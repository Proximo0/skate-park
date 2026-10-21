extends TestCase
## Wardrobe: the registry and builder contract, the default outfits, body masking, and the cover check over the pose
## grid: in every pose, every skin region a garment declares it covers lies inside that garment (sampled vertices,
## each must have garment fabric just outside it along the ray from its bone's axis).

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


func _skin_regions(body: Node3D) -> Dictionary:
	var out: Dictionary = {}
	var found: Array[MeshInstance3D] = []
	_meshes(body, found)
	for mi: MeshInstance3D in found:
		if mi.has_meta("region"):
			var r: String = str(mi.get_meta("region"))
			if not out.has(r):
				out[r] = []
			(out[r] as Array).append(mi)
	return out


func test_registry_and_contract() -> void:
	var reg: Dictionary = Wardrobe.registry()
	for slot: String in Wardrobe.SLOTS:
		assert_true(reg.has(slot), "slot " + slot)
		for id: String in (reg[slot] as Dictionary).keys():
			var c: Callable = reg[slot][id]
			assert_true(c.is_valid(), "%s:%s callable" % [slot, id])
	var cat: PartCatalog = PartCatalog.load_default()
	for it: Dictionary in cat.all_items():
		var slot: String = str(it["slot"])
		if Wardrobe.SLOTS.has(slot):
			assert_true(Wardrobe.has_builder(slot, str(it["mesh_builder"])), "catalog %s has a builder" % it["mesh_builder"])
	for id: String in ["hair_ponytail", "hair_messy", "top_bikini", "top_surf_tee", "top_rash_guard", "bottom_bikini",
			"bottom_board_shorts", "socks_crew", "shoes_low_vulc", "acc_wristbands"]:
		assert_true(Wardrobe.built_ids().has(id), id + " is built")
	assert_true(Wardrobe.is_stub("top", "top_hoodie"), "hoodie is a stub")


func test_defaults_resolve() -> void:
	var f: Dictionary = Wardrobe.resolve({})
	assert_eq(f["body"], "female")
	assert_eq(f["hair"], "hair_ponytail")
	assert_eq(f["top"], "top_bikini")
	assert_eq(f["bottom"], "bottom_bikini")
	assert_eq(f["socks"], "socks_crew")
	assert_eq(f["shoes"], "shoes_low_vulc")
	var m: Dictionary = Wardrobe.resolve({"body": "male", "socks": "socks_tube"})
	assert_eq(m["hair"], "hair_messy")
	assert_eq(m["top"], "top_surf_tee")
	assert_eq(m["bottom"], "bottom_board_shorts")
	assert_eq(m["socks"], "socks_tube", "given keys win")


func test_bare_mannequin_has_only_skin() -> void:
	for body_type: String in ["female", "male"]:
		var opts: Dictionary = BARE.duplicate()
		opts["body"] = body_type
		var body: Node3D = PlaceholderSkater.build_body({}, opts)
		var found: Array[MeshInstance3D] = []
		_meshes(body, found)
		for mi: MeshInstance3D in found:
			var under_head: bool = body.find_child("HeadModel", true, false).is_ancestor_of(mi)
			assert_true(mi.visible, body_type + " bare: nothing hidden " + str(mi.name))
			if not under_head:
				assert_eq(str(mi.get_meta("palette")), "skin", body_type + " bare body part is skin: " + str(mi.name))
		body.free()


func test_masking_hides_covered_regions() -> void:
	var body: Node3D = PlaceholderSkater.build_body({}, {"body": "male"})
	var regions: Dictionary = _skin_regions(body)
	var covered: PackedStringArray = Wardrobe.covers("top", "top_surf_tee", "male") + Wardrobe.covers("bottom", "bottom_board_shorts", "male") \
			+ Wardrobe.covers("socks", "socks_crew", "male")
	assert_true(covered.has("waist") and covered.has("pelvis") and covered.has("calf_low_L"), "tee, shorts and socks cover")
	for r: String in regions.keys():
		for mi: MeshInstance3D in regions[r]:
			assert_eq(mi.visible, not covered.has(r), "region %s visible only when uncovered" % r)
	assert_true(not covered.has("head") and not covered.has("hand_L"), "head and hands stay")
	body.free()


func test_every_region_has_a_mesh() -> void:
	for body_type: String in ["female", "male"]:
		var body: Node3D = PlaceholderSkater.build_body({}, {"body": body_type, "top": "none", "bottom": "none"})
		var regions: Dictionary = _skin_regions(body)
		for r: String in AnimeOutfit.REGIONS:
			if r == "bust":
				assert_eq(regions.has("bust_L"), body_type == "female", body_type + " bust region")
				continue
			var limb: bool = not regions.has(r)
			assert_true(regions.has(r) or (limb and regions.has(r + "_L") and regions.has(r + "_R")), body_type + " region " + r)
		body.free()


