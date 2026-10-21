extends Node
## Autoload "UiFx": every themed button (theme_type_variation set, e.g. CoralButton) tilts and grows a little when
## hovered or focused, and settles back when not. Works for mouse, keyboard and gamepad focus alike, and needs no
## per-screen code. Skip a button with set_meta("no_fx", true).

const GROW: float = 0.07
const TILT_DEGREES: float = 2.4
const WIDE: float = 440.0  ## buttons wider than this tilt and grow less so long rows stay tidy


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var b: BaseButton = node as BaseButton
	if b == null or b.has_meta(&"ui_fx"):
		return
	b.set_meta(&"ui_fx", true)
	var refresh: Callable = _refresh.bind(b)
	b.focus_entered.connect(refresh)
	b.focus_exited.connect(refresh)
	b.mouse_entered.connect(refresh)
	b.mouse_exited.connect(refresh)
	b.resized.connect(_centre_pivot.bind(b))
	b.visibility_changed.connect(refresh)
	_centre_pivot(b)


func _centre_pivot(b: BaseButton) -> void:
	b.pivot_offset = b.size * 0.5


## True when this button should show the hover/focus pose.
static func wants_pose(b: BaseButton) -> bool:
	if b.theme_type_variation == &"" or b.has_meta(&"no_fx") or b.disabled or not b.is_visible_in_tree():
		return false
	return b.has_focus() or b.is_hovered()


static func pose_for(b: BaseButton, on: bool) -> Array:
	if not on:
		return [Vector2.ONE, 0.0]
	var k: float = clampf(pow(WIDE / maxf(b.size.x, 1.0), 1.5), 0.3, 1.0)
	var dir: float = -1.0 if b.get_index() % 2 == 0 else 1.0
	return [Vector2.ONE * (1.0 + GROW * k), TILT_DEGREES * k * dir]


func _refresh(b: BaseButton) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	var pose: Array = pose_for(b, wants_pose(b))
	if b.has_meta(&"ui_fx_tween"):
		var old: Tween = b.get_meta(&"ui_fx_tween") as Tween
		if old != null and old.is_valid():
			old.kill()
	var t: Tween = b.create_tween().set_parallel(true)
	t.tween_property(b, "scale", pose[0], 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "rotation_degrees", pose[1], 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.set_meta(&"ui_fx_tween", t)
