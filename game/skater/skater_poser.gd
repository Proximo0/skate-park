class_name SkaterPoser
extends Node
## Procedural pose for the placeholder skater (PlaceholderSkater.build_body / build_board). Each frame it reads the
## Skater's anim state, asks pose_for() for a target, and blends the joints, body root and board toward it.
## Joint values are degrees added to each joint's rest rotation, so the solved leg and arm rest angles stay intact.
## Pose values: joint name -> Vector3 degrees (rotation offset); "hips_y" metres (Hips joint offset from
## HIP_HEIGHT); "lift" metres (body root offset from DECK_TOP_Y); "lean" degrees (body roll about its own Z);
## "pitch" degrees (forward lean, positive = leaning toward the nose); "body_yaw" degrees (extra yaw about Y);
## "board_rot" Vector3 degrees; "board_pos" metres. pose_for() is pure and unit tested.

const BLEND_RATE: float = 12.0  ## per second, exponential so the result does not depend on frame rate

const JOINTS: PackedStringArray = [
	"Hips", "Spine", "Chest", "Neck", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
]

const FLIP_TIME: float = 0.42
const DOUBLE_FLIP_TIME: float = 0.68
const PUSH_CYCLE: float = 0.6
const LAND_TIME: float = 0.2
const REVERT_TIME: float = 0.3
const SPECIAL_SPIN_TIME: float = 2.0
const FALL_TIME: float = 0.5
const LEAN_MAX: float = 25.0
const MANUAL_PITCH: float = 12.0
const LIP_PITCH: float = 70.0
const IDLE_UPPER: float = 6.0  ## leg offsets for a relaxed, slightly bent stance
const IDLE_LOWER: float = -10.0
const CROUCH_UPPER: float = 40.0  ## extra thigh and shin offsets at crouch = 1
const CROUCH_LOWER: float = -60.0
const DECK_CENTER: Vector3 = Vector3(0.0, 0.12, 0.0)
const REAR_TRUCK: Vector3 = Vector3(0.0, 0.0, 0.28)
const FRONT_TRUCK: Vector3 = Vector3(0.0, 0.0, -0.28)

## The Skater. Typed Object and read with get(): naming the Skater class would make this script (and its unit test)
## depend on skater.gd compiling, which needs the Flags autoload. Fields read: anim, anim_time, crouch, balance.
var skater: Object
var body: Node3D
var board: Node3D

var _nodes: Dictionary = {}  ## joint name -> Node3D
var _rest: Dictionary = {}  ## joint name -> Vector3 rest rotation (radians)
var _body_basis: Basis = Basis.IDENTITY
var _current: Dictionary = {}
var _has_pose: bool = false


func _process(delta: float) -> void:
	if skater == null or body == null or board == null:
		return
	if _nodes.is_empty():
		_capture_rest()
	var balance: Balance = skater.get("balance")
	var target: Dictionary = pose_for(str(skater.get("anim")), float(skater.get("anim_time")),
			float(skater.get("crouch")), balance.angle)
	if not _has_pose:
		_current = target
		_has_pose = true
	else:
		_current = _blend(_current, target, 1.0 - exp(-BLEND_RATE * delta))
	_apply(_current)


func _capture_rest() -> void:
	for j: String in JOINTS:
		var node: Node3D = body.find_child(j, true, false)
		_nodes[j] = node
		_rest[j] = node.rotation
	_body_basis = body.transform.basis


func _apply(pose: Dictionary) -> void:
	for j: String in JOINTS:
		var node: Node3D = _nodes[j]
		if j == "Hips":
			node.position = Vector3(0.0, PlaceholderSkater.HIP_HEIGHT + float(pose["hips_y"]), 0.0)
		node.rotation = (_rest[j] as Vector3) + (pose[j] as Vector3) * (PI / 180.0)
	var b: Basis = _body_basis * Basis(Vector3.UP, deg_to_rad(float(pose["body_yaw"]))) \
			* Basis(Vector3.BACK, deg_to_rad(float(pose["lean"]))) \
			* Basis(Vector3.RIGHT, deg_to_rad(-float(pose["pitch"])))
	body.transform = Transform3D(b, Vector3(0.0, PlaceholderSkater.DECK_TOP_Y + float(pose["lift"]), 0.0))
	var rot: Vector3 = pose["board_rot"]
	board.transform = Transform3D(Basis.from_euler(rot * (PI / 180.0)), pose["board_pos"])


