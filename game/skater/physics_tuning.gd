class_name PhysicsTuning
extends RefCounted
## Every ride-physics number the skater uses, live-editable. The skater reads these each tick (through its
## `tune` var), so the tuning panel, replays and sims can change the feel without touching code.
## Defaults are the shipped feel. Presets are JSON dictionaries of {field: value}; unknown keys are ignored.

signal changed(field: String, value: float)

## [field, default, min, max, step, group, doc]. The order here is the order the tuning panel shows.
const FIELDS: Array = [
	["gravity", 18.0, 5.0, 40.0, 0.5, "World", "Gravity, m/s². Real is 9.8; higher feels snappier, less floaty."],
	["max_speed", 22.0, 8.0, 40.0, 0.5, "World", "Hard speed cap, m/s."],
	["kill_y", -20.0, -60.0, -5.0, 1.0, "World", "Respawn below this height."],
	["push_accel", 5.5, 1.0, 30.0, 0.25, "Push", "Speed gained per second of kick contact."],
	["push_max", 12.0, 4.0, 25.0, 0.25, "Push", "Pushing alone tops out here, m/s."],
	["push_plant", 0.18, 0.0, 0.6, 0.01, "Push", "Delay before the first kick lands, s."],
	["push_cycle", 0.6, 0.2, 1.5, 0.01, "Push", "Length of one push cycle, s."],
	["push_contact", 0.55, 0.1, 1.0, 0.01, "Push", "Share of the cycle the foot is on the ground."],
	["brake", 6.0, 0.0, 30.0, 0.25, "Rolling", "Braking deceleration (stick back), m/s²."],
	["roll_friction", 0.6, 0.0, 5.0, 0.05, "Rolling", "Rolling resistance, m/s²."],
	["side_grip", 25.0, 1.0, 100.0, 1.0, "Rolling", "How hard the wheels stop sideways sliding, m/s²."],
	["turn_rate", 2.6, 0.5, 8.0, 0.05, "Rolling", "Turn rate at low speed, rad/s."],
	["turn_rate_fast", 1.7, 0.3, 6.0, 0.05, "Rolling", "Turn rate at max speed, rad/s."],
	["carve_grip", 18.0, 4.0, 60.0, 0.5, "Rolling", "Most sideways acceleration a carve can pull, m/s² (about 1 g here): sets how wide fast turns get."],
	["pump_accel", 2.5, 0.0, 15.0, 0.25, "Transitions", "Pump on gentle transitions, m/s²."],
	["pump_accel_vert", 32.0, 0.0, 50.0, 0.5, "Transitions", "Pump on steep (vert) transitions, m/s²."],
	["pump_speed_ref", 12.0, 3.0, 30.0, 0.5, "Transitions", "Speed (m/s) at which the pump gives its full rate; slower pumps less, faster more (a pass builds on the last)."],
	["vert_normal_y", 0.35, 0.05, 0.8, 0.01, "Transitions", "Leaving a face steeper than this, going up, is a vert launch."],
	["edge_grip", 2.5, 0.5, 8.0, 0.1, "Transitions", "Grip on convex bends, as a multiple of gravity's hold."],
	["overhang_radius", 3.5, 1.0, 10.0, 0.1, "Transitions", "Assumed curve radius when judging if speed holds you upside down."],
	["ollie_min", 6.0, 2.0, 15.0, 0.1, "Air", "Pop speed of a tap ollie, m/s."],
	["ollie_max", 8.5, 2.0, 18.0, 0.1, "Air", "Pop speed of a fully crouched ollie, m/s."],
	["crouch_full", 0.4, 0.05, 1.5, 0.01, "Air", "Crouch time for the full ollie, s."],
	["spin_rate", 7.5, 2.0, 20.0, 0.1, "Air", "Air spin rate, rad/s."],
	["air_steer", 1.2, 0.0, 6.0, 0.05, "Air", "How much the stick bends the path in the air."],
	["flip_time", 0.42, 0.1, 1.0, 0.01, "Air", "Time for one flip, s."],
	["double_flip_time", 0.68, 0.2, 1.5, 0.01, "Air", "Time for a double flip, s."],
	["grind_reach", 1.1, 0.3, 3.0, 0.05, "Grind", "How far a rail can be to snap on, m."],
	["grind_min_speed", 3.0, 0.0, 10.0, 0.1, "Grind", "Slowest speed that can start a grind, m/s."],
	["rail_gravity", 10.0, 0.0, 30.0, 0.5, "Grind", "Gravity along a sloped rail, m/s²."],
	["rail_friction", 1.2, 0.0, 5.0, 0.05, "Grind", "Grind friction at 8 m/s, m/s² (scales with speed: about 0.15 m/s lost per metre at any pace)."],
	["wallride_time", 1.2, 0.2, 4.0, 0.05, "Grind", "Longest wallride, s."],
	["lip_max_time", 2.5, 0.5, 6.0, 0.1, "Grind", "Longest lip trick, s."],
	["walk_speed", 1.6, 0.5, 3.0, 0.05, "Walk", "Walking speed at a half-tilted stick, m/s."],
	["run_speed", 4.0, 2.0, 8.0, 0.1, "Walk", "Running speed at a full stick, m/s."],
	["walk_accel", 27.0, 5.0, 80.0, 1.0, "Walk", "Walking acceleration, m/s² (the default reaches run speed in about 0.15 s)."],
	["walk_jump", 0.6, 0.2, 1.5, 0.05, "Walk", "Jump height on foot, m."],
	["getup_time", 0.6, 0.1, 2.0, 0.05, "Bail", "Get-up time after a bail, s."],
	["snap_reach_roll", 12.0, 3.0, 30.0, 0.5, "Ramp snap", "Q + E while rolling: farthest ramp lip it snaps you into, m."],
	["snap_reach_air", 15.0, 3.0, 30.0, 0.5, "Ramp snap", "Q + E in the air: farthest ramp lip it snaps you into, m."],
	["snap_drop_speed", 1.0, 0.5, 10.0, 0.25, "Ramp snap", "Slowest speed a snap drop-in starts down the wall with, m/s (gravity does the rest)."],
	["snap_out_speed", 5.0, 1.0, 12.0, 0.25, "Ramp snap", "Rolling speed after a snap out of a ramp, m/s."],
]

