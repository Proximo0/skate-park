class_name AnimeOutfit
extends RefCounted
## Outfit parts of the anime surf-skater girl: smooth skin torso, sporty bikini top, open short-sleeve rash guard,
## knee-length board shorts with a side stripe, crew socks and real skate shoes (skate_shoe). Static builders called by
## PlaceholderSkater with the joint to attach to and the palette materials. Torso parts live in chest joint space
## (the chest joint is 0.22 above the hips).

const TORSO_DEPTH: float = 0.78
const GUARD_OPEN: float = 0.7  ## half angle (rad) of the open front of the rash guard
const GUARD_Y0: float = -0.1
const GUARD_Y1: float = 0.19
const TOP_Y0: float = 0.0
const TOP_Y1: float = 0.13

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

static var _torso: PackedVector2Array = PackedVector2Array()


## Torso lathe profile (radius, y) in chest joint space: waist, ribs, shoulders, closing under the neck.
static func torso_profile() -> PackedVector2Array:
	if _torso.is_empty():
		_torso = SkaterParts.smooth2d(PackedVector2Array([
			Vector2(0.0, -0.17), Vector2(0.07, -0.165), Vector2(0.098, -0.14), Vector2(0.097, -0.1),
			Vector2(0.105, -0.06), Vector2(0.126, 0.0), Vector2(0.142, 0.05), Vector2(0.15, 0.1),
			Vector2(0.145, 0.14), Vector2(0.12, 0.175), Vector2(0.075, 0.2), Vector2(0.05, 0.215),
			Vector2(0.0, 0.222),
		]), 3)
	return _torso


## Torso: smooth skin body, bikini top, open rash guard. Called with the Spine and Chest joints.
static func build_torso(spine: Node3D, chest: Node3D, mats: Dictionary) -> void:
	var waist: MeshInstance3D = SkaterParts.part(spine, "SpineMesh", SkaterParts.sphere(0.1), Vector3.ZERO, mats, "skin")
	waist.scale = Vector3(1.0, 0.9, 0.78)
	var prof: PackedVector2Array = torso_profile()
	SkaterParts.part(chest, "ChestMesh", SkaterParts.lathe(prof, TORSO_DEPTH, 0.0, TAU, 28), Vector3.ZERO, mats, "skin")

	# Sporty crop bikini top: full coverage band with a white trim and two halter straps.
	var top: PackedVector2Array = SkaterParts.profile_band(prof, TOP_Y0, TOP_Y1, 0.006, 10)
	SkaterParts.part(chest, "BikiniTopMesh", SkaterParts.lathe(top, TORSO_DEPTH, 0.0, TAU, 28), Vector3.ZERO, mats, "top")
	_arc(chest, "BikiniHemMesh", prof, TOP_Y0, 0.009, -0.7, 0.7, 0.0045, mats, "top_trim")
	_arc(chest, "BikiniUpperTrimMesh", prof, TOP_Y1, 0.009, -0.7, 0.7, 0.0045, mats, "top_trim")
	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var pts: PackedVector3Array = PackedVector3Array()
		var radii: PackedFloat32Array = PackedFloat32Array()
		for i: int in 5:
			var t: float = float(i) / 4.0
			var y: float = lerpf(TOP_Y1, 0.2, t)
			var x: float = s * lerpf(0.055, 0.032, t)
			var rr: float = SkaterParts.profile_r(prof, y) + 0.009
			var k: float = clampf(x / rr, -0.99, 0.99)
			pts.append(Vector3(x, y, -TORSO_DEPTH * rr * sqrt(1.0 - k * k)))
			radii.append(0.0048)
		SkaterParts.part(chest, "BikiniStrap" + side + "Mesh", SkaterParts.tube(pts, radii, 8), Vector3.ZERO, mats, "top")

	# Short-sleeve rash guard, open at the front, cropped above the waist.
	var guard: PackedVector2Array = SkaterParts.profile_band(prof, GUARD_Y0, GUARD_Y1, 0.014, 14)
	SkaterParts.part(chest, "RashGuardMesh", SkaterParts.lathe(guard, TORSO_DEPTH, GUARD_OPEN, TAU - GUARD_OPEN, 28),
			Vector3.ZERO, mats, "shirt")
	_arc(chest, "RashGuardHemMesh", prof, GUARD_Y0, 0.0145, GUARD_OPEN, TAU - GUARD_OPEN, 0.0055, mats, "trim")
	_arc(chest, "RashGuardCollarMesh", prof, GUARD_Y1, 0.0145, 0.0, TAU, 0.0065, mats, "shirt_dark")
	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var pts: PackedVector3Array = PackedVector3Array()
		var radii: PackedFloat32Array = PackedFloat32Array()
		var ang: float = GUARD_OPEN if s > 0.0 else TAU - GUARD_OPEN
		for i: int in 9:
			var y: float = lerpf(GUARD_Y0, GUARD_Y1, float(i) / 8.0)
			var rr: float = SkaterParts.profile_r(prof, y) + 0.0145
			pts.append(Vector3(rr * sin(ang), y, -rr * TORSO_DEPTH * cos(ang)))
			radii.append(0.0055)
		SkaterParts.part(chest, "RashGuardEdge" + side + "Mesh", SkaterParts.tube_capped(pts, radii, 8), Vector3.ZERO, mats, "trim")
	# Shoulder-line side stripe down the rash guard flank.
	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var pts: PackedVector3Array = PackedVector3Array()
		var radii: PackedFloat32Array = PackedFloat32Array()
		for i: int in 8:
			var y: float = lerpf(0.12, GUARD_Y0 + 0.012, float(i) / 7.0)
			var rr: float = SkaterParts.profile_r(prof, y) + 0.0145
			var a: float = s * deg_to_rad(88.0)
			pts.append(Vector3(rr * sin(a), y, -rr * TORSO_DEPTH * cos(a)))
			radii.append(0.0055)
		SkaterParts.part(chest, "RashGuardStripe" + side + "Mesh", SkaterParts.tube_capped(pts, radii, 8), Vector3.ZERO, mats, "trim")


