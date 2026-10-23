extends "res://tests/sim/sim_base.gd"
## Ways out of a wallride and a lip trick that keep the combo going (THUG2).
##  wallride_flip_out  flip pressed on the wall pops off it (a wallie) with the flip: Wallride + Wallie + Kickflip
##  wallride_grab_out  grab pressed on the wall: Wallie + Melon, the grab held in the air
##  wallride_revert    revert on the wall pushes off it with the stance switched and a Revert scored
##  wall_to_rail       wallie off the wall onto a rail beside it: the combo carries a "Wall to Rail" link
##  lip_flip_out       flip in a lip trick pops out over the ramp with the flip; it lands clean back in the ramp
##  lip_revert_out     revert in a lip trick drops back in and reverts at the touchdown (Revert scored, stance switched)

const QP := preload("res://game/park/pieces/quarterpipe.gd")
const K1: float = 3.0
const K2: float = 1.1


func _bal_x() -> float:
	return -clampf(K1 * sk.balance.angle + K2 * sk.balance.velocity, -1.0, 1.0)


func _names() -> String:
	return str(sk.combo.display_text())


## The lab's wallride set-up (tests/lab/lab_moves.gd m_wallride), plus `extra` pieces. True once on the wall.
func _on_wall(extra: Array = []) -> bool:
	var wall := Node3D.new()
	wall.add_child(PieceKit.box(Vector3(-30, 0, -0.2), Vector3(60, 5, 0.4), PieceKit.PAINT_RED, "Wall"))
	wall.position = Vector3(0, 0, -4.0)
	var pieces: Array = [wall]
	pieces.append_array(extra)
	await sandbox(pieces)
	var th: float = deg_to_rad(25.0)
	place(Vector3(-15.0, 0.0, -1.5), Vector3(cos(th), 0.0, -sin(th)), 8.0)
	await host.get_tree().physics_frame
	for i: int in 3:
		await tick()
	for i: int in 20:
		await tick(NONE, ["ollie"] if i == 0 else [], ["ollie"])
	for i: int in 120:
		await tick(NONE, ["grind"] if i % 4 == 0 else [], [])
		if sname() == "WALLRIDE":
			break
	return sname() == "WALLRIDE"


## Runs to the touchdown (or 3 s). Returns the first landing result, "" if none.
func _to_landing() -> String:
	for i: int in 180:
		await tick(NONE)
		if not landings.is_empty():
			return str(landings[0])
		if bails > 0:
			return "bail"
	return ""


func _wall_out(button: String, want: String) -> Array:
	var on: bool = await _on_wall()
	for i: int in 6:
		await tick()
	await tick(NONE, [button], [button])
	var st: String = sname()
	var names: String = _names()
	var held: Array = [button] if button == "grab" else []
	for i: int in 10:
		await tick(NONE, [], held)
	var land: String = await _to_landing()
	var ok: bool = on and st == "AIR" and names.contains("Wallie") and names.contains(want) and land != "bail" and land != "" and bails == 0
	var row: Array = ok_line("wallride_%s_out" % button, ok, "on the wall %s, %s -> %s (want AIR), \"%s\" (want Wallie + %s), landed %s, bails %d"
		% [str(on), button, st, names, want, land, bails])
	await clear()
	return row


func _wall_revert() -> Array:
	var on: bool = await _on_wall()
	for i: int in 6:
		await tick()
	var sw0: bool = sk.switch_stance
	await tick(NONE, ["revert"], ["revert"])
	var st: String = sname()
	var names: String = _names()
	var land: String = await _to_landing()
	var ok: bool = on and st == "AIR" and sk.switch_stance != sw0 and names.contains("Revert") and land != "bail" and land != "" and bails == 0
	var row: Array = ok_line("wallride_revert", ok, "on the wall %s, revert -> %s (want AIR), switch %s -> %s, \"%s\", landed %s, bails %d"
		% [str(on), st, str(sw0), str(sk.switch_stance), names, land, bails])
	await clear()
	return row


