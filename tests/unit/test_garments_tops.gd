extends TestCase
## Crop tank, hoodie and open flannel: built (not stubs) on both bodies, the covered skin stays inside the garment in
## every pose of the wardrobe pose grid, the palette keys are used, no pure green, and each garment has its parts.


## These tests check the lofted garments and code parts on the Houdini body (the VRM body wears none of them), so
## bodies built without a "skin" option use it while a test of this file runs.
func _init() -> void:
	PlaceholderSkater.houdini_scopes += 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PlaceholderSkater.houdini_scopes -= 1

const TOPS: Array = ["top_crop_tank", "top_hoodie", "top_flannel"]


func _wardrobe() -> Object:
	return (load("res://tests/unit/test_wardrobe.gd") as GDScript).new()


func _opts(body_type: String, id: String) -> Dictionary:
	return {"body": body_type, "hair": "none", "top": id, "bottom": "none", "socks": "none", "shoes": "none", "accessories": []}


func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c: Node in node.get_children():
		_collect(c, out)


func test_built_not_stubs() -> void:
	assert_eq(GarmentTops.STUBS.size(), 0, "no top stubs left")
	for id: String in TOPS:
		assert_true(Wardrobe.has_builder("top", id), id + " is registered")
		assert_false(Wardrobe.is_stub("top", id), id + " is built")
		assert_true(Wardrobe.built_ids().has(id), id + " is in built_ids")
		assert_true(PartCatalog.load_default().has_item(id), id + " is in the catalog")
		assert_eq(PartCatalog.load_default().item(id)["mesh_builder"], id, id + " catalog builder")


func test_covers_declared_for_both_bodies() -> void:
	for body_type: String in ["female", "male"]:
		for id: String in TOPS:
			var c: PackedStringArray = Wardrobe.covers("top", id, body_type)
			assert_true(c.has("chest"), "%s %s covers the chest" % [body_type, id])
			assert_eq(c.has("bust_L"), body_type == "female", "%s %s covers the bust only on the female body" % [body_type, id])
	assert_true(Wardrobe.covers("top", "top_hoodie", "male").has("forearm_L"), "hoodie sleeves reach the wrists")
	assert_false(Wardrobe.covers("top", "top_crop_tank", "female").has("shoulder_L"), "tank leaves the shoulders bare")
	assert_false(Wardrobe.covers("top", "top_flannel", "male").has("forearm_L"), "flannel sleeves are rolled up")


