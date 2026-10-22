class_name BotDriver
extends RefCounted
## The play-bot's hands: a waypoint follower plus a small action machine, feeding Skater.set_input() once per
## physics tick the way a player's thumbs would (stick + just-pressed + held buttons). It only reads what a player
## can see (position, speed, state, the balance meter), never the skater's private ride vars.
##
## A waypoint is a Dictionary:
##   p: Vector3 (x, z matter)   spd: target speed (push below it)   r: reach radius (default 2.0)
##   act: action started when the waypoint is reached (it runs while the bot steers on to the next waypoint):
##        "ollie" {h: hold ticks, flip, grab, revert}   "air" {flip, grab, revert, wait: s}  (waits for takeoff)
##        "grind" {exit: "ride"|"ollie", end: Vector3, hold: s}   "manual" {dur: s, exit: "ollie"|"none"}
##        "revert"   "wait" {s}
##   pump: hold forward on transitions   brake: allow braking above spd   tmo: seconds before the waypoint is skipped
##   tp: {pos, dir, speed}: teleport there (a segment start); the waypoint is consumed at once.
##   drop: "mega"|"loop": the pause-menu drop-in, then the waypoint is consumed.

const UPV: Vector3 = Vector3.UP
const KP_STEER: float = 2.2
const PUSH_BELOW: float = 0.4  ## push when this far under the target speed
const DEFAULT_R: float = 2.0
const DEFAULT_TMO: float = 14.0
const GIVE_UP_TICKS: int = 150
const BAL_K1: float = 3.0
const BAL_K2: float = 1.1
const TP_WAIT_MAX: int = 240  ## ticks (4 s) a teleport waits for an open combo to land before it goes ahead anyway

var sk: Skater
var park: Node
var wps: Array = []
var idx: int = 0
var finished: bool = false
var ticks: int = 0
var skipped: Array[String] = []  ## waypoints that timed out
var notes: Array[String] = []
var moving_intent: bool = true  ## false while the bot is deliberately holding still (stuck detector reads it)
var teleported: bool = false  ## set on the tick the bot moved the skater itself (detectors skip it)
var grind_ticks: int = 0
var manual_ticks: int = 0
var pipe: Dictionary = {}  ## active pump-the-pipe mode (from a waypoint's `pipe`): {axis: "x"|"z", lane, ref, min_y, want}
var peaks: Array[float] = []
var wall_test: bool = false  ## true while the active waypoint is a deliberate head-on wall test (its slam is expected)
var wall_tests: int = 0  ## wall tests started
var misses: Array[String] = []  ## actions that did not take (ollie never left the ground, grind never caught)

var _act: Dictionary = {}
var _wp_t: float = 0.0
var _prev_p: Vector3 = Vector3.ZERO
var _have_prev: bool = false
var _rising: bool = false
var _seg_max: float = 0.0
var _pipe_dir: float = 1.0
var _prev_state: String = "ROLLING"
var _revert_in: int = -1
var _want_revert: bool = false
var _manual_wanted: bool = false
var _pos_ring: Array[Vector3] = []
var _since_push: int = 100
var _stick: Vector2 = Vector2.ZERO
var _pressed: Array = []
var _held: Array = []
var _tp_wait: int = 0  ## ticks spent holding a teleport for the open combo to land


func _init(skater: Skater, park_node: Node, waypoints: Array) -> void:
	sk = skater
	park = park_node
	wps = waypoints


