class_name Unlocks
extends RefCounted
## What finishing goals opens, from data/unlocks.json (the number of goals done over every level is the key):
## - items: shop items that stay locked until N goals are done, then cost coins as usual. "reward": true items are
##   handed over for free instead (sync_wallet puts them in the wallet's owned list).
## - specials: the special tricks, each unlocked at N goals. The player carries only a few of them at once: the slots
##   (special_slots) grow with goals. equipped_specials() is the saved pick made valid, apply_specials() takes the
##   rest out of a TrickDB so the skater cannot trigger them.
## Pure data and lookups: no nodes. Saved careers keep working: nothing here is stored, it all follows the goal count.

const DATA_PATH: String = "res://data/unlocks.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_cache = parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {"items": {}, "specials": [], "special_slots": []}
	return _cache


## Test hook: replace the data (an empty dictionary reloads the file).
static func set_data(d: Dictionary) -> void:
	_cache = d


# --- shop items -------------------------------------------------------------------------------------------------

## Goals an item needs, 0 when it is open from the start.
static func item_goals(id: String) -> int:
	var items: Dictionary = data().get("items", {}) as Dictionary
	if not items.has(id) or typeof(items[id]) != TYPE_DICTIONARY:
		return 0
	return maxi(int((items[id] as Dictionary).get("goals", 0)), 0)


static func is_reward(id: String) -> bool:
	var items: Dictionary = data().get("items", {}) as Dictionary
	return items.has(id) and typeof(items[id]) == TYPE_DICTIONARY and bool((items[id] as Dictionary).get("reward", false))


static func item_locked(id: String, goals_done: int) -> bool:
	return goals_done < item_goals(id)


## Goals still needed for the item, 0 when open.
static func goals_missing(id: String, goals_done: int) -> int:
	return maxi(item_goals(id) - goals_done, 0)


## Every item id the data names, shop order not guaranteed.
static func item_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in (data().get("items", {}) as Dictionary).keys():
		out.append(str(k))
	return out


## Reward items the player has earned by now.
static func earned_rewards(goals_done: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in item_ids():
		if is_reward(id) and not item_locked(id, goals_done):
			out.append(id)
	return out


## Puts every earned reward in the wallet's owned list. Returns the ids that were new (empty = nothing to announce).
static func sync_wallet(wallet: Wallet, goals_done: int) -> PackedStringArray:
	var fresh: PackedStringArray = []
	if wallet == null:
		return fresh
	var cat: PartCatalog = PartCatalog.load_default()
	for id: String in earned_rewards(goals_done):
		if cat.has_item(id) and not wallet.owned.has(id) and not cat.is_starter(id):
			wallet.owned[id] = true
			fresh.append(id)
	return fresh


## Items (rewards included) that this goal total opened that the previous total had not: for the "UNLOCKED" banner.
static func opened_between(before: int, after: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in item_ids():
		var need: int = item_goals(id)
		if need > before and need <= after:
			out.append(id)
	return out


static func item_name(id: String) -> String:
	var it: Dictionary = PartCatalog.load_default().item(id)
	return str(it.get("name", id))


# --- specials ---------------------------------------------------------------------------------------------------

static func special_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in data().get("specials", []) as Array:
		if typeof(e) == TYPE_DICTIONARY and str((e as Dictionary).get("id", "")) != "":
			out.append(e as Dictionary)
	return out


static func special_goals(id: String) -> int:
	for e: Dictionary in special_entries():
		if str(e["id"]) == id:
			return maxi(int(e.get("goals", 0)), 0)
	return 0


static func special_unlocked(id: String, goals_done: int) -> bool:
	return goals_done >= special_goals(id)


## Special ids open at this goal total, data order.
static func unlocked_specials(goals_done: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for e: Dictionary in special_entries():
		if goals_done >= int(e.get("goals", 0)):
			out.append(str(e["id"]))
	return out


## How many specials the player may carry at this goal total.
static func special_slots(goals_done: int) -> int:
	var slots: int = 1
	for e: Variant in data().get("special_slots", []) as Array:
		if typeof(e) == TYPE_DICTIONARY and goals_done >= int((e as Dictionary).get("goals", 0)):
			slots = maxi(slots, int((e as Dictionary).get("slots", 1)))
	return slots


## The saved pick, made valid: unlocked specials only, no repeats, at most the slot count. A career that never chose
## (saved = null) carries the first unlocked ones, as many as the slots allow.
static func equipped_specials(saved: Variant, goals_done: int) -> PackedStringArray:
	var open: PackedStringArray = unlocked_specials(goals_done)
	var cap: int = special_slots(goals_done)
	var out: PackedStringArray = []
	if typeof(saved) == TYPE_ARRAY:
		for s: Variant in saved as Array:
			var id: String = str(s)
			if open.has(id) and not out.has(id) and out.size() < cap:
				out.append(id)
		return out
	for id: String in open:
		if out.size() < cap:
			out.append(id)
	return out


## Takes every special the data names but the equipped ones out of the trick table, so only those can be triggered.
## Specials the data does not name (added later) stay. Returns how many were taken out.
static func apply_specials(db: TrickDB, equipped: PackedStringArray) -> int:
	if db == null:
		return 0
	var named: PackedStringArray = []
	for e: Dictionary in special_entries():
		named.append(str(e["id"]))
	var tricks: Array[Dictionary] = db._tricks
	var removed: int = 0
	var i: int = tricks.size() - 1
	while i >= 0:
		var t: Dictionary = tricks[i]
		var id: String = str(t.get("id", ""))
		if str(t.get("kind", "")) == "special" and named.has(id) and not equipped.has(id):
			tricks.remove_at(i)
			removed += 1
		i -= 1
	return removed
