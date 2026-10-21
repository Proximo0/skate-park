extends TestCase
## PhysicsRecorder: ring buffer wrap, snapshot pruning, dump file structure and the bail window, driven by a fake skater.

const DIR: String = "user://test_physics_logs"


class FakeSkater extends Node:
	signal physics_ticked(frame: Dictionary)
	var tune: PhysicsTuning = PhysicsTuning.new()
	var n: int = 0

	func snapshot() -> Dictionary:
		return {"n": n, "pos": Vector3(n, 2.0, 3.0)}

	func tick(events: Array = []) -> void:
		n += 1
		var frame: Dictionary = {
			"tick": n, "t": n / 60.0, "state": "ROLLING", "pos": Vector3(n, 0, 0), "vel": Vector3(1, 0, 0),
			"speed": 1.0, "on_floor": true, "floor_normal": Vector3.UP, "facing": Vector3.FORWARD,
			"stick": Vector2(0, -1), "held": ["ollie"], "pressed": [], "crouch": 0.0, "anim": "push",
			"pumping": false, "pushing": true, "events": events,
		}
		physics_ticked.emit(frame)


func _make(cap: int = 1800) -> Array:
	var sk := FakeSkater.new()
	var rec := PhysicsRecorder.new()
	rec.capacity = cap
	rec.log_dir = DIR
	rec.bind(sk)
	return [sk, rec]


func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for f: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, f])


func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func test_ring_wraps_and_keeps_order() -> void:
	var m: Array = _make(10)
	for i: int in 25:
		m[0].tick()
	var rec: PhysicsRecorder = m[1]
	assert_eq(rec.frame_count(), 10)
	var frames: Array = rec.frames_in_order()
	assert_eq(int(frames[0]["tick"]), 16)
	assert_eq(int(frames[9]["tick"]), 25)
	for i: int in 9:
		assert_eq(int(frames[i + 1]["tick"]) - int(frames[i]["tick"]), 1)
	m[0].free()
	rec.free()


func test_snapshots_every_interval_and_pruned() -> void:
	var m: Array = _make(100)
	for i: int in 400:
		m[0].tick()
	var rec: PhysicsRecorder = m[1]
	var snaps: Array = rec.snapshot_ticks()
	var oldest: int = int(rec.frames_in_order()[0]["tick"])  # 301
	assert_true(int(snaps[0]) <= oldest, "a snapshot at or before the oldest frame is kept")
	assert_true(oldest - int(snaps[0]) < 120, "older ones are dropped")
	assert_eq(int(snaps[snaps.size() - 1]), 360)
	assert_true(snaps.size() <= 3)
	m[0].free()
	rec.free()


func test_dump_structure_and_roundtrip() -> void:
	_clean()
	var m: Array = _make(50)
	m[0].tune.set_value("gravity", 21.0)
	for i: int in 130:
		m[0].tick(["ollie"] if i == 100 else [])
	var rec: PhysicsRecorder = m[1]
	var path: String = rec.dump(DIR + "/t.json")
	assert_eq(path, DIR + "/t.json")
	var doc: Dictionary = _read(path)
	assert_eq(int(doc["version"]), 1)
	assert_eq(doc["park"], "main")
	assert_eq(int(doc["tick_rate"]), Engine.physics_ticks_per_second)
	assert_near(float(doc["tuning"]["gravity"]), 21.0)
	var frames: Array = doc["frames"]
	assert_eq(frames.size(), 50)
	assert_eq(int(frames[0]["tick"]), 81)
	var f: Dictionary = frames[20]
	for key: String in ["tick", "t", "state", "pos", "vel", "speed", "on_floor", "floor_normal", "facing", "stick", "held", "pressed", "crouch", "anim", "pumping", "pushing", "events"]:
		assert_true(f.has(key), key)
	assert_eq((f["events"] as Array), ["ollie"])
	assert_eq((f["pos"] as Array).size(), 3)
	assert_near(float(f["pos"][0]), 101.0)
	var snaps: Dictionary = doc["snapshots"]
	assert_true(snaps.has("60") and snaps.has("120"))
	assert_false(snaps.has("0"))
	var back: Dictionary = str_to_var(snaps["120"] as String) as Dictionary
	assert_eq(int(back["n"]), 120)
	assert_near((back["pos"] as Vector3).x, 120.0)
	m[0].free()
	rec.free()
	_clean()


func test_bail_dump_window_and_keep_three() -> void:
	_clean()
	var m: Array = _make(1800)
	var rec: PhysicsRecorder = m[1]
	for i: int in 1000:
		m[0].tick(["bail"] if i % 200 == 0 and i > 0 else [])
	var names: Array = []
	for f: String in DirAccess.get_files_at(DIR):
		if f.begins_with("bail_"):
			names.append(f)
	# Bails at ticks 201, 401, 601, 801 all land in the same wall-clock second, so they share a name: at least one file, never more than 3.
	assert_true(names.size() >= 1 and names.size() <= 3, "bail files: %s" % str(names))
	var doc: Dictionary = _read(DIR + "/" + names[0])
	var frames: Array = doc["frames"]
	var last: int = int(frames[frames.size() - 1]["tick"])
	var first: int = int(frames[0]["tick"])
	var bail_tick: int = last - 60
	assert_true(((frames[frames.size() - 61] as Dictionary)["events"] as Array).has("bail"))
	assert_true(first >= bail_tick - 600 and first <= bail_tick - 600 + 1 or first == 1)
	assert_true((doc["snapshots"] as Dictionary).size() >= 1)
	m[0].free()
	rec.free()
	_clean()


func test_bail_files_trimmed_to_three() -> void:
	_clean()
	for i: int in 5:
		var f := FileAccess.open("%s/bail_2000-01-0%d_00-00-00.json" % [DIR, i + 1], FileAccess.WRITE)
		f.store_string("{}")
		f = null
	var m: Array = _make(1800)
	for i: int in 200:
		m[0].tick(["bail"] if i == 100 else [])
	var names: Array = []
	for f: String in DirAccess.get_files_at(DIR):
		if f.begins_with("bail_"):
			names.append(f)
	assert_eq(names.size(), 3, str(names))
	assert_false(names.has("bail_2000-01-01_00-00-00.json"))
	assert_false(names.has("bail_2000-01-02_00-00-00.json"))
	assert_false(names.has("bail_2000-01-03_00-00-00.json"))
	m[0].free()
	m[1].free()
	_clean()
