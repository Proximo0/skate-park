class_name HairStyles
extends RefCounted
## Hair styles (Wardrobe slot "hair"), built on the head by AnimeHead.build(). Contract and registration: see
## Wardrobe (game/skater/wardrobe.gd); rig["HeadModel"] is the node to build under (face toward -Z, the head
## surface helpers are AnimeHead.cap_point / face_z / face_normal / lock_mesh / pivot_lock / cap_mesh).
## HAIR SWAY CONVENTION: hair that should sway hangs from identity-rotation Node3D pivots named "HairSway_<Name>"
## under HeadModel, placed at the root of the locks they carry; a chain numbers on: "HairSway_<Name>" >
## "HairSway_<Name>2" > "HairSway_<Name>3". Side locks use "HairSway_SideL" / "HairSway_SideR" (L = -X).
## One exception: hair_long's back curtain (HairSway_Back > HairSway_Back2) hangs from the Neck joint, not the head,
## so it stays on the back when the head turns hard over a shoulder (a rigid curtain on the head would swing through
## the shoulder); its top is tucked under the head's own back locks. Without a Neck in the rig it hangs from HeadModel.
## Its pivots carry meta "sway_fwd_limit_deg" (2): a forward swing would push the curtain through the back, and
## SecondaryMotion has no collisions; until it honours that meta the curtain can dip into the back in a deep crouch.
## Every style is a scalp cap ("HairCapMesh") under layered, tapered locks. Head-attached locks keep above the
## shoulder line for their distance from the neck axis (yaw-proof: the riding look turns the head ~70 degrees),
## bangs end at or above the brows. tests/unit/test_garments_hair.gd checks builds, pivots, budget and clearance.
## Palette keys: "hair_base", "hair_mid", "hair_shadow", "hair_deep", "hair_shine" (AnimeHead.COLORS defaults),
## "hair_tie" (ponytail tie, pigtail bobbles, bun scrunchie), "flower", "flower_center".
## Built: hair_ponytail (pivots HairSway_SideL/R and the chain HairSway_Ponytail > 2 > 3), hair_messy (pivots
## HairSway_SideL/R and HairSway_Fringe), hair_bob (SideL/R), hair_long (SideL/R, Back > Back2 on the neck),
## hair_pigtails (SideL/R, PigtailL > PigtailL2, PigtailR > PigtailR2), hair_bun (SideL/R), hair_short_spiky
## (Fringe), hair_undercut (Fringe), hair_buzz (none: too short to sway), hair_shaggy (SideL/R, Nape, Fringe).

const STUBS: PackedStringArray = []


static func builders() -> Dictionary:
	return {
		"hair_ponytail": HairStyles.ponytail, "hair_messy": HairStyles.messy, "hair_bob": HairStyles.bob,
		"hair_long": HairStyles.long_hair, "hair_pigtails": HairStyles.pigtails, "hair_bun": HairStyles.bun,
		"hair_short_spiky": HairStyles.short_spiky, "hair_undercut": HairStyles.undercut, "hair_buzz": HairStyles.buzz,
		"hair_shaggy": HairStyles.shaggy,
	}


# --- ponytail (reference style) -----------------------------------------------------------------------------

