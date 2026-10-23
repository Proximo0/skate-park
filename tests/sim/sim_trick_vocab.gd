extends "res://tests/sim/sim_base.gd"
## Round-7 trick vocabulary (THUG2): the double-tap grinds, the eight lip tricks and ledge stalls, all from data.
##  grind_double_catch    grind tapped twice on the way to a rail (stick S) catches it with the double-tap grind of that
##                        dir (Salad Grind), not the single one (5-0)
##  grind_double_switch   on a 50-50, stick N + grind tapped twice switches to the Overcrook in place (still grinding)
##  lip_invert            stick NE + grind at a quarter pipe's coping holds an Invert (the old table had no NE lip trick
##                        and fell back to a Nose Stall)
##  lip_double_tap        grind tapped twice (stick N) at the coping: Nose Pick, the double-tap lip trick
##  ledge_stall           popped onto a ledge slow and square to it, grind stalls on its edge (LIP, a Nose Stall), ollie
##                        drops back off the side it came from and rides away (no bail)
##  ledge_stall_no_invert stick NE at a ledge: only the ledge stalls are allowed there, so a Nose Stall, not an Invert
##  ledge_along_grinds    rolling along the same ledge and pressing grind still grinds it (a stall needs a square hop)
## Round 11 trick depth:
##  grab_grind_hold       on a 50-50, stick E + grab held: "Indy 50-50" scored, the grab posed on the rail, its points per
##                        second on top of the grind's; let go: the grab ends, still grinding
##  grab_grind_tap_pops   grab tapped on the rail and the ollie right after: no grab grind, the Indy is the air grab
##  flip_out_on_rail      flip pressed on the rail, then the ollie: "Kickflip Out" (with the grind_out bonus), lands clean
##  flip_out_after_pop    flip pressed 0.15 s after the pop off the rail is still the out; 0.6 s after it is a plain flip
##  lip_hand_plant        stick NE + grind tapped twice at the coping: the Andrecht Invert, held, then dropped back in clean
##  lip_upright           every coping lip trick stands the rider up on the lip (board frame world up, facing out over the
##                        ramp), not laid out flat over it in the wall's frame

const STREET := preload("res://game/park/pieces/street_bits.gd")
const QP := preload("res://game/park/pieces/quarterpipe.gd")
const K1: float = 3.0
const K2: float = 1.1


func _bal_x() -> float:
	return -clampf(K1 * sk.balance.angle + K2 * sk.balance.velocity, -1.0, 1.0)


func _names() -> String:
	return str(sk.combo.display_text())


func _grind_double_catch() -> Array:
	await sandbox([STREET.flat_rail(30.0, 0.45)])
	var rp: Vector3 = (host.get_tree().get_nodes_in_group("grind_rail")[0] as GrindRail).global_points()[0]
	place(Vector3(rp.x, 0.0, rp.z - 1.6), Vector3(0, 0, 1), 8.0)
	await host.get_tree().physics_frame
	var down := Vector2(0.0, 1.0)
	await tick(down, ["grind"], [])
	var early: String = sname()
	await tick(down)
	await tick(down, ["grind"], [])
	for i: int in 10:
		if sname() == "GRIND":
			break
		await tick(down)
	var anim: String = sk.anim
	var names: String = _names()
	var ok: bool = early != "GRIND" and sname() == "GRIND" and anim == "grind_salad_grind" and names.contains("Salad Grind") \
		and not names.contains("5-0")
	var row: Array = ok_line("grind_double_catch", ok, "first tap state %s (want not yet grinding), now %s, anim %s (want grind_salad_grind), \"%s\""
		% [early, sname(), anim, names])
	await clear()
	return row


func _grind_double_switch() -> Array:
	await sandbox([STREET.flat_rail(30.0, 0.45)])
	var rp: Vector3 = (host.get_tree().get_nodes_in_group("grind_rail")[0] as GrindRail).global_points()[0]
	place(Vector3(rp.x, 0.0, rp.z - 0.4), Vector3(0, 0, 1), 8.0)
	await host.get_tree().physics_frame
	await tick(NONE, ["grind"], [])
	for i: int in 30:
		await tick(Vector2(_bal_x(), 0.0))
	var st0: String = sname()
	var up := Vector2(0.0, -1.0)
	await tick(up, ["grind"], [])
	await tick(up)
	await tick(up, ["grind"], [])
	var anim: String = sk.anim
	var still: bool = true
	for i: int in 20:
		await tick(Vector2(_bal_x(), 0.0))
		still = still and sname() == "GRIND"
	var names: String = _names()
	var ok: bool = st0 == "GRIND" and still and anim == "grind_overcrook" and names.contains("Overcrook") and bails == 0
	var row: Array = ok_line("grind_double_switch", ok, "grinding %s, still grinding %s, anim %s (want grind_overcrook), \"%s\", bails %d"
		% [st0, str(still), anim, names, bails])
	await clear()
	return row


