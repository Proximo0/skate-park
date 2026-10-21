class_name HoudiniBody
extends RefCounted
## The Houdini-made seamless skinned base body (assets/characters/houdini/base_body_<type>.glb, built by
## tools/houdini/base_body.py on the houdini-assets branch) prepared for the game: docs/houdini_pipeline.md.
##
## The .glb holds one mesh ("body", about 10k triangles, smooth normals, no UVs) skinned to the 17 SkaterPoser.JOINTS
## plus BustL/BustR (female) and a HeadTop marker, bound in the model pose (SkinnedBody.neutral_globals). It has no
## garment regions, automatic (biharmonic) weights, a placeholder head and thin paddle hands. prepared() turns it into
## the mesh the game draws (baked by tools/bake_houdini_body.sh into BAKED; processed at load when a bake is missing):
## 1. Cuts: planes through the neck under the jaw (the code head, AnimeHead, sits on top), across each wrist at the
##    Hand joint (the code hands, PlaceholderSkater._build_arm, cover the cap) and across each ankle; then the region
##    borders a garment edge can follow (_region_cuts), so a hidden region ends on a clean line, not a zig-zag of long
##    PolyReduce triangles. The plane cuts get small rounded caps ("<region>_cap", drawn only while <region> is
##    hidden), so a hidden head, hand or foot never leaves a hole.
## 2. Regions: every triangle gets one body region in the code skin's vocabulary (AnimeOutfit.REGIONS with _L/_R),
##    so the garments' covers() lists apply unchanged: the code loft (torso, thigh, calf, upper arm with its deltoid,
##    forearm) whose surface its centre lies closest to, then that loft's region by height (TORSO_CUTS) or bone
##    fraction (AnimeOutfit.LIMB_REGIONS); bands round the elbows and knees; the female cup patch is "bust_L/R".
## 3. Weights (_region_weights): each region moves like the code-skin piece it replaces: torso bands by height
##    (TORSO_WEIGHTS), limbs on their home joint with the neighbour's weight fading out from the shared joint (BLEND),
##    the bust rigid on BustL/R, no hand weight at the wrists or foot weight at the ankles.
## 4. Fit (_fit): each region is pulled in to the code-skin shapes of its part (torso, that arm, that leg), less
##    SHRINK / BLEND_SHRINK / ARMPIT_SHRINK where blended vertices swing out as joints bend, so garments lofted from
##    the code skin's sections stay outside it in every pose; the female bust is first conformed to the code bust.
## 5. Hips and knees (_piece_joints): split along the line between the code pieces (pelvis and thigh, thigh and shin)
##    and made rigid on the piece each side lies in, like the garment pieces over them.

const PATHS: Dictionary = {
	"female": "res://assets/characters/houdini/base_body_female.glb",
	"male": "res://assets/characters/houdini/base_body_male.glb",
}
## Regions of the Houdini mesh never drawn: the placeholder head (AnimeHead draws the head) and the paddle hands
## (PlaceholderSkater draws the hands).
const ALWAYS_HIDDEN: PackedStringArray = ["head", "hand_L", "hand_R"]
## Code-skin regions with no surface on the fused body: the thigh tops, buried in the pelvis (garments may still list
## them for the code skin).
const FUSED: PackedStringArray = ["thigh_top"]
## Neck cut, body-space y in the model pose: under the jaw, inside the code head's neck socket.
const HEAD_CUT_Y: float = 1.43
## Wrist cut: distance past the Hand joint along the hand bone (the code palm covers the cap).
const WRIST_CUT: float = 0.004
## Ankle cut, body-space y in the model pose (the shoe collar covers it).
const FOOT_CUT_Y: float = 0.075
## Torso regions by body-space y in the model pose: [region, top y]. One region per height on the single fused torso
## (the code skin's three overlapping lofts split the same heights between Hips, Spine and Chest); the garments that
## cover each code region cover the one used here. Above the last: "neck".
## The heights also set each band's home joint: the code loft that is outermost there (pelvis on Hips up to 0.975 m,
## waist on Spine to 1.005 m, ribcage on Chest above), which is the joint the garment piece over it hangs on.
const TORSO_CUTS: Array = [
	["pelvis", 0.905], ["hip_band", 0.935], ["waist_low", 0.965], ["belly", 0.975], ["waist", 1.005], ["under_bust", 1.075],
	["chest", 1.25], ["chest_upper", 1.31], ["neck_base", 1.36],
]
## Torso weights by body-space height: [y, Hips, Spine, Chest, Neck] rows, linear between (a soft mannequin spine:
## each band follows the joint whose code loft and garment piece it sits under, blended across the band borders).
const TORSO_WEIGHTS: Array = [
	[0.92, 1.0, 0.0, 0.0, 0.0], [0.99, 0.0, 1.0, 0.0, 0.0], [1.0, 0.0, 1.0, 0.0, 0.0], [1.03, 0.0, 0.0, 1.0, 0.0],
	[1.31, 0.0, 0.0, 1.0, 0.0], [1.37, 0.0, 0.0, 0.0, 1.0],
]
## Ankle-band points under the ankle joint lying this far outside the code shin belong to the foot.
const FOOT_FUSE: float = 0.003
## The bust region stops this much (bust-field units: inner u, outer u, bottom v) further inside the bikini cup than the
## code skin's cup patch (AnimeOutfit.CUP_SKIN_INSET): the skin there stays drawn under the cup's edge, where the
## steep cleavage wall and the under-bust crease (where the surface turns down, along the cup) would otherwise sit
## right at it.
const CUP_INSET: Vector3 = Vector3(0.1, 0.03, 0.3)
## Radius of the elbow and knee regions round their joints (the code skin's elbow and knee spheres).
const ELBOW_R: float = 0.034
const KNEE_R: float = 0.05
## How far (metres) a loft region may lie outside the code skin before it is pulled in.
const FIT_TOLERANCE: float = 0.0
## Extra pull-in (m) per region, below the code skin: where the bent elbow or a raised thigh swings blended vertices
## out past the tight garments the code skin's rigid pieces stay inside (the rash guard sleeve, the hip band under hems).
## Extra pull-in (m) of a vertex split evenly between two bones (scaled down as one bone takes over).
const BLEND_SHRINK: float = 0.004
## Pull-in (m) of the seam vertices between two PIECE_JOINTS pieces (_piece_joints).
const SEAM_SHRINK: float = 0.002
## Half width (m) of the crotch strip where the seam is pulled in twice as far (between the legs, out of sight).
const CROTCH_HALF: float = 0.03
## Extra pull-in (m) of the torso's border with the upper arms (_armpit).
const ARMPIT_SHRINK: float = 0.004
const SHRINK: Dictionary = {"upper_arm_low": 0.003, "elbow": 0.003, "hip_band": 0.003}
## The home joint of each region (limb regions without the side): the joint whose code-skin loft it replaces. Tools and
## tests use it as the region's bone (its axis is the loft's axis).
const HOME: Dictionary = {
	"pelvis": "Hips", "hip_band": "Hips", "belly": "Hips", "waist_low": "Hips", "waist": "Spine", "under_bust": "Chest",
	"chest": "Chest", "chest_upper": "Chest", "neck_base": "Chest", "bust": "BodySway_Bust", "neck": "Neck", "head": "Head",
	"shoulder": "UpperArm", "upper_arm": "UpperArm", "upper_arm_low": "UpperArm", "elbow": "LowerArm", "forearm": "LowerArm",
	"wrist": "LowerArm", "hand": "Hand", "thigh_top": "UpperLeg", "thigh_upper": "UpperLeg", "thigh_lower": "UpperLeg",
	"knee": "LowerLeg", "calf": "LowerLeg", "calf_low": "LowerLeg", "ankle": "LowerLeg", "foot": "Foot",
}

## Baked prepare results (tools/bake_houdini_body.sh): the prepared ArrayMesh with metas "regions", "tri_region",
## "bake_version", "glb_md5" (the .glb it came from) and "source_md5" (this script, checked by the tests).
const BAKED: Dictionary = {
	"female": "res://assets/characters/houdini/base_body_female_prepared.res",
	"male": "res://assets/characters/houdini/base_body_male_prepared.res",
}
## Bump to make every bake stale (the format of the baked metas changed).
const BAKE_VERSION: int = 1
const SOURCE: String = "res://game/skater/houdini_body.gd"

static var _cache: Dictionary = {}
## Tools only: false skips the fit step (to measure the raw Houdini surface against the code skin).
static var fit_enabled: bool = true


