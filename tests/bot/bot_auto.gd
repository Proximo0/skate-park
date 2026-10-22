class_name BotAuto
extends RefCounted
## Auto-built bot lines that work on ANY level, found from the level's own geometry instead of hand-typed coordinates, so a
## level that changes keeps its coverage and a level that has no such feature just skips the line:
##   auto_snap_a/b/c      Q + E ramp snap drop-ins: set down on the deck just behind a coping, hang, stomp and roll down.
##   auto_roll_in_a/b/c   natural drop-ins: roll over a coping slowly (no snap) and follow the transition down.
##   auto_roll_off_a/b    drop-outs: roll off a deck / ledge / platform edge (0.8 to 2.5 m) with no ollie, land, roll on.
##   auto_big_drop        the same off the highest edge found (2.5 m or more).
## `build(name, level, space)` returns a line {name, limit, soft, expect, wps} in the shape LevelRoute / BotLines use, or {}
## when this level has no candidate for it (the runner prints BOTINFO skip and moves on). Candidates are deterministic: the
## same level gives the same lines, so before/after runs compare.
##
## The lines are `soft` (a slow waypoint is tolerated) but a bail, respawn, stuck or snag on the way still counts.

const NAMES: Array[String] = ["auto_snap_a", "auto_snap_b", "auto_snap_c", "auto_roll_in_a", "auto_roll_in_b", "auto_roll_in_c", "auto_roll_off_a", "auto_roll_off_b", "auto_big_drop"]

const MIN_LIP_LEN: float = 3.0  ## m: a coping segment shorter than this is a corner, not a drop-in spot
const MIN_DROP: float = 1.0  ## m a ramp lip stands above the flat in front of it
const MAX_DROP: float = 8.0
const SPREAD: float = 12.0  ## m between two chosen ramps
const SNAP_BACK: float = 1.3  ## m behind the coping the snap line sets the skater down
const ROLL_BACK: float = 3.0
const EDGE_STEP: float = 0.5
const EDGE_REACH: float = 40.0
const MIN_EDGE_DROP: float = 0.8
const BIG_DROP: float = 2.5
const MAX_EDGE_DROP: float = 12.0
const DECK_TOL: float = 0.3
const HALF_WIDTH: float = 0.9  ## m each side of the roll-off path that must be floor at the same height up to the edge


## The line `line_name` for `level`, or {} when it has none.
static func build(line_name: String, level: Level, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var ctx := BotAuto.new()
	ctx._level = level
	ctx._space = space
	match line_name:
		"auto_snap_a":
			return ctx._snap_line(line_name, 0, true)
		"auto_snap_b":
			return ctx._snap_line(line_name, 1, true)
		"auto_snap_c":
			return ctx._snap_line(line_name, 2, true)
		"auto_roll_in_a":
			return ctx._snap_line(line_name, 0, false)
		"auto_roll_in_b":
			return ctx._snap_line(line_name, 1, false)
		"auto_roll_in_c":
			return ctx._snap_line(line_name, 2, false)
		"auto_roll_off_a":
			return ctx._edge_line(line_name, 0, false)
		"auto_roll_off_b":
			return ctx._edge_line(line_name, 1, false)
		"auto_big_drop":
			return ctx._edge_line(line_name, 0, true)
	return {}


var _level: Level
var _space: PhysicsDirectSpaceState3D


# --- floor probes -----------------------------------------------------------------------------------

## Floor under (x, z) found by a ray from `from_y` down, or {} (point, normal).
func _floor(x: float, z: float, from_y: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, from_y - 60.0, z), 1)
	return _space.intersect_ray(q)


## True when a skater-sized sphere standing at p is not inside any solid (a set-down point must never be buried in a collision volume).
func _clear(p: Vector3) -> bool:
	var sh := SphereShape3D.new()
	sh.radius = 0.3
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0.0, 0.45, 0.0))
	q.collision_mask = 1
	return _space.intersect_shape(q, 1).is_empty()


func _in_bounds(p: Vector3, margin: float) -> bool:
	return _level.bounds.grow(-margin).has_point(Vector2(p.x, p.z))


# --- ramp lips: snap-in and natural roll-in ------------------------------------------------------------

