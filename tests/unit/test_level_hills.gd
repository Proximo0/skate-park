extends TestCase
## The Hills: the height field and the streets cut into it, the kidney pool piece, and the level's content (gaps and
## their zones, goals and their pickups, grind edges, ramp lips).


func test_natural_hillside_falls_toward_the_valley() -> void:
	var top: float = HillsTerrain.natural(0.0, -100.0)
	var mid: float = HillsTerrain.natural(0.0, 0.0)
	var low: float = HillsTerrain.natural(0.0, 100.0)
	assert_true(top > mid + 8.0 and mid > low + 8.0, "downhill toward +Z: %.1f %.1f %.1f" % [top, mid, low])
	assert_true(HillsTerrain.natural(0.0, 400.0) < low - 30.0, "the valley floor is far below")


func test_flat_rect_levels_the_ground_and_height_at_interpolates() -> void:
	var t := HillsTerrain.new()
	t.flat_rect(Rect2(-10.0, -10.0, 20.0, 20.0), 12.5, Vector4(4.0, 4.0, 4.0, 4.0))
	for p: Vector2 in [Vector2(0.0, 0.0), Vector2(-9.5, 9.5), Vector2(3.3, -7.1)]:
		assert_near(t.height_at(p.x, p.y), 12.5, 0.001, "flat inside at %s" % p)
	var n: Vector3 = t.normal_at(0.5, 0.5)
	assert_near(n.y, 1.0, 0.001, "level ground has an up normal")


func test_streets_are_cut_into_the_ground_with_gentle_grades() -> void:
	var lvl: HillsLevel = LevelRegistry.create("hills") as HillsLevel
	(Engine.get_main_loop() as SceneTree).root.add_child(lvl)
	for rn: String in ["hillcrest", "canyon", "crest", "valley", "summit", "sunset"]:
		var r: HillsRoad = lvl.roads[rn]
		var s: float = 2.0
		var worst_grade: float = 0.0
		var worst_off: float = 0.0
		while s < r.length - 2.0:
			var c: Vector3 = r.sample(s)
			if lvl.bounds.has_point(Vector2(c.x, c.z)):
				worst_off = maxf(worst_off, absf(lvl.terrain.height_at(c.x, c.z) - c.y))
				var c2: Vector3 = r.sample(s + 1.0)
				worst_grade = maxf(worst_grade, absf(c2.y - c.y))
			s += 1.0
		assert_true(worst_off < 0.25, "%s: ground follows the street (off by %.3f)" % [rn, worst_off])
		assert_true(worst_grade < 0.33, "%s: grade under 33%% (%.3f)" % [rn, worst_grade])
	var hc: HillsRoad = lvl.roads["hillcrest"]
	assert_true(hc.sample(hc.length).y - hc.sample(0.0).y > 15.0, "Hillcrest drops more than 15 m")
	lvl.free()


func test_road_right_is_perpendicular_and_level() -> void:
	var r: HillsRoad = HillsRoad.through("t", PackedVector2Array([Vector2(0.0, 0.0), Vector2(20.0, 5.0), Vector2(40.0, 0.0), Vector2(60.0, 10.0)]))
	var s: float = 0.5
	while s < r.length - 0.5:
		var t: Vector3 = r.tangent(s)
		var rt: Vector3 = r.right(s)
		assert_near(rt.y, 0.0, 0.001, "right is level")
		assert_near(Vector2(t.x, t.z).normalized().dot(Vector2(rt.x, rt.z)), 0.0, 0.02, "right is square to the street")
		s += 3.0


func test_kidney_pool_has_coping_lip_and_zones() -> void:
	var pool: Node3D = HillsPool.build(Vector2(12.0, 8.0), 5.0, 2.9, 2.1, 1.0, 1.9, 3.4, 0.2, "tp")
	var rails: int = pool.find_children("*", "GrindRail", true, false).size()
	var lips: int = pool.find_children("*", "RampLip", true, false).size()
	assert_true(rails >= 1, "coping grind line")
	assert_true(lips >= 1, "ramp lip ring")
	var ids: Array[String] = []
	for n: Node in pool.find_children("*", "Area3D", true, false):
		ids.append(str(n.get_meta("zone_id", "")))
	for want: String in ["tp_air", "tp_w", "tp_e"]:
		assert_true(want in ids, "zone %s" % want)
	assert_near(HillsPool.depth_at(0.0, 5.0, 2.1, 1.0), 2.1, 0.001, "deep in the middle")
	assert_near(HillsPool.depth_at(5.0, 5.0, 2.1, 1.0), 1.0, 0.001, "shallow at the ends")
	pool.free()


func test_level_content_counts() -> void:
	var gaps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/levels/hills/gaps.json"))
	var goals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/levels/hills/goals.json"))
	assert_true((gaps["gaps"] as Array).size() >= 12, "at least 12 gaps")
	assert_true((goals["goals"] as Array).size() >= 10, "about 10 goals")
	var lvl: Level = LevelRegistry.create("hills")
	(Engine.get_main_loop() as SceneTree).root.add_child(lvl)
	var zones: Dictionary = {}
	for n: Node in lvl.find_children("*", "Area3D", true, false):
		if n.is_in_group("gap_zone"):
			zones[str(n.get_meta("zone_id", ""))] = true
	for g: Variant in gaps["gaps"]:
		var gap: Dictionary = g
		assert_true(zones.has(str(gap["start_zone"])), "zone %s exists" % gap["start_zone"])
		assert_true(zones.has(str(gap["end_zone"])), "zone %s exists" % gap["end_zone"])
	# every collect goal's items are in the level
	var items: Dictionary = {}
	for c: Collectible in lvl.collectibles:
		items[c.item] = int(items.get(c.item, 0)) + 1
	for g: Variant in goals["goals"]:
		var goal: Dictionary = g
		if str(goal["type"]) != "collect":
			continue
		var want: Dictionary = {}
		for it: Variant in goal["items"]:
			want[str(it)] = int(want.get(str(it), 0)) + 1
		for k: String in want:
			assert_true(int(items.get(k, 0)) >= int(want[k]), "%s: %d x %s placed" % [goal["id"], want[k], k])
	var rails: int = lvl.find_children("*", "GrindRail", true, false).size()
	var lips: int = lvl.find_children("*", "RampLip", true, false).size()
	assert_true(rails >= 25, "at least 25 grind edges (%d)" % rails)
	assert_true(lips >= 4, "ramp lips for snap (%d)" % lips)
	lvl.free()
