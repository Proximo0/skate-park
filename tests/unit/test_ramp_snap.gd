extends TestCase
## RampSnap (target selection for Q + E) and RampLip (lip registration): candidates sort by distance with lips the
## skater is behind penalised, reach limits, half pipe / bowl enclosure, the in-ramp rule, the arc, and that the ramp
## pieces register their lips facing down their transitions.


func _seg(a: Vector3, b: Vector3, inward: Vector3, kind: String = "drop_in") -> Dictionary:
	return {"a": a, "b": b, "inward": inward, "kind": kind}


## A half pipe along Z: wall A's lip at z = 0 faces +Z, wall B's at z = 13 faces -Z, both 4 m up, 10 m wide.
func _halfpipe() -> Array:
	return [
		_seg(Vector3(0, 4, 0), Vector3(10, 4, 0), Vector3.BACK),
		_seg(Vector3(0, 4, 13), Vector3(10, 4, 13), Vector3.FORWARD),
	]


func test_closest_on_segment_clamps_to_the_ends() -> void:
	var r: Array = RampSnap.closest_on_segment(Vector3(-5, 0, 1), Vector3(0, 0, 0), Vector3(10, 0, 0))
	assert_true((r[0] as Vector3).is_equal_approx(Vector3.ZERO), "clamped to a")
	r = RampSnap.closest_on_segment(Vector3(4, 2, 3), Vector3(0, 0, 0), Vector3(10, 0, 0))
	assert_true((r[0] as Vector3).is_equal_approx(Vector3(4, 0, 0)), "projected")
	assert_near(float(r[1]), 0.4)


func test_nearest_lip_in_front_wins() -> void:
	var near := _seg(Vector3(0, 3, 0), Vector3(8, 3, 0), Vector3.BACK)
	var far := _seg(Vector3(0, 3, 20), Vector3(8, 3, 20), Vector3.FORWARD)
	var c: Array = RampSnap.candidates(Vector3(4, 0, 6), [far, near], 12.0)
	assert_eq(c.size(), 1, "the far lip (14 m) is out of a 12 m reach")
	assert_true((c[0]["point"] as Vector3).is_equal_approx(Vector3(4, 3, 0)), "nearest point on the near lip")
	assert_false(bool(c[0]["behind"]))
	c = RampSnap.candidates(Vector3(4, 0, 6), [far, near], 15.0)
	assert_eq(c.size(), 2, "both in a 15 m (air) reach")
	assert_true((c[0]["point"] as Vector3).z < 1.0, "still the nearer one first")


func test_lip_behind_the_skater_is_penalised() -> void:
	# skater 3 m behind lip A (on its deck side) and 5 m in front of lip B
	var a := _seg(Vector3(0, 3, 0), Vector3(8, 3, 0), Vector3.BACK)
	var b := _seg(Vector3(0, 3, -8), Vector3(8, 3, -8), Vector3.BACK)
	var c: Array = RampSnap.candidates(Vector3(4, 3, -3), [a, b], 12.0)
	assert_true(bool(c[1]["behind"]), "lip A is behind")
	assert_true((c[0]["point"] as Vector3).z < -7.0, "the lip in front wins despite being farther")


func test_kind_passes_through() -> void:
	var c: Array = RampSnap.candidates(Vector3(0, 0, 3), [_seg(Vector3(-2, 12, 0), Vector3(2, 12, 0), Vector3.BACK, "roll_in")], 15.0)
	assert_eq(str(c[0]["kind"]), "roll_in")


func test_halfpipe_flat_bottom_is_enclosed() -> void:
	assert_true(RampSnap.enclosed(Vector3(5, 0, 6.5), _halfpipe()), "between the walls, below both lips")
	assert_false(RampSnap.enclosed(Vector3(5, 4, 6.5), _halfpipe()), "level with the lips: not walled in")
	assert_false(RampSnap.enclosed(Vector3(25, 0, 6.5), _halfpipe()), "off to the side of the half pipe")
	assert_false(RampSnap.enclosed(Vector3(5, 0, 20), _halfpipe()), "out past wall B")


func test_single_quarter_pipe_does_not_enclose() -> void:
	var qp: Array = [_seg(Vector3(0, 3.2, 0), Vector3(8, 3.2, 0), Vector3.BACK)]
	assert_false(RampSnap.enclosed(Vector3(4, 0, 4), qp), "in front of one wall only")
	assert_eq(RampSnap.walls_around(Vector3(4, 0, 4), qp).size(), 1, "but it is walled on one side")


