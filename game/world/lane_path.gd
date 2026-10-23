class_name LanePath
extends RefCounted
## A route for cars or walkers: a polyline in world space (open or a closed loop) with rounded corners, sampled by arc
## length. Built from a point list or a Path3D. Pure maths, no Node, unit tested (tests/unit/test_world_kit.gd).
##
## Corners are filleted with circular-ish arcs of up to `corner_radius` (limited by the neighbouring segment lengths),
## so a car following the path turns smoothly; curvature_ahead() gives the tightest turn coming up, for slowing down.

var points: PackedVector3Array = PackedVector3Array()  ## the smoothed polyline actually followed
var loop: bool = false
var length: float = 0.0
var _cum: PackedFloat32Array = PackedFloat32Array()  ## arc length at each point
var _turn: PackedFloat32Array = PackedFloat32Array()  ## |heading change| per metre at each point (1 / radius)


## `corners` are the raw corner points; `radius` rounds every corner (0 = sharp).
static func from_points(corners: PackedVector3Array, closed: bool, radius: float = 6.0) -> LanePath:
	var lp := LanePath.new()
	lp.loop = closed
	lp.points = LanePath.round_corners(corners, closed, radius)
	lp._measure()
	return lp


## From a Path3D's baked points (already smooth; `radius` rounds any remaining hard corners).
static func from_path3d(path: Path3D, closed: bool, radius: float = 0.0) -> LanePath:
	var pts := PackedVector3Array()
	var xf: Transform3D = path.global_transform if path.is_inside_tree() else path.transform
	for p: Vector3 in path.curve.get_baked_points():
		pts.append(xf * p)
	return from_points(pts, closed, radius)


## A rectangle loop (a city block): corners at rect's corners at height y, driven counter-clockwise seen from above
## when `ccw`, else clockwise.
static func block_loop(rect: Rect2, y: float, radius: float, ccw: bool = true) -> LanePath:
	var a := Vector3(rect.position.x, y, rect.position.y)
	var b := Vector3(rect.end.x, y, rect.position.y)
	var c := Vector3(rect.end.x, y, rect.end.y)
	var d := Vector3(rect.position.x, y, rect.end.y)
	var pts: PackedVector3Array = PackedVector3Array([a, d, c, b]) if ccw else PackedVector3Array([a, b, c, d])
	return from_points(pts, true, radius)


## A copy of this path offset sideways by `offset` metres (positive = to the right of travel), e.g. the opposite lane
## of a two-way street (offset then reverse()).
func offset(by: float) -> LanePath:
	var pts := PackedVector3Array()
	for i: int in points.size():
		var t: Vector3 = _tangent_at_index(i)
		var right: Vector3 = t.cross(Vector3.UP).normalized()
		pts.append(points[i] + right * by)
	var lp := LanePath.new()
	lp.loop = loop
	lp.points = pts
	lp._measure()
	return lp


## The same path driven the other way.
func reversed() -> LanePath:
	var pts := points.duplicate()
	pts.reverse()
	var lp := LanePath.new()
	lp.loop = loop
	lp.points = pts
	lp._measure()
	return lp


## Wraps (loop) or clamps (open) an arc length onto the path.
func wrap_s(s: float) -> float:
	if length <= 0.0:
		return 0.0
	return fposmod(s, length) if loop else clampf(s, 0.0, length)


## Position at arc length s.
func sample(s: float) -> Vector3:
	var n: int = points.size()
	if n == 0:
		return Vector3.ZERO
	if n == 1:
		return points[0]
	var w: float = wrap_s(s)
	var i: int = _segment(w)
	var j: int = (i + 1) % n
	var seg: float = _seg_len(i)
	var f: float = 0.0 if seg <= 0.0 else (w - _cum[i]) / seg
	return points[i].lerp(points[j], clampf(f, 0.0, 1.0))


## Unit travel direction at arc length s (looks `ahead` metres on for smoothness).
func tangent(s: float, ahead: float = 0.5) -> Vector3:
	var a: Vector3 = sample(s - ahead * 0.5)
	var b: Vector3 = sample(s + ahead * 0.5)
	var d: Vector3 = b - a
	if d.length() < 0.0001:
		return _tangent_at_index(_segment(wrap_s(s)))
	return d.normalized()


## The tightest curvature (1 / radius) over the next `dist` metres from s.
func curvature_ahead(s: float, dist: float) -> float:
	var best: float = 0.0
	var steps: int = maxi(int(dist / 2.0), 1)
	for k: int in steps + 1:
		var ss: float = s + dist * float(k) / float(steps)
		if not loop and ss > length:
			break
		var i: int = _segment(wrap_s(ss))
		best = maxf(best, _turn[i])
	return best


