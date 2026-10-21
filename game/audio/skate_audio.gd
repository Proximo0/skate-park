class_name SkateAudio
extends Node
## Placeholder skate sounds. bind(skater) attaches 3D players to the skater and wires its signals to SfxSynth
## streams. Presentation only: it reads skater state and never changes it.
## Loops (roll, grind) run continuously and are silenced with volume, which avoids start/stop clicks.

const UNIT_SIZE: float = 6.0
const ROLL_MIN_SPEED: float = 0.5  ## m/s, silent below this
const SPEED_FULL: float = 12.0  ## m/s, pitch and volume reach their top here
const ROLL_PITCH: Vector2 = Vector2(0.8, 1.4)
const GRIND_PITCH: Vector2 = Vector2(0.9, 1.5)
const ROLL_DB: Vector2 = Vector2(-30.0, -8.0)
const GRIND_DB: Vector2 = Vector2(-24.0, -8.0)
const SILENT_DB: float = -80.0
const BAIL_COOLDOWN: float = 0.5  ## bail can come from landed("bail") and bailed in the same moment; play once
const OLLIE_FRAMES: int = 3  ## frames to wait for anim "ollie" after the state flips to AIR

var _skater: Skater
var _roll: AudioStreamPlayer3D
var _grind: AudioStreamPlayer3D
var _streams: Dictionary = {}
var _prev_state: int = SkateState.State.ROLLING
var _ollie_frames: int = 0
var _bail_cooldown: float = 0.0


func _ready() -> void:
	_build_streams()


func _build_streams() -> void:
	_streams = {
		"roll": SfxSynth.roll_loop(),
		"grind": SfxSynth.grind_loop(),
		"pop": SfxSynth.pop(),
		"land": SfxSynth.land(),
		"bail": SfxSynth.bail(),
		"ding": SfxSynth.trick_ding(),
		"combo": SfxSynth.combo_land(),
	}


## Attaches the sound players to the skater and connects its signals. Safe to call once per skater.
func bind(skater: Skater) -> void:
	if _streams.is_empty():
		_build_streams()
	_skater = skater
	_roll = _make_player(_streams["roll"], "RollSfx")
	_grind = _make_player(_streams["grind"], "GrindSfx")
	_roll.play()
	_grind.play()
	_roll.volume_db = SILENT_DB
	_grind.volume_db = SILENT_DB
	_prev_state = skater.state.state
	_connect(skater.trick_started, _on_trick_started)
	_connect(skater.landed, _on_landed)
	_connect(skater.bailed, _on_bailed)
	_connect(skater.combo_landed, _on_combo_landed)


func _process(delta: float) -> void:
	if _skater == null or not is_instance_valid(_skater):
		return
	_bail_cooldown = maxf(0.0, _bail_cooldown - delta)
	var st: int = _skater.state.state
	if st != _prev_state:
		if st == SkateState.State.AIR and _was_grounded(_prev_state):
			_ollie_frames = OLLIE_FRAMES
		_prev_state = st
	if _ollie_frames > 0:
		if _skater.anim == "ollie":
			_play_once("pop", 1.0)
			_ollie_frames = 0
		else:
			_ollie_frames -= 1
	_update_loops(st)


func _update_loops(st: int) -> void:
	var speed: float = _skater.speed
	var moving: bool = speed >= ROLL_MIN_SPEED
	var t: float = clampf(speed / SPEED_FULL, 0.0, 1.0)
	var rolling: bool = st == SkateState.State.ROLLING or st == SkateState.State.MANUAL
	_roll.pitch_scale = lerpf(ROLL_PITCH.x, ROLL_PITCH.y, t)
	_roll.volume_db = lerpf(ROLL_DB.x, ROLL_DB.y, t) if (rolling and moving) else SILENT_DB
	var grinding: bool = st == SkateState.State.GRIND
	_grind.pitch_scale = lerpf(GRIND_PITCH.x, GRIND_PITCH.y, t)
	_grind.volume_db = lerpf(GRIND_DB.x, GRIND_DB.y, t) if (grinding and moving) else SILENT_DB


func _was_grounded(st: int) -> bool:
	return st == SkateState.State.ROLLING or st == SkateState.State.MANUAL


func _on_trick_started(trick: Dictionary) -> void:
	var kind: String = str(trick.get("kind", ""))
	var pitch: float = 1.0
	match kind:
		"grab":
			pitch = 1.2
		"special":
			pitch = 0.85
	_play_once("ding", pitch)


func _on_landed(result: String) -> void:
	if result == "bail":
		_on_bailed()
	else:
		_play_once("land", 1.0)


func _on_bailed() -> void:
	if _bail_cooldown > 0.0:
		return
	_bail_cooldown = BAIL_COOLDOWN
	_play_once("bail", 1.0)


func _on_combo_landed(_points: int, _text: String) -> void:
	_play_once("combo", 1.0)


func _make_player(stream: AudioStream, node_name: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = node_name
	p.stream = stream
	p.unit_size = UNIT_SIZE
	p.volume_db = SILENT_DB
	_skater.add_child(p)
	return p


## One-shot on its own player so overlapping sounds do not cut each other off.
func _play_once(stream_name: String, pitch: float) -> void:
	if _skater == null or not _streams.has(stream_name):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[stream_name]
	p.unit_size = UNIT_SIZE
	p.pitch_scale = pitch
	_skater.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)
