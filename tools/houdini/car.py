"""Procedural stylised car: hatchback, pickup and surf van. Usage: hython tools/houdini/car.py

HDA skatepark::car (otls/skatepark_car.hda): style (0 hatchback, 1 pickup, 2 surf van), seed, colour, size.
Exports assets/props/houdini/car_hatchback.glb, car_pickup.glb and car_surfvan.glb.
Wheel arches are cut with Booleans. The greenhouse has separate windscreen, side and rear glass between A/B/C
pillars. Wheels are separate meshes (wheel_fl, wheel_fr, wheel_rl, wheel_rr) with tyre sidewalls, a rim and spokes.
Front faces -Z.
"""
import math

import hou
import hlib


def wheels(b, p, r, w, x, zs):
    for side, sx in (("l", -1), ("r", 1)):
        for end, z in zip(("f", "r"), zs):
            path = "wheel_%s%s" % (end, side)
            n = "%s_%s" % (p, path)
            cx = sx * x
            b.cyl(n + "_tire", r, w, (cx, r, z), "tire", path, cols=20, bevel=w * 0.28, divs=2)
            face = cx + sx * (w * 0.5 - 0.012)
            b.cyl(n + "_rim", r * 0.6, 0.03, (face - sx * 0.01, r, z), "rim", path, cols=12)
            b.cyl(n + "_hub", r * 0.16, 0.05, (face, r, z), "metal", path, cols=8, rows=1)
            for k in range(5):
                a = 2 * math.pi * k / 5
                c = (face + sx * 0.004, r + r * 0.33 * math.cos(a), z + r * 0.33 * math.sin(a))
                b.box("%s_spoke%d" % (n, k), (0.02, r * 0.42, 0.045), c, "metal", path, rot=(math.degrees(a), 0, 0))


def lower_body(b, p, size, center, bevel, arch_r, arch_zs):
    """Bevelled lower body with both wheel arches cut out by a Boolean (the arch liners come out dark)."""
    body = b.box(p + "_lower", size, center, "body", "body", bevel=bevel, divs=3, tag=False)
    m = b.net.createNode("merge", p + "_arches")
    for i, z in enumerate(arch_zs):
        t = b.net.createNode("tube", "%s_arch%d" % (p, i))
        for k, v in (("type", "poly"), ("orient", "x"), ("cap", 1), ("rad1", arch_r), ("rad2", arch_r),
                     ("height", size[0] + 0.4), ("cols", 18), ("tz", z), ("ty", arch_r * 0.62)):
            t.parm(k).set(v)
        m.setInput(i, t)
    liner = b.tag(m, "trim", "body", keep=False)
    boo = b.net.createNode("boolean", p + "_cut_arches")
    boo.setInput(0, body)
    boo.setInput(1, liner)
    boo.parm("booleanop").set("subtract")
    w = b.wrangle(boo, 'if (s@shop_materialpath == "") s@shop_materialpath = "/mat/body"; s@path = "body";',
                  cls="primitive", name=p + "_body_tag")
    b.parts.append(w)  # the Boolean keeps B's (dark liner) material on the cut faces


def greenhouse(b, p, w, h, length, y0, z, taper, roof_mat="body", b_pillar=0.5):
    """Glass cabin with A, B and C pillars, a beltline and a roof, all following the same taper."""
    tf = (0.0, y0, z, y0 + h)
    yc = y0 + h * 0.5
    b.box(p + "_glass", (w, h, length), (0, yc, z), "glass", "body", taper=taper, taper_from=tf)
    for sx in (-1, 1):
        x = sx * (w * 0.5 + 0.004)
        for name, zz, d in (("a", z - length * 0.5 + 0.05, 0.1), ("b", z - length * 0.5 + length * b_pillar, 0.09),
                            ("c", z + length * 0.5 - 0.09, 0.18)):
            b.box("%s_pillar_%s%d" % (p, name, sx + 1), (0.05, h, d), (x, yc, zz), "body", "body",
                  taper=taper, taper_from=tf)
    b.box(p + "_belt", (w + 0.03, 0.05, length + 0.03), (0, y0 + 0.02, z), "body", "body")
    top = (w * taper[0], length * taper[1])
    b.box(p + "_roof", (top[0] + 0.04, 0.07, top[1] + 0.06), (0, y0 + h + 0.03, z + taper[2]), roof_mat, "body",
          bevel=0.03, divs=2)


