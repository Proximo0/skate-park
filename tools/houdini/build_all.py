"""Regenerate every Houdini prop, its HDA, its preview and the contact sheet.

Usage: hython tools/houdini/build_all.py [--no-previews]
"""
import importlib
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hlib  # noqa: E402

MODULES = ["car", "trash_bin", "litter", "graffiti_wall"]


def previews(mods):
    """One hython process per preview: the OpenGL ROP is not safe to reuse in-process."""
    pngs = []
    script = os.path.join(hlib.TOOLS, "preview.py")
    for name in mods:
        mod = importlib.import_module(name)
        for i, (fname, _, _) in enumerate(mod.VARIANTS):
            png = os.path.join(hlib.PREVIEWS, fname.replace(".glb", ".png"))
            start = time.time()
            subprocess.run([sys.executable, script, name, str(i)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if os.path.exists(png) and os.path.getmtime(png) >= start - 1:
                pngs.append(png)
            else:
                print("PREVIEW FAILED %s" % fname)
    return pngs


def contact_sheet(pngs, out, cols=3):
    from PIL import Image, ImageDraw
    tiles = [Image.open(p).convert("RGB") for p in pngs]
    w, h = tiles[0].size
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows), (40, 40, 44))
    draw = ImageDraw.Draw(sheet)
    for i, (img, p) in enumerate(zip(tiles, pngs)):
        x, y = (i % cols) * w, (i // cols) * h
        sheet.paste(img, (x, y))
        draw.text((x + 12, y + 10), os.path.basename(p)[:-4], fill=(255, 255, 255))
    sheet.save(out)
    return out


def main():
    totals = {}
    for name in MODULES:
        mod = importlib.import_module(name)
        totals.update(mod.run() if hasattr(mod, "run") else hlib.run(mod.make, mod.VARIANTS))
        if hasattr(mod, "scatter_json"):
            mod.scatter_json()
    if "--no-previews" not in sys.argv:
        pngs = previews(MODULES)
        if pngs:
            print(contact_sheet(pngs, os.path.join(hlib.PREVIEWS, "contact_sheet.png")))
    print("built %d glb files, %d triangles total" % (len(totals), sum(totals.values())))


if __name__ == "__main__":
    main()
    sys.stdout.flush()
    os._exit(0)
