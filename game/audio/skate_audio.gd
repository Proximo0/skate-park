class_name SkateAudio
extends Node
## Skate sounds. bind(skater) attaches 3D players to the skater and wires its signals to the sample bank in
## SAMPLE_DIR (rendered offline by tools/audio/render_sfx.py: ollie pop, land by surface x impact, grind
## start/loop/end per material, roll loops, skid, bail, wallplant, push), falling back to the SfxSynth stream of the
## same name when a file is missing. One-shots with round-robin variants play through an AudioStreamRandomizer
## (random variant, pitch and volume). Everything plays on the SFX bus (see sfx_bus / set_sfx_volume).
## Presentation only: it reads skater state and never changes it.
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
const SAND_WORDS: PackedStringArray = ["sand", "beach", "dirt", "dune", "gravel", "grass"]
const SKID_DB: Vector2 = Vector2(-22.0, -6.0)
const SKID_PITCH: Vector2 = Vector2(0.85, 1.25)
const SKID_FADE_IN: float = 40.0  ## dB per second the skid swells at (an ease, so it never clicks)
const SKID_FADE_OUT: float = 120.0
const WOOD_GRIND_WORDS: PackedStringArray = ["coping", "wood", "plank", "slat"]
## Skater event name -> [stream, pitch, volume dB] for the one-shots of the newer moves (see event_sound).
const EVENT_SOUNDS: Dictionary = {
	"grind_switch": ["grind_switch", 1.0, -4.0],
	"manual_switch": ["manual_switch", 1.0, -6.0],
	"manual_pivot": ["manual_pivot", 1.0, -6.0],
	"manual_revert": ["revert_whoosh", 1.1, -8.0],
	"flatland": ["flatland", 1.0, -6.0],
	"lip_pop": ["lip_pop", 1.0, -3.0],
	"lip_revert": ["revert_whoosh", 0.9, -4.0],
	"wall_revert": ["revert_whoosh", 0.8, -4.0],
	"natas_180": ["revert_whoosh", 1.35, -3.0],
	"natas_pop": ["lip_pop", 1.1, -3.0],
	"sticker_slap": ["slap", 1.0, -2.0],
	"bert_slide": ["revert_whoosh", 0.7, -5.0],
	"focus_on": ["focus_on", 1.0, -4.0],
	"focus_off": ["focus_off", 1.0, -4.0],
	"wallplant": ["wallplant", 1.0, -2.0],
	"boneless_plant": ["push", 0.9, -3.0],
	"no_comply_plant": ["push", 1.05, -4.0],
}
const BERT_DB: Vector2 = Vector2(-20.0, -5.0)
const TOW_DB: Vector2 = Vector2(-26.0, -10.0)
const FOCUS_LOWPASS_HZ: float = 2400.0  ## the master low-pass while focus slow-mo is on (muffled, underwater feel)
const LINK_SOUND: Array = ["link", 1.0, -3.0]
const OLLIE_FRAMES: int = 3  ## frames to wait for anim "ollie" after the state flips to AIR
const SAMPLE_DIR: String = "res://assets/audio/sfx/"
const SFX_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"
const MAX_VARIANTS: int = 6
## Stream name -> sample base in SAMPLE_DIR: "<base>.wav", or round-robin "<base>_1.wav", "<base>_2.wav", ...
## land_<surface>_<soft|med|hard> and grind_<material>_<start|end> are added by sample_map().
const SAMPLES: Dictionary = {
	"pop": "pop", "bail": "bail", "push": "push", "wallplant": "wallplant",
	"roll": "roll_concrete_loop", "roll_wood": "roll_wood_loop", "skid": "skid_loop",
	"grind": "grind_metal_loop", "grind_concrete": "grind_concrete_loop", "grind_wood": "grind_wood_loop",
}
const LAND_SURFACES: PackedStringArray = ["concrete", "wood", "metal"]
const LAND_IMPACTS: PackedStringArray = ["soft", "med", "hard"]
const GRIND_KINDS: PackedStringArray = ["metal", "concrete", "wood"]
## Randomization of the sampled one-shots: pitch within 1/x..x, volume within +-dB.
const SAMPLE_RANDOM_PITCH: float = 1.06
const SAMPLE_RANDOM_DB: float = 1.5
## The sampled loops were rendered at a cruising speed (about 6 m/s), so they bend less in pitch than the synth's.
const ROLL_SAMPLE_PITCH: Vector2 = Vector2(0.72, 1.22)
const GRIND_SAMPLE_PITCH: Vector2 = Vector2(0.88, 1.18)
const LOOP_SAMPLE_DB: float = 2.0  ## the sampled loops sit about 2 dB under the synth's loudness at the same setting
const LAND_SAMPLE_DB: Vector2 = Vector2(-12.0, 0.0)  ## soft..hard landing volume for the sampled landings
const PUSH_DB: float = -7.0

