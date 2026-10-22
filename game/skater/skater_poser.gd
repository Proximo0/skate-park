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
## front); "fpitch_L"/"fpitch_R" shoe pitch in degrees (+ toe up, heel-to-toe walking); "feet_on_board" 0..1 (1 = shoes lie flat on the deck, 0 = level); "feet_free" 0..1 (1 = feet hang
## from the hips instead of their targets, for bails); "hand_L"/"hand_R" hand targets in visual space with
## "grip_L"/"grip_R" 0..1 IK weights. pose_for() is pure and unit tested.
##
## Context (pose_for's ctx, filled from the live skater by _skater_ctx): "impact" (land_impact 0..1, scales the
## landing absorb), "carve" (-1..1 sideways acceleration, lean into turns), "ride_speed" (m/s, idle variety only
## when stopped), "vy" (vertical speed, the legs reach for the ground when falling). After a ragdoll bail the get-up
## blends the joints and board from where the ragdoll left them (_blend_from_ragdoll).

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
## Push stance (stance frame, metres / degrees).
const PUSH_YAW: float = 78.0  ## hips and shoulders open toward the nose
const PUSH_PITCH: float = 12.0  ## body tipped toward the nose so the hips sit over the front foot
const PUSH_FRONT: Vector3 = Vector3(0.01, 0.0, -0.17)  ## front foot over the front bolts
const PUSH_STEP: Vector3 = Vector3(0.2, 0.0, -0.2)  ## push foot plant on the ground, beside the front truck
const PUSH_END: Vector3 = Vector3(0.22, 0.0, 0.42)  ## end of the drive, just past the tail
const PUSH_FRONT_TOE: float = 84.0  ## front foot pivoted to point down the board
const PUSH_BACK_TOE: float = 86.0  ## push foot toes forward

## Live push timing. Start at the consts above; a poser whose skater has a `tune` copies its push_* fields in
## each frame so the pose stays in step with the push kicks.
static var _push_plant: float = PUSH_PLANT
static var _push_cycle: float = PUSH_CYCLE
static var _push_contact: float = PUSH_CONTACT
const POP_TIME: float = 0.08  ## tail snap
const LEVEL_TIME: float = 0.22  ## board levels out and rises to the feet
const LAND_TIME: float = 0.2  ## recovery of a landing at the default impact (land_time() scales it)
## Landing absorb (ctx "impact", Skater.land_impact 0..1): a small hop barely dips the knees and is back up in about
## 0.17 s, a big drop compresses deep (hips down to ~0.29 m below idle) and springs back over ~0.55 s.
const LAND_IMPACT_DEFAULT: float = 0.35
const LAND_TIME_MIN: float = 0.2
const LAND_TIME_PER_IMPACT: float = 0.55
const LAND_HIT: float = 0.3  ## share of the landing spent compressing; the rest springs back
const LAND_HOLD: float = 0.16  ## share of the landing the knees stay at the bottom of the compression, big landings only
const SKETCHY_TIME: float = 0.6  ## a sketchy landing (caught late) staggers for this long: arms windmill, the body wobbles
const LAND_DEPTH_MAX: float = 1.2  ## crouch-equivalent at impact 1 (hips CROUCH_DROP * this below idle)
const BLEND_RATE_LAND: float = 30.0  ## a landing dip is quick; the slow blend would swallow a small one
## Carving (ctx "carve", -1..1, + = turning toward visual +X): the body leans into the turn, the deck rolls on its
## trucks, the shoulders lead and the head looks through the turn.
const CARVE_LEAN: float = 19.0
const CARVE_ROLL: float = 8.0
const CARVE_ACCEL: float = 9.0  ## m/s^2 of sideways acceleration for a full carve
const TILT_PIVOT: Vector3 = Vector3(0.0, 0.55, 0.0)  ## visual space: the rider and board turn about the hips when the tilt is applied
const TILT_VERT: float = 0.72  ## share of the way the vert-air rider rights itself toward world up (the board comes with)
## Air body language (anim "air", ctx "vy"): the board is pulled up under the feet while rising, held at the apex, and the
## legs reach for the ground as it falls; the eyes pick out the landing.
const AIR_PULL_RISE: float = 0.30  ## board pulled this far up under the feet (metres) at the top of the pop
const AIR_PULL_APEX: float = 0.22
const AIR_PULL_LAND: float = 0.03
const GROUND_ANIMS: PackedStringArray = ["idle_ride", "push", "crouch", "land"]
const CARVE_ANIMS: PackedStringArray = ["idle_ride", "crouch", "push", "land"]
## Idle variety while stopped (ctx "ride_speed" under IDLE_STILL_SPEED): a cycle of shifting the weight onto the back
## foot, looking around, re-setting the front foot and loosening the arms, after IDLE_DELAY seconds of idling.
const IDLE_STILL_SPEED: float = 1.5
const IDLE_DELAY: float = 1.5
const IDLE_CYCLE: float = 10.0
## Get-up after a ragdoll bail: the body blends from where the ragdoll left it into the get-up pose over this long.
const GETUP_BLEND: float = 0.45
const GETUP_BOARD_REACH: float = 1.5  ## a ragdoll board farther than this from the feet is not blended back
## Powerslide (anim "powerslide"): board turned across the line, rider sitting back against the slide.
const POWERSLIDE_YAW: float = 90.0
const REVERT_TIME: float = 0.3
const SPECIAL_SPIN_TIME: float = 2.0
const FALL_TIME: float = 0.5
const LEAN_MAX: float = 25.0
const MANUAL_PITCH: float = 12.0
const LIP_PITCH: float = 70.0
const GRIND_STALL: float = 6.0  ## 5-0 / nosegrind: board pitch about the grinding truck, the free end up (Houdini bodies)
## The VRoid lead (ctx "vrm"): its own leg lengths and IK keep the feet on the tilted deck and its garments are skin,
## so the stall can tip the board a believable amount. Houdini garments (never grinding in play) keep the small cap.
const GRIND_STALL_VRM: float = 14.0
const GRIND_BLUNT: float = 50.0  ## blunt slide: board stood up nose high on its tail
## "drop_in" (the ramp snap): tail hooked on the coping with the nose up for RampSnap.HANG_TIME, then the front foot
## stomps the nose down over RampSnap.STOMP_TIME while the rider leans into the ramp; then the board rolls over the
## coping onto the wall (the skater tips the whole visual over, RampSnap.TIP_TIME) and the stomp pitch eases back flat
## on the wall over DROP_SETTLE_TIME, so the board's total pitch keeps going one way, nose down, with no kick back.
const DROP_HANG_PITCH: float = 16.0
const DROP_STOMP_PITCH: float = -22.0
const DROP_SETTLE_TIME: float = RampSnap.TIP_TIME

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
const NOSE_TIP: Vector3 = Vector3(0.0, 0.0, -0.40)  ## nollie pivot: the nose snaps down onto the ground
const GRAB_RISE: float = 0.72  ## board comes up to the knees
const GRAB_LIFT: float = 0.24  ## the body rises less, so the knees tuck
const GRAB_CURL: float = 50.0
const GRAB_ROLL: float = 22.0  ## grabbed edge tipped up toward the hand
const EDGE: float = 0.12  ## deck half width plus a little, where a hand wraps the edge

## Walking (anims "walk", "walk_jump", "dismount", "mount"). The body faces visual -Z with its feet on the ground, the
## board is carried on edge under the right arm (wheels out, grip against the hip) and that hand holds the deck's top edge.
const STEP_OFF_TIME: float = 0.25  ## "dismount": ride pose to carry pose
const HOP_ON_TIME: float = 0.3  ## "mount": board drops in front, the rider steps onto it
const WALK_LEG: float = 0.722  ## working leg length for the stride maths (the bones allow 0.73): legs nearly straight
## Heel-to-toe: shoe contact points in foot space (sole at -ANKLE_HEIGHT): heel behind the ankle, ball of the foot ahead.
const WALK_HEEL_Z: float = 0.08
const WALK_BALL_Z: float = -0.13
const WALK_HEEL_STRIKE: float = 14.0  ## degrees toe up as the front foot lands
const WALK_TOE_OFF: float = 24.0  ## degrees heel up as the back foot leaves
const CARRY_ROLL: float = 90.0  ## deck on edge: grip side toward the body
const CARRY_PITCH: float = 12.0  ## nose up
const CARRY_CENTER: Vector3 = Vector3(0.3, 0.72, -0.02)  ## where the deck's middle hangs, visual space

## The Skater. Typed Object and read with get(): naming the Skater class would make this script (and its unit test)
## depend on skater.gd compiling, which needs the Flags autoload. Fields read: anim, anim_time, crouch, balance,
## switch_stance, walker, tune, ragdoll_active, land_impact, speed, velocity, facing. Without a skater (title screen)
## the poser holds `preview_anim`.
var skater: Object
var body: Node3D
var board: Node3D
var preview_anim: String = "idle_ride"

var _nodes: Dictionary = {}  ## joint name -> Node3D
var _rest: Dictionary = {}  ## joint name -> Vector3 rest rotation (radians)
var _current: Dictionary = {}
var _has_pose: bool = false
var _preview_t: float = 0.0
var _air_t: float = 0.0  ## seconds the skater has been in the AIR state
var _tilt_s: float = 0.0  ## smoothed vert-air tilt weight 0..1
var _sketchy: bool = false  ## the last landing was sketchy (Skater.landed)
var _landed_hooked: bool = false
var _carve_s: float = 0.0  ## smoothed carve (-1..1) from the skater's turn rate
var _prev_facing: Vector3 = Vector3.ZERO
var _rag_joints: Dictionary = {}  ## joint name -> global Transform3D on the ragdoll's last frame
var _rag_board: Transform3D = Transform3D.IDENTITY
var _rag_pending: bool = false  ## a ragdoll just handed the body back: blend the get-up from its pose


