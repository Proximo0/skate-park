extends TestCase
## VrmBody: the VRoid lead body is the default skin, retargets the code joints (rest maps to rest bar the arm
## spread, ankles exactly on the code ankles in every pose of the grid, grabbing wrists reach the code wrists),
## stands an adult height, is never drawn without clothes or a bikini, wears only the Wardrobe's shoes, and its
## bust follows the BodySway pivots.

const POSES: Array = [
	["idle_ride", 0.0, 0.0, 0.0, 0.0], ["crouch", 0.0, 1.0, 0.0, 0.0], ["push", 0.5, 0.0, 0.0, 0.0],
	["ollie", 0.2, 0.0, 0.0, 0.0], ["flip_kickflip", 0.2, 0.0, 0.0, 0.0], ["grind_five_oh", 0.3, 0.6, 0.0, 0.0],
	["grab_melon", 0.4, 0.0, 0.0, 0.0], ["grab_method", 0.4, 0.0, 0.0, 0.0], ["grab_stalefish", 0.4, 0.0, 0.0, 0.0],
	["manual_manual", 0.3, 0.2, 0.0, 0.0], ["drop_in", 0.3, 0.0, 0.0, 0.0], ["walk", 0.0, 0.0, 1.4, 0.3],
	["walk", 0.0, 0.0, 4.0, 0.55],
]


func _vrm_of(body: Node3D) -> VrmBody:
	var found: Array[Node] = body.find_children("*", "VrmBody", true, false)
	return found[0] as VrmBody if not found.is_empty() else null


## A posed skater in the tree: [holder, body, poser, vrm].
func _skater(body_type: String, options: Dictionary = {}) -> Array:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var holder: Node3D = Node3D.new()
	tree.root.add_child(holder)
	var opts: Dictionary = options.duplicate()
	opts["body"] = body_type
	var body: Node3D = PlaceholderSkater.build_body({}, opts)
	body.name = "SkaterBody"
	holder.add_child(body)
	var board: Node3D = PlaceholderSkater.build_board()
	holder.add_child(board)
	var poser: SkaterPoser = SkaterPoser.new()
	poser.body = body
	poser.board = board
	holder.add_child(poser)
	poser.set_process(false)
	poser._capture_rest()
	return [holder, body, poser, _vrm_of(body)]


func _pose(r: Array, p: Array) -> Dictionary:
	var poser: SkaterPoser = r[2]
	var pose: Dictionary = SkaterPoser.pose_for(str(p[0]), float(p[1]), float(p[2]), 0.0, false, float(p[3]), float(p[4]))
	poser._current = pose
	poser._apply(pose)
	(r[3] as VrmBody).sync_pose()
	return pose


func _body_pos(body: Node3D, node_name: String) -> Vector3:
	return body.global_transform.affine_inverse() * (body.find_child(node_name, true, false) as Node3D).global_position


func test_vrm_is_the_default_skin() -> void:
	for body_type: String in ["female", "male"]:
		var body: Node3D = PlaceholderSkater.build_body({}, {"body": body_type})
		assert_eq(str(body.get_meta("skin", "")), "vrm", "%s default skin" % body_type)
		var vb: VrmBody = _vrm_of(body)
		assert_true(vb != null, "%s has a VrmBody" % body_type)
		assert_true(body.find_child("HeadModel", true, false) == null, "%s: no code head" % body_type)
		for side: String in ["Left", "Right"]:
			var hand: MeshInstance3D = body.find_child(side + "HandMesh", true, false) as MeshInstance3D
			assert_true(hand != null and not hand.visible, "%s: code %s hand hidden" % [body_type, side])
			assert_true(body.find_child(side + "ShoeMesh", true, false) != null, "%s wears the skate shoes" % body_type)
		for mi: Node in body.find_children("*", "MeshInstance3D", true, false):
			var key: String = str(mi.get_meta("palette", ""))
			assert_false(key.begins_with("top") or key.begins_with("bottom") or key.begins_with("sock") or key == "band",
					"%s: no lofted garment (%s)" % [body_type, mi.name])
		body.free()
	var old: Node3D = PlaceholderSkater.build_body({}, {"body": "female", "skin": "houdini"})
	assert_eq(str(old.get_meta("skin", "")), "houdini", "the Houdini body is still selectable")
	assert_true(_vrm_of(old) == null and old.find_child("HeadModel", true, false) != null, "Houdini body has the code head")
	old.free()