var _skater: Skater
var _roll: AudioStreamPlayer3D
var _roll_wood: AudioStreamPlayer3D
var _grind: AudioStreamPlayer3D
var _grind_concrete: AudioStreamPlayer3D
var _grind_wood: AudioStreamPlayer3D
var _skid: AudioStreamPlayer3D
var _skid_sand: AudioStreamPlayer3D
var _bert: AudioStreamPlayer3D
var _tow: AudioStreamPlayer3D
var _bert_db: float = -80.0
var _tow_db: float = -80.0
var _focus_fx: AudioEffectLowPassFilter = null
var _focus_bus_idx: int = -1
var _skid_on: bool = false
var _skid_db: float = -80.0
var _ambience: AudioStreamPlayer
var _music: MusicPlayer = null
var _surface: String = "concrete"  ## what the wheels are on: "concrete", "wood" (metal only ever applies to a grind)
var _grind_surface: String = "metal"
var _surface_tick: int = 0
var _streams: Dictionary = {}
var _prev_state: int = SkateState.State.ROLLING
var _ollie_frames: int = 0
var _bail_cooldown: float = 0.0
var _sampled: Dictionary = {}  ## stream names that came from a sample file (the rest are SfxSynth fallbacks)
var _was_grinding: bool = false
var _land_surface: String = "concrete"  ## raw surface under the wheels, metal included (for the landing sound)
var _push_contact: bool = false


func _ready() -> void:
	_build_streams()


## Sample files first; every name without one gets its SfxSynth stream (only those are synthesized).
func _build_streams() -> void:
	_streams = {}
	_sampled = {}
	var map: Dictionary = {} if OS.get_environment("SKATE_SFX_SYNTH") == "1" else sample_map()  # A/B: synth only
	for key: String in map:
		var st: AudioStream = load_sample(str(map[key]))
		if st != null:
			_streams[key] = st
			_sampled[key] = true
	for key: String in SYNTH_NAMES:
		if not _streams.has(key):
			_streams[key] = _synth(key)
	if not _streams.has("wallplant"):
		_streams["wallplant"] = _streams["slap"]
	if not _streams.has("push"):
		_streams["push"] = _streams["land"]  # (plants only: the push scuff itself needs the sample)


const SYNTH_NAMES: PackedStringArray = ["roll", "grind", "pop", "land", "bail", "ding", "combo", "roll_wood",
		"grind_concrete", "grind_wood", "land_heavy", "skid", "skid_sand", "grind_switch", "manual_switch",
		"manual_pivot", "flatland", "lip_pop", "revert_whoosh", "link", "bert", "tow", "slap", "focus_on", "focus_off"]


