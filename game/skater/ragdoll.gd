class_name SkaterRagdoll
extends Node3D
## Physics ragdoll for a bail. spawn() snapshots the pose of a PlaceholderSkater body (and its board), builds
## RigidBody3D parts joined with limited joints, and then drives the ORIGINAL joint nodes and the board node from
## the rigid bodies each physics frame, so the existing meshes follow with no duplicates. finish() frees the
## physics and stops driving; the poser takes over again on the next frame.
## Parts live on collision layer 4 and only collide with the world (mask 1), never with the skater (layer 2) or
## each other. Total mass about 40 kg. Deterministic: the board spin comes from a seeded RNG.
##
## A bail plan (BailKind.classify) picks the fall: the style's spin in the rider's frame, the arm and leg fling
## (limb spin at spawn, so the body throws itself into the pose with no popped frame), a short guiding torque so the
## fall reads (faceplant, back slam, cartwheel...) and the board's kick. Its injuries are a visual override on the
## driven joints (BailInjury) that snaps in at the first hard impact and, once the body comes to rest, pops back
## before settled() reports true. Signals tell BailFx when to crunch and when to pop.

signal injured(points: Array)  ## world positions of the injured joints, at the first hard impact
signal repairing(points: Array)  ## the injured joints start snapping back (the body has settled)

const WORLD_MASK: int = 1
const RAGDOLL_LAYER: int = 4
const SETTLE_SPEED: float = 0.6
const SETTLE_HOLD: float = 0.4
const MAX_TIME: float = 2.5
const MAX_SPEED: float = 30.0
const MAX_SPIN: float = 8.0
const ELBOW_RANGE: Vector2 = Vector2(-0.05, 2.5)  ## flex about the limb's own X axis, forearm forward is positive
const KNEE_RANGE: Vector2 = Vector2(-2.5, 0.05)  ## shin swings backward (negative)
const INERTIA_SCALE: float = 1.5
const INERTIA_LENGTH: Dictionary = {"pelvis": 0.3, "torso": 0.4, "head": 0.3, "uarm": 0.3, "larm": 0.3, "thigh": 0.4, "shin": 0.4}
const BOARD_MASS: float = 2.5
const BOARD_CENTER_Y: float = 0.07
## The followed point never drops more than this below the pelvis: a body sliding down a steep bowl wall has the
## floor metres straight below it, and following that hit made the skater (and the camera) jump down there.
const GROUND_BELOW_MAX: float = 0.6
const GUIDE_TIME: float = 0.3  ## s the style's guiding torque acts
const FLING_TIME: float = 0.2  ## s the limbs take to swing into the style's pose
const IMPACT_DV: float = 2.2  ## m/s change in one tick of a core part: the slam
const ONSET_FALLBACK: float = 0.4  ## s: injuries show by now even if no single tick reads as the slam
## Limb fling per style pose, in the body frame (radians; x about the rider's right: + swings the limb forward,
## z about the rider's back axis: + swings a limb toward the rider's right side). Mirrored for the left limbs.
const ARM_POSES: Dictionary = {
	"reach": Vector3(1.25, 0.0, 0.2), "up": Vector3(2.4, 0.0, 0.5), "brace": Vector3(-0.9, 0.0, 0.3),
	"spread": Vector3(0.2, 0.0, 1.3),
}
const LEG_POSES: Dictionary = {
	"tuck": Vector3(0.9, 0.0, 0.0), "kneel": Vector3(0.35, 0.0, 0.0), "spread": Vector3(0.25, 0.0, 0.45),
}
const SHIN_FOLD: Dictionary = {"tuck": -1.2, "kneel": -1.7}  ## extra knee flex (rad) of the leg pose

