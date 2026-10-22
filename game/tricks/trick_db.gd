class_name TrickDB
extends RefCounted
## Trick table loaded from data/tricks.json. Pure data lookups, no Node, no clock.
##
## Lookup rules:
## - find() matches flip, grab and grind tricks only (exact button, dir and double_tap).
##   If the exact trick is missing it falls back to the neutral ("") trick of that button
##   with the same double_tap, then to the neutral non-double trick. Otherwise {}.
## - find_lip() matches lip tricks (button "grind") by dir and double_tap, falling back to the single-tap trick of that
##   dir, then to the nose stall. on_ledge keeps to the tricks marked "ledge": true (stalls that work on a ledge's edge,
##   not only on a coping: no inverts or plants on a ledge).
## - find_sequence() matches manuals and specials by sequence and button.
## - find_move() looks up a board move by id (kind "move": wallplant, boneless, no_comply, caveman, acid_drop). Moves are
##   started by the skater's own rules (a button in a situation), never matched from a button and dir.
## - find_flatland() matches the tricks done inside a manual (kind "flatland": button "grab" + dir, falling back to the
##   neutral one; the "spin" button's 180 pivot).
## - find_link() looks up a link by id (kind "link": rail_transfer, wall_to_rail), the bonuses for joining one balance
##   trick to the next through the air. The skater scores them like gaps (no repeat penalty).
## Returned dictionaries are copies; callers may mutate them.

const DATA_PATH: String = "res://data/tricks.json"
const REQUIRED_FIELDS: PackedStringArray = [
	"id", "name", "kind", "button", "dir", "double_tap", "points",
	"anim", "hold", "sequence", "points_per_sec",
]
const VALID_KINDS: PackedStringArray = ["flip", "grab", "grind", "manual", "lip", "special", "move", "flatland", "link"]
## The board moves the skater scores by id (THUG2 move set); every one must be in the table.
const MOVE_IDS: PackedStringArray = ["wallplant", "boneless", "no_comply", "caveman", "acid_drop"]
## The links the skater scores by id; every one must be in the table.
const LINK_IDS: PackedStringArray = ["rail_transfer", "wall_to_rail"]
const VALID_DIRS: PackedStringArray = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", ""]
const MATCHABLE_KINDS: PackedStringArray = ["flip", "grab", "grind"]
const NEUTRAL_BUTTONS: PackedStringArray = ["flip", "grab", "grind"]

var _tricks: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _by_key: Dictionary = {}


static func load_default() -> TrickDB:
	var db: TrickDB = TrickDB.new()
	db.load_from_path(DATA_PATH)
	return db


