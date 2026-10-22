class_name GarmentBottoms
extends RefCounted
## Bottom garments (slot "bottom"). Contract and registration: see Wardrobe (game/skater/wardrobe.gd).
## Built: bottom_bikini (female; the male body gets board shorts), bottom_board_shorts, bottom_cargo_shorts (knee-length,
## pockets with flaps, belt), bottom_skate_jeans (baggy denim, stacked hem, knee fade) and bottom_joggers (tapered,
## cuffed, drawstring, side stripe).
## Palette keys: "bottom" (main fabric) and "bottom_trim" (piping, side stripe, drawstring, belt, stitching). The jeans'
## knee fade is "bottom_fade" (made from the bottom colour when the palette has no such key), the belt buckle is
## "bottom_metal".

const STUBS: PackedStringArray = []
const BOTTOM_DEFAULT: Color = Color(0.07, 0.66, 0.7)
const TRIM_DEFAULT: Color = Color(1.0, 0.5, 0.4)
## Bikini: leg-cut height (body y) over the hips and at the front and back centre, and the waistband height.
const BIKINI_SIDE_Y: float = 0.872
const BIKINI_INNER_Y: float = 0.772
const BIKINI_TOP_Y: float = 0.905
const BIKINI_GROW: float = 0.005
## Extra clearance at the leg openings (elastic edge): a flexed or stretched thigh moves its skin a little outward
## at the crease, and the edges stand that far off so it stays under the fabric.
const LEG_EDGE_GROW: float = 0.008
## Board shorts: waistband height (body y) and leg length (fraction of the thigh bone).
const SHORTS_TOP_Y: float = 0.968
const SHORTS_LEG_T: float = 0.66
const SHORTS_GROW: float = 0.008
## The seat's crotch (_waist): sections below GUSSET_REF over the pelvis bottom keep GUSSET_WIDTH of that section's size.
const GUSSET_REF: float = 0.038
const GUSSET_WIDTH: float = 0.85


static func builders() -> Dictionary:
	return {
		"bottom_bikini": GarmentBottoms.bikini,
		"bottom_board_shorts": GarmentBottoms.board_shorts,
		"bottom_cargo_shorts": GarmentBottoms.cargo_shorts,
		"bottom_skate_jeans": GarmentBottoms.skate_jeans,
		"bottom_joggers": GarmentBottoms.joggers,
	}


static func covers(id: String, body_type: String) -> PackedStringArray:
	match id:
		"bottom_bikini":
			if body_type == AnimeOutfit.MALE:
				return covers("bottom_board_shorts", body_type)
			return PackedStringArray(["thigh_top_L", "thigh_top_R"])
		"bottom_board_shorts":
			return PackedStringArray(["pelvis", "hip_band", "waist_low", "thigh_top_L", "thigh_top_R", "thigh_upper_L",
					"thigh_upper_R"])
		"bottom_cargo_shorts":
			return covers("bottom_board_shorts", body_type)
		"bottom_skate_jeans":
			return PackedStringArray(["pelvis", "hip_band", "waist_low", "thigh_top_L", "thigh_top_R", "thigh_upper_L",
					"thigh_upper_R", "thigh_lower_L", "thigh_lower_R", "knee_L", "knee_R", "calf_L", "calf_R"])
		"bottom_joggers":  ## the jeans' hem and the cuff end over the shoe collar, above the tongue: calf_low stays skin (or sock)
			return PackedStringArray(["pelvis", "hip_band", "waist_low", "thigh_top_L", "thigh_top_R", "thigh_upper_L",
					"thigh_upper_R", "thigh_lower_L", "thigh_lower_R", "knee_L", "knee_R", "calf_L", "calf_R"])
	return PackedStringArray()


static func _mats(mats: Dictionary) -> void:
	Wardrobe.mat(mats, "bottom", BOTTOM_DEFAULT)
	Wardrobe.mat(mats, "bottom_trim", TRIM_DEFAULT)
	# A deeper, quieter shade of the fabric for hems, cuffs and seams: reads as folded cloth, not a bright hoop.
	var base: Color = (mats["bottom"] as StandardMaterial3D).albedo_color
	Wardrobe.mat(mats, "bottom_dark", Color.from_hsv(base.h, base.s * 0.95, base.v * 0.86))


# --- bikini ---------------------------------------------------------------------------------------------------

## Leg-cut height (body y, rest) of the bikini on the pelvis at angle a (0 front, +PI/2 = +X): low at the front and
## back centre, high over the hips.
static func _panel_cut_y(a: float) -> float:
	return lerpf(BIKINI_INNER_Y, BIKINI_SIDE_Y, pow(absf(sin(a)), 1.6))


