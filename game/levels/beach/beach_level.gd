class_name BeachLevel
extends Level
## Beachfront: a golden-afternoon beach town where the ocean is the star. North to south (-Z to +Z):
##   the coast road (two lanes of traffic, parked surf vans, palms) -> the south sidewalk -> the land at y = 0:
##   the concrete beach skatepark in the west (snake run, bowl, pyramid, funbox, quarter pipe, banks down to the sand)
##   and the boardwalk in the middle and east (surf shop, pizza shack, food stands, arcade, benches, rails, manual pad,
##   the Beach Launch kicker) -> the seawall (a 1.2 m drop to the sand, capped with a long grindable ledge, cut by
##   banks and the lifeguard stairs) -> the beach (lifeguard towers, umbrellas, a driftwood log, rocks, a volleyball
##   net, the Rock Hop kicker) -> the surf (Ocean) with the pier running 108 m out over it to a quarter pipe.
## The bay is framed by two headlands, an island and sailboats; the town and golden hills close the land side.
## Gap zones match gaps.json here, goals goals.json; bot_route.json is written by make_route.gd from the live level.

const HALF_X: float = 110.0
const Z_MIN: float = -62.0
const Z_MAX: float = 101.0
## Sand and sea: the dry sand sits SAND_Y under the land; sea level is BERM lower still.
const SAND_Y: float = -1.2
const BERM: float = 1.2
const SEA_Y: float = SAND_Y - BERM
const SHORE_Z: float = 40.0  ## still-water line on the sand
const SEAWALL_Z: float = -8.0  ## the seawall's sea face
const SEAWALL_BACK: float = -9.0
## The coast road and its sidewalks.
const ROAD_Z0: float = -60.0
const ROAD_Z1: float = -44.0
const EAST_LANE_Z: float = -49.25
const WEST_LANE_Z: float = -54.75
const WALK_S_Z1: float = -40.0  ## south sidewalk z in [ROAD_Z1, WALK_S_Z1]
const PARK_X1: float = -38.0  ## skatepark x in [-HALF_X, PARK_X1], the boardwalk east of it
## The snake run's centre line (see BeachSnake.make).
const SNAKE_START := Vector2(-106.0, -32.0)
const SNAKE_SEGS: Array = [["L", 4.0], ["A", 12.0, 70.0], ["A", 12.0, -140.0], ["A", 12.0, 70.0], ["L", 4.0]]
const BOWL_RECT := Rect2(-85.0, -40.0, 12.0, 9.0)
## The pier: deck x in [PIER_X0, PIER_X1] from the seawall out to the end platform; a gap of missing planks.
const PIER_X0: float = 50.0
const PIER_X1: float = 58.0
const PIER_GAP_Z0: float = 62.0
const PIER_GAP_Z1: float = 64.4
const PIER_PLAT_Z: float = 86.0
const PIER_RAIL_H: float = 1.0
const DECK_T: float = 0.35
## Seawall ledge: segments [x0, x1] along the seawall, top LEDGE_H, LEDGE_D deep on the land side of the sea face.
const LEDGE_H: float = 0.5
const LEDGE_D: float = 0.6
const LEDGES: Array = [[-92.0, -66.0], [-56.0, -12.0], [-4.0, 6.0], [12.0, 50.0], [58.0, 86.0], [94.0, 108.0]]
const SPAWN_POS := Vector3(0.0, 0.1, -27.0)

const CONCRETE := Color("aea79c")
const PARK_CONCRETE := Color("a29d97")
const PLANKS := Color("8f6d55")
const PAVERS := Color("bfa489")
const SAND := Color("cdae8f")
const SEAWALL := Color("b5a892")
const LEDGE_CAP := Color("b3aa9c")
const RAIL_PAINT := Color("2f8fa8")

var snake: BeachSnake
var ocean: Ocean
var traffic: Traffic
var crowd: Pedestrians
var palms: SwayTrees
var kit: LevelKit


func _init() -> void:
	spawn = Transform3D(Basis(Vector3.UP, PI), SPAWN_POS)  # facing +Z: down the boardwalk to the sea
	bounds = Rect2(-HALF_X, Z_MIN, HALF_X * 2.0, Z_MAX - Z_MIN)
	kill_y = Level.DEFAULT_KILL_Y
	gaps_path = "res://game/levels/beach/gaps.json"
	goals_path = "res://game/levels/beach/goals.json"
	preview_view = [Vector3(-24.0, 9.0, -30.0), Vector3(30.0, -2.0, 60.0)]
	snake = BeachSnake.make(SNAKE_START, 0.0, SNAKE_SEGS)


func _ready() -> void:
	setup_environment()
	kit = LevelKit.open("beach")
	palms = SwayTrees.new()
	palms.name = "Palms"
	palms.seed_value = 77
	_ground()
	_sea()
	add_boundary()
	_skatepark()
	_boardwalk()
	_seawall()
	_beach()
	_pier()
	_road()
	_bay()
	add_child(palms)
	_life()
	_collectibles()
	_merge_all()
	add_drop_in("pier", "Pier End", Transform3D(Basis.IDENTITY, Vector3(54.0, 0.1, 84.0)))
	add_drop_in("snake", "Snake Run", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(SNAKE_START.x - 1.5, 0.1, SNAKE_START.y)))


# --- mood ----------------------------------------------------------------------------------------------

## The beach_sunny preset turned to a golden afternoon: a low warm sun in the west-south-west over the sea (glints and a
## warm side light on everything ridden toward the water), warmer horizon bands and haze.
static func golden(p: Dictionary) -> Dictionary:
	var g: Dictionary = p.duplicate()
	g["name"] = "Beach, golden afternoon"
	g["sun_rotation"] = Vector3(-27.0, -62.0, 0.0)
	g["sun_color"] = Color(1.0, 0.86, 0.66)
	g["sun_energy"] = 1.12
	g["zenith"] = Color(0.12, 0.38, 0.86)
	g["upper"] = Color(0.3, 0.6, 0.97)
	g["aqua"] = Color(0.64, 0.86, 0.94)
	g["yellow"] = Color(1.0, 0.86, 0.58)
	g["coral"] = Color(1.0, 0.66, 0.5)
	g["below"] = Color(0.3, 0.52, 0.66)
	g["band_scale"] = 0.8
	g["cloud_cover"] = 0.32
	g["cloud_warmth"] = 0.65
	g["sun_size"] = 1.15
	g["fog_color"] = Color(1.0, 0.88, 0.75)
	g["fog_density"] = 0.0011
	g["ambient_color"] = Color(1.0, 0.93, 0.88)
	g["ambient_energy"] = 0.3
	g["shadow_distance"] = 90.0
	g["water_deep"] = Color("0d5f93")
	g["water_shallow"] = Color("2fd3c4")
	return g


func setup_environment(preset_id: String = "") -> void:
	if preset_id != "":
		mood_id = preset_id
	mood = BeachLevel.golden(Mood.preset(mood_id if mood_id != "" else "beach_sunny"))
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = Mood.environment(mood)
	world_environment = we
	var key := DirectionalLight3D.new()
	key.name = "Sun"
	key.rotation_degrees = mood["sun_rotation"] as Vector3
	key.light_color = mood["sun_color"] as Color
	key.light_energy = float(mood["sun_energy"])
	key.shadow_enabled = true
	key.directional_shadow_max_distance = float(mood["shadow_distance"])
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun = key
	add_child(we)
	add_child(key)


