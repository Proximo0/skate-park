class_name PauseMenu
extends CanvasLayer
## Pause overlay: dimmed backdrop, big buttons (Resume, Restart Run, two Drop In spots, Controls, Quit), full gamepad and keyboard use.
## The pause action opens it and pauses the tree. Resume, ui_cancel or the pause action closes it.
## Restart, Drop In and Quit close the menu first (unpausing the tree), then emit their signal.
## drop_in_requested carries the spot id: "mega" or "loop" (see DropIn).

signal restart_requested
signal drop_in_requested(spot: String)
signal quit_requested
signal resumed

const PAUSE_BACKDROP := Color(0.02, 0.03, 0.09, 0.74)
const PAUSE_BUTTON_MIN := Vector2(460, 84)
const PAUSE_DROP_IN_MIN := Vector2(460, 68)
const PAUSE_DROP_IN_FONT := 32

var _backdrop: ColorRect
var _panel: PanelContainer
var _resume_button: Button
var _controls_button: Button
var _controls_screen: ControlsScreen
var _controls_open: bool = false
var _intro: Tween


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

	var deco: SkyBackdrop = SkyBackdrop.new(true)
	root.add_child(deco)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	_panel = PanelContainer.new()
	_panel.theme_type_variation = SkateThemeBuilder.PNL_NAVY
	_panel.add_child(StickerDots.new())
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size * 0.5)
	center.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)

	var title := AnimeText.new("PAUSED", UiStyle.SIZE_TITLE, UiStyle.SUNSHINE)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(title)

	_resume_button = _pause_button("Resume", SkateThemeBuilder.BTN_MINT)
	_resume_button.pressed.connect(resume)
	col.add_child(_resume_button)

	var restart := _pause_button("Restart Run", SkateThemeBuilder.BTN_SUN)
	restart.pressed.connect(_on_restart_pressed)
	col.add_child(restart)

	var drop_mega := _pause_button("Drop In: Mega Ramp", SkateThemeBuilder.BTN_CORAL, PAUSE_DROP_IN_MIN, PAUSE_DROP_IN_FONT)
	drop_mega.pressed.connect(_on_drop_in_pressed.bind("mega"))
	col.add_child(drop_mega)

	var drop_loop := _pause_button("Drop In: Loop", SkateThemeBuilder.BTN_CORAL, PAUSE_DROP_IN_MIN, PAUSE_DROP_IN_FONT)
	drop_loop.pressed.connect(_on_drop_in_pressed.bind("loop"))
	col.add_child(drop_loop)

	var hair_btn := _pause_button("", SkateThemeBuilder.BTN_TEAL, PAUSE_DROP_IN_MIN, PAUSE_DROP_IN_FONT)
	_set_toggle_text(hair_btn, "Hair physics", GameSettings.hair_on())
	hair_btn.pressed.connect(_on_toggle.bind(hair_btn, "Hair physics", true))
	col.add_child(hair_btn)

	var body_btn := _pause_button("", SkateThemeBuilder.BTN_TEAL, PAUSE_DROP_IN_MIN, PAUSE_DROP_IN_FONT)
	_set_toggle_text(body_btn, "Body physics", GameSettings.body_on())
	body_btn.pressed.connect(_on_toggle.bind(body_btn, "Body physics", false))
	col.add_child(body_btn)

	_controls_button = _pause_button("Controls", SkateThemeBuilder.BTN_TEAL)
	_controls_button.pressed.connect(_on_controls_pressed)
	col.add_child(_controls_button)

	var quit := _pause_button("Quit to Title", SkateThemeBuilder.BTN_CREAM)
	quit.pressed.connect(_on_quit_pressed)
	col.add_child(quit)

	# Up and down wrap around the buttons.
	var buttons: Array[Button] = [_resume_button, restart, drop_mega, drop_loop, hair_btn, body_btn, _controls_button, quit]
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


func _on_drop_in_pressed(spot: String) -> void:
	_hide_menu()
	drop_in_requested.emit(spot)


func _on_quit_pressed() -> void:
	_hide_menu()
	quit_requested.emit()


func _set_toggle_text(b: Button, label: String, on: bool) -> void:
	b.text = "%s: %s" % [label, "On" if on else "Off"]


func _on_toggle(b: Button, label: String, hair: bool) -> void:
	var on: bool = not (GameSettings.hair_on() if hair else GameSettings.body_on())
	if hair:
		GameSettings.set_hair(on)
	else:
		GameSettings.set_body(on)
	_set_toggle_text(b, label, on)


func _on_controls_pressed() -> void:
	_controls_open = true
	_panel.visible = false
	_controls_screen.open_screen()


func _on_controls_closed() -> void:
	_controls_open = false
	_controls_screen.visible = false
	_panel.visible = true
	_controls_button.grab_focus()


func _pause_button(text: String, variation: StringName, min_size: Vector2 = PAUSE_BUTTON_MIN, font_size: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	if font_size > 0:
		b.add_theme_font_size_override("font_size", font_size)
	b.mouse_entered.connect(b.grab_focus)
	return b
