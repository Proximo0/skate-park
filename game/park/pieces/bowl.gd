class_name Bowl
extends RefCounted
## A rounded-rectangle concrete bowl sunk into the ground, like a backyard pool. Footprint x in [0, size_x],
## z in [0, size_z]; the rim sits at y = 0 and the floor at y = -depth. Walls run from the rim down vertically,
## turn through a quarter circle of radius `transition` and meet the flat floor. The corners are offsets of the
## rounded rectangle, so the wall is parallel to the rim all the way round.
## The piece carries its own ground frame (a slab around the hole, from y = 0 down to the floor), so nothing shows
## through. Coping is a closed "coping" GrindRail on the rim with a visible metal pipe along it. Gap zones
## "<zone_prefix>_rim_n" (over the -Z rim) and "<zone_prefix>_rim_s" (over the +Z rim) match data/gaps.json.

const TILE_BLUE: Color = Color("7fd3f5")
## The painted tile stripe runs from just under the rim down to this fraction of the depth.
const BAND_TOP_Y: float = -0.15
const BAND_BOTTOM_FRACTION: float = 0.65
const GAP_WIDTH: float = 1.5
const GAP_HEIGHT: float = 3.0
const PIPE_RADIUS: float = 0.05


static func build(size_x: float = 14.0, size_z: float = 10.0, depth: float = 2.6, corner_radius: float = 3.0, transition: float = 2.4, segments: int = 10, zone_prefix: String = "bowl") -> Node3D:
	var root := Node3D.new()
	root.name = "Bowl"
	var seg: int = maxi(segments, 2)
	var rim_r: float = clampf(corner_radius, 0.0, minf(size_x, size_z) * 0.5)
	var t: float = clampf(transition, 0.01, depth)

	var shell: StaticBody3D = PieceKit.body(_shell_mesh(size_x, size_z, depth, rim_r, t, seg), PieceKit.CONCRETE, "Shell", true)
	var shell_mi: MeshInstance3D = shell.get_node("Mesh") as MeshInstance3D
	shell_mi.material_override = null
	shell_mi.set_surface_override_material(0, Toon.material(PieceKit.CONCRETE))
	if shell_mi.mesh.get_surface_count() > 1:
		shell_mi.set_surface_override_material(1, Toon.material(TILE_BLUE))
	root.add_child(shell)

	root.add_child(PieceKit.body(_deck_mesh(size_x, size_z, depth, rim_r, seg), PieceKit.CONCRETE, "Deck", true))

	var rim: PackedVector2Array = _ring(size_x, size_z, 0.0, rim_r, seg)
	var loop := PackedVector3Array()
	for p: Vector2 in rim:
		loop.append(Vector3(p.x, 0.0, p.y))
	loop.append(loop[0])
	root.add_child(PieceKit.rail(loop, "coping", "Coping"))
	var pipes := Node3D.new()
	pipes.name = "CopingPipes"
	for i: int in range(loop.size() - 1):
		var pipe: Node3D = PieceKit.round_rail(loop[i], loop[i + 1], PIPE_RADIUS, PieceKit.COPING, "CopingPipe%d" % i)
		# visual pipe only: the coping GrindRail above is the grind line
		var line: Node = pipe.get_node("Line")
		pipe.remove_child(line)
		line.free()
		pipes.add_child(pipe)
	root.add_child(pipes)

	var cx: float = size_x * 0.5
	root.add_child(PieceKit.gap_zone(zone_prefix + "_rim_n", Vector3(cx - GAP_WIDTH * 0.5, 0.0, -GAP_WIDTH * 0.5), Vector3(GAP_WIDTH, GAP_HEIGHT, GAP_WIDTH)))
	root.add_child(PieceKit.gap_zone(zone_prefix + "_rim_s", Vector3(cx - GAP_WIDTH * 0.5, 0.0, size_z - GAP_WIDTH * 0.5), Vector3(GAP_WIDTH, GAP_HEIGHT, GAP_WIDTH)))
	return root


