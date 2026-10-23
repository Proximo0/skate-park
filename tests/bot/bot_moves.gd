class_name BotMoves
extends BotAuto
## Auto-built bot lines for the THUG2 move set, found from each level's own geometry (like BotAuto), so a level that
## changes keeps its coverage and a level that has no such feature skips the line (BOTINFO skip).
##   mv_powerslide      revert while rolling on a flat run                         moves: powerslide
##   mv_boneless        up, up + ollie on a flat run                               moves: boneless
##   mv_no_comply       up + ollie on a flat run                                   moves: no_comply
##   mv_manual_pivot    a manual, then a spin button (180 pivot), ollie out        moves: manual_pivot
##   mv_wallplant       ollie, then ollie again close to a tall wall faced square  moves: wallplant
##   mv_sticker_slap    ride along a tall wall, ollie, ollie again beside it       moves: sticker_slap
##   mv_bert_slide      revert while rolling down a ramp's transition              moves: bert_slide
##   mv_acid_drop       ollie off a deck over a ramp's face, revert in the air     moves: acid_drop
##   mv_natas           ollie over a post, grind press, spin 360, pop off          moves: natas_spin
##   mv_skitch          grab behind a traffic car, towed, let go                   moves: skitch
##   mv_rail_transfer   grind a rail, pop off its end, catch the next rail         moves: link:rail_transfer
##   mv_grind_switch    grind a rail, stick E + grind switches to a boardslide     moves: grind_switch
##   mv_ledge_stall     pop slow onto a ledge square to it, grind press stalls     moves: ledge_stall
## Each line is `moves`-checked by the runner: a move that never happened is a move_miss. `build_move(name, level, space)`
## returns the line or {}. Candidates come in a fixed order so before/after runs compare.

## The lines: each one is a few segments (a teleport and a short ride each), one per move it can find a spot for on the level.
## Grouped so a level loads once per group, not once per move (a bot run has a time budget). A group's members that find no
## spot are left out; a group with none is skipped.
const GROUPS: Dictionary = {
	"mv_flat": ["mv_powerslide", "mv_boneless", "mv_no_comply", "mv_manual_pivot"],
	"mv_walls": ["mv_wallplant", "mv_sticker_slap"],
	"mv_ramps": ["mv_bert_slide", "mv_acid_drop"],
	"mv_rails": ["mv_grind_switch", "mv_rail_transfer", "mv_ledge_stall"],
	"mv_street": ["mv_skitch", "mv_natas"],  ## skitch first: the cars have not driven off yet
}
const MOVE_NAMES: Array[String] = ["mv_flat", "mv_walls", "mv_ramps", "mv_rails", "mv_street"]
const RUN_LEN: float = 20.0  ## m of flat, clear ground a flat-run line needs
const HALF_W: float = 0.9  ## m each side that must be clear and level
const FLAT_NY: float = 0.985
const LEVEL_TOL: float = 0.12  ## m the floor may wander along a runway
const WALL_MIN_H: float = 2.4  ## m: walls the wall moves use stand this tall (a ray at that height still hits)


## A group line (MOVE_NAMES) or one member (GROUPS values, for debugging with BOT_MOVES=<member,member>). BOT_MOVES narrows
## every group to the members it names.
static func build_move(line_name: String, level: Level, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var ctx := BotMoves.new()
	ctx._level = level
	ctx._space = space
	if GROUPS.has(line_name):
		var only: PackedStringArray = OS.get_environment("BOT_MOVES").split(",", false)
		var out: Dictionary = {"name": line_name, "limit": 0.0, "soft": true, "expect": [], "moves": [], "wps": [], "note": ""}
		var notes: PackedStringArray = []
		for member: String in GROUPS[line_name]:
			if not only.is_empty() and not only.has(member.substr(3)):
				continue
			var one: Dictionary = ctx._member(member)
			if one.is_empty():
				continue
			(out["wps"] as Array).append_array(one["wps"])
			(out["moves"] as Array).append_array(one["moves"])
			out["limit"] = float(out["limit"]) + float(one["limit"])
			notes.append("%s(%s)" % [member.substr(3), str(one.get("note", ""))])
		if (out["wps"] as Array).is_empty():
			return {}
		out["note"] = " ".join(notes)
		return out
	return ctx._member(line_name)


func _member(line_name: String) -> Dictionary:
	var ctx: BotMoves = self
	match line_name:
		"mv_powerslide":
			return ctx._flat_line(line_name, "powerslide")
		"mv_boneless":
			return ctx._flat_line(line_name, "boneless")
		"mv_no_comply":
			return ctx._flat_line(line_name, "no_comply")
		"mv_manual_pivot":
			return ctx._flat_line(line_name, "manual_pivot")
		"mv_wallplant":
			return ctx._wall_line(line_name, false)
		"mv_sticker_slap":
			return ctx._wall_line(line_name, true)
		"mv_bert_slide":
			return ctx._ramp_line(line_name, true)
		"mv_acid_drop":
			return ctx._ramp_line(line_name, false)
		"mv_natas":
			return ctx._natas_line(line_name)
		"mv_skitch":
			return ctx._skitch_line(line_name)
		"mv_rail_transfer":
			return ctx._rail_line(line_name, true)
		"mv_grind_switch":
			return ctx._rail_line(line_name, false)
		"mv_ledge_stall":
			return ctx._ledge_line(line_name)
	return {}


# --- shared probes ----------------------------------------------------------------------------------------

## Fresh presses of `button` every `every` ticks from `from` + `at` for `span` ticks (a catch needs a press within 8 ticks).
static func _presses(button: String, from: String, at: int, span: int, every: int, extra: Dictionary = {}) -> Array:
	var out: Array = []
	var t: int = at
	while t < at + span:
		var st: Dictionary = {"from": from, "at": t, "dur": 1, "press": [button]}
		st.merge(extra)
		out.append(st)
		t += every
	return out


static func _h(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))


