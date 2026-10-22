class_name TrickInput
extends RefCounted
## Turns per-tick stick and button input into trick requests. Pure logic: feed once per physics tick (60 Hz).
## Stick convention: x right, y down (up on the stick is y < 0).

const BUFFER_TICKS: int = 6
const DOUBLE_TAP_TICKS: int = 15
const SEQUENCE_TICKS: int = 20
## A manual's first direction must be a flick, held at most this long: holding up to push, then pulling back to
## brake, is riding, not a manual.
const MANUAL_TAP_TICKS: int = 12
const HISTORY_MAX: int = 8
## Press buffers (docs/feel_targets.md): how many ticks before the moment it can act a press still counts.
## An ollie tapped this close before touchdown pops on landing (THUG-style jump buffer, about 0.1 s).
const OLLIE_LAND_BUFFER_TICKS: int = 7
const NEVER: int = -1000000
## THUG2 ollie variants, read by ollie_variant() at the ollie's release from fresh up taps of the stick (the stick
## entering the up sector N / NE / NW from outside it) around the ollie press: up + ollie (an up tap together with the
## press: within NO_COMPLY_TICKS before it) is a no-comply; with another up tap before that, within BONELESS_TICKS of
## the press, a boneless (up, up + ollie). A
## tap up to PLANT_SLACK_TICKS after the press still counts (pressed together). Holding up to push is one old tap, so a
## push that started earlier never turns an ollie into either.
const BONELESS_TICKS: int = 18
const NO_COMPLY_TICKS: int = 4
const PLANT_SLACK_TICKS: int = 3
const UP_TAPS_MAX: int = 6
## The last up tap must be a flick, not a push: let go again by the release, or held at most FLICK_TICKS. More than two
## taps in the boneless window, or a fresh tap during the crouch after PLANT_SLACK_TICKS, is a jittery push (the stick
## wobbling across the deadzone), never a move.
const FLICK_TICKS: int = 6
const UP_DIRS: PackedStringArray = ["N", "NE", "NW"]
const BUTTONS: PackedStringArray = ["flip", "grab", "grind"]
## Indexed by quantized octant, counter-clockwise from east (stick angle with y up).
const DIRS: PackedStringArray = ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]

var _tick: int = 0
var _last_dir: String = ""
var _last_dir_tick: int = NEVER
## Distinct non-neutral dirs in entry order, each stamped with the last tick it was held.
var _history: Array[Dictionary] = []
## button name -> tick of its most recent press (every button, so pressed_within() can buffer any of them).
var _last_press: Dictionary = {}
## Ticks at which the stick last entered the up sector (fresh up taps), oldest first.
var _up_taps: Array[int] = []
var _was_up: bool = false
## The stick was up as the ollie went down (or within PLANT_SLACK_TICKS after): "up + ollie" pressed together.
var _up_with_ollie: bool = false


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
	var up_now: bool = UP_DIRS.has(raw)
	if up_now and not _was_up:
		_up_taps.append(_tick)
		if _up_taps.size() > UP_TAPS_MAX:
			_up_taps.pop_front()
	_was_up = up_now
	if just_pressed.has("ollie"):
		_up_with_ollie = up_now
	elif up_now and _last_press.has("ollie") and _tick - int(_last_press["ollie"]) <= PLANT_SLACK_TICKS:
		_up_with_ollie = true
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
	for b: Variant in just_pressed:
		if not BUTTONS.has(str(b)):
			_last_press[str(b)] = _tick  # flip/grab/grind are stamped below, after their double-tap check
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


## Like manual_sequence(), but only when the first of the two dirs was a quick flick (held at most MANUAL_TAP_TICKS),
## so a held push followed by a brake doesn't start a manual.
func manual_tap_sequence() -> Array:
	var recent: Array = []
	for entry: Dictionary in _history:
		if _tick - int(entry["tick"]) <= SEQUENCE_TICKS:
			recent.append(entry)
	if recent.size() < 2:
		return []
	var first: Dictionary = recent[recent.size() - 2]
	if int(first["tick"]) - int(first.get("start", first["tick"])) > MANUAL_TAP_TICKS:
		return []
	return [str(first["dir"]), str(recent[recent.size() - 1]["dir"])]


## manual_tap_sequence(), but only on the tick its second dir was entered, so a flick acts once. Inside a grind or a
## manual (where the stick also balances) this is the one-shot manual flick: a manual queued off a rail, or the other
## manual switched to.
func manual_flick_now() -> Array:
	if _history.is_empty() or int(_history[_history.size() - 1].get("start", -1)) != _tick:
		return []
	return manual_tap_sequence()


## True when `button` went down within the last `ticks` ticks (0: only this tick). A press is a buffer: it can act
## a moment after it happened, e.g. an ollie tapped just before touchdown. Call consume() once it has acted.
func pressed_within(button: String, ticks: int) -> bool:
	if not _last_press.has(button):
		return false
	return _tick - int(_last_press[button]) <= ticks


## Forgets the last press of `button`, so a buffered press acts only once (double taps of it restart).
func consume(button: String) -> void:
	_last_press.erase(button)


## The THUG2 ollie variant the stick taps around the last ollie press make: "boneless" (up, up + ollie), "no_comply"
## (up + ollie) or "" (a plain ollie). See BONELESS_TICKS.
func ollie_variant() -> String:
	if not _last_press.has("ollie") or not _up_with_ollie:
		return ""  # the stick was not up with the press: a blip of push a few ticks before is not "up + ollie"
	var press: int = int(_last_press["ollie"])
	var taps: int = 0
	var recent: bool = false
	if _was_up and not _up_taps.is_empty() and _tick - _up_taps[_up_taps.size() - 1] > FLICK_TICKS:
		return ""  # still holding up since well before: pushing
	for at: int in _up_taps:
		var d: int = at - press
		if d > PLANT_SLACK_TICKS:
			return ""  # the stick went up again during the crouch: pushing, not a move
		if d < -BONELESS_TICKS:
			continue
		taps += 1
		if d >= -NO_COMPLY_TICKS:
			recent = true
	if taps > 2 or not recent:
		return ""  # no up tap with the press (a push that ended earlier), or a jittery push
	return "boneless" if taps == 2 else "no_comply"


func clear() -> void:
	_tick = 0
	_last_dir = ""
	_last_dir_tick = NEVER
	_history.clear()
	_last_press.clear()
	_up_taps.clear()
	_was_up = false
	_up_with_ollie = false


func _record(dir: String) -> void:
	if not _history.is_empty() and str(_history[_history.size() - 1]["dir"]) == dir:
		var last: Dictionary = _history[_history.size() - 1]
		if _tick - int(last["tick"]) > 1:
			last["start"] = _tick  # let go and pressed again: a fresh flick
		last["tick"] = _tick
		return
	_history.append({"dir": dir, "tick": _tick, "start": _tick})
	if _history.size() > HISTORY_MAX:
		_history.pop_front()
