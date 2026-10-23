extends "res://tests/sim/sim_base.gd"
## Vert re-entry: leaving a quarter pipe into vert air and landing back onto it is a "clean" landing that keeps at least
## 90% of the impact speed.

const QP := preload("res://game/park/pieces/quarterpipe.gd")
const SPEEDS: Array = [12.0, 15.0]
const MIN_KEEP: float = 0.9


func _one(v0: float) -> Dictionary:
	await sandbox([QP.build(10.0)])
	place(Vector3(5.0, 0.0, 12.0), Vector3(0, 0, -1), v0)
	await host.get_tree().physics_frame
	var res: Dictionary = {"vert": false, "landed": "", "impact": 0.0, "after": 0.0, "peak": 0.0}
	var prev_speed: float = 0.0
	var phase: int = 0  ## 0 riding up, 1 in vert air, 2 landed
	var ticks_after: int = 0
	for i: int in 420:
		prev_speed = sk.velocity.length()
		await tick()
		if phase == 0 and sname() == "AIR" and sk.vert_air:
			phase = 1
			res["vert"] = true
		if phase == 1:
			res["peak"] = maxf(res["peak"], sk.global_position.y)
			if sname() != "AIR":
				phase = 2
				res["impact"] = prev_speed
				res["landed"] = landings[landings.size() - 1] if not landings.is_empty() else "none"
				res["after_first"] = sk.velocity.length()
		elif phase == 2:
			ticks_after += 1
			if ticks_after == 3:
				res["after"] = sk.velocity.length()
				break
	res["bails"] = bails
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	for v0: float in SPEEDS:
		var r: Dictionary = await _one(v0)
		var impact: float = r["impact"]
		var keep: float = r["after"] / impact if impact > 0.0 else 0.0
		var ok: bool = r["vert"] and r["landed"] == "clean" and keep >= MIN_KEEP and r["bails"] == 0
		rows.append(ok_line("vert_reentry_%dms" % int(v0), ok,
			"vert air %s (peak y %.1f), landing %s (need clean), impact %.1f m/s, 3 ticks later %.1f m/s = %.0f%% kept (need >=%.0f%%), bails %d"
			% [str(r["vert"]), r["peak"], r["landed"], impact, r["after"], keep * 100.0, MIN_KEEP * 100.0, r["bails"]]))
	return rows
