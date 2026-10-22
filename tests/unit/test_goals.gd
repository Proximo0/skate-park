extends TestCase


func _goals_from(list: Array, run_seconds: float = 120.0) -> Goals:
	var g: Goals = Goals.new()
	g.load_from_dict({"run_seconds": run_seconds, "goals": list})
	return g


func _sample() -> Goals:
	return _goals_from([
		{"id": "hs", "title": "High", "type": "high_score", "target": 1000},
		{"id": "cb", "title": "Combo", "type": "combo", "target": 500},
		{"id": "col", "title": "Collect", "type": "collect", "items": ["S", "K"]},
		{"id": "pz", "title": "Pizza", "type": "collect", "items": ["pizza", "pizza", "pizza"]},
		{"id": "gp", "title": "Gaps", "type": "gaps", "target": 3},
		{"id": "kf", "title": "KF", "type": "trick", "trick": "kickflip"},
		{"id": "sp", "title": "Special", "type": "special", "target": 1},
		{"id": "man", "title": "Manual", "type": "manual_time", "target": 5},
		{"id": "grd", "title": "Grind", "type": "grind_time", "target": 3},
	])


func _ids(done: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = []
	for g: Dictionary in done:
		out.append(g["id"])
	return out


# --- loading -----------------------------------------------------------------

func test_default_file_has_the_big_park_goals() -> void:
	var g: Goals = Goals.load_default()
	for id: String in ["loop_de_loop", "mega_gap", "dome_air", "long_haul_4"]:
		assert_true(g.progress(id) == 0.0 and not g.is_completed(id), "goal %s exists and is fresh" % id)
	g.start_run(0.0)
	assert_eq(g.on_collect("L").size(), 1, "the L coin completes Loop De Loop")
	g.on_hold("grind", 4.5)
	assert_true(g.is_completed("long_haul_4"), "a 4.5 second grind completes Long Haul")


func test_default_file_loads_valid_goals() -> void:
	var g: Goals = Goals.load_default()
	assert_true(g.load_errors.is_empty(), "no load errors: %s" % str(g.load_errors))
	var all: Array[Dictionary] = g.all_goals()
	assert_eq(all.size(), 24, "twenty four goals")
	assert_near(g.run_seconds, 120.0, 0.0001, "2-minute run")
	var seen: Dictionary = {}
	for goal: Dictionary in all:
		var id: String = goal["id"]
		assert_false(seen.has(id), "unique id %s" % id)
		seen[id] = true
		assert_true(Goals.TYPES.has(goal["type"]), "known type for %s" % id)
		assert_false(goal["title"] == "", "title for %s" % id)
		assert_false(goal["description"] == "", "description for %s" % id)
		assert_true(float(goal["target"]) > 0.0, "target > 0 for %s" % id)
		assert_eq(g.progress(id), 0.0, "fresh progress for %s" % id)
		assert_false(g.is_completed(id))


func test_default_trick_goals_reference_real_tricks() -> void:
	var g: Goals = Goals.load_default()
	var db: TrickDB = TrickDB.load_default()
	var checked: int = 0
	for goal: Dictionary in g.all_goals():
		if goal["type"] != "trick":
			continue
		checked += 1
		var id: String = goal["trick"]
		assert_false(db.get_trick(id).is_empty(), "trick '%s' exists in data/tricks.json" % id)
	assert_true(checked > 0, "at least one trick goal")


func test_default_collect_goals_have_expected_items() -> void:
	var g: Goals = Goals.load_default()
	var skate: Dictionary = g.get_goal("collect_skate")
	assert_eq(skate["items"], ["S", "K", "A", "T", "E"])
	assert_near(float(skate["target"]), 5.0, 0.0001)
	var pizza: Dictionary = g.get_goal("collect_pizza")
	assert_eq(pizza["items"].size(), 5)
	assert_near(float(pizza["target"]), 5.0, 0.0001)


func test_invalid_entries_are_skipped_with_errors() -> void:
	var g: Goals = _goals_from([
		{"title": "No id", "type": "combo", "target": 1},
		{"id": "a", "type": "combo", "target": 1},
		{"id": "b", "title": "Bad type", "type": "bogus", "target": 1},
		{"id": "c", "title": "Zero", "type": "combo", "target": 0},
		{"id": "d", "title": "Text target", "type": "gaps", "target": "5"},
		{"id": "e", "title": "Empty items", "type": "collect", "items": []},
		{"id": "f", "title": "Bad item", "type": "collect", "items": ["S", 3]},
		{"id": "g", "title": "No trick", "type": "trick"},
		{"id": "h", "title": "Dup", "type": "special"},
		{"id": "h", "title": "Dup again", "type": "special"},
		"not an object",
		{"id": "ok", "title": "Fine", "type": "combo", "target": 10},
	])
	assert_eq(g.all_goals().size(), 2, "only h and ok survive")
	assert_eq(g.load_errors.size(), 10, "one error per bad entry")
	assert_true(g.get_goal("ok").size() > 0)
	assert_true(g.get_goal("a").is_empty(), "entry a had no title")


func test_missing_goals_array_fails() -> void:
	var g: Goals = Goals.new()
	assert_false(g.load_from_dict({"run_seconds": 60}), "no goals key")
	assert_eq(g.all_goals().size(), 0)


func test_run_seconds_defaults_and_overrides() -> void:
	var g: Goals = _goals_from([], 45.0)
	assert_near(g.run_seconds, 45.0, 0.0001)
	var h: Goals = Goals.new()
	h.load_from_dict({"goals": []})
	assert_near(h.run_seconds, 120.0, 0.0001, "default 2 minutes")
	var bad: Goals = Goals.new()
	bad.load_from_dict({"run_seconds": -3, "goals": []})
	assert_near(bad.run_seconds, 120.0, 0.0001, "non-positive falls back")


func test_load_from_missing_path_fails() -> void:
	var g: Goals = Goals.new()
	assert_false(g.load_from_path("res://data/does_not_exist.json"))


func test_collect_target_is_item_count() -> void:
	var g: Goals = _sample()
	assert_near(float(g.get_goal("pz")["target"]), 3.0, 0.0001)


# --- combo -------------------------------------------------------------------

func test_combo_completes_at_target_once() -> void:
	var g: Goals = _sample()
	assert_eq(g.on_combo_landed(499, 499, []).size(), 0, "below target")
	assert_near(g.progress("cb"), 0.998, 0.001)
	var done: Array[Dictionary] = g.on_combo_landed(500, 999, [])
	assert_eq(_ids(done), ["cb"] as PackedStringArray, "exactly at target completes")
	assert_true(g.is_completed("cb"))
	assert_near(g.progress("cb"), 1.0, 0.0001)
	assert_eq(g.on_combo_landed(900, 1900, []).size(), 0, "second combo does not complete again")


func test_combo_progress_is_best_seen() -> void:
	var g: Goals = _sample()
	g.on_combo_landed(200, 200, [])
	g.on_combo_landed(100, 300, [])
	assert_near(g.progress("cb"), 0.4, 0.0001, "best combo 200 of 500")


# --- high score and run timer -----------------------------------------------

func test_high_score_needs_an_active_run() -> void:
	var g: Goals = _sample()
	assert_eq(g.on_combo_landed(0, 5000, []).size(), 0, "no run started")
	assert_eq(g.progress("hs"), 0.0)
	g.start_run(10.0)
	assert_true(g.run_active())
	var done: Array[Dictionary] = g.on_combo_landed(0, 1000, [])
	assert_eq(_ids(done), ["hs"] as PackedStringArray, "landed_total reaches target in run")


func test_high_score_progress_within_run() -> void:
	var g: Goals = _sample()
	g.start_run(0.0)
	g.on_combo_landed(100, 250, [])
	assert_near(g.progress("hs"), 0.25, 0.0001)
	g.on_combo_landed(100, 200, [])
	assert_near(g.progress("hs"), 0.25, 0.0001, "progress never drops")


func test_run_time_left_counts_down_and_stops() -> void:
	var g: Goals = _sample()
	assert_near(g.run_time_left(0.0), 0.0, 0.0001, "no run, no time")
	g.start_run(100.0)
	assert_near(g.run_time_left(100.0), 120.0, 0.0001)
	assert_near(g.run_time_left(130.0), 90.0, 0.0001)
	assert_near(g.run_time_left(400.0), 0.0, 0.0001, "clamped at zero")


func test_run_ends_on_tick_after_two_minutes() -> void:
	var g: Goals = _sample()
	g.start_run(0.0)
	g.tick(119.9)
	assert_true(g.run_active(), "still running at 119.9s")
	g.tick(120.0)
	assert_false(g.run_active(), "over at 120s")
	assert_eq(g.on_combo_landed(0, 5000, []).size(), 0, "landing after the run does not count")
	assert_false(g.is_completed("hs"))


func test_landing_in_time_counts_when_tick_is_on_time() -> void:
	var g: Goals = _sample()
	g.start_run(0.0)
	g.tick(119.0)
	var done: Array[Dictionary] = g.on_combo_landed(0, 1000, [])
	assert_eq(_ids(done), ["hs"] as PackedStringArray, "landing at 119s counts")


func test_second_run_can_complete_a_goal_the_first_missed() -> void:
	var g: Goals = _sample()
	g.start_run(0.0)
	g.on_combo_landed(0, 300, [])
	g.tick(200.0)
	assert_false(g.run_active())
	g.start_run(200.0)
	assert_near(g.run_time_left(200.0), 120.0, 0.0001)
	var done: Array[Dictionary] = g.on_combo_landed(0, 1000, [])
	assert_eq(_ids(done), ["hs"] as PackedStringArray)


func test_end_run_stops_scoring() -> void:
	var g: Goals = _sample()
	g.start_run(0.0)
	g.end_run()
	assert_eq(g.on_combo_landed(0, 9999, []).size(), 0)
	assert_near(g.run_time_left(1.0), 0.0, 0.0001)


# --- collect -----------------------------------------------------------------

func test_collect_word_completes_when_all_letters_seen() -> void:
	var g: Goals = _sample()
	assert_eq(g.on_collect("S").size(), 0)
	assert_near(g.progress("col"), 0.5, 0.0001)
	assert_eq(g.on_collect("S").size(), 0, "duplicate letter does not count twice")
	assert_near(g.progress("col"), 0.5, 0.0001)
	assert_eq(g.on_collect("X").size(), 0, "letter not in the word")
	var done: Array[Dictionary] = g.on_collect("K")
	assert_eq(_ids(done), ["col"] as PackedStringArray)
	assert_true(g.is_completed("col"))
	assert_eq(g.on_collect("K").size(), 0, "no second completion")


func test_collect_is_case_sensitive() -> void:
	var g: Goals = _sample()
	g.on_collect("s")
	assert_near(g.progress("col"), 0.0, 0.0001, "lowercase s is not S")


func test_collect_duplicates_count_for_repeated_items() -> void:
	var g: Goals = _sample()
	g.on_collect("pizza")
	g.on_collect("pizza")
	assert_near(g.progress("pz"), 2.0 / 3.0, 0.0001)
	assert_false(g.is_completed("pz"))
	g.on_collect("pizza")
	assert_true(g.is_completed("pz"))
	assert_eq(g.on_collect("pizza").size(), 0, "extra pizza after completion is nothing")


func test_collect_ignores_extra_pickups_beyond_need() -> void:
	var g: Goals = _goals_from([{"id": "p", "title": "P", "type": "collect", "items": ["pizza", "pizza"]}])
	g.on_collect("pizza")
	g.on_collect("pizza")
	g.on_collect("pizza")
	assert_near(g.progress("p"), 1.0, 0.0001)
	assert_true(g.is_completed("p"))


func test_default_skate_goal_completes_via_collect_sequence() -> void:
	var g: Goals = Goals.load_default()
	var done: Array[Dictionary] = []
	for letter: String in ["S", "K", "A", "T", "E"]:
		done.append_array(g.on_collect(letter))
	assert_eq(_ids(done), ["collect_skate"] as PackedStringArray)


# --- gaps --------------------------------------------------------------------

func test_gaps_use_running_total() -> void:
	var g: Goals = _sample()
	assert_eq(g.on_gap_discovered(1).size(), 0)
	assert_near(g.progress("gp"), 1.0 / 3.0, 0.0001)
	assert_eq(g.on_gap_discovered(2).size(), 0)
	var done: Array[Dictionary] = g.on_gap_discovered(3)
	assert_eq(_ids(done), ["gp"] as PackedStringArray)
	assert_eq(g.on_gap_discovered(4).size(), 0, "no repeat completion")


func test_gap_count_can_jump_past_target() -> void:
	var g: Goals = _sample()
	var done: Array[Dictionary] = g.on_gap_discovered(10)
	assert_eq(_ids(done), ["gp"] as PackedStringArray)
	assert_near(g.progress("gp"), 1.0, 0.0001)


# --- holds -------------------------------------------------------------------

func test_manual_hold_needs_target_seconds() -> void:
	var g: Goals = _sample()
	assert_eq(g.on_hold("manual", 4.9).size(), 0)
	assert_near(g.progress("man"), 0.98, 0.001)
	var done: Array[Dictionary] = g.on_hold("manual", 5.0)
	assert_eq(_ids(done), ["man"] as PackedStringArray)


func test_grind_hold_does_not_complete_manual_goal() -> void:
	var g: Goals = _sample()
	var done: Array[Dictionary] = g.on_hold("grind", 10.0)
	assert_eq(_ids(done), ["grd"] as PackedStringArray, "grind goal only")
	assert_false(g.is_completed("man"), "manual goal untouched by grind")
	assert_eq(g.on_hold("manual", 2.0).size(), 0, "manual goal still needs 5s")


func test_unknown_hold_kind_is_ignored() -> void:
	var g: Goals = _sample()
	assert_eq(g.on_hold("lip", 99.0).size(), 0)
	assert_eq(g.on_hold("", 99.0).size(), 0)
	assert_eq(g.progress("man"), 0.0)


# --- tricks and specials -----------------------------------------------------

func test_trick_goal_matches_id_only() -> void:
	var g: Goals = _sample()
	assert_eq(g.on_trick("heelflip", "flip").size(), 0)
	var done: Array[Dictionary] = g.on_trick("kickflip", "flip")
	assert_eq(_ids(done), ["kf"] as PackedStringArray)
	assert_eq(g.on_trick("kickflip", "flip").size(), 0, "no repeat completion")


func test_special_goal_matches_kind_special() -> void:
	var g: Goals = _sample()
	assert_eq(g.on_trick("kickflip", "flip").size(), 1, "kickflip completes the trick goal")
	assert_eq(g.on_trick("moonwalk", "grab").size(), 0, "a non-special trick does not complete special")
	var done: Array[Dictionary] = g.on_trick("moonwalk", "special")
	assert_eq(_ids(done), ["sp"] as PackedStringArray)
	assert_eq(g.on_trick("gravity_defier", "special").size(), 0)


func test_special_goal_is_not_completed_by_trick_id_alone() -> void:
	var g: Goals = _sample()
	assert_eq(g.on_trick("pizza_spinner", "").size(), 0)
	assert_false(g.is_completed("sp"))


func test_combo_tricks_list_completes_trick_goals() -> void:
	var g: Goals = _sample()
	var done: Array[Dictionary] = g.on_combo_landed(100, 100, ["varial_heelflip", "kickflip"])
	assert_eq(_ids(done), ["kf"] as PackedStringArray, "string entries")
	done = g.on_combo_landed(100, 200, [{"id": "rocket_launch", "kind": "special"}])
	assert_eq(_ids(done), ["sp"] as PackedStringArray, "dictionary entry with kind special")


func test_combo_tricks_list_dictionary_trick_id() -> void:
	var g: Goals = _sample()
	var done: Array[Dictionary] = g.on_combo_landed(0, 0, [{"id": "kickflip", "kind": "flip"}])
	assert_eq(_ids(done), ["kf"] as PackedStringArray)


func test_combo_completes_combo_and_trick_goals_together() -> void:
	var g: Goals = _sample()
	var done: Array[Dictionary] = g.on_combo_landed(600, 600, ["kickflip"])
	var ids: PackedStringArray = _ids(done)
	assert_true(ids.has("cb"), "combo goal completed")
	assert_true(ids.has("kf"), "trick goal completed")
	assert_eq(ids.size(), 2)


# --- signals, bookkeeping ----------------------------------------------------

func test_goal_completed_signal_fires_once_per_goal() -> void:
	var g: Goals = _sample()
	var seen: Array[String] = []
	g.goal_completed.connect(func(goal: Dictionary) -> void: seen.append(goal["id"]))
	g.on_gap_discovered(3)
	g.on_gap_discovered(4)
	g.on_collect("S")
	g.on_collect("K")
	g.on_collect("K")
	assert_eq(seen.size(), 2, "gaps and collect each once")
	assert_eq(seen[0], "gp")
	assert_eq(seen[1], "col")


func test_signal_payload_is_a_copy_of_the_goal() -> void:
	var g: Goals = _sample()
	var got: Array[Dictionary] = []
	g.goal_completed.connect(func(goal: Dictionary) -> void: got.append(goal))
	g.on_trick("kickflip", "flip")
	assert_eq(got.size(), 1)
	assert_eq(got[0]["title"], "KF")
	got[0]["title"] = "tampered"
	assert_eq(g.get_goal("kf")["title"], "KF", "mutating payload does not change goal")


func test_returned_goals_are_copies() -> void:
	var g: Goals = _sample()
	var done: Array[Dictionary] = g.on_gap_discovered(3)
	done[0]["id"] = "changed"
	assert_true(g.is_completed("gp"), "original state untouched")


func test_completed_ids_in_file_order() -> void:
	var g: Goals = _sample()
	g.on_trick("kickflip", "flip")
	g.on_gap_discovered(3)
	assert_eq(g.completed_ids(), PackedStringArray(["gp", "kf"]))


func test_unknown_id_is_safe() -> void:
	var g: Goals = _sample()
	assert_eq(g.progress("nope"), 0.0)
	assert_false(g.is_completed("nope"))
	assert_true(g.get_goal("nope").is_empty())


func test_reset_clears_progress_and_run() -> void:
	var g: Goals = _sample()
	g.start_run(0.0)
	g.on_combo_landed(600, 1200, ["kickflip"])
	g.on_collect("S")
	g.reset()
	assert_false(g.is_completed("cb"))
	assert_false(g.is_completed("hs"))
	assert_false(g.is_completed("kf"))
	assert_eq(g.progress("col"), 0.0)
	assert_eq(g.completed_ids().size(), 0)
	assert_false(g.run_active(), "reset ends the run")
	g.on_collect("S")
	g.on_collect("K")
	assert_true(g.is_completed("col"), "collect works again after reset")
	var done: Array[Dictionary] = g.on_collect("A")
	assert_eq(done.size(), 0)


func test_all_goal_types_complete_once_in_default_set() -> void:
	var g: Goals = Goals.load_default()
	var done_total: int = 0
	done_total += g.on_combo_landed(75000, 75000, []).size()
	g.start_run(0.0)
	done_total += g.on_combo_landed(0, 75000, []).size()
	for letter: String in ["S", "K", "A", "T", "E"]:
		done_total += g.on_collect(letter).size()
	for i: int in 5:
		done_total += g.on_collect("pizza").size()
	done_total += g.on_gap_discovered(5).size()
	done_total += g.on_trick("kickflip", "flip").size()
	done_total += g.on_trick("heelflip", "flip").size()
	done_total += g.on_trick("moonwalk", "special").size()
	done_total += g.on_hold("manual", 5.0).size()
	done_total += g.on_hold("grind", 3.0).size()
	assert_eq(g.completed_ids().size(), 12, "every classic default goal done")
	assert_eq(done_total, 12, "each completion reported once")
