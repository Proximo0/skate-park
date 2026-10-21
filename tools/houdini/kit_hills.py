"""Hills (suburban, hilly) kit. Usage: hython tools/houdini/kit_hills.py [--preview]

Writes assets/props/houdini/hills/<piece>.glb and kit.json (collision boxes). Metres, +Y up, front -Z, origin at the
base centre. Flat colour materials for the toon shader. The drained pool's origin is at deck level (the bowl goes
below y = 0); the road segment's origin is the arc centre.
"""
import math

import hlib

MATS = {
    "siding_blue": (0.55, 0.7, 0.85), "siding_yellow": (0.96, 0.86, 0.55), "siding_white": (0.93, 0.92, 0.88),
    "siding_mint": (0.62, 0.85, 0.72), "roof_grey": (0.3, 0.32, 0.36), "roof_red": (0.62, 0.24, 0.2),
    "roof_brown": (0.42, 0.3, 0.24), "trim_white": (0.97, 0.97, 0.95), "door_red": (0.72, 0.16, 0.14),
    "door_navy": (0.16, 0.22, 0.4), "door_green": (0.18, 0.42, 0.3), "glass": (0.45, 0.62, 0.72),
    "shutter": (0.2, 0.3, 0.42), "brick": (0.62, 0.3, 0.24), "concrete": (0.72, 0.71, 0.68),
    "asphalt": (0.22, 0.22, 0.24), "line_yellow": (0.95, 0.78, 0.15), "line_white": (0.95, 0.95, 0.93),
    "pool_plaster": (0.82, 0.9, 0.93), "pool_tile": (0.2, 0.5, 0.75), "coping": (0.8, 0.78, 0.72),
    "picket": (0.97, 0.97, 0.95), "mailbox": (0.2, 0.25, 0.3), "flag_red": (0.88, 0.15, 0.12),
    "leaf": (0.32, 0.62, 0.28), "leaf_dark": (0.18, 0.42, 0.24), "bark": (0.42, 0.3, 0.2),
    "garage_door": (0.9, 0.9, 0.87), "stain": (1.0, 1.0, 1.0),
}


def gable(b, p, w, d, y0, rise, mat, over=0.3):
    """Gable roof over a w x d footprint at height y0, ridge along X, rising `rise`; gable end walls included."""
    half = d / 2
    ang = math.degrees(math.atan2(rise, half))
    slope = math.hypot(rise, half) + over
    for sz, rx in ((-1, -ang), (1, ang)):
        c = (0, y0 + rise / 2 + 0.06, sz * (half / 2 + over * 0.4))
        b.box("%s_roof%d" % (p, sz + 1), (w + 2 * over, 0.12, slope), c, mat, "body", rot=(rx, 0, 0))
    return ang


def gable_ends(b, p, w, d, y0, rise, mat):
    for sx in (-1, 1):
        b.box("%s_gable%d" % (p, sx + 1), (0.1, rise, d), (sx * (w / 2 - 0.05), y0 + rise / 2, 0), mat, "body",
              taper=(1.0, 0.02, 0.0))


def window(b, p, x, y, z, w=1.0, h=1.2, shutters=True):
    b.box(p + "_frame", (w + 0.12, h + 0.12, 0.06), (x, y, z - 0.03), "trim_white", "body")
    b.box(p + "_glass", (w, h, 0.04), (x, y, z - 0.06), "glass", "body")
    b.box(p + "_bar_v", (0.04, h, 0.05), (x, y, z - 0.08), "trim_white", "body")
    b.box(p + "_bar_h", (w, 0.04, 0.05), (x, y, z - 0.08), "trim_white", "body")
    if shutters:
        for sx in (-1, 1):
            b.box("%s_shutter%d" % (p, sx + 1), (0.35, h + 0.1, 0.04), (x + sx * (w / 2 + 0.25), y, z - 0.03), "shutter", "body")


