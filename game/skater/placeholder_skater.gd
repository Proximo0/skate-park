class_name PlaceholderSkater
extends RefCounted
## Placeholder anime skater girl and surf-style skateboard, built in code from primitives (no imported assets).
## build_body(): a joint hierarchy named after SkeletonProfileHumanoid bones. Faces -Z, feet at y = 0.
## The caller stands it on the deck with body.position.y = DECK_TOP_Y. Regular stance: left foot forward
## (-Z). Leg poses come from a small two-bone solve so the shoes stay flat on the ground.
## build_board(): deck long along Z, nose at -Z, wheel bottoms at y = 0.
## Every MeshInstance3D has meta "palette" (its palette key) and its StandardMaterial3D in material_override,
## so the toon pass can walk the meshes and swap materials.
## Look: 12-14 year old anime skater girl. Big glossy eyes with lashes, a teal bob with swoopy wedge bangs and a
## high pink-scrunchie ponytail, an oversized lilac hoodie with a front pocket and drawstrings, cargo shorts,
## striped socks, chunky coral skate shoes, a shell necklace and mint wristbands. Board: sand grip with aqua and
## coral surf stripes and pastel mint wheels.
## Only the mesh parts and palette defaults are styling; the joints, pivots and bone lengths are the rig contract.

const DECK_TOP_Y: float = 0.135
const HIP_HEIGHT: float = 0.62
const UPPER_LEG: float = 0.30
const LOWER_LEG: float = 0.22
const ANKLE_HEIGHT: float = 0.12
const HIP_SPREAD: float = 0.075
const FOOT_Z: float = 0.12
const UPPER_ARM: float = 0.22
const LOWER_ARM: float = 0.2
const ARM_OUT: float = 0.35
const FOREARM_BEND: float = 0.5

## Hoodie torso geometry (chest joint space): the chest sphere's centre height and half sizes, to seat front
## details on its surface.
const TORSO_CENTER_Y: float = 0.04
const TORSO_HALF_Y: float = 0.1725
const TORSO_HALF_Z: float = 0.1425


static func build_body(palette: Dictionary = {}) -> Node3D:
	var mats: Dictionary = _materials(palette, _body_defaults())
	var root: Node3D = Node3D.new()
	root.name = "SkaterBody"

	var hips: Node3D = _joint(root, "Hips", Vector3(0.0, HIP_HEIGHT, 0.0))
	var pelvis: MeshInstance3D = _part(hips, "HipsMesh", _sphere(0.125), Vector3.ZERO, mats, "pants")
	pelvis.scale = Vector3(1.15, 0.72, 0.95)

	var spine: Node3D = _joint(hips, "Spine", Vector3(0.0, 0.08, 0.0))
	var hem: MeshInstance3D = _part(spine, "SpineMesh", _sphere(0.12), Vector3.ZERO, mats, "shirt")
	hem.scale = Vector3(1.12, 0.85, 0.95)
	var chest: Node3D = _joint(spine, "Chest", Vector3(0.0, 0.14, 0.0))
	var torso: MeshInstance3D = _part(chest, "ChestMesh", _sphere(0.15),Vector3(0.0, TORSO_CENTER_Y, 0.0), mats, "shirt")
	torso.scale = Vector3(1.12, 1.15, 0.95)
	_part(chest, "HoodieCollarMesh", _torus(0.058, 0.084), Vector3(0.0, 0.17, 0.0), mats, "shirt")
	_build_hoodie_front(chest, mats)

	var neck: Node3D = _joint(chest, "Neck", Vector3(0.0, 0.20, 0.0))
	_part(neck, "NeckMesh", _cylinder(0.05, 0.1), Vector3(0.0, -0.01, 0.0), mats, "skin")
	var head: Node3D = _joint(neck, "Head", Vector3(0.0, 0.04, 0.0))
	_build_head_parts(head, mats)

	_build_arm(chest, "Left", -1.0, mats)
	_build_arm(chest, "Right", 1.0, mats)
	_build_leg(hips, "Left", -1.0, -FOOT_Z, mats)
	_build_leg(hips, "Right", 1.0, FOOT_Z, mats)
	return root


