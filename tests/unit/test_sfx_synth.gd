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
