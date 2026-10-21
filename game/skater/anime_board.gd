class_name AnimeBoard
extends RefCounted
## A real street skateboard, built in code: a 7-ply popsicle deck (concave, kicked nose and tail, ply stripes on the
## edge, dark griptape with 8 bolt heads, a surf sunset graphic underneath), Indy-style trucks (riser pad, baseplate
## with mounting nuts, kingpin with bushings, washer and nut, pivot cup, cast hanger with the cross on its face,
## axle with speed rings and axle nuts) and lathe-turned urethane wheels with a core and a bearing in each face.
## Static builders called by PlaceholderSkater.build_board. Long along Z, nose at -Z, wheel bottoms at y = 0; the
## deck top stays at DECK_TOP_Y (0.135) over the flat middle. Notes: /tmp/lead/char_r2/board_research.md.

## The "Deck" proxy box (not drawn): the board's reference size, top at DECK_TOP_Y.
const DECK_LENGTH: float = 0.8
const DECK_WIDTH: float = 0.22
const DECK_THICK: float = 0.03
const DECK_Y: float = 0.12
const DECK_TOP_Y: float = DECK_Y + DECK_THICK * 0.5
## The drawn deck: 1 mm of grip over 7 maple plies.
const VIS_THICK: float = 0.0142
const GRIP_THICK: float = 0.001
const PLY_KEYS: Array[String] = ["ply", "ply_coral", "ply_dark", "ply_teal", "ply_dark", "ply_coral", "ply"]
## The ends start to round off (a half ellipse in plan) and kick up past this |z|.
const KICK_START: float = 0.295
## The kick bends over this distance, then runs straight at its angle to the tip.
const KICK_BEND: float = 0.042
const NOSE_ANGLE: float = 24.0
const TAIL_ANGLE: float = 21.0
## Rails sit this much higher than the centre line (concave across the width).
const CONCAVE: float = 0.006

## Truck layout (truck frame: origin on the ground under the axle, -Z toward the board's centre, so the kingpin
## faces the middle). Real Indy proportions scaled up about 1.45x in height to meet the game's deck height.
const WHEEL_R: float = 0.032
const WHEEL_W: float = 0.034
const AXLE_Y: float = WHEEL_R
const RISER_TOP: float = DECK_TOP_Y - VIS_THICK
const PLATE_TOP: float = RISER_TOP - 0.008
const PLATE_BOTTOM: float = PLATE_TOP - 0.008
const HANGER_HALF: float = 0.072
## Truck centres at z = +-TRUCK_Z (a 14" wheelbase between the inner mounting holes); wheel centres at x = +-WHEEL_X,
## so the outer wheel faces line up with the deck's rails.
const TRUCK_Z: float = 0.25
const WHEEL_X: float = HANGER_HALF + 0.021
const HANGER_DEPTH: float = 0.0115
## Kingpin direction: down and toward the board's centre, 50 degrees from the baseplate.
const KINGPIN_DIR: Vector3 = Vector3(0.0, -0.766, -0.643)
const KINGPIN_BASE: Vector3 = Vector3(0.0, PLATE_BOTTOM, -0.008)
const PIVOT_CUP: Vector3 = Vector3(0.0, PLATE_BOTTOM - 0.004, 0.03)
## Mounting holes, "new school" pattern (41 x 54 mm real, 1.2x).
const HOLE_X: float = 0.025
const HOLE_Z: float = 0.032


static func build_deck(root: Node3D, mats: Dictionary) -> void:
	# "Deck" is the board's reference box (full size, top at DECK_TOP_Y). It is not drawn: the visible deck is the
	# shaped surfaces below.
	var proxy: MeshInstance3D = SkaterParts.part(root, "Deck", SkaterParts.box(Vector3(DECK_WIDTH, DECK_THICK, DECK_LENGTH)),
			Vector3(0.0, DECK_Y, 0.0), mats, "grip")
	proxy.visible = false

	var zs: Array = _sample_zs()
	SkaterParts.part(root, "DeckGrip", _patch(_outline_rows(zs, 8), 0.0, true), Vector3.ZERO, mats, "grip")
	SkaterParts.part(root, "DeckBottom", _patch(_outline_rows(zs, 8), 0.0, false), Vector3.ZERO, mats, "deck")
	_build_edge(root, zs, mats)
	_build_graphic(root, mats)


