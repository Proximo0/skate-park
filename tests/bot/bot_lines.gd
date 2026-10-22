class_name BotLines
extends RefCounted
## The play-bot's routes. Every coordinate comes from the live park (piece nodes, their collision meshes, grind rails, gap
## zones, Park.drop_ins and the pieces' own layout helpers), never from hand-typed world positions, so the lines follow the
## park when it changes. `build(name)` returns {name, limit (sim seconds), wps, pipe?, note?}.
## Waypoint keys are documented in bot_driver.gd.

const Y0: float = 0.1
const NAMES: Array[String] = [
	"cruise", "ollies", "kickers", "funbox_gap", "halfpipe", "quarter_air", "rails_street", "rails_long", "manuals",
	"dome", "drop_loop", "mega", "mega_qp", "street_run", "gaps_misc", "transfers", "corners_scrape", "corners_clip_a", "corners_clip_b",
]

var park: Park
var sk: Skater


func _init(park_node: Park, skater: Skater) -> void:
	park = park_node
	sk = skater


static func names() -> Array[String]:
	return NAMES


func build(line_name: String) -> Dictionary:
	var line: Dictionary = {"name": line_name, "limit": 40.0, "expect": [], "soft": false}
	match line_name:
		"cruise":
			line["wps"] = _cruise()
			line["limit"] = 30.0
		"ollies":
			line["wps"] = _ollies()
			line["limit"] = 30.0
		"kickers":
			line["wps"] = _kickers()
			line["limit"] = 45.0
		"funbox_gap":
			line["wps"] = _funbox_gap()
			line["expect"] = ["Over The Funbox"]
			line["limit"] = 25.0
		"halfpipe":
			var hp: Rect2 = rect_of("HalfPipe")
			var cx: float = hp.get_center().x
			var flat_z: float = hp.get_center().y
			line["wps"] = [tp(Vector3(cx, Y0, flat_z + 2.5), Vector3(0, 0, -1), 7.0),
				wp(cx, flat_z - 500.0, 7.0, {"r": 0.1, "tmo": 60.0, "pipe": {"axis": "z", "lane": cx, "ref": 4.0, "min_y": 0.8, "want": 5}})]
			line["limit"] = 70.0
			line["note"] = "5 passes"
		"quarter_air":
			line["wps"] = _quarter_air()
			line["limit"] = 45.0
		"rails_street":
			line["wps"] = _rails(["RailA", "RailB", "Flatbar", "LedgeA", "LedgeB"])
			line["limit"] = 70.0
		"rails_long":
			line["wps"] = _rails(["Rail25", "Rail15"], {"Rail25": 3.5, "Rail15": 6.0})
			line["expect"] = ["Rail Marathon"]
			line["limit"] = 60.0
		"manuals":
			line["wps"] = _manuals()
			line["expect"] = ["Manual Bridge"]
			line["limit"] = 40.0
		"dome":
			line["wps"] = _dome()
			line["expect"] = ["Dome Air"]
			line["limit"] = 45.0
		"drop_loop":
			line["wps"] = _drop_loop()
			line["expect"] = ["Loop De Loop"]
			line["limit"] = 45.0
		"mega":
			line["wps"] = _mega()
			line["expect"] = ["Mega Gap"]
			line["limit"] = 50.0
		"mega_qp":
			line["wps"] = _mega_qp()
			line["expect"] = ["Mega QP Air"]
			line["limit"] = 50.0
		"street_run":
			line["wps"] = _street_run()
			line["expect"] = ["Down The Hill", "Long Ledge", "Long Rail", "Hubba Hubba", "Hubba Stairs"]
			line["limit"] = 90.0
		"gaps_misc":
			line["wps"] = _gaps_misc()
			line["soft"] = false
			line["expect"] = ["Roof Gap", "Pyramid Hop", "Bowl Hop"]
			line["limit"] = 70.0
		"transfers":
			line["wps"] = _transfers()
			line["limit"] = 50.0
		"corners_scrape":
			line["wps"] = _corners(true, ["FunBox", "Pyramid", "QuarterNorthWest", "KickerCentre"])
			line["soft"] = true
			line["limit"] = 100.0
		"corners_clip_a":
			line["wps"] = _corners(false, ["FunBox", "Pyramid"])
			line["soft"] = true
			line["limit"] = 80.0
		"corners_clip_b":
			line["wps"] = _corners(false, ["QuarterNorthWest", "KickerCentre"])
			line["soft"] = true
			line["limit"] = 80.0
		_:
			line["wps"] = []
	return line


