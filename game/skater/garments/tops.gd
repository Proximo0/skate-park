class_name GarmentTops
extends RefCounted
## Top garments (slot "top"). Contract and registration: see Wardrobe (game/skater/wardrobe.gd).
## Built: top_bikini (female; the male body gets the surf tee), top_surf_tee, top_rash_guard, top_crop_tank, top_hoodie,
## top_flannel (open plaid overshirt over a tee).
## Palette keys: "top" (main fabric) and "top_trim" (piping, collar, cuffs, ringer bands, drawstrings, plaid lines);
## the flannel also uses "top_tee" (the tee under it) and "top_plaid" (generated from "top" and "top_trim").

const STUBS: PackedStringArray = []
const GROW_TIGHT: float = 0.0045
const GROW_LOOSE: float = 0.008
const TOP_DEFAULT: Color = Color(0.07, 0.66, 0.7)
const TRIM_DEFAULT: Color = Color(1.0, 0.5, 0.4)
const CUP_EDGE_LIFT: float = 0.003  ## the cup comes down to this lift at its edges, under the piping
const CUP_PIPING_R: float = 0.003
const TANK_GROW: float = 0.006
const TANK_HEM: float = 1.05  ## hem height: just under the bust, so the under-bust and belly stay bare
const HOODIE_GROW: float = 0.011
const FLANNEL_GROW: float = 0.0115
const TEE_GROW: float = 0.003
const FLANNEL_GAP: float = 0.3  ## half-angle of the open front, from the front-centre line
const PLAID_TILE: float = 0.08  ## metres per texture tile of the plaid
const TEE_DEFAULT: Color = Color(0.95, 0.93, 0.88)


static func builders() -> Dictionary:
	return {
		"top_bikini": GarmentTops.bikini,
		"top_surf_tee": GarmentTops.surf_tee,
		"top_rash_guard": GarmentTops.rash_guard,
		"top_crop_tank": GarmentTops.crop_tank,
		"top_hoodie": GarmentTops.hoodie,
		"top_flannel": GarmentTops.flannel,
	}


static func covers(id: String, body_type: String) -> PackedStringArray:
	var torso: PackedStringArray = ["hip_band", "belly", "waist_low", "waist", "under_bust", "chest", "chest_upper"]
	if body_type != AnimeOutfit.MALE:
		torso.append_array(["bust_L", "bust_R"])
	match id:
		"top_bikini":
			# The cups enclose the bust skin under them (same pivot), so it is hidden: nothing can poke through.
			return PackedStringArray(["bust_L", "bust_R"]) if body_type != AnimeOutfit.MALE else covers("top_surf_tee", body_type)
		"top_surf_tee":
			return torso + PackedStringArray(["shoulder_L", "shoulder_R", "upper_arm_L", "upper_arm_R"])
		"top_rash_guard":
			return torso + PackedStringArray(["shoulder_L", "shoulder_R", "upper_arm_L", "upper_arm_R", "upper_arm_low_L",
					"upper_arm_low_R", "elbow_L", "elbow_R", "forearm_L", "forearm_R"])
		"top_crop_tank":
			return PackedStringArray(["chest"]) + (PackedStringArray(["bust_L", "bust_R"]) if body_type != AnimeOutfit.MALE else PackedStringArray())
		"top_hoodie":
			return covers("top_rash_guard", body_type)
		"top_flannel":
			return covers("top_surf_tee", body_type)  ## the tee under the open flannel
	return PackedStringArray()


static func _mats(mats: Dictionary) -> void:
	Wardrobe.mat(mats, "top", TOP_DEFAULT)
	Wardrobe.mat(mats, "top_trim", TRIM_DEFAULT)


# --- bikini ---------------------------------------------------------------------------------------------------

