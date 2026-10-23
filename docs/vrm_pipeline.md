# VRM body pipeline

The lead skater is drawn by a VRoid avatar instead of the Houdini/lofted body. The code rig (the joint Node3Ds that
`PlaceholderSkater.build_body` makes and `SkaterPoser` animates) still drives everything: physics, poses, IK targets,
BodySway pivots, shoes. The VRM skeleton just follows it.

| body   | file                                        | source            | scale | standing height |
|--------|---------------------------------------------|-------------------|-------|-----------------|
| female | `assets/characters/vrm/lead_female.vrm`     | VRoid AvatarSample_G | 0.93 | ~1.62 m |
| male   | `assets/characters/vrm/lead_male.vrm`       | VRoid Base_Male   | 0.98  | ~1.69 m |

Addons: `addons/vrm` (godot-vrm) and `addons/Godot-MToon-Shader`, both enabled in `project.godot`.

## Selecting the skin

- `PlaceholderSkater.SKIN = "vrm"` is the default. `opts["skin"] = "houdini"` picks the old body (with `AnimeHead`).
- If the `.vrm` file is missing the builder falls back to Houdini.
- The chosen skin is stored in `rig["skin"]` and as meta `"skin"` on the body root.
- Tests that exercise the lofted garments raise `PlaceholderSkater.houdini_scopes` in `_init` and lower it on
  `PREDELETE`; while it is > 0 the default is Houdini.

## Attach (`VrmBody.attach(body, kind, mats)`)

1. Instance the VRM as child `VrmModel` of the body, `Basis(UP, PI)` (VRM faces +Z, the rig faces -Z) times the scale.
2. Add `VrmDriver` (a `SkeletonModifier3D`, this class) under the skeleton.
3. `prepare()` swaps meshes/materials, `bind()` computes the retarget, `sync_pose()` poses the first frame.
4. The code hand meshes are hidden; the code shoes stay (see Outfit).

`VrmBody` re-binds itself when it finds itself in a duplicated tree (`PedBody.clone`), walking up to the node with meta
`body_type`.

## Retarget math

For every humanoid bone with a code joint:

- `N` = the joint's neutral basis (identity, except the arm chains: `Basis(BACK, -/+PI/2)` because the code T-pose is
  arms down and the VRM rest is arms out).
- `Kr` = the model basis (PI about Y), `Rb` = the bone's global rest basis.
- Correction `C = N^-1 * Kr * Rb`, computed once in `bind()`.
- Each frame, with the joint's body-space basis `J`: bone global basis `= Kr^-1 * J * C`.

So the neutral code pose maps exactly to the VRM rest (test `test_neutral_pose_maps_to_rest`).

Positions: hips come from the code Hips joint (`_k * hips_rest - (0, HIP_HEIGHT + lift_drop, 0)`); everything else
hangs off its parent with the rest offsets times the uniform scale. On top:

- **Legs**: always two-bone IK to the code ankle with the pole at the code knee, so the feet sit exactly on the code
  ankles (< 2 mm) and the shoes, which ride the code Foot joints, line up. The foot bone is scaled by `FOOT_SHRINK` so
  the VRoid foot fits inside the skate shoe.
- **Arms**: FK normally, `ARM_SPREAD` rotates the upper arm out a little so the hands clear the hips. While a grip
  weight is > 0.01 (`SkaterPoser._current["grip_L/R"]`), two-bone IK pulls the wrist toward the code wrist; if the
  target is out of reach the Spine bends forward up to `MAX_REACH_BEND` (bisection) and the chain is re-evaluated.
- **Fingers**: no code joints. A relaxed curl (`CURL_RELAXED`) blends to a grip curl (`CURL_GRIP`) with the grip weight;
  curl axis is `bone_dir x DOWN`.
- **Unmapped bones** (eyes, toes, upper chest etc.) keep their rest relative to the parent.
- **Bust**: `J_Sec_*_Bust1` follow the `BodySway_BustL/R` pivots (rest-relative delta, gain `BUST_GAIN`), so the
  existing `SecondaryMotion` spring drives them.

