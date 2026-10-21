extends "res://tests/sim/sim_base.gd"
## Kicker (2.0 x 2.4 x 0.9): a slow roll over it does not launch; 8, 10 and 12 m/s launch to AIR and land ROLLING, no bail.

const Kicker := preload("res://game/park/pieces/kicker.gd")
const SLOW: float = 4.0
const FAST: Array = [8.0, 10.0, 12.0]


## Returns {air, bail, rolling, air_t, peak}: rolls 4 s over the kicker with no input.
func _ride(v0: float) -> Dictionary:
	await sandbox([Kicker.build(2.0, 2.4, 0.9)])
	place(Vector3(1.0, 0.0, 12.0), Vector3(0, 0, -1), v0)
	await host.get_tree().physics_frame
	var went_air: bool = false
	var air_t: float = 0.0
	var peak: float = 0.0
	for i: int in 240:
		await tick()
		if sname() == "AIR":
			went_air = true
			air_t += DT
		peak = maxf(peak, sk.global_position.y)
	var res: Dictionary = {"air": went_air, "bails": bails, "rolling": sname() == "ROLLING", "air_t": air_t,
		"peak": peak, "speed": sk.speed}
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	var r: Dictionary = await _ride(SLOW)
	rows.append(ok_line("kicker_4ms_no_launch", not r["air"] and r["bails"] == 0,
		"went AIR %s (need false), bails %d, peak y %.2f" % [str(r["air"]), r["bails"], r["peak"]]))
	for v0: float in FAST:
		r = await _ride(v0)
		var ok: bool = r["air"] and r["rolling"] and r["bails"] == 0 and r["air_t"] >= 0.15
		rows.append(ok_line("kicker_%dms_launch" % int(v0), ok,
			"went AIR %s for %.2fs (need >=0.15), peak y %.2f, bails %d (need 0), ends ROLLING %s at %.1f m/s"
			% [str(r["air"]), r["air_t"], r["peak"], r["bails"], str(r["rolling"]), r["speed"]]))
	return rows
