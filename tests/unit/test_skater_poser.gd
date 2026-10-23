extends TestCase
## SkaterPoser.pose_for: every anim gives a full pose, feet land on the deck, flips spin the right way and are
## caught, the push foot reaches the ground, grabs put a hand target on the board, revert and switch stance.

const BRIEF_ANIMS: PackedStringArray = [
	"idle_ride", "push", "crouch", "ollie", "air", "land", "revert", "bail_fall", "bail_getup", "wallride",
	"manual_manual", "manual_nose_manual", "wallplant", "boneless", "no_comply", "caveman", "acid_drop",
]
const MOVE_ANIMS: PackedStringArray = ["wallplant", "boneless", "no_comply", "caveman", "acid_drop"]
const ANKLE_ON_DECK: float = PlaceholderSkater.DECK_TOP_Y + PlaceholderSkater.ANKLE_HEIGHT


func _has_full_pose(pose: Dictionary) -> bool:
	for j: String in SkaterPoser.JOINTS:
		if not pose.has(j) or typeof(pose[j]) != TYPE_VECTOR3:
			return false
	for k: String in ["hips_y", "lift", "lean", "pitch", "body_yaw", "feet_yaw", "feet_on_board", "feet_free",
			"grip_L", "grip_R", "toe_L", "toe_R"]:
		if not pose.has(k) or typeof(pose[k]) != TYPE_FLOAT:
			return false
	for k: String in ["board_rot", "board_pos", "foot_L", "foot_R", "hand_L", "hand_R"]:
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


func _rot(anim: String, t: float) -> Vector3:
	return SkaterPoser.pose_for(anim, t, 0.0, 0.0)["board_rot"]


func test_every_brief_anim_has_full_pose() -> void:
	for a: String in BRIEF_ANIMS:
		assert_true(_has_full_pose(SkaterPoser.pose_for(a, 0.3, 0.0, 0.0)), "full pose for " + a)
		assert_true(_has_full_pose(SkaterPoser.pose_for(a, 0.3, 0.0, 0.0, true)), "full switch pose for " + a)


func test_every_trick_anim_has_full_pose() -> void:
	var anims: Array[String] = _trick_anims()
	assert_true(anims.size() >= 40, "tricks.json loaded (%d anims)" % anims.size())
	for a: String in anims:
		for t: float in [0.0, 0.2, 0.7]:
			assert_true(_has_full_pose(SkaterPoser.pose_for(a, t, 0.5, -0.4)), "full pose for %s at %f" % [a, t])


func test_idle_feet_stand_on_the_deck_over_the_bolts() -> void:
	var idle: Dictionary = SkaterPoser.pose_for("idle_ride", 0.0, 0.0, 0.0)
	var front: Vector3 = idle["foot_L"]
	var back: Vector3 = idle["foot_R"]
	assert_near(front.y, ANKLE_ON_DECK, 0.0001, "front ankle on the deck")
	assert_near(back.y, ANKLE_ON_DECK, 0.0001, "back ankle on the deck")
	assert_true(front.z < -0.1 and back.z > 0.1, "feet spread along the board, front foot toward the nose")
	assert_near(front.x, 0.0, 0.0001, "feet centred across the board")


func test_switch_puts_the_left_foot_toward_the_tail() -> void:
	var sw: Dictionary = SkaterPoser.pose_for("idle_ride", 0.0, 0.0, 0.0, true)
	assert_true((sw["foot_L"] as Vector3).z > 0.1, "switch: left foot at the tail end")
	assert_near(float(sw["body_yaw"]), 180.0, 0.001, "switch faces the other side")


func test_unknown_anim_falls_back_to_idle() -> void:
	var idle: Dictionary = SkaterPoser.pose_for("idle_ride", 0.0, 0.0, 0.0)
	var odd: Dictionary = SkaterPoser.pose_for("no_such_anim", 0.0, 0.0, 0.0)
	assert_eq(odd["foot_L"], idle["foot_L"], "unknown anim uses the idle stance")
	assert_eq(odd["hips_y"], idle["hips_y"], "unknown anim uses idle hips")


func test_crouch_lowers_the_hips() -> void:
	for a: String in ["idle_ride", "crouch"]:
		var up: float = SkaterPoser.pose_for(a, 0.1, 0.0, 0.0)["hips_y"]
		var down: float = SkaterPoser.pose_for(a, 0.1, 1.0, 0.0)["hips_y"]
		assert_true(down < up - 0.1, a + " crouch drops the hips")


func test_flip_board_identity_at_start_and_end() -> void:
	for a: String in _trick_anims():
		if not a.begins_with("flip_"):
			continue
		var dur: float = SkaterPoser.DOUBLE_FLIP_TIME if a.contains("double") else SkaterPoser.FLIP_TIME
		var start: Vector3 = _rot(a, 0.0)
		var end: Vector3 = _rot(a, dur)
		var past: Vector3 = _rot(a, dur + 1.0)
		# A half shove ends turned 180 about Y; the board is symmetric, and the poser snaps that half turn.
		assert_true(start.is_zero_approx(), a + " board identity at t=0")
		assert_true(Vector3(end.x, fposmod(end.y, 180.0), end.z).is_zero_approx(), a + " board caught flat at the end")
		assert_eq(past, end, a + " board holds after the end")


func test_kickflip_and_heelflip_roll_opposite_ways() -> void:
	var kf: Vector3 = _rot("flip_kickflip", 0.1)
	var hf: Vector3 = _rot("flip_heelflip", 0.1)
	assert_true(kf.z > 30.0, "kickflip rolls + about the long axis")
	assert_true(hf.z < -30.0, "heelflip rolls - about the long axis")
	assert_near(kf.x, 0.0, 0.001, "no wrap")
	assert_near(kf.y, 0.0, 0.001, "no shove")


func test_shove_it_is_a_half_turn_and_varial_adds_a_flip() -> void:
	var dur: float = SkaterPoser.FLIP_TIME
	assert_near(absf(_rot("flip_pop_shove_it", dur).y), 180.0, 0.01, "shove-it ends a half turn round")
	assert_near(_rot("flip_pop_shove_it", dur * 0.5).z, 0.0, 0.001, "shove-it does not flip")
	var v: Vector3 = _rot("flip_varial_kickflip", dur * 0.5)
	assert_true(absf(v.y) > 30.0 and absf(v.z) > 30.0, "varial kickflip both shoves and flips")
	assert_true(absf(_rot("flip_impossible", dur * 0.5).x) > 30.0, "impossible wraps end over end")


