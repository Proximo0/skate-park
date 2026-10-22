extends TestCase


func _with_state(s: SkateState.State) -> SkateState:
	var k: SkateState = SkateState.new()
	k.state = s
	return k


func _count_landed(k: SkateState) -> Array:
	var got: Array = []
	k.combo_landed.connect(func() -> void: got.append(1))
	return got


func test_initial_state() -> void:
	var k: SkateState = SkateState.new()
	assert_eq(k.state, SkateState.State.ROLLING)
	assert_eq(k.time_in_state, 0.0)
	assert_false(k.combo_open)


func test_ollie_allowed_from_grounded_and_air_tricks() -> void:
	var from_states: Array = [
		SkateState.State.ROLLING, SkateState.State.MANUAL, SkateState.State.GRIND,
		SkateState.State.LIP, SkateState.State.WALLRIDE,
	]
	for s: int in from_states:
		var k: SkateState = _with_state(s as SkateState.State)
		assert_true(k.event("ollie"), "ollie from %d" % s)
		assert_eq(k.state, SkateState.State.AIR)
	var refused: Array = [SkateState.State.AIR, SkateState.State.BAIL]
	for s: int in refused:
		var k: SkateState = _with_state(s as SkateState.State)
		assert_false(k.event("ollie"), "ollie refused from %d" % s)
		assert_eq(k.state, s as SkateState.State)


func test_fall_off_allowed_from_rolling_grind_manual_wallride() -> void:
	var allowed: Array = [
		SkateState.State.ROLLING, SkateState.State.GRIND,
		SkateState.State.MANUAL, SkateState.State.WALLRIDE,
	]
	for s: int in allowed:
		var k: SkateState = _with_state(s as SkateState.State)
		assert_true(k.event("fall_off"), "fall_off from %d" % s)
		assert_eq(k.state, SkateState.State.AIR)
	var refused: Array = [SkateState.State.AIR, SkateState.State.LIP, SkateState.State.BAIL]
	for s: int in refused:
		var k: SkateState = _with_state(s as SkateState.State)
		assert_false(k.event("fall_off"), "fall_off refused from %d" % s)
		assert_eq(k.state, s as SkateState.State)


func test_land_only_from_air() -> void:
	var k: SkateState = _with_state(SkateState.State.AIR)
	assert_true(k.event("land"))
	assert_eq(k.state, SkateState.State.ROLLING)
	for s: int in [SkateState.State.ROLLING, SkateState.State.MANUAL, SkateState.State.GRIND,
			SkateState.State.LIP, SkateState.State.WALLRIDE, SkateState.State.BAIL]:
		var other: SkateState = _with_state(s as SkateState.State)
		assert_false(other.event("land"), "land refused from %d" % s)


func test_land_manual_only_from_air() -> void:
	var k: SkateState = _with_state(SkateState.State.AIR)
	assert_true(k.event("land_manual"))
	assert_eq(k.state, SkateState.State.MANUAL)
	for s: int in [SkateState.State.ROLLING, SkateState.State.GRIND, SkateState.State.LIP,
			SkateState.State.MANUAL, SkateState.State.WALLRIDE, SkateState.State.BAIL]:
		var other: SkateState = _with_state(s as SkateState.State)
		assert_false(other.event("land_manual"), "land_manual refused from %d" % s)


func test_bail_from_every_state_but_bail() -> void:
	for s: int in [SkateState.State.ROLLING, SkateState.State.AIR, SkateState.State.GRIND,
			SkateState.State.MANUAL, SkateState.State.LIP, SkateState.State.WALLRIDE]:
		var k: SkateState = _with_state(s as SkateState.State)
		assert_true(k.event("bail"), "bail from %d" % s)
		assert_eq(k.state, SkateState.State.BAIL)
	var b: SkateState = _with_state(SkateState.State.BAIL)
	assert_false(b.event("bail"), "bail refused in BAIL")
	assert_eq(b.state, SkateState.State.BAIL)


