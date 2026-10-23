extends "res://tests/sim/sim_base.gd"
## Glancing wall hits are arcade-forgiving: rolling at 10 m/s into a long straight wall at a shallow angle turns the
## skater along it and keeps the speed. Speed 0.3 s after the first wall contact is compared with a run with no wall
## (same ticks, so rolling friction cancels out). Want: 15 and 25 degrees keep at least 98.5%, 40 degrees keeps 95-97.5%.

const SPEED: float = 10.0


## Rolls at `deg` degrees (between the travel and the wall's face) into a wall along Z with its face at x = 0.
## Returns the speed `after` seconds after the first wall contact (or at the same tick with no wall), and the tick.
func _run(deg: float, with_wall: bool, contact_tick: int = -1) -> Dictionary:
	var pieces: Array = []
	if with_wall:
		pieces.append(PieceKit.box(Vector3(-0.6, 0, -60), Vector3(0.6, 3, 80), PieceKit.PAINT_RED, "Wall"))
	await sandbox(pieces)
	var th: float = deg_to_rad(deg)
	var dir := Vector3(-sin(th), 0.0, -cos(th))
	# start so the skater meets the wall after about 0.5 s
	var start := Vector3(0.3 + SPEED * 0.5 * sin(th), 0.0, 0.0)
	place(start, dir, SPEED)
	await host.get_tree().physics_frame
	var hit_tick: int = contact_tick
	var out: float = -1.0
	for i: int in 150:
		await tick()
		if hit_tick < 0 and with_wall and (sk.is_on_wall() or sk.global_position.x < 0.31):
			hit_tick = i
		if hit_tick >= 0 and i == hit_tick + 18:
			out = sk.velocity.length()
			break
	var res: Dictionary = {"speed": out, "tick": hit_tick, "bails": bails}
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	for deg: float in [15.0, 25.0, 40.0]:
		var w: Dictionary = await _run(deg, true)
		var free: Dictionary = await _run(deg, false, int(w["tick"]))
		var keep: float = float(w["speed"]) / maxf(float(free["speed"]), 0.01)
		var lo: float = 0.985 if deg <= 25.0 else 0.95
		var hi: float = 1.01 if deg <= 25.0 else 0.975
		rows.append(ok_line("wall_glance_%ddeg" % int(deg), keep >= lo and keep <= hi and int(w["bails"]) == 0 and int(w["tick"]) >= 0,
			"%d deg into a wall at %.0f m/s: kept %.1f%% of the speed 0.3 s after contact (want %.1f-%.1f%%), bails %d"
			% [int(deg), SPEED, keep * 100.0, lo * 100.0, hi * 100.0, int(w["bails"])]))
	return rows
