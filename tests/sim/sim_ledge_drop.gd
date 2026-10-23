extends "res://tests/sim/sim_base.gd"
## Ledge drops of 0.3 / 0.5 / 0.8 / 1.2 m at about 5 m/s: the skater goes AIR, lands, keeps rolling (no stuck ticks).

const HEIGHTS: Array = [0.3, 0.5, 0.8, 1.2]
const SPEED: float = 5.0


func _drop(h: float) -> Dictionary:
	var hi: Node3D = PieceKit.box(Vector3(-40, h - 1.0, -40), Vector3(40, 1.0, 80), PieceKit.CONCRETE, "High")
	var lo: Node3D = PieceKit.box(Vector3(0, -1, -40), Vector3(60, 1.0, 80), PieceKit.CONCRETE, "Low")
	await sandbox([hi, lo], false)
	place(Vector3(-3, h, 0), Vector3(1, 0, 0), SPEED)
	await host.get_tree().physics_frame
	var went_air: bool = false
	var stuck: int = 0  ## ticks past x = 3 spent rolling slower than 1 m/s
	var min_speed_after: float = 99.0
	for i: int in 180:
		await tick()
		if sname() == "AIR":
			went_air = true
		if sk.global_position.x > 3.0:
			min_speed_after = minf(min_speed_after, sk.speed)
			if sk.speed < 1.0:
				stuck += 1
	var res: Dictionary = {"air": went_air, "stuck": stuck, "rolling": sname() == "ROLLING", "bails": bails,
		"x": sk.global_position.x, "speed": sk.speed, "min": min_speed_after}
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	for h: float in HEIGHTS:
		var r: Dictionary = await _drop(h)
		var ok: bool = r["air"] and r["rolling"] and r["stuck"] == 0 and r["bails"] == 0 and r["x"] > 8.0
		rows.append(ok_line("ledge_drop_%.1fm" % h, ok,
			"went AIR %s, ends ROLLING %s, stuck ticks %d (need 0), bails %d (need 0), min speed after the edge %.1f m/s, end x %.1f (need >8) at %.1f m/s"
			% [str(r["air"]), str(r["rolling"]), r["stuck"], r["bails"], r["min"], r["x"], r["speed"]]))
	return rows