# --- ground ----------------------------------------------------------------------------------------------

## A flat slab (top at top_y, `thick` deep) over `rect` with a WorldSurface look. Collision on layer 1, receives only.
func slab(rect: Rect2, kind: String, colour: Color, node_name: String, top_y: float = 0.0, thick: float = 1.0, pattern: float = 1.0) -> StaticBody3D:
	var sb: StaticBody3D = PieceKit.box(Vector3(rect.position.x, top_y - thick, rect.position.y), Vector3(rect.size.x, thick, rect.size.y), colour, node_name)
	(sb.get_node("Mesh") as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a box shape, not the box mesh's trimesh: the road and sidewalk slabs are 840 m long, and a trimesh of triangles that size
	# reports phantom underside contacts metres from the skater (a dead stop at the WalkSouth/ParkSlab line, 100% loss)
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x, thick, rect.size.y)
	(sb.get_node("Collision") as CollisionShape3D).shape = box
	WorldSurface.apply(sb, kind, colour, pattern)
	add_child(sb)
	return sb


## `outer` minus the (possibly overlapping) `holes`, as x-strip rectangles.
static func rects_minus(outer: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	var xs: Array[float] = [outer.position.x, outer.end.x]
	for h: Rect2 in holes:
		xs.append(clampf(h.position.x, outer.position.x, outer.end.x))
		xs.append(clampf(h.end.x, outer.position.x, outer.end.x))
	xs.sort()
	var out: Array[Rect2] = []
	for i: int in xs.size() - 1:
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		if x1 - x0 < 0.001:
			continue
		var cuts: Array[Vector2] = []
		for h: Rect2 in holes:
			if h.position.x <= x0 + 0.001 and h.end.x >= x1 - 0.001:
				cuts.append(Vector2(h.position.y, h.end.y))
		cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var z: float = outer.position.y
		for c: Vector2 in cuts:
			if c.x > z + 0.001:
				out.append(Rect2(x0, z, x1 - x0, minf(c.x, outer.end.y) - z))
			z = maxf(z, c.y)
		if outer.end.y > z + 0.001:
			out.append(Rect2(x0, z, x1 - x0, outer.end.y - z))
	return out


func _ground() -> void:
	var far: float = 420.0
	slab(Rect2(-far, ROAD_Z0, far * 2.0, ROAD_Z1 - ROAD_Z0), "asphalt", Color("4d5160"), "Road")
	slab(Rect2(-far, ROAD_Z0 - 10.0, far * 2.0, 10.0), "pavers", PAVERS, "WalkNorth", 0.0, 1.0, 0.6)
	slab(Rect2(-far, ROAD_Z1, far * 2.0, WALK_S_Z1 - ROAD_Z1), "concrete", CONCRETE, "WalkSouth", 0.0, 1.0, 0.5)
	# the town's ground behind the north sidewalk (visual: the boundary keeps riders out)
	var town := MeshInstance3D.new()
	town.name = "TownGround"
	var pm := PlaneMesh.new()
	pm.size = Vector2(2600.0, 1400.0)
	town.mesh = pm
	town.position = Vector3(0.0, -0.02, ROAD_Z0 - 10.0 - 700.0)
	town.material_override = WorldSurface.material("pavers", Color("979282"), 0.8)
	town.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(town)
	# the land between the sidewalk and the seawall: skatepark slab (holes for the snake run and the bowl), boardwalk
	var land := Rect2(-HALF_X, WALK_S_Z1, PARK_X1 + HALF_X, SEAWALL_BACK - WALK_S_Z1)
	var region: Rect2 = snake_region()
	var n: int = 0
	for r: Rect2 in BeachLevel.rects_minus(land, [region, BOWL_RECT]):
		slab(r, "concrete", PARK_CONCRETE, "ParkSlab%d" % n, 0.0, 1.0, 0.7)
		n += 1
	slab(Rect2(-far, WALK_S_Z1, far - HALF_X, SEAWALL_BACK - WALK_S_Z1), "grass", Color("6f9a4c"), "LawnWest")
	slab(Rect2(PARK_X1, WALK_S_Z1, far - PARK_X1, 9.0), "pavers", PAVERS, "Plaza", 0.0, 1.0, 0.7)
	slab(Rect2(PARK_X1, WALK_S_Z1 + 9.0, far - PARK_X1, SEAWALL_BACK - WALK_S_Z1 - 9.0), "planks", PLANKS, "Boardwalk")
	# the seawall: a strip from below the sand up to the deck, its sea face at SEAWALL_Z
	var wall: StaticBody3D = slab(Rect2(-far, SEAWALL_BACK, far * 2.0, SEAWALL_Z - SEAWALL_BACK), "concrete", SEAWALL, "Seawall", 0.0, 2.6, 0.5)
	wall.name = "Seawall"


## The snake run's grid region: its footprint with a metre of deck, clipped to the skatepark land.
func snake_region() -> Rect2:
	var f: Rect2 = snake.footprint(1.0)
	var land := Rect2(-HALF_X, WALK_S_Z1, PARK_X1 + HALF_X, SEAWALL_BACK - WALK_S_Z1)
	return f.intersection(land)


func _sea() -> void:
	ocean = Ocean.new()
	ocean.name = "Ocean"
	ocean.position = Vector3(0.0, SEA_Y, SHORE_Z)
	ocean.berm = BERM
	add_child(ocean)
	var beach: StaticBody3D = ocean.add_beach(1600.0, SHORE_Z - SEAWALL_BACK, 90.0, SAND)
	beach.name = "Sand"
	# The kit's sand collides as a few 1600 m-wide triangles, which the solver rides with a few mm of jitter; the
	# playable stretch gets a finely tiled copy of the same surface instead.
	for c: Node in beach.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).shape = sand_shape(ocean.beach_slope, ocean.berm, SHORE_Z - SEAWALL_BACK, 90.0)


## The beach surface (Ocean.sand_height, in the ocean's local space) as 4 x 2 m tiles over the playable width.
static func sand_shape(slope: float, berm_h: float, inland_m: float, seaward: float) -> ConcavePolygonShape3D:
	var faces := PackedVector3Array()
	var hw: float = HALF_X + 30.0
	var z: float = -inland_m
	while z < seaward - 0.001:
		var z1: float = minf(z + 2.0, seaward)
		var y0: float = Ocean.sand_height(z, slope, berm_h)
		var y1: float = Ocean.sand_height(z1, slope, berm_h)
		var x: float = -hw
		while x < hw - 0.001:
			var x1: float = x + 4.0
			var a := Vector3(x, y0, z)
			var b := Vector3(x1, y0, z)
			var c := Vector3(x1, y1, z1)
			var d := Vector3(x, y1, z1)
			faces.append_array([a, b, c, a, c, d])
			x = x1
		z = z1
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape


# --- the skatepark -------------------------------------------------------------------------------------

