class_name SkaterPoser
extends Node
## Procedural animation for the placeholder skater (PlaceholderSkater.build_body / build_board). Each frame it reads
## the Skater's anim state, asks pose_for() for a target pose, blends toward it, and applies it: the board and body
## root are placed directly, the spine, head and arms use joint offsets (FK), and the legs are solved with two-bone
## IK so the shoes land exactly on their targets (on the deck, or on the ground while pushing). A grab also solves
## one arm with IK so the hand really holds the board.
##
## Spaces. "Visual" space is the parent of the body and board: -Z is the travel direction, +Y is board up, the
## ground under the wheels is y = 0. The "stance" frame is visual space turned by feet_yaw about Y: its -Z points at
## the rider's front foot, +X at the toe side. Regular stance, feet_yaw 0: front (left) foot toward the nose, the
## kid faces +X. Switch adds 180.
##
## Pose keys: joint name -> Vector3 degrees added to the joint's rest rotation (legs are IK, their entries are
## unused); "hips_y" metres (Hips offset from HIP_HEIGHT); "lift" metres (body root above the deck top);
## "lean" degrees (body roll about the travel axis, + tips toward +X); "pitch" degrees (+ tips toward the nose);
## "body_yaw" degrees (torso turn about Y, 0 = facing +X); "feet_yaw" degrees (stance frame turn);
## "board_rot" Vector3 degrees (YXZ Euler); "board_pos" metres; "foot_L"/"foot_R" ankle targets in visual space;
## "toe_L"/"toe_R" shoe yaw in degrees relative to the stance frame (0 = toes to the toe side, + turns toward the
## front); "feet_on_board" 0..1 (1 = shoes lie flat on the deck, 0 = level); "feet_free" 0..1 (1 = feet hang
## from the hips instead of their targets, for bails); "hand_L"/"hand_R" hand targets in visual space with
## "grip_L"/"grip_R" 0..1 IK weights. pose_for() is pure and unit tested.

const BLEND_RATE: float = 12.0  ## per second, exponential so the result does not depend on frame rate
const BLEND_RATE_FAST: float = 40.0  ## flips and the pop follow almost exactly, a lagging board looks late

const JOINTS: PackedStringArray = [
	"Hips", "Spine", "Chest", "Neck", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
]

const FLIP_TIME: float = 0.42
const DOUBLE_FLIP_TIME: float = 0.68
const CATCH: float = 0.8  ## fraction of a flip where the feet come back down onto the board
const PUSH_CYCLE: float = 0.6
const PUSH_PLANT: float = 0.18  ## first push only: seconds to step off the tail to the plant point
const PUSH_CONTACT: float = 0.55  ## fraction of a push cycle with the foot on the ground

## Live push timing. Start at the consts above; a poser whose skater has a `tune` copies its push_* fields in
## each frame so the pose stays in step with the push kicks.
static var _push_plant: float = PUSH_PLANT
static var _push_cycle: float = PUSH_CYCLE
static var _push_contact: float = PUSH_CONTACT
const POP_TIME: float = 0.08  ## tail snap
const LEVEL_TIME: float = 0.22  ## board levels out and rises to the feet
const LAND_TIME: float = 0.2
const REVERT_TIME: float = 0.3
const SPECIAL_SPIN_TIME: float = 2.0
const FALL_TIME: float = 0.5
const LEAN_MAX: float = 25.0
const MANUAL_PITCH: float = 12.0
const LIP_PITCH: float = 70.0

## Stance geometry, stance frame. Feet sit over the bolts; the back foot is a little further out, near the tail.
const FRONT_FOOT: Vector3 = Vector3(0.0, 0.0, -0.18)
const BACK_FOOT: Vector3 = Vector3(0.0, 0.0, 0.21)
const FRONT_TOE: float = 18.0  ## front shoe angled toward the nose
const BACK_TOE: float = -4.0
const IDLE_HIPS: float = -0.085  ## relaxed knees
const CROUCH_DROP: float = 0.24  ## extra hip drop at crouch = 1
const HEAD_LOOK: float = 68.0  ## head turned to look down the board at the travel direction
const DECK_CENTER: Vector3 = Vector3(0.0, 0.12, 0.0)
const REAR_TRUCK: Vector3 = Vector3(0.0, 0.0, AnimeBoard.TRUCK_Z)
const FRONT_TRUCK: Vector3 = Vector3(0.0, 0.0, -AnimeBoard.TRUCK_Z)
const WHEEL_CONTACT_Z: float = AnimeBoard.TRUCK_Z + 0.03  ## manual pivot: where the wheels touch the ground
const TAIL_TIP: Vector3 = Vector3(0.0, 0.0, 0.40)
const GRAB_RISE: float = 0.72  ## board comes up to the knees
const GRAB_LIFT: float = 0.24  ## the body rises less, so the knees tuck
const GRAB_CURL: float = 50.0
const GRAB_ROLL: float = 22.0  ## grabbed edge tipped up toward the hand
const EDGE: float = 0.12  ## deck half width plus a little, where a hand wraps the edge

## Walking (anims "walk", "walk_jump", "dismount", "mount"). The body faces visual -Z with its feet on the ground, the
## board is carried on edge under the right arm (wheels out, grip against the hip) and that hand holds the deck's top edge.
const STEP_OFF_TIME: float = 0.25  ## "dismount": ride pose to carry pose
const HOP_ON_TIME: float = 0.3  ## "mount": board drops in front, the rider steps onto it
const WALK_LEG: float = 0.71  ## working leg length for the stride maths (the bones allow 0.73)
const CARRY_ROLL: float = 90.0  ## deck on edge: grip side toward the body
const CARRY_PITCH: float = 12.0  ## nose up
const CARRY_CENTER: Vector3 = Vector3(0.3, 0.72, -0.02)  ## where the deck's middle hangs, visual space

## The Skater. Typed Object and read with get(): naming the Skater class would make this script (and its unit test)
## depend on skater.gd compiling, which needs the Flags autoload. Fields read: anim, anim_time, crouch, balance,
## switch_stance. Without a skater (title screen) the poser holds `preview_anim`.
var skater: Object
var body: Node3D
var board: Node3D
var preview_anim: String = "idle_ride"

