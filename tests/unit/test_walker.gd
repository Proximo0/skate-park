extends TestCase
## Walker maths: stick to speed, camera-relative direction, acceleration, turning, jump speed, stride length,
## the tuning fields, and the snapshot dictionary round trip.


func test_speed_for_stick_length() -> void:
	assert_near(Walker.speed_for(0.0, 1.6, 4.0), 0.0)
	assert_near(Walker.speed_for(0.1, 1.6, 4.0), 0.0, 0.0001, "dead zone")
	assert_near(Walker.speed_for(Walker.WALK_TILT, 1.6, 4.0), 1.6)
	assert_near(Walker.speed_for(1.0, 1.6, 4.0), 4.0)
	assert_near(Walker.speed_for(2.0, 1.6, 4.0), 4.0, 0.0001, "clamped to a full stick")
	assert_true(Walker.speed_for(0.8, 1.6, 4.0) > 1.6 and Walker.speed_for(0.8, 1.6, 4.0) < 4.0)


func test_move_dir_is_camera_relative() -> void:
	var up: Vector3 = Walker.move_dir(Vector2(0.0, -1.0), 0.0)
	assert_near(up.z, -1.0)
	assert_near(up.x, 0.0)
	var right: Vector3 = Walker.move_dir(Vector2(1.0, 0.0), 0.0)
	assert_near(right.x, 1.0)
	# camera turned a quarter turn left (yaw +90 degrees, looking down -X): stick up walks -X, stick right walks -Z
	var yaw: float = PI * 0.5
	var fwd: Vector3 = Walker.move_dir(Vector2(0.0, -1.0), yaw)
	assert_near(fwd.x, -1.0)
	var rt: Vector3 = Walker.move_dir(Vector2(1.0, 0.0), yaw)
	assert_near(rt.z, -1.0)
	var diag: Vector3 = Walker.move_dir(Vector2(1.0, -1.0), 0.0)
	assert_near(diag.length(), 1.0, 0.0001, "diagonals are not faster")
	assert_eq(Walker.move_dir(Vector2.ZERO, 1.0), Vector3.ZERO)


func test_yaw_from_forward() -> void:
	assert_near(Walker.yaw_from_forward(Vector3(0, 0, -1), 5.0), 0.0)
	assert_near(Walker.yaw_from_forward(Vector3(-1, 0, 0), 5.0), PI * 0.5)
	assert_near(Walker.yaw_from_forward(Vector3(0, -1, 0), 5.0), 5.0, 0.0001, "looking straight down keeps the fallback")


func test_approach_reaches_target_in_about_015s_and_decel_is_gentler() -> void:
	var t: Vector3 = Vector3(0.0, 0.0, -4.0)
	var v: Vector3 = Vector3.ZERO
	var steps: int = 0
	while v.distance_to(t) > 0.001 and steps < 100:
		v = Walker.approach(v, t, 27.0, 0.0, 1.0 / 60.0)
		steps += 1
	assert_true(steps >= 8 and steps <= 10, "run speed in ~0.15 s (%d ticks)" % steps)
	var fast: Vector3 = Vector3(0.0, 0.0, -6.0)
	var slow: Vector3 = Walker.approach(fast, Vector3.ZERO, 27.0, 12.0, 1.0)
	assert_near(slow.length(), 0.0)
	var one: Vector3 = Walker.approach(fast, Vector3.ZERO, 27.0, 12.0, 0.1)
	assert_near(one.length(), 4.8, 0.001, "carried speed sheds at the gentler decel")


func test_turn_toward_dir_converges_without_overshoot() -> void:
	var cur: Vector3 = Vector3(0.0, 0.0, -1.0)
	var want: Vector3 = Vector3(1.0, 0.0, 0.0)
	var prev: float = absf(cur.signed_angle_to(want, Vector3.UP))
	for i: int in 30:
		cur = Walker.turn_toward_dir(cur, want, Walker.TURN_RATE, 1.0 / 60.0)
		var a: float = absf(cur.signed_angle_to(want, Vector3.UP))
		assert_true(a <= prev + 0.00001, "angle never grows")
		prev = a
	assert_true(prev < 0.2, "mostly turned after 0.5 s")
	assert_eq(Walker.turn_toward_dir(cur, Vector3.ZERO, 14.0, 0.1), cur, "no input keeps the heading")


func test_jump_speed_reaches_height() -> void:
	var v: float = Walker.jump_speed(0.6, 18.0)
	assert_near(v * v / (2.0 * 18.0), 0.6, 0.0001)
	assert_near(Walker.jump_speed(0.0, 18.0), 0.0)


func test_stride_gets_longer_with_speed() -> void:
	assert_true(Walker.cycle_length(4.0) > Walker.cycle_length(1.6))


func test_walk_tuning_fields() -> void:
	var t: PhysicsTuning = PhysicsTuning.new()
	assert_near(t.walk_speed, 1.6)
	assert_near(t.run_speed, 4.0)
	assert_near(t.walk_jump, 0.6)
	assert_true(t.walk_accel > 0.0)
	assert_eq(PhysicsTuning.field_info("walk_speed")["group"], "Walk")
	assert_eq(PhysicsTuning.field_info("run_speed")["group"], "Walk")


