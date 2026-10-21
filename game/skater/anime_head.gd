class_name AnimeHead
extends RefCounted
## Head parts of the anime surf-skater girl: a smooth face (lathe with a gentle chin), big layered-iris eyes, brows,
## sun-bleached blonde hair (scalp shell, crown, swept bangs, side locks, long high ponytail with a tie) and a
## flower clip. Everything is built in "head model" space (a sphere-ish head about 0.34 tall, face toward -Z) under
## a scaled HeadModel node, so the head reads at adult proportions (about 1:6.5 of the body height).
## Static builders, called by PlaceholderSkater with the Head joint and the palette materials.

const HEAD_SCALE: float = 0.6
const FACE_DEPTH: float = 0.97

static var _profile: PackedVector2Array = PackedVector2Array()


## Face lathe profile: (radius, y), chin at the bottom, crown at the top.
static func face_profile() -> PackedVector2Array:
	if _profile.is_empty():
		_profile = SkaterParts.smooth2d(PackedVector2Array([
			Vector2(0.0, -0.053), Vector2(0.03, -0.049), Vector2(0.058, -0.031), Vector2(0.09, 0.004),
			Vector2(0.121, 0.045), Vector2(0.147, 0.09), Vector2(0.161, 0.135), Vector2(0.164, 0.18),
			Vector2(0.152, 0.235), Vector2(0.115, 0.28), Vector2(0.06, 0.308), Vector2(0.0, 0.316),
		]), 3)
	return _profile


## Z of the face surface at (x, y) in head model space (negative, toward the nose).
static func face_z(x: float, y: float) -> float:
	var r: float = maxf(SkaterParts.profile_r(face_profile(), y), 0.01)
	var k: float = clampf(x / r, -0.995, 0.995)
	return -FACE_DEPTH * r * sqrt(1.0 - k * k)


static func build(head: Node3D, mats: Dictionary) -> void:
	var m: Node3D = SkaterParts.joint(head, "HeadModel", Vector3.ZERO)
	m.scale = Vector3.ONE * HEAD_SCALE
	SkaterParts.part(m, "HeadMesh", SkaterParts.lathe(face_profile(), FACE_DEPTH, 0.0, TAU, 32), Vector3.ZERO, mats, "skin")
	SkaterParts.part(m, "NoseMesh", SkaterParts.sphere(0.0105), Vector3(0.0, 0.085, face_z(0.0, 0.085) - 0.002), mats, "nose")
	_build_face(m, mats)
	_build_hair(m, mats)
	_build_ponytail(m, mats)
	_build_flower(m, mats)


