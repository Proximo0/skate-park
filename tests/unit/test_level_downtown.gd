extends TestCase
## Downtown level: the plan's layout rules, the content counts (gaps, goals, rails, pickups), that every gap zone
## exists, that the life is in budget, and the batching helpers.

const DIR: String = "res://game/levels/downtown/"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _json(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DIR + file)) as Dictionary


func test_plan_blocks_and_roads_do_not_overlap() -> void:
	for b: Rect2 in DtPlan.grid_blocks():
		for x: float in DtPlan.OUTER_X:
			assert_false(b.position.x < x + DtPlan.ROAD_HALF and b.end.x > x - DtPlan.ROAD_HALF,
				"block %s clear of the avenue at x=%.0f" % [b, x])
		for z: float in DtPlan.OUTER_Z:
			assert_false(b.position.y < z + DtPlan.ROAD_HALF and b.end.y > z - DtPlan.ROAD_HALF,
				"block %s clear of the street at z=%.0f" % [b, z])
	assert_true(DtPlan.on_road(DtPlan.X_W, 0.0), "the west avenue is a road")
	assert_false(DtPlan.on_road(DtPlan.SPAWN.x, DtPlan.SPAWN.z), "the spawn is off the road")


func test_station_and_garage_clear_the_trains() -> void:
	var train_edge: float = DtPlan.BEAM_B + DtTrain.HALF_W
	assert_true(DtPlan.STATION.position.y > train_edge, "platform edge clears the train body")
	assert_true(DtPlan.GARAGE.position.y > train_edge, "garage clears the train body")
	assert_near(DtPlan.ROOF, DtPlan.MONO_Y, 0.001, "garage roof level with the beams (Roof To Line)")


func test_batch_builds_vertex_coloured_mesh() -> void:
	var bt := DtBatch.new()
	assert_true(bt.is_empty())
	bt.box(Vector3.ZERO, Vector3.ONE, Color.RED)
	bt.tri(Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 0, 1), Color.BLUE, Vector3.UP)
	var m: ArrayMesh = bt.mesh()
	assert_eq(m.get_surface_count(), 1, "one surface")
	var arr: Array = m.surface_get_arrays(0)
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	assert_eq(cols.size(), verts.size(), "a colour per vertex")
	# the triangle faces up whatever order its corners came in
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	assert_true(nrm[nrm.size() - 1].y > 0.9, "triangle wound toward its outward hint")


func test_cloth_mesh_spans_the_unit_square() -> void:
	var m: ArrayMesh = DtLife.cloth_mesh(4, 3)
	var aabb: AABB = m.get_aabb()
	assert_near(aabb.size.x, 1.0, 0.001)
	assert_near(aabb.size.y, 1.0, 0.001)
	assert_near(aabb.position.y, -1.0, 0.001, "hangs down from y = 0")


func test_gaps_and_goals_files() -> void:
	var gaps: Array = _json("gaps.json")["gaps"]
	var goals: Array = _json("goals.json")["goals"]
	assert_true(gaps.size() >= 12, "at least 12 named gaps (%d)" % gaps.size())
	assert_true(goals.size() >= 10, "about 10 goals (%d)" % goals.size())
	var ids: Dictionary = {}
	for g: Variant in gaps:
		var gap: Dictionary = g
		assert_false(ids.has(gap["id"]), "gap id %s is unique" % gap["id"])
		ids[gap["id"]] = true
		assert_true(str(gap["require"]) in Gaps.VALID_REQUIRE, "%s require is valid" % gap["id"])
	var g := Goals.new()
	assert_true(g.load_from_dict(_json("goals.json")), "goals parse")


func test_level_content() -> void:
	var lvl: Level = LevelRegistry.create("downtown")
	_tree().root.add_child(lvl)
	# every gap's zones exist
	var zones: Dictionary = {}
	for n: Node in lvl.find_children("*", "Area3D", true, false):
		if n.is_in_group("gap_zone"):
			zones[str(n.get_meta("zone_id", ""))] = true
	for gv: Variant in _json("gaps.json")["gaps"]:
		var gap: Dictionary = gv
		assert_true(zones.has(str(gap["start_zone"])), "zone %s exists" % gap["start_zone"])
		assert_true(zones.has(str(gap["end_zone"])), "zone %s exists" % gap["end_zone"])
	# grindable edges inside the play area
	var rails: int = 0
	for n: Node in lvl.find_children("*", "GrindRail", true, false):
		var r: GrindRail = n as GrindRail
		var p0: Vector3 = r.global_points()[0]
		if lvl.bounds.grow(1.0).has_point(Vector2(p0.x, p0.z)):
			rails += 1
	assert_true(rails >= 25, "at least 25 grindable edges (%d)" % rails)
	assert_true(lvl.find_children("*", "RampLip", true, false).size() >= 4, "transitions carry ramp lips")
	# every collect goal can be met by the pickups placed
	var items: Dictionary = {}
	for c: Collectible in lvl.collectibles:
		items[c.item] = int(items.get(c.item, 0)) + 1
	for gv: Variant in _json("goals.json")["goals"]:
		var goal: Dictionary = gv
		if str(goal["type"]) != "collect":
			continue
		var need: Dictionary = {}
		for it: Variant in goal["items"]:
			need[str(it)] = int(need.get(str(it), 0)) + 1
		for it: String in need:
			assert_true(int(items.get(it, 0)) >= int(need[it]), "%s: %d x %s placed" % [goal["id"], need[it], it])
	# the drop-ins the bot route uses exist
	for spot: String in ["platform", "garage_roof", "alley"]:
		assert_true(lvl.drop_ins.has(spot), "drop-in " + spot)
	# life in budget: 15-25 people, about 20 cars, trains on the Line
	var dt: DowntownLevel = lvl as DowntownLevel
	var people: int = dt.life.crowd.people.size()
	assert_true(people >= 15 and people <= 25, "15 to 25 people (%d)" % people)
	assert_true(dt.traffic.cars.size() >= 18, "the busiest traffic (%d cars)" % dt.traffic.cars.size())
	assert_eq(dt.transit.trains.size(), 2, "a train each way on the Line")
	lvl.free()
