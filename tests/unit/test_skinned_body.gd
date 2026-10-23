extends TestCase
## SkinnedBody and the Blender base bodies (assets/characters/base_body_<type>.glb): every SkaterPoser joint is a
## bone with the same parent, bone heads sit on the code rig's model-pose joints, the body stands 1.61 m (crown
## marker) with its soles on the ground, the triangle budget holds, and region masking drops triangles.


## These tests check the Houdini body itself, so bodies built without a "skin" option use it while a test of this
## file runs (the default skin is the VRM body).
func _init() -> void:
	PlaceholderSkater.houdini_scopes += 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PlaceholderSkater.houdini_scopes -= 1


func _skeleton(body_type: String) -> Array:
	var scene: PackedScene = load(str(SkinnedBody.PATHS[body_type])) as PackedScene
	assert_true(scene != null, "%s glb loads" % body_type)
	if scene == null:
		return []
	var inst: Node3D = scene.instantiate() as Node3D
	return [inst, SkinnedBody.find_skeleton(inst)]


func test_bones_match_joints() -> void:
	for body_type: String in ["female", "male"]:
		var r: Array = _skeleton(body_type)
		if r.is_empty():
			continue
		var skel: Skeleton3D = r[1]
		assert_true(skel != null, "%s has a Skeleton3D" % body_type)
		if skel == null:
			(r[0] as Node).free()
			continue
		var body: Node3D = PlaceholderSkater.build_body({}, {"body": body_type})
		var neutral: Dictionary = SkinnedBody.neutral_globals(body)
		for j: String in SkaterPoser.JOINTS:
			var b: int = skel.find_bone(j)
			assert_true(b >= 0, "%s bone %s" % [body_type, j])
			if b < 0:
				continue
			var parent: Node = body.find_child(j, true, false).get_parent()
			var want: String = "" if parent == body else str(parent.name)
			var got: String = "" if skel.get_bone_parent(b) < 0 else skel.get_bone_name(skel.get_bone_parent(b))
			assert_eq(got, want, "%s parent of %s" % [body_type, j])
			var head: Vector3 = skel.get_bone_global_rest(b).origin
			assert_true(head.distance_to((neutral[j] as Transform3D).origin) < 0.002, "%s %s head on the joint" % [body_type, j])
		if body_type == "female":
			for bust: String in ["BustL", "BustR"]:
				var b: int = skel.find_bone(bust)
				assert_true(b >= 0, "bone " + bust)
				if b >= 0:
					var pivot: Vector3 = (neutral[SkinnedBody.EXTRA_BONES[bust]] as Transform3D).origin
					assert_true(skel.get_bone_global_rest(b).origin.distance_to(pivot) < 0.002, bust + " at its pivot")
		body.free()
		(r[0] as Node).free()


func test_height_and_budget() -> void:
	for body_type: String in ["female", "male"]:
		var r: Array = _skeleton(body_type)
		if r.is_empty() or r[1] == null:
			continue
		var skel: Skeleton3D = r[1]
		var top: int = skel.find_bone("HeadTop")
		assert_true(top >= 0, "HeadTop marker")
		if top >= 0:
			assert_near(skel.get_bone_global_rest(top).origin.y, 1.61, 0.02, "%s stands 1.61 m" % body_type)
		var mi: MeshInstance3D = null
		for c: Node in skel.get_children():
			if c is MeshInstance3D:
				mi = c
		assert_true(mi != null and mi.skin != null, "%s skinned mesh under the skeleton" % body_type)
		if mi != null:
			var box: AABB = mi.mesh.get_aabb()
			assert_near(box.position.y, 0.0, 0.02, "%s soles on the ground" % body_type)
			var tris: int = 0
			for s: int in mi.mesh.get_surface_count():
				tris += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			assert_true(tris >= 8000 and tris <= 15000, "%s triangle budget (%d)" % [body_type, tris])
		(r[0] as Node).free()


func test_region_masking() -> void:
	var body: Node3D = PlaceholderSkater.build_body({}, {"body": "female"})
	var sb: SkinnedBody = SkinnedBody.attach(body, "female")
	assert_true(sb != null, "attach")
	if sb == null:
		body.free()
		return
	var regions: PackedInt32Array = sb.triangle_regions()
	var seen: Dictionary = {}
	for r: int in regions:
		seen[r] = true
	for i: int in SkinnedBody.REGIONS.size():
		assert_true(seen.has(i), "region %s has triangles" % SkinnedBody.REGIONS[i])
	assert_eq(seen.size(), SkinnedBody.REGIONS.size(), "no stray region ids")
	var full: int = regions.size()
	sb.set_hidden_regions(PackedStringArray(["pelvis", "glutes"]))
	var shown: int = (sb.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var hidden: int = 0
	for r: int in regions:
		if r == SkinnedBody.REGIONS.find("pelvis") or r == SkinnedBody.REGIONS.find("glutes"):
			hidden += 1
	assert_eq(shown, full - hidden, "hidden regions drop exactly their triangles")
	sb.set_hidden_regions(PackedStringArray())
	assert_eq((sb.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, full, "restored")
	body.free()
