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
const AMBIENCE_DB: float = -22.0
const LEVEL_AMBIENCE: Dictionary = {"practice": "crowd", "warehouse": "hum", "beach": "surf", "school": "crowd",
		"downtown": "city", "hills": "wind"}
const WOOD_WORDS: PackedStringArray = ["ramp", "wood", "deck", "pipe", "bank", "funbox", "kicker", "boardwalk", "bowl",
		"quarter", "vert", "launch", "mega", "coping", "plank", "stage"]
const METAL_WORDS: PackedStringArray = ["rail", "pole", "grate", "metal", "bar", "steel"]
const WOOD_GRIND_WORDS: PackedStringArray = ["coping", "wood", "plank", "slat"]
const OLLIE_FRAMES: int = 3  ## frames to wait for anim "ollie" after the state flips to AIR

var _skater: Skater
var _roll: AudioStreamPlayer3D
var _roll_wood: AudioStreamPlayer3D
var _grind: AudioStreamPlayer3D
var _grind_concrete: AudioStreamPlayer3D
var _grind_wood: AudioStreamPlayer3D
var _ambience: AudioStreamPlayer
var _surface: String = "concrete"  ## what the wheels are on: "concrete", "wood" (metal only ever applies to a grind)
var _grind_surface: String = "metal"
var _surface_tick: int = 0
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
		"roll_wood": SfxSynth.roll_wood_loop(),
		"grind_concrete": SfxSynth.grind_concrete_loop(),
		"grind_wood": SfxSynth.grind_wood_loop(),
		"land_heavy": SfxSynth.land_heavy(),
	}


## Which surface a collider (or any of its ancestors' names, lower-cased) is: "wood", "metal" or "concrete". Pure.
static func classify_surface(names: PackedStringArray) -> String:
	for n: String in names:
		var l: String = n.to_lower()
		for w: String in METAL_WORDS:
			if l.contains(w):
				return "metal"
	for n: String in names:
		var l: String = n.to_lower()
		for w: String in WOOD_WORDS:
			if l.contains(w):
				return "wood"
	return "concrete"


## A grind's material from its rail node's name: metal unless it names wood or a concrete ledge. Pure.
static func classify_grind(node_name: String) -> String:
	var l: String = node_name.to_lower()
	for w: String in WOOD_GRIND_WORDS:
		if l.contains(w):
			return "wood"
	for w: String in ["ledge", "curb", "bench", "box", "stair", "wall"]:
		if l.contains(w):
			return "concrete"
	return "metal"


## Landing sound shaping from the 0..1 impact: [stream name, pitch, volume dB]. Pure.
static func land_shape(impact: float) -> Array:
	var k: float = clampf(impact, 0.0, 1.0)
	var heavy: bool = k > 0.45
	return ["land_heavy" if heavy else "land", lerpf(1.2, 0.8, k), lerpf(-16.0, 0.0, k)]


## Ambience bed for a level id ("crowd" when unknown). Pure.
static func ambience_for(level_id: String) -> String:
	return str(LEVEL_AMBIENCE.get(level_id, "crowd"))


## Attaches the sound players to the skater and connects its signals. Safe to call once per skater.
func bind(skater: Skater) -> void:
	if _streams.is_empty():
		_build_streams()
	_skater = skater
	_roll = _make_player(_streams["roll"], "RollSfx")
	_grind = _make_player(_streams["grind"], "GrindSfx")
	_roll_wood = _make_player(_streams["roll_wood"], "RollWoodSfx")
	_grind_concrete = _make_player(_streams["grind_concrete"], "GrindConcreteSfx")
	_grind_wood = _make_player(_streams["grind_wood"], "GrindWoodSfx")
	for p: AudioStreamPlayer3D in [_roll, _roll_wood, _grind, _grind_concrete, _grind_wood]:
		p.play()
		p.volume_db = SILENT_DB
	_start_ambience()
	_prev_state = skater.state.state
	_connect(skater.trick_started, _on_trick_started)
	_connect(skater.landed, _on_landed)
	_connect(skater.bailed, _on_bailed)
	_connect(skater.combo_landed, _on_combo_landed)


func _start_ambience() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var host: Node = get_parent()
	var lvl: String = ""
	if host != null and host.get("level") != null:
		lvl = str(host.get("level").get("level_id"))
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "AmbienceSfx"
	_ambience.stream = SfxSynth.ambience_loop(ambience_for(lvl))
	_ambience.volume_db = AMBIENCE_DB
	add_child(_ambience)
	_ambience.play()


## Looks under the board for what the wheels are on (a few times a second, not every frame).
func _probe_surface() -> void:
	if not _skater.is_inside_tree():
		return
	var from: Vector3 = _skater.global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.2)
	if _skater is CollisionObject3D:
		q.exclude = [(_skater as CollisionObject3D).get_rid()]
	var hit: Dictionary = _skater.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var names := PackedStringArray()
	var n: Node = hit["collider"] as Node
	var depth: int = 0
	while n != null and depth < 4:
		names.append(str(n.name))
		n = n.get_parent()
		depth += 1
	var s: String = classify_surface(names)
	_surface = "wood" if s == "wood" else "concrete"


func _process(delta: float) -> void:
	if _skater == null or not is_instance_valid(_skater):
		return
	_surface_tick += 1
	if _surface_tick % 6 == 0 and _skater.state.state == SkateState.State.ROLLING:
		_probe_surface()
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
	var roll_db: float = lerpf(ROLL_DB.x, ROLL_DB.y, t) if (rolling and moving) else SILENT_DB
	var pitch: float = lerpf(ROLL_PITCH.x, ROLL_PITCH.y, t)
	var wood: bool = _surface == "wood"
	_roll.pitch_scale = pitch
	_roll_wood.pitch_scale = pitch
	_roll.volume_db = SILENT_DB if wood else roll_db
	_roll_wood.volume_db = roll_db if wood else SILENT_DB
	var grinding: bool = st == SkateState.State.GRIND
	if grinding:
		var rail: Variant = _skater.get("_rail")
		_grind_surface = classify_grind(str(rail.name)) if rail is Node else "metal"
	var g_db: float = lerpf(GRIND_DB.x, GRIND_DB.y, t) if (grinding and moving) else SILENT_DB
	var g_pitch: float = lerpf(GRIND_PITCH.x, GRIND_PITCH.y, t)
	for pair: Array in [[_grind, "metal"], [_grind_concrete, "concrete"], [_grind_wood, "wood"]]:
		var p: AudioStreamPlayer3D = pair[0]
		p.pitch_scale = g_pitch
		p.volume_db = g_db if _grind_surface == pair[1] else SILENT_DB


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
		var shape: Array = land_shape(_skater.land_impact)
		_play_once(str(shape[0]), float(shape[1]), float(shape[2]))


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
func _play_once(stream_name: String, pitch: float, volume_db: float = 0.0) -> void:
	if _skater == null or not _streams.has(stream_name):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[stream_name]
	p.unit_size = UNIT_SIZE
	p.pitch_scale = pitch
	p.volume_db = volume_db
	_skater.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)