## Joint nodes driven by each body, parents before children.
const DRIVEN: Array = [
	["Hips", "pelvis"], ["Spine", "torso"], ["Chest", "torso"], ["Neck", "torso"], ["Head", "head"],
	["LeftUpperArm", "l_uarm"], ["LeftLowerArm", "l_larm"], ["LeftHand", "l_larm"],
	["RightUpperArm", "r_uarm"], ["RightLowerArm", "r_larm"], ["RightHand", "r_larm"],
	["LeftUpperLeg", "l_thigh"], ["LeftLowerLeg", "l_shin"], ["LeftFoot", "l_shin"],
	["RightUpperLeg", "r_thigh"], ["RightLowerLeg", "r_shin"], ["RightFoot", "r_shin"],
]

var parts: Dictionary = {}  ## name -> RigidBody3D (includes "board" when a board was given)
var joints: Array[Joint3D] = []

var _driven: Array[Dictionary] = []  ## {node: Node3D, body: RigidBody3D, offset: Transform3D}
var _board: Node3D
var _board_local: Transform3D = Transform3D.IDENTITY
var _active: bool = true
var _time: float = 0.0
var _calm: float = 0.0
var _last_dir: Vector3 = Vector3(0.0, 0.0, -1.0)
var plan: Dictionary = {}  ## the BailKind plan this ragdoll plays ({} for a plain fall)
var _joints: Dictionary = {}  ## joint name -> Node3D of the body
var _guide: Vector3 = Vector3.ZERO  ## world torque per second on the torso while _time < GUIDE_TIME
var _prev_v: Dictionary = {}  ## core part -> last linear velocity
var _onset_t: float = -1.0  ## seconds since the injuries hit, -1 before
var _repair_t: float = -1.0  ## seconds since the repair began, -1 before


static func spawn(body: Node3D, board: Node3D, velocity: Vector3, angular_hint: Vector3, world: Node,
		bail_plan: Dictionary = {}) -> SkaterRagdoll:
	var r: SkaterRagdoll = SkaterRagdoll.new()
	r.name = "SkaterRagdoll"
	r.process_physics_priority = 100  # after the skater has moved, so the drive wins
	r.plan = bail_plan
	world.add_child(r)
	r.global_transform = Transform3D.IDENTITY
	var v: Vector3 = velocity.limit_length(MAX_SPEED)
	var spin: Vector3 = angular_hint.limit_length(MAX_SPIN)
	var style: Dictionary = BailKind.STYLES.get(str(bail_plan.get("style", "")), {})
	if not style.is_empty():
		# The styles are staged for a slam on open ground; on a steep wall (a vert or bowl bail) they fade out and the
		# fall is the plain momentum one, so the body slides down the transition instead of being thrown off it.
		var k: float = style_weight(float(bail_plan.get("ground_y", 1.0)))
		var fr: Basis = r._body_frame(body)
		var flat: Vector3 = Vector3(v.x, 0.0, v.z)
		v = flat * lerpf(1.0, float(style["keep"]), k) + Vector3(0.0, v.y, 0.0) + Vector3.UP * float(style["up"]) * k
		var styled: Vector3 = fr * ((style["spin"] as Vector3) * r._mirror())
		spin = spin.lerp(styled, k).limit_length(MAX_SPIN)
		r._guide = spin.normalized() * float(style["guide"]) * k if spin.length() > 0.01 else Vector3.ZERO
	r._build_body(body, v, spin)
	if not style.is_empty() and style_weight(float(bail_plan.get("ground_y", 1.0))) > 0.5:
		r._fling(style)
	if board != null:
		r._build_board(board, v, str(style.get("board", "forward")))
	var flat: Vector3 = Vector3(v.x, 0.0, v.z)
	if flat.length() > 0.1:
		r._last_dir = flat.normalized()
	r._drive()
	return r


## 0..1: how much of the fall style plays on ground whose normal has this y (full on flat or gentle ground, none on a
## steep wall).
static func style_weight(ground_y: float) -> float:
	return clampf((ground_y - 0.45) / 0.35, 0.0, 1.0)


