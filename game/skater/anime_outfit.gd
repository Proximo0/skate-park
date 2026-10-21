class_name AnimeOutfit
extends RefCounted
## Body and outfit parts of the anime surf-skater girl: a slim adult torso lofted from elliptical sections (pelvis,
## waist and ribcage, each with its own width, front and back depth), two soft bust forms under BodySway pivots, a
## sporty teal bikini (bralette top with coral trim and matching bottoms), striped crew socks, wristbands and real
## skate shoes (skate_shoe). Static builders called by PlaceholderSkater with the joints to attach to and the palette
## materials. Section tables are in body space (metres above the soles at rest) and converted to each joint's space.

# Skate shoe geometry, foot joint space: ankle at the origin, toe toward -Z, sole bottom at -ANKLE_HEIGHT.
const SHOE_BASE_Y: float = -0.09  ## top of the sole
const SHOE_TOE_Z: float = -0.224
const SHOE_HEEL_Z: float = 0.083
const SHOE_ROUND: float = 0.77
## Upper cross sections: z, half width, height above SHOE_BASE_Y.
const SHOE_SECTIONS: Array = [
	[-0.222, 0.006, 0.008], [-0.214, 0.024, 0.024], [-0.2, 0.037, 0.036], [-0.18, 0.046, 0.044],
	[-0.15, 0.051, 0.05], [-0.12, 0.052, 0.056], [-0.09, 0.05, 0.068], [-0.06, 0.047, 0.086],
	[-0.03, 0.045, 0.105], [0.0, 0.046, 0.118], [0.03, 0.046, 0.118], [0.055, 0.042, 0.105],
	[0.07, 0.034, 0.08], [0.078, 0.018, 0.04], [0.081, 0.005, 0.01],
]
const TOE_CAP_END_Z: float = -0.125

# --- torso ----------------------------------------------------------------------------------------------------
# Sections: [y, half width, front depth, back depth, power, z centre]. y in body space (soles at 0, rest pose).
## Pelvis, on the Hips joint: crotch, rounded hips with the glutes behind, up to the waist.
const PELVIS: Array = [
	[0.752, 0.02, 0.03, 0.03, 1.0, 0.0], [0.765, 0.062, 0.056, 0.062, 0.9, 0.0],
	[0.79, 0.126, 0.082, 0.098, 0.85, 0.0], [0.835, 0.163, 0.096, 0.118, 0.8, 0.0],
	[0.88, 0.157, 0.089, 0.107, 0.82, 0.0], [0.93, 0.132, 0.082, 0.082, 0.9, -0.002],
	[0.985, 0.101, 0.073, 0.066, 1.0, -0.006], [1.02, 0.099, 0.071, 0.064, 1.0, -0.006],
	[1.035, 0.05, 0.035, 0.035, 1.0, -0.006],
]
## Waist, on the Spine joint, bridging the pelvis and the ribcage so a bent spine stays closed.
const WAIST: Array = [
	[0.9, 0.07, 0.05, 0.05, 1.0, 0.0], [0.925, 0.124, 0.08, 0.079, 0.92, -0.003],
	[0.96, 0.108, 0.076, 0.071, 1.0, -0.006], [0.99, 0.102, 0.074, 0.067, 1.0, -0.006],
	[1.04, 0.109, 0.079, 0.071, 1.0, -0.004], [1.09, 0.116, 0.084, 0.074, 1.0, -0.002],
	[1.11, 0.07, 0.05, 0.05, 1.0, 0.0],
]
## Ribcage, shoulders and neck base, on the Chest joint. Narrow ribs (about 70% of the hips), flat back, sloped
## trapezius from the shoulder line up into the neck.
const CHEST: Array = [
	[0.99, 0.06, 0.045, 0.045, 1.0, -0.004], [1.0, 0.1, 0.072, 0.066, 1.0, -0.004],
	[1.05, 0.117, 0.086, 0.076, 1.0, -0.002], [1.1, 0.123, 0.089, 0.078, 1.0, 0.0],
	[1.15, 0.127, 0.087, 0.079, 1.0, 0.0], [1.2, 0.132, 0.081, 0.078, 0.95, 0.0],
	[1.245, 0.137, 0.073, 0.073, 0.9, 0.0], [1.275, 0.131, 0.064, 0.066, 0.9, 0.0],
	[1.3, 0.109, 0.052, 0.057, 0.9, 0.002], [1.32, 0.078, 0.044, 0.048, 1.0, 0.003],
	[1.337, 0.052, 0.041, 0.043, 1.0, 0.004], [1.36, 0.045, 0.041, 0.041, 1.0, 0.004],
]
## Bust: two soft modest forms, each under its own pivot (BodySway_BustL/R) at its root on the ribcage.
const BUST_ROOT: Vector3 = Vector3(0.062, 1.125, -0.065)  ## body space, +x side; mirrored for the left
const BUST_CENTER: Vector3 = Vector3(0.006, -0.006, -0.016)  ## form centre in pivot space (+x side)
const BUST_RADII: Vector3 = Vector3(0.054, 0.05, 0.04)
const CUP_GROW: float = 0.0045
const TOP_BAND: Vector2 = Vector2(1.04, 1.074)  ## bralette under-band, body y
## Bikini bottom: leg-cut height at the front/back centre and at the sides, and the waistband height.
const BOTTOM_CROTCH_Y: float = 0.77
const BOTTOM_SIDE_Y: float = 0.872
const BOTTOM_TOP_Y: float = 0.905


