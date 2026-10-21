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
    "ocean": (1.0, 1.0, 1.0), "foam": (1.0, 1.0, 1.0), "wave": (1.0, 1.0, 1.0), "cliff": (1.0, 1.0, 1.0),
    "sail": (0.97, 0.96, 0.92), "hull": (0.92, 0.3, 0.25),
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


# --- ocean and view ------------------------------------------------------------------------------------------------
# The sea pieces share one frame: the waterline runs along X at z = 0 and the sea extends toward +Z. Vertex colours
# carry the look (shallow turquoise to deep blue, white foam); UVs are laid out for a scrolling wave shader in Godot
# (the motion itself is a shader, not baked here).

OCEAN = """
geo = hou.pwd().geometry()
geo.addAttrib(hou.attribType.Point, "Cd", (1.0, 1.0, 1.0))
geo.addAttrib(hou.attribType.Vertex, "uv", (0.0, 0.0, 0.0))
W, xs = 160.0, 41
zs = [0.0, 1.0, 2.0, 3.5, 5.0, 7.0, 9.5, 12.5, 16.0, 20.0, 26.0, 34.0, 45.0, 60.0, 80.0, 105.0, 140.0, 180.0]
shallow, mid, deep = (0.3, 0.85, 0.8), (0.12, 0.6, 0.78), (0.06, 0.28, 0.6)
grid = []
for z in zs:
    t = min(1.0, z / 40.0)
    if t <= 0.5:
        c = [shallow[i] + (mid[i] - shallow[i]) * t * 2 for i in range(3)]
    else:
        c = [mid[i] + (deep[i] - mid[i]) * (t - 0.5) * 2 for i in range(3)]
    row = []
    for i in range(xs):
        p = geo.createPoint()
        p.setPosition((-W / 2 + W * i / (xs - 1), 0.0, z))
        p.setAttribValue("Cd", c)
        row.append(p)
    grid.append(row)
for a, b in zip(grid, grid[1:]):
    for i in range(xs - 1):
        poly = geo.createPolygon()
        for p in (a[i], a[i + 1], b[i + 1], b[i]):  # faces up
            q = p.position()
            poly.addVertex(p).setAttribValue("uv", (q[0] / 8.0, q[2] / 8.0, 0.0))
"""

FOAM = """
import math
geo = hou.pwd().geometry()
geo.addAttrib(hou.attribType.Point, "Cd", (1.0, 1.0, 1.0))
geo.addAttrib(hou.attribType.Vertex, "uv", (0.0, 0.0, 0.0))
W, n = 160.0, 161
rows = [(-0.6, 0.0), (0.4, 1.0), (1.6, 0.55), (2.6, 0.0)]  # (z offset, foam density)
grid = []
for zo, dens in rows:
    row = []
    for i in range(n):
        x = -W / 2 + W * i / (n - 1)
        wob = 0.5 * math.sin(x * 0.37) + 0.3 * math.sin(x * 1.13 + 1.7)
        p = geo.createPoint()
        p.setPosition((x, 0.03, zo + wob))
        v = 0.55 + 0.45 * dens
        p.setAttribValue("Cd", (v, min(1.0, v + 0.04), min(1.0, v + 0.06)))
        row.append(p)
    grid.append(row)
for r, (a, b) in enumerate(zip(grid, grid[1:])):
    for i in range(n - 1):
        poly = geo.createPolygon()
        for p, (u, w) in ((a[i], (i, r)), (a[i + 1], (i + 1, r)), (b[i + 1], (i + 1, r + 1)), (b[i], (i, r + 1))):
            poly.addVertex(p).setAttribValue("uv", (u / 4.0, w / 3.0, 0.0))
"""

