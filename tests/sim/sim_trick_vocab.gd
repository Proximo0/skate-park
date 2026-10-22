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


func run() -> Array:
	var rows: Array = []
	rows.append(await _grind_double_catch())
	rows.append(await _grind_double_switch())
	rows.append_array(await _lip_rows())
	rows.append_array(await _ledge_rows())
	rows.append(await _ledge_along())
	return rows