## True when the straight path p0 -> p1 (ground points) is level, flat and clear, HALF_W each side, at p0's height.
func _runway_ok(p0: Vector3, p1: Vector3, half_w: float = HALF_W) -> bool:
	var d: Vector3 = _h(p1 - p0)
	var len: float = d.length()
	if len < 0.1:
		return true
	d = d / len
	var perp := Vector3(-d.z, 0.0, d.x)
	var s: float = 0.0
	var prev: Vector3 = p0
	while s <= len + 0.01:
		var p: Vector3 = p0 + d * s
		for side: float in [-1.0, 0.0, 1.0]:
			var q: Vector3 = p + perp * (side * half_w)
			if not _in_bounds(q, 1.0):
				return false
			var h: Dictionary = _floor(q.x, q.z, p0.y + 1.0)
			if h.is_empty() or absf((h["position"] as Vector3).y - p0.y) > LEVEL_TOL or (h["normal"] as Vector3).y < FLAT_NY:
				return false
			if side == 0.0 and s > 0.0:
				# nothing standing in the way at knee and waist height between the last sample and this one
				for hy: float in [0.25, 0.8]:
					if not _ray(Vector3(prev.x, p0.y + hy, prev.z), Vector3(p.x, p0.y + hy, p.z)).is_empty():
						return false
		prev = p
		s += 0.5
	return true


## The ground point (x, z) of the level's floor found from above `from_y`, or Vector3.INF.
func _ground(x: float, z: float, from_y: float) -> Vector3:
	var h: Dictionary = _floor(x, z, from_y)
	if h.is_empty():
		return Vector3.INF
	return h["position"]


## Where to look from: the spawn, drop-in pads and every bot-route teleport (BotAuto._scan_origins), ground points only.
func _origins() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for o: Dictionary in _scan_origins():
		var p: Vector3 = o["pos"]
		var g: Vector3 = _ground(p.x, p.z, p.y + 1.5)
		if g != Vector3.INF and not out.any(func(q: Vector3) -> bool: return q.distance_to(g) < 4.0):
			out.append(g)
	return out


## A flat clear runway of `length` metres: {start, dir} (ground points), or {} when none is found. Tries each origin in
## order along 16 headings and slides the start along the heading, so the first open stretch in the level wins.
func _runway(length: float, skip: int = 0) -> Dictionary:
	var made: int = 0
	for o: Vector3 in _origins():
		for k: int in 16:
			var a: float = TAU * float(k) / 16.0
			var d := Vector3(sin(a), 0.0, -cos(a))
			for back: float in [0.0, 6.0]:
				var p0: Vector3 = o - d * back
				if not _runway_ok(p0, p0 + d * length):
					continue
				if made == skip:
					return {"start": p0, "dir": d}
				made += 1
	return {}


# --- flat runs: powerslide, boneless, no comply, manual pivot ---------------------------------------------------

