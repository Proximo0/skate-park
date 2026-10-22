extends TestCase


func _cam_vec_near(actual: Vector3, expected: Vector3, msg: String = "") -> void:
	assert_near(actual.x, expected.x, 0.001, "x " + msg)
	assert_near(actual.y, expected.y, 0.001, "y " + msg)
	assert_near(actual.z, expected.z, 0.001, "z " + msg)


func test_offset_flat_is_behind_and_above() -> void:
	# Facing -Z: the camera sits on the +Z side, 4.5 m back and 2 m up.
	_cam_vec_near(SkateCamera.desired_offset(Vector3(0, 0, -1), false), Vector3(0, SkateCamera.HEIGHT, SkateCamera.DISTANCE))


func test_offset_vert_is_higher_and_farther() -> void:
	_cam_vec_near(SkateCamera.desired_offset(Vector3(0, 0, -1), true), Vector3(0, SkateCamera.VERT_HEIGHT, SkateCamera.VERT_DISTANCE))


func test_offset_follows_facing_direction() -> void:
	# Facing +X: behind is -X.
	_cam_vec_near(SkateCamera.desired_offset(Vector3(1, 0, 0), false), Vector3(-SkateCamera.DISTANCE, SkateCamera.HEIGHT, 0))


func test_offset_ignores_facing_pitch() -> void:
	# A nose-down facing still puts the camera behind on the flat, at the same height.
	_cam_vec_near(SkateCamera.desired_offset(Vector3(0, -0.7, -0.7), false), Vector3(0, SkateCamera.HEIGHT, SkateCamera.DISTANCE))


func test_offset_zero_facing_falls_back_to_back() -> void:
	_cam_vec_near(SkateCamera.desired_offset(Vector3.ZERO, false), Vector3(0, SkateCamera.HEIGHT, SkateCamera.DISTANCE))


func test_yaw_round_trip() -> void:
	var f: Vector3 = Vector3(0.6, 0.0, -0.8)
	_cam_vec_near(SkateCamera.facing_from_yaw(SkateCamera.yaw_from_facing(f)), f)


func test_damp_zero_rate_keeps_current() -> void:
	assert_near(SkateCamera.damp(2.0, 10.0, 0.0, 1.0), 2.0)


func test_damp_zero_delta_keeps_current() -> void:
	assert_near(SkateCamera.damp(2.0, 10.0, 5.0, 0.0), 2.0)


func test_damp_one_time_constant() -> void:
	# After one time constant (1 / rate) the value has covered 1 - 1/e of the gap.
	assert_near(SkateCamera.damp(0.0, 1.0, 4.0, 0.25), 1.0 - exp(-1.0), 0.0001)


func test_damp_is_framerate_independent() -> void:
	var one_step: float = SkateCamera.damp(0.0, 1.0, 6.0, 1.0 / 30.0)
	var two_steps: float = SkateCamera.damp(SkateCamera.damp(0.0, 1.0, 6.0, 1.0 / 60.0), 1.0, 6.0, 1.0 / 60.0)
	assert_near(one_step, two_steps, 0.0001)


func test_damp_vec_matches_scalar() -> void:
	var v: Vector3 = SkateCamera.damp_vec(Vector3.ZERO, Vector3(4, -2, 1), 4.0, 0.25)
	assert_near(v.x, 4.0 * (1.0 - exp(-1.0)), 0.0001)
	assert_near(v.y, -2.0 * (1.0 - exp(-1.0)), 0.0001)


func test_damp_angle_takes_short_way_round() -> void:
	# From just under +PI toward just above -PI the short way is forward, across the wrap.
	var out: float = SkateCamera.damp_angle(3.1, -3.1, 1000.0, 1.0)
	assert_near(cos(out), cos(-3.1), 0.001)


func test_fov_base_at_rest() -> void:
	assert_near(SkateCamera.fov_for_speed(0.0), SkateCamera.FOV_BASE)
	assert_near(SkateCamera.fov_for_speed(SkateCamera.FOV_SPEED_LO), SkateCamera.FOV_BASE)


