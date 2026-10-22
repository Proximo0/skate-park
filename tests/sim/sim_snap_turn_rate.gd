extends "res://tests/sim/sim_base.gd"
## The ramp snap's turn is smooth: rolling straight at QuarterNorth and firing Q+E, the skater turns about 180 degrees
## from facing the ramp to facing down it. No tick of the whole snap (hop, hang, stomp) turns the facing more than
## 6 degrees, the turn is complete (facing down the ramp) when the board tips over the coping, and the drop-in rides out.

const ParkScript := preload("res://game/park/park.gd")
const CHORD: Array = ["spin_left", "spin_right"]
const MAX_DEG: float = 6.0


func run() -> Array:
	var park: Node = ParkScript.new()
	park.name = "Park"
	await sandbox([park], false)
	for i: int in 5:
		await tick()
	sk.respawn()
	place(Vector3(1.0, 0.05, -29.0), Vector3.FORWARD, 6.0)
	for i: int in 10:
		await tick()
	var f_prev: Vector3 = sk.facing
	var worst: float = 0.0
	var total: float = 0.0
	var tip_dot: float = -2.0
	var snapped: bool = false
	var ticks: int = 0
	for i: int in 120:
		if i == 0:
			await tick(NONE, CHORD, CHORD)
		elif i == 1:
			await tick(NONE, [], CHORD)
		else:
			await tick()
		var f: Vector3 = Vector3(sk.facing.x, 0.0, sk.facing.z).normalized()
		var fp: Vector3 = Vector3(f_prev.x, 0.0, f_prev.z).normalized()
		if not sk._snap.is_empty():
			snapped = true
			ticks += 1
			var d: float = rad_to_deg(fp.angle_to(f))
			worst = maxf(worst, d)
			total += d
			if str(sk._snap.get("phase", "")) == "tip" and tip_dot < -1.5:
				tip_dot = f.dot(Vector3.BACK)
		elif snapped:
			break
		f_prev = sk.facing
	var r: Array = await _ride_out()
	var ok: bool = snapped and worst <= MAX_DEG and total > 150.0 and tip_dot > 0.97 and bool(r[0])
	var row: Array = ok_line("snap_turn_rate", ok, "snap %s over %d ticks: turned %.0f deg in all, fastest tick %.1f deg (want <= %.0f), facing down the ramp at the tip %.2f (want > 0.97), %s"
		% [str(snapped), ticks, total, worst, MAX_DEG, tip_dot, r[1]])
	await clear()
	return [row]


func _ride_out() -> Array:
	for i: int in 180:
		await tick()
		if sname() == "ROLLING" and sk.global_position.z > -33.0:
			break
	return [bails == 0 and sname() == "ROLLING" and sk.global_position.z > -33.0, "then %s at z %.1f, bails %d" % [sname(), sk.global_position.z, bails]]