## Sections moved down by base (the joint's rest height) and smoothed.
static func local_sections(table: Array, base: float, sub: int = 3) -> Array:
	var out: Array = []
	for s: Array in table:
		var row: Array = s.duplicate()
		row[0] = float(row[0]) - base
		out.append(row)
	return SkaterParts.smooth_sections(out, sub)


## Rest height of a joint above the body root (sums the joint positions up to the body root).
static func rest_y(node: Node3D) -> float:
	var y: float = 0.0
	var n: Node3D = node
	while n != null and n.get_parent() is Node3D:
		y += n.position.y
		n = n.get_parent() as Node3D
	return y


## Skin torso (pelvis, waist, ribcage with shoulders and collarbones), the bust forms and the bikini.
static func build_torso(hips: Node3D, spine: Node3D, chest: Node3D, mats: Dictionary) -> void:
	var hips_y: float = rest_y(hips)
	var chest_y: float = rest_y(chest)
	var pelvis: Array = local_sections(PELVIS, hips_y)
	SkaterParts.part(hips, "HipsMesh", SkaterParts.loft(pelvis, 28), Vector3.ZERO, mats, "skin")
	SkaterParts.part(spine, "SpineMesh", SkaterParts.loft(local_sections(WAIST, rest_y(spine)), 28), Vector3.ZERO, mats, "skin")
	var ribs: Array = local_sections(CHEST, chest_y)
	SkaterParts.part(chest, "ChestMesh", SkaterParts.loft(ribs, 32), Vector3.ZERO, mats, "skin")
	_collarbones(chest, ribs, chest_y, mats)
	_bikini_top(chest, ribs, chest_y, mats)
	_bikini_bottom(hips, pelvis, hips_y, mats)


## Two faint collarbone ridges from the pit of the neck out toward the shoulders.
static func _collarbones(chest: Node3D, ribs: Array, base: float, mats: Dictionary) -> void:
	for s: float in [-1.0, 1.0]:
		var pts: PackedVector3Array = PackedVector3Array()
		var radii: PackedFloat32Array = PackedFloat32Array()
		for i: int in 7:
			var t: float = float(i) / 6.0
			var y: float = lerpf(1.322, 1.296, t) + 0.006 * sin(PI * t) - base
			var sec: Array = SkaterParts.section_at(ribs, y)
			var x: float = s * lerpf(0.018, 0.1, t)
			pts.append(SkaterParts.section_point(sec, SkaterParts.section_angle_for_x(sec, x, true), -0.001))
			radii.append(lerpf(0.0045, 0.0058, sin(PI * t)))
		SkaterParts.part(chest, ("Left" if s < 0.0 else "Right") + "CollarboneMesh", SkaterParts.tube_capped(pts, radii, 8),
				Vector3.ZERO, mats, "skin")