func test_adult_standing_height() -> void:
	for body_type: String in ["female", "male"]:
		var body: Node3D = PlaceholderSkater.build_body({}, {"body": body_type})
		var h: float = _vrm_of(body).standing_height()
		assert_true(h > 1.58 and h < 1.75, "%s stands %.2f m" % [body_type, h])
		body.free()


func test_neutral_pose_maps_to_rest() -> void:
	var body: Node3D = PlaceholderSkater.build_body({}, {"body": "female"})
	var vb: VrmBody = _vrm_of(body)
	for j: String in SkaterPoser.JOINTS:
		var n: Node3D = body.find_child(j, true, false) as Node3D
		n.rotation = Vector3.ZERO
	(body.find_child("LeftUpperArm", true, false) as Node3D).rotation.z = -PI * 0.5
	(body.find_child("RightUpperArm", true, false) as Node3D).rotation.z = PI * 0.5
	vb.sync_pose()
	var skel: Skeleton3D = SkinnedBody.find_skeleton(vb.model)
	for j: String in ["Spine", "Chest", "Neck", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
			"RightHand"]:
		var b: int = skel.find_bone(j)
		var want: Basis = skel.get_bone_global_rest(b).basis
		var got: Basis = (vb._globals[b] as Transform3D).basis
		var err: float = rad_to_deg(Quaternion(want.orthonormalized()).angle_to(Quaternion(got.orthonormalized())))
		# The arm chain is spread out by ARM_SPREAD on purpose (hands clear the hips); the rest is exact.
		var expect: float = rad_to_deg(VrmBody.ARM_SPREAD) if j.contains("Arm") or j.contains("Hand") else 0.0
		assert_true(absf(err - expect) < 0.5, "%s at rest in the T-pose (%.2f deg off, %.1f expected)" % [j, err, expect])
	body.free()


func test_feet_on_the_code_ankles_in_every_pose() -> void:
	for body_type: String in ["female", "male"]:
		var r: Array = _skater(body_type)
		var body: Node3D = r[1]
		var vb: VrmBody = r[3]
		for p: Array in POSES:
			_pose(r, p)
			for side: String in ["Left", "Right"]:
				var gap: float = _body_pos(body, side + "Foot").distance_to(vb.bone_body_transform(side + "Foot").origin)
				assert_true(gap < 0.002, "%s %s %s ankle on the code ankle (%.3f m)" % [body_type, p[0], side, gap])
				var knee: Vector3 = vb.bone_body_transform(side + "LowerLeg").origin
				var hip: Vector3 = vb.bone_body_transform(side + "UpperLeg").origin
				var ankle: Vector3 = vb.bone_body_transform(side + "Foot").origin
				# Body space faces -Z: a knee never bends backward.
				assert_true((knee - (hip + ankle) * 0.5).z < 0.03, "%s %s %s knee bends forward" % [body_type, p[0], side])
		(r[0] as Node).free()


