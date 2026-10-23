class_name DtTrain
extends AnimatableBody3D
## A monorail train on one of the Line's beams: three cars straddling the beam, cruising along X, braking into the
## station for a short dwell, and braking hard for a skater on its beam ahead (like Traffic does for the skater). It is
## solid (world layer); one that runs into the skater while moving knocks them into a bail, the TrafficCar way.
## Past the city's edge it hides and comes round again from the other end. One mesh, one draw call.

signal hit_skater(train: DtTrain)

const CRUISE: float = 14.0
const ACCEL: float = 1.5
const BRAKE: float = 2.0
const BRAKE_HARD: float = 7.0
const CAR_LEN: float = 9.0
const CARS: int = 3
const GAP: float = 0.5
const HALF_W: float = 1.4
const X_END: float = 330.0
const DWELL: float = 7.0
const STOP_SHORT: float = 6.0
const HIT_SPEED: float = 2.0
const KNOCK_UP: float = 3.0

var beam_z: float = 0.0
var dir: float = 1.0
var x: float = 0.0
var speed: float = CRUISE
var length: float = 0.0
var _dwell: float = 0.0
var _served: bool = false
var _cooldown: float = 0.0


static func create(z: float, direction: float, x0: float, paint: Color, stripe: Color) -> DtTrain:
	var t := DtTrain.new()
	t.name = "Train"
	t.collision_layer = 0  # switched on near the skater (see _physics_process)
	t.collision_mask = 0
	t.sync_to_physics = true
	t.beam_z = z
	t.dir = direction
	t.x = x0
	t.length = float(CARS) * CAR_LEN + float(CARS - 1) * GAP
	t.rotation.y = 0.0 if direction > 0.0 else PI
	var bt := DtBatch.new()
	var x_start: float = -t.length * 0.5
	for i: int in CARS:
		var a: float = x_start + float(i) * (CAR_LEN + GAP)
		DtTrain._car(bt, a, a + CAR_LEN, paint, stripe, i == CARS - 1, i == 0)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(CAR_LEN, 2.95, HALF_W * 2.0)
		cs.shape = shape
		cs.position = Vector3(a + CAR_LEN * 0.5, 1.55, 0.0)
		t.add_child(cs)
	var mi: MeshInstance3D = bt.instance("Body", true)
	t.add_child(mi)
	t.position = Vector3(x0, DtPlan.MONO_Y, z)
	return t


## One car from local x a to b (the front is +X): skirts either side of the beam, the body above it, a window band,
## a stripe, doors, a rounded roof, and a sloped nose on the end cars.
static func _car(bt: DtBatch, a: float, b: float, paint: Color, stripe: Color, front: bool, rear: bool) -> void:
	var l: float = b - a
	var cx: float = (a + b) * 0.5
	var glass := Color("27384f")
	for s: float in [-1.0, 1.0]:
		bt.box(Vector3(cx, -0.42, s * 1.0), Vector3(l, 0.95, 0.8), paint.darkened(0.12))
	bt.box(Vector3(cx, 1.55, 0.0), Vector3(l, 2.9, HALF_W * 2.0), paint)
	bt.box(Vector3(cx, 3.1, 0.0), Vector3(l - 0.3, 0.3, HALF_W * 1.6), paint.lightened(0.15))
	for s: float in [-1.0, 1.0]:
		var zf: float = s * (HALF_W + 0.01)
		bt.box(Vector3(cx, 0.75, zf), Vector3(l, 0.3, 0.04), stripe)
		bt.box(Vector3(cx, 1.95, zf), Vector3(l - 0.8, 0.9, 0.05), glass)
		for k: int in 4:
			bt.box(Vector3(a + 0.6 + float(k) * (l - 1.2) / 3.0, 1.95, zf * 1.002), Vector3(0.18, 0.95, 0.06), paint)
		bt.box(Vector3(cx, 1.45, zf * 1.004), Vector3(1.3, 2.3, 0.05), paint.lightened(0.25))
		bt.box(Vector3(cx, 1.45, zf * 1.006), Vector3(0.05, 2.3, 0.06), paint.darkened(0.3))
	for e: Array in [[front, b, 1.0], [rear, a, -1.0]]:
		if not bool(e[0]):
			continue
		var ex: float = float(e[1])
		var sx: float = float(e[2])
		var nose := PackedVector2Array([Vector2(0.0, -0.9), Vector2(0.0, 3.0), Vector2(0.9 * sx, 2.4), Vector2(1.5 * sx, 1.0), Vector2(1.5 * sx, -0.9)])
		var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(ex, 0.0, 0.0))
		bt.prism(nose, -HALF_W, HALF_W, paint, xf)
		bt.box(Vector3(ex + sx * 0.75, 2.1, 0.0), Vector3(0.9, 0.7, HALF_W * 1.6), glass, Basis(Vector3.FORWARD, sx * 0.55))
		bt.box(Vector3(ex + sx * 1.45, 0.5, 0.0), Vector3(0.12, 0.25, HALF_W * 1.4), Color("fff2c0"))


