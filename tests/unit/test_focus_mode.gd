extends TestCase
## FocusMode: focus comes on only with a special meter, drains it per real second, and ends (special spent) when dry.


func _meter(full: bool) -> SpecialMeter:
	var m := SpecialMeter.new()
	if full:
		m.add_points(int(SpecialMeter.FILL_POINTS))
	return m


func test_needs_a_full_meter() -> void:
	var f := FocusMode.new()
	assert_false(f.toggle(_meter(false)), "an empty meter gives no focus")
	assert_false(f.active)
	assert_true(f.toggle(_meter(true)), "a full meter turns focus on")
	assert_true(f.active)


func test_toggle_off() -> void:
	var f := FocusMode.new()
	var m: SpecialMeter = _meter(true)
	f.toggle(m)
	assert_false(f.toggle(m), "pressed again: off")
	assert_false(f.active)
	assert_true(m.is_special(), "turning it off keeps what is left of the meter")


func test_drains_per_real_second() -> void:
	var f := FocusMode.new()
	var m: SpecialMeter = _meter(true)
	f.toggle(m)
	# one real second at a 0.5 clock is 60 ticks of 1/120 s game time
	for i: int in 60:
		f.tick(1.0 / 120.0, 0.5, 0.125, m)
	assert_near(m.value, 0.875, 0.001, "an eighth of the meter per real second")
	assert_eq(f.time_scale(0.5), 0.5, "the engine clock while on")


func test_runs_dry() -> void:
	var f := FocusMode.new()
	var m: SpecialMeter = _meter(true)
	f.toggle(m)
	var ended: bool = false
	for i: int in 2000:
		if f.tick(1.0 / 60.0, 1.0, 0.125, m):
			ended = true
			assert_true(i >= 470 and i <= 490, "about 8 s of focus (%d ticks)" % i)
			break
	assert_true(ended, "the meter ran dry")
	assert_false(f.active, "focus ends")
	assert_false(m.is_special(), "special spent")
	assert_eq(f.time_scale(0.5), 1.0, "the clock back to normal")
	assert_false(f.tick(1.0 / 60.0, 1.0, 0.125, m), "nothing more to drain")
