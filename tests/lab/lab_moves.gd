extends "res://tests/sim/sim_base.gd"
## The physics lab's scripted manoeuvres. Each `m_*` function drives the skater through one scenario in a SimBase-style
## sandbox and returns {metric_name: value}. Everything is measured in sim time (physics ticks), never wall clock.
## Physics numbers that a manoeuvre needs (gravity for an ideal-value diag) come from the skater's `tune` var when
## it has one, so the lab works both before and after the skater reads everything from PhysicsTuning.
## Keys starting with "x_" are diagnostics: printed as LABINFO lines, not scored.

const QP := preload("res://game/park/pieces/quarterpipe.gd")
const HP := preload("res://game/park/pieces/halfpipe.gd")
const KICKER := preload("res://game/park/pieces/kicker.gd")
const LOOP := preload("res://game/park/pieces/loop.gd")
const STREET := preload("res://game/park/pieces/street_bits.gd")

const MINI_H: float = 1.5  ## the mini ramp used for the quarter-pipe air metrics: height = radius = 1.5 m
const LOOP_RADIUS: float = 4.0  ## the main park's loop
const LOOP_RUN_IN: float = 6.0
const LOOP_RUN_OUT: float = 6.0

var last_turn_lean_in: float = -1.0  ## set by _turn: seconds from full stick to 90% of the steady turn rate


## The manoeuvre table: [method name, [metric names it produces]]. `--only=<prefix>` keeps a manoeuvre when any of its
## metrics starts with the prefix.
static func table() -> Array:
	return [
		["m_ollie_tap", ["ollie_height_tap", "ollie_airtime_tap"]],
		["m_ollie_full", ["ollie_height_full", "ollie_airtime_full", "ollie_fall_rise_ratio"]],
		["m_sketchy", ["sketchy_stagger_s", "sketchy_steer_ratio", "sketchy_speed_keep"]],
		["m_push", ["push_time_to_top", "push_top_speed", "push_accel_0_5"]],
		["m_coast", ["coast_distance_8ms"]],
		["m_brake", ["brake_distance_8ms"]],
		["m_turn_4", ["turn_radius_4ms"]],
		["m_turn_8", ["turn_radius_8ms", "carve_lean_in_s"]],
		["m_turn_12", ["turn_radius_12ms"]],
		["m_quarter_8", ["quarter_air_8ms"]],
		["m_quarter_12", ["quarter_air_12ms"]],
		["m_kicker_8", ["kicker_distance_8ms"]],
		["m_kicker_12", ["kicker_distance_12ms"]],
		["m_landing", ["landing_speed_retention"]],
		["m_halfpipe", ["halfpipe_pump_gain_per_cycle"]],
		["m_loop", ["loop_min_entry_speed"]],
		["m_grind", ["grind_speed_loss_per_m", "grind_entry_speed_retention"]],
		["m_bank", ["roll_down_speed_bank3m"]],
		["m_ollie_latency", ["ollie_pop_latency_ms"]],
		["m_ollie_buffer", ["ollie_land_buffer_ms"]],
		["m_flip", ["flip_rotations_per_s", "flip_catch_margin_tap_s"]],
		["m_flip_buffer", ["flip_prepop_buffer_ms"]],
		["m_spin", ["spin_deg_full_ollie", "spin_under_rotation_grace_deg"]],
		["m_land_heading", ["land_clean_heading_max_deg", "land_sketchy_heading_max_deg", "land_clean_tilt_max_deg"]],
		["m_revert", ["revert_pre_land_buffer_ms", "revert_post_land_window_ms"]],
		["m_manual_window", ["manual_entry_window_ms"]],
		["m_manual_balance", ["manual_fall_nostick_s", "manual_hold_human_s"]],
		["m_grind_balance", ["grind_fall_nostick_s", "grind_hold_human_s"]],
		["m_grind_reach", ["grind_snap_reach_m", "grind_press_buffer_ms"]],
		["m_wallride", ["wallride_duration_s"]],
		["m_wall_slam", ["wall_slam_speed_ms"]],
		["m_vert", ["vert_air_14ms", "vert_air_18ms"]],
		["m_wall_carve", ["wall_carve_speed_retention"]],
		["m_slope", ["slope_accel_15deg"]],
		["m_bowl_lap", ["dome_lap_speed_retention"]],
		["m_powerslide", ["powerslide_decel_ms2"]],
		["m_nollie", ["nollie_height_ratio"]],
		["m_manual_drift", ["manual_drift_1s", "manual_recover_half_s"]],
		["m_revert_fakie", ["revert_speed_keep", "fakie_landing_retention"]],
		["m_big_air", ["big_air_clean_drop_m", "big_air_landing_keep"]],
		["m_boneless", ["boneless_height_ratio", "boneless_plant_ms", "no_comply_height_ratio"]],
		["m_wallplant", ["wallplant_push_out_ms", "wallplant_into_left_ms"]],
		["m_caveman", ["caveman_roll_speed_ms"]],
		["m_acid_drop", ["acid_drop_energy_keep"]],
		["m_grind_links", ["grind_switch_speed_keep", "rail_transfer_speed_keep", "grind_pop_charge_ratio"]],
		["m_lip_out", ["lip_pop_flip_margin_s"]],
		["m_snap_drop", ["snap_drop_energy_keep", "snap_drop_peak_accel_g"]],
	]


## A physics number from the skater's `tune` var when it has one, else `fallback`.
func tv(field: String, fallback: float) -> float:
	var t: Variant = sk.get("tune") if sk != null else null
	if t != null:
		var v: Variant = t.get(field)
		if v != null:
			return float(v)
	return fallback


func _flat_start(v0: float, dir: Vector3 = Vector3(0, 0, -1)) -> void:
	await sandbox([])
	place(Vector3(0, 0, 60), dir, v0)
	await host.get_tree().physics_frame


## Rolls on the flat with a fixed stick, wrapping the skater back across the ground so long runs never leave it.
## Returns {speeds: [m/s per tick], odo: metres travelled, ticks}.
func _flat_run(v0: float, stick: Vector2, max_s: float, stop_below: float = -1.0) -> Dictionary:
	await _flat_start(v0)
	var speeds: Array = []
	var odo: float = 0.0
	var prev: Vector3 = sk.global_position
	for i: int in int(max_s / DT):
		await tick(stick)
		var p: Vector3 = sk.global_position
		odo += Vector2(p.x - prev.x, p.z - prev.z).length()
		prev = p
		if p.z < -60.0:
			sk.global_position.z += 120.0
			prev = sk.global_position
		speeds.append(sk.velocity.length())
		if stop_below >= 0.0 and float(speeds[speeds.size() - 1]) <= stop_below:
			break
	await clear()
	return {"speeds": speeds, "odo": odo, "ticks": speeds.size()}


# --- flat ground --------------------------------------------------------------------------------------

## Ollie from 4 m/s rolling. hold_ticks of "ollie" held then released. Returns {height, air}.
func _ollie(hold_ticks: int, button: String = "ollie") -> Dictionary:
	await _flat_start(4.0)
	for i: int in 20:
		await tick()
	if button == "nollie":
		# THUG2 nollie: the nollie button toggles nollie stance, then the ollie button pops off the nose
		await tick(NONE, ["nollie"], ["nollie"])
		await tick()
		button = "ollie"
	var y0: float = sk.global_position.y
	for i: int in hold_ticks:
		await tick(NONE, [button] if (i == 0 and button != "ollie") else [], [button])
	var peak: float = y0
	var air_ticks: int = 0
	var apex_ticks: int = 0
	var went_air: bool = false
	for i: int in 180:
		await tick()
		if sname() == "AIR":
			went_air = true
			air_ticks += 1
		elif went_air:
			break
		if sk.global_position.y > peak:
			peak = sk.global_position.y
			apex_ticks = air_ticks
	await clear()
	return {"height": peak - y0, "air": float(air_ticks) * DT, "rise": float(apex_ticks) * DT,
		"fall": float(air_ticks - apex_ticks) * DT}


func m_ollie_tap() -> Dictionary:
	var r: Dictionary = await _ollie(1)
	return {"ollie_height_tap": r["height"], "ollie_airtime_tap": r["air"]}


