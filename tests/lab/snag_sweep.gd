extends Node
## Headless snag sweep: runs scripted skaters at every ridable piece of the real park (side grazes, corner hits, foot-of-ramp
## and deck-edge approaches) and reports where mechanical energy is lost without a bail/landing, ranked into hotspots.
## Run via tools/snag_sweep.sh, or: godot --headless --fixed-fps 60 --path . res://tests/lab/snag_sweep.tscn -- [options]
## Options: --only=<piece substring>  --keep=PCT (percent of approach geometries kept, default 100)  --shard=i --nshards=N (split the runs)  --merge=N (report from N shard files)  --props (also sweep benches/planters/signs)  --speeds=4,8,12  --fwd=0|1 (second pass holding forward, run at the speeds >= 8 only)
##   --batch=N (parallel skaters)  --list (print the pieces and stop)  --replay=<rank> (re-run hotspot <rank> from snags.json alone, with a trace)
## Output: `SNAG <piece> <pos> count=.. worst_loss=..% kind=.. normal=.. contact_h=.. example=..` then `SNAG summary runs=N snags=M hotspots=K`.
## Writes /tmp/lab/snags.json.

const OUT_DIR: String = "/tmp/lab"
const DT: float = 1.0 / 60.0
const RUN_TICKS: int = 90  ## 1.5 s
const WINDOW: int = 15  ## 0.25 s
const LOSS_FRAC: float = 0.30
const CELL: float = 0.5
const SKATER_R: float = 0.3
const HEAD_ON: float = 0.85  ## cos of incidence above which a hit on a >0.2 m wall is a legitimate stop, not a snag
const FWD: Vector2 = Vector2(0.0, -1.0)

