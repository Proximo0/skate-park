class_name DomeBowl
extends RefCounted
## A half-sphere bowl sunk into the ground, like a giant salad bowl. The riding surface is a spherical cap: the rim
## circle has radius `radius` at y = 0 and the bottom sits at y = -radius * depth_ratio. With depth_ratio near 1 the
## walls are near-vertical at the top. The centre of the hole sits at (half, ., half) with half = radius + MARGIN, so
## the footprint spans x in [0, size] and z in [0, size] with size = 2 * (radius + MARGIN). The rim is at y = 0.
## Pieces: "Shell" (the sphere cap, trimesh collision, normals into the bowl; surfaces: concrete, a tile band under
## the rim, and a painted target at the bottom), "Deck" (the square ground frame around the hole with a solid skirt
## down to the bottom, so nothing shows through), "Coping" (a closed "coping" GrindRail on the rim), "CopingPipe"
## (visual metal pipe along the coping) and the gap zone "<zone_prefix>_air" above the centre.

const MARGIN: float = 1.5
const TILE_BLUE: Color = Color("7fd3f5")
const PIPE_RADIUS: float = 0.05
const PIPE_SIDES: int = 8
## The tile band runs from just under the rim down to BAND_BOTTOM_Y.
const BAND_TOP_Y: float = -0.15
const BAND_BOTTOM_Y: float = -0.9
## Target rings on the floor: bins of TARGET_BIN metres out to TARGET_R, alternating yellow and red.
const TARGET_BIN: float = 0.8
const TARGET_R: float = 2.4
const GAP_HEIGHT: float = 4.0
const GAP_WIDTH_FACTOR: float = 1.2


static func build(radius: float = 8.0, depth_ratio: float = 0.85, rings: int = 16, segments: int = 48, zone_prefix: String = "dome") -> Node3D:
	var root := Node3D.new()
	root.name = "DomeBowl"
	var a: float = maxf(radius, 0.5)
	var d: float = a * clampf(depth_ratio, 0.1, 2.0)
	var half: float = a + MARGIN
	var nr: int = maxi(rings, 2)
	# the square deck's corners must fall on ray boundaries, so the segment count is a multiple of 8
	var n: int = 8 * maxi(ceili(float(segments) / 8.0), 1)
	# sphere through the rim circle (radius a at y = 0) and the bottom (y = -d)
	var rs: float = (a * a + d * d) / (2.0 * d)
	var yc: float = rs - d
	var theta_max: float = acos(clampf(yc / rs, -1.0, 1.0))

	var colours: Array[Color] = []
	var shell_mesh: ArrayMesh = _dome_mesh(rs, yc, theta_max, half, nr, n, colours)
	var shell: StaticBody3D = PieceKit.body(shell_mesh, PieceKit.CONCRETE, "Shell")
	var shell_mi: MeshInstance3D = shell.get_node("Mesh") as MeshInstance3D
	shell_mi.material_override = null
	for k: int in colours.size():
		shell_mi.set_surface_override_material(k, Toon.material(colours[k]))
	root.add_child(shell)

	root.add_child(PieceKit.body(_deck_mesh(a, d, half, n), PieceKit.CONCRETE, "Deck"))

	var loop := PackedVector3Array()
	for j: int in n + 1:
		var phi: float = TAU * float(j) / float(n)
		loop.append(Vector3(half + a * cos(phi), 0.0, half + a * sin(phi)))
	root.add_child(PieceKit.rail(loop, "coping", "Coping"))
	var pipe := MeshInstance3D.new()
	pipe.name = "CopingPipe"
	pipe.mesh = _pipe_mesh(a, half, n)
	pipe.material_override = Toon.material(PieceKit.METAL)
	root.add_child(pipe)

	var w: float = a * GAP_WIDTH_FACTOR
	root.add_child(PieceKit.gap_zone(zone_prefix + "_air", Vector3(half - w * 0.5, 0.0, half - w * 0.5), Vector3(w, GAP_HEIGHT, w)))
	return root