static func _blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out: Dictionary = {}
	for key: String in b.keys():
		var va: Variant = a[key]
		var vb: Variant = b[key]
		if vb is Vector3:
			if key == "board_rot":
				out[key] = _blend_angles(va as Vector3, vb as Vector3, k)
			else:
				out[key] = (va as Vector3).lerp(vb as Vector3, k)
		else:
			out[key] = lerpf(float(va), float(vb), k)
	return out


## Per-axis degrees, taking the short way round so a board turning past 360 does not reverse.
static func _blend_angles(a: Vector3, b: Vector3, k: float) -> Vector3:
	var d: Vector3 = b - a
	d = Vector3(fposmod(d.x + 180.0, 360.0) - 180.0, fposmod(d.y + 180.0, 360.0) - 180.0,
			fposmod(d.z + 180.0, 360.0) - 180.0)
	return a + d * k


## Target pose for an anim at anim_time t. crouch 0..1 deepens the knees; balance is the Balance angle -1..1.
static func pose_for(anim: String, t: float, crouch: float, balance: float) -> Dictionary:
	var pose: Dictionary = _blank()
	var c: float = clampf(crouch, 0.0, 1.0)
	var b: float = clampf(balance, -1.0, 1.0)
	var grounded: bool = true
	if anim.begins_with("flip_"):
		grounded = false
		_pose_tuck(pose)
		_arms(pose, Vector3(0.0, 0.0, -40.0), Vector3(0.0, 0.0, 40.0), 30.0)
		pose["hips_y"] = 0.04
		_board_turn(pose, _board_spin(anim, t), DECK_CENTER)
	elif anim.begins_with("grab_"):
		grounded = false
		_pose_tuck(pose)
		_grab(pose, anim)
		pose["hips_y"] = 0.05
	elif anim.begins_with("grind_"):
		_pose_grind(pose, anim, t, maxf(c, 0.6), b)
	elif anim.begins_with("manual_"):
		_pose_manual(pose, anim, t, maxf(c, 0.15), b)
	elif anim.begins_with("lip_"):
		_pose_lip(pose, t, maxf(c, 0.4), b)
	elif anim.begins_with("special_"):
		grounded = false
		_pose_special(pose, t)
	else:
		match anim:
			"push":
				_pose_push(pose, t, c)
			"crouch":
				_set_legs(pose, IDLE_UPPER + CROUCH_UPPER * c, IDLE_LOWER + CROUCH_LOWER * c)
				pose["pitch"] = 10.0 * c
			"ollie":
				grounded = false
				_pose_ollie(pose, t)
			"air":
				grounded = false
				_pose_tuck(pose, 50.0, -80.0)
				_arms(pose, Vector3(0.0, 0.0, -35.0), Vector3(0.0, 0.0, 35.0), 25.0)
			"land":
				var bump: float = sin(PI * clampf(t / LAND_TIME, 0.0, 1.0))
				_set_legs(pose, IDLE_UPPER + 40.0 * bump, IDLE_LOWER - 55.0 * bump)
				_arms(pose, Vector3(40.0 * bump, 0.0, -30.0 * bump - 5.0), Vector3(40.0 * bump, 0.0, 30.0 * bump + 5.0), 20.0)
				pose["pitch"] = 8.0 * bump
			"revert":
				_pose_revert(pose, t)
			"bail_fall":
				grounded = false
				_pose_bail_fall(pose, t)
			"bail_getup":
				_pose_getup(pose, t)
			"wallride":
				_set_legs(pose, IDLE_UPPER + CROUCH_UPPER * 0.2, IDLE_LOWER + CROUCH_LOWER * 0.2)
				_arms(pose, Vector3(0.0, 0.0, -50.0), Vector3(0.0, 0.0, 50.0), 20.0)
				pose["lean"] = 30.0
			_:
				_pose_idle(pose, c)
	if grounded:
		_settle(pose)
	return pose


