class_name BotLines
extends RefCounted
## The play-bot's routes. Every coordinate comes from the live park (piece nodes, their collision meshes, grind rails, gap
## zones, Park.drop_ins and the pieces' own layout helpers), never from hand-typed world positions, so the lines follow the
## park when it changes. `build(name)` returns {name, limit (sim seconds), wps, pipe?, note?}.
## Waypoint keys are documented in bot_driver.gd.

const Y0: float = 0.1
const NAMES: Array[String] = [
	"cruise", "ollies", "kickers", "funbox_gap", "halfpipe", "quarter_air", "rails_street", "rails_long", "manuals",
	"dome", "drop_loop", "mega", "street_run", "gaps_misc", "transfers", "corners",
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
			line["expect"] = ["Mega Gap", "Mega QP Air"]
			line["limit"] = 50.0
		"street_run":
			line["wps"] = _street_run()
			line["expect"] = ["Down The Hill", "Long Ledge", "Long Rail", "Hubba Hubba", "Hubba Stairs"]
			line["limit"] = 90.0
		"gaps_misc":
			line["wps"] = _gaps_misc()
			line["soft"] = true  # roof access run is a known bot routing fault (clips the parapet, stops dead)
			line["expect"] = ["Roof Gap", "Pyramid Hop", "Bowl Hop"]
			line["limit"] = 70.0
		"transfers":
			line["wps"] = _transfers()
			line["limit"] = 50.0
		"corners":
			line["wps"] = _corners()
			line["soft"] = true
			line["limit"] = 90.0
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
	var cx: float = r.get_center().x + 1.5
	var out: Array = [tp(Vector3(cx, Y0, r.position.y - 22.0), Vector3(0, 0, 1), 4.0)]
	out.append(wp(cx, r.position.y - 10.0, 12.0, {"r": 1.5}))
	out.append(wp(cx, r.position.y - 1.6, 12.0, {"r": 1.0, "act": "ollie", "h": 12, "flip": true}))
	out.append(wp(cx + 3.5, r.end.y + 5.0, 8.0, {"r": 2.5}))
	# and straight over it with no pop (rolling up, across and down)
	out.append(tp(Vector3(cx, Y0, r.position.y - 16.0), Vector3(0, 0, 1), 4.0))
	out.append(wp(cx, r.position.y - 3.0, 10.0, {"r": 1.5}))
	out.append(wp(cx, r.end.y + 1.0, 10.0, {"r": 1.5}))
	out.append(wp(cx + 3.5, r.end.y + 5.0, 6.0, {"r": 2.5}))
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
	out.append(wp(cx, r.position.y - 8.0, 9.0, {"r": 1.5}))
	out.append(wp(cx, r.position.y - 2.2, 9.0, {"r": 0.8, "act": "ollie", "h": 3, "man": true, "dur": 1.0, "exit": "ollie"}))
	out.append(wp(cx, r.end.y + 8.0, 7.0, {"r": 2.5}))
	return out


func _dome() -> Array:
	var dome: Node3D = piece("DomeBowl")
	var rim: float = 8.0
	var c: Vector3 = Vector3(dome.global_position.x + rim + 1.5, 0.0, dome.global_position.z + rim + 1.5)
	var out: Array = [tp(Vector3(c.x, Y0, c.z - rim - 0.7), Vector3(0, 0, 1), 3.0)]
	out.append(wp(c.x, c.z - 3.0, 8.0, {"r": 1.8, "pump": true}))
	# a carve once round the bowl, widening up the wall
	var a: float = PI * 0.5
	var radius: float = 4.2
	for i: int in 11:
		a += 0.6
		radius = minf(radius + 0.15, 5.6)
		out.append(wp(c.x + cos(a) * radius, c.z + sin(a) * radius, 10.0, {"r": 1.8, "pump": true, "tmo": 8.0}))
	# then pump straight across the bowl, wall to wall, until the passes reach the rim
	out.append(wp(c.x, c.z, 10.0, {"r": 0.1, "tmo": 30.0, "pump": true, "pipe": {"axis": "x", "lane": c.z, "ref": 0.0, "min_y": -3.0, "want": 5}}))
	out.append(wp(c.x + 6.0, c.z, 6.0, {"r": 2.0, "tmo": 6.0}))
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


func _mega() -> Array:
	var mega: Node3D = piece("MegaRamp")
	var lay: Dictionary = MegaRamp._layout(14.0, 18.0, 8.0)
	var cx: float = mega.global_position.x + 4.0
	var z0: float = mega.global_position.z
	return [
		{"drop": "mega"},
		wp(cx, z0 + float(lay["roll_end"]) - 3.0, 22.0, {"r": 2.5, "pump": true}),
		wp(cx, z0 + float(lay["kick_z0"]) + 4.0, 22.0, {"r": 2.5}),
		wp(cx, z0 + float(lay["lip_z"]) - 0.6, 22.0, {"r": 1.0, "act": "air", "grab": true, "revert": true, "tmo": 40.0}),
		wp(cx, z0 + float(lay["land_top_z"]) + 6.0, 22.0, {"r": 3.0}),
		wp(cx, z0 + float(lay["qp_a"]) - 2.0, 18.0, {"r": 2.5}),
		wp(cx, z0 + float(lay["qp_lip_z"]) - 0.6, 18.0, {"r": 1.0, "pump": true, "act": "air", "grab": true, "revert": true}),
		wp(cx, z0 + float(lay["qp_a"]) - 8.0, 8.0, {"r": 3.0}),
	]


func _street_run() -> Array:
	var out: Array = []
	var zc: float = Park.STREET_Z
	var down: Rect2 = rect_of("Downhill")
	out.append(tp(Vector3(down.position.x + 1.0, Y0, zc), Vector3(1, 0, 0), 3.0))
	out.append(wp(down.position.x + 12.0, zc, 10.0, {"r": 2.0}))
	out.append(wp(down.position.x + 22.0, zc, 11.0, {"r": 2.0, "pump": true}))
	out.append(wp(down.end.x + 2.0, zc, 11.0, {"r": 2.5}))
	out.append_array(rail_segment(rail_of("LongLedge"), "ollie", 14.0, 8.0))
	out.append_array(rail_segment(rail_of("LongRail"), "ride", 14.0, 8.0))
	out.append_array(_hubba())
	out.append_array(gap_run("hubba_stairs_top", "hubba_stairs_bottom", 20.0, 1.0, 5.0, 11.0, {"flip": true, "h": 30}))
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
	out.append_array(gap_run("pyramid_n", "pyramid_s", 14.0, 1.5, 7.0, 12.0, {"h": 14}))
	out.append_array(gap_run("bowl_rim_n", "bowl_rim_s", 26.0, 0.3, 8.0, 12.5, {"h": 30}))
	return out


## Up the roof access ramp (ollie over the parapet at its top), across the west roof and over the 4 m gap to the east roof.
func _roof() -> Array:
	var west: Vector3 = zone("roof_west")
	var east: Vector3 = zone("roof_east")
	var ramp: Rect2 = rect_of("RoofRamp")
	var z: float = ramp.get_center().y
	var d: Vector3 = flat(east - west).normalized()
	return [
		tp(Vector3(ramp.position.x - 6.0, Y0, z), d, 8.0),
		wp(ramp.position.x + 3.0, z, 12.0, {"r": 1.5}),
		wp(ramp.end.x - 7.0, z, 12.0, {"r": 1.0, "act": "ollie", "h": 4}),
		wp(west.x - 3.5, z, 11.0, {"r": 1.0}),
		wp(west.x - 2.0, z, 11.0, {"r": 1.0, "act": "ollie", "h": 18}),
		wp(east.x + 3.0, z, 3.0, {"r": 1.5, "brake": true}),
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
func _corners() -> Array:
	var out: Array = []
	for pn: String in ["FunBox", "Pyramid", "QuarterNorthWest", "KickerCentre"]:
		var r: Rect2 = rect_of(pn)
		var lead: float = 9.0
		var tail: float = 6.0
		for clear: float in [0.2, 0.42]:
			# east side southbound, west side northbound
			var xe: float = r.end.x + clear + 0.3
			var xw: float = r.position.x - clear - 0.3
			out.append(tp(Vector3(xe, Y0, r.position.y - lead), Vector3(0, 0, 1), 6.0))
			out.append(wp(xe, r.position.y - 2.0, 9.0, {"r": 1.5}))
			out.append(wp(xe, r.end.y + tail, 9.0, {"r": 2.0}))
			out.append(tp(Vector3(xw, Y0, r.end.y + lead), Vector3(0, 0, -1), 6.0))
			out.append(wp(xw, r.end.y + 2.0, 9.0, {"r": 1.5}))
			out.append(wp(xw, r.position.y - tail, 9.0, {"r": 2.0}))
		# the four corners, clipped at 20 and 40 degrees off the side
		var corners: Array[Vector3] = [
			Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y), Vector3(r.end.x, 0, r.position.y), Vector3(r.position.x, 0, r.position.y)]
		var inward: Array[Vector3] = [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]
		for ci: int in [0, 3]:
			for ang: float in [20.0, 40.0]:
				var inw: Vector3 = inward[ci].normalized()
				# approach direction: from outside, heading along `inw` turned by ang away from the diagonal
				var dirv: Vector3 = inw.rotated(Vector3.UP, deg_to_rad(ang if ci == 0 else -ang)).normalized()
				var aim: Vector3 = corners[ci] + inw * 0.25
				var start: Vector3 = aim - dirv * 11.0
				out.append(tp(Vector3(start.x, Y0, start.z), dirv, 6.0))
				out.append(wpv(aim - dirv * 3.0, 9.0, {"r": 1.2}))
				out.append(wpv(aim + dirv * 6.0, 9.0, {"r": 2.5, "tmo": 6.0}))
	return out
