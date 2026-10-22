class_name VrmBody
extends SkeletonModifier3D
## The lead skater's body: a finished VRoid anime model (VRM 0.x, assets/characters/vrm/lead_<type>.vrm, imported by
## the godot-vrm addon with MToon materials), driven by the code-built joint rig (PlaceholderSkater.build_body, posed
## by SkaterPoser). Pipeline and follow-ups: docs/vrm_pipeline.md.
##
## The VRM instance hangs under the body root, turned to face -Z (VRM models face +Z) and scaled uniformly by SCALE.
## Each skeleton update this modifier retargets the code joints onto the VRM humanoid bones (the 17
## SkaterPoser.JOINTS share their VRM names):
## - Rotations, not positions. Bone global basis = joint global basis * C, with C computed once from the joint's
##   T-pose-equivalent neutral (the code rig's zero pose with the upper arms raised to the side, see neutral_basis())
##   and the bone's global rest basis, so the VRM rest T-pose maps onto the code rig's T-pose. Bones keep their own
##   rest offsets (lengths).
## - Hips also take the joint's position (plus LEG_LIFT, the extra length of the VRM legs, so the knee bend matches).
## - Legs: two-bone IK on the VRM's own leg lengths puts each VRM ankle exactly on the code ankle (the poser's IK
##   target on the deck), the knee bending toward the code knee. The code shoes (Wardrobe, under the code Foot joints)
##   therefore sit exactly where they always did, and the bare VRM foot is shrunk (FOOT_SHRINK) to stay inside them.
## - Arms: rotation retarget (FK). While the poser grabs (its blended pose's "grip_L"/"grip_R"), arm IK pulls the
##   VRM wrist onto the code wrist, bending the spine toward the grab when the shorter VRM arm cannot reach.
## - Unmapped: UpperChest and the shoulders keep rest; fingers keep a relaxed curl and close into a grip with the
##   grip weight; toes keep rest. J_Sec_L/R_Bust1 follow the BodySway_BustL/R pivots (SecondaryMotion; its bust
##   toggle stops them). Hair (and the skirt) swing on the VRM's own spring bones (the addon's VRMSecondary, which
##   runs as an internal modifier after this one). The face blinks on a fixed timer (the Fcl_EYE_Close blend shape).
##
## Outfit (prepare()): the model's own shoes are always hidden (the game's skate shoes are drawn instead). The female
## dress is hidden, and the body drawn with a bikini skin texture, ONLY when the coral bikini skin exists in
## assets/characters/vrm/textures/ (BIKINI_FLAGS); until then the dress stays on. Never nude. The texture worker's
## golden blonde hair textures (HAIR_KEYS: <key>.png, <key>_shade.png, <key>_emission.png, hair_gold_params.json)
## and eye_iris.png replace the originals when present. Materials are duplicates of the imported MToon materials with
## their textures swapped (shared per material and file); the import is never edited.
##
## Use: VrmBody.attach(body_root, body_type, mats) (PlaceholderSkater.build_body does it for skin "vrm").

const PATHS: Dictionary = {
	"female": "res://assets/characters/vrm/lead_female.vrm",
	"male": "res://assets/characters/vrm/lead_male.vrm",
}
const TEXTURE_DIR: String = "res://assets/characters/vrm/textures/"
## The bikini skin texture (either name) whose presence switches the female body from the dress to the bikini, and
## the prefixes of its colourways ("<prefix><colour>.png").
const BIKINI_FLAGS: PackedStringArray = ["lead_female_body_bikini_coral.png", "body_skin_bikini_coral.png"]
const BIKINI_PREFIXES: PackedStringArray = ["lead_female_body_bikini_", "body_skin_bikini_"]
## Hair material (resource name suffix) -> texture key.
const HAIR_KEYS: Dictionary = {
	"_Hair_00_HAIR_01": "hair_main", "_Hair_00_HAIR_02": "hair_main2", "_Hair_00_HAIR_03": "ribbon",
	"_HairBack_00_HAIR": "hair_back",
}
const HAIR_PARAMS: String = "hair_gold_params.json"
const IRIS_FILE: String = "eye_iris.png"
## The palette skin colour that leaves the model's skin at SKIN_TINT (a light tan under the game's bright sun; the
## VRoid skin texture alone reads chalk white there). Other skin tones scale the tint per channel.
const SKIN_REFERENCE: Color = Color(0.9, 0.69, 0.52)
const SKIN_TINT: Color = Color(0.96, 0.83, 0.72)
const HAIR_TINT: Color = Color(0.93, 0.9, 0.86)  ## keeps the golden hair from clipping to white in full sun
## Bikini colourways by file suffix; the palette "top" colour picks the nearest one that exists.
const BIKINI_COLOURS: Dictionary = {
	"coral": Color(1.0, 0.435, 0.38),
	"blue": Color(0.18, 0.525, 0.87),
	"ocean": Color(0.18, 0.525, 0.87),
	"teal": Color(0.07, 0.66, 0.7),
}
## Uniform scale of each model: G stands 1.74 m (crown) and base_male 1.72 m, so about 1.62 m / 1.69 m in game, a
## young adult next to the 0.8 m deck. (Matching the hip height to the code leg exactly would make her 1.52 m.)
const SCALE: Dictionary = {"female": 0.93, "male": 0.98}
const FOOT_SHRINK: float = 0.86  ## bare VRM foot scale, so it stays inside the code shoe
const BUST_GAIN: float = 1.0  ## share of the bust pivot's sway the bust bones take
const REACH_SLACK: float = 0.985  ## arm IK aims for this share of the full arm length
const MAX_REACH_BEND: float = deg_to_rad(40.0)  ## most extra spine bend toward a grab
## Extra outward swing of the whole arm (radians, about the upper arm's own forward axis): the VRoid shoulders are
## narrower than the code rig's, so without it the relaxed hands hang in front of the hips instead of beside them.
const ARM_SPREAD: float = deg_to_rad(9.0)
## Relaxed finger curl per joint (degrees: proximal, intermediate, distal) and the full grip.
const CURL_RELAXED: Array[float] = [12.0, 18.0, 12.0]
const CURL_GRIP: Array[float] = [62.0, 80.0, 55.0]
const THUMB_RELAXED: float = 8.0
const THUMB_GRIP: float = 32.0
const FINGERS: PackedStringArray = ["Index", "Middle", "Ring", "Little"]
const PHALANGES: PackedStringArray = ["Proximal", "Intermediate", "Distal"]
## Seconds between blinks (cycled) and one blink's length.
const BLINK_GAPS: Array[float] = [3.2, 4.6, 2.4, 5.1, 3.8, 1.2]
const BLINK_TIME: float = 0.16
const EXTRA_BUST: Dictionary = {"J_Sec_L_Bust1": "BodySway_BustL", "J_Sec_R_Bust1": "BodySway_BustR"}

