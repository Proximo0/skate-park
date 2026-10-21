class_name ShoeStyles
extends RefCounted
## Three more skate shoe silhouettes for the wardrobe's shoes slot, next to the low vulc (SkateShoe, Vans Old Skool
## style). Each is built from the same ShoeShape maths and the same "shoe_*" colourway keys (SkateShoe.PRESETS), and
## keeps the shoe contract: a "<Side>ShoeMesh" node under the foot joint, ankle at the origin, the sole bottom at
## -ankle_height, toe toward -Z, about the same length as the vulc so the feet stay planted on the deck.
##
## RESEARCH (what makes each one instantly readable)
## - Cupsole, Nike SB Dunk Low: a chunky stitched cupsole (the cup wall is visible, with its stitch line and a seam
##   to the outsole), a leather upper in overlay panels (toe, eyestay, quarter, heel), a big curved side stripe on
##   the quarter (invented: a long wave, not the real logo), a padded collar, a FAT padded tongue with a woven label
##   and 7 eyelets.
## - Puffy, 2000s Osiris / DC / es: everything inflated: a huge pillow tongue and a thick padded collar, a thick sole
##   with a side bumper, a big side logo patch (invented badge), a lace cover strap, layered overlapping panels.
## - High top, Vans Sk8-Hi: the vulc sole, but the canvas goes up over the ankle in a padded collar with a rounded
##   ankle panel, the jazz stripe, and 8 eyelets. The collar must sit outside the leg (and the sock) in every pose,
##   so it hangs on the lower leg joint, like a sock, not on the foot (see build_high_top).
## Colour keys used (all of SkateShoe.PRESETS): canvas = leather/canvas body, suede = overlay panels, stripe = side
## stripe and logo, foxing = sidewall, sole = outsole, tread = seams and lugs, bumper, tab, tongue, collar, lining,
## laces, eyelet, stitch.

const EYELET_X: float = 0.0245

# --- shapes ------------------------------------------------------------------------------------------------------

const CUP_PLAN: Array = [
	[0.0, 0.037, 0.095], [0.03, 0.039, 0.095], [0.08, 0.0425, 0.088], [0.13, 0.0475, 0.073],
	[0.17, 0.0515, 0.057], [0.21, 0.0545, 0.044], [0.25, 0.0535, 0.036], [0.292, 0.0505, 0.032],
]
const PUFF_PLAN: Array = [
	[0.0, 0.041, 0.1], [0.03, 0.043, 0.103], [0.08, 0.0475, 0.098], [0.13, 0.0515, 0.082],
	[0.17, 0.0555, 0.064], [0.21, 0.0585, 0.05], [0.25, 0.0585, 0.042], [0.285, 0.0555, 0.038],
]
const HI_PLAN: Array = [
	[0.0, 0.036, 0.1], [0.03, 0.038, 0.1], [0.08, 0.041, 0.092], [0.13, 0.0455, 0.073],
	[0.17, 0.0495, 0.055], [0.21, 0.0525, 0.042], [0.25, 0.0515, 0.034], [0.3, 0.049, 0.031],
]


static func cup_shape() -> ShoeShape:
	var sh: ShoeShape = ShoeShape.new()
	sh.length = 0.292
	sh.fox_top = 0.042
	sh.g_sole = 0.0075
	sh.g_fox = 0.0058
	sh.spring = 0.008
	sh.plan = CUP_PLAN
	sh.exp_heel = 0.4
	sh.cap_back = 0.205
	sh.cap_sweep = 0.045
	return sh


static func puff_shape() -> ShoeShape:
	var sh: ShoeShape = ShoeShape.new()
	sh.length = 0.285
	sh.fox_top = 0.044
	sh.tuck = 0.008
	sh.g_sole = 0.0105
	sh.g_fox = 0.0085
	sh.toe_r = 0.062
	sh.toe_v = 0.046
	sh.heel_r = 0.034
	sh.spring = 0.01
	sh.plan = PUFF_PLAN
	sh.exp_heel = 0.42
	sh.cap_back = 0.198
	sh.cap_sweep = 0.04
	return sh


static func hi_shape() -> ShoeShape:
	var sh: ShoeShape = ShoeShape.new()
	sh.length = 0.3
	sh.plan = HI_PLAN
	sh.exp_heel = 0.4
	return sh


# --- shared pieces -----------------------------------------------------------------------------------------------

## Canvas/leather body of the upper.
static func _upper(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape, key: String = "shoe_canvas", cols: int = 14) -> void:
	var st: SurfaceTool = ShoeKit.begin()
	var rows: Array = []
	for d: float in sh.d_samples(0.0):
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols + 1:
			ring.append(sh.pt(d, lerpf(-PI * 0.5, PI * 0.5, float(k) / float(cols)), 0.0))
		rows.append(ring)
	ShoeKit.grid_into(st, rows, false, sh.refs(rows, 0.05))
	SkaterParts.part(shoe, "UpperMesh", ShoeKit.done(st), off, m, key)


## Toe overlay: from the tip back to the cap edge. `tip_extra` stretches the front end past the upper.
static func _toe_cap(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape, g: float, key: String, part_name: String = "ToeCapMesh") -> void:
	var st: SurfaceTool = ShoeKit.begin()
	var rows: Array = []
	for i: int in 9:
		var r: float = pow(float(i) / 8.0, 0.85)
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in 15:
			var phi: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / 14.0)
			ring.append(sh.pt(lerpf(sh.cap_edge(phi), sh.length + g, r), phi, g))
		rows.append(ring)
	ShoeKit.grid_into(st, rows, false, sh.refs(rows, 0.045))
	SkaterParts.part(shoe, part_name, ShoeKit.done(st), off, m, key)


## Rubber wrap over the front of the toe, its top edge curving up to the tip (`reach` back from the tip, `high` at
## the tip), as on the vulc.
static func _toe_bumper(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape, g: float, reach: float, low: float, high: float,
		key: String = "shoe_bumper") -> void:
	var st: SurfaceTool = ShoeKit.begin()
	for sgn: float in [-1.0, 1.0]:
		var rows: Array = []
		for i: int in 8:
			var d: float = lerpf(sh.length - reach, sh.length + g, sin(float(i) / 7.0 * PI * 0.5))
			var v: float = low + 0.016 * smoothstep(sh.length - reach, sh.length - 0.002, d) + high * smoothstep(sh.length - 0.002, sh.length + g, d)
			var pe: float = sh.phi_at_v(d, v, g)
			var ring: PackedVector3Array = PackedVector3Array()
			for k: int in 8:
				ring.append(sh.pt(d, sgn * lerpf(pe, PI * 0.5, float(k) / 7.0), g))
			rows.append(ring)
		ShoeKit.grid_into(st, rows, false, sh.refs(rows, 0.045))
	SkaterParts.part(shoe, "ToeBumperMesh", ShoeKit.done(st), off, m, key)


## Suede lace panels either side of the tongue, from d_top down to the toe cap.
static func _eyestays(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape, d_top: float, x_in: float, x_out: float,
		g: float, key: String, part_name: String = "EyestayMesh") -> void:
	var st: SurfaceTool = ShoeKit.begin()
	for sgn: float in [-1.0, 1.0]:
		var rows: Array = []
		for i: int in 11:
			var r: float = float(i) / 10.0
			var ring: PackedVector3Array = PackedVector3Array()
			for k: int in 4:
				var x: float = sgn * lerpf(x_in, x_out, float(k) / 3.0)
				var d_end: float = sh.cap_edge(sh.phi_at_x(0.2, x, 0.0)) - 0.0015
				var d: float = lerpf(d_top, d_end, r)
				ring.append(sh.pt(d, sh.phi_at_x(d, x, g), g))
			rows.append(ring)
		ShoeKit.grid_into(st, rows, false, sh.refs(rows, 0.05))
	SkaterParts.part(shoe, part_name, ShoeKit.done(st), off, m, key)


