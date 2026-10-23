extends TestCase


func _rails(root: Node) -> Array:
	var out: Array = []
	for n: Node in root.find_children("*", "GrindRail", true, false):
		out.append(n)
	return out


func _zones(root: Node) -> Dictionary:
	var out: Dictionary = {}
	for n: Node in root.find_children("*", "Area3D", true, false):
		if n.has_meta("zone_id"):
			out[n.get_meta("zone_id")] = n
	return out


## Min and max corners over every triangle of every mesh under the piece.
func _bounds(root: Node) -> Array[Vector3]:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var p: Node = n
		while p != root and p != null:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		var faces: PackedVector3Array = (n as MeshInstance3D).mesh.get_faces()
		for v: Vector3 in faces:
			lo = lo.min(t * v)
			hi = hi.max(t * v)
	var out: Array[Vector3] = [lo, hi]
	return out


## World box of a gap zone (its collision box; the Area3D itself sits at the origin of its piece).
func _zone_box(area: Area3D) -> AABB:
	var cs: CollisionShape3D = area.get_child(0) as CollisionShape3D
	var size: Vector3 = (cs.shape as BoxShape3D).size
	return AABB(cs.position - size * 0.5, size)


func _is_corner(p: Vector3, size: float) -> bool:
	var xs: bool = absf(p.x) < 0.0001 or absf(p.x - size) < 0.0001
	var zs: bool = absf(p.z) < 0.0001 or absf(p.z - size) < 0.0001
	return xs and zs and absf(p.y) < 0.0001


func _rail_named(root: Node, rail_name: String) -> GrindRail:
	return root.find_child(rail_name, true, false) as GrindRail


func test_pyramid_ledge_rails() -> void:
	var root: Node3D = Transfers.pyramid()
	var top: GrindRail = _rail_named(root, "TopEdge")
	assert_true(top != null, "top edge rail exists")
	if top != null:
		assert_eq(top.kind, "ledge", "top edge is a ledge")
		assert_eq(top.points.size(), 5, "closed polyline of 4 corners plus repeat")
		assert_true(top.points[0].is_equal_approx(top.points[4]), "polyline is closed")
		for p: Vector3 in top.points:
			assert_near(p.y, 1.4, 0.0001, "top edge sits on the top height")
	var hips: Array = []
	for k: int in 4:
		var h: GrindRail = _rail_named(root, "Hip%d" % k)
		if h != null:
			hips.append(h)
	assert_eq(hips.size(), 4, "four hip edges")
	for h: GrindRail in hips:
		assert_eq(h.kind, "ledge", "hip edge is a ledge")
		assert_eq(h.points.size(), 2, "hip edge is one straight line")
		assert_near(h.points[0].y, 1.4, 0.0001, "hip edge starts at the top")
		assert_near(h.points[1].y, 0.0, 0.0001, "hip edge ends at the ground")
		assert_true(_is_corner(h.points[1], 9.0), "hip edge ends on a base corner")
	assert_eq(_rails(root).size(), 5, "pyramid has exactly 5 rails")


func test_pyramid_zones() -> void:
	var root: Node3D = Transfers.pyramid(9.0, 3.0, 1.4, "pyramid")
	var zones: Dictionary = _zones(root)
	assert_true(zones.has("pyramid_n"), "pyramid_n zone")
	assert_true(zones.has("pyramid_s"), "pyramid_s zone")
	assert_eq(zones.size(), 2, "exactly two zones")
	var zn: AABB = _zone_box(zones.get("pyramid_n") as Area3D)
	var zs: AABB = _zone_box(zones.get("pyramid_s") as Area3D)
	assert_near(zn.position.x, 0.0, 0.0001, "n zone starts at the footprint x min")
	assert_near(zn.position.y, 0.0, 0.0001, "n zone starts at the ground")
	assert_near(zn.position.z, -1.5, 0.0001, "n zone sits beyond the -Z bank")
	assert_near(zn.size.x, 9.0, 0.0001, "zone spans the full width")
	assert_near(zn.size.y, 3.0, 0.0001, "zone is 3 m tall")
	assert_near(zn.size.z, 1.5, 0.0001, "zone is 1.5 m deep")
	assert_near(zs.position.z, 9.0, 0.0001, "s zone sits beyond the +Z bank")


