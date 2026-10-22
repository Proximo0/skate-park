extends TestCase
## Creepy Warehouse level: its gap, goal and bot-route files agree with the built level (every zone and pickup exists),
## it carries enough lines (gaps, grind edges, lips, a secret room), and it stays inside the world-kit budgets.

const DIR: String = "res://game/levels/warehouse/"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _make() -> WarehouseLevel:
	var lvl: WarehouseLevel = LevelRegistry.create("warehouse") as WarehouseLevel
	_tree().root.add_child(lvl)
	return lvl


func _json(file: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + file))
	return parsed as Dictionary if parsed is Dictionary else {}


func _zone_ids(lvl: Node) -> Dictionary:
	var out: Dictionary = {}
	for n: Node in lvl.find_children("*", "Area3D", true, false):
		if n.is_in_group("gap_zone"):
			out[str(n.get_meta("zone_id", ""))] = true
	return out


func test_gaps_parse_and_every_zone_exists() -> void:
	var gaps := Gaps.new()
	gaps.load_from_dict(_json("gaps.json"))
	assert_true(gaps.total_count() >= 12, "at least 12 named gaps (%d)" % gaps.total_count())
	var lvl: WarehouseLevel = _make()
	var zones: Dictionary = _zone_ids(lvl)
	for g: Dictionary in _json("gaps.json")["gaps"]:
		assert_true(zones.has(str(g["start_zone"])), "%s start zone %s exists" % [g["id"], g["start_zone"]])
		assert_true(zones.has(str(g["end_zone"])), "%s end zone %s exists" % [g["id"], g["end_zone"]])
	lvl.free()


func test_goals_parse_and_every_collect_item_is_placed() -> void:
	var goals: Array = _json("goals.json")["goals"]
	assert_true(goals.size() >= 10, "about ten goals (%d)" % goals.size())
	var lvl: WarehouseLevel = _make()
	var placed: Dictionary = {}
	for c: Collectible in lvl.collectibles:
		placed[c.item] = int(placed.get(c.item, 0)) + 1
		assert_true(lvl.bounds.has_point(Vector2(c.position.x, c.position.z)), "%s pickup inside the bounds" % c.item)
	for g: Dictionary in goals:
		if str(g["type"]) != "collect":
			continue
		var need: Dictionary = {}
		for it: Variant in g["items"]:
			need[str(it)] = int(need.get(str(it), 0)) + 1
		for it: String in need:
			assert_true(int(placed.get(it, 0)) >= int(need[it]), "goal %s: %d x %s placed" % [g["id"], need[it], it])
	assert_eq(int(placed.get("tape", 0)), 1, "one secret tape")
	lvl.free()


func test_bot_route_expects_real_gaps_and_covers_most_of_them() -> void:
	var names: Dictionary = {}
	for g: Dictionary in _json("gaps.json")["gaps"]:
		names[str(g["name"])] = true
	var route: Dictionary = LevelRoute.load_file(DIR + "bot_route.json")
	assert_true((route["lines"] as Array).size() >= 12, "the bot rides at least twelve lines")
	var seen: Dictionary = {}
	for l: Dictionary in route["lines"]:
		for e: Variant in l["expect"]:
			assert_true(names.has(str(e)), "line %s expects gap '%s' from gaps.json" % [l["name"], e])
			seen[str(e)] = true
	assert_true(seen.size() >= 12, "at least 12 gaps are bot-verified (%d)" % seen.size())


func test_enough_grind_edges_and_lips() -> void:
	var lvl: WarehouseLevel = _make()
	var rails: int = 0
	for n: Node in lvl.find_children("*", "", true, false):
		if n.is_in_group("grind_rail"):
			rails += 1
	assert_true(rails >= 25, "at least 25 grindable edges (%d)" % rails)
	var lips: int = lvl.find_children("*", "RampLip", true, false).size()
	assert_true(lips >= 3, "ramp lips on the transitions (%d)" % lips)
	lvl.free()


func test_within_world_kit_budgets() -> void:
	var lvl: WarehouseLevel = _make()
	var lights: int = 0
	for n: Node in lvl.find_children("*", "Light3D", true, false):
		if not (n is DirectionalLight3D) and (n as Light3D).visible:
			lights += 1
	assert_true(lights <= 20, "about a dozen real lights in view, 20 at most in all (%d)" % lights)
	var cars: int = 0
	for n: Node in lvl.find_children("*", "Traffic", true, false):
		var t: Traffic = n as Traffic
		cars += t.cars.size()
		for c: TrafficCar in t.cars:
			var p: Vector3 = c.global_position
			assert_false(lvl.bounds.has_point(Vector2(p.x, p.z)), "traffic stays outside the skate area")
	assert_true(cars > 0 and cars <= 20, "distant traffic (%d cars)" % cars)
	var crowd: Pedestrians = lvl.find_child("Crowd", true, false) as Pedestrians
	assert_true(crowd != null, "the crowd exists")
	if crowd != null:
		assert_true(crowd.people.size() >= 2 and crowd.people.size() <= 8, "sparse people (%d)" % crowd.people.size())
	lvl.free()


func test_spawn_is_over_a_floor_inside_the_bounds() -> void:
	var lvl: WarehouseLevel = _make()
	var sp: Vector3 = lvl.spawn.origin
	assert_true(lvl.bounds.has_point(Vector2(sp.x, sp.z)), "spawn inside the bounds")
	assert_true(sp.y > -0.5 and sp.y < 3.0, "spawn near the ground (%.2f)" % sp.y)
	lvl.free()