# A breaking wave, swept along X and dying out at both ends: the body rises from the water on the shore side (-Z) up
# a concave face to the crest and slopes back down out to sea; a separate lip pitches forward over the face. Colour
# runs from the sea's turquoise at the waterline to white at the crest and lip. Two-sided. Origin at its base centre.
WAVE = """
import math
geo = hou.pwd().geometry()
geo.addAttrib(hou.attribType.Point, "Cd", (1.0, 1.0, 1.0))
geo.addAttrib(hou.attribType.Vertex, "uv", (0.0, 0.0, 0.0))
L, n = 24.0, 49
body = [((-4.0, 0.0), (0.12, 0.6, 0.78)), ((-2.2, 0.3), (0.16, 0.68, 0.8)), ((-1.1, 0.9), (0.22, 0.76, 0.82)),
        ((-0.55, 1.7), (0.35, 0.84, 0.86)), ((-0.4, 2.4), (0.6, 0.92, 0.94)), ((-0.1, 3.0), (0.97, 0.99, 1.0)),
        ((0.8, 2.7), (0.5, 0.8, 0.88)), ((2.4, 1.4), (0.14, 0.55, 0.75)), ((5.0, 0.0), (0.1, 0.45, 0.7))]
lip = [((-0.1, 3.0), (0.97, 0.99, 1.0)), ((-0.9, 3.05), (1.0, 1.0, 1.0)), ((-1.6, 2.7), (0.95, 0.98, 1.0)),
       ((-1.9, 2.1), (0.85, 0.94, 0.97))]
def strip(prof, vofs):
    rows = []
    for (z, y), c in prof:
        row = []
        for i in range(n):
            x = -L / 2 + L * i / (n - 1)
            taper = math.sin(math.pi * i / (n - 1)) ** 0.6
            p = geo.createPoint()
            p.setPosition((x, y * taper, z * (0.4 + 0.6 * taper)))
            p.setAttribValue("Cd", c)
            row.append(p)
        rows.append(row)
    for k, (a, b) in enumerate(zip(rows, rows[1:])):
        for i in range(n - 1):
            for quad in ((a[i], b[i], b[i + 1], a[i + 1]), (a[i + 1], b[i + 1], b[i], a[i])):
                poly = geo.createPolygon()
                for p in quad:
                    q = p.position()
                    poly.addVertex(p).setAttribValue("uv", (q[0] / 6.0, (k + vofs) / 12.0, 0.0))
strip(body, 0)
strip(lip, 8)
"""

CLIFF = "int s = %d; vector n = noise(@P * 0.06 + s); @P += (n - 0.5) * set(14, 9, 14); @P.y = max(@P.y, 0);"
CLIFF_COLOUR = """vector n = normalize(v@N);
float grass = smooth(0.55, 0.8, n.y) * smooth(4.0, 9.0, @P.y);
v@Cd = lerp(set(0.55, 0.47, 0.4), set(0.36, 0.62, 0.3), grass) * fit(noise(@P * 0.3), 0.3, 0.7, 0.85, 1.05);
"""


def ocean_plane(b):
    # 160 m along the shore x 180 m out to sea, denser near the waterline (where the shader's waves show most).
    hlib.python_part(b, "ocean", OCEAN, "ocean", "ocean")
    return []


def shoreline_foam(b):
    # A 160 m foam band along the waterline, wavy edge, uv.x along the shore for a scrolling foam texture.
    hlib.python_part(b, "foam", FOAM, "foam", "foam")
    return []


def wave_crest(b):
    hlib.python_part(b, "wave", WAVE, "wave", "wave")
    return []


def coloured_rock(b, src):
    nrm = b.net.createNode("normal", "n_for_colour")
    nrm.setInput(0, src)
    nrm.parm("type").set("typepoint")
    b.tag(b.wrangle(nrm, CLIFF_COLOUR, name="rock_and_grass"), "cliff", "body")


def headland(seed, size):
    def fn(b):
        # Backdrop cliff mass with grassy tops (vertex colour), for either end of the bay.
        box = b.net.createNode("box", "mass")
        for k, v in (("type", "polymesh"), ("sizex", size[0]), ("sizey", size[1]), ("sizez", size[2]),
                     ("ty", size[1] / 2), ("divrate1", 13), ("divrate2", 7), ("divrate3", 9)):
            box.parm(k).set(v)
        coloured_rock(b, b.wrangle(box, CLIFF % seed + " @P.y *= 1 - 0.35 * smooth(0, %f, abs(@P.x));" % (size[0] / 2),
                                   name="erode"))
        return "mesh"
    return fn


