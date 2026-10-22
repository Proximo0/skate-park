class_name DowntownLevel
extends Level
## Downtown: city blocks in bright late-morning light under a towering skyline. See DtPlan for the layout and the
## README in this folder for the areas, lines, gaps and goals. Each area is built by its own helper (dt_*.gd); this
## script holds the Level contract, the light, and the pickups.

const GAPS_JSON: String = "res://game/levels/downtown/gaps.json"
const GOALS_JSON: String = "res://game/levels/downtown/goals.json"
## Late morning: a high sun in the south-east, cool white light, a clear sky going pale at the horizon, a blue haze
## that softens the far towers. On top of the city_afternoon preset (the registry's mood for this level).
const LIGHT: Dictionary = {
	"name": "City, late morning",
	"sun_rotation": Vector3(-54.0, 38.0, 0.0),
	"sun_color": Color(1.0, 0.96, 0.9),
	"sun_energy": 1.06,
	"shadow_distance": 100.0,
	"zenith": Color(0.16, 0.42, 0.9),
	"upper": Color(0.3, 0.6, 0.98),
	"aqua": Color(0.68, 0.86, 0.98),
	"yellow": Color(0.96, 0.94, 0.86),
	"coral": Color(0.96, 0.86, 0.8),
	"below": Color(0.6, 0.66, 0.74),
	"band_scale": 0.8,
	"cloud_cover": 0.38,
	"cloud_warmth": 0.2,
	"fog_color": Color(0.74, 0.84, 0.96),
	"fog_density": 0.0021,
	"ambient_color": Color(0.9, 0.94, 1.0),
	"ambient_energy": 0.3,
}

var streets: DtStreets
var city: DtCity
var civic: DtCivic
var transit: DtTransit
var garage: DtGarage
var alley: DtAlley
var life: DtLife
var traffic: Traffic


func _init() -> void:
	spawn = Transform3D(Basis.IDENTITY, DtPlan.SPAWN)  # facing -Z: up the promenade toward City Hall
	bounds = DtPlan.BOUNDS
	kill_y = Level.DEFAULT_KILL_Y
	gaps_path = GAPS_JSON
	goals_path = GOALS_JSON
	preview_view = [Vector3(-34.0, 9.0, 34.0), Vector3(-2.0, 4.0, -18.0)]


func _ready() -> void:
	setup_environment()
	add_backdrop("concrete", Color("8d929c"), 3000.0, -0.08)
	add_boundary()
	streets = DtStreets.new(self)
	streets.build()
	traffic = streets.traffic
	city = DtCity.new(self)
	city.night = is_night()
	city.build()
	civic = DtCivic.new(self)
	civic.build()
	transit = DtTransit.new(self)
	transit.build()
	garage = DtGarage.new(self)
	garage.build()
	alley = DtAlley.new(self)
	alley.build()
	life = DtLife.new(self, streets, civic, transit, alley)
	life.build()
	_drop_ins()
	_pickups()


## Drop-in spots (pause menu): the spawn, the station platform, the garage roof, the alley.
func _drop_ins() -> void:
	add_drop_in("plaza", "City Hall Plaza", spawn)
	add_drop_in("platform", "Station Platform", transit.platform_xf)
	add_drop_in("garage_roof", "Garage Roof", garage.roof_xf)
	add_drop_in("alley", "The Alleys", Transform3D(Basis(Vector3.UP, PI), Vector3(-94.0, DtPlan.P + 0.1, 41.5)))
	var pad := DropIn.new()
	pad.name = "PlatformLift"
	pad.spot = "platform"
	pad.target = transit.platform_xf
	pad.position = transit.drop_pad
	add_child(pad)


## The pickups: S-K-A-T-E along the lines, pizza slices in the corners, a coin in the air over each signature gap,
## and the secret tape in the alley lot.
func _pickups() -> void:
	var p: float = DtPlan.P
	# S-K-A-T-E: one on each area's signature line
	add_collectible("S", "skate", Vector3(-32.0, 1.5, 13.0))  # over the fountain plaza's pair ledges
	add_collectible("K", "skate", Vector3(-8.5, 2.65, -11.5))  # down the City Hall hubba
	add_collectible("A", "skate", Vector3(19.0, 1.4, 44.5))  # along the ledge under the Line
	add_collectible("T", "skate", Vector3(-2.5, 4.75, 63.7))  # down the station rail
	add_collectible("E", "skate", Vector3(40.0, DtPlan.MONO_Y + 0.8, DtPlan.BEAM_B))  # out on the monorail beam
	# pizza in the corners
	for pos: Vector3 in [Vector3(22.5, p + 0.9, 78.4), Vector3(-90.0, p + 0.9, 85.5), Vector3(80.0, DtPlan.L1 + 0.9, 70.0),
			Vector3(-20.0, p + DtPlan.TERRACE_H + 0.9, -23.0), Vector3(-77.0, p + 0.9, 52.0), Vector3(20.0, DtPlan.MONO_Y + 0.9, 56.6)]:
		add_collectible("pizza", "pizza", pos)
	# a coin in the air over each signature gap
	add_collectible("10", "gaps", Vector3(0.0, 3.6, -10.6))  # City Hall Ten
	add_collectible("F", "gaps", Vector3(DtPlan.FOUNTAIN.x, 3.1, DtPlan.FOUNTAIN.z + 4.2))  # Fountain Clip
	add_collectible("24", "gaps", Vector3(0.0, 7.2, 63.0))  # Station 24
	# the secret tape, in the air off the DIY quarter pipe behind the fence
	var tape := DtTape.new()
	tape.item = "tape"
	tape.group_id = "secret"
	tape.position = alley.tape_pos
	tape.name = "secret_tape"
	add_child(tape)
	collectibles.append(tape)


## The registry's mood (city_afternoon) re-lit as late morning (LIGHT). Same contract as Level.setup_environment().
func setup_environment(preset_id: String = "") -> void:
	if preset_id != "":
		mood_id = preset_id
	var p: Dictionary = Mood.preset(mood_id if mood_id != "" else "city_afternoon")
	if not bool(p.get("night", false)):
		for k: String in LIGHT:
			p[k] = LIGHT[k]
	mood = p
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = Mood.environment(p)
	var key := DirectionalLight3D.new()
	key.name = "Sun"
	key.rotation_degrees = p["sun_rotation"] as Vector3
	key.light_color = p["sun_color"] as Color
	key.light_energy = float(p["sun_energy"])
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.directional_shadow_max_distance = float(p["shadow_distance"])
	world_environment = we
	sun = key
	add_child(we)
	add_child(key)
