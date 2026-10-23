"""Rasterise the Body skin surfaces (0-3) of avatarsample_g into UV space.
Outputs posmap.npy (H,W,3 float32 rest positions, NaN where empty) and surfmap.npy (H,W int8)."""
import json, sys, numpy as np
D = sys.argv[1] if len(sys.argv) > 1 else "/tmp/lead/vrm_tex/dump"
OUT = sys.argv[2] if len(sys.argv) > 2 else "/tmp/lead/vrm_tex/work"
N = 2048
pos = np.full((N, N, 3), np.nan, np.float32)
sid = np.full((N, N), -1, np.int8)
for s in range(4):
    j = json.load(open(f"{D}/Body_{s}.json"))
    P = np.array(j["pos"], np.float32).reshape(-1, 3)
    U = np.array(j["uv"], np.float32).reshape(-1, 2)
    I = np.array(j["idx"]).reshape(-1, 3)
    print("surf", s, "tris", len(I), "pos bounds", P.min(0), P.max(0))
    for a, b, c in I:
        uv = U[[a, b, c]] * N
        x0, y0 = np.floor(uv.min(0)).astype(int); x1, y1 = np.ceil(uv.max(0)).astype(int)
        x0 = max(x0, 0); y0 = max(y0, 0); x1 = min(x1, N - 1); y1 = min(y1, N - 1)
        if x1 < x0 or y1 < y0: continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        px = xs + 0.5; py = ys + 0.5
        (ax, ay), (bx, by), (cx, cy) = uv
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9: continue
        w0 = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / den
        w1 = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / den
        w2 = 1 - w0 - w1
        e = -0.02  # slight conservative margin
        m = (w0 >= e) & (w1 >= e) & (w2 >= e)
        if not m.any(): continue
        p = w0[m, None] * P[a] + w1[m, None] * P[b] + w2[m, None] * P[c]
        pos[ys[m], xs[m]] = p
        sid[ys[m], xs[m]] = s
np.save(f"{OUT}/posmap.npy", pos); np.save(f"{OUT}/surfmap.npy", sid)
v = ~np.isnan(pos[..., 0])
print("covered", v.sum(), v.mean())