## The side wall: a dark grip band on top, then one band per ply.
static func _build_edge(root: Node3D, zs: Array, mats: Dictionary) -> void:
	var by_key: Dictionary = {}
	var ply_t: float = (VIS_THICK - GRIP_THICK) / float(PLY_KEYS.size())
	var bands: Array = [["grip", 0.0, GRIP_THICK]]
	for i: int in PLY_KEYS.size():
		bands.append([PLY_KEYS[i], GRIP_THICK + ply_t * float(i), GRIP_THICK + ply_t * float(i + 1)])
	for band: Array in bands:
		var key: String = band[0]
		if not by_key.has(key):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			by_key[key] = st
		_edge_band(by_key[key], zs, float(band[1]), float(band[2]))
	for key: String in by_key:
		var nm: String = "DeckEdge" if key == "grip" else "DeckPly_" + key
		SkaterParts.part(root, nm, (by_key[key] as SurfaceTool).commit(), Vector3.ZERO, mats, key)


## Sunset over the sea on the bottom: teal sky, a coral sun with a yellow core sinking into a deep teal sea with
## two cream foam lines.
static func _build_graphic(root: Node3D, mats: Dictionary) -> void:
	var sun_c: Vector2 = Vector2(0.0, 0.0)
	SkaterParts.part(root, "DeckSun", _patch(_disc_rows(sun_c, 0.082, 4, 28), 0.0005, false), Vector3.ZERO, mats, "deck_alt")
	SkaterParts.part(root, "DeckSunCore", _patch(_disc_rows(sun_c, 0.056, 3, 28), 0.001, false), Vector3.ZERO, mats, "deck_sun")
	# Sky stripes across the sun's upper half (the retro sunset look).
	var stripes: Array = []
	for i: int in 3:
		var z0: float = 0.022 - 0.019 * float(i)
		var w: float = 0.0045 - 0.0012 * float(i)
		stripes.append(_band_rows(z0 - w, z0 + w, 0.09))
	SkaterParts.part(root, "DeckSunStripes", _patch_multi(stripes, 0.0015), Vector3.ZERO, mats, "deck")
	SkaterParts.part(root, "DeckSea", _patch(_sea_rows(0.0), 0.002, false), Vector3.ZERO, mats, "deck_dark")
	var foam: Array = []
	foam.append(_wave_line(0.0, 0.0045))
	foam.append(_wave_line(0.085, 0.0035))
	foam.append(_wave_line(0.16, 0.003))
	SkaterParts.part(root, "DeckFoam", _patch_multi(foam, 0.0025), Vector3.ZERO, mats, "deck_foam")


