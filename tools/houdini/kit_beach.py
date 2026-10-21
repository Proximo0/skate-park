"""Beachfront kit. Usage: hython tools/houdini/kit_beach.py [--preview]

Writes assets/props/houdini/beach/<piece>.glb and kit.json (collision boxes). Metres, +Y up, front -Z, origin at the
base centre. Flat colour materials (and vertex colour bands on the palm trunks) for the toon shader.
"""
import math

import hlib

MATS = {
    "bark": (1.0, 1.0, 1.0), "frond": (0.22, 0.6, 0.25), "coconut": (0.4, 0.26, 0.12), "wood_light": (0.82, 0.68, 0.48),
    "wood_weathered": (0.62, 0.55, 0.47), "paint_white": (0.95, 0.95, 0.92), "paint_red": (0.88, 0.2, 0.18),
    "paint_aqua": (0.25, 0.75, 0.78), "paint_yellow": (0.98, 0.8, 0.25), "rope": (0.85, 0.78, 0.6),
    "glass": (0.4, 0.6, 0.68), "rock": (0.52, 0.5, 0.47), "towel_pink": (0.95, 0.45, 0.62),
    "towel_blue": (0.3, 0.5, 0.9), "board_orange": (0.98, 0.55, 0.2), "board_teal": (0.2, 0.7, 0.68),
    "board_white": (0.96, 0.96, 0.93), "board_pink": (0.95, 0.5, 0.7), "metal": (0.6, 0.62, 0.65),
    "sign": (0.98, 0.95, 0.85), "cooler": (0.2, 0.45, 0.85),
}

# Python SOP: a curved, tapered trunk with alternating vertex-colour bands, then fronds (double-sided, drooping
# leaves with a raised midrib) and coconuts at the crown. Parameters are filled in per variant.
PALM = """
import math
geo = hou.pwd().geometry()
geo.addAttrib(hou.attribType.Point, "Cd", (1.0, 1.0, 1.0))
H, LEAN, R0, R1, NF, FL, SEED = %(h)f, %(lean)f, %(r0)f, %(r1)f, %(nf)d, %(fl)f, %(seed)d
rows, cols = 12, 8
def centre(t):
    return (LEAN * t * t, H * t, 0.15 * LEAN * math.sin(t * 3.0))
rings = []
for i in range(rows + 1):
    t = i / float(rows)
    c = centre(t)
    r = R0 + (R1 - R0) * t
    band = (0.62, 0.48, 0.33) if i %% 2 == 0 else (0.5, 0.38, 0.26)
    ring = []
    for j in range(cols):
        a = 2 * math.pi * j / cols
        p = geo.createPoint()
        p.setPosition((c[0] + r * math.cos(a), c[1], c[2] + r * math.sin(a)))
        p.setAttribValue("Cd", band)
        ring.append(p)
    rings.append(ring)
for a, b in zip(rings, rings[1:]):
    for j in range(cols):
        k = (j + 1) %% cols
        poly = geo.createPolygon()
        for p in (a[j], a[k], b[k], b[j]):
            poly.addVertex(p)
top = centre(1.0)
cap = geo.createPolygon()
for p in reversed(rings[-1]):
    cap.addVertex(p)
"""