static func build_board(palette: Dictionary = {}) -> Node3D:
	var mats: Dictionary = _materials(palette, _board_defaults())
	var root: Node3D = Node3D.new()
	root.name = "Skateboard"

	# Sand grip on top (the deck top stays at DECK_TOP_Y), with an aqua and a coral surf stripe down the sides.
	_part(root, "Deck", _box(Vector3(0.22, 0.03, 0.8)), Vector3(0.0, 0.12, 0.0), mats, "grip")
	_part(root, "DeckStripe", _box(Vector3(0.226, 0.016, 0.66)), Vector3(0.0, 0.125, 0.0), mats, "deck")
	_part(root, "DeckWaveStripe", _box(Vector3(0.227, 0.008, 0.66)), Vector3(0.0, 0.112, 0.0), mats, "deck_alt")
	_part(root, "DeckUnderStripe", _box(Vector3(0.12, 0.006, 0.44)), Vector3(0.0, 0.102, 0.0), mats, "deck")
	var nose: MeshInstance3D = _part(root, "NoseKick", _box(Vector3(0.22, 0.02, 0.1)), Vector3(0.0, 0.14, -0.36), mats, "grip")
	nose.rotation.x = 0.25
	var tail: MeshInstance3D = _part(root, "TailKick", _box(Vector3(0.22, 0.02, 0.1)), Vector3(0.0, 0.14, 0.36), mats, "grip")
	tail.rotation.x = -0.25

	_build_truck(root, "Front", -0.28, mats)
	_build_truck(root, "Back", 0.28, mats)
	_build_wheel(root, "Wheel_FL", -0.12, -0.28, mats)
	_build_wheel(root, "Wheel_FR", 0.12, -0.28, mats)
	_build_wheel(root, "Wheel_BL", -0.12, 0.28, mats)
	_build_wheel(root, "Wheel_BR", 0.12, 0.28, mats)
	return root


static func _body_defaults() -> Dictionary:
	return {
		"skin": Color(1.0, 0.8, 0.68),
		"nose": Color(0.95, 0.68, 0.6),
		"hair": Color(0.27, 0.86, 0.82),
		"hair_dark": Color(0.1, 0.56, 0.6),
		"scrunchie": Color(1.0, 0.45, 0.72),
		"eyes": Color(0.14, 0.09, 0.16),
		"eye_white": Color(1.0, 1.0, 1.0),
		"mouth": Color(0.85, 0.3, 0.36),
		"blush": Color(1.0, 0.55, 0.62),
		"shirt": Color(0.78, 0.72, 1.0),
		"shirt_dark": Color(0.62, 0.55, 0.92),
		"trim": Color(1.0, 0.98, 0.94),
		"shell": Color(1.0, 0.95, 0.86),
		"band": Color(0.5, 0.95, 0.85),
		"pants": Color(0.95, 0.82, 0.6),
		"pants_dark": Color(0.8, 0.66, 0.42),
		"sock": Color(1.0, 0.98, 0.95),
		"sock_stripe": Color(1.0, 0.45, 0.72),
		"shoes": Color(0.98, 0.5, 0.58),
		"sole": Color(1.0, 0.98, 0.95),
		"toe": Color(0.5, 0.95, 0.85),
	}


static func _board_defaults() -> Dictionary:
	return {
		"grip": Color(0.96, 0.9, 0.78),
		"deck": Color(0.3, 0.85, 0.9),
		"deck_alt": Color(1.0, 0.55, 0.5),
		"wheels": Color(0.62, 0.95, 0.84),
		"hubs": Color(1.0, 0.9, 0.95),
		"trucks": Color(0.88, 0.85, 0.96),
	}


## Front of the hoodie: a kangaroo pocket, two drawstrings down to it and a shell necklace across the collar.
static func _build_hoodie_front(chest: Node3D, mats: Dictionary) -> void:
	var pocket_y: float = 0.0
	_part(chest, "PocketMesh", _box(Vector3(0.13, 0.07, 0.02)),
			Vector3(0.0, pocket_y, _torso_front_z(pocket_y) - 0.002), mats, "shirt_dark")
	for s: float in [-1.0, 1.0]:
		var string_y: float = 0.08
		var side: String = "Left" if s < 0.0 else "Right"
		_part(chest, "Drawstring" + side + "Mesh", _cylinder(0.0045, 0.1),
				Vector3(s * 0.024, string_y, _torso_front_z(string_y) - 0.002), mats, "trim")
	for i: int in 5:
		var t: float = -1.0 + 0.5 * float(i)
		var y: float = 0.15 - 0.05 * (1.0 - t * t)
		var shell: MeshInstance3D = _part(chest, "ShellNecklace%dMesh" % i, _sphere(0.014),
				Vector3(t * 0.075, y, _torso_front_z(y) - 0.006), mats, "shell")
		shell.scale = Vector3(1.0, 0.8, 0.5)


