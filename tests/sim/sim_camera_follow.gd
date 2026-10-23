extends "res://tests/sim/sim_base.gd"
## The chase camera through a vert re-entry and a landing: the view never whips (max yaw rate after the turn-around on
## the way back down a quarter pipe), never pops (max one-tick camera displacement), and a big landing sinks the camera
## where a small hop does nothing. A drop-in perch lets go and follows the skater down (it held on: 12 m away), and
## the camera rides a loop inside it with the rider in frame (it went inside the rider, 0.3 m, and whipped).
## Bot lines on the real levels: tools/camera_report.sh.

const QP := preload("res://game/park/pieces/quarterpipe.gd")
const MAX_YAW: float = 4.0  ## rad/s of the view (the exponential follow peaked at 9-10)
const MAX_JUMP: float = 0.8  ## m per tick
const LoopScript := preload("res://game/park/pieces/loop.gd")
const PERCH_MAX_DIST: float = 5.2  ## m from the rider during a perched 8 m drop-in (the held perch: 5.5 here, 12 on the real tower)
const LOOP_MIN_DIST: float = 1.5  ## m from the rider's body round the loop
const FLIP: float = 1.2  ## rad the view may turn in one tick at most (a heading flip through the vertical is ~3)
## SIM_CAMERA_SCRIPT swaps in another camera script (an older copy, without its class_name) to prove the sims can fail.
var CameraScript: GDScript = load(OS.get_environment("SIM_CAMERA_SCRIPT") if OS.get_environment("SIM_CAMERA_SCRIPT") != "" else "res://game/camera/skate_camera.gd")
var cam  ## a SkateCamera (untyped so an older copy can stand in)


func _add_camera() -> void:
	cam = CameraScript.new()
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


## The rider's body middle, along the board's up (upside down in a loop).
func _mid() -> Vector3:
	return sk.global_position + sk.board_up.normalized() * 0.85


## A drop-in's perch over the coping (as RampSnap sets it) while the skater rolls away down an 8 m wall.
func _perch_drop() -> Dictionary:
	await sandbox([QP.build(8.0, 8.0, 8.0, 1.5)])
	_add_camera()
	place(Vector3(4.0, 8.05, 1.75), Vector3(0, 0, 1), 3.0)
	sk.camera_anchor = Vector3(4.0, 8.0, 1.5) - Vector3(0, 0, 1) * RampSnap.CAMERA_BACK + Vector3.UP * RampSnap.CAMERA_UP
	sk.camera_hold = 2.0
	var res: Dictionary = {"dist": 0.0, "off": 0}
	for i: int in 96:
		await tick()
		if i < 5:
			continue
		res["dist"] = maxf(res["dist"], cam.global_position.distance_to(_mid()))
		if not cam.is_position_in_frustum(_mid()):
			res["off"] += 1
	await clear()
	return res


## Round the park's loop at 21 m/s: the camera's nearest approach to the rider, ticks with the rider out of frame and
## the largest one-tick turn of the view.
func _loop_ride() -> Dictionary:
	await sandbox([LoopScript.build(4.0, 3.0, 6.0, 6.0, 3.5)])
	_add_camera()
	place(Vector3(1.5, 0.02, -0.4), Vector3(0, 0, -1), 21.0)
	var res: Dictionary = {"min": INF, "off": 0, "turn": 0.0, "top": 0.0}
	var prev: Basis = Basis.IDENTITY
	for i: int in 200:
		await tick()
		var b: Basis = cam.global_transform.basis.orthonormalized()
		if i > 10:
			res["min"] = minf(res["min"], cam.global_position.distance_to(_mid()))
			res["turn"] = maxf(res["turn"], (prev.inverse() * b).get_rotation_quaternion().get_angle())
			if not cam.is_position_in_frustum(_mid()):
				res["off"] += 1
		prev = b
		res["top"] = maxf(res["top"], sk.global_position.y)
		if res["top"] > 7.0 and sk.global_position.y < 0.3 and sk.global_position.z < -12.0:
			break
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	var pd: Dictionary = await _perch_drop()
	rows.append(ok_line("camera_dropin_follows", pd["dist"] <= PERCH_MAX_DIST and pd["off"] == 0,
		"perched over an 8 m drop-in wall: camera at most %.2f m from the rider (need <= %.1f), rider out of frame %d ticks (need 0)" % [pd["dist"], PERCH_MAX_DIST, pd["off"]]))
	var lr: Dictionary = await _loop_ride()
	rows.append(ok_line("camera_loop_rides_inside", lr["top"] > 7.0 and lr["min"] >= LOOP_MIN_DIST and lr["off"] == 0 and lr["turn"] <= FLIP,
		"loop at 21 m/s (top %.1f m): nearest %.2f m (need >= %.1f), rider out of frame %d ticks (need 0), largest one-tick view turn %.2f rad (need <= %.1f)" % [lr["top"], lr["min"], LOOP_MIN_DIST, lr["off"], lr["turn"], FLIP]))
	for v0: float in [12.0, 15.0]:
		var r: Dictionary = await _reentry(v0)
		rows.append(ok_line("camera_reentry_%dms" % int(v0), r["vert"] and r["yaw"] <= MAX_YAW and r["jump"] <= MAX_JUMP,
			"vert air %s, max view yaw rate %.2f rad/s (need <= %.1f), max one-tick camera move %.2f m (need <= %.1f)" % [str(r["vert"]), r["yaw"], MAX_YAW, r["jump"], MAX_JUMP]))
	var big: float = await _drop(4.0)
	var small: float = await _drop(0.35)
	rows.append(ok_line("camera_landing_weight", big > 0.08 and small < 0.01,
		"4 m drop sinks the camera %.2f m (need > 0.08), a 0.35 m hop %.3f m (need < 0.01)" % [big, small]))
	return rows
