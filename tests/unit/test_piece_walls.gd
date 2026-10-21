extends TestCase


func _all(node: Node) -> Array:
	var out: Array = [node]
	for c: Node in node.get_children():
		out.append_array(_all(c))
	return out


func _rails(root: Node) -> Array[GrindRail]:
	var out: Array[GrindRail] = []
	for n: Node in _all(root):
		if n is GrindRail:
			out.append(n as GrindRail)
	return out


func _zone(root: Node, zone_id: String) -> Area3D:
	for n: Node in _all(root):
		if n is Area3D and n.has_meta("zone_id") and str(n.get_meta("zone_id")) == zone_id:
			return n as Area3D
	return null


func _gap_zone_count(root: Node) -> int:
	var count: int = 0
	for n: Node in _all(root):
		if n is Area3D and n.is_in_group("gap_zone"):
			count += 1
	return count


func _solid_bodies(root: Node) -> Array[StaticBody3D]:
	var out: Array[StaticBody3D] = []
	for n: Node in _all(root):
		if n is StaticBody3D:
			out.append(n as StaticBody3D)
	return out


func _shape_of(body: StaticBody3D) -> Shape3D:
	for c: Node in body.get_children():
		if c is CollisionShape3D:
			return (c as CollisionShape3D).shape
	return null


func _collision_shape_node(zone: Area3D) -> CollisionShape3D:
	for c: Node in zone.get_children():
		if c is CollisionShape3D:
			return c as CollisionShape3D
	return null


# wallride wall

func test_wallride_ledge_rail_on_top_front_edge() -> void:
	var root: Node3D = Walls.wallride_wall(10.0, 3.5, 0.4)
	var rails: Array[GrindRail] = _rails(root)
	assert_eq(rails.size(), 1, "one rail")
	if rails.size() == 1:
		var r: GrindRail = rails[0]
		assert_eq(r.kind, "ledge", "wallride rail is a ledge")
		assert_eq(r.points.size(), 2, "two points")
		assert_near(r.points[0].y, 3.5 + Walls.COPING_CAP_HEIGHT, 0.0001, "rail on cap top")
		assert_near(r.points[0].z, 0.4, 0.0001, "rail on front edge")
		assert_near(r.points[1].x, 10.0, 0.0001, "rail spans the length")
		assert_near(r.points[0].x, 0.0, 0.0001, "rail starts at x 0")
	root.free()


func test_wallride_zone_only_when_asked() -> void:
	var plain: Node3D = Walls.wallride_wall(10.0, 3.5, 0.4)
	assert_eq(_gap_zone_count(plain), 0, "no zone without zone_id")
	plain.free()
	var root: Node3D = Walls.wallride_wall(10.0, 3.5, 0.4, "wall_a")
	var zone: Area3D = _zone(root, "wall_a")
	assert_true(zone != null, "zone named by zone_id")
	if zone != null:
		assert_true(zone.is_in_group("gap_zone"), "zone in gap_zone group")
		assert_eq(zone.collision_mask, 2, "detects the skater layer")
		var cs: CollisionShape3D = _collision_shape_node(zone)
		assert_true(cs != null and cs.shape is BoxShape3D, "box shape")
		if cs != null and cs.shape is BoxShape3D:
			var size: Vector3 = (cs.shape as BoxShape3D).size
			assert_near(size.z, 1.2, 0.0001, "zone reaches 1.2 m out")
			assert_near(cs.position.z - size.z * 0.5, 0.4, 0.0001, "zone starts at the face")
	root.free()


func test_wallride_collision_present() -> void:
	var root: Node3D = Walls.wallride_wall()
	var bodies: Array[StaticBody3D] = _solid_bodies(root)
	assert_true(bodies.size() >= 2, "wall and cap are solid")
	for b: StaticBody3D in bodies:
		assert_true(_shape_of(b) != null, "every body has a shape")
		assert_eq(b.collision_layer, 1, "world layer")
	root.free()


# bank

