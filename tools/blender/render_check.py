"""Render check of the exported base bodies: imports base_body_<type>.glb and renders it (Cycles on the CPU, so it
runs headless without a GPU or EGL) from the front, side, three-quarter and back, then in test poses (bent knees,
crouch, raised arms) built by rotating the imported bones. Writes <out>/<type>_<view>.png plus two contact sheets
<out>/<type>_sheet_rest.png and <out>/<type>_sheet_pose.png.

Run:  /tmp/lead/bpyenv/bin/python tools/blender/render_check.py --out /tmp/lead/blender [--body female|male|both]
      [--glb-dir assets/characters] [--samples 24] [--res 520]
Godot space (Y up, faces -Z) is Blender (x, -z, y): the body faces Blender +Y.
"""

import argparse
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

VIEWS = {  # camera position, look-at (Blender space), focal length mm
    "front": ((0.0, 4.6, 0.95), (0.0, 0.0, 0.76), 88.0),
    "side": ((4.6, 0.0, 0.95), (0.0, 0.0, 0.76), 88.0),
    "threeq": ((2.9, 3.5, 1.25), (0.0, 0.0, 0.76), 88.0),
    "back": ((-1.0, -4.5, 1.05), (0.0, 0.0, 0.76), 88.0),
    "torso": ((0.9, 1.7, 1.25), (0.0, 0.0, 1.12), 75.0),
}
POSE_VIEWS = {
    "front": ((1.2, 4.4, 1.0), (0.0, 0.0, 0.75), 80.0),
    "side": ((4.6, 0.6, 0.95), (0.0, 0.0, 0.75), 80.0),
}


def setup_scene(samples, res):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.seed = 1
    sc.cycles.use_denoising = True
    sc.render.resolution_x = res
    sc.render.resolution_y = int(res * 1.4)
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.62, 0.72, 0.85, 1.0)
    bg.inputs["Strength"].default_value = 0.55
    sc.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 2.6
    sun.data.angle = math.radians(8.0)
    sun.rotation_euler = (math.radians(50), 0.0, math.radians(150))
    sc.collection.objects.link(sun)
    rim = bpy.data.objects.new("Rim", bpy.data.lights.new("Rim", "SUN"))
    rim.data.energy = 1.4
    rim.rotation_euler = (math.radians(65), 0.0, math.radians(-30))
    sc.collection.objects.link(rim)
    ground = bpy.data.meshes.new("Ground")
    ground.from_pydata([(-40, -40, 0), (40, -40, 0), (40, 40, 0), (-40, 40, 0)], [], [(0, 1, 2, 3)])
    g = bpy.data.objects.new("Ground", ground)
    gm = bpy.data.materials.new("GroundMat")
    gm.diffuse_color = (0.55, 0.58, 0.6, 1.0)
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.32, 0.35, 0.38, 1.0)
    ground.materials.append(gm)
    sc.collection.objects.link(g)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    return sc, cam


def import_body(path):
    bpy.ops.import_scene.gltf(filepath=path)
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Ground")
    for poly in mesh.data.polygons:
        poly.use_smooth = True
    return arm, mesh


def aim(cam, pos, target, lens):
    cam.location = Vector(pos)
    d = Vector(target) - Vector(pos)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens


def render(sc, path):
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def rotate_world(arm, bone, axis, deg):
    """Rotates a pose bone (and so its children) about its current head by deg around a Blender-space axis."""
    pb = arm.pose.bones[bone]
    bpy.context.view_layer.update()
    m = pb.matrix.copy()
    head = m.translation.copy()
    r = Matrix.Rotation(math.radians(deg), 4, Vector(axis))
    pb.matrix = Matrix.Translation(head) @ r @ Matrix.Translation(-head) @ m
    bpy.context.view_layer.update()


def reset_pose(arm):
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    arm.location = (0, 0, 0)
    bpy.context.view_layer.update()


