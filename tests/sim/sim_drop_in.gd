extends "res://tests/sim/sim_base.gd"
## Drop-ins in the big park with zero stick: the mega ramp must reach the lip at speed and land the gap; the drop
## ramp must feed the loop fast enough to go round it (this one depends on the skater physics, so it reports).
## Also checks the DROP IN marker pad: standing still on it for a second teleports the skater to the top.


func _pos_str(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


## Drop in at `spot` and ride with no stick until z passes `until_z` (or `seconds`). Returns what happened.
func _ride(park: Park, spot: String, until_z: float, seconds: float, marks: Dictionary) -> Dictionary:
	DropIn.teleport(sk, park.drop_ins[spot])
	var gaps: Array = []
	sk.gap_hit.connect(func(n: String, _p: int) -> void: gaps.append(n))
	var speeds: Dictionary = {}
	var went_air: bool = false
	var t: float = 0.0
	while t < seconds:
		await tick()
		t += DT
		var z: float = sk.global_position.z
		for k: String in marks:
			if not speeds.has(k) and z >= float(marks[k]):
				speeds[k] = sk.velocity.length()
		if sname() == "AIR":
			went_air = true
		if z > until_z:
			break
	return {"gaps": gaps, "speeds": speeds, "air": went_air, "state": sname(), "bails": bails, "pos": sk.global_position, "t": t}


func run() -> Array:
	var rows: Array = []
	var park := Park.new()
	await sandbox([park], false)
	await host.get_tree().physics_frame
	var mz: float = Park.MEGA_POS.z
	var r: Dictionary = await _ride(park, "mega", mz + 70.0, 12.0, {"lip": mz + 48.0})
	var lip: float = r["speeds"].get("lip", 0.0)
	var ok: bool = lip >= 15.0 and r["gaps"].has("Mega Gap") and r["bails"] == 0 and r["pos"].y < 4.0
	rows.append(ok_line("drop_in_mega", ok, "lip speed %.1f m/s (need >= 15), gaps %s (need Mega Gap), bails %d, state %s at %s"
		% [lip, str(r["gaps"]), r["bails"], r["state"], _pos_str(r["pos"])]))
	bails = 0
	var lz: float = park._loop_pos().z
	var r2: Dictionary = await _ride(park, "loop", lz + 16.0, 12.0, {"entry": lz})
	var entry: float = r2["speeds"].get("entry", 0.0)
	var ok2: bool = r2["gaps"].has("Loop De Loop") and r2["bails"] == 0
	# loop success depends on skater physics; entry speed needs about 20 m/s
	rows.append(ok_line("drop_in_loop", ok2, "loop entry speed %.1f m/s (about 20 needed), gaps %s (need Loop De Loop), bails %d, state %s at %s"
		% [entry, str(r2["gaps"]), r2["bails"], r2["state"], _pos_str(r2["pos"])]))
	bails = 0
	# the marker pad: stand still on it for a second and a half
	var pad: DropIn = park.get_node("DropInPad_mega") as DropIn
	place(pad.global_position + Vector3(0.0, 0.1, 0.0), Vector3.BACK, 0.0)
	await host.get_tree().physics_frame
	var teleported: bool = false
	for i: int in 120:
		await tick()
		if sk.global_position.y > 10.0:
			teleported = true
			break
	rows.append(ok_line("drop_in_pad", teleported, "standing still on the mega pad teleports to the deck: %s, now at %s" % [str(teleported), _pos_str(sk.global_position)]))
	await clear()
	return rows
