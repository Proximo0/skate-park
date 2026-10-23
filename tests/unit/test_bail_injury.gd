extends TestCase
## BailInjury: the injury weight curve (snap in, hold, pop back to exactly zero) and the joint override itself.


func test_weight_snaps_in_holds_and_repairs_to_zero() -> void:
	assert_eq(BailInjury.weight(-1.0, -1.0), 0.0, "nothing before the slam")
	assert_eq(BailInjury.weight(0.0, -1.0), 0.0, "starts from normal")
	var peak: float = 0.0
	var t: float = 0.0
	while t < BailInjury.ONSET_TIME + BailInjury.SETTLE_TIME:
		peak = maxf(peak, BailInjury.weight(t, -1.0))
		t += 1.0 / 120.0
	assert_true(peak > 1.0 and peak < 1.2, "a snappy small overshoot, peak %f" % peak)
	assert_near(BailInjury.weight(1.0, -1.0), 1.0, 0.0001, "holds while the body slides")
	assert_true(BailInjury.weight(1.0, BailInjury.REPAIR_TIME * 0.6) < 0.2, "most of the way back mid-repair")
	assert_eq(BailInjury.weight(1.0, BailInjury.REPAIR_TIME), 0.0, "fully repaired")
	assert_eq(BailInjury.weight(1.0, 5.0), 0.0, "stays repaired")
	var lo: float = 1.0
	t = 0.0
	while t < BailInjury.REPAIR_TIME:
		lo = minf(lo, BailInjury.weight(1.0, t))
		t += 1.0 / 240.0
	assert_true(lo < 0.0 and lo > -0.15, "the pop clicks a touch past normal, min %f" % lo)


func test_rotation_is_identity_at_zero_weight() -> void:
	for id: String in BailKind.INJURIES:
		var inj: Dictionary = BailKind.injury(id, "L", 0.8)
		assert_true(BailInjury.local_rotation(inj, 0.0, 0.3).is_equal_approx(Basis.IDENTITY), id + " at weight 0")
		var b: Basis = BailInjury.local_rotation(inj, 1.0, 0.3)
		assert_false(b.is_equal_approx(Basis.IDENTITY), id + " bends at weight 1")
		assert_near(b.determinant(), 1.0, 0.0001, id + " is a pure rotation (no stretch)")


func test_sides_mirror() -> void:
	var l: Basis = BailInjury.local_rotation(BailKind.injury("ankle", "L", 1.0), 1.0)
	var r: Basis = BailInjury.local_rotation(BailKind.injury("ankle", "R", 1.0), 1.0)
	assert_true(l.inverse().is_equal_approx(r), "left and right ankles roll opposite ways")


func _limb() -> Array[Node3D]:
	var upper: Node3D = Node3D.new()
	upper.name = "LeftUpperLeg"
	var lower: Node3D = Node3D.new()
	lower.name = "LeftLowerLeg"
	lower.position = Vector3(0, -0.4, 0)
	lower.rotation = Vector3(-0.6, 0, 0)  # knee bent the normal way
	upper.add_child(lower)
	var foot: Node3D = Node3D.new()
	foot.name = "LeftFoot"
	foot.position = Vector3(0, -0.33, 0)
	lower.add_child(foot)
	return [upper, lower, foot]


func test_knee_hyperextends_past_straight_and_stays_attached() -> void:
	var n: Array[Node3D] = _limb()
	var upper: Node3D = n[0]
	var lower: Node3D = n[1]
	var foot: Node3D = n[2]
	(Engine.get_main_loop() as SceneTree).root.add_child(upper)
	var knee: Vector3 = lower.global_position
	var shin: float = lower.global_position.distance_to(foot.global_position)
	assert_true(BailInjury.flex(upper.global_basis, lower.global_basis) < 0.0, "bent the normal way first")
	var inj: Dictionary = BailKind.injury("knee", "L", 1.0)
	BailInjury.apply(lower, inj, 1.0, upper)
	assert_near(BailInjury.flex(upper.global_basis, lower.global_basis), float(inj["angle"]), 0.001, "bent the wrong way by the angle")
	assert_true(lower.global_position.is_equal_approx(knee), "the knee stays put")
	assert_near(lower.global_position.distance_to(foot.global_position), shin, 0.0001, "the shin keeps its length")
	upper.free()


func test_hinge_parents() -> void:
	assert_eq(BailInjury.hinge_parent("RightLowerLeg"), "RightUpperLeg")
	assert_eq(BailInjury.hinge_parent("LeftLowerArm"), "LeftUpperArm")
	assert_eq(BailInjury.hinge_parent("LeftHand"), "")
