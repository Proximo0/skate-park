class_name ShopStation
extends RefCounted
## One interactive spot in the walk-in shop: where the player stands to use it, how close counts, the prompt text
## and the action. Pure data and maths (no nodes), unit tested in tests/unit/test_shop.gd.
## Actions: "shop" (SkateShop on the category id in `arg`), "creator" (CharacterCreator on the tab index in `arg`),
## "sit" (sit on the couch), "exit" (leave through the front door).

const PROMPT_KEYS: String = "E / A"

var id: String = ""
var prompt: String = ""
var action: String = ""
var arg: String = ""
var stand: Vector3 = Vector3.ZERO  ## floor point the player stands on to use it
var radius: float = 1.2  ## horizontal distance from `stand` that still counts as "at" the station


static func make(id_: String, prompt_: String, action_: String, arg_: String, stand_: Vector3,
		radius_: float = 1.2) -> ShopStation:
	var s: ShopStation = ShopStation.new()
	s.id = id_
	s.prompt = prompt_
	s.action = action_
	s.arg = arg_
	s.stand = stand_
	s.radius = radius_
	return s


## Horizontal (XZ) distance from a world point to the stand point.
func distance_to(pos: Vector3) -> float:
	return Vector2(pos.x - stand.x, pos.z - stand.z).length()


func contains(pos: Vector3) -> bool:
	return distance_to(pos) <= radius


## The station whose zone holds `pos` and whose stand point is nearest, or null.
static func nearest(stations: Array[ShopStation], pos: Vector3) -> ShopStation:
	var best: ShopStation = null
	var best_d: float = INF
	for s: ShopStation in stations:
		var d: float = s.distance_to(pos)
		if d <= s.radius and d < best_d:
			best = s
			best_d = d
	return best


static func by_id(stations: Array[ShopStation], id_: String) -> ShopStation:
	for s: ShopStation in stations:
		if s.id == id_:
			return s
	return null


## "Press E / A to <prompt>".
static func prompt_text(s: ShopStation) -> String:
	return "" if s == null else "Press %s to %s" % [PROMPT_KEYS, s.prompt]


## Index of a SkateShop category id in the catalog's category list, 0 when unknown.
static func category_index(cat: PartCatalog, category_id: String) -> int:
	for i: int in cat.categories.size():
		if str(cat.categories[i].get("id", "")) == category_id:
			return i
	return 0
