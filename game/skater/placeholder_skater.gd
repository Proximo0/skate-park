class_name PlaceholderSkater
extends RefCounted
## Placeholder cartoon kid skater and skateboard, built in code from primitives (no imported assets).
## build_body(): a joint hierarchy named after SkeletonProfileHumanoid bones. Faces -Z, feet at y = 0.
## The caller stands it on the deck with body.position.y = DECK_TOP_Y. Regular stance: left foot forward
## (-Z). Leg poses come from a small two-bone solve so the shoes stay flat on the ground.
## build_board(): deck long along Z, nose at -Z, wheel bottoms at y = 0.
## Every MeshInstance3D has meta "palette" (its palette key) and its StandardMaterial3D in material_override,
## so the toon pass can walk the meshes and swap materials.
## Look: big round head with a helmet (peak and racing stripe), googly eyes, pads, chunky sneakers, fat wheels.
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


static func build_body(palette: Dictionary = {}) -> Node3D:
	var mats: Dictionary = _materials(palette, _body_defaults())
	var root: Node3D = Node3D.new()
	root.name = "SkaterBody"

	var hips: Node3D = _joint(root, "Hips", Vector3(0.0, HIP_HEIGHT, 0.0))
	var pelvis: MeshInstance3D = _part(hips, "HipsMesh", _sphere(0.125), Vector3.ZERO, mats, "pants")
	pelvis.scale = Vector3(1.1, 0.72, 0.92)

	var spine: Node3D = _joint(hips, "Spine", Vector3(0.0, 0.08, 0.0))
	var waist: MeshInstance3D = _part(spine, "SpineMesh", _sphere(0.12), Vector3.ZERO, mats, "shirt")
	waist.scale = Vector3(1.0, 0.85, 0.82)
	var chest: Node3D = _joint(spine, "Chest", Vector3(0.0, 0.14, 0.0))
	var torso: MeshInstance3D = _part(chest, "ChestMesh", _sphere(0.15), Vector3(0.0, 0.04, 0.0), mats, "shirt")
	torso.scale = Vector3(1.05, 1.15, 0.85)
	var stripe: MeshInstance3D = _part(chest, "ShirtStripeMesh", _torus(0.135, 0.158), Vector3(0.0, -0.02, 0.0), mats, "trim")
	stripe.scale = Vector3(1.05, 1.0, 0.85)
	var neck: Node3D = _joint(chest, "Neck", Vector3(0.0, 0.20, 0.0))
	_part(neck, "NeckMesh", _cylinder(0.055, 0.1), Vector3(0.0, -0.01, 0.0), mats, "skin")
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

	# Dark grip tape on top (the deck top stays at DECK_TOP_Y), a bright colour band on the sides.
	_part(root, "Deck", _box(Vector3(0.22, 0.03, 0.8)), Vector3(0.0, 0.12, 0.0), mats, "grip")
	_part(root, "DeckStripe", _box(Vector3(0.226, 0.016, 0.66)), Vector3(0.0, 0.125, 0.0), mats, "deck")
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
		"skin": Color(1.0, 0.82, 0.66),
		"shirt": Color(1.0, 0.35, 0.3),
		"trim": Color(0.98, 0.98, 0.95),
		"pants": Color(0.22, 0.45, 1.0),
		"shoes": Color(0.6, 0.35, 1.0),
		"sole": Color(0.98, 0.98, 0.95),
		"toe": Color(1.0, 0.85, 0.2),
		"pads": Color(0.2, 0.85, 1.0),
		"glove": Color(0.98, 0.98, 0.95),
		"helmet": Color(1.0, 0.85, 0.1),
		"helmet_stripe": Color(1.0, 0.35, 0.3),
		"eyes": Color(0.08, 0.08, 0.12),
		"eye_white": Color(0.98, 0.98, 0.98),
		"mouth": Color(0.6, 0.15, 0.18),
		"blush": Color(1.0, 0.5, 0.55),
	}


static func _board_defaults() -> Dictionary:
	return {
		"grip": Color(0.3, 0.31, 0.38),
		"deck": Color(0.2, 0.85, 0.45),
		"wheels": Color(1.0, 0.55, 0.1),
		"hubs": Color(1.0, 0.95, 0.78),
		"trucks": Color(0.9, 0.92, 0.96),
	}