## The prepared body of a type: {"mesh": ArrayMesh (one surface, skinned like the .glb), "regions": PackedStringArray
## (region names), "tri_region": PackedInt32Array (region index per triangle)}. Empty when the .glb is missing.
## From the bake when it is current (about 4 s of processing per body type otherwise).
static func prepared(body_type: String) -> Dictionary:
	var kind: String = body_type if PATHS.has(body_type) else "female"
	if not _cache.has(kind):
		var d: Dictionary = _load_baked(kind)
		if d.is_empty():
			d = _prepare(kind)
		_cache[kind] = d
	return _cache[kind]


## The baked prepare result of a type, or {} when there is none or it was made from another .glb or bake format.
## (An exported game has no .glb source to hash: the bake is trusted there.)
static func _load_baked(kind: String) -> Dictionary:
	var path: String = str(BAKED[kind])
	if not ResourceLoader.exists(path):
		return {}
	var mesh: ArrayMesh = load(path) as ArrayMesh
	if mesh == null or int(mesh.get_meta("bake_version", 0)) != BAKE_VERSION:
		return {}
	var glb_md5: String = FileAccess.get_md5(str(PATHS[kind]))
	if glb_md5 != "" and glb_md5 != str(mesh.get_meta("glb_md5", "")):
		push_warning("HoudiniBody: %s is stale (the .glb changed); run tools/bake_houdini_body.sh" % path)
		return {}
	return {"mesh": mesh, "regions": mesh.get_meta("regions"), "tri_region": mesh.get_meta("tri_region")}


## Processes a body type and saves the result to BAKED (tools/bake_houdini_body.sh). Returns the save error.
static func bake(kind: String) -> Error:
	var d: Dictionary = _prepare(kind)
	if d.is_empty():
		return ERR_FILE_NOT_FOUND
	var mesh: ArrayMesh = d["mesh"]
	mesh.surface_set_material(0, null)  ## the body draws with the "skin" material_override
	mesh.set_meta("regions", d["regions"])
	mesh.set_meta("tri_region", d["tri_region"])
	mesh.set_meta("bake_version", BAKE_VERSION)
	mesh.set_meta("glb_md5", FileAccess.get_md5(str(PATHS[kind])))
	mesh.set_meta("source_md5", FileAccess.get_md5(SOURCE))
	_cache[kind] = d
	return ResourceSaver.save(mesh, str(BAKED[kind]), ResourceSaver.FLAG_COMPRESS)


## Joint name a region hangs on, given the region name with its side ("upper_arm_L" -> "LeftUpperArm", "bust_L" ->
## "BodySway_BustL", "chest" -> "Chest"). Caps hang on their region's joint except the hand cap (LowerArm) and the
## head cap (Neck).
static func home_joint(region: String) -> String:
	var r: String = region.trim_suffix("_cap")
	var cap: bool = r != region
	var side: String = ""
	if r.ends_with("_L") or r.ends_with("_R"):
		side = r.right(1)
		r = r.left(r.length() - 2)
	if cap and r == "hand":
		r = "wrist"
	if cap and r == "head":
		r = "neck"
	var j: String = str(HOME.get(r, "Hips"))
	if side == "":
		return j
	if r == "bust":
		return j + side
	return ("Left" if side == "L" else "Right") + j


static func _prepare(kind: String) -> Dictionary:
	var scene: PackedScene = load(str(PATHS[kind])) as PackedScene
	if scene == null:
		return {}
	var inst: Node = scene.instantiate()
	var skel: Skeleton3D = SkinnedBody.find_skeleton(inst)
	var mi: MeshInstance3D = null
	if skel != null:
		for c: Node in skel.get_children():
			if c is MeshInstance3D:
				mi = c as MeshInstance3D
	if mi == null or mi.mesh == null or mi.skin == null:
		inst.free()
		return {}
	var rest: Dictionary = {}
	for b: int in skel.get_bone_count():
		rest[skel.get_bone_name(b)] = skel.get_bone_global_rest(b)
	var binds: Array = []  ## bind index -> bone name
	for i: int in mi.skin.get_bind_count():
		binds.append(str(mi.skin.get_bind_name(i)) if mi.skin.get_bind_name(i) != &"" else skel.get_bone_name(mi.skin.get_bind_bone(i)))
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var material: Material = mi.mesh.surface_get_material(0)
	inst.free()
	var m: _Mesh = _Mesh.new(arrays)
	var cl: _Classifier = _Classifier.new(kind, rest)
	_clean_weights(m, binds, cl)
	var tags: Dictionary = {}  ## triangle index -> region forced by a cut
	# Every cut first (a cut renumbers the triangles), then the tags and the caps (caps only append).
	var planes: Array = []  ## [normal, d, centre, cut radius, tag centre, tag radius, cap depth, region]
	planes.append([Vector3.UP, HEAD_CUT_Y, Vector3(0.0, HEAD_CUT_Y, 0.0), 0.12, Vector3(0.0, 1.5, 0.0), 0.3, 0.01, "head"])
	for side: String in ["Left", "Right"]:
		var sfx: String = "_" + side.left(1)
		var hand: Transform3D = rest[side + "Hand"]
		var along: Vector3 = -hand.basis.y.normalized()  ## down the hand, away from the forearm
		var at: Vector3 = hand.origin + along * WRIST_CUT
		planes.append([along, along.dot(at), at, 0.06, at, 0.22, 0.014, "hand" + sfx])
		var foot: Vector3 = (rest[side + "Foot"] as Transform3D).origin
		var fc: Vector3 = Vector3(foot.x, FOOT_CUT_Y, 0.0)
		planes.append([Vector3.DOWN, -FOOT_CUT_Y, fc, 0.09, Vector3(foot.x, 0.04, -0.05), 0.2, 0.008, "foot" + sfx])
	for pl: Array in planes:
		_cut(m, pl[0], pl[1], pl[2], pl[3], str(pl[7]) == "head")
	_region_cuts(m, cl, rest)
	for pl: Array in planes:
		_tag_side(m, tags, pl[0], pl[1], pl[4], pl[5], pl[7])
	var names: PackedStringArray = PackedStringArray()
	var tri_region: PackedInt32Array = PackedInt32Array()
	var tri_count: int = m.idx.size() / 3
	tri_region.resize(tri_count)
	for t: int in tri_count:
		var r: String = str(tags.get(t, ""))
		if r == "":
			var c: Vector3 = (m.pos[m.idx[t * 3]] + m.pos[m.idx[t * 3 + 1]] + m.pos[m.idx[t * 3 + 2]]) / 3.0
			r = cl.region(c)
			if r.begins_with("bust"):
				# A sliver across a corner of the curved cup outline: its centre inside, a corner well outside.
				for k: int in 3:
					var q: Vector3 = m.pos[m.idx[t * 3 + k]]
					if cl.cup_field(Vector3(absf(q.x), q.y, q.z)) < -0.005:
						r = cl.torso_region(c, false)
		var k: int = names.find(r)
		if k < 0:
			names.append(r)
			k = names.size() - 1
		tri_region[t] = k
	var vreg: Dictionary = _vertex_regions(m, names, tri_region)
	_region_weights(m, binds, vreg, rest)
	if fit_enabled:
		_fit(m, cl, vreg, _armpit(m, names, tri_region, vreg))
		m.recompute_normals()
	tri_region = _piece_joints(m, cl, names, tri_region, binds, rest, tags)
	m.recompute_normals()
	for pl: Array in planes:
		var first: int = m.idx.size() / 3
		_cap(m, tags, pl[0], pl[1], pl[2], pl[3], pl[6], str(pl[7]) + "_cap")
		var cap_name: String = str(pl[7]) + "_cap"
		if names.find(cap_name) < 0:
			names.append(cap_name)
		for t: int in range(first, m.idx.size() / 3):
			tri_region.append(names.find(cap_name))
	m.recompute_cap_normals()
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.to_arrays())
	mesh.surface_set_material(0, material)
	return {"mesh": mesh, "regions": names, "tri_region": tri_region}


