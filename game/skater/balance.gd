class_name Balance
extends RefCounted
## Balance meter for grinds, manuals and lip tricks. Pure logic: no Node, no clock, no randf().
## angle runs -1..1, 0 is centered. The board drifts away from center (unstable equilibrium),
## seeded random nudges shove it every 0.5 to 1.0 s, and the player's stick axis pushes it back.
## Reaching abs(angle) = 1.0 is a fall. Instability grows with time held and with difficulty.

const INSTABILITY: float = 3.2
const CONTROL: float = 6.0
const DAMPING: float = 0.4
const NUDGE_STRENGTH: float = 0.15
const NUDGE_MIN_INTERVAL: float = 0.5
const NUDGE_MAX_INTERVAL: float = 1.0
const START_OFFSET_MIN: float = 0.02
const START_OFFSET_MAX: float = 0.05
const TIME_GROWTH_SECONDS: float = 12.0
const FALL_ANGLE: float = 1.0

## Position on the meter, -1.0 (fell left) to 1.0 (fell right). 0.0 is centered.
var angle: float = 0.0
## Angular velocity per second.
var velocity: float = 0.0

var _time: float = 0.0
var _difficulty: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_nudge_at: float = 0.0
var _failed: bool = false


## Resets the meter to a small seeded offset from center. Same seed and inputs give the same angles.
func start(seed_value: int, difficulty: float = 1.0) -> void:
	_rng.seed = seed_value
	_difficulty = difficulty
	var offset: float = _rng.randf_range(START_OFFSET_MIN, START_OFFSET_MAX)
	var side: float = 1.0 if _rng.randf() < 0.5 else -1.0
	angle = offset * side
	velocity = 0.0
	_time = 0.0
	_failed = false
	_next_nudge_at = _rng.randf_range(NUDGE_MIN_INTERVAL, NUDGE_MAX_INTERVAL)


## Advances the meter by delta seconds. correction is the stick axis, -1..1, positive pushes angle toward +.
## Returns false once the skater has fallen (abs(angle) >= 1.0). Stays false after that.
func update(delta: float, correction: float) -> bool:
	if _failed:
		return false
	_time += delta
	var instability: float = INSTABILITY * _difficulty * (1.0 + _time / TIME_GROWTH_SECONDS)
	velocity += angle * instability * delta
	if _time >= _next_nudge_at:
		velocity += _rng.randf_range(-1.0, 1.0) * NUDGE_STRENGTH
		_next_nudge_at = _time + _rng.randf_range(NUDGE_MIN_INTERVAL, NUDGE_MAX_INTERVAL)
	velocity += clampf(correction, -1.0, 1.0) * CONTROL * delta
	velocity *= exp(-DAMPING * delta)
	angle += velocity * delta
	if absf(angle) >= FALL_ANGLE:
		angle = clampf(angle, -FALL_ANGLE, FALL_ANGLE)
		_failed = true
		return false
	return true


func is_failed() -> bool:
	return _failed


## Seconds since start(), including time spent balanced.
func time_held() -> float:
	return _time
