class_name Park
extends Node3D
## The v1 skatepark: one full level assembled from the code-built pieces in game/park/pieces/.
## The riding area is x, z in [-75, 75] (HALF): the original 80 x 80 core (CORE_HALF = 40) in the middle, with a big
## outer ring around it (mega ramp west, dome bowl north-east, drop ramp + loop east, a long street run south). North is -Z. Pieces use the PieceKit convention (origin at the
## back-left ground corner, riding face +Z), so `_put` takes a yaw: 0 faces +Z, 180 faces -Z,
## 90 faces +X, -90 faces -X.
##
## Zones (gap ids from data/gaps.json) and collectibles (goals from data/goals.json) are placed here too.

const HALF := 75.0
## The original park, unchanged: x, z in [-CORE_HALF, CORE_HALF].
const CORE_HALF := 40.0
## Outer ring layout (world positions of each piece's origin; see the _outer_* functions).
const MEGA_POS := Vector3(-72.0, 0.0, -74.5)
const DOME_POS := Vector3(36.0, 0.0, -74.0)
const DROP_POS := Vector3(60.0, 0.0, -74.5)
const DROP_WIDTH := 4.0
const DROP_HEIGHT := 12.0
const STREET_Z := 62.0  ## centre line of the south street run, which travels +X
const SPAWN_POS := Vector3(0.0, 0.1, 20.0)
## Invisible boundary walls. The inner faces sit flush with the fence's inner face (HALF + 0.5), so the skater
## stops at the fence without snagging on it. The walls are tall enough that no jump clears them.
const BOUNDARY_INNER := HALF + 0.5
const BOUNDARY_THICK := 2.0
const BOUNDARY_HEIGHT := 40.0
const BOUNDARY_BASE_Y := -2.0

var spawn: Transform3D = Transform3D(Basis.IDENTITY, SPAWN_POS)
var collectibles: Array[Collectible] = []
## Every piece added with _put (not the ground, fences, decor, zones or collectibles), for layout checks.
var placed: Array[Node3D] = []
## Drop-in spots in park space: "mega" and "loop" -> Transform3D on the start deck, facing the roll-in.
var drop_ins: Dictionary = {}


func _ready() -> void:
	_environment()
	_ground()
	_north()
	_south()
	_west()
	_east()
	_centre()
	_street()
	_outer_mega()
	_outer_dome()
	_outer_loop()
	_outer_street()
	_outer_north()
	_drop_in_pads()
	_fences()
	_boundary()
	_decor()
	_dressing()
	_collectibles()


func _put(node: Node3D, pos: Vector3, yaw_deg: float = 0.0, node_name: String = "") -> Node3D:
	node.position = pos
	node.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	if node_name != "":
		node.name = node_name
	add_child(node)
	placed.append(node)
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
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)


## Darker than PieceKit.CONCRETE: a big flat slab in full sun reads as white at the lighter grey.
const GROUND := Color("7f8a96")


