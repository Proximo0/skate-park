#!/usr/bin/env python3
"""Offline skate sample bank: physically-modelled one-shots and loops, 44.1 kHz 16-bit mono .wav.

Usage: python3 tools/audio/render_sfx.py [out_dir]      (default: assets/audio/sfx next to the repo root)
       python3 tools/audio/render_sfx.py --list          (names only)

Needs numpy + scipy. Every sound is seeded, so a re-render gives the same bytes (the bank is reproducible and the
repo keeps both this script and its output). The game loads the files by name in game/audio/skate_audio.gd and
falls back to game/audio/sfx_synth.gd when one is missing.

Model, per sound (see the docstrings): an excitation (a filtered noise burst, an impulse, a Poisson train of
stick-slip grains) is convolved with modal impulse responses (sums of damped sines) for the bodies that ring
(7-ply maple deck, aluminium trucks, steel rail, plywood ramp over framing, concrete slab, a torso), layered with
filtered noise beds, then put through a short outdoor room (early reflections + a 0.2 s diffuse tail).
Loops are rendered long and cross-faded end-into-start, so the loop point is seamless; a 'smpl' chunk carries the
loop points (Godot's importer reads it with loop mode "Detect From WAV").
"""
import os
import struct
import sys

import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# --- DSP building blocks -------------------------------------------------------------------------------------------


def secs(n):
    return np.arange(n) / SR


def buf(seconds):
    return np.zeros(int(round(seconds * SR)))


def _sos(kind, f):
    return signal.butter(2, f, kind, fs=SR, output="sos")


def lp(x, f):
    return signal.sosfilt(_sos("lowpass", f), x)


def hp(x, f):
    return signal.sosfilt(_sos("highpass", f), x)


def bp(x, lo, hi):
    return signal.sosfilt(_sos("bandpass", [lo, hi]), x)


def lp_loop(x, f):
    """Low-pass with a warm start (filter run over the tail first) so a loop has no settling transient."""
    pre = min(len(x), int(0.2 * SR))
    return lp(np.concatenate([x[-pre:], x]), f)[pre:]


def bp_loop(x, lo, hi):
    pre = min(len(x), int(0.2 * SR))
    return bp(np.concatenate([x[-pre:], x]), lo, hi)[pre:]


def modal_ir(freqs, taus, gains, seconds, rng=None, detune=0.0):
    """Impulse response of a resonant body: a sum of damped sines (one per mode)."""
    t = secs(int(seconds * SR))
    out = np.zeros_like(t)
    for f, tau, g in zip(freqs, taus, gains):
        if rng is not None and detune > 0.0:
            f *= 1.0 + rng.uniform(-detune, detune)
        ph = 0.0 if rng is None else rng.uniform(0, 2 * np.pi)
        out += g * np.exp(-t / tau) * np.sin(2 * np.pi * f * t + ph)
    k = max(1, len(t) // 5)  # a truncated ring would click: fade the last fifth
    out[-k:] *= 0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, k))
    return out


def conv(x, ir):
    return signal.fftconvolve(x, ir)[: len(x)]


def burst(rng, seconds, tau, lo=None, hi=None):
    """Exponentially decaying noise burst (the contact itself), optionally band-limited."""
    n = int(seconds * SR)
    x = rng.standard_normal(n) * np.exp(-secs(n) / tau)
    if lo and hi:
        x = bp(x, lo, hi)
    elif hi:
        x = lp(x, hi)
    elif lo:
        x = hp(x, lo)
    return x


def place(out, x, at, gain=1.0):
    i = int(at * SR)
    if i >= len(out):
        return out
    m = min(len(x), len(out) - i)
    out[i:i + m] += gain * x[:m]
    return out


def grains(rng, n, rate, sigma=0.8, loop=False):
    """Poisson train of micro impacts with log-normal sizes: stick-slip, grit, pebbles."""
    out = np.zeros(n)
    count = rng.poisson(rate * n / SR)
    idx = rng.integers(0, n, count)
    np.add.at(out, idx, rng.lognormal(0.0, sigma, count) * rng.choice([-1.0, 1.0], count))
    return out


def env_adsr(n, a, d, s_level, r):
    """Attack / decay / sustain / release envelope over n samples (times in seconds)."""
    t = secs(n)
    total = n / SR
    e = np.where(t < a, t / max(a, 1e-6), s_level + (1 - s_level) * np.exp(-(t - a) / max(d, 1e-6)))
    rel_start = total - r
    e = np.where(t > rel_start, e * np.clip((total - t) / max(r, 1e-6), 0, 1), e)
    return e