## Sun-bleached high ponytail: a scalp cap, 10 tapered bangs ending at the brows, 3 side locks a side framing the
## face (HairSway_SideL/R), 11 strands gathered up to a coral tie, a 4-lock ponytail over the sway chain
## HairSway_Ponytail > 2 > 3, angel-ring sheen and a white flower clip.
static func ponytail(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	Wardrobe.mat(mats, "hair_tie", Color(1.0, 0.42, 0.36))
	Wardrobe.mat(mats, "flower", Color(1.0, 0.97, 0.92))
	Wardrobe.mat(mats, "flower_center", Color(1.0, 0.8, 0.2))
	var head: Node3D = rig["HeadModel"]
	_build_hair(head, mats)
	_build_ponytail(head, mats)
	_build_flower(head, mats)


static func _build_hair(head: Node3D, mats: Dictionary) -> void:
	SkaterParts.part(head, "HairCapMesh", AnimeHead.cap_mesh(), Vector3.ZERO, mats, "hair_mid")
	_build_bangs(head, mats)
	_build_gathered(head, mats)
	for s: float in [-1.0, 1.0]:
		_build_side(head, mats, s)


## Bangs: x_root, x_tip, y_tip, half width, palette key, lift over the cap.
static func _build_bangs(head: Node3D, mats: Dictionary) -> void:
	var specs: Array = [
		[-0.014, -0.034, 0.09, 0.0125, "hair_shadow", 0.0],
		[0.008, 0.016, 0.093, 0.0125, "hair_shadow", 0.0],
		[0.026, 0.05, 0.087, 0.0125, "hair_shadow", 0.0],
		[-0.032, -0.066, 0.078, 0.0135, "hair_base", 0.003],
		[-0.022, -0.046, 0.093, 0.0125, "hair_base", 0.003],
		[-0.01, -0.022, 0.099, 0.0115, "hair_base", 0.003],
		[0.002, 0.003, 0.095, 0.0115, "hair_base", 0.003],
		[0.013, 0.026, 0.1, 0.0115, "hair_base", 0.003],
		[0.023, 0.047, 0.093, 0.0125, "hair_base", 0.003],
		[0.032, 0.066, 0.078, 0.0135, "hair_base", 0.003],
	]
	for i: int in specs.size():
		var b: Array = specs[i]
		var xr: float = float(b[0])
		var xt: float = float(b[1])
		var yt: float = float(b[2])
		var hw: float = float(b[3])
		var lift: float = float(b[5])
		var pts: PackedVector3Array = PackedVector3Array()
		var ws: PackedFloat32Array = PackedFloat32Array()
		var ts: PackedFloat32Array = PackedFloat32Array()
		var n_pts: int = 7
		for k: int in n_pts:
			var t: float = float(k) / float(n_pts - 1)
			var y: float = lerpf(0.176, yt, t)
			var x: float = lerpf(xr, xt, t * t * (3.0 - 2.0 * t))
			var d: float = lerpf(0.005, 0.0125 + lift, smoothstep(0.0, 0.25, t)) - 0.007 * pow(t, 3.0)
			var base: Vector3 = Vector3(x, y, AnimeHead.face_z(x, y))
			pts.append(base + AnimeHead.face_normal(x, y) * d)
			ws.append(hw * (0.75 + 0.35 * sin(PI * minf(t * 1.4, 1.0) * 0.5)) * (1.0 - pow(t, 2.2)) + 0.0004)
			ts.append(0.0028 * (1.0 - t * 0.8) + 0.0004)
		var key: String = str(b[4])
		SkaterParts.part(head, "Bang%dMesh" % i, AnimeHead.lock_mesh(pts, ws, ts, AnimeHead.radial_normals(pts, AnimeHead.CENTER), 0.22, 10, 3),
				Vector3.ZERO, mats, key)


## Strands over the back and sides of the scalp, gathered up to the ponytail tie.
static func _build_gathered(head: Node3D, mats: Dictionary) -> void:
	var tie: Vector3 = AnimeHead.cap_point(PI, AnimeHead.PONY_ROOT_Y, AnimeHead.CAP_T)
	# start angle (deg), start height, half width, key
	var specs: Array = [
		[112.0, 0.036, 0.013, "hair_base"], [130.0, 0.008, 0.014, "hair_mid"], [146.0, -0.008, 0.014, "hair_base"],
		[163.0, -0.016, 0.014, "hair_mid"], [180.0, -0.018, 0.014, "hair_base"], [-163.0, -0.016, 0.014, "hair_mid"],
		[-146.0, -0.008, 0.014, "hair_base"], [-130.0, 0.008, 0.014, "hair_mid"], [-112.0, 0.036, 0.013, "hair_base"],
		[72.0, 0.13, 0.009, "hair_base", 0.45], [-72.0, 0.13, 0.009, "hair_base", 0.45],
	]
	for i: int in specs.size():
		var sp: Array = specs[i]
		var a0: float = deg_to_rad(float(sp[0]))
		var y0: float = float(sp[1])
		var a1: float = PI if a0 > 0.0 else -PI
		var pts: PackedVector3Array = PackedVector3Array()
		var ws: PackedFloat32Array = PackedFloat32Array()
		var ts: PackedFloat32Array = PackedFloat32Array()
		var n_pts: int = 7
		for k: int in n_pts:
			var t: float = float(k) / float(n_pts - 1)
			var a: float = lerpf(a0, a1, pow(t, 1.6))
			var y: float = lerpf(y0, AnimeHead.PONY_ROOT_Y - 0.004, t)
			var flat: float = float(sp[4]) if sp.size() > 4 else 1.0
			var q: Vector3 = AnimeHead.cap_point(a, y, AnimeHead.CAP_T + (0.0016 + 0.0025 * sin(PI * t)) * flat - 0.004 * pow(1.0 - t, 4.0))
			if k == n_pts - 1:
				q = tie
			pts.append(q)
			var wt: float = float(sp[2]) * (0.25 + 0.75 * smoothstep(0.0, 0.3, t)) * (1.0 - 0.45 * t)
			ws.append(wt)
			ts.append(0.0032 * flat * (0.4 + 0.6 * smoothstep(0.0, 0.3, t)))
		SkaterParts.part(head, "HairStrand%dMesh" % i, AnimeHead.lock_mesh(pts, ws, ts, AnimeHead.radial_normals(pts, AnimeHead.CENTER), 0.3, 8, 4),
				Vector3.ZERO, mats, str(sp[3]))
	# Angel-ring sheen: short soft streaks a third of the way down the crown.
	for i: int in 4:
		var a: float = deg_to_rad([-100.0, -55.0, 55.0, 100.0][i])
		var pts: PackedVector3Array = PackedVector3Array()
		for k: int in 4:
			var aa: float = a + deg_to_rad(-9.0 + 6.0 * float(k))
			var y: float = 0.158 + 0.003 * sin(PI * float(k) / 3.0) - 0.012 * absf(sin(a))
			pts.append(AnimeHead.cap_point(aa, y, AnimeHead.CAP_T + 0.0075))
		var ws: PackedFloat32Array = PackedFloat32Array([0.0006, 0.0028, 0.0028, 0.0006])
		var ts: PackedFloat32Array = PackedFloat32Array([0.0006, 0.0012, 0.0012, 0.0006])
		SkaterParts.part(head, "HairShine%dMesh" % i, AnimeHead.lock_mesh(pts, ws, ts, AnimeHead.radial_normals(pts, AnimeHead.CENTER), 0.0, 8, 3),
				Vector3.ZERO, mats, "hair_shine")


## Three locks per side framing the face (a long front lock curling in at the collarbone, a shorter one beside it and
## a shadow lock behind), hanging from a HairSway_Side pivot at the temple.
static func _build_side(head: Node3D, mats: Dictionary, s: float) -> void:
	var tag: String = "L" if s < 0.0 else "R"
	var root: Vector3 = Vector3(s * 0.068, 0.128, -0.046)
	var pivot: Node3D = SkaterParts.joint(head, "HairSway_Side" + tag, root)
	var front: PackedVector3Array = PackedVector3Array([
		Vector3(s * 0.058, 0.142, -0.054), Vector3(s * 0.071, 0.115, -0.068), Vector3(s * 0.075, 0.075, -0.073),
		Vector3(s * 0.074, 0.035, -0.066), Vector3(s * 0.079, -0.004, -0.055), Vector3(s * 0.078, -0.03, -0.054),
		Vector3(s * 0.067, -0.05, -0.064), Vector3(s * 0.054, -0.06, -0.077), Vector3(s * 0.045, -0.06, -0.087),
	])
	var fw: PackedFloat32Array = PackedFloat32Array([0.0065, 0.0095, 0.0105, 0.0105, 0.0102, 0.009, 0.0065, 0.003, 0.0004])
	var ft: PackedFloat32Array = PackedFloat32Array([0.0028, 0.0034, 0.0036, 0.0034, 0.0032, 0.0028, 0.002, 0.0012, 0.0004])
	AnimeHead.pivot_lock(pivot, "SideLock" + tag + "Mesh", mats, "hair_base", front, fw, ft, 0.35, true, 0.55)
	var mid: PackedVector3Array = PackedVector3Array([
		Vector3(s * 0.066, 0.136, -0.036), Vector3(s * 0.08, 0.105, -0.046), Vector3(s * 0.087, 0.06, -0.04),
		Vector3(s * 0.087, 0.015, -0.042), Vector3(s * 0.083, -0.022, -0.05), Vector3(s * 0.078, -0.045, -0.054),
		Vector3(s * 0.072, -0.054, -0.06),
	])
	var mw: PackedFloat32Array = PackedFloat32Array([0.008, 0.011, 0.012, 0.011, 0.008, 0.004, 0.0004])
	var mt: PackedFloat32Array = PackedFloat32Array([0.0028, 0.0034, 0.0035, 0.0032, 0.0026, 0.0016, 0.0004])
	AnimeHead.pivot_lock(pivot, "SideLockMid" + tag + "Mesh", mats, "hair_mid", mid, mw, mt, 0.35, true, 0.3)
	var back: PackedVector3Array = PackedVector3Array([
		Vector3(s * 0.07, 0.128, -0.018), Vector3(s * 0.084, 0.09, -0.024), Vector3(s * 0.089, 0.045, -0.02),
		Vector3(s * 0.087, 0.005, -0.014), Vector3(s * 0.08, -0.025, -0.016), Vector3(s * 0.074, -0.038, -0.026),
	])
	var bw: PackedFloat32Array = PackedFloat32Array([0.01, 0.0135, 0.014, 0.012, 0.007, 0.0004])
	var bt: PackedFloat32Array = PackedFloat32Array([0.003, 0.0034, 0.0034, 0.003, 0.002, 0.0004])
	AnimeHead.pivot_lock(pivot, "SideLockBack" + tag + "Mesh", mats, "hair_shadow", back, bw, bt, 0.3, true)


## High ponytail: a coral tie at the back of the crown and four locks (main mass, two side locks, an under lock) that
## rise, arc back and fall to the upper back. Split over the sway chain HairSway_Ponytail > 2 > 3.
static func _build_ponytail(head: Node3D, mats: Dictionary) -> void:
	var root: Vector3 = AnimeHead.cap_point(PI, AnimeHead.PONY_ROOT_Y, AnimeHead.CAP_T) + Vector3(0.0, 0.0, 0.004)
	var base: Array = [
		Vector3(0.0, 0.0, -0.01), Vector3(0.0, 0.018, 0.036), Vector3(0.0, 0.014, 0.08), Vector3(0.0, -0.022, 0.112),
		Vector3(0.0, -0.09, 0.134), Vector3(0.0, -0.17, 0.142), Vector3(0.0, -0.25, 0.146), Vector3(0.0, -0.32, 0.15),
		Vector3(0.0, -0.37, 0.162),
	]
	var p1: Node3D = SkaterParts.joint(head, "HairSway_Ponytail", root)
	var p2: Node3D = SkaterParts.joint(p1, "HairSway_Ponytail2", base[3] as Vector3)
	var p3: Node3D = SkaterParts.joint(p2, "HairSway_Ponytail3", (base[5] as Vector3) - (base[3] as Vector3))
	var tie: MeshInstance3D = SkaterParts.part(p1, "HairTieMesh", SkaterParts.torus(0.016, 0.024), Vector3(0.0, 0.004, 0.008),
			mats, "hair_tie")
	tie.rotation.x = PI * 0.5 - 1.1
	var wbase: PackedFloat32Array = PackedFloat32Array([0.017, 0.024, 0.031, 0.035, 0.036, 0.032, 0.025, 0.014, 0.0006])
	# name, x offset, z offset, width scale, length scale, wave amplitude, wave phase, key, thickness ratio
	var specs: Array = [
		["PonytailMesh", 0.0, 0.0, 0.92, 1.0, 0.005, 0.0, "hair_base", 0.62],
		["PonytailLockL", -0.023, -0.006, 0.55, 0.92, 0.013, 1.7, "hair_mid", 0.55],
		["PonytailLockR", 0.023, -0.004, 0.55, 0.97, 0.013, 3.4, "hair_mid", 0.55],
		["PonytailUnder", 0.0, -0.01, 0.62, 0.84, 0.008, 5.0, "hair_mid", 0.6],
	]
	var sub: int = 4
	for sp: Array in specs:
		var pts: PackedVector3Array = PackedVector3Array()
		var ws: PackedFloat32Array = PackedFloat32Array()
		var ts: PackedFloat32Array = PackedFloat32Array()
		var nrm: PackedVector3Array = PackedVector3Array()
		for k: int in base.size():
			var t: float = float(k) / float(base.size() - 1)
			var b: Vector3 = base[k]
			var spread: float = smoothstep(0.0, 0.3, t)
			var fan: float = 1.0 + 0.9 * smoothstep(0.55, 1.0, t)
			var q: Vector3 = Vector3(float(sp[1]) * spread * fan + float(sp[5]) * sin(t * 6.5 + float(sp[6])) * t,
					b.y * float(sp[4]), b.z + float(sp[2]) * spread)
			if k == 0:
				q = b
			pts.append(q)
			ws.append(wbase[k] * float(sp[3]))
			ts.append(wbase[k] * float(sp[3]) * float(sp[8]) + 0.0004)
			var away: Vector3 = Vector3(0.0, 0.25, 1.0).normalized() if k < 3 else Vector3(0.0, 0.0, 1.0)
			nrm.append((away + Vector3(float(sp[1]) * 30.0, 0.0, 0.0)).normalized())
		var p: PackedVector3Array = AnimeHead.smooth(pts, sub)
		var w: PackedFloat32Array = AnimeHead.smooth_r(ws, sub)
		var th: PackedFloat32Array = AnimeHead.smooth_r(ts, sub)
		var nn: PackedVector3Array = AnimeHead.smooth(nrm, sub)
		# Split at the pivots (control points 3 and 5), overlapping one sample.
		var cuts: Array = [[0, 3 * sub + 1, p1, Vector3.ZERO], [3 * sub - 1, 5 * sub + 1, p2, base[3]],
				[5 * sub - 1, p.size() - 1, p3, base[5]]]
		for ci: int in cuts.size():
			var c: Array = cuts[ci]
			var off: Vector3 = c[3]
			var sp_pts: PackedVector3Array = PackedVector3Array()
			var sp_w: PackedFloat32Array = PackedFloat32Array()
			var sp_t: PackedFloat32Array = PackedFloat32Array()
			var sp_n: PackedVector3Array = PackedVector3Array()
			for i: int in range(int(c[0]), int(c[1]) + 1):
				sp_pts.append(p[i] - off)
				sp_w.append(w[i])
				sp_t.append(th[i])
				sp_n.append(nn[i])
			var part_name: String = str(sp[0]) + ("" if ci == 0 else str(ci + 1))
			SkaterParts.part(c[2] as Node3D, part_name, AnimeHead.lock_from(sp_pts, sp_w, sp_t, sp_n, 0.06, 10), Vector3.ZERO,
					mats, str(sp[7]))


## Small white flower hair clip above the left temple.
static func _build_flower(head: Node3D, mats: Dictionary) -> void:
	var a: float = deg_to_rad(-58.0)
	var c: Vector3 = AnimeHead.cap_point(a, 0.142, AnimeHead.CAP_T + 0.006)
	var holder: Node3D = SkaterParts.joint(head, "FlowerClip", c)
	var outward: Vector3 = (c - AnimeHead.CENTER).normalized()
	holder.basis = Basis.looking_at(outward, Vector3.UP)
	for i: int in 5:
		var ang: float = TAU * float(i) / 5.0
		var pet: MeshInstance3D = SkaterParts.part(holder, "FlowerPetal%dMesh" % i, SkaterParts.sphere_small(0.0085),
				Vector3(sin(ang) * 0.0085, cos(ang) * 0.0085, -0.001), mats, "flower")
		pet.scale = Vector3(0.85, 1.1, 0.45)
		pet.rotation.z = -ang
	SkaterParts.part(holder, "FlowerCenterMesh", SkaterParts.sphere_small(0.0045), Vector3(0.0, 0.0, -0.003), mats,
			"flower_center")


# --- messy (male reference style) ---------------------------------------------------------------------------

## Short, messy anime-lead hair: a scalp cap, wide tufts swept from a whorl at the back of the crown over the top
## (their tips flick up), choppy back locks flicking out at the nape, locks over the ears and sideburns
## (HairSway_SideL/R), and a jagged fringe of pointed bangs falling to the brows (HairSway_Fringe).
static func messy(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	var head: Node3D = rig["HeadModel"]
	SkaterParts.part(head, "HairCapMesh", AnimeHead.cap_mesh(), Vector3.ZERO, mats, "hair_mid")
	var whorl: Vector2 = Vector2(180.0, 42.0)
	# Back: choppy locks from the crown to the nape, alternating shades, tips flicking out.
	for i: int in range(-3, 4):
		var fi: float = float(i)
		var key: String = "hair_base" if i % 2 == 0 else "hair_mid"
		_tuft(head, mats, "MessyBack%dMesh" % (i + 3), Vector2(180.0 + fi * 22.0, 52.0), Vector2(180.0 + fi * 27.0, -38.0 + 7.0 * absf(fi)),
				0.024, 0.011, key, 0.35)
	for sd: Array in Wardrobe.sides():
		var s: float = sd[1]
		var tag: String = "L" if s < 0.0 else "R"
		_tuft(head, mats, "MessySideBack" + tag + "Mesh", Vector2(s * 130.0, 48.0), Vector2(s * 118.0, -22.0), 0.022, 0.009, "hair_shadow", 0.3)
	# Top: wide tufts swept from the whorl over the crown in every direction, tips lifting into spikes.
	var tops: Array = [
		[0.0, 50.0, "hair_base"], [28.0, 48.0, "hair_mid"], [-28.0, 48.0, "hair_base"], [62.0, 44.0, "hair_base"],
		[-62.0, 44.0, "hair_mid"], [100.0, 38.0, "hair_mid"], [-100.0, 38.0, "hair_base"], [140.0, 40.0, "hair_base"],
		[-140.0, 40.0, "hair_mid"], [16.0, 58.0, "hair_mid"], [-44.0, 56.0, "hair_base"],
	]
	for i: int in tops.size():
		var tp: Array = tops[i]
		var tip: Vector2 = Vector2(float(tp[0]), float(tp[1]))
		_tuft(head, mats, "MessyTop%dMesh" % i, _toward(whorl, tip, 0.18), tip, 0.027, 0.012 if i < 9 else 0.008,
				str(tp[2]), 0.25, 0.006 if i < 9 else 0.011)
	_gloss(head, mats, 0.016)
	# Sides: over the ear and a sideburn in front of it, on a sway pivot at the temple.
	for sd: Array in Wardrobe.sides():
		var s: float = sd[1]
		var tag: String = "L" if s < 0.0 else "R"
		var pivot: Node3D = SkaterParts.joint(head, "HairSway_Side" + tag, Vector3(s * 0.07, 0.13, -0.03))
		_tuft(pivot, mats, "MessyOverEar" + tag + "Mesh", Vector2(s * 98.0, 52.0), Vector2(s * 104.0, -4.0), 0.021, 0.008, "hair_base", 0.3)
		_tuft(pivot, mats, "MessyTemple" + tag + "Mesh", Vector2(s * 72.0, 50.0), Vector2(s * 80.0, -14.0), 0.016, 0.004, "hair_mid", 0.25)
		_tuft(pivot, mats, "MessyTempleBack" + tag + "Mesh", Vector2(s * 84.0, 56.0), Vector2(s * 92.0, 2.0), 0.018, 0.012, "hair_shadow", 0.3)
	# Fringe: pointed bangs, slanting and crossing, ending around the brows, over a darker under-layer.
	var fringe: Node3D = SkaterParts.joint(head, "HairSway_Fringe", Vector3(0.0, 0.172, -0.07))
	var bangs: Array = [
		[-0.058, -0.074, 0.112, 0.013, "hair_shadow", 0.0], [0.06, 0.075, 0.116, 0.013, "hair_shadow", 0.0],
		[-0.004, -0.02, 0.098, 0.016, "hair_shadow", 0.0],
		[-0.05, -0.068, 0.106, 0.015, "hair_base", 0.006], [-0.03, -0.048, 0.094, 0.015, "hair_mid", 0.007],
		[-0.012, -0.03, 0.088, 0.014, "hair_base", 0.008], [0.004, 0.012, 0.096, 0.015, "hair_base", 0.008],
		[0.022, 0.04, 0.09, 0.014, "hair_mid", 0.007], [0.04, 0.06, 0.1, 0.015, "hair_base", 0.006],
		[0.056, 0.072, 0.114, 0.014, "hair_mid", 0.005],
	]
	for i: int in bangs.size():
		var b: Array = bangs[i]
		var xr: float = float(b[0])
		var xt: float = float(b[1])
		var yt: float = float(b[2])
		var hw: float = float(b[3])
		var lift: float = float(b[5])
		var pts: PackedVector3Array = PackedVector3Array()
		var ws: PackedFloat32Array = PackedFloat32Array()
		var ts: PackedFloat32Array = PackedFloat32Array()
		for k: int in 7:
			var t: float = float(k) / 6.0
			var y: float = lerpf(0.182, yt, t)
			var x: float = lerpf(xr, xt, t * t)
			var d: float = lerpf(0.008, 0.016 + lift, smoothstep(0.0, 0.3, t)) - 0.008 * pow(t, 2.5)
			pts.append(Vector3(x, y, AnimeHead.face_z(x, y)) + AnimeHead.face_normal(x, y) * d - fringe.position)
			ws.append(hw * (0.8 + 0.3 * sin(PI * minf(t * 1.5, 1.0) * 0.5)) * (1.0 - pow(t, 1.6)) + 0.0004)
			ts.append(0.0036 * (1.0 - t * 0.75) + 0.0004)
		var nrm: PackedVector3Array = PackedVector3Array()
		for q: Vector3 in pts:
			nrm.append((q + fringe.position - AnimeHead.CENTER).normalized())
		SkaterParts.part(fringe, "MessyBang%dMesh" % i, AnimeHead.lock_mesh(pts, ws, ts, nrm, 0.25, 10, 3), Vector3.ZERO, mats,
				str(b[4]))


## A lock lying over the scalp from root to tip, given as (azimuth, elevation) in degrees seen from the head centre
## (azimuth 0 = front, + toward +X; elevation 90 = straight up). Its tip lifts off the scalp by `flick` (a spiky end).
## Built in head space, then made relative to `parent` (HeadModel or a sway pivot under it).
static func _tuft(parent: Node3D, mats: Dictionary, part_name: String, root: Vector2, tip: Vector2, hw: float, flick: float, key: String,
		curl: float, base_lift: float = 0.004) -> void:
	var d0: Vector3 = _dir(root)
	var d1: Vector3 = _dir(tip)
	var off: Vector3 = parent.position if parent.name != "HeadModel" else Vector3.ZERO
	var pts: PackedVector3Array = PackedVector3Array()
	var ws: PackedFloat32Array = PackedFloat32Array()
	var ts: PackedFloat32Array = PackedFloat32Array()
	var nrm: PackedVector3Array = PackedVector3Array()
	var n: int = 7
	for k: int in n:
		var t: float = float(k) / float(n - 1)
		var d: Vector3 = d0.slerp(d1, t) if d0.dot(d1) > -0.99 else d0.lerp(d1, t).normalized()
		var lift: float = AnimeHead.CAP_T + base_lift + 0.005 * sin(PI * t) + flick * pow(t, 2.2)
		var q: Vector3 = _on_head(d, lift)
		pts.append(q - off)
		nrm.append((q - AnimeHead.CENTER).normalized())
		ws.append(hw * (0.55 + 0.45 * smoothstep(0.0, 0.3, t)) * (1.0 - pow(t, 1.5)) + 0.0005)
		ts.append(0.0042 * (1.0 - 0.7 * t) + 0.0005)
	SkaterParts.part(parent, part_name, AnimeHead.lock_mesh(pts, ws, ts, nrm, curl, 10, 4), Vector3.ZERO, mats, key)


## (azimuth, elevation) a fraction f of the way from a to b on the sphere.
static func _toward(a: Vector2, b: Vector2, f: float) -> Vector2:
	var d: Vector3 = _dir(a).slerp(_dir(b), f)
	return Vector2(rad_to_deg(atan2(d.x, -d.z)), rad_to_deg(asin(clampf(d.y, -1.0, 1.0))))


## Unit direction from the head centre for (azimuth, elevation) in degrees.
static func _dir(ae: Vector2) -> Vector3:
	var a: float = deg_to_rad(ae.x)
	var e: float = deg_to_rad(ae.y)
	return Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))