## One candidate per ramp (RampLip node): its longest "drop_in" segment's middle, with the inward direction, lip height and
## the drop to the flat in front. Sorted tallest first, then picked so the chosen ramps are SPREAD apart.
func _lip_spots() -> Array:
	var cands: Array = []
	for n: Node in _level.find_children("*", "RampLip", true, false):
		var lip: RampLip = n as RampLip
		if lip.kind != "drop_in":
			continue
		var best: Dictionary = {}
		var best_len: float = 0.0
		for s: Dictionary in lip.segments():
			var l: float = (s["a"] as Vector3).distance_to(s["b"])
			if l > best_len:
				best_len = l
				best = s
		if best.is_empty() or best_len < MIN_LIP_LEN:
			continue
		var mid: Vector3 = ((best["a"] as Vector3) + (best["b"] as Vector3)) * 0.5
		var inward: Vector3 = best["inward"]
		var behind: Vector3 = mid - inward * SNAP_BACK
		var deck: Dictionary = _floor(behind.x, behind.z, mid.y + 1.0)
		if deck.is_empty() or absf((deck["position"] as Vector3).y - mid.y) > DECK_TOL or (deck["normal"] as Vector3).y < 0.95:
			continue  # no flat deck behind the coping to stand on
		if not _clear(Vector3(behind.x, mid.y, behind.z)) or not _clear(Vector3(mid.x - inward.x * ROLL_BACK, mid.y, mid.z - inward.z * ROLL_BACK)) and not _clear(Vector3(mid.x - inward.x * 1.6, mid.y, mid.z - inward.z * 1.6)):
			continue
		var run_end: Dictionary = _runout(mid, inward)
		if run_end.is_empty():
			continue
		var drop: float = mid.y - float(run_end["y"])
		if drop < MIN_DROP or drop > MAX_DROP:
			continue
		cands.append({"mid": mid, "inward": inward, "drop": drop, "len": best_len, "target": run_end["pos"], "name": str(lip.get_path())})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["drop"]) - float(b["drop"])) > 0.01:
			return float(a["drop"]) > float(b["drop"])
		return str(a["name"]) < str(b["name"]))
	var picked: Array = []
	for c: Dictionary in cands:
		var far: bool = true
		for p: Dictionary in picked:
			if (c["mid"] as Vector3).distance_to(p["mid"]) < SPREAD:
				far = false
		if far:
			picked.append(c)
	return picked


## Down the ramp from the coping: where the floor first goes flat again (the runout), plus 2.5 m, as the place to ride to.
## {pos, y} or {} when the ramp does not come out onto a flat inside the level.
func _runout(mid: Vector3, inward: Vector3) -> Dictionary:
	var s: float = 0.6
	var seen_slope: bool = false
	while s < 16.0:
		var p: Vector3 = mid + inward * s
		var h: Dictionary = _floor(p.x, p.z, mid.y + 0.3)
		if h.is_empty():
			return {}
		var n: Vector3 = h["normal"]
		if n.y < 0.9:
			seen_slope = true
		elif seen_slope and n.y > 0.985:
			var out: Vector3 = mid + inward * (s + 2.5)
			var hh: Dictionary = _floor(out.x, out.z, (h["position"] as Vector3).y + 1.0)
			if hh.is_empty() or absf((hh["position"] as Vector3).y - (h["position"] as Vector3).y) > 0.3 or not _in_bounds(out, 1.5):
				return {}
			return {"pos": Vector3(out.x, (hh["position"] as Vector3).y, out.z), "y": (h["position"] as Vector3).y}
		s += 0.4
	return {}


