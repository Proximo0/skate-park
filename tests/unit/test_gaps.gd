extends TestCase


func _gaps_test_make(entries: Array) -> Gaps:
	var g: Gaps = Gaps.new()
	g.load_from_dict({"gaps": entries})
	return g


func _gaps_test_gap(id: String, start: String, end: String, required: String, max_time: float) -> Dictionary:
	return {
		"id": id,
		"name": id,
		"points": 100,
		"start_zone": start,
		"end_zone": end,
		"require": required,
		"max_time": max_time,
	}


func test_completes_when_start_then_end_within_window() -> void:
	var g: Gaps = _gaps_test_make([_gaps_test_gap("g1", "a", "b", "", 2.0)])
	assert_eq(g.enter_zone("a", "AIR", 0.0).size(), 0, "start entry completes nothing")
	var done: Array = g.enter_zone("b", "AIR", 1.5)
	assert_eq(done.size(), 1)
	if done.size() == 1:
		var first: Dictionary = done[0]
		assert_eq(first["id"], "g1")
		assert_eq(first["points"], 100)


func test_end_without_start_completes_nothing() -> void:
	var g: Gaps = _gaps_test_make([_gaps_test_gap("g1", "a", "b", "", 2.0)])
	assert_eq(g.enter_zone("b", "AIR", 0.0).size(), 0)
	assert_eq(g.enter_zone("a", "AIR", 0.5).size(), 0, "end entered before start does not count")


func test_expires_after_max_time() -> void:
	var g: Gaps = _gaps_test_make([_gaps_test_gap("g1", "a", "b", "", 2.0)])
	g.enter_zone("a", "AIR", 0.0)
	assert_eq(g.enter_zone("b", "AIR", 2.01).size(), 0, "just past max_time")


func test_window_edge_is_inclusive() -> void:
	var g: Gaps = _gaps_test_make([_gaps_test_gap("g1", "a", "b", "", 2.0)])
	g.enter_zone("a", "AIR", 0.0)
	assert_eq(g.enter_zone("b", "AIR", 2.0).size(), 1, "exactly max_time still counts")


func test_latest_start_is_the_one_timed() -> void:
	var g: Gaps = _gaps_test_make([_gaps_test_gap("g1", "a", "b", "", 2.5)])
	g.enter_zone("a", "AIR", 0.0)
	g.enter_zone("a", "AIR", 2.0)
	assert_eq(g.enter_zone("b", "AIR", 4.0).size(), 1, "window runs from the second start")


func test_require_must_match_at_start_and_end() -> void:
	var start_wrong: Gaps = _gaps_test_make([_gaps_test_gap("g1", "a", "b", "AIR", 2.0)])
	start_wrong.enter_zone("a", "GRIND", 0.0)
	assert_eq(start_wrong.enter_zone("b", "AIR", 1.0).size(), 0, "start state GRIND, require AIR")

	var end_wrong: Gaps = _gaps_test_make([_gaps_test_gap("g1", "a", "b", "AIR", 2.0)])
	end_wrong.enter_zone("a", "AIR", 0.0)
	assert_eq(end_wrong.enter_zone("b", "GRIND", 1.0).size(), 0, "end state GRIND, require AIR")

	var both_right: Gaps = _gaps_test_make([_gaps_test_gap("g1", "a", "b", "AIR", 2.0)])
	both_right.enter_zone("a", "AIR", 0.0)
	assert_eq(both_right.enter_zone("b", "AIR", 1.0).size(), 1)


func test_empty_require_accepts_any_state() -> void:
	var g: Gaps = _gaps_test_make([_gaps_test_gap("g1", "a", "b", "", 2.0)])
	g.enter_zone("a", "WALLRIDE", 0.0)
	assert_eq(g.enter_zone("b", "MANUAL", 1.0).size(), 1)


func test_reset_combo_clears_pending() -> void:
	var g: Gaps = _gaps_test_make([_gaps_test_gap("g1", "a", "b", "", 2.0)])
	g.enter_zone("a", "AIR", 0.0)
	g.reset_combo()
	assert_eq(g.enter_zone("b", "AIR", 1.0).size(), 0, "start was cleared by reset")


func test_completed_start_is_consumed() -> void:
	var g: Gaps = _gaps_test_make([_gaps_test_gap("g1", "a", "b", "", 2.0)])
	g.enter_zone("a", "AIR", 0.0)
	assert_eq(g.enter_zone("b", "AIR", 1.0).size(), 1)
	assert_eq(g.enter_zone("b", "AIR", 1.2).size(), 0, "same start cannot complete twice")


