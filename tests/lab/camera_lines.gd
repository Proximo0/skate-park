extends Node
## Camera continuity on a bot line: rides one line of a level with the real SkateCamera and reports the worst yaw rate
## of the view and the worst single-tick camera displacement (respawn / drop-in teleports excluded), plus the mean
## camera distance at speed (the rider's size in the frame). Run via tools/camera_report.sh, or:
## godot --headless --fixed-fps 60 --path . res://tests/lab/camera_lines.tscn -- --level=<id> --line=<name> [--maxsec=40]
## Prints `CAM <level> <line> max_yaw=<rad/s> max_jump=<m> dist_at_speed=<m> ticks=<n>` and quits.

const SKIP_TICKS: int = 20
const TELEPORT: float = 3.0  ## m the skater moves in one tick only on a respawn: that tick and the next are not scored

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
var max_jump: float = 0.0
var _dist_sum: float = 0.0
var _dist_n: int = 0


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
		if _level == "practice":
			wps = BotLines.new(_main.park, _sk).build(_line_name)["wps"]
		else:
			var route: Dictionary = LevelRoute.load_file(str(LevelRegistry.entry(_level).get("bot_route", "")))
			wps = LevelRoute.line(route, _line_name)["wps"]
		_drv = BotDriver.new(_sk, _main.park, wps)
		_sk.landed.connect(func(_r: String) -> void: _drv.on_landed())
	_drv.step(delta)
	_tick += 1
	var jump: float = _cam.global_position.distance_to(_prev_pos)
	var yaw: float = _cam.global_rotation.y
	var yaw_rate: float = absf(wrapf(yaw - _prev_yaw, -PI, PI)) / delta
	var moved: float = _sk.global_position.distance_to(_prev_skater)
	if moved > TELEPORT:
		_prev_tele = _tick
	if _tick > SKIP_TICKS and _tick - _prev_tele > 1:
		max_yaw = maxf(max_yaw, yaw_rate)
		max_jump = maxf(max_jump, jump)
		if _sk.speed >= 9.0 and _sk.state.state == SkateState.State.ROLLING:
			_dist_sum += _cam.global_position.distance_to(_sk.global_position)
			_dist_n += 1
	_prev_pos = _cam.global_position
	_prev_yaw = yaw
	_prev_skater = _sk.global_position
	if _drv.finished or _tick >= _max_ticks:
		print("CAM %s %s max_yaw=%.2f max_jump=%.2f dist_at_speed=%.2f ticks=%d" % [_level, _line_name, max_yaw, max_jump,
				_dist_sum / maxf(_dist_n, 1.0), _tick])
		get_tree().quit()
