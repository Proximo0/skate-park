class_name HillsRoad
extends RefCounted
## One street of The Hills: a smooth centre line (Catmull-Rom through control points, resampled every STEP metres)
## with a height profile, a carriageway of half-width `half` and a raised sidewalk `walk` wide on each side. Builds the
## asphalt ribbon, the painted lines, the sidewalks (collision + a grindable curb along the road edge), and gives the
## lanes for traffic and the sidewalk paths for pedestrians. Heights come from the HillsTerrain, so the ribbons lie on
## exactly what the skater rides.

const STEP: float = 1.0
const CURB_H: float = 0.1  ## sidewalk height above the road (rolled over: under Skater.EDGE_STEP_HEIGHT)
const SKIRT: float = 0.35  ## how far the sidewalk's faces reach down into the ground
const ROAD_LIFT: float = 0.025
const LINE_LIFT: float = 0.035

var road_name: String = ""
var pts: PackedVector3Array = PackedVector3Array()  ## centre line, y = road height
var cum: PackedFloat32Array = PackedFloat32Array()
var half: float = 4.0
var walk: float = 2.0
var length: float = 0.0
var box: Rect2 = Rect2()  ## the centre line's x/z bounds
## Sidewalks: false to leave a side out ([left, right] of travel).
var sides: Array[bool] = [true, true]
## Arc-length ranges [a, b] with no sidewalk on a side (driveways, crossings): [side, a, b].
var cuts: Array = []


## A road through `ctrl` (x, z control points; the line passes through every one).
static func through(nm: String, ctrl: PackedVector2Array, half_w: float = 4.0, walk_w: float = 2.0) -> HillsRoad:
	var r := HillsRoad.new()
	r.road_name = nm
	r.half = half_w
	r.walk = walk_w
	var dense := PackedVector2Array()
	var n: int = ctrl.size()
	for k: int in n - 1:
		var p0: Vector2 = ctrl[maxi(k - 1, 0)]
		var p1: Vector2 = ctrl[k]
		var p2: Vector2 = ctrl[k + 1]
		var p3: Vector2 = ctrl[mini(k + 2, n - 1)]
		if k == 0:
			p0 = p1 * 2.0 - p2
		if k + 2 > n - 1:
			p3 = p2 * 2.0 - p1
		var seg: int = maxi(int(p1.distance_to(p2) / 0.25), 4)
		for q: int in seg:
			dense.append(HillsRoad._cr(p0, p1, p2, p3, float(q) / float(seg)))
	dense.append(ctrl[n - 1])
	# resample by arc length
	var acc: float = 0.0
	var next: float = 0.0
	r.pts.append(Vector3(dense[0].x, 0.0, dense[0].y))
	next = STEP
	for k: int in range(1, dense.size()):
		var a: Vector2 = dense[k - 1]
		var b: Vector2 = dense[k]
		var l: float = a.distance_to(b)
		while acc + l >= next:
			var p: Vector2 = a.lerp(b, (next - acc) / maxf(l, 1e-6))
			r.pts.append(Vector3(p.x, 0.0, p.y))
			next += STEP
		acc += l
	var last: Vector2 = dense[dense.size() - 1]
	if Vector2(r.pts[r.pts.size() - 1].x, r.pts[r.pts.size() - 1].z).distance_to(last) > 0.3:
		r.pts.append(Vector3(last.x, 0.0, last.y))
	r._measure()
	return r


static func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _measure() -> void:
	cum.resize(pts.size())
	cum[0] = 0.0
	for i: int in range(1, pts.size()):
		cum[i] = cum[i - 1] + Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
	length = cum[cum.size() - 1]
	box = Rect2(pts[0].x, pts[0].z, 0.0, 0.0)
	for p: Vector3 in pts:
		box = box.expand(Vector2(p.x, p.z))


## Heights: the natural hillside under the line, smoothed over about `window` metres; then pinned to `h0` at the start
## and `h1` at the end (NAN = free), easing over `ease` metres.
func profile_from_natural(window: float, h0: float = NAN, h1: float = NAN, ease: float = 30.0) -> void:
	var n: int = pts.size()
	var y := PackedFloat32Array()
	y.resize(n)
	for i: int in n:
		y[i] = HillsTerrain.natural(pts[i].x, pts[i].z)
	var half_w: int = maxi(int(window / STEP * 0.5), 1)
	for _pass: int in 3:
		var out := PackedFloat32Array()
		out.resize(n)
		for i: int in n:
			var acc: float = 0.0
			var cnt: int = 0
			for k: int in range(i - half_w, i + half_w + 1):
				acc += y[clampi(k, 0, n - 1)]
				cnt += 1
			out[i] = acc / float(cnt)
		y = out
	var d0: float = 0.0 if is_nan(h0) else h0 - y[0]
	var d1: float = 0.0 if is_nan(h1) else h1 - y[n - 1]
	for i: int in n:
		var s: float = cum[i]
		var w0: float = 1.0 - smoothstep(0.0, ease, s)
		var w1: float = 1.0 - smoothstep(0.0, ease, length - s)
		pts[i].y = y[i] + d0 * w0 + d1 * w1


