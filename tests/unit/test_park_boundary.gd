extends TestCase
## Park boundary: four invisible collision walls that enclose the +-HALF riding square.


func _walls() -> Array[StaticBody3D]:
	var out: Array[StaticBody3D] = []
	var root: Node3D = Park.boundary_walls()
	for c: Node in root.get_children():
		if c is StaticBody3D:
			out.append(c as StaticBody3D)
	for b: StaticBody3D in out:
		root.remove_child(b)
	root.free()
	return out


func _box_of(body: StaticBody3D) -> AABB:
	for c: Node in body.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			var size: Vector3 = ((c as CollisionShape3D).shape as BoxShape3D).size
			return AABB(body.position - size * 0.5, size)
	return AABB()


func _named(walls: Array[StaticBody3D], node_name: String) -> AABB:
	for b: StaticBody3D in walls:
		if b.name == node_name:
			return _box_of(b)
	return AABB()


func test_four_walls_at_least_20m_tall() -> void:
	var walls: Array[StaticBody3D] = _walls()
	assert_eq(walls.size(), 4, "four boundary walls")
	for b: StaticBody3D in walls:
		var box: AABB = _box_of(b)
		assert_true(box.size.y >= 20.0, "%s is at least 20 m tall, got %f" % [b.name, box.size.y])
		assert_eq(b.collision_layer, 1, "%s on the world layer" % b.name)


func test_walls_enclose_the_park_square() -> void:
	var walls: Array[StaticBody3D] = _walls()
	var n: AABB = _named(walls, "BoundaryN")
	var s: AABB = _named(walls, "BoundaryS")
	var w: AABB = _named(walls, "BoundaryW")
	var e: AABB = _named(walls, "BoundaryE")
	# inner faces lie beyond the riding square
	assert_true(n.end.z <= -Park.HALF, "north wall inner face beyond -HALF")
	assert_true(s.position.z >= Park.HALF, "south wall inner face beyond +HALF")
	assert_true(w.end.x <= -Park.HALF, "west wall inner face beyond -HALF")
	assert_true(e.position.x >= Park.HALF, "east wall inner face beyond +HALF")
	# north and south cover the full width of the square, east and west cover its full depth
	assert_true(n.position.x <= -Park.HALF and n.end.x >= Park.HALF, "north spans the width")
	assert_true(s.position.x <= -Park.HALF and s.end.x >= Park.HALF, "south spans the width")
	assert_true(w.position.z <= -Park.HALF and w.end.z >= Park.HALF, "west spans the depth")
	assert_true(e.position.z <= -Park.HALF and e.end.z >= Park.HALF, "east spans the depth")


func test_corners_overlap_with_no_gap() -> void:
	var walls: Array[StaticBody3D] = _walls()
	var n: AABB = _named(walls, "BoundaryN")
	var s: AABB = _named(walls, "BoundaryS")
	var w: AABB = _named(walls, "BoundaryW")
	var e: AABB = _named(walls, "BoundaryE")
	# north and south reach the outer faces of east and west, and east and west reach the outer faces of north and south
	assert_true(n.position.x <= w.position.x and n.end.x >= e.end.x, "north covers the corner x range")
	assert_true(s.position.x <= w.position.x and s.end.x >= e.end.x, "south covers the corner x range")
	assert_true(w.position.z <= n.position.z and w.end.z >= s.end.z, "west covers the corner z range")
	assert_true(e.position.z <= n.position.z and e.end.z >= s.end.z, "east covers the corner z range")


func test_walls_are_collision_only() -> void:
	var root: Node3D = Park.boundary_walls()
	var meshes: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			meshes += 1
		stack.append_array(n.get_children())
	assert_eq(meshes, 0, "boundary walls are invisible")
	root.free()
