extends TestCase
## Round 11 trick depth (pure parts): stance naming (Fakie / Nollie / Switch), the flip out of a grind, the grab grind's
## scoring entry, the hand plant poses (palm on the coping, board on the feet, grab hand on the deck), the grab grind pose
## (hand on the board's grab spot) and the 360 flip / 360 shove-it / pressure flip board spins. The ride side is in
## tests/sim/sim_trick_vocab.gd (grab_grind_*, flip_out_*, lip_hand_plant, lip_upright).

const SkaterScript := preload("res://game/skater/skater.gd")


func _skater() -> Skater:
	var sk: Skater = SkaterScript.new()
	sk.db = TrickDB.load_default()
	sk.gaps = Gaps.load_default()
	return sk


func test_stance_names() -> void:
	assert_eq(Skater.stance_name("Kickflip", "flip", false, false), "Kickflip")
	assert_eq(Skater.stance_name("Kickflip", "flip", false, true), "Fakie Kickflip", "a flip ridden backward is fakie")
	assert_eq(Skater.stance_name("Kickflip", "flip", true, false), "Nollie Kickflip")
	assert_eq(Skater.stance_name("Kickflip", "flip", true, true), "Switch Kickflip", "a nollie ridden backward is switch")
	assert_eq(Skater.stance_name("360 Flip", "flip", false, true), "Fakie 360 Flip")
	assert_eq(Skater.stance_name("Indy", "grab", false, true), "Switch Indy")
	assert_eq(Skater.stance_name("Indy", "grab", true, false), "Nollie Indy")
	assert_eq(Skater.stance_name("5-0", "grind", false, true), "Switch 5-0")
	assert_eq(Skater.stance_name("Invert", "lip", false, true), "Invert", "lip tricks keep their name")


func test_fakie_flip_scores_with_the_fakie_name() -> void:
	var sk: Skater = _skater()
	sk.switch_stance = true
	sk._score_trick(sk.db.get_trick("tre_flip"))
	assert_true(sk.combo.display_text().contains("Fakie 360 Flip"), sk.combo.display_text())
	sk.free()


func test_flip_out_trick() -> void:
	var db: TrickDB = TrickDB.load_default()
	var kf: Dictionary = db.get_trick("kickflip")
	var out: Dictionary = Skater.flip_out_trick(kf, db.find_link("grind_out"))
	assert_eq(str(out["name"]), "Kickflip Out")
	assert_eq(str(out["id"]), "kickflip_out")
	assert_eq(int(out["points"]), int(kf["points"]) + int(db.find_link("grind_out")["points"]))
	assert_eq(str(out["kind"]), "flip", "still a flip (goals count it)")
	assert_eq(str(out["anim"]), str(kf["anim"]), "posed as the flip")
	assert_eq(str(kf["name"]), "Kickflip", "the table entry is not changed")


func test_flip_out_only_in_the_window_after_a_grind_pop() -> void:
	var sk: Skater = _skater()
	sk.state.event("ollie")  # in the air
	sk._grind_out_until = sk._t + Skater.GRIND_OUT_WINDOW
	sk._air_trick({"button": "flip", "dir": "", "double_tap": false, "sequence": []})
	assert_true(sk.combo.display_text().contains("Kickflip Out"), sk.combo.display_text())
	assert_eq(sk._grind_out_until, -1.0, "only the first flip of the pop is the out")
	sk.free()
	var plain: Skater = _skater()
	plain.state.event("ollie")
	plain._air_trick({"button": "flip", "dir": "", "double_tap": false, "sequence": []})
	assert_false(plain.combo.display_text().contains("Out"), "a plain air flip is no out: " + plain.combo.display_text())
	plain.free()


func test_grab_grind_trick() -> void:
	var db: TrickDB = TrickDB.load_default()
	var t: Dictionary = Skater.grab_grind_trick(db.find("grind_grab", "E", false), db.get_trick("five_oh"))
	assert_eq(str(t["name"]), "Indy 5-0")
	assert_eq(str(t["anim"]), "grind_five_oh", "posed as the grind (the poser adds the grab)")
	assert_eq(str(t["id"]), "grind_grab_indy")


