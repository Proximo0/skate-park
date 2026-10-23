extends TestCase
## Skater.snapshot()/restore() as data: keys, var_to_str round trip, and sub-object state. The physics determinism
## check (restore then run N ticks) needs physics frames, so it lives in tests/sim/sim_snapshot.gd.

const SkaterScript := preload("res://game/skater/skater.gd")


func _skater() -> Skater:
	var sk: Skater = SkaterScript.new()
	sk.db = TrickDB.load_default()
	sk.gaps = Gaps.load_default()
	return sk


## Deep compare; floats within 1e-6 because var_to_str prints some doubles at float32 precision (error up to about 1e-8).
func _same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		var da: Dictionary = a
		var db_: Dictionary = b
		if da.size() != db_.size():
			return false
		for k: Variant in da:
			if not db_.has(k) or not _same(da[k], db_[k]):
				return false
		return true
	if a is Array and b is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return false
		for i: int in aa.size():
			if not _same(aa[i], ab[i]):
				return false
		return true
	if a is float and b is float:
		return absf(float(a) - float(b)) < 1.0e-6
	if a is Vector3 and b is Vector3:
		return (a as Vector3).distance_to(b as Vector3) < 1.0e-6
	if a is Transform3D and b is Transform3D:
		return (a as Transform3D).is_equal_approx(b as Transform3D)
	return a == b


func test_snapshot_round_trips_through_text() -> void:
	var sk: Skater = _skater()
	sk.velocity = Vector3(1.5, 2.5, -3.5)
	sk._t = 4.25
	sk.crouch = 0.5
	sk.combo.add_trick("kickflip", "Kickflip", 200)
	sk.combo.add_hold_points(60, 0.5)
	sk.tricks.feed(Vector2(0.0, -1.0), ["flip"], [])
	sk.balance.start(7, 1.2)
	sk.balance.update(0.1, 0.0)
	sk.state.event("ollie")
	var snap: Dictionary = sk.snapshot()
	var text: String = var_to_str(snap)
	var back: Variant = str_to_var(text)
	assert_true(back is Dictionary)
	assert_true(_same(back, snap), "round trip")
	sk.free()


func test_restore_reproduces_snapshot() -> void:
	var a: Skater = _skater()
	a.velocity = Vector3(0.0, 3.0, -9.0)
	a._t = 1.5
	a.combo.add_trick("heelflip", "Heelflip", 150)
	a.special.add_points(900)
	a.tricks.feed(Vector2(1.0, 0.0), ["grind"], [])
	a.balance.start(3, 1.0)
	a.spin.start(0.5)
	a.spin.update(2.0)
	a.state.event("ollie")
	a.state.mark_trick()
	a.switch_stance = true
	a._seed = 9
	var snap: Dictionary = a.snapshot()
	var b: Skater = _skater()
	b.restore(str_to_var(var_to_str(snap)) as Dictionary)
	assert_true(_same(b.snapshot(), snap), "restore")
	assert_eq(b.state.state, SkateState.State.AIR)
	assert_true(b.state.combo_open)
	assert_eq(b.combo.trick_count(), 1)
	# The balance RNG continues the same sequence.
	assert_near(b.balance._rng.randf(), a.balance._rng.randf(), 0.0000001)
	a.free()
	b.free()


func test_snapshot_has_expected_keys() -> void:
	var sk: Skater = _skater()
	var snap: Dictionary = sk.snapshot()
	for key: String in ["transform", "velocity", "t", "tick", "rail", "ragdoll", "state", "tricks", "combo", "special", "balance", "spin", "gaps", "pending_air", "snap_offset"]:
		assert_true(snap.has(key), key)
	for key: String in ["state", "time_in_state", "combo_open", "revert_armed"]:
		assert_true((snap["state"] as Dictionary).has(key), "state." + key)
	sk.free()


func test_tune_is_shared_by_default() -> void:
	var sk: Skater = _skater()
	assert_true(sk.tune == PhysicsTuning.shared())
	sk.free()
