extends "res://tests/sim/sim_base.gd"
## The nollie and the powerslide, THUG2-style, on flat ground with real physics:
##  nollie_pop         nollie button (toggles nollie stance) then a tap ollie at 4 m/s: the skater pops in anim
##                     "nollie", NOLLIE_RATIO of a tap ollie's height, lands clean, no bail; tricks in that air are named
##                     "Nollie ..."; the stance stays on after the landing
##  powerslide_decel   revert button at 10 m/s on the flat (no landing to revert): anim "powerslide", mean deceleration
##                     over 0.5 s held in SLIDE_DECEL (faster than rolling, about the foot brake or a little more), the
##                     travel line kept (turns under 25 deg with the stick hard over), no bail
##  powerslide_release letting go after the slide's minimum time: back to rolling ("idle_ride") within 0.4 s and the
##                     speed held from then on (no more scrub)
##  powerslide_stop    held: skids down to a near stop and ends by itself
##  powerslide_slow    pressed at 2 m/s (under powerslide_min_speed): no slide

const NOLLIE_RATIO: Vector2 = Vector2(0.8, 1.0)
const SLIDE_DECEL: Vector2 = Vector2(3.5, 9.0)


func _pop(nollie: bool) -> Dictionary:
	await sandbox([])
	place(Vector3(0, 0, 0), Vector3(0, 0, -1), 4.0)
	for i: int in 20:
		await tick()
	if nollie:
		await tick(NONE, ["nollie"], ["nollie"])
		await tick()
	var names: Array = []
	sk.combo.trick_added.connect(func(nm: String, _p: int) -> void: names.append(nm))
	var y0: float = sk.global_position.y
	var peak: float = y0
	var anims: Dictionary = {}
	var landed: bool = false
	await tick(NONE, ["ollie"], ["ollie"])
	for i: int in 90:
		var jp: Array = ["flip"] if i == 6 else []
		await tick(NONE, jp, [])
		anims[sk.anim] = true
		peak = maxf(peak, sk.global_position.y)
		if sk.events.has("land:clean"):
			landed = true
			break
	for i: int in 10:
		await tick()
	var res: Dictionary = {"h": peak - y0, "anims": anims, "landed": landed, "bails": bails, "names": names,
		"stance": sk.nollie}
	await clear()
	return res


func _slide(v0: float, hold: int, stick: Vector2) -> Dictionary:
	await sandbox([])
	place(Vector3(0, 0, 0), Vector3(0, 0, -1), v0)
	for i: int in 6:
		await tick()
	var sv0: float = sk.velocity.length()
	var f0: Vector3 = sk.facing
	var seen: bool = false
	var sv_half: float = -1.0
	var max_turn: float = 0.0
	var ended_at: int = -1
	for i: int in hold:
		var jp: Array = ["revert"] if i == 0 else []
		await tick(stick, jp, ["revert"])
		if sk.anim == "powerslide":
			seen = true
		if i == 29:
			sv_half = sk.velocity.length()
		max_turn = maxf(max_turn, rad_to_deg(f0.angle_to(Vector3(sk.velocity.x, 0, sk.velocity.z).normalized())) if sk.velocity.length() > 0.5 else 0.0)
		if seen and ended_at < 0 and not sk.powersliding:
			ended_at = i
	var still: bool = sk.powersliding
	var at_release: float = sk.velocity.length()
	var back_at: int = -1
	for i: int in 30:
		await tick()
		if back_at < 0 and not sk.powersliding and sk.anim != "powerslide":
			back_at = i
	var after: float = sk.velocity.length()
	var res: Dictionary = {"seen": seen, "decel": (sv0 - sv_half) / 0.5 if sv_half >= 0.0 else NAN, "turn": max_turn,
		"ended_at": ended_at, "still": still, "back_at": back_at, "release_spd": at_release, "after": after,
		"bails": bails, "v0": sv0}
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	var o: Dictionary = await _pop(false)
	var n: Dictionary = await _pop(true)
	var ratio: float = float(n["h"]) / maxf(float(o["h"]), 0.01)
	var named: bool = false
	for nm: Variant in (n["names"] as Array):
		if str(nm).begins_with("Nollie "):
			named = true
	rows.append(ok_line("nollie_pop", (n["anims"] as Dictionary).has("nollie") and ratio >= NOLLIE_RATIO.x
		and ratio <= NOLLIE_RATIO.y and bool(n["landed"]) and int(n["bails"]) == 0 and named and bool(n["stance"])
		and not (o["anims"] as Dictionary).has("nollie"),
		"nollie height %.2f m vs ollie %.2f m (ratio %.2f, want %.2f..%.2f), nollie anim %s, landed clean %s, bails %d, tricks %s, stance kept %s"
		% [n["h"], o["h"], ratio, NOLLIE_RATIO.x, NOLLIE_RATIO.y, str((n["anims"] as Dictionary).has("nollie")),
			str(n["landed"]), n["bails"], str(n["names"]), str(n["stance"])]))
	var s: Dictionary = await _slide(10.0, 30, Vector2(1.0, 0.0))
	rows.append(ok_line("powerslide_decel", bool(s["seen"]) and float(s["decel"]) >= SLIDE_DECEL.x
		and float(s["decel"]) <= SLIDE_DECEL.y and float(s["turn"]) < 25.0 and int(s["bails"]) == 0,
		"slid %s, mean decel over 0.5 s %.1f m/s^2 from %.1f m/s (want %.1f..%.1f), travel turned %.0f deg (want < 25) with the stick hard over, bails %d"
		% [str(s["seen"]), s["decel"], s["v0"], SLIDE_DECEL.x, SLIDE_DECEL.y, s["turn"], s["bails"]]))
	var r: Dictionary = await _slide(10.0, 24, NONE)
	var kept: float = float(r["after"]) / maxf(float(r["release_spd"]), 0.01)
	rows.append(ok_line("powerslide_release", bool(r["seen"]) and int(r["back_at"]) >= 0 and int(r["back_at"]) <= 24
		and kept > 0.9 and int(r["bails"]) == 0,
		"released after 0.4 s at %.1f m/s: rolling again after %d ticks (want <= 24), 0.5 s later %.1f m/s (kept %.2f, want > 0.9), bails %d"
		% [r["release_spd"], r["back_at"], r["after"], kept, r["bails"]]))
	var h: Dictionary = await _slide(6.0, 120, NONE)
	rows.append(ok_line("powerslide_stop", bool(h["seen"]) and int(h["ended_at"]) >= 0 and not bool(h["still"])
		and float(h["release_spd"]) < 1.5 and int(h["bails"]) == 0,
		"held from 6 m/s: ended by itself at tick %d, %.2f m/s at the end of the hold (want < 1.5), bails %d"
		% [h["ended_at"], h["release_spd"], h["bails"]]))
	var lo: Dictionary = await _slide(2.0, 20, NONE)
	rows.append(ok_line("powerslide_slow", not bool(lo["seen"]), "pressed at %.1f m/s: slid %s (want false)" % [lo["v0"], str(lo["seen"])]))
	return rows