var _nodes: Dictionary = {}  ## joint name -> Node3D
var _rest: Dictionary = {}  ## joint name -> Vector3 rest rotation (radians)
var _current: Dictionary = {}
var _has_pose: bool = false
var _preview_t: float = 0.0


func _process(delta: float) -> void:
	if body == null or board == null:
		return
	if _nodes.is_empty():
		_capture_rest()
	if skater != null and bool(skater.get("ragdoll_active")):
		return  # a bail ragdoll is driving the joints and the board
	var anim: String = preview_anim
	var t: float = 0.0
	var crouch: float = 0.0
	var bal: float = 0.0
	var switch: bool = false
	var speed: float = 0.0
	var phase: float = 0.0
	if skater != null:
		anim = str(skater.get("anim"))
		t = float(skater.get("anim_time"))
		crouch = float(skater.get("crouch"))
		var balance: Object = skater.get("balance")
		bal = float(balance.get("angle")) if balance != null else 0.0
		switch = bool(skater.get("switch_stance"))
		var wk: Object = skater.get("walker") as Object
		if wk != null:
			speed = float(wk.get("h_speed"))
			phase = float(wk.get("phase"))
		var tn: Object = skater.get("tune") as Object
		if tn != null:
			_push_plant = float(tn.get("push_plant"))
			_push_cycle = float(tn.get("push_cycle"))
			_push_contact = float(tn.get("push_contact"))
	else:
		_preview_t += delta
		t = _preview_t
	var target: Dictionary = pose_for(anim, t, crouch, bal, switch, speed, phase)
	if not _has_pose:
		_current = target
		_has_pose = true
	else:
		for key: String in ["body_yaw", "feet_yaw"]:
			# Unwrap so the blend takes the short way round instead of spinning a full turn.
			var cur: float = float(_current[key])
			target[key] = cur + wrapf(float(target[key]) - cur, -180.0, 180.0)
		# The board is symmetric end to end: a half turn of yaw (end of a shove-it or revert) snaps, not spins back.
		var cb: Vector3 = _current["board_rot"]
		var tb: Vector3 = target["board_rot"]
		if absf(wrapf(tb.y - cb.y, -180.0, 180.0)) > 120.0:
			_current["board_rot"] = Vector3(cb.x, tb.y, cb.z)
		var rate: float = BLEND_RATE_FAST if (anim.begins_with("flip_") or anim == "ollie" or anim.begins_with("walk")
				or anim == "dismount") else BLEND_RATE
		_current = _blend(_current, target, 1.0 - exp(-rate * delta))
	_apply(_current)


## Extra body yaw for the stance: switch faces the body the other way round on the board. The revert pose spins 0
## to 180 from the old stance, which switch_stance has already left, hence the -180.
static func stance_yaw(anim_name: String, switch: bool) -> float:
	var yaw: float = 180.0 if switch else 0.0
	if anim_name == "revert":
		yaw -= 180.0
	return yaw


func _capture_rest() -> void:
	for j: String in JOINTS:
		var node: Node3D = body.find_child(j, true, false)
		_nodes[j] = node
		_rest[j] = node.rotation


func _apply(pose: Dictionary) -> void:
	var rot: Vector3 = pose["board_rot"]
	var board_basis: Basis = Basis.from_euler(rot * (PI / 180.0))
	board.transform = Transform3D(board_basis, pose["board_pos"])

	var b: Basis = Basis(Vector3.RIGHT, deg_to_rad(-float(pose["pitch"]))) \
			* Basis(Vector3.BACK, deg_to_rad(-float(pose["lean"]))) \
			* Basis(Vector3.UP, deg_to_rad(float(pose["body_yaw"]) - 90.0))
	body.transform = Transform3D(b, Vector3(0.0, PlaceholderSkater.DECK_TOP_Y + float(pose["lift"]), 0.0))
	for j: String in JOINTS:
		var node: Node3D = _nodes[j]
		if j == "Hips":
			node.position = Vector3(0.0, PlaceholderSkater.HIP_HEIGHT + float(pose["hips_y"]), 0.0)
		node.rotation = (_rest[j] as Vector3) + (pose[j] as Vector3) * (PI / 180.0)

	var parent: Node3D = body.get_parent() as Node3D
	var space: Transform3D = parent.global_transform if parent != null else Transform3D.IDENTITY
	var space_q: Quaternion = space.basis.get_rotation_quaternion()
	var board_q: Quaternion = space_q * board_basis.get_rotation_quaternion()
	var facing: Vector3 = body.global_basis * Vector3.FORWARD  ## the body's own -Z
	var hips: Node3D = _nodes["Hips"]
	var free: float = float(pose["feet_free"])
	var flat: float = float(pose["feet_on_board"]) * (1.0 - free)
	var feet_yaw: float = deg_to_rad(float(pose["feet_yaw"]))
	for side: String in ["Left", "Right"]:
		var s: String = side.left(1)
		var hip: Node3D = _nodes[side + "UpperLeg"]
		var out: Vector3 = (hip.global_position - hips.global_position).normalized()
		var target: Vector3 = space * (pose["foot_" + s] as Vector3)
		if free > 0.0:
			var hang: Vector3 = body.global_transform * Vector3((-1.0 if side == "Left" else 1.0) * 0.13,
					PlaceholderSkater.HIP_HEIGHT + float(pose["hips_y"]) - 0.88 * (PlaceholderSkater.UPPER_LEG + PlaceholderSkater.LOWER_LEG), -0.08)
			target = target.lerp(hang, free)
		var toe: float = feet_yaw + deg_to_rad(float(pose["toe_" + s]) - 90.0)
		var foot_basis: Basis = Basis(space_q.slerp(board_q, flat)) * Basis(Vector3.UP, toe)
		_solve_leg(side, target, facing + out * 0.35, foot_basis)
	for side: String in ["Left", "Right"]:
		var s: String = side.left(1)
		var w: float = float(pose["grip_" + s])
		if w > 0.01:
			_solve_arm(side, space * (pose["hand_" + s] as Vector3), w, facing)