func _flat_line(line_name: String, move: String) -> Dictionary:
	var rw: Dictionary = _runway(RUN_LEN)
	if rw.is_empty():
		return {}
	var p0: Vector3 = rw["start"]
	var d: Vector3 = rw["dir"]
	var at: Vector3 = p0 + d * 7.0
	var steps: Array = []
	var len: int = 120
	var moves: Array = [move]
	match move:
		"powerslide":
			steps = [{"at": 0, "dur": 24, "press": ["revert"], "held": ["revert"]}]
		"boneless":
			# (a long neutral run first: the pushes before it are up taps too, and more than two up taps within 18 ticks of the
			# press read as a jittery push, not a move)
			steps = [{"at": 16, "dur": 3, "sy": -1.0}, {"at": 22, "dur": 3, "sy": -1.0},
				{"at": 22, "dur": 8, "press": ["ollie"], "held": ["ollie"]}]
			len = 120
		"no_comply":
			steps = [{"at": 20, "dur": 3, "sy": -1.0}, {"at": 20, "dur": 8, "press": ["ollie"], "held": ["ollie"]}]
			len = 90
		"manual_pivot":
			# the manual flick (N then S), ride it, a spin button, then the ollie out
			steps = [{"at": 2, "dur": 3, "sy": -1.0}, {"at": 5, "dur": 3, "sy": 1.0},
				{"from": "MANUAL", "at": 40, "dur": 2, "press": ["spin_left"], "held": ["spin_left"]},
				{"from": "MANUAL", "at": 100, "dur": 6, "press": ["ollie"], "held": ["ollie"]}]
			len = 400
			moves = ["manual_pivot"]
	var wps: Array = [
		{"tp": {"pos": p0 + Vector3.UP * 0.1, "dir": d, "speed": 5.0}},
		{"p": p0 + d * 3.0, "r": 1.5, "spd": 6.5, "tmo": 6.0},
		{"p": at, "r": 1.2, "spd": 6.5, "act": "script", "steps": steps, "len": len, "nopush": true, "tmo": 6.0},
		{"p": p0 + d * (RUN_LEN - 1.0), "r": 2.0, "spd": 5.0, "tmo": 10.0},
	]
	return {"name": line_name, "limit": 30.0, "soft": true, "expect": [], "moves": moves, "wps": wps,
		"note": "run=(%.0f,%.0f)" % [p0.x, p0.z]}


# --- walls: wallplant and sticker slap ---------------------------------------------------------------------

## Tall upright wall faces found from the origins: {point (at ground height), normal (horizontal, out of the wall)}.
func _walls() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o: Vector3 in _origins():
		for k: int in 16:
			var a: float = TAU * float(k) / 16.0
			var d := Vector3(sin(a), 0.0, -cos(a))
			var from: Vector3 = o + Vector3.UP * 0.8
			var hit: Dictionary = _ray(from, from + d * 30.0)
			if hit.is_empty():
				continue
			var n: Vector3 = hit["normal"]
			if absf(n.y) > 0.15:
				continue
			var nh: Vector3 = _h(n).normalized()
			var pt: Vector3 = hit["position"]
			# tall: a ray at WALL_MIN_H, nudged off the face, hits the same wall
			var hi: Vector3 = Vector3(pt.x, o.y + WALL_MIN_H, pt.z) + nh * 0.6
			var hit2: Dictionary = _ray(hi, hi - nh * 1.2)
			if hit2.is_empty() or absf((hit2["normal"] as Vector3).y) > 0.15:
				continue
			var dup: bool = false
			for w: Dictionary in out:
				if (w["point"] as Vector3).distance_to(pt) < 5.0:
					dup = true
			if not dup:
				out.append({"point": Vector3(pt.x, o.y, pt.z), "normal": nh})
	return out


func _wall_line(line_name: String, sticker: bool) -> Dictionary:
	for w: Dictionary in _walls():
		var wp: Vector3 = w["point"]
		var n: Vector3 = w["normal"]
		if sticker:
			var line: Dictionary = _sticker_wps(line_name, wp, n)
			if not line.is_empty():
				return line
		else:
			var line2: Dictionary = _plant_wps(line_name, wp, n)
			if not line2.is_empty():
				return line2
	return {}


## Square to the wall at 6 m/s from 12 m back, ollie 3 m out, ollie again within 1.4 m of the face.
func _plant_wps(line_name: String, wall_pt: Vector3, n: Vector3) -> Dictionary:
	var start: Vector3 = wall_pt + n * 12.0
	var sg: Vector3 = _ground(start.x, start.z, wall_pt.y + 1.0)
	if sg == Vector3.INF or absf(sg.y - wall_pt.y) > LEVEL_TOL:
		return {}
	if not _runway_ok(sg, wall_pt + n * 0.9, 0.6):
		return {}
	var d: Vector3 = -n
	var pop_at: Vector3 = wall_pt + n * 3.2
	var steps: Array = [{"at": 0, "dur": 7, "press": ["ollie"], "held": ["ollie"]},
		{"from": "AIR", "at": 2, "dur": 40, "near": [wall_pt.x, wall_pt.z, 1.4], "press": ["ollie"], "held": ["ollie"]}]
	var wps: Array = [
		{"tp": {"pos": sg + Vector3.UP * 0.1, "dir": d, "speed": 4.0}},
		{"p": wall_pt + n * 7.0, "r": 1.5, "spd": 6.0, "tmo": 8.0},
		{"p": pop_at, "r": 0.8, "spd": 6.0, "act": "script", "steps": steps, "len": 140, "nopush": true, "tmo": 6.0},
		{"p": wall_pt + n * 1.2, "r": 1.0, "spd": 5.0, "tmo": 6.0},
		{"p": wall_pt + n * 9.0, "r": 2.5, "spd": 4.0, "tmo": 10.0},
	]
	return {"name": line_name, "limit": 30.0, "soft": true, "expect": [], "moves": ["wallplant"], "wps": wps,
		"note": "wall=(%.0f,%.0f)" % [wall_pt.x, wall_pt.z]}


