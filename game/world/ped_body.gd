class_name PedBody
extends RefCounted
## Crowd-cheap character bodies for pedestrians. Builds the same body the player and the shop NPCs use
## (SkaterBuilder.build_body: code rig of joint nodes, Houdini skinned skin, garments, anime head and hair), then bakes
## it for crowds: every rigid mesh under a joint is merged into ONE vertex-coloured surface per joint (the vertex alpha
## is the cloth mask, so garments keep their cloth shading and hue shift while skin and hair do not). 150-odd meshes
## become at most 15 joint surfaces (hands ride on their forearms) plus the skinned skin: 16 draw calls at most. The
## joint hierarchy stays exactly as SkaterPoser expects, and the skinned skin keeps following the joints.
##
## Looks: random(rng) gives a seeded random adult look (body type, skin, hair, outfit, colours) from the part catalog.

const CLOTH_SHADER: Shader = preload("res://game/world/ped_cloth.gdshader")

static var _material_shared: ShaderMaterial = null


## A random look: SkaterLoadout.randomise with the player's catalog, a seeded rng and a few street-wear tweaks.
static func random_look(rng: RandomNumberGenerator) -> SkaterLoadout:
	var look := SkaterLoadout.new()
	look.randomise(rng)
	return look


## Builds and bakes a body for `look`. Returns the body root (named "SkaterBody", posable by SkaterPoser).
static func build(look: SkaterLoadout) -> Node3D:
	# Pedestrians keep the varied Houdini bodies and lofted outfits; the VRoid model is the lead skater's.
	var opts: Dictionary = SkaterBuilder.body_options(look)
	opts["skin"] = "houdini"
	var body: Node3D = PlaceholderSkater.build_body(SkaterBuilder.body_palette(look), opts)
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
	var groups: Dictionary = {}  ## joint instance id -> {joint: Node3D, verts, norms, cols, idx}
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
				if str(owner_joint.name).ends_with("Hand"):
					# pedestrians' wrists never bend: the hand rides on its forearm's surface (saves two draws a person)
					xf = owner_joint.transform * xf
					owner_joint = owner_joint.get_parent() as Node3D
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
			var key: int = owner_joint.get_instance_id()
			if not groups.has(key):
				groups[key] = {"joint": owner_joint, "verts": PackedVector3Array(), "norms": PackedVector3Array(),
					"cols": PackedColorArray(), "idx": PackedInt32Array()}
			_append(groups[key] as Dictionary, mi.mesh, s, xf, albedo, vca, 1.0 if cloth else 0.0)
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
		merged.name = "Baked"
		merged.mesh = am
		merged.material_override = _material()
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


static func _append(g: Dictionary, mesh: Mesh, surface: int, xf: Transform3D, albedo: Color, vca: float, cloth: float) -> void:
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
		c.a = cloth  # the cloth mask (ped_cloth.gdshader)
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


## The shared vertex-colour toon material (ped_cloth.gdshader); recolour() gives a person their own copy.
static func _material() -> ShaderMaterial:
	if _material_shared == null:
		_material_shared = ShaderMaterial.new()
		_material_shared.shader = CLOTH_SHADER
	return _material_shared