## The BailKind context for a skater's bail: the cause it gave, filled in from the skater's state (velocity, board
## facing and up, the floor) and whether it came down on a stair set (the stairs' hidden slope is under it).
static func bail_context(skater: Node3D, ctx: Dictionary) -> Dictionary:
	var out: Dictionary = ctx.duplicate()
	if not out.has("velocity"):
		out["velocity"] = skater.get("velocity")
	if not out.has("facing"):
		out["facing"] = skater.get("facing")
	if not out.has("board_up"):
		out["board_up"] = skater.get("board_up")
	if not out.has("normal"):
		out["normal"] = skater.get("_floor_normal")
	if not out.has("stairs") and str(out.get("cause", "")) in ["land", "flip"] and skater.is_inside_tree():
		var p: Vector3 = skater.global_position
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 1.5, WORLD_MASK)
		var hit: Dictionary = skater.get_world_3d().direct_space_state.intersect_ray(q)
		out["stairs"] = not hit.is_empty() and hit["collider"] is Node and str((hit["collider"] as Node).name) == "SlopeCollision"
	return out


## True once the body is at rest (or MAX_TIME ran out) and any injury has popped back.
func settled() -> bool:
	if not (_time >= MAX_TIME or _calm >= SETTLE_HOLD):
		return false
	return not has_injuries() or _onset_t < 0.0 or _repair_t >= BailInjury.REPAIR_TIME


func has_injuries() -> bool:
	return not (plan.get("injuries", []) as Array).is_empty()


## Current injury weight (0 when none is showing).
func injury_weight() -> float:
	return BailInjury.weight(_onset_t, _repair_t) if has_injuries() else 0.0


## Raw pelvis body transform.
func pelvis_raw_transform() -> Transform3D:
	var p: RigidBody3D = parts.get("pelvis") as RigidBody3D
	return p.global_transform if p != null else global_transform


## Respawn transform: origin on the ground under the pelvis, yaw facing along the body's forward (or the last
## travel direction when the pelvis points up or down), upright. Skater root convention: feet at origin, faces -Z.
func pelvis_transform() -> Transform3D:
	var raw: Transform3D = pelvis_raw_transform()
	var fwd: Vector3 = -raw.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.35:
		fwd = _last_dir
	fwd = fwd.normalized()
	var pos: Vector3 = raw.origin
	if is_inside_tree():
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 4.0, WORLD_MASK)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			pos = hit["position"]
			pos.y = maxf(pos.y, raw.origin.y - GROUND_BELOW_MAX)
		else:
			pos.y -= 0.15
	return Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)


func finish() -> void:
	_active = false
	_driven.clear()
	if _board != null and is_instance_valid(_board):
		_board.transform = _board_local
	_board = null
	for c: Node in get_children():  # joints first, then bodies; nothing is left in the physics space
		remove_child(c)
		c.free()
	parts.clear()
	joints.clear()
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	var p: RigidBody3D = parts.get("pelvis") as RigidBody3D
	if p != null:
		if p.linear_velocity.length() < SETTLE_SPEED:
			_calm += delta
		else:
			_calm = 0.0
	var torso: RigidBody3D = parts.get("torso") as RigidBody3D
	if torso != null and _time < GUIDE_TIME and _guide != Vector3.ZERO:
		torso.apply_torque_impulse(_guide * delta * (1.0 - _time / GUIDE_TIME))
	_tick_injuries(delta)
	_drive()


func _tick_injuries(delta: float) -> void:
	if not has_injuries():
		return
	if _onset_t >= 0.0:
		_onset_t += delta
	else:
		var hit: bool = _time >= ONSET_FALLBACK
		for pn: String in ["pelvis", "torso", "head"]:
			var rb: RigidBody3D = parts.get(pn) as RigidBody3D
			if rb == null:
				continue
			if _prev_v.has(pn) and _time > 0.02 and (rb.linear_velocity - (_prev_v[pn] as Vector3)).length() > IMPACT_DV:
				hit = true
			_prev_v[pn] = rb.linear_velocity
		if hit:
			_onset_t = 0.0
			injured.emit(injury_points())
	if _repair_t >= 0.0:
		_repair_t += delta
	elif _onset_t >= 0.0 and (_time >= MAX_TIME or _calm >= SETTLE_HOLD):
		_repair_t = 0.0
		repairing.emit(injury_points())


