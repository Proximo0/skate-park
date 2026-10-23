class_name SchoolSprinkler
extends Node3D
## A field sprinkler: a little head on the grass whose jet sweeps back and forth over half a circle, spraying droplets
## (CPU particles, one draw call) that arc and fall. Deterministic sweep (no randomness in the motion).

@export var seed_value: int = 0
@export var sweep_deg: float = 150.0
@export var period: float = 7.0

var _jet: CPUParticles3D
var _t: float = 0.0


func _ready() -> void:
	_t = float(posmod(seed_value, 97)) * 0.37
	var head := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.08
	cm.height = 0.18
	cm.radial_segments = 6
	head.mesh = cm
	head.position.y = 0.09
	head.material_override = Toon.material(Color("3b3f4c"), false)
	add_child(head)
	_jet = CPUParticles3D.new()
	_jet.name = "Jet"
	_jet.amount = 70
	_jet.lifetime = 1.3
	_jet.preprocess = 1.3
	_jet.position.y = 0.18
	_jet.direction = Vector3(0.0, 0.55, -1.0)
	_jet.spread = 4.0
	_jet.initial_velocity_min = 7.5
	_jet.initial_velocity_max = 9.0
	_jet.gravity = Vector3(0.0, -9.8, 0.0)
	_jet.scale_amount_min = 0.6
	_jet.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.93, 1.0, 0.75))
	ramp.set_color(1, Color(0.85, 0.93, 1.0, 0.0))
	_jet.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = SteamVent.puff_texture()
	q.material = m
	_jet.mesh = q
	_jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_jet)


func _process(delta: float) -> void:
	_t += delta
	var k: float = sin(_t * TAU / period)
	_jet.rotation.y = deg_to_rad(sweep_deg * 0.5) * k