func _wall_to_rail() -> Array:
	var rail: GrindRail = PieceKit.rail(PackedVector3Array([Vector3(-9.0, 3.5, -2.0), Vector3(20.0, 3.5, -2.0)]), "rail", "WallRail")  ## a rail up beside the wall, where the wallie peaks
	var on: bool = await _on_wall([rail])
	for i: int in 4:
		await tick()
	await tick(NONE, ["ollie"], ["ollie"])
	var ground: bool = false
	for i: int in 60:
		await tick(NONE, ["grind"] if i % 3 == 0 else [], [])
		if sname() == "GRIND" or sname() == "ROLLING":
			ground = sname() == "ROLLING"
			break
	var st: String = sname()
	var names: String = _names()
	var ok: bool = on and st == "GRIND" and names.contains("Wall to Rail") and bails == 0
	var row: Array = ok_line("wall_to_rail", ok, "on the wall %s, after the wallie %s (want GRIND, rolled %s), \"%s\" (want Wall to Rail), bails %d"
		% [str(on), st, str(ground), names, bails])
	await clear()
	return row


## Up a 4 m quarter pipe at 14 m/s and into a lip trick on its coping. True once in LIP.
func _on_lip() -> bool:
	await sandbox([QP.build(10.0, 3.5, 4.0, 1.5)])
	place(Vector3(5.0, 0.0, 6.8), Vector3(0, 0, -1), 14.0)
	await host.get_tree().physics_frame
	for i: int in 200:
		var near: bool = sname() == "AIR" and sk.vert_air and sk.global_position.y > 3.6
		await tick(NONE, ["grind"] if near else [], [])
		if sname() == "LIP":
			break
	return sname() == "LIP"


## Kickflip out of a nose stall: the air time from the pop to the touchdown (the lab's lip_pop_flip_margin_s).
func lip_flip_data() -> Dictionary:
	var on: bool = await _on_lip()
	for i: int in 20:
		await tick(Vector2(_bal_x(), 0.0))
	await tick(NONE, ["flip"], [])
	var st: String = sname()
	var names: String = _names()
	var t0: int = sk._tick_count
	var land: String = await _to_landing()
	var air: float = float(sk._tick_count - t0) * DT
	var d: Dictionary = {"on": on, "st": st, "names": names, "land": land, "st2": sname(), "air": air, "bails": bails}
	await clear()
	return d


func _lip_flip() -> Array:
	var d: Dictionary = await lip_flip_data()
	var on: bool = d["on"]
	var st: String = d["st"]
	var names: String = d["names"]
	var land: String = d["land"]
	var st2: String = d["st2"]
	bails = int(d["bails"])
	var ok: bool = on and st == "AIR" and names.contains("Kickflip") and land == "clean" and st2 == "ROLLING" and bails == 0
	return ok_line("lip_flip_out", ok, "lip %s, flip -> %s (want AIR), \"%s\" (want lip trick + Kickflip), landed %s -> %s after %.2f s (want clean, ROLLING), bails %d"
		% [str(on), st, names, land, st2, float(d["air"]), bails])


func _lip_revert() -> Array:
	var on: bool = await _on_lip()
	for i: int in 20:
		await tick(Vector2(_bal_x(), 0.0))
	var sw0: bool = sk.switch_stance
	await tick(NONE, ["revert"], ["revert"])
	var st: String = sname()
	var land: String = await _to_landing()
	await tick(NONE)
	var names: String = _names()
	var ok: bool = on and st == "AIR" and land != "bail" and land != "" and names.contains("Revert") and sk.switch_stance != sw0 \
		and sname() == "ROLLING" and bails == 0
	var row: Array = ok_line("lip_revert_out", ok, "lip %s, revert -> %s (want AIR), landed %s, \"%s\" (want lip trick + Revert), switch %s -> %s, bails %d"
		% [str(on), st, land, names, str(sw0), str(sk.switch_stance), bails])
	await clear()
	return row


func run() -> Array:
	var rows: Array = []
	rows.append(await _wall_out("flip", "Kickflip"))
	rows.append(await _wall_out("grab", "Melon"))
	rows.append(await _wall_revert())
	rows.append(await _wall_to_rail())
	rows.append(await _lip_flip())
	rows.append(await _lip_revert())
	return rows
