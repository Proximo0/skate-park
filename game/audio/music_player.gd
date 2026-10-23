class_name MusicPlayer
extends AudioStreamPlayer
## Plays the level's procedural loop (MusicSynth) at the player's music volume (GameSettings). The loop is rendered on a
## worker thread so the level loads without a hitch; the music starts a moment later. Volume 0 stops it. Keeps playing
## while the game is paused so the volume can be judged from the pause menu. Never started in scripted runs.

const BASE_DB: float = -13.0  ## full volume setting; the synth is normalised to -6 dBFS
const DUCK_DB: float = -7.0
const DUCK_RECOVER: float = 14.0  ## dB per second the duck eases back

var level_id: String = ""
var _task: int = -1
var _stream: AudioStreamWAV = null
var _duck: float = 0.0  ## current duck depth (dB, 0 to DUCK_DB)
var _duck_hold: float = 0.0


## Output volume in dB for a 0..1 volume setting (the duck not included); -80 when off. Pure.
static func volume_db_for(setting: float) -> float:
	if setting <= 0.001:
		return -80.0
	return BASE_DB + linear_to_db(clampf(setting, 0.0, 1.0))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bus = &"Music"
	if Flags.is_scripted_run():
		set_process(false)
		return
	_task = WorkerThreadPool.add_task(func() -> void: _stream = MusicSynth.render(level_id), false, "music render")


## Eases the music down for a moment under a bail, then back up.
func duck(seconds: float) -> void:
	_duck = DUCK_DB
	_duck_hold = seconds


func _process(delta: float) -> void:
	if _stream == null:
		if _task >= 0 and WorkerThreadPool.is_task_completed(_task) and _stream == null:
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
		return
	if stream == null:
		stream = _stream
	_duck_hold = maxf(_duck_hold - delta, 0.0)
	if _duck_hold <= 0.0:
		_duck = minf(_duck + DUCK_RECOVER * delta, 0.0)
	var setting: float = GameSettings.music_scale()
	volume_db = volume_db_for(setting) + _duck
	if setting <= 0.001:
		if playing:
			stop()
	elif not playing:
		play()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
