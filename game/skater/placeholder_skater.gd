class_name PlaceholderSkater
extends RefCounted
## Placeholder anime skaters (female or male) and surf-style skateboard, built in code from primitives (no imported
## assets).
## build_body(palette, options): a joint hierarchy named after SkeletonProfileHumanoid bones (the 17
## SkaterPoser.JOINTS; same skeleton constants for both bodies, so the poser, ragdoll and physics are shared). Faces
## -Z, feet at y = 0. The caller stands it on the deck with body.position.y = DECK_TOP_Y. Regular stance: left foot
## forward (-Z). Leg poses come from a small two-bone solve so the shoes stay flat on the ground.
## The skin: by default ("skin": "vrm") the finished VRoid anime model (VrmBody: lead_female.vrm / lead_male.vrm with
## its own face, hair and hands, retargeted onto the joints; docs/vrm_pipeline.md). It wears only the skate shoes from
## the Wardrobe (and the bikini skin texture, or its own clothes); no code head, hands or lofted garments are built.
## "skin": "houdini" is the older smooth featureless base body (AnimeHead face and code-built hands, and the seamless
## Houdini skinned body, HoudiniBody via SkinnedBody, driven by the joints); "skin": "code" builds the AnimeOutfit
## lofts instead. Either of those is split into regions; hair and every garment are separate layers chosen by
## `options` and built through the Wardrobe registry, which also hides the skin regions a garment fully covers. See
## Wardrobe for the garment contract.
## options: {"body": "female"|"male", "skin": "vrm"|"houdini"|"code", "hair": id, "top": id, "bottom": id, "socks": id,
## "shoes": id, "accessories": [ids]} using catalog mesh_builder ids; "" or "none" leaves a slot empty; missing keys come from
## Wardrobe.DEFAULTS (female: ponytail, bikini top and bottoms, striped crew socks, low vulc shoes, wristbands;
## male: messy hair, surf tee, board shorts, striped crew socks, low vulc shoes).
## build_board(): deck long along Z, nose at -Z, wheel bottoms at y = 0.
## Every MeshInstance3D has meta "palette" (its palette key) and its StandardMaterial3D in material_override,
## so the toon pass can walk the meshes and swap materials.
## Look: young adult (early 20s) surf skaters, about 1.62 m, slim and athletic with long legs. Her: sun-bleached
## golden blonde hair, big blue anime eyes, light tan skin. Him: broad shoulders, a lean flat chest, narrow hips, a
## square jaw, sharp amber eyes and dark messy hair. Board: sand grip with aqua and coral surf stripes and pastel
## mint wheels.
## Only the mesh parts and palette defaults are styling; the joints, pivots and bone lengths are the rig contract.

const DECK_TOP_Y: float = 0.135
const HIP_HEIGHT: float = 0.83
const UPPER_LEG: float = 0.40
const LOWER_LEG: float = 0.33
const ANKLE_HEIGHT: float = 0.12
const HIP_SPREAD: float = 0.08
const FOOT_Z: float = 0.12
const UPPER_ARM: float = 0.28
const LOWER_ARM: float = 0.25
const ARM_OUT: float = 0.3
const FOREARM_BEND: float = 0.5
const SPINE_UP: float = 0.13  ## Hips to Spine (waist)
const CHEST_UP: float = 0.12  ## Spine to Chest (under the bust)
const NECK_UP: float = 0.255  ## Chest to Neck (base of the neck)
const HEAD_UP: float = 0.065  ## Neck to Head (top of the slender neck, under the jaw)
const SHOULDER: Vector2 = Vector2(0.14, 0.195)  ## Chest to UpperArm: x out, y up
const HAND_SCALE: float = 1.18
## Default skin: "vrm" (the VRoid model, docs/vrm_pipeline.md), "houdini" (one seamless skinned mesh,
## docs/houdini_pipeline.md) or "code" (AnimeOutfit lofts).
const SKIN: String = "vrm"
## Live test cases of the lofted garments (they need the Houdini body); while any is alive, bodies built without a
## "skin" option get "houdini" instead of SKIN.
static var houdini_scopes: int = 0


