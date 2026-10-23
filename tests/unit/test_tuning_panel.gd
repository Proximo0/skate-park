extends TestCase
## TuningPanel: one row per field, the rows and the shared tuning stay in step, reset restores the defaults.


func _make_panel() -> TuningPanel:
	var panel: TuningPanel = TuningPanel.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(panel)
	return panel


func _drop_panel(panel: TuningPanel) -> void:
	var parent: Node = panel.get_parent()
	if parent != null:
		parent.remove_child(panel)
	panel.free()


func test_row_count_matches_fields() -> void:
	PhysicsTuning.shared().reset()
	var panel: TuningPanel = _make_panel()
	assert_eq(panel.row_count(), PhysicsTuning.FIELDS.size())
	_drop_panel(panel)


func test_slider_edit_changes_shared_tuning() -> void:
	var tuning: PhysicsTuning = PhysicsTuning.shared()
	tuning.reset()
	var panel: TuningPanel = _make_panel()
	var slider: HSlider = panel.row_slider("gravity")
	assert_true(slider != null, "gravity row exists")
	slider.value = 25.0
	assert_near(tuning.gravity, 25.0, 0.01, "slider wrote to the shared tuning")
	_drop_panel(panel)
	tuning.reset()


func test_shared_change_moves_slider_without_loop() -> void:
	var tuning: PhysicsTuning = PhysicsTuning.shared()
	tuning.reset()
	var panel: TuningPanel = _make_panel()
	var hits: Array = [0]
	var counter: Callable = func(_field: String, _value: float) -> void:
		hits[0] = int(hits[0]) + 1
	tuning.changed.connect(counter)
	tuning.set_value("max_speed", 30.0)
	assert_eq(int(hits[0]), 1, "one change emitted, no echo loop")
	assert_near(panel.row_slider("max_speed").value, 30.0, 0.01, "slider follows set_value")
	assert_near(panel.row_spin("max_speed").value, 30.0, 0.01, "spin box follows set_value")
	hits[0] = 0
	panel.row_slider("gravity").value = 20.0
	assert_eq(int(hits[0]), 1, "a slider edit emits exactly one change")
	tuning.changed.disconnect(counter)
	_drop_panel(panel)
	tuning.reset()


func test_reset_all_restores_defaults() -> void:
	var tuning: PhysicsTuning = PhysicsTuning.shared()
	tuning.reset()
	var panel: TuningPanel = _make_panel()
	tuning.set_value("gravity", 30.0)
	tuning.set_value("push_plant", 0.5)
	panel.reset_all()
	for f: Array in PhysicsTuning.FIELDS:
		var field: String = f[0]
		assert_near(float(tuning.get(field)), float(f[1]), 0.0001, "shared default for " + field)
		assert_near(panel.row_slider(field).value, float(f[1]), 0.01, "slider default for " + field)
	tuning.set_value("gravity", 30.0)
	panel.reset_field("gravity")
	assert_near(tuning.gravity, 18.0, 0.0001, "reset_field restores one field")
	_drop_panel(panel)
	tuning.reset()


func test_open_shows_mouse_and_close_restores_mode() -> void:
	var before: Input.MouseMode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var set_mode: Input.MouseMode = Input.mouse_mode  # headless may refuse some modes; test against what sticks
	var panel: TuningPanel = _make_panel()
	assert_false(panel.is_open, "starts closed")
	panel.open()
	assert_true(panel.is_open, "open sets is_open")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "mouse shown while open")
	panel.close()
	assert_false(panel.is_open, "close clears is_open")
	assert_eq(Input.mouse_mode, set_mode, "previous mouse mode restored")
	_drop_panel(panel)
	Input.mouse_mode = before