func _process(delta: float) -> void:
	if body == null or board == null:
		return
	if _nodes.is_empty():
		_capture_rest()
	if skater != null and bool(skater.get("ragdoll_active")):
		_record_ragdoll()  # a bail ragdoll is driving the joints and the board; remember where it leaves them
		return
	var anim: String = preview_anim
	var t: float = 0.0
	var crouch: float = 0.0
	var bal: float = 0.0
	var switch: bool = false
	var speed: float = 0.0
	var phase: float = 0.0
	var ctx: Dictionary = {}
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
		ctx = _skater_ctx(delta)
		# Off an edge or up a vert wall the anim can still be a ground one (push, crouch, land): the body is airborne, so
		# it gets the air pose (knees tucked, board under the feet) and its own air clock.
		if _in_air():
			_air_t += delta
			if GROUND_ANIMS.has(anim):
				anim = "air"
				t = _air_t
		else:
			_air_t = 0.0
	else:
		_preview_t += delta
		t = _preview_t
	var target: Dictionary = pose_for(anim, t, crouch, bal, switch, speed, phase, ctx)
	if not _has_pose or (_rag_pending and anim == "bail_getup"):
		_current = target  # straight after a ragdoll: the get-up blend below starts from the ragdoll's own pose
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
		var rate: float = BLEND_RATE
		if anim.begins_with("flip_") or anim == "ollie" or anim.begins_with("walk") or anim == "dismount":
			rate = BLEND_RATE_FAST
		elif anim == "land" and t < land_time(float(ctx.get("impact", LAND_IMPACT_DEFAULT))):
			rate = BLEND_RATE_LAND
		_current = _blend(_current, target, 1.0 - exp(-rate * delta))
	_apply(_current)
	if anim == "bail_getup" and not _rag_joints.is_empty():
		var w: float = 1.0 - _smooth(t / GETUP_BLEND)
		_rag_pending = false
		if w > 0.0:
			_blend_from_ragdoll(w)
		else:
			_rag_joints.clear()
	elif anim != "bail_getup":
		_rag_joints.clear()
		_rag_pending = false


## The pose context from the live skater: landing impact, riding speed, vertical speed and the carve, a smoothed
## sideways acceleration (speed times turn rate) mapped to -1..1 (+ turning toward visual +X).
func _skater_ctx(delta: float) -> Dictionary:
	var ctx: Dictionary = {}
	ctx["impact"] = float(skater.get("land_impact"))
	var spd: float = float(skater.get("speed"))
	ctx["ride_speed"] = spd
	var v: Variant = skater.get("velocity")
	ctx["vy"] = (v as Vector3).y if v is Vector3 else 0.0
	var f: Variant = skater.get("facing")
	var raw: float = 0.0
	if f is Vector3:
		var fh: Vector3 = Vector3((f as Vector3).x, 0.0, (f as Vector3).z)
		if fh.length() > 0.01 and _prev_facing.length() > 0.01 and delta > 0.0:
			var turn: float = _prev_facing.signed_angle_to(fh.normalized(), Vector3.UP) / delta  ## rad/s, + = left
			raw = clampf(-turn * spd / CARVE_ACCEL, -1.0, 1.0)
		_prev_facing = fh.normalized() if fh.length() > 0.01 else _prev_facing
	_carve_s = lerpf(_carve_s, raw, 1.0 - exp(-6.0 * delta))
	ctx["carve"] = _carve_s
	ctx["vrm"] = body is VrmBody
	# Vert air: the weight of the tilt (see _vert_tilt) eases in and out; up_local is world up in the visual's space.
	var airy: bool = bool(skater.get("vert_air")) and _in_air()
	var goal: float = 1.0 if airy else 0.0
	_tilt_s = move_toward(_tilt_s, goal, delta * (6.0 if airy else 14.0))
	ctx["tilt_w"] = _tilt_s
	var parent: Node3D = body.get_parent() as Node3D
	ctx["up_local"] = (parent.global_basis.inverse() * Vector3.UP) if parent != null else Vector3.UP
	# A landing caught late (Skater.landed "sketchy") staggers for a moment.
	if skater.has_signal("landed") and not _landed_hooked:
		_landed_hooked = true
		skater.connect("landed", _on_landed)
	if str(skater.get("anim")) != "land":
		_sketchy = false
	ctx["sketchy"] = 1.0 if _sketchy else 0.0
	return ctx


## True while the skater's state machine is in AIR (the anim name can lag behind, see _process).
func _in_air() -> bool:
	var st: Object = skater.get("state") as Object
	return st != null and st.has_method("state_name") and str(st.call("state_name")) == "AIR"


func _on_landed(result: String) -> void:
	_sketchy = result == "sketchy"


## Remembers the ragdoll-driven joints and board (world space) each frame, so the get-up can start from them.
func _record_ragdoll() -> void:
	for j: String in JOINTS:
		var n: Node3D = _nodes[j]
		_rag_joints[j] = n.global_transform
	_rag_board = board.global_transform
	_rag_pending = true


## Pulls the posed joints (rotations; the hips also by position) and the board back toward where the ragdoll left
## them, by w (1 = exactly the ragdoll pose). Targets are all read first, then written parents first.
func _blend_from_ragdoll(w: float) -> void:
	var want: Dictionary = {}
	for j: String in JOINTS:
		var n: Node3D = _nodes[j]
		var rag: Transform3D = _rag_joints.get(j, n.global_transform)
		var q: Quaternion = n.global_basis.get_rotation_quaternion().slerp(rag.basis.get_rotation_quaternion(), w)
		want[j] = Transform3D(Basis(q), n.global_position.lerp(rag.origin, w))
	for j: String in JOINTS:
		var n: Node3D = _nodes[j]
		var x: Transform3D = want[j]
		if j == "Hips":
			n.global_transform = x
		else:
			n.global_basis = x.basis
	# The board comes back to the feet quicker than the body stands; one that flew off far just appears under them
	# (a board sliding metres back across the ground reads worse than the pop).
	if board.global_position.distance_to(_rag_board.origin) > GETUP_BOARD_REACH:
		return
	var wb: float = w * w * w
	var bq: Quaternion = board.global_basis.get_rotation_quaternion().slerp(_rag_board.basis.get_rotation_quaternion(), wb)
	board.global_transform = Transform3D(Basis(bq), board.global_position.lerp(_rag_board.origin, wb))


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
	var tilt: Vector3 = pose["tilt"]
	var tr: Basis = Basis(tilt.normalized(), deg_to_rad(tilt.length())) if tilt.length() > 0.01 else Basis.IDENTITY
	var tilt_xf: Transform3D = Transform3D(tr, TILT_PIVOT - tr * TILT_PIVOT)  ## turns everything about the hips
	board.transform = tilt_xf * Transform3D(board_basis, pose["board_pos"])

	var b: Basis = Basis(Vector3.RIGHT, deg_to_rad(-float(pose["pitch"]))) \
			* Basis(Vector3.BACK, deg_to_rad(-float(pose["lean"]))) \
			* Basis(Vector3.UP, deg_to_rad(float(pose["body_yaw"]) - 90.0))
	body.transform = tilt_xf * Transform3D(b, Vector3(0.0, PlaceholderSkater.DECK_TOP_Y + float(pose["lift"]), 0.0))
	for j: String in JOINTS:
		var node: Node3D = _nodes[j]
		if j == "Hips":
			node.position = Vector3(0.0, PlaceholderSkater.HIP_HEIGHT + float(pose["hips_y"]), 0.0)
		node.rotation = (_rest[j] as Vector3) + (pose[j] as Vector3) * (PI / 180.0)

	var parent: Node3D = body.get_parent() as Node3D
	var space: Transform3D = parent.global_transform if parent != null else Transform3D.IDENTITY
	var space_q: Quaternion = space.basis.get_rotation_quaternion() * tr.get_rotation_quaternion()
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
		var target: Vector3 = space * (tilt_xf * (pose["foot_" + s] as Vector3))
		if free > 0.0:
			var hang: Vector3 = body.global_transform * Vector3((-1.0 if side == "Left" else 1.0) * 0.13,
					PlaceholderSkater.HIP_HEIGHT + float(pose["hips_y"]) - 0.88 * (PlaceholderSkater.UPPER_LEG + PlaceholderSkater.LOWER_LEG), -0.08)
			target = target.lerp(hang, free)
		var toe: float = feet_yaw + deg_to_rad(float(pose["toe_" + s]) - 90.0)
		var foot_basis: Basis = Basis(space_q.slerp(board_q, flat)) * Basis(Vector3.UP, toe) \
				* Basis(Vector3.RIGHT, deg_to_rad(float(pose.get("fpitch_" + s, 0.0))))
		_solve_leg(side, target, facing + out * 0.35, foot_basis)
	for side: String in ["Left", "Right"]:
		var s: String = side.left(1)
		var w: float = float(pose["grip_" + s])
		if w > 0.01:
			_solve_arm(side, space * (tilt_xf * (pose["hand_" + s] as Vector3)), w, facing)


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
		speed: float = 0.0, phase: float = 0.0, ctx: Dictionary = {}) -> Dictionary:
	var pose: Dictionary = _blank()
	var c: float = clampf(crouch, 0.0, 1.0)
	var b: float = clampf(balance, -1.0, 1.0)
	var yaw: float = stance_yaw(anim, switch)
	pose["body_yaw"] = yaw
	pose["feet_yaw"] = yaw
	var impact: float = clampf(float(ctx.get("impact", LAND_IMPACT_DEFAULT)), 0.0, 1.0)
	var ride_speed: float = float(ctx.get("ride_speed", 99.0))
	var ext: float = air_extend(float(ctx.get("vy", 0.0)))
	var carve: float = clampf(float(ctx.get("carve", 0.0)), -1.0, 1.0)
	if CARVE_ANIMS.has(anim) and absf(carve) > 0.001:
		_board_turn(pose, Vector3(0.0, 0.0, -CARVE_ROLL * carve), Vector3.ZERO)  ## deck rolls into the turn
	if anim.begins_with("flip_"):
		_pose_flip(pose, anim, t, ext)
	elif anim.begins_with("grab_"):
		_pose_grab(pose, anim, t)
	elif anim.begins_with("grind_"):
		_pose_grind(pose, anim, t, maxf(c, 0.55), b, GRIND_STALL_VRM if bool(ctx.get("vrm", false)) else GRIND_STALL)
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
				_pose_crouch(pose, c, t)
			"ollie":
				_pose_ollie(pose, t, ext)
			"air":
				_pose_air(pose, t, ext, float(ctx.get("vy", 0.0)))
			"land":
				_pose_land(pose, t, c, impact, float(ctx.get("sketchy", 0.0)))
				var after: float = t - land_time(impact)
				if after > 0.0:
					_idle_life(pose, after, ride_speed)
			"idle_ride":
				_pose_idle(pose, c)
				_idle_life(pose, t, ride_speed)
			"nollie":
				_pose_nollie(pose, t, ext)
			"powerslide":
				_pose_powerslide(pose, t, c)
			"revert":
				_pose_revert(pose, t)
			"drop_in":
				_pose_drop_in(pose, t)
			"bail_fall":
				_pose_bail_fall(pose, t)
			"bail_getup":
				_pose_getup(pose, t)
			"wallride":
				_pose_wallride(pose, t)
			"wallplant":
				_pose_wallplant(pose, t)
			"boneless":
				_pose_boneless(pose, t)
			"no_comply":
				_pose_no_comply(pose, t)
			"caveman":
				_pose_caveman(pose, t, speed, phase)
			"acid_drop":
				_pose_acid_drop(pose, t, ext)
			_:
				_pose_idle(pose, c)
	if CARVE_ANIMS.has(anim):
		_carve(pose, carve)
	_look(pose)
	_vert_tilt(pose, ctx, ext)
	return pose