static func _build_face(head: Node3D, mats: Dictionary) -> void:
	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var x: float = s * 0.068
		var y: float = 0.12
		var z0: float = face_z(x, y) + 0.004
		# Eye: white, a dark ocean-blue ring, a blue iris with a lighter lower half, a pupil and two sparkles.
		var eye: MeshInstance3D = SkaterParts.part(head, "Eye" + side + "Mesh", SkaterParts.sphere(0.047),
				Vector3(x, y, z0), mats, "eye_white")
		eye.scale = Vector3(0.95, 1.12, 0.3)
		var ring: MeshInstance3D = SkaterParts.part(head, "IrisRing" + side + "Mesh", SkaterParts.sphere(0.04),
				Vector3(x, y - 0.004, z0 - 0.006), mats, "iris_ring")
		ring.scale = Vector3(0.96, 1.2, 0.3)
		var iris: MeshInstance3D = SkaterParts.part(head, "Iris" + side + "Mesh", SkaterParts.sphere(0.0345),
				Vector3(x, y - 0.004, z0 - 0.0085), mats, "iris")
		iris.scale = Vector3(0.96, 1.2, 0.3)
		var glow: MeshInstance3D = SkaterParts.part(head, "IrisGlow" + side + "Mesh", SkaterParts.sphere(0.0245),
				Vector3(x, y - 0.017, z0 - 0.0105), mats, "iris_light")
		glow.scale = Vector3(1.05, 0.55, 0.3)
		var pupil: MeshInstance3D = SkaterParts.part(head, "Pupil" + side + "Mesh", SkaterParts.sphere(0.018),
				Vector3(x, y + 0.002, z0 - 0.0135), mats, "eyes")
		pupil.scale = Vector3(0.9, 1.2, 0.3)
		SkaterParts.part(head, "EyeShine" + side + "Mesh", SkaterParts.sphere(0.0105),
				Vector3(x - s * 0.011, y + 0.018, z0 - 0.019), mats, "eye_white")
		SkaterParts.part(head, "EyeShineSmall" + side + "Mesh", SkaterParts.sphere(0.006),
				Vector3(x + s * 0.012, y - 0.017, z0 - 0.019), mats, "eye_white")
		# Upper lash: a thick arc hugging the top of the eye, thickest at the outer corner, ending in a flick.
		var lash_pts: PackedVector3Array = PackedVector3Array()
		var lash_r: PackedFloat32Array = PackedFloat32Array()
		for i: int in 7:
			var t: float = -1.0 + 2.0 * float(i) / 6.0
			var lx: float = x + s * t * 0.047
			var ly: float = y + 0.05 - 0.019 * t * t + s * t * 0.004
			lash_pts.append(Vector3(lx, ly, face_z(lx, ly) - 0.003))
			lash_r.append(0.0026 + 0.002 * (0.5 + 0.5 * t * s))
		var fx: float = x + s * 0.066
		var fy: float = y + 0.064
		lash_pts.append(Vector3(fx, fy, face_z(fx, fy) - 0.002))
		lash_r.append(0.0016)
		SkaterParts.part(head, "Lash" + side + "Mesh", SkaterParts.tube(_smooth(lash_pts, 3), _smooth_r(lash_r, 3), 6),
				Vector3.ZERO, mats, "eyes")
		# Eyebrow: a tapered arc well above the eye, tilted up toward the outside.
		var brow_pts: PackedVector3Array = PackedVector3Array()
		var brow_r: PackedFloat32Array = PackedFloat32Array([0.0025, 0.0033, 0.0028, 0.001])
		for i: int in 4:
			var t: float = float(i) / 3.0
			var bx: float = s * (0.044 + 0.052 * t)
			var by: float = 0.205 + 0.006 * sin(t * PI)
			brow_pts.append(Vector3(bx, by, face_z(bx, by) - 0.002))
		SkaterParts.part(head, "Brow" + side + "Mesh", SkaterParts.tube(_smooth(brow_pts, 3), _smooth_r(brow_r, 3), 6),
				Vector3.ZERO, mats, "brow")
		var blush: MeshInstance3D = SkaterParts.part(head, "Blush" + side + "Mesh", SkaterParts.sphere(0.026),
				Vector3(s * 0.098, 0.068, face_z(s * 0.1, 0.068) + 0.005), mats, "blush")
		blush.scale = Vector3(1.0, 0.55, 0.35)

	# Friendly smile: a shallow arc with a small lower-lip hint.
	var mouth_pts: PackedVector3Array = PackedVector3Array()
	var mouth_r: PackedFloat32Array = PackedFloat32Array([0.0022, 0.0042, 0.0052, 0.0042, 0.0022])
	for i: int in 5:
		var t: float = -1.0 + 0.5 * float(i)
		var mx: float = t * 0.03
		var my: float = 0.06 + 0.01 * t * t
		mouth_pts.append(Vector3(mx, my, face_z(mx, my) - 0.002))
	SkaterParts.part(head, "MouthMesh", SkaterParts.tube(_smooth(mouth_pts, 3), _smooth_r(mouth_r, 3), 6),
			Vector3.ZERO, mats, "mouth")