## Sporty bralette: an under-band round the ribs, a cup over each bust form (under the same BodySway pivot, so the
## fabric follows it), coral piping round the cups and the band, and straps over the shoulders to the back band.
static func _bikini_top(chest: Node3D, ribs: Array, base: float, mats: Dictionary) -> void:
	for s: float in [-1.0, 1.0]:
		var side: String = "L" if s < 0.0 else "R"
		var root: Vector3 = Vector3(s * BUST_ROOT.x, BUST_ROOT.y - base, BUST_ROOT.z)
		var pivot: Node3D = SkaterParts.joint(chest, "BodySway_Bust" + side, root)
		var c: Vector3 = Vector3(s * BUST_CENTER.x, BUST_CENTER.y, BUST_CENTER.z)
		var turn: Basis = Basis(Vector3.UP, -s * 0.16)  ## each form looks a little outward
		SkaterParts.part(pivot, "Bust" + side + "Mesh", _bust_mesh(BUST_RADII, turn), c, mats, "skin")
		var cup_rows: Array = _cup_rows(BUST_RADII + Vector3.ONE * CUP_GROW, turn, s)
		SkaterParts.part(pivot, "BikiniCup" + side + "Mesh", SkaterParts.facing_grid(cup_rows, Vector3.FORWARD), c, mats, "top")
		# Piping along the cup's two slanted edges, meeting at the strap.
		var trim_rows: Array = _cup_rows(BUST_RADII + Vector3.ONE * (CUP_GROW + 0.0012), turn, s)
		var first: int = 4  ## the lowest rows run round the form's rim, under the band: no piping there
		var pts: PackedVector3Array = PackedVector3Array()
		for i: int in range(first, trim_rows.size()):
			pts.append(c + (trim_rows[i] as PackedVector3Array)[0])
		for i: int in range(trim_rows.size() - 1, first - 1, -1):
			var row: PackedVector3Array = trim_rows[i]
			pts.append(c + row[row.size() - 1])
		var radii: PackedFloat32Array = PackedFloat32Array()
		for i: int in pts.size():
			radii.append(0.0032)
		SkaterParts.part(pivot, "BikiniCupTrim" + side + "Mesh", SkaterParts.tube_capped(pts, radii, 6), Vector3.ZERO, mats, "top_trim")
	# Under-band and its piping.
	var band: Array = _clip(ribs, TOP_BAND.x - base, TOP_BAND.y - base)
	SkaterParts.part(chest, "BikiniTopMesh", SkaterParts.loft(band, 32, 0.0035), Vector3.ZERO, mats, "top")
	SkaterParts.part(chest, "BikiniBandTrimMesh", SkaterParts.loft_ring(ribs, TOP_BAND.x - base, 0.0045, 0.0034, 40),
			Vector3.ZERO, mats, "top_trim")
	# Straps: up from the top of each cup, over the shoulder, down to the back band.
	for s: float in [-1.0, 1.0]:
		var spec: Array = [
			[1.16, 0.074, true], [1.2, 0.077, true], [1.25, 0.08, true], [1.29, 0.082, true],
			[1.31, 0.082, false], [1.27, 0.08, false], [1.2, 0.077, false], [1.14, 0.074, false], [1.08, 0.072, false],
		]
		var pts: PackedVector3Array = PackedVector3Array()
		var radii: PackedFloat32Array = PackedFloat32Array()
		for sp: Array in spec:
			var sec: Array = SkaterParts.section_at(ribs, float(sp[0]) - base)
			var x: float = s * float(sp[1])
			pts.append(SkaterParts.section_point(sec, SkaterParts.section_angle_for_x(sec, x, bool(sp[2]), 0.004), 0.004))
			radii.append(0.0055)
		# Over the top of the shoulder.
		var top: Array = SkaterParts.section_at(ribs, 1.318 - base)
		pts.insert(4, Vector3(s * 0.08, 1.318 - base + 0.006, float(top[5])))
		pts = SkaterParts.smooth3d(pts, 3)
		radii = PackedFloat32Array()
		for i: int in pts.size():
			radii.append(0.0055)
		SkaterParts.part(chest, ("Left" if s < 0.0 else "Right") + "BikiniStrapMesh", SkaterParts.tube_capped(pts, radii, 8),
				Vector3.ZERO, mats, "top")


## A unit-sphere point shaped into a soft natural bust form: the upper slope runs back into the chest, the lower
## half is fuller and rounder. Front is -Z.
static func _bust_shape(p: Vector3, radii: Vector3) -> Vector3:
	var q: Vector3 = p
	if q.z < 0.0:
		var up: float = maxf(q.y, 0.0)
		q.z *= 1.0 - 0.6 * up  ## top slope
		q.y -= 0.12 * (1.0 - absf(q.y)) * -q.z  ## apex a little low
	return Vector3(q.x * radii.x, q.y * radii.y, q.z * radii.z)


