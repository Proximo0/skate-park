# Lessons learned (read before starting work)

The full build guide is a Claude Doc: https://claude.ai/artifact/WtmrkVRtizP8oJBRwhxdWW. Add a row here whenever something goes wrong.

| What happened | Rule |
| --- | --- |
| Subagents messaged the user directly | Never call `mcp__hearthbot__` tools. Report only to the lead. |
| A global `flock` around every Godot run deadlocked agents | Only `godot --import` takes /tmp/skate_import.lock. Never wrap tools/*.sh in flock. |
| Sub-orchestrator agents had no Agent tool | Nested fan-out needs the Workflow tool, or the lead starts every worker. |
| 4 cloud cores cap Godot runs | Use `tools/check_all.sh` locally and the GitHub Actions matrix (`physics-checks`) for scale. |
| A GPU glitch was blamed on a guess | Sample screenshot pixels and reproduce first. If it can't be reproduced, ship toggles. |
| Wall ends were accepted as floor (`floor_max_angle` 80°), so a fake vert launch cut speed to 15% | Measure snags with `tools/snag_sweep.sh`, then fix the traced mechanism. |
| A lab WARN almost undid a design choice (strong halfpipe pump) | Check a WARN against the player's stated wishes before tuning it away. |
| `git commit -a` pushed another worker's half-finished file | The lead stages files by name while workers are editing. |
| A z-fighting floor pad | Lift the mesh, never the collider (`PieceKit.floor_pad`). |
| A `-s` render script couldn't see autoloads | `load()` game classes inside a deferred call. |
| A fix looked plausible but the bug predated the changed code | Check git history for when a bug first appeared. |
| Feel bugs were found by the player, not by us | Build the debug layer and the bot before content: tunables, debug frame, snapshot/replay, recorder, overlay, lab, bot. |
| Ramps had knife-edge side walls under 0.3 m | Piece rule: no collision edge under the skater's radius, side walls run below ground, no coplanar floors. |
| A gap needing MANUAL at its start was unreachable: the rider enters the zone in AIR, then lands into the manual inside it | Gaps.start_in_zone runs on every state change for zones the rider is inside; size start zones to cover where the landing happens |
| Character took four rounds: a primitive look, 1.25 m tall, barrel chest, low clipping bust, garments clipping the legs | Follow starter-kit/docs/character_creation_lessons.md: research references, write a numeric spec, size the skeleton to it, use elliptical lofts, offset garments from skin sections, check a pose grid |
| Untracked new files from a finished worker vanished from the shared tree while other workers were still running (secondary_motion.gd) | Commit a finished worker's files promptly, or back them up to /tmp/lead/backup/ first. Tell workers never to run git clean, git stash -u or checkout on the shared tree. |
| Polish passes: Evaluators reported "score stays 0" and "grey speech bubble" that were capture artefacts (bot teleports wiped open combos; a bubble caught mid-fade). | Before fixing an evaluator finding, reproduce it in the live scene; have bots wait for open combos to land before teleporting and log landed_total. |
| Toon shader: Ramps blew out to flat yellow because the toon light term ignored that LIGHT_COLOR already includes PI, and a white rim was added on lit faces. | Normalise light so lit albedo ≈ albedo; check every shared-shader change on park, skater and shop renders. |
| Workers: A worker reported "sims and bot skipped as instructed" when the brief asked for them. | The lead reruns check_all and the bot before every commit of park, camera or physics-adjacent files. |
| Character remade six more times (code lofts, Blender, Houdini, polish passes) and still read as a placeholder | Never sculpt humanoids in code. Start from a creator-made or licensed model (VRoid/VRM), standard humanoid bone names, test asset-site downloads on day one. See character_creation_lessons.md round two |
| Unit tests passed in the working tree but failed in CI | Other workers' uncommitted edits hide failures. Run the full suite in a clean `git worktree` of HEAD before committing |
| `tools/bot_run.sh` reported a false "crash" on big outputs | Under `set -o pipefail`, `echo "$out" \| grep -q` fails when grep exits early (SIGPIPE). Use a here-string: `grep -q pat <<<"$out"` |
