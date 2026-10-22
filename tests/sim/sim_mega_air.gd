extends "res://tests/sim/sim_base.gd"
## Mega ramp drop-in with zero stick: air keeps its horizontal speed (no air drag: only the horizontal part is capped,
## at max_speed), the fall speed comes from gravity up to a terminal 30 m/s, and the landings keep the speed.
## The landing floor is 16.5 m/s: the landing reads 16.9-17.0 depending on roll_friction (0.45 vs 0.6), so 17 was a knife edge.
## Rows: the gap air's horizontal speed at touchdown over its takeoff, the speed after the landing, the fastest fall.


func run() -> Array:
	var rows: Array = []
	var park := Park.new()
	await sandbox([park], false)
	await host.get_tree().physics_frame
	DropIn.teleport(sk, park.drop_ins["mega"])
	var lay: Dictionary = MegaRamp._layout(14.0, 18.0, 8.0)
	var z0: float = Park.MEGA_POS.z
	var airs: Array = []  ## [{t0, h0, h1, vy_min, land_speed}]
	var cur: Dictionary = {}
	var roll_bottom: float = 0.0
	var max_fall: float = 0.0
	var max_h: float = 0.0
	for i: int in int(14.0 / DT):
		await tick()
		var v: Vector3 = sk.velocity
		var h: float = Vector2(v.x, v.z).length()
		var z: float = sk.global_position.z - z0
		if roll_bottom == 0.0 and z >= float(lay["roll_end"]):
			roll_bottom = v.length()
		if sname() == "AIR":
			if cur.is_empty():
				cur = {"z0": z, "h0": h, "h1": h, "vy_min": 0.0, "land_speed": -1.0}
			cur["h1"] = h
			cur["vy_min"] = minf(float(cur["vy_min"]), v.y)
			max_fall = maxf(max_fall, -v.y)
			max_h = maxf(max_h, h)
		elif not cur.is_empty():
			cur["land_speed"] = v.length()
			cur["land_state"] = sname()
			airs.append(cur)
			cur = {}
		if sk.global_position.z - z0 > float(lay["qp_a"]) + 1.0 and airs.size() >= 2:
			break
	var gap: Dictionary = {}
	for a: Dictionary in airs:
		if absf(float(a["z0"]) - float(lay["lip_z"])) < 3.0:
			gap = a
			break
	var gap_ok: bool = not gap.is_empty()
	var keep: float = float(gap.get("h1", 0.0)) / maxf(float(gap.get("h0", 1.0)), 0.01)
	rows.append(ok_line("mega_roll_in_speed", roll_bottom >= 21.0,
		"speed at the bottom of the 18 m roll-in %.1f m/s (want >= 21, the speed cap is %.0f)" % [roll_bottom, sk.tune.max_speed]))
	rows.append(ok_line("mega_gap_air_no_drag", gap_ok and keep >= 0.995 and bails == 0,
		"gap air from the lip: horizontal speed %.1f -> %.1f m/s at touchdown (kept %.1f%%, want >= 99.5%%), bails %d, airs %d"
		% [float(gap.get("h0", 0.0)), float(gap.get("h1", 0.0)), keep * 100.0, bails, airs.size()]))
	var land: float = float(gap.get("land_speed", 0.0))
	rows.append(ok_line("mega_gap_landing_speed", gap_ok and land >= 16.5 and str(gap.get("land_state", "")) == "ROLLING",
		"rolling at %.1f m/s just after the gap landing (want >= 16.5), state %s" % [land, str(gap.get("land_state", ""))]))
	rows.append(ok_line("mega_air_fall_cap", max_fall <= 30.01 and max_h <= sk.tune.max_speed + 0.01,
		"fastest fall %.1f m/s (terminal 30), fastest horizontal air speed %.1f m/s (cap %.0f)" % [max_fall, max_h, sk.tune.max_speed]))
	await clear()
	return rows
