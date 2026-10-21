class_name SkaterLoadout
extends Resource
## Everything that makes the player's skater and board look the way they do: body, face, outfit, accessories and
## board parts. Item ids come from PartCatalog; "color" fields are indexes into that item's colour variants.
## Saved as JSON at user://loadout.json.

const SAVE_PATH: String = "user://loadout.json"
const VERSION: int = 1
const OUTFIT_SLOTS: PackedStringArray = ["top", "bottom", "socks", "shoes"]
const BOARD_SLOTS: PackedStringArray = ["deck", "truck", "wheel", "bearing", "griptape"]
const MAX_ACCESSORIES: int = 3

@export var skater_name: String = "Sunny"
@export var body_type: String = "female"  ## "female" or "male"
@export var skin_tone: Color = Color("#E6B085")
@export var hair_style: String = "hair_ponytail"
@export var hair_color: Color = Color("#F0C766")
@export var eye_color: Color = Color("#2F86E0")
@export var top_id: String = "top_rash_guard"
@export var top_color: int = 0
@export var bottom_id: String = "bottom_board_shorts"
@export var bottom_color: int = 0
@export var socks_id: String = "socks_crew"
@export var socks_color: int = 0
@export var shoes_id: String = "shoes_low_vulc"
@export var shoes_color: int = 0
@export var accessories: Array[String] = []  ## item ids, at most one per accessory colour pick
@export var accessory_colors: Array[int] = []  ## parallel to accessories
@export var deck_id: String = "deck_popsicle"
@export var deck_graphic: int = 0
@export var truck_id: String = "truck_standard"
@export var truck_color: int = 0
@export var wheel_id: String = "wheel_street_52"
@export var wheel_color: int = 0
@export var bearing_id: String = "bearing_standard"
@export var griptape_id: String = "grip_black"
@export var griptape_color: int = 0


static func default_female() -> SkaterLoadout:
	return SkaterLoadout.new()


static func default_male() -> SkaterLoadout:
	var l: SkaterLoadout = SkaterLoadout.new()
	l.skater_name = "Kai"
	l.body_type = "male"
	l.skin_tone = Color("#C98E64")
	l.hair_style = "hair_short_spiky"
	l.hair_color = Color("#1F1F33")
	l.eye_color = Color("#4A2C1A")
	l.top_id = "top_surf_tee"
	l.bottom_id = "bottom_cargo_shorts"
	l.shoes_color = 1
	l.deck_graphic = 1
	return l


# Generic slot access, so the menus can loop over slots.

func item_id(slot: String) -> String:
	match slot:
		"top": return top_id
		"bottom": return bottom_id
		"socks": return socks_id
		"shoes": return shoes_id
		"hair": return hair_style
		"deck": return deck_id
		"truck": return truck_id
		"wheel": return wheel_id
		"bearing": return bearing_id
		"griptape": return griptape_id
		"accessory": return accessories[0] if not accessories.is_empty() else ""
	return ""


func item_color(slot: String) -> int:
	match slot:
		"top": return top_color
		"bottom": return bottom_color
		"socks": return socks_color
		"shoes": return shoes_color
		"deck": return deck_graphic
		"truck": return truck_color
		"wheel": return wheel_color
		"griptape": return griptape_color
		"accessory": return accessory_colors[0] if not accessory_colors.is_empty() else 0
	return 0


## Puts an item (and colour variant) in a slot. For "accessory" an empty id clears the single accessory pick.
func set_item(slot: String, id: String, color: int = 0) -> void:
	match slot:
		"top": top_id = id; top_color = color
		"bottom": bottom_id = id; bottom_color = color
		"socks": socks_id = id; socks_color = color
		"shoes": shoes_id = id; shoes_color = color
		"hair": hair_style = id
		"deck": deck_id = id; deck_graphic = color
		"truck": truck_id = id; truck_color = color
		"wheel": wheel_id = id; wheel_color = color
		"bearing": bearing_id = id
		"griptape": griptape_id = id; griptape_color = color
		"accessory":
			accessories.clear()
			accessory_colors.clear()
			if id != "":
				accessories.append(id)
				accessory_colors.append(color)


func set_color(slot: String, color: int) -> void:
	set_item(slot, item_id(slot), color)


func duplicate_loadout() -> SkaterLoadout:
	return from_dict(to_dict())


## Swaps any item the body can't wear, the player doesn't own, or the catalog doesn't know for the first allowed
## starter item of that slot, and clamps colour indexes. `owned` is a Callable(id: String) -> bool; empty = all owned.
func sanitize(owned: Callable = Callable()) -> void:
	var cat: PartCatalog = PartCatalog.load_default()
	if body_type != "female" and body_type != "male":
		body_type = "female"
	for slot: String in ["hair"] + Array(OUTFIT_SLOTS) + Array(BOARD_SLOTS):
		var id: String = item_id(slot)
		var ok: bool = cat.fits_body(id, body_type) and cat.item(id)["slot"] == slot and (owned.is_null() or owned.call(id))
		if not ok:
			id = _fallback(cat, slot, owned)
		set_item(slot, id, clampi(item_color(slot), 0, maxi(cat.color_count(id) - 1, 0)))
	var keep_ids: Array[String] = []
	var keep_cols: Array[int] = []
	for i: int in accessories.size():
		var a: String = accessories[i]
		if cat.fits_body(a, body_type) and cat.item(a)["slot"] == "accessory" and (owned.is_null() or owned.call(a)):
			keep_ids.append(a)
			keep_cols.append(clampi(accessory_colors[i] if i < accessory_colors.size() else 0, 0, maxi(cat.color_count(a) - 1, 0)))
	accessories = keep_ids.slice(0, MAX_ACCESSORIES)
	accessory_colors = keep_cols.slice(0, MAX_ACCESSORIES)