# --- helpers ------------------------------------------------------------------------------------------

static func wp(x: float, z: float, spd: float = 9.0, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"p": Vector3(x, 0.0, z), "spd": spd}
	for k: Variant in extra:
		d[k] = extra[k]
	return d


static func wpv(p: Vector3, spd: float = 9.0, extra: Dictionary = {}) -> Dictionary:
	return wp(p.x, p.z, spd, extra)


static func tp(pos: Vector3, dir: Vector3, speed: float) -> Dictionary:
	return {"tp": {"pos": pos, "dir": dir, "speed": speed}}


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func piece(piece_name: String) -> Node3D:
	return park.get_node(piece_name) as Node3D


## The xz footprint of a piece from its collision meshes, in world space.
func rect_of(piece_name: String) -> Rect2:
	var node: Node3D = piece(piece_name)
	var have: bool = false
	var lo: Vector2 = Vector2.ZERO
	var hi: Vector2 = Vector2.ZERO
	for b: Node in node.find_children("*", "StaticBody3D", true, false):
		for c: Node in b.get_children():
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var box: AABB = mi.global_transform * mi.get_aabb()
			var a: Vector2 = Vector2(box.position.x, box.position.z)
			var z: Vector2 = Vector2(box.end.x, box.end.z)
			if not have:
				lo = a
				hi = z
				have = true
			else:
				lo = Vector2(minf(lo.x, a.x), minf(lo.y, a.y))
				hi = Vector2(maxf(hi.x, z.x), maxf(hi.y, z.y))
	return Rect2(lo, hi - lo)


func zone(zone_id: String) -> Vector3:
	for n: Node in park.get_tree().get_nodes_in_group("gap_zone"):
		if str(n.get_meta("zone_id", "")) == zone_id:
			var cs: CollisionShape3D = n.get_child(0) as CollisionShape3D
			return cs.global_position
	push_error("bot: no zone " + zone_id)
	return Vector3.ZERO


## Global points of every GrindRail under a piece.
func rails_of(piece_name: String, exclude: Array = []) -> Array:
	var out: Array = []
	for n: Node in piece(piece_name).find_children("*", "GrindRail", true, false):
		var skip: bool = false
		for x: Variant in exclude:
			if String(n.name).contains(str(x)):
				skip = true
		if not skip:
			out.append((n as GrindRail).global_points())
	return out


## Longest rail under a piece.
func rail_of(piece_name: String) -> PackedVector3Array:
	var best: PackedVector3Array = PackedVector3Array()
	var best_len: float = -1.0
	for pts: PackedVector3Array in rails_of(piece_name):
		var l: float = pts[0].distance_to(pts[pts.size() - 1])
		if l > best_len:
			best_len = l
			best = pts
	return best


## Approach, grind and leave one rail: a segment of its own (teleports to `lead` m before the start).
func rail_segment(pts: PackedVector3Array, exit_kind: String, lead: float = 10.0, spd: float = 8.0) -> Array:
	var a: Vector3 = pts[0]
	var b: Vector3 = pts[pts.size() - 1]
	var d: Vector3 = flat(b - a).normalized()
	var out: Array = [tp(Vector3(a.x - d.x * lead, Y0, a.z - d.z * lead), d, minf(spd, 3.0 + lead))]
	if lead > 5.0:
		out.append(wpv(a - d * 4.0, spd, {"r": 1.0}))
	out.append(wpv(a - d * 0.8, spd, {"r": 0.9, "act": "grind", "exit": exit_kind, "end": b}))
	out.append(wpv(b + d * 7.0, 6.0, {"r": 2.0}))
	return out
func _rails(pieces: Array, leads: Dictionary = {}) -> Array:
	var out: Array = []
	var k: int = 0
	for pn: String in pieces:
		var pts: PackedVector3Array = rail_of(pn)
		out.append_array(rail_segment(pts, "ollie" if k % 2 == 1 else "ride", float(leads.get(pn, 10.0))))
		k += 1
	return out
