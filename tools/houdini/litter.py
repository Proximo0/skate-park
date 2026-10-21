"""Litter kit and litter scatter. Usage: hython tools/houdini/litter.py

HDA skatepark::litter_kit: seed, size, layout (0 = every item at the origin for instancing,
1 = spread in a row for previews). Exports assets/props/houdini/litter_kit.glb with one named
mesh per item, each resting on y = 0 and under 200 triangles.

HDA skatepark::litter_scatter: seed, count, area. Writes instance points (item, position,
yaw, scale) as assets/props/houdini/litter_scatter_example.json for a 10 x 10 m area.
"""
import json
import os

import hou
import hlib

ITEMS = ["can_crushed_a", "can_crushed_b", "cup", "paper_crumpled_a", "paper_crumpled_b",
    "chip_bag_a", "chip_bag_b", "newspaper", "pizza_box", "napkin"]

SEED = 'int s = chi("../seed");'
PINCH = SEED + """
float fz = abs(@P.z) / 0.1;
@P.y *= 1 - smooth(0.55, 1.0, fz) * 0.9;
@P.y += (noise(@P * 30 + s + %d) - 0.5) * 0.012;
@P.x *= 1 - smooth(0.7, 1.0, fz) * 0.15;
"""


def item(b, i, name, src, snippet, mat, cusp=40.0):
    """Shape, rest on y = 0 (spread in a grid when layout is on), per-item hard-edge normals, tag."""
    n = b.wrangle(src, snippet, name=name + "_shape") if snippet else src
    rest = b.wrangle(n, ('@P.y -= getbbox_min(0).y; @P.x += ch("../layout") * %.2f; @P.z += ch("../layout") * %.2f;'
        % ((i % 5 - 2) * 0.4, (i // 5 - 0.5) * 0.45)),
        name=name + "_rest")
    nrm = b.net.createNode("normal", name + "_n")
    nrm.setInput(0, rest)
    nrm.parm("type").set("typevertex")
    nrm.parm("cuspangle").set(cusp)
    b.tag(nrm, mat, name)


def prim(b, kind, name, **parms):
    n = b.net.createNode(kind, name)
    for k, v in parms.items():
        if isinstance(v, tuple):
            n.parmTuple(k).set(v)
        else:
            n.parm(k).set(v)
    return n


# Python SOP: a lathe from (y, r) rings, 10 or 12 around, with per-ring point colour; optional caps.
LATHE = """
import math
geo = hou.pwd().geometry()
geo.addAttrib(hou.attribType.Point, "Cd", (1.0, 1.0, 1.0))
rings = []
for y, r, cd in PROFILE:
    pts = []
    for i in range(COLS):
        a = 2 * math.pi * i / COLS
        p = geo.createPoint()
        p.setPosition((r * math.cos(a), y, r * math.sin(a)))
        p.setAttribValue("Cd", cd)
        pts.append(p)
    rings.append(pts)
for a, b in zip(rings, rings[1:]):
    for i in range(COLS):
        j = (i + 1) % COLS
        poly = geo.createPolygon()
        for p in (a[i], a[j], b[j], b[i]):
            poly.addVertex(p)
for ring, top in ((rings[0], False), (rings[-1], True)):
    if top and not CAP_TOP:
        continue
    poly = geo.createPolygon()
    for p in (ring if top else list(reversed(ring))):
        poly.addVertex(p)
"""

SILVER = (0.78, 0.79, 0.82)
WHITE = (1.0, 1.0, 1.0)


def can(b, name, colour, band):
    """Drink can: rolled bottom, straight wall with a printed band, necked top; 10 around."""
    prof = [(0.0, 0.024, SILVER), (0.004, 0.03, SILVER), (0.012, 0.033, colour), (0.045, 0.033, band),
            (0.075, 0.033, colour), (0.108, 0.033, colour), (0.117, 0.028, SILVER), (0.122, 0.029, SILVER)]
    code = "PROFILE = %r\nCOLS = 10\nCAP_TOP = True\n" % (prof,) + LATHE
    return prim(b, "python", name, python=code)


# Crush: the mid wall folds in three lobes (phase alternating per row), the can squashes to ~60% height and
# tilts; then it lies on its side. The pull tab is added after, on the lid.
CRUSH = SEED + """
float t = fit(@P.y, 0.012, 0.108, 0, 1);
float mid = sin(t * PI);
float a = atan2(@P.z, @P.x);
float ph = (int(@P.y * 1000) %% 2) * 1.05 + rand(s + %d) * 6.28;
float fold = 0.5 + 0.5 * cos(3 * a + ph);
float k = 1 - 0.32 * mid * fold;
@P.x *= k; @P.z *= k;
@P.y = @P.y * (1 - 0.4 * smooth(0.02, 0.11, @P.y)) + mid * 0.008 * sin(a * 2 + s);
@P = set(@P.y, @P.x, @P.z);
"""
CUP_SHAPE = SEED + """
@P += (vector(noise(@P * 25 + s)) - 0.5) * set(0.006, 0.002, 0.006) * smooth(0.02, 0.1, @P.y);
@P = set(@P.y, @P.x, @P.z);
"""
CRUMPLE_BOX = SEED + """
vector n = noise(@P * 55 + s + %d);
@P = normalize(@P) * %f * (0.8 + 0.5 * n.x);
@P.y *= %f;
"""
VFOLD = SEED + """
@P.y += 0.035 * abs(@P.x) / 0.15 + (noise(@P * 18 + s) - 0.5) * 0.006;
"""


def build(b):
    for i, (nm, mat_colour, band) in enumerate((("can_crushed_a", (0.85, 0.12, 0.12), WHITE),
                                                 ("can_crushed_b", (0.15, 0.35, 0.85), (0.98, 0.8, 0.15)))):
        body = b.wrangle(can(b, nm + "_lathe", mat_colour, band), CRUSH % (1 + i * 6), name=nm + "_crush")
        # Pull tab: a thin plate just off the lid (lid is at x = top after the crush/rotation).
        tb = prim(b, "box", nm + "_tab", type="polymesh", divrate1=2, divrate2=2, divrate3=2, sizex=0.003, sizey=0.012, sizez=0.02)
        tw = b.wrangle(tb, 'v@Cd = set(0.78, 0.79, 0.82); @P += set(getbbox_max(1).x + 0.0015, 0, 0.004);',
                       name=nm + "_tab_place")
        tw.setInput(1, body)
        m = b.net.createNode("merge", nm + "_parts")
        m.setInput(0, body)
        m.setInput(1, tw)
        item(b, i, nm, m, None, "can", cusp=50.0)
    cup_prof = [(0.0, 0.026, WHITE), (0.004, 0.029, WHITE), (0.1, 0.041, WHITE), (0.106, 0.044, (0.85, 0.15, 0.15)),
                (0.111, 0.043, (0.85, 0.15, 0.15)), (0.108, 0.039, WHITE), (0.012, 0.027, WHITE)]
    cup = prim(b, "python", "cup_lathe", python="PROFILE = %r\nCOLS = 12\nCAP_TOP = True\n" % (cup_prof,) + LATHE)
    item(b, 2, "cup", cup, CUP_SHAPE, "can", cusp=45.0)
    for i, (nm, sd) in enumerate((("paper_crumpled_a", 3), ("paper_crumpled_b", 11))):
        bx = prim(b, "box", nm + "_box", type="polymesh", divrate1=4, divrate2=4, divrate3=4, sizex=0.08, sizey=0.08, sizez=0.08)
        item(b, 3 + i, nm, bx, CRUMPLE_BOX % (sd, 0.042, 0.85), "paper", cusp=20.0)
    for i, (nm, mat) in enumerate((("chip_bag_a", "bag_yellow"), ("chip_bag_b", "bag_purple"))):
        bag = prim(b, "box", nm + "_box", type="polymesh", divrate1=4, divrate2=2, divrate3=6, sizex=0.14, sizey=0.035, sizez=0.2)
        item(b, 5 + i, nm, bag, PINCH % (5 + i * 9), mat, cusp=35.0)
    news = prim(b, "box", "news_box", type="polymesh", divrate1=7, divrate2=2, divrate3=5, sizex=0.3, sizey=0.01, sizez=0.4)
    item(b, 7, "newspaper", news, VFOLD, "paper", cusp=25.0)
    pizza = prim(b, "box", "pizza_box", type="polymesh", divrate1=2, divrate2=2, divrate3=2, sizex=0.34, sizey=0.045, sizez=0.34)
    item(b, 8, "pizza_box", b.bevel(pizza, 0.006, 1), None, "cardboard")
    nap = prim(b, "box", "napkin_box", type="polymesh", divrate1=4, divrate2=3, divrate3=4, sizex=0.1, sizey=0.1, sizez=0.1)
    item(b, 9, "napkin", nap, CRUMPLE_BOX % (23, 0.06, 0.35), "paper", cusp=20.0)
    b.finish(normals=False)


def build_scatter(b):
    net = b.net
    grid = prim(b, "grid", "ground", sizex=1.0, sizey=1.0, rows=2, cols=2)
    grid.parm("sizex").setExpression('ch("../areax")')
    grid.parm("sizey").setExpression('ch("../areaz")')
    sc = net.createNode("scatter", "points")
    sc.setInput(0, grid)
    sc.parm("npts").setExpression('ch("../count")')
    sc.parm("seed").setExpression('ch("../seed")')
    sc.parm("relaxpoints").set(1)
    names = ", ".join('"%s"' % n for n in ITEMS)
    w = b.wrangle(sc, """int s = chi("../seed");
string items[] = {%s};
s@item = items[int(rand(@ptnum * 7.31 + s) * len(items)) %% len(items)];
f@yaw = rand(@ptnum * 3.17 + s + 0.5) * 360.0;
f@pscale = fit01(rand(@ptnum * 5.91 + s + 0.25), 0.85, 1.15);
""" % names, name="attribs")
    out = net.createNode("output", "OUT")
    out.setInput(0, w)
    net.layoutChildren()


LAYOUT = hou.ToggleParmTemplate("layout", "Spread for Preview", default_value=False)
VARIANTS = [("litter_kit.glb", {"layout": 0}, None)]
PREVIEW_PARMS = {"layout": 1}
PREVIEW_VIEW = (30.0, 40.0)


def make():
    return hlib.make_asset("litter_kit", "litter_kit", "Skate Park Litter Kit", hlib.hda_parms(extra=[LAYOUT]), build)


def scatter_json(seed=3, count=40, area=(10.0, 10.0)):
    extra = [hou.IntParmTemplate("count", "Count", 1, default_value=(count,), min=1, max=500),
        hou.FloatParmTemplate("areax", "Area X", 1, default_value=(area[0],)),
        hou.FloatParmTemplate("areaz", "Area Z", 1, default_value=(area[1],))]
    node = hlib.make_asset("litter_scatter", "litter_scatter", "Skate Park Litter Scatter",
        hlib.hda_parms(seed=seed, extra=extra), build_scatter)
    pts = []
    for p in node.geometry().points():
        pos = p.position()
        pts.append({"item": p.attribValue("item"), "position": [round(pos[0], 3), round(pos[1], 3), round(pos[2], 3)],
            "yaw_deg": round(p.attribValue("yaw"), 1), "scale": round(p.attribValue("pscale"), 3)})
    path = os.path.join(hlib.PROPS, "litter_scatter_example.json")
    with open(path, "w") as f:
        json.dump({"area_m": list(area), "seed": seed, "points": pts}, f, indent=1)
    print("litter_scatter_example.json %d points" % len(pts))


if __name__ == "__main__":
    hlib.run(make, VARIANTS)
    scatter_json()
