extends TestCase
## Every deck x truck x wheel combination keeps the physics contract: wheel bottoms at y = 0, deck top at DECK_TOP_Y
## over the flat middle, risers meeting the deck, and the node names the poser uses.

const DECKS: PackedStringArray = ["deck_popsicle", "deck_cruiser", "deck_oldschool"]
const TRUCKS: PackedStringArray = ["truck_standard", "truck_low", "truck_hollow"]
const WHEELS: PackedStringArray = ["wheel_street_52", "wheel_park_54", "wheel_cruiser_56"]


func _y_range(node: Node3D, xf: Transform3D) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	var t: Transform3D = xf * node.transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var box: AABB = (node as MeshInstance3D).mesh.get_aabb()
		for i: int in 8:
			var p: Vector3 = t * box.get_endpoint(i)
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
	for c: Node in node.get_children():
		if c is Node3D:
			var r: Vector2 = _y_range(c as Node3D, t)
			lo = minf(lo, r.x)
			hi = maxf(hi, r.y)
	return Vector2(lo, hi)


func test_every_combination_keeps_deck_top_and_wheel_bottoms() -> void:
	for d: String in DECKS:
		for tr: String in TRUCKS:
			for w: String in WHEELS:
				var tag: String = "%s/%s/%s" % [d, tr, w]
				var board: Node3D = PlaceholderSkater.build_board({}, {"deck": d, "truck": tr, "wheel": w})
				for n: String in ["Deck", "Truck_Front", "Truck_Back", "Wheel_FL", "Wheel_FR", "Wheel_BL", "Wheel_BR",
						"Wheel_FL_Hub", "Wheel_BR_Hub"]:
					assert_true(board.find_child(n, true, false) != null, tag + " has " + n)
				for n: String in ["Wheel_FL", "Wheel_FR", "Wheel_BL", "Wheel_BR"]:
					var r: Vector2 = _y_range(board.find_child(n, true, false) as Node3D, Transform3D.IDENTITY)
					var wnode: Node3D = board.find_child(n, true, false)
					var rr: Vector2 = _y_range(wnode, board.transform * (wnode.get_parent() as Node3D).transform)
					assert_true(r.x != INF, tag)
					assert_near(rr.x, 0.0, 0.0006, tag + " " + n + " bottom")
				var deck_r: Vector2 = _y_range(board.find_child("Deck", true, false) as Node3D, Transform3D.IDENTITY)
				assert_near(deck_r.y, PlaceholderSkater.DECK_TOP_Y, 0.0005, tag + " deck proxy top")
				AnimeBoard.set_deck(d)
				assert_near(AnimeBoard.top_y(0.0, 0.0), PlaceholderSkater.DECK_TOP_Y, 0.0001, tag + " drawn grip top")
				AnimeBoard.set_deck("popsicle")
				for t: String in ["Truck_Front", "Truck_Back"]:
					var riser: Node3D = board.find_child(t, true, false).find_child("TruckRiserMesh", true, false)
					assert_near(_y_range(riser, board.find_child(t, true, false).transform).y,
							PlaceholderSkater.DECK_TOP_Y - AnimeBoard.VIS_THICK, 0.0005, tag + " riser meets the deck")
				board.free()


func test_default_options_match_plain_build() -> void:
	var a: Node3D = PlaceholderSkater.build_board()
	var b: Node3D = PlaceholderSkater.build_board({}, {"deck": "deck_popsicle", "truck": "truck_standard",
			"wheel": "wheel_street_52", "graphic": "sunset"})
	assert_eq(_y_range(a, Transform3D.IDENTITY), _y_range(b, Transform3D.IDENTITY), "same extents")
	a.free()
	b.free()


func test_deck_shapes_differ() -> void:
	var lens: Array[float] = []
	for d: String in DECKS:
		var board: Node3D = PlaceholderSkater.build_board({}, {"deck": d})
		lens.append(((board.find_child("Deck", true, false) as MeshInstance3D).mesh as BoxMesh).size.z)
		board.free()
	assert_near(lens[0], 0.8, 0.0001, "popsicle length")
	assert_near(lens[1], 0.72, 0.0001, "cruiser is shorter")
	assert_true(lens[2] != lens[0], "old school differs")


func test_every_graphic_builds() -> void:
	for g: String in AnimeBoard.GRAPHICS:
		for d: String in DECKS:
			var board: Node3D = PlaceholderSkater.build_board({}, {"deck": d, "graphic": g})
			var meshes: int = 0
			for c: Node in board.get_children():
				if c.name.begins_with("Deck") and c.name != "Deck" and c.name != "DeckGrip" and c.name != "DeckBottom":
					meshes += 1
			assert_true(meshes > 3, "%s on %s has graphic parts" % [g, d])
			board.free()


func test_catalog_graphics_valid() -> void:
	var cat: PartCatalog = PartCatalog.load_default()
	var seen: Dictionary = {}
	for it: Dictionary in cat.items_in("deck"):
		var gs: Array = it.get("graphics", [])
		assert_eq(gs.size(), (it["colors"] as Array).size(), "%s graphics parallel colours" % it["id"])
		for g: Variant in gs:
			assert_true(AnimeBoard.GRAPHICS.has(str(g)), "known graphic " + str(g))
			seen[str(g)] = true
	assert_eq(seen.size(), AnimeBoard.GRAPHICS.size(), "every graphic reachable from the catalog")
