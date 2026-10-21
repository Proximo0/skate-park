extends TestCase
## Dome bowl park piece: spherical cap geometry (rim at y = 0, bottom at y = -depth), normals into the bowl,
## front-face winding, closed coping loop, footprint, gap zone and triangle budget.

const RADIUS: float = 8.0
const DEPTH_RATIO: float = 0.85
const DEPTH: float = RADIUS * DEPTH_RATIO
const MARGIN: float = 1.5
const SIZE: float = 2.0 * (RADIUS + MARGIN)
const HALF: float = RADIUS + MARGIN


func _build() -> Node3D:
	return DomeBowl.build(RADIUS, DEPTH_RATIO, 16, 48, "dome")


## Every surface of a mesh instance as [vertices, normals] pairs.
func _surfaces(root: Node3D, node_path: String) -> Array:
	var mi: MeshInstance3D = root.get_node(node_path) as MeshInstance3D
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	var out: Array = []
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		out.append([arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL]])
	return out


func _shell_vertices(root: Node3D) -> PackedVector3Array:
	var all := PackedVector3Array()
	for s: Array in _surfaces(root, "Shell/Mesh"):
		all.append_array(s[0])
	return all


func test_shell_is_static_body_with_trimesh_collision() -> void:
	var root: Node3D = _build()
	var shell: StaticBody3D = root.get_node("Shell") as StaticBody3D
	assert_true(shell != null, "riding surface is a StaticBody3D")
	var cs: CollisionShape3D = root.get_node("Shell/Collision") as CollisionShape3D
	var shape: ConcavePolygonShape3D = cs.shape as ConcavePolygonShape3D
	assert_true(shape != null, "shell uses trimesh collision")
	if shape != null:
		assert_true(shape.get_faces().size() > 0, "shell has collision faces")
		assert_true(shape.backface_collision, "shell collides from both sides")
	var deck_cs: CollisionShape3D = root.get_node("Deck/Collision") as CollisionShape3D
	assert_true(deck_cs != null and deck_cs.shape is ConcavePolygonShape3D, "deck has trimesh collision")


func test_rim_at_zero_and_bottom_at_minus_depth() -> void:
	var root: Node3D = _build()
	var v: PackedVector3Array = _shell_vertices(root)
	var lo: float = INF
	var hi: float = -INF
	for p: Vector3 in v:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	assert_near(lo, -DEPTH, 0.0001, "lowest point at -depth")
	assert_near(hi, 0.0, 0.0001, "rim at y = 0")
	# sample rim points: radius HALF-rim at y = 0 on the shell edge
	var rim_hits: int = 0
	for p: Vector3 in v:
		if absf(p.y) < 0.0001:
			rim_hits += 1
			var r: float = Vector2(p.x - HALF, p.z - HALF).length()
			assert_near(r, RADIUS, 0.0001, "rim vertex on the rim circle")
	assert_true(rim_hits > 0, "rim vertices exist")


func test_normals_point_into_the_bowl() -> void:
	var root: Node3D = _build()
	var bottom_checked: int = 0
	var rim_checked: int = 0
	for s: Array in _surfaces(root, "Shell/Mesh"):
		var v: PackedVector3Array = s[0]
		var n: PackedVector3Array = s[1]
		for i: int in v.size():
			if v[i].y < -DEPTH + 0.05:
				bottom_checked += 1
				assert_true(n[i].y > 0.99, "bottom normal points up")
			if v[i].y > -0.05:
				rim_checked += 1
				var inward: Vector3 = Vector3(HALF - v[i].x, 0.0, HALF - v[i].z).normalized()
				assert_true(n[i].dot(inward) > 0.9, "rim normal points toward the centre")
				assert_true(n[i].y < 0.35, "rim normal is mostly horizontal")
	assert_true(bottom_checked > 0, "bottom vertices exist")
	assert_true(rim_checked > 0, "rim vertices exist")