func _ground() -> void:
	# Concrete slab with holes for the sunken bowls; each bowl brings its own deck frame. A hole is Rect2(x, z, w, d).
	var holes: Array[Rect2] = [
		Rect2(22.0, -38.0, 14.0, 10.0),  # the core bowl
		Rect2(DOME_POS.x, DOME_POS.z, 19.0, 19.0),  # the dome bowl
	]
	var outer: float = HALF + 6.0
	var y := -1.0
	var xs: Array[float] = [-outer, outer]
	for h: Rect2 in holes:
		xs.append(h.position.x)
		xs.append(h.end.x)
	xs.sort()
	var n: int = 0
	for i: int in xs.size() - 1:
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		if x1 - x0 < 0.001:
			continue
		var cuts: Array[Vector2] = []  # z intervals of holes covering this x strip
		for h: Rect2 in holes:
			if h.position.x <= x0 + 0.001 and h.end.x >= x1 - 0.001:
				cuts.append(Vector2(h.position.y, h.end.y))
		cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var z: float = -outer
		for c: Vector2 in cuts:
			if c.x > z + 0.001:
				add_child(PieceKit.box(Vector3(x0, y, z), Vector3(x1 - x0, 1.0, c.x - z), GROUND, "Ground%d" % n))
				n += 1
			z = c.y
		if outer > z + 0.001:
			add_child(PieceKit.box(Vector3(x0, y, z), Vector3(x1 - x0, 1.0, outer - z), GROUND, "Ground%d" % n))
			n += 1
	# a grassy ring outside the slab, in four pieces so nothing covers the bowl holes
	var g: float = 300.0
	var grass := Color("8ad16b")
	add_child(PieceKit.box(Vector3(-g, -1.05, -g), Vector3(g * 2.0, 1.0, g - outer), grass, "GrassN"))
	add_child(PieceKit.box(Vector3(-g, -1.05, outer), Vector3(g * 2.0, 1.0, g - outer), grass, "GrassS"))
	add_child(PieceKit.box(Vector3(-g, -1.05, -outer), Vector3(g - outer, 1.0, outer * 2.0), grass, "GrassW"))
	add_child(PieceKit.box(Vector3(outer, -1.05, -outer), Vector3(g - outer, 1.0, outer * 2.0), grass, "GrassE"))


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
	_put(Buildings.shop(10.0, 8.0, 4.0, PieceKit.PAINT_RED, "SNACKS"), Vector3(-14.0, 0.0, CORE_HALF), 180.0, "ShopWest")
	_put(Buildings.shop(10.0, 8.0, 4.0, Color("4fa3e0"), "SKATE SHOP"), Vector3(0.0, 0.0, CORE_HALF), 180.0, "ShopEast")
	_put(Buildings.roof_access_ramp(4.0, 10.0, 4.0), Vector3(-24.0, 0.0, 34.0), -90.0, "RoofRamp")
	add_child(PieceKit.gap_zone("roof_west", Vector3(-17.0, 4.0, 33.0), Vector3(3.0, 3.0, 6.0)))
	add_child(PieceKit.gap_zone("roof_east", Vector3(-10.0, 4.0, 33.0), Vector3(3.0, 3.0, 6.0)))
	# SE: the big stair set with its handrail, descending north into the park, and a bank up to its platform.
	_put(StairSet.build(5.0, 4.0, 6), Vector3(20.0, 0.0, CORE_HALF), 180.0, "StairSet")
	_put(Walls.bank(4.0, 4.0, 1.6), Vector3(20.0, 0.0, 38.0), 90.0, "StairBank")
	_put(Walls.billboard_sign("SKATE PARK", 8.0), Vector3(-32.0, 0.0, 39.0), 180.0, "Sign")


func _west() -> void:
	_put(QuarterPipe.build(14.0), Vector3(-CORE_HALF, 0.0, -2.0), 90.0, "QuarterWest")
	add_child(PieceKit.gap_zone("quarter_lip", Vector3(-38.0, 3.2, -16.0), Vector3(2.5, 3.0, 14.0)))
	_put(Transfers.pyramid(9.0, 3.0, 1.4), Vector3(-28.0, 0.0, -6.0), 0.0, "Pyramid")
	_put(Kicker.build(2.0, 2.4, 0.9), Vector3(-30.0, 0.0, 16.0), 0.0, "KickerWest")


func _east() -> void:
	# Wallride alley: two painted walls facing each other.
	_put(Walls.wallride_wall(12.0, 3.5, 0.4, "wall_west"), Vector3(25.6, 0.0, 12.0), 90.0, "WallWest")
	_put(Walls.wallride_wall(12.0, 3.5, 0.4, "wall_east"), Vector3(33.6, 0.0, 0.0), -90.0, "WallEast")
	# A bank and a quarter pipe on the east edge for "Quarter To Bank".
	_put(Walls.bank(6.0, 4.0, 1.6, "bank_lip"), Vector3(CORE_HALF, 0.0, 16.0), -90.0, "BankEast")
	_put(QuarterPipe.build(10.0), Vector3(CORE_HALF, 0.0, -14.0), -90.0, "QuarterEast")
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