def lamps(b, p, x, y, z_front, z_rear, w=0.3, h=0.13):
    """Head and tail lights set inside a dark bezel."""
    for sx in (-1, 1):
        for name, z, mat, ww in (("head", z_front, "light", w), ("tail", z_rear, "taillight", w * 0.8)):
            dz = -1 if z < 0 else 1
            b.box("%s_%s_bezel%d" % (p, name, sx + 1), (ww + 0.04, h + 0.04, 0.03), (sx * x, y, z + dz * 0.005),
                  "trim", "body", bevel=0.01, divs=1)
            b.box("%s_%s%d" % (p, name, sx + 1), (ww, h, 0.03), (sx * x, y, z + dz * 0.012), mat, "body")


def plates(b, p, y, z_front, z_rear):
    b.box(p + "_plate_f", (0.5, 0.11, 0.02), (0, y, z_front - 0.01), "plate", "body")
    b.box(p + "_plate_r", (0.5, 0.11, 0.02), (0, y, z_rear + 0.01), "plate", "body")


def doors(b, p, x, y0, y1, seams, handles):
    """Door seams as thin dark lines just proud of the skin, plus door handles."""
    for sx in (-1, 1):
        for i, z in enumerate(seams):
            b.box("%s_seam%d_%d" % (p, i, sx + 1), (0.006, y1 - y0, 0.012), (sx * x, (y0 + y1) * 0.5, z), "trim", "body")
        for i, z in enumerate(handles):
            b.box("%s_handle%d_%d" % (p, i, sx + 1), (0.012, 0.03, 0.13), (sx * (x + 0.004), y1 - 0.08, z), "trim", "body")


def mirrors(b, p, x, y, z):
    for sx in (-1, 1):
        b.box("%s_mirror_arm%d" % (p, sx + 1), (0.08, 0.03, 0.04), (sx * (x - 0.04), y - 0.02, z), "trim", "body")
        b.box("%s_mirror%d" % (p, sx + 1), (0.1, 0.09, 0.05), (sx * x, y, z), "body", "body", bevel=0.015, divs=1)


def hatchback(b):
    # 4.0 x 1.7 x 1.5 m
    p = "hb"
    lower_body(b, p, (1.7, 0.66, 4.0), (0, 0.6, 0), 0.14, 0.4, (-1.3, 1.3))
    greenhouse(b, p, 1.56, 0.5, 2.3, 0.93, 0.35, (0.86, 0.8, 0.12))
    b.box(p + "_bumper_f", (1.76, 0.18, 0.16), (0, 0.4, -1.97), "trim", "body", bevel=0.05, divs=2)
    b.box(p + "_bumper_r", (1.76, 0.18, 0.16), (0, 0.4, 1.97), "trim", "body", bevel=0.05, divs=2)
    b.box(p + "_grille", (0.6, 0.12, 0.03), (0, 0.66, -2.0), "trim", "body")
    lamps(b, p, 0.58, 0.76, -2.0, 2.0)
    plates(b, p, 0.42, -2.06, 2.06)
    doors(b, p, 0.852, 0.42, 0.9, (-0.7, 0.45), (0.0,))
    mirrors(b, p, 0.88, 1.0, -0.68)
    wheels(b, p, 0.32, 0.21, 0.75, (-1.3, 1.3))