## Rows of the triangle cup patch over the front of a bust form: full width at the bottom, narrowing to a point at
## the top, a little toward the outside where the strap starts. s = +1 right side, -1 left.
static func _cup_rows(radii: Vector3, turn: Basis, s: float) -> Array:
	var rows: Array = []
	var n: int = 14
	var cols: int = 12
	for i: int in n + 1:
		var y: float = lerpf(-0.97, 0.96, float(i) / float(n))
		var disc: float = sqrt(maxf(1.0 - y * y, 0.0))
		var half: float = 0.06 + (1.0 - y) * 0.85
		var xc: float = s * 0.12 * (y + 1.0) * 0.5
		var x0: float = maxf(-disc, xc - half)
		var x1: float = minf(disc, xc + half)
		var row: PackedVector3Array = PackedVector3Array()
		for k: int in cols + 1:
			var x: float = lerpf(x0, x1, float(k) / float(cols))
			var z: float = -sqrt(maxf(1.0 - x * x - y * y, 0.0))
			row.append(turn * _bust_shape(Vector3(x, y, z), radii))
		rows.append(row)
	return rows


## Closed bust form mesh (rings from the bottom pole to the top), turned by `turn`.
static func _bust_mesh(radii: Vector3, turn: Basis) -> ArrayMesh:
	var rows: Array = []
	var lat_n: int = 12
	var lon_n: int = 24
	for i: int in lat_n + 1:
		var lat: float = lerpf(-PI * 0.5, PI * 0.5, float(i) / float(lat_n))
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in lon_n:
			var a: float = TAU * float(k) / float(lon_n)
			var p: Vector3 = Vector3(cos(lat) * sin(a), sin(lat), -cos(lat) * cos(a))
			ring.append(turn * _bust_shape(p, radii))
		rows.append(ring)
	return SkaterParts.grid(rows, true)


## Smoothed sections cut to [y0, y1], with exact end sections.
static func _clip(secs: Array, y0: float, y1: float) -> Array:
	var out: Array = [SkaterParts.section_at(secs, y0)]
	for sec: Array in secs:
		if float(sec[0]) > y0 and float(sec[0]) < y1:
			out.append(sec)
	out.append(SkaterParts.section_at(secs, y1))
	return out


## Leg-cut height round the pelvis at angle a: low at the front and back centre, high over the hips.
static func _leg_cut_y(a: float) -> float:
	return lerpf(BOTTOM_CROTCH_Y, BOTTOM_SIDE_Y, pow(absf(sin(a)), 1.6))


## Matching bikini bottoms: a panel over the pelvis between the leg cut and a low waistband, a gusset under the
## crotch, and coral piping round the waistband and the leg openings.
static func _bikini_bottom(hips: Node3D, pelvis: Array, base: float, mats: Dictionary) -> void:
	var grow: float = 0.005
	var sides: int = 40
	var rows: Array = []
	var levels: int = 10
	for v: int in levels + 1:
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in sides:
			var a: float = TAU * float(k) / float(sides)
			var y: float = lerpf(_leg_cut_y(a), BOTTOM_TOP_Y + 0.008 * cos(a + PI), float(v) / float(levels)) - base
			ring.append(SkaterParts.section_point(SkaterParts.section_at(pelvis, y), a, grow))
		rows.append(ring)
	SkaterParts.part(hips, "BikiniBottomMesh", SkaterParts.grid(rows, true), Vector3.ZERO, mats, "bottom")
	var gusset: Array = _clip(pelvis, float(pelvis[0][0]), BOTTOM_CROTCH_Y + 0.006 - base)
	SkaterParts.part(hips, "BikiniGussetMesh", SkaterParts.loft(gusset, sides, grow), Vector3.ZERO, mats, "bottom")
	for which: int in 2:
		var pts: PackedVector3Array = PackedVector3Array()
		var radii: PackedFloat32Array = PackedFloat32Array()
		for k: int in sides + 1:
			var a: float = TAU * float(k) / float(sides)
			var y: float = (_leg_cut_y(a) if which == 0 else BOTTOM_TOP_Y + 0.008 * cos(a + PI)) - base
			pts.append(SkaterParts.section_point(SkaterParts.section_at(pelvis, y), a, grow + 0.001))
			radii.append(0.0034 if which == 0 else 0.0042)
		SkaterParts.part(hips, ("BikiniLegTrimMesh" if which == 0 else "BikiniWaistTrimMesh"), SkaterParts.tube(pts, radii, 6),
				Vector3.ZERO, mats, "bottom_trim")


# --- limbs ----------------------------------------------------------------------------------------------------
# Limb sections run down the bone (local -Y): [t, half width, front depth, back depth, power, z centre], t = fraction
# of the bone length (0 at the joint, 1 at the next one, negative above it).