FRONDS = """
import math, random
geo = hou.pwd().geometry()
H, LEAN, NF, FL, SEED = %(h)f, %(lean)f, %(nf)d, %(fl)f, %(seed)d
rnd = random.Random(SEED)
crown = hou.Vector3(LEAN, H, 0.15 * LEAN * math.sin(3.0))
seg = 7
for k in range(NF):
    yaw = 2 * math.pi * k / NF + rnd.uniform(-0.2, 0.2)
    lift = rnd.uniform(0.15, 0.55)
    L = FL * rnd.uniform(0.85, 1.1)
    grid = []
    for i in range(seg + 1):
        t = i / float(seg)
        w = 0.32 * math.sin(math.pi * min(1.0, t * 1.15 + 0.05)) * (1.0 - 0.3 * t)
        d = L * t
        y = lift * d - 0.9 * (d / L) ** 2 * L * 0.55
        row = []
        for s in (-1.0, 0.0, 1.0):
            x = s * w
            yy = y + (0.06 * w if s == 0.0 else -0.04 * w)
            lx, lz = x, d
            px = crown[0] + lx * math.cos(yaw) + lz * math.sin(yaw)
            pz = crown[2] - lx * math.sin(yaw) + lz * math.cos(yaw)
            p = geo.createPoint()
            p.setPosition((px, crown[1] + yy, pz))
            row.append(p)
        grid.append(row)
    for a, b in zip(grid, grid[1:]):
        for j in range(2):
            for quad in ((a[j], a[j + 1], b[j + 1], b[j]), (b[j], b[j + 1], a[j + 1], a[j])):
                poly = geo.createPolygon()
                for p in quad:
                    poly.addVertex(p)
"""


def palm(h, lean, nf, fl, seed):
    def fn(b):
        args = {"h": h, "lean": lean, "r0": 0.2, "r1": 0.13, "nf": nf, "fl": fl, "seed": seed}
        hlib.python_part(b, "trunk", PALM % args, "bark", "trunk")
        hlib.python_part(b, "fronds", FRONDS % args, "frond", "fronds")
        for k in range(3):
            a = 2 * math.pi * k / 3 + seed
            hlib.sphere(b, "coconut%d" % k, (0.09, 0.1, 0.09),
                        (lean + 0.13 * math.cos(a), h - 0.12, 0.15 * lean * math.sin(3.0) + 0.13 * math.sin(a)),
                        "coconut", "fronds", rows=5, cols=7)
        return [((lean * 0.5, h * 0.5, 0), (0.45 + abs(lean) * 0.5, h, 0.45))]
    return fn


def lifeguard_tower(b):
    # Raised hut on four splayed legs with a ramp toward -Z; about 4.6 m tall.
    deck = 2.0
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.box("leg%d%d" % (sx + 1, sz + 1), (0.14, deck + 0.1, 0.14), (sx * 1.05, deck / 2, sz * 1.05),
                  "paint_white", "body", rot=(sz * 6, 0, -sx * 6))
    b.box("brace_x", (2.2, 0.08, 0.08), (0, 0.9, 1.0), "paint_white", "body")
    b.box("brace_x2", (2.2, 0.08, 0.08), (0, 0.9, -1.0), "paint_white", "body")
    b.box("deck", (2.6, 0.12, 2.6), (0, deck, 0), "wood_light", "body")
    b.box("hut", (2.0, 1.6, 1.8), (0, deck + 0.86, 0.2), "paint_aqua", "body", bevel=0.03, divs=1)
    b.box("window", (1.6, 0.6, 0.03), (0, deck + 1.15, -0.71), "glass", "body")
    b.box("stripe", (2.02, 0.18, 1.82), (0, deck + 0.3, 0.2), "paint_red", "body")
    b.box("roof_a", (1.3, 0.08, 2.3), (-0.55, deck + 1.85, 0.2), "paint_red", "body", rot=(0, 0, 22))
    b.box("roof_b", (1.3, 0.08, 2.3), (0.55, deck + 1.85, 0.2), "paint_red", "body", rot=(0, 0, -22))
    b.box("gable_f", (2.0, 0.42, 0.04), (0, deck + 1.86, -0.71), "paint_white", "body", taper=(0.05, 1.0, 0.0))
    b.box("gable_b", (2.0, 0.42, 0.04), (0, deck + 1.86, 1.11), "paint_white", "body", taper=(0.05, 1.0, 0.0))
    for sx in (-1, 1):
        b.box("rail_side%d" % (sx + 1), (0.05, 0.05, 2.6), (sx * 1.28, deck + 0.9, 0), "paint_white", "body")
        for z in (-1.25, 0.0, 1.25):
            b.box("rail_post%d_%d" % (sx + 1, int(z * 10)), (0.05, 0.9, 0.05), (sx * 1.28, deck + 0.45, z), "paint_white", "body")
    b.box("rail_front", (2.6, 0.05, 0.05), (-0.0, deck + 0.9, -1.28), "paint_white", "body")
    ang = math.degrees(math.atan2(deck, 3.0))
    b.box("ramp", (0.9, 0.08, math.hypot(deck, 3.0)), (0.6, deck / 2, -2.8), "wood_light", "body", rot=(-ang, 0, 0))
    for i in range(8):
        t = (i + 0.5) / 8
        b.box("cleat%d" % i, (0.88, 0.03, 0.05), (0.6, deck * (1 - t) + 0.05, -1.3 - 3.0 * t), "wood_weathered", "body")
    b.box("flag_pole", (0.04, 1.2, 0.04), (0.95, deck + 2.3, 0.95), "metal", "body")
    b.box("flag", (0.5, 0.3, 0.02), (1.22, deck + 2.75, 0.95), "paint_red", "body")
    return [((0, deck / 2 + 0.6, 0), (2.6, deck + 1.2, 2.6)), ((0, deck + 0.86, 0.2), (2.0, 1.6, 1.8)),
            ((0.6, deck / 2, -2.8), (0.9, deck, 3.0))]


