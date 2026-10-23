# Houdini base body (the default skin)

The skater's body is one seamless skinned mesh made in Houdini (`tools/houdini/base_body.py` on the
`houdini-assets` branch): `assets/characters/houdini/base_body_female.glb` and `base_body_male.glb`. It replaces the
code-built segmented skin (the `AnimeOutfit` lofts), which is still there as an option.

- `PlaceholderSkater.build_body(palette, {"skin": "houdini" | "code"})`. The default is `PlaceholderSkater.SKIN`
  (`"houdini"`). With `"code"` nothing changes from before.
- Kept from the code body: the joint rig (17 `SkaterPoser.JOINTS` plus the `BodySway_BustL/R` pivots), the anime head
  (`AnimeHead` under `HeadModel`) with its hair and `HairSway_*` pivots, the code hands (`HAND_SCALE`), every garment,
  and secondary motion. The `.glb`'s BustL/R bones follow the BodySway pivots, so the bust sways as before.
- `SkinnedBody` (`game/skater/skinned_body.gd`, a `SkeletonModifier3D`) copies the joint poses onto the bones each
  frame. Because it follows the joints, the poser, the ragdoll, the creator preview and the shop dressing room drive it
  with no changes.
- The mesh is named `SkinMesh` (meta `palette = "skin"`, `skinned = true`). It is drawn with the palette's `"skin"`
  material, so skin tone and the toon pass work as before.

## What the game does to the .glb (`game/skater/houdini_body.gd`)

The raw `.glb` has a placeholder head, thin paddle hands, automatic biharmonic weights and no garment regions.
`HoudiniBody.prepared(type)` turns it into what the game draws. The header of `houdini_body.gd` has the details:

1. **Cuts and caps.** Plane cuts go under the jaw, across the wrists and across the ankles. Each cut is closed with a
   small rounded cap (`head_cap`, `hand_X_cap`, `foot_X_cap`).
   - The head and hands are always hidden (`ALWAYS_HIDDEN`); the code head and hands sit over their caps.
   - The feet are hidden while shoes are on (`Wardrobe.FEET`).
   - The region borders are cut too, so a hidden region ends on a clean line.
2. **Regions.** Every triangle gets a region from the code skin's vocabulary (`AnimeOutfit.REGIONS`, with `_L/_R`),
   so `Wardrobe.dress` and every garment's `covers()` work unchanged. `SkinnedBody.set_hidden_regions` rebuilds the
   index buffer, and masked meshes are cached.
   - `thigh_top` has no surface on the fused body (`HoudiniBody.FUSED`).
3. **Weights.** Each region moves like the code piece (and the garment piece) it stands for:
   - torso bands by height
   - limbs on their joint, blending to the neighbour near the shared joint
   - the bust rigid on BustL/R
   - hips and knees split along the line between the code pieces and rigid on each side
4. **Fit.** Each region is pulled in to the code-skin shapes that the garments are lofted from. Where blended
   vertices swing out as a joint bends, they are pulled in a few millimetres more (`SHRINK`, `BLEND_SHRINK`,
   `ARMPIT_SHRINK`, `SEAM_SHRINK`). With this, `test_covered_skin_stays_inside_garment_in_every_pose` holds for the
   Houdini skin.

Processing takes about 4 s per body type, so it is baked:

```sh
tools/bake_houdini_body.sh     # writes assets/characters/houdini/base_body_<type>_prepared.res
```

- Re-bake after changing `houdini_body.gd` or a base-body `.glb`.
- `tests/unit/test_houdini_body.gd` fails while a bake is stale (it checks the MD5 of the source and of the `.glb`).
- At runtime, a missing bake, or one made from another `.glb`, falls back to processing at load and logs a warning.

## Tests

- The cover tests (`test_wardrobe`, `test_garments_*`) read the posed skin through `test_wardrobe.gd`'s
  `repose_skin(body)`. It builds one proxy mesh per region, under the region's home joint (`HoudiniBody.home_joint`),
  from the CPU-skinned pose (`SkinnedBody.posed_arrays`). The assertions are the same as for the code skin.
- `test_placeholder_skater` measures the drawn skinned triangles (hidden regions left out) in place of the code skin's
  per-joint meshes.

## Rough edges

- Hips and knees are rigid on each side of the line between the code pieces, like the code skin's overlapping
  pieces. In deep hip flexion (sitting, beyond the game's poses) a soft crease shows along that line.
- The proxies used by the cover test sample about 40 vertices per region, as the code skin's per-part meshes did.
  Checking every vertex still finds a few millimetre-scale misses at the crotch and armpit seams in grab poses. Those
  places are under shorts and sleeves.
