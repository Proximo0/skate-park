extends TestCase
## The big park: every placed piece stays inside the boundary walls, the new outer pieces never overlap another piece,
## and the long lines keep a clear run-out after their last piece.

var _park: Park


func _build() -> Park:
	if _park == null:
		_park = Park.new()
		_park._ready()
	return _park


func _meshes(node: Node, xf: Transform3D, out: Array[AABB]) -> void:
	for c: Node in node.get_children():
		if c is Node3D:
			var n3: Node3D = c as Node3D
			var t: Transform3D = xf * n3.transform
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				out.append(t * (c as MeshInstance3D).mesh.get_aabb())
			_meshes(c, t, out)


## World (park-space) AABB of a placed piece, from its meshes.
func _aabb(piece: Node3D) -> AABB:
	var parts: Array[AABB] = []
	_meshes(piece, piece.transform, parts)
	var box: AABB = AABB()
	for i: int in parts.size():
		box = parts[i] if i == 0 else box.merge(parts[i])
	return box


func _xz_overlap(a: AABB, b: AABB, eps: float) -> bool:
	return a.position.x < b.end.x - eps and b.position.x < a.end.x - eps and a.position.z < b.end.z - eps and b.position.z < a.end.z - eps


func _piece(park: Park, node_name: String) -> Node3D:
	for p: Node3D in park.placed:
		if p.name == node_name:
			return p
	return null


func test_pieces_inside_boundary() -> void:
	var park: Park = _build()
	var limit: float = Park.BOUNDARY_INNER
	assert_true(park.placed.size() > 40, "pieces were placed")
	for p: Node3D in park.placed:
		var b: AABB = _aabb(p)
		assert_true(b.position.x >= -limit and b.end.x <= limit and b.position.z >= -limit and b.end.z <= limit,
			"%s inside the boundary, aabb %s" % [p.name, str(b)])


const NEW_PIECES: Array[String] = ["MegaRamp", "MegaSign", "DomeBowl", "DropRamp", "Loop", "CatchQuarter", "LoopSign", "Downhill",
	"LongLedge", "LongRail", "HubbaSet", "StreetQuarter", "Rail25", "Rail15", "BankWall-38", "BankWall-2", "BankWall34", "BankWall70"]


func test_new_pieces_do_not_overlap_anything() -> void:
	var park: Park = _build()
	for node_name: String in NEW_PIECES:
		var a: Node3D = _piece(park, node_name)
		assert_true(a != null, "%s exists" % node_name)
		if a == null:
			continue
		var ab: AABB = _aabb(a)
		for other: Node3D in park.placed:
			if other == a:
				continue
			assert_false(_xz_overlap(ab, _aabb(other), 0.05), "%s overlaps %s" % [node_name, other.name])


func _corridor_clear(park: Park, x0: float, x1: float, z0: float, z1: float, owner_names: Array[String]) -> bool:
	var box: AABB = AABB(Vector3(x0, -10.0, z0), Vector3(x1 - x0, 20.0, z1 - z0))
	for p: Node3D in park.placed:
		if owner_names.has(String(p.name)):
			continue
		if _xz_overlap(box, _aabb(p), 0.05):
			return false
	return true


func test_run_outs_are_clear() -> void:
	var park: Park = _build()
	var mega_end: float = Park.MEGA_POS.z + MegaRamp.length(8.0, 18.0, 14.0, 8.0)
	assert_true(_corridor_clear(park, Park.MEGA_POS.x, Park.MEGA_POS.x + 8.0, mega_end, mega_end + 12.0, []), "12 m clear past the mega quarter pipe")
	var loop_box: AABB = _aabb(_piece(park, "Loop"))
	var catch_box: AABB = _aabb(_piece(park, "CatchQuarter"))
	assert_true(catch_box.position.z - loop_box.end.z >= 12.0, "12 m or more between the loop and the catch quarter pipe")
	assert_true(_corridor_clear(park, loop_box.position.x, loop_box.end.x, loop_box.end.z, loop_box.end.z + 12.0, []), "loop run-out is clear")
	var hubba: AABB = _aabb(_piece(park, "HubbaSet"))
	var street_q: AABB = _aabb(_piece(park, "StreetQuarter"))
	assert_true(street_q.position.x - hubba.end.x >= 12.0, "12 m or more between the hubba and the street quarter pipe")


