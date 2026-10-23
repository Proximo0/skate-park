class_name WhGeo
extends RefCounted
## Geometry helpers for the Creepy Warehouse: industrial materials (wh_surface.gdshader), a mesh batcher that merges many
## boxes and meshes into one MeshInstance3D per material (per spatial tile when asked, so the Compatibility renderer's
## per-object light passes stay local), a collision body that collects box shapes, kit pieces as MultiMeshes, and small
## builders (pipes, rails, ramps from profiles) used by every area of the level.

const SHADER: Shader = preload("res://game/levels/warehouse/wh_surface.gdshader")
const KINDS: Dictionary = {"metal": 0, "brick": 1, "concrete": 2, "rust": 3, "plywood": 4, "paint": 5, "floor": 6}

static var _mats: Dictionary = {}
static var _unshaded: Dictionary = {}


## A shared industrial material. `rust` and `grime` 0..1; `accent` alpha 0 = a rust brown.
static func mat(kind: String, colour: Color, rust: float = 0.5, grime: float = 0.5, accent: Color = Color(0, 0, 0, 0), pattern_scale: float = 1.0, ground_y: float = 0.0) -> ShaderMaterial:
	var key: String = "%s|%s|%.2f|%.2f|%s|%.2f|%.2f" % [kind, colour.to_html(), rust, grime, accent.to_html(), pattern_scale, ground_y]
	if _mats.has(key):
		return _mats[key] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", colour)
	m.set_shader_parameter("kind", int(KINDS.get(kind, 0)))
	m.set_shader_parameter("rust", rust)
	m.set_shader_parameter("grime", grime)
	m.set_shader_parameter("scale", pattern_scale)
	m.set_shader_parameter("ground_y", ground_y)
	m.set_shader_parameter("accent", accent if accent.a > 0.0 else Color("6b3a22"))
	_mats[key] = m
	return m


static var _merged: ShaderMaterial = null


## The one material every Batch tile of WhGeo.mat surfaces shares (the parameters are per vertex).
static func merged_material() -> ShaderMaterial:
	if _merged == null:
		_merged = ShaderMaterial.new()
		_merged.shader = SHADER
		_merged.set_shader_parameter("per_vertex", true)
	return _merged


## A flat unshaded colour (lamp heads, lit windows, signs). `add` = additive blend. Fog follows the scene unless no_fog.
static func glow(colour: Color, add: bool = false, no_fog: bool = false) -> StandardMaterial3D:
	var key: String = "%s|%s|%s" % [colour.to_html(true), str(add), str(no_fog)]
	if _unshaded.has(key):
		return _unshaded[key] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	if add:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = no_fog
	m.disable_receive_shadows = true
	_unshaded[key] = m
	return m


