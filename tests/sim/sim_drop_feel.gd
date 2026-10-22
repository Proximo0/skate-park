extends "res://tests/sim/sim_base.gd"
## Drop-in and drop-out feel, tick by tick, with the chase camera running. Every level, real ramps and real drops.
##  drop_in_snap_<level>   Q + E standing on the deck behind a coping, on up to SNAP_LIPS lips of each level: tail on the
##                         coping, stomp, roll over onto the wall and down. The board never turns more than MAX_TURN
##                         degrees in a tick (plus what following the ramp at speed needs), the skater is never airborne between the stomp and the flat, the speed only
##                         builds (no step up or down past what gravity gives in a tick), the bottom speed is at least
##                         BOTTOM_SHARE of a free roll from the coping, and the camera never jerks (MAX_CAM_DEG,
##                         MAX_CAM_STEP).
##  drop_in_roll_<spot>    rolling slowly off a deck over a coping or a roll-in edge (no buttons): the same, plus no
##                         "air" at all.
##  drop_off_<h>m_<v>      rolling off a ledge h m high at v m/s with no ollie: one flight, one landing, no bounce, the
##                         board's nose dips toward the fall then levels (lands within LAND_TILT_DEG of the ground), keeps
##                         at least LAND_KEEP of the speed along the ground, camera smooth.
##  drop_off_<level>       the same on real drops found in each level (edges with flat run-up and flat landing).

const CHORD: Array = ["spin_left", "spin_right"]
const LEVELS: Array[String] = ["practice", "warehouse", "beach", "school", "downtown", "hills"]
const SNAP_LIPS: int = 6  ## lips tried per level (spread over its lips)
const MAX_TURN: float = 6.5  ## deg the board's up may turn in one tick (past 0.5 deg per m/s over 2 m/s)
const MAX_CAM_DEG: float = 8.0  ## deg the camera may turn in one tick
const MAX_CAM_STEP: float = 0.7  ## m the camera may move in one tick
const BOTTOM_SHARE: float = 0.7
const LAND_TILT_DEG: float = 12.0
const LAND_KEEP: float = 0.88
const HEIGHTS: Array = [0.5, 1.2, 2.0, 3.0]
const SPEEDS: Array = [3.0, 6.0, 10.0]
const LEVEL_DROPS: int = 2  ## real drops tried per level
const SETTLE: int = 6  ## ticks after a placement the camera is allowed to settle (a respawn snaps it)

var cam: SkateCamera
var snaps: Array = []


func _attach_camera() -> void:
	cam = SkateCamera.new()
	cam.name = "SimCam"
	cam.target = sk
	root3.add_child(cam)
	sk.ramp_snapped.connect(func(m: String) -> void: snaps.append(m))


## Per-tick watcher. Call begin() after placing, then step() every tick; read the stats.
class Watch:
	var bu: Vector3
	var cb: Basis
	var cp: Vector3
	var spd: float
	var n: int = 0
	var max_turn: float = 0.0
	var max_turn_tick: int = -1
	var max_cam: float = 0.0
	var max_cam_tick: int = -1
	var max_cam_step: float = 0.0
	var max_gain: float = 0.0  ## biggest speed rise in a tick past gravity's
	var max_drop: float = 0.0  ## biggest speed fall in a tick
	var events: Array[String] = []
	var settle: int = 0

	func begin(sk: Variant, cam: Camera3D, settle_ticks: int) -> void:
		bu = sk.board_up
		cb = cam.global_transform.basis
		cp = cam.global_position
		spd = sk.velocity.length()
		settle = settle_ticks

	func step(sk: Variant, cam: Camera3D, g: float, track_speed: bool) -> void:
		n += 1
		# the board's turn past what riding real geometry at this speed needs (a toe kink at 8 m/s is 8 degrees)
		var turn: float = rad_to_deg(bu.angle_to(sk.board_up)) - maxf(0.5 * sk.velocity.length() - 1.0, 0.0)
		if turn > max_turn:
			max_turn = turn
			max_turn_tick = n
		bu = sk.board_up
		var b: Basis = cam.global_transform.basis
		if n > settle:
			var q: Quaternion = (cb.orthonormalized().inverse() * b.orthonormalized()).get_rotation_quaternion()
			if rad_to_deg(q.get_angle()) > max_cam:
				max_cam = rad_to_deg(q.get_angle())
				max_cam_tick = n
			max_cam_step = maxf(max_cam_step, cp.distance_to(cam.global_position))
		cb = b
		cp = cam.global_position
		var s: float = sk.velocity.length()
		if track_speed:
			max_gain = maxf(max_gain, s - spd - g / 60.0)
			max_drop = maxf(max_drop, spd - s)
		spd = s
		for e: String in sk.events:
			events.append("%d:%s" % [n, e])

	func cam_ok() -> bool:
		return max_cam <= MAX_CAM_DEG and max_cam_step <= MAX_CAM_STEP

	func cam_str() -> String:
		return "camera max %.1f deg/tick (tick %d) %.2f m/tick" % [max_cam, max_cam_tick, max_cam_step]


