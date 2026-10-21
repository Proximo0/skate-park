class_name SkateCamera
extends Camera3D
## THUG-style chase camera. Sits behind and above the skater along its facing and looks ahead along the velocity.
## In vert air or on a steep surface it stops swinging behind the skater: it holds the last ground yaw, rises and
## pulls back so the ramp and the skater both stay in frame. In BAIL it slowly orbits. Never goes below the ground
## and pulls in when a wall is between the look point and the camera. No speed shake (motion sickness).
## Pure math is in static functions for unit tests; the node only feeds the target's state and runs the raycasts.

const DISTANCE := 4.5
const HEIGHT := 2.0
const VERT_DISTANCE := 6.0
const VERT_HEIGHT := 3.0
const LOOK_HEIGHT := 0.9
const LOOK_AHEAD_FACTOR := 0.12  ## seconds of velocity projected ahead of the look point
const LOOK_AHEAD_MAX := 1.5
const MIN_GROUND_CLEARANCE := 0.5
const WALL_MARGIN := 0.3
const POS_RATE := 6.0  ## 1/s, framerate-independent damping
const LOOK_RATE := 8.0
const YAW_RATE := 4.0  ## 1/s: time constant 0.25 s, the yaw lag
const VERT_BLEND_RATE := 3.0
const ORBIT_RATE := 0.35  ## rad/s while bailing
const FOV_BASE := 70.0
const FOV_FAST := 78.0
const FOV_SPEED_LO := 12.0
const FOV_SPEED_HI := 20.0
const FOV_RATE := 4.0
const RAY_UP := 1.0
const RAY_DOWN := 40.0
const WORLD_MASK := 1

var target: Skater

var _primed: bool = false
var _yaw: float = 0.0
var _vert_blend: float = 0.0
var _cam_pos: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
var _fov: float = FOV_BASE


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
	var t: float = clampf((speed - FOV_SPEED_LO) / (FOV_SPEED_HI - FOV_SPEED_LO), 0.0, 1.0)
	return FOV_BASE + (FOV_FAST - FOV_BASE) * t


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
	var grinding: bool = target.state.state == SkateState.State.GRIND
	var bailing: bool = target.state.state == SkateState.State.BAIL
	var steep: bool = target.board_up.y < 0.5 and not grinding
	var vert: bool = target.vert_air or steep
	var skater_pos: Vector3 = target.global_position
	# The wall ray starts at the skater's head, not at the lookahead point: the lookahead can sit inside the
	# deck of a ramp, and a ray that starts inside solid geometry always reports a hit.
	var eye: Vector3 = skater_pos + Vector3.UP * LOOK_HEIGHT
	var goal_look: Vector3 = look_target(skater_pos, target.velocity)

	if not _primed:
		_primed = true
		_yaw = yaw_from_facing(target.facing)
		_vert_blend = 1.0 if vert else 0.0
		_look = goal_look
		_cam_pos = _constrain(skater_pos + desired_offset(facing_from_yaw(_yaw), vert), eye)

	if bailing:
		_yaw = wrapf(_yaw + ORBIT_RATE * delta, -PI, PI)
	elif not vert:
		_yaw = damp_angle(_yaw, yaw_from_facing(target.facing), YAW_RATE, delta)
	# else: hold the last ground yaw so the camera does not swing under the ramp.

	_vert_blend = damp(_vert_blend, 1.0 if vert else 0.0, VERT_BLEND_RATE, delta)
	var fwd: Vector3 = facing_from_yaw(_yaw)
	var offset: Vector3 = desired_offset(fwd, false).lerp(desired_offset(fwd, true), _vert_blend)
	var goal_pos: Vector3 = _constrain(skater_pos + offset, eye)

	_cam_pos = damp_vec(_cam_pos, goal_pos, POS_RATE, delta)
	_cam_pos = _constrain(_cam_pos, eye)
	_look = damp_vec(_look, goal_look, LOOK_RATE, delta)
	_fov = damp(_fov, fov_for_speed(target.speed), FOV_RATE, delta)

	global_position = _cam_pos
	fov = _fov
	if not _cam_pos.is_equal_approx(_look):
		look_at(_look, Vector3.UP)


## Keeps the camera above the ground under it and out of walls between it and the look point.
func _constrain(p: Vector3, look: Vector3) -> Vector3:
	var out: Vector3 = p
	var down: Dictionary = _ray(out + Vector3.UP * RAY_UP, out + Vector3.DOWN * RAY_DOWN)
	if not down.is_empty():
		out = ground_lift(out, (down["position"] as Vector3).y, MIN_GROUND_CLEARANCE)
	var wall: Dictionary = _ray(look, out)
	if not wall.is_empty():
		out = pulled_in(look, out, wall["position"] as Vector3, WALL_MARGIN)
	return out


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	return space.intersect_ray(query)
