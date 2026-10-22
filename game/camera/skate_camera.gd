class_name SkateCamera
extends Camera3D
## THUG-style chase camera. Sits behind and above the skater along its facing and looks ahead along the velocity.
## In vert air or on a steep surface it stops swinging behind the skater: it holds the last ground yaw, rises and
## pulls back so the ramp and the skater both stay in frame. In BAIL it slowly orbits. Never goes below the ground
## and pulls in when a wall is between the look point and the camera. No speed shake (motion sickness).
## Pure math is in static functions for unit tests; the node only feeds the target's state and runs the raycasts.

const DISTANCE := 3.3  ## m behind the skater on the ground (was 4.5: the skater read ~100 px tall at 720p)
const HEIGHT := 1.35  ## m above the skater: a lower, flatter angle shows the ground rushing past
const VERT_DISTANCE := 3.8  ## air above a ramp lip or on a wall: still farther and higher so the landing stays in frame
const VERT_HEIGHT := 1.8
const LOOK_HEIGHT := 0.9
const BODY_CENTRE := 0.3  ## the skater's collision sphere centre above its origin
const LOOK_AHEAD_FACTOR := 0.12  ## seconds of velocity projected ahead of the look point
const LOOK_AHEAD_MAX := 1.5
const MIN_GROUND_CLEARANCE := 0.5
const WALL_MARGIN := 0.3
const POS_RATE := 6.0  ## 1/s, framerate-independent damping
const LOOK_RATE := 8.0
const POS_LEAD := 0.72  ## share of the position lag (speed / POS_RATE) the goal leads the skater to cancel
const LEAD_MAX_SPEED := 16.0  ## m/s: the lead stops growing here
const YAW_RATE := 4.0  ## 1/s: the yaw velocity aims at this many times the angle still to go (time constant 0.25 s)
const YAW_MAX_RATE := 2.6  ## rad/s: soft cap on the yaw swing (tanh), so a 140 degree re-entry turn takes ~0.9 s, never a whip
const YAW_ACCEL_FACTOR := 4.0  ## the yaw velocity follows its aim at this x the follow rate: 4 is critically damped
const SNAP_YAW_FACTOR := 3.0  ## yaw follow rate during a ramp snap (the skater often turns right round onto the coping)
const SNAP_YAW_MAX := 4.2  ## rad/s at most the yaw swings during a ramp snap or drop-in (about 4 degrees a tick)
const CRANE_STEPS: Array[float] = [0.75, 1.5, 2.25, 3.0, 4.0, 5.0]  ## m the arm tries rising over an obstacle
const CRANE_KEEP := 0.8  ## share of the arm's length a craned goal must keep
const SLOPE_LIFT_MAX := 2.0  ## the slope lift is at most this many times DISTANCE
const LIFT_STEP := 0.04  ## m: see _lift_clear
const LIFT_MAX := 0.12
const PERCH_RATE: float = 3.0  ## 1/s the drop-in perch blends in and out
const CRANE_RATE: float = 3.0  ## 1/s the crane height follows the height that clears
const CRANE_UNBLOCK: float = 0.1  ## hysteresis: once craned, the plain arm must keep this much more to drop back
const CRANE_LINGER := 1.0  ## s the arm keeps craning once the plain chase spot is clear again
const WALK_YAW_FACTOR := 0.2  ## yaw follow rate on foot, as a share of YAW_RATE
const WALK_ZOOM := 0.62  ## on foot the camera sits closer and lower: the offset is scaled by this
const VERT_BLEND_RATE := 3.0
const ORBIT_RATE := 0.35  ## rad/s while bailing
const FOV_BASE := 66.0
const FOV_FAST := 75.0  ## at FOV_SPEED_HI and above (was 84: the rider shrank to ~18% of the frame at 12 m/s)
const FOV_SPEED_LO := 5.0  ## m/s where the speed push starts
const FOV_SPEED_HI := 22.0
const FOV_CURVE := 1.6  ## > 1: subtle at cruise, stronger toward top speed
const PUSH_DISTANCE := 0.35  ## extra m the camera trails behind at FOV_SPEED_HI (it eases back, so speed feels like a drag)
const FOV_RATE := 4.0
const PUNCH_TIME := 0.12  ## s: the landing dip and FOV punch, one short hit with no lingering shake
const PUNCH_FOV := 4.0  ## degrees of extra FOV at the start of a landing punch
const RAY_UP := 0.6  ## m: the ground probe starts this far above the camera. Higher found catwalks and beams overhead and lifted the camera on top of them.
const ARM_SHRINK_FRAC := 0.45  ## the shown arm shortens by at most this share of the gap per tick (a thin rail's graze no longer pops)
const ARM_SHRINK_MAX := 0.4  ## m: ... and by at most this many metres per tick
const ARM_GROW_RATE := 5.0  ## 1/s the shown arm lengthens again once the way is clear
const LAND_MIN_IMPACT := 4.5  ## m/s of landing speed along y where the camera starts to feel the impact
const LAND_MAX_IMPACT := 15.0  ## m/s of landing speed that gives the full impact
const LAND_DIP := 0.3  ## m the camera sinks at a full impact (scaled down with the impact, zero for a small landing)
const LAND_SPRING := 38.0  ## rad/s of the landing dip's spring (a critically light bounce)
const LAND_DAMP := 0.28  ## damping ratio of the landing spring: one visible rebound
const VERT_LOOK_DOWN := 0.35  ## share of the rider's height above the ground the vert-air look point drops by
const VERT_LOOK_DOWN_MAX := 2.6  ## m
const ORBIT_STICK_RATE := 2.6  ## rad/s at full right-stick deflection
const ORBIT_MOUSE_SENS := 0.0045  ## rad per pixel of mouse motion while the right button is held
const ORBIT_PITCH_MAX := 0.55
const ORBIT_RECENTER_DELAY := 0.5  ## s after the last orbit input before the camera swings back behind
const ORBIT_RECENTER_RATE := 3.0
const RAY_DOWN := 40.0
const WORLD_MASK := 1
const ARM_RADIUS := 0.22  ## m: the spring-arm sphere swept from the skater's head to the desired camera position
const TELEPORT_DIST := 4.0  ## m a skater moves in one physics tick only when respawned or dropped in: the camera snaps

