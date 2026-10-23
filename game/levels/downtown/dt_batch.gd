class_name DtBatch
extends RefCounted
## Downtown: merges many small static shapes (boxes, cylinders, prisms, quads) into ONE vertex-coloured mesh, drawn
## with a single Toon.material_vc material, so a whole area's granite, trim, posts and clutter cost one draw call.
## Colours are given in sRGB like Toon.material and stored linear (the toon shader multiplies COLOR in linear).
## Faces get flat normals; winding is fixed from an outward normal hint, so every face renders with back-face culling.

var _st := SurfaceTool.new()
var tris: int = 0


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


## One triangle whose front faces `out` (any vector on the visible side).
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, out: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var lin: Color = col.srgb_to_linear()
	var flip: bool = n.dot(out) > 0.0
	var nn: Vector3 = n if flip else -n
	_st.set_color(lin)
	_st.set_normal(nn)
	_st.add_vertex(a)
	_st.set_color(lin)
	_st.set_normal(nn)
	_st.add_vertex(c if flip else b)
	_st.set_color(lin)
	_st.set_normal(nn)
	_st.add_vertex(b if flip else c)
	tris += 1


## A planar quad a-b-c-d (in order round its edge) facing `out`.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, out: Vector3) -> void:
	tri(a, b, c, col, out)
	tri(a, c, d, col, out)


## An oriented box: centre, full size, rotation. Skip faces with `skip_bottom` (boxes standing on the ground).
func box(centre: Vector3, size: Vector3, col: Color, basis: Basis = Basis.IDENTITY, skip_bottom: bool = true) -> void:
	var h: Vector3 = size * 0.5
	var c: Array[Vector3] = []
	for i: int in 8:
		var p := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		c.append(centre + basis * p)
	var bx: Vector3 = basis.x
	var by: Vector3 = basis.y
	var bz: Vector3 = basis.z
	quad(c[2], c[3], c[7], c[6], col, by)  # top
	if not skip_bottom:
		quad(c[0], c[1], c[5], c[4], col, -by)
	quad(c[1], c[3], c[7], c[5], col, bx)
	quad(c[0], c[2], c[6], c[4], col, -bx)
	quad(c[4], c[5], c[7], c[6], col, bz)
	quad(c[0], c[1], c[3], c[2], col, -bz)


## Axis-aligned box from its minimum corner.
func box_min(min_corner: Vector3, size: Vector3, col: Color, skip_bottom: bool = true) -> void:
	box(min_corner + size * 0.5, size, col, Basis.IDENTITY, skip_bottom)


## A box spanning segment a-b (its long axis), `w` wide and `h` tall (cross-section), the up side along world up when
## possible. For beams, rails as square bars, banner poles.
func bar(a: Vector3, b: Vector3, w: float, h: float, col: Color) -> void:
	var d: Vector3 = b - a
	var l: float = d.length()
	if l < 1e-5:
		return
	var z: Vector3 = d / l
	var up: Vector3 = Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x: Vector3 = up.cross(z).normalized()
	var y: Vector3 = z.cross(x).normalized()
	box((a + b) * 0.5, Vector3(w, h, l), col, Basis(x, y, z), false)


## A vertical cylinder (or cone/frustum) standing on `base`.
func cyl(base: Vector3, r_bottom: float, height: float, col: Color, sides: int = 10, r_top: float = -1.0, caps: bool = true) -> void:
	var rt: float = r_bottom if r_top < 0.0 else r_top
	for i: int in sides:
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var p0: Vector3 = base + d0 * r_bottom
		var p1: Vector3 = base + d1 * r_bottom
		var q0: Vector3 = base + Vector3(0.0, height, 0.0) + d0 * rt
		var q1: Vector3 = base + Vector3(0.0, height, 0.0) + d1 * rt
		quad(p0, p1, q1, q0, col, (d0 + d1) * 0.5)
		if caps and rt > 0.001:
			tri(base + Vector3(0.0, height, 0.0), q0, q1, col, Vector3.UP)


