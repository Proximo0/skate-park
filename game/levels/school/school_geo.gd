class_name SchoolGeo
extends RefCounted
## Batched static geometry for the School level. One SchoolGeo per area: every box, prism and lathe added to it is
## merged into one mesh per material (one draw call per material per area), and its collision goes into one
## StaticBody3D (box shapes for boxes, convex shapes for prisms, one trimesh for lathes). Everything is in world
## space (the level sits at the origin).
##
## Winding: Godot treats clockwise as front-facing, so every face is emitted reversed from its outside-CCW order with
## its outward normal set explicitly (as game/park/pieces/transfers.gd does). Trimesh collision uses the same faces, so
## it is solid from the visible side only (backface collision off, like PieceKit.body).
##
## Materials are named by key: SchoolGeo.toon(colour), SchoolGeo.surf(kind, colour, scale) and SchoolGeo.facade(id)
## return the key and register the shared material.

const FACADE_SHADER: Shader = preload("res://game/levels/school/school_facade.gdshader")

## key -> Material, shared by every area.
static var _mats: Dictionary = {}
## key -> true for materials whose meshes never cast shadows (ground-like surfaces).
static var _no_shadow: Dictionary = {}
## Flat-colour keys (toon_*, glow_*) -> their colour. They share two vertex-coloured batches per area ("toonvc" and
## "glowvc"), so a whole area of painted boxes is one or two draw calls instead of one per colour.
static var _colour: Dictionary = {}
const TOON_VC: String = "toonvc"
const GLOW_VC: String = "glowvc"

var parent: Node3D
var area: String = ""
var body: StaticBody3D
var _batches: Dictionary = {}  ## material key -> SurfaceTool
var _counts: Dictionary = {}  ## material key -> vertices added
var _trimesh: PackedVector3Array = PackedVector3Array()
var _n_shapes: int = 0


func _init(p: Node3D, area_name: String) -> void:
	parent = p
	area = area_name
	body = StaticBody3D.new()
	body.name = area_name + "Solid"
	body.collision_layer = 1
	body.collision_mask = 0
	p.add_child(body)


# --- materials ------------------------------------------------------------------------------------------

static func toon(c: Color) -> String:
	var k: String = "toon_" + c.to_html(false)
	if not _mats.has(k):
		_mats[k] = Toon.material(c, false)
		_colour[k] = c
	return k


## A WorldSurface material (concrete, asphalt, grass, pavers, court, ...). Surfaces never cast shadows.
static func surf(kind: String, c: Color = Color(0, 0, 0, 0), sc: float = 1.0) -> String:
	var k: String = "surf_%s_%s_%.2f" % [kind, c.to_html(false), sc]
	if not _mats.has(k):
		_mats[k] = WorldSurface.material(kind, c, sc)
		_no_shadow[k] = true
	return k


## Unshaded emissive colour (lamp heads, lit signs). Never casts shadows.
static func glow(c: Color) -> String:
	var k: String = "glow_" + c.to_html(false)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		m.disable_fog = false
		_mats[k] = m
		_no_shadow[k] = true
		_colour[k] = c
	return k


## The building facade shader (brick or block walls, a window grid with some windows lit) under a preset id.
## params override the shader's uniforms.
static func facade(id: String, params: Dictionary = {}) -> String:
	var k: String = "facade_" + id
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = FACADE_SHADER
		for p: String in params:
			m.set_shader_parameter(p, params[p])
		_mats[k] = m
	return k


static func mat(key: String) -> Material:
	return _mats.get(key, null) as Material


## The batch a key draws in: the shared vertex-colour batch for flat colours, else its own.
static func _batch_key(key: String) -> String:
	if key.begins_with("toon_"):
		return TOON_VC
	if key.begins_with("glow_"):
		return GLOW_VC
	return key


static func _batch_mat(bk: String) -> Material:
	if bk == TOON_VC:
		return Toon.material_vc(Color.WHITE)
	if bk == GLOW_VC:
		if not _mats.has(GLOW_VC):
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			_mats[GLOW_VC] = m
			_no_shadow[GLOW_VC] = true
		return _mats[GLOW_VC] as Material
	return _mats[bk] as Material


# --- primitives -----------------------------------------------------------------------------------------

