extends TestCase
## BailKind: bail classification from the failure, severity from the impact speed, the injury picks and the meat.


func _land(up: Vector3, v: Vector3, spin: float = 0.0, n: Vector3 = Vector3.UP, fwd: Vector3 = Vector3.FORWARD) -> Dictionary:
	return {"cause": "land", "velocity": v, "normal": n, "facing": fwd, "board_up": up.normalized(), "spin_deg": spin}


func test_causes_map_to_their_kinds() -> void:
	assert_eq(BailKind.kind_of({"cause": "wall"}), "wall_slam")
	assert_eq(BailKind.kind_of({"cause": "manual", "lean": -0.5}), "manual_back", "leaned back off a manual")
	assert_eq(BailKind.kind_of({"cause": "manual", "lean": 0.5}), "manual_front", "nose dipped off a manual")
	assert_eq(BailKind.kind_of({"cause": "lip"}), "lip_fall")
	assert_eq(BailKind.kind_of({"cause": "flip"}), "flip_tangle", "landed with the board still flipping")
	assert_eq(BailKind.kind_of({"cause": "grind", "drop": 2.5, "rail_speed": 1.0}), "racked", "slow on a high rail")
	assert_eq(BailKind.kind_of({"cause": "grind", "drop": 0.6, "rail_speed": 1.0}), "grind_tip")
	assert_eq(BailKind.kind_of({"cause": "grind", "drop": 2.5, "rail_speed": 8.0}), "grind_tip", "fast off a high rail")
	assert_eq(BailKind.kind_of({"cause": "wall", "kind": "primo"}), "primo", "a forced kind wins")
	assert_eq(BailKind.kind_of({"cause": "wall", "kind": "nonsense"}), "wall_slam", "an unknown forced kind is ignored")


func test_landing_tilts_classify() -> void:
	var v: Vector3 = Vector3(0, -3, -10)
	# Rider frame: forward -Z, right (toe side) +X.
	assert_eq(BailKind.kind_of(_land(Vector3(1, 0.1, 0), v)), "primo", "board on its edge")
	assert_eq(BailKind.kind_of(_land(Vector3(0.85, 0.45, 0), v)), "toe_catch", "tipped onto the toe edge")
	assert_eq(BailKind.kind_of(_land(Vector3(-0.85, 0.45, 0), v)), "heel_catch", "tipped onto the heel edge")
	assert_eq(BailKind.kind_of(_land(Vector3(0, 0.4, -0.9), v)), "over_rotated", "nose down on flat ground")
	assert_eq(BailKind.kind_of(_land(Vector3(0, 0.4, 0.9), v)), "back_slam", "tail down")
	assert_eq(BailKind.kind_of(_land(Vector3(0, -1, 0), v)), "back_slam", "landed on the board upside down")
	var bank: Vector3 = Vector3(0, 0.85, 0.53).normalized()
	var f: Vector3 = Vector3.FORWARD.slide(bank).normalized()
	var up: Vector3 = bank * cos(deg_to_rad(65.0)) + f * sin(deg_to_rad(65.0))
	assert_eq(BailKind.kind_of(_land(up, v, 0.0, bank)), "nose_dive", "nose into a bank")


func test_big_drop_and_stairs() -> void:
	assert_eq(BailKind.kind_of(_land(Vector3(0.85, 0.45, 0), Vector3(0, -15, -4))), "big_drop", "a big fall beats the tilt")
	assert_eq(BailKind.kind_of(_land(Vector3(1, 0.1, 0), Vector3(0, -15, -4))), "primo", "but a primo is still a primo")
	var c: Dictionary = _land(Vector3(0.75, 0.6, 0), Vector3(0, -5, -9))
	c["stairs"] = true
	assert_eq(BailKind.kind_of(c), "stair_slam")


func test_spin_direction_splits_over_and_under_rotation() -> void:
	# Travelling -Z, board turned 70 degrees counter-clockwise (seen from above).
	var fwd: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(70.0))
	var v: Vector3 = Vector3(0, -2, -10)
	assert_true(BailKind.heading_error(fwd, v, Vector3.UP) > 60.0, "heading error is signed counter-clockwise")
	assert_eq(BailKind.kind_of(_land(Vector3.UP, v, 430.0, Vector3.UP, fwd)), "over_rotated", "spun ccw past the 360")
	assert_eq(BailKind.kind_of(_land(Vector3.UP, v, -290.0, Vector3.UP, fwd)), "under_rotated", "spun cw, stopped short")
	assert_eq(BailKind.kind_of(_land(Vector3.UP, v, 10.0, Vector3.UP, fwd)), "under_rotated", "no spin: sideways slam")
	var fakie: Vector3 = Vector3.BACK.rotated(Vector3.UP, deg_to_rad(70.0))
	assert_true(BailKind.heading_error(fakie, v, Vector3.UP) > 60.0, "fakie folds onto the same error")


