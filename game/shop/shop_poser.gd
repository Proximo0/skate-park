class_name ShopPoser
extends SkaterPoser
## SkaterPoser plus a few shop poses, so NPCs and the player can stand around, lean on the counter and sit on the
## couch without touching game/skater/. With `mode` == "" it is exactly a SkaterPoser (the player walking).
## Modes: "stand" (carrying the board under the arm, swaying a little and looking around), "counter" (no board,
## hands on the counter top in front), "sit" (on a seat SEAT_HEIGHT high, hands on the knees, board on the floor).
## All poses are in the body's "visual" space: -Z forward, the floor at y = 0 under the hips.

const SEAT_HEIGHT: float = 0.47  ## hip joint height when sitting: glutes on a cushion top about 0.38
const SIT_RECLINE: float = 28.0  ## degrees the pelvis and spine lean back, onto the backrest
const SIT_FEET: float = 0.56  ## ankles this far in front of the hips (knees just past the cushion edge)
const SHOP_BLEND_RATE: float = 8.0

var mode: String = ""
var sway_phase: float = 0.0  ## offsets the idle sway so NPCs don't move in step
var look_yaw: float = 0.0  ## extra head turn, degrees (+ = to the body's left)
var _shop_t: float = 0.0


func _process(delta: float) -> void:
	if mode == "":
		super._process(delta)
		return
	if body == null or board == null:
		return
	if _nodes.is_empty():
		_capture_rest()
	_shop_t += delta
	var target: Dictionary = shop_pose(mode, _shop_t + sway_phase, look_yaw)
	if not _has_pose:
		_current = target
		_has_pose = true
	else:
		_current = SkaterPoser._blend(_current, target, 1.0 - exp(-SHOP_BLEND_RATE * delta))
	_apply(_current)


## The target pose for a shop mode at time t (seconds). Pure, unit tested.
static func shop_pose(pose_mode: String, t: float, look: float = 0.0) -> Dictionary:
	var pose: Dictionary = SkaterPoser.pose_for("walk", 0.0, 0.0, 0.0, false, 0.0, 0.0)
	match pose_mode:
		"sit":
			_shop_sit(pose, t)
		"counter":
			_shop_counter(pose, t)
		_:
			_shop_stand(pose, t)
	pose["Head"] = (pose["Head"] as Vector3) + Vector3(0.0, look, 0.0)
	return pose


## Standing with the board under the arm: weight shifts side to side, the head looks around now and then.
static func _shop_stand(pose: Dictionary, t: float) -> void:
	var sway: float = sin(t * 0.9)
	pose["hips_y"] = float(pose["hips_y"]) - 0.01 + 0.008 * sin(t * 1.8)
	pose["lean"] = 2.0 * sway
	pose["Spine"] = (pose["Spine"] as Vector3) + Vector3(0.0, 0.0, -2.5 * sway)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(0.0, 4.0 * sin(t * 0.37), 0.0)
	pose["Head"] = (pose["Head"] as Vector3) + Vector3(3.0 * sin(t * 0.5), 16.0 * sin(t * 0.31), 0.0)
	pose["foot_L"] = Vector3(-0.11, PlaceholderSkater.ANKLE_HEIGHT, -0.02)
	pose["foot_R"] = Vector3(0.12, PlaceholderSkater.ANKLE_HEIGHT, 0.04)
	pose["toe_L"] = -8.0
	pose["toe_R"] = 10.0
	pose["LeftUpperArm"] = Vector3(4.0, 0.0, -6.0 - 2.0 * sway)


## Behind the counter: no board, leaning forward a little with both hands on the counter top.
static func _shop_counter(pose: Dictionary, t: float) -> void:
	_shop_stand(pose, t)
	pose["lean"] = 0.0
	pose["Spine"] = Vector3(-6.0, 0.0, 0.0)
	pose["Chest"] = Vector3(-4.0, 6.0 * sin(t * 0.4), 0.0)
	pose["hand_L"] = Vector3(-0.2, 1.03, -0.36)
	pose["hand_R"] = Vector3(0.22, 1.03, -0.34)
	pose["grip_L"] = 1.0
	pose["grip_R"] = 1.0
	pose["board_pos"] = Vector3(0.0, -5.0, 0.0)  ## out of sight under the floor (the caller also hides it)


## Sitting: glutes on the cushion, thighs level to knees just past its front edge, shins down to the floor, the
## pelvis and spine reclined so the back rests on the backrest, hands on the thighs, board on the floor in front.
## Measured on the Houdini bodies (fuller hips): SEAT_HEIGHT puts the glutes on ShopInterior's cushion top (about
## 0.38) and SIT_RECLINE the shoulder blades on its backrest with the hips at SEAT_X.
static func _shop_sit(pose: Dictionary, t: float) -> void:
	pose["hips_y"] = SEAT_HEIGHT - PlaceholderSkater.HIP_HEIGHT
	pose["lift"] = -PlaceholderSkater.DECK_TOP_Y
	pose["pitch"] = 0.0
	pose["lean"] = 0.0
	pose["feet_on_board"] = 0.0
	pose["foot_L"] = Vector3(-0.14, PlaceholderSkater.ANKLE_HEIGHT, -SIT_FEET)
	pose["foot_R"] = Vector3(0.15, PlaceholderSkater.ANKLE_HEIGHT, -SIT_FEET + 0.03)
	pose["toe_L"] = -10.0
	pose["toe_R"] = 12.0
	var breathe: float = sin(t * 1.3)
	pose["Hips"] = Vector3(SIT_RECLINE * 0.45, 0.0, 0.0)
	pose["Spine"] = Vector3(SIT_RECLINE * 0.35 + 1.0 * breathe, 0.0, 0.0)
	pose["Chest"] = Vector3(SIT_RECLINE * 0.2, 0.0, 0.0)
	pose["Neck"] = Vector3(-10.0, 0.0, 0.0)
	pose["Head"] = Vector3(-12.0, 6.0 * sin(t * 0.23), 4.0)  ## chin down from the recline, eyes ahead
	pose["hand_L"] = Vector3(-0.16, SEAT_HEIGHT + 0.07, -0.22)
	pose["hand_R"] = Vector3(0.17, SEAT_HEIGHT + 0.07, -0.2)
	pose["grip_L"] = 1.0
	pose["grip_R"] = 1.0
	pose["board_rot"] = Vector3(0.0, 90.0, 0.0)
	pose["board_pos"] = Vector3(0.05, 0.0, -0.88)