func _skatepark() -> void:
	var holes: Array[Rect2] = [BOWL_RECT]
	var sn: Node3D = snake.build(snake_region(), holes)
	add_child(sn)
	placed.append(sn)
	put(Bowl.build(BOWL_RECT.size.x, BOWL_RECT.size.y, 2.4, 2.8, 2.2, 10, "sp_bowl"), Vector3(BOWL_RECT.position.x, 0.0, BOWL_RECT.position.y), 0.0, "Bowl")
	# the snake's roll-out runs straight onto the funbox (built along X)
	put(FunBox.build(4.0, 5.0, 3.0, 1.0, "sp_funbox"), Vector3(-49.0, 0.0, -30.0), 90.0, "FunBox")
	put(Transfers.pyramid(9.0, 3.0, 1.4, "sp_pyr"), Vector3(-43.0, 0.0, -24.0), -90.0, "Pyramid")
	# the west quarter pipe faces east across the park
	put(QuarterPipe.build(12.0, 3.0, 3.2, 1.5), Vector3(-HALF_X, 0.0, -10.0), 90.0, "QuarterWest")
	# the south-east pocket: a ledge and a flat bar along the seawall
	put(StreetBits.ledge(9.0, 0.5, 0.8, Color("ff7a5c"), "sp_ledge"), Vector3(-64.5, 0.0, -19.0), 90.0, "ParkLedge")  # clear of the snake run pit wall (it was overhanging it)
	put(StreetBits.flat_rail(8.0, 0.45, "sp_bar_a", "sp_bar_b"), Vector3(-66.0, 0.0, -15.6), 90.0, "ParkBar")
	# banks from the deck down to the sand
	put(Walls.bank(12.0, 4.0, -SAND_Y, "sp_bank_w"), Vector3(-104.0, SAND_Y, SEAWALL_Z), 0.0, "BankSandWest")
	put(Walls.bank(10.0, 4.0, -SAND_Y, "sp_bank_e"), Vector3(-66.0, SAND_Y, SEAWALL_Z), 0.0, "BankSandEast")
	_put_deco(StreetBits.bench(2.4), Vector3(-71.0, 0.0, -43.0 + 3.0), 0.0, "BowlBenchA")
	_put_deco(StreetBits.bench(2.4), Vector3(-90.0, 0.0, -43.0 + 3.0), 0.0, "BowlBenchB")
	var sg: Node3D = Walls.billboard_sign("SUNSET BEACH SKATEPARK", 12.0)
	_put_deco(sg, Vector3(-88.0, 0.0, -39.4), 180.0, "ParkSign")
	for p: Vector3 in [Vector3(-108.0, 0.0, -38.0), Vector3(-108.5, 0.0, -24.0),
			Vector3(-60.0, 0.0, -21.0), Vector3(-42.0, 0.0, -11.5), Vector3(-108.0, 0.0, -9.8)]:
		_palm(p, 1.0)


## A grindable / solid piece that is not a main line (benches, signs): added but not tracked in `placed`.
func _put_deco(node: Node3D, pos: Vector3, yaw_deg: float, node_name: String) -> Node3D:
	node.position = pos
	node.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	node.name = node_name
	add_child(node)
	return node


## A swaying palm (SwayTrees) with a solid trunk when it stands in the riding area.
func _palm(pos: Vector3, size: float = 0.0) -> void:
	palms.add("palm", pos, size)
	if bounds.grow(2.0).has_point(Vector2(pos.x, pos.z)):
		var sb := StaticBody3D.new()
		sb.name = "PalmTrunk"
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.26
		cyl.height = 5.0
		cs.shape = cyl
		cs.position = Vector3(0.25, 2.5, 0.0)
		sb.add_child(cs)
		sb.position = pos
		add_child(sb)


# --- the boardwalk ---------------------------------------------------------------------------------------

func _boardwalk() -> void:
	put(Buildings.shop(12.0, 8.0, 4.0, Color("1fb3c4"), "SURF SHOP"), Vector3(-30.0, 0.0, WALK_S_Z1), 0.0, "SurfShop")
	put(Buildings.shop(10.0, 8.0, 4.0, Color("ff7a5c"), "PIZZA"), Vector3(-14.0, 0.0, WALK_S_Z1), 0.0, "PizzaShack")
	put(Buildings.roof_access_ramp(4.0, 10.0, 4.0), Vector3(-30.0, 0.0, WALK_S_Z1), -90.0, "RoofRamp")
	add_child(PieceKit.gap_zone("roof_surf", Vector3(-21.5, 4.0, -39.0), Vector3(3.0, 3.0, 6.0)))
	add_child(PieceKit.gap_zone("roof_pizza", Vector3(-13.5, 4.0, -39.0), Vector3(3.0, 3.0, 6.0)))
	put(Buildings.shop(14.0, 8.0, 4.5, Color("8f6fe0"), "ARCADE"), Vector3(24.0, 0.0, WALK_S_Z1), 0.0, "Arcade")
	put(Buildings.shop(10.0, 7.0, 3.6, Color("ffc94a"), "RENTALS"), Vector3(64.0, 0.0, WALK_S_Z1), 0.0, "Rentals")
	put(Buildings.shop(12.0, 8.0, 4.0, Color("ff8fb1"), "ICE CREAM"), Vector3(90.0, 0.0, WALK_S_Z1), 0.0, "IceCream")
	# food stands, a cart and racks in the row in front of the shops
	var stand_tints: Array[Color] = [Color("ff6b5e"), Color("1aa6b7"), Color("f2a33a"), Color("5fcf80")]
	var k: int = 0
	for x: float in [3.0, 9.0, 15.0, 80.0]:
		kit.place(self, "food_stand", Vector3(x, 0.0, -37.0), PI, {"tint": stand_tints[k % stand_tints.size()], "name": "FoodStand%d" % k})
		k += 1
	_put_deco(Props.ice_cream_cart(), Vector3(20.0, 0.0, -35.0), 180.0, "IceCreamCart")
	kit.place(self, "surfboard_rack", Vector3(-32.5, 0.0, -31.4), 0.0, {"name": "RackShop"})
	kit.place(self, "surfboard_rack", Vector3(75.5, 0.0, -31.8), 0.0, {"name": "RackRentals"})
	for p: Vector3 in [Vector3(1.0, 0.0, -33.5), Vector3(12.0, 0.0, -33.5), Vector3(84.0, 0.0, -34.0)]:
		_put_deco(Props.picnic_table(), p, 0.0, "Picnic")
	# street furniture on the boardwalk: two flat rails in a row, a manual pad, round palm planters
	put(StreetBits.flat_rail(8.0, 0.45, "", ""), Vector3(-31.0, 0.0, -21.0), 90.0, "BoardRailA")
	put(StreetBits.flat_rail(8.0, 0.45, "", ""), Vector3(-19.0, 0.0, -21.0), 90.0, "BoardRailB")
	add_child(PieceKit.gap_zone("bw_rail_a", Vector3(-24.5, 0.45, -22.0), Vector3(1.5, 1.5, 1.0)))
	add_child(PieceKit.gap_zone("bw_rail_b", Vector3(-19.0, 0.45, -22.0), Vector3(1.5, 1.5, 1.0)))
	put(StreetBits.manual_pad(7.0, 2.5, 0.3, "bw_pad_a", "bw_pad_b"), Vector3(40.0, 0.0, -21.5), 90.0, "ManualPad")
	put(StreetBits.ledge(8.0, 0.5, 0.8, Color("3fb6c8"), ""), Vector3(64.0, 0.0, -19.0), 90.0, "BoardLedge")
	for p: Vector3 in [Vector3(-12.0, 0.0, -25.0), Vector3(18.0, 0.0, -25.0), Vector3(30.0, 0.0, -17.0), Vector3(80.0, 0.0, -22.0), Vector3(100.0, 0.0, -25.0)]:
		_planter_palm(p)
	# benches facing the sea along the seawall walk
	var b: int = 0
	for x: float in [-30.0, -21.0, 16.0, 22.0, 42.0, 66.0, 74.0, 100.0]:
		_put_deco(StreetBits.bench(2.4), Vector3(x, 0.0, -15.0), 0.0, "Bench%d" % b)
		b += 1
	# the Beach Launch: a kicker aimed out over the seawall ledge and onto the sand
	put(Kicker.build(2.4, 2.4, 1.0), Vector3(35.2, 0.0, -11.0), 180.0, "LaunchKicker")
	add_child(PieceKit.gap_zone("launch_lip", Vector3(32.8, 0.6, -11.6), Vector3(2.4, 2.5, 1.2)))
	add_child(PieceKit.gap_zone("launch_sand", Vector3(29.0, SAND_Y, -8.0), Vector3(10.0, 2.0, 17.0)))
	for p: Vector3 in [Vector3(-36.0, 0.0, -41.6), Vector3(-6.0, 0.0, -41.6), Vector3(22.0, 0.0, -41.6), Vector3(48.0, 0.0, -41.6), Vector3(62.0, 0.0, -41.6),
			Vector3(88.0, 0.0, -41.6), Vector3(106.0, 0.0, -41.6), Vector3(46.0, 0.0, -12.0), Vector3(60.0, 0.0, -12.0), Vector3(-2.0, 0.0, -12.0)]:
		_palm(p)