## Garments to check per body: [slot, id].
func _garments(body_type: String) -> Array:
	var out: Array = [["top", "top_surf_tee"], ["top", "top_rash_guard"], ["bottom", "bottom_board_shorts"], ["socks", "socks_crew"]]
	if body_type == "female":
		out.append_array([["top", "top_bikini"], ["bottom", "bottom_bikini"]])
	return out


func test_covered_skin_stays_inside_garment_in_every_pose() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for body_type: String in ["female", "male"]:
		for g: Array in _garments(body_type):
			var slot: String = g[0]
			var id: String = g[1]
			var covers: PackedStringArray = Wardrobe.covers(slot, id, body_type)
			if covers.is_empty():
				continue
			var opts: Dictionary = BARE.duplicate()
			opts["body"] = body_type
			if slot == "accessory":
				opts["accessories"] = [id]
			else:
				opts[slot] = id
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
			var regions: Dictionary = _skin_regions(body)
			var cloth: Array[MeshInstance3D] = []
			var all: Array[MeshInstance3D] = []
			_meshes(body, all)
			var head: Node = body.find_child("HeadModel", true, false)
			for mi: MeshInstance3D in all:
				if not mi.has_meta("region") and not head.is_ancestor_of(mi):
					cloth.append(mi)
			var skin: Array[MeshInstance3D] = []
			for r: String in regions.keys():
				for mi: MeshInstance3D in regions[r]:
					skin.append(mi)
			for p: Array in POSES:
				poser._apply(SkaterPoser.pose_for(p[1], p[2], p[3], 0.0, false, p[4], p[5]))
				var tm: TriangleMesh = _tri_mesh(cloth)
				var skin_tm: TriangleMesh = _tri_mesh(skin)
				var misses: int = 0
				var checked: int = 0
				var first: String = ""
				for r: String in covers:
					assert_true(regions.has(r), "%s %s covers an existing region %s" % [body_type, id, r])
					for mi: MeshInstance3D in regions.get(r, []):
						assert_false(mi.visible, "%s %s hides %s" % [body_type, id, r])
						var res: Array = _check_region(mi, tm, skin_tm)
						checked += int(res[0])
						misses += int(res[1])
						if int(res[1]) > 0 and first == "":
							first = r
				assert_true(checked > 0, "%s %s sampled skin" % [body_type, id])
				assert_eq(misses, 0, "%s %s pose %s: skin outside the garment (first region %s)" % [body_type, id, p[0], first])
			holder.free()


func _tri_mesh(meshes: Array[MeshInstance3D]) -> TriangleMesh:
	var faces: PackedVector3Array = PackedVector3Array()
	for mi: MeshInstance3D in meshes:
		faces.append_array(mi.global_transform * mi.mesh.get_faces())
	var tm: TriangleMesh = TriangleMesh.new()
	tm.create_from_faces(faces)
	return tm


## Samples a region mesh's vertices; returns [checked, outside]. A vertex is inside when the ray from it outward (away
## from its bone's axis) meets the garment within 7 cm, or first meets skin from inside: it is buried
## in (e.g. the narrowed top of the waist inside the chest; that outer part is checked in its own right when covered).
func _check_region(mi: MeshInstance3D, tm: TriangleMesh, skin_tm: TriangleMesh) -> Array:
	var bone: Node3D = mi.get_parent() as Node3D
	if str(bone.name).begins_with("BodySway_"):
		bone = bone.get_parent() as Node3D
	var verts: PackedVector3Array = mi.mesh.get_faces()
	var step: int = maxi(verts.size() / 40, 1)
	var to_bone: Transform3D = bone.global_transform.affine_inverse() * mi.global_transform
	var checked: int = 0
	var outside: int = 0
	for i: int in range(0, verts.size(), step):
		var local: Vector3 = to_bone * verts[i]
		var axis: Vector3 = Vector3(0.0, local.y, 0.0)
		var dir_local: Vector3 = local - axis
		if dir_local.length() < 0.01:
			continue
		var w: Vector3 = bone.global_transform * local
		var dir: Vector3 = (bone.global_transform.basis * dir_local).normalized()
		checked += 1
		# intersect_ray, not intersect_segment: in 4.7 the segment query misses hits on short segments. A ray that runs
		# exactly through a garment edge can slip between its triangles, so two slightly turned rays get a say too.
		var cloth_d: float = INF
		var side: Vector3 = bone.global_transform.basis.y.normalized()
		for turn: float in [0.0, 0.03, -0.03]:
			var hit: Dictionary = tm.intersect_ray(w - dir * 0.0005, dir.rotated(side, turn))
			if not hit.is_empty():
				cloth_d = minf(cloth_d, ((hit["position"] as Vector3) - w).length())
		if cloth_d <= 0.07:
			continue
		# Buried: the first skin met going out is the inside of another skin part (TriangleMesh normals of these
		# clockwise-wound meshes face inward, so an exit hit has normal . dir < 0).
		var over: Dictionary = skin_tm.intersect_ray(w + dir * 0.002, dir)
		var buried: bool = not over.is_empty() and (over["normal"] as Vector3).dot(dir) < 0.0
		if not buried:
			outside += 1
	return [checked, outside]


