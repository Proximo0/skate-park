class_name ControlRemap
extends RefCounted
## Control remapping for the keyboard and the gamepad. The player's picks are overrides on top of the defaults in
## game/autoload/controls.gd and live in user://controls.json: {"keys": {action: physical keycode}, "pads": {action: joy
## button}}. apply() rewrites the InputMap (an action's key events, or its joypad BUTTON events; stick, d-pad motion and
## trigger events are never touched), reset() drops every override. Scripted runs (tests, bots, captures) never read or
## write the file, so they always see the defaults.
##
## Rebinding a key or button that another remappable action already uses swaps the two, so no two actions share one.
## The four move actions remap their first key only (the WASD one): the arrow keys, the stick and the d-pad stay.

const SAVE_PATH: String = "user://controls.json"
const DEFAULTS: Script = preload("res://game/autoload/controls.gd")
## [label, action] in the order the settings screen lists them. Move rows are keyboard only.
const ROWS: Array = [
	["Ollie", "ollie"], ["Flip", "flip"], ["Grab", "grab"], ["Grind", "grind"], ["Spin left", "spin_left"],
	["Spin right", "spin_right"], ["Revert", "revert"], ["Nollie", "nollie"], ["Focus", "focus"],
	["Step off board", "dismount"], ["Pause", "pause"], ["Restart run", "restart"],
	["Move up", "move_up"], ["Move down", "move_down"], ["Move left", "move_left"], ["Move right", "move_right"],
]
const MOVE_DEFAULT_KEYS: Dictionary = {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S}

static var keys: Dictionary = {}  ## action -> physical keycode (overrides only)
static var pads: Dictionary = {}  ## action -> JoyButton (overrides only)
static var _loaded: bool = false


## Reads the saved overrides and applies them. Call once at start (GameSettings.ensure_loaded does).
static func load_saved() -> void:
	if _loaded:
		return
	_loaded = true
	keys.clear()
	pads.clear()
	if Flags.is_scripted_run() or not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	for pair: Array in [["keys", keys], ["pads", pads]]:
		var src: Variant = d.get(pair[0], {})
		if typeof(src) != TYPE_DICTIONARY:
			continue
		for a: Variant in src as Dictionary:
			var v: Variant = (src as Dictionary)[a]
			if typeof(a) == TYPE_STRING and is_remappable(str(a)) and (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT):
				(pair[1] as Dictionary)[str(a)] = int(v)
	apply()


static func save() -> void:
	if Flags.is_scripted_run():
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"keys": keys, "pads": pads}))


static func is_remappable(action: String) -> bool:
	for r: Array in ROWS:
		if r[1] == action:
			return true
	return false


static func has_pad(action: String) -> bool:
	return not action.begins_with("move_")


## The key an action uses now (physical keycode), KEY_NONE if none.
static func key_of(action: String) -> int:
	if keys.has(action):
		return int(keys[action])
	return default_key(action)


## The joypad button an action uses now, -1 if none (revert and nollie are on the triggers by default).
static func pad_of(action: String) -> int:
	if pads.has(action):
		return int(pads[action])
	return default_pad(action)


static func default_key(action: String) -> int:
	if MOVE_DEFAULT_KEYS.has(action):
		return int(MOVE_DEFAULT_KEYS[action])
	var def: Variant = (DEFAULTS.get_script_constant_map()["BUTTONS"] as Dictionary).get(action, null)
	if def == null or (def[0] as Array).is_empty():
		return KEY_NONE
	return int((def[0] as Array)[0])


static func default_pad(action: String) -> int:
	if not has_pad(action):
		return -1
	var def: Variant = (DEFAULTS.get_script_constant_map()["BUTTONS"] as Dictionary).get(action, null)
	if def == null or (def[1] as Array).is_empty():
		return -1
	return int((def[1] as Array)[0])


## Display name of a key ("Space", "J").
static func key_name(code: int) -> String:
	return "None" if code == KEY_NONE else OS.get_keycode_string(code)


## Short names for a pad button (PlayStation / Xbox); "Trigger" for an action still on its trigger.
static func pad_name(action: String) -> String:
	var b: int = pad_of(action)
	if b < 0:
		return "Trigger" if action == "revert" or action == "nollie" else "None"
	return PAD_NAMES.get(b, "Button %d" % b)


const PAD_NAMES: Dictionary = {
	JOY_BUTTON_A: "Cross / A", JOY_BUTTON_B: "Circle / B", JOY_BUTTON_X: "Square / X", JOY_BUTTON_Y: "Triangle / Y",
	JOY_BUTTON_LEFT_SHOULDER: "L1 / LB", JOY_BUTTON_RIGHT_SHOULDER: "R1 / RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Select", JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}


## Binds a key to an action (swapping with the action that had it). Applies and saves.
static func set_key(action: String, code: int) -> void:
	if not is_remappable(action) or code == KEY_NONE:
		return
	for r: Array in ROWS:
		var other: String = r[1]
		if other != action and key_of(other) == code:
			keys[other] = key_of(action)
	keys[action] = code
	apply()
	save()


## Binds a joypad button to an action (swapping with the action that had it). Applies and saves.
static func set_pad(action: String, button: int) -> void:
	if not is_remappable(action) or not has_pad(action) or button < 0:
		return
	for r: Array in ROWS:
		var other: String = r[1]
		if other != action and has_pad(other) and pad_of(other) == button:
			pads[other] = pad_of(action)
	pads[action] = button
	apply()
	save()


## Back to the default controls.
static func reset() -> void:
	keys.clear()
	pads.clear()
	apply()
	save()


## Rewrites the InputMap from the defaults plus the overrides.
static func apply() -> void:
	for r: Array in ROWS:
		var action: String = r[1]
		if not InputMap.has_action(action):
			continue
		_rebind_keys(action, key_of(action))
		if has_pad(action):
			_rebind_pad(action, pad_of(action))


static func _rebind_keys(action: String, code: int) -> void:
	var is_move: bool = MOVE_DEFAULT_KEYS.has(action)
	for e: InputEvent in InputMap.action_get_events(action):
		var ek := e as InputEventKey
		if ek == null:
			continue
		var kc: int = ek.physical_keycode
		if is_move and kc != int(MOVE_DEFAULT_KEYS[action]) and not _is_tracked(action, kc):
			continue  # an arrow key: stays
		InputMap.action_erase_event(action, e)
	if code != KEY_NONE:
		var ne := InputEventKey.new()
		ne.physical_keycode = code as Key
		InputMap.action_add_event(action, ne)
		if is_move:
			_last_move[action] = code


static var _last_move: Dictionary = {}  ## action -> the key apply() put on a move action last (so a later apply() finds it)


static func _is_tracked(action: String, kc: int) -> bool:
	return _last_move.get(action, -1) == kc


static func _rebind_pad(action: String, button: int) -> void:
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			InputMap.action_erase_event(action, e)
	if button >= 0:
		var nb := InputEventJoypadButton.new()
		nb.button_index = button as JoyButton
		InputMap.action_add_event(action, nb)
