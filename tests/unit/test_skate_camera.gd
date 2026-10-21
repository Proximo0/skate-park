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
