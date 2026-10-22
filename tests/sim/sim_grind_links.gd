extends "res://tests/sim/sim_base.gd"
## Grind depth (THUG2): what a rail can link into, and how the pop off it is timed.
##  grind_switch_mid_rail   on a 50-50, stick E + grind switches to a boardslide on the same rail: still grinding, the
##                          boardslide scores as its own trick (combo x2), the speed is kept and the balance is half reset
##  grind_pop_charge        a tap ollie pops off the rail at about 7.5 m/s; holding ollie on the rail crouches and the
##                          release pops higher (the full charge about 1.4 x the tap's height), and nothing pops mid-hold
##  grind_pop_charge_at_end holding ollie through the end of the rail pops the charged ollie there (not the fall-off hop)
##  rail_transfer           ollie off the end of one rail and grind the next one in line: the combo carries a
##                          "Rail Transfer" link and the second grind keeps at least 90% of the first one's speed
##  ledge_no_fake_transfer  hopping from one top edge of a ledge to its other edge is no Rail Transfer, and mashing grind
##                          off the ledge's end never catches the ends of its two edges back and forth
##  manual_to_grind         grind pressed in a manual beside a low rail starts the grind straight from the manual
##  grind_to_manual         the manual flick (N, S) done on the rail, well before its end, lands the drop off it in a manual

const STREET := preload("res://game/park/pieces/street_bits.gd")
const K1: float = 3.0  ## the bot's balance gains (tests/bot/bot_driver.gd)
const K2: float = 1.1


## The stick x that holds a grind's balance (as the bot does).
func _bal_x() -> float:
	return -clampf(K1 * sk.balance.angle + K2 * sk.balance.velocity, -1.0, 1.0)


## The stick y that holds a manual's balance.
func _bal_y() -> float:
	return clampf(K1 * sk.balance.angle + K2 * sk.balance.velocity, -1.0, 1.0)


func _names() -> String:
	return str(sk.combo.display_text())


## A 30 m flat rail at 0.45 m and the skater grinding it at 8 m/s. Returns the rail's start point.
func _on_rail(length: float = 30.0) -> Vector3:
	await sandbox([STREET.flat_rail(length, 0.45)])
	var rails: Array = host.get_tree().get_nodes_in_group("grind_rail")
	var rp: Vector3 = (rails[0] as GrindRail).global_points()[0]
	place(Vector3(rp.x, 0.0, -0.4), Vector3(0, 0, 1), 8.0)
	await host.get_tree().physics_frame
	await tick(NONE, ["grind"], [])
	return rp


## A 50-50 switched to a boardslide 0.5 s in (the physics lab's grind_switch_speed_keep reads "keep").
func switch_data() -> Dictionary:
	await _on_rail()
	for i: int in 30:
		await tick(Vector2(_bal_x(), 0.0))
	var st0: String = sname()
	var v0: float = sk.velocity.length()
	var a0: float = absf(sk.balance.angle)
	var n0: int = sk.combo.trick_count()
	await tick(Vector2(1.0, 0.0), ["grind"], [])
	var a1: float = absf(sk.balance.angle)
	var v1: float = sk.velocity.length()
	var anim1: String = sk.anim
	var n1: int = sk.combo.trick_count()
	var names: String = _names()
	var still: bool = true
	for i: int in 20:
		await tick(Vector2(_bal_x(), 0.0))
		still = still and sname() == "GRIND"
	var d: Dictionary = {"st0": st0, "still": still, "anim": anim1, "n0": n0, "n1": n1, "names": names, "keep": v1 / maxf(v0, 0.01),
		"a0": a0, "a1": a1, "bails": bails}
	await clear()
	return d


func _switch() -> Array:
	var d: Dictionary = await switch_data()
	var ok: bool = str(d["st0"]) == "GRIND" and bool(d["still"]) and str(d["anim"]) == "grind_boardslide" and int(d["n1"]) == int(d["n0"]) + 1 \
		and str(d["names"]).contains("Boardslide") and float(d["keep"]) >= 0.98 and float(d["a1"]) <= float(d["a0"]) * 0.55 + 0.01 and int(d["bails"]) == 0
	return ok_line("grind_switch_mid_rail", ok,
		"grinding %s -> %s for 20 ticks, anim %s (want grind_boardslide), tricks %d -> %d, \"%s\", speed keep %.3f (want >= 0.98), balance |%.3f| -> |%.3f| (want halved), bails %d"
		% [str(d["st0"]), str(d["still"]), str(d["anim"]), int(d["n0"]), int(d["n1"]), str(d["names"]), float(d["keep"]), float(d["a0"]), float(d["a1"]), int(d["bails"])])


