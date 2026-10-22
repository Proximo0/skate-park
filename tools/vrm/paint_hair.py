"""Luminance-preserving recolour of avatarsample_g hair textures to golden blonde (+ single teal ribbon).
Writes hair_main / hair_main2 / hair_back / ribbon (.png + _shade.png [+ _emission.png]) and hair_gold_params.json."""
import sys, json, numpy as np
from PIL import Image
DUMP = sys.argv[1] if len(sys.argv) > 1 else "/tmp/lead/vrm_tex/dump"
OUT = sys.argv[2] if len(sys.argv) > 2 else "/home/claude/skate/assets/characters/vrm/textures"
def hx(h): h = h.lstrip("#"); return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)
SHADOW, MID, HI = hx("B8862E"), hx("E8C26A"), hx("FFF0B8")
TEAL = hx("2FB3B0")
def load(n): return np.array(Image.open(f"{DUMP}/{n}.png").convert("RGBA")).astype(np.float32)
def lum(a): return (0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]) / 255
def ramp(t):
    t = np.clip(t, 0, 1)[..., None]
    lo = SHADOW + (MID - SHADOW) * np.clip(t / 0.6, 0, 1)
    return np.where(t < 0.6, lo, MID + (HI - MID) * np.clip((t - 0.6) / 0.4, 0, 1))
def save(rgb, alpha, name):
    Image.fromarray(np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8), "RGBA").save(f"{OUT}/{name}")
def gold(key, src, lo, hi, shade_mul):
    a = load(src); L = lum(a)
    t = (L - lo) / (hi - lo)
    c = ramp(t * 0.80 + 0.18)
    save(c, a[..., 3], f"{key}.png")
    save(c * np.array(shade_mul, np.float32), a[..., 3], f"{key}_shade.png")
    return a
a = gold("hair_main", "Hair001_0__MainTex", 0.80, 1.0, (0.80, 0.70, 0.55))
a = gold("hair_main2", "Hair001_15__MainTex", 0.80, 1.0, (0.82, 0.72, 0.56))
# back hair has dark/grey strand shading: keep its range
b = load("Body_6__MainTex"); Lb = lum(b)
print("hairback L", np.percentile(Lb[b[..., 3] > 10], [1, 50, 99]))
lo, hi = np.percentile(Lb[b[..., 3] > 10], [1, 99])
c = ramp(((Lb - lo) / (hi - lo)) * 0.80 + 0.18)
save(c, b[..., 3], "hair_back.png"); save(c * np.array((0.80, 0.70, 0.55), np.float32), b[..., 3], "hair_back_shade.png")
# ribbon: one teal accent, keep the slight shading
r = load("Hair001_53__MainTex"); Lr = lum(r)
tr = np.clip((Lr - 0.82) / 0.18, 0, 1)[..., None]
cr = TEAL * (0.80 + 0.20 * tr)
save(cr, r[..., 3], "ribbon.png"); save(cr * np.array((0.65, 0.8, 0.85), np.float32), r[..., 3], "ribbon_shade.png")
# emission (anime highlight bands): warm-tint
for key, src, tint in (("hair_main", "Hair001_0__EmissionMap", (1.0, 0.86, 0.55)), ("hair_main2", "Hair001_15__EmissionMap", (1.0, 0.86, 0.55)), ("ribbon", "Hair001_53__EmissionMap", (0.6, 0.95, 0.95))):
    e = load(src); L = lum(e)[..., None]
    save(L * 255 * np.array(tint, np.float32), np.full(L.shape[:2], 255, np.float32), f"{key}_emission.png")
params = {k: {"_Color": [1, 1, 1, 1], "_ShadeColor": [1, 1, 1, 1]} for k in ("hair_main", "hair_main2", "hair_back", "ribbon")}
for k in ("hair_main", "hair_main2", "ribbon"): params[k]["_EmissionColor"] = [1, 1, 1, 1]
json.dump(params, open(f"{OUT}/hair_gold_params.json", "w"), indent=1)
