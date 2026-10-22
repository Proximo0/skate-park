extends TestCase


func _db() -> TrickDB:
	return TrickDB.load_default()


func test_get_trick_by_id() -> void:
	var db: TrickDB = _db()
	assert_eq(str(db.get_trick("melon").get("button", "")), "grab", "melon is a grab")
	assert_eq(db.get_trick("no_such_trick").size(), 0, "unknown id gives empty dict")


func test_find_flip_dirs() -> void:
	var db: TrickDB = _db()
	assert_eq(str(db.find("flip", "", false).get("id", "")), "kickflip")
	assert_eq(str(db.find("flip", "N", false).get("id", "")), "pop_shove_it")
	assert_eq(str(db.find("flip", "SW", false).get("id", "")), "impossible")
	assert_eq(str(db.find("flip", "NW", false).get("id", "")), "frontside_flip")


func test_find_double_tap_variants() -> void:
	var db: TrickDB = _db()
	assert_eq(str(db.find("flip", "", true).get("id", "")), "double_kickflip")
	assert_eq(str(db.find("flip", "N", true).get("id", "")), "double_pop_shove_it")
	assert_eq(str(db.find("grab", "E", true).get("id", "")), "double_indy")
	assert_true(bool(db.find("grab", "E", true).get("double_tap", false)), "double variant flagged")


func test_find_grabs_and_grinds() -> void:
	var db: TrickDB = _db()
	assert_eq(str(db.find("grab", "", false).get("id", "")), "melon")
	assert_eq(str(db.find("grab", "SE", false).get("id", "")), "benihana")
	assert_eq(str(db.find("grind", "", false).get("id", "")), "fifty_fifty")
	assert_eq(str(db.find("grind", "S", false).get("id", "")), "five_oh")
	assert_eq(str(db.find("grind", "NE", false).get("id", "")), "lipslide")


func test_find_falls_back_to_neutral() -> void:
	var db: TrickDB = _db()
	# Grinds have no double-tap variants, so a double tap falls back to the neutral single trick.
	assert_eq(str(db.find("grind", "N", true).get("id", "")), "fifty_fifty", "double grind falls back")
	assert_eq(str(db.find("grind", "", true).get("id", "")), "fifty_fifty", "neutral double grind falls back")


func test_find_unknown_returns_empty() -> void:
	var db: TrickDB = _db()
	assert_eq(db.find("nope", "", false).size(), 0, "unknown button")
	assert_eq(db.find("", "", false).size(), 0, "empty button does not match manuals")
	assert_eq(db.find("flip", "", false).is_empty(), false)


func test_find_lip() -> void:
	var db: TrickDB = _db()
	assert_eq(str(db.find_lip("N").get("id", "")), "nose_stall")
	assert_eq(str(db.find_lip("E").get("id", "")), "axle_stall")
	assert_eq(str(db.find_lip("S").get("id", "")), "rock_to_fakie")
	assert_eq(str(db.find_lip("W").get("id", "")), "disaster")
	assert_eq(db.find_lip("NE").size(), 0, "no diagonal lip tricks")


func test_find_sequence() -> void:
	var db: TrickDB = _db()
	assert_eq(str(db.find_sequence(["N", "S"], "").get("id", "")), "manual")
	assert_eq(str(db.find_sequence(["S", "N"], "").get("id", "")), "nose_manual")
	assert_eq(str(db.find_sequence(["S", "N"], "flip").get("id", "")), "rocket_launch")
	assert_eq(str(db.find_sequence(["E", "W"], "grab").get("id", "")), "pizza_spinner")
	assert_eq(str(db.find_sequence(["E", "W"], "flip").get("id", "")), "", "wrong button")
	assert_eq(db.find_sequence(["E", "N", "W"], "").size(), 0, "no such sequence")


func test_by_kind_counts() -> void:
	var db: TrickDB = _db()
	assert_eq(db.by_kind("flip").size(), 18, "flips: 9 dirs x 2")
	assert_eq(db.by_kind("grab").size(), 18, "grabs: 9 dirs x 2")
	assert_eq(db.by_kind("grind").size(), 9, "grinds: 9 dirs")
	assert_eq(db.by_kind("lip").size(), 4, "lips")
	assert_eq(db.by_kind("manual").size(), 2, "manuals")
	assert_eq(db.by_kind("special").size(), 4, "specials")
	assert_eq(db.by_kind("flatland").size(), 6, "flatland: 5 grab dirs + the 180 pivot")
	assert_eq(db.by_kind("link").size(), TrickDB.LINK_IDS.size(), "links")
	assert_eq(db.by_kind("bogus").size(), 0, "unknown kind")


