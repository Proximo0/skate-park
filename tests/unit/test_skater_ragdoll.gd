extends TestCase
## SkaterRagdoll. Structure checks run in-process; the dynamic checks (real physics frames) run
## tests/ragdoll_harness.gd in a child Godot process because the unit runner cannot step frames.

const SCENARIOS: Array = [["ground", 5.0], ["ground", 12.0], ["ground", 20.0], ["wall", 15.0], ["wall", 20.0]]


func _tree_root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _make_world() -> Dictionary:
	var world: Node3D = Node3D.new()
	_tree_root().add_child(world)
	var body: Node3D = PlaceholderSkater.build_body()
	body.position.y = PlaceholderSkater.DECK_TOP_Y
	world.add_child(body)
	var board: Node3D = PlaceholderSkater.build_board()
	world.add_child(board)
	return {"world": world, "body": body, "board": board}


func test_spawn_builds_parts_with_sane_mass_and_layers() -> void:
	var w: Dictionary = _make_world()
	var world: Node3D = w["world"]
	var rd: SkaterRagdoll = SkaterRagdoll.spawn(w["body"], w["board"], Vector3(0, 0, -15), Vector3(1, 0, 0), world)
	assert_eq(rd.parts.size(), 12, "11 body parts and the board")
	assert_eq(rd.joints.size(), 10, "neck, spine, 2 shoulders, 2 elbows, 2 hips, 2 knees")
	var total: float = 0.0
	for pname: String in rd.parts.keys():
		var rb: RigidBody3D = rd.parts[pname]
		if pname != "board":
			total += rb.mass
		assert_eq(rb.collision_mask, 1, pname + " collides with the world only")
		assert_eq(rb.collision_layer & 2, 0, pname + " is not on the skater layer")
		assert_true(rb.linear_velocity.length() > 5.0, pname + " carries the skater's velocity")
	assert_true(total > 35.0 and total < 45.0, "total mass about 40 kg, got %f" % total)
	assert_false(rd.settled(), "not settled at spawn")
	var t: Transform3D = rd.pelvis_transform()
	assert_true(t.origin.is_finite() and t.basis.is_finite(), "pelvis transform is finite")
	rd.finish()
	world.free()


func test_driven_nodes_start_where_they_were() -> void:
	var w: Dictionary = _make_world()
	var world: Node3D = w["world"]
	var body: Node3D = w["body"]
	var names: PackedStringArray = ["Hips", "Head", "LeftLowerArm", "RightFoot", "LeftHand"]
	var before: Array[Transform3D] = []
	for n: String in names:
		before.append((body.find_child(n, true, false) as Node3D).global_transform)
	var board_before: Transform3D = (w["board"] as Node3D).global_transform
	var rd: SkaterRagdoll = SkaterRagdoll.spawn(body, w["board"], Vector3.ZERO, Vector3.ZERO, world)
	for i: int in names.size():
		var now: Transform3D = (body.find_child(names[i], true, false) as Node3D).global_transform
		assert_true(now.origin.distance_to(before[i].origin) < 0.001, names[i] + " not moved by spawn")
		assert_true(now.basis.is_equal_approx(before[i].basis), names[i] + " keeps its orientation")
	assert_true((w["board"] as Node3D).global_transform.origin.distance_to(board_before.origin) < 0.001, "board not moved")
	rd.finish()
	world.free()


func test_finish_leaves_no_stray_nodes() -> void:
	var w: Dictionary = _make_world()
	var world: Node3D = w["world"]
	var kids: int = world.get_child_count()
	var rd: SkaterRagdoll = SkaterRagdoll.spawn(w["body"], w["board"], Vector3(0, 0, -10), Vector3.ZERO, world)
	assert_eq(world.get_child_count(), kids + 1, "one ragdoll node added")
	var part_list: Array = rd.parts.values()
	rd.finish()
	assert_eq(world.get_child_count(), kids, "ragdoll node removed from the world")
	assert_true(rd.is_queued_for_deletion(), "ragdoll node queued for deletion")
	for p: Variant in part_list:
		assert_false(is_instance_valid(p), "part freed")
	assert_eq(rd.parts.size(), 0, "parts cleared")
	world.free()


func test_spawn_is_deterministic() -> void:
	var out: Array[Vector3] = []
	for i: int in 2:
		var w: Dictionary = _make_world()
		var world: Node3D = w["world"]
		var rd: SkaterRagdoll = SkaterRagdoll.spawn(w["body"], w["board"], Vector3(1, 2, -12), Vector3(0, 1, 0), world)
		out.append((rd.parts["board"] as RigidBody3D).angular_velocity)
		rd.finish()
		world.free()
	assert_true(out[0].is_equal_approx(out[1]), "same inputs give the same board spin")


## Runs the harness in a child process. Returns the key=value pairs of its RAGDOLL line, or {}.
func _run_harness(scenario: String, speed: float) -> Dictionary:
	var out: Array = []
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path",
		ProjectSettings.globalize_path("res://"), "-s", "res://tests/ragdoll_harness.gd", "--", scenario, str(speed)]
	OS.execute(OS.get_executable_path(), args, out, true)
	var result: Dictionary = {}
	for chunk: Variant in out:
		for line: String in str(chunk).split("\n"):
			if line.begins_with("RAGDOLL "):
				for kv: String in line.trim_prefix("RAGDOLL ").split(" "):
					var pair: PackedStringArray = kv.split("=")
					if pair.size() == 2:
						result[pair[0]] = pair[1]
	return result


func test_physics_bails_settle_stay_above_ground_and_stay_stable() -> void:
	for sc: Array in SCENARIOS:
		var tag: String = "%s %.0f m/s" % [sc[0], sc[1]]
		var r: Dictionary = _run_harness(sc[0], sc[1])
		if r.is_empty():
			failures.append("harness produced no result for " + tag)
			continue
		assert_eq(int(r["nan"]), 0, tag + " no NaN or runaway transforms")
		assert_true(float(r["settle_t"]) > 0.0 and float(r["settle_t"]) <= 3.0, tag + " settles within 3 s, got " + str(r["settle_t"]))
		assert_true(float(r["min_y"]) > -0.05, tag + " stays above the ground, min y " + str(r["min_y"]))
		assert_true(float(r["board_min_y"]) > -0.05, tag + " board stays above the ground")
		assert_true(float(r["max_speed"]) < 25.0, tag + " nothing explodes, max speed " + str(r["max_speed"]))
		assert_true(float(r["final_speed"]) < 0.6, tag + " comes to rest")
		assert_true(float(r["stretch"]) < 0.6, tag + " joints never tear apart, peak " + str(r["stretch"]))
		assert_true(float(r["final_stretch"]) < 0.05, tag + " joints are whole at rest")
		assert_true(float(r["final_viol"]) < 0.3, tag + " limits respected at rest")
		assert_eq(int(r["ragdoll_alive"]), 0, tag + " finish() frees the ragdoll")
		assert_eq(int(r["node_delta"]), 0, tag + " no stray nodes after finish()")