## The injured joint nodes (effects attach to them so they ride along with the limb).
func injury_nodes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for inj: Dictionary in plan.get("injuries", []):
		var n: Node3D = _joints.get(str(inj["joint"])) as Node3D
		if n != null and is_instance_valid(n):
			out.append(n)
	return out


## World positions of the injured joints.
func injury_points() -> Array:
	var out: Array = []
	for inj: Dictionary in plan.get("injuries", []):
		var n: Node3D = _joints.get(str(inj["joint"])) as Node3D
		if n != null and n.is_inside_tree():
			out.append(n.global_position)
	return out


func _process(_delta: float) -> void:
	if _active:
		_drive()


## Writes the bodies' transforms onto the original nodes.
func _drive() -> void:
	for d: Dictionary in _driven:
		var n: Node3D = d["node"]
		if not is_instance_valid(n):
			continue
		var b: RigidBody3D = d["body"]
		n.global_transform = b.global_transform * (d["offset"] as Transform3D)
	var w: float = injury_weight()
	if absf(w) < 0.0001:
		return
	for inj: Dictionary in plan.get("injuries", []):
		var jn: Node3D = _joints.get(str(inj["joint"])) as Node3D
		if jn == null or not is_instance_valid(jn):
			continue
		var hp: String = BailInjury.hinge_parent(str(inj["joint"]))
		BailInjury.apply(jn, inj, w, _joints.get(hp) as Node3D if hp != "" else null)


## The rider's frame at the bail: x right, y up, z back (the body faces -Z), from the hips, levelled.
func _body_frame(body: Node3D) -> Basis:
	var hips: Node3D = body.find_child("Hips", true, false) as Node3D
	var b: Basis = (hips if hips != null else body).global_basis.orthonormalized()
	var back: Vector3 = Vector3(b.z.x, 0.0, b.z.z)
	if back.length() < 0.1:
		back = Vector3.BACK
	back = back.normalized()
	return Basis(Vector3.UP.cross(back).normalized(), Vector3.UP, back)


## +1 or -1: which way a sideways style rolls (the injured side goes down first).
func _mirror() -> Vector3:
	var inj: Array = plan.get("injuries", [])
	var side: String = str((inj[0] as Dictionary).get("side", "L")) if not inj.is_empty() else str(plan.get("side", "R"))
	var m: float = -1.0 if side == "L" else 1.0
	return Vector3(1.0, m, m)


## Throws the arms and legs into the style's pose: the limb parts spin about their root joint for FLING_TIME.
func _fling(style: Dictionary) -> void:
	var hips: Node3D = _joints.get("Hips") as Node3D
	if hips == null:
		return
	var fr: Basis = _body_frame(hips)
	var arm: Vector3 = ARM_POSES.get(str(style.get("arms", "")), Vector3.ZERO)
	var leg: Vector3 = LEG_POSES.get(str(style.get("legs", "")), Vector3.ZERO)
	var fold: float = float(SHIN_FOLD.get(str(style.get("legs", "")), 0.0))
	for k: String in ["l", "r"]:
		var m: float = -1.0 if k == "l" else 1.0
		var side: String = "Left" if k == "l" else "Right"
		_spin_limb([k + "_uarm", k + "_larm"], _joints.get(side + "UpperArm") as Node3D,
				fr * Vector3(arm.x, arm.y * m, arm.z * m) / FLING_TIME)
		_spin_limb([k + "_thigh", k + "_shin"], _joints.get(side + "UpperLeg") as Node3D,
				fr * Vector3(leg.x, leg.y * m, leg.z * m) / FLING_TIME)
		if fold != 0.0:
			_spin_limb([k + "_shin"], _joints.get(side + "LowerLeg") as Node3D, fr * Vector3(fold, 0.0, 0.0) / FLING_TIME)


