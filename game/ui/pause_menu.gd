class_name PauseMenu
extends CanvasLayer
## Pause overlay: dimmed backdrop, four big buttons, full gamepad and keyboard use.
## The pause action opens it and pauses the tree. Resume, ui_cancel or the pause action closes it.
## Restart and Quit close the menu first (unpausing the tree), then emit their signal.

signal restart_requested
signal quit_requested
signal resumed

const PAUSE_BACKDROP := Color(0.02, 0.03, 0.09, 0.62)
const PAUSE_PANEL := Color("#2B2F7A")
const PAUSE_BUTTON_MIN := Vector2(420, 90)
const PAUSE_FOCUS_SCALE := 1.08
const PAUSE_PANEL_RADIUS := 40
const PAUSE_PANEL_PAD := 36

var _backdrop: ColorRect
var _panel: PanelContainer
var _resume_button: Button
var _controls_button: Button
var _controls_screen: ControlsScreen
var _controls_open: bool = false
var _intro: Tween
var _pops: Dictionary = {}  ## Button -> Tween running its focus scale


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_backdrop = ColorRect.new()
	_backdrop.color = PAUSE_BACKDROP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	_panel = PanelContainer.new()
	var panel_box: StyleBoxFlat = UiStyle.panel_style(PAUSE_PANEL)
	panel_box.set_corner_radius_all(PAUSE_PANEL_RADIUS)
	panel_box.set_content_margin_all(PAUSE_PANEL_PAD)
	_panel.add_theme_stylebox_override("panel", panel_box)
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size * 0.5)
	center.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_panel.add_child(col)

	var title := UiStyle.label("Paused", UiStyle.SIZE_TITLE, UiStyle.SUNSHINE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	_resume_button = _pause_button("Resume", UiStyle.LIME)
	_resume_button.pressed.connect(resume)
	col.add_child(_resume_button)

	var restart := _pause_button("Restart Run", UiStyle.SUNSHINE)
	restart.pressed.connect(_on_restart_pressed)
	col.add_child(restart)

	_controls_button = _pause_button("Controls", UiStyle.SKY_BLUE)
	_controls_button.pressed.connect(_on_controls_pressed)
	col.add_child(_controls_button)

	var quit := _pause_button("Quit to Title", UiStyle.BUBBLEGUM)
	quit.pressed.connect(_on_quit_pressed)
	col.add_child(quit)

	# Up and down wrap around the four buttons.
	var buttons: Array[Button] = [_resume_button, restart, _controls_button, quit]
	var n: int = buttons.size()
	for i: int in n:
		var b: Button = buttons[i]
		b.focus_neighbor_top = buttons[(i - 1 + n) % n].get_path()
		b.focus_neighbor_bottom = buttons[(i + 1) % n].get_path()

	_controls_screen = ControlsScreen.new()
	_controls_screen.visible = false
	_controls_screen.closed.connect(_on_controls_closed)
	add_child(_controls_screen)


func _unhandled_input(event: InputEvent) -> void:
	if _controls_open:
		return  # the controls screen handles its own close
	if visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or _pause_is_circle(event):
			get_viewport().set_input_as_handled()
			resume()
		elif event.is_action_pressed("ollie"):
			# Godot's ui_accept has no gamepad button here, so Cross presses the focused button.
			var focus: Control = get_viewport().gui_get_focus_owner()
			if focus is Button:
				get_viewport().set_input_as_handled()
				(focus as Button).pressed.emit()
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_menu()


func _pause_is_circle(event: InputEvent) -> bool:
	var jb := event as InputEventJoypadButton
	return jb != null and jb.pressed and jb.button_index == JOY_BUTTON_B


## Shows the menu, pauses the tree and focuses Resume.
func open_menu() -> void:
	if visible:
		return
	visible = true
	_controls_open = false
	_controls_screen.visible = false
	_panel.visible = true
	get_tree().paused = true
	_backdrop.modulate.a = 0.0
	_panel.scale = Vector2(0.9, 0.9)
	_intro = create_tween().set_parallel(true)
	_intro.tween_property(_backdrop, "modulate:a", 1.0, 0.15)
	_intro.tween_property(_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_resume_button.grab_focus()


## Closes the menu and unpauses the tree.
func resume() -> void:
	if not visible:
		return
	_hide_menu()
	resumed.emit()


func _hide_menu() -> void:
	if _intro and _intro.is_valid():
		_intro.kill()
	_controls_open = false
	_controls_screen.visible = false
	visible = false
	get_tree().paused = false


func _on_restart_pressed() -> void:
	_hide_menu()
	restart_requested.emit()


func _on_quit_pressed() -> void:
	_hide_menu()
	quit_requested.emit()


func _on_controls_pressed() -> void:
	_controls_open = true
	_panel.visible = false
	_controls_screen.open_screen()


func _on_controls_closed() -> void:
	_controls_open = false
	_controls_screen.visible = false
	_panel.visible = true
	_controls_button.grab_focus()


func _pause_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = PAUSE_BUTTON_MIN
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", UiStyle.SIZE_BIG)
	for k: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, UiStyle.INK)
	b.add_theme_stylebox_override("normal", _pause_box(color, 26, UiStyle.INK, 4, 18))
	b.add_theme_stylebox_override("hover", _pause_box(color.lightened(0.15), 26, UiStyle.INK, 4, 18))
	b.add_theme_stylebox_override("pressed", _pause_box(color.darkened(0.15), 26, UiStyle.INK, 4, 18))
	b.add_theme_stylebox_override("focus", _pause_box(color, 26, UiStyle.WHITE, 8, 18))
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.focus_entered.connect(_pop.bind(b, PAUSE_FOCUS_SCALE))
	b.focus_exited.connect(_pop.bind(b, 1.0))
	b.mouse_entered.connect(b.grab_focus)
	return b


## Scales a button to target with a short tween, replacing any tween still running on it.
func _pop(b: Button, target: float) -> void:
	var old: Tween = _pops.get(b) as Tween
	if old and old.is_valid():
		old.kill()
	var t := create_tween()
	t.tween_property(b, "scale", Vector2.ONE * target, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pops[b] = t


func _pause_box(fill: Color, radius: int, border: Color, border_w: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.set_border_width_all(border_w)
		s.border_color = border
	s.set_content_margin_all(pad)
	return s
