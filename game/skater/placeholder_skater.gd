class_name PlaceholderSkater
extends RefCounted
## Placeholder anime skater girl and surf-style skateboard, built in code from primitives (no imported assets).
## build_body(): a joint hierarchy named after SkeletonProfileHumanoid bones. Faces -Z, feet at y = 0.
## The caller stands it on the deck with body.position.y = DECK_TOP_Y. Regular stance: left foot forward
## (-Z). Leg poses come from a small two-bone solve so the shoes stay flat on the ground.
## build_board(): deck long along Z, nose at -Z, wheel bottoms at y = 0.
## Every MeshInstance3D has meta "palette" (its palette key) and its StandardMaterial3D in material_override,
## so the toon pass can walk the meshes and swap materials.
## Look: young adult (early 20s) surf-skater girl, about 6.5 heads tall. Sun-bleached golden blonde hair in a high
## ponytail with bangs, a hair tie and a flower clip, big blue anime eyes, light tan skin. Coral open rash guard over a
## teal sport bikini top, knee-length teal board shorts with a side stripe, mint-teal wristbands, striped crew socks and
## real skate shoes (white and coral with a teal toe cap, gum sole). Board: sand grip with aqua and coral surf stripes
## and pastel mint wheels.
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
	SkaterParts.part(neck, "NeckMesh", SkaterParts.cylinder(0.04, 0.13), Vector3(0.0, -0.005, 0.0), mats, "skin")
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
		"skin": Color(0.9, 0.69, 0.52),
		"nose": Color(0.82, 0.52, 0.4),
		"hair": Color(0.94, 0.78, 0.4),
		"hair_dark": Color(0.76, 0.55, 0.25),
		"hair_light": Color(0.99, 0.9, 0.66),
		"hair_root": Color(0.5, 0.34, 0.15),
		"hair_tie": Color(1.0, 0.42, 0.36),
		"flower": Color(1.0, 0.97, 0.92),
		"flower_center": Color(1.0, 0.8, 0.2),
		"brow": Color(0.62, 0.43, 0.2),
		"eyes": Color(0.2, 0.12, 0.1),
		"iris": Color(0.1, 0.45, 0.85),
		"iris_light": Color(0.45, 0.85, 0.97),
		"iris_ring": Color(0.03, 0.17, 0.4),
		"eye_white": Color(1.0, 1.0, 1.0),
		"mouth": Color(0.9, 0.38, 0.4),
		"blush": Color(1.0, 0.6, 0.55),
		"shirt": Color(1.0, 0.48, 0.3),
		"shirt_dark": Color(0.86, 0.34, 0.24),
		"trim": Color(1.0, 0.97, 0.9),
		"top": Color(0.08, 0.72, 0.74),
		"top_trim": Color(1.0, 0.97, 0.9),
		"band": Color(0.1, 0.72, 0.74),
		"pants": Color(0.07, 0.46, 0.62),
		"pants_trim": Color(1.0, 0.48, 0.3),
		"short_stripe": Color(1.0, 0.97, 0.9),
		"sock": Color(0.97, 0.96, 0.92),
		"sock_stripe": Color(1.0, 0.48, 0.3),
		"sock_stripe2": Color(0.08, 0.72, 0.74),
		"shoes": Color(1.0, 0.46, 0.3),
		"shoe_panel": Color(0.98, 0.97, 0.93),
		"toe": Color(0.98, 0.97, 0.93),
		"collar": Color(0.06, 0.62, 0.68),
		"tongue": Color(0.98, 0.97, 0.93),
		"laces": Color(0.06, 0.4, 0.55),
		"stitch": Color(0.35, 0.25, 0.18),
		"foxing": Color(0.98, 0.97, 0.93),
		"sole": Color(0.72, 0.54, 0.34),
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
	SkaterParts.part(upper, side + "ShoulderMesh", SkaterParts.sphere(0.04), Vector3.ZERO, mats, "skin")
	SkaterParts.part(upper, side + "UpperArmMesh", _limb(PackedFloat32Array([0.0, -0.1, -0.19]), PackedFloat32Array([0.037, 0.034, 0.031])),
			Vector3.ZERO, mats, "skin")
	AnimeOutfit.build_sleeve(upper, side, mats)
	var lower: Node3D = SkaterParts.joint(upper, side + "LowerArm", Vector3(0.0, -UPPER_ARM, 0.0))
	lower.rotation.x = FOREARM_BEND
	SkaterParts.part(lower, side + "ElbowMesh", SkaterParts.sphere(0.032), Vector3.ZERO, mats, "skin")
	SkaterParts.part(lower, side + "LowerArmMesh", _limb(PackedFloat32Array([0.0, -0.09, -0.172]), PackedFloat32Array([0.031, 0.027, 0.022])),
			Vector3.ZERO, mats, "skin")
	AnimeOutfit.build_wristband(lower, side, mats)
	var hand: Node3D = SkaterParts.joint(lower, side + "Hand", Vector3(0.0, -LOWER_ARM, 0.0))
	SkaterParts.part(hand, side + "HandMesh", _hand_mesh(s), Vector3.ZERO, mats, "skin")