## Weight cleanup: drop influences from the other side's limbs and from the HeadTop marker, keep the 4 largest,
## renormalize.
static func _clean_weights(m: _Mesh, binds: Array, cl: _Classifier) -> void:
	var bust_bind: Dictionary = {"L": binds.find("BustL"), "R": binds.find("BustR")}
	for v: int in m.pos.size():
		if bust_bind["L"] >= 0 and cl.in_bust_field(m.pos[v]):
			# The bust forms ride their BustL/R bones (the BodySway pivots) like the code skin's bust and the bikini cups.
			var w: Dictionary = {}
			var k_b: float = smoothstep(1.0, 0.55, cl.bust_d2(m.pos[v]))
			for k: int in 4:
				w[m.bones[v * 4 + k]] = float(w.get(m.bones[v * 4 + k], 0.0)) + m.wts[v * 4 + k] * (1.0 - k_b)
			var bb: int = bust_bind["L" if m.pos[v].x < 0.0 else "R"]
			w[bb] = float(w.get(bb, 0.0)) + k_b
			m.set_weights(v, w)
		var p: Vector3 = m.pos[v]
		var total: float = 0.0
		for k: int in 4:
			var bn: String = str(binds[m.bones[v * 4 + k]]) if m.bones[v * 4 + k] < binds.size() else ""
			var drop: bool = bn == "HeadTop"
			if absf(p.x) > 0.03 and (bn.begins_with("Left") and p.x > 0.0 or bn.begins_with("Right") and p.x < 0.0):
				drop = true
			if drop:
				m.wts[v * 4 + k] = 0.0
			total += m.wts[v * 4 + k]
		if total <= 0.0:
			continue
		for k: int in 4:
			m.wts[v * 4 + k] /= total


## Splits the triangles that cross the plane n.p = d within `radius` of `centre`, so the mesh has an edge loop on it.
## up_only: only triangles above centre's y - radius * 0.5 (keeps the neck cut off the shoulders); keep: when valid,
## only triangles whose centre it accepts (Callable(Vector3) -> bool).
## field: when valid, cuts along its zero set instead of the plane (Callable(Vector3) -> float, linear along edges).
## only: when not empty, only triangles whose entry in `regions` it holds. Returns each output triangle's source triangle.
static func _cut(m: _Mesh, n: Vector3, d: float, centre: Vector3, radius: float, up_only: bool,
		keep: Callable = Callable(), field: Callable = Callable(), regions: PackedInt32Array = PackedInt32Array(),
		only: Array = []) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var origin: PackedInt32Array = PackedInt32Array()  ## source triangle of each output triangle
	var split: Dictionary = {}  ## edge key -> new vertex
	for t: int in m.idx.size() / 3:
		var ia: Array = [m.idx[t * 3], m.idx[t * 3 + 1], m.idx[t * 3 + 2]]
		var n0: int = out.size()
		if not only.is_empty() and not only.has(regions[t]):
			out.append_array(PackedInt32Array(ia))
			origin.append(t)
			continue
		var c: Vector3 = (m.pos[ia[0]] + m.pos[ia[1]] + m.pos[ia[2]]) / 3.0
		var sd: Array = []
		var pos_n: int = 0
		var neg_n: int = 0
		for i: int in ia:
			var s: float = float(field.call(m.pos[i])) if field.is_valid() else n.dot(m.pos[i]) - d
			if absf(s) < 1e-6:
				s = 0.0
				if not field.is_valid():
					m.on_plane[i] = true
			sd.append(s)
			pos_n += int(s > 0.0)
			neg_n += int(s < 0.0)
		if pos_n == 0 or neg_n == 0 or c.distance_to(centre) > radius or (up_only and c.y < centre.y - radius * 0.5) \
				or (keep.is_valid() and not bool(keep.call(c))):
			out.append_array(PackedInt32Array(ia))
			origin.append(t)
			continue
		# Rotate so the lone vertex (alone on its side, or the one on the plane) comes first.
		var lone: int = 0
		for i: int in 3:
			var a: float = sd[i]
			var b: float = sd[(i + 1) % 3]
			var cc: float = sd[(i + 2) % 3]
			if (a > 0.0 and b <= 0.0 and cc <= 0.0) or (a < 0.0 and b >= 0.0 and cc >= 0.0):
				lone = i
				break
		var v0: int = ia[lone]
		var v1: int = ia[(lone + 1) % 3]
		var v2: int = ia[(lone + 2) % 3]
		var s0: float = sd[lone]
		var s1: float = sd[(lone + 1) % 3]
		var s2: float = sd[(lone + 2) % 3]
		if s1 == 0.0 or s2 == 0.0:
			# One vertex on the plane: split the opposite edge only.
			var on: int = v1 if s1 == 0.0 else v2
			var other: int = v2 if s1 == 0.0 else v1
			var so: float = s2 if s1 == 0.0 else s1
			var e: int = _edge_vertex(m, split, v0, other, s0, so, field)
			if on == v1:
				out.append_array(PackedInt32Array([v0, v1, e, e, v1, v2]))
			else:
				out.append_array(PackedInt32Array([v0, e, v2, e, v1, v2]))
		else:
			var e1: int = _edge_vertex(m, split, v0, v1, s0, s1, field)
			var e2: int = _edge_vertex(m, split, v0, v2, s0, s2, field)
			out.append_array(PackedInt32Array([v0, e1, e2, e1, v1, v2, e1, v2, e2]))
		for k: int in (out.size() - n0) / 3:
			origin.append(t)
	m.idx = out
	return origin


static func _edge_vertex(m: _Mesh, split: Dictionary, a: int, b: int, sa: float, sb: float, field: Callable) -> int:
	var key: Vector2i = Vector2i(mini(a, b), maxi(a, b))
	if split.has(key):
		return split[key]
	var t: float = sa / (sa - sb)
	if field.is_valid():  # a curved cut: bisect for the zero along the edge
		var lo: float = 0.0
		var hi: float = 1.0
		for i: int in 12:
			t = (lo + hi) * 0.5
			var st: float = float(field.call(m.pos[a].lerp(m.pos[b], t)))
			if (st > 0.0) == (sa > 0.0):
				lo = t
			else:
				hi = t
		t = (lo + hi) * 0.5
	var v: int = m.lerp_vertex(a, b, t)
	m.on_plane[v] = true
	split[key] = v
	return v


## Splits the long PolyReduce triangles along every region border that a garment edge can follow, so a hidden region
## ends on a clean line: the torso heights (TORSO_CUTS), the limb fractions (AnimeOutfit.LIMB_REGIONS) and the elbow and
## knee bands, each only on the triangles of its own loft.
static func _region_cuts(m: _Mesh, cl: _Classifier, rest: Dictionary) -> void:
	var on_torso: Callable = func(c: Vector3) -> bool: return typeof(cl.best(c)[0]) == TYPE_STRING
	for cut: Array in TORSO_CUTS:
		_cut(m, Vector3.UP, float(cut[1]), Vector3(0.0, float(cut[1]), 0.0), 0.4, false, on_torso)
	# Torso against the upper arms and thighs: along the surface where the two lofts are equally close.
	for i: int in cl.limbs.size():
		var lbt: Array = cl.limbs[i]
		if not (lbt[0] in ["upper_arm", "thigh"]):
			continue
		var jt: Vector3 = (rest[lbt[2]] as Transform3D).origin
		var near: Callable = func(c: Vector3) -> bool:
			if c.distance_to(jt) > 0.2:
				return false
			var b: Variant = cl.best(c)[0]
			return typeof(b) == TYPE_STRING or int(b) == i
		var border: Callable = func(p: Vector3) -> float: return cl.torso_vs_limb(p, i)
		_cut(m, Vector3.UP, 0.0, jt, 0.2, false, near, border)
	if cl.kind != AnimeOutfit.MALE:
		for sx: float in [-1.0, 1.0]:
			var on_front: Callable = func(c: Vector3) -> bool:
				return c.z < -0.02 and signf(c.x) == sx and absf(c.x) < 0.16 and c.y > 0.98 and c.y < 1.32
			var cup: Callable = func(p: Vector3) -> float: return cl.cup_field(Vector3(absf(p.x), p.y, p.z))
			_cut(m, Vector3.UP, 0.0, Vector3(sx * 0.064, 1.14, -0.1), 0.25, false, on_front, cup)
	for i: int in cl.limbs.size():
		var lb: Array = cl.limbs[i]
		var xf: Transform3D = rest[lb[2]]
		var axis: Vector3 = xf.basis.y.normalized()
		var on_limb: Callable = func(c: Vector3) -> bool:
			var b: Variant = cl.best(c)[0]
			return typeof(b) == TYPE_INT and int(b) == i
		var ys: Array = []
		for c: Array in AnimeOutfit.LIMB_REGIONS[lb[0]]:
			ys.append(-float(c[2]) * float(lb[4]))
		ys.pop_back()
		if lb[0] == "forearm":
			ys.append_array([-ELBOW_R])
		if lb[0] == "upper_arm":
			ys.append(-float(lb[4]) + ELBOW_R)
		if lb[0] == "calf":
			ys.append(-KNEE_R)
		if lb[0] == "thigh":
			ys.append(-float(lb[4]) + KNEE_R)
		for y: float in ys:
			var at: Vector3 = xf * Vector3(0.0, y, 0.0)
			_cut(m, axis, axis.dot(at), at, 0.2, false, on_limb)


