extends TestCase

const REQUIRED_SLOTS: PackedStringArray = ["top", "bottom", "socks", "shoes", "deck", "truck", "wheel", "bearing", "griptape", "hair"]


func test_every_item_is_valid() -> void:
	var cat: PartCatalog = PartCatalog.load_default()
	assert_true(cat.all_items().size() > 30, "a good range of items")
	for it: Dictionary in cat.all_items():
		var id: String = str(it.get("id", ""))
		assert_true(id != "", "item has an id")
		assert_true(str(it.get("name", "")) != "", "%s has a name" % id)
		assert_true(str(it.get("desc", "")) != "", "%s has a description" % id)
		assert_true(str(it.get("mesh_builder", "")) != "", "%s has a mesh_builder" % id)
		assert_true(cat.slot_order.has(str(it.get("slot", ""))), "%s slot is known" % id)
		assert_true(int(it.get("price", 0)) > 0, "%s price > 0" % id)
		var bodies: Array = it.get("bodies", [])
		assert_true(not bodies.is_empty(), "%s has bodies" % id)
		for b: Variant in bodies:
			assert_true(PartCatalog.BODIES.has(str(b)), "%s body %s" % [id, str(b)])


func test_ids_are_unique() -> void:
	var seen: Dictionary = {}
	for it: Dictionary in PartCatalog.load_default().all_items():
		var id: String = str(it["id"])
		assert_false(seen.has(id), "duplicate id %s" % id)
		seen[id] = true


func test_colour_hexes_are_valid_and_not_pure_green() -> void:
	var cat: PartCatalog = PartCatalog.load_default()
	for it: Dictionary in cat.all_items():
		var cols: Array = it["colors"]
		if it["slot"] != "hair":
			assert_true(cols.size() >= 2 and cols.size() <= 4, "%s has 2-4 colourways" % it["id"])
		assert_eq((it["color_names"] as Array).size(), cols.size(), "%s names match colours" % it["id"])
		for h: Variant in cols:
			var s: String = str(h)
			assert_true(s.length() == 7 and s.begins_with("#") and s.substr(1).is_valid_hex_number(), "%s hex %s" % [it["id"], s])
			assert_true(s.to_upper() != "#00FF00", "%s avoids pure green" % it["id"])


func test_every_slot_has_items_for_both_bodies() -> void:
	var cat: PartCatalog = PartCatalog.load_default()
	for slot: String in REQUIRED_SLOTS:
		for body: String in PartCatalog.BODIES:
			assert_true(not cat.items_for(slot, body).is_empty(), "%s has items for %s" % [slot, body])
			var has_starter: bool = false
			for it: Dictionary in cat.items_for(slot, body):
				has_starter = has_starter or bool(it["starter"])
			assert_true(has_starter, "%s has a starter for %s" % [slot, body])


func test_requested_items_exist() -> void:
	var cat: PartCatalog = PartCatalog.load_default()
	for id: String in ["top_bikini", "top_crop_tank", "top_surf_tee", "top_hoodie", "top_rash_guard", "top_flannel",
			"bottom_bikini", "bottom_board_shorts", "bottom_cargo_shorts", "bottom_skate_jeans", "bottom_joggers",
			"shoes_low_vulc", "shoes_cupsole", "shoes_puffy", "shoes_high_top",
			"deck_popsicle", "deck_cruiser", "deck_oldschool", "truck_standard", "truck_low", "truck_hollow",
			"wheel_street_52", "wheel_park_54", "wheel_cruiser_56"]:
		assert_true(cat.has_item(id), id)
	assert_false(cat.fits_body("top_bikini", "male"), "bikini top is female only")


func test_palettes_and_shop_categories() -> void:
	var cat: PartCatalog = PartCatalog.load_default()
	assert_true(cat.skin_tones.size() >= 4)
	assert_true(cat.hair_colors.size() >= 4)
	assert_true(cat.eye_colors.size() >= 4)
	assert_eq(cat.categories.size(), 6)
	for c: Dictionary in cat.categories:
		assert_true(not cat.category_items(str(c["id"]), "female").is_empty(), "category %s has items" % c["id"])
	assert_eq(PartCatalog.palette_index(cat.skin_tones, cat.skin_tones[2]["color"]), 2)


func test_color_lookup_clamps() -> void:
	var cat: PartCatalog = PartCatalog.load_default()
	assert_true(cat.color_of("deck_popsicle", 99).is_equal_approx(cat.color_of("deck_popsicle", cat.color_count("deck_popsicle") - 1)))
	assert_true(cat.color_of("nope", 0).is_equal_approx(Color.WHITE))


func test_builder_pending_features() -> void:
	var all: PackedStringArray = SkaterBuilder.pending_features()
	assert_false(all.has("body:male"), "the male body is built")
	for id: String in ["top_crop_tank", "top_hoodie", "top_flannel"]:
		assert_false(all.has("top:" + id), id + " is drawn")
	assert_false(all.has("truck:truck_low"), "low trucks are drawn")
	assert_false(all.has("truck:truck_standard"))
	assert_true(SkaterBuilder.pending_features(SkaterLoadout.default_female()).is_empty(), "default female is fully supported")
	var pal: Dictionary = SkaterBuilder.body_palette(SkaterLoadout.default_male())
	assert_true(pal.has("skin") and pal.has("shirt") and pal.has("iris"))
	assert_true(SkaterBuilder.board_palette(SkaterLoadout.default_male()).has("wheels"))
