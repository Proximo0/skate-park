"""Skinned base body (smooth featureless mannequin) built in Houdini, for comparison with tools/blender/base_body.py.

Usage: hython tools/houdini/base_body.py [female|male|both]
       hython tools/houdini/base_body.py --view <body> <azimuth>   (one preview render; used internally)

Pipeline:
  1. Read the joint dump (tools/blender/rig_rest.json, model pose = "neutral" transforms) and the skin section tables
     in game/skater/anime_outfit.gd (rows [y or t, half width, front, back, power, z centre]).
  2. Python SOP: a low-poly quad cage per part. Torso parts loft the PELVIS/WAIST/CHEST tables (body space), the
     neck loft sits on the Neck joint, the limbs loft THIGH/CALF/UPPER_ARM/FOREARM along their bones (y = -t * length)
     in the model pose (A-pose arms). Mitten hands, simple feet and a smooth head placeholder close the body.
  3. Subdivide (OpenSubdiv Catmull-Clark, 2 levels) for smooth parts, then VDB from polygons + smooth SDF + convert
     fuses them into one watertight skin with soft junctions.
  4. Female bust: the game's two-lobe height field (AnimeOutfit.bust_height) raised along the front normal.
  5. Remesh to even triangles at the budget, smooth normals.
  6. KineFX: skeleton from the dump (17 SkaterPoser joints, BustL/R on the BodySway pivots for the female, a
     non-deforming HeadTop at the crown), Joint Capture Biharmonic, glTF export with the ROP glTF Character.
Space: Godot body space (Y up, metres, faces -Z, Left = -X, origin between the feet).
Outputs: assets/characters/houdini/base_body_<body>.glb, tools/houdini/base_body.hip,
         tools/houdini/previews/base_body_<body>.png (front, three-quarter, side).
"""
import json
import math
import os
import re
import subprocess
import sys
import time

import hou

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hlib  # noqa: E402

RIG = os.path.join(hlib.ROOT, "tools", "blender", "rig_rest.json")
OUTFIT = os.path.join(hlib.ROOT, "game", "skater", "anime_outfit.gd")
OUT_DIR = os.path.join(hlib.ROOT, "assets", "characters", "houdini")
HIP = os.path.join(hlib.TOOLS, "base_body.hip")
HEAD_TOP = 1.61
TRI_BUDGET = 10000
SKIN = (0.96, 0.80, 0.69)
VOXEL = 0.0025
REMESH_EDGE = 0.0168  # metres; about TRI_BUDGET triangles over the body's ~1.6 m2

# Model-pose joint names in SkaterPoser.JOINTS order (the dump's other nodes are the BodySway pivots).
JOINTS = ["Hips", "Spine", "Chest", "Neck", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
          "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg",
          "RightLowerLeg", "RightFoot"]
# Hand rows (u metres from the Hand joint, width extent, thickness extent, palm-ward curl), from the Blender SPEC.
HAND = {
    "female": [(0.0, 0.022, 0.015, 0.0), (0.018, 0.029, 0.0155, 0.0), (0.050, 0.035, 0.0145, 0.0),
               (0.080, 0.037, 0.0115, 0.001), (0.105, 0.035, 0.0102, 0.004), (0.128, 0.032, 0.0092, 0.009),
               (0.147, 0.025, 0.0078, 0.015), (0.156, 0.012, 0.004, 0.018)],
    "male": [(0.0, 0.025, 0.017, 0.0), (0.019, 0.032, 0.017, 0.0), (0.054, 0.038, 0.016, 0.0),
             (0.086, 0.040, 0.0125, 0.001), (0.113, 0.038, 0.011, 0.004), (0.138, 0.035, 0.010, 0.009),
             (0.158, 0.027, 0.0085, 0.016), (0.167, 0.013, 0.0045, 0.019)],
}
THUMB = {"female": [(0.0, 0.011), (0.020, 0.0105), (0.040, 0.0095), (0.057, 0.008), (0.064, 0.004)],
         "male": [(0.0, 0.012), (0.022, 0.0115), (0.043, 0.0105), (0.061, 0.0088), (0.069, 0.0045)]}
