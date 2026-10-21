class_name Walker
extends RefCounted
## On-foot movement for the Skater while it carries the board (SkateState.WALK). The maths is static and unit tested;
## step() drives the skater's CharacterBody3D. Camera-relative 8-way movement like THUG walking: the stick is read
## against the camera's yaw (or `ref_yaw` when there is no camera), the body turns smoothly to face the way it moves,
## and the floor is followed with snap. Stick length picks the speed: a half tilt walks, a full stick runs.

const DEADZONE: float = 0.15  ## stick length below which the skater stands still
const WALK_TILT: float = 0.6  ## stick length that gives exactly walk_speed; full stick gives run_speed
const TURN_RATE: float = 14.0  ## 1/s, exponential turn of the body toward the move direction
const STEP_OFF_TIME: float = 0.25  ## the step-off transition, s
const MIN_WALK_TIME: float = 0.2  ## shortest walk before the board can go back down, s
const DISMOUNT_STOP_TIME: float = 0.5  ## a hop-off at speed jogs to a stop in about this long, s
const MIN_CARRY_DECEL: float = 8.0
const FLOOR_MAX_ANGLE: float = 45.0  ## degrees: steeper than this is a wall to a walker, and it slides down
const SNAP_LENGTH: float = 0.6

var facing: Vector3 = Vector3.FORWARD  ## horizontal direction the body faces
var h_speed: float = 0.0  ## horizontal speed, m/s (read by the poser)
var phase: float = 0.0  ## stride cycles (one cycle = both feet), read by the poser
var step_time: float = 0.0  ## seconds since stepping off
var ref_yaw: float = 0.0  ## camera yaw used when there is no camera
var carry_decel: float = 0.0  ## deceleration while shedding the speed carried off the board, 0 = use walk_accel
var grounded: bool = true


## Starts a walk from the skater's current heading, with `speed_in` m/s carried off the board.
func begin(heading: Vector3, speed_in: float) -> void:
	var h: Vector3 = Vector3(heading.x, 0.0, heading.z)
	facing = h.normalized() if h.length() > 0.01 else Vector3.FORWARD
	ref_yaw = yaw_from_forward(facing, 0.0)
	h_speed = speed_in
	phase = 0.0
	step_time = 0.0
	grounded = true
	carry_decel = maxf(MIN_CARRY_DECEL, speed_in / DISMOUNT_STOP_TIME) if speed_in > 1.0 else 0.0


# --- pure maths ---------------------------------------------------------------------------------------------

## Camera yaw (rotation about Y, 0 = looking down -Z) from its forward vector; `fallback` if it looks straight down.
static func yaw_from_forward(fwd: Vector3, fallback: float) -> float:
	if Vector2(fwd.x, fwd.z).length() < 0.05:
		return fallback
	return atan2(-fwd.x, -fwd.z)


## Walking speed for a stick length: 0 in the dead zone, walk_speed at WALK_TILT, run_speed at a full stick.
static func speed_for(stick_len: float, walk: float, run: float) -> float:
	var m: float = clampf(stick_len, 0.0, 1.0)
	if m < DEADZONE:
		return 0.0
	if m <= WALK_TILT:
		return walk * m / WALK_TILT
	return lerpf(walk, run, (m - WALK_TILT) / (1.0 - WALK_TILT))


## World direction (unit, horizontal) for a stick (x right, y down = back) seen from a camera with this yaw.
static func move_dir(stick: Vector2, yaw: float) -> Vector3:
	var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var d: Vector3 = right * stick.x + fwd * -stick.y
	return d.normalized() if d.length() > 0.0001 else Vector3.ZERO


static func target_velocity(stick: Vector2, yaw: float, walk: float, run: float) -> Vector3:
	return move_dir(stick, yaw) * speed_for(stick.length(), walk, run)


## Moves `cur` toward `target` (both horizontal) by at most accel * delta, or decel * delta while it is faster
## than the target and `decel` is set.
static func approach(cur: Vector3, target: Vector3, accel: float, decel: float, delta: float) -> Vector3:
	var rate: float = decel if (decel > 0.0 and cur.length() > target.length()) else accel
	return cur.move_toward(target, rate * delta)


## Initial upward speed that reaches `height` under `gravity`.
static func jump_speed(height: float, gravity: float) -> float:
	return sqrt(2.0 * maxf(gravity, 0.01) * maxf(height, 0.0))


## `cur` turned toward `want` (both horizontal) by the fraction 1 - e^(-rate * delta) of the angle between them.
static func turn_toward_dir(cur: Vector3, want: Vector3, rate: float, delta: float) -> Vector3:
	if want.length() < 0.0001:
		return cur
	var ang: float = cur.signed_angle_to(want, Vector3.UP)
	return cur.rotated(Vector3.UP, ang * (1.0 - exp(-rate * delta))).normalized()


## Stride length of one full cycle (both feet) at this speed, m. Longer strides when running.
static func cycle_length(speed: float) -> float:
	return 1.1 + 0.3 * speed


# --- stepping -----------------------------------------------------------------------------------------------

## One physics tick on `body`. `cam_forward` is the camera's forward vector (Vector3.ZERO = no camera).
func step(body: CharacterBody3D, delta: float, stick: Vector2, jump: bool, tune: PhysicsTuning,
		cam_forward: Vector3) -> void:
	step_time += delta
	var yaw: float = yaw_from_forward(cam_forward, ref_yaw) if cam_forward != Vector3.ZERO else ref_yaw
	ref_yaw = yaw
	var target: Vector3 = target_velocity(stick, yaw, tune.walk_speed, tune.run_speed)
	var vel: Vector3 = body.velocity
	var vh: Vector3 = Vector3(vel.x, 0.0, vel.z)
	vh = approach(vh, target, tune.walk_accel, carry_decel, delta)
	if carry_decel > 0.0 and vh.length() <= target.length() + 0.05:
		carry_decel = 0.0
	var vy: float = vel.y - tune.gravity * delta
	var on_floor: bool = body.is_on_floor()
	var snap: float = SNAP_LENGTH
	if on_floor and jump and step_time >= STEP_OFF_TIME * 0.5:
		vy = jump_speed(tune.walk_jump, tune.gravity)
		snap = 0.0
	elif vy > 0.0:
		snap = 0.0
	if target.length() > 0.05:
		facing = turn_toward_dir(facing, target.normalized(), TURN_RATE, delta)
	body.velocity = Vector3(vh.x, vy, vh.z)
	body.up_direction = Vector3.UP
	body.floor_max_angle = deg_to_rad(FLOOR_MAX_ANGLE)
	body.floor_snap_length = snap
	body.move_and_slide()
	body.floor_snap_length = SNAP_LENGTH
	grounded = body.is_on_floor()
	var after: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)
	h_speed = after.length()
	if grounded:
		phase = fposmod(phase + h_speed * delta / cycle_length(h_speed), 1.0)


func to_dict() -> Dictionary:
	return {"facing": facing, "h_speed": h_speed, "phase": phase, "step_time": step_time, "ref_yaw": ref_yaw,
			"carry_decel": carry_decel, "grounded": grounded}


func from_dict(d: Dictionary) -> void:
	facing = d["facing"]
	h_speed = d["h_speed"]
	phase = d["phase"]
	step_time = d["step_time"]
	ref_yaw = d["ref_yaw"]
	carry_decel = d["carry_decel"]
	grounded = d["grounded"]
