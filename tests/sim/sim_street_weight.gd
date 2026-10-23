extends "res://tests/sim/sim_base.gd"
## Round-7 grounded weight (Skate-3 arc and landing catch).
##  street_ollie_arc      a tap ollie still pops about a metre but lands in under 0.66 s (it hung 0.68 s), and a full
##                        ollie falls from its apex quicker than it rose (fall/rise under 0.92; a symmetric arc is 1.0)
##  vert_air_plain_gravity a vert launch off a 4 m quarter at 14 m/s peaks at v^2 / 2g of its launch speed (within 4%):
##                        the heavier street fall never touches vert air, so the halfpipe pump keeps its heights
##  sketchy_stagger       a sketchy landing (a full ollie spun 65 deg) staggers 0.3-0.5 s: the stick turns under 60% of
##                        a clean landing's yaw in the first 0.25 s and the speed is scrubbed (not a flat 0.8 at once)

const QP := preload("res://game/park/pieces/quarterpipe.gd")


## Ollie on the flat at 4 m/s with `hold` ticks of crouch. {h, air, rise, fall} in m and s.
func _ollie(hold: int) -> Dictionary:
	await sandbox([])
	place(Vector3(0, 0, 0), Vector3(0, 0, -1), 4.0)
	await host.get_tree().physics_frame
	for i: int in 10:
		await tick()
	var y0: float = sk.global_position.y
	for i: int in hold:
		await tick(NONE, ["ollie"] if i == 0 else [], ["ollie"])
	var peak: float = y0
	var air: int = 0
	var apex: int = 0
	var went: bool = false
	for i: int in 180:
		await tick()
		if sname() == "AIR":
			went = true
			air += 1
		elif went:
			break
		if sk.global_position.y > peak:
			peak = sk.global_position.y
			apex = air
	var d: Dictionary = {"h": peak - y0, "air": float(air) * DT, "rise": float(apex) * DT, "fall": float(air - apex) * DT}
	await clear()
	return d


func _arc() -> Array:
	var tap: Dictionary = await _ollie(1)
	var full: Dictionary = await _ollie(40)
	var ratio: float = float(full["fall"]) / maxf(float(full["rise"]), DT)
	var ok: bool = float(tap["h"]) > 0.95 and float(tap["h"]) < 1.15 and float(tap["air"]) < 0.66 and float(full["h"]) > 1.8 \
		and ratio < 0.92
	return ok_line("street_ollie_arc", ok, "tap %.2f m in %.3f s (want 0.95-1.15 m, under 0.66 s), full %.2f m, rise %.3f s fall %.3f s, fall/rise %.2f (want under 0.92)"
		% [float(tap["h"]), float(tap["air"]), float(full["h"]), float(full["rise"]), float(full["fall"]), ratio])


func _vert() -> Array:
	await sandbox([QP.build(10.0, 3.5, 4.0, 1.5)])
	place(Vector3(5.0, 0.0, 6.8), Vector3(0, 0, -1), 14.0)
	await host.get_tree().physics_frame
	var vy0: float = -1.0
	var y0: float = 0.0
	var peak: float = -INF
	var vert: bool = false
	for i: int in 240:
		await tick()
		if vy0 < 0.0 and sname() == "AIR":
			vert = sk.vert_air
			vy0 = sk.velocity.y
			y0 = sk.global_position.y
		if vy0 >= 0.0:
			if sname() != "AIR":
				break
			peak = maxf(peak, sk.global_position.y)
	var g: float = float(sk.tune.gravity)
	var want: float = vy0 * vy0 / (2.0 * g)
	var got: float = peak - y0
	var ok: bool = vert and want > 0.5 and absf(got - want) <= 0.04 * want + 0.05
	var row: Array = ok_line("vert_air_plain_gravity", ok, "vert %s, launch vy %.2f m/s, rise %.2f m (want %.2f, plain gravity)" % [str(vert), vy0, got, want])
	await clear()
	return row


## Full ollie at 8 m/s spun `deg` with the shoulder button, then full right stick from the touchdown.
func _land_run(deg: float) -> Dictionary:
	await sandbox([])
	place(Vector3(0, 0, 0), Vector3(0, 0, -1), 8.0)
	await host.get_tree().physics_frame
	for i: int in 10:
		await tick()
	for i: int in 30:
		await tick(NONE, ["ollie"] if i == 0 else [], ["ollie"])
	var n: int = roundi(deg_to_rad(deg) / (float(sk.tune.spin_rate) * DT))
	var k: int = 0
	var res: String = ""
	var before: float = 0.0
	for i: int in 120:
		var spinning: bool = sname() == "AIR" and k < n
		await tick(NONE, ["spin_left"] if spinning and k == 0 else [], ["spin_left"] if spinning else [])
		if spinning:
			k += 1
		if not landings.is_empty():
			res = str(landings[0])
			break
		before = Vector2(sk.velocity.x, sk.velocity.z).length()
	var f0: Vector3 = sk.facing
	var turned: float = 0.0
	var stag: int = 0
	for i: int in 30:
		await tick(Vector2(1.0, 0.0))
		var s: Variant = sk.get("stagger")
		if s != null and float(s) > 0.0:
			stag += 1
		if i == 14:
			turned = absf(rad_to_deg(Vector2(f0.x, f0.z).angle_to(Vector2(sk.facing.x, sk.facing.z))))
	var d: Dictionary = {"res": res, "turn": turned, "stag": float(stag + (1 if stag > 0 else 0)) * DT,
		"keep": sk.velocity.length() / maxf(before, 0.01), "bails": bails}
	await clear()
	return d


func _stagger() -> Array:
	var clean: Dictionary = await _land_run(0.0)
	var sketchy: Dictionary = await _land_run(65.0)
	var ratio: float = float(sketchy["turn"]) / maxf(float(clean["turn"]), 0.01)
	var ok: bool = clean["res"] == "clean" and sketchy["res"] == "sketchy" and float(sketchy["stag"]) >= 0.3 \
		and float(sketchy["stag"]) <= 0.5 and ratio < 0.6 and float(sketchy["keep"]) > 0.75 \
		and float(sketchy["keep"]) < float(clean["keep"]) - 0.04 and int(sketchy["bails"]) == 0
	return ok_line("sketchy_stagger", ok, "landings %s / %s, stagger %.2f s (want 0.3-0.5), yaw in 0.25 s %.1f vs clean %.1f deg (ratio %.2f, want under 0.6), speed keep after 0.5 s %.3f vs clean %.3f"
		% [clean["res"], sketchy["res"], float(sketchy["stag"]), float(sketchy["turn"]), float(clean["turn"]), ratio, float(sketchy["keep"]), float(clean["keep"])])


func run() -> Array:
	var rows: Array = []
	rows.append(await _arc())
	rows.append(await _vert())
	rows.append(await _stagger())
	return rows