func test_ids_unique() -> void:
	var db: TrickDB = _db()
	var ids: PackedStringArray = db.ids()
	var seen: Dictionary = {}
	for id: String in ids:
		seen[id] = true
	assert_eq(seen.size(), ids.size(), "ids are unique")
	assert_true(ids.size() > 0, "table is not empty")


func test_every_field_present_and_typed() -> void:
	var db: TrickDB = _db()
	for id: String in db.ids():
		var t: Dictionary = db.get_trick(id)
		for field: String in ["id", "name", "kind", "button", "dir", "double_tap", "points", "anim", "hold", "sequence", "points_per_sec"]:
			assert_true(t.has(field), "%s has %s" % [id, field])
		assert_eq(typeof(t.get("name")), TYPE_STRING, id + " name")
		assert_eq(typeof(t.get("double_tap")), TYPE_BOOL, id + " double_tap")
		assert_eq(typeof(t.get("hold")), TYPE_BOOL, id + " hold")
		assert_eq(typeof(t.get("sequence")), TYPE_ARRAY, id + " sequence")
		assert_eq(typeof(t.get("points")), TYPE_INT, id + " points")
		assert_eq(typeof(t.get("points_per_sec")), TYPE_INT, id + " points_per_sec")


func test_held_and_points_rules() -> void:
	var db: TrickDB = _db()
	for t: Dictionary in db.by_kind("grab"):
		assert_true(bool(t.get("hold")), str(t.get("id")) + " grabs hold")
		assert_true(int(t.get("points_per_sec")) > 0, str(t.get("id")) + " grabs pay per sec")
	for t: Dictionary in db.by_kind("flip"):
		assert_false(bool(t.get("hold")), str(t.get("id")) + " flips do not hold")
		assert_eq(int(t.get("points_per_sec")), 0, str(t.get("id")) + " flips pay no per sec")
	for t: Dictionary in db.by_kind("special"):
		assert_true(int(t.get("points")) >= 2000 and int(t.get("points")) <= 4000, str(t.get("id")) + " special points")
		assert_eq(int(t.get("sequence").size()), 2, str(t.get("id")) + " special sequence length")


func test_copies_are_safe_to_mutate() -> void:
	var db: TrickDB = _db()
	var t: Dictionary = db.get_trick("kickflip")
	t["points"] = 999999
	assert_true(int(db.get_trick("kickflip").get("points")) != 999999, "table not mutated")


func test_board_moves_score_from_the_table() -> void:
	var db: TrickDB = _db()
	for id: String in TrickDB.MOVE_IDS:
		var t: Dictionary = db.find_move(id)
		assert_eq(str(t.get("kind", "")), "move", "%s is a move" % id)
		assert_eq(str(t.get("anim", "")), id, "%s anim is its id (the poser keys off it)" % id)
		assert_true(int(t.get("points", 0)) > 0, "%s scores" % id)
	assert_eq(db.find_move("kickflip").size(), 0, "a flip is not a move")
	assert_eq(db.by_kind("move").size(), TrickDB.MOVE_IDS.size(), "moves")
	assert_eq(db.find("", "", false).size(), 0, "moves never match a button")


func test_find_flatland() -> void:
	var db: TrickDB = _db()
	assert_eq(str(db.find_flatland("grab", "").get("id", "")), "casper")
	assert_eq(str(db.find_flatland("grab", "N").get("id", "")), "pogo")
	assert_eq(str(db.find_flatland("grab", "S").get("id", "")), "anti_casper")
	assert_eq(str(db.find_flatland("grab", "NE").get("id", "")), "casper", "a dir with no flatland trick falls back to neutral")
	assert_eq(str(db.find_flatland("spin", "").get("id", "")), "manual_pivot")
	assert_eq(db.find_flatland("flip", "").size(), 0, "flip in a manual is no flatland trick (it waits for the pop)")
	assert_eq(str(db.find("grab", "", false).get("id", "")), "melon", "flatland never shadows the air grabs")
	for t: Dictionary in db.by_kind("flatland"):
		assert_true(str(t.get("anim", "")).begins_with("manual_"), "%s poses as a manual (the poser keys manual_*)" % t["id"])
		assert_true(int(t.get("points", 0)) >= 150 and int(t.get("points", 0)) <= 500, "%s THUG2-sized points" % t["id"])


func test_links_score_from_the_table() -> void:
	var db: TrickDB = _db()
	for id: String in TrickDB.LINK_IDS:
		var t: Dictionary = db.find_link(id)
		assert_eq(str(t.get("kind", "")), "link", "%s is a link" % id)
		assert_true(int(t.get("points", 0)) >= 200, "%s scores" % id)
	assert_eq(str(db.find_link("rail_transfer").get("name", "")), "Rail Transfer")
	assert_eq(str(db.find_link("wall_to_rail").get("name", "")), "Wall to Rail")
	assert_eq(db.find_link("kickflip").size(), 0, "a flip is not a link")