static func _blank() -> Dictionary:
	var pose: Dictionary = {}
	for j: String in JOINTS:
		pose[j] = Vector3.ZERO
	pose["hips_y"] = 0.0
	pose["lift"] = 0.0
	pose["lean"] = 0.0
	pose["pitch"] = 0.0
	pose["body_yaw"] = 0.0
	pose["board_rot"] = Vector3.ZERO
	pose["board_pos"] = Vector3.ZERO
	return pose


static func _set_legs(pose: Dictionary, upper: float, lower: float) -> void:
	_set_leg(pose, "Left", upper, lower)
	_set_leg(pose, "Right", upper, lower)


## Thigh and shin offsets in degrees. The foot counter-rotates so the shoe stays level.
static func _set_leg(pose: Dictionary, side: String, upper: float, lower: float) -> void:
	pose[side + "UpperLeg"] = Vector3(upper, 0.0, 0.0)
	pose[side + "LowerLeg"] = Vector3(lower, 0.0, 0.0)
	pose[side + "Foot"] = Vector3(-(upper + lower), 0.0, 0.0)


static func _arms(pose: Dictionary, left: Vector3, right: Vector3, elbow: float) -> void:
	pose["LeftUpperArm"] = left
	pose["RightUpperArm"] = right
	pose["LeftLowerArm"] = Vector3(elbow, 0.0, 0.0)
	pose["RightLowerArm"] = Vector3(elbow, 0.0, 0.0)


## Knees tucked up toward the chest.
static func _pose_tuck(pose: Dictionary, upper: float = 55.0, lower: float = -85.0) -> void:
	_set_legs(pose, upper, lower)


static func _pose_idle(pose: Dictionary, c: float) -> void:
	_set_legs(pose, IDLE_UPPER + CROUCH_UPPER * c, IDLE_LOWER + CROUCH_LOWER * c)
	_arms(pose, Vector3(6.0, 0.0, -5.0), Vector3(6.0, 0.0, 5.0), 10.0)
	pose["pitch"] = 10.0 * c


static func _pose_push(pose: Dictionary, t: float, c: float) -> void:
	var p: float = fposmod(t, PUSH_CYCLE) / PUSH_CYCLE
	var s: float = 0.5 - 0.5 * cos(TAU * p)  ## 0 at cycle start, 1 mid-kick
	# Front (left) leg stays bent and absorbs; back (right) leg swings down and back, then straightens.
	_set_leg(pose, "Left", IDLE_UPPER + 6.0 + CROUCH_UPPER * c, IDLE_LOWER - 6.0 + CROUCH_LOWER * c)
	_set_leg(pose, "Right", IDLE_UPPER - 40.0 * s + CROUCH_UPPER * c, IDLE_LOWER + 22.0 * s + CROUCH_LOWER * c)
	var swing: float = 2.0 * s - 1.0
	_arms(pose, Vector3(swing * 30.0, 0.0, -15.0), Vector3(-swing * 30.0, 0.0, 15.0), 15.0)
	pose["pitch"] = 6.0 + 10.0 * c


static func _pose_ollie(pose: Dictionary, t: float) -> void:
	var k: float = clampf(t / 0.12, 0.0, 1.0)  ## pop: legs and arms go up in the first 0.12 s
	_set_legs(pose, 55.0 * k, -85.0 * k)
	_arms(pose, Vector3(0.0, 0.0, -150.0 * k), Vector3(0.0, 0.0, 150.0 * k), 20.0 * k)
	pose["hips_y"] = 0.05 * k


static func _pose_revert(pose: Dictionary, t: float) -> void:
	var p: float = clampf(t / REVERT_TIME, 0.0, 1.0)
	p = p * p * (3.0 - 2.0 * p)  ## ease in and out
	var yaw: float = 180.0 * p
	_pose_idle(pose, 0.0)
	pose["body_yaw"] = yaw
	_board_turn(pose, Vector3(0.0, yaw, 0.0), Vector3.ZERO)


static func _pose_bail_fall(pose: Dictionary, t: float) -> void:
	var p: float = clampf(t / FALL_TIME, 0.0, 1.0)
	p = p * p
	_set_leg(pose, "Left", 25.0, -30.0)
	_set_leg(pose, "Right", -15.0, 10.0)
	_arms(pose, Vector3(70.0 * sin(t * 12.0), 0.0, -60.0), Vector3(70.0 * sin(t * 12.0 + PI), 0.0, 60.0), 40.0)
	pose["lean"] = 80.0 * p
	pose["hips_y"] = -0.25 * p


