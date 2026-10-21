class_name Combo
extends RefCounted
## THUG2-style combo scoring. Pure logic: no Node, no clock.
## combo total = (sum of trick points) x (number of tricks in the combo).
## Repeating a trick id inside one combo is worth less each time (REPEAT_FACTORS).
## Spins add a bonus: points = round(base x repeat x (1 + 0.5 x spins)).

signal trick_added(name: String, points: int)

const REPEAT_FACTORS: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.1]
const SPIN_STEP_DEG: int = 180
const SPIN_SLACK_DEG: int = 30
const SPIN_BONUS_PER_STEP: float = 0.5
const NAME_LIST_MAX: int = 5

var landed_total: int = 0
var best_combo: int = 0

var _tricks: Array[Dictionary] = []
var _hold_accum: float = 0.0


## Adds a trick to the current combo. spin_degrees may be negative; its absolute value is used.
func add_trick(id: String, name: String, base_points: int, spin_degrees: int = 0) -> void:
	var repeat: int = _repeat_count(id)
	var repeat_factor: float = REPEAT_FACTORS[mini(repeat, REPEAT_FACTORS.size() - 1)]
	var spin_abs: int = absi(spin_degrees)
	var spins: int = (spin_abs + SPIN_SLACK_DEG) / SPIN_STEP_DEG
	var spin_mult: float = 1.0 + SPIN_BONUS_PER_STEP * float(spins)
	var points: int = roundi(float(base_points) * repeat_factor * spin_mult)
	var display_name: String = name
	if spin_abs >= SPIN_STEP_DEG:
		display_name = "%d %s" % [spin_abs, name]
	_tricks.append({"id": id, "name": display_name, "points": points, "gap": false})
	_hold_accum = 0.0
	trick_added.emit(display_name, points)


## Held tricks (grinds, manuals, grabs) accrue points into the most recent trick.
## Fractional points carry over until they add up to a whole point.
func add_hold_points(points_per_sec: int, delta: float) -> void:
	if _tricks.is_empty():
		return
	_hold_accum += float(points_per_sec) * delta
	var whole: int = floori(_hold_accum)
	if whole <= 0:
		return
	_hold_accum -= float(whole)
	var last: Dictionary = _tricks[_tricks.size() - 1]
	var last_points: int = last["points"]
	last["points"] = last_points + whole


## A gap (a scored obstacle or spot) counts as a trick. It is not repeat-penalized and gets no spin bonus.
func add_gap(name: String, points: int) -> void:
	_tricks.append({"id": "", "name": name, "points": points, "gap": true})
	_hold_accum = 0.0
	trick_added.emit(name, points)


func is_active() -> bool:
	return not _tricks.is_empty()


func trick_count() -> int:
	return _tricks.size()


## Sum of the points of every trick in the combo, before the trick-count multiplier.
func base_sum() -> int:
	var sum: int = 0
	for entry: Dictionary in _tricks:
		var p: int = entry["points"]
		sum += p
	return sum


func multiplier() -> int:
	return _tricks.size()


func total() -> int:
	return base_sum() * multiplier()


## Trick names joined by " + ", last NAME_LIST_MAX only, with "... + " in front when some are cut.
func display_text() -> String:
	var names: PackedStringArray = []
	for entry: Dictionary in _tricks:
		var n: String = entry["name"]
		names.append(n)
	var start: int = maxi(0, names.size() - NAME_LIST_MAX)
	var text: String = " + ".join(names.slice(start))
	if start > 0:
		text = "... + " + text
	return text


## Lands the combo: adds its total to landed_total, updates best_combo, resets. Returns the total.
func land() -> int:
	var earned: int = total()
	landed_total += earned
	best_combo = maxi(best_combo, earned)
	_reset()
	return earned


## Bails the combo: scores nothing and resets. landed_total and best_combo are unchanged.
func bail() -> void:
	_reset()


func _repeat_count(id: String) -> int:
	var count: int = 0
	for entry: Dictionary in _tricks:
		var is_gap: bool = entry["gap"]
		var entry_id: String = entry["id"]
		if not is_gap and entry_id == id:
			count += 1
	return count


func _reset() -> void:
	_tricks.clear()
	_hold_accum = 0.0
