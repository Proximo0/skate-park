"""Procedural base body (smooth featureless mannequin) for the skater, built in Blender and exported to glTF.

Run:  /tmp/lead/bpyenv/bin/python tools/blender/base_body.py --out assets/characters [--body female|male|both]
      [--rig tools/blender/rig_rest.json] [--blend <dir>]

Pipeline (deterministic, no GUI):
  1. Read the skeleton constants from game/skater/placeholder_skater.gd, the region list from
     game/skater/skinned_body.gd and the joint dump from tools/blender/rig_rest.json (tools/blender/dump_rig.gd).
     The dump must agree with the constants, or the script stops (re-run the dump).
  2. Box-model a low-poly quad cage in the model pose (straight legs, A-pose arms at SkinnedBody.NEUTRAL_ARM):
     elliptical torso rings (24 around) with the legs split off at the crotch and 10-sided arm sockets,
     12..14-sided limb rings, a flat mitten hand with a thumb, simple feet, an open collar ring at the neck top.
  3. Subdivision Surface (level 1, limit surface), then smooth analytic forms on the dense mesh (the bust, a
     faint pectoral plane on the male).
  4. Regions: every face gets one body region (SkinnedBody.REGIONS) -> vertex groups of the same names and the
     region index in the second UV map (glTF TEXCOORD_1 = Godot UV2.x).
  5. Armature: one bone per SkaterPoser.JOINTS joint (same names and parents, heads at the model-pose joint
     positions), BustL/BustR (female) at the BodySway_Bust pivots, a non-deforming HeadTop marker at the crown.
     Automatic (heat) weights, then fix-ups: smooth elbow/knee blends, wrist/ankle kept off the hand/foot bones,
     bust on Chest + BustL/R, neck blend, no cross-limb weights, 4 influences, normalized.
  6. Export GLB: Y up, metres, skinned mesh + armature, smooth normals.

Coordinates: everything is computed in Godot body space (Y up, the body faces -Z, Left = -X) and converted to
Blender (Z up) only when the mesh and bones are created: blender = (x, -z, y). The glTF exporter's +Y-up
conversion turns it back into Godot space.
"""

import argparse
import json
import math
import os
import re
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SKATER_GD = os.path.join(ROOT, "game", "skater", "placeholder_skater.gd")
SKINNED_GD = os.path.join(ROOT, "game", "skater", "skinned_body.gd")
POSER_GD = os.path.join(ROOT, "game", "skater", "skater_poser.gd")
DEFAULT_RIG = os.path.join(ROOT, "tools", "blender", "rig_rest.json")

HEAD_TOP = 1.61  # crown height (m), the target standing height
PARTS = ["torso", "neck", "arm_L", "arm_R", "hand_L", "hand_R", "leg_L", "leg_R", "foot_L", "foot_R"]


# --- reading the game's constants ------------------------------------------------------------------------------

def read_constants(path=SKATER_GD):
    src = open(path, encoding="utf-8").read()
    out = {}
    for m in re.finditer(r"^const\s+(\w+)\s*:\s*float\s*=\s*([-0-9.]+)", src, re.M):
        out[m.group(1)] = float(m.group(2))
    m = re.search(r"^const\s+SHOULDER\s*:\s*Vector2\s*=\s*Vector2\(\s*([-0-9.]+)\s*,\s*([-0-9.]+)\s*\)", src, re.M)
    out["SHOULDER"] = (float(m.group(1)), float(m.group(2)))
    skins = re.findall(r'"skin"\s*:\s*Color\(\s*([-0-9.]+)\s*,\s*([-0-9.]+)\s*,\s*([-0-9.]+)\s*\)', src)
    out["SKIN_female"] = tuple(float(c) for c in skins[0])
    out["SKIN_male"] = tuple(float(c) for c in skins[1]) if len(skins) > 1 else out["SKIN_female"]
    need = ["HIP_HEIGHT", "UPPER_LEG", "LOWER_LEG", "ANKLE_HEIGHT", "HIP_SPREAD", "UPPER_ARM", "LOWER_ARM",
            "SPINE_UP", "CHEST_UP", "NECK_UP", "HEAD_UP"]
    missing = [k for k in need if k not in out]
    if missing:
        sys.exit("base_body: constants missing from %s: %s" % (path, missing))
    return out


def read_regions(path=SKINNED_GD):
    src = open(path, encoding="utf-8").read()
    block = re.search(r"const REGIONS: PackedStringArray = \[(.*?)\]", src, re.S).group(1)
    return re.findall(r'"(\w+)"', block)


def read_neutral_arm(path=SKINNED_GD):
    src = open(path, encoding="utf-8").read()
    return float(re.search(r"const NEUTRAL_ARM: float = ([0-9.]+)", src).group(1))


def read_joints(path=POSER_GD):
    src = open(path, encoding="utf-8").read()
    block = re.search(r"const JOINTS: PackedStringArray = \[(.*?)\]", src, re.S).group(1)
    return re.findall(r'"(\w+)"', block)


def load_rig(path, body, C, joints, neutral_arm):
    rig = json.load(open(path, encoding="utf-8"))
    nodes = rig["bodies"][body]["nodes"]
    # Stale-dump guard: the dump must match the constants the game uses now.
    expect = {
        "Hips": (0.0, C["HIP_HEIGHT"], 0.0),
        "Spine": (0.0, C["HIP_HEIGHT"] + C["SPINE_UP"], 0.0),
        "Chest": (0.0, C["HIP_HEIGHT"] + C["SPINE_UP"] + C["CHEST_UP"], 0.0),
        "Neck": (0.0, C["HIP_HEIGHT"] + C["SPINE_UP"] + C["CHEST_UP"] + C["NECK_UP"], 0.0),
        "Head": (0.0, C["HIP_HEIGHT"] + C["SPINE_UP"] + C["CHEST_UP"] + C["NECK_UP"] + C["HEAD_UP"], 0.0),
        "LeftUpperLeg": (-C["HIP_SPREAD"], C["HIP_HEIGHT"], 0.0),
        "LeftLowerLeg": (-C["HIP_SPREAD"], C["HIP_HEIGHT"] - C["UPPER_LEG"], 0.0),
        "LeftFoot": (-C["HIP_SPREAD"], C["HIP_HEIGHT"] - C["UPPER_LEG"] - C["LOWER_LEG"], 0.0),
        "LeftUpperArm": (-C["SHOULDER"][0], C["HIP_HEIGHT"] + C["SPINE_UP"] + C["CHEST_UP"] + C["SHOULDER"][1], 0.0),
    }
    for name, p in expect.items():
        q = nodes[name]["neutral"][9:12]
        if max(abs(a - b) for a, b in zip(p, q)) > 1e-4:
            sys.exit("base_body: %s is stale (%s at %s, constants say %s); re-run tools/blender/dump_rig.gd"
                     % (path, name, q, p))
    if abs(rig["neutral_arm"] - neutral_arm) > 1e-6:
        sys.exit("base_body: %s NEUTRAL_ARM differs from skinned_body.gd; re-run the dump" % path)
    for j in joints:
        if j not in nodes:
            sys.exit("base_body: joint %s missing from %s" % (j, path))
    return nodes