func test_drop_ins_are_on_the_decks() -> void:
	var park: Park = _build()
	var mega: Transform3D = park.drop_ins["mega"]
	assert_near(mega.origin.y, 18.0, 0.001, "mega deck height")
	assert_near((-mega.basis.z).z, 1.0, 0.001, "mega faces south")
	var lp: Transform3D = park.drop_ins["loop"]
	assert_near(lp.origin.y, Park.DROP_HEIGHT, 0.001, "drop ramp deck height")
	assert_near((-lp.basis.z).z, 1.0, 0.001, "drop ramp faces south")
	assert_near(lp.origin.x, Park.DROP_POS.x + Park.DROP_WIDTH * 0.5, 0.001, "centred on the drop ramp")


func test_loop_lines_up_with_the_drop_ramp() -> void:
	var park: Park = _build()
	# the loop's run-in ribbon centre (world x) equals the drop ramp's centre line
	var loop: Node3D = _piece(park, "Loop")
	var ribbon_centre_x: float = loop.position.x - 1.5
	assert_near(ribbon_centre_x, Park.DROP_POS.x + Park.DROP_WIDTH * 0.5, 0.001, "ribbon centre on the ramp centre line")
	assert_near(loop.position.z, Park.DROP_POS.z + DropRamp.length(Park.DROP_WIDTH, Park.DROP_HEIGHT), 0.001, "run-in starts where the ramp ends")


func test_ground_has_holes_for_both_bowls() -> void:
	var park: Park = _build()
	var probes: Array[Vector3] = [Vector3(29.0, 0.0, -33.0), Vector3(Park.DOME_POS.x + 9.5, 0.0, Park.DOME_POS.z + 9.5)]
	for pr: Vector3 in probes:
		for c: Node in park.get_children():
			if String(c.name).begins_with("Ground") and c is Node3D:
				var b: AABB = _aabb(c as Node3D)
				assert_false(pr.x > b.position.x and pr.x < b.end.x and pr.z > b.position.z and pr.z < b.end.z, "no slab over the bowl at %s" % str(pr))
	var covered: int = 0
	for c: Node in park.get_children():
		if String(c.name).begins_with("Ground") and c is Node3D:
			var b: AABB = _aabb(c as Node3D)
			if 0.0 > b.position.x and 0.0 < b.end.x and 0.0 > b.position.z and 0.0 < b.end.z:
				covered += 1
	assert_eq(covered, 1, "the centre of the park is on exactly one slab")


func test_fences_cover_the_new_perimeter() -> void:
	var park: Park = _build()
	var n: int = 0
	for c: Node in park.get_children():
		if String(c.name).begins_with("Fence"):
			n += 1
	assert_eq(n, 4 * int(Park.HALF * 2.0 / 10.0), "fence segments")


func _zone_ids(node: Node, out: Dictionary) -> void:
	if node is Area3D and node.has_meta("zone_id"):
		out[str(node.get_meta("zone_id"))] = true
	for c: Node in node.get_children():
		_zone_ids(c, out)


func test_every_gap_has_both_zones_in_the_park() -> void:
	var park: Park = _build()
	var ids: Dictionary = {}
	_zone_ids(park, ids)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/gaps.json"))
	var root: Dictionary = parsed
	for entry: Variant in root["gaps"]:
		var gap: Dictionary = entry
		assert_true(ids.has(gap["start_zone"]), "%s start zone %s exists" % [gap["id"], gap["start_zone"]])
		assert_true(ids.has(gap["end_zone"]), "%s end zone %s exists" % [gap["id"], gap["end_zone"]])


func test_collectible_coins_for_the_goals() -> void:
	var park: Park = _build()
	var items: Dictionary = {}
	for c: Collectible in park.collectibles:
		items[c.item] = true
	for item: String in ["L", "M", "D"]:
		assert_true(items.has(item), "coin %s placed" % item)


func test_zz_cleanup() -> void:
	if _park != null:
		_park.free()
		_park = null
