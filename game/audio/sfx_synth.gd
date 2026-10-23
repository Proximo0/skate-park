class_name SfxSynth
extends RefCounted
## Placeholder sound effects synthesized in code (no audio files). Pure math: no nodes, no clock, no randf().
## Every stream is 16-bit mono at RATE, normalised to PEAK (-6 dBFS). Noise comes from a seeded
## RandomNumberGenerator. Loops are built to be periodic over their length: every frequency is an integer
## number of Hz and the filters are run over two cycles, keeping the second, so the loop point is seamless.

const RATE: int = 22050
const PEAK: float = 0.501187  ## -6 dBFS
const ATTACK: float = 0.003  ## seconds, short fade-in on every partial to avoid clicks
const LOOP_SECONDS: float = 1.0


## Rolling wheels on pavement: low rumble plus band-limited texture, swelling with a slow wobble.
static func roll_loop() -> AudioStreamWAV:
	var n: int = int(LOOP_SECONDS * RATE)
	var rng := _rng(101)
	var tex: PackedFloat32Array = _lowpass_periodic(_noise(n, rng), 900.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var wobble: float = 0.85 + 0.15 * sin(TAU * 4.0 * t)
		var rumble: float = 0.6 * sin(TAU * 55.0 * t) + 0.25 * sin(TAU * 82.0 * t) + 0.12 * sin(TAU * 110.0 * t)
		out[i] = (0.9 * tex[i] * wobble) + 0.35 * rumble
	return _to_stream(out, true)


## Metal-on-rail scrape: bright band-passed noise with a rattle and a few inharmonic metallic partials.
static func grind_loop() -> AudioStreamWAV:
	var n: int = int(LOOP_SECONDS * RATE)
	var rng := _rng(202)
	var noise: PackedFloat32Array = _noise(n, rng)
	var band: PackedFloat32Array = _bandpass_periodic(noise, 2000.0, 7000.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var rattle: float = 0.6 + 0.4 * sin(TAU * 23.0 * t)
		var ring: float = 0.10 * sin(TAU * 1480.0 * t) + 0.07 * sin(TAU * 2220.0 * t) + 0.04 * sin(TAU * 3350.0 * t)
		out[i] = band[i] * rattle * 0.9 + ring * (0.7 + 0.3 * sin(TAU * 9.0 * t))
	return _to_stream(out, true)


## Powerslide on pavement: urethane squeal (a wavering high tone pair, integer Hz so the loop is seamless) over a
## band-passed grit bed that chatters as the wheels stick and slip.
static func skid_loop() -> AudioStreamWAV:
	var n: int = int(LOOP_SECONDS * RATE)
	var rng := _rng(301)
	var grit: PackedFloat32Array = _bandpass_periodic(_noise(n, rng), 700.0, 3800.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var stick: float = 0.55 + 0.45 * sin(TAU * 13.0 * t) * sin(TAU * 5.0 * t + 0.6)
		var wob: float = 6.0 * sin(TAU * 3.0 * t)
		var squeal: float = 0.34 * sin(TAU * (1180.0 * t + wob / 3.0)) + 0.2 * sin(TAU * (1773.0 * t + wob / 2.0)) \
				+ 0.08 * sin(TAU * 2364.0 * t)
		out[i] = grit[i] * stick * 1.1 + squeal * (0.55 + 0.45 * sin(TAU * 4.0 * t + 1.1))
	return _to_stream(out, true)


## Powerslide on sand or dirt: no squeal, a soft wide hiss and a low drag.
static func skid_sand_loop() -> AudioStreamWAV:
	var n: int = int(LOOP_SECONDS * RATE)
	var rng := _rng(302)
	var hiss: PackedFloat32Array = _bandpass_periodic(_noise(n, rng), 250.0, 3000.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var surge: float = 0.7 + 0.3 * sin(TAU * 6.0 * t)
		out[i] = hiss[i] * surge + 0.18 * sin(TAU * 60.0 * t)
	return _to_stream(out, true)


## Rolling on wood (ramps, decks, boardwalk): a hollow low drone with a regular "ka-thunk" over each plank gap.
static func roll_wood_loop() -> AudioStreamWAV:
	var n: int = int(LOOP_SECONDS * RATE)
	var rng := _rng(111)
	var tex: PackedFloat32Array = _lowpass_periodic(_noise(n, rng), 600.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var phase: float = fposmod(t * 8.0, 1.0)  ## 8 plank seams per second
		var knock: float = exp(-phase * 22.0) * sin(TAU * 140.0 * t)
		var hollow: float = 0.5 * sin(TAU * 70.0 * t) + 0.2 * sin(TAU * 96.0 * t)
		out[i] = 0.55 * tex[i] + 0.4 * hollow + 0.7 * knock
	return _to_stream(out, true)


## Grinding a concrete ledge: a low gritty scrape, darker and rougher than the rail's ring.
static func grind_concrete_loop() -> AudioStreamWAV:
	var n: int = int(LOOP_SECONDS * RATE)
	var rng := _rng(212)
	var band: PackedFloat32Array = _bandpass_periodic(_noise(n, rng), 300.0, 2600.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var grit: float = 0.55 + 0.45 * sin(TAU * 31.0 * t) * sin(TAU * 7.0 * t)
		out[i] = band[i] * grit + 0.25 * sin(TAU * 90.0 * t)
	return _to_stream(out, true)


## Sliding along wood (a coping, a bench slat): a soft dull rasp.
static func grind_wood_loop() -> AudioStreamWAV:
	var n: int = int(LOOP_SECONDS * RATE)
	var rng := _rng(213)
	var band: PackedFloat32Array = _bandpass_periodic(_noise(n, rng), 200.0, 1400.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		out[i] = band[i] * (0.7 + 0.3 * sin(TAU * 13.0 * t)) + 0.3 * sin(TAU * 120.0 * t)
	return _to_stream(out, true)


## A hard landing from a big drop: the thud plus a sub boom and a board clack, about 0.32 s. Played louder and
## lower for harder impacts.
static func land_heavy() -> AudioStreamWAV:
	var out := _buffer(0.32)
	_add_tone(out, 0.0, 0.32, 90.0, 38.0, 1.0, 0.1, 0.2)
	_add_tone(out, 0.0, 0.12, 260.0, 160.0, 0.5, 0.04)
	var rng := _rng(414)
	_add_noise(out, 0.0, 0.03, 0.8, 0.008, rng, 3200.0)
	_add_noise(out, 0.045, 0.04, 0.4, 0.01, rng, 5000.0)  ## the board slapping back down
	return _to_stream(out, false)


## Looping ambience, 2 s, quiet: "crowd" (a murmur with swells and the odd cheer-ish rise), "wind", "surf"
## (slow wave wash), "hum" (warehouse fans and mains hum), "city" (distant traffic).
static func ambience_loop(kind: String) -> AudioStreamWAV:
	var n: int = int(2.0 * RATE)
	var rng := _rng(700 + kind.length())
	var noise: PackedFloat32Array = _noise(n, rng)
	var out := PackedFloat32Array()
	out.resize(n)
	match kind:
		"crowd":
			var a: PackedFloat32Array = _bandpass_periodic(noise, 250.0, 1800.0)
			for i: int in n:
				var t: float = float(i) / RATE
				out[i] = a[i] * (0.6 + 0.25 * sin(TAU * 0.5 * t) + 0.15 * sin(TAU * 1.5 * t + 1.0))
		"wind":
			var a: PackedFloat32Array = _bandpass_periodic(noise, 150.0, 900.0)
			for i: int in n:
				var t: float = float(i) / RATE
				out[i] = a[i] * (0.55 + 0.45 * sin(TAU * 0.5 * t))
		"surf":
			var a: PackedFloat32Array = _lowpass_periodic(noise, 1400.0)
			for i: int in n:
				var t: float = float(i) / RATE
				var wave: float = 0.5 + 0.5 * sin(TAU * 0.5 * t - 1.2)
				out[i] = a[i] * (0.15 + 0.85 * wave * wave)
		"hum":
			var a: PackedFloat32Array = _lowpass_periodic(noise, 300.0)
			for i: int in n:
				var t: float = float(i) / RATE
				out[i] = 0.5 * a[i] + 0.5 * sin(TAU * 50.0 * t) + 0.25 * sin(TAU * 100.0 * t) + 0.1 * sin(TAU * 150.0 * t)
		_:  ## "city"
			var a: PackedFloat32Array = _lowpass_periodic(noise, 500.0)
			for i: int in n:
				var t: float = float(i) / RATE
				out[i] = a[i] * (0.7 + 0.3 * sin(TAU * 1.0 * t + 0.5)) + 0.15 * sin(TAU * 60.0 * t)
	return _to_stream(out, true)


## Ollie: a short woody click, about 80 ms.
static func pop() -> AudioStreamWAV:
	var out := _buffer(0.08)
	_add_tone(out, 0.0, 0.08, 520.0, 380.0, 0.9, 0.012, 0.2)
	_add_tone(out, 0.0, 0.03, 1250.0, 1100.0, 0.25, 0.004)
	var rng := _rng(303)
	_add_noise(out, 0.0, 0.006, 0.5, 0.002, rng, 4000.0)
	return _to_stream(out, false)


## Landing: a soft thud plus a wooden clack, about 150 ms.
static func land() -> AudioStreamWAV:
	var out := _buffer(0.15)
	_add_tone(out, 0.0, 0.15, 120.0, 55.0, 1.0, 0.05)
	_add_tone(out, 0.0, 0.05, 1800.0, 1700.0, 0.3, 0.008, 0.3)
	var rng := _rng(404)
	_add_noise(out, 0.0, 0.01, 0.6, 0.003, rng, 5000.0)
	return _to_stream(out, false)


## Bail: a cartoon "bonk" followed by a slide-and-skid, about 0.7 s.
static func bail() -> AudioStreamWAV:
	var out := _buffer(0.7)
	_add_tone(out, 0.0, 0.25, 360.0, 140.0, 0.9, 0.07, 0.5)
	_add_tone(out, 0.0, 0.12, 700.0, 520.0, 0.3, 0.03)
	var rng := _rng(505)
	# Slide: noise that swells, then dies away over the skid.
	var slide_len: float = 0.6
	var slide := _buffer(slide_len)
	_add_noise(slide, 0.0, slide_len, 1.0, 0.25, rng, 1600.0)
	var s0: int = int(0.05 * RATE)
	for i: int in slide.size():
		if i + s0 < out.size():
			out[i + s0] += 0.6 * slide[i] * minf(1.0, float(i) / (0.08 * RATE))
	return _to_stream(out, false)


## Trick landed: cheerful two-note chime (G6 then C7).
static func trick_ding() -> AudioStreamWAV:
	var out := _buffer(0.4)
	_add_tone(out, 0.0, 0.3, 1568.0, 1568.0, 0.8, 0.09, 0.25)
	_add_tone(out, 0.09, 0.31, 2093.0, 2093.0, 0.7, 0.10, 0.25)
	return _to_stream(out, false)


## Combo landed: rising three-note arpeggio (C5, E5, G5).
static func combo_land() -> AudioStreamWAV:
	var out := _buffer(0.6)
	_add_tone(out, 0.00, 0.35, 523.25, 523.25, 0.7, 0.12, 0.25)
	_add_tone(out, 0.11, 0.35, 659.25, 659.25, 0.7, 0.12, 0.25)
	_add_tone(out, 0.22, 0.38, 783.99, 783.99, 0.8, 0.14, 0.25)
	return _to_stream(out, false)


## Grind switch: a metallic tick and a quick upward chirp as the board shifts onto the other trucks, about 0.14 s.
static func grind_switch() -> AudioStreamWAV:
	var out := _buffer(0.14)
	_add_tone(out, 0.0, 0.12, 900.0, 1500.0, 0.55, 0.04, 0.3)
	_add_tone(out, 0.0, 0.05, 2400.0, 2100.0, 0.3, 0.012)
	var rng := _rng(601)
	_add_noise(out, 0.0, 0.02, 0.6, 0.005, rng, 6000.0)
	return _to_stream(out, false)


## Manual switch: two soft wheel clicks, one low and one a step up, about 0.12 s.
static func manual_switch() -> AudioStreamWAV:
	var out := _buffer(0.12)
	_add_tone(out, 0.0, 0.05, 300.0, 240.0, 0.7, 0.02)
	_add_tone(out, 0.05, 0.07, 420.0, 340.0, 0.7, 0.025)
	var rng := _rng(602)
	_add_noise(out, 0.0, 0.01, 0.3, 0.003, rng, 3000.0)
	_add_noise(out, 0.05, 0.01, 0.3, 0.003, rng, 3000.0)
	return _to_stream(out, false)


## Manual pivot: a spin whoosh (noise that swells and fades) with a wheel chirp, about 0.3 s.
static func manual_pivot() -> AudioStreamWAV:
	var out := _buffer(0.3)
	var rng := _rng(603)
	_add_noise(out, 0.0, 0.3, 0.9, 0.09, rng, 1800.0)
	_add_tone(out, 0.0, 0.25, 500.0, 900.0, 0.3, 0.1)
	return _to_stream(out, false)


## Flatland: a bright two-note blip (E6 up to A6), cheerful and short, about 0.2 s.
static func flatland() -> AudioStreamWAV:
	var out := _buffer(0.2)
	_add_tone(out, 0.0, 0.1, 1318.5, 1318.5, 0.7, 0.05, 0.2)
	_add_tone(out, 0.07, 0.13, 1760.0, 1760.0, 0.8, 0.06, 0.2)
	return _to_stream(out, false)


## Pop out of a lip stall: a hollow coping knock then a pop, about 0.18 s.
static func lip_pop() -> AudioStreamWAV:
	var out := _buffer(0.18)
	_add_tone(out, 0.0, 0.1, 190.0, 110.0, 0.9, 0.04, 0.3)
	_add_tone(out, 0.03, 0.1, 520.0, 700.0, 0.6, 0.03, 0.2)
	var rng := _rng(605)
	_add_noise(out, 0.0, 0.015, 0.5, 0.004, rng, 4500.0)
	return _to_stream(out, false)


## Revert off a lip or a wall: a short cloth-and-wheels whoosh with a clack, about 0.26 s.
static func revert_whoosh() -> AudioStreamWAV:
	var out := _buffer(0.26)
	var rng := _rng(606)
	_add_noise(out, 0.0, 0.26, 0.8, 0.07, rng, 2400.0)
	_add_tone(out, 0.12, 0.1, 240.0, 160.0, 0.6, 0.04)
	return _to_stream(out, false)


## Rail transfer / link: a quick bright rising sparkle (C6 E6 G6 C7), about 0.3 s.
static func link() -> AudioStreamWAV:
	var out := _buffer(0.32)
	var notes: Array[float] = [1046.5, 1318.5, 1568.0, 2093.0]
	for i: int in notes.size():
		_add_tone(out, 0.045 * float(i), 0.2, notes[i], notes[i], 0.6, 0.07, 0.15)
	return _to_stream(out, false)


## Bert slide: a hand and shoe dragging on a bank. Rougher than the powerslide: no squeal, a low scuffing drag with
## coarse stick-slip chatter over a gritty mid band.
static func bert_loop() -> AudioStreamWAV:
	var n: int = int(LOOP_SECONDS * RATE)
	var rng := _rng(311)
	var grit: PackedFloat32Array = _bandpass_periodic(_noise(n, rng), 300.0, 2600.0)
	var drag: PackedFloat32Array = _lowpass_periodic(_noise(n, rng), 260.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var chatter: float = 0.45 + 0.55 * absf(sin(TAU * 11.0 * t) * sin(TAU * 7.0 * t + 0.4))
		out[i] = grit[i] * chatter * 1.1 + drag[i] * 1.6 * (0.7 + 0.3 * sin(TAU * 3.0 * t))
	return _to_stream(out, true)


## Skitch tow: a small engine idling ahead (a low rough buzz with a firing wobble) under the wheels' rumble.
static func tow_loop() -> AudioStreamWAV:
	var n: int = int(LOOP_SECONDS * RATE)
	var rng := _rng(321)
	var tex: PackedFloat32Array = _lowpass_periodic(_noise(n, rng), 500.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var fire: float = 0.7 + 0.3 * sin(TAU * 24.0 * t)
		var eng: float = 0.55 * sin(TAU * 48.0 * t) + 0.35 * sin(TAU * 96.0 * t) + 0.2 * sin(TAU * 144.0 * t) \
				+ 0.08 * sin(TAU * 240.0 * t)
		out[i] = eng * fire + 0.6 * tex[i]
	return _to_stream(out, true)


## Sticker slap: a flat palm-and-sole smack on the wall, about 0.16 s.
static func slap() -> AudioStreamWAV:
	var out := _buffer(0.16)
	var rng := _rng(607)
	_add_noise(out, 0.0, 0.1, 1.0, 0.018, rng, 5200.0)
	_add_tone(out, 0.0, 0.14, 260.0, 110.0, 0.8, 0.04, 0.3)
	return _to_stream(out, false)


## Focus on: a falling, slowing swoop. Focus off: the same rising back.
static func focus_swoop(on: bool) -> AudioStreamWAV:
	var out := _buffer(0.45)
	var rng := _rng(608 if on else 609)
	var f0: float = 900.0 if on else 220.0
	var f1: float = 220.0 if on else 900.0
	_add_tone(out, 0.0, 0.4, f0, f1, 0.7, 0.2, 0.2)
	_add_noise(out, 0.0, 0.4, 0.35, 0.12, rng, 1800.0 if on else 3000.0)
	return _to_stream(out, false)


## Menu move: a short soft tick.
static func ui_move() -> AudioStreamWAV:
	var out := _buffer(0.04)
	_add_tone(out, 0.0, 0.04, 1000.0, 1000.0, 1.0, 0.008)
	return _to_stream(out, false)


## Menu accept: two quick rising blips (C6 then G6).
static func ui_accept() -> AudioStreamWAV:
	var out := _buffer(0.2)
	_add_tone(out, 0.0, 0.09, 1046.5, 1046.5, 0.8, 0.04, 0.2)
	_add_tone(out, 0.06, 0.14, 1568.0, 1568.0, 0.9, 0.05, 0.2)
	return _to_stream(out, false)


# --- helpers (underscore-prefixed, file-local by convention) ------------------------------------------

static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _buffer(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


static func _noise(n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


## One-pole low-pass, run over two cycles of the buffer and keeping the second, so it is periodic.
static func _lowpass_periodic(x: PackedFloat32Array, cutoff_hz: float) -> PackedFloat32Array:
	var n: int = x.size()
	var a: float = 1.0 - exp(-TAU * cutoff_hz / RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y: float = 0.0
	for cycle: int in 2:
		for i: int in n:
			y += a * (x[i] - y)
			if cycle == 1:
				out[i] = y
	return out


static func _bandpass_periodic(x: PackedFloat32Array, low_hz: float, high_hz: float) -> PackedFloat32Array:
	var hi: PackedFloat32Array = _lowpass_periodic(x, high_hz)
	var lo: PackedFloat32Array = _lowpass_periodic(x, low_hz)
	var out := PackedFloat32Array()
	out.resize(x.size())
	for i: int in x.size():
		out[i] = hi[i] - lo[i]
	return out


## Adds a sine that sweeps f0 -> f1 with an exponential decay (time constant tau) and an optional 2nd harmonic.
static func _add_tone(buf: PackedFloat32Array, start: float, length: float, f0: float, f1: float,
		amp: float, tau: float, harmonic: float = 0.0) -> void:
	var s0: int = int(start * RATE)
	var n: int = int(length * RATE)
	var phase: float = 0.0
	for i: int in n:
		var idx: int = s0 + i
		if idx < 0 or idx >= buf.size():
			continue
		var t: float = float(i) / RATE
		var f: float = lerpf(f0, f1, float(i) / maxf(1.0, float(n)))
		phase += TAU * f / RATE
		var env: float = amp * exp(-t / tau) * minf(1.0, t / ATTACK)
		buf[idx] += env * (sin(phase) + harmonic * sin(2.0 * phase))


## Adds one-pole filtered noise with an exponential decay.
static func _add_noise(buf: PackedFloat32Array, start: float, length: float, amp: float, tau: float,
		rng: RandomNumberGenerator, cutoff_hz: float) -> void:
	var s0: int = int(start * RATE)
	var n: int = int(length * RATE)
	var a: float = 1.0 - exp(-TAU * cutoff_hz / RATE)
	var y: float = 0.0
	for i: int in n:
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		var idx: int = s0 + i
		if idx < 0 or idx >= buf.size():
			continue
		var t: float = float(i) / RATE
		buf[idx] += amp * exp(-t / tau) * minf(1.0, t / ATTACK) * y


## Normalises to PEAK and packs 16-bit little-endian mono PCM.
static func _to_stream(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak: float = 0.0
	for s: float in buf:
		peak = maxf(peak, absf(s))
	var scale: float = PEAK / peak if peak > 0.0 else 0.0
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i: int in buf.size():
		var v: int = clampi(roundi(buf[i] * scale * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, v)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	if loop:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = buf.size()
	return st