# Foot rows along -Z: (z, half width, top height); the sole is flat at y = 0.
FOOT = {"female": [(0.06, 0.012, 0.05), (0.05, 0.03, 0.075), (0.02, 0.034, 0.10), (-0.03, 0.038, 0.08),
                   (-0.08, 0.041, 0.056), (-0.125, 0.038, 0.038), (-0.155, 0.027, 0.026), (-0.163, 0.01, 0.012)],
        "male": [(0.062, 0.013, 0.052), (0.052, 0.032, 0.078), (0.02, 0.036, 0.105), (-0.03, 0.04, 0.084),
                 (-0.085, 0.043, 0.058), (-0.13, 0.04, 0.04), (-0.162, 0.028, 0.027), (-0.171, 0.011, 0.012)]}
HEAD = {"female": (0.075, 0.1125, 0.095), "male": (0.08, 0.1125, 0.1)}  # radii x, y, z (0.15 wide, 0.225 tall)
# Male limb scales (half width, depths), as AnimeOutfit.skin_sections.
MALE_SCALE = {"thigh": (1.06, 1.04), "calf": (1.1, 1.08), "upper_arm": (1.2, 1.18), "forearm": (1.14, 1.16)}


# --- inputs -----------------------------------------------------------------------------------------------------

def gd_table(src, name):
    m = re.search(r"^const %s: Array = \[(.*?)\n\]" % name, src, re.S | re.M)
    if not m:
        sys.exit("base_body: table %s missing from %s" % (name, OUTFIT))
    return json.loads("[" + m.group(1).strip().rstrip(",") + "]")


def gd_float(src, name):
    return float(re.search(r"^const %s: float = ([-0-9.]+)" % name, src, re.M).group(1))


def gd_vec2(src, name):
    m = re.search(r"^const %s: Vector2 = Vector2\(([-0-9.]+), ([-0-9.]+)\)" % name, src, re.M)
    return float(m.group(1)), float(m.group(2))


def load_inputs(body):
    src = open(OUTFIT, encoding="utf-8").read()
    m = body == "male"
    sfx = "_M" if m else ""
    tables = {k: gd_table(src, k.upper() + sfx) for k in ("pelvis", "waist", "chest", "neck")}
    for k, name in (("thigh", "THIGH"), ("calf", "CALF"), ("upper_arm", "UPPER_ARM_SECTIONS"),
                    ("forearm", "FOREARM_SECTIONS")):
        t = gd_table(src, name)
        if m:
            kw, kd = MALE_SCALE[k]
            t = [[r[0], r[1] * kw, r[2] * kd, r[3] * kd] + r[4:] for r in t]
        tables[k] = t
    bust = None
    if not m:
        bust = {"apex": gd_vec2(src, "BUST_APEX"), "r_in": gd_float(src, "BUST_R_IN"),
                "r_out": gd_float(src, "BUST_R_OUT"), "r_down": gd_float(src, "BUST_R_DOWN"),
                "r_up": gd_float(src, "BUST_R_UP"), "h": gd_float(src, "BUST_HEIGHT")}
    rig = json.load(open(RIG, encoding="utf-8"))["bodies"][body]
    nodes = rig["nodes"]
    for j in JOINTS:
        if j not in nodes:
            sys.exit("base_body: joint %s missing from %s" % (j, RIG))
    return tables, bust, rig


# --- cage -------------------------------------------------------------------------------------------------------

def shrink_comp(n):
    """Cage radius factor so a Catmull-Clark ring of n points keeps its radius on the limit surface."""
    return 3.0 / (2.0 + math.cos(2.0 * math.pi / n))