def distant_island(b):
    # A low green island for the horizon, 120 x 14 x 56 m.
    s = b.net.createNode("sphere", "mound")
    for k, v in (("type", "polymesh"), ("rows", 8), ("cols", 16), ("radx", 60.0), ("rady", 14.0), ("radz", 28.0)):
        s.parm(k).set(v)
    coloured_rock(b, b.wrangle(s, CLIFF % 11, name="erode"))
    return []


def sailboat(b):
    # 6 m dinghy for the view: hull, deck, mast, mainsail and jib; bow toward -Z.
    hlib.sphere(b, "hull", (0.9, 0.45, 3.0), (0, 0.3, 0), "hull", "body", rows=6, cols=12,
                snippet="@P.y = max(@P.y, 0.3); @P.x *= 1 - 0.6 * smooth(0.0, 3.0, -@P.z);")
    b.box("deck", (1.5, 0.05, 4.8), (0, 0.32, 0.3), "wood_light", "body")
    b.cyl("mast", 0.06, 7.0, (0, 3.8, -0.6), "metal", "body", orient="y", cols=6, rows=1)
    b.box("main", (0.02, 5.8, 2.6), (0, 3.6, 0.7), "sail", "body", taper=(1.0, 0.05, -1.25))
    b.box("jib", (0.02, 4.6, 1.8), (0, 3.0, -1.5), "sail", "body", taper=(1.0, 0.05, 0.85))
    return []


PIECES = [
    ("palm_tree_a", palm(7.0, 0.8, 8, 2.4, 1)), ("palm_tree_b", palm(8.5, -1.3, 9, 2.7, 2)),
    ("palm_tree_c", palm(5.5, 0.4, 7, 2.1, 3)), ("lifeguard_tower", lifeguard_tower), ("pier_section", pier_section),
    ("boardwalk_planks", boardwalk), ("food_stand", food_stand), ("surfboard_rack", surfboard_rack),
    ("umbrella_towel_set", umbrella_set), ("rocks", rocks),
    ("ocean_plane", ocean_plane), ("shoreline_foam", shoreline_foam), ("wave_crest", wave_crest),
    ("headland_left", headland(5, (70.0, 28.0, 45.0))), ("headland_right", headland(9, (55.0, 22.0, 40.0))),
    ("distant_island", distant_island), ("sailboat", sailboat),
]

# The view shot (--view): pieces placed as a bay seen from the sand, previews/beach_view.png.
VIEW = {
    "ocean_plane": (0, 0, 0, 0), "shoreline_foam": (0, 0, 0, 0), "wave_crest": (-8, 0, 30, 0),
    "headland_left": (-80, 0, 30, 20), "headland_right": (75, 0, 45, -25), "distant_island": (40, -2, 175, 0),
    "sailboat": (-22, 0, 70, 60), "palm_tree_a": (-7, 0, -8, 0), "palm_tree_b": (9, 0, -12, 0),
    "palm_tree_c": (14, 0, -5, 0), "lifeguard_tower": (3, 0, -6, 180), "umbrella_towel_set": (-3, 0, -3, 0),
    "surfboard_rack": (-12, 0, -9, 160), "rocks": (20, 0, 1, 30),
}


def view():
    hlib.MATERIALS.update(MATS)
    hlib.MATERIALS["concrete"] = (0.93, 0.85, 0.66)  # the preview ground plays the sand
    hlib.ensure_materials()
    for name, fn in PIECES:
        if name not in VIEW:
            continue
        sub, _ = hlib.build_piece("beach", name, fn)
        x, y, z, ry = VIEW[name]
        obj = sub.parent()
        obj.parmTuple("t").set((x, y, z))
        obj.parm("ry").set(ry)
    focus = hou.node("/obj/beach_ocean_plane/ocean_plane")
    hlib.preview(focus, os.path.join(hlib.PREVIEWS, "beach_view.png"), res=(1600, 800), azimuth=0.0, elevation=6.0,
                 radius=26.0, center=(0, 4.0, 22.0))


if __name__ == "__main__":
    import os
    import sys

    import hou
    if "--view" in sys.argv:
        view()
        sys.stdout.flush()
        os._exit(0)
    hlib.run_kit("beach", PIECES, MATS)
    sys.stdout.flush()
    os._exit(0)
