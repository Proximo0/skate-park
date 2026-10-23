extends TestCase
## Props: every builder returns a Node3D with meshes, collision only where specified, stays under the triangle
## budget, and sits on the ground (base origin) where it should.

const TRI_BUDGET: int = 600
const NO_COLLISION_KINDS: PackedStringArray = ["tree", "palm_tree", "bush", "picnic_table", "lamp_post", "ice_cream_cart", "cloud", "mountain", "crowd_kid"]


func _mesh_nodes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func _triangles(root: Node) -> int:
	var total: int = 0
	for mi: MeshInstance3D in _mesh_nodes(root):
		if mi.mesh != null:
			total += mi.mesh.get_faces().size() / 3
	return total


## Lowest world-space y of any mesh vertex under root, measured with root's own transform ignored.
func _min_y(node: Node3D, xf: Transform3D) -> float:
	var low: float = INF
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var child_xf: Transform3D = xf * mi.transform
			for v: Vector3 in mi.mesh.get_faces():
				low = minf(low, (child_xf * v).y)
		elif child is Node3D:
			low = minf(low, _min_y(child as Node3D, xf * (child as Node3D).transform))
	return low


func _build_all() -> Dictionary:
	return {
		"tree": Props.tree(),
		"palm_tree": Props.palm_tree(),
		"bush": Props.bush(),
		"trash_can": Props.trash_can(),
		"traffic_cone": Props.traffic_cone(),
		"picnic_table": Props.picnic_table(),
		"lamp_post": Props.lamp_post(),
		"ice_cream_cart": Props.ice_cream_cart(),
		"cloud": Props.cloud(1.5),
		"mountain": Props.mountain(40.0),
		"crowd_kid": Props.crowd_kid(Color.BLUE),
	}


func test_every_builder_returns_node3d_with_meshes() -> void:
	var all: Dictionary = _build_all()
	for kind: String in all:
		var root: Node3D = all[kind] as Node3D
		assert_true(root != null, kind + " returns a Node3D")
		if root != null:
			assert_true(_mesh_nodes(root).size() > 0, kind + " has mesh instances")
			assert_true(root.find_children("*", "MeshInstance3D", true, false).size() > 0, kind + " finds meshes")
	for node: Node in all.values():
		node.free()


func test_meshes_have_toon_material() -> void:
	var root: Node3D = Props.tree()
	for mi: MeshInstance3D in _mesh_nodes(root):
		assert_true(mi.material_override is ShaderMaterial, "mesh %s uses toon material" % mi.name)
	root.free()


func test_collision_only_on_trash_can_and_traffic_cone() -> void:
	var all: Dictionary = _build_all()
	for kind: String in NO_COLLISION_KINDS:
		var root: Node3D = all[kind] as Node3D
		assert_eq(root.find_children("*", "CollisionShape3D", true, false).size(), 0, kind + " has no collision")
		assert_false(root is StaticBody3D, kind + " is not a body")
	for kind: String in ["trash_can", "traffic_cone"]:
		var root: Node3D = all[kind] as Node3D
		assert_true(root is StaticBody3D, kind + " root is a StaticBody3D")
		var shapes: Array[Node] = root.find_children("*", "CollisionShape3D", true, false)
		assert_eq(shapes.size(), 1, kind + " has one collision shape")
		if shapes.size() == 1:
			assert_true((shapes[0] as CollisionShape3D).shape != null, kind + " shape set")
	for node: Node in all.values():
		node.free()


func test_each_prop_under_triangle_budget() -> void:
	var all: Dictionary = _build_all()
	for kind: String in all:
		var root: Node3D = all[kind] as Node3D
		var tris: int = _triangles(root)
		assert_true(tris > 0, kind + " has triangles")
		assert_true(tris < TRI_BUDGET, "%s under %d triangles, got %d" % [kind, TRI_BUDGET, tris])
	for node: Node in all.values():
		node.free()


func test_ground_props_sit_on_base() -> void:
	var all: Dictionary = _build_all()
	for kind: String in ["tree", "palm_tree", "bush", "trash_can", "traffic_cone", "picnic_table", "lamp_post", "ice_cream_cart", "crowd_kid"]:
		var root: Node3D = all[kind] as Node3D
		assert_near(_min_y(root, Transform3D.IDENTITY), 0.0, 0.02, kind + " base at y=0")
	for node: Node in all.values():
		node.free()


