class_name ControlsScreen
extends Control
## Full-screen controls help. Lists each player action with its PlayStation button and keyboard key,
## read from the InputMap that game/autoload/controls.gd fills, then six short tips for kids.
## Back, ui_cancel or pause emit closed. Showing and hiding the screen is up to the owner (see open_screen).

signal closed

const CTRL_BG := Color("#1B2360")
const CTRL_CARD := Color("#2F3B8C")
const CTRL_BACK_MIN := Vector2(320, 72)
const CTRL_COLUMN_GAP := 48
const CTRL_NAME_MIN := 200
const CTRL_BUTTON_MIN := 300
const CTRL_TIP_WIDTH := 580  ## three equal tip cards across the screen

## [heading, [[label, action], ...]]. "move" stands for the four move_* actions. Balance rides the move stick.
## Pick shows the ollie binding (Cross, Space): the menus accept it as well.
const CTRL_SECTIONS := [
	["Riding", [["Move", "move"], ["Ollie", "ollie"]]],
	["Tricks", [["Flip", "flip"], ["Grab", "grab"], ["Spin left", "spin_left"], ["Spin right", "spin_right"], ["Revert", "revert"], ["Nollie", "nollie"]]],
	["Grinds and Balance", [["Grind", "grind"], ["Balance", "move"]]],
	["Menus", [["Pick", "ollie"], ["Pause", "pause"], ["Restart run", "restart"]]],
]

const CTRL_TIPS := [
	"Hold Cross to crouch, let go to ollie.",
	"Up then Down for a manual. Balance on the back wheels.",
	"Get close to a rail or ledge and press Triangle to grind.",
	"Square flips, Circle grabs. Do them in the air for points.",
	"Land clean to keep your combo going.",
	"Fill the special meter, then Down-Up + Square for a special.",
]

var _back: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## Shows the screen and focuses Back.
func open_screen() -> void:
	visible = true
	_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or _ctrl_is_circle(event):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.is_action_pressed("ollie"):
		# Godot's ui_accept has no gamepad button here, so Cross presses the focused button.
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus is Button:
			get_viewport().set_input_as_handled()
			(focus as Button).pressed.emit()


func _ctrl_is_circle(event: InputEvent) -> bool:
	var jb := event as InputEventJoypadButton
	return jb != null and jb.pressed and jb.button_index == JOY_BUTTON_B


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = CTRL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 20)
	margin.add_child(main)

	var title := UiStyle.label("Controls", UiStyle.SIZE_TITLE, UiStyle.SUNSHINE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", CTRL_COLUMN_GAP)
	main.add_child(columns)
	columns.add_child(_column([CTRL_SECTIONS[0], CTRL_SECTIONS[1]]))
	columns.add_child(_column([CTRL_SECTIONS[2], CTRL_SECTIONS[3]]))

	main.add_child(_tips())

	var back_row := CenterContainer.new()
	main.add_child(back_row)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size = CTRL_BACK_MIN
	_back.add_theme_font_size_override("font_size", UiStyle.SIZE_BODY)
	for k: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		_back.add_theme_color_override(k, UiStyle.INK)
	_back.add_theme_stylebox_override("normal", _ctrl_box(UiStyle.SKY_BLUE, UiStyle.INK, 4))
	_back.add_theme_stylebox_override("hover", _ctrl_box(UiStyle.SKY_BLUE.lightened(0.15), UiStyle.INK, 4))
	_back.add_theme_stylebox_override("pressed", _ctrl_box(UiStyle.SKY_BLUE.darkened(0.15), UiStyle.INK, 4))
	_back.add_theme_stylebox_override("focus", _ctrl_box(UiStyle.SKY_BLUE, UiStyle.WHITE, 8))
	_back.pressed.connect(func() -> void: closed.emit())
	back_row.add_child(_back)


## One column of sections; each section is a heading and its action rows.
func _column(sections: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	for section: Array in sections:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		col.add_child(box)
		var heading: String = section[0]
		box.add_child(UiStyle.label(heading, UiStyle.SIZE_BODY, UiStyle.BUBBLEGUM))
		for row: Array in section[1]:
			var text: String = row[0]
			var action: String = row[1]
			box.add_child(_row(text, action))
	return col


func _row(text: String, action: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var name_label := UiStyle.label(text, UiStyle.SIZE_BODY, UiStyle.WHITE, false)
	name_label.custom_minimum_size.x = CTRL_NAME_MIN
	h.add_child(name_label)
	var button_label := UiStyle.label(_joy_text(action), UiStyle.SIZE_BODY, UiStyle.LIME, false)
	button_label.custom_minimum_size.x = CTRL_BUTTON_MIN
	h.add_child(button_label)
	h.add_child(UiStyle.label(_key_text(action), UiStyle.SIZE_BODY, UiStyle.SKY_BLUE, false))
	return h


func _tips() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(UiStyle.label("How to", UiStyle.SIZE_BIG, UiStyle.SUNSHINE))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 16)
	box.add_child(grid)
	for i: int in CTRL_TIPS.size():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiStyle.panel_style(CTRL_CARD))
		card.custom_minimum_size = Vector2(CTRL_TIP_WIDTH, 0)
		grid.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		row.add_child(UiStyle.label(str(i + 1), UiStyle.SIZE_BODY, UiStyle.SUNSHINE))
		var tip_text: String = CTRL_TIPS[i]
		var tip := UiStyle.label(tip_text, UiStyle.SIZE_BODY, UiStyle.WHITE, false)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tip)
	return box