func test_flip_feet_leave_the_deck_and_come_back() -> void:
	var mid: Dictionary = SkaterPoser.pose_for("flip_kickflip", SkaterPoser.FLIP_TIME * 0.4, 0.0, 0.0)
	var end: Dictionary = SkaterPoser.pose_for("flip_kickflip", SkaterPoser.FLIP_TIME, 0.0, 0.0)
	assert_near(float(mid["feet_on_board"]), 0.0, 0.001, "feet off the deck mid flip")
	var kick: Dictionary = SkaterPoser.pose_for("flip_kickflip", SkaterPoser.FLIP_TIME * 0.2, 0.0, 0.0)
	assert_true((kick["foot_L"] as Vector3).x > 0.08, "front foot kicked out toward the toe side")
	assert_near(float(end["feet_on_board"]), 1.0, 0.001, "caught: shoes back flat on the deck")
	var on_deck: Vector3 = SkaterPoser.deck_point(end, SkaterPoser.BACK_FOOT + Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0))
	assert_true((end["foot_R"] as Vector3).distance_to(on_deck) < 0.01, "caught: back foot on the deck")


func test_ollie_pops_the_tail() -> void:
	var pop: Vector3 = _rot("ollie", SkaterPoser.POP_TIME)
	assert_true(pop.x > 15.0, "nose up at the pop")
	var level: Dictionary = SkaterPoser.pose_for("ollie", SkaterPoser.LEVEL_TIME + 0.05, 0.0, 0.0)
	assert_near((level["board_rot"] as Vector3).x, 0.0, 0.01, "board levels out")
	assert_true((level["board_pos"] as Vector3).y > 0.15, "board rises into the tucked feet")


func test_push_foot_sweeps_along_the_ground_behind() -> void:
	var t0: float = SkaterPoser.PUSH_PLANT + SkaterPoser.PUSH_CYCLE * 0.05
	var t1: float = SkaterPoser.PUSH_PLANT + SkaterPoser.PUSH_CYCLE * 0.35  ## mid drive, before the toe-off
	var a: Vector3 = SkaterPoser.pose_for("push", t0, 0.0, 0.0)["foot_R"]
	var b: Vector3 = SkaterPoser.pose_for("push", t1, 0.0, 0.0)["foot_R"]
	assert_near(a.y, PlaceholderSkater.ANKLE_HEIGHT, 0.001, "push foot planted on the ground")
	assert_near(b.y, PlaceholderSkater.ANKLE_HEIGHT, 0.001, "still on the ground mid sweep")
	assert_true(b.z > a.z + 0.2, "foot sweeps back toward the tail")
	assert_true(a.x > 0.15, "push foot beside the board on the toe side")
	var front: Vector3 = SkaterPoser.pose_for("push", t1, 0.0, 0.0)["foot_L"]
	assert_near(front.y, ANKLE_ON_DECK, 0.0001, "front foot stays on the deck")


func test_grabs_put_a_hand_on_the_board() -> void:
	for a: String in ["grab_melon", "grab_indy", "grab_nosegrab", "grab_tailgrab", "grab_method", "grab_mute"]:
		var pose: Dictionary = SkaterPoser.pose_for(a, 0.5, 0.0, 0.0)
		var grip: float = maxf(float(pose["grip_L"]), float(pose["grip_R"]))
		assert_near(grip, 1.0, 0.001, a + " one hand gripping")
		assert_true((pose["board_pos"] as Vector3).y > 0.3, a + " board pulled up")
	var melon: Dictionary = SkaterPoser.pose_for("grab_melon", 0.5, 0.0, 0.0)
	var indy: Dictionary = SkaterPoser.pose_for("grab_indy", 0.5, 0.0, 0.0)
	assert_true(float(melon["grip_L"]) > 0.5, "melon: front hand")
	assert_true(float(indy["grip_R"]) > 0.5, "indy: back hand")
	assert_true((melon["hand_L"] as Vector3).x < 0.0, "melon on the heel edge")
	assert_true((indy["hand_R"] as Vector3).x > 0.0, "indy on the toe edge")


func test_grind_poses_differ() -> void:
	var seen: Dictionary = {}
	for a: String in ["grind_fifty_fifty", "grind_five_oh", "grind_nosegrind", "grind_crooked_grind",
			"grind_smith_grind", "grind_feeble_grind", "grind_boardslide", "grind_blunt_slide"]:
		seen[str(_rot(a, 0.3))] = a
	assert_eq(seen.size(), 8, "each grind tilts the board its own way")


func test_boardslide_turns_body_and_board_across() -> void:
	var p: Dictionary = SkaterPoser.pose_for("grind_boardslide", 0.3, 0.6, 0.0)
	assert_near((p["board_rot"] as Vector3).y, 90.0, 0.01, "board across the rail")
	assert_near(float(p["body_yaw"]), 90.0, 0.01, "body faces down the rail")
	assert_near((p["foot_L"] as Vector3).y, ANKLE_ON_DECK, 0.0001, "feet still on the deck")


func test_manual_tips_the_board_about_the_wheels() -> void:
	assert_near(_rot("manual_manual", 0.5).x, SkaterPoser.MANUAL_PITCH, 0.01, "manual nose up")
	assert_near(_rot("manual_nose_manual", 0.5).x, -SkaterPoser.MANUAL_PITCH, 0.01, "nose manual nose down")


func test_revert_turns_rider_and_board_together() -> void:
	var start: Dictionary = SkaterPoser.pose_for("revert", 0.0, 0.0, 0.0, true)
	var end: Dictionary = SkaterPoser.pose_for("revert", SkaterPoser.REVERT_TIME, 0.0, 0.0, true)
	assert_near(fposmod(float(start["body_yaw"]), 360.0), 0.0, 0.01, "starts in the old (regular) stance")
	assert_near(fposmod(float(end["body_yaw"]), 360.0), 180.0, 0.01, "ends switch")
	assert_near((end["board_rot"] as Vector3).y, 0.0, 0.01, "symmetric board ends square")
	for p: Dictionary in [start, end]:
		assert_near((p["foot_L"] as Vector3).y, ANKLE_ON_DECK, 0.0001, "feet on the deck through the revert")


func test_stance_yaw() -> void:
	assert_near(SkaterPoser.stance_yaw("idle_ride", false), 0.0, 0.001, "regular")
	assert_near(SkaterPoser.stance_yaw("idle_ride", true), 180.0, 0.001, "switch")
	assert_near(SkaterPoser.stance_yaw("revert", true), 0.0, 0.001, "revert into switch starts regular")


func test_special_spins_two_turns_and_ends_at_identity() -> void:
	var quarter: Vector3 = _rot("special_pizza_spinner", SkaterPoser.SPECIAL_SPIN_TIME * 0.25)
	assert_near(absf(quarter.y), 180.0, 0.01, "half a turn a quarter of the way through two turns")
	assert_true(_rot("special_pizza_spinner", SkaterPoser.SPECIAL_SPIN_TIME).is_zero_approx(), "ends at identity")


func test_bail_lets_the_feet_go() -> void:
	var p: Dictionary = SkaterPoser.pose_for("bail_fall", SkaterPoser.FALL_TIME, 0.0, 0.0)
	assert_near(float(p["feet_free"]), 1.0, 0.001, "feet hang free at the end of the fall")


