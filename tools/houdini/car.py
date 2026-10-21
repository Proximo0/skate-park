"""Procedural stylised car: hatchback and pickup. Usage: hython tools/houdini/car.py

HDA skatepark::car (otls/skatepark_car.hda): style (0 hatchback, 1 pickup), seed, colour, size.
Exports assets/props/houdini/car_hatchback.glb and car_pickup.glb.
Wheels are separate meshes (wheel_fl, wheel_fr, wheel_rl, wheel_rr). Front faces -Z.
"""
import hou
import hlib


def wheels(b, prefix, r, w, x, z):
    for side, sx in (("l", -1), ("r", 1)):
        for end, sz in (("f", z[0]), ("r", z[1])):
            path = "wheel_%s%s" % (end, side)
            cx = sx * x
            b.cyl("%s_%s_tire" % (prefix, path), r, w, (cx, r, sz), "tire", path, cols=20, bevel=w * 0.22, divs=2)
            b.cyl("%s_%s_rim" % (prefix, path), r * 0.58, w + 0.02, (cx, r, sz), "rim", path, cols=12)


def lights(b, prefix, x, y, zf, zr, w=0.3, h=0.14):
    for sx in (-1, 1):
        b.box("%s_head%d" % (prefix, sx + 1), (w, h, 0.06), (sx * x, y, zf), "light", "body", bevel=0.02, divs=1)
        b.box("%s_tail%d" % (prefix, sx + 1), (w * 0.8, h, 0.06), (sx * x, y, zr), "taillight", "body", bevel=0.02, divs=1)


def mirrors(b, prefix, x, y, z):
    for sx in (-1, 1):
        b.box("%s_mirror%d" % (prefix, sx + 1), (0.16, 0.1, 0.06), (sx * x, y, z), "body", "body", bevel=0.02, divs=1)


def hatchback(b):
    # 4.0 x 1.7 x 1.5 m
    b.box("hb_lower", (1.7, 0.62, 4.0), (0, 0.6, 0), "body", "body", bevel=0.14, divs=3)
    b.box("hb_cabin", (1.56, 0.52, 2.4), (0, 1.16, 0.35), "glass", "body", bevel=0.06, divs=2, taper=(0.86, 0.78, 0.1))
    b.box("hb_roof", (1.38, 0.08, 1.92), (0, 1.46, 0.45), "body", "body", bevel=0.035, divs=2)
    b.box("hb_pillar", (1.5, 0.5, 0.12), (0, 1.15, 0.55), "body", "body", bevel=0.03, divs=1, taper=(0.9, 1.0, 0.0))
    b.box("hb_bumper_f", (1.76, 0.2, 0.2), (0, 0.42, -1.98), "trim", "body", bevel=0.05, divs=2)
    b.box("hb_bumper_r", (1.76, 0.2, 0.2), (0, 0.42, 1.98), "trim", "body", bevel=0.05, divs=2)
    b.box("hb_grille", (0.62, 0.14, 0.05), (0, 0.66, -2.01), "trim", "body", bevel=0.02, divs=1)
    lights(b, "hb", 0.56, 0.76, -2.0, 2.0)
    mirrors(b, "hb", 0.86, 1.0, -0.75)
    wheels(b, "hb", 0.33, 0.22, 0.76, (-1.3, 1.3))


def pickup(b):
    # 5.2 x 1.9 x 1.8 m
    b.box("pu_lower", (1.9, 0.7, 5.2), (0, 0.73, 0), "body", "body", bevel=0.14, divs=3)
    b.box("pu_cab", (1.76, 0.6, 1.7), (0, 1.38, -0.55), "glass", "body", bevel=0.06, divs=2, taper=(0.88, 0.8, 0.08))
    b.box("pu_roof", (1.58, 0.1, 1.42), (0, 1.73, -0.47), "body", "body", bevel=0.04, divs=2)
    for sx in (-1, 1):
        b.box("pu_bedside%d" % (sx + 1), (0.08, 0.4, 2.24), (sx * 0.91, 1.28, 1.47), "body", "body", bevel=0.02, divs=1)
    b.box("pu_tailgate", (1.9, 0.4, 0.08), (0, 1.28, 2.56), "body", "body", bevel=0.02, divs=1)
    b.box("pu_bedfront", (1.9, 0.4, 0.08), (0, 1.28, 0.38), "body", "body", bevel=0.02, divs=1)
    b.box("pu_bedliner", (1.74, 0.02, 2.1), (0, 1.09, 1.47), "trim", "body")
    b.box("pu_bumper_f", (1.96, 0.24, 0.22), (0, 0.5, -2.58), "metal", "body", bevel=0.05, divs=2)
    b.box("pu_bumper_r", (1.96, 0.24, 0.22), (0, 0.5, 2.58), "metal", "body", bevel=0.05, divs=2)
    b.box("pu_grille", (1.1, 0.26, 0.05), (0, 0.85, -2.61), "trim", "body", bevel=0.02, divs=1)
    lights(b, "pu", 0.68, 0.88, -2.6, 2.6, w=0.26, h=0.18)
    mirrors(b, "pu", 0.98, 1.26, -1.3)
    wheels(b, "pu", 0.4, 0.28, 0.84, (-1.7, 1.7))


def build(b):
    hatchback(b)
    m0 = b.merge("hatchback")
    pickup(b)
    m1 = b.merge("pickup")
    sw = b.net.createNode("switch", "style_switch")
    sw.setInput(0, m0)
    sw.setInput(1, m1)
    sw.parm("input").setExpression('ch("../style")')
    b.finish(src=sw)


STYLE = hou.MenuParmTemplate("style", "Body Style", ("hatchback", "pickup"), ("Hatchback", "Pickup"))
# (glb name, HDA parms, material colour overrides)
VARIANTS = [
    ("car_hatchback.glb", {"style": 0, "colour": (0.95, 0.35, 0.2)}, {"body": (0.95, 0.35, 0.2)}),
    ("car_pickup.glb", {"style": 1, "colour": (0.2, 0.55, 0.85)}, {"body": (0.2, 0.55, 0.85)}),
]


def make():
    return hlib.make_asset("car", "car", "Skate Park Car",
        hlib.hda_parms(colour=(0.85, 0.22, 0.16), extra=[STYLE]), build)


if __name__ == "__main__":
    hlib.run(make, VARIANTS)