## An axis-aligned box by its minimum corner and size.
## `top` false leaves the top face out (when a flat surface quad covers it, so the two are never coplanar).
func box(min_corner: Vector3, size: Vector3, key: String, collide: bool = true, top: bool = true) -> void:
	obox(Transform3D(Basis.IDENTITY, min_corner + size * 0.5), size, key, collide, top)


## A box centred at xf.origin, turned by xf.basis (unscaled).
func obox(xf: Transform3D, size: Vector3, key: String, collide: bool = true, top: bool = true) -> void:
	var h: Vector3 = size * 0.5
	var c: Array[Vector3] = []
	for i: int in 8:
		c.append(xf * Vector3(h.x * (1.0 if i & 1 else -1.0), h.y * (1.0 if i & 2 else -1.0), h.z * (1.0 if i & 4 else -1.0)))
	var st: SurfaceTool = _st(key)
	var o: Vector3 = xf.origin
	# faces as quads (any order; _quad orients them by the outward hint)
	_quad(st, key, c[0], c[1], c[3], c[2], o)  # -z
	_quad(st, key, c[4], c[5], c[7], c[6], o)  # +z
	_quad(st, key, c[0], c[1], c[5], c[4], o)  # -y
	if top:
		_quad(st, key, c[2], c[3], c[7], c[6], o)  # +y
	_quad(st, key, c[0], c[2], c[6], c[4], o)  # -x
	_quad(st, key, c[1], c[3], c[7], c[5], o)  # +x
	if collide:
		var cs := CollisionShape3D.new()
		cs.name = "Box%d" % _n_shapes
		_n_shapes += 1
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		cs.transform = xf
		body.add_child(cs)


## A visual-only box (no collision).
func vbox(min_corner: Vector3, size: Vector3, key: String) -> void:
	box(min_corner, size, key, false)


## A convex prism: `profile` is a convex polygon in the (z, y) plane of xf's local space, extruded along local x from
## x0 to x1. Collision is one convex shape.
func prism(xf: Transform3D, profile: PackedVector2Array, x0: float, x1: float, key: String, collide: bool = true, show: bool = true) -> void:
	var n: int = profile.size()
	var a: Array[Vector3] = []
	var b: Array[Vector3] = []
	var centre := Vector3.ZERO
	for p: Vector2 in profile:
		a.append(xf * Vector3(x0, p.y, p.x))
		b.append(xf * Vector3(x1, p.y, p.x))
		centre += xf * Vector3((x0 + x1) * 0.5, p.y, p.x)
	centre /= float(n)
	if show:
		var st: SurfaceTool = _st(key)
		for i: int in n:
			var j: int = (i + 1) % n
			_quad(st, key, a[i], a[j], b[j], b[i], centre)
		for i: int in range(1, n - 1):
			_tri(st, key, a[0], a[i], a[i + 1], a[0] - b[0])
			_tri(st, key, b[0], b[i], b[i + 1], b[0] - a[0])
	if collide:
		var pts := PackedVector3Array()
		for v: Vector3 in a:
			pts.append(v)
		for v: Vector3 in b:
			pts.append(v)
		var cs := CollisionShape3D.new()
		cs.name = "Prism%d" % _n_shapes
		_n_shapes += 1
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		cs.shape = shape
		body.add_child(cs)


## A wedge (ramp or bank) along local x in [x0, x1]: rises from (z_low, y0) to (z_high, y1) with a flat bottom at y0
## and a vertical back at z_high. Just a prism with a triangle profile.
func wedge(xf: Transform3D, x0: float, x1: float, z_low: float, z_high: float, y0: float, y1: float, key: String, collide: bool = true) -> void:
	prism(xf, PackedVector2Array([Vector2(z_low, y0), Vector2(z_high, y0), Vector2(z_high, y1)]), x0, x1, key, collide)


