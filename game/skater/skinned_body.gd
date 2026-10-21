class_name SkinnedBody
extends SkeletonModifier3D
## Drives a Blender-made skinned base body (assets/characters/base_body_<type>.glb) from the code-built joint rig
## (PlaceholderSkater.build_body, posed by SkaterPoser). Pilot of the Blender pipeline: docs/blender_pipeline.md.
##
## The .glb holds one smooth featureless mannequin mesh skinned to a Skeleton3D whose bones are named after the
## 17 SkaterPoser.JOINTS (same parents, bone heads at the joint positions), plus BustL/BustR (driven by the
## BodySway_BustL/R pivots) and a non-deforming HeadTop marker at the crown. The mesh was modelled in a neutral
## "model pose": every joint at its rest position with zero rotation (straight legs, straight elbows) except the
## upper arms, which hang out at NEUTRAL_ARM radians (an A pose, so the armpits skin cleanly).
##
## Each skeleton update this modifier copies the joints onto the bones:
##   bone global pose = joint pose (body space) * inverse(joint model-pose transform) * bone global rest
## so the bones follow the joints exactly whatever roll Blender gave them, and the mesh matches its model pose
## when the joints are in the model pose.
##
## Garment masking: every triangle of the mesh carries its body region index (REGIONS) in UV2.x. Call
## set_hidden_regions() with the regions the worn garments cover; the hidden triangles are dropped from the
## index buffer once, at dress time (one draw call, any material).
##
## Use: var sb: SkinnedBody = SkinnedBody.attach(body_root) after PlaceholderSkater.build_body(); then
## sb.hide_code_skin() hides the code-built skin meshes (the code head, hair and garments stay).
##
## Houdini body (the game's default skin, docs/houdini_pipeline.md): attach(body, type, "houdini") swaps in the mesh
## HoudiniBody.prepared() makes from assets/characters/houdini/base_body_<type>.glb (cut, region-tagged, fitted) and
## its per-triangle regions, in the code skin's region names. PlaceholderSkater.build_body does this itself and
## builds no code skin; Wardrobe.mask_skin() then calls set_hidden_regions() with the garments' covers.

const PATHS: Dictionary = {
	"female": "res://assets/characters/base_body_female.glb",
	"male": "res://assets/characters/base_body_male.glb",
}
## Upper arm |rotation.z| of the model pose (radians, out from the sides). Read by tools/blender/dump_rig.gd.
const NEUTRAL_ARM: float = 0.65
## Extra deform bones -> the code-rig node that drives them (children of Chest in both rigs).
const EXTRA_BONES: Dictionary = {"BustL": "BodySway_BustL", "BustR": "BodySway_BustR"}
## Body regions, in UV2.x index order. tools/blender/base_body.py parses this list, keep it one per line.
const REGIONS: PackedStringArray = [
	"neck",
	"chest_upper",
	"bust",
	"under_bust",
	"waist",
	"pelvis",
	"glutes",
	"upper_arm_L",
	"upper_arm_R",
	"forearm_L",
	"forearm_R",
	"hand_L",
	"hand_R",
	"thigh_upper_L",
	"thigh_upper_R",
	"thigh_lower_L",
	"thigh_lower_R",
	"knee_L",
	"knee_R",
	"calf_L",
	"calf_R",
	"ankle_L",
	"ankle_R",
	"foot_L",
	"foot_R",
]

var body_root: Node3D  ## the code-built SkaterBody whose joints drive the bones
var mesh_instance: MeshInstance3D
var _map: Array = []  ## [bone index, driving Node3D, correction Transform3D], parents before children
var _full_mesh: ArrayMesh
var region_names: PackedStringArray = PackedStringArray()  ## region index -> name (REGIONS for the Blender body)
var tri_region: PackedInt32Array = PackedInt32Array()  ## region index of each triangle of _full_mesh
var always_hidden: PackedStringArray = PackedStringArray()  ## regions never drawn (the Houdini head and hands)
var hidden_regions: PackedStringArray = PackedStringArray()  ## the regions hidden now (always_hidden included)

## Masked meshes shared by every body with the same full mesh and hidden set: "<full mesh id>|<sorted regions>".
static var _masked: Dictionary = {}


## Instantiates the body type's .glb under body_root (identity transform) and returns its modifier, already
## driving the skeleton. Returns null when the .glb or its Skeleton3D is missing.
## source: "blender" (assets/characters/base_body_<type>.glb, regions in UV2) or "houdini" (HoudiniBody).
static func attach(body: Node3D, body_type: String = "", source: String = "blender") -> SkinnedBody:
	var kind: String = body_type if body_type != "" else str(body.get_meta("body_type", "female"))
	var houdini: bool = source == "houdini"
	var paths: Dictionary = HoudiniBody.PATHS if houdini else PATHS
	var prep: Dictionary = HoudiniBody.prepared(kind) if houdini else {}
	if houdini and prep.is_empty():
		return null
	var scene: PackedScene = load(str(paths.get(kind, paths["female"]))) as PackedScene
	if scene == null:
		return null
	var inst: Node3D = scene.instantiate() as Node3D
	inst.name = "SkinnedBody"
	body.add_child(inst)
	var skel: Skeleton3D = find_skeleton(inst)
	if skel == null:
		inst.queue_free()
		return null
	var sb: SkinnedBody = SkinnedBody.new()
	sb.name = "JointDriver"
	sb.body_root = body
	skel.add_child(sb)
	sb.bind()
	if houdini and sb.mesh_instance != null:
		sb.mesh_instance.mesh = prep["mesh"]
		sb._full_mesh = prep["mesh"]
		sb.region_names = prep["regions"]
		sb.tri_region = prep["tri_region"]
		sb.always_hidden = HoudiniBody.ALWAYS_HIDDEN
		sb.set_hidden_regions(PackedStringArray())
	return sb