func test_two_bone_reaches_a_reachable_target() -> void:
	var j: Array[Vector3] = SkaterPoser.two_bone(Vector3.ZERO, Vector3(0.1, -0.4, 0.0), Vector3(0, 0, -1), 0.3, 0.22)
	assert_true(j[2].distance_to(Vector3(0.1, -0.4, 0.0)) < 0.001, "end on target")
	assert_near(j[1].distance_to(j[0]), 0.3, 0.0001, "upper bone length kept")
	assert_near(j[2].distance_to(j[1]), 0.22, 0.0001, "lower bone length kept")
	assert_true(j[1].z < 0.0, "knee bends toward the pole")


func test_drop_in_hangs_nose_up_then_stomps_nose_down() -> void:
	var hang: Dictionary = SkaterPoser.pose_for("drop_in", 0.1, 0.0, 0.0)
	var stomp: Dictionary = SkaterPoser.pose_for("drop_in", RampSnap.HANG_TIME + RampSnap.STOMP_TIME, 0.0, 0.0)
	assert_true(_has_full_pose(hang) and _has_full_pose(stomp), "full drop-in poses")
	assert_true((hang["board_rot"] as Vector3).x > 10.0, "tail hooked on the coping: nose up")
	assert_true((stomp["board_rot"] as Vector3).x < -15.0, "stomped: nose down the ramp")
	assert_true(float(stomp["pitch"]) > float(hang["pitch"]), "weight goes from the tail onto the front foot")
	assert_true((hang["foot_L"] as Vector3).y > (SkaterPoser.deck_point(hang, SkaterPoser.FRONT_FOOT) as Vector3).y + 0.05, "front foot hovers while hanging")


func _hips(anim: String, t: float, ctx: Dictionary) -> float:
	return float(SkaterPoser.pose_for(anim, t, 0.0, 0.0, false, 0.0, 0.0, ctx)["hips_y"])


func test_landing_absorb_scales_with_impact() -> void:
	var small: float = 0.0
	var big: float = 0.0
	for i: int in 40:
		var t: float = i * 0.015
		small = maxf(small, SkaterPoser.land_absorb(t, 0.15))
		big = maxf(big, SkaterPoser.land_absorb(t, 0.95))
	assert_true(small < 0.15, "a small hop barely dips (%f)" % small)
	assert_true(big > 0.9, "a big drop compresses deep (%f)" % big)
	assert_true(SkaterPoser.land_time(0.95) > SkaterPoser.land_time(0.15) + 0.25, "a big landing takes longer to recover")
	assert_near(SkaterPoser.land_absorb(SkaterPoser.land_time(0.95) + 0.01, 0.95), 0.0, 0.0001, "fully recovered")
	var deep: float = _hips("land", SkaterPoser.land_time(0.95) * SkaterPoser.LAND_HIT, {"impact": 0.95})
	var light: float = _hips("land", SkaterPoser.land_time(0.15) * SkaterPoser.LAND_HIT, {"impact": 0.15})
	assert_true(deep < light - 0.15, "the hips drop much further on the big landing")


func test_carve_leans_into_the_turn_and_rolls_the_deck() -> void:
	var right: Dictionary = SkaterPoser.pose_for("idle_ride", 1.0, 0.0, 0.0, false, 0.0, 0.0, {"carve": 1.0})
	var left: Dictionary = SkaterPoser.pose_for("idle_ride", 1.0, 0.0, 0.0, false, 0.0, 0.0, {"carve": -1.0})
	assert_true(float(right["lean"]) > 10.0 and float(left["lean"]) < -10.0, "body leans toward the inside of the turn")
	assert_true((right["board_rot"] as Vector3).z < -3.0, "deck rolls down on the inside edge")
	assert_true((right["Chest"] as Vector3).y < (left["Chest"] as Vector3).y - 10.0, "shoulders lead the turn")
	assert_near((right["foot_L"] as Vector3).distance_to(SkaterPoser.deck_point(right,
			SkaterPoser.FRONT_FOOT + Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0))), 0.0, 0.001, "feet ride the rolled deck")


func test_idle_variety_only_when_stopped_and_after_a_while() -> void:
	var early: Dictionary = SkaterPoser.pose_for("idle_ride", 0.5, 0.0, 0.0, false, 0.0, 0.0, {"ride_speed": 0.0})
	var calm: Dictionary = SkaterPoser.pose_for("idle_ride", 0.5, 0.0, 0.0, false, 0.0, 0.0, {"ride_speed": 6.0})
	assert_eq(early["foot_L"], calm["foot_L"], "nothing happens in the first moments")
	var heads: Dictionary = {}
	var feet_moved: bool = false
	for i: int in 40:
		var t: float = SkaterPoser.IDLE_DELAY + i * 0.25
		var p: Dictionary = SkaterPoser.pose_for("idle_ride", t, 0.0, 0.0, false, 0.0, 0.0, {"ride_speed": 0.0})
		heads[snappedf((p["Head"] as Vector3).y, 5.0)] = true
		feet_moved = feet_moved or (p["foot_L"] as Vector3).y > (early["foot_L"] as Vector3).y + 0.02
		var moving: Dictionary = SkaterPoser.pose_for("idle_ride", t, 0.0, 0.0, false, 0.0, 0.0, {"ride_speed": 6.0})
		assert_eq(moving["foot_L"], early["foot_L"], "no foot shuffling while riding")
	assert_true(heads.size() >= 6, "the head looks around while stopped")
	assert_true(feet_moved, "the front foot gets re-set while stopped")


func test_stalls_tip_the_free_end_up() -> void:
	assert_true(_rot("grind_five_oh", 0.3).x > 5.0, "5-0: nose up over the back truck")
	assert_true(_rot("grind_nosegrind", 0.3).x < -5.0, "nosegrind: tail up over the front truck")
	assert_true(_rot("grind_blunt_slide", 0.3).x > 40.0, "blunt: board stood up nose high")
	assert_true(_rot("grind_smith_grind", 0.3).x < -5.0, "smith: nose dipped below the rail")
	var five: Dictionary = SkaterPoser.pose_for("grind_five_oh", 0.3, 0.6, 0.0)
	assert_true((five["foot_L"] as Vector3).y > (five["foot_R"] as Vector3).y, "5-0: front foot above the back foot")


func test_flick_directions_match_the_trick() -> void:
	var kf: Dictionary = SkaterPoser.flick("flip_kickflip")
	var hf: Dictionary = SkaterPoser.flick("flip_heelflip")
	assert_true((kf["front"] as Vector3).x > 0.1, "kickflip flicks out over the toe-side edge")
	assert_true((hf["front"] as Vector3).z < (kf["front"] as Vector3).z, "heelflip kicks further forward off the nose")
	assert_true(float(hf["toe"]) > 10.0, "heelflip leads with the heel")
	assert_true((SkaterPoser.flick("flip_pop_shove_it")["back"] as Vector3).x < 0.0, "backside shove scoops to the heel side")
	assert_true((SkaterPoser.flick("flip_hardflip")["back"] as Vector3).x > 0.0, "frontside (hardflip) scoops to the toe side")