## Two-bone IK for a leg: thigh and shin point at the knee and ankle, the knee bends toward `pole`.
func _solve_leg(side: String, target: Vector3, pole: Vector3, foot_basis: Basis) -> void:
	var upper: Node3D = _nodes[side + "UpperLeg"]
	var lower: Node3D = _nodes[side + "LowerLeg"]
	var foot: Node3D = _nodes[side + "Foot"]
	var joints: Array[Vector3] = two_bone(upper.global_position, target, pole,
			PlaceholderSkater.UPPER_LEG, PlaceholderSkater.LOWER_LEG)
	upper.global_basis = bone_basis(joints[1] - joints[0], pole)
	lower.global_basis = bone_basis(joints[2] - joints[1], pole)
	foot.global_basis = foot_basis


## Arm IK blended with the FK pose by w. The elbow bends out and back.
func _solve_arm(side: String, target: Vector3, w: float, facing: Vector3) -> void:
	var upper: Node3D = _nodes[side + "UpperArm"]
	var lower: Node3D = _nodes[side + "LowerArm"]
	var fk_upper: Quaternion = upper.global_basis.get_rotation_quaternion()
	var fk_lower: Quaternion = lower.global_basis.get_rotation_quaternion()
	var shoulder: Vector3 = upper.global_position
	var out: Vector3 = (shoulder - (_nodes["Chest"] as Node3D).global_position).normalized()
	var pole: Vector3 = (out - facing * 0.5).normalized()
	var joints: Array[Vector3] = two_bone(shoulder, target, pole, PlaceholderSkater.UPPER_ARM, PlaceholderSkater.LOWER_ARM)
	var ik_upper: Quaternion = bone_basis(joints[1] - joints[0], pole).get_rotation_quaternion()
	var ik_lower: Quaternion = bone_basis(joints[2] - joints[1], pole).get_rotation_quaternion()
	upper.global_basis = Basis(fk_upper.slerp(ik_upper, w))
	lower.global_basis = Basis(fk_lower.slerp(ik_lower, w))


## Two-bone solve: returns [root, middle joint, end] with the end as close to target as the bones allow and the
## middle joint bent toward pole.
static func two_bone(root: Vector3, target: Vector3, pole: Vector3, l1: float, l2: float) -> Array[Vector3]:
	var to: Vector3 = target - root
	var dir: Vector3 = to.normalized() if to.length() > 0.00001 else Vector3.DOWN
	var d: float = clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.0005)
	var p: Vector3 = pole - dir * pole.dot(dir)
	if p.length() < 0.0001:
		p = dir.cross(Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.UP)
	p = p.normalized()
	var a: float = acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var mid: Vector3 = root + (dir * cos(a) + p * sin(a)) * l1
	return [root, mid, root + dir * d]


## Basis for a bone that hangs along its local -Y (as the rig's limbs do) with its local -Z toward fwd.
static func bone_basis(bone: Vector3, fwd: Vector3) -> Basis:
	var y: Vector3 = -bone.normalized()
	var f: Vector3 = fwd - y * fwd.dot(y)
	if f.length() < 0.0001:
		f = Vector3.FORWARD - y * Vector3.FORWARD.dot(y)
	var z: Vector3 = -f.normalized()
	var x: Vector3 = y.cross(z)
	return Basis(x, y, z)


static func _blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out: Dictionary = {}
	for key: String in b.keys():
		var va: Variant = a.get(key, b[key])
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


# --- poses -----------------------------------------------------------------------------------------------------

## Target pose for an anim at anim_time t. crouch 0..1 bends the knees; balance is the Balance angle -1..1;
## switch turns the rider round on the board.
## speed (m/s) and phase (stride cycles) are for the walking anims: "walk" strides by phase, the others use phase
## for the cycle they start from.
static func pose_for(anim: String, t: float, crouch: float, balance: float, switch: bool = false,
		speed: float = 0.0, phase: float = 0.0) -> Dictionary:
	var pose: Dictionary = _blank()
	var c: float = clampf(crouch, 0.0, 1.0)
	var b: float = clampf(balance, -1.0, 1.0)
	var yaw: float = stance_yaw(anim, switch)
	pose["body_yaw"] = yaw
	pose["feet_yaw"] = yaw
	if anim.begins_with("flip_"):
		_pose_flip(pose, anim, t)
	elif anim.begins_with("grab_"):
		_pose_grab(pose, anim, t)
	elif anim.begins_with("grind_"):
		_pose_grind(pose, anim, t, maxf(c, 0.55), b)
	elif anim.begins_with("manual_"):
		_pose_manual(pose, anim, t, maxf(c, 0.2), b)
	elif anim.begins_with("lip_"):
		_pose_lip(pose, t, maxf(c, 0.4), b)
	elif anim.begins_with("special_"):
		_pose_special(pose, anim, t)
	else:
		match anim:
			"walk":
				_pose_walk(pose, phase, speed)
			"walk_jump":
				_pose_walk_jump(pose, speed)
			"dismount":
				_pose_dismount(pose, t, crouch, switch, phase, speed)
			"mount":
				_pose_mount(pose, t, switch)
			"push":
				_pose_push(pose, t, c)
			"crouch":
				_pose_idle(pose, c)
			"ollie":
				_pose_ollie(pose, t)
			"air":
				_pose_air(pose, t)
			"land":
				_pose_land(pose, t, c)
			"revert":
				_pose_revert(pose, t)
			"bail_fall":
				_pose_bail_fall(pose, t)
			"bail_getup":
				_pose_getup(pose, t)
			"wallride":
				_pose_idle(pose, 0.3)
				_arms(pose, Vector3(0.0, 0.0, -55.0), Vector3(0.0, 0.0, 55.0), 20.0)
				pose["lean"] = 28.0
			_:
				_pose_idle(pose, c)
	_look(pose)
	return pose