## One closed loop of the rounded rectangle inset by `inset` (x, z), with 4 * (seg + 1) points. The corner radius
## shrinks by the inset (sharp once the inset passes the rim radius). Index i is the same place on every ring, so
## rings of the same seg can be stitched.
static func _ring(size_x: float, size_z: float, inset: float, rim_r: float, seg: int) -> PackedVector2Array:
	var half: float = minf(size_x - 2.0 * inset, size_z - 2.0 * inset) * 0.5
	var r: float = clampf(rim_r - inset, 0.0, half)
	var centres: Array[Vector2] = [
		Vector2(inset + r, inset + r),
		Vector2(size_x - inset - r, inset + r),
		Vector2(size_x - inset - r, size_z - inset - r),
		Vector2(inset + r, size_z - inset - r),
	]
	var pts := PackedVector2Array()
	for c: int in 4:
		var a0: float = PI + PI * 0.5 * float(c)
		for k: int in seg + 1:
			var a: float = a0 + PI * 0.5 * float(k) / float(seg)
			pts.append(centres[c] + Vector2(cos(a), sin(a)) * r)
	return pts


## Wall profile as (inset, y) pairs from the rim down to the floor.
static func _profile(depth: float, t: float, seg: int) -> PackedVector2Array:
	var prof := PackedVector2Array()
	prof.append(Vector2(0.0, 0.0))
	prof.append(Vector2(0.0, -(depth - t)))
	for i: int in range(1, seg + 1):
		var th: float = PI * 0.5 * float(i) / float(seg)
		prof.append(Vector2(t * (1.0 - cos(th)), -(depth - t) - t * sin(th)))
	return prof


static func _shell_mesh(size_x: float, size_z: float, depth: float, rim_r: float, t: float, seg: int) -> ArrayMesh:
	var prof: PackedVector2Array = _profile(depth, t, seg)
	var rings: Array[PackedVector2Array] = []
	for p: Vector2 in prof:
		rings.append(_ring(size_x, size_z, p.x, rim_r, seg))
	var centre := Vector2(size_x * 0.5, size_z * 0.5)
	var concrete := SurfaceTool.new()
	concrete.begin(Mesh.PRIMITIVE_TRIANGLES)
	var band := SurfaceTool.new()
	band.begin(Mesh.PRIMITIVE_TRIANGLES)
	var band_count: int = 0
	var band_bottom: float = -depth * BAND_BOTTOM_FRACTION
	var n: int = rings[0].size()
	for k: int in range(prof.size() - 1):
		var a2: Vector2 = prof[k]
		var b2: Vector2 = prof[k + 1]
		var d: Vector2 = b2 - a2
		# left of the walk down the wall: the air side of the shell
		var n2: Vector2 = Vector2(-d.y, d.x).normalized()
		var in_band: bool = a2.y <= BAND_TOP_Y and b2.y >= band_bottom
		var st: SurfaceTool = band if in_band else concrete
		for j: int in n:
			var j1: int = (j + 1) % n
			var pa: Vector3 = _p3(rings[k][j], a2.y)
			var pb: Vector3 = _p3(rings[k][j1], a2.y)
			var pc: Vector3 = _p3(rings[k + 1][j], b2.y)
			var pd: Vector3 = _p3(rings[k + 1][j1], b2.y)
			var hint: Vector3 = _air_hint((pa + pb + pc + pd) * 0.25, centre, n2)
			_tri(st, pa, pb, pc, hint)
			_tri(st, pb, pd, pc, hint)
			if in_band:
				band_count += 1
	# floor cap: fan from the middle of the flat floor ring
	var floor_ring: PackedVector2Array = rings[prof.size() - 1]
	var floor_y: float = prof[prof.size() - 1].y
	var mid := Vector3(centre.x, floor_y, centre.y)
	for j: int in n:
		_tri(concrete, mid, _p3(floor_ring[j], floor_y), _p3(floor_ring[(j + 1) % n], floor_y), Vector3.UP)
	# smooth normals over the shared vertices of the shell
	concrete.index()
	concrete.generate_normals()
	var mesh := ArrayMesh.new()
	concrete.commit(mesh)
	if band_count > 0:
		band.index()
		band.generate_normals()
		band.commit(mesh)
	return mesh