## Up a 4 m quarter pipe at 14 m/s, grind pressed (as `taps`, ticks apart) near the coping with `stick` held.
func _lip_with(stick: Vector2, double: bool) -> Dictionary:
	await sandbox([QP.build(10.0, 3.5, 4.0, 1.5)])
	place(Vector3(5.0, 0.0, 6.8), Vector3(0, 0, -1), 14.0)
	await host.get_tree().physics_frame
	var first: int = -1
	for i: int in 200:
		var near: bool = sname() == "AIR" and sk.vert_air and sk.global_position.y > 3.0
		var press: bool = false
		if near and first < 0:
			first = i
			press = true
		elif first >= 0 and double and i == first + 2:
			press = true
		await tick(stick if near else NONE, ["grind"] if press else [], [])
		if sname() == "LIP" and (not double or i >= first + 2):
			break
	var d: Dictionary = {"st": sname(), "anim": sk.anim, "names": _names()}
	await clear()
	return d


func _lip_rows() -> Array:
	var inv: Dictionary = await _lip_with(Vector2(0.7, -0.7), false)
	var pick: Dictionary = await _lip_with(Vector2(0.0, -1.0), true)
	return [
		ok_line("lip_invert", inv["st"] == "LIP" and str(inv["anim"]) == "lip_invert" and str(inv["names"]).contains("Invert"),
			"state %s, anim %s (want lip_invert), \"%s\"" % [inv["st"], inv["anim"], inv["names"]]),
		ok_line("lip_double_tap", pick["st"] == "LIP" and str(pick["anim"]) == "lip_nose_pick" and str(pick["names"]).contains("Nose Pick"),
			"state %s, anim %s (want lip_nose_pick), \"%s\"" % [pick["st"], pick["anim"], pick["names"]]),
	]


## An 8 m ledge along z (top edges at x 0 and 0.8, 0.5 m up); the skater rolls at it square from x -3 at `v0`, ollies
## and presses grind with `stick` near the edge, then holds the stall a moment and ollies out. Runs to the landing.
func _ledge_square(stick: Vector2, v0: float) -> Dictionary:
	await sandbox([STREET.ledge(8.0, 0.5, 0.8)])
	place(Vector3(-3.0, 0.0, 4.0), Vector3(1, 0, 0), v0)
	await host.get_tree().physics_frame
	for i: int in 4:
		await tick()
	var popped: bool = false
	var st_hold: String = ""
	for i: int in 120:
		var x: float = sk.global_position.x
		if not popped and x > -1.6:
			popped = true
			await tick(NONE, ["ollie"], ["ollie"])
			continue
		await tick(stick if popped and sname() == "AIR" else NONE, ["grind"] if popped and sname() == "AIR" else [], [])
		if sname() == "LIP":
			break
	var anim: String = sk.anim
	var names: String = _names()
	var events_seen: bool = false
	for i: int in 20:
		await tick(Vector2(_bal_x(), 0.0))
	st_hold = sname()
	await tick(NONE, ["ollie"], ["ollie"])
	var land: String = ""
	for i: int in 120:
		await tick()
		if not landings.is_empty():
			land = str(landings[0])
			break
	for i: int in 20:
		await tick()
	var d: Dictionary = {"anim": anim, "names": names, "hold": st_hold, "land": land, "after": sname(), "bails": bails,
		"x": sk.global_position.x, "ev": events_seen}
	await clear()
	return d