static func _blank() -> Dictionary:
	var pose: Dictionary = {}
	for j: String in JOINTS:
		pose[j] = Vector3.ZERO
	pose["hips_y"] = IDLE_HIPS
	pose["lift"] = 0.0
	pose["lean"] = 0.0
	pose["pitch"] = 0.0
	pose["body_yaw"] = 0.0
	pose["feet_yaw"] = 0.0
	pose["board_rot"] = Vector3.ZERO
	pose["board_pos"] = Vector3.ZERO
	pose["foot_L"] = Vector3.ZERO
	pose["foot_R"] = Vector3.ZERO
	pose["toe_L"] = FRONT_TOE
	pose["toe_R"] = BACK_TOE
	pose["feet_on_board"] = 1.0
	pose["feet_free"] = 0.0
	pose["hand_L"] = Vector3.ZERO
	pose["hand_R"] = Vector3.ZERO
	pose["grip_L"] = 0.0
	pose["grip_R"] = 0.0
	return pose


## Head turned to look down the board toward the travel direction, chest following a little. Follows the torso
## yaw: facing the side (0 or 180) looks hard over the lead shoulder, facing down the line (boardslide) looks ahead.
static func _look(pose: Dictionary) -> void:
	var k: float = cos(deg_to_rad(float(pose["body_yaw"])))
	pose["Head"] = (pose["Head"] as Vector3) + Vector3(0.0, HEAD_LOOK * k, 0.0)
	pose["Neck"] = (pose["Neck"] as Vector3) + Vector3(0.0, 8.0 * k, 0.0)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(0.0, 12.0 * k, 0.0)


## Where a stance-frame point (y measured up from the deck top) is in visual space, given the pose's board.
static func deck_point(pose: Dictionary, stance_pos: Vector3) -> Vector3:
	var rot: Vector3 = pose["board_rot"]
	var r: Basis = Basis.from_euler(rot * (PI / 180.0))
	var rel_yaw: float = deg_to_rad(float(pose["feet_yaw"]) - rot.y)
	var local: Vector3 = Basis(Vector3.UP, rel_yaw) * stance_pos + Vector3(0.0, PlaceholderSkater.DECK_TOP_Y, 0.0)
	return (pose["board_pos"] as Vector3) + r * local


## A stance-frame point relative to the ground under the board (no board tilt), in visual space.
static func ground_point(pose: Dictionary, stance_pos: Vector3) -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(float(pose["feet_yaw"]))) * stance_pos


## Both ankles on the deck at their stance spots, nudged by front/back offsets (stance frame, metres).
static func _feet_on_board(pose: Dictionary, front: Vector3 = Vector3.ZERO, back: Vector3 = Vector3.ZERO) -> void:
	var ankle: Vector3 = Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0)
	pose["foot_L"] = deck_point(pose, FRONT_FOOT + front + ankle)
	pose["foot_R"] = deck_point(pose, BACK_FOOT + back + ankle)


static func _arms(pose: Dictionary, left: Vector3, right: Vector3, elbow: float) -> void:
	pose["LeftUpperArm"] = left
	pose["RightUpperArm"] = right
	pose["LeftLowerArm"] = Vector3(elbow, 0.0, 0.0)
	pose["RightLowerArm"] = Vector3(elbow, 0.0, 0.0)


## Spine curl forward (toward the toes), degrees split over the spine and chest.
static func _curl(pose: Dictionary, deg: float) -> void:
	pose["Spine"] = (pose["Spine"] as Vector3) + Vector3(-deg * 0.6, 0.0, 0.0)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(-deg * 0.4, 0.0, 0.0)


static func _pose_idle(pose: Dictionary, c: float) -> void:
	pose["hips_y"] = IDLE_HIPS - CROUCH_DROP * c
	_curl(pose, 6.0 + 22.0 * c)
	_arms(pose, Vector3(10.0, 0.0, -8.0 - 10.0 * c), Vector3(-6.0, 0.0, 8.0 + 10.0 * c), 14.0 + 10.0 * c)
	_feet_on_board(pose)


## Back foot steps off beside the board on the toe side, plants ahead of the tail, sweeps back along the ground and
## swings forward again; the front foot turns to point down the board and the front knee takes the weight.
static func _pose_push(pose: Dictionary, t: float, c: float) -> void:
	var plant: Vector3 = Vector3(0.21, PlaceholderSkater.ANKLE_HEIGHT, 0.02)
	var finish: Vector3 = Vector3(0.24, PlaceholderSkater.ANKLE_HEIGHT, 0.5)
	var ankle: Vector3 = Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0)
	var contact: float = 0.0  ## 1 while the foot is on the ground
	var foot: Vector3
	var reach: float = 0.0  ## 0 foot forward, 1 foot fully back (arm swing)
	if t < _push_plant:
		var k: float = _smooth(t / _push_plant)
		foot = deck_point(pose, BACK_FOOT + ankle).lerp(ground_point(pose, plant), k) + Vector3.UP * 0.07 * sin(PI * k)
		contact = k
	else:
		var u: float = fposmod(t - _push_plant, _push_cycle) / _push_cycle
		if u < _push_contact:
			reach = _smooth(u / _push_contact)
			foot = ground_point(pose, plant.lerp(finish, reach))
			contact = 1.0
		else:
			var k: float = _smooth((u - _push_contact) / (1.0 - _push_contact))
			reach = 1.0 - k
			foot = ground_point(pose, finish.lerp(plant, k)) + Vector3.UP * 0.1 * sin(PI * k)
			contact = 1.0 - sin(PI * k)
	pose["hips_y"] = IDLE_HIPS - 0.17 * maxf(contact, 0.6) - 0.08 * c
	pose["body_yaw"] = float(pose["body_yaw"]) + 38.0  ## torso turns to face down the board
	pose["pitch"] = 7.0
	_curl(pose, 14.0)
	pose["foot_L"] = deck_point(pose, Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, -0.13))
	pose["foot_R"] = foot
	pose["toe_L"] = 70.0
	pose["toe_R"] = 60.0
	var swing: float = 2.0 * reach - 1.0
	_arms(pose, Vector3(-30.0 * swing, 0.0, -10.0), Vector3(30.0 * swing, 0.0, 10.0), 25.0)


