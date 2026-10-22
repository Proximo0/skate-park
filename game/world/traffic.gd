class_name Traffic
extends Node3D
## Moving traffic for a level: cars (CarModel, from the Houdini glbs in colour variants) driving lanes (LanePath, from
## point lists or Path3Ds) with smooth acceleration and braking, slowing for corners, keeping their distance, stopping
## at signal-controlled intersections and stopping for the skater (and walkers) in front of them. Each car is an
## AnimatableBody3D on the world layer, so the skater collides with it (riding into its side is a wall slam); a car
## that runs into the skater knocks them into a bail (the skater's own slam/ragdoll path). Headlights at night.
##
## Use (in a Level's _ready):
##   var traffic := Traffic.new()
##   add_child(traffic)
##   var lane: int = traffic.add_lane(LanePath.block_loop(Rect2(-40, -30, 80, 60), 0.0, 8.0), 11.0)
##   traffic.add_cars(lane, 5)
##   traffic.add_intersection(Vector3(0, 0, 0), 9.0)  # optional: signals where lanes cross
## Distance LOD, built in: cars are not drawn beyond view_range (140 m from the camera, an engine visibility range on
## every mesh) and a car past it (or with no camera and no skater near) skips its visual motion (wheel roll, lean,
## brake lights); the driving, signals and collisions always run. Levels that set their own visibility_range_end on
## the car meshes after add_cars (downtown) simply replace it.
## Budget: ~20 cars (3 draw calls each by day, 4 at night; a few hundred metres of lanes cost nothing).

signal skater_hit(car: TrafficCar)

const ACCEL: float = 2.4  ## m/s^2, gentle pull away
const BRAKE: float = 5.0  ## m/s^2, normal braking
const BRAKE_HARD: float = 9.0  ## m/s^2, emergency stop for the skater
const LAT_ACCEL: float = 2.6  ## m/s^2 allowed in a turn (sets the corner speed)
const HEADWAY: float = 1.2  ## seconds of gap kept to the car in front
const MIN_GAP: float = 2.5  ## metres bumper to bumper when stopped
const STOP_AHEAD: float = 2.8  ## metres a car stops short of the skater or a walker
const SKATER_LANE_HALF: float = 1.8  ## how far either side of a car's path counts as "in front"
const HIT_SPEED: float = 2.5  ## a car at least this fast that touches the skater knocks them down
const SIGNAL_GREEN: float = 9.0
const SIGNAL_AMBER: float = 2.2

@export var seed_value: int = 11
## Headlights: -1 = follow the level's mood (Level.is_night()), 0 = off, 1 = on.
@export var lights_mode: int = -1
## Metres from the camera past which cars are not drawn or animated (0 = never culled).
@export var view_range: float = 140.0

var lanes: Array[LanePath] = []
var lane_speed: Array[float] = []
var cars: Array[TrafficCar] = []
## {centre: Vector3, radius: float, phase: float} per intersection; signals alternate between the x-ish and z-ish axis.
var intersections: Array[Dictionary] = []
var time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _lane_entries: Array = []  ## per lane: [[s_entry, intersection index, axis 0/1], ...]
var _night: bool = false


func _ready() -> void:
	_rng.seed = seed_value
	var lvl: Level = Level.of(self)
	_night = lvl.is_night() if lvl != null else false
	if lights_mode >= 0:
		_night = lights_mode == 1
	for c: TrafficCar in cars:
		c.model.set_lights(_night)


## Adds a lane; returns its index. `speed` is the lane's limit in m/s (11 = about 40 km/h).
func add_lane(path: LanePath, speed: float = 11.0) -> int:
	lanes.append(path)
	lane_speed.append(speed)
	_lane_entries.append([])
	_index_entries()
	return lanes.size() - 1