# --- small vector helpers (Godot space, plain tuples) ----------------------------------------------------------

def V(*a):
    return Vector(a if len(a) == 3 else a[0])


def smoothstep(e0, e1, x):
    if e0 == e1:
        return 1.0 if x >= e1 else 0.0
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def shrink_comp(n):
    """Cage radius factor so a Catmull-Clark ring of n points keeps its intended radius on the limit surface."""
    return 3.0 / (2.0 + math.cos(2.0 * math.pi / n))


def spow(v, p):
    return math.copysign(abs(v) ** p, v)


def ring_point(c, U, Vv, a_deg, ext_u, ext_vp, ext_vn, pw=1.0):
    """Point at angle a on an elliptical section: a = 0 toward +V, 90 toward -U. ext_vp/ext_vn: +V/-V extents."""
    a = math.radians(a_deg)
    su = spow(-math.sin(a), pw)
    cv = spow(math.cos(a), pw)
    return c + U * (su * ext_u) + Vv * (cv * (ext_vp if cv > 0.0 else ext_vn))


def ring_angle(p, c, U, Vv, ext_u, ext_v):
    d = p - c
    return math.degrees(math.atan2(-d.dot(U) / ext_u, d.dot(Vv) / ext_v))


def perp_frame(T, ref):
    """Unit vector perpendicular to T, as close as possible to ref."""
    v = ref - T * ref.dot(T)
    return v.normalized()


# --- body specs --------------------------------------------------------------------------------------------------
# Heights are for the default skeleton (hips 0.83, knee 0.43, ankle 0.10, spine 0.96, chest 1.08, neck 1.335,
# head 1.40) and are remapped piecewise-linearly onto the actual joint heights, so the forms follow the constants.
# Torso rows: (y, half width, front depth, back depth, z centre, superellipse power). Rows 9..12 hold the arm
# socket (armpit row ... shoulder-top row). Limb rows: (t or y, extents ...). All extents are limit-surface sizes.

