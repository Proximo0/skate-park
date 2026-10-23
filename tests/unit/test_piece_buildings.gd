extends TestCase


func _bt_nodes(root: Node) -> Array:
	var out: Array = []
	_bt_walk(root, out)
	return out


func _bt_walk(node: Node, out: Array) -> void:
	out.append(node)
	for c: Node in node.get_children():
		_bt_walk(c, out)


## Highest world y of a static body's collision faces, where the body sits at its own position.
func _bt_top_y(body: StaticBody3D, z_max: float = INF, z_min: float = -INF) -> float:
	var cs: CollisionShape3D = body.get_node("Collision") as CollisionShape3D
	var faces: PackedVector3Array = (cs.shape as ConcavePolygonShape3D).get_faces()
	var top: float = -INF
	for v: Vector3 in faces:
		if v.z <= z_max and v.z >= z_min:
			top = maxf(top, v.y + body.position.y)
	return top


func test_shop_has_ledge_rails_on_parapet() -> void:
	var s: Node3D = Buildings.shop(10.0, 8.0, 4.0)
	var rails: Array = []
	for n: Node in _bt_nodes(s):
		if n is GrindRail and n.name.begins_with("Ledge"):
			rails.append(n)
	assert_eq(rails.size(), 3, "left, front and right ledges")
	for r: GrindRail in rails:
		assert_eq(r.kind, "ledge")
		for p: Vector3 in r.points:
			assert_near(p.y, 4.0 + Buildings.PARAPET_H, 0.0001, "ledge sits on parapet top")
	s.free()


func test_shop_roof_collision_top_at_height() -> void:
	var s: Node3D = Buildings.shop(10.0, 8.0, 4.0)
	var walls: StaticBody3D = s.get_node("Walls")
	assert_near(_bt_top_y(walls), 4.0, 0.0001, "roof top is at height")
	s.free()


func test_shop_quarter_pipe_on_roof() -> void:
	var s: Node3D = Buildings.shop(10.0, 8.0, 4.0)
	var qp: Node3D = s.get_node("QuarterPipe")
	assert_near(qp.position.y, 4.0, 0.0001, "pipe base sits on roof")
	assert_true(qp.get_node("Ramp") is StaticBody3D, "pipe has collision ramp")
	assert_true(qp.get_node("Coping") is GrindRail, "pipe has coping rail")
	assert_near(_bt_top_y(qp.get_node("Ramp") as StaticBody3D) + qp.position.y, 4.0 + Buildings.ROOF_PIPE_HEIGHT, 0.0001, "pipe deck top")
	s.free()


func test_roof_ramp_rises_toward_minus_z_to_roof_height() -> void:
	var r: Node3D = Buildings.roof_access_ramp(4.0, 10.0, 4.0)
	var ramp: StaticBody3D = r.get_node("Ramp")
	assert_near(_bt_top_y(ramp, 0.01), 4.0, 0.0001, "back edge reaches roof height")
	assert_true(_bt_top_y(ramp, 10.0, 9.5) < 0.6, "ground end is low")
	r.free()


func test_roof_ramp_has_ledge_on_each_side() -> void:
	var r: Node3D = Buildings.roof_access_ramp(4.0, 10.0, 4.0)
	var ledges: int = 0
	for n: Node in _bt_nodes(r):
		if n is GrindRail and n.name.begins_with("Ledge") and (n as GrindRail).kind == "ledge":
			ledges += 1
	assert_eq(ledges, 2, "two side ledges")
	r.free()


func test_gap_pair_zones_at_roof_height() -> void:
	var g: Node3D = Buildings.gap_pair("roof_west", "roof_east", 4.0)
	var a: Area3D = g.get_node("Zone_roof_west")
	var b: Area3D = g.get_node("Zone_roof_east")
	assert_eq(a.get_meta("zone_id"), "roof_west")
	assert_eq(b.get_meta("zone_id"), "roof_east")
	var ca: CollisionShape3D = a.get_child(0) as CollisionShape3D
	var cb: CollisionShape3D = b.get_child(0) as CollisionShape3D
	var sa: BoxShape3D = ca.shape as BoxShape3D
	assert_eq(sa.size, Vector3(6.0, 3.0, 2.0), "zone size")
	# Centres: min corner + half size. Zone a min x = 0, zone b min x = gap + 2 = 6.
	assert_near(ca.position.x, 3.0, 0.0001, "zone a centre x")
	assert_near(cb.position.x, 9.0, 0.0001, "zone b centre x")
	assert_near(ca.position.y, 5.5, 0.0001, "zones sit at roof height")
	g.free()
