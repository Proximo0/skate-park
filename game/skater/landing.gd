class_name Landing
extends RefCounted
## Landing judgement from the board pose and velocity. Pure logic: no Node, no clock.
## Generous on purpose: "sketchy" is a soft landing, and only a board that is badly tilted or
## pointing across the direction of travel is a "bail".

const UPRIGHT_BAIL_DOT: float = 0.5
const UPRIGHT_CLEAN_DOT: float = 0.85
const SPEED_IGNORE_HEADING: float = 1.0
const HEADING_CLEAN_DEG: float = 50.0
const HEADING_SKETCHY_DEG: float = 80.0
const DEGENERATE_EPSILON: float = 0.0001

const RESULT_CLEAN: String = "clean"
const RESULT_SKETCHY: String = "sketchy"
const RESULT_BAIL: String = "bail"


## Judges a landing. board_forward and board_up are the board's local axes in world space,
## velocity is the skater's world velocity, ground_normal is the surface normal under the wheels.
## Returns {"result": "clean" | "sketchy" | "bail", "switch": bool}.
## switch is true when the skater is rolling backward (fakie or rolling switch).
static func judge(board_forward: Vector3, board_up: Vector3, velocity: Vector3, ground_normal: Vector3) -> Dictionary:
	var normal: Vector3 = ground_normal.normalized()
	var up_dot: float = board_up.normalized().dot(normal)
	if up_dot < UPRIGHT_BAIL_DOT:
		return _landing_judgement(RESULT_BAIL, false)
	var upright_clean: bool = up_dot >= UPRIGHT_CLEAN_DOT

	var flat_velocity: Vector3 = velocity - normal * velocity.dot(normal)
	var flat_forward: Vector3 = board_forward - normal * board_forward.dot(normal)
	var ignore_heading: bool = flat_velocity.length() < SPEED_IGNORE_HEADING \
			or flat_forward.length() < DEGENERATE_EPSILON
	if ignore_heading:
		var still_result: String = RESULT_CLEAN if upright_clean else RESULT_SKETCHY
		return _landing_judgement(still_result, false)

	var heading_deg: float = rad_to_deg(acos(clampf(
			flat_forward.normalized().dot(flat_velocity.normalized()), -1.0, 1.0)))
	var backward_side: bool = heading_deg >= 90.0
	var result: String = RESULT_BAIL
	if heading_deg <= HEADING_CLEAN_DEG or heading_deg >= 180.0 - HEADING_CLEAN_DEG:
		result = RESULT_CLEAN
	elif heading_deg <= HEADING_SKETCHY_DEG or heading_deg >= 180.0 - HEADING_SKETCHY_DEG:
		result = RESULT_SKETCHY

	if result == RESULT_BAIL:
		return _landing_judgement(RESULT_BAIL, false)
	if result == RESULT_CLEAN and not upright_clean:
		result = RESULT_SKETCHY
	return _landing_judgement(result, backward_side)


static func _landing_judgement(result: String, is_switch: bool) -> Dictionary:
	return {"result": result, "switch": is_switch}