def room(x, rng, wet=0.14, rt=0.22, size=1.0):
    """Short outdoor room: a few early reflections (walls, ground, a ramp face) and a dark diffuse tail."""
    n = int((rt * 2.2 + 0.05) * SR)
    ir = np.zeros(n)
    ir[0] = 1.0
    for d_ms, g in ((3.1, 0.45), (7.9, 0.3), (13.4, 0.22), (21.0, 0.16), (29.5, 0.11), (41.0, 0.08)):
        i = int(d_ms * size * SR / 1000.0 * rng.uniform(0.9, 1.1))
        if i < n:
            ir[i] += g * rng.choice([-1.0, 1.0])
    tail = lp(rng.standard_normal(n), 3500.0) * np.exp(-secs(n) / (rt / 6.9)) * 0.06
    tail[: int(0.012 * SR)] = 0.0
    ir_wet = ir.copy()
    ir_wet[0] = 0.0
    ir_wet += tail
    y = np.concatenate([x, np.zeros(n)])
    return y + wet * signal.fftconvolve(y, ir_wet)[: len(y)]


def fade_tail(x, seconds=0.01):
    n = min(len(x), int(seconds * SR))
    x[-n:] *= np.linspace(1.0, 0.0, n)
    return x


def trim(x, floor_db=-66.0, pad=0.02):
    """Cuts the silent tail (below floor_db of the peak), keeping a short fade. The buffer's own end is faded over
    its last 120 ms first, so a body still ringing there dies away instead of being cut."""
    x = fade_tail(x.copy(), 0.12)
    peak = np.max(np.abs(x)) + 1e-12
    above = np.nonzero(np.abs(x) > peak * 10 ** (floor_db / 20.0))[0]
    end = min(len(x), (above[-1] if len(above) else len(x)) + int(pad * SR))
    return fade_tail(x[:end].copy(), pad)


def norm_peak(x, db=-3.0):
    return x * (10 ** (db / 20.0) / (np.max(np.abs(x)) + 1e-12))


def norm_loop(x, rms_db=-20.0, peak_db=-2.0):
    rms = np.sqrt(np.mean(x ** 2)) + 1e-12
    y = x * (10 ** (rms_db / 20.0) / rms)
    pk = np.max(np.abs(y))
    lim = 10 ** (peak_db / 20.0)
    if pk > lim:  # soft-knee limit the odd grit spike instead of turning the whole loop down
        y = lim * np.tanh(y / lim)
    return y


def make_loop(x, seconds, xfade=0.25):
    """x must be at least seconds + xfade long; equal-power cross-fade of the overhang into the start."""
    L = int(seconds * SR)
    X = int(xfade * SR)
    y = x[:L].copy()
    w = np.linspace(0.0, np.pi / 2, X)
    y[:X] = x[:X] * np.sin(w) + x[L:L + X] * np.cos(w)
    return y


# --- Bodies (modal data) -------------------------------------------------------------------------------------------
# 7-ply maple deck, free-free bending/torsion modes (Hz, decay s, gain). Lively but short: the grip and the trucks damp it.
DECK = ([96, 214, 352, 498, 690, 940, 1270, 1720, 2350, 3100],
        [0.06, 0.05, 0.04, 0.032, 0.026, 0.02, 0.015, 0.011, 0.008, 0.006],
        [0.55, 0.9, 0.7, 0.6, 0.5, 0.42, 0.32, 0.22, 0.15, 0.1])
# Aluminium truck (hanger, baseplate, kingpin): bright, inharmonic, a little ring.
TRUCK = ([1630, 2475, 3390, 4720, 6150, 8100],
         [0.04, 0.03, 0.022, 0.016, 0.012, 0.008],
         [0.6, 0.8, 0.55, 0.45, 0.3, 0.2])
# Concrete slab: dead, a short low knock.
SLAB = ([48, 83, 131, 210], [0.035, 0.025, 0.018, 0.012], [1.0, 0.7, 0.4, 0.2])
# Plywood ramp sheet over 2x framing: boomy and hollow, the THUG / Skate "ramp thunk".
RAMP = ([58, 81, 117, 152, 199, 263, 341, 455, 610],
        [0.22, 0.18, 0.15, 0.12, 0.1, 0.08, 0.06, 0.045, 0.03],
        [1.0, 0.9, 0.75, 0.6, 0.5, 0.38, 0.28, 0.2, 0.12])