## Tags every triangle whose centre lies on the positive side of n.p = d and within radius of centre.
static func _tag_side(m: _Mesh, tags: Dictionary, n: Vector3, d: float, centre: Vector3, radius: float, region: String) -> void:
	var sx: float = signf(centre.x)
	for t: int in m.idx.size() / 3:
		var c: Vector3 = (m.pos[m.idx[t * 3]] + m.pos[m.idx[t * 3 + 1]] + m.pos[m.idx[t * 3 + 2]]) / 3.0
		if n.dot(c) - d > 0.0 and c.distance_to(centre) < radius and (sx == 0.0 or signf(c.x) == sx):
			if not tags.has(t):
				tags[t] = region


## Closes the kept side (n.p < d) of the loop cut at the plane with a rounded cap `depth` deep into the removed side.
static func _cap(m: _Mesh, tags: Dictionary, n: Vector3, d: float, centre: Vector3, radius: float, depth: float,
		region: String) -> void:
	var nxt: Dictionary = {}
	for t: int in m.idx.size() / 3:
		if tags.has(t):
			continue
		var ia: Array = [m.idx[t * 3], m.idx[t * 3 + 1], m.idx[t * 3 + 2]]
		var c: Vector3 = (m.pos[ia[0]] + m.pos[ia[1]] + m.pos[ia[2]]) / 3.0
		if n.dot(c) - d > 0.0 or c.distance_to(centre) > radius * 1.5:
			continue
		for i: int in 3:
			var a: int = ia[i]
			var b: int = ia[(i + 1) % 3]
			if m.on_plane.has(a) and m.on_plane.has(b) and absf(n.dot(m.pos[a]) - d) < 1e-5 and absf(n.dot(m.pos[b]) - d) < 1e-5:
				nxt[b] = a  ## reversed: the cap runs the loop the other way round
	# Longest loop.
	var best: Array = []
	var seen: Dictionary = {}
	for s: int in nxt.keys():
		if seen.has(s):
			continue
		var loop: Array = []
		var v: int = s
		while not seen.has(v) and nxt.has(v):
			seen[v] = true
			loop.append(v)
			v = nxt[v]
		if v == s and loop.size() > best.size():
			best = loop
	if best.size() < 3:
		push_warning("HoudiniBody: no loop to cap for " + region)
		return
	var mid: Vector3 = Vector3.ZERO
	for v: int in best:
		mid += m.pos[v]
	mid /= float(best.size())
	var rings: int = 3
	var ring_ids: Array = []
	for r: int in rings + 1:
		var ang: float = PI * 0.5 * float(r) / float(rings + 1)
		var ids: Array = []
		for v: int in best:
			var p: Vector3 = mid + (m.pos[v] - mid) * cos(ang) + n * depth * sin(ang)
			ids.append(m.copy_vertex(v, p))
		ring_ids.append(ids)
	var tip: int = m.copy_vertex(best[0], mid + n * depth)
	m.blend_weights_of(tip, best)
	var start: int = m.idx.size() / 3
	var count: int = best.size()
	for r: int in rings:
		var a: Array = ring_ids[r]
		var b: Array = ring_ids[r + 1]
		for i: int in count:
			var j: int = (i + 1) % count
			m.add_tri(a[i], a[j], b[j], mid - n * depth)
			m.add_tri(a[i], b[j], b[i], mid - n * depth)
	var last: Array = ring_ids[rings]
	for i: int in count:
		m.add_tri(last[i], last[(i + 1) % count], tip, mid - n * depth)
	for t: int in range(start, m.idx.size() / 3):
		tags[t] = region
	for ids: Array in ring_ids:
		for v: int in ids:
			m.cap_vertex[v] = mid - n * depth
	m.cap_vertex[tip] = mid - n * depth


## Pulls loft regions in to FIT_TOLERANCE outside the code skin (less SHRINK, and BLEND_SHRINK where two bones share a
## vertex: blended points swing out of the rigid garment pieces as the joint bends).
static func _fit(m: _Mesh, cl: _Classifier, vreg: Dictionary, armpit: Dictionary) -> void:
	for v: int in vreg.keys():
		if m.cap_vertex.has(v):
			continue
		var p: Vector3 = m.pos[v]
		var top: float = 0.0
		for k: int in 4:
			top = maxf(top, m.wts[v * 4 + k])
		var extra: float = BLEND_SHRINK * clampf(2.0 * (1.0 - top), 0.0, 1.0)
		if armpit.has(v):
			extra = maxf(extra, ARMPIT_SHRINK)
		var q: Vector3 = cl.fitted(p, str(vreg[v]), extra)
		if q != p:
			m.pos[v] = q


