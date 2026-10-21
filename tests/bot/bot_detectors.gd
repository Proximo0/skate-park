class_name BotDetectors
extends RefCounted
## Watches the skater's per-tick debug frames (Skater.physics_ticked) and flags everything that would feel broken to a
## player: snags, hard stops, bails (with a cause), getting stuck, falling out of the world, jitter, on_floor flicker,
## teleport-sized jumps, overspeed and NaN. One instance per line.

const WINDOW: int = 15  ## 0.25 s of ticks for the snag window
const SNAG_DROP: float = 0.30
const SNAG_MIN_ENERGY: float = 20.0
const STUCK_TICKS: int = 120
const STUCK_MOVE: float = 0.3
const JUMP_LIMIT: float = 1.0
const MAX_PER_KIND: int = 6
const HEAD_ON_DEG: float = 55.0  ## a hit steeper than this to the wall is a crash, not a snag
const JITTER_Y_MIN: float = 0.012  ## peak-to-peak metres worth reporting (1.2 cm)
## Events that legitimately change energy, or move the skater, so a window holding one is not judged.
const EXCUSE_EVENTS: Array[String] = ["bail", "respawn", "grind", "grind_end", "lip", "wallride", "ollie", "dismount", "mount"]

var line_name: String = ""
var gravity: float = 18.0
var max_speed: float = 22.0
var kill_y: float = -20.0
var issues: Array[Dictionary] = []
var suppressed: Dictionary = {}  ## kind -> count beyond MAX_PER_KIND
var counts: Dictionary = {}  ## kind -> total
var bails: int = 0
var snags: int = 0
var max_speed_seen: float = 0.0
var max_height: float = -1000.0
var landings: Dictionary = {"clean": 0, "sketchy": 0, "bail": 0}
var gaps: Array[String] = []
var airtime_ticks: int = 0
var frames: Array = []  ## recorded debug dicts (only when record is true)
var record: bool = false
var bail_causes: Array[String] = []
var snaps: Array[float] = []  ## grind / lip entry jumps (by design: the visual catches up), metres
var route_faults: Array[String] = []  ## stops that look like the bot's own routing, not the physics
var wall_hits: int = 0

var _hist: Array[Dictionary] = []
var _cool: Dictionary = {}
var _intent_run: int = 0
var _pos_hist: Array[Vector3] = []
var _flip_hist: Array[int] = []
var _n_jit: Array[int] = []
var _air_run: int = 0
var _air_by_ollie: bool = false
var _last_land: String = ""
var _last_land_tick: int = -100
var _tick_dt: float = 1.0 / 60.0
var _prev_raw: Dictionary = {}
var _headon_tick: int = -1000
var _headon_hit: String = ""
var _d_hist: Array[Vector3] = []
var _y_hist: Array[float] = []


func _init(name_in: String, tune: PhysicsTuning, record_frames: bool) -> void:
	line_name = name_in
	gravity = tune.gravity
	max_speed = tune.max_speed
	kill_y = tune.kill_y
	record = record_frames


## Forget the previous frames (the bot teleported the skater).
func reset_history() -> void:
	_hist.clear()
	_pos_hist.clear()
	_flip_hist.clear()
	_n_jit.clear()
	_intent_run = 0
	_air_run = 0


func on_gap(gap_name: String) -> void:
	gaps.append(gap_name)


