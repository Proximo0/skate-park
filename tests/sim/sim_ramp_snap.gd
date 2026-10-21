extends "res://tests/sim/sim_base.gd"
## The ramp snap (Q + E / L1 + R1 together) in the real park:
##  roll_in_quarter  rolling toward QuarterNorth (coping y 3.2 at z -38.5): hop onto the coping, hang, drop in, land on
##                   the transition clean and roll back out onto the flat, no bail
##  air_halfpipe_low in the air beside the half pipe, below its lips: straight onto the nearer wall, clean, no bail
##  air_halfpipe_high in the air beside the half pipe, above its lips: onto the coping, drop in, clean, no bail
##  out_halfpipe     riding up a half pipe wall: out of the half pipe onto flat ground, rolling, no bail
##  out_quarter      riding up QuarterNorth: onto the flat in front of it, rolling away, no bail
##  roll_in_mega     rolling near the mega ramp tower in the air: set on its start deck, rolls into the roll-in
##  far_nothing      far from every ramp: nothing happens except the "no ramp" signal; the chord does not spin
##  every_lip        in the air 4 m in front of and 2.5 m above the middle of every RampLip in the park: snaps in, no bail

const ParkScript := preload("res://game/park/park.gd")
const CHORD: Array = ["spin_left", "spin_right"]
const QN_COPING_Z: float = -38.5
const QN_COPING_Y: float = 3.2
const HP_X: float = -33.0  ## half pipe centre line
const HP_A_Z: float = -38.0  ## wall A's coping
const HP_B_Z: float = -25.0  ## wall B's coping
const HP_COPING_Y: float = 4.0

var park: Node
var snaps: Array = []
var misses: int = 0


func _setup() -> void:
	park = ParkScript.new()
	park.name = "Park"
	await sandbox([park], false)
	for i: int in 5:
		await tick()
	sk.ramp_snapped.connect(func(m: String) -> void: snaps.append(m))
	sk.ramp_snap_missed.connect(func() -> void: misses += 1)


func _reset_counts() -> void:
	sk.respawn()
	snaps = []
	misses = 0
	bails = 0
	landings = []


func _air(pos: Vector3, vel: Vector3) -> void:
	place(pos, Vector3(vel.x, 0.0, vel.z) if Vector2(vel.x, vel.z).length() > 0.1 else Vector3.FORWARD, 0.0)
	sk.velocity = vel
	sk.state.event("ollie")
	sk._launch_normal = UPV
	sk.vert_air = false
	sk._enter_air(false)


func _fire() -> void:
	await tick(NONE, CHORD, CHORD)
	await tick(NONE, [], CHORD)
	await tick()


## Ticks up to `seconds`; stops early once `done` returns true. Returns a summary.
func _watch(seconds: float, done: Callable) -> Dictionary:
	var t: float = 0.0
	var min_ny: float = 1.0
	var max_step: float = 0.0
	var last: Vector3 = sk.global_position
	var rolled_on_wall: bool = false
	while t < seconds:
		await tick()
		t += DT
		max_step = maxf(max_step, sk.global_position.distance_to(last))
		last = sk.global_position
		if sname() == "ROLLING":
			min_ny = minf(min_ny, sk._floor_normal.y)
			if sk._floor_normal.y < 0.8:
				rolled_on_wall = true
		if done.call():
			break
	return {"t": t, "min_ny": min_ny, "step": max_step, "wall": rolled_on_wall}


