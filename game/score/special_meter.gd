class_name SpecialMeter
extends RefCounted
## THUG2-style special meter. Pure logic: no Node, no clock.
## Points fill the meter. It drains only outside a combo and only while not special.
## Once full it latches special: no drain until bail(). use_special() keeps it special (THUG2 does not empty it).

signal became_special

const FILL_POINTS: float = 3000.0
const DRAIN_PER_SEC: float = 0.03

## Fill level, 0.0 to 1.0.
var value: float = 0.0

var _special: bool = false


## Adds score points to the meter. Fills by points / FILL_POINTS and caps at 1.0.
func add_points(points: int) -> void:
	if points <= 0:
		return
	value = minf(1.0, value + float(points) / FILL_POINTS)
	if value >= 1.0 and not _special:
		_special = true
		became_special.emit()


## Advances the meter by delta seconds. Drains only when not in a combo and not special.
func tick(delta: float, in_combo: bool) -> void:
	if in_combo or _special:
		return
	value = maxf(0.0, value - DRAIN_PER_SEC * delta)


## Ends special mode and empties the meter.
func bail() -> void:
	value = 0.0
	_special = false


func is_special() -> bool:
	return _special


## Spends a special. THUG2 keeps the meter full, so this stays special.
func use_special() -> void:
	pass
