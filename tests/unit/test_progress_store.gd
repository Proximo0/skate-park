extends TestCase
## ProgressStore: records, round trip through a file, corrupt files, stars, gating, tips; Goals.mark_done.

const TMP: String = "user://test_progress.json"


func _cleanup() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func test_record_run_flags_new_bests_and_goals() -> void:
	var s: ProgressStore = ProgressStore.new()
	var r: Dictionary = s.record_run("practice", 5000, 1200, PackedStringArray(["a", "b"]))
	assert_true(r["score"] and r["combo"], "first run is a record")
	assert_eq((r["goals"] as PackedStringArray).size(), 2)
	var r2: Dictionary = s.record_run("practice", 4000, 1500, PackedStringArray(["b", "c"]))
	assert_false(r2["score"], "lower score is no record")
	assert_true(r2["combo"])
	assert_eq((r2["goals"] as PackedStringArray).size(), 1, "only c is new")
	assert_eq(s.best_score("practice"), 5000)
	assert_eq(s.goals_done_count("practice"), 3)
	assert_eq(s.runs("practice"), 2)
	var z: Dictionary = s.record_run("beach", 0, 0, PackedStringArray())
	assert_false(z["score"] or z["combo"], "zero is never a record")


func test_save_and_load_round_trip() -> void:
	_cleanup()
	var s: ProgressStore = ProgressStore.new()
	s.path = TMP
	s.record_run("warehouse", 9100, 2200, PackedStringArray(["g1"]))
	s.mark_tip("nollie")
	s.unlock_all = true
	assert_true(s.save())
	var t: ProgressStore = ProgressStore.load_file(TMP)
	assert_eq(t.best_score("warehouse"), 9100)
	assert_eq(t.best_combo("warehouse"), 2200)
	assert_eq(t.goals_done("warehouse"), PackedStringArray(["g1"]))
	assert_true(t.tip_seen("nollie"))
	assert_false(t.tip_seen("boneless"))
	assert_true(t.unlock_all)
	_cleanup()


func test_missing_and_corrupt_files_give_a_fresh_career() -> void:
	_cleanup()
	assert_eq(ProgressStore.load_file(TMP).total_goals_done(), 0)
	var f: FileAccess = FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string("{not json at all")
	f.close()
	assert_eq(ProgressStore.load_file(TMP).best_score("practice"), 0)
	f = FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string('{"levels": {"practice": {"best_score": "x", "goals": 5}, "beach": 3}, "tips": 7, "unlock_all": "yes"}')
	f.close()
	var s: ProgressStore = ProgressStore.load_file(TMP)
	assert_eq(s.best_score("practice"), 0)
	assert_eq(s.goals_done_count("practice"), 0)
	assert_false(s.unlock_all)
	_cleanup()


func test_stars() -> void:
	assert_eq(ProgressStore.stars_for(0, 12), 0)
	assert_eq(ProgressStore.stars_for(1, 12), 1)
	assert_eq(ProgressStore.stars_for(6, 12), 2)
	assert_eq(ProgressStore.stars_for(12, 12), 3)


func test_goal_totals_come_from_the_level_files() -> void:
	assert_true(ProgressStore.goal_total("warehouse") > 0)
	assert_true(ProgressStore.goal_total("practice") > 0, "practice uses data/goals.json")


func test_gating_opens_with_goals_and_the_toggle() -> void:
	var s: ProgressStore = ProgressStore.new()
	assert_true(s.is_unlocked("practice"))
	assert_true(s.is_unlocked("warehouse"))
	assert_false(s.is_unlocked("beach"))
	assert_eq(s.goals_to_unlock("beach"), int(ProgressStore.UNLOCK_AT["beach"]))
	for i: int in int(ProgressStore.UNLOCK_AT["beach"]):
		s.add_goal("practice", "g%d" % i)
	assert_true(s.is_unlocked("beach"))
	assert_false(s.is_unlocked("hills"))
	s.unlock_all = true
	assert_true(s.is_unlocked("hills"))


func test_goals_mark_done_is_silent() -> void:
	var g: Goals = Goals.load_default()
	var first: String = str(g.all_goals()[0]["id"])
	var fired: Array = []
	g.goal_completed.connect(func(goal: Dictionary) -> void: fired.append(goal))
	g.mark_done(PackedStringArray([first, "nope"]))
	assert_true(g.is_completed(first))
	assert_eq(g.progress(first), 1.0)
	assert_eq(fired.size(), 0, "no second reward")