static func _pose_getup(pose: Dictionary, t: float) -> void:
	var d: float = SkateState.BAIL_TIME * 0.4  ## the rest of the bail after the fall
	var p: float = clampf(t / d, 0.0, 1.0)
	var rest: float = 1.0 - p
	_pose_idle(pose, 0.8 * rest)
	_arms(pose, Vector3(40.0 * rest * sin(t * 12.0), 0.0, -40.0 * rest - 5.0),
			Vector3(40.0 * rest * sin(t * 12.0 + PI), 0.0, 40.0 * rest + 5.0), 30.0)
	pose["lean"] = 80.0 * rest
	pose["hips_y"] = -0.25 * rest


static func _pose_grind(pose: Dictionary, anim: String, t: float, c: float, b: float) -> void:
	_set_legs(pose, IDLE_UPPER + CROUCH_UPPER * c, IDLE_LOWER + CROUCH_LOWER * c)
	pose["lean"] = LEAN_MAX * b
	var flail: float = 35.0 * absf(b) * sin(t * 10.0)
	_arms(pose, Vector3(flail, 0.0, -35.0), Vector3(-flail, 0.0, 35.0), 20.0)
	if anim == "grind_boardslide" or anim == "grind_lipslide" or anim == "grind_blunt_slide":
		# Board across the rail, body square to the travel direction.
		pose["body_yaw"] = -90.0
		_board_turn(pose, Vector3(0.0, 90.0, 0.0), Vector3.ZERO)


static func _pose_manual(pose: Dictionary, anim: String, t: float, c: float, b: float) -> void:
	_set_legs(pose, IDLE_UPPER + CROUCH_UPPER * c, IDLE_LOWER + CROUCH_LOWER * c)
	var nose_down: bool = anim == "manual_nose_manual"
	var sign: float = -1.0 if nose_down else 1.0
	var flail: float = 25.0 * sin(t * 8.0) * b
	_arms(pose, Vector3(flail, 0.0, -45.0), Vector3(-flail, 0.0, 45.0), 15.0)
	pose["pitch"] = 10.0 * sign  ## leans back on a manual, forward on a nose manual
	var pivot: Vector3 = FRONT_TRUCK if nose_down else REAR_TRUCK
	_board_turn(pose, Vector3(sign * MANUAL_PITCH + 8.0 * b, 0.0, 0.0), pivot)


static func _pose_lip(pose: Dictionary, t: float, c: float, b: float) -> void:
	_set_legs(pose, IDLE_UPPER + CROUCH_UPPER * c, IDLE_LOWER + CROUCH_LOWER * c)
	var flail: float = 20.0 * sin(t * 8.0) * absf(b)
	_arms(pose, Vector3(flail, 0.0, -60.0), Vector3(-flail, 0.0, 60.0), 30.0)
	_board_turn(pose, Vector3(LIP_PITCH + 8.0 * b, 0.0, 0.0), REAR_TRUCK)


static func _pose_special(pose: Dictionary, t: float) -> void:
	var spin: float = fposmod(720.0 * clampf(t / SPECIAL_SPIN_TIME, 0.0, 1.0), 360.0)  ## two slow turns, ends at identity
	_set_leg(pose, "Left", 30.0, -40.0)
	_set_leg(pose, "Right", -45.0, 25.0)  ## one leg kicked out behind
	_arms(pose, Vector3(0.0, 0.0, -150.0), Vector3(0.0, 0.0, 150.0), 20.0)
	pose["lean"] = 12.0 * sin(t * 6.0)
	pose["hips_y"] = 0.06
	_board_turn(pose, Vector3(0.0, spin, 0.0), DECK_CENTER)