static func _build_hair(head: Node3D, mats: Dictionary) -> void:
	var prof: PackedVector2Array = face_profile()
	# Crown: a smooth dome over the top of the head; its edge sits above the brows. It is a hemisphere-like shell.
	var crown: MeshInstance3D = SkaterParts.part(head, "HairCapMesh",
			SkaterParts.lathe(_top(prof, 0.215, 0.3175, 0.02), 1.02, 0.0, TAU, 28), Vector3.ZERO, mats, "hair")
	crown.rotation.x = 0.0
	# Back shell: everything behind and beside the face, down to the nape, open at the front.
	var w: float = deg_to_rad(64.0)
	SkaterParts.part(head, "HairBackMesh", SkaterParts.lathe(SkaterParts.profile_band(prof, 0.0, 0.26, 0.02, 12), 1.02,
			w, TAU - w, 28), Vector3.ZERO, mats, "hair")
	var cap2: MeshInstance3D = SkaterParts.part(head, "HairVolumeMesh", SkaterParts.sphere(0.19),
			Vector3(0.0, 0.1, 0.045), mats, "hair_dark")
	cap2.scale = Vector3(0.96, 0.88, 0.8)
	# Parting and darker roots along the hairline, plus sun-bleached highlight streaks over the crown.
	var part_pts: PackedVector3Array = PackedVector3Array()
	var part_r: PackedFloat32Array = PackedFloat32Array()
	for i: int in 7:
		var t: float = float(i) / 6.0
		var py: float = lerpf(0.315, 0.235, t)
		var px: float = 0.03 + 0.03 * t
		var pr: float = SkaterParts.profile_r(prof, py) + 0.0215
		part_pts.append(Vector3(px, py, -pr * 1.02 * sqrt(maxf(1.0 - pow(px / pr, 2.0), 0.01))))
		part_r.append(0.0035)
	SkaterParts.part(head, "HairPartMesh", SkaterParts.tube(_smooth(part_pts, 3), _smooth_r(part_r, 3), 6),
			Vector3.ZERO, mats, "hair_root")
	for i: int in 3:
		var ang: float = deg_to_rad(-60.0 + 55.0 * float(i))
		var sp: PackedVector3Array = PackedVector3Array()
		var sr: PackedFloat32Array = PackedFloat32Array()
		for j: int in 6:
			var py: float = lerpf(0.31, 0.25, float(j) / 5.0)
			var rr: float = SkaterParts.profile_r(prof, py) + 0.024
			var a: float = ang * (0.35 + 0.65 * float(j) / 5.0) + 0.3 * float(i) + 0.4
			sp.append(Vector3(rr * sin(a), py, -rr * 1.02 * cos(a)))
			sr.append(0.006 * sin(PI * (0.15 + 0.8 * float(j) / 5.0)) + 0.001)
		SkaterParts.part(head, "HairStreak%dMesh" % i, SkaterParts.tube_capped(_smooth(sp, 3), _smooth_r(sr, 3), 6),
				Vector3.ZERO, mats, "hair_light")

	# Bangs: darker back layer, lighter front layer. The centre ones end above the brows, the side sweeps frame the face.
	var back_specs: Array = [
		[-0.1, -0.1, 0.17, 0.05], [-0.02, -0.035, 0.225, 0.045], [0.04, 0.06, 0.225, 0.045], [0.1, 0.122, 0.14, 0.05],
	]
	for i: int in back_specs.size():
		var b: Array = back_specs[i]
		_bang(head, "BangBack%d" % i, mats, "hair_dark", float(b[0]) * 0.4, float(b[1]), float(b[2]) + 0.004, float(b[3]), 0.014)
	var front_specs: Array = [
		[-0.085, -0.115, 0.14, 0.05], [-0.01, -0.02, 0.23, 0.042], [0.05, 0.075, 0.228, 0.042], [0.09, 0.132, 0.1, 0.05],
	]
	for i: int in front_specs.size():
		var b: Array = front_specs[i]
		_bang(head, "BangFront%d" % i, mats, "hair", float(b[0]) * 0.4 + 0.01, float(b[1]), float(b[2]), float(b[3]))

	# Side locks framing the face, over the cheek and down to the collarbone, flicking outward at the tips.
	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var pts: PackedVector3Array = PackedVector3Array([
			Vector3(s * 0.15, 0.22, -0.05), Vector3(s * 0.172, 0.14, -0.075), Vector3(s * 0.176, 0.05, -0.082),
			Vector3(s * 0.172, -0.05, -0.07), Vector3(s * 0.176, -0.12, -0.05), Vector3(s * 0.184, -0.17, -0.035),
		])
		var radii: PackedFloat32Array = PackedFloat32Array([0.03, 0.036, 0.034, 0.03, 0.02, 0.003])
		_sheet(head, "LockMesh" + side, mats, "hair", pts, radii, 0.7)
		var inner: PackedVector3Array = PackedVector3Array([
			Vector3(s * 0.14, 0.2, -0.1), Vector3(s * 0.158, 0.12, -0.108), Vector3(s * 0.158, 0.03, -0.1),
			Vector3(s * 0.156, -0.06, -0.082), Vector3(s * 0.162, -0.12, -0.06),
		])
		var inner_r: PackedFloat32Array = PackedFloat32Array([0.022, 0.028, 0.026, 0.018, 0.003])
		_sheet(head, "LockInner" + side + "Mesh", mats, "hair_dark", inner, inner_r, 0.7)