## A gap attempt: roll at `a` from `lead` m back, pop `pop` m before the first zone, land past the second.
func gap_run(zone_a: String, zone_b: String, lead: float, pop: float, post: float, spd: float, extra: Dictionary = {}) -> Array:
	var a: Vector3 = zone(zone_a)
	var b: Vector3 = zone(zone_b)
	var d: Vector3 = flat(b - a).normalized()
	var act: Dictionary = {"act": "ollie", "h": 8, "r": 1.0}
	for k: Variant in extra:
		act[k] = extra[k]
	return [
		tp(Vector3(a.x - d.x * lead, Y0, a.z - d.z * lead), d, 4.0),
		wpv(a - d * (pop + 6.0), spd, {"r": 1.5}),
		wpv(a - d * pop, spd, act),
		wpv(b + d * post, spd * 0.6, {"r": 2.5}),
	]


# --- lines --------------------------------------------------------------------------------------------

func _cruise() -> Array:
	# the open flat south of the street plaza: S-turns, then a loop back
	var out: Array = [tp(Vector3(-22.0, Y0, 23.0), Vector3(1, 0, 0), 4.0)]
	var zs: Array[float] = [24.3, 22.0, 24.3, 22.0, 24.3, 22.0, 23.0]
	var x: float = -19.0
	for z: float in zs:
		out.append(wp(x, z, 8.5, {"r": 2.0}))
		x += 4.8
	return out


func _ollies() -> Array:
	var out: Array = [tp(Vector3(-23.0, Y0, 22.5), Vector3(1, 0, 0), 6.0)]
	out.append(wp(-17.0, 22.5, 8.0, {"r": 1.5}))
	out.append(wp(-14.0, 22.5, 8.0, {"r": 1.0, "act": "ollie", "h": 2}))
	out.append(wp(-6.0, 22.5, 8.0, {"r": 1.0, "act": "ollie", "h": 30}))
	out.append(wp(2.0, 22.5, 8.0, {"r": 1.0, "act": "ollie", "h": 10, "flip": true}))
	out.append(wp(9.5, 22.5, 8.0, {"r": 1.0, "act": "ollie", "h": 12, "flip": true, "grab": true, "revert": true}))
	out.append(wp(13.0, 22.5, 6.0, {"r": 1.5}))
	# stopping and brake: a hard stop from speed, then push off again
	out.append(tp(Vector3(-20.0, Y0, 22.5), Vector3(1, 0, 0), 9.0))
	out.append(wp(-8.0, 22.5, 9.0, {"r": 1.5}))
	out.append(wp(-2.0, 22.5, 0.5, {"r": 1.5, "brake": true, "act": "wait", "s": 0.5}))
	out.append(wp(10.0, 22.5, 8.0, {"r": 2.0}))
	return out


func _kickers() -> Array:
	var out: Array = []
	for kn: String in ["KickerCentre", "KickerWest", "KickerEast"]:
		var r: Rect2 = rect_of(kn)
		var cx: float = r.get_center().x
		var lip_z: float = r.position.y  # the kicker rises toward -Z: the lip is its min z face
		var start_z: float = lip_z + 16.0
		out.append(tp(Vector3(cx, Y0, start_z), Vector3(0, 0, -1), 3.0))
		out.append(wp(cx, lip_z + 11.0, 10.0, {"r": 1.5}))
		out.append(wp(cx, lip_z + 4.0, 10.0, {"r": 1.0}))
		out.append(wp(cx, lip_z + 0.6, 10.0, {"r": 0.8, "act": "air", "grab": true, "flip": kn == "KickerWest", "revert": true}))
		out.append(wp(cx + (4.0 if kn == "KickerCentre" else 0.0), lip_z - 9.0, 7.0, {"r": 2.5}))
	return out


