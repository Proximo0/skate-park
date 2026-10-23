extends TestCase
## Round 9 presentation of the round-8 moves: focus action, event sounds, coach tips, the controls screen's tip pages.


func test_focus_is_a_controls_button_and_registers_once() -> void:
	assert_true(Controls.BUTTONS.has("focus"), "focus in the Controls table")
	assert_true(InputMap.has_action("focus"))
	var before: int = InputMap.action_get_events("focus").size()
	Skater._ensure_focus_action()
	assert_eq(InputMap.action_get_events("focus").size(), before, "registering again adds nothing")
	var keys: int = 0
	for e: InputEvent in InputMap.action_get_events("focus"):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_F:
			keys += 1
	assert_eq(keys, 1, "one F binding")


func test_round8_event_sounds_exist() -> void:
	for e: String in ["natas_180", "natas_pop", "sticker_slap", "bert_slide", "focus_on", "focus_off"]:
		assert_eq(SkateAudio.event_sound(e).size(), 3, e + " has a sound")
	var a: SkateAudio = SkateAudio.new()
	a._build_streams()
	for e: String in SkateAudio.EVENT_SOUNDS:
		assert_true(a._streams.has(str(SkateAudio.EVENT_SOUNDS[e][0])), e + " stream built")
	for loop: String in ["bert", "tow"]:
		assert_eq((a._streams[loop] as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, loop + " loops")
	a.free()


func test_coach_tips_for_round8_moves() -> void:
	assert_eq(CoachTips.tip_for_event("natas"), "natas")
	assert_eq(CoachTips.tip_for_event("sticker_slap"), "sticker_slap")
	assert_eq(CoachTips.tip_for_event("bert_slide"), "bert_slide")
	assert_eq(CoachTips.tip_for_event("skitch"), "skitch")
	assert_eq(CoachTips.tip_for_event("focus_on"), "focus")
	for id: String in ["natas", "sticker_slap", "bert_slide", "skitch", "focus"]:
		assert_true(CoachTips.TIPS.has(id) and CoachTips.NUDGE_ORDER.has(id), id)


func test_controls_screen_pages_and_lists_focus() -> void:
	var cs: ControlsScreen = ControlsScreen.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(cs)
	assert_eq(cs._tip_texts.size(), ControlsScreen.CTRL_TIPS_PER_PAGE)
	cs.show_page(1)
	assert_eq(cs._tip_texts[0].text, ControlsScreen.CTRL_TIPS[ControlsScreen.CTRL_TIPS_PER_PAGE])
	cs.show_page(2)
	assert_eq(cs._page, 0, "pages wrap")
	assert_true(cs._joy_text("focus").contains("R3"))
	assert_eq(cs._key_text("focus"), "F")
	cs.free()