var target: Skater
var dbg: Dictionary = {}  ## last tick's goal / damped / final camera position, for tests and the flight recorder

var _primed: bool = false
var _yaw: float = 0.0
var _vert_blend: float = 0.0
var _walk_blend: float = 0.0
var _cam_pos: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
var _fov: float = FOV_BASE
var _push: float = 0.0
var _punch: float = 0.0  ## 1 at the landing, decays to 0 over PUNCH_TIME
var _yaw_vel: float = 0.0  ## rad/s, eased toward the (capped) aim: see YAW_MAX_RATE
var _free_pos: Vector3 = Vector3.ZERO  ## the damped camera position before the wall arm shortens it
var _arm_frac: float = 1.0  ## shown arm length / free arm length, shortened in steps and eased back out
var _air_vy: float = 0.0  ## most negative vertical speed since the last landing (the impact)
var _land_h: float = 0.0  ## landing dip: displacement m (down positive) ...
var _land_v: float = 0.0  ## ... and its velocity, a damped spring
var _look_down: float = 0.0  ## m the vert-air look point sits below the rider, damped
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = 0.0
var _orbit_idle: float = 99.0  ## s since the last orbit input
var _mouse_orbit: Vector2 = Vector2.ZERO  ## mouse motion since the last tick (right button held)
var _punch_target: Skater
var _last_skater_pos: Vector3 = Vector3.ZERO
var _have_last: bool = false
var _slope_lift: float = 0.0  ## m the camera rises over a steep slope behind the skater, damped
var _crane_left: float = 0.0  ## s the arm keeps craning over obstacles after a drop-in, an air or a ramp
var _crane_blocked: bool = false  ## the plain chase spot was blocked on the last crane check
var _crane_h: float = 0.0  ## m the chase goal is craned up, damped toward the CRANE_STEPS height that clears
var _perch_blend: float = 0.0  ## 0 chase .. 1 drop-in perch, damped so the switch to the perch is a glide


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


## One tick of the yaw swing: the velocity eases (critically damped at YAW_ACCEL_FACTOR) toward `diff * rate`, softly
## capped at YAW_MAX_RATE by a tanh so a half-turn takes about a second and never whips. `diff` is the angle still to go.
static func yaw_velocity_step(vel: float, diff: float, rate: float, delta: float) -> float:
	var aim: float = YAW_MAX_RATE * tanh(diff * rate / YAW_MAX_RATE)
	return damp(vel, aim, rate * YAW_ACCEL_FACTOR, delta)


