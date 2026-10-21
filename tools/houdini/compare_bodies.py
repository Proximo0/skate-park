"""Side-by-side render of the Blender and Houdini base bodies with the same camera and light.

Usage: hython tools/houdini/compare_bodies.py            -> previews/compare_bodies.png
       hython tools/houdini/compare_bodies.py --one <glb> <azimuth> <png>   (internal: one render per process)
"""
import os
import subprocess
import sys
import time

import hou

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hlib  # noqa: E402

GLBS = [("Blender", "assets/characters/base_body_%s.glb"), ("Houdini", "assets/characters/houdini/base_body_%s.glb")]
VIEWS = [0.0, 35.0, 90.0]


def render_one(glb, azimuth, png):
    hlib.MATERIALS["skin"] = (0.96, 0.80, 0.69)
    geo = hou.node("/obj").createNode("geo", "body")
    g = geo.createNode("gltf")
    g.parm("gltffile").set(glb.replace("\\", "/"))
    m = geo.createNode("attribwrangle")
    m.setInput(0, g)
    m.parm("class").set("primitive")
    m.parm("snippet").set('s@shop_materialpath = "/mat/skin";')
    m.setDisplayFlag(True)
    m.setRenderFlag(True)
    hlib.preview(m, png, res=(400, 760), azimuth=azimuth, elevation=6.0, radius=0.62, center=(0, 0.82, 0))


def main():
    from PIL import Image, ImageDraw
    tiles = []
    tmp = os.path.join(hlib.PREVIEWS, "_cmp")
    os.makedirs(tmp, exist_ok=True)
    for body in ("female", "male"):
        row = []
        for az in VIEWS:
            for label, rel in GLBS:
                png = os.path.join(tmp, "%s_%s_%d.png" % (body, label, az))
                start = time.time()
                subprocess.run([sys.executable, os.path.abspath(__file__), "--one",
                                os.path.join(hlib.ROOT, rel % body), str(az), png],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                ok = os.path.exists(png) and os.path.getmtime(png) >= start - 1
                row.append((label, body, png if ok else None))
        tiles.append(row)
    w, h = 400, 760
    sheet = Image.new("RGB", (w * len(tiles[0]), h * len(tiles)), (30, 30, 34))
    draw = ImageDraw.Draw(sheet)
    for r, row in enumerate(tiles):
        for c, (label, body, png) in enumerate(row):
            if png:
                sheet.paste(Image.open(png).convert("RGB"), (c * w, r * h))
            draw.rectangle((c * w + 8, r * h + 8, c * w + 150, r * h + 30), fill=(0, 0, 0))
            draw.text((c * w + 14, r * h + 13), "%s %s" % (label, body), fill=(255, 255, 255))
    out = os.path.join(hlib.PREVIEWS, "compare_bodies.png")
    sheet.save(out)
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)
    print(out)


if __name__ == "__main__":
    if sys.argv[1:2] == ["--one"]:
        render_one(sys.argv[2], float(sys.argv[3]), sys.argv[4])
    else:
        main()
    sys.stdout.flush()
    os._exit(0)
