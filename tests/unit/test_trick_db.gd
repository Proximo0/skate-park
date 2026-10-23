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
	assert_eq(str(db.find("flip", "N", true).get("id", "")), "three_sixty_shove_it")
	# THUG2: a double-tapped grab is its own named grab, not a "Double Indy"
	assert_eq(str(db.find("grab", "E", true).get("id", "")), "crossbone")
	assert_eq(str(db.find("grab", "", true).get("id", "")), "madonna")
	assert_eq(str(db.find("grab", "SE", true).get("id", "")), "christ_air")
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
	# Every grind dir has a double-tap variant (THUG2's grind variants).
	assert_eq(str(db.find("grind", "N", true).get("id", "")), "overcrook", "double nosegrind dir")
	assert_eq(str(db.find("grind", "", true).get("id", "")), "hurricane", "neutral double grind")
	assert_eq(str(db.find("grind", "S", true).get("id", "")), "salad_grind")
	assert_eq(str(db.find("grind", "SE", true).get("id", "")), "suski_grind")
	assert_eq(str(db.find("grind", "SW", true).get("id", "")), "willy_grind")
	# A button with no trick for a double tap falls back to the neutral single trick.
	var plain := TrickDB.new()
	plain._load_list([{"id": "a", "name": "A", "kind": "grind", "button": "grind", "dir": "", "double_tap": false, "points": 1,
		"anim": "grind_a", "hold": true, "sequence": [], "points_per_sec": 0}])
	assert_eq(str(plain.find("grind", "N", true).get("id", "")), "a", "double falls back to the neutral single")


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
	assert_eq(str(db.find_lip("NE").get("id", "")), "invert")
	assert_eq(str(db.find_lip("NW").get("id", "")), "one_foot_invert")
	assert_eq(str(db.find_lip("SE").get("id", "")), "eggplant")
	assert_eq(str(db.find_lip("SW").get("id", "")), "blunt_to_fakie")
	assert_eq(str(db.find_lip("").get("id", "")), "nose_stall", "no dir: the nose stall")
	assert_eq(str(db.find_lip("N", true).get("id", "")), "nose_pick", "double tap")
	assert_eq(str(db.find_lip("SW", true).get("id", "")), "blunt_to_fakie", "no double for the dir: its single")


func test_find_lip_on_ledge() -> void:
	var db: TrickDB = _db()
	assert_eq(str(db.find_lip("N", false, true).get("id", "")), "nose_stall")
	assert_eq(str(db.find_lip("E", true, true).get("id", "")), "smith_stall")
	assert_eq(str(db.find_lip("W", true, true).get("id", "")), "feeble_stall")
	assert_eq(str(db.find_lip("SW", false, true).get("id", "")), "blunt_to_fakie")
	# no inverts or plants on a ledge: those dirs fall back to the nose stall
	assert_eq(str(db.find_lip("NE", false, true).get("id", "")), "nose_stall")
	assert_eq(str(db.find_lip("SE", false, true).get("id", "")), "nose_stall")
	for t: Dictionary in db.by_kind("lip"):
		assert_true(t.has("ledge"), "%s says whether it works on a ledge" % t["id"])


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
	assert_eq(db.by_kind("grab").size(), 27, "grabs: 9 dirs x 2, and 9 grab grinds")
	assert_eq(db.by_kind("grind").size(), 18, "grinds: 9 dirs x 2")
	assert_eq(db.by_kind("lip").size(), 14, "lips: 8 dirs + 6 double taps")
	assert_eq(db.by_kind("manual").size(), 2, "manuals")
	assert_eq(db.by_kind("special").size(), 4, "specials")
	assert_eq(db.by_kind("flatland").size(), 6, "flatland: 5 grab dirs + the 180 pivot")
	assert_eq(db.by_kind("link").size(), TrickDB.LINK_IDS.size() + 1, "links, and the grind_out bonus")
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


func test_thug2_extras_in_the_table() -> void:
	var db: TrickDB = _db()
	assert_eq(str(db.find_move("natas_spin").get("name", "")), "Natas Spin")
	assert_eq(str(db.find_move("sticker_slap").get("name", "")), "Sticker Slap")
	assert_eq(str(db.find_move("bert_slide").get("name", "")), "Bert Slide")
	assert_eq(str(db.find_move("skitch").get("name", "")), "Skitch")
	assert_true(int(db.find_move("natas_spin").get("points_per_sec", 0)) > 0, "a natas pays while held")
	assert_true(int(db.find_move("skitch").get("points_per_sec", 0)) > 0, "a skitch pays while towed")
	assert_eq(int(db.find_move("sticker_slap").get("points_per_sec", 0)), 0, "a sticker slap is a tap")


