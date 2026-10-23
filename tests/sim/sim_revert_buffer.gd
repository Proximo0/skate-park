extends "res://tests/sim/sim_base.gd"
## Revert timing like THUG: the revert button counts when hit a moment before touchdown (buffered, up to 0.15 s) as
## well as just after it (the 0.35 s window). A press long before the landing is not a revert.
## Each run: tap ollie at 6 m/s on flat, press revert `offset` ticks from the touchdown tick (negative = in the air).


func _attempt(offset: int, land_tick: int) -> Dictionary:
	await sandbox([])
	place(Vector3(0, 0, 0), Vector3(0, 0, -1), 6.0)
	await host.get_tree().physics_frame
	var reverts: Array = []
	sk.trick_started.connect(func(t: Dictionary) -> void:
		if str(t.get("id", "")) == "revert":
			reverts.append(true))
	await tick(NONE, ["ollie"], ["ollie"])
	var landed_at: int = -1
	for i: int in 90:
		var jp: Array = ["revert"] if land_tick >= 0 and i == land_tick + offset else []
		await tick(NONE, jp, jp)
		if landed_at < 0 and sk.events.has("land:clean"):
			landed_at = i
	var res: Dictionary = {"reverts": reverts.size(), "land": landed_at, "bails": bails}
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	var probe: Dictionary = await _attempt(0, -1)
	var lt: int = int(probe["land"])
	if lt < 0:
		return [ok_line("revert_buffer", false, "the tap ollie never landed clean")]
	for off: int in [-8, -3, 0, 6, -25]:
		var r: Dictionary = await _attempt(off, lt)
		var want: int = 0 if off < -9 else 1
		rows.append(ok_line("revert_press_%+d_ticks" % off, int(r["reverts"]) == want and int(r["bails"]) == 0,
			"revert pressed %d ticks from touchdown: %d reverts (want %d), bails %d" % [off, int(r["reverts"]), want, int(r["bails"])]))
	return rows