func _level(id: String) -> Node3D:
	root3 = Node3D.new()
	host.add_child(root3)
	var lvl: Node3D
	if id == "practice":
		lvl = (load("res://game/park/park.gd") as GDScript).new()
	else:
		lvl = LevelRegistry.create(id)
	lvl.name = "Park"
	root3.add_child(lvl)
	await attach_skater()
	_attach_camera()
	for i: int in 4:
		await tick()
	return lvl


func _ray_down(p: Vector3, up: float, down: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * up, p + Vector3.DOWN * down, 1)
	return sk.get_world_3d().direct_space_state.intersect_ray(q)


## Where the skater's sphere comes to rest dropped onto `p` from a metre up: its bottom's height (or -INF).
func _rest_y(p: Vector3) -> float:
	var sph := SphereShape3D.new()
	sph.radius = 0.3
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.3)
	q.motion = Vector3.DOWN * 3.0
	q.collision_mask = 1
	var f: PackedFloat32Array = sk.get_world_3d().direct_space_state.cast_motion(q)
	if f.size() < 2 or f[0] >= 1.0:
		return -INF
	return p.y + 1.3 - 3.0 * f[0] - 0.3


func _clear(p: Vector3, r: float = 0.35) -> bool:
	var sph := SphereShape3D.new()
	sph.radius = r
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * (r + 0.05))
	q.collision_mask = 1
	return sk.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _start(pos: Vector3, dir: Vector3, speed: float) -> void:
	sk.respawn()
	place(pos, dir, speed)
	snaps = []
	bails = 0
	landings = []
	cam.snap()


## Q + E from the deck behind the middle of `seg`. Returns [ok, detail] or [] when the lip has no deck to stand on.
func _deck_snap(seg: Dictionary) -> Array:
	var a: Vector3 = seg["a"]
	var b: Vector3 = seg["b"]
	var lip: Vector3 = (a + b) * 0.5
	var inward: Vector3 = seg["inward"]
	var stand: Vector3 = lip - inward * 0.9
	var hit: Dictionary = _ray_down(stand, 0.6, 1.0)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.97 or absf((hit["position"] as Vector3).y - lip.y) > 0.15:
		return []
	var p: Vector3 = (hit["position"] as Vector3) + Vector3.UP * 0.02
	if not _clear(p) or a.distance_to(b) < 1.6:
		return []
	_start(p, inward, 0.0)
	for i: int in 6:
		await tick()
	var w := Watch.new()
	w.begin(sk, cam, SETTLE)
	await tick(NONE, CHORD, CHORD)
	w.step(sk, cam, sk.tune.gravity, false)
	await tick(NONE, [], CHORD)
	w.step(sk, cam, sk.tune.gravity, false)
	var released: bool = false
	var air_after: int = 0
	var bottom_speed: float = 0.0
	var ok_end: bool = false
	for i: int in 300:
		await tick()
		var was: bool = released
		released = released or sk.events.has("ramp_snap_release")
		w.step(sk, cam, sk.tune.gravity, was)
		if released and sname() == "AIR":
			air_after += 1
		if released and sname() == "ROLLING" and sk._floor_normal.y > 0.97 and sk.global_position.y < lip.y - 0.5:
			bottom_speed = sk.velocity.length()
			ok_end = true
			break
		if bails > 0:
			break
	var drop_h: float = lip.y - sk.global_position.y
	var free: float = sqrt(2.0 * sk.tune.gravity * maxf(drop_h, 0.0))
	var ok: bool = snaps == ["drop_in"] and released and ok_end and bails == 0 and air_after == 0 \
		and w.max_turn <= MAX_TURN and w.max_gain <= 0.35 and w.max_drop <= 0.6 and bottom_speed >= free * BOTTOM_SHARE \
		and w.cam_ok()
	return [ok, "snaps %s, released %s, reached the flat %s, air ticks after the stomp %d, bails %d, board turn max %.1f deg (tick %d), speed step up %.2f down %.2f, bottom %.1f m/s (free roll %.1f), %s"
		% [str(snaps), str(released), str(ok_end), air_after, bails, w.max_turn, w.max_turn_tick, w.max_gain, w.max_drop, bottom_speed, free, w.cam_str()]]


