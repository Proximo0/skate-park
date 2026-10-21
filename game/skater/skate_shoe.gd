class_name SkateShoe
extends RefCounted
## Vulcanised skate shoe in the Vans Old Skool mould, built for the placeholder skater: a flat, wide, low upper
## lofted from superellipse sections (flat top, near-vertical sides, boxy rounded toe) on a thick white foxing
## band with a thin coloured line, a waffle-hinted sole edge, a rubber toe bumper, a suede toe cap, eyestays and
## heel counter with double stitching, 6 eyelets a side with flat criss-cross laces and a bow, a puffy tongue,
## a padded collar roll, a heel pull tab and the curved "jazz" side stripe.
##
## Foot joint space: ankle at the origin, toe toward -Z, sole bottom at -ankle_height. Geometry is built in
## ground space (y = 0 at the sole bottom) and every part is offset down by ankle_height.
## Colours come from a colourway Dictionary (see PRESETS); its keys are palette keys ("shoe_*").

const LENGTH: float = ShoeShape.D_LENGTH  ## heel to toe of the upper (sole is ~8 mm longer)
const HEEL_Z: float = ShoeShape.D_HEEL_Z  ## z of the back of the upper's heel
const EXP: float = ShoeShape.D_EXP  ## 2 / superellipse exponent (~2.8): flat top, near-vertical sides
const SOLE_TOP: float = 0.012  ## top of the outsole band (white rubber, waffle edge)
const FOX_TOP: float = ShoeShape.D_FOX_TOP  ## top of the foxing band, where the upper starts
const TUCK: float = ShoeShape.D_TUCK  ## how far the upper runs down inside the foxing
const TOE_R: float = ShoeShape.D_TOE_R  ## plan-view toe rounding length
const TOE_V: float = ShoeShape.D_TOE_V  ## side-view toe rounding length
const HEEL_R: float = ShoeShape.D_HEEL_R  ## plan-view heel rounding length
const G_SOLE: float = ShoeShape.D_G_SOLE
const G_FOX: float = ShoeShape.D_G_FOX
## Upper plan before the end rounding: distance from heel, half width, height above FOX_TOP.
const PLAN: Array = ShoeShape.D_PLAN
## Ankle opening (collar rim) in plan: centre distance from heel, half length, half width.
const OPEN_D: float = 0.0765
const OPEN_HALF_D: float = 0.0485
const OPEN_HALF_X: float = 0.036
const EYESTAY_IN: float = 0.0155
const EYESTAY_OUT: float = 0.0345
const EYELETS: int = 6
const EYELET_X: float = 0.0245
const EYELET_TOP_D: float = 0.137
const EYELET_LOW_D: float = 0.196

