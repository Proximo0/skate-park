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
CRUSH = SEED + """
float t = fit(@P.y, -0.061, 0.061, 0, 1);
float bulge = 1 + 0.35 * sin(t * PI) * (t > 0.12 && t < 0.88);
@P.x *= bulge; @P.z *= bulge; @P.y *= 0.5;
@P += (vector(noise(@P * 45 + s + %d)) - 0.5) * 0.02;
@P = set(@P.y, @P.x, @P.z);
"""
CRUMPLE = SEED + """
float n = noise(@P * 38 + s + %d);
@P *= 1 + (n - 0.5) * 0.8;
@P.y *= %f;
"""
PINCH = SEED + """
float fz = abs(@P.z) / 0.1;
@P.y *= 1 - smooth(0.55, 1.0, fz) * 0.9;
@P.y += (noise(@P * 30 + s + %d) - 0.5) * 0.012;
@P.x *= 1 - smooth(0.7, 1.0, fz) * 0.15;
"""
FOLD = SEED + """
@P.y += 0.025 * abs(sin(@P.x * 9.0)) + (noise(@P * 20 + s) - 0.5) * 0.01;
"""
CUP = SEED + """
@P += (vector(noise(@P * 30 + s)) - 0.5) * 0.008;
@P = set(@P.y, @P.x, @P.z);
"""


def item(b, i, name, src, snippet, mat):
    n = b.wrangle(src, snippet, name=name + "_shape") if snippet else src
    rest = b.wrangle(n, ('@P.y -= getbbox_min(0).y; @P.x += ch("../layout") * %.2f; @P.z += ch("../layout") * %.2f;'
        % ((i % 5 - 2) * 0.4, (i // 5 - 0.5) * 0.45)),
        name=name + "_rest")
    b.tag(rest, mat, name)


def prim(b, kind, name, **parms):
    n = b.net.createNode(kind, name)
    for k, v in parms.items():
        if isinstance(v, tuple):
            n.parmTuple(k).set(v)
        else:
            n.parm(k).set(v)
    return n


def can(b, name):
    return prim(b, "tube", name, type="poly", orient="y", cap=1, rad1=0.033, rad2=0.033, height=0.122, cols=10, rows=5)


def build(b):
    item(b, 0, "can_crushed_a", can(b, "can_a"), CRUSH % 1, "can_red")
    item(b, 1, "can_crushed_b", can(b, "can_b"), CRUSH % 7, "can_blue")
    cup = prim(b, "tube", "cup_tube", type="poly", orient="y", cap=1, rad1=0.03, rad2=0.042, height=0.11, cols=12, rows=3)
    item(b, 2, "cup", cup, CUP, "paper")
    for i, (nm, sd) in enumerate((("paper_crumpled_a", 3), ("paper_crumpled_b", 11))):
        sph = prim(b, "sphere", nm + "_sph", type="polymesh", rows=7, cols=9, radx=0.045, rady=0.045, radz=0.045)
        item(b, 3 + i, nm, sph, CRUMPLE % (sd, 0.85), "paper")
    for i, (nm, mat) in enumerate((("chip_bag_a", "bag_yellow"), ("chip_bag_b", "bag_purple"))):
        bag = prim(b, "box", nm + "_box", type="polymesh", divrate1=4, divrate2=2, divrate3=6, sizex=0.14, sizey=0.035, sizez=0.2)
        item(b, 5 + i, nm, bag, PINCH % (5 + i * 9), mat)
    news = prim(b, "box", "news_box", type="polymesh", divrate1=7, divrate2=2, divrate3=5, sizex=0.3, sizey=0.01, sizez=0.4)
    item(b, 7, "newspaper", news, FOLD, "paper")
    pizza = prim(b, "box", "pizza_box", type="polymesh", sizex=0.34, sizey=0.045, sizez=0.34)
    item(b, 8, "pizza_box", b.bevel(pizza, 0.006, 1), None, "cardboard")
    nap = prim(b, "sphere", "napkin_sph", type="polymesh", rows=6, cols=8, radx=0.06, rady=0.06, radz=0.06)
    item(b, 9, "napkin", nap, CRUMPLE % (23, 0.35), "paper")
    b.finish(cusp=50.0)


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
