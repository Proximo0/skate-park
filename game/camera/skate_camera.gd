class_name SkateCamera
extends Camera3D
## THUG-style chase camera. Sits behind and above the skater along its facing and looks ahead along the velocity.
## In vert air or on a steep surface it stops swinging behind the skater: it holds the last ground yaw, rises and
## pulls back so the ramp and the skater both stay in frame. In BAIL it slowly orbits. Never goes below the ground
## and pulls in when a wall is between the look point and the camera. No speed shake (motion sickness).
## Pure math is in static functions for unit tests; the node only feeds the target's state and runs the raycasts.

const DISTANCE := 3.5  ## m behind the skater on the ground (was 4.5: the skater read ~100 px tall at 720p)
const HEIGHT := 1.45  ## m above the skater: a lower, flatter angle shows the ground rushing past
const VERT_DISTANCE := 5.0  ## air above a ramp lip or on a wall: still farther and higher so the landing stays in frame
const VERT_HEIGHT := 2.5
const LOOK_HEIGHT := 0.9
const LOOK_AHEAD_FACTOR := 0.12  ## seconds of velocity projected ahead of the look point
const LOOK_AHEAD_MAX := 1.5
const MIN_GROUND_CLEARANCE := 0.5
const WALL_MARGIN := 0.3
const POS_RATE := 6.0  ## 1/s, framerate-independent damping
const LOOK_RATE := 8.0
const YAW_RATE := 4.0  ## 1/s: time constant 0.25 s, the yaw lag
const SNAP_YAW_FACTOR := 3.0  ## yaw follow rate during a ramp snap (the skater often turns right round onto the coping)
const WALK_YAW_FACTOR := 0.2  ## yaw follow rate on foot, as a share of YAW_RATE
const WALK_ZOOM := 0.62  ## on foot the camera sits closer and lower: the offset is scaled by this
const VERT_BLEND_RATE := 3.0
const ORBIT_RATE := 0.35  ## rad/s while bailing
const FOV_BASE := 68.0
const FOV_FAST := 84.0  ## at FOV_SPEED_HI and above
const FOV_SPEED_LO := 5.0  ## m/s where the speed push starts
const FOV_SPEED_HI := 22.0
const FOV_CURVE := 1.6  ## > 1: subtle at cruise, stronger toward top speed
const PUSH_DISTANCE := 0.9  ## extra m the camera trails behind at FOV_SPEED_HI (it eases back, so speed feels like a drag)
const FOV_RATE := 4.0
const PUNCH_TIME := 0.12  ## s: the landing dip and FOV punch, one short hit with no lingering shake
const PUNCH_FOV := 4.0  ## degrees of extra FOV at the start of a landing punch
const PUNCH_DIP := 0.14  ## m the camera drops at the start of a landing punch
const RAY_UP := 1.0
const RAY_DOWN := 40.0
const WORLD_MASK := 1
const ARM_RADIUS := 0.22  ## m: the spring-arm sphere swept from the skater's head to the desired camera position
const TELEPORT_DIST := 4.0  ## m a skater moves in one physics tick only when respawned or dropped in: the camera snaps

var target: Skater

var _primed: bool = false
var _yaw: float = 0.0
var _vert_blend: float = 0.0
var _walk_blend: float = 0.0
var _cam_pos: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
var _fov: float = FOV_BASE
var _push: float = 0.0
var _punch: float = 0.0  ## 1 at the landing, decays to 0 over PUNCH_TIME
var _punch_target: Skater
var _last_skater_pos: Vector3 = Vector3.ZERO
var _have_last: bool = false


## Forget the damped state: the next physics tick puts the camera straight behind the skater.
func snap() -> void:
	_primed = false


static func yaw_from_facing(facing: Vector3) -> float:
	return atan2(-facing.x, -facing.z)


