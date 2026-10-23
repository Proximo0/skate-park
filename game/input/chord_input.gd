class_name ChordInput
extends RefCounted
## Two buttons pressed together as one action: spin_left + spin_right (Q + E, L1 + R1) is the ramp snap. Pure logic:
## feed once per physics tick (60 Hz) with the tick's just-pressed and held buttons.
## The chord fires on the tick the second button goes down, when the first went down at most WINDOW_TICKS before and
## is still held. After it fires both buttons are "spent" (suppressing() is true) until both are released, so the
## presses do not also spin. A press counts when the button shows up in just_pressed or newly in held (scripted
## input may hold a button without a just-pressed tick). A direct `fire_action` press (a bound action or a script)
## also fires.

const WINDOW_TICKS: int = 6  ## 0.1 s at 60 Hz
const NEVER: int = -1000000

var first: String
var second: String
var fire_action: String

var _tick: int = 0
var _down_a: int = NEVER  ## tick `first` last went down
var _down_b: int = NEVER
var _held_a: bool = false
var _held_b: bool = false
var _spent: bool = false


func _init(a: String = "spin_left", b: String = "spin_right", action: String = "ramp_snap") -> void:
	first = a
	second = b
	fire_action = action


## Advances one tick. Returns true on the tick the chord fires.
func feed(just_pressed: Array, held: Array) -> bool:
	_tick += 1
	var a_now: bool = held.has(first) or just_pressed.has(first)
	var b_now: bool = held.has(second) or just_pressed.has(second)
	var a_edge: bool = just_pressed.has(first) or (a_now and not _held_a)
	var b_edge: bool = just_pressed.has(second) or (b_now and not _held_b)
	_held_a = a_now
	_held_b = b_now
	if a_edge:
		_down_a = _tick
	if b_edge:
		_down_b = _tick
	if _spent and not a_now and not b_now:
		_spent = false
	if just_pressed.has(fire_action):
		_spent = _spent or a_now or b_now
		return true
	if _spent or not (a_now and b_now) or not (a_edge or b_edge):
		return false
	if absi(_down_a - _down_b) > WINDOW_TICKS:
		return false
	_spent = true
	return true


## True while the buttons of a fired chord are still down: their spin is cancelled.
func suppressing() -> bool:
	return _spent


## Ticks since the earlier of the two presses that made the chord (0 when it went down this tick): how much spin the
## first press already gave, so the caller can undo it.
func lead_ticks() -> int:
	return clampi(_tick - mini(_down_a, _down_b), 0, WINDOW_TICKS)


func to_dict() -> Dictionary:
	return {"tick": _tick, "down_a": _down_a, "down_b": _down_b, "held_a": _held_a, "held_b": _held_b, "spent": _spent}


func from_dict(d: Dictionary) -> void:
	_tick = int(d.get("tick", 0))
	_down_a = int(d.get("down_a", NEVER))
	_down_b = int(d.get("down_b", NEVER))
	_held_a = bool(d.get("held_a", false))
	_held_b = bool(d.get("held_b", false))
	_spent = bool(d.get("spent", false))