const LAGOON: String = "Old Skool Lagoon"
const DUNK: String = "Dunk Coral Reef"
const ONE_STAR: String = "One Star Sunset"
## Colourway presets. Keys are palette keys; a colourway may give any subset (the rest come from Lagoon).
const PRESETS: Dictionary = {
	LAGOON: {
		"shoe_canvas": Color(0.06, 0.6, 0.64),
		"shoe_suede": Color(0.03, 0.43, 0.49),
		"shoe_stripe": Color(1.0, 0.45, 0.36),
		"shoe_foxing": Color(0.97, 0.96, 0.92),
		"shoe_foxing_line": Color(1.0, 0.45, 0.36),
		"shoe_bumper": Color(0.99, 0.98, 0.95),
		"shoe_sole": Color(0.95, 0.93, 0.88),
		"shoe_tread": Color(0.78, 0.78, 0.8),
		"shoe_tab": Color(1.0, 0.45, 0.36),
		"shoe_laces": Color(1.0, 0.94, 0.8),
		"shoe_eyelet": Color(0.16, 0.18, 0.24),
		"shoe_tongue": Color(0.06, 0.6, 0.64),
		"shoe_collar": Color(0.03, 0.43, 0.49),
		"shoe_lining": Color(0.1, 0.13, 0.2),
		"shoe_stitch": Color(1.0, 0.95, 0.84),
	},
	DUNK: {
		"shoe_canvas": Color(0.98, 0.95, 0.89),
		"shoe_suede": Color(1.0, 0.5, 0.42),
		"shoe_stripe": Color(0.04, 0.5, 0.57),
		"shoe_foxing": Color(0.98, 0.97, 0.94),
		"shoe_foxing_line": Color(1.0, 0.5, 0.42),
		"shoe_bumper": Color(0.98, 0.97, 0.94),
		"shoe_sole": Color(0.04, 0.5, 0.57),
		"shoe_tread": Color(0.02, 0.33, 0.4),
		"shoe_tab": Color(0.04, 0.5, 0.57),
		"shoe_laces": Color(0.99, 0.98, 0.95),
		"shoe_eyelet": Color(0.98, 0.95, 0.89),
		"shoe_tongue": Color(0.04, 0.5, 0.57),
		"shoe_collar": Color(1.0, 0.5, 0.42),
		"shoe_lining": Color(0.02, 0.27, 0.33),
		"shoe_stitch": Color(0.98, 0.95, 0.89),
	},
	ONE_STAR: {
		"shoe_canvas": Color(1.0, 0.64, 0.3),
		"shoe_suede": Color(0.93, 0.38, 0.27),
		"shoe_stripe": Color(0.45, 0.29, 0.72),
		"shoe_foxing": Color(0.99, 0.94, 0.83),
		"shoe_foxing_line": Color(0.45, 0.29, 0.72),
		"shoe_bumper": Color(0.99, 0.94, 0.83),
		"shoe_sole": Color(0.8, 0.56, 0.32),
		"shoe_tread": Color(0.6, 0.39, 0.2),
		"shoe_tab": Color(0.45, 0.29, 0.72),
		"shoe_laces": Color(0.99, 0.94, 0.83),
		"shoe_eyelet": Color(0.3, 0.18, 0.45),
		"shoe_tongue": Color(1.0, 0.64, 0.3),
		"shoe_collar": Color(0.45, 0.29, 0.72),
		"shoe_lining": Color(0.25, 0.14, 0.32),
		"shoe_stitch": Color(0.99, 0.94, 0.83),
	},
}


## The colourway preset called `preset_name` (Lagoon when unknown).
static func preset(preset_name: String) -> Dictionary:
	return (PRESETS.get(preset_name, PRESETS[LAGOON]) as Dictionary).duplicate()


## A full colourway from one catalogue colour (the canvas), for the customiser: darker suede panels and collar,
## a contrasting jazz stripe and heel tab, white foxing and laces.
static func colourway_from(canvas: Color) -> Dictionary:
	var c: Dictionary = preset(LAGOON)
	var contrast: Color = Color.from_hsv(fposmod(canvas.h + 0.5, 1.0), clampf(canvas.s, 0.55, 0.85), clampf(canvas.v, 0.75, 1.0))
	c["shoe_canvas"] = canvas
	c["shoe_tongue"] = canvas
	c["shoe_suede"] = canvas.darkened(0.25)
	c["shoe_collar"] = canvas.darkened(0.25)
	c["shoe_stripe"] = contrast
	c["shoe_foxing_line"] = contrast
	c["shoe_tab"] = contrast
	return c


## Builds the shoe under `foot` as "<side>ShoeMesh". Colours: `colourway` keys win, then materials already in
## `mats` (e.g. from the body palette), then the Lagoon defaults (added to `mats` so both shoes share them).
static func build(foot: Node3D, side: String, ankle_height: float, mats: Dictionary, colourway: Dictionary = {}) -> Node3D:
	var m: Dictionary = ShoeKit.materials(mats, colourway)
	var shoe: Node3D = SkaterParts.joint(foot, side + "ShoeMesh", Vector3.ZERO)
	var off: Vector3 = Vector3(0.0, -ankle_height, 0.0)
	_sole_parts(shoe, off, m)
	_upper_parts(shoe, off, m)
	_lacing_parts(shoe, off, m)
	_collar_parts(shoe, off, m)
	_stripes(shoe, off, m)
	return shoe


# --- sole: outsole with waffle edge, foxing band with its line, heel label -----------------------------------

