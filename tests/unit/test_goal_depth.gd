extends TestCase
## Round 8 goal depth: the new goal types (named gap, gap + trick, distinct tricks, gap chain, timed gaps, streak,
## distances), sessions (2:00 / 5:00 / free), the per-level data, the unlocks (shop items, special slots) and the saved
## session pick.

const LEVELS: Array[String] = ["practice", "warehouse", "beach", "school", "downtown", "hills"]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _goals(list: Array) -> Goals:
	var g: Goals = Goals.new()
	g.load_from_dict({"run_seconds": 120, "goals": list})
	g.start_run(0.0)
	return g


func _level_goals(id: String) -> Dictionary:
	var path: String = "res://data/goals.json" if id == "practice" else "res://game/levels/%s/goals.json" % id
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func _level_gap_ids(id: String) -> Array[String]:
	var path: String = "res://data/gaps.json" if id == "practice" else "res://game/levels/%s/gaps.json" % id
	var out: Array[String] = []
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	for gap: Variant in d["gaps"] as Array:
		out.append(str((gap as Dictionary)["id"]))
	return out


# --- new goal types ------------------------------------------------------------------------------------------------

func test_named_gap_completes_on_id_or_name() -> void:
	var g: Goals = _goals([
		{"id": "a", "title": "A", "type": "named_gap", "gap": "mega_gap"},
		{"id": "b", "title": "B", "type": "named_gap", "gap": "Loop De Loop"},
	])
	assert_eq(g.on_gap_event("other", "Other", 1.0).size(), 0)
	assert_eq(g.on_gap_event("mega_gap", "Mega Gap", 2.0).size(), 1)
	assert_true(g.is_completed("a"))
	assert_eq(g.on_gap_event("loop_de_loop", "Loop De Loop", 3.0).size(), 1, "the display name works too")


func test_gap_trick_needs_both_in_one_landed_combo() -> void:
	var g: Goals = _goals([{"id": "h", "title": "H", "type": "gap_trick", "gap": "hubba", "trick": "kickflip"}])
	g.on_gap_event("hubba", "Hubba", 1.0)
	assert_eq(g.on_combo_landed(500, 500, []).size(), 0, "the gap alone is not enough")
	g.on_trick("kickflip", "flip")
	g.on_gap_event("hubba", "Hubba", 5.0)
	assert_eq(g.on_combo_landed(900, 1400, []).size(), 1, "kickflip + hubba in one combo")


func test_gap_trick_by_kind_and_bail_clears_the_combo() -> void:
	var g: Goals = _goals([{"id": "h", "title": "H", "type": "gap_trick", "gap": "roof", "trick_kind": "grab"}])
	g.on_trick("indy", "grab")
	g.on_gap_event("roof", "Roof", 1.0)
	g.on_combo_bailed()
	assert_eq(g.on_combo_landed(300, 300, []).size(), 0, "a bailed combo counts for nothing")
	g.on_trick("melon", "grab")
	g.on_gap_event("roof", "Roof", 9.0)
	assert_eq(g.on_combo_landed(300, 600, []).size(), 1)


func test_combo_trick_needs_points_and_the_trick() -> void:
	var g: Goals = _goals([{"id": "c", "title": "C", "type": "combo_trick", "trick_kind": "grab", "target": 4000}])
	g.on_trick("kickflip", "flip")
	assert_eq(g.on_combo_landed(5000, 5000, []).size(), 0, "no grab in it")
	g.on_trick("indy", "grab")
	assert_eq(g.on_combo_landed(3000, 8000, []).size(), 0, "too few points")
	assert_near(g.progress("c"), 0.75, 0.001)
	g.on_trick("indy", "grab")
	assert_eq(g.on_combo_landed(4200, 12000, []).size(), 1)


