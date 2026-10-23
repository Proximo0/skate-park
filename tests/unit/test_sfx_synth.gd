extends TestCase
## SfxSynth: format, length, peak level and loop flags for every synthesized stream.


func _sfx_samples(st: AudioStreamWAV) -> PackedFloat32Array:
	var n: int = st.data.size() / 2
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		out[i] = float(st.data.decode_s16(i * 2)) / 32767.0
	return out


func _sfx_peak(samples: PackedFloat32Array) -> float:
	var p: float = 0.0
	for s: float in samples:
		p = maxf(p, absf(s))
	return p


func _sfx_check_format(st: AudioStreamWAV, expected_samples: int, label: String) -> void:
	assert_true(st != null, label)
	if st == null:
		return
	assert_eq(st.format, AudioStreamWAV.FORMAT_16_BITS, label + " format")
	assert_eq(st.mix_rate, SfxSynth.RATE, label + " rate")
	assert_false(st.stereo, label + " mono")
	assert_eq(st.data.size(), expected_samples * 2, label + " byte length")
	var peak: float = _sfx_peak(_sfx_samples(st))
	# -6 dBFS is 0.5012 of full scale. Allow a little rounding room either side.
	assert_true(peak > 0.45 and peak <= 0.5015, label + " peak %f" % peak)


func _sfx_check_loop(st: AudioStreamWAV, label: String) -> void:
	assert_eq(st.loop_mode, AudioStreamWAV.LOOP_FORWARD, label + " loop mode")
	assert_eq(st.loop_begin, 0, label + " loop begin")
	assert_eq(st.loop_end, st.data.size() / 2, label + " loop end")
	# Seamless loop: the step from the last sample back to the first is no bigger than the largest step inside.
	var s: PackedFloat32Array = _sfx_samples(st)
	var max_step: float = 0.0
	for i: int in range(1, s.size()):
		max_step = maxf(max_step, absf(s[i] - s[i - 1]))
	var wrap_step: float = absf(s[0] - s[s.size() - 1])
	assert_true(wrap_step <= max_step + 0.0001, label + " wrap step %f > max %f" % [wrap_step, max_step])


func _sfx_check_one_shot(st: AudioStreamWAV, label: String) -> void:
	assert_eq(st.loop_mode, AudioStreamWAV.LOOP_DISABLED, label + " no loop")


func test_roll_loop() -> void:
	var st: AudioStreamWAV = SfxSynth.roll_loop()
	_sfx_check_format(st, 22050, "roll")
	_sfx_check_loop(st, "roll")


func test_grind_loop() -> void:
	var st: AudioStreamWAV = SfxSynth.grind_loop()
	_sfx_check_format(st, 22050, "grind")
	_sfx_check_loop(st, "grind")


func test_pop() -> void:
	var st: AudioStreamWAV = SfxSynth.pop()
	_sfx_check_format(st, int(0.08 * SfxSynth.RATE), "pop")
	_sfx_check_one_shot(st, "pop")


func test_land() -> void:
	var st: AudioStreamWAV = SfxSynth.land()
	_sfx_check_format(st, int(0.15 * SfxSynth.RATE), "land")
	_sfx_check_one_shot(st, "land")


func test_bail() -> void:
	var st: AudioStreamWAV = SfxSynth.bail()
	_sfx_check_format(st, int(0.7 * SfxSynth.RATE), "bail")
	_sfx_check_one_shot(st, "bail")


func test_trick_ding() -> void:
	var st: AudioStreamWAV = SfxSynth.trick_ding()
	_sfx_check_format(st, int(0.4 * SfxSynth.RATE), "ding")
	_sfx_check_one_shot(st, "ding")


func test_combo_land() -> void:
	var st: AudioStreamWAV = SfxSynth.combo_land()
	_sfx_check_format(st, int(0.6 * SfxSynth.RATE), "combo")
	_sfx_check_one_shot(st, "combo")