func feed(f: Dictionary, moving_intent: bool, bot_teleported: bool, hit: Dictionary = {}) -> void:
	var tick: int = int(f["tick"])
	var pos: Vector3 = f["pos"]
	var vel: Vector3 = f["vel"]
	var speed: float = float(f["speed"])
	var state: String = f["state"]
	var evs: Array[String] = []
	for e: Variant in f["events"]:
		evs.append(str(e))
	if record:
		frames.append(_encode(f))
	if bot_teleported:
		reset_history()
	# --- NaN / overspeed (always)
	if not (is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z) and is_finite(vel.x) and is_finite(vel.y) and is_finite(vel.z)):
		_issue("nan", pos, tick, "pos=%s vel=%s state=%s" % [pos, vel, state])
		return
	max_speed_seen = maxf(max_speed_seen, speed)
	max_height = maxf(max_height, pos.y)
	if speed > max_speed + 0.05 and _ready("overspeed", tick, 120):
		_issue("overspeed", pos, tick, "speed=%.2f max=%.1f state=%s events=%s" % [speed, max_speed, state, evs])
	for e: String in evs:
		if e.begins_with("land:"):
			var r: String = e.substr(5)
			landings[r] = int(landings.get(r, 0)) + 1
			_last_land = r
			_last_land_tick = tick
	if state == "AIR":
		airtime_ticks += 1
	# --- fell out of the world / respawned
	if evs.has("respawn") and not bot_teleported:
		_issue("respawn", pos, tick, "respawned at y=%.1f prev=%s" % [pos.y, _prev_summary()])
	elif pos.y < kill_y + 2.0 and _ready("kill", tick, 600):
		_issue("below_kill_plane", pos, tick, "y=%.1f kill_y=%.1f state=%s" % [pos.y, kill_y, state])
	var prev: Dictionary = _hist[_hist.size() - 1] if not _hist.is_empty() else {}
	# --- teleport-sized jump (a grind or lip snap is by design: the visual catches up through _snap_offset)
	if not prev.is_empty():
		var jump: float = pos.distance_to(prev["pos"])
		if jump > JUMP_LIMIT and not evs.has("respawn"):
			if (evs.has("grind") or evs.has("lip")) and jump < 1.8:
				snaps.append(jump)
			elif _ready("teleport", tick, 30):
				_issue("teleport", pos, tick, "moved %.2f m in one tick from %s state=%s->%s events=%s" % [jump, prev["pos"], prev["state"], state, evs])
	# --- bail with cause
	if state == "BAIL" and (prev.is_empty() or str(prev["state"]) != "BAIL"):
		bails += 1
		_issue("bail", pos, tick, _bail_cause(f, prev, evs))
	# --- build this tick's lite record
	var excuse: bool = state in ["BAIL", "GRIND", "LIP", "WALLRIDE"] or bool(f["braking"])
	for e: String in evs:
		if EXCUSE_EVENTS.has(e) or e.begins_with("land:"):
			excuse = true
	var energy: float = 0.5 * speed * speed + gravity * pos.y
	var cur: Dictionary = {"tick": tick, "pos": pos, "vel": vel, "speed": speed, "state": state, "on_floor": bool(f["on_floor"]),
		"n": f["floor_normal"], "ex": excuse, "E": energy, "events": evs, "braking": bool(f["braking"]), "hit": str(hit.get("name", "")), "hitn": hit.get("n", Vector3.ZERO)}
	_hist.append(cur)
	if _hist.size() > 200:
		_hist.pop_front()
	_prev_raw = f
	_snag_and_stop(cur, f)
	_stuck(cur, moving_intent and state != "BAIL")
	_jitter(cur, f)
	_flicker(cur)