# Steel sheet / grate (metal ramp face, a box top): bright long ring.
PLATE = ([173, 291, 418, 607, 822, 1093, 1452, 1938, 2560, 3390, 4480],
         [0.45, 0.4, 0.36, 0.33, 0.3, 0.26, 0.22, 0.18, 0.14, 0.1, 0.07],
         [0.7, 0.8, 0.75, 0.7, 0.6, 0.55, 0.45, 0.38, 0.3, 0.22, 0.15])
# Steel round rail (Euler-Bernoulli ratios 1 : 2.76 : 5.40 : 8.93 : 13.3) plus a post/support resonance.
def RAIL(base):
    r = [1.0, 2.756, 5.404, 8.933, 13.34, 18.64]
    return ([base * k for k in r] + [base * 0.37],
            [0.9, 0.7, 0.55, 0.4, 0.28, 0.2, 0.3],
            [0.55, 0.8, 0.7, 0.5, 0.35, 0.22, 0.4])
# Wooden coping / bench slat: dull, quick.
WOOD_SLAT = ([142, 318, 560, 905, 1380], [0.05, 0.04, 0.03, 0.02, 0.012], [0.8, 0.9, 0.6, 0.4, 0.25])
# Torso / limbs hitting the ground (soft tissue over bone, padded by clothing).
BODY = ([62, 97, 148, 226], [0.05, 0.04, 0.03, 0.02], [1.0, 0.8, 0.45, 0.25])


def body(rng, spec, seconds, detune=0.03, scale=1.0):
    f, tau, g = spec
    return modal_ir(f, [t * scale for t in tau], g, seconds, rng, detune)


# --- Sounds ---------------------------------------------------------------------------------------------------------


def ollie_pop(rng):
    """Tail snapping the concrete: a hard crack, the deck's bending modes, a slab knock, the trucks clinking as the
    board leaves, then the front foot's griptape scuff (the 'shhk' as it slides up the nose)."""
    out = buf(0.42)
    crack = burst(rng, 0.004, 0.0007, lo=900)
    crack[0] += 2.5
    place(out, conv(np.pad(crack, (0, int(0.25 * SR))), body(rng, DECK, 0.25, 0.04)), 0.0, 0.9)
    place(out, hp(crack, 2500), 0.0, 0.8)  # the raw tail-on-concrete click
    place(out, conv(np.pad(burst(rng, 0.003, 0.001, hi=900), (0, int(0.1 * SR))), body(rng, SLAB, 0.1)), 0.0, 0.45)
    place(out, burst(rng, 0.025, 0.006, 900, 5000), 0.0, 0.5)  # tail scrape grit
    for at, g in ((0.006, 0.35), (0.021, 0.18), (0.038, 0.08)):
        ex = np.zeros(int(0.08 * SR))
        ex[0] = 1.0
        place(out, conv(ex, body(rng, TRUCK, 0.08, 0.05)), at + rng.uniform(-0.002, 0.002), g)
    n = int(0.16 * SR)
    scuff = bp(rng.standard_normal(n), 2200, 9000) * env_adsr(n, 0.04, 0.05, 0.4, 0.07)
    scuff *= 0.5 + 0.5 * lp(np.abs(grains(rng, n, 700, 1.0)), 120) / 0.02
    place(out, scuff / (np.max(np.abs(scuff)) + 1e-9), 0.035 + rng.uniform(0, 0.012), 0.16)
    return norm_peak(trim(room(hp(out, 90), rng, wet=0.12)), -3.0)


IMPACTS = {"soft": 0.35, "med": 0.65, "hard": 1.0}


