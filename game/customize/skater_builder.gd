class_name SkaterBuilder
extends RefCounted
## Adapter between a SkaterLoadout and the meshes. Stage 1: calls PlaceholderSkater and maps loadout colours into
## its palette. Stage 2 replaces the bodies of build_body / build_board with per-item builders chosen by each
## catalog item's `mesh_builder` key. Anything not drawn yet is listed by pending_features().

## mesh_builder keys that really draw. Body side: the built (not stubbed) Wardrobe ids (Wardrobe.built_ids()).
const SUPPORTED_BUILDERS: PackedStringArray = [
	"hair_ponytail", "hair_messy", "top_bikini", "top_surf_tee", "top_rash_guard", "top_crop_tank", "top_hoodie", "top_flannel",
	"bottom_bikini", "bottom_board_shorts",
	"socks_crew", "shoes_low_vulc", "acc_wristbands",
	"deck_popsicle", "truck_standard", "wheel_street_52", "bearing_none", "griptape_color",
	"deck_cruiser", "deck_oldschool", "truck_low", "truck_hollow", "wheel_park_54", "wheel_cruiser_56",
]
## Slots pending_features() inspects for a loadout.
const SLOTS_TO_CHECK: PackedStringArray = [
	"hair", "top", "bottom", "socks", "shoes", "accessory", "deck", "truck", "wheel", "bearing", "griptape",
]


static func build_body(loadout: SkaterLoadout) -> Node3D:
	return PlaceholderSkater.build_body(body_palette(loadout), body_options(loadout))


## PlaceholderSkater.build_body options for a loadout: the body type and each slot's catalog mesh_builder id.
static func body_options(l: SkaterLoadout) -> Dictionary:
	var cat: PartCatalog = PartCatalog.load_default()
	var o: Dictionary = {"body": l.body_type if l.body_type == "male" else "female"}
	for slot: String in ["hair", "top", "bottom", "socks", "shoes"]:
		o[slot] = str(cat.item(l.item_id(slot)).get("mesh_builder", ""))
	var acc: Array = []
	for a: String in l.accessories:
		acc.append(str(cat.item(a).get("mesh_builder", a)))
	o["accessories"] = acc
	return o


static func build_board(loadout: SkaterLoadout) -> Node3D:
	return PlaceholderSkater.build_board(board_palette(loadout), board_options(loadout))


## PlaceholderSkater.build_board options for a loadout: the deck, truck and wheel mesh builders and the deck graphic.
static func board_options(l: SkaterLoadout) -> Dictionary:
	var cat: PartCatalog = PartCatalog.load_default()
	return {
		"deck": str(cat.item(l.deck_id).get("mesh_builder", "deck_popsicle")),
		"truck": str(cat.item(l.truck_id).get("mesh_builder", "truck_standard")),
		"wheel": str(cat.item(l.wheel_id).get("mesh_builder", "wheel_street_52")),
		"graphic": cat.graphic_of(l.deck_id, l.deck_graphic),
	}


## Palette keys of PlaceholderSkater._body_defaults() set from the loadout: skin; the AnimeHead hair keys
## ("hair_base", "hair_mid", "hair_shadow", "hair_deep", "hair_shine") and brow; the iris keys ("head_iris_rim",
## "head_iris_mid", "head_iris_glow", "head_pupil"); garment keys ("top"/"top_trim", "bottom"/"bottom_trim",
## "sock"/"sock_stripe"/"sock_stripe2", accessories: wristbands "band"); and the shoe colourway ("shoe_*" keys from
## SkateShoe.colourway_from). The legacy keys ("hair", "iris", "shirt", ...) are kept for older callers.
static func body_palette(l: SkaterLoadout) -> Dictionary:
	var cat: PartCatalog = PartCatalog.load_default()
	var p: Dictionary = {}
	p["skin"] = l.skin_tone
	p["nose"] = l.skin_tone.lerp(Color(0.8, 0.4, 0.35), 0.3)
	p["blush"] = l.skin_tone.lerp(Color(1.0, 0.45, 0.5), 0.45)
	var hc: Color = l.hair_color
	p["hair"] = hc
	p["hair_dark"] = hc.darkened(0.22)
	p["hair_light"] = hc.lightened(0.3)
	p["hair_root"] = hc.darkened(0.45)
	p["brow"] = hc.darkened(0.35)
	p["hair_base"] = hc.lightened(0.06)
	p["hair_mid"] = hc.darkened(0.06)
	p["hair_shadow"] = hc.darkened(0.25)
	p["hair_deep"] = hc.darkened(0.45)
	p["hair_shine"] = hc.lightened(0.45)
	p["head_brow"] = hc.darkened(0.3) if hc.get_luminance() > 0.25 else hc.darkened(0.15)
	var ec: Color = l.eye_color
	p["iris"] = ec
	p["iris_light"] = ec.lightened(0.45)
	p["iris_ring"] = ec.darkened(0.55)
	p["head_iris_rim"] = ec.darkened(0.5)
	p["head_iris_mid"] = ec.lightened(0.08)
	p["head_iris_glow"] = ec.lightened(0.55)
	p["head_pupil"] = ec.darkened(0.8)
	var top: Color = cat.color_of(l.top_id, l.top_color)
	p["top"] = top
	p["top_trim"] = _contrast(top)
	p["shirt"] = top
	p["shirt_dark"] = top.darkened(0.15)
	var bottom: Color = cat.color_of(l.bottom_id, l.bottom_color)
	p["bottom"] = bottom
	if l.bottom_id == "bottom_joggers":
		bottom = Color.from_hsv(bottom.h, bottom.s * 0.7, bottom.v * 0.78)  ## sweats: a deeper, quieter shade
		p["bottom"] = bottom
	p["bottom_trim"] = _soft_trim(bottom)
	p["top_tee"] = Color(0.78, 0.77, 0.88)  ## the tee under the flannel: light grey-lavender, never a white slab
	p["pants"] = bottom
	p["pants_trim"] = bottom.lightened(0.35)
	var sock: Color = cat.color_of(l.socks_id, l.socks_color)
	p["sock"] = sock
	p["sock_stripe"] = sock.darkened(0.25) if sock.get_luminance() < 0.85 else Color(1.0, 0.48, 0.3)
	p["sock_stripe2"] = sock.darkened(0.4) if sock.get_luminance() < 0.85 else Color(0.08, 0.72, 0.74)
	var shoe: Color = cat.color_of(l.shoes_id, l.shoes_color)
	p["shoes"] = shoe
	p["collar"] = shoe.darkened(0.2)
	var way: Dictionary = SkateShoe.colourway_from(shoe)
	for key: String in way:
		p[key] = way[key]
	for i: int in l.accessories.size():
		var a: String = l.accessories[i]
		var c: Color = cat.color_of(a, l.accessory_colors[i] if i < l.accessory_colors.size() else 0)
		if str(cat.item(a).get("mesh_builder", "")) == "acc_wristbands":
			p["band"] = c
		else:
			p["acc_" + a.trim_prefix("acc_")] = c
	return p


