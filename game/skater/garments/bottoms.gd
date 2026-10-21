class_name GarmentBottoms
extends RefCounted
## Bottom garments (slot "bottom"). Contract and registration: see Wardrobe (game/skater/wardrobe.gd).
## Built: bottom_bikini (female; the male body gets board shorts), bottom_board_shorts.
## Palette keys: "bottom" (main fabric) and "bottom_trim" (piping, waistband, side stripe, drawstring).

const STUBS: PackedStringArray = ["bottom_cargo_shorts", "bottom_skate_jeans", "bottom_joggers"]
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


static func builders() -> Dictionary:
	return {
		"bottom_bikini": GarmentBottoms.bikini,
		"bottom_board_shorts": GarmentBottoms.board_shorts,
		"bottom_cargo_shorts": GarmentBottoms._stub.bind("bottom_cargo_shorts"),
		"bottom_skate_jeans": GarmentBottoms._stub.bind("bottom_skate_jeans"),
		"bottom_joggers": GarmentBottoms._stub.bind("bottom_joggers"),
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
	return PackedStringArray()


static func _stub(rig: Dictionary, body_type: String, mats: Dictionary, id: String) -> void:
	var fallback: Callable = GarmentBottoms.board_shorts if body_type == AnimeOutfit.MALE else GarmentBottoms.bikini
	Wardrobe.stub(rig, body_type, mats, "bottom", id, fallback)


static func _mats(mats: Dictionary) -> void:
	Wardrobe.mat(mats, "bottom", BOTTOM_DEFAULT)
	Wardrobe.mat(mats, "bottom_trim", TRIM_DEFAULT)


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
	var gusset: Array = (seat[0] as Array).duplicate()
	gusset[0] = float(gusset[0]) - 0.008  ## past the skin's end, so the crotch stays inside the seat
	seat.push_front(gusset)
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
		var hp: PackedVector3Array = hem_ring.duplicate()
		hp.append(hem_ring[0])
		var hr: PackedFloat32Array = PackedFloat32Array()
		hr.resize(hp.size())
		hr.fill(0.0055)
		SkaterParts.part(upper, side + "BoardShortsHemMesh", SkaterParts.tube(hp, hr, 6), Vector3.ZERO, mats, "bottom_trim")
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