## Matching bikini bottoms: a panel over the pelvis up to a low waistband with a gusset under the crotch (on Hips),
## and a leg-opening piece round the top of each thigh (on <Side>UpperLeg) whose lower edge is the panel's leg cut,
## so the fabric follows the thigh where it meets the hip and the thigh top never shows through. The panel stands
## off further at its leg edges (elastic edge) so a flexed thigh stays under it. Coral piping on the waistband and
## the leg openings.
static func bikini(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	if body_type == AnimeOutfit.MALE:
		board_shorts(rig, body_type, mats)
		return
	_mats(mats)
	var hips: Node3D = rig["Hips"]
	var base: float = float(rig["rest_y"]["Hips"])
	var pelvis: Array = rig["sections"]["pelvis"]
	var sides: int = 40
	var rows: Array = []
	var levels: int = 10
	for v: int in levels + 1:
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in sides:
			var a: float = TAU * float(k) / float(sides)
			var f: float = float(v) / float(levels)
			var y: float = lerpf(_panel_cut_y(a), BIKINI_TOP_Y + 0.008 * cos(a + PI), f) - base
			ring.append(SkaterParts.section_point(SkaterParts.section_at(pelvis, y), a, _edge_grow(f, a)))
		rows.append(ring)
	SkaterParts.part(hips, "BikiniBottomMesh", SkaterParts.grid(rows, true), Vector3.ZERO, mats, "bottom")
	var gusset: Array = AnimeOutfit.clip(pelvis, float(pelvis[0][0]), BIKINI_INNER_Y + 0.012 - base)
	SkaterParts.part(hips, "BikiniGussetMesh", SkaterParts.loft(gusset, sides, BIKINI_GROW), Vector3.ZERO, mats, "bottom")
	var pts: PackedVector3Array = PackedVector3Array()
	for k: int in sides + 1:
		var a: float = TAU * float(k) / float(sides)
		var y: float = BIKINI_TOP_Y + 0.008 * cos(a + PI) - base
		pts.append(SkaterParts.section_point(SkaterParts.section_at(pelvis, y), a, BIKINI_GROW + 0.001))
	var radii: PackedFloat32Array = PackedFloat32Array()
	radii.resize(pts.size())
	radii.fill(0.0042)
	SkaterParts.part(hips, "BikiniWaistTrimMesh", SkaterParts.tube(pts, radii, 6), Vector3.ZERO, mats, "bottom_trim")
	var leg_pts: PackedVector3Array = PackedVector3Array()
	for k: int in sides + 1:
		var a: float = TAU * float(k) / float(sides)
		leg_pts.append(SkaterParts.section_point(SkaterParts.section_at(pelvis, _panel_cut_y(a) - base), a, _edge_grow(0.0, a) + 0.001))
	var leg_radii: PackedFloat32Array = PackedFloat32Array()
	leg_radii.resize(leg_pts.size())
	leg_radii.fill(0.0034)
	SkaterParts.part(hips, "BikiniLegTrimMesh", SkaterParts.tube(leg_pts, leg_radii, 6), Vector3.ZERO, mats, "bottom_trim")
	# Leg openings, on the thighs: from inside the pelvis down to the panel's own leg cut (found at rest), so at rest
	# the two edges meet, and in any pose the opening moves with the thigh.
	var thigh: Array = rig["sections"]["thigh"]
	var ul: float = float(rig["lengths"]["upper_leg"])
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		var upper: Node3D = rig[side + "UpperLeg"]
		var to_hips: Transform3D = upper.transform
		var top_y: float = 0.17 * ul  ## thigh-space y of the loft's top
		var cols: int = 32
		var cuts: PackedFloat32Array = PackedFloat32Array()
		for k: int in cols:
			cuts.append(_cut_on_thigh(TAU * float(k) / float(cols), thigh, to_hips, base, top_y, -0.45 * ul))
		var leg_rows: Array = []
		var n: int = 10
		for v: int in n + 1:
			var ring: PackedVector3Array = PackedVector3Array()
			for k: int in cols:
				var a: float = TAU * float(k) / float(cols)
				var f: float = pow(float(v) / float(n), 1.5)
				var y: float = lerpf(cuts[k], top_y, f)
				ring.append(SkaterParts.section_point(SkaterParts.section_at(thigh, y), a, BIKINI_GROW + 0.5 * LEG_EDGE_GROW * (1.0 - f)))
			leg_rows.append(ring)
		SkaterParts.part(upper, side + "BikiniLegMesh", SkaterParts.grid(leg_rows, true), Vector3.ZERO, mats, "bottom")


## Panel clearance at height fraction f (0 = leg edge, 1 = waistband) and angle a: thickest at the leg openings,
## least over the hips where the leg cut is high.
static func _edge_grow(f: float, a: float) -> float:
	var edge: float = pow(1.0 - clampf(f / 0.45, 0.0, 1.0), 2.0) * (1.0 - 0.6 * pow(absf(sin(a)), 3.0))
	return BIKINI_GROW + LEG_EDGE_GROW * edge


## Thigh-space y on the thigh's surface line at angle a where, at rest, the point reaches the panel's leg cut.
static func _cut_on_thigh(a: float, thigh: Array, to_hips: Transform3D, hips_y: float, y_hi: float, y_lo: float) -> float:
	var hi: float = y_hi
	var lo: float = y_lo
	for i: int in 24:
		var mid: float = (hi + lo) * 0.5
		var p: Vector3 = to_hips * SkaterParts.section_point(SkaterParts.section_at(thigh, mid), a)
		var a_p: float = atan2(p.x, -p.z)
		if p.y + hips_y > _panel_cut_y(a_p):
			hi = mid
		else:
			lo = mid
	return (hi + lo) * 0.5


# --- board shorts ---------------------------------------------------------------------------------------------

## Knee-length board shorts: a seat over the pelvis (Hips) with a waistband, a lining band round the low waist
## (Spine) so a bent spine never shows skin, loose straight legs on the thighs flaring a little at the hem, a
## contrast stripe down each outer leg, a hem band and a tied drawstring at the fly.
static func board_shorts(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	_mats(mats)
	var hips: Node3D = rig["Hips"]
	var base: float = float(rig["rest_y"]["Hips"])
	var pelvis: Array = rig["sections"]["pelvis"]
	var seat: Array = AnimeOutfit.clip(pelvis, float(pelvis[0][0]), SHORTS_TOP_Y - base)
	seat = _crotch(seat, pelvis)
	SkaterParts.part(hips, "BoardShortsSeatMesh", SkaterParts.loft(seat, 36, SHORTS_GROW), Vector3.ZERO, mats, "bottom")
	SkaterParts.part(hips, "BoardShortsWaistbandMesh", SkaterParts.loft(AnimeOutfit.clip(pelvis, SHORTS_TOP_Y - 0.026 - base,
			SHORTS_TOP_Y - base), 36, SHORTS_GROW + 0.003), Vector3.ZERO, mats, "bottom_trim")
	var spine_y: float = float(rig["rest_y"]["Spine"])
	var waist: Array = rig["sections"]["waist"]
	# Lining on Spine so a bent spine never opens the waist: fabric colour below the waistband, trim colour behind it
	# (where it pokes through the seat it then matches what is around it).
	var band_low: float = SHORTS_TOP_Y - 0.026 - spine_y
	SkaterParts.part(rig["Spine"], "BoardShortsWaistMesh", SkaterParts.loft(AnimeOutfit.clip(waist, float(waist[0][0]), band_low),
			32, SHORTS_GROW + 0.001), Vector3.ZERO, mats, "bottom")
	SkaterParts.part(rig["Spine"], "BoardShortsWaistTrimMesh", SkaterParts.loft(AnimeOutfit.clip(waist, band_low, SHORTS_TOP_Y - spine_y),
			32, SHORTS_GROW + 0.001), Vector3.ZERO, mats, "bottom_trim")
	# Drawstring at the front of the waistband: a small knot and two short tails lying on the fabric.
	var front: Array = SkaterParts.section_at(pelvis, SHORTS_TOP_Y - 0.012 - base)
	var knot: Vector3 = SkaterParts.section_point(front, 0.0, SHORTS_GROW + 0.004)
	SkaterParts.part(hips, "BoardShortsKnotMesh", SkaterParts.sphere_small(0.005), knot, mats, "bottom")
	for s: float in [-1.0, 1.0]:
		var tail: PackedVector3Array = PackedVector3Array()
		for i: int in 5:
			var t: float = float(i) / 4.0
			var sec: Array = SkaterParts.section_at(pelvis, SHORTS_TOP_Y - 0.012 - 0.03 * t - base)
			tail.append(SkaterParts.section_point(sec, s * 0.12 * t, SHORTS_GROW + 0.004))
		var tr: PackedFloat32Array = PackedFloat32Array([0.0026, 0.0025, 0.0024, 0.0023, 0.0022])
		SkaterParts.part(hips, ("Left" if s < 0.0 else "Right") + "BoardShortsStringMesh", SkaterParts.tube_capped(tail, tr, 6),
				Vector3.ZERO, mats, "bottom")
	# Legs.
	var thigh: Array = rig["sections"]["thigh"]
	var ul: float = float(rig["lengths"]["upper_leg"])
	var ref: Array = SkaterParts.section_at(thigh, 0.0)
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		var s: float = sd[1]
		var upper: Node3D = rig[side + "UpperLeg"]
		var rows: Array = []
		var steps: int = 20
		var y_top: float = 0.2 * ul
		var y_end: float = -SHORTS_LEG_T * ul
		var hem_ring: PackedVector3Array = PackedVector3Array()
		for i: int in steps + 1:
			var f: float = float(i) / float(steps)
			var y: float = lerpf(y_top, y_end, f)
			var sec: Array = (SkaterParts.section_at(thigh, y) as Array).duplicate()
			if y < 0.0:  ## below the hip joint the leg hangs straight and loose
				for c: int in [1, 2, 3]:
					sec[c] = maxf(float(sec[c]), float(ref[c]) * lerpf(0.98, 0.94, f))
			var g: float = SHORTS_GROW + 0.004 + 0.006 * smoothstep(0.5, 1.0, f)
			var ring: PackedVector3Array = PackedVector3Array()
			for k: int in 28:
				ring.append(SkaterParts.section_point(sec, TAU * float(k) / 28.0, g))
			rows.append(ring)
			if i == steps:
				hem_ring = ring
		rows.reverse()
		SkaterParts.part(upper, side + "BoardShortsLegMesh", SkaterParts.grid(rows, true), Vector3.ZERO, mats, "bottom")
		# Inside of the hem: the same cloth seen from within (flipped), so an open end reads as cloth, not a see-through hoop.
		SkaterParts.part(upper, side + "BoardShortsLiningMesh", SkaterParts.grid(rows.slice(0, 8), true, true), Vector3.ZERO, mats, "bottom_dark")
		var hp: PackedVector3Array = hem_ring.duplicate()
		hp.append(hem_ring[0])
		var hr: PackedFloat32Array = PackedFloat32Array()
		hr.resize(hp.size())
		hr.fill(0.0042)
		SkaterParts.part(upper, side + "BoardShortsHemMesh", SkaterParts.tube(hp, hr, 6), Vector3.ZERO, mats, "bottom_dark")
		# Outer side stripe: a band lying on the leg from the top down to the hem.
		var i_out: int = 7 if s > 0.0 else 21
		var left: PackedVector3Array = PackedVector3Array()
		var right: PackedVector3Array = PackedVector3Array()
		for ring: PackedVector3Array in rows:
			var p: Vector3 = ring[i_out] + Vector3(s * 0.0015, 0.0, 0.0)
			left.append(p + Vector3(0.0, 0.0, -0.013))
			right.append(p + Vector3(0.0, 0.0, 0.013))
		SkaterParts.part(upper, side + "BoardShortsStripeMesh", SkaterParts.facing_grid([left, right], Vector3(s, 0.0, 0.0)),
				Vector3.ZERO, mats, "bottom_trim")


# --- shared: waist, loose legs --------------------------------------------------------------------------------

## Closed rounded end of a knee piece (metres past the knee joint).
const KNEE_E: float = 0.055
const BELT_LOOP_ANGLES: Array = [0.8, -0.8, 2.15, -2.15, PI]
const METAL_DEFAULT: Color = Color(0.82, 0.78, 0.62)
## Cargo pocket on the outer-front thigh (thigh-space y, centre angle, half angle, bulge); flap above it.
const POCKET_Y0: float = -0.125
const POCKET_Y1: float = -0.285
const POCKET_A: float = 1.2
const POCKET_HA: float = 0.5
const POCKET_BULGE: float = 0.024
## Leg profiles: rows [d, grow, floor half width, floor depth]. d = metres down the leg from the hip joint; the
## cloth section is the skin section plus grow, but at least the floor (baggy cut).
const CARGO_PROF: Array = [
	[-0.1, 0.012, 0.0, 0.0], [0.0, 0.018, 0.085, 0.092], [0.2, 0.02, 0.09, 0.098], [0.4, 0.024, 0.093, 0.1],
]
const JEANS_PROF: Array = [
	[-0.1, 0.012, 0.0, 0.0], [0.0, 0.016, 0.085, 0.09], [0.2, 0.018, 0.088, 0.094], [0.4, 0.024, 0.088, 0.094],
	[0.5, 0.028, 0.083, 0.09], [0.62, 0.024, 0.074, 0.082], [0.74, 0.018, 0.064, 0.072],
]
const JOGGER_PROF: Array = [
	[-0.1, 0.012, 0.0, 0.0], [0.0, 0.016, 0.0, 0.0], [0.2, 0.02, 0.0, 0.0], [0.4, 0.024, 0.0, 0.0],
	[0.5, 0.026, 0.0, 0.0], [0.57, 0.03, 0.0, 0.0], [0.62, 0.028, 0.0, 0.0], [0.655, 0.0115, 0.0, 0.0],
]


## Fabric metrics at distance d: [grow, floor half width, floor depth], linear between the rows of `p`.
static func _prof(p: Array, d: float) -> Array:
	var first: Array = p[0]
	if d <= float(first[0]):
		return [first[1], first[2], first[3]]
	for i: int in p.size() - 1:
		var a: Array = p[i]
		var b: Array = p[i + 1]
		if d <= float(b[0]):
			var t: float = (d - float(a[0])) / (float(b[0]) - float(a[0]))
			return [lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t), lerpf(float(a[3]), float(b[3]), t)]
	var last: Array = p[p.size() - 1]
	return [last[1], last[2], last[3]]


## Point of a loose leg's cloth at LowerLeg/UpperLeg-space height y and angle a (0 = front). thigh: the piece hangs on
## the UpperLeg (y runs down to and past the knee); else on the LowerLeg (y up to +KNEE_E above the knee). Past the
## knee the cloth closes in a rounded end. extra stands the point off the cloth.
static func _leg_pt(secs: Array, thigh: bool, ul: float, prof: Array, y: float, a: float, extra: float = 0.0) -> Vector3:
	var over: float = (-y - ul) if thigh else y
	var d: float = -y if thigh else ul - y
	var sec: Array = (SkaterParts.section_at(secs, y if thigh else minf(y, 0.0)) as Array).duplicate()
	var pr: Array = _prof(prof, d)
	var lift: float = smoothstep(-0.08, 0.04, d)
	sec[1] = maxf(float(sec[1]) + float(pr[0]), float(pr[1]) * lift)
	sec[2] = maxf(float(sec[2]) + float(pr[0]), float(pr[2]) * lift)
	sec[3] = maxf(float(sec[3]) + float(pr[0]), float(pr[2]) * lift)
	var p: Vector3 = SkaterParts.section_point(sec, a, extra)
	if over > 0.0:
		var k: float = sqrt(maxf(1.0 - pow(over / KNEE_E, 2.0), 0.0))
		p.x = lerpf(float(sec[6]), p.x, k)
		p.z = lerpf(float(sec[5]), p.z, k)
	return Vector3(p.x, y, p.z)


## Closed grid of a loose leg piece. Row heights are Callables(a) -> y, listed top to bottom.
static func _leg_mesh(secs: Array, thigh: bool, ul: float, prof: Array, rows_y: Array, cols: int, extra: float, flip: bool = false) -> ArrayMesh:
	var rows: Array = []
	for fn: Callable in rows_y:
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols:
			var a: float = TAU * float(k) / float(cols)
			ring.append(_leg_pt(secs, thigh, ul, prof, float(fn.call(a)), a, extra))
		rows.append(ring)
	rows.reverse()
	return SkaterParts.grid(rows, true, flip)


static func _const_y(y: float) -> Callable:
	return func(_a: float) -> float: return y


static func _lerp_y(y0: float, hem: Callable, f: float) -> Callable:
	return func(a: float) -> float: return lerpf(y0, float(hem.call(a)), f)


## Rows from y_top down to the knee (UpperLeg space) and then the rounded end past the knee.
static func _thigh_rows(ul: float, y_top: float, n: int) -> Array:
	var rows: Array = []
	for i: int in n + 1:
		rows.append(_const_y(lerpf(y_top, -ul, float(i) / float(n))))
	for o: float in [0.4, 0.75, 0.93, 0.995]:
		rows.append(_const_y(-ul - KNEE_E * o))
	return rows


## Rows of the lower leg: the rounded end above the knee, then down to the hem.
static func _calf_rows(hem: Callable, n: int) -> Array:
	var rows: Array = []
	for o: float in [0.995, 0.93, 0.75, 0.4]:
		rows.append(_const_y(KNEE_E * o))
	for i: int in n + 1:
		rows.append(_lerp_y(0.0, hem, float(i) / float(n)))
	return rows


## Closed polyline round a loose leg piece at heights y_of(a) (for hems and folds).
static func _leg_line(secs: Array, thigh: bool, ul: float, prof: Array, y_of: Callable, extra: float, cols: int = 36) -> PackedVector3Array:
	var pts: PackedVector3Array = PackedVector3Array()
	for k: int in cols + 1:
		var a: float = TAU * float(k) / float(cols)
		pts.append(_leg_pt(secs, thigh, ul, prof, float(y_of.call(a)), a, extra))
	return pts


static func _tube_part(parent: Node3D, part_name: String, pts: PackedVector3Array, r: float, mats: Dictionary, key: String) -> void:
	var radii: PackedFloat32Array = PackedFloat32Array()
	radii.resize(pts.size())
	radii.fill(r)
	SkaterParts.part(parent, part_name, SkaterParts.tube(pts, radii, 6), Vector3.ZERO, mats, key)


## Seat over the pelvis (Hips) up to top_y with a waistband of band_h in band_key, and a lining round the low waist
## (Spine) so a bent spine never shows skin. Same construction as the board shorts.
## The seat's crotch: the code pelvis pinches in to a point under the thigh roots, where the legs' tubes close over
## it. With a thigh raised high (method, crouch) the leg tube swings off the groin crease, so the seat's lowest
## sections keep most of the width of the hips just above them (a gusset), and a last section past the skin's end
## closes it. Returns the new section list.
static func _crotch(seat: Array, pelvis: Array) -> Array:
	var out: Array = []
	var ref: Array = SkaterParts.section_at(pelvis, float(pelvis[0][0]) + GUSSET_REF)
	for sec0: Array in seat:
		var sec: Array = sec0.duplicate()
		if float(sec[0]) < float(pelvis[0][0]) + GUSSET_REF:
			for c: int in [1, 2, 3]:
				sec[c] = maxf(float(sec[c]), float(ref[c]) * GUSSET_WIDTH)
		out.append(sec)
	var gusset: Array = (out[0] as Array).duplicate()
	gusset[0] = float(gusset[0]) - 0.008
	gusset[1] = float(gusset[1]) * 0.6
	out.push_front(gusset)
	return out


static func _waist(rig: Dictionary, mats: Dictionary, prefix: String, top_y: float, grow: float, band_h: float, band_key: String) -> void:
	var hips: Node3D = rig["Hips"]
	var base: float = float(rig["rest_y"]["Hips"])
	var pelvis: Array = rig["sections"]["pelvis"]
	var seat: Array = AnimeOutfit.clip(pelvis, float(pelvis[0][0]), top_y - base)
	seat = _crotch(seat, pelvis)
	SkaterParts.part(hips, prefix + "SeatMesh", SkaterParts.loft(seat, 36, grow), Vector3.ZERO, mats, "bottom")
	SkaterParts.part(hips, prefix + "WaistbandMesh", SkaterParts.loft(AnimeOutfit.clip(pelvis, top_y - band_h - base, top_y - base),
			36, grow + 0.003), Vector3.ZERO, mats, band_key)
	var spine_y: float = float(rig["rest_y"]["Spine"])
	var waist: Array = rig["sections"]["waist"]
	var band_low: float = top_y - band_h - spine_y
	SkaterParts.part(rig["Spine"], prefix + "WaistMesh", SkaterParts.loft(AnimeOutfit.clip(waist, float(waist[0][0]), band_low), 32,
			grow + 0.001), Vector3.ZERO, mats, "bottom")
	SkaterParts.part(rig["Spine"], prefix + "WaistBandLiningMesh", SkaterParts.loft(AnimeOutfit.clip(waist, band_low, top_y - spine_y),
			32, grow + 0.001), Vector3.ZERO, mats, band_key)


## Belt loops: short rods standing proud of the waistband at the given angles.
static func _loops(rig: Dictionary, mats: Dictionary, prefix: String, top_y: float, grow: float, key: String) -> void:
	var base: float = float(rig["rest_y"]["Hips"])
	var pelvis: Array = rig["sections"]["pelvis"]
	for i: int in BELT_LOOP_ANGLES.size():
		var pts: PackedVector3Array = PackedVector3Array()
		for j: int in 3:
			var y: float = top_y + 0.002 - 0.034 * float(j) / 2.0
			pts.append(SkaterParts.section_point(SkaterParts.section_at(pelvis, y - base), float(BELT_LOOP_ANGLES[i]), grow))
		var rr: PackedFloat32Array = PackedFloat32Array([0.0045, 0.0045, 0.0045])
		SkaterParts.part(rig["Hips"], "%sBeltLoop%dMesh" % [prefix, i], SkaterParts.tube_capped(pts, rr, 6), Vector3.ZERO, mats, key)


## Outer thigh point row for a flat patch: width across z at the outer side line.
static func _side_line(secs: Array, thigh: bool, ul: float, prof: Array, s: float, y0: float, y1: float, n: int, extra: float) -> PackedVector3Array:
	var pts: PackedVector3Array = PackedVector3Array()
	for i: int in n + 1:
		pts.append(_leg_pt(secs, thigh, ul, prof, lerpf(y0, y1, float(i) / float(n)), s * PI * 0.5, extra))
	return pts


## A stripe lying on the outer side of a leg piece, half_w wide.
static func _side_stripe(parent: Node3D, part_name: String, pts: PackedVector3Array, s: float, half_w: float, mats: Dictionary, key: String) -> void:
	var left: PackedVector3Array = PackedVector3Array()
	var right: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in pts:
		left.append(p + Vector3(0.0, 0.0, -half_w))
		right.append(p + Vector3(0.0, 0.0, half_w))
	SkaterParts.part(parent, part_name, SkaterParts.facing_grid([left, right], Vector3(s, 0.0, 0.0)), Vector3.ZERO, mats, key)


# --- cargo shorts ---------------------------------------------------------------------------------------------

## Edge distance (m) of the cargo pocket at thigh-space y and angle a on side s: 0 on the outline, grows inwards.
static func _pocket_edge(y: float, a: float, s: float) -> float:
	var da: float = absf(a - s * POCKET_A)
	var across: float = (1.0 - da / POCKET_HA) * 0.05
	return minf(across, minf(y - POCKET_Y1, POCKET_Y0 - y))


static func _pocket_bulge(y: float, a: float, s: float) -> float:
	return POCKET_BULGE * smoothstep(0.0, 1.0, clampf(_pocket_edge(y, a, s) / 0.009, 0.0, 1.0))


## Knee-length roomy cargo shorts: seat with a belt and belt loops, straight wide legs to the knee with a turned hem,
## and on each outer thigh a bellows pocket with a flap (pointed, stitched, buttoned).
static func cargo_shorts(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	_mats(mats)
	Wardrobe.mat(mats, "bottom_metal", METAL_DEFAULT)
	var hips: Node3D = rig["Hips"]
	var base: float = float(rig["rest_y"]["Hips"])
	var pelvis: Array = rig["sections"]["pelvis"]
	_waist(rig, mats, "Cargo", SHORTS_TOP_Y, SHORTS_GROW, 0.026, "bottom")
	# Belt in the trim colour over the waistband, loops over it, a buckle with a tail at the front.
	var belt_g: float = SHORTS_GROW + 0.0075
	SkaterParts.part(hips, "CargoBeltMesh", SkaterParts.loft(AnimeOutfit.clip(pelvis, SHORTS_TOP_Y - 0.03 - base, SHORTS_TOP_Y - 0.006 - base),
			36, belt_g), Vector3.ZERO, mats, "bottom_trim")
	_loops(rig, mats, "Cargo", SHORTS_TOP_Y, belt_g + 0.0025, "bottom")
	var front: Array = SkaterParts.section_at(pelvis, SHORTS_TOP_Y - 0.018 - base)
	SkaterParts.part(hips, "CargoBuckleMesh", SkaterParts.box(Vector3(0.03, 0.026, 0.006)),
			SkaterParts.section_point(front, 0.0, belt_g + 0.003), mats, "bottom_metal")
	SkaterParts.part(hips, "CargoBuckleHoleMesh", SkaterParts.box(Vector3(0.018, 0.014, 0.004)),
			SkaterParts.section_point(front, 0.0, belt_g + 0.0065), mats, "bottom_trim")
	var tail: PackedVector3Array = PackedVector3Array()
	for i: int in 6:
		var t: float = float(i) / 5.0
		tail.append(SkaterParts.section_point(SkaterParts.section_at(pelvis, SHORTS_TOP_Y - 0.018 - base), 0.13 + 0.3 * t, belt_g + 0.0045))
	var tr: PackedFloat32Array = PackedFloat32Array([0.0042, 0.0042, 0.0042, 0.0042, 0.0042, 0.0042])
	SkaterParts.part(hips, "CargoBeltTailMesh", SkaterParts.tube_capped(tail, tr, 6), Vector3.ZERO, mats, "bottom_trim")
	# Legs.
	var secs: Array = rig["sections"]["thigh"]
	var ul: float = float(rig["lengths"]["upper_leg"])
	var y_hem: float = -0.965 * ul
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		var s: float = sd[1]
		var upper: Node3D = rig[side + "UpperLeg"]
		var rows: Array = []
		for i: int in 17:
			rows.append(_const_y(lerpf(0.2 * ul, y_hem, float(i) / 16.0)))
		SkaterParts.part(upper, side + "CargoLegMesh", _leg_mesh(secs, true, ul, CARGO_PROF, rows, 32, 0.0), Vector3.ZERO, mats, "bottom")
		SkaterParts.part(upper, side + "CargoLiningMesh", _leg_mesh(secs, true, ul, CARGO_PROF, rows.slice(rows.size() - 8), 32, 0.0, true),
				Vector3.ZERO, mats, "bottom_dark")
		var hem: PackedVector3Array = _leg_line(secs, true, ul, CARGO_PROF, _const_y(y_hem), 0.002)
		_tube_part(upper, side + "CargoHemMesh", hem, 0.0042, mats, "bottom_dark")
		_tube_part(upper, side + "CargoHemStitchMesh", _leg_line(secs, true, ul, CARGO_PROF, _const_y(y_hem + 0.017), 0.0016), 0.0013,
				mats, "bottom_dark")
		_cargo_pocket(upper, side, s, secs, ul, mats)


static func _cargo_pocket(upper: Node3D, side: String, s: float, secs: Array, ul: float, mats: Dictionary) -> void:
	var prof: Array = CARGO_PROF
	var ac: float = s * POCKET_A
	# Pocket bag: a patch on the leg that swells into a box with rounded edges.
	var rows: Array = []
	var nv: int = 14
	var nu: int = 14
	for i: int in nv + 1:
		var y: float = lerpf(POCKET_Y0, POCKET_Y1, float(i) / float(nv))
		var row: PackedVector3Array = PackedVector3Array()
		for j: int in nu + 1:
			var a: float = ac + POCKET_HA * (2.0 * float(j) / float(nu) - 1.0)
			row.append(_leg_pt(secs, true, ul, prof, y, a, 0.0012 + _pocket_bulge(y, a, s)))
		rows.append(row)
	SkaterParts.part(upper, side + "CargoPocketMesh", SkaterParts.facing_grid(rows, Vector3(s, 0.0, 0.0)), Vector3.ZERO, mats, "bottom")
	# Flap: from the pocket's top edge, a pointed lower edge.
	var f_top: float = POCKET_Y0 + 0.004
	var f_ha: float = POCKET_HA + 0.03
	var flap_y: Callable = func(a: float) -> float:
		return POCKET_Y0 - 0.058 - 0.02 * (1.0 - clampf(absf(a - ac) / f_ha, 0.0, 1.0))
	var frows: Array = []
	for i: int in 7:
		var f: float = float(i) / 6.0
		var row2: PackedVector3Array = PackedVector3Array()
		for j: int in 17:
			var a2: float = ac + f_ha * (2.0 * float(j) / 16.0 - 1.0)
			var y2: float = lerpf(f_top, float(flap_y.call(a2)), f)
			row2.append(_leg_pt(secs, true, ul, prof, y2, a2, 0.0016 + _pocket_bulge(clampf(y2, POCKET_Y1, POCKET_Y0), a2, s) + 0.0042))
		frows.append(row2)
	SkaterParts.part(upper, side + "CargoFlapMesh", SkaterParts.facing_grid(frows, Vector3(s, 0.0, 0.0)), Vector3.ZERO, mats, "bottom")
	var edge: PackedVector3Array = PackedVector3Array()
	for j: int in 25:
		var a3: float = ac + f_ha * (2.0 * float(j) / 24.0 - 1.0)
		var y3: float = float(flap_y.call(a3))
		edge.append(_leg_pt(secs, true, ul, prof, y3, a3, 0.0016 + _pocket_bulge(clampf(y3, POCKET_Y1, POCKET_Y0), a3, s) + 0.0048))
	_tube_part(upper, side + "CargoFlapEdgeMesh", edge, 0.0022, mats, "bottom_trim")
	var bp: Vector3 = _leg_pt(secs, true, ul, prof, POCKET_Y0 - 0.062, ac, 0.0016 + _pocket_bulge(POCKET_Y0 - 0.062, ac, s) + 0.0075)
	SkaterParts.part(upper, side + "CargoButtonMesh", SkaterParts.sphere_small(0.0055), bp, mats, "bottom_trim")


# --- skate jeans ----------------------------------------------------------------------------------------------

## Jeans hem height (LowerLeg y) at angle a: lower at the sides, riding up over the shoe at the front and back.
static func _jeans_hem(a: float) -> float:
	var c: float = cos(a)
	return -0.312 + 0.09 * pow(maxf(c, 0.0), 1.8) + 0.05 * pow(maxf(-c, 0.0), 3.0)


## Back-pocket outline point: u across (0..1), v down (0..1), centred at x = xc on the pelvis at the back.
static func _back_pocket_pt(pelvis: Array, base: float, xc: float, u: float, v: float, grow: float) -> Vector3:
	var y_top: float = 0.945
	var y_bot: float = 0.862 - 0.016 * (1.0 - absf(2.0 * u - 1.0))
	var y: float = lerpf(y_top, y_bot, v)
	var sec: Array = SkaterParts.section_at(pelvis, y - base)
	var x: float = xc + 0.05 * (2.0 * u - 1.0) * lerpf(1.0, 0.92, v)
	return SkaterParts.section_point(sec, SkaterParts.section_angle_for_x(sec, x, false), grow)


## Baggy straight-leg jeans (90s skate): low-slung waistband with belt loops, a button and fly stitching, patch back
## pockets with stitching, wide straight legs that stack in ruffles over the shoe, and a clean knee (the old faded patch read as a stain).
static func skate_jeans(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	_mats(mats)
	var base_col: Color = (mats["bottom"] as StandardMaterial3D).albedo_color
	Wardrobe.mat(mats, "bottom_fade", base_col.lerp(Color(0.85, 0.9, 1.0), 0.2))
	Wardrobe.mat(mats, "bottom_metal", METAL_DEFAULT)
	var hips: Node3D = rig["Hips"]
	var base: float = float(rig["rest_y"]["Hips"])
	var pelvis: Array = rig["sections"]["pelvis"]
	var top_y: float = SHORTS_TOP_Y
	_waist(rig, mats, "Jeans", top_y, SHORTS_GROW, 0.03, "bottom")
	_loops(rig, mats, "Jeans", top_y, SHORTS_GROW + 0.0075, "bottom")
	var g: float = SHORTS_GROW + 0.003
	var rail: PackedVector3Array = PackedVector3Array()
	for k: int in 37:
		var a: float = TAU * float(k) / 36.0
		rail.append(SkaterParts.section_point(SkaterParts.section_at(pelvis, top_y - 0.027 - base), a, g + 0.0012))
	_tube_part(hips, "JeansWaistStitchMesh", rail, 0.0015, mats, "bottom_trim")
	var front: Array = SkaterParts.section_at(pelvis, top_y - 0.015 - base)
	SkaterParts.part(hips, "JeansButtonMesh", SkaterParts.sphere_small(0.0072), SkaterParts.section_point(front, 0.0, g + 0.004), mats,
			"bottom_metal")
	# Fly: a J stitch from the button down the front, and the front pocket arcs.
	var fly: PackedVector3Array = PackedVector3Array()
	for i: int in 9:
		var t: float = float(i) / 8.0
		var y: float = lerpf(top_y - 0.03, top_y - 0.125, t)
		fly.append(SkaterParts.section_point(SkaterParts.section_at(pelvis, y - base), 0.085 * pow(t, 2.2), g + 0.0012))
	_tube_part(hips, "JeansFlyStitchMesh", fly, 0.0013, mats, "bottom_trim")
	for s: float in [-1.0, 1.0]:
		var arc: PackedVector3Array = PackedVector3Array()
		for i: int in 11:
			var t: float = float(i) / 10.0
			var y: float = lerpf(top_y - 0.03, top_y - 0.1, sin(t * PI * 0.5))
			arc.append(SkaterParts.section_point(SkaterParts.section_at(pelvis, y - base), s * lerpf(0.5, 1.05, 1.0 - cos(t * PI * 0.5)), g + 0.0012))
		_tube_part(hips, ("Left" if s < 0.0 else "Right") + "JeansPocketArcMesh", arc, 0.0013, mats, "bottom_trim")
		# Back pocket and its stitching.
		var xc: float = s * 0.062
		var rows: Array = []
		for i: int in 7:
			var row: PackedVector3Array = PackedVector3Array()
			for j: int in 9:
				row.append(_back_pocket_pt(pelvis, base, xc, float(j) / 8.0, float(i) / 6.0, SHORTS_GROW + 0.0028))
			rows.append(row)
		var side_name: String = "Left" if s < 0.0 else "Right"
		SkaterParts.part(hips, side_name + "JeansBackPocketMesh", SkaterParts.facing_grid(rows, Vector3(0.0, 0.0, 1.0)), Vector3.ZERO, mats, "bottom")
		var outline: PackedVector3Array = PackedVector3Array()
		for j: int in 9:
			outline.append(_back_pocket_pt(pelvis, base, xc, 0.0, float(j) / 8.0, SHORTS_GROW + 0.0042))
		for j: int in 9:
			var u: float = float(j) / 8.0
			outline.append(_back_pocket_pt(pelvis, base, xc, u, 1.0, SHORTS_GROW + 0.0042))
		for j: int in 9:
			outline.append(_back_pocket_pt(pelvis, base, xc, 1.0, 1.0 - float(j) / 8.0, SHORTS_GROW + 0.0042))
		_tube_part(hips, side_name + "JeansBackPocketStitchMesh", outline, 0.0013, mats, "bottom_trim")
	# Legs.
	var thigh: Array = rig["sections"]["thigh"]
	var calf: Array = rig["sections"]["calf"]
	var ul: float = float(rig["lengths"]["upper_leg"])
	var hem: Callable = GarmentBottoms._jeans_hem
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		var upper: Node3D = rig[side + "UpperLeg"]
		var lower: Node3D = rig[side + "LowerLeg"]
		SkaterParts.part(upper, side + "JeansThighMesh", _leg_mesh(thigh, true, ul, JEANS_PROF, _thigh_rows(ul, 0.2 * ul, 12), 32, 0.0),
				Vector3.ZERO, mats, "bottom")
		SkaterParts.part(lower, side + "JeansShinMesh", _leg_mesh(calf, false, ul, JEANS_PROF, _calf_rows(hem, 13), 32, 0.002),
				Vector3.ZERO, mats, "bottom")
		_knee_ball(lower, side + "JeansKneeMesh", calf, ul, JEANS_PROF, mats)
		# Hem fold and two stacked ruffles above it, wobbling a little round the leg.
		_tube_part(lower, side + "JeansHemMesh", _leg_line(calf, false, ul, JEANS_PROF, hem, 0.0035), 0.0085, mats, "bottom")
		_tube_part(lower, side + "JeansHemStitchMesh", _leg_line(calf, false, ul, JEANS_PROF, func(a: float) -> float: return _jeans_hem(a) + 0.014,
				0.0078), 0.0013, mats, "bottom_trim")
		for r: int in 1:
			var rise: float = 0.03 + 0.034 * float(r)
			var ph: float = 1.3 * float(r) + (0.7 if side == "Left" else 0.0)
			_tube_part(lower, "%sJeansStack%dMesh" % [side, r], _leg_line(calf, false, ul, JEANS_PROF,
					func(a: float) -> float: return _jeans_hem(a) + rise + 0.007 * sin(3.0 * a + ph), 0.0055), 0.0082, mats, "bottom")


## A ball at the knee joint (a little smaller than the legs) so a bent knee never opens the cloth.
static func _knee_ball(lower: Node3D, part_name: String, calf: Array, ul: float, prof: Array, mats: Dictionary) -> void:
	var sec: Array = (SkaterParts.section_at(calf, 0.0) as Array).duplicate()
	var pr: Array = _prof(prof, ul)
	var hw: float = maxf(float(sec[1]) + float(pr[0]), float(pr[1]))
	var dp: float = maxf(float(sec[2]) + float(pr[0]), float(pr[2]))
	var ball: MeshInstance3D = SkaterParts.part(lower, part_name, SkaterParts.sphere(1.0), Vector3(0.0, 0.0, float(sec[5])), mats, "bottom")
	ball.scale = Vector3(hw * 0.97, minf(hw, dp) * 0.97, dp * 0.97)


# --- joggers --------------------------------------------------------------------------------------------------

## Tapered joggers: soft elastic waistband with a drawstring, roomy thighs narrowing to a blouse above the ankle cuff,
## ribbed cuffs, and a side stripe down each leg.
static func joggers(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	_mats(mats)
	var hips: Node3D = rig["Hips"]
	var base: float = float(rig["rest_y"]["Hips"])
	var pelvis: Array = rig["sections"]["pelvis"]
	_waist(rig, mats, "Jogger", SHORTS_TOP_Y + 0.004, SHORTS_GROW, 0.04, "bottom")
	var top_y: float = SHORTS_TOP_Y + 0.004
	for yo: float in [0.012, 0.024]:
		var seam: PackedVector3Array = PackedVector3Array()
		for k: int in 37:
			seam.append(SkaterParts.section_point(SkaterParts.section_at(pelvis, top_y - yo - base), TAU * float(k) / 36.0, SHORTS_GROW + 0.0045))
		_tube_part(hips, "JoggerWaistRib%dMesh" % int(yo * 100.0), seam, 0.0016, mats, "bottom")
	# Drawstring knot and tails at the front.
	var front: Array = SkaterParts.section_at(pelvis, top_y - 0.02 - base)
	SkaterParts.part(hips, "JoggerKnotMesh", SkaterParts.sphere_small(0.0058), SkaterParts.section_point(front, 0.0, SHORTS_GROW + 0.0075), mats,
			"bottom_trim")
	for s: float in [-1.0, 1.0]:
		var tail: PackedVector3Array = PackedVector3Array()
		for i: int in 6:
			var t: float = float(i) / 5.0
			var sec: Array = SkaterParts.section_at(pelvis, top_y - 0.02 - 0.075 * pow(t, 1.1) - base)
			tail.append(SkaterParts.section_point(sec, s * (0.04 + 0.1 * t), SHORTS_GROW + 0.0075))
		var tr: PackedFloat32Array = PackedFloat32Array([0.0026, 0.0026, 0.0026, 0.0025, 0.0024, 0.0023])
		SkaterParts.part(hips, ("Left" if s < 0.0 else "Right") + "JoggerStringMesh", SkaterParts.tube_capped(tail, tr, 6), Vector3.ZERO, mats,
				"bottom_trim")
	# Legs.
	var thigh: Array = rig["sections"]["thigh"]
	var calf: Array = rig["sections"]["calf"]
	var ul: float = float(rig["lengths"]["upper_leg"])
	var y_end: float = -0.255  ## the cuff clears the shoe tongue (0.034 above the ankle joint at -0.33)
	var cuff_lo: float = -0.275
	var hem: Callable = _const_y(y_end)
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		var s: float = sd[1]
		var upper: Node3D = rig[side + "UpperLeg"]
		var lower: Node3D = rig[side + "LowerLeg"]
		SkaterParts.part(upper, side + "JoggerThighMesh", _leg_mesh(thigh, true, ul, JOGGER_PROF, _thigh_rows(ul, 0.2 * ul, 12), 32, 0.0),
				Vector3.ZERO, mats, "bottom")
		SkaterParts.part(lower, side + "JoggerShinMesh", _leg_mesh(calf, false, ul, JOGGER_PROF, _calf_rows(hem, 12), 32, 0.002),
				Vector3.ZERO, mats, "bottom")
		_knee_ball(lower, side + "JoggerKneeMesh", calf, ul, JOGGER_PROF, mats)
		# Ribbed ankle cuff: a short band below the gathered leg, in rings.
		var cuff_rows: Array = []
		for i: int in 4:
			cuff_rows.append(_const_y(lerpf(y_end + 0.006, cuff_lo, float(i) / 3.0)))
		SkaterParts.part(lower, side + "JoggerCuffMesh", _leg_mesh(calf, false, ul, JOGGER_PROF, cuff_rows, 32, 0.0045), Vector3.ZERO, mats,
				"bottom")
		for y: float in [-0.257, -0.2655, -0.274]:
			_tube_part(lower, "%sJoggerCuffRib%dMesh" % [side, int(-y * 1000.0)], _leg_line(calf, false, ul, JOGGER_PROF, _const_y(y), 0.0065),
					0.0036, mats, "bottom_dark")
		# Side stripe: thigh piece down to the knee, then the shin piece to the cuff.
		_side_stripe(upper, side + "JoggerStripeUpperMesh", _side_line(thigh, true, ul, JOGGER_PROF, s, 0.03, -ul, 16, 0.0016), s, 0.0105, mats,
				"bottom_trim")
		_side_stripe(lower, side + "JoggerStripeLowerMesh", _side_line(calf, false, ul, JOGGER_PROF, s, 0.0, y_end + 0.004, 14, 0.0046), s, 0.0105,
				mats, "bottom_trim")