## Dome profile from the face profile between two heights, pushed out, closed at the crown.
static func _top(prof: PackedVector2Array, y0: float, y1: float, offset: float) -> PackedVector2Array:
	var out: PackedVector2Array = SkaterParts.profile_band(prof, y0, y1, offset, 10)
	out.append(Vector2(0.03, 0.3265))
	out.append(Vector2(0.0, 0.3295))
	return out


## A flat hair sheet: a tapered capped tube squashed along X (the points are given in final space).
static func _sheet(head: Node3D, part_name: String, mats: Dictionary, key: String, pts: PackedVector3Array,
		radii: PackedFloat32Array, flat: float) -> MeshInstance3D:
	var scaled: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in pts:
		scaled.append(Vector3(p.x / flat, p.y, p.z))
	var mi: MeshInstance3D = SkaterParts.part(head, part_name,
			SkaterParts.tube_capped(_smooth(scaled, 3), _smooth_r(radii, 3), 8), Vector3.ZERO, mats, key)
	mi.scale = Vector3(flat, 1.0, 1.0)
	return mi


## One tapered bang lock: from the crown near x_root over the forehead, ending in a swept soft point near
## (x_tip, y_tip) just in front of the face.
static func _bang(head: Node3D, part_name: String, mats: Dictionary, key: String, x_root: float, x_tip: float,
		y_tip: float, radius: float, zoff: float = 0.0) -> void:
	var dir: float = signf(x_tip - 0.015)
	var pts: PackedVector3Array = PackedVector3Array()
	pts.append(Vector3(x_root, 0.29, -0.06))
	var mid_x: float = lerpf(x_root, x_tip, 0.5)
	pts.append(Vector3(mid_x, 0.265, face_z(mid_x, 0.265) - 0.026 + zoff))
	pts.append(Vector3(x_tip, y_tip + 0.03, face_z(x_tip, y_tip + 0.03) - 0.026 + zoff))
	pts.append(Vector3(x_tip + dir * 0.012, y_tip + 0.008, face_z(x_tip, y_tip + 0.02) - 0.028 + zoff))
	pts.append(Vector3(x_tip + dir * 0.026, y_tip - 0.016, face_z(x_tip, y_tip + 0.02) - 0.024 + zoff))
	var r: float = radius * 0.62
	var radii: PackedFloat32Array = PackedFloat32Array([r * 0.9, r, r * 0.85, r * 0.5, 0.002])
	var lock: MeshInstance3D = SkaterParts.part(head, part_name, SkaterParts.tube_capped(_smooth(pts, 3), _smooth_r(radii, 3), 8),
			Vector3.ZERO, mats, key)
	lock.scale = Vector3.ONE


