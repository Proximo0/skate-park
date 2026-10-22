class_name Goals
extends RefCounted
## Goal list and progress, loaded from data/goals.json. Pure logic: no Node, no clock.
## Callers feed events and the current time (tick). Every on_* call returns the goals it newly completed.
##
## Goal types:
## - high_score: landed_total >= target within one run (run_seconds in the file). Needs start_run(now).
##   Callers pass the run's landed_total and reset it at start_run.
## - combo: points of a single combo >= target.
## - collect: every entry of "items" collected. Duplicates count, so five "pizza" needs five pickups.
## - gaps: discovered gap count (the running total, not a delta) >= target.
## - trick: trick id "trick" landed, via on_trick or inside the tricks list of on_combo_landed.
## - special: any trick of kind "special" landed.
## - manual_time / grind_time: one hold of at least target seconds (on_hold kind "manual" / "grind").
## Progress is the best value seen, 0..1. A completed goal stays completed until reset().

signal goal_completed(goal: Dictionary)

const DATA_PATH: String = "res://data/goals.json"
const DEFAULT_RUN_SECONDS: float = 120.0
const TYPES: PackedStringArray = [
	"high_score", "combo", "collect", "gaps", "trick", "special", "manual_time", "grind_time",
]
const HOLD_TYPE_BY_KIND: Dictionary = {"manual": "manual_time", "grind": "grind_time"}

var run_seconds: float = DEFAULT_RUN_SECONDS
var load_errors: PackedStringArray = []

var _goals: Array[Dictionary] = []
var _index_by_id: Dictionary = {}
var _done: Dictionary = {}
var _progress: Dictionary = {}
var _need: Dictionary = {}
var _have: Dictionary = {}
var _run_active: bool = false
var _run_start: float = 0.0


static func load_default() -> Goals:
	var goals: Goals = Goals.new()
	goals.load_from_path(DATA_PATH)
	return goals