## Advance one tick. Call before the skater's own physics step.
func step(delta: float) -> void:
	teleported = false
	var d: Dictionary = sk.debug
	if d.is_empty():
		sk.set_input(Vector2.ZERO, [], [])
		return
	ticks += 1
	moving_intent = true
	var st: String = d["state"]
	var pos: Vector3 = d["pos"]
	_stick = Vector2.ZERO
	_pressed = []
	_held = []
	_watch_stuck(st, pos)
	if not _consume_special(pos):
		# a teleport is held while a combo is open: respawn() would wipe its points (see teleport)
		moving_intent = false
		_pos_ring.clear()
		_prev_state = st
		sk.set_input(Vector2.ZERO, [], [])
		return
	if finished and st == "ROLLING":
		sk.set_input(Vector2.ZERO, [], [])
		moving_intent = false
		return
	if not pipe.is_empty():
		_record_peak(d)
	if _prev_state == "GRIND" and st != "GRIND" and str(_act.get("kind", "")) == "grind":
		_act = {}
	if _prev_state == "MANUAL" and st != "MANUAL" and str(_act.get("kind", "")) in ["manual", "manual_unwanted"]:
		_act = {}
	match st:
		"BAIL":
			moving_intent = false
			_act = {}
			if wall_test:
				# the test did its job: go on to the next segment (this is not a timeout)
				wall_test = false
				_end_segment()
		"GRIND":
			grind_ticks += 1
			_stick.x = _balance_stick(true)
			_grind_exit(d)
		"MANUAL":
			manual_ticks += 1
			_stick.y = _balance_stick(false)
			_manual_hold()
		"LIP":
			_stick.x = _balance_stick(true)
			if int(_act.get("lip_t", 0)) > 40:
				_pressed.append("ollie")
				_held.append("ollie")
			_act["lip_t"] = int(_act.get("lip_t", 0)) + 1
		"AIR":
			_air_input(d)
		"WALLRIDE":
			pass
		_:
			_ground_input(d, delta)
	_prev_state = st
	sk.set_input(_stick, _pressed, _held)


## Gives up on a segment when pinned in place (the detectors report why); the bot is not meant to sit there for ever.
func _watch_stuck(st: String, pos: Vector3) -> void:
	if st != "ROLLING" or not moving_intent or not pipe.is_empty() or str(_act.get("kind", "")) == "wait":
		_pos_ring.clear()
		return
	_pos_ring.append(pos)
	if _pos_ring.size() > GIVE_UP_TICKS:
		_pos_ring.pop_front()
	if _pos_ring.size() >= GIVE_UP_TICKS:
		var lo: Vector3 = _pos_ring[0]
		var hi: Vector3 = _pos_ring[0]
		for p: Vector3 in _pos_ring:
			lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
			hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
		if lo.distance_to(hi) < 0.4:
			notes.append("gave_up_segment_at_" + _fmt(pos))
			_skip_segment("stuck")
			_pos_ring.clear()


## Drops the rest of the current segment (up to the next teleport / drop-in).
func _skip_segment(why: String) -> void:
	skipped.append("%s@wp%d" % [why, idx])
	idx += 1
	while idx < wps.size() and not (wps[idx] as Dictionary).has("tp") and not (wps[idx] as Dictionary).has("drop"):
		idx += 1
	_wp_t = 0.0
	_act = {}
	_have_prev = false
	if idx >= wps.size():
		finished = true


## Moves on to the next segment without logging a skip.
func _end_segment() -> void:
	idx += 1
	while idx < wps.size() and not (wps[idx] as Dictionary).has("tp") and not (wps[idx] as Dictionary).has("drop"):
		idx += 1
	_wp_t = 0.0
	_act = {}
	_have_prev = false
	if idx >= wps.size():
		finished = true


## Teleport / drop-in waypoints take effect without a tick of their own. Returns false while a teleport is held
## for an open combo to land (the caller then idles this tick).
func _consume_special(pos: Vector3) -> bool:
	while idx < wps.size():
		var wp: Dictionary = wps[idx]
		if wp.has("tp"):
			if sk.combo.is_active():
				if _tp_wait < TP_WAIT_MAX:
					_tp_wait += 1
					return false
				notes.append("tp_forced_with_combo_open")
			_tp_wait = 0
			var tp: Dictionary = wp["tp"]
			teleport(tp["pos"], tp["dir"], float(tp.get("speed", 0.0)))
			_next(true)
			_prev_p = tp["pos"]
			_have_prev = true
		elif wp.has("drop"):
			var spots: Dictionary = park.get("drop_ins") as Dictionary
			DropIn.teleport(sk, spots[wp["drop"]] as Transform3D)
			teleported = true
			_act = {}
			_next(true)
		else:
			break
	if idx >= wps.size():
		finished = true
	return true


