class_name PlaceholderSkater
extends RefCounted
## Placeholder cartoon kid skater and skateboard, built in code from primitives (no imported assets).
## build_body(): a joint hierarchy named after SkeletonProfileHumanoid bones. Faces -Z, feet at y = 0.
## The caller stands it on the deck with body.position.y = DECK_TOP_Y. Regular stance: left foot forward
## (-Z). Leg poses come from a small two-bone solve so the shoes stay flat on the ground.
## build_board(): deck long along Z, nose at -Z, wheel bottoms at y = 0.
## Every MeshInstance3D has meta "palette" (its palette key) and its StandardMaterial3D in material_override,
## so the toon pass can walk the meshes and swap materials.

const DECK_TOP_Y: float = 0.135
const HIP_HEIGHT: float = 0.62
const UPPER_LEG: float = 0.30
const LOWER_LEG: float = 0.22
const ANKLE_HEIGHT: float = 0.12
const HIP_SPREAD: float = 0.075
const FOOT_Z: float = 0.12
const ARM_OUT: float = 0.35
const FOREARM_BEND: float = 0.5


static func build_body(palette: Dictionary = {}) -> Node3D:
	var mats: Dictionary = _materials(palette, _body_defaults())
	var root: Node3D = Node3D.new()
	root.name = "SkaterBody"

	var hips: Node3D = _joint(root, "Hips", Vector3(0.0, HIP_HEIGHT, 0.0))
	_part(hips, "HipsMesh", _box(Vector3(0.26, 0.12, 0.18)), Vector3.ZERO, mats, "pants")

	var spine: Node3D = _joint(hips, "Spine", Vector3(0.0, 0.08, 0.0))
	_part(spine, "SpineMesh", _capsule(0.13, 0.18), Vector3.ZERO, mats, "shirt")
	var chest: Node3D = _joint(spine, "Chest", Vector3(0.0, 0.14, 0.0))
	_part(chest, "ChestMesh", _capsule(0.15, 0.26), Vector3(0.0, 0.04, 0.0), mats, "shirt")
	var neck: Node3D = _joint(chest, "Neck", Vector3(0.0, 0.20, 0.0))
	_part(neck, "NeckMesh", _cylinder(0.05, 0.08), Vector3(0.0, 0.02, 0.0), mats, "skin")
	var head: Node3D = _joint(neck, "Head", Vector3(0.0, 0.04, 0.0))
	_part(head, "HeadMesh", _sphere(0.14), Vector3(0.0, 0.11, 0.0), mats, "skin")
	_part(head, "HelmetMesh", _hemisphere(0.16), Vector3(0.0, 0.10, 0.0), mats, "helmet")
	_part(head, "EyeLeftMesh", _sphere(0.035), Vector3(-0.055, 0.07, -0.13), mats, "eyes")
	_part(head, "EyeRightMesh", _sphere(0.035), Vector3(0.055, 0.07, -0.13), mats, "eyes")

	_build_arm(chest, "Left", -1.0, mats)
	_build_arm(chest, "Right", 1.0, mats)
	_build_leg(hips, "Left", -1.0, -FOOT_Z, mats)
	_build_leg(hips, "Right", 1.0, FOOT_Z, mats)
	return root


static func build_board(palette: Dictionary = {}) -> Node3D:
	var mats: Dictionary = _materials(palette, _board_defaults())
	var root: Node3D = Node3D.new()
	root.name = "Skateboard"

	_part(root, "Deck", _box(Vector3(0.22, 0.03, 0.8)), Vector3(0.0, 0.12, 0.0), mats, "deck")
	var nose: MeshInstance3D = _part(root, "NoseKick", _box(Vector3(0.22, 0.02, 0.1)), Vector3(0.0, 0.14, -0.36), mats, "deck")
	nose.rotation.x = 0.25
	var tail: MeshInstance3D = _part(root, "TailKick", _box(Vector3(0.22, 0.02, 0.1)), Vector3(0.0, 0.14, 0.36), mats, "deck")
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
		"pants": Color(0.22, 0.45, 1.0),
		"shoes": Color(0.98, 0.98, 0.95),
		"helmet": Color(1.0, 0.85, 0.1),
		"eyes": Color(0.08, 0.08, 0.12),
	}


