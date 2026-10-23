class_name SettingsScreen
extends Control
## Full-screen settings (opened from the pause menu): sound and feel on the left (SFX volume, camera speed, invert Y,
## balance assist), the control remap table on the right (keyboard and gamepad, one row per action, click or press Cross
## on a cell and then press the new key or button; Esc cancels), Reset controls and Back. Values live in GameSettings and
## ControlRemap, which save them. Back, ui_cancel or pause emit closed (not while a cell is waiting for its key).

signal closed

const ST_ROW_FONT: int = 26
const ST_HEAD_FONT: int = 30
const ST_SLIDER_MIN := Vector2(300, 36)
const ST_CELL_MIN := Vector2(210, 44)

var _back: Button
var _reset: Button
var _sfx_slider: HSlider
var _sfx_value: Label
var _sens_slider: HSlider
var _sens_value: Label
var _invert_btn: Button
var _assist_btn: Button
var _cells: Dictionary = {}  ## "action:key" / "action:pad" -> Button
var _listen_action: String = ""
var _listen_kind: String = ""  ## "key" or "pad" while a cell waits for its input
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## Shows the screen and focuses Back.
func open_screen() -> void:
	visible = true
	_cancel_listen()
	_refresh()
	if _back != null:
		_back.grab_focus()


func is_listening() -> bool:
	return _listen_action != ""


