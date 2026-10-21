extends TestCase
## The walk-in shop: station maths, the cast, the sit pose, and every station opening the right menu (or sitting, or
## leaving) and closing again with the player rebuilt. Runs without physics frames: the player is teleported to
## each station. The walking version is tests/sim/sim_shop_walk.gd.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _make_shop() -> ShopRoom:
	var shop: ShopRoom = (load("res://game/shop/shop.tscn") as PackedScene).instantiate() as ShopRoom
	shop.allow_scene_change = false
	_tree().root.add_child(shop)
	return shop


func _free(n: Node) -> void:
	n.get_parent().remove_child(n)
	n.free()


func test_nearest_station_and_prompt() -> void:
	var a: ShopStation = ShopStation.make("a", "do a", "shop", "decks", Vector3(0, 0, 0), 1.0)
	var b: ShopStation = ShopStation.make("b", "do b", "sit", "", Vector3(1.5, 0, 0), 1.0)
	var list: Array[ShopStation] = [a, b]
	assert_eq(ShopStation.nearest(list, Vector3(0.2, 5.0, 0.1)), a, "height is ignored")
	assert_eq(ShopStation.nearest(list, Vector3(1.0, 0, 0)), b, "the nearer of two overlapping zones")
	assert_eq(ShopStation.nearest(list, Vector3(0, 0, 3)), null)
	assert_eq(ShopStation.prompt_text(a), "Press E / A to do a")
	assert_eq(ShopStation.prompt_text(null), "")
	assert_eq(ShopStation.by_id(list, "b"), b)


func test_category_index_matches_catalog() -> void:
	var cat: PartCatalog = PartCatalog.load_default()
	for id: String in ["decks", "clothing", "shoes"]:
		var i: int = ShopStation.category_index(cat, id)
		assert_eq(str(cat.categories[i]["id"]), id)
	assert_eq(ShopStation.category_index(cat, "nope"), 0)


func test_sit_pose_puts_hips_on_the_seat() -> void:
	var p: Dictionary = ShopPoser.shop_pose("sit", 1.0)
	assert_near(PlaceholderSkater.HIP_HEIGHT + float(p["hips_y"]), ShopPoser.SEAT_HEIGHT, 0.001)
	assert_near(float(p["lift"]), -PlaceholderSkater.DECK_TOP_Y, 0.0001, "body root on the floor")
	assert_true((p["foot_L"] as Vector3).z < -0.3, "feet out in front")
	assert_near(float(p["grip_L"]), 1.0, 0.0001, "hands on the knees")
	var c: Dictionary = ShopPoser.shop_pose("counter", 0.0)
	assert_true((c["hand_R"] as Vector3).y > 0.95, "hands on the counter top")


func test_npc_talks_once_per_visit() -> void:
	var npc: ShopNpc = ShopNpc.create("t", "Tester", SkaterLoadout.new(), {}, "stand", PackedStringArray(["one", "two"]), 0.0)
	_tree().root.add_child(npc)
	assert_false(npc.update_talk(Vector3(10, 0, 0), 0.1))
	assert_true(npc.update_talk(Vector3(1, 0, 0), 0.1), "starts talking when the player comes close")
	assert_eq(npc.current_line(), "one")
	assert_false(npc.update_talk(Vector3(1, 0, 0), 0.1), "no new line while still close")
	npc.update_talk(Vector3(1, 0, 0), ShopNpc.LINE_TIME)
	assert_false(npc.is_talking(), "the bubble times out")
	npc.update_talk(Vector3(ShopNpc.LEAVE_RADIUS + 1.0, 0, 0), 0.1)
	assert_true(npc.update_talk(Vector3(1, 0, 0), 0.1))
	assert_eq(npc.current_line(), "two", "next visit, next line")
	_free(npc)


func test_shop_builds_stations_and_cast() -> void:
	var shop: ShopRoom = _make_shop()
	var ids: PackedStringArray = []
	for s: ShopStation in shop.stations:
		ids.append(s.id)
		assert_true(absf(s.stand.x) < ShopInterior.W and absf(s.stand.z) < ShopInterior.D, "%s inside the room" % s.id)
	for id: String in ["boards", "shoes", "clothes", "dressing", "style", "couch", "door"]:
		assert_true(ids.has(id), "station " + id)
	assert_true(shop.npcs.size() >= 4, "NPCs: %d" % shop.npcs.size())
	var talkers: int = 0
	for n: ShopNpc in shop.npcs:
		if not n.lines.is_empty():
			talkers += 1
	assert_true(talkers >= 2, "the shopkeeper and one more NPC talk")
	assert_eq(shop.skater.state.state, SkateState.State.WALK, "the player starts on foot")
	assert_true(shop.interior.vice.get_child_count() == 1, "a board in the workbench vice")
	_free(shop)