## Tail snaps down (board pitched nose up about the tail tip), then the board levels and rises into the tucked feet
## as the front foot slides up toward the nose.
static func _pose_ollie(pose: Dictionary, t: float) -> void:
	var pop: float = clampf(t / POP_TIME, 0.0, 1.0)
	var level: float = _smooth(clampf((t - POP_TIME) / (LEVEL_TIME - POP_TIME), 0.0, 1.0))
	var pitch: float = 26.0 * sin(PI * 0.5 * pop) * (1.0 - level)
	_board_turn(pose, Vector3(pitch, 0.0, 0.0), TAIL_TIP)
	pose["board_pos"] = (pose["board_pos"] as Vector3) + Vector3(0.0, 0.2 * level, 0.0)
	pose["hips_y"] = IDLE_HIPS - 0.02 * level
	_curl(pose, 18.0)
	_arms(pose, Vector3(-25.0 * pop, 0.0, -70.0 * pop), Vector3(25.0 * pop, 0.0, 70.0 * pop), 25.0)
	_feet_on_board(pose, Vector3(0.0, 0.0, -0.07) * pop, Vector3.ZERO)


## In the air the board stays up under tucked feet, then the legs extend for the landing.
static func _pose_air(pose: Dictionary, t: float) -> void:
	pose["board_pos"] = Vector3(0.0, 0.2 * exp(-1.6 * t) + 0.05, 0.0)
	pose["hips_y"] = IDLE_HIPS - 0.02
	_curl(pose, 14.0)
	_arms(pose, Vector3(-15.0, 0.0, -55.0), Vector3(15.0, 0.0, 55.0), 25.0)
	_feet_on_board(pose)


static func _pose_land(pose: Dictionary, t: float, c: float) -> void:
	var bump: float = sin(PI * clampf(t / LAND_TIME, 0.0, 1.0))
	_pose_idle(pose, maxf(c, 0.7 * bump))
	_arms(pose, Vector3(30.0 * bump, 0.0, -25.0 * bump - 8.0), Vector3(-20.0 * bump, 0.0, 25.0 * bump + 8.0), 25.0)


## Flip tricks. The feet leave the deck right after the flick, the board spins under them (eased: quick off the
## flick, slowing into the catch) and the feet come back down onto it at CATCH.
static func _pose_flip(pose: Dictionary, anim: String, t: float) -> void:
	var dbl: bool = anim.contains("double")
	var dur: float = DOUBLE_FLIP_TIME if dbl else FLIP_TIME
	var p: float = clampf(t / dur, 0.0, 1.0)
	var rise: float = 0.18 * sin(PI * minf(p * 1.2, 1.0)) + 0.06 * p
	var pivot: Vector3 = DECK_CENTER
	if anim.contains("impossible"):
		pivot = Vector3(0.0, 0.12, BACK_FOOT.z)  ## wraps round the back foot
	_board_turn(pose, _board_spin(anim, t), pivot)
	pose["board_pos"] = (pose["board_pos"] as Vector3) + Vector3(0.0, rise, 0.0)
	var off: float = 0.0  ## feet height above the deck
	if p < CATCH:
		off = 0.12 * sin(PI * 0.5 * minf(p / 0.25, 1.0))
	else:
		off = 0.12 * (1.0 - _smooth((p - CATCH) / (1.0 - CATCH)))
	# The kick: front foot flicks out toward the toe side and the nose, then tucks back over the board.
	var kick: float = sin(PI * clampf(p / 0.45, 0.0, 1.0))
	var front: Vector3 = Vector3(0.13 * kick, 0.0, -0.08 * kick)
	var back: Vector3 = Vector3.ZERO
	if anim.contains("shove") or anim.contains("varial") or anim.contains("laser") or anim.contains("hardflip"):
		back = Vector3(0.06 * kick, 0.0, 0.05 * kick)  ## the back foot scoops
	var ankle: Vector3 = Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0)
	var level: Dictionary = pose.duplicate()
	level["board_rot"] = Vector3.ZERO
	level["board_pos"] = Vector3(0.0, rise, 0.0)
	pose["foot_L"] = deck_point(level, FRONT_FOOT + front + ankle + Vector3.UP * off)
	pose["foot_R"] = deck_point(level, BACK_FOOT + back + ankle + Vector3.UP * off)
	pose["feet_on_board"] = 0.0 if (p > 0.05 and p < CATCH + 0.1) else 1.0
	_curl(pose, 20.0)
	_arms(pose, Vector3(-20.0, 0.0, -50.0), Vector3(20.0, 0.0, 50.0), 30.0)


## Board rotation (degrees, YXZ Euler) for a flip_* anim at time t: the long-axis roll (Z) for kickflips (+) and
## heelflips (-), the shove (Y: backside +, frontside -) for shove-its, varials, hardflips and laser flips, the
## end-over-end wrap (X) for impossibles. Identity before the flick and again once caught.
static func _board_spin(anim: String, t: float) -> Vector3:
	var dbl: bool = anim.contains("double")
	var dur: float = DOUBLE_FLIP_TIME if dbl else FLIP_TIME
	var n: float = 2.0 if dbl else 1.0
	var p: float = clampf(t / dur, 0.0, 1.0)
	p = 1.0 - (1.0 - p) * (1.0 - p)  ## ease out: fast off the flick, slowing into the catch
	var roll: float = 0.0
	var shove: float = 0.0
	var wrap: float = 0.0
	if anim.contains("impossible"):
		wrap = 360.0 * n
	elif anim.contains("laser"):
		shove = -360.0
		roll = -360.0 * n
	elif anim.contains("hardflip"):
		shove = -180.0
		roll = 360.0 * n
	elif anim.contains("varial_heelflip"):
		shove = -180.0
		roll = -360.0 * n
	elif anim.contains("varial"):
		shove = 180.0
		roll = 360.0 * n
	elif anim.contains("shove"):
		shove = 180.0 * n
	elif anim.contains("heelflip"):
		roll = -360.0 * n
	else:
		roll = 360.0 * n  ## kickflip, frontside flip
	return Vector3(_wrap(wrap * p), _wrap(shove * p), _wrap(roll * p))