func _funbox_gap() -> Array:
	# funbox ridden north -> south (bank up at its north end), popped at the foot of the first bank
	var r: Rect2 = rect_of("FunBox")
	var cx: float = r.get_center().x
	var out: Array = [tp(Vector3(cx, Y0, r.position.y - 22.0), Vector3(0, 0, 1), 4.0)]
	out.append(wp(cx, r.position.y - 10.0, 12.0, {"r": 1.5}))
	out.append(wp(cx, r.position.y - 1.6, 12.0, {"r": 1.0, "act": "ollie", "h": 12, "flip": true}))
	out.append(wp(cx, r.end.y + 1.0, 8.0, {"r": 1.5}))
	out.append(wp(cx + 6.0, r.end.y + 3.0, 5.0, {"r": 2.5}))
	# and straight over it with no pop (rolling up, across and down)
	out.append(tp(Vector3(cx, Y0, r.position.y - 16.0), Vector3(0, 0, 1), 4.0))
	out.append(wp(cx, r.position.y - 3.0, 10.0, {"r": 1.5}))
	out.append(wp(cx, r.end.y + 1.0, 10.0, {"r": 1.5}))
	out.append(wp(cx, r.end.y + 1.0, 6.0, {"r": 1.5}))
	out.append(wp(cx + 6.0, r.end.y + 3.0, 5.0, {"r": 2.5}))
	return out


func _quarter_air() -> Array:
	var out: Array = []
	var q: Rect2 = rect_of("QuarterNorthWest")
	var cx: float = q.get_center().x
	var lip_z: float = q.position.y + 1.5
	out.append(tp(Vector3(cx, Y0, lip_z + 22.0), Vector3(0, 0, -1), 3.0))
	out.append(wp(cx, lip_z + 10.0, 12.0, {"r": 1.5}))
	out.append(wp(cx, lip_z + 3.0, 12.0, {"r": 1.0, "pump": true}))
	out.append(wp(cx, lip_z + 0.5, 12.0, {"r": 0.8, "act": "air", "grab": true, "revert": true}))
	out.append(wp(cx, lip_z + 16.0, 6.0, {"r": 2.5}))
	# the west quarter, ridden toward -X
	var w: Rect2 = rect_of("QuarterWest")
	var lip_x: float = w.end.x - 1.5
	var cz: float = w.get_center().y
	out.append(tp(Vector3(lip_x + 22.0, Y0, cz), Vector3(-1, 0, 0), 3.0))
	out.append(wp(lip_x + 10.0, cz, 12.0, {"r": 1.5}))
	out.append(wp(lip_x + 3.0, cz, 12.0, {"r": 1.0, "pump": true}))
	out.append(wp(lip_x + 0.5, cz, 12.0, {"r": 0.8, "act": "air", "flip": true, "revert": true}))
	out.append(wp(lip_x + 16.0, cz, 6.0, {"r": 2.5}))
	return out


func _manuals() -> Array:
	var out: Array = []
	# flat manual first
	out.append(tp(Vector3(-22.0, Y0, 22.5), Vector3(1, 0, 0), 6.0))
	out.append(wp(-14.0, 22.5, 9.0, {"r": 1.5}))
	out.append(wp(-10.0, 22.5, 9.0, {"r": 1.0, "act": "manual", "dur": 2.0, "exit": "ollie"}))
	out.append(wp(10.0, 22.5, 7.0, {"r": 2.0}))
	# the manual pad: ollie up onto it and land in a manual
	var r: Rect2 = rect_of("ManualPad")
	var cx: float = r.get_center().x
	out.append(tp(Vector3(cx, Y0, r.position.y - 18.0), Vector3(0, 0, 1), 4.0))
	# Manual Bridge: ollie up onto the pad and land in a manual inside zone A (its first half), then hold it past zone B.
	out.append(wp(cx, r.position.y - 9.0, 8.0, {"r": 1.5}))
	out.append(wp(cx, r.position.y - 1.6, 8.0, {"r": 0.8, "act": "ollie", "h": 5, "man": true, "dur": 1.5}))
	out.append(wp(cx, r.end.y + 8.0, 7.0, {"r": 2.5}))
	return out