var body_root: Node3D  ## the code-built SkaterBody whose joints drive the bones
var body_type: String = "female"
var model: Node3D  ## the VRM instance
var face: MeshInstance3D
var meshes: Array[MeshInstance3D] = []
var bikini: bool = false  ## true when the dress is hidden and the bikini skin is drawn
var hair_swapped: bool = false
var blink_enabled: bool = true

var _bound: bool = false
var _order: PackedInt32Array = PackedInt32Array()  ## bones to evaluate, parents first
var _parent: PackedInt32Array = PackedInt32Array()
var _rest: Array[Transform3D] = []  ## local rest of every bone
var _role: Dictionary = {}  ## bone -> "joint" | "finger" | "thumb" | "bust" | "foot"
var _joint: Dictionary = {}  ## bone -> driving code Node3D
var _corr: Dictionary = {}  ## bone -> Basis C (skeleton space)
var _axis: Dictionary = {}  ## bone -> local bone direction (unit, toward its child) for the IK swing
var _len: Dictionary = {}  ## bone -> length to its child
var _curl_axis: Dictionary = {}  ## finger bone -> local curl axis
var _curl_k: Dictionary = {}  ## finger bone -> [phalanx index, side "L"/"R", thumb]
var _bust_rest: Dictionary = {}  ## bust bone -> rest Transform3D of its code pivot
var _bone: Dictionary = {}  ## bone name -> index
var _names: PackedStringArray = PackedStringArray()  ## index -> bone name
var _k: Transform3D = Transform3D.IDENTITY  ## skeleton space -> body space
var _kr: Basis = Basis.IDENTITY  ## rotation part of _k
var _lift: float = 0.0
var _blink_idx: int = -1
var _blink_t: float = 0.0
var _blink_gap: int = 0
var _poser: Object = null
var _globals: Array[Transform3D] = []

## Prepared meshes and materials shared by every body of one model and outfit: key -> {mesh name -> Mesh}.
static var _prepared: Dictionary = {}
static var _mat_cache: Dictionary = {}


## Instantiates the body type's VRM under body (facing -Z, scaled), dresses it (prepare()) and returns its modifier,
## already driving the skeleton. Returns null when the model or its Skeleton3D is missing.
static func attach(body: Node3D, kind: String = "", mats: Dictionary = {}) -> VrmBody:
	var bt: String = kind if kind != "" else str(body.get_meta("body_type", "female"))
	if not PATHS.has(bt):
		bt = "female"
	var path: String = str(PATHS[bt])
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return null
	var inst: Node3D = scene.instantiate() as Node3D
	inst.name = "VrmModel"
	var s: float = float(SCALE.get(bt, 0.93))
	inst.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * s), Vector3.ZERO)
	body.add_child(inst)
	var skel: Skeleton3D = SkinnedBody.find_skeleton(inst)
	if skel == null:
		inst.queue_free()
		return null
	var vb: VrmBody = VrmBody.new()
	vb.name = "VrmDriver"
	vb.body_root = body
	vb.body_type = bt
	vb.model = inst
	skel.add_child(vb)
	vb.prepare(_top_colour(mats), skin_tint(_mat_colour(mats, "skin", SKIN_REFERENCE)))
	vb.bind()
	vb.sync_pose()
	return vb


static func _mat_colour(mats: Dictionary, key: String, fallback: Color) -> Color:
	var m: Variant = mats.get(key)
	if m is StandardMaterial3D:
		return (m as StandardMaterial3D).albedo_color
	return fallback


## The MToon colour multiplier for a palette skin colour (SKIN_TINT for the default skin).
static func skin_tint(skin: Color) -> Color:
	return Color(clampf(SKIN_TINT.r * skin.r / SKIN_REFERENCE.r, 0.2, 1.0),
			clampf(SKIN_TINT.g * skin.g / SKIN_REFERENCE.g, 0.2, 1.0),
			clampf(SKIN_TINT.b * skin.b / SKIN_REFERENCE.b, 0.2, 1.0))