func _p(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


func _sim_roll_in_quarter() -> Array:
	_reset_counts()
	place(Vector3(1.0, 0.05, -29.0), Vector3.FORWARD, 6.0)
	for i: int in 10:
		await tick()
	await _fire()
	var hung: bool = false
	var hang_y: float = -9.0
	for i: int in 60:  # the arc and the hang
		await tick()
		if sk.anim == "drop_in" and sk.velocity.length() < 0.01:
			hung = true
			hang_y = sk.global_position.y
		if str(sk._snap.get("phase", "")) == "" and hung:
			break
	var r: Dictionary = await _watch(4.0, func() -> bool: return sname() == "ROLLING" and sk.global_position.z > QN_COPING_Z + 6.0)
	var ok: bool = snaps == ["drop_in"] and hung and absf(hang_y - QN_COPING_Y) < 0.2 and bails == 0 and r["wall"] \
		and landings.size() >= 1 and str(landings[0]) == "clean" and sname() == "ROLLING" and sk.speed > 3.0 \
		and float(r["step"]) < 1.0
	return ok_line("ramp_snap_roll_in_quarter", ok, "snaps %s, hung on coping %s at y %.2f (coping %.1f), rode the wall %s (min floor ny %.2f), landings %s, bails %d, now %s at %s %.1f m/s, biggest step %.2f m"
		% [str(snaps), str(hung), hang_y, QN_COPING_Y, str(r["wall"]), r["min_ny"], str(landings), bails, sname(), _p(sk.global_position), sk.speed, r["step"]])


func _sim_air_halfpipe(high: bool) -> Array:
	_reset_counts()
	# beside the half pipe's east side (x -28), level with its middle, drifting west
	_air(Vector3(-25.0, 6.0 if high else 1.8, -29.0), Vector3(-4.0, 1.5, 0.0))
	await _fire()
	var r: Dictionary = await _watch(4.0, func() -> bool: return sname() == "ROLLING" and sk._floor_normal.y > 0.97 and sk.global_position.y < 0.3)
	var want: String = "drop_in" if high else "air_in"
	var ok: bool = snaps == [want] and bails == 0 and r["wall"] and landings.size() >= 1 and str(landings[0]) == "clean" \
		and sname() == "ROLLING" and sk.global_position.x < -28.0 and sk.global_position.x > -38.0 and float(r["step"]) < 1.0
	return ok_line("ramp_snap_air_halfpipe_" + ("high" if high else "low"), ok, "snaps %s (want %s), rode the wall %s, landings %s, bails %d, now %s at %s %.1f m/s, biggest step %.2f m"
		% [str(snaps), want, str(r["wall"]), str(landings), bails, sname(), _p(sk.global_position), sk.speed, r["step"]])


func _sim_out_halfpipe() -> Array:
	_reset_counts()
	place(Vector3(HP_X, 0.05, -31.5), Vector3.FORWARD, 9.0)
	var on_wall: bool = false
	for i: int in 120:
		await tick()
		if sname() == "ROLLING" and sk._floor_normal.y < 0.7:
			on_wall = true
			break
	var start: Vector3 = sk.global_position
	await _fire()
	var r: Dictionary = await _watch(3.0, func() -> bool: return sk._snap.is_empty() and sname() == "ROLLING")
	for i: int in 30:
		await tick()
	var p: Vector3 = sk.global_position
	var outside: bool = p.x > -28.0 or p.x < -38.0 or p.z < -40.0 or p.z > -23.0
	var ok: bool = on_wall and snaps.size() == 1 and str(snaps[0]).begins_with("out") and bails == 0 and sname() == "ROLLING" \
		and sk._floor_normal.y > 0.97 and sk.speed > 0.5 and outside and float(r["step"]) < 1.0
	return ok_line("ramp_snap_out_halfpipe", ok, "on the wall %s at %s, snaps %s, bails %d, now %s on floor ny %.2f at %s (outside the half pipe %s) %.1f m/s, biggest step %.2f m"
		% [str(on_wall), _p(start), str(snaps), bails, sname(), sk._floor_normal.y, _p(p), str(outside), sk.speed, r["step"]])


func _sim_out_quarter() -> Array:
	_reset_counts()
	place(Vector3(1.0, 0.05, -30.0), Vector3.FORWARD, 9.0)
	var on_wall: bool = false
	for i: int in 120:
		await tick()
		if sname() == "ROLLING" and sk._floor_normal.y < 0.8 and sk.velocity.y > 0.0:
			on_wall = true
			break
	await _fire()
	var r: Dictionary = await _watch(3.0, func() -> bool: return sk._snap.is_empty() and sname() == "ROLLING")
	for i: int in 30:
		await tick()
	var p: Vector3 = sk.global_position
	var ok: bool = on_wall and snaps == ["out"] and bails == 0 and sname() == "ROLLING" and sk._floor_normal.y > 0.97 \
		and p.z > QN_COPING_Z + 3.0 + 3.0 and sk.velocity.z > 0.5 and float(r["step"]) < 1.0
	return ok_line("ramp_snap_out_quarter", ok, "on the wall %s, snaps %s, bails %d, now %s at %s moving %s, biggest step %.2f m (want rolling away on the flat, z > %.1f)"
		% [str(on_wall), str(snaps), bails, sname(), _p(p), _p(sk.velocity), r["step"], QN_COPING_Z + 6.0])


func _sim_roll_in_mega() -> Array:
	_reset_counts()
	var deck: Transform3D = park.drop_ins["mega"]
	# in the air beside the tower's start deck (18 m up), a few metres off its side
	var beside: Vector3 = deck.origin + Vector3(6.5, -4.0, 1.0)
	_air(beside, Vector3(0.0, 2.0, 0.0))
	await _fire()
	var r: Dictionary = await _watch(2.0, func() -> bool: return sk._snap.is_empty() and sname() == "ROLLING")
	var on_deck: float = sk.global_position.y
	var r2: Dictionary = await _watch(3.0, func() -> bool: return sk.global_position.y < deck.origin.y - 6.0)
	var ok: bool = snaps == ["roll_in"] and bails == 0 and absf(on_deck - deck.origin.y) < 0.3 and sk.global_position.y < deck.origin.y - 6.0 \
		and sk.speed > 8.0 and float(r["step"]) < 1.0
	return ok_line("ramp_snap_roll_in_mega", ok, "snaps %s, set down at y %.1f (deck %.1f), then at %s %.1f m/s after %.1f s, bails %d"
		% [str(snaps), on_deck, deck.origin.y, _p(sk.global_position), sk.speed, r2["t"], bails])


## A flat spot with no lip within 16 m (searched, not hand-picked), rolling and in the air.
func _sim_far_nothing() -> Array:
	_reset_counts()
	var segs: Array = sk._lip_segments()
	var spot: Vector3 = Vector3.INF
	for x: int in range(-60, 61, 4):
		for z: int in range(-60, 61, 4):
			var p := Vector3(float(x), 0.0, float(z))
			if not RampSnap.candidates(p, segs, 17.0).is_empty():
				continue
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 8.0, p + Vector3.DOWN * 2.0, 1)
			var hit: Dictionary = sk.get_world_3d().direct_space_state.intersect_ray(q)
			if hit.is_empty() or absf((hit["position"] as Vector3).y) > 0.05 or (hit["normal"] as Vector3).y < 0.99:
				continue
			# room to roll a few metres
			var q2 := PhysicsShapeQueryParameters3D.new()
			var sph := SphereShape3D.new()
			sph.radius = 3.0
			q2.shape = sph
			q2.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 3.2)
			if not sk.get_world_3d().direct_space_state.intersect_shape(q2, 1).is_empty():
				continue
			spot = p
			break
		if spot != Vector3.INF:
			break
	if spot == Vector3.INF:
		return ok_line("ramp_snap_far_nothing", false, "no flat spot 17 m from every lip found")
	place(spot + Vector3(0.0, 0.05, 0.0), Vector3.FORWARD, 4.0)
	for i: int in 5:
		await tick()
	var before: Vector3 = sk.global_position
	await _fire()
	var moved: float = sk.global_position.distance_to(before)
	var roll_ok: bool = snaps.is_empty() and misses == 1 and sname() == "ROLLING" and moved < 0.4
	# in the air: left then right three ticks later. The chord cancels the spin the left button gave.
	_air(spot + Vector3(0.0, 3.0, 0.0), Vector3(0.0, 5.0, -2.0))
	var face0: Vector3 = sk.facing
	await tick(NONE, ["spin_left"], ["spin_left"])
	await tick(NONE, [], ["spin_left"])
	await tick(NONE, [], ["spin_left"])
	await tick(NONE, ["spin_right"], CHORD)
	for i: int in 10:
		await tick(NONE, [], CHORD)  # still held: spent, no spin
	await tick()
	var turned: float = rad_to_deg(face0.angle_to(sk.facing))
	var air_ok: bool = snaps.is_empty() and misses == 2 and turned < 1.0
	return ok_line("ramp_snap_far_nothing", roll_ok and air_ok, "flat spot %s: rolling chord moved %.2f m in 3 ticks, snaps %s, misses %d, state %s; air chord turned the skater %.1f deg (want < 1)"
		% [_p(spot), moved, str(snaps), misses, sname(), turned])


