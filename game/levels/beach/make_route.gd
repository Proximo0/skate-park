extends SceneTree
## Writes game/levels/beach/bot_route.json from the live Beachfront level (zone, rail and piece positions), so the bot's
## lines follow the layout. Run: godot --headless --path . -s res://game/levels/beach/make_route.gd

const OUT: String = "res://game/levels/beach/bot_route.json"
const Y0: float = 0.1

var lvl: Node3D


func _initialize() -> void:
	_boot.call_deferred()


func _boot() -> void:
	var reg: GDScript = load("res://game/levels/level_registry.gd")
	lvl = reg.call("create", "beach") as Node3D
	root.add_child(lvl)
	_write.call_deferred()


func _write() -> void:
	var lines: Array = []
	lines.append(_line("snake_run", 40.0, ["Snake Charmer"], _snake()))
	lines.append(_line("bowl", 30.0, [], _bowl()))
	lines.append(_line("pyramid", 30.0, ["Pyramid Scheme"], _pyramid()))
	lines.append(_line("seawall_slide", 30.0, ["Seawall Slide"], _slide("seawall_w", "seawall_e", -8.6)))
	lines.append(_line("pier_approach", 30.0, ["Pier Approach"], _slide("ledge_pier_a", "ledge_pier_b", -8.6)))
	lines.append(_line("stairs", 25.0, ["Lifeguard Steps"], _stairs()))
	lines.append(_line("beach_launch", 25.0, ["Beach Launch", "Seawall Drop"], _launch()))
	lines.append(_line("pier_rail", 40.0, ["Pier Rail Marathon"], _pier_rail()))
	lines.append(_line("missing_planks", 25.0, ["Missing Planks"], _planks()))
	lines.append(_line("pier_end_air", 30.0, ["Pier End Air"], _pier_air()))
	lines.append(_line("rock_hop", 25.0, ["Rock Hop"], _rock_hop()))
	lines.append(_line("quarter_west", 30.0, [], _quarter_west()))
	var f: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"lines": lines}, " "))
	f.close()
	printerr("ROUTE wrote %d lines" % lines.size())
	quit()


func _line(n: String, limit: float, expect: Array, wps: Array) -> Dictionary:
	return {"name": n, "limit": limit, "expect": expect, "wps": wps}


static func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]


static func tp(pos: Vector3, dir: Vector3, speed: float) -> Dictionary:
	return {"tp": {"pos": _v(pos), "dir": _v(dir.normalized()), "speed": speed}}


static func wp(x: float, z: float, spd: float, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"p": [snappedf(x, 0.01), 0, snappedf(z, 0.01)], "spd": spd}
	for k: Variant in extra:
		d[k] = extra[k]
	return d


func K(n: String) -> Variant:
	return (lvl.get_script() as GDScript).get_script_constant_map()[n]


func zone(id: String) -> Vector3:
	for n: Node in lvl.get_tree().get_nodes_in_group("gap_zone"):
		if str(n.get_meta("zone_id", "")) == id:
			return (n.get_child(0) as Node3D).global_position
	push_error("route: no zone " + id)
	return Vector3.ZERO


## Roll in at the head of the snake run and carve its centre line out the far end.
func _snake() -> Array:
	var sn: Object = lvl.get("snake")
	var a: Array = sn.call("at", 0.0)
	var start: Vector2 = a[0]
	var out: Array = [tp(Vector3(start.x - 3.0, Y0, start.y), Vector3(1, 0, 0), 5.0)]
	var s: float = 3.0
	var length: float = sn.get("length")
	while s < length:
		var p: Vector2 = (sn.call("at", s) as Array)[0]
		out.append(wp(p.x, p.y, 9.0, {"r": 2.2, "tmo": 8.0}))
		s += 5.0
	var e: Vector2 = (sn.call("at", length) as Array)[0]
	out.append(wp(e.x + 4.0, e.y, 7.0, {"r": 2.0}))
	out.append(wp(e.x + 6.0, e.y + 4.0, 5.0, {"r": 2.5}))
	return out


## Into the bowl over its south rim, across the floor and back out.
func _bowl() -> Array:
	var r: Rect2 = K("BOWL_RECT")
	var cx: float = r.get_center().x
	return [tp(Vector3(cx - 2.0, Y0, r.end.y + 9.0), Vector3(0, 0, -1), 4.0),
		wp(cx - 2.0, r.end.y + 2.0, 7.0, {"r": 1.5}),
		wp(cx - 2.0, r.get_center().y, 7.0, {"r": 2.0, "tmo": 6.0}),
		wp(cx + 2.5, r.get_center().y, 7.0, {"r": 2.0, "tmo": 6.0}),
		wp(cx + 2.5, r.end.y + 4.0, 7.0, {"r": 2.0, "pump": true, "tmo": 8.0}),
		wp(cx + 2.5, r.end.y + 8.0, 4.0, {"r": 2.0})]


