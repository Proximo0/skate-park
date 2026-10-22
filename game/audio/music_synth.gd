class_name MusicSynth
extends RefCounted
## Background music rendered in code: a 4-bar loop per level built from drum, bass, chord and pluck voices (mellow
## hip-hop for the practice park, punk for the warehouse, surf for the beach, and so on). Pure math with seeded
## noise, no nodes and no clock, so a loop is the same every time. Voices wrap around the end of the buffer, which
## makes the loop point seamless. render() takes a fraction of a second to a second of CPU: call it off the main
## thread (MusicPlayer does) and play the result as an ordinary looping AudioStreamWAV.

const RATE: int = 22050
const BARS: int = 4
const STEPS: int = 16  ## sixteenth notes per bar
const CHORDS: Dictionary = {
	"m": [0, 3, 7], "M": [0, 4, 7], "5": [0, 7, 12], "m7": [0, 3, 7, 10], "M7": [0, 4, 7, 11],
}
const PENT_MINOR: Array[int] = [0, 3, 5, 7, 10]
const PENT_MAJOR: Array[int] = [0, 2, 4, 7, 9]

## Per level: bpm, swing (0..0.3 delay of off-beat sixteenths), root (MIDI of the bass root), minor (lead scale),
## prog (one [semitones from root, chord type] per bar), kick/snare/hat (16-step "x" strings), bass (16-step string:
## x root, o octave, f fifth), chords (stab every bar start: 0 none, 1 stab, 2 sustained pad), lead (0..1 note density),
## drive (0..1 bass overtones: punk grit), seed.
const SPECS: Dictionary = {
	"practice": {"bpm": 88, "swing": 0.14, "root": 45, "minor": true,
			"prog": [[0, "m7"], [8, "M7"], [3, "M7"], [10, "M"]],
			"kick": "x.....x..x.x....", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.xx",
			"bass": "x..x..o...x.f...", "chords": 2, "lead": 0.22, "drive": 0.0, "seed": 11},
	"warehouse": {"bpm": 152, "swing": 0.0, "root": 40, "minor": true,
			"prog": [[0, "5"], [0, "5"], [5, "5"], [7, "5"]],
			"kick": "x.....x.x.x.....", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x.",
			"bass": "x.x.x.x.x.x.x.x.", "chords": 1, "lead": 0.0, "drive": 1.0, "seed": 22},
	"beach": {"bpm": 100, "swing": 0.06, "root": 43, "minor": false,
			"prog": [[0, "M"], [5, "M"], [7, "M"], [5, "M"]],
			"kick": "x.......x.x.....", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x.",
			"bass": "x...x.f.x...x.o.", "chords": 1, "lead": 0.42, "drive": 0.0, "seed": 33},
	"school": {"bpm": 128, "swing": 0.0, "root": 43, "minor": false,
			"prog": [[0, "5"], [7, "5"], [9, "5"], [5, "5"]],
			"kick": "x.......x.x.....", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x.",
			"bass": "x.x.x.x.x.x.x.x.", "chords": 1, "lead": 0.3, "drive": 0.6, "seed": 44},
	"downtown": {"bpm": 92, "swing": 0.18, "root": 38, "minor": true,
			"prog": [[0, "m7"], [5, "M7"], [10, "M7"], [7, "m7"]],
			"kick": "x..x.....x.x....", "snare": "....x.......x..x", "hat": "x.xxx.x.x.xxx.x.",
			"bass": "x.....f.x..x..o.", "chords": 2, "lead": 0.16, "drive": 0.0, "seed": 55},
	"hills": {"bpm": 76, "swing": 0.2, "root": 41, "minor": false,
			"prog": [[0, "M7"], [9, "m7"], [2, "m7"], [7, "M"]],
			"kick": "x.......x.x.....", "snare": "........x.......", "hat": "x...x...x...x...",
			"bass": "x.......o.x.....", "chords": 2, "lead": 0.2, "drive": 0.0, "seed": 66},
}


## Loop length in seconds for a level's spec (BARS bars at its tempo). Pure.
static func loop_seconds(level_id: String) -> float:
	return float(BARS * 4) * 60.0 / float(spec_for(level_id)["bpm"])


static func spec_for(level_id: String) -> Dictionary:
	return SPECS.get(level_id, SPECS["practice"])


static func midi_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


