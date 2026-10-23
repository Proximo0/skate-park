extends "res://tests/sim/sim_base.gd"
## Every new level (LevelRegistry, not practice): the skater spawns on the floor and pushes forward for 3 s without
## falling through, bailing or leaving the bounds. Plus the world kit's traffic: a car stops for a skater standing in
## its lane instead of running them over.

const LEVELS: Array[String] = ["warehouse", "beach", "school", "downtown", "hills"]
const RIDE_TICKS: int = 180


func _ride_level(id: String) -> Dictionary:
	root3 = Node3D.new()
	host.add_child(root3)
	var lvl: Level = LevelRegistry.create(id)
	root3.add_child(lvl)
	await attach_skater()
	var sp: Transform3D = lvl.spawn
	place(sp.origin, -sp.basis.z, 0.0)
	await host.get_tree().physics_frame
	var min_y: float = INF
	var left: bool = false
	for i: int in RIDE_TICKS:
		await tick(FWD if i < 120 else NONE)
		min_y = minf(min_y, sk.global_position.y)
		if not lvl.bounds.has_point(Vector2(sk.global_position.x, sk.global_position.z)):
			left = true
	var travelled: float = Vector2(sk.global_position.x - sp.origin.x, sk.global_position.z - sp.origin.z).length()
	var res: Dictionary = {"min_y": min_y, "bails": bails, "left": left, "travelled": travelled, "state": sname()}
	await clear()
	return res


## A skater stopped in a lane in front of a car: the car brakes to a stop short of them, no knock-down.
func _traffic_stops() -> Dictionary:
	root3 = Node3D.new()
	host.add_child(root3)
	var lvl: Level = load("res://game/world/demo/world_demo.gd").new()
	root3.add_child(lvl)
	await attach_skater()
	sk.add_to_group("skater")
	var traffic: Traffic = lvl.get("traffic") as Traffic
	var car: TrafficCar = traffic.cars[0]
	var path: LanePath = traffic.lanes[car.lane]
	var ahead: Vector3 = path.sample(car.s + 22.0)
	place(ahead + Vector3(0.0, 0.1, 0.0), path.tangent(car.s + 22.0), 0.0)
	car.speed = 9.0
	var closest: float = INF
	for i: int in 360:
		await tick()
		var d: float = (car.global_position - sk.global_position).length() - car.half_length
		closest = minf(closest, d)
	var res: Dictionary = {"closest": closest, "bails": bails, "car_speed": car.speed}
	await clear()
	return res


## A skater who cuts in right in front of a moving car (too close to stop) is knocked into a bail.
func _traffic_hits() -> Dictionary:
	root3 = Node3D.new()
	host.add_child(root3)
	var lvl: Level = load("res://game/world/demo/world_demo.gd").new()
	root3.add_child(lvl)
	await attach_skater()
	sk.add_to_group("skater")
	var traffic: Traffic = lvl.get("traffic") as Traffic
	var car: TrafficCar = traffic.cars[0]
	var path: LanePath = traffic.lanes[car.lane]
	car.speed = 9.0
	await host.get_tree().physics_frame
	var at: float = car.s + car.half_length + 0.6
	place(path.sample(at) + Vector3(0.0, 0.1, 0.0), path.tangent(at).cross(Vector3.UP), 0.0)
	for i: int in 90:
		await tick()
	var res: Dictionary = {"bails": bails}
	await clear()
	return res


func run() -> Array:
	var rows: Array = []
	for id: String in LEVELS:
		var r: Dictionary = await _ride_level(id)
		var ok: bool = r["min_y"] > -0.5 and r["bails"] == 0 and not r["left"] and r["travelled"] > 8.0
		rows.append(ok_line("level_%s_spawn_ride" % id, ok,
			"lowest y %.2f (need > -0.5), bails %d (need 0), left bounds %s, rode %.1f m (need > 8), ends %s"
			% [r["min_y"], r["bails"], str(r["left"]), r["travelled"], r["state"]]))
	var t: Dictionary = await _traffic_stops()
	rows.append(ok_line("traffic_stops_for_skater", t["bails"] == 0 and t["closest"] > 0.5 and t["car_speed"] < 0.5,
		"car stopped %.1f m short (need > 0.5), car speed %.2f m/s (need < 0.5), bails %d (need 0)"
		% [t["closest"], t["car_speed"], t["bails"]]))
	var h: Dictionary = await _traffic_hits()
	rows.append(ok_line("traffic_hit_bails_skater", h["bails"] >= 1, "bails %d (need >= 1)" % h["bails"]))
	return rows
