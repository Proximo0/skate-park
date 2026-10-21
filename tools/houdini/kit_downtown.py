"""Downtown kit. Usage: hython tools/houdini/kit_downtown.py [--preview]

Writes assets/props/houdini/downtown/<piece>.glb and kit.json (collision boxes). Metres, +Y up, front -Z, origin at
the base centre. Flat colour materials for the toon shader. The facade modules stack: base (5 m), middle (3.5 m
floors), top (2 m parapet), all 10 m wide and 0.5 m deep.
"""
import hlib

MATS = {
    "pole_green": (0.16, 0.3, 0.24), "pole_grey": (0.36, 0.38, 0.4), "lamp_glow": (1.0, 0.92, 0.7),
    "signal_body": (0.12, 0.12, 0.13), "sig_red": (0.9, 0.12, 0.1), "sig_amber": (0.98, 0.65, 0.1),
    "sig_green": (0.15, 0.85, 0.4), "glass": (0.45, 0.62, 0.7), "ad_panel": (0.98, 0.85, 0.55),
    "bench_wood": (0.62, 0.42, 0.26), "stone": (0.72, 0.7, 0.66), "granite": (0.45, 0.45, 0.47),
    "water": (0.35, 0.7, 0.85), "kiosk_green": (0.15, 0.45, 0.32), "awning_red": (0.78, 0.18, 0.16),
    "awning_white": (0.95, 0.94, 0.9), "mag_a": (0.95, 0.3, 0.35), "mag_b": (0.25, 0.55, 0.95),
    "mag_c": (0.98, 0.8, 0.25), "hydrant_red": (0.82, 0.12, 0.1), "facade": (0.78, 0.7, 0.58),
    "facade_trim": (0.9, 0.87, 0.8), "window_frame": (0.2, 0.22, 0.25), "metal": (0.6, 0.62, 0.65),
    "soil": (0.3, 0.22, 0.15), "leaf": (0.3, 0.6, 0.28), "bark": (0.42, 0.3, 0.2), "door_dark": (0.18, 0.2, 0.22),
}


def streetlight(b):
    b.cyl("base", 0.18, 0.5, (0, 0.25, 0), "pole_green", "body", orient="y", cols=10, rows=1)
    b.cyl("pole", 0.08, 6.0, (0, 3.2, 0), "pole_green", "body", orient="y", cols=8, rows=1, rad2=0.06)
    b.box("arm", (0.06, 0.06, 1.4), (0, 6.1, -0.7), "pole_green", "body")
    b.box("head", (0.35, 0.14, 0.6), (0, 6.02, -1.35), "pole_green", "body", bevel=0.03, divs=1)
    b.box("lens", (0.28, 0.02, 0.5), (0, 5.94, -1.35), "lamp_glow", "body")
    b.box("banner", (0.02, 0.9, 0.45), (0, 4.4, -0.27), "awning_red", "body")
    return [((0, 3.2, 0), (0.36, 6.4, 0.36))]


def traffic_light(b):
    # Pole on the corner, mast arm over the road toward -X, a three-lamp head facing -Z, a ped signal.
    b.cyl("pole", 0.12, 6.2, (0, 3.1, 0), "pole_grey", "body", orient="y", cols=10, rows=1)
    b.box("mast", (5.0, 0.12, 0.12), (-2.5, 5.9, 0), "pole_grey", "body")
    b.box("brace", (2.0, 0.06, 0.06), (-1.0, 5.4, 0), "pole_grey", "body", rot=(0, 0, 14))
    for k, x in enumerate((-2.2, -4.4)):
        b.box("head%d" % k, (0.36, 1.05, 0.3), (x, 5.35, 0), "signal_body", "body", bevel=0.03, divs=1)
        for i, mat in enumerate(("sig_red", "sig_amber", "sig_green")):
            y = 5.7 - i * 0.34
            b.cyl("lamp%d_%d" % (k, i), 0.11, 0.03, (x, y, -0.16), mat, "body", orient="z", cols=10, rows=1)
            b.box("visor%d_%d" % (k, i), (0.26, 0.03, 0.14), (x, y + 0.13, -0.22), "signal_body", "body")
    b.box("ped_box", (0.3, 0.3, 0.2), (0.2, 2.7, -0.08), "signal_body", "body", bevel=0.02, divs=1)
    b.box("ped_lamp", (0.22, 0.22, 0.02), (0.2, 2.7, -0.19), "sig_amber", "body")
    b.box("button", (0.1, 0.16, 0.06), (0.14, 1.1, -0.12), "sig_amber", "body")
    return [((0, 3.1, 0), (0.25, 6.2, 0.25))]


