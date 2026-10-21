extends TestCase

const DT: float = 1.0 / 60.0


## Runs the meter with no player input until it falls or the cap passes. Returns the fall time, or -1 if it never fell.
func _no_input_fall_time(seed_value: int, difficulty: float) -> float:
	var b: Balance = Balance.new()
	b.start(seed_value, difficulty)
	var ok: bool = true
	while ok and b.time_held() < 60.0:
		ok = b.update(DT, 0.0)
	return b.time_held() if b.is_failed() else -1.0


func test_same_seed_same_inputs_same_angles() -> void:
	var a: Balance = Balance.new()
	var b: Balance = Balance.new()
	a.start(42, 1.2)
	b.start(42, 1.2)
	assert_eq(a.angle, b.angle, "same start angle")
	for i: int in range(600):
		var c: float = sin(float(i) * 0.1) * 0.5
		var ra: bool = a.update(DT, c)
		var rb: bool = b.update(DT, c)
		assert_eq(ra, rb, "same fall result at tick %d" % i)
		assert_eq(a.angle, b.angle, "same angle at tick %d" % i)
		if not ra:
			break


func test_different_seeds_differ() -> void:
	var a: Balance = Balance.new()
	var b: Balance = Balance.new()
	a.start(1)
	b.start(2)
	var differs: bool = false
	for i: int in range(120):
		a.update(DT, 0.0)
		b.update(DT, 0.0)
		if a.angle != b.angle:
			differs = true
	assert_true(differs, "different seeds drift differently")


func test_start_resets_state() -> void:
	var b: Balance = Balance.new()
	b.start(7)
	for i: int in range(300):
		if not b.update(DT, 0.0):
			break
	assert_true(b.is_failed(), "fell before reset")
	b.start(7)
	assert_false(b.is_failed(), "reset clears fall")
	assert_eq(b.time_held(), 0.0, "reset clears time")
	assert_true(absf(b.angle) < 0.06, "start offset is small")
	assert_true(absf(b.angle) > 0.01, "start offset is not zero")


func test_no_input_falls_in_window() -> void:
	for seed_value: int in range(1, 21):
		var t: float = _no_input_fall_time(seed_value, 1.0)
		assert_true(t >= 1.5 and t <= 4.0, "seed %d fell at %f, want 1.5 to 4.0 s" % [seed_value, t])


func test_correcting_controller_survives_15s() -> void:
	for seed_value: int in range(1, 11):
		var b: Balance = Balance.new()
		b.start(seed_value, 1.0)
		var ok: bool = true
		while ok and b.time_held() < 15.0:
			var c: float = 0.0
			if absf(b.angle) > 0.1:
				c = -signf(b.angle)
			ok = b.update(DT, c)
		assert_false(b.is_failed(), "seed %d fell at %f" % [seed_value, b.time_held()])
		assert_true(b.time_held() >= 15.0, "seed %d lasted 15 s" % seed_value)


func test_higher_difficulty_fails_sooner() -> void:
	for seed_value: int in range(1, 6):
		var easy: float = _no_input_fall_time(seed_value, 1.0)
		var hard: float = _no_input_fall_time(seed_value, 2.0)
		assert_true(hard < easy, "seed %d: difficulty 2 (%f) before difficulty 1 (%f)" % [seed_value, hard, easy])


func test_update_stays_false_after_fall() -> void:
	var b: Balance = Balance.new()
	b.start(3, 2.0)
	var fell: bool = false
	for i: int in range(600):
		if not b.update(DT, 0.0):
			fell = true
			break
	assert_true(fell, "fell")
	assert_true(b.is_failed(), "is_failed reports fall")
	assert_false(b.update(DT, 1.0), "stays failed")
	assert_true(absf(b.angle) <= 1.0, "angle clamped to meter")
