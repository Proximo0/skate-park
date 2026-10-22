class_name Mood
extends RefCounted
## Time-of-day / mood presets for the levels: sky, sun, fog, ambient light and tonemap in one id. Built on
## Toon.park_sky_environment (the park's environment contract: colour ambient, linear-ish tonemap, peach haze) with the
## sky swapped for game/world/mood_sky.gdshader, a superset of game/art/sky.gdshader (moon, stars, city glow,
## per-mood cloud colours). Everything works in the Compatibility renderer.
##
## Use: Level.setup_environment("beach_sunny"), or Mood.build(id) -> {preset, environment: WorldEnvironment,
## sun: DirectionalLight3D} and add both nodes yourself. Mood.preset(id) is the plain Dictionary (unit tested).
## A preset's "night" flag tells the world nodes to light up (car headlights, lamp glow, lit windows).

const DEFAULT_ID: String = "day"
const SKY_SHADER: Shader = preload("res://game/world/mood_sky.gdshader")

## Every key a preset may set, with the default (the practice park's sunny afternoon).
const BASE: Dictionary = {
	"name": "Sunny afternoon",
	"night": false,
	"sun_rotation": Vector3(-58.0, 35.0, 0.0),  ## the key light's rotation_degrees; the sky's sun sits along its +Z
	"sun_color": Color(1.0, 0.95, 0.86),
	"sun_energy": 1.0,
	"shadow_distance": 150.0,
	"zenith": Color(0.2, 0.5, 0.96),
	"upper": Color(0.3, 0.66, 1.0),
	"aqua": Color(0.58, 0.88, 0.95),
	"yellow": Color(1.0, 0.86, 0.42),
	"coral": Color(1.0, 0.5, 0.4),
	"below": Color(0.8, 0.4, 0.32),
	"band_scale": 1.0,
	"cloud_cover": 0.45,
	"cloud_lit": Color(1.0, 0.985, 0.95),
	"cloud_shaded": Color(0.74, 0.8, 0.94),
	"cloud_low": Color(0.62, 0.68, 0.88),
	"cloud_warm": Color(1.0, 0.82, 0.66),
	"cloud_warmth": 0.5,
	"disc_color": Color(1.0, 0.97, 0.78),
	"ring_color": Color(1.0, 0.86, 0.45),
	"sun_size": 1.0,
	"sun_rings": 1.0,
	"moon": 0.0,
	"stars": 0.0,
	"glow_color": Color(1.0, 0.6, 0.3),
	"glow_strength": 0.0,
	"fog_color": Color(1.0, 0.84, 0.68),
	"fog_density": 0.0007,
	"fog_sky_affect": 0.0,
	"ambient_color": Color(1.0, 0.93, 0.9),
	"ambient_energy": 0.22,
	"tonemap": "linear",  ## "linear", "reinhard", "filmic" or "aces"
	"exposure": 1.0,
	"white": 1.0,
	"glow": false,
	"water_deep": Color("1f6f9a"),  ## Ocean colours under this sky (game/world/ocean.gd)
	"water_shallow": Color("37c8c0"),
	"lamp_color": Color("ffd08a"),  ## street lamps, windows and headlights at night
}