func test_combo_distinct_counts_different_ids_only() -> void:
	var g: Goals = _goals([{"id": "d", "title": "D", "type": "combo_distinct", "target": 3}])
	for t: String in ["kickflip", "kickflip", "heelflip"]:
		g.on_trick(t, "flip")
	assert_eq(g.on_combo_landed(100, 100, []).size(), 0, "two different ids")
	for t: String in ["kickflip", "heelflip", "indy"]:
		g.on_trick(t, "flip")
	assert_eq(g.on_combo_landed(100, 200, []).size(), 1)


func test_gap_chain_counts_different_gaps_in_one_combo() -> void:
	var g: Goals = _goals([{"id": "c", "title": "C", "type": "gap_chain", "target": 3}])
	g.on_gap_event("a", "A", 1.0)
	g.on_gap_event("a", "A", 2.0)
	g.on_gap_event("b", "B", 3.0)
	assert_eq(g.on_combo_landed(100, 100, []).size(), 0, "a twice is one gap")
	g.on_gap_event("a", "A", 4.0)
	g.on_gap_event("b", "B", 5.0)
	g.on_gap_event("c", "C", 6.0)
	assert_eq(g.on_combo_landed(100, 200, []).size(), 1)


func test_timed_gaps_slide_over_the_window() -> void:
	var g: Goals = _goals([{"id": "t", "title": "T", "type": "timed_gaps", "target": 3, "seconds": 20}])
	g.on_gap_event("a", "A", 0.0)
	g.on_gap_event("b", "B", 12.0)
	assert_eq(g.on_gap_event("c", "C", 25.0).size(), 0, "a left the 20 s window")
	assert_eq(g.on_gap_event("d", "D", 30.0).size(), 1, "b, c, d inside 20 s")


func test_streak_breaks_on_a_bail() -> void:
	var g: Goals = _goals([{"id": "s", "title": "S", "type": "streak", "target": 3}])
	g.on_combo_landed(100, 100, [])
	g.on_combo_landed(100, 200, [])
	g.on_combo_bailed()
	assert_eq(g.on_combo_landed(100, 300, []).size(), 0, "the streak started over")
	g.on_combo_landed(100, 400, [])
	assert_eq(g.on_combo_landed(100, 500, []).size(), 1)


func test_distance_goals_follow_the_hold_kind() -> void:
	var g: Goals = _goals([
		{"id": "m", "title": "M", "type": "manual_distance", "target": 60},
		{"id": "r", "title": "R", "type": "grind_distance", "target": 30},
	])
	assert_eq(g.on_distance("manual", 59.0).size(), 0)
	assert_near(g.progress("m"), 59.0 / 60.0, 0.001)
	assert_eq(g.on_distance("grind", 31.0).size(), 1, "a grind does not feed the manual goal")
	assert_eq(g.on_distance("manual", 61.0).size(), 1)
	assert_eq(g.on_distance("slide", 99.0).size(), 0)


func test_new_types_reject_bad_entries() -> void:
	var g: Goals = Goals.new()
	g.load_from_dict({"goals": [
		{"id": "a", "title": "A", "type": "named_gap"},
		{"id": "b", "title": "B", "type": "gap_trick", "gap": "x"},
		{"id": "c", "title": "C", "type": "timed_gaps", "target": 3},
		{"id": "d", "title": "D", "type": "combo_trick", "target": 100},
		{"id": "e", "title": "E", "type": "streak", "target": 0},
	]})
	assert_eq(g.all_goals().size(), 0)
	assert_eq(g.load_errors.size(), 5)


# --- sessions ------------------------------------------------------------------------------------------------------

func test_five_minute_session_doubles_score_targets_and_titles() -> void:
	var g: Goals = Goals.load_default()
	g.set_session(300.0)
	assert_near(g.run_seconds, 300.0)
	var goal: Dictionary = g.get_goal("pro_score_30k")
	assert_near(float(goal["target"]), 60000.0)
	assert_true(str(goal["title"]).contains("60,000"), str(goal["title"]))
	assert_true(str(goal["description"]).contains("5-minute"), str(goal["description"]))
	g.set_session(120.0)
	assert_near(float(g.get_goal("pro_score_30k")["target"]), 30000.0, 0.001, "back to the file's own")
	assert_true(str(g.get_goal("pro_score_30k")["title"]).contains("30,000"))


