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
## - pickup: like collect, but the items are hidden pickups the goals file itself places ("pickups": zone entries that
##   GoalPickup.spawn puts over the level's gap zones), so the level scripts do not have to.
## - gaps: discovered gap count (the running total, not a delta) >= target.
## - trick: trick id "trick" landed, via on_trick or inside the tricks list of on_combo_landed.
## - special: any trick of kind "special" landed.
## - manual_time / grind_time: one hold of at least target seconds (on_hold kind "manual" / "grind").
## - manual_distance / grind_distance: one manual or grind of at least target metres (on_distance).
## - named_gap: the gap with id (or name) "gap" is hit (on_gap_event). The landmark goals use this.
## - gap_trick: land a combo that holds the gap "gap" and the trick "trick" (an id) or any trick of kind "trick_kind".
## - combo_trick: land a combo of at least target points that holds the trick "trick" / kind "trick_kind".
## - combo_distinct: land one combo holding at least target different trick ids.
## - gap_chain: land one combo holding at least target different gaps.
## - timed_gaps: target different gaps inside "seconds" seconds (on_gap_event with the caller's clock).
## - streak: land target combos in a row without a bail.
## - pro_challenge: one tier (bronze / silver / gold, "tier") of a level's Pro Challenge. Needs a running timed run. Lands a
##   combo that holds at least "chain" different gaps of the signature list "gaps" (ids or names) and is worth at least
##   "combo" points, while the run's landed_total is at least "score" (the target; 5:00 runs double it like high_score) and
##   no more than "within" seconds (of a 2:00 run, scaled with the session) have passed since the run started (0 = no limit).
## Combo-shaped goals read a buffer of what the running combo holds (on_trick, on_gap_event); on_combo_landed judges
## and clears it, on_combo_bailed clears it and breaks the streak.
## A session (set_session) picks the run: 2:00 is the file's own, 5:00 doubles every high_score target, free skate has
## no clock and parks the high_score goals (is_active false).
## Progress is the best value seen, 0..1. A completed goal stays completed until reset().

signal goal_completed(goal: Dictionary)

const DATA_PATH: String = "res://data/goals.json"
const DEFAULT_RUN_SECONDS: float = 120.0
const TYPES: PackedStringArray = [
	"high_score", "combo", "collect", "pickup", "gaps", "trick", "special", "manual_time", "grind_time",
	"manual_distance", "grind_distance", "named_gap", "gap_trick", "combo_trick", "combo_distinct", "gap_chain",
	"timed_gaps", "streak", "pro_challenge",
]
const PRO_TIERS: PackedStringArray = ["bronze", "silver", "gold"]
const DISTANCE_TYPE_BY_KIND: Dictionary = {"manual": "manual_distance", "grind": "grind_distance"}
## Score targets grow with the run length: a 5 minute run asks twice the 2 minute points.
const SCORE_SCALE_5MIN: float = 2.0
const SCORE_ROUND: float = 500.0
const HOLD_TYPE_BY_KIND: Dictionary = {"manual": "manual_time", "grind": "grind_time"}

var run_seconds: float = DEFAULT_RUN_SECONDS
var untimed: bool = false  ## free skate: the run never ends and the high_score goals are parked
var pickups: Array[Dictionary] = []  ## hidden pickups the file asks for: {"item", "zone", "dy"}
var load_errors: PackedStringArray = []

var _goals: Array[Dictionary] = []
var _index_by_id: Dictionary = {}
var _done: Dictionary = {}
var _progress: Dictionary = {}
var _need: Dictionary = {}
var _have: Dictionary = {}
var _run_active: bool = false
var _run_start: float = 0.0
var _file_run_seconds: float = DEFAULT_RUN_SECONDS
var _combo_tricks: Array[Dictionary] = []  ## {"id", "kind"} of what the running combo holds
var _combo_gaps: Array[String] = []  ## gap ids the running combo holds
var _combo_gap_names: Array[String] = []  ## their display names (a goal may name either)
var _gap_log: Array[Dictionary] = []  ## {"id", "t"} of recent gaps, for timed_gaps
var _streak: int = 0
var _now: float = 0.0  ## the caller's clock as last seen (tick, start_run, on_gap_event)


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
	pickups.clear()
	untimed = false
	run_seconds = DEFAULT_RUN_SECONDS
	var rs: float = _as_number(root.get("run_seconds", DEFAULT_RUN_SECONDS))
	if not is_nan(rs) and rs > 0.0:
		run_seconds = rs
	_file_run_seconds = run_seconds
	var pk: Variant = root.get("pickups", [])
	if typeof(pk) == TYPE_ARRAY:
		for entry: Variant in pk as Array:
			if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("item", "")) != "" \
					and str((entry as Dictionary).get("zone", "")) != "":
				pickups.append((entry as Dictionary).duplicate(true))
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


