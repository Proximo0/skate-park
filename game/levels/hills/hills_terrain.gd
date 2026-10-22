class_name HillsTerrain
extends RefCounted
## The Hills' ground: one smooth height field over a tensor grid (1 m cells over the riding area, 4 m cells out along
## the through roads, then cells growing geometrically out to the mountains), shaped in layers: a natural hillside
## (natural()), then flattening ops for pads, terraces, cul-de-sacs, the water channel and the roads, applied in order
## (a later op wins inside its core and blends out over its margin, so the field always stays continuous). Holes are
## whole cells left out (the pools and the channel bring their own floors and meet the grid edge exactly).
##
## height_at() interpolates the SAME triangles the meshes and the collision use, so anything laid on the ground (road
## ribbons, sidewalks, houses) sits exactly on what the skater rides. Collision covers the riding area only, in tiles.

const CORE_HALF: float = 124.0  ## 1 m cells for |x|, |z| <= CORE_HALF
const MID_HALF_X: float = 344.0  ## 4 m cells in x out to here (the through roads run on)
const MID_CELL: float = 4.0
const FAR: float = 3400.0
const FAR_GROWTH: float = 1.16
const TILE: float = 16.0  ## collision tile size (m)

## Height of the natural hillside along z (north is -Z, uphill): knots (z, y), monotone cubic between them.
const PROFILE: Array = [
	[-3400.0, 420.0], [-2300.0, 360.0], [-1300.0, 150.0], [-600.0, 80.0], [-260.0, 54.0], [-110.0, 33.0],
	[0.0, 18.5], [110.0, 4.2], [150.0, -3.0], [215.0, -34.0], [300.0, -50.0], [700.0, -54.0], [1150.0, -53.0],
	[1500.0, -20.0], [1900.0, 150.0], [2500.0, 330.0], [3400.0, 360.0],
]

var xs: PackedFloat32Array = PackedFloat32Array()
var zs: PackedFloat32Array = PackedFloat32Array()
var nx: int = 0
var nz: int = 0
var h: PackedFloat32Array = PackedFloat32Array()
var hole: PackedByteArray = PackedByteArray()  ## per cell (i + j * (nx - 1)): 1 = left out
var _cx0: int = 0  ## column index of x = -CORE_HALF
var _cz0: int = 0
static var _noise: FastNoiseLite = null
static var _pz: PackedFloat32Array = PackedFloat32Array()
static var _py: PackedFloat32Array = PackedFloat32Array()
static var _pm: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	xs = HillsTerrain._axis(MID_HALF_X)
	zs = HillsTerrain._axis(CORE_HALF)
	nx = xs.size()
	nz = zs.size()
	_cx0 = xs.find(-CORE_HALF)
	_cz0 = zs.find(-CORE_HALF)
	h.resize(nx * nz)
	for j: int in nz:
		for i: int in nx:
			h[i + j * nx] = HillsTerrain.natural(xs[i], zs[j])
	hole.resize((nx - 1) * (nz - 1))
	hole.fill(0)


## Grid lines: 1 m inside the core, MID_CELL out to `mid`, then growing cells to FAR (symmetric about 0).
static func _axis(mid: float) -> PackedFloat32Array:
	var pos: Array[float] = []
	var v: float = 0.0
	while v < CORE_HALF - 0.001:
		v += 1.0
		pos.append(v)
	while v < mid - 0.001:
		v += MID_CELL
		pos.append(v)
	var step: float = MID_CELL
	while v < FAR:
		step *= FAR_GROWTH
		v += step
		pos.append(v)
	var out := PackedFloat32Array()
	for k: int in range(pos.size() - 1, -1, -1):
		out.append(-pos[k])
	out.append(0.0)
	for p: float in pos:
		out.append(p)
	return out


# --- the natural hillside ------------------------------------------------------------------------------------------

static func _profile_setup() -> void:
	if not _pz.is_empty():
		return
	for k: Array in PROFILE:
		_pz.append(float(k[0]))
		_py.append(float(k[1]))
	var n: int = _pz.size()
	var d := PackedFloat32Array()
	for i: int in n - 1:
		d.append((_py[i + 1] - _py[i]) / (_pz[i + 1] - _pz[i]))
	_pm.resize(n)
	_pm[0] = d[0]
	_pm[n - 1] = d[n - 2]
	for i: int in range(1, n - 1):
		_pm[i] = 0.0 if d[i - 1] * d[i] <= 0.0 else (d[i - 1] + d[i]) * 0.5
	for i: int in n - 1:  # Fritsch-Carlson: no overshoot between knots
		if absf(d[i]) < 1e-6:
			_pm[i] = 0.0
			_pm[i + 1] = 0.0
			continue
		var a: float = _pm[i] / d[i]
		var b: float = _pm[i + 1] / d[i]
		var s: float = a * a + b * b
		if s > 9.0:
			var t: float = 3.0 / sqrt(s)
			_pm[i] = t * a * d[i]
			_pm[i + 1] = t * b * d[i]
	_noise = FastNoiseLite.new()
	_noise.seed = 7
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0035
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4


