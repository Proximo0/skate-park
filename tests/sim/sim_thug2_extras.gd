extends "res://tests/sim/sim_base.gd"
## THUG2's signature extras (round 8) with real physics.
##  natas_spin        a tap-crouch ollie over a 0.3 m post (a bollard), grind pressed above it: stands on the post's top
##                    (state LIP, balance "natas", held within 0.1 m of the top), spin_right held 1.1 s turns it 360 or
##                    more, scored per 180 with the direction ("FS 360 Natas" or more), ollie pops off and lands, no bail
##  natas_wide_box    the same over a 1.4 m wide box: no natas (a box top is not a post)
##  sticker_slap      riding along a wall at 7 m/s, ollie, ollie again beside it: event sticker_slap (no wallplant), the
##                    speed along the wall kept (>= 0.95), pushed out of it and up (> 3 m/s), lands rolling, no bail
##  sticker_no_wall   the same second ollie with no wall beside: nothing
##  bert_slide        across a 30 degree bank at 7 m/s, revert: event bert_slide, the travel turns 50 degrees or more in
##                    0.6 s and loses more energy (speed and height) than the same ride without the press, rolling at the end, no bail
##  bert_not_on_flat  revert on the flat is still a powerslide, never a bert slide
##  skitch_tow        rolling up behind a stopped car, grab held: towed as it pulls away (state MANUAL, balance "skitch"),
##                    within 0.5 m/s of its speed after 4 s, never closer than 0.2 m to its bumper or over 1.2 m back (from 0.5 s in),
##                    letting go keeps 0.95 of the car's speed, scored "Skitch", no bail
##  skitch_no_car     grab on the flat with no car near: no skitch
##  focus_toggle      the focus button does nothing on an empty meter; on a full one it turns focus on, drains the meter,
##                    turns off when pressed again; the engine clock is never touched in a scripted run, and a ride with
##                    focus on is the same tick for tick as one without (physics deterministic)

const TrafficCarScript := preload("res://game/world/traffic_car.gd")
const POST_Z: float = -3.4
const WALL_X: float = 1.0
const BANK_H: float = 5.0
const BANK_DEG: float = 30.0


func _names() -> String:
	var out: PackedStringArray = []
	for e: Dictionary in sk.combo._tricks:
		out.append(str(e.get("name", "")))
	return ", ".join(out)


func _bal_x() -> float:
	return -clampf(3.0 * sk.balance.angle + 1.1 * sk.balance.velocity, -1.0, 1.0)


## Ollie at 3 m/s toward a post (or box) `width` wide and 0.9 m tall at POST_Z, grind pressed above it, spin held, ollie off.
func natas(width: float) -> Dictionary:
	await sandbox([PieceKit.box(Vector3(-width * 0.5, 0.0, POST_Z - width * 0.5), Vector3(width, 0.9, width), PieceKit.CONCRETE, "Post")])
	place(Vector3(0, 0, 0), Vector3(0, 0, -1), 3.0)
	for i: int in 5:
		await tick()
	for i: int in 14:
		await tick(NONE, ["ollie"] if i == 0 else [], ["ollie"])
	var on_post: int = 0
	var worst_dy: float = 0.0
	var pressed: bool = false
	var started: bool = false
	var spun_ticks: int = 0
	var popped: bool = false
	var result: String = ""
	var kind: String = ""
	var names: String = ""
	for i: int in 260:
		var jp: Array = []
		var held: Array = []
		var stick: Vector2 = NONE
		if not pressed and sname() == "AIR" and sk.global_position.z < POST_Z + 0.7 and sk.global_position.y > 0.9:
			jp = ["grind"]
			pressed = true
		if sname() == "LIP":
			stick = Vector2(_bal_x(), 0.0)
			if spun_ticks < 66:
				held = ["spin_right"]
				spun_ticks += 1
			elif not popped:
				jp = ["ollie"]
				held = ["ollie"]
				popped = true
		await tick(stick, jp, held)
		if sname() == "LIP":
			started = true
			kind = sk.balance_kind
			on_post += 1
			worst_dy = maxf(worst_dy, absf(sk.global_position.y - 0.9))
		names = _names() if sk.combo.is_active() else names
		for e: String in sk.events:
			if e.begins_with("land:"):
				result = e.substr(5)
		if result != "":
			break
	var res: Dictionary = {"started": started, "kind": kind, "on_post": on_post, "dy": worst_dy, "names": names,
		"result": result, "bails": bails, "popped": popped}
	await clear()
	return res


