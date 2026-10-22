extends TestCase
## The HUD's NOLLIE stance tag: built hidden, shown and hidden by the stance (jump-cut path; the tween path needs a tree).


func test_tag_builds_hidden_and_follows_stance() -> void:
	var hud := Hud.new()
	hud._root = Control.new()
	hud._build_nollie_tag()
	var tag: Control = hud._nollie_tag
	assert_true(tag != null, "tag built")
	assert_false(tag.visible, "hidden while the stance is regular")
	hud._set_nollie_tag(true, false)
	assert_true(tag.visible and tag.modulate.a > 0.99 and tag.scale == Vector2.ONE, "NOLLIE shown")
	hud._set_nollie_tag(false, false)
	assert_false(tag.visible, "and gone again")
	assert_eq(Hud.NOLLIE_TEXT, "NOLLIE")
	hud._root.free()
	hud.free()