## A round concrete planter (grindable rim) with a palm in it.
func _planter_palm(p: Vector3) -> void:
	var r: float = 1.1
	var h: float = 0.5
	var sb := StaticBody3D.new()
	sb.name = "Planter"
	sb.collision_layer = 1
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 1.04
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.position.y = h * 0.5
	mi.material_override = Toon.material(Color("e9dcc6"), false)
	sb.add_child(mi)
	var soil := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = r - 0.12
	sm.bottom_radius = r - 0.12
	sm.height = 0.04
	sm.radial_segments = 16
	soil.mesh = sm
	soil.position.y = h + 0.005
	soil.material_override = Toon.material(Color("7a5536"), false)
	sb.add_child(soil)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = h
	cs.shape = cyl
	cs.position.y = h * 0.5
	sb.add_child(cs)
	var ring := PackedVector3Array()
	for i: int in 17:
		var a: float = TAU * float(i) / 16.0
		ring.append(Vector3(cos(a) * (r - 0.04), h, sin(a) * (r - 0.04)))
	sb.add_child(PieceKit.rail(ring, "ledge", "Rim"))
	sb.position = p
	add_child(sb)
	palms.add("palm", p + Vector3(0.0, h, 0.0), 0.9)
	var trunk := CollisionShape3D.new()
	var tc := CylinderShape3D.new()
	tc.radius = 0.26
	tc.height = 4.5
	trunk.shape = tc
	trunk.position = Vector3(0.2, h + 2.25, 0.0)
	sb.add_child(trunk)


# --- the seawall -----------------------------------------------------------------------------------------

func _seawall() -> void:
	var root := Node3D.new()
	root.name = "SeawallLedges"
	add_child(root)
	var z0: float = SEAWALL_Z - LEDGE_D
	var i: int = 0
	for seg: Array in LEDGES:
		var x0: float = float(seg[0])
		var x1: float = float(seg[1])
		var body: StaticBody3D = PieceKit.box(Vector3(x0, 0.0, z0), Vector3(x1 - x0, LEDGE_H, LEDGE_D), LEDGE_CAP, "Ledge%d" % i)
		WorldSurface.apply(body, "concrete", LEDGE_CAP, 0.4)
		root.add_child(body)
		root.add_child(PieceKit.rail(PackedVector3Array([Vector3(x0, LEDGE_H, z0), Vector3(x1, LEDGE_H, z0)]), "ledge", "LedgeBack%d" % i))
		root.add_child(PieceKit.rail(PackedVector3Array([Vector3(x0, LEDGE_H, SEAWALL_Z), Vector3(x1, LEDGE_H, SEAWALL_Z)]), "ledge", "LedgeSea%d" % i))
		root.add_child(PieceKit.gap_zone("seawall_top", Vector3(x0, LEDGE_H, z0 - 0.2), Vector3(x1 - x0, 1.6, LEDGE_D + 0.4)))
		i += 1
	# the long slides: zones at both ends of the two long ledges
	root.add_child(PieceKit.gap_zone("seawall_w", Vector3(-56.0, LEDGE_H, z0 - 0.4), Vector3(3.0, 1.6, LEDGE_D + 0.8)))
	root.add_child(PieceKit.gap_zone("seawall_e", Vector3(-15.0, LEDGE_H, z0 - 0.4), Vector3(3.0, 1.6, LEDGE_D + 0.8)))
	root.add_child(PieceKit.gap_zone("ledge_pier_a", Vector3(12.0, LEDGE_H, z0 - 0.4), Vector3(3.0, 1.6, LEDGE_D + 0.8)))
	root.add_child(PieceKit.gap_zone("ledge_pier_b", Vector3(47.0, LEDGE_H, z0 - 0.4), Vector3(3.0, 1.6, LEDGE_D + 0.8)))
	# the sand in front of the seawall
	root.add_child(PieceKit.gap_zone("sand_front", Vector3(-HALF_X, SAND_Y, SEAWALL_Z + 0.6), Vector3(HALF_X * 2.0, 1.6, 6.0)))
	# the way down: a bank and the lifeguard stairs (from the deck to the sand), and a bank at the east end
	put(Walls.bank(8.0, 4.0, -SAND_Y, ""), Vector3(-12.0, SAND_Y, SEAWALL_Z), 0.0, "BankSandMid")
	put(StairSet.build(6.0, 1.5, 5, 0.24, 0.45, "bw_stairs"), Vector3(6.0, SAND_Y, SEAWALL_Z), 0.0, "Stairs")
	# a longer landing strip on the sand: a fast ollie off the top clears the piece's own bottom zone
	add_child(PieceKit.gap_zone("bw_stairs_bottom", Vector3(6.0, SAND_Y, -2.25), Vector3(6.0, 1.5, 5.0)))
	put(Walls.bank(8.0, 4.0, -SAND_Y, ""), Vector3(86.0, SAND_Y, SEAWALL_Z), 0.0, "BankSandEast2")


# --- the beach -------------------------------------------------------------------------------------------