## The shown arm fraction after the wall probe wants `wanted` (0..1) of the free arm: shortening is stepped (a share of
## the gap, at most ARM_SHRINK_MAX m of an arm `arm_len` long), lengthening eases back out.
static func arm_step(shown: float, wanted: float, arm_len: float, delta: float) -> float:
	if wanted < shown:
		var gap: float = shown - wanted
		var step: float = minf(gap * ARM_SHRINK_FRAC, ARM_SHRINK_MAX / maxf(arm_len, 0.5))
		step = maxf(step, minf(gap, 0.02))
		return shown - step
	return damp(shown, wanted, ARM_GROW_RATE, delta)


## Landing impact (m/s downward) to 0..1: nothing for a small landing, 1 at LAND_MAX_IMPACT.
static func impact_strength(impact: float) -> float:
	return smoothstep(LAND_MIN_IMPACT, LAND_MAX_IMPACT, impact)


static func ground_lift(p: Vector3, ground_y: float, clearance: float) -> Vector3:
	return Vector3(p.x, maxf(p.y, ground_y + clearance), p.z)


## The wall hit point pulls the camera toward the look point, stopping `margin` short of it.
static func pulled_in(look: Vector3, desired: Vector3, hit: Vector3, margin: float) -> Vector3:
	var dir: Vector3 = desired - look
	if dir.length() < 0.001:
		return look
	var dist: float = maxf((hit - look).length() - margin, 0.0)
	return look + dir.normalized() * dist


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_mouse_orbit += (event as InputEventMouseMotion).relative


## Right stick / right-button mouse orbit: moves the orbit angles while held, swings back behind after the release.
func _orbit_step(delta: float) -> void:
	var stick := Vector2.ZERO
	if not target.scripted_input:
		for pad: int in Input.get_connected_joypads():
			var v := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
			if v.length() > stick.length():
				stick = v
	if stick.length() < 0.25:
		stick = Vector2.ZERO
	var move := Vector2(stick.x * ORBIT_STICK_RATE * delta, stick.y * ORBIT_STICK_RATE * 0.5 * delta) + _mouse_orbit * ORBIT_MOUSE_SENS
	_mouse_orbit = Vector2.ZERO
	if move != Vector2.ZERO:
		_orbit_idle = 0.0
		_orbit_yaw = wrapf(_orbit_yaw - move.x, -PI, PI)
		_orbit_pitch = clampf(_orbit_pitch + move.y, -ORBIT_PITCH_MAX, ORBIT_PITCH_MAX)
	else:
		_orbit_idle += delta
		if _orbit_idle > ORBIT_RECENTER_DELAY:
			_orbit_yaw = damp_angle(_orbit_yaw, 0.0, ORBIT_RECENTER_RATE, delta)
			_orbit_pitch = damp(_orbit_pitch, 0.0, ORBIT_RECENTER_RATE, delta)
			if absf(_orbit_yaw) < 0.002 and absf(_orbit_pitch) < 0.002:
				_orbit_yaw = 0.0
				_orbit_pitch = 0.0


