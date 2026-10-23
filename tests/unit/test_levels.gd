extends TestCase
## Level API and LevelRegistry: every registered level instantiates headless, spawns over a floor, is closed in by its
## boundary and has a bot route that parses and stays inside its bounds.

const NEW_LEVELS: Array[String] = ["warehouse", "beach", "school", "downtown", "hills"]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Instantiates a level in the tree (so _ready builds it). Caller frees it.
func _make(id: String) -> Level:
	var lvl: Level = LevelRegistry.create(id)
	_tree().root.add_child(lvl)
	return lvl


## World-space AABBs of every collision shape under `root` (any shape type, via its debug mesh).
func _shape_boxes(root: Node) -> Array[AABB]:
	var out: Array[AABB] = []
	for n: Node in root.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = n as CollisionShape3D
		if cs.shape == null or cs.disabled:
			continue
		var body: CollisionObject3D = cs.get_parent() as CollisionObject3D
		if body == null or (body.collision_layer & 1) == 0:
			continue
		out.append(cs.global_transform * cs.shape.get_debug_mesh().get_aabb())
	return out


func test_registry_lists_practice_and_five_new_levels() -> void:
	var ids: Array[String] = LevelRegistry.ids()
	assert_eq(ids[0], "practice", "practice comes first")
	for id: String in NEW_LEVELS:
		assert_true(ids.has(id), "registry has " + id)
	assert_eq(ids.size(), 6)


func test_entries_have_the_contract_fields() -> void:
	for e: Dictionary in LevelRegistry.entries():
		for k: String in ["id", "name", "blurb", "script", "mood", "bot_route"]:
			assert_true(e.has(k) and str(e[k]) != "", "%s has %s" % [e.get("id", "?"), k])
		assert_true(Mood.has(str(e["mood"])), "%s mood %s is a preset" % [e["id"], e["mood"]])
		assert_true(ResourceLoader.exists(str(e["script"])), "%s script exists" % e["id"])


func test_resolve_prefers_arg_then_selection() -> void:
	var keep: String = LevelRegistry.selected
	LevelRegistry.selected = "beach"
	assert_eq(LevelRegistry.resolve({}), "beach", "selection when no arg")
	LevelRegistry.selected = "no_such_level"
	assert_eq(LevelRegistry.resolve({}), "practice", "unknown falls back to practice")
	LevelRegistry.selected = keep


func test_unknown_id_is_not_registered() -> void:
	assert_false(LevelRegistry.has("no_such_level"))
	assert_true(LevelRegistry.entry("no_such_level").is_empty())


func test_create_fills_identity_fields() -> void:
	for id: String in NEW_LEVELS:
		var lvl: Level = LevelRegistry.create(id)
		assert_true(lvl != null, id + " created")
		if lvl == null:
			continue
		assert_eq(lvl.level_id, id)
		assert_eq(lvl.mood_id, str(LevelRegistry.entry(id)["mood"]))
		assert_true(lvl.display_name != "", id + " has a display name")
		lvl.free()


func test_new_levels_build_with_environment_and_spawn_over_a_floor() -> void:
	for id: String in NEW_LEVELS:
		var lvl: Level = _make(id)
		assert_true(lvl.world_environment != null, id + " has a WorldEnvironment")
		assert_true(lvl.sun != null, id + " has a sun")
		var sp: Vector3 = lvl.spawn.origin
		assert_true(lvl.bounds.has_point(Vector2(sp.x, sp.z)), id + " spawn inside bounds")
		var floor_found: bool = false
		for bb: AABB in _shape_boxes(lvl):
			var inside: bool = sp.x >= bb.position.x and sp.x <= bb.end.x and sp.z >= bb.position.z and sp.z <= bb.end.z
			if inside and bb.end.y <= sp.y + 0.01 and bb.end.y >= sp.y - 0.6:
				floor_found = true
		assert_true(floor_found, id + " has a floor just under the spawn")
		assert_true(sp.y > lvl.kill_y + 5.0, id + " spawn well above kill_y")
		lvl.free()