## A surface of revolution about the vertical axis through `centre`. `prof` is (r, y) pairs walked so that the visible
## side is on the right of the walk (outside -> in for a basin: outer wall up, over the rim, down the bowl, across the
## floor). `a0`, `a1` limit the sweep (radians, default the full circle). Collision (if any) is trimesh.
func lathe(centre: Vector3, prof: PackedVector2Array, segs: int, key: String, collide: bool = true, a0: float = 0.0, a1: float = TAU) -> void:
	var st: SurfaceTool = _st(key)
	for s: int in segs:
		var t0: float = lerpf(a0, a1, float(s) / float(segs))
		var t1: float = lerpf(a0, a1, float(s + 1) / float(segs))
		var tm: float = (t0 + t1) * 0.5
		for j: int in prof.size() - 1:
			var p: Vector2 = prof[j]
			var q: Vector2 = prof[j + 1]
			var d: Vector2 = q - p
			var n2 := Vector2(d.y, -d.x)  # right of the walk
			var hint := Vector3(n2.x * cos(tm), n2.y, n2.x * sin(tm))
			var v00: Vector3 = centre + Vector3(p.x * cos(t0), p.y, p.x * sin(t0))
			var v01: Vector3 = centre + Vector3(p.x * cos(t1), p.y, p.x * sin(t1))
			var v10: Vector3 = centre + Vector3(q.x * cos(t0), q.y, q.x * sin(t0))
			var v11: Vector3 = centre + Vector3(q.x * cos(t1), q.y, q.x * sin(t1))
			# a profile point on the axis makes one of these degenerate; _tri_dir drops it
			_tri_dir(st, key, v00, v01, v11, hint, collide)
			_tri_dir(st, key, v00, v11, v10, hint, collide)


## One triangle facing `n` (optionally part of the area's trimesh collision).
func tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, collide: bool, key: String) -> void:
	_tri_dir(_st(key), key, a, b, c, n, collide)


## A flat disc decal (a tree grate, a painted circle) of radius r at c, lifted 0.012.
func vflat_ring(c: Vector3, r: float, key: String, segs: int = 16) -> void:
	lathe(c + Vector3(0.0, 0.012, 0.0), PackedVector2Array([Vector2(r, 0.0), Vector2(0.0, 0.0)]), segs, key, false)


## An additive light pool on the floor (a lamp's glow without a light): one textured quad, merged per colour.
func pool(c: Vector3, radius: float, colour: Color, strength: float) -> void:
	var key: String = "pool_%s_%.2f" % [colour.to_html(false), strength]
	if not _mats.has(key):
		var mi: MeshInstance3D = FlickerLight.light_pool(1.0, colour, strength)
		_mats[key] = mi.material_override
		_no_shadow[key] = true
		mi.free()
	var st: SurfaceTool = _st(key)
	var a := c + Vector3(-radius, 0.0, -radius)
	var b := c + Vector3(radius, 0.0, -radius)
	var d := c + Vector3(radius, 0.0, radius)
	var e := c + Vector3(-radius, 0.0, radius)
	for v: Array in [[a, Vector2(0, 0)], [b, Vector2(1, 0)], [d, Vector2(1, 1)], [a, Vector2(0, 0)], [d, Vector2(1, 1)], [e, Vector2(0, 1)]]:  # clockwise from above = front
		st.set_normal(Vector3.UP)
		st.set_uv(v[1] as Vector2)
		st.add_vertex(v[0] as Vector3)
	_counts[key] = int(_counts[key]) + 6


## A flat visual quad (decals: painted lines, track lanes) facing `n`.
func decal(a: Vector3, b: Vector3, c: Vector3, d: Vector3, key: String, n: Vector3 = Vector3.UP) -> void:
	var st: SurfaceTool = _st(key)
	_tri_dir(st, key, a, b, c, n, false)
	_tri_dir(st, key, a, c, d, n, false)


## An axis-aligned flat decal rectangle on y (world x/z rect), lifted `lift` above y.
func flat(r: Rect2, y: float, key: String, lift: float = 0.012) -> void:
	var yy: float = y + lift
	decal(Vector3(r.position.x, yy, r.position.y), Vector3(r.end.x, yy, r.position.y), Vector3(r.end.x, yy, r.end.y), Vector3(r.position.x, yy, r.end.y), key)


## A thin flat strip from a to b (world, same y), width w, lifted.
func strip(a: Vector3, b: Vector3, w: float, key: String, lift: float = 0.012) -> void:
	var d: Vector3 = (b - a)
	d.y = 0.0
	var s: Vector3 = Vector3(-d.z, 0.0, d.x).normalized() * w * 0.5
	var up := Vector3(0.0, lift, 0.0)
	decal(a - s + up, b - s + up, b + s + up, a + s + up, key)


