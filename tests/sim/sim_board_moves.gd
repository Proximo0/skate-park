extends "res://tests/sim/sim_base.gd"
## THUG2 board moves (round 4) with real physics. The lab (tests/lab/lab_moves.gd) reuses the scenario coroutines.
##  boneless_pop      up, up + ollie at 4 m/s on the flat: anim "boneless", the pop waits for the foot plant (BONELESS_WAIT
##                    ticks after the release), goes BONELESS_RATIO of a full-crouch ollie's height, lands clean
##  no_comply_pop     up + ollie: anim "no_comply", a short plant, NO_COMPLY_RATIO of a tap ollie's height, lands clean
##  push_ollie_plain  holding up to push, then a tap ollie: a plain ollie (an old up hold is not a no-comply tap)
##  wallplant         a full ollie into an upright wall, ollie again near it: anim "wallplant", the speed into the wall
##                    killed (under 1 m/s left at the push), then pushed back out (over 2.5 m/s away) with a pop that
##                    rises again, landing rolling away from the wall without a bail
##  caveman           on foot: jump (ollie), ollie again in the air: anim "caveman", lands ROLLING at 4.5 m/s or more
##                    within 1 s, no bail
##  acid_drop         off a quarter pipe's deck over its coping, revert over the face: anim "acid_drop", rolling on the
##                    transition (not the flat) and the energy kept (speed over sqrt(v^2 + 2 g drop) at least ACID_KEEP),
##                    faster than the same air without the press, no bail

const QP := preload("res://game/park/pieces/quarterpipe.gd")
const BONELESS_RATIO: Vector2 = Vector2(1.1, 1.35)
const BONELESS_WAIT: Vector2i = Vector2i(5, 10)
const NO_COMPLY_RATIO: Vector2 = Vector2(0.8, 1.0)
const ACID_KEEP: float = 0.9
const WALL_Z: float = -9.0  ## the wall's face (it looks along +Z)


func _seen(anims: Dictionary, a: String) -> bool:
	return anims.has(a)


## A pop on the flat at 4 m/s. `taps`: stick script before the press, as [[stick, ticks], ...]; the press comes with
## `press_stick` held, the ollie held `hold` ticks. Returns {h, anims, landed, bails, wait (ticks from release to air)}.
func pop(taps: Array, press_stick: Vector2, hold: int) -> Dictionary:
	await sandbox([])
	place(Vector3(0, 0, 0), Vector3(0, 0, -1), 4.0)
	for i: int in 20:
		await tick()
	for t: Array in taps:
		for i: int in int(t[1]):
			await tick(t[0])
	var y0: float = sk.global_position.y
	var peak: float = y0
	var anims: Dictionary = {}
	for i: int in hold:
		await tick(press_stick, ["ollie"] if i == 0 else [], ["ollie"])
		anims[sk.anim] = true
	var wait: int = -1
	var landed: bool = false
	for i: int in 120:
		await tick(press_stick if i < 2 else NONE)
		anims[sk.anim] = true
		if wait < 0 and sname() == "AIR":
			wait = i
		peak = maxf(peak, sk.global_position.y)
		if wait >= 0 and (sk.events.has("land:clean") or sk.events.has("land:sketchy")):
			landed = sk.events.has("land:clean")
			break
	var res: Dictionary = {"h": peak - y0, "anims": anims, "landed": landed, "bails": bails, "wait": wait}
	await clear()
	return res


func boneless() -> Dictionary:
	return await pop([[FWD, 3], [NONE, 3]], FWD, 1)


func no_comply() -> Dictionary:
	return await pop([], FWD, 1)


func tap_ollie() -> Dictionary:
	return await pop([], NONE, 1)


func full_ollie() -> Dictionary:
	return await pop([], NONE, 24)