func _beach() -> void:
	var y: float = SAND_Y
	for t: Array in [[Vector3(-60.0, y, 6.0), 0], [Vector3(24.0, y, 8.0), 1], [Vector3(92.0, y, 6.0), 2]]:
		kit.place(self, "lifeguard_tower", t[0] as Vector3, PI, {"name": "LifeguardTower%d" % int(t[1])})
	var umb: Array[Vector3] = [Vector3(-44.0, y, 4.0), Vector3(-30.0, y, 12.0), Vector3(-8.0, y, 16.0), Vector3(8.0, y, 10.0),
		Vector3(40.0, y, 14.0), Vector3(66.0, y, 9.0), Vector3(74.0, y, 17.0), Vector3(102.0, y, 12.0), Vector3(-80.0, y, 10.0),
		Vector3(-96.0, y, 15.0), Vector3(-70.0, y, 19.0), Vector3(12.0, y, 20.0)]
	for i: int in umb.size():
		kit.place(self, "umbrella_towel_set", umb[i], float(i) * 1.3, {"name": "Umbrella%d" % i, "shadow": true})
	kit.place(self, "surfboard_rack", Vector3(-55.0, y, 2.5), PI, {"name": "RackTower0"})
	kit.place(self, "surfboard_rack", Vector3(29.0, y, 4.0), PI, {"name": "RackTower1"})
	# rocks at the west end of the beach and round the pier's foot
	var rocks: Array = [[Vector3(-104.0, y, 22.0), 1.4], [Vector3(-99.0, y, 26.0), 1.0], [Vector3(-106.0, y, 30.0), 1.8],
		[Vector3(61.0, y, 24.0), 0.9], [Vector3(46.0, y, 28.0), 1.1]]
	for r: Array in rocks:
		kit.place(self, "rocks", r[0] as Vector3, float((r[0] as Vector3).x) * 0.37, {"scale": float(r[1]), "name": "Rocks"})
	# Rock Hop: a kicker on the sand aimed (+X) over a low, half-buried reef (no collision: a short hop must not
	# hang the board on a rock)
	put(Kicker.build(2.4, 2.8, 1.3), Vector3(-14.0, y, 20.0), -90.0, "RockKicker")
	for k: int in 2:
		kit.place(self, "rocks", Vector3(-12.9 + float(k) * 1.1, y, 20.4 + float(k) * 1.2), float(k), {"scale": 0.45, "name": "ReefRocks", "collide": false})
	add_child(PieceKit.gap_zone("rock_kick", Vector3(-15.0, y + 0.6, 19.8), Vector3(1.2, 2.5, 2.8)))
	add_child(PieceKit.gap_zone("rock_land", Vector3(-11.0, y, 18.5), Vector3(9.0, 2.0, 5.5)))
	_driftwood(Vector3(-42.0, y, 14.0), 7.0)
	_volleyball(Vector3(-24.0, y, 6.0))
	for p: Vector3 in [Vector3(-84.0, y, -4.0), Vector3(-48.0, y, -3.0), Vector3(-26.0, y, -4.0), Vector3(70.0, y, -4.0), Vector3(104.0, y, -3.5), Vector3(118.0, y, -3.0),
			Vector3(-118.0, y, -4.0), Vector3(-130.0, y, -2.0), Vector3(134.0, y, -2.5)]:
		_palm(p, 1.15)


## A bleached driftwood log lying along X: solid, with a grind line along its top.
func _driftwood(p: Vector3, length: float) -> void:
	var r: float = 0.32
	var sb := StaticBody3D.new()
	sb.name = "Driftwood"
	sb.collision_layer = 1
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.85
	cm.bottom_radius = r
	cm.height = length
	cm.radial_segments = 10
	mi.mesh = cm
	mi.rotation.z = PI * 0.5
	mi.material_override = Toon.material(Color("c9b291"), false)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = length
	cs.shape = cyl
	cs.rotation.z = PI * 0.5
	sb.add_child(cs)
	sb.add_child(PieceKit.rail(PackedVector3Array([Vector3(-length * 0.5, r, 0.0), Vector3(length * 0.5, r, 0.0)]), "rail", "LogTop"))
	sb.position = p + Vector3(0.0, r - 0.08, 0.0)
	add_child(sb)


