extends "res://tests/sim/sim_base.gd"
## A skater started (or put back) partly or wholly inside solid geometry gets out by the shortest way, at most
## DEPEN_MAX_STEP m a tick (plus the engine's overlap recovery), then rides on with ordinary physics: never left falling at terminal speed through a floor,
## never pinned. Cases: buried 0.1 / 0.25 / 0.5 m into the ground, inside a 1 m crate on the ground (sphere fully inside),
## half into a wall's side.

const CAP: float = 0.55  ## m per tick the body may jump past its speed: the skater's push-out (0.25) plus the engine's own overlap recovery


func _case(label: String, pieces: Array, pos: Vector3, spd: float) -> Array:
	await sandbox(pieces)
	place(pos, Vector3.FORWARD, spd)
	var max_fall: float = 0.0
	var worst_step: float = 0.0
	var last: Vector3 = sk.global_position
	var last_v: float = spd
	var seen: Dictionary = {"respawn": false}  # (a lambda captures locals by value: flag through a dictionary)
	sk.physics_ticked.connect(func(f: Dictionary) -> void:
		if (f["events"] as Array).has("respawn"):
			seen["respawn"] = true)
	for i: int in 90:
		await tick()
		var p: Vector3 = sk.global_position
		worst_step = maxf(worst_step, p.distance_to(last) - maxf(last_v, sk.velocity.length()) * DT)
		last = p
		last_v = sk.velocity.length()
		if i > 20:
			max_fall = maxf(max_fall, -sk.velocity.y)
	var top: float = sk.global_position.y
	var respawned: bool = seen["respawn"]
	var ok: bool = sname() == "ROLLING" and sk.is_on_floor() and max_fall < 2.0 and not respawned and worst_step <= CAP
	var row: Array = ok_line("buried_" + label, ok, "now %s at y %.2f on floor %s, fastest fall after 0.33 s %.1f m/s (want < 2), respawned %s, worst push step %.2f m (want <= %.2f), bails %d"
		% [sname(), top, str(sk.is_on_floor()), max_fall, str(respawned), worst_step, CAP, bails])
	await clear()
	return row


func run() -> Array:
	var rows: Array = []
	for d: float in [0.1, 0.25, 0.5]:
		rows.append(await _case("ground_%dcm" % int(d * 100.0), [], Vector3(0, -d, 0), 0.0))
	rows.append(await _case("in_crate", [PieceKit.box(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1), PieceKit.PAINT_RED, "Crate")], Vector3(0, 0.2, 0), 0.0))
	rows.append(await _case("half_in_wall", [PieceKit.box(Vector3(-0.6, 0, -10), Vector3(0.6, 3, 20), PieceKit.PAINT_RED, "Wall")], Vector3(-0.1, 0.0, 0), 4.0))
	rows.append(await _thin_wall())
	return rows


## Jumping beside a 0.15 m thin wall must never be "pushed out" through it to the far side.
func _thin_wall() -> Array:
	await sandbox([PieceKit.box(Vector3(0.45, 0, -10), Vector3(0.15, 3, 20), PieceKit.PAINT_RED, "Thin")])
	place(Vector3(0.0, 0.0, 0.0), Vector3.FORWARD, 4.0)
	await tick()
	sk.velocity.y = 6.0
	var crossed: bool = false
	for i: int in 60:
		await tick()
		if sk.global_position.x > 0.3:
			crossed = true
	var row: Array = ok_line("buried_thin_wall_no_pushthrough", not crossed and sname() == "ROLLING",
		"jumped beside a 0.15 m wall: ended at x %.2f (wall at 0.45-0.60), crossed %s, %s" % [sk.global_position.x, str(crossed), sname()])
	await clear()
	return row