## The fallback stream for a name in SYNTH_NAMES.
static func _synth(key: String) -> AudioStream:
	match key:
		"roll": return SfxSynth.roll_loop()
		"grind": return SfxSynth.grind_loop()
		"pop": return SfxSynth.pop()
		"land": return SfxSynth.land()
		"bail": return SfxSynth.bail()
		"ding": return SfxSynth.trick_ding()
		"combo": return SfxSynth.combo_land()
		"roll_wood": return SfxSynth.roll_wood_loop()
		"grind_concrete": return SfxSynth.grind_concrete_loop()
		"grind_wood": return SfxSynth.grind_wood_loop()
		"land_heavy": return SfxSynth.land_heavy()
		"skid": return SfxSynth.skid_loop()
		"skid_sand": return SfxSynth.skid_sand_loop()
		"grind_switch": return SfxSynth.grind_switch()
		"manual_switch": return SfxSynth.manual_switch()
		"manual_pivot": return SfxSynth.manual_pivot()
		"flatland": return SfxSynth.flatland()
		"lip_pop": return SfxSynth.lip_pop()
		"revert_whoosh": return SfxSynth.revert_whoosh()
		"link": return SfxSynth.link()
		"bert": return SfxSynth.bert_loop()
		"tow": return SfxSynth.tow_loop()
		"slap": return SfxSynth.slap()
		"focus_on": return SfxSynth.focus_swoop(true)
		"focus_off": return SfxSynth.focus_swoop(false)
	return null


## Every stream name that has a sample, with its base file name. Pure.
static func sample_map() -> Dictionary:
	var m: Dictionary = SAMPLES.duplicate()
	for s: String in LAND_SURFACES:
		for i: String in LAND_IMPACTS:
			m["land_%s_%s" % [s, i]] = "land_%s_%s" % [s, i]
	for k: String in GRIND_KINDS:
		for e: String in ["start", "end"]:
			m["grind_%s_%s" % [k, e]] = "grind_%s_%s" % [k, e]
	return m


## The sample files for a base name: "<base>.wav" alone, else "<base>_1.wav" ... while they exist.
static func sample_paths(base: String) -> PackedStringArray:
	var out := PackedStringArray()
	var single: String = SAMPLE_DIR + base + ".wav"
	if ResourceLoader.exists(single):
		out.append(single)
		return out
	for v: int in range(1, MAX_VARIANTS + 1):
		var p: String = "%s%s_%d.wav" % [SAMPLE_DIR, base, v]
		if not ResourceLoader.exists(p):
			break
		out.append(p)
	return out


## A loop sample as it is, or a one-shot (one or several round-robin variants) in an AudioStreamRandomizer that
## picks a variant (never the same twice running) with a little pitch and volume spread. null when no file exists.
static func load_sample(base: String) -> AudioStream:
	var paths: PackedStringArray = sample_paths(base)
	if paths.is_empty():
		return null
	var first: AudioStream = load(paths[0]) as AudioStream
	if first == null:
		return null
	if first is AudioStreamWAV and (first as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return first
	var r := AudioStreamRandomizer.new()
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS if paths.size() > 2 \
			else AudioStreamRandomizer.PLAYBACK_RANDOM
	r.random_pitch = SAMPLE_RANDOM_PITCH
	r.random_volume_offset_db = SAMPLE_RANDOM_DB
	for i: int in paths.size():
		var st: AudioStream = first if i == 0 else load(paths[i]) as AudioStream
		if st != null:
			r.add_stream(-1, st)
	return r


## The bus every sound effect plays on: "SFX" when the layout has it (default_bus_layout.tres), else Master.
static func sfx_bus() -> StringName:
	return SFX_BUS if AudioServer.get_bus_index(SFX_BUS) >= 0 else &"Master"


## Sets the SFX bus volume from a 0..1 setting (0 mutes). For a settings slider; music has its own bus.
static func set_sfx_volume(setting: float) -> void:
	var idx: int = AudioServer.get_bus_index(SFX_BUS)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, setting <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(setting, 0.001, 1.0)))