SPEC = {
    "female": {
        "torso": [
            (0.776, 0.150, 0.068, 0.090, 0.006, 0.95),  # 0: leg split ring (front/back centres dip, see split_dip)
            (0.815, 0.161, 0.084, 0.108, 0.006, 0.85),
            (0.860, 0.163, 0.086, 0.106, 0.004, 0.85),  # hip widest
            (0.920, 0.140, 0.081, 0.086, 0.000, 0.90),
            (0.960, 0.117, 0.076, 0.072, -0.004, 0.96),
            (1.000, 0.102, 0.073, 0.066, -0.005, 1.0),  # waist
            (1.040, 0.108, 0.077, 0.069, -0.004, 1.0),
            (1.085, 0.117, 0.083, 0.075, -0.002, 1.0),  # under-bust
            (1.130, 0.123, 0.085, 0.077, 0.000, 1.0),
            (1.175, 0.127, 0.083, 0.077, 0.000, 0.98),  # 9: armpit row (socket bottom)
            (1.215, 0.131, 0.080, 0.076, 0.000, 0.95),
            (1.255, 0.133, 0.074, 0.072, 0.000, 0.92),
            (1.292, 0.124, 0.063, 0.065, 0.002, 0.90),  # 12: shoulder-top row (socket top)
            (1.318, 0.094, 0.052, 0.056, 0.003, 0.95),  # trapezius
            (1.342, 0.050, 0.044, 0.045, 0.004, 1.0),  # neck base
        ],
        "neck": [(1.375, 0.047, 0.043, 0.043, 0.003), (1.405, 0.0455, 0.042, 0.042, 0.0),
                 (1.437, 0.044, 0.040, 0.040, -0.003)],
        "split_dip": (0.012, 0.006),
        "crotch": (0.748, 0.006),
        "socket": {"x": 0.118, "y": 1.243, "ru": 0.063, "rf": 0.041, "tilt": 0.25},
        # (t along the bone, top/bottom extent, front/back extent, normal blend to the bone, offset along e_top)
        "upper_arm": [(0.0, 0.045, 0.044, 0.35, 0.0), (0.14, 0.041, 0.039, 1.0, 0.0), (0.40, 0.036, 0.035, 1.0, 0.0),
                      (0.70, 0.032, 0.031, 1.0, 0.0), (0.93, 0.029, 0.028, 1.0, 0.0)],
        "forearm": [(0.06, 0.029, 0.028), (0.25, 0.030, 0.028), (0.55, 0.026, 0.023), (0.84, 0.0225, 0.0185),
                    (0.97, 0.0215, 0.016)],
        # (u metres from the Hand joint, width extent (pinky/thumb), thickness extent, palm-ward curl offset)
        "hand": [(0.018, 0.029, 0.0155, 0.0), (0.050, 0.035, 0.0145, 0.0), (0.080, 0.037, 0.0115, 0.001),
                 (0.105, 0.035, 0.0102, 0.004), (0.128, 0.032, 0.0092, 0.009), (0.147, 0.025, 0.0078, 0.015)],
        "thumb": [(0.020, 0.0105), (0.040, 0.0095), (0.057, 0.0080)],
        # (y, half width, front, back, x offset outward, z offset)
        "leg": [(0.725, 0.077, 0.079, 0.084, 0.0, 0.0), (0.645, 0.072, 0.074, 0.073, -0.002, 0.0),
                (0.565, 0.064, 0.064, 0.061, -0.001, 0.0), (0.490, 0.055, 0.054, 0.051, 0.0, 0.0),
                (0.430, 0.049, 0.050, 0.046, 0.0, 0.0), (0.380, 0.046, 0.044, 0.049, 0.0, 0.002),
                (0.315, 0.048, 0.040, 0.059, 0.0, 0.007), (0.245, 0.043, 0.036, 0.049, 0.0, 0.004),
                (0.175, 0.035, 0.031, 0.035, 0.0, 0.0), (0.130, 0.031, 0.029, 0.029, 0.0, 0.0)],
        "foot": [(0.072, 0.004, 0.033, 0.047, 0.052), (0.042, -0.048, 0.039, 0.031, 0.040),
                 (0.031, -0.100, 0.042, 0.022, 0.030), (0.028, -0.138, 0.037, 0.016, 0.025)],
        "toe_z": -0.160,
        "arm_scale": 1.0,
        "bust": {"apex": (0.066, 1.13), "r_in": 0.054, "r_out": 0.066, "r_down": 0.058, "r_up": 0.088, "h": 0.044,
                 "pow": 1.6},
    },
    "male": {
        "torso": [
            (0.776, 0.136, 0.066, 0.079, 0.004, 0.95),
            (0.815, 0.141, 0.082, 0.092, 0.004, 0.88),
            (0.860, 0.141, 0.084, 0.091, 0.002, 0.88),
            (0.920, 0.131, 0.082, 0.081, 0.000, 0.92),
            (0.960, 0.124, 0.080, 0.075, -0.004, 0.95),
            (1.000, 0.122, 0.080, 0.073, -0.005, 0.95),
            (1.040, 0.128, 0.084, 0.075, -0.004, 0.92),
            (1.085, 0.140, 0.090, 0.079, -0.002, 0.9),
            (1.130, 0.152, 0.094, 0.082, 0.000, 0.88),
            (1.175, 0.163, 0.095, 0.084, 0.000, 0.86),
            (1.215, 0.171, 0.092, 0.084, 0.000, 0.84),
            (1.255, 0.175, 0.085, 0.080, 0.000, 0.82),
            (1.292, 0.166, 0.073, 0.073, 0.002, 0.84),
            (1.318, 0.118, 0.060, 0.062, 0.003, 0.95),
            (1.342, 0.060, 0.053, 0.053, 0.004, 1.0),
        ],
        "neck": [(1.375, 0.057, 0.052, 0.052, 0.003), (1.405, 0.055, 0.050, 0.050, 0.0),
                 (1.437, 0.052, 0.048, 0.048, -0.003)],
        "split_dip": (0.010, 0.005),
        "crotch": (0.750, 0.004),
        "socket": {"x": 0.150, "y": 1.247, "ru": 0.068, "rf": 0.049, "tilt": 0.15},
        "upper_arm": [(0.0, 0.056, 0.053, 0.35, 0.0), (0.14, 0.047, 0.045, 1.0, 0.0), (0.40, 0.042, 0.040, 1.0, 0.0),
                      (0.70, 0.037, 0.035, 1.0, 0.0), (0.93, 0.033, 0.031, 1.0, 0.0)],
        "forearm": [(0.06, 0.033, 0.031), (0.25, 0.035, 0.032), (0.55, 0.030, 0.026), (0.84, 0.025, 0.020),
                    (0.97, 0.024, 0.0175)],
        "hand": [(0.019, 0.032, 0.017, 0.0), (0.054, 0.038, 0.016, 0.0), (0.086, 0.040, 0.0125, 0.001),
                 (0.113, 0.038, 0.011, 0.004), (0.138, 0.035, 0.010, 0.009), (0.158, 0.027, 0.0085, 0.016)],
        "thumb": [(0.022, 0.0115), (0.043, 0.0105), (0.061, 0.0088)],
        "leg": [(0.725, 0.074, 0.077, 0.078, -0.002, 0.0), (0.645, 0.069, 0.072, 0.069, -0.003, 0.0),
                (0.565, 0.063, 0.063, 0.059, 0.002, 0.0), (0.490, 0.055, 0.055, 0.051, 0.0, 0.0),
                (0.430, 0.050, 0.051, 0.047, 0.0, 0.0), (0.380, 0.048, 0.045, 0.051, 0.0, 0.002),
                (0.315, 0.051, 0.042, 0.062, 0.0, 0.008), (0.245, 0.046, 0.038, 0.052, 0.0, 0.004),
                (0.175, 0.037, 0.033, 0.037, 0.0, 0.0), (0.130, 0.033, 0.031, 0.031, 0.0, 0.0)],
        "foot": [(0.072, 0.004, 0.035, 0.049, 0.054), (0.042, -0.050, 0.042, 0.032, 0.040),
                 (0.031, -0.104, 0.045, 0.023, 0.030), (0.028, -0.144, 0.040, 0.017, 0.025)],
        "toe_z": -0.168,
        "arm_scale": 1.0,
        "bust": None,
        "pecs": {"apex": (0.075, 1.17), "r": 0.075, "h": 0.007},
    },
}

TORSO_N = 24
TORSO_QUARTER = [0.0, 11.0, 22.0, 33.0, 45.0, 64.0, 90.0]  # col angles 0..6 (front centre .. side)
# Cage row heights (default skeleton): key rows of SPEC[...]["torso"] are interpolated onto these, denser through
# the bust. SOCKET_Y is the armpit row; it and the next three rows hold the arm socket.
ROW_Y = [0.776, 0.815, 0.860, 0.920, 0.960, 1.000, 1.040, 1.065, 1.090, 1.110, 1.130, 1.152, 1.175, 1.215, 1.255,
         1.292, 1.318, 1.342]
SOCKET_Y = 1.175
LIMB_N = 14
ARM_N = 10


def torso_angles():
    a = list(TORSO_QUARTER)
    for k in range(7, 13):
        a.append(180.0 - TORSO_QUARTER[12 - k])
    for k in range(13, 24):
        a.append(360.0 - a[24 - k])
    return a