func test_ollie_front_foot_slides_up_and_arms_rise() -> void:
	var start: Dictionary = SkaterPoser.pose_for("ollie", 0.0, 0.0, 0.0)
	var slide: Dictionary = SkaterPoser.pose_for("ollie", SkaterPoser.LEVEL_TIME, 0.0, 0.0)
	assert_true(float(start["hips_y"]) < float(slide["hips_y"]) - 0.1, "pops up out of the crouch")
	var z0: float = SkaterPoser.deck_point(slide, SkaterPoser.FRONT_FOOT + Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0)).z
	assert_true((slide["foot_L"] as Vector3).z < z0 - 0.03, "front foot slides toward the nose")
	assert_true(absf((slide["LeftUpperArm"] as Vector3).z) > absf((start["LeftUpperArm"] as Vector3).z) + 20.0, "arms thrown out with the pop")


func test_falling_extends_the_legs_for_the_landing() -> void:
	var up: Dictionary = SkaterPoser.pose_for("air", 0.1, 0.0, 0.0, false, 0.0, 0.0, {"vy": 2.0})
	var down: Dictionary = SkaterPoser.pose_for("air", 0.1, 0.0, 0.0, false, 0.0, 0.0, {"vy": -7.0})
	assert_true((down["board_pos"] as Vector3).y < (up["board_pos"] as Vector3).y - 0.1, "board reaches down when falling")


func test_push_ends_on_the_ball_of_the_foot() -> void:
	var t: float = SkaterPoser.PUSH_PLANT + SkaterPoser.PUSH_CYCLE * SkaterPoser.PUSH_CONTACT * 0.97
	assert_true(float(SkaterPoser.pose_for("push", t, 0.0, 0.0)["fpitch_R"]) < -15.0, "heel up at the toe-off")
	var plant: float = SkaterPoser.PUSH_PLANT + SkaterPoser.PUSH_CYCLE * 0.05
	assert_near(float(SkaterPoser.pose_for("push", plant, 0.0, 0.0)["fpitch_R"]), 0.0, 0.5, "flat on the plant")


func test_grabs_have_their_own_shapes() -> void:
	var seen: Dictionary = {}
	for a: String in ["grab_indy", "grab_melon", "grab_method", "grab_stalefish", "grab_mute", "grab_nosegrab", "grab_tailgrab"]:
		var p: Dictionary = SkaterPoser.pose_for(a, 0.5, 0.0, 0.0)
		seen[str([p["lean"], p["pitch"], p["Spine"], p["LeftUpperArm"], p["RightUpperArm"]])] = a
	assert_eq(seen.size(), 7, "each grab has its own body shape")


func test_carried_board_sways_with_the_stride_and_stays_in_hand() -> void:
	var a: Dictionary = SkaterPoser.pose_for("walk", 0.0, 0.0, 0.0, false, 1.4, 0.35)
	var b: Dictionary = SkaterPoser.pose_for("walk", 0.0, 0.0, 0.0, false, 1.4, 0.85)
	assert_true((a["board_rot"] as Vector3).distance_to(b["board_rot"]) > 3.0, "board swings with the stride")
	for p: Dictionary in [a, b]:
		assert_near(float(p["grip_R"]), 1.0, 0.001, "right hand holds the board")


func test_vrm_stall_tips_further_than_the_houdini_cap() -> void:
	var houdini: float = (SkaterPoser.pose_for("grind_five_oh", 0.3, 0.6, 0.0)["board_rot"] as Vector3).x
	var vrm: float = (SkaterPoser.pose_for("grind_five_oh", 0.3, 0.6, 0.0, false, 0.0, 0.0, {"vrm": true})["board_rot"] as Vector3).x
	assert_near(houdini, SkaterPoser.GRIND_STALL, 0.01, "Houdini bodies keep the 6 degree cap")
	assert_near(vrm, SkaterPoser.GRIND_STALL_VRM, 0.01, "the VRoid lead tips the 5-0 board 14 degrees")
	var nose: Dictionary = SkaterPoser.pose_for("grind_nosegrind", 0.3, 0.6, 0.0, false, 0.0, 0.0, {"vrm": true})
	assert_near((nose["board_rot"] as Vector3).x, -SkaterPoser.GRIND_STALL_VRM, 0.01, "nosegrind tips tail up")


func test_nollie_pops_off_the_nose_with_weight_forward() -> void:
	var load_pose: Dictionary = SkaterPoser.pose_for("nollie", 0.0, 0.0, 0.0)
	var pop: Dictionary = SkaterPoser.pose_for("nollie", SkaterPoser.POP_TIME, 0.0, 0.0)
	assert_true(_has_full_pose(pop), "a full pose")
	assert_true((pop["board_rot"] as Vector3).x < -15.0, "the nose snaps down: tail up")
	assert_true(float(load_pose["pitch"]) > 5.0, "weight forward in the load")
	assert_true((load_pose["foot_R"] as Vector3).y < ANKLE_ON_DECK + 0.01 and (load_pose["foot_L"] as Vector3).y < ANKLE_ON_DECK + 0.01, "feet on the deck in the load")
	var end: Dictionary = SkaterPoser.pose_for("nollie", 1.0, 0.0, 0.0)
	assert_near((end["board_rot"] as Vector3).x, 0.0, 0.01, "board levels out")


func test_powerslide_turns_the_board_across_and_counter_rotates_the_shoulders() -> void:
	var p: Dictionary = SkaterPoser.pose_for("powerslide", 0.5, 0.0, 0.0)
	assert_near((p["board_rot"] as Vector3).y, 90.0, 0.01, "board a quarter turn across the line")
	assert_true(float(p["body_yaw"]) < float(p["feet_yaw"]), "the body turns less than the feet")
	assert_true((p["Chest"] as Vector3).y < -10.0, "shoulders counter-rotate")
	assert_true(float(p["hips_y"]) < SkaterPoser.IDLE_HIPS - 0.1, "low stance")


func test_thug2_move_poses_are_full_and_finite() -> void:
	for a: String in MOVE_ANIMS:
		for sw: bool in [false, true]:
			for t: float in [0.0, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 1.0]:
				var pose: Dictionary = SkaterPoser.pose_for(a, t, 0.3, 0.0, sw, 4.0, 0.3, {"vy": -3.0})
				assert_true(_has_full_pose(pose), "full pose for %s at %f" % [a, t])
				for k: String in ["foot_L", "foot_R", "board_pos", "board_rot"]:
					assert_true((pose[k] as Vector3).is_finite(), "%s finite for %s at %f" % [k, a, t])


func test_thug2_moves_end_back_on_the_deck() -> void:
	for a: String in ["wallplant", "boneless", "no_comply", "acid_drop"]:
		var end: Dictionary = SkaterPoser.pose_for(a, 1.5, 0.0, 0.0)
		assert_near((end["foot_L"] as Vector3).y, ANKLE_ON_DECK + float((end["board_pos"] as Vector3).y), 0.001, a + " front foot on the deck at the end")
		assert_near((end["foot_R"] as Vector3).y, ANKLE_ON_DECK + float((end["board_pos"] as Vector3).y), 0.001, a + " back foot on the deck at the end")
		assert_near(float(end["grip_L"]) + float(end["grip_R"]), 0.0, 0.001, a + " hands free at the end")


