extends TestCase

const R := 4.0
const RUN_IN := 6.0
const RUN_OUT := 6.0
const OFFSET := 3.5
const WIDTH := 3.0


func _all(node: Node) -> Array:
	var out: Array = [node]
	for c: Node in node.get_children():
		out.append_array(_all(c))
	return out


func _track(root: Node) -> StaticBody3D:
	return root.find_child("Track", true, false) as StaticBody3D


## Vertex and normal arrays of the track's collision mesh (the body's only MeshInstance3D).
func _track_arrays(root: Node) -> Array:
	var body: StaticBody3D = _track(root)
	var mi: MeshInstance3D = body.find_child("Mesh", false, false) as MeshInstance3D
	var arrays: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	return arrays


func _zone(root: Node, zone_id: String) -> Area3D:
	for n: Node in _all(root):
		if n is Area3D and n.has_meta("zone_id") and str(n.get_meta("zone_id")) == zone_id:
			return n as Area3D
	return null


func test_highest_track_vertex_is_two_radii() -> void:
	var root: Node3D = LoopTrack.build(R, WIDTH, RUN_IN, RUN_OUT, OFFSET)
	var arrays: Array = _track_arrays(root)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var top: float = -INF
	for i: int in verts.size():
		# riding face normals point down over the top; the slab's back (normal up) and the side and end faces of the
		# closed section (horizontal normals, running out to the slab's back) are skipped
		if normals[i].y < -0.5:
			top = maxf(top, verts[i].y)
	assert_near(top, 2.0 * R, 0.05, "highest track vertex at 2R (plus the 0.02 lift)")
	root.free()


func test_lowest_point_is_the_flat_height() -> void:
	var root: Node3D = LoopTrack.build(R, WIDTH, RUN_IN, RUN_OUT, OFFSET)
	var arrays: Array = _track_arrays(root)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var low: float = INF
	for i: int in verts.size():
		# the slab's underside (normal pointing down, under the ground) and the side and end faces of the closed
		# section (horizontal normals, running down to the underside) are not the riding face
		if normals[i].y > 0.5:
			low = minf(low, verts[i].y)
	assert_near(low, 0.02, 0.0001, "flat parts and loop bottom at y 0.02")
	root.free()


func test_run_in_starts_at_origin() -> void:
	var root: Node3D = LoopTrack.build(R, WIDTH, RUN_IN, RUN_OUT, OFFSET)
	var verts: PackedVector3Array = _track_arrays(root)[Mesh.ARRAY_VERTEX]
	var found: bool = false
	var max_z: float = -INF
	for v: Vector3 in verts:
		max_z = maxf(max_z, v.z)
		if v.distance_to(Vector3(0.0, 0.02, 0.0)) < 0.0001:
			found = true
	assert_true(found, "riding face corner at (0, 0.02, 0)")
	assert_near(max_z, 0.0, 0.0001, "nothing behind the run-in start")
	root.free()


func test_exit_offset_by_offset() -> void:
	var root: Node3D = LoopTrack.build(R, WIDTH, RUN_IN, RUN_OUT, OFFSET)
	var arrays: Array = _track_arrays(root)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var end_z: float = INF
	for v: Vector3 in verts:
		end_z = minf(end_z, v.z)
	assert_near(end_z, -RUN_IN - RUN_OUT, 0.0001, "run-out ends at z = -(run_in + run_out)")
	var lo_x: float = INF
	var hi_x: float = -INF
	for i: int in verts.size():
		var v: Vector3 = verts[i]
		if absf(v.z - end_z) < 0.0001 and absf(v.y - 0.02) < 0.0001 and normals[i].dot(Vector3.UP) > 0.999:
			lo_x = minf(lo_x, v.x)
			hi_x = maxf(hi_x, v.x)
	assert_near(lo_x, OFFSET, 0.0001, "run-out left edge offset by offset")
	assert_near(hi_x, OFFSET + WIDTH, 0.0001, "run-out right edge at offset + width")
	root.free()


func test_circle_center_documented_point() -> void:
	var c: Vector3 = LoopTrack.circle_center(R, RUN_IN)
	assert_near(c.y, R + 0.02, 0.0001, "centre height is radius above the lift")
	assert_near(c.z, -RUN_IN, 0.0001, "centre sits at the loop bottom's z")


func test_loop_normals_point_to_centre() -> void:
	var root: Node3D = LoopTrack.build(R, WIDTH, RUN_IN, RUN_OUT, OFFSET)
	var arrays: Array = _track_arrays(root)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var centre: Vector3 = LoopTrack.circle_center(R, RUN_IN)
	var checked: int = 0
	var bad: int = 0
	for i: int in verts.size():
		var v: Vector3 = verts[i]
		var n: Vector3 = normals[i]
		# riding-face vertices on the circle: curb sides have lateral normals, and the slab's back sits R + SLAB out
		var dist: float = Vector2(v.y - centre.y, v.z - centre.z).length()
		if absf(n.x) > 0.01 or v.y < 0.5 or dist > R + 0.02:
			continue
		var to_centre := Vector3(0.0, centre.y - v.y, centre.z - v.z)
		checked += 1
		if n.dot(to_centre) <= 0.0:
			bad += 1
	assert_true(checked > 50, "checked a good number of loop vertices (%d)" % checked)
	assert_eq(bad, 0, "every loop normal points toward the centre")
	root.free()


func test_triangles_are_front_facing_from_inside() -> void:
	var root: Node3D = LoopTrack.build(R, WIDTH, RUN_IN, RUN_OUT, OFFSET)
	var arrays: Array = _track_arrays(root)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bad: int = 0
	for i: int in range(0, verts.size(), 3):
		var a: Vector3 = verts[i]
		var b: Vector3 = verts[i + 1]
		var c: Vector3 = verts[i + 2]
		var n: Vector3 = normals[i]
		# Godot front faces are clockwise: stored order must wind opposite to the normal
		if (b - a).cross(c - a).dot(n) >= 0.0:
			bad += 1
	assert_eq(bad, 0, "no inside-out triangles")
	root.free()


func test_static_body_and_gap_zone() -> void:
	var root: Node3D = LoopTrack.build(R, WIDTH, RUN_IN, RUN_OUT, OFFSET)
	var body: StaticBody3D = _track(root)
	assert_true(body != null, "StaticBody3D track")
	if body != null:
		var cs: CollisionShape3D = null
		for c: Node in body.get_children():
			if c is CollisionShape3D:
				cs = c as CollisionShape3D
		assert_true(cs != null and cs.shape is ConcavePolygonShape3D, "trimesh collision")
	var statics: int = 0
	for n: Node in _all(root):
		if n is StaticBody3D:
			statics += 1
	assert_eq(statics, 1, "only the track collides")
	var zone: Area3D = _zone(root, "loop_full")
	assert_true(zone != null, "gap zone loop_full")
	if zone != null:
		assert_true(zone.is_in_group("gap_zone"), "zone in gap_zone group")
		assert_eq(zone.collision_mask, 2, "detects the skater")
	root.free()