func test_male_body_shape() -> void:
	var m: Node3D = PlaceholderSkater.build_body({}, {"body": "male"})
	var f: Node3D = PlaceholderSkater.build_body()
	assert_true(m.find_child("BodySway_BustL", true, false) == null, "no bust pivots on the male body")
	assert_true(f.find_child("BodySway_BustL", true, false) != null, "female bust pivots")
	for j: String in SkaterPoser.JOINTS:
		var mj: Node3D = m.find_child(j, true, false)
		var fj: Node3D = f.find_child(j, true, false)
		assert_true(mj != null, "male joint " + j)
		assert_true(mj.transform.is_equal_approx(fj.transform), "same skeleton at " + j)
	var chest_m: Array = SkaterParts.section_at(SkaterParts.smooth_sections(AnimeOutfit.CHEST_M, 3), 1.245)
	var chest_f: Array = SkaterParts.section_at(SkaterParts.smooth_sections(AnimeOutfit.CHEST, 3), 1.245)
	var hip_m: Array = SkaterParts.section_at(SkaterParts.smooth_sections(AnimeOutfit.PELVIS_M, 3), 0.835)
	var hip_f: Array = SkaterParts.section_at(SkaterParts.smooth_sections(AnimeOutfit.PELVIS, 3), 0.835)
	assert_true(float(chest_m[1]) > float(chest_f[1]) + 0.02, "broader shoulders")
	assert_true(float(chest_m[1]) > float(hip_m[1]), "shoulders wider than the hips")
	assert_true(float(hip_m[1]) < float(hip_f[1]), "narrower hips")
	assert_true(m.find_child("HairSway_SideL", true, false) != null and m.find_child("HairSway_Fringe", true, false) != null,
			"messy hair sway pivots")
	assert_true(m.find_child("SurfTeeChestMesh", true, false) != null and m.find_child("LeftBoardShortsLegMesh", true, false) != null,
			"surf tee and board shorts")
	m.free()
	f.free()


func test_hair_styles_build_on_both_heads() -> void:
	for body_type: String in ["female", "male"]:
		for id: String in ["hair_ponytail", "hair_messy"]:
			var body: Node3D = PlaceholderSkater.build_body({}, {"body": body_type, "hair": id})
			var model: Node3D = body.find_child("HeadModel", true, false)
			assert_true(model.find_child("HairCapMesh", true, false) != null, "%s %s has a cap" % [body_type, id])
			for n: Node in model.find_children("HairSway_*", "Node3D", true, false):
				assert_true((n as Node3D).basis.is_equal_approx(Basis.IDENTITY), "%s starts at identity" % n.name)
			body.free()


func test_stub_falls_back_to_reference_garment() -> void:
	var body: Node3D = PlaceholderSkater.build_body({}, {"body": "male", "top": "top_hoodie", "bottom": "bottom_joggers"})
	assert_true(body.find_child("SurfTeeChestMesh", true, false) != null, "stub top draws the reference tee")
	assert_true(body.find_child("BoardShortsSeatMesh", true, false) != null, "stub bottom draws the reference shorts")
	body.free()


func test_builder_maps_loadout() -> void:
	var l: SkaterLoadout = SkaterLoadout.default_male()
	var o: Dictionary = SkaterBuilder.body_options(l)
	assert_eq(o["body"], "male")
	assert_eq(o["top"], "top_surf_tee")
	var p: Dictionary = SkaterBuilder.body_palette(l)
	for key: String in ["hair_base", "hair_shadow", "head_brow", "head_iris_mid", "shoe_canvas", "shoe_stripe", "top", "top_trim",
			"bottom", "sock"]:
		assert_true(p.has(key), "palette maps " + key)
	var shoe: Color = PartCatalog.load_default().color_of(l.shoes_id, l.shoes_color)
	assert_true((p["shoe_canvas"] as Color).is_equal_approx(shoe), "shoe canvas from the loadout colour")
	var body: Node3D = SkaterBuilder.build_body(l)
	var upper: MeshInstance3D = body.find_child("UpperMesh", true, false)
	assert_true((upper.material_override as StandardMaterial3D).albedo_color.is_equal_approx(shoe), "shoe colour reaches the shoe")
	var cap: MeshInstance3D = body.find_child("HairCapMesh", true, false)
	assert_true((cap.material_override as StandardMaterial3D).albedo_color.is_equal_approx(p["hair_mid"]), "hair colour reaches the hair")
	body.free()