static func _sole_parts(shoe: Node3D, off: Vector3, m: Dictionary) -> void:
	var st: SurfaceTool = ShoeKit.begin()
	var bottom: PackedVector3Array = _sh().outline(G_SOLE - 0.006, 0.0)
	var centre: PackedVector3Array = PackedVector3Array()
	var zc: float = HEEL_Z - LENGTH * 0.5
	for p: Vector3 in bottom:
		centre.append(Vector3(0.0, p.y, zc))
	var rows: Array = [centre, bottom, _sh().outline(G_SOLE, 0.004), _sh().outline(G_SOLE, SOLE_TOP)]
	ShoeKit.grid_into(st, rows, true, _sh().refs(rows, 0.008))
	SkaterParts.part(shoe, "SoleMesh", ShoeKit.done(st), off, m, "shoe_sole")

	st = ShoeKit.begin()
	rows = [_sh().outline(G_SOLE - 0.001, SOLE_TOP - 0.002), _sh().outline(G_FOX, SOLE_TOP), _sh().outline(G_FOX, FOX_TOP - 0.003),
			_sh().outline(G_FOX - 0.0025, FOX_TOP), _sh().outline(-0.002, FOX_TOP)]
	ShoeKit.grid_into(st, rows, true, _sh().refs(rows, 0.012))
	SkaterParts.part(shoe, "FoxingMesh", ShoeKit.done(st), off, m, "shoe_foxing")

	st = ShoeKit.begin()
	rows = [_sh().outline(G_FOX + 0.0007, 0.0215), _sh().outline(G_FOX + 0.0007, 0.0245)]
	ShoeKit.grid_into(st, rows, true, _sh().refs(rows, 0.023))
	SkaterParts.part(shoe, "FoxingLineMesh", ShoeKit.done(st), off, m, "shoe_foxing_line")

	# Waffle hint: short dark lugs round the bottom edge of the outsole.
	st = ShoeKit.begin()
	var ring: PackedVector3Array = _sh().outline(G_SOLE + 0.0006, 0.0)
	var lengths: PackedFloat32Array = PackedFloat32Array([0.0])
	for i: int in ring.size():
		lengths.append(lengths[i] + ring[i].distance_to(ring[(i + 1) % ring.size()]))
	var total: float = lengths[lengths.size() - 1]
	var count: int = int(total / 0.0105)
	for i: int in count:
		var s0: float = total * float(i) / float(count)
		var a: Vector3 = ShoeKit.along(ring, lengths, s0)
		var b: Vector3 = ShoeKit.along(ring, lengths, s0 + 0.0052)
		var up: Vector3 = Vector3(0.0, 0.0052, 0.0)
		var lift: Vector3 = Vector3(0.0, 0.0012, 0.0)
		ShoeKit.quad_into(st, a + lift, b + lift, a + up, b + up, Vector3(0.0, 0.004, clampf(a.z, HEEL_Z - LENGTH + 0.06, HEEL_Z - 0.06)))
	SkaterParts.part(shoe, "SoleTreadMesh", ShoeKit.done(st), off, m, "shoe_tread")

	# "Off the wall" style rubber label on the heel foxing.
	SkaterParts.part(shoe, "HeelLabelMesh", SkaterParts.box(Vector3(0.03, 0.011, 0.003)),
			off + Vector3(0.0, 0.019, HEEL_Z + G_FOX + 0.0006), m, "shoe_tab")


# --- upper: canvas body, suede toe cap, toe bumper, heel counter, eyestays ------------------------------------

