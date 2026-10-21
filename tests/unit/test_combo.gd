extends TestCase


func test_multiplier_is_trick_count() -> void:
	var c: Combo = Combo.new()
	assert_false(c.is_active(), "empty combo is not active")
	assert_eq(c.multiplier(), 0)
	assert_eq(c.total(), 0)
	c.add_trick("flip", "Kickflip", 100)
	c.add_trick("grab", "Indy", 50)
	assert_true(c.is_active())
	assert_eq(c.trick_count(), 2)
	assert_eq(c.base_sum(), 150)
	assert_eq(c.multiplier(), 2)
	assert_eq(c.total(), 300, "(100 + 50) x 2")


func test_repeat_penalty_steps() -> void:
	var c: Combo = Combo.new()
	c.add_trick("flip", "Kickflip", 100)
	c.add_trick("flip", "Kickflip", 100)
	c.add_trick("flip", "Kickflip", 100)
	c.add_trick("flip", "Kickflip", 100)
	c.add_trick("flip", "Kickflip", 100)
	c.add_trick("flip", "Kickflip", 100)
	# 100, 75, 50, 25, 10, 10
	assert_eq(c.base_sum(), 270)
	assert_eq(c.multiplier(), 6)
	assert_eq(c.total(), 1620)


func test_repeat_only_counts_same_id() -> void:
	var c: Combo = Combo.new()
	c.add_trick("flip", "Kickflip", 100)
	c.add_trick("grab", "Indy", 100)
	c.add_trick("flip", "Kickflip", 100)
	assert_eq(c.base_sum(), 275, "100 + 100 + 75 (second flip repeat)")


func test_spin_bonus_and_names() -> void:
	var c: Combo = Combo.new()
	c.add_trick("kf", "Kickflip", 100, 540)
	# floor((540+30)/180) = 3 -> x2.5
	assert_eq(c.base_sum(), 250, "540 spin bonus")
	var names: Array[String] = []
	c.trick_added.connect(func(n: String, _p: int) -> void: names.append(n))
	c.add_trick("kf2", "Kickflip", 100, 360)
	c.add_trick("hf", "Heelflip", 100, 180)
	c.add_trick("sh", "Shove", 100, 90)
	c.add_trick("sp", "Spin", 100, -180)
	assert_eq(c.base_sum(), 250 + 200 + 150 + 100 + 150, "bonuses: 360 x2, 180 x1.5, 90 x1, -180 x1.5")
	assert_eq(names.size(), 4)
	assert_eq(names[0], "360 Kickflip")
	assert_eq(names[1], "180 Heelflip")
	assert_eq(names[2], "Shove", "90 spin has no prefix")
	assert_eq(names[3], "180 Spin", "negative spin uses absolute value")


func test_spin_below_180_has_no_name_prefix() -> void:
	var c: Combo = Combo.new()
	var names: Array[String] = []
	c.trick_added.connect(func(n: String, _p: int) -> void: names.append(n))
	c.add_trick("x", "Ollie", 100, 150)
	assert_eq(names[0], "Ollie")
	assert_eq(c.base_sum(), 150, "150 degrees still earns the first step (floor((150+30)/180) = 1)")


func test_spin_and_repeat_combine() -> void:
	var c: Combo = Combo.new()
	c.add_trick("kf", "Kickflip", 100)
	c.add_trick("kf", "Kickflip", 100, 180)
	# second kickflip: 100 x 0.75 x 1.5 = 112.5 -> 113 (round half away from zero)
	assert_eq(c.base_sum(), 213)


func test_hold_points_accrue_to_last_trick() -> void:
	var c: Combo = Combo.new()
	c.add_trick("grind", "Grind", 50)
	c.add_hold_points(10, 0.25)
	assert_eq(c.base_sum(), 52, "2.5 accumulates, 2 whole points added")
	c.add_hold_points(10, 0.25)
	assert_eq(c.base_sum(), 55, "remaining 0.5 + 2.5 = 3 whole points")
	assert_eq(c.total(), 55, "one trick, multiplier 1")