func test_grind_start_from_air_rolling_and_manual_only() -> void:
	# MANUAL -> GRIND: grind pressed in a manual beside a rail grinds straight from it (a THUG2 link)
	for s: int in [SkateState.State.AIR, SkateState.State.ROLLING, SkateState.State.MANUAL]:
		var k: SkateState = _with_state(s as SkateState.State)
		assert_true(k.event("grind_start"), "grind_start from %d" % s)
		assert_eq(k.state, SkateState.State.GRIND)
	for s: int in [SkateState.State.GRIND, SkateState.State.LIP,
			SkateState.State.WALLRIDE, SkateState.State.BAIL]:
		var k: SkateState = _with_state(s as SkateState.State)
		assert_false(k.event("grind_start"), "grind_start refused from %d" % s)


func test_manual_start_and_end() -> void:
	var k: SkateState = _with_state(SkateState.State.ROLLING)
	assert_true(k.event("manual_start"))
	assert_eq(k.state, SkateState.State.MANUAL)
	assert_true(k.event("manual_end"))
	assert_eq(k.state, SkateState.State.ROLLING)
	var air: SkateState = _with_state(SkateState.State.AIR)
	assert_false(air.event("manual_start"), "manual_start only from ROLLING")
	var grind: SkateState = _with_state(SkateState.State.GRIND)
	assert_false(grind.event("manual_end"), "manual_end only from MANUAL")


func test_lip_start_and_end() -> void:
	var k: SkateState = _with_state(SkateState.State.AIR)
	assert_true(k.event("lip_start"))
	assert_eq(k.state, SkateState.State.LIP)
	assert_true(k.event("lip_end"))
	assert_eq(k.state, SkateState.State.AIR)
	var rolling: SkateState = _with_state(SkateState.State.ROLLING)
	assert_false(rolling.event("lip_start"), "lip_start only from AIR")
	var lip: SkateState = _with_state(SkateState.State.LIP)
	assert_false(lip.event("lip_start"), "lip_start refused while in LIP")


func test_wallride_start_from_air_only() -> void:
	var k: SkateState = _with_state(SkateState.State.AIR)
	assert_true(k.event("wallride_start"))
	assert_eq(k.state, SkateState.State.WALLRIDE)
	for s: int in [SkateState.State.ROLLING, SkateState.State.MANUAL, SkateState.State.GRIND,
			SkateState.State.LIP, SkateState.State.WALLRIDE, SkateState.State.BAIL]:
		var other: SkateState = _with_state(s as SkateState.State)
		assert_false(other.event("wallride_start"), "wallride_start refused from %d" % s)


func test_unknown_event_refused() -> void:
	var k: SkateState = _with_state(SkateState.State.ROLLING)
	assert_false(k.event("kickflip"))
	assert_false(k.event(""))
	assert_eq(k.state, SkateState.State.ROLLING)


func test_refused_event_emits_nothing_and_keeps_timer() -> void:
	var k: SkateState = _with_state(SkateState.State.ROLLING)
	var changes: Array = []
	k.state_changed.connect(func(f: SkateState.State, t: SkateState.State) -> void: changes.append([f, t]))
	k.tick(0.2)
	assert_false(k.event("land"))
	assert_false(k.event("lip_end"))
	assert_eq(changes.size(), 0)
	assert_near(k.time_in_state, 0.2, 0.0001, "refused events do not reset the timer")


func test_state_changed_signal_and_timer_reset() -> void:
	var k: SkateState = SkateState.new()
	var changes: Array = []
	k.state_changed.connect(func(f: SkateState.State, t: SkateState.State) -> void: changes.append([f, t]))
	k.tick(0.5)
	assert_true(k.event("ollie"))
	assert_eq(changes.size(), 1)
	assert_eq(changes[0], [SkateState.State.ROLLING, SkateState.State.AIR])
	assert_eq(k.time_in_state, 0.0, "timer resets on entry")


func test_state_name() -> void:
	var k: SkateState = SkateState.new()
	assert_eq(k.state_name(), "ROLLING")
	k.state = SkateState.State.AIR
	assert_eq(k.state_name(), "AIR")
	k.state = SkateState.State.GRIND
	assert_eq(k.state_name(), "GRIND")
	k.state = SkateState.State.MANUAL
	assert_eq(k.state_name(), "MANUAL")
	k.state = SkateState.State.LIP
	assert_eq(k.state_name(), "LIP")
	k.state = SkateState.State.WALLRIDE
	assert_eq(k.state_name(), "WALLRIDE")
	k.state = SkateState.State.BAIL
	assert_eq(k.state_name(), "BAIL")