## Adds angular velocity w (world) to the parts, turning about the root joint's position.
func _spin_limb(names: Array, root: Node3D, w: Vector3) -> void:
	if root == null or w.length() < 0.001:
		return
	var c: Vector3 = root.global_position
	for pn: String in names:
		var rb: RigidBody3D = parts.get(pn) as RigidBody3D
		if rb == null:
			continue
		rb.angular_velocity += w
		rb.linear_velocity += w.cross(rb.global_position - c)


# --- building -----------------------------------------------------------------------------------------

func _build_body(body: Node3D, v: Vector3, spin: Vector3) -> void:
	var j: Dictionary = {}
	for pair: Array in DRIVEN:
		var n: Node3D = body.find_child(pair[0], true, false) as Node3D
		if n != null:
			j[pair[0]] = n
	if not j.has("Hips"):
		return
	_joints = j
	var ua: float = PlaceholderSkater.UPPER_ARM
	var la: float = PlaceholderSkater.LOWER_ARM
	var ul: float = PlaceholderSkater.UPPER_LEG
	var ll: float = PlaceholderSkater.LOWER_LEG
	# name: [joint node, center in joint frame, mass]
	var pelvis: RigidBody3D = _part("pelvis", j.get("Hips"), Vector3.ZERO, 6.0)
	_box(pelvis, Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3(0.28, 0.17, 0.22))
	var torso: RigidBody3D = _part("torso", j.get("Spine"), Vector3(0.0, 0.17, 0.0), 10.0)
	_box(torso, Transform3D.IDENTITY, Vector3(0.32, 0.36, 0.2))
	var head: RigidBody3D = _part("head", j.get("Head"), Vector3(0.0, 0.12, 0.0), 4.0)
	_sphere(head, Transform3D.IDENTITY, 0.15)
	var bodies: Array[RigidBody3D] = [pelvis, torso, head]
	_cone(pelvis, torso, j.get("Spine"), Basis.IDENTITY, 0.5, 0.45, true)
	_cone(torso, head, j.get("Head"), Basis.IDENTITY, 0.7, 0.8, true)
	for side: String in ["Left", "Right"]:
		var k: String = "l" if side == "Left" else "r"
		var j_ua: Node3D = j.get(side + "UpperArm")
		var j_la: Node3D = j.get(side + "LowerArm")
		var j_ul: Node3D = j.get(side + "UpperLeg")
		var j_ll: Node3D = j.get(side + "LowerLeg")
		if j_ua != null and j_la != null:
			var b_ua: RigidBody3D = _part(k + "_uarm", j_ua, Vector3(0.0, -ua * 0.5, 0.0), 1.4)
			_capsule(b_ua, Transform3D.IDENTITY, 0.045, ua + 0.02)
			var b_la: RigidBody3D = _part(k + "_larm", j_la, Vector3(0.0, -la * 0.5 - 0.01, 0.0), 1.3)
			_capsule(b_la, Transform3D.IDENTITY, 0.04, la + 0.08)
			_cone(torso, b_ua, j_ua, _limb_frame(j_ua), 1.6, 0.9, false)
			_hinge(b_ua, b_la, j_la, j_ua, ELBOW_RANGE)
			bodies.append_array([b_ua, b_la])
		if j_ul != null and j_ll != null:
			var b_ul: RigidBody3D = _part(k + "_thigh", j_ul, Vector3(0.0, -ul * 0.5, 0.0), 4.5)
			_capsule(b_ul, Transform3D.IDENTITY, 0.07, ul + 0.02)
			var b_ll: RigidBody3D = _part(k + "_shin", j_ll, Vector3(0.0, -ll * 0.5, 0.0), 3.0)
			_capsule(b_ll, Transform3D.IDENTITY, 0.055, ll + 0.02)
			var foot: Node3D = j.get(side + "Foot")
			if foot != null:
				var ft: Transform3D = b_ll.global_transform.affine_inverse() * foot.global_transform
				_box(b_ll, ft * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.085, -0.04)), Vector3(0.1, 0.07, 0.26))
			_cone(pelvis, b_ul, j_ul, _limb_frame(j_ul), 1.3, 0.6, false)
			_hinge(b_ul, b_ll, j_ll, j_ul, KNEE_RANGE)
			bodies.append_array([b_ul, b_ll])
	for pn: String in parts.keys():  # inertia floor: thin limbs spin too easily for the joint solver
		var rb2: RigidBody3D = parts[pn]
		var ext: float = float(INERTIA_LENGTH.get(pn.substr(2) if pn.length() > 2 and pn[1] == '_' else pn, 0.3))
		rb2.inertia = Vector3.ONE * rb2.mass * ext * ext / 12.0 * INERTIA_SCALE
	# Velocities: rigid-body spin about the pelvis.
	var c: Vector3 = pelvis.global_position
	for b: RigidBody3D in bodies:
		b.linear_velocity = v + spin.cross(b.global_position - c)
		b.angular_velocity = spin
	for pair: Array in DRIVEN:
		var n: Node3D = j.get(pair[0])
		var rb: RigidBody3D = parts.get(pair[1]) as RigidBody3D
		if n != null and rb != null:
			_driven.append({"node": n, "body": rb, "offset": rb.global_transform.affine_inverse() * n.global_transform})