## Riding -z at 7 m/s with a wall's face at x = WALL_X (if `wall`), 0.4 m off it; ollie, then ollie again in the air.
func sticker(wall: bool) -> Dictionary:
	var pieces: Array = []
	if wall:
		pieces.append(PieceKit.box(Vector3(WALL_X, 0.0, -40.0), Vector3(1.0, 4.0, 50.0), PieceKit.CONCRETE, "Wall"))
	await sandbox(pieces)
	place(Vector3(WALL_X - 0.7, 0, 0), Vector3(0, 0, -1), 7.0)
	for i: int in 3:
		await tick()
	await tick(NONE, ["ollie"], ["ollie"])
	await tick()
	var v_before: Vector3 = Vector3.ZERO
	var v_after: Vector3 = Vector3.ZERO
	var slapped: bool = false
	var planted: bool = false
	var result: String = ""
	for i: int in 120:
		var jp: Array = []
		if i == 8:
			jp = ["ollie"]
			v_before = sk.velocity
		await tick(NONE, jp, jp)
		if sk.events.has("sticker_slap"):
			slapped = true
			v_after = sk.velocity
		if sk.events.has("wallplant"):
			planted = true
		for e: String in sk.events:
			if e.begins_with("land:"):
				result = e.substr(5)
		if result != "":
			for k: int in 10:
				await tick()
			break
	var res: Dictionary = {"slapped": slapped, "planted": planted, "keep": -v_after.z / maxf(-v_before.z, 0.01),
		"out": -v_after.x, "up": v_after.y, "result": result, "bails": bails, "state": sname()}
	await clear()
	return res


func _bank() -> Node3D:
	# profile (y, z): top edge at z = 0, toe at z = run, BANK_DEG steep; extruded along +x
	var run: float = BANK_H / tan(deg_to_rad(BANK_DEG))
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, run), Vector2(BANK_H, 0.0)])
	var n := Node3D.new()
	n.add_child(PieceKit.body(PieceKit.extrude_profile(prof, 60.0), PieceKit.RAMP_WOOD, "Bank"))
	n.position = Vector3(-30.0, 0.0, 0.0)
	return n


## Across the bank at 7 m/s (heading +x, mid-slope), revert pressed after 10 ticks if `press`; 0.6 s later.
func bert(press: bool) -> Dictionary:
	await sandbox([_bank()])
	var run: float = BANK_H / tan(deg_to_rad(BANK_DEG))
	var z0: float = run * 0.5
	place(Vector3(-20.0, BANK_H * 0.5 + 0.05, z0), Vector3(1, 0, 0), 7.0)
	for i: int in 10:
		await tick()
	var f0: Vector3 = Vector3(sk.velocity.x, 0.0, sk.velocity.z).normalized()
	var g: float = float(sk.tune.gravity)
	var e0: float = 0.5 * sk.velocity.length_squared() + g * sk.global_position.y
	var berted: bool = false
	var anims: Dictionary = {}
	for i: int in 36:
		await tick(NONE, ["revert"] if press and i == 0 else [], ["revert"] if press and i < 20 else [])
		anims[sk.anim] = true
		if sk.events.has("bert_slide"):
			berted = true
	var f1: Vector3 = Vector3(sk.velocity.x, 0.0, sk.velocity.z).normalized()
	var res: Dictionary = {"berted": berted, "turn": rad_to_deg(f0.angle_to(f1)), "loss": e0 - (0.5 * sk.velocity.length_squared() + g * sk.global_position.y),
		"state": sname(), "bails": bails, "anims": anims}
	await clear()
	return res


func bert_flat() -> Dictionary:
	await sandbox([])
	place(Vector3(0, 0, 0), Vector3(0, 0, -1), 7.0)
	for i: int in 10:
		await tick()
	var bert_seen: bool = false
	var slide_seen: bool = false
	for i: int in 30:
		await tick(NONE, ["revert"] if i == 0 else [], ["revert"] if i < 20 else [])
		bert_seen = bert_seen or sk.events.has("bert_slide")
		slide_seen = slide_seen or sk.events.has("powerslide")
	var res: Dictionary = {"bert": bert_seen, "slide": slide_seen}
	await clear()
	return res