## Hillside height along z alone (the monotone cubic through PROFILE).
static func base_z(z: float) -> float:
	_profile_setup()
	var n: int = _pz.size()
	if z <= _pz[0]:
		return _py[0]
	if z >= _pz[n - 1]:
		return _py[n - 1]
	var i: int = clampi(_pz.bsearch(z) - 1, 0, n - 2)
	var hh: float = _pz[i + 1] - _pz[i]
	var t: float = (z - _pz[i]) / hh
	var t2: float = t * t
	var t3: float = t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * _py[i] + (t3 - 2.0 * t2 + t) * hh * _pm[i] \
		+ (-2.0 * t3 + 3.0 * t2) * _py[i + 1] + (t3 - t2) * hh * _pm[i + 1]


## The untouched hillside at (x, z): the profile, gentle rolls in the suburb, then hills to either side of the valley
## and ridged mountains far away.
static func natural(x: float, z: float) -> float:
	var y: float = HillsTerrain.base_z(z)
	var r: float = Vector2(x, z).length()
	# gentle rolls in the neighbourhood (small, so the streets stay rideable)
	y += 1.1 * sin(x / 23.0 + 0.7) * cos(z / 29.0) + 0.6 * sin((x - z) / 17.0)
	# the valley sides: hills rise to the east and west once past the suburb
	var side: float = smoothstep(150.0, 900.0, absf(x))
	y += side * (60.0 + 90.0 * smoothstep(0.0, 1500.0, absf(x) - 900.0)) * (1.0 - 0.5 * smoothstep(200.0, 1200.0, z))
	# ridges and knolls, growing with distance
	var amp: float = 4.0 * smoothstep(140.0, 400.0, r) + 70.0 * smoothstep(900.0, 2600.0, r)
	if amp > 0.0:
		y += amp * (_noise.get_noise_2d(x, z) * 0.9 + 0.25)
	return y


# --- shaping ops ---------------------------------------------------------------------------------------------------

## Column range [i0, i1] of the vertices with x in [a, b].
func _cols(a: float, b: float) -> Vector2i:
	return Vector2i(clampi(xs.bsearch(a), 0, nx - 1), clampi(xs.bsearch(b, false) - 1, 0, nx - 1))


func _rows(a: float, b: float) -> Vector2i:
	return Vector2i(clampi(zs.bsearch(a), 0, nz - 1), clampi(zs.bsearch(b, false) - 1, 0, nz - 1))


static func _w(d: float, core: float, margin: float) -> float:
	if d <= core:
		return 1.0
	if margin <= 0.0:
		return 0.0
	return 1.0 - smoothstep(core, core + margin, d)


## A corridor along a polyline whose points carry their target height in y: inside `core` (m from the line) the ground
## takes the line's height, then blends back over `margin`.
func corridor(pts: PackedVector3Array, core: float, margin: float) -> void:
	var reach: float = core + margin
	var best: Dictionary = {}  # vertex index -> Vector2(distance, target)
	for k: int in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var ci: Vector2i = _cols(minf(a.x, b.x) - reach, maxf(a.x, b.x) + reach)
		var rj: Vector2i = _rows(minf(a.z, b.z) - reach, maxf(a.z, b.z) + reach)
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var l2: float = maxf(ab.length_squared(), 1e-9)
		for j: int in range(rj.x, rj.y + 1):
			var z: float = zs[j]
			for i: int in range(ci.x, ci.y + 1):
				var x: float = xs[i]
				var t: float = clampf(((x - a.x) * ab.x + (z - a.z) * ab.y) / l2, 0.0, 1.0)
				var dx: float = x - (a.x + ab.x * t)
				var dz: float = z - (a.z + ab.y * t)
				var d: float = sqrt(dx * dx + dz * dz)
				if d > reach:
					continue
				var idx: int = i + j * nx
				var cur: Variant = best.get(idx)
				if cur == null or d < (cur as Vector2).x:
					best[idx] = Vector2(d, lerpf(a.y, b.y, t))
	for idx: int in best:
		var v: Vector2 = best[idx]
		h[idx] = lerpf(h[idx], v.y, HillsTerrain._w(v.x, core, margin))