## A full ollie at 7 m/s at an upright wall, ollie pressed again as it comes in reach.
func wallplant(press: bool = true) -> Dictionary:
	await sandbox([PieceKit.box(Vector3(-6, 0, WALL_Z - 1.0), Vector3(12, 5, 1), PieceKit.CONCRETE, "Wall")])
	place(Vector3(0, 0, -1.0), Vector3(0, 0, -1), 7.0)
	await tick()
	var anims: Dictionary = {}
	var into_at_push: float = NAN
	var out_after: float = NAN
	var vy_after: float = NAN
	var plant_y: float = NAN
	var peak_after: float = -INF
	var pushed: bool = false
	var pressed: bool = false
	var result: String = ""
	var away: float = NAN
	for i: int in 24:
		await tick(NONE, ["ollie"] if i == 0 else [], ["ollie"])
	for i: int in 150:
		var jp: Array = []
		if press and not pressed and sname() == "AIR" and sk.global_position.z < WALL_Z + 1.6:
			jp = ["ollie"]
			pressed = true
		var vz_before: float = sk.velocity.z
		await tick(NONE, jp, jp)
		anims[sk.anim] = true
		if sk.events.has("wallplant"):
			plant_y = sk.global_position.y
		if sk.events.has("wallplant_push"):
			pushed = true
			into_at_push = -vz_before
			out_after = sk.velocity.z
			vy_after = sk.velocity.y
		if pushed:
			peak_after = maxf(peak_after, sk.global_position.y)
		for e: String in sk.events:
			if e.begins_with("land:"):
				result = e.substr(5)
		if result != "":
			for k: int in 20:
				await tick()
			away = sk.velocity.z
			break
	var res: Dictionary = {"anims": anims, "into": into_at_push, "out": out_after, "vy": vy_after, "rise": peak_after - plant_y,
		"result": result, "bails": bails, "state": sname(), "away": away}
	await clear()
	return res


## On foot at a run: jump, then ollie again `delay` ticks later.
func caveman(delay: int = 10) -> Dictionary:
	await sandbox([])
	place(Vector3(0, 0, 0), Vector3(0, 0, -1), 2.0)
	for i: int in 5:
		await tick()
	await tick(NONE, ["dismount"], ["dismount"])
	for i: int in 40:
		await tick(FWD)
	var walked: bool = sname() == "WALK"
	await tick(FWD, ["ollie"], ["ollie"])
	var anims: Dictionary = {}
	var rolled_at: int = -1
	var states: Dictionary = {}
	for i: int in 90:
		await tick(FWD if i < delay else NONE, ["ollie"] if i == delay else [], ["ollie"] if i == delay else [])
		anims[sk.anim] = true
		states[sname()] = true
		if i > delay and sname() == "ROLLING":
			rolled_at = i - delay
			break
	for i: int in 6:
		await tick()
	var res: Dictionary = {"walked": walked, "anims": anims, "rolled_at": rolled_at, "speed": sk.velocity.length(),
		"bails": bails, "states": states}
	await clear()
	return res


