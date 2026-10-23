class_name BeachSnake
extends RefCounted
## The Beachfront snake run: a winding concrete channel sunk into the skatepark slab, built as one heightfield.
## The centre line is a chain of straight and circular pieces (exact distances, so the field is cheap to sample). Across
## the channel the floor is flat for FLOOR_HALF either side of the line, then a circular transition of radius RADIUS rises
## to the deck (y = 0). Along the line the depth eases in from 0 at both ends (the roll-in and the roll-out) to DEPTH.
## The surface is one grid mesh over `region` (world x/z) with each quad split along its flatter diagonal, so the walls
## don't saw-tooth; a rectangle can be left out (a bowl hole). Coping: a "coping" GrindRail, a RampLip and a visible pipe
## on each rim where the wall is at full height. Pure geometry, no Node state, so it is unit tested.

const DEPTH: float = 1.7
const FLOOR_HALF: float = 2.1
const RADIUS: float = 3.0
const TAPER: float = 7.0  ## metres of roll-in / roll-out at each end
const STEP: float = 0.2  ## grid spacing
const PIPE_R: float = 0.05
const LIP_MIN_DEPTH: float = 1.0  ## coping only where the wall is at least this tall
const CONCRETE := Color("b9b2a8")
const COPING := Color("5a6072")

## Pieces: {"kind": "line", "a": Vector2, "b": Vector2, "s0": float, "len": float} or
## {"kind": "arc", "c": Vector2, "r": float, "t0": float, "sweep": float (signed radians), "s0": float, "len": float}.
var pieces: Array[Dictionary] = []
var length: float = 0.0


## A path starting at `start` heading `heading_deg` (0 = +X, 90 = +Z) through `segs`: ["L", metres] or
## ["A", radius, turn_deg] (positive turns toward +Z from +X, i.e. clockwise seen from above).
static func make(start: Vector2, heading_deg: float, segs: Array) -> BeachSnake:
	var sn := BeachSnake.new()
	var p: Vector2 = start
	var h: float = deg_to_rad(heading_deg)
	for sg: Array in segs:
		if str(sg[0]) == "L":
			var l: float = float(sg[1])
			var b: Vector2 = p + Vector2(cos(h), sin(h)) * l
			sn.pieces.append({"kind": "line", "a": p, "b": b, "s0": sn.length, "len": l})
			sn.length += l
			p = b
		else:
			var r: float = float(sg[1])
			var turn: float = deg_to_rad(float(sg[2]))
			var side: float = signf(turn)
			# the centre sits to the side the path turns toward
			var n: Vector2 = Vector2(-sin(h), cos(h)) * side
			var c: Vector2 = p + n * r
			var t0: float = (p - c).angle()
			sn.pieces.append({"kind": "arc", "c": c, "r": r, "t0": t0, "sweep": turn, "s0": sn.length, "len": r * absf(turn)})
			sn.length += r * absf(turn)
			h += turn
			p = c + Vector2(cos(t0 + turn), sin(t0 + turn)) * r
	return sn


## Point and unit tangent on the centre line at arc length s (clamped).
func at(s: float) -> Array:
	var ss: float = clampf(s, 0.0, length)
	for pc: Dictionary in pieces:
		if ss <= float(pc["s0"]) + float(pc["len"]) + 0.0001 or pc == pieces[pieces.size() - 1]:
			var u: float = clampf((ss - float(pc["s0"])) / maxf(float(pc["len"]), 0.0001), 0.0, 1.0)
			if str(pc["kind"]) == "line":
				var a: Vector2 = pc["a"]
				var b: Vector2 = pc["b"]
				return [a.lerp(b, u), (b - a).normalized()]
			var sw: float = float(pc["sweep"])
			var t: float = float(pc["t0"]) + sw * u
			var c: Vector2 = pc["c"]
			var r: float = float(pc["r"])
			var tan: Vector2 = Vector2(-sin(t), cos(t)) * signf(sw)
			return [c + Vector2(cos(t), sin(t)) * r, tan]
	return [Vector2.ZERO, Vector2.RIGHT]


## Distance from p to the centre line and the arc length of the closest point: Vector2(d, s).
func closest(p: Vector2) -> Vector2:
	var best: Vector2 = Vector2(INF, 0.0)
	for pc: Dictionary in pieces:
		var d: float
		var s: float
		if str(pc["kind"]) == "line":
			var a: Vector2 = pc["a"]
			var b: Vector2 = pc["b"]
			var ab: Vector2 = b - a
			var u: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
			d = p.distance_to(a + ab * u)
			s = float(pc["s0"]) + u * float(pc["len"])
		else:
			var c: Vector2 = pc["c"]
			var r: float = float(pc["r"])
			var sw: float = float(pc["sweep"])
			var t0: float = float(pc["t0"])
			var rel: float = angle_difference(t0, (p - c).angle())  # signed angle from t0
			var u: float = clampf(rel / sw, 0.0, 1.0) if absf(sw) > 0.0001 else 0.0
			var t: float = t0 + sw * u
			d = p.distance_to(c + Vector2(cos(t), sin(t)) * r)
			s = float(pc["s0"]) + u * float(pc["len"])
		if d < best.x:
			best = Vector2(d, s)
	return best


