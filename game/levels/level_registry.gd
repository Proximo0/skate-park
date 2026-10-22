class_name LevelRegistry
extends RefCounted
## Every playable level: id, display name, one-line blurb, script, mood preset (game/world/mood.gd), bot route file,
## preview image and card accent colour. main.gd builds the chosen level with create(); the level-select screen
## (game/ui/level_select.gd) lists entries(). The order here is the order on the level-select screen.
##
## Choosing a level: `-- --level=<id>` on the command line wins the first time main.gd asks (resolve()); after that the
## last pick from the level select (`selected`) wins, so "Change level" in the pause menu works in a run started with
## --level. `--testpark` still loads the small proving ground and ignores all of this.

const DEFAULT_ID: String = "practice"
## Practice keeps its code-built bot routes (tests/bot/bot_lines.gd); this marks it.
const BUILTIN_ROUTE: String = "builtin:bot_lines"

const ENTRIES: Array[Dictionary] = [
	{
		"id": "practice", "name": "Practice Park", "blurb": "The home park: mega ramp, loop, dome bowl and a long street run.",
		"script": "res://game/park/park.gd", "mood": "day", "bot_route": BUILTIN_ROUTE,
		"preview": "res://game/levels/previews/practice.png", "accent": Color("3ddc97"), "tag": "DAY",
	},
	{
		"id": "warehouse", "name": "Creepy Warehouse", "blurb": "An abandoned warehouse at night. Catwalks, loading docks, sodium lights.",
		"script": "res://game/levels/warehouse/warehouse_level.gd", "mood": "warehouse_night",
		"bot_route": "res://game/levels/warehouse/bot_route.json",
		"preview": "res://game/levels/previews/warehouse.png", "accent": Color("ff9f3d"), "tag": "NIGHT",
	},
	{
		"id": "beach", "name": "Beachfront", "blurb": "A concrete park on the sand. Boardwalk, pier, palms and rolling surf.",
		"script": "res://game/levels/beach/beach_level.gd", "mood": "beach_sunny",
		"bot_route": "res://game/levels/beach/bot_route.json",
		"preview": "res://game/levels/previews/beach.png", "accent": Color("00a6c8"), "tag": "SUNNY",
	},
	{
		"id": "school", "name": "School", "blurb": "The campus after hours. Stairs, rails, banks, courtyard and the gym.",
		"script": "res://game/levels/school/school_level.gd", "mood": "school_dusk",
		"bot_route": "res://game/levels/school/bot_route.json",
		"preview": "res://game/levels/previews/school.png", "accent": Color("ffd23f"), "tag": "DUSK",
	},
	{
		"id": "downtown", "name": "Downtown", "blurb": "City blocks and plazas. Ledges, fountains, traffic and towers.",
		"script": "res://game/levels/downtown/downtown_level.gd", "mood": "city_afternoon",
		"bot_route": "res://game/levels/downtown/bot_route.json",
		"preview": "res://game/levels/previews/downtown.png", "accent": Color("ff6b5b"), "tag": "CITY",
	},
	{
		"id": "hills", "name": "The Hills", "blurb": "Long downhill streets, cul-de-sacs, drained pools and valley views.",
		"script": "res://game/levels/hills/hills_level.gd", "mood": "hills_golden",
		"bot_route": "res://game/levels/hills/bot_route.json",
		"preview": "res://game/levels/previews/hills.png", "accent": Color("b58cff"), "tag": "GOLDEN",
	},
]

## The level the next main.gd load builds (set by the level select and by resolve()).
static var selected: String = DEFAULT_ID
static var _arg_used: bool = false


static func ids() -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in ENTRIES:
		out.append(str(e["id"]))
	return out


static func has(id: String) -> bool:
	return ids().has(id)


## The entry for `id` (a copy), or {} when there is none.
static func entry(id: String) -> Dictionary:
	for e: Dictionary in ENTRIES:
		if str(e["id"]) == id:
			return e.duplicate()
	return {}


static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in ENTRIES:
		out.append(e.duplicate())
	return out


static func display_name(id: String) -> String:
	return str(entry(id).get("name", id))


## The id main.gd should build, given the run's args (Flags.args): `level=<id>` the first time it is asked, then the
## last selection. Unknown ids fall back to the default.
static func resolve(args: Dictionary) -> String:
	if not _arg_used and args.has("level"):
		_arg_used = true
		var want: String = str(args["level"])
		if has(want):
			selected = want
		else:
			push_warning("LevelRegistry: unknown level '%s', loading %s" % [want, DEFAULT_ID])
	if not has(selected):
		selected = DEFAULT_ID
	return selected


## A new, not yet added Level for `id` (unknown ids give the default). Its level_id, display_name, mood_id and
## bot_route_path come from the entry unless the level script set them itself.
static func create(id: String) -> Level:
	var e: Dictionary = entry(id)
	if e.is_empty():
		e = entry(DEFAULT_ID)
	var script: Script = load(str(e["script"])) as Script
	var lvl: Level = script.new() as Level
	lvl.level_id = str(e["id"])
	if lvl.display_name == "":
		lvl.display_name = str(e["name"])
	if lvl.mood_id == "":
		lvl.mood_id = str(e["mood"])
	if lvl.bot_route_path == "":
		lvl.bot_route_path = str(e["bot_route"])
	return lvl


## The preview texture for a level card, or null when it has not been rendered yet (tools/level_previews.gd).
static func preview(id: String) -> Texture2D:
	var path: String = str(entry(id).get("preview", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