func test_lamp_post_has_warm_low_energy_light_without_shadows() -> void:
	var root: Node3D = Props.lamp_post()
	var lights: Array[Node] = root.find_children("*", "OmniLight3D", true, false)
	assert_eq(lights.size(), 1, "one omni light")
	if lights.size() == 1:
		var light: OmniLight3D = lights[0] as OmniLight3D
		assert_near(light.omni_range, 6.0, 0.0001, "range 6")
		assert_true(light.light_energy > 0.0 and light.light_energy <= 1.0, "low energy")
		assert_false(light.shadow_enabled, "shadows off")
		assert_true(light.light_color.r > light.light_color.b, "warm colour")
	root.free()


func test_tree_height_parameter_scales_crown() -> void:
	var short_tree: Node3D = Props.tree(2.0)
	var tall_tree: Node3D = Props.tree(6.0)
	assert_true(_min_y(tall_tree, Transform3D.IDENTITY) >= -0.02, "tall tree on ground")
	var short_top: float = -INF
	var tall_top: float = -INF
	for mi: MeshInstance3D in _mesh_nodes(short_tree):
		for v: Vector3 in mi.mesh.get_faces():
			short_top = maxf(short_top, (mi.transform * v).y)
	for mi: MeshInstance3D in _mesh_nodes(tall_tree):
		for v: Vector3 in mi.mesh.get_faces():
			tall_top = maxf(tall_top, (mi.transform * v).y)
	assert_true(tall_top > short_top * 2.0, "tall tree is taller")
	short_tree.free()
	tall_tree.free()


func test_scatter_adds_one_node_per_position() -> void:
	var parent: Node3D = Node3D.new()
	var positions: PackedVector3Array = PackedVector3Array([Vector3(1, 0, 2), Vector3(-3, 0, 4), Vector3(0, 0, 0)])
	var added: Array[Node3D] = Props.scatter(parent, "bush", positions, 7)
	assert_eq(added.size(), 3, "three nodes returned")
	assert_eq(parent.get_child_count(), 3, "three children added")
	for i: int in added.size():
		assert_eq(added[i].position, positions[i], "node %d at its position" % i)
	parent.free()


func test_scatter_is_deterministic_for_same_seed() -> void:
	var positions: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0), Vector3(5, 0, 5), Vector3(-2, 0, 3)])
	var a: Node3D = Node3D.new()
	var b: Node3D = Node3D.new()
	Props.scatter(a, "tree", positions, 42)
	Props.scatter(b, "tree", positions, 42)
	for i: int in 3:
		var na: Node3D = a.get_child(i) as Node3D
		var nb: Node3D = b.get_child(i) as Node3D
		assert_near(na.rotation.y, nb.rotation.y, 0.00001, "same yaw for same seed")
		assert_near(na.scale.x, nb.scale.x, 0.00001, "same scale for same seed")
	a.free()
	b.free()


func test_scatter_varies_yaw_and_scale_within_range() -> void:
	var positions: PackedVector3Array = PackedVector3Array()
	for i: int in 8:
		positions.append(Vector3(float(i) * 2.0, 0.0, 0.0))
	var parent: Node3D = Node3D.new()
	Props.scatter(parent, "bush", positions, 3)
	var yaws: PackedFloat32Array = PackedFloat32Array()
	for child: Node in parent.get_children():
		var n: Node3D = child as Node3D
		yaws.append(n.rotation.y)
		assert_true(n.scale.x >= 0.85 - 0.0001 and n.scale.x <= 1.2 + 0.0001, "scale in range")
		assert_near(n.scale.x, n.scale.y, 0.0001, "uniform scale")
	var distinct: bool = false
	for i: int in yaws.size():
		if absf(yaws[i] - yaws[0]) > 0.01:
			distinct = true
	assert_true(distinct, "yaw varies across instances")
	parent.free()


func test_scatter_collision_props_keep_collision() -> void:
	var parent: Node3D = Node3D.new()
	Props.scatter(parent, "trash_can", PackedVector3Array([Vector3(0, 0, 0), Vector3(3, 0, 0)]), 11)
	for child: Node in parent.get_children():
		assert_true(child is StaticBody3D, "scattered trash can is a body")
		assert_eq(child.find_children("*", "CollisionShape3D", true, false).size(), 1, "scattered trash can has collision")
	parent.free()