## Degrees wrapped to [-180, 180), with whole turns exactly 0.
static func _wrap(deg: float) -> float:
	var w: float = fposmod(deg + 180.0, 360.0) - 180.0
	return 0.0 if absf(w) < 0.0001 else w


## Grabs. The board comes up to the knees, the rider curls down, and one hand (IK) holds the named board spot.
static func _pose_grab(pose: Dictionary, anim: String, t: float) -> void:
	var k: float = _smooth(t / 0.18)
	var hand: String = "L"  ## front hand
	var spot: Vector3 = Vector3(-EDGE, 0.0, -0.09)  ## melon: heel edge, just behind the front foot
	var tweak: Vector3 = Vector3(0.0, 0.0, -1.8 * GRAB_ROLL)  ## extra board rotation (degrees): heel edge up
	var front: Vector3 = Vector3.ZERO
	var back: Vector3 = Vector3.ZERO
	var curl: float = GRAB_CURL * 0.7  ## heel-side grabs reach back, so less forward curl
	if anim.contains("indy"):
		hand = "R"
		spot = Vector3(EDGE, 0.0, 0.02)
		tweak = Vector3(0.0, 0.0, GRAB_ROLL)
		curl = GRAB_CURL * 1.4
	elif anim.contains("mute"):
		spot = Vector3(EDGE, 0.0, -0.03)
		tweak = Vector3(0.0, 0.0, GRAB_ROLL)
		curl = GRAB_CURL * 1.4
	elif anim.contains("stalefish"):
		hand = "R"
		spot = Vector3(-EDGE, 0.0, 0.1)
	elif anim.contains("method"):
		spot = Vector3(-EDGE, 0.0, -0.08)
		tweak = Vector3(0.0, 0.0, -2.0 * GRAB_ROLL)  ## board pulled up behind, heel edge high
		back = Vector3(-0.12, 0.08, 0.03)
		curl = GRAB_CURL * 0.6
	elif anim.contains("nosegrab"):
		spot = Vector3(0.0, 0.0, -0.36)
		tweak = Vector3(18.0, 0.0, 0.0)  ## nose pulled up to the hand
	elif anim.contains("tailgrab"):
		hand = "R"
		spot = Vector3(0.0, 0.0, 0.37)
		tweak = Vector3(-18.0, 0.0, 0.0)
	elif anim.contains("benihana"):
		hand = "R"
		spot = Vector3(0.0, 0.0, 0.37)
		tweak = Vector3(-18.0, 0.0, 0.0)
		back = Vector3(0.05, -0.32, 0.12)  ## back foot kicked off and down
	elif anim.contains("airwalk"):
		spot = Vector3(0.0, 0.0, -0.36)
		tweak = Vector3(18.0, 0.0, 0.0)
		front = Vector3(0.22, 0.05, -0.18)  ## front foot walks off forward
		back = Vector3(-0.15, 0.0, 0.12)
	# Lean the whole body toward the grabbed spot so the short cartoon arm reaches it.
	var sway: float = cos(deg_to_rad(float(pose["feet_yaw"])))
	pose["lean"] = (0.0 if spot.x > 0.0 else -25.0 if spot.x < 0.0 else 0.0) * sway * k
	pose["pitch"] = (22.0 if spot.z < -0.2 else -22.0 if spot.z > 0.2 else 0.0) * k
	_board_turn(pose, tweak * k, DECK_CENTER)
	pose["board_pos"] = (pose["board_pos"] as Vector3) + Vector3(0.0, GRAB_RISE * k, 0.0)
	pose["lift"] = GRAB_LIFT * k
	_curl(pose, curl * k)
	_feet_on_board(pose, front * k, back * k)
	if front != Vector3.ZERO or back.y < -0.1:
		pose["feet_on_board"] = 0.0
	pose["hand_" + hand] = deck_point(pose, spot + Vector3(0.0, 0.01, 0.0))
	pose["grip_" + hand] = k
	if hand == "L":
		_arms(pose, Vector3.ZERO, Vector3(-20.0, 0.0, 70.0), 20.0)
	else:
		_arms(pose, Vector3(-20.0, 0.0, -70.0), Vector3.ZERO, 20.0)


static func _pose_revert(pose: Dictionary, t: float) -> void:
	var yaw: float = 180.0 * _smooth(t / REVERT_TIME)
	_pose_idle(pose, 0.4)
	pose["body_yaw"] = float(pose["body_yaw"]) + yaw
	pose["feet_yaw"] = float(pose["feet_yaw"]) + yaw
	# The board turns with the rider; it is symmetric, so it ends where it started.
	_board_turn(pose, Vector3(0.0, yaw - 180.0, 0.0), Vector3.ZERO)
	_feet_on_board(pose)


static func _pose_bail_fall(pose: Dictionary, t: float) -> void:
	var p: float = clampf(t / FALL_TIME, 0.0, 1.0)
	p = p * p
	_feet_on_board(pose)
	_arms(pose, Vector3(70.0 * sin(t * 12.0), 0.0, -60.0), Vector3(70.0 * sin(t * 12.0 + PI), 0.0, 60.0), 40.0)
	pose["lean"] = 80.0 * p
	pose["hips_y"] = IDLE_HIPS - 0.2 * p
	pose["feet_free"] = p


static func _pose_getup(pose: Dictionary, t: float) -> void:
	var d: float = SkateState.BAIL_TIME * 0.4  ## the rest of the bail after the fall
	var rest: float = 1.0 - _smooth(t / d)
	_pose_idle(pose, 0.8 * rest)
	_arms(pose, Vector3(40.0 * rest * sin(t * 12.0), 0.0, -40.0 * rest - 5.0),
			Vector3(40.0 * rest * sin(t * 12.0 + PI), 0.0, 40.0 * rest + 5.0), 30.0)
	pose["lean"] = 80.0 * rest
	pose["hips_y"] = float(pose["hips_y"]) - 0.2 * rest
	pose["feet_free"] = rest