def house(w, d, storeys, rise, siding, roof, door, garage=False, porch=False, chimney=False):
    def fn(b):
        h = 2.9 * storeys
        b.box("walls", (w, h, d), (0, h / 2 + 0.3, 0), siding, "body")
        b.box("foundation", (w + 0.1, 0.3, d + 0.1), (0, 0.15, 0), "concrete", "body")
        gable(b, "main", w, d, h + 0.3, rise, roof)
        gable_ends(b, "main", w, d, h + 0.3, rise, siding)
        z = -d / 2
        b.box("door", (1.0, 2.1, 0.06), (0, 1.35, z - 0.03), door, "body")
        b.box("door_frame", (1.2, 2.25, 0.04), (0, 1.42, z - 0.01), "trim_white", "body")
        b.box("knob", (0.06, 0.06, 0.06), (0.35, 1.3, z - 0.08), "trim_white", "body")
        b.box("step", (1.6, 0.3, 0.6), (0, 0.15, z - 0.3), "concrete", "body")
        for s in range(storeys):
            y = 1.9 + s * 2.9
            for x in (-w / 2 + 1.5, w / 2 - 1.5):
                window(b, "win%d_%d" % (s, int(x > 0)), x, y, z)
            if s > 0:
                window(b, "win%d_mid" % s, 0, y, z, w=0.8, h=1.0, shutters=False)
        for sx in (-1, 1):  # side windows
            b.box("side_glass%d" % (sx + 1), (0.04, 1.1, 1.0), (sx * (w / 2 + 0.02), 1.9, 0.5), "glass", "body")
        boxes = [((0, (h + 0.3 + rise) / 2, 0), (w, h + 0.3 + rise, d))]
        if porch:
            b.box("porch_deck", (w * 0.6, 0.25, 1.8), (0, 0.42, z - 0.9), "concrete", "body")
            for sx in (-1, 1):
                b.box("porch_post%d" % (sx + 1), (0.15, 2.4, 0.15), (sx * w * 0.28, 1.75, z - 1.65), "trim_white", "body")
            b.box("porch_roof", (w * 0.66, 0.12, 2.0), (0, 3.0, z - 0.95), roof, "body", rot=(8, 0, 0))
            boxes.append(((0, 0.27, z - 0.9), (w * 0.6, 0.55, 1.8)))
        if chimney:
            b.box("chimney", (0.7, rise + 1.4, 0.7), (w / 2 - 1.2, h + 0.3 + (rise + 1.4) / 2, d / 4), "brick", "body")
            b.box("chimney_cap", (0.8, 0.1, 0.8), (w / 2 - 1.2, h + 0.3 + rise + 1.45, d / 4), "concrete", "body")
        if garage:
            gx = w / 2 + 2.0
            b.box("garage", (4.0, 2.9, d - 1.0), (gx, 1.75, 0.5), siding, "body")
            b.box("garage_roof", (4.4, 0.15, d - 0.6), (gx, 3.25, 0.5), roof, "body")
            b.box("garage_door", (3.0, 2.3, 0.06), (gx, 1.45, z + 0.47), "garage_door", "body")
            for i in range(4):
                b.box("garage_groove%d" % i, (3.0, 0.03, 0.03), (gx, 0.85 + i * 0.5, z + 0.42), "trim_white", "body")
            boxes.append(((gx, 1.75, 0.5), (4.0, 3.5, d - 1.0)))
        return boxes
    return fn


def picket_fence(b):
    # 3 m section: 13 pointed pickets on two rails between posts, faces -Z.
    for sx in (-1, 1):
        b.box("post%d" % (sx + 1), (0.1, 1.1, 0.1), (sx * 1.5, 0.55, 0), "picket", "body")
        b.box("post_cap%d" % (sx + 1), (0.14, 0.05, 0.14), (sx * 1.5, 1.12, 0), "picket", "body")
    for y in (0.3, 0.75):
        b.box("rail%d" % int(y * 100), (3.0, 0.07, 0.04), (0, y, 0.05), "picket", "body")
    for i in range(13):
        x = -1.32 + i * 0.22
        b.box("picket%d" % i, (0.09, 0.85, 0.025), (x, 0.47, 0.0), "picket", "body")
        b.box("tip%d" % i, (0.09, 0.12, 0.025), (x, 0.95, 0.0), "picket", "body", taper=(0.05, 1.0, 0.0))
    return [((0, 0.55, 0.02), (3.1, 1.1, 0.12))]


