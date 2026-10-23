extends "res://tests/sim/sim_base.gd"
## The player-facing replay (game/replay/): a 5 s scripted ride (push, ollie over a kicker with a kickflip, land)
## is recorded by the flight recorder and the ReplayDirector side by side; the director's clip is then played back
## through the real skater puppet and the skater's position at every recorded tick must match the flight recorder's
## (under 1 mm), the board and hips must come back as captured, and closing the replay must put the skater, the
## pause state and the camera back exactly. Run alone: godot --headless --path . res://tests/sim/sim_suite.tscn
## -- sim_replay (once listed in SIM_FILES).

const Kicker := preload("res://game/park/pieces/kicker.gd")
const RIDE_TICKS: int = 300  ## 5 s
const POS_TOL: float = 0.001


## Gives the sandbox skater the game's Visual (placeholder body + board) and poser, as main.gd does.
func _dress() -> void:
	var visual: Node3D = sk.get_node("Visual")  # the skater makes an empty one in _ready
	var board: Node3D = PlaceholderSkater.build_board()
	board.name = "Skateboard"
	visual.add_child(board)
	var body: Node3D = PlaceholderSkater.build_body()
	body.name = "SkaterBody"
	body.position = Vector3(0, PlaceholderSkater.DECK_TOP_Y, 0)
	visual.add_child(body)
	var poser := SkaterPoser.new()
	poser.skater = sk
	poser.body = body
	poser.board = board
	sk.add_child(poser)


func run() -> Array:
	var rows: Array = []
	await sandbox([Kicker.build(2.0, 2.4, 0.9)])
	_dress()
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.make_current()
	var rec := PhysicsRecorder.new()
	root3.add_child(rec)
	rec.bind(sk)
	var d := ReplayDirector.new()
	root3.add_child(d)
	d.bind(sk, rec)
	d.set_process(false)  # the sim drives the clock: one sample per physics tick
	place(Vector3(1.0, 0.0, 14.0), Vector3(0, 0, -1), 7.0)
	var clock_of_tick: Dictionary = {}
	var air_ticks: int = 0
	for i: int in RIDE_TICKS:
		var held: Array = ["ollie"] if i >= 40 and i < 58 else []
		var jp: Array = ["flip"] if i == 60 else []
		await tick(FWD if i < 30 else NONE, jp, held)
		if sname() == "AIR":
			air_ticks += 1
		d.clock = float(i) * DT
		d.sample_now()
		var kept: Array = rec.frames_in_order()
		if not kept.is_empty():  # physics_frame fires before the tick runs: the newest frame is the pose sampled now
			clock_of_tick[int((kept.back() as Dictionary)["tick"])] = d.clock
	rows.append(ok_line("replay_records_5s", d.buffer.size() == RIDE_TICKS and air_ticks > 10,
		"%d frames over %.2f s (need %d), %d air ticks (need >10), %d tracks, %d KB ring"
		% [d.buffer.size(), d.buffer.duration(), RIDE_TICKS, air_ticks, d.buffer.track_count, d.buffer.bytes() / 1024]))

	var before: Transform3D = sk.global_transform
	var board_before: Transform3D = (sk.get_node("Visual/Skateboard") as Node3D).transform
	var c: ReplayBuffer = d.buffer.last_seconds(5.0)
	var started: bool = d.play_clip(c, "SIM")
	rows.append(ok_line("replay_starts", started and d.active and host.get_tree().paused
		and host.get_viewport().get_camera_3d() != cam,
		"active %s, tree paused %s, replay camera current %s" % [str(d.active), str(host.get_tree().paused),
		str(host.get_viewport().get_camera_3d() != cam)]))
	# every recorded tick: the puppet stands where the flight recorder had the skater
	var worst: float = 0.0
	var worst_tick: int = -1
	var checked: int = 0
	for f: Dictionary in rec.frames_in_order():
		var tk: int = int(f["tick"])
		if not clock_of_tick.has(tk):
			continue
		d.play_t = float(clock_of_tick[tk])
		d._apply(d.play_t)
		var err: float = sk.global_position.distance_to(f["pos"] as Vector3)
		checked += 1
		if err > worst:
			worst = err
			worst_tick = tk
	rows.append(ok_line("replay_positions_match_recorder", checked >= RIDE_TICKS - 2 and worst < POS_TOL,
		"%d ticks, max error %.6f m at tick %d (need < %.3f)" % [checked, worst, worst_tick, POS_TOL]))
	# the takeoff frame's board and hips come back as captured (the flip shows in the replay)
	var mid_i: int = c.index_at(c.start_time() + 62.0 * DT)
	d._apply(c.time_at(mid_i))
	var board_err: float = _xf_err((sk.get_node("Visual/Skateboard") as Node3D).transform, c.xform(mid_i, 3))
	var hips: Node3D = (sk.get_node("Visual/SkaterBody") as Node3D).find_child("Hips", true, false) as Node3D
	var hips_k: int = d._tracks.find(hips)
	var hips_err: float = _xf_err(hips.transform, c.xform(mid_i, hips_k)) if hips_k > 0 else 99.0
	rows.append(ok_line("replay_pose_tracks", board_err < 1e-4 and hips_err < 1e-4 and d.buffer.track_count >= 21,
		"board err %.6f, hips err %.6f (track %d), %d tracks (need >= 21: skater, visual, body, board, 17 joints)"
		% [board_err, hips_err, hips_k, d.buffer.track_count]))
	# auto cuts exist for a clip with an air
	rows.append(ok_line("replay_auto_cuts", d._cuts.size() >= 2,
		"%d cuts: %s" % [d._cuts.size(), str(d._cuts.map(func(x: Dictionary) -> String:
			return "%.2f %s" % [float(x["t"]) - c.start_time(), ReplayShots.NAMES[int(x["shot"])]]))]))
	d.stop()
	var back_err: float = sk.global_transform.origin.distance_to(before.origin)
	var board_back: float = _xf_err((sk.get_node("Visual/Skateboard") as Node3D).transform, board_before)
	rows.append(ok_line("replay_restores", not d.active and not host.get_tree().paused
		and host.get_viewport().get_camera_3d() == cam and back_err < 1e-5 and board_back < 1e-5,
		"active %s, paused %s, camera back %s, skater moved %.6f m, board moved %.6f"
		% [str(d.active), str(host.get_tree().paused), str(host.get_viewport().get_camera_3d() == cam), back_err, board_back]))
	await clear()
	return rows


func _xf_err(a: Transform3D, b: Transform3D) -> float:
	return a.origin.distance_to(b.origin) + (a.basis.x - b.basis.x).length() + (a.basis.y - b.basis.y).length() \
		+ (a.basis.z - b.basis.z).length()