func teleport(pos: Vector3, dir: Vector3, speed: float) -> void:
	# respawn() bails the combo, so the caller has already let any open combo land (see _consume_special)
	sk.respawn()
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	var p: Vector3 = pos
	# stand on whatever surface is under the point (a ramp, a roof), never inside it
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pos + UPV * 3.0, pos - UPV * 40.0, 1)
	var hit: Dictionary = sk.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		p.y = (hit["position"] as Vector3).y + 0.1
	sk.global_transform = Transform3D(Basis.looking_at(d, UPV), p)
	sk.velocity = d * speed
	sk.facing = d
	sk.speed = speed
	teleported = true
	_act = {}
	wall_test = false
	_have_prev = false
	_pipe_dir = 1.0
	_pos_ring.clear()


func _next(silent: bool = false) -> void:
	if idx < wps.size():
		var wp: Dictionary = wps[idx]
		if wp.has("p"):
			_prev_p = wp["p"]
			_have_prev = true
	idx += 1
	_wp_t = 0.0
	if idx >= wps.size() and not silent:
		finished = true


# --- ground -------------------------------------------------------------------------------------------

func _ground_input(d: Dictionary, delta: float) -> void:
	var pos: Vector3 = d["pos"]
	var speed: float = d["speed"]
	var fn: Vector3 = d["floor_normal"]
	var kind: String = str(_act.get("kind", ""))
	# --- the active action may own the buttons this tick
	match kind:
		"ollie":
			_ollie_step(d)
		"air":
			# waiting for takeoff: keep riding
			_act["t"] = int(_act["t"]) + 1
			if float(_act["t"]) * delta > float(_act.get("wait", 3.0)):
				misses.append("air_never_left_ground at " + _fmt(pos))
				_act = {}
		"grind":
			if int(_act["t"]) == 0:
				_pressed.append("grind")
			_held.append("grind")
			_act["t"] = int(_act["t"]) + 1
			if int(_act["t"]) > 14:
				var rail_d: float = _dist_to_end_rail(pos)
				misses.append("grind_press_no_catch at %s dist_to_rail=%.2f" % [_fmt(pos), rail_d])
				_act = {}
		"manual":
			_manual_sequence()
		"revert":
			if int(_act["t"]) == 1:
				_pressed.append("revert")
				_held.append("revert")
			_act["t"] = int(_act["t"]) + 1
			if int(_act["t"]) > 3:
				_act = {}
		"wait":
			moving_intent = false
			_act["t"] = int(_act["t"]) + 1
			if float(_act["t"]) * delta >= float(_act["s"]):
				_act = {}
	# revert queued after a landing
	if _revert_in >= 0:
		_revert_in -= 1
		if _revert_in == 0:
			_pressed.append("revert")
			_held.append("revert")
	if idx >= wps.size():
		finished = true
		return
	var wp: Dictionary = wps[idx]
	_wp_t += delta
	if bool(wp.get("wall_test", false)) and not wall_test:
		wall_test = true
		wall_tests += 1
	if wp.has("pipe") and pipe.is_empty():
		pipe = wp["pipe"]
		peaks = []
		_rising = false
		_seg_max = -1000.0
	if not pipe.is_empty() and _wp_t > float(wp.get("tmo", 40.0)):
		notes.append("pipe_timeout_after_%d_peaks" % peaks.size())
		pipe = {}
		_next()
		return
	var target: Vector3 = wp["p"]
	var to: Vector3 = target - pos
	to.y = 0.0
	var dist: float = to.length()
	var reach: float = float(wp.get("r", DEFAULT_R))
	if str(wp.get("act", "")) == "ollie":
		# the waypoint is where the board should pop: start the crouch early by the distance rolled while holding it
		reach += float(wp.get("h", 7)) / 60.0 * speed
	var passed: bool = false
	if _have_prev:
		var seg: Vector3 = target - _prev_p
		seg.y = 0.0
		if seg.length() > 1.0 and dist < maxf(reach * 3.0, 6.0):
			var along: float = (pos - target).dot(seg.normalized())
			passed = along > 0.0
	if not pipe.is_empty():
		passed = false
		dist = 1e9
	if bool(wp.get("hold", false)):
		# ride straight for hold_s seconds (up a wall and back), then carry on with the next waypoint
		if _wp_t > float(wp.get("hold_s", 1.5)):
			_reach(wp, d)
		else:
			_stick.x = 0.0
			return
		if finished or idx >= wps.size():
			return
		wp = wps[idx]
		if wp.has("tp") or wp.has("drop"):
			return
		target = wp["p"]
		to = target - pos
		to.y = 0.0
	elif dist < reach or passed:
		_reach(wp, d)
		if finished or idx >= wps.size():
			return
		wp = wps[idx]
		if wp.has("tp") or wp.has("drop"):
			return
		target = wp["p"]
		to = target - pos
		to.y = 0.0
	elif _wp_t > float(wp.get("tmo", DEFAULT_TMO)):
		_skip_segment("timeout@" + _fmt(target))
		return
	# steering
	if not pipe.is_empty():
		to = _pipe_target(d) - pos
		to.y = 0.0
		dist = 1e9
	_stick.x = _steer(d, to)
	if kind == "air":
		_stick.x = 0.0
	# speed control
	var want: float = float(wp.get("spd", 9.0))
	var flat: bool = bool(d["on_floor"]) and fn.y > 0.8
	_since_push += 1
	if flat and kind != "manual":
		if speed < want - PUSH_BELOW:
			_stick.y = -1.0
			_since_push = 0
		elif bool(wp.get("brake", false)) and speed > want + 4.0 and kind == "" and _since_push > 25:
			# (pushing then pulling back inside 20 ticks is the manual input, so wait it out first)
			_stick.y = 0.7
	if bool(wp.get("pump", false)) and fn.y < 0.95 and fn.y > 0.15 and speed < float(wp.get("pump_max", 14.0)):
		_stick.y = -1.0
	if not pipe.is_empty():
		_stick.y = -1.0
		if pipe.has("no_push_above") and pos.y > float(pipe["no_push_above"]):
			_stick.y = 0.0  # no pumping at the lip: it throws the rider over the coping