## Reads a goals file of the form {"run_seconds": n, "goals": [...]}. Returns false if it cannot be read.
func load_from_path(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Goals: missing %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Goals: %s is not a JSON object" % path)
		return false
	var root: Dictionary = parsed
	return load_from_dict(root)


## Replaces the goal list. Invalid entries are skipped and listed in load_errors. Returns false if "goals" is missing.
func load_from_dict(root: Dictionary) -> bool:
	_goals.clear()
	_index_by_id.clear()
	load_errors.clear()
	run_seconds = DEFAULT_RUN_SECONDS
	var rs: float = _as_number(root.get("run_seconds", DEFAULT_RUN_SECONDS))
	if not is_nan(rs) and rs > 0.0:
		run_seconds = rs
	var list: Variant = root.get("goals", null)
	if typeof(list) != TYPE_ARRAY:
		load_errors.append("goals is not an array")
		return false
	var entries: Array = list
	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			load_errors.append("goal entry is not an object")
			continue
		var raw: Dictionary = entry
		var err: String = _add_goal(raw)
		if err != "":
			load_errors.append(err)
	reset()
	return true


## Clears all progress and ends any run. The goal list stays.
func reset() -> void:
	_done.clear()
	_progress.clear()
	_need.clear()
	_have.clear()
	for goal: Dictionary in _goals:
		var id: String = goal["id"]
		_progress[id] = 0.0
		_done[id] = false
		if goal["type"] == "collect":
			var need: Dictionary = {}
			for item: String in goal["items"]:
				need[item] = int(need.get(item, 0)) + 1
			_need[id] = need
			_have[id] = {}
	_run_active = false
	_run_start = 0.0


## Marks goals done from a saved career, without emitting goal_completed (no second reward). Unknown ids are ignored.
func mark_done(ids: PackedStringArray) -> void:
	for id: String in ids:
		if _index_by_id.has(id):
			_done[id] = true
			_progress[id] = 1.0


## Every goal, in file order, as copies.
func all_goals() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for goal: Dictionary in _goals:
		out.append(goal.duplicate(true))
	return out


## One goal by id, as a copy. Empty dictionary if unknown.
func get_goal(id: String) -> Dictionary:
	if not _index_by_id.has(id):
		return {}
	return _goals[_index_by_id[id]].duplicate(true)


func completed_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for goal: Dictionary in _goals:
		var id: String = goal["id"]
		if _done[id]:
			out.append(id)
	return out


func is_completed(id: String) -> bool:
	return bool(_done.get(id, false))


## 0..1, the best progress toward the goal. Unknown id gives 0.
func progress(id: String) -> float:
	return float(_progress.get(id, 0.0))


## Starts a high_score run at time now (seconds, caller's clock). Lasts run_seconds.
func start_run(now: float) -> void:
	_run_active = true
	_run_start = now


## Ends the current run early.
func end_run() -> void:
	_run_active = false


## Call once per frame (or per physics tick) with the current time. Ends the run when its time is up.
func tick(now: float) -> void:
	if _run_active and now - _run_start >= run_seconds:
		_run_active = false


func run_active() -> bool:
	return _run_active


## Seconds left in the run at time now, 0 when no run is active.
func run_time_left(now: float) -> float:
	if not _run_active:
		return 0.0
	return clampf(_run_start + run_seconds - now, 0.0, run_seconds)


## A combo was landed. points is that combo's total, landed_total is the run's running total.
## tricks lists the tricks in the combo: trick id Strings, or dictionaries with "id" and optional "kind".
func on_combo_landed(points: int, landed_total: int, tricks: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for goal: Dictionary in _goals:
		var id: String = goal["id"]
		if _done[id]:
			continue
		var target: float = goal["target"]
		match goal["type"]:
			"combo":
				_bump(id, float(points) / target)
				if float(points) >= target:
					_complete(id, out)
			"high_score":
				if _run_active:
					_bump(id, float(landed_total) / target)
					if float(landed_total) >= target:
						_complete(id, out)
	for entry: Variant in tricks:
		if typeof(entry) == TYPE_STRING:
			_apply_trick(entry, "", out)
		elif typeof(entry) == TYPE_DICTIONARY:
			var d: Dictionary = entry
			_apply_trick(str(d.get("id", "")), str(d.get("kind", "")), out)
	return out


## One pickup of a collectible item ("S", "pizza", ...).
func on_collect(item: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for goal: Dictionary in _goals:
		var id: String = goal["id"]
		if _done[id] or goal["type"] != "collect" or not _need[id].has(item):
			continue
		var have: Dictionary = _have[id]
		var need: Dictionary = _need[id]
		have[item] = mini(int(have.get(item, 0)) + 1, int(need[item]))
		var matched: int = 0
		for k: String in have:
			matched += int(have[k])
		var total: int = goal["items"].size()
		_bump(id, float(matched) / float(total))
		if matched >= total:
			_complete(id, out)
	return out


## count is the running total of gaps discovered this session (Gaps.discovered_count()).
func on_gap_discovered(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for goal: Dictionary in _goals:
		var id: String = goal["id"]
		if _done[id] or goal["type"] != "gaps":
			continue
		var target: float = goal["target"]
		_bump(id, float(count) / target)
		if float(count) >= target:
			_complete(id, out)
	return out


## One finished hold. kind is "manual" or "grind"; seconds is how long that single hold lasted.
func on_hold(kind: String, seconds: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not HOLD_TYPE_BY_KIND.has(kind):
		return out
	var type_name: String = HOLD_TYPE_BY_KIND[kind]
	for goal: Dictionary in _goals:
		var id: String = goal["id"]
		if _done[id] or goal["type"] != type_name:
			continue
		var target: float = goal["target"]
		_bump(id, seconds / target)
		if seconds >= target:
			_complete(id, out)
	return out


## A trick was landed. kind is the trick's kind from data/tricks.json ("flip", "grab", "grind", "lip", "manual", "special").
func on_trick(id: String, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_apply_trick(id, kind, out)
	return out


func _apply_trick(id: String, kind: String, out: Array[Dictionary]) -> void:
	for goal: Dictionary in _goals:
		var gid: String = goal["id"]
		if _done[gid]:
			continue
		if goal["type"] == "trick" and id != "" and goal["trick"] == id:
			_complete(gid, out)
		elif goal["type"] == "special" and kind == "special":
			_complete(gid, out)


func _complete(id: String, out: Array[Dictionary]) -> void:
	if _done[id]:
		return
	_done[id] = true
	_progress[id] = 1.0
	var goal: Dictionary = _goals[_index_by_id[id]]
	var copy: Dictionary = goal.duplicate(true)
	out.append(copy)
	goal_completed.emit(copy.duplicate(true))


func _bump(id: String, ratio: float) -> void:
	_progress[id] = maxf(float(_progress[id]), clampf(ratio, 0.0, 1.0))


## Validates one raw entry and appends it. Returns "" on success, else the reason it was skipped.
func _add_goal(raw: Dictionary) -> String:
	var id: String = _str_field(raw, "id")
	if id == "":
		return "goal without id"
	if _index_by_id.has(id):
		return "%s: duplicate id" % id
	var title: String = _str_field(raw, "title")
	if title == "":
		return "%s: missing title" % id
	var type_name: String = _str_field(raw, "type")
	if not TYPES.has(type_name):
		return "%s: unknown type '%s'" % [id, type_name]
	var goal: Dictionary = {
		"id": id,
		"title": title,
		"description": _str_field(raw, "description"),
		"type": type_name,
		"target": 1.0,
	}
	match type_name:
		"collect":
			var items: Array[String] = []
			var list: Variant = raw.get("items", null)
			if typeof(list) != TYPE_ARRAY:
				return "%s: collect needs an items array" % id
			var entries: Array = list
			for entry: Variant in entries:
				if typeof(entry) != TYPE_STRING or entry == "":
					return "%s: collect items must be non-empty strings" % id
				items.append(entry)
			if items.is_empty():
				return "%s: collect needs at least one item" % id
			goal["items"] = items
			goal["target"] = float(items.size())
		"trick":
			var trick: String = _str_field(raw, "trick")
			if trick == "":
				return "%s: trick goal needs a trick id" % id
			goal["trick"] = trick
		"special":
			pass
		_:
			var target: float = _as_number(raw.get("target", NAN))
			if is_nan(target) or target <= 0.0:
				return "%s: target must be a number above 0" % id
			goal["target"] = target
	_goals.append(goal)
	_index_by_id[id] = _goals.size() - 1
	_progress[id] = 0.0
	_done[id] = false
	return ""


func _str_field(raw: Dictionary, key: String) -> String:
	var v: Variant = raw.get(key, "")
	return v if typeof(v) == TYPE_STRING else ""


func _as_number(v: Variant) -> float:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return float(v)
	return NAN