func _snap_level(id: String) -> Array:
	await _level(id)
	var segs: Array = []
	for n: Node in host.get_tree().get_nodes_in_group("ramp_lip"):
		var lip: RampLip = n as RampLip
		if lip != null and lip.is_inside_tree() and lip.kind == "drop_in":
			var ss: Array = lip.segments()
			if not ss.is_empty():
				segs.append(ss[ss.size() / 2])
	var tried: int = 0
	var bad: PackedStringArray = []
	var stride: int = maxi(1, ceili(float(segs.size()) / float(SNAP_LIPS * 2)))
	var i: int = 0
	while i < segs.size() and tried < SNAP_LIPS:
		var r: Array = await _deck_snap(segs[i])
		i += stride
		if r.is_empty():
			continue
		tried += 1
		if not r[0]:
			bad.append("lip at %s: %s" % [_p(((segs[i - stride]["a"] as Vector3) + (segs[i - stride]["b"] as Vector3)) * 0.5), r[1]])
	await clear()
	if tried == 0:
		return ok_line("drop_in_snap_" + id, null, "no coping with a deck behind it to stand on")
	return ok_line("drop_in_snap_" + id, bad.is_empty(), "%d copings, failures: %s" % [tried, "; ".join(bad) if not bad.is_empty() else "none"])


## Roll slowly off a deck into its ramp: from `pos` along `dir` at `speed`, no buttons, until on the flat below.
func _roll_in(name: String, lvl_id: String, pos: Vector3, dir: Vector3, speed: float, top_y: float) -> Array:
	await _level(lvl_id)
	_start(pos, dir, speed)
	var w := Watch.new()
	w.begin(sk, cam, SETTLE * 3)  # placed on a deck by a fence: the first frames are the camera's teleport
	var airs: int = 0
	var ok_end: bool = false
	var bottom: float = 0.0
	var started: bool = false
	for i: int in 400:
		await tick()
		w.step(sk, cam, sk.tune.gravity, started)
		started = i > SETTLE
		if i > SETTLE and sk.events.has("air"):
			airs += 1
		if sname() == "ROLLING" and sk._floor_normal.y > 0.97 and sk.global_position.y < top_y - 1.0:
			ok_end = true
			bottom = sk.velocity.length()
			break
	var drop_h: float = top_y - sk.global_position.y
	var free: float = sqrt(2.0 * sk.tune.gravity * maxf(drop_h, 0.0))
	await clear()
	var ok: bool = ok_end and airs == 0 and bails == 0 and w.max_turn <= MAX_TURN and w.max_drop <= 0.6 \
		and bottom >= free * BOTTOM_SHARE and w.cam_ok()
	return ok_line("drop_in_roll_" + name, ok, "reached the flat %s, airborne %d times (want 0), bails %d, board turn max %.1f deg (tick %d), speed step down %.2f, bottom %.1f m/s (free roll %.1f), %s"
		% [str(ok_end), airs, bails, w.max_turn, w.max_turn_tick, w.max_drop, bottom, free, w.cam_str()])


