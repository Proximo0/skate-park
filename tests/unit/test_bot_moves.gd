extends TestCase
## The play-bot's move-line plumbing (tests/bot/bot_moves.gd, bot_driver.gd): names, press helpers and the script overlay.


func test_group_names_are_unique_and_every_member_is_known() -> void:
	var seen: Dictionary = {}
	for n: String in BotMoves.MOVE_NAMES:
		assert_true(n.begins_with("mv_"), n)
		assert_true(BotMoves.GROUPS.has(n), "group " + n)
		assert_false(BotAuto.NAMES.has(n), "a move line must not shadow an auto line")
		for m: String in BotMoves.GROUPS[n]:
			assert_false(seen.has(m), "member in two groups: " + m)
			seen[m] = true
	assert_eq(BotMoves.GROUPS.size(), BotMoves.MOVE_NAMES.size())


func test_every_thug2_move_has_a_bot_line() -> void:
	var members: Array = []
	for n: String in BotMoves.MOVE_NAMES:
		members.append_array(BotMoves.GROUPS[n])
	for m: String in ["natas", "sticker_slap", "bert_slide", "skitch", "wallplant", "boneless", "no_comply", "acid_drop",
			"rail_transfer", "grind_switch", "manual_pivot", "ledge_stall", "powerslide", "rail_tricks", "hand_plant"]:
		assert_true(members.has("mv_" + m), "no bot line for " + m)


func test_presses_are_spaced_and_stay_inside_the_span() -> void:
	var steps: Array = BotMoves._presses("grind", "AIR", 3, 10, 4)
	assert_eq(steps.size(), 3)
	assert_eq(int((steps[0] as Dictionary)["at"]), 3)
	assert_eq(int((steps[2] as Dictionary)["at"]), 11)
	assert_eq(str((steps[1] as Dictionary)["from"]), "AIR")
	var gated: Array = BotMoves._presses("grind", "AIR", 0, 3, 3, {"near": [1.0, 2.0, 0.5]})
	assert_true((gated[0] as Dictionary).has("near"), "extra keys ride along")


func test_trick_db_has_every_move_the_lines_expect() -> void:
	var db: TrickDB = TrickDB.load_default()
	for id: String in ["natas_spin", "sticker_slap", "bert_slide", "skitch", "wallplant", "boneless", "no_comply", "acid_drop"]:
		assert_false(db.find_move(id).is_empty(), id)
	assert_false(db.find_link("rail_transfer").is_empty())
	assert_false(db.get_trick("andrecht").is_empty(), "the hand plant line expects the andrecht")
