# Art spec for generated 3D art

This is the brief for making 3D models with AI tools. Each piece is one file, dropped into `art/` under its slot name (see the table at the end). The game uses it automatically; a missing file just means the built-in placeholder shows.

## File format and export

- Format: **glTF 2.0 Binary, `.glb`**. One self-contained file, textures embedded.
- Units: **1 unit = 1 metre.**
- Axes: **Y up. Forward is -Z.** Models face -Z.
- Scale: apply all transforms before export (scale 1, rotation 0 on the root).
- Include animations and the skin when the piece has them. Nothing else in the file needs names beyond what this page lists.

## Skater (slots `skater_body`, `skater_board`)

### Skater body
- A cartoon kid, about **1.3 m tall**, with a big head.
- Facing **-Z**.
- Skeleton bone names must be **exactly** these (they match Godot's humanoid skeleton, so Mixamo-style rigs retarget correctly):

  `Root, Hips, Spine, Chest, UpperChest, Neck, Head, LeftShoulder, LeftUpperArm, LeftLowerArm, LeftHand, RightShoulder, RightUpperArm, RightLowerArm, RightHand, LeftUpperLeg, LeftLowerLeg, LeftFoot, LeftToes, RightUpperLeg, RightLowerLeg, RightFoot, RightToes`

  Bones you do not need can be left out, but the names that are present must match exactly. Upper and Lower names are case-sensitive.
- Required animations (name each glTF animation exactly as shown):

  `idle_ride`, `push`, `crouch`, `ollie`, `land`, `bail_fall`, `bail_getup`, `manual`, `nose_manual`, `grind_5050`, `grind_board`, `grab_generic`, `flip_generic`, `lip_stall`, `wallride`, `celebrate`

- Poly budget: **15,000 triangles or fewer.**
- Texture budget: **1024 x 1024 px** total for the character.

### Board
- Deck: **0.8 m long**. Origin at the **centre of the deck's bottom surface**.
- Nose points toward **-Z**.
- Each wheel is a separate node named exactly `Wheel_FL`, `Wheel_FR`, `Wheel_BL`, `Wheel_BR` (front left, front right, back left, back right). Wheel origins at their axle centre.
- Poly budget: **5,000 triangles or fewer.**

## Park pieces (slots `park_*`)

- Origin at **ground level, at the piece's back-left corner**, on a **1 m grid**. Pieces sit flush on the grid with no offset.
- Grind edges are marked by **child nodes named `Rail_*`** (for example `Rail_1`, `Rail_2`). A rail is a straight line starting at the node's origin and running along its **-Z** for its **scale.z** length. Rail nodes are invisible guides (no mesh needed), or keep them as thin meshes if you like.
- Coping (the metal lip on a bowl or pool edge) is marked by child nodes named `Coping_*` in the same way.
- Texture budget: **2048 x 2048 px per park atlas** (one shared atlas per piece, or one for all park pieces).
- Poly budget: **5,000 triangles or fewer per piece.**

## Look: toon

- **Flat colours.** No gradients inside a surface, no photo textures, no fine detail.
- Use only this palette (10 colours):

  | Name | Hex |
  |---|---|
  | White | `#FFFFFF` |
  | Ink (outlines, shadows) | `#1B1B2F` |
  | Red | `#FF4D4D` |
  | Orange | `#FF9F1C` |
  | Yellow | `#FFD93D` |
  | Green | `#6BCB77` |
  | Blue | `#4D96FF` |
  | Purple | `#9B5DE5` |
  | Pink | `#F15BB5` |
  | Tan | `#A0785A` |

- **No PBR tricks.** Set roughness and metallic to plain values (roughness 1.0, metallic 0.0 or flat). No normal maps, no metal shine, no glossy highlights.
- Bright, readable, kid-friendly. No blood, no weapons, no swearing or rude text.

## Slot table

| Slot name | File | What it is |
|---|---|---|
| `skater_body` | `art/skater_body.glb` | The skater character with skeleton and all required animations |
| `skater_board` | `art/skater_board.glb` | The skateboard with `Wheel_*` nodes |
| `park_quarterpipe` | `art/park_quarterpipe.glb` | Quarter pipe ramp |
| `park_halfpipe` | `art/park_halfpipe.glb` | Half pipe (both sides) |
| `park_bowl` | `art/park_bowl.glb` | Bowl, with `Coping_*` on the edge |
| `park_funbox` | `art/park_funbox.glb` | Funbox (flat box with ramps) |
| `park_rail_flat` | `art/park_rail_flat.glb` | Flat rail, with `Rail_*` nodes |
| `park_rail_down` | `art/park_rail_down.glb` | Downhill rail, with `Rail_*` nodes |
| `park_ledge` | `art/park_ledge.glb` | Ledge, with `Rail_*` nodes on the top edge |
| `park_stairs` | `art/park_stairs.glb` | Stair set, with `Rail_*` nodes |
| `park_kicker` | `art/park_kicker.glb` | Kicker ramp |
| `park_wall` | `art/park_wall.glb` | Wall for wallrides |
| `park_bench` | `art/park_bench.glb` | Bench for grinds and sitting |
| `park_props` | `art/park_props.glb` | Decor: cones, signs, barrels, and similar (no collision) |

## Checklist before dropping a file in

1. Named exactly as the slot, `.glb`, in `art/`.
2. 1 unit = 1 metre; Y up; faces -Z.
3. Skater: bone names match the list; required animations present; under 15k triangles.
4. Board: 0.8 m long, origin at the deck centre bottom, `Wheel_FL/FR/BL/BR` present.
5. Park piece: origin at back-left corner on the 1 m grid; `Rail_*` and `Coping_*` where needed; under 5k triangles.
6. Colours from the palette; no PBR shine.