func test_new_levels_boundary_encloses_bounds() -> void:
	for id: String in NEW_LEVELS:
		var lvl: Level = _make(id)
		var walls: Dictionary = {}
		for n: Node in lvl.find_children("Boundary*", "StaticBody3D", true, false):
			for bb: AABB in _shape_boxes(n):
				walls[str(n.name)] = bb
		for w: String in ["BoundaryN", "BoundaryS", "BoundaryW", "BoundaryE"]:
			assert_true(walls.has(w), "%s has %s" % [id, w])
		if walls.size() == 4:
			var b: Rect2 = lvl.bounds
			assert_true((walls["BoundaryN"] as AABB).end.z <= b.position.y + 0.01, id + " north wall outside")
			assert_true((walls["BoundaryS"] as AABB).position.z >= b.end.y - 0.01, id + " south wall outside")
			assert_true((walls["BoundaryW"] as AABB).end.x <= b.position.x + 0.01, id + " west wall outside")
			assert_true((walls["BoundaryE"] as AABB).position.x >= b.end.x - 0.01, id + " east wall outside")
			for w: String in walls:
				assert_true((walls[w] as AABB).size.y >= 20.0, "%s %s tall enough" % [id, w])
			# walls overlap at the corners: no gap to slip through
			var n: AABB = walls["BoundaryN"]
			assert_true(n.position.x <= (walls["BoundaryW"] as AABB).end.x and n.end.x >= (walls["BoundaryE"] as AABB).position.x,
					id + " north wall spans the corners")
		lvl.free()


func test_new_levels_bot_route_parses_inside_bounds() -> void:
	for id: String in NEW_LEVELS:
		var path: String = str(LevelRegistry.entry(id)["bot_route"])
		assert_true(FileAccess.file_exists(path), id + " bot route exists at " + path)
		var route: Dictionary = LevelRoute.load_file(path)
		assert_false(route.is_empty(), id + " route parses")
		assert_true(LevelRoute.line_names(route).size() >= 1, id + " route has a line")
		var b: Rect2 = LevelRegistry.create(id).bounds
		for p: Vector3 in LevelRoute.points(route):
			assert_true(b.has_point(Vector2(p.x, p.z)), "%s route point %s inside bounds" % [id, p])


func test_practice_route_is_builtin() -> void:
	assert_eq(str(LevelRegistry.entry("practice")["bot_route"]), LevelRegistry.BUILTIN_ROUTE)


func test_walls_around_builds_four_named_walls() -> void:
	var root: Node3D = Level.walls_around(Rect2(-10.0, -10.0, 20.0, 20.0), 30.0, -2.0, 2.0)
	var names: Array[String] = []
	for c: Node in root.get_children():
		names.append(str(c.name))
	names.sort()
	assert_eq(names, ["BoundaryE", "BoundaryN", "BoundaryS", "BoundaryW"])
	root.free()


func test_level_of_finds_ancestor() -> void:
	var lvl := Level.new()
	var a := Node3D.new()
	var b := Node3D.new()
	lvl.add_child(a)
	a.add_child(b)
	assert_eq(Level.of(b), lvl)
	var loose := Node3D.new()
	assert_true(Level.of(loose) == null, "no Level above a loose node")
	loose.free()
	lvl.free()


func test_level_kits_load_and_every_piece_file_exists() -> void:
	for id: String in NEW_LEVELS:
		var kit: LevelKit = LevelKit.open(id)
		assert_true(kit.names().size() > 0, id + " kit has pieces")
		for p: String in kit.names():
			var file: String = kit.dir + str(kit.info(p).get("file", ""))
			assert_true(ResourceLoader.exists(file), "%s/%s file exists" % [id, p])
			assert_true(kit.bounds(p).size.length() > 0.0, "%s/%s has bounds" % [id, p])


func test_level_kit_place_adds_box_collision() -> void:
	var kit: LevelKit = LevelKit.open("hills")
	var root := Node3D.new()
	var node: Node3D = kit.place(root, "mailbox", Vector3(3.0, 0.0, 4.0), 0.5)
	assert_true(node is StaticBody3D, "a StaticBody3D")
	var shapes: int = 0
	for c: Node in node.get_children():
		if c is CollisionShape3D:
			shapes += 1
	assert_eq(shapes, kit.collision_boxes("mailbox").size(), "one shape per manifest box")
	assert_near(node.position.x, 3.0)
	var deco: Node3D = kit.place(root, "mailbox", Vector3.ZERO, 0.0, {"collide": false})
	assert_false(deco is CollisionObject3D, "collide=false gives a plain node")
	root.free()