func test_parts_palette_keys_and_no_green() -> void:
	var expected: Dictionary = {
		"top_crop_tank": ["CropTankMesh", "CropTankHemMesh", "CropTankNeckMesh", "LeftCropTankStrapMesh", "RightCropTankStrapMesh"],
		"top_hoodie": ["HoodieChestMesh", "HoodieHoodMesh", "HoodiePocketMesh", "HoodieLeftStringMesh", "HoodieRightStringMesh",
				"LeftHoodieSleeveMesh", "RightHoodieForearmSleeveMesh", "LeftHoodieCuffMesh", "HoodieHemMesh"],
		"top_flannel": ["FlannelChestMesh", "FlannelCollarMesh", "LeftFlannelSleeveMesh", "RightFlannelCuffMesh", "FlannelTeeChestMesh"],
	}
	for body_type: String in ["female", "male"]:
		for id: String in TOPS:
			var pal: Dictionary = {"top": Color(0.4, 0.2, 0.7), "top_trim": Color(0.9, 0.3, 0.2)}
			var body: Node3D = PlaceholderSkater.build_body(pal, _opts(body_type, id))
			for part: String in expected[id]:
				assert_true(body.find_child(part, true, false) != null, "%s %s has %s" % [body_type, id, part])
			var found: Array[MeshInstance3D] = []
			_collect(body, found)
			var main_ok: bool = false
			for mi: MeshInstance3D in found:
				if mi.has_meta("region") or not mi.has_meta("palette"):
					continue
				var k: String = str(mi.get_meta("palette"))
				if not k.begins_with("top"):
					continue
				var m: StandardMaterial3D = mi.material_override as StandardMaterial3D
				assert_false(m.albedo_color.is_equal_approx(Color(0.0, 1.0, 0.0)), "%s %s %s is not pure green" % [body_type, id, mi.name])
				if k == "top":
					main_ok = main_ok or m.albedo_color.is_equal_approx(Color(0.4, 0.2, 0.7))
				if mi.mesh.get_surface_count() > 0 and mi.mesh.get_faces().size() > 0:
					assert_true(mi.mesh.get_aabb().size.length() > 0.0, "%s %s %s is not empty" % [body_type, id, mi.name])
			assert_true(main_ok or id == "top_flannel", "%s %s draws in the main colour" % [body_type, id])
			if id == "top_flannel":
				var plaid: MeshInstance3D = body.find_child("FlannelChestMesh", true, false)
				assert_eq(str(plaid.get_meta("palette")), "top_plaid", "flannel panels use the plaid material")
				var mat: StandardMaterial3D = plaid.material_override as StandardMaterial3D
				assert_true(mat.albedo_texture != null, "plaid has a generated texture")
				var arrays: Array = plaid.mesh.surface_get_arrays(0)
				assert_true((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() > 0, "plaid panels carry UVs")
			body.free()


func test_hoodie_has_pocket_hood_and_strings_in_place() -> void:
	for body_type: String in ["female", "male"]:
		var body: Node3D = PlaceholderSkater.build_body({}, _opts(body_type, "top_hoodie"))
		var chest: Node3D = body.find_child("Chest", true, false)
		var hood: MeshInstance3D = body.find_child("HoodieHoodMesh", true, false)
		var hood_box: AABB = hood.mesh.get_aabb()
		assert_true(hood.get_parent() == chest, "hood hangs on the chest")
		assert_true(hood_box.get_center().z > 0.0, "%s hood lies on the back (+Z)" % body_type)
		var pocket: MeshInstance3D = body.find_child("HoodiePocketMesh", true, false)
		assert_true(pocket.mesh.get_aabb().get_center().z < 0.0, "%s kangaroo pocket is on the front (-Z)" % body_type)
		for side: String in ["Left", "Right"]:
			var str_mesh: MeshInstance3D = body.find_child("Hoodie%sStringMesh" % side, true, false)
			assert_true(str_mesh.mesh.get_aabb().get_center().z < 0.0, "%s %s drawstring hangs on the front" % [body_type, side])
			var sleeve: MeshInstance3D = body.find_child("%sHoodieSleeveMesh" % side, true, false)
			assert_true(sleeve.get_parent() == body.find_child(side + "UpperArm", true, false), "%s sleeve follows the upper arm" % side)
			var fore: MeshInstance3D = body.find_child("%sHoodieForearmSleeveMesh" % side, true, false)
			assert_true(fore.get_parent() == body.find_child(side + "LowerArm", true, false), "%s sleeve follows the forearm" % side)
		body.free()


func test_flannel_front_is_open_and_tee_shows() -> void:
	for body_type: String in ["female", "male"]:
		var body: Node3D = PlaceholderSkater.build_body({}, _opts(body_type, "top_flannel"))
		var panel: MeshInstance3D = body.find_child("FlannelChestMesh", true, false)
		var verts: PackedVector3Array = panel.mesh.get_faces()
		var near_centre: int = 0
		for v: Vector3 in verts:
			if v.z < -0.03 and absf(v.x) < 0.02:
				near_centre += 1
		assert_eq(near_centre, 0, "%s flannel front has no fabric on the centre line" % body_type)
		var tee: MeshInstance3D = body.find_child("FlannelTeeChestMesh", true, false)
		assert_eq(str(tee.get_meta("palette")), "top_tee", "tee under the flannel uses its own key")
		var tee_front: int = 0
		for v: Vector3 in tee.mesh.get_faces():
			if v.z < -0.03 and absf(v.x) < 0.02:
				tee_front += 1
		assert_true(tee_front > 0, "%s tee fills the gap" % body_type)
		body.free()


func test_covered_skin_stays_inside_garment_in_every_pose() -> void:
	var helper: Object = _wardrobe()
	var poses: Array = helper.POSES
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for body_type: String in ["female", "male"]:
		for id: String in TOPS:
			var covers: PackedStringArray = Wardrobe.covers("top", id, body_type)
			assert_false(covers.is_empty(), id + " declares covers")
			var holder: Node3D = Node3D.new()
			tree.root.add_child(holder)
			var body: Node3D = PlaceholderSkater.build_body({}, _opts(body_type, id))
			holder.add_child(body)
			var board: Node3D = Node3D.new()
			holder.add_child(board)
			var poser: SkaterPoser = SkaterPoser.new()
			poser.body = body
			poser.board = board
			poser.set_process(false)
			holder.add_child(poser)
			poser._capture_rest()
			helper.repose_skin(body)
			var regions: Dictionary = helper._skin_regions(body)
			var cloth: Array[MeshInstance3D] = []
			var all: Array[MeshInstance3D] = []
			var skin: Array[MeshInstance3D] = []
			_collect(body, all)
			var head: Node = body.find_child("HeadModel", true, false)
			for mi: MeshInstance3D in all:
				if mi.has_meta("region"):
					skin.append(mi)
				elif helper.is_cloth(mi, head):
					cloth.append(mi)
			for p: Array in poses:
				poser._apply(SkaterPoser.pose_for(p[1], p[2], p[3], 0.0, false, p[4], p[5]))
				helper.repose_skin(body)
				var tm: TriangleMesh = helper._tri_mesh(cloth)
				var skin_tm: TriangleMesh = helper._tri_mesh(skin)
				var misses: int = 0
				var checked: int = 0
				var first: String = ""
				for r: String in covers:
					assert_true(regions.has(r) or helper.fused_away(body, r), "%s %s covers an existing region %s" % [body_type, id, r])
					for mi: MeshInstance3D in regions.get(r, []):
						assert_false(mi.visible, "%s %s hides %s" % [body_type, id, r])
						var res: Array = helper._check_region(mi, tm, skin_tm)
						checked += int(res[0])
						misses += int(res[1])
						if int(res[1]) > 0 and first == "":
							first = r
				assert_true(checked > 0 or helper._all_fused(body, covers), "%s %s sampled skin" % [body_type, id])
				assert_eq(misses, 0, "%s %s pose %s: skin outside the garment (first region %s)" % [body_type, id, p[0], first])
			holder.free()
