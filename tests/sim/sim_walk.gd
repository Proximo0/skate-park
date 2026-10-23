extends "res://tests/sim/sim_base.gd"
## Walking: step off the board (C / left-stick click), walk and run carrying it, jump, and step back on.
## Dismounting at 6 m/s jogs to a stop inside 2 m; 3 s of walking covers about 4.8 m; the jump is about 0.6 m; the
## mount puts the board under the feet rolling at the walking speed and the skater can push away; a snapshot taken
## while walking replays exactly.

const HALF_TILT: Vector2 = Vector2(0.0, -Walker.WALK_TILT)  ## stick that gives exactly walk_speed


func _stand_on_ground(speed: float) -> void:
	await sandbox([])
	sk.tune = PhysicsTuning.new()
	place(Vector3(0, 0.0, 0), Vector3(0, 0, -1), speed)
	for i: int in 10:
		await tick(FWD if speed > 0.0 else NONE)


func _dismount_and_settle() -> void:
	await tick(NONE, ["dismount"])
	for i: int in 15:
		await tick(NONE)


func run() -> Array:
	var rows: Array = []

	# Hop off at 6 m/s: stops within 2 m and switches to WALK.
	await _stand_on_ground(6.0)
	var start: Vector3 = sk.global_position
	var events: Array = []
	var ev: Callable = func(frame: Dictionary) -> void:
		events.append_array(frame["events"])
	sk.physics_ticked.connect(ev)
	await tick(NONE, ["dismount"])
	var entered: bool = sname() == "WALK"
	for i: int in 120:
		await tick(NONE)
	sk.physics_ticked.disconnect(ev)
	var run_out: float = sk.global_position.distance_to(start)
	rows.append(ok_line("dismount_stops", entered and sname() == "WALK" and run_out < 2.0 + 0.001 and sk.velocity.length() < 0.05 and events.has("dismount"),
			"state %s, ran on %.2f m (need < 2.0), end speed %.3f, events %s" % [sname(), run_out, sk.velocity.length(), str(events)]))
	await clear()

	# Walk forward 3 s at the walking speed.
	await _stand_on_ground(0.0)
	await _dismount_and_settle()
	var p0: Vector3 = sk.global_position
	for i: int in 180:
		await tick(HALF_TILT)
	var dist: float = p0.distance_to(sk.global_position)
	var dz: float = p0.z - sk.global_position.z
	rows.append(ok_line("walk_3s", absf(dist - 4.8) < 0.25 and dz > 4.4 and absf(sk.global_position.y) < 0.05,
			"walked %.2f m in 3 s (want about 4.8), forward %.2f, y %.3f, anim %s" % [dist, dz, sk.global_position.y, sk.anim]))
	# Full stick runs at 4 m/s.
	for i: int in 30:
		await tick(FWD)
	rows.append(ok_line("run_speed", absf(sk.velocity.length() - 4.0) < 0.1, "full stick speed %.2f m/s (want 4.0)" % sk.velocity.length()))
	await clear()

	# Jump: about 0.6 m.
	await _stand_on_ground(0.0)
	await _dismount_and_settle()
	var base_y: float = sk.global_position.y
	var peak: float = base_y
	await tick(NONE, ["ollie"])
	var left_floor: bool = false
	for i: int in 60:
		await tick(NONE)
		peak = maxf(peak, sk.global_position.y)
		left_floor = left_floor or not sk.is_on_floor()
	var h: float = peak - base_y
	rows.append(ok_line("walk_jump", h >= 0.5 and h <= 0.7 and left_floor and sname() == "WALK" and sk.is_on_floor(),
			"jump peak %.2f m (want 0.5-0.7), state %s, back on the floor %s" % [h, sname(), str(sk.is_on_floor())]))
	await clear()

	# Mount: back on the board at walking speed, board under the feet, can push away.
	await _stand_on_ground(0.0)
	await _dismount_and_settle()
	for i: int in 40:
		await tick(HALF_TILT)
	await tick(HALF_TILT, ["dismount"])
	await tick(NONE)
	var mounted: bool = sname() == "ROLLING"
	var spd: float = sk.velocity.length()
	var under: bool = absf(sk.global_position.y) < 0.05 and sk.is_on_floor() and absf(sk.floor_max_angle - deg_to_rad(80.0)) < 0.001
	var z0: float = sk.global_position.z
	for i: int in 120:
		await tick(FWD)
	rows.append(ok_line("mount_and_push", mounted and under and spd > 1.2 and spd < 1.8 and sk.velocity.length() > 3.0 and sk.global_position.z < z0 - 3.0,
			"state %s, rolled off at %.2f m/s (want about 1.6), board on ground %s, speed after pushing %.2f" % [sname(), spd, str(under), sk.velocity.length()]))
	await clear()

	# Snapshot/restore round trip while walking, through a jump.
	await _stand_on_ground(0.0)
	await _dismount_and_settle()
	for i: int in 40:
		await tick(HALF_TILT)
	var snap_text: String = var_to_str(sk.snapshot())
	var first: Array = await _walk_script()
	sk.restore(str_to_var(snap_text) as Dictionary)
	var second: Array = await _walk_script()
	var worst: float = 0.0
	for i: int in first.size():
		worst = maxf(worst, (first[i] as Vector3).distance_to(second[i] as Vector3))
	rows.append(ok_line("walk_snapshot", worst <= 1.0e-3 and sname() == "WALK",
			"worst position error %.6f m over %d walking ticks incl. a jump (need <= 0.001)" % [worst, first.size()]))
	await clear()
	return rows


func _walk_script() -> Array:
	var out: Array = []
	for i: int in 90:
		await tick(Vector2(0.5, -0.8), ["ollie"] if i == 20 else [])
		out.append(sk.global_position)
	return out