func _dome() -> Array:
	var dome: Node3D = piece("DomeBowl")
	var rim: float = 8.0
	var c: Vector3 = Vector3(dome.global_position.x + rim + 1.5, 0.0, dome.global_position.z + rim + 1.5)
	var out: Array = [tp(Vector3(c.x, Y0, c.z - rim - 0.7), Vector3(0, 0, 1), 3.0)]
	# the roll-in keeps its energy over the rim (Skater._keep_convex_energy): no pumping down the drop, gravity alone
	# brings the rider to about 15 m/s at the bottom of the 6.7 m dish
	out.append(wp(c.x, c.z - 3.0, 8.0, {"r": 1.8}))
	# a carve once round the bowl, widening up the wall; pumping only tops the speed up to what the carve can hold
	var a: float = PI * 0.5
	var radius: float = 4.2
	for i: int in 11:
		a += 0.6
		radius = minf(radius + 0.15, 5.6)
		out.append(wp(c.x + cos(a) * radius, c.z + sin(a) * radius, 10.0, {"r": 1.8, "pump": true, "pump_max": 12.0, "tmo": 8.0}))
	# then pump straight across the bowl, wall to wall, until the passes reach the rim (no pumping at the lip, and back to
	# the middle if a pass carries the rider out of the dish)
	out.append(wp(c.x, c.z, 10.0, {"r": 0.1, "tmo": 30.0, "pump": true, "pipe": {"axis": "x", "lane": c.z, "ref": 0.0, "min_y": -3.0, "want": 5,
		"no_push_above": -2.0, "center": Vector2(c.x, c.z), "radius": rim - 0.5}}))
	out.append(wp(c.x + 6.0, c.z, 6.0, {"r": 2.0, "tmo": 6.0}))
	# Dome Air: the gap zone floats over the middle of the dish (y 0..4, 9.6 m square), so the rider has to leave the wall
	# going inward: roll across at 18 m/s and pop a short ollie at radius 6.5. (Rolling off the lip alone throws the rider
	# outward and up, never over the centre.)
	out.append(tp(Vector3(c.x - 1.0, Y0, c.z), Vector3(1, 0, 0), 18.0))
	out.append(wp(c.x + 6.5, c.z, 22.0, {"r": 0.2, "act": "ollie", "h": 6}))
	out.append(wp(c.x - 6.0, c.z, 12.0, {"r": 2.5, "tmo": 8.0}))
	return out


func _drop_loop() -> Array:
	var loop: Node3D = piece("Loop")
	var runin: Vector3 = loop.to_global(Vector3(2.0, 0.0, -3.0))
	var top: Vector3 = loop.to_global(Vector3(3.75, 0.0, -6.0))
	var runout: Vector3 = loop.to_global(Vector3(5.0, 0.0, -14.0))
	var cq: Rect2 = rect_of("CatchQuarter")
	# the catch quarter faces -Z: its curved base is at the max z end, the lip near min z... riding +Z up the face
	var lip_z: float = cq.position.y + 1.5
	var cxq: float = runout.x
	return [
		{"drop": "loop"},
		wpv(runin, 20.0, {"r": 3.0, "pump": true}),
		wpv(top, 20.0, {"r": 3.0}),
		wpv(runout, 20.0, {"r": 3.0}),
		wp(cxq, lip_z - 14.0, 12.0, {"r": 3.0, "brake": true}),
		wp(cxq, lip_z - 3.0, 12.0, {"r": 1.5, "pump": true}),
		wp(cxq, lip_z - 0.5, 12.0, {"r": 1.0, "act": "air", "grab": true, "revert": true}),
		wp(cxq, lip_z - 18.0, 6.0, {"r": 3.0}),
	]


## Mega Gap: drop in, no pop, off the kicker at 19 m/s and down onto the landing.
func _mega() -> Array:
	var mega: Node3D = piece("MegaRamp")
	var lay: Dictionary = MegaRamp._layout(14.0, 18.0, 8.0)
	var cx: float = mega.global_position.x + 4.0
	var z0: float = mega.global_position.z
	return [
		{"drop": "mega"},
		wp(cx, z0 + float(lay["roll_end"]) - 3.0, 22.0, {"r": 2.5, "pump": true}),
		wp(cx, z0 + float(lay["kick_z0"]) + 4.0, 22.0, {"r": 2.5}),
		wp(cx, z0 + float(lay["lip_z"]) - 0.6, 22.0, {"r": 1.0, "act": "air", "grab": true, "tmo": 40.0}),
		wp(cx, z0 + float(lay["land_top_z"]) + 6.0, 22.0, {"r": 3.0}),
		wp(cx, z0 + float(lay["qp_a"]) - 2.0, 18.0, {"r": 2.5}),
		wp(cx, z0 + float(lay["qp_lip_z"]) - 0.6, 18.0, {"r": 1.0, "pump": true, "act": "air", "grab": true}),
		wp(cx, z0 + float(lay["qp_a"]) - 8.0, 8.0, {"r": 3.0}),
	]