const THIGH: Array = [
	[-0.17, 0.04, 0.04, 0.045, 1.0, 0.0], [-0.1, 0.06, 0.06, 0.066, 1.0, 0.0], [0.0, 0.077, 0.074, 0.08, 1.0, 0.0],
	[0.2, 0.078, 0.08, 0.078, 1.0, -0.002], [0.45, 0.071, 0.075, 0.069, 1.0, -0.003], [0.7, 0.059, 0.06, 0.055, 1.0, -0.004],
	[0.88, 0.05, 0.05, 0.047, 1.0, -0.004], [1.0, 0.047, 0.047, 0.045, 1.0, -0.002], [1.1, 0.03, 0.03, 0.03, 1.0, 0.0],
]
const CALF: Array = [
	[-0.1, 0.03, 0.03, 0.03, 1.0, 0.0], [-0.03, 0.045, 0.046, 0.044, 1.0, 0.0], [0.08, 0.045, 0.041, 0.05, 1.0, 0.0],
	[0.28, 0.049, 0.038, 0.06, 1.0, 0.0], [0.5, 0.041, 0.034, 0.046, 1.0, 0.0], [0.75, 0.033, 0.03, 0.033, 1.0, 0.0],
	[0.92, 0.031, 0.029, 0.03, 1.0, 0.0], [1.04, 0.029, 0.027, 0.027, 1.0, 0.0], [1.12, 0.015, 0.015, 0.015, 1.0, 0.0],
]
const UPPER_ARM_SECTIONS: Array = [
	[-0.12, 0.022, 0.022, 0.022, 1.0, 0.0], [-0.04, 0.04, 0.04, 0.04, 1.0, 0.0], [0.15, 0.039, 0.04, 0.038, 1.0, 0.0],
	[0.45, 0.034, 0.033, 0.036, 1.0, 0.002], [0.8, 0.03, 0.029, 0.031, 1.0, 0.0], [1.0, 0.029, 0.028, 0.029, 1.0, 0.0],
	[1.08, 0.016, 0.016, 0.016, 1.0, 0.0],
]
const FOREARM_SECTIONS: Array = [
	[-0.08, 0.018, 0.018, 0.018, 1.0, 0.0], [0.0, 0.029, 0.028, 0.029, 1.0, 0.0], [0.2, 0.031, 0.03, 0.029, 1.0, 0.0],
	[0.55, 0.026, 0.023, 0.023, 1.0, 0.0], [0.88, 0.023, 0.018, 0.018, 1.0, 0.0], [1.0, 0.022, 0.017, 0.017, 1.0, 0.0],
	[1.06, 0.012, 0.01, 0.01, 1.0, 0.0],
]


## Limb sections at bone length `length`, in the joint's space (y = -t * length), smoothed.
static func limb_sections(table: Array, length: float, sub: int = 3) -> Array:
	var out: Array = []
	for s: Array in table:
		var row: Array = s.duplicate()
		row[0] = -float(row[0]) * length
		out.append(row)
	return SkaterParts.smooth_sections(out, sub)


## Upper and lower arm skin: elliptical lofts with a round deltoid cap and a soft elbow.
static func build_arm_skin(upper: Node3D, lower: Node3D, side: String, upper_len: float, lower_len: float, mats: Dictionary) -> void:
	var delt: MeshInstance3D = SkaterParts.part(upper, side + "ShoulderMesh", SkaterParts.sphere(1.0), Vector3(0.0, -0.012, 0.0), mats, "skin")
	delt.scale = Vector3(0.043, 0.048, 0.043)
	SkaterParts.part(upper, side + "UpperArmMesh", SkaterParts.loft(limb_sections(UPPER_ARM_SECTIONS, upper_len), 16, 0.0, true),
			Vector3.ZERO, mats, "skin")
	SkaterParts.part(lower, side + "ElbowMesh", SkaterParts.sphere(0.029), Vector3.ZERO, mats, "skin")
	SkaterParts.part(lower, side + "LowerArmMesh", SkaterParts.loft(limb_sections(FOREARM_SECTIONS, lower_len), 16, 0.0, true),
			Vector3.ZERO, mats, "skin")