func test_wallplant_puts_a_foot_on_the_wall() -> void:
	var mid: Dictionary = SkaterPoser.pose_for("wallplant", 0.2, 0.0, 0.0)
	var foot: Vector3 = mid["foot_L"]
	assert_true(foot.z < -0.45, "front foot reaches ahead of the nose to the wall")
	assert_true(foot.y > 0.4, "planted well above the ground")
	assert_true(float(mid["fpitch_L"]) > 60.0, "sole turned flat to the wall")
	assert_true((mid["foot_R"] as Vector3).y > ANKLE_ON_DECK and (mid["foot_R"] as Vector3).y < 0.5, "back foot rides the lifted board")


func test_boneless_plants_the_front_foot_and_grabs_the_board() -> void:
	var mid: Dictionary = SkaterPoser.pose_for("boneless", 0.25, 0.0, 0.0)
	assert_near((mid["foot_L"] as Vector3).y, PlaceholderSkater.ANKLE_HEIGHT, 0.001, "front foot on the ground")
	assert_near(float(mid["grip_L"]), 1.0, 0.01, "front hand holds the board")
	assert_true((mid["board_pos"] as Vector3).y > 0.2, "board lifted into the hand")


func test_no_comply_front_foot_steps_off_ahead_of_the_nose() -> void:
	var mid: Dictionary = SkaterPoser.pose_for("no_comply", 0.25, 0.0, 0.0)
	assert_near((mid["foot_L"] as Vector3).y, PlaceholderSkater.ANKLE_HEIGHT, 0.001, "front foot on the ground")
	assert_true((mid["foot_L"] as Vector3).z < -0.5, "past the nose")
	var pop: Dictionary = SkaterPoser.pose_for("no_comply", 0.17, 0.0, 0.0)
	assert_true((pop["board_rot"] as Vector3).x > 10.0, "tail snapped, nose up")


func test_caveman_throws_the_board_down() -> void:
	assert_near(float(SkaterPoser.pose_for("caveman", 0.0, 0.0, 0.0, false, 4.5)["grip_R"]), 1.0, 0.01, "board in hand at the start")
	assert_near(float(SkaterPoser.pose_for("caveman", 0.6, 0.0, 0.0, false, 4.5)["grip_R"]), 0.0, 0.01, "board thrown by the end")


func test_acid_drop_tucks_and_levels_the_board() -> void:
	var early: Dictionary = SkaterPoser.pose_for("acid_drop", 0.08, 0.0, 0.0)
	var late: Dictionary = SkaterPoser.pose_for("acid_drop", 0.4, 0.0, 0.0)
	assert_true((early["board_rot"] as Vector3).x < -5.0, "board follows the fall nose down")
	assert_true(absf((late["board_rot"] as Vector3).x) < 1.0, "levelled out to the transition")
	assert_true(float(early["hips_y"]) < SkaterPoser.IDLE_HIPS - 0.08, "tucked, knees up")


func test_air_tucks_rising_and_reaches_for_the_ground_falling() -> void:
	var rising: Dictionary = SkaterPoser.pose_for("air", 0.4, 0.0, 0.0, false, 0.0, 0.0, {"vy": 5.0})
	var apex: Dictionary = SkaterPoser.pose_for("air", 0.4, 0.0, 0.0, false, 0.0, 0.0, {"vy": 0.0})
	var falling: Dictionary = SkaterPoser.pose_for("air", 0.4, 0.0, 0.0, false, 0.0, 0.0, {"vy": -7.0})
	var up: float = (rising["board_pos"] as Vector3).y
	assert_true(up > 0.25, "board pulled well up under the feet on the way up (%f)" % up)
	assert_true((apex["board_pos"] as Vector3).y > 0.15, "still tucked at the apex")
	assert_true((falling["board_pos"] as Vector3).y < 0.08, "board down and the legs long for the landing")
	var reach: float = PlaceholderSkater.UPPER_LEG + PlaceholderSkater.LOWER_LEG
	for p: Dictionary in [rising, apex, falling]:
		var hip: Vector3 = Vector3(0.0, PlaceholderSkater.DECK_TOP_Y + PlaceholderSkater.HIP_HEIGHT + float(p["hips_y"]), 0.0)
		assert_true(((p["foot_R"] as Vector3).distance_to(hip)) < reach, "feet within reach of the hips")
	assert_true(((rising["foot_R"] as Vector3).y - (falling["foot_R"] as Vector3).y) > 0.2, "knees tuck: the feet ride up toward the hips")
	assert_true(absf((rising["LeftUpperArm"] as Vector3).x - (rising["RightUpperArm"] as Vector3).x) > 20.0, "arms balance asymmetrically")
	assert_true((falling["Head"] as Vector3).x < (rising["Head"] as Vector3).x - 8.0, "eyes drop to the landing")


func test_air_feet_stay_pinned_to_the_deck_in_every_phase() -> void:
	for vy: float in [8.0, 4.0, 0.0, -3.0, -8.0]:
		for t: float in [0.0, 0.1, 0.3, 0.8]:
			var p: Dictionary = SkaterPoser.pose_for("air", t, 0.0, 0.0, false, 0.0, 0.0, {"vy": vy})
			assert_near(float(p["feet_on_board"]), 1.0, 0.001, "shoes flat on the deck")
			for pair: Array in [["foot_L", SkaterPoser.FRONT_FOOT], ["foot_R", SkaterPoser.BACK_FOOT]]:
				var want: Vector3 = SkaterPoser.deck_point(p, (pair[1] as Vector3) + Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0))
				assert_true((p[pair[0]] as Vector3).distance_to(want) < 0.06, "%s within 6 cm of its deck spot (vy %f t %f)" % [pair[0], vy, t])


func test_big_landing_compresses_and_holds_for_a_fifth_to_two_fifths_of_a_second() -> void:
	var im: float = 0.95
	var depth: float = SkaterPoser.land_absorb(SkaterPoser.land_time(im) * SkaterPoser.LAND_HIT, im)
	var down_until: float = 0.0
	for i: int in 200:
		var t: float = i * 0.005
		if SkaterPoser.land_absorb(t, im) >= depth * 0.95:
			down_until = t
	assert_true(down_until > 0.2 and down_until < 0.45, "the knees are at the bottom until %f s" % down_until)
	assert_true(SkaterPoser.land_time(im) > 0.55 and SkaterPoser.land_time(im) < 0.85, "back up inside a second")
	var small_down: float = SkaterPoser.land_time(0.15) * SkaterPoser.LAND_HIT
	assert_true(small_down < 0.12, "a small hop is quick")