## Mega QP Air in a run of its own. Mega Gap closes a combo when it lands (0.35 s on the wheels), and that wipes the
## pending start of Mega QP Air (the runout zone is entered 0.2 s after the landing), and the flat landing costs 5 m/s
## that the quarter pipe then lacks. So this run rolls off the kicker at 20 m/s without registering the gap and pumps
## the quarter pipe; its apex is 7.5-8.6 m against 7.4 m needed (see docs/play_bot.md, gap reachability).
func _mega_qp() -> Array:
	var mega: Node3D = piece("MegaRamp")
	var lay: Dictionary = MegaRamp._layout(14.0, 18.0, 8.0)
	var cx: float = mega.global_position.x + 4.0
	var z0: float = mega.global_position.z
	return [
		{"drop": "mega"},
		wp(cx, z0 + float(lay["roll_end"]) - 3.0, 20.0, {"r": 2.5, "pump": true}),
		wp(cx, z0 + float(lay["kick_z0"]) + 4.0, 20.0, {"r": 2.5}),
		wp(cx, z0 + float(lay["lip_z"]) - 0.6, 20.0, {"r": 1.0, "act": "air", "tmo": 40.0}),
		wp(cx, z0 + float(lay["land_top_z"]) + 6.0, 20.0, {"r": 3.0}),
		wp(cx, z0 + float(lay["qp_a"]) - 2.0, 20.0, {"r": 2.5}),
		wp(cx, z0 + float(lay["qp_lip_z"]) - 0.6, 20.0, {"r": 1.0, "pump": true, "pump_max": 22.0}),
		wp(cx, z0 + float(lay["qp_lip_z"]) + 1.5, 20.0, {"hold": true, "hold_s": 1.2}),
		wp(cx, z0 + float(lay["qp_a"]) - 8.0, 8.0, {"r": 3.0}),
	]


func _street_run() -> Array:
	var out: Array = []
	var zc: float = Park.STREET_Z
	var down: Rect2 = rect_of("Downhill")
	# The rails first (each a segment of its own, with its own run-up).
	out.append_array(rail_segment(rail_of("LongLedge"), "ollie", 14.0, 8.0))
	out.append_array(rail_segment(rail_of("LongRail"), "ride", 14.0, 8.0))
	out.append_array(_hubba())
	# Down The Hill: the access ramp needs ~11 m/s of height, so start at the very west edge (rolling at 4 m/s, pushing
	# up the ramp) and carry the speed gained on the way down along the open lane beside the rails to the hubba stairs
	# (the ramp, platform and 10 steps need ~11 m/s to be cleared in the air).
	var ta: Vector3 = zone("hubba_stairs_top")
	var lane: float = zc + 1.4  # clear of the long ledge / rail line (z = 62 +- 0.4)
	out.append(tp(Vector3(down.position.x - 1.6, Y0, zc), Vector3(1, 0, 0), 4.0))
	out.append(wp(down.position.x + 12.0, zc, 12.0, {"r": 2.0}))
	out.append(wp(down.position.x + 22.0, zc, 12.0, {"r": 2.0}))
	out.append(wp(down.end.x - 6.0, lane, 14.0, {"r": 3.0}))
	out.append(wp(ta.x - 16.0, lane, 14.0, {"r": 3.0}))
	out.append(wp(ta.x - 8.0, ta.z, 14.0, {"r": 1.5}))
	out.append(wp(ta.x - 0.6, ta.z, 14.0, {"r": 0.5, "act": "ollie", "h": 8, "flip": true}))
	out.append(wp(ta.x + 16.0, ta.z, 8.0, {"r": 2.5}))
	var q: Rect2 = rect_of("StreetQuarter")
	var lip_x: float = q.end.x - 1.5
	out.append(tp(Vector3(lip_x - 22.0, Y0, zc), Vector3(1, 0, 0), 3.0))
	out.append(wp(lip_x - 10.0, zc, 12.0, {"r": 1.5}))
	out.append(wp(lip_x - 3.0, zc, 12.0, {"r": 1.0, "pump": true}))
	out.append(wp(lip_x - 0.5, zc, 12.0, {"r": 0.8, "act": "air", "grab": true, "revert": true}))
	out.append(wp(lip_x - 16.0, zc, 6.0, {"r": 2.5}))
	return out


