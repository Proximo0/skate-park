extends TestCase

const FORWARD: Vector3 = Vector3(0.0, 0.0, -1.0)
const UP: Vector3 = Vector3(0.0, 1.0, 0.0)
const SPEED: float = 5.0


## Horizontal velocity heading the given number of degrees away from FORWARD (0 = forward, 180 = backward).
func _heading_velocity(deg: float, speed: float = SPEED) -> Vector3:
	var a: float = deg_to_rad(deg)
	return Vector3(sin(a), 0.0, -cos(a)) * speed


## Board up vector whose dot with the flat ground (UP) equals upright_dot.
func _tilted_up(upright_dot: float) -> Vector3:
	var t: float = acos(upright_dot)
	return Vector3(sin(t), cos(t), 0.0)


func _judge(forward: Vector3, up: Vector3, vel: Vector3, normal: Vector3 = UP) -> Dictionary:
	return Landing.judge(forward, up, vel, normal)


func _assert_result(d: Dictionary, result: String, is_switch: bool, msg: String) -> void:
	assert_eq(d["result"], result, msg + " result")
	assert_eq(d["switch"], is_switch, msg + " switch")


func test_straight_forward_is_clean_not_switch() -> void:
	_assert_result(_judge(FORWARD, UP, _heading_velocity(0.0)), "clean", false, "forward")


func test_straight_backward_is_clean_switch() -> void:
	_assert_result(_judge(FORWARD, UP, _heading_velocity(180.0)), "clean", true, "backward")


func test_heading_within_35_forward_is_clean() -> void:
	_assert_result(_judge(FORWARD, UP, _heading_velocity(20.0)), "clean", false, "20 fwd")
	_assert_result(_judge(FORWARD, UP, _heading_velocity(34.9)), "clean", false, "34.9 fwd")


func test_heading_within_35_backward_is_clean_switch() -> void:
	_assert_result(_judge(FORWARD, UP, _heading_velocity(160.0)), "clean", true, "160 back")
	_assert_result(_judge(FORWARD, UP, _heading_velocity(145.5)), "clean", true, "145.5 back")


func test_heading_35_to_70_forward_is_sketchy_not_switch() -> void:
	_assert_result(_judge(FORWARD, UP, _heading_velocity(50.0)), "sketchy", false, "50 fwd")
	_assert_result(_judge(FORWARD, UP, _heading_velocity(60.0)), "sketchy", false, "60 fwd")


func test_heading_70_to_110_is_bail() -> void:
	_assert_result(_judge(FORWARD, UP, _heading_velocity(80.0)), "bail", false, "80")
	_assert_result(_judge(FORWARD, UP, _heading_velocity(90.0)), "bail", false, "90")
	_assert_result(_judge(FORWARD, UP, _heading_velocity(100.0)), "bail", false, "100")


func test_heading_110_to_145_is_sketchy_switch() -> void:
	_assert_result(_judge(FORWARD, UP, _heading_velocity(120.0)), "sketchy", true, "120 back")
	_assert_result(_judge(FORWARD, UP, _heading_velocity(110.0)), "sketchy", true, "110 back")


func test_sketchy_side_is_the_closer_side() -> void:
	# 85 degrees is nearer to forward (bail band), 95 nearer to backward (bail band); 65 and 115 pick a side.
	_assert_result(_judge(FORWARD, UP, _heading_velocity(65.0)), "sketchy", false, "65 closer fwd")
	_assert_result(_judge(FORWARD, UP, _heading_velocity(115.0)), "sketchy", true, "115 closer back")


func test_board_pointing_across_is_bail_even_when_upright() -> void:
	# Board points sideways while the skater moves forward: heading is 90 degrees off.
	var side_forward: Vector3 = Vector3(1.0, 0.0, 0.0)
	_assert_result(_judge(side_forward, UP, _heading_velocity(0.0)), "bail", false, "sideways board")


func test_tilt_below_half_is_bail() -> void:
	_assert_result(_judge(FORWARD, _tilted_up(0.4), _heading_velocity(0.0)), "bail", false, "dot 0.4")
	_assert_result(_judge(FORWARD, _tilted_up(0.0), _heading_velocity(0.0)), "bail", false, "dot 0")


func test_tilt_just_above_half_is_not_bail() -> void:
	var d: Dictionary = _judge(FORWARD, _tilted_up(0.51), _heading_velocity(0.0))
	assert_eq(d["result"], "sketchy", "dot 0.51 downgrades to sketchy")