## Peak height above the rail of the pop off it, with ollie held `hold` ticks on the rail first (1 = a tap).
func pop_data(hold: int) -> Dictionary:
	var rp: Vector3 = await _on_rail()
	for i: int in 20:
		await tick(Vector2(_bal_x(), 0.0))
	var y0: float = sk.global_position.y
	var early: bool = false
	for i: int in hold:
		await tick(Vector2(_bal_x(), 0.0), ["ollie"] if i == 0 else [], ["ollie"])
		if i < hold - 1 and sname() != "GRIND":
			early = true
	var peak: float = y0
	var left: bool = false
	for i: int in 90:
		await tick()
		if sname() == "AIR":
			left = true
		peak = maxf(peak, sk.global_position.y)
		if left and sname() != "AIR":
			break
	var res: Dictionary = {"h": peak - y0, "left": left, "early": early, "rail_y": rp.y}
	await clear()
	return res


func _pop_rows() -> Array:
	var tap: Dictionary = await pop_data(1)
	var full: Dictionary = await pop_data(30)
	var ratio: float = float(full["h"]) / maxf(float(tap["h"]), 0.01)
	var ok: bool = bool(tap["left"]) and bool(full["left"]) and not bool(full["early"]) and float(tap["h"]) > 1.35 \
		and float(tap["h"]) < 1.8 and ratio >= 1.25 and ratio <= 1.7
	return [ok_line("grind_pop_charge", ok,
		"tap pop %.2f m (want 1.35-1.8, the old fixed 7.5 m/s), 0.5 s charge %.2f m, ratio %.2f (want 1.25-1.7), popped mid-hold %s"
		% [float(tap["h"]), float(full["h"]), ratio, str(full["early"])])]


## Holds ollie for the last 0.6 s of a short rail: the end pops the charged ollie.
func _pop_at_end() -> Array:
	await _on_rail(6.0)
	var rails: Array = host.get_tree().get_nodes_in_group("grind_rail")
	var end_z: float = (rails[0] as GrindRail).global_points()[1].z
	var y0: float = sk.global_position.y
	var pressed: bool = false
	var peak: float = y0
	var ev: Array = []
	var left: bool = false
	for i: int in 200:
		var z: float = sk.global_position.z
		var hold: bool = sname() == "GRIND" and z > end_z - 4.8
		var jp: Array = ["ollie"] if hold and not pressed else []
		if hold:
			pressed = true
		await tick(Vector2(_bal_x(), 0.0) if sname() == "GRIND" else NONE, jp, ["ollie"] if hold else [])
		for e: String in sk.events:
			ev.append(e)
		if sname() == "AIR":
			left = true
			peak = maxf(peak, sk.global_position.y)
		elif left:
			break
	var popped: bool = ev.has("ollie")
	var ok: bool = left and popped and peak - y0 > 1.8 and bails == 0
	var row: Array = ok_line("grind_pop_charge_at_end", ok,
		"held ollie off the end: popped %s (want true), rose %.2f m (want > 1.8: the charged pop, a fall-off hop rises 0.25 m), bails %d"
		% [str(popped), peak - y0, bails])
	await clear()
	return row


## Ollie off the end of an 8 m rail onto a second one in line 2 m on and 0.5 m to the side.
func transfer_data() -> Dictionary:
	var a := STREET.flat_rail(8.0, 0.45)
	var b := STREET.flat_rail(14.0, 0.45)
	b.position = Vector3(0.5, 0.0, 10.0)
	await sandbox([a, b])
	var rails: Array = host.get_tree().get_nodes_in_group("grind_rail")
	var ra: GrindRail = rails[0] as GrindRail
	var rp: Vector3 = ra.global_points()[0]
	place(Vector3(rp.x, 0.0, -0.4), Vector3(0, 0, 1), 9.0)
	await host.get_tree().physics_frame
	await tick(NONE, ["grind"], [])
	var v_a: float = 0.0
	var v_b: float = -1.0
	var on_b: bool = false
	var popped: bool = false
	for i: int in 240:
		var st: String = sname()
		if st == "GRIND" and sk._rail == ra:
			v_a = sk.velocity.length()
			var pop: bool = sk.global_position.z > 7.3 and not popped
			if pop:
				popped = true
			await tick(Vector2(_bal_x(), 0.0), ["ollie"] if pop else [], ["ollie"] if pop else [])
		elif st == "AIR":
			await tick(NONE, ["grind"] if i % 3 == 0 else [], [])
		elif st == "GRIND":
			on_b = true
			await tick(Vector2(_bal_x(), 0.0))  ## the catch tick still carries the air's fall: read the rail speed after it
			v_b = sk.velocity.length()
			break
		else:
			break
	var d: Dictionary = {"names": _names(), "keep": v_b / maxf(v_a, 0.01), "on_b": on_b, "popped": popped, "v_a": v_a, "v_b": v_b,
		"bails": bails}
	await clear()
	return d


func _transfer() -> Array:
	var d: Dictionary = await transfer_data()
	var ok: bool = bool(d["on_b"]) and bool(d["popped"]) and str(d["names"]).contains("Rail Transfer") and float(d["keep"]) >= 0.9 \
		and int(d["bails"]) == 0
	return ok_line("rail_transfer", ok,
		"ollied off rail A %s, grinding rail B %s, \"%s\" (want Rail Transfer), speed %.2f -> %.2f m/s (keep %.2f, want >= 0.9), bails %d"
		% [str(d["popped"]), str(d["on_b"]), str(d["names"]), float(d["v_a"]), float(d["v_b"]), float(d["keep"]), int(d["bails"])])