def pickup(b):
    # 5.2 x 1.9 x 1.8 m
    p = "pu"
    lower_body(b, p, (1.9, 0.72, 5.2), (0, 0.74, 0), 0.14, 0.5, (-1.7, 1.7))
    greenhouse(b, p, 1.76, 0.58, 1.7, 1.1, -0.55, (0.88, 0.82, 0.08), b_pillar=0.62)
    for sx in (-1, 1):
        b.box("%s_bedside%d" % (p, sx + 1), (0.08, 0.4, 2.24), (sx * 0.91, 1.3, 1.47), "body", "body", bevel=0.02, divs=1)
    b.box(p + "_tailgate", (1.9, 0.4, 0.08), (0, 1.3, 2.56), "body", "body", bevel=0.02, divs=1)
    b.box(p + "_bedfront", (1.9, 0.4, 0.08), (0, 1.3, 0.38), "body", "body", bevel=0.02, divs=1)
    b.box(p + "_bedliner", (1.74, 0.02, 2.1), (0, 1.11, 1.47), "trim", "body")
    b.box(p + "_bumper_f", (1.98, 0.22, 0.2), (0, 0.5, -2.58), "metal", "body", bevel=0.05, divs=2)
    b.box(p + "_bumper_r", (1.98, 0.22, 0.2), (0, 0.5, 2.58), "metal", "body", bevel=0.05, divs=2)
    b.box(p + "_grille", (1.1, 0.26, 0.03), (0, 0.86, -2.6), "trim", "body")
    for i in range(3):
        b.box("%s_grille_bar%d" % (p, i), (1.12, 0.03, 0.04), (0, 0.78 + i * 0.08, -2.61), "metal", "body")
    lamps(b, p, 0.7, 0.88, -2.6, 2.6, w=0.24, h=0.17)
    plates(b, p, 0.5, -2.69, 2.69)
    doors(b, p, 0.952, 0.48, 1.08, (-1.38, 0.0), (-0.1,))
    mirrors(b, p, 0.98, 1.24, -1.28)
    wheels(b, p, 0.4, 0.28, 0.84, (-1.7, 1.7))