func _snap_line(line_name: String, index: int, snap: bool) -> Dictionary:
	var spots: Array = _lip_spots()
	if spots.is_empty():
		return {}
	if index >= spots.size():
		return {}  ## this level has fewer ramps than lines: no duplicate runs
	var c: Dictionary = spots[index]
	var mid: Vector3 = c["mid"]
	var inward: Vector3 = c["inward"]
	var back: float = SNAP_BACK
	if not snap:
		back = 0.0
		for try_back: float in [ROLL_BACK, 2.2, 1.6]:
			var tp: Vector3 = mid - inward * try_back
			var dk: Dictionary = _floor(tp.x, tp.z, mid.y + 1.0)
			if not dk.is_empty() and absf((dk["position"] as Vector3).y - mid.y) <= DECK_TOL and (dk["normal"] as Vector3).y > 0.95 and _clear(Vector3(tp.x, mid.y, tp.z)):
				back = try_back
				break
		if back == 0.0:
			return {}
	var start: Vector3 = mid - inward * back
	start.y = mid.y + 0.1
	if not _clear(start):
		return {}
	var wps: Array = [{"tp": {"pos": start, "dir": inward, "speed": 0.4 if snap else 1.5}}]
	if snap:
		# the chord on the first tick, then hands off while the snap carries the skater over the coping
		wps.append({"p": start + inward * 0.05, "r": 1.0, "spd": 0.0, "act": "snap", "tmo": 3.0})
	else:
		# a natural roll-in: a gentle push only, so the speed stays under the skater's roll-in limit
		wps.append({"p": mid + inward * 0.6, "r": 0.5, "spd": 2.0, "tmo": 6.0})
	var target: Vector3 = c["target"]
	wps.append({"p": target, "r": 2.0, "spd": 6.0, "tmo": 9.0})
	return {"name": line_name, "limit": 30.0, "soft": true, "expect": [], "wps": wps,
		"note": "ramp=%s drop=%.1fm" % [String(c["name"]).get_slice("/", String(c["name"]).get_slice_count("/") - 2), float(c["drop"])]}


# --- deck edges: roll-off and big drop ------------------------------------------------------------------

## Places to scan for an edge from: the level's drop-in pads, its spawn, and every teleport and waypoint-to-waypoint heading of its
## bot route (the practice park's code-built lines through BotLines), i.e. the lines the bot already rides.
func _scan_origins() -> Array:
	var out: Array = []
	for id: Variant in _level.drop_ins:
		var xf: Transform3D = _level.drop_ins[id]
		out.append({"pos": xf.origin, "dir": -xf.basis.z})
	var sx: Transform3D = _level.spawn
	out.append({"pos": sx.origin, "dir": -sx.basis.z})
	var all_lines: Array = []
	if _level.bot_route_path == LevelRegistry.BUILTIN_ROUTE and _level is Park:
		var bl := BotLines.new(_level as Park, null)
		for n: String in BotLines.names():
			all_lines.append(bl.build(n))
	elif _level.bot_route_path != "":
		all_lines = LevelRoute.load_file(_level.bot_route_path).get("lines", [])
	for l: Dictionary in all_lines:
		var w: Array = l.get("wps", [])
		var prev: Variant = null
		for i: int in w.size():
			var wp: Dictionary = w[i]
			if wp.has("tp"):
				var tp: Dictionary = wp["tp"]
				out.append({"pos": tp["pos"], "dir": tp["dir"]})
				prev = tp["pos"]
			elif wp.has("p"):
				var q: Vector3 = wp["p"]
				if prev != null and (prev as Vector3).distance_to(q) > 1.0:
					out.append({"pos": prev, "dir": q - (prev as Vector3)})
				prev = q
	return out


## March from `origin` along `dir` and return the first edge where the floor falls away: {start, dir, edge, drop, land, run}.
func _find_edge(origin: Vector3, dir: Vector3) -> Dictionary:
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	var first: Dictionary = _floor(origin.x, origin.z, origin.y + 1.5)
	if first.is_empty() or (first["normal"] as Vector3).y < 0.95:
		return {}
	var y0: float = (first["position"] as Vector3).y
	var prev_y: float = y0
	var s: float = EDGE_STEP
	while s <= EDGE_REACH:
		var p: Vector3 = origin + d * s
		if not _in_bounds(p, 2.0):
			return {}
		var from: Vector3 = origin + d * (s - EDGE_STEP)
		var wall := PhysicsRayQueryParameters3D.create(Vector3(from.x, prev_y + 0.5, from.z), Vector3(p.x, prev_y + 0.5, p.z), 1)
		if not _space.intersect_ray(wall).is_empty():
			return {}  # something in the way, not a drop
		var h: Dictionary = _floor(p.x, p.z, prev_y + 0.6)
		var y: float = (h["position"] as Vector3).y if not h.is_empty() else -1000.0
		if y >= prev_y - 0.35:
			# the upper floor must be wide enough to ride (a ledge top or a rail is a grind, not a roll-off)
			var perp := Vector3(-d.z, 0.0, d.x)
			for side: float in [-1.0, 1.0]:
				var q: Vector3 = p + perp * (side * HALF_WIDTH)
				var hs: Dictionary = _floor(q.x, q.z, prev_y + 0.6)
				if hs.is_empty() or absf((hs["position"] as Vector3).y - y) > 0.25:
					return {}
		if y < prev_y - 0.35:
			var edge: Vector3 = origin + d * (s - EDGE_STEP)
			edge.y = prev_y
			return _landing(origin, d, edge, y0)
		prev_y = y
		s += EDGE_STEP
	return {}


