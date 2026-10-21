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

const LENGTH: float = 0.302  ## heel to toe of the upper (sole is ~8 mm longer)
const HEEL_Z: float = 0.08  ## z of the back of the upper's heel
const EXP: float = 0.72  ## 2 / superellipse exponent (~2.8): flat top, near-vertical sides
const SOLE_TOP: float = 0.012  ## top of the outsole band (white rubber, waffle edge)
const FOX_TOP: float = 0.033  ## top of the foxing band, where the upper starts
const TUCK: float = 0.007  ## how far the upper runs down inside the foxing
const TOE_R: float = 0.058  ## plan-view toe rounding length
const TOE_V: float = 0.042  ## side-view toe rounding length
const HEEL_R: float = 0.03  ## plan-view heel rounding length
const G_SOLE: float = 0.0055
const G_FOX: float = 0.0038
## Upper plan before the end rounding: distance from heel, half width, height above FOX_TOP.
const PLAN: Array = [
	[0.0, 0.036, 0.093], [0.03, 0.038, 0.093], [0.08, 0.041, 0.085], [0.13, 0.0455, 0.069],
	[0.17, 0.0495, 0.053], [0.21, 0.0525, 0.041], [0.25, 0.0515, 0.034], [0.302, 0.049, 0.031],
]
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
	var m: Dictionary = _materials(mats, colourway)
	var shoe: Node3D = SkaterParts.joint(foot, side + "ShoeMesh", Vector3.ZERO)
	var off: Vector3 = Vector3(0.0, -ankle_height, 0.0)
	_sole_parts(shoe, off, m)
	_upper_parts(shoe, off, m)
	_lacing_parts(shoe, off, m)
	_collar_parts(shoe, off, m)
	_stripes(shoe, off, m)
	return shoe


static func _materials(mats: Dictionary, colourway: Dictionary) -> Dictionary:
	var defaults: Dictionary = PRESETS[LAGOON]
	var out: Dictionary = mats.duplicate()
	var missing: Dictionary = {}
	for key: String in defaults.keys():
		if not mats.has(key):
			missing[key] = defaults[key]
	var made: Dictionary = SkaterParts.materials({}, missing)
	for key: String in made.keys():
		mats[key] = made[key]
		out[key] = made[key]
	var given: Dictionary = {}
	for key: String in colourway.keys():
		if defaults.has(key):
			given[key] = colourway[key]
	var custom: Dictionary = SkaterParts.materials({}, given)
	for key: String in custom.keys():
		out[key] = custom[key]
	return out


# --- sole: outsole with waffle edge, foxing band with its line, heel label -----------------------------------

static func _sole_parts(shoe: Node3D, off: Vector3, m: Dictionary) -> void:
	var st: SurfaceTool = _begin()
	var bottom: PackedVector3Array = _outline(G_SOLE - 0.006, 0.0)
	var centre: PackedVector3Array = PackedVector3Array()
	var zc: float = HEEL_Z - LENGTH * 0.5
	for p: Vector3 in bottom:
		centre.append(Vector3(0.0, p.y, zc))
	var rows: Array = [centre, bottom, _outline(G_SOLE, 0.004), _outline(G_SOLE, SOLE_TOP)]
	_grid_into(st, rows, true, _refs(rows, 0.008))
	SkaterParts.part(shoe, "SoleMesh", _done(st), off, m, "shoe_sole")

	st = _begin()
	rows = [_outline(G_SOLE - 0.001, SOLE_TOP - 0.002), _outline(G_FOX, SOLE_TOP), _outline(G_FOX, FOX_TOP - 0.003),
			_outline(G_FOX - 0.0025, FOX_TOP), _outline(-0.002, FOX_TOP)]
	_grid_into(st, rows, true, _refs(rows, 0.012))
	SkaterParts.part(shoe, "FoxingMesh", _done(st), off, m, "shoe_foxing")

	st = _begin()
	rows = [_outline(G_FOX + 0.0007, 0.0215), _outline(G_FOX + 0.0007, 0.0245)]
	_grid_into(st, rows, true, _refs(rows, 0.023))
	SkaterParts.part(shoe, "FoxingLineMesh", _done(st), off, m, "shoe_foxing_line")

	# Waffle hint: short dark lugs round the bottom edge of the outsole.
	st = _begin()
	var ring: PackedVector3Array = _outline(G_SOLE + 0.0006, 0.0)
	var lengths: PackedFloat32Array = PackedFloat32Array([0.0])
	for i: int in ring.size():
		lengths.append(lengths[i] + ring[i].distance_to(ring[(i + 1) % ring.size()]))
	var total: float = lengths[lengths.size() - 1]
	var count: int = int(total / 0.0105)
	for i: int in count:
		var s0: float = total * float(i) / float(count)
		var a: Vector3 = _along(ring, lengths, s0)
		var b: Vector3 = _along(ring, lengths, s0 + 0.0052)
		var up: Vector3 = Vector3(0.0, 0.0052, 0.0)
		var lift: Vector3 = Vector3(0.0, 0.0012, 0.0)
		_quad_into(st, a + lift, b + lift, a + up, b + up, Vector3(0.0, 0.004, clampf(a.z, HEEL_Z - LENGTH + 0.06, HEEL_Z - 0.06)))
	SkaterParts.part(shoe, "SoleTreadMesh", _done(st), off, m, "shoe_tread")

	# "Off the wall" style rubber label on the heel foxing.
	SkaterParts.part(shoe, "HeelLabelMesh", SkaterParts.box(Vector3(0.03, 0.011, 0.003)),
			off + Vector3(0.0, 0.019, HEEL_Z + G_FOX + 0.0006), m, "shoe_tab")


