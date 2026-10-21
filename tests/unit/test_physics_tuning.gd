extends TestCase
## PhysicsTuning: defaults, clamping, dict/diff/apply and the JSON save/load round trip.

const PATH: String = "user://test_physics_tuning.json"


func test_defaults_match_fields() -> void:
	var t := PhysicsTuning.new()
	for f: Array in PhysicsTuning.FIELDS:
		assert_near(float(t.get(f[0])), float(f[1]), 0.000001, str(f[0]))
	assert_true(t.diff_from_defaults().is_empty())
	assert_eq(PhysicsTuning.field_names().size(), PhysicsTuning.FIELDS.size())


func test_set_value_clamps() -> void:
	var t := PhysicsTuning.new()
	assert_true(t.set_value("gravity", 1000.0))
	assert_near(t.gravity, 40.0)
	assert_true(t.set_value("gravity", -5.0))
	assert_near(t.gravity, 5.0)
	assert_false(t.set_value("no_such_field", 1.0))


func test_changed_signal_and_reset() -> void:
	var t := PhysicsTuning.new()
	var seen: Array = []
	t.changed.connect(func(field: String, value: float) -> void: seen.append([field, value]))
	t.set_value("brake", 99.0)
	assert_eq(seen.size(), 1)
	assert_eq(seen[0][0], "brake")
	assert_near(float(seen[0][1]), 30.0)
	t.reset()
	assert_near(t.brake, 6.0)


func test_diff_and_apply() -> void:
	var t := PhysicsTuning.new()
	t.set_value("gravity", 12.0)
	t.set_value("side_grip", 40.0)
	var d: Dictionary = t.diff_from_defaults()
	assert_eq(d.size(), 2)
	var u := PhysicsTuning.new()
	var n: int = u.apply_dict(d)
	assert_eq(n, 2)
	assert_near(u.gravity, 12.0)
	assert_near(u.side_grip, 40.0)
	assert_eq(u.apply_dict({"bogus": 1.0}), 0)


func test_save_load_round_trip() -> void:
	var t := PhysicsTuning.new()
	t.set_value("ollie_max", 10.0)
	t.set_value("turn_rate", 3.25)
	assert_eq(t.save_json(PATH), OK)
	var u := PhysicsTuning.new()
	assert_true(u.load_json(PATH))
	assert_eq(u.to_dict(), t.to_dict())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	assert_false(u.load_json(PATH))
