extends "res://tests/sim/sim_base.gd"
## Main-park dome bowl (rim at y 0, 6.8 m deep): start rolling across the bottom at 7 m/s and pump wall to wall
## (stick forward) for 20 s. The passes must build to a real air above the rim (the coping), score "Dome Air", and
## not bail. Rows: the peaks above the rim and the gap.

const SECONDS: float = 20.0


func run() -> Array:
	var rows: Array = []
	var park := Park.new()
	await sandbox([park], false)
	await host.get_tree().physics_frame
	var c: Vector3 = Park.DOME_POS + Vector3(9.5, 0.0, 9.5)
	place(Vector3(c.x, -6.8 + 0.02, c.z), Vector3(1, 0, 0), 7.0)
	var gaps: Array = []
	sk.gap_hit.connect(func(n: String, _p: int) -> void: gaps.append(n))
	await host.get_tree().physics_frame
	var peaks: Array = []
	var cur: float = -99.0
	var first_air_t: float = -1.0
	for i: int in int(SECONDS / DT):
		await tick(FWD)
		if sname() == "AIR":
			cur = maxf(cur, sk.global_position.y)
			if first_air_t < 0.0 and sk.global_position.y > 0.0:
				first_air_t = float(i) * DT
		elif cur > -99.0:
			peaks.append(cur)
			cur = -99.0
		if gaps.has("Dome Air") and peaks.size() >= 4:
			break
	var strs: PackedStringArray = []
	var best: float = -99.0
	for p: Variant in peaks:
		strs.append("%.1f" % float(p))
		best = maxf(best, float(p))
	rows.append(ok_line("dome_pump_air", best >= 1.5 and bails == 0,
		"peaks above the rim [%s] m (want one >= 1.5), first air over the rim at %.1f s, bails %d" % [",".join(strs), first_air_t, bails]))
	rows.append(ok_line("dome_air_gap", gaps.has("Dome Air"), "gaps %s (want Dome Air)" % str(gaps)))
	await clear()
	return rows