static func build_body(palette: Dictionary = {}, options: Dictionary = {}) -> Node3D:
	var opts: Dictionary = Wardrobe.resolve(options)
	var body_type: String = str(opts["body"])
	var mats: Dictionary = SkaterParts.materials(palette, _body_defaults(body_type))
	var root: Node3D = Node3D.new()
	root.name = "SkaterBody"
	root.set_meta("body_type", body_type)
	var skin: String = str(opts.get("skin", "houdini" if houdini_scopes > 0 else SKIN))
	if skin == "vrm" and not ResourceLoader.exists(str(VrmBody.PATHS.get(body_type, ""))):
		skin = "houdini"
	var code_skin: bool = skin == "code"
	var rig: Dictionary = {"body_type": body_type, "code_skin": code_skin, "skin": skin}
	root.set_meta("skin", skin)

	var hips: Node3D = SkaterParts.joint(root, "Hips", Vector3(0.0, HIP_HEIGHT, 0.0))
	var spine: Node3D = SkaterParts.joint(hips, "Spine", Vector3(0.0, SPINE_UP, 0.0))
	var chest: Node3D = SkaterParts.joint(spine, "Chest", Vector3(0.0, CHEST_UP, 0.0))
	if code_skin:
		AnimeOutfit.build_torso(hips, spine, chest, mats, body_type)
	elif body_type != AnimeOutfit.MALE:
		AnimeOutfit.build_bust_pivots(chest, HIP_HEIGHT + SPINE_UP + CHEST_UP)
	var neck: Node3D = SkaterParts.joint(chest, "Neck", Vector3(0.0, NECK_UP, 0.0))
	if code_skin:
		AnimeOutfit.build_neck(neck, mats, body_type)
	var head: Node3D = SkaterParts.joint(neck, "Head", Vector3(0.0, HEAD_UP, 0.0))
	for n: Node3D in [hips, spine, chest, neck, head]:
		rig[str(n.name)] = n
	for side: Array in [["Left", -1.0, -FOOT_Z], ["Right", 1.0, FOOT_Z]]:
		_build_arm(chest, side[0], side[1], mats, body_type, rig)
		_build_leg(hips, side[0], side[1], side[2], mats, body_type, rig)
	for pivot: String in ["BodySway_BustL", "BodySway_BustR"]:
		var p: Node = chest.get_node_or_null(pivot)
		if p != null:
			rig[pivot] = p
	rig["rest_y"] = {"Hips": HIP_HEIGHT, "Spine": HIP_HEIGHT + SPINE_UP, "Chest": HIP_HEIGHT + SPINE_UP + CHEST_UP,
			"Neck": HIP_HEIGHT + SPINE_UP + CHEST_UP + NECK_UP, "Head": HIP_HEIGHT + SPINE_UP + CHEST_UP + NECK_UP + HEAD_UP}
	rig["lengths"] = {"upper_leg": UPPER_LEG, "lower_leg": LOWER_LEG, "upper_arm": UPPER_ARM, "lower_arm": LOWER_ARM,
			"ankle": ANKLE_HEIGHT}
	rig["sections"] = AnimeOutfit.joint_sections(body_type, rig["rest_y"], rig["lengths"])
	if skin == "vrm":
		_attach_vrm(root, body_type, mats)
	else:
		AnimeHead.build(head, mats, str(opts.get("hair", "")), body_type, rig)
		if not code_skin:
			_attach_skinned(root, body_type, mats)
	Wardrobe.dress(rig, opts, mats)
	return root


## The VRoid model under the body root, driven by the joints (VrmBody). The code hands are hidden (the model has its
## own); its face, hair and clothes or bikini are the model's.
static func _attach_vrm(root: Node3D, body_type: String, mats: Dictionary) -> void:
	for n: Node in root.find_children("*HandMesh", "MeshInstance3D", true, false):
		(n as MeshInstance3D).visible = false
	var vb: VrmBody = VrmBody.attach(root, body_type, mats)
	if vb == null:
		push_warning("PlaceholderSkater: the VRM model is missing (no body drawn); pass \"skin\": \"houdini\"")


## The Houdini skinned body under the body root, driven by the joints, drawn with the "skin" material.
static func _attach_skinned(root: Node3D, body_type: String, mats: Dictionary) -> void:
	var sb: SkinnedBody = SkinnedBody.attach(root, body_type, "houdini")
	if sb == null or sb.mesh_instance == null:
		push_warning("PlaceholderSkater: the Houdini base body is missing (no skin drawn); pass \"skin\": \"code\"")
		return
	var mi: MeshInstance3D = sb.mesh_instance
	mi.name = "SkinMesh"
	mi.material_override = mats["skin"]
	mi.set_meta("palette", "skin")
	mi.set_meta("skinned", true)