## The drop measured 3 m past the edge, checked to be a flat landing inside the level above the kill plane.
func _landing(origin: Vector3, d: Vector3, edge: Vector3, y0: float) -> Dictionary:
	var land_p: Vector3 = edge + d * 3.5
	var h: Dictionary = _floor(land_p.x, land_p.z, edge.y + 0.3)
	if h.is_empty() or not _in_bounds(land_p, 1.5):
		return {}
	var ly: float = (h["position"] as Vector3).y
	var drop: float = edge.y - ly
	if drop < MIN_EDGE_DROP or drop > MAX_EDGE_DROP or ly < _level.kill_y + 3.0:
		return {}
	if (h["normal"] as Vector3).y < 0.8:
		return {}
	# the runout beyond the landing must stay on a floor
	var run: Vector3 = edge + d * 8.0
	var hr: Dictionary = _floor(run.x, run.z, ly + 1.5)
	if hr.is_empty() or absf((hr["position"] as Vector3).y - ly) > 1.0 or not _in_bounds(run, 1.5):
		run = edge + d * 5.5
		hr = _floor(run.x, run.z, ly + 1.5)
		if hr.is_empty() or absf((hr["position"] as Vector3).y - ly) > 1.0:
			return {}
	return {"start": Vector3(origin.x, y0, origin.z), "dir": d, "edge": edge, "drop": drop, "land": Vector3(land_p.x, ly, land_p.z), "run": Vector3(run.x, (hr["position"] as Vector3).y, run.z)}


func _edges() -> Array:
	var found: Array = []
	for o: Dictionary in _scan_origins():
		var e: Dictionary = _find_edge(o["pos"], o["dir"])
		if e.is_empty():
			continue
		var dup: bool = false
		for f: Dictionary in found:
			if (f["edge"] as Vector3).distance_to(e["edge"]) < 6.0:
				dup = true
		if not dup:
			found.append(e)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["drop"]) - float(b["drop"])) > 0.01:
			return float(a["drop"]) > float(b["drop"])
		return (a["edge"] as Vector3).x < (b["edge"] as Vector3).x)
	return found


func _edge_line(line_name: String, index: int, big: bool) -> Dictionary:
	var pool: Array = []
	for e: Dictionary in _edges():
		if big == (float(e["drop"]) >= BIG_DROP):
			pool.append(e)
	if not big:
		pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["drop"]) > float(b["drop"]))  ## highest below 2.5 m first
	var made: int = 0
	for e: Dictionary in pool:
		var wps: Array = _edge_wps(e)
		if wps.is_empty():
			continue
		if made == index:
			var edge: Vector3 = e["edge"]
			return {"name": line_name, "limit": 30.0, "soft": true, "expect": [], "wps": wps,
				"note": "edge=(%.0f,%.1f,%.0f) drop=%.1fm" % [edge.x, edge.y, edge.z, float(e["drop"])]}
		made += 1
	return {}


## The waypoints of a roll-off: set down 6 m back on the upper floor, roll to the edge at 4 m/s, off it with no ollie, on past the landing.
func _edge_wps(e: Dictionary) -> Array:
	var d: Vector3 = e["dir"]
	var edge: Vector3 = e["edge"]
	var start: Vector3 = edge - d * 6.0
	var sh: Dictionary = _floor(start.x, start.z, edge.y + 1.0)
	if sh.is_empty() or absf((sh["position"] as Vector3).y - edge.y) > 0.3 or (sh["normal"] as Vector3).y < 0.95:
		start = e["start"]
		if start.distance_to(edge) > 30.0:
			return []
	else:
		start = Vector3(start.x, (sh["position"] as Vector3).y, start.z)
	if not _clear(start):
		return []
	return [
		{"tp": {"pos": start, "dir": d, "speed": 3.0}},
		{"p": edge - d * 1.0, "r": 1.0, "spd": 4.0, "tmo": 8.0},
		{"p": edge + d * 3.5, "r": 2.0, "spd": 4.0, "tmo": 6.0},
		{"p": e["run"], "r": 2.5, "spd": 5.0, "tmo": 8.0},
	]
