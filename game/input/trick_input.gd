class_name TrickInput
extends RefCounted
## Turns per-tick stick and button input into trick requests. Pure logic: feed once per physics tick (60 Hz).
## Stick convention: x right, y down (up on the stick is y < 0).

const BUFFER_TICKS: int = 6
const DOUBLE_TAP_TICKS: int = 15
const SEQUENCE_TICKS: int = 20
const HISTORY_MAX: int = 8
const NEVER: int = -1000000
const BUTTONS: PackedStringArray = ["flip", "grab", "grind"]
## Indexed by quantized octant, counter-clockwise from east (stick angle with y up).
const DIRS: PackedStringArray = ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]

var _tick: int = 0
var _last_dir: String = ""
var _last_dir_tick: int = NEVER
## Distinct non-neutral dirs in entry order, each stamped with the last tick it was held.
var _history: Array[Dictionary] = []
## button name -> tick of its most recent press.
var _last_press: Dictionary = {}


## 8-way direction of the stick, or "" when inside the deadzone.
static func quantize(stick: Vector2, deadzone: float = 0.4) -> String:
	if stick.length_squared() == 0.0 or stick.length() < deadzone:
		return ""
	var angle: float = atan2(-stick.y, stick.x)
	var index: int = posmod(roundi(angle / (PI / 4.0)), 8)
	return DIRS[index]


## Advances one tick. Returns one request per just-pressed flip, grab or grind.
@warning_ignore("unused_parameter")
func feed(stick: Vector2, just_pressed: Array, held: Array) -> Array:
	_tick += 1
	var raw: String = quantize(stick)
	if raw != "":
		_last_dir = raw
		_last_dir_tick = _tick
		_record(raw)
	var dir: String = raw
	if dir == "" and _tick - _last_dir_tick <= BUFFER_TICKS:
		dir = _last_dir

	var requests: Array[Dictionary] = []
	if just_pressed.is_empty():
		return requests
	var seq: Array = manual_sequence()
	for name_value: Variant in just_pressed:
		var button: String = str(name_value)
		if not BUTTONS.has(button):
			continue
		var double_tap: bool = false
		if _last_press.has(button):
			double_tap = _tick - int(_last_press[button]) <= DOUBLE_TAP_TICKS
		_last_press[button] = _tick
		requests.append({
			"button": button,
			"dir": dir,
			"double_tap": double_tap,
			"sequence": seq.duplicate(),
		})
	return requests


## The last two distinct dirs entered within the last SEQUENCE_TICKS ticks, oldest first; else [].
func manual_sequence() -> Array:
	var recent: Array = []
	for entry: Dictionary in _history:
		if _tick - int(entry["tick"]) <= SEQUENCE_TICKS:
			recent.append(str(entry["dir"]))
	if recent.size() < 2:
		return []
	return [recent[recent.size() - 2], recent[recent.size() - 1]]


func clear() -> void:
	_tick = 0
	_last_dir = ""
	_last_dir_tick = NEVER
	_history.clear()
	_last_press.clear()


func _record(dir: String) -> void:
	if not _history.is_empty() and str(_history[_history.size() - 1]["dir"]) == dir:
		_history[_history.size() - 1]["tick"] = _tick
		return
	_history.append({"dir": dir, "tick": _tick})
	if _history.size() > HISTORY_MAX:
		_history.pop_front()