## A thin tube following the torso surface around the Y axis at height y, from angle a0 to a1.
static func _arc(parent: Node3D, part_name: String, prof: PackedVector2Array, y: float, offset: float, a0: float,
		a1: float, tube_r: float, mats: Dictionary, key: String) -> void:
	var rr: float = SkaterParts.profile_r(prof, y) + offset
	var pts: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var n: int = 28
	for i: int in n + 1:
		var a: float = lerpf(a0, a1, float(i) / float(n))
		pts.append(Vector3(rr * sin(a), y, -rr * TORSO_DEPTH * cos(a)))
		radii.append(tube_r)
	SkaterParts.part(parent, part_name, SkaterParts.tube_capped(pts, radii, 8), Vector3.ZERO, mats, key)


## A horizontal ring (circle around the local Y axis) of the given radius at height y.
static func _ring(parent: Node3D, part_name: String, y: float, radius: float, tube_r: float, mats: Dictionary, key: String) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	for i: int in 25:
		var a: float = TAU * float(i) / 24.0
		pts.append(Vector3(radius * cos(a), y, radius * sin(a)))
		radii.append(tube_r)
	SkaterParts.part(parent, part_name, SkaterParts.tube_capped(pts, radii, 8), Vector3.ZERO, mats, key)


## Rash guard short sleeve over the upper arm, with a trim cuff.
static func build_sleeve(upper: Node3D, side: String, mats: Dictionary) -> void:
	var pts: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 0.01, 0.0), Vector3(0.0, -0.03, 0.0), Vector3(0.0, -0.08, 0.0), Vector3(0.0, -0.12, 0.0),
	])
	var radii: PackedFloat32Array = PackedFloat32Array([0.046, 0.05, 0.048, 0.044])
	SkaterParts.part(upper, side + "SleeveMesh", SkaterParts.tube_capped(AnimeHead._smooth(pts, 3), AnimeHead._smooth_r(radii, 3), 14),
			Vector3.ZERO, mats, "shirt")
	_ring(upper, side + "SleeveCuffMesh", -0.115, 0.0445, 0.006, mats, "trim")


static func build_wristband(lower: Node3D, side: String, mats: Dictionary) -> void:
	SkaterParts.part(lower, side + "WristbandMesh", SkaterParts.cylinder(0.0305, 0.036), Vector3(0.0, -0.172, 0.0), mats, "band")
	_ring(lower, side + "WristbandTrimMesh", -0.19, 0.0295, 0.0035, mats, "trim")


