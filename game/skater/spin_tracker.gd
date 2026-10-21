class_name SpinTracker
extends RefCounted
## Tracks total spin in a trick from the board yaw each frame. Pure logic: no Node, no clock.
## Each update adds the signed shortest-angle change, so wraparound at +/-180 degrees is handled.
## spins180 rounds to the nearest half turn with a 30 degree grace window, so a 150 degree spin counts as 180.

const GRACE_DEG: float = 30.0
const HALF_TURN_DEG: float = 180.0

var _last_yaw: float = 0.0
var _total_rad: float = 0.0


## Begins tracking from yaw (radians). Clears any accumulated spin.
func start(yaw: float) -> void:
	_last_yaw = yaw
	_total_rad = 0.0


## Adds the shortest signed change from the last yaw to this one (radians).
func update(yaw: float) -> void:
	var step: float = wrapf(yaw - _last_yaw, -PI, PI)
	_total_rad += step
	_last_yaw = yaw


## Signed total spin in degrees. Positive is counter-clockwise seen from above.
func degrees() -> float:
	return rad_to_deg(_total_rad)


## Number of half turns, counting the unsigned total. 0 for under 150 degrees, 1 for 150 to 329, and so on.
func spins180() -> int:
	return int(floor((absf(degrees()) + GRACE_DEG) / HALF_TURN_DEG))


## Trick name for the spin: "" for none, "180", "360", "540", ... by spins180 x 180.
func label() -> String:
	var n: int = spins180()
	if n == 0:
		return ""
	return str(n * 180)