## High ponytail: overlapping tapered, slightly wavy sheets from a coral hair tie, arcing back and flowing down to
## the waist, with a sun-bleached highlight strand.
static func _build_ponytail(head: Node3D, mats: Dictionary) -> void:
	var root: Vector3 = Vector3(0.0, 0.245, 0.115)
	var tie: MeshInstance3D = SkaterParts.part(head, "HairTieMesh", SkaterParts.torus(0.05, 0.08), root + Vector3(0.0, 0.004, 0.012),
			mats, "hair_tie")
	tie.rotation.x = PI * 0.5 - 0.55
	tie.scale = Vector3(1.0, 1.0, 1.0)
	# dx, key, radius scale, length scale, wave amplitude, wave phase
	var specs: Array = [
		[0.0, "hair", 1.0, 1.0, 0.012, 0.0],
		[-0.05, "hair_dark", 0.7, 0.9, 0.016, 1.7],
		[0.05, "hair_dark", 0.72, 0.95, 0.016, 3.1],
		[0.012, "hair_light", 0.42, 0.97, 0.01, 0.8],
	]
	for i: int in specs.size():
		var sp: Array = specs[i]
		var dx: float = float(sp[0])
		var rs: float = float(sp[2])
		var ls: float = float(sp[3])
		var amp: float = float(sp[4])
		var ph: float = float(sp[5])
		var base: Array = [
			Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.03, 0.07), Vector3(0.0, 0.04, 0.16), Vector3(0.0, 0.0, 0.26),
			Vector3(0.0, -0.1, 0.33), Vector3(0.0, -0.24, 0.37), Vector3(0.0, -0.38, 0.38), Vector3(0.0, -0.5, 0.36),
			Vector3(0.0, -0.58, 0.34),
		]
		var pts: PackedVector3Array = PackedVector3Array()
		for k: int in base.size():
			var t: float = float(k) / float(base.size() - 1)
			var b: Vector3 = base[k]
			var lift: float = 0.0 if i != 3 else 0.012
			pts.append(root + Vector3((dx + amp * sin(t * 7.0 + ph) * t) * 1.0, b.y * ls + lift, b.z * ls + (0.0 if i != 3 else 0.0)))
		var radii: PackedFloat32Array = PackedFloat32Array([
			0.05 * rs, 0.066 * rs, 0.07 * rs, 0.064 * rs, 0.056 * rs, 0.046 * rs, 0.034 * rs, 0.018 * rs, 0.003,
		])
		_sheet(head, "PonytailMesh" if i == 0 else "PonytailLock%d" % i, mats, str(sp[1]), pts, radii, 0.75 if i == 0 else 0.6)


## Small white flower hair clip above the left temple.
static func _build_flower(head: Node3D, mats: Dictionary) -> void:
	var c: Vector3 = Vector3(-0.118, 0.235, -0.085)
	var holder: Node3D = SkaterParts.joint(head, "FlowerClip", c)
	holder.rotation = Vector3(0.0, deg_to_rad(-52.0), deg_to_rad(18.0))
	for i: int in 5:
		var a: float = TAU * float(i) / 5.0
		var pet: MeshInstance3D = SkaterParts.part(holder, "FlowerPetal%dMesh" % i, SkaterParts.sphere(0.021),
				Vector3(sin(a) * 0.022, cos(a) * 0.022, -0.002), mats, "flower")
		pet.scale = Vector3(0.85, 1.1, 0.5)
		pet.rotation.z = -a
	SkaterParts.part(holder, "FlowerCenterMesh", SkaterParts.sphere(0.0125), Vector3(0.0, 0.0, -0.007), mats, "flower_center")


## Catmull-Rom resample: `sub` points per original segment, passing through every original point.
static func _smooth(pts: PackedVector3Array, sub: int) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var n: int = pts.size()
	for i: int in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		for k: int in sub:
			var t: float = float(k) / float(sub)
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(pts[n - 1])
	return out


## Linear resample of per-point radii to match _smooth.
static func _smooth_r(radii: PackedFloat32Array, sub: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var n: int = radii.size()
	for i: int in n - 1:
		for k: int in sub:
			out.append(lerpf(radii[i], radii[i + 1], float(k) / float(sub)))
	out.append(radii[n - 1])
	return out
