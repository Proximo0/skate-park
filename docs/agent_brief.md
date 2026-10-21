# Agent brief (step 2 and 3)

Read `CLAUDE.md` first. This file lists the contracts other modules already provide. Use them; do not change them.

## Hard rules for helper agents
- Only create or edit the files your task lists. Never edit anyone else's files, `project.godot`, autoloads,
  `game/skater/skater.gd`, `game/park/piece_kit.gd`, `game/park/grind_rail.gd` or `tests/runner.gd`. If you need a
  change there, describe it in your final report.
- Never call any `mcp__hearthbot__` tool and never message the user. Report only through your final answer.
- Do not run git.
- Wrap every Godot call in the shared lock: `(flock 9; <godot command>) 9>/tmp/skate_godot.lock`.
  `tools/run_tests.sh` and `tools/capture.sh` already take it.
- Rendering check: `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path /home/claude/skate --rendering-driver opengl3 --resolution 1280x720 <scene or -s script> -- --scripted`.
  Put throwaway render scripts in `/tmp/<your task>/`, not in the project, and look at the PNG you produce.
- Finish with: files written, tests run and their result, what you saw in your render, anything others must know.

## Units and axes
Metres. Y up. Godot forward is -Z. Physics 60 Hz. Collision layer 1 = world, layer 2 = skater.

## Skater (`game/skater/skater.gd`, class `Skater extends CharacterBody3D`)
Readable each frame:
- `state: SkateState` with `state.state` (enum `SkateState.State` ROLLING, AIR, GRIND, MANUAL, LIP, WALLRIDE, BAIL),
  `state.state_name()`, `state.time_in_state`
- `velocity: Vector3`, `speed: float`, `facing: Vector3` (travel direction), `board_up: Vector3`, `vert_air: bool`
- `anim: String`, `anim_time: float` (seconds since anim changed), `anim_trick: Dictionary` (last trick), `crouch: float` 0..1,
  `switch_stance: bool`, `balance_kind: String` ("", "grind", "manual", "lip"), `balance.angle: float` -1..1
- `combo: Combo` (`display_text()`, `base_sum()`, `multiplier()`, `total()`, `landed_total`, `best_combo`, `is_active()`)
- `special: SpecialMeter` (`value` 0..1, `is_special()`), `gaps: Gaps` (`discovered_count()`, `total_count()`)
Signals: `trick_started(trick: Dictionary)`, `combo_changed(text, base, multiplier)`, `combo_landed(points, text)`,
`combo_bailed(text)`, `landed(result: String)` ("clean", "sketchy", "bail"), `gap_hit(gap_name, points)`, `bailed`.
Methods: `respawn()`, `set_input(stick: Vector2, just_pressed: Array, held: Array)` with `scripted_input = true`.
The skater's visual is the child `Visual` (Node3D), which contains `Skateboard` (from `PlaceholderSkater.build_board()`)
and `SkaterBody` (from `PlaceholderSkater.build_body()`, rotated 90 degrees about Y so the kid stands sideways on the board).
Visual's basis: -Z = travel direction, +Y = board up.

`anim` values: `idle_ride`, `push`, `crouch`, `ollie`, `air`, `land`, `revert`, `bail_fall`, `bail_getup`, `wallride`,
plus the trick's `anim` from `data/tricks.json`: `flip_<id>`, `grab_<id>`, `grind_<id>`, `lip_<id>`,
`manual_manual`, `manual_nose_manual`, `special_<id>`. Match on the prefix (`flip_`, `grab_`, ...).

## Park pieces (`game/park/piece_kit.gd`, class `PieceKit`)
Every piece is a `class_name <Name> extends RefCounted` with `static func build(...) -> Node3D` in
`game/park/pieces/<name>.gd`. Origin at ground level at the back-left corner; footprint x in [0, width],
z in [0, depth]; the riding face looks toward +Z. Use:
- `PieceKit.body(mesh, color, name) -> StaticBody3D` (toon material + trimesh collision, both sides collide)
- `PieceKit.box(min_corner, size, color, name) -> StaticBody3D`
- `PieceKit.extrude_profile(profile: PackedVector2Array of (y, z), width) -> ArrayMesh` (any winding; vertex 0 must see
  every other vertex, fan triangulation of the end caps)
- `PieceKit.mesh_from_triangles(tris) -> ArrayMesh`
- `PieceKit.rail(points, kind, name) -> GrindRail` (kind "rail", "ledge" or "coping"; points in the parent's local space)
- `PieceKit.round_rail(a, b, radius, color, name) -> Node3D` (visible pipe plus its GrindRail)
- `PieceKit.gap_zone(zone_id, min_corner, size) -> Area3D` (gap detection; zone ids must match `data/gaps.json`)
- Colours: `PieceKit.CONCRETE, RAMP_WOOD, RAMP_SIDE, METAL, PAINT_RED, PAINT_GREEN, PAINT_PURPLE, PAINT_YELLOW`
Reference pieces: `game/park/pieces/quarterpipe.gd` (QuarterPipe) and `game/park/pieces/kicker.gd` (Kicker).
Every edge a skater should grind needs a GrindRail: ledge tops ("ledge"), ramp lips ("coping"), metal rails ("rail").
Rails sit exactly on the top edge; the skater snaps to them.

## Look
`Toon.material(color)` for any mesh, `Toon.apply_to(node)` to convert StandardMaterial3D meshes, `Toon.sky_environment()`.
Kid-friendly, bright, rounded, readable. No blood, no swearing.

## Input actions (`game/autoload/controls.gd`)
`move_left/right/up/down` (stick, WASD, d-pad), `ollie` (Cross / Space), `flip` (Square / J), `grab` (Circle / K),
`grind` (Triangle / I), `spin_left` (L1 / Q), `spin_right` (R1 / E), `revert` (R2 / L), `nollie` (L2 / U),
`pause` (Start / Esc), `restart` (Select / Backspace), `debug_stamp` (F10). `Controls.move_vector()`.