## Picks the session: seconds <= 0 is free skate (no clock, high_score goals parked), 120 the file's own run, any
## other length rescales the high_score targets (300 s asks double). Call before start_run. Titles and descriptions
## of the scaled goals are rewritten to match.
func set_session(seconds: float) -> void:
	untimed = seconds <= 0.0
	run_seconds = _file_run_seconds if untimed else seconds
	var scale: float = 1.0
	if not untimed and run_seconds > _file_run_seconds * 1.5:
		scale = SCORE_SCALE_5MIN
	for goal: Dictionary in _goals:
		if not _is_timed_type(str(goal["type"])):
			continue
		var base: float = goal["base_target"]
		var target: float = base if scale == 1.0 else roundf(base * scale / SCORE_ROUND) * SCORE_ROUND
		goal["target"] = target
		goal["title"] = _retitle(str(goal["base_title"]), base, target)
		goal["description"] = _retitle(str(goal["base_description"]), base, target)
		if scale != 1.0 and goal["description"] != "":
			goal["description"] = str(goal["description"]).replace("2-minute", "%d-minute" % int(run_seconds / 60.0))
		elif untimed and goal["description"] != "":
			goal["description"] = "Timed runs only. Pick 2:00 or 5:00 on the level select."


## False for goals the session parks (the high_score goals in free skate).
func is_active(id: String) -> bool:
	if not untimed or not _index_by_id.has(id):
		return true
	return not _is_timed_type(str(_goals[_index_by_id[id]]["type"]))


## The goal types a free-skate session parks and a 5 minute session scales: they need a timed run.
static func _is_timed_type(type_name: String) -> bool:
	return type_name == "high_score" or type_name == "pro_challenge"


## "Pro Score: 30,000" with 30000 -> 60000 gives "Pro Score: 60,000".
static func _retitle(text: String, base: float, target: float) -> String:
	if is_equal_approx(base, target):
		return text
	return text.replace(_commas(int(base)), _commas(int(target)))