## Vert air (ctx "tilt_w" 0..1 ramps in and out as the skater enters and leaves vert air, "up_local" = world up in visual
## space): the visual lies with the ramp, which left the rider reclining or upside down over the coping. The whole rider and
## board turn about the hips toward world up (TILT_VERT of the way), so the body stays readable the THUG way and still
## leans with the wall. The turn fades out as the legs reach for the landing (the board is aligning to the ramp then).
static func _vert_tilt(pose: Dictionary, ctx: Dictionary, ext: float) -> void:
	var w: float = clampf(float(ctx.get("tilt_w", 0.0)), 0.0, 1.0) * TILT_VERT * (1.0 - ext)
	if w <= 0.001:
		return
	var up: Vector3 = ctx.get("up_local", Vector3.UP)
	var axis: Vector3 = Vector3.UP.cross(up)
	if axis.length() < 0.0001:
		return
	pose["tilt"] = axis.normalized() * rad_to_deg(Vector3.UP.angle_to(up)) * w


## How far the legs reach down for the landing (0 tucked, 1 extended) from the vertical speed: rising and at the apex
## the knees stay tucked, falling faster than 2 m/s the legs start reaching for the ground.
static func air_extend(vy: float) -> float:
	return clampf((-vy - 2.0) / 4.0, 0.0, 1.0)


## Seconds a landing at this impact takes to compress and spring back.
static func land_time(impact: float) -> float:
	return LAND_TIME_MIN + LAND_TIME_PER_IMPACT * clampf(impact, 0.0, 1.0)


## Crouch-equivalent knee bend of the landing absorb at time t: a compression (sine in, LAND_HIT of the landing), the
## knees held at the bottom a moment on a hard landing (the weight settling), then a spring back up with a small
## overshoot, exactly 0 after land_time(). Deeper and longer for harder impacts.
static func land_absorb(t: float, impact: float) -> float:
	var im: float = clampf(impact, 0.0, 1.0)
	var u: float = t / land_time(im)
	if u <= 0.0 or u >= 1.0:
		return 0.0
	var depth: float = clampf(LAND_DEPTH_MAX * pow(im, 1.3), 0.06, LAND_DEPTH_MAX)
	if u < LAND_HIT:
		return depth * sin(PI * 0.5 * u / LAND_HIT)
	var hold: float = LAND_HOLD * im * im
	if u < LAND_HIT + hold:
		return depth
	var s: float = (u - LAND_HIT - hold) / (1.0 - LAND_HIT - hold)
	return depth * ((1.0 - s) * (1.0 - s) * (1.0 + 2.0 * s) - 0.12 * sin(PI * s) * s)


## Lean into a carve: body roll toward the inside of the turn, shoulders and head leading round it, knees a little
## deeper; a heelside carve sits back with the arms reaching over the toes, a toeside one drives the knees in.
static func _carve(pose: Dictionary, carve: float) -> void:
	if absf(carve) < 0.001:
		return
	var toe_x: float = cos(deg_to_rad(float(pose["body_yaw"])))  ## +1 when the rider faces visual +X
	var heel: float = clampf(-carve * signf(toe_x), 0.0, 1.0)  ## share of a heelside carve
	pose["lean"] = float(pose["lean"]) + CARVE_LEAN * carve
	pose["hips_y"] = float(pose["hips_y"]) - 0.03 * absf(carve) - 0.03 * heel
	pose["Spine"] = (pose["Spine"] as Vector3) + Vector3(0.0, -6.0 * carve, 0.0)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(0.0, -10.0 * carve, 0.0)
	pose["Head"] = (pose["Head"] as Vector3) + Vector3(0.0, -10.0 * carve, 0.0)
	_curl(pose, 8.0 * heel)
	for side: Array in [["LeftUpperArm", -1.0], ["RightUpperArm", 1.0]]:
		pose[side[0]] = (pose[side[0]] as Vector3) + Vector3(25.0 * heel - 8.0 * absf(carve) * (1.0 - heel), 0.0,
				float(side[1]) * 10.0 * absf(carve))


## Idle life on top of a riding stance: breathing always; when stopped a slow cycle of habits (weight onto the back
## foot, a look round over the shoulders, re-setting the front foot, loosening the arms). Nothing in the first
## IDLE_DELAY seconds, so a short stop stays still. Pure function of t.
static func _idle_life(pose: Dictionary, t: float, ride_speed: float) -> void:
	var breathe: float = sin(t * 1.7)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(1.2 * breathe, 0.0, 0.0)
	pose["Head"] = (pose["Head"] as Vector3) + Vector3(0.0, 4.0 * sin(t * 0.43) * minf(t, 1.0), 0.0)
	var still: float = 1.0 - clampf(ride_speed / IDLE_STILL_SPEED, 0.0, 1.0)
	if still <= 0.0 or t <= IDLE_DELAY:
		return
	var u: float = fposmod(t - IDLE_DELAY, IDLE_CYCLE)
	var shift: float = _window(u, 0.0, 3.4) * still
	var look: float = _window(u, 3.2, 6.6) * still
	var adjust: float = _window(u, 6.4, 8.0) * still
	var loose: float = _window(u, 7.8, 10.0) * still
	# Weight onto the back foot: the body sits back over the tail, the hip drops and the back knee bends.
	pose["pitch"] = float(pose["pitch"]) - 5.0 * shift
	pose["hips_y"] = float(pose["hips_y"]) - 0.025 * shift
	pose["Hips"] = (pose["Hips"] as Vector3) + Vector3(0.0, 0.0, 5.0 * shift)
	pose["Spine"] = (pose["Spine"] as Vector3) + Vector3(0.0, 0.0, -4.0 * shift)
	pose["LeftUpperArm"] = (pose["LeftUpperArm"] as Vector3) + Vector3(-6.0, 0.0, 6.0) * shift
	# A look round: over the back shoulder, then forward down the line.
	var sweep: float = sin(PI * clampf((u - 3.2) / 3.4, 0.0, 1.0) * 2.0)
	pose["Head"] = (pose["Head"] as Vector3) + Vector3(4.0 * look, -50.0 * sweep * look, 4.0 * sweep * look)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(0.0, -12.0 * sweep * look, 0.0)
	# Re-set the front foot: a small lift and a twist of the toes, then down again.
	var step: float = sin(PI * clampf((u - 6.4) / 1.6, 0.0, 1.0))
	pose["foot_L"] = (pose["foot_L"] as Vector3) + Vector3(0.0, 0.045 * step * adjust, 0.0)
	pose["toe_L"] = float(pose["toe_L"]) + 14.0 * step * adjust
	pose["Head"] = (pose["Head"] as Vector3) + Vector3(-12.0 * adjust, 0.0, 0.0)  ## glance down at the foot
	# Loosen the arms: a shake out and a shoulder roll.
	var shake: float = sin(t * 9.0) * loose
	pose["LeftUpperArm"] = (pose["LeftUpperArm"] as Vector3) + Vector3(12.0 * shake, 0.0, -6.0 * loose)
	pose["RightUpperArm"] = (pose["RightUpperArm"] as Vector3) + Vector3(-12.0 * shake, 0.0, 6.0 * loose)
	pose["LeftLowerArm"] = (pose["LeftLowerArm"] as Vector3) + Vector3(10.0 * loose, 0.0, 0.0)
	pose["RightLowerArm"] = (pose["RightLowerArm"] as Vector3) + Vector3(10.0 * loose, 0.0, 0.0)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(0.0, 0.0, 3.0 * sin(t * 2.2) * loose)


## 0 outside [a, b], 1 inside it, with 0.6 s smooth ramps at both ends.
static func _window(u: float, a: float, b: float) -> float:
	return _smooth((u - a) / 0.6) * (1.0 - _smooth((u - (b - 0.6)) / 0.6))


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
	pose["fpitch_L"] = 0.0
	pose["fpitch_R"] = 0.0
	pose["feet_on_board"] = 1.0
	pose["feet_free"] = 0.0
	pose["hand_L"] = Vector3.ZERO
	pose["hand_R"] = Vector3.ZERO
	pose["grip_L"] = 0.0
	pose["grip_R"] = 0.0
	pose["tilt"] = Vector3.ZERO  ## rotation vector (degrees) turning the whole rider and board in visual space about TILT_PIVOT
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


## A real push: hips and shoulders open toward the nose, the front foot pivots to point down the board over the front
## bolts and its knee bends to take the weight (the body tips forward so the hips sit over it). The back foot steps
## off to the toe side, plants beside the front truck with its toes forward, drives straight back past the tail,
## then swings forward low to plant again. The arms counter-swing (back arm forward as the push leg goes back).
static func _pose_push(pose: Dictionary, t: float, c: float) -> void:
	var ankle: Vector3 = Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0)
	var plant: Vector3 = PUSH_STEP + ankle
	var finish: Vector3 = PUSH_END + ankle
	var foot: Vector3
	var drive: float = 0.0  ## 0 foot planted forward, 1 at the end of the drive (hips lowest, arms widest)
	var settle: float = 1.0  ## 0 on the deck, 1 stepped off into the push stance (first step only)
	var fpitch: float = 0.0  ## push shoe pitch: flat on the plant, heel up into the toe-off, toe trailing on the return
	if t < _push_plant:
		var k: float = _smooth(t / _push_plant)
		var out: float = _smooth(minf(t / _push_plant * 1.6, 1.0))  ## out to the side first, then forward
		var from: Vector3 = deck_point(pose, BACK_FOOT + ankle)
		var to: Vector3 = ground_point(pose, plant)
		foot = Vector3(lerpf(from.x, to.x, out), lerpf(from.y, to.y, k), lerpf(from.z, to.z, k))
		foot += Vector3.UP * 0.08 * sin(PI * k)
		settle = k
	else:
		var u: float = fposmod(t - _push_plant, _push_cycle) / _push_cycle
		if u < _push_contact:
			drive = _smooth(u / _push_contact)
			foot = ground_point(pose, plant.lerp(finish, drive))
			# Heel rises through the last of the drive: the push ends on the ball of the foot.
			var toe_off: float = _smooth((u / _push_contact - 0.65) / 0.35)
			fpitch = -26.0 * toe_off
			foot += Vector3.UP * _roll_raise(fpitch)
		else:
			var k: float = _smooth((u - _push_contact) / (1.0 - _push_contact))
			drive = 1.0 - k
			# The foot comes forward low, the toe trailing near the ground before it swings through flat to plant.
			var arc: float = sin(PI * k) * _smooth(k / 0.3)
			fpitch = lerpf(-26.0, 0.0, _smooth(k / 0.7))
			foot = ground_point(pose, finish.lerp(plant, k) + Vector3(0.03 * arc, 0.07 * arc, 0.0))
			foot += Vector3.UP * _roll_raise(fpitch) * (1.0 - k)
	pose["body_yaw"] = float(pose["body_yaw"]) + PUSH_YAW * (0.4 + 0.6 * settle)
	pose["pitch"] = (PUSH_PITCH + 3.0 * drive) * settle
	pose["lean"] = 3.0 * settle
	pose["Hips"] = Vector3(PUSH_PITCH * 0.4 * settle, 0.0, 0.0)  ## pelvis tipped back so the chest stays up
	pose["hips_y"] = IDLE_HIPS - (0.085 + 0.09 * drive) * settle - 0.06 * c
	_curl(pose, 10.0 + 4.0 * drive)
	var swing: float = (2.0 * drive - 1.0) * settle
	# The shoulders counter-turn a little against the push leg; the head holds steady down the line.
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(0.0, 5.0 * swing, 0.0)
	pose["Head"] = Vector3(8.0 * settle, -5.0 * swing, 0.0)  ## chin up, eyes down the line
	pose["foot_L"] = deck_point(pose, PUSH_FRONT + ankle)
	pose["foot_R"] = foot
	pose["fpitch_R"] = fpitch * settle
	pose["toe_L"] = PUSH_FRONT_TOE
	pose["toe_R"] = PUSH_BACK_TOE
	_arms(pose, Vector3(-34.0 * swing, 0.0, -12.0), Vector3(34.0 * swing, 0.0, 12.0), 22.0 + 10.0 * absf(swing))


