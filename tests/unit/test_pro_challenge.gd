extends TestCase
## Pro Challenge: the pro_challenge goal tiers, medals read back from a career, every level's file, and the settings
## that ride with it (balance assist, control remap).

const LEVELS: Array[String] = ["practice", "warehouse", "beach", "school", "downtown", "hills"]


func _tiers(within_silver: float = 0.0) -> Goals:
	var g: Goals = Goals.new()
	g.load_from_dict({"run_seconds": 120, "goals": [
		{"id": "x_pro_bronze", "title": "Bronze", "type": "pro_challenge", "tier": "bronze", "score": 1000, "chain": 1, "combo": 500, "gaps": ["a", "b", "c"]},
		{"id": "x_pro_silver", "title": "Silver", "type": "pro_challenge", "tier": "silver", "score": 3000, "chain": 2, "combo": 1500, "gaps": ["a", "b", "c"], "within": within_silver},
	]})
	return g


func test_bronze_needs_score_chain_and_combo() -> void:
	var g: Goals = _tiers()
	g.start_run(0.0)
	g.on_gap_event("a", "A", 5.0)
	assert_eq(g.on_combo_landed(400, 5000, []).size(), 0, "combo below 500")
	g.on_gap_event("a", "A", 6.0)
	assert_eq(g.on_combo_landed(800, 700, []).size(), 0, "run total below 1000")
	g.on_gap_event("zzz", "Z", 7.0)
	assert_eq(g.on_combo_landed(800, 5000, []).size(), 0, "no signature gap held")
	g.on_gap_event("b", "B", 8.0)
	var done: Array[Dictionary] = g.on_combo_landed(800, 5000, [])
	assert_eq(done.size(), 1, "bronze lands")
	assert_eq(done[0]["id"], "x_pro_bronze")
	assert_false(g.is_completed("x_pro_silver"))


func test_silver_needs_two_gaps_in_one_combo_and_the_clock() -> void:
	var g: Goals = _tiers(60.0)
	g.start_run(0.0)
	g.on_gap_event("a", "A", 10.0)
	g.on_combo_landed(2000, 9000, [])  # bronze, one gap
	g.on_gap_event("a", "A", 20.0)
	assert_eq(g.on_combo_landed(2000, 9000, []).size(), 0, "one gap is not a silver chain")
	g.on_gap_event("a", "A", 30.0)
	g.on_gap_event("c", "C", 31.0)
	g.tick(70.0)
	assert_eq(g.on_combo_landed(2000, 9000, []).size(), 0, "past the 60 s window")
	var g2: Goals = _tiers(60.0)
	g2.start_run(0.0)
	g2.on_gap_event("a", "A", 30.0)
	g2.on_gap_event("c", "C", 31.0)
	g2.tick(40.0)
	var ids: PackedStringArray = []
	for d: Dictionary in g2.on_combo_landed(2000, 9000, []):
		ids.append(d["id"])
	assert_true(ids.has("x_pro_silver") and ids.has("x_pro_bronze"), "both tiers inside the window")


func test_a_bailed_combo_counts_nothing_and_free_skate_parks_it() -> void:
	var g: Goals = _tiers()
	g.start_run(0.0)
	g.on_gap_event("a", "A", 5.0)
	g.on_combo_bailed()
	assert_eq(g.on_combo_landed(2000, 9000, []).size(), 0, "the held gap was lost with the bail")
	g.set_session(0.0)
	assert_false(g.is_active("x_pro_bronze"), "free skate has no clock")


func test_five_minute_session_doubles_the_score_ask() -> void:
	var g: Goals = _tiers()
	g.set_session(300.0)
	assert_eq(int(g.get_goal("x_pro_bronze")["target"]), 2000)


