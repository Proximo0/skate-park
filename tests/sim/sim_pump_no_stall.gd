extends "res://tests/sim/sim_base.gd"
## Holding the stick forward (pump) on a steep wall must never park the skater on it (the old fixed-strength pump
## balanced gravity on a wall of about 55 degrees, so a slow skater hung there). A 55 degree, 5 m bank climbed at
## 7 m/s with the stick held forward for 5 s: the skater must roll back down, not hang, and pumping must not climb a
## flat (uncurved) bank far past what the speed gives.


func run() -> Array:
	var h: float = 5.0
	var run_len: float = h / tan(deg_to_rad(55.0))
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, run_len), Vector2(h, 0.0)])  # (y, z): rises toward -z
	var q := Node3D.new()
	q.add_child(PieceKit.body(PieceKit.extrude_profile(prof, 8.0), PieceKit.RAMP_WOOD, "Bank55"))
	q.position = Vector3(-4.0, 0.0, -run_len - 1.0)
	await sandbox([q])
	place(Vector3(0.0, 0.0, 2.0), Vector3(0, 0, -1), 7.0)
	await host.get_tree().physics_frame
	var parked: int = 0
	var worst: int = 0
	var max_y: float = 0.0
	for i: int in 300:
		await tick(FWD)
		max_y = maxf(max_y, sk.global_position.y)
		if sname() == "ROLLING" and sk.global_position.y > 0.8 and sk.speed < 0.6:
			parked += 1
			worst = maxi(worst, parked)
		else:
			parked = 0
	var detail: String = "climbed to %.2f m (want 0.8-2.5: rolling energy gives 1.4 m, and a flat bank has no curve to pump; bank top 5 m); longest time parked on the wall (y>0.8 m, speed<0.6 m/s) %d ticks (want <= 20), bails %d" % [max_y, worst, bails]
	await clear()
	return [ok_line("pump_no_stall_on_wall", worst <= 20 and max_y > 0.8 and max_y < 2.5, detail)]