## A flat rectangle (axis-aligned, world x/z) at height `y`, blending out over per-side margins (west, east, north,
## south); a margin of 0 is a hard edge (the next grid line keeps its height: put a retaining wall there).
func flat_rect(r: Rect2, y: float, margins: Vector4 = Vector4(4, 4, 4, 4)) -> void:
	var m: float = maxf(maxf(margins.x, margins.y), maxf(margins.z, margins.w))
	var ci: Vector2i = _cols(r.position.x - m, r.end.x + m)
	var rj: Vector2i = _rows(r.position.y - m, r.end.y + m)
	for j: int in range(rj.x, rj.y + 1):
		var z: float = zs[j]
		var ez: float = 0.0
		if z < r.position.y - 0.001:
			ez = (r.position.y - z) / maxf(margins.z, 0.0001)
		elif z > r.end.y + 0.001:
			ez = (z - r.end.y) / maxf(margins.w, 0.0001)
		for i: int in range(ci.x, ci.y + 1):
			var x: float = xs[i]
			var ex: float = 0.0
			if x < r.position.x - 0.001:
				ex = (r.position.x - x) / maxf(margins.x, 0.0001)
			elif x > r.end.x + 0.001:
				ex = (x - r.end.x) / maxf(margins.y, 0.0001)
			var e: float = sqrt(ex * ex + ez * ez)
			if e >= 1.0:
				continue
			var idx: int = i + j * nx
			h[idx] = lerpf(h[idx], y, 1.0 - smoothstep(0.0, 1.0, e))


## A flat rectangle turned `yaw` (radians) about its centre (a house pad facing its street).
func flat_box(centre: Vector3, half: Vector2, yaw: float, margin: float) -> void:
	var reach: float = half.length() + margin
	var ci: Vector2i = _cols(centre.x - reach, centre.x + reach)
	var rj: Vector2i = _rows(centre.z - reach, centre.z + reach)
	var c: float = cos(yaw)
	var s: float = sin(yaw)
	for j: int in range(rj.x, rj.y + 1):
		for i: int in range(ci.x, ci.y + 1):
			var dx: float = xs[i] - centre.x
			var dz: float = zs[j] - centre.z
			var lx: float = dx * c - dz * s
			var lz: float = dx * s + dz * c
			var ex: float = maxf(absf(lx) - half.x, 0.0)
			var ez: float = maxf(absf(lz) - half.y, 0.0)
			var d: float = sqrt(ex * ex + ez * ez)
			var idx: int = i + j * nx
			h[idx] = lerpf(h[idx], centre.y, HillsTerrain._w(d, 0.0, margin))


## A flat disc (a cul-de-sac bulb).
func flat_disc(centre: Vector3, radius: float, margin: float) -> void:
	var reach: float = radius + margin
	var ci: Vector2i = _cols(centre.x - reach, centre.x + reach)
	var rj: Vector2i = _rows(centre.z - reach, centre.z + reach)
	for j: int in range(rj.x, rj.y + 1):
		for i: int in range(ci.x, ci.y + 1):
			var d: float = Vector2(xs[i] - centre.x, zs[j] - centre.z).length()
			var idx: int = i + j * nx
			h[idx] = lerpf(h[idx], centre.y, HillsTerrain._w(d, radius, margin))


## Sets the vertices on a grid-aligned rectangle's outline (and inside it) to `y` exactly: the edge a piece with its
## own floor (a pool deck) meets.
func set_rect(r: Rect2, y: float) -> void:
	var ci: Vector2i = _cols(r.position.x, r.end.x)
	var rj: Vector2i = _rows(r.position.y, r.end.y)
	for j: int in range(rj.x, rj.y + 1):
		for i: int in range(ci.x, ci.y + 1):
			h[i + j * nx] = y


## Leaves out every cell inside the grid-aligned rectangle `r`.
func cut_hole(r: Rect2) -> void:
	var ci: Vector2i = _cols(r.position.x, r.end.x)
	var rj: Vector2i = _rows(r.position.y, r.end.y)
	for j: int in range(rj.x, rj.y):
		for i: int in range(ci.x, ci.y):
			hole[i + j * (nx - 1)] = 1


## Sets the vertex nearest to (x, z) on a column line to y (used to pin edges to a piece's exact heights).
func set_vertex(x: float, z: float, y: float) -> void:
	var i: int = clampi(xs.bsearch(x - 0.001), 0, nx - 1)
	var j: int = clampi(zs.bsearch(z - 0.001), 0, nz - 1)
	h[i + j * nx] = y


# --- queries -------------------------------------------------------------------------------------------------------

## Ground height at (x, z) on the triangles the meshes and collision use.
func height_at(x: float, z: float) -> float:
	var i: int = clampi(xs.bsearch(x, false) - 1, 0, nx - 2)
	var j: int = clampi(zs.bsearch(z, false) - 1, 0, nz - 2)
	var u: float = clampf((x - xs[i]) / (xs[i + 1] - xs[i]), 0.0, 1.0)
	var v: float = clampf((z - zs[j]) / (zs[j + 1] - zs[j]), 0.0, 1.0)
	var h00: float = h[i + j * nx]
	var h10: float = h[i + 1 + j * nx]
	var h01: float = h[i + (j + 1) * nx]
	var h11: float = h[i + 1 + (j + 1) * nx]
	if u >= v:
		return h00 + u * (h10 - h00) + v * (h11 - h10)
	return h00 + v * (h01 - h00) + u * (h11 - h01)