def bus_stop(b):
    # Shelter 3.2 x 1.4 m, open toward -Z: glass back and sides, roof, bench, ad panel, sign pole.
    W, D, H = 3.2, 1.4, 2.5
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.box("post%d%d" % (sx + 1, sz + 1), (0.08, H, 0.08), (sx * W / 2, H / 2, sz * D / 2), "pole_grey", "body")
        b.box("side_glass%d" % (sx + 1), (0.02, H - 0.4, D - 0.1), (sx * W / 2, H / 2 + 0.1, 0), "glass", "body")
    b.box("back_glass", (W - 0.1, H - 0.4, 0.02), (0, H / 2 + 0.1, D / 2), "glass", "body")
    b.box("roof", (W + 0.3, 0.12, D + 0.3), (0, H + 0.06, -0.05), "pole_grey", "body", rot=(-3, 0, 0))
    b.box("ad", (1.2, 1.8, 0.1), (W / 2 - 0.7, 1.15, D / 2 - 0.06), "ad_panel", "body")
    b.box("bench", (1.8, 0.06, 0.4), (-0.4, 0.45, D / 2 - 0.3), "bench_wood", "body")
    for x in (-1.15, 0.35):
        b.box("bench_leg%d" % int(x > 0), (0.05, 0.43, 0.35), (x, 0.215, D / 2 - 0.3), "pole_grey", "body")
    b.cyl("sign_pole", 0.04, 2.8, (-W / 2 - 0.5, 1.4, -0.5), "pole_grey", "body", orient="y", cols=6, rows=1)
    b.box("sign", (0.45, 0.45, 0.03), (-W / 2 - 0.5, 2.6, -0.5), "sig_green", "body")
    return [((0, H / 2, D / 2), (W, H, 0.1)), ((-W / 2, H / 2, 0), (0.1, H, D)), ((W / 2, H / 2, 0), (0.1, H, D)),
            ((-0.4, 0.24, D / 2 - 0.3), (1.8, 0.48, 0.4))]


# Python SOP: a closed (r, y) profile (counter-clockwise) revolved round Y, `n` sides (a hollow ring wall).
REVOLVE = """
import math
geo = hou.pwd().geometry()
prof, n = %r, %d
rings = []
for r, y in prof:
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        p = geo.createPoint()
        p.setPosition((r * math.cos(a), y, r * math.sin(a)))
        pts.append(p)
    rings.append(pts)
for k in range(len(rings)):
    a, b = rings[k], rings[(k + 1) %% len(rings)]
    for i in range(n):
        j = (i + 1) %% n
        poly = geo.createPolygon()
        for p in (a[i], a[j], b[j], b[i]):  # front face to the right of the profile's travel (outward for CCW)
            poly.addVertex(p)
"""


def fountain(b):
    # Round basin 4.6 m across with a skateable 0.45 m stone rim, a central column and bowl, water surfaces.
    hlib.python_part(b, "basin_wall", REVOLVE % ([(2.05, 0.1), (2.3, 0.0), (2.3, 0.45), (2.36, 0.45), (2.36, 0.53),
                                                    (2.0, 0.53), (2.0, 0.1)], 24), "stone", "body")
    b.cyl("basin_floor", 2.1, 0.1, (0, 0.05, 0), "stone", "body", orient="y", cols=24, rows=1)
    b.cyl("water", 2.04, 0.02, (0, 0.36, 0), "water", "body", orient="y", cols=24, rows=1)
    b.cyl("column", 0.25, 1.4, (0, 0.95, 0), "stone", "body", orient="y", cols=12, rows=1)
    b.cyl("bowl", 0.9, 0.25, (0, 1.6, 0), "stone", "body", orient="y", cols=16, rows=1, rad2=0.6)
    b.cyl("bowl_water", 0.82, 0.02, (0, 1.73, 0), "water", "body", orient="y", cols=16, rows=1)
    b.cyl("spout", 0.08, 0.5, (0, 1.95, 0), "stone", "body", orient="y", cols=8, rows=1)
    hlib.sphere(b, "jet", (0.16, 0.35, 0.16), (0, 2.45, 0), "water", "body", rows=6, cols=8)
    return "mesh"  # the hollow basin and its rim (a ledge to grind)