## Arc length of the point on the path nearest to `p` (coarse: nearest polyline vertex, then refined on its segments).
func closest_s(p: Vector3) -> float:
	var best_d: float = INF
	var best_s: float = 0.0
	var n: int = points.size()
	var segs: int = n if loop else n - 1
	for i: int in segs:
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % n]
		var ab: Vector3 = b - a
		var l2: float = ab.length_squared()
		var f: float = 0.0 if l2 <= 0.0 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
		var q: Vector3 = a + ab * f
		var d: float = q.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best_s = _cum[i] + sqrt(l2) * f
	return best_s


## Rounds the corners of a polyline: each interior corner is replaced by a short arc (quadratic Bezier through the
## corner, cut back by up to `radius` and at most 45 % of each neighbouring segment).
static func round_corners(pts: PackedVector3Array, closed: bool, radius: float) -> PackedVector3Array:
	var n: int = pts.size()
	if radius <= 0.0 or n < 3:
		return pts.duplicate()
	var out := PackedVector3Array()
	for i: int in n:
		var p: Vector3 = pts[i]
		var has_prev: bool = closed or i > 0
		var has_next: bool = closed or i < n - 1
		if not (has_prev and has_next):
			out.append(p)
			continue
		var a: Vector3 = pts[(i - 1 + n) % n]
		var b: Vector3 = pts[(i + 1) % n]
		var da: Vector3 = a - p
		var db: Vector3 = b - p
		var turn: float = da.normalized().angle_to(db.normalized())
		if turn > PI - 0.05:  # straight through
			out.append(p)
			continue
		var cut: float = minf(radius * tan((PI - turn) * 0.5), minf(da.length(), db.length()) * 0.45)
		var p0: Vector3 = p + da.normalized() * cut
		var p2: Vector3 = p + db.normalized() * cut
		var steps: int = clampi(int(cut * 1.2), 3, 16)
		for k: int in steps + 1:
			var t: float = float(k) / float(steps)
			out.append(p0.lerp(p, t).lerp(p.lerp(p2, t), t))
	return out


func _measure() -> void:
	var n: int = points.size()
	_cum.resize(n)
	_turn.resize(n)
	var acc: float = 0.0
	for i: int in n:
		_cum[i] = acc
		if i < n - 1 or loop:
			acc += _seg_len(i)
	length = acc
	for i: int in n:
		var has: bool = loop or (i > 0 and i < n - 1)
		if not has:
			_turn[i] = 0.0
			continue
		var a: Vector3 = points[(i - 1 + n) % n]
		var b: Vector3 = points[i]
		var c: Vector3 = points[(i + 1) % n]
		var d1: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
		var d2: Vector3 = Vector3(c.x - b.x, 0.0, c.z - b.z)
		var l: float = (d1.length() + d2.length()) * 0.5
		_turn[i] = 0.0 if l < 0.001 or d1.length() < 0.001 or d2.length() < 0.001 else d1.angle_to(d2) / l
	# spread each vertex's turn over its neighbours, so a corner reads as a curve, not a spike
	var smooth := PackedFloat32Array(_turn)
	for i: int in n:
		var m: float = _turn[i]
		for k: int in [-2, -1, 1, 2]:
			var j: int = i + k
			if loop:
				j = posmod(j, n)
			elif j < 0 or j >= n:
				continue
			m = maxf(m, _turn[j])
		smooth[i] = m
	_turn = smooth


func _seg_len(i: int) -> float:
	var n: int = points.size()
	return points[i].distance_to(points[(i + 1) % n])


## Index of the segment holding arc length w (binary search on the cumulative lengths).
func _segment(w: float) -> int:
	var n: int = points.size()
	var lo: int = 0
	var hi: int = n - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) / 2
		if _cum[mid] <= w:
			lo = mid
		else:
			hi = mid - 1
	if not loop:
		lo = mini(lo, n - 2)
	return lo


func _tangent_at_index(i: int) -> Vector3:
	var n: int = points.size()
	if n < 2:
		return Vector3.FORWARD
	var a: int = i
	var b: int = i + 1
	if b >= n:
		if loop:
			b = 0
		else:
			a = n - 2
			b = n - 1
	var d: Vector3 = points[b] - points[a]
	return d.normalized() if d.length() > 0.0001 else Vector3.FORWARD
