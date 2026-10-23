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
static var sfx_volume: int = 100  ## percent 0..100, drives the "SFX" audio bus (Master while that bus does not exist)
static var balance_assist: int = 1  ## 0 Easy, 1 Normal (today's values), 2 Hard: scales how fast grind / manual balance gets worse
static var invert_y: bool = false  ## camera orbit (right stick / mouse) vertical axis
static var cam_sensitivity: int = 100  ## percent 25..200 of the orbit speed
const SFX_BUS: String = "SFX"
const ASSIST_NAMES: PackedStringArray = ["Easy", "Normal", "Hard"]
## Balance.TIME_GROWTH_SECONDS is divided by this: Easy grows the wobble at 0.5x, Hard at 1.6x.
const ASSIST_GROWTH: Array[float] = [0.5, 1.0, 1.6]
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
	if Flags.is_scripted_run():
		return
	ControlRemap.load_saved()  # the player's key and button picks go into the InputMap with the first read of the options
	_load_file()
	apply_sfx_volume()


static func _load_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
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
		sfx_volume = clampi(int((data as Dictionary).get("sfx_volume", 100)), 0, 100)
		balance_assist = clampi(int((data as Dictionary).get("balance_assist", 1)), 0, 2)
		invert_y = bool((data as Dictionary).get("invert_y", false))
		cam_sensitivity = clampi(int((data as Dictionary).get("cam_sensitivity", 100)), 25, 200)


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
				"bail_injuries": bail_injuries, "cam_distance": cam_distance, "cam_fov": cam_fov, "cam_shake": cam_shake, "music_volume": music_volume,
				"sfx_volume": sfx_volume, "balance_assist": balance_assist, "invert_y": invert_y, "cam_sensitivity": cam_sensitivity}))


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


## SFX volume as 0..1.
static func sfx_scale() -> float:
	ensure_loaded()
	return float(sfx_volume) / 100.0


## Sets the SFX volume (percent) and applies it to the audio bus.
static func set_sfx_volume(pct: int) -> void:
	ensure_loaded()
	sfx_volume = clampi(pct, 0, 100)
	apply_sfx_volume()
	save()


## The bus the SFX slider drives: "SFX" when it exists, else Master (the fallback until the SFX bus is created).
static func sfx_bus_index() -> int:
	var i: int = AudioServer.get_bus_index(SFX_BUS)
	return i if i >= 0 else AudioServer.get_bus_index("Master")


static func apply_sfx_volume() -> void:
	if AudioServer.get_bus_index(SFX_BUS) >= 0:
		SkateAudio.set_sfx_volume(float(sfx_volume) / 100.0)
		return
	var i: int = sfx_bus_index()
	if i < 0:
		return
	var lin: float = float(sfx_volume) / 100.0
	AudioServer.set_bus_volume_db(i, linear_to_db(lin) if lin > 0.0 else -80.0)
	AudioServer.set_bus_mute(i, sfx_volume <= 0)


static func assist_level() -> int:
	ensure_loaded()
	return clampi(balance_assist, 0, 2)


## Growth multiplier for the balance meter's instability over time (1.0 on Normal).
static func balance_growth_scale() -> float:
	return ASSIST_GROWTH[assist_level()]


static func set_balance_assist(level: int) -> void:
	ensure_loaded()
	balance_assist = posmod(level, 3)
	save()


static func cam_invert_y() -> bool:
	ensure_loaded()
	return invert_y


static func set_invert_y(on: bool) -> void:
	ensure_loaded()
	invert_y = on
	save()


## Camera orbit speed multiplier (1.0 = today). The camera multiplies its stick and mouse orbit by this and by -1 when
## cam_invert_y() asks for the vertical axis flipped.
static func cam_sens_scale() -> float:
	ensure_loaded()
	return float(cam_sensitivity) / 100.0


static func set_cam_sensitivity(pct: int) -> void:
	ensure_loaded()
	cam_sensitivity = clampi(pct, 25, 200)
	save()
