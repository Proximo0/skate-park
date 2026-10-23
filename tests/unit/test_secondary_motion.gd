extends TestCase
## SecondaryMotion on a hand-built rig: pivot discovery by prefix, settling, bounded response, toggles.


func _joint(parent: Node3D, name: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = at
	parent.add_child(n)
	return n


## Root > Chest > BodySway_BustL/R ; Root > Head > HairSway_SideL/R and the ponytail chain; one extra style.
func _rig() -> Dictionary:
	var root := Node3D.new()
	var chest: Node3D = _joint(root, "Chest", Vector3(0, 1.2, 0))
	_joint(chest, "BodySway_BustL", Vector3(-0.08, 0.0, -0.06))
	_joint(chest, "BodySway_BustR", Vector3(0.08, 0.0, -0.06))
	var head: Node3D = _joint(root, "Head", Vector3(0, 1.6, 0))
	_joint(head, "HairSway_SideL", Vector3(-0.07, 0.05, 0))
	_joint(head, "HairSway_SideR", Vector3(0.07, 0.05, 0))
	var p1: Node3D = _joint(head, "HairSway_Ponytail", Vector3(0, 0.08, 0.1))
	var p2: Node3D = _joint(p1, "HairSway_Ponytail2", Vector3(0, -0.1, 0.05))
	_joint(p2, "HairSway_Ponytail3", Vector3(0, -0.1, 0.02))
	_joint(head, "HairSway_Bangs", Vector3(0, 0.1, -0.08))
	return {"root": root, "head": head}


func _make(rig: Dictionary) -> SecondaryMotion:
	var sm := SecondaryMotion.new()
	sm.follow_settings = false
	sm.bind(rig["root"] as Node3D)
	return sm


func test_finds_pivots_by_prefix() -> void:
	var rig: Dictionary = _rig()
	var sm: SecondaryMotion = _make(rig)
	assert_eq(sm.pivot_count(), 8)
	var names: Array[String] = []
	for n: Node3D in sm.pivot_nodes():
		names.append(String(n.name))
	assert_true("HairSway_Bangs" in names, "new styles are found without a list")
	assert_true("BodySway_BustR" in names)
	assert_false("Head" in names)
	(rig["root"] as Node).free()
	sm.free()


func test_stationary_settles_to_rest() -> void:
	var rig: Dictionary = _rig()
	var sm: SecondaryMotion = _make(rig)
	var rests: Array[Transform3D] = []
	for n: Node3D in sm.pivot_nodes():
		rests.append(n.transform)
	for i: int in 240:
		sm.tick()
	var nodes: Array[Node3D] = sm.pivot_nodes()
	for i: int in nodes.size():
		assert_true(nodes[i].transform.is_equal_approx(rests[i]), "%s at rest" % nodes[i].name)
	(rig["root"] as Node).free()
	sm.free()


func test_sudden_acceleration_is_bounded() -> void:
	var rig: Dictionary = _rig()
	var root: Node3D = rig["root"]
	var sm: SecondaryMotion = _make(rig)
	var rests: Dictionary = {}
	for n: Node3D in sm.pivot_nodes():
		rests[n] = n.transform
	var moved: bool = false
	var z: float = 0.0
	var v: float = 0.0
	for i: int in 180:
		# Hard shove then a hard stop, plus a vertical bump.
		v = 12.0 if i < 20 else (0.0 if i < 40 else v)
		z += -v / 60.0
		root.position = Vector3(0.0, 0.1 if i == 100 else 0.0, z)
		sm.tick()
		for n: Node3D in sm.pivot_nodes():
			var rest: Transform3D = rests[n]
			var delta: Basis = rest.basis.inverse() * n.transform.basis
			var ang: float = rad_to_deg(Quaternion(delta).get_angle())
			if String(n.name).begins_with("BodySway_"):
				var prm: Dictionary = SecondaryMotion.bust_params(sm.body_level)
				assert_true(ang <= float(prm["tilt"]) + 0.01, "bust tilt %f" % ang)
				assert_true(n.transform.origin.distance_to(rest.origin) <= float(prm["max"]) + 0.0001, "bust travel")
			else:
				assert_true(ang <= 61.0, "%s swing %f" % [n.name, ang])
				var e: Vector3 = delta.get_euler()
				if n.name == "HairSway_Ponytail":
					assert_true(e.x >= -deg_to_rad(30.01) and e.x <= deg_to_rad(18.01), "ponytail link 1 range")
				assert_true(absf(e.z) <= deg_to_rad(30.01), "lateral")
			if ang > 0.2:
				moved = true
	assert_true(moved, "the shove moves something")
	root.free()
	sm.free()


func test_toggles_off_keep_identity() -> void:
	var rig: Dictionary = _rig()
	var root: Node3D = rig["root"]
	var sm: SecondaryMotion = _make(rig)
	var rests: Array[Transform3D] = []
	for n: Node3D in sm.pivot_nodes():
		rests.append(n.transform)
	sm.hair_enabled = false
	sm.body_enabled = false
	for i: int in 60:
		root.position = Vector3(0, 0, -float(i % 7))
		sm.tick()
	var nodes: Array[Node3D] = sm.pivot_nodes()
	for i: int in nodes.size():
		assert_true(nodes[i].transform.is_equal_approx(rests[i]), "%s untouched" % nodes[i].name)
	root.free()
	sm.free()


func test_hair_only_toggle_leaves_bust_moving() -> void:
	var rig: Dictionary = _rig()
	var root: Node3D = rig["root"]
	var sm: SecondaryMotion = _make(rig)
	sm.hair_enabled = false
	var bust_moved: bool = false
	for i: int in 60:
		root.position = Vector3(0, 0.05 * float(i % 2), 0)
		sm.tick()
	for n: Node3D in sm.pivot_nodes():
		if String(n.name).begins_with("HairSway_"):
			assert_true(n.transform.basis.is_equal_approx(Basis.IDENTITY), "hair stays put")
		elif not n.transform.origin.is_equal_approx(Vector3(n.position.x, 0.0, -0.06)):
			bust_moved = true
	assert_true(bust_moved, "bust still reacts")
	root.free()
	sm.free()


func test_teleport_resets_state() -> void:
	var rig: Dictionary = _rig()
	var root: Node3D = rig["root"]
	var sm: SecondaryMotion = _make(rig)
	for i: int in 30:
		root.position = Vector3(0, 0, -0.3 * float(i * i % 5))
		sm.tick()
	root.position = Vector3(200, 0, 0)
	sm.tick()
	for i: int in 240:
		sm.tick()
	for n: Node3D in sm.pivot_nodes():
		if String(n.name).begins_with("HairSway_"):
			assert_true(n.transform.basis.is_equal_approx(Basis.IDENTITY), "%s settled after teleport" % n.name)
	root.free()
	sm.free()


func test_bust_levels_bounce_more_as_they_rise() -> void:
	# A landing: the chest drops and stops dead. Count how far and how long the bust keeps moving after the stop.
	var travel: Array[float] = []
	var settle: Array[int] = []
	for level: int in SecondaryMotion.BUST_LEVELS.size():
		var rig: Dictionary = _rig()
		var root: Node3D = rig["root"]
		var sm: SecondaryMotion = _make(rig)
		sm.hair_enabled = false
		sm.body_level = level
		var bust: Node3D = null
		for n: Node3D in sm.pivot_nodes():
			if String(n.name).begins_with("BodySway_"):
				bust = n
		var rest: Vector3 = bust.position
		var y: float = 0.5
		var most: float = 0.0
		var last_move: int = 0
		for i: int in 150:
			y = maxf(0.0, 0.5 - 0.5 * 9.8 * pow(float(i) / 60.0, 2.0)) if i < 20 else 0.0
			root.position = Vector3(0.0, y, 0.0)
			sm.tick()
			var d: float = bust.position.distance_to(rest)
			if i >= 20:
				most = maxf(most, d)
				if d > 0.0015:
					last_move = i
		travel.append(most)
		settle.append(last_move)
		assert_true(most <= float(SecondaryMotion.bust_params(level)["max"]) + 0.0001, "level %d stays within its limit" % level)
		root.free()
		sm.free()
	assert_near(travel[0], 0.0, 0.00001, "Off does not move")
	assert_true(travel[1] < travel[2] and travel[2] < travel[3], "stronger levels travel further %s" % str(travel))
	assert_true(travel[2] > 0.008, "Normal visibly bounces on a landing (%f m)" % travel[2])
	assert_true(settle[2] < 140, "Normal settles within about two seconds")


func test_body_level_cycle() -> void:
	assert_eq(GameSettings.next_body_level(0), 1)
	assert_eq(GameSettings.next_body_level(3), 0)
	assert_eq(GameSettings.BODY_LEVEL_NAMES[SecondaryMotion.BUST_DEFAULT_LEVEL], "Normal")