## The joint rig of a built body (every joint, sway pivot and HeadModel by name, plus the section data), the same
## Dictionary garment builders receive. For tools and tests.
static func rig_of(body: Node3D) -> Dictionary:
	var body_type: String = str(body.get_meta("body_type", "female"))
	var rig: Dictionary = {"body_type": body_type}
	for n: Node in body.find_children("*", "Node3D", true, false):
		if not (n is MeshInstance3D):
			rig[str(n.name)] = n
	rig["rest_y"] = {"Hips": HIP_HEIGHT, "Spine": HIP_HEIGHT + SPINE_UP, "Chest": HIP_HEIGHT + SPINE_UP + CHEST_UP,
			"Neck": HIP_HEIGHT + SPINE_UP + CHEST_UP + NECK_UP, "Head": HIP_HEIGHT + SPINE_UP + CHEST_UP + NECK_UP + HEAD_UP}
	rig["lengths"] = {"upper_leg": UPPER_LEG, "lower_leg": LOWER_LEG, "upper_arm": UPPER_ARM, "lower_arm": LOWER_ARM,
			"ankle": ANKLE_HEIGHT}
	rig["sections"] = AnimeOutfit.joint_sections(body_type, rig["rest_y"], rig["lengths"])
	return rig


static func build_board(palette: Dictionary = {}, options: Dictionary = {}) -> Node3D:
	var mats: Dictionary = SkaterParts.materials(palette, _board_defaults())
	var root: Node3D = Node3D.new()
	root.name = "Skateboard"

	var deck: String = str(options.get("deck", "popsicle"))
	var truck_opts: Dictionary = {"truck": str(options.get("truck", "standard")), "wheel": str(options.get("wheel", "street"))}
	AnimeBoard.build_deck(root, mats, deck, str(options.get("graphic", "sunset")))

	var tz: float = AnimeBoard.TRUCK_Z
	var wx: float = AnimeBoard.WHEEL_X
	var wheel: String = str(truck_opts["wheel"])
	AnimeBoard.build_truck(root, "Front", -tz, mats, truck_opts)
	AnimeBoard.build_truck(root, "Back", tz, mats, truck_opts)
	AnimeBoard.build_wheel(root, "Wheel_FL", -wx, -tz, mats, wheel)
	AnimeBoard.build_wheel(root, "Wheel_FR", wx, -tz, mats, wheel)
	AnimeBoard.build_wheel(root, "Wheel_BL", -wx, tz, mats, wheel)
	AnimeBoard.build_wheel(root, "Wheel_BR", wx, tz, mats, wheel)
	AnimeBoard.set_deck("popsicle")  # the static shape queries (top_y ...) go back to the default deck
	return root


