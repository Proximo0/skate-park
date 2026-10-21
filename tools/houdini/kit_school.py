"""School kit. Usage: hython tools/houdini/kit_school.py [--preview]

Writes assets/props/houdini/school/<piece>.glb and kit.json (collision boxes). Metres, +Y up, front -Z, origin at the
base centre. Flat colour materials for the toon shader. The bus reuses car.py's body, arch, wheel and lamp parts.
"""
import math

import car
import hlib

MATS = {
    "body": (0.98, 0.76, 0.1), "locker_blue": (0.2, 0.42, 0.72), "locker_dark": (0.1, 0.16, 0.26),
    "table_top": (0.85, 0.85, 0.82), "bench_blue": (0.25, 0.5, 0.85), "concrete": (0.68, 0.66, 0.62),
    "soil": (0.3, 0.22, 0.15), "shrub": (0.25, 0.55, 0.22), "steel": (0.6, 0.62, 0.65), "alu": (0.78, 0.8, 0.82),
    "brick": (0.66, 0.3, 0.24), "trim_white": (0.93, 0.93, 0.9), "door_red": (0.75, 0.16, 0.14),
    "flag_blue": (0.2, 0.35, 0.8), "flag_white": (0.97, 0.97, 0.95), "stripe_black": (0.08, 0.08, 0.08),
    "stop_red": (0.85, 0.1, 0.1),
}


def lockers(b):
    # Bank of 6 lockers, 1.8 m wide x 1.85 m tall x 0.45 m deep, doors toward -Z.
    n, w, h, d = 6, 0.3, 1.85, 0.45
    b.box("cabinet", (n * w, h, d), (0, h / 2 + 0.1, 0), "locker_blue", "body")
    b.box("plinth", (n * w, 0.1, d - 0.04), (0, 0.05, 0.02), "locker_dark", "body")
    for i in range(n):
        x = -n * w / 2 + (i + 0.5) * w
        b.box("door%d" % i, (w - 0.02, h - 0.04, 0.02), (x, h / 2 + 0.1, -d / 2 - 0.01), "locker_blue", "body")
        for k in range(3):
            b.box("vent%d_%d" % (i, k), (w * 0.6, 0.012, 0.022), (x, h - 0.1 - k * 0.04, -d / 2 - 0.012), "locker_dark", "body")
        b.box("handle%d" % i, (0.03, 0.12, 0.03), (x + w * 0.3, 1.05, -d / 2 - 0.03), "steel", "body")
        b.box("number%d" % i, (0.06, 0.035, 0.022), (x, h - 0.28, -d / 2 - 0.012), "trim_white", "body")
    b.box("top_cap", (n * w + 0.02, 0.03, d + 0.02), (0, h + 0.115, 0), "locker_dark", "body")


def cafeteria_table(b):
    # Table 2.4 x 0.75 m top at 0.74 m with attached benches each side (one rigid unit).
    b.box("top", (2.4, 0.04, 0.75), (0, 0.74, 0), "table_top", "body", bevel=0.01, divs=1)
    b.box("top_edge", (2.42, 0.02, 0.77), (0, 0.715, 0), "steel", "body")
    for sz in (-1, 1):
        b.box("bench%d" % (sz + 1), (2.2, 0.04, 0.3), (0, 0.45, sz * 0.62), "bench_blue", "body", bevel=0.01, divs=1)
        for x in (-0.9, 0.9):
            b.box("bench_arm%d_%d" % (sz + 1, int(x > 0)), (0.05, 0.04, 0.62), (x, 0.43, sz * 0.31), "steel", "body")
    for x in (-0.9, 0.9):
        b.box("leg%d" % int(x > 0), (0.06, 0.72, 0.06), (x, 0.37, 0), "steel", "body")
        b.box("foot%d" % int(x > 0), (0.06, 0.04, 1.5), (x, 0.02, 0), "steel", "body")
    return [((0, 0.38, 0), (2.4, 0.76, 0.75)), ((0, 0.235, -0.62), (2.2, 0.47, 0.3)), ((0, 0.235, 0.62), (2.2, 0.47, 0.3))]


