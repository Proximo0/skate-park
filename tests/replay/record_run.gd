extends Node
## Flight-recorder self-test driver: a scripted ~5 s ride (push, two ollies, turns) on the test park with a
## PhysicsRecorder bound; dumps the log to the path given after `--` and quits.
## Run via tools/replay_selftest.sh, or: godot --headless --fixed-fps 60 --path . res://tests/replay/record_run.tscn -- <out.json>

const RIDE_TICKS: int = 300

var _skater: Skater
var _rec: PhysicsRecorder
var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://physics_logs/selftest.json"
	var park: Node = (load("res://game/park/test_park.tscn") as PackedScene).instantiate()
	add_child(park)
	_skater = park.get("skater")
	_skater.scripted_input = true
	_rec = PhysicsRecorder.new()
	add_child(_rec)
	_rec.bind(_skater)
	_skater.physics_ticked.connect(_on_tick)
	_feed(1)


## Input for tick `tick`: push forward, crouch 12 ticks then release (ollie) at 100 and 220, steer left then right.
static func input_for(tick: int) -> Array:
	var stick: Vector2 = Vector2(0.0, -1.0)
	if tick >= 140 and tick < 180:
		stick = Vector2(-0.6, -1.0)
	elif tick >= 240:
		stick = Vector2(0.5, -0.8)
	var held: Array = []
	if (tick >= 88 and tick < 100) or (tick >= 208 and tick < 220):
		held = ["ollie"]
	return [stick, [], held]


func _feed(tick: int) -> void:
	var inp: Array = input_for(tick)
	_skater.set_input(inp[0], inp[1], inp[2])


func _on_tick(frame: Dictionary) -> void:
	var tick: int = int(frame["tick"])
	if tick >= RIDE_TICKS:
		_skater.physics_ticked.disconnect(_on_tick)
		_finish.call_deferred()
		return
	_feed(tick + 1)


func _finish() -> void:
	var path: String = _rec.dump(_out)
	var states: Dictionary = {}
	for r: Dictionary in _rec.frames_in_order():
		states[r["state"]] = true
		for e: String in (r["events"] as Array):
			states["ev:" + e] = true
	print("RECORD wrote %s frames=%d snapshots=%d seen=%s" % [path, _rec.frame_count(), _rec.snapshot_ticks().size(), str(states.keys())])
	get_tree().quit(0)
