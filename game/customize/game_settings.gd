class_name GameSettings
extends RefCounted
## Player options that live outside a run (hair physics, and body physics with its strength: body_level() 0 Off,
## 1 Subtle, 2 Normal (default), 3 Bouncy). Saved as JSON at user://settings.json.
## Scripted runs and tests never read or write the file.

const SAVE_PATH: String = "user://settings.json"

static var hair_physics: bool = true
static var body_physics: bool = true
static var body_strength: int = 2  ## 1 Subtle, 2 Normal, 3 Bouncy (while body_physics is on)
const BODY_LEVEL_NAMES: PackedStringArray = ["Off", "Subtle", "Normal", "Bouncy"]
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
		body_strength = clampi(int((data as Dictionary).get("body_level", 2)), 1, 3)


static func hair_on() -> bool:
	ensure_loaded()
	return hair_physics


static func body_on() -> bool:
	ensure_loaded()
	return body_physics


## Body physics strength: 0 when off, else body_strength (1 Subtle, 2 Normal, 3 Bouncy).
static func body_level() -> int:
	ensure_loaded()
	return body_strength if body_physics else 0


## Sets the body physics level (0 turns it off; 1 to 3 turn it on at that strength).
static func set_body_level(level: int) -> void:
	ensure_loaded()
	body_physics = level > 0
	if level > 0:
		body_strength = clampi(level, 1, 3)
	save()


## The next level in the Off > Subtle > Normal > Bouncy > Off cycle (the pause menu's button).
static func next_body_level(level: int) -> int:
	return (clampi(level, 0, 3) + 1) % 4


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
		f.store_string(JSON.stringify({"hair_physics": hair_physics, "body_physics": body_physics, "body_level": body_strength}))