func test_begin_and_dict_round_trip() -> void:
	var w: Walker = Walker.new()
	w.begin(Vector3(1.0, 2.0, 0.0), 6.0)
	assert_near(w.facing.x, 1.0)
	assert_near(w.facing.y, 0.0)
	assert_true(w.carry_decel >= Walker.MIN_CARRY_DECEL, "speed carried off the board is shed gently")
	w.phase = 0.37
	w.step_time = 1.5
	var d: Dictionary = str_to_var(var_to_str(w.to_dict())) as Dictionary
	var o: Walker = Walker.new()
	o.from_dict(d)
	assert_eq(o.to_dict(), w.to_dict())
	var still: Walker = Walker.new()
	still.begin(Vector3.ZERO, 0.0)
	assert_near(still.carry_decel, 0.0)


# --- poser: walking anims ---------------------------------------------------------------------------------------

func test_walk_poses_stand_on_the_ground_and_carry_the_board() -> void:
	for a: String in ["walk", "walk_jump", "dismount", "mount"]:
		var pose: Dictionary = SkaterPoser.pose_for(a, 0.1, 0.0, 0.0, false, 1.6, 0.3)
		for j: String in SkaterPoser.JOINTS:
			assert_true(pose.has(j), "%s has joint %s" % [a, j])
		for k: String in ["foot_L", "foot_R", "hand_R", "board_pos", "board_rot"]:
			assert_true(pose.has(k), "%s has %s" % [a, k])
	var walk: Dictionary = SkaterPoser.pose_for("walk", 0.0, 0.0, 0.0, false, 1.6, 0.3)
	assert_near(float(walk["grip_R"]), 1.0, 0.0001, "carrying hand grips the deck")
	var rot: Vector3 = walk["board_rot"]
	assert_near(rot.z, SkaterPoser.CARRY_ROLL, 0.001, "board on edge")
	var hand: Vector3 = walk["hand_R"]
	var pos: Vector3 = walk["board_pos"]
	assert_true(hand.distance_to(pos) < 0.4, "the hand is on the board")
	assert_true(hand.x > 0.15 and hand.y > 0.4 and hand.y < 0.8, "hand at the hip, right side")
	# both ankles at ground level when stood still, one lifted mid-swing
	var idle: Dictionary = SkaterPoser.pose_for("walk", 0.0, 0.0, 0.0, false, 0.0, 0.0)
	assert_near((idle["foot_L"] as Vector3).y, PlaceholderSkater.ANKLE_HEIGHT, 0.0001)
	assert_near((idle["foot_R"] as Vector3).y, PlaceholderSkater.ANKLE_HEIGHT, 0.0001)
	var lowest: float = 10.0
	var highest: float = 0.0
	for i: int in 40:
		var p: Dictionary = SkaterPoser.pose_for("walk", 0.0, 0.0, 0.0, false, 1.6, float(i) / 40.0)
		for f: String in ["foot_L", "foot_R"]:
			var y: float = (p[f] as Vector3).y
			lowest = minf(lowest, y)
			highest = maxf(highest, y)
	assert_near(lowest, PlaceholderSkater.ANKLE_HEIGHT, 0.0001, "feet never sink below the ground")
	assert_true(highest > PlaceholderSkater.ANKLE_HEIGHT + 0.03, "the swinging foot lifts")


func test_stride_scales_with_speed_and_feet_alternate() -> void:
	var slow: float = 0.0
	var fast: float = 0.0
	for i: int in 40:
		var ph: float = float(i) / 40.0
		slow = maxf(slow, absf((SkaterPoser.pose_for("walk", 0.0, 0.0, 0.0, false, 1.6, ph)["foot_L"] as Vector3).z))
		fast = maxf(fast, absf((SkaterPoser.pose_for("walk", 0.0, 0.0, 0.0, false, 4.0, ph)["foot_L"] as Vector3).z))
	assert_true(fast > slow, "a run strides further than a walk")
	var a: Dictionary = SkaterPoser.pose_for("walk", 0.0, 0.0, 0.0, false, 1.6, 0.1)
	var b: Dictionary = SkaterPoser.pose_for("walk", 0.0, 0.0, 0.0, false, 1.6, 0.6)
	assert_near((a["foot_L"] as Vector3).z, (b["foot_R"] as Vector3).z, 0.0001, "feet half a cycle apart")


func test_dismount_ends_in_the_carry_pose() -> void:
	var end: Dictionary = SkaterPoser.pose_for("dismount", SkaterPoser.STEP_OFF_TIME, 0.0, 0.0, false, 0.0, 0.0)
	var walk: Dictionary = SkaterPoser.pose_for("walk", 0.0, 0.0, 0.0, false, 0.0, 0.0)
	assert_near((end["board_pos"] as Vector3).distance_to(walk["board_pos"] as Vector3), 0.0, 0.001)
	assert_near(float(end["body_yaw"]), float(walk["body_yaw"]), 0.01)
	var begin: Dictionary = SkaterPoser.pose_for("dismount", 0.0, 0.0, 0.0)
	assert_near(float(begin["feet_on_board"]), 1.0, 0.001, "starts on the deck")
	var mount_end: Dictionary = SkaterPoser.pose_for("mount", SkaterPoser.HOP_ON_TIME, 0.0, 0.0)
	assert_near((mount_end["board_pos"] as Vector3).length(), 0.0, 0.01, "board ends under the feet")