## Scalp point (lifted t) in direction d from the head centre: finds the head height with that elevation.
static func _on_head(d: Vector3, t: float) -> Vector3:
	var a: float = atan2(d.x, -d.z)
	var e: float = asin(clampf(d.y, -1.0, 1.0))
	var lo: float = -0.04
	var hi: float = AnimeHead.CROWN_Y
	for i: int in 22:
		var mid: float = (lo + hi) * 0.5
		var p: Vector3 = AnimeHead.head_point(a, mid) - AnimeHead.CENTER
		var pe: float = atan2(p.y, Vector2(p.x, p.z).length())
		if pe < e:
			lo = mid
		else:
			hi = mid
	return AnimeHead.cap_point(a, (lo + hi) * 0.5, t)


# --- shared lock helpers (the new styles) -------------------------------------------------------------------

## Height below which hair stops following the dome and hangs straight down from the head's widest point.
const HANG_Y: float = 0.095


## Head-space position of a hair parent: zero for HeadModel, else the "hs" meta set by _pivot (falls back to the
## node's own position, for pivots made directly under HeadModel by the reference styles).
static func _hs(node: Node3D) -> Vector3:
	if node.has_meta("hs"):
		return node.get_meta("hs")
	if str(node.name) == "HeadModel":
		return Vector3.ZERO
	return node.position