func test_sketchy_landing_staggers_then_settles() -> void:
	var live: Dictionary = {"impact": 0.4, "stagger_left": 0.4, "stagger_time": 0.4}
	var clean: Dictionary = SkaterPoser.pose_for("land", 0.2, 0.0, 0.0, false, 0.0, 0.0, {"impact": 0.4})
	var sketchy: Dictionary = SkaterPoser.pose_for("land", 0.2, 0.0, 0.0, false, 0.0, 0.0, live)
	var arm_swing: float = ((sketchy["LeftUpperArm"] as Vector3) - (clean["LeftUpperArm"] as Vector3)).length()
	assert_true(arm_swing > 20.0, "arms windmill on a sketchy landing (%f)" % arm_swing)
	# Keyed to the physics stagger: the wobble is gone the moment Skater.stagger runs out, whatever the anim clock says.
	var over: Dictionary = {"impact": 0.4, "stagger_left": 0.0, "stagger_time": 0.4}
	var settled: Dictionary = SkaterPoser.pose_for("land", 0.3, 0.0, 0.0, false, 0.0, 0.0, over)
	var ref: Dictionary = SkaterPoser.pose_for("land", 0.3, 0.0, 0.0, false, 0.0, 0.0, {"impact": 0.4})
	assert_near(float(settled["lean"]), float(ref["lean"]), 0.001, "the stagger is over when Skater.stagger is")
	# ...and it fades with the remaining time: more left, more wobble.
	var wob: Callable = func(left: float) -> float:
		var p: Dictionary = SkaterPoser.pose_for("land", 0.2, 0.0, 0.0, false, 0.0, 0.0, {"impact": 0.4, "stagger_left": left, "stagger_time": 0.4})
		return ((p["LeftUpperArm"] as Vector3) - (ref["LeftUpperArm"] as Vector3)).length()
	assert_true(wob.call(0.4) > wob.call(0.2) and wob.call(0.2) > wob.call(0.05), "the wobble fades as the stagger counts down")
	# A short landing pose does not cut it off: the same wobble shows on the ground-riding anims.
	var idle_clean: Dictionary = SkaterPoser.pose_for("idle_ride", 1.0, 0.0, 0.0)
	var idle_stag: Dictionary = SkaterPoser.pose_for("idle_ride", 1.0, 0.0, 0.0, false, 0.0, 0.0, {"stagger_left": 0.3, "stagger_time": 0.4})
	assert_true(((idle_stag["LeftUpperArm"] as Vector3) - (idle_clean["LeftUpperArm"] as Vector3)).length() > 10.0,
			"the stagger carries on after the land anim ends")


func test_vert_air_turns_the_rider_toward_world_up() -> void:
	var up_local: Vector3 = Vector3(0.0, 0.1, -0.995).normalized()  ## board standing on the wall: world up is nearly along -Z
	var none: Dictionary = SkaterPoser.pose_for("air", 0.5, 0.0, 0.0, false, 0.0, 0.0, {"vy": 1.0})
	assert_eq(none["tilt"], Vector3.ZERO, "no tilt without vert air")
	var tilted: Dictionary = SkaterPoser.pose_for("air", 0.5, 0.0, 0.0, false, 0.0, 0.0, {"vy": 1.0, "tilt_w": 1.0, "up_local": up_local})
	var deg: float = (tilted["tilt"] as Vector3).length()
	assert_true(deg > 55.0 and deg < 75.0, "the rider rights itself most of the way (%f deg)" % deg)
	var landing: Dictionary = SkaterPoser.pose_for("air", 0.9, 0.0, 0.0, false, 0.0, 0.0, {"vy": -8.0, "tilt_w": 1.0, "up_local": up_local})
	assert_near((landing["tilt"] as Vector3).length(), 0.0, 0.001, "the tilt is gone by the time the legs reach for the ramp")


func test_flatland_poses_are_distinct_and_full() -> void:
	var seen: Dictionary = {}
	for a: String in ["manual_casper", "manual_pogo", "manual_anti_casper", "manual_truckstand", "manual_handstand", "manual_manual"]:
		var p: Dictionary = SkaterPoser.pose_for(a, 0.5, 0.3, 0.0)
		assert_true(_has_full_pose(p), "full pose for " + a)
		var key: String = "%s|%s|%s" % [str(p["board_rot"]), str(p["pitch"]), str(p["lift"])]
		assert_false(seen.has(key), a + " has its own pose")
		seen[key] = true
	assert_true(float(SkaterPoser.pose_for("manual_handstand", 0.5, 0.3, 0.0)["pitch"]) > 150.0, "handstand inverts the rider")
	assert_near(float((SkaterPoser.pose_for("manual_casper", 0.5, 0.3, 0.0)["board_rot"] as Vector3).z), 180.0, 0.01, "casper flips the board")


func test_manual_pivot_spins_half_round() -> void:
	var ctx: Dictionary = {"pivot_p": 0.0, "pivot_dir": 1.0}
	var start: Dictionary = SkaterPoser.pose_for("manual_nose_manual", 0.5, 0.2, 0.0, true, 0.0, 0.0, ctx)
	var done: Dictionary = SkaterPoser.pose_for("manual_nose_manual", 0.5, 0.2, 0.0, true)
	assert_near(absf(float(start["body_yaw"]) - float(done["body_yaw"])), 180.0, 0.01, "rider starts a half turn away")
	assert_near(absf(float((start["board_rot"] as Vector3).y)), 180.0, 0.01, "board starts a half turn away")
	assert_near(float((done["board_rot"] as Vector3).y), 0.0, 0.01, "board ends square")


func test_new_grabs_grinds_and_lips_have_full_poses() -> void:
	var anims: PackedStringArray = ["grab_madonna", "grab_judo", "grab_crossbone", "grab_rocket_air", "grab_christ_air",
			"grab_cannonball", "grab_crail", "grab_japan", "grab_roast_beef", "grab_double_airwalk", "grab_unknown_thing",
			"grind_overcrook", "grind_willy_grind", "grind_salad_grind", "grind_suski_grind", "grind_darkslide",
			"grind_hurricane", "grind_noseslide", "grind_tailslide", "grind_nosebluntslide", "lip_invert", "lip_eggplant",
			"lip_one_foot_invert", "lip_nose_pick", "lip_blunt_to_fakie", "lip_feeble_stall", "lip_smith_stall"]
	for a: String in anims:
		for t: float in [0.05, 0.4]:
			assert_true(_has_full_pose(SkaterPoser.pose_for(a, t, 0.5, 0.2)), "full pose for %s at %f" % [a, t])
	var rot_a: Vector3 = SkaterPoser.pose_for("grind_overcrook", 0.4, 0.6, 0.0)["board_rot"]
	var rot_b: Vector3 = SkaterPoser.pose_for("grind_crooked_grind", 0.4, 0.6, 0.0)["board_rot"]
	assert_true(rot_a.distance_to(rot_b) > 5.0, "overcrook differs from crooked")