def pier_section(b):
    # 6 m long (Z) x 4 m wide deck at 2.0 m on pilings (ground/sea bed at y = 0), railings both sides.
    deck = 2.0
    for i in range(20):
        b.box("plank%d" % i, (4.0, 0.06, 0.28), (0, deck - 0.03, -2.85 + i * 0.3), "wood_weathered", "body")
    for sx in (-1, 0, 1):
        b.box("beam%d" % (sx + 1), (0.15, 0.25, 6.0), (sx * 1.8, deck - 0.185, 0), "wood_weathered", "body")
    for sx in (-1, 1):
        for z in (-2.7, 0.0, 2.7):
            b.cyl("piling%d_%d" % (sx + 1, int(z)), 0.16, deck + 0.9, (sx * 1.85, (deck + 0.9) / 2, z), "wood_weathered",
                  "body", orient="y", cols=10, rows=1)
        b.box("rail%d" % (sx + 1), (0.1, 0.1, 6.0), (sx * 1.9, deck + 0.95, 0), "wood_light", "body")
        b.box("rail_mid%d" % (sx + 1), (0.06, 0.08, 6.0), (sx * 1.9, deck + 0.5, 0), "wood_light", "body")
    for z in (-1.3, 1.3):
        b.cyl("rope_coil%d" % int(z > 0), 0.18, 0.08, (1.4, deck + 0.04, z), "rope", "body", orient="y", cols=10, rows=1)
    b.box("bench", (0.45, 0.45, 1.6), (-1.5, deck + 0.22, 0), "wood_light", "body")
    return [((0, deck - 0.1, 0), (4.0, 0.2, 6.0)), ((-1.9, deck + 0.5, 0), (0.12, 1.0, 6.0)),
            ((1.9, deck + 0.5, 0), (0.12, 1.0, 6.0))]


def boardwalk(b):
    # 4 m wide (X) x 2 m (Z) module, 0.25 m tall, planks across with 1 cm gaps, on joists.
    for i in range(14):
        b.box("plank%d" % i, (4.0, 0.04, 0.13), (0, 0.23, -0.93 + i * 0.143), "wood_light", "body")
    for x in (-1.8, -0.6, 0.6, 1.8):
        b.box("joist%d" % int(x * 10), (0.1, 0.2, 2.0), (x, 0.1, 0), "wood_weathered", "body")
    return [((0, 0.125, 0), (4.0, 0.25, 2.0))]