## Heel counter: a cup round the heel whose front edge slopes from d_top (at the collar) to d_base (at the sole).
static func _heel_cup(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape, g: float, d_top: float, d_base: float,
		key: String, part_name: String = "HeelCounterMesh") -> void:
	var st: SurfaceTool = ShoeKit.begin()
	var rows: Array = []
	for i: int in 8:
		var r: float = 1.0 - cos(float(i) / 7.0 * PI * 0.5)
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in 15:
			var phi: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / 14.0)
			var de: float = d_top + (d_base - d_top) * pow(absf(sin(phi)), 2.0)
			ring.append(sh.pt(lerpf(-g, de, r), phi, g))
		rows.append(ring)
	ShoeKit.grid_into(st, rows, false, sh.refs(rows, 0.06))
	SkaterParts.part(shoe, part_name, ShoeKit.done(st), off, m, key)


## Panel on both sides of the upper. Columns run from the top edge (x = x_top on the upper) down to v_base above the
## sole stack; rows run from the back edge to the front edge, both edges given at the top and at the base.
static func _side_panel(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape, part_name: String, key: String, g: float,
		x_top: float, v_base: float, back: Vector2, front: Vector2, nr: int = 9, nu: int = 5) -> void:
	var st: SurfaceTool = ShoeKit.begin()
	for sgn: float in [-1.0, 1.0]:
		var rows: Array = []
		for i: int in nr:
			var r: float = float(i) / float(nr - 1)
			var ring: PackedVector3Array = PackedVector3Array()
			for k: int in nu:
				var u: float = float(k) / float(nu - 1)
				var d: float = lerpf(lerpf(back.x, back.y, u), lerpf(front.x, front.y, u), r)
				var phi: float = lerpf(sh.phi_at_x(d, x_top, g), sh.phi_at_v(d, v_base, g), u)
				ring.append(sh.pt(d, sgn * phi, g))
			rows.append(ring)
		ShoeKit.grid_into(st, rows, false, sh.refs(rows, 0.05))
	SkaterParts.part(shoe, part_name, ShoeKit.done(st), off, m, key)


## Dashes along a polyline given by f(t) -> Vector2(d, phi), t in 0..1, on the surface grown by g.
static func _dashes(sh: ShoeShape, st: SurfaceTool, f: Callable, steps: int, g: float) -> void:
	for i: int in steps:
		var a: Vector2 = f.call((float(i) + 0.15) / float(steps))
		var b: Vector2 = f.call((float(i) + 0.75) / float(steps))
		sh.dash(st, a.x, a.y, b.x, b.y, g)


## A ribbon decal on the side of the upper: path rows of [d, v above fox_top, half width], ~1 mm proud.
static func _side_ribbon(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape, part_base: String, key: String,
		path: Array, g: float, sub: int = 4) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	for s: Array in path:
		pts.append(Vector3(float(s[0]), float(s[1]), float(s[2])))
	pts = SkaterParts.smooth3d(pts, sub)
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
			a_row.append(sh.pt(da, sgn * sh.phi_at_v(da, va, g), g))
			b_row.append(sh.pt(db, sgn * sh.phi_at_v(db, vb, g), g))
		var st: SurfaceTool = ShoeKit.begin()
		ShoeKit.grid_into(st, [a_row, b_row], false, sh.refs([a_row, b_row], 0.05))
		SkaterParts.part(shoe, part_base + ("Left" if sgn < 0.0 else "Right") + "Mesh", ShoeKit.done(st), off, m, key)


## Eyelets (dark rings) at x = +-EYELET_X from d_low to d_top; returns the hole positions [[d, x], ...] per side.
static func _eyelets(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape, count: int, d_low: float, d_top: float,
		g: float, r: float = 0.0034, ex: float = EYELET_X) -> Array:
	var st: SurfaceTool = ShoeKit.begin()
	var holes: Array = [[], []]
	for i: int in count:
		var d: float = lerpf(d_low, d_top, float(i) / float(count - 1))
		for j: int in 2:
			var x: float = ex * (-1.0 if j == 0 else 1.0)
			var phi: float = sh.phi_at_x(d, x, g)
			var p: Vector3 = sh.pt(d, phi, g + 0.0011)
			var n: Vector3 = (sh.pt(d, phi, g + 0.01) - sh.pt(d, phi, g)).normalized()
			var u: Vector3 = Vector3.FORWARD.cross(n).normalized()
			var w: Vector3 = n.cross(u).normalized()
			for k: int in 8:
				var a0: float = TAU * float(k) / 8.0
				var a1: float = TAU * float(k + 1) / 8.0
				ShoeKit.tri_into(st, p, p + (u * cos(a0) + w * sin(a0)) * r, p + (u * cos(a1) + w * sin(a1)) * r, p - n * 0.01)
			(holes[j] as Array).append([d, x])
	SkaterParts.part(shoe, "EyeletsMesh", ShoeKit.done(st), off, m, "shoe_eyelet")
	return holes


## Padded tongue lofted along `spine` rows [d, height above the upper's top (or absolute y when > 0.1), half thickness,
## half width].
static func _tongue(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape, spine_rows: Array) -> void:
	var st: SurfaceTool = ShoeKit.begin()
	var spine: PackedVector3Array = PackedVector3Array()
	for t: Array in spine_rows:
		var d: float = float(t[0])
		var y: float = float(t[1])
		if y < 0.1:
			y += sh.top_y(d, 0.0)
		spine.append(Vector3(0.0, y, sh.heel_z - d))
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
			ring.append(spine[i] + Vector3.RIGHT * float(spine_rows[i][3]) * signf(s) * pow(absf(s), 0.6)
					+ nrm * float(spine_rows[i][2]) * signf(c) * pow(absf(c), 0.6))
		rows.append(ring)
	ShoeKit.grid_into(st, rows, true, spine)
	SkaterParts.part(shoe, "TongueMesh", ShoeKit.done(st), off, m, "shoe_tongue")


## Height of the tongue's top face above the upper's top at d (the first four spine rows are the lace-covered part).
static func _tongue_face(spine_rows: Array, d: float) -> float:
	for i: int in 3:
		var a: Array = spine_rows[i]
		var b: Array = spine_rows[i + 1]
		if d >= float(b[0]):
			var t: float = clampf((d - float(b[0])) / (float(a[0]) - float(b[0])), 0.0, 1.0)
			return lerpf(float(b[1]) + float(b[2]), float(a[1]) + float(a[2]), t)
	return float(spine_rows[3][1]) + float(spine_rows[3][2])


## Flat criss-cross laces over the holes, a bottom bar and a bow above the top pair.
static func _laces(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape, holes: Array, spine_rows: Array, bow_d: float,
		bow_h: float = 0.0125, width: float = 0.0044) -> void:
	var st: SurfaceTool = ShoeKit.begin()
	var left: Array = holes[0]
	var right: Array = holes[1]
	_lace_into(st, sh, spine_rows, left[0], right[0], 0, width)
	for i: int in left.size() - 1:
		_lace_into(st, sh, spine_rows, left[i], right[i + 1], 1, width)
		_lace_into(st, sh, spine_rows, right[i], left[i + 1], 0, width)
	var items: Array = [[ShoeKit.done(st), Transform3D.IDENTITY]]
	if bow_d > 0.0:
		var kd: float = bow_d
		var knot: Vector3 = sh.over(kd, 0.0, bow_h)
		items.append([_knot_mesh(0.0045), Transform3D(Basis.from_scale(Vector3(1.2, 0.8, 1.0)), knot)])
		for sgn: float in [-1.0, 1.0]:
			var loop: PackedVector3Array = PackedVector3Array([knot, sh.over(kd + 0.004, sgn * 0.012, bow_h + 0.001),
					sh.over(kd + 0.011, sgn * 0.025, bow_h - 0.0005), sh.over(kd + 0.006, sgn * 0.031, bow_h - 0.002),
					sh.over(kd - 0.001, sgn * 0.022, bow_h - 0.001), knot + Vector3(sgn * 0.003, 0.0, 0.0)])
			items.append([SkaterParts.tube(loop, PackedFloat32Array([0.0021, 0.0021, 0.0021, 0.0021, 0.0021, 0.0021]), 4),
					Transform3D.IDENTITY])
			var tail: PackedVector3Array = PackedVector3Array([knot, sh.over(kd + 0.012, sgn * 0.006, bow_h - 0.001),
					sh.over(kd + 0.026, sgn * 0.011, bow_h - 0.0027), sh.over(kd + 0.038, sgn * 0.015, bow_h - 0.0033)])
			items.append([SkaterParts.tube(tail, PackedFloat32Array([0.0022, 0.0022, 0.0021, 0.002]), 4), Transform3D.IDENTITY])
	SkaterParts.part(shoe, "LacesMesh", ShoeKit.merge(items), off, m, "shoe_laces")