func test_ui_move() -> void:
	var st: AudioStreamWAV = SfxSynth.ui_move()
	_sfx_check_format(st, int(0.04 * SfxSynth.RATE), "ui_move")
	_sfx_check_one_shot(st, "ui_move")


func test_ui_accept() -> void:
	var st: AudioStreamWAV = SfxSynth.ui_accept()
	_sfx_check_format(st, int(0.2 * SfxSynth.RATE), "ui_accept")
	_sfx_check_one_shot(st, "ui_accept")


func test_noise_is_seeded() -> void:
	# Same seed, same bytes: the loops are reproducible run to run.
	assert_true(SfxSynth.roll_loop().data == SfxSynth.roll_loop().data, "roll repeatable")
	assert_true(SfxSynth.grind_loop().data == SfxSynth.grind_loop().data, "grind repeatable")
	assert_true(SfxSynth.bail().data == SfxSynth.bail().data, "bail repeatable")


func test_material_loops() -> void:
	for st: AudioStreamWAV in [SfxSynth.roll_wood_loop(), SfxSynth.grind_concrete_loop(), SfxSynth.grind_wood_loop()]:
		_sfx_check_format(st, 22050, "material loop")
		_sfx_check_loop(st, "material loop")


func test_land_heavy() -> void:
	var st: AudioStreamWAV = SfxSynth.land_heavy()
	_sfx_check_format(st, int(0.32 * SfxSynth.RATE), "land_heavy")
	_sfx_check_one_shot(st, "land_heavy")


func test_ambience_loops() -> void:
	for kind: String in ["crowd", "wind", "surf", "hum", "city"]:
		var st: AudioStreamWAV = SfxSynth.ambience_loop(kind)
		_sfx_check_format(st, 44100, "ambience " + kind)
		_sfx_check_loop(st, "ambience " + kind)


func test_surface_classification() -> void:
	assert_eq(SkateAudio.classify_surface(PackedStringArray(["Collision", "Quarterpipe_1", "Park"])), "wood")
	assert_eq(SkateAudio.classify_surface(PackedStringArray(["Ground", "Park"])), "concrete")
	assert_eq(SkateAudio.classify_surface(PackedStringArray(["Handrail", "Ramp"])), "metal")
	assert_eq(SkateAudio.classify_grind("GrindRail_3"), "metal")
	assert_eq(SkateAudio.classify_grind("Ledge_box"), "concrete")
	assert_eq(SkateAudio.classify_grind("Coping_N"), "wood")


func test_landing_shape_scales_with_impact() -> void:
	var soft: Array = SkateAudio.land_shape(0.1)
	var hard: Array = SkateAudio.land_shape(0.9)
	assert_eq(soft[0], "land")
	assert_eq(hard[0], "land_heavy")
	assert_true(float(hard[2]) > float(soft[2]) and float(hard[1]) < float(soft[1]), "harder: louder and lower")
	assert_eq(SkateAudio.ambience_for("beach"), "surf")
	assert_eq(SkateAudio.ambience_for("nonsense"), "crowd")


func test_skid_loops_and_shape() -> void:
	for st: AudioStreamWAV in [SfxSynth.skid_loop(), SfxSynth.skid_sand_loop()]:
		_sfx_check_format(st, SfxSynth.RATE, "skid")
		_sfx_check_loop(st, "skid")
	assert_eq(SkateAudio.classify_surface(PackedStringArray(["Sand", "Park"])), "sand")
	assert_eq(SkateAudio.classify_surface(PackedStringArray(["Ground", "Park"])), "concrete")
	var slow: Vector2 = SkateAudio.skid_shape(2.0)
	var fast: Vector2 = SkateAudio.skid_shape(20.0)
	assert_true(fast.x > slow.x and fast.y > slow.y, "faster slide: louder and higher")
	assert_true(fast.x <= SkateAudio.SKID_DB.y + 0.001, "capped at the top of the range")
