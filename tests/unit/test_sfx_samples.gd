extends TestCase
## The offline sample bank (tools/audio/render_sfx.py -> assets/audio/sfx) and how SkateAudio uses it: every mapped
## sound has its files, loops loop, one-shots round-robin through a randomizer, the synth covers missing files, and
## all of it plays on the SFX bus.


func test_every_mapped_sample_exists() -> void:
	var map: Dictionary = SkateAudio.sample_map()
	assert_true(map.size() >= 25, "map size %d" % map.size())
	for key: String in map:
		var paths: PackedStringArray = SkateAudio.sample_paths(str(map[key]))
		assert_true(paths.size() >= 1, key + " has a file")
	for s: String in SkateAudio.LAND_SURFACES:
		for i: String in SkateAudio.LAND_IMPACTS:
			assert_eq(SkateAudio.sample_paths("land_%s_%s" % [s, i]).size(), 3, "%s %s: three round-robin takes" % [s, i])
	assert_eq(SkateAudio.sample_paths("pop").size(), 3, "three pops")


func test_loops_loop_and_one_shots_randomize() -> void:
	for base: String in ["roll_concrete_loop", "roll_wood_loop", "skid_loop", "grind_metal_loop", "grind_concrete_loop",
			"grind_wood_loop"]:
		var st: AudioStreamWAV = SkateAudio.load_sample(base) as AudioStreamWAV
		assert_true(st != null, base + " loads as a wav")
		if st == null:
			continue
		assert_eq(st.loop_mode, AudioStreamWAV.LOOP_FORWARD, base + " loops (smpl chunk)")
		assert_eq(st.mix_rate, 44100, base + " rate")
		assert_true(st.get_length() >= 2.5, base + " long enough not to drone")
	var pop: AudioStreamRandomizer = SkateAudio.load_sample("pop") as AudioStreamRandomizer
	assert_true(pop != null, "pop is a randomizer")
	assert_eq(pop.streams_count, 3)
	assert_true(pop.random_pitch > 1.0 and pop.random_volume_offset_db > 0.0, "pitch and volume spread")
	assert_eq(pop.playback_mode, AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS)
	var start: AudioStreamRandomizer = SkateAudio.load_sample("grind_metal_start") as AudioStreamRandomizer
	assert_true(start != null and start.streams_count == 1, "single take still gets the spread")
	assert_true(SkateAudio.load_sample("no_such_sound") == null, "missing file: null")


func test_streams_prefer_samples_and_fall_back_to_synth() -> void:
	var a: SkateAudio = SkateAudio.new()
	a._build_streams()
	for key: String in ["pop", "roll", "grind", "skid", "bail", "land_wood_hard", "grind_concrete_start"]:
		assert_true(a._sampled.has(key), key + " is sampled")
	for key: String in ["bert", "tow", "ding", "skid_sand", "land", "land_heavy"]:
		assert_false(a._sampled.has(key), key + " stays synth")
		assert_true(a._streams.has(key), key + " built")
	assert_true(a._streams["roll"] is AudioStreamWAV and (a._streams["roll"] as AudioStreamWAV).mix_rate == 44100)
	assert_true(a._streams.has("wallplant") and a._streams.has("push"))
	a.free()


func test_land_sample_key() -> void:
	assert_eq(SkateAudio.land_sample_key(0.1, "concrete"), "land_concrete_soft")
	assert_eq(SkateAudio.land_sample_key(0.5, "wood"), "land_wood_med")
	assert_eq(SkateAudio.land_sample_key(0.9, "metal"), "land_metal_hard")
	assert_eq(SkateAudio.land_sample_key(2.0, "sand"), "land_concrete_hard", "sand lands as concrete, impact clamped")
	assert_eq(SkateAudio.event_sound("wallplant")[0], "wallplant")


func test_sfx_and_music_buses() -> void:
	var sfx: int = AudioServer.get_bus_index(&"SFX")
	assert_true(sfx > 0, "SFX bus from default_bus_layout.tres")
	assert_eq(AudioServer.get_bus_send(sfx), &"Master")
	assert_true(AudioServer.get_bus_index(&"Music") > 0, "music has its own bus")
	assert_eq(SkateAudio.sfx_bus(), &"SFX")
	var before: float = AudioServer.get_bus_volume_db(sfx)
	SkateAudio.set_sfx_volume(0.5)
	assert_true(absf(AudioServer.get_bus_volume_db(sfx) - linear_to_db(0.5)) < 0.01, "slider drives the bus")
	SkateAudio.set_sfx_volume(0.0)
	assert_true(AudioServer.is_bus_mute(sfx), "0 mutes")
	SkateAudio.set_sfx_volume(1.0)
	assert_false(AudioServer.is_bus_mute(sfx))
	AudioServer.set_bus_volume_db(sfx, before)