func m_ollie_full() -> Dictionary:
	var r: Dictionary = await _ollie(40)  ## well past crouch_full (0.4 s = 24 ticks)
	return {"ollie_height_full": r["height"], "ollie_airtime_full": r["air"],
		"ollie_fall_rise_ratio": float(r["fall"]) / maxf(float(r["rise"]), DT), "x_ollie_full_rise_s": r["rise"],
		"x_ollie_full_fall_s": r["fall"]}


func m_push() -> Dictionary:
	var r: Dictionary = await _flat_run(0.0, FWD, 20.0)
	var sp: Array = r["speeds"]
	var n: int = sp.size()
	var tail: int = int(2.0 / DT)  ## mean over the last 2 s = several whole push cycles
	var top: float = 0.0
	for i: int in range(n - tail, n):
		top += float(sp[i])
	top /= float(tail)
	var t95: float = -1.0
	for i: int in n:
		if float(sp[i]) >= 0.95 * top:
			t95 = float(i + 1) * DT
			break
	var t5: float = -1.0
	for i: int in n:
		if float(sp[i]) >= 5.0:
			t5 = float(i + 1) * DT
			break
	return {"push_time_to_top": t95, "push_top_speed": top, "push_accel_0_5": 5.0 / t5 if t5 > 0.0 else 0.0}


func m_coast() -> Dictionary:
	var r: Dictionary = await _flat_run(8.0, NONE, 40.0, 0.05)
	return {"coast_distance_8ms": r["odo"], "x_coast_time_s": float(r["ticks"]) * DT}


func m_brake() -> Dictionary:
	var r: Dictionary = await _flat_run(8.0, Vector2(0.0, 1.0), 12.0, 0.05)
	return {"brake_distance_8ms": r["odo"], "x_brake_time_s": float(r["ticks"]) * DT}


## Full-stick turn from v0. Radius = mean speed / mean yaw rate, between 0.2 s and 1.2 s (past the start-up, before
## friction has bled much speed).
func _turn(v0: float) -> float:
	await _flat_start(v0)
	for i: int in 3:
		await tick()  # rolling straight first, so the press is a lean-in from neutral as in play
	var prev_dir: Vector2 = Vector2(sk.velocity.x, sk.velocity.z).normalized()
	var ang: float = 0.0
	var ang_a: float = 0.0
	var ang_b: float = 0.0
	var spd_sum: float = 0.0
	var spd_n: int = 0
	var a_tick: int = int(0.2 / DT)
	var b_tick: int = int(1.2 / DT)
	var rates: Array = []
	for i: int in b_tick:
		await tick(Vector2(1.0, 0.0))
		var d: Vector2 = Vector2(sk.velocity.x, sk.velocity.z)
		var step: float = 0.0
		if d.length() > 0.1:
			step = prev_dir.angle_to(d.normalized())
			ang += step
			prev_dir = d.normalized()
		rates.append(absf(step) / DT)
		if i + 1 == a_tick:
			ang_a = ang
		if i >= a_tick:
			spd_sum += d.length()
			spd_n += 1
		ang_b = ang
	await clear()
	var rate: float = absf(ang_b - ang_a) / (float(b_tick - a_tick) * DT)
	# lean-in: the first tick the turn reaches 90% of its steady rate (the 0.5..1 s average), in seconds from the press
	var steady: float = 0.0
	for k: int in range(int(0.5 / DT), int(1.0 / DT)):
		steady += float(rates[k])
	steady /= float(int(1.0 / DT) - int(0.5 / DT))
	last_turn_lean_in = -1.0
	for k: int in rates.size():
		if float(rates[k]) >= 0.9 * steady:
			last_turn_lean_in = float(k + 1) * DT
			break
	if rate < 0.01:
		return 999.0
	return (spd_sum / float(maxi(spd_n, 1))) / rate


func m_turn_4() -> Dictionary:
	return {"turn_radius_4ms": await _turn(4.0)}


func m_turn_8() -> Dictionary:
	var r: float = await _turn(8.0)
	return {"turn_radius_8ms": r, "carve_lean_in_s": last_turn_lean_in}


func m_turn_12() -> Dictionary:
	return {"turn_radius_12ms": await _turn(12.0)}


# --- ramps and air ------------------------------------------------------------------------------------

## Rides a 1.5 m mini quarter pipe (height = radius) at v0 with no input. Returns how far the board's peak is above the
## coping (negative when it never reached the lip), plus the end state.
func _quarter(v0: float) -> Dictionary:
	await sandbox([QP.build(10.0, MINI_H, MINI_H, 1.5)])
	place(Vector3(5.0, 0.0, 4.8), Vector3(0, 0, -1), v0)  ## 1.8 m of run-in: v0 is (nearly) the speed at the ramp
	await host.get_tree().physics_frame
	var peak: float = 0.0
	var went_air: bool = false
	for i: int in 300:
		await tick()
		peak = maxf(peak, sk.global_position.y)
		if sname() == "AIR":
			went_air = true
	var res: Dictionary = {"above": peak - MINI_H, "air": went_air, "bails": bails}
	await clear()
	return res


func m_quarter_8() -> Dictionary:
	var r: Dictionary = await _quarter(8.0)
	return {"quarter_air_8ms": r["above"], "x_quarter_8ms_bails": r["bails"]}


func m_quarter_12() -> Dictionary:
	var r: Dictionary = await _quarter(12.0)
	return {"quarter_air_12ms": r["above"], "x_quarter_12ms_bails": r["bails"]}


## Kicker (2.0 x 2.4 x 0.9, lip at z = 0): horizontal distance from the lip to the first touchdown.
func _kicker(v0: float) -> Dictionary:
	await sandbox([KICKER.build(2.0, 2.4, 0.9)])
	place(Vector3(1.0, 0.0, 4.2), Vector3(0, 0, -1), v0)  ## 1.8 m of run-in: v0 is (nearly) the speed at the kicker
	await host.get_tree().physics_frame
	var went_air: bool = false
	var dist: float = -1.0
	var air_t: float = 0.0
	for i: int in 240:
		await tick()
		if sname() == "AIR":
			went_air = true
			air_t += DT
		elif went_air:
			dist = -sk.global_position.z  ## the lip is at z = 0; riding -Z
			break
	var res: Dictionary = {"dist": dist, "air_t": air_t}
	await clear()
	return res


func m_kicker_8() -> Dictionary:
	var r: Dictionary = await _kicker(8.0)
	return {"kicker_distance_8ms": r["dist"], "x_kicker_8ms_airtime_s": r["air_t"]}


func m_kicker_12() -> Dictionary:
	var r: Dictionary = await _kicker(12.0)
	return {"kicker_distance_12ms": r["dist"], "x_kicker_12ms_airtime_s": r["air_t"]}


## A clean flat landing after a tap ollie at 8 m/s: horizontal speed just after touchdown over just before it.
func m_landing() -> Dictionary:
	await _flat_start(8.0)
	for i: int in 10:
		await tick()
	await tick(NONE, [], ["ollie"])
	var before: float = 0.0
	var ratio: float = -1.0
	var went_air: bool = false
	for i: int in 120:
		var v: Vector3 = sk.velocity
		before = Vector2(v.x, v.z).length()
		await tick()
		if sname() == "AIR":
			went_air = true
		elif went_air:
			var a: Vector3 = sk.velocity
			ratio = Vector2(a.x, a.z).length() / maxf(before, 0.001)
			break
	var verdict: String = landings[landings.size() - 1] if not landings.is_empty() else "none"
	await clear()
	return {"landing_speed_retention": ratio, "x_landing_result": verdict}


## Halfpipe (10 wide, 6 flat, r 3.5, coping 4.0): enter the flat at 9 m/s and hold forward. Each turnaround's peak is
## measured above the coping; gain per cycle = (5th peak - 1st peak) / 4, or over however many peaks there were.
func m_halfpipe() -> Dictionary:
	await sandbox([HP.build(10.0, 6.0, 3.5, 4.0, 2.0)])
	place(Vector3(5.0, 0.0, 8.5), Vector3(0, 0, -1), 9.0)
	await host.get_tree().physics_frame
	var coping: float = 4.0
	var peaks: Array = []
	var rising: bool = false
	var seg_max: float = 0.0
	for i: int in int(40.0 / DT):
		await tick(FWD)
		var vy: float = sk.velocity.y
		var y: float = sk.global_position.y
		if vy > 0.5:
			rising = true
			seg_max = maxf(seg_max, y)
		elif rising and vy <= 0.0:
			rising = false
			if seg_max > 1.0:
				peaks.append(seg_max - coping)
			seg_max = 0.0
		if peaks.size() >= 5:
			break
	var gain: float = 0.0
	if peaks.size() >= 2:
		gain = (float(peaks[peaks.size() - 1]) - float(peaks[0])) / float(peaks.size() - 1)
	var strs: PackedStringArray = []
	for p: Variant in peaks:
		strs.append("%.2f" % float(p))
	var res: Dictionary = {"halfpipe_pump_gain_per_cycle": gain, "x_halfpipe_peaks_above_coping_m": "[" + ",".join(strs) + "]",
		"x_halfpipe_bails": bails}
	await clear()
	return res