## Pyramid Scheme: a long run down the boardwalk (westward) and two hops over the pyramid.
func _pyramid() -> Array:
	var a: Vector3 = zone("sp_pyr_n")
	var b: Vector3 = zone("sp_pyr_s")
	return [tp(Vector3(a.x + 26.0, Y0, a.z), Vector3(-1, 0, 0), 4.0),
		wp(a.x + 8.0, a.z, 12.5, {"r": 1.5}),
		wp(a.x + 2.0, a.z, 12.5, {"r": 1.0, "act": "ollie", "h": 24}),
		wp(b.x - 1.0, b.z - 2.0, 6.0, {"r": 2.0}),
		wp(b.x - 2.0, b.z - 6.0, 4.0, {"r": 2.5})]


## A long ledge grind on the seawall's back edge, from zone `za` to `zb`.
func _slide(za: String, zb: String, rail_z: float) -> Array:
	var a: Vector3 = zone(za)
	var b: Vector3 = zone(zb)
	var x0: float = a.x - 1.5
	var x1: float = b.x + 1.5
	return [tp(Vector3(x0 - 12.0, Y0, rail_z - 1.6), Vector3(1, 0, 0.1), 10.0),
		wp(x0 - 4.0, rail_z - 0.9, 12.0, {"r": 1.0}),
		wp(x0 + 0.6, rail_z - 0.15, 12.0, {"r": 0.9, "act": "grind", "exit": "ride", "end": _v(Vector3(x1, 0.5, rail_z))}),
		wp(x1 + 5.0, rail_z - 2.5, 6.0, {"r": 2.5, "tmo": 16.0})]


func _stairs() -> Array:
	var top: Vector3 = zone("bw_stairs_top")
	return [tp(Vector3(top.x, Y0, -24.0), Vector3(0, 0, 1), 4.0),
		wp(top.x, -13.0, 9.0, {"r": 1.5}),
		wp(top.x, top.z - 0.3, 9.0, {"r": 0.8, "act": "ollie", "h": 10}),
		wp(top.x, 4.0, 6.0, {"r": 2.5})]


func _launch() -> Array:
	var lip: Vector3 = zone("launch_lip")
	return [tp(Vector3(lip.x, Y0, -27.0), Vector3(0, 0, 1), 4.0),
		wp(lip.x, -17.0, 11.5, {"r": 1.5}),
		wp(lip.x, lip.z - 0.6, 11.5, {"r": 0.8, "act": "air", "grab": true}),
		wp(lip.x, 8.0, 6.0, {"r": 2.5})]


## The pier railing from the seawall most of the way out to the missing planks.
func _pier_rail() -> Array:
	var x: float = K("PIER_X0") + 0.1
	return [tp(Vector3(x + 1.4, Y0, -22.0), Vector3(-0.08, 0, 1), 10.0),
		wp(x + 0.9, -10.0, 12.0, {"r": 1.0}),
		wp(x + 0.15, -6.2, 12.0, {"r": 0.9, "act": "grind", "exit": "ride", "end": _v(Vector3(x, 1.0, 46.0))}),
		wp(x + 3.5, 52.0, 5.0, {"r": 3.0, "tmo": 16.0})]


func _planks() -> Array:
	var a: Vector3 = zone("pier_gap_a")
	return [tp(Vector3(55.0, Y0, 38.0), Vector3(0, 0, 1), 4.0),
		wp(55.0, 52.0, 9.5, {"r": 1.5}),
		wp(55.0, K("PIER_GAP_Z0") - 1.0, 9.5, {"r": 0.8, "act": "ollie", "h": 10}),
		wp(55.0, 74.0, 6.0, {"r": 2.5})]


func _pier_air() -> Array:
	var lip: Vector3 = zone("pier_qp_lip")
	return [tp(Vector3(54.0, Y0, 70.0), Vector3(0, 0, 1), 5.0),
		wp(54.0, 88.0, 12.0, {"r": 1.5}),
		wp(54.0, lip.z - 3.0, 12.0, {"r": 1.0, "pump": true}),
		wp(54.0, lip.z + 0.5, 12.0, {"r": 0.8, "act": "air", "grab": true, "tmo": 10.0}),
		wp(54.0, 84.0, 6.0, {"r": 3.0})]


func _rock_hop() -> Array:
	var k: Vector3 = zone("rock_kick")
	var y: float = K("SAND_Y") + 0.1
	return [tp(Vector3(k.x - 18.0, y, k.z), Vector3(1, 0, 0), 5.0),
		wp(k.x - 8.0, k.z, 11.0, {"r": 1.5}),
		wp(k.x - 0.4, k.z, 11.0, {"r": 0.8, "act": "air", "grab": true}),
		wp(k.x + 16.0, k.z, 6.0, {"r": 2.5})]


func _quarter_west() -> Array:
	var z: float = -14.0
	var lip_x: float = -K("HALF_X") + 1.5
	return [tp(Vector3(-74.0, Y0, -11.0), Vector3(-1, 0, 0), 6.0),
		wp(-92.0, -11.0, 11.0, {"r": 1.5}),
		wp(lip_x + 9.0, z, 11.0, {"r": 1.5}),
		wp(lip_x + 3.0, z, 11.0, {"r": 1.0, "pump": true}),
		wp(lip_x + 0.5, z, 11.0, {"r": 0.8, "act": "air", "grab": true, "revert": true}),
		wp(lip_x + 14.0, z, 6.0, {"r": 2.5})]
