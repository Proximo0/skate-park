class_name Wallet
extends RefCounted
## The player's coins and the shop items they own. Coins are earned from landed combos and finished goals.
## Starter items from the catalog are always owned. Saved as JSON at user://wallet.json.

const SAVE_PATH: String = "user://wallet.json"
const START_COINS: int = 120
const COINS_PER_GOAL: int = 25
const POINTS_PER_COIN: int = 100
const MAX_COINS_PER_COMBO: int = 40

var coins: int = START_COINS
var owned: Dictionary = {}  ## item id -> true, bought items only


## Coins a landed combo is worth: one per 100 points, at least 1 and at most MAX_COINS_PER_COMBO.
static func coins_for_combo(points: int) -> int:
	if points <= 0:
		return 0
	return clampi(points / POINTS_PER_COIN, 1, MAX_COINS_PER_COMBO)


func add(amount: int) -> void:
	coins = maxi(coins + amount, 0)


func can_afford(price: int) -> bool:
	return coins >= price


func owns(id: String) -> bool:
	return owned.has(id) or PartCatalog.load_default().is_starter(id)


## Buys an item at the catalog price. False when unknown, already owned or too expensive.
func buy(id: String) -> bool:
	var cat: PartCatalog = PartCatalog.load_default()
	if not cat.has_item(id) or owns(id):
		return false
	var price: int = int(cat.item(id)["price"])
	if not can_afford(price):
		return false
	coins -= price
	owned[id] = true
	return true


func to_dict() -> Dictionary:
	return {"version": 1, "coins": coins, "owned": owned.keys()}


static func from_dict(d: Dictionary) -> Wallet:
	var w: Wallet = Wallet.new()
	w.coins = maxi(int(d.get("coins", START_COINS)), 0)
	for id: Variant in d.get("owned", []):
		w.owned[str(id)] = true
	return w


func save(path: String = SAVE_PATH) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return true


## Reads a saved wallet. Missing or broken file gives a fresh one with the starting coins.
static func load_file(path: String = SAVE_PATH) -> Wallet:
	if not FileAccess.file_exists(path):
		return Wallet.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return Wallet.new()
	return from_dict(parsed as Dictionary)