func test_free_skate_has_no_clock_and_parks_score_goals() -> void:
	var g: Goals = Goals.load_default()
	g.set_session(0.0)
	g.start_run(0.0)
	g.tick(100000.0)
	assert_true(g.run_active(), "no clock ends a free run")
	assert_eq(g.run_time_left(5.0), 0.0)
	assert_false(g.is_active("high_score_10k"))
	assert_true(g.is_active("combo_champ_5k"))
	assert_eq(g.on_combo_landed(100, 99999, []).size(), 0 if not g.is_completed("combo_champ_5k") else 1)
	assert_false(g.is_completed("high_score_10k"), "a parked score goal never completes")
	assert_eq(g.on_combo_landed(6000, 105999, []).size(), 1, "a combo goal still does")


func test_session_modes() -> void:
	assert_eq(SessionMode.seconds("2min"), 120.0)
	assert_eq(SessionMode.seconds("5min"), 300.0)
	assert_eq(SessionMode.seconds("free"), 0.0)
	assert_eq(SessionMode.seconds("junk"), 120.0, "unknown falls back to the default")
	assert_eq(SessionMode.cycle("2min", 1), "5min")
	assert_eq(SessionMode.cycle("2min", -1), "free")
	assert_eq(SessionMode.cycle("free", 1), "2min")


func test_session_pick_is_saved_and_bad_values_reset() -> void:
	var s: ProgressStore = ProgressStore.new()
	s.session = "free"
	var t: ProgressStore = ProgressStore.new()
	t.from_dict(s.to_dict())
	assert_eq(t.session, "free")
	t.from_dict({"session": "forever"})
	assert_eq(t.session, "2min")
	t.from_dict({"levels": {}})  # a career saved before sessions existed
	assert_eq(t.session, "2min")
	assert_true(t.specials == null)


# --- level data ----------------------------------------------------------------------------------------------------

func test_every_level_has_two_signature_gap_goals_that_name_real_gaps() -> void:
	for id: String in LEVELS:
		var d: Dictionary = _level_goals(id)
		var gap_ids: Array[String] = _level_gap_ids(id)
		var signature: int = 0
		for e: Variant in d["goals"] as Array:
			var goal: Dictionary = e
			if goal["type"] in ["named_gap", "gap_trick"]:
				signature += 1
				assert_true(gap_ids.has(str(goal["gap"])), "%s: goal %s names gap %s that the level has" % [id, goal["id"], goal["gap"]])
		assert_true(signature >= 2, "%s has two signature gap goals, found %d" % [id, signature])


func test_every_level_loads_clean_with_a_mixtape() -> void:
	for id: String in LEVELS:
		var path: String = "res://data/goals.json" if id == "practice" else "res://game/levels/%s/goals.json" % id
		var g: Goals = Goals.new()
		assert_true(g.load_from_path(path))
		assert_true(g.load_errors.is_empty(), "%s: %s" % [id, str(g.load_errors)])
		assert_eq(g.pickups.size(), 3, "%s hides three tapes" % id)
		assert_true(g.get_goal("mixtape").has("items"), "%s has the mixtape goal" % id)
		assert_eq((g.get_goal("mixtape")["items"] as Array).size(), g.pickups.size(), "one tape per VHS in the goal")


func test_trick_goals_in_level_files_use_real_trick_ids_and_kinds() -> void:
	var db: TrickDB = TrickDB.load_default()
	for id: String in LEVELS:
		for e: Variant in _level_goals(id)["goals"] as Array:
			var goal: Dictionary = e
			if str(goal.get("trick", "")) != "":
				assert_false(db.get_trick(str(goal["trick"])).is_empty(), "%s: trick %s exists" % [id, goal["trick"]])
			if str(goal.get("trick_kind", "")) != "":
				assert_true(goal["trick_kind"] in ["flip", "grab", "grind", "manual", "lip", "special"], "%s kind" % id)