## Knee-length board shorts: a smooth tapered thigh tube (key "pants") with a side stripe and a trim hem.
static func build_shorts(upper: Node3D, side: String, upper_leg: float, mats: Dictionary) -> void:
	var ys: Array = [0.02, -0.04, -0.12, -0.2, -0.26, -(upper_leg - 0.012)]
	var rs: Array = [0.075, 0.073, 0.068, 0.066, 0.068, 0.07]
	var pts: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	for i: int in ys.size():
		pts.append(Vector3(0.0, float(ys[i]), 0.0))
		radii.append(float(rs[i]))
	SkaterParts.part(upper, side + "UpperLegMesh", SkaterParts.tube(AnimeHead._smooth(pts, 3), AnimeHead._smooth_r(radii, 3), 18),
			Vector3.ZERO, mats, "pants")
	var hem_y: float = -(upper_leg - 0.012)
	SkaterParts.part(upper, side + "ShortsLiningMesh", _annulus(0.0695, 0.036, hem_y), Vector3.ZERO, mats, "pants")
	_ring(upper, side + "ShortsHemMesh", hem_y, 0.07, 0.0065, mats, "pants_trim")
	# Side stripe on the outer face of the thigh.
	var s: float = -1.0 if side == "Left" else 1.0
	var line: PackedVector3Array = PackedVector3Array()
	for i: int in 9:
		var y: float = lerpf(-0.03, hem_y + 0.012, float(i) / 8.0)
		var r: float = _lerp_table(ys, rs, y)
		line.append(Vector3(s * (r + 0.0012), y, 0.0))
	SkaterParts.part(upper, side + "ShortsStripeMesh", SkaterParts.ribbon(line, Vector3(0.0, 0.0, 1.0), 0.012, Vector3(s, 0.0, 0.0)),
			Vector3.ZERO, mats, "short_stripe")
	SkaterParts.part(upper, side + "ShortsStripe2Mesh", SkaterParts.ribbon(_shift(line, 0.0, 0.0, 0.026), Vector3(0.0, 0.0, 1.0), 0.0045, Vector3(s, 0.0, 0.0)),
			Vector3.ZERO, mats, "pants_trim")


## Flat ring disc at height y, visible from both sides (closes the open hem of the shorts).
static func _annulus(r_out: float, r_in: float, y: float) -> ArrayMesh:
	var rows: Array = []
	for r: float in [r_out, r_in]:
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in 28:
			var a: float = TAU * float(k) / 28.0
			ring.append(Vector3(r * sin(a), y, -r * cos(a)))
		rows.append(ring)
	return SkaterParts.merge([[SkaterParts.grid(rows, true), Transform3D.IDENTITY], [SkaterParts.grid(rows, true, true), Transform3D.IDENTITY]])


static func _shift(pts: PackedVector3Array, dx: float, dy: float, dz: float) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in pts:
		out.append(p + Vector3(dx, dy, dz))
	return out


## Linear lookup of a decreasing-y table.
static func _lerp_table(ys: Array, vs: Array, y: float) -> float:
	for i: int in ys.size() - 1:
		if y >= float(ys[i + 1]):
			var t: float = (float(ys[i]) - y) / maxf(float(ys[i]) - float(ys[i + 1]), 0.00001)
			return lerpf(float(vs[i]), float(vs[i + 1]), t)
	return float(vs[vs.size() - 1])


## Smooth skin shin with a knee cap, and a high-crew striped sock over the lower part.
static func build_sock(lower: Node3D, side: String, lower_leg: float, mats: Dictionary) -> void:
	SkaterParts.part(lower, side + "KneeMesh", SkaterParts.sphere(0.043), Vector3.ZERO, mats, "skin")
	var pts: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.05, 0.0), Vector3(0.0, -0.09, 0.0), Vector3(0.0, -0.14, 0.0),
		Vector3(0.0, -(lower_leg - 0.03), 0.0),
	])
	var radii: PackedFloat32Array = PackedFloat32Array([0.04, 0.046, 0.041, 0.033, 0.027])
	SkaterParts.part(lower, side + "LowerLegMesh", SkaterParts.tube_capped(AnimeHead._smooth(pts, 3), AnimeHead._smooth_r(radii, 3), 16),
			Vector3.ZERO, mats, "skin")
	var sp: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, -0.077, 0.0), Vector3(0.0, -0.12, 0.0), Vector3(0.0, -0.17, 0.0), Vector3(0.0, -(lower_leg - 0.005), 0.0),
	])
	var sr: PackedFloat32Array = PackedFloat32Array([0.0445, 0.04, 0.0365, 0.034])
	SkaterParts.part(lower, side + "SockMesh", SkaterParts.tube(AnimeHead._smooth(sp, 3), AnimeHead._smooth_r(sr, 3), 16),
			Vector3.ZERO, mats, "sock")
	_ring(lower, side + "SockCuffMesh", -0.077, 0.0445, 0.0055, mats, "sock")
	_ring(lower, side + "SockStripe0Mesh", -0.092, 0.0425, 0.0045, mats, "sock_stripe")
	_ring(lower, side + "SockStripe1Mesh", -0.108, 0.0412, 0.0045, mats, "sock_stripe2")
	_ring(lower, side + "SockStripe2Mesh", -0.124, 0.0398, 0.0045, mats, "sock_stripe")


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
