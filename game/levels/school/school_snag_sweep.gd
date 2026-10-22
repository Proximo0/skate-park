extends "res://tests/lab/snag_sweep.gd"
## The snag sweep (tests/lab/snag_sweep.gd) run on the School level instead of the practice park. The School's geometry
## is batched into one StaticBody3D per area, so every collision shape (box, prism, cylinder) is swept as its own
## piece, over the whole campus (the park sweep only scans +-76 m), with the traffic and the people taken out.
## Run (one process): godot --headless --fixed-fps 60 --path . res://game/levels/school/school_snag_sweep.tscn -- --keep=30
## Same options as the park sweep (--only=<area or shape name>, --speeds=, --fwd=0, --list, --show=N).

## Shapes wider than this are floor slabs, not pieces to approach.
const MAX_PIECE: float = 40.0


func _main() -> void:
	park = SchoolLevel.new()
	park.name = "Park"
	add_child(park)
	for n: String in ["Traffic", "Pedestrians", "CrowdShadowLod"]:
		var c: Node = park.get_node_or_null(n)
		if c != null:
			c.queue_free()
	if args.has("batch"):
		batch_n = int(args["batch"])
	await get_tree().physics_frame
	await get_tree().physics_frame
	var pieces: Array = _collect_pieces()
	if args.has("list"):
		for p: Dictionary in pieces:
			var bb: AABB = p["aabb"]
			printerr("SNAGPIECE %s pos=%s size=%s" % [p["name"], bb.position, bb.size])
		printerr("SNAGPIECE total %d" % pieces.size())
		return
	await _make_skaters(batch_n)
	var tune: Variant = skaters[0].get("tune")
	if tune != null and tune.get("gravity") != null:
		gravity = float(tune.get("gravity"))
	var runs: Array = _generate(pieces)
	printerr("SNAG planned runs=%d pieces=%d" % [runs.size(), pieces.size()])
	var snags: Array = []
	var done: int = 0
	while done < runs.size():
		var chunk: Array = runs.slice(done, mini(done + batch_n, runs.size()))
		var res: Array = await _run_batch(chunk)
		snags.append_array(res)
		done += chunk.size()
	if args.has("nshards") and int(args["nshards"]) > 1:
		_save_raw(runs.size(), snags)
	else:
		_report(runs.size(), snags)


## Every solid shape of the level's static bodies as a piece (named area/shape), minus floor slabs, the boundary
## walls, posts and trunks.
func _collect_pieces() -> Array:
	var only: String = str(args.get("only", ""))
	var out: Array = []
	for n: Node in park.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = n as CollisionShape3D
		var sb: StaticBody3D = cs.get_parent() as StaticBody3D
		if sb == null or cs.shape == null or cs.disabled or cs.shape is ConcavePolygonShape3D:
			continue
		if (sb.collision_layer & 1) == 0:
			continue
		var nm: String = String(sb.name) + "/" + String(cs.name)
		if nm.to_lower().contains("boundary") or str(park.get_path_to(sb)).to_lower().contains("boundary"):
			continue
		var bb: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
		if bb.size.x > MAX_PIECE or bb.size.z > MAX_PIECE:
			continue
		if bb.size.x < 0.5 and bb.size.z < 0.5:
			continue  ## posts, poles and trunks are meant to stop you
		if only != "" and not nm.contains(only):
			continue
		out.append({"name": nm, "piece": String(sb.name), "body": sb, "aabb": bb, "ground": false})
	return out


## As the park sweep's, but over the level's bounds, with each start found by a ray from above the piece's own base
## (the field is 3 m down and the roofs 3 to 6 m up).
func _generate(pieces: Array) -> Array:
	var speeds: Array = []
	for s: String in str(args.get("speeds", "4,8,12")).split(","):
		speeds.append(float(s))
	var keep: int = int(args.get("keep", "100"))
	var shard: int = int(args.get("shard", "0"))
	var nshards: int = int(args.get("nshards", "1"))
	var fwd_pass: bool = str(args.get("fwd", "1")) != "0"
	var inner: Rect2 = (park as Level).bounds.grow(-0.5)
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var runs: Array = []
	var counter: int = 0
	var ridx: int = 0
	for p: Dictionary in pieces:
		var bb: AABB = p["aabb"]
		for g: Dictionary in _geoms(p):
			counter += 1
			if keep < 100 and (counter * 7919 + 13) % 101 >= keep * 101 / 100:
				continue
			var st: Vector2 = g["start"]
			if not inner.has_point(st):
				continue
			var from_y: float = bb.end.y + 1.0 if g["top"] else bb.position.y + 2.5
			var q := PhysicsRayQueryParameters3D.create(Vector3(st.x, from_y, st.y), Vector3(st.x, bb.position.y - 4.0, st.y), 1)
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				continue
			var nrm: Vector3 = hit["normal"]
			var pos: Vector3 = (hit["position"] as Vector3) + Vector3(0.0, 0.01, 0.0)
			if nrm.y < 0.3:
				continue
			if g["top"] and pos.y < bb.position.y + 0.3:
				continue
			var hd: Vector2 = g["heading"]
			var dir: Vector3 = Vector3(hd.x, 0.0, hd.y).slide(nrm).normalized()
			for sp: float in speeds:
				for fwd: bool in ([false, true] if fwd_pass and sp >= 8.0 else [false]):
					ridx += 1
					if ridx % nshards != shard:
						continue
					runs.append({"piece": p["name"], "top": p["piece"], "kind": g["kind"], "desc": g["desc"], "pos": pos, "dir": dir,
						"normal": nrm, "speed": sp, "fwd": fwd, "aabb_top": bb.end.y})
	return runs