## The presets. Only the keys that differ from BASE.
const PRESETS: Dictionary = {
	"day": {},
	"beach_sunny": {
		"name": "Beach, high sun",
		"sun_rotation": Vector3(-52.0, 150.0, 0.0),
		"sun_color": Color(1.0, 0.96, 0.88),
		"sun_energy": 1.05,
		"zenith": Color(0.1, 0.42, 0.92),
		"upper": Color(0.22, 0.6, 1.0),
		"aqua": Color(0.55, 0.86, 0.98),
		"yellow": Color(0.92, 0.95, 0.9),
		"coral": Color(1.0, 0.86, 0.74),
		"below": Color(0.16, 0.5, 0.72),
		"band_scale": 0.55,
		"cloud_cover": 0.3,
		"cloud_warmth": 0.15,
		"fog_color": Color(0.78, 0.9, 1.0),
		"fog_density": 0.0009,
		"ambient_color": Color(0.94, 0.97, 1.0),
		"ambient_energy": 0.26,
		"water_deep": Color("0b5d8f"),
		"water_shallow": Color("2fd0c4"),
	},
	"warehouse_night": {
		"name": "Industrial night",
		"night": true,
		"sun_rotation": Vector3(-38.0, -140.0, 0.0),
		"sun_color": Color(0.55, 0.66, 1.0),
		"sun_energy": 0.32,
		"shadow_distance": 60.0,
		"zenith": Color(0.012, 0.02, 0.06),
		"upper": Color(0.025, 0.04, 0.1),
		"aqua": Color(0.05, 0.07, 0.15),
		"yellow": Color(0.16, 0.11, 0.12),
		"coral": Color(0.36, 0.2, 0.12),
		"below": Color(0.05, 0.05, 0.07),
		"cloud_cover": 0.35,
		"cloud_lit": Color(0.2, 0.22, 0.3),
		"cloud_shaded": Color(0.08, 0.09, 0.14),
		"cloud_low": Color(0.06, 0.06, 0.1),
		"cloud_warm": Color(0.4, 0.24, 0.14),
		"cloud_warmth": 0.4,
		"disc_color": Color(0.92, 0.94, 1.0),
		"ring_color": Color(0.5, 0.6, 0.9),
		"sun_size": 1.6,
		"sun_rings": 0.0,
		"moon": 1.0,
		"stars": 0.9,
		"glow_color": Color(1.0, 0.55, 0.2),
		"glow_strength": 0.35,
		"fog_color": Color(0.16, 0.14, 0.16),
		"fog_density": 0.018,
		"fog_sky_affect": 0.0,
		"ambient_color": Color(0.45, 0.52, 0.78),
		"ambient_energy": 0.3,
		"tonemap": "filmic",
		"exposure": 1.15,
		"glow": true,
		"lamp_color": Color("ffb347"),  ## sodium orange
	},
	"school_dusk": {
		"name": "After school, golden hour",
		"sun_rotation": Vector3(-14.0, -115.0, 0.0),
		"sun_color": Color(1.0, 0.74, 0.5),
		"sun_energy": 1.0,
		"zenith": Color(0.2, 0.28, 0.62),
		"upper": Color(0.42, 0.42, 0.78),
		"aqua": Color(0.86, 0.6, 0.72),
		"yellow": Color(1.0, 0.72, 0.4),
		"coral": Color(1.0, 0.44, 0.32),
		"below": Color(0.5, 0.3, 0.32),
		"band_scale": 1.3,
		"cloud_cover": 0.4,
		"cloud_lit": Color(1.0, 0.86, 0.74),
		"cloud_shaded": Color(0.62, 0.5, 0.72),
		"cloud_low": Color(0.48, 0.4, 0.62),
		"cloud_warm": Color(1.0, 0.62, 0.42),
		"cloud_warmth": 0.8,
		"disc_color": Color(1.0, 0.92, 0.7),
		"ring_color": Color(1.0, 0.66, 0.36),
		"sun_size": 1.4,
		"fog_color": Color(1.0, 0.7, 0.56),
		"fog_density": 0.0022,
		"ambient_color": Color(0.82, 0.72, 0.9),
		"ambient_energy": 0.3,
		"lamp_color": Color("ffd08a"),
	},
	"city_afternoon": {
		"name": "City, late afternoon",
		"sun_rotation": Vector3(-34.0, 60.0, 0.0),
		"sun_color": Color(1.0, 0.88, 0.72),
		"sun_energy": 1.0,
		"zenith": Color(0.2, 0.44, 0.86),
		"upper": Color(0.36, 0.6, 0.92),
		"aqua": Color(0.66, 0.82, 0.92),
		"yellow": Color(1.0, 0.86, 0.62),
		"coral": Color(1.0, 0.66, 0.5),
		"below": Color(0.5, 0.5, 0.56),
		"cloud_cover": 0.5,
		"cloud_warmth": 0.45,
		"fog_color": Color(0.9, 0.84, 0.8),
		"fog_density": 0.0016,
		"ambient_color": Color(0.92, 0.92, 0.98),
		"ambient_energy": 0.26,
	},
	"city_night": {
		"name": "City at night",
		"night": true,
		"sun_rotation": Vector3(-45.0, 30.0, 0.0),
		"sun_color": Color(0.6, 0.7, 1.0),
		"sun_energy": 0.3,
		"shadow_distance": 60.0,
		"zenith": Color(0.02, 0.03, 0.09),
		"upper": Color(0.05, 0.06, 0.16),
		"aqua": Color(0.12, 0.1, 0.24),
		"yellow": Color(0.36, 0.2, 0.3),
		"coral": Color(0.6, 0.3, 0.3),
		"below": Color(0.06, 0.06, 0.1),
		"cloud_cover": 0.25,
		"cloud_lit": Color(0.3, 0.26, 0.38),
		"cloud_shaded": Color(0.12, 0.12, 0.2),
		"cloud_low": Color(0.1, 0.1, 0.16),
		"cloud_warm": Color(0.6, 0.36, 0.3),
		"disc_color": Color(0.94, 0.95, 1.0),
		"ring_color": Color(0.5, 0.6, 0.9),
		"sun_size": 1.5,
		"sun_rings": 0.0,
		"moon": 1.0,
		"stars": 0.35,
		"glow_color": Color(1.0, 0.5, 0.45),
		"glow_strength": 0.5,
		"fog_color": Color(0.2, 0.16, 0.24),
		"fog_density": 0.006,
		"ambient_color": Color(0.5, 0.52, 0.8),
		"ambient_energy": 0.34,
		"tonemap": "filmic",
		"exposure": 1.15,
		"glow": true,
	},
	"hills_golden": {
		"name": "Hills, late golden light",
		"sun_rotation": Vector3(-22.0, 120.0, 0.0),
		"sun_color": Color(1.0, 0.82, 0.6),
		"sun_energy": 1.05,
		"zenith": Color(0.16, 0.42, 0.86),
		"upper": Color(0.32, 0.6, 0.96),
		"aqua": Color(0.7, 0.84, 0.9),
		"yellow": Color(1.0, 0.82, 0.52),
		"coral": Color(1.0, 0.58, 0.42),
		"below": Color(0.56, 0.5, 0.42),
		"band_scale": 1.1,
		"cloud_cover": 0.35,
		"cloud_warmth": 0.7,
		"sun_size": 1.2,
		"fog_color": Color(0.98, 0.82, 0.66),
		"fog_density": 0.0012,
		"ambient_color": Color(0.96, 0.9, 0.9),
		"ambient_energy": 0.26,
	},
}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in PRESETS:
		out.append(k)
	return out