## A beach volleyball net between two solid poles (along Z), visual net.
func _volleyball(p: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Volleyball"
	root.position = p
	add_child(root)
	for dz: float in [-4.5, 4.5]:
		var sb := StaticBody3D.new()
		sb.name = "Pole"
		sb.collision_layer = 1
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.06
		cm.height = 2.6
		cm.radial_segments = 8
		mi.mesh = cm
		mi.position.y = 1.3
		mi.material_override = Toon.material(Color("f4f1e8"), false)
		sb.add_child(mi)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.08
		cyl.height = 2.6
		cs.shape = cyl
		cs.position.y = 1.3
		sb.add_child(cs)
		sb.position = Vector3(0.0, 0.0, dz)
		root.add_child(sb)
	var net := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(9.0, 0.9)
	net.mesh = qm
	net.rotation.y = PI * 0.5
	net.position = Vector3(0.0, 2.05, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.15, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	net.material_override = mat
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(net)
	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, 0.08, 9.0)
	band.mesh = bm
	band.position = Vector3(0.0, 2.5, 0.0)
	band.material_override = Toon.material(Color("f4f1e8"), false)
	root.add_child(band)


# --- the pier --------------------------------------------------------------------------------------------

func _pier() -> void:
	var root := Node3D.new()
	root.name = "Pier"
	add_child(root)
	placed.append(root)
	var w: float = PIER_X1 - PIER_X0
	var decks: Array[Rect2] = [
		Rect2(PIER_X0, SEAWALL_Z, w, PIER_GAP_Z0 - SEAWALL_Z),
		Rect2(PIER_X0, PIER_GAP_Z1, w, PIER_PLAT_Z - PIER_GAP_Z1),
		Rect2(PIER_X0 - 6.0, PIER_PLAT_Z, w + 12.0, Z_MAX + 1.0 - PIER_PLAT_Z),
	]
	var k: int = 0
	for r: Rect2 in decks:
		var sb: StaticBody3D = PieceKit.box(Vector3(r.position.x, -DECK_T, r.position.y), Vector3(r.size.x, DECK_T, r.size.y), PLANKS, "Deck%d" % k)
		WorldSurface.apply(sb, "planks", PLANKS, 1.25)
		root.add_child(sb)
		k += 1
	# the joist across the missing planks: a narrow beam you can grind or roll
	var joist: StaticBody3D = PieceKit.box(Vector3(53.88, -DECK_T, PIER_GAP_Z0 - 0.2), Vector3(0.24, DECK_T, PIER_GAP_Z1 - PIER_GAP_Z0 + 0.4), Color("8a6440"), "Joist")
	root.add_child(joist)
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(54.0, 0.0, PIER_GAP_Z0 - 0.2), Vector3(54.0, 0.0, PIER_GAP_Z1 + 0.2)]), "rail", "JoistRail"))
	root.add_child(PieceKit.gap_zone("pier_gap_a", Vector3(PIER_X0, 0.0, PIER_GAP_Z0 - 3.0), Vector3(w, 3.0, 3.0)))
	root.add_child(PieceKit.gap_zone("pier_gap_b", Vector3(PIER_X0, 0.0, PIER_GAP_Z1), Vector3(w, 3.0, 3.0)))
	# railings with a grind line along the top, both sides of the long deck, and round the end platform
	var runs: Array = [
		[Vector3(PIER_X0 + 0.1, 0.0, -6.0), Vector3(PIER_X0 + 0.1, 0.0, PIER_PLAT_Z)],
		[Vector3(PIER_X1 - 0.1, 0.0, -6.0), Vector3(PIER_X1 - 0.1, 0.0, PIER_PLAT_Z)],
		[Vector3(PIER_X0 - 5.9, 0.0, PIER_PLAT_Z + 0.1), Vector3(PIER_X0 - 5.9, 0.0, Z_MAX - 0.5)],
		[Vector3(PIER_X1 + 5.9, 0.0, PIER_PLAT_Z + 0.1), Vector3(PIER_X1 + 5.9, 0.0, Z_MAX - 0.5)],
		[Vector3(PIER_X0 - 5.9, 0.0, PIER_PLAT_Z + 0.1), Vector3(PIER_X0 - 0.2, 0.0, PIER_PLAT_Z + 0.1)],
		[Vector3(PIER_X1 + 0.2, 0.0, PIER_PLAT_Z + 0.1), Vector3(PIER_X1 + 5.9, 0.0, PIER_PLAT_Z + 0.1)],
	]
	var posts: Array[Transform3D] = []
	for i: int in runs.size():
		var a: Vector3 = runs[i][0]
		var b: Vector3 = runs[i][1]
		root.add_child(_railing(a, b, "Railing%d" % i, posts))
	root.add_child(PieceKit.gap_zone("pier_rail_a", Vector3(PIER_X0 - 0.6, 0.6, -6.0), Vector3(w + 1.2, 1.4, 4.0)))
	root.add_child(PieceKit.gap_zone("pier_rail_b", Vector3(PIER_X0 - 0.6, 0.6, 40.0), Vector3(w + 1.2, 1.4, 4.0)))
	# zones for the drop off the side of the pier onto the sand
	for x: float in [PIER_X0 - 0.4, PIER_X1 + 0.4]:
		root.add_child(PieceKit.gap_zone("pier_side", Vector3(x - 0.5, 0.4, -6.0), Vector3(1.0, 2.0, 28.0)))
	for x: float in [PIER_X0 - 9.0, PIER_X1 + 1.5]:
		root.add_child(PieceKit.gap_zone("pier_sand", Vector3(x, SAND_Y - 0.5, -6.0), Vector3(7.5, 2.0, 30.0)))
	var pm := MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	var post := BoxMesh.new()
	post.size = Vector3(0.1, PIER_RAIL_H, 0.1)
	pm.mesh = post
	pm.instance_count = posts.size()
	for i: int in posts.size():
		pm.set_instance_transform(i, posts[i])
	var pmi := MultiMeshInstance3D.new()
	pmi.name = "RailPosts"
	pmi.multimesh = pm
	pmi.material_override = Toon.material(Color("f4f1e8"), false)
	root.add_child(pmi)
	_pilings(root)
	# the end of the pier: a quarter pipe facing the shore for big air, a bait shack, benches
	put(QuarterPipe.build(12.0, 3.4, 3.6, 1.5), Vector3(60.0, 0.0, Z_MAX - 0.6), 180.0, "PierQuarter")
	add_child(PieceKit.gap_zone("pier_qp_lip", Vector3(48.0, 2.0, Z_MAX - 3.6), Vector3(12.0, 1.6, 1.6)))
	add_child(PieceKit.gap_zone("pier_qp_air", Vector3(48.0, 3.5, Z_MAX - 4.0), Vector3(12.0, 4.0, 2.8)))
	var shack: StaticBody3D = PieceKit.box(Vector3(PIER_X0 - 5.6, 0.0, PIER_PLAT_Z + 0.8), Vector3(3.4, 2.8, 4.0), Color("f4f1e8"), "BaitShack")
	root.add_child(shack)
	var roof: StaticBody3D = PieceKit.box(Vector3(PIER_X0 - 5.9, 2.8, PIER_PLAT_Z + 0.5), Vector3(4.0, 0.25, 4.6), Color("1aa6b7"), "BaitRoof")
	root.add_child(roof)
	root.add_child(BeachTown.sign_label("BAIT", Color("ff6b5e"), Vector3(PIER_X0 - 2.1, 1.9, PIER_PLAT_Z + 2.8), PI * 0.5, 64))
	_put_deco(StreetBits.bench(2.4), Vector3(PIER_X1 + 2.0, 0.0, PIER_PLAT_Z + 1.0), 180.0, "PierBench")
	for p: Vector3 in [Vector3(PIER_X0 - 5.6, 0.0, Z_MAX - 1.2), Vector3(PIER_X1 + 5.6, 0.0, Z_MAX - 1.2), Vector3(PIER_X1 + 5.6, 0.0, PIER_PLAT_Z + 0.4)]:
		_put_deco(Props.lamp_post(), p, 0.0, "PierLamp")


## A pier railing from a to b (deck level): a solid thin wall up to the top rail, a round top pipe with its grind line,
## and posts (appended to `posts` for one MultiMesh).
func _railing(a: Vector3, b: Vector3, node_name: String, posts: Array[Transform3D]) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var top_a: Vector3 = a + Vector3(0.0, PIER_RAIL_H, 0.0)
	var top_b: Vector3 = b + Vector3(0.0, PIER_RAIL_H, 0.0)
	var pipe: Node3D = PieceKit.round_rail(top_a, top_b, 0.045, Color("f4f1e8"), "TopRail")
	root.add_child(pipe)
	var mid: Node3D = PieceKit.round_rail(a + Vector3(0.0, 0.5, 0.0), b + Vector3(0.0, 0.5, 0.0), 0.025, Color("f4f1e8"), "MidRail")
	mid.get_node("Line").queue_free()
	root.add_child(mid)
	var sb := StaticBody3D.new()
	sb.name = "Guard"
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var along: Vector3 = b - a
	var flat_x: bool = absf(along.x) > absf(along.z)
	box.size = Vector3(along.length() if flat_x else 0.12, PIER_RAIL_H - 0.08, 0.12 if flat_x else along.length())
	cs.shape = box
	cs.position = (a + b) * 0.5 + Vector3(0.0, (PIER_RAIL_H - 0.08) * 0.5, 0.0)
	sb.add_child(cs)
	root.add_child(sb)
	var n: int = maxi(int(along.length() / 2.5), 1)
	for i: int in n + 1:
		var p: Vector3 = a.lerp(b, float(i) / float(n))
		posts.append(Transform3D(Basis.IDENTITY, p + Vector3(0.0, PIER_RAIL_H * 0.5, 0.0)))
	return root


