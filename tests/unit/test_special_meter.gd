extends TestCase


func test_fill_by_points() -> void:
	var m: SpecialMeter = SpecialMeter.new()
	assert_eq(m.value, 0.0, "starts empty")
	assert_false(m.is_special())
	m.add_points(1500)
	assert_near(m.value, 0.5, 0.0001, "1500 of 3000")
	m.add_points(750)
	assert_near(m.value, 0.75, 0.0001, "accumulates")
	m.add_points(-100)
	assert_near(m.value, 0.75, 0.0001, "negative points ignored")
	assert_false(m.is_special())


func test_cap_at_one_and_latch() -> void:
	var became: Array[bool] = [false]
	var m: SpecialMeter = SpecialMeter.new()
	m.became_special.connect(func() -> void: became[0] = true)
	m.add_points(2000)
	assert_false(m.is_special(), "not yet full")
	assert_false(became[0])
	m.add_points(5000)
	assert_near(m.value, 1.0, 0.0001, "capped at 1.0")
	assert_true(m.is_special())
	assert_true(became[0], "became_special emitted")


func test_became_special_emits_once() -> void:
	var count: Array[int] = [0]
	var m: SpecialMeter = SpecialMeter.new()
	m.became_special.connect(func() -> void: count[0] += 1)
	m.add_points(3000)
	m.add_points(3000)
	m.tick(1.0, false)
	assert_eq(count[0], 1)


func test_drain_outside_combo() -> void:
	var m: SpecialMeter = SpecialMeter.new()
	m.add_points(1500)
	m.tick(1.0, false)
	assert_near(m.value, 0.5 - 0.03, 0.0001, "drains 0.03/s")
	m.tick(2.0, false)
	assert_near(m.value, 0.41, 0.0001, "scales with delta: 0.47 - 0.06")


func test_no_drain_in_combo() -> void:
	var m: SpecialMeter = SpecialMeter.new()
	m.add_points(1500)
	m.tick(10.0, true)
	assert_near(m.value, 0.5, 0.0001, "no drain while in a combo")


func test_drain_floors_at_zero() -> void:
	var m: SpecialMeter = SpecialMeter.new()
	m.add_points(300)
	m.tick(100.0, false)
	assert_eq(m.value, 0.0, "never below zero")
	assert_false(m.is_special())


func test_special_latch_no_drain() -> void:
	var m: SpecialMeter = SpecialMeter.new()
	m.add_points(3000)
	assert_true(m.is_special())
	m.tick(100.0, false)
	assert_near(m.value, 1.0, 0.0001, "special does not drain")
	assert_true(m.is_special(), "special stays latched")


func test_use_special_keeps_special() -> void:
	var m: SpecialMeter = SpecialMeter.new()
	m.add_points(3000)
	m.use_special()
	assert_true(m.is_special(), "still special after use")
	assert_near(m.value, 1.0, 0.0001, "meter not emptied")


func test_bail_resets() -> void:
	var m: SpecialMeter = SpecialMeter.new()
	m.add_points(3000)
	m.bail()
	assert_eq(m.value, 0.0)
	assert_false(m.is_special())
	m.add_points(600)
	assert_near(m.value, 0.2, 0.0001, "fills again after bail")
	assert_false(m.is_special())


func test_refill_to_special_after_bail() -> void:
	var count: Array[int] = [0]
	var m: SpecialMeter = SpecialMeter.new()
	m.became_special.connect(func() -> void: count[0] += 1)
	m.add_points(3000)
	m.bail()
	m.add_points(3000)
	assert_true(m.is_special())
	assert_eq(count[0], 2, "latches again after bail")
