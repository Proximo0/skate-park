extends Node
## Scripted behaviour sims for the skater controller, headless (tools/run_sims.sh).
## Each scenario gets a fresh test park, drives park.skater with scripted input one physics tick at a time, and
## checks an outcome. Time limits are in sim seconds (physics ticks), never wall clock.
## Prints "SIM <name> PASS|FAIL <detail>" per scenario, then "SIMS passed=N failed=M". Exit 1 on any failure.

const PARK_SCENE: String = "res://game/park/test_park.tscn"
const DEFAULT_BUDGET: float = 15.0
const SPAWN: Vector3 = Vector3(0.0, 0.05, 10.0)
const RAIL_X: float = -6.0  ## the round rail runs along x = -6
const NONE: Vector2 = Vector2.ZERO
const UP: Vector2 = Vector2(0.0, -1.0)  ## stick up = N
const DOWN: Vector2 = Vector2(0.0, 1.0)  ## stick down = S

## [scenario name, time limit in sim seconds]. Each name has a coroutine _sc_<name>.
const SCENARIOS: Array = [
	["push_speed", 15.0],
	["ollie_height", 15.0],
	["ollie_flip_combo", 15.0],
	["midair_landing_bail", 15.0],
	["quarterpipe_vert", 25.0],
	["grind_rail", 25.0],
	["manual", 20.0],
	["revert", 25.0],
	["spin_180", 20.0],
	["respawn", 20.0],
]

var _park: Node
var _sk: Skater
var _verdict: int = 0  ## 0 running, 1 pass, -1 fail
var _detail: String = ""
var _budget: float = DEFAULT_BUDGET
var _sim_t: float = 0.0

# Facts gathered since the last _reset_facts(): by _observe() after every tick, and by the skater's signals.
var _states: Dictionary = {}  ## state name -> true
var _went_air: bool = false
var _bailed: bool = false
var _base_y: float = 0.0
var _max_y: float = 0.0
var _vert_ok: bool = false  ## vert_air while the origin was above 3.4 m
var _tricks: Array = []
var _combo_points: Array = []
var _combo_texts: Array = []
var _landings: Array = []


func _ready() -> void:
	_run_all()


