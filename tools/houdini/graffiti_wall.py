"""Procedural graffiti wall section. Usage: hython tools/houdini/graffiti_wall.py

HDA skatepark::graffiti_wall: seed, size. Exports assets/props/houdini/graffiti_wall.glb:
6 x 3 x 0.3 m concrete wall with a coping cap on top (3.1 m overall), bevelled edges, chips knocked out of
the corners and the bottom front edge (Boolean, positions from the seed), weathering in point colour (Cd,
exported as COLOR_0) and UVs where the wall's front face (-Z) spans 0..1 for a decal texture; the back is mirrored.
"""
import hlib

WEATHER = """int s = chi("../seed");
float n = noise(@P * 1.3 + s) * 0.6 + noise(@P * 6.0 + s * 3) * 0.4;
float grime = fit(@P.y, 0.0, 0.7, 0.78, 1.0);
@Cd = set(1, 1, 1) * fit(n, 0.25, 0.75, 0.82, 1.0) * grime;
"""
UVS = """vector n = prim_normal(0, @primnum, set(0.5, 0.5, 0));
float u = (@P.x + 3.0) / 6.0;
float v = @P.y / 3.0;
if (abs(n.z) > 0.5) {
    if (n.z > 0) u = 1.0 - u;
    v@uv = set(u, v, 0);
} else if (abs(n.x) > 0.5) {
    v@uv = set((@P.z + 0.15) / 6.0, v, 0);
} else {
    v@uv = set(u, (@P.z + 0.15) / 6.0, 0);
}
"""


CHIPS = """
import random
geo = hou.pwd().geometry()
rnd = random.Random(hou.pwd().parent().parm("seed").eval())
geo.addAttrib(hou.attribType.Point, "orient", (0.0, 0.0, 0.0, 1.0))
geo.addAttrib(hou.attribType.Point, "scale", (1.0, 1.0, 1.0))
for k in range(9):
    sx, sz = rnd.choice((-1, 1)), rnd.choice((-1, 1))
    if k < 6:  # vertical corner edges
        c = (sx * 3.0, rnd.uniform(0.25, 2.8), sz * 0.15)
    else:  # bottom front edge, where boards and trucks hit
        c = (rnd.uniform(-2.6, 2.6), 0.0, -0.15)
    p = geo.createPoint()
    p.setPosition(c)
    q = hou.Quaternion(hou.hmath.buildRotate(rnd.uniform(0, 90), rnd.uniform(0, 90), rnd.uniform(0, 90)))
    p.setAttribValue("orient", tuple(q))
    p.setAttribValue("scale", (rnd.uniform(0.06, 0.12), rnd.uniform(0.08, 0.18), rnd.uniform(0.06, 0.12)))
"""
CAP = """int s = chi("../seed");
@Cd = set(1, 1, 1) * fit(noise(@P * 4.0 + s + 9), 0.25, 0.75, 0.9, 1.04);
v@uv = set((@P.x + 3.0) / 6.0, 0.0, 0);
"""


def build(b):
    box = b.net.createNode("box", "wall")
    box.parm("type").set("polymesh")
    for a, v in zip("xyz", (6.0, 3.0, 0.3)):
        box.parm("size" + a).set(v)
    box.parm("ty").set(1.5)
    for i, v in enumerate((25, 13, 2)):
        box.parm("divrate%d" % (i + 1)).set(v)
    bev = b.bevel(box, 0.035, 2)
    pts = b.net.createNode("python", "chip_points")
    pts.parm("python").set(CHIPS)
    cube = b.net.createNode("box", "chip_shape")
    cube.parm("type").set("polymesh")
    chips = b.net.createNode("copytopoints::2.0", "chips")
    chips.setInput(0, cube)
    chips.setInput(1, pts)
    boo = b.net.createNode("boolean", "knock_chips")
    boo.setInput(0, bev)
    boo.setInput(1, chips)
    boo.parm("booleanop").set("subtract")
    cd = b.wrangle(boo, WEATHER, name="weathering")
    uv = b.wrangle(cd, UVS, cls="vertex", name="decal_uvs")
    b.tag(uv, "concrete", "wall")
    cap = b.net.createNode("box", "coping")
    for k, v in (("type", "polymesh"), ("sizex", 6.12), ("sizey", 0.1), ("sizez", 0.42), ("ty", 3.05),
                 ("divrate1", 13), ("divrate2", 2), ("divrate3", 2)):
        cap.parm(k).set(v)
    capw = b.wrangle(b.bevel(cap, 0.02, 2), CAP, name="coping_look")
    b.tag(capw, "concrete", "wall")
    b.finish(cusp=40.0)


VARIANTS = [("graffiti_wall.glb", {}, None)]
PREVIEW_VIEW = (25.0, 12.0)


def make():
    return hlib.make_asset("graffiti_wall", "graffiti_wall", "Skate Park Graffiti Wall", hlib.hda_parms(), build)


if __name__ == "__main__":
    hlib.run(make, VARIANTS)
