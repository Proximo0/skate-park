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
	assert_near(_world_origin(hips).y, PlaceholderSkater.HIP_HEIGHT, 0.001)
	body.free()


func test_body_height_and_feet_on_ground() -> void:
	var body: Node3D = PlaceholderSkater.build_body()
	var r: Vector2 = _world_y_range(body)
	assert_near(r.x, 0.0, 0.005, "lowest point is the soles")
	assert_true(r.y >= 1.55 and r.y <= 1.7, "adult height %f in 1.55..1.70" % r.y)
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
	assert_true(cap.mesh is ArrayMesh, "hair cap is a smooth scalp shell")
	var head_y: float = _world_origin(body.find_child("Head", true, false)).y
	var hr: Vector2 = _world_y_range(cap)
	assert_true(hr.x >= head_y - 0.02, "hair cap sits on the head, not below it")
	body.free()


## AABB of every mesh under node in the space of `space`, composed by hand (no scene tree).
func _aabb_in(node: Node3D, space: Node3D) -> AABB:
	var found: Array[MeshInstance3D] = []
	_meshes(node, found)
	var inv: Transform3D = _world_transform(space).affine_inverse()
	var box: AABB = AABB()
	for i: int in found.size():
		var b: AABB = (inv * _world_transform(found[i])) * found[i].mesh.get_aabb()
		box = b if i == 0 else box.merge(b)
	return box


func test_anime_head_proportions_face_and_hair() -> void:
	var body: Node3D = PlaceholderSkater.build_body()
	var head: Node3D = body.find_child("Head", true, false)
	var skin: MeshInstance3D = body.find_child("HeadMesh", true, false)
	var box: AABB = _aabb_in(skin, head)
	assert_near(box.size.y, 0.225, 0.006, "head is 0.225 chin to crown")
	assert_near(box.size.x, 0.15, 0.006, "head is about 0.15 wide")
	assert_true(box.position.y < 0.0 and box.position.y > -0.05, "chin just below the Head joint, above the neck")
	# Eyes: gap between them about one eye width, on the head's middle band.
	var le: AABB = _aabb_in(body.find_child("EyeLeftMesh", true, false), head)
	var re: AABB = _aabb_in(body.find_child("EyeRightMesh", true, false), head)
	var gap: float = re.position.x - (le.position.x + le.size.x)
	assert_true(absf(gap - le.size.x) < 0.012, "eye gap %f about one eye width %f" % [gap, le.size.x])
	var eye_mid: float = le.get_center().y - box.position.y
	assert_true(eye_mid > 0.38 * box.size.y and eye_mid < 0.5 * box.size.y, "eye line at or a bit below mid-head")
	for part: String in ["IrisLeftMesh", "PupilRightMesh", "EyeShineLeftMesh", "LashRightMesh", "BrowLeftMesh", "MouthMesh",
			"NoseMesh", "HairTieMesh", "FlowerClip"]:
		assert_true(body.find_child(part, true, false) != null, "head has " + part)
	# Layered locks: bangs, side locks, gathered strands and ponytail locks.
	var locks: int = 0
	var found: Array[MeshInstance3D] = []
	_meshes(head, found)
	var tris: int = 0
	for mi: MeshInstance3D in found:
		var n: String = str(mi.name)
		if n.begins_with("Bang") or n.begins_with("SideLock") or n.begins_with("HairStrand") or n in ["PonytailMesh",
				"PonytailLockL", "PonytailLockR", "PonytailUnder"]:
			locks += 1
		var arr: Array = mi.mesh.surface_get_arrays(0)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		tris += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	assert_true(locks >= 20, "at least 20 hair locks, got %d" % locks)
	assert_true(tris < 25000, "head and hair under 25k triangles, got %d" % tris)
	body.free()


func test_hair_sway_pivots() -> void:
	var body: Node3D = PlaceholderSkater.build_body()
	var model: Node3D = body.find_child("HeadModel", true, false)
	for pivot_name: String in ["HairSway_SideL", "HairSway_SideR", "HairSway_Ponytail"]:
		var p: Node3D = model.get_node_or_null(pivot_name)
		assert_true(p != null, pivot_name + " hangs from the head model")
		assert_true(p.get_child_count() > 0, pivot_name + " carries hair")
	var p1: Node3D = model.get_node("HairSway_Ponytail")
	var p2: Node3D = p1.get_node_or_null("HairSway_Ponytail2")
	assert_true(p2 != null, "ponytail chain: Ponytail2 under Ponytail")
	var p3: Node3D = p2.get_node_or_null("HairSway_Ponytail3")
	assert_true(p3 != null, "ponytail chain: Ponytail3 under Ponytail2")
	for p: Node3D in [p1, p2, p3, model.get_node("HairSway_SideL"), model.get_node("HairSway_SideR")]:
		assert_true(p.basis.is_equal_approx(Basis.IDENTITY), str(p.name) + " starts at identity rotation")
	assert_true(_world_origin(model.get_node("HairSway_SideL")).x < 0.0, "SideL is on the left (-X)")
	assert_true(p3.position.y < 0.0, "ponytail chain runs downward")
	body.free()