def food_stand(b):
    # Beach shack 3 x 2.5 m, serving hatch and striped awning toward -Z, surf sign on the roof.
    b.box("shack_l", (0.5, 2.4, 2.5), (-1.25, 1.2, 0), "paint_aqua", "body")
    b.box("shack_r", (0.5, 2.4, 2.5), (1.25, 1.2, 0), "paint_aqua", "body")
    b.box("shack_back", (2.0, 2.4, 0.2), (0, 1.2, 1.15), "paint_aqua", "body")
    b.box("counter_front", (2.0, 1.0, 0.2), (0, 0.5, -1.15), "paint_aqua", "body")
    b.box("header", (2.0, 0.5, 0.2), (0, 2.15, -1.15), "paint_aqua", "body")
    b.box("counter", (2.2, 0.06, 0.45), (0, 1.03, -1.2), "wood_light", "body")
    for i in range(7):  # board-and-batten trim
        b.box("batten%d" % i, (0.04, 2.4, 0.02), (-1.5 + i * 0.5, 1.2, -1.26), "paint_white", "body")
    b.box("roof", (3.4, 0.12, 2.9), (0, 2.46, 0), "wood_weathered", "body")
    for i in range(6):
        mat = "paint_red" if i % 2 == 0 else "paint_white"
        b.box("awning%d" % i, (0.5, 0.04, 1.0), (-1.25 + i * 0.5, 2.15, -1.6), mat, "body", rot=(-18, 0, 0))
    b.box("sign", (1.8, 0.5, 0.06), (0, 2.85, -1.1), "sign", "body", bevel=0.02, divs=1)
    b.box("sign_post_a", (0.06, 0.4, 0.06), (-0.7, 2.6, -1.1), "wood_light", "body")
    b.box("sign_post_b", (0.06, 0.4, 0.06), (0.7, 2.6, -1.1), "wood_light", "body")
    for i, x in enumerate((-0.6, 0.6)):
        b.cyl("stool_seat%d" % i, 0.18, 0.05, (x, 0.75, -1.8), "paint_red", "body", orient="y", cols=10, rows=1)
        b.cyl("stool_leg%d" % i, 0.03, 0.72, (x, 0.36, -1.8), "metal", "body", orient="y", cols=6, rows=1)
    return [((0, 1.25, 0), (3.0, 2.5, 2.5))]


def board(b, name, length, mat, center, rot):
    """Surfboard: a flat ellipsoid with a narrowed nose (toward -Z before rot), rotated about its centre."""
    hlib.sphere(b, name, (0.26, 0.035, length / 2), center, mat, "body", rows=6, cols=14,
                snippet="@P.x = %f + (@P.x - %f) * (1 - 0.5 * smooth(0.0, %f, %f - @P.z));"
                        % (center[0], center[0], length / 2, center[2]))
    b.parts[-1].setInput(0, _rotate(b, b.parts[-1].inputs()[0], center, rot))


def _rotate(b, node, pivot, rot):
    x = b.net.createNode("xform", node.name() + "_rot")
    x.setInput(0, node)
    for a, v in zip("xyz", rot):
        x.parm("r" + a).set(v)
    for a, v in zip("xyz", pivot):
        x.parm("p" + a).set(v)
    return x


def surfboard_rack(b):
    # A-frame rack 2.4 m wide with four boards leaning on the -Z side.
    for sx in (-1, 1):
        b.box("frame_f%d" % (sx + 1), (0.08, 1.8, 0.08), (sx * 1.15, 0.88, -0.3), "wood_light", "body", rot=(-12, 0, 0))
        b.box("frame_b%d" % (sx + 1), (0.08, 1.8, 0.08), (sx * 1.15, 0.88, 0.3), "wood_light", "body", rot=(12, 0, 0))
    for y in (0.5, 1.4):
        b.box("bar%d" % int(y * 10), (2.4, 0.07, 0.07), (0, y, -0.38 + (y - 0.5) * 0.15), "wood_light", "body")
    for i, mat in enumerate(("board_orange", "board_teal", "board_white", "board_pink")):
        x = -0.8 + i * 0.53
        board(b, "board%d" % i, 2.0, mat, (x, 1.0, -0.6), (-78, 0, 0))
    return [((0, 0.9, -0.25), (2.4, 1.85, 1.0))]


