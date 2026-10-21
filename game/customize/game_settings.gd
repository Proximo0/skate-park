class_name GameSettings
extends RefCounted
## Player options that live outside a run (hair and body physics). Saved as JSON at user://settings.json.
## Scripted runs and tests never read or write the file.

const SAVE_PATH: String = "user://settings.json"

static var hair_physics: bool = true
static var body_physics: bool = true
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if Flags.is_scripted_run() or not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		hair_physics = bool((data as Dictionary).get("hair_physics", true))
		body_physics = bool((data as Dictionary).get("body_physics", true))


static func hair_on() -> bool:
	ensure_loaded()
	return hair_physics


static func body_on() -> bool:
	ensure_loaded()
	return body_physics


static func set_hair(on: bool) -> void:
	ensure_loaded()
	hair_physics = on
	save()


static func set_body(on: bool) -> void:
	ensure_loaded()
	body_physics = on
	save()


static func save() -> void:
	if Flags.is_scripted_run():
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"hair_physics": hair_physics, "body_physics": body_physics}))