## Did a skater entering the loop at v0 (no input) get round it and out the run-out? Returns {ok, entry}: entry is the
## speed as it crossed the loop's tangent point (z = -run_in) on the flat.
func _loop_try(v0: float) -> Dictionary:
	await sandbox([LOOP.build(LOOP_RADIUS, 3.0, LOOP_RUN_IN, LOOP_RUN_OUT, 3.5)])
	place(Vector3(1.5, 0.02, -0.4), Vector3(0, 0, -1), v0)  ## on the run-in ribbon (a ground approach would hit its 2 cm lip)
	await host.get_tree().physics_frame
	var top_y: float = 0.0
	var done: bool = false
	var entry: float = -1.0
	for i: int in 480:
		await tick()
		var p: Vector3 = sk.global_position
		top_y = maxf(top_y, p.y)
		if entry < 0.0 and p.z <= -LOOP_RUN_IN:
			entry = sk.velocity.length()
		if bails > 0 or p.z > 4.0:
			break
		if top_y > 2.0 * LOOP_RADIUS - 1.0 and p.z < -(LOOP_RUN_IN + 2.0) and p.y < 0.4 and sname() == "ROLLING":
			done = true
			break
	await clear()
	return {"ok": done, "entry": entry}


## Bisects the lowest speed at the loop's base that completes it (6..22 m/s; 99 when even the speed cap fails).
func m_loop() -> Dictionary:
	var hi: float = 22.0
	var best: Dictionary = await _loop_try(hi)
	if not best["ok"]:
		return {"loop_min_entry_speed": 99.0}
	var lo: float = 6.0
	for i: int in 7:
		var mid: float = (lo + hi) * 0.5
		var r: Dictionary = await _loop_try(mid)
		if r["ok"]:
			hi = mid
			best = r
		else:
			lo = mid
	var g: float = tv("gravity", 18.0)
	return {"loop_min_entry_speed": best["entry"], "x_loop_ideal_sqrt5gr_ms": sqrt(5.0 * g * LOOP_RADIUS)}


## 50-50 along a 30 m flat rail entered at 8 m/s with no input: speed lost per metre of grind (until it ends or bails).
func m_grind() -> Dictionary:
	await sandbox([STREET.flat_rail(30.0, 0.45)])
	var rails: Array = host.get_tree().get_nodes_in_group("grind_rail")
	var cx: float = (rails[0] as GrindRail).global_points()[0].x
	place(Vector3(cx, 0.0, -0.4), Vector3(0, 0, 1), 8.0)
	await host.get_tree().physics_frame
	var v_pre: float = sk.velocity.length()
	await tick(NONE, ["grind"], [])
	var z0: float = 0.0
	var v0: float = 0.0
	var z1: float = 0.0
	var v1: float = 0.0
	var started: bool = false
	for i: int in 400:
		if i > 0:
			await tick()
		if sname() == "GRIND":
			if not started:
				started = true
				z0 = sk.global_position.z
				v0 = sk.velocity.length()
			z1 = sk.global_position.z
			v1 = sk.velocity.length()
		elif started:
			break
	var dist: float = absf(z1 - z0)
	var loss: float = (v0 - v1) / dist if dist >= 2.0 else -1.0
	var res: Dictionary = {"grind_speed_loss_per_m": loss, "grind_entry_speed_retention": v0 / maxf(v_pre, 0.01) if started else -1.0,
		"x_grind_length_m": dist, "x_grind_bails": bails}
	await clear()
	return res


## 3 m high bank (5 m run, about 31 degrees) with a flat deck on top; rolls off the deck at 1 m/s, no input. Speed when
## the board reaches the toe.
func m_bank() -> Dictionary:
	var h: float = 3.0
	var run: float = 5.0
	var prof := PackedVector2Array([Vector2(0.0, -3.0), Vector2(0.0, run), Vector2(h, 0.0), Vector2(h, -3.0)])
	var wedge := Node3D.new()
	wedge.add_child(PieceKit.body(PieceKit.extrude_profile(prof, 10.0), PieceKit.RAMP_WOOD, "Bank3m"))
	wedge.position = Vector3(-5.0, 0.0, 0.0)
	await sandbox([wedge])
	place(Vector3(0.0, h + 0.02, -0.5), Vector3(0, 0, 1), 1.0)
	await host.get_tree().physics_frame
	var at_toe: float = -1.0
	var went_air: bool = false
	for i: int in int(10.0 / DT):
		await tick()
		if sname() == "AIR":
			went_air = true
		if sk.global_position.z >= run and sk.global_position.y < 0.3:
			at_toe = sk.velocity.length()
			break
	var g: float = tv("gravity", 18.0)
	var res: Dictionary = {"roll_down_speed_bank3m": at_toe, "x_bank_ideal_sqrt2gh_ms": sqrt(2.0 * g * h), "x_bank_went_air": went_air}
	await clear()
	return res


# --- feel targets (docs/feel_targets.md) --------------------------------------------------------------
# Timing windows are measured by scanning the press tick against a probe run's event tick; heights, times and
# speeds the same way as above. The balance metrics use a "human" stick model: it pushes back against the lean it
# saw HUMAN_REACT_TICKS ago (the lean and how fast it tips), so they read how hard the balance is for a steady
# player, not a perfect bot.

const HUMAN_REACT_TICKS: int = 12  ## 0.2 s: a typical visual reaction time
const HUMAN_GAIN: float = 1.0  ## stick per unit of lean (the meter runs -1..1)
const HUMAN_RATE_GAIN: float = 0.3  ## stick per unit of lean speed (1/s): a player reads which way it is tipping
const BALANCE_CAP_S: float = 30.0


## Tap ollie at `v0` on the flat. Before each tick `hook.call(ttl, since)` gives that tick's [stick, just_pressed, held]:
## ttl = predicted ticks until touchdown (1 = this tick lands; 999 on the ground before it), since = ticks since the
## touchdown tick (-1 before it). Windows are judged against the run's own flight, so a one-tick shift in when the
## sandbox starts can't skew them. Returns {result, state_after (2 ticks after touchdown), ids (tricks), bails, ttl_err}.
func _ollie_run(v0: float, hook: Callable, after_ticks: int = 30) -> Dictionary:
	await _flat_start(v0)
	for i: int in 10:
		await tick()
	var ids: Array = []
	sk.trick_started.connect(func(t: Dictionary) -> void: ids.append(str(t.get("id", ""))))
	await tick(NONE, ["ollie"], ["ollie"])
	var landed_at: int = -1
	var result: String = ""
	var state_after: String = ""
	var preds: Array = []
	var g: float = tv("gravity", 18.0)
	for i: int in 200:
		var ttl: int = 999
		if landed_at < 0 and sname() == "AIR":
			ttl = _ttl_ticks(maxf(sk.global_position.y, 0.0), sk.velocity.y, g)
			preds.append([i, ttl])
		var inp: Array = hook.call(ttl, i - landed_at if landed_at >= 0 else -1)
		await tick(inp[0], inp[1], inp[2])
		if landed_at < 0:
			for e: String in sk.events:
				if e.begins_with("land:"):
					landed_at = i
					result = e.substr(5)
		if landed_at >= 0 and i == landed_at + 2:
			state_after = sname()
		if landed_at >= 0 and i >= landed_at + after_ticks:
			break
	var err: float = 0.0
	for pr: Array in preds:
		err = maxf(err, absf(float(int(pr[0]) + int(pr[1]) - 1 - landed_at)))
	var res: Dictionary = {"result": result, "state_after": state_after, "ids": ids, "bails": bails, "ttl_err": err,
		"air_ticks": landed_at + 1}
	await clear()
	return res


