"""Creepy warehouse kit. Usage: hython tools/houdini/kit_warehouse.py [--preview]

Writes assets/props/houdini/warehouse/<piece>.glb and kit.json (collision boxes). Metres, +Y up, front -Z, origin at
the base centre. Flat colour materials for the toon shader.
"""
import math

import hlib

MATS = {
    "container_red": (0.62, 0.16, 0.12), "container_blue": (0.16, 0.3, 0.5), "steel_dark": (0.22, 0.23, 0.25),
    "steel": (0.5, 0.52, 0.55), "wood_pallet": (0.66, 0.52, 0.34), "cardboard": (0.72, 0.56, 0.36),
    "safety_yellow": (0.95, 0.72, 0.1), "rubber": (0.07, 0.07, 0.08), "concrete": (0.5, 0.49, 0.47),
    "glass_dirty": (0.42, 0.5, 0.48), "drum_blue": (0.12, 0.28, 0.55), "drum_rust": (0.5, 0.27, 0.14),
    "hazard_black": (0.08, 0.08, 0.08), "seat": (0.15, 0.15, 0.17), "wire": (0.6, 0.62, 0.64),
    "door_grey": (0.42, 0.44, 0.45),
}


def container(colour):
    def fn(b):
        L, H, W = 6.06, 2.59, 2.44
        b.box("shell", (L, H, W), (0, H / 2, 0), colour, "body")
        for sz in (-1, 1):  # corrugated long sides
            for i in range(19):
                x = -L / 2 + 0.3 + i * 0.3
                b.box("rib%d_%d" % (i, sz + 1), (0.12, H - 0.3, 0.03), (x, H / 2, sz * (W / 2 + 0.012)), colour, "body")
        for i in range(8):  # roof ribs
            b.box("roofrib%d" % i, (0.08, 0.025, W - 0.2), (-L / 2 + 0.5 + i * 0.72, H + 0.012, 0), colour, "body")
        for sx in (-1, 1):  # corner castings
            for sy in (0, 1):
                for sz in (-1, 1):
                    b.box("corner%d%d%d" % (sx + 1, sy, sz + 1), (0.18, 0.12, 0.16),
                          (sx * (L / 2 - 0.08), 0.06 + sy * (H - 0.12), sz * (W / 2 - 0.07)), "steel_dark", "body")
        b.box("door_seam", (0.02, H - 0.3, 0.02), (L / 2 + 0.01, H / 2, 0), "steel_dark", "body")
        for i, z in enumerate((-0.85, -0.4, 0.4, 0.85)):  # door lock bars
            b.cyl("lockbar%d" % i, 0.022, H - 0.25, (L / 2 + 0.03, H / 2, z), "steel", "body", orient="y", cols=6, rows=1)
            b.box("handle%d" % i, (0.04, 0.05, 0.16), (L / 2 + 0.06, 1.2, z), "steel_dark", "body")
        b.box("fork_pocket_a", (0.25, 0.1, W + 0.02), (-1.0, 0.07, 0), "steel_dark", "body")
        b.box("fork_pocket_b", (0.25, 0.1, W + 0.02), (1.0, 0.07, 0), "steel_dark", "body")
    return fn


def pallet(b, p, y):
    for i in range(5):
        b.box("%s_top%d" % (p, i), (1.2, 0.022, 0.1), (0, y + 0.122, -0.45 + i * 0.225), "wood_pallet", "body")
    for i in range(3):
        b.box("%s_block%d" % (p, i), (1.2, 0.078, 0.1), (0, y + 0.072, -0.45 + i * 0.45), "wood_pallet", "body")
        b.box("%s_bottom%d" % (p, i), (1.2, 0.022, 0.12), (0, y + 0.011, -0.44 + i * 0.44), "wood_pallet", "body")


def pallet_stack(b):
    for k in range(4):
        pallet(b, "p%d" % k, k * 0.144)
    top = 4 * 0.144
    for i, (x, z, s) in enumerate(((-0.3, -0.25, 0.45), (0.28, -0.22, 0.4), (-0.25, 0.25, 0.42), (0.3, 0.26, 0.38))):
        b.box("carton%d" % i, (s * 1.2, s, s), (x, top + s / 2, z), "cardboard", "body", bevel=0.01, divs=1)
        b.box("tape%d" % i, (s * 1.21, 0.004, 0.05), (x, top + s + 0.002, z), "door_grey", "body")
    b.box("carton_top", (0.5, 0.35, 0.4), (0.05, top + 0.45 + 0.175, 0.0), "cardboard", "body", bevel=0.01, divs=1)