# --- unlocks -------------------------------------------------------------------------------------------------------

func test_unlock_data_names_real_items_and_specials() -> void:
	var cat: PartCatalog = PartCatalog.load_default()
	for id: String in Unlocks.item_ids():
		assert_true(cat.has_item(id), "catalog has %s" % id)
		assert_false(cat.is_starter(id), "%s is not a starter" % id)
		assert_true(Unlocks.item_goals(id) > 0, "%s needs goals" % id)
	var db: TrickDB = TrickDB.load_default()
	for e: Dictionary in Unlocks.special_entries():
		assert_eq(str(db.get_trick(str(e["id"])).get("kind", "")), "special", "%s is a special" % e["id"])
	assert_eq(Unlocks.unlocked_specials(0).size(), 2, "two specials from the start")
	assert_eq(Unlocks.special_slots(0), 2)
	assert_eq(Unlocks.special_slots(10), 3)
	assert_eq(Unlocks.special_slots(25), 4)


func test_locked_items_and_rewards() -> void:
	assert_true(Unlocks.item_locked("deck_oldschool", 0))
	assert_false(Unlocks.item_locked("deck_oldschool", 9))
	assert_eq(Unlocks.goals_missing("deck_oldschool", 5), 4)
	assert_false(Unlocks.item_locked("deck_popsicle", 0), "starters and unnamed items are open")
	assert_true(Unlocks.is_reward("acc_headband"))
	var w: Wallet = Wallet.new()
	assert_eq(Unlocks.sync_wallet(w, 1).size(), 0)
	var fresh: PackedStringArray = Unlocks.sync_wallet(w, 2)
	assert_eq(fresh, PackedStringArray(["acc_headband"]))
	assert_true(w.owns("acc_headband"))
	assert_eq(Unlocks.sync_wallet(w, 2).size(), 0, "granted once")
	assert_true(Unlocks.opened_between(1, 3).has("acc_headband"))
	assert_true(Unlocks.opened_between(1, 3).has("deck_cruiser"))
	assert_false(Unlocks.opened_between(3, 3).has("deck_cruiser"))


func test_equipped_specials_follow_slots_and_unlocks() -> void:
	var s: ProgressStore = ProgressStore.new()
	assert_eq(s.equipped_specials(), PackedStringArray(["rocket_launch", "pizza_spinner"]), "the defaults")
	assert_false(s.toggle_special("moonwalk"), "locked at 0 goals")
	assert_true(s.toggle_special("pizza_spinner"), "put one away")
	assert_eq(s.equipped_specials(), PackedStringArray(["rocket_launch"]))
	for i: int in 6:
		s.add_goal("practice", "g%d" % i)
	assert_true(s.toggle_special("moonwalk"), "open at 6 goals with a free slot")
	assert_eq(s.equipped_specials().size(), 2)
	assert_false(s.toggle_special("pizza_spinner"), "both slots are used")
	assert_false(s.toggle_special("gravity_defier"), "slots full and still locked")
	var t: ProgressStore = ProgressStore.new()
	t.from_dict(s.to_dict())
	assert_eq(t.equipped_specials(), s.equipped_specials(), "the pick survives a save")


func test_apply_specials_takes_the_rest_out_of_the_table() -> void:
	var db: TrickDB = TrickDB.load_default()
	var removed: int = Unlocks.apply_specials(db, PackedStringArray(["rocket_launch"]))
	assert_eq(removed, 3)
	assert_false(db.find_sequence(["S", "N"], "flip").is_empty(), "the equipped one still triggers")
	assert_true(db.find_sequence(["E", "W"], "grab").is_empty(), "an unequipped one cannot")
	assert_false(db.get_trick("pizza_spinner").is_empty(), "by id it is still known (goals, names)")


