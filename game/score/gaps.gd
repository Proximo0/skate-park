class_name Gaps
extends RefCounted
## Gap detection for combos. A gap is a start zone entered, then an end zone entered, within one combo,
## no more than max_time seconds apart. If require is not "", the state must equal require at both the
## start entry and the end entry ("" accepts any state). Pure logic: no Node, no clock. The caller passes
## `now` (seconds) with every zone entry. Gap content lives in data/gaps.json.

signal gap_completed(gap: Dictionary, first_time: bool)

const DATA_PATH: String = "res://data/gaps.json"
const VALID_REQUIRE: PackedStringArray = ["AIR", "GRIND", "MANUAL", "WALLRIDE", ""]

## Gap id -> true, set on the first completion of that gap. Kept across combos and reset_combo().
var discovered: Dictionary = {}

var _gaps: Array[Dictionary] = []
## Gap id -> {"time": float, "state": String}: the most recent start entry, waiting for its end zone.
var _pending: Dictionary = {}


static func load_default() -> Gaps:
	var gaps: Gaps = Gaps.new()
	if not FileAccess.file_exists(DATA_PATH):
		push_error("Gaps: missing %s" % DATA_PATH)
		return gaps
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Gaps: %s is not a JSON object" % DATA_PATH)
		return gaps
	var root: Dictionary = parsed
	gaps.load_from_dict(root)
	return gaps


## Replaces the gap list with the entries of d["gaps"]. Malformed entries are reported and skipped.
## Clears pending starts. Discovery is kept.
func load_from_dict(d: Dictionary) -> void:
	_gaps.clear()
	_pending.clear()
	var raw: Variant = d.get("gaps", [])
	if typeof(raw) != TYPE_ARRAY:
		push_error("Gaps: 'gaps' is not an array")
		return
	var entries: Array = raw
	var seen: Dictionary = {}
	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("Gaps: entry is not an object")
			continue
		var source: Dictionary = entry
		var gap: Dictionary = _normalize(source)
		if gap.is_empty():
			continue
		var gap_id: String = gap["id"]
		if seen.has(gap_id):
			push_error("Gaps: duplicate id %s" % gap_id)
			continue
		seen[gap_id] = true
		_gaps.append(gap)


## Records a zone entry at time now with the player's state. Returns the gap Dictionaries (copies)
## completed by this entry. Each completion also emits gap_completed.
func enter_zone(zone_id: String, state_name: String, now: float) -> Array:
	var completed: Array = []
	for gap: Dictionary in _gaps:
		var end_zone: String = gap["end_zone"]
		if end_zone != zone_id:
			continue
		var gap_id: String = gap["id"]
		if not _pending.has(gap_id):
			continue
		var start: Dictionary = _pending[gap_id]
		var start_time: float = start["time"]
		var start_state: String = start["state"]
		if now - start_time > float(gap["max_time"]):
			_pending.erase(gap_id)
			continue
		var required: String = gap["require"]
		if required != "" and (start_state != required or state_name != required):
			continue
		_pending.erase(gap_id)
		var done: Dictionary = gap.duplicate(true)
		var first_time: bool = not discovered.has(gap_id)
		discovered[gap_id] = true
		completed.append(done)
		gap_completed.emit(done, first_time)
	# Starts are registered after completions so a gap whose start and end share a zone
	# cannot complete against its own entry.
	for gap: Dictionary in _gaps:
		var start_zone: String = gap["start_zone"]
		if start_zone == zone_id:
			var start_id: String = gap["id"]
			_pending[start_id] = {"time": now, "state": state_name}
	return completed


## Registers starts for gaps that begin in `zone_id` and require `state_name`, for a player already inside the
## zone who has just switched into that state (landing into a manual on a pad). Never completes a gap.
func start_in_zone(zone_id: String, state_name: String, now: float) -> void:
	for gap: Dictionary in _gaps:
		if gap["start_zone"] == zone_id and gap["require"] == state_name:
			_pending[str(gap["id"])] = {"time": now, "state": state_name}


## Clears all pending start entries (call when a combo lands or bails).
func reset_combo() -> void:
	_pending.clear()


func discovered_count() -> int:
	return discovered.size()


func total_count() -> int:
	return _gaps.size()


func _normalize(source: Dictionary) -> Dictionary:
	var id: String = str(source.get("id", ""))
	var start_zone: String = str(source.get("start_zone", ""))
	var end_zone: String = str(source.get("end_zone", ""))
	var required: String = str(source.get("require", ""))
	if id.is_empty() or start_zone.is_empty() or end_zone.is_empty():
		push_error("Gaps: entry needs id, start_zone and end_zone")
		return {}
	if not VALID_REQUIRE.has(required):
		push_error("Gaps: %s has invalid require '%s'" % [id, required])
		return {}
	var points: int = int(source.get("points", 0))
	var max_time: float = float(source.get("max_time", 0.0))
	return {
		"id": id,
		"name": str(source.get("name", id)),
		"points": points,
		"start_zone": start_zone,
		"end_zone": end_zone,
		"require": required,
		"max_time": max_time,
	}