## Collects triangles per material (and per tile of `tile` metres when > 0) and commits them as merged meshes.
class Batch:
	extends RefCounted
	var tile: float = 0.0
	var shadow: bool = true
	var _tools: Dictionary = {}  ## key -> SurfaceTool
	var _mat_of: Dictionary = {}  ## key -> Material

	func _init(tile_m: float = 0.0, casts: bool = true) -> void:
		tile = tile_m
		shadow = casts

	func _st(m: Material, at: Vector3) -> SurfaceTool:
		var sm: ShaderMaterial = m as ShaderMaterial
		var merged: bool = sm != null and sm.shader == WhGeo.SHADER
		var key: String = "wh" if merged else str(m.get_instance_id())
		if tile > 0.0:
			key += "|%d|%d" % [int(floorf(at.x / tile)), int(floorf(at.z / tile))]
		if not _tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			if merged:
				st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
				st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
			_tools[key] = st
			_mat_of[key] = WhGeo.merged_material() if merged else m
		var out: SurfaceTool = _tools[key] as SurfaceTool
		if merged:
			# the material's parameters ride on the vertices that follow (SurfaceTool keeps the last colour/custom)
			var acc: Color = sm.get_shader_parameter("accent")
			out.set_color(sm.get_shader_parameter("albedo") as Color)
			out.set_custom(0, Color(acc.r, acc.g, acc.b, float(sm.get_shader_parameter("rust"))))
			out.set_custom(1, Color(float(sm.get_shader_parameter("grime")), float(sm.get_shader_parameter("scale")),
					float(sm.get_shader_parameter("ground_y")), float(sm.get_shader_parameter("kind"))))
		return out

	## A box centred at `c` with `size`, turned by `b`.
	func box(c: Vector3, size: Vector3, m: Material, b: Basis = Basis.IDENTITY) -> void:
		var st: SurfaceTool = _st(m, c)
		var h: Vector3 = size * 0.5
		var faces: Array = [
			[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
			[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
			[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
			[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
			[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
			[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		]
		for f: Array in faces:
			var nn: Vector3 = f[0]
			var u: Vector3 = f[1]
			var v: Vector3 = f[2]
			var o: Vector3 = nn * h
			var hu: Vector3 = u * h
			var hv: Vector3 = v * h
			var p0: Vector3 = c + b * (o - hu - hv)
			var p1: Vector3 = c + b * (o + hu - hv)
			var p2: Vector3 = c + b * (o + hu + hv)
			var p3: Vector3 = c + b * (o - hu + hv)
			var wn: Vector3 = (b * nn).normalized()
			_quad(st, p0, p1, p2, p3, wn)

	## A box given by its min corner and size (axis aligned).
	func box_min(lo: Vector3, size: Vector3, m: Material) -> void:
		box(lo + size * 0.5, size, m)

	## One quad p0..p3 counter-clockwise seen from the side `n` points to.
	func quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, m: Material) -> void:
		var n: Vector3 = (p2 - p0).cross(p3 - p1).normalized()
		_quad(_st(m, (p0 + p2) * 0.5), p0, p1, p2, p3, n)

	func tri(a: Vector3, b2: Vector3, c: Vector3, m: Material) -> void:
		var st: SurfaceTool = _st(m, (a + b2 + c) / 3.0)
		var n: Vector3 = (b2 - a).cross(c - a).normalized()
		for p: Vector3 in [a, c, b2]:
			st.set_normal(n)
			st.set_uv(Vector2(p.x + p.z, p.y))
			st.add_vertex(p)

	func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3) -> void:
		# Godot front faces are clockwise: emit the counter-clockwise quad reversed
		for p: Vector3 in [p0, p2, p1, p0, p3, p2]:
			st.set_normal(n)
			st.set_uv(Vector2(p.x + p.z, p.y))
			st.add_vertex(p)

	## Appends every surface of `mesh` placed by `xf` (normals kept), all in material `m`.
	func mesh(src: Mesh, xf: Transform3D, m: Material, only_surface: int = -1) -> void:
		var st: SurfaceTool = _st(m, xf.origin)
		var nb: Basis = xf.basis.inverse().transposed()
		for s: int in src.get_surface_count():
			if only_surface >= 0 and s != only_surface:
				continue
			var arr: Array = src.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var order: PackedInt32Array = idx
			if order.is_empty():
				order = PackedInt32Array(range(verts.size()))
			for i: int in order:
				if not norms.is_empty():
					st.set_normal((nb * norms[i]).normalized())
				var p: Vector3 = xf * verts[i]
				st.set_uv(Vector2(p.x + p.z, p.y))
				st.add_vertex(p)

	## Adds a cylinder from a to b.
	func pipe(a: Vector3, b2: Vector3, r: float, m: Material, sides: int = 8) -> void:
		var cyl := CylinderMesh.new()
		cyl.top_radius = r
		cyl.bottom_radius = r
		cyl.height = a.distance_to(b2)
		cyl.radial_segments = sides
		cyl.rings = 1
		mesh(cyl, Transform3D(WhGeo.basis_along(b2 - a), (a + b2) * 0.5), m)

	## The merged meshes as MeshInstance3Ds under a new Node3D called `node_name` in `parent`.
	func commit(parent: Node, node_name: String) -> Node3D:
		var root := Node3D.new()
		root.name = node_name
		parent.add_child(root)
		var i: int = 0
		for key: String in _tools:
			var st: SurfaceTool = _tools[key] as SurfaceTool
			var mi := MeshInstance3D.new()
			mi.name = "%s%d" % [node_name, i]
			mi.mesh = st.commit()
			mi.material_override = _mat_of[key] as Material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
			i += 1
		_tools.clear()
		_mat_of.clear()
		return root


## A Basis whose +Y runs along `dir` (for cylinders).
static func basis_along(dir: Vector3) -> Basis:
	var d: Vector3 = dir.normalized()
	var up_hint: Vector3 = Vector3.FORWARD if absf(d.dot(Vector3.UP)) > 0.99 else Vector3.UP
	return Basis.looking_at(d, up_hint) * Basis(Vector3.RIGHT, -PI / 2.0)


## A static collision body (world layer 1) under `parent`; add shapes with solid().
static func body(parent: Node, node_name: String) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = node_name
	sb.collision_layer = 1
	sb.collision_mask = 0
	parent.add_child(sb)
	return sb


## A box collision shape on `sb` (world space: the body sits at the origin).
static func solid(sb: StaticBody3D, c: Vector3, size: Vector3, b: Basis = Basis.IDENTITY) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = Transform3D(b, c)
	sb.add_child(cs)
	return cs


static func solid_min(sb: StaticBody3D, lo: Vector3, size: Vector3) -> CollisionShape3D:
	return solid(sb, lo + size * 0.5, size)


## A convex hull collision shape from points (world space).
static func hull(sb: StaticBody3D, pts: PackedVector3Array) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	cs.shape = shape
	sb.add_child(cs)
	return cs


## Visual + collision box in one call.
static func block(bt: Batch, sb: StaticBody3D, lo: Vector3, size: Vector3, m: Material) -> void:
	bt.box_min(lo, size, m)
	solid_min(sb, lo, size)


## A grind line under `parent` (world space points).
static func grind(parent: Node, pts: PackedVector3Array, kind: String = "rail", node_name: String = "Grind") -> GrindRail:
	var r: GrindRail = PieceKit.rail(pts, kind, node_name)
	parent.add_child(r)
	return r


## Every MeshInstance3D under `root` gets `m` (piece reskin); returns root.
static func reskin(root: Node, m: Material) -> Node:
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = m
	return root


## Rect2 cells of `outer` not covered by `holes`, merged along x into runs. Used to cut the ground slabs.
static func cut_rects(outer: Rect2, holes: Array[Rect2], cuts_x: Array[float] = [], cuts_z: Array[float] = []) -> Array[Rect2]:
	var xs: Array[float] = [outer.position.x, outer.end.x]
	var zs: Array[float] = [outer.position.y, outer.end.y]
	for h: Rect2 in holes:
		xs.append_array([h.position.x, h.end.x])
		zs.append_array([h.position.y, h.end.y])
	xs.append_array(cuts_x)
	zs.append_array(cuts_z)
	xs = WhGeo._uniq_in(xs, outer.position.x, outer.end.x)
	zs = WhGeo._uniq_in(zs, outer.position.y, outer.end.y)
	var out: Array[Rect2] = []
	for j: int in zs.size() - 1:
		var run_start: float = NAN
		for i: int in xs.size() - 1:
			var cell := Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j])
			var mid: Vector2 = cell.get_center()
			var hole: bool = false
			for h: Rect2 in holes:
				if h.has_point(mid):
					hole = true
					break
			var cut_here: bool = cuts_x.has(xs[i])
			if hole or cut_here:
				if not is_nan(run_start):
					out.append(Rect2(run_start, zs[j], xs[i] - run_start, zs[j + 1] - zs[j]))
					run_start = NAN
			if not hole and is_nan(run_start):
				run_start = xs[i]
		if not is_nan(run_start):
			out.append(Rect2(run_start, zs[j], xs[xs.size() - 1] - run_start, zs[j + 1] - zs[j]))
	return out


static func _uniq_in(v: Array[float], lo: float, hi: float) -> Array[float]:
	v.sort()
	var out: Array[float] = []
	for x: float in v:
		if x < lo - 0.001 or x > hi + 0.001:
			continue
		if out.is_empty() or x - out[out.size() - 1] > 0.001:
			out.append(x)
	return out


## Kit piece copies drawn as MultiMeshes (one per piece, its own surface materials): `xforms` place them, no collision.
## Night tones for kit pieces whose stock colours glare under the sodium lamps (material name -> colour).
const KIT_TONES: Dictionary = {
	"pallet_stack": {"cardboard": Color("6a5036"), "wood_pallet": Color("5a4430"), "door_grey": Color("50545a")},
	"oil_drum": {"drum_blue": Color("2c4a6e"), "drum_rust": Color("6a3a24"), "steel_dark": Color("33363b")},
	"loading_dock_door": {"door_grey": Color("5a6068"), "concrete": Color("5e5f63"), "safety_yellow": Color("b88d1e"), "steel_dark": Color("33363b")},
}


static func kit_multi(parent: Node, kit: LevelKit, piece: String, xforms: Array[Transform3D], node_name: String = "", recolour: Dictionary = {}, shadow: bool = true) -> MultiMeshInstance3D:
	if recolour.is_empty() and KIT_TONES.has(piece):
		recolour = KIT_TONES[piece] as Dictionary
	var vis: Node3D = kit.visual(piece)
	var src: MeshInstance3D = vis.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var m: ArrayMesh = (src.mesh as ArrayMesh).duplicate() as ArrayMesh
	for s: int in m.get_surface_count():
		var orig: Material = src.mesh.surface_get_material(s)
		var nm: String = orig.resource_name if orig != null else ""
		var surf: Material = src.get_surface_override_material(s)
		if recolour.has(nm):
			var r: Variant = recolour[nm]
			surf = r as Material if r is Material else Toon.material(r as Color, false)
		m.surface_set_material(s, surf)
	var local: Transform3D = WhGeo._mesh_xf(vis, src)
	vis.free()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i] * local)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name if node_name != "" else piece + "_multi"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