## Along the wall 0.7 m off its face at 7 m/s, ollie, ollie again beside it.
func _sticker_wps(line_name: String, wall_pt: Vector3, n: Vector3) -> Dictionary:
	for sgn: float in [1.0, -1.0]:
		var t: Vector3 = Vector3(-n.z, 0.0, n.x) * sgn
		var p0: Vector3 = wall_pt + n * 0.7 - t * 4.0
		var p1: Vector3 = p0 + t * 17.0
		var g0: Vector3 = _ground(p0.x, p0.z, wall_pt.y + 1.0)
		if g0 == Vector3.INF or absf(g0.y - wall_pt.y) > LEVEL_TOL:
			continue
		if not _runway_ok(g0, Vector3(p1.x, g0.y, p1.z), 0.25):
			continue
		# the wall must run alongside the whole way (rays toward it at waist and chest height)
		var ok: bool = true
		var s: float = 0.0
		while s <= 17.0 and ok:
			var q: Vector3 = p0 + t * s
			for hy: float in [0.6, 1.4]:
				var h: Dictionary = _ray(Vector3(q.x, g0.y + hy, q.z), Vector3(q.x, g0.y + hy, q.z) - n * 1.2)
				if h.is_empty() or absf((h["position"] as Vector3 - Vector3(q.x, g0.y + hy, q.z)).dot(-n) - 0.7) > 0.25:
					ok = false
			s += 1.0
		if not ok:
			continue
		var steps: Array = [{"at": 0, "dur": 6, "press": ["ollie"], "held": ["ollie"]},
			{"from": "AIR", "at": 6, "dur": 4, "press": ["ollie"], "held": ["ollie"]}]
		var wps: Array = [
			{"tp": {"pos": g0 + Vector3.UP * 0.1, "dir": t, "speed": 5.0}},
			{"p": p0 + t * 6.0, "r": 1.2, "spd": 7.0, "tmo": 6.0},
			{"p": p0 + t * 7.0, "r": 0.8, "spd": 7.0, "act": "script", "steps": steps, "len": 140, "nopush": true, "tmo": 6.0},
			{"p": p1, "r": 2.0, "spd": 6.0, "tmo": 8.0},
		]
		return {"name": line_name, "limit": 30.0, "soft": true, "expect": [], "moves": ["sticker_slap"], "wps": wps,
			"note": "wall=(%.0f,%.0f)" % [wall_pt.x, wall_pt.z]}
	return {}


# --- ramps: bert slide and acid drop -----------------------------------------------------------------------

func _ramp_line(line_name: String, bert: bool) -> Dictionary:
	var spots: Array = _lip_spots()
	# ramps of 5 m and under first (a mega ramp's roll-in leaves a bert slide far too fast to steer out of), the rest after
	var ordered: Array = spots.filter(func(c: Dictionary) -> bool: return float(c["drop"]) <= 5.0)
	ordered.append_array(spots.filter(func(c: Dictionary) -> bool: return float(c["drop"]) > 5.0))
	for c: Dictionary in ordered:
		var mid: Vector3 = c["mid"]
		var inward: Vector3 = c["inward"]
		if bert:
			var line: Dictionary = _bert_wps(line_name, mid, inward, c)
			if not line.is_empty():
				return line
		else:
			if float(c["drop"]) < 1.2:
				continue
			var line2: Dictionary = _acid_wps(line_name, mid, inward, c)
			if not line2.is_empty():
				return line2
	return {}


## A bert slide: BotAuto's natural roll-in (it rides clean on every level), with revert pressed once the face under the board
## is a bank (normal y 0.45 to 0.92) and the roll has picked up speed.
func _bert_wps(line_name: String, _mid: Vector3, _inward: Vector3, c: Dictionary) -> Dictionary:
	var spots: Array = _lip_spots()
	var idx: int = spots.find(c)
	var base: Dictionary = _snap_line(line_name, idx, false)
	if base.is_empty():
		return {}
	var wps: Array = base["wps"]
	var steps: Array = [{"at": 0, "dur": 400, "ny": [0.45, 0.92], "spd": [3.5, 40.0], "press": ["revert"], "held": ["revert"]}]
	var roll: Dictionary = wps[1]
	roll["act"] = "script"
	roll["steps"] = steps
	roll["len"] = 300
	roll["nopush"] = true
	base["moves"] = ["bert_slide"]
	base["note"] = str(base.get("note", "")).replace("drop=", "bert drop=")
	return base


