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
const GLOW := Color("ffb02e")

@export var spot: String = ""
var target: Transform3D = Transform3D.IDENTITY
var held: float = 0.0
var cooldown: float = 0.0

var _skater: Skater
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
	var lbl := Label3D.new()
	lbl.name = "Label"
	lbl.text = "DROP IN"
	lbl.font_size = 96
	lbl.pixel_size = 0.012
	lbl.outline_size = 14
	lbl.modulate = Color.WHITE
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = false
	lbl.position.y = 2.6
	add_child(lbl)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node3D) -> void:
	if body is Skater:
		_skater = body as Skater


func _on_exit(body: Node3D) -> void:
	if body == _skater:
		_skater = null
		held = 0.0


func _physics_process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	var stopped: bool = _skater != null and cooldown <= 0.0 and _skater.velocity.length() < STOP_SPEED
	held = held + delta if stopped else 0.0
	if _mat != null:
		_mat.emission_energy_multiplier = 1.2 + 0.8 * sin(Time.get_ticks_msec() * 0.006) + held * 2.0
	if held >= HOLD_TIME:
		held = 0.0
		cooldown = COOLDOWN
		var sk: Skater = _skater
		_skater = null
		DropIn.teleport(sk, target)
		dropped.emit(spot)