## Pilings under the pier (one MultiMesh) with collision where they stand in the sand or the shallows.
func _pilings(root: Node3D) -> void:
	var xs: Array[Transform3D] = []
	var z: float = -4.0
	while z < Z_MAX:
		var xs_row: Array[float] = [PIER_X0 + 0.4, PIER_X1 - 0.4]
		if z > PIER_PLAT_Z:
			xs_row = [PIER_X0 - 5.6, PIER_X0 + 0.4, PIER_X1 - 0.4, PIER_X1 + 5.6]
		for x: float in xs_row:
			xs.append(Transform3D(Basis.IDENTITY, Vector3(x, -DECK_T - 4.5, z)))
			if z < SHORE_Z + 6.0:
				var sb := StaticBody3D.new()
				sb.name = "Piling"
				sb.collision_layer = 1
				var cs := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 0.24
				cyl.height = 9.0
				cs.shape = cyl
				sb.add_child(cs)
				sb.position = Vector3(x, -DECK_T - 4.5, z)
				root.add_child(sb)
		z += 4.0
	var cm := CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.26
	cm.height = 9.0
	cm.radial_segments = 8
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cm
	mm.instance_count = xs.size()
	for i: int in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Pilings"
	mmi.multimesh = mm
	mmi.material_override = Toon.material(Color("6f5238"), false)
	root.add_child(mmi)
	# cross beams under the deck (visual)
	var beams := MultiMesh.new()
	beams.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(PIER_X1 - PIER_X0 + 0.4, 0.3, 0.3)
	beams.mesh = bm
	var bx: Array[Transform3D] = []
	var bz: float = -4.0
	while bz < PIER_PLAT_Z:
		bx.append(Transform3D(Basis.IDENTITY, Vector3((PIER_X0 + PIER_X1) * 0.5, -DECK_T - 0.15, bz)))
		bz += 4.0
	beams.instance_count = bx.size()
	for i: int in bx.size():
		beams.set_instance_transform(i, bx[i])
	var bmi := MultiMeshInstance3D.new()
	bmi.name = "Beams"
	bmi.multimesh = beams
	bmi.material_override = Toon.material(Color("5e4430"), false)
	root.add_child(bmi)


# --- the coast road --------------------------------------------------------------------------------------

func _road() -> void:
	var root := Node3D.new()
	root.name = "RoadDressing"
	add_child(root)
	# lane lines: a double yellow centre line and white edge lines (visual strips)
	var strips: Array = [
		[Vector3(0.0, 0.012, -52.0 - 0.12), Vector3(840.0, 0.02, 0.12), Color("f2c230")],
		[Vector3(0.0, 0.012, -52.0 + 0.12), Vector3(840.0, 0.02, 0.12), Color("f2c230")],
		[Vector3(0.0, 0.012, ROAD_Z1 - 2.5), Vector3(840.0, 0.02, 0.12), Color("eeeeea")],
		[Vector3(0.0, 0.012, ROAD_Z0 + 2.5), Vector3(840.0, 0.02, 0.12), Color("eeeeea")],
	]
	for s: Array in strips:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s[1] as Vector3
		mi.mesh = bm
		mi.position = s[0] as Vector3
		mi.material_override = Toon.material(s[2] as Color, false)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	# a zebra crossing at x = -2
	for i: int in 8:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.2, 0.02, 0.6)
		bar.mesh = bm
		bar.position = Vector3(-2.0, 0.013, ROAD_Z0 + 1.2 + float(i) * 1.9)
		bar.material_override = Toon.material(Color("eeeeea"), false)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bar)
	# parked surf vans and cars in the parking strips
	var vans: Array = [
		["van", Color("ff8a3d"), Vector3(-92.0, 0.0, ROAD_Z1 - 1.25), PI * 0.5], ["van", Color("4fd1c5"), Vector3(-60.0, 0.0, ROAD_Z1 - 1.25), PI * 0.5],
		["hatch", Color("f2c94c"), Vector3(-30.0, 0.0, ROAD_Z1 - 1.25), PI * 0.5], ["van", Color("f4f0e6"), Vector3(18.0, 0.0, ROAD_Z1 - 1.25), PI * 0.5],
		["pickup", Color("b3262d"), Vector3(40.0, 0.0, ROAD_Z1 - 1.25), PI * 0.5], ["van", Color("ff8ec7"), Vector3(76.0, 0.0, ROAD_Z1 - 1.25), PI * 0.5],
		["van", Color("7ec8e3"), Vector3(-76.0, 0.0, ROAD_Z0 + 1.25), -PI * 0.5], ["hatch", Color("3d7a5a"), Vector3(-14.0, 0.0, ROAD_Z0 + 1.25), -PI * 0.5],
		["van", Color("ffd23f"), Vector3(30.0, 0.0, ROAD_Z0 + 1.25), -PI * 0.5], ["van", Color("ff6b5e"), Vector3(96.0, 0.0, ROAD_Z0 + 1.25), -PI * 0.5],
	]
	for v: Array in vans:
		var car: StaticBody3D = BeachTown.parked(str(v[0]), v[1] as Color, v[2] as Vector3, float(v[3]))
		root.add_child(car)
		if str(v[0]) == "van":
			var board: MeshInstance3D = BeachTown.surfboard(2.3, Color("fff3d6") if int((v[2] as Vector3).x) % 2 == 0 else Color("ff5a8a"))
			board.position = Vector3(0.0, (car.get_child(0) as CarModel).aabb.end.y + 0.06, 0.0)
			car.add_child(board)
	# palms along both sidewalks, the town beyond and the hills behind it
	var x: float = -300.0
	while x <= 300.0:
		_palm(Vector3(x + 3.0, 0.0, ROAD_Z1 + 1.6), 1.1)
		_palm(Vector3(x - 4.0, 0.0, ROAD_Z0 - 1.8), 1.0)
		x += 14.0
	add_child(BeachTown.town(-420.0, 420.0, ROAD_Z0 - 9.5, 4071, [-268.0, 268.0]))
	add_child(BeachTown.hills(0.0, -470.0, 911))
	traffic = BeachTown.traffic(EAST_LANE_Z, WEST_LANE_Z, -140.0, 260.0)
	add_child(traffic)


# --- the bay ---------------------------------------------------------------------------------------------

func _bay() -> void:
	kit.place(self, "headland_left", Vector3(-330.0, SEA_Y - 6.0, SHORE_Z + 150.0), deg_to_rad(-40.0), {"collide": false, "scale": 3.0, "shadow": false})
	kit.place(self, "headland_right", Vector3(350.0, SEA_Y - 6.0, SHORE_Z + 120.0), deg_to_rad(35.0), {"collide": false, "scale": 3.0, "shadow": false})
	kit.place(self, "distant_island", Vector3(-160.0, SEA_Y - 0.5, SHORE_Z + 760.0), 0.2, {"collide": false, "scale": 2.6, "shadow": false})
	kit.place(self, "distant_island", Vector3(420.0, SEA_Y - 0.5, SHORE_Z + 1100.0), 2.4, {"collide": false, "scale": 1.8, "shadow": false})
	var boats := BeachTown.Boats.new()
	boats.name = "Sailboats"
	add_child(boats)
	var spots: Array = [[Vector3(30.0, SEA_Y - 0.3, SHORE_Z + 150.0), 70.0], [Vector3(-70.0, SEA_Y - 0.3, SHORE_Z + 230.0), -40.0],
		[Vector3(150.0, SEA_Y - 0.3, SHORE_Z + 320.0), 100.0], [Vector3(-180.0, SEA_Y - 0.3, SHORE_Z + 420.0), 20.0], [Vector3(80.0, SEA_Y - 0.3, SHORE_Z + 520.0), -80.0]]
	for i: int in spots.size():
		var s: Array = spots[i]
		var b: Node3D = kit.place(boats, "sailboat", s[0] as Vector3, deg_to_rad(float(s[1])), {"collide": false, "shadow": false, "scale": 1.4, "name": "Sailboat%d" % i})
		boats.boats.append(b)
		boats.base.append(s[0] as Vector3)
		boats.speed.append(1.0 + float(i) * 0.3)
	add_child(Birds.flock("gull", 9, Vector3(54.0, 9.0, 50.0), 26.0, 5))
	add_child(Birds.flock("gull", 6, Vector3(-40.0, 8.0, 10.0), 22.0, 8))
	add_child(Birds.flock("gull", 10, Vector3(-20.0, 14.0, 120.0), 50.0, 13))