# --- upper: canvas body, suede toe cap, toe bumper, heel counter, eyestays ------------------------------------

static func _upper_parts(shoe: Node3D, off: Vector3, m: Dictionary) -> void:
	var cols: int = 14
	var st: SurfaceTool = _begin()
	var rows: Array = []
	for d: float in _d_samples(0.0):
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols + 1:
			ring.append(_pt(d, lerpf(-PI * 0.5, PI * 0.5, float(k) / float(cols)), 0.0))
		rows.append(ring)
	_grid_into(st, rows, false, _refs(rows, 0.05))
	SkaterParts.part(shoe, "UpperMesh", _done(st), off, m, "shoe_canvas")

	# Toe cap (the ollie zone): suede over the toe box, its back edge a U from the first eyelet down to the foxing.
	var g_cap: float = 0.0022
	st = _begin()
	rows = []
	for i: int in 9:
		var r: float = pow(float(i) / 8.0, 0.85)
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols + 1:
			var phi: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / float(cols))
			ring.append(_pt(lerpf(_cap_edge(phi), LENGTH + g_cap, r), phi, g_cap))
		rows.append(ring)
	_grid_into(st, rows, false, _refs(rows, 0.045))
	SkaterParts.part(shoe, "ToeCapMesh", _done(st), off, m, "shoe_suede")

	# Toe bumper: the white rubber wrap over the front of the toe, its top edge curving up to the tip.
	var g_bump: float = 0.0042
	st = _begin()
	for sgn: float in [-1.0, 1.0]:
		rows = []
		for i: int in 10:
			var d: float = lerpf(LENGTH - 0.07, LENGTH + g_bump, sin(float(i) / 9.0 * PI * 0.5))
			var v: float = 0.003 + 0.016 * smoothstep(LENGTH - 0.07, LENGTH - 0.002, d) + 0.03 * smoothstep(LENGTH - 0.002, LENGTH + g_bump, d)
			var pe: float = _phi_at_v(d, v, g_bump)
			var ring: PackedVector3Array = PackedVector3Array()
			for k: int in 8:
				ring.append(_pt(d, sgn * lerpf(pe, PI * 0.5, float(k) / 7.0), g_bump))
			rows.append(ring)
		_grid_into(st, rows, false, _refs(rows, 0.045))
	SkaterParts.part(shoe, "ToeBumperMesh", _done(st), off, m, "shoe_bumper")

	# Heel counter: suede cup round the heel, its front edge sloping from the collar down to the foxing.
	var g_heel: float = 0.0024
	st = _begin()
	rows = []
	for i: int in 8:
		var r: float = 1.0 - cos(float(i) / 7.0 * PI * 0.5)
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols + 1:
			var phi: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / float(cols))
			var de: float = 0.022 + 0.04 * pow(absf(sin(phi)), 2.0)
			ring.append(_pt(lerpf(-g_heel, de, r), phi, g_heel))
		rows.append(ring)
	_grid_into(st, rows, false, _refs(rows, 0.06))
	SkaterParts.part(shoe, "HeelCounterMesh", _done(st), off, m, "shoe_suede")

	# Eyestays: suede lace panels either side of the tongue, from the collar down to the toe cap.
	var g_eye: float = 0.0026
	st = _begin()
	for sgn: float in [-1.0, 1.0]:
		rows = []
		for i: int in 11:
			var r: float = float(i) / 10.0
			var ring: PackedVector3Array = PackedVector3Array()
			for k: int in 4:
				var x: float = sgn * lerpf(EYESTAY_IN, EYESTAY_OUT, float(k) / 3.0)
				var d_end: float = _cap_edge(_phi_at_x(0.2, x, 0.0)) - 0.0015
				var d: float = lerpf(0.117, d_end, r)
				ring.append(_pt(d, _phi_at_x(d, x, g_eye), g_eye))
			rows.append(ring)
		_grid_into(st, rows, false, _refs(rows, 0.05))
	SkaterParts.part(shoe, "EyestayMesh", _done(st), off, m, "shoe_suede")

	# Double stitch rows: along the toe cap edge and the outer edge of each eyestay.
	st = _begin()
	for gap: float in [0.0035, 0.0068]:
		var steps: int = 22
		for i: int in steps:
			var pa: float = lerpf(-1.42, 1.42, (float(i) + 0.15) / float(steps))
			var pb: float = lerpf(-1.42, 1.42, (float(i) + 0.75) / float(steps))
			_dash_into(st, _cap_edge(pa) + gap, pa, _cap_edge(pb) + gap, pb, g_cap + 0.0009)
	for sgn: float in [-1.0, 1.0]:
		for xe: float in [EYESTAY_OUT - 0.0028, EYESTAY_OUT - 0.006]:
			var x: float = sgn * xe
			var d_end: float = _cap_edge(_phi_at_x(0.2, x, 0.0)) - 0.004
			var steps: int = 13
			for i: int in steps:
				var da: float = lerpf(0.12, d_end, (float(i) + 0.15) / float(steps))
				var db: float = lerpf(0.12, d_end, (float(i) + 0.75) / float(steps))
				_dash_into(st, da, _phi_at_x(da, x, g_eye), db, _phi_at_x(db, x, g_eye), g_eye + 0.0009)
	SkaterParts.part(shoe, "StitchMesh", _done(st), off, m, "shoe_stitch")


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
	var st: SurfaceTool = _begin()
	var spine: PackedVector3Array = PackedVector3Array()
	for t: Array in TONGUE:
		var d: float = float(t[0])
		var y: float = float(t[1])
		if y < 0.1:
			y += _top_y(d, 0.0)
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
	_grid_into(st, rows, true, spine)
	SkaterParts.part(shoe, "TongueMesh", _done(st), off, m, "shoe_tongue")

	# Eyelets: small dark discs on the eyestays.
	var g_eye: float = 0.0026
	st = _begin()
	var holes: Array = [[], []]
	for i: int in EYELETS:
		var d: float = lerpf(EYELET_LOW_D, EYELET_TOP_D, float(i) / float(EYELETS - 1))
		for j: int in 2:
			var x: float = EYELET_X * (-1.0 if j == 0 else 1.0)
			var phi: float = _phi_at_x(d, x, g_eye)
			var p: Vector3 = _pt(d, phi, g_eye + 0.0011)
			var n: Vector3 = (_pt(d, phi, g_eye + 0.01) - _pt(d, phi, g_eye)).normalized()
			var u: Vector3 = Vector3.FORWARD.cross(n).normalized()
			var w: Vector3 = n.cross(u).normalized()
			for k: int in 8:
				var a0: float = TAU * float(k) / 8.0
				var a1: float = TAU * float(k + 1) / 8.0
				_tri_into(st, p, p + (u * cos(a0) + w * sin(a0)) * 0.0034, p + (u * cos(a1) + w * sin(a1)) * 0.0034, p - n * 0.01)
			(holes[j] as Array).append([d, x])
	SkaterParts.part(shoe, "EyeletsMesh", _done(st), off, m, "shoe_eyelet")

	# Flat laces: a bottom bar, then criss-cross pairs arching over the tongue.
	st = _begin()
	var left: Array = holes[0]
	var right: Array = holes[1]
	_lace_into(st, left[0], right[0], 0)
	for i: int in EYELETS - 1:
		_lace_into(st, left[i], right[i + 1], 1)
		_lace_into(st, right[i], left[i + 1], 0)
	var items: Array = [[_done(st), Transform3D.IDENTITY]]
	# Bow at the top: a knot, two flat-ish loops and two tails lying down the laces.
	var kd: float = EYELET_TOP_D - 0.003
	var knot: Vector3 = _over(kd, 0.0, 0.0125)
	items.append([SkaterParts.sphere_small(0.0045), Transform3D(Basis.from_scale(Vector3(1.2, 0.8, 1.0)), knot)])
	for sgn: float in [-1.0, 1.0]:
		var loop: PackedVector3Array = PackedVector3Array([knot, _over(kd + 0.004, sgn * 0.012, 0.0135),
				_over(kd + 0.011, sgn * 0.025, 0.012), _over(kd + 0.006, sgn * 0.031, 0.0105),
				_over(kd - 0.001, sgn * 0.022, 0.0115), knot + Vector3(sgn * 0.003, 0.0, 0.0)])
		loop = SkaterParts.smooth3d(loop, 2)
		var lr: PackedFloat32Array = PackedFloat32Array()
		for i: int in loop.size():
			lr.append(0.0021)
		items.append([SkaterParts.tube(loop, lr, 5), Transform3D.IDENTITY])
		var tail: PackedVector3Array = PackedVector3Array([knot, _over(kd + 0.012, sgn * 0.006, 0.0115),
				_over(kd + 0.026, sgn * 0.011, 0.0098), _over(kd + 0.038, sgn * 0.015, 0.0092)])
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
		path.append(_over(d, x, clear))
	var rows: Array = []
	for i: int in n:
		var tan: Vector3 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var across: Vector3 = tan.cross(Vector3.UP).normalized() * 0.0044
		var up: Vector3 = Vector3(0.0, 0.0008, 0.0)
		rows.append(PackedVector3Array([path[i] + across + up, path[i] - across + up, path[i] - across - up,
				path[i] + across - up]))
	_grid_into(st, rows, true, path)


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
		path.append(_over(d, x, 0.0005 + 0.003 * back))
		radii.append(lerpf(0.0068, 0.0092, back))
	SkaterParts.part(shoe, "CollarMesh", SkaterParts.tube_capped(path, radii, 6), off, m, "shoe_collar")

	# Lining: the dark inside of the shoe, seen round the sock through the opening.
	var st: SurfaceTool = _begin()
	var rows: Array = []
	var refs: PackedVector3Array = PackedVector3Array()
	for j: int in 4:
		var f: float = float(j) / 3.0
		var ring: PackedVector3Array = PackedVector3Array()
		for i: int in 18:
			var a: float = TAU * float(i) / 18.0
			ring.append(_over(OPEN_D - (OPEN_HALF_D - 0.002) * f * cos(a), (OPEN_HALF_X - 0.002) * f * sin(a), 0.0025))
		rows.append(ring)
		refs.append(_over(OPEN_D, 0.0, -0.05))
	_grid_into(st, rows, true, refs)
	SkaterParts.part(shoe, "LiningMesh", _done(st), off, m, "shoe_lining")

	# Heel pull tab standing up from the back of the collar.
	var tab: MeshInstance3D = SkaterParts.part(shoe, "HeelTabMesh", SkaterParts.box(Vector3(0.02, 0.036, 0.0045)),
			off + Vector3(0.0, _top_y(0.0, 0.0) + 0.0005, HEEL_Z + 0.0045), m, "shoe_tab")
	tab.rotation.x = -0.12


