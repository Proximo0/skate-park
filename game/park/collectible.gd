class_name Collectible
extends Area3D
## A bright pickup the skater rides through: a spinning, bobbing letter coin or pizza slice.
## Builds its own visual in _ready. On the first skater contact it emits collected once, pops and frees itself.

signal collected(item: String, group_id: String)

const SKATER_LAYER: int = 2
const PICKUP_RADIUS: float = 0.7
const SPIN_SPEED: float = 2.2
const BOB_HEIGHT: float = 0.12
const BOB_SPEED: float = 2.5
const FADE_NEAR: float = 4.0  ## m from the camera inside which the pickup shrinks and fades so it never covers the view
const FADE_FAR: float = 1.5  ## m: fully gone this close
const POP_SCALE: float = 1.35
const POP_TIME: float = 0.12
const SHRINK_TIME: float = 0.1
const COIN_COLOR: Color = Color(1.0, 0.85, 0.2)
const LETTER_COLOR: Color = Color(1.0, 0.3, 0.12)
const OUTLINE_COLOR: Color = Color(0.2, 0.06, 0.0)
const CHEESE_COLOR: Color = Color(1.0, 0.82, 0.25)
const CRUST_COLOR: Color = Color(0.85, 0.52, 0.22)

@export var item: String = "S"
@export var group_id: String = ""

var _visual: Node3D
var _label: Label3D
var _base_y: float = 0.0
var _phase: float = 0.0
var _taken: bool = false


func _ready() -> void:
	add_to_group("collectible")
	collision_layer = 0
	collision_mask = SKATER_LAYER
	monitoring = true
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = PICKUP_RADIUS
	shape.shape = sphere
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	if item == "pizza":
		_build_pizza()
	else:
		_build_letter()
	_base_y = position.y
	# Deterministic phase so a row of pickups does not bob in lockstep, and no randomness in visuals either.
	_phase = fposmod(position.x * 0.7 + position.z * 1.3, TAU)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _taken:
		return
	_phase += BOB_SPEED * delta
	_visual.rotation.y += SPIN_SPEED * delta
	_visual.position.y = sin(_phase) * BOB_HEIGHT
	if _label != null:
		_label.position.y = _visual.position.y
	_fade_near_camera()


## Fades and shrinks the pickup as the camera gets close, so it never fills the screen as it flashes past.
func _fade_near_camera() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var k: float = 1.0
	if cam != null:
		var d: float = cam.global_position.distance_to(global_position)
		k = smoothstep(FADE_FAR, FADE_NEAR, d)
	var vis: bool = k > 0.02
	_visual.visible = vis
	if _label != null:
		_label.visible = vis
		_label.scale = Vector3.ONE * lerpf(0.4, 1.0, k)
		_label.modulate = Color(LETTER_COLOR.r, LETTER_COLOR.g, LETTER_COLOR.b, k)
		_label.outline_modulate = Color(OUTLINE_COLOR.r, OUTLINE_COLOR.g, OUTLINE_COLOR.b, k)
	_visual.scale = Vector3.ONE * lerpf(0.4, 1.0, k)


func _on_body_entered(body: Node3D) -> void:
	if _taken or not (body is Skater):
		return
	_taken = true
	set_deferred("monitoring", false)
	collected.emit(item, group_id)
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE * POP_SCALE, POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_visual, "scale", Vector3.ZERO, SHRINK_TIME)
	tween.tween_callback(queue_free)


func _build_letter() -> void:
	# The coin spins; the letter is a billboard that stays readable from any angle, so it sits outside the spin.
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.27
	torus.outer_radius = 0.31
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.material_override = Toon.material(COIN_COLOR)
	_visual.add_child(ring)

	_label = Label3D.new()
	_label.text = item
	_label.font_size = 200
	_label.pixel_size = 0.003
	_label.outline_size = 24
	_label.outline_modulate = OUTLINE_COLOR
	_label.modulate = LETTER_COLOR
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.z = 0.1
	add_child(_label)


func _build_pizza() -> void:
	# Triangular prism slice, point down, crust along the top edge.
	var slice: MeshInstance3D = MeshInstance3D.new()
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.8, 0.8, 0.14)
	slice.mesh = prism
	slice.rotation_degrees.z = 180.0
	slice.material_override = Toon.material(CHEESE_COLOR)
	_visual.add_child(slice)

	var crust: MeshInstance3D = MeshInstance3D.new()
	var roll: CylinderMesh = CylinderMesh.new()
	roll.top_radius = 0.09
	roll.bottom_radius = 0.09
	roll.height = 0.82
	crust.mesh = roll
	crust.rotation_degrees.z = 90.0
	crust.position.y = 0.4
	crust.material_override = Toon.material(CRUST_COLOR)
	_visual.add_child(crust)