def land(rng, surface, impact):
    """Four wheels hitting (back truck, then front a few ms later), each hit ringing the deck and the truck and the
    surface: a short slab knock on concrete, the hollow plywood boom on a ramp, a long ring on steel. The shoes stomp
    under it (more body as the impact grows); hard landings add a board flex creak and a second clatter."""
    k = IMPACTS[impact]
    out = buf(1.0 if surface == "metal" else 0.7)
    spread = rng.uniform(0.004, 0.022) * (1.3 - 0.6 * k)
    surf = {"concrete": SLAB, "wood": RAMP, "metal": PLATE}[surface]
    surf_gain = {"concrete": 1.1, "wood": 0.75, "metal": 0.55}[surface]
    for i, at in enumerate((0.0, spread)):
        g = (1.0 if i == 0 else rng.uniform(0.6, 0.9)) * (0.4 + 0.6 * k)
        cutoff = 1200 + 3500 * k  # urethane: softer hits are darker
        ex = np.pad(burst(rng, 0.006, 0.0012 + 0.0015 * (1 - k), hi=cutoff), (0, int(0.6 * SR)))
        ex[0] += 1.5 * k
        place(out, conv(ex, body(rng, DECK, 0.3, 0.04)), at, 0.55 * g)
        place(out, conv(ex, body(rng, TRUCK, 0.12, 0.05)), at + 0.001, (0.25 + 0.35 * k) * g)
        place(out, conv(ex, body(rng, surf, 0.9 if surface == "metal" else 0.5, 0.03, 0.7 + 0.5 * k)), at,
              surf_gain * g)
    # Shoes stomping onto the bolts: a padded low thump, heavier with impact.
    stomp = np.pad(burst(rng, 0.01, 0.004, hi=400), (0, int(0.2 * SR)))
    place(out, conv(stomp, body(rng, BODY, 0.2, 0.05)), spread * 0.5 + 0.006, 0.6 * k * k)
    if surface == "concrete":  # grit crunching under the wheels
        n = int(0.05 * SR)
        place(out, bp(grains(rng, n, 1500, 1.0), 2500, 9000) * np.exp(-secs(n) / 0.012), 0.0, 0.05 * (0.5 + k))
    if k > 0.9:  # board flex creak + a truck rattle bounce
        n = int(0.09 * SR)
        creak = bp(grains(rng, n, 380, 0.5), 300, 1600) * env_adsr(n, 0.02, 0.03, 0.5, 0.03)
        place(out, creak, 0.03, 0.4)
        ex = np.zeros(int(0.1 * SR))
        ex[0] = 1.0
        place(out, conv(ex, body(rng, TRUCK, 0.1, 0.06)), 0.055 + rng.uniform(0, 0.02), 0.2)
    return norm_peak(trim(room(out, rng, wet=0.1 + 0.05 * k)), -3.0)


def scrape_bed(rng, n, kind):
    """Continuous grinding excitation: a stick-slip grain train (truck axle / hanger skipping on the surface) plus a
    filtered noise hiss, slowly breathing as the pressure changes."""
    t = secs(n)
    if kind == "metal":
        g = grains(rng, n, 2600, 0.9)
        g = bp_loop(g, 1400, 9500)
        hiss = bp_loop(rng.standard_normal(n), 4000, 14000)
        exc = g / np.std(g) + 0.45 * hiss / np.std(hiss)
        press = 0.75 + 0.25 * lp_loop(rng.standard_normal(n), 4) / 0.05
        chatter = 0.8 + 0.2 * np.sign(np.sin(2 * np.pi * 37 * t + 3 * np.sin(2 * np.pi * 1.5 * t)))
        return exc * np.clip(press, 0.4, 1.3) * lp_loop(chatter, 300)
    if kind == "concrete":
        g = grains(rng, n, 1100, 1.2)
        exc = bp_loop(g, 300, 5200) + bp_loop(rng.standard_normal(n), 500, 3500) * 0.05
        press = 0.7 + 0.3 * lp_loop(rng.standard_normal(n), 6) / 0.05
        return exc * np.clip(press, 0.3, 1.4)
    g = grains(rng, n, 700, 0.8)
    exc = bp_loop(g, 160, 2600) + bp_loop(rng.standard_normal(n), 200, 1800) * 0.06
    press = 0.75 + 0.25 * lp_loop(rng.standard_normal(n), 5) / 0.05
    return exc * np.clip(press, 0.4, 1.3)


def grind_bodies(rng, kind):
    if kind == "metal":
        return [(RAIL(rng.uniform(395, 430)), 1.2, 0.35), (TRUCK, 0.15, 0.35)]
    if kind == "concrete":
        return [(SLAB, 0.15, 0.6), (TRUCK, 0.1, 0.12)]
    return [(WOOD_SLAT, 0.2, 0.9), (RAMP, 0.4, 0.25)]


def grind_loop(rng, kind, seconds=3.0):
    n = int((seconds + 0.3) * SR)
    exc = scrape_bed(rng, n, kind)
    out = exc * 0.6
    for spec, dur, g in grind_bodies(rng, kind):
        out += g * conv(np.concatenate([exc[-int(dur * SR):], exc]), body(rng, spec, dur, 0.0))[int(dur * SR):] / 6.0
    out = lp(out, 12000)
    return norm_loop(make_loop(out, seconds), -19.0)


