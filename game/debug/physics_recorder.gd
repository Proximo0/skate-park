class_name PhysicsRecorder
extends Node
## Flight recorder: keeps the last 30 s of per-tick skater data plus a snapshot() every 60 ticks in a ring buffer.
## F12 dumps it to user://physics_logs/run_<datetime>.json; each bail also writes bail_<datetime>.json (10 s before
## it, 1 s after; the newest 3 are kept). Format: docs/physics_debug_brief.md. Replay it with tools/replay.sh.

const VERSION: int = 1
const LOG_DIR: String = "user://physics_logs"
const KEEP_BAILS: int = 3
const BAIL_BEFORE_S: float = 10.0
const BAIL_AFTER_S: float = 1.0
const TOAST_SECONDS: float = 3.0

var capacity: int = 1800  ## frames kept (30 s at 60 Hz)
var snapshot_every: int = 60  ## ticks between snapshots
var log_dir: String = LOG_DIR
var tick_rate: int = 60

var _skater: Object = null
var _ring: Array = []  ## Dictionary per tick, raw values (Vector3 etc.); converted only when dumping
var _head: int = 0  ## next write slot
var _count: int = 0
var _snaps: Dictionary = {}  ## tick (int) -> var_to_str(snapshot()) String
var _bail_tick: int = -1  ## tick of a bail waiting for its extra second, or -1
var _toast_layer: CanvasLayer = null
var _toast_label: Label = null
var _toast_left: float = 0.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tick_rate = Engine.physics_ticks_per_second


func bind(skater: Object) -> void:
	if _skater != null and _skater.is_connected("physics_ticked", _on_tick):
		_skater.disconnect("physics_ticked", _on_tick)
	_skater = skater
	_skater.connect("physics_ticked", _on_tick)


func frame_count() -> int:
	return _count


## The kept frames, oldest first (the raw ring entries, not copies).
func frames_in_order() -> Array:
	var out: Array = []
	var start: int = (_head - _count + capacity) % capacity
	for i: int in _count:
		out.append(_ring[(start + i) % capacity])
	return out


func snapshot_ticks() -> Array:
	var ticks: Array = _snaps.keys()
	ticks.sort()
	return ticks


func _on_tick(frame: Dictionary) -> void:
	var tick: int = int(frame["tick"])
	var ev: Array = frame["events"]
	var rec: Dictionary = {
		"tick": tick, "t": frame["t"], "state": frame["state"], "pos": frame["pos"], "vel": frame["vel"],
		"speed": frame["speed"], "on_floor": frame["on_floor"], "floor_normal": frame["floor_normal"],
		"facing": frame["facing"], "stick": frame["stick"], "held": (frame["held"] as Array).duplicate(),
		"pressed": (frame["pressed"] as Array).duplicate(), "crouch": frame["crouch"], "anim": frame["anim"],
		"pumping": frame["pumping"], "pushing": frame["pushing"], "events": ev.duplicate(),
	}
	if _ring.size() < capacity:
		_ring.resize(capacity)
	_ring[_head] = rec
	_head = (_head + 1) % capacity
	_count = mini(_count + 1, capacity)
	if _snaps.is_empty() or tick % snapshot_every == 0:
		_snaps[tick] = var_to_str(_skater.call("snapshot"))
		_prune_snapshots()
	if _bail_tick < 0 and ev.has("bail"):
		_bail_tick = tick
	elif _bail_tick >= 0 and tick >= _bail_tick + int(round(BAIL_AFTER_S * tick_rate)):
		_write_bail()


## Drops snapshots older than the newest one at or before the oldest kept frame (nothing can replay from them).
func _prune_snapshots() -> void:
	if _count == 0:
		return
	var oldest: int = int((_ring[(_head - _count + capacity) % capacity] as Dictionary)["tick"])
	var keep_from: int = -1
	for k: int in _snaps:
		if k <= oldest and k > keep_from:
			keep_from = k
	if keep_from < 0:
		return
	for k: int in _snaps.keys():
		if k < keep_from:
			_snaps.erase(k)