## Front surface of the hoodie torso at chest-local height y (z is negative, toward the nose).
static func _torso_front_z(y: float) -> float:
	var k: float = clampf((y - TORSO_CENTER_Y) / TORSO_HALF_Y, -1.0, 1.0)
	return -TORSO_HALF_Z * sqrt(1.0 - k * k)


static func _build_head_parts(head: Node3D, mats: Dictionary) -> void:
	_part(head, "HeadMesh", _sphere(0.19), Vector3(0.0, 0.13, 0.0), mats, "skin")
	_part(head, "NoseMesh", _sphere(0.012), Vector3(0.0, 0.095, -0.189), mats, "nose")

	# Hair cap: a hemisphere pushed back so its front edge sits above the eyes; bangs and side locks hang from it.
	var cap: MeshInstance3D = _part(head, "HairCapMesh", _dome(0.2), Vector3(0.0, 0.16, 0.03), mats, "hair")
	cap.scale = Vector3(1.0, 0.92, 1.0)
	# Nape hair: a fuller back of the head that the ponytail grows from.
	var nape: MeshInstance3D = _part(head, "HairNapeMesh", _sphere(0.165), Vector3(0.0, 0.12, 0.1), mats, "hair_dark")
	nape.scale = Vector3(1.0, 0.95, 0.7)

	# Swoopy bangs: tapered three-sided strands from the hairline, fanned out from the centre parting so the tips
	# sweep to the sides and the eyes stay open below them.
	for i: int in 5:
		var x: float = -0.12 + 0.06 * float(i)
		var sx: float = signf(x) if i != 2 else 0.0
		var strand: PackedVector3Array = PackedVector3Array([
			Vector3(x * 0.8, 0.225, -0.15), Vector3(x + sx * 0.02, 0.2, -0.175), Vector3(x + sx * 0.06, 0.17, -0.19),
		])
		var radii: PackedFloat32Array = PackedFloat32Array([0.032, 0.024, 0.003])
		var hair_key: String = "hair" if i % 2 == 0 else "hair_dark"
		_part(head, "BangMesh%d" % i, _tube(strand, radii, 3), Vector3.ZERO, mats, hair_key)

	# Side locks framing the face, hanging to the jaw.
	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var lock: PackedVector3Array = PackedVector3Array([
			Vector3(s * 0.15, 0.13, -0.07), Vector3(s * 0.17, 0.02, -0.05), Vector3(s * 0.16, -0.08, -0.03),
		])
		var lock_radii: PackedFloat32Array = PackedFloat32Array([0.036, 0.03, 0.003])
		_part(head, "LockMesh" + side, _tube(lock, lock_radii, 3), Vector3.ZERO, mats, "hair")

	# High ponytail: a tapered tube off the back of the head, with a pink scrunchie at its root.
	var tail_points: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 0.24, 0.08), Vector3(0.0, 0.27, 0.17), Vector3(0.0, 0.27, 0.27),
		Vector3(0.0, 0.22, 0.35), Vector3(0.0, 0.15, 0.4), Vector3(0.0, 0.1, 0.42),
	])
	var tail_radii: PackedFloat32Array = PackedFloat32Array([0.08, 0.072, 0.06, 0.045, 0.024, 0.01])
	_part(head, "PonytailMesh", _tube(tail_points, tail_radii), Vector3.ZERO, mats, "hair")
	var scrunchie: MeshInstance3D = _part(head, "ScrunchieMesh", _torus(0.07, 0.094), Vector3(0.0, 0.27, 0.17),
			mats, "scrunchie")
	scrunchie.rotation.x = PI * 0.5

	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var x: float = s * 0.07
		# Big glossy eye: a white base, a large dark iris, two white highlights and a lash line with a flick.
		var eye: MeshInstance3D = _part(head, "Eye" + side + "Mesh", _sphere(0.05), Vector3(x, 0.125, -0.158), mats, "eye_white")
		eye.scale = Vector3(1.0, 1.15, 0.35)
		var iris: MeshInstance3D = _part(head, "Iris" + side + "Mesh", _sphere(0.04), Vector3(x, 0.118, -0.166), mats, "eyes")
		iris.scale = Vector3(1.0, 1.12, 0.32)
		_part(head, "EyeShine" + side + "Mesh", _sphere(0.013), Vector3(x - s * 0.012, 0.13, -0.18), mats, "eye_white")
		_part(head, "EyeShineSmall" + side + "Mesh", _sphere(0.006), Vector3(x + s * 0.004, 0.106, -0.18), mats, "eye_white")
		var lash: MeshInstance3D = _part(head, "Lash" + side + "Mesh", _box(Vector3(0.07, 0.012, 0.016)),
				Vector3(x, 0.182, -0.15), mats, "eyes")
		lash.rotation.x = -0.2
		var flick: MeshInstance3D = _part(head, "LashFlick" + side + "Mesh", _box(Vector3(0.028, 0.011, 0.016)),
				Vector3(x + s * 0.04, 0.172, -0.146), mats, "eyes")
		flick.rotation.z = s * 0.6
		var blush: MeshInstance3D = _part(head, "Blush" + side + "Mesh", _sphere(0.03), Vector3(s * 0.112, 0.085, -0.15), mats, "blush")
		blush.scale = Vector3(1.0, 0.6, 0.4)
		var ear: MeshInstance3D = _part(head, "Ear" + side + "Mesh", _sphere(0.035), Vector3(s * 0.178, 0.06, 0.0), mats, "skin")
		ear.scale = Vector3(0.5, 1.0, 0.8)
		var corner: MeshInstance3D = _part(head, "Smile" + side + "Mesh", _box(Vector3(0.024, 0.009, 0.016)),
				Vector3(s * 0.03, 0.078, -0.18), mats, "mouth")
		corner.rotation.z = s * 0.7
	_part(head, "MouthMesh", _box(Vector3(0.03, 0.01, 0.02)), Vector3(0.0, 0.072, -0.184), mats, "mouth")