## Off a 3 m quarter pipe's deck (riding +Z over its coping at z = 2) with a tap ollie; revert over the face if `press`.
## Returns the speed just after touching down, the expected energy speed, where and how it landed.
func acid(press: bool) -> Dictionary:
	await sandbox([QP.build(10.0, 3.0, 3.0, 2.0)])
	place(Vector3(5.0, 3.0, 0.3), Vector3(0, 0, 1), 6.0)
	for i: int in 3:
		await tick()
	var anims: Dictionary = {}
	await tick(NONE, ["ollie"], ["ollie"])
	await tick()
	var v_press: float = NAN
	var y_press: float = NAN
	var pressed: bool = false
	var touch_spd: float = NAN
	var touch_ny: float = NAN
	var touch_y: float = NAN
	var ideal: float = NAN
	var g: float = float(sk.tune.gravity)
	for i: int in 120:
		var jp: Array = []
		if press and not pressed and sname() == "AIR" and sk.global_position.z > 2.6:
			jp = ["revert"]
			pressed = true
			v_press = sk.velocity.length()
			y_press = sk.global_position.y
		await tick(NONE, jp, jp)
		anims[sk.anim] = true
		if sname() == "ROLLING" or sname() == "BAIL":
			touch_spd = sk.velocity.length()
			touch_ny = float(sk._floor_normal.y)
			touch_y = sk.global_position.y
			if pressed:
				ideal = sqrt(v_press * v_press + 2.0 * g * maxf(y_press - touch_y, 0.0))
			break
	var res: Dictionary = {"anims": anims, "spd": touch_spd, "ny": touch_ny, "ideal": ideal, "bails": bails,
		"state": sname(), "v_press": v_press}
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	var full: Dictionary = await full_ollie()
	var tap: Dictionary = await tap_ollie()
	var b: Dictionary = await boneless()
	var br: float = float(b["h"]) / maxf(float(full["h"]), 0.01)
	rows.append(ok_line("boneless_pop", _seen(b["anims"], "boneless") and br >= BONELESS_RATIO.x and br <= BONELESS_RATIO.y
		and int(b["wait"]) >= BONELESS_WAIT.x and int(b["wait"]) <= BONELESS_WAIT.y and bool(b["landed"]) and int(b["bails"]) == 0,
		"up, up + ollie: anim boneless %s, %.2f m vs full ollie %.2f m (ratio %.2f, want %.2f..%.2f), pop %d ticks after release (want %d..%d), clean %s, bails %d"
		% [str(_seen(b["anims"], "boneless")), b["h"], full["h"], br, BONELESS_RATIO.x, BONELESS_RATIO.y, b["wait"],
			BONELESS_WAIT.x, BONELESS_WAIT.y, str(b["landed"]), b["bails"]]))
	var nc: Dictionary = await no_comply()
	var nr: float = float(nc["h"]) / maxf(float(tap["h"]), 0.01)
	rows.append(ok_line("no_comply_pop", _seen(nc["anims"], "no_comply") and not _seen(nc["anims"], "boneless")
		and nr >= NO_COMPLY_RATIO.x and nr <= NO_COMPLY_RATIO.y and int(nc["wait"]) >= 2 and bool(nc["landed"]) and int(nc["bails"]) == 0,
		"up + ollie: anim no_comply %s, %.2f m vs tap ollie %.2f m (ratio %.2f, want %.2f..%.2f), pop %d ticks after release, clean %s, bails %d"
		% [str(_seen(nc["anims"], "no_comply")), nc["h"], tap["h"], nr, NO_COMPLY_RATIO.x, NO_COMPLY_RATIO.y, nc["wait"],
			str(nc["landed"]), nc["bails"]]))
	var pu: Dictionary = await pop([[FWD, 30]], FWD, 1)
	rows.append(ok_line("push_ollie_plain", _seen(pu["anims"], "ollie") and not _seen(pu["anims"], "no_comply")
		and not _seen(pu["anims"], "boneless") and int(pu["wait"]) <= 1,
		"held up 0.5 s (pushing) then tap ollie: anims %s, pop %d ticks after release (want a plain ollie, <= 1)"
		% [str(pu["anims"].keys()), pu["wait"]]))
	var w: Dictionary = await wallplant()
	rows.append(ok_line("wallplant", _seen(w["anims"], "wallplant") and float(w["into"]) < 1.0 and float(w["out"]) > 2.5
		and float(w["vy"]) > 4.0 and float(w["rise"]) > 0.6 and str(w["result"]) in ["clean", "sketchy"] and int(w["bails"]) == 0
		and float(w["away"]) > 1.0,
		"anim wallplant %s, into the wall at the push %.2f m/s (want < 1), out %.2f m/s (want > 2.5), up %.2f m/s, rose %.2f m, landed %s rolling away %.2f m/s, bails %d"
		% [str(_seen(w["anims"], "wallplant")), w["into"], w["out"], w["vy"], w["rise"], w["result"], w["away"], w["bails"]]))
	var c: Dictionary = await caveman()
	rows.append(ok_line("caveman", bool(c["walked"]) and _seen(c["anims"], "caveman") and int(c["rolled_at"]) >= 0
		and int(c["rolled_at"]) <= 60 and float(c["speed"]) >= 4.5 and int(c["bails"]) == 0,
		"walking %s, anim caveman %s, rolling %d ticks after the second press (want <= 60), %.2f m/s (want >= 4.5), states %s, bails %d"
		% [str(c["walked"]), str(_seen(c["anims"], "caveman")), c["rolled_at"], c["speed"], str(c["states"].keys()), c["bails"]]))
	var a: Dictionary = await acid(true)
	var a0: Dictionary = await acid(false)
	var keep: float = float(a["spd"]) / maxf(float(a["ideal"]), 0.01)
	rows.append(ok_line("acid_drop", _seen(a["anims"], "acid_drop") and str(a["state"]) == "ROLLING" and float(a["ny"]) < 0.97
		and keep >= ACID_KEEP and float(a["spd"]) > float(a0["spd"]) and int(a["bails"]) == 0,
		"anim acid_drop %s, touched down %s on a face ny %.2f (want < 0.97) at %.2f m/s = %.2f of the energy speed %.2f (want >= %.2f); without the press %s at %.2f m/s (ny %.2f), bails %d"
		% [str(_seen(a["anims"], "acid_drop")), a["state"], a["ny"], a["spd"], keep, a["ideal"], ACID_KEEP, a0["state"],
			a0["spd"], a0["ny"], a["bails"]]))
	return rows
