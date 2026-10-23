extends TestCase


## All GrindRail nodes under a root (recursive).
func _sb_rails(root: Node) -> Array[GrindRail]:
	var out: Array[GrindRail] = []
	for c: Node in root.get_children():
		if c is GrindRail:
			out.append(c)
		out.append_array(_sb_rails(c))
	return out


## Zone ids of all gap zones under a root (recursive), in tree order.
func _sb_zone_ids(root: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for c: Node in root.get_children():
		if c.has_meta("zone_id"):
			out.append(String(c.get_meta("zone_id")))
		out.append_array(_sb_zone_ids(c))
	return out


## Zone nodes under a root (recursive).
func _sb_zones(root: Node) -> Array[Area3D]:
	var out: Array[Area3D] = []
	for c: Node in root.get_children():
		if c is Area3D and c.has_meta("zone_id"):
			out.append(c)
		out.append_array(_sb_zones(c))
	return out


func test_ledge_has_two_ledge_rails_on_top_edges() -> void:
	var root: Node3D = StreetBits.ledge(8.0, 0.5, 0.8)
	var rails: Array[GrindRail] = _sb_rails(root)
	assert_eq(rails.size(), 2, "two rails")
	for r: GrindRail in rails:
		assert_eq(r.kind, "ledge", "ledge kind")
		assert_eq(r.points.size(), 2, "two points per rail")
		for p: Vector3 in r.points:
			assert_near(p.y, 0.5, 0.0001, "rail on top surface")
	var xs: Array[float] = []
	for r: GrindRail in rails:
		xs.append(r.points[0].x)
	xs.sort()
	assert_near(xs[0], 0.0, 0.0001, "rail on x = 0 edge")
	assert_near(xs[1], 0.8, 0.0001, "rail on x = depth edge")


func test_ledge_rails_run_full_length() -> void:
	var rails: Array[GrindRail] = _sb_rails(StreetBits.ledge(8.0, 0.5, 0.8))
	for r: GrindRail in rails:
		assert_near(r.points[0].z, 0.0, 0.0001, "starts at z = 0")
		assert_near(r.points[1].z, 8.0, 0.0001, "ends at z = length")


func test_ledge_without_zone_has_no_gap_zone() -> void:
	var root: Node3D = StreetBits.ledge(8.0, 0.5, 0.8, PieceKit.PAINT_PURPLE, "")
	assert_eq(_sb_zone_ids(root).size(), 0, "no zone")


func test_ledge_with_zone_has_one_zone_over_top() -> void:
	var root: Node3D = StreetBits.ledge(8.0, 0.5, 0.8, PieceKit.PAINT_PURPLE, "ledge_a")
	var ids: PackedStringArray = _sb_zone_ids(root)
	assert_eq(ids.size(), 1, "one zone")
	assert_eq(ids[0], "ledge_a", "zone id")
	var zones: Array[Area3D] = _sb_zones(root)
	assert_eq(zones.size(), 1, "one zone node")
	var cs: CollisionShape3D = zones[0].get_child(0)
	var box: BoxShape3D = cs.shape
	assert_near(cs.position.y - box.size.y * 0.5, 0.5, 0.0001, "zone starts at ledge top")
	assert_near(box.size.y, 1.5, 0.0001, "zone is 1.5 m tall")


func test_manual_pad_has_two_ledge_rails_on_long_sides() -> void:
	var root: Node3D = StreetBits.manual_pad(6.0, 2.5, 0.3)
	var rails: Array[GrindRail] = _sb_rails(root)
	assert_eq(rails.size(), 2, "two rails")
	for r: GrindRail in rails:
		assert_eq(r.kind, "ledge", "ledge kind")
		for p: Vector3 in r.points:
			assert_near(p.y, 0.3, 0.0001, "rail on pad top")
		assert_near(r.points[1].z - r.points[0].z, 6.0, 0.0001, "rail runs the length")
	assert_eq(_sb_zone_ids(root).size(), 0, "no zones without ids")


func test_manual_pad_zones_on_each_end() -> void:
	var root: Node3D = StreetBits.manual_pad(6.0, 2.5, 0.3, "manual_pad_a", "manual_pad_b")
	var ids: PackedStringArray = _sb_zone_ids(root)
	assert_eq(ids.size(), 2, "two zones")
	assert_true(ids.has("manual_pad_a"), "zone a present")
	assert_true(ids.has("manual_pad_b"), "zone b present")
	for z: Area3D in _sb_zones(root):
		var cs: CollisionShape3D = z.get_child(0)
		var box: BoxShape3D = cs.shape
		var z_min: float = cs.position.z - box.size.z * 0.5
		var z_max: float = cs.position.z + box.size.z * 0.5
		if z.get_meta("zone_id") == "manual_pad_a":
			assert_near(z_min, 0.0, 0.0001, "zone a at z = 0 end")
			assert_near(z_max, 3.0, 0.0001, "zone a covers the first half, where an ollie lands into a manual")
		else:
			assert_near(z_max, 6.0, 0.0001, "zone b at z = length end")


func test_flat_rail_has_one_rail_at_height() -> void:
	var root: Node3D = StreetBits.flat_rail(6.0, 0.45)
	var rails: Array[GrindRail] = _sb_rails(root)
	assert_eq(rails.size(), 1, "one rail")
	assert_eq(rails[0].kind, "rail", "rail kind")
	for p: Vector3 in rails[0].points:
		assert_near(p.y, 0.45, 0.0001, "rail at height")
	assert_near(rails[0].points[1].z - rails[0].points[0].z, 6.0, 0.0001, "rail spans length")


func test_flat_rail_zones_at_both_ends() -> void:
	var root: Node3D = StreetBits.flat_rail(6.0, 0.45, "flatbar_a", "flatbar_b")
	var ids: PackedStringArray = _sb_zone_ids(root)
	assert_eq(ids.size(), 2, "two zones")
	assert_true(ids.has("flatbar_a"), "zone a present")
	assert_true(ids.has("flatbar_b"), "zone b present")
	assert_eq(_sb_zone_ids(StreetBits.flat_rail(6.0, 0.45)).size(), 0, "no zones without ids")


func test_bench_has_front_seat_ledge() -> void:
	var root: Node3D = StreetBits.bench(2.4)
	var rails: Array[GrindRail] = _sb_rails(root)
	assert_eq(rails.size(), 1, "one rail")
	assert_eq(rails[0].kind, "ledge", "ledge kind")
	for p: Vector3 in rails[0].points:
		assert_near(p.y, StreetBits.BENCH_SEAT_TOP, 0.0001, "rail on seat top")
		assert_near(p.z, StreetBits.BENCH_DEPTH, 0.0001, "rail on front edge")
	assert_near(rails[0].points[0].x, 0.0, 0.0001, "starts at x = 0")
	assert_near(rails[0].points[1].x, 2.4, 0.0001, "ends at x = length")
	assert_eq(_sb_zone_ids(root).size(), 0, "no zones")


func test_planter_has_one_closed_ledge_rail() -> void:
	var root: Node3D = StreetBits.planter(2.0, 0.55)
	var rails: Array[GrindRail] = _sb_rails(root)
	assert_eq(rails.size(), 1, "one rail")
	var r: GrindRail = rails[0]
	assert_eq(r.kind, "ledge", "ledge kind")
	assert_eq(r.points.size(), 5, "four corners plus closing point")
	assert_eq(r.points[0], r.points[4], "closed polyline")
	for p: Vector3 in r.points:
		assert_near(p.y, 0.55, 0.0001, "rail on planter top")
	var corners: Array[Vector3] = [Vector3(0, 0.55, 0), Vector3(2, 0.55, 0), Vector3(2, 0.55, 2), Vector3(0, 0.55, 2)]
	for c: Vector3 in corners:
		assert_true(r.points.has(c), "corner %s on rail" % c)


func test_planter_has_no_zones() -> void:
	assert_eq(_sb_zone_ids(StreetBits.planter()).size(), 0, "no zones")