static func _build_arm(chest: Node3D, side: String, s: float, mats: Dictionary) -> void:
	var upper: Node3D = _joint(chest, side + "UpperArm", Vector3(s * 0.19, 0.12, 0.0))
	upper.rotation.z = s * ARM_OUT
	_part(upper, side + "UpperArmMesh", _capsule(0.04, UPPER_ARM), Vector3(0.0, -UPPER_ARM * 0.5, 0.0), mats, "skin")
	# Oversized hoodie sleeve.
	_part(upper, side + "SleeveMesh", _capsule(0.068, 0.17), Vector3(0.0, -0.085, 0.0), mats, "shirt")
	var lower: Node3D = _joint(upper, side + "LowerArm", Vector3(0.0, -UPPER_ARM, 0.0))
	lower.rotation.x = FOREARM_BEND
	_part(lower, side + "LowerArmMesh", _capsule(0.034, LOWER_ARM), Vector3(0.0, -LOWER_ARM * 0.5, 0.0), mats, "skin")
	_part(lower, side + "WristbandMesh", _torus(0.03, 0.05), Vector3(0.0, -0.165, 0.0), mats, "band")
	var hand: Node3D = _joint(lower, side + "Hand", Vector3(0.0, -LOWER_ARM, 0.0))
	_part(hand, side + "HandMesh", _sphere(0.042), Vector3(0.0, -0.01, 0.0), mats, "skin")