# --- life ------------------------------------------------------------------------------------------------

func _life() -> void:
	crowd = Pedestrians.new()
	crowd.name = "Pedestrians"
	crowd.seed_value = 23
	add_child(crowd)
	var carry := BeachTown.SurfCarry.new()
	carry.name = "SurfCarry"
	add_child(carry)
	# the crowd's hair and body meshes come in dozens of single-material surfaces: one surface each keeps the draw
	# calls of the crowd (19 people) inside the street-level budget
	var trim := BeachMerge.PedTrim.new()
	trim.name = "PedTrim"
	trim.crowd = crowd
	add_child(trim)
	# the boardwalk promenade (in front of the shops) and the seawall walk
	var prom: Array[Pedestrian] = crowd.add_walkers(LanePath.from_points(PackedVector3Array([Vector3(-36.0, 0.0, -29.6), Vector3(106.0, 0.0, -29.6)]), false), 4)
	carry.who.append(prom[1])
	carry.who.append(prom[3])
	crowd.add_walkers(LanePath.from_points(PackedVector3Array([Vector3(-34.0, 0.0, -10.6), Vector3(106.0, 0.0, -10.6)]), false), 1)
	crowd.add_walkers(LanePath.from_points(PackedVector3Array([Vector3(-36.0, 0.0, -9.9), Vector3(106.0, 0.0, -9.9)]), false), 2, 2.6, 3.1)  # joggers
	# sidewalks and the zebra crossing
	crowd.add_walkers(LanePath.from_points(PackedVector3Array([Vector3(-100.0, 0.0, ROAD_Z1 + 2.6), Vector3(100.0, 0.0, ROAD_Z1 + 2.6)]), false), 1)
	crowd.add_walkers(LanePath.from_points(PackedVector3Array([Vector3(-2.0, 0.0, ROAD_Z1 + 1.0), Vector3(-2.0, 0.0, ROAD_Z0 - 2.0)]), false), 1, 1.0, 1.2)
	# the pier: a stroller and two fishers at the end
	crowd.add_walkers(LanePath.from_points(PackedVector3Array([Vector3(54.0, 0.0, -4.0), Vector3(54.0, 0.0, PIER_GAP_Z0 - 2.0)]), false), 1)
	crowd.add_idler(Vector3(PIER_X0 - 5.0, 0.0, Z_MAX - 8.0), -PI * 0.5, "idle")
	crowd.add_idler(Vector3(PIER_X1 + 5.0, 0.0, Z_MAX - 9.5), PI * 0.5, "phone")
	# the beach: a group by the umbrellas, a couple, a surfer walking the wet sand
	crowd.add_group(Vector3(-36.0, SAND_Y, 8.0), 3)
	crowd.add_group(Vector3(70.0, SAND_Y, 13.0), 2)
	var shore_y: float = SEA_Y + Ocean.sand_height(-12.5, ocean.beach_slope, BERM)
	var wet: Array[Pedestrian] = crowd.add_walkers(LanePath.from_points(PackedVector3Array([Vector3(-100.0, shore_y, SHORE_Z - 12.5), Vector3(100.0, shore_y, SHORE_Z - 12.5)]), false), 1)
	carry.who.append(wet[0])
	# a skatepark spectator
	crowd.add_idler(Vector3(-79.0, 0.0, -42.4), 0.0, "phone")


# --- draw calls ---

## Prop kinds drawn as one set (see _merge_all) though their nodes have different names.
const MERGE_KINDS: Dictionary = {"SurfShop": "Shop", "Rentals": "Shop", "PizzaShack": "Shop", "IceCream": "Shop",
	"Arcade": "Shop", "RackShop": "Rack", "RackRentals": "Rack", "RackTower": "Rack", "IceCreamCart": "FoodStand"}


## Bakes each static prop's meshes into one (BeachMerge): benches, stands, shops, ramps, the pier, the road dressing.
func _merge_all() -> void:
	var skip: Array[String] = ["Ocean", "Palms", "Pedestrians", "Traffic", "Town", "Hills", "Sailboats", "Environment", "Sun",
		"SnakeRun", "Boundary", "SurfCarry", "TownGround"]
	# repeated props (Umbrella0..11, FoodStand0..3, Bench..) are gathered under one node first, so each kind costs
	# one draw per material however many there are
	var kinds: Dictionary = {}
	for c: Node in get_children():
		if not (c is Node3D) or c is Collectible or c is Birds or skip.has(str(c.name)):
			continue
		var kind: String = str(c.name).rstrip("0123456789")
		kind = str(MERGE_KINDS.get(kind, kind))
		if not kinds.has(kind):
			kinds[kind] = []
		(kinds[kind] as Array).append(c)
	for kind: String in kinds:
		var members: Array = kinds[kind]
		var host: Node3D = members[0] as Node3D
		if members.size() > 1:
			host = Node3D.new()
			host.name = kind + "Set"
			add_child(host)
			for m: Variant in members:
				(m as Node3D).reparent(host, true)
		if host.find_children("*", "MeshInstance3D", true, false).size() > 1:
			BeachMerge.merge(host)


# --- collectibles ----------------------------------------------------------------------------------------

func _collectibles() -> void:
	var mid: Array = snake.at(snake.length * 0.5)
	var m: Vector2 = mid[0]
	add_collectible("S", "skate", Vector3(m.x, -BeachSnake.DEPTH + 1.0, m.y))
	add_collectible("K", "skate", Vector3(BOWL_RECT.get_center().x, -1.3, BOWL_RECT.get_center().y))
	add_collectible("A", "skate", Vector3(54.0, 6.4, Z_MAX - 2.4))
	add_collectible("T", "skate", Vector3(34.0, 1.6, -5.0))
	add_collectible("E", "skate", Vector3(PIER_X0 + 0.1, PIER_RAIL_H + 0.6, 40.0))
	for p: Vector3 in [Vector3(2.0, 1.0, -31.0), Vector3(-25.0, 1.2, -21.5), Vector3(44.0, 1.3, -20.25), Vector3(-47.5, 2.4, -19.5),
			Vector3(54.0, 1.2, (PIER_GAP_Z0 + PIER_GAP_Z1) * 0.5)]:
		add_collectible("pizza", "pizza", p)
	add_collectible("TAPE", "secret", Vector3(-8.0, 5.2, -36.0))
