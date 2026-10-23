class_name DropIn
extends Area3D
## "DROP IN" marker pad: a glowing disc at the base of a drop-in tower. When the skater has been stopped on it for
## HOLD_TIME seconds it teleports the skater to the top of the tower (the `target` transform, in park space).
## The pause menu's drop-in buttons use the same teleport, DropIn.teleport().

signal dropped(spot: String)

const SKATER_LAYER: int = 2
const HOLD_TIME: float = 1.0
const STOP_SPEED: float = 1.0
const COOLDOWN: float = 2.0
const RADIUS: float = 1.8
## A drop-in starts with a small nudge so the skater rolls off the deck edge without having to push.
const NUDGE_SPEED: float = 2.5
const LABEL_Y: float = 3.6
const HIDE_SPEED: float = 6.0  ## riding faster than this, away from the pad: the marker is hidden
const HIDE_DIST: float = 6.0
const GLOW := Color("ffb02e")

@export var spot: String = ""
var target: Transform3D = Transform3D.IDENTITY
var held: float = 0.0
var cooldown: float = 0.0

var _skater: Skater
var _label: Label3D
var _beam: MeshInstance3D
var _watch: Skater  ## any skater in the scene, found once: the label hides while it is riding the ramp
var _disc: MeshInstance3D
var _mat: StandardMaterial3D


## Respawn the skater (clears state, combo and gaps like Restart) and put it at `xform` facing along -basis.z, rolling
## gently forward. Uses only the skater's public fields, so skater.gd needs no extra method.
static func teleport(skater: Skater, xform: Transform3D, nudge: float = NUDGE_SPEED) -> void:
	skater.respawn()
	var t: Transform3D = xform
	t.origin += Vector3(0.0, 0.1, 0.0)
	skater.global_transform = t
	var dir: Vector3 = -t.basis.z
	skater.facing = dir
	skater.velocity = dir * nudge
	skater.speed = nudge


func _ready() -> void:
	collision_layer = 0
	collision_mask = SKATER_LAYER
	monitoring = true
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = RADIUS
	shape.height = 2.0
	cs.shape = shape
	cs.position.y = 1.0
	add_child(cs)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = GLOW
	_mat.emission_enabled = true
	_mat.emission = GLOW
	_mat.emission_energy_multiplier = 1.5
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cyl := CylinderMesh.new()
	cyl.top_radius = RADIUS
	cyl.bottom_radius = RADIUS
	cyl.height = 0.05
	cyl.radial_segments = 32
	_disc = MeshInstance3D.new()
	_disc.name = "Disc"
	_disc.mesh = cyl
	_disc.material_override = _mat
	_disc.position.y = 0.04
	add_child(_disc)
	var beam := CylinderMesh.new()
	beam.top_radius = RADIUS * 0.8
	beam.bottom_radius = RADIUS * 0.8
	beam.height = 5.0
	beam.radial_segments = 24
	beam.cap_top = false
	beam.cap_bottom = false
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(GLOW.r, GLOW.g, GLOW.b, 0.18)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam_mi := MeshInstance3D.new()
	beam_mi.name = "Beam"
	beam_mi.mesh = beam
	beam_mi.material_override = bm
	beam_mi.position.y = 2.5
	add_child(beam_mi)
	_label = Label3D.new()
	_label.name = "Label"
	_label.text = "DROP IN"
	_label.font_size = 110
	_label.pixel_size = 0.012
	_label.outline_size = 40
	_label.outline_modulate = Color("1b1b2f")
	_label.modulate = Color("fff3c4")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS  # solid and depth-sorted, not a see-through sprite
	_label.no_depth_test = false
	_label.position.y = LABEL_Y
	add_child(_label)
	_beam = beam_mi
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node3D) -> void:
	if body is Skater:
		_skater = body as Skater


func _on_exit(body: Node3D) -> void:
	if body == _skater:
		_skater = null
		held = 0.0


## The label and beam only show while the skater is near the pad or slow: while already riding the ramp they would
## hang in the sky and be clipped by the wall.
func _update_marker() -> void:
	if _label == null:
		return
	if (_watch == null or not is_instance_valid(_watch)) and Engine.get_physics_frames() % 30 == 0:
		var found: Array[Node] = get_tree().root.find_children("*", "Skater", true, false) if is_inside_tree() else []
		_watch = found[0] as Skater if not found.is_empty() else null
	var show: bool = true
	if _watch != null and is_instance_valid(_watch):
		var d: float = Vector2(_watch.global_position.x - global_position.x, _watch.global_position.z - global_position.z).length()
		var up: float = _watch.global_position.y - global_position.y
		if up > 1.5 or (_watch.speed > HIDE_SPEED and d > HIDE_DIST):
			show = false
	_label.visible = show
	_beam.visible = show


func _physics_process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	var stopped: bool = _skater != null and cooldown <= 0.0 and _skater.velocity.length() < STOP_SPEED
	held = held + delta if stopped else 0.0
	_update_marker()
	if _mat != null:
		_mat.emission_energy_multiplier = 1.2 + 0.8 * sin(Time.get_ticks_msec() * 0.006) + held * 2.0
	if held >= HOLD_TIME:
		held = 0.0
		cooldown = COOLDOWN
		var sk: Skater = _skater
		_skater = null
		DropIn.teleport(sk, target)
		dropped.emit(spot)
