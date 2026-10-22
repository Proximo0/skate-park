extends "res://tests/sim/sim_base.gd"
## The skater never clings to steep faces it has no grip on, and the wall grip and peel-off leave roll-ins alone:
##  bank_side    rolling at 4 m/s off the side of a raised bank's deck, next to the end of its coping (the beach
##               BankSandMid hotspot): falls off the side into the air and lands on the ground below; never ROLLING on a
##               near-vertical face (|floor normal y| < 0.15), never gaining energy while rolling
##  dome_roll_in rolling slowly (4 m/s) over the practice dome bowl's rim (the DomeBowl hotspot): the skater follows the
##               wall down to the bottom without peeling off it into the air or bailing, and loses no more energy over the
##               coping than before the grip limit (the coping's own loss, worst 0.25 s window, is ~64% of the start energy
##               and is left as it is: the bot lines are tuned to it)
##  wall_carve   carving along the dome's steep upper wall (normal y 0.2): at 3 m/s there is not enough press for the
##               wheels to hold the line and the skater slides down (over 0.4 m in 0.6 s); at 9 m/s it holds (under 0.25 m)

const BankPiece := preload("res://game/park/pieces/walls.gd")


func _energy() -> float:
	return 0.5 * sk.velocity.length_squared() + 18.0 * sk.global_position.y


func _bank_side() -> Array:
	var pieces: Array = []
	pieces.append(PieceKit.box(Vector3(-40, -2.2, -40), Vector3(80, 1, 80), PieceKit.CONCRETE, "Low"))
	pieces.append(PieceKit.box(Vector3(-10, -1.2, -10), Vector3(30, 1.2, 10), PieceKit.CONCRETE, "Walk"))
	var bank: Node3D = BankPiece.bank(8.0, 4.0, 1.2, "")
	bank.position = Vector3(0, -1.2, 0)
	pieces.append(bank)
	await sandbox(pieces, false)
	place(Vector3(5.5, 0.01, -1.5), Vector3(0.64, 0.0, 0.77), 4.0)
	var clung: int = 0
	var gain: float = 0.0
	var aired: bool = false
	var e_last: float = _energy()
	for i: int in 120:
		await tick()
		var e: float = _energy()
		if sname() == "ROLLING":
			if absf(sk._floor_normal.y) < 0.15:
				clung += 1
			gain = maxf(gain, e - e_last)
		if sname() == "AIR":
			aired = true
		e_last = e
	var ok: bool = clung == 0 and gain < 0.3 and aired and sname() == "ROLLING" and sk.global_position.y < -1.0 and bails == 0
	var row: Array = ok_line("cling_bank_side", ok, "ticks rolling on a near-vertical face %d (want 0), biggest energy gain in a rolling tick %.2f (want < 0.3), went airborne %s, now %s at y %.2f (ground -1.2), bails %d"
		% [clung, gain, str(aired), sname(), sk.global_position.y, bails])
	await clear()
	return row


func _dome_roll_in() -> Array:
	var park := Park.new()
	await sandbox([park], false)
	place(Vector3(49.6, 0.01, -72.54), Vector3(-0.61, 0.0, 0.79), 4.15)
	var es: Array = []
	var start_ref: float = 0.5 * 4.15 * 4.15
	var seen: Dictionary = {"roll_in": false}  # (a lambda captures locals by value: flag through a dictionary)
	var air: bool = false
	sk.physics_ticked.connect(func(f: Dictionary) -> void:
		if (f["events"] as Array).has("roll_in"):
			seen["roll_in"] = true)
	for i: int in 70:
		await tick()
		es.append(_energy())
		if sname() == "AIR" and sk.global_position.y < -0.1:
			air = true
	var worst: float = 0.0
	for i: int in range(15, es.size()):
		worst = maxf(worst, float(es[i - 15]) - float(es[i]))
	var rolled_in: bool = seen["roll_in"]
	var ok: bool = rolled_in and worst < 0.7 * start_ref and bails == 0 and not air and sk.global_position.y < -5.0
	var row: Array = ok_line("cling_dome_roll_in", ok, "rolled in %s, worst 0.25 s energy loss %.1f (%.0f%% of the start's %.1f, want < 70%%), fell off the wall %s, bails %d, now %s at y %.1f (want < -5) %.1f m/s"
		% [str(rolled_in), worst, 100.0 * worst / start_ref, start_ref, str(air), bails, sname(), sk.global_position.y, sk.speed])
	await clear()
	return row


## Puts the skater on the dome's upper wall (a ray from the dome's middle at y -0.6 toward +X) moving along it (+Z).
func _on_dome_wall(spd: float) -> float:
	var park := Park.new()
	await sandbox([park], false)
	await host.get_tree().physics_frame
	var c: Vector3 = Park.DOME_POS + Vector3(9.5, -0.6, 9.5)
	var q := PhysicsRayQueryParameters3D.create(c, c + Vector3.RIGHT * 20.0, 1)
	var hit: Dictionary = sk.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		await clear()
		return -1.0
	var n: Vector3 = hit["normal"]
	var d: Vector3 = Vector3.BACK.slide(n).normalized()
	place((hit["position"] as Vector3) + n * 0.3 - Vector3(0, 0.3, 0), Vector3.BACK, spd)
	sk.velocity = d * spd
	sk.facing = d
	sk.board_up = n
	sk._floor_normal = n
	sk.up_direction = n
	var y0: float = sk.global_position.y
	for i: int in 36:
		await tick()
	var drop: float = y0 - sk.global_position.y
	await clear()
	return drop


func run() -> Array:
	var rows: Array = []
	rows.append(await _bank_side())
	rows.append(await _dome_roll_in())
	var slow: float = await _on_dome_wall(3.0)
	var fast: float = await _on_dome_wall(9.0)
	rows.append(ok_line("cling_wall_carve", slow > 0.4 and fast < 0.25 and fast > -9.0,
		"on the dome's upper wall for 0.6 s: at 3 m/s slid down %.2f m (want > 0.4), at 9 m/s %.2f m (want < 0.25)" % [slow, fast]))
	return rows