static func _grab(pose: Dictionary, anim: String) -> void:
	# The rider tucks the board up to the hands. Shoulders sit about 0.19 m either side of the body along the
	# board, so the rest outward tilt (20 deg) already puts a straight arm over the nose or tail end. A nose or
	# tail grab keeps that angle and straightens the arm; a side grab swings the near arm a little forward
	# (melon, method, airwalk) or back (indy, stalefish, mute, benihana) to hang over the deck edge.
	pose["board_pos"] = Vector3(0.0, 0.22, 0.0)
	var reach: String = "Right"
	var reach_upper: Vector3 = Vector3(20.0, 0.0, 0.0)  ## side grab: hang forward over the edge
	var other_upper: Vector3 = Vector3(0.0, 0.0, -30.0)
	var elbow: float = -20.0  ## straightens the reaching arm (rest forearm bend is about 29 deg)
	if anim.contains("nosegrab"):
		reach_upper = Vector3.ZERO
		elbow = -25.0
	elif anim.contains("tailgrab"):
		reach = "Left"
		reach_upper = Vector3.ZERO
		elbow = -25.0
	elif anim.contains("indy") or anim.contains("stalefish") or anim.contains("mute") or anim.contains("benihana"):
		reach = "Left"
		reach_upper = Vector3(-20.0, 0.0, 0.0)  ## back hand swings back over the edge
	var other: String = "Left" if reach == "Right" else "Right"
	pose[reach + "UpperArm"] = reach_upper
	pose[reach + "LowerArm"] = Vector3(elbow, 0.0, 0.0)
	pose[other + "UpperArm"] = other_upper if other == "Left" else Vector3(0.0, 0.0, 30.0)


## Board rotation (degrees) for a flip_* anim at time t. Zero before the spin and again once it completes.
static func _board_spin(anim: String, t: float) -> Vector3:
	var dbl: bool = anim.contains("double")
	var dur: float = DOUBLE_FLIP_TIME if dbl else FLIP_TIME
	var turns: float = 2.0 if dbl else 1.0
	var p: float = clampf(t / dur, 0.0, 1.0)
	var deg: float = fposmod(360.0 * turns * p, 360.0)
	var axis: Vector3 = Vector3(0.0, 0.0, 1.0)  ## kickflip, heelflip, hardflip, frontside: roll about the long axis
	if anim.contains("impossible"):
		axis = Vector3.RIGHT
	elif anim.contains("shove") or anim.contains("varial") or anim.contains("laser"):
		axis = Vector3.UP
	return axis * deg


static func _board_turn(pose: Dictionary, euler_deg: Vector3, pivot: Vector3) -> void:
	var r: Basis = Basis.from_euler(euler_deg * (PI / 180.0))
	pose["board_rot"] = euler_deg
	pose["board_pos"] = pivot - r * pivot  ## keeps the pivot point fixed in place


## Sets hips height so both soles sit on the deck given the leg offsets, and lifts the body with the deck.
static func _settle(pose: Dictionary) -> void:
	var rest_l: Vector2 = PlaceholderSkater._leg_pose(-PlaceholderSkater.FOOT_Z)
	var rest_r: Vector2 = PlaceholderSkater._leg_pose(PlaceholderSkater.FOOT_Z)
	var hips: float = 0.5 * (_leg_height(rest_l, pose, "Left") + _leg_height(rest_r, pose, "Right"))
	pose["hips_y"] = hips - PlaceholderSkater.HIP_HEIGHT
	var rot: Vector3 = pose["board_rot"]
	var r: Basis = Basis.from_euler(rot * (PI / 180.0))
	var deck_top: Vector3 = (pose["board_pos"] as Vector3) + r * Vector3(0.0, PlaceholderSkater.DECK_TOP_Y, 0.0)
	pose["lift"] = deck_top.y - PlaceholderSkater.DECK_TOP_Y


## Hip-to-sole height for one leg: upper and lower leg vertical reach plus the ankle height.
static func _leg_height(rest: Vector2, pose: Dictionary, side: String) -> float:
	var up: Vector3 = pose[side + "UpperLeg"]
	var lo: Vector3 = pose[side + "LowerLeg"]
	var alpha: float = rest.x + deg_to_rad(up.x)
	var beta: float = rest.y + deg_to_rad(up.x + lo.x)
	return PlaceholderSkater.UPPER_LEG * cos(alpha) + PlaceholderSkater.LOWER_LEG * cos(beta) \
			+ PlaceholderSkater.ANKLE_HEIGHT