func test_every_level_has_three_tiers_and_a_line_the_bot_rides() -> void:
	for lvl: String in LEVELS:
		var info: Dictionary = ProgressStore.pro_info(lvl)
		assert_false(info.is_empty(), "%s has a pro challenge" % lvl)
		if info.is_empty():
			continue
		for t: String in info["tiers"]:
			assert_true(t != "", "%s: all three tiers" % lvl)
		var route: String = "res://game/levels/%s/bot_route.json" % lvl
		if lvl != "practice":
			assert_true(FileAccess.get_file_as_string(route).contains("\"%s\"" % info["line"]), "%s: line %s is a bot_route line" % [lvl, info["line"]])
		var g: Goals = Goals.new()
		assert_true(g.load_from_path(ProgressStore.goals_file(lvl)))
		assert_eq(g.load_errors.size(), 0, "%s goals load clean: %s" % [lvl, g.load_errors])


func test_medal_is_the_best_tier_done() -> void:
	var st: ProgressStore = ProgressStore.new()
	assert_eq(st.medal("hills"), 0)
	st.add_goal("hills", "hills_pro_silver")
	assert_eq(st.medal("hills"), 2, "silver")
	st.add_goal("hills", "hills_pro_bronze")
	assert_eq(st.medal("hills"), 2)
	st.add_goal("hills", "hills_pro_gold")
	assert_eq(st.medal("hills"), 3)
	var again: ProgressStore = ProgressStore.new()
	again.from_dict(st.to_dict())
	assert_eq(again.medal("hills"), 3, "medals survive a save and load")
	assert_eq(ProgressStore.medal_name(1), "Bronze medal")


func test_balance_assist_scales_the_growth() -> void:
	var was: int = GameSettings.balance_assist
	var fall: Array[float] = []
	for level: int in 3:
		GameSettings.balance_assist = level
		var b: Balance = Balance.new()
		b.start(7, 1.0)
		var ok: bool = true
		while ok and b.time_held() < 60.0:
			ok = b.update(1.0 / 60.0, 0.0)
		fall.append(b.time_held())
	GameSettings.balance_assist = was
	assert_true(fall[0] >= fall[1] and fall[1] >= fall[2], "easy lasts at least as long as normal, hard the shortest: %s" % [fall])
	GameSettings.balance_assist = 1
	assert_near(GameSettings.balance_growth_scale(), 1.0, 0.0001, "Normal is today's values")
	GameSettings.balance_assist = was


func test_remap_swaps_resets_and_never_saves_in_scripted_runs() -> void:
	ControlRemap.reset()
	var ollie_key: int = ControlRemap.key_of("ollie")
	var flip_key: int = ControlRemap.key_of("flip")
	ControlRemap.set_key("ollie", flip_key)
	assert_eq(ControlRemap.key_of("ollie"), flip_key)
	assert_eq(ControlRemap.key_of("flip"), ollie_key, "the two swapped")
	var has: bool = false
	for e: InputEvent in InputMap.action_get_events("ollie"):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == flip_key:
			has = true
	assert_true(has, "the InputMap follows")
	ControlRemap.set_pad("grab", JOY_BUTTON_LEFT_STICK)
	assert_eq(ControlRemap.pad_of("grab"), JOY_BUTTON_LEFT_STICK)
	assert_eq(ControlRemap.pad_of("dismount"), JOY_BUTTON_B, "dismount took grab's old button")
	ControlRemap.set_key("move_up", KEY_T)
	var arrows: int = 0
	for e: InputEvent in InputMap.action_get_events("move_up"):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_UP:
			arrows += 1
	assert_eq(arrows, 1, "the arrow key stays on move_up")
	ControlRemap.reset()
	assert_eq(ControlRemap.key_of("ollie"), ollie_key, "reset gives the defaults back")
	assert_eq(ControlRemap.key_of("move_up"), KEY_W)
	assert_false(FileAccess.file_exists(ControlRemap.SAVE_PATH) and Flags.is_scripted_run() and ControlRemap.keys.size() > 0)