def grind_start(rng, kind):
    """Trucks slamming onto the rail / ledge / coping (a ringing clank or a dull knock), with the scrape swelling."""
    out = buf(1.0 if kind == "metal" else 0.6)
    ex = np.pad(burst(rng, 0.004, 0.001, lo=300), (0, int(1.0 * SR)))
    ex[0] += 2.0
    for spec, dur, g in grind_bodies(rng, kind):  # rings shorter than in the loop: the scrape takes over from it
        place(out, conv(ex, body(rng, spec, dur, 0.0, 0.5)), 0.0, g * 1.4)
    place(out, conv(ex[: int(0.3 * SR)], body(rng, DECK, 0.25)), 0.0, 0.5)
    n = int(0.45 * SR)
    sc = scrape_bed(rng, n, kind) * env_adsr(n, 0.04, 0.15, 0.6, 0.25)
    place(out, sc / (np.max(np.abs(sc)) + 1e-9), 0.01, 0.35)
    return norm_peak(trim(room(out, rng, wet=0.12)), -3.0)


def grind_end(rng, kind):
    """The scrape cutting off as the board pops free, a small truck tick, and the rail left ringing."""
    out = buf(1.4 if kind == "metal" else 0.5)
    n = int(0.12 * SR)
    sc = scrape_bed(rng, n, kind) * np.exp(-secs(n) / 0.035)
    place(out, sc / (np.max(np.abs(sc)) + 1e-9), 0.0, 0.5)
    ex = np.zeros(int(1.1 * SR))
    ex[int(0.03 * SR)] = 1.0
    for spec, dur, g in grind_bodies(rng, kind):
        place(out, conv(ex, body(rng, spec, dur, 0.0, 0.6)), 0.0, g * 0.8)
    return norm_peak(trim(room(out, rng, wet=0.12)), -3.0)


def roll_concrete(rng, seconds=4.0):
    """Urethane on pavement: a rough low rumble (the contact patch rolling over aggregate) that rings the deck, pebble
    grit ticks, faint bearing hiss, and two sidewalk seams per loop (front then back wheels, clack-clack)."""
    n = int((seconds + 0.3) * SR)
    t = secs(n)
    rough = lp_loop(rng.standard_normal(n), 260) * (0.7 + 0.3 * lp_loop(rng.standard_normal(n), 25) / 0.03)
    deck = conv(np.concatenate([rough[-int(0.3 * SR):], rough]), body(rng, DECK, 0.3, 0.0))[int(0.3 * SR):]
    grit = bp_loop(grains(rng, n, 900, 0.6), 1200, 7000)
    hiss = bp_loop(rng.standard_normal(n), 3000, 9000)
    out = 1.0 * rough / np.std(rough) + 0.35 * deck / np.std(deck) + 0.22 * grit / np.std(grit) \
        + 0.05 * hiss / np.std(hiss)
    out *= 0.92 + 0.08 * np.sin(2 * np.pi * 0.75 * t)  # slow surface patch change; 3 cycles per 4 s loop
    for at in (0.9, 2.95):
        for dt, g in ((0.0, 1.0), (0.085, 0.8)):
            ex = np.pad(burst(rng, 0.004, 0.0015, hi=2500), (0, int(0.15 * SR)))
            hit = conv(ex, body(rng, DECK, 0.15)) * 0.6 + conv(ex, body(rng, TRUCK, 0.06)) * 0.25 \
                + conv(ex, body(rng, SLAB, 0.06)) * 0.6
            place(out, hit / np.max(np.abs(hit)) * 5.0 * g, at + dt)
    return norm_loop(make_loop(out, seconds), -20.0)