## Ticks until a street air at height y (m, over flat ground at 0) rising at vy touches down: stepped like the skater
## (gravity first, then the move), with the heavier fall past the apex (tune fall_gravity up to fall_boost_max m/s).
func _ttl_ticks(y: float, vy: float, g: float) -> int:
	var fall_k: float = tv("fall_gravity", 1.0)
	var boost_max: float = tv("fall_boost_max", 0.0)
	var n: int = 0
	while n < 600:
		n += 1
		var k: float = fall_k if vy < 0.0 and -vy < boost_max else 1.0
		vy -= g * k * DT
		y += vy * DT
		if y <= 0.0:
			break
	return maxi(n, 1)


func _no_input(_ttl: int, _since: int) -> Array:
	return [NONE, [], []]


func m_ollie_latency() -> Dictionary:
	await _flat_start(4.0)
	for i: int in 10:
		await tick()
	await tick(NONE, ["ollie"], ["ollie"])
	var n: int = 0
	for i: int in 20:
		await tick()
		n += 1
		if sname() == "AIR":
			break
	await clear()
	return {"ollie_pop_latency_ms": float(n) * DT * 1000.0}


## Ollie tapped (pressed and released) `k` ticks before touchdown: does the skater pop again on landing? The longest
## such lead that still pops (0: an ollie tapped in the air is dropped).
func m_ollie_buffer() -> Dictionary:
	var best: int = 0
	for k: int in range(1, 16):
		var hook: Callable = func(ttl: int, _since: int) -> Array:
			return [NONE, ["ollie"], ["ollie"]] if ttl == k + 1 else [NONE, [], []]
		var r: Dictionary = await _ollie_run(6.0, hook, 12)
		if r["state_after"] != "AIR":
			break
		best = k
	return {"ollie_land_buffer_ms": float(best) * DT * 1000.0}


## Full ollie with a kickflip pressed on the pop: how long the flip takes (ticks the flip anim plays), and how much air
## a tap ollie leaves after a flip (margin before the late-catch / bail rule bites).
func m_flip() -> Dictionary:
	await _flat_start(6.0)
	for i: int in 10:
		await tick()
	await tick(NONE, ["ollie"], ["ollie"])
	await tick(Vector2(-1, 0), ["flip"], ["flip"])  ## W + flip: the kickflip (any flip: same flip_time)
	var flip_ticks: int = 0
	var air: int = 0
	for i: int in 120:
		await tick()
		if sname() == "AIR":
			air += 1
			if sk._air_trick_until > sk._t:
				flip_ticks += 1
		elif air > 0:
			break
	var verdict: String = landings[landings.size() - 1] if not landings.is_empty() else "none"
	await clear()
	var dur: float = float(flip_ticks + 1) * DT
	var probe: Dictionary = await _ollie_run(6.0, _no_input)
	var tap_air: float = float(int(probe["air_ticks"])) * DT
	return {"flip_rotations_per_s": 1.0 / dur, "flip_catch_margin_tap_s": tap_air - dur, "x_flip_duration_s": dur,
		"x_flip_tap_landing": verdict}


## Flip pressed `k` ticks before the ollie pops (while crouched): the longest lead that still does the flip.
func m_flip_buffer() -> Dictionary:
	var best: int = 0
	for k: int in range(1, 30):
		await _flat_start(6.0)
		for i: int in 5:
			await tick()
		var ids: Array = []
		sk.trick_started.connect(func(t: Dictionary) -> void: ids.append(str(t.get("kind", ""))))
		for i: int in k:
			await tick(Vector2(-1, 0) if i == 0 else NONE, ["flip", "ollie"] if i == 0 else [], ["ollie"])
		for i: int in 30:
			await tick()
		var flipped: bool = ids.has("flip")
		await clear()
		if flipped:
			best = k
		else:
			break
	return {"flip_prepop_buffer_ms": float(best) * DT * 1000.0}


## Full ollie at 8 m/s holding the spin button the whole air: how far it turns on the flat.
func m_spin() -> Dictionary:
	await _flat_start(8.0)
	for i: int in 10:
		await tick()
	for i: int in 30:
		await tick(NONE, ["ollie"] if i == 0 else [], ["ollie"])
	var deg: float = 0.0
	for i: int in 120:
		await tick(NONE, [], ["spin_left"])
		if sname() == "AIR":
			deg = absf(sk.spin.degrees())
		elif deg > 0.0:
			break
	await clear()
	var st: SpinTracker = SpinTracker.new()
	var grace: float = 180.0
	for d: int in range(180, 90, -1):
		st.start(0.0)
		for j: int in 10:
			st.update(deg_to_rad(float(d)) * float(j + 1) / 10.0)
		if st.spins180() < 1:
			break
		grace = 180.0 - float(d)
	return {"spin_deg_full_ollie": deg, "spin_under_rotation_grace_deg": grace}


## Lands a full ollie at 8 m/s turned `deg` off the travel direction (an analog stick spin through the first part of the
## air). Returns {result, deg (the actual turn)}.
func _land_turned(deg: float) -> Dictionary:
	var rate: float = tv("spin_rate", 7.5)
	var n: int = maxi(1, ceili(deg_to_rad(deg) / (rate * DT)))
	var f: float = deg_to_rad(deg) / (float(n) * rate * DT)
	while f < 0.3 and n > 1:
		n -= 1
		f = deg_to_rad(deg) / (float(n) * rate * DT)
	var sx: float = -(0.35 + 0.5 * clampf(f, 0.3, 1.0))  ## left spin
	await _flat_start(8.0)
	for i: int in 10:
		await tick()
	for i: int in 30:
		await tick(NONE, ["ollie"] if i == 0 else [], ["ollie"])
	var turned: float = 0.0
	var res: String = ""
	var k: int = 0
	for i: int in 120:
		var spinning: bool = sname() == "AIR" and k < n and deg > 0.0
		await tick(Vector2(sx, 0.0) if spinning else NONE)
		if spinning:
			k += 1
		if sname() == "AIR":
			turned = absf(sk.spin.degrees())
		for e: String in sk.events:
			if e.begins_with("land:"):
				res = e.substr(5)
		if res != "":
			break
	await clear()
	return {"result": res, "deg": turned}


## The biggest heading error (board vs travel) that still lands clean, and that still rides away (sketchy).
func m_land_heading() -> Dictionary:
	var out: Dictionary = {}
	for want: String in ["clean", "sketchy"]:
		var lo: float = 0.0
		var hi: float = 100.0
		var lo_deg: float = 0.0
		for i: int in 8:
			var mid: float = (lo + hi) * 0.5
			var r: Dictionary = await _land_turned(mid)
			var good: bool = r["result"] == "clean" or (want == "sketchy" and r["result"] == "sketchy")
			if good:
				lo = mid
				lo_deg = float(r["deg"])
			else:
				hi = mid
		out["land_%s_heading_max_deg" % want] = lo_deg
	var tilt: float = 0.0
	for d: int in range(0, 90):
		var th: float = deg_to_rad(float(d))
		var up := Vector3(sin(th), cos(th), 0.0)
		if Landing.judge(Vector3.FORWARD, up, Vector3.FORWARD * 6.0, Vector3.UP)["result"] != "clean":
			break
		tilt = float(d)
	out["land_clean_tilt_max_deg"] = tilt
	return out


## Revert: pressed `off` ticks from the touchdown tick (negative = still in the air). Earliest and latest that count.
func m_revert() -> Dictionary:
	var probe: Dictionary = await _ollie_run(6.0, _no_input)
	var pre: int = 0
	for k: int in range(1, 30):
		if not await _reverts(-k):
			break
		pre = k
	var post: int = 0
	for k: int in range(1, 60):
		if not await _reverts(k):
			break
		post = k
	return {"revert_pre_land_buffer_ms": float(pre) * DT * 1000.0, "revert_post_land_window_ms": float(post) * DT * 1000.0,
		"x_ttl_prediction_err_ticks": probe["ttl_err"]}


func _reverts(off: int) -> bool:
	var hook: Callable = func(ttl: int, since: int) -> Array:
		var hit: bool = (off < 0 and ttl == 1 - off) or (off >= 0 and since == off)
		return [NONE, ["revert"], ["revert"]] if hit else [NONE, [], []]
	var r: Dictionary = await _ollie_run(6.0, hook, maxi(off, 0) + 4)
	return (r["ids"] as Array).has("revert") and int(r["bails"]) == 0