## Roll off the edge at `edge` (top surface height edge.y) along `dir` at `speed`, no ollie. Returns the stats.
func _roll_off(edge: Vector3, dir: Vector3, speed: float, low_y: float) -> Dictionary:
	_start(edge - dir * 3.0 + Vector3.UP * 0.02, dir, speed)
	for i: int in 3:
		await tick()
	sk.velocity = dir * speed  # the placement's settle tick bleeds a little
	var w := Watch.new()
	w.begin(sk, cam, SETTLE)
	var flights: int = 0
	var was_air: bool = false
	var landed_at: int = -1
	var pre: float = 0.0
	var post: float = 0.0
	var tilt: float = 0.0
	var max_pitch: float = 0.0
	var off_ground_after: int = 0
	for i: int in 240:
		await tick()
		w.step(sk, cam, sk.tune.gravity, false)
		var air: bool = sname() == "AIR"
		if air and not was_air:
			flights += 1
			pre = Vector2(sk.velocity.x, sk.velocity.z).length()
		if air:
			var f: Vector3 = sk.facing.slide(sk.board_up).normalized()
			max_pitch = maxf(max_pitch, rad_to_deg(asin(clampf(-f.y, -1.0, 1.0))))
		if was_air and not air and landed_at < 0:
			landed_at = i
			tilt = rad_to_deg(sk.board_up.angle_to(sk._floor_normal))
		if landed_at >= 0 and i == landed_at + 6:
			post = sk.velocity.slide(sk._floor_normal).length()
		if landed_at >= 0 and i > landed_at and i <= landed_at + 30 and not sk.is_on_floor():
			off_ground_after += 1
		was_air = air
		if landed_at >= 0 and i >= landed_at + 30:
			break
	return {"flights": flights, "landed": landed_at >= 0, "tilt": tilt, "pre": pre, "post": post, "bounce": off_ground_after,
		"bails": bails, "w": w, "pitch": max_pitch, "land": landings.duplicate(), "low": absf(sk.global_position.y - low_y) < 0.3}


func _judge_drop(r: Dictionary) -> Array:
	var w: Watch = r["w"]
	var keep: float = float(r["post"]) / maxf(float(r["pre"]), 0.01)
	var ok: bool = r["landed"] and int(r["flights"]) == 1 and int(r["bounce"]) == 0 and int(r["bails"]) == 0 \
		and float(r["tilt"]) <= LAND_TILT_DEG and keep >= LAND_KEEP and keep <= 1.05 and w.max_turn <= MAX_TURN and w.cam_ok() \
		and (r["land"] as Array).size() >= 1 and str((r["land"] as Array)[0]) == "clean" and bool(r["low"])
	return [ok, "flights %d (want 1), landed %s %s, ticks off the ground after (bounce) %d, bails %d, nose dip max %.1f deg, board vs ground at touchdown %.1f deg, speed along the ground kept %.2f (%.1f -> %.1f), board turn max %.1f deg, %s"
		% [r["flights"], str(r["landed"]), str(r["land"]), r["bounce"], r["bails"], r["pitch"], r["tilt"], keep, r["pre"], r["post"], w.max_turn, w.cam_str()]]


func _sandbox_drops() -> Array:
	var rows: Array = []
	for h: float in HEIGHTS:
		var hi: Node3D = PieceKit.box(Vector3(-40, h - 1.0, -10), Vector3(40, 1.0, 20), PieceKit.CONCRETE, "High")
		var lo: Node3D = PieceKit.box(Vector3(0, -1, -10), Vector3(60, 1.0, 20), PieceKit.CONCRETE, "Low")
		await sandbox([hi, lo], false)
		_attach_camera()
		for v: float in SPEEDS:
			var r: Dictionary = await _roll_off(Vector3(0.0, h, 0.0), Vector3(1, 0, 0), v, 0.0)
			var j: Array = _judge_drop(r)
			rows.append(ok_line("drop_off_%.1fm_%dms" % [h, int(v)], j[0], j[1]))
		await clear()
	return rows