static func _upper_parts(shoe: Node3D, off: Vector3, m: Dictionary) -> void:
	var cols: int = 14
	var st: SurfaceTool = ShoeKit.begin()
	var rows: Array = []
	for d: float in _sh().d_samples(0.0):
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols + 1:
			ring.append(_sh().pt(d, lerpf(-PI * 0.5, PI * 0.5, float(k) / float(cols)), 0.0))
		rows.append(ring)
	ShoeKit.grid_into(st, rows, false, _sh().refs(rows, 0.05))
	SkaterParts.part(shoe, "UpperMesh", ShoeKit.done(st), off, m, "shoe_canvas")

	# Toe cap (the ollie zone): suede over the toe box, its back edge a U from the first eyelet down to the foxing.
	var g_cap: float = 0.0022
	st = ShoeKit.begin()
	rows = []
	for i: int in 9:
		var r: float = pow(float(i) / 8.0, 0.85)
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols + 1:
			var phi: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / float(cols))
			ring.append(_sh().pt(lerpf(_sh().cap_edge(phi), LENGTH + g_cap, r), phi, g_cap))
		rows.append(ring)
	ShoeKit.grid_into(st, rows, false, _sh().refs(rows, 0.045))
	SkaterParts.part(shoe, "ToeCapMesh", ShoeKit.done(st), off, m, "shoe_suede")

	# Toe bumper: the white rubber wrap over the front of the toe, its top edge curving up to the tip.
	var g_bump: float = 0.0042
	st = ShoeKit.begin()
	for sgn: float in [-1.0, 1.0]:
		rows = []
		for i: int in 10:
			var d: float = lerpf(LENGTH - 0.07, LENGTH + g_bump, sin(float(i) / 9.0 * PI * 0.5))
			var v: float = 0.003 + 0.016 * smoothstep(LENGTH - 0.07, LENGTH - 0.002, d) + 0.03 * smoothstep(LENGTH - 0.002, LENGTH + g_bump, d)
			var pe: float = _sh().phi_at_v(d, v, g_bump)
			var ring: PackedVector3Array = PackedVector3Array()
			for k: int in 8:
				ring.append(_sh().pt(d, sgn * lerpf(pe, PI * 0.5, float(k) / 7.0), g_bump))
			rows.append(ring)
		ShoeKit.grid_into(st, rows, false, _sh().refs(rows, 0.045))
	SkaterParts.part(shoe, "ToeBumperMesh", ShoeKit.done(st), off, m, "shoe_bumper")

	# Heel counter: suede cup round the heel, its front edge sloping from the collar down to the foxing.
	var g_heel: float = 0.0024
	st = ShoeKit.begin()
	rows = []
	for i: int in 8:
		var r: float = 1.0 - cos(float(i) / 7.0 * PI * 0.5)
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols + 1:
			var phi: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / float(cols))
			var de: float = 0.022 + 0.04 * pow(absf(sin(phi)), 2.0)
			ring.append(_sh().pt(lerpf(-g_heel, de, r), phi, g_heel))
		rows.append(ring)
	ShoeKit.grid_into(st, rows, false, _sh().refs(rows, 0.06))
	SkaterParts.part(shoe, "HeelCounterMesh", ShoeKit.done(st), off, m, "shoe_suede")

	# Eyestays: suede lace panels either side of the tongue, from the collar down to the toe cap.
	var g_eye: float = 0.0026
	st = ShoeKit.begin()
	for sgn: float in [-1.0, 1.0]:
		rows = []
		for i: int in 11:
			var r: float = float(i) / 10.0
			var ring: PackedVector3Array = PackedVector3Array()
			for k: int in 4:
				var x: float = sgn * lerpf(EYESTAY_IN, EYESTAY_OUT, float(k) / 3.0)
				var d_end: float = _sh().cap_edge(_sh().phi_at_x(0.2, x, 0.0)) - 0.0015
				var d: float = lerpf(0.117, d_end, r)
				ring.append(_sh().pt(d, _sh().phi_at_x(d, x, g_eye), g_eye))
			rows.append(ring)
		ShoeKit.grid_into(st, rows, false, _sh().refs(rows, 0.05))
	SkaterParts.part(shoe, "EyestayMesh", ShoeKit.done(st), off, m, "shoe_suede")

	# Double stitch rows: along the toe cap edge and the outer edge of each eyestay.
	st = ShoeKit.begin()
	for gap: float in [0.0035, 0.0068]:
		var steps: int = 22
		for i: int in steps:
			var pa: float = lerpf(-1.42, 1.42, (float(i) + 0.15) / float(steps))
			var pb: float = lerpf(-1.42, 1.42, (float(i) + 0.75) / float(steps))
			_sh().dash(st, _sh().cap_edge(pa) + gap, pa, _sh().cap_edge(pb) + gap, pb, g_cap + 0.0009)
	for sgn: float in [-1.0, 1.0]:
		for xe: float in [EYESTAY_OUT - 0.0028, EYESTAY_OUT - 0.006]:
			var x: float = sgn * xe
			var d_end: float = _sh().cap_edge(_sh().phi_at_x(0.2, x, 0.0)) - 0.004
			var steps: int = 13
			for i: int in steps:
				var da: float = lerpf(0.12, d_end, (float(i) + 0.15) / float(steps))
				var db: float = lerpf(0.12, d_end, (float(i) + 0.75) / float(steps))
				_sh().dash(st, da, _sh().phi_at_x(da, x, g_eye), db, _sh().phi_at_x(db, x, g_eye), g_eye + 0.0009)
	SkaterParts.part(shoe, "StitchMesh", ShoeKit.done(st), off, m, "shoe_stitch")