func test_fov_subtle_at_cruise_strong_at_top() -> void:
	var cruise: float = SkateCamera.fov_for_speed(10.0) - SkateCamera.FOV_BASE
	var top: float = SkateCamera.fov_for_speed(SkateCamera.FOV_SPEED_HI) - SkateCamera.FOV_BASE
	assert_near(SkateCamera.fov_for_speed(30.0), SkateCamera.FOV_FAST)
	assert_true(cruise > 0.0 and cruise < top * 0.3, "cruise push %.2f should be under 30%% of top push %.2f" % [cruise, top])


func test_speed_push_monotonic() -> void:
	assert_true(SkateCamera.speed_push(8.0) < SkateCamera.speed_push(14.0) and SkateCamera.speed_push(14.0) < SkateCamera.speed_push(22.0))


func test_ground_lift_raises_low_camera() -> void:
	_cam_vec_near(SkateCamera.ground_lift(Vector3(1, 0.1, 2), 0.0, 0.5), Vector3(1, 0.5, 2))


func test_ground_lift_keeps_high_camera() -> void:
	_cam_vec_near(SkateCamera.ground_lift(Vector3(1, 3.0, 2), 0.0, 0.5), Vector3(1, 3.0, 2))


func test_pulled_in_stops_short_of_wall() -> void:
	var out: Vector3 = SkateCamera.pulled_in(Vector3(0, 1, 0), Vector3(0, 1, 10), Vector3(0, 1, 4), 0.3)
	_cam_vec_near(out, Vector3(0, 1, 3.7))


func test_pulled_in_no_room_returns_look() -> void:
	var out: Vector3 = SkateCamera.pulled_in(Vector3(0, 1, 0), Vector3(0, 1, 10), Vector3(0, 1, 0.1), 0.3)
	_cam_vec_near(out, Vector3(0, 1, 0))


func test_look_target_is_above_skater() -> void:
	_cam_vec_near(SkateCamera.look_target(Vector3(2, 0, 3), Vector3.ZERO), Vector3(2, 0.9, 3))


func test_look_target_leads_velocity_clamped() -> void:
	# 20 m/s forward: 0.12 s lead is 2.4 m, clamped to 1.5 m.
	_cam_vec_near(SkateCamera.look_target(Vector3.ZERO, Vector3(0, 0, -20)), Vector3(0, 0.9, -1.5))


func test_look_target_ignores_vertical_velocity() -> void:
	_cam_vec_near(SkateCamera.look_target(Vector3.ZERO, Vector3(0, 9, 0)), Vector3(0, 0.9, 0))


func test_yaw_velocity_never_whips_on_a_half_turn() -> void:
	# A 140 degree swing (the camera after a vert re-entry): the yaw velocity stays under the cap and the turn takes
	# about a second, where the plain exponential follow peaked at 9.8 rad/s in 0.45 s.
	var yaw_left: float = deg_to_rad(140.0)
	var vel: float = 0.0
	var peak: float = 0.0
	var t: float = 0.0
	var t90: float = -1.0
	while t < 3.0:
		vel = SkateCamera.yaw_velocity_step(vel, yaw_left, SkateCamera.YAW_RATE, 1.0 / 60.0)
		yaw_left -= vel / 60.0
		peak = maxf(peak, absf(vel))
		t += 1.0 / 60.0
		if t90 < 0.0 and yaw_left < deg_to_rad(14.0):
			t90 = t
	assert_true(peak <= SkateCamera.YAW_MAX_RATE, "yaw velocity peak %.2f rad/s should stay under the %.1f cap" % [peak, SkateCamera.YAW_MAX_RATE])
	assert_true(t90 >= 0.75 and t90 <= 1.3, "a half turn should take about a second to 90%%, took %.2f s" % t90)
	assert_true(absf(yaw_left) < 0.02, "and settle on the heading, %.3f rad left" % yaw_left)


