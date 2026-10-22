extends TestCase
## Cargo shorts, skate jeans, joggers and the tube, ankle and zig-zag socks: built (not stubs) on both bodies, the
## covered skin stays inside the garment in every pose of the wardrobe pose grid, no pure green, the palette keys are
## used, and long pants never cut into the shoe in the riding stance.


## These tests check the lofted garments and code parts on the Houdini body (the VRM body wears none of them), so
## bodies built without a "skin" option use it while a test of this file runs.
func _init() -> void:
	PlaceholderSkater.houdini_scopes += 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PlaceholderSkater.houdini_scopes -= 1

const BOTTOMS: Array = ["bottom_cargo_shorts", "bottom_skate_jeans", "bottom_joggers"]
const SOCKS: Array = ["socks_tube", "socks_ankle", "socks_striped"]
const LONG: Array = ["bottom_skate_jeans", "bottom_joggers"]
const SHOE_POSES: Array = [0]  ## indices into the pose grid: idle (the riding stance)


func _wardrobe() -> Object:
	return (load("res://tests/unit/test_wardrobe.gd") as GDScript).new()


func _opts(body_type: String, slot: String, id: String) -> Dictionary:
	var opts: Dictionary = {"hair": "none", "top": "none", "bottom": "none", "socks": "none", "shoes": "none", "accessories": []}
	opts["body"] = body_type
	opts[slot] = id
	return opts


func test_built_not_stubs() -> void:
	for id: String in BOTTOMS + SOCKS:
		assert_false(Wardrobe.stub_ids().has(("bottom:" if id.begins_with("bottom") else "socks:") + id), id + " is built")
	assert_eq(GarmentBottoms.STUBS.size(), 0)
	assert_eq(GarmentSocks.STUBS.size(), 0)


func test_builds_on_both_bodies_with_palette_keys_and_no_green() -> void:
	for body_type: String in ["female", "male"]:
		for id: String in BOTTOMS + SOCKS:
			var slot: String = "bottom" if id.begins_with("bottom") else "socks"
			var key: String = "bottom" if slot == "bottom" else "sock"
			var pal: Dictionary = {key: Color(0.4, 0.2, 0.7), key + "_trim" if slot == "bottom" else "sock_stripe": Color(0.9, 0.3, 0.2)}
			var body: Node3D = PlaceholderSkater.build_body(pal, _opts(body_type, slot, id))
			var found: Array[MeshInstance3D] = []
			_collect(body, found)
			var parts: int = 0
			var main_ok: bool = false
			for mi: MeshInstance3D in found:
				if mi.has_meta("region") or mi.get_meta("palette", "") == "skin" or not mi.has_meta("palette"):
					continue
				var k: String = str(mi.get_meta("palette"))
				if k == key:
					parts += 1
					main_ok = main_ok or (mi.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color(0.4, 0.2, 0.7))
				if k.begins_with("bottom") or k.begins_with("sock"):
					var c: Color = (mi.material_override as StandardMaterial3D).albedo_color
					assert_false(c.is_equal_approx(Color(0.0, 1.0, 0.0)), "%s %s %s is not pure green" % [body_type, id, mi.name])
			assert_true(parts > 0 and main_ok, "%s %s draws in the palette key %s" % [body_type, id, key])
			body.free()


func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c: Node in node.get_children():
		_collect(c, out)


func test_covered_skin_stays_inside_garment_in_every_pose() -> void:
	var helper: Object = _wardrobe()
	var poses: Array = helper.POSES
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for body_type: String in ["female", "male"]:
		for id: String in BOTTOMS + SOCKS:
			var slot: String = "bottom" if id.begins_with("bottom") else "socks"
			var covers: PackedStringArray = Wardrobe.covers(slot, id, body_type)
			assert_false(covers.is_empty(), id + " declares covers")
			var holder: Node3D = Node3D.new()
			tree.root.add_child(holder)
			var body: Node3D = PlaceholderSkater.build_body({}, _opts(body_type, slot, id))
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
			_collect(body, all)
			var head: Node = body.find_child("HeadModel", true, false)
			var skin: Array[MeshInstance3D] = []
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
	helper.free()


## True when the point lies inside the closed-ish shoe mesh: an upward ray crosses its surface an odd number of times.
func _inside(tm: TriangleMesh, p: Vector3) -> bool:
	var crossings: int = 0
	var o: Vector3 = p
	for i: int in 12:
		var hit: Dictionary = tm.intersect_ray(o, Vector3.UP)
		if hit.is_empty():
			break
		crossings += 1
		o = (hit["position"] as Vector3) + Vector3.UP * 0.0002
	return crossings % 2 == 1


func test_long_pants_clear_the_shoe() -> void:
	var helper: Object = _wardrobe()
	var poses: Array = helper.POSES
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for body_type: String in ["female", "male"]:
		for id: String in LONG:
			var opts: Dictionary = _opts(body_type, "bottom", id)
			opts["shoes"] = "shoes_low_vulc"
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
			var all: Array[MeshInstance3D] = []
			_collect(body, all)
			var shoe_parts: Array[MeshInstance3D] = []
			var pants: Array[MeshInstance3D] = []
			for mi: MeshInstance3D in all:
				var path: String = str(body.get_path_to(mi))
				if path.contains("ShoeMesh"):
					shoe_parts.append(mi)
				elif str(mi.name).begins_with("Left") or str(mi.name).begins_with("Right"):
					if (id == "bottom_skate_jeans" and str(mi.name).contains("Jeans")) or (id == "bottom_joggers" and str(mi.name).contains("Jogger")):
						if mi.get_parent().name.ends_with("LowerLeg"):
							pants.append(mi)
			assert_true(shoe_parts.size() > 0 and pants.size() > 0, "%s %s has shoe and lower-leg pants parts" % [body_type, id])
			for pi: int in SHOE_POSES:
				var p: Array = poses[pi]
				poser._apply(SkaterPoser.pose_for(p[1], p[2], p[3], 0.0, false, p[4], p[5]))
				var tm: TriangleMesh = helper._tri_mesh(shoe_parts)
				var bad: int = 0
				var total: int = 0
				for mi: MeshInstance3D in pants:
					var verts: PackedVector3Array = mi.mesh.get_faces()
					var tr: Transform3D = mi.global_transform
					for i: int in range(0, verts.size(), 3):
						var w: Vector3 = tr * verts[i]
						total += 1
						if _inside(tm, w):
							bad += 1
				assert_true(total > 0)
				assert_eq(bad, 0, "%s %s pose %s: %d pants vertices inside the shoe" % [body_type, id, p[0], bad])
			holder.free()
	helper.free()