## The landing dip: a lightly damped spring kicked by _on_landed, scaled by the impact.
func _land_step(delta: float) -> void:
	var accel: float = -LAND_SPRING * LAND_SPRING * _land_h - 2.0 * LAND_DAMP * LAND_SPRING * _land_v
	_land_v += accel * delta
	_land_h += _land_v * delta


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if _punch_target != target:
		_punch_target = target
		target.landed.connect(_on_landed)
	_punch = maxf(_punch - delta / PUNCH_TIME, 0.0)
	_land_step(delta)
	if target.is_on_floor():
		_air_vy = 0.0
	else:
		_air_vy = minf(_air_vy, target.velocity.y)
	_orbit_step(delta)
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
	# The head is taken along the board's up from the body sphere's centre (BODY_CENTRE above the origin) on every
	# slope, not just past the steep threshold: straight up from the origin is inside the ramp on a 50 degree wall,
	# and switching the rule at a threshold made the arm jump.
	var eye: Vector3 = skater_pos + Vector3.UP * LOOK_HEIGHT
	if not grinding and target.state.state != SkateState.State.WALK and target.board_up.length() > 0.1:
		eye = skater_pos + Vector3.UP * BODY_CENTRE + target.board_up.normalized() * (LOOK_HEIGHT - BODY_CENTRE)
	var goal_look: Vector3 = look_target(skater_pos, target.velocity)
	# Vert air: frame the rider and the coping below, not the horizon: the look point drops toward the ground under
	# the rider (the camera is already craning higher and farther), with the ramp's lip held in the lower frame.
	var look_down_goal: float = 0.0
	if vert and not target.is_on_floor():
		var below: Dictionary = _ray(skater_pos + Vector3.UP * 0.3, skater_pos + Vector3.DOWN * 30.0)
		var above_ground: float = (skater_pos.y - (below["position"] as Vector3).y) if not below.is_empty() else 0.0
		look_down_goal = clampf(above_ground * VERT_LOOK_DOWN, 0.0, VERT_LOOK_DOWN_MAX)
	_look_down = damp(_look_down, look_down_goal, 4.0, delta)
	goal_look += Vector3.DOWN * _look_down

	if not _primed:
		_primed = true
		_yaw = yaw_from_facing(target.facing)
		_vert_blend = 1.0 if vert else 0.0
		_look = goal_look
		_fov = fov_for_speed(target.speed)
		_push = 0.0
		_punch = 0.0
		_slope_lift = 0.0
		_perch_blend = 0.0
		_crane_h = 0.0
		_crane_blocked = false
		_yaw_vel = 0.0
		_arm_frac = 1.0
		_land_h = 0.0
		_land_v = 0.0
		_look_down = 0.0
		_air_vy = 0.0
		_cam_pos = _crane_goal(skater_pos, desired_offset(facing_from_yaw(_yaw), vert), eye, INF)
		_free_pos = _cam_pos

	if bailing:
		_yaw_vel = 0.0
		_yaw = wrapf(_yaw + ORBIT_RATE * delta, -PI, PI)
	elif not vert:
		# On foot the stick is camera-relative, so a fast follow would chase its own tail: swing slowly instead.
		var walking: bool = target.state.state == SkateState.State.WALK
		var rate: float = YAW_RATE * (WALK_YAW_FACTOR if walking else 1.0) * (SNAP_YAW_FACTOR if target.snapping() else 1.0)
		_yaw_vel = yaw_velocity_step(_yaw_vel, angle_difference(_yaw, yaw_from_facing(target.facing)), rate, delta)
		if target.snapping() or target.camera_hold > 0.0:
			# swinging round behind a skater who turned to face down a ramp: a steady swing, never a whip
			_yaw_vel = clampf(_yaw_vel, -SNAP_YAW_MAX, SNAP_YAW_MAX)
		_yaw = wrapf(_yaw + _yaw_vel * delta, -PI, PI)
	else:
		# hold the last ground yaw so the camera does not swing under the ramp (and let its swing die out)
		_yaw_vel = damp(_yaw_vel, 0.0, 10.0, delta)
		_yaw = wrapf(_yaw + _yaw_vel * delta, -PI, PI)

	_vert_blend = damp(_vert_blend, 1.0 if vert else 0.0, VERT_BLEND_RATE, delta)
	var fwd: Vector3 = facing_from_yaw(_yaw)
	var offset: Vector3 = desired_offset(fwd, false).lerp(desired_offset(fwd, true), _vert_blend)
	offset *= GameSettings.cam_distance_scale()
	_walk_blend = damp(_walk_blend, 1.0 if target.state.state == SkateState.State.WALK else 0.0, VERT_BLEND_RATE, delta)
	offset *= lerpf(1.0, WALK_ZOOM, _walk_blend)
	_push = damp(_push, speed_push(target.speed) if target.state.state != SkateState.State.WALK else 0.0, FOV_RATE, delta)
	offset += Vector3(offset.x, 0.0, offset.z).normalized() * PUSH_DISTANCE * _push
	# Rolling down a steep slope (a roll-in, a drop-in's wall, a bank): the surface behind rises, so the camera rises
	# with it instead of sitting inside it, looking down the slope the way the skater goes.
	var fy: float = target.facing.y if target.is_on_floor() and not grinding else 0.0
	var slope_lift: float = 0.0
	if fy < 0.0:
		slope_lift = DISTANCE * clampf(-fy / maxf(sqrt(maxf(1.0 - fy * fy, 0.0)), 0.3), 0.0, SLOPE_LIFT_MAX) * smoothstep(0.2, 0.4, -fy)
	_slope_lift = damp(_slope_lift, slope_lift, VERT_BLEND_RATE, delta)
	offset.y += _slope_lift
	if _orbit_yaw != 0.0 or _orbit_pitch != 0.0:
		var flat: Vector3 = Vector3(offset.x, 0.0, offset.z)
		var radius: float = flat.length()
		var ang: float = atan2(flat.x, flat.z) + _orbit_yaw
		var rise: float = offset.y + radius * tan(_orbit_pitch)
		offset = Vector3(sin(ang) * radius, rise, cos(ang) * radius)
	var holding: bool = target.camera_hold > 0.0
	# Crane over obstacles (instead of pulling in through them) around ramps, in the air and just after: it lingers
	# after the skater is back on the flat until the plain chase spot behind them is clear again.
	var crane_now: bool = holding or target.snapping() or target.vert_air or steep or not target.is_on_floor() \
		or target.board_up.y < 0.97
	if crane_now:
		_crane_left = CRANE_LINGER
	var crane: bool = _crane_left > 0.0
	if not crane:
		_crane_h = damp(_crane_h, 0.0, CRANE_RATE, delta)
	# The damped position trails the goal by speed / POS_RATE metres (1.9 m at 11.6 m/s: the rider read 5.4 m away, 18% of
	# the frame). The goal leads the skater to cancel most of that lag, keeping a little drag for the feel of speed.
	var lead: Vector3 = Vector3(target.velocity.x, 0.0, target.velocity.z).limit_length(LEAD_MAX_SPEED)
	lead *= POS_LEAD / POS_RATE * (1.0 - _vert_blend) * (1.0 - _walk_blend)
	var anchor: Vector3 = skater_pos + lead
	var goal_pos: Vector3 = _crane_goal(anchor, offset, eye, delta) if crane \
		else _constrain(anchor + offset + Vector3.UP * _crane_h, eye)
	if crane and not crane_now and not _crane_blocked:
		_crane_left = maxf(_crane_left - delta, 0.0)
	# A drop-in: rise to a perch over the coping and watch the skater go down the wall from there (a chase camera
	# low behind them would sit inside the ramp's deck); the chase takes over again down on the flat. Blended in
	# and out so neither the goal nor the look point switches in one tick.
	_perch_blend = damp(_perch_blend, 1.0 if holding else 0.0, PERCH_RATE, delta)
	var perched: bool = _perch_blend > 0.5
	if _perch_blend > 0.001:
		goal_pos = goal_pos.lerp(target.camera_anchor, _perch_blend)

	var before_arm: Vector3 = damp_vec(_free_pos, goal_pos, POS_RATE, delta)
	# The free position is damped and kept clear of the ground; the wall arm only shortens what is SHOWN (_shown_arm), in
	# steps, so a thin rail or lamp post grazing the sweep for one tick no longer pops the camera metres in and out.
	# On the way to a drop-in perch the arm is not swept: the perch is clear of the ramp, and a deck fence or rail
	# crossing the line for a moment would yank the camera in through the coping and back.
	if perched:
		_free_pos = _ground_clear(before_arm)
		_arm_frac = damp(_arm_frac, 1.0, ARM_GROW_RATE, delta)  # eases out of a shortened arm: no jump onto the perch
		_cam_pos = eye + (_free_pos - eye) * _arm_frac
	else:
		_free_pos = _lift_clear(before_arm, eye) if crane else _ground_clear(before_arm)
		_cam_pos = _shown_arm(_free_pos, eye, delta)
	dbg = {"goal": goal_pos, "damped": before_arm, "final": _cam_pos, "crane": crane, "crane_h": _crane_h, "blocked": _crane_blocked, "perched": perched, "yaw": _yaw, "yaw_vel": _yaw_vel, "look": _look}
	_look = damp_vec(_look, goal_look.lerp(skater_pos + Vector3.UP * 0.6, _perch_blend), LOOK_RATE, delta)
	_fov = damp(_fov, fov_for_speed(target.speed), FOV_RATE, delta)

	var hit: float = _punch * _punch
	global_position = _cam_pos + Vector3.DOWN * _land_h
	fov = _fov + GameSettings.cam_fov_offset() + PUNCH_FOV * hit
	if not _cam_pos.is_equal_approx(_look):
		look_at(_look, Vector3.UP)


