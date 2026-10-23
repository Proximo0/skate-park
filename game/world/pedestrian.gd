class_name Pedestrian
extends Node3D
## One walker of a Pedestrians crowd: a baked body (PedBody) posed by a PedPoser, walking a LanePath (back and forth on
## an open path, round and round on a loop), stopping now and then to idle or check a phone. When the skater comes
## close it steps aside off the line; when the skater flies past very close it startles, and sometimes it waves.
## Standing groups ("chat") and fixed idlers ("phone", "idle", "wave") use the same node with no path.
## Walkers are in the "traffic_obstacle" group, so Traffic stops for them where they cross a lane.
## Cost: about 15 draw calls (one per joint plus the skin); the pose runs at an LOD rate set by Pedestrians (every frame
## close, less far away, never when the person is hidden or off camera).

const DODGE_RADIUS: float = 4.5
const STARTLE_RADIUS: float = 1.8
const DODGE_SIDE: float = 1.3
const TURN_RATE: float = 6.0

var path: LanePath = null
var s: float = 0.0
var dir: float = 1.0  ## +1 forward along the path, -1 back
var walk_speed: float = 1.25
var base_mode: String = "idle"  ## the mode when not walking (path == null) or during a stop
## Optional: a look of this person's own (instead of one of the crowd's pool) and a PedBody uniform put on it. Set both
## right after add_walkers/add_group/add_idler, before the crowd builds its looks (the first frame).
var look_override: SkaterLoadout = null
var uniform: String = ""
var poser: PedPoser
var body: Node3D
var phase: float = 0.0
var clock: float = 0.0
var rng := RandomNumberGenerator.new()
var _stop_left: float = 0.0
var _next_stop: float = 0.0
var _react_left: float = 0.0
var _react_mode: String = ""
var _offset: float = 0.0  ## sideways step off the path (metres, + = right of travel)
var _offset_target: float = 0.0
var _yaw: float = 0.0
var _rest_yaw: float = 0.0
var _pending: float = 0.0  ## time accumulated while the pose update was skipped (LOD)
var _phone: MeshInstance3D = null
var posed: bool = false  ## true once the body has been posed at least once
var _shadows_on: bool = true
var _shadow_meshes: Array[GeometryInstance3D] = []  ## the meshes set_shadows(false) switched off

static var _phone_mesh: BoxMesh = null
static var _phone_mat: StandardMaterial3D = null


## A pedestrian with no body yet (attach_body() gives it one; until then it walks unseen). Not yet in the tree.
static func create(seed_value: int) -> Pedestrian:
	var p := Pedestrian.new()
	p.rng.seed = seed_value
	p.visible = false
	p._next_stop = p.rng.randf_range(8.0, 30.0)
	return p


## Puts a baked body (PedBody.build or PedBody.clone) on this pedestrian and makes its poser.
func attach_body(b: Node3D) -> void:
	body = b
	body.name = "SkaterBody"
	add_child(body)
	var dummy_board := Node3D.new()  # the poser needs a board; pedestrians carry none
	dummy_board.name = "NoBoard"
	dummy_board.visible = false
	add_child(dummy_board)
	poser = PedPoser.new()
	poser.name = "Poser"
	poser.body = body
	poser.board = dummy_board
	poser.sway_phase = rng.randf() * 10.0
	poser.mode = "walk" if path != null else base_mode
	add_child(poser)
	poser.set_process(false)  # driven by step() at the LOD rate (the poser gotcha)
	var hand: Node3D = body.find_child("RightHand", true, false) as Node3D
	if hand != null:
		_phone = Pedestrian.phone_prop()
		_phone.visible = false
		hand.add_child(_phone)
	visible = true


## A phone in the palm (one small shared box; shown only in the "phone" pose).
static func phone_prop() -> MeshInstance3D:
	if _phone_mesh == null:
		_phone_mesh = BoxMesh.new()
		_phone_mesh.size = Vector3(0.072, 0.145, 0.011)
		_phone_mat = StandardMaterial3D.new()
		_phone_mat.albedo_color = Color("1c1f2a")
		_phone_mat.emission_enabled = true
		_phone_mat.emission = Color("6fb7ff")
		_phone_mat.emission_energy_multiplier = 0.25
	var mi := MeshInstance3D.new()
	mi.name = "Phone"
	mi.mesh = _phone_mesh
	mi.material_override = _phone_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, -0.07, -0.02)
	mi.rotation = Vector3(0.0, PI * 0.5, 0.0)
	return mi


func has_body() -> bool:
	return body != null


func _ready() -> void:
	_rest_yaw = rotation.y
	_yaw = rotation.y
	if path != null:
		add_to_group("traffic_obstacle")
	_place(1.0)


func is_walking() -> bool:
	return path != null and _stop_left <= 0.0 and _react_left <= 0.0