## Edges in the level with a flat run-up and a flat landing 0.4 to 3 m lower, found by rays on a grid. [[edge, dir, low_y]]
func _find_drops(lvl: Level) -> Array:
	var out: Array = []
	var r: Rect2 = lvl.bounds
	var dirs: Array = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var step: float = 3.0
	var x: float = r.position.x + 4.0
	while x < r.end.x - 4.0 and out.size() < 40:
		var z: float = r.position.y + 4.0
		while z < r.end.y - 4.0 and out.size() < 40:
			for d: Vector3 in dirs:
				var top: Dictionary = _ray_down(Vector3(x, 40.0, z), 0.0, 60.0)
				if top.is_empty() or (top["normal"] as Vector3).y < 0.99:
					continue
				var ty: float = (top["position"] as Vector3).y
				var ok_run: bool = true
				for k: float in [-3.0, -2.0, -1.0, -0.4]:
					var h0: Dictionary = _ray_down(Vector3(x, ty, z) + d * k, 0.5, 0.5)
					if h0.is_empty() or (h0["normal"] as Vector3).y < 0.99 or absf((h0["position"] as Vector3).y - ty) > 0.03 \
							or absf(_rest_y(Vector3(x, ty, z) + d * k) - ty) > 0.03:
						ok_run = false
				if not ok_run:
					continue
				var below: Dictionary = _ray_down(Vector3(x, ty, z) + d * 0.6, 0.2, 4.0)
				if below.is_empty():
					continue
				var ly: float = (below["position"] as Vector3).y
				var drop: float = ty - ly
				if drop < 0.45 or drop > 3.0:
					continue
				var ok_land: bool = true
				for k: float in [1.0, 2.0, 3.0, 4.5, 6.0]:
					var h1: Dictionary = _ray_down(Vector3(x, ly, z) + d * k, 0.3, 0.5)
					if h1.is_empty() or (h1["normal"] as Vector3).y < 0.99 or absf((h1["position"] as Vector3).y - ly) > 0.05:
						ok_land = false
				if not ok_land or not _clear(Vector3(x, ty, z) - d * 2.0, 0.5) or not _clear(Vector3(x, ly, z) + d * 2.5, 0.5):
					continue
				# find the edge itself: march to where the top stops
				var e: float = -0.4
				while e < 0.7:
					var h2: Dictionary = _ray_down(Vector3(x, ty, z) + d * e, 0.2, 0.2)
					if h2.is_empty():
						break
					e += 0.05
				out.append([Vector3(x, ty, z) + d * (e - 0.05), d, ly, drop])
			z += step
		x += step
	return out


func _level_drops(id: String) -> Array:
	var lvl: Node3D = await _level(id)
	var found: Array = _find_drops(lvl as Level) if lvl is Level else []
	# spread the picks over the drop heights found
	found.sort_custom(func(p: Array, q: Array) -> bool: return float(p[3]) < float(q[3]))
	var picks: Array = []
	for k: int in LEVEL_DROPS:
		if found.is_empty():
			break
		picks.append(found[mini(found.size() - 1, int(float(found.size() - 1) * float(k + 1) / float(LEVEL_DROPS + 1)))])
	var bad: PackedStringArray = []
	var done: PackedStringArray = []
	for d: Array in picks:
		var r: Dictionary = await _roll_off(d[0], d[1], 6.0, d[2])
		var j: Array = _judge_drop(r)
		done.append("%.1f m at %s" % [d[3], _p(d[0])])
		if not j[0]:
			bad.append("%.1f m drop at %s: %s" % [d[3], _p(d[0]), j[1]])
	await clear()
	if picks.is_empty():
		return ok_line("drop_off_" + id, null, "no clean drop found to test")
	return ok_line("drop_off_" + id, bad.is_empty(), "%s; failures: %s" % [", ".join(done), "; ".join(bad) if not bad.is_empty() else "none"])


func _p(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


func run() -> Array:
	var rows: Array = []
	for id: String in LEVELS:
		rows.append(await _snap_level(id))
	# natural drop-ins: off the half pipe's deck over its coping, off the mega ramp's start deck down its roll-in
	rows.append(await _roll_in("halfpipe_coping", "practice", Vector3(-33.0, 4.05, -39.5), Vector3(0, 0, 1), 2.0, 4.0))
	rows.append(await _roll_in("quarter_coping", "practice", Vector3(1.0, 3.25, -39.7), Vector3(0, 0, 1), 1.5, 3.2))
	var mega: Transform3D = Transform3D(Basis.IDENTITY, Park.MEGA_POS) * MegaRamp.drop_in_transform(8.0, 18.0)
	rows.append(await _roll_in("mega_rollin", "practice", mega.origin + Vector3.UP * 0.05, -mega.basis.z, 2.5, mega.origin.y))
	rows.append_array(await _sandbox_drops())
	for id: String in LEVELS:
		if id != "practice":
			rows.append(await _level_drops(id))
	return rows