## Palette defaults of each body. Head and hair keys are AnimeHead.COLORS; shoe keys are the Lagoon colourway
## (SkateShoe.PRESETS).
static func _body_defaults(body_type: String = "female") -> Dictionary:
	var d: Dictionary = {
		"skin": Color(0.9, 0.69, 0.52),
		"nose": Color(0.82, 0.52, 0.4),
		"hair": Color(0.94, 0.78, 0.4),
		"hair_dark": Color(0.76, 0.55, 0.25),
		"hair_light": Color(0.99, 0.9, 0.66),
		"acc_cap": Color(0.13, 0.15, 0.2),
		"acc_headband": Color(1.0, 0.42, 0.36),
		"acc_sunnies": Color(0.1, 0.1, 0.14),
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
		"trim": Color(1.0, 0.97, 0.9),
		"top": Color(0.07, 0.66, 0.7),
		"top_trim": Color(1.0, 0.5, 0.4),
		"top_print": Color(1.0, 0.82, 0.38),
		"bottom": Color(0.07, 0.66, 0.7),
		"bottom_trim": Color(1.0, 0.5, 0.4),
		"band": Color(0.1, 0.72, 0.74),
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
	for key: String in AnimeHead.COLORS:
		d[key] = AnimeHead.COLORS[key]
	var lagoon: Dictionary = SkateShoe.preset(SkateShoe.LAGOON)
	for key: String in lagoon:
		d[key] = lagoon[key]
	if body_type == "male":
		for key: String in MALE_DEFAULTS:
			d[key] = MALE_DEFAULTS[key]
	return d


## Male palette over the shared defaults: a warmer tan, dark chocolate-brown messy hair with a cool sheen, amber
## eyes, a cream ringer surf tee with coral trim and deep teal board shorts with a coral side stripe.
const MALE_DEFAULTS: Dictionary = {
	"skin": Color(0.86, 0.62, 0.45),
	"hair_base": Color(0.27, 0.2, 0.2),
	"hair_mid": Color(0.21, 0.155, 0.16),
	"hair_shadow": Color(0.14, 0.1, 0.12),
	"hair_deep": Color(0.09, 0.07, 0.09),
	"hair_shine": Color(0.5, 0.42, 0.44),
	"head_brow": Color(0.17, 0.12, 0.12),
	"head_lash": Color(0.13, 0.09, 0.1),
	"head_lash_low": Color(0.45, 0.3, 0.25),
	"head_iris_rim": Color(0.35, 0.17, 0.06),
	"head_iris_mid": Color(0.8, 0.5, 0.16),
	"head_iris_glow": Color(1.0, 0.82, 0.45),
	"head_pupil": Color(0.12, 0.06, 0.04),
	"top": Color(0.96, 0.94, 0.88),
	"top_trim": Color(1.0, 0.45, 0.36),
	"top_print": Color(1.0, 0.72, 0.3),
	"bottom": Color(0.05, 0.42, 0.5),
	"bottom_trim": Color(1.0, 0.5, 0.38),
}


static func _board_defaults() -> Dictionary:
	return {
		# Deck: dark griptape on top, maple plies with coral and teal dyed plies, a sunset-over-the-sea graphic below.
		"grip": Color(0.25, 0.26, 0.3),
		"ply": Color(0.95, 0.84, 0.64),
		"ply_dark": Color(0.84, 0.67, 0.46),
		"ply_coral": Color(1.0, 0.48, 0.38),
		"ply_teal": Color(0.08, 0.66, 0.72),
		"deck": Color(0.2, 0.7, 0.75),
		"deck_dark": Color(0.06, 0.4, 0.55),
		"deck_alt": Color(1.0, 0.48, 0.38),
		"deck_sun": Color(1.0, 0.82, 0.42),
		"deck_foam": Color(0.98, 0.96, 0.9),
		"deck_accent": Color(1.0, 0.48, 0.38),
		# Trucks: raw cast aluminium hanger and baseplate, steel hardware, orange bushings, black riser pads.
		"trucks": Color(0.76, 0.76, 0.74),
		"baseplate": Color(0.64, 0.64, 0.63),
		"truck_dark": Color(0.28, 0.3, 0.35),
		"hardware": Color(0.56, 0.58, 0.62),
		"bushings": Color(1.0, 0.55, 0.22),
		"truck_accent": Color(0.55, 0.92, 0.88),
		"riser": Color(0.14, 0.15, 0.18),
		# Wheels: sunny urethane, cream core, teal bearing shields.
		"wheels": Color(1.0, 0.78, 0.4),
		"core": Color(0.98, 0.96, 0.9),
		"hubs": Color(0.08, 0.6, 0.68),
	}

static func _build_arm(chest: Node3D, side: String, s: float, mats: Dictionary, body_type: String, rig: Dictionary) -> void:
	var upper: Node3D = SkaterParts.joint(chest, side + "UpperArm", Vector3(s * SHOULDER.x, SHOULDER.y, 0.0))
	upper.rotation.z = s * ARM_OUT
	var lower: Node3D = SkaterParts.joint(upper, side + "LowerArm", Vector3(0.0, -UPPER_ARM, 0.0))
	lower.rotation.x = FOREARM_BEND
	if rig["code_skin"]:
		AnimeOutfit.build_arm_skin(upper, lower, side, UPPER_ARM, LOWER_ARM, mats, body_type)
	var hand: Node3D = SkaterParts.joint(lower, side + "Hand", Vector3(0.0, -LOWER_ARM, 0.0))
	var hand_mesh: MeshInstance3D = SkaterParts.part(hand, side + "HandMesh", _hand_mesh(s), Vector3.ZERO, mats, "skin")
	hand_mesh.scale = Vector3.ONE * (HAND_SCALE * 1.08 if body_type == "male" else HAND_SCALE)
	SkaterParts.tag_region(hand_mesh, "hand_" + side.left(1))
	for n: Node3D in [upper, lower, hand]:
		rig[str(n.name)] = n


## Soft hand, hanging along -Y with the palm toward +Z and the thumb on the inner side (-s): a slim tapered palm, four
## jointed fingers graded in length and relaxed in a slight curl toward the palm, and a two-segment thumb, merged into
## one mesh. (A round puck palm with straight sausage fingers read as a mitten.)
static func _hand_mesh(s: float) -> ArrayMesh:
	var items: Array = []
	# Palm: wider across the knuckles than at the wrist, thin front to back, with a soft heel under the thumb.
	items.append([SkaterParts.sphere_small(0.026), Transform3D(Basis.from_scale(Vector3(0.98, 1.3, 0.44)), Vector3(0.0, -0.037, 0.001))])
	items.append([SkaterParts.sphere_small(0.012), Transform3D(Basis.from_scale(Vector3(1.0, 1.4, 0.8)), Vector3(-s * 0.011, -0.03, 0.004))])
	items.append([SkaterParts.capsule_small(0.0105, 0.05), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, -0.062, 0.0))])
	# Fingers, index (inner side) to little finger: [x, base y, length].
	var fingers: Array = [[-0.0195, -0.066, 0.042], [-0.0065, -0.068, 0.047], [0.0065, -0.067, 0.044], [0.0185, -0.063, 0.035]]
	for f: Array in fingers:
		var base: Vector3 = Vector3(s * float(f[0]), float(f[1]), 0.0)
		var l: float = float(f[2])
		var r: float = 0.0062 if absf(float(f[0])) < 0.015 else 0.0057
		var curl: float = 0.22 + 0.06 * absf(float(f[0])) / 0.02  ## the outer fingers curl a little more
		var d0: Vector3 = Vector3(0.0, -cos(curl), sin(curl))
		var mid: Vector3 = base + d0 * l * 0.55
		var d1: Vector3 = Vector3(0.0, -cos(curl * 2.4), sin(curl * 2.4))
		items.append(_hand_bone(base, mid, r))
		items.append(_hand_bone(mid, mid + d1 * l * 0.45, r * 0.9))
	# Thumb: out from the heel of the palm, angled across the front of the palm.
	var t0: Vector3 = Vector3(-s * 0.021, -0.026, 0.006)
	var t1: Vector3 = t0 + Vector3(-s * 0.008, -0.021, 0.009)
	var t2: Vector3 = t1 + Vector3(s * 0.001, -0.018, 0.012)
	items.append(_hand_bone(t0, t1, 0.0078))
	items.append(_hand_bone(t1, t2, 0.0068))
	return SkaterParts.merge(items)


