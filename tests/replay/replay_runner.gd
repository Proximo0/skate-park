extends Node
## Replays a flight-recorder log (see docs/flight_recorder.md): rebuilds the park, restores the snapshot nearest at or
## before --from, feeds the recorded inputs and compares against the recorded positions.
## Run via tools/replay.sh <log.json> [--tune=preset.json] [--from=tick] [--ticks=N] [--csv=out.csv].
## Output: `REPLAY divergence max=<m> at tick <t> mean=<m>`, `REPLAY events ...`, `REPLAY whatif ...` (with --tune),
## `REPLAY csv <path>`. Exit 1 on a bad log, or when an unmodified replay diverges by more than 1e-3 m.

const EPS: float = 1.0e-3
const MAX_EVENT_LINES: int = 20

var _log: Dictionary = {}
var _by_tick: Dictionary = {}  ## tick -> recorded frame
var _skater: Skater = null
var _replayed: Dictionary = {}  ## tick -> debug frame
var _end_tick: int = 0
var _start_tick: int = 0
var _whatif: bool = false
var _csv_path: String = ""


func _ready() -> void:
	var log_path: String = ""
	var tune_path: String = ""
	var from_tick: int = -1
	var max_ticks: int = -1
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tune="):
			tune_path = a.substr(7)
		elif a.begins_with("--from="):
			from_tick = int(a.substr(7))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
		elif a.begins_with("--csv="):
			_csv_path = a.substr(6)
		elif not a.begins_with("--"):
			log_path = a
	if log_path == "" or not FileAccess.file_exists(log_path):
		_fail("REPLAY error log not found: '%s'" % log_path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(log_path))
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("frames"):
		_fail("REPLAY error not a flight-recorder log: %s" % log_path)
		return
	_log = parsed
	if _csv_path == "":
		_csv_path = log_path.get_basename() + ".replay.csv"
	var frames: Array = _log["frames"]
	if frames.is_empty() or (_log["snapshots"] as Dictionary).is_empty():
		_fail("REPLAY error log has no frames or no snapshots")
		return
	for f: Dictionary in frames:
		_by_tick[int(f["tick"])] = f
	var snap_ticks: Array = []
	for k: String in (_log["snapshots"] as Dictionary):
		snap_ticks.append(int(k))
	snap_ticks.sort()
	var first_tick: int = int((frames[0] as Dictionary)["tick"])
	var last_tick: int = int((frames[frames.size() - 1] as Dictionary)["tick"])
	var snap_tick: int = int(snap_ticks[0])
	if from_tick >= 0:
		for st: int in snap_ticks:
			if st <= from_tick:
				snap_tick = st
	_start_tick = snap_tick
	_end_tick = last_tick if max_ticks < 0 else mini(last_tick, snap_tick + max_ticks)
	if not _by_tick.has(snap_tick + 1):
		_fail("REPLAY error no recorded frame after snapshot tick %d (log frames %d..%d)" % [snap_tick, first_tick, last_tick])
		return
	_build_world(str(_log.get("park", "main")))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var tune := PhysicsTuning.new()
	tune.apply_dict(_log.get("tuning", {}) as Dictionary)
	if tune_path != "":
		_whatif = true
		if not tune.load_json(tune_path):
			_fail("REPLAY error cannot read tuning preset %s" % tune_path)
			return
	_skater.tune = tune
	_skater.restore(str_to_var((_log["snapshots"] as Dictionary)[str(snap_tick)] as String) as Dictionary)
	_apply_input(snap_tick + 1)
	_skater.physics_ticked.connect(_on_replay_tick)
	print("REPLAY start park=%s snapshot_tick=%d end_tick=%d tune=%s" % [_log.get("park", "main"), snap_tick, _end_tick, tune_path if tune_path != "" else "recorded"])


func _fail(msg: String) -> void:
	printerr(msg)
	print(msg)
	get_tree().quit(1)


func _build_world(park_name: String) -> void:
	if park_name == "testpark":
		var park: Node = (load("res://game/park/test_park.tscn") as PackedScene).instantiate()
		add_child(park)
		_skater = park.get("skater")
	else:
		var park := Park.new()
		park.name = "Park"
		add_child(park)
		_skater = Skater.new()
		_skater.name = "Skater"
		_skater.transform = park.spawn
		add_child(_skater)
	_skater.scripted_input = true
	_skater.set_input(Vector2.ZERO, [], [])


func _apply_input(tick: int) -> void:
	var f: Dictionary = _by_tick[tick]
	var st: Array = f["stick"]
	_skater.set_input(Vector2(float(st[0]), float(st[1])), f["pressed"] as Array, f["held"] as Array)


func _on_replay_tick(frame: Dictionary) -> void:
	var tick: int = int(frame["tick"])
	_replayed[tick] = frame
	if tick >= _end_tick or not _by_tick.has(tick + 1):
		_skater.physics_ticked.disconnect(_on_replay_tick)
		_finish.call_deferred()
		return
	_apply_input(tick + 1)


