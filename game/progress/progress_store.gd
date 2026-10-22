class_name ProgressStore
extends RefCounted
## The player's career: per-level best score, best combo and completed goals, the coach tips already shown, and the
## "unlock everything" switch. Saved as JSON at user://progress.json (the wallet keeps its own coins and owned items in
## user://wallet.json). A missing, unreadable or corrupt file gives a fresh career, never an error.
## Scripted runs (tests, bots, captures, headless) use shared() as an in-memory store that is never written.
##
## Career gating: practice and warehouse are always open; the other levels open once enough goals are done across all
## levels (UNLOCK_AT). `unlock_all` (a toggle on the level select) opens everything.

const SAVE_PATH: String = "user://progress.json"
const VERSION: int = 1
const GOALS_FALLBACK: String = "res://data/goals.json"
## Goals done (over every level) a level needs before it opens. Missing id = open from the start.
const UNLOCK_AT: Dictionary = {"beach": 3, "school": 6, "downtown": 10, "hills": 15}

static var _shared: ProgressStore = null

var unlock_all: bool = false
var path: String = ""  ## where save() writes; "" keeps the store in memory only
var _levels: Dictionary = {}  ## level id -> {"best_score": int, "best_combo": int, "goals": [ids], "runs": int}
var _tips: Dictionary = {}  ## tip id -> true


## The game-wide store. Loaded from user://progress.json on first use, except in scripted runs (memory only).
static func shared() -> ProgressStore:
	if _shared == null:
		if Flags.is_scripted_run():
			_shared = ProgressStore.new()
		else:
			_shared = ProgressStore.load_file(SAVE_PATH)
	return _shared


## Drops the shared store (tests).
static func reset_shared() -> void:
	_shared = null


## Reads a saved career. Missing or broken file gives a fresh store that will save to `file`.
static func load_file(file: String = SAVE_PATH) -> ProgressStore:
	var s: ProgressStore = ProgressStore.new()
	s.path = file
	if not FileAccess.file_exists(file):
		return s
	var json := JSON.new()  # parse() reports a bad file as a code, not an engine error
	if json.parse(FileAccess.get_file_as_string(file)) == OK and typeof(json.data) == TYPE_DICTIONARY:
		s.from_dict(json.data as Dictionary)
	return s


func to_dict() -> Dictionary:
	var lv: Dictionary = {}
	for id: String in _levels:
		var e: Dictionary = _levels[id]
		lv[id] = {
			"best_score": int(e["best_score"]), "best_combo": int(e["best_combo"]),
			"goals": (e["goals"] as Array).duplicate(), "runs": int(e["runs"]),
		}
	return {"version": VERSION, "unlock_all": unlock_all, "levels": lv, "tips": _tips.keys()}


## Replaces the contents; anything of the wrong type is ignored.
func from_dict(d: Dictionary) -> void:
	_levels.clear()
	_tips.clear()
	var ua: Variant = d.get("unlock_all", false)
	unlock_all = typeof(ua) == TYPE_BOOL and ua
	var lv: Variant = d.get("levels", {})
	if typeof(lv) == TYPE_DICTIONARY:
		var levels: Dictionary = lv
		for id: Variant in levels:
			var raw: Variant = levels[id]
			if typeof(id) != TYPE_STRING or typeof(raw) != TYPE_DICTIONARY:
				continue
			var e: Dictionary = _entry(str(id))
			var rd: Dictionary = raw
			e["best_score"] = maxi(_int(rd.get("best_score", 0)), 0)
			e["best_combo"] = maxi(_int(rd.get("best_combo", 0)), 0)
			e["runs"] = maxi(_int(rd.get("runs", 0)), 0)
			var gl: Variant = rd.get("goals", [])
			if typeof(gl) == TYPE_ARRAY:
				for g: Variant in gl as Array:
					if typeof(g) == TYPE_STRING and not (e["goals"] as Array).has(g):
						(e["goals"] as Array).append(g)
	var tips: Variant = d.get("tips", [])
	if typeof(tips) == TYPE_ARRAY:
		for t: Variant in tips as Array:
			if typeof(t) == TYPE_STRING:
				_tips[t] = true