## A small low-poly knot.
static func _knot_mesh(r: float) -> SphereMesh:
	var sp: SphereMesh = SphereMesh.new()
	sp.radius = r
	sp.height = r * 2.0
	sp.radial_segments = 6
	sp.rings = 3
	return sp


static func _lace_into(st: SurfaceTool, sh: ShoeShape, spine_rows: Array, a: Array, b: Array, layer: int, width: float) -> void:
	var path: PackedVector3Array = PackedVector3Array()
	var n: int = 5
	for i: int in n:
		var t: float = float(i) / float(n - 1)
		var d: float = lerpf(float(a[0]), float(b[0]), t)
		var x: float = lerpf(float(a[1]), float(b[1]), t)
		var arch: float = pow(sin(PI * t), 0.6)
		var clear: float = 0.0034 + (_tongue_face(spine_rows, d) + 0.0018 - 0.0034) * arch + 0.0013 * float(layer) * arch
		path.append(sh.over(d, x, clear))
	var rows: Array = []
	for i: int in n:
		var tan: Vector3 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var across: Vector3 = tan.cross(Vector3.UP).normalized() * width
		var up: Vector3 = Vector3(0.0, 0.0008, 0.0)
		rows.append(PackedVector3Array([path[i] + across + up, path[i] - across + up, path[i] - across - up,
				path[i] + across - up]))
	ShoeKit.grid_into(st, rows, true, path)


## Padded collar roll round the ankle opening (centre d, half length hd, half width hx) with a dark lining inside.
## `r` is the tube radius at the front and `r_back` at the back; `lift` is how high the roll's centre sits above the
## upper (more at the back).
static func _collar(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape, open_d: float, hd: float, hx: float,
		r: float, r_back: float, lift: float, lift_back: float, part_name: String = "CollarMesh") -> void:
	var path: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var n: int = 23
	for i: int in n:
		var psi: float = lerpf(-0.8 * PI, 0.8 * PI, float(i) / float(n - 1))
		var d: float = open_d - hd * cos(psi)
		var x: float = hx * sin(psi)
		var back: float = 1.0 - smoothstep(open_d - hd, open_d + hd * 0.9, d)
		path.append(sh.over(d, x, lerpf(lift, lift_back, back)))
		radii.append(lerpf(r, r_back, back))
	SkaterParts.part(shoe, part_name, SkaterParts.tube_capped(path, radii, 7), off, m, "shoe_collar")
	var st: SurfaceTool = ShoeKit.begin()
	var rows: Array = []
	var refs: PackedVector3Array = PackedVector3Array()
	for j: int in 4:
		var f: float = float(j) / 3.0
		var ring: PackedVector3Array = PackedVector3Array()
		for i: int in 18:
			var a: float = TAU * float(i) / 18.0
			ring.append(sh.over(open_d - (hd - 0.002) * f * cos(a), (hx - 0.002) * f * sin(a), lift - 0.0005))
		rows.append(ring)
		refs.append(sh.over(open_d, 0.0, -0.05))
	ShoeKit.grid_into(st, rows, true, refs)
	SkaterParts.part(shoe, "LiningMesh", ShoeKit.done(st), off, m, "shoe_lining")


## Short lugs round the bottom edge of the outsole.
static func _lugs(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape, g: float, pitch: float, size: float, high: float) -> void:
	var st: SurfaceTool = ShoeKit.begin()
	var ring: PackedVector3Array = sh.outline(g, 0.0)
	var lengths: PackedFloat32Array = ShoeKit.ring_lengths(ring)
	var total: float = lengths[lengths.size() - 1]
	var count: int = int(total / pitch)
	for i: int in count:
		var s0: float = total * float(i) / float(count)
		var a: Vector3 = ShoeKit.along(ring, lengths, s0)
		var b: Vector3 = ShoeKit.along(ring, lengths, s0 + size)
		var lift: Vector3 = Vector3(0.0, 0.0012, 0.0)
		ShoeKit.quad_into(st, a + lift, b + lift, a + Vector3(0.0, high, 0.0), b + Vector3(0.0, high, 0.0),
				Vector3(0.0, 0.004, clampf(a.z, sh.heel_z - sh.length + 0.06, sh.heel_z - 0.06)))
	SkaterParts.part(shoe, "SoleTreadMesh", ShoeKit.done(st), off, m, "shoe_tread")


## Dashes round a closed outline ring (a stitch line round the sidewall).
static func _ring_dashes(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape, part_name: String, g: float, y: float,
		pitch: float, size: float, high: float, key: String) -> void:
	var st: SurfaceTool = ShoeKit.begin()
	var ring: PackedVector3Array = sh.outline(g, y)
	var lengths: PackedFloat32Array = ShoeKit.ring_lengths(ring)
	var total: float = lengths[lengths.size() - 1]
	var count: int = int(total / pitch)
	for i: int in count:
		var s0: float = total * float(i) / float(count)
		var a: Vector3 = ShoeKit.along(ring, lengths, s0)
		var b: Vector3 = ShoeKit.along(ring, lengths, s0 + size)
		var up: Vector3 = Vector3(0.0, high, 0.0)
		ShoeKit.quad_into(st, a, b, a + up, b + up, Vector3(0.0, y, clampf(a.z, sh.heel_z - sh.length + 0.06, sh.heel_z - 0.06)))
	SkaterParts.part(shoe, part_name, ShoeKit.done(st), off, m, key)


## A flat round dot on the upper (perforation) of radius r at (d, x), sunk into the leather colour of its patch.
static func _dot_into(st: SurfaceTool, sh: ShoeShape, d: float, x: float, g: float, r: float) -> void:
	var phi: float = sh.phi_at_x(d, x, g)
	var p: Vector3 = sh.pt(d, phi, g + 0.0006)
	var n: Vector3 = (sh.pt(d, phi, g + 0.01) - sh.pt(d, phi, g)).normalized()
	var u: Vector3 = Vector3.FORWARD.cross(n).normalized()
	var w: Vector3 = n.cross(u).normalized()
	for k: int in 5:
		var a0: float = TAU * float(k) / 5.0
		var a1: float = TAU * float(k + 1) / 5.0
		ShoeKit.tri_into(st, p, p + (u * cos(a0) + w * sin(a0)) * r, p + (u * cos(a1) + w * sin(a1)) * r, p - n * 0.01)


# --- cupsole: Nike SB Dunk Low style -----------------------------------------------------------------------------

const CUP_TONGUE: Array = [
	[0.205, 0.0012, 0.0012, 0.0135], [0.18, 0.0025, 0.0025, 0.0165], [0.155, 0.0045, 0.0045, 0.0185],
	[0.142, 0.011, 0.0095, 0.0235], [0.134, 0.131, 0.0135, 0.031], [0.1305, 0.15, 0.0135, 0.0325],
	[0.129, 0.159, 0.0095, 0.029], [0.1285, 0.1635, 0.0035, 0.019],
]
## Swoosh-like stripe on the quarter: distance from heel, height above fox_top, half width. A long wave with a fat
## blunt back end, a belly low on the quarter and a thin tail sweeping up toward the laces (invented, not the logo).
const CUP_WAVE: Array = [
	[0.064, 0.058, 0.0062], [0.076, 0.042, 0.0088], [0.094, 0.026, 0.0098], [0.116, 0.0185, 0.0086],
	[0.142, 0.0235, 0.0058], [0.166, 0.037, 0.0032], [0.18, 0.05, 0.0012],
]


