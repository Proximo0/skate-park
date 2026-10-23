extends TestCase
## Park dressing: the builders return nodes, litter has no collision, cans, dumpsters and cars do, the graffiti textures stay
## inside their memory budget and really paint something, and the park carries the dressing.

const TEXTURE_BUDGET_BYTES: int = 8 * 1024 * 1024


func _count(root: Node, cls: String) -> int:
	return root.find_children("*", cls, true, false).size()


func test_builders_return_nodes() -> void:
	var nodes: Array[Node] = [
		ParkDressing.build([]), ParkDressing.graffiti(), ParkDressing.trash_cans(), ParkDressing.cars(), ParkDressing.litter([]),
		ParkDressing.walls(), ParkDressing.bin(Color.SEA_GREEN), ParkDressing.bin(Color.SEA_GREEN, true), ParkDressing.overflowing_bin(3),
		ParkDressing.car("hatch", Color.RED), ParkDressing.car("pickup", Color.RED), ParkDressing.car("van", Color.RED),
		ParkDressing.dumpster(Color.STEEL_BLUE, "tag_drip"),
	]
	for n: Node in nodes:
		assert_true(n != null and n.get_child_count() > 0, "builder returns a populated node")
		n.free()


func test_counts_are_in_range() -> void:
	var root: Node3D = ParkDressing.build([])
	var counts: Dictionary = root.get_meta("counts") as Dictionary
	assert_true(int(counts["graffiti"]) >= 15 and int(counts["graffiti"]) <= 25, "15 to 25 graffiti pieces, got %d" % int(counts["graffiti"]))
	assert_true(int(counts["cars"]) >= 6 and int(counts["cars"]) <= 10, "6 to 10 cars, got %d" % int(counts["cars"]))
	assert_true(int(counts["litter"]) >= 150 and int(counts["litter"]) <= 300, "150 to 300 litter pieces, got %d" % int(counts["litter"]))
	assert_true(int(counts["cans"]) >= 10, "trash cans and dumpsters placed")
	assert_true(int(counts["walls"]) >= 3, "graffiti walls placed")
	root.free()


func test_litter_has_no_collision_and_is_multimesh() -> void:
	var lit: Node3D = ParkDressing.litter([])
	assert_eq(_count(lit, "CollisionShape3D"), 0, "litter has no collision shapes")
	assert_eq(_count(lit, "StaticBody3D"), 0, "litter has no bodies")
	assert_true(_count(lit, "MultiMeshInstance3D") > 5, "litter is batched in multimeshes")
	assert_eq(_count(lit, "MeshInstance3D"), 0, "no loose litter meshes")
	for kit: String in ["can_crushed_a", "cup", "paper_crumpled_a", "chip_bag_a", "newspaper", "pizza_box", "napkin"]:
		assert_true(lit.get_node_or_null("Litter_" + kit) != null, "litter item %s has its own multimesh" % kit)
	lit.free()


func test_litter_is_deterministic_and_avoids_rects() -> void:
	var avoid: Array[Rect2] = [Rect2(-20.0, -20.0, 40.0, 40.0)]
	var a: Array[Vector2] = ParkDressing.litter_points(avoid, 120, _rng(7))
	var b: Array[Vector2] = ParkDressing.litter_points(avoid, 120, _rng(7))
	assert_eq(a.size(), b.size(), "same seed, same count")
	for i: int in a.size():
		assert_eq(a[i], b[i], "same seed, same point")
		assert_false(avoid[0].has_point(a[i]), "litter stays out of the avoided footprint")
		assert_true(absf(a[i].x) < Park.HALF and absf(a[i].y) < Park.HALF, "litter inside the fence")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func test_cars_have_box_collision_and_do_not_overlap() -> void:
	var cars: Node3D = ParkDressing.cars()
	var rects: Array[Rect2] = []
	for c: Node in cars.get_children():
		assert_true(c is StaticBody3D, "car is a static body")
		var body: StaticBody3D = c as StaticBody3D
		assert_eq(body.collision_layer, 1, "cars are on the world layer")
		var shapes: Array[Node] = body.find_children("*", "CollisionShape3D", true, false)
		assert_true(shapes.size() >= 1, "car has collision")
		for s: Node in shapes:
			assert_true((s as CollisionShape3D).shape is BoxShape3D, "car collision is a box")
		var half: Vector2 = Vector2(1.03, ParkDressing.car_length(body.name.split("_")[1]) * 0.5)
		if absf(body.rotation_degrees.y) > 90.0 or absf(body.rotation_degrees.y) < 1.0:
			var r := Rect2(body.position.x - half.x, body.position.z - half.y, half.x * 2.0, half.y * 2.0)
			for o: Rect2 in rects:
				assert_false(o.intersects(r), "cars do not overlap")
			rects.append(r)
		# collision is sized from the mesh: the boxes cover the model's footprint and its roof
		var mesh_bb: AABB = HoudiniProps.aabb_of(body.get_node("Model") as Node3D)
		var low: BoxShape3D = (body.get_node("CollisionBody") as CollisionShape3D).shape as BoxShape3D
		assert_true(absf(low.size.z - mesh_bb.size.z) < 0.01 and absf(low.size.x - mesh_bb.size.x) < 0.01, "%s collision matches the mesh footprint" % body.name)
		assert_true(absf(ParkDressing.car_length(body.name.split("_")[1]) - mesh_bb.size.z) < 0.05, "%s lined up by its real length" % body.name)
		# nothing in the park starts inside a car: the skater spawns well away from them
		assert_true(body.position.distance_to(Park.SPAWN_POS) > 20.0, "car far from the spawn")
	cars.free()


