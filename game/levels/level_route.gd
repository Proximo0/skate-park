class_name LevelRoute
extends RefCounted
## A level's play-bot route, stored as JSON next to the level (game/levels/<id>/bot_route.json) and turned into the
## waypoint dictionaries the bot's driver (tests/bot/bot_driver.gd) follows. The practice park keeps its code-built
## routes (tests/bot/bot_lines.gd); every other level uses a file like this:
##
##   {"lines": [
##     {"name": "cruise", "limit": 30, "soft": false, "expect": ["Some Gap Name"],
##      "wps": [
##        {"tp": {"pos": [0, 0.1, 20], "dir": [0, 0, -1], "speed": 4}},
##        {"p": [0, 0, 6], "spd": 7, "r": 2.0},
##        {"p": [0, 0, -6], "spd": 8, "act": "ollie", "h": 10}
##      ]}
##   ]}
##
## Keys are the BotDriver waypoint keys (p, spd, r, act, tmo, pump, brake, tp, drop, ...). Any 3-number array under
## a key in VEC_KEYS becomes a Vector3. `limit` is the line's time limit in sim seconds.

const VEC_KEYS: Array[String] = ["p", "pos", "dir", "end"]


## {"lines": [...]} with Vector3s converted, or {} when the file is missing or broken.
static func load_file(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("LevelRoute: %s is not a JSON object" % path)
		return {}
	return from_dict(parsed as Dictionary)


static func from_dict(d: Dictionary) -> Dictionary:
	var out: Dictionary = {"lines": []}
	for raw: Variant in d.get("lines", []):
		if not (raw is Dictionary):
			continue
		var line: Dictionary = _convert(raw) as Dictionary
		line["name"] = str(line.get("name", "line%d" % (out["lines"] as Array).size()))
		line["limit"] = float(line.get("limit", 30.0))
		line["soft"] = bool(line.get("soft", false))
		if not line.has("expect"):
			line["expect"] = []
		if not line.has("wps"):
			line["wps"] = []
		(out["lines"] as Array).append(line)
	return out


## Names of the lines in a loaded route.
static func line_names(route: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for l: Dictionary in route.get("lines", []):
		out.append(str(l["name"]))
	return out


## The line called `line_name`, or {}.
static func line(route: Dictionary, line_name: String) -> Dictionary:
	for l: Dictionary in route.get("lines", []):
		if str(l["name"]) == line_name:
			return l.duplicate(true)
	return {}


## Every position a route visits (teleports and waypoints), for checks.
static func points(route: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for l: Dictionary in route.get("lines", []):
		for w: Dictionary in l.get("wps", []):
			if w.has("p"):
				out.append(w["p"] as Vector3)
			if w.has("tp"):
				out.append((w["tp"] as Dictionary)["pos"] as Vector3)
	return out


static func _convert(v: Variant, key: String = "") -> Variant:
	if v is Dictionary:
		var d: Dictionary = {}
		for k: Variant in (v as Dictionary):
			d[str(k)] = _convert((v as Dictionary)[k], str(k))
		return d
	if v is Array:
		var a: Array = v
		if VEC_KEYS.has(key) and a.size() == 3:
			return Vector3(float(a[0]), float(a[1]), float(a[2]))
		var out: Array = []
		for x: Variant in a:
			out.append(_convert(x))
		return out
	return v