func test_zone_shared_by_start_and_end_does_not_self_complete() -> void:
	var g: Gaps = _gaps_test_make([_gaps_test_gap("loop", "a", "a", "", 2.0)])
	assert_eq(g.enter_zone("a", "AIR", 0.0).size(), 0)
	assert_eq(g.enter_zone("a", "AIR", 1.0).size(), 1, "second entry completes against the first")


func test_discovery_tracks_first_completion() -> void:
	var g: Gaps = _gaps_test_make([_gaps_test_gap("g1", "a", "b", "", 2.0)])
	var got: Array = []
	g.gap_completed.connect(func(_gap: Dictionary, first: bool) -> void: got.append(first))
	assert_eq(g.discovered_count(), 0)
	g.enter_zone("a", "AIR", 0.0)
	g.enter_zone("b", "AIR", 1.0)
	g.enter_zone("a", "AIR", 5.0)
	g.enter_zone("b", "AIR", 6.0)
	assert_eq(got, [true, false], "first_time only on the first completion")
	assert_true(g.discovered.has("g1"))
	assert_eq(g.discovered_count(), 1)


func test_discovery_survives_reset_combo() -> void:
	var g: Gaps = _gaps_test_make([_gaps_test_gap("g1", "a", "b", "", 2.0)])
	g.enter_zone("a", "AIR", 0.0)
	g.enter_zone("b", "AIR", 1.0)
	g.reset_combo()
	assert_eq(g.discovered_count(), 1)


func test_counts() -> void:
	var g: Gaps = _gaps_test_make([
		_gaps_test_gap("g1", "a", "b", "", 2.0),
		_gaps_test_gap("g2", "c", "d", "", 2.0),
	])
	assert_eq(g.total_count(), 2)
	assert_eq(g.discovered_count(), 0)


func test_malformed_entries_are_skipped() -> void:
	var bad_require: Dictionary = _gaps_test_gap("bad", "a", "b", "FLYING", 2.0)
	var no_end: Dictionary = _gaps_test_gap("no_end", "a", "", "", 2.0)
	var good: Dictionary = _gaps_test_gap("good", "x", "y", "", 2.0)
	var g: Gaps = _gaps_test_make([bad_require, no_end, good])
	assert_eq(g.total_count(), 1)
	assert_eq(g.enter_zone("a", "AIR", 0.0).size(), 0, "bad entry never registers")
	assert_eq(g.enter_zone("x", "AIR", 0.0).size(), 0)
	assert_eq(g.enter_zone("y", "AIR", 1.0).size(), 1)


func test_load_from_dict_without_gaps_key_is_empty() -> void:
	var g: Gaps = Gaps.new()
	g.load_from_dict({})
	assert_eq(g.total_count(), 0)


func test_load_default_reads_real_json() -> void:
	var g: Gaps = Gaps.load_default()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Gaps.DATA_PATH))
	assert_true(typeof(parsed) == TYPE_DICTIONARY, "data/gaps.json parses")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var root: Dictionary = parsed
	var raw: Array = root["gaps"]
	assert_eq(g.total_count(), raw.size(), "every entry in the file loads")
	assert_true(g.total_count() >= 12, "about 12 example gaps")
	var completed: Array = g.enter_zone("funbox_a", "AIR", 0.0)
	assert_eq(completed.size(), 0)
	completed = g.enter_zone("funbox_b", "AIR", 1.0)
	assert_eq(completed.size(), 1, "Over The Funbox completes")
	if completed.size() == 1:
		var first: Dictionary = completed[0]
		assert_eq(first["id"], "over_the_funbox")
		assert_eq(first["points"], 300)
		assert_eq(first["name"], "Over The Funbox")


func test_start_in_zone_lets_a_landing_into_the_required_state_start_a_gap() -> void:
	var g: Gaps = _gaps_test_make([_gaps_test_gap("m", "a", "b", "MANUAL", 5.0)])
	g.enter_zone("a", "AIR", 0.0)
	assert_eq(g.enter_zone("b", "MANUAL", 1.0).size(), 0, "an AIR entry cannot start a manual gap")
	g.enter_zone("a", "AIR", 2.0)
	g.start_in_zone("a", "MANUAL", 2.1)
	assert_eq(g.enter_zone("b", "MANUAL", 3.0).size(), 1, "landing into a manual inside the start zone counts")


func test_start_in_zone_ignores_other_states_and_never_completes() -> void:
	var g: Gaps = _gaps_test_make([_gaps_test_gap("m", "a", "a", "MANUAL", 5.0)])
	g.start_in_zone("a", "GRIND", 0.0)
	assert_eq(g._pending.size(), 0, "wrong state registers nothing")
	g.start_in_zone("a", "MANUAL", 0.0)
	assert_eq(g._pending.size(), 1, "the matching state registers a start")