## A hatchback stopped on the flat facing -z; the skater rolls up behind it at 2 m/s and holds grab (if `car`); the car
## pulls away at 2.4 m/s² to 9 m/s; after 4 s grab is let go.
func skitch(with_car: bool) -> Dictionary:
	await sandbox([])
	var car: Node3D = null
	var rear_z: float = -4.0
	if with_car:
		car = TrafficCarScript.create("hatch", Color(0.8, 0.2, 0.2))
		root3.add_child(car)
		var bb: AABB = car.model.aabb
		car.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, rear_z - bb.end.z))
	place(Vector3(0, 0, 0), Vector3(0, 0, -1), 2.0)
	var caught: bool = false
	var kind: String = ""
	var min_gap: float = INF
	var max_gap: float = 0.0
	var gap_at_catch: float = NAN
	var car_speed: float = 0.0
	var speed_diff: float = NAN
	var release_keep: float = NAN
	var after_state: String = ""
	var names: String = ""
	var pressed: bool = false
	var t_catch: int = -1
	for i: int in 420:
		var jp: Array = []
		var held: Array = []
		var stick: Vector2 = NONE
		if not pressed and sk.global_position.z < rear_z + 1.6:
			jp = ["grab"]
			pressed = true
		if pressed and (t_catch < 0 or i - t_catch < 240):
			held = ["grab"]
		if sname() == "MANUAL":
			stick = Vector2(_bal_x(), 0.0)
		if car != null and t_catch >= 0:
			car_speed = minf(car_speed + 2.4 * DT, 9.0)
			car.set("speed", car_speed)
			car.global_position += Vector3(0, 0, -car_speed * DT)
		await tick(stick, jp, held)
		if sk.events.has("skitch"):
			caught = true
			t_catch = i
			kind = sk.balance_kind
		if caught and sname() == "MANUAL" and car != null and i - t_catch >= 30:
			var gap: float = sk.global_position.z - (car.global_position.z + car.model.aabb.end.z)
			if is_nan(gap_at_catch):
				gap_at_catch = gap
			min_gap = minf(min_gap, gap)
			max_gap = maxf(max_gap, gap)
			speed_diff = absf(sk.velocity.length() - car_speed)
		if caught and t_catch >= 0 and i - t_catch == 241:
			release_keep = sk.velocity.length() / maxf(car_speed, 0.01)
			after_state = sname()
			names = _names()
			break
	var res: Dictionary = {"caught": caught, "kind": kind, "min_gap": min_gap, "max_gap": max_gap, "diff": speed_diff,
		"keep": release_keep, "after": after_state, "names": names, "bails": bails, "car_speed": car_speed}
	await clear()
	return res