# --- tongue, eyelets, flat criss-cross laces and a bow --------------------------------------------------------

## Tongue spine: distance from heel, height above the upper's top (or absolute y when > 0.1), half thickness,
## half width.
const TONGUE: Array = [
	[0.207, 0.0012, 0.0012, 0.0125], [0.18, 0.0022, 0.0022, 0.0145], [0.155, 0.0036, 0.0036, 0.0148],
	[0.14, 0.0085, 0.0075, 0.019], [0.132, 0.128, 0.011, 0.026], [0.1285, 0.143, 0.011, 0.0265],
	[0.1275, 0.1505, 0.0075, 0.022], [0.127, 0.1535, 0.0025, 0.012],
]


static func _lacing_parts(shoe: Node3D, off: Vector3, m: Dictionary) -> void:
	# Tongue: a lofted rounded-rectangle pad, thin under the laces and puffy where it stands above the throat.
	var st: SurfaceTool = ShoeKit.begin()
	var spine: PackedVector3Array = PackedVector3Array()
	for t: Array in TONGUE:
		var d: float = float(t[0])
		var y: float = float(t[1])
		if y < 0.1:
			y += _sh().top_y(d, 0.0)
		spine.append(Vector3(0.0, y, HEEL_Z - d))
	var rows: Array = []
	for i: int in spine.size():
		var tan: Vector3 = (spine[mini(i + 1, spine.size() - 1)] - spine[maxi(i - 1, 0)]).normalized()
		var nrm: Vector3 = Vector3.RIGHT.cross(tan).normalized()
		if nrm.y - nrm.z < 0.0:
			nrm = -nrm
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in 12:
			var a: float = TAU * float(k) / 12.0
			var c: float = cos(a)
			var s: float = sin(a)
			ring.append(spine[i] + Vector3.RIGHT * float(TONGUE[i][3]) * signf(s) * pow(absf(s), 0.6)
					+ nrm * float(TONGUE[i][2]) * signf(c) * pow(absf(c), 0.6))
		rows.append(ring)
	ShoeKit.grid_into(st, rows, true, spine)
	SkaterParts.part(shoe, "TongueMesh", ShoeKit.done(st), off, m, "shoe_tongue")

	# Eyelets: small dark discs on the eyestays.
	var g_eye: float = 0.0026
	st = ShoeKit.begin()
	var holes: Array = [[], []]
	for i: int in EYELETS:
		var d: float = lerpf(EYELET_LOW_D, EYELET_TOP_D, float(i) / float(EYELETS - 1))
		for j: int in 2:
			var x: float = EYELET_X * (-1.0 if j == 0 else 1.0)
			var phi: float = _sh().phi_at_x(d, x, g_eye)
			var p: Vector3 = _sh().pt(d, phi, g_eye + 0.0011)
			var n: Vector3 = (_sh().pt(d, phi, g_eye + 0.01) - _sh().pt(d, phi, g_eye)).normalized()
			var u: Vector3 = Vector3.FORWARD.cross(n).normalized()
			var w: Vector3 = n.cross(u).normalized()
			for k: int in 8:
				var a0: float = TAU * float(k) / 8.0
				var a1: float = TAU * float(k + 1) / 8.0
				ShoeKit.tri_into(st, p, p + (u * cos(a0) + w * sin(a0)) * 0.0034, p + (u * cos(a1) + w * sin(a1)) * 0.0034, p - n * 0.01)
			(holes[j] as Array).append([d, x])
	SkaterParts.part(shoe, "EyeletsMesh", ShoeKit.done(st), off, m, "shoe_eyelet")

	# Flat laces: a bottom bar, then criss-cross pairs arching over the tongue.
	st = ShoeKit.begin()
	var left: Array = holes[0]
	var right: Array = holes[1]
	_lace_into(st, left[0], right[0], 0)
	for i: int in EYELETS - 1:
		_lace_into(st, left[i], right[i + 1], 1)
		_lace_into(st, right[i], left[i + 1], 0)
	var items: Array = [[ShoeKit.done(st), Transform3D.IDENTITY]]
	# Bow at the top: a knot, two flat-ish loops and two tails lying down the laces.
	var kd: float = EYELET_TOP_D - 0.003
	var knot: Vector3 = _sh().over(kd, 0.0, 0.0125)
	items.append([SkaterParts.sphere_small(0.0045), Transform3D(Basis.from_scale(Vector3(1.2, 0.8, 1.0)), knot)])
	for sgn: float in [-1.0, 1.0]:
		var loop: PackedVector3Array = PackedVector3Array([knot, _sh().over(kd + 0.004, sgn * 0.012, 0.0135),
				_sh().over(kd + 0.011, sgn * 0.025, 0.012), _sh().over(kd + 0.006, sgn * 0.031, 0.0105),
				_sh().over(kd - 0.001, sgn * 0.022, 0.0115), knot + Vector3(sgn * 0.003, 0.0, 0.0)])
		loop = SkaterParts.smooth3d(loop, 2)
		var lr: PackedFloat32Array = PackedFloat32Array()
		for i: int in loop.size():
			lr.append(0.0021)
		items.append([SkaterParts.tube(loop, lr, 5), Transform3D.IDENTITY])
		var tail: PackedVector3Array = PackedVector3Array([knot, _sh().over(kd + 0.012, sgn * 0.006, 0.0115),
				_sh().over(kd + 0.026, sgn * 0.011, 0.0098), _sh().over(kd + 0.038, sgn * 0.015, 0.0092)])
		items.append([SkaterParts.tube_capped(tail, PackedFloat32Array([0.0022, 0.0022, 0.0021, 0.002]), 5),
				Transform3D.IDENTITY])
	SkaterParts.part(shoe, "LacesMesh", SkaterParts.merge(items), off, m, "shoe_laces")


