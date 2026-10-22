class_name TrafficCar
extends AnimatableBody3D
## One car of a Traffic node: a CarModel (body, spinning wheels, lamps) on an AnimatableBody3D (world layer 1, boxes
## sized from the model) that Traffic moves along its lane each physics tick. A HitArea round the bonnet watches for
## the skater: a car moving at least HIT_SPEED that touches them knocks them into a bail (Skater._bail via the slam and
## ragdoll path, carrying the car's speed) and emits hit_skater. The body leans a little into turns and dips under
## braking (visual only).

signal hit_skater(car: TrafficCar)

const KNOCK_UP: float = 3.0
const HIT_COOLDOWN: float = 2.0

var lane: int = 0
var s: float = 0.0  ## arc length along the lane
var speed: float = 0.0
var speed_factor: float = 1.0
var half_length: float = 2.1
var model: CarModel
var _yaw: float = 0.0
var _accel_vis: float = 0.0
var _lean: float = 0.0
var _hit_area: Area3D
var _cooldown: float = 0.0


static func create(kind: String, paint: Color) -> TrafficCar:
	var car := TrafficCar.new()
	car.collision_layer = 1
	car.collision_mask = 0
	car.sync_to_physics = true  # riders on the roof are carried along
	car.model = CarModel.create(kind, paint)
	car.add_child(car.model)
	var bb: AABB = car.model.aabb
	car.half_length = bb.size.z * 0.5
	var belt: float = bb.position.y + bb.size.y * 0.55
	car._box(Vector3(bb.size.x, belt, bb.size.z), Vector3(bb.get_center().x, belt * 0.5, bb.get_center().z), "CollisionBody")
	var cab_len: float = bb.size.z * 0.55
	car._box(Vector3(bb.size.x - 0.12, bb.end.y - belt, cab_len), Vector3(0.0, (bb.end.y + belt) * 0.5, bb.get_center().z + bb.size.z * 0.08), "CollisionCabin")
	car._hit_area = Area3D.new()
	car._hit_area.name = "HitArea"
	car._hit_area.collision_layer = 0
	car._hit_area.collision_mask = 2  # the skater's layer
	car._hit_area.monitorable = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(bb.size.x + 0.5, belt + 0.4, bb.size.z * 0.5 + 0.6)
	cs.shape = shape
	cs.position = Vector3(0.0, (belt + 0.4) * 0.5, bb.position.z + bb.size.z * 0.25 - 0.3)
	car._hit_area.add_child(cs)
	car.add_child(car._hit_area)
	return car


func _box(size: Vector3, centre: Vector3, node_name: String) -> void:
	var cs := CollisionShape3D.new()
	cs.name = node_name
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = centre
	add_child(cs)


## Travel direction (the model's nose, -Z).
func forward() -> Vector3:
	return -global_transform.basis.z


## Snaps the car onto its lane at arc length s.
func place(path: LanePath) -> void:
	var t: Vector3 = path.tangent(s, 2.0)
	_yaw = atan2(-t.x, -t.z)
	transform = Transform3D(Basis(Vector3.UP, _yaw), path.sample(s))


## One tick: speed toward `target` (accelerating at `accel`, braking at up to `brake`), then along the lane.
func drive(path: LanePath, target: float, delta: float, brake: float, accel: float) -> void:
	var before: float = speed
	if target > speed:
		# ease in near the target so cars do not jerk to a constant speed
		var k: float = clampf((target - speed) / 2.0, 0.25, 1.0)
		speed = minf(target, speed + accel * k * delta)
	else:
		speed = maxf(target, speed - brake * delta)
	speed = maxf(speed, 0.0)
	s = path.wrap_s(s + speed * delta)
	var pos: Vector3 = path.sample(s)
	# steer toward the lane a little ahead (the front axle leads), turning at a finite rate
	var t: Vector3 = path.tangent(s + 1.2, 2.0)
	var want: float = atan2(-t.x, -t.z)
	var dyaw: float = angle_difference(_yaw, want)
	_yaw += dyaw * (1.0 - exp(-10.0 * delta))
	global_transform = Transform3D(Basis(Vector3.UP, _yaw), pos)
	# visual body motion: dive under braking, squat on pull-away, lean out of turns
	var acc: float = (speed - before) / maxf(delta, 0.0001)
	_accel_vis = lerpf(_accel_vis, acc, 1.0 - exp(-4.0 * delta))
	_lean = lerpf(_lean, clampf(dyaw / maxf(delta, 0.0001) * speed * 0.02, -0.05, 0.05), 1.0 - exp(-5.0 * delta))
	model.rotation = Vector3(clampf(-_accel_vis * 0.006, -0.03, 0.03), 0.0, _lean)
	model.roll(speed * delta)
	model.set_brake(clampf(-_accel_vis / 3.0, 0.0, 1.0) if speed > 0.3 or before > 0.3 else 0.6)
	_cooldown = maxf(_cooldown - delta, 0.0)


## Knocks the skater down when this car runs into them.
func check_hit(skater: Node3D, min_speed: float) -> void:
	if skater == null or _cooldown > 0.0 or speed < min_speed:
		return
	if not _hit_area.overlaps_body(skater):
		return
	var st: Object = skater.get("state") as Object
	if st != null and str(st.call("state_name")) == "BAIL":
		return
	if not skater.has_method("_bail"):
		return
	_cooldown = HIT_COOLDOWN
	var push: Vector3 = forward() * (speed + 2.0) + Vector3.UP * KNOCK_UP
	skater.set("velocity", push)
	skater.call("_bail")
	hit_skater.emit(self)
