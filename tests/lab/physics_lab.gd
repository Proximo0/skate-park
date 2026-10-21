extends Node
## Headless physics lab: runs scripted manoeuvres (lab_moves.gd) and prints a metrics table against data/physics_targets.json.
## Run via tools/physics_report.sh, or: godot --headless --fixed-fps 60 --path . res://tests/lab/physics_lab.tscn -- [--tune=preset.json] [--only=prefix]
## Output: `LAB <metric> <value> <unit> target=<t> ok=[min,max] PASS|WARN`, `LAB summary pass=N warn=M`, /tmp/lab/report.json and
## /tmp/lab/report.md. Exit code 0 even with WARNs (it is a report, not a gate); 1 only when a manoeuvre crashed.

const TARGETS_PATH: String = "res://data/physics_targets.json"
const OUT_DIR: String = "/tmp/lab"


func _ready() -> void:
	var tune_path: String = ""
	var only: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tune="):
			tune_path = a.substr(7)
		elif a.begins_with("--only="):
			only = a.substr(7)
	var tuning_note: String = _apply_tune(tune_path)
	var targets: Dictionary = _load_json(TARGETS_PATH)
	var moves_script: GDScript = load("res://tests/lab/lab_moves.gd") as GDScript
	var moves: Variant = moves_script.new()
	moves.host = self
	var crashed: Array = []
	var results: Dictionary = {}  ## metric -> value (String for x_ diagnostics)
	for row: Array in moves_script.table():
		var fn: String = row[0]
		var names: Array = row[1]
		if only != "" and not names.any(func(n: String) -> bool: return n.begins_with(only)):
			continue
		var out: Variant = await moves.call(fn)
		if not (out is Dictionary):
			crashed.append(fn)
			print("LAB crash %s returned no result (script error inside the manoeuvre)" % fn)
			continue
		for k: String in out:
			if k.begins_with("x_") or only == "" or k.begins_with(only):
				results[k] = out[k]
	var metrics: Dictionary = {}
	var info: Dictionary = {}
	var passed: int = 0
	var warned: int = 0
	var md: PackedStringArray = ["| metric | value | unit | target | ok range | status |", "|---|---:|---|---:|---|---|"]
	var keys: Array = results.keys()
	for k: String in keys:
		if k.begins_with("x_"):
			info[k] = results[k]
			print("LABINFO %s %s" % [k, str(results[k])])
			continue
		var v: float = float(results[k])
		var t: Dictionary = targets.get(k, {})
		if t.is_empty():
			metrics[k] = {"value": v, "status": "NOTARGET"}
			print("LAB %s %.3f - no target" % [k, v])
			continue
		var lo: float = float(t["min_ok"])
		var hi: float = float(t["max_ok"])
		var ok: bool = is_finite(v) and v >= lo and v <= hi
		var status: String = "PASS" if ok else "WARN"
		if ok:
			passed += 1
		else:
			warned += 1
		metrics[k] = {"value": v, "unit": t["unit"], "target": t["target"], "min_ok": lo, "max_ok": hi, "status": status}
		print("LAB %s %.3f %s target=%s ok=[%s,%s] %s" % [k, v, t["unit"], _n(t["target"]), _n(lo), _n(hi), status])
		md.append("| %s | %.3f | %s | %s | %s to %s | %s |" % [k, v, t["unit"], _n(t["target"]), _n(lo), _n(hi), status])
	print("LAB summary pass=%d warn=%d" % [passed, warned])
	_write(metrics, info, passed, warned, tuning_note, md, crashed)
	get_tree().quit(1 if not crashed.is_empty() else 0)


func _n(x: Variant) -> String:
	return String.num(float(x), 3)


## Applies a preset to PhysicsTuning.shared() when that class exists. Returns a note for the report.
func _apply_tune(path: String) -> String:
	if path == "":
		return "defaults"
	var script: GDScript = null
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c["class"] == "PhysicsTuning":
			script = load(c["path"]) as GDScript
	if script == null:
		print("LABINFO tune PhysicsTuning class not found: preset %s ignored" % path)
		return "preset ignored (no PhysicsTuning class)"
	var d: Dictionary = _load_json(path)
	if d.has("tuning") and d["tuning"] is Dictionary:
		d = d["tuning"]
	var shared: Variant = script.call("shared")
	var n: int = shared.apply_dict(d)
	print("LABINFO tune applied %d fields from %s" % [n, path])
	return "preset %s (%d fields)" % [path, n]


func _load_json(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _tuning_dict() -> Dictionary:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c["class"] == "PhysicsTuning":
			var script: GDScript = load(c["path"]) as GDScript
			var shared: Variant = script.call("shared")
			return shared.diff_from_defaults()
	return {}


func _write(metrics: Dictionary, info: Dictionary, passed: int, warned: int, tuning_note: String, md: PackedStringArray, crashed: Array) -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var report: Dictionary = {"version": 1, "tuning": tuning_note, "tuning_diff": _tuning_dict(), "metrics": metrics, "info": info,
		"summary": {"pass": passed, "warn": warned, "crashed": crashed}}
	var f: FileAccess = FileAccess.open(OUT_DIR + "/report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	var text: String = "# Physics lab report\n\nTuning: %s\n\n" % tuning_note + "\n".join(md) + "\n\npass=%d warn=%d\n" % [passed, warned]
	var m: FileAccess = FileAccess.open(OUT_DIR + "/report.md", FileAccess.WRITE)
	m.store_string(text)
	m.close()
