"""Repaint avatarsample_g body skin texture: clean skin + surf bikini (coral / blue).
Inputs: dump/Body_0__MainTex.png (original), work/posmap.npy, work/surfmap.npy (see bake_posmap.py).
Outputs: <out>/body_skin_bikini_coral.png, body_skin_bikini_blue.png (2048x2048, same as original)."""
import sys, numpy as np
from PIL import Image
from scipy import ndimage as ndi
DUMP = sys.argv[1] if len(sys.argv) > 1 else "/tmp/lead/vrm_tex/dump"
WORK = sys.argv[2] if len(sys.argv) > 2 else "/tmp/lead/vrm_tex/work"
OUT = sys.argv[3] if len(sys.argv) > 3 else "/home/claude/skate/assets/characters/vrm/textures"
pos = np.load(f"{WORK}/posmap.npy"); sid = np.load(f"{WORK}/surfmap.npy")
src = np.array(Image.open(f"{DUMP}/Body_0__MainTex.png").convert("RGBA")).astype(np.float32)
N = 2048
valid = sid >= 0
X = np.nan_to_num(pos[..., 0]); Y = np.nan_to_num(pos[..., 1], nan=-9); Z = np.nan_to_num(pos[..., 2])
AX = np.abs(X)
rgb = src[..., :3]
R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
sat = (rgb.max(-1) - rgb.min(-1)) / np.maximum(rgb.max(-1), 1)

# ---------- 1. clean skin: find non-skin texels (stockings, underwear, socks) and inpaint ----------
bad = valid & ((B > R - 10) | (sat < 0.06))
bad |= valid & (sid == 1)                      # feet (socks) - shoes cover them
bad |= valid & (Y < 0.70) & (sid == 0)          # stocking zone on legs
bad |= valid & (Y > 0.76) & (Y < 1.04) & (sid == 0)   # underwear zone
bad |= valid & (Y > 0.69) & (Y < 0.76) & ((B > R - 25))
bad = ndi.binary_dilation(bad, iterations=5) & valid
good = valid & ~bad
# do not use hands / head / neck (surf 2,3) colours as donors for the legs
donor = good & (sid == 0)
fill = np.zeros_like(rgb); done = np.zeros((N, N), bool)
for sg in (6, 20, 60, 160, 400):
    w = ndi.gaussian_filter(donor.astype(np.float32), sg)
    c = np.stack([ndi.gaussian_filter(rgb[..., k] * donor, sg) for k in range(3)], -1) / np.maximum(w[..., None], 1e-6)
    take = (~done) & (w > 0.2)
    fill[take] = c[take]; done |= take
skin = rgb.copy()
skin[bad] = fill[bad]
# legs / hips: one clean uniform tone (matches the original thigh/hip colour), blended into the original torso skin
tone_c = np.array([255, 228, 209], np.float32)
wl = np.clip((1.10 - Y) / 0.055, 0, 1) * (sid == 0) * (Y < 1.10)
skin = skin * (1 - wl[..., None]) + tone_c[None, None, :] * wl[..., None]
feet = valid & (sid == 1)
skin[feet] = tone_c
thigh_tone = tone_c

