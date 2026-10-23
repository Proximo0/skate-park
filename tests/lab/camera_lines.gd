extends Node
## Camera continuity on a bot line: rides one line of a level with the real SkateCamera and reports the worst yaw rate
## of the view and the worst single-tick camera displacement (respawn / drop-in teleports excluded), plus the mean
## camera distance at speed (the rider's size in the frame). Run via tools/camera_report.sh, or:
## godot --headless --fixed-fps 60 --path . res://tests/lab/camera_lines.tscn -- --level=<id> --line=<name> [--maxsec=40]
## Also the farthest and nearest the camera gets from the rider (drop-ins lost the rider 12 m away; the loop put the
## camera inside the rider), the smallest share of the frame height the rider fills, and ticks with the rider out of frame.
## Bail ticks are not scored for distance and framing (the bail camera orbits a ragdoll).
## Prints `CAM <level> <line> max_yaw=<rad/s> max_rot=<rad/s> max_jump=<m> dist_at_speed=<m> max_dist=<m> min_dist=<m> min_frame=<0..1>
## off_frame=<ticks> ticks=<n>` and quits.

const SKIP_TICKS: int = 20
const TELEPORT: float = 1.5  ## m the skater moves in one tick only on a respawn or reset (top speed is 0.4 m a tick): that tick and the next are not scored

var _level: String = "practice"
var _line_name: String = ""
var _max_ticks: int = 40 * 60
var _main: Node
var _sk: Skater
var _cam: Camera3D
var _drv: BotDriver
var _tick: int = 0
var _settle: int = 0
var _prev_pos: Vector3 = Vector3.ZERO
var _prev_yaw: float = 0.0
var _prev_skater: Vector3 = Vector3.ZERO
var _prev_tele: int = -10
var max_yaw: float = 0.0
var max_rot: float = 0.0
var _prev_basis: Basis = Basis.IDENTITY
var max_jump: float = 0.0
var _dist_sum: float = 0.0
var _dist_n: int = 0
var max_dist: float = 0.0
var min_dist: float = INF
var min_frame: float = INF
var off_frame: int = 0
var _bail_left: int = 0
const RIDER_H: float = 1.7  ## m of rider the frame-share metric measures


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		match kv[0]:
			"level": _level = kv[1]
			"line": _line_name = kv[1]
			"maxsec": _max_ticks = int(kv[1]) * 60
	if _level != "practice":
		Flags.args = {"level": _level}
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_sk = _main.skater
	_sk.scripted_input = true
	_cam = _main.get_node("SkateCamera")


func _physics_process(delta: float) -> void:
	if _main == null:
		return
	_settle += 1
	if _settle < 5:
		return
	if _drv == null:
		var wps: Array
		var space: PhysicsDirectSpaceState3D = _sk.get_world_3d().direct_space_state
		if _line_name.begins_with("auto_"):
			wps = (load("res://tests/bot/bot_auto.gd").build(_line_name, _main.park, space) as Dictionary).get("wps", [])
		elif _line_name.begins_with("mv_"):
			wps = (load("res://tests/bot/bot_moves.gd").build_move(_line_name, _main.park, space) as Dictionary).get("wps", [])
		elif _level == "practice":
			wps = BotLines.new(_main.park, _sk).build(_line_name)["wps"]
		else:
			var route: Dictionary = LevelRoute.load_file(str(LevelRegistry.entry(_level).get("bot_route", "")))
			wps = LevelRoute.line(route, _line_name)["wps"]
		_drv = BotDriver.new(_sk, _main.park, wps)
		_sk.landed.connect(func(_r: String) -> void: _drv.on_landed())
	_drv.step(delta)
	_tick += 1
	var jump: float = _cam.global_position.distance_to(_prev_pos)
	# The view's horizontal swing: the heading change of the view direction, weighted by how level it is (cos pitch).
	# The Euler yaw alone spikes meaninglessly when the view passes near vertical (the loop camera rolls over the top).
	var fwd: Vector3 = -_cam.global_transform.basis.z
	var yaw: float = atan2(fwd.x, fwd.z)
	var level: float = Vector2(fwd.x, fwd.z).length()
	var yaw_rate: float = absf(wrapf(yaw - _prev_yaw, -PI, PI)) * level / delta
	# ... and the whole rotation of the view (yaw, pitch and roll), rad/s.
	var rot_rate: float = (_prev_basis.inverse() * _cam.global_transform.basis).get_rotation_quaternion().get_angle() / delta
	var moved: float = _sk.global_position.distance_to(_prev_skater)
	if moved > TELEPORT:
		_prev_tele = _tick
	if _tick > SKIP_TICKS and _tick - _prev_tele > 1:
		max_yaw = maxf(max_yaw, yaw_rate)
		max_rot = maxf(max_rot, rot_rate)
		max_jump = maxf(max_jump, jump)
		if _sk.speed >= 9.0 and _sk.state.state == SkateState.State.ROLLING:
			_dist_sum += _cam.global_position.distance_to(_sk.global_position)
			_dist_n += 1
		_frame_metrics()
	_prev_pos = _cam.global_position
	_prev_yaw = yaw
	_prev_basis = _cam.global_transform.basis.orthonormalized()
	_prev_skater = _sk.global_position
	if _drv.finished or _tick >= _max_ticks:
		print("CAM %s %s max_yaw=%.2f max_rot=%.2f max_jump=%.2f dist_at_speed=%.2f max_dist=%.2f min_dist=%.2f min_frame=%.3f off_frame=%d ticks=%d" % [
				_level, _line_name, max_yaw, max_rot, max_jump, _dist_sum / maxf(_dist_n, 1.0), max_dist, min_dist if is_finite(min_dist) else 0.0,
				min_frame if is_finite(min_frame) else 0.0, off_frame, _tick])
		get_tree().quit()


## Distance and framing, skipping bails and a second after them (the getup and respawn).
func _frame_metrics() -> void:
	if _sk.state.state == SkateState.State.BAIL or _sk.state.state == SkateState.State.WALK:
		_bail_left = 60
		return
	if _bail_left > 0:
		_bail_left -= 1
		return
	var up: Vector3 = _sk.board_up.normalized() if _sk.board_up.length() > 0.1 else Vector3.UP
	var mid: Vector3 = _sk.global_position + up * (RIDER_H * 0.5)  # the body's middle, along the board's up (upside down in a loop)
	var d: float = _cam.global_position.distance_to(mid)
	max_dist = maxf(max_dist, d)
	min_dist = minf(min_dist, d)
	var frame: float = RIDER_H / (2.0 * d * tan(deg_to_rad(_cam.fov) * 0.5))
	min_frame = minf(min_frame, frame)
	if not _cam.is_position_in_frustum(mid):
		off_frame += 1