## Tail snaps down (board pitched nose up about the tail tip), then the board levels and rises into the tucked feet
## as the front foot slides up toward the nose.
static func _pose_ollie(pose: Dictionary, t: float, ext: float = 0.0) -> void:
	var pop: float = clampf(t / POP_TIME, 0.0, 1.0)
	var level: float = _smooth(clampf((t - POP_TIME) / (LEVEL_TIME - POP_TIME), 0.0, 1.0))
	var slide: float = _smooth((t - 0.01) / (LEVEL_TIME - 0.01))  ## front foot dragging up the grip
	var tuck: float = _smooth((t - POP_TIME * 0.5) / 0.2)  ## knees come up as the board rises
	var pitch: float = 26.0 * sin(PI * 0.5 * pop) * (1.0 - level)
	_board_turn(pose, Vector3(pitch, 0.0, 0.0), TAIL_TIP)
	pose["board_pos"] = (pose["board_pos"] as Vector3) + Vector3(0.0, 0.2 * tuck * (1.0 - 0.85 * ext), 0.0)
	# Out of the crouch the back leg snaps straight (hips up), then the knees tuck under the rising board.
	var coil: float = 1.0 - _smooth(pop)
	pose["hips_y"] = IDLE_HIPS - 0.16 * coil + 0.025 * sin(PI * pop) - 0.02 * tuck * (1.0 - ext)
	pose["pitch"] = -4.0 * coil
	_curl(pose, 12.0 + 14.0 * coil + 6.0 * tuck * (1.0 - ext))
	pose["Head"] = Vector3(-8.0 * tuck, 0.0, 0.0)  ## eyes on the board
	# Arms: loaded low and back in the crouch, thrown up and out with the pop, front arm leading.
	var up: float = _smooth(pop * 1.4) * (1.0 - 0.35 * ext)
	_arms(pose, Vector3(-14.0 * coil + 22.0 * up, 0.0, -18.0 - 34.0 * up),
			Vector3(18.0 * coil + 22.0 * up, 0.0, 18.0 + 52.0 * up), 22.0 + 3.0 * up)
	# The front foot slides up toward the nose (toe lifting as the side of the shoe drags the grip), then comes back
	# over the bolts to level the board; the back foot rides the tail through the snap.
	var front_z: float = -0.12 * slide * (1.0 - 0.45 * tuck)
	_feet_on_board(pose, Vector3(0.0, 0.0, front_z), Vector3(0.0, 0.0, 0.07 * (1.0 - level) * (1.0 - level)))
	pose["fpitch_L"] = 14.0 * sin(PI * slide)


## Nollie (anim "nollie"; the mirror of the ollie): the weight sits forward over the front foot, which snaps the nose
## down (board pitched tail up about the nose tip) while the back foot slides back off the bolts toward the tail, then
## the board levels and rises into the tucked feet. Hips low and shoulders over the front knee in the load.
static func _pose_nollie(pose: Dictionary, t: float, ext: float = 0.0) -> void:
	var pop: float = clampf(t / POP_TIME, 0.0, 1.0)
	var level: float = _smooth(clampf((t - POP_TIME) / (LEVEL_TIME - POP_TIME), 0.0, 1.0))
	var slide: float = _smooth((t - 0.01) / (LEVEL_TIME - 0.01))  ## back foot dragging toward the tail
	var tuck: float = _smooth((t - POP_TIME * 0.5) / 0.2)
	var pitch: float = -26.0 * sin(PI * 0.5 * pop) * (1.0 - level)
	_board_turn(pose, Vector3(pitch, 0.0, 0.0), NOSE_TIP)
	pose["board_pos"] = (pose["board_pos"] as Vector3) + Vector3(0.0, 0.2 * tuck * (1.0 - 0.85 * ext), 0.0)
	var coil: float = 1.0 - _smooth(pop)
	pose["hips_y"] = IDLE_HIPS - 0.17 * coil + 0.025 * sin(PI * pop) - 0.02 * tuck * (1.0 - ext)
	pose["pitch"] = 9.0 * coil + 3.0 * (1.0 - coil) * (1.0 - tuck)  ## the body tips forward over the nose
	pose["Hips"] = Vector3(6.0 * coil, 0.0, 0.0)
	_curl(pose, 16.0 + 18.0 * coil + 4.0 * tuck * (1.0 - ext))
	pose["Head"] = Vector3(6.0 * coil - 8.0 * tuck, 0.0, 0.0)  ## eyes down the line, then on the board
	var up: float = _smooth(pop * 1.4) * (1.0 - 0.35 * ext)
	_arms(pose, Vector3(14.0 * coil + 20.0 * up, 0.0, -18.0 - 40.0 * up),
			Vector3(-16.0 * coil + 20.0 * up, 0.0, 18.0 + 46.0 * up), 24.0)
	var back_z: float = 0.13 * slide * (1.0 - 0.5 * tuck)
	_feet_on_board(pose, Vector3(0.0, 0.0, -0.04 * (1.0 - level)), Vector3(0.0, 0.0, back_z))
	pose["fpitch_R"] = 14.0 * sin(PI * slide)


## In the air (ctx "vy", t = seconds in the air anim): rising, the knees tuck and the board is pulled up under the feet
## with the front arm leading and the back arm out wide; at the apex the pose holds and the arms float; falling, the
## legs reach down, the board settles flat for the landing, the arms spread and the eyes pick out the spot.
static func _pose_air(pose: Dictionary, t: float, ext: float = 0.0, vy: float = 0.0) -> void:
	var rise: float = clampf(vy / 6.0, 0.0, 1.0)  ## 1 at the top of a pop, 0 from the apex on
	var tuck: float = (1.0 - ext) * (AIR_PULL_APEX / AIR_PULL_RISE + (1.0 - AIR_PULL_APEX / AIR_PULL_RISE) * rise)
	var settle: float = _smooth(t / 0.18)  ## the pull-up builds over the first moments (ollie hands the board over high)
	var pull: float = lerpf(AIR_PULL_LAND, AIR_PULL_RISE, tuck)
	# The nose lifts a little going up and dips toward the ground coming down.
	var pitch: float = 7.0 * rise - 9.0 * ext
	_board_turn(pose, Vector3(pitch, 0.0, 0.0), Vector3.ZERO)
	pose["board_pos"] = Vector3(0.0, pull, 0.0)
	pose["hips_y"] = IDLE_HIPS - 0.045 * tuck * settle + 0.015 * ext
	pose["pitch"] = -2.0 * rise + 3.0 * ext
	_curl(pose, 8.0 + 16.0 * tuck * settle)
	# Eyes forward going up, then down onto the landing; a slow float in the arms keeps the pose alive.
	pose["Head"] = Vector3(2.0 * rise - 12.0 * ext, 0.0, 0.0)
	var drift: float = sin(t * 3.4)
	var spread: float = 1.0 - 0.3 * ext
	_arms(pose,
			Vector3(-26.0 * tuck + 24.0 * ext + 4.0 * drift, 0.0, -48.0 * spread + 4.0 * drift),
			Vector3(18.0 * tuck - 22.0 * ext - 3.0 * drift, 0.0, 54.0 * spread - 4.0 * drift),
			22.0 + 14.0 * tuck)
	_feet_on_board(pose, Vector3(0.0, 0.0, -0.03 * tuck), Vector3(0.0, 0.0, 0.03 * tuck))
	pose["fpitch_L"] = 8.0 * tuck
	pose["fpitch_R"] = -6.0 * tuck


static func _pose_land(pose: Dictionary, t: float, c: float, impact: float = LAND_IMPACT_DEFAULT, sketchy: float = 0.0) -> void:
	var stagger: float = clampf(sketchy, 0.0, 1.0) * clampf(1.0 - t / SKETCHY_TIME, 0.0, 1.0)
	var a: float = land_absorb(t, impact)
	a = minf(a + 0.35 * stagger * (0.5 + 0.5 * sin(t * 18.0)), LAND_DEPTH_MAX)
	_pose_idle(pose, maxf(c, a))
	# Chest folds over the knees and the eyes drop to the board; the arms throw out to catch the balance, wider the
	# harder the hit, and come back in as the legs spring up.
	_curl(pose, 10.0 * a)
	pose["pitch"] = 3.0 * a
	pose["Head"] = Vector3(-10.0 * a, 0.0, 0.0)
	var arm: float = a * (0.6 + 0.6 * impact)
	_arms(pose, Vector3(10.0 + 22.0 * arm, 0.0, -8.0 - 42.0 * arm), Vector3(-6.0 - 16.0 * arm, 0.0, 8.0 + 46.0 * arm),
			14.0 + 22.0 * arm)
	# The weight arrives low: hips sink back over the tail a little and the arms drop through the compression.
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(-8.0 * a * impact, 0.0, 0.0)
	pose["LeftUpperArm"] = (pose["LeftUpperArm"] as Vector3) + Vector3(-18.0 * a * impact, 0.0, 10.0 * a * impact)
	pose["RightUpperArm"] = (pose["RightUpperArm"] as Vector3) + Vector3(-18.0 * a * impact, 0.0, -10.0 * a * impact)
	if stagger > 0.0:
		# Caught it late: the arms windmill to find the balance and the body wobbles side to side while it settles.
		var ph: float = t * 13.0
		pose["lean"] = float(pose["lean"]) + 18.0 * stagger * sin(ph * 0.8)
		pose["pitch"] = float(pose["pitch"]) + 6.0 * stagger * sin(ph * 0.55 + 1.0)
		pose["LeftUpperArm"] = (pose["LeftUpperArm"] as Vector3) + Vector3(92.0 * stagger * sin(ph), 0.0, -34.0 * stagger)
		pose["RightUpperArm"] = (pose["RightUpperArm"] as Vector3) + Vector3(92.0 * stagger * sin(ph + PI * 0.8), 0.0, 34.0 * stagger)
		pose["Head"] = (pose["Head"] as Vector3) + Vector3(0.0, 0.0, 6.0 * stagger * sin(ph * 0.8))