## The sampled landing for a 0..1 impact and the surface under the wheels: "land_<surface>_<soft|med|hard>".
## Sand and anything unknown land as concrete. Pure.
static func land_sample_key(impact: float, surface: String) -> String:
	var k: float = clampf(impact, 0.0, 1.0)
	var level: String = "soft" if k < 0.3 else ("med" if k < 0.65 else "hard")
	var s: String = surface if LAND_SURFACES.has(surface) else "concrete"
	return "land_%s_%s" % [s, level]


## Skid loop volume (dB) and pitch for a speed in m/s: silent-ish at a crawl, full by SPEED_FULL. Pure.
static func skid_shape(speed: float) -> Vector2:
	var t: float = clampf(speed / SPEED_FULL, 0.0, 1.0)
	return Vector2(lerpf(SKID_DB.x, SKID_DB.y, t), lerpf(SKID_PITCH.x, SKID_PITCH.y, t))


## Which surface a collider (or any of its ancestors' names, lower-cased) is: "sand", "wood", "metal" or "concrete".
## Pure.
static func classify_surface(names: PackedStringArray) -> String:
	for n: String in names:
		var l: String = n.to_lower()
		for w: String in METAL_WORDS:
			if l.contains(w):
				return "metal"
	for n: String in names:
		var l: String = n.to_lower()
		for w: String in SAND_WORDS:
			if l.contains(w):
				return "sand"
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


## The one-shot ([stream, pitch, dB]) a skater event name plays, [] when it has none. "link:<id>" is a rail transfer. Pure.
static func event_sound(event: String) -> Array:
	if event.begins_with("link:"):
		return LINK_SOUND
	return EVENT_SOUNDS.get(event, [])


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
	_skid = _make_player(_streams["skid"], "SkidSfx")
	_skid_sand = _make_player(_streams["skid_sand"], "SkidSandSfx")
	_bert = _make_player(_streams["bert"], "BertSfx")
	_tow = _make_player(_streams["tow"], "TowSfx")
	for p: AudioStreamPlayer3D in [_roll, _roll_wood, _grind, _grind_concrete, _grind_wood, _skid, _skid_sand, _bert, _tow]:
		p.play()
		p.volume_db = SILENT_DB
	_start_ambience()
	_prev_state = skater.state.state
	_connect(skater.trick_started, _on_trick_started)
	_connect(skater.landed, _on_landed)
	_connect(skater.bailed, _on_bailed)
	_connect(skater.combo_landed, _on_combo_landed)
	_connect(skater.powerslide_changed, _on_powerslide_changed)
	_connect(skater.focus_changed, _on_focus_changed)
	_connect(skater.physics_ticked, _on_tick)
	_connect(skater.bailed, _duck_music)
	_start_music()


func _on_tick(frame: Dictionary) -> void:
	for e: Variant in frame.get("events", []):
		var snd: Array = event_sound(str(e))
		if not snd.is_empty():
			_play_once(str(snd[0]), float(snd[1]), float(snd[2]))
	# Push: one sole scuff each time the push foot meets the ground (the pulse that drives the speed).
	var contact: bool = bool(frame.get("pushing", false)) and float(frame.get("push_pulse", 0.0)) > 1.0
	if contact and not _push_contact and _sampled.has("push"):
		_play_once("push", 1.0, PUSH_DB)
	_push_contact = contact


## Background music for the level: silent in scripted runs and when the volume setting is off.
func _start_music() -> void:
	if Flags.is_scripted_run() or _music != null:
		return
	var host: Node = get_parent()
	var lvl: String = ""
	if host != null and host.get("level") != null:
		lvl = str(host.get("level").get("level_id"))
	_music = MusicPlayer.new()
	_music.name = "Music"
	_music.level_id = lvl
	add_child(_music)
	if AudioServer.get_bus_index(MUSIC_BUS) >= 0:
		_music.bus = MUSIC_BUS  # (after add_child: its _ready sets Master)


