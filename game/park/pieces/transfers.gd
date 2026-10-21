class_name Transfers
extends RefCounted
## Transfer pieces: a pyramid to ride over, a spine (two quarter pipes back to back) and a hip (two quarter pipes
## meeting at an outside corner). Each builder returns a Node3D whose origin is at ground level at the back-left
## corner of its footprint, like the other park pieces. Heights are built as height fields over a grid and closed
## with skirts down to the ground, so every face is wound outward (see _tri).


## A four-sided truncated pyramid. Footprint x, z in [0, base]; flat square top of side `top` at `height`.
static func pyramid(base: float = 9.0, top: float = 3.0, height: float = 1.4, zone_prefix: String = "pyramid") -> Node3D:
	var root := Node3D.new()
	root.name = "Pyramid"
	var inset: float = (base - top) * 0.5
	var p: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(base, 0.0, 0.0), Vector3(base, 0.0, base), Vector3(0.0, 0.0, base)]
	var t: Array[Vector3] = [
		Vector3(inset, height, inset), Vector3(base - inset, height, inset),
		Vector3(base - inset, height, base - inset), Vector3(inset, height, base - inset),
	]
	var centre := Vector3(base * 0.5, height * 0.5, base * 0.5)
	var tris: Array[Vector3] = []
	_quad(tris, t[0], t[1], t[2], t[3], Vector3.UP)
	for k: int in 4:
		var a: Vector3 = p[k]
		var b: Vector3 = p[(k + 1) % 4]
		var c: Vector3 = t[(k + 1) % 4]
		var d: Vector3 = t[k]
		_quad(tris, a, b, c, d, (a + b + c + d) * 0.25 - centre)
	root.add_child(PieceKit.body(_mesh(tris), PieceKit.RAMP_SIDE, "Banks"))
	# ledge on the closed top edge, and on each sloped hip edge from the top corner down to the base corner
	root.add_child(PieceKit.rail(PackedVector3Array([t[0], t[1], t[2], t[3], t[0]]), "ledge", "TopEdge"))
	for k: int in 4:
		root.add_child(PieceKit.rail(PackedVector3Array([t[k], p[k]]), "ledge", "Hip%d" % k))
	# gap zones sit just beyond the bottom of the -Z and +Z banks, ground to 3 m, full width, 1.5 m deep
	root.add_child(PieceKit.gap_zone(zone_prefix + "_n", Vector3(0.0, 0.0, -1.5), Vector3(base, 3.0, 1.5)))
	root.add_child(PieceKit.gap_zone(zone_prefix + "_s", Vector3(0.0, 0.0, base), Vector3(base, 3.0, 1.5)))
	return root


## A spine: two quarter pipes back to back along X, sharing one fin whose top is the coping at `height`.
## Footprint x in [0, length], z in [0, 2 * radius]. Each pipe's curve reaches `radius` at the fin.
static func spine(length: float = 8.0, radius: float = 2.2, height: float = 2.4) -> Node3D:
	var root := Node3D.new()
	root.name = "Spine"
	var fin: float = 0.2
	var rh: float = radius - fin * 0.5  # horizontal reach of each pipe
	var left := func(_x: float, z: float) -> float: return _tr_lip(z, rh, radius)
	var right := func(_x: float, z: float) -> float: return _tr_lip(2.0 * radius - z, rh, radius)
	var top := func(_x: float, _z: float) -> float: return height
	var tris: Array[Vector3] = []
	_patch(tris, 0.0, length, 0.0, rh, 2, 12, left)
	_patch(tris, 0.0, length, rh, rh + fin, 2, 1, top)
	_patch(tris, 0.0, length, rh + fin, 2.0 * radius, 2, 12, right)
	root.add_child(PieceKit.body(_mesh(tris), PieceKit.RAMP_WOOD, "Ramps"))
	var cop := PieceKit.round_rail(Vector3(0.0, height, radius), Vector3(length, height, radius), 0.05, PieceKit.METAL, "Coping")
	(cop.get_node("Line") as GrindRail).kind = "coping"
	root.add_child(cop)
	return root


## A hip: an L of two quarter pipes around a 90 degree outside corner. Footprint x, z in [0, size].
## The deck (x, z >= radius) is flat at `height`; each leg's curve runs down to the ground on the outside, and a
## corner wedge fills the outside corner (min of the two curves, so the diagonal is a shallow crease).
## Coping runs along both lips as one polyline meeting at (radius, height, radius).
static func hip(size: float = 8.0, radius: float = 2.5, height: float = 2.8, zone_prefix: String = "hip") -> Node3D:
	var root := Node3D.new()
	root.name = "Hip"
	var r: float = radius
	var s: float = size
	var legZ := func(_x: float, z: float) -> float: return _tr_lip(z, r, r)
	var legX := func(x: float, _z: float) -> float: return _tr_lip(x, r, r)
	var deck := func(_x: float, _z: float) -> float: return height
	var corner := func(x: float, z: float) -> float: return minf(_tr_lip(x, r, r), _tr_lip(z, r, r))
	var tris: Array[Vector3] = []
	_patch(tris, r, s, 0.0, r, 2, 12, legZ)     # leg along X, lip at z = r
	_patch(tris, r, s, r, s, 1, 1, deck)        # flat deck
	_patch(tris, 0.0, r, r, s, 12, 2, legX)     # leg along Z, lip at x = r
	_patch(tris, 0.0, r, 0.0, r, 12, 12, corner)  # outside corner wedge
	root.add_child(PieceKit.body(_mesh(tris), PieceKit.RAMP_WOOD, "Ramps"))
	# visible pipes along each lip, then one coping polyline through the corner
	var pipe_x: Node3D = PieceKit.round_rail(Vector3(s, height, r), Vector3(r, height, r), 0.05, PieceKit.METAL, "PipeX")
	var pipe_z: Node3D = PieceKit.round_rail(Vector3(r, height, r), Vector3(r, height, s), 0.05, PieceKit.METAL, "PipeZ")
	pipe_x.get_node("Line").free()
	pipe_z.get_node("Line").free()
	root.add_child(pipe_x)
	root.add_child(pipe_z)
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(s, height, r), Vector3(r, height, r), Vector3(r, height, s)]), "coping", "Coping"))
	# gap zones over each lip, clear of the corner: _n over the X lip, _s over the Z lip
	root.add_child(PieceKit.gap_zone(zone_prefix + "_n", Vector3(r + 1.0, height, r - 1.0), Vector3(s - r - 1.0, 3.0, 2.0)))
	root.add_child(PieceKit.gap_zone(zone_prefix + "_s", Vector3(r - 1.0, height, r + 1.0), Vector3(2.0, 3.0, s - r - 1.0)))
	return root