## Every shipped grab / grind / lip anim resolves to its own intended pose branch (exact id first, never a keyword from
## another trick: grind_noseslide is not a nose grind, grind_tailslide not a tail grind).
const GRAB_BRANCH: Dictionary = {
	"grab_madonna": "madonna", "grab_rocket_air": "rocket", "grab_judo": "judo", "grab_crossbone": "crossbone",
	"grab_christ_air": "christ", "grab_crail": "crail", "grab_japan": "japan", "grab_roast_beef": "roast",
	"grab_cannonball": "cannonball", "grab_indy": "indy", "grab_melon": "melon", "grab_method": "method",
	"grab_mute": "mute", "grab_nosegrab": "nosegrab", "grab_tailgrab": "tailgrab", "grab_benihana": "benihana",
	"grab_stalefish": "stalefish", "grab_airwalk": "airwalk",
}
const LIP_BRANCH: Dictionary = {
	"lip_invert": "invert", "lip_one_foot_invert": "one_foot_invert", "lip_eggplant": "eggplant",
	"lip_blunt_to_fakie": "blunt", "lip_nose_pick": "nose_pick", "lip_nose_stall": "nose_stall",
	"lip_smith_stall": "smith", "lip_feeble_stall": "feeble", "lip_axle_stall": "axle", "lip_rock_to_fakie": "rock",
	"lip_disaster": "disaster",
}


func test_each_grab_id_resolves_to_its_own_shape() -> void:
	var shapes: Dictionary = {}
	for a: String in GRAB_BRANCH:
		assert_eq(SkaterPoser.pose_branch(a), "grab:" + str(GRAB_BRANCH[a]), "branch for " + a)
		var g: Dictionary = SkaterPoser.grab_shape(a)
		var sig: String = str(g)
		assert_false(shapes.has(sig), "%s has a shape of its own (not %s's)" % [a, str(shapes.get(sig, ""))])
		shapes[sig] = a
	assert_eq(SkaterPoser.pose_branch("grab_double_airwalk"), "grab:airwalk", "an unknown id falls back on its keyword")
	assert_eq(SkaterPoser.pose_branch("grab_zzz"), "grab:mute", "an unknown id falls back on mute")


func test_each_grind_id_resolves_to_its_own_pose() -> void:
	var rots: Dictionary = {}
	for a: String in SkaterPoser.GRIND_BRANCHES:
		assert_eq(SkaterPoser.pose_branch(a), "grind:" + a, "branch for " + a)
		var p: Dictionary = SkaterPoser.pose_for(a, 0.4, 0.6, 0.0)
		var sig: String = "%s|%s|%s|%s" % [str(p["board_rot"]), str(p["board_pos"]), str(p["body_yaw"]), str(p["pitch"])]
		assert_false(rots.has(sig), "%s has a pose of its own (not %s's)" % [a, str(rots.get(sig, ""))])
		rots[sig] = a
	assert_eq(SkaterPoser.pose_branch("grind_fifty_fifty"), "grind:default", "50-50 rides the plain pose")
	# The collisions the keyword fallback used to risk: noseslide is a slide across the rail, not a nosegrind.
	var ns: Dictionary = SkaterPoser.pose_for("grind_noseslide", 0.4, 0.6, 0.0)
	var ng: Dictionary = SkaterPoser.pose_for("grind_nosegrind", 0.4, 0.6, 0.0)
	assert_true(absf(float(ns["body_yaw"]) - float(ng["body_yaw"])) > 45.0, "noseslide faces down the rail, a nosegrind does not")
	var ts: Dictionary = SkaterPoser.pose_for("grind_tailslide", 0.4, 0.6, 0.0)
	var fo: Dictionary = SkaterPoser.pose_for("grind_five_oh", 0.4, 0.6, 0.0)
	assert_true(absf(float(ts["body_yaw"]) - float(fo["body_yaw"])) > 45.0, "tailslide faces down the rail, a 5-0 does not")
	var nb: Dictionary = SkaterPoser.pose_for("grind_nosebluntslide", 0.4, 0.6, 0.0)
	assert_near(float(nb["body_yaw"]), float(ng["body_yaw"]), 0.01, "nose blunt slide keeps the stance (not a slide across)")
	assert_true((nb["board_rot"] as Vector3).x < -30.0, "nose blunt slide stands the board up on its nose")


func test_each_lip_id_resolves_to_its_own_pose() -> void:
	for a: String in LIP_BRANCH:
		assert_eq(SkaterPoser.pose_branch(a), "lip:" + str(LIP_BRANCH[a]), "branch for " + a)
	var coping: Dictionary = {}
	for a: String in ["lip_axle_stall", "lip_nose_stall", "lip_nose_pick", "lip_blunt_to_fakie", "lip_smith_stall", "lip_feeble_stall"]:
		var p: Dictionary = SkaterPoser.pose_for(a, 0.4, 0.4, 0.0)
		var sig: String = "%s|%s|%s" % [str(p["board_rot"]), str(p["board_pos"]), str(p["pitch"])]
		coping[a] = sig
	var seen: Dictionary = {}
	for a: String in coping:
		assert_false(seen.has(coping[a]), "coping %s has its own pose" % a)
		seen[coping[a]] = true
	# Inverts and the eggplant go upside down; nothing else does.
	for a: String in ["lip_invert", "lip_one_foot_invert", "lip_eggplant"]:
		assert_true(float(SkaterPoser.pose_for(a, 0.4, 0.4, 0.0)["pitch"]) > 100.0, a + " inverts the rider")
	for a: String in ["lip_nose_pick", "lip_nose_stall", "lip_blunt_to_fakie", "lip_smith_stall", "lip_feeble_stall"]:
		assert_true(float(SkaterPoser.pose_for(a, 0.4, 0.4, 0.0)["pitch"]) < 30.0, a + " keeps the rider upright")
	var pick: Dictionary = SkaterPoser.pose_for("lip_nose_pick", 0.4, 0.4, 0.0)
	var stall: Dictionary = SkaterPoser.pose_for("lip_nose_stall", 0.4, 0.4, 0.0)
	assert_true(float(pick["grip_R"]) > 0.5 and float(stall["grip_R"]) < 0.5, "the nose pick holds the tail, the nose stall does not")


