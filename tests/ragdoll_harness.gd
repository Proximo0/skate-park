extends SceneTree
## Real-physics harness for SkaterRagdoll (the unit runner cannot step frames). Run by test_skater_ragdoll.gd:
##   godot --headless --fixed-fps 60 --path . -s res://tests/ragdoll_harness.gd -- <scenario> <speed>
## scenario: "ground" (falls and slides on flat ground) or "wall" (flies into a wall 5 m ahead); "inj_<kind>"
## falls on the ground with a BailKind plan of that kind (styles and injuries).
## Prints one line: RAGDOLL key=value ...

const PAIRS: Array = [
	["Hips", "LeftUpperLeg"], ["LeftUpperLeg", "LeftLowerLeg"], ["LeftLowerLeg", "LeftFoot"],
	["Hips", "RightUpperLeg"], ["RightUpperLeg", "RightLowerLeg"], ["RightLowerLeg", "RightFoot"],
	["Chest", "LeftUpperArm"], ["LeftUpperArm", "LeftLowerArm"], ["LeftLowerArm", "LeftHand"],
	["Chest", "RightUpperArm"], ["RightUpperArm", "RightLowerArm"], ["RightLowerArm", "RightHand"],
	["Hips", "Spine"], ["Chest", "Neck"], ["Neck", "Head"],
]


func _initialize() -> void:
	_run.call_deferred()


func _bad(v: Vector3) -> bool:
	return is_nan(v.x) or is_nan(v.y) or is_nan(v.z) or v.length() > 1000.0