func _build() -> void:
	var sky: SkyBackdrop = SkyBackdrop.new()
	sky.sparkles = false
	add_child(sky)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	margin.add_child(main)
	var title := AnimeText.new("SETTINGS", 56, UiStyle.SUNSHINE)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main.add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(columns)

	var left: PanelContainer = MenuKit.panel()
	left.custom_minimum_size = Vector2(640, 0)
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	columns.add_child(left)
	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 14)
	left.add_child(lcol)
	lcol.add_child(MenuKit.text("SOUND AND FEEL", ST_HEAD_FONT, SkateThemeBuilder.CORAL))
	_sfx_slider = _slider(lcol, "SFX volume", 0, 100, 5, GameSettings.sfx_volume)
	_sfx_value = _sfx_slider.get_meta("value_label") as Label
	_sfx_slider.value_changed.connect(_on_sfx)
	_sens_slider = _slider(lcol, "Camera speed", 25, 200, 5, GameSettings.cam_sensitivity)
	_sens_value = _sens_slider.get_meta("value_label") as Label
	_sens_slider.value_changed.connect(_on_sens)
	_invert_btn = _setting_button(lcol, "InvertY", "Invert camera Y")
	_invert_btn.pressed.connect(_on_invert)
	_assist_btn = _setting_button(lcol, "BalanceAssist", "Balance assist")
	_assist_btn.pressed.connect(_on_assist)
	_hint = MenuKit.text("", 22, SkateThemeBuilder.MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(580, 0)
	lcol.add_child(_hint)

	var right: PanelContainer = MenuKit.panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var rcol := VBoxContainer.new()
	rcol.add_theme_constant_override("separation", 6)
	right.add_child(rcol)
	var head := HBoxContainer.new()
	rcol.add_child(head)
	var h1 := MenuKit.text("CONTROLS", ST_HEAD_FONT, SkateThemeBuilder.CORAL)
	h1.custom_minimum_size.x = 230
	head.add_child(h1)
	for t: String in ["Keyboard", "Gamepad"]:
		var h := MenuKit.text(t, ST_ROW_FONT - 4, SkateThemeBuilder.MUTED)
		h.custom_minimum_size.x = ST_CELL_MIN.x + 8
		head.add_child(h)
	var scroll := ScrollContainer.new()
	scroll.name = "RemapScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rcol.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)
	var all_buttons: Array[Button] = []
	for r: Array in ControlRemap.ROWS:
		var action: String = r[1]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var nm := MenuKit.text(str(r[0]), ST_ROW_FONT)
		nm.custom_minimum_size = Vector2(220, ST_CELL_MIN.y)
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(nm)
		for kind: String in ["key", "pad"]:
			if kind == "pad" and not ControlRemap.has_pad(action):
				var none := MenuKit.text("stick / d-pad", ST_ROW_FONT - 6, SkateThemeBuilder.MUTED)
				none.custom_minimum_size = ST_CELL_MIN
				none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				h.add_child(none)
				continue
			var b := Button.new()
			b.name = "%s_%s" % [action, kind]
			b.theme_type_variation = SkateThemeBuilder.BTN_CREAM
			b.custom_minimum_size = ST_CELL_MIN
			b.add_theme_font_size_override("font_size", ST_ROW_FONT - 4)
			b.focus_mode = Control.FOCUS_ALL
			b.pressed.connect(_begin_listen.bind(action, kind))
			b.mouse_entered.connect(b.grab_focus)
			h.add_child(b)
			_cells[b.name] = b
			all_buttons.append(b)
		rows.add_child(h)
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.add_theme_constant_override("separation", 32)
	main.add_child(back_row)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size = Vector2(300, 60)
	_back.theme_type_variation = SkateThemeBuilder.BTN_SUN
	_back.pressed.connect(func() -> void: closed.emit())
	_back.mouse_entered.connect(_back.grab_focus)
	back_row.add_child(_back)
	_reset = Button.new()
	_reset.name = "ResetControls"
	_reset.text = "Reset controls"
	_reset.custom_minimum_size = Vector2(300, 60)
	_reset.theme_type_variation = SkateThemeBuilder.BTN_CORAL
	_reset.pressed.connect(_on_reset)
	_reset.mouse_entered.connect(_reset.grab_focus)
	back_row.add_child(_reset)
	# focus: sliders and toggles, then the remap cells top to bottom, then Back and Reset
	var order: Array[Control] = [_sfx_slider, _sens_slider, _invert_btn, _assist_btn]
	order.append_array(all_buttons)
	order.append_array([_back, _reset])
	for i: int in order.size():
		order[i].focus_neighbor_top = order[(i - 1 + order.size()) % order.size()].get_path()
		order[i].focus_neighbor_bottom = order[(i + 1) % order.size()].get_path()
	_refresh()


func _slider(parent: Control, label: String, lo: int, hi: int, step: int, value: int) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var nm := MenuKit.text(label, ST_ROW_FONT)
	nm.custom_minimum_size.x = 190
	row.add_child(nm)
	var s := HSlider.new()
	s.name = label.replace(" ", "")
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = ST_SLIDER_MIN
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	row.add_child(s)
	var v := MenuKit.text("%d%%" % value, ST_ROW_FONT, SkateThemeBuilder.CORAL)
	v.custom_minimum_size.x = 80
	row.add_child(v)
	s.set_meta("value_label", v)
	return s


func _setting_button(parent: Control, nm: String, text: String) -> Button:
	var b := Button.new()
	b.name = nm
	b.text = text
	b.theme_type_variation = SkateThemeBuilder.BTN_TEAL
	b.custom_minimum_size = Vector2(580, 56)
	b.add_theme_font_size_override("font_size", 28)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(b.grab_focus)
	parent.add_child(b)
	return b


func _refresh() -> void:
	if _invert_btn == null:
		return
	_invert_btn.text = "Invert camera Y: %s" % ("On" if GameSettings.cam_invert_y() else "Off")
	_assist_btn.text = "Balance assist: %s" % GameSettings.ASSIST_NAMES[GameSettings.assist_level()]
	_hint.text = [
		"Easy: grinds and manuals stay steady longer.", "Normal: the standard balance.",
		"Hard: the wobble grows fast, hold your line.",
	][GameSettings.assist_level()]
	for r: Array in ControlRemap.ROWS:
		var action: String = r[1]
		var kb: Button = _cells.get(action + "_key") as Button
		if kb != null:
			kb.text = "Press a key..." if (_listen_action == action and _listen_kind == "key") else ControlRemap.key_name(ControlRemap.key_of(action))
		var pb: Button = _cells.get(action + "_pad") as Button
		if pb != null:
			pb.text = "Press a button..." if (_listen_action == action and _listen_kind == "pad") else ControlRemap.pad_name(action)


func _on_sfx(v: float) -> void:
	GameSettings.set_sfx_volume(int(v))
	_sfx_value.text = "%d%%" % int(v)


func _on_sens(v: float) -> void:
	GameSettings.set_cam_sensitivity(int(v))
	_sens_value.text = "%d%%" % int(v)


func _on_invert() -> void:
	GameSettings.set_invert_y(not GameSettings.cam_invert_y())
	_refresh()


func _on_assist() -> void:
	GameSettings.set_balance_assist(GameSettings.assist_level() + 1)
	_refresh()


func _on_reset() -> void:
	_cancel_listen()
	ControlRemap.reset()
	_refresh()


func _begin_listen(action: String, kind: String) -> void:
	_listen_action = action
	_listen_kind = kind
	_refresh()


func _cancel_listen() -> void:
	_listen_action = ""
	_listen_kind = ""
	_refresh()


## While a cell waits, the next key (or pad button) is its new binding and nothing else sees the event.
func _input(event: InputEvent) -> void:
	if not visible or _listen_action == "":
		return
	if _listen_kind == "key" and event is InputEventKey:
		var ek := event as InputEventKey
		if not ek.pressed or ek.echo:
			return
		get_viewport().set_input_as_handled()
		if ek.physical_keycode == KEY_ESCAPE:
			_cancel_listen()
			return
		ControlRemap.set_key(_listen_action, ek.physical_keycode)
		_cancel_listen()
	elif _listen_kind == "pad" and event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if not jb.pressed:
			return
		get_viewport().set_input_as_handled()
		ControlRemap.set_pad(_listen_action, jb.button_index)
		_cancel_listen()
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_cancel_listen()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _listen_action != "":
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or _is_circle(event):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.is_action_pressed("ollie"):
		# Godot's ui_accept has no gamepad button here, so Cross presses the focused button.
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus is Button:
			get_viewport().set_input_as_handled()
			(focus as Button).pressed.emit()


func _is_circle(event: InputEvent) -> bool:
	var jb := event as InputEventJoypadButton
	return jb != null and jb.pressed and jb.button_index == JOY_BUTTON_B
