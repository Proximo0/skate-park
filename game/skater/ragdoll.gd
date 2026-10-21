class_name SkaterRagdoll
extends Node3D
## Physics ragdoll for a bail. spawn() snapshots the pose of a PlaceholderSkater body (and its board), builds
## RigidBody3D parts joined with limited joints, and then drives the ORIGINAL joint nodes and the board node from
## the rigid bodies each physics frame, so the existing meshes follow with no duplicates. finish() frees the
## physics and stops driving; the poser takes over again on the next frame.
## Parts live on collision layer 4 and only collide with the world (mask 1), never with the skater (layer 2) or
## each other. Total mass about 40 kg. Deterministic: the board spin comes from a seeded RNG.

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


static func spawn(body: Node3D, board: Node3D, velocity: Vector3, angular_hint: Vector3, world: Node) -> SkaterRagdoll:
	var r: SkaterRagdoll = SkaterRagdoll.new()
	r.name = "SkaterRagdoll"
	r.process_physics_priority = 100  # after the skater has moved, so the drive wins
	world.add_child(r)
	r.global_transform = Transform3D.IDENTITY
	var v: Vector3 = velocity.limit_length(MAX_SPEED)
	var spin: Vector3 = angular_hint.limit_length(MAX_SPIN)
	r._build_body(body, v, spin)
	if board != null:
		r._build_board(board, v)
	var flat: Vector3 = Vector3(v.x, 0.0, v.z)
	if flat.length() > 0.1:
		r._last_dir = flat.normalized()
	r._drive()
	return r


func settled() -> bool:
	return _time >= MAX_TIME or _calm >= SETTLE_HOLD


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
	_drive()


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


# --- building -----------------------------------------------------------------------------------------

func _build_body(body: Node3D, v: Vector3, spin: Vector3) -> void:
	var j: Dictionary = {}
	for pair: Array in DRIVEN:
		var n: Node3D = body.find_child(pair[0], true, false) as Node3D
		if n != null:
			j[pair[0]] = n
	if not j.has("Hips"):
		return
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
			var b_la: RigidBody3D = _part(k + "_larm", j_la, Vector3(0.0, -la * 0.5 - 0.01, 0.0), 1.0)
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


func _build_board(board: Node3D, v: Vector3) -> void:
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
