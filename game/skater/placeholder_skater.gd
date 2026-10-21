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


static func build_body(palette: Dictionary = {}) -> Node3D:
	var mats: Dictionary = SkaterParts.materials(palette, _body_defaults())
	var root: Node3D = Node3D.new()
	root.name = "SkaterBody"

	var hips: Node3D = SkaterParts.joint(root, "Hips", Vector3(0.0, HIP_HEIGHT, 0.0))
	var pelvis: MeshInstance3D = SkaterParts.part(hips, "HipsMesh", SkaterParts.sphere(0.125), Vector3.ZERO, mats, "pants")
	pelvis.scale = Vector3(1.15, 0.72, 0.95)

	var spine: Node3D = SkaterParts.joint(hips, "Spine", Vector3(0.0, 0.08, 0.0))
	var chest: Node3D = SkaterParts.joint(spine, "Chest", Vector3(0.0, 0.14, 0.0))
	AnimeOutfit.build_torso(spine, chest, mats)

	var neck: Node3D = SkaterParts.joint(chest, "Neck", Vector3(0.0, 0.20, 0.0))
	SkaterParts.part(neck, "NeckMesh", SkaterParts.cylinder(0.05, 0.1), Vector3(0.0, -0.01, 0.0), mats, "skin")
	var head: Node3D = SkaterParts.joint(neck, "Head", Vector3(0.0, 0.04, 0.0))
	AnimeHead.build(head, mats)

	_build_arm(chest, "Left", -1.0, mats)
	_build_arm(chest, "Right", 1.0, mats)
	_build_leg(hips, "Left", -1.0, -FOOT_Z, mats)
	_build_leg(hips, "Right", 1.0, FOOT_Z, mats)
	return root


static func build_board(palette: Dictionary = {}) -> Node3D:
	var mats: Dictionary = SkaterParts.materials(palette, _board_defaults())
	var root: Node3D = Node3D.new()
	root.name = "Skateboard"

	AnimeBoard.build_deck(root, mats)

	AnimeBoard.build_truck(root, "Front", -0.28, mats)
	AnimeBoard.build_truck(root, "Back", 0.28, mats)
	AnimeBoard.build_wheel(root, "Wheel_FL", -0.12, -0.28, mats)
	AnimeBoard.build_wheel(root, "Wheel_FR", 0.12, -0.28, mats)
	AnimeBoard.build_wheel(root, "Wheel_BL", -0.12, 0.28, mats)
	AnimeBoard.build_wheel(root, "Wheel_BR", 0.12, 0.28, mats)
	return root


static func _body_defaults() -> Dictionary:
	return {
		"skin": Color(0.78, 0.67, 0.58),
		"nose": Color(0.95, 0.68, 0.6),
		"hair": Color(0.18, 0.68, 0.66),
		"hair_dark": Color(0.08, 0.46, 0.52),
		"scrunchie": Color(0.9, 0.3, 0.6),
		"eyes": Color(0.14, 0.09, 0.16),
		"iris": Color(0.04, 0.36, 0.42),
		"iris_light": Color(0.25, 0.72, 0.68),
		"eye_white": Color(1.0, 1.0, 1.0),
		"mouth": Color(0.85, 0.3, 0.36),
		"blush": Color(1.0, 0.55, 0.62),
		"shirt": Color(0.68, 0.6, 0.94),
		"shirt_dark": Color(0.45, 0.36, 0.78),
		"trim": Color(0.9, 0.88, 0.82),
		"shell": Color(0.9, 0.72, 0.62),
		"band": Color(0.3, 0.8, 0.72),
		"pants": Color(0.86, 0.7, 0.5),
		"pants_dark": Color(0.65, 0.42, 0.22),
		"sock": Color(0.9, 0.88, 0.85),
		"sock_stripe": Color(0.85, 0.3, 0.55),
		"shoes": Color(0.85, 0.32, 0.4),
		"sole": Color(0.9, 0.88, 0.85),
		"toe": Color(0.3, 0.8, 0.72),
	}


static func _board_defaults() -> Dictionary:
	return {
		"grip": Color(0.62, 0.55, 0.46),
		"deck": Color(0.2, 0.7, 0.75),
		"deck_alt": Color(0.9, 0.42, 0.4),
		"deck_sun": Color(0.95, 0.8, 0.45),
		"wheels": Color(0.5, 0.85, 0.72),
		"hubs": Color(0.9, 0.8, 0.85),
		"trucks": Color(0.7, 0.68, 0.8),
	}

static func _build_arm(chest: Node3D, side: String, s: float, mats: Dictionary) -> void:
	var upper: Node3D = SkaterParts.joint(chest, side + "UpperArm", Vector3(s * 0.19, 0.12, 0.0))
	upper.rotation.z = s * ARM_OUT
	SkaterParts.part(upper, side + "UpperArmMesh", SkaterParts.capsule(0.04, UPPER_ARM), Vector3(0.0, -UPPER_ARM * 0.5, 0.0), mats, "skin")
	AnimeOutfit.build_sleeve(upper, side, mats)
	var lower: Node3D = SkaterParts.joint(upper, side + "LowerArm", Vector3(0.0, -UPPER_ARM, 0.0))
	lower.rotation.x = FOREARM_BEND
	SkaterParts.part(lower, side + "LowerArmMesh", SkaterParts.capsule(0.034, LOWER_ARM), Vector3(0.0, -LOWER_ARM * 0.5, 0.0), mats, "skin")
	AnimeOutfit.build_wristband(lower, side, mats)
	var hand: Node3D = SkaterParts.joint(lower, side + "Hand", Vector3(0.0, -LOWER_ARM, 0.0))
	SkaterParts.part(hand, side + "HandMesh", SkaterParts.sphere(0.042), Vector3(0.0, -0.01, 0.0), mats, "skin")


## foot_z: ankle offset from the hips along Z (negative = forward, toward the nose).
static func _build_leg(hips: Node3D, side: String, s: float, foot_z: float, mats: Dictionary) -> void:
	var pose: Vector2 = _leg_pose(foot_z)
	var upper: Node3D = SkaterParts.joint(hips, side + "UpperLeg", Vector3(s * HIP_SPREAD, 0.0, 0.0))
	upper.rotation.x = pose.x
	SkaterParts.part(upper, side + "UpperLegMesh", SkaterParts.capsule(0.06, UPPER_LEG), Vector3(0.0, -UPPER_LEG * 0.5, 0.0), mats, "pants")
	AnimeOutfit.build_shorts(upper, side, UPPER_LEG, mats)
	var lower: Node3D = SkaterParts.joint(upper, side + "LowerLeg", Vector3(0.0, -UPPER_LEG, 0.0))
	lower.rotation.x = pose.y - pose.x
	AnimeOutfit.build_sock(lower, side, LOWER_LEG, mats)
	var foot: Node3D = SkaterParts.joint(lower, side + "Foot", Vector3(0.0, -LOWER_LEG, 0.0))
	foot.rotation.x = -pose.y
	AnimeOutfit.build_shoe(foot, side, ANKLE_HEIGHT, mats)

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