## Identity-rotation sway pivot at head-space point hs under parent (HeadModel or another pivot).
static func _pivot(parent: Node3D, pivot_name: String, hs: Vector3) -> Node3D:
	var p: Node3D = SkaterParts.joint(parent, pivot_name, hs - _hs(parent))
	p.set_meta("hs", hs)
	return p


## Sway pivot hung from the Neck joint (so it does not turn with the head) at head-space point hs. Uses the rest
## transform of Head in Neck space; without a Neck in the rig it hangs from HeadModel.
static func _neck_pivot(rig: Dictionary, pivot_name: String, hs: Vector3) -> Node3D:
	var model: Node3D = rig["HeadModel"]
	var neck: Node3D = rig.get("Neck") as Node3D
	var head: Node3D = rig.get("Head") as Node3D
	if neck == null or head == null or head.get_parent() != neck:
		return _pivot(model, pivot_name, hs)
	var p: Node3D = SkaterParts.joint(neck, pivot_name, head.transform * (model.transform * hs))
	p.set_meta("hs", hs)
	return p


## Outward direction used to orient a lock's flat side: radial from the head centre above it, horizontal below.
static func _out_dir(p: Vector3) -> Vector3:
	var c: Vector3 = AnimeHead.CENTER
	if p.y >= c.y:
		return (p - c).normalized()
	var h: Vector3 = Vector3(p.x, 0.0, p.z - c.z)
	return h.normalized() if h.length() > 0.0001 else Vector3.BACK


## Hair envelope point at head angle a (0 = front, +X positive) and height y, `off` over the skin: on the dome above
## HANG_Y, below it straight down from the widest point of the head at that angle (hair falls, it does not follow
## the jaw in).
static func _env(a: float, y: float, off: float) -> Vector3:
	if y >= HANG_Y:
		return AnimeHead.cap_point(a, y, off)
	var cz: float = AnimeHead.CENTER.z
	var top: Vector3 = AnimeHead.cap_point(a, HANG_Y, off)
	var dir: Vector2 = Vector2(top.x, top.z - cz)
	var best: float = dir.length()
	for k: int in 6:
		var yy: float = lerpf(maxf(y, -0.02), HANG_Y, float(k) / 6.0)
		var q: Vector3 = AnimeHead.cap_point(a, yy, off)
		best = maxf(best, Vector2(q.x, q.z - cz).length())
	dir = dir.normalized()
	return Vector3(dir.x * best, y, cz + dir.y * best)


## Builds a lock from head-space points under `parent` (made relative to it). Normals point out (_out_dir).
static func _lock(parent: Node3D, part_name: String, mats: Dictionary, key: String, pts: PackedVector3Array,
		ws: PackedFloat32Array, ts: PackedFloat32Array, curl: float, sides: int = 8, sub: int = 3) -> MeshInstance3D:
	var off: Vector3 = _hs(parent)
	var local: PackedVector3Array = PackedVector3Array()
	var nrm: PackedVector3Array = PackedVector3Array()
	for q: Vector3 in pts:
		local.append(q - off)
		nrm.append(_out_dir(q))
	return SkaterParts.part(parent, part_name, AnimeHead.lock_mesh(local, ws, ts, nrm, curl, sides, sub), Vector3.ZERO, mats, key)


## A lock given in head space split over a chain of pivots at the heights `cuts` (descending): the part above
## cuts[0] hangs from pivots[0], the part between cuts[0] and cuts[1] from pivots[1], and so on. Pieces overlap by
## one sample so the seams stay closed while they sway.
static func _chain_lock(pivots: Array, cuts: Array, part_name: String, mats: Dictionary, key: String, pts: PackedVector3Array,
		ws: PackedFloat32Array, ts: PackedFloat32Array, curl: float, sides: int = 8, sub: int = 3) -> void:
	var p: PackedVector3Array = AnimeHead.smooth(pts, sub)
	var w: PackedFloat32Array = AnimeHead.smooth_r(ws, sub)
	var th: PackedFloat32Array = AnimeHead.smooth_r(ts, sub)
	var seg: PackedInt32Array = PackedInt32Array()
	for q: Vector3 in p:
		var s: int = 0
		while s < cuts.size() and q.y < float(cuts[s]):
			s += 1
		seg.append(s)
	for s: int in pivots.size():
		var i0: int = -1
		var i1: int = -1
		for i: int in p.size():
			if seg[i] == s:
				if i0 < 0:
					i0 = i
				i1 = i
		if i0 < 0:
			continue
		i0 = maxi(i0 - 1, 0)
		i1 = mini(i1 + 1, p.size() - 1)
		if i1 - i0 < 2:
			continue
		var piv: Node3D = pivots[s]
		var off: Vector3 = _hs(piv)
		var lp: PackedVector3Array = PackedVector3Array()
		var lw: PackedFloat32Array = PackedFloat32Array()
		var lt: PackedFloat32Array = PackedFloat32Array()
		var ln: PackedVector3Array = PackedVector3Array()
		for i: int in range(i0, i1 + 1):
			lp.append(p[i] - off)
			lw.append(w[i])
			lt.append(th[i])
			ln.append(_out_dir(p[i]))
		var nm: String = part_name + ("" if s == 0 else str(s + 1))
		SkaterParts.part(piv, nm + "Mesh", AnimeHead.lock_from(lp, lw, lt, ln, curl, sides), Vector3.ZERO, mats, key)


## Taper of a lock's half width along t (0 root .. 1 tip): narrow at the root, fullest a quarter down, pointed tip.
static func _taper(hw: float, t: float, tip_pow: float = 1.6) -> float:
	return hw * (0.7 + 0.3 * smoothstep(0.0, 0.28, t)) * (1.0 - pow(t, tip_pow)) + 0.0005


## A draped lock: root on the scalp at (a0, y0), falling over the head along the envelope to (a1, y1). `off` is its
## layer height over the skin, `flare` extra outward lift toward the tip (flicked-out ends), `tuck` pulls the tip
## in toward the neck (a bob's turned-in ends; negative flicks it out). Returns the head-space centre line.
static func _drape_pts(a0: float, y0: float, a1: float, y1: float, off: float, flare: float, tuck: float,
		n: int = 8, puff: float = 0.004) -> PackedVector3Array:
	var pts: PackedVector3Array = PackedVector3Array()
	for k: int in n:
		var t: float = float(k) / float(n - 1)
		var y: float = lerpf(y0, y1, t)
		var a: float = lerpf(a0, a1, smoothstep(0.0, 1.0, t))
		var o: float = off + puff * sin(PI * minf(t * 1.25, 1.0)) + flare * smoothstep(0.45, 1.0, t)
		var q: Vector3 = _env(a, y, o)
		var tk: float = tuck * smoothstep(0.7, 1.0, t)
		if tk != 0.0:
			var h: Vector3 = Vector3(q.x, 0.0, q.z - AnimeHead.CENTER.z).normalized()
			q -= h * tk
			q.y += absf(tk) * 0.6
		pts.append(q)
	return pts


static func _drape(parent: Node3D, part_name: String, mats: Dictionary, key: String, a0: float, y0: float, a1: float,
		y1: float, hw: float, off: float, flare: float = 0.0, tuck: float = 0.0, curl: float = 0.3, tip_pow: float = 1.6, puff: float = 0.004) -> MeshInstance3D:
	var pts: PackedVector3Array = _drape_pts(a0, y0, a1, y1, off, flare, tuck, 8, puff)
	var ws: PackedFloat32Array = PackedFloat32Array()
	var ts: PackedFloat32Array = PackedFloat32Array()
	for k: int in pts.size():
		var t: float = float(k) / float(pts.size() - 1)
		ws.append(_taper(hw, t, tip_pow))
		ts.append(0.0034 * (1.0 - 0.7 * t) + 0.0005)
	return _lock(parent, part_name, mats, key, pts, ws, ts, curl)


## Bangs over the face: each spec is [x_root, x_tip, y_tip, half width, key, lift]; roots at y_root on the hairline,
## tips slanting toward x_tip. Built under `parent` (HeadModel or a fringe pivot).
static func _bangs(parent: Node3D, mats: Dictionary, prefix: String, specs: Array, y_root: float = 0.18,
		curve: float = 2.0, tip_pow: float = 1.6) -> void:
	var off: Vector3 = _hs(parent)
	for i: int in specs.size():
		var b: Array = specs[i]
		var xr: float = float(b[0])
		var xt: float = float(b[1])
		var yt: float = float(b[2])
		var hw: float = float(b[3])
		var lift: float = float(b[5])
		var pts: PackedVector3Array = PackedVector3Array()
		var ws: PackedFloat32Array = PackedFloat32Array()
		var ts: PackedFloat32Array = PackedFloat32Array()
		var nrm: PackedVector3Array = PackedVector3Array()
		for k: int in 7:
			var t: float = float(k) / 6.0
			var y: float = lerpf(y_root, yt, t)
			var x: float = lerpf(xr, xt, pow(t, curve))
			var d: float = lerpf(0.007, 0.0135 + lift, smoothstep(0.0, 0.3, t)) - 0.0075 * pow(t, 2.5)
			var q: Vector3 = Vector3(x, y, AnimeHead.face_z(x, y)) + AnimeHead.face_normal(x, y) * d
			pts.append(q - off)
			nrm.append((q - AnimeHead.CENTER).normalized())
			ws.append(hw * (0.8 + 0.3 * sin(PI * minf(t * 1.5, 1.0) * 0.5)) * (1.0 - pow(t, tip_pow)) + 0.0004)
			ts.append(0.0032 * (1.0 - t * 0.75) + 0.0004)
		SkaterParts.part(parent, "%s%dMesh" % [prefix, i], AnimeHead.lock_mesh(pts, ws, ts, nrm, 0.25, 8, 3), Vector3.ZERO,
				mats, str(b[4]))


