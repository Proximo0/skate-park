extends TestCase
## World kit cost and cleanliness: the baked pedestrian body (draw surfaces, cloth mask, uniform), the crowd freeing
## its look templates, the built-in distance LOD of Pedestrians and Traffic.


func _surfaces(body: Node) -> int:
	var n: int = 0
	for m: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi.mesh != null:
			n += mi.mesh.get_surface_count()
	return n


func _baked(body: Node, joint: String) -> MeshInstance3D:
	var j: Node = body.find_child(joint, true, false)
	return j.get_node("Baked") as MeshInstance3D if j != null and j.has_node("Baked") else null


func test_baked_people_stay_within_the_surface_budget() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i: int in 10:
		var b: Node3D = PedBody.build(PedBody.random_look(rng))
		var n: int = _surfaces(b)
		assert_true(n <= 16, "look %d draws %d surfaces (budget 16)" % [i, n])
		# one baked surface per joint, never a cloth and a plain one side by side
		for j: Node in b.find_children("*", "Node3D", true, false):
			var baked: int = 0
			for c: Node in j.get_children():
				if c is MeshInstance3D and str(c.name).begins_with("Baked"):
					baked += 1
			assert_true(baked <= 1, "%s has %d baked meshes" % [j.name, baked])
		b.free()


func test_baked_vertex_alpha_is_the_cloth_mask() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var b: Node3D = PedBody.build(PedBody.random_look(rng))
	var cloth: int = 0
	var skin: int = 0
	for n: Node in b.find_children("Baked", "MeshInstance3D", true, false):
		var cols: PackedColorArray = (n as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		for c: Color in cols:
			if c.a > 0.5:
				cloth += 1
			else:
				skin += 1
	assert_true(cloth > 100, "garment vertices carry alpha 1 (%d)" % cloth)
	assert_true(skin > 100, "skin, hair and face vertices carry alpha 0 (%d)" % skin)
	b.free()


func test_recolour_gives_each_person_their_own_material() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var b: Node3D = PedBody.build(PedBody.random_look(rng))
	var shared: Material = _baked(b, "Chest").material_override
	PedBody.recolour(b, 0.4)
	var own: Material = _baked(b, "Chest").material_override
	assert_true(own != shared, "own material after recolour")
	assert_true(_baked(b, "Hips").material_override == own, "one material for the whole body")
	b.free()


func test_security_uniform_dresses_by_joint() -> void:
	var b: Node3D = PedBody.build(PedBody.guard_look())
	var before: int = (_baked(b, "Head").mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	PedBody.uniform(b, PedBody.UNIFORM_SECURITY)
	assert_true((_baked(b, "Head").mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() > before, "a cap on the head")
	var chest: PackedColorArray = _baked(b, "Chest").mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var navy: int = 0
	var yellow: int = 0
	for c: Color in chest:
		var s: Color = c.linear_to_srgb()
		if s.b > s.r * 1.3 and s.b > 0.3:
			navy += 1
		if s.r > 0.8 and s.g > 0.7 and s.b < 0.4:
			yellow += 1
	assert_true(navy > 50, "navy shirt (%d)" % navy)
	assert_true(yellow > 0, "yellow badge (%d)" % yellow)
	assert_true(_surfaces(b) <= 16, "still within the surface budget")
	b.free()


func _tree_root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


## The crowd frees its look templates and everything under them: no orphan nodes left behind.
func test_crowd_leaves_no_orphans() -> void:
	var before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var crowd := Pedestrians.new()
	crowd.look_pool = 2
	crowd.add_group(Vector3.ZERO, 3)
	crowd.build_now()
	assert_true(crowd.is_loaded(), "everyone dressed")
	_tree_root().add_child(crowd)
	_tree_root().remove_child(crowd)
	crowd.free()
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), before, "orphan nodes after the crowd is gone")


func test_person_with_a_look_override_gets_a_private_template() -> void:
	var crowd := Pedestrians.new()
	crowd.look_pool = 2
	var people: Array[Pedestrian] = crowd.add_group(Vector3.ZERO, 3)
	people[1].look_override = PedBody.guard_look()
	people[1].uniform = PedBody.UNIFORM_SECURITY
	crowd.build_now()
	assert_true(crowd.is_loaded(), "everyone dressed")
	assert_true(_baked(people[1].body, "Head").mesh.get_aabb().size.y > 0.0)
	var head_verts: int = (_baked(people[1].body, "Head").mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	var other: int = (_baked(people[0].body, "Head").mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert_true(head_verts != other, "the guard has his own head (cap)")
	crowd.free()


## No camera (bots, sims): distance is measured from the skater. Far people are hidden, not posed and cast no shadow;
## near people are shown, posed and cast shadows.
func test_crowd_lod_follows_the_skater_when_there_is_no_camera() -> void:
	var crowd := Pedestrians.new()
	crowd.look_pool = 1
	crowd.add_idler(Vector3(0.0, 0.0, 5.0), 0.0)
	crowd.add_idler(Vector3(0.0, 0.0, 90.0), 0.0)
	crowd.add_idler(Vector3(0.0, 0.0, 30.0), 0.0)
	crowd.build_now()
	var skater := Node3D.new()
	skater.add_to_group("skater")
	_tree_root().add_child(skater)
	_tree_root().add_child(crowd)
	for i: int in 8:
		crowd._process(0.016)
	var near: Pedestrian = crowd.people[0]
	var far: Pedestrian = crowd.people[1]
	var mid: Pedestrian = crowd.people[2]
	assert_true(near.visible and near.posed, "near person shown and posed")
	assert_false(far.visible, "person at 90 m hidden")
	assert_false(far.posed, "hidden person never posed")
	assert_true(mid.visible, "30 m is inside the 50 m range")
	var casting: int = 0
	var casting_mid: int = 0
	for n: Node in near.find_children("*", "GeometryInstance3D", true, false):
		if (n as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casting += 1
	for n: Node in mid.find_children("*", "GeometryInstance3D", true, false):
		if (n as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casting_mid += 1
	assert_true(casting > 5, "near person casts shadows (%d meshes)" % casting)
	assert_eq(casting_mid, 0, "person beyond the shadow range casts none")
	# walking toward the far person brings them back
	skater.position = Vector3(0.0, 0.0, 80.0)
	for i: int in 8:
		crowd._process(0.016)
	assert_true(far.visible and far.posed, "person comes back into range")
	_tree_root().remove_child(crowd)
	_tree_root().remove_child(skater)
	crowd.free()
	skater.free()


func test_traffic_cars_have_a_view_range() -> void:
	var t := Traffic.new()
	var lane: int = t.add_lane(LanePath.block_loop(Rect2(0.0, 0.0, 40.0, 30.0), 0.0, 6.0, true), 10.0)
	var cars: Array[TrafficCar] = t.add_cars(lane, 2)
	var meshes: int = 0
	for n: Node in cars[0].find_children("*", "GeometryInstance3D", true, false):
		meshes += 1
		assert_near((n as GeometryInstance3D).visibility_range_end, Traffic.new().view_range, 0.001, "cars are culled past view_range")
	assert_true(meshes > 0, "car has meshes")
	# a car out of range keeps driving but skips the visual motion
	var car: TrafficCar = cars[0]
	var path: LanePath = t.lanes[lane]
	var s0: float = car.s
	var rot0: Vector3 = car.model.rotation
	car.speed = 8.0
	car.drive(path, 8.0, 0.1, 5.0, 2.4, false)
	assert_true(car.s != s0, "still drives out of range")
	assert_eq(car.model.rotation, rot0, "no visual lean out of range")
	t.free()