func test_tilt_between_half_and_085_downgrades_clean_to_sketchy() -> void:
	_assert_result(_judge(FORWARD, _tilted_up(0.7), _heading_velocity(0.0)), "sketchy", false, "dot 0.7 fwd")
	_assert_result(_judge(FORWARD, _tilted_up(0.84), _heading_velocity(180.0)), "sketchy", true, "dot 0.84 back")


func test_tilt_at_085_stays_clean() -> void:
	_assert_result(_judge(FORWARD, _tilted_up(0.85), _heading_velocity(0.0)), "clean", false, "dot 0.85")


func test_tilt_downgrade_keeps_bail_and_sketchy_bands() -> void:
	# Upright downgrade only changes clean. A sketchy heading stays sketchy, a bail heading stays bail.
	_assert_result(_judge(FORWARD, _tilted_up(0.7), _heading_velocity(50.0)), "sketchy", false, "tilt sketchy")
	_assert_result(_judge(FORWARD, _tilted_up(0.7), _heading_velocity(90.0)), "bail", false, "tilt bail")


func test_slow_speed_ignores_heading_when_upright() -> void:
	_assert_result(_judge(FORWARD, UP, _heading_velocity(90.0, 0.5)), "clean", false, "slow sideways")
	_assert_result(_judge(FORWARD, UP, _heading_velocity(180.0, 0.5)), "clean", false, "slow backward")


func test_slow_speed_still_downgrades_on_tilt() -> void:
	_assert_result(_judge(FORWARD, _tilted_up(0.7), _heading_velocity(0.0, 0.2)), "sketchy", false, "slow tilted")


func test_slow_speed_still_bails_below_half() -> void:
	_assert_result(_judge(FORWARD, _tilted_up(0.3), Vector3.ZERO), "bail", false, "stopped tilted")


func test_standing_still_upright_is_clean() -> void:
	_assert_result(_judge(FORWARD, UP, Vector3.ZERO), "clean", false, "stopped upright")


func test_speed_exactly_one_uses_heading() -> void:
	# At 1 m/s and above, heading counts. A sideways 1 m/s roll is a bail.
	_assert_result(_judge(FORWARD, UP, _heading_velocity(90.0, 1.0)), "bail", false, "1 m/s sideways")


func test_vertical_velocity_is_ignored() -> void:
	# Falling or launching straight up should not change the horizontal heading.
	var vel: Vector3 = _heading_velocity(0.0) + Vector3(0.0, -8.0, 0.0)
	_assert_result(_judge(FORWARD, UP, vel), "clean", false, "vertical component")


func test_sloped_ground_uses_plane_projection() -> void:
	var normal: Vector3 = Vector3(1.0, 1.0, 0.0).normalized()
	# Board sits on the slope: up matches the normal. Velocity runs down the slope along forward.
	var vel: Vector3 = Vector3(0.0, 0.0, -SPEED)
	_assert_result(_judge(FORWARD, normal, vel, normal), "clean", false, "slope forward")


func test_sloped_ground_backward_switch() -> void:
	var normal: Vector3 = Vector3(1.0, 1.0, 0.0).normalized()
	var vel: Vector3 = Vector3(0.0, 0.0, SPEED)
	_assert_result(_judge(FORWARD, normal, vel, normal), "clean", true, "slope backward")


func test_unnormalized_inputs_are_accepted() -> void:
	var fwd: Vector3 = FORWARD * 3.0
	var up: Vector3 = UP * 2.0
	var vel: Vector3 = _heading_velocity(0.0) * 2.0
	var n: Vector3 = UP * 4.0
	_assert_result(_judge(fwd, up, vel, n), "clean", false, "unnormalized")


func test_switch_flag_matches_heading_side_for_sketchy_band() -> void:
	# Sweep through the sketchy bands and check switch always tracks the side.
	for deg: int in range(40, 71, 5):
		var d: Dictionary = _judge(FORWARD, UP, _heading_velocity(float(deg)))
		assert_eq(d["result"], "sketchy", "sweep fwd %d" % deg)
		assert_false(d["switch"], "sweep fwd %d not switch" % deg)
	for deg: int in range(110, 141, 5):
		var d: Dictionary = _judge(FORWARD, UP, _heading_velocity(float(deg)))
		assert_eq(d["result"], "sketchy", "sweep back %d" % deg)
		assert_true(d["switch"], "sweep back %d switch" % deg)