static func build_truck(board: Node3D, truck_name: String, z: float, mats: Dictionary) -> void:
	var truck: Node3D = SkaterParts.joint(board, "Truck_" + truck_name, Vector3(0.0, 0.0, z))
	var body: Node3D = SkaterParts.joint(truck, "TruckBody", Vector3.ZERO)
	if z < 0.0:
		body.rotation.y = PI  # both kingpins face the middle of the board
	var b: Dictionary = {}

	# Riser pad and baseplate, with the 4 mounting nuts and bolt ends under the plate and 4 bolt heads on the grip.
	_prism(_st(b, "riser"), _rounded_rect(0.038, 0.05, 0.008, 4), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			PLATE_TOP, RISER_TOP, 0.0)
	var plate: PackedVector2Array = _plate_outline()
	_prism(_st(b, "baseplate"), plate, Vector3.RIGHT, Vector3.BACK, Vector3.UP, PLATE_BOTTOM, PLATE_TOP, 0.0025)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var hole: Vector3 = Vector3(sx * HOLE_X, 0.0, sz * HOLE_Z)
			_cyl(_st(b, "hardware"), hole + Vector3(0.0, PLATE_BOTTOM, 0.0), hole + Vector3(0.0, PLATE_BOTTOM - 0.004, 0.0),
					0.0052, 0.0052, 6, false, true, true)
			_cyl(_st(b, "hardware"), hole + Vector3(0.0, PLATE_BOTTOM - 0.004, 0.0), hole + Vector3(0.0, PLATE_BOTTOM - 0.0065, 0.0),
					0.0024, 0.0024, 6, false, true)
			var top: float = DECK_TOP_Y + _concave(hole.x)
			_cyl(_st(b, "hardware"), hole + Vector3(0.0, top - 0.0004, 0.0), hole + Vector3(0.0, top + 0.0011, 0.0),
					0.0058, 0.0048, 8, false, true)
			_cyl(_st(b, "truck_dark"), hole + Vector3(0.0, top + 0.0009, 0.0), hole + Vector3(0.0, top + 0.0014, 0.0),
					0.0022, 0.0022, 6, false, true, true)

	# Kingpin boss (the wedge under the plate that holds the kingpin) and the pivot cup housing.
	var k: Vector3 = KINGPIN_DIR
	_cyl(_st(b, "baseplate"), Vector3(0.0, PLATE_BOTTOM + 0.002, -0.004), KINGPIN_BASE + k * 0.01, 0.017, 0.0125, 16, false, true)
	_cyl(_st(b, "baseplate"), Vector3(0.0, PLATE_BOTTOM + 0.002, 0.028), PIVOT_CUP + k * 0.006, 0.011, 0.0095, 14, false, true)
	_cyl(_st(b, "bushings"), PIVOT_CUP + k * 0.005, PIVOT_CUP + k * 0.008, 0.0075, 0.0075, 12, false, true)

	# Kingpin stack, from the boss down: bottom (boardside) bushing, the hanger's bushing seat, top (roadside)
	# bushing, cup washer, kingpin nut and the bolt's threaded end.
	var p: Callable = func(s: float) -> Vector3: return KINGPIN_BASE + k * s
	_cyl(_st(b, "hardware"), p.call(0.008), p.call(0.0105), 0.0145, 0.0145, 16, true, true)
	_cyl(_st(b, "bushings"), p.call(0.0105), p.call(0.0235), 0.0125, 0.0132, 16, true, true)
	_cyl(_st(b, "trucks"), p.call(0.0235), p.call(0.0355), 0.0165, 0.0165, 18, true, true)
	_cyl(_st(b, "bushings"), p.call(0.0355), p.call(0.0475), 0.0128, 0.0105, 16, true, true)
	_cyl(_st(b, "hardware"), p.call(0.0475), p.call(0.0505), 0.0128, 0.0128, 16, true, true)
	_cyl(_st(b, "hardware"), p.call(0.0505), p.call(0.0575), 0.0078, 0.0078, 6, true, true, true)
	_cyl(_st(b, "hardware"), p.call(0.0575), p.call(0.0625), 0.0042, 0.0042, 10, false, true)

	# Hanger: the cast front-view profile (grinding bar over the axle, a tent rising in the middle, a rounded belly),
	# the neck up to the bushing seat, the pivot nub up into the pivot cup, and the cross on both faces.
	_prism(_st(b, "trucks"), _hanger_profile(), Vector3.RIGHT, Vector3.UP, Vector3.BACK, -HANGER_DEPTH, HANGER_DEPTH, 0.003)
	var web: PackedVector2Array = PackedVector2Array([Vector2(0.0115, 0.044), Vector2(0.007, 0.056), Vector2(-0.02, 0.081),
			Vector2(-0.035, 0.075), Vector2(-0.027, 0.058), Vector2(-0.0115, 0.046)])
	_prism(_st(b, "trucks"), web, Vector3.BACK, Vector3.UP, Vector3.RIGHT, -0.0125, 0.0125, 0.003)
	_cyl(_st(b, "trucks"), Vector3(0.0, 0.054, 0.005), PIVOT_CUP + k * 0.004, 0.0062, 0.0048, 10, true, true)
	var cross: PackedVector2Array = _cross_outline(Vector2(0.0, 0.034), 0.0118, 0.0024, 0.0062)
	_prism(_st(b, "truck_dark"), cross, Vector3.RIGHT, Vector3.UP, Vector3.BACK, -HANGER_DEPTH - 0.0006, -HANGER_DEPTH + 0.001, 0.0)
	_prism(_st(b, "truck_dark"), cross, Vector3.RIGHT, Vector3.UP, Vector3.BACK, HANGER_DEPTH - 0.001, HANGER_DEPTH + 0.0006, 0.0)

	# Axle through the hanger, a speed ring each side of each wheel, and the axle nuts.
	var wx: float = WHEEL_X
	_cyl(_st(b, "hardware"), Vector3(-wx - 0.019, AXLE_Y, 0.0), Vector3(wx + 0.019, AXLE_Y, 0.0), 0.0042, 0.0042, 10, true, true)
	for s: float in [-1.0, 1.0]:
		_cyl(_st(b, "hardware"), Vector3(s * (HANGER_HALF - 0.001), AXLE_Y, 0.0), Vector3(s * (wx - 0.0152), AXLE_Y, 0.0),
				0.0062, 0.0062, 12, true, true)
		_cyl(_st(b, "hardware"), Vector3(s * (wx + 0.0152), AXLE_Y, 0.0), Vector3(s * (wx + 0.0175), AXLE_Y, 0.0),
				0.0062, 0.0062, 12, true, true)
		_cyl(_st(b, "hardware"), Vector3(s * (wx + 0.0175), AXLE_Y, 0.0), Vector3(s * (wx + 0.0245), AXLE_Y, 0.0),
				0.0068, 0.0068, 6, true, true, true)

	var names: Dictionary = {"trucks": "TruckHangerMesh", "baseplate": "TruckBaseMesh", "hardware": "TruckAxleMesh",
			"bushings": "TruckBushingsMesh", "riser": "TruckRiserMesh", "truck_dark": "TruckCrossMesh"}
	for key: String in b:
		SkaterParts.part(body, names.get(key, "Truck_" + key), (b[key] as SurfaceTool).commit(), Vector3.ZERO, mats, key)


