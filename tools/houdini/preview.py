"""Render one preview PNG. Usage: hython tools/houdini/preview.py <module> <variant index>

The OpenGL ROP crashes on a second render in the same hython session, so
build_all.py runs this once per variant in its own process.
"""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hlib  # noqa: E402

mod = importlib.import_module(sys.argv[1])
fname, parms, mats = mod.VARIANTS[int(sys.argv[2])]
node = mod.make()
hlib.apply(node, parms)
for k, v in getattr(mod, "PREVIEW_PARMS", {}).items():
    node.parm(k).set(v)
az, el = getattr(mod, "PREVIEW_VIEW", (35.0, 20.0))
hlib.preview(node, os.path.join(hlib.PREVIEWS, fname.replace(".glb", ".png")), mats, azimuth=az, elevation=el)
sys.stdout.flush()
os._exit(0)  # skip hython teardown, which segfaults after an OpenGL render