## A cylinder (visual, optional convex collision) between two points.
func cyl(a: Vector3, b: Vector3, r: float, key: String, sides: int = 8, collide: bool = false) -> void:
	var axis: Vector3 = b - a
	var len: float = axis.length()
	if len < 0.0001:
		return
	var y: Vector3 = axis / len
	var x: Vector3 = (Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).cross(y).normalized()
	var z: Vector3 = y.cross(x)
	var st: SurfaceTool = _st(key)
	var mid: Vector3 = (a + b) * 0.5
	for i: int in sides:
		var t0: float = TAU * float(i) / float(sides)
		var t1: float = TAU * float(i + 1) / float(sides)
		var o0: Vector3 = (x * cos(t0) + z * sin(t0)) * r
		var o1: Vector3 = (x * cos(t1) + z * sin(t1)) * r
		_quad(st, key, a + o0, a + o1, b + o1, b + o0, mid)
		_tri_dir(st, key, b, b + o0, b + o1, y, false)
		_tri_dir(st, key, a, a + o1, a + o0, -y, false)
	if collide:
		var cs := CollisionShape3D.new()
		cs.name = "Cyl%d" % _n_shapes
		_n_shapes += 1
		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = len
		cs.shape = shape
		cs.transform = Transform3D(Basis(x, y, z), mid)
		body.add_child(cs)


## A collision-only oriented box (centre and rotation from xf).
func osolid(xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	cs.name = "OSolid%d" % _n_shapes
	_n_shapes += 1
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)


## A collision-only box (an invisible blocker under something visual that is solid).
func solid(min_corner: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	cs.name = "Solid%d" % _n_shapes
	_n_shapes += 1
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = min_corner + size * 0.5
	body.add_child(cs)


# --- output ---------------------------------------------------------------------------------------------

## Creates one MeshInstance3D per material under the parent, and the trimesh collision. Call once, at the end.
func commit() -> void:
	var holder := Node3D.new()
	holder.name = area + "Mesh"
	parent.add_child(holder)
	var keys: Array = _batches.keys()
	keys.sort()
	for key: String in keys:
		if int(_counts.get(key, 0)) == 0:
			continue
		var st: SurfaceTool = _batches[key]
		var mi := MeshInstance3D.new()
		mi.name = key
		mi.mesh = st.commit()
		mi.material_override = SchoolGeo._batch_mat(key)
		if _no_shadow.has(key):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	if not _trimesh.is_empty():
		var cs := CollisionShape3D.new()
		cs.name = "Trimesh"
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(_trimesh)
		shape.backface_collision = false
		cs.shape = shape
		body.add_child(cs)
	_batches.clear()


# --- internals ------------------------------------------------------------------------------------------

func _st(key: String) -> SurfaceTool:
	var bk: String = SchoolGeo._batch_key(key)
	if not _batches.has(bk):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[bk] = st
		_counts[bk] = 0
	return _batches[bk] as SurfaceTool


## Quad a, b, c, d (loop order), facing away from `inside`.
func _quad(st: SurfaceTool, key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
	var want: Vector3 = (a + b + c + d) * 0.25 - inside
	_tri_dir(st, key, a, b, c, want, false)
	_tri_dir(st, key, a, c, d, want, false)


func _tri(st: SurfaceTool, key: String, a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	_tri_dir(st, key, a, b, c, want, false)


## Emits triangle a, b, c with its normal along `want` (flipped if needed). Optionally adds it to the trimesh.
func _tri_dir(st: SurfaceTool, key: String, a: Vector3, b: Vector3, c: Vector3, want: Vector3, collide: bool) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	if n.dot(want) < 0.0:
		var t: Vector3 = b
		b = c
		c = t
		n = -n
	n = n.normalized()
	# Godot's front face is clockwise: emit the outside-CCW triangle reversed.
	var vc: bool = _colour.has(key)
	var col: Color = _colour.get(key, Color.WHITE)
	if vc and key.begins_with("toon_"):
		col = col.srgb_to_linear()  # the toon shader multiplies by COLOR as is (linear); glowvc converts itself
	for v: Vector3 in [a, c, b]:
		st.set_normal(n)
		if vc:
			st.set_color(col)
		st.add_vertex(v)
	var bk: String = SchoolGeo._batch_key(key)
	_counts[bk] = int(_counts[bk]) + 3
	if collide:
		_trimesh.append(a)
		_trimesh.append(c)
		_trimesh.append(b)