## A capsule from a to b of radius r, as a SkaterParts.merge item.
static func _hand_bone(a: Vector3, b: Vector3, r: float) -> Array:
	var d: Vector3 = b - a
	var basis: Basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	return [SkaterParts.capsule_small(r, d.length() + 2.0 * r), Transform3D(basis, (a + b) * 0.5)]


## foot_z: ankle offset from the hips along Z (negative = forward, toward the nose).
static func _build_leg(hips: Node3D, side: String, s: float, foot_z: float, mats: Dictionary, body_type: String, rig: Dictionary) -> void:
	var pose: Vector2 = _leg_pose(foot_z)
	var upper: Node3D = SkaterParts.joint(hips, side + "UpperLeg", Vector3(s * HIP_SPREAD, 0.0, 0.0))
	upper.rotation.x = pose.x
	var lower: Node3D = SkaterParts.joint(upper, side + "LowerLeg", Vector3(0.0, -UPPER_LEG, 0.0))
	lower.rotation.x = pose.y - pose.x
	if rig["code_skin"]:
		AnimeOutfit.build_leg_skin(upper, lower, side, UPPER_LEG, LOWER_LEG, mats, body_type)
	var foot: Node3D = SkaterParts.joint(lower, side + "Foot", Vector3(0.0, -LOWER_LEG, 0.0))
	foot.rotation.x = -pose.y
	for n: Node3D in [upper, lower, foot]:
		rig[str(n.name)] = n

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