## Reads a tricks file of the form {"tricks": [...]}. Returns false if it cannot be read.
func load_from_path(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("TrickDB: missing %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("TrickDB: %s is not a JSON object" % path)
		return false
	var root: Dictionary = parsed
	var list: Variant = root.get("tricks", [])
	if typeof(list) != TYPE_ARRAY:
		push_error("TrickDB: %s has no tricks array" % path)
		return false
	var entries: Array = list
	_load_list(entries)
	return true


func get_trick(id: String) -> Dictionary:
	if not _by_id.has(id):
		return {}
	var found: Dictionary = _by_id[id]
	return found.duplicate(true)


func find(button: String, dir: String, double_tap: bool) -> Dictionary:
	var key: String = _key(button, dir, double_tap)
	if _by_key.has(key):
		var exact: Dictionary = _by_key[key]
		return exact.duplicate(true)
	var neutral: String = _key(button, "", double_tap)
	if _by_key.has(neutral):
		var same_tap: Dictionary = _by_key[neutral]
		return same_tap.duplicate(true)
	var plain: String = _key(button, "", false)
	if _by_key.has(plain):
		var plain_hit: Dictionary = _by_key[plain]
		return plain_hit.duplicate(true)
	return {}


## Lip trick for a stick dir (any of the eight) and tap: the exact one, else that dir's single-tap trick, else the nose
## stall (or the first allowed one). on_ledge: only tricks with "ledge": true (a ledge stall).
func find_lip(dir: String, double_tap: bool = false, on_ledge: bool = false) -> Dictionary:
	var single: Dictionary = {}
	var fallback: Dictionary = {}
	for t: Dictionary in _tricks:
		if str(t.get("kind", "")) != "lip" or (on_ledge and not bool(t.get("ledge", false))):
			continue
		var tap: bool = bool(t.get("double_tap", false))
		if str(t.get("dir", "")) == dir:
			if tap == double_tap:
				return t.duplicate(true)
			if not tap:
				single = t
		if not tap and (fallback.is_empty() or str(t.get("dir", "")) == "N"):
			fallback = t
	if not single.is_empty():
		return single.duplicate(true)
	return fallback.duplicate(true)


## Manual or special whose sequence equals the given one and whose button matches.
## Manuals use button "".
func find_sequence(sequence: Array, button: String) -> Dictionary:
	for t: Dictionary in _tricks:
		var kind: String = str(t.get("kind", ""))
		if kind != "manual" and kind != "special":
			continue
		if str(t.get("button", "")) != button:
			continue
		var seq: Array = t.get("sequence", [])
		if seq == sequence:
			return t.duplicate(true)
	return {}


## A board move (kind "move") by id, or {} when there is none.
func find_move(id: String) -> Dictionary:
	if not _by_id.has(id) or str((_by_id[id] as Dictionary).get("kind", "")) != "move":
		return {}
	var found: Dictionary = _by_id[id]
	return found.duplicate(true)


## A flatland trick (done in a manual) for a button and stick dir: the exact dir, else the button's neutral one, else {}.
func find_flatland(button: String, dir: String) -> Dictionary:
	var neutral: Dictionary = {}
	for t: Dictionary in _tricks:
		if str(t.get("kind", "")) != "flatland" or str(t.get("button", "")) != button:
			continue
		if str(t.get("dir", "")) == dir:
			return t.duplicate(true)
		if str(t.get("dir", "")) == "":
			neutral = t
	return neutral.duplicate(true)


## A link (kind "link") by id, or {} when there is none.
func find_link(id: String) -> Dictionary:
	if not _by_id.has(id) or str((_by_id[id] as Dictionary).get("kind", "")) != "link":
		return {}
	var found: Dictionary = _by_id[id]
	return found.duplicate(true)


func by_kind(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in _tricks:
		if str(t.get("kind", "")) == kind:
			out.append(t.duplicate(true))
	return out


func ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for t: Dictionary in _tricks:
		out.append(str(t.get("id", "")))
	return out


func _load_list(list: Array) -> void:
	_tricks.clear()
	_by_id.clear()
	_by_key.clear()
	for item: Variant in list:
		if typeof(item) != TYPE_DICTIONARY:
			push_error("TrickDB: non-object entry in tricks")
			continue
		var t: Dictionary = item
		# JSON numbers parse as float; the table stores whole numbers as int.
		t["points"] = int(t.get("points", 0))
		t["points_per_sec"] = int(t.get("points_per_sec", 0))
		_tricks.append(t)
		var id: String = str(t.get("id", ""))
		if _by_id.has(id):
			push_error("TrickDB: duplicate id %s" % id)
		_by_id[id] = t
		if str(t.get("kind", "")) in MATCHABLE_KINDS:
			var key: String = _key(str(t.get("button", "")), str(t.get("dir", "")), bool(t.get("double_tap", false)))
			if _by_key.has(key):
				push_error("TrickDB: duplicate trick for %s" % key)
			_by_key[key] = t
	_validate()


func _validate() -> void:
	for t: Dictionary in _tricks:
		var id: String = str(t.get("id", "?"))
		for field: String in REQUIRED_FIELDS:
			if not t.has(field):
				push_error("TrickDB: %s missing field %s" % [id, field])
		if not (str(t.get("kind", "")) in VALID_KINDS):
			push_error("TrickDB: %s has bad kind" % id)
		if not (str(t.get("dir", "")) in VALID_DIRS):
			push_error("TrickDB: %s has bad dir" % id)
	for id: String in MOVE_IDS:
		if find_move(id).is_empty():
			push_error("TrickDB: missing move %s" % id)
	for id: String in LINK_IDS:
		if find_link(id).is_empty():
			push_error("TrickDB: missing link %s" % id)
	for button: String in NEUTRAL_BUTTONS:
		if not _by_key.has(_key(button, "", false)):
			push_error("TrickDB: no neutral trick for button %s" % button)


func _key(button: String, dir: String, double_tap: bool) -> String:
	return "%s|%s|%s" % [button, dir, "2" if double_tap else "1"]