static func build_cupsole(foot: Node3D, side: String, ankle_height: float, mats: Dictionary, colourway: Dictionary = {}) -> Node3D:
	var m: Dictionary = ShoeKit.materials(mats, colourway)
	var sh: ShoeShape = cup_shape()
	var shoe: Node3D = SkaterParts.joint(foot, side + "ShoeMesh", Vector3.ZERO)
	var off: Vector3 = Vector3(0.0, -ankle_height, 0.0)
	_cup_sole(shoe, off, m, sh)
	_upper(shoe, off, m, sh)
	_cup_panels(shoe, off, m, sh)
	_toe_bumper(shoe, off, m, sh, 0.0042, 0.045, 0.0025, 0.016)
	var holes: Array = _eyelets(shoe, off, m, sh, 7, 0.205, 0.147, 0.0026)
	_tongue(shoe, off, m, sh, CUP_TONGUE)
	_laces(shoe, off, m, sh, holes, CUP_TONGUE, 0.144)
	_collar(shoe, off, m, sh, 0.0775, 0.0495, 0.0385, 0.0092, 0.0115, 0.0004, 0.0025)
	var tab: MeshInstance3D = SkaterParts.part(shoe, "HeelTabMesh", SkaterParts.box(Vector3(0.016, 0.026, 0.0042)),
			off + Vector3(0.0, sh.top_y(0.0, 0.0) - 0.004, sh.heel_z + 0.0045), m, "shoe_tab")
	tab.rotation.x = -0.12
	_cup_label(shoe, off, m, sh)
	return shoe


static func _cup_sole(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape) -> void:
	var gs: float = sh.g_sole
	var st: SurfaceTool = ShoeKit.begin()
	var rows: Array = [sh.outline(gs - 0.0065, 0.0), sh.outline(gs - 0.0005, 0.005), sh.outline(gs, 0.0112)]
	ShoeKit.grid_into(st, rows, true, sh.refs(rows, 0.008))
	SkaterParts.part(shoe, "SoleMesh", ShoeKit.done(st), off, m, "shoe_sole")

	# Cup sidewall: a fat convex wall, a little proud of the upper, rolling in under the upper at the top.
	st = ShoeKit.begin()
	rows = [sh.outline(gs - 0.0008, 0.0108), sh.outline(gs + 0.0009, 0.0215), sh.outline(sh.g_fox + 0.0008, sh.fox_top - 0.004),
			sh.outline(sh.g_fox - 0.0025, sh.fox_top)]
	ShoeKit.grid_into(st, rows, true, sh.refs(rows, 0.016))
	SkaterParts.part(shoe, "FoxingMesh", ShoeKit.done(st), off, m, "shoe_foxing")

	# The seam between outsole and cup, and the stitch line round the middle of the wall.
	st = ShoeKit.begin()
	rows = [sh.outline(gs + 0.0009, 0.0106), sh.outline(gs + 0.0009, 0.0126)]
	ShoeKit.grid_into(st, rows, true, sh.refs(rows, 0.011))
	SkaterParts.part(shoe, "FoxingLineMesh", ShoeKit.done(st), off, m, "shoe_suede")
	_ring_dashes(shoe, off, m, sh, "SoleStitchMesh", gs + 0.0019, 0.0235, 0.0115, 0.0062, 0.0017, "shoe_suede")
	_lugs(shoe, off, m, sh, gs + 0.0006, 0.015, 0.0075, 0.0046)


static func _cup_panels(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape) -> void:
	var g_cap: float = 0.0022
	_toe_cap(shoe, off, m, sh, g_cap, "shoe_suede")
	_eyestays(shoe, off, m, sh, 0.118, 0.0145, 0.0365, 0.0026, "shoe_suede")
	_heel_cup(shoe, off, m, sh, 0.0024, 0.026, 0.066, "shoe_suede")
	# Quarter overlay (carries the stripe): between the heel cup, the eyestay and the toe cap.
	_side_panel(shoe, off, m, sh, "QuarterMesh", "shoe_suede", 0.0021, 0.0375, 0.003, Vector2(0.074, 0.07), Vector2(0.172, 0.152))
	_side_ribbon(shoe, off, m, sh, "WaveStripe", "shoe_stripe", CUP_WAVE, 0.0036)
	# Stitching: double rows on the toe cap and the eyestay edge, one row round the quarter and the heel cup.
	var st: SurfaceTool = ShoeKit.begin()
	for gap: float in [0.0035, 0.0068]:
		var f_cap: Callable = func(t: float) -> Vector2:
			var pa: float = lerpf(-1.42, 1.42, t)
			return Vector2(sh.cap_edge(pa) + gap, pa)
		_dashes(sh, st, f_cap, 22, g_cap + 0.0009)
	for sgn: float in [-1.0, 1.0]:
		for xe: float in [0.0365 - 0.0028, 0.0365 - 0.006]:
			var x: float = sgn * xe
			var d_end: float = sh.cap_edge(sh.phi_at_x(0.2, x, 0.0)) - 0.004
			var f_eye: Callable = func(t: float) -> Vector2:
				var d: float = lerpf(0.121, d_end, t)
				return Vector2(d, sh.phi_at_x(d, x, 0.0026))
			_dashes(sh, st, f_eye, 13, 0.0026 + 0.0009)
		var f_q: Callable = func(t: float) -> Vector2:
			var d: float = lerpf(0.0765, 0.0725, t)
			return Vector2(d, sgn * lerpf(sh.phi_at_x(d, 0.0355, 0.0021), sh.phi_at_v(d, 0.0045, 0.0021), t))
		_dashes(sh, st, f_q, 8, 0.0021 + 0.0009)
	SkaterParts.part(shoe, "StitchMesh", ShoeKit.done(st), off, m, "shoe_stitch")
	# Perforations on the toe box.
	st = ShoeKit.begin()
	var ds: Array = [0.232, 0.2455, 0.259, 0.2725]
	var counts: Array = [5, 6, 5, 4]
	for i: int in ds.size():
		for k: int in int(counts[i]):
			var x: float = (float(k) - float(int(counts[i]) - 1) * 0.5) * 0.0098
			_dot_into(st, sh, float(ds[i]), x, g_cap + 0.0003, 0.0017)
	SkaterParts.part(shoe, "PerforationMesh", ShoeKit.done(st), off, m, "shoe_lining")


## Woven tongue label on the front of the tongue's top.
static func _cup_label(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape) -> void:
	var z: float = sh.heel_z - 0.1305 - 0.0135 - 0.0005
	var plate: MeshInstance3D = SkaterParts.part(shoe, "TongueLabelMesh", SkaterParts.box(Vector3(0.026, 0.0165, 0.0016)),
			off + Vector3(0.0, 0.1525, z), m, "shoe_tab")
	plate.rotation.x = -0.2
	var mark: MeshInstance3D = SkaterParts.part(shoe, "TongueMarkMesh", SkaterParts.box(Vector3(0.015, 0.0045, 0.0016)),
			off + Vector3(0.0, 0.1525, z - 0.0007), m, "shoe_foxing")
	mark.rotation.x = -0.2


# --- puffy: 2000s Osiris / DC / es style ---------------------------------------------------------------------------

const PUFF_TONGUE: Array = [
	[0.205, 0.0015, 0.0015, 0.0155], [0.18, 0.003, 0.003, 0.02], [0.155, 0.0055, 0.0055, 0.0245],
	[0.143, 0.014, 0.011, 0.031], [0.131, 0.15, 0.0195, 0.044], [0.1275, 0.17, 0.021, 0.047],
	[0.126, 0.187, 0.015, 0.041], [0.1255, 0.196, 0.005, 0.027],
]


