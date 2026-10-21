extends TestCase


func test_format_points_thousands_separators() -> void:
	assert_eq(Hud.format_points(1234567), "1,234,567")
	assert_eq(Hud.format_points(1000), "1,000")
	assert_eq(Hud.format_points(999), "999")
	assert_eq(Hud.format_points(0), "0")
	assert_eq(Hud.format_points(-12345), "-12,345", "negative keeps sign")


func test_combo_line_base_times_multiplier() -> void:
	assert_eq(Hud.combo_line(1250, 4), "1,250 x 4")
	assert_eq(Hud.combo_line(0, 0), "0 x 0")
	assert_eq(Hud.combo_line(100, 1), "100 x 1")


func test_gaps_line_found_over_total() -> void:
	assert_eq(Hud.gaps_line(3, 12), "Gaps 3/12")
	assert_eq(Hud.gaps_line(0, 0), "Gaps 0/0")


func test_count_up_moves_toward_target_without_overshoot() -> void:
	assert_eq(Hud.count_up(500.0, 500, 0.1), 500.0, "already there")
	assert_eq(Hud.count_up(0.0, 1000, 0.0), 0.0, "no time, no move")
	var step: float = Hud.count_up(0.0, 1000, 0.1)
	assert_true(step > 0.0 and step < 1000.0, "partway after 0.1 s, got %f" % step)
	assert_near(Hud.count_up(0.0, 1000, 20.0), 1000.0, 0.5, "long time reaches target")
	assert_eq(Hud.count_up(999.7, 1000, 0.016), 1000.0, "snaps when within half a point")


func test_balance_meter_is_vertical_only_for_manual() -> void:
	assert_true(Hud.balance_is_vertical("manual"))
	assert_false(Hud.balance_is_vertical("grind"))
	assert_false(Hud.balance_is_vertical("lip"))
	assert_false(Hud.balance_is_vertical(""))