## Advances the walker by delta. `pose_now` false skips the (costly) pose update this frame; the time is kept and
## applied on the next posed frame. `skater` may be null.
func step(delta: float, skater: Node3D, pose_now: bool) -> void:
	clock += delta
	if poser == null:
		_walk_only(delta)
		return
	_react(delta, skater)
	if _react_left <= 0.0:
		poser.look_yaw = move_toward(poser.look_yaw, 0.0, 60.0 * delta)
	if path != null:
		if _react_left <= 0.0 and _stop_left > 0.0:
			_stop_left -= delta
			if _stop_left <= 0.0:
				_next_stop = rng.randf_range(12.0, 40.0)
		elif _react_left <= 0.0:
			_next_stop -= delta
			if _next_stop <= 0.0:
				_stop_left = rng.randf_range(2.5, 7.0)
				base_mode = "phone" if rng.randf() < 0.45 else "idle"
		var moving: bool = is_walking() or (_react_mode == "dodge" and _react_left > 0.0)
		if moving:
			var v: float = walk_speed * (1.15 if _react_mode == "dodge" else 1.0)
			s += v * dir * delta
			if not path.loop and (s >= path.length or s <= 0.0):
				s = clampf(s, 0.0, path.length)
				dir = -dir
			s = path.wrap_s(s)
			phase = fposmod(phase + v * delta * Pedestrian.cadence(v), 1.0)
		_offset = move_toward(_offset, _offset_target, 1.4 * delta)
		_place(delta)
		poser.mode = "walk" if moving else (_react_mode if _react_left > 0.0 and _react_mode != "dodge" else base_mode)
	else:
		poser.mode = _react_mode if _react_left > 0.0 and _react_mode != "dodge" else base_mode
		var want: float = _rest_yaw
		if _react_left > 0.0 and skater != null:
			var to: Vector3 = skater.global_position - global_position
			want = atan2(-to.x, -to.z)
		_yaw += angle_difference(_yaw, want) * (1.0 - exp(-TURN_RATE * delta))
		rotation.y = _yaw
	_pending += delta
	if _phone != null:
		_phone.visible = poser.mode == "phone"
	if pose_now:
		poser.drive(_pending, clock, phase, walk_speed if poser.mode == "walk" else 0.0)
		_pending = 0.0
		posed = true


## Sun shadows on or off for the whole body (the crowd's distance LOD). Only meshes that were casting are switched, and
## only those come back, so a level that turned some off for its own reasons keeps them off.
func set_shadows(on: bool) -> void:
	if on == _shadows_on or body == null:
		return
	_shadows_on = on
	if on:
		for g: GeometryInstance3D in _shadow_meshes:
			if is_instance_valid(g):
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_shadow_meshes.clear()
	else:
		for n: Node in find_children("*", "GeometryInstance3D", true, false):
			var g: GeometryInstance3D = n as GeometryInstance3D
			if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_shadow_meshes.append(g)


## Keeps a body-less walker moving along its path (so the crowd is spread out when the bodies arrive).
func _walk_only(delta: float) -> void:
	if path == null:
		return
	s = path.wrap_s(s + walk_speed * dir * delta)
	if not path.loop and (s >= path.length - 0.01 or s <= 0.01):
		dir = -dir
	_place(delta)


## Stride cycles per metre at walking speed v: matches SkaterPoser's walk so the planted foot does not slide
## (a foot is planted for half the cycle and travels 2 * half over it).
static func cadence(v: float) -> float:
	var half: float = minf(0.18 + 0.045 * v, 0.32) * clampf(v / 0.6, 0.0, 1.0)
	return 0.5 / maxf(2.0 * half, 0.05)


func _place(delta: float) -> void:
	if path == null:
		return
	var t: Vector3 = path.tangent(s, 1.0) * dir
	var right: Vector3 = t.cross(Vector3.UP).normalized()
	position = path.sample(s) + right * _offset
	var want: float = atan2(-t.x, -t.z)
	_yaw += angle_difference(_yaw, want) * (1.0 - exp(-TURN_RATE * delta))
	rotation.y = _yaw


## Sidestep, startle or wave when the skater is close.
func _react(delta: float, skater: Node3D) -> void:
	_react_left = maxf(_react_left - delta, 0.0)
	if _react_left <= 0.0:
		_react_mode = ""
		_offset_target = 0.0
	if skater == null:
		return
	var to: Vector3 = skater.global_position - global_position
	var d: float = Vector2(to.x, to.z).length()
	if d > DODGE_RADIUS or absf(to.y) > 2.0:
		return
	var sk_v: Vector3 = skater.get("velocity") as Vector3 if skater.get("velocity") is Vector3 else Vector3.ZERO
	var sk_speed: float = Vector2(sk_v.x, sk_v.z).length()
	if d < STARTLE_RADIUS and sk_speed > 4.0 and _react_mode != "startle":
		_react_mode = "startle"
		_react_left = 1.1
		look_at_skater(to)
		return
	if _react_left > 0.0:
		return
	if path != null and sk_speed > 1.0:
		# step to the side away from the skater's line
		var t: Vector3 = path.tangent(s, 1.0) * dir
		var right: Vector3 = t.cross(Vector3.UP).normalized()
		_offset_target = -signf(right.dot(to)) * DODGE_SIDE
		if _offset_target == 0.0:
			_offset_target = DODGE_SIDE
		_react_mode = "dodge"
		_react_left = 2.2
	elif sk_speed < 3.0 and rng.randf() < 0.5 * delta * 4.0:
		_react_mode = "wave"
		_react_left = 2.4
		look_at_skater(to)


func look_at_skater(to: Vector3) -> void:
	var local: Vector3 = global_transform.basis.inverse() * to
	poser.look_yaw = clampf(rad_to_deg(atan2(-local.x, -local.z)), -70.0, 70.0)