def mailbox(b):
    b.box("post", (0.1, 1.05, 0.1), (0, 0.52, 0), "trim_white", "body")
    b.box("arm", (0.12, 0.06, 0.5), (0, 1.0, -0.1), "trim_white", "body")
    b.box("box", (0.24, 0.2, 0.5), (0, 1.13, -0.12), "mailbox", "body")
    b.cyl("box_top", 0.12, 0.5, (0, 1.23, -0.12), "mailbox", "body", orient="z", cols=10, rows=1)
    b.box("flag", (0.02, 0.18, 0.06), (0.135, 1.28, 0.0), "flag_red", "body")
    b.box("door", (0.25, 0.3, 0.02), (0, 1.17, -0.375), "mailbox", "body")
    return [((0, 0.65, -0.05), (0.3, 1.35, 0.6))]


# Python SOP: a drained kidney pool. Outline points run counter-clockwise from above (x = cos t, z = sin t); faces
# point to the right of each profile's travel: down-and-in for the bowl (inward and up), up for the deck.
POOL = """
import math
geo = hou.pwd().geometry()
geo.addAttrib(hou.attribType.Prim, "shop_materialpath", "")
N = 40
A, B, K = 4.0, 2.5, 1.1
SQ = (6.0, 4.5)
def outline(t):
    x = A * math.cos(t) * (1 + 0.12 * math.cos(t))
    z = B * math.sin(t)
    if math.sin(t) < 0:
        z += K * math.sin(t) ** 2
    return hou.Vector3(x, 0, z)
ts = [2 * math.pi * i / N for i in range(N)]
O = [outline(t) for t in ts]
cen = sum(O, hou.Vector3()) * (1.0 / N)
def norm_out(i):
    a, c = O[(i - 1) % N], O[(i + 1) % N]
    tan = (c - a).normalized()
    n = hou.Vector3(tan[2], 0, -tan[0])
    return n if n.dot(O[i] - cen) > 0 else -n
NO = [norm_out(i) for i in range(N)]
def ring(fn):
    pts = []
    for i in range(N):
        p = geo.createPoint()
        p.setPosition(fn(i))
        pts.append(p)
    return pts
def bridge(a, b, mat, flip=False):
    for i in range(N):
        j = (i + 1) % N
        quad = (a[i], a[j], b[j], b[i]) if not flip else (a[i], b[i], b[j], a[j])
        poly = geo.createPolygon()
        for p in quad:
            poly.addVertex(p)
        poly.setAttribValue("shop_materialpath", "/mat/" + mat)
def depth(i):
    return 1.2 + 1.2 * (O[i][0] / A * 0.5 + 0.5)  # shallow end at -X, deep end at +X
# Bowl: from the coping lip down a near-vertical tile band, round a transition, flat across the bottom.
prof = [(0.0, 0.0, "pool_tile"), (0.02, -0.28, "pool_plaster")]
for k in range(1, 7):
    ph = math.pi / 2 * k / 6
    prof.append((0.05 + 0.9 * (1 - math.cos(ph)), None, "pool_plaster", math.sin(ph)))
rings = []
for k, entry in enumerate(prof):
    inset = entry[0]
    if entry[1] is not None:
        rings.append((ring(lambda i, inset=inset, y=entry[1]: O[i] - NO[i] * inset + hou.Vector3(0, y, 0)), entry[2]))
    else:
        s = entry[3]
        rings.append((ring(lambda i, inset=inset, s=s: O[i] - NO[i] * inset + hou.Vector3(0, -0.28 - (depth(i) - 0.28) * s, 0)), entry[2]))
for (a, ma), (b, mb) in zip(rings, rings[1:]):
    bridge(a, b, ma)
last = rings[-1][0]
centre = geo.createPoint()
centre.setPosition(cen + hou.Vector3(0, -sum(depth(i) for i in range(N)) / N, 0))
for i in range(N):
    poly = geo.createPolygon()
    for p in (last[i], last[(i + 1) % N], centre):
        poly.addVertex(p)
    poly.setAttribValue("shop_materialpath", "/mat/pool_plaster")
# Coping: a rounded lip just outside the outline (outer foot first, over the top, down into the pool).
cop = [(0.32, 0.0), (0.32, 0.06), (0.18, 0.085), (0.04, 0.07), (0.0, 0.03), (0.0, 0.0)]
crings = [ring(lambda i, o=o, y=y: O[i] + NO[i] * o + hou.Vector3(0, y, 0)) for o, y in cop]
for a, b in zip(crings, crings[1:]):
    bridge(a, b, "coping")
# Deck: from the coping's outer foot out to a SQ rectangle, matched by angle.
def edge(i):
    d = O[i] - cen
    d = hou.Vector3(d[0], 0, d[2]).normalized()
    s = min(SQ[0] / max(abs(d[0]), 1e-6), SQ[1] / max(abs(d[2]), 1e-6))
    return cen + d * s
outer = ring(edge)
bridge(crings[0], outer, "concrete", flip=True)
"""


