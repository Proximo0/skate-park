extends TestCase
## StairSet park piece with the default parameters: width 5, platform_depth 4, 6 steps of 0.25 rise and 0.45 run.


func _stairs_test_build() -> Node3D:
	return StairSet.build()


func _stairs_test_child(root: Node, child_name: String) -> Node:
	for c: Node in root.get_children():
		if c.name == child_name:
			return c
	return null


func _stairs_test_rails(root: Node, kind: String) -> Array:
	var out: Array = []
	for c: Node in root.get_children():
		if c is GrindRail and (c as GrindRail).kind == kind:
			out.append(c)
	return out


func test_handrail_is_one_three_point_polyline_kinked_at_top_step() -> void:
	var root: Node3D = _stairs_test_build()
	var handrails: Array = _stairs_test_rails(root, "rail")
	assert_eq(handrails.size(), 1, "one handrail polyline")
	if handrails.size() != 1:
		return
	var rail: GrindRail = handrails[0]
	assert_eq(rail.points.size(), 3, "handrail has 3 points")
	if rail.points.size() != 3:
		return
	var mid: Vector3 = rail.points[1]
	assert_near(mid.z, 4.0, 0.0001, "middle point at the platform front (top step)")
	assert_near(mid.y, 6.0 * 0.25 + 0.9, 0.0001, "middle point 0.9 m above the top step")
	assert_true(rail.points[0].z < mid.z, "flat segment starts back on the platform")
	assert_true(rail.points[2].z > 4.0 + 6.0 * 0.45, "sloped segment runs past the last step")
	assert_true(rail.points[2].y < mid.y, "sloped segment descends")
	root.free()


func test_ledge_rail_exists() -> void:
	var root: Node3D = _stairs_test_build()
	assert_eq(_stairs_test_rails(root, "ledge").size(), 1, "one ledge rail")
	root.free()


func test_slope_collision_exists_as_hidden_wedge() -> void:
	var root: Node3D = _stairs_test_build()
	var body: Node = _stairs_test_child(root, "SlopeCollision")
	assert_true(body is StaticBody3D, "slope collision body exists")
	if not body is StaticBody3D:
		return
	var cs: CollisionShape3D = null
	for c: Node in body.get_children():
		if c is CollisionShape3D:
			cs = c
	assert_true(cs != null and cs.shape is ConvexPolygonShape3D, "slope is a convex wedge")
	if cs == null or not cs.shape is ConvexPolygonShape3D:
		return
	var pts: PackedVector3Array = (cs.shape as ConvexPolygonShape3D).points
	var has_top: bool = false
	var has_bottom: bool = false
	for p: Vector3 in pts:
		if absf(p.y - 1.5) < 0.0001 and absf(p.z - 4.0) < 0.0001:
			has_top = true
		if absf(p.y) < 0.0001 and absf(p.z - 4.0 - 6.0 * 0.45) < 0.0001:
			has_bottom = true
	assert_true(has_top, "wedge top edge at the platform front")
	assert_true(has_bottom, "wedge bottom edge at the ground past the last step")
	root.free()


func test_step_meshes_have_no_collision() -> void:
	var root: Node3D = _stairs_test_build()
	var steps: Node = _stairs_test_child(root, "Steps")
	assert_true(steps != null, "steps node exists")
	if steps == null:
		return
	assert_true(steps.get_child_count() >= 5, "step visuals exist")
	for s: Node in steps.get_children():
		assert_true(s is MeshInstance3D, "step %s is a plain mesh" % s.name)
		assert_eq(s.get_child_count(), 0, "step %s has no collision children" % s.name)
	root.free()


func test_gap_zones_present() -> void:
	var root: Node3D = _stairs_test_build()
	var ids: PackedStringArray = []
	for c: Node in root.get_children():
		if c is Area3D and c.has_meta("zone_id"):
			ids.append(str(c.get_meta("zone_id")))
	assert_true(ids.has("stair_top"), "top zone")
	assert_true(ids.has("stair_bottom"), "bottom zone")
	root.free()
