extends TestCase
## ResultsScreen, the GoalsPanel run bookkeeping, the level select career view and the coach tips.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_results_screen_shows_numbers_and_records() -> void:
	var r: ResultsScreen = ResultsScreen.new().setup({
		"level_name": "Test Park", "score": 12345, "best_combo": 2000, "goals": ["A", "B"], "goals_done": 5, "goals_total": 12,
		"record_score": true, "record_combo": false, "best_score": 12345, "best_combo_ever": 3000,
	})
	_tree().root.add_child(r)
	r.finish_now()
	assert_true(r.find_child("NewRecord", true, false) != null, "record sticker shown")
	assert_eq(r.get_children().size() > 0, true)
	var got: Array = []
	r.retry_pressed.connect(func() -> void: got.append("retry"))
	r.free_skate_pressed.connect(func() -> void: got.append("free"))
	r.level_select_pressed.connect(func() -> void: got.append("levels"))
	for b: Node in r.find_children("*", "Button", true, false):
		(b as Button).pressed.emit()
	assert_eq(got.size(), 3)
	assert_eq(ResultsScreen.goals_line(2, 5, 12), "2 this run   -   5 / 12 done")
	r.free()


func test_panel_run_bookkeeping_records_the_run() -> void:
	var store: ProgressStore = ProgressStore.new()
	var panel: GoalsPanel = GoalsPanel.new()
	panel.results_enabled = false
	panel.store = store
	var g: Goals = Goals.load_default()
	_tree().root.add_child(panel)
	panel.bind(g, func() -> float: return 0.0)
	panel.store = store  # bind took the shared store; use ours
	panel.level_id = "practice"
	panel._on_goal_completed({"id": "gx", "title": "Goal X"})
	var d: Dictionary = panel.build_results()
	assert_eq((d["goals"] as Array).size(), 1)
	assert_eq(store.goals_done_count("practice"), 1)
	assert_true(d.has("record_score"))
	panel.free()


func test_level_select_shows_locks_and_toggle() -> void:
	var store: ProgressStore = ProgressStore.new()
	var ls: LevelSelect = LevelSelect.new()
	ls.store = store
	_tree().root.add_child(ls)
	assert_true((ls._locks["beach"] as Control).visible, "beach locked")
	assert_false((ls._locks["practice"] as Control).visible, "practice open")
	var picked: Array = []
	ls.chosen.connect(func(id: String) -> void: picked.append(id))
	(ls._cards["beach"] as Button).pressed.emit()
	assert_eq(picked.size(), 0, "locked card refuses")
	(ls._cards["warehouse"] as Button).pressed.emit()
	assert_eq(picked, ["warehouse"])
	ls._unlock_btn.pressed.emit()
	assert_true(store.unlock_all)
	assert_false((ls._locks["beach"] as Control).visible)
	ls.free()


func test_coach_tip_shows_once_and_is_saved() -> void:
	var store: ProgressStore = ProgressStore.new()
	var tips: CoachTips = CoachTips.new()
	tips.store = store
	_tree().root.add_child(tips)
	assert_true(tips._offer("boneless", false))
	assert_true(store.tip_seen("boneless"))
	assert_eq(tips.shown_id(), "boneless")
	tips._quiet = 0.0
	assert_false(tips._offer("boneless", false), "never twice")
	assert_eq(CoachTips.tip_for_trick("wallplant"), "wallplant")
	assert_eq(CoachTips.tip_for_trick("kickflip"), "")
	assert_eq(CoachTips.next_nudge(store.tip_seen), "powerslide", "boneless is known, next is powerslide")
	tips.free()