def roll_wood(rng, seconds=4.0):
    """Smooth ramp (skatelite / ply): little grit, a hollow roar from the sheet and the air under it, and soft
    joint thumps where two sheets meet."""
    n = int((seconds + 0.3) * SR)
    smooth = lp_loop(rng.standard_normal(n), 180)
    pre = int(0.5 * SR)
    hollow = conv(np.concatenate([smooth[-pre:], smooth]), body(rng, RAMP, 0.5, 0.0))[pre:]
    deck = conv(np.concatenate([smooth[-pre:], smooth]), body(rng, DECK, 0.3, 0.0))[pre:]
    hiss = bp_loop(rng.standard_normal(n), 1500, 6000)
    out = 0.6 * smooth / np.std(smooth) + 1.0 * hollow / np.std(hollow) + 0.25 * deck / np.std(deck) \
        + 0.06 * hiss / np.std(hiss)
    for at in (0.6, 1.95, 3.3):
        for dt, g in ((0.0, 1.0), (0.085, 0.75)):
            ex = np.pad(burst(rng, 0.004, 0.002, hi=1200), (0, int(0.4 * SR)))
            hit = conv(ex, body(rng, RAMP, 0.4)) + conv(ex, body(rng, DECK, 0.2)) * 0.4
            place(out, hit / np.max(np.abs(hit)) * 1.8 * g, at + dt)
    return norm_loop(make_loop(out, seconds), -20.0)


def skid_loop(rng, seconds=3.0):
    """Powerslide: urethane stick-slip squeal (a jittering fundamental around 1 kHz with its harmonics, gated by the
    stick-slip cycles) over the scrubbed-grit scrape and the deck rumble."""
    n = int((seconds + 0.3) * SR)
    t = secs(n)
    f0 = 960 + 120 * lp_loop(rng.standard_normal(n), 3) / 0.04 + 25 * lp_loop(rng.standard_normal(n), 40) / 0.03
    ph = 2 * np.pi * np.cumsum(f0) / SR
    tone = sum(a * np.sin(h * ph) for h, a in ((1, 1.0), (2, 0.55), (3, 0.3), (4, 0.18), (5, 0.1), (6, 0.06)))
    gate = np.clip(0.5 + lp_loop(rng.standard_normal(n), 18) / 0.05, 0.0, 1.0)
    squeal = tone * gate * (0.6 + 0.4 * np.sin(2 * np.pi * 1.0 * t + 0.4) ** 2)
    scrape = bp_loop(grains(rng, n, 6000, 0.45), 700, 7500)
    rumble = lp_loop(rng.standard_normal(n), 200)
    out = 0.9 * squeal / np.std(squeal) + 0.8 * scrape / np.std(scrape) + 0.45 * rumble / np.std(rumble)
    return norm_loop(make_loop(out, seconds), -18.0)


def body_slap(rng, out, at, gain):
    """Body meeting the ground: a skin-and-cloth slap on top of a padded torso thump."""
    slap = burst(rng, 0.03, 0.006, 700, 6500)
    place(out, slap / np.max(np.abs(slap)), at, 0.55 * gain)
    ex = np.pad(burst(rng, 0.012, 0.004, hi=500), (0, int(0.25 * SR)))
    th = conv(ex, body(rng, BODY, 0.25, 0.06))
    place(out, th / np.max(np.abs(th)), at, 1.0 * gain)


def board_clatter(rng, out, at, gain):
    """The board tumbling away: bounces that come quicker and smaller (a coefficient of restitution ~0.65), each one
    hitting a random edge (deck-heavy or truck-heavy), then a short roll-off."""
    t = at
    dt = rng.uniform(0.11, 0.16)
    g = 1.0
    while g > 0.06 and t < len(out) / SR - 0.1:
        ex = np.pad(burst(rng, 0.004, 0.0012, hi=6000), (0, int(0.25 * SR)))
        ex[0] += 1.0
        mix = rng.uniform(0.2, 1.0)
        hit = conv(ex, body(rng, DECK, 0.25, 0.06)) * (1.2 - mix) + conv(ex, body(rng, TRUCK, 0.1, 0.06)) * mix * 0.6
        place(out, hit / np.max(np.abs(hit)) * g * gain, t)
        t += dt
        dt *= rng.uniform(0.55, 0.75)
        g *= rng.uniform(0.5, 0.7)
    n = int(0.45 * SR)
    roll = lp(rng.standard_normal(n), 300) * np.exp(-secs(n) / 0.15)
    place(out, roll / np.max(np.abs(roll)) * 0.25 * gain, t)


