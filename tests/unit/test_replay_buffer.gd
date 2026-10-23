extends TestCase
## ReplayBuffer (the replay's ring of visual frames), ReplayShots (auto cuts and tripods) and the ReplayDirector's
## best-combo bookkeeping plus the results screen's Watch Replay button.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _xf(x: float, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, 0.0))


func _filled(n: int, cap: int = 100, tracks: int = 2) -> ReplayBuffer:
	var b := ReplayBuffer.new(tracks, cap)
	for i: int in n:
		b.push(float(i) * 0.1, [_xf(float(i)), _xf(-float(i))], float(i), ReplayBuffer.FLAG_AIR if i >= 5 and i < 8 else 0)
	return b


func test_ring_wraps_and_keeps_newest() -> void:
	var b := _filled(8, 5)
	assert_eq(b.size(), 5)
	assert_near(b.start_time(), 0.3, 1e-6, "oldest kept")
	assert_near(b.end_time(), 0.7, 1e-6, "newest")
	assert_near(b.xform(0, 0).origin.x, 3.0, 1e-5)
	assert_near(b.xform(4, 1).origin.x, -7.0, 1e-5, "second track")
	assert_near(b.speed_at(4), 7.0, 1e-5)
	b.clear()
	assert_eq(b.size(), 0)
	assert_eq(b.sample(1.0).size(), 0, "empty buffer samples nothing")


func test_same_time_push_replaces_the_frame() -> void:
	var b := ReplayBuffer.new(1, 10)
	b.push(1.0, [_xf(1.0)])
	b.push(1.0, [_xf(2.0)])
	assert_eq(b.size(), 1)
	assert_near(b.xform(0, 0).origin.x, 2.0, 1e-6)


func test_sample_interpolates_position_and_rotation() -> void:
	var b := ReplayBuffer.new(1, 10)
	b.push(0.0, [_xf(0.0, 0.0)])
	b.push(1.0, [_xf(2.0, PI * 0.5)])
	var s: Transform3D = b.sample(0.5)[0]
	assert_near(s.origin.x, 1.0, 1e-5, "lerped origin")
	assert_near(s.basis.get_euler().y, PI * 0.25, 1e-4, "slerped yaw")
	assert_near(b.sample(-5.0)[0].origin.x, 0.0, 1e-6, "clamped before")
	assert_near(b.sample(5.0)[0].origin.x, 2.0, 1e-6, "clamped after")
	assert_near(b.sample_track(0.25, 0).origin.x, 0.5, 1e-5)
	assert_near(b.speed_sample(0.5), 0.0, 1e-6)


func test_index_at_is_the_frame_at_or_before() -> void:
	var b := _filled(20)
	assert_eq(b.index_at(0.0), 0)
	assert_eq(b.index_at(0.55), 5)
	assert_eq(b.index_at(0.61), 6)
	assert_eq(b.index_at(99.0), 19)
	assert_eq(b.index_at(-1.0), 0)


func test_clip_is_an_independent_copy() -> void:
	var b := _filled(20, 30)
	var c: ReplayBuffer = b.clip(0.45, 1.05)
	assert_eq(c.size(), 6, "0.5 .. 1.0")
	assert_near(c.start_time(), 0.5, 1e-6)
	assert_near(c.xform(0, 0).origin.x, 5.0, 1e-5)
	for i: int in 40:
		b.push(10.0 + i, [_xf(100.0), _xf(100.0)])
	assert_near(c.xform(0, 0).origin.x, 5.0, 1e-5, "clip unchanged by later pushes")
	assert_near(b.last_seconds(2.0).duration(), 2.0, 1e-6)
	assert_eq(b.clip(500.0, 600.0).size(), 0, "empty range")


func test_edges_find_takeoffs() -> void:
	var b := _filled(20)
	var e: PackedFloat64Array = b.edges(ReplayBuffer.FLAG_AIR)
	assert_eq(e.size(), 1)
	assert_near(e[0], 0.5, 1e-6)
	assert_eq(b.edges(ReplayBuffer.FLAG_GRIND).size(), 0)


func test_cost_is_small() -> void:
	var b := ReplayBuffer.new(40, int(ReplayDirector.BUFFER_SECONDS * ReplayDirector.SAMPLE_HZ))
	assert_true(b.bytes() < 3 * 1024 * 1024, "20 s x 40 tracks under 3 MB (%d)" % b.bytes())