static func find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c: Node in n.get_children():
		var s: Skeleton3D = find_skeleton(c)
		if s != null:
			return s
	return null


## Model-pose rotation (Euler XYZ, radians) of a code-rig node. Everything else is zero.
static func neutral_rotation(node_name: String) -> Vector3:
	if node_name == "LeftUpperArm":
		return Vector3(0.0, 0.0, -NEUTRAL_ARM)
	if node_name == "RightUpperArm":
		return Vector3(0.0, 0.0, NEUTRAL_ARM)
	return Vector3.ZERO


## Body-space model-pose transforms of the joints and extra-bone pivots of a code-built body, by node name.
## Uses only the nodes' rest positions (local offsets), so it is valid whatever pose the rig is in now, except
## that the Hips offset is taken from PlaceholderSkater.HIP_HEIGHT (the poser moves the Hips).
static func neutral_globals(body: Node3D) -> Dictionary:
	var out: Dictionary = {}
	_neutral_walk(body, Transform3D.IDENTITY, out)
	return out


static func _neutral_walk(n: Node3D, parent_xf: Transform3D, out: Dictionary) -> void:
	for c: Node in n.get_children():
		var j: Node3D = c as Node3D
		if j == null or j is MeshInstance3D or j is Skeleton3D:
			continue
		var nm: String = str(j.name)
		var driven: bool = SkaterPoser.JOINTS.has(nm) or EXTRA_BONES.values().has(nm)
		if not driven:
			continue
		var pos: Vector3 = j.position
		if nm == "Hips":
			pos = Vector3(0.0, PlaceholderSkater.HIP_HEIGHT, 0.0)
		var xf: Transform3D = parent_xf * Transform3D(Basis.from_euler(neutral_rotation(nm)), pos)
		out[nm] = xf
		_neutral_walk(j, xf, out)


## Builds the bone -> joint map and the per-bone corrections. Call again if the code rig is rebuilt.
func bind() -> void:
	_map.clear()
	var skel: Skeleton3D = _skel()
	if skel == null or body_root == null:
		return
	mesh_instance = null
	for c: Node in skel.get_children():
		if c is MeshInstance3D:
			mesh_instance = c as MeshInstance3D
	var neutral: Dictionary = neutral_globals(body_root)
	var to_body: Transform3D = _skeleton_to_body(skel)
	for b: int in skel.get_bone_count():  # glTF import orders parents before children
		var bone: String = skel.get_bone_name(b)
		var node_name: String = str(EXTRA_BONES.get(bone, bone))
		if not neutral.has(node_name):
			continue
		var node: Node3D = body_root.find_child(node_name, true, false) as Node3D
		if node == null:
			continue
		var rest_body: Transform3D = to_body * skel.get_bone_global_rest(b)
		var corr: Transform3D = (neutral[node_name] as Transform3D).affine_inverse() * rest_body
		_map.append([b, node, corr])


## The driven skeleton (the parent; also before this node enters the tree, when get_skeleton() is still null).
func _skel() -> Skeleton3D:
	var s: Skeleton3D = get_skeleton()
	return s if s != null else get_parent() as Skeleton3D


