"""Procedural wheelie bin with a separate lid. Usage: hython tools/houdini/trash_bin.py

HDA skatepark::trash_bin: seed, colour, size. Exports assets/props/houdini/trash_bin.glb
(meshes: bin, lid, wheels). About 0.6 x 0.6 x 1.0 m, wheels and handle at the back (+Z).
"""
import hlib


def build(b):
    b.box("body", (0.54, 0.84, 0.58), (0, 0.5, 0), "plastic", "bin", bevel=0.035, divs=2,
        taper=(0.86, 0.86, 0.0), taper_below=True)
    b.box("rim", (0.6, 0.06, 0.64), (0, 0.9, 0), "plastic", "bin", bevel=0.015, divs=1)
    b.box("handle", (0.46, 0.05, 0.05), (0, 0.86, 0.34), "trim", "bin", bevel=0.015, divs=1)
    b.box("lid", (0.62, 0.05, 0.66), (0, 0.955, 0.0), "plastic", "lid", bevel=0.018, divs=2)
    b.box("lid_grip", (0.2, 0.025, 0.04), (0, 0.94, -0.34), "trim", "lid", bevel=0.008, divs=1)
    b.cyl("axle", 0.015, 0.56, (0, 0.08, 0.27), "metal", "wheels", cols=6, rows=1)
    for sx in (-1, 1):
        b.cyl("wheel%d" % (sx + 1), 0.08, 0.06, (sx * 0.27, 0.08, 0.27), "tire", "wheels", cols=12, bevel=0.012, divs=1)
        b.cyl("hub%d" % (sx + 1), 0.045, 0.065, (sx * 0.27, 0.08, 0.27), "rim", "wheels", cols=8, rows=1)
    b.finish()


COLOUR = (0.18, 0.45, 0.26)
VARIANTS = [("trash_bin.glb", {"colour": COLOUR}, {"plastic": COLOUR})]


def make():
    return hlib.make_asset("trash_bin", "trash_bin", "Skate Park Trash Bin", hlib.hda_parms(colour=COLOUR), build)


if __name__ == "__main__":
    hlib.run(make, VARIANTS)
