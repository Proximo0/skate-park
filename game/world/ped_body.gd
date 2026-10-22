class_name PedBody
extends RefCounted
## Crowd-cheap character bodies for pedestrians. Builds the same body the player and the shop NPCs use
## (SkaterBuilder.build_body: code rig of joint nodes, Houdini skinned skin, garments, anime head and hair), then bakes
## it for crowds: every rigid mesh under a joint is merged into one vertex-coloured toon mesh per joint (cloth and
## non-cloth kept apart so garments keep their cloth shading). 150-odd meshes become about 20 draw calls, the joint
## hierarchy stays exactly as SkaterPoser expects, and the skinned skin keeps following the joints.
##
## Looks: random(rng) gives a seeded random adult look (body type, skin, hair, outfit, colours) from the part catalog.

const CLOTH_KEY: String = "cloth"
const CLOTH_SHADER: Shader = preload("res://game/world/ped_cloth.gdshader")

static var _materials: Dictionary = {}


## A random look: SkaterLoadout.randomise with the player's catalog, a seeded rng and a few street-wear tweaks.
static func random_look(rng: RandomNumberGenerator) -> SkaterLoadout:
	var look := SkaterLoadout.new()
	look.randomise(rng)
	return look


## Builds and bakes a body for `look`. Returns the body root (named "SkaterBody", posable by SkaterPoser).
static func build(look: SkaterLoadout) -> Node3D:
	var body: Node3D = SkaterBuilder.build_body(look)
	body.name = "SkaterBody"
	Toon.apply_to(body)
	bake(body)
	return body


## Merges the rigid meshes of `body` per joint (see the class doc). Returns how many draw calls were saved.
static func bake(body: Node3D) -> int:
	var joints: Dictionary = {}
	for j: String in SkaterPoser.JOINTS:
		var n: Node = body.find_child(j, true, false)
		if n != null:
			joints[n] = j
	var groups: Dictionary = {}  ## "joint path|cloth" -> {joint: Node3D, cloth: bool, verts, norms, cols, idx}
	var victims: Array[MeshInstance3D] = []
	for n: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or mi.skin != null or mi.get_parent() is Skeleton3D:  # the skinned skin stays as it is
			continue
		if not _visible_in(mi, body):
			victims.append(mi)
			continue
		var owner_joint: Node3D = body
		var xf: Transform3D = Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != body:
			if p != mi and joints.has(p):
				owner_joint = p as Node3D
				break
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		for s: int in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			var albedo: Color = Color.WHITE
			var cloth: bool = false
			var vca: float = 0.0
			if mat is ShaderMaterial:
				var sm: ShaderMaterial = mat as ShaderMaterial
				var a: Variant = sm.get_shader_parameter("albedo")
				if a is Color:
					albedo = a
				cloth = float(sm.get_shader_parameter("cloth_shade") if sm.get_shader_parameter("cloth_shade") != null else 0.0) > 0.0
				vca = float(sm.get_shader_parameter("vertex_color_amount") if sm.get_shader_parameter("vertex_color_amount") != null else 0.0)
			elif mat is StandardMaterial3D:
				albedo = (mat as StandardMaterial3D).albedo_color
			var key: String = "%s|%s" % [str(owner_joint.get_instance_id()), str(cloth)]
			if not groups.has(key):
				groups[key] = {"joint": owner_joint, "cloth": cloth, "verts": PackedVector3Array(), "norms": PackedVector3Array(),
					"cols": PackedColorArray(), "idx": PackedInt32Array()}
			_append(groups[key] as Dictionary, mi.mesh, s, xf, albedo, vca)
		victims.append(mi)
	for g: Dictionary in groups.values():
		var verts: PackedVector3Array = g["verts"]
		if verts.is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = g["norms"]
		arrays[Mesh.ARRAY_COLOR] = g["cols"]
		arrays[Mesh.ARRAY_INDEX] = g["idx"]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var merged := MeshInstance3D.new()
		merged.name = "Baked" + ("Cloth" if bool(g["cloth"]) else "")
		merged.mesh = am
		merged.material_override = _material(bool(g["cloth"]))
		(g["joint"] as Node3D).add_child(merged)
	var saved: int = victims.size() - groups.size()
	for mi: MeshInstance3D in victims:
		mi.get_parent().remove_child(mi)
		mi.free()
	return saved


static func _visible_in(n: Node, root: Node) -> bool:
	var p: Node = n
	while p != null and p != root:
		if p is Node3D and not (p as Node3D).visible:
			return false
		p = p.get_parent()
	return true


static func _append(g: Dictionary, mesh: Mesh, surface: int, xf: Transform3D, albedo: Color, vca: float) -> void:
	var arr: Array = mesh.surface_get_arrays(surface)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var vc: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var verts: PackedVector3Array = g["verts"]
	var norms: PackedVector3Array = g["norms"]
	var cols: PackedColorArray = g["cols"]
	var idx: PackedInt32Array = g["idx"]
	var base: int = verts.size()
	var lin: Color = albedo.srgb_to_linear()
	var flip: bool = xf.basis.determinant() < 0.0
	for i: int in v.size():
		verts.append(xf * v[i])
		norms.append((xf.basis.inverse().transposed() * n[i]).normalized() if i < n.size() else Vector3.UP)
		var c: Color = lin
		if vca > 0.0 and i < vc.size():
			c = Color(lin.r * lerpf(1.0, vc[i].r, vca), lin.g * lerpf(1.0, vc[i].g, vca), lin.b * lerpf(1.0, vc[i].b, vca))
		cols.append(c)
	if ix.is_empty():
		for i: int in v.size():
			ix.append(i)
	for t: int in range(0, ix.size() - 2, 3):
		if flip:
			idx.append_array([base + ix[t], base + ix[t + 2], base + ix[t + 1]])
		else:
			idx.append_array([base + ix[t], base + ix[t + 1], base + ix[t + 2]])
	g["verts"] = verts
	g["norms"] = norms
	g["cols"] = cols
	g["idx"] = idx


## The shared vertex-colour toon material for skin, hair and faces; garments get the cloth shader (ped_cloth.gdshader),
## shared until recolour() gives a person their own.
static func _material(cloth: bool) -> ShaderMaterial:
	var key: String = CLOTH_KEY if cloth else "plain"
	if _materials.has(key):
		return _materials[key] as ShaderMaterial
	var m := ShaderMaterial.new()
	if cloth:
		m.shader = CLOTH_SHADER
	else:
		m.shader = Toon.TOON_SHADER
		m.set_shader_parameter("albedo", Color.WHITE)
		m.set_shader_parameter("vertex_color_amount", 1.0)
	_materials[key] = m
	return m


## A copy of a baked body (cheap: about 20 nodes and shared meshes) with its skin re-bound to the copy's joints.
static func clone(template: Node3D) -> Node3D:
	var b: Node3D = template.duplicate() as Node3D
	for n: Node in b.find_children("*", "", true, false):
		if n is SkinnedBody:
			var sb: SkinnedBody = n as SkinnedBody
			sb.body_root = b
			sb.bind()
	return b


## Gives this body's garments their own colours: hue turned by `hue` (0..1 turns), saturation and value scaled.
static func recolour(body: Node3D, hue: float, sat: float = 1.0, val: float = 1.0) -> void:
	var m: ShaderMaterial = _material(true).duplicate() as ShaderMaterial
	m.set_shader_parameter("hue_shift", hue)
	m.set_shader_parameter("sat_mul", sat)
	m.set_shader_parameter("val_mul", val)
	for n: Node in body.find_children("BakedCloth", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = m