static func _pose_grind(pose: Dictionary, anim: String, t: float, c: float, b: float) -> void:
	var flail: float = 35.0 * absf(b) * sin(t * 10.0)
	_arms(pose, Vector3(flail, 0.0, -40.0), Vector3(-flail, 0.0, 40.0), 20.0)
	pose["lean"] = LEAN_MAX * b
	match anim:
		"grind_five_oh":
			_board_turn(pose, Vector3(-14.0, 0.0, 0.0), REAR_TRUCK)
			pose["pitch"] = -8.0
		"grind_nosegrind":
			_board_turn(pose, Vector3(14.0, 0.0, 0.0), FRONT_TRUCK)
			pose["pitch"] = 10.0
		"grind_crooked_grind":
			_board_turn(pose, Vector3(-12.0, 16.0, 6.0), FRONT_TRUCK)
			pose["pitch"] = 10.0
		"grind_smith_grind":
			_board_turn(pose, Vector3(14.0, 0.0, -22.0), REAR_TRUCK)
			pose["pitch"] = -6.0
		"grind_feeble_grind":
			_board_turn(pose, Vector3(10.0, 0.0, 22.0), REAR_TRUCK)
			pose["pitch"] = -6.0
		"grind_boardslide", "grind_lipslide":
			# Board across the rail, body turned to face down it.
			var turn: float = 90.0 if anim == "grind_boardslide" else -90.0
			pose["body_yaw"] = float(pose["body_yaw"]) + turn
			pose["feet_yaw"] = float(pose["feet_yaw"]) + turn
			_board_turn(pose, Vector3(0.0, float(pose["feet_yaw"]), 0.0), Vector3.ZERO)
		"grind_blunt_slide":
			_board_turn(pose, Vector3(-55.0, 0.0, 0.0), REAR_TRUCK)
			pose["pitch"] = -12.0
	pose["hips_y"] = IDLE_HIPS - CROUCH_DROP * c
	_curl(pose, 12.0 + 14.0 * c)
	_feet_on_board(pose)


static func _pose_manual(pose: Dictionary, anim: String, t: float, c: float, b: float) -> void:
	var nose: bool = anim == "manual_nose_manual"
	var sgn: float = -1.0 if nose else 1.0
	var flail: float = 25.0 * sin(t * 8.0) * b
	_arms(pose, Vector3(flail, 0.0, -50.0), Vector3(-flail, 0.0, 50.0), 15.0)
	pose["pitch"] = -10.0 * sgn + 6.0 * b  ## weight back over the tail (forward over the nose)
	var pivot: Vector3 = Vector3(0.0, 0.0, -WHEEL_CONTACT_Z) if nose else Vector3(0.0, 0.0, WHEEL_CONTACT_Z)
	_board_turn(pose, Vector3(sgn * MANUAL_PITCH + 8.0 * b, 0.0, 0.0), pivot)
	pose["hips_y"] = IDLE_HIPS - CROUCH_DROP * c
	_curl(pose, 8.0 + 10.0 * c)
	_feet_on_board(pose)


static func _pose_lip(pose: Dictionary, t: float, c: float, b: float) -> void:
	var flail: float = 20.0 * sin(t * 8.0) * absf(b)
	_arms(pose, Vector3(flail, 0.0, -60.0), Vector3(-flail, 0.0, 60.0), 30.0)
	_board_turn(pose, Vector3(LIP_PITCH + 8.0 * b, 0.0, 0.0), REAR_TRUCK)
	pose["hips_y"] = IDLE_HIPS - CROUCH_DROP * c
	pose["pitch"] = -6.0
	_feet_on_board(pose)


static func _pose_special(pose: Dictionary, anim: String, t: float) -> void:
	var p: float = clampf(t / SPECIAL_SPIN_TIME, 0.0, 1.0)
	_board_turn(pose, Vector3(0.0, _wrap(720.0 * p), 0.0), DECK_CENTER)  ## two slow turns, ends at identity
	pose["board_pos"] = (pose["board_pos"] as Vector3) + Vector3(0.0, 0.18 * sin(PI * p), 0.0)
	_arms(pose, Vector3(0.0, 0.0, -150.0), Vector3(0.0, 0.0, 150.0), 20.0)
	pose["lean"] = 12.0 * sin(t * 6.0)
	_feet_on_board(pose)
	pose["feet_on_board"] = 0.0
	if anim.contains("moonwalk") or anim.contains("gravity"):
		var w: float = sin(t * 9.0)  ## feet walk over the spinning board
		pose["foot_L"] = (pose["foot_L"] as Vector3) + Vector3(0.0, 0.12 + 0.08 * w, 0.0)
		pose["foot_R"] = (pose["foot_R"] as Vector3) + Vector3(0.0, 0.12 - 0.08 * w, 0.0)
	else:
		pose["foot_R"] = (pose["foot_R"] as Vector3) + Vector3(0.0, -0.05, 0.3)  ## one leg kicked out behind