func _ledge_hops() -> Array:
	await sandbox([STREET.ledge(8.0, 0.5)])
	place(Vector3(-0.4, 0.0, -0.4), Vector3(0, 0, 1), 8.0)
	await host.get_tree().physics_frame
	await tick(NONE, ["grind"], [])
	var grinds_after_end: int = 0
	var grinds: int = 0
	var popped: bool = false
	for i: int in 150:
		var st: String = sname()
		var jp: Array = []
		var stick: Vector2 = NONE
		if st == "GRIND":
			stick = Vector2(_bal_x(), 0.0)
			if sk.global_position.z > 2.5 and not popped:
				popped = true
				jp = ["ollie"]
		elif st == "AIR" and i % 3 == 0:
			jp = ["grind"]
		elif st != "AIR":
			if sk.global_position.z > 8.0:
				break
		await tick(stick, jp, ["ollie"] if jp.has("ollie") else [])
		if (sk.events as Array).has("grind"):
			grinds += 1
			if sk.global_position.z > 7.9:
				grinds_after_end += 1
	var names: String = _names()
	var ok: bool = popped and grinds >= 1 and not names.contains("Rail Transfer") and grinds_after_end == 0
	var row: Array = ok_line("ledge_no_fake_transfer", ok,
		"hopped on the ledge %s, re-caught %d times, \"%s\" (want no Rail Transfer), catches at the ledge's end %d (want 0), bails %d"
		% [str(popped), grinds, names, grinds_after_end, bails])
	await clear()
	return row


## Start a manual on the flat (N flick then S) and keep it balanced.
func _start_manual() -> void:
	await tick(NONE)
	for i: int in 3:
		await tick(Vector2(0.0, -1.0))
	for i: int in 3:
		await tick(Vector2(0.0, 1.0))


func _manual_to_grind() -> Array:
	var r := STREET.flat_rail(12.0, 0.45)
	r.position = Vector3(0.0, 0.0, 6.0)
	await sandbox([r])
	var rails: Array = host.get_tree().get_nodes_in_group("grind_rail")
	var rp: Vector3 = (rails[0] as GrindRail).global_points()[0]
	place(Vector3(rp.x + 0.5, 0.0, 0.0), Vector3(0, 0, 1), 7.0)
	await host.get_tree().physics_frame
	await _start_manual()
	var in_manual: bool = sname() == "MANUAL"
	var pressed: bool = false
	for i: int in 120:
		if sname() != "MANUAL":
			break
		var press: bool = sk.global_position.z > rp.z + 1.5 and not pressed
		if press:
			pressed = true
		await tick(Vector2(0.0, _bal_y()), ["grind"] if press else [], [])
	var st: String = sname()
	var names: String = _names()
	var ok: bool = in_manual and pressed and st == "GRIND" and names.contains("Manual") and bails == 0
	var row: Array = ok_line("manual_to_grind", ok, "manual %s, grind pressed beside the rail %s, state %s (want GRIND), \"%s\", bails %d"
		% [str(in_manual), str(pressed), st, names, bails])
	await clear()
	return row


func _grind_to_manual() -> Array:
	await _on_rail(8.0)
	var rails: Array = host.get_tree().get_nodes_in_group("grind_rail")
	var end_z: float = (rails[0] as GrindRail).global_points()[1].z
	var flicked: bool = false
	var land_state: String = ""
	var left: bool = false
	var flick_t: int = -1
	for i: int in 240:
		var st: String = sname()
		if st == "GRIND":
			var stick := Vector2(_bal_x(), 0.0)
			if sk.global_position.z > end_z - 4.0 and flick_t < 0:
				flick_t = 0
			if flick_t >= 0 and flick_t < 6:
				stick = Vector2(0.0, -1.0 if flick_t < 3 else 1.0)
				flick_t += 1
				flicked = flick_t == 6
			await tick(stick)
		elif st == "AIR":
			left = true
			await tick(NONE)
		else:
			if left:
				land_state = st
			break
	var ok: bool = flicked and left and land_state == "MANUAL" and bails == 0
	var row: Array = ok_line("grind_to_manual", ok,
		"flicked N, S on the rail 4 m before its end %s, dropped off %s, landed in %s (want MANUAL), bails %d"
		% [str(flicked), str(left), land_state, bails])
	await clear()
	return row


func run() -> Array:
	var rows: Array = []
	rows.append(await _switch())
	rows.append_array(await _pop_rows())
	rows.append(await _pop_at_end())
	rows.append(await _transfer())
	rows.append(await _ledge_hops())
	rows.append(await _manual_to_grind())
	rows.append(await _grind_to_manual())
	return rows
