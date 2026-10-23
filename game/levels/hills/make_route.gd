extends SceneTree
## Writes game/levels/hills/bot_route.json from the live level (every coordinate comes from the built streets, lots
## and pieces). Rerun after moving anything:  godot --headless --path . -s res://game/levels/hills/make_route.gd

## The level, untyped on purpose: this script runs before the autoloads exist, so it must not name classes that
## depend on them (HillsLevel, LevelRegistry, HillsTown) at compile time.
var lvl: Node3D
var roads: Dictionary = {}
var consts: Dictionary = {}


func _initialize() -> void:
	_go.call_deferred()


func v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]


func tp(p: Vector3, d: Vector3, spd: float) -> Dictionary:
	return {"tp": {"pos": v(p + Vector3(0, 0.15, 0)), "dir": v(d.normalized()), "speed": spd}}


func wp(p: Vector3, spd: float, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"p": v(p), "spd": spd}
	for k: Variant in extra:
		d[k] = v(extra[k] as Vector3) if extra[k] is Vector3 else extra[k]
	return d


func wpv(p: Vector3, spd: float, extra: Dictionary = {}) -> Dictionary:
	return wp(p, spd, extra)


func road_run(rn: String, s0: float, s1: float, off: float, spd: float, step: float, extra: Dictionary = {}) -> Array:
	var r: HillsRoad = roads[rn]
	var out: Array = []
	var dir: float = signf(s1 - s0)
	var right_sign: float = dir
	var start: Vector3 = r.sample(s0) + r.right(s0) * off * right_sign
	out.append(tp(start, r.tangent(s0) * dir, 4.0))
	var s: float = s0 + dir * step
	while (s - s1) * dir < 0.0:
		out.append(wp(r.sample(s) + r.right(s) * off * right_sign, spd, extra))
		s += dir * step
	out.append(wp(r.sample(s1) + r.right(s1) * off * right_sign, spd, extra))
	return out