## Landing weight: the dip and the FOV punch scale with how hard the skater came down (vertical speed): a small
## landing is nothing, a big air a short, lightly damped sink with one rebound. No shake with the setting off.
func _on_landed(result: String) -> void:
	var impact: float = -_air_vy
	_air_vy = 0.0
	if result == "bail" or target == null or target.camera_hold > 0.0:  # no landing dip on a drop-in's stomp
		return
	if not GameSettings.cam_shake_on():
		return
	var k: float = impact_strength(impact) * (1.0 if result == "clean" else 0.7)
	if k < 0.02:
		return
	_punch = k
	_land_v += LAND_DIP * k * LAND_SPRING


## Keeps the camera above the ground under it and out of walls between it and the look point.
func _constrain(p: Vector3, look: Vector3) -> Vector3:
	return _arm(look, _ground_clear(p))


## Keeps the camera MIN_GROUND_CLEARANCE above the ground under it.
func _ground_clear(p: Vector3) -> Vector3:
	var down: Dictionary = _ray(p + Vector3.UP * RAY_UP, p + Vector3.DOWN * RAY_DOWN)
	if down.is_empty():
		return p
	return ground_lift(p, (down["position"] as Vector3).y, MIN_GROUND_CLEARANCE)


## The camera position `p` shown: the arm swept from the eye, its length shortened in steps (arm_step).
func _shown_arm(p: Vector3, eye: Vector3, delta: float) -> Vector3:
	var full: float = p.distance_to(eye)
	if full < 0.01:
		return p
	var hit: Vector3 = _arm(eye, p)
	var wanted: float = clampf(hit.distance_to(eye) / full, 0.0, 1.0)
	_arm_frac = minf(arm_step(_arm_frac, wanted, full, delta), 1.0)
	return eye + (p - eye) * _arm_frac


