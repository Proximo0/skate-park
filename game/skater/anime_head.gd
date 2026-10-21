class_name AnimeHead
extends RefCounted
## Head parts of the anime skater girl: face, eyes, brows, hair (cap, layered bangs, side locks, bob nape) and a
## curved ponytail with a scrunchie. Static builders, called by PlaceholderSkater with the Head joint and the
## palette materials. Everything is in Head joint space; the face looks toward -Z.

const FACE_R: float = 0.17
const FACE_Y: float = 0.13


## Z of the face sphere's front surface at (x, y) in head space (negative, toward the nose).
static func face_z(x: float, y: float) -> float:
	var dy: float = y - FACE_Y
	return -sqrt(maxf(FACE_R * FACE_R - x * x - dy * dy, 0.0001))


static func build(head: Node3D, mats: Dictionary) -> void:
	SkaterParts.part(head, "HeadMesh", SkaterParts.sphere(FACE_R), Vector3(0.0, FACE_Y, 0.0), mats, "skin")
	var jaw: MeshInstance3D = SkaterParts.part(head, "JawMesh", SkaterParts.sphere(0.13), Vector3(0.0, 0.06, -0.03), mats, "skin")
	jaw.scale = Vector3(1.0, 0.85, 0.9)
	SkaterParts.part(head, "NoseMesh", SkaterParts.sphere(0.011), Vector3(0.0, 0.088, face_z(0.0, 0.088) - 0.002), mats, "nose")
	_build_face(head, mats)
	_build_hair(head, mats)
	_build_ponytail(head, mats)


static func _build_face(head: Node3D, mats: Dictionary) -> void:
	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var x: float = s * 0.066
		var y: float = 0.122
		var z0: float = face_z(x, y) + 0.004
		# Eye: white, a big teal iris with a lighter lower half, a dark pupil, two highlights, curved lash and flick.
		var eye: MeshInstance3D = SkaterParts.part(head, "Eye" + side + "Mesh", SkaterParts.sphere(0.044),
				Vector3(x, y, z0), mats, "eye_white")
		eye.scale = Vector3(0.95, 1.12, 0.3)
		var iris: MeshInstance3D = SkaterParts.part(head, "Iris" + side + "Mesh", SkaterParts.sphere(0.035),
				Vector3(x, y - 0.004, z0 - 0.007), mats, "iris")
		iris.scale = Vector3(0.96, 1.2, 0.3)
		var glow: MeshInstance3D = SkaterParts.part(head, "IrisGlow" + side + "Mesh", SkaterParts.sphere(0.024),
				Vector3(x, y - 0.016, z0 - 0.0095), mats, "iris_light")
		glow.scale = Vector3(1.05, 0.55, 0.3)
		var pupil: MeshInstance3D = SkaterParts.part(head, "Pupil" + side + "Mesh", SkaterParts.sphere(0.02),
				Vector3(x, y + 0.001, z0 - 0.0125), mats, "eyes")
		pupil.scale = Vector3(0.9, 1.2, 0.3)
		SkaterParts.part(head, "EyeShine" + side + "Mesh", SkaterParts.sphere(0.01),
				Vector3(x - s * 0.011, y + 0.017, z0 - 0.018), mats, "eye_white")
		SkaterParts.part(head, "EyeShineSmall" + side + "Mesh", SkaterParts.sphere(0.0055),
				Vector3(x + s * 0.012, y - 0.016, z0 - 0.018), mats, "eye_white")
		# Upper lash: an arc hugging the top of the eye, thickest toward the outer corner, ending in a flick.
		var lash_pts: PackedVector3Array = PackedVector3Array()
		var lash_r: PackedFloat32Array = PackedFloat32Array()
		for i: int in 7:
			var t: float = -1.0 + 2.0 * float(i) / 6.0
			var lx: float = x + s * t * 0.044
			var ly: float = y + 0.048 - 0.018 * t * t + s * t * 0.004
			lash_pts.append(Vector3(lx, ly, face_z(lx, ly) - 0.003))
			lash_r.append(0.0028 + 0.0022 * (0.5 + 0.5 * t * s))
		var fx: float = x + s * 0.062
		var fy: float = y + 0.066
		lash_pts.append(Vector3(fx, fy, face_z(fx, fy) - 0.002))
		lash_r.append(0.0015)
		SkaterParts.part(head, "Lash" + side + "Mesh", SkaterParts.tube(_smooth(lash_pts, 3), _smooth_r(lash_r, 3), 5),
				Vector3.ZERO, mats, "eyes")
		# Eyebrow: a short tapered arc well above the eye, tilted up toward the outside.
		var brow_pts: PackedVector3Array = PackedVector3Array()
		var brow_r: PackedFloat32Array = PackedFloat32Array([0.0025, 0.0033, 0.0028, 0.001])
		for i: int in 4:
			var t: float = float(i) / 3.0
			var bx: float = s * (0.042 + 0.05 * t)
			var by: float = 0.2 + 0.008 * t
			brow_pts.append(Vector3(bx, by, face_z(bx, by) - 0.002))
		SkaterParts.part(head, "Brow" + side + "Mesh", SkaterParts.tube(_smooth(brow_pts, 3), _smooth_r(brow_r, 3), 5),
				Vector3.ZERO, mats, "hair_dark")
		var blush: MeshInstance3D = SkaterParts.part(head, "Blush" + side + "Mesh", SkaterParts.sphere(0.028),
				Vector3(s * 0.105, 0.078, face_z(s * 0.108, 0.078) + 0.006), mats, "blush")
		blush.scale = Vector3(1.0, 0.6, 0.35)

	# Small smile: a shallow arc.
	var mouth_pts: PackedVector3Array = PackedVector3Array()
	var mouth_r: PackedFloat32Array = PackedFloat32Array([0.0025, 0.0045, 0.0055, 0.0045, 0.0025])
	for i: int in 5:
		var t: float = -1.0 + 0.5 * float(i)
		var mx: float = t * 0.026
		var my: float = 0.066 + 0.008 * t * t
		mouth_pts.append(Vector3(mx, my, face_z(mx, my) - 0.002))
	SkaterParts.part(head, "MouthMesh", SkaterParts.tube(_smooth(mouth_pts, 3), _smooth_r(mouth_r, 3), 5),
			Vector3.ZERO, mats, "mouth")