func _skeleton_to_body(skel: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var n: Node = skel
	while n != null and n != body_root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _process_modification_with_delta(_delta: float) -> void:
	sync_pose()


## Copies the current joint poses onto the bones (also callable by hand, e.g. from tests).
func sync_pose() -> void:
	var skel: Skeleton3D = _skel()
	if skel == null or _map.is_empty():
		return
	var from_body: Transform3D = _skeleton_to_body(skel).affine_inverse()
	var in_tree: bool = body_root.is_inside_tree()
	var inv_root: Transform3D = body_root.global_transform.affine_inverse() if in_tree else Transform3D.IDENTITY
	for m: Array in _map:
		var node: Node3D = m[1]
		var joint_body: Transform3D = inv_root * node.global_transform if in_tree else _skeleton_to_body(node)
		skel.set_bone_global_pose(int(m[0]), from_body * joint_body * (m[2] as Transform3D))


## Hides every code-built skin mesh of body_root (MeshInstance3Ds with a "region" meta, the old lofted body),
## except the head. Garments, hair and the head stay.
func hide_code_skin() -> void:
	_hide_skin(body_root)


func _hide_skin(n: Node) -> void:
	if n is MeshInstance3D and n.has_meta("region") and str(n.get_meta("region")) != "head":
		(n as MeshInstance3D).visible = false
	for c: Node in n.get_children():
		if c is Skeleton3D or str(c.name) == "HeadModel":
			continue
		_hide_skin(c)


## Drops the triangles of the given regions (names from region_names) and of always_hidden from the mesh; an empty
## list shows all but always_hidden. A cap region "<r>_cap" (Houdini) is drawn only while <r> is hidden. The masked
## mesh is built once per hidden set and shared.
func set_hidden_regions(regions: PackedStringArray) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	if _full_mesh == null:
		_full_mesh = mesh_instance.mesh as ArrayMesh
	_load_regions()
	var want: Dictionary = {}
	for r: String in regions + always_hidden:
		want[r] = true
	var hidden: Dictionary = {}
	var names: PackedStringArray = PackedStringArray()
	for i: int in region_names.size():
		var r: String = region_names[i]
		var hide: bool = want.has(r)
		if r.ends_with("_cap"):
			hide = not want.has(r.trim_suffix("_cap"))
		if hide:
			hidden[i] = true
			names.append(r)
	names.sort()
	hidden_regions = names
	if hidden.is_empty():
		mesh_instance.mesh = _full_mesh
		return
	var key: String = "%d|%s" % [_full_mesh.get_instance_id(), ",".join(names)]
	if not _masked.has(key):
		_masked[key] = _masked_mesh(hidden)
	mesh_instance.mesh = _masked[key]


func _masked_mesh(hidden: Dictionary) -> ArrayMesh:
	var out: ArrayMesh = ArrayMesh.new()
	var arrays: Array = _full_mesh.surface_get_arrays(0)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var kept: PackedInt32Array = PackedInt32Array()
	for t: int in tri_region.size():
		if not hidden.has(tri_region[t]):
			kept.append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
	for s: int in _full_mesh.get_surface_count():
		var arr: Array = arrays if s == 0 else _full_mesh.surface_get_arrays(s)
		if s == 0:
			if kept.is_empty():
				continue
			arr[Mesh.ARRAY_INDEX] = kept
		var flags: int = _full_mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, _full_mesh.surface_get_material(s))
	return out


## Region index of each triangle of surface 0 (for tools and tests). Blender bodies read it from UV2.x.
func triangle_regions() -> PackedInt32Array:
	_load_regions()
	return tri_region


func _load_regions() -> void:
	if not tri_region.is_empty():
		return
	var m: Mesh = _full_mesh if _full_mesh != null else (mesh_instance.mesh if mesh_instance != null else null)
	if m == null:
		return
	region_names = REGIONS
	var arrays: Array = m.surface_get_arrays(0)
	var uv2: Variant = arrays[Mesh.ARRAY_TEX_UV2]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t: int in range(0, idx.size(), 3):
		tri_region.append(int((uv2 as PackedVector2Array)[idx[t]].x) if uv2 != null and not (uv2 as PackedVector2Array).is_empty() else -1)


## Region name of each triangle (for tools and tests).
func triangle_region_names() -> PackedStringArray:
	_load_regions()
	var out: PackedStringArray = PackedStringArray()
	for r: int in tri_region:
		out.append(region_names[r] if r >= 0 and r < region_names.size() else "")
	return out


## Vertex positions and normals of the full mesh in its current skinned pose, in world space (CPU skinning; call
## sync_pose() first when the joints moved since the last skeleton update). Returns [positions, normals].
func posed_arrays() -> Array:
	var skel: Skeleton3D = _skel()
	if skel == null or mesh_instance == null or _full_mesh == null:
		return [PackedVector3Array(), PackedVector3Array()]
	var skin: Skin = mesh_instance.skin
	var mats: Array[Transform3D] = []
	for i: int in skin.get_bind_count():
		var b: int = skin.get_bind_bone(i)
		if b < 0:
			b = skel.find_bone(skin.get_bind_name(i))
		mats.append(skel.get_bone_global_pose(b) * skin.get_bind_pose(i) if b >= 0 else Transform3D.IDENTITY)
	var to_world: Transform3D = skel.global_transform if skel.is_inside_tree() else _skeleton_to_body(skel)
	var arrays: Array = _full_mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var wts: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var out_v: PackedVector3Array = PackedVector3Array()
	var out_n: PackedVector3Array = PackedVector3Array()
	out_v.resize(vs.size())
	out_n.resize(vs.size())
	for v: int in vs.size():
		var p: Vector3 = Vector3.ZERO
		var n: Vector3 = Vector3.ZERO
		for k: int in 4:
			var w: float = wts[v * 4 + k]
			if w <= 0.0:
				continue
			var m: Transform3D = mats[bones[v * 4 + k]]
			p += (m * vs[v]) * w
			n += (m.basis * ns[v]) * w
		out_v[v] = to_world * p
		out_n[v] = (to_world.basis * n).normalized()
	return [out_v, out_n]
