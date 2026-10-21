extends Node
## The play-bot: skates the REAL park (res://game/main.tscn) along scripted routes the way a player would, and reports
## everything that feels broken. Run it with tools/bot_run.sh (see docs/play_bot.md).
## Args (after --): --tune=<preset.json>  --only=<line or prefix>  --record  --list
## Output: `BOT <line> DONE|FAIL ...`, `BOTISSUE <kind> <line> pos=.. tick=.. detail`, `BOT score=<0-100> issues=N`,
## /tmp/bot/report.json and (with --record) /tmp/bot/<line>.json flight-recorder files for lines with problems.

const OUT_DIR: String = "/tmp/bot"
const SETTLE_TICKS: int = 4
const TAIL_TICKS: int = 45  ## ticks after the last waypoint, so the final landing is judged
## Score: start at 100, take off per issue (by kind) and per failed line. See docs/play_bot.md.
const PENALTY: Dictionary = {
	"bail": 5.0, "snag": 4.0, "hard_stop": 4.0, "stuck": 8.0, "respawn": 15.0, "below_kill_plane": 15.0,
	"jitter_normal": 2.0, "jitter_y": 2.0, "floor_flicker": 2.0, "teleport": 3.0, "overspeed": 6.0, "nan": 20.0,
	"grind_miss": 3.0, "action_miss": 2.0, "wp_timeout": 3.0, "gap_miss": 3.0,
}
const FAIL_PENALTY: float = 5.0

var _only: String = ""
var _record: bool = false
var _queue: Array[String] = []
var _results: Array[Dictionary] = []
var _all_issues: Array[Dictionary] = []
var _tune_note: String = "defaults"

var _phase: String = "next"
var _settle: int = 0
var _tail: int = 0
var _main: Node = null
var _sk: Skater = null
var _driver: BotDriver = null
var _det: BotDetectors = null
var _line: Dictionary = {}
var _snapshots: Dictionary = {}
var _line_ticks: int = 0
var _started_msec: int = 0
var _fail_reason: String = ""
var _shard: int = 0  ## with --nshards=N, this process runs every Nth line (tools/check_all.sh runs shards in parallel)
var _nshards: int = 1


func _ready() -> void:
	var tune_path: String = ""
	var list_only: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tune="):
			tune_path = a.substr(7)
		elif a.begins_with("--only="):
			_only = a.substr(7)
		elif a == "--record":
			_record = true
		elif a == "--list":
			list_only = true
		elif a.begins_with("--shard="):
			_shard = int(a.substr(8))
		elif a.begins_with("--nshards="):
			_nshards = maxi(1, int(a.substr(10)))
	if tune_path != "":
		_tune_note = _apply_tune(tune_path)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var names: Array[String] = BotLines.names()
	for i: int in names.size():
		var n: String = names[i]
		if (_only == "" or n == _only or n.begins_with(_only)) and i % _nshards == _shard:
			_queue.append(n)
	if list_only:
		for n: String in BotLines.names():
			print("BOTLINE ", n)
		get_tree().quit(0)
		return
	_started_msec = Time.get_ticks_msec()
	if _queue.is_empty():
		print("BOT crash no line matches --only=%s (lines: %s)" % [_only, ", ".join(BotLines.names())])
		get_tree().quit(1)