## `count` cars spread evenly along a lane. kinds: any of "hatch", "pickup", "van" (default: a mix); colours: paints to
## pick from (default CarModel.PAINTS). Returns the new cars.
func add_cars(lane: int, count: int, kinds: Array[String] = [], colours: Array[Color] = []) -> Array[TrafficCar]:
	var out: Array[TrafficCar] = []
	var path: LanePath = lanes[lane]
	var pick: Array[String] = ["hatch", "hatch", "pickup", "van"]
	if not kinds.is_empty():
		pick = kinds
	var start: float = _rng.randf() * path.length
	for i: int in count:
		var kind: String = pick[_rng.randi() % pick.size()]
		var paint: Color = colours[_rng.randi() % colours.size()] if not colours.is_empty() else Color(CarModel.PAINTS[_rng.randi() % CarModel.PAINTS.size()])
		var car := TrafficCar.create(kind, paint)
		car.name = "Car%d" % cars.size()
		car.lane = lane
		car.s = path.wrap_s(start + path.length * float(i) / float(maxi(count, 1)))
		car.speed_factor = _rng.randf_range(0.85, 1.05)
		car.speed = lane_speed[lane] * 0.5
		car.place(path)
		car.set_view_range(view_range)
		add_child(car)
		car.model.set_lights(_night)
		car.hit_skater.connect(func(c: TrafficCar) -> void: skater_hit.emit(c))
		cars.append(car)
		out.append(car)
	return out


## A signal-controlled crossing: cars on lanes passing within `radius` of `centre` stop at its edge while their axis is
## red. Axis 0 = lanes running mostly along X, 1 = mostly along Z. Returns the index.
func add_intersection(centre: Vector3, radius: float = 8.0, phase: float = 0.0) -> int:
	intersections.append({"centre": centre, "radius": radius, "phase": phase})
	_index_entries()
	return intersections.size() - 1


## Signal state for an axis at intersection i: "green", "amber" or "red".
func signal_state(i: int, axis: int) -> String:
	var it: Dictionary = intersections[i]
	var cycle: float = (SIGNAL_GREEN + SIGNAL_AMBER) * 2.0
	var u: float = fposmod(time + float(it["phase"]), cycle)
	var green_axis: int = 0 if u < SIGNAL_GREEN + SIGNAL_AMBER else 1
	var into: float = u if green_axis == 0 else u - (SIGNAL_GREEN + SIGNAL_AMBER)
	if axis != green_axis:
		return "red"
	return "green" if into < SIGNAL_GREEN else "amber"


## Simple signal heads on four poles at an intersection's corners (visual only). Returns the node.
func add_signal_poles(i: int) -> Node3D:
	var poles := TrafficSignals.build(self, i)
	add_child(poles)
	return poles


func _physics_process(delta: float) -> void:
	time += delta
	var sk: Node3D = get_tree().get_first_node_in_group("skater") as Node3D if is_inside_tree() else null
	var walkers: Array[Node] = get_tree().get_nodes_in_group("traffic_obstacle") if is_inside_tree() else []
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye: Vector3 = cam.global_position if cam != null else (sk.global_position if sk != null else Vector3.ZERO)
	var has_eye: bool = cam != null or sk != null
	var vr2: float = (view_range + 10.0) * (view_range + 10.0)
	for car: TrafficCar in cars:
		var path: LanePath = lanes[car.lane]
		var target: float = lane_speed[car.lane] * car.speed_factor
		# corners ahead
		var curv: float = path.curvature_ahead(car.s, maxf(car.speed * 2.5, 8.0))
		if curv > 0.001:
			target = minf(target, sqrt(LAT_ACCEL / curv))
		# the car in front on the same lane
		var gap: float = _gap_ahead(car)
		if gap < INF:
			target = minf(target, maxf(0.0, (gap - MIN_GAP) / HEADWAY))
			if gap < MIN_GAP + 0.5:
				target = 0.0
		# signals
		target = minf(target, _signal_limit(car))
		# the skater and walkers in front
		var hard: bool = false
		if sk != null:
			var lim: float = _obstacle_limit(car, sk.global_position)
			if lim < target:
				target = lim
				hard = true
		for w: Node in walkers:
			var w3: Node3D = w as Node3D
			if w3 != null:
				target = minf(target, _obstacle_limit(car, w3.global_position))
		var visual: bool = not has_eye or view_range <= 0.0 or car.global_position.distance_squared_to(eye) < vr2
		car.drive(path, target, delta, BRAKE_HARD if hard else BRAKE, ACCEL, visual)
		car.check_hit(sk, HIT_SPEED)