## A straight roll at 6 m/s with stick-up pushes for 90 ticks; `focus_at` >= 0 presses focus on that tick. Returns the
## end position, whether focus came on, the meter, and the engine clock seen.
func focus_ride(fill: bool, focus_at: int, off_at: int = -1) -> Dictionary:
	await sandbox([])
	place(Vector3(0, 0, 0), Vector3(0, 0, -1), 6.0)
	if fill:
		sk.special.add_points(3000)
	var came_on: bool = false
	var went_off: bool = false
	var scale_seen: float = 1.0
	var v_at_on: float = NAN
	for i: int in 90:
		var jp: Array = []
		if i == focus_at or i == off_at:
			jp = ["focus"]
		await tick(FWD, jp, jp)
		scale_seen = minf(scale_seen, Engine.time_scale)
		if sk.events.has("focus_on"):
			came_on = true
			v_at_on = sk.special.value
		if sk.events.has("focus_off"):
			went_off = true
	var res: Dictionary = {"pos": sk.global_position, "on": came_on, "off": went_off, "active": sk.get("focus") != null and bool(sk.get("focus").active),
		"value": sk.special.value, "scale": scale_seen, "v_on": v_at_on}
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	var n: Dictionary = await natas(0.3)
	rows.append(ok_line("natas_spin", bool(n["started"]) and str(n["kind"]) == "natas" and int(n["on_post"]) >= 66
		and float(n["dy"]) < 0.1 and (str(n["names"]).contains("360 Natas") or str(n["names"]).contains("540 Natas"))
		and str(n["result"]) in ["clean", "sketchy"] and int(n["bails"]) == 0,
		"on the post %s (balance %s) %d ticks, off the top by %.2f m at most, combo [%s], landed %s, bails %d"
		% [str(n["started"]), n["kind"], n["on_post"], n["dy"], n["names"], n["result"], n["bails"]]))
	var nw: Dictionary = await natas(1.4)
	rows.append(ok_line("natas_wide_box", not bool(nw["started"]),
		"a 1.4 m box top: natas %s (want false), combo [%s]" % [str(nw["started"]), nw["names"]]))
	var s: Dictionary = await sticker(true)
	rows.append(ok_line("sticker_slap", bool(s["slapped"]) and not bool(s["planted"]) and float(s["keep"]) >= 0.95
		and float(s["out"]) > 0.5 and float(s["up"]) > 3.0 and str(s["result"]) in ["clean", "sketchy"] and int(s["bails"]) == 0
		and str(s["state"]) == "ROLLING",
		"slap %s, wallplant %s, kept %.2f of the speed along the wall (want >= 0.95), out %.2f m/s, up %.2f m/s, landed %s, %s, bails %d"
		% [str(s["slapped"]), str(s["planted"]), s["keep"], s["out"], s["up"], s["result"], s["state"], s["bails"]]))
	var s0: Dictionary = await sticker(false)
	rows.append(ok_line("sticker_no_wall", not bool(s0["slapped"]), "no wall beside: slap %s (want false)" % str(s0["slapped"])))
	var b: Dictionary = await bert(true)
	var b0: Dictionary = await bert(false)
	rows.append(ok_line("bert_slide", bool(b["berted"]) and float(b["turn"]) >= 50.0 and float(b["loss"]) > float(b0["loss"]) + 5.0
		and str(b["state"]) == "ROLLING" and int(b["bails"]) == 0,
		"bert %s, turned %.0f deg in 0.6 s (want >= 50; no press %.0f), lost %.1f J/kg of energy (no press %.1f, want 5 more), %s, bails %d, anims %s"
		% [str(b["berted"]), b["turn"], b0["turn"], b["loss"], b0["loss"], b["state"], b["bails"], str(b["anims"].keys())]))
	var bf: Dictionary = await bert_flat()
	rows.append(ok_line("bert_not_on_flat", not bool(bf["bert"]) and bool(bf["slide"]),
		"revert on the flat: bert %s (want false), powerslide %s (want true)" % [str(bf["bert"]), str(bf["slide"])]))
	var k: Dictionary = await skitch(true)
	rows.append(ok_line("skitch_tow", bool(k["caught"]) and str(k["kind"]) == "skitch" and float(k["diff"]) < 0.5
		and float(k["min_gap"]) > 0.2 and float(k["max_gap"]) < 1.2 and float(k["keep"]) >= 0.95 and str(k["after"]) == "ROLLING"
		and str(k["names"]).contains("Skitch") and int(k["bails"]) == 0,
		"caught %s (balance %s), car at %.1f m/s, speed off by %.2f m/s, gap to the bumper %.2f..%.2f m, let go keeping %.2f, then %s, combo [%s], bails %d"
		% [str(k["caught"]), k["kind"], k["car_speed"], k["diff"], k["min_gap"], k["max_gap"], k["keep"], k["after"], k["names"], k["bails"]]))
	var k0: Dictionary = await skitch(false)
	rows.append(ok_line("skitch_no_car", not bool(k0["caught"]), "grab with no car: skitch %s (want false)" % str(k0["caught"])))
	var f_empty: Dictionary = await focus_ride(false, 10)
	var f_on: Dictionary = await focus_ride(true, 10)
	var f_off: Dictionary = await focus_ride(true, 10, 50)
	var f_none: Dictionary = await focus_ride(true, -1)
	var same: bool = (f_on["pos"] as Vector3).is_equal_approx(f_none["pos"] as Vector3)
	rows.append(ok_line("focus_toggle", not bool(f_empty["on"]) and bool(f_on["on"]) and bool(f_on["active"])
		and float(f_on["value"]) < 0.99 and float(f_on["value"]) > 0.5 and bool(f_off["off"]) and not bool(f_off["active"])
		and is_equal_approx(float(f_on["scale"]), 1.0) and same,
		"empty meter: on %s (want false); full: on %s, meter %.3f after 80 ticks, pressed again off %s; engine clock seen %.2f (want 1.00 in a scripted run); same path as without focus %s"
		% [str(f_empty["on"]), str(f_on["on"]), f_on["value"], str(f_off["off"]), f_on["scale"], str(same)]))
	return rows