func _build_board(board: Node3D, v: Vector3, kick: String = "forward") -> void:
	var gt: Transform3D = board.global_transform
	var b: RigidBody3D = _new_body("board", BOARD_MASS)
	b.global_transform = Transform3D(gt.basis.orthonormalized(), gt.origin + gt.basis.orthonormalized().y * BOARD_CENTER_Y)
	_box(b, Transform3D.IDENTITY, Vector3(0.22, 0.14, 0.8))
	b.physics_material_override = _material(0.6, 0.35)
	b.linear_damp = 0.05
	b.angular_damp = 2.5
	var flat: Vector3 = Vector3(v.x, 0.0, v.z)
	var dir: Vector3 = flat.normalized() if flat.length() > 0.5 else -gt.basis.z.normalized()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = absi(hash(Vector3(snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)))) + 17
	var side: Vector3 = dir.cross(Vector3.UP)
	b.linear_velocity = v + dir * 2.0 + Vector3.UP * 3.0 + side * rng.randf_range(-1.5, 1.5)
	var sign_x: float = 1.0 if rng.randf() < 0.5 else -1.0
	b.angular_velocity = side * sign_x * rng.randf_range(4.0, 8.0) \
		+ dir * rng.randf_range(-4.0, 4.0) + Vector3.UP * rng.randf_range(-3.0, 3.0)
	match kick:  # the style's board: shot out ahead (default), squirting back, popped up, or rolling on its rail
		"back":
			b.linear_velocity = v * 0.35 - dir * 1.5 + Vector3.UP * 2.5 + side * rng.randf_range(-1.0, 1.0)
		"up":
			b.linear_velocity = v * 0.8 + Vector3.UP * 4.5 + side * rng.randf_range(-1.0, 1.0)
		"roll":
			b.linear_velocity = v * 0.9 + Vector3.UP * 2.0 + side * sign_x * 1.5
			b.angular_velocity = dir * sign_x * rng.randf_range(7.0, 10.0) + Vector3.UP * rng.randf_range(-2.0, 2.0)
	b.linear_velocity = b.linear_velocity.limit_length(MAX_SPEED)
	_board = board
	_board_local = board.transform
	_driven.append({"node": board, "body": b, "offset": b.global_transform.affine_inverse() * gt})


func _material(friction: float, bounce: float) -> PhysicsMaterial:
	var m: PhysicsMaterial = PhysicsMaterial.new()
	m.friction = friction
	m.bounce = bounce
	return m