## Sets the profile by a function of arc length: f(s) -> height.
func profile_fn(f: Callable) -> void:
	for i: int in pts.size():
		pts[i].y = float(f.call(cum[i]))


## Lowers or raises the stretch [a, b] (arc length) to a flat `y`, easing in and out over `ease` metres.
func flatten(a: float, b: float, y: float, ease: float = 20.0) -> void:
	for i: int in pts.size():
		var s: float = cum[i]
		var w: float = 1.0
		if s < a:
			w = smoothstep(a - ease, a, s)
		elif s > b:
			w = 1.0 - smoothstep(b, b + ease, s)
		pts[i].y = lerpf(pts[i].y, y, w)


func _index(s: float) -> int:
	return clampi(cum.bsearch(s, false) - 1, 0, pts.size() - 2)


func sample(s: float) -> Vector3:
	var sc: float = clampf(s, 0.0, length)
	var i: int = _index(sc)
	var f: float = (sc - cum[i]) / maxf(cum[i + 1] - cum[i], 1e-6)
	return pts[i].lerp(pts[i + 1], clampf(f, 0.0, 1.0))


func tangent(s: float) -> Vector3:
	var a: Vector3 = sample(s - 1.0)
	var b: Vector3 = sample(s + 1.0)
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	return d.normalized() if d.length() > 1e-5 else Vector3.FORWARD


## Horizontal unit vector to the right of travel at s.
func right(s: float) -> Vector3:
	return tangent(s).cross(Vector3.UP).normalized()