func test_severity_scales_with_impact() -> void:
	assert_eq(BailKind.severity(2.0), 0.0)
	assert_eq(BailKind.severity(40.0), 1.0)
	var last: float = -1.0
	for i: int in 25:
		var s: float = BailKind.severity(float(i))
		assert_true(s >= last, "severity never drops as the impact grows")
		last = s
	assert_eq(BailKind.injury_count(0.05), 0, "a soft bail is a plain bail")
	assert_eq(BailKind.injury_count(0.3), 1)
	assert_eq(BailKind.injury_count(0.7), 2)
	assert_eq(BailKind.injury_count(0.95), 3)
	var soft: Dictionary = BailKind.injury("wrist", "L", 0.0)
	var hard: Dictionary = BailKind.injury("wrist", "L", 1.0)
	assert_true(float(hard["angle"]) > float(soft["angle"]), "harder slams bend further")
	assert_true(BailKind.meat(0.9, 2) > BailKind.meat(0.3, 2), "harder slams are worth more meat")
	assert_true(BailKind.meat(0.6, 3) > BailKind.meat(0.6, 1), "stacked injuries are worth more meat")
	assert_eq(BailKind.meat(0.6, 0), 0)
	assert_eq(BailKind.meat(0.5, 1) % 10, 0, "meat rounds to tens")


func test_injury_angles_stay_cartoon_but_past_the_limit() -> void:
	for id: String in BailKind.INJURIES:
		var d: Dictionary = BailKind.INJURIES[id]
		var r: Vector2 = d["deg"]
		assert_true(r.x >= 20.0 and r.y <= 110.0 and r.x < r.y, id + " angle range is visible but bounded")
		assert_true(str(d["label"]) != "", id + " has a readout label")
	var ankle: Dictionary = BailKind.injury("ankle", "R", 1.0)
	assert_true(rad_to_deg(float(ankle["angle"])) >= 70.0 and rad_to_deg(float(ankle["angle"])) <= 90.0, "ankle rolls 70-90 degrees")
	assert_eq(str(ankle["joint"]), "RightFoot")
	assert_eq(str(BailKind.injury("neck", "L", 0.5)["joint"]), "Head", "the neck has no side")


func test_classify_plans() -> void:
	var p: Dictionary = BailKind.classify({"cause": "wall", "impact": 17.0, "velocity": Vector3(0, 0, -17)})
	assert_eq(str(p["kind"]), "wall_slam")
	assert_eq(str(p["style"]), "wall_splat")
	assert_true(BailKind.STYLES.has(str(p["style"])), "every plan names a known style")
	assert_true((p["injuries"] as Array).size() >= 2, "a hard wall slam hurts more than once")
	var joints: Array = []
	for inj: Dictionary in p["injuries"]:
		assert_false(joints.has(inj["joint"]), "no joint hurt twice")
		joints.append(inj["joint"])
		assert_true(SkaterPoser.JOINTS.has(str(inj["joint"])), str(inj["joint"]) + " is a rig joint")
	assert_true(int(p["meat"]) > 0)
	var off: Dictionary = BailKind.classify({"cause": "wall", "impact": 17.0}, false)
	assert_eq((off["injuries"] as Array).size(), 0, "injuries off: a plain ragdoll")
	assert_eq(int(off["meat"]), 0)
	assert_eq(str(off["style"]), "wall_splat", "the fall style stays with injuries off")
	var soft: Dictionary = BailKind.classify({"cause": "manual", "velocity": Vector3(0, 0, -3)})
	assert_eq((soft["injuries"] as Array).size(), 0, "a slow manual tip-over hurts nothing")
	for kind: String in BailKind.KINDS:
		var k: Dictionary = BailKind.KINDS[kind]
		assert_true(BailKind.STYLES.has(str(k["style"])), kind + " has a known style")
		for id: Variant in k["pool"]:
			assert_true(BailKind.INJURIES.has(str(id)), kind + " pool entry " + str(id))


func test_classify_is_deterministic() -> void:
	var ctx: Dictionary = _land(Vector3(0.75, 0.6, 0), Vector3(1.3, -4, -13))
	assert_eq(BailKind.classify(ctx), BailKind.classify(ctx), "same context, same plan")
	assert_eq(BailKind.pick_side({"lean": 0.4}), "R")
	assert_eq(BailKind.pick_side({"lean": -0.4}), "L")
