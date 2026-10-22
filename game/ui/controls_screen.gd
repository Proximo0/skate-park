class_name ControlsScreen
extends Control
## Full-screen controls help. Lists each player action with its PlayStation / Xbox button names and keyboard key,
## read from the InputMap that game/autoload/controls.gd fills, then six short tips for kids.
## Back, ui_cancel or pause emit closed. Showing and hiding the screen is up to the owner (see open_screen).

signal closed

const CTRL_ROW_FONT: int = 28
const CTRL_BUTTON_INK := Color("#C8382B")  ## coral deep enough to read on cream
const CTRL_KEY_INK := Color("#00758F")  ## teal deep enough to read on cream
const CTRL_TIP_FONT: int = 23
const CTRL_BACK_MIN := Vector2(320, 60)
const CTRL_COLUMN_GAP := 48
const CTRL_NAME_MIN := 200
const CTRL_BUTTON_MIN := 330
const CTRL_TIP_WIDTH := 400  ## three equal tip cards across the screen

## [heading, [[label, action], ...]]. "move" stands for the four move_* actions. Balance rides the move stick.
## Pick shows the ollie binding (Cross, Space): the menus accept it as well. Chorded actions (Controls.CHORDS) show
## their two buttons joined with "+".
const CTRL_SECTIONS := [
	["Riding", [["Move", "move"], ["Ollie", "ollie"], ["Ramp snap", "ramp_snap"]]],
	["Tricks", [["Flip", "flip"], ["Grab", "grab"], ["Spin left", "spin_left"], ["Spin right", "spin_right"], ["Revert", "revert"], ["Nollie", "nollie"]]],
	["Grinds and Balance", [["Grind", "grind"], ["Balance", "move"]]],
	["Menus", [["Pick", "ollie"], ["Pause", "pause"], ["Restart run", "restart"]]],
]

const CTRL_TIPS := [
	"Hold Cross to crouch, let go to ollie.",
	"Up then Down for a manual. Balance on the back wheels.",
	"Triangle near a rail to grind. Ollie to the next rail and Triangle to link.",
	"Square flips, Circle grabs. Full special meter: Down-Up + Square.",
	"Up, Up + Ollie: boneless. Up + Ollie: no comply. Ollie at a wall: wallplant.",
	"Revert while rolling to powerslide, or in the air over a bank to acid drop.",
	"On a rail: Triangle + stick switches the grind. Hold Ollie to charge the pop.",
	"In a manual: flick the stick to switch, spin to pivot, Revert to roll out, Grab + stick for flatland.",
	"On a wall or a lip: Flip, Grab or Revert pops you out with that trick.",
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
	var sky: SkyBackdrop = SkyBackdrop.new()
	sky.sparkles = false
	add_child(sky)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	margin.add_child(main)

	var title := AnimeText.new("CONTROLS", 56, UiStyle.SUNSHINE)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main.add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", CTRL_COLUMN_GAP)
	main.add_child(columns)
	for pair: Array in [[CTRL_SECTIONS[0], CTRL_SECTIONS[1]], [CTRL_SECTIONS[2], CTRL_SECTIONS[3]]]:
		var card: PanelContainer = MenuKit.panel()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(_column(pair))
		columns.add_child(card)

	main.add_child(_tips())

	var back_row := CenterContainer.new()
	main.add_child(back_row)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size = CTRL_BACK_MIN
	_back.theme_type_variation = SkateThemeBuilder.BTN_SUN
	_back.pressed.connect(func() -> void: closed.emit())
	back_row.add_child(_back)


## One column of sections; each section is a heading and its action rows.
func _column(sections: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	for section: Array in sections:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		col.add_child(box)
		var heading: String = section[0]
		box.add_child(MenuKit.text(heading.to_upper(), CTRL_ROW_FONT, CTRL_BUTTON_INK))
		for row: Array in section[1]:
			var text: String = row[0]
			var action: String = row[1]
			box.add_child(_row(text, action))
	return col


func _row(text: String, action: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var name_label := MenuKit.text(text, CTRL_ROW_FONT)
	name_label.custom_minimum_size.x = CTRL_NAME_MIN
	h.add_child(name_label)
	var button_label := MenuKit.text(_joy_text(action), CTRL_ROW_FONT, CTRL_BUTTON_INK)
	button_label.custom_minimum_size.x = CTRL_BUTTON_MIN
	h.add_child(button_label)
	h.add_child(MenuKit.text(_key_text(action), CTRL_ROW_FONT, CTRL_KEY_INK))
	return h


func _tips() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(UiStyle.label("HOW TO", UiStyle.SIZE_BODY, UiStyle.SUNSHINE))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for i: int in CTRL_TIPS.size():
		var card: PanelContainer = MenuKit.panel(SkateThemeBuilder.PNL_TEAL)
		card.custom_minimum_size = Vector2(CTRL_TIP_WIDTH, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		row.add_child(UiStyle.label(str(i + 1), UiStyle.SIZE_BIG, UiStyle.WHITE))
		var tip_text: String = CTRL_TIPS[i]
		var tip := MenuKit.text(tip_text, CTRL_TIP_FONT)
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
	if Controls.CHORDS.has(action):
		return _chord_text(action, true)
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
	if Controls.CHORDS.has(action):
		return _chord_text(action, false)
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


## "L1 + R1 / LB + RB" or "Q + E": the chord's two buttons, PlayStation then Xbox names for the pad.
func _chord_text(action: String, joy: bool) -> String:
	var parts: Array = Controls.CHORDS[action]
	if not joy:
		return "%s + %s" % [_key_text(str(parts[0])), _key_text(str(parts[1]))]
	var a: PackedStringArray = _joy_text(str(parts[0])).split(" / ")
	var b: PackedStringArray = _joy_text(str(parts[1])).split(" / ")
	if a.size() == 2 and b.size() == 2:
		return "%s + %s / %s + %s" % [a[0], b[0], a[1], b[1]]
	return "%s + %s" % [" / ".join(a), " / ".join(b)]


func _button_name(b: int) -> String:
	match b:
		JOY_BUTTON_A:
			return "Cross / A"
		JOY_BUTTON_X:
			return "Square / X"
		JOY_BUTTON_B:
			return "Circle / B"
		JOY_BUTTON_Y:
			return "Triangle / Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "L1 / LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "R1 / RB"
		JOY_BUTTON_START:
			return "Start / Menu"
		JOY_BUTTON_BACK:
			return "Select / View"
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			return "D-pad"
	return ""


func _axis_name(a: int) -> String:
	match a:
		JOY_AXIS_TRIGGER_RIGHT:
			return "R2 / RT"
		JOY_AXIS_TRIGGER_LEFT:
			return "L2 / LT"
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
			return "Left stick"
	return ""