## The torso's vertices on its border with the shoulders and upper arms: they ride the chest while the arm triangles
## round them follow the arm, so with the arm raised they sit in the armpit right under the sleeve's opening.
static func _armpit(m: _Mesh, names: PackedStringArray, tri_region: PackedInt32Array, vreg: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for t: int in tri_region.size():
		var base: String = names[tri_region[t]].trim_suffix("_L").trim_suffix("_R")
		if not base in ["shoulder", "upper_arm"]:
			continue
		for k: int in 3:
			var v: int = m.idx[t * 3 + k]
			if _rank(str(vreg.get(v, ""))) == 2:
				out[v] = true
	return out


## Leg joints the pieces of the code skin (and the garments hung on them) meet at: [regions, joint, its reach (m),
## parent piece, child piece].
## The regions on each side of the joint are [parent side], [child side]; the first of each is the one a triangle that
## moves with the other piece is relabelled to.
const PIECE_JOINTS: Array = [
	[["pelvis"], ["thigh_upper", "thigh_top"], "UpperLeg", 0.17, "pelvis", "thigh", true],
	[["thigh_lower"], ["knee", "calf"], "LowerLeg", 0.12, "thigh", "shin", true],
]
## How far below the pelvis loft's end the seats of the shorts and trousers reach (GarmentBottoms' gusset row).
const SEAT_GUSSET: float = 0.008
## Half width (m) of the blend between two pieces' joints by how far a point lies inside each.
const PIECE_BLEND: float = 0.002


## Near the hips and knees a point follows the code-skin piece it lies inside (the pelvis or the thigh, the thigh or
## the shin): those pieces are rigid on their joints and so are the garment pieces over them (the shorts' seat on the
## hips, their legs on the thighs, the jeans' knee on the shin). A biharmonic blend would swing the buttock out of the
## seat as the thigh lifts, and the front of the knee out of the knee piece as it bends. The long triangles across
## the line between the pieces are split along it first, then each triangle takes the region of the piece it moves
## with (so the garment over that piece is the one that hides and covers it).
static func _piece_joints(m: _Mesh, cl: _Classifier, names: PackedStringArray, tri_region: PackedInt32Array, binds: Array,
		rest: Dictionary, tags: Dictionary) -> PackedInt32Array:
	var left_x: float = (rest["LeftUpperLeg"] as Transform3D).origin.x
	var regions: PackedInt32Array = tri_region
	for pj: Array in PIECE_JOINTS:
		for side: String in ["Left", "Right"]:
			var jt: Vector3 = (rest[side + str(pj[2])] as Transform3D).origin
			var reach: float = float(pj[3])
			var mine: Callable = func(c: Vector3) -> bool:
				return c.distance_to(jt) <= reach and signf(c.x) == (signf(left_x) if side == "Left" else -signf(left_x))
			var field: Callable = func(q: Vector3) -> float: return _piece_w(cl, q, pj, side) - 0.5
			var ids: Array = _region_ids(names, pj)
			var keep: Callable = func(c: Vector3) -> bool: return mine.call(c)
			var origin: PackedInt32Array = _cut(m, Vector3.UP, 0.0, jt, reach, false, keep, field, regions, ids)
			var remapped: PackedInt32Array = PackedInt32Array()
			remapped.resize(origin.size())
			var old_tags: Dictionary = tags.duplicate()
			tags.clear()
			for k: int in origin.size():
				remapped[k] = regions[origin[k]]
				if old_tags.has(origin[k]):
					tags[k] = old_tags[origin[k]]  ## the cap side tags are per triangle too
			regions = remapped
	# Weights and regions, by the piece each vertex and triangle moves with.
	var tri_count: int = m.idx.size() / 3
	for pj: Array in PIECE_JOINTS:
		var ids: Array = _region_ids(names, pj)
		for side: String in ["Left", "Right"]:
			var child: String = side + str(pj[2])
			var jt: Vector3 = (rest[child] as Transform3D).origin
			var pb: int = binds.find(_parent_of(child))
			var cb: int = binds.find(child)
			var sx: float = signf(left_x) if side == "Left" else -signf(left_x)
			var done: Dictionary = {}
			for t: int in tri_count:
				if not ids.has(regions[t]):
					continue
				var c: Vector3 = (m.pos[m.idx[t * 3]] + m.pos[m.idx[t * 3 + 1]] + m.pos[m.idx[t * 3 + 2]]) / 3.0
				if c.distance_to(jt) > float(pj[3]) or signf(c.x) != sx:
					continue
				for k: int in 3:
					var v: int = m.idx[t * 3 + k]
					if done.has(v) or m.cap_vertex.has(v) or signf(m.pos[v].x) != sx:
						continue  ## a vertex follows its own side's leg
					done[v] = true
					var w: float = _piece_w(cl, m.pos[v], pj, side, 0.0005)
					if w >= 0.0 and pb >= 0 and cb >= 0:
						# Rigid: a vertex on the line between the pieces (w 0.5, where the cut put it) goes with the
						# child, whose garment piece (the leg, the knee) closes round the joint's crease.
						w = 1.0 if w >= 0.49 else 0.0
						m.set_weights(v, {pb: 1.0 - w, cb: w})
				var wc: float = _piece_w(cl, c, pj, side)
				if wc < 0.0:
					continue
				var to: String = str(pj[1][0]) + "_" + side.left(1)
				if wc <= 0.5:
					to = str(pj[0][0]) if pj[0][0] == "pelvis" else str(pj[0][0]) + "_" + side.left(1)
				var base: String = names[regions[t]].trim_suffix("_L").trim_suffix("_R")
				if (wc > 0.5) == (base in pj[1]):
					continue  ## already a region of that piece
				var i: int = names.find(to)
				if i < 0:
					names.append(to)
					i = names.size() - 1
				regions[t] = i
	# The seam: a child-rigid corner of a parent triangle (on the crease the cut ran along) is drawn SEAM_SHRINK in
	# toward the child's axis, so it stays inside the parent's garment piece too as the joint bends.
	var pulled: Dictionary = {}
	for t: int in tri_count:
		var base: String = names[regions[t]].trim_suffix("_L").trim_suffix("_R")
		for pj: Array in PIECE_JOINTS:
			if not base in pj[0]:
				continue
			for k: int in 3:
				var v: int = m.idx[t * 3 + k]
				if pulled.has(v) or m.cap_vertex.has(v):
					continue
				var child: String = ("Left" if signf(m.pos[v].x) == signf(left_x) else "Right") + str(pj[2])
				var cb: int = binds.find(child)
				var on_child: bool = false
				for j: int in 4:
					on_child = on_child or (m.bones[v * 4 + j] == cb and m.wts[v * 4 + j] > 0.99)
				if not on_child:
					continue
				pulled[v] = true
				var xf: Transform3D = rest[child]
				var axis: Vector3 = xf.basis.y.normalized()
				var d: Vector3 = m.pos[v] - xf.origin
				var radial: Vector3 = d - axis * d.dot(axis)
				if radial.length() > 1e-4:
					var pull: float = SEAM_SHRINK * (2.0 if absf(m.pos[v].x) < CROTCH_HALF else 1.0)
					m.pos[v] -= radial.normalized() * pull
	return regions


## Region indices of a PIECE_JOINTS row (either side).
static func _region_ids(names: PackedStringArray, pj: Array) -> Array:
	var ids: Array = []
	for i: int in names.size():
		var base: String = names[i].trim_suffix("_L").trim_suffix("_R")
		if base in pj[0] or base in pj[1]:
			ids.append(i)
	return ids


## Child bone weight (0..1) of a point at a PIECE_JOINTS joint: 1 inside the child piece (the thigh where it runs up
## into the pelvis, the shin's knee ball inside the thigh's end), else 0 inside the parent piece; outside both, blended
## over PIECE_BLEND by which one p lies closer to. -1 where neither piece reaches. tol: how far outside the child piece
## still counts as inside (the vertices a cut put on its surface).
static func _piece_w(cl: _Classifier, p: Vector3, pj: Array, side: String, tol: float = 0.0) -> float:
	var dc: float = cl.piece_out(p, str(pj[5]), side)
	var dp: float = cl.piece_out(p, str(pj[4]), side)
	if bool(pj[6]) and dc <= tol:
		return 1.0
	if dp <= 0.0:
		return 0.0
	if dc <= 0.0:
		return 1.0
	if dp == INF and dc == INF:
		return -1.0
	if dp == INF:
		return 1.0
	if dc == INF:
		return 0.0
	return smoothstep(-PIECE_BLEND, PIECE_BLEND, dp - dc)


## Region of each vertex on a region border: by _rank, then the first triangle that uses it.
static func _vertex_regions(m: _Mesh, names: PackedStringArray, tri_region: PackedInt32Array) -> Dictionary:
	var vreg: Dictionary = {}
	for t: int in tri_region.size():
		for k: int in 3:
			var v: int = m.idx[t * 3 + k]
			var r: String = names[tri_region[t]]
			if not vreg.has(v) or _rank(r) > _rank(str(vreg[v])):
				vreg[v] = r
	return vreg


## Which region a vertex on a border takes: the torso over the limbs (it stays with the rigid garment piece over the
## torso; the limb side blends to the torso near the joint anyway), and anything over the head, hands and feet.
static func _rank(r: String) -> int:
	if _passive(r):
		return 0
	var base: String = r.trim_suffix("_L").trim_suffix("_R")
	if base in ["pelvis", "hip_band", "belly", "waist_low", "waist", "under_bust", "chest", "chest_upper", "neck_base", "neck"]:
		return 2
	return 1


## Regions that are neither fitted nor reweighted (a vertex shared with an active region takes that one).
static func _passive(r: String) -> bool:
	return r.begins_with("head") or r.begins_with("hand") or r.begins_with("foot")


## Weights by region, so each region moves like the code-skin part it replaces (rigid on its home joint: the garment
## piece that covers it hangs on that joint) while the joints still blend. The biharmonic weights have long tails
## (a few percent of the thigh down at the ankle, of the arm across the ribs); here a vertex keeps its home joint's
## weight, a neighbouring bone's weight fades out with the distance from the joint they share (BLEND), any other
## bone's weight is dropped (what is dropped goes to the home joint), and the wrists and ankles keep none of the hand and foot (no candy-wrapper twist).
static func _region_weights(m: _Mesh, binds: Array, vreg: Dictionary, rest: Dictionary) -> void:
	for v: int in vreg.keys():
		var reg: String = vreg[v]
		var base: String = reg
		var side: String = ""
		if base.ends_with("_L") or base.ends_with("_R"):
			side = "Left" if base.ends_with("_L") else "Right"
			base = base.left(base.length() - 2)
		if base in ["head", "hand"] or not HOME.has(base):
			continue
		var home: String = str(HOME[base])
		if home == "BodySway_Bust":
			# Under the bikini cup: rigid on the bust bone, as the cup is rigid on its BodySway pivot.
			var bb: int = binds.find("Bust" + reg.right(1))
			if bb >= 0:
				m.set_weights(v, {bb: 1.0})
			continue
		elif side != "":
			home = side + home
		var p: Vector3 = m.pos[v]
		if base in ["hip_band", "belly", "waist_low", "waist", "under_bust", "chest", "chest_upper", "neck_base"]:
			m.set_weights(v, _torso_weights(p.y, binds, m, v))
			continue
		var w: Dictionary = {}
		var total: float = 0.0
		for k: int in 4:
			var b: int = m.bones[v * 4 + k]
			var wt: float = m.wts[v * 4 + k]
			if wt <= 0.0:
				continue
			var bn: String = str(binds[b]) if b < binds.size() else ""
			var f: float = _weight_factor(base, home, bn, p, rest)
			if f > 0.0:
				w[b] = float(w.get(b, 0.0)) + wt * f
				total += wt * f
		var hb: int = binds.find(home)
		if hb >= 0 and total < 0.9999:
			w[hb] = float(w.get(hb, 0.0)) + (1.0 - total)  ## dropped weight goes to the home joint
			total = 1.0
		if total > 1e-4:
			m.set_weights(v, w)


## Torso band weights at height y (TORSO_WEIGHTS), keeping a bust bone's share where the vertex has one.
static func _torso_weights(y: float, binds: Array, m: _Mesh, v: int) -> Dictionary:
	var row: Array = TORSO_WEIGHTS[0]
	var last: Array = TORSO_WEIGHTS[TORSO_WEIGHTS.size() - 1]
	var ws: Array = [row[1], row[2], row[3], row[4]]
	if y >= float(last[0]):
		ws = [last[1], last[2], last[3], last[4]]
	else:
		for i: int in TORSO_WEIGHTS.size() - 1:
			var a: Array = TORSO_WEIGHTS[i]
			var b: Array = TORSO_WEIGHTS[i + 1]
			if y >= float(a[0]) and y < float(b[0]):
				var t: float = (y - float(a[0])) / (float(b[0]) - float(a[0]))
				for k: int in 4:
					ws[k] = lerpf(float(a[k + 1]), float(b[k + 1]), t)
	var bust: float = 0.0
	var bust_bind: int = -1
	for k: int in 4:
		var b: int = m.bones[v * 4 + k]
		if b < binds.size() and str(binds[b]).begins_with("Bust"):
			bust += m.wts[v * 4 + k]
			bust_bind = b
	var out: Dictionary = {}
	var names: Array = ["Hips", "Spine", "Chest", "Neck"]
	for k: int in 4:
		var bi: int = binds.find(names[k])
		if bi >= 0 and float(ws[k]) > 0.0:
			out[bi] = float(out.get(bi, 0.0)) + float(ws[k]) * (1.0 - bust)
	if bust_bind >= 0:
		out[bust_bind] = bust
	return out


## Blend radii [full until, gone at] (metres from the shared joint) of a neighbouring bone, by the shared joint.
const BLEND: Dictionary = {
	"Spine": [0.06, 0.14], "Chest": [0.06, 0.14], "Neck": [0.03, 0.08], "Head": [0.02, 0.06],
	"UpperArm": [0.04, 0.1], "LowerArm": [0.03, 0.08], "Hand": [0.0, 0.0],
	"UpperLeg": [0.05, 0.12], "LowerLeg": [0.03, 0.08], "Foot": [0.02, 0.06],
}


## Multiplier (0..1) of `bone`'s weight on a vertex of region `base` (home joint `home`) at model-pose point p.
static func _weight_factor(base: String, home: String, bone: String, p: Vector3, rest: Dictionary) -> float:
	if bone == home or bone.begins_with("Bust"):
		return 1.0
	if (base == "wrist" and bone.ends_with("Hand")) or (base == "ankle" and bone.ends_with("Foot")):
		return 0.0
	# The joint shared with a neighbour: the child's own joint.
	var child: String = ""
	if rest.has(bone) and rest.has(home):
		if _parent_of(bone) == home:
			child = bone
		elif _parent_of(home) == bone:
			child = home
	if child == "":
		return 0.0
	var fam: String = child.trim_prefix("Left").trim_prefix("Right")
	var r: Array = BLEND.get(fam, [0.0, 0.0])
	var d: float = p.distance_to((rest[child] as Transform3D).origin)
	return 1.0 - smoothstep(float(r[0]), float(r[1]), d)


static func _parent_of(joint: String) -> String:
	var fam: String = joint.trim_prefix("Left").trim_prefix("Right")
	var side: String = joint.left(joint.length() - fam.length())
	match fam:
		"Spine": return "Hips"
		"Chest": return "Spine"
		"Neck": return "Chest"
		"Head": return "Neck"
		"UpperArm": return "Chest"
		"LowerArm": return side + "UpperArm"
		"Hand": return side + "LowerArm"
		"UpperLeg": return "Hips"
		"LowerLeg": return side + "UpperLeg"
		"Foot": return side + "LowerLeg"
	return ""


## Editable copy of a skinned surface (positions, normals, 4 bones and weights per vertex, indices).
class _Mesh:
	var pos: PackedVector3Array
	var nrm: PackedVector3Array
	var bones: PackedInt32Array
	var wts: PackedFloat32Array
	var idx: PackedInt32Array
	var on_plane: Dictionary = {}
	var cap_vertex: Dictionary = {}  ## cap vertex -> the cap's inner centre (normals point away from it)

	func _init(arrays: Array) -> void:
		pos = arrays[Mesh.ARRAY_VERTEX]
		nrm = arrays[Mesh.ARRAY_NORMAL]
		bones = arrays[Mesh.ARRAY_BONES]
		wts = arrays[Mesh.ARRAY_WEIGHTS]
		idx = arrays[Mesh.ARRAY_INDEX]

	func lerp_vertex(a: int, b: int, t: float) -> int:
		pos.append(pos[a].lerp(pos[b], t))
		nrm.append(nrm[a].lerp(nrm[b], t).normalized())
		var w: Dictionary = {}
		for k: int in 4:
			w[bones[a * 4 + k]] = float(w.get(bones[a * 4 + k], 0.0)) + wts[a * 4 + k] * (1.0 - t)
			w[bones[b * 4 + k]] = float(w.get(bones[b * 4 + k], 0.0)) + wts[b * 4 + k] * t
		_append_weights(w)
		return pos.size() - 1

	func copy_vertex(src: int, p: Vector3) -> int:
		pos.append(p)
		nrm.append(nrm[src])
		for k: int in 4:
			bones.append(bones[src * 4 + k])
			wts.append(wts[src * 4 + k])
		return pos.size() - 1

	## Gives vertex v the mean weights of the given vertices.
	func blend_weights_of(v: int, of: Array) -> void:
		var w: Dictionary = {}
		for s: int in of:
			for k: int in 4:
				w[bones[s * 4 + k]] = float(w.get(bones[s * 4 + k], 0.0)) + wts[s * 4 + k]
		var pairs: Array = _top4(w)
		for k: int in 4:
			bones[v * 4 + k] = int(pairs[k][0])
			wts[v * 4 + k] = float(pairs[k][1])

	func set_weights(v: int, w: Dictionary) -> void:
		var pairs: Array = _top4(w)
		for k: int in 4:
			bones[v * 4 + k] = int(pairs[k][0])
			wts[v * 4 + k] = float(pairs[k][1])

	func _append_weights(w: Dictionary) -> void:
		var pairs: Array = _top4(w)
		for k: int in 4:
			bones.append(int(pairs[k][0]))
			wts.append(float(pairs[k][1]))

	static func _top4(w: Dictionary) -> Array:
		var pairs: Array = []
		for b: int in w.keys():
			if float(w[b]) > 0.0:
				pairs.append([b, float(w[b])])
		pairs.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) > float(y[1]))
		pairs = pairs.slice(0, 4)
		var total: float = 0.0
		for p: Array in pairs:
			total += float(p[1])
		for p: Array in pairs:
			p[1] = float(p[1]) / maxf(total, 1e-9)
		while pairs.size() < 4:
			pairs.append([0, 0.0])
		return pairs

	## Adds a triangle facing away from `inner` (Godot front faces wind clockwise).
	func add_tri(a: int, b: int, c: int, inner: Vector3) -> void:
		var fn: Vector3 = (pos[b] - pos[a]).cross(pos[c] - pos[a])
		if fn.dot((pos[a] + pos[b] + pos[c]) / 3.0 - inner) > 0.0:
			idx.append_array(PackedInt32Array([a, c, b]))
		else:
			idx.append_array(PackedInt32Array([a, b, c]))

	## Smooth normals from the faces (area weighted), keeping the original side.
	func recompute_normals() -> void:
		var acc: PackedVector3Array = PackedVector3Array()
		acc.resize(pos.size())
		for t: int in idx.size() / 3:
			var a: int = idx[t * 3]
			var b: int = idx[t * 3 + 1]
			var c: int = idx[t * 3 + 2]
			var fn: Vector3 = (pos[b] - pos[a]).cross(pos[c] - pos[a])
			acc[a] += fn
			acc[b] += fn
			acc[c] += fn
		var agree: int = 0
		for v: int in pos.size():
			agree += 1 if acc[v].dot(nrm[v]) > 0.0 else -1
		var sgn: float = 1.0 if agree >= 0 else -1.0
		for v: int in pos.size():
			if acc[v].length_squared() > 1e-20:
				nrm[v] = (acc[v] * sgn).normalized()

	func recompute_cap_normals() -> void:
		for v: int in cap_vertex.keys():
			nrm[v] = (pos[v] - (cap_vertex[v] as Vector3)).normalized()

	func to_arrays() -> Array:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = pos
		arrays[Mesh.ARRAY_NORMAL] = nrm
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = wts
		arrays[Mesh.ARRAY_INDEX] = idx
		return arrays