## Renders the level's loop as a looping 16-bit mono stream (normalised to -6 dBFS: play it quietly).
static func render(level_id: String) -> AudioStreamWAV:
	var sp: Dictionary = spec_for(level_id)
	var step_s: float = 60.0 / float(sp["bpm"]) / 4.0
	var n: int = int(round(step_s * float(STEPS * BARS) * RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(sp["seed"])
	var prog: Array = sp["prog"]
	var scale: Array[int] = PENT_MINOR if bool(sp["minor"]) else PENT_MAJOR
	var swing: float = float(sp["swing"])
	for bar: int in BARS:
		var chord: Array = prog[bar % prog.size()]
		var root: float = float(sp["root"]) + float(chord[0])
		var tones: Array = CHORDS[chord[1]]
		var t_bar: float = float(bar * STEPS) * step_s
		if int(sp["chords"]) > 0:
			var dur: float = step_s * (14.0 if int(sp["chords"]) == 2 else 3.0)
			for semi: int in tones:
				_voice(buf, t_bar, dur, midi_hz(root + 24.0 + float(semi)), 0.06, dur * 0.5 if int(sp["chords"]) == 2 else 0.09, 0.0, 0.0, 0.02)
		for s: int in STEPS:
			var t: float = t_bar + float(s) * step_s + (swing * step_s if s % 2 == 1 else 0.0)
			if _hit(sp["kick"], s):
				_kick(buf, t)
			if _hit(sp["snare"], s):
				_snare(buf, t, rng)
			if _hit(sp["hat"], s):
				_hat(buf, t, rng, 0.14 if s % 4 != 0 else 0.22)
			var b: String = str(sp["bass"]).substr(s, 1)
			if b != "." and b != "":
				var note: float = root
				if b == "o":
					note += 12.0
				elif b == "f":
					note += 7.0
				var len_s: float = step_s * (1.6 if float(sp["drive"]) < 0.5 else 1.8)
				_voice(buf, t, len_s, midi_hz(note), 0.5, 0.16 if float(sp["drive"]) < 0.5 else 0.3,
						0.18 + 0.5 * float(sp["drive"]), 0.1 + 0.4 * float(sp["drive"]), 0.006)
			var density: float = float(sp["lead"])
			if density > 0.0 and s % 2 == 0 and rng.randf() < density:
				var deg: int = rng.randi_range(0, scale.size() - 1)
				var oct: int = 36 + (12 if rng.randf() < 0.3 else 0)
				_voice(buf, t, step_s * 3.0, midi_hz(root + float(oct + scale[deg])), 0.2, 0.13, 0.25, 0.0, 0.004)
	_soft_clip(buf)
	return SfxSynth._to_stream(buf, true)


static func _hit(pattern: String, step: int) -> bool:
	return pattern.substr(step, 1) == "x"


## Adds `v` at sample `idx`, wrapping past the end so the loop has no seam.
static func _put(buf: PackedFloat32Array, idx: int, v: float) -> void:
	buf[idx % buf.size()] += v


## A pitched voice: sine with 2nd / 3rd harmonics, a short attack, a held body and an exponential tail.
## tau is the decay time constant.
static func _voice(buf: PackedFloat32Array, start: float, length: float, hz: float, amp: float, tau: float,
		h2: float, h3: float, attack: float) -> void:
	var s0: int = int(start * RATE)
	var n: int = int(length * RATE)
	var w: float = TAU * hz / RATE
	var atk: float = maxf(attack, 0.002)
	for i: int in n:
		var t: float = float(i) / RATE
		var env: float = amp * exp(-t / maxf(tau, 0.001)) * minf(1.0, t / atk) * minf(1.0, (length - t) / 0.02)
		var ph: float = w * float(i)
		_put(buf, s0 + i, env * (sin(ph) + h2 * sin(2.0 * ph) + h3 * sin(3.0 * ph)))


static func _kick(buf: PackedFloat32Array, start: float) -> void:
	var s0: int = int(start * RATE)
	var n: int = int(0.22 * RATE)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		phase += TAU * (46.0 + 90.0 * exp(-t / 0.035)) / RATE
		_put(buf, s0 + i, 0.9 * exp(-t / 0.085) * minf(1.0, t / 0.002) * sin(phase))


static func _snare(buf: PackedFloat32Array, start: float, rng: RandomNumberGenerator) -> void:
	var s0: int = int(start * RATE)
	var n: int = int(0.16 * RATE)
	var y: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		y += 0.5 * (rng.randf_range(-1.0, 1.0) - y)
		var body: float = sin(TAU * 190.0 * t) * exp(-t / 0.035)
		_put(buf, s0 + i, 0.5 * y * exp(-t / 0.05) + 0.35 * body)


static func _hat(buf: PackedFloat32Array, start: float, rng: RandomNumberGenerator, amp: float) -> void:
	var s0: int = int(start * RATE)
	var n: int = int(0.05 * RATE)
	var prev: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		var x: float = rng.randf_range(-1.0, 1.0)
		_put(buf, s0 + i, amp * exp(-t / 0.015) * (x - prev))  ## the difference of noise: a cheap high-pass
		prev = x


## Keeps the sum of voices from clipping before normalising.
static func _soft_clip(buf: PackedFloat32Array) -> void:
	for i: int in buf.size():
		buf[i] = tanh(buf[i] * 1.2)
