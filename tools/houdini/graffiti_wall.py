"""Procedural graffiti wall section. Usage: hython tools/houdini/graffiti_wall.py

HDA skatepark::graffiti_wall: seed, size. Exports assets/props/houdini/graffiti_wall.glb:
6 x 3 x 0.3 m concrete wall, bevelled edges, weathering in point colour (Cd, exported as
COLOR_0) and UVs where the front face (-Z) spans 0..1 for a decal texture; the back is mirrored.
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


def build(b):
    box = b.net.createNode("box", "wall")
    box.parm("type").set("polymesh")
    for a, v in zip("xyz", (6.0, 3.0, 0.3)):
        box.parm("size" + a).set(v)
    box.parm("ty").set(1.5)
    for i, v in enumerate((25, 13, 2)):
        box.parm("divrate%d" % (i + 1)).set(v)
    bev = b.bevel(box, 0.035, 2)
    cd = b.wrangle(bev, WEATHER, name="weathering")
    uv = b.wrangle(cd, UVS, cls="vertex", name="decal_uvs")
    b.tag(uv, "concrete", "wall")
    b.finish(cusp=40.0)


VARIANTS = [("graffiti_wall.glb", {}, None)]
PREVIEW_VIEW = (25.0, 12.0)


def make():
    return hlib.make_asset("graffiti_wall", "graffiti_wall", "Skate Park Graffiti Wall", hlib.hda_parms(), build)


if __name__ == "__main__":
    hlib.run(make, VARIANTS)