## The loop's local origin: its run-in starts where the drop ramp's flat run ends. The loop is turned 180 degrees, so
## its local -Z (travel) is world +Z and its run-in ribbon (local x 0..3) is centred on the drop ramp.
func _loop_pos() -> Vector3:
	var ramp_end: float = DROP_POS.z + DropRamp.length(DROP_WIDTH, DROP_HEIGHT)
	# sunk by LIFT so the loop's riding face (at y = LIFT) is flush with the ground and the ramp's flat run
	return Vector3(DROP_POS.x + DROP_WIDTH * 0.5 + 1.5, -LoopTrack.LIFT, ramp_end)


func _loop_coin_pos() -> Vector3:
	var lp: Vector3 = _loop_pos()
	# the top of the loop, where a rider hanging on the ribbon's underside passes (measured: its origin peaks at about
	# y = 7.4, 0.6 m under the riding face, a little past the circle's top and drifting toward the offset side)
	return lp + Vector3(-2.1, 7.3, 5.8)


func _mega_coin_pos() -> Vector3:
	return MEGA_POS + Vector3(4.0, 6.0, 55.3)


## WEST edge: the mega ramp, drop-in at the north end, travelling south.
func _outer_mega() -> void:
	_put(MegaRamp.build(8.0, 18.0, 14.0, 8.0), MEGA_POS, 0.0, "MegaRamp")
	drop_ins["mega"] = Transform3D(Basis.IDENTITY, MEGA_POS) * MegaRamp.drop_in_transform(8.0, 18.0)
	# a big sign beside the tower
	_put(Walls.billboard_sign("MEGA RAMP", 8.0), Vector3(-58.0, 0.0, -66.0), 90.0, "MegaSign")


## NORTH-EAST: the dome bowl.
func _outer_dome() -> void:
	_put(DomeBowl.build(8.0, 0.85), DOME_POS, 0.0, "DomeBowl")
	var c: Vector3 = DOME_POS + Vector3(9.5, 0.0, 9.5)
	# four rim zones (one id) to pair with the "dome_air" zone above the centre
	for k: int in 4:
		var a: float = float(k) * PI * 0.5
		var d := Vector3(cos(a), 0.0, sin(a))
		var along: bool = k % 2 == 0
		var size := Vector3(3.0, 3.0, 5.0) if along else Vector3(5.0, 3.0, 3.0)
		var mid: Vector3 = c + d * 6.5
		add_child(PieceKit.gap_zone("dome_rim", Vector3(mid.x - size.x * 0.5, -1.0, mid.z - size.z * 0.5), size))


## EAST edge: the drop ramp feeds the loop, then a long run-out to a catch quarter pipe.
func _outer_loop() -> void:
	_put(DropRamp.build(DROP_WIDTH, DROP_HEIGHT, 2.0), DROP_POS, 0.0, "DropRamp")
	drop_ins["loop"] = Transform3D(Basis.IDENTITY, DROP_POS) * DropRamp.drop_in_transform(DROP_WIDTH, DROP_HEIGHT)
	var loop: Node3D = _put(LoopTrack.build(4.0, 3.0, 6.0, 6.0, 3.5), _loop_pos(), 180.0, "Loop")
	# end-of-loop zone (local): the flat run-out, to pair with "loop_full"
	loop.add_child(PieceKit.gap_zone("loop_out", Vector3(3.0, 0.0, -11.5), Vector3(4.0, 3.0, 2.0)))
	# the catch: a quarter pipe across the run-out lane, 40 m past the loop
	_put(QuarterPipe.build(10.0), Vector3(_loop_pos().x, 0.0, 24.0), 180.0, "CatchQuarter")
	_put(Walls.billboard_sign("LOOP DE LOOP", 8.0), Vector3(48.0, 0.0, -44.0), -90.0, "LoopSign")