## Up the hubba's launch ramp (it runs beside the ledge) and onto the ledge at the top, down to the foot of the stairs.
func _hubba() -> Array:
	var hs: Node3D = piece("HubbaSet")
	var best: PackedVector3Array = PackedVector3Array()
	var best_x: float = -INF
	for pts: PackedVector3Array in rails_of("HubbaSet", ["LedgeRail", "HandRail"]):
		var lx: float = hs.to_local(pts[0]).x
		if lx > best_x:
			best_x = lx
			best = pts
	var a: Vector3 = best[0]
	var b: Vector3 = best[best.size() - 1]
	var d: Vector3 = flat(b - a).normalized()
	var lat: Vector3 = flat(hs.global_transform.basis.x).normalized()
	var lane: Vector3 = lat * 0.9
	return [
		tp(Vector3(a.x + lane.x - d.x * 14.0, Y0, a.z + lane.z - d.z * 14.0), d, 4.0),
		wpv(a + lane - d * 7.0, 9.0, {"r": 1.5}),
		wpv(a + lane - d * 0.6, 9.0, {"r": 0.8, "act": "grind", "exit": "ride", "end": b}),
		wpv(b + d * 6.0, 6.0, {"r": 2.5}),
	]


func _gaps_misc() -> Array:
	var out: Array = []
	out.append_array(_roof())
	# Pyramid Hop: 10.5 m of air between the zones over a 9 m base, so it is two hops (over the foot, off the flat top)
	# at 12+ m/s: that needs a 26 m run-up.
	out.append_array(gap_run("pyramid_n", "pyramid_s", 26.0, 2.0, 8.0, 12.5, {"h": 24}))
	out.append_array(gap_run("bowl_rim_n", "bowl_rim_s", 26.0, 0.3, 8.0, 12.5, {"h": 30}))
	return out


## Up the roof access ramp at 12 m/s, a small ollie over the parapet at its top, a quick second pop just after landing
## on the west roof, and over the 4 m gap to the east roof. Both roof zones must be entered in the air, so the second
## pop has to leave the ground before the west zone (x = -17.3): there is only 6 m of roof to do it in.
func _roof() -> Array:
	var west: Vector3 = zone("roof_west")
	var east: Vector3 = zone("roof_east")
	var ramp: Rect2 = rect_of("RoofRamp")
	var z: float = ramp.get_center().y
	var d: Vector3 = flat(east - west).normalized()
	return [
		tp(Vector3(ramp.position.x - 26.0, Y0, z), d, 4.0),
		wp(ramp.position.x - 6.0, z, 13.0, {"r": 1.5}),
		wp(ramp.end.x - 2.0, z, 13.0, {"r": 0.3, "act": "ollie", "h": 3}),
		wp(west.x - 1.5, z, 13.0, {"r": 0.3, "act": "ollie", "h": 3}),
		wp(east.x + 4.0, z, 3.0, {"r": 2.0, "brake": true}),
		wp(east.x + 5.0, z, 2.0, {"r": 1.5, "brake": true, "act": "wait", "s": 0.3}),
	]