def torso_rows(keys):
    """Key rows interpolated (linearly, the subdivision smooths) onto ROW_Y."""
    out = []
    for y in ROW_Y:
        for a, b in zip(keys, keys[1:]):
            if a[0] <= y <= b[0]:
                t = 0.0 if b[0] == a[0] else (y - a[0]) / (b[0] - a[0])
                out.append(tuple([y] + [a[i] + (b[i] - a[i]) * t for i in range(1, len(a))]))
                break
    return out


def side_col(k, s):
    """Torso column k (0..12 on the left, -X) mirrored for side s (+1 right)."""
    return k if s < 0 else (TORSO_N - k) % TORSO_N


class Remap:
    """Piecewise-linear y remap from the default skeleton's joint heights to the actual ones."""

    def __init__(self, nodes):
        def y(n):
            return nodes[n]["neutral"][10]
        self.src = [0.0, 0.10, 0.43, 0.83, 0.96, 1.08, 1.335, 1.40, 1.61]
        self.dst = [0.0, y("LeftFoot"), y("LeftLowerLeg"), y("Hips"), y("Spine"), y("Chest"), y("Neck"), y("Head"),
                    y("Head") + 0.21]

    def __call__(self, v):
        s, d = self.src, self.dst
        for i in range(len(s) - 1):
            if v <= s[i + 1] or i == len(s) - 2:
                t = (v - s[i]) / (s[i + 1] - s[i])
                return d[i] + t * (d[i + 1] - d[i])
        return v


# --- cage ------------------------------------------------------------------------------------------------------

class Cage:
    def __init__(self):
        self.verts = []
        self.faces = []  # (tuple of vertex indices, part index)

    def add(self, p):
        self.verts.append(Vector(p))
        return len(self.verts) - 1

    def ring(self, pts):
        return [self.add(p) for p in pts]

    def bridge(self, a, b, part):
        n = len(a)
        assert n == len(b)
        for i in range(n):
            j = (i + 1) % n
            self.faces.append(((a[i], a[j], b[j], b[i]), part))

    def cap(self, ring, part):
        self.faces.append((tuple(reversed(ring)), part))