func _snag_and_stop(cur: Dictionary, f: Dictionary) -> void:
	var n: int = _hist.size()
	if n < 3:
		return
	var tick: int = int(cur["tick"])
	var emax: float = -INF
	var vmax: float = 0.0
	var fast: Dictionary = cur
	var excused: bool = false
	var start: int = maxi(0, n - 1 - WINDOW)
	for i: int in range(start, n):
		var h: Dictionary = _hist[i]
		emax = maxf(emax, float(h["E"]))
		if float(h["speed"]) > vmax:
			vmax = float(h["speed"])
			fast = h
		if bool(h["ex"]):
			excused = true
	var e_now: float = float(cur["E"])
	var snag: bool = not excused and emax > SNAG_MIN_ENERGY and (emax - e_now) > SNAG_DROP * emax
	# (running out of speed at the top of a steep face is the turnaround, not a stop)
	var apex: bool = (cur["n"] as Vector3).y < 0.5 and (fast["vel"] as Vector3).y > 0.5
	var stop: bool = str(cur["state"]) == "ROLLING" and not excused and not apex and vmax > 4.0 and float(cur["speed"]) < 1.0
	if not snag and not stop:
		return
	# what did it hit, and how squarely? A square hit on a wall is a crash (expected), a glancing one is a snag.
	var hit: String = ""
	var incidence: float = -1.0
	var hn: Vector3 = Vector3.ZERO
	for i: int in range(n - 1, maxi(-1, n - 1 - WINDOW), -1):
		var hh: Dictionary = _hist[i]
		if str(hh["hit"]) != "" and absf((hh["hitn"] as Vector3).y) < 0.5:
			hit = str(hh["hit"])
			hn = hh["hitn"]
			break
	if hit == "":
		hit = _recent_hit_name(WINDOW)
	var vdir: Vector3 = (fast["vel"] as Vector3)
	if hn != Vector3.ZERO and vdir.length() > 0.5:
		incidence = rad_to_deg(asin(clampf(absf(vdir.normalized().dot(hn)), 0.0, 1.0)))
	var detail_tail: String = " hit=%s n=%s incidence=%s" % [hit, _v(hn), ("%.0fdeg (0=grazing, 90=head-on)" % incidence) if incidence >= 0.0 else "n/a"]
	if incidence >= HEAD_ON_DEG:
		wall_hits += 1
		_headon_tick = tick
		_headon_hit = hit
		return
	if snag and _ready("snag", tick, 40):
		snags += 1
		_issue("snag", cur["pos"], tick, "energy %.1f -> %.1f (-%.0f%%) in %.2fs; speed %.1f -> %.1f state=%s on_wall=%s events=%s%s" % [
			emax, e_now, 100.0 * (emax - e_now) / emax, float(n - start) * _tick_dt, vmax, float(cur["speed"]), cur["state"],
			f["on_wall"], _recent_events(WINDOW), detail_tail])
	if stop and _ready("hard_stop", tick, 90):
		_issue("hard_stop", cur["pos"], tick, "speed %.1f -> %.2f within 0.25s while ROLLING on_wall=%s floor_n=%s events=%s%s" % [
			vmax, float(cur["speed"]), f["on_wall"], _v(f["floor_normal"]), _recent_events(WINDOW), detail_tail])


func _stuck(cur: Dictionary, intent: bool) -> void:
	_pos_hist.append(cur["pos"])
	if _pos_hist.size() > STUCK_TICKS + 1:
		_pos_hist.pop_front()
	var st: String = cur["state"]
	if intent and st in ["ROLLING", "AIR"]:
		_intent_run += 1
	else:
		_intent_run = 0
		return
	if _intent_run >= STUCK_TICKS and _pos_hist.size() > STUCK_TICKS:
		var lo: Vector3 = _pos_hist[0]
		var hi: Vector3 = _pos_hist[0]
		for p: Vector3 in _pos_hist:
			lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
			hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
		var span: float = lo.distance_to(hi)
		var tick: int = int(cur["tick"])
		if span < STUCK_MOVE and _ready("stuck", tick, 240):
			if tick - _headon_tick < 400:
				# pinned after a square wall hit: the route ran into something, the physics did what a wall does
				route_faults.append("stuck at %s after a head-on hit on %s" % [_v(cur["pos"]), _headon_hit])
			else:
				_issue("stuck", cur["pos"], tick, "moved %.2f m (whole window) in 2 s while trying to move; state=%s speed=%.2f floor_n=%s%s" % [span, st, float(cur["speed"]), _v(cur["n"]), _recent_hit(60)])