func at(x: float, z: float, lift: float = 0.0) -> Vector3:
	return Vector3(x, height_at(x, z) + lift, z)


## Surface normal at (x, z) (finite differences over 1 m).
func normal_at(x: float, z: float) -> Vector3:
	var hx: float = height_at(x + 0.5, z) - height_at(x - 0.5, z)
	var hz: float = height_at(x, z + 0.5) - height_at(x, z - 0.5)
	return Vector3(-hx, 1.0, -hz).normalized()


func _vn(i: int, j: int) -> Vector3:
	var i0: int = maxi(i - 1, 0)
	var i1: int = mini(i + 1, nx - 1)
	var j0: int = maxi(j - 1, 0)
	var j1: int = mini(j + 1, nz - 1)
	var hx: float = (h[i1 + j * nx] - h[i0 + j * nx]) / (xs[i1] - xs[i0])
	var hz: float = (h[i + j1 * nx] - h[i + j0 * nx]) / (zs[j1] - zs[j0])
	return Vector3(-hx, 1.0, -hz).normalized()


# --- meshes and collision ------------------------------------------------------------------------------------------

## The near ground (|x|, |z| <= CORE_HALF) as one mesh: holes left out, smooth normals. `lift` raises the mesh only.
func near_mesh() -> ArrayMesh:
	return _mesh(_cx0, _cx0 + int(CORE_HALF * 2.0), _cz0, _cz0 + int(CORE_HALF * 2.0), false, Callable())


## Everything outside the near square (to the mountains), with per-vertex colours from `colour_fn(x, y, z) -> Color`.
func far_mesh(colour_fn: Callable) -> ArrayMesh:
	return _mesh(0, nx - 1, 0, nz - 1, true, colour_fn)


func _mesh(ia: int, ib: int, ja: int, jb: int, outside: bool, colour_fn: Callable) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var map := PackedInt32Array()
	var w: int = ib - ia + 1
	map.resize(w * (jb - ja + 1))
	map.fill(-1)
	var ci0: int = _cx0
	var ci1: int = _cx0 + int(CORE_HALF * 2.0)
	var cj0: int = _cz0
	var cj1: int = _cz0 + int(CORE_HALF * 2.0)
	for j: int in range(ja, jb):
		for i: int in range(ia, ib):
			var in_core: bool = i >= ci0 and i < ci1 and j >= cj0 and j < cj1
			if in_core == outside:
				continue
			if hole[i + j * (nx - 1)] != 0:
				continue
			var c: Array[int] = []
			for q: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				var m: int = (q.x - ia) + (q.y - ja) * w
				if map[m] < 0:
					map[m] = verts.size()
					var y: float = h[q.x + q.y * nx]
					verts.append(Vector3(xs[q.x], y, zs[q.y]))
					norms.append(_vn(q.x, q.y))
					if outside:
						cols.append(colour_fn.call(xs[q.x], y, zs[q.y]) as Color)
				c.append(map[m])
			idx.append_array(PackedInt32Array([c[0], c[1], c[2], c[0], c[2], c[3]]))
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	if outside:
		arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Collision for the cells inside `area`, one ConcavePolygonShape3D per TILE x TILE block, as CollisionShape3D
## children of a new StaticBody3D (world layer 1).
func collision_body(area: Rect2) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var ci: Vector2i = _cols(area.position.x, area.end.x)
	var rj: Vector2i = _rows(area.position.y, area.end.y)
	var t: int = int(TILE)
	var n: int = 0
	for tj: int in range(rj.x, rj.y, t):
		for ti: int in range(ci.x, ci.y, t):
			var faces := PackedVector3Array()
			for j: int in range(tj, mini(tj + t, rj.y)):
				for i: int in range(ti, mini(ti + t, ci.y)):
					if hole[i + j * (nx - 1)] != 0:
						continue
					var p00 := Vector3(xs[i], h[i + j * nx], zs[j])
					var p10 := Vector3(xs[i + 1], h[i + 1 + j * nx], zs[j])
					var p11 := Vector3(xs[i + 1], h[i + 1 + (j + 1) * nx], zs[j + 1])
					var p01 := Vector3(xs[i], h[i + (j + 1) * nx], zs[j + 1])
					faces.append_array(PackedVector3Array([p00, p10, p11, p00, p11, p01]))
			if faces.is_empty():
				continue
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(faces)
			shape.backface_collision = false
			var cs := CollisionShape3D.new()
			cs.name = "Tile%d" % n
			cs.shape = shape
			body.add_child(cs)
			n += 1
	return body
