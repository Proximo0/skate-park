class_name PedPoser
extends SkaterPoser
## SkaterPoser for pedestrians: no board, both arms swinging, and a few street poses. It never runs on its own
## (_process is off: Pedestrian calls drive() at its own LOD rate), so remember the poser gotcha when you build one by
## hand: add_child(poser), then poser.set_process(false), or SkaterPoser._process would overwrite the pose.
## Modes: "walk" (stride by phase and speed), "idle" (weight shifts, looks around), "phone" (head down over a phone in
## the right hand), "chat" (talking with the hands), "wave" (big friendly wave), "startle" (leans back, hands up).
## All poses are in the body's visual space: -Z forward, the floor at y = 0. Joint angle signs (degrees, added to the
## rest pose): an upper arm's +X swings it forward, a right upper arm's -Z (left's +Z) brings it in to the side and +Y
## (left's -Y) turns a bent forearm in across the body; a lower arm's +X bends the elbow; Head/Neck +X tilts the face
## up and Spine +X leans back.

const PED_BLEND: float = 9.0

var mode: String = "idle"
var look_yaw: float = 0.0  ## extra head turn in degrees (+ = to the body's left)
var sway_phase: float = 0.0


## Blends toward the pose for the current mode and applies it. `t` is the walker's own clock (seconds), phase and
## speed drive the walk.
func drive(delta: float, t: float, phase: float, speed: float) -> void:
	if body == null or board == null:
		return
	if _nodes.is_empty():
		_capture_rest()
	var target: Dictionary = ped_pose(mode, t + sway_phase, phase, speed, look_yaw)
	if not _has_pose:
		_current = target
		_has_pose = true
	else:
		_current = SkaterPoser._blend(_current, target, 1.0 - exp(-PED_BLEND * delta))
	_apply(_current)


## The target pose for a mode. Pure, unit tested.
static func ped_pose(pose_mode: String, t: float, phase: float, speed: float, look: float = 0.0) -> Dictionary:
	var walking: bool = pose_mode == "walk"
	var pose: Dictionary = SkaterPoser.pose_for("walk", 0.0, 0.0, 0.0, false, speed if walking else 0.0, phase if walking else 0.0)
	# no board: tuck it away and free the right hand
	pose["board_pos"] = Vector3(0.0, -50.0, 0.0)
	pose["grip_R"] = 0.0
	if walking:
		_ped_walk_arms(pose, phase, speed)
	else:
		_ped_stand(pose, t)
	match pose_mode:
		"phone":
			_ped_phone(pose, t)
		"chat":
			_ped_chat(pose, t)
		"wave":
			_ped_wave(pose, t)
		"startle":
			_ped_startle(pose, t)
	pose["Head"] = (pose["Head"] as Vector3) + Vector3(0.0, look, 0.0)
	return pose


## Both arms swing against the legs (the walk cycle only swings the left; the right one carried the board).
static func _ped_walk_arms(pose: Dictionary, phase: float, speed: float) -> void:
	var amp: float = clampf(speed / 0.6, 0.0, 1.0)
	var swing: float = 18.0 * amp * -cos(TAU * phase)
	pose["LeftUpperArm"] = Vector3(swing, 0.0, 6.0)
	pose["RightUpperArm"] = Vector3(-swing, 0.0, -6.0)
	pose["LeftLowerArm"] = Vector3(14.0 + 6.0 * maxf(swing, 0.0) / 18.0, 0.0, 0.0)
	pose["RightLowerArm"] = Vector3(14.0 + 6.0 * maxf(-swing, 0.0) / 18.0, 0.0, 0.0)
	# a little hip roll and counter-rotation of the chest
	pose["Hips"] = (pose["Hips"] as Vector3) + Vector3(0.0, 4.0 * amp * sin(TAU * phase), 0.0)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(0.0, -5.0 * amp * sin(TAU * phase), 0.0)


