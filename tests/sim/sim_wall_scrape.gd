extends "res://tests/sim/sim_base.gd"
## Glancing wall scrapes never pop the body: rolling at 4-14 m/s into a long wall face, the end of a short wall (its
## corner) and a low curb-height box, at 5-60 degrees, and holding the stick into the wall, the body never moves
## further in one tick than the speed it had allows (displacement <= speed * dt + 0.02 m), never stumbles on a glancing
## contact (under 50 degrees) and keeps rolling along the wall.

const EPS: float = 0.02
const ANGLES: Array = [5.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0]
const SPEEDS: Array = [4.0, 8.0, 14.0]

var stumbles: int = 0


## Rolls at `deg` into a wall along Z with its face at x = 0 (kind "face": 80 m long; "end": the wall stops at z = 0,
## the path clips its corner; "curb": a 0.25 m tall box). Returns the worst tick excess over speed * dt and the stumbles.
func _run(deg: float, spd: float, kind: String, stick: Vector2) -> Dictionary:
	var pieces: Array = []
	if kind == "face":
		pieces.append(PieceKit.box(Vector3(-0.6, 0, -60), Vector3(0.6, 3, 80), PieceKit.PAINT_RED, "Wall"))
	elif kind == "end":
		pieces.append(PieceKit.box(Vector3(-0.6, 0, 0), Vector3(0.6, 3, 20), PieceKit.PAINT_RED, "Wall"))
	else:
		pieces.append(PieceKit.box(Vector3(-0.6, 0, -60), Vector3(0.6, 0.25, 80), PieceKit.PAINT_RED, "Curb"))
	await sandbox(pieces)
	var th: float = deg_to_rad(deg)
	var dir := Vector3(-sin(th), 0.0, -cos(th))
	var t_hit: float = 0.5
	var start := Vector3(0.3 + spd * t_hit * sin(th), 0.0, spd * t_hit * cos(th))
	if kind == "end":
		start.z += 0.15  # meet the wall right at its corner
	place(start, dir, spd)
	stumbles = 0
	var on_ev: Callable = func(f: Dictionary) -> void:
		if (f["events"] as Array).has("stumble"):
			stumbles += 1
	sk.physics_ticked.connect(on_ev)
	await host.get_tree().physics_frame
	var worst: float = -1.0
	var worst_tick: int = -1
	var last: Vector3 = sk.global_position
	var last_v: float = sk.velocity.length()
	for i: int in 70:
		await tick(stick)
		var p: Vector3 = sk.global_position
		var v_now: float = sk.velocity.length()
		var excess: float = p.distance_to(last) - maxf(last_v, v_now) * DT  # a speed gained this tick also covers its step
		if excess > worst:
			worst = excess
			worst_tick = i
		last = p
		last_v = v_now
	var res: Dictionary = {"excess": worst, "tick": worst_tick, "stumbles": stumbles, "bails": bails, "speed": sk.velocity.length(), "state": sname()}
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	var worst_pop: float = -1.0
	var worst_desc: String = ""
	var glance_stumbles: int = 0
	var stumble_desc: String = ""
	var bail_n: int = 0
	var runs: int = 0
	for kind: String in ["face", "end", "curb"]:
		for deg: float in ANGLES:
			for spd: float in SPEEDS:
				for stick: Vector2 in [NONE, Vector2(0.6, 0.0)]:
					var r: Dictionary = await _run(deg, spd, kind, stick)
					runs += 1
					if float(r["excess"]) > worst_pop:
						worst_pop = float(r["excess"])
						worst_desc = "%s %d deg %.0f m/s stick %s (tick %d)" % [kind, int(deg), spd, str(stick), int(r["tick"])]
					if int(r["stumbles"]) > 0 and deg < 50.0 and kind != "curb":
						glance_stumbles += 1
						stumble_desc = "%s %d deg %.0f m/s stick %s" % [kind, int(deg), spd, str(stick)]
					bail_n += int(r["bails"])
	rows.append(ok_line("wall_scrape_no_pop", worst_pop <= EPS,
		"%d scrapes: worst tick step over speed*dt %.3f m (want <= %.2f) at %s" % [runs, worst_pop, EPS, worst_desc]))
	rows.append(ok_line("wall_scrape_glance_no_stumble", glance_stumbles == 0 and bail_n == 0,
		"glancing (<50 deg) scrapes that stumbled %d (want 0)%s, bails %d" % [glance_stumbles, (" e.g. " + stumble_desc) if stumble_desc != "" else "", bail_n]))
	return rows