## Thigh and calf skin: a slender thigh, a defined knee with a small kneecap, the calf fullest in its upper third and
## a fine ankle.
static func build_leg_skin(upper: Node3D, lower: Node3D, side: String, upper_len: float, lower_len: float, mats: Dictionary) -> void:
	SkaterParts.part(upper, side + "UpperLegMesh", SkaterParts.loft(limb_sections(THIGH, upper_len), 16, 0.0, true),
			Vector3.ZERO, mats, "skin")
	SkaterParts.part(lower, side + "KneeMesh", SkaterParts.sphere(0.045), Vector3(0.0, 0.0, 0.0), mats, "skin")
	var cap: MeshInstance3D = SkaterParts.part(lower, side + "KneecapMesh", SkaterParts.sphere(1.0), Vector3(0.0, -0.008, -0.032), mats, "skin")
	cap.scale = Vector3(0.024, 0.028, 0.016)
	SkaterParts.part(lower, side + "LowerLegMesh", SkaterParts.loft(limb_sections(CALF, lower_len), 16, 0.0, true),
			Vector3.ZERO, mats, "skin")


## Mint wristband round the wrist end of the forearm, with a trim line at its hand edge.
static func build_wristband(lower: Node3D, side: String, lower_len: float, mats: Dictionary) -> void:
	var secs: Array = limb_sections(FOREARM_SECTIONS, lower_len)
	var y0: float = -0.86 * lower_len
	var y1: float = -1.0 * lower_len + 0.004
	SkaterParts.part(lower, side + "WristbandMesh", SkaterParts.loft(_clip_desc(secs, y0, y1), 16, 0.0045, true), Vector3.ZERO, mats, "band")
	SkaterParts.part(lower, side + "WristbandTrimMesh", SkaterParts.loft_ring(secs, y1 + 0.003, 0.0058, 0.0025, 20), Vector3.ZERO, mats, "trim")


## Limb sections (listed top to bottom) cut to y0 >= y >= y1.
static func _clip_desc(secs: Array, y0: float, y1: float) -> Array:
	var out: Array = [SkaterParts.section_at(secs, y0)]
	for sec: Array in secs:
		if float(sec[0]) < y0 and float(sec[0]) > y1:
			out.append(sec)
	out.append(SkaterParts.section_at(secs, y1))
	return out


## High-crew striped sock over the lower calf and ankle, down into the shoe collar.
static func build_sock(lower: Node3D, side: String, lower_len: float, mats: Dictionary) -> void:
	var secs: Array = limb_sections(CALF, lower_len)
	var top: float = -lower_len + 0.15  ## cuff about 0.27 above the soles
	SkaterParts.part(lower, side + "SockMesh", SkaterParts.loft(_clip_desc(secs, top, -lower_len - 0.01), 16, 0.003, true),
			Vector3.ZERO, mats, "sock")
	SkaterParts.part(lower, side + "SockCuffMesh", SkaterParts.loft_ring(secs, top, 0.004, 0.004, 24), Vector3.ZERO, mats, "sock")
	var keys: Array = ["sock_stripe", "sock_stripe2", "sock_stripe"]
	for i: int in 3:
		SkaterParts.part(lower, side + "SockStripe%dMesh" % i, SkaterParts.loft_ring(secs, top - 0.014 - 0.015 * float(i), 0.0035, 0.0042, 24),
				Vector3.ZERO, mats, keys[i])


# --- skate shoe -------------------------------------------------------------------------------------------

## Half width and height above the sole of the upper at z (linear between the sections).
static func shoe_dims(z: float) -> Vector2:
	for i: int in SHOE_SECTIONS.size() - 1:
		var a: Array = SHOE_SECTIONS[i]
		var b: Array = SHOE_SECTIONS[i + 1]
		if z <= float(b[0]):
			var t: float = clampf((z - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.00001), 0.0, 1.0)
			return Vector2(lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t))
	return Vector2(0.005, 0.01)


## Foot-shaped outline (x, z) of the sole, grown by `grow`.
static func shoe_outline(grow: float, n: int = 44) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var half: float = (SHOE_HEEL_Z - SHOE_TOE_Z) * 0.5 + grow
	var zc: float = (SHOE_HEEL_Z + SHOE_TOE_Z) * 0.5
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var c: float = cos(a)
		var sn: float = sin(a)
		var z: float = zc - signf(c) * pow(absf(c), 0.85) * half
		var t: float = clampf((z - SHOE_TOE_Z) / (SHOE_HEEL_Z - SHOE_TOE_Z), 0.0, 1.0)
		var w: float = 0.0565 - 0.011 * smoothstep(0.35, 0.95, t) + grow
		out.append(Vector2(signf(sn) * pow(absf(sn), 0.8) * w, z))
	return out