## {s, d (signed: + right of travel), p} of the closest centre-line point to (x, z).
func closest(p: Vector3) -> Dictionary:
	var best: float = INF
	var bs: float = 0.0
	for i: int in pts.size() - 1:
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[i + 1].x, pts[i + 1].z)
		var ab: Vector2 = b - a
		var t: float = clampf((Vector2(p.x, p.z) - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var d: float = (a + ab * t).distance_squared_to(Vector2(p.x, p.z))
		if d < best:
			best = d
			bs = cum[i] + (cum[i + 1] - cum[i]) * t
	var c: Vector3 = sample(bs)
	var sd: float = (p - c).dot(right(bs))
	return {"s": bs, "d": sd, "p": c}


## Distance from (x, z) to the centre line (horizontal).
func distance(p: Vector3) -> float:
	return absf(float(closest(p)["d"]))


## The centre line as corridor points for HillsTerrain.corridor (y = road height).
func corridor_points(step_m: float = 3.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	var s: float = 0.0
	while s < length:
		out.append(sample(s))
		s += step_m
	out.append(sample(length))
	return out


## A point at arc length s, `off` metres to the right of travel, on the terrain (+ lift).
func ground_point(t: HillsTerrain, s: float, off: float, lift: float) -> Vector3:
	var c: Vector3 = sample(s) + right(s) * off
	return t.at(c.x, c.z, lift)


# --- meshes --------------------------------------------------------------------------------------------------------

## A ribbon from offset o0 to o1 (right of travel) over [s0, s1], on the terrain + lift. Up-facing.
func ribbon(t: HillsTerrain, s0: float, s1: float, o0: float, o1: float, lift: float, step_m: float = STEP) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = maxi(int(ceil((s1 - s0) / step_m)), 1)
	var prev_a: Vector3
	var prev_b: Vector3
	for k: int in n + 1:
		var s: float = lerpf(s0, s1, float(k) / float(n))
		var a: Vector3 = ground_point(t, s, o0, lift)
		var b: Vector3 = ground_point(t, s, o1, lift)
		if k > 0:
			HillsRoad.quad_up(st, prev_a, prev_b, b, a)
		prev_a = a
		prev_b = b
	st.generate_normals()
	return st.commit()


## Adds quad a-b-c-d with its front face up (a, b at the start, c, d at the end of a strip).
static func quad_up(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	HillsRoad.tri_facing(st, a, b, c, Vector3.UP)
	HillsRoad.tri_facing(st, a, c, d, Vector3.UP)


## Adds triangle a, b, c with its front face toward `toward` (Godot's front face is clockwise seen from the front).
static func tri_facing(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, toward: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	if n.dot(toward) > 0.0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)


## The arc-length runs [a, b] of a side's sidewalk that are not cut and not inside another road's carriageway.
func walk_runs(side: int, others: Array, extra_cuts: Array = []) -> Array[Vector2]:
	var runs: Array[Vector2] = []
	if not sides[0 if side < 0 else 1]:
		return runs
	var off: float = float(side) * (half + walk * 0.5)
	var s: float = 0.0
	var start: float = -1.0
	var last_ok: float = -1.0
	while s <= length:
		var ok: bool = true
		for c: Array in cuts + extra_cuts:
			if int(c[0]) == side and s >= float(c[1]) and s <= float(c[2]):
				ok = false
				break
		if ok:
			var p: Vector3 = sample(s) + right(s) * off
			for o: Variant in others:
				var road: HillsRoad = o as HillsRoad
				if road == self or not road.box.grow(road.half + walk + 1.0).has_point(Vector2(p.x, p.z)):
					continue
				if road.distance(p) < road.half + walk + 0.6:
					ok = false
					break
		if ok and start < 0.0:
			start = s
		if ok:
			last_ok = s
		if (not ok or s + STEP > length) and start >= 0.0:
			if last_ok - start >= 2.0:
				runs.append(Vector2(start, last_ok))
			start = -1.0
		s += STEP
	return runs


## The sidewalk slab of one run on `side` (-1 left, +1 right): a top CURB_H above the road, the curb face along the
## road edge and the outer face, both running SKIRT down into the ground. Returns [mesh, faces for collision].
func sidewalk_mesh(t: HillsTerrain, side: int, run: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var o_in: float = float(side) * half
	var o_out: float = float(side) * (half + walk)
	var n: int = maxi(int(ceil((run.y - run.x) / STEP)), 1)
	var pi_top: Vector3
	var po_top: Vector3
	var pi_bot: Vector3
	var po_bot: Vector3
	for k: int in n + 1:
		var s: float = lerpf(run.x, run.y, float(k) / float(n))
		var r: Vector3 = right(s) * float(side)
		var ci: Vector3 = ground_point(t, s, o_in, 0.0)
		var co: Vector3 = ground_point(t, s, o_out, 0.0)
		var top_y: float = sample(s).y + CURB_H
		var i_top := Vector3(ci.x, maxf(top_y, ci.y + 0.02), ci.z)
		var o_top := Vector3(co.x, maxf(top_y, co.y + 0.02), co.z)
		var i_bot := Vector3(ci.x, ci.y - SKIRT, ci.z)
		var o_bot := Vector3(co.x, co.y - SKIRT, co.z)
		if k == 0 or k == n:
			# end caps
			var along: Vector3 = tangent(s) * (-1.0 if k == 0 else 1.0)
			HillsRoad.tri_facing(st, i_top, o_top, o_bot, along)
			HillsRoad.tri_facing(st, i_top, o_bot, i_bot, along)
		if k > 0:
			HillsRoad.quad_up(st, pi_top, po_top, o_top, i_top)
			HillsRoad.tri_facing(st, pi_top, i_top, i_bot, -r)
			HillsRoad.tri_facing(st, pi_top, i_bot, pi_bot, -r)
			HillsRoad.tri_facing(st, po_top, o_top, o_bot, r)
			HillsRoad.tri_facing(st, po_top, o_bot, po_bot, r)
		pi_top = i_top
		po_top = o_top
		pi_bot = i_bot
		po_bot = o_bot
	st.generate_normals()
	return st.commit()


## The curb's grind line for a run: along the road edge at the sidewalk's top.
func curb_points(t: HillsTerrain, side: int, run: Vector2, inset: float = 0.05) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n: int = maxi(int(ceil((run.y - run.x) / 2.0)), 1)
	for k: int in n + 1:
		var s: float = lerpf(run.x, run.y, float(k) / float(n))
		var c: Vector3 = ground_point(t, s, float(side) * (half + inset), 0.0)
		out.append(Vector3(c.x, maxf(sample(s).y + CURB_H, c.y + 0.02), c.z))
	return out


## A dashed or solid painted line at offset `off` (strip `width` wide). dash/gap 0 = solid.
func paint_line(t: HillsTerrain, off: float, width: float, dash: float, gap: float, s0: float = 0.0, s1: float = -1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var end_s: float = length if s1 < 0.0 else s1
	var s: float = s0
	while s < end_s:
		var e: float = end_s if dash <= 0.0 else minf(s + dash, end_s)
		var n: int = maxi(int(ceil((e - s) / 2.0)), 1)
		var pa: Vector3
		var pb: Vector3
		for k: int in n + 1:
			var ss: float = lerpf(s, e, float(k) / float(n))
			var a: Vector3 = ground_point(t, ss, off - width * 0.5, LINE_LIFT)
			var b: Vector3 = ground_point(t, ss, off + width * 0.5, LINE_LIFT)
			if k > 0:
				HillsRoad.quad_up(st, pa, pb, b, a)
			pa = a
			pb = b
		s = e + gap
		if dash <= 0.0:
			break
	st.generate_normals()
	return st.commit()


## Lane centre points for traffic (offset to the right of travel; reversed for the other direction), on the road.
func lane_points(t: HillsTerrain, off: float, s0: float = 0.0, s1: float = -1.0, step_m: float = 4.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	var e: float = length if s1 < 0.0 else s1
	var s: float = s0
	while s <= e:
		out.append(ground_point(t, s, off, 0.0))
		s += step_m
	return out


## Points along the middle of a sidewalk (side -1 / +1) on its top, for walkers.
func walk_points(t: HillsTerrain, side: int, s0: float, s1: float, step_m: float = 3.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	var s: float = s0
	while s <= s1:
		var c: Vector3 = ground_point(t, s, float(side) * (half + walk * 0.5), 0.0)
		out.append(Vector3(c.x, maxf(sample(s).y + CURB_H, c.y), c.z))
		s += step_m
	return out