func test_grounded_and_air_queries() -> void:
	var expect: Dictionary = {
		SkateState.State.ROLLING: [true, false],
		SkateState.State.MANUAL: [true, false],
		SkateState.State.AIR: [false, true],
		SkateState.State.GRIND: [false, false],
		SkateState.State.LIP: [false, false],
		SkateState.State.WALLRIDE: [false, false],
		SkateState.State.BAIL: [false, false],
	}
	for s: int in expect:
		var k: SkateState = _with_state(s as SkateState.State)
		var pair: Array = expect[s]
		assert_eq(k.is_grounded(), pair[0], "is_grounded in %d" % s)
		assert_eq(k.can_trick_in_air(), pair[1], "can_trick_in_air in %d" % s)


func test_mark_trick_opens_combo() -> void:
	var k: SkateState = SkateState.new()
	k.mark_trick()
	assert_true(k.combo_open)


func test_landing_window_lands_combo() -> void:
	var k: SkateState = SkateState.new()
	var landed: Array = _count_landed(k)
	k.mark_trick()
	assert_true(k.event("ollie"))
	k.tick(1.0)
	assert_eq(landed.size(), 0, "no landing while airborne")
	assert_true(k.event("land"))
	k.tick(0.2)
	assert_eq(landed.size(), 0, "inside the landing window")
	k.tick(0.15)
	assert_eq(landed.size(), 1, "lands once the window expires")
	assert_false(k.combo_open, "landing closes the combo")
	k.tick(1.0)
	assert_eq(landed.size(), 1, "does not land twice")


func test_landing_window_exact_boundary() -> void:
	var k: SkateState = SkateState.new()
	var landed: Array = _count_landed(k)
	k.mark_trick()
	k.event("ollie")
	k.event("land")
	k.tick(SkateState.LAND_WINDOW)
	assert_eq(landed.size(), 1, "window is inclusive at LAND_WINDOW")


func test_no_landing_without_combo() -> void:
	var k: SkateState = SkateState.new()
	var landed: Array = _count_landed(k)
	k.event("ollie")
	k.event("land")
	k.tick(2.0)
	assert_eq(landed.size(), 0)


func test_no_landing_while_airborne_with_open_combo() -> void:
	var k: SkateState = SkateState.new()
	var landed: Array = _count_landed(k)
	k.mark_trick()
	k.event("ollie")
	k.tick(5.0)
	assert_eq(landed.size(), 0, "combo stays open in the air")
	assert_true(k.combo_open)


func test_manual_linking_keeps_combo_going() -> void:
	var k: SkateState = SkateState.new()
	var landed: Array = _count_landed(k)
	k.mark_trick()
	k.event("ollie")
	k.event("land")
	k.tick(0.1)
	assert_true(k.event("manual_start"))
	k.tick(1.0)
	assert_eq(landed.size(), 0, "no landing while on manual")
	assert_true(k.event("manual_end"))
	k.tick(0.2)
	assert_eq(landed.size(), 0, "the landing window restarts on manual_end")
	k.tick(0.2)
	assert_eq(landed.size(), 1)


func test_land_manual_keeps_combo_going() -> void:
	var k: SkateState = SkateState.new()
	var landed: Array = _count_landed(k)
	k.mark_trick()
	k.event("ollie")
	k.event("land_manual")
	k.tick(2.0)
	assert_eq(landed.size(), 0, "landing onto a manual does not land the combo")
	k.event("manual_end")
	k.tick(0.4)
	assert_eq(landed.size(), 1)


func test_revert_inside_window_keeps_combo_open() -> void:
	var k: SkateState = SkateState.new()
	var landed: Array = _count_landed(k)
	k.mark_trick()
	k.event("ollie")
	k.event("land")
	k.tick(0.2)
	assert_true(k.event("revert"))
	assert_eq(k.state, SkateState.State.ROLLING, "revert stays ROLLING")
	assert_true(k.combo_open, "revert keeps the combo open")
	assert_eq(k.time_in_state, 0.0, "revert restarts the landing window")
	k.tick(0.3)
	assert_eq(landed.size(), 0, "0.3 s after the revert is still inside the new window")
	k.tick(0.1)
	assert_eq(landed.size(), 1)