def newsstand(b):
    # Kiosk 2.4 x 1.6 m with an awning toward -Z, a service window and magazine racks either side.
    b.box("kiosk", (2.4, 2.3, 1.6), (0, 1.15, 0), "kiosk_green", "body", bevel=0.04, divs=1)
    b.box("roof", (2.6, 0.15, 1.8), (0, 2.38, 0), "kiosk_green", "body")
    b.box("window", (1.6, 0.9, 0.03), (0, 1.45, -0.81), "glass", "body")
    b.box("counter", (1.8, 0.06, 0.35), (0, 0.98, -0.95), "metal", "body")
    for i in range(6):
        b.box("awning%d" % i, (0.43, 0.04, 0.8), (-1.08 + i * 0.43, 2.15, -1.15), "awning_red" if i % 2 == 0 else "awning_white",
              "body", rot=(-20, 0, 0))
    for sx in (-1, 1):
        b.box("rack%d" % (sx + 1), (0.06, 1.4, 1.2), (sx * 1.25, 0.9, 0), "metal", "body")
        for r in range(3):
            for c in range(3):
                mat = ("mag_a", "mag_b", "mag_c")[(r + c) % 3]
                b.box("mag%d_%d%d" % (sx + 1, r, c), (0.04, 0.3, 0.22), (sx * 1.3, 0.5 + r * 0.42, -0.35 + c * 0.35), mat, "body")
    b.box("sign", (2.0, 0.35, 0.06), (0, 2.65, -0.7), "awning_white", "body")
    return [((0, 1.2, 0), (2.6, 2.4, 1.6))]


def hydrant(b):
    b.cyl("flange", 0.17, 0.08, (0, 0.04, 0), "hydrant_red", "body", orient="y", cols=12, rows=1)
    b.cyl("body", 0.12, 0.55, (0, 0.35, 0), "hydrant_red", "body", orient="y", cols=12, rows=1)
    b.cyl("collar", 0.15, 0.06, (0, 0.64, 0), "hydrant_red", "body", orient="y", cols=12, rows=1)
    hlib.sphere(b, "cap", (0.13, 0.11, 0.13), (0, 0.68, 0), "hydrant_red", "body", rows=6, cols=12,
                snippet="@P.y = max(@P.y, 0.68);")
    b.cyl("nut", 0.03, 0.06, (0, 0.81, 0), "metal", "body", orient="y", cols=6, rows=1)
    for sx in (-1, 1):
        b.cyl("nozzle%d" % (sx + 1), 0.05, 0.1, (sx * 0.16, 0.42, 0), "hydrant_red", "body", orient="x", cols=8, rows=1)
        b.cyl("nozzle_cap%d" % (sx + 1), 0.055, 0.03, (sx * 0.22, 0.42, 0), "metal", "body", orient="x", cols=8, rows=1)
    b.cyl("pumper", 0.07, 0.12, (0, 0.42, -0.16), "hydrant_red", "body", orient="z", cols=8, rows=1)
    return [((0, 0.42, 0), (0.34, 0.84, 0.34))]


def window_grid(b, p, y, cols, h, W, D):
    """One row of framed windows across the facade front (z = -D/2)."""
    span = W / cols
    for i in range(cols):
        x = -W / 2 + (i + 0.5) * span
        b.box("%s_frame%d" % (p, i), (span * 0.66, h, 0.06), (x, y, -D / 2 - 0.02), "window_frame", "body")
        b.box("%s_glass%d" % (p, i), (span * 0.6, h - 0.08, 0.04), (x, y, -D / 2 - 0.05), "glass", "body")
        b.box("%s_sill%d" % (p, i), (span * 0.7, 0.06, 0.14), (x, y - h / 2 - 0.03, -D / 2 - 0.07), "facade_trim", "body")


def facade_base(b):
    W, H, D = 10.0, 5.0, 0.5
    b.box("wall", (W, H, D), (0, H / 2, 0), "facade", "body")
    for i in range(3):  # two storefronts and a door between
        x = (-3.2, 0.0, 3.2)[i]
        if i == 1:
            b.box("door", (1.4, 2.5, 0.06), (x, 1.25, -D / 2 - 0.02), "door_dark", "body")
            b.box("door_glass", (1.1, 1.6, 0.03), (x, 1.5, -D / 2 - 0.06), "glass", "body")
        else:
            b.box("shop_frame%d" % i, (3.6, 3.0, 0.06), (x, 1.9, -D / 2 - 0.02), "window_frame", "body")
            b.box("shop_glass%d" % i, (3.4, 2.6, 0.03), (x, 2.0, -D / 2 - 0.06), "glass", "body")
            for k in range(5):
                mat = "awning_red" if k % 2 == 0 else "awning_white"
                b.box("awning%d_%d" % (i, k), (0.76, 0.04, 1.1), (x - 1.52 + k * 0.76, 3.7, -D / 2 - 0.5), mat, "body",
                      rot=(-18, 0, 0))
    for x in (-5.0, -1.6, 1.6, 5.0):
        b.box("pilaster%d" % int(x * 10), (0.4, H, 0.12), (x, H / 2, -D / 2 - 0.06), "facade_trim", "body")
    b.box("band", (W + 0.1, 0.3, 0.2), (0, H - 0.15, -D / 2 - 0.05), "facade_trim", "body")
    return [((0, H / 2, 0), (W, H, D))]