## A trim colour that stands out against `c`: the opposite hue, kept bright (coral on white).
static func _contrast(c: Color) -> Color:
	if c.s < 0.15:
		return Color(1.0, 0.45, 0.36) if c.v > 0.5 else Color(0.3, 0.85, 0.9)
	return Color.from_hsv(fposmod(c.h + 0.5, 1.0), clampf(c.s, 0.55, 0.85), clampf(c.v, 0.8, 1.0))


## A quieter trim for bottoms (stitching, belts, piping): the contrast hue pulled towards the fabric, less saturated.
static func _soft_trim(c: Color) -> Color:
	var t: Color = _contrast(c)
	return Color.from_hsv(t.h, t.s * 0.55, clampf(t.v * 0.78, 0.5, 0.78))


## Palette keys of PlaceholderSkater._board_defaults() set from the loadout.
static func board_palette(l: SkaterLoadout) -> Dictionary:
	var cat: PartCatalog = PartCatalog.load_default()
	var deck: Color = cat.color_of(l.deck_id, l.deck_graphic)
	var wheel: Color = cat.color_of(l.wheel_id, l.wheel_color)
	var truck: Color = cat.color_of(l.truck_id, l.truck_color)
	var p: Dictionary = {
		"deck": deck,
		"deck_alt": deck.lerp(Color(1, 1, 1), 0.35),
		"deck_dark": deck.darkened(0.4),
		"deck_accent": Color.from_hsv(fposmod(deck.h + 0.5, 1.0), 0.7, 1.0),
		"grip": cat.color_of(l.griptape_id, l.griptape_color),
		"wheels": wheel,
		"hubs": wheel.lightened(0.4),
		"trucks": truck,
		"truck_accent": truck.lightened(0.45).lerp(Color(0.55, 0.95, 0.9), 0.35),
	}
	if l.wheel_id == "wheel_cruiser_56":
		# Soft cruiser urethane reads translucent: a paler tyre over a tinted core.
		p["wheels"] = wheel.lerp(Color(1, 1, 1), 0.22)
		p["core"] = wheel.lightened(0.6)
	return p


## What can't be drawn yet, as "slot:mesh_builder" strings (stubbed Wardrobe ids draw a stand-in). With a loadout,
## only the entries that loadout uses; with null, every catalog entry that has no builder yet.
static func pending_features(l: SkaterLoadout = null) -> PackedStringArray:
	var cat: PartCatalog = PartCatalog.load_default()
	var out: PackedStringArray = []
	if l == null:
		for it: Dictionary in cat.all_items():
			_add_if_pending(out, str(it["slot"]), str(it["mesh_builder"]))
	else:
		for slot: String in SLOTS_TO_CHECK:
			if slot == "accessory":
				for a: String in l.accessories:
					_add_if_pending(out, slot, str(cat.item(a).get("mesh_builder", a)))
			else:
				_add_if_pending(out, slot, str(cat.item(l.item_id(slot)).get("mesh_builder", "")))
	return out


static func _add_if_pending(out: PackedStringArray, slot: String, builder: String) -> void:
	if builder != "" and not SUPPORTED_BUILDERS.has(builder):
		out.append("%s:%s" % [slot, builder])