static func build_puffy(foot: Node3D, side: String, ankle_height: float, mats: Dictionary, colourway: Dictionary = {}) -> Node3D:
	var m: Dictionary = ShoeKit.materials(mats, colourway)
	var sh: ShoeShape = puff_shape()
	var shoe: Node3D = SkaterParts.joint(foot, side + "ShoeMesh", Vector3.ZERO)
	var off: Vector3 = Vector3(0.0, -ankle_height, 0.0)
	_puff_sole(shoe, off, m, sh)
	_upper(shoe, off, m, sh)
	_puff_panels(shoe, off, m, sh)
	_toe_bumper(shoe, off, m, sh, 0.0062, 0.06, 0.004, 0.026)
	var holes: Array = _eyelets(shoe, off, m, sh, 6, 0.2, 0.143, 0.0032, 0.0038, 0.0285)
	_tongue(shoe, off, m, sh, PUFF_TONGUE)
	_laces(shoe, off, m, sh, holes, PUFF_TONGUE, 0.142, 0.0155, 0.0049)
	_lace_cover(shoe, off, m, sh)
	_collar(shoe, off, m, sh, 0.0805, 0.0575, 0.0465, 0.0158, 0.0185, 0.003, 0.006)
	_puff_badges(shoe, off, m, sh)
	var tab: MeshInstance3D = SkaterParts.part(shoe, "HeelTabMesh", SkaterParts.box(Vector3(0.022, 0.032, 0.0055)),
			off + Vector3(0.0, sh.top_y(0.0, 0.0) + 0.006, sh.heel_z + 0.0075), m, "shoe_tab")
	tab.rotation.x = -0.12
	return shoe


static func _puff_sole(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape) -> void:
	var gs: float = sh.g_sole
	var st: SurfaceTool = ShoeKit.begin()
	var rows: Array = [sh.outline(gs - 0.008, 0.0), sh.outline(gs - 0.0008, 0.005), sh.outline(gs, 0.0118)]
	ShoeKit.grid_into(st, rows, true, sh.refs(rows, 0.008))
	SkaterParts.part(shoe, "SoleMesh", ShoeKit.done(st), off, m, "shoe_sole")

	# Thick foam midsole, convex, rolling in under the upper.
	st = ShoeKit.begin()
	rows = [sh.outline(gs - 0.001, 0.0115), sh.outline(gs + 0.0012, 0.022), sh.outline(gs + 0.0012, 0.034),
			sh.outline(sh.g_fox + 0.0008, sh.fox_top - 0.004), sh.outline(sh.g_fox - 0.003, sh.fox_top)]
	ShoeKit.grid_into(st, rows, true, sh.refs(rows, 0.022))
	SkaterParts.part(shoe, "FoxingMesh", ShoeKit.done(st), off, m, "shoe_foxing")

	# Side bumper: a chunky rubber band round the top of the midsole, split by ribs.
	st = ShoeKit.begin()
	var gb: float = gs + 0.0042
	rows = [sh.outline(gb - 0.0025, 0.0235), sh.outline(gb + 0.0006, 0.0335), sh.outline(gb - 0.0025, 0.0435)]
	ShoeKit.grid_into(st, rows, true, sh.refs(rows, 0.034))
	SkaterParts.part(shoe, "BumperMesh", ShoeKit.done(st), off, m, "shoe_collar")
	var ring: PackedVector3Array = sh.outline(gb + 0.0006, 0.027)
	var lengths: PackedFloat32Array = ShoeKit.ring_lengths(ring)
	var total: float = lengths[lengths.size() - 1]
	var count: int = int(total / 0.034)
	st = ShoeKit.begin()
	for i: int in count:
		var s0: float = total * float(i) / float(count)
		var a: Vector3 = ShoeKit.along(ring, lengths, s0)
		var b: Vector3 = ShoeKit.along(ring, lengths, s0 + 0.0036)
		var up: Vector3 = Vector3(0.0, 0.0105, 0.0)
		ShoeKit.quad_into(st, a, b, a + up, b + up, Vector3(0.0, 0.034, clampf(a.z, sh.heel_z - sh.length + 0.06, sh.heel_z - 0.06)))
	SkaterParts.part(shoe, "BumperRibsMesh", ShoeKit.done(st), off, m, "shoe_foxing")

	# A bright piping line round the top of the bumper, and sole lugs.
	st = ShoeKit.begin()
	rows = [sh.outline(gb - 0.0006, 0.0395), sh.outline(gb - 0.0006, 0.0412)]
	ShoeKit.grid_into(st, rows, true, sh.refs(rows, 0.04))
	SkaterParts.part(shoe, "FoxingLineMesh", ShoeKit.done(st), off, m, "shoe_foxing_line")
	_lugs(shoe, off, m, sh, gs + 0.0006, 0.016, 0.0085, 0.0052)


static func _puff_panels(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape) -> void:
	var g_cap: float = 0.0026
	_toe_cap(shoe, off, m, sh, g_cap, "shoe_suede")
	_eyestays(shoe, off, m, sh, 0.118, 0.0125, 0.0435, 0.003, "shoe_suede")
	# Layered quarter panels: a long low one under, a taller one on top, and the heel cup over both.
	_side_panel(shoe, off, m, sh, "QuarterMesh", "shoe_suede", 0.0022, 0.0445, 0.004, Vector2(0.06, 0.056), Vector2(0.178, 0.152))
	_side_panel(shoe, off, m, sh, "QuarterTopMesh", "shoe_canvas", 0.0034, 0.0455, 0.016, Vector2(0.074, 0.078), Vector2(0.158, 0.138), 7, 4)
	_heel_cup(shoe, off, m, sh, 0.0042, 0.02, 0.07, "shoe_suede")
	var st: SurfaceTool = ShoeKit.begin()
	for gap: float in [0.0035, 0.0068]:
		var f_cap: Callable = func(t: float) -> Vector2:
			var pa: float = lerpf(-1.42, 1.42, t)
			return Vector2(sh.cap_edge(pa) + gap, pa)
		_dashes(sh, st, f_cap, 22, g_cap + 0.0009)
	for sgn: float in [-1.0, 1.0]:
		var x: float = sgn * 0.0405
		var d_end: float = sh.cap_edge(sh.phi_at_x(0.2, x, 0.0)) - 0.004
		var f_eye: Callable = func(t: float) -> Vector2:
			var d: float = lerpf(0.121, d_end, t)
			return Vector2(d, sh.phi_at_x(d, x, 0.003))
		_dashes(sh, st, f_eye, 13, 0.003 + 0.0009)
		var f_h: Callable = func(t: float) -> Vector2:
			var d: float = lerpf(0.0215, 0.0715, t * t)
			return Vector2(d, sgn * lerpf(sh.phi_at_x(d, 0.04, 0.0042), sh.phi_at_v(d, 0.006, 0.0042), t))
		_dashes(sh, st, f_h, 11, 0.0042 + 0.0009)
	SkaterParts.part(shoe, "StitchMesh", ShoeKit.done(st), off, m, "shoe_stitch")


## Lace cover: a wide strap over the laces with a buckle plate and a lace loop above it.
static func _lace_cover(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape) -> void:
	var d0: float = 0.171
	var rows: Array = []
	var st: SurfaceTool = ShoeKit.begin()
	var refs: PackedVector3Array = PackedVector3Array()
	for j: int in 4:
		var dj: float = d0 + lerpf(-0.0075, 0.0075, float(j) / 3.0)
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in 13:
			var x: float = lerpf(-0.0465, 0.0465, float(k) / 12.0)
			var f: float = pow(absf(x) / 0.0465, 2.5)
			var arch: float = 0.0015 + (_tongue_face(PUFF_TONGUE, dj) + 0.0095) * (1.0 - f)
			ring.append(sh.over(dj, x, arch * (1.0 if j == 1 or j == 2 else 0.85)))
		rows.append(ring)
		refs.append(sh.over(dj, 0.0, 0.0))
	ShoeKit.grid_into(st, rows, false, refs)
	SkaterParts.part(shoe, "LaceCoverMesh", ShoeKit.done(st), off, m, "shoe_tab")
	var plate: MeshInstance3D = SkaterParts.part(shoe, "LaceCoverPlateMesh", SkaterParts.box(Vector3(0.017, 0.0034, 0.0125)),
			off + sh.over(d0, 0.0, 0.0165), m, "shoe_foxing")
	plate.rotation.x = 0.0