static func facing_from_yaw(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## Offset from the skater to the camera: behind the facing (horizontal), then up. Vert uses the higher, farther pose.
static func desired_offset(facing: Vector3, vert: bool) -> Vector3:
	var back: Vector3 = -facing
	back.y = 0.0
	if back.length() < 0.1:
		back = Vector3.BACK
	var dist: float = VERT_DISTANCE if vert else DISTANCE
	var height: float = VERT_HEIGHT if vert else HEIGHT
	return back.normalized() * dist + Vector3.UP * height


## Point the camera looks at: above the skater, nudged ahead along the horizontal velocity.
static func look_target(skater_pos: Vector3, velocity: Vector3) -> Vector3:
	var ahead: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * LOOK_AHEAD_FACTOR
	if ahead.length() > LOOK_AHEAD_MAX:
		ahead = ahead.normalized() * LOOK_AHEAD_MAX
	return skater_pos + Vector3.UP * LOOK_HEIGHT + ahead


static func fov_for_speed(speed: float) -> float:
	return FOV_BASE + (FOV_FAST - FOV_BASE) * speed_push(speed)


## 0 at or below FOV_SPEED_LO, 1 at FOV_SPEED_HI, eased so cruise is subtle and top speed is strong.
static func speed_push(speed: float) -> float:
	var t: float = clampf((speed - FOV_SPEED_LO) / (FOV_SPEED_HI - FOV_SPEED_LO), 0.0, 1.0)
	return pow(t, FOV_CURVE)


## Framerate-independent exponential damping: `rate` is 1/s, the result moves (1 - e^(-rate*delta)) of the way.
static func damp(current: float, target_value: float, rate: float, delta: float) -> float:
	return current + (target_value - current) * (1.0 - exp(-rate * maxf(delta, 0.0)))


static func damp_vec(current: Vector3, target_value: Vector3, rate: float, delta: float) -> Vector3:
	return current + (target_value - current) * (1.0 - exp(-rate * maxf(delta, 0.0)))


static func damp_angle(current: float, target_value: float, rate: float, delta: float) -> float:
	var step: float = angle_difference(current, target_value)
	return current + step * (1.0 - exp(-rate * maxf(delta, 0.0)))


static func ground_lift(p: Vector3, ground_y: float, clearance: float) -> Vector3:
	return Vector3(p.x, maxf(p.y, ground_y + clearance), p.z)


## The wall hit point pulls the camera toward the look point, stopping `margin` short of it.
static func pulled_in(look: Vector3, desired: Vector3, hit: Vector3, margin: float) -> Vector3:
	var dir: Vector3 = desired - look
	if dir.length() < 0.001:
		return look
	var dist: float = maxf((hit - look).length() - margin, 0.0)
	return look + dir.normalized() * dist


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if _punch_target != target:
		_punch_target = target
		target.landed.connect(_on_landed)
	_punch = maxf(_punch - delta / PUNCH_TIME, 0.0)
	var grinding: bool = target.state.state == SkateState.State.GRIND
	var bailing: bool = target.state.state == SkateState.State.BAIL
	var steep: bool = target.board_up.y < 0.5 and not grinding
	var vert: bool = target.vert_air or steep
	var skater_pos: Vector3 = target.global_position
	if _have_last and skater_pos.distance_to(_last_skater_pos) > TELEPORT_DIST:
		_primed = false  # respawn, restart or drop-in: hard snap instead of gliding through the park
	_last_skater_pos = skater_pos
	_have_last = true
	# The wall ray starts at the skater's head, not at the lookahead point: the lookahead can sit inside the
	# deck of a ramp, and a ray that starts inside solid geometry always reports a hit.
	# On a steep surface the head is offset along the board's up so the arm starts in the air, not inside the wall.
	var eye: Vector3 = skater_pos + Vector3.UP * LOOK_HEIGHT
	if steep or target.vert_air:
		var up: Vector3 = target.board_up.normalized() if target.board_up.length() > 0.1 else Vector3.UP
		eye = skater_pos + up * LOOK_HEIGHT
	var goal_look: Vector3 = look_target(skater_pos, target.velocity) + Vector3.UP * (1.0 if vert else 0.0)

	if not _primed:
		_primed = true
		_yaw = yaw_from_facing(target.facing)
		_vert_blend = 1.0 if vert else 0.0
		_look = goal_look
		_fov = fov_for_speed(target.speed)
		_push = 0.0
		_punch = 0.0
		_cam_pos = _constrain(skater_pos + desired_offset(facing_from_yaw(_yaw), vert), eye)

	if bailing:
		_yaw = wrapf(_yaw + ORBIT_RATE * delta, -PI, PI)
	elif not vert:
		# On foot the stick is camera-relative, so a fast follow would chase its own tail: swing slowly instead.
		var walking: bool = target.state.state == SkateState.State.WALK
		var rate: float = YAW_RATE * (WALK_YAW_FACTOR if walking else 1.0) * (SNAP_YAW_FACTOR if target.snapping() else 1.0)
		_yaw = damp_angle(_yaw, yaw_from_facing(target.facing), rate, delta)
	# else: hold the last ground yaw so the camera does not swing under the ramp.

	_vert_blend = damp(_vert_blend, 1.0 if vert else 0.0, VERT_BLEND_RATE, delta)
	var fwd: Vector3 = facing_from_yaw(_yaw)
	var offset: Vector3 = desired_offset(fwd, false).lerp(desired_offset(fwd, true), _vert_blend)
	_walk_blend = damp(_walk_blend, 1.0 if target.state.state == SkateState.State.WALK else 0.0, VERT_BLEND_RATE, delta)
	offset *= lerpf(1.0, WALK_ZOOM, _walk_blend)
	_push = damp(_push, speed_push(target.speed) if target.state.state != SkateState.State.WALK else 0.0, FOV_RATE, delta)
	offset += Vector3(offset.x, 0.0, offset.z).normalized() * PUSH_DISTANCE * _push
	var goal_pos: Vector3 = _constrain(skater_pos + offset, eye)

	if target.camera_hold > 0.0:
		# a ramp snap's drop-in: rise up behind the coping and watch the skater drop down the wall (following it round
		# would swing the arm into the ramp)
		_cam_pos = damp_vec(_cam_pos, target.camera_anchor, POS_RATE, delta)
		_look = damp_vec(_look, skater_pos + Vector3.UP * 0.6, LOOK_RATE * 1.5, delta)
	else:
		_cam_pos = damp_vec(_cam_pos, goal_pos, POS_RATE, delta)
		_cam_pos = _constrain(_cam_pos, eye)
		_look = damp_vec(_look, goal_look, LOOK_RATE, delta)
	_fov = damp(_fov, fov_for_speed(target.speed), FOV_RATE, delta)

	var hit: float = _punch * _punch
	global_position = _cam_pos + Vector3.DOWN * PUNCH_DIP * hit
	fov = _fov + PUNCH_FOV * hit
	if not _cam_pos.is_equal_approx(_look):
		look_at(_look, Vector3.UP)


func _on_landed(result: String) -> void:
	if result != "bail":
		_punch = 1.0 if result == "clean" else 0.7


## Keeps the camera above the ground under it and out of walls between it and the look point.
func _constrain(p: Vector3, look: Vector3) -> Vector3:
	var out: Vector3 = p
	var down: Dictionary = _ray(out + Vector3.UP * RAY_UP, out + Vector3.DOWN * RAY_DOWN)
	if not down.is_empty():
		out = ground_lift(out, (down["position"] as Vector3).y, MIN_GROUND_CLEARANCE)
	out = _arm(look, out)
	return out


## Spring arm: sweeps a small sphere from the head to the desired position and stops short of the first wall.
## When the sphere starts inside geometry the thin ray is the fallback. Pulling in is instant; easing back out
## comes from the position damping.
func _arm(look: Vector3, goal: Vector3) -> Vector3:
	var motion: Vector3 = goal - look
	var len: float = motion.length()
	if len < 0.001:
		return goal
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = ARM_RADIUS
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, look)
	q.motion = motion
	q.collision_mask = WORLD_MASK
	var res: PackedFloat32Array = space.cast_motion(q)
	if res.size() >= 2 and res[0] < 1.0 and res[1] < 1.0 and res[0] > 0.0:
		return look + motion * res[0]
	var wall: Dictionary = _ray(look, goal)
	if not wall.is_empty():
		return pulled_in(look, goal, wall["position"] as Vector3, WALL_MARGIN)
	return goal


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	return space.intersect_ray(query)
