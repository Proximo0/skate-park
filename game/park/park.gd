class_name Park
extends Node3D
## The v1 skatepark: one full level assembled from the code-built pieces in game/park/pieces/.
## The riding area is x, z in [-40, 40]. North is -Z. Pieces use the PieceKit convention (origin at the
## back-left ground corner, riding face +Z), so `_put` takes a yaw: 0 faces +Z, 180 faces -Z,
## 90 faces +X, -90 faces -X.
##
## Zones (gap ids from data/gaps.json) and collectibles (goals from data/goals.json) are placed here too.

const HALF := 40.0
const SPAWN_POS := Vector3(0.0, 0.1, 20.0)

var spawn: Transform3D = Transform3D(Basis.IDENTITY, SPAWN_POS)
var collectibles: Array[Collectible] = []


func _ready() -> void:
	_environment()
	_ground()
	_north()
	_south()
	_west()
	_east()
	_centre()
	_street()
	_fences()
	_decor()
	_collectibles()


func _put(node: Node3D, pos: Vector3, yaw_deg: float = 0.0, node_name: String = "") -> Node3D:
	node.position = pos
	node.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	if node_name != "":
		node.name = node_name
	add_child(node)
	return node


func _environment() -> void:
	var env := WorldEnvironment.new()
	env.name = "Environment"
	env.environment = Toon.sky_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


## Darker than PieceKit.CONCRETE: a big flat slab in full sun reads as white at the lighter grey.
const GROUND := Color("7f8a96")


func _ground() -> void:
	# Concrete slab with a hole for the sunken bowl (x 22..36, z -38..-28); the bowl brings its own frame.
	var y := -1.0
	var outer := 46.0
	var parts: Array = [
		[Vector3(-outer, y, -outer), Vector3(outer + 22.0, 1.0, outer * 2.0)],  # west of the bowl
		[Vector3(36.0, y, -outer), Vector3(outer - 36.0, 1.0, outer * 2.0)],  # east of the bowl
		[Vector3(22.0, y, -outer), Vector3(14.0, 1.0, outer - 38.0)],  # north of the bowl
		[Vector3(22.0, y, -28.0), Vector3(14.0, 1.0, outer + 28.0)],  # south of the bowl
	]
	for i: int in parts.size():
		add_child(PieceKit.box(parts[i][0], parts[i][1], GROUND, "Ground%d" % i))
	# a grassy ring outside the fence
	add_child(PieceKit.box(Vector3(-120, -1.05, -120), Vector3(240, 1.0, 240), Color("8ad16b"), "Grass"))


func _north() -> void:
	# NW: the big halfpipe, running north-south.
	_put(HalfPipe.build(10.0, 6.0, 3.5, 4.0, 2.0), Vector3(-38.0, 0.0, -40.0), 0.0, "HalfPipe")
	# Quarter pipes along the north edge.
	_put(QuarterPipe.build(14.0), Vector3(-24.0, 0.0, -40.0), 0.0, "QuarterNorthWest")
	_put(QuarterPipe.build(14.0, 3.0, 3.2), Vector3(-6.0, 0.0, -40.0), 0.0, "QuarterNorth")
	# NE: the sunken bowl.
	_put(Bowl.build(14.0, 10.0, 2.6), Vector3(22.0, 0.0, -38.0), 0.0, "Bowl")
	# The spine between the north quarters and the centre.
	_put(Transfers.spine(10.0, 2.2, 2.4), Vector3(6.0, 0.0, -24.0), 0.0, "Spine")


func _south() -> void:
	# Two shops facing the park with a roof gap between them, and a ramp up to the west roof.
	_put(Buildings.shop(10.0, 8.0, 4.0, PieceKit.PAINT_RED, "SNACKS"), Vector3(-14.0, 0.0, HALF), 180.0, "ShopWest")
	_put(Buildings.shop(10.0, 8.0, 4.0, Color("4fa3e0"), "SKATE SHOP"), Vector3(0.0, 0.0, HALF), 180.0, "ShopEast")
	_put(Buildings.roof_access_ramp(4.0, 10.0, 4.0), Vector3(-24.0, 0.0, 34.0), -90.0, "RoofRamp")
	add_child(PieceKit.gap_zone("roof_west", Vector3(-17.0, 4.0, 33.0), Vector3(3.0, 3.0, 6.0)))
	add_child(PieceKit.gap_zone("roof_east", Vector3(-10.0, 4.0, 33.0), Vector3(3.0, 3.0, 6.0)))
	# SE: the big stair set with its handrail, descending north into the park, and a bank up to its platform.
	_put(StairSet.build(5.0, 4.0, 6), Vector3(20.0, 0.0, HALF), 180.0, "StairSet")
	_put(Walls.bank(4.0, 4.0, 1.6), Vector3(20.0, 0.0, 38.0), 90.0, "StairBank")
	_put(Walls.billboard_sign("SKATE PARK", 8.0), Vector3(-34.0, 0.0, 39.0), 180.0, "Sign")


