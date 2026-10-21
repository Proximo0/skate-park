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
		["m_push", ["push_time_to_top", "push_top_speed"]],
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
	return {"push_time_to_top": t95, "push_top_speed": top}


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