func _duck_music() -> void:
	if _music != null:
		_music.duck(1.2)


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
	_ambience.bus = sfx_bus()
	add_child(_ambience)
	_ambience.play()


## Looks under the board for what the wheels are on (a few times a second, not every frame).
func _probe_surface() -> void:
	var s: String = _probe_raw()
	if s.is_empty():
		return
	_land_surface = s
	_surface = s if s == "wood" or s == "sand" else "concrete"


## The raw surface under the board ("concrete", "wood", "metal", "sand"), "" when the ray finds nothing.
func _probe_raw() -> String:
	if not _skater.is_inside_tree():
		return ""
	var from: Vector3 = _skater.global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.2)
	if _skater is CollisionObject3D:
		q.exclude = [(_skater as CollisionObject3D).get_rid()]
	var hit: Dictionary = _skater.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return ""
	var names := PackedStringArray()
	var n: Node = hit["collider"] as Node
	var depth: int = 0
	while n != null and depth < 4:
		names.append(str(n.name))
		n = n.get_parent()
		depth += 1
	return classify_surface(names)


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
	_update_skid(delta)
	_update_extras(delta)


func _on_powerslide_changed(active: bool) -> void:
	_skid_on = active
	if active:
		_probe_surface()


## The skid loop swells in while the powerslide lasts and drops away when it ends; sand gets the hiss, not the squeal.
func _update_skid(delta: float) -> void:
	var shape: Vector2 = skid_shape(_skater.speed)
	var target: float = shape.x if (_skid_on and _skater.powersliding) else SILENT_DB
	var rate: float = SKID_FADE_IN if target > _skid_db else SKID_FADE_OUT
	_skid_db = move_toward(_skid_db, target, rate * delta)
	var sand: bool = _surface == "sand"
	_skid.pitch_scale = shape.y
	_skid_sand.pitch_scale = shape.y
	_skid.volume_db = SILENT_DB if sand or _skid_db <= -60.0 else _skid_db
	_skid_sand.volume_db = _skid_db + 2.0 if sand and _skid_db > -60.0 else SILENT_DB


## Bert scrape and skitch tow loops: fade in while the move lasts, out when it ends (like the skid).
func _update_extras(delta: float) -> void:
	var t: float = clampf(_skater.speed / SPEED_FULL, 0.0, 1.0)
	var bert_target: float = lerpf(BERT_DB.x, BERT_DB.y, t) if _skater.berting else SILENT_DB
	_bert_db = move_toward(_bert_db, bert_target, (SKID_FADE_IN if bert_target > _bert_db else SKID_FADE_OUT) * delta)
	_bert.volume_db = SILENT_DB if _bert_db <= -60.0 else _bert_db
	_bert.pitch_scale = lerpf(0.8, 1.15, t)
	var skitching: bool = _skater.get("_skitch_car") != null
	var tow_target: float = lerpf(TOW_DB.x, TOW_DB.y, t) if skitching else SILENT_DB
	_tow_db = move_toward(_tow_db, tow_target, (SKID_FADE_IN if tow_target > _tow_db else SKID_FADE_OUT) * delta)
	_tow.volume_db = SILENT_DB if _tow_db <= -60.0 else _tow_db
	_tow.pitch_scale = lerpf(0.85, 1.3, t)


## Focus slow-mo: the engine clock already slows every sound (Engine.time_scale drives the audio speed); on top of
## that the master bus gets a low-pass so the world sounds muffled and far, and it is taken off again when focus ends.
func _on_focus_changed(on: bool) -> void:
	if _focus_fx == null:
		_focus_fx = AudioEffectLowPassFilter.new()
		_focus_fx.cutoff_hz = FOCUS_LOWPASS_HZ
		AudioServer.add_bus_effect(0, _focus_fx)
		_focus_bus_idx = AudioServer.get_bus_effect_count(0) - 1
	if _focus_bus_idx >= 0 and _focus_bus_idx < AudioServer.get_bus_effect_count(0):
		AudioServer.set_bus_effect_enabled(0, _focus_bus_idx, on)