## SOUTH: a long street run from west to east along z = STREET_Z. Pieces are built along local Z and turned to run +X
## (yaw 90 maps local +Z to +X and local +X to -Z), so a piece of width w centred on the line sits at z = STREET_Z + w / 2.
func _put_run(node: Node3D, x0: float, width: float, node_name: String, lane: float = 0.0) -> Node3D:
	return _put(node, Vector3(x0, 0.0, STREET_Z + lane + width * 0.5), 90.0, node_name)


func _outer_street() -> void:
	_put_run(StreetRun.downhill(34.0, 3.5, 8.0, 5.0, 10.0), -73.0, 8.0, "Downhill")
	_put_run(StreetRun.long_ledge(18.0, 0.5, 0.8, PieceKit.PAINT_PURPLE, "long_ledge"), -18.0, 0.8, "LongLedge")
	_put_run(StreetRun.long_rail(22.0, 0.45, "long_rail"), 4.0, 1.0, "LongRail")
	_put_run(StreetRun.hubba_set(10, 0.2, 0.9, 5.0), 31.0, 6.2, "HubbaSet")
	# flat-bank walls along the south edge: bank up, then a wall to wallride
	for x1: float in [-38.0, -2.0, 34.0, 70.0]:
		_put(StreetRun.bank_wall(24.0, 1.6, 4.0, 3.0), Vector3(x1, 0.0, HALF - 0.4), 180.0, "BankWall%d" % int(x1))
	# the east end of the run
	_put(QuarterPipe.build(10.0), Vector3(HALF, 0.0, STREET_Z - 5.0), -90.0, "StreetQuarter")


## NORTH-WEST / NORTH: two long rails, a long way from anything else, on the line to the dome.
func _outer_north() -> void:
	_put(StreetBits.flat_rail(25.0, 0.45, "rail25_a", "rail25_b"), Vector3(-60.0, 0.0, -58.5), 90.0, "Rail25")
	_put(StreetBits.flat_rail(15.0, 0.45, "rail15_a", "rail15_b"), Vector3(-26.0, 0.0, -58.5), 90.0, "Rail15")


## DROP IN marker pads at the base of each tower: stand still on one for a second to be sent to the top.
func _drop_in_pads() -> void:
	var pads: Array = [
		["mega", Vector3(MEGA_POS.x + 8.0 + 3.5, 0.0, MEGA_POS.z + 40.0)],
		["loop", Vector3(DROP_POS.x + DROP_WIDTH + 3.0, 0.0, DROP_POS.z + 26.0)],
	]
	for p: Array in pads:
		var pad := DropIn.new()
		pad.spot = str(p[0])
		pad.target = drop_ins[p[0]]
		pad.position = p[1]
		pad.name = "DropInPad_" + str(p[0])
		add_child(pad)


func _fences() -> void:
	var n: int = int(round(HALF * 2.0 / 10.0))
	for i: int in n:
		var x: float = -HALF + i * 10.0
		_fence(Walls.fence(10.0, 1.4), Vector3(x, 0.0, -HALF - 0.6), 0.0, "FenceN%d" % i)
		_fence(Walls.fence(10.0, 1.4), Vector3(x + 10.0, 0.0, HALF + 0.6), 180.0, "FenceS%d" % i)
		_fence(Walls.fence(10.0, 1.4), Vector3(-HALF - 0.6, 0.0, x + 10.0), 90.0, "FenceW%d" % i)
		_fence(Walls.fence(10.0, 1.4), Vector3(HALF + 0.6, 0.0, x), -90.0, "FenceE%d" % i)


## A fence segment: placed like a piece but not tracked as a rideable one.
func _fence(node: Node3D, pos: Vector3, yaw_deg: float, node_name: String) -> void:
	node.position = pos
	node.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	node.name = node_name
	add_child(node)


