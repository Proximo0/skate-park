extends "res://tests/sim/sim_base.gd"
## Manual depth (THUG2): what a manual can link into on the flat, at 7 m/s.
##  manual_balance_no_switch  2 s of manual held with the balance stick alone never switches or adds tricks
##  manual_switch             the nose-manual flick (S, N) in a manual switches to a nose manual (combo x2, still MANUAL)
##  manual_pivot              a spin button in a manual is a 180 pivot: still MANUAL, stance switched, travel unchanged,
##                            the board now down on its other end (manual <-> nose manual), "180 Pivot" scored
##  manual_revert             revert in a manual: back to ROLLING, stance switched, "Revert" scored, combo still open,
##                            and a manual flick right after links a new manual into the same combo
##  flatland_casper / _pogo   grab (neutral / N) in a manual holds a flatland trick (Casper / Pogo) while held, then
##                            back to the manual
##  manual_flip_out           ollie + flip on the same tick out of a manual: the flip scores in the air

const K1: float = 3.0
const K2: float = 1.1


func _bal_y() -> float:
	return clampf(K1 * sk.balance.angle + K2 * sk.balance.velocity, -1.0, 1.0)


func _names() -> String:
	return str(sk.combo.display_text())


## Flat ground, 7 m/s, a manual started (N flick, then S) and balanced for `settle` ticks.
func _in_manual(settle: int = 30) -> bool:
	await sandbox([])
	place(Vector3(0, 0, 40), Vector3(0, 0, -1), 7.0)
	await host.get_tree().physics_frame
	await tick(NONE)
	for i: int in 3:
		await tick(Vector2(0.0, -1.0))
	for i: int in 3:
		await tick(Vector2(0.0, 1.0))
	for i: int in settle:
		await tick(Vector2(0.0, _bal_y()))
	return sname() == "MANUAL"


func _no_switch() -> Array:
	var ok0: bool = await _in_manual(0)
	var n0: int = sk.combo.trick_count()
	var still: bool = true
	for i: int in 120:
		await tick(Vector2(0.0, _bal_y()))
		still = still and sname() == "MANUAL"
	var ok: bool = ok0 and still and sk.combo.trick_count() == n0 and bails == 0
	var row: Array = ok_line("manual_balance_no_switch", ok, "manual held 2 s %s, tricks %d -> %d (want unchanged), bails %d"
		% [str(still), n0, sk.combo.trick_count(), bails])
	await clear()
	return row


func _switch() -> Array:
	var ok0: bool = await _in_manual()
	var n0: int = sk.combo.trick_count()
	for i: int in 3:
		await tick(Vector2(0.0, 1.0))
	for i: int in 3:
		await tick(Vector2(0.0, -1.0))
	var anim1: String = sk.anim
	var st1: String = sname()
	for i: int in 10:
		await tick(Vector2(0.0, _bal_y()))
	var ok: bool = ok0 and st1 == "MANUAL" and sname() == "MANUAL" and anim1 == "manual_nose_manual" \
		and sk.combo.trick_count() == n0 + 1 and _names().contains("Nose Manual") and bails == 0
	var row: Array = ok_line("manual_switch", ok, "state %s, anim %s (want manual_nose_manual), tricks %d -> %d, \"%s\", bails %d"
		% [st1, anim1, n0, sk.combo.trick_count(), _names(), bails])
	await clear()
	return row


func _pivot() -> Array:
	var ok0: bool = await _in_manual()
	var sw0: bool = sk.switch_stance
	var v0: Vector3 = sk.velocity
	await tick(Vector2(0.0, _bal_y()), ["spin_left"], ["spin_left"])
	for i: int in 12:
		await tick(Vector2(0.0, _bal_y()))
	var dirdot: float = sk.velocity.normalized().dot(v0.normalized())
	var ok: bool = ok0 and sname() == "MANUAL" and sk.switch_stance != sw0 and sk.anim == "manual_nose_manual" \
		and _names().contains("180 Pivot") and dirdot > 0.99 and bails == 0
	var row: Array = ok_line("manual_pivot", ok, "state %s, switch %s -> %s, anim %s (want manual_nose_manual), \"%s\", travel dot %.3f, bails %d"
		% [sname(), str(sw0), str(sk.switch_stance), sk.anim, _names(), dirdot, bails])
	await clear()
	return row


func _revert() -> Array:
	var ok0: bool = await _in_manual()
	var sw0: bool = sk.switch_stance
	await tick(Vector2(0.0, _bal_y()), ["revert"], ["revert"])
	var st1: String = sname()
	var open1: bool = sk.state.combo_open
	var names1: String = _names()
	for i: int in 4:
		await tick(NONE)
	for i: int in 3:
		await tick(Vector2(0.0, -1.0))
	for i: int in 3:
		await tick(Vector2(0.0, 1.0))
	var st2: String = sname()
	var n2: int = sk.combo.trick_count()
	var ok: bool = ok0 and st1 == "ROLLING" and open1 and sk.switch_stance != sw0 and names1.contains("Revert") \
		and st2 == "MANUAL" and n2 == 3 and bails == 0
	var row: Array = ok_line("manual_revert", ok,
		"after revert %s (want ROLLING), combo open %s, switch %s -> %s, \"%s\"; manual flick after: %s with %d tricks (want MANUAL, 3), bails %d"
		% [st1, str(open1), str(sw0), str(sk.switch_stance), names1, st2, n2, bails])
	await clear()
	return row


func _flatland(stick: Vector2, want_name: String, want_anim: String) -> Array:
	var ok0: bool = await _in_manual()
	await tick(stick, ["grab"], ["grab"])
	var anim1: String = sk.anim
	var held_ok: bool = true
	for i: int in 30:
		await tick(Vector2(0.0, _bal_y()), [], ["grab"])
		held_ok = held_ok and sname() == "MANUAL" and sk.anim == want_anim
	var p_held: int = sk.combo.base_sum()
	for i: int in 6:
		await tick(Vector2(0.0, _bal_y()))
	var anim2: String = sk.anim
	var ok: bool = ok0 and anim1 == want_anim and held_ok and anim2 == "manual_manual" and _names().contains(want_name) \
		and sname() == "MANUAL" and bails == 0
	var row: Array = ok_line("flatland_" + want_name.to_lower(), ok,
		"anim %s held %s (want %s), released -> %s (want manual_manual), \"%s\", base %d, bails %d"
		% [anim1, str(held_ok), want_anim, anim2, _names(), p_held, bails])
	await clear()
	return row


func _flip_out() -> Array:
	var ok0: bool = await _in_manual()
	await tick(NONE, ["ollie", "flip"], ["ollie"])
	var st1: String = sname()
	var names: String = _names()
	var landed_clean: bool = false
	for i: int in 90:
		await tick(NONE)
		if not landings.is_empty():
			landed_clean = str(landings[0]) != "bail"
			break
	var ok: bool = ok0 and st1 == "AIR" and names.contains("Kickflip") and bails == 0
	var row: Array = ok_line("manual_flip_out", ok, "state after ollie+flip %s (want AIR), \"%s\" (want Kickflip), landed %s, bails %d"
		% [st1, names, str(landed_clean), bails])
	await clear()
	return row


func run() -> Array:
	var rows: Array = []
	rows.append(await _no_switch())
	rows.append(await _switch())
	rows.append(await _pivot())
	rows.append(await _revert())
	rows.append(await _flatland(NONE, "Casper", "manual_casper"))
	rows.append(await _flatland(Vector2(0.0, -1.0), "Pogo", "manual_pogo"))
	rows.append(await _flip_out())
	return rows
