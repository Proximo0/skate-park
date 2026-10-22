extends TestCase
## BailFx pure parts: the readout text, the camera shake and punch envelopes, the synthesized crunch and pop.


func test_readout_lines() -> void:
	var p: Dictionary = BailKind.classify({"cause": "land", "kind": "toe_catch", "impact": 16.0, "velocity": Vector3(0, 0, -16)})
	var lines: PackedStringArray = BailFx.readout_lines(p)
	assert_eq(lines.size(), (p["injuries"] as Array).size() + 2, "title, one line per injury, meat")
	assert_eq(lines[0], "TOESIDE FACEPLANT")
	assert_true(lines[lines.size() - 1].begins_with("+") and lines[lines.size() - 1].ends_with(" MEAT"))
	assert_true(lines[lines.size() - 1].contains(","), "meat formatted with thousands commas")
	var off: Dictionary = BailKind.classify({"cause": "land", "kind": "toe_catch", "impact": 16.0}, false)
	assert_eq(BailFx.readout_lines(off).size(), 0, "injuries off: no readout")


func test_shake_and_punch_are_short_and_end_at_rest() -> void:
	assert_eq(BailFx.shake_offset(BailFx.SHAKE_TIME, 1.0), Vector2.ZERO)
	assert_eq(BailFx.shake_offset(-0.1, 1.0), Vector2.ZERO)
	var peak: float = 0.0
	var t: float = 0.0
	while t < BailFx.SHAKE_TIME:
		peak = maxf(peak, BailFx.shake_offset(t, 1.0).length())
		t += 0.005
	assert_true(peak > 0.03 and peak <= BailFx.SHAKE_AMP * 1.3, "a visible but small shake, %f m" % peak)
	assert_true(BailFx.shake_offset(0.05, 0.0).length() <= BailFx.shake_offset(0.05, 1.0).length(), "softer slams shake less")
	assert_eq(BailFx.punch_fov(BailFx.PUNCH_TIME, 1.0), 0.0)
	assert_eq(BailFx.punch_fov(0.0, 1.0), 0.0, "the punch eases in from the chase framing")
	assert_true(BailFx.punch_fov(0.1, 1.0) > 8.0, "and punches in hard")
	assert_true(BailFx.punch_fov(0.1, 0.0) < BailFx.punch_fov(0.1, 1.0), "scaled by severity")


func test_sounds() -> void:
	for st: AudioStreamWAV in [BailFx.crunch_stream(), BailFx.pop_stream()]:
		assert_eq(st.format, AudioStreamWAV.FORMAT_16_BITS)
		assert_eq(st.mix_rate, BailFx.RATE)
		var peak: int = 0
		for i: int in st.data.size() / 2:
			peak = maxi(peak, absi(st.data.decode_s16(i * 2)))
		assert_true(peak > 15000 and peak <= 16384, "peak about -6 dBFS, got %d" % peak)
	assert_true(BailFx.crunch_stream().get_length() < 0.5, "the crunch is short")
	assert_true(BailFx.crunch_stream() == BailFx.crunch_stream(), "built once")


func test_burst_textures() -> void:
	for spiky: bool in [true, false]:
		var tex: ImageTexture = BailFx.burst_texture(spiky)
		var img: Image = tex.get_image()
		assert_eq(img.get_width(), 64)
		assert_eq(img.get_pixel(0, 0).a, 0.0, "transparent corners")
	assert_true(BailFx.burst_texture(true).get_image().get_pixel(32, 32).a > 0.9, "the pow star is solid in the middle")
