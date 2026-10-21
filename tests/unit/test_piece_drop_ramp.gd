extends TestCase
## DropRamp: a tall start deck, a concave roll-in to the ground and a flat run, travel along +Z.


func _find(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for c: Node in root.get_children():
		var f: Node = _find(c, node_name)
		if f != null:
			return f
	return null


func _bounds(body: Node3D) -> AABB:
	for c: Node in body.get_children():
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c as MeshInstance3D
			return (body.transform * mi.transform) * mi.mesh.get_aabb()
	return AABB()


func test_deck_top_at_start_height_and_filled_to_ground() -> void:
	var root: Node3D = DropRamp.build(4.0, 12.0, 2.0)
	var tower: StaticBody3D = _find(root, "RollIn") as StaticBody3D
	assert_true(tower != null, "RollIn body exists")
	if tower != null:
		var b: AABB = _bounds(tower)
		assert_near(b.end.y, 12.0, 0.0001, "deck top at start_height")
		assert_near(b.position.y, 0.0, 0.0001, "filled to the ground")
		assert_near(b.position.z, 0.0, 0.0001, "starts at z 0")
		assert_near(b.size.x, 4.0, 0.0001, "width")
		assert_near(b.end.z, DropRamp.roll_end(12.0), 0.01, "roll-in reaches the ground at roll_end")
	assert_near(DropRamp.length(4.0, 12.0, 2.0), DropRamp.roll_end(12.0) + 2.0, 0.0001, "length adds the flat run")
	root.free()


func test_drop_in_faces_plus_z_on_deck() -> void:
	var t: Transform3D = DropRamp.drop_in_transform(4.0, 12.0)
	var fwd: Vector3 = -t.basis.z
	assert_near(fwd.z, 1.0, 0.0001, "facing +Z")
	assert_near(t.origin.y, 12.0, 0.0001, "on the deck")
	assert_true(t.origin.z > 0.0 and t.origin.z < DropRamp.DECK_LEN, "on the deck, back from the edge")
	assert_near(t.origin.x, 2.0, 0.0001, "middle of the width")


func test_roll_curve_is_concave_and_ends_flat() -> void:
	var c: PackedVector2Array = DropRamp.roll_curve(12.0)
	assert_near(c[0].x, 12.0, 0.0001, "starts at the deck edge height")
	assert_near(c[c.size() - 1].x, 0.0, 0.0001, "ends on the ground")
	var prev_slope: float = 99.0
	for i: int in range(1, c.size()):
		var slope: float = (c[i - 1].x - c[i].x) / (c[i].y - c[i - 1].y)
		assert_true(slope <= prev_slope + 0.0001, "slope never steepens")
		prev_slope = slope
	assert_true(prev_slope < 0.05, "flat at the bottom")
