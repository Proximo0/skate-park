extends TestCase


func _art_slots_test_placeholder(counter: Array[int]) -> Callable:
	return func() -> Node3D:
		counter[0] += 1
		var n: Node3D = Node3D.new()
		n.name = "Placeholder"
		return n


func test_path_for_is_glb_under_art() -> void:
	assert_eq(ArtSlots.path_for("skater_body"), "res://art/skater_body.glb")
	assert_eq(ArtSlots.path_for("park_rail_flat"), "res://art/park_rail_flat.glb")


func test_slots_lists_all_fourteen_slots() -> void:
	assert_eq(ArtSlots.SLOTS.size(), 14)
	assert_true(ArtSlots.SLOTS.has("skater_board"))
	assert_true(ArtSlots.SLOTS.has("park_props"))


func test_has_art_false_for_missing_slot() -> void:
	assert_false(ArtSlots.has_art("no_such_slot_for_test"))


func test_instance_falls_back_to_placeholder() -> void:
	var counter: Array[int] = [0]
	var node: Node3D = ArtSlots.instance("no_such_slot_for_test", _art_slots_test_placeholder(counter))
	assert_eq(counter[0], 1, "placeholder called once")
	assert_true(node != null, "placeholder node returned")
	if node != null:
		assert_eq(String(node.name), "Placeholder")
		node.free()