static func _build_hair(head: Node3D, mats: Dictionary) -> void:
	# Hair cap: a hemisphere tilted so its rim rises over the forehead and drops to the nape.
	var cap: MeshInstance3D = SkaterParts.part(head, "HairCapMesh", SkaterParts.dome(0.207), Vector3(0.0, 0.14, 0.045), mats, "hair")
	cap.rotation.x = 0.3
	cap.scale = Vector3(1.0, 0.85, 1.0)
	# Bob nape: fuller hair behind and under the head that the ponytail grows out of.
	var nape: MeshInstance3D = SkaterParts.part(head, "HairNapeMesh", SkaterParts.sphere(0.2), Vector3(0.0, 0.07, 0.04), mats, "hair_dark")
	nape.scale = Vector3(1.0, 0.74, 0.82)

	# Temple hair: fills the gap between the cap and the side locks.
	for s: float in [-1.0, 1.0]:
		var temple: MeshInstance3D = SkaterParts.part(head, "HairTemple" + ("Left" if s < 0.0 else "Right") + "Mesh",
				SkaterParts.sphere(0.07), Vector3(s * 0.125, 0.13, -0.045), mats, "hair_dark")
		temple.scale = Vector3(0.9, 1.0, 1.35)

	# Layered bangs: a darker back layer, then lighter locks in front. They sweep away from an off-centre parting and
	# taper to soft points just above the eyes.
	var back_tips: Array = [-0.115, -0.045, 0.03, 0.1]
	for i: int in back_tips.size():
		var tx: float = back_tips[i]
		_bang(head, "BangBack%d" % i, mats, "hair_dark", tx * 0.4, tx, 0.172, 0.05)
	var front_tips: Array = [-0.085, -0.01, 0.06, 0.12]
	for i: int in front_tips.size():
		var tx: float = front_tips[i]
		_bang(head, "BangFront%d" % i, mats, "hair", tx * 0.3 + 0.02, tx, 0.178 - 0.016 * absf(tx) * 5.0, 0.042)

	# Side locks framing the face down to the jaw, flicking outward at the tips.
	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var pts: PackedVector3Array = PackedVector3Array([
			Vector3(s * 0.15, 0.2, -0.05), Vector3(s * 0.172, 0.12, -0.062), Vector3(s * 0.172, 0.05, -0.06),
			Vector3(s * 0.166, -0.02, -0.05), Vector3(s * 0.172, -0.06, -0.035),
		])
		var radii: PackedFloat32Array = PackedFloat32Array([0.03, 0.034, 0.03, 0.02, 0.003])
		var lock: MeshInstance3D = SkaterParts.part(head, "LockMesh" + side,
				SkaterParts.tube(_smooth(pts, 4), _smooth_r(radii, 4), 8), Vector3.ZERO, mats, "hair")
		lock.scale = Vector3(0.8, 1.0, 1.0)
		var inner: PackedVector3Array = PackedVector3Array([
			Vector3(s * 0.135, 0.19, -0.1), Vector3(s * 0.16, 0.11, -0.095), Vector3(s * 0.155, 0.04, -0.085),
			Vector3(s * 0.15, -0.02, -0.07),
		])
		var inner_r: PackedFloat32Array = PackedFloat32Array([0.022, 0.026, 0.02, 0.003])
		SkaterParts.part(head, "LockInner" + side + "Mesh", SkaterParts.tube(_smooth(inner, 4), _smooth_r(inner_r, 4), 8),
				Vector3.ZERO, mats, "hair_dark")


