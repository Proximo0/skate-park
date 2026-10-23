extends TestCase
## PhysicsOverlay stats and buffers fed with synthetic frames, and TimeControl scale cycling.

const DT: float = 1.0 / 60.0


func _frame(tick: int, state: String, y: float, speed: float, events: Array = []) -> Dictionary:
	return {"tick": tick, "t": float(tick) * DT, "state": state, "pos": Vector3(0, y, 0),
		"vel": Vector3(0, 0, -speed), "speed": speed, "events": events}


func _overlay() -> PhysicsOverlay:
	var o := PhysicsOverlay.new()
	o.spawn_y = 0.5
	return o


func test_air_stats_from_frames() -> void:
	var o: PhysicsOverlay = _overlay()
	o.feed_frame(_frame(1, "ROLLING", 0.5, 8.0))
	o.feed_frame(_frame(2, "AIR", 0.6, 8.0, ["ollie", "air"]))
	o.feed_frame(_frame(3, "AIR", 1.2, 8.0))
	o.feed_frame(_frame(4, "AIR", 1.5, 8.0))
	o.feed_frame(_frame(5, "AIR", 1.0, 8.0))
	o.feed_frame(_frame(6, "ROLLING", 0.5, 6.0, ["land:clean"]))
	assert_near(o.last_air_time, 4.0 * DT, 1e-5, "air time")
	assert_near(o.last_air_peak, 0.9, 1e-5, "peak above take-off")
	assert_near(o.last_ollie_pop, 0.9, 1e-5, "pop above ollie point")
	assert_near(o.last_retention, 0.75, 1e-5, "speed after / before")
	assert_eq(o.event_log().size(), 3)
	assert_eq(o.event_log()[2], "6 land:clean")
	o.free()


func test_no_air_stats_before_first_air() -> void:
	var o: PhysicsOverlay = _overlay()
	o.feed_frame(_frame(1, "ROLLING", 0.5, 5.0))
	assert_true(o.last_air_time < 0.0)
	assert_true(o.last_retention < 0.0)
	o.free()


func test_event_log_keeps_last_six() -> void:
	var o: PhysicsOverlay = _overlay()
	for i: int in 10:
		o.feed_frame(_frame(i + 1, "ROLLING", 0.5, 5.0, ["e%d" % i]))
	assert_eq(o.event_log().size(), 6)
	assert_eq(o.event_log()[0], "5 e4")
	assert_eq(o.event_log()[5], "10 e9")
	o.free()


func test_graph_buffer_wraps() -> void:
	var o: PhysicsOverlay = _overlay()
	var total: int = PhysicsOverlay.WINDOW_TICKS + 50
	for i: int in total:
		o.feed_frame(_frame(i, "ROLLING", 0.5, float(i)))
	assert_eq(o.sample_count(), PhysicsOverlay.WINDOW_TICKS)
	assert_near(o.sample_at(PhysicsOverlay.GRAPH_SPEED, 0), 50.0, 1e-3, "oldest")
	assert_near(o.sample_at(PhysicsOverlay.GRAPH_SPEED, o.sample_count() - 1), float(total - 1), 1e-3, "newest")
	o.free()


func test_text_has_core_fields() -> void:
	var o: PhysicsOverlay = _overlay()
	o.feed_frame(_frame(1, "ROLLING", 0.5, 10.0))
	var s: String = o.build_text()
	assert_true(s.contains("ROLLING"))
	assert_true(s.contains("36.0 km/h"))
	o.free()


func test_time_scale_cycles() -> void:
	var tc := TimeControl.new()
	var seen: Array[float] = []
	for i: int in 5:
		seen.append(tc.cycle_scale())
	Engine.time_scale = 1.0
	assert_eq(seen, [0.5, 0.25, 0.1, 1.0, 0.5] as Array[float])
	assert_eq(tc.badge_text(), "SLOW x0.5")
	tc.set_scale_index(2)
	Engine.time_scale = 1.0
	assert_eq(tc.badge_text(), "SLOW x0.25")
	tc.free()