func _go() -> void:
	var reg: GDScript = load("res://game/levels/level_registry.gd")
	lvl = reg.call("create", "hills") as Node3D
	root.add_child(lvl)
	roads = lvl.get("roads")
	consts = (lvl.get_script() as GDScript).get_script_constant_map()
	var lines: Array = []
	var ch: HillsChannel = lvl.get("channel")
	var sp: Vector3 = (lvl.get("spawn") as Transform3D).origin
	var ditch: Array = [tp(sp, Vector3(0, 0, 1), 2.0)]
	for z: float in [-50.0, -20.0, 10.0, 40.0, 54.0]:
		ditch.append(wp(Vector3(ch.cx, 0, z), 9.0, {"r": 3.0}))
	lines.append({"name": "ditch_bomb", "limit": 30, "expect": ["Ditch Bomb"], "wps": ditch})
	var hc: HillsRoad = roads["hillcrest"]
	lines.append({"name": "hillcrest_bomb", "limit": 45, "expect": ["Hillcrest Bomb"], "wps": road_run("hillcrest", hc.length - 8.0, 4.0, 2.0, 12.0, 10.0, {"brake": true, "r": 3.0})})
	var cy: HillsRoad = roads["canyon"]
	var cyw: Array = road_run("canyon", 8.0, cy.length - 22.0, 2.0, 14.0, 12.0, {"brake": true, "r": 3.0})
	cyw.append(wp(cy.sample(cy.length - 12.0) + cy.right(cy.length - 12.0) * 2.0, 7.0, {"brake": true, "r": 3.0}))
	var vr0: HillsRoad = roads["valley"]
	var sj: float = float(vr0.closest(cy.sample(cy.length))["s"])
	cyw.append(wp(vr0.sample(sj + 10.0) + vr0.right(sj + 10.0) * 2.0, 7.0, {"brake": true, "r": 3.0}))
	cyw.append(wp(vr0.sample(sj + 16.0) + vr0.right(sj + 16.0) * 2.0, 7.0, {"brake": true, "r": 3.0}))
	lines.append({"name": "canyon_bomb", "limit": 40, "expect": ["Canyon Bomb"], "wps": cyw})
	# Pool Row: through the three pools, over both yard fences
	var ty: float = float(lvl.get("terrace_y"))
	var pz: float = -8.0
	var pool: Array = [tp(Vector3(-17.0, ty, pz), Vector3(1, 0, 0), 8.0)]
	pool.append(wp(Vector3(-7.0, 0, pz), 9.0, {"r": 2.5}))
	pool.append(wp(Vector3(2.0, 0, pz), 9.0, {"r": 1.0, "act": "ollie", "h": 12}))
	pool.append(wp(Vector3(15.0, 0, pz), 9.0, {"r": 2.5}))
	pool.append(wp(Vector3(24.0, 0, pz), 9.0, {"r": 1.0, "act": "ollie", "h": 12}))
	pool.append(wp(Vector3(37.0, 0, pz), 9.0, {"r": 2.5}))
	pool.append(wp(Vector3(46.0, 0, pz), 7.0, {"r": 2.5}))
	lines.append({"name": "pool_row", "limit": 25, "expect": ["Backyard Fence Hop", "Neighbour's Fence", "Pool To Pool", "Next Door Pool"], "wps": pool})
	# Driveway Launch: out of the garage, down the drive, off the kicker into Summit Court
	for lot: Dictionary in lvl.get("lots"):
		if bool((lot["opts"] as Dictionary).get("kicker", false)):
			var a: Vector3 = lot["drive_a"]
			var b: Vector3 = lot["drive_b"]
			var d: Vector3 = Vector3(a.x - b.x, 0, a.z - b.z).normalized()
			var dl: Array = [tp(Vector3(b.x, b.y, b.z) + d * 0.5, d, 4.0)]
			dl.append(wp(Vector3(a.x, 0, a.z) - d * 1.6, 10.0, {"r": 1.0}))
			dl.append(wp(Vector3(a.x, 0, a.z) + d * 9.0, 6.0, {"r": 2.5}))
			lines.append({"name": "driveway_launch", "limit": 15, "expect": ["Driveway Launch"], "wps": dl})
			break
	# Million Dollar View: grind the overlook rail
	var vr: HillsRoad = roads["valley"]
	var off: float = float(consts["ROAD_HALF"]) + 2.2  # the overlook walk (HillsTown.SHOULDER)
	var s_a: float = float(vr.closest(Vector3(-36.0, 0, 88.0))["s"])
	var s_g: float = float(vr.closest(Vector3(-28.0, 0, 88.0))["s"])
	var s_e: float = float(vr.closest(Vector3(24.0, 0, 88.0))["s"])
	var rail: Array = [tp(vr.sample(s_a) + vr.right(s_a) * (off - 0.6), vr.tangent(s_a), 7.0)]
	var g0: Vector3 = vr.sample(s_g) + vr.right(s_g) * off
	rail.append(wpv(g0 - vr.tangent(s_g) * 2.6 - vr.right(s_g) * 0.3, 8.0, {"r": 0.8, "act": "ollie", "h": 12}))
	rail.append(wpv(g0 - vr.tangent(s_g) * 0.2, 8.0, {"r": 1.2, "act": "grind", "exit": "ride", "end": vr.sample(s_e) + vr.right(s_e) * off}))
	rail.append(wpv(vr.sample(s_e + 6.0) + vr.right(s_e) * (off - 1.5), 6.0, {"r": 3.0}))
	lines.append({"name": "overlook_rail", "limit": 20, "expect": ["Million Dollar View"], "wps": rail})
	# Valley Park: the flat rail
	var py: float = float(lvl.get("park_y"))
	var pr: Array = [tp(Vector3(-4.0, py, 69.5), Vector3(1, 0, 0), 6.0)]
	pr.append(wp(Vector3(3.2, 0, 69.5), 7.0, {"r": 0.9, "act": "grind", "exit": "ride", "end": Vector3(12.0, 0.0, 69.5)}))
	pr.append(wp(Vector3(18.0, 0, 69.5), 5.0, {"r": 2.5}))
	lines.append({"name": "park_rail", "limit": 15, "expect": ["Valley Park Rail"], "wps": pr})
	# the secret garden: off the kicker over the low hedge
	var sr: Rect2 = consts["SECRET"]
	var sc: float = sr.position.y + 4.0
	var sg: Array = [tp(Vector3(sr.end.x + 15.0, py, sc), Vector3(-1, 0, 0), 9.0)]
	sg.append(wp(Vector3(sr.end.x + 2.5, 0, sc), 10.5, {"r": 1.0}))
	sg.append(wp(Vector3(sr.end.x - 3.5, 0, sc), 7.0, {"r": 2.0}))
	lines.append({"name": "secret_garden", "limit": 15, "expect": ["Secret Garden"], "wps": sg})
	# street crossings on the slopes: lawn, sidewalk, curb, road, curb, sidewalk, lawn
	var hcx: HillsRoad = roads["hillcrest"]
	var sx: float = 100.0
	var cross: Array = [tp(hcx.sample(sx) - hcx.right(sx) * 10.0, hcx.right(sx), 5.0)]
	cross.append(wp(hcx.sample(sx) + hcx.right(sx) * 10.0, 6.0, {"r": 1.5}))
	lines.append({"name": "hillcrest_cross", "limit": 12, "expect": [], "wps": cross})
	for lot: Dictionary in lvl.get("lots"):
		if str(lot["road"]) == "crest" and int(lot["side"]) < 0 and absf((lot["centre"] as Vector3).x + 49.0) < 3.0:
			var a: Vector3 = lot["drive_a"]
			var b: Vector3 = lot["drive_b"]
			var d: Vector3 = Vector3(a.x - b.x, 0, a.z - b.z).normalized()
			var dd: Array = [tp(Vector3(b.x, b.y, b.z) + d * 0.5, d, 3.0)]
			dd.append(wp(Vector3(a.x, 0, a.z) + d * 6.0, 6.0, {"r": 1.5}))
			dd.append(wp(Vector3(a.x, 0, a.z) + d * 15.0, 5.0, {"r": 2.0}))
			lines.append({"name": "driveway_cross", "limit": 12, "expect": [], "wps": dd})
			break
	var f: FileAccess = FileAccess.open("res://game/levels/hills/bot_route.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"lines": lines}, "\t") + "\n")
	f.close()
	quit()