def bail(rng):
    """Slam: body slap, a cloth slide on the pavement, and the board clattering off on its own."""
    out = buf(1.6)
    body_slap(rng, out, 0.0, 1.0)
    n = int(0.5 * SR)
    slide = bp(rng.standard_normal(n), 400, 3200) * env_adsr(n, 0.05, 0.15, 0.4, 0.25)
    slide *= 0.6 + 0.4 * np.abs(lp(grains(rng, n, 200, 0.6), 30)) / 0.05
    place(out, slide / np.max(np.abs(slide)), 0.04, 0.22)
    body_slap(rng, out, rng.uniform(0.16, 0.24), 0.45)  # second contact (arm / hip)
    board_clatter(rng, out, rng.uniform(0.07, 0.14), 0.7)
    return norm_peak(trim(room(out, rng, wet=0.14)), -2.0)


def wallplant(rng):
    """Foot planted on a wall: a sole thud with body behind it, the tail knocking the wall a moment later."""
    out = buf(0.5)
    ex = np.pad(burst(rng, 0.01, 0.003, hi=1800), (0, int(0.25 * SR)))
    th = conv(ex, body(rng, BODY, 0.25, 0.05))
    place(out, th / np.max(np.abs(th)), 0.0, 1.0)
    place(out, burst(rng, 0.02, 0.004, 900, 5000), 0.0, 0.25)
    ex2 = np.pad(burst(rng, 0.003, 0.0008, lo=500), (0, int(0.25 * SR)))
    ex2[0] += 1.5
    knock = conv(ex2, body(rng, DECK, 0.25)) + 0.6 * conv(ex2, body(rng, SLAB, 0.08))
    place(out, knock / np.max(np.abs(knock)), rng.uniform(0.025, 0.045), 0.6)
    return norm_peak(trim(room(out, rng, wet=0.18, size=0.7)), -3.0)


def push(rng):
    """Push foot scuffing the pavement: a heel tap, then the sole dragging (grainy, rising and falling)."""
    out = buf(0.4)
    place(out, burst(rng, 0.012, 0.003, 200, 2500), 0.0, 0.5)
    n = int(rng.uniform(0.14, 0.2) * SR)
    sole = bp(rng.standard_normal(n), 350, 4500) * env_adsr(n, 0.035, 0.06, 0.55, 0.06)
    sole *= 0.5 + 0.5 * np.clip(np.abs(lp(grains(rng, n, 900, 1.0), 60)) / 0.03, 0, 2)
    place(out, sole / np.max(np.abs(sole)), 0.008, 0.9)
    return norm_peak(trim(room(out, rng, wet=0.1)), -3.0)


# --- Bank ----------------------------------------------------------------------------------------------------------
# name -> (renderer, loop seconds or 0 for a one-shot). Round-robin variants are name_1, name_2, name_3 (own seeds).

def bank():
    b = {}
    for v in (1, 2, 3):
        b["pop_%d" % v] = (ollie_pop, 0)
        b["push_%d" % v] = (push, 0)
        b["bail_%d" % v] = (bail, 0)
        b["wallplant_%d" % v] = (wallplant, 0)
        for s in ("concrete", "wood", "metal"):
            for i in IMPACTS:
                b["land_%s_%s_%d" % (s, i, v)] = (lambda r, s=s, i=i: land(r, s, i), 0)
    for k in ("metal", "concrete", "wood"):
        b["grind_%s_start" % k] = (lambda r, k=k: grind_start(r, k), 0)
        b["grind_%s_end" % k] = (lambda r, k=k: grind_end(r, k), 0)
        b["grind_%s_loop" % k] = (lambda r, k=k: grind_loop(r, k), 3.0)
    b["roll_concrete_loop"] = (roll_concrete, 4.0)
    b["roll_wood_loop"] = (roll_wood, 4.0)
    b["skid_loop"] = (skid_loop, 3.0)
    return b


def seed_for(name):
    h = 2166136261
    for c in name.encode():
        h = ((h ^ c) * 16777619) & 0xFFFFFFFF
    return h


def write_wav(path, x, loop):
    pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(pcm)) + pcm
    if loop:
        n = len(x)
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, 0, n - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def main():
    if "--list" in sys.argv:
        print("\n".join(sorted(bank())))
        return 0
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets", "audio", "sfx")
    os.makedirs(out_dir, exist_ok=True)
    total = 0
    for name, (fn, loop) in sorted(bank().items()):
        x = fn(np.random.default_rng(seed_for(name)))
        path = os.path.join(out_dir, name + ".wav")
        write_wav(path, x, loop > 0)
        total += os.path.getsize(path)
    print("rendered %d sounds, %.2f MB -> %s" % (len(bank()), total / 1e6, out_dir))
    return 0


if __name__ == "__main__":
    sys.exit(main())