func _new_body(part_name: String, mass: float) -> RigidBody3D:
	var b: RigidBody3D = RigidBody3D.new()
	b.name = part_name
	b.mass = mass
	b.collision_layer = RAGDOLL_LAYER
	b.collision_mask = WORLD_MASK
	b.continuous_cd = true
	b.linear_damp = 0.15
	b.angular_damp = 2.5
	b.can_sleep = false
	b.physics_material_override = _material(0.9, 0.05)
	add_child(b)
	parts[part_name] = b
	return b


## A body whose frame matches the joint node's world orientation, centered at `center` (joint frame).
func _part(part_name: String, jn: Node3D, center: Vector3, mass: float) -> RigidBody3D:
	var gt: Transform3D = jn.global_transform
	var b: RigidBody3D = _new_body(part_name, mass)
	b.global_transform = Transform3D(gt.basis.orthonormalized(), gt * center)
	return b


func _add_shape(b: RigidBody3D, shape: Shape3D, xf: Transform3D) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	b.add_child(cs)


func _box(b: RigidBody3D, xf: Transform3D, size: Vector3) -> void:
	var s: BoxShape3D = BoxShape3D.new()
	s.size = size
	_add_shape(b, s, xf)


func _sphere(b: RigidBody3D, xf: Transform3D, radius: float) -> void:
	var s: SphereShape3D = SphereShape3D.new()
	s.radius = radius
	_add_shape(b, s, xf)


func _capsule(b: RigidBody3D, xf: Transform3D, radius: float, height: float) -> void:
	var s: CapsuleShape3D = CapsuleShape3D.new()
	s.radius = radius
	s.height = maxf(height, radius * 2.0 + 0.01)
	_add_shape(b, s, xf)


## Joint frame for a cone-twist: X (the twist axis) along the limb (down the joint's -Y).
func _limb_frame(jn: Node3D) -> Basis:
	var b: Basis = jn.global_transform.basis.orthonormalized()
	return Basis(-b.y, b.x, b.z)


func _cone(a: RigidBody3D, b: RigidBody3D, at: Node3D, frame: Basis, swing: float, twist: float, spine: bool) -> void:
	if at == null:
		return
	var basis: Basis = frame
	if spine:  # twist along the body's up axis
		var g: Basis = at.global_transform.basis.orthonormalized()
		basis = Basis(g.y, -g.x, g.z)
	var cj: Generic6DOFJoint3D = Generic6DOFJoint3D.new()
	add_child(cj)
	cj.global_transform = Transform3D(basis, at.global_position)
	cj.node_a = cj.get_path_to(a)
	cj.node_b = cj.get_path_to(b)
	cj.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	cj.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	cj.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	cj.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	cj.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	cj.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	cj.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -twist)
	cj.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, twist)
	cj.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -swing)
	cj.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, swing)
	cj.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -swing)
	cj.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, swing)
	joints.append(cj)


## Hinge about the joint's X axis. `absolute` is the allowed flex range measured from straight; the joint's own
## zero is the spawn pose, so the limits are shifted by the pose's current flex.
func _hinge(a: RigidBody3D, b: RigidBody3D, at: Node3D, upper: Node3D, absolute: Vector2) -> void:
	var gu: Basis = upper.global_transform.basis.orthonormalized()
	var gl: Basis = at.global_transform.basis.orthonormalized()
	var rel: Basis = gu.inverse() * gl
	var cur: float = atan2(rel.y.z, rel.y.y)
	var lo: float = minf(absolute.x, cur - 0.05)
	var hi: float = maxf(absolute.y, cur + 0.05)
	var hj: HingeJoint3D = HingeJoint3D.new()
	add_child(hj)
	hj.global_transform = Transform3D(Basis(gu.y, -gu.z, -gu.x), at.global_position)  # hinge axis -X: matches the engine's angle sign
	hj.node_a = hj.get_path_to(a)
	hj.node_b = hj.get_path_to(b)
	hj.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	hj.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, lo - cur)
	hj.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, hi - cur)
	joints.append(hj)