## Ground frame: the footprint minus the hole, a solid slab from y = 0 down to the floor level (flat shaded).
static func _deck_mesh(size_x: float, size_z: float, depth: float, rim_r: float, seg: int) -> ArrayMesh:
	var hole: PackedVector2Array = _ring(size_x, size_z, 0.0, rim_r, seg)
	var outer := PackedVector2Array([Vector2(0.0, 0.0), Vector2(size_x, 0.0), Vector2(size_x, size_z), Vector2(0.0, size_z)])
	var centre := Vector2(size_x * 0.5, size_z * 0.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_annulus(st, outer, hole, 0.0, Vector3.UP)
	_annulus(st, outer, hole, -depth, Vector3.DOWN)
	var n: int = hole.size()
	for j: int in n:
		var j1: int = (j + 1) % n
		# hole wall faces into the hole
		var a: Vector3 = _p3(hole[j], 0.0)
		var b: Vector3 = _p3(hole[j1], 0.0)
		var c: Vector3 = _p3(hole[j], -depth)
		var dd: Vector3 = _p3(hole[j1], -depth)
		var hint: Vector3 = _air_hint((a + b + c + dd) * 0.25, centre, Vector2(1.0, 0.0))
		_tri(st, a, b, c, hint)
		_tri(st, b, dd, c, hint)
	for k: int in 4:
		# outer sides face away from the middle
		var o0: Vector2 = outer[k]
		var o1: Vector2 = outer[(k + 1) % 4]
		var out2: Vector2 = Vector2((o1 - o0).y, -(o1 - o0).x).normalized()
		var out3 := Vector3(out2.x, 0.0, out2.y)
		var a2: Vector3 = _p3(o0, 0.0)
		var b2: Vector3 = _p3(o1, 0.0)
		var c2: Vector3 = _p3(o0, -depth)
		var d2: Vector3 = _p3(o1, -depth)
		_tri(st, a2, b2, c2, out3)
		_tri(st, b2, d2, c2, out3)
	st.generate_normals()
	return st.commit()


## Triangulated annulus between a convex outer loop and a convex inner loop (both counter-clockwise in x, z), at height y.
static func _annulus(st: SurfaceTool, outer: PackedVector2Array, inner: PackedVector2Array, y: float, hint: Vector3) -> void:
	var m: int = outer.size()
	var n: int = inner.size()
	var j0: int = 0
	var best: float = INF
	for j: int in n:
		var dd: float = inner[j].distance_squared_to(outer[0])
		if dd < best:
			best = dd
			j0 = j
	var i: int = 0
	var j: int = 0
	while i < m or j < n:
		var oi: Vector2 = outer[i % m]
		var oi1: Vector2 = outer[(i + 1) % m]
		var ij: Vector2 = inner[(j0 + j) % n]
		var ij1: Vector2 = inner[(j0 + j + 1) % n]
		var advance_outer: bool = true
		if i >= m:
			advance_outer = false
		elif j < n:
			advance_outer = oi1.distance_squared_to(ij) <= oi.distance_squared_to(ij1)
		if advance_outer:
			_tri(st, _p3(oi, y), _p3(oi1, y), _p3(ij, y), hint)
			i += 1
		else:
			_tri(st, _p3(oi, y), _p3(ij1, y), _p3(ij, y), hint)
			j += 1


## Adds a triangle whose SurfaceTool normal points along `hint` (degenerate triangles are skipped). Godot's
## generate_normals is the negative of the right-hand cross product, so the right-hand normal is set to point away.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, hint: Vector3) -> void:
	var nrm: Vector3 = (b - a).cross(c - a)
	if nrm.length_squared() < 1e-12:
		return
	var p1: Vector3 = b
	var p2: Vector3 = c
	if nrm.dot(hint) > 0.0:
		p1 = c
		p2 = b
	st.add_vertex(a)
	st.add_vertex(p1)
	st.add_vertex(p2)


## Direction toward the bowl's air at a point of a wall: horizontal toward the middle, scaled by the 2D profile
## normal (s, y), so a wall faces into the bowl and the arc faces up and in.
static func _air_hint(mid: Vector3, centre: Vector2, n2: Vector2) -> Vector3:
	var inward := Vector3(centre.x - mid.x, 0.0, centre.y - mid.z)
	if inward.length_squared() > 1e-9:
		inward = inward.normalized()
	else:
		inward = Vector3.ZERO
	return inward * n2.x + Vector3.UP * n2.y


static func _p3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)
