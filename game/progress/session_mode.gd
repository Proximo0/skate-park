class_name SessionMode
extends RefCounted
## The three ways to run a level, picked on the level select and kept in the career (ProgressStore.session):
## a 2:00 run (the default, the file's own clock), a 5:00 run (high_score targets double) and free skate (no clock,
## the high_score goals wait for a timed run).

const DEFAULT_ID: String = "2min"
const MODES: Array[Dictionary] = [
	{"id": "2min", "label": "2:00 Run", "short": "2:00", "seconds": 120.0, "blurb": "2:00 on the clock. Hit the goals."},
	{"id": "5min", "label": "5:00 Run", "short": "5:00", "seconds": 300.0, "blurb": "5:00 of lines. Score goals count x2."},
	{"id": "free", "label": "Free Skate", "short": "FREE", "seconds": 0.0, "blurb": "No clock. Hunt gaps, tapes, tricks."},
]


static func ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for m: Dictionary in MODES:
		out.append(str(m["id"]))
	return out


static func is_valid(id: String) -> bool:
	return ids().has(id)


## The mode dictionary for an id; the default one when unknown.
static func mode(id: String) -> Dictionary:
	for m: Dictionary in MODES:
		if str(m["id"]) == id:
			return m
	return MODES[0]


## Run length in seconds, 0 for free skate.
static func seconds(id: String) -> float:
	return float(mode(id)["seconds"])


static func label(id: String) -> String:
	return str(mode(id)["label"])


## The next mode in the list (wraps), step is +1 or -1.
static func cycle(id: String, step: int) -> String:
	var all: PackedStringArray = ids()
	var i: int = all.find(id)
	if i < 0:
		i = 0
	return all[posmod(i + step, all.size())]
