extends "res://tests/sim/sim_base.gd"
## The chase camera through a vert re-entry and a landing: the view never whips (max yaw rate after the turn-around on
## the way back down a quarter pipe), never pops (max one-tick camera displacement), and a big landing sinks the camera
## where a small hop does nothing. Bot lines on the real levels: tools/camera_report.sh.

const QP := preload("res://game/park/pieces/quarterpipe.gd")
const MAX_YAW: float = 4.0  ## rad/s of the view (the exponential follow peaked at 9-10)
const MAX_JUMP: float = 0.8  ## m per tick
var cam: SkateCamera


func _add_camera() -> void:
	cam = SkateCamera.new()
	root3.add_child(cam)
	cam.target = sk


func _reentry(v0: float) -> Dictionary:
	await sandbox([QP.build(10.0)])
	_add_camera()
	place(Vector3(5.0, 0.0, 12.0), Vector3(0, 0, -1), v0)
	var res: Dictionary = {"yaw": 0.0, "jump": 0.0, "vert": false}
	var prev_pos: Vector3 = Vector3.ZERO
	var prev_yaw: float = 0.0
	var landed_ticks: int = 0
	for i: int in 420:
		await tick()
		var yaw: float = cam.global_rotation.y
		if i > 10:
			res["yaw"] = maxf(res["yaw"], absf(wrapf(yaw - prev_yaw, -PI, PI)) / DT)
			res["jump"] = maxf(res["jump"], cam.global_position.distance_to(prev_pos))
		prev_pos = cam.global_position
		prev_yaw = yaw
		if sk.vert_air:
			res["vert"] = true
		if res["vert"] and sname() != "AIR":
			landed_ticks += 1
			if landed_ticks > 150:
				break
	await clear()
	return res


func _drop(height: float) -> float:
	await sandbox([])
	_add_camera()
	place(Vector3(0.0, height, 0.0), Vector3(0, 0, -1), 4.0)
	var peak: float = 0.0
	for i: int in 150:
		await tick()
		peak = maxf(peak, cam._land_h)
	await clear()
	return peak


func run() -> Array:
	var rows: Array = []
	for v0: float in [12.0, 15.0]:
		var r: Dictionary = await _reentry(v0)
		rows.append(ok_line("camera_reentry_%dms" % int(v0), r["vert"] and r["yaw"] <= MAX_YAW and r["jump"] <= MAX_JUMP,
			"vert air %s, max view yaw rate %.2f rad/s (need <= %.1f), max one-tick camera move %.2f m (need <= %.1f)" % [str(r["vert"]), r["yaw"], MAX_YAW, r["jump"], MAX_JUMP]))
	var big: float = await _drop(4.0)
	var small: float = await _drop(0.35)
	rows.append(ok_line("camera_landing_weight", big > 0.08 and small < 0.01,
		"4 m drop sinks the camera %.2f m (need > 0.08), a 0.35 m hop %.3f m (need < 0.01)" % [big, small]))
	return rows