## One flat lace from eyelet a to eyelet b ([d, x] each), arching over the tongue; layer 1 rides on top.
static func _lace_into(st: SurfaceTool, a: Array, b: Array, layer: int) -> void:
	var path: PackedVector3Array = PackedVector3Array()
	var n: int = 6
	for i: int in n:
		var t: float = float(i) / float(n - 1)
		var d: float = lerpf(float(a[0]), float(b[0]), t)
		var x: float = lerpf(float(a[1]), float(b[1]), t)
		var arch: float = pow(sin(PI * t), 0.6)
		var clear: float = 0.0034 + (_tongue_face(d) + 0.0018 - 0.0034) * arch + 0.0013 * float(layer) * arch
		path.append(_sh().over(d, x, clear))
	var rows: Array = []
	for i: int in n:
		var tan: Vector3 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var across: Vector3 = tan.cross(Vector3.UP).normalized() * 0.0044
		var up: Vector3 = Vector3(0.0, 0.0008, 0.0)
		rows.append(PackedVector3Array([path[i] + across + up, path[i] - across + up, path[i] - across - up,
				path[i] + across - up]))
	ShoeKit.grid_into(st, rows, true, path)


## Height of the tongue's top face above the upper's top at d (for the laces to clear it).
static func _tongue_face(d: float) -> float:
	for i: int in 3:
		var a: Array = TONGUE[i]
		var b: Array = TONGUE[i + 1]
		if d >= float(b[0]):
			var t: float = clampf((d - float(b[0])) / (float(a[0]) - float(b[0])), 0.0, 1.0)
			return lerpf(float(b[1]) + float(b[2]), float(a[1]) + float(a[2]), t)
	return float(TONGUE[3][1]) + float(TONGUE[3][2])


# --- collar: padded roll round the ankle opening, dark lining, heel pull tab ----------------------------------

