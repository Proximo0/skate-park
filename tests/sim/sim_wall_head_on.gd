extends "res://tests/sim/sim_base.gd"
## Head-on wall: at 7 m/s square into a 3 m wall the skater stumbles and bounces back off it with 20-30% of the speed
## (no bail, no dead stop); at 11 m/s it still stumbles, bouncing back harder (a bigger share of the speed); only at
## 14 m/s truly square-on (over the 13 m/s slam limit) is it a bail, and 14 m/s at 20 degrees off square bounces.


## Rolls square into the wall at `v0`. Returns {bails, back (m/s away from the wall), events, min_z}.
func _hit(v0: float, off_deg: float = 0.0) -> Dictionary:
	var wall := Node3D.new()
	wall.add_child(PieceKit.box(Vector3(-2, 0, -0.2), Vector3(4, 3, 0.4), PieceKit.PAINT_RED, "Wall"))
	wall.position = Vector3(0, 0, -6.2)
	await sandbox([wall])
	var th: float = deg_to_rad(off_deg)
	var d := Vector3(-sin(th), 0.0, -cos(th))
	place(Vector3(0, 0, -6.0 + 0.3) - d * v0 * 0.5, d, v0)
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
	var m: Dictionary = await _hit(11.0)
	var mfrac: float = float(m["back"]) / 11.0
	rows.append(ok_line("wall_head_on_stumble_11ms", int(m["bails"]) == 0 and mfrac > frac and mfrac <= 0.4 and (m["events"] as Array).has("stumble"),
		"11 m/s square into a wall: bounced back at %.1f m/s (%.0f%%, want more than at 7 m/s and <= 40%%), bails %d (want 0), events %s"
		% [float(m["back"]), mfrac * 100.0, int(m["bails"]), str(m["events"])]))
	var b: Dictionary = await _hit(14.0)
	rows.append(ok_line("wall_head_on_slam_14ms", int(b["bails"]) == 1 and (b["events"] as Array).has("wall_slam"),
		"14 m/s square into a wall: bails %d (want 1), events %s, closest z %.2f, state %s" % [int(b["bails"]), str(b["events"]), float(b["min_z"]), str(b["state"])]))
	var g: Dictionary = await _hit(14.0, 20.0)
	rows.append(ok_line("wall_off_square_14ms_no_bail", int(g["bails"]) == 0,
		"14 m/s into a wall 20 degrees off square: bails %d (want 0, only square-on hits slam), events %s, state %s" % [int(g["bails"]), str(g["events"]), str(g["state"])]))
	return rows