func _ledge_rows() -> Array:
	var st: Dictionary = await _ledge_square(NONE, 3.0)
	var ne: Dictionary = await _ledge_square(Vector2(0.7, -0.7), 3.0)
	var ok: bool = str(st["anim"]) == "lip_nose_stall" and str(st["names"]).contains("Nose Stall") and st["hold"] == "LIP" \
		and str(st["land"]) != "bail" and str(st["land"]) != "" and st["after"] == "ROLLING" and int(st["bails"]) == 0 \
		and float(st["x"]) < 0.0
	return [
		ok_line("ledge_stall", ok, "anim %s (want lip_nose_stall), \"%s\", held %s 1/3 s (want LIP), ollie out landed %s -> %s at x %.2f (want back off the near side, x < 0), bails %d"
			% [st["anim"], st["names"], st["hold"], st["land"], st["after"], float(st["x"]), int(st["bails"])]),
		ok_line("ledge_stall_no_invert", str(ne["anim"]) == "lip_nose_stall" and not str(ne["names"]).contains("Invert"),
			"stick NE at a ledge: anim %s (want lip_nose_stall, no invert on a ledge), \"%s\"" % [ne["anim"], ne["names"]]),
	]


func _ledge_along() -> Array:
	await sandbox([STREET.ledge(12.0, 0.5, 0.8)])
	place(Vector3(-0.35, 0.0, -1.0), Vector3(0, 0, 1), 7.0)
	await host.get_tree().physics_frame
	for i: int in 3:
		await tick()
	await tick(NONE, ["ollie"], ["ollie"])
	var st: String = ""
	for i: int in 60:
		await tick(NONE, ["grind"] if i % 3 == 0 else [], [])
		if sname() == "GRIND" or sname() == "LIP":
			st = sname()
			break
	var row: Array = ok_line("ledge_along_grinds", st == "GRIND", "rolling along a ledge, grind -> %s (want GRIND), \"%s\"" % [st, _names()])
	await clear()
	return row


## A 50-50 on a flat rail, balanced for 30 ticks; returns once grinding.
func _on_rail() -> void:
	await sandbox([STREET.flat_rail(30.0, 0.45)])
	var rp: Vector3 = (host.get_tree().get_nodes_in_group("grind_rail")[0] as GrindRail).global_points()[0]
	place(Vector3(rp.x, 0.0, rp.z - 0.4), Vector3(0, 0, 1), 8.0)
	await host.get_tree().physics_frame
	await tick(NONE, ["grind"], [])
	for i: int in 30:
		await tick(Vector2(_bal_x(), 0.0))


func _grab_grind_rows() -> Array:
	await _on_rail()
	var st0: String = sname()
	var pps0: int = sk._hold_pps
	await tick(Vector2(1.0, 0.0), ["grab"], ["grab"])
	var posed_at_once: String = sk.grind_grab_anim
	for i: int in 20:
		await tick(Vector2(_bal_x(), 0.0), [], ["grab"])
	var held_names: String = _names()
	var gg: String = sk.grind_grab_anim
	var pps1: int = sk._hold_pps
	var anim1: String = sk.anim
	await tick(Vector2(_bal_x(), 0.0))
	var after: String = sk.grind_grab_anim
	var st1: String = sname()
	var pps2: int = sk._hold_pps
	var ok: bool = st0 == "GRIND" and posed_at_once == "grab_indy" and held_names.contains("Indy 50-50") and gg == "grab_indy" \
		and pps1 > pps0 and anim1 == "grind_fifty_fifty" and after == "" and st1 == "GRIND" and pps2 == pps0
	var row1: Array = ok_line("grab_grind_hold", ok, "grinding %s, posed at once %s, \"%s\", grab %s, pps %d -> %d -> %d, anim %s, let go: grab \"%s\" %s"
		% [st0, posed_at_once, held_names, gg, pps0, pps1, pps2, anim1, after, st1])
	await clear()
	await _on_rail()
	await tick(Vector2(1.0, 0.0), ["grab"], ["grab"])
	await tick(Vector2(_bal_x(), 0.0))
	await tick(Vector2(_bal_x(), 0.0), ["ollie"], ["ollie"])
	await tick(NONE)
	for i: int in 3:
		await tick(NONE, [], ["grab"])
	var tap_names: String = _names()
	var ok2: bool = sname() == "AIR" and tap_names.contains("Indy") and not tap_names.contains("Indy 50-50")
	var row2: Array = ok_line("grab_grind_tap_pops", ok2, "state %s (want AIR), \"%s\" (want the air Indy, no Indy 50-50)" % [sname(), tap_names])
	await clear()
	return [row1, row2]