func _west() -> void:
	_put(QuarterPipe.build(14.0), Vector3(-HALF, 0.0, -2.0), 90.0, "QuarterWest")
	add_child(PieceKit.gap_zone("quarter_lip", Vector3(-38.0, 3.2, -16.0), Vector3(2.5, 3.0, 14.0)))
	_put(Transfers.pyramid(9.0, 3.0, 1.4), Vector3(-28.0, 0.0, -6.0), 0.0, "Pyramid")
	_put(Kicker.build(2.0, 2.4, 0.9), Vector3(-30.0, 0.0, 16.0), 0.0, "KickerWest")


func _east() -> void:
	# Wallride alley: two painted walls facing each other.
	_put(Walls.wallride_wall(12.0, 3.5, 0.4, "wall_west"), Vector3(25.6, 0.0, 12.0), 90.0, "WallWest")
	_put(Walls.wallride_wall(12.0, 3.5, 0.4, "wall_east"), Vector3(33.6, 0.0, 0.0), -90.0, "WallEast")
	# A bank and a quarter pipe on the east edge for "Quarter To Bank".
	_put(Walls.bank(6.0, 4.0, 1.6, "bank_lip"), Vector3(HALF, 0.0, 16.0), -90.0, "BankEast")
	_put(QuarterPipe.build(10.0), Vector3(HALF, 0.0, -14.0), -90.0, "QuarterEast")
	add_child(PieceKit.gap_zone("quarter_lip", Vector3(35.5, 3.2, -14.0), Vector3(2.5, 3.0, 10.0)))
	_put(Kicker.build(2.0, 2.4, 0.9), Vector3(18.0, 0.0, 4.0), 0.0, "KickerEast")


func _centre() -> void:
	_put(FunBox.build(4.0, 5.0, 3.0, 1.0), Vector3(-2.0, 0.0, -10.0), 0.0, "FunBox")
	_put(Transfers.hip(8.0, 2.5, 2.8), Vector3(-14.0, 0.0, -28.0), 0.0, "Hip")
	_put(Kicker.build(2.4, 2.4, 1.0), Vector3(-1.2, 0.0, 6.0), 0.0, "KickerCentre")


func _street() -> void:
	# South-centre street plaza.
	_put(StreetBits.ledge(8.0, 0.5, 0.8, PieceKit.PAINT_PURPLE, "ledge_a"), Vector3(4.0, 0.0, 12.0), 0.0, "LedgeA")
	_put(StreetBits.ledge(8.0, 0.5, 0.8, PieceKit.PAINT_GREEN, "ledge_b"), Vector3(9.0, 0.0, 12.0), 0.0, "LedgeB")
	_put(StreetBits.manual_pad(6.0, 2.5, 0.3, "manual_pad_a", "manual_pad_b"), Vector3(-7.0, 0.0, 13.0), 0.0, "ManualPad")
	_put(StreetBits.flat_rail(6.0, 0.45, "rail_a_top", ""), Vector3(-17.0, 0.0, 12.0), 0.0, "RailA")
	_put(StreetBits.flat_rail(6.0, 0.45, "rail_b_top", ""), Vector3(-13.0, 0.0, 12.0), 0.0, "RailB")
	_put(StreetBits.flat_rail(5.0, 0.45, "flatbar_a", "flatbar_b"), Vector3(14.0, 0.0, 22.0), 90.0, "Flatbar")
	_put(StreetBits.bench(2.4), Vector3(-26.0, 0.0, 26.0), 0.0, "BenchA")
	_put(StreetBits.bench(2.4), Vector3(26.0, 0.0, 26.0), 0.0, "BenchB")
	_put(StreetBits.planter(2.0, 0.55), Vector3(-22.0, 0.0, 6.0), 0.0, "PlanterA")
	_put(StreetBits.planter(2.0, 0.55), Vector3(12.0, 0.0, -6.0), 0.0, "PlanterB")