func test_bowl_floor_is_enclosed() -> void:
	var loop := PackedVector3Array([Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 8), Vector3(0, 0, 8), Vector3(0, 0, 0)])
	var lip: RampLip = RampLip.ring(loop, Vector3(5, 0, 4))
	var segs: Array = lip.segments()
	assert_true((segs[0]["inward"] as Vector3).is_equal_approx(Vector3.BACK), "north rim faces the centre")
	assert_true((segs[1]["inward"] as Vector3).is_equal_approx(Vector3.LEFT), "east rim faces the centre")
	assert_true(RampSnap.enclosed(Vector3(5, -2.5, 4), segs), "on the bowl floor")
	assert_false(RampSnap.enclosed(Vector3(5, 0, 12), segs), "on the ground outside")
	lip.free()


func test_in_ramp_rule() -> void:
	assert_false(RampSnap.in_ramp(true, 1.0, false, false, false), "rolling on flat: snap in")
	assert_true(RampSnap.in_ramp(true, 0.6, false, false, false), "on a transition: snap out")
	assert_true(RampSnap.in_ramp(false, 1.0, true, false, false), "vert air: snap out")
	assert_false(RampSnap.in_ramp(false, 0.6, false, false, false), "ordinary air (the floor normal is stale): snap in")
	assert_true(RampSnap.in_ramp(false, 1.0, false, true, false), "lip trick: snap out")
	assert_true(RampSnap.in_ramp(true, 1.0, false, false, true), "half pipe flat bottom: snap out")


func test_arc_ends_and_rises() -> void:
	var p0 := Vector3(0, 0, 0)
	var p1 := Vector3(10, 3, 0)
	assert_true(RampSnap.arc_point(p0, p1, 1.5, 0.0).is_equal_approx(p0), "starts at p0")
	assert_true(RampSnap.arc_point(p0, p1, 1.5, 1.0).is_equal_approx(p1), "ends at p1")
	var mid: Vector3 = RampSnap.arc_point(p0, p1, 1.5, 0.5)
	assert_near(mid.y, 1.5 + 1.5, 0.001, "peaks apex over the straight line at the middle")
	assert_true(RampSnap.arc_time(0.0) >= 0.35 and RampSnap.arc_time(40.0) <= 0.5, "0.35 to 0.5 s")
	assert_true(RampSnap.arc_apex(10.0) > RampSnap.arc_apex(2.0), "longer arcs go higher")
	assert_near(RampSnap.arc_apex(2.0, Vector3(0, 1, 0), Vector3(5, 0, 0), 4.8), 4.3, 0.001, "a snap out clears the lip")


func test_hang_spot_puts_the_rear_truck_behind_the_coping() -> void:
	var lip := Vector3(0, 3.2, 1.5)
	var spot: Vector3 = RampSnap.hang_spot(lip, Vector3.BACK, 0.25)
	var rear_truck: Vector3 = spot - Vector3.BACK * 0.25  # the board's tail end is opposite the facing
	assert_true(rear_truck.z < lip.z, "rear truck on the deck side")
	assert_near(lip.z - rear_truck.z, RampSnap.HANG_BACK, 0.0001)


## Every ramp piece registers lips whose inward points down its transition (the floor in front is lower).
func test_pieces_register_lips() -> void:
	var cases: Array = [
		[QuarterPipe.build(8.0), 1], [HalfPipe.build(), 2], [Bowl.build(), 1], [DomeBowl.build(8.0, 0.85), 1],
		[Transfers.spine(10.0, 2.2, 2.4), 2], [Transfers.hip(8.0, 2.5, 2.8), 1], [Walls.bank(6.0, 4.0, 1.6), 1],
		[MegaRamp.build(8.0, 18.0, 14.0, 8.0), 2], [DropRamp.build(4.0, 12.0, 2.0), 1],
	]
	for c: Array in cases:
		var root: Node3D = c[0]
		var lips: Array = root.find_children("*", "RampLip", true, false)
		assert_eq(lips.size(), int(c[1]), "%s lips" % root.name)
		for l: Node in lips:
			var lip: RampLip = l as RampLip
			assert_eq(lip.inward.size(), lip.points.size() - 1, "%s: one inward per segment" % root.name)
			for d: Vector3 in lip.inward:
				assert_near(d.y, 0.0, 0.0001, "horizontal")
				assert_near(d.length(), 1.0, 0.0001, "unit")
		root.free()
	var qp: Node3D = QuarterPipe.build(8.0, 3.0, 3.2, 1.5)
	var ql: RampLip = qp.find_children("*", "RampLip", true, false)[0]
	assert_true(ql.inward[0].is_equal_approx(Vector3.BACK), "quarter pipe faces +Z")
	assert_near(ql.points[0].y, 3.2, 0.0001, "on the coping")
	qp.free()
	var mega: Node3D = MegaRamp.build(8.0, 18.0, 14.0, 8.0)
	var kinds: Array = []
	for l: Node in mega.find_children("*", "RampLip", true, false):
		kinds.append((l as RampLip).kind)
	assert_true(kinds.has("roll_in") and kinds.has("drop_in"), "mega ramp: roll-in deck and quarter pipe coping")
	mega.free()