func test_triangles_front_face_into_the_bowl() -> void:
	## Godot front faces are clockwise seen from the front: the triangle's right-hand cross product points
	## away from the side it is seen from, so it must point opposite to the vertex normals.
	var root: Node3D = _build()
	var bad: int = 0
	var checked: int = 0
	for path: String in ["Shell/Mesh", "Deck/Mesh", "CopingPipe"]:
		for s: Array in _surfaces(root, path):
			var v: PackedVector3Array = s[0]
			var n: PackedVector3Array = s[1]
			for i: int in range(0, v.size(), 3):
				var cross: Vector3 = (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
				if cross.length_squared() < 1e-12:
					continue
				checked += 1
				var face_n: Vector3 = n[i] + n[i + 1] + n[i + 2]
				if cross.dot(face_n) >= 0.0:
					bad += 1
	assert_true(checked > 0, "triangles exist")
	assert_eq(bad, 0, "no inside-out triangles")


func test_coping_is_closed_loop_on_rim() -> void:
	var root: Node3D = _build()
	var coping: GrindRail = root.get_node("Coping") as GrindRail
	assert_eq(coping.kind, "coping")
	var pts: PackedVector3Array = coping.points
	assert_true(pts.size() > 8, "coping has points")
	assert_eq(pts[0], pts[pts.size() - 1], "coping repeats its first point")
	for p: Vector3 in pts:
		assert_near(p.y, 0.0, 0.0001, "coping sits at y = 0")
		assert_near(Vector2(p.x - HALF, p.z - HALF).length(), RADIUS, 0.0001, "coping on the rim circle")


func test_footprint_in_range() -> void:
	var root: Node3D = _build()
	for p: Vector3 in _shell_vertices(root):
		assert_true(p.x >= -0.0001 and p.x <= SIZE + 0.0001, "shell inside x footprint")
		assert_true(p.z >= -0.0001 and p.z <= SIZE + 0.0001, "shell inside z footprint")
	for s: Array in _surfaces(root, "Deck/Mesh"):
		for p: Vector3 in s[0]:
			assert_true(p.x >= -0.0001 and p.x <= SIZE + 0.0001, "deck inside x footprint")
			assert_true(p.z >= -0.0001 and p.z <= SIZE + 0.0001, "deck inside z footprint")
	var coping: GrindRail = root.get_node("Coping") as GrindRail
	for p: Vector3 in coping.points:
		assert_true(p.x >= 0.0 and p.x <= SIZE and p.z >= 0.0 and p.z <= SIZE, "coping inside footprint")


func test_deck_keeps_the_hole_clear() -> void:
	var root: Node3D = _build()
	var top_tris: int = 0
	for s: Array in _surfaces(root, "Deck/Mesh"):
		var v: PackedVector3Array = s[0]
		var n: PackedVector3Array = s[1]
		for i: int in range(0, v.size(), 3):
			if n[i].y > 0.99 and absf(v[i].y) < 0.0001:
				top_tris += 1
				var c: Vector3 = (v[i] + v[i + 1] + v[i + 2]) / 3.0
				assert_true(Vector2(c.x - HALF, c.z - HALF).length() >= RADIUS - 0.0001, "no deck top over the hole")
	assert_true(top_tris > 0, "deck top exists")


func test_paint_surfaces_exist() -> void:
	var root: Node3D = _build()
	var mi: MeshInstance3D = root.get_node("Shell/Mesh") as MeshInstance3D
	assert_true((mi.mesh as ArrayMesh).get_surface_count() >= 3, "concrete, tile band and target surfaces")


func test_gap_zone_above_centre() -> void:
	var root: Node3D = _build()
	var zone: Area3D = root.get_node("Zone_dome_air") as Area3D
	assert_true(zone != null, "air zone exists")
	if zone == null:
		return
	assert_eq(zone.get_meta("zone_id"), "dome_air")
	assert_true(zone.is_in_group("gap_zone"), "zone in gap_zone group")
	var cs: CollisionShape3D = zone.get_child(0) as CollisionShape3D
	var box: BoxShape3D = cs.shape as BoxShape3D
	assert_near(box.size.y, 4.0, 0.0001, "zone 4 m tall")
	assert_near(cs.position.y - box.size.y * 0.5, 0.0, 0.0001, "zone starts at the rim")
	assert_near(cs.position.x, HALF, 0.0001, "zone centred on x")
	assert_near(cs.position.z, HALF, 0.0001, "zone centred on z")


func test_triangle_budget() -> void:
	var root: Node3D = _build()
	var faces: int = 0
	for path: String in ["Shell/Mesh", "Deck/Mesh", "CopingPipe"]:
		for s: Array in _surfaces(root, path):
			faces += (s[0] as PackedVector3Array).size() / 3
	assert_true(faces < 6000, "under 6000 triangles, got %d" % faces)