func test_hand_plants_put_the_palm_on_the_coping() -> void:
	for key: String in ["invert", "one_foot_invert", "andrecht", "sad_plant", "eggplant"]:
		var p: Dictionary = SkaterPoser.pose_for("lip_" + key, 0.4, 0.4, 0.0)
		var plant: String = str(SkaterPoser.plant_shape(key)["plant"])
		var hand: Vector3 = p["hand_" + plant]
		assert_true(float(p["grip_" + plant]) > 0.9, key + " plants a hand")
		assert_near(hand.y, SkaterPoser.PLANT_HAND_Y, 0.001, key + " palm on the coping top")
		assert_true(absf(hand.z) <= SkaterPoser.PLANT_HAND_REACH + 0.001, key + " palm on the coping line")
		var other: String = "R" if plant == "L" else "L"
		assert_true(float(p["grip_" + other]) > 0.9, key + " holds the board in the other hand")
	var a: Dictionary = SkaterPoser.pose_for("lip_andrecht", 0.4, 0.4, 0.0)
	var i: Dictionary = SkaterPoser.pose_for("lip_invert", 0.4, 0.4, 0.0)
	assert_true(float(a["grip_R"]) > 0.9 and (a["hand_R"] as Vector3).y < 0.0, "the andrecht plants the back hand")
	assert_true((i["hand_L"] as Vector3).y < 0.0, "the invert plants the front hand")
	for key: String in ["andrecht", "sad_plant"]:
		assert_true(float(SkaterPoser.pose_for("lip_" + key, 0.4, 0.4, 0.0)["pitch"]) > 150.0, key + " is upside down")
	var rb: Dictionary = SkaterPoser.pose_for("lip_russian_boneless", 0.4, 0.4, 0.0)
	assert_true(float(rb["pitch"]) < 60.0, "the russian boneless stays upright")
	assert_near((rb["foot_R"] as Vector3).y, SkaterPoser.PLANT_HAND_Y + PlaceholderSkater.ANKLE_HEIGHT, 0.001,
		"the russian boneless plants the back foot on the coping")


func test_hand_plants_keep_the_board_on_the_feet() -> void:
	for key: String in ["invert", "andrecht", "eggplant"]:
		var p: Dictionary = SkaterPoser.pose_for("lip_" + key, 0.4, 0.4, 0.0)
		var deck: Vector3 = SkaterPoser._board_point(p, Vector3(0.0, PlaceholderSkater.DECK_TOP_Y, 0.0))
		var feet: Vector3 = ((p["foot_L"] as Vector3) + (p["foot_R"] as Vector3)) * 0.5
		assert_true(deck.distance_to(feet) < 0.25, "%s board under the feet (%.2f m)" % [key, deck.distance_to(feet)])
		assert_true(deck.y > 0.8, key + " board up over the rider")


func test_grind_grab_puts_the_hand_on_the_grab_spot() -> void:
	for gg: String in ["grab_indy", "grab_melon", "grab_nosegrab", "grab_tailgrab"]:
		var plain: Dictionary = SkaterPoser.pose_for("grind_five_oh", 0.4, 0.6, 0.0)
		var p: Dictionary = SkaterPoser.pose_for("grind_five_oh", 0.4, 0.6, 0.0, false, 0.0, 0.0, {"grind_grab": gg})
		var g: Dictionary = SkaterPoser.grab_shape(gg)
		var hand: String = str(g["hand"])
		var spot: Vector3 = SkaterPoser.deck_point(p, (g["spot"] as Vector3) + Vector3(0.0, 0.015, 0.0))
		assert_true(float(p["grip_" + hand]) > 0.9, gg + " grips")
		assert_true((p["hand_" + hand] as Vector3).distance_to(spot) < 0.001, gg + " hand on the grab spot")
		assert_true(float(p["hips_y"]) < float(plain["hips_y"]) - 0.1, gg + " sinks down to reach")
		assert_eq(p["board_rot"], plain["board_rot"], gg + " leaves the board on the rail")


func test_new_flip_spins() -> void:
	var tre: Vector3 = SkaterPoser._board_spin("flip_tre_flip", SkaterPoser.FLIP_TIME * 0.5)
	assert_true(absf(tre.y) > 1.0 and absf(tre.z) > 1.0, "a 360 flip shoves and flips: %s" % str(tre))
	var sh: Vector3 = SkaterPoser._board_spin("flip_360_shove_it", SkaterPoser.FLIP_TIME * 0.5)
	assert_true(absf(sh.y) > 45.0 and absf(sh.z) < 0.01, "a 360 shove-it only shoves (wrapped past a half turn mid-way): %s" % str(sh))
	var pr: Vector3 = SkaterPoser._board_spin("flip_pressure_flip", SkaterPoser.FLIP_TIME * 0.3)
	var kf: Vector3 = SkaterPoser._board_spin("flip_kickflip", SkaterPoser.FLIP_TIME * 0.3)
	assert_true(pr.z * kf.z < 0.0 and absf(pr.y) > 1.0, "a pressure flip turns heelflip-wise while it shoves")
	for a: String in ["flip_tre_flip", "flip_360_shove_it", "flip_pressure_flip"]:
		var end: Vector3 = SkaterPoser._board_spin(a, SkaterPoser.FLIP_TIME)
		assert_true(Vector3(end.x, fposmod(end.y, 180.0), end.z).is_zero_approx(), a + " caught flat")