def build_cage(body, nodes, neutral_arm):
    S = SPEC[body]
    ry = Remap(nodes)
    cage = Cage()
    P = {name: i for i, name in enumerate(PARTS)}
    k24 = shrink_comp(TORSO_N)
    k14 = shrink_comp(LIMB_N)
    k10 = shrink_comp(ARM_N)
    angles = torso_angles()
    X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

    def jpos(name):
        return Vector(nodes[name]["neutral"][9:12])

    # Torso grid: rows x 24 columns. Socket interior points are skipped, socket points are set from the socket ring.
    rows = torso_rows(S["torso"])
    grid = []
    sk0 = ROW_Y.index(SOCKET_Y)
    dip_f, dip_b = S["split_dip"]
    for r, (y, hw, df, db, zc, pw) in enumerate(rows):
        yy = ry(y)
        c = Vector((0.0, yy, zc))
        row = []
        for k in range(TORSO_N):
            p = ring_point(c, X, -Z, angles[k], hw * k24, df * k24, db * k24, pw)
            if r == 0:  # front and back centres dip toward the crotch
                ca = math.cos(math.radians(angles[k]))
                p.y -= (dip_f if ca > 0 else dip_b) * abs(ca) ** 3
            row.append(p)
        grid.append(row)

    # Arm sockets: a 10-point ring on rows sk0..sk0+3, columns 5..7 (mirrored on the right).
    sock = S["socket"]
    socket_cells = [(3, 6), (3, 5), (2, 5), (1, 5), (0, 5), (0, 6), (0, 7), (1, 7), (2, 7), (3, 7)]
    beta = [36.0 * i for i in range(ARM_N)]
    arm_dirs = {}
    socket_ring_pts = {}
    for s in (-1.0, 1.0):
        side = "Left" if s < 0 else "Right"
        J = jpos(side + "UpperArm")
        E = jpos(side + "LowerArm")
        d = (E - J).normalized()
        arm_dirs[s] = d
        out = Vector((s, 0.0, 0.0))
        n_s = (out * (1.0 - sock["tilt"]) + d * sock["tilt"]).normalized()
        e_up = perp_frame(n_s, Y)
        sc = Vector((s * sock["x"], ry(sock["y"]), 0.0))
        pts = [ring_point(sc, Z, e_up, b, sock["rf"], sock["ru"], sock["ru"]) for b in beta]
        socket_ring_pts[s] = pts
        for (dr, kc), p in zip(socket_cells, pts):
            grid[sk0 + dr][side_col(kc, s)] = p
    skip = set()
    for s in (-1.0, 1.0):
        for dr in (1, 2):
            skip.add((sk0 + dr, side_col(6, s)))

    gid = []
    for r, row in enumerate(grid):
        ids = []
        for k, p in enumerate(row):
            ids.append(None if (r, k) in skip else cage.add(p))
        gid.append(ids)
    hole = set()
    for s in (-1.0, 1.0):
        for dr in range(3):
            for kc in (5, 6):
                a, b = side_col(kc, s), side_col(kc + 1, s)
                hole.add((sk0 + dr, min(a, b) if abs(a - b) == 1 else max(a, b)))
    for r in range(len(grid) - 1):
        for k in range(TORSO_N):
            k2 = (k + 1) % TORSO_N
            if (r, k) in hole:
                continue
            cage.faces.append(((gid[r][k], gid[r][k2], gid[r + 1][k2], gid[r + 1][k]), P["torso"]))

    # Neck: rings of 24 up to the open collar ring under the jaw.
    prev = gid[-1]
    for (y, hw, df, db, zc) in S["neck"]:
        c = Vector((0.0, ry(y), zc))
        ring = cage.ring([ring_point(c, X, -Z, angles[k], hw * k24, df * k24, db * k24) for k in range(TORSO_N)])
        cage.bridge(prev, ring, P["neck"])
        prev = ring

    # Legs: the split ring's half plus a crotch point, then 14-point rings down to the ankle, then the foot.
    cy, cz = S["crotch"]
    crotch = cage.add((0.0, ry(cy), cz))
    for s in (-1.0, 1.0):
        side = "Left" if s < 0 else "Right"
        tag = "L" if s < 0 else "R"
        U = Vector((-s, 0.0, 0.0))
        hip = jpos(side + "UpperLeg")
        top = [gid[0][side_col(k, s)] for k in range(13)] + [crotch]
        # Angles of the top ring around the first thigh section, blended to an even spread further down.
        y0, hw0, f0, b0, xo0, zo0 = S["leg"][0]
        c0 = Vector((hip.x + s * xo0, ry(y0), zo0))
        top_ang = []
        for vi in top:
            a = ring_angle(cage.verts[vi], c0, U, -Z, hw0, (f0 + b0) * 0.5)
            top_ang.append(a)
        for i in range(1, len(top_ang)):  # unwrap to increasing
            while top_ang[i] < top_ang[i - 1]:
                top_ang[i] += 360.0
        even = [top_ang[0] + i * 360.0 / LIMB_N for i in range(LIMB_N)]
        prev = top
        for i, (y, hw, f, b, xo, zo) in enumerate(S["leg"]):
            w = 0.55 if i == 0 else 1.0
            c = Vector((hip.x + s * xo, ry(y), zo))
            pts = [ring_point(c, U, -Z, ta * (1 - w) + ea * w, hw * k14, f * k14, b * k14)
                   for ta, ea in zip(top_ang, even)]
            ring = cage.ring(pts)
            cage.bridge(prev, ring, P["leg_" + tag])
            prev = ring
        # Foot: rings perpendicular to a path from the ankle down and forward to the toes.
        ankle = jpos(side + "Foot")
        path = [Vector((ankle.x, ry(S["leg"][-1][0]), 0.0))]
        for (y, z, hw, t, bt) in S["foot"]:
            path.append(Vector((ankle.x, y, z)))
        path.append(Vector((ankle.x, S["foot"][-1][0] - 0.002, S["toe_z"])))
        for i, (y, z, hw, t, bt) in enumerate(S["foot"]):
            p = path[i + 1]
            T = (path[i + 2] - path[i]).normalized()
            Vf = perp_frame(T, -Z if i == 0 else Y)
            if i == 0:
                Vf = perp_frame(T, (-Z + Y).normalized())
            pts = [ring_point(p, U, Vf, ea, hw * k14, t * k14, bt * k14) for ea in even]
            ring = cage.ring(pts)
            cage.bridge(prev, ring, P["foot_" + tag])
            prev = ring
        cage.cap(prev, P["foot_" + tag])

    # Arms: socket ring -> upper arm -> forearm -> hand (mitten) with a thumb.
    asc = S["arm_scale"]
    for s in (-1.0, 1.0):
        side = "Left" if s < 0 else "Right"
        tag = "L" if s < 0 else "R"
        J = jpos(side + "UpperArm")
        E = jpos(side + "LowerArm")
        H = jpos(side + "Hand")
        d = arm_dirs[s]
        e_top = perp_frame(d, Y)
        out = Vector((s, 0.0, 0.0))
        n_s = (out * (1.0 - sock["tilt"]) + d * sock["tilt"]).normalized()
        sock_ids = [gid[sk0 + dr][side_col(kc, s)] for dr, kc in socket_cells]
        prev = sock_ids
        L_u = (E - J).length
        L_f = (H - E).length
        for (t, ru, rf, w, off) in S["upper_arm"]:
            n = (n_s * (1.0 - w) + d * w).normalized()
            et = perp_frame(n, Y)
            c = J + d * (t * L_u) + et * off
            ring = cage.ring([ring_point(c, Z, et, b, rf * k10 * asc, ru * k10 * asc, ru * k10 * asc) for b in beta])
            cage.bridge(prev, ring, P["arm_" + tag])
            prev = ring
        nf = len(S["forearm"])
        for i, (t, ru, rf) in enumerate(S["forearm"]):
            phase = 18.0 * smoothstep(0.3, 0.97, t)
            c = E + d * (t * L_f)
            ring = cage.ring([ring_point(c, Z, e_top, b + phase, rf * k10 * asc, ru * k10 * asc, ru * k10 * asc)
                              for b in beta])
            cage.bridge(prev, ring, P["arm_" + tag])
            prev = ring
        hand_rings = []
        palm = Z  # the palm faces +Z (back), the back of the hand faces forward, as the code-built hand
        for (u, wv, th, curl) in S["hand"]:
            c = H + d * u + palm * curl
            ring = cage.ring([ring_point(c, Z, e_top, b + 18.0, th * k10, wv * k10, wv * k10) for b in beta])
            cage.bridge(prev, ring, P["hand_" + tag])
            hand_rings.append(ring)
            prev = ring
        # Mitten tip: close with a ladder of quads so the fingertip edge stays clean.
        r = prev
        cage.faces.append(((r[0], r[1], r[8], r[9]), P["hand_" + tag]))
        cage.faces.append(((r[1], r[2], r[7], r[8]), P["hand_" + tag]))
        cage.faces.append(((r[2], r[3], r[6], r[7]), P["hand_" + tag]))
        cage.faces.append(((r[3], r[4], r[5], r[6]), P["hand_" + tag]))
        # Thumb: replace the thumb-edge quad between hand rings 0 and 1 (points 4 and 5, beta 162..198).
        h0, h1 = hand_rings[0], hand_rings[1]
        base = [h0[4], h1[4], h1[5], h0[5]]
        quad = (h0[4], h0[5], h1[5], h1[4])
        cage.faces = [f for f in cage.faces if set(f[0]) != set(quad)]
        bc = sum((cage.verts[i] for i in base), Vector()) / 4.0
        td = (d * 0.80 - e_top * 0.45 - Z * 0.25).normalized()
        prev = base
        for (dist, rad) in S["thumb"]:
            c = bc + td * dist
            ring = []
            for i in base:
                off = cage.verts[i] - bc
                off = off - td * off.dot(td)
                ring.append(cage.add(c + off.normalized() * rad * shrink_comp(4)))
            cage.bridge(prev, ring, P["hand_" + tag])
            prev = ring
        cage.cap(prev, P["hand_" + tag])
    return cage


