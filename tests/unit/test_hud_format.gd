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


func test_zero_point_landing_spawns_no_pop() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var hud: Hud = Hud.new()
	tree.root.add_child(hud)
	hud._land_points = 0
	hud._flush_landing()
	assert_eq(hud._fx.get_child_count(), 0, "0-point landing shows nothing")
	hud._land_points = 150
	hud._flush_landing()
	assert_true(hud._fx.get_child_count() > 0, "a real landing still pops")
	hud.queue_free()


func test_balance_title_and_trick_size() -> void:
	assert_eq(Hud.balance_title("grind"), "GRIND")
	assert_eq(Hud.balance_title("manual"), "MANUAL")
	assert_eq(Hud.balance_title("lip"), "LIP")
	assert_true(Hud.trick_size("Ollie") > Hud.trick_size("Backside Tailslide to Fakie"), "long names shrink")
	assert_true(Hud.trick_size("Kickflip") == Hud.TRICK_SIZE, "short names full size")


func test_trick_string_is_below_the_skater() -> void:
	# the skater sits mid-screen; the trick string and the pop-ups must live in the lower band, never over them
	assert_true(Hud.TRICK_Y >= 0.72, "trick string bottom-centre")
	assert_true(Hud.FLOAT_Y >= 0.8 and Hud.FLOAT_X > 0.65, "points pop lower right")


func test_bail_shows_the_dead_combo_struck_and_clears_the_live_one() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var hud: Hud = Hud.new()
	tree.root.add_child(hud)
	hud._combo_box.visible = true
	hud._last_base = 1250
	hud._last_total_mult = 4
	hud._on_combo_bailed("Kickflip + Heelflip")
	assert_false(hud._combo_box.visible, "the live combo readout is gone on a bail")
	assert_true(hud._fail_box.visible, "the failed combo shows")
	assert_eq(hud._fail_trick.text, "Kickflip + Heelflip", "the dead combo keeps its trick line")
	assert_eq(hud._fail_pts.text, "1,250 x 4", "and its points")
	assert_true(hud._fail_shown, "shown once per bail")
	hud.queue_free()