## Manual flicked in the air (N then S, two ticks each) ending `k` ticks before touchdown: the longest lead that still
## lands in a manual.
func m_manual_window() -> Dictionary:
	var best: int = 0
	for k: int in range(1, 40):
		var hook: Callable = func(ttl: int, _since: int) -> Array:
			var e: int = k + 1  ## the flick's last tick, as a ttl
			if ttl == e + 3 or ttl == e + 2:
				return [Vector2(0, -1), [], []]
			if ttl == e + 1 or ttl == e:
				return [Vector2(0, 1), [], []]
			return [NONE, [], []]
		var r: Dictionary = await _ollie_run(6.0, hook, 4)
		if r["state_after"] != "MANUAL":
			break
		best = k
	return {"manual_entry_window_ms": float(best) * DT * 1000.0}


## Starts a manual on the flat at 6 m/s, then balances it with `human` (the delayed proportional stick) or no stick.
## Seconds until the fall (capped at BALANCE_CAP_S).
func _manual_hold(human: bool) -> float:
	await _flat_start(6.0)
	for i: int in 5:
		await tick()
	for s: Vector2 in [Vector2(0, -1), Vector2(0, -1), Vector2(0, 1), Vector2(0, 1)]:
		await tick(s)
	var seen: Array = []
	var t: float = 0.0
	if sname() != "MANUAL":
		await clear()
		return -1.0
	while t < BALANCE_CAP_S and sname() == "MANUAL":
		seen.append(_lean())
		var stick: Vector2 = NONE
		if human and seen.size() > HUMAN_REACT_TICKS:
			stick = Vector2(0.0, clampf(float(seen[seen.size() - 1 - HUMAN_REACT_TICKS]), -1.0, 1.0))
		sk.speed = 6.0
		sk.velocity = sk.velocity.normalized() * 6.0  ## hold the speed: the clock, not friction, should end it
		if sk.global_position.z < -60.0:
			sk.global_position.z += 120.0
		await tick(stick)
		t += DT
	await clear()
	return t


## What the player model reacts to: lean plus how fast it is tipping, weighted.
func _lean() -> float:
	return HUMAN_GAIN * float(sk.balance.angle) + HUMAN_RATE_GAIN * float(sk.balance.velocity)


func m_manual_balance() -> Dictionary:
	return {"manual_fall_nostick_s": await _manual_hold(false), "manual_hold_human_s": await _manual_hold(true)}


## 50-50 on a long flat rail at `v0`, balanced by `human` or not: seconds on the rail until it topples or bails.
func _grind_hold(human: bool) -> float:
	await sandbox([STREET.flat_rail(200.0, 0.45)])
	var rails: Array = host.get_tree().get_nodes_in_group("grind_rail")
	var cx: float = (rails[0] as GrindRail).global_points()[0].x
	place(Vector3(cx, 0.0, -0.4), Vector3(0, 0, 1), 9.0)
	await host.get_tree().physics_frame
	await tick(NONE, ["grind"], [])
	var t: float = 0.0
	var seen: Array = []
	while t < BALANCE_CAP_S and sname() == "GRIND":
		seen.append(_lean())
		var stick: Vector2 = NONE
		if human and seen.size() > HUMAN_REACT_TICKS:
			stick = Vector2(clampf(-float(seen[seen.size() - 1 - HUMAN_REACT_TICKS]), -1.0, 1.0), 0.0)
		sk._rail_speed = 8.0 * signf(sk._rail_speed)  ## hold the speed: the balance, not friction, should end it
		await tick(stick)
		t += DT
	await clear()
	return t


func m_grind_balance() -> Dictionary:
	return {"grind_fall_nostick_s": await _grind_hold(false), "grind_hold_human_s": await _grind_hold(true)}


## Rolling at 8 m/s alongside a 0.45 m rail, `d` m to its side, grind pressed: does it snap on?
func _grind_catch(d: float) -> bool:
	await sandbox([STREET.flat_rail(30.0, 0.45)])
	var rails: Array = host.get_tree().get_nodes_in_group("grind_rail")
	var rp: Vector3 = (rails[0] as GrindRail).global_points()[0]
	place(Vector3(rp.x + d, 0.0, 3.0), Vector3(0, 0, 1), 8.0)
	await host.get_tree().physics_frame
	for i: int in 3:
		await tick()
	await tick(NONE, ["grind"], [])
	var ok: bool = false
	for i: int in 3:
		await tick()
		ok = ok or sname() == "GRIND"
	await clear()
	return ok


## Rolling at 8 m/s straight at a rail's end from 5 m out. Grind is pressed once, on the first tick the skater is past
## `z_press` (or on every tick when `every`). Returns the z of the tick before the grind started (99 when none did).
## Triggered by position, not tick count, so a one-tick shift in the sandbox's start can't skew it.
func _grind_press_at(z_press: float, every: bool = false) -> float:
	await sandbox([STREET.flat_rail(30.0, 0.45)])
	var rails: Array = host.get_tree().get_nodes_in_group("grind_rail")
	var rp: Vector3 = (rails[0] as GrindRail).global_points()[0]
	place(Vector3(rp.x, 0.0, -5.0), Vector3(0, 0, 1), 8.0)
	await host.get_tree().physics_frame
	var pressed: bool = false
	var z_prev: float = sk.global_position.z
	var got: float = 99.0
	for i: int in 50:
		var press: bool = every or (not pressed and sk.global_position.z >= z_press)
		pressed = pressed or press
		z_prev = sk.global_position.z
		await tick(NONE, ["grind"] if press else [], [])
		if sname() == "GRIND":
			got = z_prev
			break
	await clear()
	return got


func m_grind_reach() -> Dictionary:
	var lo: float = 0.0
	var hi: float = 2.5
	for i: int in 8:
		var mid: float = (lo + hi) * 0.5
		if await _grind_catch(mid):
			lo = mid
		else:
			hi = mid
	# Where a grind starts when grind is mashed: the rail just came into reach. Then the earliest single press before
	# that point that still grinds (buffered), in ticks of travel at 8 m/s.
	var z_reach: float = await _grind_press_at(0.0, true)
	var best: int = 0
	for k: int in range(1, 30):
		if await _grind_press_at(z_reach - float(k) * 8.0 * DT + 0.01) > 50.0:
			break
		best = k
	return {"grind_snap_reach_m": lo, "grind_press_buffer_ms": float(best) * DT * 1000.0}


## Ollie into a tall wall at 25 degrees with grind tapped through the air: how long the wallride lasts.
func m_wallride() -> Dictionary:
	var wall := Node3D.new()
	wall.add_child(PieceKit.box(Vector3(-30, 0, -0.2), Vector3(60, 5, 0.4), PieceKit.PAINT_RED, "Wall"))
	wall.position = Vector3(0, 0, -4.0)
	await sandbox([wall])
	var th: float = deg_to_rad(25.0)  ## 25 degrees into the wall's face: a shallow approach, as wallrides are done
	var d := Vector3(cos(th), 0.0, -sin(th))
	place(Vector3(-15.0, 0.0, -1.5), d, 8.0)
	await host.get_tree().physics_frame
	for i: int in 3:
		await tick()
	for i: int in 20:
		await tick(NONE, ["ollie"] if i == 0 else [], ["ollie"])
	var wr: int = 0
	var y0: float = 0.0
	var y1: float = 0.0
	for i: int in 240:
		await tick(NONE, ["grind"] if i % 4 == 0 and wr == 0 else [], [])
		if sname() == "WALLRIDE":
			if wr == 0:
				y0 = sk.global_position.y
			wr += 1
			y1 = sk.global_position.y
		elif wr > 0:
			break
	await clear()
	return {"wallride_duration_s": float(wr) * DT, "x_wallride_height_change_m": y1 - y0}


## Head-on into a flat wall at v0: bail or not.
func _slams(v0: float) -> bool:
	var wall := Node3D.new()
	wall.add_child(PieceKit.box(Vector3(-2, 0, -0.2), Vector3(4, 3, 0.4), PieceKit.PAINT_RED, "Wall"))
	wall.position = Vector3(0, 0, -6.2)
	await sandbox([wall])
	var dir := Vector3(0, 0, -1)
	place(Vector3(0, 0, -5.7) - dir * v0 * 0.5, dir, v0)
	await host.get_tree().physics_frame
	for i: int in 60:
		await tick()
	var b: bool = bails > 0
	await clear()
	return b