def planter_ledge(b):
    # Skateable planter: 4 x 1.2 m footprint, 0.5 m tall, steel edge coping on the long top edges, shrubs inside.
    L, W, H, t = 4.0, 1.2, 0.5, 0.15
    for sz in (-1, 1):
        b.box("wall_long%d" % (sz + 1), (L, H, t), (0, H / 2, sz * (W / 2 - t / 2)), "concrete", "body")
        b.box("coping%d" % (sz + 1), (L, 0.03, 0.05), (0, H + 0.0, sz * (W / 2 - 0.02)), "steel", "body")
    for sx in (-1, 1):
        b.box("wall_end%d" % (sx + 1), (t, H, W - 2 * t), (sx * (L / 2 - t / 2), H / 2, 0), "concrete", "body")
    b.box("soil", (L - 2 * t, 0.05, W - 2 * t), (0, H - 0.08, 0), "soil", "body")
    for i, x in enumerate((-1.3, -0.4, 0.5, 1.35)):
        hlib.sphere(b, "shrub%d" % i, (0.32, 0.28, 0.3), (x, H + 0.12, 0.02 * i), "shrub", "body", rows=5, cols=8,
                    snippet="vector n = noise(@P * 6 + %d); @P += (n - 0.5) * 0.08;" % i)
    return [((0, H / 2, 0), (L, H, W))]


def bike_rack(b):
    # Five inverted-U hoops on a base rail, 2.2 m long, 0.85 m tall.
    r, seg = 0.18, 6
    for i in range(5):
        x = -0.9 + i * 0.45
        for s in (-1, 1):
            b.cyl("hoop%d_leg%d" % (i, s + 1), 0.022, 0.68, (x, 0.34, s * r), "steel", "body", orient="y", cols=6, rows=1)
        for k in range(seg):
            a0 = math.pi * k / seg
            a1 = math.pi * (k + 1) / seg
            am = (a0 + a1) / 2
            c = (x, 0.68 + r * math.sin(am), r * math.cos(am))
            length = 2 * r * math.sin(math.pi / seg / 2) + 0.01
            b.box("hoop%d_arc%d" % (i, k), (0.04, 0.04, length), c, "steel", "body", rot=(-math.degrees(am) + 90, 0, 0))
    b.box("rail_a", (2.2, 0.04, 0.05), (0, 0.02, -r), "steel", "body")
    b.box("rail_b", (2.2, 0.04, 0.05), (0, 0.02, r), "steel", "body")
    return [((0, 0.43, 0), (2.0, 0.86, 0.42))]


def bleachers(b):
    # Five tiers, 6 m long, rising toward +Z (seating faces -Z), aluminium planks on side frames.
    tiers, step_y, step_z = 5, 0.42, 0.75
    for i in range(tiers):
        y = 0.45 + i * step_y
        z = i * step_z - 1.5
        b.box("seat%d" % i, (6.0, 0.05, 0.28), (0, y, z), "alu", "body")
        b.box("foot%d" % i, (6.0, 0.04, 0.3), (0, y - 0.25, z - 0.32), "alu", "body")
    ang = math.degrees(math.atan2(tiers * step_y, tiers * step_z))
    length = math.hypot(tiers * step_y, tiers * step_z)
    for x in (-2.9, -1.0, 1.0, 2.9):
        b.box("frame%d" % int(x * 10), (0.08, 0.1, length), (x, 0.25 + tiers * step_y / 2 - 0.2, -1.5 + tiers * step_z / 2 - 0.4),
              "steel", "body", rot=(-ang, 0, 0))
        b.box("post_back%d" % int(x * 10), (0.08, 0.45 + tiers * step_y, 0.08), (x, (0.45 + tiers * step_y) / 2, (tiers - 1) * step_z - 1.4),
              "steel", "body")
    for i in range(tiers - 1):  # a post under every tier, on each frame line
        y = 0.45 + i * step_y
        for x in (-2.9, -1.0, 1.0, 2.9):
            b.box("tier_post%d_%d" % (i, int(x * 10)), (0.06, y, 0.06), (x, y / 2, i * step_z - 1.5), "steel", "body")
    b.box("back_rail", (6.0, 0.05, 0.05), (0, 0.45 + tiers * step_y, (tiers - 1) * step_z - 1.4), "steel", "body")
    return [((0, (0.45 + tiers * step_y) / 2, -1.5 + (tiers - 1) * step_z / 2), (6.0, 0.45 + tiers * step_y, tiers * step_z))]