## Surface point of a decal at local (a along the foot toward the toe is -d, b up) around (d, v) on the side of the upper.
static func _decal_pt(sh: ShoeShape, sgn: float, d: float, v: float, a: float, b: float, g: float) -> Vector3:
	return sh.pt(d - a, sgn * sh.phi_at_v(d - a, v + b, g), g)


## A polygon decal (fan from its centre) mapped onto the side of the upper.
static func _decal_fan(st: SurfaceTool, sh: ShoeShape, sgn: float, d: float, v: float, poly: Array, g: float) -> void:
	var c: Vector3 = _decal_pt(sh, sgn, d, v, 0.0, 0.0, g)
	var ref: Vector3 = Vector3(0.0, c.y, c.z)
	for k: int in poly.size():
		var p0: Vector2 = poly[k]
		var p1: Vector2 = poly[(k + 1) % poly.size()]
		ShoeKit.tri_into(st, c, _decal_pt(sh, sgn, d, v, p0.x, p0.y, g), _decal_pt(sh, sgn, d, v, p1.x, p1.y, g), ref)


## A thick line decal from (ax, ay) to (bx, by), width w.
static func _decal_bar(st: SurfaceTool, sh: ShoeShape, sgn: float, d: float, v: float, a: Vector2, b: Vector2, w: float, g: float) -> void:
	var n: Vector2 = (b - a).orthogonal().normalized() * w * 0.5
	var p: Array = [a + n, a - n, b + n, b - n]
	var q: Array = []
	for pt: Vector2 in p:
		q.append(_decal_pt(sh, sgn, d, v, pt.x, pt.y, g))
	var ref: Vector3 = Vector3(0.0, (q[0] as Vector3).y, (q[0] as Vector3).z)
	ShoeKit.quad_into(st, q[0], q[1], q[2], q[3], ref)


## Big round badge with a lightning bolt on each quarter (an invented emblem) and a woven label on the tongue.
static func _puff_badges(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape) -> void:
	var g: float = 0.0049
	var d: float = 0.112
	var v: float = 0.036
	var disc: SurfaceTool = ShoeKit.begin()
	var bolt: SurfaceTool = ShoeKit.begin()
	var ring: Array = []
	for k: int in 14:
		var a: float = TAU * float(k) / 14.0
		ring.append(Vector2(cos(a), sin(a)) * 0.0235)
	for sgn: float in [-1.0, 1.0]:
		_decal_fan(disc, sh, sgn, d, v, ring, g)
		# Rotated so the bolt leans the same way on both sides (the decal's a axis runs toward the heel).
		_decal_bar(bolt, sh, sgn, d, v, Vector2(-0.008, 0.0215), Vector2(0.0035, 0.002), 0.0094, g + 0.0009)
		_decal_bar(bolt, sh, sgn, d, v, Vector2(0.008, -0.0215), Vector2(-0.0035, -0.002), 0.0094, g + 0.0009)
		_decal_bar(bolt, sh, sgn, d, v, Vector2(-0.0105, -0.0005), Vector2(0.0105, 0.0005), 0.0074, g + 0.0009)
	SkaterParts.part(shoe, "BadgeDiscMesh", ShoeKit.done(disc), off, m, "shoe_foxing")
	SkaterParts.part(shoe, "BadgeBoltMesh", ShoeKit.done(bolt), off, m, "shoe_stripe")
	# Woven label on the tongue's front.
	var z: float = sh.heel_z - 0.1275 - 0.021 - 0.0006
	var plate: MeshInstance3D = SkaterParts.part(shoe, "TongueLabelMesh", SkaterParts.box(Vector3(0.036, 0.021, 0.002)),
			off + Vector3(0.0, 0.169, z), m, "shoe_stripe")
	plate.rotation.x = -0.15
	var mark: MeshInstance3D = SkaterParts.part(shoe, "TongueMarkMesh", SkaterParts.box(Vector3(0.022, 0.0075, 0.002)),
			off + Vector3(0.0, 0.169, z - 0.0009), m, "shoe_tab")
	mark.rotation.x = -0.15


# --- high top: Vans Sk8-Hi style ----------------------------------------------------------------------------------
# The low part (vulc sole, toe cap, jazz stripe, the first four eyelet pairs) hangs on the foot as "<Side>ShoeMesh".
# The shaft (padded collar, ankle panels, the other four eyelet pairs, tongue and bow) is a loft of the calf's own
# sections, so it hangs on the lower leg joint like a sock and stays outside the sock and the skin in every pose.

const HI_TONGUE: Array = [
	[0.207, 0.0012, 0.0012, 0.0125], [0.18, 0.0022, 0.0022, 0.0145], [0.155, 0.0036, 0.0036, 0.0148],
	[0.14, 0.0085, 0.0075, 0.019], [0.127, 0.0105, 0.0055, 0.016],
]
const HI_GROW: float = 0.0102  ## shaft distance outside the calf section (the sock takes 3 mm of it)
const HI_BOTTOM: float = -0.02  ## shaft bottom, relative to the ankle joint (hidden inside the vamp)
const HI_TOP: float = 0.075  ## collar top above the ankle joint
const HI_EYELET_Y: Array = [-0.008, 0.0085, 0.025, 0.0415]  ## shaft eyelet heights above the ankle joint
const HI_EYELET_X: float = 0.0215


static func build_high_top(foot: Node3D, lower: Node3D, side: String, ankle_height: float, calf: Array, lower_len: float,
		mats: Dictionary, colourway: Dictionary = {}) -> Node3D:
	var m: Dictionary = ShoeKit.materials(mats, colourway)
	var sh: ShoeShape = hi_shape()
	var shoe: Node3D = SkaterParts.joint(foot, side + "ShoeMesh", Vector3.ZERO)
	var off: Vector3 = Vector3(0.0, -ankle_height, 0.0)
	_vulc_sole(shoe, off, m, sh)
	_upper(shoe, off, m, sh, "shoe_canvas", 12)
	_toe_cap(shoe, off, m, sh, 0.0022, "shoe_suede")
	_toe_bumper(shoe, off, m, sh, 0.0042, 0.07, 0.003, 0.03)
	_heel_cup(shoe, off, m, sh, 0.0024, 0.022, 0.062, "shoe_suede")
	_eyestays(shoe, off, m, sh, 0.131, 0.0155, 0.0345, 0.0026, "shoe_suede")
	_side_ribbon(shoe, off, m, sh, "SidePanel", "shoe_stripe", SkateShoe.STRIPE, 0.0011)
	_hi_stitches(shoe, off, m, sh)
	var holes: Array = _eyelets(shoe, off, m, sh, 4, 0.205, 0.158, 0.0026, 0.0034, 0.0245)
	_tongue(shoe, off, m, sh, HI_TONGUE)
	_laces(shoe, off, m, sh, holes, HI_TONGUE, -1.0, 0.0125, 0.0038)
	_hi_shaft(lower, side, m, calf, lower_len)
	return shoe


