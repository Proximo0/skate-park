class_name HairStyles
extends RefCounted
## Hair styles (Wardrobe slot "hair"), built on the head by AnimeHead.build(). Contract and registration: see
## Wardrobe (game/skater/wardrobe.gd); rig["HeadModel"] is the node to build under (face toward -Z, the head
## surface helpers are AnimeHead.cap_point / face_z / face_normal / lock_mesh / pivot_lock / cap_mesh).
## HAIR SWAY CONVENTION: hair that should sway hangs from identity-rotation Node3D pivots named "HairSway_<Name>"
## under HeadModel, placed at the root of the locks they carry; a chain numbers on: "HairSway_<Name>" >
## "HairSway_<Name>2" > "HairSway_<Name>3". Side locks use "HairSway_SideL" / "HairSway_SideR" (L = -X).
## Palette keys: "hair_base", "hair_mid", "hair_shadow", "hair_deep", "hair_shine" (AnimeHead.COLORS defaults),
## "hair_tie", "flower", "flower_center".
## Built: hair_ponytail (pivots HairSway_SideL/R and the chain HairSway_Ponytail > 2 > 3), hair_messy (pivots
## HairSway_SideL/R and HairSway_Fringe).

const STUBS: PackedStringArray = ["hair_bob", "hair_long", "hair_pigtails", "hair_bun", "hair_short_spiky", "hair_undercut",
	"hair_buzz", "hair_shaggy"]


static func builders() -> Dictionary:
	var out: Dictionary = {"hair_ponytail": HairStyles.ponytail, "hair_messy": HairStyles.messy}
	for id: String in STUBS:
		out[id] = HairStyles._stub.bind(id)
	return out


static func _stub(rig: Dictionary, body_type: String, mats: Dictionary, id: String) -> void:
	var fallback: Callable = HairStyles.messy if body_type == AnimeOutfit.MALE else HairStyles.ponytail
	Wardrobe.stub(rig, body_type, mats, "hair", id, fallback)


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
		Vector3(s * 0.074, 0.035, -0.066), Vector3(s * 0.079, -0.004, -0.055), Vector3(s * 0.078, -0.04, -0.054),
		Vector3(s * 0.066, -0.068, -0.064), Vector3(s * 0.052, -0.081, -0.077), Vector3(s * 0.043, -0.081, -0.087),
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
		Vector3(0.0, -0.09, 0.126), Vector3(0.0, -0.17, 0.12), Vector3(0.0, -0.25, 0.108), Vector3(0.0, -0.32, 0.104),
		Vector3(0.0, -0.37, 0.114),
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