static func _board_defaults() -> Dictionary:
	return {
		"deck": Color(0.2, 0.85, 0.45),
		"wheels": Color(1.0, 0.55, 0.1),
		"trucks": Color(0.75, 0.78, 0.84),
	}


static func _build_arm(chest: Node3D, side: String, s: float, mats: Dictionary) -> void:
	var upper: Node3D = _joint(chest, side + "UpperArm", Vector3(s * 0.19, 0.12, 0.0))
	upper.rotation.z = s * ARM_OUT
	_part(upper, side + "UpperArmMesh", _capsule(0.045, 0.18), Vector3(0.0, -0.09, 0.0), mats, "shirt")
	var lower: Node3D = _joint(upper, side + "LowerArm", Vector3(0.0, -0.18, 0.0))
	lower.rotation.x = FOREARM_BEND
	_part(lower, side + "LowerArmMesh", _capsule(0.04, 0.16), Vector3(0.0, -0.08, 0.0), mats, "shirt")
	var hand: Node3D = _joint(lower, side + "Hand", Vector3(0.0, -0.16, 0.0))
	_part(hand, side + "HandMesh", _sphere(0.05), Vector3.ZERO, mats, "skin")


## foot_z: ankle offset from the hips along Z (negative = forward, toward the nose).
static func _build_leg(hips: Node3D, side: String, s: float, foot_z: float, mats: Dictionary) -> void:
	var pose: Vector2 = _leg_pose(foot_z)
	var upper: Node3D = _joint(hips, side + "UpperLeg", Vector3(s * HIP_SPREAD, 0.0, 0.0))
	upper.rotation.x = pose.x
	_part(upper, side + "UpperLegMesh", _capsule(0.065, UPPER_LEG), Vector3(0.0, -UPPER_LEG * 0.5, 0.0), mats, "pants")
	var lower: Node3D = _joint(upper, side + "LowerLeg", Vector3(0.0, -UPPER_LEG, 0.0))
	lower.rotation.x = pose.y - pose.x
	_part(lower, side + "LowerLegMesh", _capsule(0.058, LOWER_LEG), Vector3(0.0, -LOWER_LEG * 0.5, 0.0), mats, "pants")
	var foot: Node3D = _joint(lower, side + "Foot", Vector3(0.0, -LOWER_LEG, 0.0))
	foot.rotation.x = -pose.y
	_part(foot, side + "ShoeMesh", _box(Vector3(0.12, ANKLE_HEIGHT, 0.26)), Vector3(0.0, -ANKLE_HEIGHT * 0.5, -0.05), mats, "shoes")


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
	_part(truck, "TruckBaseMesh", _box(Vector3(0.2, 0.02, 0.05)), Vector3(0.0, 0.095, 0.0), mats, "trucks")
	var axle: MeshInstance3D = _part(truck, "TruckAxleMesh", _cylinder(0.008, 0.26), Vector3(0.0, 0.035, 0.0), mats, "trucks")
	axle.rotation.z = PI * 0.5


static func _build_wheel(board: Node3D, wheel_name: String, x: float, z: float, mats: Dictionary) -> void:
	var wheel: MeshInstance3D = _part(board, wheel_name, _cylinder(0.035, 0.025), Vector3(x, 0.035, z), mats, "wheels")
	wheel.rotation.z = PI * 0.5


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


static func _hemisphere(radius: float) -> SphereMesh:
	var m: SphereMesh = _sphere(radius)
	m.is_hemisphere = true
	m.height = radius  # Godot's hemisphere keeps the full-height param; radius gives a dome of that radius
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
