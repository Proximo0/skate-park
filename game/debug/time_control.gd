class_name TimeControl
extends Node
## Always-on time controls for physics debugging. F2 cycles Engine.time_scale through 1, 0.5, 0.25, 0.1.
## F3 freezes the game (tree paused); while frozen, the period key advances exactly one physics tick.
## Godot has no single-step, so a step unpauses and re-pauses on the second physics_frame signal after it:
## the signal fires at the start of each physics iteration, before nodes process, so one full iteration runs
## in between. Esc (the pause action) while frozen unfreezes first, so the pause menu takes over cleanly.
## F3 does nothing while the pause menu (or anything else) already holds the tree paused.

signal frozen_changed(frozen: bool)

const SCALES: Array[float] = [1.0, 0.5, 0.25, 0.1]
const LAYER: int = 119

var frozen: bool = false
var scale_index: int = 0

var _stepping: bool = false
var _step_frames: int = 0
var _badge_layer: CanvasLayer
var _badge: Label
var _plate: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_badge()
	_refresh()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _build_badge() -> void:
	_badge_layer = CanvasLayer.new()
	_badge_layer.layer = LAYER
	_badge_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_badge_layer)
	_plate = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.8)
	style.set_content_margin_all(6.0)
	style.set_corner_radius_all(6)
	_plate.add_theme_stylebox_override("panel", style)
	_plate.anchor_left = 0.5
	_plate.anchor_right = 0.5
	_plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_plate.offset_top = 96.0  ## below the timer
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_layer.add_child(_plate)
	_badge = Label.new()
	_badge.add_theme_font_size_override("font_size", 22)
	_plate.add_child(_badge)


func _input(event: InputEvent) -> void:
	if frozen and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		set_frozen(false)  # not consumed: the pause menu opens next
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.echo and key.physical_keycode != KEY_PERIOD:
		return
	match key.physical_keycode:
		KEY_F2:
			cycle_scale()
		KEY_F3:
			set_frozen(not frozen)
		KEY_PERIOD:
			step()
		_:
			return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# The pause menu resumed (or anything else unpaused the tree) while we believed we were frozen.
	if frozen and not _stepping and not get_tree().paused:
		frozen = false
		_refresh()
		frozen_changed.emit(false)


## Moves to the next time scale (1, 0.5, 0.25, 0.1, back to 1) and returns it.
func cycle_scale() -> float:
	scale_index = (scale_index + 1) % SCALES.size()
	Engine.time_scale = SCALES[scale_index]
	_refresh()
	return SCALES[scale_index]


func set_scale_index(i: int) -> void:
	scale_index = clampi(i, 0, SCALES.size() - 1)
	Engine.time_scale = SCALES[scale_index]
	_refresh()


func set_frozen(on: bool) -> void:
	if on == frozen:
		return
	if on and get_tree().paused:
		return  # the pause menu has the tree
	if not on and _stepping:
		_stepping = false
		_step_frames = 0
		_disconnect_step()
	frozen = on
	get_tree().paused = on
	_refresh()
	frozen_changed.emit(on)


## Advances exactly one physics tick while frozen.
func step() -> void:
	if not frozen or _stepping:
		return
	_stepping = true
	_step_frames = 0
	get_tree().paused = false
	get_tree().physics_frame.connect(_on_step_frame)


func _on_step_frame() -> void:
	_step_frames += 1
	if _step_frames < 2:
		return  # first signal: the iteration that runs the tick starts now
	_disconnect_step()
	_stepping = false
	get_tree().paused = true


func _disconnect_step() -> void:
	if get_tree().physics_frame.is_connected(_on_step_frame):
		get_tree().physics_frame.disconnect(_on_step_frame)


func badge_text() -> String:
	if frozen:
		return "FROZEN (. = step)"
	if scale_index != 0:
		return "SLOW x%s" % String.num(SCALES[scale_index], 2)
	return ""


func _refresh() -> void:
	if _badge == null:
		return
	var txt: String = badge_text()
	_plate.visible = txt != ""
	_badge.text = txt