func _boundary() -> void:
	add_child(Park.boundary_walls())


## Four invisible, collision-only walls around the riding area: flat inner faces at +-BOUNDARY_INNER, each
## BOUNDARY_THICK thick and BOUNDARY_HEIGHT tall. North and south span the full width; east and west span the full
## depth, so the corners overlap and leave no gap. Static bodies on the world layer (1), like the ground.
static func boundary_walls() -> Node3D:
	var root := Node3D.new()
	root.name = "Boundary"
	var outer: float = BOUNDARY_INNER + BOUNDARY_THICK
	var centre: float = BOUNDARY_INNER + BOUNDARY_THICK * 0.5
	var y: float = BOUNDARY_BASE_Y + BOUNDARY_HEIGHT * 0.5
	var span: Vector3 = Vector3(outer * 2.0, BOUNDARY_HEIGHT, BOUNDARY_THICK)
	var side: Vector3 = Vector3(BOUNDARY_THICK, BOUNDARY_HEIGHT, outer * 2.0)
	root.add_child(_wall_body("BoundaryN", Vector3(0.0, y, -centre), span))
	root.add_child(_wall_body("BoundaryS", Vector3(0.0, y, centre), span))
	root.add_child(_wall_body("BoundaryW", Vector3(-centre, y, 0.0), side))
	root.add_child(_wall_body("BoundaryE", Vector3(centre, y, 0.0), side))
	return root


static func _wall_body(node_name: String, centre: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.position = centre
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	return body


## Graffiti, trash cans, litter and parked cars (game/park/pieces/dressing.gd). Not tracked in `placed`.
func _dressing() -> void:
	add_child(ParkDressing.build(placed))


func _decor() -> void:
	var decor := Node3D.new()
	decor.name = "Decor"
	add_child(decor)
	var trees := PackedVector3Array()
	var palms := PackedVector3Array()
	# a square ring of trees outside the fence, evenly spaced along the perimeter
	var ring: float = HALF + 8.0
	var count: int = 40
	for i: int in count:
		var p: Vector3 = _ring_point(float(i) / float(count), ring)
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
		crowd.append(Vector3(-HALF - 4.0, 0.0, -36.0 + i * 1.6))
	Props.scatter(decor, "crowd_kid", crowd, 11)
	var mountains := PackedVector3Array()
	for i: int in 9:
		var t: float = float(i) / 9.0 * TAU + 0.3
		mountains.append(Vector3(cos(t) * 260.0, 0.0, sin(t) * 260.0))
	Props.scatter(decor, "mountain", mountains, 12)
	var clouds := PackedVector3Array()
	for i: int in 10:
		var t: float = float(i) / 10.0 * TAU
		clouds.append(Vector3(cos(t) * 150.0, 38.0 + (i % 3) * 6.0, sin(t) * 150.0))
	Props.scatter(decor, "cloud", clouds, 13)


## A point on the square of half-size `half`, f = 0..1 once around, starting at the north-west corner.
static func _ring_point(f: float, half: float) -> Vector3:
	var d: float = fposmod(f, 1.0) * 8.0 * half
	var side: int = int(d / (2.0 * half))
	var u: float = d - float(side) * 2.0 * half - half
	match side:
		0:
			return Vector3(u, 0.0, -half)
		1:
			return Vector3(half, 0.0, u)
		2:
			return Vector3(-u, 0.0, half)
	return Vector3(-half, 0.0, -u)


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
	# The outer ring: a coin on each big line (L: top of the loop, M: over the mega gap, D: over the dome) and pizza.
	_letter("L", _loop_coin_pos())
	_letter("M", _mega_coin_pos())
	_letter("D", DOME_POS + Vector3(9.5, 2.6, 9.5))
	for p: Vector3 in [Vector3(-48.0, 3.6, STREET_Z), Vector3(40.0, 3.4, STREET_Z), Vector3(-48.0, 1.4, -59.0)]:
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