## Urethane wheel (bottom at y = 0): a lathe-turned tyre with rounded lips and a recessed face, a cream core ring
## on each face (children of the wheel, so they spin with it), and the bearing in the "_Hub" sibling: a coloured
## shield between a steel outer race and inner race.
static func build_wheel(board: Node3D, wheel_name: String, x: float, z: float, mats: Dictionary) -> void:
	var h: float = WHEEL_W * 0.5
	var r: float = WHEEL_R
	var prof: PackedVector2Array = PackedVector2Array([
		Vector2(0.0112, -h + 0.0024), Vector2(0.0205, -h + 0.0024), Vector2(0.0222, -h + 0.0006), Vector2(0.0262, -h),
		Vector2(0.0293, -h + 0.0012), Vector2(0.0311, -h + 0.0042), Vector2(r, -h + 0.009), Vector2(r, h - 0.009),
		Vector2(0.0311, h - 0.0042), Vector2(0.0293, h - 0.0012), Vector2(0.0262, h), Vector2(0.0222, h - 0.0006),
		Vector2(0.0205, h - 0.0024), Vector2(0.0112, h - 0.0024), Vector2(0.0112, -h + 0.0024)])
	var tyre: SurfaceTool = _new_st()
	_lathe(tyre, prof, 20)
	var wheel: MeshInstance3D = SkaterParts.part(board, wheel_name, tyre.commit(), Vector3(x, AXLE_Y, z), mats, "wheels")
	wheel.rotation.z = PI * 0.5
	var face: float = h - 0.0022
	var core: SurfaceTool = _new_st()
	for s: float in [-1.0, 1.0]:
		_ring(core, Vector3(0.0, s * face, 0.0), Vector3(0.0, s, 0.0), 0.0108, 0.0168, 20)
	SkaterParts.part(wheel, wheel_name + "_Core", core.commit(), Vector3.ZERO, mats, "core")

	var shield: SurfaceTool = _new_st()
	var races: SurfaceTool = _new_st()
	for s: float in [-1.0, 1.0]:
		var c: Vector3 = Vector3(0.0, s * (face + 0.0003), 0.0)
		_ring(shield, c, Vector3(0.0, s, 0.0), 0.0056, 0.0094, 16)
		_ring(races, c, Vector3(0.0, s, 0.0), 0.0094, 0.0112, 16)
		_ring(races, c, Vector3(0.0, s, 0.0), 0.0041, 0.0056, 8)
	var hub: MeshInstance3D = SkaterParts.part(board, wheel_name + "_Hub", shield.commit(), Vector3(x, AXLE_Y, z), mats, "hubs")
	hub.rotation.z = PI * 0.5
	SkaterParts.part(hub, wheel_name + "_Races", races.commit(), Vector3.ZERO, mats, "hardware")


## Deck centre line height at z: flat in the middle, then a short bend into a straight kick at the nose (-Z) and
## tail (+Z) angles.
static func center_y(z: float) -> float:
	var base: float = DECK_TOP_Y - VIS_THICK * 0.5
	var d: float = absf(z) - KICK_START
	if d <= 0.0:
		return base
	var t: float = tan(deg_to_rad(NOSE_ANGLE if z < 0.0 else TAIL_ANGLE))
	if d < KICK_BEND:
		return base + t * d * d / (2.0 * KICK_BEND)
	return base + t * (d - KICK_BEND * 0.5)


## Top surface height (grip) at (x, z): the centre line plus the concave lift toward the rails.
static func top_y(x: float, z: float) -> float:
	return center_y(z) + VIS_THICK * 0.5 + _concave(x)


static func _concave(x: float) -> float:
	var u: float = clampf(x / (DECK_WIDTH * 0.5), -1.0, 1.0)
	return CONCAVE * u * u


## Half width at z: full in the middle, a half ellipse over the ends.
static func _half_width(z: float) -> float:
	var end: float = DECK_LENGTH * 0.5 - KICK_START
	var d: float = maxf(absf(z) - KICK_START, 0.0) / end
	return DECK_WIDTH * 0.5 * sqrt(maxf(1.0 - d * d, 0.0))


## |z| where the end outline crosses x (inverse of _half_width over the ends).
static func _end_z(x: float) -> float:
	var u: float = clampf(absf(x) / (DECK_WIDTH * 0.5), 0.0, 1.0)
	return KICK_START + (DECK_LENGTH * 0.5 - KICK_START) * sqrt(1.0 - u * u)


## z samples from nose to tail: even in the middle, arc-spaced over the rounded ends so the tips stay round.
static func _sample_zs() -> Array:
	var out: Array = []
	var end: float = DECK_LENGTH * 0.5 - KICK_START
	var arc: int = 14
	for i: int in arc + 1:
		var phi: float = (PI * 0.5) * (1.0 - float(i) / float(arc))
		out.append(-(KICK_START + end * sin(phi)))
	var mid: int = 10
	for i: int in range(1, mid):
		out.append(-KICK_START + 2.0 * KICK_START * float(i) / float(mid))
	for i: int in arc + 1:
		var phi: float = (PI * 0.5) * float(i) / float(arc)
		out.append(KICK_START + end * sin(phi))
	return out


