class_name AnimeOutfit
extends RefCounted
## Skin of the anime skater bodies (female and male): torso lofted from elliptical sections (pelvis, waist and
## ribcage, each with its own width, front and back depth), the neck, arm and leg lofts, and on the female body two
## soft bust forms under BodySway pivots. Clothing is NOT built here: garments live in game/skater/garments/ and are
## chosen through Wardrobe. This file exposes the skin section tables and surface helpers that garments use to sit
## just outside the skin: skin_sections(), joint_sections(), chest_front_point(), bust_height(), clip(), clip_desc().
## Section tables are in body space (metres above the soles at rest) and converted to each joint's space.

const FEMALE: String = "female"
const MALE: String = "male"

# --- torso ----------------------------------------------------------------------------------------------------
# Sections: [y, half width, front depth, back depth, power, z centre]. y in body space (soles at 0, rest pose).
## Pelvis, on the Hips joint: crotch, rounded hips with the glutes behind, up to the waist.
const PELVIS: Array = [
	[0.752, 0.02, 0.03, 0.03, 1.0, 0.0], [0.765, 0.062, 0.056, 0.062, 0.9, 0.0],
	[0.79, 0.126, 0.082, 0.098, 0.85, 0.0], [0.835, 0.163, 0.096, 0.118, 0.8, 0.0],
	[0.88, 0.157, 0.089, 0.107, 0.82, 0.0], [0.93, 0.132, 0.082, 0.082, 0.9, -0.002],
	[0.985, 0.098, 0.071, 0.064, 1.0, -0.006], [1.015, 0.086, 0.06, 0.055, 1.0, -0.006],
	[1.035, 0.04, 0.03, 0.03, 1.0, -0.006],
]
## Waist, on the Spine joint, bridging the pelvis and the ribcage so a bent spine stays closed. Its top tucks well
## inside the ribcage (and the pelvis top inside the waist), so a bent spine never pushes it out through the skin
## or clothes above.
const WAIST: Array = [
	[0.9, 0.07, 0.05, 0.05, 1.0, 0.0], [0.925, 0.124, 0.08, 0.079, 0.92, -0.003],
	[0.96, 0.108, 0.076, 0.071, 1.0, -0.006], [0.99, 0.102, 0.074, 0.067, 1.0, -0.006],
	[1.04, 0.098, 0.062, 0.064, 1.0, -0.004], [1.075, 0.074, 0.04, 0.05, 1.0, -0.002],
	[1.11, 0.04, 0.025, 0.03, 1.0, 0.0],
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
## Neck, on the Neck joint: [y local to the Neck joint, half width, front, back, power, z centre].
const NECK: Array = [
	[-0.035, 0.047, 0.043, 0.043, 1.0, 0.004], [0.02, 0.0455, 0.041, 0.042, 1.0, 0.002],
	[0.075, 0.044, 0.04, 0.041, 1.0, -0.002], [0.1, 0.035, 0.03, 0.03, 1.0, -0.004],
]

## Male torso: narrow hips with flat glutes, a straight waist, a broad lean ribcage with a flat chest, wide shoulders
## that reach past the shoulder joints (the deltoids cover the arm roots), and a thicker neck.
const PELVIS_M: Array = [
	[0.752, 0.022, 0.032, 0.032, 1.0, 0.0], [0.765, 0.066, 0.058, 0.06, 0.9, 0.0],
	[0.79, 0.122, 0.08, 0.088, 0.85, 0.0], [0.835, 0.148, 0.09, 0.098, 0.82, 0.0],
	[0.88, 0.146, 0.087, 0.094, 0.85, 0.0], [0.93, 0.136, 0.084, 0.084, 0.9, -0.002],
	[0.985, 0.122, 0.078, 0.072, 0.95, -0.006], [1.015, 0.11, 0.066, 0.06, 1.0, -0.006],
	[1.035, 0.05, 0.034, 0.034, 1.0, -0.006],
]
const WAIST_M: Array = [
	[0.9, 0.08, 0.055, 0.055, 1.0, 0.0], [0.925, 0.134, 0.083, 0.081, 0.92, -0.003],
	[0.96, 0.128, 0.081, 0.075, 0.95, -0.006], [0.99, 0.127, 0.081, 0.073, 0.95, -0.006],
	[1.04, 0.13, 0.084, 0.074, 0.95, -0.004], [1.075, 0.118, 0.072, 0.064, 0.95, -0.002],
	[1.11, 0.06, 0.04, 0.04, 1.0, 0.0],
]
const CHEST_M: Array = [
	[0.99, 0.07, 0.05, 0.05, 1.0, -0.004], [1.0, 0.118, 0.078, 0.07, 1.0, -0.004],
	[1.05, 0.135, 0.088, 0.078, 0.95, -0.002], [1.1, 0.146, 0.094, 0.082, 0.9, 0.0],
	[1.15, 0.155, 0.099, 0.085, 0.86, 0.0], [1.2, 0.163, 0.098, 0.086, 0.84, 0.0],
	[1.245, 0.168, 0.088, 0.082, 0.82, 0.0], [1.275, 0.162, 0.076, 0.074, 0.84, 0.0],
	[1.3, 0.142, 0.064, 0.066, 0.86, 0.002], [1.32, 0.104, 0.056, 0.057, 0.95, 0.003],
	[1.337, 0.064, 0.052, 0.052, 1.0, 0.004], [1.36, 0.058, 0.05, 0.05, 1.0, 0.004],
]
const NECK_M: Array = [
	[-0.035, 0.058, 0.054, 0.054, 1.0, 0.004], [0.02, 0.056, 0.051, 0.052, 1.0, 0.002],
	[0.075, 0.053, 0.049, 0.05, 1.0, -0.002], [0.1, 0.042, 0.036, 0.036, 1.0, -0.004],
]

# --- bust (female) ----------------------------------------------------------------------------------------------
# Each bust form is a smooth height field over the ribcage's front surface, so it rises out of the skin with no seam:
# height BUST_HEIGHT at the apex, falling to zero (and a hair under the skin) at its rim. The rim's top reaches up to
# about 5 cm under the collarbones in a long soft slope (no shelf); the lower pole is fuller and rounder, ending in a
# soft crease on the under-band line. The forms stay on the front of the ribcage (outer rim inside the ribs' side)
# with a small gap between them. Each form hangs under its own BodySway_BustL/R pivot so secondary motion can sway
# it; the bikini cups follow the same field.
const BUST_APEX: Vector2 = Vector2(0.064, 1.142)  ## body space (x on the +x side, y)
const BUST_R_IN: float = 0.047  ## rim distance toward the centre line
const BUST_R_OUT: float = 0.05  ## rim distance toward the arm
const BUST_R_DOWN: float = 0.077  ## under-bust crease at about 1.065
const BUST_R_UP: float = 0.122  ## long upper slope, its top about 5 cm under the collarbones
const BUST_HEIGHT: float = 0.048
const BUST_SINK: float = 0.0025  ## the rim sits this far under the skin, so the patch edge never shows
const BUST_PIVOT_Y: float = 1.165  ## pivot height (body space): sway hinges above the apex, toward the upper root
const CUP_GROW: float = 0.0045
const SIDE_SINK: float = 0.004  ## extra sink of the bust skin's rim (and lift of the cups) toward the ribs' side
const TOP_BAND: Vector2 = Vector2(1.034, 1.066)  ## bralette under-band, body y (its top on the under-bust crease)
## Triangle cup outline in bust-field coordinates (shared by the skin split and the bikini cups): rows from
## CUP_BOTTOM_V (on the under-band) to CUP_TOP_V (the strap point), each row spanning cup_span(v).
const CUP_BOTTOM_V: float = -1.03
const CUP_TOP_V: float = 0.6
const CUP_TIP_U: float = 0.12
## Bust skin under the cup stops this far (in u) inside the cup's inner (x) and outer (y) edges; the visible skin
## outside runs on under the cup edge to meet it. More on the inside, where the form's wall is steep.
const CUP_SKIN_INSET: Vector2 = Vector2(0.15, 0.05)

static var _front_cache: Dictionary = {}


## The raw skin section table of a body part, in the units its builder uses. part: "pelvis", "waist", "chest" (body
## space y), "neck" (Neck-joint space y), "thigh", "calf", "upper_arm", "forearm" (t = fraction of the bone, see the
## limb tables below). body_type: "female" or "male".
static func skin_sections(part: String, body_type: String = FEMALE) -> Array:
	var m: bool = body_type == MALE
	match part:
		"pelvis": return PELVIS_M if m else PELVIS
		"waist": return WAIST_M if m else WAIST
		"chest": return CHEST_M if m else CHEST
		"neck": return NECK_M if m else NECK
		"thigh": return _scaled(THIGH, 1.06, 1.04) if m else THIGH
		"calf": return _scaled(CALF, 1.1, 1.08) if m else CALF
		"upper_arm": return _scaled(UPPER_ARM_SECTIONS, 1.2, 1.18) if m else UPPER_ARM_SECTIONS
		"forearm": return _scaled(FOREARM_SECTIONS, 1.14, 1.16) if m else FOREARM_SECTIONS
	push_warning("AnimeOutfit.skin_sections: unknown part " + part)
	return []


## Smoothed skin sections in the space of the joint each part hangs on, keyed by part name, ready for garments:
## pelvis on Hips, waist on Spine, chest on Chest, neck on Neck (y up); thigh on <Side>UpperLeg, calf on
## <Side>LowerLeg, upper_arm on <Side>UpperArm, forearm on <Side>LowerArm (listed top to bottom, y = -t * length).
## rest_y: rest heights of "Hips", "Spine", "Chest"; lengths: "upper_leg", "lower_leg", "upper_arm", "lower_arm".
static func joint_sections(body_type: String, rest_y: Dictionary, lengths: Dictionary) -> Dictionary:
	return {
		"pelvis": local_sections(skin_sections("pelvis", body_type), float(rest_y["Hips"])),
		"waist": local_sections(skin_sections("waist", body_type), float(rest_y["Spine"])),
		"chest": local_sections(skin_sections("chest", body_type), float(rest_y["Chest"])),
		"neck": SkaterParts.smooth_sections(skin_sections("neck", body_type), 3),
		"thigh": limb_sections(skin_sections("thigh", body_type), float(lengths["upper_leg"])),
		"calf": limb_sections(skin_sections("calf", body_type), float(lengths["lower_leg"])),
		"upper_arm": limb_sections(skin_sections("upper_arm", body_type), float(lengths["upper_arm"])),
		"forearm": limb_sections(skin_sections("forearm", body_type), float(lengths["lower_arm"])),
	}


## Table with half width scaled by kw and both depths by kd.
static func _scaled(table: Array, kw: float, kd: float) -> Array:
	var out: Array = []
	for s: Array in table:
		var row: Array = s.duplicate()
		row[1] = float(row[1]) * kw
		row[2] = float(row[2]) * kd
		row[3] = float(row[3]) * kd
		out.append(row)
	return out


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


## Skin torso (pelvis, waist, ribcage with shoulders and collarbones) and, on the female body, the bust forms under
## their BodySway_BustL/R pivots.
static func build_torso(hips: Node3D, spine: Node3D, chest: Node3D, mats: Dictionary, body_type: String = FEMALE) -> void:
	var chest_y: float = rest_y(chest)
	_torso_regions(hips, "Hips", "pelvis", rest_y(hips), body_type, mats, 28)
	_torso_regions(spine, "Spine", "waist", rest_y(spine), body_type, mats, 28)
	_torso_regions(chest, "Chest", "chest", chest_y, body_type, mats, 32)
	var ribs: Array = local_sections(skin_sections("chest", body_type), chest_y)
	_collarbones(chest, ribs, chest_y, mats, body_type)
	if body_type != MALE:
		_bust(chest, chest_y, mats)


## Body regions of each torso loft, body-space y ranges. The ends match the section tables.
const TORSO_REGIONS: Dictionary = {
	"pelvis": [["pelvis", 0.752, 0.905], ["hip_band", 0.905, 0.965], ["belly", 0.965, 1.035]],
	"waist": [["waist_low", 0.9, 0.965], ["waist", 0.965, 1.11]],
	"chest": [["under_bust", 0.99, 1.075], ["chest", 1.075, 1.25], ["chest_upper", 1.25, 1.31], ["neck_base", 1.31, 1.36]],
}
## Body regions of each limb loft, as t ranges (fraction of the bone, top to bottom). Regions get "_L"/"_R".
const LIMB_REGIONS: Dictionary = {
	"thigh": [["thigh_top", -0.17, -0.11], ["thigh_upper", -0.11, 0.45], ["thigh_lower", 0.45, 1.1]],
	"calf": [["calf", -0.1, 0.56], ["calf_low", 0.56, 0.9], ["ankle", 0.9, 1.12]],
	"upper_arm": [["shoulder", -0.12, 0.15], ["upper_arm", 0.15, 0.45], ["upper_arm_low", 0.45, 1.08]],
	"forearm": [["forearm", -0.08, 0.82], ["wrist", 0.82, 1.06]],
}
## Every skin region name (limb ones without the side suffix), for docs and tests.
const REGIONS: PackedStringArray = [
	"pelvis", "hip_band", "belly", "waist_low", "waist", "under_bust", "chest", "chest_upper", "neck_base", "bust",
	"neck", "head", "shoulder", "upper_arm", "upper_arm_low", "elbow", "forearm", "wrist", "hand",
	"thigh_top", "thigh_upper", "thigh_lower", "knee", "calf", "calf_low", "ankle",
]


static func _torso_regions(joint: Node3D, prefix: String, part: String, base: float, body_type: String, mats: Dictionary,
		sides: int) -> void:
	var cuts: Array = []
	for c: Array in TORSO_REGIONS[part]:
		cuts.append([c[0], float(c[1]) - base, float(c[2]) - base])
	SkaterParts.region_parts(joint, prefix, SkaterParts.loft_regions(local_sections(skin_sections(part, body_type), base), cuts, sides),
			"", mats, "skin")


static func _limb_regions(joint: Node3D, side: String, part: String, length: float, body_type: String, mats: Dictionary) -> void:
	var cuts: Array = []
	for c: Array in LIMB_REGIONS[part]:
		cuts.append([c[0], -float(c[1]) * length, -float(c[2]) * length])
	SkaterParts.region_parts(joint, side, SkaterParts.loft_regions(limb_sections(skin_sections(part, body_type), length), cuts, 16),
			"_" + side.left(1), mats, "skin")


## Neck skin on the Neck joint.
static func build_neck(neck: Node3D, mats: Dictionary, body_type: String = FEMALE) -> void:
	SkaterParts.tag_region(SkaterParts.part(neck, "NeckMesh", SkaterParts.loft(SkaterParts.smooth_sections(skin_sections("neck", body_type), 3), 18),
			Vector3.ZERO, mats, "skin"), "neck")


## Two faint collarbone ridges from the pit of the neck out toward the shoulders.
static func _collarbones(chest: Node3D, ribs: Array, base: float, mats: Dictionary, body_type: String) -> void:
	var reach: float = 0.118 if body_type == MALE else 0.1
	for s: float in [-1.0, 1.0]:
		var pts: PackedVector3Array = PackedVector3Array()
		var radii: PackedFloat32Array = PackedFloat32Array()
		for i: int in 7:
			var t: float = float(i) / 6.0
			var y: float = lerpf(1.322, 1.296, t) + 0.006 * sin(PI * t) - base
			var sec: Array = SkaterParts.section_at(ribs, y)
			var x: float = s * lerpf(0.018, reach, t)
			pts.append(SkaterParts.section_point(sec, SkaterParts.section_angle_for_x(sec, x, true), -0.001))
			radii.append(lerpf(0.0045, 0.0058, sin(PI * t)))
		SkaterParts.tag_region(SkaterParts.part(chest, ("Left" if s < 0.0 else "Right") + "CollarboneMesh",
				SkaterParts.tube_capped(pts, radii, 8), Vector3.ZERO, mats, "skin"), "chest_upper")


# --- chest front surface and the bust field ------------------------------------------------------------------

## Height of the bust field above the ribcage skin at body-space (|x|, y); -BUST_SINK outside the forms.
static func bust_height(x_abs: float, y: float) -> float:
	var dx: float = x_abs - BUST_APEX.x
	var dy: float = y - BUST_APEX.y
	var u: float = dx / (BUST_R_OUT if dx > 0.0 else BUST_R_IN)
	var v: float = dy / (BUST_R_UP if dy > 0.0 else BUST_R_DOWN)
	var d2: float = u * u + v * v
	if d2 >= 1.0:
		return -BUST_SINK
	var e: float = 0.78 + 1.5 * smoothstep(-0.3, 0.75, v)  ## full and round below, a long soft slope above
	return BUST_HEIGHT * pow(1.0 - d2, e) - BUST_SINK


## Cup outline at bust-field row v: Vector2(u at the inner edge, u at the outer edge). A rounded triangle: full width
## over the lower pole and the outer flank (the whole form below the apex is covered), narrowing to the strap point.
static func cup_span(v: float) -> Vector2:
	var k: float = clampf((v - CUP_BOTTOM_V) / (CUP_TOP_V - CUP_BOTTOM_V), 0.0, 1.0)
	var ko: float = clampf((v + 0.2) / (CUP_TOP_V + 0.2), 0.0, 1.0)  ## the outer side arcs round the flank to the tip
	var tip_l: float = CUP_TIP_U - 0.03  ## the tip keeps a little width (the strap's), so no row collapses to a point
	var tip_r: float = CUP_TIP_U + 0.03
	return Vector2(lerpf(-1.03, tip_l, pow(k, 1.5)), tip_r + (1.04 - tip_r) * sqrt(1.0 - ko * ko))


## Body-space x of the bust field at rim coordinate u (signed: + toward the arm) on side s.
static func bust_x(u: float, s: float) -> float:
	return s * (BUST_APEX.x + u * (BUST_R_OUT if u > 0.0 else BUST_R_IN))


## Body-space y of the bust field at rim coordinate v (+ up).
static func bust_y(v: float) -> float:
	return BUST_APEX.y + v * (BUST_R_UP if v > 0.0 else BUST_R_DOWN)


## Point of the ribcage's front skin at body-space (x, y), in body space, and its outward normal.
static func chest_skin(x: float, y: float, body_type: String = FEMALE) -> Array:
	var p: Vector3 = _chest_raw(x, y, body_type)
	var h: float = 0.002
	var dx: Vector3 = _chest_raw(x + h, y, body_type) - _chest_raw(x - h, y, body_type)
	var dy: Vector3 = _chest_raw(x, y + h, body_type) - _chest_raw(x, y - h, body_type)
	var n: Vector3 = dy.cross(dx).normalized()
	if n.z > 0.0:
		n = -n
	return [p, n]


static func _chest_raw(x: float, y: float, body_type: String) -> Vector3:
	if not _front_cache.has(body_type):
		_front_cache[body_type] = SkaterParts.smooth_sections(skin_sections("chest", body_type), 6)
	var sec: Array = SkaterParts.section_at(_front_cache[body_type], y)
	return SkaterParts.section_point(sec, SkaterParts.section_angle_for_x(sec, x, true))


## Body-space point on the front of the chest including the bust forms (female), lifted `lift` off the surface.
static func chest_front_point(x: float, y: float, lift: float, body_type: String = FEMALE) -> Vector3:
	var sn: Array = chest_skin(x, y, body_type)
	var h: float = bust_height(absf(x), y) if body_type != MALE else 0.0
	return (sn[0] as Vector3) + (sn[1] as Vector3) * (maxf(h, -BUST_SINK) + lift)


## Body-space position of the BodySway_Bust pivot on side s (+1 right, -1 left).
static func bust_pivot(s: float) -> Vector3:
	var p: Vector3 = (chest_skin(s * BUST_APEX.x, BUST_PIVOT_Y)[0] as Vector3)
	return Vector3(s * BUST_APEX.x, BUST_PIVOT_Y, p.z + 0.015)


## Rows of body-space points over the bust field of side s, lifted `lift`: v from v0 to v1 (n rows), and per row u
## from u0(v) to u1(v) given by `span` (Callable(v) -> Vector2(u0, u1)), `cols` columns.
static func bust_rows(s: float, lift: float, v0: float, v1: float, n: int, cols: int, span: Callable) -> Array:
	var rows: Array = []
	for i: int in n + 1:
		var v: float = lerpf(v0, v1, float(i) / float(n))
		var uu: Vector2 = span.call(v)
		var row: PackedVector3Array = PackedVector3Array()
		for k: int in cols + 1:
			var u: float = lerpf(uu.x, uu.y, float(k) / float(cols))
			row.append(chest_front_point(bust_x(u, s), bust_y(v), lift))
		rows.append(row)
	return rows


static func _full_span(_v: float) -> Vector2:
	return Vector2(-1.04, 1.04)


static func _span_inner(v: float) -> Vector2:
	var c: Vector2 = _skin_cut(v)
	return Vector2(-1.04, c.x)


static func _span_cup(v: float) -> Vector2:
	return _skin_cut(v)


static func _span_outer(v: float) -> Vector2:
	var c: Vector2 = _skin_cut(v)
	return Vector2(c.y, 1.04)


## Where the bust skin splits at row v (public, for HoudiniBody's region tags).
static func skin_cut(v: float) -> Vector2:
	return _skin_cut(v)


## Where the bust skin splits at row v: the cup outline moved CUP_SKIN_INSET inward (collapsing at the tip).
static func _skin_cut(v: float) -> Vector2:
	var cs: Vector2 = cup_span(v)
	var mid: float = (cs.x + cs.y) * 0.5
	var shut: float = (cs.y - cs.x) * 0.5 * smoothstep(CUP_TOP_V - 0.45, CUP_TOP_V - 0.2, v)  ## closes below the tip
	return Vector2(minf(cs.x + CUP_SKIN_INSET.x + shut, mid), maxf(cs.y - CUP_SKIN_INSET.y - shut, mid))


## 0 on the front of the ribs, 1 where the ribcage's normal turns to the side (|n.x| from 0.35 to 0.8).
static func side_factor(rib_normal: Vector3) -> float:
	return smoothstep(0.35, 0.8, absf(rib_normal.x))


## Outward unit normal of the bust skin (the height field over the ribs) at bust-field (u, v) on side s, body space.
static func bust_normal(u: float, v: float, s: float) -> Vector3:
	var e: float = 0.01
	var pu: Vector3 = chest_front_point(bust_x(u + e, s), bust_y(v), 0.0) - chest_front_point(bust_x(u - e, s), bust_y(v), 0.0)
	var pv: Vector3 = chest_front_point(bust_x(u, s), bust_y(v + e), 0.0) - chest_front_point(bust_x(u, s), bust_y(v - e), 0.0)
	var n: Vector3 = pu.cross(pv).normalized()
	return -n if n.z > 0.0 else n


## Rows moved from body space into a node's space given that node's body-space origin.
static func rows_to_local(rows: Array, origin: Vector3) -> Array:
	var out: Array = []
	for r: PackedVector3Array in rows:
		var o: PackedVector3Array = PackedVector3Array()
		for p: Vector3 in r:
			o.append(p - origin)
		out.append(o)
	return out


## Bust forms: a height-field patch over each side of the ribcage, under its BodySway_Bust pivot, in four pieces that
## share their edges and their (analytic) normals, so the bare form is one smooth surface: the part under the bikini
## cup (region "bust_L"/"bust_R", which the bikini hides), the skin beside the cup on the inside and the outside, and
## the upper slope above the strap point (region "chest": a top that covers the chest covers them too).
static func _bust(chest: Node3D, chest_y: float, mats: Dictionary) -> void:
	var pivots: Array = build_bust_pivots(chest, chest_y)
	for s: float in [-1.0, 1.0]:
		var side: String = "L" if s < 0.0 else "R"
		var root: Vector3 = bust_pivot(s)
		var pivot: Node3D = pivots[0 if s < 0.0 else 1]
		var v0: float = -1.04
		var vt: float = CUP_TOP_V
		var pieces: Array = [
			["Bust" + side + "Mesh", "bust_" + side, v0, vt, 48, 28, _span_cup],
			["Bust" + side + "InnerMesh", "chest", v0, vt, 48, 10, _span_inner],
			["Bust" + side + "OuterMesh", "chest", v0, vt, 48, 8, _span_outer],
			["Bust" + side + "TopMesh", "chest", vt, 1.04, 14, 24, _full_span],
		]
		for pc: Array in pieces:
			var mesh: ArrayMesh = _bust_patch(s, root, float(pc[2]), float(pc[3]), int(pc[4]), int(pc[5]), pc[6])
			SkaterParts.tag_region(SkaterParts.part(pivot, str(pc[0]), mesh, Vector3.ZERO, mats, "skin"), str(pc[1]))


## The female body's BodySway_BustL/R pivots under the Chest joint (rest height chest_y), [left, right]: the code
## skin's bust forms hang on them, and the skinned body's BustL/R bones follow them.
static func build_bust_pivots(chest: Node3D, chest_y: float) -> Array:
	var out: Array = []
	for s: float in [-1.0, 1.0]:
		var side: String = "L" if s < 0.0 else "R"
		out.append(SkaterParts.joint(chest, "BodySway_Bust" + side, bust_pivot(s) - Vector3(0.0, chest_y, 0.0)))
	return out


## One piece of a bust form: rows v0..v1 (n rows), each from span(v).x to span(v).y (cols columns), in the pivot's
## space (origin = the pivot's body-space position), facing out, with the field's analytic normals.
static func _bust_patch(s: float, origin: Vector3, v0: float, v1: float, n: int, cols: int, span: Callable) -> ArrayMesh:
	var pts: Array = []
	var nrm: Array = []
	for i: int in n + 1:
		var v: float = lerpf(v0, v1, float(i) / float(n))
		var uu: Vector2 = span.call(v)
		var pr: PackedVector3Array = PackedVector3Array()
		var nr: PackedVector3Array = PackedVector3Array()
		for k: int in cols + 1:
			var u: float = lerpf(uu.x, uu.y, float(k) / float(cols))
			var x: float = bust_x(u, s)
			var y: float = bust_y(v)
			var sn: Array = chest_skin(x, y)
			# Toward the ribs' side the form's flank runs almost along the ribs: sink its rim deeper there so it meets
			# them cleanly, and where it comes out of the ribs give it their normal, so the meeting line shades as one
			# surface (no flecks along it).
			var sink: float = SIDE_SINK * side_factor(sn[1] as Vector3)
			pr.append(chest_front_point(x, y, -sink) - origin)
			var above: float = maxf(bust_height(absf(x), y), -BUST_SINK) - sink
			nr.append((sn[1] as Vector3).lerp(bust_normal(u, v, s), smoothstep(0.0, 0.006, above)).normalized())
		pts.append(pr)
		nrm.append(nr)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in n:
		for k: int in cols:
			var quad: Array = [[i, k], [i, k + 1], [i + 1, k], [i, k + 1], [i + 1, k + 1], [i + 1, k]]
			for t: int in 2:
				var tri: Array = quad.slice(t * 3, t * 3 + 3)
				var a: Vector3 = (pts[tri[0][0]] as PackedVector3Array)[tri[0][1]]
				var b: Vector3 = (pts[tri[1][0]] as PackedVector3Array)[tri[1][1]]
				var c: Vector3 = (pts[tri[2][0]] as PackedVector3Array)[tri[2][1]]
				if (b - a).cross(c - a).length_squared() < 1e-14:
					continue  ## the cup piece closes to zero width below the strap point
				var order: Array = tri
				var fn: Vector3 = (b - a).cross(c - a)
				if fn.dot((nrm[tri[0][0]] as PackedVector3Array)[tri[0][1]]) > 0.0:  ## Godot's front faces wind clockwise
					order = [tri[0], tri[2], tri[1]]
				for ik: Array in order:
					st.set_normal((nrm[ik[0]] as PackedVector3Array)[ik[1]])
					st.add_vertex((pts[ik[0]] as PackedVector3Array)[ik[1]])
	return st.commit()


## Smoothed sections cut to [y0, y1], with exact end sections.
static func clip(secs: Array, y0: float, y1: float) -> Array:
	var out: Array = [SkaterParts.section_at(secs, y0)]
	for sec: Array in secs:
		if float(sec[0]) > y0 and float(sec[0]) < y1:
			out.append(sec)
	out.append(SkaterParts.section_at(secs, y1))
	return out


## Limb sections (listed top to bottom) cut to y0 >= y >= y1.
static func clip_desc(secs: Array, y0: float, y1: float) -> Array:
	var out: Array = [SkaterParts.section_at(secs, y0)]
	for sec: Array in secs:
		if float(sec[0]) < y0 and float(sec[0]) > y1:
			out.append(sec)
	out.append(SkaterParts.section_at(secs, y1))
	return out


## Sections with half width and depths grown by `grow` (and optionally scaled), for loose garments.
static func grown(secs: Array, grow: float, scale: float = 1.0) -> Array:
	var out: Array = []
	for s: Array in secs:
		var row: Array = s.duplicate()
		for f: int in [1, 2, 3]:
			row[f] = float(row[f]) * scale + grow
		out.append(row)
	return out


# --- limbs ----------------------------------------------------------------------------------------------------
# Limb sections run down the bone (local -Y): [t, half width, front depth, back depth, power, z centre], t = fraction
# of the bone length (0 at the joint, 1 at the next one, negative above it).

const THIGH: Array = [
	[-0.17, 0.027, 0.027, 0.03, 1.0, 0.0], [-0.1, 0.06, 0.06, 0.066, 1.0, 0.0], [0.0, 0.077, 0.074, 0.08, 1.0, 0.0],
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


## Upper and lower arm skin: elliptical lofts (split into regions) with a round deltoid cap and a soft elbow.
static func build_arm_skin(upper: Node3D, lower: Node3D, side: String, upper_len: float, lower_len: float, mats: Dictionary,
		body_type: String = FEMALE) -> void:
	var m: bool = body_type == MALE
	var sfx: String = "_" + side.left(1)
	var dc: Vector4 = deltoid(body_type)
	var delt: MeshInstance3D = SkaterParts.part(upper, side + "ShoulderCapMesh", SkaterParts.sphere(1.0), Vector3(0.0, dc.w, 0.0), mats, "skin")
	delt.scale = Vector3(dc.x, dc.y, dc.z)
	SkaterParts.tag_region(delt, "shoulder" + sfx)
	_limb_regions(upper, side, "upper_arm", upper_len, body_type, mats)
	SkaterParts.tag_region(SkaterParts.part(lower, side + "ElbowMesh", SkaterParts.sphere(0.034 if m else 0.029), Vector3.ZERO, mats,
			"skin"), "elbow" + sfx)
	_limb_regions(lower, side, "forearm", lower_len, body_type, mats)


## Deltoid cap of the upper arm: radii (x, y, z) and the centre's y on the UpperArm joint (w).
static func deltoid(body_type: String) -> Vector4:
	return Vector4(0.053, 0.05, 0.051, -0.02) if body_type == MALE else Vector4(0.043, 0.048, 0.043, -0.012)


## Thigh and calf skin (split into regions): a slender thigh, a defined knee with a small kneecap, the calf fullest
## in its upper third and a fine ankle (a little thicker throughout on the male body).
static func build_leg_skin(upper: Node3D, lower: Node3D, side: String, upper_len: float, lower_len: float, mats: Dictionary,
		body_type: String = FEMALE) -> void:
	var m: bool = body_type == MALE
	var sfx: String = "_" + side.left(1)
	_limb_regions(upper, side, "thigh", upper_len, body_type, mats)
	SkaterParts.tag_region(SkaterParts.part(lower, side + "KneeMesh", SkaterParts.sphere(0.048 if m else 0.045), Vector3.ZERO, mats,
			"skin"), "knee" + sfx)
	var cap: MeshInstance3D = SkaterParts.part(lower, side + "KneecapMesh", SkaterParts.sphere(1.0), Vector3(0.0, -0.008, -0.032), mats, "skin")
	cap.scale = Vector3(0.026, 0.03, 0.017) if m else Vector3(0.024, 0.028, 0.016)
	SkaterParts.tag_region(cap, "knee" + sfx)
	_limb_regions(lower, side, "calf", lower_len, body_type, mats)
