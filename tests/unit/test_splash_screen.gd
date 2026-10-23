extends TestCase
## SplashScreen: instantiates, any skip ends it, and skipping targets the title screen.


func _make() -> SplashScreen:
	var scene: PackedScene = load("res://game/ui/splash_screen.tscn")
	var splash: SplashScreen = scene.instantiate()
	splash.change_scene = false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(splash)
	return splash


func _drop(splash: SplashScreen) -> void:
	var parent: Node = splash.get_parent()
	if parent != null:
		parent.remove_child(splash)
	splash.free()


func test_instantiates_and_runs() -> void:
	var splash: SplashScreen = _make()
	assert_false(splash.is_done())
	assert_true(splash.get_node_or_null("TitleLayer") != null)
	_drop(splash)


func test_skip_finishes_once() -> void:
	var splash: SplashScreen = _make()
	var count: Array[int] = [0]
	splash.finished.connect(func() -> void: count[0] += 1)
	splash.skip()
	splash.skip()
	assert_true(splash.is_done())
	assert_eq(count[0], 1)
	_drop(splash)


func test_key_press_skips() -> void:
	var splash: SplashScreen = _make()
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_SPACE
	splash._input(ev)
	assert_true(splash.is_done())
	_drop(splash)


func test_target_is_title_screen() -> void:
	assert_eq(SplashScreen.TITLE_SCENE, "res://game/ui/title_screen.tscn")
	assert_true(ResourceLoader.exists(SplashScreen.TITLE_SCENE))