func test_bank_coping_rail_on_lip() -> void:
	var root: Node3D = Walls.bank(6.0, 4.0, 1.6)
	var rails: Array[GrindRail] = _rails(root)
	assert_eq(rails.size(), 1, "one rail")
	if rails.size() == 1:
		var r: GrindRail = rails[0]
		assert_eq(r.kind, "coping", "bank rail is coping")
		assert_near(r.points[0].y, 1.6, 0.0001, "coping on top")
		assert_near(r.points[0].z, Walls.BANK_DECK, 0.0001, "coping on the lip")
		assert_near(r.points[1].x, 6.0, 0.0001, "coping spans the width")
	root.free()


func test_bank_collision_and_zone_above_lip() -> void:
	var root: Node3D = Walls.bank(6.0, 4.0, 1.6, "bank_a")
	var bodies: Array[StaticBody3D] = _solid_bodies(root)
	assert_eq(bodies.size(), 1, "one ramp body")
	if bodies.size() == 1:
		assert_true(_shape_of(bodies[0]) is ConcavePolygonShape3D, "ramp has trimesh collision")
	var zone: Area3D = _zone(root, "bank_a")
	assert_true(zone != null, "zone named by zone_id")
	if zone != null:
		var cs: CollisionShape3D = _collision_shape_node(zone)
		assert_true(cs != null and cs.shape is BoxShape3D, "zone box")
		if cs != null:
			assert_true(cs.position.y > 1.6, "zone sits above the lip")
	var plain: Node3D = Walls.bank(6.0, 4.0, 1.6)
	assert_eq(_gap_zone_count(plain), 0, "no zone without zone_id")
	plain.free()
	root.free()


func test_bank_has_no_ledge_rail() -> void:
	var root: Node3D = Walls.bank()
	for r: GrindRail in _rails(root):
		assert_false(r.kind == "ledge", "no ledge on bank")
	root.free()


# fence

func test_fence_thin_box_collision_and_transparent_panel() -> void:
	var root: Node3D = Walls.fence(10.0, 1.4)
	var bodies: Array[StaticBody3D] = _solid_bodies(root)
	assert_eq(bodies.size(), 1, "one collision body")
	if bodies.size() == 1:
		var shape: Shape3D = _shape_of(bodies[0])
		assert_true(shape is BoxShape3D, "fence collision is a box")
		if shape is BoxShape3D:
			var size: Vector3 = (shape as BoxShape3D).size
			assert_near(size.x, 10.0, 0.0001, "spans the length")
			assert_near(size.y, 1.4, 0.0001, "spans the height")
			assert_true(size.z < 0.2, "thin")
	var panel_ok: bool = false
	for n: Node in _all(root):
		if n is MeshInstance3D and (n as MeshInstance3D).material_override is StandardMaterial3D:
			var m: StandardMaterial3D = (n as MeshInstance3D).material_override as StandardMaterial3D
			panel_ok = panel_ok or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	assert_true(panel_ok, "semi-transparent panel")
	assert_eq(_rails(root).size(), 0, "fence has no grind rails")
	root.free()


# billboard

func test_billboard_collision_on_posts_only() -> void:
	var root: Node3D = Walls.billboard_sign("SKATE PARK", 6.0)
	var bodies: Array[StaticBody3D] = _solid_bodies(root)
	assert_eq(bodies.size(), 2, "two posts collide")
	for b: StaticBody3D in bodies:
		assert_true(b.name.begins_with("Post"), "only posts collide, got %s" % b.name)
	assert_eq(_rails(root).size(), 0, "sign has no grind rails")
	root.free()


func test_billboard_label_text() -> void:
	var root: Node3D = Walls.billboard_sign("HELLO", 6.0)
	var label: Label3D = null
	for n: Node in _all(root):
		if n is Label3D:
			label = n as Label3D
	assert_true(label != null, "label present")
	if label != null:
		assert_eq(label.text, "HELLO", "text set")
		assert_true(label.outline_size > 0, "outlined")
	root.free()