def kidney_pool(b):
    hlib.python_part(b, "pool", POOL, "concrete", "body")
    b.parts[-1].parm("snippet").set('s@path = "body";')  # keep the per-face materials from the SOP
    return "mesh"


def driveway(b):
    # 3.5 x 8 m concrete slab (0.1 m), expansion joints, oil stains in vertex colour, toward -Z from the garage.
    slab = b.net.createNode("box", "slab")
    for k, v in (("type", "polymesh"), ("sizex", 3.5), ("sizey", 0.1), ("sizez", 8.0), ("ty", 0.05),
                 ("divrate1", 8), ("divrate2", 2), ("divrate3", 17)):
        slab.parm(k).set(v)
    w = b.wrangle(slab, "float n = noise(@P * 1.5 + 4); @Cd = set(1, 1, 1) * fit(n, 0.3, 0.7, 0.78, 1.0);"
                        " if (length(set(@P.x, @P.z + 1.5)) < 0.5) @Cd *= 0.8;", name="stains")
    b.tag(w, "stain", "body")
    for i in range(1, 4):
        b.box("joint%d" % i, (3.5, 0.012, 0.025), (0, 0.101, -4.0 + i * 2.0), "asphalt", "body")
    return [((0, 0.05, 0), (3.5, 0.1, 8.0))]


ROAD = """
import math
geo = hou.pwd().geometry()
geo.addAttrib(hou.attribType.Prim, "shop_materialpath", "")
R0, R1, N = 10.0, 17.0, 24
def strip(r_in, r_out, y, mat, dash=False):
    for k in range(N):
        if dash and k % 2:
            continue
        a0, a1 = math.pi / 2 * k / N, math.pi / 2 * (k + 1) / N
        pts = []
        for r, a in ((r_in, a0), (r_out, a0), (r_out, a1), (r_in, a1)):
            p = geo.createPoint()
            p.setPosition((r * math.cos(a), y, r * math.sin(a)))
            pts.append(p)
        poly = geo.createPolygon()
        for p in pts:  # face up
            poly.addVertex(p)
        poly.setAttribValue("shop_materialpath", "/mat/" + mat)
strip(R0, R1, 0.0, "asphalt")
strip(13.42, 13.58, 0.005, "line_yellow", dash=True)
strip(R0 + 0.25, R0 + 0.37, 0.005, "line_white")
strip(R1 - 0.37, R1 - 0.25, 0.005, "line_white")
for r_in, r_out in ((R0 - 0.3, R0), (R1, R1 + 0.3)):
    strip(r_in, r_out, 0.15, "concrete")
    for r, sgn in ((r_in, -1), (r_out, 1)):  # curb faces (outward from the curb)
        for k in range(N):
            a0, a1 = math.pi / 2 * k / N, math.pi / 2 * (k + 1) / N
            pts = []
            for a, y in ((a0, 0.0), (a1, 0.0), (a1, 0.15), (a0, 0.15)):
                p = geo.createPoint()
                p.setPosition((r * math.cos(a), y, r * math.sin(a)))
                pts.append(p)
            poly = geo.createPolygon()
            for p in (pts if sgn > 0 else list(reversed(pts))):
                poly.addVertex(p)
            poly.setAttribValue("shop_materialpath", "/mat/concrete")
"""


def road_curve(b):
    # A 90-degree two-lane bend: inner radius 10 m, 7 m of asphalt, dashed yellow centre line, white edge lines,
    # 0.15 m curbs. Origin at the arc centre; the bend runs from +X round to +Z.
    hlib.python_part(b, "road", ROAD, "asphalt", "body")
    b.parts[-1].parm("snippet").set('s@path = "body";')
    return "mesh"