func _reach(wp: Dictionary, d: Dictionary) -> void:
	var act: String = str(wp.get("act", ""))
	_next()
	if act == "":
		return
	var a: Dictionary = wp.duplicate()
	a["kind"] = act
	a["t"] = 0
	match act:
		"ollie":
			a["h"] = int(wp.get("h", 7))
		"air":
			pass
		"grind":
			pass
		"manual":
			a["phase"] = 0
		"wait":
			a["s"] = float(wp.get("s", 1.0))
	_act = a
	_want_revert = bool(wp.get("revert", false))


func _steer(d: Dictionary, to: Vector3) -> float:
	var f: Vector3 = d["facing"]
	f.y = 0.0
	if f.length() < 0.25 or to.length() < 0.2:
		return 0.0
	var ang: float = f.normalized().signed_angle_to(to.normalized(), UPV)
	return clampf(-KP_STEER * ang, -1.0, 1.0)


# --- actions ------------------------------------------------------------------------------------------

func _ollie_step(d: Dictionary) -> void:
	var t: int = int(_act["t"])
	var h: int = int(_act["h"])
	if t < h:
		_held.append("ollie")
		if t == 0:
			_pressed.append("ollie")
	elif t == h:
		if bool(_act.get("flip", false)):
			_pressed.append("flip")
			_held.append("flip")
	elif t > h + 4 and str(d["state"]) == "ROLLING":
		misses.append("ollie_never_left_ground at " + _fmt(d["pos"]))
		_act = {}
		return
	_act["t"] = t + 1