## Rows of (x, z) points across the deck outline, one row per z sample.
static func _outline_rows(zs: Array, cols: int) -> Array:
	var rows: Array = []
	for z: float in zs:
		var hw: float = _half_width(z)
		var row: PackedVector2Array = PackedVector2Array()
		for j: int in cols + 1:
			row.append(Vector2(lerpf(-hw, hw, float(j) / float(cols)), z))
		rows.append(row)
	return rows


## Concentric rings of (x, z) points filling a disc.
static func _disc_rows(c: Vector2, radius: float, rings: int, segs: int) -> Array:
	var rows: Array = []
	for i: int in rings + 1:
		var rr: float = radius * float(i) / float(rings)
		var row: PackedVector2Array = PackedVector2Array()
		for k: int in segs + 1:
			var a: float = TAU * float(k) / float(segs)
			row.append(c + Vector2(cos(a), sin(a)) * rr)
		rows.append(row)
	return rows


## Two rows spanning a straight band across the board between z0 and z1, x within +-half.
static func _band_rows(z0: float, z1: float, half: float) -> Array:
	var a: PackedVector2Array = PackedVector2Array()
	var b: PackedVector2Array = PackedVector2Array()
	for j: int in 9:
		var x: float = lerpf(-half, half, float(j) / 8.0)
		a.append(Vector2(x, z0))
		b.append(Vector2(x, z1))
	return [a, b]


## Wave crest z at x, offset toward the tail by `shift`.
static func _wave_z(x: float, shift: float) -> float:
	return 0.035 + shift + 0.016 * sin(x * 48.0 + shift * 30.0) + 0.006 * sin(x * 110.0 + 1.3)


## The sea: from the first crest to the tail's outline.
static func _sea_rows(shift: float) -> Array:
	var rows: Array = []
	var cols: int = 22
	var rows_n: int = 8
	var hw: float = DECK_WIDTH * 0.5 - 0.0001
	for i: int in rows_n + 1:
		var v: float = float(i) / float(rows_n)
		var row: PackedVector2Array = PackedVector2Array()
		for j: int in cols + 1:
			var x: float = lerpf(-hw, hw, float(j) / float(cols))
			row.append(Vector2(x, lerpf(_wave_z(x, shift), _end_z(x) - 0.0004, v)))
		rows.append(row)
	return rows


## A foam line (two rows) along a crest, half width w.
static func _wave_line(shift: float, w: float) -> Array:
	var a: PackedVector2Array = PackedVector2Array()
	var b: PackedVector2Array = PackedVector2Array()
	var hw: float = DECK_WIDTH * 0.5 - 0.0015
	for j: int in 33:
		var x: float = lerpf(-hw, hw, float(j) / 32.0)
		a.append(Vector2(x, _wave_z(x, shift) - w))
		b.append(Vector2(x, _wave_z(x, shift) + w))
	return [a, b]


## A surface following the deck (top or bottom) over a grid of (x, z) rows, lifted `off` off it (outward).
static func _patch(rows: Array, off: float, facing_up: bool) -> ArrayMesh:
	var st: SurfaceTool = _new_st()
	_patch_into(st, rows, off, facing_up)
	return st.commit()


## Several two-row strips on the bottom, `off` below it.
static func _patch_multi(strips: Array, off: float) -> ArrayMesh:
	var st: SurfaceTool = _new_st()
	for rows: Array in strips:
		_patch_into(st, rows, off, false)
	return st.commit()


static func _patch_into(st: SurfaceTool, rows: Array, off: float, facing_up: bool) -> void:
	var sgn: float = 1.0 if facing_up else -1.0
	for i: int in rows.size() - 1:
		var r0: PackedVector2Array = rows[i]
		var r1: PackedVector2Array = rows[i + 1]
		for j: int in r0.size() - 1:
			var q: Array = [r0[j], r0[j + 1], r1[j], r1[j + 1]]
			var v: Array = []
			var n: Array = []
			for p: Vector2 in q:
				var y: float = top_y(p.x, p.y) + off if facing_up else top_y(p.x, p.y) - VIS_THICK - off
				v.append(Vector3(p.x, y, p.y))
				n.append(_surface_normal(p.x, p.y) * sgn)
			_tri(st, v[0], v[1], v[2], n[0], n[1], n[2])
			_tri(st, v[1], v[3], v[2], n[1], n[3], n[2])