def forklift(b):
    # 2.3 m long, forks toward -Z.
    b.box("chassis", (1.1, 0.55, 1.9), (0, 0.5, 0.15), "safety_yellow", "body", bevel=0.06, divs=2)
    b.box("counterweight", (1.1, 0.75, 0.45), (0, 0.65, 1.05), "safety_yellow", "body", bevel=0.12, divs=2)
    b.box("seat", (0.5, 0.12, 0.45), (0, 0.85, 0.45), "seat", "body", bevel=0.03, divs=1)
    b.box("seat_back", (0.5, 0.45, 0.1), (0, 1.1, 0.7), "seat", "body", bevel=0.03, divs=1)
    b.cyl("steer_col", 0.03, 0.45, (0, 1.0, -0.15), "steel_dark", "body", orient="y", cols=6, rows=1)
    b.cyl("steer_wheel", 0.17, 0.03, (0, 1.24, -0.15), "rubber", "body", orient="y", cols=10, rows=1)
    for sx in (-1, 1):  # overhead guard
        for z in (-0.3, 0.85):
            b.box("guard_post%d_%d" % (sx + 1, int(z > 0)), (0.06, 1.35, 0.06), (sx * 0.5, 1.45, z), "hazard_black", "body")
    b.box("guard_roof", (1.08, 0.05, 1.25), (0, 2.13, 0.27), "hazard_black", "body")
    for i in range(4):
        b.box("guard_slat%d" % i, (1.0, 0.04, 0.05), (0, 2.17, -0.2 + i * 0.3), "hazard_black", "body")
    for sx in (-1, 1):  # mast and forks
        b.box("mast%d" % (sx + 1), (0.09, 2.3, 0.12), (sx * 0.38, 1.25, -0.9), "steel_dark", "body")
        b.box("fork_v%d" % (sx + 1), (0.1, 0.55, 0.05), (sx * 0.3, 0.38, -1.0), "steel_dark", "body")
        b.box("fork%d" % (sx + 1), (0.1, 0.05, 1.1), (sx * 0.3, 0.1, -1.55), "steel_dark", "body")
    b.box("carriage", (0.9, 0.35, 0.06), (0, 0.45, -0.98), "steel_dark", "body")
    b.box("mast_cross", (0.85, 0.1, 0.1), (0, 2.35, -0.9), "steel_dark", "body")
    for sx in (-1, 1):
        b.cyl("wheel_f%d" % (sx + 1), 0.3, 0.25, (sx * 0.5, 0.3, -0.55), "rubber", "body", cols=14, bevel=0.05, divs=1)
        b.cyl("hub_f%d" % (sx + 1), 0.15, 0.26, (sx * 0.5, 0.3, -0.55), "safety_yellow", "body", cols=8, rows=1)
        b.cyl("wheel_r%d" % (sx + 1), 0.22, 0.2, (sx * 0.48, 0.22, 0.95), "rubber", "body", cols=12, bevel=0.04, divs=1)
    b.box("beacon", (0.1, 0.08, 0.1), (0, 2.2, 0.75), "safety_yellow", "body")


def railing(b, p, length, y0, x, along="z"):
    """Posts every ~1 m plus top and mid rails along Z at x (deck at y0)."""
    n = max(2, int(round(length)) + 1)
    for i in range(n):
        z = -length / 2 + i * length / (n - 1)
        b.box("%s_post%d" % (p, i), (0.04, 1.05, 0.04), (x, y0 + 0.525, z), "safety_yellow", "body")
    b.box(p + "_top", (0.05, 0.05, length), (x, y0 + 1.05, 0), "safety_yellow", "body")
    b.box(p + "_mid", (0.03, 0.03, length), (x, y0 + 0.55, 0), "safety_yellow", "body")
    b.box(p + "_toe", (0.01, 0.1, length), (x, y0 + 0.05, 0), "steel_dark", "body")


