extends TestCase
## StreetRun: the long south-run pieces.


func _all(node: Node) -> Array:
	var out: Array = [node]
	for c: Node in node.get_children():
		out.append_array(_all(c))
	return out


func _zone_ids(root: Node) -> Array[String]:
	var ids: Array[String] = []
	for n: Node in _all(root):
		if n is Area3D and n.has_meta("zone_id"):
			ids.append(str(n.get_meta("zone_id")))
	return ids


func test_downhill_profile_eases_from_drop_to_zero() -> void:
	assert_near(StreetRun.downhill_y(0.0, 3.5), 3.5, 0.0001, "top")
	assert_near(StreetRun.downhill_y(1.0, 3.5), 0.0, 0.0001, "bottom")
	assert_near(StreetRun.downhill_y(0.5, 3.5), 1.75, 0.0001, "middle")
	var prev: float = 99.0
	for i: int in 21:
		var y: float = StreetRun.downhill_y(float(i) / 20.0, 3.5)
		assert_true(y <= prev + 0.0001, "never rises")
		prev = y
	# gentle: the steepest slope of a 34 m, 3.5 m drop is under 10 degrees
	var steepest: float = 0.0
	for i: int in 200:
		var a: float = StreetRun.downhill_y(float(i) / 200.0, 3.5)
		var b: float = StreetRun.downhill_y(float(i + 1) / 200.0, 3.5)
		steepest = maxf(steepest, (a - b) / (34.0 / 200.0))
	assert_true(rad_to_deg(atan(steepest)) < 10.0, "gentle slope")


func test_downhill_zones_and_length() -> void:
	var root: Node3D = StreetRun.downhill(34.0, 3.5, 8.0, 5.0, 10.0)
	var ids: Array[String] = _zone_ids(root)
	assert_true(ids.has("downhill_top") and ids.has("downhill_bottom"), "top and bottom zones")
	assert_near(StreetRun.downhill_length(34.0, 5.0, 10.0), 49.0, 0.0001, "length")
	root.free()


func test_long_pieces_have_end_zones() -> void:
	var ledge: Node3D = StreetRun.long_ledge(18.0, 0.5, 0.8, PieceKit.PAINT_PURPLE, "long_ledge")
	var ids: Array[String] = _zone_ids(ledge)
	assert_true(ids.has("long_ledge_a") and ids.has("long_ledge_b"), "ledge end zones")
	ledge.free()
	var rail: Node3D = StreetRun.long_rail(22.0, 0.45, "long_rail")
	ids = _zone_ids(rail)
	assert_true(ids.has("long_rail_a") and ids.has("long_rail_b"), "rail end zones")
	var longest: float = 0.0
	for n: Node in _all(rail):
		if n is GrindRail:
			var pts: PackedVector3Array = (n as GrindRail).points
			longest = maxf(longest, pts[0].distance_to(pts[pts.size() - 1]))
	assert_true(longest >= 15.0, "rail is at least 15 m long")
	rail.free()


func test_hubba_has_sloped_grind_line_and_zones() -> void:
	var root: Node3D = StreetRun.hubba_set(10, 0.2, 0.9, 5.0)
	var ids: Array[String] = _zone_ids(root)
	for z: String in ["hubba_a", "hubba_b", "hubba_stairs_top", "hubba_stairs_bottom"]:
		assert_true(ids.has(z), "zone " + z)
	var found: bool = false
	for n: Node in _all(root):
		if n is GrindRail and n.name == "HubbaRail":
			var pts: PackedVector3Array = (n as GrindRail).points
			assert_true(pts[0].y > pts[pts.size() - 1].y + 1.0, "the hubba rail runs downhill")
			found = true
	assert_true(found, "hubba rail present")
	assert_near(StreetRun.hubba_length(10, 0.9, 3.0), 18.0, 0.0001, "length")
	root.free()


func test_bank_wall_has_bank_and_wall() -> void:
	var root: Node3D = StreetRun.bank_wall(24.0, 1.6, 4.0, 3.0)
	var names: Array[String] = []
	for n: Node in _all(root):
		names.append(String(n.name))
	assert_true(names.has("Bank") and names.has("WallrideWall"), "bank and wall")
	root.free()