func test_restrict_specials_keeps_only_the_allowed() -> void:
	var db: TrickDB = _db()
	var before: int = db.by_kind("special").size()
	assert_eq(before, 4)
	var removed: int = db.restrict_specials(["rocket_launch"])
	assert_eq(removed, 3)
	assert_eq(db.by_kind("special").size(), 1)
	assert_false(db.find_sequence(["S", "N"], "flip").is_empty(), "the allowed special still triggers")
	assert_true(db.find_sequence(["E", "W"], "grab").is_empty(), "a restricted one cannot")
	assert_false(db.get_trick("pizza_spinner").is_empty(), "by id it is still known")
	assert_eq(db.by_kind("flip").size(), _db().by_kind("flip").size(), "other kinds are untouched")


func test_restrict_specials_empty_removes_all_and_unknown_ids_are_ignored() -> void:
	var db: TrickDB = _db()
	assert_eq(db.restrict_specials(["not_a_trick"]), 4)
	assert_eq(db.by_kind("special").size(), 0)
	assert_eq(db.restrict_specials([]), 0, "nothing left to remove")


func test_clear_specials_restriction_restores_the_table() -> void:
	var db: TrickDB = _db()
	var n: int = db.ids().size()
	db.restrict_specials([])
	assert_eq(db.ids().size(), n - 4)
	assert_eq(db.clear_specials_restriction(), 4)
	assert_eq(db.ids().size(), n)
	assert_false(db.find_sequence(["E", "W"], "grab").is_empty(), "restored specials trigger again")
	assert_eq(db.clear_specials_restriction(), 0, "clearing twice is a no-op")


## Round 11 naming: 360 flip (tre flip), 360 shove-it and pressure flip on the double taps, varial heel kept.
func test_tre_flip_pressure_flip_and_360_shove_it() -> void:
	var db: TrickDB = _db()
	assert_eq(str(db.find("flip", "E", true).get("name", "")), "360 Flip", "double-tapped varial kickflip: the tre flip")
	assert_eq(str(db.find("flip", "N", true).get("name", "")), "360 Shove-It")
	assert_eq(str(db.find("flip", "NW", true).get("name", "")), "Pressure Flip")
	assert_eq(str(db.find("flip", "SE", false).get("name", "")), "Varial Heelflip")
	assert_eq(str(db.get_trick("tre_flip").get("anim", "")), "flip_tre_flip")


## Grab grinds: their own button, the same stick dirs as the air grabs; never matched by an air grab press.
func test_grab_grinds_in_the_table() -> void:
	var db: TrickDB = _db()
	assert_eq(str(db.find("grind_grab", "", false).get("name", "")), "Melon")
	assert_eq(str(db.find("grind_grab", "E", false).get("name", "")), "Indy")
	assert_eq(str(db.find("grind_grab", "NW", false).get("name", "")), "Crail", "no airwalk on a rail")
	assert_eq(str(db.find("grind_grab", "E", true).get("name", "")), "Melon", "no double taps: neutral fallback")
	assert_eq(str(db.find("grab", "E", false).get("id", "")), "indy", "an air grab press never finds a grab grind")
	for t: Dictionary in db.by_kind("grab"):
		if str(t["button"]) == "grind_grab":
			assert_true(str(t["anim"]).begins_with("grab_"), "%s poses a grab" % t["id"])
	var out: Dictionary = db.find_link("grind_out")
	assert_eq(str(out.get("name", "")), "Out")
	assert_true(int(out.get("points", 0)) > 0, "the flip out pays a bonus")


## Hand plants on the coping: the double taps of the invert / one-foot invert / eggplant dirs, never on a ledge.
func test_hand_plant_lips() -> void:
	var db: TrickDB = _db()
	assert_eq(str(db.find_lip("NE", true).get("id", "")), "andrecht")
	assert_eq(str(db.find_lip("NW", true).get("id", "")), "sad_plant")
	assert_eq(str(db.find_lip("SE", true).get("id", "")), "russian_boneless")
	for id: String in ["andrecht", "sad_plant", "russian_boneless"]:
		assert_false(bool(db.get_trick(id).get("ledge", true)), id + " is coping only")
	assert_eq(str(db.find_lip("NE", true, true).get("id", "")), "nose_stall", "no plants on a ledge")
