extends TestCase

const LOADOUT_TMP: String = "user://test_loadout_tmp.json"

func test_defaults_are_valid() -> void:
	var cat: PartCatalog = PartCatalog.load_default()
	for l: SkaterLoadout in [SkaterLoadout.default_female(), SkaterLoadout.default_male()]:
		for slot: String in ["hair", "top", "bottom", "socks", "shoes", "deck", "truck", "wheel", "bearing", "griptape"]:
			var id: String = l.item_id(slot)
			assert_true(cat.has_item(id), "%s %s exists" % [l.body_type, slot])
			assert_true(cat.fits_body(id, l.body_type), "%s %s fits body" % [l.body_type, slot])
			assert_true(cat.is_starter(id), "%s %s is a starter item" % [l.body_type, slot])
	assert_eq(SkaterLoadout.default_female().body_type, "female")
	assert_eq(SkaterLoadout.default_male().body_type, "male")

func test_dict_round_trip() -> void:
	var l: SkaterLoadout = SkaterLoadout.default_male()
	l.skater_name = "Pip"
	l.top_color = 2
	l.deck_id = "deck_oldschool"
	l.deck_graphic = 3
	l.wheel_id = "wheel_park_54"
	l.set_item("accessory", "acc_cap", 1)
	var back: SkaterLoadout = SkaterLoadout.from_dict(l.to_dict())
	assert_eq(back.to_dict(), l.to_dict())
	assert_eq(back.skater_name, "Pip")
	assert_eq(back.top_color, 2)
	assert_eq(back.deck_graphic, 3)
	assert_eq(back.accessories, ["acc_cap"] as Array[String])
	assert_true(back.skin_tone.is_equal_approx(l.skin_tone))

func test_json_round_trip_through_a_file() -> void:
	var l: SkaterLoadout = SkaterLoadout.default_female()
	l.hair_color = Color("#FF7EB6")
	l.shoes_id = "shoes_high_top"
	assert_true(l.save(LOADOUT_TMP))
	var back: SkaterLoadout = SkaterLoadout.load_file(LOADOUT_TMP)

	assert_eq(back.hair_color.to_html(false), "ff7eb6")
	assert_eq(back.shoes_id, "shoes_high_top")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOADOUT_TMP))

func test_missing_or_broken_file_gives_default() -> void:
	var l: SkaterLoadout = SkaterLoadout.load_file("user://no_such_loadout_file.json")
	assert_eq(l.to_dict(), SkaterLoadout.default_female().to_dict())
	var f: FileAccess = FileAccess.open(LOADOUT_TMP, FileAccess.WRITE)
	f.store_string("not json {")
	f.close()
	assert_eq(SkaterLoadout.load_file(LOADOUT_TMP).to_dict(), SkaterLoadout.default_female().to_dict())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOADOUT_TMP))

func test_sanitize_fixes_body_mismatch_and_unowned() -> void:
	var l: SkaterLoadout = SkaterLoadout.default_female()
	l.set_item("top", "top_bikini")
	l.body_type = "male"
	l.sanitize()
	assert_true(PartCatalog.load_default().fits_body(l.top_id, "male"), "bikini top swapped for a male-friendly top")
	var m: SkaterLoadout = SkaterLoadout.default_female()
	m.set_item("shoes", "shoes_high_top")
	m.sanitize(func(id: String) -> bool: return PartCatalog.load_default().is_starter(id))
	assert_eq(m.shoes_id, "shoes_low_vulc", "unowned shoes fall back to a starter")
	m.top_color = 99
	m.sanitize()
	assert_true(m.top_color < PartCatalog.load_default().color_count(m.top_id), "colour index clamped")

func test_randomise_is_seeded_and_valid() -> void:
	var a: SkaterLoadout = SkaterLoadout.default_female()
	var b: SkaterLoadout = SkaterLoadout.default_female()
	var r1: RandomNumberGenerator = RandomNumberGenerator.new()
	var r2: RandomNumberGenerator = RandomNumberGenerator.new()
	r1.seed = 7
	r2.seed = 7
	a.randomise(r1)
	b.randomise(r2)
	assert_eq(a.to_dict(), b.to_dict(), "same seed, same look")
	var cat: PartCatalog = PartCatalog.load_default()
	for slot: String in ["top", "bottom", "shoes", "deck"]:
		assert_true(cat.fits_body(a.item_id(slot), a.body_type))

func test_set_item_and_accessor_agree() -> void:
	var l: SkaterLoadout = SkaterLoadout.default_female()
	l.set_item("truck", "truck_low", 2)
	assert_eq(l.item_id("truck"), "truck_low")
	assert_eq(l.item_color("truck"), 2)
	l.set_item("accessory", "acc_cap", 1)
	assert_eq(l.item_id("accessory"), "acc_cap")
	l.set_item("accessory", "")
	assert_true(l.accessories.is_empty())