## Region of a model-pose point: the code loft whose surface it lies closest to, then that loft's region.
class _Classifier:
	var kind: String
	var rest: Dictionary
	var torso: Array = []  ## smoothed body-space sections of the fused torso and neck
	var limbs: Array = []  ## [part, side, joint name, smoothed sections in joint space, length]
	var neck_y: float

	func _init(body_type: String, bone_rest: Dictionary) -> void:
		kind = body_type
		rest = bone_rest
		neck_y = (rest["Neck"] as Transform3D).origin.y
		var rows: Array = []
		for r: Array in AnimeOutfit.skin_sections("pelvis", kind):
			if float(r[0]) <= 0.93:
				rows.append(r)
		for r: Array in AnimeOutfit.skin_sections("waist", kind):
			if float(r[0]) > 0.93 and float(r[0]) < 0.975:
				rows.append(r)
		for r: Array in AnimeOutfit.skin_sections("chest", kind):
			if float(r[0]) >= 0.995:
				rows.append(r)
		var top: float = float(rows[rows.size() - 1][0])
		for r: Array in AnimeOutfit.skin_sections("neck", kind):
			if float(r[0]) + neck_y > top + 0.01:
				var row: Array = r.duplicate()
				row[0] = float(r[0]) + neck_y
				rows.append(row)
		torso = SkaterParts.smooth_sections(rows, 3)
		var lens: Dictionary = {"thigh": ["UpperLeg", PlaceholderSkater.UPPER_LEG], "calf": ["LowerLeg", PlaceholderSkater.LOWER_LEG],
				"upper_arm": ["UpperArm", PlaceholderSkater.UPPER_ARM], "forearm": ["LowerArm", PlaceholderSkater.LOWER_ARM]}
		for part: String in lens:
			for side: String in ["Left", "Right"]:
				var secs: Array = AnimeOutfit.limb_sections(AnimeOutfit.skin_sections(part, kind), float(lens[part][1]))
				limbs.append([part, side, side + str(lens[part][0]), secs, float(lens[part][1])])

	## Superellipse radius ratio of offset (x, z) against a section (1 on its outline).
	static func ratio(sec: Array, x: float, z: float) -> float:
		var p: float = float(sec[4])
		var dx: float = absf(x - float(sec[6])) / maxf(float(sec[1]), 1e-4)
		var dz0: float = z - float(sec[5])
		var dz: float = absf(dz0) / maxf(float(sec[2]) if dz0 < 0.0 else float(sec[3]), 1e-4)
		var e: float = 2.0 / p
		return pow(pow(dx, e) + pow(dz, e), p / 2.0)

	## Female bust height over the ribs at a body-space point (0 off the forms).
	func bust_lift(p: Vector3) -> float:
		if kind == AnimeOutfit.MALE or p.z > 0.0:
			return 0.0
		return maxf(AnimeOutfit.bust_height(absf(p.x), p.y), 0.0)

	## [loft, ratio]: the loft whose surface p lies closest to (loft is "torso" or an index into limbs).
	func best(p: Vector3) -> Array:
		var out: Array = ["", INF]
		var y0: float = float(torso[0][0])
		var y1: float = float(torso[torso.size() - 1][0])
		if p.y >= y0 and p.y <= y1:
			var sec: Array = SkaterParts.section_at(torso, p.y)
			var r: float = ratio(sec, p.x, p.z)
			var lift: float = bust_lift(p)
			if lift > 0.0:
				var d: float = float(sec[2])
				r = ratio(sec, p.x, p.z + lift * d / maxf(d, 1e-4))
			out = ["torso", r]
		for i: int in limbs.size():
			var r: float = limb_ratio(p, i)
			if r < INF and absf(log(r)) < absf(log(float(out[1]))):
				out = [i, r]
		return out

	## Radius ratio of p against limb i's loft (INF outside its length); for an upper arm, also its deltoid cap (the
	## code skin's shoulder), whichever is closer.
	func limb_ratio(p: Vector3, i: int) -> float:
		var lb: Array = limbs[i]
		var q: Vector3 = (rest[lb[2]] as Transform3D).affine_inverse() * p
		var secs: Array = lb[3]
		var r: float = INF
		if q.y <= float(secs[0][0]) and q.y >= float(secs[secs.size() - 1][0]):
			r = maxf(ratio(SkaterParts.section_at(secs, q.y), q.x, q.z), 1e-4)
		if lb[0] == "upper_arm":
			var dc: Vector4 = AnimeOutfit.deltoid(kind)
			var rd: float = maxf(((q - Vector3(0.0, dc.w, 0.0)) / Vector3(dc.x, dc.y, dc.z)).length(), 1e-4)
			if r == INF or absf(log(rd)) < absf(log(r)):
				r = rd
		return r

	func region(p: Vector3) -> String:
		var b: Array = best(p)
		var loft: Variant = b[0]
		if typeof(loft) == TYPE_STRING and str(loft) == "torso":
			return torso_region(p)
		if typeof(loft) != TYPE_INT:
			return "pelvis" if p.y < 1.0 else "neck"
		var lb: Array = limbs[int(loft)]
		var part: String = lb[0]
		var sfx: String = "_" + str(lb[1]).left(1)
		var q: Vector3 = (rest[lb[2]] as Transform3D).affine_inverse() * p
		var t: float = -q.y / float(lb[4])
		if part == "upper_arm" or part == "forearm":
			var elbow: Transform3D = rest[str(lb[1]) + "LowerArm"]
			if absf((elbow.affine_inverse() * p).y) < ELBOW_R:
				return "elbow" + sfx
		if part == "thigh" or part == "calf":
			var knee: Transform3D = rest[str(lb[1]) + "LowerLeg"]
			if absf((knee.affine_inverse() * p).y) < KNEE_R:
				return "knee" + sfx
		if part == "calf" and t > 0.9 and p.y < (rest[str(lb[1]) + "Foot"] as Transform3D).origin.y:
			# The heel and instep fused onto the shin: part of the foot (a sock or shoe encloses the shin, not them).
			var o: Array = outside(p, ["loft", (rest[lb[2]] as Transform3D).affine_inverse(), lb[3]], 0.0)
			if float(o[0]) > FOOT_FUSE:
				return "foot" + sfx
		for c: Array in AnimeOutfit.LIMB_REGIONS[part]:
			if t <= float(c[2]):
				return str(c[0]) + sfx
		var cuts: Array = AnimeOutfit.LIMB_REGIONS[part]
		return str(cuts[cuts.size() - 1][0]) + sfx

	## > 0 where the torso loft is the closer one, < 0 where limb i is (|log| of the radius ratios, clamped to +-1).
	func torso_vs_limb(p: Vector3, i: int) -> float:
		var a: float = 1.0
		if p.y >= float(torso[0][0]) and p.y <= float(torso[torso.size() - 1][0]):
			var sec: Array = SkaterParts.section_at(torso, p.y)
			var r: float = ratio(sec, p.x, p.z)
			var lift: float = bust_lift(p)
			if lift > 0.0:
				var d: float = float(sec[2])
				r = ratio(sec, p.x, p.z + lift * d / maxf(d, 1e-4))
			a = minf(absf(log(maxf(r, 1e-4))), 1.0)
		var b: float = 1.0
		var rl: float = limb_ratio(p, i)
		if rl < INF:
			b = minf(absf(log(rl)), 1.0)
		return b - a

	## Inside (> 0) or outside (< 0) the bikini cup's skin patch (AnimeOutfit cup outline, field units), at |x|.
	func cup_field(p: Vector3) -> float:
		var u: float = (p.x - AnimeOutfit.BUST_APEX.x) / (AnimeOutfit.BUST_R_OUT if p.x > AnimeOutfit.BUST_APEX.x else AnimeOutfit.BUST_R_IN)
		var v: float = (p.y - AnimeOutfit.BUST_APEX.y) / (AnimeOutfit.BUST_R_UP if p.y > AnimeOutfit.BUST_APEX.y else AnimeOutfit.BUST_R_DOWN)
		var cut: Vector2 = AnimeOutfit.skin_cut(clampf(v, AnimeOutfit.CUP_BOTTOM_V, AnimeOutfit.CUP_TOP_V))
		return minf(minf(u - cut.x - CUP_INSET.x, cut.y - CUP_INSET.y - u), minf(v - AnimeOutfit.CUP_BOTTOM_V - CUP_INSET.z,
				AnimeOutfit.CUP_TOP_V - v))

	func torso_region(p: Vector3, bust: bool = true) -> String:
		if bust and kind != AnimeOutfit.MALE and p.z < -0.02 and cup_field(Vector3(absf(p.x), p.y, p.z)) > 0.0:
			return "bust_L" if p.x < 0.0 else "bust_R"
		for c: Array in TORSO_CUTS:
			if p.y < float(c[1]):
				return str(c[0])
		return "neck"

	## How far p lies outside a code-skin piece (negative inside, INF where the piece does not reach p): "torso" (the
	## torso loft), "pelvis" (the same, down to the seats' gusset), "upper_arm" (that side's upper arm loft and deltoid
	## cap), "thigh" (that side's thigh loft) or "shin" (that side's knee ball, kneecap and calf loft).
	func piece_out(p: Vector3, piece: String, side: String) -> float:
		var shs: Array = []
		if piece == "torso":
			shs = shapes(p, "torso", "")
		elif piece == "upper_arm":
			var secs: Array = _limb_secs("upper_arm", side)
			for sh: Array in shapes(p, "arm", side):
				if str(sh[0]) == "loft" and sh[2] == secs:
					shs.append(sh)
			var dc: Vector4 = AnimeOutfit.deltoid(kind)
			var up: Transform3D = rest[side + "UpperArm"]
			shs.append(["blob", Transform3D(Basis.IDENTITY, Vector3(0.0, -dc.w, 0.0)) * up.affine_inverse(), Vector3(dc.x, dc.y, dc.z)])
		elif piece == "pelvis":
			# Down to the shorts' gusset below the loft's end (SEAT_GUSSET): the crotch the seat closes round.
			var y0: float = float(torso[0][0])
			if p.y < y0 and p.y >= y0 - SEAT_GUSSET:
				return float(outside(Vector3(p.x, y0, p.z), ["loft", Transform3D.IDENTITY, torso], 0.0)[0])
			shs = shapes(p, "torso", "")
		else:
			for sh: Array in shapes(p, "leg", side):
				var shin: bool = str(sh[0]) == "blob" or sh[2] != _limb_secs("thigh", side)
				if (piece == "shin") == shin and not (str(sh[0]) == "loft" and sh[1] == Transform3D.IDENTITY):
					shs.append(sh)
		var out: float = INF
		for sh: Array in shs:
			out = minf(out, float(outside(p, sh, 0.0)[0]))
		return out

	func _limb_secs(part: String, side: String) -> Array:
		for lb: Array in limbs:
			if lb[0] == part and lb[1] == side:
				return lb[3]
		return []

	## Code-skin shapes near p: [kind, transform to the shape's space, data] where kind is "loft" (data: smoothed
	## sections, y along the axis) or "blob" (data: Vector3 radii of an ellipsoid at the origin).
	## group: "torso", "arm" or "leg" (the code-skin parts a region's garment pieces were lofted round), side "Left" or
	## "Right" for the limbs.
	func shapes(p: Vector3, group: String, side: String) -> Array:
		var out: Array = []
		if group != "arm":
			# The thighs run up into the pelvis loft (the seat and the hip joint's crease are the pelvis piece's).
			if p.y >= float(torso[0][0]) and p.y <= float(torso[torso.size() - 1][0]):
				out.append(["loft", Transform3D.IDENTITY, torso])
		if group == "torso":
			return out
		for lb: Array in limbs:
			if str(lb[1]) != side or (group == "arm") != (lb[0] in ["upper_arm", "forearm"]):
				continue
			var xf: Transform3D = (rest[lb[2]] as Transform3D).affine_inverse()
			var q: Vector3 = xf * p
			var secs: Array = lb[3]
			if q.y <= float(secs[0][0]) and q.y >= float(secs[secs.size() - 1][0]):
				out.append(["loft", xf, secs])
		var m: bool = kind == AnimeOutfit.MALE
		if group == "arm":
			var dc: Vector4 = AnimeOutfit.deltoid(kind)
			var up: Transform3D = rest[side + "UpperArm"]
			out.append(["blob", Transform3D(Basis.IDENTITY, Vector3(0.0, -dc.w, 0.0)) * up.affine_inverse(), Vector3(dc.x, dc.y, dc.z)])
			var r: float = 0.034 if m else 0.029
			out.append(["blob", (rest[side + "LowerArm"] as Transform3D).affine_inverse(), Vector3(r, r, r)])
		else:
			var lower: Transform3D = (rest[side + "LowerLeg"] as Transform3D).affine_inverse()
			var r: float = 0.048 if m else 0.045
			out.append(["blob", lower, Vector3(r, r, r)])
			out.append(["blob", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.008, 0.032)) * lower,
					Vector3(0.026, 0.03, 0.017) if m else Vector3(0.024, 0.028, 0.016)])
		return out

	## How far p lies outside a shape (negative inside), and the point on the shape (+ tol) it would be pulled to.
	func outside(p: Vector3, sh: Array, tol: float) -> Array:
		var xf: Transform3D = sh[1]
		var q: Vector3 = xf * p
		if str(sh[0]) == "blob":
			var rad: Vector3 = sh[2]
			var k: float = (q / rad).length()
			var dist: float = q.length()
			if dist < 1e-5:
				return [-1.0, p]
			var surf: float = dist / k
			return [dist - surf, xf.affine_inverse() * (q * ((surf + tol) / dist))]
		var sec: Array = SkaterParts.section_at(sh[2], q.y)
		var lift: float = bust_lift(p) if xf == Transform3D.IDENTITY else 0.0
		var c: Vector3 = Vector3(float(sec[6]), q.y, float(sec[5]))
		var off: Vector3 = q - c
		var rad2: float = Vector2(off.x, off.z).length()
		if rad2 < 1e-5:
			return [-1.0, p]
		var r: float = ratio(sec, q.x, q.z)
		var surf2: float = rad2 / r + lift
		return [rad2 - surf2, xf.affine_inverse() * (c + off * ((surf2 + tol) / rad2))]

	## The point pulled in to FIT_TOLERANCE outside the nearest code-skin shape of its region's part (torso, that arm
	## or that leg), when it lies outside all of them by more (unchanged inside any of them; the head, hands and feet
	## are left alone, and the female bust field is first conformed to the code bust).
	func fitted(p_in: Vector3, reg: String, extra: float = 0.0) -> Vector3:
		var p: Vector3 = p_in
		var base: String = reg
		if base.ends_with("_L") or base.ends_with("_R"):
			base = base.left(base.length() - 2)
		if base in ["head", "hand", "foot"] or base.ends_with("_cap") or not HOME.has(base):
			return p_in
		if in_bust_field(p):
			p = conform(p)
		elif base == "bust":
			return p
		var group: String = "torso"
		var side: String = ""
		var home: String = str(HOME[base])
		if home in ["UpperArm", "LowerArm", "UpperLeg", "LowerLeg"]:
			side = "Left" if reg.ends_with("_L") else "Right"
			group = "arm" if home in ["UpperArm", "LowerArm"] else "leg"
		var tol: float = FIT_TOLERANCE - float(SHRINK.get(base, 0.0)) - extra
		var best_out: float = INF
		var best_p: Vector3 = p
		for sh: Array in shapes(p, group, side):
			var o: Array = outside(p, sh, tol)
			if float(o[0]) < best_out:
				best_out = float(o[0])
				best_p = o[1]
		if best_out <= tol or best_out == INF:
			return p
		return best_p

	## True on the front of the female ribcage within the bust forms' rim.
	func in_bust_field(p: Vector3) -> bool:
		if kind == AnimeOutfit.MALE or p.z > -0.02:
			return false
		return bust_d2(p) < 1.0

	func bust_d2(p: Vector3) -> float:
		var dx: float = absf(p.x) - AnimeOutfit.BUST_APEX.x
		var dy: float = p.y - AnimeOutfit.BUST_APEX.y
		var u: float = dx / (AnimeOutfit.BUST_R_OUT if dx > 0.0 else AnimeOutfit.BUST_R_IN)
		var v: float = dy / (AnimeOutfit.BUST_R_UP if dy > 0.0 else AnimeOutfit.BUST_R_DOWN)
		return u * u + v * v

	## A point of the female bust field moved (along z) onto the code skin's bust form, fading out toward the rim,
	## so the bikini cups, built on that form, fit it.
	func conform(p: Vector3) -> Vector3:
		# The code surface's point over (x, y): its field coordinates shifted until its own x, y land on p's.
		var q: Vector2 = Vector2(p.x, p.y)
		var target: Vector3 = AnimeOutfit.chest_front_point(q.x, q.y, 0.0, kind)
		for i: int in 6:
			q += Vector2(p.x - target.x, p.y - target.y)
			target = AnimeOutfit.chest_front_point(q.x, q.y, 0.0, kind)
		var w: float = smoothstep(1.0, 0.8, bust_d2(p))
		return Vector3(p.x, p.y, lerpf(p.z, target.z, w))
