extends TestCase
## Skater trick triggers that need no physics frame: the nollie (stance toggle + ollie), the powerslide's start and
## end hooks, and a bail dropping a combo of gaps only. Their ride physics are in tests/sim/sim_nollie_powerslide.gd.

const SkaterScript := preload("res://game/skater/skater.gd")


func _skater() -> Skater:
	var sk: Skater = SkaterScript.new()
	sk.db = TrickDB.load_default()
	sk.gaps = Gaps.load_default()
	return sk


func test_bail_drops_a_combo_of_gaps_only() -> void:
	var sk: Skater = _skater()
	var bailed: Array = []
	sk.combo_bailed.connect(func(t: String) -> void: bailed.append(t))
	sk.combo.add_gap("Over The Funbox", 250)
	assert_false(sk.state.combo_open, "a gap alone opens no trick combo")
	assert_true(sk.combo.is_active())
	sk._bail()
	assert_false(sk.combo.is_active(), "the gap combo is dropped by the bail, not shown again after the get-up")
	assert_eq(bailed.size(), 1, "the HUD hears the combo was bailed")
	sk.free()


func test_bail_with_a_trick_combo_bails_it_once() -> void:
	var sk: Skater = _skater()
	sk.state.combo_bailed.connect(sk._on_combo_bailed)
	var bailed: Array = []
	sk.combo_bailed.connect(func(t: String) -> void: bailed.append(t))
	sk._score_trick({"id": "kickflip", "name": "Kickflip", "points": 100, "kind": "flip"})
	sk._bail()
	assert_false(sk.combo.is_active())
	assert_eq(bailed.size(), 1)
	sk.free()


func test_nollie_toggles_and_pops_off_the_nose() -> void:
	var sk: Skater = _skater()
	var seen: Array = []
	sk.nollie_changed.connect(func(on: bool) -> void: seen.append(on))
	sk._set_nollie(true)
	assert_true(sk.nollie)
	sk._ollie(10.0)
	assert_eq(sk.anim, "nollie")
	assert_near(sk.velocity.y, 10.0 * sk.tune.nollie_pop, 0.001, "a nollie pops at nollie_pop of the ollie")
	assert_true(sk._nollie_air)
	sk._score_trick({"id": "kickflip", "name": "Kickflip", "points": 100, "kind": "flip"})
	assert_true(sk.combo.display_text().contains("Nollie Kickflip"), sk.combo.display_text())
	sk._set_nollie(false)
	assert_eq(seen, [true, false])
	sk.free()


func test_plain_ollie_is_not_a_nollie() -> void:
	var sk: Skater = _skater()
	sk._ollie(10.0)
	assert_eq(sk.anim, "ollie")
	assert_near(sk.velocity.y, 10.0, 0.001)
	assert_false(sk._nollie_air)
	sk.free()


func test_landing_ends_the_nollie_air_but_keeps_the_stance() -> void:
	var sk: Skater = _skater()
	sk._set_nollie(true)
	sk._ollie(8.0)
	sk._land(Vector3.UP)
	assert_false(sk._nollie_air)
	assert_true(sk.nollie, "the stance stays until toggled (THUG2)")
	sk.free()


func test_bail_clears_nollie_and_powerslide() -> void:
	var sk: Skater = _skater()
	var slides: Array = []
	sk.powerslide_changed.connect(func(on: bool) -> void: slides.append(on))
	sk._set_nollie(true)
	sk._start_powerslide()
	assert_eq(sk.anim, "powerslide")
	assert_true(sk.powersliding)
	sk._bail()
	assert_false(sk.nollie)
	assert_false(sk.powersliding)
	assert_eq(slides, [true, false])
	sk.free()


func test_powerslide_end_returns_to_the_ride_pose() -> void:
	var sk: Skater = _skater()
	sk._start_powerslide()
	sk._end_powerslide()
	assert_eq(sk.anim, "idle_ride")
	sk._end_powerslide()  # a second end is a no-op
	assert_false(sk.powersliding)
	sk.free()


func test_snapshot_keeps_nollie_and_powerslide() -> void:
	var sk: Skater = _skater()
	sk._set_nollie(true)
	sk._start_powerslide()
	sk._slide_time = 0.25
	var snap: Dictionary = sk.snapshot()
	var other: Skater = _skater()
	other.restore(str_to_var(var_to_str(snap)))
	assert_true(other.nollie)
	assert_true(other.powersliding)
	assert_near(other._slide_time, 0.25)
	sk.free()
	other.free()


func _drop_land(fall: float, n: Vector3) -> Skater:
	var sk: Skater = _skater()
	sk.facing = Vector3(0, 0, -1)
	sk.board_up = Vector3.UP
	sk.global_transform = Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), Vector3.ZERO)
	sk.state.event("ollie")
	sk._land(n, Vector3(0.0, -fall, -12.0))
	return sk


func test_upright_flat_landing_from_huge_height_slams() -> void:
	var sk: Skater = _drop_land(26.6, Vector3.UP)  # a 20 m drop
	assert_eq(sk.state.state, SkateState.State.BAIL, "26.6 m/s square into flat ground is a height slam")
	assert_true(sk.events.has("height_slam") or sk._carry_events.has("height_slam"))
	assert_eq(str(sk._bail_ctx.get("kind", "")), "big_drop")
	sk.free()


func test_upright_flat_landing_under_the_slam_speed_rides_away() -> void:
	var sk: Skater = _drop_land(20.0, Vector3.UP)  # about an 11 m drop
	assert_eq(sk.state.state, SkateState.State.ROLLING)
	sk.free()


func test_huge_drop_onto_a_steep_transition_is_ridable() -> void:
	# A 45 degree landing ramp sloping down the way of travel (a mega ramp landing): little of the fall goes into it.
	var n: Vector3 = Vector3(0.0, 1.0, -1.0).normalized()
	var sk: Skater = _drop_land(26.6, n)
	assert_false(sk.events.has("height_slam") or sk._carry_events.has("height_slam"), "a transition that turns the fall into roll stays ridable")
	sk.free()