## Flip tricks. The feet leave the deck right after the flick, the board spins under them (eased: quick off the
## flick, slowing into the catch) and the feet come back down onto it at CATCH.
static func _pose_flip(pose: Dictionary, anim: String, t: float, ext: float = 0.0) -> void:
	var dbl: bool = anim.contains("double")
	var dur: float = DOUBLE_FLIP_TIME if dbl else FLIP_TIME
	var p: float = clampf(t / dur, 0.0, 1.0)
	var rise: float = 0.18 * sin(PI * minf(p * 1.2, 1.0)) + 0.06 * p * (1.0 - 0.8 * ext)
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
	var kick: float = sin(PI * clampf(p / 0.45, 0.0, 1.0))
	var k: Dictionary = flick(anim)
	var front: Vector3 = (k["front"] as Vector3) * kick
	var back: Vector3 = (k["back"] as Vector3) * kick
	var ankle: Vector3 = Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0)
	var level: Dictionary = pose.duplicate()
	level["board_rot"] = Vector3.ZERO
	level["board_pos"] = Vector3(0.0, rise, 0.0)
	pose["foot_L"] = deck_point(level, FRONT_FOOT + front + ankle + Vector3.UP * off)
	pose["foot_R"] = deck_point(level, BACK_FOOT + back + ankle + Vector3.UP * off)
	pose["toe_L"] = FRONT_TOE + float(k["toe"]) * kick  ## heelflips lead with the heel, kickflips with the toe
	pose["fpitch_L"] = float(k["pitch"]) * kick
	pose["feet_on_board"] = 0.0 if (p > 0.05 and p < CATCH + 0.1) else 1.0
	# The catch: both feet stomp back on and the knees give, then the legs reach for the ground.
	var stomp: float = sin(PI * clampf((p - CATCH) / (1.0 - CATCH), 0.0, 1.0)) if p > CATCH else 0.0
	pose["hips_y"] = IDLE_HIPS - 0.02 - 0.05 * stomp
	_curl(pose, 18.0 + 6.0 * kick + 6.0 * stomp - 4.0 * ext)
	pose["Head"] = Vector3(-14.0 * (1.0 - 0.5 * ext), 0.0, 0.0)  ## watching the board turn under the feet
	# Arms rise with the flick (front arm forward over the kicking foot), open out wide for the catch.
	_arms(pose, Vector3(-10.0 + 30.0 * kick, 0.0, -42.0 - 14.0 * kick), Vector3(18.0 - 10.0 * kick, 0.0, 48.0 + 10.0 * stomp),
			26.0 + 14.0 * kick)


## The feet of a flip trick (stance frame, metres at the peak of the flick): the front foot's flick ("front": a
## kickflip flicks out over the toe-side edge by the nose, a heelflip kicks forward off the nose heel first, a
## shove-it just lifts) and the back foot's scoop ("back": toward the heel side for a backside shove, the toe side for
## frontside ones, wrapping under for an impossible), the front shoe's extra yaw ("toe", degrees) and pitch ("pitch").
static func flick(anim: String) -> Dictionary:
	var front: Vector3 = Vector3(0.13, 0.0, -0.08)  ## kickflip
	var toe: float = 0.0
	var pitch: float = 0.0
	var back: Vector3 = Vector3.ZERO
	var heel: bool = anim.contains("heelflip") or anim.contains("laser")
	if heel:
		front = Vector3(0.04, 0.02, -0.17)
		toe = 30.0
		pitch = 18.0
	elif anim.contains("impossible"):
		front = Vector3(0.03, 0.06, -0.04)  ## front foot gets out of the way
		back = Vector3(0.0, -0.04, 0.08)  ## back foot scoops the tail round under
	elif anim.contains("shove") and not anim.contains("varial"):
		front = Vector3(0.02, 0.05, -0.02)
	elif anim.contains("hardflip"):
		front = Vector3(0.06, -0.02, -0.14)  ## front foot kicks forward and down
		pitch = -12.0
	var spin: Vector3 = _board_spin(anim, FLIP_TIME * 0.3)
	if absf(spin.y) > 0.5:
		back = Vector3(-0.07 if spin.y > 0.0 else 0.07, 0.0, 0.06)  ## backside scoops to the heel side
	return {"front": front, "back": back, "toe": toe, "pitch": pitch}


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
	var g: Dictionary = grab_shape(anim)
	var hand: String = str(g["hand"])
	var spot: Vector3 = g["spot"]
	var front: Vector3 = g["front"]
	var back: Vector3 = g["back"]
	# Lean the whole body toward the grabbed spot so the arm reaches it; each grab adds its own body shape.
	var sway: float = cos(deg_to_rad(float(pose["feet_yaw"])))
	pose["lean"] = float(g["lean"]) * sway * k
	pose["pitch"] = float(g["pitch"]) * k
	_board_turn(pose, (g["tweak"] as Vector3) * k, DECK_CENTER)
	pose["board_pos"] = (pose["board_pos"] as Vector3) + Vector3(0.0, GRAB_RISE * k, 0.0)
	pose["lift"] = GRAB_LIFT * k
	_curl(pose, float(g["curl"]) * k)
	pose["Spine"] = (pose["Spine"] as Vector3) + (g["spine"] as Vector3) * k
	pose["Chest"] = (pose["Chest"] as Vector3) + (g["chest"] as Vector3) * k
	pose["Head"] = (pose["Head"] as Vector3) + (g["head"] as Vector3) * k
	_feet_on_board(pose, front * k, back * k)
	if front != Vector3.ZERO or back.y < -0.1:
		pose["feet_on_board"] = 0.0
	pose["hand_" + hand] = deck_point(pose, spot + Vector3(0.0, 0.01, 0.0))
	pose["grip_" + hand] = k
	# The free arm styles the grab: thrown out and up for balance, its own way per grab.
	var free: Vector3 = (g["free"] as Vector3) * k
	if hand == "L":
		_arms(pose, Vector3.ZERO, free, 20.0 + 15.0 * k)
	else:
		_arms(pose, Vector3(free.x, -free.y, -free.z), Vector3.ZERO, 20.0 + 15.0 * k)


## The body shape of a grab: grabbing hand ("L" front, "R" back) and the board spot it holds (stance frame), the
## board tweak (degrees), feet offsets, body lean/pitch (degrees), spine curl and extra spine/chest/head rotation, and
## the free arm (as the right arm's offsets; mirrored for a free left arm).
## Indy: back hand on the toe edge between the feet, knees tucked up, front arm out. Mute: front hand on the toe
## edge. Melon: front hand on the heel edge, the body leaning back over it, back arm up. Method: melon grip with the
## board pulled up behind (heel edge high), knees bent back and the chest arched, free arm reaching forward and up.
## Stalefish: back hand round behind the back leg onto the heel edge. Nosegrab: front hand on the nose, front knee
## tucked, back leg straight. Tailgrab: back hand on the tail, back knee tucked, front leg straight. Benihana and
## airwalk throw a foot off the board.
static func grab_shape(anim: String) -> Dictionary:
	var g: Dictionary = {
		"hand": "L", "spot": Vector3(-EDGE, 0.0, -0.09), "tweak": Vector3(0.0, 0.0, -1.8 * GRAB_ROLL),
		"front": Vector3.ZERO, "back": Vector3.ZERO, "lean": -22.0, "pitch": 0.0, "curl": GRAB_CURL * 0.55,
		"spine": Vector3(-20.0, 0.0, 12.0), "chest": Vector3(-6.0, 0.0, 6.0), "head": Vector3(-6.0, 0.0, 0.0),
		"free": Vector3(-35.0, 0.0, 95.0),
	}  ## melon
	if anim.contains("indy"):
		g.merge({"hand": "R", "spot": Vector3(EDGE, 0.0, 0.02), "tweak": Vector3(0.0, 0.0, GRAB_ROLL), "lean": 0.0,
				"curl": GRAB_CURL * 1.15, "spine": Vector3.ZERO, "chest": Vector3(6.0, 0.0, 0.0),
				"head": Vector3(10.0, 0.0, 0.0), "free": Vector3(-25.0, 0.0, 95.0),
				"back": Vector3(0.0, 0.02, 0.0)}, true)
	elif anim.contains("mute"):
		g.merge({"spot": Vector3(EDGE, 0.0, -0.03), "tweak": Vector3(0.0, 0.0, GRAB_ROLL), "lean": 0.0,
				"curl": GRAB_CURL * 1.0, "spine": Vector3(0.0, 0.0, -6.0), "chest": Vector3.ZERO,
				"head": Vector3(8.0, 0.0, 0.0), "free": Vector3(-40.0, 0.0, 90.0)}, true)
	elif anim.contains("stalefish"):
		g.merge({"hand": "R", "spot": Vector3(-EDGE, 0.0, 0.1), "lean": -24.0, "curl": GRAB_CURL * 0.5,
				"chest": Vector3(-6.0, -10.0, 6.0), "free": Vector3(20.0, 0.0, 85.0),
				"front": Vector3(0.0, 0.0, -0.04)}, true)
	elif anim.contains("method"):
		g.merge({"spot": Vector3(-EDGE, 0.0, -0.08), "tweak": Vector3(0.0, 0.0, -2.0 * GRAB_ROLL), "lean": -25.0,
				"back": Vector3(-0.12, 0.08, 0.03), "curl": GRAB_CURL * 0.3,
				"spine": Vector3(-14.0, 0.0, 14.0), "chest": Vector3(8.0, 0.0, 6.0), "head": Vector3(12.0, 0.0, 0.0),
				"free": Vector3(45.0, 0.0, 120.0)}, true)
	elif anim.contains("nosegrab"):
		g.merge({"spot": Vector3(0.0, 0.0, -0.36), "tweak": Vector3(18.0, 0.0, 0.0), "lean": 0.0, "pitch": 16.0,
				"curl": GRAB_CURL * 0.6, "spine": Vector3.ZERO, "chest": Vector3.ZERO, "head": Vector3(4.0, 0.0, 0.0),
				"back": Vector3(0.0, 0.0, 0.03), "free": Vector3(-50.0, 0.0, 75.0)}, true)
	elif anim.contains("tailgrab") or anim.contains("benihana"):
		g.merge({"hand": "R", "spot": Vector3(0.0, 0.0, 0.37), "tweak": Vector3(-18.0, 0.0, 0.0), "lean": 0.0,
				"pitch": -16.0, "curl": GRAB_CURL * 0.6, "spine": Vector3.ZERO, "chest": Vector3.ZERO,
				"head": Vector3(4.0, 0.0, 0.0), "free": Vector3(-30.0, 0.0, 80.0)}, true)
		if anim.contains("benihana"):
			g["back"] = Vector3(0.05, -0.32, 0.12)  ## back foot kicked off and down
	elif anim.contains("airwalk"):
		g.merge({"spot": Vector3(0.0, 0.0, -0.36), "tweak": Vector3(18.0, 0.0, 0.0), "lean": 0.0, "pitch": 16.0,
				"curl": GRAB_CURL * 0.5, "spine": Vector3.ZERO, "chest": Vector3.ZERO,
				"front": Vector3(0.22, 0.05, -0.18), "back": Vector3(-0.15, 0.0, 0.12),
				"free": Vector3(-60.0, 0.0, 70.0)}, true)
	return g


