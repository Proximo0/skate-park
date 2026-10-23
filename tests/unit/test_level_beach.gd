extends TestCase
## Beachfront level: the snake run's heightfield, the slab cutter, the sand collision and the level's content counts.


func _snake() -> BeachSnake:
	return BeachSnake.make(BeachLevel.SNAKE_START, 0.0, BeachLevel.SNAKE_SEGS)


func test_snake_centre_line_is_continuous_and_ends_where_planned() -> void:
	var sn: BeachSnake = _snake()
	assert_true(sn.length > 60.0 and sn.length < 75.0, "snake length %.1f" % sn.length)
	var prev: Vector2 = (sn.at(0.0) as Array)[0]
	assert_true(prev.distance_to(BeachLevel.SNAKE_START) < 0.01, "starts at SNAKE_START")
	var s: float = 0.5
	while s <= sn.length:
		var p: Vector2 = (sn.at(s) as Array)[0]
		assert_true(p.distance_to(prev) < 0.51, "no jump in the centre line at s=%.1f" % s)
		prev = p
		s += 0.5
	var end: Vector2 = (sn.at(sn.length) as Array)[0]
	assert_near(end.y, BeachLevel.SNAKE_START.y, 0.05, "the S-bend comes back to the start's z")


func test_snake_depth_tapers_to_flush_ends_and_is_deepest_mid_run() -> void:
	var sn: BeachSnake = _snake()
	assert_near(sn.depth_at(0.0), 0.0, 0.001, "flush at the roll-in")
	assert_near(sn.depth_at(sn.length), 0.0, 0.001, "flush at the roll-out")
	assert_near(sn.depth_at(sn.length * 0.5), BeachSnake.DEPTH, 0.001, "full depth mid run")
	var mid: Vector2 = (sn.at(sn.length * 0.5) as Array)[0]
	assert_near(sn.height(mid.x, mid.y), -BeachSnake.DEPTH, 0.01, "floor height on the centre line")
	# well outside the reach the deck is flat
	assert_near(sn.height(mid.x, mid.y + 20.0), 0.0, 0.001, "deck outside the run")


func test_rects_minus_covers_outer_without_holes() -> void:
	var outer := Rect2(0, 0, 10, 10)
	var holes: Array[Rect2] = [Rect2(2, 2, 3, 3), Rect2(4, 4, 3, 3)]
	var parts: Array[Rect2] = BeachLevel.rects_minus(outer, holes)
	var area: float = 0.0
	for r: Rect2 in parts:
		area += r.get_area()
		for h: Rect2 in holes:
			assert_false(r.intersects(h), "piece %s overlaps hole %s" % [r, h])
		assert_true(outer.encloses(r), "piece inside outer")
	# 100 - (9 + 9 - 1 overlap)
	assert_near(area, 83.0, 0.001, "area of the remainder")


func test_sand_shape_is_tiled_and_follows_the_beach_profile() -> void:
	var shape: ConcavePolygonShape3D = BeachLevel.sand_shape(0.08, 1.2, 49.0, 90.0)
	var faces: PackedVector3Array = shape.get_faces()
	assert_true(faces.size() > 0 and faces.size() % 3 == 0, "triangles")
	var widest: float = 0.0
	for i: int in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		widest = maxf(widest, maxf(absf(a.x - b.x), maxf(absf(b.x - c.x), absf(a.x - c.x))))
		for p: Vector3 in [a, b, c]:
			assert_near(p.y, Ocean.sand_height(p.z, 0.08, 1.2), 0.15, "on the profile at z=%.1f" % p.z)
	assert_true(widest <= 4.001, "tiles no wider than 4 m (was %.1f)" % widest)


func test_level_content_counts() -> void:
	var gaps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/levels/beach/gaps.json"))
	var goals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/levels/beach/goals.json"))
	assert_true((gaps["gaps"] as Array).size() >= 12, "at least 12 gaps")
	assert_true((goals["goals"] as Array).size() >= 10, "about 10 goals")
	var lvl: Level = LevelRegistry.create("beach")
	(Engine.get_main_loop() as SceneTree).root.add_child(lvl)
	var zones: Dictionary = {}
	for n: Node in lvl.find_children("*", "Area3D", true, false):
		if n.is_in_group("gap_zone"):
			zones[str(n.get_meta("zone_id", ""))] = true
	for g: Variant in gaps["gaps"]:
		var gap: Dictionary = g
		assert_true(zones.has(str(gap["start_zone"])), "zone %s exists" % gap["start_zone"])
		assert_true(zones.has(str(gap["end_zone"])), "zone %s exists" % gap["end_zone"])
	var rails: int = lvl.find_children("*", "GrindRail", true, false).size()
	var lips: int = lvl.find_children("*", "RampLip", true, false).size()
	assert_true(rails >= 25, "at least 25 grind edges (%d)" % rails)
	assert_true(lips > 0, "ramp lips for snap (%d)" % lips)
	lvl.free()


func test_ground_slabs_collide_as_boxes_not_giant_trimeshes() -> void:
	# an 840 m trimesh slab gave phantom underside contacts at the WalkSouth/ParkSlab line (a dead stop, 100% loss in the snag sweep)
	var lvl: Level = LevelRegistry.create("beach")
	(Engine.get_main_loop() as SceneTree).root.add_child(lvl)
	for nm: String in ["Road", "WalkNorth", "WalkSouth", "Seawall"]:
		var sb: StaticBody3D = lvl.get_node(nm) as StaticBody3D
		assert_true(sb != null, nm + " exists")
		var cs: CollisionShape3D = sb.get_node("Collision") as CollisionShape3D
		assert_true(cs.shape is BoxShape3D, nm + " collides as a box")
		var box: BoxShape3D = cs.shape as BoxShape3D
		assert_near(sb.position.y + box.size.y * 0.5, 0.0 if nm != "Seawall" else 0.0, 0.001, nm + " top flush with y = 0")
	lvl.free()