func m_wall_slam() -> Dictionary:
	var lo: float = 4.0
	var hi: float = 22.0
	if not await _slams(hi):
		return {"wall_slam_speed_ms": 99.0}
	for i: int in 7:
		var mid: float = (lo + hi) * 0.5
		if await _slams(mid):
			hi = mid
		else:
			lo = mid
	return {"wall_slam_speed_ms": hi}


## A 4 m quarter pipe (radius 3.5, like the halfpipe's walls) at v0, no input: board height above the coping.
func _vert(v0: float) -> float:
	await sandbox([QP.build(10.0, 3.5, 4.0, 1.5)])
	place(Vector3(5.0, 0.0, 6.8), Vector3(0, 0, -1), v0)
	await host.get_tree().physics_frame
	var peak: float = 0.0
	for i: int in 300:
		await tick()
		peak = maxf(peak, sk.global_position.y)
	await clear()
	return peak - 4.0


func m_vert() -> Dictionary:
	var g: float = tv("gravity", 18.0)
	return {"vert_air_14ms": await _vert(14.0), "vert_air_18ms": await _vert(18.0),
		"x_vert_ideal_18ms_m": 18.0 * 18.0 / (2.0 * g) - 4.0}


## Bowl-style carve: up a 2.5 m quarter pipe at 45 degrees and 8 m/s, no input, and back down. Speed back on the flat
## over the entry speed.
func m_wall_carve() -> Dictionary:
	await sandbox([QP.build(30.0, 2.5, 2.5, 1.5)])
	var d := Vector3(1, 0, -1).normalized()
	place(Vector3(5.0, 0.0, 7.0), d, 8.0)
	await host.get_tree().physics_frame
	var v_in: float = -1.0
	var v_out: float = -1.0
	var climbed: bool = false
	var peak: float = 0.0
	for i: int in 300:
		await tick()
		var p: Vector3 = sk.global_position
		peak = maxf(peak, p.y)
		if v_in < 0.0 and p.z < 4.05:
			v_in = sk.velocity.length()  ## at the toe
		if p.y > 0.3:
			climbed = true
		if climbed and p.z > 4.05 and sk.velocity.z > 0.0:
			v_out = sk.velocity.length()
			break
	var res: Dictionary = {"wall_carve_speed_retention": v_out / maxf(v_in, 0.01), "x_wall_carve_peak_m": peak,
		"x_wall_carve_bails": bails, "x_wall_carve_air": sk != null and sname() == "AIR"}
	await clear()
	return res


## A long 15 degree hill: mean acceleration rolling down it, no input, over 1 s (from 0.5 s to 1.5 s).
func m_slope() -> Dictionary:
	var ang: float = deg_to_rad(15.0)
	var run: float = 30.0
	var h: float = run * tan(ang)
	var prof := PackedVector2Array([Vector2(0.0, -2.0), Vector2(0.0, run), Vector2(h, 0.0), Vector2(h, -2.0)])
	var wedge := Node3D.new()
	wedge.add_child(PieceKit.body(PieceKit.extrude_profile(prof, 10.0), PieceKit.RAMP_WOOD, "Hill"))
	wedge.position = Vector3(-5.0, 0.0, 0.0)
	await sandbox([wedge])
	place(Vector3(0.0, h - 0.5 * tan(ang) + 0.02, 0.5), Vector3(0, 0, 1), 1.0)
	await host.get_tree().physics_frame
	var v_a: float = -1.0
	var v_b: float = -1.0
	for i: int in 90:
		await tick()
		if i == 29:
			v_a = sk.velocity.length()
		if i == 89:
			v_b = sk.velocity.length()
	await clear()
	var g: float = tv("gravity", 18.0)
	return {"slope_accel_15deg": v_b - v_a, "x_slope_ideal_gsin_ms2": g * sin(ang)}


## One full hands-off lap round the dome bowl (r 8, depth 6.8) at a steady ring: start tangent at radius `ring` m from the
## centre at `v0`, steer with a proportional controller that holds the ring radius, no pumping (no forward stick). The
## ring's height is the same at both ends, so speed back over speed in is the lap's pure carve loss (rolling friction,
## side grip, wall press). Returns {ratio, lap_s, mean_radius}.
func _dome_lap(v0: float, ring: float) -> Dictionary:
	var node: Node3D = DOME.build(8.0, 0.85, 16, 48, "dome")
	await sandbox([node])
	var c := Vector3(9.5, 0.0, 9.5)
	var rs: float = (64.0 + 6.8 * 6.8) / (2.0 * 6.8)
	var yc: float = rs - 6.8
	var y0: float = yc - sqrt(maxf(rs * rs - ring * ring, 0.0))
	var start := c + Vector3(ring, 0, 0)
	start.y = y0 + 0.1
	var d := Vector3(0, 0, -1)
	place(start, d, v0)
	await host.get_tree().physics_frame
	var v_in: float = -1.0
	var ang_prev: float = 0.0
	var turned: float = 0.0
	var r_sum: float = 0.0
	var r_n: int = 0
	var ticks: int = 0
	var v_out: float = -1.0
	for i: int in 900:
		var rel: Vector3 = sk.global_position - c
		var r: float = Vector2(rel.x, rel.z).length()
		var ang: float = atan2(rel.z, rel.x)
		if i > 0:
			turned += absf(wrapf(ang - ang_prev, -PI, PI))
		ang_prev = ang
		var spd: float = sk.velocity.length()
		var radial := Vector3(rel.x, 0.0, rel.z).normalized()
		var tang := Vector3(-radial.z, 0.0, radial.x) * -1.0  ## counter-clockwise seen from above is -z at +x
		var want: Vector3 = (tang - radial * clampf((r - ring) * 0.5, -0.8, 0.8)).normalized()
		var hv := Vector3(sk.velocity.x, 0.0, sk.velocity.z).normalized()
		var err: float = hv.signed_angle_to(want, Vector3.UP)  ## + = want is to the left
		var st: float = clampf(-err * 2.5, -1.0, 1.0)  ## stick x: steer = -stick_x * rate, rotation about +Y is left
		await tick(Vector2(st, 0.0))
		ticks += 1
		if ticks == 60:
			v_in = sk.velocity.length()
			turned = 0.0
		if ticks > 60:
			r_sum += r
			r_n += 1
			if turned >= TAU:
				v_out = sk.velocity.length()
				break
		if sname() != "ROLLING" and sname() != "AIR":
			break
	var res: Dictionary = {"ratio": v_out / maxf(v_in, 0.01) if v_out > 0.0 else -1.0, "lap_s": float(ticks - 60) * DT,
		"mean_radius": r_sum / maxf(float(r_n), 1.0), "v_in": v_in, "v_out": v_out, "bails": bails, "state": sname()}
	await clear()
	return res


const DOME := preload("res://game/park/pieces/dome_bowl.gd")


func m_bowl_lap() -> Dictionary:
	var r: Dictionary = await _dome_lap(11.0, 6.0)
	return {"dome_lap_speed_retention": r["ratio"], "x_dome_lap_s": r["lap_s"], "x_dome_lap_radius_m": r["mean_radius"],
		"x_dome_lap_bails": r["bails"]}


## Powerslide (the revert button while rolling, or "powerslide" in scripted input; Skater.powersliding while it skids):
## the mean deceleration over the first 0.5 s of a full-stick slide at 10 m/s.
func m_powerslide() -> Dictionary:
	await _flat_start(10.0)
	for i: int in 6:
		await tick()
	var v0: float = sk.velocity.length()
	var slid: bool = false
	var v1: float = v0
	for i: int in 30:
		await tick(Vector2(1.0, 0.0), ["powerslide"] if i == 0 else [], ["powerslide"])
		if bool(sk.get("powersliding")):
			slid = true
	v1 = sk.velocity.length()
	await clear()
	if not slid:
		return {"powerslide_decel_ms2": NAN}
	return {"powerslide_decel_ms2": (v0 - v1) / 0.5}


## Nollie against ollie: tap height ratio (nollie stance toggled with the nollie button, then a tap ollie).
func m_nollie() -> Dictionary:
	var tap: Dictionary = await _ollie(1)
	var nol: Dictionary = await _ollie(1, "nollie")
	if float(nol["height"]) < 0.2:
		return {"nollie_height_ratio": NAN, "x_nollie_height_m": nol["height"]}
	return {"nollie_height_ratio": float(nol["height"]) / maxf(float(tap["height"]), 0.01), "x_nollie_height_m": nol["height"]}


