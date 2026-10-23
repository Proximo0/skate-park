class_name SchoolBlinker
extends Node3D
## An aircraft-warning light for the School level's backdrop (the radio mast on the hills): an unshaded glow ball that
## blinks on and off about once a second.

const PERIOD := 1.4
const ON_FRACTION := 0.45

var _ball: MeshInstance3D
var _t := 0.0


static func create(colour: Color, radius: float = 1.4) -> SchoolBlinker:
	var b := SchoolBlinker.new()
	b.name = "Blinker"
	b._ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	b._ball.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	b._ball.material_override = m
	b._ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(b._ball)
	return b


func _process(delta: float) -> void:
	_t = fmod(_t + delta, PERIOD)
	_ball.visible = _t < PERIOD * ON_FRACTION