func _run_all() -> void:
	var passed: int = 0
	var failed: int = 0
	for entry: Array in SCENARIOS:
		var sc_name: String = entry[0]
		_budget = float(entry[1])
		await _run_one(sc_name)
		if _verdict == 1:
			passed += 1
		else:
			failed += 1
		print("SIM %s %s %s" % [sc_name, "PASS" if _verdict == 1 else "FAIL", _detail])
	print("SIMS passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _run_one(sc_name: String) -> void:
	_verdict = 0
	_detail = ""
	_sim_t = 0.0
	_park = (load(PARK_SCENE) as PackedScene).instantiate()
	add_child(_park)
	_sk = _park.get("skater") as Skater
	await get_tree().physics_frame
	_sk.scripted_input = true
	_sk.trick_started.connect(_on_trick)
	_sk.combo_landed.connect(_on_combo_landed)
	_sk.bailed.connect(_on_bailed)
	_sk.landed.connect(_on_landed)
	_reset_facts()
	await call("_sc_" + sc_name)
	_finish(false, "scenario ended without a verdict")  ## no-op when a verdict is already in
	remove_child(_park)
	_park.free()
	_sk = null


func _finish(ok: bool, detail: String) -> void:
	if _verdict != 0:
		return
	_verdict = 1 if ok else -1
	_detail = detail


## One physics tick with this input. Returns false once the verdict is in or the time limit is spent,
## so every scenario loop can `if not await _tick(...): return`.
func _tick(stick: Vector2 = Vector2.ZERO, just_pressed: Array = [], held: Array = []) -> bool:
	if _verdict != 0:
		return false
	if _sim_t >= _budget:
		_finish(false, "time limit %.1fs hit while %s" % [_budget, _sk.state.state_name()])
		return false
	_sk.set_input(stick, just_pressed, held)
	await get_tree().physics_frame
	_sim_t += get_physics_process_delta_time()
	_observe()
	return true


func _observe() -> void:
	_states[_sk.state.state_name()] = true
	if _sk.state.state == SkateState.State.AIR:
		_went_air = true
	_max_y = maxf(_max_y, _sk.global_position.y)
	if _sk.vert_air and _sk.global_position.y > 3.4:
		_vert_ok = true


func _reset_facts() -> void:
	_states.clear()
	_went_air = false
	_bailed = false
	_base_y = _sk.global_position.y
	_max_y = _base_y
	_vert_ok = false
	_tricks.clear()
	_combo_points.clear()
	_combo_texts.clear()
	_landings.clear()


func _on_trick(t: Dictionary) -> void:
	_tricks.append(t)


func _on_combo_landed(points: int, text: String) -> void:
	_combo_points.append(points)
	_combo_texts.append(text)


func _on_bailed() -> void:
	_bailed = true


func _on_landed(result: String) -> void:
	_landings.append(result)


## Ticks neutral until the skater is rolling on the ground, then clears the facts. False if it never settles.
func _settle() -> bool:
	for i: int in 30:
		if not await _tick():
			return false
	if _sk.state.state != SkateState.State.ROLLING or not _sk.is_on_floor():
		_finish(false, "did not settle rolling on the ground (state %s)" % _sk.state.state_name())
		return false
	_reset_facts()
	return true


func _place(pos: Vector3, vel: Vector3, fwd: Vector3) -> void:
	_sk.global_position = pos
	_sk.velocity = vel
	_sk.facing = fwd


## Balance correction for the grind (stick x) and manual (stick y). Positive angle is corrected by a negative push.
## Stick x runs straight into Balance.update, so the grind uses -k * angle. Manual uses -stick.y, so it uses +k * angle.
func _grind_stick() -> Vector2:
	var c: float = clampf(-1.5 * _sk.balance.angle - 0.2 * _sk.balance.velocity, -1.0, 1.0)
	return Vector2(c, 0.0)


func _manual_stick() -> Vector2:
	var c: float = clampf(1.0 * _sk.balance.angle + 0.2 * _sk.balance.velocity, -1.0, 1.0)
	return Vector2(0.0, c)


func _trick_kinds() -> String:
	var parts: PackedStringArray = []
	for t: Variant in _tricks:
		parts.append("%s(%s)" % [str((t as Dictionary).get("name", "?")), str((t as Dictionary).get("kind", "?"))])
	return ", ".join(parts)


# --- scenarios ----------------------------------------------------------------------------------------

func _sc_push_speed() -> void:
	if not await _settle():
		return
	var top: float = 0.0
	var reached_at: float = -1.0
	for i: int in 180:
		if not await _tick(UP):
			return
		top = maxf(top, _sk.speed)
		if reached_at < 0.0 and _sk.speed >= 10.0:
			reached_at = _sim_t
	var rolling: bool = _states.size() == 1 and _states.has("ROLLING")
	_finish(reached_at >= 0.0 and rolling,
		"top %.1f m/s, reached 10 m/s at %.2fs, states %s" % [top, reached_at, str(_states.keys())])


func _sc_ollie_height() -> void:
	if not await _settle():
		return
	for i: int in 18:
		if not await _tick(NONE, [], ["ollie"]):
			return
	if not await _tick(NONE, [], []):  ## release: the ollie fires
		return
	var released_at: float = _sim_t
	var landed_after: float = -1.0
	for i: int in 150:
		if not await _tick():
			return
		if _went_air and _sk.state.state == SkateState.State.ROLLING:
			landed_after = _sim_t - released_at
			break
	var h: float = _max_y - _base_y
	var ok: bool = _went_air and h >= 1.0 and landed_after > 0.0 and landed_after <= 2.0 and not _bailed
	_finish(ok, "peak height %.2f m (need >=1.0), back to ROLLING %.2fs after release (need <=2.0), bailed %s"
		% [h, landed_after, str(_bailed)])


func _sc_ollie_flip_combo() -> void:
	if not await _settle():
		return
	for i: int in 18:
		if not await _tick(NONE, [], ["ollie"]):
			return
	if not await _tick(NONE, ["flip"], []):  ## release the ollie with a flip on the same tick
		return
	for i: int in 240:
		if not await _tick():
			return
		if not _combo_points.is_empty():
			break
	var flip_first: bool = not _tricks.is_empty() and str((_tricks[0] as Dictionary).get("kind", "")) == "flip"
	var pts: int = int(_combo_points[0]) if not _combo_points.is_empty() else 0
	_finish(flip_first and pts > 0,
		"tricks [%s], combo landed %d points" % [_trick_kinds(), pts])


func _sc_midair_landing_bail() -> void:
	if not await _settle():
		return
	if not await _tick(NONE, [], ["ollie"]):  ## one tick of crouch: a low ollie, about 0.7 s of air
		return
	if not await _tick():
		return
	## Press flip 0.45 s into the air. Its rotation (0.42 s) outlasts touchdown, so the landing must bail.
	var pressed: bool = false
	for i: int in 120:
		if _sk.state.state == SkateState.State.AIR and _sk.state.time_in_state >= 0.45:
			pressed = true
			break
		if not await _tick():
			return
	if not pressed:
		_finish(false, "never reached AIR for a late flip press (state %s)" % _sk.state.state_name())
		return
	if not await _tick(NONE, ["flip"], []):
		return
	var bail_at: float = -1.0
	var recovered_after: float = -1.0
	for i: int in 300:
		if not await _tick():
			return
		if _sk.state.state == SkateState.State.BAIL and bail_at < 0.0:
			bail_at = _sim_t
		elif bail_at >= 0.0 and _sk.state.state == SkateState.State.ROLLING:
			recovered_after = _sim_t - bail_at
			break
	var ok: bool = bail_at >= 0.0 and recovered_after >= 0.0 and recovered_after <= 2.5
	_finish(ok, "bailed %s, back to ROLLING %.2fs after the bail (need <=2.5), landings %s"
		% [str(bail_at >= 0.0), recovered_after, str(_landings)])


func _sc_quarterpipe_vert() -> void:
	if not await _settle():
		return
	## Ride straight at the far pipe at full speed, holding up, until the skater leaves the surface.
	var launched: bool = false
	for i: int in 900:
		if not await _tick(UP):
			return
		if _went_air:
			launched = true
			break
	if not launched:
		_finish(false, "never left the ramp; max y %.2f" % _max_y)
		return
	var speed_at_launch: float = _sk.speed
	## Let it fly and wait for it to come back down onto the ramp.
	var back: bool = false
	for i: int in 480:
		if not await _tick():
			return
		if _sk.state.state == SkateState.State.ROLLING:
			back = true
			break
	var ok: bool = _vert_ok and back and not _bailed
	_finish(ok, "launch at %.1f m/s, max y %.2f m (need >3.4 in vert), vert_seen %s, back ROLLING %s, bailed %s, landings %s"
		% [speed_at_launch, _max_y, str(_vert_ok), str(back), str(_bailed), str(_landings)])


func _sc_grind_rail() -> void:
	if not await _settle():
		return
	## Approach the rail from the side at x = -4.7, heading -X at 6 m/s.
	_place(Vector3(-4.7, 0.05, 0.0), Vector3(-6.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0))
	for i: int in 4:
		if not await _tick(NONE, [], ["ollie"]):
			return
	if not await _tick():  ## release: the ollie fires
		return
	## Press grind once airborne and within reach of the rail.
	var pressed: bool = false
	for i: int in 60:
		if _sk.state.state == SkateState.State.AIR and absf(_sk.global_position.x - RAIL_X) <= 0.9:
			pressed = true
			break
		if not await _tick():
			return
	if not pressed:
		_finish(false, "never airborne near the rail (state %s, x %.2f)" % [_sk.state.state_name(), _sk.global_position.x])
		return
	if not await _tick(NONE, ["grind"], []):
		return
	var grind_seen: bool = _sk.state.state == SkateState.State.GRIND
	var z0: float = _sk.global_position.z
	var travelled: float = 0.0
	var after: String = ""
	for i: int in 900:
		if not await _tick(_grind_stick()):
			return
		if _sk.state.state == SkateState.State.GRIND:
			grind_seen = true
			travelled = maxf(travelled, absf(_sk.global_position.z - z0))
		elif grind_seen:
			after = _sk.state.state_name()
			break
	var grind_tricks: bool = false
	for t: Variant in _tricks:
		if str((t as Dictionary).get("kind", "")) == "grind":
			grind_tricks = true
	var ok: bool = grind_seen and travelled >= 1.0 and (after == "AIR" or after == "ROLLING") and grind_tricks and not _bailed
	_finish(ok, "grind seen %s, travelled %.1f m along the rail, after the end %s, grind in combo %s, bailed %s"
		% [str(grind_seen), travelled, after, str(grind_tricks), str(_bailed)])


func _sc_manual() -> void:
	if not await _settle():
		return
	for i: int in 90:  ## push up to speed
		if not await _tick(UP):
			return
	for i: int in 2:  ## let go of the push: a manual is a flick, not a held push then a brake
		if not await _tick(NONE):
			return
	for i: int in 4:  ## stick up (N)
		if not await _tick(UP):
			return
	if not await _tick(DOWN):  ## stick down (S) on the same tick N-then-S completes: manual starts
		return
	var manual_seen: bool = _sk.state.state == SkateState.State.MANUAL
	var manual_secs: float = 0.0
	for i: int in 300:
		if _sk.state.state != SkateState.State.MANUAL or _sk.state.time_in_state >= 2.0:
			break
		if not await _tick(_manual_stick()):
			return
		manual_seen = manual_seen or _sk.state.state == SkateState.State.MANUAL
	if _sk.state.state == SkateState.State.MANUAL:
		manual_secs = _sk.state.time_in_state
	else:
		_finish(false, "manual ended early in %s (speed %.1f, bailed %s)" % [_sk.state.state_name(), _sk.speed, str(_bailed)])
		return
	if not await _tick(NONE, ["ollie"], []):  ## ollie out of the manual
		return
	var out_air: bool = _sk.state.state == SkateState.State.AIR
	var ok: bool = manual_seen and manual_secs >= 1.5 and out_air and not _bailed
	_finish(ok, "manual seen %s, held %.2fs (need >=1.5), ollie out to AIR %s, bailed %s, speed %.1f"
		% [str(manual_seen), manual_secs, str(out_air), str(_bailed), _sk.speed])


func _sc_revert() -> void:
	if not await _settle():
		return
	## Ride up the far pipe and ollie on the curve, so the skater lands again and arms the revert window.
	_place(Vector3(0.0, 0.05, -18.0), Vector3(0.0, 0.0, -9.0), Vector3(0.0, 0.0, -1.0))
	for i: int in 240:
		if _sk.state.state == SkateState.State.ROLLING and _sk.global_position.z < -26.0:
			break
		if not await _tick(UP):
			return
	for i: int in 3:
		if not await _tick(NONE, [], ["ollie"]):
			return
	if not await _tick():
		return
	var landed: bool = false
	for i: int in 300:
		if _went_air and _sk.state.state == SkateState.State.ROLLING:
			landed = true
			break
		if not await _tick():
			return
	if not landed:
		_finish(false, "never landed back to ROLLING (state %s, landings %s)" % [_sk.state.state_name(), str(_landings)])
		return
	## Press revert on the first tick after landing, well inside the 0.35 s window.
	if not await _tick(NONE, ["revert"], []):
		return
	for i: int in 240:
		if not await _tick():
			return
		if not _combo_texts.is_empty():
			break
	var revert_trick: bool = false
	for t: Variant in _tricks:
		if str((t as Dictionary).get("id", "")) == "revert":
			revert_trick = true
	var in_combo: bool = not _combo_texts.is_empty() and str(_combo_texts[0]).contains("Revert")
	_finish(revert_trick and in_combo and not _bailed,
		"revert trick %s, combo text %s, bailed %s" % [str(revert_trick), str(_combo_texts), str(_bailed)])


func _sc_spin_180() -> void:
	if not await _settle():
		return
	## Roll onto the kicker (x 6..8, z 2..4.4, rising toward -Z) and ollie off its lip with spin_left held.
	_place(Vector3(7.0, 0.05, 9.0), Vector3(0.0, 0.0, -9.0), Vector3(0.0, 0.0, -1.0))
	for i: int in 120:
		if _sk.state.state == SkateState.State.ROLLING and _sk.global_position.z < 3.6:
			break
		if not await _tick():
			return
	for i: int in 6:
		if not await _tick(NONE, [], ["ollie"]):
			return
	if not await _tick():  ## release: the ollie fires
		return
	if not _went_air:
		_finish(false, "no ollie off the kicker (state %s, z %.2f)" % [_sk.state.state_name(), _sk.global_position.z])
		return
	for i: int in 27:  ## 0.45 s of spin_left in the air, about 200 degrees
		if not await _tick(NONE, [], ["spin_left"]):
			return
	var landed: bool = false
	for i: int in 300:
		if not await _tick():
			return
		if _sk.state.state == SkateState.State.ROLLING:
			landed = true
			break
	for i: int in 60:
		if not landed or not _combo_texts.is_empty():
			break
		if not await _tick():
			return
	var spin_trick: bool = false
	for t: Variant in _tricks:
		var d: Dictionary = t
		if str(d.get("kind", "")) == "spin" and str(d.get("name", "")).begins_with("180"):
			spin_trick = true
	var ok: bool = landed and spin_trick and not _bailed
	_finish(ok, "landed %s, 180 spin trick %s, tricks [%s], landings %s, bailed %s"
		% [str(landed), str(spin_trick), _trick_kinds(), str(_landings), str(_bailed)])


func _sc_respawn() -> void:
	if not await _settle():
		return
	for i: int in 120:  ## ride away
		if not await _tick(UP):
			return
	var away: float = _sk.global_position.distance_to(SPAWN)
	_sk.respawn()
	var at_spawn: bool = _sk.global_position.distance_to(SPAWN) < 0.01
	var still: bool = _sk.velocity.length() < 0.001
	var rolling: bool = _sk.state.state == SkateState.State.ROLLING
	## Then the controller carries on from spawn.
	for i: int in 10:
		if not await _tick():
			return
	var stays: bool = _sk.state.state == SkateState.State.ROLLING
	## Respawn from the air too: the state machine is rebuilt there.
	if not await _tick(NONE, [], ["ollie"]):
		return
	if not await _tick():
		return
	var was_air: bool = _sk.state.state == SkateState.State.AIR
	_sk.respawn()
	var air_reset: bool = _sk.state.state == SkateState.State.ROLLING and _sk.global_position.distance_to(SPAWN) < 0.01
	var ok: bool = away > 5.0 and at_spawn and still and rolling and stays and was_air and air_reset
	_finish(ok, "rode %.1f m away, at spawn %s, velocity zero %s, ROLLING %s, still ROLLING %s, respawn from AIR (was air %s) reset %s"
		% [away, str(at_spawn), str(still), str(rolling), str(stays), str(was_air), str(air_reset)])