func _air_input(d: Dictionary) -> void:
	var kind: String = str(_act.get("kind", ""))
	var vy: float = (d["vel"] as Vector3).y
	if kind == "ollie" or kind == "air":
		var at: int = int(_act.get("air_t", 0))
		_act["air_t"] = at + 1
		if kind == "air" and at == 0 and bool(_act.get("flip", false)):
			_pressed.append("flip")
			_held.append("flip")
		if bool(_act.get("grab", false)) and not bool(_act.get("grab_done", false)):
			if at >= 4 and vy > -2.0:
				if not _act.has("grab_started"):
					_act["grab_started"] = true
					_pressed.append("grab")
				_held.append("grab")
			elif _act.has("grab_started"):
				_act["grab_done"] = true
	if (kind == "ollie" or kind == "air") and bool(_act.get("man", false)):
		# pull N then S in the last few ticks of the fall, so the sequence is fresh when the wheels touch down
		if vy < -1.5 and not _act.has("man_t") and _ground_dist(d) < maxf(0.4, -vy * 0.15):
			_act["man_t"] = 0
		if _act.has("man_t"):
			var mt: int = int(_act["man_t"])
			_act["man_t"] = mt + 1
			_stick.y = -1.0 if mt < 3 else 1.0
	# air steering: only gentle, never past the spin threshold
	var wp: Dictionary = wps[idx] if idx < wps.size() else {}
	if not wp.is_empty() and wp.has("p") and not bool(d["vert_air"]):
		var to: Vector3 = (wp["p"] as Vector3) - (d["pos"] as Vector3)
		to.y = 0.0
		_stick.x = clampf(_steer_raw(d, to), -0.3, 0.3)


## Height above whatever is under the skater (a ray straight down, world layer), 99 when nothing is there.
func _ground_dist(d: Dictionary) -> float:
	var p: Vector3 = d["pos"]
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + UPV * 0.3, p - UPV * 60.0, 1)
	var hit: Dictionary = sk.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return 99.0
	return p.y - (hit["position"] as Vector3).y


func _steer_raw(d: Dictionary, to: Vector3) -> float:
	var v: Vector3 = d["vel"]
	v.y = 0.0
	if v.length() < 0.5 or to.length() < 0.2:
		return 0.0
	return clampf(-KP_STEER * v.normalized().signed_angle_to(to.normalized(), UPV), -1.0, 1.0)


## Called by the runner on a landing event so a revert can follow it.
func on_landed() -> void:
	if _want_revert:
		_revert_in = 3
		_want_revert = false
	var kind: String = str(_act.get("kind", ""))
	if (kind == "ollie" or kind == "air") and bool(_act.get("man", false)):
		_act = {"kind": "manual", "dur": float(_act.get("dur", 1.5)), "exit": str(_act.get("exit", "ollie")), "mt": 0, "t": 99}
	elif kind in ["ollie", "air"]:
		_act = {}


func _manual_sequence() -> void:
	var t: int = int(_act["t"])
	_act["t"] = t + 1
	_manual_wanted = true
	# release to neutral first: the physics only counts a short N flick (a held push straight into S is riding)
	if t < 2:
		_stick.y = 0.0
	elif t < 5:
		_stick.y = -1.0
	else:
		_stick.y = 1.0
	if t > 40:
		misses.append("manual_never_started")
		_act = {}