def catwalk(b):
    # 3 m long (Z), 1 m wide, deck top at 3 m, legs to the ground.
    b.box("deck", (1.0, 0.06, 3.0), (0, 2.97, 0), "steel_dark", "body")
    for i in range(10):
        b.box("grate%d" % i, (0.96, 0.012, 0.02), (0, 3.006, -1.35 + i * 0.3), "steel", "body")
    for sx in (-1, 1):
        b.box("stringer%d" % (sx + 1), (0.08, 0.2, 3.0), (sx * 0.5, 2.84, 0), "steel_dark", "body")
        railing(b, "rail%d" % (sx + 1), 3.0, 3.0, sx * 0.48)
        for z in (-1.4, 1.4):
            b.box("leg%d_%d" % (sx + 1, int(z > 0)), (0.1, 2.74, 0.1), (sx * 0.45, 1.37, z), "steel_dark", "body")
    b.box("brace_a", (0.9, 0.06, 0.06), (0, 1.6, -1.4), "steel_dark", "body")
    b.box("brace_b", (0.9, 0.06, 0.06), (0, 1.6, 1.4), "steel_dark", "body")
    return [((0, 2.97, 0), (1.0, 0.06, 3.0)), ((-0.45, 1.37, 0), (0.1, 2.74, 3.0)), ((0.45, 1.37, 0), (0.1, 2.74, 3.0))]


def catwalk_stairs(b):
    # Rises 3 m over a 4 m run toward -Z (the bottom step at z = +2, the top landing at z = -2), 1 m wide.
    steps, rise, run = 15, 3.0, 4.0
    ang = math.degrees(math.atan2(rise, run))
    length = math.hypot(rise, run)
    for i in range(steps):
        y = (i + 0.5) * rise / steps
        z = run / 2 - (i + 0.5) * run / steps
        b.box("step%d" % i, (0.95, 0.04, run / steps + 0.02), (0, y, z), "steel_dark", "body")
    for sx in (-1, 1):
        b.box("stringer%d" % (sx + 1), (0.06, 0.22, length), (sx * 0.5, rise / 2, 0), "steel_dark", "body", rot=(ang, 0, 0))
        b.box("handrail%d" % (sx + 1), (0.05, 0.05, length), (sx * 0.5, rise / 2 + 0.95, 0), "safety_yellow", "body",
              rot=(ang, 0, 0))
        for i in range(4):
            t = (i + 0.5) / 4
            b.box("hpost%d_%d" % (sx + 1, i), (0.04, 0.95, 0.04), (sx * 0.5, rise * t + 0.47, run / 2 - run * t),
                  "safety_yellow", "body")
    return [((0, rise / 2, 0), (1.0, rise, run))]


def dock_door(b):
    # Wall 6 x 5 m with a 3.2 x 3.6 m roll-up door; the dock platform (1.2 m) in front (-Z).
    b.box("wall_l", (1.4, 5.0, 0.3), (-2.3, 2.5, 0), "concrete", "body")
    b.box("wall_r", (1.4, 5.0, 0.3), (2.3, 2.5, 0), "concrete", "body")
    b.box("wall_top", (3.2, 1.4, 0.3), (0, 4.3, 0), "concrete", "body")
    b.box("door", (3.2, 3.6, 0.06), (0, 1.8 + 0.0, 0.05), "door_grey", "body")
    for i in range(14):
        b.box("door_rib%d" % i, (3.18, 0.03, 0.03), (0, 0.15 + i * 0.25, 0.0), "steel_dark", "body")
    b.box("door_handle", (0.3, 0.05, 0.05), (0, 0.5, -0.02), "steel_dark", "body")
    for sx in (-1, 1):  # yellow and black guard posts and frame
        b.box("frame%d" % (sx + 1), (0.12, 3.7, 0.36), (sx * 1.66, 1.85, 0), "safety_yellow", "body")
        b.cyl("bollard%d" % (sx + 1), 0.1, 1.0, (sx * 1.9, 1.7, -0.6), "safety_yellow", "body", orient="y", cols=10)
        b.box("bumper%d" % (sx + 1), (0.25, 0.35, 0.12), (sx * 1.2, 1.0, -1.66), "rubber", "body")
    b.box("header", (3.44, 0.12, 0.36), (0, 3.66, 0), "safety_yellow", "body")
    b.box("dock", (6.0, 1.2, 1.6), (0, 0.6, -0.8), "concrete", "body")
    b.box("dock_edge", (6.0, 0.04, 0.1), (0, 1.2, -1.58), "safety_yellow", "body")
    b.box("dock_light", (0.3, 0.2, 0.25), (-2.5, 4.0, -0.25), "steel_dark", "body")
    return [((-2.3, 2.5, 0), (1.4, 5.0, 0.3)), ((2.3, 2.5, 0), (1.4, 5.0, 0.3)), ((0, 4.3, 0), (3.2, 1.4, 0.3)),
            ((0, 1.8, 0.05), (3.2, 3.6, 0.1)), ((0, 0.6, -0.8), (6.0, 1.2, 1.6))]