def section_ring(row, n, base_y=0.0, sign_y=1.0):
    """Ring of a section row [y, hw, front, back, power, zc(, xc)] in its joint space (AnimeOutfit.section_point)."""
    k = shrink_comp(n)
    y, hw, df, db, p, zc = row[:6]
    xc = row[6] if len(row) > 6 else 0.0
    pts = []
    for i in range(n):
        a = 2.0 * math.pi * i / n
        sn, c = math.sin(a), math.cos(a)
        x = xc + hw * k * math.copysign(abs(sn) ** p, sn)
        z = zc - (df if c > 0 else db) * k * math.copysign(abs(c) ** p, c)
        pts.append((x, base_y + sign_y * y, z))
    return pts


def xform(m, p):
    """Point p in the space of a dumped Godot transform m (basis columns x, y, z then origin)."""
    return (m[9] + m[0] * p[0] + m[3] * p[1] + m[6] * p[2],
            m[10] + m[1] * p[0] + m[4] * p[1] + m[7] * p[2],
            m[11] + m[2] * p[0] + m[5] * p[1] + m[8] * p[2])


def build_cage(body, tables, rig):
    """Rings per part (list of parts, each a list of rings bottom-to-top or top-to-bottom), all in body space."""
    nodes = rig["nodes"]

    def neutral(j):
        return nodes[j]["neutral"]

    # One continuous torso loft: pelvis up to 0.93, the waist's 0.96 row, the ribcage from 1.0, then the neck rows
    # above the ribcage's top. (In the game these are separate overlapping lofts per joint; fused they would leave
    # ledges where one tucks into the next.)
    neck_y = neutral("Neck")[10]
    rows = [r for r in tables["pelvis"] if r[0] <= 0.93]
    rows += [r for r in tables["waist"] if 0.93 < r[0] < 0.975]
    rows += [r for r in tables["chest"] if r[0] >= 0.995]
    rows += [[r[0] + neck_y] + list(r[1:]) for r in tables["neck"] if r[0] + neck_y > rows[-1][0] + 0.01]
    parts = [[section_ring(r, 24) for r in rows]]
    lengths = {"thigh": ("UpperLeg", 0.4), "calf": ("LowerLeg", 0.33), "upper_arm": ("UpperArm", 0.28),
               "forearm": ("LowerArm", 0.25)}
    for side in ("Left", "Right"):
        for k, (bone, length) in lengths.items():
            m = neutral(side + bone)
            rings = []
            for r in tables[k]:
                local = section_ring([r[0] * length] + list(r[1:]), 16, sign_y=-1.0)
                rings.append([xform(m, p) for p in local])
            parts.append(rings)
        # Mitten hand along the Hand bone: width along the bone's z (thumb to the front), thickness along its x.
        m = neutral(side + "Hand")
        palm = 1.0 if side == "Left" else -1.0  # bone +x points toward the body on the left arm, away on the right
        rings = []
        for u, w, t, curl in HAND[body]:
            ring = []
            for i in range(12):
                a = 2.0 * math.pi * i / 12
                ring.append(xform(m, (palm * (curl + t * math.cos(a)), -u, w * math.sin(a))))
            rings.append(ring)
        parts.append(rings)
        # Thumb: from the palm's front edge, down and forward.
        d = (0.25 * palm, -0.55, -0.8)
        dl = math.sqrt(sum(c * c for c in d))
        d = tuple(c / dl for c in d)
        e1 = (0.0, 0.0, 1.0) if abs(d[2]) < 0.9 else (1.0, 0.0, 0.0)
        e1 = _norm(_cross(d, e1))
        e2 = _cross(d, e1)
        start = (palm * 0.004, -0.028, -0.024)
        rings = []
        for s, r in THUMB[body]:
            c = tuple(start[i] + d[i] * s for i in range(3))
            ring = []
            for i in range(8):
                a = 2.0 * math.pi * i / 8
                ring.append(xform(m, tuple(c[j] + r * (e1[j] * math.cos(a) + e2[j] * math.sin(a)) for j in range(3))))
            rings.append(ring)
        parts.append(rings)
        # Foot: rings across Z, flat sole, rounded top.
        fx = neutral(side + "Foot")[9]
        rings = []
        for z, hw, top in FOOT[body]:
            ring = []
            for i in range(12):
                a = 2.0 * math.pi * i / 12
                s, c = math.sin(a), math.cos(a)
                y = top * 0.5 + top * 0.5 * math.copysign(abs(c) ** 0.7, c)
                ring.append((fx + hw * math.copysign(abs(s) ** 0.8, s), max(y, 0.0), z))
            rings.append(ring)
        parts.append(rings)
    return parts


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _norm(a):
    length = math.sqrt(sum(c * c for c in a))
    return tuple(c / length for c in a)


