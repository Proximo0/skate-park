# Lessons learned (read before starting work)

The full build guide is a Claude Doc: https://claude.ai/artifact/WtmrkVRtizP8oJBRwhxdWW. Add a row here whenever something goes wrong.

| What happened | Rule |
| --- | --- |
| Subagents messaged the user directly | Never call `mcp__hearthbot__` tools. Report only to the lead. |
| A global `flock` around every Godot run deadlocked agents | Only `godot --import` takes /tmp/<project>_import.lock. Never wrap tools/*.sh in flock. |
| Sub-orchestrator agents had no Agent tool | Nested fan-out needs the Workflow tool, or the lead starts every worker. |
| 4 cloud cores cap Godot runs | Use `tools/check_all.sh` locally and the GitHub Actions matrix (`checks`) for scale. |
| A GPU glitch was blamed on a guess | Sample screenshot pixels and reproduce first. If it can't be reproduced, ship toggles. |
| Wall ends were accepted as floor (`floor_max_angle` 80°), so a fake vert launch cut speed to 15% | Measure snags with `tools/snag_sweep.sh`, then fix the traced mechanism. |
| A lab WARN almost undid a design choice (strong halfpipe pump) | Check a WARN against the player's stated wishes before tuning it away. |
| `git commit -a` pushed another worker's half-finished file | The lead stages files by name while workers are editing. |
| A z-fighting floor pad | Lift the mesh, never the collider (`PieceKit.floor_pad`). |
| A `-s` render script couldn't see autoloads | `load()` game classes inside a deferred call. |
| A fix looked plausible but the bug predated the changed code | Check git history for when a bug first appeared. |
| Feel bugs were found by the player, not by us | Build the debug layer and the bot before content: tunables, debug frame, snapshot/replay, recorder, overlay, lab, bot. |
| Ramps had knife-edge side walls under 0.3 m | Piece rule: no collision edge under the skater's radius, side walls run below ground, no coplanar floors. |
| Mid-flight workers left the tree red while CI linted the pushed tree (Sandblood) | The lead copies finished files into a clean clone (`/tmp/<project>_build`), runs lint, tests and sims there, commits by name and pushes from it; then `git reset` the work tree to origin. |
| Container restarts killed running workers three times (Sandblood) | Workers leave WIP in the tree; relaunch on that WIP with the prior findings in the prompt, never from scratch. |
| A bot run hung 15 min and wrote 334 MB: another worker's half-saved shared script failed to parse (Sandblood) | Watch a long bot run's log size or error lines, not just its exit; re-run balance after a shared script stops changing. |
| Balance work started from stale numbers after an AI change (Sandblood) | Re-measure the baseline on the current tree before tuning; numbers go stale after any AI or physics change. |
| An AI "thrust" never hurt: it aimed open-loop and moved slower than the damage threshold (Sandblood) | Steer AI actions on the measured result (closed loop) and check speeds against the damage thresholds. |
| A win rule had no fallback for its zero case: fist fights never bleed, so every time-out was a draw (Sandblood) | Every judge or scoring rule needs a fallback when its main measure is level. |
| Two instances of one glb shared a cached `Mesh`; per-instance override materials errored at teardown (Sandblood) | Duplicate an instanced glb's mesh before setting surface override materials. |
| Houdini glTF ROP exported every material as `alphaMode BLEND` (Sandblood) | Force imported art opaque (or set it in the ROP); `hipFile.save` needs its folder made first; build with `--only=<ids>`. |
| Jolt contact order is thread-dependent, so same-seed runs split (Sandblood) | Sort contacts before first-per-key debounce; run each same-seed repeat in a fresh process. |
| Dynamic props with a one-sided layer/mask became immovable blocks (Sandblood) | Give dynamic props symmetric masks, or no layer at all. |
| Closing an ENet peer from its own signal crashed; ENet's throttle dropped half the snapshots; a relay silently dropped packets over its size limit (Sandblood) | Defer peer close to idle; switch the ENet throttle off for snapshot streams; split packets by bytes under the relay limit. |
| Thin decorative meshes cast hard shadow streaks; cool ambient made orange sand read green in shadow (Sandblood) | Only big shapes cast shadows; use a warm ambient on warm ground and sample shadow hues before blaming shaders. |
| Secrets (online service client keys) must ship in builds but not in a public repo (Sandblood) | Keep them in a gitignored config injected by the export script; never write them to memory or docs. |