## One tapered bang lock: from the crown near x_root over the forehead, ending in a swept soft point near
## (x_tip, y_tip) just in front of the face.
static func _bang(head: Node3D, part_name: String, mats: Dictionary, key: String, x_root: float, x_tip: float,
		y_tip: float, radius: float) -> void:
	var dir: float = signf(x_tip - 0.015)
	var pts: PackedVector3Array = PackedVector3Array()
	pts.append(Vector3(x_root, 0.285, -0.03))
	var mid_x: float = lerpf(x_root, x_tip, 0.5)
	pts.append(Vector3(mid_x, 0.25, face_z(mid_x, 0.25) - 0.032))
	pts.append(Vector3(x_tip, y_tip + 0.032, face_z(x_tip, y_tip + 0.032) - 0.028))
	pts.append(Vector3(x_tip + dir * 0.014, y_tip + 0.008, face_z(x_tip, y_tip + 0.02) - 0.028))
	pts.append(Vector3(x_tip + dir * 0.03, y_tip - 0.016, face_z(x_tip, y_tip + 0.02) - 0.022))
	var r: float = radius * 0.6
	var radii: PackedFloat32Array = PackedFloat32Array([r * 0.9, r, r * 0.85, r * 0.55, 0.002])
	var lock: MeshInstance3D = SkaterParts.part(head, part_name, SkaterParts.tube(_smooth(pts, 4), _smooth_r(radii, 4), 8),
			Vector3.ZERO, mats, key)
	lock.scale = Vector3(1.0, 1.0, 0.8)


## High ponytail: three overlapping tapered locks that rise from a pink scrunchie, arc back and swoosh down.
static func _build_ponytail(head: Node3D, mats: Dictionary) -> void:
	var root: Vector3 = Vector3(0.0, 0.195, 0.1)
	var scrunchie: MeshInstance3D = SkaterParts.part(head, "ScrunchieMesh", SkaterParts.torus(0.06, 0.09),
			root, mats, "scrunchie")
	scrunchie.rotation.x = PI * 0.5 - 0.5
	var specs: Array = [
		# x offset, key, radius scale, length scale, sideways flick
		[0.0, "hair", 1.0, 1.0, 0.0],
		[-0.045, "hair_dark", 0.7, 0.88, -0.05],
		[0.045, "hair_dark", 0.7, 0.92, 0.05],
	]
	for i: int in specs.size():
		var sp: Array = specs[i]
		var dx: float = float(sp[0])
		var rs: float = float(sp[2])
		var ls: float = float(sp[3])
		var fl: float = float(sp[4])
		var pts: PackedVector3Array = PackedVector3Array([
			root + Vector3(dx * 0.4, 0.0, 0.0),
			root + Vector3(dx * 0.8, 0.035 * ls, 0.09 * ls),
			root + Vector3(dx * 1.1 + fl * 0.3, 0.045 * ls, 0.2 * ls),
			root + Vector3(dx * 1.3 + fl * 0.8, 0.0, 0.3 * ls),
			root + Vector3(dx * 1.2 + fl * 1.6, -0.12 * ls, 0.36 * ls),
			root + Vector3(dx * 0.9 + fl * 2.4, -0.25 * ls, 0.35 * ls),
			root + Vector3(dx * 0.7 + fl * 3.0, -0.33 * ls, 0.3 * ls),
		])
		var radii: PackedFloat32Array = PackedFloat32Array([
			0.055 * rs, 0.068 * rs, 0.072 * rs, 0.065 * rs, 0.055 * rs, 0.03 * rs, 0.004,
		])
		var part: MeshInstance3D = SkaterParts.part(head, "PonytailMesh" if i == 0 else "PonytailLock%d" % i,
				SkaterParts.tube(_smooth(pts, 4), _smooth_r(radii, 4), 10), Vector3.ZERO, mats, str(sp[1]))
		part.scale = Vector3(0.85 if i == 0 else 0.7, 1.0, 1.0)


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