func _fences() -> void:
	for i: int in 8:
		var x: float = -HALF + i * 10.0
		_put(Walls.fence(10.0, 1.4), Vector3(x, 0.0, -HALF - 0.6), 0.0, "FenceN%d" % i)
		_put(Walls.fence(10.0, 1.4), Vector3(x + 10.0, 0.0, HALF + 0.6), 180.0, "FenceS%d" % i)
		_put(Walls.fence(10.0, 1.4), Vector3(-HALF - 0.6, 0.0, x + 10.0), 90.0, "FenceW%d" % i)
		_put(Walls.fence(10.0, 1.4), Vector3(HALF + 0.6, 0.0, x), -90.0, "FenceE%d" % i)


func _decor() -> void:
	var decor := Node3D.new()
	decor.name = "Decor"
	add_child(decor)
	var trees := PackedVector3Array()
	var palms := PackedVector3Array()
	for i: int in 16:
		var t: float = float(i) / 16.0 * TAU
		var p := Vector3(cos(t) * 58.0, 0.0, sin(t) * 58.0)
		if i % 3 == 0:
			palms.append(p)
		else:
			trees.append(p)
	Props.scatter(decor, "tree", trees, 3)
	Props.scatter(decor, "palm_tree", palms, 4)
	Props.scatter(decor, "bush", PackedVector3Array([Vector3(-44, 0, 10), Vector3(44, 0, -10), Vector3(10, 0, 44), Vector3(-10, 0, -44)]), 5)
	Props.scatter(decor, "lamp_post", PackedVector3Array([Vector3(-20, 0, 28), Vector3(20, 0, 28), Vector3(-20, 0, -12), Vector3(24, 0, -14)]), 6)
	Props.scatter(decor, "trash_can", PackedVector3Array([Vector3(-28, 0, 29), Vector3(29, 0, 29)]), 7)
	Props.scatter(decor, "traffic_cone", PackedVector3Array([Vector3(2, 0, 26), Vector3(3, 0, 27), Vector3(-3, 0, 26)]), 8)
	Props.scatter(decor, "picnic_table", PackedVector3Array([Vector3(-34, 0, 26)]), 9)
	Props.scatter(decor, "ice_cream_cart", PackedVector3Array([Vector3(-6, 0, 29)]), 10)
	var crowd := PackedVector3Array()
	for i: int in 6:
		crowd.append(Vector3(-42.5, 0.0, -36.0 + i * 1.6))
	Props.scatter(decor, "crowd_kid", crowd, 11)
	var mountains := PackedVector3Array()
	for i: int in 9:
		var t: float = float(i) / 9.0 * TAU + 0.3
		mountains.append(Vector3(cos(t) * 160.0, 0.0, sin(t) * 160.0))
	Props.scatter(decor, "mountain", mountains, 12)
	var clouds := PackedVector3Array()
	for i: int in 10:
		var t: float = float(i) / 10.0 * TAU
		clouds.append(Vector3(cos(t) * 90.0, 38.0 + (i % 3) * 6.0, sin(t) * 90.0))
	Props.scatter(decor, "cloud", clouds, 13)


func _collectibles() -> void:
	# S-K-A-T-E letters in spots that each need a different skill.
	_letter("S", Vector3(0.0, 2.4, -4.5))  # above the funbox rail
	_letter("K", Vector3(-33.0, 6.2, -38.5 + 2.0 + 3.5))  # big air on the halfpipe's north wall
	_letter("A", Vector3(-19.0, 5.0, 36.0))  # on the west shop roof
	_letter("T", Vector3(29.0, -1.5, -33.0))  # down in the bowl
	_letter("E", Vector3(-23.5, 3.2, -1.5))  # above the pyramid
	# Five pizza slices.
	for p: Vector3 in [Vector3(29.6, 2.4, 6.0), Vector3(17.5, 3.0, 34.0), Vector3(11.0, 3.6, -21.8), Vector3(-10.0, 4.2, -24.0), Vector3(37.0, 2.6, 19.0)]:
		_pizza(p)


func _letter(item: String, pos: Vector3) -> void:
	var c := Collectible.new()
	c.item = item
	c.group_id = "skate"
	c.position = pos
	c.name = "Letter_" + item
	add_child(c)
	collectibles.append(c)


func _pizza(pos: Vector3) -> void:
	var c := Collectible.new()
	c.item = "pizza"
	c.group_id = "pizza"
	c.position = pos
	c.name = "Pizza_%d" % collectibles.size()
	add_child(c)
	collectibles.append(c)