def surfvan(b):
    # Boxy two-tone camper, 4.6 x 1.85 x 2.0 m, with a roof rack and a surfboard (about 2.2 m tall overall).
    p = "sv"
    lower_body(b, p, (1.85, 0.78, 4.5), (0, 0.69, 0), 0.16, 0.42, (-1.45, 1.45))
    b.box(p + "_upper", (1.85, 0.9, 4.5), (0, 1.53, 0.0), "body2", "body", bevel=0.16, divs=3,
          taper=(0.94, 0.97, 0.0))
    for sx in (-1, 1):  # side window band, slightly proud of the upper body
        b.box("%s_side_glass%d" % (p, sx + 1), (0.02, 0.4, 3.2), (sx * 0.9, 1.6, 0.35), "glass", "body")
    b.box(p + "_rear_glass", (1.4, 0.4, 0.02), (0, 1.6, 2.25), "glass", "body")
    for sx in (-1, 1):  # split windscreen
        b.box("%s_screen%d" % (p, sx + 1), (0.68, 0.45, 0.02), (sx * 0.37, 1.6, -2.25), "glass", "body")
    b.box(p + "_screen_bar", (0.06, 0.47, 0.03), (0, 1.6, -2.255), "body2", "body")
    b.box(p + "_nose_v", (1.2, 0.36, 0.03), (0, 1.08, -2.255), "body2", "body", taper=(0.35, 1.0, 0.0), taper_below=True)
    for sx in (-1, 1):
        for name, r, mat, dz in (("bezel", 0.1, "trim", 0.0), ("lamp", 0.08, "light", -0.01)):
            b.cyl("%s_%s%d" % (p, name, sx + 1), r, 0.03, (sx * 0.64, 0.86, -2.26 + dz), mat, "body",
                  orient="z", cols=12, rows=1)
        b.box("%s_tail%d" % (p, sx + 1), (0.12, 0.22, 0.03), (sx * 0.78, 0.95, 2.26), "taillight", "body")
    b.box(p + "_bumper_f", (1.9, 0.14, 0.16), (0, 0.42, -2.28), "metal", "body", bevel=0.04, divs=2)
    b.box(p + "_bumper_r", (1.9, 0.14, 0.16), (0, 0.42, 2.28), "metal", "body", bevel=0.04, divs=2)
    plates(b, p, 0.6, -2.27, 2.27)
    doors(b, p, 0.93, 0.36, 1.06, (-1.6, -0.75, 0.55), (-1.0, 0.45))
    mirrors(b, p, 0.98, 1.4, -2.0)
    # Roof rack: two cross bars on feet and two side rails.
    for z in (-1.1, 1.1):
        b.cyl("%s_rack_bar%d" % (p, int(z > 0)), 0.02, 1.7, (0, 2.05, z), "metal", "body", orient="x", cols=6, rows=1)
        for sx in (-1, 1):
            b.box("%s_rack_foot%d_%d" % (p, int(z > 0), sx + 1), (0.05, 0.1, 0.06), (sx * 0.78, 2.0, z), "trim", "body")
    for sx in (-1, 1):
        b.cyl("%s_rack_rail%d" % (p, sx + 1), 0.018, 2.4, (sx * 0.8, 2.07, 0), "metal", "body", orient="z", cols=6, rows=1)
    # Surfboard: a flattened ellipsoid with a pointed nose (toward -Z), a deck stripe and a fin.
    sph = b.net.createNode("sphere", p + "_board")
    for k, v in (("type", "polymesh"), ("rows", 8), ("cols", 18), ("radx", 0.27), ("rady", 0.04), ("radz", 1.12)):
        sph.parm(k).set(v)
    shape = b.wrangle(sph, "@P.x *= 1 - 0.55 * smooth(0.0, 1.12, -@P.z); @P.y += 0.04 * pow(abs(@P.z) / 1.12, 3);"
                           " @P += set(0, 2.12, 0);", name=p + "_board_shape")
    b.tag(shape, "surfboard", "surfboard")
    b.box(p + "_board_stripe", (0.06, 0.012, 1.6), (0, 2.157, 0.1), "body", "surfboard")
    b.box(p + "_board_fin", (0.015, 0.1, 0.12), (0, 2.05, 0.95), "trim", "surfboard")
    wheels(b, p, 0.34, 0.22, 0.82, (-1.45, 1.45))


def build(b):
    merges = []
    for fn, name in ((hatchback, "hatchback"), (pickup, "pickup"), (surfvan, "surfvan")):
        fn(b)
        merges.append(b.merge(name))
    sw = b.net.createNode("switch", "style_switch")
    for i, m in enumerate(merges):
        sw.setInput(i, m)
    sw.parm("input").setExpression('ch("../style")')
    b.finish(src=sw)


STYLE = hou.MenuParmTemplate("style", "Body Style", ("hatchback", "pickup", "surfvan"),
                             ("Hatchback", "Pickup", "Surf Van"))
# (glb name, HDA parms, material colour overrides)
VARIANTS = [
    ("car_hatchback.glb", {"style": 0, "colour": (0.95, 0.35, 0.2)}, {"body": (0.95, 0.35, 0.2)}),
    ("car_pickup.glb", {"style": 1, "colour": (0.2, 0.55, 0.85)}, {"body": (0.2, 0.55, 0.85)}),
    ("car_surfvan.glb", {"style": 2, "colour": (0.2, 0.72, 0.66)}, {"body": (0.2, 0.72, 0.66)}),
]


def make():
    return hlib.make_asset("car", "car", "Skate Park Car",
                           hlib.hda_parms(colour=(0.85, 0.22, 0.16), extra=[STYLE]), build)


if __name__ == "__main__":
    hlib.run(make, VARIANTS)
