extends TestCase
## The shared skate theme: builds with the palette variations, the saved .tres loads and is the project theme,
## and the hover/focus pose is a small tilt that wide buttons soften.


func test_builder_has_button_and_panel_variations() -> void:
	var t: Theme = SkateThemeBuilder.build()
	for v: StringName in [SkateThemeBuilder.BTN_CORAL, SkateThemeBuilder.BTN_TEAL, SkateThemeBuilder.BTN_ROW]:
		assert_true(t.has_stylebox("normal", v), "%s normal box" % v)
		assert_true(t.has_stylebox("focus", v), "%s focus ring" % v)
	assert_true(t.has_stylebox("panel", SkateThemeBuilder.PNL_NAVY))
	assert_true(t.default_font != null)


func test_saved_theme_is_the_project_theme() -> void:
	assert_eq(str(ProjectSettings.get_setting("gui/theme/custom")), SkateThemeBuilder.THEME_PATH)
	var saved: Theme = load(SkateThemeBuilder.THEME_PATH) as Theme
	assert_true(saved != null)
	assert_true(saved.has_stylebox("normal", SkateThemeBuilder.BTN_SUN))


func test_sticker_has_outline_and_shadow() -> void:
	var sb: StyleBoxFlat = SkateThemeBuilder.sticker(SkateThemeBuilder.CORAL)
	assert_eq(sb.border_width_left, SkateThemeBuilder.BORDER)
	assert_true(sb.shadow_offset.y > 0.0)
	assert_true(SkateThemeBuilder.flat(SkateThemeBuilder.CORAL).shadow_size == 0)


func test_pose_tilts_when_posed_and_rests_otherwise() -> void:
	var b: Button = Button.new()
	b.size = Vector2(300, 80)
	var rest: Array = UiFx.pose_for(b, false)
	assert_eq(rest[0], Vector2.ONE)
	assert_eq(rest[1], 0.0)
	var on: Array = UiFx.pose_for(b, true)
	assert_true((on[0] as Vector2).x > 1.0)
	assert_true(absf(on[1] as float) > 0.0)
	b.size = Vector2(1200, 80)
	var wide: Array = UiFx.pose_for(b, true)
	assert_true(absf(wide[1] as float) < absf(on[1] as float), "wide buttons tilt less")
	b.free()


func test_anime_text_sizes_itself_and_pops() -> void:
	var a: AnimeText = AnimeText.new("KICKFLIP", 60, SkateThemeBuilder.SUN)
	assert_true(a.custom_minimum_size.x > 100.0)
	a.pop("HEELFLIP")
	assert_eq(a.text, "HEELFLIP")
	assert_true(a.scale.x > 1.0, "starts big then settles")
	a.free()