static func _top_colour(mats: Dictionary) -> Color:
	var m: Variant = mats.get("top")
	if m is StandardMaterial3D:
		return (m as StandardMaterial3D).albedo_color
	return BIKINI_COLOURS["coral"]


## True when the texture worker's bikini skin is there (the dress may come off).
static func bikini_available() -> bool:
	for f: String in BIKINI_FLAGS:
		if ResourceLoader.exists(TEXTURE_DIR + f):
			return true
	return false


## Texture files (names) in TEXTURE_DIR starting with prefix and ending in .png, sorted. Works in exported builds.
static func texture_files(prefix: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f: String in ResourceLoader.list_directory(TEXTURE_DIR):
		if f.begins_with(prefix) and f.ends_with(".png"):
			out.append(f)
	out.sort()
	return out


## The bikini texture file closest in colour to `top` (coral when nothing better matches), or "" when none exists.
static func bikini_file(top: Color) -> String:
	var best: String = ""
	var best_d: float = INF
	for prefix: String in BIKINI_PREFIXES:
		for f: String in texture_files(prefix):
			var key: String = f.trim_prefix(prefix).trim_suffix(".png")
			var c: Color = BIKINI_COLOURS.get(key, BIKINI_COLOURS["coral"])
			var d: float = Vector3(c.r - top.r, c.g - top.g, c.b - top.b).length() + (0.0 if BIKINI_COLOURS.has(key) else 10.0)
			if d < best_d:
				best_d = d
				best = f
	return best


## Texture key of a hair material (by resource name), or "".
static func hair_key(material_name: String) -> String:
	for suffix: String in HAIR_KEYS:
		if material_name.ends_with(suffix):
			return str(HAIR_KEYS[suffix])
	return ""


## Shader parameter -> value swaps for a hair key (main, shade, emission textures and the colour params), empty when
## the texture worker has no texture for it.
static func hair_swaps(key: String) -> Dictionary:
	var out: Dictionary = {}
	if key == "" or not ResourceLoader.exists(TEXTURE_DIR + key + ".png"):
		return out
	out["_MainTex"] = TEXTURE_DIR + key + ".png"
	out["_ShadeTexture"] = TEXTURE_DIR + key + ("_shade.png" if ResourceLoader.exists(TEXTURE_DIR + key + "_shade.png") else ".png")
	if ResourceLoader.exists(TEXTURE_DIR + key + "_emission.png"):
		out["_EmissionMap"] = TEXTURE_DIR + key + "_emission.png"
	if FileAccess.file_exists(TEXTURE_DIR + HAIR_PARAMS):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXTURE_DIR + HAIR_PARAMS))
		if data is Dictionary and (data as Dictionary).get(key) is Dictionary:
			var prm: Dictionary = (data as Dictionary)[key]
			for k: String in prm:
				var v: Variant = prm[k]
				if v is Array and (v as Array).size() == 4:
					out[k] = Color(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return out


# --- outfit -------------------------------------------------------------------------------------------------------

## Swaps the meshes of the model for the outfit's: model shoes always dropped, the dress dropped and the bikini skin
## drawn when bikini_available(), golden hair textures when present. Built once per model and outfit, then shared.
func prepare(top: Color = BIKINI_COLOURS["coral"], tint: Color = SKIN_TINT) -> void:
	meshes.clear()
	if model == null:
		return
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(n as MeshInstance3D)
	face = model.find_child("Face", true, false) as MeshInstance3D
	var bikini_tex: String = bikini_file(top) if body_type == "female" and bikini_available() else ""
	bikini = bikini_tex != ""
	var golden: bool = body_type == "female" and not hair_swaps("hair_main").is_empty()
	hair_swapped = golden
	var key: String = "%s|%s|%s|%s" % [body_type, bikini_tex, str(golden), tint.to_html()]
	if not _prepared.has(key):
		var made: Dictionary = {}
		for mi: MeshInstance3D in meshes:
			made[str(mi.name)] = _prepared_mesh(mi.mesh as ArrayMesh, bikini_tex, golden, tint)
		_prepared[key] = made
	var ready: Dictionary = _prepared[key]
	for mi: MeshInstance3D in meshes:
		if ready.get(str(mi.name)) != null:
			mi.mesh = ready[str(mi.name)]
		mi.set_meta("vrm", true)
	_trim_springs()


## Drops the model's own spring chains this body drives or no longer draws: the bust (SecondaryMotion drives it
## through the BodySway pivots, with the player's setting), the skirt (it flew up as the knees bent; the dress is
## only a stand-in until the bikini skin exists) and, with the dress hidden, the sleeves. Hair keeps its springs.
func _trim_springs() -> void:
	var sec: Node = model.get_node_or_null("secondary")
	if sec == null or not ("spring_bones" in sec):
		return
	var springs: Array = sec.get("spring_bones")
	var kept: Array = springs.duplicate()
	kept.clear()
	for sb: Resource in springs:
		var first: String = ""
		var joints: PackedStringArray = sb.get("joint_nodes") if sb != null else PackedStringArray()
		if not joints.is_empty():
			first = joints[0]
		if first.contains("Bust") or first.contains("Skirt") or (bikini and first.contains("Sleeve")):
			continue
		kept.append(sb)
	sec.set("spring_bones", kept)
	if "spring_bones" in model:
		model.set("spring_bones", kept)


## A copy of `src` without the dropped surfaces and with swapped materials (null when nothing changes).
func _prepared_mesh(src: ArrayMesh, bikini_tex: String, golden: bool, tint: Color) -> ArrayMesh:
	if src == null:
		return null
	var changed: bool = false
	var keep: Array[int] = []
	var mats: Array[Material] = []
	for s: int in src.get_surface_count():
		var mat: Material = src.surface_get_material(s)
		var nm: String = mat.resource_name if mat != null else ""
		if nm.contains("_Shoes_") or (bikini_tex != "" and nm.contains("_Onepice_")):
			changed = true
			continue
		var swapped: Material = mat
		if nm.ends_with("_SKIN"):
			# No skin matcap: VRoid's additive _SphereAdd sheen blows out to a flat cream patch wherever a bent limb's
			# normal faces a low camera (inner thigh in a crouch seen from below, wrists).
			var sw: Dictionary = {"_Color": tint, "_ShadeColor": _shade_of(mat, tint), "_SphereAdd": null}
			if bikini_tex != "" and nm.contains("_Body_"):
				sw["_MainTex"] = TEXTURE_DIR + bikini_tex
				sw["_ShadeTexture"] = TEXTURE_DIR + bikini_tex
			swapped = _swapped(mat, sw)
		elif body_type == "female" and (hair_key(nm) != "" or nm.ends_with("_HAIR")):
			var sw: Dictionary = hair_swaps(hair_key(nm)) if golden else {}
			var c: Variant = sw.get("_Color", Color.WHITE)
			sw["_Color"] = (c as Color) * HAIR_TINT if c is Color else HAIR_TINT
			swapped = _swapped(mat, sw)
		elif golden and nm.contains("_EyeIris_") and ResourceLoader.exists(TEXTURE_DIR + IRIS_FILE):
			var t: String = TEXTURE_DIR + IRIS_FILE
			swapped = _swapped(mat, {"_MainTex": t, "_ShadeTexture": t})
		if swapped != mat:
			changed = true
		keep.append(s)
		mats.append(swapped)
	if not changed:
		return null
	var out: ArrayMesh = ArrayMesh.new()
	for i: int in keep.size():
		var s: int = keep[i]
		var flags: int = src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		var bs: Array = src.surface_get_blend_shape_arrays(s)
		if out.get_surface_count() == 0:
			for b: int in src.get_blend_shape_count():
				out.add_blend_shape(src.get_blend_shape_name(b))
			out.blend_shape_mode = src.blend_shape_mode
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), src.surface_get_arrays(s), bs, {}, flags)
		out.surface_set_material(i, mats[i])
		out.surface_set_name(i, src.surface_get_name(s))
	return out


