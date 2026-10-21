class_name Wardrobe
extends RefCounted
## Registry of the skater's clothing and hair builders, keyed by slot and by the catalog's `mesh_builder` id
## (data/catalog.json), and the code that dresses a base body with them.
##
## ARCHITECTURE
## 1. Base body. For each body type ("female", "male") PlaceholderSkater builds one smooth, featureless base body,
##    like a mannequin, with no anatomical detail. It is the only skin. The female bust is part of that base body
##    (AnimeOutfit bust field, under the BodySway_BustL/R pivots). With no garments at all the base body is still a
##    presentable mannequin.
## 2. Garments. Every garment (hair, top, bottom, socks, shoes, accessory) is a separate layer built by a builder
##    registered here, lofted from the base body's section data and offset outward by a small clearance (about 4-8
##    mm, more at the joints). Nothing about a garment is baked into the body.
## 3. Body masking. The skin is split into regions (AnimeOutfit.TORSO_REGIONS / LIMB_REGIONS / REGIONS; each code
##    skin MeshInstance3D has meta "region", limb regions end in "_L" or "_R"; the Houdini skinned body tags each
##    triangle with the same names, HoudiniBody, plus "foot_L"/"foot_R"). Each garment declares the regions it FULLY
##    covers (covers()); dress() hides those skin meshes, so skin can never poke through the garment in any pose. A
##    garment may only declare a region it encloses all round, and the piece that encloses it must hang on the same
##    joint (or pivot) as that skin, so the cover holds in every pose. tests/unit/test_wardrobe.gd checks this over
##    the pose grid.
##
## GARMENT BUILDER CONTRACT
##     static func build(rig: Dictionary, body_type: String, mats: Dictionary) -> void
## - rig: every joint Node3D by name (the 17 SkaterPoser.JOINTS names, plus "HeadModel" and, on the female body,
##   "BodySway_BustL"/"BodySway_BustR"), and:
##     "body_type": "female" | "male"
##     "sections": AnimeOutfit.joint_sections(): smoothed skin sections in each joint's space, keyed "pelvis" (Hips),
##                 "waist" (Spine), "chest" (Chest), "neck" (Neck), "thigh" (<Side>UpperLeg), "calf" (<Side>LowerLeg),
##                 "upper_arm" (<Side>UpperArm), "forearm" (<Side>LowerArm). Section rows are
##                 [y, half width, front depth, back depth, power, z centre, x centre] (SkaterParts.section_point).
##     "rest_y": rest height above the soles of "Hips", "Spine", "Chest", "Neck", "Head".
##     "lengths": "upper_leg", "lower_leg", "upper_arm", "lower_arm", "ankle" (metres, PlaceholderSkater constants).
##   Body-space tables: AnimeOutfit.skin_sections(part, body_type); chest front with the bust:
##   AnimeOutfit.chest_front_point(x, y, lift, body_type). PlaceholderSkater.rig_of(body) rebuilds a rig.
## - body_type: "female" or "male". A builder must work for every body its catalog item lists in "bodies".
## - mats: palette key -> StandardMaterial3D, shared by the whole skater. Build parts with
##   SkaterParts.part(joint, name, mesh, offset, mats, key) so the toon pass can find them by meta "palette". A key
##   that may be missing from the palette goes through Wardrobe.mat(mats, key, default_colour) first.
## - Builders add MeshInstance3D children (or holder Node3Ds) under the rig joints. They must not move, rename or
##   re-parent joints, and must not touch the skin. Name parts uniquely (e.g. "SurfTee..."), sides with Left/Right.
## - Hair builders: same signature, slot "hair", built by AnimeHead.build() (dress() skips the hair slot). They hang
##   under rig["HeadModel"] (face toward -Z; head surface helpers AnimeHead.cap_point / face_z / face_normal /
##   lock_mesh / pivot_lock / cap_mesh). HAIR SWAY CONVENTION: hair that should sway hangs from identity-rotation
##   Node3D pivots named "HairSway_<Name>" placed at each lock's root; a chain numbers on: "HairSway_<Name>" >
##   "HairSway_<Name>2" > "HairSway_<Name>3". Side locks use "HairSway_SideL" / "HairSway_SideR" (L = -X). The
##   secondary-motion code finds pivots by the "HairSway_" and "BodySway_" prefixes, so keep them.
##
## REGISTERING. Each slot's builders live in their own file under game/skater/garments/ (hair.gd, tops.gd,
## bottoms.gd, socks.gd, shoes.gd, accessories.gd). Each file has:
##     static func builders() -> Dictionary   # mesh_builder id -> static Callable with the contract above
##     static func covers(id, body_type) -> PackedStringArray   # skin regions the garment fully covers (not hair)
##     const STUBS: PackedStringArray          # ids registered but not built yet
## A stub warns once and builds the slot's reference garment instead (so a body is never left uncovered; accessory
## stubs build nothing). To build a stubbed id: write its builder, point builders() at it, remove it from STUBS and
## declare covers().