func test_ledge_stalls_sit_near_flat_on_the_edge_at_standing_height() -> void:
	for a: String in ["lip_axle_stall", "lip_nose_stall", "lip_nose_pick", "lip_blunt_to_fakie", "lip_smith_stall",
			"lip_feeble_stall", "lip_rock_to_fakie", "lip_disaster"]:
		var cop: Dictionary = SkaterPoser.pose_for(a, 0.4, 0.4, 0.0)
		var led: Dictionary = SkaterPoser.pose_for(a, 0.4, 0.4, 0.0, false, 0.0, 0.0, {"ledge": true})
		assert_true(_has_full_pose(led), "full ledge pose for " + a)
		var bp: Vector3 = led["board_rot"]
		assert_true(absf(bp.x) < 45.0, "%s lies near flat on the ledge (%f deg)" % [a, bp.x])
		assert_true(absf((cop["board_rot"] as Vector3).x) > 60.0 or a == "lip_blunt_to_fakie", "%s stands up on coping" % a)
		var hip: float = float(led["hips_y"])
		assert_true(hip > SkaterPoser.IDLE_HIPS - 0.2, "%s: the rider stands at normal height (hips_y %f)" % [a, hip])
		# the feet are on the board: the ankles within a hand of the deck
		var d: float = (led["foot_L"] as Vector3).distance_to(SkaterPoser.deck_point(led, SkaterPoser.FRONT_FOOT + Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0)))
		assert_true(d < 0.05, "%s: the front foot is on the deck" % a)
	var ns: Dictionary = SkaterPoser.pose_for("lip_nose_stall", 0.4, 0.4, 0.0, false, 0.0, 0.0, {"ledge": true})
	var smith: Dictionary = SkaterPoser.pose_for("lip_smith_stall", 0.4, 0.4, 0.0, false, 0.0, 0.0, {"ledge": true})
	var feeble: Dictionary = SkaterPoser.pose_for("lip_feeble_stall", 0.4, 0.4, 0.0, false, 0.0, 0.0, {"ledge": true})
	var blunt: Dictionary = SkaterPoser.pose_for("lip_blunt_to_fakie", 0.4, 0.4, 0.0, false, 0.0, 0.0, {"ledge": true})
	assert_true((ns["board_rot"] as Vector3).x < -10.0, "nose stall: tail up")
	assert_true((blunt["board_rot"] as Vector3).x > 20.0, "blunt: nose up on the tail")
	assert_true((smith["board_rot"] as Vector3).z < -10.0 and (feeble["board_rot"] as Vector3).z > 10.0, "smith and feeble roll opposite ways")


const ROUND8_ANIMS: PackedStringArray = ["natas_spin", "sticker_slap", "bert_slide", "skitch"]


func test_round8_moves_have_their_own_full_finite_poses() -> void:
	var idle: Dictionary = SkaterPoser.pose_for("idle_ride", 0.3, 0.0, 0.0)
	for a: String in ROUND8_ANIMS:
		assert_eq(SkaterPoser.pose_branch(a), "other:" + a, "exact id " + a)
		for sw: bool in [false, true]:
			for side: float in [1.0, -1.0]:
				for t: float in [0.0, 0.1, 0.3, 0.6, 2.0]:
					var ctx: Dictionary = {"wall_side": side, "uphill_side": side, "vy": 2.0}
					var pose: Dictionary = SkaterPoser.pose_for(a, t, 0.3, 0.4, sw, 4.0, 0.3, ctx)
					assert_true(_has_full_pose(pose), "full pose for %s at %f" % [a, t])
					for k: String in ["foot_L", "foot_R", "hand_L", "hand_R", "board_pos", "board_rot"]:
						assert_true((pose[k] as Vector3).is_finite(), "%s finite for %s" % [k, a])
		var mid: Dictionary = SkaterPoser.pose_for(a, 0.3, 0.3, 0.0, false, 4.0, 0.3, {"wall_side": 1.0, "uphill_side": 1.0})
		assert_true(float(mid["hips_y"]) < float(idle["hips_y"]) - 0.01 or a == "sticker_slap", a + " is not the idle pose")


func test_natas_crouches_over_the_post_with_a_hand_on_it() -> void:
	var p: Dictionary = SkaterPoser.pose_for("natas_spin", 0.4, 0.0, 0.0)
	assert_true(float(p["hips_y"]) < SkaterPoser.IDLE_HIPS - 0.3, "deep crouch")
	assert_near(float(p["grip_L"]) + float(p["grip_R"]), 1.0, 0.01, "exactly one hand down")
	var hand: Vector3 = p["hand_L"] if float(p["grip_L"]) > 0.5 else p["hand_R"]
	assert_true(hand.y < 0.2 and absf(hand.x) < 0.3 and absf(hand.z) < 0.2, "hand on the board's edge over the post")
	assert_near(float((p["board_pos"] as Vector3).y), 0.0, 0.001, "board sits on the post top")


func test_sticker_slap_kicks_a_foot_out_toward_the_wall_and_returns() -> void:
	for side: float in [1.0, -1.0]:
		var mid: Dictionary = SkaterPoser.pose_for("sticker_slap", 0.15, 0.0, 0.0, false, 6.0, 0.0, {"wall_side": side, "vy": 1.0})
		var foot: Vector3 = mid["foot_L"]
		assert_true(foot.x * side > 0.4, "foot out on the wall side %f" % side)
		assert_true(foot.y > 0.25, "foot lifted off the board")
		assert_true(float(mid["fpitch_L"]) > 40.0, "sole turned to the wall")
		assert_true(float(mid["grip_L"]) + float(mid["grip_R"]) > 0.5, "an arm braces the wall")
	var start: Dictionary = SkaterPoser.pose_for("sticker_slap", 0.0, 0.0, 0.0, false, 6.0, 0.0, {"wall_side": 1.0})
	assert_true(float(start["feet_on_board"]) > 0.95, "both feet on the board before the tap")
	var done: Dictionary = SkaterPoser.pose_for("sticker_slap", 0.3, 0.0, 0.0, false, 6.0, 0.0, {"wall_side": 1.0})
	assert_true(float(done["feet_on_board"]) > 0.95, "and back on it when the slap ends")


func test_bert_slide_puts_the_uphill_hand_down_and_leans_into_the_bank() -> void:
	for side: float in [1.0, -1.0]:
		var p: Dictionary = SkaterPoser.pose_for("bert_slide", 0.3, 0.0, 0.0, false, 6.0, 0.0, {"uphill_side": side})
		var down: Vector3 = p["hand_L"] if float(p["grip_L"]) > 0.5 else p["hand_R"]
		assert_true(down.y < 0.1, "hand on the surface")
		assert_true(down.x * side > 0.2, "on the uphill side %f" % side)
		assert_true(float(p["lean"]) * side > 20.0, "leaning into the bank")
		assert_true(float(p["hips_y"]) < SkaterPoser.IDLE_HIPS - 0.25, "low body")
		assert_true(absf((p["board_rot"] as Vector3).y) > 10.0, "board swung round under the feet")


func test_skitch_holds_the_bumper_ahead_with_the_lead_hand() -> void:
	for sw: bool in [false, true]:
		var p: Dictionary = SkaterPoser.pose_for("skitch", 0.4, 0.0, 0.0, sw)
		var lead: String = "R" if sw else "L"
		var other: String = "L" if sw else "R"
		assert_near(float(p["grip_" + lead]), 1.0, 0.01, "lead hand grips")
		assert_near(float(p["grip_" + other]), 0.0, 0.01, "other arm free")
		assert_true((p["hand_" + lead] as Vector3).z < -0.4, "hand ahead of the nose side")
		assert_true(float(p["pitch"]) > 15.0, "leaning toward the car")