func _apply_tune(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("BOTINFO tune cannot open %s" % path)
		return "preset unreadable"
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return "preset unparsable"
	var d: Dictionary = parsed
	if d.has("tuning") and d["tuning"] is Dictionary:
		d = d["tuning"]
	var n: int = PhysicsTuning.shared().apply_dict(d)
	print("BOTINFO tune applied %d fields from %s" % [n, path])
	return "preset %s (%d fields)" % [path, n]


func _physics_process(delta: float) -> void:
	match _phase:
		"next":
			_begin_line()
		"settle":
			_settle += 1
			if _settle >= SETTLE_TICKS:
				_start_run()
		"run":
			_line_ticks += 1
			if _driver.finished:
				_tail += 1
				if _tail >= TAIL_TICKS:
					_end_line("")
					return
			_driver.step(delta)
			if _line_ticks > int(float(_line["limit"]) * 60.0):
				_end_line("timeout")
		"gap":
			_phase = "next"
		"done":
			pass


func _begin_line() -> void:
	if _queue.is_empty():
		_finish()
		return
	var name_in: String = _queue.pop_front()
	_line = {"name": name_in}
	var scene: PackedScene = load("res://game/main.tscn") as PackedScene
	_main = scene.instantiate()
	add_child(_main)
	_sk = _main.get("skater") as Skater
	_sk.scripted_input = true
	_phase = "settle"
	_settle = 0


func _start_run() -> void:
	var park: Park = _main.get("park") as Park
	var lines: BotLines = BotLines.new(park, _sk)
	_line = lines.build(str(_line["name"]))
	var tune: PhysicsTuning = PhysicsTuning.shared()
	_det = BotDetectors.new(str(_line["name"]), tune, _record)
	_driver = BotDriver.new(_sk, park, _line["wps"])
	_snapshots = {}
	_sk.physics_ticked.connect(_on_tick)
	_sk.gap_hit.connect(func(n: String, _p: int) -> void: _det.on_gap(n))
	_line_ticks = 0
	_tail = 0
	_fail_reason = ""
	_phase = "run"


func _on_tick(f: Dictionary) -> void:
	if _det == null:
		return
	if _driver.teleported:
		_snapshots[str(int(f["tick"]))] = var_to_str(_sk.snapshot())
	_det.wall_test = _driver.wall_test
	_det.feed(f, _driver.moving_intent, _driver.teleported, _hit_info())
	for e: Variant in f["events"]:
		if str(e).begins_with("land:"):
			_driver.on_landed()


## What the skater last slid against this tick, for the issue details (tells a bot routing fault from a physics one).
## Prefers a wall-like contact over the floor.
func _hit_info() -> Dictionary:
	var n: int = _sk.get_slide_collision_count()
	if n == 0:
		return {}
	var best: KinematicCollision3D = _sk.get_slide_collision(n - 1)
	for i: int in n:
		var c: KinematicCollision3D = _sk.get_slide_collision(i)
		if absf(c.get_normal().y) < 0.5:
			best = c
	var col: Object = best.get_collider()
	var nm: String = str(col)
	if col is Node:
		var path: String = str((col as Node).get_path())
		nm = path.get_slice("/", path.get_slice_count("/") - 2) + "/" + path.get_slice("/", path.get_slice_count("/") - 1)
	return {"name": nm, "n": best.get_normal()}


func _end_line(reason: String) -> void:
	_phase = "gap"
	_sk.physics_ticked.disconnect(_on_tick)
	var d: BotDetectors = _det
	var drv: BotDriver = _driver
	# driver-side findings become issues
	var tick: int = int(_sk.debug.get("tick", 0))
	var pos: Vector3 = _sk.global_position
	for m: String in drv.misses:
		var kind: String = "grind_miss" if m.begins_with("grind") else "action_miss"
		d.issues.append({"kind": kind, "line": d.line_name, "pos": pos, "tick": tick, "detail": m + " (check bot aim vs physics: " + m + ")"})
		d.counts[kind] = int(d.counts.get(kind, 0)) + 1
	var soft: bool = bool(_line.get("soft", false))
	var gave_up: int = 0
	for s: String in drv.skipped:
		if s.begins_with("stuck"):
			gave_up += 1
		elif not soft:
			d.issues.append({"kind": "wp_timeout", "line": d.line_name, "pos": pos, "tick": tick, "detail": "waypoint %s not reached in time" % s})
			d.counts["wp_timeout"] = int(d.counts.get("wp_timeout", 0)) + 1
	# gaps the line is meant to land that never fired
	var unreachable: Dictionary = _line.get("design_unreachable", {})
	for g: Variant in _line.get("expect", []):
		if unreachable.has(str(g)) and not d.gaps.has(str(g)):
			d.infos.append("gap_design %s: %s" % [str(g), str(unreachable[str(g)])])
		elif not d.gaps.has(str(g)) and reason == "":
			d.issues.append({"kind": "gap_miss", "line": d.line_name, "pos": pos, "tick": tick, "detail": "gap '%s' was attempted but not completed (see gaps.json: its zones and required state)" % str(g)})
			d.counts["gap_miss"] = int(d.counts.get("gap_miss", 0)) + 1
	var ok: bool = reason == "" and (drv.skipped.is_empty() or soft) and not d.counts.has("respawn") and not d.counts.has("below_kill_plane") and not d.counts.has("nan")
	if reason != "":
		_fail_reason = reason
	elif not drv.skipped.is_empty() and not soft:
		_fail_reason = "wp_timeout" if gave_up == 0 else "gave_up_after_stop"
	elif d.counts.has("respawn") or d.counts.has("below_kill_plane"):
		_fail_reason = "fell_out"
	var t_sec: float = float(_line_ticks) / 60.0
	var landed: int = _sk.combo.landed_total  ## points banked on this line (a bailed or wiped combo banks nothing)
	var notes: Array[String] = []
	if not d.snaps.is_empty():
		var smax: float = 0.0
		for sn: float in d.snaps:
			smax = maxf(smax, sn)
		notes.append("grind_snaps=%d(max %.2fm)" % [d.snaps.size(), smax])
	if d.wall_hits > 0:
		notes.append("head_on_wall_hits=%d" % d.wall_hits)
	if not d.route_faults.is_empty():
		notes.append("bot_route_faults=%d" % d.route_faults.size())
	if _fail_reason != "":
		notes.append("reason=" + _fail_reason)
	for n: String in drv.notes:
		notes.append(n)
	if not drv.peaks.is_empty():
		var ps: Array[String] = []
		for p: float in drv.peaks:
			ps.append("%.2f" % p)
		notes.append("peaks_above_coping=[" + ",".join(ps) + "]")
	if _line.has("note"):
		notes.append(str(_line["note"]))
	var causes: Array[String] = []
	for c: String in d.bail_causes:
		causes.append(c.split(" (")[0])
	if not causes.is_empty():
		notes.append("bail_causes=" + str(causes))
	var res: Dictionary = {
		"line": d.line_name, "ok": ok, "t": snappedf(t_sec, 0.01), "bails": d.bails, "snags": d.snags, "gaps": d.gaps.duplicate(),
		"landings": d.landings.duplicate(), "max_speed": snappedf(d.max_speed_seen, 0.01), "max_height": snappedf(d.max_height, 0.01),
		"grind_s": snappedf(float(drv.grind_ticks) / 60.0, 0.01), "manual_s": snappedf(float(drv.manual_ticks) / 60.0, 0.01),
		"air_s": snappedf(float(d.airtime_ticks) / 60.0, 0.01),
		"route_faults": d.route_faults.duplicate(), "wall_hits": d.wall_hits, "head_on": d.head_on_log.duplicate(),
		"infos": d.infos.duplicate(), "wall_tests": drv.wall_tests, "wall_test_slams": d.wall_test_results.duplicate(), "grind_snaps": d.snaps.size(),
		"issue_counts": d.counts.duplicate(), "peaks": drv.peaks.duplicate(), "notes": notes, "reason": _fail_reason,
		"landed_total": landed,
	}
	_results.append(res)
	print("BOT %s %s t=%.1f bails=%d snags=%d gaps=[%s] max_speed=%.1f max_h=%.1f grind=%.1fs manual=%.1fs landings=%s landed_total=%d %s" % [
		d.line_name, "DONE" if ok else "FAIL", t_sec, d.bails, d.snags, ",".join(d.gaps), d.max_speed_seen, d.max_height,
		float(drv.grind_ticks) / 60.0, float(drv.manual_ticks) / 60.0, _land_str(d.landings), landed, " ".join(notes)])
	for iss: Dictionary in d.issues:
		var p: Vector3 = iss["pos"]
		print("BOTISSUE %s %s pos=(%.1f,%.1f,%.1f) tick=%d %s" % [iss["kind"], iss["line"], p.x, p.y, p.z, int(iss["tick"]), iss["detail"]])
		_all_issues.append(iss)
	for rf: String in d.route_faults:
		print("BOTINFO routefault %s %s" % [d.line_name, rf])
	for ho: String in d.head_on_log:
		print("BOTINFO headon %s %s" % [d.line_name, ho])
	for inf: String in d.infos:
		print("BOTINFO %s %s" % [d.line_name, inf])
	for wt: String in d.wall_test_results:
		print("BOTINFO walltest %s %s" % [d.line_name, wt])
	if drv.wall_tests > d.wall_test_results.size():
		print("BOTINFO walltest %s %d test(s) run, %d slammed (the physics slam limit was not reached or the hit was not square)" % [d.line_name, drv.wall_tests, d.wall_test_results.size()])
	for k: String in d.suppressed:
		print("BOTISSUE %s %s pos=- tick=- (+%d more suppressed)" % [k, d.line_name, int(d.suppressed[k])])
	if _record and (not ok or not d.issues.is_empty()):
		_write_recording(d, res)
	_main.queue_free()
	_main = null
	_sk = null
	_det = null
	_driver = null


func _land_str(l: Dictionary) -> String:
	return "%d/%d/%d" % [int(l["clean"]), int(l["sketchy"]), int(l["bail"])]


func _write_recording(d: BotDetectors, res: Dictionary) -> void:
	var issues: Array = []
	for iss: Dictionary in d.issues:
		issues.append({"kind": iss["kind"], "pos": BotDetectors._encode({"p": iss["pos"]})["p"], "tick": iss["tick"], "detail": iss["detail"]})
	var rec: Dictionary = {
		"version": 1, "park": "main", "tick_rate": 60, "tuning": PhysicsTuning.shared().to_dict(), "line": d.line_name,
		"result": res, "issues": issues, "frames": d.frames, "snapshots": _snapshots,
	}
	var f: FileAccess = FileAccess.open("%s/%s.json" % [OUT_DIR, d.line_name], FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(rec))
		f.close()
		print("BOTINFO recorded %s/%s.json (%d frames)" % [OUT_DIR, d.line_name, d.frames.size()])


func _finish() -> void:
	_phase = "done"
	var penalty: float = 0.0
	var total: int = 0
	var counts: Dictionary = {}
	for r: Dictionary in _results:
		if not bool(r["ok"]):
			penalty += FAIL_PENALTY
		for k: String in r["issue_counts"]:
			var c: int = int((r["issue_counts"] as Dictionary)[k])
			total += c
			counts[k] = int(counts.get(k, 0)) + c
			penalty += float(PENALTY.get(k, 2.0)) * float(mini(c, 6))
	var score: int = clampi(int(round(100.0 - penalty)), 0, 100)
	var failed: int = 0
	var landed_sum: int = 0
	for r: Dictionary in _results:
		if not bool(r["ok"]):
			failed += 1
		landed_sum += int(r["landed_total"])
	print("BOT score=%d issues=%d lines=%d failed=%d landed_total=%d" % [score, total, _results.size(), failed, landed_sum])
	var issues_out: Array = []
	for iss: Dictionary in _all_issues:
		issues_out.append({"kind": iss["kind"], "line": iss["line"], "pos": BotDetectors._encode({"p": iss["pos"]})["p"], "tick": iss["tick"], "detail": iss["detail"]})
	var report: Dictionary = {
		"version": 1, "score": score, "issues": total, "issue_counts": counts, "landed_total": landed_sum, "lines": _results, "issue_list": issues_out,
		"tuning": _tune_note, "tuning_diff": PhysicsTuning.shared().diff_from_defaults(),
		"wall_seconds": snappedf(float(Time.get_ticks_msec() - _started_msec) / 1000.0, 0.1),
	}
	var f: FileAccess = FileAccess.open(OUT_DIR + ("/report.json" if _nshards == 1 else "/report_shard%d.json" % _shard), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	get_tree().quit(0)
