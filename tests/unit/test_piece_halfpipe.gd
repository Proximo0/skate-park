extends TestCase
## HalfPipe park piece: node tree, coping rails, footprint and collision.

const WIDTH: float = 10.0
const FLAT: float = 6.0
const RADIUS: float = 3.5
const HEIGHT: float = 4.0
const DECK: float = 2.0


func _hp_all(node: Node, out: Array) -> void:
	for child: Node in node.get_children():
		out.append(child)
		_hp_all(child, out)


func _hp_local_transform(node: Node3D, root: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## Bounds of every mesh under root, in root's local space.
func _hp_bounds(root: Node3D) -> AABB:
	var nodes: Array = []
	_hp_all(root, nodes)
	var out: AABB = AABB()
	var first: bool = true
	for n: Variant in nodes:
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			var box: AABB = _hp_local_transform(mi, root) * mi.mesh.get_aabb()
			if first:
				out = box
				first = false
			else:
				out = out.merge(box)
	return out


func test_builds_named_node_with_children() -> void:
	var root: Node3D = HalfPipe.build()
	assert_true(root != null, "piece returned")
	assert_eq(String(root.name), "HalfPipe", "root name")
	assert_true(root.get_child_count() >= 4, "walls, floor and stripes present")
	root.free()


func test_two_coping_rails_at_lip_height() -> void:
	var root: Node3D = HalfPipe.build()
	var nodes: Array = []
	_hp_all(root, nodes)
	var copings: Array = []
	for n: Variant in nodes:
		if n is GrindRail and (n as GrindRail).kind == "coping":
			copings.append(n)
	assert_eq(copings.size(), 2, "one coping rail per wall")
	for c: Variant in copings:
		var rail: GrindRail = c as GrindRail
		assert_true(rail.points.size() >= 2, "coping has points")
		for p: Vector3 in rail.points:
			assert_near(p.y, HEIGHT, 0.0001, "coping sits at lip height")
		assert_near(rail.points[0].x, 0.0, 0.0001, "coping starts at x = 0")
		assert_near(rail.points[rail.points.size() - 1].x, WIDTH, 0.0001, "coping ends at x = width")
	root.free()


func test_footprint_matches_width_and_length() -> void:
	var root: Node3D = HalfPipe.build()
	var box: AABB = _hp_bounds(root)
	var length: float = 2.0 * (DECK + RADIUS) + FLAT
	assert_near(box.position.x, 0.0, 0.01, "min x")
	assert_near(box.end.x, WIDTH, 0.01, "max x")
	assert_near(box.position.z, 0.0, 0.01, "min z")
	assert_near(box.end.z, length, 0.01, "max z")
	assert_true(box.end.y >= HEIGHT, "reaches deck height")
	assert_true(box.end.y <= HEIGHT + 1.0, "fence stays under a metre above the deck")
	root.free()


func test_collision_shapes_exist() -> void:
	var root: Node3D = HalfPipe.build()
	var nodes: Array = []
	_hp_all(root, nodes)
	var shapes: int = 0
	var bodies: int = 0
	var empty: int = 0
	for n: Variant in nodes:
		if n is StaticBody3D:
			bodies += 1
		if n is CollisionShape3D:
			if (n as CollisionShape3D).shape == null:
				empty += 1
			else:
				shapes += 1
	assert_true(bodies >= 2, "static bodies for ramps, floor, sides and fences")
	assert_true(shapes >= bodies, "every body has a collision shape")
	assert_eq(empty, 0, "no empty collision shapes")
	root.free()