var park: Node3D
var batch_n: int = 48
var skaters: Array = []
var gravity: float = 18.0
var args: Dictionary = {}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var t0: int = Time.get_ticks_msec()
	if args.has("merge"):
		_merge(int(args["merge"]))
		get_tree().quit(0)
		return
	await _main()
	print("SNAG runtime %.1f s" % (float(Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit(0)


func _main() -> void:
	park = Park.new()
	park.name = "Park"
	add_child(park)
	if args.has("batch"):
		batch_n = int(args["batch"])
	await get_tree().physics_frame
	await get_tree().physics_frame
	var pieces: Array = _collect_pieces()
	if args.has("list"):
		for p: Dictionary in pieces:
			var bb: AABB = p["aabb"]
			print("SNAGPIECE %s pos=%s size=%s" % [p["name"], bb.position, bb.size])
		print("SNAGPIECE total %d" % pieces.size())
		return
	await _make_skaters(batch_n)
	var tune: Variant = skaters[0].get("tune")
	if tune != null and tune.get("gravity") != null:
		gravity = float(tune.get("gravity"))
	if args.has("replay"):
		await _replay(int(args["replay"]))
		return
	var runs: Array = _generate(pieces)
	print("SNAG planned runs=%d pieces=%d" % [runs.size(), pieces.size()])
	var snags: Array = []
	var done: int = 0
	var t_start: int = Time.get_ticks_msec()
	while done < runs.size():
		var chunk: Array = runs.slice(done, mini(done + batch_n, runs.size()))
		var res: Array = await _run_batch(chunk)
		snags.append_array(res)
		done += chunk.size()
		if (done / batch_n) % 20 == 0:
			print("SNAGPROGRESS %d/%d runs, %d snags, %.0f s" % [done, runs.size(), snags.size(), float(Time.get_ticks_msec() - t_start) / 1000.0])
	if args.has("nshards") and int(args["nshards"]) > 1:
		_save_raw(runs.size(), snags)
	else:
		_report(runs.size(), snags)


# --- pieces -----------------------------------------------------------------------------------------

func _top_piece(n: Node) -> Node:
	var cur: Node = n
	while cur != null and cur.get_parent() != park:
		cur = cur.get_parent()
	return cur


func _body_aabb(b: StaticBody3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for c: Node in b.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs == null or cs.shape == null or cs.disabled:
			continue
		var xf: Transform3D = cs.global_transform
		var bb: AABB
		if cs.shape is ConcavePolygonShape3D:
			var faces: PackedVector3Array = (cs.shape as ConcavePolygonShape3D).get_faces()
			if faces.is_empty():
				continue
			var lo: Vector3 = xf * faces[0]
			var hi: Vector3 = lo
			for v: Vector3 in faces:
				var w: Vector3 = xf * v
				lo = lo.min(w)
				hi = hi.max(w)
			bb = AABB(lo, hi - lo)
		else:
			bb = xf * cs.shape.get_debug_mesh().get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out if not first else AABB(Vector3.ZERO, Vector3(-1, -1, -1))


## Every StaticBody3D under a placed piece (plus the ground slabs, for seam runs), with its global AABB.
func _collect_pieces() -> Array:
	var only: String = str(args.get("only", ""))
	var out: Array = []
	for b: Node in park.find_children("*", "StaticBody3D", true, false):
		var sb: StaticBody3D = b as StaticBody3D
		var top: Node = _top_piece(sb)
		var bb: AABB = _body_aabb(sb)
		if bb.size.x < 0.0:
			continue
		var is_ground: bool = String(sb.name).begins_with("Ground") and sb.get_parent() == park
		var low: String = (String(top.name) + "/" + String(sb.name)).to_lower()
		if low.contains("boundary") or low.contains("fence") or low.contains("grass"):
			continue
		if not args.has("props") and (low.begins_with("bench") or low.begins_with("planter") or low.begins_with("decor") or low.contains("sign/")):
			continue  ## street furniture is meant to stop you; --props sweeps it too
		if is_ground:
			bb = bb.intersection(AABB(Vector3(-HALF_SCAN, -2, -HALF_SCAN), Vector3(2 * HALF_SCAN, 4, 2 * HALF_SCAN)))
		if bb.size.x < 0.05 or bb.size.z < 0.05 or (bb.size.x < 0.5 and bb.size.z < 0.5 and not args.has("posts")):
			continue  ## rail feet, legs and posts are not ridable pieces
		var nm: String = String(top.name) if top == sb else String(top.name) + "/" + String(sb.name)
		if only != "" and not nm.contains(only):
			continue
		out.append({"name": nm, "piece": String(top.name), "body": sb, "aabb": bb, "ground": is_ground})
	return out


const HALF_SCAN: float = 76.0


# --- run generation ---------------------------------------------------------------------------------

func _rot(v: Vector2, deg: float) -> Vector2:
	return v.rotated(deg_to_rad(deg))


func _inside(r: Rect2, p: Vector2) -> bool:
	return r.grow(-0.02).has_point(p)


func _seg_hits(r: Rect2, a: Vector2, b: Vector2) -> bool:
	for i: int in range(1, 20):
		if _inside(r, a.lerp(b, float(i) / 20.0)):
			return true
	return false


## Approach geometries for one piece: dictionaries {kind, desc, start (Vector2 xz), heading (Vector2), top (bool, start on the piece)}.
func _geoms(p: Dictionary) -> Array:
	var bb: AABB = p["aabb"]
	var r: Rect2 = Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z)
	var out: Array = []
	var normals: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	var is_ground: bool = p["ground"]
	if not is_ground:
		# 1. side grazes: parallel to each side, 1 m before the piece, centre 0.32 and 0.20 m off the face
		for n: Vector2 in normals:
			var t: Vector2 = Vector2(-n.y, n.x)
			var face_c: Vector2 = r.get_center() + Vector2(n.x * r.size.x * 0.5, n.y * r.size.y * 0.5)
			var half: float = (r.size.y if absf(n.x) > 0.5 else r.size.x) * 0.5
			for dir: float in [1.0, -1.0]:
				for off: float in [0.32, 0.20]:
					var start: Vector2 = face_c + n * off - t * dir * (half + 1.0)
					out.append({"kind": "side", "desc": "side n=%s dir=%+d off=%.2f" % [_v2s(n), int(dir), off], "start": start, "heading": t * dir, "top": false})
		# 2. corners at 15/30/45/60 degrees to a side
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var corner: Vector2 = Vector2(r.get_center().x + sx * r.size.x * 0.5, r.get_center().y + sz * r.size.y * 0.5)
				var seen: Dictionary = {}
				for base: Vector2 in [Vector2(-sx, 0.0), Vector2(0.0, -sz)]:
					for ang: float in [15.0, 30.0, 45.0, 60.0]:
						for sgn: float in [1.0, -1.0]:
							var h: Vector2 = _rot(base, ang * sgn).normalized()
							for perp: float in [0.18, -0.18]:  ## clip the corner with the sphere rather than hit it dead-centre
								var aim: Vector2 = corner + Vector2(-h.y, h.x) * perp
								var start: Vector2 = aim - h * 2.5
								var key: String = "%d,%d,%d" % [roundi(h.x * 100.0), roundi(h.y * 100.0), int(perp * 100.0)]
								if seen.has(key) or _inside(r, start) or _seg_hits(r, start, aim):
									continue
								seen[key] = true
								out.append({"kind": "corner", "desc": "corner (%+d,%+d) a=%d perp=%+.2f" % [int(sx), int(sz), int(ang), perp], "start": start, "heading": h, "top": false})
	# 3. onto the foot of each face (0/20/40 off-axis) and 4. off the deck edges (same angles) from on top
	for n: Vector2 in normals:
		var t: Vector2 = Vector2(-n.y, n.x)
		var width: float = (r.size.y if absf(n.x) > 0.5 else r.size.x)
		var face_c: Vector2 = r.get_center() + Vector2(n.x * r.size.x * 0.5, n.y * r.size.y * 0.5)
		var lats: Array = [0.5] if width < 3.0 else [0.5, 0.15, 0.85]
		for f: float in lats:
			var aim: Vector2 = face_c + t * (f - 0.5) * width
			for ang: float in [0.0, 20.0, -20.0, 40.0, -40.0]:
				var h: Vector2 = _rot(-n, ang)
				out.append({"kind": "face", "desc": "foot n=%s lat=%.2f a=%+d" % [_v2s(n), f, int(ang)], "start": aim - h * 2.0, "heading": h, "top": false})
				if is_ground or f != 0.5 and width < 6.0:
					continue
				var h2: Vector2 = _rot(n, ang)
				out.append({"kind": "deck", "desc": "deck n=%s lat=%.2f a=%+d" % [_v2s(n), f, int(ang)], "start": aim - h2 * 2.5, "heading": h2, "top": true})
	return out


func _v2s(v: Vector2) -> String:
	return "%+d,%+d" % [int(v.x), int(v.y)]


func _generate(pieces: Array) -> Array:
	var speeds: Array = []
	for s: String in str(args.get("speeds", "4,8,12")).split(","):
		speeds.append(float(s))
	var keep: int = int(args.get("keep", "100"))  ## percent of approach geometries kept (deterministic hash pick)
	var shard: int = int(args.get("shard", "0"))
	var nshards: int = int(args.get("nshards", "1"))
	var ridx: int = 0
	var fwd_pass: bool = str(args.get("fwd", "1")) != "0"
	var runs: Array = []
	var counter: int = 0
	for p: Dictionary in pieces:
		var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
		for g: Dictionary in _geoms(p):
			counter += 1
			if keep < 100 and (counter * 7919 + 13) % 101 >= keep * 101 / 100:
				continue
			var st: Vector2 = g["start"]
			var from_y: float = (p["aabb"] as AABB).end.y + 1.0 if g["top"] else 2.5
			var q := PhysicsRayQueryParameters3D.create(Vector3(st.x, from_y, st.y), Vector3(st.x, -3.0, st.y), 1)
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				continue
			var nrm: Vector3 = hit["normal"]
			var pos: Vector3 = (hit["position"] as Vector3) + Vector3(0.0, 0.01, 0.0)
			if nrm.y < 0.3 or absf(st.x) > 74.5 or absf(st.y) > 74.5:
				continue
			if g["top"] and pos.y < 0.3:
				continue
			var hd: Vector2 = g["heading"]
			var dir: Vector3 = Vector3(hd.x, 0.0, hd.y).slide(nrm).normalized()
			for sp: float in speeds:
				for fwd: bool in ([false, true] if fwd_pass and sp >= 8.0 else [false]):
					ridx += 1
					if ridx % nshards != shard:
						continue
					runs.append({"piece": p["name"], "top": p["piece"], "kind": g["kind"], "desc": g["desc"], "pos": pos, "dir": dir, "normal": nrm,
						"speed": sp, "fwd": fwd, "aabb_top": (p["aabb"] as AABB).end.y})
	return runs


# --- running ---------------------------------------------------------------------------------------

func _make_skaters(n: int) -> void:
	var script: GDScript = load("res://game/skater/skater.gd") as GDScript
	for i: int in n:
		var sk: CharacterBody3D = script.new()
		sk.name = "SweepSkater%d" % i
		add_child(sk)
		sk.scripted_input = true
		sk.set_meta("rec", [])
		sk.physics_ticked.connect(_on_tick.bind(sk))
		skaters.append(sk)
	await get_tree().physics_frame
	for sk: Variant in skaters:
		sk.set_input(Vector2.ZERO, [], [])


func _on_tick(frame: Dictionary, sk: CharacterBody3D) -> void:
	var cols: Array = []
	for i: int in sk.get_slide_collision_count():
		var c: KinematicCollision3D = sk.get_slide_collision(i)
		cols.append([c.get_collider_id(), c.get_normal(), c.get_position()])
	var rec: Array = sk.get_meta("rec")
	rec.append([frame["pos"], frame["vel"], frame["state"], frame["on_floor"], frame["on_wall"], sk.get_wall_normal() if sk.is_on_wall() else Vector3.ZERO,
		frame["events"].duplicate(), cols, frame["floor_normal"], frame["launch_normal"], frame["vert_air"]])


func _place(sk: Variant, run: Dictionary) -> void:
	sk.respawn()
	var dir: Vector3 = run["dir"]
	var nrm: Vector3 = run["normal"]
	sk.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), run["pos"])
	sk.velocity = dir * float(run["speed"])
	sk.facing = dir
	sk.board_up = nrm
	sk._floor_normal = nrm
	sk.up_direction = nrm
	sk.speed = float(run["speed"])
	sk.vert_air = false
	sk._wall_normal = Vector3.ZERO
	sk._launch_normal = Vector3.UP
	sk.set_input(FWD if run["fwd"] else Vector2.ZERO, [], [])
	sk.set_meta("rec", [])


func _run_batch(chunk: Array) -> Array:
	for i: int in chunk.size():
		_place(skaters[i], chunk[i])
	for t: int in RUN_TICKS:
		await get_tree().physics_frame
	var found: Array = []
	for i: int in chunk.size():
		var s: Variant = _analyse(skaters[i].get_meta("rec"), chunk[i])
		if s != null:
			found.append_array(s)
	return found


func _energy(rec: Array, i: int) -> float:
	var v: Vector3 = rec[i][1]
	var p: Vector3 = rec[i][0]
	return 0.5 * v.length_squared() + gravity * p.y


## Snags in one run: Array of dictionaries (possibly empty).
func _analyse(rec: Array, run: Dictionary) -> Variant:
	var out: Array = []
	var n: int = rec.size()
	var i: int = 2
	while i + WINDOW < n:
		var j: int = i + WINDOW
		var excluded: bool = false
		for k: int in range(i + 1, j + 1):
			for e: String in rec[k][6]:
				if e == "bail" or e == "respawn" or e.begins_with("land"):
					excluded = true
		if excluded:
			i += 1
			continue
		var v0: float = (rec[i][1] as Vector3).length()
		var y0: float = (rec[i][0] as Vector3).y
		var e0: float = _energy(rec, i)
		var ref: float = 0.5 * v0 * v0 + gravity * maxf(y0, 0.0)
		var loss: float = e0 - _energy(rec, j)
		var hard: bool = false
		if v0 > 4.0:
			for k: int in range(i, j + 1):
				if (rec[k][1] as Vector3).length() < 1.0 and rec[k][2] == "ROLLING":
					hard = true
		if (ref > 0.5 and loss > LOSS_FRAC * ref) or hard:
			out.append(_describe(rec, run, i, j, loss / maxf(ref, 0.001), hard))
			i = j + 15  ## one snag per event
			continue
		i += 1
	return out


func _describe(rec: Array, run: Dictionary, i: int, j: int, frac: float, hard: bool) -> Dictionary:
	# onset: the tick with the biggest single-tick energy loss
	var m: int = i + 1
	var worst: float = -1e9
	for k: int in range(i + 1, j + 1):
		var d: float = _energy(rec, k - 1) - _energy(rec, k)
		if d > worst:
			worst = d
			m = k
	var vdir: Vector3 = (rec[maxi(m - 1, 0)][1] as Vector3).normalized()
	var best: Array = []
	var best_score: float = 1e9
	for k: int in range(maxi(m - 2, 0), mini(m + 2, rec.size())):
		for c: Array in rec[k][7]:
			var score: float = (c[1] as Vector3).dot(vdir)
			if score < best_score:
				best_score = score
				best = c
	var d: Dictionary = {"run": run, "tick": m, "loss_frac": frac, "hard_stop": hard, "state": rec[m][2],
		"pos": rec[m][0], "speed_before": (rec[i][1] as Vector3).length(), "speed_after": (rec[j][1] as Vector3).length(),
		"on_wall": rec[m][4], "wall_normal": rec[m][5], "on_floor": rec[m][3],
		"collider": "none", "collider_path": "", "normal": Vector3.ZERO, "contact": rec[m][0], "contact_h": 0.0, "horizontal": false,
		"owner": str(run["top"]), "kind": "logic", "incidence": 0.0, "obstacle_h": 0.0, "head_on": false}
	if best.is_empty():
		return d
	var obj: Object = instance_from_id(best[0])
	var node: Node = obj as Node
	if node != null:
		d["collider"] = String(node.name)
		d["collider_path"] = str(park.get_path_to(node))
		var tp: Node = _top_piece(node)
		d["owner"] = String(tp.name) + "/" + String(node.name) if tp != null and tp != node else String(node.name)
	var nrm: Vector3 = best[1]
	var pt: Vector3 = best[2]
	d["normal"] = nrm
	d["contact"] = pt
	d["contact_h"] = pt.y - (rec[m][0] as Vector3).y
	d["horizontal"] = absf(nrm.y) < 0.35
	d["incidence"] = -nrm.dot(vdir)  ## 1 = dead head-on into the surface, 0 = grazing
	var obst_h: float = 0.0
	if node != null and node is StaticBody3D:
		obst_h = _body_aabb(node as StaticBody3D).end.y - (rec[m][0] as Vector3).y
	d["obstacle_h"] = obst_h
	d["head_on"] = d["horizontal"] and float(d["incidence"]) > HEAD_ON and obst_h > 0.2  ## a real wall hit square-on: stopping is correct
	d["kind"] = _classify(rec, run, m, best, d)
	return d


func _classify(rec: Array, run: Dictionary, m: int, col: Array, d: Dictionary) -> String:
	var nrm: Vector3 = col[1]
	var floorish: bool = nrm.y > 0.85
	if floorish:
		# a seam: the floor under us changed from one body to another of (nearly) the same plane
		for k: int in range(maxi(m - 6, 0), m):
			for c: Array in rec[k][7]:
				if (c[1] as Vector3).y > 0.85 and c[0] != col[0] and (c[1] as Vector3).dot(nrm) > 0.98:
					return "seam"
		return "seam" if run["kind"] == "face" and float(d["contact_h"]) < 0.1 else "facet"
	var kind: String = str(run["kind"])
	if kind == "corner":
		return "corner"
	if kind == "side":
		return "side"
	if absf(float(col[2].y) - float(run["aabb_top"])) < 0.25 and kind == "deck":
		return "lip"
	if float(d["contact_h"]) < 0.5:
		return "foot"
	return "wall"


# --- report ----------------------------------------------------------------------------------------

func _run_str(r: Dictionary) -> String:
	var p: Vector3 = r["pos"]
	var dr: Vector3 = r["dir"]
	return "%s %s v=%d %s start=(%.1f,%.2f,%.1f) dir=(%.2f,%.2f,%.2f)" % [r["piece"], r["desc"], int(r["speed"]), "fwd" if r["fwd"] else "neutral", p.x, p.y, p.z, dr.x, dr.y, dr.z]


func _v3s(v: Vector3) -> String:
	return "(%.2f,%.2f,%.2f)" % [v.x, v.y, v.z]


func _report(n_runs: int, all_snags: Array) -> void:
	var groups: Dictionary = {}
	var snags: Array = []
	var headon: int = 0
	for s: Dictionary in all_snags:
		if bool(s.get("head_on", false)) and not args.has("include_headon"):
			headon += 1
		else:
			snags.append(s)
	for s: Dictionary in snags:
		var c: Vector3 = s["contact"]
		var key: String = "%s@%.1f,%.1f" % [s["owner"], roundf(c.x / CELL) * CELL, roundf(c.z / CELL) * CELL]
		if not groups.has(key):
			groups[key] = {"key": key, "piece": s["owner"], "cell": [roundf(c.x / CELL) * CELL, roundf(c.z / CELL) * CELL], "count": 0, "loss_sum": 0.0, "worst": s,
				"kinds": {}, "head_on": 0}
		var g: Dictionary = groups[key]
		g["count"] = int(g["count"]) + 1
		g["loss_sum"] = float(g["loss_sum"]) + float(s["loss_frac"])
		g["kinds"][s["kind"]] = int((g["kinds"] as Dictionary).get(s["kind"], 0)) + 1
		if float(s["loss_frac"]) > float((g["worst"] as Dictionary)["loss_frac"]):
			g["worst"] = s
	var hot: Array = groups.values()
	hot.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["count"] != b["count"]:
			return int(a["count"]) > int(b["count"])
		return float(a["loss_sum"]) > float(b["loss_sum"]))
	var rank: int = 0
	var shown: int = int(args.get("show", "40"))
	for g: Dictionary in hot:
		var w: Dictionary = g["worst"]
		var kinds: Dictionary = g["kinds"]
		var kind: String = "logic"
		var kc: int = -1
		for k: String in kinds:
			if int(kinds[k]) > kc:
				kc = int(kinds[k])
				kind = k
		g["kind"] = kind
		g["rank"] = rank
		if rank < shown:
			print("SNAG %s (%.1f,%.1f) count=%d worst_loss=%d%% kind=%s normal=%s contact_h=%.2f incidence=%.2f example=%s" % [g["piece"], (g["cell"] as Array)[0], (g["cell"] as Array)[1],
				g["count"], roundi(float(w["loss_frac"]) * 100.0), kind, _v3s(w["normal"]), float(w["contact_h"]), float(w["incidence"]), _run_str(w["run"])])
		rank += 1
	print("SNAG note %d square-on wall hits (incidence>%.2f onto a >0.2 m obstacle) excluded as legitimate stops; --include_headon keeps them" % [headon, HEAD_ON])
	print("SNAG summary runs=%d snags=%d hotspots=%d" % [n_runs, snags.size(), hot.size()])
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var hj: Array = []
	for g: Dictionary in hot:
		hj.append(_jsonable(g))
	var sj: Array = []
	for s: Dictionary in snags:
		sj.append(_jsonable(s))
	var f: FileAccess = FileAccess.open(OUT_DIR + "/snags.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "runs": n_runs, "snags": snags.size(), "headon_excluded": headon, "hotspots": hj, "all": sj}, "  "))
	f.close()


func _save_raw(n_runs: int, snags: Array) -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var f: FileAccess = FileAccess.open(OUT_DIR + "/snags_raw_%s.json" % str(args.get("shard", "0")), FileAccess.WRITE)
	f.store_string(JSON.stringify({"runs": n_runs, "snags": _jsonable(snags)}))
	f.close()
	print("SNAG shard %s done runs=%d snags=%d" % [str(args.get("shard", "0")), n_runs, snags.size()])


func _merge(n: int) -> void:
	var runs: int = 0
	var snags: Array = []
	for i: int in n:
		var f: FileAccess = FileAccess.open(OUT_DIR + "/snags_raw_%d.json" % i, FileAccess.READ)
		if f == null:
			print("SNAG crash shard %d produced no output" % i)
			continue
		var d: Dictionary = JSON.parse_string(f.get_as_text())
		runs += int(d["runs"])
		for s: Dictionary in d["snags"]:
			for k: String in ["pos", "wall_normal", "normal", "contact"]:
				var a: Array = s[k]
				s[k] = Vector3(a[0], a[1], a[2])
			s["run"] = _unjson_run(s["run"])
			snags.append(s)
	_report(runs, snags)


func _jsonable(v: Variant) -> Variant:
	if v is Vector3:
		return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
	if v is Vector2:
		return [v.x, v.y]
	if v is Dictionary:
		var o: Dictionary = {}
		for k: Variant in v:
			o[str(k)] = _jsonable(v[k])
		return o
	if v is Array:
		var a: Array = []
		for x: Variant in v:
			a.append(_jsonable(x))
		return a
	if v is float and not is_finite(v):
		return 0.0
	return v


func _unjson_run(d: Dictionary) -> Dictionary:
	var r: Dictionary = d.duplicate()
	for k: String in ["pos", "dir", "normal"]:
		var a: Array = d[k]
		r[k] = Vector3(a[0], a[1], a[2])
	return r


# --- replay ----------------------------------------------------------------------------------------

func _replay(rank: int) -> void:
	var f: FileAccess = FileAccess.open(OUT_DIR + "/snags.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var hot: Dictionary = data["hotspots"][rank]
	var run: Dictionary = _unjson_run((hot["worst"] as Dictionary)["run"])
	print("TRACE hotspot %d %s" % [rank, hot["key"]])
	print("TRACE run %s" % _run_str(run))
	var sk: Variant = skaters[0]
	_place(sk, run)
	for t: int in RUN_TICKS:
		await get_tree().physics_frame
	var rec: Array = sk.get_meta("rec")
	var onset: int = int((hot["worst"] as Dictionary)["tick"])
	var snag_list: Array = _analyse(rec, run)
	if not snag_list.is_empty():
		onset = int((snag_list[0] as Dictionary)["tick"])
	print("TRACE onset tick=%d (replayed snags=%d)" % [onset, snag_list.size()])
	for k: int in range(maxi(onset - 6, 0), mini(onset + 8, rec.size())):
		var r: Array = rec[k]
		var p: Vector3 = r[0]
		var v: Vector3 = r[1]
		var cs: String = ""
		var ground_n: int = 0
		for c: Array in r[7]:
			var o: Node = instance_from_id(c[0]) as Node
			var nm: String = String(park.get_path_to(o)) if o != null else "?"
			if nm.begins_with("Ground") and not args.has("allcols"):
				ground_n += 1
				continue
			cs += " [%s n=%s pt=(%.2f,%.2f,%.2f)]" % [nm, _v3s(c[1]), c[2].x, c[2].y, c[2].z]
		print("TRACE t=%2d pos=(%.2f,%.3f,%.2f) vel=(%.2f,%.2f,%.2f) spd=%5.2f %-7s floor=%d wall=%d%s fn=%s launch=%s vert=%d ev=%s ground_hits=%d%s" % [k, p.x, p.y, p.z, v.x, v.y, v.z, v.length(), r[2],
			int(r[3]), int(r[4]), (" wn=" + _v3s(r[5])) if r[4] else "", _v3s(r[8]), _v3s(r[9]), int(r[10]), str(r[6]), ground_n, cs])