## Channel depth (below the deck) at arc length s: eased in over TAPER at both ends.
func depth_at(s: float) -> float:
	var k: float = minf(clampf(s / TAPER, 0.0, 1.0), clampf((length - s) / TAPER, 0.0, 1.0))
	return DEPTH * k * k * (3.0 - 2.0 * k)


## How far the transition reaches from the floor edge to the deck for a depth d.
static func reach(d: float) -> float:
	var r: float = RADIUS
	var dd: float = clampf(d, 0.0, r)
	return sqrt(maxf(r * r - (r - dd) * (r - dd), 0.0))


## Height of the transition profile: `u` metres out from the floor edge, for depth d (0 = the deck).
static func profile(u: float, d: float) -> float:
	if d <= 0.0001:
		return 0.0
	if u <= 0.0:
		return -d
	if u >= reach(d):
		return 0.0
	return -d + RADIUS - sqrt(RADIUS * RADIUS - u * u)


## Surface height at world (x, z).
func height(x: float, z: float) -> float:
	var ds: Vector2 = closest(Vector2(x, z))
	return profile(ds.x - FLOOR_HALF, depth_at(ds.y))


## Rim offset from the centre line at arc length s.
func rim_at(s: float) -> float:
	return FLOOR_HALF + reach(depth_at(s))


## The world rect the channel (with `margin` of deck) covers, snapped out to the grid.
func footprint(margin: float = 1.0) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var n: int = int(ceil(length / 0.5))
	for i: int in n + 1:
		var s: float = length * float(i) / float(n)
		var pt: Array = at(s)
		var c: Vector2 = pt[0]
		var e: float = rim_at(s) + margin
		lo = Vector2(minf(lo.x, c.x - e), minf(lo.y, c.y - e))
		hi = Vector2(maxf(hi.x, c.x + e), maxf(hi.y, c.y + e))
	lo = (lo / STEP).floor() * STEP
	hi = (hi / STEP).ceil() * STEP
	return Rect2(lo, hi - lo)


## The surface as one StaticBody3D ("SnakeRun": mesh + trimesh) over `region`, leaving out `holes` (world rects).
func build_body(region: Rect2, holes: Array[Rect2] = []) -> StaticBody3D:
	var nx: int = int(round(region.size.x / STEP))
	var nz: int = int(round(region.size.y / STEP))
	var hs := PackedFloat32Array()
	hs.resize((nx + 1) * (nz + 1))
	for j: int in nz + 1:
		for i: int in nx + 1:
			hs[j * (nx + 1) + i] = height(region.position.x + float(i) * STEP, region.position.y + float(j) * STEP)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var remap := PackedInt32Array()
	remap.resize((nx + 1) * (nz + 1))
	remap.fill(-1)
	for j: int in nz:
		for i: int in nx:
			var cx: float = region.position.x + (float(i) + 0.5) * STEP
			var cz: float = region.position.y + (float(j) + 0.5) * STEP
			var skip: bool = false
			for h: Rect2 in holes:
				if h.has_point(Vector2(cx, cz)):
					skip = true
			if skip:
				continue
			var k00: int = j * (nx + 1) + i
			var k10: int = k00 + 1
			var k01: int = k00 + nx + 1
			var k11: int = k01 + 1
			var ids: Array[int] = []
			for k: int in [k00, k10, k01, k11]:
				if remap[k] < 0:
					remap[k] = verts.size()
					var gi: int = k % (nx + 1)
					var gj: int = k / (nx + 1)
					verts.append(Vector3(region.position.x + float(gi) * STEP, hs[k], region.position.y + float(gj) * STEP))
					norms.append(_normal(hs, gi, gj, nx, nz))
				ids.append(remap[k])
			# split along the diagonal whose ends are closer in height (follows the contours)
			if absf(hs[k00] - hs[k11]) <= absf(hs[k10] - hs[k01]):
				idx.append_array([ids[0], ids[1], ids[3], ids[0], ids[3], ids[2]])
			else:
				idx.append_array([ids[0], ids[1], ids[2], ids[1], ids[3], ids[2]])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sb := StaticBody3D.new()
	sb.name = "SnakeRun"
	sb.collision_layer = 1
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var faces := PackedVector3Array()
	for t: int in idx.size():
		faces.append(verts[idx[t]])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	cs.shape = shape
	sb.add_child(cs)
	return sb