func test_pyramid_footprint() -> void:
	var root: Node3D = Transfers.pyramid(9.0, 3.0, 1.4, "pyramid")
	var b: Array[Vector3] = _bounds(root)
	assert_near(b[0].x, 0.0, 0.0001, "min x")
	assert_near(b[1].x, 9.0, 0.0001, "max x")
	assert_near(b[0].z, 0.0, 0.0001, "min z")
	assert_near(b[1].z, 9.0, 0.0001, "max z")
	assert_near(b[0].y, 0.0, 0.0001, "on the ground")
	assert_near(b[1].y, 1.4, 0.0001, "top at height")


func test_pyramid_faces_point_outward() -> void:
	# Godot shows the side a clockwise-wound triangle faces, so the visible side is -cross of the stored order.
	var root: Node3D = Transfers.pyramid()
	var centre := Vector3(4.5, 0.7, 4.5)
	var mi: MeshInstance3D = root.find_child("Mesh", true, false) as MeshInstance3D
	var faces: PackedVector3Array = mi.mesh.get_faces()
	var bad: int = 0
	for i: int in range(0, faces.size(), 3):
		var n: Vector3 = -(faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])
		var c: Vector3 = (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
		if n.dot(c - centre) < -0.0001:
			bad += 1
	assert_eq(bad, 0, "no pyramid triangle faces inward")
	var stored: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var bad_normals: int = 0
	for i: int in range(0, faces.size(), 3):
		var c: Vector3 = (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
		if stored[i].dot(c - centre) < -0.0001:
			bad_normals += 1
	assert_eq(bad_normals, 0, "stored normals point outward")


func test_spine_coping_and_footprint() -> void:
	var root: Node3D = Transfers.spine(8.0, 2.2, 2.4)
	var rails: Array = _rails(root)
	assert_eq(rails.size(), 1, "spine has one coping rail")
	if rails.size() == 1:
		var r: GrindRail = rails[0]
		assert_eq(r.kind, "coping", "coping kind")
		assert_eq(r.points.size(), 2, "straight coping")
		assert_near(r.points[0].y, 2.4, 0.0001, "coping at height")
		var reach: float = Transfers.spine_reach(2.2, 2.4)
		assert_near(r.points[0].z, reach + 0.1, 0.0001, "coping on the shared centre line")
		assert_near(r.points[0].x, 0.0, 0.0001, "coping starts at x 0")
		assert_near(r.points[1].x, 8.0, 0.0001, "coping ends at length")
	var b: Array[Vector3] = _bounds(root)
	assert_near(b[0].x, 0.0, 0.0001, "spine min x")
	assert_near(b[1].x, 8.0, 0.0001, "spine max x")
	assert_near(b[0].z, 0.0, 0.0001, "spine min z")
	assert_near(b[1].z, 2.0 * Transfers.spine_reach(2.2, 2.4) + 0.2, 0.0001, "spine max z is two faces and the fin")
	assert_near(b[1].y, 2.45, 0.0001, "spine top at height plus the 0.05 coping pipe radius")


## The faces end below the skater's vert threshold (normal.y 0.35), so a launch off the fin is a transfer, not a
## straight-up vert air; but still steep (a real spine), and they rise monotonically to the coping height.
func test_spine_faces_end_below_vert_but_steep() -> void:
	var tune_ny: float = 0.35
	var reach: float = Transfers.spine_reach(2.2, 2.4)
	var dy: float = Transfers.spine_face(reach, 2.2, 2.4) - Transfers.spine_face(reach - 0.1, 2.2, 2.4)
	var end_slope_deg: float = rad_to_deg(atan2(dy, 0.1))
	assert_true(cos(deg_to_rad(end_slope_deg)) > tune_ny, "the fin end is below the vert threshold, got %.1f deg" % end_slope_deg)
	assert_true(end_slope_deg > 55.0, "but still steep, got %.1f deg" % end_slope_deg)
	assert_near(Transfers.spine_face(reach, 2.2, 2.4), 2.4, 0.0001, "face reaches the coping height")
	assert_near(Transfers.spine_face(0.0, 2.2, 2.4), 0.0, 0.0001, "face starts on the ground")
	var prev: float = -1.0
	for i: int in 41:
		var h: float = Transfers.spine_face(reach * float(i) / 40.0, 2.2, 2.4)
		assert_true(h >= prev - 0.00001, "face never dips")
		prev = h
	# a short spine (lower than the arc) still ends at the coping height
	assert_near(Transfers.spine_face(Transfers.spine_reach(2.2, 1.0), 2.2, 1.0), 1.0, 0.0001, "low spine reaches its height")


func test_hip_rails_and_footprint() -> void:
	var root: Node3D = Transfers.hip(8.0, 2.5, 2.8, "hip")
	var rails: Array = _rails(root)
	assert_eq(rails.size(), 1, "hip has one coping polyline")
	if rails.size() == 1:
		var r: GrindRail = rails[0]
		assert_eq(r.kind, "coping", "coping kind")
		assert_eq(r.points.size(), 3, "two lips meeting at the corner")
		assert_true(r.points[1].is_equal_approx(Vector3(2.5, 2.8, 2.5)), "lips meet at the corner")
		assert_near(r.points[0].x, 8.0, 0.0001, "X lip runs to the far end")
		assert_near(r.points[2].z, 8.0, 0.0001, "Z lip runs to the far end")
	var b: Array[Vector3] = _bounds(root)
	assert_near(b[0].x, 0.0, 0.0001, "hip min x")
	assert_near(b[1].x, 8.0, 0.0001, "hip max x")
	assert_near(b[0].z, 0.0, 0.0001, "hip min z")
	assert_near(b[1].z, 8.0, 0.0001, "hip max z")
	assert_near(b[0].y, 0.0, 0.0001, "hip on the ground")
	assert_near(b[1].y, 2.85, 0.0001, "hip top at height plus the 0.05 coping pipe radius")


func test_hip_zones() -> void:
	var root: Node3D = Transfers.hip(8.0, 2.5, 2.8, "hip")
	var zones: Dictionary = _zones(root)
	assert_eq(zones.size(), 2, "two hip zones")
	assert_true(zones.has("hip_n"), "hip_n zone")
	assert_true(zones.has("hip_s"), "hip_s zone")
	var zn: Area3D = zones.get("hip_n") as Area3D
	var zs: Area3D = zones.get("hip_s") as Area3D
	if zn != null and zs != null:
		var an: AABB = _zone_box(zn)
		var as_: AABB = _zone_box(zs)
		assert_false(an.intersects(as_), "hip zones do not overlap")
		assert_true(an.position.x >= 2.5 and an.end.x <= 8.0001, "hip_n lies over the X lip")
		assert_true(as_.position.z >= 2.5 and as_.end.z <= 8.0001, "hip_s lies over the Z lip")
		assert_true(an.position.y >= 2.8 - 0.0001, "hip zones start at deck height")


func test_piece_names() -> void:
	assert_eq(String(Transfers.pyramid().name), "Pyramid", "pyramid root name")
	assert_eq(String(Transfers.spine().name), "Spine", "spine root name")
	assert_eq(String(Transfers.hip().name), "Hip", "hip root name")
	var zones: Dictionary = _zones(Transfers.pyramid(9.0, 3.0, 1.4, "bank"))
	assert_true(zones.has("bank_n") and zones.has("bank_s"), "custom zone prefix for pyramid")