static func _pose_revert(pose: Dictionary, t: float) -> void:
	var k: float = _smooth(t / REVERT_TIME)
	var mid: float = sin(PI * k)
	var yaw: float = 180.0 * k
	_pose_idle(pose, 0.4 + 0.3 * mid)
	pose["body_yaw"] = float(pose["body_yaw"]) + yaw
	pose["feet_yaw"] = float(pose["feet_yaw"]) + yaw
	# The head and shoulders lead the turn and the arms swing out with it; the board turns with the rider and, being
	# symmetric, ends where it started.
	pose["Head"] = Vector3(0.0, 25.0 * mid, 0.0)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(0.0, 12.0 * mid, 0.0)
	_arms(pose, Vector3(15.0 * mid, 0.0, -14.0 - 40.0 * mid), Vector3(-10.0 * mid, 0.0, 14.0 + 40.0 * mid), 20.0)
	_board_turn(pose, Vector3(0.0, yaw - 180.0, 0.0), Vector3.ZERO)
	_feet_on_board(pose)


## Drop-in: stand on the tail with the rear wheels on the coping (weight back over the deck, front foot hovering over
## the bolts, arms out for balance), the front foot stomps the nose down and the weight goes forward over it, then ride
## the wall down in a forward-leaning crouch (knees bent, chest over the front foot) ready for the bottom.
static func _pose_drop_in(pose: Dictionary, t: float) -> void:
	var lift: float = _smooth(t / (RampSnap.HANG_TIME * 0.4))  ## the nose comes up as the weight rocks back
	var s: float = _smooth((t - RampSnap.HANG_TIME) / RampSnap.STOMP_TIME)
	var settle: float = _smooth((t - RampSnap.HANG_TIME - RampSnap.STOMP_TIME) / DROP_SETTLE_TIME)
	var sway: float = 3.0 * sin(t * 9.0) * lift * (1.0 - s)  ## a little balance wobble on the coping
	_board_turn(pose, Vector3(lerpf(DROP_HANG_PITCH * lift, DROP_STOMP_PITCH, s) * (1.0 - settle), 0.0, 0.0), REAR_TRUCK)
	pose["hips_y"] = IDLE_HIPS - 0.04 * lift - 0.12 * s - 0.04 * settle
	pose["pitch"] = lerpf(-8.0 * lift, 16.0, s) * (1.0 - 0.45 * settle)
	pose["lean"] = sway
	_curl(pose, 8.0 + 4.0 * lift + 14.0 * s + 4.0 * settle)
	_arms(pose, Vector3(-25.0 * lift + 35.0 * s, 0.0, -50.0 * lift + 22.0 * s), Vector3(25.0 * lift - 35.0 * s, 0.0, 50.0 * lift - 22.0 * s), 25.0)
	var ankle: Vector3 = Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0)
	pose["foot_R"] = deck_point(pose, BACK_FOOT + Vector3(0.0, 0.0, 0.06 * (1.0 - settle)) + ankle)  ## on the tail
	pose["foot_L"] = deck_point(pose, FRONT_FOOT + ankle) + Vector3(0.0, 0.08 * lift * (1.0 - s), 0.0)


static func _pose_bail_fall(pose: Dictionary, t: float) -> void:
	var p: float = clampf(t / FALL_TIME, 0.0, 1.0)
	p = p * p
	_feet_on_board(pose)
	_arms(pose, Vector3(70.0 * sin(t * 12.0), 0.0, -60.0), Vector3(70.0 * sin(t * 12.0 + PI), 0.0, 60.0), 40.0)
	pose["lean"] = 80.0 * p
	pose["hips_y"] = IDLE_HIPS - 0.2 * p
	pose["feet_free"] = p


static func _pose_getup(pose: Dictionary, t: float) -> void:
	# Up from the ground: low on bent knees with the hands pushing off the thighs, then standing up into the stance.
	# After a ragdoll bail the poser also blends the joints from where the ragdoll left them (GETUP_BLEND).
	var d: float = SkateState.BAIL_TIME * 0.4  ## the rest of the bail after the fall
	var rest: float = 1.0 - _smooth(t / d)
	_pose_idle(pose, 1.0 * rest)
	pose["hips_y"] = float(pose["hips_y"]) - 0.06 * rest
	pose["pitch"] = 8.0 * rest
	_curl(pose, 20.0 * rest)
	pose["Head"] = Vector3(14.0 * rest, 0.0, 0.0)
	_arms(pose, Vector3(40.0 * rest, 0.0, -10.0 - 6.0 * (1.0 - rest)), Vector3(40.0 * rest, 0.0, 10.0 + 6.0 * (1.0 - rest)),
			20.0 + 25.0 * rest)
	# Without a ragdoll (sims, the bare fall) the body still comes up from the fall's sideways tip.
	pose["lean"] = 30.0 * rest * rest


static func _pose_grind(pose: Dictionary, anim: String, t: float, c: float, b: float, stall: float = GRIND_STALL) -> void:
	# Balance: the body leans with the meter, both arms tilt against it like a balance pole and flail when it is far
	# out, the hips shift the other way.
	var flail: float = 35.0 * absf(b) * sin(t * 10.0)
	var tilt: float = 28.0 * b
	_arms(pose, Vector3(flail + 10.0, 0.0, -42.0 + tilt), Vector3(-flail - 6.0, 0.0, 42.0 + tilt), 22.0)
	pose["lean"] = LEAN_MAX * b
	pose["Hips"] = Vector3(0.0, 0.0, -6.0 * b)
	var drop: float = 0.0  ## extra hip drop for the stalls on one truck
	var front: Vector3 = Vector3.ZERO
	var back: Vector3 = Vector3.ZERO
	match anim:
		"grind_five_oh":
			# Back truck on the rail, nose held up: weight over the back foot.
			_board_turn(pose, Vector3(stall, 0.0, 0.0), REAR_TRUCK)
			pose["pitch"] = -9.0
		"grind_nosegrind":
			# Front truck on the rail, tail up: weight over the front foot.
			_board_turn(pose, Vector3(-stall, 0.0, 0.0), FRONT_TRUCK)
			pose["pitch"] = 11.0
		"grind_crooked_grind":
			# Front truck, nose down and the board angled across with the nose's toe-side edge on the rail.
			_board_turn(pose, Vector3(-12.0, 16.0, 6.0), FRONT_TRUCK)
			pose["pitch"] = 11.0
			drop = 0.03
		"grind_smith_grind":
			# Back truck on the rail, the front truck dipped down past it: nose down and rolled.
			_board_turn(pose, Vector3(-12.0, 0.0, -22.0), REAR_TRUCK)
			pose["pitch"] = -6.0
			drop = 0.05
		"grind_feeble_grind":
			# Back truck on the rail, the front truck hanging over the far side.
			_board_turn(pose, Vector3(-9.0, 0.0, 22.0), REAR_TRUCK)
			pose["pitch"] = -6.0
			drop = 0.05
		"grind_boardslide", "grind_lipslide":
			# Board across the rail, body turned to face down it, knees soft and the weight centred.
			var turn: float = 90.0 if anim == "grind_boardslide" else -90.0
			pose["body_yaw"] = float(pose["body_yaw"]) + turn
			pose["feet_yaw"] = float(pose["feet_yaw"]) + turn
			_board_turn(pose, Vector3(0.0, float(pose["feet_yaw"]), 0.0), Vector3.ZERO)
			pose["pitch"] = -4.0
			_arms(pose, Vector3(25.0 + flail, 0.0, -42.0 + tilt), Vector3(25.0 - flail, 0.0, 42.0 + tilt), 38.0)
		"grind_blunt_slide":
			# Tail on the rail with the board stood up nose high, the rider sitting back on it.
			# Pivot under the back foot so the rider stays over the tail on the rail.
			_board_turn(pose, Vector3(GRIND_BLUNT, 0.0, 0.0), Vector3(0.0, 0.0, BACK_FOOT.z))
			pose["pitch"] = -10.0
			drop = 0.04
	pose["hips_y"] = IDLE_HIPS - CROUCH_DROP * c - drop
	_curl(pose, 12.0 + 14.0 * c)
	pose["Head"] = Vector3(-10.0, 0.0, 0.0)  ## eyes down the rail
	_feet_on_board(pose, front, back)