func test_revert_emits_no_state_change() -> void:
	var k: SkateState = SkateState.new()
	var changes: Array = []
	k.state_changed.connect(func(f: SkateState.State, t: SkateState.State) -> void: changes.append([f, t]))
	k.event("ollie")
	k.event("land")
	var before: int = changes.size()
	assert_true(k.event("revert"))
	assert_eq(changes.size(), before, "revert does not emit state_changed")


func test_revert_chains_while_inside_window() -> void:
	var k: SkateState = SkateState.new()
	var landed: Array = _count_landed(k)
	k.mark_trick()
	k.event("ollie")
	k.event("land")
	k.tick(0.2)
	assert_true(k.event("revert"))
	k.tick(0.2)
	assert_true(k.event("revert"), "second revert inside the restarted window")
	k.tick(0.2)
	assert_eq(landed.size(), 0)
	k.tick(0.2)
	assert_eq(landed.size(), 1)


func test_revert_refused_after_window() -> void:
	var k: SkateState = SkateState.new()
	var landed: Array = _count_landed(k)
	k.mark_trick()
	k.event("ollie")
	k.event("land")
	k.tick(0.4)
	assert_eq(landed.size(), 1)
	assert_false(k.event("revert"), "revert refused after the window")
	assert_eq(k.state, SkateState.State.ROLLING)


func test_revert_refused_exactly_at_window_end() -> void:
	var k: SkateState = SkateState.new()
	k.event("ollie")
	k.event("land")
	k.tick(SkateState.REVERT_WINDOW)
	assert_false(k.event("revert"), "window is exclusive at REVERT_WINDOW")


func test_revert_refused_when_not_landed_from_air() -> void:
	var fresh: SkateState = SkateState.new()
	assert_false(fresh.event("revert"), "no landing yet")

	var manual: SkateState = SkateState.new()
	manual.event("manual_start")
	manual.event("manual_end")
	assert_false(manual.event("revert"), "manual_end is not a landing from AIR")

	var recovered: SkateState = SkateState.new()
	recovered.event("bail")
	recovered.tick(SkateState.BAIL_TIME)
	recovered.event("recover")
	assert_false(recovered.event("revert"), "recover is not a landing from AIR")


func test_revert_refused_outside_rolling() -> void:
	var k: SkateState = SkateState.new()
	k.event("ollie")
	k.event("land")
	k.event("ollie")
	assert_false(k.event("revert"), "revert refused in AIR")
	var m: SkateState = SkateState.new()
	m.event("ollie")
	m.event("land_manual")
	assert_false(m.event("revert"), "revert refused on MANUAL")


func test_manual_end_clears_revert_gate() -> void:
	var k: SkateState = SkateState.new()
	k.event("ollie")
	k.event("land")
	k.event("manual_start")
	k.event("manual_end")
	assert_false(k.event("revert"), "the gate is cleared on manual_end")


func test_bail_closes_combo_and_emits_bailed() -> void:
	var k: SkateState = SkateState.new()
	var landed: Array = _count_landed(k)
	var bailed: Array = []
	k.combo_bailed.connect(func() -> void: bailed.append(1))
	k.mark_trick()
	k.event("ollie")
	assert_true(k.event("bail"))
	assert_eq(bailed.size(), 1, "combo_bailed emitted")
	assert_false(k.combo_open, "bail clears the combo")
	k.event("recover") # too early, ignored
	k.tick(SkateState.BAIL_TIME)
	assert_true(k.event("recover"))
	k.tick(1.0)
	assert_eq(landed.size(), 0, "a bailed combo never lands")
	assert_eq(bailed.size(), 1)


func test_bail_without_combo_emits_nothing() -> void:
	var k: SkateState = SkateState.new()
	var bailed: Array = []
	k.combo_bailed.connect(func() -> void: bailed.append(1))
	assert_true(k.event("bail"))
	assert_eq(bailed.size(), 0)


func test_bail_while_in_bail_is_refused_and_silent() -> void:
	var k: SkateState = SkateState.new()
	k.event("bail")
	k.mark_trick()
	var bailed: Array = []
	k.combo_bailed.connect(func() -> void: bailed.append(1))
	assert_false(k.event("bail"))
	assert_eq(bailed.size(), 0)
	assert_true(k.combo_open, "a refused bail leaves the combo alone")


