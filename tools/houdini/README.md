# Houdini props pilot

Procedural props built in Houdini 22.0 (Indie licence) with hython. Each generator builds a SOP network,
saves it as an HDA in `otls/`, and exports glTF binary to `assets/props/houdini/`.
Assets are in metres, Y-up, with the origin at the ground centre and the front facing -Z.
Materials are flat-colour Principled shaders with plain names; Godot applies its own toon shader.

## Regenerate

```
set HY="C:\Program Files\Side Effects Software\Houdini 22.0.466\bin\hython.exe"
%HY% tools\houdini\build_all.py              :: every glb, every HDA, previews and the contact sheet
%HY% tools\houdini\build_all.py --no-previews
%HY% tools\houdini\car.py                    :: or just one asset
%HY% tools\houdini\preview.py car 0          :: one preview: <module> <variant index>
```

hython can segfault while shutting down after an OpenGL render. The outputs are already written by then,
so the crash is harmless. `preview.py` therefore renders one image per process.

## Assets

| File | HDA | Parameters | Meshes |
|---|---|---|---|
| car_hatchback.glb, car_pickup.glb | skatepark::car | style, seed, colour, size | body, wheel_fl/fr/rl/rr |
| trash_bin.glb | skatepark::trash_bin | seed, colour, size | bin, lid, wheels |
| litter_kit.glb | skatepark::litter_kit | seed, size, layout | 10 items, each at the origin |
| litter_scatter_example.json | skatepark::litter_scatter | seed, count, areax, areaz | instance points |
| graffiti_wall.glb | skatepark::graffiti_wall | seed, size | wall (Cd weathering, decal UVs) |

- The `colour` parameter drives the `body` material on cars and the `plastic` material on the bin when the glb is exported.
- Graffiti wall UVs: the front face (-Z) spans 0..1, so a decal texture maps across the whole wall. The back face is mirrored.
- Litter scatter JSON: `{"item", "position" [x, y, z], "yaw_deg", "scale"}` for each point. `item` is a mesh name in litter_kit.glb.
- To add a variant, add a row to the module's `VARIANTS` list: (glb name, HDA parms, material colour overrides).

Files: `hlib.py` (shared builder, materials, export, preview), one module per asset, `preview.py`, `build_all.py`.
Previews are in `previews/`, with all of them together in `contact_sheet.png`.