func _jitter(cur: Dictionary, f: Dictionary) -> void:
	var n: int = _hist.size()
	if n < 2:
		return
	var prev: Dictionary = _hist[n - 2]
	var tick: int = int(cur["tick"])
	var flat_both: bool = str(cur["state"]) == "ROLLING" and str(prev["state"]) == "ROLLING" and bool(cur["on_floor"]) and bool(prev["on_floor"]) \
		and (cur["n"] as Vector3).y > 0.995 and (prev["n"] as Vector3).y > 0.995 and float(cur["speed"]) > 1.5
	# floor normal flapping: tick-to-tick changes that reverse direction (a surface curving away is monotonic, not jitter)
	var dn: Vector3 = Vector3.ZERO
	if flat_both:
		dn = (cur["n"] as Vector3) - (prev["n"] as Vector3)
	_d_hist.append(dn)
	if _d_hist.size() > 20:
		_d_hist.pop_front()
	var reversals: int = 0
	for i: int in range(1, _d_hist.size()):
		var a: Vector3 = _d_hist[i - 1]
		var b: Vector3 = _d_hist[i]
		if a.length() > 0.01 and b.length() > 0.01 and a.dot(b) < 0.0:
			reversals += 1
	if reversals >= 3 and _ready("jitter_normal", tick, 120):
		_issue("jitter_normal", cur["pos"], tick, "floor normal reverses direction %d times in 20 ticks on flat ground; n=%s prev=%s" % [reversals, _v(cur["n"]), _v(prev["n"])])
	# height oscillation on flat ground
	var sgn: int = 0
	var y: float = (cur["pos"] as Vector3).y
	if flat_both:
		var dy: float = y - (prev["pos"] as Vector3).y
		if absf(dy) > 0.003:
			sgn = 1 if dy > 0.0 else -1
	_flip_hist.append(sgn)
	_y_hist.append(y if flat_both else NAN)
	if _flip_hist.size() > 24:
		_flip_hist.pop_front()
		_y_hist.pop_front()
	var flips: int = 0
	var last: int = 0
	for s: int in _flip_hist:
		if s != 0:
			if last != 0 and s != last:
				flips += 1
			last = s
	var ylo: float = INF
	var yhi: float = -INF
	var contiguous: bool = _y_hist.size() >= 24
	for yy: float in _y_hist:
		if is_nan(yy):
			contiguous = false
		else:
			ylo = minf(ylo, yy)
			yhi = maxf(yhi, yy)
	if contiguous and flips >= 5 and yhi - ylo >= JITTER_Y_MIN and _ready("jitter_y", tick, 120):
		_issue("jitter_y", cur["pos"], tick, "height flips direction %d times in 24 ticks on flat ground, peak-to-peak %.1f mm" % [flips, (yhi - ylo) * 1000.0])


## on_floor on / off / on within 3 ticks with no jump: the board is hopping on the ground.
func _flicker(cur: Dictionary) -> void:
	var n: int = _hist.size()
	if n < 4 or not bool(cur["on_floor"]):
		return
	var tick: int = int(cur["tick"])
	var off_run: int = 0
	var i: int = n - 2
	while i >= 0 and not bool(_hist[i]["on_floor"]) and off_run < 4:
		off_run += 1
		i -= 1
	if off_run == 0 or off_run > 2 or i < 0 or not bool(_hist[i]["on_floor"]):
		return
	for k: int in range(i, n):
		var h: Dictionary = _hist[k]
		if bool(h["ex"]) or float(h["speed"]) < 2.0:
			return
		for e: String in h["events"]:
			if e == "air":
				if (h["vel"] as Vector3).y > 1.5:
					return
	if _ready("floor_flicker", tick, 20):
		_issue("floor_flicker", cur["pos"], tick, "on_floor off for %d tick(s) at speed %.1f state=%s floor_n=%s events=%s" % [off_run, float(cur["speed"]), cur["state"], _v(cur["n"]), _recent_events(4)])


