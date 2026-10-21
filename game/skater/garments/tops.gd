class_name GarmentTops
extends RefCounted
## Top garments (slot "top"). Contract and registration: see Wardrobe (game/skater/wardrobe.gd).
## Built: top_bikini (female; the male body gets the surf tee), top_surf_tee, top_rash_guard.
## Palette keys: "top" (main fabric) and "top_trim" (piping, collar, cuffs, ringer bands).

const STUBS: PackedStringArray = ["top_crop_tank", "top_hoodie", "top_flannel"]
const GROW_TIGHT: float = 0.0045
const GROW_LOOSE: float = 0.008
const TOP_DEFAULT: Color = Color(0.07, 0.66, 0.7)
const TRIM_DEFAULT: Color = Color(1.0, 0.5, 0.4)
const CUP_BOTTOM_V: float = -1.2  ## overlaps the under-band, no gap
const CUP_TOP_V: float = 0.64  ## bust-field v of the cup's top point (about 1.19 m)


static func builders() -> Dictionary:
	return {
		"top_bikini": GarmentTops.bikini,
		"top_surf_tee": GarmentTops.surf_tee,
		"top_rash_guard": GarmentTops.rash_guard,
		"top_crop_tank": GarmentTops._stub.bind("top_crop_tank"),
		"top_hoodie": GarmentTops._stub.bind("top_hoodie"),
		"top_flannel": GarmentTops._stub.bind("top_flannel"),
	}


static func covers(id: String, body_type: String) -> PackedStringArray:
	var torso: PackedStringArray = ["hip_band", "belly", "waist_low", "waist", "under_bust", "chest", "chest_upper"]
	if body_type != AnimeOutfit.MALE:
		torso.append_array(["bust_L", "bust_R"])
	match id:
		"top_bikini":
			return PackedStringArray() if body_type != AnimeOutfit.MALE else covers("top_surf_tee", body_type)
		"top_surf_tee":
			return torso + PackedStringArray(["shoulder_L", "shoulder_R", "upper_arm_L", "upper_arm_R"])
		"top_rash_guard":
			return torso + PackedStringArray(["shoulder_L", "shoulder_R", "upper_arm_L", "upper_arm_R", "upper_arm_low_L",
					"upper_arm_low_R", "elbow_L", "elbow_R", "forearm_L", "forearm_R"])
	return PackedStringArray()


static func _stub(rig: Dictionary, body_type: String, mats: Dictionary, id: String) -> void:
	var fallback: Callable = GarmentTops.surf_tee if body_type == AnimeOutfit.MALE else GarmentTops.bikini
	Wardrobe.stub(rig, body_type, mats, "top", id, fallback)


static func _mats(mats: Dictionary) -> void:
	Wardrobe.mat(mats, "top", TOP_DEFAULT)
	Wardrobe.mat(mats, "top_trim", TRIM_DEFAULT)


# --- bikini ---------------------------------------------------------------------------------------------------

## Sporty bralette: a triangle cup over each bust form (under the same BodySway pivot, following the bust field
## CUP_GROW outside the skin everywhere), coral piping round the cups and the under-band, and straps over the
## shoulders to the back band. The male body has no bust, so it gets the surf tee.
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
		var span: Callable = func(v: float) -> Vector2:
			var k: float = clampf((v + 1.06) / 1.7, 0.0, 1.0)  ## full width up to the bottom of the form
			var half: float = lerpf(1.06, 0.05, pow(k, 1.1))
			var uc: float = 0.2 * k
			return Vector2(uc - half, uc + half * 0.84)  ## the outer side stays on the front of the ribs
		var rows: Array = AnimeOutfit.bust_rows(s, AnimeOutfit.CUP_GROW, CUP_BOTTOM_V, CUP_TOP_V, 40, 24, span)
		SkaterParts.part(pivot, "BikiniCup" + side + "Mesh", SkaterParts.facing_grid(AnimeOutfit.rows_to_local(rows, origin),
				Vector3.FORWARD), Vector3.ZERO, mats, "top")
		var trim_rows: Array = AnimeOutfit.bust_rows(s, AnimeOutfit.CUP_GROW + 0.0014, CUP_BOTTOM_V, CUP_TOP_V, 40, 24, span)
		var pts: PackedVector3Array = PackedVector3Array()
		var first: int = 5  ## the rows below the form's rim lie under the band: no piping there
		for i: int in range(first, trim_rows.size()):
			pts.append((trim_rows[i] as PackedVector3Array)[0] - origin)
		for i: int in range(trim_rows.size() - 1, first - 1, -1):
			var row: PackedVector3Array = trim_rows[i]
			pts.append(row[row.size() - 1] - origin)
		var radii: PackedFloat32Array = PackedFloat32Array()
		radii.resize(pts.size())
		radii.fill(0.0032)
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


