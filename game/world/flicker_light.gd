class_name FlickerLight
extends Node3D
## A lamp that hums: a light (SpotLight3D or OmniLight3D) plus a glowing bulb mesh, steady with a faint flutter, or
## `failing`: dropping out in seeded bursts like a dying tube. The pattern is deterministic per seed (no global random).
## sodium_lamp() builds a whole street/warehouse lamp: pole, arm, head, downward spot, an additive light pool on the
## floor and a faint beam cone that shows in fog. Lights cost per lit object in the Compatibility renderer, so keep a
## level to about a dozen real lights in view and fake the rest with pools (see docs/levels.md).

@export var failing: bool = false
@export var seed_value: int = 3
@export var energy: float = 2.0

var light: Light3D = null
var glow_materials: Array[StandardMaterial3D] = []  ## materials whose brightness follows the light (bulb, pool, beam)
var _base_colors: Array[Color] = []
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _until: float = 0.0
var _off: bool = false


func _ready() -> void:
	_rng.seed = seed_value
	for m: StandardMaterial3D in glow_materials:
		_base_colors.append(m.albedo_color)


## Registers a material to dim with the light (its albedo is scaled).
func add_glow(m: StandardMaterial3D) -> void:
	glow_materials.append(m)


func _process(delta: float) -> void:
	_t += delta
	var k: float = 1.0 + 0.03 * sin(_t * 31.0) + 0.02 * sin(_t * 7.3)
	if failing:
		if _t >= _until:
			# alternate on stretches and off bursts; off bursts are short and come in clusters
			_off = not _off if _rng.randf() < 0.75 else _off
			_until = _t + (_rng.randf_range(0.03, 0.25) if _off else _rng.randf_range(0.2, 2.8))
		if _off:
			k = 0.05 + 0.1 * _rng.randf()
	if light != null:
		light.light_energy = energy * k
	for i: int in glow_materials.size():
		var c: Color = _base_colors[i]
		glow_materials[i].albedo_color = Color(c.r * k, c.g * k, c.b * k, c.a)


## A sodium lamp on a pole `height` tall: orange spot pointing down, bulb, floor pool and a faint fog beam.
static func sodium_lamp(height: float = 6.0, is_failing: bool = false, colour: Color = Color("ffb347"), seed_v: int = 3) -> FlickerLight:
	var f := FlickerLight.new()
	f.name = "SodiumLamp"
	f.failing = is_failing
	f.seed_value = seed_v
	var pole_mat: ShaderMaterial = Toon.material(Color("3a3e4a"), false)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.07
	pm.bottom_radius = 0.1
	pm.height = height
	pm.radial_segments = 8
	pole.mesh = pm
	pole.position = Vector3(0, height * 0.5, 0)
	pole.material_override = pole_mat
	f.add_child(pole)
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.08, 0.08, 1.2)
	arm.mesh = am
	arm.position = Vector3(0, height - 0.05, -0.55)
	arm.material_override = pole_mat
	f.add_child(arm)
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.36, 0.14, 0.62)
	head.mesh = hm
	head.position = Vector3(0, height - 0.08, -1.1)
	head.material_override = pole_mat
	f.add_child(head)
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_mat.albedo_color = Color(colour.r * 2.2, colour.g * 2.0, colour.b * 1.6)
	var bulb := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.28, 0.03, 0.5)
	bulb.mesh = bm
	bulb.position = Vector3(0, height - 0.16, -1.1)
	bulb.material_override = bulb_mat
	f.add_child(bulb)
	f.add_glow(bulb_mat)
	var spot := SpotLight3D.new()
	spot.light_color = colour
	spot.light_energy = 2.0
	spot.spot_range = height * 2.4
	spot.spot_angle = 58.0
	spot.spot_attenuation = 0.8
	spot.shadow_enabled = false
	spot.position = Vector3(0, height - 0.2, -1.1)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	f.add_child(spot)
	f.light = spot
	f.energy = 2.0
	var pool := FlickerLight.light_pool(height * 0.9, colour, 0.5)
	pool.position = Vector3(0, 0.03, -1.1)
	f.add_child(pool)
	f.add_glow(pool.material_override as StandardMaterial3D)
	var beam := FlickerLight.beam_cone(height - 0.2, height * 0.42, colour, 0.06)
	beam.position = Vector3(0, (height - 0.2) * 0.5, -1.1)
	f.add_child(beam)
	f.add_glow(beam.material_override as StandardMaterial3D)
	return f


## An additive pool of light on the floor: a disc `radius` wide, fading out (no real light needed).
static func light_pool(radius: float, colour: Color, strength: float = 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "LightPool"
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(colour.r * strength, colour.g * strength, colour.b * strength, 1.0)
	m.albedo_texture = FlickerLight.radial_texture()
	m.disable_receive_shadows = true
	m.no_depth_test = false
	m.disable_fog = true  # fog would add its colour to the additive quad and show its square edges
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A faint additive cone hanging down `length` metres from its origin, `radius` wide at the bottom (shows the light in
## fog and dark air).
static func beam_cone(length: float, radius: float, colour: Color, strength: float = 0.06) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Beam"
	var c := CylinderMesh.new()
	c.top_radius = 0.18
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 16
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	mi.mesh = c
	mi.position = Vector3(0, -length * 0.5, 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	m.albedo_color = Color(colour.r * strength, colour.g * strength, colour.b * strength, 1.0)
	m.albedo_texture = FlickerLight.fade_texture()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static var _radial: GradientTexture2D = null
static var _fade: GradientTexture2D = null


## White in the middle fading to black at the rim (for additive pools).
static func radial_texture() -> GradientTexture2D:
	if _radial == null:
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color.BLACK)
		g.add_point(0.45, Color(0.55, 0.55, 0.55))
		_radial = GradientTexture2D.new()
		_radial.gradient = g
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		_radial.width = 128
		_radial.height = 128
	return _radial


## Bright at the top (v = 0) fading to black at the bottom (for beams).
static func fade_texture() -> GradientTexture2D:
	if _fade == null:
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color.BLACK)
		_fade = GradientTexture2D.new()
		_fade.gradient = g
		_fade.fill_from = Vector2(0.5, 0.0)
		_fade.fill_to = Vector2(0.5, 1.0)
		_fade.width = 8
		_fade.height = 64
	return _fade