## An acid drop: ollie 1 m before the coping from the deck, revert in the air over the face.
func _acid_wps(line_name: String, mid: Vector3, inward: Vector3, c: Dictionary) -> Dictionary:
	# a face that falls away steeply from the coping (at least 1.2 m under the deck 1.5 m on): a gentle bank lands the ollie at once
	var face: Vector3 = _ground(mid.x + inward.x * 1.5, mid.z + inward.z * 1.5, mid.y + 0.5)
	if face == Vector3.INF or mid.y - face.y < 1.2:
		return {}
	var start: Vector3 = Vector3.INF
	for back: float in [7.0, 5.5, 4.0]:
		var sp: Vector3 = mid - inward * back
		var sd: Dictionary = _floor(sp.x, sp.z, mid.y + 1.0)
		if sd.is_empty() or absf((sd["position"] as Vector3).y - mid.y) > DECK_TOL or (sd["normal"] as Vector3).y < 0.95:
			continue
		if _runway_ok(sd["position"], mid - inward * 0.3, 0.5):
			start = sd["position"]
			break
	if start == Vector3.INF:
		return {}
	var steps: Array = [{"at": 0, "dur": 7, "press": ["ollie"], "held": ["ollie"]}]
	steps.append_array(_presses("revert", "AIR", 2, 45, 3, {"gd": [0.5, 12.0]}))  ## pressed on and off: the first one with a face below drops
	var wps: Array = [
		{"tp": {"pos": start + Vector3.UP * 0.1, "dir": inward, "speed": 4.0}},
		{"p": mid - inward * 4.0, "r": 1.0, "spd": 6.0, "tmo": 6.0},
		{"p": mid - inward * 2.6, "r": 0.6, "spd": 6.0, "act": "script", "steps": steps, "len": 160, "nopush": true, "tmo": 6.0},
		{"p": c["target"], "r": 2.5, "spd": 6.0, "tmo": 10.0},
	]
	return {"name": line_name, "limit": 30.0, "soft": true, "expect": [], "moves": ["acid_drop"], "wps": wps,
		"note": "ramp=%s drop=%.1fm" % [String(c["name"]).get_slice("/", String(c["name"]).get_slice_count("/") - 2), float(c["drop"])]}


# --- natas: a post --------------------------------------------------------------------------------------------