func _physics_process(delta: float) -> void:
	var target: float = CRUISE
	# the station: brake into it, wait, go
	var to_station: float = (0.0 - x) * dir
	if _dwell > 0.0:
		_dwell -= delta
		target = 0.0
		if _dwell <= 0.0:
			_served = true
	elif not _served and to_station > -0.5:
		target = minf(target, sqrt(2.0 * BRAKE * maxf(to_station, 0.0)))
		if to_station < 0.6 and speed < 0.4:
			_dwell = DWELL
	if _served and to_station < -60.0:
		_served = false
	# the skater on this beam, ahead
	var sk: Node3D = get_tree().get_first_node_in_group("skater") as Node3D if is_inside_tree() else null
	if sk != null:
		var p: Vector3 = sk.global_position
		var ahead: float = (p.x - x) * dir - length * 0.5
		if absf(p.z - beam_z) < 2.4 and p.y > DtPlan.MONO_Y - 1.5 and p.y < DtPlan.MONO_Y + 4.5 and ahead > -length and ahead < 70.0:
			target = minf(target, sqrt(2.0 * BRAKE_HARD * maxf(ahead - STOP_SHORT, 0.0)))
	if target > speed:
		speed = minf(target, speed + ACCEL * delta)
	else:
		speed = maxf(target, speed - BRAKE_HARD * delta)
	x += dir * speed * delta
	if x * dir > X_END:
		x = -dir * X_END
		_served = false
	global_position = Vector3(x, DtPlan.MONO_Y, beam_z)
	visible = absf(x) < X_END - 20.0
	# solid only while the skater is anywhere near it (a moving body on the world layer costs physics pairs all the
	# way along the Line; nothing else needs to touch it)
	var near: bool = sk != null and absf(sk.global_position.x - x) < length * 0.5 + 30.0 and absf(sk.global_position.z - beam_z) < 12.0
	var want_layer: int = 1 if near else 0
	if collision_layer != want_layer:
		collision_layer = want_layer
	_cooldown = maxf(_cooldown - delta, 0.0)
	_check_hit(sk)


func _check_hit(sk: Node3D) -> void:
	if sk == null or _cooldown > 0.0 or speed < HIT_SPEED:
		return
	var lp: Vector3 = to_local(sk.global_position)
	if absf(lp.x) > length * 0.5 + 1.8 or absf(lp.z) > HALF_W + 0.5 or lp.y < -0.6 or lp.y > 3.4:
		return
	if lp.x < length * 0.5 - 1.0:
		return  # alongside, not in front: the body itself is the wall
	var st: Object = sk.get("state") as Object
	if st != null and str(st.call("state_name")) == "BAIL":
		return
	if not sk.has_method("_bail"):
		return
	_cooldown = 2.0
	sk.set("velocity", Vector3(dir, 0.0, 0.0) * (speed + 2.0) + Vector3.UP * KNOCK_UP)
	sk.call("_bail")
	hit_skater.emit(self)