# ---------- 2. bikini signed-distance masks (metres, negative = inside) ----------
EPS = 0.0007
def alpha(sd): return np.clip(0.5 - sd / EPS, 0, 1)
def seg_sd2(px, py, a, b):
    ax_, ay_ = a; bx_, by_ = b
    dx, dy = bx_ - ax_, by_ - ay_
    t = np.clip(((px - ax_) * dx + (py - ay_) * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(px - (ax_ + t * dx), py - (ay_ + t * dy))
def tri_sd(px, py, P):
    # P list of 3 vertices CCW or CW; signed distance via half-planes (approximate, exact inside)
    cx = sum(p[0] for p in P) / 3; cy = sum(p[1] for p in P) / 3
    d = None
    for i in range(3):
        a = P[i]; b = P[(i + 1) % 3]
        nx, ny = (b[1] - a[1]), -(b[0] - a[0]); L = np.hypot(nx, ny); nx /= L; ny /= L
        if (cx - a[0]) * nx + (cy - a[1]) * ny > 0: nx, ny = -nx, -ny
        di = (px - a[0]) * nx + (py - a[1]) * ny
        d = di if d is None else np.maximum(d, di)
    return d

# --- top (triangle cups, straps, back band, neck halter, ties) ---
CUP = [(0.006, 1.210), (0.146, 1.240), (0.040, 1.372)]
cup_tri = tri_sd(AX, Y, CUP)
cup_sd = np.maximum(cup_tri, -Z - 0.045)
# straps: thin (9 mm) strings from the cup apex over the shoulder to a small knot at the back of the neck base.
# Waypoints are snapped onto the real surface so the string hugs the skin.
from scipy.spatial import cKDTree
vy, vx = np.nonzero(valid & (Y > 1.30) & (Y < 1.50))
vpts = pos[vy[::2], vx[::2]]
tree = cKDTree(vpts)
WAY = [(0.040, 1.372, 0.09), (0.052, 1.390, 0.07), (0.062, 1.405, 0.04), (0.066, 1.414, 0.0),
       (0.052, 1.418, -0.035), (0.028, 1.416, -0.052), (0.0, 1.413, -0.057)]
def snap(p): return vpts[tree.query(p)[1]]
side_pts = [snap(p) for p in WAY]
sub = valid & (Y > 1.34) & (Y < 1.46)
STRAP_HW = 0.0045
strap_d = np.full((N, N), 1.0, np.float32)
for sgn in (-1, 1):
    pts = [np.array([sgn * q[0], q[1], q[2]]) for q in side_pts]
    pts[-1][0] = 0.0
    for p0, p1 in zip(pts[:-1], pts[1:]):
        d = p1 - p0; L2 = float(d @ d)
        P = pos[sub]
        t = np.clip(((P - p0) @ d) / L2, 0, 1)
        dist = np.linalg.norm(P - (p0 + t[:, None] * d), axis=1) - STRAP_HW
        cur = strap_d[sub]; strap_d[sub] = np.minimum(cur, dist)
knot = snap((0.0, 1.413, -0.057))
kd = np.linalg.norm(pos - knot[None, None, :], axis=-1) - 0.0075
strap_sd = np.where(valid, np.minimum(strap_d, np.nan_to_num(kd, nan=1.0)), 1.0)
band_sd = np.where((Z < 0.0) | (AX > 0.125), np.abs(Y - 1.236) - 0.0055, 1.0)
# back knot + tails (nape)
def tails(cx, cy, zmax, length, spread, hw, dirs=(-1, 1)):
    sd = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2) - 0.0085
    for s in dirs:
        yy_ = np.clip((cy - Y) / length, 0, 1)
        xc = cx + s * (0.004 + spread * yy_ ** 1.2)
        d = np.maximum(np.abs(X - xc) - hw * (1 - 0.35 * yy_), np.maximum(Y - cy, (cy - length) - Y))
        sd = np.minimum(sd, d)
    return np.where(Z < zmax, sd, 1.0)
band_knot_sd = tails(0.0, 1.236, -0.015, 0.10, 0.04, 0.0045)
string_top_sd = np.minimum.reduce([strap_sd, band_sd, band_knot_sd])

# --- bottom (low-rise triangles + side ties) ---
yT = 0.995 + 0.15 * AX
xw = np.clip(0.032 + 0.64 * (Y - 0.872), 0.0, 0.122)
yb = 0.872
pan_sd = np.maximum.reduce([(Y - yT) * 0.99, (AX - xw) * 0.85, yb - Y])
# restrict to the pelvis area (avoid painting the other leg etc.)
pan_sd = np.where((Y < 1.05) & (Y > 0.8), pan_sd, 1.0)
# side string at the hips (waist string) and bow
side_sd = np.where(AX > 0.105, np.abs(Y - 1.011) - 0.0055, 1.0)
side_sd = np.where((Y > 0.99) & (Y < 1.03), side_sd, 1.0)
def bow(sign):
    xs = sign * 0.14
    d = 1.0 * np.ones_like(X)
    on_side = (np.sign(X) == sign) & (AX > 0.1)
    for s in (-1, 1):
        # loops
        zc = s * 0.022
        el = np.sqrt(((Z - zc) / 0.013) ** 2 + ((Y - 1.018) / 0.0085) ** 2) * 0.0085
        # tails
        yy_ = np.clip((1.011 - Y) / 0.085, 0, 1)
        zt = s * (0.005 + 0.03 * yy_ ** 1.3)
        tl = np.maximum(np.abs(Z - zt) - 0.0042 * (1 - 0.3 * yy_), np.maximum(Y - 1.014, 0.926 - Y))
        d = np.minimum(d, np.minimum(el - 0.0085, tl))
    knot = np.sqrt((Z / 1.0) ** 2 + (Y - 1.012) ** 2) - 0.007
    d = np.minimum(d, knot)
    return np.where(on_side, d, 1.0)
bow_sd = np.minimum(bow(-1), bow(1))
string_bot_sd = np.minimum(side_sd, bow_sd)

fab_cover = np.minimum.reduce([cup_sd, pan_sd])
cloth_sd = np.minimum(fab_cover, np.minimum(string_top_sd, string_bot_sd))
cloth_sd = np.where(valid, cloth_sd, 1.0)

# trim (white piping) near edges of cups / panel: distance inside edge
trim_w = 0.0055
in_fab = np.minimum(cup_sd, pan_sd)
in_fab = np.where((cup_sd < 0) | (pan_sd < 0), in_fab, 1.0)
edge_in = -in_fab   # >0 inside, distance to edge

# ---------- 3. compose per colourway ----------
rng = np.random.default_rng(3)
noise = ndi.gaussian_filter(rng.standard_normal((N, N)).astype(np.float32), 1.0)
ii, jj = np.meshgrid(np.arange(N), np.arange(N))
weave = (np.sin(ii * 0.9) * np.sin(jj * 0.9)) * 0.018 + noise * 0.03
def compose(col, name):
    col = np.array(col, np.float32)
    out = skin.copy()
    a_cloth = alpha(cloth_sd)
    # soft contact shadow on skin around the cloth
    near = ndi.gaussian_filter(a_cloth, 2.2)
    out = out * (1 - 0.07 * np.clip(near * 1.6 - a_cloth, 0, 1)[..., None])
    # fabric colour with shading
    bust_r = np.hypot(AX - 0.062, Y - 1.2745)
    shade = np.ones((N, N), np.float32)
    shade = np.where(cup_sd < 0, 1.06 - 0.20 * np.clip(bust_r / 0.075, 0, 1) ** 1.5, shade)
    shade = np.where(pan_sd < 0, 1.03 - 0.16 * np.clip((1.0 - Y) / 0.13 + 0.0, 0, 1) - 0.05 * np.clip(AX / 0.12, 0, 1), shade)
    shade = np.where(cloth_sd < 0, shade, 1.0)
    fab = col[None, None, :] * (shade + weave)[..., None]
    # seam line (darker piping stitch) and white trim
    seam = alpha(np.abs(edge_in - 0.0105) - 0.0007) * (in_fab < 0)
    fab = fab * (1 - 0.18 * seam[..., None])
    trim = np.clip(alpha(in_fab) * (edge_in < trim_w), 0, 1)
    white = np.array([248, 246, 242], np.float32)[None, None, :] * (1.0 + weave[..., None] * 0.5)
    # trim only on cups and panels (not strings); strings keep fabric colour with slight highlight
    fab = fab * (1 - trim[..., None]) + white * trim[..., None]
    # tie strings: slightly lighter centre line for a twisted-cord look
    out = out * (1 - a_cloth[..., None]) + fab * a_cloth[..., None]
    out = np.clip(out, 0, 255)
    # dilate painted/valid area to avoid UV seam gaps
    idx = ndi.distance_transform_edt(~valid, return_distances=False, return_indices=True)
    grown = out[idx[0], idx[1]]
    ring = ndi.binary_dilation(valid, iterations=8) & ~valid
    final = src[..., :3].copy()
    final[valid] = out[valid]
    final[ring] = grown[ring]
    # remaining padding: keep original (already skin-coloured bleed) but remove white remnants
    rest = ~(valid | ring)
    pad_bad = rest & ((B > R - 10) | (sat < 0.06))
    final[pad_bad] = thigh_tone
    res = np.dstack([final, src[..., 3]]).astype(np.uint8)
    Image.fromarray(res, "RGBA").save(f"{OUT}/{name}")
    print("wrote", name)
import os
os.makedirs(OUT, exist_ok=True)
compose((255, 111, 97), "body_skin_bikini_coral.png")
compose((46, 134, 222), "body_skin_bikini_blue.png")
Image.fromarray(np.dstack([skin, src[..., 3]]).astype(np.uint8), "RGBA").save(f"{WORK}/skin_only.png")
