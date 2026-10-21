extends "res://tests/sim/sim_base.gd"
## Head-on wall: at 7 m/s square into a 3 m wall the skater stumbles and bounces back off it with 20-30% of the speed
## (no bail, no dead stop); at 12 m/s (over the 9 m/s slam limit) it is a bail.


## Rolls square into the wall at `v0`. Returns {bails, back (m/s away from the wall), events, min_z}.
func _hit(v0: float) -> Dictionary:
	var wall := Node3D.new()
	wall.add_child(PieceKit.box(Vector3(-2, 0, -0.2), Vector3(4, 3, 0.4), PieceKit.PAINT_RED, "Wall"))
	wall.position = Vector3(0, 0, -6.2)
	await sandbox([wall])
	place(Vector3(0, 0, -6.0 + 0.3 + v0 * 0.5), Vector3(0, 0, -1), v0)
	await host.get_tree().physics_frame
	var back: float = 0.0
	var evs: Dictionary = {}
	var min_z: float = 99.0
	for i: int in 60:
		await tick()
		min_z = minf(min_z, sk.global_position.z)
		for e: String in sk.events:
			evs[e] = true
		back = maxf(back, sk.velocity.z)
	var res: Dictionary = {"bails": bails, "back": back, "events": evs.keys(), "min_z": min_z, "state": sname()}
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	var a: Dictionary = await _hit(7.0)
	var frac: float = float(a["back"]) / 7.0
	rows.append(ok_line("wall_head_on_stumble_7ms", int(a["bails"]) == 0 and frac >= 0.18 and frac <= 0.32 and (a["events"] as Array).has("stumble"),
		"7 m/s square into a wall: bounced back at %.1f m/s (%.0f%% of the impact, want 18-32%%), bails %d (want 0), events %s, state %s"
		% [float(a["back"]), frac * 100.0, int(a["bails"]), str(a["events"]), str(a["state"])]))
	var b: Dictionary = await _hit(12.0)
	rows.append(ok_line("wall_head_on_slam_12ms", int(b["bails"]) == 1 and (b["events"] as Array).has("wall_slam"),
		"12 m/s square into a wall: bails %d (want 1), events %s, closest z %.2f, state %s" % [int(b["bails"]), str(b["events"]), float(b["min_z"]), str(b["state"])]))
	return rows