func _write_bail() -> void:
	var bail: int = _bail_tick
	_bail_tick = -1
	var from_tick: int = bail - int(round(BAIL_BEFORE_S * tick_rate))
	var path: String = "%s/bail_%s.json" % [log_dir, _stamp()]
	_write_file(path, from_tick, bail + int(round(BAIL_AFTER_S * tick_rate)))
	_trim_bails()


func _trim_bails() -> void:
	var names: Array = []
	for f: String in DirAccess.get_files_at(log_dir):
		if f.begins_with("bail_") and f.ends_with(".json"):
			names.append(f)
	names.sort()
	while names.size() > KEEP_BAILS:
		DirAccess.remove_absolute("%s/%s" % [log_dir, names.pop_front()])


## Writes everything in the ring to `path` (default user://physics_logs/run_<datetime>.json). Returns the path.
func dump(path: String = "") -> String:
	if path == "":
		path = "%s/run_%s.json" % [log_dir, _stamp()]
	_write_file(path, -1, -1)
	return path


func _stamp() -> String:
	return Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")


## Frames with from_tick <= tick <= to_tick (-1 = no bound) and the snapshots needed to replay them.
func _write_file(path: String, from_tick: int, to_tick: int) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var frames: Array = []
	for rec: Dictionary in frames_in_order():
		var tk: int = int(rec["tick"])
		if (from_tick >= 0 and tk < from_tick) or (to_tick >= 0 and tk > to_tick):
			continue
		frames.append(_frame_json(rec))
	var first: int = int((frames[0] as Dictionary)["tick"]) if not frames.is_empty() else 0
	var last: int = int((frames[frames.size() - 1] as Dictionary)["tick"]) if not frames.is_empty() else 0
	var best: int = -1
	for k: int in _snaps:
		if k <= first and k > best:
			best = k
	var snaps: Dictionary = {}
	for k: int in snapshot_ticks():
		if k >= maxi(best, 0) and k <= last:
			snaps[str(k)] = _snaps[k]
	var tune_dict: Dictionary = {}
	var tn: Variant = _skater.get("tune") if _skater != null else null
	if tn is PhysicsTuning:
		tune_dict = (tn as PhysicsTuning).to_dict()
	else:
		tune_dict = PhysicsTuning.shared().to_dict()
	var doc: Dictionary = {"version": VERSION, "park": _park_name(), "tuning": tune_dict, "tick_rate": tick_rate,
		"frames": frames, "snapshots": snaps}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("PhysicsRecorder: cannot write %s (%d)" % [path, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(doc))


func _park_name() -> String:
	var n: Node = (_skater as Node).get_parent() if _skater is Node else null
	while n != null:
		if n is Park:
			return "main"
		var sc: Script = n.get_script() as Script
		if sc != null and sc.resource_path.ends_with("test_park.gd"):
			return "testpark"
		n = n.get_parent()
	return "main"


static func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _frame_json(r: Dictionary) -> Dictionary:
	var st: Vector2 = r["stick"]
	return {
		"tick": r["tick"], "t": r["t"], "state": r["state"], "pos": _v3(r["pos"]), "vel": _v3(r["vel"]),
		"speed": r["speed"], "on_floor": r["on_floor"], "floor_normal": _v3(r["floor_normal"]),
		"facing": _v3(r["facing"]), "stick": [st.x, st.y], "held": r["held"], "pressed": r["pressed"],
		"crouch": r["crouch"], "anim": r["anim"], "pumping": r["pumping"], "pushing": r["pushing"],
		"events": r["events"],
	}


# --- F12 and the toast ----------------------------------------------------------------------------------

func _ready() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 120
	add_child(_toast_layer)
	_toast_label = Label.new()
	_toast_label.position = Vector2(16, 16)
	_toast_label.add_theme_font_size_override("font_size", 16)
	_toast_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_toast_label.add_theme_constant_override("outline_size", 6)
	_toast_label.visible = false
	_toast_layer.add_child(_toast_label)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F12:
		var path: String = dump()
		toast("Physics log saved:\n" + ProjectSettings.globalize_path(path))


func toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.visible = true
	_toast_left = TOAST_SECONDS


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0 and _toast_label != null:
			_toast_label.visible = false