## The goal for `offset` from the skater, craned up over whatever is between it and the skater (a ramp's deck, the
## ledge just rolled off) instead of pulled in through it: the arm is tried at CRANE_STEPS heights and the first that
## keeps most of its length is the crane height, which the goal follows at CRANE_RATE (a blocked/clear flicker as the
## skater moves would otherwise throw the goal metres up and down from one tick to the next). Moving the goal up over
## an edge is smooth; pulling the camera in through it is a jump.
func _crane_goal(skater_pos: Vector3, offset: Vector3, eye: Vector3, delta: float) -> Vector3:
	var plain: Vector3 = _constrain(skater_pos + offset, eye)
	var want: float = (skater_pos + offset).distance_to(eye)
	var keep: float = CRANE_KEEP + (CRANE_UNBLOCK if _crane_blocked else 0.0)
	_crane_blocked = plain.distance_to(eye) < want * keep
	var h_goal: float = 0.0
	if _crane_blocked:
		for h: float in CRANE_STEPS:
			var p: Vector3 = _constrain(skater_pos + offset + Vector3.UP * h, eye)
			if p.distance_to(eye) >= (skater_pos + offset + Vector3.UP * h).distance_to(eye) * CRANE_KEEP:
				h_goal = h
				break
	_crane_h = damp(_crane_h, h_goal, CRANE_RATE, delta) if is_finite(delta) else h_goal
	if _crane_h < 0.01:
		return plain
	return _constrain(skater_pos + offset + Vector3.UP * _crane_h, eye)


## The free camera position `p` when an edge comes between it and the skater around a ramp or a drop (below a
## coping, off a ledge): raised a little (at most LIFT_MAX a tick) rather than pulled in through the edge, which is a
## jump. A camera that would sit inside something stays put and the shown arm shortens instead (see _shown_arm).
func _lift_clear(p: Vector3, eye: Vector3) -> Vector3:
	var base: Vector3 = _ground_clear(p)
	if _arm(eye, base).distance_to(base) < 0.01:
		return base
	var h: float = LIFT_STEP
	while h <= LIFT_MAX + 0.001:
		var q: Vector3 = _ground_clear(base + Vector3.UP * h)
		if _arm(eye, q).distance_to(q) < 0.01:
			return q
		h += LIFT_STEP
	var up: Vector3 = _ground_clear(base + Vector3.UP * LIFT_MAX)
	return up if not _inside(up) else base


## True when the camera's sphere at `p` overlaps the world.
func _inside(p: Vector3) -> bool:
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = ARM_RADIUS * 0.5
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, p)
	q.collision_mask = WORLD_MASK
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


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
