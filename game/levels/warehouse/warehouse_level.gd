class_name WarehouseLevel
extends Level
## Creepy Warehouse: an abandoned industrial complex at night (see README.md here for the layout, lines and gaps).
## Five areas round one core: the main HALL (raised dock-height floor, catwalk ring, DIY quarter pipe, racks, pallet gap,
## forklift, spine), the south LOADING DOCKS and truck court (drained truck-well quarter pipe, dock ledges, trailers),
## the east CONTAINER YARD (container runs and gaps under a gantry crane), the north RAIL SPUR (parked train, tracks,
## bank wall) and the west BOILER YARD (drained settling pit, pipe runs, smokestack). A secret annex hides behind the
## hall's east wall. Outside the fence: a moonlit skyline and an elevated highway with traffic.
## North is -Z. The hall floor and the dock aprons sit at FL (1.2 m, truck-bed height); the yards are at grade (0).
##
## The build is split by area: WhGeo (materials, batching, collision), WhHall (hall, catwalks, annex), WhOutdoor (ground,
## docks, yard, rail, boiler yard), WhLights (lamps, moon shafts), WhWorld (skyline, highway, traffic, people, critters).

const FL: float = 1.2  ## hall floor / dock top
const HALL := Rect2(-40.0, -20.0, 80.0, 40.0)  ## hall interior (x, z)
const WALL_T: float = 0.5
const SLAB := Rect2(-40.5, -26.0, 81.0, 52.0)  ## the raised slab: hall plus the north rail dock and the south dock apron
const ROOF_Y: float = 12.0
const HALF_X: float = 96.0
const NORTH_Z: float = -78.0
const SOUTH_Z: float = 74.0
const SPAWN_POS := Vector3(0.0, FL + 0.1, 17.0)
## The truck well (south dock, centre): a drained ramp that dips under grade to a quarter pipe up to the dock edge.
const WELL := Rect2(-6.0, 26.0, 12.0, 12.5)
const WELL_FLOOR: float = -1.0
## The drained settling pit (boiler yard).
const PIT_POS := Vector3(-84.0, 0.0, -4.0)
const PIT_SIZE := Vector2(16.0, 12.0)
## The secret annex behind the hall's east wall (raised floor like the hall).
const ANNEX := Rect2(40.5, 7.5, 9.5, 13.0)

## Moonlight direction (toward the moon): north, a little east, about 38 degrees up.
const MOON_DIR := Vector3(0.25, 0.8, -1.0)

var traffic: Traffic = null
var crowd: Pedestrians = null
var _kit: LevelKit = null


func _init() -> void:
	spawn = Transform3D(Basis.IDENTITY, SPAWN_POS)  # facing -Z: north, into the hall
	bounds = Rect2(-HALF_X, NORTH_Z, HALF_X * 2.0, SOUTH_Z - NORTH_Z)
	kill_y = Level.DEFAULT_KILL_Y
	gaps_path = "res://game/levels/warehouse/gaps.json"
	goals_path = "res://game/levels/warehouse/goals.json"
	preview_view = [Vector3(30.0, FL + 3.8, 10.0), Vector3(-30.0, FL + 0.8, -5.0)]


func _ready() -> void:
	setup_environment()
	_tune_mood()
	_kit = LevelKit.open("warehouse")
	WhOutdoor.build(self)
	WhHall.build(self)
	WhLights.build(self)
	WhWorld.build(self)
	_pickups()
	_flatten_pieces()
	_trim_shadow_casters()
	add_boundary()
	add_drop_in("catwalk", "Catwalk", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(24.0, 4.4 + FL - 1.2 + 0.1, -19.0)))
	add_drop_in("containers", "Container Run", Transform3D(Basis.IDENTITY, Vector3(62.0, 2.72, -2.0)))


## Park pieces and static props baked into merged meshes (see WhGeo.flatten).
const FLAT_PIECES: Array[String] = ["DIYQuarter", "CatwalkStairs", "ForkKicker", "AnnexQuarter", "DockStairs", "DockBank",
	"WellQuarter", "WellKicker", "NorthBank", "Pit", "PipeKicker", "Mannequin", "Forklift", "ForkPallet"]


func _flatten_pieces() -> void:
	var bt := WhGeo.Batch.new(24.0)
	for n: Node in get_children():
		if str(n.name) in FLAT_PIECES and n is Node3D:
			WhGeo.flatten(n as Node3D, bt)
	bt.commit(self, "PiecesMesh")