## Height of a quarter-pipe curve at horizontal distance t from the ground end: 0 at t = 0, `r_top` at t = reach.
static func _tr_lip(t: float, reach: float, r_top: float) -> float:
	var u: float = clampf(t / reach, 0.0, 1.0)
	return r_top - r_top * sqrt(maxf(1.0 - u * u, 0.0))


## Build the render and collision mesh from triangles wound counter-clockwise seen from outside (cross product
## points out). Godot treats clockwise as front-facing, so each triangle is emitted reversed, with its outward
## normal set explicitly. PieceKit.mesh_from_triangles does not do this: it keeps the wound order, so its faces
## show from inside and its normals point in.
static func _mesh(tris: Array[Vector3]) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(0, tris.size(), 3):
		var a: Vector3 = tris[i]
		var b: Vector3 = tris[i + 1]
		var c: Vector3 = tris[i + 2]
		var n: Vector3 = (b - a).cross(c - a).normalized()
		for v: Vector3 in [a, c, b]:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()


## Emit triangle a, b, c, flipped if needed so its outward normal (cross product) points the same way as `want`.
static func _tri(tris: Array[Vector3], a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.dot(want) < 0.0:
		tris.append_array([a, c, b])
	else:
		tris.append_array([a, b, c])


## Emit quad a, b, c, d (in loop order) as two triangles facing `want`.
static func _quad(tris: Array[Vector3], a: Vector3, b: Vector3, c: Vector3, d: Vector3, want: Vector3) -> void:
	_tri(tris, a, b, c, want)
	_tri(tris, a, c, d, want)


## A vertical wall from the ground up to heights ha, hb along the XZ segment a -> b.
static func _wall(tris: Array[Vector3], ax: float, az: float, bx: float, bz: float, ha: float, hb: float, want: Vector3) -> void:
	if ha <= 0.000001 and hb <= 0.000001:
		return
	_quad(tris, Vector3(ax, 0.0, az), Vector3(bx, 0.0, bz), Vector3(bx, hb, bz), Vector3(ax, ha, az), want)


## A rectangle [x0, x1] x [z0, z1] of top surface y = fn(x, z), split into nx by nz cells, with skirts down to the
## ground on all four sides. Adjacent patches meet at a shared edge, so a height step there becomes a visible lip.
static func _patch(tris: Array[Vector3], x0: float, x1: float, z0: float, z1: float, nx: int, nz: int, fn: Callable) -> void:
	var xs: Array[float] = []
	var zs: Array[float] = []
	for i: int in nx + 1:
		xs.append(lerpf(x0, x1, float(i) / float(nx)))
	for j: int in nz + 1:
		zs.append(lerpf(z0, z1, float(j) / float(nz)))
	var w: int = nz + 1
	var hs: Array[float] = []
	for i: int in nx + 1:
		for j: int in nz + 1:
			hs.append(float(fn.call(xs[i], zs[j])))
	for i: int in nx:
		for j: int in nz:
			var p00 := Vector3(xs[i], hs[i * w + j], zs[j])
			var p10 := Vector3(xs[i + 1], hs[(i + 1) * w + j], zs[j])
			var p11 := Vector3(xs[i + 1], hs[(i + 1) * w + j + 1], zs[j + 1])
			var p01 := Vector3(xs[i], hs[i * w + j + 1], zs[j + 1])
			# the diagonal p00 -> p11 is the corner crease for the wedge, so every cell splits along it
			_tri(tris, p00, p10, p11, Vector3.UP)
			_tri(tris, p00, p11, p01, Vector3.UP)
	for j: int in nz:
		_wall(tris, x0, zs[j], x0, zs[j + 1], hs[j], hs[j + 1], Vector3.LEFT)
		_wall(tris, x1, zs[j], x1, zs[j + 1], hs[nx * w + j], hs[nx * w + j + 1], Vector3.RIGHT)
	for i: int in nx:
		_wall(tris, xs[i], z0, xs[i + 1], z0, hs[i * w], hs[(i + 1) * w], Vector3.FORWARD)
		_wall(tris, xs[i], z1, xs[i + 1], z1, hs[i * w + nz], hs[(i + 1) * w + nz], Vector3.BACK)