static func has(id: String) -> bool:
	return PRESETS.has(id)


## The full preset (BASE merged with the preset's own keys). An unknown id gives the default.
static func preset(id: String) -> Dictionary:
	var out: Dictionary = BASE.duplicate()
	var own: Dictionary = PRESETS.get(id, PRESETS[DEFAULT_ID])
	for k: String in own:
		out[k] = own[k]
	out["id"] = id if PRESETS.has(id) else DEFAULT_ID
	return out


## Direction TO the sun for a preset (the key light's +Z axis).
static func sun_direction(p: Dictionary) -> Vector3:
	return Basis.from_euler((p["sun_rotation"] as Vector3) * (PI / 180.0)) * Vector3(0.0, 0.0, 1.0)


## {preset, environment (WorldEnvironment "Environment"), sun (DirectionalLight3D "Sun")} for preset `id`. Not added to
## any tree.
static func build(id: String) -> Dictionary:
	var p: Dictionary = preset(id)
	var env: Environment = environment(p)
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = p["sun_rotation"] as Vector3
	sun.light_color = p["sun_color"] as Color
	sun.light_energy = float(p["sun_energy"])
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = float(p["shadow_distance"])
	return {"preset": p, "environment": we, "sun": sun}


## The Environment for a resolved preset.
static func environment(p: Dictionary) -> Environment:
	var env: Environment = Toon.park_sky_environment(sun_direction(p))
	var mat := ShaderMaterial.new()
	mat.shader = SKY_SHADER
	mat.set_shader_parameter("sun_dir", sun_direction(p))
	for pair: Array in [["zenith", "zenith_color"], ["upper", "upper_color"], ["aqua", "aqua_color"], ["yellow", "yellow_color"],
			["coral", "coral_color"], ["below", "below_color"], ["cloud_lit", "cloud_lit"], ["cloud_shaded", "cloud_shaded"],
			["cloud_low", "cloud_low"], ["cloud_warm", "cloud_warm"], ["disc_color", "disc_color"], ["ring_color", "ring_color"],
			["glow_color", "glow_color"]]:
		var c: Color = p[pair[0]] as Color
		mat.set_shader_parameter(str(pair[1]), Vector3(c.r, c.g, c.b))
	for key: String in ["cloud_cover", "cloud_warmth", "sun_size", "sun_rings", "moon", "stars", "glow_strength", "band_scale"]:
		mat.set_shader_parameter(key, float(p[key]))
	env.sky.sky_material = mat
	env.fog_light_color = p["fog_color"] as Color
	env.fog_density = float(p["fog_density"])
	env.fog_sky_affect = float(p["fog_sky_affect"])
	env.ambient_light_color = p["ambient_color"] as Color
	env.ambient_light_energy = float(p["ambient_energy"])
	match str(p["tonemap"]):
		"filmic":
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		"aces":
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
		"reinhard":
			env.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
		_:
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = float(p["exposure"])
	env.tonemap_white = float(p["white"])
	if bool(p["glow"]):
		env.glow_enabled = true
		env.glow_intensity = 0.6
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 0.9
	return env