func test_recover_timing() -> void:
	var k: SkateState = SkateState.new()
	k.event("bail")
	k.tick(1.0)
	assert_false(k.event("recover"), "refused at 1.0 s")
	assert_eq(k.state, SkateState.State.BAIL)
	k.tick(0.1)
	assert_false(k.event("recover"), "refused at 1.1 s")
	k.tick(0.1)
	assert_true(k.event("recover"), "allowed at 1.2 s")
	assert_eq(k.state, SkateState.State.ROLLING)
	assert_eq(k.time_in_state, 0.0)


func test_recover_allowed_exactly_at_bail_time() -> void:
	var k: SkateState = SkateState.new()
	k.event("bail")
	k.tick(SkateState.BAIL_TIME)
	assert_true(k.event("recover"))


func test_recover_only_from_bail() -> void:
	var k: SkateState = SkateState.new()
	k.tick(5.0)
	assert_false(k.event("recover"), "recover refused from ROLLING")
	var air: SkateState = _with_state(SkateState.State.AIR)
	air.tick(5.0)
	assert_false(air.event("recover"), "recover refused from AIR")


func test_recover_starts_landing_window() -> void:
	var k: SkateState = SkateState.new()
	var landed: Array = _count_landed(k)
	k.event("bail")
	k.tick(SkateState.BAIL_TIME)
	k.event("recover")
	k.mark_trick()
	k.tick(0.2)
	assert_eq(landed.size(), 0)
	k.tick(0.2)
	assert_eq(landed.size(), 1, "a trick scored after recovery lands once the window passes")


func test_open_combo_on_ground_lands_on_next_tick_after_window() -> void:
	var k: SkateState = SkateState.new()
	var landed: Array = _count_landed(k)
	k.tick(1.0)
	k.mark_trick()
	assert_eq(landed.size(), 0, "no landing during mark_trick itself")
	k.tick(0.0)
	assert_eq(landed.size(), 1, "a trick scored while rolling past the window lands on the next tick")


func test_dismount_only_from_rolling_and_mount_only_from_walk() -> void:
	var k: SkateState = SkateState.new()
	assert_false(k.event("mount"), "mount refused while rolling")
	assert_true(k.event("dismount"))
	assert_eq(k.state, SkateState.State.WALK)
	assert_eq(k.state_name(), "WALK")
	assert_false(k.event("dismount"), "already walking")
	assert_true(k.event("mount"))
	assert_eq(k.state, SkateState.State.ROLLING)
	for s: int in [SkateState.State.AIR, SkateState.State.GRIND, SkateState.State.MANUAL, SkateState.State.LIP,
			SkateState.State.WALLRIDE, SkateState.State.BAIL]:
		var o: SkateState = _with_state(s as SkateState.State)
		assert_false(o.event("dismount"), "no dismount from %d" % s)
		assert_eq(o.state, s as SkateState.State)


func test_walk_refuses_tricks_and_takes_bail() -> void:
	for ev: String in ["ollie", "fall_off", "land", "grind_start", "manual_start", "wallride_start", "revert"]:
		var k: SkateState = _with_state(SkateState.State.WALK)
		assert_false(k.event(ev), "%s refused while walking" % ev)
		assert_eq(k.state, SkateState.State.WALK)
	var b: SkateState = _with_state(SkateState.State.WALK)
	assert_true(b.event("bail"))
	assert_eq(b.state, SkateState.State.BAIL)


func test_combo_lands_while_walking() -> void:
	var k: SkateState = SkateState.new()
	var landed: Array = _count_landed(k)
	k.mark_trick()
	k.event("dismount")
	k.tick(0.2)
	assert_eq(landed.size(), 0)
	k.tick(0.2)
	assert_eq(landed.size(), 1, "an open combo lands after the window even on foot")


func test_caveman_only_from_walk_and_lands_rolling() -> void:
	var k: SkateState = _with_state(SkateState.State.WALK)
	assert_true(k.event("caveman"), "caveman from walking")
	assert_eq(k.state, SkateState.State.AIR)
	assert_true(k.event("land"))
	assert_eq(k.state, SkateState.State.ROLLING)
	for s: int in [SkateState.State.ROLLING, SkateState.State.AIR, SkateState.State.GRIND, SkateState.State.BAIL]:
		var o: SkateState = _with_state(s as SkateState.State)
		assert_false(o.event("caveman"), "no caveman from %d" % s)