static func _pose_manual(pose: Dictionary, anim: String, t: float, c: float, b: float) -> void:
	var nose: bool = anim == "manual_nose_manual"
	var sgn: float = -1.0 if nose else 1.0
	# The balance meter drives everything: the board's pitch, the body over it, the arms counter-swinging fore and
	# aft (windmilling when it is far out) and a fast wobble in the board that grows near the limits.
	var wobble: float = 2.5 * absf(b) * absf(b) * sin(t * 13.0)
	var flail: float = 25.0 * sin(t * 8.0) * b
	var counter: float = 30.0 * b  ## arms reach toward the side the board tips away from
	_arms(pose, Vector3(flail - counter * sgn, 0.0, -50.0), Vector3(-flail - counter * sgn, 0.0, 50.0), 15.0)
	pose["pitch"] = -10.0 * sgn + 6.0 * b  ## weight back over the tail (forward over the nose)
	pose["Hips"] = Vector3(-8.0 * sgn + 5.0 * b, 0.0, 0.0)
	var pivot: Vector3 = Vector3(0.0, 0.0, -WHEEL_CONTACT_Z) if nose else Vector3(0.0, 0.0, WHEEL_CONTACT_Z)
	_board_turn(pose, Vector3(sgn * MANUAL_PITCH + 8.0 * b + wobble, 0.0, 0.0), pivot)
	pose["hips_y"] = IDLE_HIPS - CROUCH_DROP * c - 0.03 * absf(b)
	_curl(pose, 8.0 + 10.0 * c + 6.0 * absf(b))
	pose["Head"] = Vector3(-6.0 - 4.0 * absf(b), 0.0, 0.0)
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
	# Inverted pendulum: the hips ride an arc over the planted foot (highest as it passes under them, lowest at the
	# strike), the stance leg nearly straight with a soft knee; a run sinks a little more.
	var planted: float = 0.0  ## forward-back offset of the stance foot from the hips
	for off: float in [0.0, 0.5]:
		var u0: float = fposmod(phase + off, 1.0)
		if u0 < stance:
			planted = _foot_cycle(u0, half, stance, 0.0).x
	var leg: float = WALK_LEG * (0.985 - 0.03 * run_k * amp)
	var reach: float = sqrt(leg * leg - planted * planted)
	var bob: float = reach - leg  ## the arc's drop, for the board's carry bob
	var hips: float = PlaceholderSkater.ANKLE_HEIGHT + reach - PlaceholderSkater.HIP_HEIGHT
	var lean: float = (1.5 + 8.5 * run_k) * amp  ## an upright walk; a run leans into it
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
	for sd: Array in [["L", -0.09, 0.0], ["R", 0.09, 0.5]]:
		var u: float = fposmod(phase + float(sd[2]), 1.0)
		var f: Vector2 = _foot_cycle(u, half, stance, foot_lift)
		var pitch: float = _foot_roll(u, stance) * amp
		pose["fpitch_" + str(sd[0])] = pitch
		pose["foot_" + str(sd[0])] = Vector3(float(sd[1]), PlaceholderSkater.ANKLE_HEIGHT + f.y + _roll_raise(pitch), centre + f.x)
	# Upright: chest lifted and open (shoulders back), head up over the shoulders, the lean taken at the hips.
	_curl(pose, -3.0 + 9.0 * run_k)
	pose["Neck"] = Vector3(lean * 0.3 - 2.0, 0.0, 0.0)
	pose["Head"] = Vector3(lean * 0.5 + 4.0, 0.0, 0.0)
	# Hip sway: the pelvis turns with the forward leg and drops on the swing side; the chest counter-turns.
	var c: float = cos(2.0 * PI * phase)
	var sn: float = sin(2.0 * PI * phase)
	pose["Hips"] = Vector3(0.0, -6.0 * amp * c, -3.0 * amp * sn)
	pose["Spine"] = (pose["Spine"] as Vector3) + Vector3(0.0, 2.0 * amp * c, 2.0 * amp * sn)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(0.0, 4.0 * amp * c, 1.0 * amp * sn)
	var swing: float = (18.0 + 24.0 * run_k) * amp * -c  ## forward when the right foot is
	pose["LeftUpperArm"] = Vector3(swing, 0.0, -5.0)
	pose["LeftLowerArm"] = Vector3(10.0 + maxf(swing, 0.0) * 0.5 * (1.0 - run_k) + 40.0 * run_k * amp, 0.0, 0.0)
	pose["RightUpperArm"] = Vector3(0.0, 0.0, 6.0)
	pose["RightLowerArm"] = Vector3(30.0, 0.0, 0.0)
	_carry_board(pose, bob * 0.6, phase, amp)


## Heel-to-toe shoe pitch (degrees, + toe up) at cycle position u: toe up at heel strike, flat through mid-stance,
## heel rising to the toe-off, then swinging through back to toe up for the next strike.
static func _foot_roll(u: float, stance: float) -> float:
	if u < stance:
		var k: float = u / stance
		if k < 0.15:
			return lerpf(WALK_HEEL_STRIKE, 0.0, _smooth(k / 0.15))
		if k < 0.6:
			return 0.0
		return -WALK_TOE_OFF * _smooth((k - 0.6) / 0.4)
	var s: float = (u - stance) / (1.0 - stance)
	return lerpf(-WALK_TOE_OFF, WALK_HEEL_STRIKE, _smooth(s))


## How far the ankle rises so the lowest of the heel and the ball of a pitched shoe stays on the ground.
static func _roll_raise(pitch_deg: float) -> float:
	var a: float = deg_to_rad(pitch_deg)
	var h: float = PlaceholderSkater.ANKLE_HEIGHT
	var heel: float = -h * cos(a) - WALK_HEEL_Z * sin(a)
	var ball: float = -h * cos(a) - WALK_BALL_Z * sin(a)
	return maxf(0.0, -minf(heel, ball) - h)


## The board on edge under the right arm and the right hand on its top edge.
static func _carry_board(pose: Dictionary, bob: float, phase: float = 0.0, amp: float = 0.0) -> void:
	# The carried board swings a little with the stride, lagging the step (a pendulum under the hand).
	var sw: float = sin(TAU * phase - 0.6) * amp
	var rot: Vector3 = Vector3(CARRY_PITCH + 4.0 * sw, 3.0 * sw, CARRY_ROLL)
	var b: Basis = Basis.from_euler(rot * (PI / 180.0))
	var origin: Vector3 = CARRY_CENTER + Vector3(0.0, bob, 0.012 * sw) - b * Vector3(0.0, AnimeBoard.DECK_Y, 0.0)
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


## Crouching to pop: knees bend, the weight settles a little toward the tail and the arms load down and back.
static func _pose_crouch(pose: Dictionary, c: float, t: float) -> void:
	_pose_idle(pose, c)
	pose["pitch"] = -3.0 * c
	pose["Head"] = (pose["Head"] as Vector3) + Vector3(-6.0 * c, 0.0, 0.0)
	_arms(pose, Vector3(-14.0 * c, 0.0, -10.0 - 8.0 * c), Vector3(18.0 * c, 0.0, 10.0 + 8.0 * c), 18.0 + 12.0 * c)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(0.8 * sin(t * 1.7), 0.0, 0.0)


## Powerslide (anim "powerslide"): the board kicked a quarter turn across the line, the rider low and sitting back
## against the slide. The hips and feet stay with the board but the shoulders and head counter-rotate back down the
## line of travel, the downhill hand trails toward the ground and the other arm balances out the front.
static func _pose_powerslide(pose: Dictionary, t: float, c: float) -> void:
	var k: float = _smooth(t / 0.15)
	var turn: float = POWERSLIDE_YAW * k
	pose["body_yaw"] = float(pose["body_yaw"]) + turn * 0.78
	pose["feet_yaw"] = float(pose["feet_yaw"]) + turn
	_board_turn(pose, Vector3(0.0, turn, 0.0), Vector3.ZERO)
	pose["hips_y"] = IDLE_HIPS - CROUCH_DROP * maxf(c, 0.9 * k)
	pose["lean"] = -16.0 * k  ## sat back into the slide
	pose["pitch"] = -6.0 * k
	_curl(pose, 12.0 * k)
	pose["Hips"] = Vector3(-6.0 * k, 0.0, 0.0)
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(0.0, -26.0 * k, 0.0)  ## shoulders back toward the travel line
	pose["Head"] = Vector3(4.0, -34.0 * k, 0.0)  ## eyes on where the slide is going
	_arms(pose, Vector3(30.0, 0.0, -75.0 * k - 10.0), Vector3(-50.0 * k, 0.0, 22.0 + 12.0 * k), 18.0 * k + 8.0)
	_feet_on_board(pose, Vector3(0.0, 0.0, 0.02 * k), Vector3(0.0, 0.0, -0.02 * k))
	pose["Chest"] = (pose["Chest"] as Vector3) + Vector3(0.0, 0.0, 2.0 * sin(t * 30.0) * k)  ## chatter


## Wallride: knees bent, hips pressed in toward the wall, the wall-side arm reaching down toward it and the free arm
## thrown up and out, head up looking along the wall.
static func _pose_wallride(pose: Dictionary, t: float) -> void:
	_pose_idle(pose, 0.45)
	var k: float = _smooth(t / 0.15)
	pose["lean"] = 28.0 * k
	_curl(pose, 6.0 * k)
	pose["Head"] = Vector3(10.0 * k, 0.0, -10.0 * k)
	_arms(pose, Vector3(10.0, 0.0, -30.0 - 50.0 * k), Vector3(-20.0, 0.0, 30.0 + 70.0 * k), 25.0)


## A stance-frame point (x toward the chest, y up from the ground, z along the board, -Z the nose) in visual space,
## with the foot's ankle height added to y so the sole sits at that height.
static func _sole_point(pose: Dictionary, x: float, y: float, z: float) -> Vector3:
	return ground_point(pose, Vector3(x, PlaceholderSkater.ANKLE_HEIGHT + y, z))