def skylight(b):
    # Roof skylight frame 4 x 3 m (lies flat; origin at its base centre), some panes missing, a few shards.
    for sz in (-1, 1):
        b.box("beam_x%d" % (sz + 1), (4.0, 0.15, 0.12), (0, 0.075, sz * 1.44), "steel_dark", "body")
    for sx in (-1, 1):
        b.box("beam_z%d" % (sx + 1), (0.12, 0.15, 3.0), (sx * 1.94, 0.075, 0), "steel_dark", "body")
    for i in range(1, 4):
        b.box("mullion_z%d" % i, (0.06, 0.1, 2.9), (-2.0 + i * 1.0, 0.05, 0), "steel_dark", "body")
    b.box("mullion_x", (3.9, 0.1, 0.06), (0, 0.05, 0), "steel_dark", "body")
    missing = {(0, 1), (2, 0), (3, 1)}
    for i in range(4):
        for j in range(2):
            if (i, j) in missing:
                continue
            b.box("pane%d%d" % (i, j), (0.94, 0.012, 1.38), (-1.5 + i * 1.0, 0.09, -0.72 + j * 1.44), "glass_dirty", "body")
    for k, (x, z, r) in enumerate(((-1.7, 0.4, 25), (-1.3, 1.1, -40), (0.6, -1.1, 60), (1.3, 0.5, -15))):
        b.box("shard%d" % k, (0.25, 0.01, 0.12), (x, 0.1, z), "glass_dirty", "body", rot=(8, r, 12), taper=(0.1, 1.0, 0.0))


def oil_drum(b):
    r, h = 0.29, 0.88
    b.cyl("drum", r, h, (0, h / 2, 0), "drum_blue", "body", orient="y", cols=16, rows=1)
    for y in (0.3, 0.58):
        b.cyl("rib%d" % int(y * 100), r + 0.012, 0.03, (0, y, 0), "drum_blue", "body", orient="y", cols=16, rows=1)
    for y in (0.012, h - 0.012):
        b.cyl("chime%d" % int(y * 100), r + 0.008, 0.024, (0, y, 0), "steel_dark", "body", orient="y", cols=16, rows=1)
    b.cyl("bung", 0.03, 0.02, (0.15, h + 0.01, 0.05), "steel_dark", "body", orient="y", cols=6, rows=1)
    b.box("rust_patch", (0.2, 0.15, 0.01), (0.0, 0.45, -r - 0.002), "drum_rust", "body", rot=(0, 0, 12))


def fence_panel(b):
    # Chain-link panel 3 m wide, 2.2 m tall, with barbed wire arms (faces -Z).
    for sx in (-1, 1):
        b.cyl("post%d" % (sx + 1), 0.035, 2.3, (sx * 1.5, 1.15, 0), "steel", "body", orient="y", cols=8, rows=1)
        b.box("arm%d" % (sx + 1), (0.04, 0.4, 0.04), (sx * 1.5, 2.45, 0.12), "steel", "body", rot=(-35, 0, 0))
    b.cyl("top_rail", 0.025, 3.0, (0, 2.15, 0), "steel", "body", orient="x", cols=6, rows=1)
    b.cyl("bottom_wire", 0.01, 3.0, (0, 0.05, 0), "steel", "body", orient="x", cols=4, rows=1)
    for i in range(12):  # diamond mesh as two sets of diagonal wires
        x = -1.5 + (i + 0.5) * 0.25
        for d, sgn in (("a", 1), ("b", -1)):
            b.box("wire_%s%d" % (d, i), (0.008, 2.25, 0.006), (x, 1.1, 0), "wire", "body", rot=(0, 0, sgn * 6.3))
    for k in range(3):
        b.cyl("barb%d" % k, 0.006, 3.0, (0, 2.36 + k * 0.1, 0.06 + k * 0.08), "wire", "body", orient="x", cols=4, rows=1)
    return [((0, 1.15, 0), (3.07, 2.3, 0.1))]


PIECES = [
    ("container_red", container("container_red")), ("container_blue", container("container_blue")),
    ("pallet_stack", pallet_stack), ("forklift", forklift), ("catwalk_module", catwalk),
    ("catwalk_stairs", catwalk_stairs), ("loading_dock_door", dock_door), ("skylight_frame_broken", skylight),
    ("oil_drum", oil_drum), ("chainlink_fence_panel", fence_panel),
]

if __name__ == "__main__":
    import os
    import sys
    hlib.run_kit("warehouse", PIECES, MATS)
    sys.stdout.flush()
    os._exit(0)