func test_cars_vary_in_style_and_paint() -> void:
	var cars: Node3D = ParkDressing.cars()
	var kinds: Dictionary = {}
	var paints: Dictionary = {}
	for c: Node in cars.get_children():
		kinds[c.name.split("_")[1]] = true
		var mi: MeshInstance3D = c.get_node("Model/body") as MeshInstance3D
		var mat: ShaderMaterial = mi.get_surface_override_material(0) as ShaderMaterial
		assert_true(mat != null, "%s body is a toon material" % c.name)
		paints[(mat.get_shader_parameter("albedo") as Color).to_html()] = true
		var wheel: MeshInstance3D = c.get_node("Model/wheel_fl") as MeshInstance3D
		assert_true(wheel.get_surface_override_material(0) is ShaderMaterial, "%s wheels are toon" % c.name)
	assert_eq(cars.get_child_count(), 7, "seven cars")
	assert_true(kinds.has("van"), "at least one surf van")
	assert_true(kinds.size() == 3, "all three Houdini cars used, got %s" % str(kinds.keys()))
	assert_true(paints.size() >= 6, "bodies are painted differently, got %d colours" % paints.size())
	cars.free()


func test_walls_have_collision_and_a_decal_each_and_stay_off_the_spawn() -> void:
	var w: Node3D = ParkDressing.walls()
	assert_true(w.get_child_count() >= 3, "walls placed")
	for c: Node in w.get_children():
		assert_true(c is StaticBody3D, "%s is a static body" % c.name)
		assert_eq((c as StaticBody3D).collision_layer, 1, "walls are on the world layer")
		assert_eq(c.find_children("*", "CollisionShape3D", true, false).size(), 3, "a box and two round end caps per wall")
		assert_true(c.find_children("Graffiti_*", "MeshInstance3D", true, false).size() >= 1, "%s carries graffiti" % c.name)
		var p: Vector3 = (c as Node3D).position
		assert_true(maxf(absf(p.x), absf(p.z)) > 70.0, "%s stands against the fence" % c.name)
		var mi: MeshInstance3D = c.get_node("Model/wall") as MeshInstance3D
		assert_true(mi.get_surface_override_material(0) is ShaderMaterial, "wall is toon")
	w.free()


func test_bins_use_the_houdini_model() -> void:
	var cans: Node3D = ParkDressing.trash_cans()
	var bins: int = 0
	for c: Node in cans.get_children():
		if c.get_node_or_null("Model/lid") != null:
			bins += 1
	assert_true(bins >= 10, "bins are the Houdini trash_bin, got %d" % bins)
	cans.free()


func test_cans_and_dumpsters_have_collision() -> void:
	var cans: Node3D = ParkDressing.trash_cans()
	assert_true(cans.get_child_count() >= 10, "cans placed")
	for c: Node in cans.get_children():
		assert_true(c is StaticBody3D, "%s is a static body" % c.name)
		assert_true(c.find_children("*", "CollisionShape3D", true, false).size() >= 1, "%s has collision" % c.name)
		var p: Vector3 = (c as Node3D).position
		assert_true(Vector2(p.x, p.z).distance_to(Vector2(Park.SPAWN_POS.x, Park.SPAWN_POS.z)) > 15.0, "%s away from the spawn" % c.name)
	cans.free()


func test_graffiti_is_meshes_only_and_textures_fit_the_budget() -> void:
	var g: Node3D = ParkDressing.graffiti()
	assert_eq(_count(g, "CollisionShape3D"), 0, "graffiti has no collision")
	for q: Node in g.get_children():
		var mi: MeshInstance3D = q as MeshInstance3D
		assert_true(mi.mesh is QuadMesh, "%s is a quad" % q.name)
		assert_true(mi.material_override is ShaderMaterial, "%s has a decal material" % q.name)
	g.free()
	var total: int = 0
	for id: String in GraffitiArt.ids():
		total += GraffitiArt.memory_bytes(id)
	assert_true(total < TEXTURE_BUDGET_BYTES, "graffiti textures under 8 MB, got %d" % total)


func test_graffiti_paints_something() -> void:
	# painted for real even headless: a throw-up and a sticker have opaque and transparent pixels
	for id: String in ["throw_waxy", "sticker_smile"]:
		var img: Image = GraffitiArt.paint(id)
		var sz: Vector2i = GraffitiArt.size_of(id)
		assert_eq(img.get_width(), sz.x, id + " width")
		var opaque: int = 0
		var clear: int = 0
		for y: int in range(0, sz.y, 3):
			for x: int in range(0, sz.x, 3):
				var a: float = img.get_pixel(x, y).a
				if a > 0.9:
					opaque += 1
				elif a < 0.1:
					clear += 1
		assert_true(opaque > 50, id + " has painted pixels")
		assert_true(clear > 50, id + " keeps transparent pixels")


func test_park_carries_the_dressing() -> void:
	var park := Park.new()
	park._ready()
	var d: Node = park.get_node_or_null("Dressing")
	assert_true(d != null, "the park has a Dressing node")
	if d != null:
		assert_true(d.get_node_or_null("Cars") != null, "cars present")
		assert_true(d.get_node_or_null("Litter") != null, "litter present")
	park.free()
