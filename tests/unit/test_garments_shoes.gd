extends TestCase
## Shoe garments (cupsole, puffy, high top): registration, the foot contract (node name, sole bottom at -ankle height,
## length within 5% of the vulc), triangle budget, colourways, and the high top's collar staying outside the leg skin
## and the sock in every pose (covers "ankle").


## These tests check the lofted garments and code parts on the Houdini body (the VRM body wears none of them), so
## bodies built without a "skin" option use it while a test of this file runs.
func _init() -> void:
	PlaceholderSkater.houdini_scopes += 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PlaceholderSkater.houdini_scopes -= 1

const IDS: Array = ["shoes_cupsole", "shoes_puffy", "shoes_high_top"]
const POSES: Array = [
	["idle", "idle_ride", 0.0, 0.0, 0.0, 0.0], ["crouch", "crouch", 0.0, 1.0, 0.0, 0.0],
	["ollie_up", "ollie", 0.2, 0.0, 0.0, 0.0], ["push", "push", 0.5, 0.0, 0.0, 0.0],
	["indy", "grab_indy", 0.4, 0.0, 0.0, 0.0], ["method", "grab_method", 0.4, 0.0, 0.0, 0.0],
	["nosegrab", "grab_nosegrab", 0.4, 0.0, 0.0, 0.0], ["walk", "walk", 0.0, 0.0, 1.4, 0.3],
	["run", "walk", 0.0, 0.0, 4.0, 0.55], ["grind", "grind_five_oh", 0.3, 0.6, 0.0, 0.0],
]
const BARE: Dictionary = {"hair": "none", "top": "none", "bottom": "none", "socks": "none", "shoes": "none", "accessories": []}


func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c: Node in node.get_children():
		_meshes(c, out)


func _tris(mi: MeshInstance3D) -> int:
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var idx: Variant = arrays[Mesh.ARRAY_INDEX]
	return (idx as PackedInt32Array).size() / 3 if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3