func _bail_cause(f: Dictionary, prev: Dictionary, evs: Array[String]) -> String:
	var prev_state: String = str(prev.get("state", "?"))
	var cause: String = ""
	var fn: Vector3 = f["floor_normal"]
	var vel: Vector3 = f["vel"]
	# a landing is judged with the pose and velocity of the tick before it
	var pr: Dictionary = _prev_raw if not _prev_raw.is_empty() else f
	var up_dot: float = (pr["board_up"] as Vector3).normalized().dot(fn.normalized())
	var pv: Vector3 = (pr["vel"] as Vector3)
	var fv: Vector3 = pv - fn * pv.dot(fn)
	var ff: Vector3 = (pr["facing"] as Vector3) - fn * (pr["facing"] as Vector3).dot(fn)
	var heading: float = 0.0
	if fv.length() > 0.1 and ff.length() > 0.1:
		heading = rad_to_deg(acos(clampf(ff.normalized().dot(fv.normalized()), -1.0, 1.0)))
	if evs.has("land:bail") or (_last_land == "bail" and int(f["tick"]) - _last_land_tick < 3):
		var why: String = "board tilted" if up_dot < 0.5 else ("sideways" if heading > 80.0 and heading < 100.0 else ("mid-flip" if str(pr["anim"]).begins_with("flip") else "?"))
		cause = "land:bail [%s] (board_up.floor_n=%.2f need>=0.5, heading_vs_velocity=%.0fdeg need<=80 or >=100, anim=%s, landing speed=%.1f, floor_n=%s, launch_normal=%s, vert_air=%s)" % [
			why, up_dot, heading, pr["anim"], pv.length(), _v(fn), _v(pr["launch_normal"]), pr["vert_air"]]
	elif prev_state in ["GRIND", "MANUAL", "LIP"]:
		cause = "balance_fail while " + prev_state
	elif bool(f["on_wall"]):
		cause = "wall_hit wall_n=%s" % _v(f["wall_normal"])
	else:
		cause = "unknown (prev_state=%s)" % prev_state
	bail_causes.append(cause)
	return "%s; prev_state=%s speed=%.1f vel=%s events=%s" % [cause, prev_state, float(f["speed"]), _v(vel), evs]


func _prev_summary() -> String:
	if _hist.is_empty():
		return "-"
	var h: Dictionary = _hist[_hist.size() - 1]
	return "state=%s pos=%s speed=%.1f" % [h["state"], _v(h["pos"]), float(h["speed"])]


func _recent_hit_name(n: int) -> String:
	for i: int in range(_hist.size() - 1, maxi(-1, _hist.size() - 1 - n), -1):
		var h: String = str(_hist[i]["hit"])
		if h != "":
			return h
	return ""


func _recent_hit(n: int) -> String:
	for i: int in range(_hist.size() - 1, maxi(-1, _hist.size() - 1 - n), -1):
		var h: String = str(_hist[i]["hit"])
		if h != "":
			return " hit=" + h
	return ""


func _recent_events(n: int) -> String:
	var out: Array[String] = []
	for i: int in range(maxi(0, _hist.size() - n), _hist.size()):
		for e: String in _hist[i]["events"]:
			out.append(e)
	return str(out)


func _ready(kind: String, tick: int, cooldown: int) -> bool:
	if _cool.has(kind) and tick - int(_cool[kind]) < cooldown:
		return false
	_cool[kind] = tick
	return true


func _issue(kind: String, pos: Vector3, tick: int, detail: String) -> void:
	counts[kind] = int(counts.get(kind, 0)) + 1
	if int(counts[kind]) > MAX_PER_KIND:
		suppressed[kind] = int(suppressed.get(kind, 0)) + 1
		return
	issues.append({"kind": kind, "line": line_name, "pos": pos, "tick": tick, "detail": detail})


static func _v(v: Variant) -> String:
	var x: Vector3 = v
	return "(%.2f,%.2f,%.2f)" % [x.x, x.y, x.z]


## A debug frame as plain JSON-able values (Vector3 -> [x, y, z]).
static func _encode(f: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in f:
		var v: Variant = f[k]
		if v is Vector3:
			out[k] = [snappedf((v as Vector3).x, 0.0001), snappedf((v as Vector3).y, 0.0001), snappedf((v as Vector3).z, 0.0001)]
		elif v is Vector2:
			out[k] = [(v as Vector2).x, (v as Vector2).y]
		elif v is Array:
			out[k] = (v as Array).duplicate()
		else:
			out[k] = v
	return out
