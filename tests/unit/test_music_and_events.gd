extends TestCase
## Procedural music, the new event sounds, the trick-text spot picker, music volume and the coach tips for new moves.


func test_every_level_renders_a_seamless_loop() -> void:
	for id: String in ["practice", "warehouse", "beach", "school", "downtown", "hills"]:
		var t0: int = Time.get_ticks_msec()
		var st: AudioStreamWAV = MusicSynth.render(id)
		var ms: int = Time.get_ticks_msec() - t0
		var want: int = int(round(MusicSynth.loop_seconds(id) * SfxSynth.RATE))
		assert_true(absi(st.data.size() / 2 - want) <= 2, id + " loop length")
		assert_eq(st.loop_mode, AudioStreamWAV.LOOP_FORWARD, id + " loops")
		assert_true(ms < 4000, "%s renders in %d ms" % [id, ms])
		var n: int = st.data.size() / 2
		var peak: float = 0.0
		var max_step: float = 0.0
		var prev: float = 0.0
		for i: int in n:
			var v: float = float(st.data.decode_s16(i * 2)) / 32767.0
			peak = maxf(peak, absf(v))
			if i > 0:
				max_step = maxf(max_step, absf(v - prev))
			prev = v
		assert_true(peak > 0.4 and peak < 0.52, id + " peak %f" % peak)
		var first: float = float(st.data.decode_s16(0)) / 32767.0
		assert_true(absf(first - prev) <= max_step + 0.001, id + " seam")


func test_levels_differ_in_tempo() -> void:
	assert_true(MusicSynth.loop_seconds("warehouse") < MusicSynth.loop_seconds("hills"))
	assert_eq(MusicSynth.spec_for("nope"), MusicSynth.spec_for("practice"))


func test_event_sounds_map_and_exist() -> void:
	for e: String in ["grind_switch", "manual_switch", "manual_pivot", "flatland", "lip_pop", "lip_revert", "wall_revert", "link:hubba_to_pole"]:
		var snd: Array = SkateAudio.event_sound(e)
		assert_eq(snd.size(), 3, e + " has a sound")
	assert_eq(SkateAudio.event_sound("ollie"), [], "plain events stay silent")
	var a: SkateAudio = SkateAudio.new()
	a._build_streams()
	for e: String in SkateAudio.EVENT_SOUNDS:
		assert_true(a._streams.has(str(SkateAudio.EVENT_SOUNDS[e][0])), e + " stream built")
	assert_true(a._streams.has("link"))
	a.free()


func test_new_one_shots_format() -> void:
	for st: AudioStreamWAV in [SfxSynth.grind_switch(), SfxSynth.manual_switch(), SfxSynth.manual_pivot(), SfxSynth.flatland(),
			SfxSynth.lip_pop(), SfxSynth.revert_whoosh(), SfxSynth.link()]:
		assert_eq(st.loop_mode, AudioStreamWAV.LOOP_DISABLED)
		assert_eq(st.mix_rate, SfxSynth.RATE)
		assert_true(st.data.size() > 400)


func test_trick_spot_avoids_the_rider() -> void:
	var spots: PackedFloat32Array = Hud.TRICK_ALT_Y
	assert_eq(Hud.trick_spot(spots, 0.2, 0.5, 0.14), spots[0], "rider high: string stays low")
	assert_eq(Hud.trick_spot(spots, 0.6, 0.9, 0.14), spots[1], "rider low: string moves up")
	assert_eq(Hud.trick_spot(spots, 0.1, 0.95, 0.14), spots[spots.size() - 1], "no clear spot: the last")


func test_music_volume_cycle_and_db() -> void:
	assert_eq(GameSettings.next_music_volume(0), 25)
	assert_eq(GameSettings.next_music_volume(50), 75)
	assert_eq(GameSettings.next_music_volume(100), 0, "wraps to off")
	assert_true(MusicPlayer.volume_db_for(0.0) <= -80.0)
	assert_true(MusicPlayer.volume_db_for(1.0) > MusicPlayer.volume_db_for(0.5))


func test_music_off_in_scripted_runs() -> void:
	var mp: MusicPlayer = MusicPlayer.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(mp)
	assert_true(mp._task < 0, "no render started when scripted")
	assert_false(mp.playing)
	mp.free()


func test_coach_tips_for_new_events() -> void:
	assert_eq(CoachTips.tip_for_event("grind_switch"), "rail_switch")
	assert_eq(CoachTips.tip_for_event("manual_pivot"), "manual_switch")
	assert_eq(CoachTips.tip_for_event("lip_revert"), "lip_trick")
	assert_eq(CoachTips.tip_for_event("ollie"), "")
	for id: String in CoachTips.NUDGE_ORDER:
		assert_true(CoachTips.TIPS.has(id), id + " has text")