func _transfers() -> Array:
	# north -> south over the pyramid, the hip (up its north leg, across the deck, off the south edge) and the spine
	var out: Array = []
	for pn: String in ["Pyramid", "Hip", "Spine"]:
		var r: Rect2 = rect_of(pn)
		var cx: float = r.get_center().x
		if pn == "Hip":
			cx = r.position.x + 5.5
		out.append(tp(Vector3(cx, Y0, r.position.y - 14.0), Vector3(0, 0, 1), 4.0))
		out.append(wp(cx, r.position.y - 4.0, 10.0, {"r": 1.5, "pump": true}))
		out.append(wp(cx, r.end.y + 6.0, 10.0, {"r": 2.0, "pump": true, "tmo": 10.0}))
	return out
## Scrapes along the sides of ramps and clips their corners at angles (the player reported snagging on both).
## Split in two lines so neither runs for minutes: `scrape` = the side scrapes plus the deliberate wall test, else the corner clips.
func _corners(scrape: bool, pieces: Array) -> Array:
	var out: Array = []
	for pn: String in pieces:
		var r: Rect2 = rect_of(pn)
		var lead: float = 9.0
		var tail: float = 6.0
		for clear: float in ([0.2, 0.42] if scrape else []):
			# east side southbound, west side northbound
			var xe: float = r.end.x + clear + 0.3
			var xw: float = r.position.x - clear - 0.3
			out.append(tp(Vector3(xe, Y0, r.position.y - lead), Vector3(0, 0, 1), 6.0))
			out.append(wp(xe, r.position.y - 2.0, 9.0, {"r": 1.5}))
			out.append(wp(xe, r.end.y + tail, 9.0, {"r": 2.0}))
			out.append(tp(Vector3(xw, Y0, r.end.y + lead), Vector3(0, 0, -1), 6.0))
			out.append(wp(xw, r.end.y + 2.0, 9.0, {"r": 1.5}))
			out.append(wp(xw, r.position.y - tail, 9.0, {"r": 2.0}))
		# two corners, each clipped on both faces at 15 and 30 degrees: a glancing graze (a real player's mistake), never
		# square on at speed. The path crosses the face 0.4 m along from the corner.
		for cxs: float in ([] if scrape else [r.end.x, r.position.x]):
			for czs: float in [r.end.y, r.position.y]:
				var sx: float = 1.0 if cxs > r.get_center().x else -1.0
				var sz: float = 1.0 if czs > r.get_center().y else -1.0
				for ang: float in [15.0, 30.0]:
					var ca: float = cos(deg_to_rad(ang))
					var sa: float = sin(deg_to_rad(ang))
					# along the face that lies on z = czs (normal sz), coming from beyond the corner in x
					var h1: Vector3 = Vector3(-sx * ca, 0, -sz * sa)
					var q1: Vector3 = Vector3(cxs - sx * 0.4, 0, czs)
					out.append(tp(q1 - h1 * 11.0 + Vector3(0, Y0, 0), h1, 6.0))
					out.append(wpv(q1 - h1 * 3.0, 9.0, {"r": 1.2}))
					out.append(wpv(q1 + Vector3(-sx * 6.0, 0, sz * 1.5), 9.0, {"r": 2.5, "tmo": 4.0}))
					# along the face on x = cxs (normal sx), coming from beyond the corner in z
					var h2: Vector3 = Vector3(-sx * sa, 0, -sz * ca)
					var q2: Vector3 = Vector3(cxs, 0, czs - sz * 0.4)
					out.append(tp(q2 - h2 * 11.0 + Vector3(0, Y0, 0), h2, 6.0))
					out.append(wpv(q2 - h2 * 3.0, 9.0, {"r": 1.2}))
					out.append(wpv(q2 + Vector3(sx * 1.5, 0, -sz * 6.0), 9.0, {"r": 2.5, "tmo": 4.0}))
	# The deliberate wall test (INFO, not a finding): square into the tall end of the centre kicker at 15 m/s, which must
	# bail (head-on speed above the slam speed, 13 m/s).
	if not scrape:
		return out
	var k: Rect2 = rect_of("KickerCentre")
	var kx: float = k.get_center().x
	out.append(tp(Vector3(kx, Y0, k.position.y - 14.0), Vector3(0, 0, 1), 15.0))
	out.append(wp(kx, k.position.y - 5.0, 15.0, {"r": 1.5}))
	out.append(wp(kx, k.position.y + 1.0, 15.0, {"r": 0.5, "wall_test": true, "tmo": 6.0}))
	return out