func test_body_palette_override() -> void:
	var body: Node3D = PlaceholderSkater.build_body({"top": Color(1, 0, 0)})
	var top: Node3D = body.find_child("BikiniTopMesh", true, false)
	var mat: StandardMaterial3D = top.material_override
	assert_eq(mat.albedo_color, Color(1, 0, 0), "top palette applied")
	assert_eq(top.get_meta("palette"), "top", "palette key meta")
	assert_eq(body.find_child("BikiniBottomMesh", true, false).get_meta("palette"), "bottom", "bottom key meta")
	assert_eq(body.find_child("LeftUpperLegMesh", true, false).get_meta("palette"), "skin", "bare leg")
	body.free()


## The body world AABB (x, z extents) of one mesh at rest, in metres.
func _world_box(node: Node3D) -> AABB:
	var found: Array[MeshInstance3D] = []
	_meshes(node, found)
	var box: AABB = AABB()
	var first: bool = true
	for mi: MeshInstance3D in found:
		var t: Transform3D = _world_transform(mi)
		var b: AABB = t * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func test_adult_proportions() -> void:
	var body: Node3D = PlaceholderSkater.build_body()
	var height: float = _world_y_range(body).y
	var hips: float = PlaceholderSkater.HIP_HEIGHT
	assert_true(hips / height > 0.49 and hips / height < 0.54, "long legs: hip joint at %f of the height" % (hips / height))
	var pelvis: AABB = _world_box(body.find_child("HipsMesh", true, false))
	var ribs: AABB = _world_box(body.find_child("ChestMesh", true, false))
	assert_true(pelvis.position.y > 0.72 and pelvis.position.y < 0.8, "crotch near 47%% of the height: %f" % pelvis.position.y)
	# Narrow ribcage: the under-bust is well under the hip width; flat elliptical torso, not a barrel.
	var under_bust: Array = SkaterParts.section_at(SkaterParts.smooth_sections(AnimeOutfit.CHEST, 3), 1.05)
	var hip_sec: Array = SkaterParts.section_at(SkaterParts.smooth_sections(AnimeOutfit.PELVIS, 3), 0.835)
	var waist_sec: Array = SkaterParts.section_at(SkaterParts.smooth_sections(AnimeOutfit.WAIST, 3), 0.99)
	assert_true(float(under_bust[1]) < 0.8 * float(hip_sec[1]), "ribcage narrower than the hips")
	assert_true(float(waist_sec[1]) < 0.7 * float(hip_sec[1]), "slim waist")
	assert_true(float(under_bust[2]) + float(under_bust[3]) < 0.75 * 2.0 * float(under_bust[1]), "ribcage deeper than wide is a barrel")
	assert_true(ribs.size.x < pelvis.size.x, "shoulder-less ribcage loft narrower than the hips")
	# Bust forms sit under their sway pivots, cups with them.
	for side: String in ["L", "R"]:
		var pivot: Node3D = body.find_child("BodySway_Bust" + side, true, false)
		assert_true(pivot != null, "bust pivot " + side)
		assert_eq(str(pivot.get_parent().name), "Chest", "bust pivot on the chest")
		assert_true(pivot.transform.is_equal_approx(Transform3D(Basis.IDENTITY, pivot.position)), "pivot at rest has no rotation")
		assert_true(pivot.find_child("BikiniCup" + side + "Mesh", false, false) != null, "cup moves with the bust " + side)
	# Slender neck: 0.06..0.08 between the top of the ribcage and the Head joint.
	var neck_len: float = _world_origin(body.find_child("Head", true, false)).y - ribs.end.y
	assert_true(neck_len > 0.03 and neck_len < 0.08, "visible neck %f" % neck_len)
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
	assert_near(AnimeBoard.top_y(0.0, 0.0), PlaceholderSkater.DECK_TOP_Y, 0.0001, "drawn grip top over the flat middle")
	assert_true(AnimeBoard.top_y(0.1, 0.0) > AnimeBoard.top_y(0.0, 0.0) + 0.003, "concave: rails above the centre")
	assert_true(AnimeBoard.top_y(0.0, -0.39) > PlaceholderSkater.DECK_TOP_Y + 0.025, "nose kicks up")
	assert_true(AnimeBoard.top_y(0.0, 0.39) > PlaceholderSkater.DECK_TOP_Y + 0.02, "tail kicks up")
	board.free()


