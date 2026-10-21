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
| car_hatchback.glb, car_pickup.glb, car_surfvan.glb | skatepark::car | style, seed, colour, size | body, wheel_fl/fr/rl/rr (+ surfboard on the van) |
| trash_bin.glb | skatepark::trash_bin | seed, colour, size | bin, lid, wheels |
| litter_kit.glb | skatepark::litter_kit | seed, size, layout | 10 items, each at the origin |
| litter_scatter_example.json | skatepark::litter_scatter | seed, count, areax, areaz | instance points |
| graffiti_wall.glb | skatepark::graffiti_wall | seed, size | wall (coping cap, seeded corner chips, Cd weathering, decal UVs) |

- Cars: wheel arches are cut with Booleans (dark liners), the greenhouse has glass between A/B/C pillars, the wheels
  have tyre sidewalls, a rim and five spokes, and there are door seams, handles, bezelled lamps and blank plates.
- The trash bin's `lid` node has its origin on the hinge axis (0, 0.93, 0.33), so rotating it about X opens the lid.
  `hlib.set_pivot` applies this to the glb after export, because the glTF ROP writes identity node transforms.
- The litter cans and cup get their print, rims and lip from vertex colour (COLOR_0) on a white `can` material. In Godot,
  enable "Vertex Color > Use as Albedo" on the material if the importer doesn't already.
- The `colour` parameter drives the `body` material on cars and the `plastic` material on the bin when the glb is exported.
- Graffiti wall UVs: the front face (-Z) spans 0..1, so a decal texture maps across the whole wall. The back face is mirrored.
- Litter scatter JSON: `{"item", "position" [x, y, z], "yaw_deg", "scale"}` for each point. `item` is a mesh name in litter_kit.glb.
- To add a variant, add a row to the module's `VARIANTS` list: (glb name, HDA parms, material colour overrides).

Files: `hlib.py` (shared builder, materials, export, preview), one module per asset, `preview.py`, `build_all.py`.
Previews are in `previews/`, with all of them together in `contact_sheet.png`.

## Base body (KineFX)

`base_body.py` builds the skinned base body for a side-by-side comparison with `tools/blender/base_body.py`:

```
%HY% tools\houdini\base_body.py both          :: or female / male; also saves tools\houdini\base_body.hip
```

- Inputs: the joint dump `tools/blender/rig_rest.json` (model pose = the "neutral" transforms, A-pose arms) and the
  skin section tables in `game/skater/anime_outfit.gd`. The tables are read when the script runs, so table edits flow through.
- Method: a Python SOP lofts a quad cage from the section rows: one continuous torso (pelvis, waist row, ribcage, neck), and limbs
  along their bones (y = -t x length), plus mitten hands, feet and a head placeholder (0.15 m wide, 0.225 m tall,
  crown at 1.61 m). Next, Subdivide (Catmull-Clark x2), the female bust field (`AnimeOutfit.bust_height` apex, radii
  and height, with softer exponents), then VDB from polygons, smooth SDF and convert to fuse everything into one
  skin. PolyReduce brings it to about 10k triangles.
- Rig: the 17 SkaterPoser joints, BustL/BustR on the BodySway pivots (female only), and a non-deforming HeadTop. Joint Capture
  Biharmonic, then Capture Correct (4 influences, normalized), then ROP glTF Character.
- Output: `assets/characters/houdini/base_body_<body>.glb` and previews `previews/base_body_<body>.png` (front,
  three-quarter, side).
- Not yet matched to the Blender body: region tags (TEXCOORD_1 garment masks), the scripted weight fix-ups, and the
  byte-identical output guarantee.