func save() -> bool:
	if path == "":
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return true


# --- levels ---------------------------------------------------------------------------------------------------

func best_score(level_id: String) -> int:
	return int(_levels[level_id]["best_score"]) if _levels.has(level_id) else 0


func best_combo(level_id: String) -> int:
	return int(_levels[level_id]["best_combo"]) if _levels.has(level_id) else 0


func runs(level_id: String) -> int:
	return int(_levels[level_id]["runs"]) if _levels.has(level_id) else 0


func goals_done(level_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if _levels.has(level_id):
		for g: Variant in _levels[level_id]["goals"] as Array:
			out.append(str(g))
	return out


func goals_done_count(level_id: String) -> int:
	return (_levels[level_id]["goals"] as Array).size() if _levels.has(level_id) else 0


func total_goals_done() -> int:
	var n: int = 0
	for id: String in _levels:
		n += (_levels[id]["goals"] as Array).size()
	return n


## Records a finished (or ongoing) run: raises the bests, adds the goal ids. Returns what is new:
## {"score": bool, "combo": bool, "goals": PackedStringArray}. A zero score or combo is never a record.
func record_run(level_id: String, score: int, combo: int, goal_ids: PackedStringArray) -> Dictionary:
	var e: Dictionary = _entry(level_id)
	var rec: Dictionary = {"score": false, "combo": false, "goals": PackedStringArray()}
	if score > int(e["best_score"]):
		e["best_score"] = score
		rec["score"] = true
	if combo > int(e["best_combo"]):
		e["best_combo"] = combo
		rec["combo"] = true
	e["runs"] = int(e["runs"]) + 1
	var have: Array = e["goals"]
	var fresh: PackedStringArray = []
	for g: String in goal_ids:
		if not have.has(g):
			have.append(g)
			fresh.append(g)
	rec["goals"] = fresh
	return rec


## One goal completed mid-run (so a quit still keeps it). True when it was not known before.
func add_goal(level_id: String, goal_id: String) -> bool:
	var have: Array = _entry(level_id)["goals"]
	if have.has(goal_id):
		return false
	have.append(goal_id)
	return true


## Raises the bests without counting a run (an ongoing run's score, kept if the player quits).
func note_bests(level_id: String, score: int, combo: int) -> void:
	var e: Dictionary = _entry(level_id)
	e["best_score"] = maxi(int(e["best_score"]), score)
	e["best_combo"] = maxi(int(e["best_combo"]), combo)


# --- career ---------------------------------------------------------------------------------------------------

## How many goals a level has (its goals.json, else the shared one). 0 if unreadable.
static func goal_total(level_id: String) -> int:
	var file: String = "res://game/levels/%s/goals.json" % level_id
	if not FileAccess.file_exists(file):
		file = GOALS_FALLBACK
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var list: Variant = (parsed as Dictionary).get("goals", [])
	return (list as Array).size() if typeof(list) == TYPE_ARRAY else 0


## 0 to 3 stars: one for any goal, two for half of them, three for all.
static func stars_for(done: int, total: int) -> int:
	if done <= 0 or total <= 0:
		return 0
	if done >= total:
		return 3
	return 2 if done * 2 >= total else 1


func stars(level_id: String) -> int:
	return stars_for(goals_done_count(level_id), goal_total(level_id))


## Goals still needed before the level opens (0 = open).
func goals_to_unlock(level_id: String) -> int:
	if unlock_all or not UNLOCK_AT.has(level_id):
		return 0
	return maxi(int(UNLOCK_AT[level_id]) - total_goals_done(), 0)


func is_unlocked(level_id: String) -> bool:
	return goals_to_unlock(level_id) == 0


# --- coach tips -----------------------------------------------------------------------------------------------

func tip_seen(id: String) -> bool:
	return _tips.has(id)


func mark_tip(id: String) -> void:
	_tips[id] = true


func _entry(level_id: String) -> Dictionary:
	if not _levels.has(level_id):
		_levels[level_id] = {"best_score": 0, "best_combo": 0, "goals": [], "runs": 0}
	return _levels[level_id]


static func _int(v: Variant) -> int:
	return int(v) if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT else 0