def school_bus(b):
    # 10.5 x 2.5 x 3.1 m bus, short hood toward -Z, window band with many pillars, black stripes, stop arm.
    p = "bus"
    car.lower_body(b, p, (2.5, 1.2, 10.5), (0, 1.0, 0.0), 0.12, 0.6, (-3.7, 3.3))
    b.box(p + "_upper", (2.5, 1.35, 9.4), (0, 2.27, 0.55), "body", "body", bevel=0.18, divs=2)
    b.box(p + "_hood", (2.3, 0.4, 1.3), (0, 1.65, -4.55), "body", "body", bevel=0.12, divs=2)
    for sx in (-1, 1):
        b.box("%s_windowband%d" % (p, sx + 1), (0.02, 0.62, 8.4), (sx * 1.255, 2.3, 0.9), "glass", "body")
        for i in range(13):
            b.box("%s_pillar%d_%d" % (p, sx + 1, i), (0.03, 0.62, 0.08), (sx * 1.27, 2.3, -3.3 + i * 0.7), "body", "body")
        for y in (1.55, 1.25):
            b.box("%s_stripe%d_%d" % (p, sx + 1, int(y * 100)), (0.02, 0.06, 10.4), (sx * 1.26, y, 0.0), "stripe_black", "body")
    b.box(p + "_windscreen", (2.2, 0.85, 0.03), (0, 2.25, -4.16), "glass", "body")
    b.box(p + "_rear_glass", (1.8, 0.6, 0.03), (0, 2.35, 5.26), "glass", "body")
    b.box(p + "_door", (0.03, 1.9, 0.8), (1.26, 1.65, -3.6), "glass", "body")
    b.box(p + "_roof_lights", (1.6, 0.12, 0.12), (0, 2.98, -3.75), "taillight", "body")
    b.box(p + "_grille", (1.2, 0.35, 0.03), (0, 1.25, -5.26), "trim", "body")
    car.lamps(b, p, 0.85, 1.35, -5.25, 5.25, w=0.22, h=0.2)
    car.plates(b, p, 0.8, -5.27, 5.27)
    b.box(p + "_bumper_f", (2.6, 0.25, 0.2), (0, 0.65, -5.3), "stripe_black", "body")
    b.box(p + "_bumper_r", (2.6, 0.25, 0.2), (0, 0.65, 5.3), "stripe_black", "body")
    b.cyl(p + "_stop_sign", 0.22, 0.03, (-1.32, 2.0, -3.0), "stop_red", "body", orient="x", cols=8, rows=1)
    car.mirrors(b, p, 1.4, 2.2, -4.4)
    car.wheels(b, p, 0.5, 0.32, 1.05, (-3.7, 3.3))
    return [((0, 1.55, 0.0), (2.5, 3.1, 10.5))]


FLAG = 'float t = (@P.x - 0.12) / 1.2; @P.z += 0.08 * sin(t * 7.0) * t;'


