extends TestCase
## HoudiniBody: the baked prepare results are current, every triangle has a region, the cuts are capped (no hole at
## the neck, wrists or ankles), the weights are clean, and a barefoot body stands on its soles.

const BAREFOOT: Dictionary = {"top": "none", "bottom": "none", "socks": "none", "shoes": "none", "accessories": []}


func test_bakes_are_current() -> void:
	for kind: String in ["female", "male"]:
		var path: String = str(HoudiniBody.BAKED[kind])
		assert_true(ResourceLoader.exists(path), "%s bake exists (tools/bake_houdini_body.sh)" % kind)
		if not ResourceLoader.exists(path):
			continue
		var mesh: ArrayMesh = load(path) as ArrayMesh
		assert_eq(int(mesh.get_meta("bake_version", 0)), HoudiniBody.BAKE_VERSION, kind + " bake format")
		assert_eq(str(mesh.get_meta("glb_md5", "")), FileAccess.get_md5(str(HoudiniBody.PATHS[kind])),
				kind + " bake made from this .glb (run tools/bake_houdini_body.sh)")
		assert_eq(str(mesh.get_meta("source_md5", "")), FileAccess.get_md5(HoudiniBody.SOURCE),
				kind + " bake made by this houdini_body.gd (run tools/bake_houdini_body.sh)")


func test_regions_and_caps() -> void:
	for kind: String in ["female", "male"]:
		var d: Dictionary = HoudiniBody.prepared(kind)
		var names: PackedStringArray = d["regions"]
		var tri_region: PackedInt32Array = d["tri_region"]
		var mesh: ArrayMesh = d["mesh"]
		var idx: PackedInt32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		assert_eq(tri_region.size(), idx.size() / 3, kind + ": one region per triangle")
		var count: Dictionary = {}
		for r: int in tri_region:
			count[names[r]] = int(count.get(names[r], 0)) + 1
		for r: String in ["head_cap", "hand_L_cap", "hand_R_cap", "foot_L_cap", "foot_R_cap"]:
			assert_true(int(count.get(r, 0)) >= 8, "%s: %s closes its cut" % [kind, r])
		for r: String in HoudiniBody.ALWAYS_HIDDEN:
			assert_true(count.has(r), "%s: %s region" % [kind, r])
		assert_eq(count.has("bust_L"), kind == "female", kind + " bust region")


func test_weights_are_clean() -> void:
	for kind: String in ["female", "male"]:
		var d: Dictionary = HoudiniBody.prepared(kind)
		var a: Array = (d["mesh"] as ArrayMesh).surface_get_arrays(0)
		var wts: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var bad: int = 0
		for v: int in wts.size() / 4:
			var s: float = wts[v * 4] + wts[v * 4 + 1] + wts[v * 4 + 2] + wts[v * 4 + 3]
			if absf(s - 1.0) > 0.001:
				bad += 1
		assert_eq(bad, 0, kind + ": every vertex's weights sum to 1")


func test_barefoot_soles_on_ground() -> void:
	for kind: String in ["female", "male"]:
		var opts: Dictionary = BAREFOOT.duplicate()
		opts["body"] = kind
		var body: Node3D = PlaceholderSkater.build_body({}, opts)
		var sb: SkinnedBody = body.find_children("*", "SkinnedBody", true, false)[0] as SkinnedBody
		assert_true(not sb.hidden_regions.has("foot_L"), kind + ": bare feet drawn")
		sb.sync_pose()
		var pv: PackedVector3Array = sb.posed_arrays()[0]
		var lo: float = INF
		for p: Vector3 in pv:
			lo = minf(lo, p.y)
		assert_near(lo, 0.0, 0.006, kind + ": soles on the ground")
		body.free()