static func _surface_normal(x: float, z: float) -> Vector3:
	var e: float = 0.002
	var dx: float = (top_y(x + e, z) - top_y(x - e, z)) / (2.0 * e)
	var dz: float = (center_y(z + e) - center_y(z - e)) / (2.0 * e)
	return Vector3(-dx, 1.0, -dz).normalized()


## One horizontal band of the edge wall, from `d0` to `d1` below the top surface, all round the outline.
static func _edge_band(st: SurfaceTool, zs: Array, d0: float, d1: float) -> void:
	var loop: Array = []
	for z: float in zs:
		loop.append(Vector2(_half_width(z), z))
	for i: int in range(zs.size() - 1, -1, -1):
		loop.append(Vector2(-_half_width(zs[i]), zs[i]))
	for i: int in loop.size():
		var p0: Vector2 = loop[i]
		var p1: Vector2 = loop[(i + 1) % loop.size()]
		if p0.distance_to(p1) < 0.0001:
			continue
		var out0: Vector3 = _outward(loop, i)
		var out1: Vector3 = _outward(loop, (i + 1) % loop.size())
		var a: Vector3 = Vector3(p0.x, top_y(p0.x, p0.y) - d0, p0.y)
		var b: Vector3 = Vector3(p1.x, top_y(p1.x, p1.y) - d0, p1.y)
		var c: Vector3 = Vector3(p0.x, top_y(p0.x, p0.y) - d1, p0.y)
		var d: Vector3 = Vector3(p1.x, top_y(p1.x, p1.y) - d1, p1.y)
		_tri(st, a, b, c, out0, out1, out0)
		_tri(st, b, d, c, out1, out1, out0)


static func _outward(loop: Array, i: int) -> Vector3:
	var n: int = loop.size()
	var prev: Vector2 = loop[(i - 1 + n) % n]
	var next: Vector2 = loop[(i + 1) % n]
	var t: Vector2 = next - prev
	var normal: Vector2 = Vector2(t.y, -t.x).normalized()
	var p: Vector2 = loop[i]
	if normal.dot(Vector2(p.x, p.y)) < 0.0:
		normal = -normal
	return Vector3(normal.x, 0.0, normal.y)


## Baseplate outline in (x, z): wide at the kingpin end (-Z), tapering toward the pivot end, rounded corners.
static func _plate_outline() -> PackedVector2Array:
	var corners: Array = [Vector2(-0.036, -0.047), Vector2(0.036, -0.047), Vector2(0.03, 0.044), Vector2(-0.03, 0.044)]
	return _round_corners(corners, 0.011, 4)


static func _rounded_rect(hx: float, hz: float, r: float, steps: int) -> PackedVector2Array:
	return _round_corners([Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)], r, steps)