static func _build_head_parts(head: Node3D, mats: Dictionary) -> void:
	_part(head, "HeadMesh", _sphere(0.18), Vector3(0.0, 0.13, 0.0), mats, "skin")
	# Helmet: a dome above the eyes, a narrow racing stripe over the top and a peak at the front.
	var helmet: MeshInstance3D = _part(head, "HelmetMesh", _dome(0.2), Vector3(0.0, 0.19, 0.0), mats, "helmet")
	helmet.scale = Vector3(1.0, 0.72, 1.0)
	var racing: MeshInstance3D = _part(head, "HelmetStripeMesh", _dome(0.2), Vector3(0.0, 0.19, 0.0), mats, "helmet_stripe")
	racing.scale = Vector3(0.16, 0.74, 1.02)
	var visor: MeshInstance3D = _part(head, "VisorMesh", _sphere(0.12), Vector3(0.0, 0.2, -0.2), mats, "helmet")
	visor.scale = Vector3(1.0, 0.16, 0.7)
	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var x: float = s * 0.068
		_part(head, "Eye" + side + "Mesh", _sphere(0.042), Vector3(x, 0.135, -0.158), mats, "eye_white")
		_part(head, "Pupil" + side + "Mesh", _sphere(0.024), Vector3(x, 0.135, -0.19), mats, "eyes")
		_part(head, "EyeShine" + side + "Mesh", _sphere(0.008), Vector3(x + s * 0.01, 0.145, -0.205), mats, "eye_white")
		var blush: MeshInstance3D = _part(head, "Blush" + side + "Mesh", _sphere(0.03), Vector3(s * 0.11, 0.095, -0.135), mats, "blush")
		blush.scale = Vector3(1.0, 0.6, 0.5)
		var ear: MeshInstance3D = _part(head, "Ear" + side + "Mesh", _sphere(0.035), Vector3(s * 0.168, 0.06, 0.0), mats, "skin")
		ear.scale = Vector3(0.5, 1.0, 0.8)
		var corner: MeshInstance3D = _part(head, "Smile" + side + "Mesh", _box(Vector3(0.03, 0.011, 0.02)), Vector3(s * 0.045, 0.088, -0.163), mats, "mouth")
		corner.rotation.z = s * 0.7
	_part(head, "MouthMesh", _box(Vector3(0.05, 0.011, 0.02)), Vector3(0.0, 0.074, -0.17), mats, "mouth")


static func _build_arm(chest: Node3D, side: String, s: float, mats: Dictionary) -> void:
	var upper: Node3D = _joint(chest, side + "UpperArm", Vector3(s * 0.19, 0.12, 0.0))
	upper.rotation.z = s * ARM_OUT
	_part(upper, side + "UpperArmMesh", _capsule(0.045, UPPER_ARM), Vector3(0.0, -UPPER_ARM * 0.5, 0.0), mats, "skin")
	_part(upper, side + "SleeveMesh", _capsule(0.06, 0.13), Vector3(0.0, -0.04, 0.0), mats, "shirt")
	var lower: Node3D = _joint(upper, side + "LowerArm", Vector3(0.0, -UPPER_ARM, 0.0))
	lower.rotation.x = FOREARM_BEND
	_part(lower, side + "LowerArmMesh", _capsule(0.042, LOWER_ARM), Vector3(0.0, -LOWER_ARM * 0.5, 0.0), mats, "skin")
	var pad: MeshInstance3D = _part(lower, side + "ElbowPadMesh", _sphere(0.058), Vector3.ZERO, mats, "pads")
	pad.scale = Vector3(1.0, 0.9, 0.9)
	var hand: Node3D = _joint(lower, side + "Hand", Vector3(0.0, -LOWER_ARM, 0.0))
	var mitt: MeshInstance3D = _part(hand, side + "HandMesh", _sphere(0.065), Vector3(0.0, -0.01, 0.0), mats, "glove")
	mitt.scale = Vector3(0.95, 1.1, 1.0)


## foot_z: ankle offset from the hips along Z (negative = forward, toward the nose).
static func _build_leg(hips: Node3D, side: String, s: float, foot_z: float, mats: Dictionary) -> void:
	var pose: Vector2 = _leg_pose(foot_z)
	var upper: Node3D = _joint(hips, side + "UpperLeg", Vector3(s * HIP_SPREAD, 0.0, 0.0))
	upper.rotation.x = pose.x
	_part(upper, side + "UpperLegMesh", _capsule(0.07, UPPER_LEG), Vector3(0.0, -UPPER_LEG * 0.5, 0.0), mats, "pants")
	var lower: Node3D = _joint(upper, side + "LowerLeg", Vector3(0.0, -UPPER_LEG, 0.0))
	lower.rotation.x = pose.y - pose.x
	_part(lower, side + "LowerLegMesh", _capsule(0.06, LOWER_LEG), Vector3(0.0, -LOWER_LEG * 0.5, 0.0), mats, "pants")
	var knee: MeshInstance3D = _part(lower, side + "KneePadMesh", _sphere(0.07), Vector3(0.0, 0.0, -0.035), mats, "pads")
	knee.scale = Vector3(1.0, 0.85, 0.7)
	_part(lower, side + "CuffMesh", _cylinder(0.066, 0.04), Vector3(0.0, -0.2, 0.0), mats, "pants")
	var foot: Node3D = _joint(lower, side + "Foot", Vector3(0.0, -LOWER_LEG, 0.0))
	foot.rotation.x = -pose.y
	# Chunky sneaker: coloured upper, toe cap, white sole. The sole bottom sits at -ANKLE_HEIGHT (flat on the ground).
	_part(foot, side + "ShoeMesh", _box(Vector3(0.12, ANKLE_HEIGHT, 0.26)), Vector3(0.0, -ANKLE_HEIGHT * 0.5, -0.05), mats, "shoes")
	_part(foot, side + "SoleMesh", _box(Vector3(0.13, 0.025, 0.28)), Vector3(0.0, -0.1075, -0.05), mats, "sole")
	var toe: MeshInstance3D = _part(foot, side + "ToeCapMesh", _sphere(0.062), Vector3(0.0, -0.06, -0.13), mats, "toe")
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