def facade_mid(b):
    W, H, D = 10.0, 3.5, 0.5
    b.box("wall", (W, H, D), (0, H / 2, 0), "facade", "body")
    window_grid(b, "row", 1.85, 5, 1.8, W, D)
    b.box("band", (W + 0.1, 0.15, 0.12), (0, 0.075, -D / 2 - 0.04), "facade_trim", "body")
    return [((0, H / 2, 0), (W, H, D))]


def facade_top(b):
    W, H, D = 10.0, 2.0, 0.5
    b.box("parapet", (W, H, D), (0, H / 2, 0), "facade", "body")
    b.box("cornice", (W + 0.3, 0.35, D + 0.35), (0, H - 0.4, -0.12), "facade_trim", "body", bevel=0.05, divs=1)
    b.box("coping", (W + 0.1, 0.1, D + 0.1), (0, H + 0.05, 0), "facade_trim", "body")
    for i in range(10):
        b.box("dentil%d" % i, (0.2, 0.15, 0.1), (-4.5 + i, H - 0.7, -D / 2 - 0.05), "facade_trim", "body")
    b.box("ac_unit", (1.4, 0.9, 1.0), (2.5, H + 0.55, 1.0), "metal", "body", bevel=0.03, divs=1)
    b.cyl("ac_fan", 0.35, 0.03, (2.5, H + 1.01, 1.0), "door_dark", "body", orient="y", cols=12, rows=1)
    return [((0, H / 2, 0), (W, H, D))]


def plaza_ledge_planter(b):
    # 6 m granite ledge (0.5 m tall, steel-edged: skateable) beside a round planter with a tree.
    b.box("ledge", (6.0, 0.5, 0.8), (-1.2, 0.25, 0), "granite", "body", bevel=0.01, divs=1)
    for sz in (-1, 1):
        b.box("edge%d" % (sz + 1), (6.0, 0.03, 0.03), (-1.2, 0.5, sz * 0.39), "metal", "body")
    b.cyl("planter", 0.9, 0.55, (2.8, 0.275, 0), "stone", "body", orient="y", cols=16, rows=1)
    b.cyl("soil", 0.82, 0.02, (2.8, 0.52, 0), "soil", "body", orient="y", cols=16, rows=1)
    b.cyl("trunk", 0.08, 2.0, (2.8, 1.5, 0), "bark", "body", orient="y", cols=6, rows=1)
    for i, (dx, dy, dz, r) in enumerate(((0, 3.0, 0, 0.9), (0.45, 2.7, 0.2, 0.6), (-0.4, 2.75, -0.2, 0.65),
                                          (0.1, 3.5, -0.1, 0.55))):
        hlib.sphere(b, "canopy%d" % i, (r, r * 0.85, r), (2.8 + dx, dy, dz), "leaf", "body", rows=5, cols=8,
                    snippet="vector n = noise(@P * 2.5 + %d); @P += (n - 0.5) * 0.25;" % i)
    return [((-1.2, 0.25, 0), (6.0, 0.5, 0.8)), ((2.8, 0.28, 0), (1.8, 0.56, 1.8)), ((2.8, 1.5, 0), (0.2, 2.0, 0.2))]


PIECES = [
    ("streetlight", streetlight), ("traffic_light", traffic_light), ("bus_stop", bus_stop), ("fountain", fountain),
    ("newsstand", newsstand), ("hydrant", hydrant), ("facade_base", facade_base), ("facade_mid", facade_mid),
    ("facade_top", facade_top), ("plaza_ledge_planter", plaza_ledge_planter),
]

if __name__ == "__main__":
    import os
    import sys
    hlib.run_kit("downtown", PIECES, MATS)
    sys.stdout.flush()
    os._exit(0)