CAGE_SOP = '''
import json
geo = hou.pwd().geometry()
geo.addAttrib(hou.attribType.Point, "part", 0)
for part, rings in enumerate(json.loads(DATA)):
    ids = []
    for ring in rings:
        pts = geo.createPoints([hou.Vector3(p) for p in ring])
        for p in pts:
            p.setAttribValue("part", part)
        ids.append(pts)
    n = len(ids[0])
    for a, b in zip(ids, ids[1:]):
        for i in range(n):
            j = (i + 1) % n
            poly = geo.createPolygon()
            for p in (a[i], b[i], b[j], a[j]):
                poly.addVertex(p)
    for ring, rev in ((ids[0], False), (ids[-1], True)):
        poly = geo.createPolygon()
        for p in (reversed(ring) if rev else ring):
            poly.addVertex(p)
'''


def head_ring_part(body, rig):
    """Head placeholder: an ellipsoid of latitude rings whose crown is at HEAD_TOP."""
    rx, ry, rz = HEAD[body]
    cy = HEAD_TOP - ry
    rings = []
    for k in range(1, 12):
        lat = -math.pi / 2 + math.pi * k / 12
        y = cy + ry * math.sin(lat)
        r = math.cos(lat)
        rings.append([(rx * r * math.sin(2 * math.pi * i / 16), y, -0.006 + rz * r * math.cos(2 * math.pi * i / 16))
                      for i in range(16)])
    return rings


# --- bust and skeleton ------------------------------------------------------------------------------------------

BUST_VEX = '''
// AnimeOutfit.bust_height: two lobes over the ribcage (same apex, radii and height), raised outward.
float xa = abs(@P.x);
float dx = xa - %(ax)f;
float dy = @P.y - %(ay)f;
float u = dx / (dx > 0 ? %(r_out)f : %(r_in)f);
float v = dy / (dy > 0 ? %(r_up)f : %(r_down)f);
float d2 = u * u + v * v;
vector out = normalize(set(@P.x, 0.0, @P.z));  // outward from the torso axis (cage normals face inward)
if (i@part == 0 && d2 < 1.0 && out.z < 0.0) {  // the torso loft's front only
    float e = 1.15 + 0.45 * smooth(-0.3, 0.75, v);  // softer than the game's 0.78..2.28: no garment hides the rim here
    float h = %(h)f * pow(1.0 - d2, e);
    @P += normalize(set(out.x * 0.4, 0.0, -1.0)) * h * smooth(0.0, 0.5, -out.z);
}
'''

SKELETON_SOP = '''
import json
geo = hou.pwd().geometry()
joints = json.loads(DATA)
geo.addAttrib(hou.attribType.Point, "name", "")
geo.addAttrib(hou.attribType.Point, "transform", (1.0, 0, 0, 0, 1.0, 0, 0, 0, 1.0))
pts = {}
for j in joints:
    p = geo.createPoint()
    p.setPosition(j["p"])
    p.setAttribValue("name", j["name"])
    p.setAttribValue("transform", j["m"])
    pts[j["name"]] = p
for j in joints:
    if j["parent"]:
        poly = geo.createPolygon(is_closed=False)
        poly.addVertex(pts[j["parent"]])
        poly.addVertex(pts[j["name"]])
'''