func test_grabbing_wrist_reaches_the_board() -> void:
	var r: Array = _skater("female")
	var body: Node3D = r[1]
	var vb: VrmBody = r[3]
	for p: Array in [["grab_melon", 0.4, 0.0, 0.0, 0.0], ["grab_method", 0.4, 0.0, 0.0, 0.0],
			["grab_stalefish", 0.4, 0.0, 0.0, 0.0], ["grab_indy", 0.4, 0.0, 0.0, 0.0], ["walk", 0.0, 0.0, 1.4, 0.3]]:
		var pose: Dictionary = _pose(r, p)
		for s: String in ["L", "R"]:
			if float(pose["grip_" + s]) < 0.9:
				continue
			var side: String = "Left" if s == "L" else "Right"
			var gap: float = _body_pos(body, side + "Hand").distance_to(vb.bone_body_transform(side + "Hand").origin)
			assert_true(gap < 0.09, "%s %s wrist within reach of the grab (%.3f m)" % [p[0], side, gap])
	(r[0] as Node).free()


func test_never_nude() -> void:
	for body_type: String in ["female", "male"]:
		var body: Node3D = PlaceholderSkater.build_body({}, {"body": body_type})
		var vb: VrmBody = _vrm_of(body)
		var drawn: PackedStringArray = vb.drawn_surfaces()
		var clothes: bool = false
		for nm: String in drawn:
			assert_false(nm.contains("_Shoes_"), "%s: the model's own shoes are hidden" % body_type)
			if nm.contains("_CLOTH"):
				clothes = true
		var skin_tex: String = ""
		for mi: MeshInstance3D in vb.meshes:
			if str(mi.name) != "Body":
				continue
			for s: int in mi.mesh.get_surface_count():
				var m: ShaderMaterial = mi.get_active_material(s) as ShaderMaterial
				if m != null and m.resource_name.contains("_Body_"):
					var t: Texture2D = m.get_shader_parameter("_MainTex") as Texture2D
					skin_tex = t.resource_path if t != null else ""
		var bikini: bool = skin_tex.begins_with(VrmBody.TEXTURE_DIR) and skin_tex.contains("bikini")
		assert_true(clothes or bikini, "%s wears its clothes or the bikini skin" % body_type)
		assert_eq(vb.bikini, bikini, "%s bikini flag matches the skin texture" % body_type)
		if body_type == "female":
			assert_eq(vb.bikini, VrmBody.bikini_available(), "the dress comes off only when the bikini skin exists")
		body.free()


func test_bust_follows_the_sway_pivots() -> void:
	var body: Node3D = PlaceholderSkater.build_body({}, {"body": "female"})
	var vb: VrmBody = _vrm_of(body)
	vb.sync_pose()
	var rest: Vector3 = vb.bone_body_transform("J_Sec_L_Bust1").origin
	var pivot: Node3D = body.find_child("BodySway_BustL", true, false) as Node3D
	pivot.position += Vector3(0.0, -0.02, 0.0)
	vb.sync_pose()
	var moved: Vector3 = vb.bone_body_transform("J_Sec_L_Bust1").origin - rest
	assert_true(moved.y < -0.015 and moved.y > -0.025, "bust bone drops with its pivot (%s)" % str(moved))
	pivot.position -= Vector3(0.0, -0.02, 0.0)
	vb.sync_pose()
	assert_true(vb.bone_body_transform("J_Sec_L_Bust1").origin.distance_to(rest) < 0.0005, "and returns")
	body.free()


func test_texture_lookup() -> void:
	assert_eq(VrmBody.hair_key("F00_000_Hair_00_HAIR_01"), "hair_main")
	assert_eq(VrmBody.hair_key("F00_000_Hair_00_HAIR_03"), "ribbon")
	assert_eq(VrmBody.hair_key("F00_000_HairBack_00_HAIR"), "hair_back")
	assert_eq(VrmBody.hair_key("F00_000_00_Face_00_SKIN"), "")
	var tint: Color = VrmBody.skin_tint(VrmBody.SKIN_REFERENCE)
	assert_true(tint.is_equal_approx(VrmBody.SKIN_TINT), "the default skin keeps the reference tint")
	if VrmBody.bikini_available():
		assert_true(VrmBody.bikini_file(VrmBody.BIKINI_COLOURS["coral"]).contains("coral"), "coral top picks the coral bikini")