UMBRELLA = """
import math
geo = hou.pwd().geometry()
geo.addAttrib(hou.attribType.Prim, "shop_materialpath", "")
n, R, H, Y = 10, 1.1, 0.35, 2.1
apex = geo.createPoint()
apex.setPosition((0, Y + H, 0))
rim = []
for i in range(n):
    a = 2 * math.pi * i / n
    p = geo.createPoint()
    p.setPosition((R * math.cos(a), Y, R * math.sin(a)))
    rim.append(p)
for i in range(n):
    for tri in ((apex, rim[(i + 1) % n], rim[i]), (apex, rim[i], rim[(i + 1) % n])):
        poly = geo.createPolygon()
        for p in tri:
            poly.addVertex(p)
        poly.setAttribValue("shop_materialpath", "/mat/paint_red" if i % 2 == 0 else "/mat/paint_white")
"""


def umbrella_set(b):
    # Beach umbrella (tilted pole) over two towels and a cooler.
    canopy = b.net.createNode("python", "canopy")
    canopy.parm("python").set(UMBRELLA)
    w = b.wrangle(canopy, 's@path = "body";', cls="primitive", name="canopy_tag")
    b.parts.append(w)
    b.cyl("pole", 0.025, 2.4, (0, 1.2, 0), "metal", "body", orient="y", cols=6, rows=1)
    b.box("towel_a", (0.8, 0.01, 1.7), (-0.55, 0.005, 0.1), "towel_pink", "body", rot=(0, 8, 0))
    b.box("towel_b", (0.8, 0.01, 1.7), (0.55, 0.005, -0.05), "towel_blue", "body", rot=(0, -6, 0))
    for i, x in enumerate((-0.55, 0.55)):
        b.box("towel_stripe%d" % i, (0.8, 0.012, 0.12), (x, 0.006, -0.55), "paint_white", "body", rot=(0, 8 - i * 14, 0))
    b.box("cooler", (0.5, 0.35, 0.32), (1.25, 0.175, 0.6), "cooler", "body", bevel=0.03, divs=1)
    b.box("cooler_lid", (0.52, 0.06, 0.34), (1.25, 0.37, 0.6), "paint_white", "body", bevel=0.02, divs=1)
    return [((0, 1.2, 0), (0.1, 2.4, 0.1)), ((1.25, 0.2, 0.6), (0.52, 0.4, 0.34))]


ROCK = "int s = %d; vector n = noise(@P * 2.2 + s); @P *= 0.8 + 0.45 * n.x; @P.y = max(@P.y, -0.02) * %f;"


def rocks(b):
    # A faceted cluster of four rocks, about 2.4 x 1.2 m.
    for i, (r, c, sq) in enumerate((((0.9, 0.7, 0.8), (0, 0.35, 0), 1.0), ((0.6, 0.45, 0.55), (0.95, 0.22, 0.3), 0.9),
                                    ((0.45, 0.3, 0.4), (-0.85, 0.15, -0.35), 0.8), ((0.3, 0.2, 0.3), (0.4, 0.1, -0.75), 0.8))):
        hlib.sphere(b, "rock%d" % i, r, c, "rock", "body", rows=6, cols=8,
                    snippet=ROCK % (i * 7 + 3, sq) + " @P.y = max(@P.y, 0);")
    return "mesh"


PIECES = [
    ("palm_tree_a", palm(7.0, 0.8, 8, 2.4, 1)), ("palm_tree_b", palm(8.5, -1.3, 9, 2.7, 2)),
    ("palm_tree_c", palm(5.5, 0.4, 7, 2.1, 3)), ("lifeguard_tower", lifeguard_tower), ("pier_section", pier_section),
    ("boardwalk_planks", boardwalk), ("food_stand", food_stand), ("surfboard_rack", surfboard_rack),
    ("umbrella_towel_set", umbrella_set), ("rocks", rocks),
]

if __name__ == "__main__":
    import os
    import sys
    hlib.run_kit("beach", PIECES, MATS)
    sys.stdout.flush()
    os._exit(0)