## Rings of a torso shirt piece over smoothed body sections (joint space, `base` = joint rest y), from y0 to y1
## (body space). loose: never narrower than the under-bust (it hangs, it does not cinch at the waist).
static var _fine: Dictionary = {}


## The chest sections smoothed as finely as AnimeOutfit.chest_skin() smooths them (body space).
static func _fine_chest(body_type: String) -> Array:
	if not _fine.has(body_type):
		_fine[body_type] = SkaterParts.smooth_sections(AnimeOutfit.skin_sections("chest", body_type), 6)
	return _fine[body_type]


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
			ring.append(p)
		rows.append(ring)
	return rows


static func _shirt(rig: Dictionary, body_type: String, mats: Dictionary, tag: String, grow: float, loose: bool,
		sleeve_end: float, forearm_end: float) -> void:
	var secs: Dictionary = rig["sections"]
	var ry: Dictionary = rig["rest_y"]
	var chest_y: float = float(ry["Chest"])
	var spine_y: float = float(ry["Spine"])
	var hips_y: float = float(ry["Hips"])
	var ref_y: float = 1.06
	var ref: Array = SkaterParts.section_at(SkaterParts.smooth_sections(AnimeOutfit.skin_sections("chest", body_type), 3), ref_y)
	ref = ref.duplicate()
	for f: int in [1, 2, 3]:
		ref[f] = float(ref[f]) * 0.97
	var collar_y: float = (1.345 if body_type == AnimeOutfit.MALE else 1.335) if loose else 1.35
	var hem_y: float = 0.885 if loose else 0.9
	# Chest piece (with the bust) on Chest; waist piece on Spine; hips piece on Hips. They overlap, so a bent spine
	# never opens a gap.
	var chest_rows: Array = _torso_rows(secs["chest"], chest_y, 0.975, collar_y, grow, body_type, loose, ref, true)
	SkaterParts.part(rig["Chest"], tag + "ChestMesh", SkaterParts.grid(chest_rows, true), Vector3.ZERO, mats, "top")
	var waist_rows: Array = _torso_rows(secs["waist"], spine_y, 0.9, 1.11, grow + (0.003 if loose else 0.001), body_type, loose, ref, false)
	SkaterParts.part(rig["Spine"], tag + "WaistMesh", SkaterParts.grid(waist_rows, true), Vector3.ZERO, mats, "top")
	var hips_rows: Array = _torso_rows(secs["pelvis"], hips_y, hem_y, 1.035, grow + (0.007 if loose else 0.001), body_type, loose, ref, false)
	SkaterParts.part(rig["Hips"], tag + "HipsMesh", SkaterParts.grid(hips_rows, true), Vector3.ZERO, mats, "top")
	# Collar and hem.
	var collar: PackedVector3Array = chest_rows[chest_rows.size() - 1]
	SkaterParts.part(rig["Chest"], tag + "CollarMesh", _ring_tube(collar, 0.0055 if loose else 0.007), Vector3.ZERO, mats,
			"top_trim")
	SkaterParts.part(rig["Hips"], tag + "HemMesh", _ring_tube(hips_rows[0], 0.004 if loose else 0.002), Vector3.ZERO, mats, "top")
	# Contrast panel across the chest (rash guard).
	if loose:
		_sleeves(rig, body_type, mats, tag, grow, loose, sleeve_end, forearm_end)
		return
	var band_rows: Array = _torso_rows(secs["chest"], chest_y, 1.165, 1.215, grow + 0.0015, body_type, loose,
			ref, true)
	SkaterParts.part(rig["Chest"], tag + "BandMesh", SkaterParts.grid(band_rows, true), Vector3.ZERO, mats, "top_trim")
	_sleeves(rig, body_type, mats, tag, grow, loose, sleeve_end, forearm_end)


static func _sleeves(rig: Dictionary, body_type: String, mats: Dictionary, tag: String, grow: float, loose: bool,
		sleeve_end: float, forearm_end: float) -> void:
	var secs: Dictionary = rig["sections"]
	var ul: float = float(rig["lengths"]["upper_arm"])
	var ll: float = float(rig["lengths"]["lower_arm"])
	var male: bool = body_type == AnimeOutfit.MALE
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
		SkaterParts.part(upper, side + tag + "SleeveMesh", SkaterParts.grid(rows, true), Vector3.ZERO, mats, "top")
		if forearm_end <= 0.0:
			SkaterParts.part(upper, side + tag + "CuffMesh", _ring_tube(rows[0], 0.0045), Vector3.ZERO, mats, "top_trim")
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
			SkaterParts.part(lower, side + tag + "ForearmSleeveMesh", SkaterParts.grid(frows, true), Vector3.ZERO, mats, "top")
			SkaterParts.part(lower, side + tag + "CuffMesh", _ring_tube(frows[0], 0.0045), Vector3.ZERO, mats, "top_trim")


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