func _exit_tree() -> void:
	if _focus_fx != null and _focus_bus_idx >= 0 and _focus_bus_idx < AudioServer.get_bus_effect_count(0):
		AudioServer.remove_bus_effect(0, _focus_bus_idx)
		_focus_fx = null


func _update_loops(st: int) -> void:
	var speed: float = _skater.speed
	var moving: bool = speed >= ROLL_MIN_SPEED
	var t: float = clampf(speed / SPEED_FULL, 0.0, 1.0)
	var rolling: bool = st == SkateState.State.ROLLING or st == SkateState.State.MANUAL
	var roll_db: float = lerpf(ROLL_DB.x, ROLL_DB.y, t) if (rolling and moving) else SILENT_DB
	var pitch: float = lerpf(ROLL_PITCH.x, ROLL_PITCH.y, t)
	var wood: bool = _surface == "wood"
	_roll.pitch_scale = _loop_pitch("roll", ROLL_SAMPLE_PITCH, ROLL_PITCH, t)
	_roll_wood.pitch_scale = _loop_pitch("roll_wood", ROLL_SAMPLE_PITCH, ROLL_PITCH, t)
	_roll.volume_db = SILENT_DB if wood else roll_db + _loop_gain("roll", roll_db)
	_roll_wood.volume_db = roll_db + _loop_gain("roll_wood", roll_db) if wood else SILENT_DB
	var grinding: bool = st == SkateState.State.GRIND
	if grinding:
		var rail: Variant = _skater.get("_rail")
		_grind_surface = classify_grind(str(rail.name)) if rail is Node else "metal"
	if grinding != _was_grinding:
		# The trucks hitting the rail (or leaving it): a one-shot on top of the loop's fade.
		var edge: String = "grind_%s_%s" % [_grind_surface, "start" if grinding else "end"]
		if grinding or moving:
			_play_once(edge, 1.0, lerpf(-10.0, -3.0, t) if grinding else lerpf(-12.0, -4.0, t))
		_was_grinding = grinding
	var g_db: float = lerpf(GRIND_DB.x, GRIND_DB.y, t) if (grinding and moving) else SILENT_DB
	for pair: Array in [[_grind, "metal", "grind"], [_grind_concrete, "concrete", "grind_concrete"],
			[_grind_wood, "wood", "grind_wood"]]:
		var p: AudioStreamPlayer3D = pair[0]
		var key: String = pair[2]
		p.pitch_scale = _loop_pitch(key, GRIND_SAMPLE_PITCH, GRIND_PITCH, t)
		p.volume_db = g_db + _loop_gain(key, g_db) if _grind_surface == pair[1] else SILENT_DB


## Loop pitch for a 0..1 speed share: the sample's narrower range when the stream is a sample.
func _loop_pitch(key: String, sample_range: Vector2, synth_range: Vector2, t: float) -> float:
	var r: Vector2 = sample_range if _sampled.has(key) else synth_range
	return lerpf(r.x, r.y, t)


func _loop_gain(key: String, db: float) -> float:
	return LOOP_SAMPLE_DB if _sampled.has(key) and db > SILENT_DB else 0.0


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
		return
	var raw: String = _probe_raw() if _skater.is_inside_tree() else ""
	if not raw.is_empty():
		_land_surface = raw
	var k: float = clampf(_skater.land_impact, 0.0, 1.0)
	var key: String = land_sample_key(k, _land_surface)
	if _sampled.has(key):
		_play_once(key, lerpf(1.04, 0.96, k), lerpf(LAND_SAMPLE_DB.x, LAND_SAMPLE_DB.y, k))
	else:
		var shape: Array = land_shape(k)
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
	p.bus = sfx_bus()
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
	p.bus = sfx_bus()
	_skater.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)
