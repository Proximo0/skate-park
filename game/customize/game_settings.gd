class_name GameSettings
extends RefCounted
## Player options that live outside a run (hair physics, and body physics with its strength: body_level() 0 Off,
## 1 Subtle, 2 Normal (default), 3 Bouncy), and bail injuries (the twists and sprains of a slam, BailFx; off leaves
## a plain ragdoll). Saved as JSON at user://settings.json.
## Scripted runs and tests never read or write the file.

const SAVE_PATH: String = "user://settings.json"

static var hair_physics: bool = true
static var body_physics: bool = true
static var body_strength: int = 2  ## 1 Subtle, 2 Normal, 3 Bouncy (while body_physics is on)
static var bail_injuries: bool = true
static var cam_distance: int = 1  ## 0 Near, 1 Normal, 2 Far (SkateCamera arm length)
static var cam_fov: int = 1  ## 0 Narrow, 1 Normal, 2 Wide
static var cam_shake: bool = true  ## landing weight: the dip and FOV punch
static var music_volume: int = 50  ## percent, one of MUSIC_STEPS (0 is off)
const MUSIC_STEPS: Array[int] = [0, 25, 50, 75, 100]
const CAM_DISTANCE_NAMES: PackedStringArray = ["Near", "Normal", "Far"]
const CAM_DISTANCE_SCALE: Array[float] = [0.85, 1.0, 1.25]
const CAM_FOV_NAMES: PackedStringArray = ["Narrow", "Normal", "Wide"]
const CAM_FOV_OFFSET: Array[float] = [-7.0, 0.0, 8.0]  ## degrees added to the camera FOV
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
		bail_injuries = bool((data as Dictionary).get("bail_injuries", true))
		cam_distance = clampi(int((data as Dictionary).get("cam_distance", 1)), 0, 2)
		cam_fov = clampi(int((data as Dictionary).get("cam_fov", 1)), 0, 2)
		cam_shake = bool((data as Dictionary).get("cam_shake", true))
		music_volume = clampi(int((data as Dictionary).get("music_volume", 50)), 0, 100)


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


static func injuries_on() -> bool:
	ensure_loaded()
	return bail_injuries


static func set_injuries(on: bool) -> void:
	ensure_loaded()
	bail_injuries = on
	save()


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
		f.store_string(JSON.stringify({"hair_physics": hair_physics, "body_physics": body_physics, "body_level": body_strength,
				"bail_injuries": bail_injuries, "cam_distance": cam_distance, "cam_fov": cam_fov, "cam_shake": cam_shake, "music_volume": music_volume}))


static func cam_distance_scale() -> float:
	ensure_loaded()
	return CAM_DISTANCE_SCALE[clampi(cam_distance, 0, 2)]


static func cam_fov_offset() -> float:
	ensure_loaded()
	return CAM_FOV_OFFSET[clampi(cam_fov, 0, 2)]


static func cam_shake_on() -> bool:
	ensure_loaded()
	return cam_shake


## Sets the camera distance (0 Near, 1 Normal, 2 Far).
static func set_cam_distance(level: int) -> void:
	ensure_loaded()
	cam_distance = posmod(level, 3)
	save()


## Sets the camera FOV (0 Narrow, 1 Normal, 2 Wide).
static func set_cam_fov(level: int) -> void:
	ensure_loaded()
	cam_fov = posmod(level, 3)
	save()


static func set_cam_shake(on: bool) -> void:
	ensure_loaded()
	cam_shake = on
	save()


## Music volume as 0..1.
static func music_scale() -> float:
	ensure_loaded()
	return float(music_volume) / 100.0


## The next music volume in the Off > 25 > 50 > 75 > 100 > Off cycle (the pause menu's button).
static func next_music_volume(pct: int) -> int:
	for step: int in MUSIC_STEPS:
		if step > pct:
			return step
	return 0


static func set_music_volume(pct: int) -> void:
	ensure_loaded()
	music_volume = clampi(pct, 0, 100)
	save()
