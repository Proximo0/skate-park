extends "res://tests/sim/sim_base.gd"
## In the air, a face too steep to land on is a wall: falling past it (brushing a 77 degree face, normal y 0.23, like a
## bowl's upper wall or a box's leaning side) slides along it and keeps falling. The vertical speed is never zeroed in one
## tick in the air (from below -2 m/s to above -0.5 m/s without a landing), and the skater reaches the ground.

func _run(toward: float) -> Dictionary:
	var wedge: StaticBody3D = PieceKit.box(Vector3(-1.0, 0.0, -5.0), Vector3(1.0, 6.0, 10.0), PieceKit.PAINT_RED, "Steep")
	await sandbox([])
	var pivot := Node3D.new()
	root3.add_child(pivot)
	pivot.rotation = Vector3(0.0, 0.0, deg_to_rad(13.0))  # the +X face leans back: normal (0.97, 0.23, 0)
	pivot.add_child(wedge)
	await host.get_tree().physics_frame
	place(Vector3(-0.45, 3.5, 0.0), Vector3.FORWARD, 0.0)  # the face sits at x = -0.23 y
	sk.velocity = Vector3(-toward, -3.0, -2.0)
	sk.state.event("ollie")
	sk._launch_normal = UPV
	sk._enter_air(false)
	var zeroed: int = 0
	var landed_ok: bool = false
	var last_vy: float = sk.velocity.y
	for i: int in 90:
		await tick()
		var vy: float = sk.velocity.y
		if sname() == "AIR" and last_vy < -2.0 and vy > -0.5:
			zeroed += 1
		last_vy = vy
		if sname() == "ROLLING" and sk.global_position.y < 0.2:
			landed_ok = true
			break
	var res: Dictionary = {"zeroed": zeroed, "landed": landed_ok, "y": sk.global_position.y, "state": sname()}
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	for toward: float in [1.0, 3.0]:
		var r: Dictionary = await _run(toward)
		rows.append(ok_line("air_wall_slide_%d" % int(toward), int(r["zeroed"]) == 0 and bool(r["landed"]),
			"falling past a 77 deg face drifting into it at %.0f m/s: ticks the fall was zeroed in the air %d (want 0), reached the ground rolling %s (now %s at y %.2f)"
			% [toward, int(r["zeroed"]), str(r["landed"]), r["state"], float(r["y"])]))
	return rows