func test_hold_points_apply_only_to_most_recent_trick() -> void:
	var c: Combo = Combo.new()
	c.add_trick("grind", "Grind", 50)
	c.add_trick("grab", "Grab", 40)
	c.add_hold_points(20, 1.0)
	assert_eq(c.base_sum(), 50 + 40 + 20)


func test_hold_points_with_no_tricks_is_ignored() -> void:
	var c: Combo = Combo.new()
	c.add_hold_points(100, 1.0)
	assert_false(c.is_active())
	c.add_trick("grind", "Grind", 10)
	assert_eq(c.base_sum(), 10, "no held points leaked from before the trick")


func test_gap_counts_as_trick() -> void:
	var c: Combo = Combo.new()
	var got: Array = []
	c.trick_added.connect(func(n: String, p: int) -> void: got.append([n, p]))
	c.add_gap("Gap Hit", 200)
	assert_eq(c.trick_count(), 1)
	assert_eq(c.multiplier(), 1)
	assert_eq(c.total(), 200)
	assert_eq(got[0], ["Gap Hit", 200])


func test_gap_not_repeat_penalized() -> void:
	var c: Combo = Combo.new()
	c.add_gap("Gap Hit", 200)
	c.add_gap("Gap Hit", 200)
	assert_eq(c.base_sum(), 400)


func test_land_adds_to_landed_and_resets() -> void:
	var c: Combo = Combo.new()
	c.add_trick("a", "A", 100)
	c.add_trick("b", "B", 50)
	var got: int = c.land()
	assert_eq(got, 300)
	assert_eq(c.landed_total, 300)
	assert_false(c.is_active(), "land resets the combo")
	assert_eq(c.total(), 0)
	assert_eq(c.trick_count(), 0)


func test_bail_scores_nothing_and_resets() -> void:
	var c: Combo = Combo.new()
	c.add_trick("a", "A", 100)
	c.add_trick("b", "B", 50)
	c.bail()
	assert_false(c.is_active())
	assert_eq(c.landed_total, 0)
	assert_eq(c.best_combo, 0)


func test_repeat_count_resets_after_land_and_bail() -> void:
	var c: Combo = Combo.new()
	c.add_trick("flip", "Kickflip", 100)
	c.land()
	c.add_trick("flip", "Kickflip", 100)
	assert_eq(c.base_sum(), 100, "new combo, full value again")
	c.bail()
	c.add_trick("flip", "Kickflip", 100)
	assert_eq(c.base_sum(), 100)


func test_best_combo_tracks_highest_landed() -> void:
	var c: Combo = Combo.new()
	c.add_trick("a", "A", 100)
	c.land()
	assert_eq(c.best_combo, 100)
	c.add_trick("a", "A", 100)
	c.add_trick("b", "B", 100)
	c.land()
	assert_eq(c.best_combo, 400, "2 tricks x 200 base")
	assert_eq(c.landed_total, 500)
	c.add_trick("c", "C", 10)
	c.land()
	assert_eq(c.best_combo, 400, "smaller combo does not lower best")
	assert_eq(c.landed_total, 510)


func test_bail_does_not_change_best_combo() -> void:
	var c: Combo = Combo.new()
	c.add_trick("a", "A", 500)
	c.bail()
	assert_eq(c.best_combo, 0)


func test_display_text_empty_and_short() -> void:
	var c: Combo = Combo.new()
	assert_eq(c.display_text(), "")
	c.add_trick("a", "Ollie", 10)
	c.add_trick("b", "Grind", 10)
	assert_eq(c.display_text(), "Ollie + Grind")


func test_display_text_exactly_five_has_no_prefix() -> void:
	var c: Combo = Combo.new()
	for n: String in ["A", "B", "C", "D", "E"]:
		c.add_trick(n, n, 1)
	assert_eq(c.display_text(), "A + B + C + D + E")


func test_display_text_truncates_to_last_five() -> void:
	var c: Combo = Combo.new()
	for n: String in ["A", "B", "C", "D", "E", "F", "G"]:
		c.add_trick(n, n, 1)
	assert_eq(c.display_text(), "... + C + D + E + F + G")


func test_display_text_uses_spin_names() -> void:
	var c: Combo = Combo.new()
	c.add_trick("kf", "Kickflip", 10, 540)
	assert_eq(c.display_text(), "540 Kickflip")