static func _commas(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	for i: int in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out


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
		if goal["type"] in ["collect", "pickup"]:
			var need: Dictionary = {}
			for item: String in goal["items"]:
				need[item] = int(need.get(item, 0)) + 1
			_need[id] = need
			_have[id] = {}
	_run_active = false
	_run_start = 0.0
	_combo_tricks.clear()
	_combo_gaps.clear()
	_combo_gap_names.clear()
	_gap_log.clear()
	_streak = 0


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
	_now = now
	_combo_tricks.clear()
	_combo_gaps.clear()
	_combo_gap_names.clear()
	_gap_log.clear()
	_streak = 0


## Ends the current run early.
func end_run() -> void:
	_run_active = false


## Call once per frame (or per physics tick) with the current time. Ends the run when its time is up.
func tick(now: float) -> void:
	_now = now
	if _run_active and not untimed and now - _run_start >= run_seconds:
		_run_active = false


func run_active() -> bool:
	return _run_active


## Seconds left in the run at time now, 0 when no run is active.
func run_time_left(now: float) -> float:
	if not _run_active or untimed:
		return 0.0
	return clampf(_run_start + run_seconds - now, 0.0, run_seconds)


## A combo was landed. points is that combo's total, landed_total is the run's running total.
## tricks lists the tricks in the combo: trick id Strings, or dictionaries with "id" and optional "kind". Whatever
## on_trick / on_gap_event buffered for this combo counts too.
func on_combo_landed(points: int, landed_total: int, tricks: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var held: Array[Dictionary] = _combo_tricks.duplicate()
	for entry: Variant in tricks:
		if typeof(entry) == TYPE_STRING:
			held.append({"id": entry, "kind": ""})
		elif typeof(entry) == TYPE_DICTIONARY:
			var d: Dictionary = entry
			held.append({"id": str(d.get("id", "")), "kind": str(d.get("kind", ""))})
	var gaps_held: Array[String] = _combo_gaps.duplicate()
	var names_held: Array[String] = _combo_gap_names.duplicate()
	_combo_tricks.clear()
	_combo_gaps.clear()
	_combo_gap_names.clear()
	_streak += 1
	var distinct: Dictionary = {}
	for h: Dictionary in held:
		if str(h["id"]) != "":
			distinct[str(h["id"])] = true
	for goal: Dictionary in _goals:
		var id: String = goal["id"]
		if _done[id] or not is_active(id):
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
			"combo_trick":
				if _holds_trick(goal, held):
					_bump(id, float(points) / target)
					if float(points) >= target:
						_complete(id, out)
			"combo_distinct":
				_bump(id, float(distinct.size()) / target)
				if float(distinct.size()) >= target:
					_complete(id, out)
			"gap_chain":
				_bump(id, float(gaps_held.size()) / target)
				if float(gaps_held.size()) >= target:
					_complete(id, out)
			"gap_trick":
				if gaps_held.has(str(goal["gap"])) or names_held.has(str(goal["gap"])):
					if _holds_trick(goal, held):
						_complete(id, out)
					else:
						_bump(id, 0.5)
			"streak":
				_bump(id, float(_streak) / target)
				if float(_streak) >= target:
					_complete(id, out)
			"pro_challenge":
				if _run_active:
					_judge_pro(goal, points, landed_total, gaps_held, names_held, out)
	for h: Dictionary in held:
		_apply_trick(str(h["id"]), str(h["kind"]), out)
	return out


## One pro challenge tier against a landed combo. Progress is the mean of the three asks (score, chain, combo).
func _judge_pro(goal: Dictionary, points: int, landed_total: int, gaps_held: Array[String], names_held: Array[String], out: Array[Dictionary]) -> void:
	var id: String = goal["id"]
	var within: float = float(goal.get("within", 0.0))
	if within > 0.0 and _now - _run_start > within * run_seconds / _file_run_seconds:
		return  # too slow for this medal
	var chain: int = 0
	for g: Variant in goal["gaps"] as Array:
		if gaps_held.has(str(g)) or names_held.has(str(g)):
			chain += 1
	var need_chain: float = float(goal["chain"])
	var need_combo: float = float(goal["combo"])
	var parts: Array[float] = [minf(float(landed_total) / float(goal["target"]), 1.0), minf(float(chain) / need_chain, 1.0)]
	if need_combo > 0.0:
		parts.append(minf(float(points) / need_combo, 1.0))
	var sum: float = 0.0
	for x: float in parts:
		sum += x
	_bump(id, sum / float(parts.size()) * 0.99)
	if sum >= float(parts.size()) - 0.0001:
		_complete(id, out)


## The combo was bailed: what it held counts for nothing and the streak starts again.
func on_combo_bailed() -> void:
	_combo_tricks.clear()
	_combo_gaps.clear()
	_combo_gap_names.clear()
	_streak = 0


## What the running combo holds, for the HUD and tests: {"tricks": [ids], "gaps": [gap ids]}.
func combo_holds() -> Dictionary:
	var ids: Array[String] = []
	for h: Dictionary in _combo_tricks:
		ids.append(str(h["id"]))
	return {"tricks": ids, "gaps": _combo_gaps.duplicate()}


## One pickup of a collectible item ("S", "pizza", ...).
func on_collect(item: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for goal: Dictionary in _goals:
		var id: String = goal["id"]
		if _done[id] or not (goal["type"] in ["collect", "pickup"]) or not _need[id].has(item):
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


## A real gap (from data/gaps.json) was completed at time now: id and display name. Finishes named_gap goals, feeds
## timed_gaps, and goes into the running combo for gap_trick and gap_chain.
func on_gap_event(gap_id: String, gap_name: String, now: float) -> Array[Dictionary]:
	_now = maxf(_now, now)
	var out: Array[Dictionary] = []
	var key: String = gap_id if gap_id != "" else gap_name
	if key != "" and not _combo_gaps.has(key):
		_combo_gaps.append(key)
	if gap_name != "" and not _combo_gap_names.has(gap_name):
		_combo_gap_names.append(gap_name)
	_gap_log.append({"id": gap_id, "t": now})
	while _gap_log.size() > 32:
		_gap_log.remove_at(0)
	for goal: Dictionary in _goals:
		var id: String = goal["id"]
		if _done[id] or not is_active(id):
			continue
		match goal["type"]:
			"named_gap":
				if str(goal["gap"]) in [gap_id, gap_name]:
					_complete(id, out)
			"timed_gaps":
				var seen: Dictionary = {}
				for e: Dictionary in _gap_log:
					if now - float(e["t"]) <= float(goal["seconds"]):
						seen[str(e["id"])] = true
				var n: int = seen.size()
				_bump(id, float(n) / float(goal["target"]))
				if float(n) >= float(goal["target"]):
					_complete(id, out)
	return out


## One finished manual or grind: kind is "manual" or "grind", meters is how far that single hold went.
func on_distance(kind: String, meters: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DISTANCE_TYPE_BY_KIND.has(kind):
		return out
	var type_name: String = DISTANCE_TYPE_BY_KIND[kind]
	for goal: Dictionary in _goals:
		var id: String = goal["id"]
		if _done[id] or goal["type"] != type_name:
			continue
		var target: float = goal["target"]
		_bump(id, meters / target)
		if meters >= target:
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
	if id != "":
		_combo_tricks.append({"id": id, "kind": kind})
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


func _holds_trick(goal: Dictionary, held: Array[Dictionary]) -> bool:
	var want_id: String = str(goal.get("trick", ""))
	var want_kind: String = str(goal.get("trick_kind", ""))
	for h: Dictionary in held:
		if want_id != "" and str(h["id"]) == want_id:
			return true
		if want_kind != "" and str(h["kind"]) == want_kind:
			return true
	return false


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
		"collect", "pickup":
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
		"named_gap", "gap_trick":
			var gap: String = _str_field(raw, "gap")
			if gap == "":
				return "%s: %s needs a gap id" % [id, type_name]
			goal["gap"] = gap
			if type_name == "gap_trick":
				if _str_field(raw, "trick") == "" and _str_field(raw, "trick_kind") == "":
					return "%s: gap_trick needs a trick or trick_kind" % id
				goal["trick"] = _str_field(raw, "trick")
				goal["trick_kind"] = _str_field(raw, "trick_kind")
		"combo_trick":
			if _str_field(raw, "trick") == "" and _str_field(raw, "trick_kind") == "":
				return "%s: combo_trick needs a trick or trick_kind" % id
			var ct: float = _as_number(raw.get("target", NAN))
			if is_nan(ct) or ct <= 0.0:
				return "%s: target must be a number above 0" % id
			goal["target"] = ct
			goal["trick"] = _str_field(raw, "trick")
			goal["trick_kind"] = _str_field(raw, "trick_kind")
		"pro_challenge":
			var tier: String = _str_field(raw, "tier")
			if not PRO_TIERS.has(tier):
				return "%s: pro_challenge tier must be bronze, silver or gold" % id
			var sc: float = _as_number(raw.get("score", NAN))
			if is_nan(sc) or sc <= 0.0:
				return "%s: pro_challenge needs a score above 0" % id
			var gl: Variant = raw.get("gaps", null)
			if typeof(gl) != TYPE_ARRAY or (gl as Array).is_empty():
				return "%s: pro_challenge needs a gaps array" % id
			var gaps_list: Array[String] = []
			for gx: Variant in gl as Array:
				if typeof(gx) != TYPE_STRING or gx == "":
					return "%s: pro_challenge gaps must be non-empty strings" % id
				gaps_list.append(gx)
			goal["target"] = sc
			goal["tier"] = tier
			goal["gaps"] = gaps_list
			goal["chain"] = clampi(int(_as_number(raw.get("chain", 1.0))), 1, gaps_list.size())
			goal["combo"] = maxf(_as_number(raw.get("combo", 0.0)), 0.0) if not is_nan(_as_number(raw.get("combo", 0.0))) else 0.0
			goal["within"] = maxf(_as_number(raw.get("within", 0.0)), 0.0) if not is_nan(_as_number(raw.get("within", 0.0))) else 0.0
		"timed_gaps":
			var tg: float = _as_number(raw.get("target", NAN))
			var secs: float = _as_number(raw.get("seconds", NAN))
			if is_nan(tg) or tg <= 0.0 or is_nan(secs) or secs <= 0.0:
				return "%s: timed_gaps needs a target and seconds above 0" % id
			goal["target"] = tg
			goal["seconds"] = secs
		_:
			var target: float = _as_number(raw.get("target", NAN))
			if is_nan(target) or target <= 0.0:
				return "%s: target must be a number above 0" % id
			goal["target"] = target
	if _is_timed_type(type_name):  # kept so set_session can rescale from the file's own numbers
		goal["base_target"] = goal["target"]
		goal["base_title"] = title
		goal["base_description"] = goal["description"]
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