## The vulc sole stack on any shape: outsole with a waffle edge, white foxing band with its coloured line, heel label.
static func _vulc_sole(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape) -> void:
	var gs: float = sh.g_sole
	var gf: float = sh.g_fox
	var sole_top: float = SkateShoe.SOLE_TOP
	var st: SurfaceTool = ShoeKit.begin()
	var rows: Array = [sh.outline(gs - 0.006, 0.0), sh.outline(gs, 0.004), sh.outline(gs, sole_top)]
	ShoeKit.grid_into(st, rows, true, sh.refs(rows, 0.008))
	SkaterParts.part(shoe, "SoleMesh", ShoeKit.done(st), off, m, "shoe_sole")
	st = ShoeKit.begin()
	rows = [sh.outline(gf, sole_top), sh.outline(gf, sh.fox_top - 0.003), sh.outline(gf - 0.0025, sh.fox_top)]
	ShoeKit.grid_into(st, rows, true, sh.refs(rows, 0.012))
	SkaterParts.part(shoe, "FoxingMesh", ShoeKit.done(st), off, m, "shoe_foxing")
	st = ShoeKit.begin()
	rows = [sh.outline(gf + 0.0007, 0.0215), sh.outline(gf + 0.0007, 0.0245)]
	ShoeKit.grid_into(st, rows, true, sh.refs(rows, 0.023))
	SkaterParts.part(shoe, "FoxingLineMesh", ShoeKit.done(st), off, m, "shoe_foxing_line")
	_lugs(shoe, off, m, sh, gs + 0.0006, 0.0105, 0.0052, 0.0052)
	SkaterParts.part(shoe, "HeelLabelMesh", SkaterParts.box(Vector3(0.03, 0.011, 0.003)),
			off + Vector3(0.0, 0.019, sh.heel_z + gf + 0.0006), m, "shoe_tab")


static func _hi_stitches(shoe: Node3D, off: Vector3, m: Dictionary, sh: ShoeShape) -> void:
	var st: SurfaceTool = ShoeKit.begin()
	for gap: float in [0.0035, 0.0068]:
		var f_cap: Callable = func(t: float) -> Vector2:
			var pa: float = lerpf(-1.42, 1.42, t)
			return Vector2(sh.cap_edge(pa) + gap, pa)
		_dashes(sh, st, f_cap, 22, 0.0022 + 0.0009)
	for sgn: float in [-1.0, 1.0]:
		for xe: float in [0.0345 - 0.0028, 0.0345 - 0.006]:
			var x: float = sgn * xe
			var d_end: float = sh.cap_edge(sh.phi_at_x(0.2, x, 0.0)) - 0.004
			var f_eye: Callable = func(t: float) -> Vector2:
				var d: float = lerpf(0.134, d_end, t)
				return Vector2(d, sh.phi_at_x(d, x, 0.0026))
			_dashes(sh, st, f_eye, 11, 0.0026 + 0.0009)
	SkaterParts.part(shoe, "StitchMesh", ShoeKit.done(st), off, m, "shoe_stitch")


# --- shaft ----------------------------------------------------------------------------------------------------------

## Extra distance of the shaft outside the calf section at height y (lower leg space) and section angle a: the bottom
## flares forward (to meet the instep and the lace line) and back (to meet the heel).
static func _shaft_grow(y: float, a: float, ankle_y: float) -> float:
	var rel: float = y - ankle_y
	var flare: float = 1.0 - smoothstep(-0.012, 0.06, rel)
	var c: float = cos(a)
	var front: float = pow(maxf(c, 0.0), 2.0)
	var back: float = pow(maxf(-c, 0.0), 2.0)
	return HI_GROW + flare * (0.03 * front + 0.016 * back) + 0.0012 * smoothstep(0.06, HI_TOP, rel)


static func _shaft_pt(secs: Array, y: float, a: float, ankle_y: float, extra: float = 0.0) -> Vector3:
	return SkaterParts.section_point(SkaterParts.section_at(secs, y), a, _shaft_grow(y, a, ankle_y) + extra)


## Outward normal of the shaft at (y, a), in the horizontal plane.
static func _shaft_n(secs: Array, y: float, a: float, ankle_y: float) -> Vector3:
	return (_shaft_pt(secs, y, a, ankle_y, 0.01) - _shaft_pt(secs, y, a, ankle_y)).normalized()


static func _shaft_angle(secs: Array, y: float, x: float, ankle_y: float) -> float:
	return SkaterParts.section_angle_for_x(SkaterParts.section_at(secs, y), x, true, _shaft_grow(y, 0.0, ankle_y) - 0.012)


static func _hi_shaft(lower: Node3D, side: String, m: Dictionary, secs: Array, lower_len: float) -> void:
	var ay: float = -lower_len
	var y0: float = ay + HI_BOTTOM
	var y1: float = ay + HI_TOP
	var rows: Array = []
	var n_rows: int = 9
	var cols: int = 18
	for i: int in n_rows:
		var y: float = lerpf(y0, y1, float(i) / float(n_rows - 1))
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols:
			ring.append(_shaft_pt(secs, y, TAU * float(k) / float(cols), ay))
		rows.append(ring)
	SkaterParts.part(lower, side + "ShoeShaftMesh", SkaterParts.grid(rows, true), Vector3.ZERO, m, "shoe_canvas")
	# Dark lining seen inside the collar; it runs down inside the shoe to the end of the ankle skin, so the skin is always
	# enclosed. Then the padded roll round the top.
	var inner: Array = []
	var inner_y: Array = [float(secs[secs.size() - 1][0]) - 0.008, y0 - 0.006, y0 + 0.014, y1 - 0.03, y1 - 0.02, y1 - 0.01, y1]
	for y: float in inner_y:
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols:
			var q: Vector3 = SkaterParts.section_point(SkaterParts.section_at(secs, y), TAU * float(k) / float(cols), 0.0049)
			q.y = y  # below the last section the nearest one is reused
			ring.append(q)
		inner.append(ring)
	SkaterParts.part(lower, side + "ShoeShaftLiningMesh", SkaterParts.grid(inner, true, true), Vector3.ZERO, m, "shoe_lining")
	SkaterParts.part(lower, side + "ShoeCollarMesh", SkaterParts.loft_ring(secs, y1, HI_GROW + 0.0016, 0.0078, 20), Vector3.ZERO, m,
			"shoe_collar")
	_hi_ankle_pads(lower, side, m, secs, ay)
	_hi_front(lower, side, m, secs, ay)
	var tab: MeshInstance3D = SkaterParts.part(lower, side + "ShoeShaftTabMesh", SkaterParts.box(Vector3(0.022, 0.03, 0.0045)),
			_shaft_pt(secs, y1 - 0.004, PI, ay, 0.0012), m, "shoe_tab")
	tab.rotation.x = -0.1


## Padded ankle panels: a round pillow on each side of the shaft over the ankle bone, with a stitched edge.
static func _hi_ankle_pads(lower: Node3D, side: String, m: Dictionary, secs: Array, ay: float) -> void:
	var yc: float = ay + 0.034
	var st: SurfaceTool = ShoeKit.begin()
	var dash: SurfaceTool = ShoeKit.begin()
	for sgn: float in [-1.0, 1.0]:
		var ac: float = sgn * (PI * 0.5 + 0.12)
		var rows: Array = []
		var refs: PackedVector3Array = PackedVector3Array()
		for j: int in 3:
			var rho: float = float(j) / 2.0
			var ring: PackedVector3Array = PackedVector3Array()
			for k: int in 12:
				var th: float = TAU * float(k) / 12.0
				var y: float = yc + 0.0215 * rho * sin(th)
				var a: float = ac + 0.74 * rho * cos(th) * sgn
				ring.append(_shaft_pt(secs, y, a, ay, 0.0012 + 0.0052 * sqrt(maxf(1.0 - rho * rho, 0.0))))
			rows.append(ring)
			refs.append(Vector3(0.0, yc, 0.0))
		ShoeKit.grid_into(st, rows, true, refs)
		for k: int in 14:
			var t0: float = TAU * (float(k) + 0.1) / 14.0
			var t1: float = TAU * (float(k) + 0.6) / 14.0
			var p0: Vector3 = _shaft_pt(secs, yc + 0.0235 * sin(t0), ac + 0.8 * cos(t0) * sgn, ay, 0.0014)
			var p1: Vector3 = _shaft_pt(secs, yc + 0.0235 * sin(t1), ac + 0.8 * cos(t1) * sgn, ay, 0.0014)
			var n: Vector3 = Vector3(sgn, 0.0, 0.0)
			var w: Vector3 = (p1 - p0).cross(n).normalized() * 0.0006
			ShoeKit.quad_into(dash, p0 - w, p0 + w, p1 - w, p1 + w, Vector3(0.0, p0.y, 0.0))
	SkaterParts.part(lower, side + "ShoeAnklePadMesh", ShoeKit.done(st), Vector3.ZERO, m, "shoe_suede")
	SkaterParts.part(lower, side + "ShoeAnkleStitchMesh", ShoeKit.done(dash), Vector3.ZERO, m, "shoe_stitch")