## Uniforms: PedBody.uniform(body, UNIFORM_SECURITY) dresses a baked body (a clone of a template) as a security guard.
const UNIFORM_SECURITY: String = "security"
const _NAVY_SHIRT: Color = Color("3d5f9f")
const _NAVY_TROUSERS: Color = Color("33497d")
const _BOOT: Color = Color("14151a")
const _BADGE_YELLOW: Color = Color("ffd83a")
const _BELT: Color = Color("0d0e12")
const _SHIRT_JOINTS: PackedStringArray = ["Spine", "Chest", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm"]
const _TROUSER_JOINTS: PackedStringArray = ["Hips", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"]


## A look for the security guard: a man in long trousers and a plain shirt with a short buzz cut (the cap, belt and
## badge patches come from uniform()).
static func guard_look() -> SkaterLoadout:
	var look: SkaterLoadout = SkaterLoadout.default_male()
	look.hair_style = "hair_buzz"
	look.top_id = "top_flannel"
	look.top_color = 0
	look.skin_tone = Color("#C98E64")
	look.hair_color = Color("#2a2622")
	look.bottom_id = "bottom_skate_jeans"
	look.bottom_color = 0
	look.accessories = []
	look.accessory_colors = []
	look.sanitize()
	return look


## Dresses `body` (baked, private to one person: its meshes are rebuilt) in a uniform. Only UNIFORM_SECURITY exists:
## dark navy shirt and trousers, black boots and belt, a navy cap with a badge-yellow front patch, a yellow badge on
## the left chest and yellow shoulder patches. Recolouring is by joint, so it does not depend on the look underneath.
static func uniform(body: Node3D, kind: String = UNIFORM_SECURITY) -> void:
	if kind != UNIFORM_SECURITY:
		return
	for jn: String in SkaterPoser.JOINTS:
		var joint: Node3D = body.find_child(jn, true, false) as Node3D
		if joint == null:
			continue
		var baked: MeshInstance3D = null
		for c: Node in joint.get_children():
			if c is MeshInstance3D and c.name == "Baked":
				baked = c as MeshInstance3D
		var g: Dictionary = {"verts": PackedVector3Array(), "norms": PackedVector3Array(), "cols": PackedColorArray(), "idx": PackedInt32Array()}
		if baked != null:
			var arr: Array = baked.mesh.surface_get_arrays(0)
			g["verts"] = arr[Mesh.ARRAY_VERTEX]
			g["norms"] = arr[Mesh.ARRAY_NORMAL]
			g["cols"] = arr[Mesh.ARRAY_COLOR]
			g["idx"] = arr[Mesh.ARRAY_INDEX]
		var tint: Variant = null
		if jn in _SHIRT_JOINTS:
			tint = _NAVY_SHIRT
		elif jn in _TROUSER_JOINTS:
			tint = _NAVY_TROUSERS
		if tint != null:
			var cols: PackedColorArray = g["cols"]
			var lin: Color = (tint as Color).srgb_to_linear()
			for i: int in cols.size():
				if cols[i].a > 0.5:
					# keep a little of the garment's own shading variation so folds do not go flat
					var v: float = clampf(cols[i].get_luminance() * 3.0, 0.8, 1.15)
					cols[i] = Color(lin.r * v, lin.g * v, lin.b * v, 0.0)
			g["cols"] = cols
		elif jn.ends_with("Foot"):
			var cols2: PackedColorArray = g["cols"]
			var boot: Color = _BOOT.srgb_to_linear()
			boot.a = 0.0
			for i: int in cols2.size():
				cols2[i] = boot
			g["cols"] = cols2
		_uniform_parts(g, jn)
		if (g["verts"] as PackedVector3Array).is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g["verts"]
		arrays[Mesh.ARRAY_NORMAL] = g["norms"]
		arrays[Mesh.ARRAY_COLOR] = g["cols"]
		arrays[Mesh.ARRAY_INDEX] = g["idx"]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if baked == null:
			baked = MeshInstance3D.new()
			baked.name = "Baked"
			baked.material_override = _material()
			joint.add_child(baked)
		baked.mesh = am


## The extra pieces of the security uniform on one joint.
static func _uniform_parts(g: Dictionary, joint: String) -> void:
	match joint:
		"Head":
			# a navy cap: a dome over the crown, a short brim and a yellow front patch
			var dome := SphereMesh.new()
			dome.radius = 0.5
			dome.height = 0.5
			dome.is_hemisphere = true
			dome.radial_segments = 14
			dome.rings = 5
			_part(g, dome, Transform3D(Basis.from_scale(Vector3(0.25, 0.3, 0.27)), Vector3(0.0, 0.125, 0.012)), _NAVY_SHIRT)
			var brim := BoxMesh.new()
			brim.size = Vector3(0.17, 0.012, 0.085)
			_part(g, brim, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(10.0)), Vector3(0.0, 0.133, -0.135)), _NAVY_TROUSERS)
			var patch := BoxMesh.new()
			patch.size = Vector3(0.055, 0.035, 0.01)
			_part(g, patch, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12.0)), Vector3(0.0, 0.17, -0.128)), _BADGE_YELLOW)
		"Spine":
			# the belt: a black band round the waist with a small buckle
			var belt := CylinderMesh.new()
			belt.top_radius = 0.5
			belt.bottom_radius = 0.5
			belt.height = 0.045
			belt.radial_segments = 16
			belt.rings = 1
			_part(g, belt, Transform3D(Basis.from_scale(Vector3(0.305, 1.0, 0.24)), Vector3(0.0, -0.035, 0.0)), _BELT)
			var buckle := BoxMesh.new()
			buckle.size = Vector3(0.04, 0.035, 0.012)
			_part(g, buckle, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.035, -0.125)), _BADGE_YELLOW)
		"Chest":
			var badge := BoxMesh.new()
			badge.size = Vector3(0.05, 0.06, 0.012)
			_part(g, badge, Transform3D(Basis.IDENTITY, Vector3(-0.07, 0.13, -0.137)), _BADGE_YELLOW)
			var pocket := BoxMesh.new()
			pocket.size = Vector3(0.055, 0.05, 0.01)
			_part(g, pocket, Transform3D(Basis.IDENTITY, Vector3(0.07, 0.13, -0.138)), _NAVY_TROUSERS)
		"LeftUpperArm", "RightUpperArm":
			var sh := BoxMesh.new()
			sh.size = Vector3(0.016, 0.055, 0.075)
			var sx: float = -0.062 if joint == "LeftUpperArm" else 0.062
			_part(g, sh, Transform3D(Basis.IDENTITY, Vector3(sx, -0.03, 0.0)), _BADGE_YELLOW)


static func _part(g: Dictionary, mesh: Mesh, xf: Transform3D, colour: Color) -> void:
	_append(g, mesh, 0, xf, colour, 0.0, 0.0)


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
	var m: ShaderMaterial = _material().duplicate() as ShaderMaterial
	m.set_shader_parameter("hue_shift", hue)
	m.set_shader_parameter("sat_mul", sat)
	m.set_shader_parameter("val_mul", val)
	for n: Node in body.find_children("Baked", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = m