func test_old_wallet_and_progress_files_still_load() -> void:
	var w: Wallet = Wallet.from_dict({"coins": 50, "owned": ["deck_oldschool"]})
	assert_true(w.owns("deck_oldschool"), "an item bought before locks stays owned")
	var s: ProgressStore = ProgressStore.new()
	s.from_dict({"version": 1, "unlock_all": false, "levels": {"practice": {"best_score": 10, "goals": ["a"]}}, "tips": []})
	assert_eq(s.goals_done_count("practice"), 1)
	assert_eq(s.session, "2min")


# --- screens -------------------------------------------------------------------------------------------------------

func test_level_select_session_picker() -> void:
	var store: ProgressStore = ProgressStore.new()
	var ls: LevelSelect = LevelSelect.new()
	ls.store = store
	_tree().root.add_child(ls)
	assert_eq(ls._session_btns.size(), 3)
	(ls._session_btns["free"] as Button).pressed.emit()
	assert_eq(store.session, "free")
	(ls._session_btns["5min"] as Button).pressed.emit()
	assert_eq(store.session, "5min")
	ls.free()


func test_shop_locks_items_and_equips_specials() -> void:
	var store: ProgressStore = ProgressStore.new()
	var wallet: Wallet = Wallet.new()
	wallet.coins = 500
	var shop: SkateShop = SkateShop.new().setup(wallet, SkaterLoadout.new(), false, store)
	_tree().root.add_child(shop)
	shop.set_category(0)  # decks: Retro Wide needs 9 goals
	var retro: int = -1
	for i: int in shop._items.size():
		if str(shop._items[i]["id"]) == "deck_oldschool":
			retro = i
	assert_true(retro >= 0)
	shop._selected = retro
	shop._activate()
	assert_false(wallet.owns("deck_oldschool"), "locked: coins cannot buy it")
	assert_eq(wallet.coins, 500)
	for i: int in 9:
		store.add_goal("practice", "g%d" % i)
	shop._activate()
	assert_true(wallet.owns("deck_oldschool"), "open at 9 goals")
	shop.set_category(shop._cat.categories.size())  # the special tricks tab
	assert_eq(shop._special_ids.size(), 4)
	shop._selected = 2  # moonwalk, open at 6 goals but both slots are taken
	shop._activate()
	assert_false(store.equipped_specials().has("moonwalk"), "slots are full")
	shop._selected = 0
	shop._activate()
	shop._selected = 2
	shop._activate()
	assert_true(store.equipped_specials().has("moonwalk"))
	shop.free()


# --- hidden pickups in the real levels ------------------------------------------------------------------------------

func test_every_level_places_its_three_tapes_over_real_zones() -> void:
	for id: String in LEVELS:
		var level: Level = LevelRegistry.create(id)
		_tree().root.add_child(level)
		var g: Goals = Goals.new()
		g.load_from_path("res://data/goals.json" if id == "practice" else "res://game/levels/%s/goals.json" % id)
		var tapes: Array[Collectible] = GoalPickup.spawn(_tree(), level, g.pickups)
		assert_eq(tapes.size(), 3, "%s: every tape finds its zone" % id)
		for t: Collectible in tapes:
			assert_eq(t.item, "VHS")
			assert_true(t.global_position.y > level.kill_y, "%s: a tape above the kill height" % id)
		level.free()


func test_goal_list_puts_goals_in_progress_first() -> void:
	var all: Array[Dictionary] = [{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}]
	var prog: Dictionary = {"a": 0.0, "b": 0.0, "c": 0.4, "d": 0.8}
	var out: Array[Dictionary] = GoalsPanel.pick_goals(all, PackedStringArray(), func(id: String) -> float: return float(prog[id]), 3)
	assert_eq(str(out[0]["id"]), "d", "closest to done first")
	assert_eq(str(out[1]["id"]), "c")
	assert_eq(str(out[2]["id"]), "a", "then data order")
	var done_out: Array[Dictionary] = GoalsPanel.pick_goals(all, PackedStringArray(["d"]), func(id: String) -> float: return float(prog[id]), 2)
	assert_eq(str(done_out[0]["id"]), "c", "finished goals drop out")