## foot_z: ankle offset from the hips along Z (negative = forward, toward the nose).
static func _build_leg(hips: Node3D, side: String, s: float, foot_z: float, mats: Dictionary) -> void:
	var pose: Vector2 = _leg_pose(foot_z)
	var upper: Node3D = _joint(hips, side + "UpperLeg", Vector3(s * HIP_SPREAD, 0.0, 0.0))
	upper.rotation.x = pose.x
	_part(upper, side + "UpperLegMesh", _capsule(0.06, UPPER_LEG), Vector3(0.0, -UPPER_LEG * 0.5, 0.0), mats, "pants")
	# Cargo shorts: a hem band and a patch pocket on the thigh.
	_part(upper, side + "ShortsHemMesh", _cylinder(0.066, 0.05), Vector3(0.0, -UPPER_LEG + 0.035, 0.0), mats, "pants_dark")
	_part(upper, side + "CargoPocketMesh", _box(Vector3(0.05, 0.07, 0.02)), Vector3(0.0, -0.15, -0.062), mats, "pants_dark")
	var lower: Node3D = _joint(upper, side + "LowerLeg", Vector3(0.0, -UPPER_LEG, 0.0))
	lower.rotation.x = pose.y - pose.x
	# Tall striped sock over the whole shin.
	_part(lower, side + "LowerLegMesh", _capsule(0.048, LOWER_LEG), Vector3(0.0, -LOWER_LEG * 0.5, 0.0), mats, "sock")
	for j: int in 3:
		_part(lower, side + "SockStripe%dMesh" % j, _torus(0.044, 0.058), Vector3(0.0, -0.02 - 0.03 * float(j), 0.0),
				mats, "sock_stripe")
	var foot: Node3D = _joint(lower, side + "Foot", Vector3(0.0, -LOWER_LEG, 0.0))
	foot.rotation.x = -pose.y
	# Chunky skate shoe: coral upper, mint toe cap, thick white sole. The sole bottom sits at -ANKLE_HEIGHT (flat on
	# the ground).
	# A capsule lying along Z: rounded toe and heel, ANKLE_HEIGHT tall.
	var shoe: MeshInstance3D = _part(foot, side + "ShoeMesh", _capsule(ANKLE_HEIGHT * 0.5, 0.27),
			Vector3(0.0, -ANKLE_HEIGHT * 0.5, -0.05), mats, "shoes")
	shoe.rotation.x = PI * 0.5
	_part(foot, side + "SoleMesh", _box(Vector3(0.14, 0.03, 0.29)), Vector3(0.0, -0.105, -0.05), mats, "sole")
	var toe: MeshInstance3D = _part(foot, side + "ToeCapMesh", _sphere(0.06), Vector3(0.0, -0.06, -0.14), mats, "toe")
	toe.scale = Vector3(1.0, 0.8, 1.0)


## Returns Vector2(thigh angle, shin world angle) for a flat leg pose with the ankle ANKLE_HEIGHT above the
## ground and foot_z offset from the hip. Knee bends forward (toward -Z), as a real knee does.
static func _leg_pose(foot_z: float) -> Vector2:
	var drop: float = HIP_HEIGHT - ANKLE_HEIGHT
	var dist: float = sqrt(drop * drop + foot_z * foot_z)
	var reach: float = minf(dist, UPPER_LEG + LOWER_LEG - 0.0005)
	# Vectors are (y, z) offsets from the hip joint.
	var ankle: Vector2 = Vector2(-drop, foot_z) * (reach / dist)
	var psi: float = _leg_angle_of(ankle)
	var cos_knee: float = clampf(
		(UPPER_LEG * UPPER_LEG + reach * reach - LOWER_LEG * LOWER_LEG) / (2.0 * UPPER_LEG * reach), -1.0, 1.0)
	var thigh: float = psi + acos(cos_knee)
	var knee: Vector2 = Vector2(-cos(thigh), -sin(thigh)) * UPPER_LEG
	var shin: float = _leg_angle_of(ankle - knee)
	return Vector2(thigh, shin)


## Rotation.x angle of a (y, z) vector, so that rotation.x = angle swings the leg's down vector onto it.
static func _leg_angle_of(v: Vector2) -> float:
	return atan2(-v.y, -v.x)


static func _build_truck(board: Node3D, truck_name: String, z: float, mats: Dictionary) -> void:
	var truck: Node3D = _joint(board, "Truck_" + truck_name, Vector3(0.0, 0.0, z))
	_part(truck, "TruckBaseMesh", _box(Vector3(0.15, 0.02, 0.07)), Vector3(0.0, 0.095, 0.0), mats, "trucks")
	_part(truck, "TruckHangerMesh", _box(Vector3(0.2, 0.034, 0.03)), Vector3(0.0, 0.07, 0.0), mats, "trucks")
	var axle: MeshInstance3D = _part(truck, "TruckAxleMesh", _cylinder(0.009, 0.26), Vector3(0.0, 0.045, 0.0), mats, "trucks")
	axle.rotation.z = PI * 0.5