static func _collar_parts(shoe: Node3D, off: Vector3, m: Dictionary) -> void:
	var path: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var n: int = 17
	for i: int in n:
		var psi: float = lerpf(-0.8 * PI, 0.8 * PI, float(i) / float(n - 1))
		var d: float = OPEN_D - OPEN_HALF_D * cos(psi)
		var x: float = OPEN_HALF_X * sin(psi)
		var back: float = 0.5 + 0.5 * cos(psi)
		path.append(_sh().over(d, x, 0.0005 + 0.003 * back))
		radii.append(lerpf(0.0068, 0.0092, back))
	SkaterParts.part(shoe, "CollarMesh", SkaterParts.tube_capped(path, radii, 6), off, m, "shoe_collar")

	# Lining: the dark inside of the shoe, seen round the sock through the opening.
	var st: SurfaceTool = ShoeKit.begin()
	var rows: Array = []
	var refs: PackedVector3Array = PackedVector3Array()
	for j: int in 4:
		var f: float = float(j) / 3.0
		var ring: PackedVector3Array = PackedVector3Array()
		for i: int in 18:
			var a: float = TAU * float(i) / 18.0
			ring.append(_sh().over(OPEN_D - (OPEN_HALF_D - 0.002) * f * cos(a), (OPEN_HALF_X - 0.002) * f * sin(a), 0.0025))
		rows.append(ring)
		refs.append(_sh().over(OPEN_D, 0.0, -0.05))
	ShoeKit.grid_into(st, rows, true, refs)
	SkaterParts.part(shoe, "LiningMesh", ShoeKit.done(st), off, m, "shoe_lining")

	# Heel pull tab standing up from the back of the collar.
	var tab: MeshInstance3D = SkaterParts.part(shoe, "HeelTabMesh", SkaterParts.box(Vector3(0.02, 0.036, 0.0045)),
			off + Vector3(0.0, _sh().top_y(0.0, 0.0) + 0.0005, HEEL_Z + 0.0045), m, "shoe_tab")
	tab.rotation.x = -0.12


# --- SUNSET wave stripe: a curved ribbon decal ~1 mm proud of each quarter -------------------------------------------

## Stripe path on the quarter: distance from heel, height above FOX_TOP, half width.
const STRIPE: Array = [
	[0.185, 0.034, 0.0030], [0.166, 0.046, 0.0034], [0.147, 0.033, 0.0036], [0.128, 0.020, 0.0036],
	[0.109, 0.033, 0.0036], [0.090, 0.046, 0.0036], [0.071, 0.033, 0.0034], [0.060, 0.022, 0.0030],
]


static func _stripes(shoe: Node3D, off: Vector3, m: Dictionary) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	for s: Array in STRIPE:
		pts.append(Vector3(float(s[0]), float(s[1]), float(s[2])))
	pts = SkaterParts.smooth3d(pts, 4)
	var g: float = 0.0011
	for sgn: float in [-1.0, 1.0]:
		var a_row: PackedVector3Array = PackedVector3Array()
		var b_row: PackedVector3Array = PackedVector3Array()
		for i: int in pts.size():
			var q: Vector3 = pts[i]
			var t: Vector3 = pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]
			var nrm: Vector2 = Vector2(-t.y, t.x).normalized() * q.z
			var da: float = q.x + nrm.x
			var va: float = q.y + nrm.y
			var db: float = q.x - nrm.x
			var vb: float = q.y - nrm.y
			a_row.append(_sh().pt(da, sgn * _sh().phi_at_v(da, va, g), g))
			b_row.append(_sh().pt(db, sgn * _sh().phi_at_v(db, vb, g), g))
		var st: SurfaceTool = ShoeKit.begin()
		ShoeKit.grid_into(st, [a_row, b_row], false, _sh().refs([a_row, b_row], 0.05))
		SkaterParts.part(shoe, "SidePanel" + ("Left" if sgn < 0.0 else "Right") + "Mesh", ShoeKit.done(st), off, m, "shoe_stripe")


# --- shape of the upper: ShoeShape holds the maths --------------------------------------------------------------

static var _shape: ShoeShape = null


## The low vulc's shape (also the starting point of every ShoeStyles shape).
static func _sh() -> ShoeShape:
	if _shape == null:
		_shape = ShoeShape.new()
	return _shape