func _fallback(cat: PartCatalog, slot: String, owned: Callable) -> String:
	for it: Dictionary in cat.items_for(slot, body_type):
		if owned.is_null() or owned.call(str(it["id"])):
			return str(it["id"])
	for it: Dictionary in cat.items_for(slot, body_type):
		return str(it["id"])
	return ""


## Picks a random look from the items the player owns. Deterministic for a seeded rng.
func randomise(rng: RandomNumberGenerator, owned: Callable = Callable()) -> void:
	var cat: PartCatalog = PartCatalog.load_default()
	body_type = "male" if rng.randi_range(0, 1) == 1 else "female"
	if not cat.skin_tones.is_empty():
		skin_tone = cat.skin_tones[rng.randi_range(0, cat.skin_tones.size() - 1)]["color"]
	if not cat.hair_colors.is_empty():
		hair_color = cat.hair_colors[rng.randi_range(0, cat.hair_colors.size() - 1)]["color"]
	if not cat.eye_colors.is_empty():
		eye_color = cat.eye_colors[rng.randi_range(0, cat.eye_colors.size() - 1)]["color"]
	for slot: String in ["hair"] + Array(OUTFIT_SLOTS) + Array(BOARD_SLOTS):
		var pool: Array[Dictionary] = []
		for it: Dictionary in cat.items_for(slot, body_type):
			if owned.is_null() or owned.call(str(it["id"])):
				pool.append(it)
		if pool.is_empty():
			continue
		var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var cols: int = (pick["colors"] as Array).size()
		set_item(slot, str(pick["id"]), rng.randi_range(0, maxi(cols - 1, 0)))
	accessories.clear()
	accessory_colors.clear()
	if rng.randi_range(0, 2) == 0:
		var pool2: Array[Dictionary] = []
		for it: Dictionary in cat.items_for("accessory", body_type):
			if owned.is_null() or owned.call(str(it["id"])):
				pool2.append(it)
		if not pool2.is_empty():
			var a: Dictionary = pool2[rng.randi_range(0, pool2.size() - 1)]
			set_item("accessory", str(a["id"]), rng.randi_range(0, maxi((a["colors"] as Array).size() - 1, 0)))
	sanitize(owned)


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"name": skater_name,
		"body_type": body_type,
		"skin_tone": skin_tone.to_html(false),
		"hair_style": hair_style,
		"hair_color": hair_color.to_html(false),
		"eye_color": eye_color.to_html(false),
		"top": {"id": top_id, "color": top_color},
		"bottom": {"id": bottom_id, "color": bottom_color},
		"socks": {"id": socks_id, "color": socks_color},
		"shoes": {"id": shoes_id, "color": shoes_color},
		"accessories": _accessories_to_array(),
		"board": {
			"deck": {"id": deck_id, "graphic": deck_graphic},
			"truck": {"id": truck_id, "color": truck_color},
			"wheel": {"id": wheel_id, "color": wheel_color},
			"bearing": {"id": bearing_id},
			"griptape": {"id": griptape_id, "color": griptape_color},
		},
	}


static func from_dict(d: Dictionary) -> SkaterLoadout:
	var l: SkaterLoadout = SkaterLoadout.new()
	l.skater_name = str(d.get("name", l.skater_name))
	l.body_type = str(d.get("body_type", l.body_type))
	l.skin_tone = Color.from_string(str(d.get("skin_tone", "")), l.skin_tone)
	l.hair_style = str(d.get("hair_style", l.hair_style))
	l.hair_color = Color.from_string(str(d.get("hair_color", "")), l.hair_color)
	l.eye_color = Color.from_string(str(d.get("eye_color", "")), l.eye_color)
	for slot: String in OUTFIT_SLOTS:
		var e: Dictionary = d.get(slot, {}) as Dictionary
		l.set_item(slot, str(e.get("id", l.item_id(slot))), int(e.get("color", 0)))
	for a: Variant in d.get("accessories", []):
		var ad: Dictionary = a as Dictionary
		if l.accessories.size() < MAX_ACCESSORIES and ad.has("id"):
			l.accessories.append(str(ad["id"]))
			l.accessory_colors.append(int(ad.get("color", 0)))
	var b: Dictionary = d.get("board", {}) as Dictionary
	var deck: Dictionary = b.get("deck", {}) as Dictionary
	l.deck_id = str(deck.get("id", l.deck_id))
	l.deck_graphic = int(deck.get("graphic", 0))
	var truck: Dictionary = b.get("truck", {}) as Dictionary
	l.truck_id = str(truck.get("id", l.truck_id))
	l.truck_color = int(truck.get("color", 0))
	var wheel: Dictionary = b.get("wheel", {}) as Dictionary
	l.wheel_id = str(wheel.get("id", l.wheel_id))
	l.wheel_color = int(wheel.get("color", 0))
	l.bearing_id = str((b.get("bearing", {}) as Dictionary).get("id", l.bearing_id))
	var grip: Dictionary = b.get("griptape", {}) as Dictionary
	l.griptape_id = str(grip.get("id", l.griptape_id))
	l.griptape_color = int(grip.get("color", 0))
	return l


func _accessories_to_array() -> Array:
	var out: Array = []
	for i: int in accessories.size():
		out.append({"id": accessories[i], "color": accessory_colors[i] if i < accessory_colors.size() else 0})
	return out


func save(path: String = SAVE_PATH) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return true


## Reads a saved loadout. Missing or broken file gives default_female().
static func load_file(path: String = SAVE_PATH) -> SkaterLoadout:
	if not FileAccess.file_exists(path):
		return default_female()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return default_female()
	var l: SkaterLoadout = from_dict(parsed as Dictionary)
	l.sanitize()
	return l
