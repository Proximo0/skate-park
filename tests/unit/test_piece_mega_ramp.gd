extends TestCase


func _all(node: Node) -> Array:
	var out: Array = [node]
	for c: Node in node.get_children():
		out.append_array(_all(c))
	return out


func _find(root: Node, node_name: String) -> Node:
	for n: Node in _all(root):
		if n.name == node_name:
			return n
	return null


## World AABB of a body that sits directly under root (root is at identity).
func _bounds(body: Node3D) -> AABB:
	for c: Node in body.get_children():
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c as MeshInstance3D
			return (body.transform * mi.transform) * mi.mesh.get_aabb()
	return AABB()


func _solid_bodies(root: Node) -> Array[StaticBody3D]:
	var out: Array[StaticBody3D] = []
	for n: Node in _all(root):
		if n is StaticBody3D:
			out.append(n as StaticBody3D)
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


func test_start_deck_top_at_start_height() -> void:
	var root: Node3D = MegaRamp.build(8.0, 18.0, 14.0, 8.0)
	var tower: StaticBody3D = _find(root, "RollIn") as StaticBody3D
	assert_true(tower != null, "roll-in tower body exists")
	if tower != null:
		var b: AABB = _bounds(tower)
		assert_near(b.end.y, 18.0, 0.0001, "deck top at start_height")
		assert_near(b.position.z, 0.0, 0.0001, "tower starts at z 0")
		assert_near(b.position.y, 0.0, 0.0001, "tower filled to the ground")
	root.free()


func test_drop_in_faces_plus_z_on_deck() -> void:
	var t: Transform3D = MegaRamp.drop_in_transform(8.0, 18.0)
	var forward: Vector3 = -t.basis.z
	assert_near(forward.x, 0.0, 0.0001, "facing x")
	assert_near(forward.y, 0.0, 0.0001, "facing y")
	assert_near(forward.z, 1.0, 0.0001, "facing +Z")
	assert_near(t.origin.y, 18.0, 0.0001, "sits on the deck")
	assert_true(t.origin.z > 0.0 and t.origin.z < MegaRamp.DECK_LEN, "on the deck, a bit back from the edge")
	assert_true(t.origin.x > 0.0 and t.origin.x < 8.0, "inside the width")


func test_gap_is_open_air() -> void:
	var root: Node3D = MegaRamp.build(8.0, 18.0, 14.0, 8.0)
	var kicker: StaticBody3D = _find(root, "Kicker") as StaticBody3D
	var landing: StaticBody3D = _find(root, "Landing") as StaticBody3D
	assert_true(kicker != null and landing != null, "kicker and landing bodies exist")
	if kicker != null and landing != null:
		var kicker_end: float = _bounds(kicker).end.z
		var landing_start: float = _bounds(landing).position.z
		assert_near(landing_start - kicker_end, 14.0, 0.01, "open air is exactly gap")
		for b: StaticBody3D in _solid_bodies(root):
			var bb: AABB = _bounds(b)
			if bb.end.y <= 0.5:
				continue
			var in_gap: bool = bb.end.z > kicker_end + 0.001 and bb.position.z < landing_start - 0.001
			assert_false(in_gap, "no solid above y 0.5 in the gap (%s)" % b.name)
	root.free()


func test_quarter_pipe_top_at_qp_height() -> void:
	var root: Node3D = MegaRamp.build(8.0, 18.0, 14.0, 8.0)
	var qp: StaticBody3D = _find(root, "QuarterPipe") as StaticBody3D
	assert_true(qp != null, "quarter pipe body exists")
	if qp != null:
		assert_near(_bounds(qp).end.y, 8.0, 0.0001, "top at qp_height")
	root.free()


func test_coping_rail_on_qp_lip() -> void:
	var root: Node3D = MegaRamp.build(8.0, 18.0, 14.0, 8.0)
	var coping: GrindRail = null
	for r: GrindRail in _rails(root):
		if r.kind == "coping":
			coping = r
	assert_true(coping != null, "coping rail exists")
	if coping != null:
		assert_near(coping.points[0].y, 8.0, 0.0001, "coping at qp_height")
		assert_near(coping.points[1].x, 8.0, 0.0001, "coping spans the width")
		var qp: StaticBody3D = _find(root, "QuarterPipe") as StaticBody3D
		assert_near(coping.points[0].z, _bounds(qp).end.z - MegaRamp.QP_DECK, 0.01, "coping on the lip, deck behind")
	root.free()


func test_gap_zones_exist() -> void:
	var root: Node3D = MegaRamp.build(8.0, 18.0, 14.0, 8.0)
	var gap: Area3D = _zone(root, "mega_gap")
	var air: Area3D = _zone(root, "mega_qp_air")
	assert_true(gap != null and gap.is_in_group("gap_zone"), "mega_gap zone in group")
	assert_true(air != null and air.is_in_group("gap_zone"), "mega_qp_air zone in group")
	if gap != null and air != null:
		var kicker: StaticBody3D = _find(root, "Kicker") as StaticBody3D
		var cs: CollisionShape3D = gap.get_child(0) as CollisionShape3D
		var size: Vector3 = (cs.shape as BoxShape3D).size
		assert_near(cs.position.z - size.z * 0.5, _bounds(kicker).end.z, 0.01, "mega_gap starts at the lip")
	root.free()


func test_length_matches_footprint() -> void:
	var root: Node3D = MegaRamp.build(8.0, 18.0, 14.0, 8.0)
	var end: float = 0.0
	for b: StaticBody3D in _solid_bodies(root):
		end = maxf(end, _bounds(b).end.z)
	assert_near(MegaRamp.length(8.0, 18.0, 14.0, 8.0), end, 0.01, "length() equals the far z")
	root.free()
