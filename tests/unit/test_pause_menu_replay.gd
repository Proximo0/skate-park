extends TestCase
## The pause menu's Replay entry is hidden when no replay buffer exists.


func test_replay_hidden_without_a_clip() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var p: PauseMenu = PauseMenu.new()
	tree.root.add_child(p)
	assert_false(p.replay_available(), "no director, no replay")
	p.open_menu()
	var b: Button = p.find_child("ReplayButton", true, false) as Button
	assert_true(b != null, "button exists")
	assert_false(b.visible, "hidden with no clip")
	p.resume()
	p.free()
