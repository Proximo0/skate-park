extends TestCase
## PlaceholderSkater: joint names, pose geometry, height and board size. No scene tree, so world
## transforms are composed by hand from node transforms.

const JOINTS: PackedStringArray = [
	"Hips", "Spine", "Chest", "Neck", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
]


func _world_transform(node: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var n: Node3D = node
	while n != null:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t


func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c: Node in node.get_children():
		_meshes(c, out)


## World-space min and max Y over every mesh under node (node must be a root, or a child of a root).
func _world_y_range(node: Node3D) -> Vector2:
	var found: Array[MeshInstance3D] = []
	_meshes(node, found)
	var lo: float = INF
	var hi: float = -INF
	for mi: MeshInstance3D in found:
		var t: Transform3D = _world_transform(mi)
		var box: AABB = mi.mesh.get_aabb()
		for i: int in 8:
			var p: Vector3 = t * box.get_endpoint(i)
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
	return Vector2(lo, hi)


func _world_origin(node: Node3D) -> Vector3:
	return _world_transform(node).origin


func test_body_joint_names_and_hierarchy() -> void:
	var body: Node3D = PlaceholderSkater.build_body()
	for j: String in JOINTS:
		assert_true(body.find_child(j, true, false) != null, "joint " + j)
	var expected_parent: Dictionary = {
		"Spine": "Hips", "Chest": "Spine", "Neck": "Chest", "Head": "Neck",
		"LeftUpperArm": "Chest", "LeftLowerArm": "LeftUpperArm", "LeftHand": "LeftLowerArm",
		"RightUpperArm": "Chest", "RightLowerArm": "RightUpperArm", "RightHand": "RightLowerArm",
		"LeftUpperLeg": "Hips", "LeftLowerLeg": "LeftUpperLeg", "LeftFoot": "LeftLowerLeg",
		"RightUpperLeg": "Hips", "RightLowerLeg": "RightUpperLeg", "RightFoot": "RightLowerLeg",
	}
	for child: String in expected_parent.keys():
		var node: Node = body.find_child(child, true, false)
		assert_eq(str(node.get_parent().name), expected_parent[child], "parent of " + child)
	body.free()


func test_body_hips_height() -> void:
	var body: Node3D = PlaceholderSkater.build_body()
	var hips: Node3D = body.find_child("Hips", true, false)
	assert_near(_world_origin(hips).y, 0.62, 0.001)
	body.free()


func test_body_height_and_feet_on_ground() -> void:
	var body: Node3D = PlaceholderSkater.build_body()
	var r: Vector2 = _world_y_range(body)
	assert_near(r.x, 0.0, 0.005, "lowest point is the soles")
	assert_true(r.y >= 1.2 and r.y <= 1.45, "height %f in 1.2..1.45" % r.y)
	body.free()


func test_shoes_sit_flat_on_ground() -> void:
	var body: Node3D = PlaceholderSkater.build_body()
	for side: String in ["Left", "Right"]:
		var shoe: Node3D = body.find_child(side + "ShoeMesh", true, false)
		var r: Vector2 = _world_y_range(shoe)
		assert_near(r.x, 0.0, 0.005, side + " shoe sole")
		assert_true(r.y - r.x >= 0.12 and r.y - r.x <= 0.2, side + " shoe height (sole to tongue top) %f" % (r.y - r.x))
	body.free()


func test_left_foot_forward_regular_stance() -> void:
	var body: Node3D = PlaceholderSkater.build_body()
	var lf: Vector3 = _world_origin(body.find_child("LeftFoot", true, false))
	var rf: Vector3 = _world_origin(body.find_child("RightFoot", true, false))
	assert_true(lf.z < rf.z - 0.1, "left foot is toward -Z (nose) of right foot")
	assert_near(lf.y, rf.y, 0.001, "ankles level")
	body.free()


func test_hair_cap_is_on_top() -> void:
	var body: Node3D = PlaceholderSkater.build_body()
	var cap: MeshInstance3D = body.find_child("HairCapMesh", true, false)
	assert_true(cap.mesh is ArrayMesh, "hair cap is a smooth lathe dome")
	var head_y: float = _world_origin(body.find_child("Head", true, false)).y
	var hr: Vector2 = _world_y_range(cap)
	assert_true(hr.x >= head_y - 0.02, "hair cap sits on the head, not below it")
	body.free()


func test_body_palette_override() -> void:
	var body: Node3D = PlaceholderSkater.build_body({"shirt": Color(1, 0, 0)})
	var chest: Node3D = body.find_child("RashGuardMesh", true, false)
	var mat: StandardMaterial3D = chest.material_override
	assert_eq(mat.albedo_color, Color(1, 0, 0), "shirt palette applied")
	assert_eq(chest.get_meta("palette"), "shirt", "palette key meta")
	var pants: MeshInstance3D = body.find_child("LeftUpperLegMesh", true, false)
	assert_eq(pants.get_meta("palette"), "pants", "pants key meta")
	body.free()


func test_board_names() -> void:
	var board: Node3D = PlaceholderSkater.build_board()
	for w: String in ["Wheel_FL", "Wheel_FR", "Wheel_BL", "Wheel_BR", "Deck", "Truck_Front", "Truck_Back"]:
		assert_true(board.find_child(w, true, false) != null, "node " + w)
	board.free()


func test_board_length() -> void:
	var board: Node3D = PlaceholderSkater.build_board()
	var deck: MeshInstance3D = board.find_child("Deck", true, false)
	var size: Vector3 = (deck.mesh as BoxMesh).size
	assert_near(size.z, 0.8, 0.0001, "deck is 0.8 long along Z")
	assert_near(size.x, 0.22, 0.0001, "deck width")
	var ext: Vector2 = _world_extent_z(board)
	assert_near(ext.y - ext.x, 0.8, 0.05, "whole board length including kicks")
	board.free()


func test_board_wheels_on_ground() -> void:
	var board: Node3D = PlaceholderSkater.build_board()
	assert_near(_world_y_range(board).x, 0.0, 0.001, "lowest point is the wheels")
	for w: String in ["Wheel_FL", "Wheel_FR", "Wheel_BL", "Wheel_BR"]:
		var r: Vector2 = _world_y_range(board.find_child(w, true, false))
		assert_near(r.x, 0.0, 0.001, w + " bottom")
	board.free()


func test_deck_top_matches_constant() -> void:
	var board: Node3D = PlaceholderSkater.build_board()
	var deck: MeshInstance3D = board.find_child("Deck", true, false)
	var r: Vector2 = _world_y_range(deck)
	assert_near(r.y, PlaceholderSkater.DECK_TOP_Y, 0.0005, "deck top")
	board.free()


## Returns Vector2(min z, max z) over the board's meshes.
func _world_extent_z(node: Node3D) -> Vector2:
	var found: Array[MeshInstance3D] = []
	_meshes(node, found)
	var lo: float = INF
	var hi: float = -INF
	for mi: MeshInstance3D in found:
		var t: Transform3D = _world_transform(mi)
		var box: AABB = mi.mesh.get_aabb()
		for i: int in 8:
			var p: Vector3 = t * box.get_endpoint(i)
			lo = minf(lo, p.z)
			hi = maxf(hi, p.z)
	return Vector2(lo, hi)


func test_palette_has_no_pure_green() -> void:
	var body: Node3D = PlaceholderSkater.build_body()
	var found: Array[MeshInstance3D] = []
	_meshes(body, found)
	for mi: MeshInstance3D in found:
		var c: Color = (mi.material_override as StandardMaterial3D).albedo_color
		assert_false(c.is_equal_approx(Color(0.0, 1.0, 0.0)), str(mi.name) + " is not pure green")
	body.free()


func test_skate_shoe_parts_and_adult_proportions() -> void:
	var body: Node3D = PlaceholderSkater.build_body()
	for side: String in ["Left", "Right"]:
		var shoe: Node = body.find_child(side + "ShoeMesh", true, false)
		for part: String in ["SoleMesh", "FoxingMesh", "UpperMesh", "ToeCapMesh", "StitchMesh", "LacesMesh", "TongueMesh",
				"CollarMesh", "SidePanelLeftMesh", "SidePanelRightMesh"]:
			assert_true(shoe.find_child(part, true, false) != null, side + " shoe has " + part)
	var head_y: float = _world_origin(body.find_child("Head", true, false)).y
	var r: Vector2 = _world_y_range(body)
	var head: Vector2 = _world_y_range(body.find_child("HeadMesh", true, false))
	var heads: float = r.y / (head.y - head.x)
	assert_true(heads >= 5.8 and heads <= 7.5, "about 6.5 heads tall, got %f (head joint %f)" % [heads, head_y])
	body.free()
