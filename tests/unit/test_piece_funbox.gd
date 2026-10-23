extends TestCase
## FunBox park piece: footprint, rails and gap zones, built with default and custom dimensions.


func _funbox_test_collect_aabbs(node: Node3D, parent_t: Transform3D, out: Array) -> void:
	var nt: Transform3D = parent_t * node.transform
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		out.append(nt * mi.mesh.get_aabb())
	for c: Node in node.get_children():
		if c is Node3D:
			_funbox_test_collect_aabbs(c as Node3D, nt, out)


func _funbox_test_bounds(root: Node3D) -> AABB:
	var boxes: Array = []
	_funbox_test_collect_aabbs(root, Transform3D.IDENTITY, boxes)
	var all: AABB = boxes[0]
	for i: int in range(1, boxes.size()):
		all = all.merge(boxes[i])
	return all


func _funbox_test_rails(node: Node3D, parent_t: Transform3D, out: Array) -> void:
	var nt: Transform3D = parent_t * node.transform
	if node is GrindRail:
		var gr: GrindRail = node as GrindRail
		var pts := PackedVector3Array()
		for p: Vector3 in gr.points:
			pts.append(nt * p)
		out.append({"kind": gr.kind, "points": pts})
	for c: Node in node.get_children():
		if c is Node3D:
			_funbox_test_rails(c as Node3D, nt, out)


func _funbox_test_rails_of(root: Node3D) -> Array:
	var out: Array = []
	_funbox_test_rails(root, Transform3D.IDENTITY, out)
	return out


func _funbox_test_zones(root: Node3D) -> Dictionary:
	# zone_id -> Vector3 centre of the zone's collision box (root-local)
	var out: Dictionary = {}
	for c: Node in root.get_children():
		if c is Area3D and c.has_meta("zone_id"):
			var cs: CollisionShape3D = c.get_child(0) as CollisionShape3D
			out[c.get_meta("zone_id")] = cs.position
	return out


func test_root_is_named_node3d() -> void:
	var root: Node3D = FunBox.build()
	assert_eq(String(root.name), "FunBox")
	root.free()


func test_default_footprint() -> void:
	var root: Node3D = FunBox.build()
	var b: AABB = _funbox_test_bounds(root)
	assert_near(b.position.x, 0.0, 0.0001, "min x")
	assert_near(b.end.x, 4.0, 0.0001, "max x = width")
	assert_near(b.position.z, 0.0, 0.0001, "min z")
	assert_near(b.end.z, 11.0, 0.0001, "max z = top + 2 * bank")
	assert_near(b.position.y, 0.0, 0.0001, "sits on the ground")
	assert_true(b.end.y >= 1.0 and b.end.y < 2.0, "top at height, rail a little above")
	root.free()


func test_custom_footprint() -> void:
	var root: Node3D = FunBox.build(6.0, 2.0, 1.5, 0.8, "gate")
	var b: AABB = _funbox_test_bounds(root)
	assert_near(b.end.x, 6.0, 0.0001, "custom width")
	assert_near(b.end.z, 5.0, 0.0001, "custom top 2 + 2 * bank 1.5")
	root.free()


func test_ledges_on_both_long_top_edges() -> void:
	var root: Node3D = FunBox.build()
	var ledges: Array = []
	for r: Dictionary in _funbox_test_rails_of(root):
		if r["kind"] == "ledge":
			ledges.append(r["points"])
	assert_eq(ledges.size(), 2, "two ledges")
	var xs: PackedFloat32Array = []
	for pts: PackedVector3Array in ledges:
		assert_eq(pts.size(), 2, "ledge has two points")
		if pts.size() != 2:
			continue
		xs.append(pts[0].x)
		assert_eq(pts[0].x, pts[1].x, "ledge runs along z")
		assert_near(pts[0].y, 1.0, 0.0001, "ledge at height")
		assert_near(pts[1].y, 1.0, 0.0001, "ledge at height")
		assert_near(pts[0].z, 3.0, 0.0001, "ledge starts at top start")
		assert_near(pts[1].z, 8.0, 0.0001, "ledge ends at top end")
	xs.sort()
	if xs.size() == 2:
		assert_near(xs[0], 0.0, 0.0001, "left ledge on x = 0")
		assert_near(xs[1], 4.0, 0.0001, "right ledge on x = width")
	root.free()


func test_mid_rail_on_posts() -> void:
	var root: Node3D = FunBox.build()
	var rails: Array = []
	for r: Dictionary in _funbox_test_rails_of(root):
		if r["kind"] == "rail":
			rails.append(r["points"])
	assert_eq(rails.size(), 1, "one mid rail")
	if rails.size() == 1:
		var pts: PackedVector3Array = rails[0]
		assert_eq(pts.size(), 2)
		if pts.size() == 2:
			assert_near(pts[0].x, 2.0, 0.0001, "down the middle")
			assert_near(pts[0].y, 1.45, 0.0001, "height + 0.45")
			assert_near(pts[1].y, 1.45, 0.0001, "flat rail")
			assert_near(pts[0].z, 3.4, 0.0001, "starts inside the top")
			assert_near(pts[1].z, 7.6, 0.0001, "ends inside the top")
	var posts: int = 0
	for c: Node in root.get_children():
		if c is StaticBody3D and c.name.begins_with("Post"):
			posts += 1
	assert_eq(posts, 2, "two posts")
	root.free()


func test_gap_zones_named_and_placed() -> void:
	var root: Node3D = FunBox.build()
	var zones: Dictionary = _funbox_test_zones(root)
	assert_eq(zones.size(), 2, "two zones")
	assert_true(zones.has("funbox_a"), "zone a named")
	assert_true(zones.has("funbox_b"), "zone b named")
	if zones.has("funbox_a") and zones.has("funbox_b"):
		var a: Vector3 = zones["funbox_a"]
		var b: Vector3 = zones["funbox_b"]
		assert_true(a.z < 5.5, "zone a over the first bank")
		assert_true(b.z > 5.5, "zone b over the second bank")
	root.free()


func test_zone_prefix_applies() -> void:
	var root: Node3D = FunBox.build(4.0, 5.0, 3.0, 1.0, "gate")
	var zones: Dictionary = _funbox_test_zones(root)
	assert_true(zones.has("gate_a"), "prefix a")
	assert_true(zones.has("gate_b"), "prefix b")
	assert_false(zones.has("funbox_a"), "no default prefix")
	root.free()
