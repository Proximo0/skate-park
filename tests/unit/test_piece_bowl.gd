extends TestCase
## Bowl park piece: geometry (rim at y = 0, floor at y = -depth), coping loop, collision, normals, gap zones.

const SIZE_X: float = 14.0
const SIZE_Z: float = 10.0
const DEPTH: float = 2.6
const RADIUS: float = 3.0


func _build() -> Node3D:
	return Bowl.build(SIZE_X, SIZE_Z, DEPTH, RADIUS, 2.4, 10, "bowl")


func _shell_arrays(root: Node3D, surface: int) -> Array:
	var mi: MeshInstance3D = root.get_node("Shell/Mesh") as MeshInstance3D
	return (mi.mesh as ArrayMesh).surface_get_arrays(surface)


## Point inside the rounded rectangle that is the rim outline, shrunk by `margin`.
func _in_rim(p: Vector2, margin: float) -> bool:
	var x0: float = margin
	var x1: float = SIZE_X - margin
	var z0: float = margin
	var z1: float = SIZE_Z - margin
	if p.x < x0 or p.x > x1 or p.y < z0 or p.y > z1:
		return false
	var r: float = maxf(RADIUS - margin, 0.0)
	var cx: float = clampf(p.x, x0 + r, x1 - r)
	var cz: float = clampf(p.y, z0 + r, z1 - r)
	return Vector2(p.x - cx, p.y - cz).length() <= r + 0.0001


func test_coping_is_closed_loop_at_rim() -> void:
	var root: Node3D = _build()
	var coping: GrindRail = root.get_node("Coping") as GrindRail
	assert_eq(coping.kind, "coping")
	var pts: PackedVector3Array = coping.points
	assert_true(pts.size() > 8, "coping has points")
	assert_eq(pts[0], pts[pts.size() - 1], "coping repeats its first point")
	for p: Vector3 in pts:
		assert_near(p.y, 0.0, 0.0001, "coping sits at y = 0")
		assert_true(p.x >= -0.0001 and p.x <= SIZE_X + 0.0001, "coping inside x footprint")
		assert_true(p.z >= -0.0001 and p.z <= SIZE_Z + 0.0001, "coping inside z footprint")
	var pipes: Node3D = root.get_node("CopingPipes") as Node3D
	assert_eq(pipes.get_child_count(), pts.size() - 1, "one pipe per coping segment")
	for pipe: Node in pipes.get_children():
		assert_eq(pipe.get_child_count(), 1, "pipe has only its mesh, no extra rail")


func test_floor_depth_and_rim_top() -> void:
	var root: Node3D = _build()
	var lo: float = INF
	var hi: float = -INF
	for s: int in 2:
		var arrays: Array = _shell_arrays(root, s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for p: Vector3 in v:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
	assert_near(lo, -DEPTH, 0.0001, "floor at -depth")
	assert_near(hi, 0.0, 0.0001, "rim top at y = 0")


func test_collision_exists_for_shell_and_deck() -> void:
	var root: Node3D = _build()
	for body_name: String in ["Shell", "Deck"]:
		var cs: CollisionShape3D = root.get_node(body_name + "/Collision") as CollisionShape3D
		assert_true(cs != null, body_name + " has collision")
		var shape: ConcavePolygonShape3D = cs.shape as ConcavePolygonShape3D
		assert_true(shape != null, body_name + " uses trimesh collision")
		if shape != null:
			assert_true(shape.get_faces().size() > 0, body_name + " has faces")
			assert_true(shape.backface_collision, body_name + " collides from both sides")


func test_shell_normals_face_the_air() -> void:
	var root: Node3D = _build()
	var centre := Vector3(SIZE_X * 0.5, 0.0, SIZE_Z * 0.5)
	var arrays: Array = _shell_arrays(root, 0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var floor_checked: int = 0
	var wall_checked: int = 0
	for i: int in v.size():
		if v[i].y < -DEPTH + 0.001:
			floor_checked += 1
			assert_true(n[i].y > 0.9, "floor normal points up")
		elif absf(v[i].y + 0.2) < 0.001:
			wall_checked += 1
			var inward: Vector3 = Vector3(centre.x - v[i].x, 0.0, centre.z - v[i].z).normalized()
			assert_true(n[i].dot(inward) > 0.0, "wall normal points into the bowl")
	assert_true(floor_checked > 0, "floor vertices exist")
	assert_true(wall_checked > 0, "wall vertices exist")


func test_band_surface_exists() -> void:
	var root: Node3D = _build()
	var mi: MeshInstance3D = root.get_node("Shell/Mesh") as MeshInstance3D
	assert_eq((mi.mesh as ArrayMesh).get_surface_count(), 2, "concrete and tile band surfaces")


func test_deck_covers_footprint_outside_hole() -> void:
	var root: Node3D = _build()
	var mi: MeshInstance3D = root.get_node("Deck/Mesh") as MeshInstance3D
	var arrays: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var top_tris: int = 0
	var bad: int = 0
	for i: int in range(0, v.size(), 3):
		if absf(v[i].y) < 0.0001 and absf(v[i + 1].y) < 0.0001 and absf(v[i + 2].y) < 0.0001:
			top_tris += 1
			var c: Vector3 = (v[i] + v[i + 1] + v[i + 2]) / 3.0
			if _in_rim(Vector2(c.x, c.z), 0.05):
				bad += 1
	assert_true(top_tris > 0, "deck top exists")
	assert_eq(bad, 0, "no deck top over the hole")


func test_gap_zones_match_gaps_json() -> void:
	var root: Node3D = _build()
	var n_zone: Area3D = root.get_node("Zone_bowl_rim_n") as Area3D
	var s_zone: Area3D = root.get_node("Zone_bowl_rim_s") as Area3D
	assert_true(n_zone != null and s_zone != null, "both rim zones exist")
	if n_zone == null or s_zone == null:
		return
	assert_eq(n_zone.get_meta("zone_id"), "bowl_rim_n")
	assert_eq(s_zone.get_meta("zone_id"), "bowl_rim_s")
	assert_true(n_zone.is_in_group("gap_zone") and s_zone.is_in_group("gap_zone"), "zones in gap_zone group")
	var cs_n: CollisionShape3D = n_zone.get_child(0) as CollisionShape3D
	var cs_s: CollisionShape3D = s_zone.get_child(0) as CollisionShape3D
	var box_n: BoxShape3D = cs_n.shape as BoxShape3D
	var box_s: BoxShape3D = cs_s.shape as BoxShape3D
	assert_near(cs_n.position.z, 0.0, 0.8, "n zone centred on the -Z rim")
	assert_near(cs_s.position.z, SIZE_Z, 0.8, "s zone centred on the +Z rim")
	assert_near(box_n.size.y, 3.0, 0.0001, "zone reaches 3 m above the rim")
	assert_near(cs_n.position.y - box_n.size.y * 0.5, 0.0, 0.0001, "zone starts at the rim")
	assert_near(box_s.size.x, 1.5, 0.0001, "zone is 1.5 m wide")
