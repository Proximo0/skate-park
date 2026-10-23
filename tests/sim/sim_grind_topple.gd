extends "res://tests/sim/sim_base.gd"
## Grind topple: on a low flat rail at 8 m/s, holding the stick hard to one side tips the balance over that way.
## The skater must step off on that side (no bail), land ROLLING with the combo landed, keep about 85% of the grind
## speed, and carve away toward the fall side. A rail 2.5 m up has no ground in reach, so a topple there is a bail.

const STREET := preload("res://game/park/pieces/street_bits.gd")


## Grinds a flat rail of `height` with the stick held at `stick_x`. Returns what happened after the topple.
func _topple(height: float, stick_x: float) -> Dictionary:
	await sandbox([STREET.flat_rail(30.0, height)])
	var combos: Array = [0]
	sk.combo_landed.connect(func(_p: int, _t: String) -> void: combos[0] += 1)
	var rails: Array = host.get_tree().get_nodes_in_group("grind_rail")
	var rp: Vector3 = (rails[0] as GrindRail).global_points()[0]
	var start_y: float = 0.0 if height < 1.0 else height - 0.3
	place(Vector3(rp.x, start_y, -0.4), Vector3(0, 0, 1), 8.0)
	await host.get_tree().physics_frame
	await tick(NONE, ["grind"], [])
	var grind_speed: float = 0.0
	var toppled: bool = false
	var topple_x: float = 0.0
	var land_tick: int = -1
	var land_speed: float = 0.0
	var states: Dictionary = {}
	var x_after: float = 0.0
	var yaw_turn: float = 0.0
	for i: int in 300:
		var held: bool = sname() == "GRIND"
		await tick(Vector2(stick_x, 0.0) if held else NONE)
		states[sname()] = true
		if sname() == "GRIND":
			grind_speed = sk.velocity.length()
		if (sk.events as Array).has("topple_carve"):
			toppled = true
			topple_x = sk.global_position.x
		for e: String in sk.events:
			if e.begins_with("land:") and toppled and land_tick < 0:
				land_tick = i
				land_speed = Vector3(sk.velocity.x, 0.0, sk.velocity.z).length()
		if land_tick >= 0 and i == land_tick + 30:
			x_after = sk.global_position.x
			yaw_turn = rad_to_deg(atan2(sk.facing.x, sk.facing.z))  ## 0 = along the rail (+z); + = toward +x
			break
		if bails > 0:
			break
	var res: Dictionary = {"toppled": toppled, "bails": bails, "state": sname(), "grind_speed": grind_speed,
		"land_speed": land_speed, "landed": land_tick >= 0, "dx": x_after - rp.x, "yaw": yaw_turn, "combos": combos[0],
		"topple_x": topple_x - rp.x}
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	# Stick right (+1) pushes the balance toward + = the skater's right; travelling +z, the right is -x.
	for side: Array in [["right", 1.0, -1.0], ["left", -1.0, 1.0]]:
		var r: Dictionary = await _topple(0.45, float(side[1]))
		var sgn: float = float(side[2])
		var keep: float = float(r["land_speed"]) / maxf(float(r["grind_speed"]), 0.01)
		var ok: bool = bool(r["toppled"]) and int(r["bails"]) == 0 and bool(r["landed"]) and str(r["state"]) == "ROLLING" \
			and keep >= 0.78 and keep <= 0.95 and float(r["dx"]) * sgn > 0.3 and float(r["yaw"]) * sgn > 20.0 and float(r["yaw"]) * sgn < 60.0 and int(r["combos"]) >= 1
		rows.append(ok_line("grind_topple_carve_%s" % side[0], ok,
			"toppled %s, bails %d, state %s, speed %.1f -> %.1f m/s (%.0f%%, want 78-95), 0.5 s after touchdown %.2f m to the %s side, heading %.0f deg toward it (want 20-60), combos landed %d"
			% [str(r["toppled"]), int(r["bails"]), str(r["state"]), float(r["grind_speed"]), float(r["land_speed"]), keep * 100.0,
				float(r["dx"]) * sgn, side[0], float(r["yaw"]) * sgn, int(r["combos"])]))
	var hi: Dictionary = await _topple(2.5, 1.0)
	rows.append(ok_line("grind_topple_high_rail_bails", int(hi["bails"]) == 1 and not bool(hi["toppled"]),
		"2.5 m rail: bails %d (want 1), topple-carve %s (want false)" % [int(hi["bails"]), str(hi["toppled"])]))
	return rows