## One cross-section ring of the upper (z fixed), K points from the top round the right side to the bottom and back.
static func _shoe_ring(z: float, hw: float, h: float, grow: float, count: int) -> PackedVector3Array:
	var ring: PackedVector3Array = PackedVector3Array()
	for j: int in count:
		var a: float = TAU * float(j) / float(count)
		var u: float = cos(a)
		var v: float = sin(a)
		var x: float = (hw + grow) * signf(v) * pow(absf(v), SHOE_ROUND)
		var y: float = SHOE_BASE_Y - grow * 0.5
		if u > 0.0:
			y = SHOE_BASE_Y + (h + grow) * pow(u, SHOE_ROUND)
		ring.append(Vector3(x, y, z))
	return ring


static func _shoe_rows() -> Array:
	var pts: PackedVector3Array = PackedVector3Array()
	for sct: Array in SHOE_SECTIONS:
		pts.append(Vector3(float(sct[0]), float(sct[1]), float(sct[2])))
	return Array(SkaterParts.smooth3d(pts, 3))


## x of the upper's surface at height y and z (right side, positive x).
static func shoe_side_x(z: float, y: float) -> float:
	var d: Vector2 = shoe_dims(z)
	var u: float = pow(clampf((y - SHOE_BASE_Y) / maxf(d.y, 0.001), 0.0, 1.0), 1.0 / SHOE_ROUND)
	return d.x * pow(sqrt(maxf(1.0 - u * u, 0.0)), SHOE_ROUND)