func _manual_hold() -> void:
	if str(_act.get("kind", "")) == "manual":
		_act["mt"] = int(_act.get("mt", 0)) + 1
		var done: bool = float(int(_act["mt"])) / 60.0 >= float(_act.get("dur", 2.0))
		if _act.has("exit_p"):
			# leave the manual at a spot (dur is then the longest it may last)
			var e: Vector3 = _act["exit_p"]
			var p: Vector3 = sk.global_position
			if Vector2(p.x - e.x, p.z - e.z).length() < 0.2 + sk.speed * 0.02:
				done = true
		if done:
			var ex: String = str(_act.get("exit", "ollie"))
			if ex == "ollie" or ex == "ollie_man":
				_pressed.append("ollie")
				_held.append("ollie")
			if ex == "ollie_man":
				# hop and land in the next manual (the gap needs MANUAL on entering both zones)
				_act = {"kind": "ollie", "man": true, "dur": float(_act.get("dur2", 1.0)), "exit": "ollie", "t": 99, "h": 1}
			else:
				_act = {}
	elif int(_act.get("unwanted", 0)) == 0:
		# a manual the bot did not ask for (push then pull back): note it and ride it out
		_act = {"kind": "manual_unwanted", "unwanted": 1, "mt": 0}
		notes.append("unrequested_manual")
	else:
		_act["mt"] = int(_act.get("mt", 0)) + 1
		if int(_act["mt"]) > 45:
			_pressed.append("ollie")
			_held.append("ollie")


func _grind_exit(d: Dictionary) -> void:
	if str(_act.get("kind", "")) == "grind":
		_act["gt"] = int(_act.get("gt", 0)) + 1
		var done: bool = false
		if str(_act.get("exit", "ride")) == "ollie" and _act.has("end"):
			var e: Vector3 = _act["end"]
			var p: Vector3 = d["pos"]
			var v: float = maxf(float(d["speed"]), 1.0)
			if Vector2(p.x - e.x, p.z - e.z).length() < 0.15 + v * 0.02:
				done = true
		if _act.has("hold") and float(int(_act["gt"])) / 60.0 >= float(_act["hold"]):
			done = true
		if done:
			_pressed.append("ollie")
			_held.append("ollie")
			_act = {}


func _balance_stick(horizontal: bool) -> float:
	var u: float = clampf(BAL_K1 * sk.balance.angle + BAL_K2 * sk.balance.velocity, -1.0, 1.0)
	return -u if horizontal else u


func _dist_to_end_rail(pos: Vector3) -> float:
	var best: float = INF
	for n: Node in sk.get_tree().get_nodes_in_group("grind_rail"):
		var r: GrindRail = n as GrindRail
		if r == null:
			continue
		var hit: Dictionary = r.closest(pos)
		if not hit.is_empty():
			best = minf(best, float(hit["distance"]))
	return best


# --- pipe pumping ---------------------------------------------------------------------------------------

func _pipe_target(d: Dictionary) -> Vector3:
	var pos: Vector3 = d["pos"]
	var vel: Vector3 = d["vel"]
	var lane: float = float(pipe["lane"])
	if pipe.has("center"):
		# a round bowl: back to the middle when the rider has left the dish
		var ctr: Vector2 = pipe["center"]
		if Vector2(pos.x, pos.z).distance_to(ctr) > float(pipe.get("radius", 7.0)):
			return Vector3(ctr.x, 0.0, ctr.y)
	var along_x: bool = str(pipe.get("axis", "z")) == "x"
	var comp: float = vel.x if along_x else vel.z
	if absf(comp) > 0.8:
		_pipe_dir = signf(comp)
	if along_x:
		return Vector3(pos.x + _pipe_dir * 20.0, 0.0, lane)
	return Vector3(lane, 0.0, pos.z + _pipe_dir * 20.0)


func _record_peak(d: Dictionary) -> void:
	var vy: float = (d["vel"] as Vector3).y
	var y: float = (d["pos"] as Vector3).y
	if vy > 0.5:
		_rising = true
		_seg_max = maxf(_seg_max, y)
	elif _rising and vy <= 0.0:
		_rising = false
		if _seg_max > float(pipe.get("min_y", 0.8)):
			peaks.append(_seg_max - float(pipe.get("ref", 0.0)))
			if peaks.size() >= int(pipe.get("want", 5)):
				pipe = {}
				_next()
		_seg_max = -1000.0


func _fmt(v: Vector3) -> String:
	return "(%.1f,%.1f,%.1f)" % [v.x, v.y, v.z]
