class_name SkaterBuilder
extends RefCounted
## Adapter between a SkaterLoadout and the meshes. Stage 1: calls PlaceholderSkater and maps loadout colours into
## its palette. Stage 2 replaces the bodies of build_body / build_board with per-item builders chosen by each
## catalog item's `mesh_builder` key. Anything not drawn yet is listed by pending_features().

## mesh_builder keys the placeholder skater can already draw (colour only).
const SUPPORTED_BUILDERS: PackedStringArray = [
	"top_rash_guard", "bottom_board_shorts", "socks_crew", "shoes_low_vulc", "hair_ponytail",
	"deck_popsicle", "truck_standard", "wheel_street_52", "bearing_none", "griptape_color",
]
## Slots pending_features() inspects for a loadout (accessories are not drawn at all yet).
const SLOTS_TO_CHECK: PackedStringArray = [
	"hair", "top", "bottom", "socks", "shoes", "accessory", "deck", "truck", "wheel", "bearing", "griptape",
]


static func build_body(loadout: SkaterLoadout) -> Node3D:
	return PlaceholderSkater.build_body(body_palette(loadout))


static func build_board(loadout: SkaterLoadout) -> Node3D:
	return PlaceholderSkater.build_board(board_palette(loadout))


## Palette keys of PlaceholderSkater._body_defaults() set from the loadout.
static func body_palette(l: SkaterLoadout) -> Dictionary:
	var cat: PartCatalog = PartCatalog.load_default()
	var p: Dictionary = {}
	p["skin"] = l.skin_tone
	p["nose"] = l.skin_tone.lerp(Color(0.8, 0.4, 0.35), 0.3)
	p["blush"] = l.skin_tone.lerp(Color(1.0, 0.45, 0.5), 0.45)
	p["hair"] = l.hair_color
	p["hair_dark"] = l.hair_color.darkened(0.22)
	p["hair_light"] = l.hair_color.lightened(0.3)
	p["hair_root"] = l.hair_color.darkened(0.45)
	p["brow"] = l.hair_color.darkened(0.35)
	p["iris"] = l.eye_color
	p["iris_light"] = l.eye_color.lightened(0.45)
	p["iris_ring"] = l.eye_color.darkened(0.55)
	var top: Color = cat.color_of(l.top_id, l.top_color)
	p["top"] = top
	p["shirt"] = top
	p["shirt_dark"] = top.darkened(0.15)
	var bottom: Color = cat.color_of(l.bottom_id, l.bottom_color)
	p["pants"] = bottom
	p["pants_trim"] = bottom.lightened(0.35)
	var sock: Color = cat.color_of(l.socks_id, l.socks_color)
	p["sock"] = sock
	p["sock_stripe"] = sock.darkened(0.25)
	p["sock_stripe2"] = sock.darkened(0.4)
	var shoe: Color = cat.color_of(l.shoes_id, l.shoes_color)
	p["shoes"] = shoe
	p["collar"] = shoe.darkened(0.2)
	return p


## Palette keys of PlaceholderSkater._board_defaults() set from the loadout.
static func board_palette(l: SkaterLoadout) -> Dictionary:
	var cat: PartCatalog = PartCatalog.load_default()
	var deck: Color = cat.color_of(l.deck_id, l.deck_graphic)
	var wheel: Color = cat.color_of(l.wheel_id, l.wheel_color)
	return {
		"deck": deck,
		"deck_alt": deck.lerp(Color(1, 1, 1), 0.35),
		"grip": cat.color_of(l.griptape_id, l.griptape_color),
		"wheels": wheel,
		"hubs": wheel.lightened(0.4),
		"trucks": cat.color_of(l.truck_id, l.truck_color),
	}


## What the placeholder can't draw yet, as "slot:mesh_builder" strings (plus "body:male"). With a loadout, only the
## entries that loadout uses; with null, every catalog entry that has no builder yet. Stage 2 clears this list.
static func pending_features(l: SkaterLoadout = null) -> PackedStringArray:
	var cat: PartCatalog = PartCatalog.load_default()
	var out: PackedStringArray = []
	if l == null or l.body_type == "male":
		out.append("body:male")
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