# --- forms on the subdivided mesh --------------------------------------------------------------------------------

def bust_field(x, y, b):
    """0..1 bust height factor at body-space (x, y) and the normalised radius r (r < 1 inside the form)."""
    ax, ay = b["apex"]
    dx = abs(x) - ax
    dy = y - ay
    u = dx / (b["r_out"] if dx > 0 else b["r_in"])
    v = dy / (b["r_up"] if dy > 0 else b["r_down"])
    r = math.sqrt(u * u + v * v)
    if r >= 1.0:
        return 0.0, r
    f = (1.0 - r * r) ** b.get("pow", 2.0)
    return f, r


def apply_forms(mesh, body, ry):
    S = SPEC[body]
    vs = mesh.vertices
    torso_v = set()
    for poly in mesh.polygons:
        if PARTS[poly.material_index] == "torso":
            torso_v.update(poly.vertices)
    normals = {i: vs[i].normal.copy() for i in torso_v}  # before any move: moving a vertex re-derives normals
    moves = {}
    for i in sorted(torso_v):
        v = vs[i]
        n = normals[i]
        x, y, z = v.co.x, v.co.z, -v.co.y  # Godot space
        nz = -n.y  # Godot z of the normal
        if nz > -0.05:
            continue  # only the front of the torso
        if S.get("bust"):
            b = dict(S["bust"])
            b["apex"] = (b["apex"][0], ry(b["apex"][1]))
            f, _r = bust_field(x, y, b)
            if f > 0:
                h = b["h"] * f * smoothstep(-0.05, -0.35, nz)
                moves[i] = n * h
        if S.get("pecs"):
            pc = S["pecs"]
            dx = abs(x) - pc["apex"][0]
            dy = y - ry(pc["apex"][1])
            r = math.sqrt(dx * dx + dy * dy * 1.6) / pc["r"]
            if r < 1:
                moves[i] = n * pc["h"] * (1 - r * r) ** 2 * smoothstep(-0.05, -0.35, nz)
    for i, m in moves.items():
        vs[i].co += m


# --- regions -------------------------------------------------------------------------------------------------------

def face_region(part, c, body, nodes, ry):
    """Region of a face from its part and its centre c (Godot space, model pose)."""
    S = SPEC[body]
    tag = part[-1]
    if part == "neck":
        return "neck"
    if part.startswith("hand"):
        return "hand_" + tag
    if part.startswith("foot"):
        return "foot_" + tag
    if part.startswith("arm"):
        side = "Left" if tag == "L" else "Right"
        E = Vector(nodes[side + "LowerArm"]["neutral"][9:12])
        J = Vector(nodes[side + "UpperArm"]["neutral"][9:12])
        d = (E - J).normalized()
        return ("forearm_" if (c - E).dot(d) > 0.0 else "upper_arm_") + tag
    if part.startswith("leg"):
        y = c.y
        knee = nodes["LeftLowerLeg"]["neutral"][10]
        if y > ry(0.64):
            return "thigh_upper_" + tag
        if y > ry(0.49):
            return "thigh_lower_" + tag
        if y > ry(0.38):
            return "knee_" + tag
        if y > ry(0.175):
            return "calf_" + tag
        return "ankle_" + tag
    # torso
    y = c.y
    if S.get("bust"):
        b = dict(S["bust"])
        b["apex"] = (b["apex"][0], ry(b["apex"][1]))
        f, r = bust_field(c.x, y, b)
        if r < 1.0 and c.z < 0.0:
            return "bust"
    elif S.get("pecs"):
        pc = S["pecs"]
        dx = abs(c.x) - pc["apex"][0]
        dy = y - ry(pc["apex"][1])
        if math.sqrt(dx * dx + dy * dy * 1.6) < pc["r"] and c.z < 0.0:
            return "bust"
    if y >= ry(1.09):
        return "chest_upper"
    if y >= ry(1.0):
        return "under_bust"
    if y >= ry(0.92):
        return "waist"
    if c.z > 0.02 and abs(c.x) < 0.15:
        return "glutes"
    return "pelvis"


# --- Blender objects ---------------------------------------------------------------------------------------------