## Tapered capped limb tube down the Y axis: heights and radii per point.
static func _limb(ys: PackedFloat32Array, rs: PackedFloat32Array) -> ArrayMesh:
	var pts: PackedVector3Array = PackedVector3Array()
	for y: float in ys:
		pts.append(Vector3(0.0, y, 0.0))
	return SkaterParts.tube_capped(AnimeHead._smooth(pts, 3), AnimeHead._smooth_r(rs, 3), 16)


## Soft hand: a flattened palm, four rounded fingers and a thumb, merged into one mesh. Hangs along -Y.
static func _hand_mesh(s: float) -> ArrayMesh:
	var items: Array = []
	items.append([SkaterParts.sphere_small(0.028), Transform3D(Basis.from_scale(Vector3(0.95, 1.2, 0.6)), Vector3(0.0, -0.034, 0.0))])
	for i: int in 4:
		var x: float = (float(i) - 1.5) * 0.0145
		var len: float = 0.046 - 0.004 * absf(float(i) - 1.5)
		var tilt: Basis = Basis(Vector3.RIGHT, -0.18)
		items.append([SkaterParts.capsule_small(0.0078, len), Transform3D(tilt, Vector3(x, -0.07 - len * 0.35, -0.004))])
	var thumb_basis: Basis = Basis(Vector3.BACK, -s * 0.7) * Basis(Vector3.RIGHT, -0.2)
	items.append([SkaterParts.capsule_small(0.0088, 0.042), Transform3D(thumb_basis, Vector3(-s * 0.03, -0.045, -0.012))])
	return SkaterParts.merge(items)


## foot_z: ankle offset from the hips along Z (negative = forward, toward the nose).
static func _build_leg(hips: Node3D, side: String, s: float, foot_z: float, mats: Dictionary) -> void:
	var pose: Vector2 = _leg_pose(foot_z)
	var upper: Node3D = SkaterParts.joint(hips, side + "UpperLeg", Vector3(s * HIP_SPREAD, 0.0, 0.0))
	upper.rotation.x = pose.x
	AnimeOutfit.build_shorts(upper, side, UPPER_LEG, mats)
	var lower: Node3D = SkaterParts.joint(upper, side + "LowerLeg", Vector3(0.0, -UPPER_LEG, 0.0))
	lower.rotation.x = pose.y - pose.x
	AnimeOutfit.build_sock(lower, side, LOWER_LEG, mats)
	var foot: Node3D = SkaterParts.joint(lower, side + "Foot", Vector3(0.0, -LOWER_LEG, 0.0))
	foot.rotation.x = -pose.y
	AnimeOutfit.skate_shoe(foot, side, ANKLE_HEIGHT, mats)

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