## Wallplant (anim "wallplant", about 0.5 s): riding at the wall, the front foot comes off the board and
## plants flat on the wall (sole to the wall, toes up) with the knee folded and the body compressed in against it, the
## back foot holding the board under the tail; then the leg drives straight, the body extends off the wall and the
## foot drops back onto the board. The wall is ahead of the nose (-Z).
static func _pose_wallplant(pose: Dictionary, t: float) -> void:
	var load_k: float = _smooth(t / 0.12)  ## compress toward the wall
	var plant: float = _smooth((t - 0.08) / 0.07) * (1.0 - _smooth((t - 0.3) / 0.08))  ## front sole on the wall
	var drive: float = _smooth((t - 0.2) / 0.16)  ## leg straightens, body pushes off
	var back: float = _smooth((t - 0.3) / 0.12)  ## foot returns to the board
	var air: float = _smooth((t - 0.36) / 0.12)
	_board_turn(pose, Vector3(10.0 * plant * (1.0 - air), 0.0, 0.0), TAIL_TIP)
	pose["board_pos"] = (pose["board_pos"] as Vector3) + Vector3(0.0, 0.1 * load_k, 0.0)
	pose["hips_y"] = IDLE_HIPS - 0.2 * load_k * (1.0 - drive) + 0.05 * drive - 0.04 * air
	pose["lift"] = 0.12 * drive * (1.0 - air) + 0.06 * air
	pose["pitch"] = 26.0 * load_k * (1.0 - drive) - 10.0 * drive * (1.0 - air)
	pose["lean"] = 0.0
	_curl(pose, 18.0 * load_k * (1.0 - drive) + 8.0 * air)
	pose["Head"] = Vector3(-6.0 * load_k + 8.0 * drive * (1.0 - air), 0.0, 0.0)
	# The front arm braces toward the wall, the back arm swings out for balance, both throw wide as the body leaves.
	_arms(pose, Vector3(60.0 * load_k * (1.0 - drive) - 10.0 * drive, 0.0, -25.0 - 35.0 * drive),
			Vector3(-25.0 * load_k + 20.0 * drive, 0.0, 22.0 + 50.0 * drive), 22.0 + 20.0 * load_k * (1.0 - drive))
	var wall: Vector3 = _sole_point(pose, 0.0, 0.5, -0.56)
	var deck: Vector3 = deck_point(pose, FRONT_FOOT + Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0))
	var reach: Vector3 = deck.lerp(wall, _smooth(t / 0.12))
	pose["foot_L"] = reach.lerp(deck, back) + Vector3(0.0, 0.1 * sin(PI * minf(t / 0.12, 1.0)) * (1.0 - plant), 0.0)
	pose["fpitch_L"] = 78.0 * plant
	pose["foot_R"] = deck_point(pose, BACK_FOOT + Vector3(0.0, 0.0, 0.03 * plant) + Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0))
	pose["feet_on_board"] = 1.0 - 0.7 * plant


## Boneless (anim "boneless", about 0.65 s): the front foot steps off the board onto the ground ahead of it
## and takes the weight, the board lifts into the front hand (held on the toe edge) while the back leg trails, then
## the rider hops off the planted foot and the board comes back under both feet.
static func _pose_boneless(pose: Dictionary, t: float) -> void:
	var step: float = _smooth(t / 0.1) * (1.0 - _smooth((t - 0.42) / 0.1))  ## front foot on the ground
	var hold: float = _smooth((t - 0.06) / 0.14) * (1.0 - _smooth((t - 0.4) / 0.12))  ## board in the hand
	var hop: float = sin(PI * clampf((t - 0.32) / 0.28, 0.0, 1.0))
	_board_turn(pose, Vector3(-14.0 * hold, 0.0, -62.0 * hold), DECK_CENTER)
	pose["board_pos"] = (pose["board_pos"] as Vector3) + Vector3(0.42 * hold, 0.3 * hold, -0.12 * hold)
	pose["hips_y"] = IDLE_HIPS - 0.2 * step + 0.02 * hop
	pose["lift"] = 0.24 * hop
	pose["pitch"] = 16.0 * step * (1.0 - hop)
	pose["lean"] = -8.0 * step
	_curl(pose, 26.0 * step + 6.0 * hop)
	pose["Head"] = Vector3(-8.0 * step, 0.0, 0.0)
	var edge: Vector3 = Vector3(EDGE, 0.0, -0.1)
	pose["hand_L"] = deck_point(pose, edge + Vector3(0.0, 0.01, 0.0))
	pose["grip_L"] = hold
	_arms(pose, Vector3.ZERO, Vector3(-30.0 * step + 40.0 * hop, 0.0, 28.0 + 40.0 * step), 24.0)
	var ankle: Vector3 = Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0)
	var deck_l: Vector3 = deck_point(pose, FRONT_FOOT + ankle)
	var ground: Vector3 = _sole_point(pose, 0.3, 0.0, -0.32)
	pose["foot_L"] = deck_l.lerp(ground, step) + Vector3(0.0, 0.1 * sin(PI * clampf(t / 0.1, 0.0, 1.0)) * (1.0 - step), 0.0)
	pose["foot_L"] = (pose["foot_L"] as Vector3) + Vector3(0.0, 0.25 * hop, 0.0)
	var trail: Vector3 = _sole_point(pose, -0.06, 0.22, 0.34)
	pose["foot_R"] = deck_point(pose, BACK_FOOT + ankle).lerp(trail, hold) + Vector3(0.0, 0.2 * hop, 0.0)
	pose["fpitch_R"] = -28.0 * hold
	pose["feet_on_board"] = 1.0 - 0.9 * maxf(step, hold)
	pose["toe_L"] = lerpf(FRONT_TOE, 60.0, step)


## No comply (anim "no_comply", about 0.6 s): the front foot steps off over the nose onto the ground and takes
## the weight, the back foot pops the tail so the board flips up level in front of the rider, then the front foot
## hops back up and onto it.
static func _pose_no_comply(pose: Dictionary, t: float) -> void:
	var step: float = _smooth(t / 0.1) * (1.0 - _smooth((t - 0.36) / 0.1))
	var pop: float = _smooth((t - 0.1) / 0.06)
	var level: float = _smooth((t - 0.16) / 0.14)
	var rise: float = pop * (1.0 - _smooth((t - 0.42) / 0.12))
	var pitch: float = 32.0 * pop * (1.0 - level)
	_board_turn(pose, Vector3(pitch, 0.0, 0.0), TAIL_TIP)
	pose["board_pos"] = (pose["board_pos"] as Vector3) + Vector3(0.0, 0.26 * rise, -0.05 * rise)
	var snap: float = sin(PI * clampf((t - 0.08) / 0.14, 0.0, 1.0))
	pose["hips_y"] = IDLE_HIPS - 0.2 * step * (1.0 - pop) - 0.07 * step * pop + 0.02 * snap
	pose["pitch"] = 12.0 * step
	pose["lean"] = -6.0 * step
	_curl(pose, 16.0 * step + 8.0 * rise)
	pose["Head"] = Vector3(-10.0 * step, 0.0, 0.0)
	_arms(pose, Vector3(40.0 * step - 20.0 * snap, 0.0, -20.0 - 20.0 * step),
			Vector3(-20.0 * step + 25.0 * snap, 0.0, 22.0 + 50.0 * snap), 24.0)
	var ankle: Vector3 = Vector3(0.0, PlaceholderSkater.ANKLE_HEIGHT, 0.0)
	var deck_l: Vector3 = deck_point(pose, FRONT_FOOT + ankle)
	var ground: Vector3 = _sole_point(pose, 0.26, 0.0, -0.62)
	var onto: float = _smooth((t - 0.38) / 0.14)  ## back up onto the deck
	var foot: Vector3 = deck_l.lerp(ground, step)
	pose["foot_L"] = foot + Vector3(0.0, 0.12 * sin(PI * clampf(t / 0.1, 0.0, 1.0)) * (1.0 - step) + 0.1 * sin(PI * onto), 0.0)
	pose["foot_R"] = deck_point(pose, BACK_FOOT + Vector3(0.0, 0.0, 0.07 * (1.0 - level)) + ankle)
	pose["feet_on_board"] = 1.0 - 0.8 * step
	pose["toe_L"] = lerpf(FRONT_TOE, 70.0, step)


## Caveman (anim "caveman", about 0.55 s): a running jump with the board held up in the back hand, then thrown
## down ahead and landed on. The run eases into the ride stance as the board leaves the hand and drops under the feet.
static func _pose_caveman(pose: Dictionary, t: float, speed: float, phase: float) -> void:
	var run: Dictionary = _blank()
	_pose_walk(run, phase, maxf(speed, 4.5))
	_carry_board(run, 0.0, phase, 0.0)
	run["board_pos"] = (run["board_pos"] as Vector3) + Vector3(0.0, 0.3, 0.0)  ## held up high for the jump
	var jump: float = _smooth(t / 0.12)
	var throw: float = _smooth((t - 0.16) / 0.2)
	var land: Dictionary = _blank()
	_pose_air(land, 0.2, 0.7)
	_arms(land, Vector3(20.0, 0.0, -60.0), Vector3(-10.0, 0.0, 60.0), 20.0)
	var out: Dictionary = _blend(run, land, throw)
	var hump: float = sin(PI * clampf((t - 0.04) / 0.5, 0.0, 1.0))
	out["lift"] = lerpf(float(run["lift"]), 0.0, throw) + 0.3 * hump * (1.0 - throw * 0.5)
	out["board_pos"] = (out["board_pos"] as Vector3) + Vector3(0.0, 0.0, -0.3 * sin(PI * throw))
	out["grip_R"] = float(run["grip_R"]) * (1.0 - _smooth((t - 0.2) / 0.08))
	# Knees tucked up through the jump, then reaching for the board.
	for side: String in ["L", "R"]:
		out["foot_" + side] = (out["foot_" + side] as Vector3) + Vector3(0.0, 0.14 * jump * (1.0 - throw), 0.0)
	for key: String in out.keys():
		pose[key] = out[key]


## Acid drop (anim "acid_drop", about 0.55 s): off the lip of a drop, tucked small with the knees up and the
## arms forward, the board following the fall nose down then levelling out to meet the transition, and the knees
## taking the hit as it lands.
static func _pose_acid_drop(pose: Dictionary, t: float, ext: float = 0.0) -> void:
	var tuck: float = _smooth(t / 0.12) * (1.0 - 0.6 * _smooth((t - 0.2) / 0.2))
	var level: float = _smooth((t - 0.06) / 0.3)
	_board_turn(pose, Vector3(-16.0 * _smooth(t / 0.08) * (1.0 - level), 0.0, 0.0), DECK_CENTER)
	pose["board_pos"] = (pose["board_pos"] as Vector3) + Vector3(0.0, 0.16 * tuck * (1.0 - 0.8 * ext), 0.0)
	var absorb: float = land_absorb(maxf(t - 0.34, 0.0), 0.6) if t > 0.34 else 0.0
	pose["hips_y"] = IDLE_HIPS - 0.14 * tuck - CROUCH_DROP * absorb
	pose["pitch"] = 8.0 * tuck * (1.0 - level) + 3.0 * absorb
	_curl(pose, 20.0 * tuck + 12.0 * absorb)
	pose["Head"] = Vector3(-8.0 * tuck * (1.0 - level), 0.0, 0.0)
	_arms(pose, Vector3(35.0 * tuck + 10.0 * absorb, 0.0, -35.0 - 25.0 * absorb), Vector3(-5.0 * tuck, 0.0, 35.0 + 30.0 * absorb), 28.0)
	_feet_on_board(pose)


static func _board_turn(pose: Dictionary, euler_deg: Vector3, pivot: Vector3) -> void:
	var r: Basis = Basis.from_euler(euler_deg * (PI / 180.0))
	pose["board_rot"] = euler_deg
	pose["board_pos"] = pivot - r * pivot  ## keeps the pivot point fixed in place


static func _smooth(x: float) -> float:
	var p: float = clampf(x, 0.0, 1.0)
	return p * p * (3.0 - 2.0 * p)
