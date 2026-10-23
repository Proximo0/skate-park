extends TestCase
## World kit: moods, lane paths, the ocean's CPU wave model, traffic signals and pedestrian poses.


func test_every_mood_preset_has_the_base_keys() -> void:
	for id: String in Mood.ids():
		var p: Dictionary = Mood.preset(id)
		for k: String in Mood.BASE.keys():
			assert_true(p.has(k), "%s has %s" % [id, k])
		assert_eq(str(p["id"]), id)
		assert_true(Mood.sun_direction(p).y > 0.0 or bool(p["night"]), id + " sun above the horizon by day")


func test_mood_build_gives_environment_and_sun() -> void:
	var b: Dictionary = Mood.build("warehouse_night")
	assert_true(b["environment"] is WorldEnvironment)
	assert_true((b["environment"] as WorldEnvironment).environment != null, "with an Environment")
	assert_true(b["sun"] is DirectionalLight3D)
	assert_true(bool((b["preset"] as Dictionary)["night"]), "warehouse is a night mood")
	(b["sun"] as Node).free()
	(b["environment"] as Node).free()


func test_unknown_mood_falls_back() -> void:
	assert_false(Mood.has("no_such_mood"))
	assert_true(Mood.preset("no_such_mood").has("sun_energy"), "fallback preset is complete")


func test_lane_path_block_loop_length_and_wrap() -> void:
	var lp: LanePath = LanePath.block_loop(Rect2(0.0, 0.0, 40.0, 20.0), 0.0, 0.0, true)
	assert_near(lp.length, 120.0, 0.5, "perimeter of a sharp-cornered block")
	assert_near(lp.wrap_s(lp.length + 3.0), 3.0, 0.001)
	assert_near(lp.wrap_s(-2.0), lp.length - 2.0, 0.001)
	var p: Vector3 = lp.sample(10.0)
	assert_near(p.y, 0.0)


func test_lane_path_offset_moves_right_of_travel() -> void:
	var lp: LanePath = LanePath.from_points(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -50)]), false, 0.0)
	var right: LanePath = lp.offset(2.0)
	# travelling -Z, right is +X
	assert_near(right.sample(10.0).x, 2.0, 0.01)
	assert_near(lp.tangent(5.0).z, -1.0, 0.01)
	assert_near(lp.closest_s(Vector3(1.0, 0.0, -20.0)), 20.0, 0.2)


func test_lane_path_rounded_corners_have_curvature() -> void:
	var lp: LanePath = LanePath.block_loop(Rect2(0.0, 0.0, 60.0, 60.0), 0.0, 9.0, true)
	var best: float = 0.0
	var s: float = 0.0
	while s < lp.length:
		best = maxf(best, lp.curvature_ahead(s, 10.0))
		s += 2.0
	assert_true(best > 0.02 and best < 0.3, "corner curvature near 1/9, got %f" % best)


func test_ocean_height_is_bounded_and_stays_above_the_sand() -> void:
	var o := Ocean.new()
	for z: float in [2.0, 6.0, 20.0, 80.0, 400.0]:
		for t: float in [0.0, 1.3, 4.7]:
			var h: float = o.height_at(3.0, z, t)
			assert_true(absf(h) < 2.5, "wave height sane at z=%f: %f" % [z, h])
			var d: float = o.depth_at(z)
			if d > 1.0:
				assert_true(h > -d, "water above the sea floor at z=%f" % z)
	o.free()


func test_ocean_shoal_dies_on_the_sand() -> void:
	assert_near(Ocean.shoal(-2.0, 0.0), 0.0, 0.001, "chop gone on dry sand")
	assert_true(Ocean.shoal(3.0, 1.0) > 1.0, "swell grows in the shallows")
	assert_near(Ocean.shoal(200.0, 1.0), 1.0, 0.01, "deep water untouched")
	assert_near(Ocean.sand_height(-50.0, 0.08, 1.2), 1.2, 0.001, "berm caps the dry beach")


func test_ocean_meshes_build() -> void:
	var w: ArrayMesh = Ocean.water_mesh(200.0, 400.0, 20.0, 60.0, 80.0)
	assert_true(w.get_surface_count() == 1 and w.get_aabb().size.x >= 399.0, "water sheet spans its width")
	var b: ArrayMesh = Ocean.beach_mesh(100.0, 30.0, 40.0)
	assert_true(b.get_aabb().position.z <= -29.0 and b.get_aabb().end.z >= 39.0, "beach spans inland to seaward")


func test_traffic_signals_alternate_axes() -> void:
	var tr := Traffic.new()
	tr.add_intersection(Vector3.ZERO, 8.0, 0.0)
	tr.time = 1.0
	assert_eq(tr.signal_state(0, 0), "green")
	assert_eq(tr.signal_state(0, 1), "red")
	tr.time = Traffic.SIGNAL_GREEN + 0.5
	assert_eq(tr.signal_state(0, 0), "amber")
	tr.time = Traffic.SIGNAL_GREEN + Traffic.SIGNAL_AMBER + 1.0
	assert_eq(tr.signal_state(0, 0), "red")
	assert_eq(tr.signal_state(0, 1), "green")
	tr.free()


func test_car_kinds_have_info() -> void:
	for k: String in ["hatch", "pickup", "van"]:
		var info: Dictionary = CarModel.kind_info(k)
		assert_false(info.is_empty(), k + " has kind info")


func test_ped_poses_cover_every_mode() -> void:
	for m: String in ["walk", "idle", "phone", "chat", "wave", "startle"]:
		var p: Dictionary = PedPoser.ped_pose(m, 1.0, 0.25, 1.3 if m == "walk" else 0.0)
		for j: String in SkaterPoser.JOINTS:
			assert_true(p.has(j), "%s pose has %s" % [m, j])
		assert_true((p["board_pos"] as Vector3).y < -10.0, m + " hides the board")


func test_ped_pose_signs() -> void:
	# phone: head tips down (negative X), forearms bent up in front
	var phone: Dictionary = PedPoser.ped_pose("phone", 0.0, 0.0, 0.0)
	assert_true((phone["Head"] as Vector3).x < 0.0, "looking down at the phone")
	assert_true((phone["RightLowerArm"] as Vector3).x > 60.0, "elbow bent")
	# startle: arms come up in front (positive X swings forward)
	var st: Dictionary = PedPoser.ped_pose("startle", 0.0, 0.0, 0.0)
	assert_true((st["LeftUpperArm"] as Vector3).x > 20.0 and (st["RightUpperArm"] as Vector3).x > 20.0, "hands up in front")


func test_ped_cadence_matches_stride() -> void:
	assert_true(Pedestrian.cadence(1.3) > 0.5 and Pedestrian.cadence(1.3) < 2.5, "about one stride cycle per 1-2 m")
	assert_true(Pedestrian.cadence(0.6) > Pedestrian.cadence(1.6), "shorter strides when slow")