## Fat wheel (bottom at y = 0) with a light hub on each face.
static func _build_wheel(board: Node3D, wheel_name: String, x: float, z: float, mats: Dictionary) -> void:
	var wheel: MeshInstance3D = _part(board, wheel_name, _cylinder(0.045, 0.03), Vector3(x, 0.045, z), mats, "wheels")
	wheel.rotation.z = PI * 0.5
	var hub: MeshInstance3D = _part(board, wheel_name + "_Hub", _cylinder(0.02, 0.036), Vector3(x, 0.045, z), mats, "hubs")
	hub.rotation.z = PI * 0.5


static func _materials(palette: Dictionary, defaults: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in defaults.keys():
		var given: Color = palette.get(key, defaults[key])
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = given
		mat.roughness = 0.7
		out[key] = mat
	return out


static func _joint(parent: Node3D, joint_name: String, pivot: Vector3) -> Node3D:
	var joint: Node3D = Node3D.new()
	joint.name = joint_name
	joint.position = pivot
	parent.add_child(joint)
	return joint


static func _part(parent: Node3D, part_name: String, mesh: Mesh, offset: Vector3, mats: Dictionary, key: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.position = offset
	mi.material_override = mats[key]
	mi.set_meta("palette", key)
	parent.add_child(mi)
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	return m


static func _sphere(radius: float) -> SphereMesh:
	var m: SphereMesh = SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 24
	m.rings = 12
	return m


## Upper half of a sphere of this radius (dome), centred on its origin. Godot's hemisphere spans y 0..height,
## so height = radius gives a dome whose top is at the radius.
static func _dome(radius: float) -> SphereMesh:
	var m: SphereMesh = _sphere(radius)
	m.is_hemisphere = true
	m.height = radius
	return m


static func _torus(inner_radius: float, outer_radius: float) -> TorusMesh:
	var m: TorusMesh = TorusMesh.new()
	m.inner_radius = inner_radius
	m.outer_radius = outer_radius
	return m


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m: CapsuleMesh = CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 20
	m.rings = 6
	return m


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 16
	return m


## Tapered tube through the points, radius per point. Built in place (no mesh transform) so its bounds are tight.
static func _tube(points: PackedVector3Array, radii: PackedFloat32Array, sides: int = 12) -> ArrayMesh:
	var n: int = points.size()
	var rings: Array = []
	var normals: Array = []
	for i: int in n:
		var tangent: Vector3 = (points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side: Vector3 = tangent.cross(Vector3.RIGHT)
		if side.length() < 0.001:
			side = tangent.cross(Vector3.UP)
		side = side.normalized()
		var up: Vector3 = side.cross(tangent).normalized()
		var ring: PackedVector3Array = PackedVector3Array()
		var ring_normals: Array = []
		for k: int in sides:
			var a: float = TAU * float(k) / float(sides)
			var dir: Vector3 = side * cos(a) + up * sin(a)
			ring.append(points[i] + dir * radii[i])
			ring_normals.append(dir)
		rings.append(ring)
		normals.append(ring_normals)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in n - 1:
		for k: int in sides:
			var k2: int = (k + 1) % sides
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k2]
			var c: Vector3 = rings[i + 1][k]
			var d: Vector3 = rings[i + 1][k2]
			var na: Vector3 = normals[i][k]
			var nb: Vector3 = normals[i][k2]
			var nc: Vector3 = normals[i + 1][k]
			var nd: Vector3 = normals[i + 1][k2]
			st.set_normal(na)
			st.add_vertex(a)
			st.set_normal(nb)
			st.add_vertex(b)
			st.set_normal(nc)
			st.add_vertex(c)
			st.set_normal(nb)
			st.add_vertex(b)
			st.set_normal(nd)
			st.add_vertex(d)
			st.set_normal(nc)
			st.add_vertex(c)
	return st.commit()
