extends TestCase
## GameSettings: the bail injuries option (default On; tests never touch the save file).


func test_bail_injuries_default_on_and_toggles() -> void:
	var was: bool = GameSettings.injuries_on()
	GameSettings.bail_injuries = true
	assert_true(GameSettings.injuries_on(), "on by default")
	GameSettings.set_injuries(false)
	assert_false(GameSettings.injuries_on())
	GameSettings.set_injuries(true)
	assert_true(GameSettings.injuries_on())
	GameSettings.bail_injuries = was


func test_pause_menu_has_the_toggle() -> void:
	var pm: PauseMenu = PauseMenu.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(pm)
	var b: Button = pm.find_child("BailInjuries", true, false) as Button
	assert_true(b != null, "pause menu shows Bail injuries")
	if b != null:
		GameSettings.bail_injuries = true
		b.text = ""
		b.pressed.emit()
		assert_false(GameSettings.injuries_on(), "pressing turns injuries off")
		assert_eq(b.text, "Bail injuries: Off")
		b.pressed.emit()
		assert_true(GameSettings.injuries_on())
		assert_eq(b.text, "Bail injuries: On")
	pm.free()