const SLOTS: PackedStringArray = ["hair", "top", "bottom", "socks", "shoes", "accessory"]
## Default outfit of each base body: the look of the game's default skaters.
const DEFAULTS: Dictionary = {
	"female": {
		"body": "female", "hair": "hair_ponytail", "top": "top_bikini", "bottom": "bottom_bikini", "socks": "socks_crew",
		"shoes": "shoes_low_vulc", "accessories": ["acc_wristbands"],
	},
	"male": {
		"body": "male", "hair": "hair_messy", "top": "top_surf_tee", "bottom": "bottom_board_shorts", "socks": "socks_crew",
		"shoes": "shoes_low_vulc", "accessories": [],
	},
}

## Skin regions any shoe hides: the skinned body's bare feet (the code skin has none). Not part of covers(): a foot
## sits deep in a roomy shoe rather than just under its surface, so tests/unit/test_garments_shoes.gd checks it is
## enclosed in its own way.
const FEET: PackedStringArray = ["foot_L", "foot_R"]

static var _registry: Dictionary = {}
static var _warned: Dictionary = {}


## slot -> {mesh_builder id -> Callable}.
static func registry() -> Dictionary:
	if _registry.is_empty():
		_registry = {
			"hair": HairStyles.builders(),
			"top": GarmentTops.builders(),
			"bottom": GarmentBottoms.builders(),
			"socks": GarmentSocks.builders(),
			"shoes": GarmentShoes.builders(),
			"accessory": GarmentAccessories.builders(),
		}
	return _registry


static func _stubs(slot: String) -> PackedStringArray:
	match slot:
		"hair": return HairStyles.STUBS
		"top": return GarmentTops.STUBS
		"bottom": return GarmentBottoms.STUBS
		"socks": return GarmentSocks.STUBS
		"shoes": return GarmentShoes.STUBS
		"accessory": return GarmentAccessories.STUBS
	return PackedStringArray()


## Skin regions the garment fully covers (limb regions carry "_L"/"_R"). Stubs and hair cover nothing.
static func covers(slot: String, id: String, body_type: String) -> PackedStringArray:
	if is_stub(slot, id) or not has_builder(slot, id):
		return PackedStringArray()
	match slot:
		"top": return GarmentTops.covers(id, body_type)
		"bottom": return GarmentBottoms.covers(id, body_type)
		"socks": return GarmentSocks.covers(id, body_type)
		"shoes": return GarmentShoes.covers(id, body_type)
		"accessory": return GarmentAccessories.covers(id, body_type)
	return PackedStringArray()


## True when the id is registered for the slot (built or stubbed).
static func has_builder(slot: String, id: String) -> bool:
	return (registry().get(slot, {}) as Dictionary).has(id)