static func _arr_v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _finish() -> void:
	var worst: float = 0.0
	var worst_tick: int = _start_tick
	var sum: float = 0.0
	var n: int = 0
	var ticks: Array = _replayed.keys()
	ticks.sort()
	var csv: PackedStringArray = ["tick,t,rec_state,rec_px,rec_py,rec_pz,rec_vx,rec_vy,rec_vz,rec_speed,rep_state,rep_px,rep_py,rep_pz,rep_vx,rep_vy,rep_vz,rep_speed,rec_events,rep_events"]
	var mism: Array = []
	for tk: int in ticks:
		var rec: Dictionary = _by_tick[tk]
		var rep: Dictionary = _replayed[tk]
		var rp: Vector3 = _arr_v3(rec["pos"])
		var rv: Vector3 = _arr_v3(rec["vel"])
		var pp: Vector3 = rep["pos"]
		var pv: Vector3 = rep["vel"]
		var d: float = rp.distance_to(pp)
		sum += d
		n += 1
		if d > worst:
			worst = d
			worst_tick = tk
		var rev: Array = rec["events"]
		var pev: Array = rep["events"]
		if str(rev) != str(pev):
			mism.append([tk, rev, pev])
		csv.append("%d,%.5f,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%s,%s" % [
			tk, float(rec["t"]), rec["state"], rp.x, rp.y, rp.z, rv.x, rv.y, rv.z, float(rec["speed"]),
			rep["state"], pp.x, pp.y, pp.z, pv.x, pv.y, pv.z, float(rep["speed"]), "|".join(rev), "|".join(pev)])
	var f := FileAccess.open(_csv_path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(csv) + "\n")
	var mean: float = sum / float(maxi(n, 1))
	print("REPLAY divergence max=%.6f at tick %d mean=%.6f" % [worst, worst_tick, mean])
	print("REPLAY events mismatches=%d of %d ticks" % [mism.size(), n])
	for i: int in mini(mism.size(), MAX_EVENT_LINES):
		print("REPLAY event_mismatch tick=%d recorded=%s replayed=%s" % [mism[i][0], str(mism[i][1]), str(mism[i][2])])
	if _whatif:
		_print_whatif(ticks)
	print("REPLAY csv %s" % _csv_path)
	var bad: bool = not _whatif and worst > EPS
	if bad:
		print("REPLAY FAIL divergence %.6f m exceeds %.3f m with unchanged tuning" % [worst, EPS])
	get_tree().quit(1 if bad else 0)


## Peak y of each airborne stretch, as recorded and replayed.
func _air_peaks(ticks: Array, replayed: bool) -> Array:
	var peaks: Array = []
	var cur: float = -INF
	for tk: int in ticks:
		var in_air: bool
		var y: float
		if replayed:
			in_air = str((_replayed[tk] as Dictionary)["state"]) == "AIR"
			y = ((_replayed[tk] as Dictionary)["pos"] as Vector3).y
		else:
			in_air = str((_by_tick[tk] as Dictionary)["state"]) == "AIR"
			y = float(((_by_tick[tk] as Dictionary)["pos"] as Array)[1])
		if in_air:
			cur = maxf(cur, y)
		elif cur > -INF:
			peaks.append(cur)
			cur = -INF
	if cur > -INF:
		peaks.append(cur)
	return peaks


## Occurrences of an event name (prefix-matched for land:*) as [tick, speed], in order.
func _event_list(ticks: Array, replayed: bool) -> Dictionary:
	var out: Dictionary = {}
	for tk: int in ticks:
		var fr: Dictionary = _replayed[tk] if replayed else _by_tick[tk]
		for e: String in (fr["events"] as Array):
			var key: String = e.get_slice(":", 0)
			if not out.has(key):
				out[key] = []
			(out[key] as Array).append([tk, float(fr["speed"])])
	return out


func _print_whatif(ticks: Array) -> void:
	var rec_peaks: Array = _air_peaks(ticks, false)
	var rep_peaks: Array = _air_peaks(ticks, true)
	for i: int in maxi(rec_peaks.size(), rep_peaks.size()):
		var a: String = "%.3f" % float(rec_peaks[i]) if i < rec_peaks.size() else "-"
		var b: String = "%.3f" % float(rep_peaks[i]) if i < rep_peaks.size() else "-"
		print("REPLAY whatif air#%d peak_y recorded=%s replayed=%s" % [i + 1, a, b])
	var rec_ev: Dictionary = _event_list(ticks, false)
	var rep_ev: Dictionary = _event_list(ticks, true)
	var names: Array = rec_ev.keys()
	for k: String in rep_ev:
		if not names.has(k):
			names.append(k)
	names.sort()
	for name: String in names:
		var ra: Array = rec_ev.get(name, [])
		var pa: Array = rep_ev.get(name, [])
		if name == "bail":
			print("REPLAY whatif bails recorded=%d replayed=%d" % [ra.size(), pa.size()])
		for i: int in maxi(ra.size(), pa.size()):
			var a: String = "tick %d speed %.2f" % [ra[i][0], ra[i][1]] if i < ra.size() else "none"
			var b: String = "tick %d speed %.2f" % [pa[i][0], pa[i][1]] if i < pa.size() else "none"
			print("REPLAY whatif %s#%d recorded=(%s) replayed=(%s)" % [name, i + 1, a, b])
	if not rec_ev.has("bail") and not rep_ev.has("bail"):
		print("REPLAY whatif bails recorded=0 replayed=0")
	var max_rec: float = 0.0
	var max_rep: float = 0.0
	for tk: int in ticks:
		max_rec = maxf(max_rec, float((_by_tick[tk] as Dictionary)["speed"]))
		max_rep = maxf(max_rep, float((_replayed[tk] as Dictionary)["speed"]))
	print("REPLAY whatif max_speed recorded=%.2f replayed=%.2f" % [max_rec, max_rep])