## Post tops: small box / cylinder / capsule collision shapes whose top stands 0.55 to 1.0 m over the floor beside them.
func _posts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: Node in _level.get_tree().root.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = n as CollisionShape3D
		if cs.shape == null or cs.disabled or not (cs.get_parent() is CollisionObject3D):
			continue
		if (cs.get_parent() as CollisionObject3D).collision_layer & 1 == 0 or not cs.is_inside_tree():
			continue
		if not (cs.shape is BoxShape3D or cs.shape is CylinderShape3D or cs.shape is CapsuleShape3D):
			continue
		var aabb: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
		if aabb.size.x > 0.46 or aabb.size.z > 0.46 or aabb.size.y < 0.4:
			continue
		var top: Vector3 = Vector3(aabb.get_center().x, aabb.end.y, aabb.get_center().z)
		var g: Vector3 = _ground(top.x + 0.9, top.z, top.y + 1.0)
		if g == Vector3.INF:
			continue
		var h: float = top.y - g.y
		if h < 0.55 or h > 1.0:
			continue
		var hit: Dictionary = _ray(top + Vector3.UP * 0.1, top - Vector3.UP * 0.3)
		if hit.is_empty() or (hit["normal"] as Vector3).y < 0.9:
			continue
		out.append({"top": hit["position"], "ground": g.y, "h": h, "name": String(cs.get_parent().name)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Vector3 = a["top"]
		var pb: Vector3 = b["top"]
		return pa.x < pb.x if absf(pa.x - pb.x) > 0.01 else pa.z < pb.z)
	return out


func _natas_line(line_name: String) -> Dictionary:
	for post: Dictionary in _posts():
		var top: Vector3 = post["top"]
		var gy: float = float(post["ground"])
		for k: int in 8:
			var a: float = TAU * float(k) / 8.0
			var d := Vector3(sin(a), 0.0, -cos(a))
			var start: Vector3 = Vector3(top.x, gy, top.z) - d * 3.4
			var g0: Vector3 = _ground(start.x, start.z, gy + 1.0)
			if g0 == Vector3.INF or absf(g0.y - gy) > LEVEL_TOL:
				continue
			if not _runway_ok(g0, Vector3(top.x, gy, top.z) - d * 0.8, 0.5):
				continue
			var after: Vector3 = Vector3(top.x, gy, top.z) + d * 3.0
			var ga: Vector3 = _ground(after.x, after.z, gy + 1.0)
			if ga == Vector3.INF or absf(ga.y - gy) > LEVEL_TOL:
				continue
			var steps: Array = [{"at": 5, "dur": 14, "held": ["ollie"]}, {"at": 5, "dur": 1, "press": ["ollie"], "held": ["ollie"]},
				{"from": "AIR", "at": 0, "dur": 60, "near": [top.x, top.z, 0.7], "press": ["grind"]},
				{"from": "LIP", "at": 0, "dur": 66, "held": ["spin_right"]},
				{"from": "LIP", "at": 70, "dur": 4, "press": ["ollie"], "held": ["ollie"]}]
			var wps: Array = [
				{"tp": {"pos": g0 + Vector3.UP * 0.1, "dir": d, "speed": 3.0}},
				{"p": g0 + d * 0.3, "r": 0.4, "spd": 3.0, "act": "script", "steps": steps, "len": 260, "nopush": true, "tmo": 4.0},
				{"p": ga, "r": 2.0, "spd": 4.0, "tmo": 12.0},
			]
			return {"name": line_name, "limit": 30.0, "soft": true, "expect": [], "moves": ["natas_spin"], "wps": wps,
				"note": "post=%s h=%.2f" % [String(post["name"]), float(post["h"])]}
	return {}


# --- traffic: skitch -------------------------------------------------------------------------------------------

func _skitch_line(line_name: String) -> Dictionary:
	var cars: Array[Node] = _level.get_tree().root.find_children("*", "TrafficCar", true, false)
	if cars.is_empty():
		return {}
	var origin: Vector3 = _level.spawn.origin
	cars.sort_custom(func(x: Node, y: Node) -> bool:
		# (distance in 6 m steps, then by name: cars drive off during the settle ticks, so exact distances can flip run to run)
		var dx: float = snappedf((x as Node3D).global_position.distance_to(origin), 6.0)
		var dy: float = snappedf((y as Node3D).global_position.distance_to(origin), 6.0)
		if absf(dx - dy) > 0.01:
			return dx < dy
		var px: Vector3 = (x as Node3D).global_position
		var py: Vector3 = (y as Node3D).global_position
		return px.x < py.x if absf(px.x - py.x) > 1.0 else px.z < py.z)
	for n: Node in cars:
		var car: Node3D = n as Node3D
		var b: Basis = car.global_transform.basis
		var fwd: Vector3 = _h(-b.z).normalized()
		var rear_z: float = 2.1
		var model: Variant = car.get("model")
		if model is CarModel:
			rear_z = (model as CarModel).aabb.end.z
		var rear: Vector3 = car.global_transform * Vector3(0.0, 0.0, rear_z)
		var pos: Vector3 = rear - fwd * 1.3
		var g: Vector3 = _ground(pos.x, pos.z, car.global_position.y + 1.5)
		if g == Vector3.INF or absf(g.y - car.global_position.y) > 0.6 or not _in_bounds(pos, 3.0):
			continue
		# level, open ground for the 6 m behind the car (it stands on a street, not under a ledge or in a wall)
		if not _runway_ok(Vector3(pos.x - fwd.x * 6.0, g.y, pos.z - fwd.z * 6.0), Vector3(pos.x, g.y, pos.z), 0.4):
			continue
		var steps: Array = [{"at": 3, "dur": 1, "press": ["grab"], "held": ["grab"]}, {"at": 3, "dur": 150, "held": ["grab"]},
			{"at": 155, "dur": 4, "press": ["ollie"], "held": ["ollie"]}]
		var wps: Array = [
			{"tp": {"car": true, "gap": 1.3, "near": car.global_position, "pos": pos, "dir": fwd, "speed": 0.0}},
			{"p": pos, "r": 400.0, "spd": 4.0, "act": "script", "steps": steps, "len": 220},
			{"p": pos + fwd * 80.0, "r": 2.0, "spd": 4.0, "tmo": 5.0},
		]
		return {"name": line_name, "limit": 14.0, "soft": true, "expect": [], "moves": ["skitch"], "wps": wps,
			"note": "car@(%.0f,%.0f)" % [car.global_position.x, car.global_position.z]}
	return {}


# --- rails and ledges ----------------------------------------------------------------------------------------

## The route's own rail grinds (proven lines: the bot already rides them clean): for every "grind" waypoint of every route
## line, {line (name), pre (the waypoints from the line's teleport up to the grind), grind (the waypoint), a (where the
## grind is aimed at, the rail's start side), b (the grind's `end`), d (a -> b, flat unit)}. Practice uses its code-built
## lines (BotLines), every other level its bot_route.json.
func _route_grinds() -> Array[Dictionary]:
	var lines: Array = []
	if _level.bot_route_path == LevelRegistry.BUILTIN_ROUTE and _level is Park:
		var bl := BotLines.new(_level as Park, null)
		for n: String in BotLines.names():
			lines.append(bl.build(n))
	elif _level.bot_route_path != "":
		lines = LevelRoute.load_file(_level.bot_route_path).get("lines", [])
	var out: Array[Dictionary] = []
	for l: Dictionary in lines:
		var w: Array = l.get("wps", [])
		var first: int = 0
		for i: int in w.size():
			var wd: Dictionary = w[i]
			if wd.has("tp"):
				first = i
			if str(wd.get("act", "")) == "grind" and wd.has("end") and w[first].has("tp"):
				var a: Vector3 = wd["p"]
				var b: Vector3 = wd["end"]
				if _h(b - a).length() < 5.0:
					continue
				out.append({"line": str(l.get("name", "")), "pre": w.slice(first, i), "grind": wd, "a": a, "b": b,
					"d": _h(b - a).normalized(), "tail": w.slice(i + 1, mini(i + 2, w.size()))})
	return out


## The approach to a rail's first end: {start (ground), lead} with 10 m (or 7) of clear level floor in front of `a`.
func _rail_approach(a: Vector3, d: Vector3) -> Dictionary:
	var g: Vector3 = _ground(a.x - d.x * 1.0, a.z - d.z * 1.0, a.y - 0.2)
	if g == Vector3.INF or a.y - g.y > 0.8:
		return {}
	for lead: float in [10.0, 7.0]:
		var s: Vector3 = Vector3(a.x - d.x * lead, g.y, a.z - d.z * lead)
		var gs: Vector3 = _ground(s.x, s.z, g.y + 0.6)
		if gs == Vector3.INF or absf(gs.y - g.y) > LEVEL_TOL:
			continue
		if _runway_ok(gs, Vector3(a.x - d.x * 0.9, g.y, a.z - d.z * 0.9), 0.4):
			return {"start": gs, "lead": lead}
	return {}


## Two rails of different pieces in a row (the second starts 1 to 6 m past the first's end, on its line, at about its
## height): grind the first, pop off its end, grind press in the air catches the second (a Rail Transfer).
func _transfer_line(line_name: String) -> Dictionary:
	var rails: Array[Dictionary] = _rails("rail", 3.0)
	for ra: Dictionary in rails:
		var a: Vector3 = ra["a"]
		var b: Vector3 = ra["b"]
		var d: Vector3 = ra["d"]
		for rb: Dictionary in rails:
			if rb == ra or rb["parent"] == ra["parent"]:
				continue
			var ba: Vector3 = rb["a"]
			var rel: Vector3 = _h(ba - b)
			var along: float = rel.dot(d)
			if along < 1.0 or along > 6.0 or absf(rel.dot(Vector3(-d.z, 0.0, d.x))) > 0.5 or absf(ba.y - b.y) > 0.4 or (rb["d"] as Vector3).dot(d) < 0.95:
				continue
			var ap: Dictionary = _rail_approach(a, d)
			if ap.is_empty():
				continue
			var start: Vector3 = ap["start"]
			var lead: float = ap["lead"]
			var grind_wp: Dictionary = {"p": a - d * 0.8, "r": 0.9, "spd": 8.0, "act": "grind", "exit": "ollie", "end": b, "tmo": 10.0,
				"after": {"len": 120, "steps": _presses("grind", "AIR", 3, 60, 3)}}
			var nb: Vector3 = rb["b"]
			var wps: Array = [{"tp": {"pos": start + Vector3.UP * 0.1, "dir": d, "speed": minf(8.0, 3.0 + lead)}},
				{"p": a - d * 4.0, "r": 1.0, "spd": 8.0}, grind_wp, {"p": nb + (rb["d"] as Vector3) * 6.0, "r": 2.5, "spd": 6.0, "tmo": 10.0}]
			return {"name": line_name, "limit": 30.0, "soft": true, "expect": [], "moves": ["link:rail_transfer"], "wps": wps,
				"note": "rail=%s -> %s" % [str(ra["name"]), str(rb["name"])]}
	return {}


func _rail_line(line_name: String, transfer: bool) -> Dictionary:
	if transfer:
		return _transfer_line(line_name)
	var grinds: Array[Dictionary] = _route_grinds()
	for ga: Dictionary in grinds:
		var a: Vector3 = ga["a"]
		var b: Vector3 = ga["b"]
		var grind_wp: Dictionary = (ga["grind"] as Dictionary).duplicate(true)
		var note: String = "rail of line %s" % str(ga["line"])
		# grind switch: grind pressed again with the stick E, then W, switches to another trick on the same rail
		var secs: float = _h(b - a).length() / 8.0
		# (two presses, E then W: the catch itself may already have been E, and a switch needs a different trick)
		grind_wp["steps"] = [{"from": "GRIND", "at": int(secs * 60.0 * 0.3), "dur": 1, "press": ["grind"], "sx": 1.0},
			{"from": "GRIND", "at": int(secs * 60.0 * 0.5), "dur": 1, "press": ["grind"], "sx": -1.0}]
		var wps: Array = (ga["pre"] as Array).duplicate(true)
		wps.append(grind_wp)
		wps.append_array((ga["tail"] as Array).duplicate(true))
		return {"name": line_name, "limit": 40.0, "soft": true, "expect": [], "moves": ["grind_switch"], "wps": wps, "note": note}
	return {}


## Rails of kind `kind` (not a loop, at least `min_len` long), by position: {a, b, d, name}.
func _rails(kind: String, min_len: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: Node in _level.get_tree().get_nodes_in_group("grind_rail"):
		var r: GrindRail = n as GrindRail
		if r == null or r.kind != kind or not _level.is_ancestor_of(r):
			continue
		var gp: PackedVector3Array = r.global_points()
		if gp.size() < 2:
			continue
		var a: Vector3 = gp[0]
		var b: Vector3 = gp[gp.size() - 1]
		if _h(b - a).length() < min_len:
			continue
		out.append({"a": a, "b": b, "d": _h(b - a).normalized(), "name": String(r.name), "parent": r.get_parent()})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var xa: Vector3 = x["a"]
		var ya: Vector3 = y["a"]
		return xa.x < ya.x if absf(xa.x - ya.x) > 0.01 else xa.z < ya.z)
	return out


## A ledge stall: pop onto a ledge at 3.5 m/s square to it, grind press, stay a moment, ollie out.
func _ledge_line(line_name: String) -> Dictionary:
	for rl: Dictionary in _rails("ledge", 2.5):
		var a: Vector3 = rl["a"]
		var b: Vector3 = rl["b"]
		var mid: Vector3 = (a + b) * 0.5
		var t: Vector3 = rl["d"]
		for sgn: float in [1.0, -1.0]:
			var n: Vector3 = Vector3(-t.z, 0.0, t.x) * sgn  ## the way the skater comes from: toward the ledge is -n
			var g: Vector3 = _ground(mid.x + n.x * 1.6, mid.z + n.z * 1.6, mid.y + 1.0)
			if g == Vector3.INF or mid.y - g.y > 0.8 or mid.y - g.y < 0.1 or (_floor(g.x, g.z, g.y + 1.0)["normal"] as Vector3).y < 0.97:
				continue
			var start: Vector3 = Vector3(mid.x + n.x * 6.5, g.y, mid.z + n.z * 6.5)
			var gs: Vector3 = _ground(start.x, start.z, g.y + 0.6)
			if gs == Vector3.INF or absf(gs.y - g.y) > LEVEL_TOL or not _runway_ok(gs, Vector3(mid.x + n.x * 1.6, g.y, mid.z + n.z * 1.6), 0.4):
				continue
			var steps: Array = [{"at": 0, "dur": 6, "press": ["ollie"], "held": ["ollie"]}]
			steps.append_array(_presses("grind", "AIR", 1, 45, 3, {"near": [mid.x, mid.z, 1.4]}))
			steps.append({"from": "LIP", "at": 45, "dur": 4, "press": ["ollie"], "held": ["ollie"]})
			var wps: Array = [
				{"tp": {"pos": gs + Vector3.UP * 0.1, "dir": -n, "speed": 3.5}},
				{"p": mid + n * 3.0, "r": 1.0, "spd": 3.5, "tmo": 6.0},
				{"p": mid + n * 1.7, "r": 0.5, "spd": 3.5, "act": "script", "steps": steps, "len": 200, "nopush": true, "tmo": 6.0},
				{"p": mid + n * 30.0, "r": 2.0, "spd": 4.0, "tmo": 4.0},  ## the stall drops back off the side it came from; the wait lets it land
			]
			return {"name": line_name, "limit": 30.0, "soft": true, "expect": [], "moves": ["ledge_stall"], "wps": wps,
				"note": "ledge=%s" % String(rl["name"])}
	return {}
