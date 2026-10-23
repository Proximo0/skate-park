extends "res://tests/sim/sim_base.gd"
## 45 degree bank: riding along (across) the slope at 8 m/s with no input does not slide sideways off it more than a little.
## The wedge is 6 m high and 40 m long (along x); its slope falls toward +z. The skater starts mid-slope heading +x.

const H: float = 6.0
const LEN: float = 40.0
const SPEED: float = 8.0
const SECONDS: float = 3.0
const MAX_DRIFT: float = 1.0  ## metres of downhill (z) slide allowed over the run


func _wedge() -> Node3D:
	# profile points are (y, z): top edge at z=0, toe at z=H, 45 degrees. extrude_profile runs along +x.
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, H), Vector2(H, 0.0)])
	var n := Node3D.new()
	n.add_child(PieceKit.body(PieceKit.extrude_profile(prof, LEN), PieceKit.RAMP_WOOD, "Bank45"))
	n.position = Vector3(-10.0, 0.0, 0.0)
	return n


func run() -> Array:
	await sandbox([_wedge()])
	var z0: float = H * 0.5
	place(Vector3(-8.0, H * 0.5 + 0.05, z0), Vector3(1, 0, 0), SPEED)
	await host.get_tree().physics_frame
	var max_dz: float = 0.0
	var went_air: bool = false
	var on_floor_ticks: int = 0
	var n: int = int(SECONDS / DT)
	for i: int in n:
		await tick()
		if sname() == "AIR":
			went_air = true
		if sk.is_on_floor():
			on_floor_ticks += 1
		max_dz = maxf(max_dz, absf(sk.global_position.z - z0))
	var dx: float = sk.global_position.x + 8.0
	var end_state: String = sname()
	var ny: float = sk._floor_normal.y
	await clear()
	var ok: bool = dx > 10.0 and max_dz <= MAX_DRIFT and bails == 0 and on_floor_ticks > n / 2 \
		and ny > 0.6 and ny < 0.8  ## really on the 45 degree face (normal y 0.707)
	return [ok_line("bank45_cross_slope", ok,
		"travelled %.1f m along x in %.0fs (need >10), max sideways/downhill slide %.2f m (need <=%.1f), on floor %d/%d ticks, floor normal y %.2f (need ~0.71), ends %s"
		% [dx, SECONDS, max_dz, MAX_DRIFT, on_floor_ticks, n, ny, end_state])]