## Only the big merged meshes cast moon shadows (the hall walls and roof keep the moonlight out of the hall); lamps,
## props, pickups, cars and clutter skip the shadow pass, which otherwise costs a draw call per surface.
const SHADOW_CASTERS: Array[String] = ["HallMesh", "Roof", "AnnexMesh", "RailMesh", "BoilerMesh", "YardMesh", "CourtMesh",
	"DockMesh", "PiecesMesh", "TruckWellMesh"]


func _trim_shadow_casters() -> void:
	for top: Node in get_children():
		var name_s: String = str(top.name)
		if name_s in SHADOW_CASTERS or name_s.begins_with("Containers_"):
			continue
		var list: Array[Node] = top.find_children("*", "GeometryInstance3D", true, false)
		if top is GeometryInstance3D:
			list.append(top)
		for n: Node in list:
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func kit() -> LevelKit:
	if _kit == null:
		_kit = LevelKit.open("warehouse")
	return _kit


## Moonlit, foggy, sodium-lit: the warehouse_night preset with the moon swung round to the north (over the skyline and
## through the skylights), a lighter fog so the lines read across the hall, and enough cool ambient for the shadows.
func _tune_mood() -> void:
	var d: Vector3 = MOON_DIR.normalized()
	sun.look_at_from_position(Vector3.ZERO, -d, Vector3.UP)
	sun.light_energy = 0.45
	sun.light_color = Color(0.66, 0.74, 0.96)
	sun.directional_shadow_max_distance = 55.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.06
	var env: Environment = world_environment.environment
	var sky_mat: ShaderMaterial = env.sky.sky_material as ShaderMaterial
	if sky_mat != null:
		sky_mat.set_shader_parameter("sun_dir", d)
		sky_mat.set_shader_parameter("cloud_cover", 0.12)
		sky_mat.set_shader_parameter("cloud_lit", Color(0.09, 0.1, 0.15))
		sky_mat.set_shader_parameter("cloud_shaded", Color(0.045, 0.05, 0.08))
	env.fog_density = 0.0045
	# ground fog: thick along the yards (height fog below fog_height), thin above the roofline so the high cameras
	# still read the layout
	env.fog_height = 4.0
	env.fog_height_density = 0.12
	env.fog_light_color = Color(0.1, 0.1, 0.14)
	# ambient: mostly a flat grey-violet, only a little of the blue night sky, so steel and concrete keep their colour
	env.ambient_light_sky_contribution = 0.3
	env.ambient_light_color = Color(0.58, 0.58, 0.68)
	env.ambient_light_energy = 0.32
	env.tonemap_exposure = 1.15
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08


## S-K-A-T-E letters on the lines, six spray cans, the secret tape and two gap coins (C and F).
func _pickups() -> void:
	var pk: Array = [
		["S", "skate", Vector3(-20.0, FL + 1.6, -5.0)],  # over the pallet gap
		["K", "skate", Vector3(0.0, 4.4 + 1.4, -19.0)],  # on the catwalk, above the stair head
		["A", "skate", Vector3(62.0, 2.62 + 1.3, -21.0)],  # container gap
		["T", "skate", Vector3(0.0, -0.2, 29.2)],  # down in the truck well
		["E", "skate", Vector3(-76.0, 1.4, 8.4)],  # in the air off the settling pit's south rim
		["can", "cans", Vector3(-10.0, 1.3 + 1.0, -31.0)],  # on the flatcar
		["can", "cans", Vector3(31.0, FL + 1.2, -1.6)],  # at the foot of the catwalk ramp
		["can", "cans", Vector3(-58.5, 2.4, -37.0)],  # over the pipes (Pipe Hop)
		["can", "cans", Vector3(24.0, 1.45 + 1.0, 33.0)],  # on the flatbed trailer
		["can", "cans", Vector3(-18.0, 1.6, 46.0)],  # over the jersey barriers
		["can", "cans", Vector3(0.0, 1.2, -73.6)],  # on the north bank wall
		["tape", "tape", Vector3(44.5, FL + 1.0, 15.2)],  # in the secret annex
		["C", "coin", Vector3(80.0, 4.2, 39.9)],  # Container Hop
		["F", "coin", Vector3(14.0, FL + 3.1, -1.9)],  # Forklift Hop
	]
	for p: Array in pk:
		var c: Collectible = WhPickup.make(str(p[0]), str(p[1]), p[2] as Vector3)
		c.name = "%s_%s_%d" % [p[1], p[0], collectibles.size()]
		add_child(c)
		collectibles.append(c)