func test_plan_cuts_before_takeoffs_and_fills_long_stretches() -> void:
	var cuts: Array = ReplayShots.plan(0.0, 10.0, PackedFloat64Array([2.0, 2.5, 6.0]))
	assert_eq(int((cuts[0] as Dictionary)["shot"]), ReplayShots.Shot.CHASE)
	assert_near(float((cuts[0] as Dictionary)["t"]), 0.0)
	assert_near(float((cuts[1] as Dictionary)["t"]), 2.0 - ReplayShots.LEAD_IN, 1e-6, "cut just before the takeoff")
	assert_eq(int((cuts[1] as Dictionary)["shot"]), ReplayShots.Shot.LOW)
	for i: int in range(1, cuts.size()):
		var gap: float = float((cuts[i] as Dictionary)["t"]) - float((cuts[i - 1] as Dictionary)["t"])
		var least: float = ReplayShots.MIN_FIRST if i == 1 else ReplayShots.MIN_GAP
		assert_true(gap >= least - 1e-6, "no shot shorter than MIN_GAP (%f)" % gap)
		assert_true(gap <= ReplayShots.MAX_LEN + 1e-6, "no shot longer than MAX_LEN (%f)" % gap)
		assert_true(int((cuts[i] as Dictionary)["shot"]) != ReplayShots.Shot.FREE)
	var flat: Array = ReplayShots.plan(0.0, 10.0, PackedFloat64Array())
	assert_true(flat.size() >= 3, "fillers on a flat clip")
	assert_eq(ReplayShots.cut_index(cuts, 1.0), 0)
	assert_eq(ReplayShots.cut_index(cuts, 2.0), 1)
	var early: Array = ReplayShots.plan(0.0, 5.0, PackedFloat64Array([0.97]))
	assert_eq(early.size(), 2, "an early air still gets its low-angle cut")


func test_tripods_stand_where_the_shot_says() -> void:
	var mid := Vector3(0, 1, 0)
	var low: Vector3 = ReplayShots.tripod(ReplayShots.Shot.LOW, mid, Vector3(0, 0, -1), 1.0)
	assert_near(low.y - mid.y, ReplayShots.LOW_UP, 1e-5, "low and near the ground")
	assert_true(low.distance_to(mid) > 2.0 and low.distance_to(mid) < 4.0)
	var wide: Vector3 = ReplayShots.tripod(ReplayShots.Shot.WIDE, mid, Vector3(0, 0, -1), -1.0)
	assert_true(wide.distance_to(mid) > 8.0, "wide is far")
	var other: Vector3 = ReplayShots.tripod(ReplayShots.Shot.WIDE, mid, Vector3(0, 0, -1), 1.0)
	assert_true(signf(wide.x) != signf(other.x), "side sign flips the side")
	var orb: Vector3 = ReplayShots.orbit(mid, 0.0, 0.0, 5.0)
	assert_near(orb.distance_to(mid), 5.0, 1e-5)


func test_director_keeps_best_combo_clips() -> void:
	var d := ReplayDirector.new()
	d.buffer = ReplayBuffer.new(2, 2000)
	for i: int in 600:
		d.clock = float(i) / 60.0
		d.buffer.push(d.clock, [_xf(float(i)), _xf(0.0)])
	d.clock = 2.0
	d._on_trick({})
	d.clock = 5.0
	d._on_combo_landed(1500, "Kickflip + 50-50")
	assert_eq(d.best_entries().size(), 0, "waits COMBO_AFTER before clipping")
	d.clock = 6.5
	d._finalize_pending()
	var e: Dictionary = d.best_clip_for(1500)
	assert_false(e.is_empty())
	var c: ReplayBuffer = e["clip"]
	assert_near(c.start_time(), 2.0 - ReplayDirector.COMBO_BEFORE, 0.02, "starts before the first trick")
	assert_near(c.end_time(), 5.0 + ReplayDirector.COMBO_AFTER, 0.02, "ends after the landing")
	for p: int in [100, 3000, 200, 2500]:
		d._on_combo_landed(p, "x")
		d._finalize_pending()
	var pts: Array = d.best_entries().map(func(x: Dictionary) -> int: return int(x["points"]))
	assert_eq(pts, [3000, 2500, 1500], "best three kept, best first")
	assert_true(d.best_clip_for(100).is_empty())
	d._on_combo_landed(9000, "late")
	assert_false(d.best_clip_for(9000).is_empty(), "a just-landed combo is clipped on request")
	d.free()


func test_results_offer_watch_replay_only_with_a_clip() -> void:
	var d := ReplayDirector.new()
	_tree().root.add_child(d)
	var b := _filled(10)
	d._best = [{"points": 2000, "text": "Kickflip", "clip": b}]
	var r: ResultsScreen = ResultsScreen.new().setup({"level_name": "T", "score": 5000, "best_combo": 2000})
	_tree().root.add_child(r)
	assert_true(r.find_child("WatchReplay", true, false) != null, "button shown")
	r.free()
	var r2: ResultsScreen = ResultsScreen.new().setup({"level_name": "T", "score": 5000, "best_combo": 1999})
	_tree().root.add_child(r2)
	assert_true(r2.find_child("WatchReplay", true, false) == null, "no clip, no button")
	r2.free()
	d.free()