## Front of the shaft: eyestays, the padded tongue strip, four eyelet pairs, criss-cross laces and a bow.
static func _hi_front(lower: Node3D, side: String, m: Dictionary, secs: Array, ay: float) -> void:
	var y0: float = ay + HI_BOTTOM
	var y1: float = ay + HI_TOP
	# Eyestays.
	var st: SurfaceTool = ShoeKit.begin()
	for sgn: float in [-1.0, 1.0]:
		var rows: Array = []
		var refs: PackedVector3Array = PackedVector3Array()
		for i: int in 8:
			var y: float = lerpf(y0 + 0.012, y1 - 0.004, float(i) / 7.0)
			var ring: PackedVector3Array = PackedVector3Array()
			for k: int in 4:
				var x: float = sgn * lerpf(0.0145, 0.0345, float(k) / 3.0)
				ring.append(_shaft_pt(secs, y, _shaft_angle(secs, y, x, ay), ay, 0.0024))
			rows.append(ring)
			refs.append(Vector3(0.0, y, 0.0))
		ShoeKit.grid_into(st, rows, false, refs)
	SkaterParts.part(lower, side + "ShoeEyestayMesh", ShoeKit.done(st), Vector3.ZERO, m, "shoe_suede")
	# Tongue strip: a padded pad up the front, poking out of the collar.
	st = ShoeKit.begin()
	var rows2: Array = []
	var refs2: PackedVector3Array = PackedVector3Array()
	var steps: int = 9
	for i: int in steps:
		var t: float = float(i) / float(steps - 1)
		var y: float = lerpf(y0 + 0.004, y1 + 0.016, t)
		var cap: float = 1.0 - pow(smoothstep(0.82, 1.0, t), 2.0)
		var ring: PackedVector3Array = PackedVector3Array()
		var centre: Vector3 = _shaft_pt(secs, y, 0.0, ay, 0.0)
		var nrm: Vector3 = _shaft_n(secs, y, 0.0, ay)
		for k: int in 12:
			var a: float = TAU * float(k) / 12.0
			var c: float = cos(a)
			var s: float = sin(a)
			var thick: float = 0.0035 + 0.0072 * cap * pow(maxf(c, 0.0), 0.7) - 0.005 * maxf(-c, 0.0)
			ring.append(centre + nrm * thick + Vector3.RIGHT * 0.0118 * cap * signf(s) * pow(absf(s), 0.6))
		rows2.append(ring)
		refs2.append(centre - nrm * 0.02)
	ShoeKit.grid_into(st, rows2, true, refs2)
	SkaterParts.part(lower, side + "ShoeTongueMesh", ShoeKit.done(st), Vector3.ZERO, m, "shoe_tongue")
	# Eyelets and laces.
	var holes: Array = [[], []]
	st = ShoeKit.begin()
	for yr: float in HI_EYELET_Y:
		var y: float = ay + yr
		for j: int in 2:
			var x: float = HI_EYELET_X * (-1.0 if j == 0 else 1.0)
			var a: float = _shaft_angle(secs, y, x, ay)
			var n: Vector3 = _shaft_n(secs, y, a, ay)
			var p: Vector3 = _shaft_pt(secs, y, a, ay, 0.0024 + 0.0011)
			var u: Vector3 = (Vector3.UP - n * n.y).normalized()
			var w: Vector3 = n.cross(u).normalized()
			for k: int in 8:
				var a0: float = TAU * float(k) / 8.0
				var a1: float = TAU * float(k + 1) / 8.0
				ShoeKit.tri_into(st, p, p + (u * cos(a0) + w * sin(a0)) * 0.0034, p + (u * cos(a1) + w * sin(a1)) * 0.0034, p - n * 0.01)
			(holes[j] as Array).append([y, x])
	SkaterParts.part(lower, side + "ShoeEyeletsMesh", ShoeKit.done(st), Vector3.ZERO, m, "shoe_eyelet")
	st = ShoeKit.begin()
	var left: Array = holes[0]
	var right: Array = holes[1]
	_shaft_lace(st, secs, ay, left[0], right[0], 0)
	for i: int in left.size() - 1:
		_shaft_lace(st, secs, ay, left[i], right[i + 1], 1)
		_shaft_lace(st, secs, ay, right[i], left[i + 1], 0)
	var items: Array = [[ShoeKit.done(st), Transform3D.IDENTITY]]
	# Bow above the top pair, lying on the tongue strip.
	var ky: float = ay + HI_EYELET_Y[HI_EYELET_Y.size() - 1] + 0.0165
	var knot: Vector3 = _shaft_pt(secs, ky, 0.0, ay, 0.0105)
	items.append([_knot_mesh(0.0045), Transform3D(Basis.from_scale(Vector3(1.2, 1.0, 0.8)), knot)])
	for sgn: float in [-1.0, 1.0]:
		var loop: PackedVector3Array = PackedVector3Array([knot, knot + Vector3(sgn * 0.012, 0.0075, -0.0035),
				knot + Vector3(sgn * 0.027, 0.0045, -0.0055), knot + Vector3(sgn * 0.033, -0.0065, -0.0045),
				knot + Vector3(sgn * 0.021, -0.0085, -0.003), knot + Vector3(sgn * 0.004, -0.002, -0.0008)])
		items.append([SkaterParts.tube(loop, PackedFloat32Array([0.0021, 0.0021, 0.0021, 0.0021, 0.0021, 0.0021]), 4), Transform3D.IDENTITY])
		var tail: PackedVector3Array = PackedVector3Array([knot, knot + Vector3(sgn * 0.005, -0.012, -0.001),
				knot + Vector3(sgn * 0.009, -0.026, -0.0015), knot + Vector3(sgn * 0.011, -0.038, -0.001)])
		items.append([SkaterParts.tube(tail, PackedFloat32Array([0.0022, 0.0022, 0.0021, 0.002]), 4), Transform3D.IDENTITY])
	SkaterParts.part(lower, side + "ShoeLacesMesh", ShoeKit.merge(items), Vector3.ZERO, m, "shoe_laces")


static func _shaft_lace(st: SurfaceTool, secs: Array, ay: float, a: Array, b: Array, layer: int) -> void:
	var n: int = 4
	var path: PackedVector3Array = PackedVector3Array()
	var norms: Array = []
	for i: int in n:
		var t: float = float(i) / float(n - 1)
		var y: float = lerpf(float(a[0]), float(b[0]), t)
		var x: float = lerpf(float(a[1]), float(b[1]), t)
		var ang: float = _shaft_angle(secs, y, x, ay)
		var arch: float = pow(sin(PI * t), 0.6)
		var clear: float = 0.0034 + (0.0105 + 0.0018 - 0.0034) * arch + 0.0013 * float(layer) * arch
		path.append(_shaft_pt(secs, y, ang, ay, clear))
		norms.append(_shaft_n(secs, y, ang, ay))
	var rows: Array = []
	for i: int in n:
		var tan: Vector3 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var across: Vector3 = tan.cross(norms[i] as Vector3).normalized() * 0.0034
		var up: Vector3 = (norms[i] as Vector3) * 0.0008
		rows.append(PackedVector3Array([path[i] + across + up, path[i] - across + up, path[i] - across - up, path[i] + across - up]))
	var refs: PackedVector3Array = PackedVector3Array()
	for i: int in n:
		refs.append(path[i] - (norms[i] as Vector3) * 0.02)
	ShoeKit.grid_into(st, rows, true, refs)