## Smooth normal from the height grid (central differences).
static func _normal(hs: PackedFloat32Array, i: int, j: int, nx: int, nz: int) -> Vector3:
	var w: int = nx + 1
	var i0: int = maxi(i - 1, 0)
	var i1: int = mini(i + 1, nx)
	var j0: int = maxi(j - 1, 0)
	var j1: int = mini(j + 1, nz)
	var dx: float = (hs[j * w + i1] - hs[j * w + i0]) / (float(i1 - i0) * STEP)
	var dz: float = (hs[j1 * w + i] - hs[j0 * w + i]) / (float(j1 - j0) * STEP)
	return Vector3(-dx, 1.0, -dz).normalized()


## The two rim polylines (y = 0) where the wall is at least LIP_MIN_DEPTH deep: [left, right], each a
## PackedVector3Array running with the path, plus the matching inward directions [left_in, right_in].
func rims() -> Array:
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var lin := PackedVector3Array()
	var rin := PackedVector3Array()
	var n: int = int(ceil(length / 0.5))
	for i: int in n + 1:
		var s: float = length * float(i) / float(n)
		if depth_at(s) < LIP_MIN_DEPTH:
			continue
		var pt: Array = at(s)
		var c: Vector2 = pt[0]
		var t: Vector2 = pt[1]
		var nrm := Vector2(-t.y, t.x)  # to the left of travel
		var r: float = rim_at(s)
		var lp: Vector2 = c + nrm * r
		var rp: Vector2 = c - nrm * r
		left.append(Vector3(lp.x, 0.0, lp.y))
		right.append(Vector3(rp.x, 0.0, rp.y))
		lin.append(Vector3(-nrm.x, 0.0, -nrm.y))
		rin.append(Vector3(nrm.x, 0.0, nrm.y))
	return [left, right, lin, rin]


## The whole snake run: surface, coping rails and lips, coping pipes and the two gap zones ("snake_in" over the
## roll-in, "snake_out" over the roll-out). World space (add it under a node at the origin).
func build(region: Rect2, holes: Array[Rect2] = []) -> Node3D:
	var root := Node3D.new()
	root.name = "SnakeRun"
	var body: StaticBody3D = build_body(region, holes)
	(body.get_node("Mesh") as MeshInstance3D).material_override = Toon.material(CONCRETE, false)
	root.add_child(body)
	var rr: Array = rims()
	for side: int in 2:
		var pts: PackedVector3Array = rr[side]
		if pts.size() < 2:
			continue
		var dirs: PackedVector3Array = rr[side + 2]
		var nm: String = "Left" if side == 0 else "Right"
		root.add_child(PieceKit.rail(pts, "coping", "Coping" + nm))
		var lip_dirs := PackedVector3Array()
		for k: int in pts.size() - 1:
			lip_dirs.append((dirs[k] + dirs[k + 1]).normalized())
		root.add_child(RampLip.make(pts, lip_dirs, "drop_in", "Lip" + nm))
		root.add_child(tube(pts, dirs, PIPE_R, COPING, "Pipe" + nm))
	var a: Array = at(TAPER * 0.6)
	var b: Array = at(length - TAPER * 0.6)
	for z: Array in [["snake_in", a], ["snake_out", b]]:
		var c: Vector2 = (z[1] as Array)[0]
		var w: float = FLOOR_HALF * 2.0 + 2.0
		root.add_child(PieceKit.gap_zone(str(z[0]), Vector3(c.x - w * 0.5, -1.2, c.y - w * 0.5), Vector3(w, 3.0, w)))
	return root


## A round pipe along a polyline (visual only), pushed `out` of the rim along -inward so it sits on the lip.
static func tube(pts: PackedVector3Array, inward: PackedVector3Array, r: float, colour: Color, node_name: String) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 6
	var rings: Array[PackedVector3Array] = []
	var rnorm: Array[PackedVector3Array] = []
	for k: int in pts.size():
		var t: Vector3 = (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var side: Vector3 = t.cross(Vector3.UP).normalized()
		var c: Vector3 = pts[k] - inward[k] * 0.01 + Vector3(0.0, -0.005, 0.0)
		var ring := PackedVector3Array()
		var rn := PackedVector3Array()
		for q: int in sides:
			var a: float = TAU * float(q) / float(sides)
			var n: Vector3 = side * cos(a) + Vector3.UP * sin(a)
			ring.append(c + n * r)
			rn.append(n)
		rings.append(ring)
		rnorm.append(rn)
	for k: int in pts.size() - 1:
		for q: int in sides:
			var q1: int = (q + 1) % sides
			var v: Array[Vector3] = [rings[k][q], rings[k + 1][q], rings[k + 1][q1], rings[k][q1]]
			var n: Array[Vector3] = [rnorm[k][q], rnorm[k + 1][q], rnorm[k + 1][q1], rnorm[k][q1]]
			for e: int in [0, 2, 1, 0, 3, 2]:
				st.set_normal(n[e])
				st.add_vertex(v[e])
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = Toon.material(colour, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