## On a rail; flip pressed `flip_at` ticks from the ollie (negative: on the rail before it); runs to the landing.
func _flip_out_with(flip_at: int) -> Dictionary:
	await _on_rail()
	if flip_at < 0:
		await tick(Vector2(_bal_x(), 0.0), ["flip"], [])
		for i: int in -flip_at - 1:
			await tick(Vector2(_bal_x(), 0.0))
	await tick(Vector2(_bal_x(), 0.0), ["ollie"], ["ollie"])
	var land: String = ""
	for i: int in 160:
		await tick(NONE, ["flip"] if flip_at > 0 and i == flip_at - 1 else [], [])
		if not landings.is_empty():
			land = str(landings[0])
			break
	var d: Dictionary = {"names": _names(), "land": land, "bails": bails, "base": sk.combo.landed_total}
	await clear()
	return d


func _flip_out_rows() -> Array:
	var on: Dictionary = await _flip_out_with(-3)
	var late: Dictionary = await _flip_out_with(9)
	var too_late: Dictionary = await _flip_out_with(36)
	var ok1: bool = str(on["names"]).contains("Kickflip Out") and str(on["land"]) != "bail" and str(on["land"]) != "" \
		and int(on["bails"]) == 0
	var ok2: bool = str(late["names"]).contains("Kickflip Out") and str(too_late["names"]).contains("Kickflip") \
		and not str(too_late["names"]).contains("Out")
	return [
		ok_line("flip_out_on_rail", ok1, "\"%s\" landed %s, bails %d" % [on["names"], on["land"], int(on["bails"])]),
		ok_line("flip_out_after_pop", ok2, "0.15 s after: \"%s\" (want Kickflip Out), 0.6 s after: \"%s\" (want a plain Kickflip)"
			% [late["names"], too_late["names"]]),
	]


## Up the quarter pipe, grind tapped twice with stick NE at the coping (the Andrecht), held 30 ticks, ollie back in.
func _hand_plant() -> Dictionary:
	await sandbox([QP.build(10.0, 3.5, 4.0, 1.5)])
	place(Vector3(5.0, 0.0, 6.8), Vector3(0, 0, -1), 14.0)
	await host.get_tree().physics_frame
	var first: int = -1
	var ne := Vector2(0.7, -0.7)
	for i: int in 200:
		var near: bool = sname() == "AIR" and sk.vert_air and sk.global_position.y > 3.0
		var press: bool = (near and first < 0) or (first >= 0 and i == first + 2)
		if near and first < 0:
			first = i
		await tick(ne if near or sname() == "LIP" else NONE, ["grind"] if press else [], [])
		if sname() == "LIP" and first >= 0 and i >= first + 2:
			break
	for i: int in 12:
		await tick(Vector2(_bal_x(), 0.0))
	var d: Dictionary = {"st": sname(), "anim": sk.anim, "names": _names(), "up": sk.board_up, "facing": sk.facing}
	for i: int in 18:
		await tick(Vector2(_bal_x(), 0.0))
	await tick(NONE, ["ollie"], ["ollie"])
	var land: String = ""
	for i: int in 200:
		await tick()
		if not landings.is_empty():
			land = str(landings[0])
			break
	d["land"] = land
	d["bails"] = bails
	await clear()
	return d


func _hand_plant_rows() -> Array:
	var d: Dictionary = await _hand_plant()
	var up: Vector3 = d["up"]
	var fc: Vector3 = d["facing"]
	var ok: bool = d["st"] == "LIP" and str(d["anim"]) == "lip_andrecht" and str(d["names"]).contains("Andrecht Invert") \
		and str(d["land"]) != "" and str(d["land"]) != "bail" and int(d["bails"]) == 0
	var upright: bool = up.y > 0.97 and absf(fc.y) < 0.05 and fc.z > 0.9
	return [
		ok_line("lip_hand_plant", ok, "state %s, anim %s (want lip_andrecht), \"%s\", dropped in: %s, bails %d"
			% [d["st"], d["anim"], d["names"], d["land"], int(d["bails"])]),
		ok_line("lip_upright", upright, "board up %s (want world up), facing %s (want out over the ramp, +z)" % [str(up), str(fc)]),
	]


func run() -> Array:
	var rows: Array = []
	rows.append_array(await _grab_grind_rows())
	rows.append_array(await _flip_out_rows())
	rows.append_array(await _hand_plant_rows())
	rows.append(await _grind_double_catch())
	rows.append(await _grind_double_switch())
	rows.append_array(await _lip_rows())
	rows.append_array(await _ledge_rows())
	rows.append(await _ledge_along())
	return rows