def skeleton_data(body, rig, with_head_top=True):
    nodes = rig["nodes"]
    out = []
    for j in JOINTS:
        m = nodes[j]["neutral"]
        out.append({"name": j, "parent": nodes[j]["parent"], "p": m[9:12], "m": m[0:9]})
    if body == "female":
        for bone, pivot in sorted(rig["extra_bones"].items()):
            m = nodes[pivot]["neutral"]
            out.append({"name": bone, "parent": nodes[pivot]["parent"], "p": m[9:12], "m": m[0:9]})
    if with_head_top:
        out.append({"name": "HeadTop", "parent": "Head", "p": [0.0, HEAD_TOP, 0.0], "m": [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]})
    return out


# --- network ----------------------------------------------------------------------------------------------------

def setp(node, **parms):
    for k, v in parms.items():
        node.parm(k).set(v)
    return node


def build_body(body):
    tables, bust, rig = load_inputs(body)
    parts = build_cage(body, tables, rig) + [head_ring_part(body, rig)]
    obj = hou.node("/obj")
    old = obj.node("base_body_" + body)
    if old:
        old.destroy()
    geo = obj.createNode("geo", "base_body_" + body)
    cage = geo.createNode("python", "cage")
    cage.parm("python").set("DATA = %r\n" % json.dumps(parts, separators=(",", ":")) + CAGE_SOP)
    sub = setp(geo.createNode("subdivide", "catmull_clark"), iterations=2)  # winding is irrelevant: VDB rebuilds
    sub.setInput(0, cage)
    last = sub
    if bust:
        w = geo.createNode("attribwrangle", "bust")
        w.setInput(0, last)
        w.parm("class").set("point")
        w.parm("snippet").set(BUST_VEX % {"ax": bust["apex"][0], "ay": bust["apex"][1], "r_in": bust["r_in"],
                                          "r_out": bust["r_out"], "r_up": bust["r_up"], "r_down": bust["r_down"],
                                          "h": bust["h"]})
        last = w
    vdb = setp(geo.createNode("vdbfrompolygons", "to_sdf"), voxelsize=VOXEL)
    vdb.setInput(0, last)
    smo = setp(geo.createNode("vdbsmoothsdf", "soft_junctions"), iterations=3)
    smo.setInput(0, vdb)
    conv = setp(geo.createNode("convertvdb", "to_polygons"), conversion="poly")
    conv.setInput(0, smo)
    # Even, near-equilateral triangles at the budget (not PolyReduce's long slivers), so the game's region cuts
    # (HoudiniBody._region_cuts) follow clean lines and joints bend smoothly.
    red = setp(geo.createNode("remesh::2.0", "budget"), targetsize=REMESH_EDGE, iterations=3)
    red.setInput(0, conv)
    clean = geo.createNode("attribwrangle", "tag")
    clean.setInput(0, red)
    clean.parm("class").set("primitive")
    clean.parm("snippet").set('s@name = "body"; s@shop_materialpath = "/mat/skin";')
    snrm = setp(geo.createNode("normal", "smooth_normals"), type="typepoint")
    snrm.setInput(0, clean)
    skel_cap = geo.createNode("python", "skeleton_capture")
    skel_cap.parm("python").set("DATA = %r\n" % json.dumps(skeleton_data(body, rig, False)) + SKELETON_SOP)
    skel = geo.createNode("python", "skeleton")
    skel.parm("python").set("DATA = %r\n" % json.dumps(skeleton_data(body, rig, True)) + SKELETON_SOP)
    cap = geo.createNode("kinefx::jointcapturebiharmonic", "capture")
    cap.setInput(0, snrm)
    cap.setInput(1, skel_cap)
    try:
        cap.geometry()
        if cap.errors():
            raise hou.OperationFailed(" ".join(cap.errors()))
    except hou.Error as e:
        print("biharmonic capture failed, using proximity: %s" % e)
        cap.destroy()
        cap = setp(geo.createNode("kinefx::jointcaptureproximity", "capture"), maxinfluences=4)
        cap.setInput(0, snrm)
        cap.setInput(1, skel_cap)
    lim = setp(geo.createNode("capturecorrect", "body"), limitregions=1, maxregions=4, renormalize=1)
    lim.setInput(0, cap)  # 4 influences, normalized (as the Blender body); named "body" for the glTF mesh name
    cap = lim
    out = geo.createNode("output", "OUT")
    out.setInput(0, cap)
    out.setDisplayFlag(True)
    out.setRenderFlag(True)
    geo.layoutChildren()
    return geo, cap, skel


