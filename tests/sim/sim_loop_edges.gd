extends "res://tests/sim/sim_base.gd"
## The loop's ribbon has solid edges: steering hard into either curb all the way round never lets the skater slip off
## the side of the track, and dropping onto the outside of the loop's top across its edges never falls through into
## the loop. Loop as in the park: r 4, 3 m wide, 6 m run-in and run-out, 3.5 m sideways offset.

const LoopScript := preload("res://game/park/pieces/loop.gd")
const R: float = 4.0
const W: float = 3.0
const RUN_IN: float = 6.0
const OFFSET: float = 3.5


## Left edge x of the ribbon at the loop angle under the skater (or -1 when not over the loop part).
func _edge_x(p: Vector3) -> float:
	var cy: float = LoopScript.LIFT + R
	var th: float = fposmod(atan2(-(p.z + RUN_IN), cy - p.y), TAU)
	var u: float = clampf(th / TAU, 0.0, 1.0)
	return OFFSET * u * u * (3.0 - 2.0 * u)


## Rides round at 21 m/s holding the stick to one side. Returns {out (m outside the ribbon at worst), done, bails}.
func _ride(stick_x: float) -> Dictionary:
	await sandbox([LoopScript.build(R, W, RUN_IN, 6.0, OFFSET)])
	place(Vector3(1.5, 0.02, -0.4), Vector3(0, 0, -1), 21.0)
	await host.get_tree().physics_frame
	var worst: float = 0.0
	var top: float = 0.0
	for i: int in 180:
		await tick(Vector2(stick_x, 0.0))
		var p: Vector3 = sk.global_position
		top = maxf(top, p.y)
		if p.y > 1.0:
			var e: float = _edge_x(p)
			worst = maxf(worst, maxf(e - p.x, p.x - (e + W)))
		if top > 2.0 * R - 1.0 and p.y < 0.4 and p.z < -RUN_IN - 1.0:
			break
	var res: Dictionary = {"out": worst, "done": top > 2.0 * R - 1.0, "bails": bails}
	await clear()
	return res


## Drops from 1 m above the outside of the loop's top at x. Returns true when it did not end up inside the loop.
func _drop(x: float) -> Dictionary:
	await sandbox([LoopScript.build(R, W, RUN_IN, 6.0, OFFSET)])
	var top_y: float = LoopScript.LIFT + 2.0 * R
	place(Vector3(x, top_y + 1.0, -RUN_IN), Vector3(0, 0, -1), 0.0)
	await host.get_tree().physics_frame
	var e: float = OFFSET * 0.5
	var inside: bool = false
	for i: int in 90:
		await tick()
		var p: Vector3 = sk.global_position
		if p.x > e + 0.05 and p.x < e + W - 0.05 and p.y < top_y - 0.3 and p.y > 1.0 and absf(p.z + RUN_IN) < R:
			inside = true
	var res: Dictionary = {"inside": inside, "y": sk.global_position.y}
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	for sx: float in [1.0, -1.0]:
		var r: Dictionary = await _ride(sx)
		rows.append(ok_line("loop_curb_hold_%s" % ("right" if sx > 0.0 else "left"), bool(r["done"]) and float(r["out"]) < 0.05 and int(r["bails"]) == 0,
			"21 m/s round the loop steering full %s: at worst %.2f m outside the ribbon (want < 0.05), made it %s, bails %d"
			% ["right" if sx > 0.0 else "left", float(r["out"]), str(r["done"]), int(r["bails"])]))
	var bad: PackedStringArray = []
	var e: float = OFFSET * 0.5
	for x: float in [e - 0.35, e - 0.2, e - 0.05, e + 0.1, e + W - 0.1, e + W + 0.05, e + W + 0.2, e + W + 0.35]:
		var d: Dictionary = await _drop(x)
		if bool(d["inside"]):
			bad.append("%.2f" % x)
	rows.append(ok_line("loop_top_edges_solid", bad.is_empty(),
		"dropped onto the outside of the loop top across both edges: fell through into the loop at x [%s] (want none)" % ",".join(bad)))
	return rows
