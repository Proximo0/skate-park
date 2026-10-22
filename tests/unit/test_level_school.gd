extends TestCase
## School level: its gap, goal and bot-route files agree with the built level (every zone and pickup exists), it
## carries enough lines (gaps, grind edges, lips, a secret), and it stays inside the world-kit budgets.

const DIR: String = "res://game/levels/school/"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _make() -> SchoolLevel:
	var lvl: SchoolLevel = LevelRegistry.create("school") as SchoolLevel
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
	var lvl: SchoolLevel = _make()
	var zones: Dictionary = _zone_ids(lvl)
	for g: Dictionary in _json("gaps.json")["gaps"]:
		assert_true(zones.has(str(g["start_zone"])), "%s start zone %s exists" % [g["id"], g["start_zone"]])
		assert_true(zones.has(str(g["end_zone"])), "%s end zone %s exists" % [g["id"], g["end_zone"]])
	lvl.free()


func test_goals_parse_and_every_collect_item_is_placed() -> void:
	var goals: Array = _json("goals.json")["goals"]
	assert_true(goals.size() >= 10, "about ten goals (%d)" % goals.size())
	var lvl: SchoolLevel = _make()
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


func test_bot_route_expects_only_real_gaps() -> void:
	var names: Dictionary = {}
	for g: Dictionary in _json("gaps.json")["gaps"]:
		names[str(g["name"])] = true
	var route: Dictionary = LevelRoute.load_file(DIR + "bot_route.json")
	assert_true((route["lines"] as Array).size() >= 10, "the bot rides at least ten lines")
	for l: Dictionary in route["lines"]:
		for e: Variant in l["expect"]:
			assert_true(names.has(str(e)), "line %s expects gap '%s' from gaps.json" % [l["name"], e])


func test_enough_grind_edges_and_lips() -> void:
	var lvl: SchoolLevel = _make()
	var rails: int = 0
	for n: Node in lvl.find_children("*", "", true, false):
		if n.is_in_group("grind_rail"):
			rails += 1
	assert_true(rails >= 25, "at least 25 grindable edges (%d)" % rails)
	var lips: int = lvl.find_children("*", "RampLip", true, false).size()
	assert_true(lips >= 3, "ramp lips on the transitions (%d)" % lips)
	lvl.free()


func test_within_world_kit_budgets() -> void:
	var lvl: SchoolLevel = _make()
	var lights: int = 0
	for n: Node in lvl.find_children("*", "Light3D", true, false):
		if not (n is DirectionalLight3D):
			lights += 1
	assert_true(lights <= 12, "about 12 real lights at most (%d)" % lights)
	var crowd: Pedestrians = lvl.get_node("Pedestrians") as Pedestrians
	assert_true(crowd.people.size() >= 5 and crowd.people.size() <= 25, "a few people (%d)" % crowd.people.size())
	var traffic: Traffic = lvl.get_node("Traffic") as Traffic
	assert_true(traffic.cars.size() > 0 and traffic.cars.size() <= 20, "perimeter traffic (%d cars)" % traffic.cars.size())
	for c: TrafficCar in traffic.cars:
		var p: Vector3 = c.global_position
		assert_false(lvl.bounds.grow(-1.0).has_point(Vector2(p.x, p.z)), "cars stay on the perimeter road")
	lvl.free()


func test_gym_roof_is_reachable_and_the_tape_is_up_there() -> void:
	var lvl: SchoolLevel = _make()
	var tape: Collectible = null
	for c: Collectible in lvl.collectibles:
		if c.item == "tape":
			tape = c
	assert_true(tape != null, "the tape exists")
	if tape != null:
		assert_true(tape.position.y > SchoolLevel.GYM_Y, "the tape sits on the gym roof")
		var under: bool = false
		for n: Node in lvl.find_children("*", "CollisionShape3D", true, false):
			var cs: CollisionShape3D = n as CollisionShape3D
			if cs.shape == null:
				continue
			var bb: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
			var top: float = bb.end.y
			if bb.has_point(Vector3(tape.position.x, top - 0.01, tape.position.z)) and top <= tape.position.y and top > tape.position.y - 2.0:
				under = true
		assert_true(under, "solid roof under the tape")
	lvl.free()


func test_subtract_cuts_holes_without_overlap() -> void:
	var r := Rect2(0.0, 0.0, 10.0, 10.0)
	var parts: Array[Rect2] = SchoolLevel.subtract(r, [Rect2(3.0, 3.0, 4.0, 4.0)])
	var area: float = 0.0
	for p: Rect2 in parts:
		area += p.get_area()
		assert_false(p.intersects(Rect2(3.0, 3.0, 4.0, 4.0)), "no piece overlaps the hole")
	assert_near(area, 100.0 - 16.0, 0.001, "pieces cover the rest exactly")
