extends Node
## Input actions, registered in code so they live in one readable place.
## Gamepad layout follows THUG2 on PS2 (Cross = ollie, Square = flip, Circle = grab, Triangle = grind).

const MOVE := ["move_left", "move_right", "move_up", "move_down"]

## action -> [keyboard keys], [joypad buttons]
const BUTTONS := {
	"ollie": [[KEY_SPACE], [JOY_BUTTON_A]],
	"flip": [[KEY_J], [JOY_BUTTON_X]],
	"grab": [[KEY_K], [JOY_BUTTON_B]],
	"grind": [[KEY_I], [JOY_BUTTON_Y]],
	"spin_left": [[KEY_Q], [JOY_BUTTON_LEFT_SHOULDER]],
	"spin_right": [[KEY_E], [JOY_BUTTON_RIGHT_SHOULDER]],
	"revert": [[KEY_L], []],  # plus right trigger, added below
	"nollie": [[KEY_U], []],  # plus left trigger, added below
	"dismount": [[KEY_C], [JOY_BUTTON_LEFT_STICK]],  # step off / on the board
	"pause": [[KEY_ESCAPE], [JOY_BUTTON_START]],
	"restart": [[KEY_BACKSPACE], [JOY_BUTTON_BACK]],
	"debug_stamp": [[KEY_F10], []],
}


func _ready() -> void:
	_add_move("move_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT)
	_add_move("move_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT)
	_add_move("move_up", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP)
	_add_move("move_down", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN)
	for action: String in BUTTONS:
		_ensure(action)
		for k: Key in BUTTONS[action][0]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
		for b: JoyButton in BUTTONS[action][1]:
			var j := InputEventJoypadButton.new()
			j.button_index = b
			InputMap.action_add_event(action, j)
	_add_trigger("revert", JOY_AXIS_TRIGGER_RIGHT)
	_add_trigger("nollie", JOY_AXIS_TRIGGER_LEFT)


## Stick direction with keyboard and d-pad merged, length <= 1.
func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)


func _add_move(action: String, keys: Array, axis: JoyAxis, sign_: float, dpad: JoyButton) -> void:
	_ensure(action)
	for k: Key in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	var m := InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = sign_
	InputMap.action_add_event(action, m)
	var d := InputEventJoypadButton.new()
	d.button_index = dpad
	InputMap.action_add_event(action, d)


func _add_trigger(action: String, axis: JoyAxis) -> void:
	var m := InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = 1.0
	InputMap.action_add_event(action, m)