def tree_round(b):
    b.cyl("trunk", 0.12, 2.6, (0, 1.3, 0), "bark", "body", orient="y", cols=8, rows=1, rad2=0.18)  # rad is the top
    for i, (dx, dy, dz, r) in enumerate(((0, 3.6, 0, 1.6), (0.9, 3.1, 0.4, 1.1), (-0.9, 3.2, -0.3, 1.15),
                                          (0.2, 4.5, -0.2, 1.1), (-0.3, 3.0, 0.9, 1.0))):
        hlib.sphere(b, "canopy%d" % i, (r, r * 0.85, r), (dx, dy, dz), "leaf", "body", rows=6, cols=9,
                    snippet="vector n = noise(@P * 1.4 + %d); @P += (n - 0.5) * 0.35;" % (i * 3))
    return [((0, 1.3, 0), (0.4, 2.6, 0.4)), ((0, 3.7, 0), (3.6, 2.4, 3.6))]


def tree_pine(b):
    b.cyl("trunk", 0.15, 1.6, (0, 0.8, 0), "bark", "body", orient="y", cols=8, rows=1)
    for i in range(4):
        r = 1.7 - i * 0.38
        b.cyl("tier%d" % i, 0.05, 1.7, (0, 1.6 + i * 1.05, 0), "leaf_dark", "body", orient="y", cols=10, rows=1, rad2=r)
    return [((0, 0.8, 0), (0.3, 1.6, 0.3)), ((0, 3.4, 0), (3.4, 4.2, 3.4))]


def garage(b):
    # Detached 6 x 6.5 m garage, gable roof, roll-up door toward -Z, side door and window.
    w, d, h = 6.0, 6.5, 3.0
    b.box("walls", (w, h, d), (0, h / 2 + 0.15, 0), "siding_white", "body")
    b.box("slab", (w + 0.2, 0.15, d + 0.2), (0, 0.075, 0), "concrete", "body")
    gable(b, "g", w, d, h + 0.15, 1.6, "roof_grey")
    gable_ends(b, "g", w, d, h + 0.15, 1.6, "siding_white")
    b.box("door", (4.8, 2.4, 0.06), (0, 1.35, -d / 2 - 0.03), "garage_door", "body")
    for i in range(5):
        b.box("groove%d" % i, (4.8, 0.03, 0.03), (0, 0.6 + i * 0.48, -d / 2 - 0.07), "trim_white", "body")
    b.box("door_trim", (5.0, 2.55, 0.03), (0, 1.42, -d / 2 - 0.015), "trim_white", "body")
    b.box("side_door", (0.06, 2.1, 0.9), (w / 2 + 0.03, 1.2, 1.5), "door_green", "body")
    b.box("side_window", (0.04, 0.8, 1.0), (w / 2 + 0.02, 1.8, -1.0), "glass", "body")
    b.box("light", (0.15, 0.25, 0.1), (2.7, 2.9, -d / 2 - 0.08), "trim_white", "body")
    return [((0, (h + 1.75) / 2, 0), (w, h + 1.75, d))]


PIECES = [
    ("house_ranch", house(10.0, 7.0, 1, 1.8, "siding_blue", "roof_grey", "door_red", garage=True, porch=True)),
    ("house_two_storey", house(8.0, 7.0, 2, 2.2, "siding_yellow", "roof_red", "door_navy", porch=True)),
    ("house_colonial", house(9.0, 8.0, 2, 2.4, "siding_white", "roof_grey", "door_green", chimney=True)),
    ("house_cottage", house(7.0, 6.0, 1, 3.0, "siding_mint", "roof_brown", "door_red", chimney=True)),
    ("picket_fence", picket_fence), ("mailbox", mailbox), ("drained_kidney_pool", kidney_pool),
    ("driveway", driveway), ("road_curve", road_curve), ("tree_round", tree_round), ("tree_pine", tree_pine),
    ("garage", garage),
]

if __name__ == "__main__":
    import os
    import sys
    hlib.run_kit("hills", PIECES, MATS)
    sys.stdout.flush()
    os._exit(0)