def pose(arm, name):
    """Test poses. Axes are Blender's: +X is the body's right, +Y its front, +Z up."""
    reset_pose(arm)
    X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
    if name == "bentknees":  # skate stance: knees bent, slight hip hinge, arms relaxed forward
        for s in ("Left", "Right"):
            rotate_world(arm, s + "UpperLeg", X, 40)
            rotate_world(arm, s + "LowerLeg", X, -75)
            rotate_world(arm, s + "Foot", X, 35)
        rotate_world(arm, "Spine", X, 12)
        rotate_world(arm, "LeftLowerArm", X, 45)
        rotate_world(arm, "RightLowerArm", X, 45)
        arm.location.z = -0.1
    elif name == "crouch":  # deep crouch: thighs near horizontal, chest forward, arms reaching to the knees
        for s in ("Left", "Right"):
            rotate_world(arm, s + "UpperLeg", X, 95)
            rotate_world(arm, s + "LowerLeg", X, -130)
            rotate_world(arm, s + "Foot", X, 35)
        rotate_world(arm, "Spine", X, 20)
        rotate_world(arm, "Chest", X, 15)
        rotate_world(arm, "LeftUpperArm", X, 55)
        rotate_world(arm, "RightUpperArm", X, 55)
        rotate_world(arm, "LeftLowerArm", X, 50)
        rotate_world(arm, "RightLowerArm", X, 50)
        arm.location.z = -0.37
    elif name == "armsup":  # both arms raised overhead, one elbow bent, head turned
        rotate_world(arm, "LeftUpperArm", Y, 75)
        rotate_world(arm, "RightUpperArm", Y, -75)
        rotate_world(arm, "LeftLowerArm", Y, 20)
        rotate_world(arm, "RightLowerArm", X, -70)
        rotate_world(arm, "Spine", Z, 15)
        rotate_world(arm, "Head", Z, 50)
        rotate_world(arm, "LeftUpperLeg", X, 25)
        rotate_world(arm, "LeftLowerLeg", X, -40)
    bpy.context.view_layer.update()


def sheet(paths, out, cols):
    imgs = []
    for p in paths:
        im = bpy.data.images.load(p)
        w, h = im.size
        a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        imgs.append(a)
        bpy.data.images.remove(im)
    h, w = imgs[0].shape[:2]
    rows = (len(imgs) + cols - 1) // cols
    canvas = np.ones((rows * h, cols * w, 4), dtype=np.float32)
    for i, a in enumerate(imgs):
        r, c = divmod(i, cols)
        canvas[(rows - 1 - r) * h:(rows - r) * h, c * w:(c + 1) * w] = a  # Blender pixels start at the bottom
    img = bpy.data.images.new("sheet", cols * w, rows * h, alpha=True)
    img.pixels = canvas.ravel().tolist()
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/lead/blender")
    ap.add_argument("--body", default="both", choices=["female", "male", "both"])
    ap.add_argument("--glb-dir", default=os.path.join(ROOT, "assets", "characters"))
    ap.add_argument("--samples", type=int, default=24)
    ap.add_argument("--res", type=int, default=520)
    ap.add_argument("--only", default="", help="comma list of views/poses to render")
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)
    only = set(filter(None, args.only.split(",")))
    for body in (["female", "male"] if args.body == "both" else [args.body]):
        sc, cam = setup_scene(args.samples, args.res)
        arm, mesh = import_body(os.path.join(args.glb_dir, "base_body_%s.glb" % body))
        rest = []
        for view, (pos, tgt, lens) in VIEWS.items():
            if only and view not in only:
                continue
            aim(cam, pos, tgt, lens)
            p = os.path.join(args.out, "%s_%s.png" % (body, view))
            render(sc, p)
            rest.append(p)
        if rest:
            sheet(rest, os.path.join(args.out, "%s_sheet_rest.png" % body), len(rest))
        posed = []
        for pname in ("bentknees", "crouch", "armsup"):
            if only and pname not in only:
                continue
            pose(arm, pname)
            for view, (pos, tgt, lens) in POSE_VIEWS.items():
                aim(cam, pos, tgt, lens)
                p = os.path.join(args.out, "%s_pose_%s_%s.png" % (body, pname, view))
                render(sc, p)
                posed.append(p)
        if posed:
            sheet(posed, os.path.join(args.out, "%s_sheet_pose.png" % body), 2 if len(posed) < 6 else 6)
        print("render_check: %s -> %d renders" % (body, len(rest) + len(posed)))


if __name__ == "__main__":
    main(sys.argv[1:])