## Bumper-to-bumper distance to the next car ahead on the same lane (INF when none).
func _gap_ahead(car: TrafficCar) -> float:
	var path: LanePath = lanes[car.lane]
	var best: float = INF
	for other: TrafficCar in cars:
		if other == car or other.lane != car.lane:
			continue
		var d: float = other.s - car.s
		if path.loop:
			d = fposmod(d, path.length)
		if d <= 0.0:
			continue
		best = minf(best, d - (car.half_length + other.half_length))
	return best


## Speed allowed so the car can stop STOP_AHEAD short of a point in its way (INF when the point is not in its way).
func _obstacle_limit(car: TrafficCar, p: Vector3) -> float:
	var fwd: Vector3 = car.forward()
	var to: Vector3 = p - car.global_position
	var ahead: float = to.dot(fwd)
	if ahead < 0.0 or absf(to.y) > 2.5:
		return INF
	var look: float = car.speed * car.speed / (2.0 * BRAKE) + 14.0
	if ahead > look:
		return INF
	# follow the lane: compare against the path point that far ahead, so curves are handled
	var path: LanePath = lanes[car.lane]
	var on_path: Vector3 = path.sample(car.s + ahead)
	var side: float = Vector2(p.x - on_path.x, p.z - on_path.z).length()
	if side > SKATER_LANE_HALF + 0.3:
		return INF
	var room: float = ahead - car.half_length - STOP_AHEAD
	return 0.0 if room <= 0.0 else sqrt(2.0 * BRAKE * room)


## Speed allowed by the signals ahead on this car's lane.
func _signal_limit(car: TrafficCar) -> float:
	var entries: Array = _lane_entries[car.lane]
	if entries.is_empty():
		return INF
	var path: LanePath = lanes[car.lane]
	var best: float = INF
	for e: Array in entries:
		var stop_s: float = float(e[0]) - car.half_length - 0.5
		var d: float = stop_s - car.s
		if path.loop:
			d = fposmod(d, path.length)
		if d > 40.0:
			continue
		var st: String = signal_state(int(e[1]), int(e[2]))
		if st == "green":
			continue
		if st == "amber" and d < car.speed * car.speed / (2.0 * BRAKE) * 0.8:
			continue  # too close to stop: go through on amber
		best = minf(best, 0.0 if d < 0.3 else sqrt(2.0 * BRAKE * maxf(d - 0.3, 0.0)))
	return best


## For every lane and intersection: where the lane enters the intersection circle, and its axis there.
func _index_entries() -> void:
	for li: int in lanes.size():
		var path: LanePath = lanes[li]
		var list: Array = []
		for ii: int in intersections.size():
			var it: Dictionary = intersections[ii]
			var c: Vector3 = it["centre"]
			var r: float = float(it["radius"])
			var inside: bool = Vector2(path.sample(0.0).x - c.x, path.sample(0.0).z - c.z).length() < r
			var s: float = 0.0
			while s < path.length:
				var p: Vector3 = path.sample(s)
				var now_in: bool = Vector2(p.x - c.x, p.z - c.z).length() < r
				if now_in and not inside:
					var t: Vector3 = path.tangent(s + r)
					list.append([s, ii, 0 if absf(t.x) >= absf(t.z) else 1])
				inside = now_in
				s += 0.5
		_lane_entries[li] = list