func test_board_real_parts() -> void:
	var board: Node3D = PlaceholderSkater.build_board()
	for part: String in ["DeckGrip", "DeckBottom", "DeckEdge", "DeckPly_ply", "DeckPly_ply_coral", "DeckPly_ply_teal", "DeckSun", "DeckSea"]:
		assert_true(board.find_child(part, true, false) != null, "deck has " + part)
	for t: String in ["Truck_Front", "Truck_Back"]:
		var truck: Node3D = board.find_child(t, true, false)
		for part: String in ["TruckBaseMesh", "TruckHangerMesh", "TruckAxleMesh", "TruckBushingsMesh", "TruckRiserMesh", "TruckCrossMesh"]:
			assert_true(truck.find_child(part, true, false) != null, t + " has " + part)
		# Kingpins face the middle: the truck body's -Z (kingpin side) points toward z = 0.
		var body: Node3D = truck.find_child("TruckBody", true, false)
		var kingpin_dir: Vector3 = body.basis * Vector3.FORWARD
		assert_true(kingpin_dir.z * truck.position.z < 0.0, t + " kingpin faces the board's centre")
	for w: String in ["Wheel_FL", "Wheel_FR", "Wheel_BL", "Wheel_BR"]:
		var wheel: MeshInstance3D = board.find_child(w, true, false)
		assert_true(wheel.mesh is ArrayMesh, w + " is a lathe-turned wheel")
		assert_true(wheel.find_child(w + "_Core", true, false) != null, w + " has a core")
		assert_true(board.find_child(w + "_Hub", true, false) != null, w + " has a bearing hub")
		assert_true(absf(wheel.position.x) + AnimeBoard.WHEEL_W * 0.5 <= AnimeBoard.DECK_WIDTH * 0.5 + 0.002,
				w + " outer face within the deck's width")
	var found: Array[MeshInstance3D] = []
	_meshes(board, found)
	var tris: int = 0
	for mi: MeshInstance3D in found:
		if mi.visible:
			var arr: Array = mi.mesh.surface_get_arrays(0)
			tris += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	assert_true(tris < 11000, "board stays under 11k triangles, got %d" % tris)
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
		for part: String in ["SoleMesh", "FoxingMesh", "FoxingLineMesh", "SoleTreadMesh", "UpperMesh", "ToeCapMesh",
				"ToeBumperMesh", "EyestayMesh", "EyeletsMesh", "StitchMesh", "LacesMesh", "TongueMesh", "CollarMesh",
				"LiningMesh", "HeelCounterMesh", "HeelTabMesh", "SidePanelLeftMesh", "SidePanelRightMesh"]:
			assert_true(shoe.find_child(part, true, false) != null, side + " shoe has " + part)
		# Skate shoe proportions in foot space: about 0.3 m heel to toe, about 0.1 m wide, a flat sole.
		var foot: Node3D = shoe.get_parent() as Node3D
		var box: AABB = _local_aabb(shoe as Node3D, foot)
		assert_true(box.size.z >= 0.28 and box.size.z <= 0.34, side + " shoe length %f" % box.size.z)
		assert_true(box.size.x >= 0.1 and box.size.x <= 0.13, side + " shoe width %f" % box.size.x)
		assert_near(box.position.y, -PlaceholderSkater.ANKLE_HEIGHT, 0.002, side + " sole bottom at -ANKLE_HEIGHT")
	var head_y: float = _world_origin(body.find_child("Head", true, false)).y
	var r: Vector2 = _world_y_range(body)
	var head: Vector2 = _world_y_range(body.find_child("HeadMesh", true, false))
	var heads: float = r.y / (head.y - head.x)
	assert_true(heads >= 5.8 and heads <= 7.5, "about 6.5 heads tall, got %f (head joint %f)" % [heads, head_y])
	body.free()


func test_skate_shoe_colourways() -> void:
	var lagoon: Dictionary = SkateShoe.preset(SkateShoe.LAGOON)
	for preset_name: String in [SkateShoe.LAGOON, SkateShoe.DUNK, SkateShoe.ONE_STAR]:
		var colours: Dictionary = SkateShoe.preset(preset_name)
		for key: String in lagoon.keys():
			assert_true(colours.has(key), preset_name + " has " + key)
			assert_false((colours[key] as Color).is_equal_approx(Color(0.0, 1.0, 0.0)), preset_name + " " + key + " is not pure green")
	var foot: Node3D = Node3D.new()
	var shoe: Node3D = SkateShoe.build(foot, "Test", 0.12, {}, SkateShoe.preset(SkateShoe.DUNK))
	var upper: MeshInstance3D = shoe.find_child("UpperMesh", true, false)
	var want: Color = SkateShoe.preset(SkateShoe.DUNK)["shoe_canvas"]
	assert_true((upper.material_override as StandardMaterial3D).albedo_color.is_equal_approx(want), "colourway sets the canvas")
	var from: Dictionary = SkateShoe.colourway_from(Color(0.9, 0.3, 0.5))
	assert_true((from["shoe_canvas"] as Color).is_equal_approx(Color(0.9, 0.3, 0.5)), "colourway_from keeps the canvas colour")
	foot.free()


## AABB of every mesh under node, in the space of `space`.
func _local_aabb(node: Node3D, space: Node3D) -> AABB:
	var found: Array[MeshInstance3D] = []
	_meshes(node, found)
	var inv: Transform3D = _world_transform(space).affine_inverse()
	var box: AABB = AABB()
	for i: int in found.size():
		var b: AABB = (inv * _world_transform(found[i])) * found[i].get_aabb()
		box = b if i == 0 else box.merge(b)
	return box