## A tube along segment a-b (round rails, pipes, poles at any angle).
func tube(a: Vector3, b: Vector3, r: float, col: Color, sides: int = 8) -> void:
	var d: Vector3 = b - a
	if d.length() < 1e-5:
		return
	var z: Vector3 = d.normalized()
	var up: Vector3 = Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x: Vector3 = up.cross(z).normalized()
	var y: Vector3 = z.cross(x)
	for i: int in sides:
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		var o0: Vector3 = (x * cos(a0) + y * sin(a0)) * r
		var o1: Vector3 = (x * cos(a1) + y * sin(a1)) * r
		quad(a + o0, a + o1, b + o1, b + o0, col, (o0 + o1))


## A dome (half sphere, or less with `frac`) on `base`.
func dome(base: Vector3, r: float, col: Color, frac: float = 1.0, sides: int = 16, rings: int = 6, squash: float = 1.0) -> void:
	for j: int in rings:
		var t0: float = float(j) / float(rings) * PI * 0.5 * frac
		var t1: float = float(j + 1) / float(rings) * PI * 0.5 * frac
		for i: int in sides:
			var a0: float = TAU * float(i) / float(sides)
			var a1: float = TAU * float(i + 1) / float(sides)
			var p00: Vector3 = base + Vector3(cos(a0) * cos(t0) * r, sin(t0) * r * squash, sin(a0) * cos(t0) * r)
			var p10: Vector3 = base + Vector3(cos(a1) * cos(t0) * r, sin(t0) * r * squash, sin(a1) * cos(t0) * r)
			var p01: Vector3 = base + Vector3(cos(a0) * cos(t1) * r, sin(t1) * r * squash, sin(a0) * cos(t1) * r)
			var p11: Vector3 = base + Vector3(cos(a1) * cos(t1) * r, sin(t1) * r * squash, sin(a1) * cos(t1) * r)
			var out: Vector3 = (p00 + p11) * 0.5 - base
			quad(p00, p10, p11, p01, col, out)


## A prism: the 2D profile (Vector2(z, y) points, any winding, convex or fan-safe from point 0) extruded across x in
## [x0, x1], then placed with `xf`.
func prism(profile: PackedVector2Array, x0: float, x1: float, col: Color, xf: Transform3D = Transform3D.IDENTITY) -> void:
	var n: int = profile.size()
	var cz: Vector2 = Vector2.ZERO
	for p: Vector2 in profile:
		cz += p
	cz /= float(n)
	for i: int in n:
		var p: Vector2 = profile[i]
		var q: Vector2 = profile[(i + 1) % n]
		var a: Vector3 = xf * Vector3(x0, p.y, p.x)
		var b: Vector3 = xf * Vector3(x0, q.y, q.x)
		var c: Vector3 = xf * Vector3(x1, q.y, q.x)
		var d: Vector3 = xf * Vector3(x1, p.y, p.x)
		var mid: Vector2 = (p + q) * 0.5 - cz
		quad(a, b, c, d, col, xf.basis * Vector3(0.0, mid.y, mid.x))
	for i: int in range(1, n - 1):
		var a2: Vector2 = profile[0]
		var b2: Vector2 = profile[i]
		var c2: Vector2 = profile[i + 1]
		tri(xf * Vector3(x0, a2.y, a2.x), xf * Vector3(x0, b2.y, b2.x), xf * Vector3(x0, c2.y, c2.x), col, xf.basis * Vector3.LEFT)
		tri(xf * Vector3(x1, a2.y, a2.x), xf * Vector3(x1, b2.y, b2.x), xf * Vector3(x1, c2.y, c2.x), col, xf.basis * Vector3.RIGHT)


func is_empty() -> bool:
	return tris == 0


func mesh() -> ArrayMesh:
	return _st.commit()


## The merged mesh as one MeshInstance3D with the shared vertex-colour toon material.
func instance(node_name: String, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh()
	mi.material_override = Toon.material_vc(Color.WHITE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