static func _mesh_xf(root: Node3D, n: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Collision boxes of a kit piece added to `sb` at `xf` (manifest boxes; none for mesh collision).
static func kit_solids(sb: StaticBody3D, kit: LevelKit, piece: String, xf: Transform3D, grow: float = 0.0) -> void:
	for bb: AABB in kit.collision_boxes(piece):
		var c: Vector3 = xf * bb.get_center()
		solid(sb, c, bb.size + Vector3.ONE * grow, xf.basis.orthonormalized())


static func yaw(deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(deg))


## Additive vertical-fade quad/box "light shaft" mesh is in WhLights; this is the soft radial pool texture reuse.
static func pool(parent: Node, pos: Vector3, radius: float, colour: Color, strength: float = 0.5) -> MeshInstance3D:
	var p: MeshInstance3D = FlickerLight.light_pool(radius, colour, strength)
	p.position = pos
	parent.add_child(p)
	return p


const TAG_SHADER: Shader = preload("res://game/levels/warehouse/wh_tag.gdshader")
static var _tag_mats: Dictionary = {}


## A graffiti piece (GraffitiArt id) `w` metres wide at `pos`, facing yaw_deg (0 = +Z), lit like the wall under it.
static func tag(id: String, w: float, pos: Vector3, yaw_deg: float, fade: float = 0.8) -> MeshInstance3D:
	var key: String = "%s@%.2f" % [id, fade]
	if not _tag_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = TAG_SHADER
		m.set_shader_parameter("tex", GraffitiArt.texture(id))
		m.set_shader_parameter("fade", fade)
		_tag_mats[key] = m
	var px: Vector2i = GraffitiArt.size_of(id)
	var q := QuadMesh.new()
	q.size = Vector2(w, w * float(px.y) / float(px.x))
	var mi := MeshInstance3D.new()
	mi.name = "Tag_" + id
	mi.mesh = q
	mi.material_override = _tag_mats[key] as ShaderMaterial
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	return mi


## Bakes the meshes of the level's placed pieces (park ramps, stairs, the pit...) into `bt`, per surface material, and
## frees their MeshInstance3Ds; collision, grind rails, ramp lips and gap zones stay. Pieces are static, and a piece
## is otherwise one draw call per part plus one per lamp touching each part.
static func flatten(root: Node3D, bt: Batch) -> void:
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var xf: Transform3D = mi.global_transform
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.material_override
			if m == null:
				m = mi.get_surface_override_material(s)
			if m == null:
				m = mi.mesh.surface_get_material(s)
			if m == null:
				continue
			bt.mesh(mi.mesh, xf, m, s)
		mi.get_parent().remove_child(mi)
		mi.free()


## Bakes the given MeshInstance3Ds (in the tree) into `bt` and frees them (see flatten).
static func flatten_list(list: Array[MeshInstance3D], bt: Batch) -> void:
	for mi: MeshInstance3D in list:
		var xf: Transform3D = mi.global_transform
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.material_override
			if m == null:
				m = mi.get_surface_override_material(s)
			if m == null:
				m = mi.mesh.surface_get_material(s)
			if m != null:
				bt.mesh(mi.mesh, xf, m, s)
		mi.get_parent().remove_child(mi)
		mi.free()


## Merges MeshInstance3Ds that share one material (and need their own UVs, like additive pools and shafts) into one
## MeshInstance3D under `parent`, then frees them. Returns the merged instance.
static func merge_same(list: Array[MeshInstance3D], parent: Node, node_name: String) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m: Material = null
	for mi: MeshInstance3D in list:
		if m == null:
			m = mi.material_override
		st.append_from(mi.mesh, 0, mi.global_transform)
		mi.get_parent().remove_child(mi)
		mi.free()
	var out := MeshInstance3D.new()
	out.name = node_name
	out.mesh = st.commit()
	out.material_override = m
	out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(out)
	return out