## Starts a manual on the flat at 6 m/s; false when it did not start.
func _enter_manual() -> bool:
	await _flat_start(6.0)
	for i: int in 5:
		await tick()
	for s: Vector2 in [Vector2(0, -1), Vector2(0, -1), Vector2(0, 1), Vector2(0, 1)]:
		await tick(s)
	return sname() == "MANUAL"


## Manual balance feel: how far the meter drifts in one second with no input (the faster it runs away, the busier the
## player), and how fast full counter-stick brings a half-tipped manual back to near centre.
func m_manual_drift() -> Dictionary:
	if not await _enter_manual():
		await clear()
		return {"manual_drift_1s": -1.0, "manual_recover_half_s": -1.0}
	sk.balance.angle = 0.1
	sk.balance.velocity = 0.0
	var peak_drift: float = 0.0
	for i: int in 60:
		sk.speed = 6.0
		sk.velocity = sk.velocity.normalized() * 6.0
		await tick()
		if sname() != "MANUAL":
			break
	peak_drift = absf(float(sk.balance.angle)) / 0.1  ## growth factor of a 0.1 lean in 1 s
	var drift_state: String = sname()
	await clear()
	var rec: float = -1.0
	if await _enter_manual():
		sk.balance.angle = 0.5
		sk.balance.velocity = 0.0
		var t: float = 0.0
		while t < 3.0 and sname() == "MANUAL":
			sk.speed = 6.0
			sk.velocity = sk.velocity.normalized() * 6.0
			var a: float = float(sk.balance.angle)
			await tick(Vector2(0.0, clampf(a * 3.0 + float(sk.balance.velocity) * 0.8, -1.0, 1.0)))
			t += DT
			if absf(float(sk.balance.angle)) < 0.1:
				rec = t
				break
	await clear()
	return {"manual_drift_1s": peak_drift, "manual_recover_half_s": rec, "x_manual_drift_state": drift_state}


## Revert and fakie. revert_speed_keep: speed 12 ticks after touchdown with a revert on the landing tick over the same
## run without it. fakie_landing_retention: a 180 spin landed rolling backward (fakie) over the speed just before it.
func _spin_land_run(spin_ticks: int, revert: bool) -> Dictionary:
	await _flat_start(8.0)
	for i: int in 10:
		await tick()
	for i: int in 30:
		await tick(NONE, ["ollie"] if i == 0 else [], ["ollie"])
	var before: float = 0.0
	var landed_at: int = -1
	var after: float = -1.0
	var result: String = ""
	var stance_before: bool = sk.switch_stance
	for i: int in 160:
		var v: Vector3 = sk.velocity
		var spinning: bool = sname() == "AIR" and spin_ticks > 0 and i < spin_ticks
		var jp: Array = []
		if revert and landed_at < 0 and sname() == "AIR" and sk.global_position.y < 0.15 and sk.velocity.y < 0.0:
			jp = ["revert"]
		await tick(Vector2(-1.0, 0.0) if spinning and spin_ticks > 0 else NONE, jp, ["spin_left"] if spinning else [])
		if landed_at < 0:
			for e: String in sk.events:
				if e.begins_with("land:"):
					landed_at = i
					result = e.substr(5)
					before = Vector2(v.x, v.z).length()
		if landed_at >= 0 and i == landed_at + 12:
			after = Vector2(sk.velocity.x, sk.velocity.z).length()
			break
	var stance_after: bool = sk.switch_stance
	await clear()
	return {"before": before, "after": after, "result": result, "stance_changed": stance_after != stance_before}


func m_revert_fakie() -> Dictionary:
	var base: Dictionary = await _spin_land_run(0, false)
	var rev: Dictionary = await _spin_land_run(0, true)
	var fk: Dictionary = await _spin_land_run(25, false)
	var keep: float = float(rev["after"]) / maxf(float(base["after"]), 0.01) if float(rev["after"]) > 0.0 else -1.0
	return {"revert_speed_keep": keep, "fakie_landing_retention": float(fk["after"]) / maxf(float(fk["before"]), 0.01),
		"x_revert_stance_flipped": rev["stance_changed"], "x_fakie_result": fk["result"], "x_fakie_stance_flipped": fk["stance_changed"],
		"x_revert_result": rev["result"]}


## Drops the upright skater from `h` metres at 12 m/s onto flat ground. Returns {result, impact (m/s into the ground),
## keep (horizontal speed 12 ticks after touchdown over just before), bails}.
func _drop_from(h: float) -> Dictionary:
	await _flat_start(12.0)
	sk.global_position.y = h
	sk.velocity = Vector3(0, 0, -12.0)
	var impact: float = 0.0
	var before: float = 12.0
	var result: String = ""
	var landed_at: int = -1
	var after: float = -1.0
	for i: int in 300:
		var v: Vector3 = sk.velocity
		await tick()
		if landed_at < 0:
			impact = maxf(impact, -v.y)
			for e: String in sk.events:
				if e.begins_with("land:"):
					landed_at = i
					result = e.substr(5)
					before = Vector2(v.x, v.z).length()
		elif i == landed_at + 12:
			after = Vector2(sk.velocity.x, sk.velocity.z).length()
			break
	var b: int = bails
	await clear()
	return {"result": result, "impact": impact, "keep": after / maxf(before, 0.01) if after > 0.0 else -1.0, "bails": b}


## Big-air landing: the highest drop (2 m steps, up to 20 m: a mega-ramp gap lands from about 3 to 8 m) that still lands
## clean, with the impact speed of the last clean one, and the speed kept by an 8 m drop (a mega ramp's fall).
func m_big_air() -> Dictionary:
	var best: float = 0.0
	var impact: float = 0.0
	var keep8: float = -1.0
	var first_bail: float = -1.0
	for h: int in range(2, 22, 2):
		var r: Dictionary = await _drop_from(float(h))
		if h == 8:
			keep8 = r["keep"]
		if r["result"] == "clean":
			if first_bail < 0.0:
				best = float(h)
				impact = r["impact"]
		elif first_bail < 0.0:
			first_bail = float(h)
	return {"big_air_clean_drop_m": best, "big_air_landing_keep": keep8, "x_big_air_clean_impact_ms": impact,
		"x_big_air_first_fail_drop_m": first_bail}


# --- THUG2 board moves (round 4): the scenarios live in tests/sim/sim_board_moves.gd ---------------------------

const BoardMoves := preload("res://tests/sim/sim_board_moves.gd")


func _moves() -> Variant:
	var m: Variant = BoardMoves.new()
	m.host = host
	m.SkaterScript = SkaterScript
	return m


## Boneless (up, up + ollie) height over a full-crouch ollie's, its foot-plant wait from the release to the pop, and the
## no-comply (up + ollie) height over a tap ollie's.
func m_boneless() -> Dictionary:
	var m: Variant = _moves()
	var full: Dictionary = await m.full_ollie()
	var tap: Dictionary = await m.tap_ollie()
	var b: Dictionary = await m.boneless()
	var nc: Dictionary = await m.no_comply()
	var out: Dictionary = {"boneless_height_ratio": NAN, "boneless_plant_ms": NAN, "no_comply_height_ratio": NAN,
		"x_boneless_height_m": b["h"], "x_no_comply_height_m": nc["h"]}
	if (b["anims"] as Dictionary).has("boneless"):
		out["boneless_height_ratio"] = float(b["h"]) / maxf(float(full["h"]), 0.01)
		out["boneless_plant_ms"] = float(b["wait"]) * DT * 1000.0
	if (nc["anims"] as Dictionary).has("no_comply"):
		out["no_comply_height_ratio"] = float(nc["h"]) / maxf(float(tap["h"]), 0.01)
	return out


## Wallplant from a full ollie at 7 m/s into an upright wall: the push-off speed back out, and the speed still going into
## the wall at the push (what the planted foot did not kill).
func m_wallplant() -> Dictionary:
	var w: Dictionary = await _moves().wallplant()
	if not (w["anims"] as Dictionary).has("wallplant"):
		return {"wallplant_push_out_ms": NAN, "wallplant_into_left_ms": NAN}
	return {"wallplant_push_out_ms": w["out"], "wallplant_into_left_ms": w["into"], "x_wallplant_rise_m": w["rise"],
		"x_wallplant_landing": w["result"]}


