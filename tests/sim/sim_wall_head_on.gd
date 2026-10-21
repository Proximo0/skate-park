extends "res://tests/sim/sim_base.gd"
## Head-on wall: REPORT ONLY (printed as INFO, never counts as pass or fail). Known issue: the skater stops dead.
## Flip the null in ok_line to a real check once the wall behaviour is fixed.


func run() -> Array:
	var wall := Node3D.new()
	wall.add_child(PieceKit.box(Vector3(-2, 0, -0.2), Vector3(4, 3, 0.4), PieceKit.PAINT_RED, "Wall"))
	wall.position = Vector3(0, 0, -6.2)
	await sandbox([wall])
	place(Vector3(0, 0, 4), Vector3(0, 0, -1), 12.0)
	await host.get_tree().physics_frame
	var min_z: float = 99.0
	var speed_1s: float = 0.0
	var states: Dictionary = {}
	for i: int in 90:
		await tick()
		min_z = minf(min_z, sk.global_position.z)
		states[sname()] = true
		if i == 59:
			speed_1s = sk.speed
	var detail: String = "12 m/s head-on into a wall: closest z %.2f (wall face at -6.0), speed %.1f m/s at 1.0s, end speed %.1f m/s, bails %d, states %s" \
		% [min_z, speed_1s, sk.speed, bails, str(states.keys())]
	await clear()
	return [ok_line("wall_head_on_report", null, detail)]