def export(body, cap, skel):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "base_body_%s.glb" % body).replace("\\", "/")
    rop = hou.node("/out").createNode("kinefx::gltfcharacter", "gltf_" + body)
    rop.parm("skingeosop").set(cap.path())
    rop.parm("captureposesop").set(skel.path())
    rop.parm("filepath").set(path)
    rop.parm("exportmeshname").set(1)
    rop.parm("exporttype").set("glb")
    rop.parm("customattribs").set(0)
    rop.render()
    return path


def stats(body, cap, skel):
    g = cap.geometry()
    tris = sum(max(p.numVertices() - 2, 0) for p in g.prims())
    bb = g.boundingBox()
    names = [p.attribValue("name") for p in skel.geometry().points()]
    print("base_body_%s.glb %d tris, %d points, height %.3f m, bounds x %.3f..%.3f z %.3f..%.3f" % (
        body, tris, len(g.points()), bb.maxvec()[1], bb.minvec()[0], bb.maxvec()[0], bb.minvec()[2], bb.maxvec()[2]))
    print("  bones (%d): %s" % (len(names), ", ".join(names)))
    return tris, names


# --- previews ---------------------------------------------------------------------------------------------------

VIEWS = [("front", 0.0), ("three_quarter", 35.0), ("side", 90.0)]
CLOSE = "--close" in sys.argv  # torso close-up instead of the full figure


def render_view(body, azimuth):
    hlib.MATERIALS["skin"] = SKIN
    geo, cap, skel = build_body(body)
    tmp = os.path.join(hlib.PREVIEWS, "_base_body_%s_%d.png" % (body, int(azimuth)))
    if CLOSE:
        hlib.preview(cap, tmp, res=(500, 800), azimuth=azimuth, elevation=6.0, radius=0.3, center=(0, 1.05, 0))
    else:
        hlib.preview(cap, tmp, res=(500, 800), azimuth=azimuth, elevation=6.0, radius=0.62, center=(0, 0.82, 0))


def previews(body):
    from PIL import Image
    tiles = []
    for _, az in VIEWS:
        tmp = os.path.join(hlib.PREVIEWS, "_base_body_%s_%d.png" % (body, int(az)))
        start = time.time()
        subprocess.run([sys.executable, os.path.abspath(__file__), "--view", body, str(az)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if os.path.exists(tmp) and os.path.getmtime(tmp) >= start - 1:
            tiles.append(tmp)
        else:
            print("PREVIEW FAILED %s %s" % (body, az))
    if not tiles:
        return None
    imgs = [Image.open(t).convert("RGB") for t in tiles]
    w, h = imgs[0].size
    sheet = Image.new("RGB", (w * len(imgs), h))
    for i, im in enumerate(imgs):
        sheet.paste(im, (i * w, 0))
    out = os.path.join(hlib.PREVIEWS, "base_body_%s.png" % body)
    sheet.save(out)
    for t in tiles:
        os.remove(t)
    return out


def main():
    if sys.argv[1:2] == ["--view"]:
        render_view(sys.argv[2], float(sys.argv[3]))
        return
    which = sys.argv[1] if len(sys.argv) > 1 else "both"
    bodies = ["female", "male"] if which == "both" else [which]
    hlib.MATERIALS["skin"] = SKIN
    hlib.ensure_materials()
    for body in bodies:
        geo, cap, skel = build_body(body)
        stats(body, cap, skel)
        print(export(body, cap, skel))
    hou.hipFile.save(HIP.replace("\\", "/"))
    for body in bodies:
        print(previews(body))


if __name__ == "__main__":
    main()
    sys.stdout.flush()
    os._exit(0)