## Caveman: rolling speed 6 ticks after the board is caught from a running jump on foot.
func m_caveman() -> Dictionary:
	var c: Dictionary = await _moves().caveman()
	if int(c["rolled_at"]) < 0:
		return {"caveman_roll_speed_ms": NAN}
	return {"caveman_roll_speed_ms": c["speed"], "x_caveman_catch_ticks": c["rolled_at"]}


## Acid drop off a 3 m quarter's deck over its face: speed on touching the face over the energy speed
## sqrt(v^2 + 2 g drop) from the press.
func m_acid_drop() -> Dictionary:
	var a: Dictionary = await _moves().acid(true)
	if not (a["anims"] as Dictionary).has("acid_drop"):
		return {"acid_drop_energy_keep": NAN}
	return {"acid_drop_energy_keep": float(a["spd"]) / maxf(float(a["ideal"]), 0.01), "x_acid_drop_face_ny": a["ny"],
		"x_acid_drop_speed_ms": a["spd"]}


func _links(path: String) -> Variant:
	var m: Variant = (load(path) as GDScript).new()
	m.host = host
	m.SkaterScript = SkaterScript
	return m


## Ramp snap drop-in (Q + E) off the deck of a quarter pipe `height` tall (radius 3 m, a vertical wall above that):
## speed at the bottom of the transition and the hardest push the tip over the coping gives (the most speed gained in
## one tick from the stomp to a few ticks onto the wall; the hop up to the coping is a guided glide and not counted). The snap must be a real drop-in: energy-true like rolling in by hand.
func snap_drop_data(height: float) -> Dictionary:
	var deck: float = 2.0
	await sandbox([QP.build(8.0, 3.0, height, deck)])
	place(Vector3(4.0, height + 0.02, deck - 1.2), Vector3(0, 0, 1), 0.5)
	await host.get_tree().physics_frame
	await tick()
	await tick(NONE, ["spin_left", "spin_right"], ["spin_left", "spin_right"])
	await tick(NONE, [], ["spin_left", "spin_right"])
	var snapped: bool = false
	var peak: float = 0.0
	var prev: float = sk.velocity.length()
	var spd: float = -1.0
	var peak_ticks: int = 0
	var bails0: int = bails
	for i: int in int(6.0 / DT):
		await tick()
		var v: float = sk.velocity.length()
		if not sk._snap.is_empty():
			snapped = true
		if str(sk._snap.get("phase", "")) == "tip" or (snapped and sk._snap.is_empty() and peak_ticks < 3):
			peak = maxf(peak, (v - prev) / DT)  # the fall over the coping and its hand-over to the wall
			if sk._snap.is_empty():
				peak_ticks += 1
		prev = v
		if snapped and sk._snap.is_empty() and sk.global_position.z > deck + 3.0 and sk.global_position.y < 0.15:
			spd = v
			break
	var res: Dictionary = {"spd": spd, "peak": peak, "snapped": snapped, "bails": bails - bails0, "state": sname()}
	await clear()
	return res


func m_snap_drop() -> Dictionary:
	var g: float = tv("gravity", 18.0)
	var h: float = 6.0
	var r: Dictionary = await snap_drop_data(h)
	var low: Dictionary = await snap_drop_data(3.2)
	if not bool(r["snapped"]) or float(r["spd"]) < 0.0:
		return {"snap_drop_energy_keep": NAN, "snap_drop_peak_accel_g": NAN}
	return {"snap_drop_energy_keep": float(r["spd"]) / sqrt(2.0 * g * h), "snap_drop_peak_accel_g": float(r["peak"]) / g,
		"x_snap_drop_6m_speed_ms": r["spd"], "x_snap_drop_6m_bails": r["bails"],
		"x_snap_drop_3m_keep": float(low["spd"]) / sqrt(2.0 * g * 3.2), "x_snap_drop_3m_peak_accel_g": float(low["peak"]) / g}


## Grind links (tests/sim/sim_grind_links.gd): speed kept through a switch to another grind on the rail and through an
## ollie transfer to the next rail, and the height of a fully charged pop off a rail over a tap pop's.
func m_grind_links() -> Dictionary:
	var sim: Variant = _links("res://tests/sim/sim_grind_links.gd")
	var sw: Dictionary = await sim.switch_data()
	var tr: Dictionary = await sim.transfer_data()
	var tap: Dictionary = await sim.pop_data(1)
	var full: Dictionary = await sim.pop_data(30)
	return {
		"grind_switch_speed_keep": float(sw["keep"]) if str(sw["anim"]) == "grind_boardslide" else NAN,
		"rail_transfer_speed_keep": float(tr["keep"]) if str(tr["names"]).contains("Rail Transfer") else NAN,
		"grind_pop_charge_ratio": float(full["h"]) / maxf(float(tap["h"]), 0.01),
		"x_grind_pop_tap_m": tap["h"], "x_grind_pop_full_m": full["h"],
	}


## Kickflip out of a nose stall on a 4 m quarter: air time from the pop to the touchdown, less the flip's time.
func m_lip_out() -> Dictionary:
	var sim: Variant = _links("res://tests/sim/sim_wall_lip_outs.gd")
	var d: Dictionary = await sim.lip_flip_data()
	if not str(d["names"]).contains("Kickflip"):
		return {"lip_pop_flip_margin_s": NAN}
	return {"lip_pop_flip_margin_s": float(d["air"]) - tv("flip_time", 0.42), "x_lip_pop_landing": d["land"]}


## Sketchy landing stagger (Skate-3 catch): a full ollie at 8 m/s spun `deg` in the air, then full right stick from the
## touchdown. Returns the yaw turned in the first 0.25 s on the ground, the stagger seconds the skater reports, the
## landing result and the speed 0.6 s after touchdown over the speed just before it (m_sketchy scores it against the
## clean run's, so the carve's own scrub cancels out).
func _stagger_run(deg: float) -> Dictionary:
	var rate: float = tv("spin_rate", 7.5)
	var n: int = roundi(deg_to_rad(deg) / (rate * DT))
	await _flat_start(8.0)
	for i: int in 10:
		await tick()
	for i: int in 30:
		await tick(NONE, ["ollie"] if i == 0 else [], ["ollie"])
	var res: String = ""
	var k: int = 0
	var before: float = 0.0
	for i: int in 120:
		var spinning: bool = sname() == "AIR" and k < n
		await tick(Vector2(-1.0, 0.0) if spinning else NONE, ["spin_left"] if spinning and k == 0 else [],
				["spin_left"] if spinning else [])
		if spinning:
			k += 1
		for e: String in sk.events:
			if e.begins_with("land:"):
				res = e.substr(5)
		if res != "":
			break
		before = Vector2(sk.velocity.x, sk.velocity.z).length()
	var f0: Vector3 = sk.facing
	var turned: float = 0.0
	var stag: int = 0
	var keep: float = NAN
	for i: int in 36:
		await tick(Vector2(1.0, 0.0))
		if float(sk.get("stagger") if sk.get("stagger") != null else 0.0) > 0.0:
			stag += 1
		if i == 14:
			turned = rad_to_deg(Vector2(f0.x, f0.z).angle_to(Vector2(sk.facing.x, sk.facing.z)))
	keep = sk.velocity.length() / maxf(before, 0.001)
	await clear()
	return {"result": res, "turn": absf(turned), "stagger_s": float(stag + (1 if stag > 0 else 0)) * DT, "keep": keep}


func m_sketchy() -> Dictionary:
	var clean: Dictionary = await _stagger_run(0.0)
	var sk_run: Dictionary = await _stagger_run(65.0)
	if sk_run["result"] != "sketchy" or clean["result"] != "clean":
		return {"sketchy_stagger_s": NAN, "sketchy_steer_ratio": NAN, "sketchy_speed_keep": NAN,
			"x_sketchy_results": [clean["result"], sk_run["result"]]}
	return {"sketchy_stagger_s": sk_run["stagger_s"],
		"sketchy_steer_ratio": float(sk_run["turn"]) / maxf(float(clean["turn"]), 0.01),
		"sketchy_speed_keep": float(sk_run["keep"]) / maxf(float(clean["keep"]), 0.001), "x_sketchy_abs_keep": sk_run["keep"],
		"x_clean_speed_keep": clean["keep"],
		"x_sketchy_turn_deg_025s": sk_run["turn"], "x_clean_turn_deg_025s": clean["turn"]}