func test_yaw_velocity_small_turn_stays_responsive() -> void:
	var yaw_left: float = 0.3
	var vel: float = 0.0
	for i: int in 30:  # half a second
		vel = SkateCamera.yaw_velocity_step(vel, yaw_left, SkateCamera.YAW_RATE, 1.0 / 60.0)
		yaw_left -= vel / 60.0
	assert_true(yaw_left < 0.3 * 0.2, "a 17 degree correction is 80%% done in half a second, %.3f rad left" % yaw_left)


func test_yaw_velocity_does_not_overshoot() -> void:
	var yaw_left: float = 1.0
	var vel: float = 0.0
	for i: int in 240:
		vel = SkateCamera.yaw_velocity_step(vel, yaw_left, SkateCamera.YAW_RATE, 1.0 / 60.0)
		yaw_left -= vel / 60.0
		assert_true(yaw_left > -0.01, "critically damped: no overshoot (%.3f)" % yaw_left)


func test_arm_step_shortens_in_steps_and_eases_out() -> void:
	# A 2.2 m graze on a 5 m arm: the shown arm gives up at most ARM_SHRINK_MAX m a tick, not all of it at once.
	var shown: float = SkateCamera.arm_step(1.0, 0.56, 5.0, 1.0 / 60.0)
	assert_true((1.0 - shown) * 5.0 <= SkateCamera.ARM_SHRINK_MAX + 0.001, "shrank %.2f m in one tick" % ((1.0 - shown) * 5.0))
	assert_true(shown < 1.0, "but it does shorten")
	var s: float = 1.0
	for i: int in 30:
		s = SkateCamera.arm_step(s, 0.56, 5.0, 1.0 / 60.0)
	assert_near(s, 0.56, 0.01)
	var out: float = SkateCamera.arm_step(0.56, 1.0, 5.0, 1.0 / 60.0)
	assert_true(out > 0.56 and out < 0.6, "lengthening is eased, not instant (%.3f)" % out)


func test_impact_strength_none_for_small_landings() -> void:
	assert_eq(SkateCamera.impact_strength(0.0), 0.0)
	assert_eq(SkateCamera.impact_strength(3.0), 0.0)
	assert_true(SkateCamera.impact_strength(9.0) > 0.0 and SkateCamera.impact_strength(9.0) < 1.0)
	assert_eq(SkateCamera.impact_strength(20.0), 1.0)
	assert_true(SkateCamera.impact_strength(8.0) < SkateCamera.impact_strength(12.0), "monotonic")


func test_rider_fills_a_quarter_of_the_frame_at_speed() -> void:
	# THUG2 / Skate 3 framing: a 1.75 m rider is 25-30% of the frame height at a 12 m/s cruise.
	var lag: float = 12.0 / SkateCamera.POS_RATE * (1.0 - SkateCamera.POS_LEAD)  # the damped position trails the goal
	var dist: float = Vector3(0.0, SkateCamera.HEIGHT, SkateCamera.DISTANCE).length() + SkateCamera.PUSH_DISTANCE * SkateCamera.speed_push(12.0) + lag
	var frame_h: float = 2.0 * dist * tan(deg_to_rad(SkateCamera.fov_for_speed(12.0)) * 0.5)
	var share: float = 1.75 / frame_h
	assert_true(share >= 0.25 and share <= 0.34, "rider is %.0f%% of the frame height at 12 m/s" % (share * 100.0))


func test_camera_settings_scales() -> void:
	assert_eq(GameSettings.CAM_DISTANCE_SCALE[1], 1.0)
	assert_eq(GameSettings.CAM_FOV_OFFSET[1], 0.0)
	assert_true(GameSettings.CAM_DISTANCE_SCALE[0] < 1.0 and GameSettings.CAM_DISTANCE_SCALE[2] > 1.0)
	assert_true(GameSettings.CAM_FOV_OFFSET[0] < 0.0 and GameSettings.CAM_FOV_OFFSET[2] > 0.0)