## Walk cycle. Stride length and cadence grow with speed (run above ~3 m/s), standing still at 0. Feet go in visual
## space on the ground; the free (left) arm swings against the legs; the right hand holds the carried board.
static func _pose_walk(pose: Dictionary, phase: float, speed: float) -> void:
	var run_k: float = clampf((speed - 2.0) / 2.0, 0.0, 1.0)
	var amp: float = clampf(speed / 0.6, 0.0, 1.0)
	var half: float = minf(0.18 + 0.045 * speed, 0.32) * amp  ## foot travel either side of the hips
	var stance: float = lerpf(0.5, 0.4, run_k)  ## share of the cycle a foot is on the ground
	var foot_lift: float = (0.05 + 0.05 * run_k) * amp
	var reach: float = sqrt(WALK_LEG * WALK_LEG - half * half)  ## hip height that keeps the legs just reachable
	var bob: float = 0.025 * amp * -cos(4.0 * PI * phase)  ## highest over a planted foot
	var hips: float = PlaceholderSkater.ANKLE_HEIGHT + reach - PlaceholderSkater.HIP_HEIGHT - 0.03 * (1.0 - amp) + bob
	var lean: float = (3.0 + 9.0 * run_k) * amp
	pose["hips_y"] = hips
	pose["lift"] = -PlaceholderSkater.DECK_TOP_Y  ## body root on the ground
	pose["pitch"] = lean
	pose["body_yaw"] = 90.0  ## facing visual -Z
	pose["feet_yaw"] = 90.0
	pose["toe_L"] = 0.0
	pose["toe_R"] = 0.0
	pose["feet_on_board"] = 0.0
	# Centre the feet under the hips, which the forward lean pushes ahead.
	var centre: float = -(PlaceholderSkater.HIP_HEIGHT + hips) * sin(deg_to_rad(lean))
	var left: Vector2 = _foot_cycle(fposmod(phase, 1.0), half, stance, foot_lift)
	var right: Vector2 = _foot_cycle(fposmod(phase + 0.5, 1.0), half, stance, foot_lift)
	pose["foot_L"] = Vector3(-0.09, PlaceholderSkater.ANKLE_HEIGHT + left.y, centre + left.x)
	pose["foot_R"] = Vector3(0.09, PlaceholderSkater.ANKLE_HEIGHT + right.y, centre + right.x)
	_curl(pose, 3.0 + 8.0 * run_k)
	var swing: float = (16.0 + 26.0 * run_k) * amp * -cos(2.0 * PI * phase)  ## forward when the right foot is
	pose["LeftUpperArm"] = Vector3(swing, 0.0, -4.0)
	pose["LeftLowerArm"] = Vector3(10.0 + 40.0 * run_k * amp, 0.0, 0.0)
	pose["RightUpperArm"] = Vector3(0.0, 0.0, 6.0)
	pose["RightLowerArm"] = Vector3(30.0, 0.0, 0.0)
	_carry_board(pose, bob * 0.6)


## The board on edge under the right arm and the right hand on its top edge.
static func _carry_board(pose: Dictionary, bob: float) -> void:
	var rot: Vector3 = Vector3(CARRY_PITCH, 0.0, CARRY_ROLL)
	var b: Basis = Basis.from_euler(rot * (PI / 180.0))
	var origin: Vector3 = CARRY_CENTER + Vector3(0.0, bob, 0.0) - b * Vector3(0.0, AnimeBoard.DECK_Y, 0.0)
	pose["board_rot"] = rot
	pose["board_pos"] = origin
	pose["hand_R"] = origin + b * Vector3(AnimeBoard.DECK_WIDTH * 0.5 - 0.01, AnimeBoard.DECK_Y, -0.05)
	pose["grip_R"] = 1.0


## One foot's (forward-back offset z, height y) at cycle position u: planted and sliding back for `stance` of the
## cycle (-Z is forward), then swung forward through the air.
static func _foot_cycle(u: float, half: float, stance: float, lift: float) -> Vector2:
	if u < stance:
		return Vector2(lerpf(-half, half, u / stance), 0.0)
	var s: float = (u - stance) / (1.0 - stance)
	return Vector2(lerpf(half, -half, _smooth(s)), lift * sin(PI * s))


## Jump on foot: standing pose with the knees pulled up and the free arm out.
static func _pose_walk_jump(pose: Dictionary, speed: float) -> void:
	_pose_walk(pose, 0.0, minf(speed, 1.0))
	pose["foot_L"] = (pose["foot_L"] as Vector3) + Vector3(0.0, 0.12, -0.05)
	pose["foot_R"] = (pose["foot_R"] as Vector3) + Vector3(0.0, 0.1, 0.06)
	pose["hips_y"] = float(pose["hips_y"]) + 0.02
	pose["LeftUpperArm"] = Vector3(-20.0, 0.0, -65.0)


## Step off the board: the ride stance eases into the carry pose in STEP_OFF_TIME as the board comes up to the arm.
static func _pose_dismount(pose: Dictionary, t: float, crouch: float, switch: bool, phase: float, speed: float) -> void:
	var k: float = _smooth(t / STEP_OFF_TIME)
	var ride: Dictionary = _blank()
	ride["body_yaw"] = stance_yaw("idle_ride", switch)
	ride["feet_yaw"] = stance_yaw("idle_ride", switch)
	_pose_idle(ride, clampf(crouch, 0.0, 1.0))
	var walk: Dictionary = _blank()
	_pose_walk(walk, phase, speed)
	var out: Dictionary = _blend(ride, walk, k)
	out["lift"] = float(out["lift"]) + 0.06 * sin(PI * k)  ## a little hop off
	out["board_pos"] = (out["board_pos"] as Vector3) + Vector3(0.0, 0.1 * sin(PI * k), 0.0)
	for key: String in out.keys():
		pose[key] = out[key]


## Hop onto the board: it drops to the ground just ahead, then the rider steps up onto it and it slides under the feet.
static func _pose_mount(pose: Dictionary, t: float, switch: bool) -> void:
	var k: float = _smooth(t / HOP_ON_TIME)
	var start: Dictionary = _blank()
	_pose_walk(start, 0.0, 0.0)
	start["board_rot"] = Vector3.ZERO
	start["board_pos"] = Vector3(0.0, 0.0, -0.5)
	start["grip_R"] = 0.0
	var ride: Dictionary = _blank()
	ride["body_yaw"] = stance_yaw("idle_ride", switch)
	ride["feet_yaw"] = stance_yaw("idle_ride", switch)
	_pose_idle(ride, 0.3)
	var out: Dictionary = _blend(start, ride, k)
	out["lift"] = float(out["lift"]) + 0.08 * sin(PI * k)
	for key: String in out.keys():
		pose[key] = out[key]


static func _board_turn(pose: Dictionary, euler_deg: Vector3, pivot: Vector3) -> void:
	var r: Basis = Basis.from_euler(euler_deg * (PI / 180.0))
	pose["board_rot"] = euler_deg
	pose["board_pos"] = pivot - r * pivot  ## keeps the pivot point fixed in place


static func _smooth(x: float) -> float:
	var p: float = clampf(x, 0.0, 1.0)
	return p * p * (3.0 - 2.0 * p)
