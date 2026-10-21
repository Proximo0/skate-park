# Blender character pipeline (pilot)

> The game's default body is now the Houdini base body (`docs/houdini_pipeline.md`). The Blender bodies below are
> still loadable through `SkinnedBody.attach(body, type, "blender")` and covered by `test_skinned_body`.

Base bodies are modelled, rigged, weighted and exported by scripts in `tools/blender/`, run in Blender as a Python
module (headless, no GUI). Output: `assets/characters/base_body_female.glb` and `base_body_male.glb`, driven at
runtime by `SkinnedBody` (`game/skater/skinned_body.gd`) from the code-built joint rig.

## Setup: the bpy venv (Python 3.13 required)

The `bpy` wheel for Blender 5.2 needs Python 3.13 exactly.

```sh
python3.13 -m venv /tmp/lead/bpyenv
/tmp/lead/bpyenv/bin/pip install bpy          # Blender 5.2.x as a module, about 400 MB
/tmp/lead/bpyenv/bin/python -c "import bpy; print(bpy.app.version_string)"
```

Any path works; the scripts only need that interpreter (`BPY=... tools/blender/build.sh`). The session hook does
not create it yet. These scripts are the one exception to "tools use the standard library only": they run inside bpy.

Rendering: `render_check.py` uses Cycles on the CPU because EEVEE and Workbench need `libEGL.so.1`, which the
container lacks (`apt-get install libegl1` would enable them).

## Rebuild

```sh
tools/blender/build.sh [--render /tmp/lead/blender]
```

1. Import (under `/tmp/skate_import.lock`), then `tools/blender/dump_rig.gd` dumps the code rig to
   `tools/blender/rig_rest.json`: each SkaterPoser joint and BodySway_Bust pivot, its parent, its rest transform and
   its model-pose transform (`SkinnedBody.neutral_globals`).
2. `base_body.py` reads the skeleton constants from `placeholder_skater.gd`, `REGIONS`/`NEUTRAL_ARM` from
   `skinned_body.gd` and `JOINTS` from `skater_poser.gd`, and stops if the dump is stale. It box-models a quad cage,
   subdivides it once (limit surface), adds the bust as a smooth displacement, tags regions, builds the armature,
   binds with automatic weights, fixes the weights and exports. Output is byte-identical run to run.
3. Re-import so Godot picks up the new .glb files.
4. Optional: `render_check.py` renders front, side, three-quarter, back, torso, plus bent-knee, crouch and
   raised-arm poses into `<dir>/<body>_*.png` and contact sheets.

Edit forms in `SPEC` at the top of `base_body.py`. Heights are for the default skeleton and are remapped
onto the actual joint heights, so changing the constants in `placeholder_skater.gd` reshapes the body.

## Model pose and skeleton contract

- The model pose has every joint at its rest offset with zero rotation (straight legs, straight elbows), except
  the upper arms, which hang out at `SkinnedBody.NEUTRAL_ARM` (0.65 rad A pose). The code rig's own rest pose
  (staggered feet, bent elbows) differs only in rotations. SkinnedBody bridges the difference:
  `bone_global = joint_global * inverse(joint_model_pose) * bone_global_rest`.
- Bones: the 17 `SkaterPoser.JOINTS` (same names and parents, heads on the joints), `BustL`/`BustR` (female only;
  heads on `BodySway_BustL/R`, children of Chest) and `HeadTop` (non-deforming crown marker at 1.61 m).
- Space: Godot Y up, metres, the body faces -Z, Left = -X. In Blender the body faces +Y, with Z up.
- Skin: 4 influences, normalized. Automatic heat weights, then scripted fixes: smooth elbow and knee blends
  (about ±3.5 cm), wrists and ankles kept on the forearm and shin (no candy-wrapper from hand or foot twist), a
  shoulder blend across a near-vertical plane through the joint, the bust on Chest plus BustL/R, a Chest > Neck >
  Head blend up the neck, and no weights from the other side's limbs.

## Regions (garment masking)

Each face has exactly one region, in the order of `SkinnedBody.REGIONS`: neck, chest_upper, bust, under_bust, waist,
pelvis, glutes, upper_arm_L/R, forearm_L/R, hand_L/R, thigh_upper_L/R, thigh_lower_L/R, knee_L/R, calf_L/R,
ankle_L/R, foot_L/R. In the .blend the regions are vertex groups. In the .glb the region index is in the
second UV map (`TEXCOORD_1`, which Godot imports as UV2.x = index + 0.5). The exporter splits vertices on region
borders, so every triangle has one region and the normals stay smooth. `SkinnedBody.set_hidden_regions()` drops
those triangles from the index buffer once, at dress time.

## Garments (next step)

Model each garment in the same .blend (or one that links the base body and armature) as its own mesh around the
model-pose body, offset 2-6 mm outside it:
- Weights: copy them from the body with a Data Transfer modifier (vertex groups, nearest face interpolated),
  apply it, then clean up and limit to 4 influences. Use the same armature, so one Skeleton3D drives body and
  garments.
- Coverage: list the regions the garment fully encloses (a custom property `covers` on the object, exported as
  glTF extras). At runtime, hide those regions on the body. Only list a region that is covered all the way round,
  in every pose.
- Export each garment as its own .glb (mesh plus a copy of the armature), or several garments in one .glb as
  separate meshes. In Godot, parent each garment MeshInstance3D under the body's Skeleton3D and set
  `skeleton = ..` and `skin` from its import.

## Godot import settings (`assets/characters/*.glb.import`)

- `meshes/force_disable_compression=true`: keeps UV2 region ids and the positions exact.
- `meshes/generate_lods=false`: LODs would only apply to the unmasked mesh, and 10k triangles do not need them.
- Everything else uses the defaults (skins named, no animation).
- Blender export settings, in `export_glb()`: GLB, +Y up, selected only, no modifiers applied (the armature stays a
  skin), normals and both UV maps, no tangents, one material, all bones (HeadTop included), at most 4 influences,
  extras on, rest-position armature.