## Parts of one shoe: everything under the shoe node plus the high top's shaft parts on the lower leg ("<Side>Shoe*").
func _shoe_parts(body: Node3D, side: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	_meshes(body.find_child(side + "ShoeMesh", true, false), out)
	var lower: Node = body.find_child(side + "LowerLeg", true, false)
	for c: Node in lower.get_children():
		if c is MeshInstance3D and str(c.name).begins_with(side + "Shoe"):
			out.append(c as MeshInstance3D)
	return out


func _dress(id: String, body_type: String = "female", extra: Dictionary = {}) -> Node3D:
	var opts: Dictionary = {"body": body_type, "shoes": id, "top": "none", "bottom": "none"}
	for k: String in extra.keys():
		opts[k] = extra[k]
	return PlaceholderSkater.build_body({}, opts)


func _world_transform(node: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var n: Node3D = node
	while n != null:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t


func _local_aabb(parts: Array[MeshInstance3D], space: Node3D) -> AABB:
	var inv: Transform3D = _world_transform(space).affine_inverse()
	var box: AABB = AABB()
	for i: int in parts.size():
		var b: AABB = (inv * _world_transform(parts[i])) * parts[i].get_aabb()
		box = b if i == 0 else box.merge(b)
	return box


func test_registered_and_built() -> void:
	for id: String in IDS:
		assert_true(Wardrobe.has_builder("shoes", id), id + " registered")
		assert_false(Wardrobe.is_stub("shoes", id), id + " is built, not a stub")
		assert_true(Wardrobe.built_ids().has(id), id + " in built_ids")
	assert_true(GarmentShoes.STUBS.is_empty(), "no shoe stubs left")
	assert_eq(Wardrobe.covers("shoes", "shoes_high_top", "female"), PackedStringArray(["ankle_L", "ankle_R"]), "high top covers the ankle")
	assert_true(Wardrobe.covers("shoes", "shoes_cupsole", "male").is_empty(), "cupsole covers nothing")
	assert_true(Wardrobe.covers("shoes", "shoes_puffy", "male").is_empty(), "puffy covers nothing")


func test_foot_contract_and_budget() -> void:
	var vulc: Node3D = _dress("shoes_low_vulc")
	var vfoot: Node3D = vulc.find_child("RightFoot", true, false)
	var vbox: AABB = _local_aabb(_shoe_parts(vulc, "Right"), vfoot)
	for body_type: String in ["female", "male"]:
		for id: String in IDS:
			var body: Node3D = _dress(id, body_type)
			for side: String in ["Left", "Right"]:
				var shoe: Node = body.find_child(side + "ShoeMesh", true, false)
				assert_true(shoe != null, "%s %s has %sShoeMesh" % [body_type, id, side])
				var foot: Node3D = body.find_child(side + "Foot", true, false)
				assert_true(shoe.get_parent() == foot, "%s shoe hangs on the foot" % side)
				var foot_parts: Array[MeshInstance3D] = []
				_meshes(shoe, foot_parts)
				var box: AABB = _local_aabb(foot_parts, foot)
				assert_near(box.position.y, -PlaceholderSkater.ANKLE_HEIGHT, 0.002, "%s %s sole bottom" % [id, side])
				assert_near(box.size.z, vbox.size.z, vbox.size.z * 0.05, "%s %s length within 5%% of the vulc (%f vs %f)" % [id, side, box.size.z, vbox.size.z])
				assert_near(box.get_center().z, vbox.get_center().z, 0.012, "%s %s toe and heel stay over the deck" % [id, side])
				assert_true(box.size.x >= 0.1 and box.size.x <= 0.16, "%s %s width %f" % [id, side, box.size.x])
				var tris: int = 0
				for mi: MeshInstance3D in _shoe_parts(body, side):
					tris += _tris(mi)
				assert_true(tris >= 2000 and tris <= 4500, "%s %s triangles %d in 2000..4500" % [id, side, tris])
			body.free()
	vulc.free()


func test_distinct_silhouettes() -> void:
	# Each style carries the parts that make it recognisable.
	var want: Dictionary = {
		"shoes_cupsole": ["SoleStitchMesh", "QuarterMesh", "SunMarkMesh", "PerforationMesh", "TongueLabelMesh", "CollarMesh"],
		"shoes_puffy": ["BumperMesh", "BumperRibsMesh", "BadgeDiscMesh", "LaceCoverMesh", "QuarterTopMesh", "TongueLabelMesh", "CollarMesh"],
		"shoes_high_top": ["SidePanelLeftMesh", "ToeCapMesh", "TongueMesh", "EyeletsMesh"],
	}
	for id: String in want.keys():
		var body: Node3D = _dress(id)
		var shoe: Node = body.find_child("RightShoeMesh", true, false)
		for part: String in want[id]:
			assert_true(shoe.find_child(part, true, false) != null, "%s has %s" % [id, part])
		body.free()
	var hi: Node3D = _dress("shoes_high_top")
	var lower: Node = hi.find_child("RightLowerLeg", true, false)
	for part: String in ["RightShoeShaftMesh", "RightShoeCollarMesh", "RightShoeAnklePadMesh", "RightShoeEyeletsMesh", "RightShoeLacesMesh"]:
		assert_true(lower.get_node_or_null(part) != null, "high top shaft has " + part)
	hi.free()
	# Eyelet counts: 7 cupsole, 8 high top (4 on the vamp, 4 on the shaft); 8 triangles each.
	var cup: Node3D = _dress("shoes_cupsole")
	var cup_eyelets: MeshInstance3D = cup.find_child("RightShoeMesh", true, false).find_child("EyeletsMesh", true, false)
	assert_eq(_tris(cup_eyelets), 7 * 2 * 8, "cupsole has 7 eyelet pairs")
	cup.free()
	var hi2: Node3D = _dress("shoes_high_top")
	var lo: MeshInstance3D = hi2.find_child("RightShoeMesh", true, false).find_child("EyeletsMesh", true, false)
	var up: MeshInstance3D = hi2.find_child("RightLowerLeg", true, false).get_node("RightShoeEyeletsMesh")
	assert_eq(_tris(lo) + _tris(up), 8 * 2 * 8, "high top has 8 eyelet pairs")
	hi2.free()


func test_colourways() -> void:
	var keys: Dictionary = SkateShoe.preset(SkateShoe.LAGOON)
	var way: Dictionary = SkateShoe.colourway_from(Color(0.9, 0.3, 0.5))
	for id: String in IDS:
		var body: Node3D = PlaceholderSkater.build_body(way, {"body": "female", "shoes": id})
		var found: Array[MeshInstance3D] = _shoe_parts(body, "Right") + _shoe_parts(body, "Left")
		assert_true(found.size() > 10, id + " has parts")
		var canvas: int = 0
		for mi: MeshInstance3D in found:
			var key: String = str(mi.get_meta("palette", ""))
			assert_true(keys.has(key), "%s %s uses a shoe_* colourway key (%s)" % [id, mi.name, key])
			if key == "shoe_canvas":
				canvas += 1
				assert_true((mi.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color(0.9, 0.3, 0.5)),
						"%s canvas takes the colourway colour" % id)
		assert_true(canvas >= 2, id + " has canvas parts on both shoes")
		body.free()
	# A colourway passed straight to the builders wins over the palette; both shoes share the default materials.
	var mats: Dictionary = {}
	var foot: Node3D = Node3D.new()
	var shoe: Node3D = ShoeStyles.build_cupsole(foot, "Test", 0.12, mats, SkateShoe.preset(SkateShoe.DUNK))
	var upper: MeshInstance3D = shoe.find_child("UpperMesh", true, false)
	assert_true((upper.material_override as StandardMaterial3D).albedo_color.is_equal_approx(SkateShoe.preset(SkateShoe.DUNK)["shoe_canvas"]),
			"colourway colour reaches the cupsole")
	foot.free()


# --- the high top's collar vs the leg ----------------------------------------------------------------------------


func _wardrobe() -> Object:
	return (load("res://tests/unit/test_wardrobe.gd") as GDScript).new()


func _tri_mesh(meshes: Array[MeshInstance3D]) -> TriangleMesh:
	var faces: PackedVector3Array = PackedVector3Array()
	for mi: MeshInstance3D in meshes:
		faces.append_array(mi.global_transform * mi.mesh.get_faces())
	var tm: TriangleMesh = TriangleMesh.new()
	tm.create_from_faces(faces)
	return tm


## Skin vertices of the ankle region (and the sock's) between the ankle joint and the collar top must have the shaft
## outside them, on the ray from the bone axis, in this pose. Returns [checked, misses].
func _check_inside_shaft(meshes: Array[MeshInstance3D], shaft: TriangleMesh, bone: Node3D, lo: float, hi: float) -> Array:
	var checked: int = 0
	var misses: int = 0
	for mi: MeshInstance3D in meshes:
		var verts: PackedVector3Array = mi.mesh.get_faces()
		var to_bone: Transform3D = bone.global_transform.affine_inverse() * mi.global_transform
		for i: int in range(0, verts.size(), maxi(verts.size() / 60, 1)):
			var local: Vector3 = to_bone * verts[i]
			if local.y < lo or local.y > hi:
				continue
			var axis: Vector3 = bone.global_transform * Vector3(0.0, local.y, 0.0)
			var w: Vector3 = bone.global_transform * local
			var radial: float = (w - axis).length()
			if radial < 0.01:
				continue
			var dir: Vector3 = (w - axis) / radial
			checked += 1
			var hit: Dictionary = shaft.intersect_ray(axis, dir)
			if hit.is_empty() or ((hit["position"] as Vector3) - axis).length() < radial + 0.001:
				misses += 1
	return [checked, misses]


func test_high_top_collar_outside_leg_and_sock_in_every_pose() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for body_type: String in ["female", "male"]:
		var holder: Node3D = Node3D.new()
		tree.root.add_child(holder)
		var body: Node3D = _dress("shoes_high_top", body_type, {"socks": "socks_crew"})
		holder.add_child(body)
		var board: Node3D = Node3D.new()
		holder.add_child(board)
		var poser: SkaterPoser = SkaterPoser.new()
		poser.body = body
		poser.board = board
		poser.set_process(false)
		holder.add_child(poser)
		poser._capture_rest()
		var ay: float = -PlaceholderSkater.LOWER_LEG
		var helper: Object = _wardrobe()
		for p: Array in POSES:
			poser._apply(SkaterPoser.pose_for(p[1], p[2], p[3], 0.0, false, p[4], p[5]))
			helper.repose_skin(body)
			for side: String in ["Left", "Right"]:
				var lower: Node3D = body.find_child(side + "LowerLeg", true, false)
				var shaft_parts: Array[MeshInstance3D] = [lower.get_node(side + "ShoeShaftMesh") as MeshInstance3D]
				var shaft: TriangleMesh = _tri_mesh(shaft_parts)
				var inner: Array[MeshInstance3D] = []
				var all: Array[MeshInstance3D] = []
				_meshes(lower, all)
				for mi: MeshInstance3D in all:
					if mi.has_meta("region") and (str(mi.get_meta("region")).begins_with("ankle") or str(mi.get_meta("region")).begins_with("calf_low")):
						inner.append(mi)
					elif str(mi.name) == side + "SockMesh":
						inner.append(mi)
				assert_true(inner.size() >= 3, "%s %s found skin and sock parts" % [body_type, side])
				var res: Array = _check_inside_shaft(inner, shaft, lower, ay + 0.0, ay + 0.07)
				assert_true(int(res[0]) > 20, "%s %s %s sampled %d vertices" % [body_type, side, p[0], int(res[0])])
				assert_eq(int(res[1]), 0, "%s %s pose %s: leg or sock outside the high-top collar" % [body_type, side, p[0]])
		holder.free()


## The same cover check as the Wardrobe test: every vertex of the skin's ankle region has garment fabric just outside
## it (barefoot, so the shoe alone has to do the covering).
func test_high_top_covers_bare_ankle_in_every_pose() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for body_type: String in ["female", "male"]:
		var opts: Dictionary = BARE.duplicate()
		opts["body"] = body_type
		opts["shoes"] = "shoes_high_top"
		var holder: Node3D = Node3D.new()
		tree.root.add_child(holder)
		var body: Node3D = PlaceholderSkater.build_body({}, opts)
		holder.add_child(body)
		var board: Node3D = Node3D.new()
		holder.add_child(board)
		var poser: SkaterPoser = SkaterPoser.new()
		poser.body = body
		poser.board = board
		poser.set_process(false)
		holder.add_child(poser)
		poser._capture_rest()
		var helper: Object = _wardrobe()
		helper.repose_skin(body)
		var all: Array[MeshInstance3D] = []
		_meshes(body, all)
		var head: Node = body.find_child("HeadModel", true, false)
		var cloth: Array[MeshInstance3D] = []
		var skin: Array[MeshInstance3D] = []
		var ankle: Array[MeshInstance3D] = []
		for mi: MeshInstance3D in all:
			if mi.has_meta("region"):
				skin.append(mi)
				if str(mi.get_meta("region")).begins_with("ankle"):
					ankle.append(mi)
					assert_false(mi.visible, "high top hides " + str(mi.get_meta("region")))
			elif helper.is_cloth(mi, head):
				cloth.append(mi)
		assert_eq(ankle.size(), 2, body_type + " has two ankle meshes")
		for p: Array in POSES:
			poser._apply(SkaterPoser.pose_for(p[1], p[2], p[3], 0.0, false, p[4], p[5]))
			helper.repose_skin(body)
			var tm: TriangleMesh = _tri_mesh(cloth)
			var skin_tm: TriangleMesh = _tri_mesh(skin)
			var misses: int = 0
			var checked: int = 0
			for mi: MeshInstance3D in ankle:
				var res: Array = _check_region(mi, tm, skin_tm)
				checked += int(res[0])
				misses += int(res[1])
			assert_true(checked > 0, "%s sampled ankle skin" % body_type)
			assert_eq(misses, 0, "%s pose %s: ankle skin outside the shoe" % [body_type, p[0]])
		holder.free()


func _check_region(mi: MeshInstance3D, tm: TriangleMesh, skin_tm: TriangleMesh) -> Array:
	var bone: Node3D = mi.get_parent() as Node3D
	var verts: PackedVector3Array = mi.mesh.get_faces()
	var step: int = maxi(verts.size() / 40, 1)
	var to_bone: Transform3D = bone.global_transform.affine_inverse() * mi.global_transform
	var checked: int = 0
	var outside: int = 0
	for i: int in range(0, verts.size(), step):
		var local: Vector3 = to_bone * verts[i]
		var dir_local: Vector3 = local - Vector3(0.0, local.y, 0.0)
		if dir_local.length() < 0.01:
			continue
		var w: Vector3 = bone.global_transform * local
		var dir: Vector3 = (bone.global_transform.basis * dir_local).normalized()
		checked += 1
		var cloth_d: float = INF
		var side: Vector3 = bone.global_transform.basis.y.normalized()
		for turn: float in [0.0, 0.03, -0.03]:
			var hit: Dictionary = tm.intersect_ray(w - dir * 0.0005, dir.rotated(side, turn))
			if not hit.is_empty():
				cloth_d = minf(cloth_d, ((hit["position"] as Vector3) - w).length())
		if cloth_d <= 0.07:
			continue
		var over: Dictionary = skin_tm.intersect_ray(w + dir * 0.002, dir)
		var buried: bool = not over.is_empty() and (over["normal"] as Vector3).dot(dir) < 0.0
		if not buried:
			outside += 1
	return [checked, outside]