# --- jazz stripe: a curved ribbon decal ~1 mm proud of each quarter -------------------------------------------

## Stripe path on the quarter: distance from heel, height above FOX_TOP, half width.
const STRIPE: Array = [
	[0.186, 0.041, 0.0012], [0.162, 0.035, 0.0042], [0.132, 0.027, 0.0064], [0.106, 0.024, 0.0078],
	[0.087, 0.032, 0.0085], [0.077, 0.048, 0.0085], [0.066, 0.047, 0.0082], [0.059, 0.028, 0.0078],
	[0.061, -0.003, 0.0078],
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
			a_row.append(_pt(da, sgn * _phi_at_v(da, va, g), g))
			b_row.append(_pt(db, sgn * _phi_at_v(db, vb, g), g))
		var st: SurfaceTool = _begin()
		_grid_into(st, [a_row, b_row], false, _refs([a_row, b_row], 0.05))
		SkaterParts.part(shoe, "SidePanel" + ("Left" if sgn < 0.0 else "Right") + "Mesh", _done(st), off, m, "shoe_stripe")


# --- shape of the upper -----------------------------------------------------------------------------------------

## Catmull-Rom through PLAN column `col` at distance d from the heel.
static func _plan(d: float, col: int) -> float:
	var n: int = PLAN.size()
	var dd: float = clampf(d, 0.0, float(PLAN[n - 1][0]))
	var i: int = 0
	while i < n - 2 and dd > float(PLAN[i + 1][0]):
		i += 1
	var t: float = (dd - float(PLAN[i][0])) / (float(PLAN[i + 1][0]) - float(PLAN[i][0]))
	var p0: float = float(PLAN[maxi(i - 1, 0)][col])
	var p1: float = float(PLAN[i][col])
	var p2: float = float(PLAN[i + 1][col])
	var p3: float = float(PLAN[mini(i + 2, n - 1)][col])
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


## Half width of the upper at d, grown by g (the heel and toe ends move out by g too).
static func _hw(d: float, g: float) -> float:
	var tt: float = clampf((d - (LENGTH - TOE_R)) / (TOE_R + g), 0.0, 1.0)
	var th: float = clampf((HEEL_R - d) / (HEEL_R + g), 0.0, 1.0)
	return (_plan(d, 1) + g) * pow(1.0 - pow(tt, 2.6), 1.0 / 2.6) * pow(1.0 - pow(th, 2.4), 1.0 / 2.4)


## Height of the upper's section at d above its tucked base (FOX_TOP - TUCK), grown by g.
static func _ht(d: float, g: float) -> float:
	var tv: float = clampf((d - (LENGTH - TOE_V)) / (TOE_V + g), 0.0, 1.0)
	return (_plan(d, 2) + TUCK + g) * pow(1.0 - pow(tv, 2.2), 1.0 / 2.2)


## Toe spring: the front of the shoe lifts ~1 cm.
static func _lift(d: float) -> float:
	return 0.0095 * pow(smoothstep(LENGTH - 0.08, LENGTH + 0.006, d), 1.5)


## Point on the upper's surface (grown by g) at distance d from the heel and section angle phi
## (0 = top centre, +PI/2 = the +X side's base, -PI/2 = the -X side's base).
static func _pt(d: float, phi: float, g: float) -> Vector3:
	var s: float = sin(phi)
	var c: float = cos(phi)
	var x: float = _hw(d, g) * signf(s) * pow(absf(s), EXP)
	var y: float = FOX_TOP - TUCK + _ht(d, g) * pow(absf(c), EXP)
	return Vector3(x, y + _lift(d), HEEL_Z - d)


## Section angle where the surface (grown by g) is at x.
static func _phi_at_x(d: float, x: float, g: float) -> float:
	var r: float = clampf(absf(x) / maxf(_hw(d, g), 0.00001), 0.0, 1.0)
	return signf(x) * asin(pow(r, 1.0 / EXP))


## Section angle (+X side) where the surface (grown by g) is v above FOX_TOP.
static func _phi_at_v(d: float, v: float, g: float) -> float:
	var c: float = clampf((v + TUCK) / maxf(_ht(d, g), 0.00001), 0.0, 1.0)
	return acos(pow(c, 1.0 / EXP))


## y of the upper's top centre at d.
static func _top_y(d: float, g: float) -> float:
	return _pt(d, 0.0, g).y


## Point `clear` above the upper's surface at (d, x).
static func _over(d: float, x: float, clear: float) -> Vector3:
	return _pt(d, _phi_at_x(d, x, 0.0), 0.0) + Vector3(0.0, clear, 0.0)


## Toe cap back edge (distance from heel) at section angle phi: highest on top, sweeping back down the sides.
static func _cap_edge(phi: float) -> float:
	return 0.21 - 0.05 * pow(absf(sin(phi)), 1.6)


## Distances from the heel for the lengthwise rows: dense at the rounded heel and toe.
static func _d_samples(g: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for i: int in 5:
		out.append(lerpf(-g, HEEL_R, 1.0 - cos(float(i) / 5.0 * PI * 0.5)))
	var mid: int = 13
	for i: int in mid:
		out.append(lerpf(HEEL_R, LENGTH - TOE_R, float(i) / float(mid)))
	for i: int in 10:
		out.append(lerpf(LENGTH - TOE_R, LENGTH + g, sin(float(i) / 9.0 * PI * 0.5)))
	return out


## Closed plan outline of the upper's footprint grown by g, at height y (plus toe spring).
static func _outline(g: float, y: float) -> PackedVector3Array:
	var ds: PackedFloat32Array = _d_samples(g)
	var out: PackedVector3Array = PackedVector3Array()
	for d: float in ds:
		out.append(Vector3(_hw(d, g), y + _lift(d), HEEL_Z - d))
	for i: int in range(ds.size() - 2, 0, -1):
		var d: float = ds[i]
		out.append(Vector3(-_hw(d, g), y + _lift(d), HEEL_Z - d))
	return out


static func _along(ring: PackedVector3Array, lengths: PackedFloat32Array, s: float) -> Vector3:
	var total: float = lengths[lengths.size() - 1]
	var ss: float = fposmod(s, total)
	for i: int in ring.size():
		if ss <= lengths[i + 1]:
			var t: float = (ss - lengths[i]) / maxf(lengths[i + 1] - lengths[i], 0.000001)
			return ring[i].lerp(ring[(i + 1) % ring.size()], t)
	return ring[0]


# --- mesh building: every triangle is wound to face away from a reference point inside its part -----------------

static func _begin() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _done(st: SurfaceTool) -> ArrayMesh:
	st.index()
	st.generate_normals()
	return st.commit()


## Per-row reference points inside the shoe at height ref_y, under each row's mean z.
static func _refs(rows: Array, ref_y: float) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for r: PackedVector3Array in rows:
		var z: float = 0.0
		for p: Vector3 in r:
			z += p.z
		z /= float(maxi(r.size(), 1))
		out.append(Vector3(0.0, ref_y, clampf(z, HEEL_Z - LENGTH + 0.05, HEEL_Z - 0.04)))
	return out


static func _grid_into(st: SurfaceTool, rows: Array, closed: bool, refs: PackedVector3Array) -> void:
	for i: int in rows.size() - 1:
		var r0: PackedVector3Array = rows[i]
		var r1: PackedVector3Array = rows[i + 1]
		var ref: Vector3 = (refs[i] + refs[i + 1]) * 0.5
		var cols: int = r0.size() if closed else r0.size() - 1
		for k: int in cols:
			var k2: int = (k + 1) % r0.size()
			_quad_into(st, r0[k], r0[k2], r1[k], r1[k2], ref)


static func _quad_into(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ref: Vector3) -> void:
	_tri_into(st, a, b, c, ref)
	_tri_into(st, b, d, c, ref)


## Adds triangle abc wound so its front (Godot: clockwise) faces away from ref. Skips degenerate triangles.
static func _tri_into(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ref: Vector3) -> void:
	var n: Vector3 = (c - a).cross(b - a)
	if n.length_squared() < 1e-14:
		return
	st.add_vertex(a)
	if n.dot((a + b + c) / 3.0 - ref) >= 0.0:
		st.add_vertex(b)
		st.add_vertex(c)
	else:
		st.add_vertex(c)
		st.add_vertex(b)


## One stitch dash on the surface grown by g, from (da, pa) to (db, pb), 1.2 mm wide.
static func _dash_into(st: SurfaceTool, da: float, pa: float, db: float, pb: float, g: float) -> void:
	var a: Vector3 = _pt(da, pa, g)
	var b: Vector3 = _pt(db, pb, g)
	var n: Vector3 = (_pt(da, pa, g + 0.01) - a).normalized()
	var w: Vector3 = (b - a).cross(n).normalized() * 0.0006
	_quad_into(st, a - w, a + w, b - w, b + w, a - n * 0.01)
