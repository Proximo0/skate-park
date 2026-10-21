extends "res://tests/sim/sim_base.gd"
## Grind snap looks like a quick hop, not a teleport: rolling at 8 m/s beside a low rail, 1.0 m off it, and pressing
## grind snaps the body onto the rail at once, but the visual (Visual node) slides over: no single frame moves it
## more than 0.25 m beyond the travel, and it catches up with the body within 0.15 s.

const STREET := preload("res://game/park/pieces/street_bits.gd")
const SPEED: float = 8.0


func run() -> Array:
	await sandbox([STREET.flat_rail(30.0, 0.4)])
	var rails: Array = host.get_tree().get_nodes_in_group("grind_rail")
	var rp: Vector3 = (rails[0] as GrindRail).global_points()[0]
	place(Vector3(rp.x + 1.0, 0.0, 1.0), Vector3(0, 0, 1), SPEED)
	await host.get_tree().physics_frame
	for i: int in 12:
		await tick()
	var vis: Node3D = sk.get_node("Visual") as Node3D
	var prev: Vector3 = vis.global_position
	var prev_body: Vector3 = sk.global_position
	await tick(NONE, ["grind"], [])
	var body_jump: float = (sk.global_position - prev_body).length() - SPEED * DT
	var worst: float = 0.0
	var caught: int = -1
	for i: int in 30:
		if i > 0:
			await tick()
		var v: Vector3 = vis.global_position
		var travel: float = sk.velocity.length() * DT
		worst = maxf(worst, (v - prev).length() - travel)
		prev = v
		if caught < 0 and v.distance_to(sk.global_position) < 0.02:
			caught = i
	var grinding: bool = sname() == "GRIND"
	await clear()
	var ok: bool = grinding and body_jump > 0.6 and worst <= 0.25 and caught >= 0 and caught <= 9
	return [ok_line("grind_snap_visual_ease", ok,
		"body snapped %.2f m onto the rail (grinding %s); visual's biggest jump beyond the travel %.2f m in a frame (want <= 0.25), caught up after %d ticks (want <= 9, 0.15 s)"
		% [body_jump, str(grinding), worst, caught])]
