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


## The manoeuvre table: [method name, [metric names it produces]]. `--only=<prefix>` keeps a manoeuvre when any of its
## metrics starts with the prefix.
static func table() -> Array:
	return [
		["m_ollie_tap", ["ollie_height_tap", "ollie_airtime_tap"]],
		["m_ollie_full", ["ollie_height_full", "ollie_airtime_full"]],
		["m_push", ["push_time_to_top", "push_top_speed", "push_accel_0_5"]],
		["m_coast", ["coast_distance_8ms"]],
		["m_brake", ["brake_distance_8ms"]],
		["m_turn_4", ["turn_radius_4ms"]],
		["m_turn_8", ["turn_radius_8ms"]],
		["m_turn_12", ["turn_radius_12ms"]],
		["m_quarter_8", ["quarter_air_8ms"]],
		["m_quarter_12", ["quarter_air_12ms"]],
		["m_kicker_8", ["kicker_distance_8ms"]],
		["m_kicker_12", ["kicker_distance_12ms"]],
		["m_landing", ["landing_speed_retention"]],
		["m_halfpipe", ["halfpipe_pump_gain_per_cycle"]],
		["m_loop", ["loop_min_entry_speed"]],
		["m_grind", ["grind_speed_loss_per_m"]],
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
func _ollie(hold_ticks: int) -> Dictionary:
	await _flat_start(4.0)
	for i: int in 20:
		await tick()
	var y0: float = sk.global_position.y
	for i: int in hold_ticks:
		await tick(NONE, [], ["ollie"])
	var peak: float = y0
	var air_ticks: int = 0
	var went_air: bool = false
	for i: int in 180:
		await tick()
		peak = maxf(peak, sk.global_position.y)
		if sname() == "AIR":
			went_air = true
			air_ticks += 1
		elif went_air:
			break
	await clear()
	return {"height": peak - y0, "air": float(air_ticks) * DT}


func m_ollie_tap() -> Dictionary:
	var r: Dictionary = await _ollie(1)
	return {"ollie_height_tap": r["height"], "ollie_airtime_tap": r["air"]}


func m_ollie_full() -> Dictionary:
	var r: Dictionary = await _ollie(40)  ## well past crouch_full (0.4 s = 24 ticks)
	return {"ollie_height_full": r["height"], "ollie_airtime_full": r["air"]}


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
	var prev_dir: Vector2 = Vector2(0, -1)
	var ang: float = 0.0
	var ang_a: float = 0.0
	var ang_b: float = 0.0
	var spd_sum: float = 0.0
	var spd_n: int = 0
	var a_tick: int = int(0.2 / DT)
	var b_tick: int = int(1.2 / DT)
	for i: int in b_tick:
		await tick(Vector2(1.0, 0.0))
		var d: Vector2 = Vector2(sk.velocity.x, sk.velocity.z)
		if d.length() > 0.1:
			ang += prev_dir.angle_to(d.normalized())
			prev_dir = d.normalized()
		if i + 1 == a_tick:
			ang_a = ang
		if i >= a_tick:
			spd_sum += d.length()
			spd_n += 1
		ang_b = ang
	await clear()
	var rate: float = absf(ang_b - ang_a) / (float(b_tick - a_tick) * DT)
	if rate < 0.01:
		return 999.0
	return (spd_sum / float(maxi(spd_n, 1))) / rate


func m_turn_4() -> Dictionary:
	return {"turn_radius_4ms": await _turn(4.0)}


func m_turn_8() -> Dictionary:
	return {"turn_radius_8ms": await _turn(8.0)}


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
	var res: Dictionary = {"grind_speed_loss_per_m": loss, "x_grind_length_m": dist, "x_grind_bails": bails}
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
			var y: float = maxf(sk.global_position.y, 0.0)
			var vy: float = sk.velocity.y
			ttl = maxi(1, ceili((vy + sqrt(vy * vy + 2.0 * g * y)) / g / DT))
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
