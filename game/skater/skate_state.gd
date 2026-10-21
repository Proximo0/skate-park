class_name SkateState
extends RefCounted
## Skater state machine: rolling, air, grind, manual, lip, wallride, bail. Pure logic: no Node, no clock.
## Callers feed named events through event() and advance time through tick(delta).
## Combo rules: mark_trick() opens the combo. It lands when the skater is ROLLING and LAND_WINDOW has
## passed since the last landing or revert. Bailing with an open combo emits combo_bailed.
## Manual linking: ROLLING -> MANUAL -> ROLLING keeps the combo open, because the landing timer only runs in ROLLING.
## Revert: a ROLLING state reached by "land" can be reverted within REVERT_WINDOW. The window restarts.

enum State { ROLLING, AIR, GRIND, MANUAL, LIP, WALLRIDE, BAIL }

signal state_changed(from: State, to: State)
signal combo_landed
signal combo_bailed

const LAND_WINDOW: float = 0.35
const REVERT_WINDOW: float = 0.35
const BAIL_TIME: float = 1.2

var state: State = State.ROLLING
var time_in_state: float = 0.0
var combo_open: bool = false

## True only while ROLLING was entered by "land" (or a revert in that state). Gates the revert event.
var _revert_armed: bool = false


## Applies a named transition. Returns false, with no state or signal change, when it is not allowed.
func event(event_name: String) -> bool:
	if event_name == "revert":
		if state != State.ROLLING or not _revert_armed or time_in_state >= REVERT_WINDOW:
			return false
		time_in_state = 0.0
		return true
	var target: int = _target(event_name)
	if target < 0:
		return false
	_enter(target as State, event_name)
	return true


## Marks that a trick scored, which opens the combo.
func mark_trick() -> void:
	combo_open = true


## Advances the state timer. While ROLLING with an open combo, the combo lands once LAND_WINDOW has passed.
func tick(delta: float) -> void:
	time_in_state += delta
	if state == State.ROLLING and combo_open and time_in_state >= LAND_WINDOW:
		combo_open = false
		combo_landed.emit()


func state_name() -> String:
	var names: Array = State.keys()
	return String(names[state])


## True on the ground: ROLLING or MANUAL.
func is_grounded() -> bool:
	return state == State.ROLLING or state == State.MANUAL


## Tricks like flips and grabs are allowed in AIR only.
func can_trick_in_air() -> bool:
	return state == State.AIR


## Returns the target state for an event, or -1 if the event is not allowed from the current state.
func _target(event_name: String) -> int:
	match event_name:
		"ollie":
			if state in [State.ROLLING, State.MANUAL, State.GRIND, State.LIP, State.WALLRIDE]:
				return State.AIR
		"fall_off":
			if state in [State.ROLLING, State.GRIND, State.MANUAL, State.WALLRIDE]:
				return State.AIR
		"land":
			if state == State.AIR:
				return State.ROLLING
		"land_manual":
			if state == State.AIR:
				return State.MANUAL
		"bail":
			if state != State.BAIL:
				return State.BAIL
		"grind_start":
			if state in [State.AIR, State.ROLLING]:
				return State.GRIND
		"manual_start":
			if state == State.ROLLING:
				return State.MANUAL
		"manual_end":
			if state == State.MANUAL:
				return State.ROLLING
		"lip_start":
			if state == State.AIR:
				return State.LIP
		"lip_end":
			if state == State.LIP:
				return State.AIR
		"wallride_start":
			if state == State.AIR:
				return State.WALLRIDE
		"recover":
			if state == State.BAIL and time_in_state >= BAIL_TIME:
				return State.ROLLING
		_:
			pass
	return -1


## Changes state, resets the timer, sets the revert gate, and emits. Entering BAIL closes an open combo.
func _enter(to: State, cause: String) -> void:
	var from: State = state
	state = to
	time_in_state = 0.0
	_revert_armed = to == State.ROLLING and cause == "land"
	state_changed.emit(from, to)
	if to == State.BAIL and combo_open:
		combo_open = false
		combo_bailed.emit()