func _sim_every_lip() -> Array:
	var bad: PackedStringArray = []
	var n: int = 0
	for node: Node in park.find_children("*", "RampLip", true, false):
		var lip: RampLip = node as RampLip
		var segs: Array = lip.segments()
		var s: Dictionary = segs[segs.size() / 2]
		var mid: Vector3 = ((s["a"] as Vector3) + (s["b"] as Vector3)) * 0.5
		_reset_counts()
		_air(mid + (s["inward"] as Vector3) * 4.0 + Vector3.UP * 2.5, Vector3(0.0, 1.0, 0.0) - (s["inward"] as Vector3) * 1.0)
		await _fire()
		await _watch(4.0, func() -> bool: return sk._snap.is_empty() and sname() == "ROLLING" and sk.state.time_in_state > 0.5)
		n += 1
		var nm: String = str(lip.get_parent().name) + "/" + str(lip.name)
		if snaps.size() != 1 or bails > 0 or sname() != "ROLLING" or landings.has("bail"):
			bad.append("%s: snaps %s misses %d bails %d state %s landings %s at %s" % [nm, str(snaps), misses, bails, sname(), str(landings), _p(sk.global_position)])
	return ok_line("ramp_snap_every_lip", bad.is_empty() and n >= 10, "%d lips, failures: %s" % [n, "; ".join(bad) if not bad.is_empty() else "none"])


func run() -> Array:
	var rows: Array = []
	await _setup()
	rows.append(await _sim_roll_in_quarter())
	rows.append(await _sim_air_halfpipe(false))
	rows.append(await _sim_air_halfpipe(true))
	rows.append(await _sim_out_halfpipe())
	rows.append(await _sim_out_quarter())
	rows.append(await _sim_roll_in_mega())
	rows.append(await _sim_far_nothing())
	rows.append(await _sim_every_lip())
	await clear()
	return rows