def g2b(p):
    return Vector((p[0], -p[2], p[1]))


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_mesh(cage, body):
    me = bpy.data.meshes.new("BaseBody_%s_cage" % body)
    verts = [g2b(p) for p in cage.verts]
    used = sorted({i for f, _ in cage.faces for i in f})
    remap = {old: new for new, old in enumerate(used)}
    me.from_pydata([verts[i] for i in used], [], [tuple(remap[i] for i in f) for f, _ in cage.faces])
    me.update()
    for poly, (_, part) in zip(me.polygons, cage.faces):
        poly.material_index = part
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("BaseBody_%s" % body, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def subdivide(obj, levels):
    mod = obj.modifiers.new("Subdivision", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    mod.quality = 3
    mod.uv_smooth = "PRESERVE_CORNERS"
    mod.boundary_smooth = "ALL"
    mod.use_limit_surface = True
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    obj.modifiers.clear()
    old = obj.data
    obj.data = me
    me.name = obj.name
    bpy.data.meshes.remove(old)


def assign_regions(obj, body, nodes, ry, regions):
    me = obj.data
    reg_of_face = []
    for poly in me.polygons:
        c = poly.center
        cg = Vector((c.x, c.z, -c.y))
        reg_of_face.append(face_region(PARTS[poly.material_index], cg, body, nodes, ry))
    groups = {name: obj.vertex_groups.new(name=name) for name in regions}
    members = {name: set() for name in regions}
    for poly, reg in zip(me.polygons, reg_of_face):
        members[reg].update(poly.vertices)
    for name, vs in members.items():
        if vs:
            groups[name].add(sorted(vs), 1.0, "REPLACE")
    uv0 = me.uv_layers.new(name="UVMap")
    uv1 = me.uv_layers.new(name="Regions")
    for poly, reg in zip(me.polygons, reg_of_face):
        ri = regions.index(reg)
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv0.data[li].uv = (co.x * 0.5 + 0.5, co.z / HEAD_TOP)  # simple front projection, a placeholder map
            uv1.data[li].uv = (ri + 0.5, 0.5)
    return reg_of_face


def make_armature(body, nodes, joints):
    arm = bpy.data.armatures.new("Armature_%s" % body)
    obj = bpy.data.objects.new("Armature", arm)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    def p(name):
        return Vector(nodes[name]["neutral"][9:12])

    tails = {
        "Hips": p("Spine"), "Spine": p("Chest"), "Chest": p("Neck"), "Neck": p("Head"),
        "Head": p("Head") + Vector((0.0, HEAD_TOP - p("Head").y, 0.0)),
    }
    for side in ("Left", "Right"):
        hand_dir = (p(side + "Hand") - p(side + "LowerArm")).normalized()
        tails[side + "UpperArm"] = p(side + "LowerArm")
        tails[side + "LowerArm"] = p(side + "Hand")
        tails[side + "Hand"] = p(side + "Hand") + hand_dir * 0.09
        tails[side + "UpperLeg"] = p(side + "LowerLeg")
        tails[side + "LowerLeg"] = p(side + "Foot")
        tails[side + "Foot"] = Vector((p(side + "Foot").x, 0.03, -0.11))
    eb = arm.edit_bones
    for j in joints:
        b = eb.new(j)
        b.head = g2b(p(j))
        b.tail = g2b(tails[j])
        b.roll = 0.0
    for j in joints:
        par = nodes[j]["parent"]
        if par:
            eb[j].parent = eb[par]
            eb[j].use_connect = False
    extra = {}
    for bone, pivot in (("BustL", "BodySway_BustL"), ("BustR", "BodySway_BustR")):
        if pivot in nodes:
            b = eb.new(bone)
            b.head = g2b(p(pivot))
            b.tail = g2b(p(pivot) + Vector((0.0, -0.02, -0.05)))
            b.parent = eb[nodes[pivot]["parent"]]
            extra[bone] = pivot
    top = eb.new("HeadTop")
    top.head = g2b(tails["Head"])
    top.tail = g2b(tails["Head"] + Vector((0.0, 0.05, 0.0)))
    top.parent = eb["Head"]
    top.use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj, extra


def bind(mesh_obj, arm_obj):
    bpy.ops.object.select_all(action="DESELECT")
    mesh_obj.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


# --- weight fix-ups --------------------------------------------------------------------------------------------------

def shoulder_blend(g, J, d, w, tag, on_arm=False, shift=0.0):
    """Shoulder and armpit: UpperArm fades in across a near-vertical plane through the shoulder joint, so a
    raised arm drags the armpit and deltoid with it instead of folding them; the rest stays on the torso."""
    out = Vector((-1.0 if tag == "Left" else 1.0, 0.0, 0.0))
    x_s = (g - J).dot(out) - shift  # shift: how much wider than the female socket this torso is
    # outward of the shoulder joint, fading out below the armpit so the chest and bust stay on the torso
    a = smoothstep(-0.03, 0.025, x_s) * smoothstep(J.y - 0.13, J.y - 0.07, g.y)
    if on_arm:
        a = max(a, smoothstep(0.0, 0.07, (g - J).dot(d)))  # down the arm (the armpit's underside too): all arm
    if a <= 0.0:
        w.pop(tag + "UpperArm", None)
        return w if w else {"Chest": 1.0}
    torso = {n: x for n, x in w.items() if n in ("Chest", "Spine", "Neck")}
    tot = sum(torso.values())
    out = {n: x / tot * (1.0 - a) for n, x in torso.items()} if tot > 0 else {"Chest": 1.0 - a}
    out[tag + "UpperArm"] = a
    return out


def fix_weights(mesh_obj, body, nodes, ry, regions, extra, joints):
    me = mesh_obj.data
    vg = mesh_obj.vertex_groups
    bone_names = list(joints) + list(extra.keys())
    bone_set = set(bone_names)
    idx = {g.name: g.index for g in vg}
    names_by_idx = {g.index: g.name for g in vg}
    S = SPEC[body]

    def P(n):
        return Vector(nodes[n]["neutral"][9:12])

    # A vertex belongs to a limb part when any of its faces does; vertices that also touch a torso face (the
    # socket and split rings) keep the torso's automatic weights.
    part_of_vert = {}
    shared = set()
    for poly in me.polygons:
        part = PARTS[poly.material_index]
        for v in poly.vertices:
            if part == "torso":
                shared.add(v)
                part_of_vert.setdefault(v, "torso")
            elif part_of_vert.get(v, "torso") in ("torso", "neck"):
                part_of_vert[v] = part

    shift = S["socket"]["x"] - SPEC["female"]["socket"]["x"]
    bust = None
    if S.get("bust"):
        bust = dict(S["bust"])
        bust["apex"] = (bust["apex"][0], ry(bust["apex"][1]))

    for v in me.vertices:
        g = Vector((v.co.x, v.co.z, -v.co.y))
        w = {}
        for ge in v.groups:
            n = names_by_idx[ge.group]
            if n in bone_set and ge.weight > 0.0:
                w[n] = ge.weight
        part = part_of_vert.get(v.index, "torso")
        tag = "Left" if g.x < 0 else "Right"
        other = "Right" if tag == "Left" else "Left"
        # No weights from the other side's limbs.
        for n in list(w):
            if n.startswith(other) and abs(g.x) > 0.02:
                del w[n]
        is_limb = part != "torso" and part != "neck" and v.index not in shared
        if part.startswith(("arm", "hand")) and is_limb:
            J, E, H = P(tag + "UpperArm"), P(tag + "LowerArm"), P(tag + "Hand")
            d = (E - J).normalized()
            x_e = (g - E).dot(d)  # along the arm from the elbow
            x_w = (g - H).dot(d)  # from the wrist
            t_u = (g - J).dot(d) / (E - J).length
            lower = smoothstep(-0.03, 0.035, x_e)
            hand = smoothstep(0.0, 0.03, x_w)
            if t_u < 0.3:
                w = shoulder_blend(g, J, d, w, tag, True, shift)
            else:
                w = {tag + "UpperArm": (1 - lower), tag + "LowerArm": lower * (1 - hand), tag + "Hand": hand}
        elif part.startswith(("leg", "foot")) and is_limb:
            K, A = P(tag + "LowerLeg"), P(tag + "Foot")
            y = g.y
            lower = smoothstep(K.y + 0.04, K.y - 0.04, y)
            foot = smoothstep(A.y + 0.01, A.y - 0.03, y) if part.startswith("leg") else max(
                smoothstep(A.y + 0.01, A.y - 0.03, y), smoothstep(-0.01, -0.05, g.z))
            if y > K.y + 0.12:
                # upper thigh: keep the automatic Hips/UpperLeg blend, nothing from below the knee
                for n in list(w):
                    if n not in (tag + "UpperLeg", "Hips", "Spine"):
                        del w[n]
                if not w:
                    w = {tag + "UpperLeg": 1.0}
            else:
                w = {tag + "UpperLeg": (1 - lower), tag + "LowerLeg": lower * (1 - foot), tag + "Foot": foot}
        else:
            # torso / neck
            for n in list(w):
                if n.endswith(("LowerArm", "Hand", "LowerLeg", "Foot")):
                    del w[n]
            J = P(tag + "UpperArm")
            if abs(g.x) > 0.02:  # everywhere on the torso, so no automatic arm weight is left below the blend
                w = shoulder_blend(g, J, (P(tag + "LowerArm") - J).normalized(), w, tag, False, shift)
            neck_y = P("Neck").y
            head_y = P("Head").y
            if g.y > neck_y - 0.02 and abs(g.x) < 0.075:
                head = smoothstep(head_y - 0.025, head_y + 0.03, g.y) * 0.8
                chest = smoothstep(neck_y + 0.01, neck_y - 0.03, g.y)
                w = {"Chest": chest, "Neck": (1 - chest) * (1 - head), "Head": (1 - chest) * head}
            for b in ("BustL", "BustR"):
                w.pop(b, None)
            if bust is not None and g.z < 0.0:
                f, r = bust_field(g.x, g.y, bust)
                if r < 1.15:
                    # bust on Chest, carried by its BustL/R bone near the apex
                    # keep the shoulder blend at the outer rim; Spine (and Neck) weight moves to Chest
                    bb = 0.85 * smoothstep(1.0, 0.25, r)
                    keep = {n: x for n, x in w.items() if n.endswith("UpperArm")}
                    rest = 1.0 - sum(keep.values())
                    w = {n: x * (1.0 - bb) for n, x in keep.items()}
                    w["Chest"] = rest * (1.0 - bb)
                    if bb > 0.0 and ("BustL" in extra):
                        w["BustL" if g.x < 0 else "BustR"] = bb
        # normalise, drop tiny, keep 4
        w = {n: x for n, x in w.items() if x > 0.01}
        if not w:
            w = {"Chest": 1.0}
        top = sorted(w.items(), key=lambda kv: (-kv[1], kv[0]))[:4]
        tot = sum(x for _, x in top)
        for n in bone_names:
            if n in idx:
                vg[idx[n]].remove([v.index])
        for n, x in top:
            if n not in idx:
                idx[n] = vg.new(name=n).index
            vg[idx[n]].add([v.index], x / tot, "REPLACE")


# --- export ------------------------------------------------------------------------------------------------------------

def make_material(body, C):
    mat = bpy.data.materials.new("skin")
    col = C["SKIN_" + body]
    mat.diffuse_color = (col[0], col[1], col[2], 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1.0)
        bsdf.inputs["Roughness"].default_value = 0.8
    return mat


def export_glb(path, mesh_obj, arm_obj):
    bpy.ops.object.select_all(action="DESELECT")
    mesh_obj.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_texcoords=True, export_normals=True, export_tangents=False, export_materials="EXPORT",
        export_skins=True, export_all_influences=False, export_def_bones=False, export_morph=False,
        export_animations=False, export_extras=True, export_rest_position_armature=True)


def build(body, args, C, regions, joints, neutral_arm):
    reset_scene()
    nodes = load_rig(args.rig, body, C, joints, neutral_arm)
    ry = Remap(nodes)
    cage = build_cage(body, nodes, neutral_arm)
    obj = make_mesh(cage, body)
    cage_quads = len(obj.data.polygons)
    subdivide(obj, args.levels)
    obj.data.update()
    apply_forms(obj.data, body, ry)
    obj.data.update()
    obj.data.shade_smooth()
    assign_regions(obj, body, nodes, ry, regions)
    arm_obj, extra = make_armature(body, nodes, joints)
    bind(obj, arm_obj)
    fix_weights(obj, body, nodes, ry, regions, extra, joints)
    mat = make_material(body, C)  # one material slot; the part indices are no longer needed
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.material_index = 0
    obj["regions"] = json.dumps(regions)
    obj["body_type"] = body
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    os.makedirs(args.out, exist_ok=True)
    path = os.path.join(args.out, "base_body_%s.glb" % body)
    export_glb(path, obj, arm_obj)
    if args.blend:
        os.makedirs(args.blend, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(args.blend, "base_body_%s.blend" % body))
    zs = [v.co.z for v in obj.data.vertices]
    print("base_body: %s cage %d faces -> %d verts, %d tris, mesh y %.3f..%.3f -> %s"
          % (body, cage_quads, len(obj.data.vertices), tris, min(zs), max(zs), os.path.relpath(path, ROOT)))
    return obj, arm_obj


def parse_args(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", default=os.path.join(ROOT, "assets", "characters"))
    ap.add_argument("--body", default="both", choices=["female", "male", "both"])
    ap.add_argument("--rig", default=DEFAULT_RIG)
    ap.add_argument("--levels", type=int, default=1)
    ap.add_argument("--blend", default="", help="also save a .blend per body into this directory")
    return ap.parse_args(argv)


def main(argv):
    args = parse_args(argv)
    C = read_constants()
    regions = read_regions()
    joints = read_joints()
    neutral_arm = read_neutral_arm()
    for body in (["female", "male"] if args.body == "both" else [args.body]):
        build(body, args, C, regions, joints, neutral_arm)


if __name__ == "__main__":
    main(sys.argv[1:])