static var _shared: PhysicsTuning = null

var gravity: float
var max_speed: float
var kill_y: float
var push_accel: float
var push_max: float
var push_plant: float
var push_cycle: float
var push_contact: float
var brake: float
var roll_friction: float
var side_grip: float
var turn_rate: float
var turn_rate_fast: float
var carve_grip: float
var pump_accel: float
var pump_accel_vert: float
var pump_speed_ref: float
var vert_normal_y: float
var edge_grip: float
var overhang_radius: float
var ollie_min: float
var ollie_max: float
var crouch_full: float
var spin_rate: float
var air_steer: float
var flip_time: float
var double_flip_time: float
var grind_reach: float
var grind_min_speed: float
var rail_gravity: float
var rail_friction: float
var wallride_time: float
var lip_max_time: float
var walk_speed: float
var run_speed: float
var walk_accel: float
var walk_jump: float
var getup_time: float
var snap_reach_roll: float
var snap_reach_air: float
var snap_drop_speed: float
var snap_out_speed: float


func _init() -> void:
	reset()


## The tuning every skater uses unless it is given its own. The tuning panel edits this one.
static func shared() -> PhysicsTuning:
	if _shared == null:
		_shared = PhysicsTuning.new()
	return _shared


static func field_names() -> PackedStringArray:
	var out := PackedStringArray()
	for f: Array in FIELDS:
		out.append(f[0])
	return out


static func field_info(field: String) -> Dictionary:
	for f: Array in FIELDS:
		if f[0] == field:
			return {"name": f[0], "default": f[1], "min": f[2], "max": f[3], "step": f[4], "group": f[5], "doc": f[6]}
	return {}


func reset() -> void:
	for f: Array in FIELDS:
		set(f[0], float(f[1]))


## Sets one field, clamped to its range. Returns false for an unknown field.
func set_value(field: String, value: float) -> bool:
	var info: Dictionary = field_info(field)
	if info.is_empty():
		return false
	var v: float = clampf(value, float(info["min"]), float(info["max"]))
	set(field, v)
	changed.emit(field, v)
	return true


func to_dict() -> Dictionary:
	var d: Dictionary = {}
	for f: Array in FIELDS:
		d[f[0]] = get(f[0])
	return d


## Applies known keys from `d` (others are ignored). Returns the number of fields applied.
func apply_dict(d: Dictionary) -> int:
	var n: int = 0
	for key: Variant in d:
		if set_value(str(key), float(d[key])):
			n += 1
	return n


## Only the fields that differ from the defaults: what a preset needs to store.
func diff_from_defaults() -> Dictionary:
	var d: Dictionary = {}
	for f: Array in FIELDS:
		if not is_equal_approx(float(get(f[0])), float(f[1])):
			d[f[0]] = get(f[0])
	return d


func copy_from(other: PhysicsTuning) -> void:
	apply_dict(other.to_dict())


func save_json(path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t", false))
	return OK


## Loads a preset file over the current values. Returns false if the file is missing or not a JSON object.
func load_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	apply_dict(parsed)
	return true