## Replaces each corner of a convex polygon with an arc of radius r.
static func _round_corners(corners: Array, r: float, steps: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = corners.size()
	for i: int in n:
		var p: Vector2 = corners[i]
		var a: Vector2 = (corners[(i - 1 + n) % n] - p).normalized()
		var b: Vector2 = (corners[(i + 1) % n] - p).normalized()
		var p0: Vector2 = p + a * r
		var p1: Vector2 = p + b * r
		for k: int in steps + 1:
			var t: float = float(k) / float(steps)
			# Quadratic Bezier through the corner: a smooth fillet.
			out.append(p0.lerp(p, t).lerp(p.lerp(p1, t), t))
	return out


## Front view of the hanger in (x, y): the grinding bar with rounded ends round the axle, a tent rising in the
## middle toward the bushing seat, and a rounded belly under the middle.
static func _hanger_profile() -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var end_x: float = HANGER_HALF - 0.012
	# Right end: an arc round the axle from the top to the bottom.
	for k: int in 7:
		var a: float = PI * 0.5 - PI * float(k) / 6.0
		pts.append(Vector2(end_x + 0.012 * cos(a), AXLE_Y + 0.0125 * sin(a)))
	# Underside sweeping down to the belly, round the bottom, and up to the left end.
	var under: Array = [Vector2(0.046, 0.0195), Vector2(0.028, 0.0165), Vector2(0.016, 0.0135), Vector2(0.008, 0.0118),
			Vector2(0.0, 0.0113), Vector2(-0.008, 0.0118), Vector2(-0.016, 0.0135), Vector2(-0.028, 0.0165), Vector2(-0.046, 0.0195)]
	for p: Vector2 in under:
		pts.append(p)
	for k: int in 7:
		var a: float = -PI * 0.5 - PI * float(k) / 6.0
		pts.append(Vector2(-end_x + 0.012 * cos(a), AXLE_Y + 0.0125 * sin(a)))
	# Top: the flat grinding bar, then the tent.
	var top: Array = [Vector2(-0.038, 0.0448), Vector2(-0.026, 0.047), Vector2(-0.014, 0.0545), Vector2(-0.006, 0.058),
			Vector2(0.006, 0.058), Vector2(0.014, 0.0545), Vector2(0.026, 0.047), Vector2(0.038, 0.0448)]
	for p: Vector2 in top:
		pts.append(p)
	return pts


## The Indy-style cross: four arms flaring out from the centre.
static func _cross_outline(c: Vector2, arm: float, inner: float, outer: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var dirs: Array = [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)]
	for i: int in 4:
		var d: Vector2 = dirs[i]
		var nxt: Vector2 = dirs[(i + 1) % 4]
		var prv: Vector2 = dirs[(i + 3) % 4]
		pts.append(c + d * arm + prv * outer)
		pts.append(c + d * (arm - 0.0018))
		pts.append(c + d * arm + nxt * outer)
		pts.append(c + (d + nxt) * inner)
	return pts


## Extrudes a 2D outline (u, v axes) along `axis` from d0 to d1, with the caps inset by `bevel` for a soft edge.
static func _prism(st: SurfaceTool, outline: PackedVector2Array, u: Vector3, v: Vector3, axis: Vector3, d0: float, d1: float,
		bevel: float) -> void:
	var n: int = outline.size()
	var area: float = 0.0
	for i: int in n:
		area += outline[i].cross(outline[(i + 1) % n])
	var ccw: bool = area > 0.0
	var normals: Array = []
	var inset: PackedVector2Array = PackedVector2Array()
	for i: int in n:
		var e0: Vector2 = outline[i] - outline[(i - 1 + n) % n]
		var e1: Vector2 = outline[(i + 1) % n] - outline[i]
		var n0: Vector2 = Vector2(e0.y, -e0.x).normalized()
		var n1: Vector2 = Vector2(e1.y, -e1.x).normalized()
		if not ccw:
			n0 = -n0
			n1 = -n1
		var nn: Vector2 = (n0 + n1).normalized()
		normals.append(nn)
		var miter: float = maxf(nn.dot(n1), 0.5)
		inset.append(outline[i] - nn * bevel / miter)
	var to3: Callable = func(p: Vector2, d: float) -> Vector3: return u * p.x + v * p.y + axis * d
	var b: float = minf(bevel, (d1 - d0) * 0.45)
	var layers: Array = [[inset, d0, -1.0], [outline, d0 + b, 0.0], [outline, d1 - b, 0.0], [inset, d1, 1.0]]
	if bevel <= 0.0:
		layers = [[outline, d0, 0.0], [outline, d1, 0.0]]
	for li: int in layers.size() - 1:
		var la: Array = layers[li]
		var lb: Array = layers[li + 1]
		for i: int in n:
			var j: int = (i + 1) % n
			var pa: PackedVector2Array = la[0]
			var pb: PackedVector2Array = lb[0]
			var ni: Vector2 = normals[i]
			var nj: Vector2 = normals[j]
			var nai: Vector3 = (u * ni.x + v * ni.y + axis * float(la[2])).normalized()
			var naj: Vector3 = (u * nj.x + v * nj.y + axis * float(la[2])).normalized()
			var nbi: Vector3 = (u * ni.x + v * ni.y + axis * float(lb[2])).normalized()
			var nbj: Vector3 = (u * nj.x + v * nj.y + axis * float(lb[2])).normalized()
			var a: Vector3 = to3.call(pa[i], float(la[1]))
			var bb: Vector3 = to3.call(pa[j], float(la[1]))
			var c: Vector3 = to3.call(pb[i], float(lb[1]))
			var d: Vector3 = to3.call(pb[j], float(lb[1]))
			_tri(st, a, bb, c, nai, naj, nbi)
			_tri(st, bb, d, c, naj, nbj, nbi)
	var cap: PackedVector2Array = inset if bevel > 0.0 else outline
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(cap)
	for t: int in range(0, idx.size(), 3):
		for side: float in [-1.0, 1.0]:
			var d: float = d1 if side > 0.0 else d0
			var nrm: Vector3 = axis * side
			_tri(st, to3.call(cap[idx[t]], d), to3.call(cap[idx[t + 1]], d), to3.call(cap[idx[t + 2]], d), nrm, nrm, nrm)


## Cylinder (or cone) from a to b with radii ra and rb. Flat-shaded sides when `flat` (hex nuts).
static func _cyl(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, segs: int, cap_a: bool, cap_b: bool,
		flat: bool = false) -> void:
	var axis: Vector3 = (b - a).normalized()
	var side: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up: Vector3 = side.cross(axis).normalized()
	var slope: float = (ra - rb) / maxf(a.distance_to(b), 0.00001)
	for k: int in segs:
		var a0: float = TAU * float(k) / float(segs)
		var a1: float = TAU * float(k + 1) / float(segs)
		var d0: Vector3 = side * cos(a0) + up * sin(a0)
		var d1: Vector3 = side * cos(a1) + up * sin(a1)
		var n0: Vector3 = (d0 + axis * slope).normalized()
		var n1: Vector3 = (d1 + axis * slope).normalized()
		if flat:
			n0 = ((d0 + d1) * 0.5 + axis * slope).normalized()
			n1 = n0
		_tri(st, a + d0 * ra, a + d1 * ra, b + d0 * rb, n0, n1, n0)
		_tri(st, a + d1 * ra, b + d1 * rb, b + d0 * rb, n1, n1, n0)
		if cap_a:
			_tri(st, a, a + d0 * ra, a + d1 * ra, -axis, -axis, -axis)
		if cap_b:
			_tri(st, b, b + d1 * rb, b + d0 * rb, axis, axis, axis)


## Flat ring (annulus) centred on c, facing `normal`, around the Y axis.
static func _ring(st: SurfaceTool, c: Vector3, normal: Vector3, r0: float, r1: float, segs: int) -> void:
	for k: int in segs:
		var a0: float = TAU * float(k) / float(segs)
		var a1: float = TAU * float(k + 1) / float(segs)
		var d0: Vector3 = Vector3(sin(a0), 0.0, -cos(a0))
		var d1: Vector3 = Vector3(sin(a1), 0.0, -cos(a1))
		_tri(st, c + d0 * r0, c + d1 * r0, c + d0 * r1, normal, normal, normal)
		_tri(st, c + d1 * r0, c + d1 * r1, c + d0 * r1, normal, normal, normal)


## Surface of revolution around Y from a closed (radius, y) profile. Normals are smooth round the turn and across
## gentle profile corners, split at sharp ones.
static func _lathe(st: SurfaceTool, prof: PackedVector2Array, segs: int) -> void:
	var m: int = prof.size()
	var cx: Vector2 = Vector2.ZERO
	for p: Vector2 in prof:
		cx += p
	cx /= float(m)
	var seg_n: Array = []
	for i: int in m - 1:
		var t: Vector2 = prof[i + 1] - prof[i]
		var nn: Vector2 = Vector2(t.y, -t.x).normalized()
		var mid: Vector2 = (prof[i] + prof[i + 1]) * 0.5
		if nn.dot(mid - cx) < 0.0:
			nn = -nn
		seg_n.append(nn)
	for i: int in m - 1:
		var na: Vector2 = seg_n[i]
		var nb: Vector2 = seg_n[i]
		if i > 0 and (seg_n[i - 1] as Vector2).dot(seg_n[i]) > 0.64:
			na = ((seg_n[i - 1] as Vector2) + (seg_n[i] as Vector2)).normalized()
		if i < m - 2 and (seg_n[i + 1] as Vector2).dot(seg_n[i]) > 0.64:
			nb = ((seg_n[i + 1] as Vector2) + (seg_n[i] as Vector2)).normalized()
		for k: int in segs:
			var a0: float = TAU * float(k) / float(segs)
			var a1: float = TAU * float(k + 1) / float(segs)
			var d0: Vector3 = Vector3(sin(a0), 0.0, -cos(a0))
			var d1: Vector3 = Vector3(sin(a1), 0.0, -cos(a1))
			var p0: Vector2 = prof[i]
			var p1: Vector2 = prof[i + 1]
			var v00: Vector3 = d0 * p0.x + Vector3.UP * p0.y
			var v01: Vector3 = d1 * p0.x + Vector3.UP * p0.y
			var v10: Vector3 = d0 * p1.x + Vector3.UP * p1.y
			var v11: Vector3 = d1 * p1.x + Vector3.UP * p1.y
			var n00: Vector3 = (d0 * na.x + Vector3.UP * na.y).normalized()
			var n01: Vector3 = (d1 * na.x + Vector3.UP * na.y).normalized()
			var n10: Vector3 = (d0 * nb.x + Vector3.UP * nb.y).normalized()
			var n11: Vector3 = (d1 * nb.x + Vector3.UP * nb.y).normalized()
			_tri(st, v00, v01, v10, n00, n01, n10)
			_tri(st, v01, v11, v10, n01, n11, n10)


static func _new_st() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## The SurfaceTool for one palette key in a builder dictionary, made on first use.
static func _st(builders: Dictionary, key: String) -> SurfaceTool:
	if not builders.has(key):
		builders[key] = _new_st()
	return builders[key]


## Adds a triangle wound clockwise as seen from the side its normals point to (Godot's front face).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var face: Vector3 = (b - a).cross(c - a)
	var avg: Vector3 = na + nb + nc
	if face.length() < 0.0000001:
		return
	if face.dot(avg) > 0.0:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nc)
		st.add_vertex(c)
		st.set_normal(nb)
		st.add_vertex(b)
	else:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nb)
		st.add_vertex(b)
		st.set_normal(nc)
		st.add_vertex(c)