## Real-looking skate shoe: padded collar and tongue, laces, stitched toe cap, vulcanised gum sole with a foxing stripe,
## and a side panel stripe. Sole bottom at -ankle_height; the parts share a "<side>ShoeMesh" node.
static func skate_shoe(foot: Node3D, side: String, ankle_height: float, mats: Dictionary) -> Node3D:
	var shoe: Node3D = SkaterParts.joint(foot, side + "ShoeMesh", Vector3.ZERO)
	var bottom: float = -ankle_height
	# Gum rubber sole and the foxing stripe round the base of the upper.
	SkaterParts.part(shoe, "SoleMesh", SkaterParts.slab(shoe_outline(0.003), bottom, bottom + 0.03, 0.005), Vector3.ZERO, mats, "sole")
	SkaterParts.part(shoe, "FoxingMesh", SkaterParts.slab(shoe_outline(-0.0015), bottom + 0.025, bottom + 0.044, 0.004),
			Vector3.ZERO, mats, "foxing")

	# Upper: a lofted body, and a toe cap loft slightly proud of it.
	var count: int = 20
	var rows: Array = []
	var cap_rows: Array = []
	for d: Vector3 in _shoe_rows():
		rows.append(_shoe_ring(d.x, d.y, d.z, 0.0, count))
		if d.x <= TOE_CAP_END_Z:
			cap_rows.append(_shoe_ring(d.x, d.y, d.z, 0.0035, count))
	SkaterParts.part(shoe, "UpperMesh", SkaterParts.grid(rows, true), Vector3.ZERO, mats, "shoes")
	var cap_z: float = (cap_rows[cap_rows.size() - 1] as PackedVector3Array)[0].z
	var last: Vector2 = shoe_dims(cap_z)
	cap_rows.append(_shoe_ring(cap_z + 0.0025, last.x, last.y, 0.0012, count))
	SkaterParts.part(shoe, "ToeCapMesh", SkaterParts.grid(cap_rows, true), Vector3.ZERO, mats, "toe")

	# Toe cap stitching: dashes along the cap's back edge over the top and down both sides.
	var dashes: Array = []
	var dash_n: int = 15
	for i: int in dash_n:
		var a0: float = deg_to_rad(-98.0 + 14.0 * float(i))
		var a1: float = a0 + deg_to_rad(8.0)
		var p0: Vector3 = _edge_point(cap_z + 0.0075, a0)
		var p1: Vector3 = _edge_point(cap_z + 0.0075, a1)
		dashes.append([SkaterParts.tube(PackedVector3Array([p0, p1]), PackedFloat32Array([0.0014, 0.0014]), 4), Transform3D.IDENTITY])
	SkaterParts.part(shoe, "StitchMesh", SkaterParts.merge(dashes), Vector3.ZERO, mats, "stitch")

	# Laces: raised bars across the tongue, with a small knot.
	var bars: Array = []
	for i: int in 5:
		var z: float = -0.1 + 0.021 * float(i)
		var dm: Vector2 = shoe_dims(z)
		var slope: float = atan2(shoe_dims(z + 0.01).y - shoe_dims(z - 0.01).y, 0.02)
		var y: float = SHOE_BASE_Y + dm.y + 0.002
		var bar: Mesh = SkaterParts.capsule_small(0.0058, 0.064)
		bars.append([bar, Transform3D(Basis(Vector3.RIGHT, -slope) * Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, y, z))])
	var kz: float = -0.0
	var kd: Vector2 = shoe_dims(kz)
	bars.append([SkaterParts.sphere_small(0.0075), Transform3D(Basis.IDENTITY, Vector3(0.0, SHOE_BASE_Y + kd.y + 0.006, kz - 0.012))])
	for s: float in [-1.0, 1.0]:
		bars.append([SkaterParts.capsule_small(0.0042, 0.04), Transform3D(Basis(Vector3.BACK, s * 1.0) * Basis(Vector3.RIGHT, 0.0),
				Vector3(s * 0.016, SHOE_BASE_Y + kd.y + 0.004, kz - 0.016))])
	SkaterParts.part(shoe, "LacesMesh", SkaterParts.merge(bars), Vector3.ZERO, mats, "laces")

	# Padded tongue and chunky collar.
	var tongue: MeshInstance3D = SkaterParts.part(shoe, "TongueMesh", SkaterParts.capsule(0.02, 0.1), Vector3(0.0, 0.018, -0.042),
			mats, "tongue")
	tongue.scale = Vector3(1.55, 1.0, 0.75)
	tongue.rotation.x = 0.1
	var collar: MeshInstance3D = SkaterParts.part(shoe, "CollarMesh", SkaterParts.torus(0.024, 0.048), Vector3(0.0, 0.017, 0.012),
			mats, "collar")
	collar.scale = Vector3(1.0, 1.0, 1.15)
	# Heel tab.
	var tab: MeshInstance3D = SkaterParts.part(shoe, "HeelTabMesh", SkaterParts.sphere(0.02), Vector3(0.0, 0.0, 0.074), mats, "shoe_panel")
	tab.scale = Vector3(0.7, 1.4, 0.35)

	# Side panel stripe on both sides: a bold diagonal band from the lace line down toward the heel.
	var path: Array = [Vector2(-0.05, 0.012), Vector2(-0.018, -0.012), Vector2(0.012, -0.036), Vector2(0.04, -0.058), Vector2(0.056, -0.07)]
	var line: PackedVector3Array = PackedVector3Array()
	for p: Vector2 in path:
		line.append(Vector3(p.x, p.y, 0.0))
	line = SkaterParts.smooth3d(line, 4)
	for sgn: float in [-1.0, 1.0]:
		var left: PackedVector3Array = PackedVector3Array()
		var right: PackedVector3Array = PackedVector3Array()
		for i: int in line.size():
			var q: Vector3 = line[i]
			var q2: Vector3 = line[mini(i + 1, line.size() - 1)]
			var q1: Vector3 = line[maxi(i - 1, 0)]
			var tz: float = q2.x - q1.x
			var ty: float = q2.y - q1.y
			var tl: float = maxf(sqrt(tz * tz + ty * ty), 0.00001)
			var az: float = ty / tl * 0.011
			var ay: float = -tz / tl * 0.011
			left.append(Vector3(sgn * (shoe_side_x(q.x - az, q.y - ay) + 0.0015), q.y - ay, q.x - az))
			right.append(Vector3(sgn * (shoe_side_x(q.x + az, q.y + ay) + 0.0015), q.y + ay, q.x + az))
		SkaterParts.part(shoe, "SidePanel" + ("Left" if sgn < 0.0 else "Right") + "Mesh", SkaterParts.facing_grid([left, right], Vector3(sgn, 0.0, 0.0)),
				Vector3.ZERO, mats, "shoe_panel")
	return shoe


## Point on the upper's outline at angle a (0 = top, + toward +x) at section z, a hair outside the surface.
static func _edge_point(z: float, a: float) -> Vector3:
	var d: Vector2 = shoe_dims(z)
	var u: float = cos(a)
	var v: float = sin(a)
	return Vector3((d.x + 0.0045) * signf(v) * pow(absf(v), SHOE_ROUND), SHOE_BASE_Y + (d.y + 0.0045) * pow(maxf(u, 0.0), SHOE_ROUND), z)