Modifier results are not persisted on the skeleton, so `bone_body_transform()` reads the driver's `_globals` cache, not
`Skeleton3D.get_bone_global_pose`.

## Secondary motion

- Hair keeps the VRM spring bones (VRMSecondary runs after regular modifiers, so it sees our pose).
- Bust and Skirt spring chains are removed (`_trim_springs`): the bust is driven by `SecondaryMotion`, and the skirt
  springs flew up and showed underwear. Sleeve chains go too when the bikini is on (no sleeves).
- Blink: blend shape ending `_Fcl_EYE_Close`, random gaps `BLINK_GAPS`, `BLINK_TIME` long.
- Bust levels (`SecondaryMotion.BUST_LEVELS`, setting `GameSettings.body_level`, pause menu "Body physics"):
  Off / Subtle / Normal (default) / Bouncy. Offsets are clamped per level so the bust never clips the bikini or arms.

## Outfit (Teen rating: never nude)

Texture files live in `assets/characters/vrm/textures/` (owned by the texture worker). Both naming schemes are read:

| purpose      | names tried                                                            |
|--------------|------------------------------------------------------------------------|
| bikini skin  | `lead_female_body_bikini_<colour>.png`, `body_skin_bikini_<colour>.png` |
| golden hair  | `hair_main`, `hair_main2`, `hair_back`, `ribbon` (+ `_shade`, `_emission`), params in `hair_gold_params.json` |
| iris         | `eye_iris.png`                                                         |

Rules in `prepare()`:

- The model's `_Shoes_` surfaces are always dropped; the game's skate shoes (Wardrobe slot `shoes`) are worn instead.
- The dress (`_Onepice_` surfaces) is dropped **only** when a bikini skin file exists; the bikini colour is the
  nearest of `BIKINI_COLOURS` to the outfit's top colour. Without the file the dress stays on.
- `_SKIN` materials get the palette skin tint (`skin_tint`, relative to `SKIN_REFERENCE`); female hair gets `HAIR_TINT`.
- `_SKIN` materials lose their `_SphereAdd` matcap: the additive sheen blew out into a flat cream patch on bent limbs
  seen from low cameras (inner thigh in a crouch, wrists), which read as a garment patch.
- All materials are duplicates (cached per source + swaps); meshes are copied and tagged meta `"vrm"`.
- `test_never_nude` checks that every body draws either its clothes or the bikini skin.

`Wardrobe.dress()` only fits `VRM_SLOTS = ["shoes"]` on a VRM rig; tops, bottoms, socks and hair garments are skipped.

**Toon guard**: `Toon.apply_to` sets `material_override` on every mesh, which whitens MToon. `VrmBody` clears it on its
meshes every frame. Cleaner: have `Toon` skip meshes with meta `"vrm"`.

## Wardrobe follow-up

The lofted garments are fitted to the Houdini body and do not fit the VRoid mesh. Options:

1. Export VRoid outfit variants (hoodie, shorts, ...) as extra `.vrm` files and swap meshes on the same skeleton.
2. Texture-painted variants of the body texture (like the bikini), chosen per outfit colour.
3. Re-fit the lofted garments to VRM bone weights (most work).

## Tests and tools

- `tests/unit/test_vrm_body.gd`: default skin, adult height, rest mapping, ankles on code ankles in every pose, grab
  reach, never nude, bust follows pivots, texture lookup.
- `tests/unit/test_secondary_motion.gd`: bust levels.
- Pose grids: a headless harness that builds the skater, applies `SkaterPoser.pose_for(...)`, calls `sync_pose()` and
  renders front / side / 3/4 / below views (`xvfb-run -a godot --rendering-driver opengl3`).

## Export

The `.vrm` files import as scenes through the godot-vrm import plugin. `tools/export_windows.sh` builds fine with both
addons; the imported scenes and MToon shaders are packed like any other resource.