## Sporty bralette: a triangle cup over each bust form (under the same BodySway pivot, following the bust field
## CUP_GROW outside the skin, easing in to CUP_EDGE_LIFT at its edges), coral piping along the cup edges and the
## under-band, and straps over the shoulders to the back band. The cup outline is AnimeOutfit.cup_span(), the same
## line the bust skin is split on, and the skin under the cup is hidden (covers()). The male body has no bust, so it
## gets the surf tee.
static func bikini(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	if body_type == AnimeOutfit.MALE or not rig.has("BodySway_BustL"):
		surf_tee(rig, body_type, mats)
		return
	_mats(mats)
	var chest: Node3D = rig["Chest"]
	var chest_y: float = float(rig["rest_y"]["Chest"])
	var ribs: Array = rig["sections"]["chest"]
	var tops: Dictionary = {}
	for s: float in [-1.0, 1.0]:
		var side: String = "L" if s < 0.0 else "R"
		var pivot: Node3D = rig["BodySway_Bust" + side]
		var origin: Vector3 = AnimeOutfit.bust_pivot(s)
		var rows: Array = _cup_rows(s, 0.0, 40, 24)
		SkaterParts.part(pivot, "BikiniCup" + side + "Mesh", _front_grid(AnimeOutfit.rows_to_local(rows, origin), origin), Vector3.ZERO,
				mats, "top")
		# Piping along both edges, from the band piping up to the strap point and back down.
		var trim_rows: Array = _cup_rows(s, CUP_PIPING_R * 0.45, 40, 24)
		var pts: PackedVector3Array = PackedVector3Array()
		var first: int = 1
		for i: int in range(first, trim_rows.size()):
			pts.append((trim_rows[i] as PackedVector3Array)[0] - origin)
		for i: int in range(trim_rows.size() - 2, first - 1, -1):
			var row: PackedVector3Array = trim_rows[i]
			pts.append(row[row.size() - 1] - origin)
		var radii: PackedFloat32Array = PackedFloat32Array()
		radii.resize(pts.size())
		radii.fill(CUP_PIPING_R)
		SkaterParts.part(pivot, "BikiniCupTrim" + side + "Mesh", SkaterParts.tube_capped(pts, radii, 6), Vector3.ZERO, mats, "top_trim")
		var top_row: PackedVector3Array = rows[rows.size() - 1]
		tops[s] = top_row[top_row.size() / 2]
	# Under-band round the ribs and its piping.
	var band_y: Vector2 = AnimeOutfit.TOP_BAND - Vector2(chest_y, chest_y)
	SkaterParts.part(chest, "BikiniTopMesh", SkaterParts.loft(AnimeOutfit.clip(ribs, band_y.x, band_y.y), 32, 0.0035), Vector3.ZERO,
			mats, "top")
	SkaterParts.part(chest, "BikiniBandTrimMesh", SkaterParts.loft_ring(ribs, band_y.x, 0.0045, 0.0034, 40), Vector3.ZERO, mats,
			"top_trim")
	# Straps: from the top of each cup, up over the shoulder, down to the back band.
	for s: float in [-1.0, 1.0]:
		var pts: PackedVector3Array = PackedVector3Array()
		pts.append((tops[s] as Vector3) - Vector3(0.0, chest_y, 0.0))
		for fy: Vector2 in [Vector2(1.235, 0.079), Vector2(1.27, 0.081), Vector2(1.295, 0.082)]:
			pts.append(AnimeOutfit.chest_front_point(s * fy.y, fy.x, 0.004) - Vector3(0.0, chest_y, 0.0))
		var top: Array = SkaterParts.section_at(ribs, 1.318 - chest_y)
		pts.append(Vector3(s * 0.08, 1.318 - chest_y + 0.006, float(top[5])))
		for by: Vector2 in [Vector2(1.31, 0.082), Vector2(1.27, 0.08), Vector2(1.2, 0.077), Vector2(1.14, 0.074), Vector2(1.08, 0.072)]:
			var sec: Array = SkaterParts.section_at(ribs, by.x - chest_y)
			pts.append(SkaterParts.section_point(sec, SkaterParts.section_angle_for_x(sec, s * by.y, false, 0.004), 0.004))
		pts = SkaterParts.smooth3d(pts, 3)
		var radii: PackedFloat32Array = PackedFloat32Array()
		radii.resize(pts.size())
		radii.fill(0.0055)
		SkaterParts.part(chest, ("Left" if s < 0.0 else "Right") + "BikiniStrapMesh", SkaterParts.tube_capped(pts, radii, 8),
				Vector3.ZERO, mats, "top")


## Open grid over rows (in a node's space whose body-space origin is `origin`) facing out from the body's vertical axis,
## each triangle wound on its own (the cup wraps round to face the side at its outer edge) and slivers dropped.
static func _front_grid(rows: Array, origin: Vector3) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in rows.size() - 1:
		var r0: PackedVector3Array = rows[i]
		var r1: PackedVector3Array = rows[i + 1]
		for k: int in r0.size() - 1:
			for tri: Array in [[r0[k], r0[k + 1], r1[k]], [r0[k + 1], r1[k + 1], r1[k]]]:
				var a: Vector3 = tri[0]
				var b: Vector3 = tri[1]
				var c: Vector3 = tri[2]
				var n: Vector3 = (b - a).cross(c - a)
				if n.length_squared() < 1e-13:  ## (also float32 slivers)
					continue
				var out: Vector3 = Vector3(a.x + origin.x, 0.0, a.z + origin.z)
				if n.dot(out) > 0.0:  ## Godot's front faces wind clockwise
					st.add_vertex(a)
					st.add_vertex(c)
					st.add_vertex(b)
				else:
					st.add_vertex(a)
					st.add_vertex(b)
					st.add_vertex(c)
	st.index()
	st.generate_normals()
	return st.commit()


## Body-space rows of the cup of side s over the bust field (AnimeOutfit.cup_span outline, n rows by cols columns),
## lifted CUP_GROW off the skin in the middle and CUP_EDGE_LIFT at the edges, plus `extra`.
static func _cup_rows(s: float, extra: float, n: int, cols: int) -> Array:
	var rows: Array = []
	for i: int in n + 1:
		var v: float = lerpf(AnimeOutfit.CUP_BOTTOM_V, AnimeOutfit.CUP_TOP_V, float(i) / float(n))
		var uu: Vector2 = AnimeOutfit.cup_span(v)
		var row: PackedVector3Array = PackedVector3Array()
		for k: int in cols + 1:
			var t: float = float(k) / float(cols)
			var u: float = lerpf(uu.x, uu.y, t)
			var edge: float = minf(t, 1.0 - t) * absf(uu.y - uu.x)  ## distance to the nearer edge, in u
			var x: float = AnimeOutfit.bust_x(u, s)
			var y: float = AnimeOutfit.bust_y(v)
			var side: float = AnimeOutfit.side_factor(AnimeOutfit.chest_skin(x, y)[1] as Vector3)
			var lift: float = lerpf(CUP_EDGE_LIFT, AnimeOutfit.CUP_GROW, smoothstep(0.0, 0.35, edge)) + extra
			row.append(AnimeOutfit.chest_front_point(x, y, lift + AnimeOutfit.SIDE_SINK * side))
		rows.append(row)
	return rows


# --- shirts ---------------------------------------------------------------------------------------------------

## Loose short-sleeved surf tee: a ringer collar and sleeve cuffs in "top_trim", a hem over the hips, a contrast
## band across the chest and a small sun-and-wave chest print.
static func surf_tee(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	_mats(mats)
	_shirt(rig, body_type, mats, "SurfTee", GROW_LOOSE, true, 0.5, -1.0)
	_tee_print(rig, body_type, mats)


## Tight long-sleeved rash guard with a mock collar, contrast cuffs and a contrast panel across the chest.
static func rash_guard(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	_mats(mats)
	_shirt(rig, body_type, mats, "RashGuard", GROW_TIGHT, false, 1.1, 0.84)


## Height of the fabric over the chest front at body (x, y): bridges the cleavage and drapes straight down from the
## bust apex, so it is never below the bust field.
static func _drape(x: float, y: float, body_type: String, loose: bool) -> float:
	if body_type == AnimeOutfit.MALE:
		return 0.0
	var xa: float = maxf(absf(x), AnimeOutfit.BUST_APEX.x)
	var h: float = AnimeOutfit.bust_height(xa, y)
	var below: float = AnimeOutfit.BUST_APEX.y - y
	if below > 0.0:
		var fall: float = 0.075 if loose else 0.05
		h = maxf(h, AnimeOutfit.bust_height(xa, AnimeOutfit.BUST_APEX.y) * (1.0 - smoothstep(0.0, fall, below)))
	return maxf(h, 0.0)


static var _fine: Dictionary = {}


## The chest sections smoothed as finely as AnimeOutfit.chest_skin() smooths them (body space).
static func _fine_chest(body_type: String) -> Array:
	if not _fine.has(body_type):
		_fine[body_type] = SkaterParts.smooth_sections(AnimeOutfit.skin_sections("chest", body_type), 6)
	return _fine[body_type]


## Chest-front fix-up of a shirt point p (`sec` is the skin's section, a < PI/2 the front half): drape
## over the bust, enclose the finer chest surface, and room over the collarbones.
static func _front_adjust(p: Vector3, sec: Array, a: float, y: float, grow: float, body_type: String, loose: bool) -> Vector3:
	var sx: float = SkaterParts.section_point(sec, a).x  ## the skin under this point (not the grown shirt)
	var h: float = _drape(sx, y, body_type, loose)
	var nrm: Vector3 = AnimeOutfit.chest_skin(clampf(sx, -0.12, 0.12), clampf(y, 1.0, 1.3), body_type)[1]
	if h > 0.0:
		p += nrm * (h * 1.08)
	elif body_type != AnimeOutfit.MALE and y > 1.0 and y < 1.26:
		# Also enclose the finer-smoothed chest surface the bust field sits on (they part by a few mm at the
		# sides, where the forms' rims are).
		var alt: Vector3 = SkaterParts.section_point(SkaterParts.section_at(_fine_chest(body_type), y), a, grow)
		if Vector2(alt.x, alt.z).length() > Vector2(p.x, p.z).length():
			p = Vector3(alt.x, p.y, alt.z)
	# Room over the collarbones (they stand about 5 mm proud of the sections).
	p += nrm * (0.004 * smoothstep(1.275, 1.3, y) * smoothstep(0.0, 0.02, absf(p.x)))
	return p


## Rings of a torso shirt piece over smoothed body sections (joint space, `base` = joint rest y), from y0 to y1
## (body space). loose: never narrower than the under-bust (it hangs, it does not cinch at the waist).
static func _torso_rows(secs_local: Array, base: float, y0: float, y1: float, grow: float, body_type: String, loose: bool,
		ref: Array, chest_front: bool) -> Array:
	var rows: Array = []
	var cut: Array = AnimeOutfit.clip(secs_local, y0 - base, y1 - base)
	var first: Array = (cut[0] as Array).duplicate()
	first[0] = minf(float(first[0]), y0 - base)  ## may hang a little below the skin's end (no edge to peek past)
	cut[0] = first
	var n: int = 40
	for sec: Array in cut:
		var sc: Array = sec.duplicate()
		if loose:
			var w: float = 1.0 - smoothstep(1.02, 1.12, float(sc[0]) + base)  ## hangs straight below the ribs only
			for f: int in [1, 2, 3]:
				sc[f] = lerpf(float(sc[f]), maxf(float(sc[f]), float(ref[f])), w)
		var ring: PackedVector3Array = PackedVector3Array()
		var y: float = float(sc[0]) + base
		for k: int in n:
			var a: float = TAU * float(k) / float(n)
			var p: Vector3 = SkaterParts.section_point(sc, a, grow)
			if chest_front and cos(a) > 0.0:
				p = _front_adjust(p, sec, a, y, grow, body_type, loose)
			ring.append(p)
		rows.append(ring)
	return rows


## Shirt options (all optional): "key"/"trim" palette keys of the fabric and the trim, "plaid" (checked fabric with UVs),
## "collar_y", "hem_y", "band" (contrast chest panel), "collar_r"/"hem_r"/"cuff_r" (trim tube radii), "hem_key", "sleeve_grow".
static func _shirt(rig: Dictionary, body_type: String, mats: Dictionary, tag: String, grow: float, loose: bool,
		sleeve_end: float, forearm_end: float, opt: Dictionary = {}) -> void:
	var secs: Dictionary = rig["sections"]
	var ry: Dictionary = rig["rest_y"]
	var chest_y: float = float(ry["Chest"])
	var spine_y: float = float(ry["Spine"])
	var hips_y: float = float(ry["Hips"])
	var key: String = str(opt.get("key", "top"))
	var trim: String = str(opt.get("trim", "top_trim"))
	var ref: Array = _ref_section(body_type)
	var collar_y: float = float(opt.get("collar_y", (1.345 if body_type == AnimeOutfit.MALE else 1.335) if loose else 1.35))
	var hem_y: float = float(opt.get("hem_y", 0.885 if loose else 0.9))
	# Chest piece (with the bust) on Chest; waist piece on Spine; hips piece on Hips. They overlap, so a bent spine
	# never opens a gap.
	var chest_rows: Array = _torso_rows(secs["chest"], chest_y, 0.975, collar_y, grow, body_type, loose, ref, true)
	SkaterParts.part(rig["Chest"], tag + "ChestMesh", _surf(chest_rows, opt, 0.0, TAU, chest_y, 0.1), Vector3.ZERO, mats, key)
	var waist_rows: Array = _torso_rows(secs["waist"], spine_y, 0.9, 1.11, grow + (0.003 if loose else 0.001), body_type, loose, ref, false)
	SkaterParts.part(rig["Spine"], tag + "WaistMesh", _surf(waist_rows, opt, 0.0, TAU, spine_y, 0.1), Vector3.ZERO, mats, key)
	var hips_rows: Array = _torso_rows(secs["pelvis"], hips_y, hem_y, 1.035, grow + (0.007 if loose else 0.001), body_type, loose, ref, false)
	SkaterParts.part(rig["Hips"], tag + "HipsMesh", _surf(hips_rows, opt, 0.0, TAU, hips_y, 0.1), Vector3.ZERO, mats, key)
	# Collar and hem.
	var collar: PackedVector3Array = chest_rows[chest_rows.size() - 1]
	SkaterParts.part(rig["Chest"], tag + "CollarMesh", _ring_tube(collar, float(opt.get("collar_r", 0.0055 if loose else 0.007))),
			Vector3.ZERO, mats, trim)
	SkaterParts.part(rig["Hips"], tag + "HemMesh", _ring_tube(hips_rows[0], float(opt.get("hem_r", 0.004 if loose else 0.002))),
			Vector3.ZERO, mats, str(opt.get("hem_key", key)))
	# Contrast panel across the chest (rash guard).
	if bool(opt.get("band", not loose)):
		var band_rows: Array = _torso_rows(secs["chest"], chest_y, 1.165, 1.215, grow + 0.0015, body_type, loose,
				ref, true)
		SkaterParts.part(rig["Chest"], tag + "BandMesh", SkaterParts.grid(band_rows, true), Vector3.ZERO, mats, trim)
	_sleeves(rig, body_type, mats, tag, grow, loose, sleeve_end, forearm_end, opt)


static func _sleeves(rig: Dictionary, body_type: String, mats: Dictionary, tag: String, grow: float, loose: bool,
		sleeve_end: float, forearm_end: float, opt: Dictionary = {}) -> void:
	var secs: Dictionary = rig["sections"]
	var ul: float = float(rig["lengths"]["upper_arm"])
	var ll: float = float(rig["lengths"]["lower_arm"])
	var male: bool = body_type == AnimeOutfit.MALE
	var key: String = str(opt.get("key", "top"))
	var trim: String = str(opt.get("trim", "top_trim"))
	var cuff_r: float = float(opt.get("cuff_r", 0.0045))
	grow = float(opt.get("sleeve_grow", grow))
	var dc: Vector4 = AnimeOutfit.deltoid(body_type)
	var delt: Vector3 = Vector3(dc.x, dc.y, dc.z)
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		var upper: Node3D = rig[side + "UpperArm"]
		var arm: Array = secs["upper_arm"]
		var sg: float = grow + (0.004 if loose else 0.0)
		var rows: Array = []
		var y_top: float = maxf(dc.w + delt.y, float((arm[0] as Array)[0]) + 0.004) + sg  ## over the deltoid and the arm's top
		var y_end: float = -sleeve_end * ul
		var steps: int = 22
		for i: int in steps + 1:
			var y: float = lerpf(y_top, y_end, pow(float(i) / float(steps), 1.4))
			var sec: Array = (SkaterParts.section_at(arm, y) as Array).duplicate()
			var e: float = (y - dc.w) / delt.y
			var dome: float = sqrt(maxf(1.0 - e * e, 0.0))  ## the deltoid cap (a scaled sphere) stays inside
			sec[1] = maxf(float(sec[1]), delt.x * dome)
			sec[2] = maxf(float(sec[2]), delt.z * dome)
			sec[3] = maxf(float(sec[3]), delt.z * dome)
			if i == 0:
				sec[1] = 0.0
				sec[2] = 0.0
				sec[3] = 0.0
			sec[0] = y
			var flare: float = (0.004 * smoothstep(0.6, 1.0, float(i) / float(steps))) if loose else 0.0
			var ring: PackedVector3Array = PackedVector3Array()
			for k: int in 20:
				ring.append(SkaterParts.section_point(sec, TAU * float(k) / 20.0, 0.0 if i == 0 else sg + flare))
			rows.append(ring)
		rows.reverse()
		SkaterParts.part(upper, side + tag + "SleeveMesh", _surf(rows, opt, 0.0, TAU, 0.0, 0.045), Vector3.ZERO, mats, key)
		if forearm_end <= 0.0:
			SkaterParts.part(upper, side + tag + "CuffMesh", _ring_tube(rows[0], cuff_r), Vector3.ZERO, mats, trim)
		else:
			var lower: Node3D = rig[side + "LowerArm"]
			var fsecs: Array = secs["forearm"]
			var elbow_r: float = 0.034 if male else 0.029
			var frows: Array = []
			var fsteps: int = 18
			for i: int in fsteps + 1:
				var y: float = lerpf(0.045, -forearm_end * ll, float(i) / float(fsteps))
				var sec: Array = (SkaterParts.section_at(fsecs, y) as Array).duplicate()
				var sph: float = sqrt(maxf(elbow_r * elbow_r - y * y, 0.0))
				for f: int in [1, 2, 3]:
					sec[f] = maxf(float(sec[f]), sph)
				sec[0] = y
				var ring: PackedVector3Array = PackedVector3Array()
				for k: int in 18:
					ring.append(SkaterParts.section_point(sec, TAU * float(k) / 18.0, grow))
				frows.append(ring)
			frows.reverse()
			SkaterParts.part(lower, side + tag + "ForearmSleeveMesh", _surf(frows, opt, 0.0, TAU, 0.0, 0.04), Vector3.ZERO, mats, key)
			SkaterParts.part(lower, side + tag + "CuffMesh", _ring_tube(frows[0], cuff_r), Vector3.ZERO, mats, trim)


## Small chest print on the tee: a sun disc with two wave lines, lying on the fabric (left chest).
static func _tee_print(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	Wardrobe.mat(mats, "top_print", Color(1.0, 0.82, 0.38))
	var chest_y: float = float(rig["rest_y"]["Chest"])
	var cx: float = -0.06
	var cy: float = 1.215 if body_type == AnimeOutfit.MALE else 1.235
	var lift: float = GROW_LOOSE + 0.004
	var ring: PackedVector3Array = PackedVector3Array()
	for k: int in 24:
		var a: float = TAU * float(k) / 24.0
		ring.append(_print_point(cx + cos(a) * 0.022, cy + sin(a) * 0.022, lift, chest_y, body_type))
	SkaterParts.part(rig["Chest"], "SurfTeeSunMesh", _fan(_print_point(cx, cy, lift, chest_y, body_type), ring), Vector3.ZERO, mats,
			"top_print")
	for w: int in 2:
		var pts: PackedVector3Array = PackedVector3Array()
		for i: int in 13:
			var t: float = float(i) / 12.0
			var x: float = cx - 0.032 + 0.064 * t
			pts.append(_print_point(x, cy - 0.03 - 0.012 * float(w) + 0.004 * sin(t * TAU * 1.5), lift + 0.001, chest_y, body_type))
		var radii: PackedFloat32Array = PackedFloat32Array()
		radii.resize(pts.size())
		radii.fill(0.0028)
		SkaterParts.part(rig["Chest"], "SurfTeeWave%dMesh" % w, SkaterParts.tube_capped(pts, radii, 6), Vector3.ZERO, mats, "top_trim")


static func _print_point(x: float, y: float, lift: float, chest_y: float, body_type: String) -> Vector3:
	var sn: Array = AnimeOutfit.chest_skin(x, y, body_type)
	var h: float = _drape(x, y, body_type, true) * 1.08
	return (sn[0] as Vector3) + (sn[1] as Vector3) * (h + lift) - Vector3(0.0, chest_y, 0.0)


## Flat fan from a centre point to a ring, facing away from the body (-Z side, the chest front).
static func _fan(c: Vector3, ring: PackedVector3Array) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in ring.size():
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % ring.size()]
		var n: Vector3 = (a - c).cross(b - c)
		if n.z < 0.0:  ## Godot's front faces wind clockwise
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(a)
		else:
			st.add_vertex(c)
			st.add_vertex(a)
			st.add_vertex(b)
	st.generate_normals()
	return st.commit()


## Closed tube following a ring of points (collars, cuffs, hems).
static func _ring_tube(ring: PackedVector3Array, r: float) -> ArrayMesh:
	var pts: PackedVector3Array = ring.duplicate()
	pts.append(ring[0])
	var radii: PackedFloat32Array = PackedFloat32Array()
	radii.resize(pts.size())
	radii.fill(r)
	return SkaterParts.tube(pts, radii, 6)


# --- shared shaping helpers -----------------------------------------------------------------------------------

## The chest section the loose shirts never shrink below (just under the bust, a little tucked in).
static func _ref_section(body_type: String) -> Array:
	var ref: Array = SkaterParts.section_at(SkaterParts.smooth_sections(AnimeOutfit.skin_sections("chest", body_type), 3), 1.06)
	ref = ref.duplicate()
	for f: int in [1, 2, 3]:
		ref[f] = float(ref[f]) * 0.97
	return ref


## A point of a shirt surface at body height y and section angle a (0 = front, joint space of `secs`): the shirt
## surface _torso_rows() lofts, sampled anywhere.
static func _gpoint(secs: Array, base: float, y: float, a: float, grow: float, body_type: String, loose: bool, ref: Array,
		chest_front: bool) -> Vector3:
	var sec: Array = SkaterParts.section_at(secs, y - base)
	sec[0] = y - base
	var p: Vector3 = SkaterParts.section_point(_loosened(sec, y, loose, ref), a, grow)
	if chest_front and cos(a) > 0.0:
		p = _front_adjust(p, sec, a, y, grow, body_type, loose)
	return p


## Evenly spaced angles from a0 to a1 (n steps; a closed ring leaves out the repeated end).
static func _angles(a0: float, a1: float, n: int, closed: bool) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for k: int in (n if closed else n + 1):
		out.append(a0 + (a1 - a0) * float(k) / float(n))
	return out


## Rows (bottom to top, n + 1 of them) of a shirt surface over `angles`; column k runs from y_lo[k] to y_hi[k], and the
## grow eases from grow to grow_hi going up. drops = Vector2(bottom, top): the grow sinks by that much over the first
## and last quarter of the rows, so a piece overlapping its neighbour ends inside it (no visible step).
static func _shaped(secs: Array, base: float, body_type: String, loose: bool, ref: Array, grow: float, grow_hi: float,
		chest_front: bool, angles: PackedFloat32Array, y_lo: PackedFloat32Array, y_hi: PackedFloat32Array, n: int,
		drops: Vector2 = Vector2.ZERO) -> Array:
	var rows: Array = []
	for i: int in n + 1:
		var t: float = float(i) / float(n)
		var g: float = lerpf(grow, grow_hi, t) - drops.x * (1.0 - smoothstep(0.0, 0.3, t)) - drops.y * smoothstep(0.7, 1.0, t)
		var row: PackedVector3Array = PackedVector3Array()
		for k: int in angles.size():
			row.append(_gpoint(secs, base, lerpf(y_lo[k], y_hi[k], t), angles[k], g, body_type, loose, ref, chest_front))
		rows.append(row)
	return rows


## Rows (bottom to top) of an open panel round the back with a straight front gap: at each height the panel starts and ends
## where the shirt surface has x = +-gap(y), `cols` columns between. Same surface as _gpoint().
static func _panel_rows(secs: Array, base: float, body_type: String, loose: bool, ref: Array, grow: float, chest_front: bool,
		y_lo: float, y_hi: float, n: int, cols: int, drops: Vector2, gap: Callable) -> Array:
	var rows: Array = []
	for i: int in n + 1:
		var t: float = float(i) / float(n)
		var y: float = lerpf(y_lo, y_hi, t)
		var g: float = grow - drops.x * (1.0 - smoothstep(0.0, 0.3, t)) - drops.y * smoothstep(0.7, 1.0, t)
		var sec: Array = SkaterParts.section_at(secs, y - base)
		sec[0] = y - base
		var sc: Array = _loosened(sec, y, loose, ref)
		var a_edge: float = SkaterParts.section_angle_for_x(sc, float(gap.call(y)), true, g)
		var row: PackedVector3Array = PackedVector3Array()
		for k: int in cols + 1:
			var a: float = lerpf(a_edge, TAU - a_edge, float(k) / float(cols))
			var p: Vector3 = SkaterParts.section_point(sc, a, g)
			if chest_front and cos(a) > 0.0:
				p = _front_adjust(p, sec, a, y, g, body_type, loose)
			row.append(p)
		rows.append(row)
	return rows


## The section a loose shirt follows at height y: never narrower than ref just under the ribs.
static func _loosened(sec: Array, y: float, loose: bool, ref: Array) -> Array:
	var sc: Array = sec.duplicate()
	if loose:
		var w: float = 1.0 - smoothstep(1.02, 1.12, y)
		for f: int in [1, 2, 3]:
			sc[f] = lerpf(float(sc[f]), maxf(float(sc[f]), float(ref[f])), w)
	return sc


## Surface from rows whose columns span angles a0..a1 (a full turn when closed). With opt "plaid" it carries UVs
## (u along the angle, v up the body in tiles of PLAID_TILE; vb = the joint's rest y, ur = a typical radius).
static func _surf(rows: Array, opt: Dictionary, a0: float, a1: float, vb: float, ur: float, closed: bool = true) -> ArrayMesh:
	if not bool(opt.get("plaid", false)):
		return SkaterParts.grid(rows, closed)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in rows.size() - 1:
		var r0: PackedVector3Array = rows[i]
		var r1: PackedVector3Array = rows[i + 1]
		var m: int = r0.size()
		var cols: int = m if closed else m - 1
		var steps: float = float(m if closed else m - 1)
		for k: int in cols:
			var k2: int = (k + 1) % m
			var ua: float = a0 + (a1 - a0) * float(k) / steps
			var ub: float = a0 + (a1 - a0) * float(k + 1) / steps
			if not closed:  ## open panels: the angle of the point itself (columns do not share angles from row to row)
				_uv_vertex(st, r0[k], _angle_of(r0[k]), ur, vb)
				_uv_vertex(st, r0[k2], _angle_of(r0[k2]), ur, vb)
				_uv_vertex(st, r1[k], _angle_of(r1[k]), ur, vb)
				_uv_vertex(st, r0[k2], _angle_of(r0[k2]), ur, vb)
				_uv_vertex(st, r1[k2], _angle_of(r1[k2]), ur, vb)
				_uv_vertex(st, r1[k], _angle_of(r1[k]), ur, vb)
				continue
			_uv_vertex(st, r0[k], ua, ur, vb)
			_uv_vertex(st, r0[k2], ub, ur, vb)
			_uv_vertex(st, r1[k], ua, ur, vb)
			_uv_vertex(st, r0[k2], ub, ur, vb)
			_uv_vertex(st, r1[k2], ub, ur, vb)
			_uv_vertex(st, r1[k], ua, ur, vb)
	st.index()
	st.generate_normals()
	return st.commit()


## Angle round the body's vertical axis of a point (0 = front, increasing toward +X), 0..TAU.
static func _angle_of(p: Vector3) -> float:
	return fposmod(atan2(p.x, -p.z), TAU)


static func _uv_vertex(st: SurfaceTool, p: Vector3, a: float, ur: float, vb: float) -> void:
	st.set_uv(Vector2(a * ur / PLAID_TILE, (p.y + vb) / PLAID_TILE))
	st.add_vertex(p)


## Registers the plaid material "top_plaid": a small generated tile from "top" and "top_trim" (wide darker bands both
## ways, crossing darker, thin light lines), tinted by nothing else.
static func _plaid_mat(mats: Dictionary) -> void:
	if mats.has("top_plaid"):
		return
	var main: Color = (mats["top"] as StandardMaterial3D).albedo_color
	var line: Color = (mats["top_trim"] as StandardMaterial3D).albedo_color
	var size: int = 64
	var img: Image = Image.create(size, size, true, Image.FORMAT_RGB8)
	for y: int in size:
		for x: int in size:
			var c: Color = main
			var k: float = 1.0
			if x >= 12 and x < 36:
				k *= 0.72
			if y >= 12 and y < 36:
				k *= 0.72
			if (x >= 54 and x < 57) or (y >= 54 and y < 57):
				k *= 0.4
			c = Color(main.r * k, main.g * k, main.b * k)
			if (x >= 43 and x < 46) or (y >= 43 and y < 46):
				c = c.lerp(line, 0.7)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.9
	mats["top_plaid"] = m


# --- crop tank ------------------------------------------------------------------------------------------------

## Fitted crop tank: a hem just under the bust, a scooped neckline, deep armholes and two round straps over the
## shoulders, piped in "top_trim". Covers the chest and (female) the bust forms.
static func crop_tank(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	_mats(mats)
	var male: bool = body_type == AnimeOutfit.MALE
	var chest: Node3D = rig["Chest"]
	var chest_y: float = float(rig["rest_y"]["Chest"])
	var secs: Array = rig["sections"]["chest"]
	var ref: Array = _ref_section(body_type)
	var grow: float = TANK_GROW
	var strap_x: float = 0.085 if male else 0.074
	var angles: PackedFloat32Array = _angles(0.0, TAU, 72, true)
	var skin: Array = SkaterParts.section_at(secs, 1.28 - chest_y)
	var lo: PackedFloat32Array = PackedFloat32Array()
	var hi: PackedFloat32Array = PackedFloat32Array()
	for a: float in angles:
		var x: float = absf(SkaterParts.section_point(skin, a).x)
		var inner: float = (1.258 + 0.06 * smoothstep(0.0, strap_x, x)) if cos(a) > 0.0 else (1.285 + 0.033 * smoothstep(0.0, strap_x, x))
		lo.append(TANK_HEM)
		hi.append(lerpf(inner, 1.256, smoothstep(strap_x + 0.012, strap_x + 0.045, x)))
	var rows: Array = _shaped(secs, chest_y, body_type, false, ref, grow, grow, true, angles, lo, hi, 34)
	SkaterParts.part(chest, "CropTankMesh", SkaterParts.grid(rows, true), Vector3.ZERO, mats, "top")
	SkaterParts.part(chest, "CropTankHemMesh", _ring_tube(rows[0], 0.0038), Vector3.ZERO, mats, "top_trim")
	SkaterParts.part(chest, "CropTankNeckMesh", _ring_tube(rows[rows.size() - 1], 0.0032), Vector3.ZERO, mats, "top_trim")
	# Straps: from the front panel's top edge up over the shoulder to the back panel's.
	for s: float in [-1.0, 1.0]:
		var a_front: float = SkaterParts.section_angle_for_x(skin, s * strap_x, true)
		var a_back: float = SkaterParts.section_angle_for_x(skin, s * strap_x, false)
		var y_front: float = 1.318
		var y_back: float = 1.318
		var top_y: float = 1.318
		for yy: float in [1.31, 1.32, 1.33, 1.34, 1.35]:
			if float(SkaterParts.section_at(secs, yy - chest_y)[1]) >= strap_x:
				top_y = yy
		var top: Array = SkaterParts.section_at(secs, top_y - chest_y)
		var pts: PackedVector3Array = PackedVector3Array()
		pts.append(_gpoint(secs, chest_y, y_front, a_front, grow, body_type, false, ref, true))
		pts.append(SkaterParts.section_point(top, a_front, grow + 0.004) + Vector3(0.0, 0.004, 0.0))
		pts.append(Vector3(s * strap_x, top_y - chest_y + 0.007, float(top[5])))
		pts.append(SkaterParts.section_point(top, a_back, grow + 0.004) + Vector3(0.0, 0.004, 0.0))
		pts.append(_gpoint(secs, chest_y, y_back, a_back, grow, body_type, false, ref, false))
		pts = SkaterParts.smooth3d(pts, 3)
		var radii: PackedFloat32Array = PackedFloat32Array()
		radii.resize(pts.size())
		radii.fill(0.009)
		SkaterParts.part(chest, ("Left" if s < 0.0 else "Right") + "CropTankStrapMesh", SkaterParts.tube_capped(pts, radii, 8),
				Vector3.ZERO, mats, "top")


# --- hoodie ---------------------------------------------------------------------------------------------------

## Loose long-sleeved hoodie: ribbed hem and cuffs in "top_trim", a kangaroo pocket, drawstrings, and the hood lying
## on the back of the neck and shoulders. Sleeves follow the arm joints.
static func hoodie(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	_mats(mats)
	var opt: Dictionary = {"collar_y": 1.345, "hem_y": 0.86, "band": false, "collar_r": 0.011, "hem_r": 0.0075,
			"hem_key": "top_trim", "cuff_r": 0.0075, "sleeve_grow": 0.0085}
	_shirt(rig, body_type, mats, "Hoodie", HOODIE_GROW, true, 1.1, 0.86, opt)
	var ref: Array = _ref_section(body_type)
	_hood(rig, body_type, mats, ref)
	_pocket(rig, body_type, mats, ref)
	_drawstrings(rig, body_type, mats)


## The hood lying down: a soft pile of fabric over the back of the neck and between the shoulder blades, thickest a
## third of the way down and flush with the hoodie at its edges.
static func _hood(rig: Dictionary, body_type: String, mats: Dictionary, ref: Array) -> void:
	var chest_y: float = float(rig["rest_y"]["Chest"])
	var secs: Array = rig["sections"]["chest"]
	var a_lo: float = PI * 0.5
	var a_hi: float = PI * 1.5
	var angles: PackedFloat32Array = _angles(a_lo, a_hi, 30, false)
	var lo: PackedFloat32Array = PackedFloat32Array()
	var hi: PackedFloat32Array = PackedFloat32Array()
	var bulge_w: PackedFloat32Array = PackedFloat32Array()
	for a: float in angles:
		var edge: float = minf(a - a_lo, a_hi - a)
		var f: float = (a - a_lo) / (a_hi - a_lo)
		lo.append(lerpf(1.315, 1.165, pow(maxf(sin(PI * f), 0.0), 0.55)))
		hi.append(1.343)
		bulge_w.append(smoothstep(0.0, 0.5, edge))
	var rows: Array = []
	var n: int = 16
	for i: int in n + 1:
		var t: float = float(n - i) / float(n)  ## 0 at the collar, 1 at the free edge; rows run bottom to top
		var row: PackedVector3Array = PackedVector3Array()
		for k: int in angles.size():
			var bulge: float = 0.04 * sin(PI * pow(t, 0.8)) * bulge_w[k]
			var y: float = lerpf(hi[k], lo[k], t)
			row.append(_gpoint(secs, chest_y, y, angles[k], HOODIE_GROW + 0.004 + bulge, body_type, true, ref, false))
		rows.append(row)
	SkaterParts.part(rig["Chest"], "HoodieHoodMesh", SkaterParts.grid(rows, false), Vector3.ZERO, mats, "top")
	# The hood's rolled edge along the free sides.
	var edge_pts: PackedVector3Array = PackedVector3Array()
	for k: int in angles.size():
		edge_pts.append((rows[0] as PackedVector3Array)[k])
	var side_pts: Array = [PackedVector3Array(), PackedVector3Array()]
	for i: int in n + 1:
		(side_pts[0] as PackedVector3Array).append((rows[i] as PackedVector3Array)[0])
		(side_pts[1] as PackedVector3Array).append((rows[i] as PackedVector3Array)[angles.size() - 1])
	var rim: PackedVector3Array = PackedVector3Array()
	rim.append_array(side_pts[0])
	rim.append_array(edge_pts)
	var tail: PackedVector3Array = side_pts[1]
	tail.reverse()
	rim.append_array(tail)
	var rim_r: PackedFloat32Array = PackedFloat32Array()
	rim_r.resize(rim.size())
	rim_r.fill(0.0035)
	SkaterParts.part(rig["Chest"], "HoodieHoodRimMesh", SkaterParts.tube_capped(rim, rim_r, 6), Vector3.ZERO, mats, "top_trim")


## Kangaroo pocket: a panel across the belly, tapered into the hoodie round its edges, slanted openings piped in trim.
static func _pocket(rig: Dictionary, body_type: String, mats: Dictionary, ref: Array) -> void:
	var secs: Dictionary = rig["sections"]
	var hips_y: float = float(rig["rest_y"]["Hips"])
	var spine_y: float = float(rig["rest_y"]["Spine"])
	var amax: float = 0.8
	var cols: int = 24
	var n: int = 8
	var rows: Array = []
	for i: int in n + 1:
		var t: float = float(i) / float(n)
		var row: PackedVector3Array = PackedVector3Array()
		for k: int in cols + 1:
			var f: float = float(k) / float(cols)
			var a: float = lerpf(-amax, amax, f)
			var lo: float = 0.925 + 0.016 * smoothstep(0.5, 0.8, absf(a))
			var hi: float = 1.05 - 0.055 * smoothstep(0.3, 0.8, absf(a))
			var y: float = lerpf(lo, hi, t)
			var edge: float = minf(minf(t, 1.0 - t), minf(f, 1.0 - f) * 2.0)
			var lift: float = 0.0015 + 0.0055 * smoothstep(0.0, 0.2, edge)
			var ph: Vector3 = _gpoint(secs["pelvis"], hips_y, y, a, HOODIE_GROW + 0.007 + lift, body_type, true, ref, false)
			var pw: Vector3 = _gpoint(secs["waist"], spine_y, y, a, HOODIE_GROW + 0.003 + lift, body_type, true, ref, false)
			var pb: Vector3 = (ph + Vector3(0.0, hips_y, 0.0)) if Vector2(ph.x, ph.z).length() > Vector2(pw.x, pw.z).length() \
					else (pw + Vector3(0.0, spine_y, 0.0))
			row.append(pb - Vector3(0.0, spine_y, 0.0))
		rows.append(row)
	SkaterParts.part(rig["Spine"], "HoodiePocketMesh", SkaterParts.grid(rows, false), Vector3.ZERO, mats, "top")
	# Piping along the top (slanted openings).
	var top: PackedVector3Array = rows[rows.size() - 1]
	var r: PackedFloat32Array = PackedFloat32Array()
	r.resize(top.size())
	r.fill(0.0028)
	SkaterParts.part(rig["Spine"], "HoodiePocketTrimMesh", SkaterParts.tube_capped(top, r, 6), Vector3.ZERO, mats, "top_trim")


## Two drawstrings hanging from the neckline down the chest, ending in small aglets.
static func _drawstrings(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	var chest_y: float = float(rig["rest_y"]["Chest"])
	var male: bool = body_type == AnimeOutfit.MALE
	for s: float in [-1.0, 1.0]:
		var pts: PackedVector3Array = PackedVector3Array()
		var steps: int = 9
		var end: Vector3 = Vector3.ZERO
		for i: int in steps + 1:
			var t: float = float(i) / float(steps)
			var x: float = s * (0.026 + 0.006 * sin(t * 2.4) + 0.004 * t)
			var y: float = 1.322 - (0.12 if male else 0.105) * t
			end = _print_point(x, y, HOODIE_GROW + 0.0045, chest_y, body_type)
			pts.append(end)
		var radii: PackedFloat32Array = PackedFloat32Array()
		radii.resize(pts.size())
		radii.fill(0.0026)
		var side: String = "Left" if s < 0.0 else "Right"
		SkaterParts.part(rig["Chest"], "Hoodie" + side + "StringMesh", SkaterParts.tube_capped(pts, radii, 6), Vector3.ZERO, mats, "top_trim")
		SkaterParts.part(rig["Chest"], "Hoodie" + side + "AgletMesh", SkaterParts.sphere(0.0048), end + Vector3(0.0, -0.004, 0.0), mats, "top")


# --- flannel --------------------------------------------------------------------------------------------------

## Open plaid overshirt over a plain tee: panels with a front gap (the tee shows), a spread collar, and sleeves rolled up
## above the elbow with a thick cuff. "top" and "top_trim" make the plaid, "top_tee" is the tee.
static func flannel(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	_mats(mats)
	Wardrobe.mat(mats, "top_tee", TEE_DEFAULT)
	_plaid_mat(mats)
	var ref: Array = _ref_section(body_type)
	# The tee under it: a closed loose tee, shorter than the overshirt, short sleeves.
	var tee: Dictionary = _layer(rig, body_type, mats, "FlannelTee", TEE_GROW, 0.9, 1.335, {"key": "top_tee"}, ref, Callable())
	SkaterParts.part(rig["Hips"], "FlannelTeeHemMesh", _ring_tube((tee["hips"] as Array)[0], 0.003), Vector3.ZERO, mats, "top_tee")
	SkaterParts.part(rig["Chest"], "FlannelTeeCollarMesh", _ring_tube(tee["top"], 0.0065), Vector3.ZERO, mats, "top_tee")
	_sleeves(rig, body_type, mats, "FlannelTee", TEE_GROW + 0.002, true, 0.5, -1.0, {"key": "top_tee", "trim": "top_tee", "cuff_r": 0.004})
	# The overshirt: panels from the front gap (wider toward the hem) round the back.
	var over: Dictionary = _layer(rig, body_type, mats, "Flannel", FLANNEL_GROW, 0.855, 1.325, {"key": "top_plaid", "plaid": true}, ref,
			_flannel_gap)
	var hem: PackedVector3Array = (over["hips"] as Array)[0]
	var hem_r: PackedFloat32Array = PackedFloat32Array()
	hem_r.resize(hem.size())
	hem_r.fill(0.004)
	SkaterParts.part(rig["Hips"], "FlannelHemMesh", SkaterParts.tube_capped(hem, hem_r, 6), Vector3.ZERO, mats, "top")
	_flannel_collar(rig, body_type, mats, ref)
	_sleeves(rig, body_type, mats, "Flannel", FLANNEL_GROW, true, 0.82, -1.0, {"plaid": true, "key": "top_plaid", "trim": "top",
			"cuff_r": 0.0085})


## Half width of the flannel's open front at body height y: a narrow V at the collar opening up to the hem.
static func _flannel_gap(y: float) -> float:
	return clampf(0.03 + 0.09 * (1.31 - y), 0.03, 0.09)


## The chest, waist and hips pieces of one torso layer, cross-faded where they overlap so a twisting spine never shows a
## step: a closed ring, or (with a gap callable) an open panel round the back. Returns {"hips": rows, "top": the chest
## piece's top row}.
static func _layer(rig: Dictionary, body_type: String, mats: Dictionary, tag: String, grow: float, hem_y: float, collar_y: float,
		opt: Dictionary, ref: Array, gap: Callable) -> Dictionary:
	var secs: Dictionary = rig["sections"]
	var open: bool = gap.is_valid()
	var pieces: Array = [
		["Chest", "chest", 0.96, collar_y, Vector2(0.02, 0.0), true],
		["Spine", "waist", 0.88, 1.11, Vector2(0.02, 0.02), false],
		["Hips", "pelvis", hem_y, 1.035, Vector2(0.0, 0.02), false],
	]
	var out: Dictionary = {}
	for pc: Array in pieces:
		var base: float = float(rig["rest_y"][str(pc[0])])
		var rows: Array
		if open:
			rows = _panel_rows(secs[str(pc[1])], base, body_type, true, ref, grow, bool(pc[5]), float(pc[2]), float(pc[3]), 26, 44, pc[4], gap)
		else:
			var angles: PackedFloat32Array = _angles(0.0, TAU, 56, true)
			var lo: PackedFloat32Array = PackedFloat32Array()
			var hi: PackedFloat32Array = PackedFloat32Array()
			lo.resize(angles.size())
			hi.resize(angles.size())
			lo.fill(float(pc[2]))
			hi.fill(float(pc[3]))
			rows = _shaped(secs[str(pc[1])], base, body_type, true, ref, grow, grow, bool(pc[5]), angles, lo, hi, 26, pc[4])
		SkaterParts.part(rig[str(pc[0])], tag + str(pc[0]) + "Mesh", _surf(rows, opt, 0.0, TAU, base, 0.1, not open), Vector3.ZERO, mats,
				str(opt["key"]))
		if str(pc[0]) == "Chest":
			out["top"] = rows[rows.size() - 1]
		out["hips"] = rows
	return out


## Spread collar: a short band round the neck that flares outward toward its top edge, open at the front.
static func _flannel_collar(rig: Dictionary, body_type: String, mats: Dictionary, ref: Array) -> void:
	var chest_y: float = float(rig["rest_y"]["Chest"])
	var rows: Array = _panel_rows(rig["sections"]["chest"], chest_y, body_type, true, ref, FLANNEL_GROW + 0.001, true, 1.3, 1.352, 5, 36,
			Vector2(0.0, -0.011), func(_y: float) -> float: return 0.035)
	SkaterParts.part(rig["Chest"], "FlannelCollarMesh", _surf(rows, {"plaid": true}, 0.0, TAU, chest_y, 0.1, false), Vector3.ZERO, mats,
			"top_plaid")
	var top: PackedVector3Array = rows[rows.size() - 1]
	var r: PackedFloat32Array = PackedFloat32Array()
	r.resize(top.size())
	r.fill(0.0035)
	SkaterParts.part(rig["Chest"], "FlannelCollarEdgeMesh", SkaterParts.tube_capped(top, r, 6), Vector3.ZERO, mats, "top")
