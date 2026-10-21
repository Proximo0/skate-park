extends TestCase
## SkaterPoser.pose_for: every anim gives a full pose, flips return the board to identity, crouch bends the knees.

const BRIEF_ANIMS: PackedStringArray = [
	"idle_ride", "push", "crouch", "ollie", "air", "land", "revert", "bail_fall", "bail_getup", "wallride",
	"manual_manual", "manual_nose_manual",
]


func _has_full_pose(pose: Dictionary) -> bool:
	for j: String in SkaterPoser.JOINTS:
		if not pose.has(j) or typeof(pose[j]) != TYPE_VECTOR3:
			return false
	for k: String in ["hips_y", "lift", "lean", "pitch", "body_yaw"]:
		if not pose.has(k) or typeof(pose[k]) != TYPE_FLOAT:
			return false
	for k: String in ["board_rot", "board_pos"]:
		if not pose.has(k) or typeof(pose[k]) != TYPE_VECTOR3:
			return false
	return true


func _trick_anims() -> Array[String]:
	var file: FileAccess = FileAccess.open("res://data/tricks.json", FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	var out: Array[String] = []
	for trick: Dictionary in data["tricks"]:
		out.append(str(trick["anim"]))
	return out


func test_every_brief_anim_has_full_pose() -> void:
	for a: String in BRIEF_ANIMS:
		var pose: Dictionary = SkaterPoser.pose_for(a, 0.3, 0.0, 0.0)
		assert_true(_has_full_pose(pose), "full pose for " + a)
	for a: String in ["flip_kickflip", "grab_melon", "grind_fifty_fifty", "lip_nose_stall", "special_rocket_launch"]:
		assert_true(_has_full_pose(SkaterPoser.pose_for(a, 0.3, 0.0, 0.0)), "full pose for " + a)


func test_every_trick_anim_has_full_pose() -> void:
	var anims: Array[String] = _trick_anims()
	assert_true(anims.size() >= 40, "tricks.json loaded (%d anims)" % anims.size())
	for a: String in anims:
		for t: float in [0.0, 0.2, 0.7]:
			assert_true(_has_full_pose(SkaterPoser.pose_for(a, t, 0.5, -0.4)), "full pose for %s at %f" % [a, t])


func test_unknown_anim_falls_back_to_idle() -> void:
	var idle: Dictionary = SkaterPoser.pose_for("idle_ride", 0.0, 0.0, 0.0)
	var odd: Dictionary = SkaterPoser.pose_for("no_such_anim", 0.0, 0.0, 0.0)
	assert_eq(odd["LeftUpperLeg"], idle["LeftUpperLeg"], "unknown anim uses idle legs")


func test_flip_board_identity_at_start() -> void:
	for a: String in _trick_anims():
		if not a.begins_with("flip_"):
			continue
		var rot: Vector3 = SkaterPoser.pose_for(a, 0.0, 0.0, 0.0)["board_rot"]
		assert_true(rot.is_zero_approx(), a + " board identity at t=0")


func test_flip_board_identity_at_end() -> void:
	for a: String in _trick_anims():
		if not a.begins_with("flip_"):
			continue
		var dur: float = SkaterPoser.DOUBLE_FLIP_TIME if a.contains("double") else SkaterPoser.FLIP_TIME
		var rot: Vector3 = SkaterPoser.pose_for(a, dur, 0.0, 0.0)["board_rot"]
		assert_true(rot.is_zero_approx(), a + " board identity at the end")
		var past: Vector3 = SkaterPoser.pose_for(a, dur + 1.0, 0.0, 0.0)["board_rot"]
		assert_true(past.is_zero_approx(), a + " board identity after the end")


func test_kickflip_rolls_about_z_over_042s() -> void:
	var half: Vector3 = SkaterPoser.pose_for("flip_kickflip", 0.21, 0.0, 0.0)["board_rot"]
	assert_near(half.z, 180.0, 0.01, "half way is 180 about Z")
	assert_near(half.x, 0.0, 0.01, "no X")
	assert_near(half.y, 0.0, 0.01, "no Y")


func test_double_kickflip_is_720_over_068s() -> void:
	var half: Vector3 = SkaterPoser.pose_for("flip_double_kickflip", 0.34, 0.0, 0.0)["board_rot"]
	assert_near(absf(half.z), 0.0, 0.01, "360 at half way wraps to identity, not 720 degrees of drift")
	var quarter: Vector3 = SkaterPoser.pose_for("flip_double_kickflip", 0.17, 0.0, 0.0)["board_rot"]
	assert_near(quarter.z, 180.0, 0.01, "quarter way is 180 about Z for a double")


func test_shove_turns_about_y_and_impossible_about_x() -> void:
	var shove: Vector3 = SkaterPoser.pose_for("flip_pop_shove_it", 0.21, 0.0, 0.0)["board_rot"]
	assert_near(shove.y, 180.0, 0.01, "shove-it turns about Y")
	var imp: Vector3 = SkaterPoser.pose_for("flip_impossible", 0.21, 0.0, 0.0)["board_rot"]
	assert_near(imp.x, 180.0, 0.01, "impossible turns about X")


func test_crouch_increases_knee_bend() -> void:
	for a: String in ["idle_ride", "crouch", "push"]:
		var up: Dictionary = SkaterPoser.pose_for(a, 0.1, 0.0, 0.0)
		var down: Dictionary = SkaterPoser.pose_for(a, 0.1, 1.0, 0.0)
		var bend_up: float = (up["LeftLowerLeg"] as Vector3).x
		var bend_down: float = (down["LeftLowerLeg"] as Vector3).x
		assert_true(bend_down < bend_up - 30.0, a + " crouch flexes the shin more")
		assert_true(float(down["hips_y"]) < float(up["hips_y"]) - 0.05, a + " crouch lowers the hips")


func test_bail_fall_tips_body_and_keeps_board_flat() -> void:
	var pose: Dictionary = SkaterPoser.pose_for("bail_fall", SkateState.BAIL_TIME, 0.0, 0.0)
	assert_near(float(pose["lean"]), 80.0, 0.01, "body rolls 80")
	assert_true((pose["board_rot"] as Vector3).is_zero_approx(), "board stays flat")


func test_grind_leans_with_balance() -> void:
	var right: Dictionary = SkaterPoser.pose_for("grind_fifty_fifty", 0.5, 0.0, 1.0)
	var left: Dictionary = SkaterPoser.pose_for("grind_fifty_fifty", 0.5, 0.0, -1.0)
	assert_near(float(right["lean"]), SkaterPoser.LEAN_MAX, 0.01, "full balance leans 25")
	assert_near(float(left["lean"]), -SkaterPoser.LEAN_MAX, 0.01, "other side leans -25")


func test_boardslide_turns_body_and_board() -> void:
	var pose: Dictionary = SkaterPoser.pose_for("grind_boardslide", 0.5, 0.0, 0.0)
	assert_near(float(pose["body_yaw"]), -90.0, 0.01, "body turned 90 against the board")
	assert_near((pose["board_rot"] as Vector3).y, 90.0, 0.01, "board yawed 90")


func test_manual_pitches_board_nose_up_and_nose_manual_down() -> void:
	var m: Vector3 = SkaterPoser.pose_for("manual_manual", 0.5, 0.0, 0.0)["board_rot"]
	var nm: Vector3 = SkaterPoser.pose_for("manual_nose_manual", 0.5, 0.0, 0.0)["board_rot"]
	assert_near(m.x, 12.0, 0.01, "manual nose up 12")
	assert_near(nm.x, -12.0, 0.01, "nose manual nose down 12")


func test_revert_yaws_180_over_03s() -> void:
	var end: Dictionary = SkaterPoser.pose_for("revert", SkaterPoser.REVERT_TIME, 0.0, 0.0)
	assert_near(float(end["body_yaw"]), 180.0, 0.01, "body yaw 180 at the end of the spin")
	assert_near((end["board_rot"] as Vector3).y, 180.0, 0.01, "board yaw 180")
	var start: Dictionary = SkaterPoser.pose_for("revert", 0.0, 0.0, 0.0)
	assert_near(float(start["body_yaw"]), 0.0, 0.01, "no yaw at the start")


func test_special_spins_two_turns_and_ends_at_identity() -> void:
	var mid: Vector3 = SkaterPoser.pose_for("special_pizza_spinner", 0.5, 0.0, 0.0)["board_rot"]
	assert_near(mid.y, 180.0, 0.01, "quarter of the spin after 0.5 of 2 s is 180 yaw")
	var end: Vector3 = SkaterPoser.pose_for("special_pizza_spinner", SkaterPoser.SPECIAL_SPIN_TIME, 0.0, 0.0)["board_rot"]
	assert_true(end.is_zero_approx(), "two turns end at identity")


func test_idle_hips_only_dip_slightly_when_grounded() -> void:
	# Ground anims solve hip height from the leg offsets, so a relaxed stance barely moves the hips.
	var idle: Dictionary = SkaterPoser.pose_for("idle_ride", 0.0, 0.0, 0.0)
	assert_true(absf(float(idle["hips_y"])) < 0.05, "relaxed hips within 5 cm of rest")
	assert_near(float(idle["lift"]), 0.0, 0.0001, "no deck lift on flat board")