## Point on the sphere at polar angle theta (from the bottom pole) and azimuth phi, in the bowl's local space.
static func _sphere_point(theta: float, phi: float, rs: float, yc: float, half: float) -> Vector3:
	var r: float = rs * sin(theta)
	return Vector3(half + r * cos(phi), yc - rs * cos(theta), half + r * sin(phi))


## Unit normal of the sphere at (theta, phi), pointing toward the centre (into the bowl).
static func _inward(theta: float, phi: float) -> Vector3:
	return Vector3(-sin(theta) * cos(phi), cos(theta), -sin(theta) * sin(phi))


## The riding surface, split into surfaces: 0 concrete, 1 tile band, 2 yellow target, 3 red target. Only the
## surfaces with faces are committed; `colours` receives the colour of each committed surface, in order.
static func _dome_mesh(rs: float, yc: float, theta_max: float, half: float, nr: int, n: int, colours: Array[Color]) -> ArrayMesh:
	var palette: Array[Color] = [PieceKit.CONCRETE, TILE_BLUE, PieceKit.PAINT_YELLOW, PieceKit.PAINT_RED]
	var sts: Array[SurfaceTool] = []
	var counts: Array[int] = []
	for k: int in palette.size():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts.append(st)
		counts.append(0)
	for i: int in nr:
		var t0: float = theta_max * float(i) / float(nr)
		var t1: float = theta_max * float(i + 1) / float(nr)
		var tm: float = (t0 + t1) * 0.5
		var y_mid: float = yc - rs * cos(tm)
		var r_mid: float = rs * sin(tm)
		var slot: int = 0
		if y_mid <= BAND_TOP_Y and y_mid >= BAND_BOTTOM_Y:
			slot = 1
		if r_mid < TARGET_R:
			slot = 2 if int(r_mid / TARGET_BIN) % 2 == 0 else 3
		var st: SurfaceTool = sts[slot]
		for j: int in n:
			var p0: float = TAU * float(j) / float(n)
			var p1: float = TAU * float(j + 1) / float(n)
			var q00: Vector3 = _sphere_point(t0, p0, rs, yc, half)
			var q01: Vector3 = _sphere_point(t0, p1, rs, yc, half)
			var q10: Vector3 = _sphere_point(t1, p0, rs, yc, half)
			var q11: Vector3 = _sphere_point(t1, p1, rs, yc, half)
			var n00: Vector3 = _inward(t0, p0)
			var n01: Vector3 = _inward(t0, p1)
			var n10: Vector3 = _inward(t1, p0)
			var n11: Vector3 = _inward(t1, p1)
			_tri(st, q00, q10, q11, n00, n10, n11)
			_tri(st, q00, q11, q01, n00, n11, n01)
			counts[slot] += 6
	var mesh := ArrayMesh.new()
	for k: int in palette.size():
		if counts[k] > 0:
			sts[k].commit(mesh)
			colours.append(palette[k])
	return mesh