## A strand from the scalp at (a0, y0) gathered to `target` (a tie or bun), lying over the cap like the ponytail's.
static func _gather(parent: Node3D, part_name: String, mats: Dictionary, key: String, a0: float, y0: float, target: Vector3,
		hw: float, flat: float = 1.0) -> void:
	var tc: Vector3 = target - AnimeHead.CENTER
	var a1: float = atan2(tc.x, -tc.z)
	if absf(a1 - a0) > PI:
		a1 += TAU * signf(a0 - a1)
	var pts: PackedVector3Array = PackedVector3Array()
	var ws: PackedFloat32Array = PackedFloat32Array()
	var ts: PackedFloat32Array = PackedFloat32Array()
	for k: int in 7:
		var t: float = float(k) / 6.0
		var a: float = lerpf(a0, a1, pow(t, 1.3))
		var y: float = lerpf(y0, target.y - 0.006, t)
		var q: Vector3 = AnimeHead.cap_point(a, minf(y, AnimeHead.CROWN_Y - 0.002),
				AnimeHead.CAP_T + (0.0016 + 0.003 * sin(PI * t)) * flat - 0.004 * pow(1.0 - t, 4.0))
		q = q.lerp(target, smoothstep(0.7, 1.0, t))
		pts.append(q)
		ws.append(hw * (0.3 + 0.7 * smoothstep(0.0, 0.3, t)) * (1.0 - 0.5 * t))
		ts.append(0.0032 * flat * (0.4 + 0.6 * smoothstep(0.0, 0.3, t)))
	_lock(parent, part_name, mats, key, pts, ws, ts, 0.3, 8, 3)


## Angel-ring sheen: n short streaks around the crown at height y.
static func _sheen(head: Node3D, mats: Dictionary, angles: Array, y: float, lift: float = 0.0075, wscale: float = 1.0,
		key: String = "hair_shine", name_tag: String = "HairSheen") -> void:
	for i: int in angles.size():
		var a: float = deg_to_rad(float(angles[i]))
		var pts: PackedVector3Array = PackedVector3Array()
		for k: int in 4:
			var aa: float = a + deg_to_rad(-8.0 + 5.5 * float(k))
			pts.append(AnimeHead.cap_point(aa, y + 0.003 * sin(PI * float(k) / 3.0) - 0.01 * absf(sin(a)), AnimeHead.CAP_T + lift))
		var ws: PackedFloat32Array = PackedFloat32Array([0.0006, 0.0026 * wscale, 0.0026 * wscale, 0.0006])
		_lock(head, "%s%dMesh" % [name_tag, i], mats, key, pts, ws, PackedFloat32Array([0.0006, 0.0011, 0.0011, 0.0006]), 0.0, 6, 3)


## Short-hair gloss: broad spec bands across the crown (hair_shine) and cool rim streaks over the temples and the back
## of the head (hair_rim), so dark short cuts read as lit forms, not flat blobs.
static func _gloss(head: Node3D, mats: Dictionary, lift: float, y: float = 0.17) -> void:
	_sheen(head, mats, [-35.0, 35.0, 180.0], y, lift, 3.4, "hair_shine", "HairGloss")
	_sheen(head, mats, [-100.0, 100.0, -150.0, 150.0], y - 0.035, lift, 2.2, "hair_rim", "HairRim")


## Deterministic jitter in [-1, 1] for lock i (no random numbers in game code).
static func _jit(i: int, salt: float = 0.0) -> float:
	return sin(float(i) * 12.9898 + salt * 78.233) * 0.5 + sin(float(i) * 4.1414 + salt * 3.7) * 0.5


static func _scalp(head: Node3D, mats: Dictionary, key: String = "hair_mid") -> void:
	SkaterParts.part(head, "HairCapMesh", AnimeHead.cap_mesh(), Vector3.ZERO, mats, key)


# --- bob ----------------------------------------------------------------------------------------------------

