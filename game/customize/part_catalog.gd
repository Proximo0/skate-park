class_name PartCatalog
extends RefCounted
## Every item the skater can wear or ride, loaded from data/catalog.json. Pure data and lookups, no nodes.
## Item fields: id (unique across the catalog), name, slot, bodies ("female" / "male"), price, colors (hex),
## color_names, desc, mesh_builder (key that SkaterBuilder maps to a builder function), starter (owned at the start).

const DATA_PATH: String = "res://data/catalog.json"
const BODIES: PackedStringArray = ["female", "male"]

static var _default: PartCatalog = null

var slot_order: PackedStringArray = []
var categories: Array[Dictionary] = []
var skin_tones: Array[Dictionary] = []
var hair_colors: Array[Dictionary] = []
var eye_colors: Array[Dictionary] = []
var names: PackedStringArray = []
var _items: Array[Dictionary] = []
var _by_id: Dictionary = {}


## The shared catalog read from data/catalog.json (cached).
static func load_default() -> PartCatalog:
	if _default == null:
		var text: String = FileAccess.get_file_as_string(DATA_PATH)
		var parsed: Variant = JSON.parse_string(text)
		_default = from_dict(parsed as Dictionary if parsed is Dictionary else {})
	return _default


static func from_dict(d: Dictionary) -> PartCatalog:
	var c: PartCatalog = PartCatalog.new()
	for s: Variant in d.get("slots", []):
		c.slot_order.append(str(s))
	for cat: Variant in d.get("shop_categories", []):
		c.categories.append(cat as Dictionary)
	c.skin_tones = _palette(d.get("skin_tones", []))
	c.hair_colors = _palette(d.get("hair_colors", []))
	c.eye_colors = _palette(d.get("eye_colors", []))
	for n: Variant in d.get("names", []):
		c.names.append(str(n))
	for raw: Variant in d.get("items", []):
		var item: Dictionary = raw as Dictionary
		c._items.append(item)
		c._by_id[str(item.get("id", ""))] = item
	return c


static func _palette(rows: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Variant in rows:
		var row: Dictionary = r as Dictionary
		out.append({"name": str(row.get("name", "")), "color": Color.from_string(str(row.get("hex", "")), Color.WHITE)})
	return out


func all_items() -> Array[Dictionary]:
	return _items


func has_item(id: String) -> bool:
	return _by_id.has(id)


## The item dictionary for an id, or {} when unknown.
func item(id: String) -> Dictionary:
	return _by_id.get(id, {}) as Dictionary


func items_in(slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in _items:
		if it["slot"] == slot:
			out.append(it)
	return out


## Items of a slot that the given body type may wear, catalog order.
func items_for(slot: String, body: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in items_in(slot):
		if (it["bodies"] as Array).has(body):
			out.append(it)
	return out


func fits_body(id: String, body: String) -> bool:
	return has_item(id) and (item(id)["bodies"] as Array).has(body)


func starter_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for it: Dictionary in _items:
		if it.get("starter", false):
			out.append(str(it["id"]))
	return out


func is_starter(id: String) -> bool:
	return bool(item(id).get("starter", false))


func color_count(id: String) -> int:
	return (item(id).get("colors", []) as Array).size()


## Colour variant `index` of an item (clamped). White when the item has none.
func color_of(id: String, index: int) -> Color:
	var cols: Array = item(id).get("colors", [])
	if cols.is_empty():
		return Color.WHITE
	return Color.from_string(str(cols[clampi(index, 0, cols.size() - 1)]), Color.WHITE)


func color_name(id: String, index: int) -> String:
	var names_: Array = item(id).get("color_names", [])
	if names_.is_empty():
		return ""
	return str(names_[clampi(index, 0, names_.size() - 1)])


## The shop categories as dictionaries {id, name, slots}.
func category_items(category_id: String, body: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cat: Dictionary in categories:
		if cat["id"] != category_id:
			continue
		for slot: Variant in cat["slots"]:
			out.append_array(items_for(str(slot), body))
	return out


## Index of the palette entry closest to `c` (exact match preferred), 0 when the palette is empty.
static func palette_index(palette: Array[Dictionary], c: Color) -> int:
	var best: int = 0
	var best_d: float = 1e9
	for i: int in palette.size():
		var p: Color = palette[i]["color"]
		var dist: float = absf(p.r - c.r) + absf(p.g - c.g) + absf(p.b - c.b)
		if dist < best_d:
			best_d = dist
			best = i
	return best