## The material's shade colour times tint.
static func _shade_of(mat: Material, tint: Color) -> Color:
	var c: Variant = (mat as ShaderMaterial).get_shader_parameter("_ShadeColor") if mat is ShaderMaterial else null
	return ((c as Color) if c is Color else Color.WHITE) * tint


## A duplicate of an MToon material with shader parameters replaced: values that are res:// paths load as textures.
## Shared per material and swap set.
static func _swapped(mat: Material, swaps: Dictionary) -> Material:
	var key: String = "%d|%s" % [mat.get_instance_id(), str(swaps)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	if not (mat is ShaderMaterial):
		return mat
	var m: ShaderMaterial = mat.duplicate() as ShaderMaterial
	for p: String in swaps:
		var v: Variant = swaps[p]
		if v is String:
			var tex: Texture2D = load(str(v)) as Texture2D
			if tex == null:
				return mat
			v = tex
		m.set_shader_parameter(p, v)
	_mat_cache[key] = m
	return m


# --- binding ------------------------------------------------------------------------------------------------------

## T-pose-equivalent body-space basis of a code joint: the zero pose, with the upper arms (and so the forearms and
## hands) raised straight out to the side as in the VRM rest pose.
static func neutral_basis(joint: String) -> Basis:
	if joint.begins_with("Left") and (joint.ends_with("Arm") or joint.ends_with("Hand")):
		return Basis(Vector3.BACK, -PI * 0.5)
	if joint.begins_with("Right") and (joint.ends_with("Arm") or joint.ends_with("Hand")):
		return Basis(Vector3.BACK, PI * 0.5)
	return Basis.IDENTITY


## Builds the bone tables and per-bone corrections. Call again if the code rig is rebuilt.
func bind() -> void:
	_bound = false
	var skel: Skeleton3D = _skel()
	if skel == null:
		return
	if body_root == null:
		body_root = _find_body_root()
	if body_root == null:
		return
	if model == null:
		model = skel.get_parent() as Node3D
	_k = _skeleton_to_body(skel)
	_kr = _k.basis.orthonormalized()
	var n: int = skel.get_bone_count()
	_parent.resize(n)
	_rest.clear()
	_bone.clear()
	_names.resize(n)
	for b: int in n:
		_parent[b] = skel.get_bone_parent(b)
		_rest.append(skel.get_bone_rest(b))
		_bone[skel.get_bone_name(b)] = b
		_names[b] = skel.get_bone_name(b)
	_role.clear()
	_joint.clear()
	_corr.clear()
	_axis.clear()
	_len.clear()
	_curl_axis.clear()
	_curl_k.clear()
	_bust_rest.clear()
	for j: String in SkaterPoser.JOINTS:
		var b: int = int(_bone.get(j, -1))
		var node: Node3D = body_root.find_child(j, true, false) as Node3D
		if b < 0 or node == null:
			continue
		_role[b] = "joint"
		_joint[b] = node
		var rest_g: Basis = skel.get_bone_global_rest(b).basis
		_corr[b] = neutral_basis(j).inverse() * _kr * rest_g
	for limb: String in ["UpperLeg", "LowerLeg", "UpperArm", "LowerArm"]:
		for side: String in ["Left", "Right"]:
			var b: int = int(_bone.get(side + limb, -1))
			var c: int = int(_bone.get(side + _child_of(limb), -1))
			if b < 0 or c < 0:
				continue
			var d: Vector3 = _rest[c].origin
			_len[b] = d.length()
			_axis[b] = d.normalized()
	for side: String in ["Left", "Right"]:
		_bind_fingers(skel, side)
		var foot: int = int(_bone.get(side + "Foot", -1))
		if foot >= 0:
			_role[foot] = "foot"
	for bust: String in EXTRA_BUST:
		var b: int = int(_bone.get(bust, -1))
		var pivot: Node3D = body_root.find_child(str(EXTRA_BUST[bust]), true, false) as Node3D
		if b >= 0 and pivot != null:
			_role[b] = "bust"
			_joint[b] = pivot
			_bust_rest[b] = pivot.transform
	var legs: float = float(_len.get(int(_bone.get("LeftUpperLeg", -1)), 0.0)) + float(_len.get(int(_bone.get("LeftLowerLeg", -1)), 0.0))
	_lift = legs * _k.basis.get_scale().x - (PlaceholderSkater.UPPER_LEG + PlaceholderSkater.LOWER_LEG)
	_build_order()
	_globals.resize(n)
	_find_face_blink()
	_bound = true


static func _child_of(limb: String) -> String:
	match limb:
		"UpperLeg": return "LowerLeg"
		"LowerLeg": return "Foot"
		"UpperArm": return "LowerArm"
	return "Hand"


func _bind_fingers(skel: Skeleton3D, side: String) -> void:
	var hand: int = int(_bone.get(side + "Hand", -1))
	var mid: int = int(_bone.get(side + "MiddleProximal", -1))
	if hand < 0 or mid < 0:
		return
	var hand_g: Transform3D = skel.get_bone_global_rest(hand)
	var dir: Vector3 = (skel.get_bone_global_rest(mid).origin - hand_g.origin).normalized()
	var palm: Vector3 = Vector3.DOWN  ## VRM T-pose: palms down
	var axis_s: Vector3 = dir.cross(palm).normalized()
	for f: String in FINGERS:
		for i: int in PHALANGES.size():
			var b: int = int(_bone.get(side + f + PHALANGES[i], -1))
			if b < 0:
				continue
			_role[b] = "finger"
			_curl_axis[b] = (skel.get_bone_global_rest(b).basis.inverse() * axis_s).normalized()
			_curl_k[b] = i
	for i: int in 3:
		var b: int = int(_bone.get(side + "Thumb" + ["Metacarpal", "Proximal", "Distal"][i], -1))
		if b < 0:
			continue
		var g: Transform3D = skel.get_bone_global_rest(b)
		var kids: PackedInt32Array = skel.get_bone_children(b)
		var tdir: Vector3 = (skel.get_bone_global_rest(kids[0]).origin - g.origin).normalized() if kids.size() > 0 else dir
		# The thumb folds across the palm: about the axis across its own direction and the palm normal, tipped in.
		var t_axis: Vector3 = tdir.cross(palm).normalized()
		_role[b] = "thumb"
		_curl_axis[b] = (g.basis.inverse() * t_axis).normalized()
		_curl_k[b] = i


## Bones worth evaluating (driven ones and their ancestors), parents first.
func _build_order() -> void:
	var n: int = _parent.size()
	var need: PackedByteArray = PackedByteArray()
	need.resize(n)
	for b: int in _role.keys():
		var p: int = b
		while p >= 0 and need[p] == 0:
			need[p] = 1
			p = _parent[p]
	var depth: Array = []
	for b: int in n:
		if need[b] == 0:
			continue
		var d: int = 0
		var p: int = _parent[b]
		while p >= 0:
			d += 1
			p = _parent[p]
		depth.append([d, b])
	depth.sort_custom(func(a: Array, c: Array) -> bool: return int(a[0]) < int(c[0]) or (int(a[0]) == int(c[0]) and int(a[1]) < int(c[1])))
	_order = PackedInt32Array()
	for e: Array in depth:
		_order.append(int(e[1]))


func _find_face_blink() -> void:
	_blink_idx = -1
	if face == null and model != null:
		face = model.find_child("Face", true, false) as MeshInstance3D
	if face == null or face.mesh == null:
		return
	for i: int in face.mesh.get_blend_shape_count():
		if str(face.mesh.get_blend_shape_name(i)).ends_with("_Fcl_EYE_Close"):
			_blink_idx = i
			return


## The body root a duplicated VrmBody belongs to (PedBody.clone duplicates without script variables).
func _find_body_root() -> Node3D:
	var n: Node = get_parent()
	while n != null:
		if n is Node3D and n.has_meta("body_type"):
			body_type = str(n.get_meta("body_type"))
			return n as Node3D
		n = n.get_parent()
	return null


func _skel() -> Skeleton3D:
	var s: Skeleton3D = get_skeleton()
	return s if s != null else get_parent() as Skeleton3D


func _skeleton_to_body(n: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	while n != null and n != body_root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


# --- per frame ----------------------------------------------------------------------------------------------------

func _process_modification_with_delta(delta: float) -> void:
	if not _bound:
		bind()
	_guard_materials()
	_tick_blink(delta)
	sync_pose()


## The toon pass (Toon.apply_to) replaces every mesh's material; the VRM keeps its MToon materials.
func _guard_materials() -> void:
	for mi: MeshInstance3D in meshes:
		if mi.material_override != null:
			mi.material_override = null


func _tick_blink(delta: float) -> void:
	if _blink_idx < 0 or face == null:
		return
	_blink_t += delta
	var gap: float = BLINK_GAPS[_blink_gap % BLINK_GAPS.size()]
	var v: float = 0.0
	if blink_enabled and _blink_t > gap:
		var u: float = (_blink_t - gap) / BLINK_TIME
		if u >= 1.0:
			_blink_t = 0.0
			_blink_gap += 1
		else:
			v = minf(u / 0.4, 1.0) if u < 0.4 else 1.0 - (u - 0.4) / 0.6
	face.set_blend_shape_value(_blink_idx, v)


## Grip weights [left, right] of the poser driving this body (its blended pose), 0 when there is none.
func grip_weights() -> Vector2:
	if _poser == null and body_root != null and body_root.is_inside_tree():
		var n: Node = body_root
		for i: int in 3:
			if n == null:
				break
			n = n.get_parent()
			if n == null:
				break
			for c: Node in n.get_children():
				if c is SkaterPoser and (c as SkaterPoser).body == body_root:
					_poser = c
					break
			if _poser != null:
				break
	if _poser == null or not is_instance_valid(_poser):
		return Vector2.ZERO
	var cur: Variant = _poser.get("_current")
	if not (cur is Dictionary) or (cur as Dictionary).is_empty():
		return Vector2.ZERO
	var d: Dictionary = cur
	return Vector2(float(d.get("grip_L", 0.0)), float(d.get("grip_R", 0.0)))


## Retargets the current joint poses onto the bones (also callable by hand, e.g. from tests and captures).
func sync_pose() -> void:
	var skel: Skeleton3D = _skel()
	if skel == null:
		return
	if not _bound:
		bind()
		if not _bound:
			return
	var joints: Dictionary = _joint_globals()
	var grip: Vector2 = grip_weights()
	var bend: Basis = Basis.IDENTITY
	_evaluate(joints, grip, bend)
	# Grabs: when the (shorter) VRM arm cannot reach the code wrist, bend the spine toward it and solve again.
	for side: int in 2:
		var w: float = grip[side]
		if w < 0.05:
			continue
		var extra: Basis = _reach_bend("Left" if side == 0 else "Right", joints, w)
		if extra != Basis.IDENTITY:
			bend = extra * bend
	if bend != Basis.IDENTITY:
		_evaluate(joints, grip, bend)
	for b: int in _order:
		if not _role.has(b) and b != int(_bone.get("Spine", -1)):
			continue
		var p: int = _parent[b]
		var local: Transform3D = (_globals[p].affine_inverse() if p >= 0 else Transform3D.IDENTITY) * _globals[b]
		skel.set_bone_pose_position(b, local.origin)
		skel.set_bone_pose_rotation(b, local.basis.get_rotation_quaternion())
		skel.set_bone_pose_scale(b, local.basis.get_scale())


## Body-space transforms of the driving code nodes, by bone.
func _joint_globals() -> Dictionary:
	var out: Dictionary = {}
	var in_tree: bool = body_root.is_inside_tree()
	var inv_root: Transform3D = body_root.global_transform.affine_inverse() if in_tree else Transform3D.IDENTITY
	for b: int in _joint.keys():
		var node: Node3D = _joint[b]
		out[b] = inv_root * node.global_transform if in_tree else _skeleton_to_body(node)
	for side: String in ["Left", "Right"]:
		var ua: int = int(_bone.get(side + "UpperArm", -1))
		if ua < 0 or not out.has(ua):
			continue
		var j: Basis = (out[ua] as Transform3D).basis.orthonormalized()
		var spread: Basis = j * Basis(Vector3.BACK, -ARM_SPREAD if side == "Left" else ARM_SPREAD) * j.inverse()
		for limb: String in ["UpperArm", "LowerArm", "Hand"]:
			var b: int = int(_bone.get(side + limb, -1))
			if b >= 0 and out.has(b):
				var xf: Transform3D = out[b]
				out[b] = Transform3D(spread * xf.basis, xf.origin)  ## positions stay: grab IK aims at the real wrist
	return out


## Fills _globals (skeleton space) for the bones in _order. bend: extra rotation of the Spine bone about its origin.
func _evaluate(joints: Dictionary, grip: Vector2, bend: Basis) -> void:
	var inv_k: Transform3D = _k.affine_inverse()
	var inv_kr: Basis = _kr.inverse()
	var spine: int = int(_bone.get("Spine", -1))
	var ik: Dictionary = {}  ## bone -> desired direction (skeleton space) from an IK solve on its parent
	for b: int in _order:
		var p: int = _parent[b]
		var parent_g: Transform3D = _globals[p] if p >= 0 else Transform3D.IDENTITY
		var g: Transform3D = parent_g * _rest[b]
		var role: String = str(_role.get(b, ""))
		if role == "joint" or role == "foot":
			var j: Transform3D = joints[b]
			g.basis = inv_kr * j.basis.orthonormalized() * (_corr[b] as Basis)
			var bname: String = _bone_name(b)
			if bname == "Hips":
				var off: Vector3 = _k * _rest_global_origin(b) - Vector3(0.0, PlaceholderSkater.HIP_HEIGHT + _lift_drop(), 0.0)
				g.origin = inv_k * (j * off)
			if role == "foot":
				g.basis = g.basis.scaled_local(Vector3.ONE * FOOT_SHRINK)
			if ik.has(b):
				g.basis = _swing(g.basis, _axis[b], ik[b])
			if bname.ends_with("UpperLeg"):
				_solve_leg(b, g, joints, ik, inv_k)
				g.basis = _swing(g.basis, _axis[b], ik[b])
			elif bname.ends_with("UpperArm"):
				var w: float = grip.x if bname.begins_with("Left") else grip.y
				if w > 0.01:
					_solve_arm(b, g, joints, ik, inv_k, w)
					g.basis = _swing(g.basis, _axis[b], ik[b])
		elif role == "finger" or role == "thumb":
			var w: float = grip.x if _bone_name(b).begins_with("Left") else grip.y
			var i: int = int(_curl_k[b])
			var deg: float = lerpf(THUMB_RELAXED, THUMB_GRIP, w) if role == "thumb" else lerpf(CURL_RELAXED[i], CURL_GRIP[i], w)
			if role == "thumb" and i == 0:
				deg *= 0.5
			g = parent_g * _rest[b] * Transform3D(Basis(_curl_axis[b], deg_to_rad(deg)), Vector3.ZERO)
		elif role == "bust":
			g = _bust_global(b, parent_g, joints, inv_k)
		if b == spine and bend != Basis.IDENTITY:
			g.basis = bend * g.basis
		_globals[b] = g


func _bone_name(b: int) -> String:
	return _names[b] if b >= 0 and b < _names.size() else ""


func _rest_global_origin(b: int) -> Vector3:
	var xf: Transform3D = _rest[b]
	var p: int = _parent[b]
	while p >= 0:
		xf = _rest[p] * xf
		p = _parent[p]
	return xf.origin


## How far the VRM hips sit below their rest height relative to the code hips (the VRM legs are LEG_LIFT longer
## than the code legs, and the VRM hip joints sit that much above the code ones).
func _lift_drop() -> float:
	var ul: int = int(_bone.get("LeftUpperLeg", -1))
	if ul < 0:
		return 0.0
	var hip_y: float = (_k * _rest_global_origin(ul)).y
	return hip_y - PlaceholderSkater.HIP_HEIGHT - _lift


## Rotates basis so its local axis `local_dir` points along `want` (skeleton space), with the smallest swing.
static func _swing(basis: Basis, local_dir: Vector3, want: Vector3) -> Basis:
	var cur: Vector3 = (basis * local_dir).normalized()
	var w: Vector3 = want.normalized()
	if cur.is_equal_approx(w) or w == Vector3.ZERO:
		return basis
	var axis: Vector3 = cur.cross(w)
	if axis.length() < 0.000001:
		return basis
	return Basis(axis.normalized(), cur.angle_to(w)) * basis


## Two-bone IK of a VRM leg onto the code ankle, the knee toward the code knee. Fills ik for both bones.
func _solve_leg(b: int, g: Transform3D, joints: Dictionary, ik: Dictionary, inv_k: Transform3D) -> void:
	var side: String = "Left" if _bone_name(b).begins_with("Left") else "Right"
	var lower: int = int(_bone.get(side + "LowerLeg", -1))
	var foot: int = int(_bone.get(side + "Foot", -1))
	if lower < 0 or foot < 0 or not joints.has(foot) or not joints.has(lower) or not joints.has(b):
		return
	var hip_c: Vector3 = (joints[b] as Transform3D).origin
	var knee_c: Vector3 = (joints[lower] as Transform3D).origin
	var ankle_c: Vector3 = (joints[foot] as Transform3D).origin
	var target: Vector3 = inv_k * ankle_c
	var pole: Vector3 = inv_k.basis * (knee_c - (hip_c + ankle_c) * 0.5)
	var pts: Array[Vector3] = SkaterPoser.two_bone(g.origin, target, pole, float(_len[b]), float(_len[lower]))
	ik[b] = pts[1] - pts[0]
	ik[lower] = pts[2] - pts[1]


## Arm IK onto the code wrist, blended with the FK hand position by w. Fills ik for both bones.
func _solve_arm(b: int, g: Transform3D, joints: Dictionary, ik: Dictionary, inv_k: Transform3D, w: float) -> void:
	var side: String = "Left" if _bone_name(b).begins_with("Left") else "Right"
	var lower: int = int(_bone.get(side + "LowerArm", -1))
	var hand: int = int(_bone.get(side + "Hand", -1))
	if lower < 0 or hand < 0 or not joints.has(hand) or not joints.has(lower) or not joints.has(b):
		return
	var sh_c: Vector3 = (joints[b] as Transform3D).origin
	var el_c: Vector3 = (joints[lower] as Transform3D).origin
	var wr_c: Vector3 = (joints[hand] as Transform3D).origin
	var l1: float = float(_len[b])
	var l2: float = float(_len[lower])
	# FK wrist: the retargeted upper and lower arm.
	var lower_basis: Basis = _kr.inverse() * (joints[lower] as Transform3D).basis.orthonormalized() * (_corr[lower] as Basis)
	var elbow_fk: Vector3 = g.origin + g.basis * _rest[lower].origin
	var wrist_fk: Vector3 = elbow_fk + lower_basis * _rest[hand].origin
	var target: Vector3 = wrist_fk.lerp(inv_k * wr_c, w)
	var pole: Vector3 = inv_k.basis * (el_c - (sh_c + wr_c) * 0.5)
	var pts: Array[Vector3] = SkaterPoser.two_bone(g.origin, target, pole, l1 * REACH_SLACK, l2 * REACH_SLACK)
	ik[b] = pts[1] - pts[0]
	ik[lower] = pts[2] - pts[1]


## Extra Spine rotation (skeleton space) that brings the shoulder within reach of the code wrist, or IDENTITY.
func _reach_bend(side: String, joints: Dictionary, w: float) -> Basis:
	var ua: int = int(_bone.get(side + "UpperArm", -1))
	var la: int = int(_bone.get(side + "LowerArm", -1))
	var hand: int = int(_bone.get(side + "Hand", -1))
	var spine: int = int(_bone.get("Spine", -1))
	if ua < 0 or la < 0 or hand < 0 or spine < 0 or not joints.has(hand):
		return Basis.IDENTITY
	var reach: float = (float(_len[ua]) + float(_len[la])) * REACH_SLACK * 0.98
	var target: Vector3 = _k.affine_inverse() * (joints[hand] as Transform3D).origin
	var sh: Vector3 = _globals[ua].origin
	var pivot: Vector3 = _globals[spine].origin
	if sh.distance_to(target) <= reach:
		return Basis.IDENTITY
	var v: Vector3 = sh - pivot
	var u: Vector3 = target - pivot
	var axis: Vector3 = v.cross(u)
	if axis.length() < 0.000001:
		return Basis.IDENTITY
	axis = axis.normalized()
	var hi: float = minf(v.angle_to(u), MAX_REACH_BEND)
	var lo: float = 0.0
	for i: int in 12:
		var mid: float = (lo + hi) * 0.5
		if (pivot + v.rotated(axis, mid)).distance_to(target) > reach:
			lo = mid
		else:
			hi = mid
	return Basis(axis, hi * w)


## Bust bone: its rest under the upper chest, moved and tilted like its code BodySway pivot (scaled by BUST_GAIN).
func _bust_global(b: int, parent_g: Transform3D, joints: Dictionary, inv_k: Transform3D) -> Transform3D:
	var g: Transform3D = parent_g * _rest[b]
	var pivot: Node3D = _joint[b]
	var rest: Transform3D = _bust_rest[b]
	var chest: Transform3D = (joints[b] as Transform3D) * pivot.transform.affine_inverse()  ## the pivot's parent, body space
	var d_pos: Vector3 = chest.basis * (pivot.transform.origin - rest.origin) * BUST_GAIN
	var d_rot: Quaternion = (pivot.transform.basis * rest.basis.inverse()).get_rotation_quaternion()
	d_rot = Quaternion.IDENTITY.slerp(d_rot, BUST_GAIN)
	var rot_body: Basis = chest.basis.orthonormalized() * Basis(d_rot) * chest.basis.orthonormalized().inverse()
	g.basis = (_kr.inverse() * rot_body * _kr) * g.basis
	g.origin += inv_k.basis * d_pos
	return g


# --- queries for tools and tests ----------------------------------------------------------------------------------

## A driven bone's pose in body space as of the last retarget (call sync_pose() first when the joints moved since
## the last skeleton update). Other bones: their rest. (The skeleton itself drops modifier results after drawing.)
func bone_body_transform(bone: String) -> Transform3D:
	var b: int = int(_bone.get(bone, -1))
	if b < 0 or b >= _globals.size():
		return Transform3D.IDENTITY
	if _order.has(b):
		return _k * _globals[b]
	return _k * Transform3D(Basis.IDENTITY, _rest_global_origin(b))


## Standing height in body space (metres): the model's rest mesh bounds times its scale.
func standing_height() -> float:
	var top: float = -INF
	var bottom: float = INF
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		var bb: AABB = mi.mesh.get_aabb()
		top = maxf(top, bb.end.y)
		bottom = minf(bottom, bb.position.y)
	if top == -INF:
		return 0.0
	return (top - bottom) * _k.basis.get_scale().y


## Names of the surfaces (materials) the outfit draws, for tests: never a missing body, never nothing but skin.
func drawn_surfaces() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null or not mi.visible:
			continue
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			out.append(m.resource_name if m != null else "")
	return out