def flagpole(b):
    b.cyl("base", 0.45, 0.3, (0, 0.15, 0), "concrete", "body", orient="y", cols=12, rows=1)
    b.cyl("pole", 0.06, 8.0, (0, 4.3, 0), "alu", "body", orient="y", cols=8, rows=1, rad2=0.035)
    hlib.sphere(b, "finial", (0.07, 0.07, 0.07), (0, 8.35, 0), "body", "body", rows=5, cols=8)
    for i, (mat, y) in enumerate((("flag_blue", 7.85), ("flag_white", 7.65), ("flag_blue", 7.45))):
        fl = b.net.createNode("box", "flag%d" % i)
        for k, v in (("type", "polymesh"), ("sizex", 1.2), ("sizey", 0.2), ("sizez", 0.01), ("tx", 0.66), ("ty", y),
                     ("divrate1", 9), ("divrate2", 2), ("divrate3", 2)):
            fl.parm(k).set(v)
        b.tag(b.wrangle(fl, FLAG, name="flag%d_wave" % i), mat, "body")
    b.cyl("cleat", 0.02, 0.15, (0.07, 1.2, 0), "steel", "body", orient="y", cols=6, rows=1)
    return [((0, 0.15, 0), (0.9, 0.3, 0.9)), ((0, 4.3, 0), (0.12, 8.0, 0.12))]


def gym_facade(door):
    def fn(b):
        # 8 x 6 m brick facade module (0.4 m deep) toward -Z: double doors and steps, or a high window band.
        W, H, D = 8.0, 6.0, 0.4
        b.box("wall", (W, H, D), (0, H / 2, 0), "brick", "body")
        b.box("cornice", (W + 0.1, 0.35, D + 0.2), (0, H - 0.1, -0.05), "trim_white", "body")
        b.box("plinth", (W + 0.02, 0.4, D + 0.06), (0, 0.2, -0.02), "concrete", "body")
        for i in range(5):  # brick courses as faint white bands
            b.box("course%d" % i, (W, 0.03, 0.02), (0, 1.0 + i * 0.9, -D / 2 - 0.005), "trim_white", "body")
        b.box("window_band", (W - 1.2, 1.1, 0.04), (0, 4.4, -D / 2 - 0.01), "glass", "body")
        for i in range(7):
            b.box("mullion%d" % i, (0.08, 1.15, 0.06), (-3.4 + i * (6.8 / 6), 4.4, -D / 2 - 0.02), "trim_white", "body")
        if door:
            b.box("door_frame", (2.6, 2.7, 0.06), (0, 1.75, -D / 2 - 0.02), "trim_white", "body")
            for sx in (-1, 1):
                b.box("door%d" % (sx + 1), (1.15, 2.4, 0.05), (sx * 0.6, 1.6, -D / 2 - 0.05), "door_red", "body")
                b.box("door_glass%d" % (sx + 1), (0.5, 0.7, 0.02), (sx * 0.6, 2.2, -D / 2 - 0.085), "glass", "body")
                b.box("push_bar%d" % (sx + 1), (0.8, 0.05, 0.06), (sx * 0.6, 1.4, -D / 2 - 0.1), "steel", "body")
            for i in range(3):
                b.box("step%d" % i, (4.0 - i * 0.4, 0.15, 0.4), (0, 0.075 + i * 0.15, -D / 2 - 1.0 + i * 0.35), "concrete", "body")
        else:
            b.box("window_low", (W - 2.0, 1.2, 0.04), (0, 2.0, -D / 2 - 0.01), "glass", "body")
            for i in range(5):
                b.box("mullion_low%d" % i, (0.08, 1.25, 0.06), (-3.0 + i * 1.5, 2.0, -D / 2 - 0.02), "trim_white", "body")
            b.box("sill", (W - 1.8, 0.08, 0.2), (0, 1.36, -D / 2 - 0.08), "trim_white", "body")
        return [((0, H / 2, 0), (W, H, D))] + ([((0, 0.225, -D / 2 - 0.65), (4.0, 0.45, 1.1))] if door else [])
    return fn


PIECES = [
    ("lockers", lockers), ("cafeteria_table", cafeteria_table), ("planter_ledge", planter_ledge),
    ("bike_rack", bike_rack), ("bleachers", bleachers), ("school_bus", school_bus), ("flagpole", flagpole),
    ("gym_facade_door", gym_facade(True)), ("gym_facade_window", gym_facade(False)),
]

if __name__ == "__main__":
    import os
    import sys
    hlib.run_kit("school", PIECES, MATS)
    sys.stdout.flush()
    os._exit(0)