func test_every_station_opens_its_menu_and_closes() -> void:
	var shop: ShopRoom = _make_shop()
	var expect: Dictionary = {
		"boards": ["shop", "decks"], "shoes": ["shop", "shoes"], "clothes": ["shop", "clothing"],
		"dressing": ["creator", 1], "style": ["creator", 0],
	}
	var cat: PartCatalog = PartCatalog.load_default()
	for id: String in expect:
		var st: ShopStation = ShopStation.by_id(shop.stations, id)
		shop.skater.global_position = st.stand + Vector3(0.1, 0.05, 0.0)
		assert_eq(shop.refresh_focus(), st, "focus at " + id)
		assert_eq(shop.hud.prompt_line(), ShopStation.prompt_text(st))
		var old_body: Node = shop.skater.get_node("Visual/SkaterBody")
		shop.use_station(st)
		var want: Array = expect[id]
		assert_eq(shop.overlay_kind, str(want[0]), id)
		if str(want[0]) == "shop":
			assert_true(shop.overlay is SkateShop, id + " opens the skate shop")
			assert_eq(int(shop.overlay.get("_category")), ShopStation.category_index(cat, str(want[1])), id + " category")
		else:
			assert_true(shop.overlay is CharacterCreator, id + " opens the creator")
			assert_eq(int(shop.overlay.get("_tab")), int(want[1]), id + " tab")
		assert_false(shop.hud.visible, "HUD hidden under the menu")
		shop.close_menu()
		assert_eq(shop.overlay, null, id + " closed")
		assert_true(shop.hud.visible)
		var new_body: Node = shop.skater.get_node_or_null("Visual/SkaterBody")
		assert_true(new_body != null and new_body != old_body, id + ": player rebuilt after closing")
	_free(shop)


func test_menu_changes_show_on_the_player() -> void:
	var shop: ShopRoom = _make_shop()
	shop.open_menu("creator", "0")
	shop.loadout.skin_tone = Color("#9A6445")
	shop.close_menu()
	var skin_found: bool = false
	for mi: Node in shop.skater.get_node("Visual/SkaterBody").find_children("*", "MeshInstance3D", true, false):
		if str((mi as MeshInstance3D).get_meta("palette", "")) == "skin":
			var mat: ShaderMaterial = (mi as MeshInstance3D).material_override as ShaderMaterial
			skin_found = skin_found or (mat != null and (mat.get_shader_parameter("albedo") as Color).is_equal_approx(Color("#9A6445")))
	assert_true(skin_found, "new skin tone on the rebuilt body")
	_free(shop)


func test_couch_sits_and_stands() -> void:
	var shop: ShopRoom = _make_shop()
	var st: ShopStation = ShopStation.by_id(shop.stations, "couch")
	shop.skater.global_position = st.stand + Vector3(0, 0.05, 0)
	assert_eq(shop.refresh_focus(), st)
	shop.use_station(st)
	assert_true(shop.sitting)
	assert_eq(shop.poser.mode, "sit")
	assert_true(shop.skater.global_position.distance_to(shop.interior.seats[0].origin) < 0.01, "on the seat")
	assert_true(shop.sit_cam.current, "sit camera")
	shop.stand_up()
	assert_false(shop.sitting)
	assert_eq(shop.poser.mode, "")
	assert_true(shop.camera.current)
	assert_eq(ShopStation.nearest(shop.stations, shop.skater.global_position), st, "stands up at the couch")
	_free(shop)


func test_door_heads_to_the_park() -> void:
	var shop: ShopRoom = _make_shop()
	var got: Array = []
	shop.leave_requested.connect(func(scene: String) -> void: got.append(scene))
	var st: ShopStation = ShopStation.by_id(shop.stations, "door")
	shop.skater.global_position = st.stand + Vector3(0, 0.05, 0)
	assert_eq(shop.refresh_focus(), st)
	shop.use_station(st)
	assert_eq(got, [ShopRoom.PARK_SCENE])
	_free(shop)