## True when the id is registered but only a placeholder stub.
static func is_stub(slot: String, id: String) -> bool:
	return _stubs(slot).has(id)


## Ids that really draw (registered and not stubbed).
static func built_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for slot: String in SLOTS:
		for id: String in (registry()[slot] as Dictionary).keys():
			if not is_stub(slot, id):
				out.append(id)
	return out


## Ids registered as stubs, as "slot:id".
static func stub_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for slot: String in SLOTS:
		for id: String in _stubs(slot):
			out.append("%s:%s" % [slot, id])
	return out


## Options with every missing key filled from the body's defaults. Unknown body types become "female".
static func resolve(options: Dictionary) -> Dictionary:
	var body: String = str(options.get("body", "female"))
	if not DEFAULTS.has(body):
		body = "female"
	var out: Dictionary = (DEFAULTS[body] as Dictionary).duplicate(true)
	for key: String in options.keys():
		out[key] = options[key]
	out["body"] = body
	return out


## Builds one item. An empty id or "none" builds nothing. Unknown ids warn once and build nothing.
static func build_item(slot: String, id: String, rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	if id == "" or id == "none":
		return
	var reg: Dictionary = registry().get(slot, {})
	if not reg.has(id):
		warn_once("Wardrobe: no %s builder for '%s'" % [slot, id])
		return
	(reg[id] as Callable).call(rig, body_type, mats)


## Builds every garment slot of the (resolved) options onto the rig (not hair: AnimeHead.build() does that), then
## hides the skin regions the garments cover.
static func dress(rig: Dictionary, options: Dictionary, mats: Dictionary) -> void:
	var body_type: String = str(rig["body_type"])
	var covered: PackedStringArray = []
	for slot: String in SLOTS:
		if slot == "hair":
			continue
		var ids: Array = []
		if slot == "accessory":
			ids = Array(options.get("accessories", []))
		else:
			ids = [str(options.get(slot, ""))]
		for id: Variant in ids:
			build_item(slot, str(id), rig, body_type, mats)
			covered.append_array(covers(slot, str(id), body_type))
			if slot == "shoes" and has_builder(slot, str(id)):
				covered.append_array(FEET)
	mask_skin((rig["Hips"] as Node3D).get_parent(), covered)


## Hides every skin mesh under root whose region is in `covered` (meta "hidden_by_garment" marks them), and the
## covered regions of a skinned body (SkinnedBody.set_hidden_regions; the head and hands it never draws stay hidden).
static func mask_skin(root: Node, covered: PackedStringArray) -> void:
	if root is MeshInstance3D and root.has_meta("region") and covered.has(str(root.get_meta("region"))):
		(root as MeshInstance3D).visible = false
		root.set_meta("hidden_by_garment", true)
	if root is SkinnedBody:
		(root as SkinnedBody).set_hidden_regions(covered)
	for c: Node in root.get_children():
		mask_skin(c, covered)


## The material for `key`, made from `colour` and added to mats when the palette has no such key.
static func mat(mats: Dictionary, key: String, colour: Color) -> StandardMaterial3D:
	if not mats.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = 0.7
		mats[key] = m
	return mats[key]


## push_warning once per message (stubs are built every time a skater is built).
static func warn_once(msg: String) -> void:
	if not _warned.has(msg):
		_warned[msg] = true
		push_warning(msg)


## Shared stub: warns once that `id` is not built yet and builds `fallback` (the slot's reference garment).
static func stub(rig: Dictionary, body_type: String, mats: Dictionary, slot: String, id: String, fallback: Callable) -> void:
	warn_once("Wardrobe: %s '%s' is not built yet; drawing the reference %s instead" % [slot, id, slot])
	if fallback.is_valid():
		fallback.call(rig, body_type, mats)


## Both sides with their names and signs: [["Left", -1.0], ["Right", 1.0]].
static func sides() -> Array:
	return [["Left", -1.0], ["Right", 1.0]]