## Chin-length anime bob: blunt bangs ending above the brows, a rounded outer layer of wide locks from the crown
## whose ends turn in under the jaw line (slightly longer toward the face, an A-line), a darker under layer showing
## between them, and two face-framing locks a side on HairSway_SideL/R.
static func bob(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	var head: Node3D = rig["HeadModel"]
	_scalp(head, mats)
	_bangs(head, mats, "BobBang", [
		[-0.03, -0.04, 0.104, 0.014, "hair_shadow", 0.0], [0.0, 0.002, 0.106, 0.015, "hair_shadow", 0.0],
		[0.03, 0.04, 0.104, 0.014, "hair_shadow", 0.0],
		[-0.052, -0.062, 0.1, 0.016, "hair_base", 0.004], [-0.034, -0.042, 0.098, 0.0155, "hair_mid", 0.005],
		[-0.016, -0.02, 0.1, 0.0155, "hair_base", 0.006], [0.002, 0.003, 0.098, 0.013, "hair_base", 0.006],
		[0.02, 0.024, 0.101, 0.0155, "hair_mid", 0.005], [0.037, 0.045, 0.099, 0.013, "hair_base", 0.005],
		[0.054, 0.064, 0.101, 0.016, "hair_mid", 0.004],
	], 0.178, 1.6, 2.6)
	# Under layer: darker, a little shorter, between the outer locks.
	var under: Array = [70.0, 100.0, 130.0, 157.0, 180.0]
	var n: int = 0
	for s: float in [-1.0, 1.0]:
		for ad: float in under:
			if s < 0.0 and ad == 180.0:
				continue
			var a: float = deg_to_rad(ad) * s
			var tip: float = lerpf(-0.02, 0.004, (ad - 70.0) / 110.0)
			_drape(head, "BobUnder%dMesh" % n, mats, "hair_shadow", a, 0.17, a, tip, 0.028, AnimeHead.CAP_T + 0.001,
					0.0, 0.018, 0.3, 3.0, 0.009)
			n += 1
	# Outer layer: wide locks from the crown, alternating shades, ends turned in.
	var outer: Array = [58.0, 80.0, 102.0, 124.0, 145.0, 165.0, 180.0]
	n = 0
	for s: float in [-1.0, 1.0]:
		for ad: float in outer:
			if s < 0.0 and ad == 180.0:
				continue
			var a: float = deg_to_rad(ad) * s
			var tip: float = lerpf(-0.03, -0.006, (ad - 58.0) / 122.0) + 0.004 * _jit(n)
			var key: String = "hair_base" if n % 2 == 0 else "hair_mid"
			_drape(head, "BobLock%dMesh" % n, mats, key, a * 0.92, 0.183, a + 0.05 * s, tip, 0.03,
					AnimeHead.CAP_T + 0.0045, 0.0, 0.022, 0.3, 2.6, 0.013)
			n += 1
	for s: float in [-1.0, 1.0]:
		var tag: String = "L" if s < 0.0 else "R"
		var pivot: Node3D = _pivot(head, "HairSway_Side" + tag, Vector3(s * 0.066, 0.135, -0.044))
		_drape(pivot, "BobSideFront" + tag + "Mesh", mats, "hair_base", deg_to_rad(52.0) * s, 0.165, deg_to_rad(46.0) * s,
				-0.036, 0.015, AnimeHead.CAP_T + 0.006, 0.0, 0.016, 0.35, 2.2, 0.01)
		_drape(pivot, "BobSideMid" + tag + "Mesh", mats, "hair_mid", deg_to_rad(66.0) * s, 0.16, deg_to_rad(62.0) * s,
				-0.03, 0.016, AnimeHead.CAP_T + 0.008, 0.0, 0.016, 0.35, 2.2, 0.012)
	_sheen(head, mats, [-105.0, -60.0, 60.0, 105.0, 150.0, -150.0], 0.158, 0.01)


# --- long ---------------------------------------------------------------------------------------------------

## Long, flowing hair past the shoulders: soft side-swept bangs ending above the brows, layered locks over the
## dome to the nape, three face-framing locks a side (HairSway_SideL/R), and a back curtain of broad tapered locks
## (a dark under layer and a lighter outer layer) falling to the middle of the back, hung from the neck on the
## sway chain HairSway_Back > HairSway_Back2 so it stays on the back when the head turns.
static func long_hair(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	var head: Node3D = rig["HeadModel"]
	_scalp(head, mats)
	_bangs(head, mats, "LongBang", [
		[-0.028, -0.036, 0.104, 0.014, "hair_shadow", 0.0], [0.006, 0.016, 0.106, 0.015, "hair_shadow", 0.0],
		[0.036, 0.05, 0.1, 0.014, "hair_shadow", 0.0],
		[-0.054, -0.07, 0.094, 0.013, "hair_base", 0.004], [-0.036, -0.05, 0.1, 0.013, "hair_mid", 0.005],
		[-0.018, -0.026, 0.104, 0.0125, "hair_base", 0.006], [-0.002, 0.004, 0.098, 0.0125, "hair_base", 0.006],
		[0.014, 0.028, 0.1, 0.0125, "hair_mid", 0.006], [0.03, 0.048, 0.096, 0.013, "hair_base", 0.005],
		[0.048, 0.068, 0.092, 0.0135, "hair_mid", 0.004],
	], 0.18, 1.8)
	# Dome: locks from the crown down over the back and sides to the nape (they cover the curtain's top).
	var dome: Array = [62.0, 84.0, 106.0, 128.0, 150.0, 170.0]
	var n: int = 0
	for s: float in [-1.0, 1.0]:
		for ad: float in dome:
			var a: float = deg_to_rad(ad) * s
			var tip: float = lerpf(-0.03, -0.04, (ad - 62.0) / 108.0) + 0.004 * _jit(n, 1.0)
			_drape(head, "LongDome%dMesh" % n, mats, "hair_base" if n % 2 == 0 else "hair_mid", a * 0.6, 0.187, a, tip, 0.024,
					AnimeHead.CAP_T + 0.004, 0.006, -0.002)
			n += 1
	_drape(head, "LongDomeBackMesh", mats, "hair_mid", PI, 0.185, PI, -0.044, 0.024, AnimeHead.CAP_T + 0.005, 0.006, -0.002)
	for s: float in [-1.0, 1.0]:
		var tag: String = "L" if s < 0.0 else "R"
		var pivot: Node3D = _pivot(head, "HairSway_Side" + tag, Vector3(s * 0.066, 0.135, -0.044))
		_drape(pivot, "LongSideFront" + tag + "Mesh", mats, "hair_base", deg_to_rad(50.0) * s, 0.166, deg_to_rad(44.0) * s,
				-0.066, 0.012, AnimeHead.CAP_T + 0.006, 0.004, 0.006, 0.35)
		_drape(pivot, "LongSideMid" + tag + "Mesh", mats, "hair_mid", deg_to_rad(64.0) * s, 0.162, deg_to_rad(60.0) * s,
				-0.058, 0.0125, AnimeHead.CAP_T + 0.008, 0.004, 0.004, 0.35)
		_drape(pivot, "LongSideBack" + tag + "Mesh", mats, "hair_shadow", deg_to_rad(80.0) * s, 0.155, deg_to_rad(78.0) * s,
				-0.05, 0.014, AnimeHead.CAP_T + 0.007, 0.004, 0.0, 0.3)
	_curtain(rig, head, mats, body_type)
	_sheen(head, mats, [-110.0, -65.0, 65.0, 110.0, 155.0, -155.0], 0.16, 0.009)


## Back skin depth (+Z) at head-space height y and side offset x, from the rig's chest sections (fallback: a flat
## back 8 cm behind the head joint).
static func _back_z(rig: Dictionary, y: float, x: float) -> float:
	if not (rig.has("sections") and rig.has("rest_y")):
		return 0.08
	var secs: Array = (rig["sections"] as Dictionary)["chest"]
	var ry: Dictionary = rig["rest_y"]
	var sec: Array = SkaterParts.section_at(secs, y + float(ry["Head"]) - float(ry["Chest"]))
	var a: float = SkaterParts.section_angle_for_x(sec, clampf(x, -float(sec[1]) * 0.98, float(sec[1]) * 0.98), false)
	return maxf(SkaterParts.section_point(sec, a).z, 0.045)


## The long back curtain: broad locks from under the head's back locks down the back, fanning out, standing off the
## back by 2-3 cm; under layer first (dark), then the outer layer. Hung from the neck: HairSway_Back > Back2.
static func _curtain(rig: Dictionary, head: Node3D, mats: Dictionary, _body_type: String) -> void:
	var top_y: float = 0.03
	var p1: Node3D = _neck_pivot(rig, "HairSway_Back", Vector3(0.0, top_y, 0.088))
	var cut: float = -0.16
	var p2: Node3D = _pivot(p1, "HairSway_Back2", Vector3(0.0, cut, _back_z(rig, cut, 0.0) + 0.026))
	# The curtain rests against the back: swinging forward would push it through the back (SecondaryMotion has no
	# collisions). Requested limit, degrees forward per link (SecondaryMotion does not read it yet).
	for p: Node3D in [p1, p2]:
		p.set_meta("sway_fwd_limit_deg", 2.0)
	# x at the top, x at the tip, tip y, half width, key, standoff boost
	var specs: Array = [
		[-0.04, -0.1, -0.3, 0.026, "hair_shadow", 0.0], [-0.014, -0.035, -0.33, 0.026, "hair_shadow", 0.0],
		[0.014, 0.035, -0.32, 0.026, "hair_shadow", 0.0], [0.04, 0.1, -0.3, 0.026, "hair_shadow", 0.0],
		[-0.056, -0.135, -0.27, 0.022, "hair_mid", 0.004], [-0.034, -0.083, -0.335, 0.024, "hair_base", 0.005],
		[-0.012, -0.03, -0.36, 0.024, "hair_mid", 0.006], [0.01, 0.022, -0.35, 0.024, "hair_base", 0.006],
		[0.032, 0.078, -0.34, 0.024, "hair_mid", 0.005], [0.056, 0.135, -0.28, 0.022, "hair_base", 0.004],
	]
	for i: int in specs.size():
		var sp: Array = specs[i]
		var x0: float = float(sp[0])
		var x1: float = float(sp[1])
		var y1: float = float(sp[2])
		var hw: float = float(sp[3])
		var boost: float = float(sp[5])
		var pts: PackedVector3Array = PackedVector3Array()
		var ws: PackedFloat32Array = PackedFloat32Array()
		var ts: PackedFloat32Array = PackedFloat32Array()
		var n: int = 9
		for k: int in n:
			var t: float = float(k) / float(n - 1)
			var y: float = lerpf(top_y, y1, t)
			var x: float = lerpf(x0, x1, smoothstep(0.0, 1.0, t)) + 0.006 * sin(t * 5.0 + float(i)) * t
			var stand: float = 0.026 + boost + 0.012 * t
			var z: float = maxf(_back_z(rig, y, x) + stand, 0.088 - 0.25 * x * x)
			pts.append(Vector3(x, y, z))
			ws.append(hw * (0.55 + 0.45 * smoothstep(0.0, 0.2, t)) * (1.0 - pow(t, 2.2)) + 0.0006)
			ts.append(0.0042 * (1.0 - 0.6 * t) + 0.0006)
		_chain_lock([p1, p2], [cut], "LongCurtain%d" % i, mats, str(sp[4]), pts, ws, ts, 0.28, 8, 3)


# --- pigtails -----------------------------------------------------------------------------------------------

## Twin tails: hair parted down the back and gathered from each half to a bobble tie high behind each ear, each
## tail flaring out and falling past the shoulders well clear of them (chain HairSway_PigtailL > PigtailL2, R the
## same), soft bangs above the brows and a short face-framing lock a side (HairSway_SideL/R).
static func pigtails(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	Wardrobe.mat(mats, "hair_tie", Color(1.0, 0.42, 0.36))
	var head: Node3D = rig["HeadModel"]
	_scalp(head, mats)
	_bangs(head, mats, "PigBang", [
		[-0.026, -0.03, 0.104, 0.014, "hair_shadow", 0.0], [0.0, 0.004, 0.107, 0.014, "hair_shadow", 0.0],
		[0.028, 0.034, 0.104, 0.014, "hair_shadow", 0.0],
		[-0.05, -0.066, 0.096, 0.0135, "hair_base", 0.004], [-0.032, -0.044, 0.101, 0.013, "hair_mid", 0.005],
		[-0.014, -0.022, 0.098, 0.013, "hair_base", 0.006], [0.004, 0.006, 0.102, 0.0125, "hair_base", 0.006],
		[0.02, 0.03, 0.099, 0.013, "hair_mid", 0.005], [0.036, 0.05, 0.101, 0.013, "hair_base", 0.005],
		[0.052, 0.068, 0.095, 0.0135, "hair_mid", 0.004],
	], 0.179, 1.8)
	for s: float in [-1.0, 1.0]:
		var tag: String = "L" if s < 0.0 else "R"
		var ta: float = s * deg_to_rad(112.0)
		var tie: Vector3 = AnimeHead.cap_point(ta, 0.128, AnimeHead.CAP_T + 0.006)
		# Strands from this half of the head (front hairline round to the back parting) to the tie.
		var starts: Array = [[40.0, 0.172], [62.0, 0.15], [80.0, 0.125], [96.0, 0.07], [128.0, 0.04], [150.0, 0.02],
				[172.0, 0.012], [176.0, 0.1], [150.0, 0.16], [100.0, 0.18], [60.0, 0.183]]
		for i: int in starts.size():
			var st: Array = starts[i]
			_gather(head, "PigStrand%s%d" % [tag, i], mats, "hair_base" if i % 2 == 0 else "hair_mid", s * deg_to_rad(float(st[0])),
					float(st[1]), tie, 0.016)
		var out: Vector3 = Vector3(s, 0.0, 0.35).normalized()
		var p1: Node3D = _pivot(head, "HairSway_Pigtail" + tag, tie)
		var bob: MeshInstance3D = SkaterParts.part(p1, "PigTie" + tag + "Mesh", SkaterParts.torus(0.012, 0.0185), out * 0.006,
				mats, "hair_tie")
		bob.basis = Basis(Vector3.FORWARD.cross(out).normalized() if absf(out.z) < 0.99 else Vector3.UP, PI * 0.5) * Basis.IDENTITY
		bob.basis = Basis.looking_at(out, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
		for k: int in 2:
			SkaterParts.part(p1, "PigBobble%s%dMesh" % [tag, k], SkaterParts.sphere_small(0.0075),
					out * 0.008 + Vector3(0.0, 0.016 if k == 0 else -0.016, 0.0), mats, "hair_tie")
		# Tail: rises out of the tie, arcs out past the shoulder and falls; four locks round a centre line.
		var base: Array = [
			Vector3.ZERO, out * 0.03 + Vector3(0.0, 0.012, 0.0), out * 0.07 + Vector3(0.0, 0.0, 0.0),
			out * 0.105 + Vector3(0.0, -0.05, 0.0), out * 0.132 + Vector3(0.0, -0.12, 0.0), out * 0.15 + Vector3(0.0, -0.19, 0.0),
			out * 0.152 + Vector3(0.0, -0.25, 0.012), out * 0.142 + Vector3(0.0, -0.285, 0.02),
		]
		var cut: float = tie.y - 0.06
		var p2: Node3D = _pivot(p1, "HairSway_Pigtail" + tag + "2", tie + (base[3] as Vector3))
		var wb: PackedFloat32Array = PackedFloat32Array([0.013, 0.02, 0.026, 0.028, 0.026, 0.021, 0.013, 0.0006])
		var specs: Array = [["Main", 0.0, 0.0, 1.0, "hair_base", 0.0], ["Front", -0.012, 0.008, 0.62, "hair_mid", 1.6],
				["Back", 0.012, -0.004, 0.62, "hair_mid", 3.1], ["Under", 0.0, -0.01, 0.55, "hair_shadow", 4.4]]
		for sp: Array in specs:
			var pts: PackedVector3Array = PackedVector3Array()
			var ws: PackedFloat32Array = PackedFloat32Array()
			var ts: PackedFloat32Array = PackedFloat32Array()
			for k: int in base.size():
				var t: float = float(k) / float(base.size() - 1)
				var spread: float = smoothstep(0.0, 0.35, t)
				var q: Vector3 = tie + (base[k] as Vector3) + Vector3(0.0, 0.0, float(sp[1]) * spread) \
						+ out * (float(sp[2]) * spread + 0.004 * sin(t * 6.0 + float(sp[5])) * t)
				pts.append(q)
				ws.append(wb[k] * float(sp[3]))
				ts.append(wb[k] * float(sp[3]) * 0.6 + 0.0004)
			_chain_lock([p1, p2], [cut], "PigTail%s%s" % [tag, sp[0]], mats, str(sp[4]), pts, ws, ts, 0.1, 8, 3)
		var side: Node3D = _pivot(head, "HairSway_Side" + tag, Vector3(s * 0.066, 0.135, -0.044))
		_drape(side, "PigSide" + tag + "Mesh", mats, "hair_base", deg_to_rad(54.0) * s, 0.164, deg_to_rad(50.0) * s, -0.02, 0.011,
				AnimeHead.CAP_T + 0.005, 0.0, 0.008, 0.35, 1.6, 0.006)
		_drape(side, "PigSideBack" + tag + "Mesh", mats, "hair_shadow", deg_to_rad(70.0) * s, 0.155, deg_to_rad(68.0) * s, 0.02,
				0.011, AnimeHead.CAP_T + 0.004, 0.0, 0.004, 0.3, 1.6, 0.004)
	_sheen(head, mats, [-60.0, -25.0, 25.0, 60.0], 0.16, 0.008)


# --- bun ----------------------------------------------------------------------------------------------------

## Messy top bun: strands swept up from every side to a scrunchie at the top of the crown, a bun of looping locks
## with a few loose ends sticking out, wispy bangs above the brows and loose face-framing tendrils
## (HairSway_SideL/R) plus short wisps at the nape.
static func bun(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	Wardrobe.mat(mats, "hair_tie", Color(1.0, 0.42, 0.36))
	var head: Node3D = rig["HeadModel"]
	_scalp(head, mats)
	_bangs(head, mats, "BunBang", [
		[-0.03, -0.044, 0.1, 0.0125, "hair_shadow", 0.0], [0.008, 0.02, 0.104, 0.013, "hair_shadow", 0.0],
		[-0.05, -0.068, 0.098, 0.012, "hair_base", 0.004], [-0.022, -0.036, 0.104, 0.012, "hair_mid", 0.006],
		[-0.004, -0.008, 0.108, 0.0115, "hair_base", 0.006], [0.016, 0.03, 0.102, 0.012, "hair_base", 0.006],
		[0.036, 0.054, 0.1, 0.012, "hair_mid", 0.005], [0.054, 0.07, 0.096, 0.012, "hair_base", 0.004],
	], 0.176, 1.8)
	var top: Vector3 = AnimeHead.cap_point(PI, AnimeHead.CROWN_Y - 0.004, AnimeHead.CAP_T) + Vector3(0.0, 0.006, 0.012)
	# Swept-up strands from all round the hairline.
	var starts: Array = [-150.0, -120.0, -95.0, -72.0, -50.0, 180.0, 150.0, 120.0, 95.0, 72.0, 50.0, -165.0, 165.0, -135.0, 135.0]
	for i: int in starts.size():
		var ad: float = float(starts[i])
		var a: float = deg_to_rad(ad)
		var y0: float = AnimeHead.hairline_y(a) + 0.002 if absf(ad) < 160.0 else 0.0
		if absf(ad) > 140.0:
			y0 = lerpf(0.0, 0.03, (180.0 - absf(ad)) / 40.0)
		_gather(head, "BunStrand%d" % i, mats, "hair_base" if i % 2 == 0 else "hair_mid", a, y0, top, 0.017)
	# The bun: a scrunchie, then looping locks wound round a centre and a few loose ends.
	var bun_c: Vector3 = top + Vector3(0.0, 0.036, 0.008)
	var tie: MeshInstance3D = SkaterParts.part(head, "BunTieMesh", SkaterParts.torus(0.013, 0.022), top + Vector3(0.0, 0.006, 0.0), mats,
			"hair_tie")
	tie.scale = Vector3(1.0, 1.6, 1.0)
	for i: int in 7:
		var ang: float = TAU * float(i) / 7.0 + 0.4 * _jit(i)
		var tilt: float = 0.5 + 0.35 * _jit(i, 2.0)
		var axis: Vector3 = Vector3(cos(ang), tilt, sin(ang)).normalized()
		var u: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
		var v: Vector3 = axis.cross(u).normalized()
		var pts: PackedVector3Array = PackedVector3Array()
		var ws: PackedFloat32Array = PackedFloat32Array()
		var ts: PackedFloat32Array = PackedFloat32Array()
		var r: float = 0.03 + 0.004 * _jit(i, 5.0)
		for k: int in 8:
			var t: float = float(k) / 7.0
			var ph: float = PI * 1.55 * t + ang
			pts.append(bun_c + (u * cos(ph) + v * sin(ph)) * r * (1.0 - 0.15 * t) + axis * 0.004 * sin(PI * t))
			ws.append(0.014 * sin(PI * clampf(t * 1.1, 0.05, 1.0)) + 0.001)
			ts.append(0.006 * sin(PI * clampf(t, 0.05, 0.95)) + 0.001)
		_lock(head, "BunLoop%dMesh" % i, mats, "hair_base" if i % 3 != 1 else "hair_mid", pts, ws, ts, 0.25, 8, 3)
	SkaterParts.part(head, "BunCoreMesh", SkaterParts.sphere_small(0.028), bun_c, mats, "hair_mid").scale = Vector3(1.0, 0.85, 1.0)
	for i: int in 4:
		var ang: float = TAU * float(i) / 4.0 + 0.8
		var d: Vector3 = Vector3(cos(ang), 0.7 + 0.2 * _jit(i, 3.0), sin(ang)).normalized()
		var pts: PackedVector3Array = PackedVector3Array([bun_c + d * 0.022, bun_c + d * 0.038, bun_c + d * 0.052 + Vector3(0.0, 0.004, 0.0)])
		_lock(head, "BunEnd%dMesh" % i, mats, "hair_base", pts, PackedFloat32Array([0.006, 0.0045, 0.0004]),
				PackedFloat32Array([0.002, 0.0015, 0.0004]), 0.2, 6, 3)
	for s: float in [-1.0, 1.0]:
		var tag: String = "L" if s < 0.0 else "R"
		var side: Node3D = _pivot(head, "HairSway_Side" + tag, Vector3(s * 0.066, 0.13, -0.04))
		_drape(side, "BunTendril" + tag + "Mesh", mats, "hair_base", deg_to_rad(58.0) * s, 0.15, deg_to_rad(54.0) * s, 0.0,
				0.0075, AnimeHead.CAP_T + 0.005, 0.0, -0.004, 0.4, 1.4, 0.004)
		_drape(side, "BunTendrilBack" + tag + "Mesh", mats, "hair_mid", deg_to_rad(74.0) * s, 0.13, deg_to_rad(76.0) * s, 0.025,
				0.0065, AnimeHead.CAP_T + 0.004, 0.0, -0.004, 0.4, 1.4, 0.003)
		_drape(head, "BunNape" + tag + "Mesh", mats, "hair_mid", deg_to_rad(160.0) * s, 0.05, deg_to_rad(150.0) * s, -0.02,
				0.007, AnimeHead.CAP_T + 0.002, 0.004, 0.0, 0.3, 1.4, 0.002)
	_sheen(head, mats, [-70.0, -30.0, 30.0, 70.0], 0.168, 0.008)


# --- short spiky --------------------------------------------------------------------------------------------

## Spiky short hair (shonen lead): tufts swept up and back from the front hairline and out from a whorl into tall
## pointed spikes, shorter spikes over the sides and back flicking out, and a fringe of pointed spikes ending above
## the brows (HairSway_Fringe).
static func short_spiky(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	var head: Node3D = rig["HeadModel"]
	_scalp(head, mats)
	var whorl: Vector2 = Vector2(180.0, 50.0)
	# Back and side spikes: from the crown down, tips lifting out.
	for i: int in range(-4, 5):
		var fi: float = float(i)
		_tuft(head, mats, "SpikyBack%dMesh" % (i + 4), Vector2(180.0 + fi * 20.0, 55.0), Vector2(180.0 + fi * 24.0, -14.0 + 5.0 * absf(fi)),
				0.022, 0.026, "hair_base" if i % 2 == 0 else "hair_mid", 0.3)
	for sd: Array in Wardrobe.sides():
		var s: float = sd[1]
		var tag: String = "L" if s < 0.0 else "R"
		_tuft(head, mats, "SpikySide" + tag + "Mesh", Vector2(s * 100.0, 50.0), Vector2(s * 104.0, 6.0), 0.02, 0.016, "hair_mid", 0.3)
		_tuft(head, mats, "SpikyTemple" + tag + "Mesh", Vector2(s * 76.0, 48.0), Vector2(s * 82.0, 0.0), 0.016, 0.01, "hair_shadow", 0.3)
	# Top: tall spikes swept up and back, the longest at the crown.
	var tops: Array = [
		[0.0, 64.0, 0.05, "hair_base"], [30.0, 60.0, 0.046, "hair_mid"], [-30.0, 60.0, 0.046, "hair_base"],
		[62.0, 52.0, 0.04, "hair_base"], [-62.0, 52.0, 0.04, "hair_mid"], [100.0, 46.0, 0.036, "hair_mid"],
		[-100.0, 46.0, 0.036, "hair_base"], [140.0, 44.0, 0.042, "hair_base"], [-140.0, 44.0, 0.042, "hair_mid"],
		[180.0, 40.0, 0.044, "hair_mid"], [12.0, 74.0, 0.054, "hair_mid"], [-46.0, 72.0, 0.05, "hair_base"],
	]
	for i: int in tops.size():
		var tp: Array = tops[i]
		var tip: Vector2 = Vector2(float(tp[0]), float(tp[1]))
		_tuft(head, mats, "SpikyTop%dMesh" % i, _toward(whorl, tip, 0.12), tip, 0.03, float(tp[2]), str(tp[3]), 0.25, 0.008)
	_gloss(head, mats, 0.018)
	var fringe: Node3D = _pivot(head, "HairSway_Fringe", Vector3(0.0, 0.172, -0.07))
	_bangs(fringe, mats, "SpikyBang", [
		[-0.056, -0.074, 0.112, 0.014, "hair_shadow", 0.0], [0.058, 0.076, 0.114, 0.014, "hair_shadow", 0.0],
		[-0.046, -0.066, 0.1, 0.015, "hair_base", 0.007], [-0.024, -0.04, 0.094, 0.015, "hair_mid", 0.008],
		[-0.004, -0.008, 0.102, 0.015, "hair_base", 0.009], [0.016, 0.03, 0.093, 0.015, "hair_base", 0.008],
		[0.036, 0.056, 0.099, 0.015, "hair_mid", 0.007], [0.054, 0.074, 0.11, 0.014, "hair_base", 0.006],
	], 0.184, 1.4, 1.3)


# --- undercut -----------------------------------------------------------------------------------------------

## Undercut: sides and back clipped short (a darker close cap with fine flat tufts), and a long top swept back and
## over to one side in broad locks, its front falling as a long swoop to above the right brow (HairSway_Fringe).
static func undercut(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	var head: Node3D = rig["HeadModel"]
	_scalp(head, mats, "hair_shadow")
	# Clipped sides and back: short flat tufts in the dark shades.
	var n: int = 0
	for az: float in [-150.0, -120.0, -95.0, -70.0, 180.0, 150.0, 120.0, 95.0, 70.0]:
		for row: int in 2:
			var e0: float = 34.0 if row == 0 else 12.0
			_tuft(head, mats, "UndercutClip%dMesh" % n, Vector2(az, e0), Vector2(az + 4.0 * signf(az), e0 - 22.0), 0.02, 0.0,
					"hair_shadow" if (n % 2 == 0) else "hair_deep", 0.2, -0.006)
			n += 1
	# Top: broad locks from the front hairline swept back over the crown, slightly to the left.
	var tops: Array = [
		[-44.0, 30.0, -60.0, 46.0], [-24.0, 34.0, -40.0, 62.0], [0.0, 36.0, -16.0, 66.0], [22.0, 34.0, 10.0, 66.0],
		[42.0, 30.0, 34.0, 58.0], [60.0, 28.0, 60.0, 50.0],
	]
	for i: int in tops.size():
		var tp: Array = tops[i]
		var root: Vector2 = Vector2(float(tp[0]), float(tp[1]) + 12.0)
		var tip: Vector2 = Vector2(180.0 + float(tp[2]) * 0.6, float(tp[3]) - 12.0)
		_tuft(head, mats, "UndercutTop%dMesh" % i, root, tip, 0.03, 0.012, "hair_base" if i % 2 == 0 else "hair_mid", 0.25, 0.014)
	for i: int in 4:
		var az: float = -60.0 + 40.0 * float(i)
		_tuft(head, mats, "UndercutCrown%dMesh" % i, Vector2(az * 0.5, 80.0), Vector2(180.0 + az * 0.8, 38.0), 0.028, 0.014,
				"hair_mid" if i % 2 == 0 else "hair_base", 0.25, 0.016)
	# Front: a long swoop from the left of the parting over to the right brow.
	var fringe: Node3D = _pivot(head, "HairSway_Fringe", Vector3(0.0, 0.176, -0.068))
	_bangs(fringe, mats, "UndercutBang", [
		[-0.04, 0.0, 0.124, 0.018, "hair_shadow", 0.004], [-0.03, 0.03, 0.106, 0.02, "hair_base", 0.012],
		[-0.012, 0.05, 0.094, 0.019, "hair_mid", 0.015], [0.006, 0.066, 0.092, 0.017, "hair_base", 0.015],
		[0.024, 0.074, 0.104, 0.014, "hair_mid", 0.012], [-0.05, -0.034, 0.128, 0.014, "hair_mid", 0.006],
	], 0.192, 0.8, 1.3)
	_sheen(head, mats, [-40.0, 0.0, 40.0], 0.178, 0.02)
	_gloss(head, mats, 0.014, 0.16)


# --- buzz ---------------------------------------------------------------------------------------------------

## Buzz cut: a close cap with a crisp hairline, its texture short flat tufts in two shades laid from the crown, and
## a crisp hairline. Too short to sway.
static func buzz(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	var head: Node3D = rig["HeadModel"]
	_scalp(head, mats)
	var n: int = 0
	for ring: Array in [[74.0, 6, 0.0], [54.0, 9, 20.0], [32.0, 10, 0.0], [8.0, 9, 18.0]]:
		var e: float = float(ring[0])
		var count: int = int(ring[1])
		for k: int in count:
			var az: float = -180.0 + 360.0 * float(k) / float(count) + float(ring[2])
			var front: bool = absf(wrapf(az, -180.0, 180.0)) < 70.0
			if e < 40.0 and front:
				continue
			var tip: Vector2 = Vector2(az + 6.0, e - 24.0)
			if front:
				tip = Vector2(az * 1.05, maxf(e - 24.0, 42.0))
			_tuft(head, mats, "BuzzTuft%dMesh" % n, Vector2(az, e), tip, 0.022, 0.0, "hair_mid" if n % 3 != 0 else "hair_shadow",
					0.15, -0.007)
			n += 1
	_gloss(head, mats, 0.0095, 0.166)


# --- shaggy -------------------------------------------------------------------------------------------------

## Surfer shag: choppy layers from a whorl, an outer layer of locks to the jaw whose ends flick out, a curtain
## fringe parted off-centre and swept aside (ending above the brows, HairSway_Fringe), locks over the ears
## (HairSway_SideL/R) and a flicked nape layer (HairSway_Nape). The same cut on both bodies.
static func shaggy(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	var head: Node3D = rig["HeadModel"]
	_scalp(head, mats)
	var male: bool = body_type == "male"
	var whorl: Vector2 = Vector2(170.0, 55.0)
	var tops: Array = [
		[10.0, 56.0, "hair_mid"], [-30.0, 52.0, "hair_base"], [45.0, 48.0, "hair_base"], [-70.0, 44.0, "hair_mid"],
		[80.0, 44.0, "hair_mid"], [120.0, 40.0, "hair_base"], [-120.0, 40.0, "hair_base"], [155.0, 36.0, "hair_mid"],
		[-155.0, 36.0, "hair_mid"],
	]
	for i: int in tops.size():
		var tp: Array = tops[i]
		var tip: Vector2 = Vector2(float(tp[0]), float(tp[1]))
		_tuft(head, mats, "ShagTop%dMesh" % i, _toward(whorl, tip, 0.12), tip, 0.03, 0.009, str(tp[2]), 0.25, 0.01)
	# Outer layer: locks from the crown over the back and sides, ends flicking out at the jaw line.
	var n: int = 0
	for s: float in [-1.0, 1.0]:
		for ad: float in [104.0, 128.0, 152.0, 172.0]:
			var a: float = deg_to_rad(ad) * s
			var tip: float = (0.0 if male else -0.012) + 0.008 * _jit(n, 4.0) + 0.012 * (ad - 104.0) / 68.0
			_drape(head, "ShagLayer%dMesh" % n, mats, "hair_base" if n % 2 == 0 else "hair_mid", a * 0.9, 0.17, a + 0.08 * s, tip,
					0.022, AnimeHead.CAP_T + 0.006, 0.012, -0.008, 0.3, 1.5, 0.01)
			n += 1
	var nape: Node3D = _pivot(head, "HairSway_Nape", Vector3(0.0, 0.06, 0.1))
	for i: int in 5:
		var a: float = deg_to_rad(180.0 + (-40.0 + 20.0 * float(i)))
		_drape(nape, "ShagNape%dMesh" % i, mats, "hair_shadow" if i % 2 == 0 else "hair_mid", a, 0.08, a * 1.0 + 0.1 * _jit(i),
				-0.03 + 0.008 * _jit(i, 2.0), 0.016, AnimeHead.CAP_T + 0.008, 0.014, -0.006, 0.3, 1.4, 0.006)
	for s: float in [-1.0, 1.0]:
		var tag: String = "L" if s < 0.0 else "R"
		var side: Node3D = _pivot(head, "HairSway_Side" + tag, Vector3(s * 0.07, 0.13, -0.03))
		_drape(side, "ShagSideFront" + tag + "Mesh", mats, "hair_mid", deg_to_rad(62.0) * s, 0.16, deg_to_rad(64.0) * s,
				-0.012 if not male else 0.0, 0.016, AnimeHead.CAP_T + 0.007, 0.006, -0.004, 0.35, 1.5, 0.008)
		_drape(side, "ShagSideEar" + tag + "Mesh", mats, "hair_base", deg_to_rad(82.0) * s, 0.165, deg_to_rad(86.0) * s,
				-0.02 if not male else -0.008, 0.019, AnimeHead.CAP_T + 0.009, 0.01, -0.006, 0.35, 1.5, 0.01)
	var fringe: Node3D = _pivot(head, "HairSway_Fringe", Vector3(0.0, 0.176, -0.068))
	var bt: float = 0.0 if not male else -0.004
	_bangs(fringe, mats, "ShagBang", [
		[-0.008, -0.04, 0.11 + bt, 0.015, "hair_shadow", 0.0], [0.016, 0.05, 0.108 + bt, 0.015, "hair_shadow", 0.0],
		[-0.014, -0.058, 0.098 + bt, 0.015, "hair_base", 0.006], [-0.03, -0.072, 0.096 + bt, 0.014, "hair_mid", 0.005],
		[0.0, -0.026, 0.11 + bt, 0.013, "hair_mid", 0.007], [0.02, 0.04, 0.104 + bt, 0.014, "hair_base", 0.007],
		[0.03, 0.064, 0.097 + bt, 0.015, "hair_mid", 0.006], [0.044, 0.076, 0.098 + bt, 0.014, "hair_base", 0.005],
	], 0.184, 1.3, 1.5)
	_sheen(head, mats, [-50.0, -15.0, 25.0, 60.0], 0.165, 0.016)