## Input events bound to an action. "move" gathers the four move_* actions from controls.gd.
func _events(action: String) -> Array:
	if action != "move":
		return InputMap.action_get_events(action)
	var all: Array = []
	for a: String in Controls.MOVE:
		all.append_array(InputMap.action_get_events(a))
	return all


## PlayStation names for the joypad events bound to an action, e.g. "Cross" or "Left stick / D-pad".
func _joy_text(action: String) -> String:
	var names: PackedStringArray = []
	for e: InputEvent in _events(action):
		var n: String = ""
		if e is InputEventJoypadButton:
			n = _button_name((e as InputEventJoypadButton).button_index)
		elif e is InputEventJoypadMotion:
			n = _axis_name((e as InputEventJoypadMotion).axis)
		if n != "" and not names.has(n):
			names.append(n)
	return " / ".join(names)


## Keyboard keys bound to an action. The move row is WASD plus arrows, written out.
func _key_text(action: String) -> String:
	if action == "move":
		return "WASD / Arrows"
	var names: PackedStringArray = []
	for e: InputEvent in _events(action):
		if e is InputEventKey:
			var key_event := e as InputEventKey
			var code: int = key_event.physical_keycode
			if code == KEY_NONE:
				code = key_event.keycode
			var n: String = OS.get_keycode_string(code)
			if n != "" and not names.has(n):
				names.append(n)
	return " / ".join(names)


func _button_name(b: int) -> String:
	match b:
		JOY_BUTTON_A:
			return "Cross"
		JOY_BUTTON_X:
			return "Square"
		JOY_BUTTON_B:
			return "Circle"
		JOY_BUTTON_Y:
			return "Triangle"
		JOY_BUTTON_LEFT_SHOULDER:
			return "L1"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "R1"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_BACK:
			return "Select"
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			return "D-pad"
	return ""


func _axis_name(a: int) -> String:
	match a:
		JOY_AXIS_TRIGGER_RIGHT:
			return "R2"
		JOY_AXIS_TRIGGER_LEFT:
			return "L2"
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
			return "Left stick"
	return ""


func _ctrl_box(fill: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(26)
	s.set_border_width_all(border_w)
	s.border_color = border
	s.set_content_margin_all(18)
	return s