## Ground frame: the square footprint minus the hole, from y = 0 down to -d. The square corners lie on the rays
## from the centre, so each wedge between two rays is one quad (top, bottom, hole wall, outer wall).
static func _deck_mesh(a: float, d: float, half: float, n: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hole := PackedVector2Array()
	var outer := PackedVector2Array()
	for j: int in n:
		var phi: float = TAU * float(j) / float(n)
		hole.append(Vector2(half + a * cos(phi), half + a * sin(phi)))
		outer.append(_edge_point(phi, half))
	var centre := Vector2(half, half)
	for j: int in n:
		var j1: int = (j + 1) % n
		var phi0: float = TAU * float(j) / float(n)
		var phi1: float = TAU * float(j + 1) / float(n)
		var h0: Vector2 = hole[j]
		var h1: Vector2 = hole[j1]
		var o0: Vector2 = outer[j]
		var o1: Vector2 = outer[j1]
		# top and bottom of the slab
		_quad(st, _v3(h0, 0.0), _v3(h1, 0.0), _v3(o1, 0.0), _v3(o0, 0.0), Vector3.UP)
		_quad(st, _v3(h0, -d), _v3(o0, -d), _v3(o1, -d), _v3(h1, -d), Vector3.DOWN)
		# hole wall faces into the hole
		var hn0 := Vector3(-cos(phi0), 0.0, -sin(phi0))
		var hn1 := Vector3(-cos(phi1), 0.0, -sin(phi1))
		_quad_n(st, _v3(h0, 0.0), _v3(h1, 0.0), _v3(h1, -d), _v3(h0, -d), hn0, hn1, hn1, hn0)
		# outer skirt faces away from the middle
		var sv: Vector2 = o1 - o0
		var on: Vector2 = Vector2(sv.y, -sv.x).normalized()
		if on.dot((o0 + o1) * 0.5 - centre) < 0.0:
			on = -on
		var out3 := Vector3(on.x, 0.0, on.y)
		_quad(st, _v3(o0, 0.0), _v3(o1, 0.0), _v3(o1, -d), _v3(o0, -d), out3)
	return st.commit()


## Where the ray from the centre at angle phi meets the square footprint (absolute x, z).
static func _edge_point(phi: float, half: float) -> Vector2:
	var dx: float = cos(phi)
	var dz: float = sin(phi)
	var t: float = INF
	if absf(dx) > 1e-9:
		t = minf(t, half / absf(dx))
	if absf(dz) > 1e-9:
		t = minf(t, half / absf(dz))
	return Vector2(half + dx * t, half + dz * t)


## Visual pipe: a torus of radius `a` around the rim at y = PIPE_RADIUS (the visible top half sits above the rim).
static func _pipe_mesh(a: float, half: float, n: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in n:
		var u0: float = TAU * float(j) / float(n)
		var u1: float = TAU * float(j + 1) / float(n)
		for k: int in PIPE_SIDES:
			var v0: float = TAU * float(k) / float(PIPE_SIDES)
			var v1: float = TAU * float(k + 1) / float(PIPE_SIDES)
			var p00: Vector3 = _torus_point(a, half, u0, v0)
			var p01: Vector3 = _torus_point(a, half, u0, v1)
			var p10: Vector3 = _torus_point(a, half, u1, v0)
			var p11: Vector3 = _torus_point(a, half, u1, v1)
			var n00: Vector3 = _torus_normal(u0, v0)
			var n01: Vector3 = _torus_normal(u0, v1)
			var n10: Vector3 = _torus_normal(u1, v0)
			var n11: Vector3 = _torus_normal(u1, v1)
			_tri(st, p00, p10, p11, n00, n10, n11)
			_tri(st, p00, p11, p01, n00, n11, n01)
	return st.commit()


static func _torus_point(a: float, half: float, u: float, v: float) -> Vector3:
	var rr: float = a + PIPE_RADIUS * cos(v)
	return Vector3(half + rr * cos(u), PIPE_RADIUS + PIPE_RADIUS * sin(v), half + rr * sin(u))


static func _torus_normal(u: float, v: float) -> Vector3:
	return Vector3(cos(v) * cos(u), sin(v), cos(v) * sin(u))


## A flat quad (p0, p1, p2, p3 in order around it) split into two triangles with one normal.
static func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, nrm: Vector3) -> void:
	_tri(st, p0, p1, p2, nrm, nrm, nrm)
	_tri(st, p0, p2, p3, nrm, nrm, nrm)


static func _quad_n(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n0: Vector3, n1: Vector3, n2: Vector3, n3: Vector3) -> void:
	_tri(st, p0, p1, p2, n0, n1, n2)
	_tri(st, p0, p2, p3, n0, n2, n3)


## Adds a triangle with per-vertex normals. Godot treats clockwise as front-facing, so the winding is chosen so the
## front face points the same way as the summed vertex normals (the side the bowl's air and the outside face).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var nrm: Vector3 = (b - a).cross(c - a)
	if nrm.length_squared() < 1e-12:
		return
	var want: Vector3 = na + nb + nc
	var p1: Vector3 = b
	var n1: Vector3 = nb
	var p2: Vector3 = c
	var n2: Vector3 = nc
	if nrm.dot(want) > 0.0:
		p1 = c
		n1 = nc
		p2 = b
		n2 = nb
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(n1)
	st.add_vertex(p1)
	st.set_normal(n2)
	st.add_vertex(p2)


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)