## Standing: weight shifting from foot to foot, arms relaxed, the head looking around now and then.
static func _ped_stand(pose: Dictionary, t: float) -> void:
	var sway: float = sin(t * 0.8)
	pose["hips_y"] = float(pose["hips_y"]) - 0.01 + 0.006 * sin(t * 1.6)
	pose["lean"] = 1.6 * sway
	pose["Spine"] = (pose["Spine"] as Vector3) + Vector3(0.0, 0.0, -2.0 * sway)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(0.0, 3.0 * sin(t * 0.33), 0.0)
	pose["Head"] = (pose["Head"] as Vector3) + Vector3(2.0 * sin(t * 0.45), 14.0 * sin(t * 0.27), 0.0)
	pose["foot_L"] = Vector3(-0.12, PlaceholderSkater.ANKLE_HEIGHT, -0.03)
	pose["foot_R"] = Vector3(0.12, PlaceholderSkater.ANKLE_HEIGHT, 0.03)
	pose["toe_L"] = -9.0
	pose["toe_R"] = 9.0
	pose["LeftUpperArm"] = Vector3(3.0, 0.0, 8.0)
	pose["RightUpperArm"] = Vector3(3.0, 0.0, -8.0)
	pose["LeftLowerArm"] = Vector3(12.0, 0.0, 0.0)
	pose["RightLowerArm"] = Vector3(12.0, 0.0, 0.0)


## Looking down at a phone held in front of the chest in the right hand, thumb busy.
static func _ped_phone(pose: Dictionary, t: float) -> void:
	pose["Head"] = Vector3(-20.0, 4.0 * sin(t * 0.7), 0.0)
	pose["Neck"] = Vector3(-10.0, 0.0, 0.0)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(-3.0, 0.0, 0.0)
	var thumb: float = 2.0 * maxf(sin(t * 7.0), 0.0)
	pose["RightUpperArm"] = Vector3(20.0, 30.0, -8.0)
	pose["RightLowerArm"] = Vector3(92.0 + thumb, 0.0, 0.0)
	pose["LeftUpperArm"] = Vector3(12.0, -22.0, 8.0)
	pose["LeftLowerArm"] = Vector3(80.0, 0.0, 0.0)


## Talking: the head nods along, one hand and then the other gestures.
static func _ped_chat(pose: Dictionary, t: float) -> void:
	var a: float = maxf(sin(t * 1.3), 0.0)
	var b: float = maxf(sin(t * 1.3 + 2.4), 0.0)
	pose["RightUpperArm"] = Vector3(4.0 + 20.0 * a, 18.0 * a, -6.0)
	pose["RightLowerArm"] = Vector3(15.0 + 60.0 * a, 0.0, 0.0)
	pose["LeftUpperArm"] = Vector3(4.0 + 16.0 * b, -14.0 * b, 6.0)
	pose["LeftLowerArm"] = Vector3(15.0 + 50.0 * b, 0.0, 0.0)
	pose["Head"] = (pose["Head"] as Vector3) + Vector3(5.0 * sin(t * 4.0) * (a + b), 0.0, 3.0 * sin(t * 0.9))


## A big friendly wave with the right hand.
static func _ped_wave(pose: Dictionary, t: float) -> void:
	pose["RightUpperArm"] = Vector3(-10.0, 0.0, 150.0)
	pose["RightLowerArm"] = Vector3(25.0 + 25.0 * sin(t * 9.0), 0.0, 0.0)
	pose["Head"] = (pose["Head"] as Vector3) + Vector3(6.0, 0.0, 0.0)


## Surprised: leaning back, hands up in front, knees soft.
static func _ped_startle(pose: Dictionary, _t: float) -> void:
	pose["pitch"] = -7.0
	pose["hips_y"] = float(pose["hips_y"]) - 0.04
	pose["Spine"] = Vector3(8.0, 0.0, 0.0)
	pose["Head"] = Vector3(6.0, 0.0, 0.0)
	pose["LeftUpperArm"] = Vector3(45.0, -20.0, 5.0)
	pose["RightUpperArm"] = Vector3(45.0, 20.0, -5.0)
	pose["LeftLowerArm"] = Vector3(85.0, 0.0, 0.0)
	pose["RightLowerArm"] = Vector3(85.0, 0.0, 0.0)