func _flex(body: Node3D, upper: String, lower: String) -> float:
	var gu: Basis = (body.find_child(upper, true, false) as Node3D).global_transform.basis.orthonormalized()
	var gl: Basis = (body.find_child(lower, true, false) as Node3D).global_transform.basis.orthonormalized()
	var rel: Basis = gu.inverse() * gl
	return atan2(rel.y.z, rel.y.y)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scenario: String = args[0] if args.size() > 0 else "ground"
	var speed: float = float(args[1]) if args.size() > 1 else 15.0
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var ground: StaticBody3D = StaticBody3D.new()
	ground.collision_layer = 1
	var gs: CollisionShape3D = CollisionShape3D.new()
	var gb: BoxShape3D = BoxShape3D.new()
	gb.size = Vector3(200, 1, 200)
	gs.shape = gb
	ground.add_child(gs)
	ground.position = Vector3(0, -0.5, 0)
	world.add_child(ground)
	if scenario == "wall":
		var wall: StaticBody3D = StaticBody3D.new()
		wall.collision_layer = 1
		var ws: CollisionShape3D = CollisionShape3D.new()
		var wb: BoxShape3D = BoxShape3D.new()
		wb.size = Vector3(20, 10, 1)
		ws.shape = wb
		wall.add_child(ws)
		wall.position = Vector3(0, 5, -5.5)
		world.add_child(wall)
	var holder: Node3D = Node3D.new()
	world.add_child(holder)
	var body: Node3D = PlaceholderSkater.build_body()
	body.position.y = PlaceholderSkater.DECK_TOP_Y
	holder.add_child(body)
	var board: Node3D = PlaceholderSkater.build_board()
	holder.add_child(board)
	await physics_frame
	var nodes_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var vel: Vector3 = Vector3(0, 0, -speed)
	var plan: Dictionary = {}
	if scenario.begins_with("inj_"):
		plan = BailKind.classify({"kind": scenario.trim_prefix("inj_"), "impact": speed, "velocity": vel})
	if scenario == "ground" or not plan.is_empty():
		vel = Vector3(0.0, -speed * 0.35, -speed * 0.94)
		holder.position.y = 1.5
	var rd: SkaterRagdoll = SkaterRagdoll.spawn(body, board, vel, Vector3(2.0, 0.5, -1.0), world, plan)
	var injured_t: Array = [-1.0]
	var repair_t: Array = [-1.0]
	var peak_w: Array = [0.0]
	rd.injured.connect(func(_p: Array) -> void: injured_t[0] = rd._time)
	rd.repairing.connect(func(_p: Array) -> void: repair_t[0] = rd._time)
	var rest: Dictionary = {}
	for p: Array in PAIRS:
		rest[p[1]] = (body.find_child(p[0], true, false) as Node3D).global_position.distance_to(
			(body.find_child(p[1], true, false) as Node3D).global_position)
	var min_y: float = 99.0
	var min_part: String = ""
	var nan: int = 0
	var stretch: float = 0.0
	var stretch_frames: int = 0
	var viol_frames: int = 0
	var elbow_viol: float = 0.0
	var knee_viol: float = 0.0
	var settle_t: float = -1.0
	var final_stretch: float = 0.0
	var final_viol: float = 0.0
	var max_speed: float = 0.0
	var board_min_y: float = 99.0
	var frames: int = 0
	while frames < 300:
		await physics_frame
		frames += 1
		for pname: String in rd.parts.keys():
			var rb: RigidBody3D = rd.parts[pname]
			if _bad(rb.global_position) or _bad(rb.linear_velocity):
				nan += 1
			if pname != "board" and rb.global_position.y < min_y:
				min_y = rb.global_position.y
				min_part = "%s@%d" % [pname, frames]
		board_min_y = minf(board_min_y, (rd.parts["board"] as RigidBody3D).global_position.y)
		max_speed = maxf(max_speed, (rd.parts["pelvis"] as RigidBody3D).linear_velocity.length())
		for p: Array in PAIRS:
			var d: float = (body.find_child(p[0], true, false) as Node3D).global_position.distance_to(
				(body.find_child(p[1], true, false) as Node3D).global_position)
			stretch = maxf(stretch, absf(d - float(rest[p[1]])))
			if absf(d - float(rest[p[1]])) > 0.08:
				stretch_frames += 1
		for s: String in ["Left", "Right"]:
			var e: float = _flex(body, s + "UpperArm", s + "LowerArm")
			elbow_viol = maxf(elbow_viol, maxf(SkaterRagdoll.ELBOW_RANGE.x - e, e - SkaterRagdoll.ELBOW_RANGE.y))
			var k: float = _flex(body, s + "UpperLeg", s + "LowerLeg")
			knee_viol = maxf(knee_viol, maxf(SkaterRagdoll.KNEE_RANGE.x - k, k - SkaterRagdoll.KNEE_RANGE.y))
			if maxf(maxf(SkaterRagdoll.ELBOW_RANGE.x - e, e - SkaterRagdoll.ELBOW_RANGE.y), maxf(SkaterRagdoll.KNEE_RANGE.x - k, k - SkaterRagdoll.KNEE_RANGE.y)) > 0.3:
				viol_frames += 1
		if args.size() > 2 and args[2] == "v":
			var worst: String = ""
			var ws: float = 0.0
			for pn: String in rd.parts.keys():
				var sp: float = (rd.parts[pn] as RigidBody3D).linear_velocity.length()
				if sp > ws:
					ws = sp
					worst = pn
			print("V %d %s %.1f y=%.2f" % [frames, worst, ws, (rd.parts["pelvis"] as RigidBody3D).global_position.y])
		if args.size() > 2 and args[2] == "t" and frames % 6 == 0:
			print("TRACE %d elbowL=%.2f kneeL=%.2f" % [frames, _flex(body, "LeftUpperArm", "LeftLowerArm"), _flex(body, "LeftUpperLeg", "LeftLowerLeg")])
		final_stretch = 0.0
		final_viol = 0.0
		for p: Array in PAIRS:
			final_stretch = maxf(final_stretch, absf((body.find_child(p[0], true, false) as Node3D).global_position.distance_to((body.find_child(p[1], true, false) as Node3D).global_position) - float(rest[p[1]])))
		for s: String in ["Left", "Right"]:
			var e2: float = _flex(body, s + "UpperArm", s + "LowerArm")
			var k2: float = _flex(body, s + "UpperLeg", s + "LowerLeg")
			final_viol = maxf(final_viol, maxf(maxf(SkaterRagdoll.ELBOW_RANGE.x - e2, e2 - SkaterRagdoll.ELBOW_RANGE.y), maxf(SkaterRagdoll.KNEE_RANGE.x - k2, k2 - SkaterRagdoll.KNEE_RANGE.y)))
		peak_w[0] = maxf(peak_w[0], rd.injury_weight())
		if settle_t < 0.0 and rd.settled():
			settle_t = frames / 60.0
	var end_w: float = rd.injury_weight()
	var end_t: Transform3D = rd.pelvis_transform()
	var end_raw: Vector3 = rd.pelvis_raw_transform().origin
	var pelvis_final_speed: float = (rd.parts["pelvis"] as RigidBody3D).linear_velocity.length()
	rd.finish()
	await physics_frame
	await physics_frame
	var nodes_after: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("RAGDOLL scenario=%s speed=%.1f settle_t=%.2f min_y=%.3f board_min_y=%.3f nan=%d stretch=%.3f elbow_viol=%.3f knee_viol=%.3f max_speed=%.1f final_speed=%.2f ragdoll_alive=%d node_delta=%d end=(%.2f,%.2f,%.2f) ground_y=%.3f stretch_frames=%d viol_frames=%d final_stretch=%.3f final_viol=%.3f injuries=%d injured_t=%.2f repair_t=%.2f peak_w=%.2f end_w=%.3f min_part=%s" % [
		scenario, speed, settle_t, min_y, board_min_y, nan, stretch, elbow_viol, knee_viol, max_speed, pelvis_final_speed,
		1 if is_instance_valid(rd) else 0, nodes_after - nodes_before, end_raw.x, end_raw.y, end_raw.z, end_t.origin.y, stretch_frames, viol_frames, final_stretch, final_viol,
		(plan.get("injuries", []) as Array).size(), injured_t[0], repair_t[0], peak_w[0], end_w, min_part])
	quit(0)
