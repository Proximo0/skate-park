# Play bot

An automated player that skates the real park (`res://game/main.tscn`, a fresh instance per line) and reports everything that feels broken.

    tools/bot_run.sh [--only=<line>] [--tune=<preset.json>] [--record] [--list]

Runs headless at `--fixed-fps 60`, about 25 s wall for all 16 lines. Exit 0 unless the bot crashed.
Files: `tests/bot/bot.tscn`, `bot_main.gd` (orchestrator, scoring, output), `bot_lines.gd` (routes built from park piece nodes, gap-zone Area3Ds, rail points, `Park.drop_ins`; no hand-guessed coordinates), `bot_driver.gd` (input), `bot_detectors.gd` (issue detection).

## Driver
`skater.scripted_input = true`; every physics tick `set_input(stick, pressed, held)`. A waypoint follower steers with a PD law on the signed angle between `facing` and the target (stick.x), pushes below target speed, brakes when far too fast, and balances grinds/manuals/lips from `skater.balance`. Waypoint actions: ollie (hold, release, optional flip/grab/revert/manual), grind, manual, pump, revert, wait, teleport (drop-in via `DropIn.teleport`-style placement), pipe pumping (records peaks).

## Lines
cruise, ollies, kickers, funbox_gap, halfpipe (5 pumped passes, peaks recorded), quarter_air, rails_street, rails_long, manuals, dome, drop_loop, mega, street_run, gaps_misc, transfers, corners (soft: side scrapes and corner clips at angle).
A line is DONE when no waypoint timed out or was skipped (soft lines tolerate skips) and there was no respawn, kill-plane fall or NaN.

## Detectors (per tick, from `physics_ticked`)
- snag: energy 0.5v^2+g*y drops >30% in 0.25 s with no bail/land/grind/lip/ollie/wallride/respawn event and not braking
- hard_stop: ROLLING, speed >4 to <1 (apex turnarounds excluded)
- stuck: <0.3 m moved over 2 s of intent to move (head-on wall hits are logged as BOTINFO routefault, a bot fault, not an issue)
- bail (with cause: board tilt, heading vs velocity, mid-flip, balance fail, wall hit), respawn, below_kill_plane
- jitter_normal / jitter_y (flat ground), floor_flicker (on_floor off for 1-2 ticks while rolling)
- teleport (>1 m in a tick; grind/lip snaps <1.8 m are notes only)
- overspeed (> tune max_speed + 0.05), nan
- grind_miss / action_miss / wp_timeout / gap_miss (expected gap in `gaps.json` never completed)
Each kind is capped at 6 reports per line (the rest are counted as suppressed).

## Output
    BOT <line> DONE|FAIL t=.. bails=.. snags=.. gaps=[..] max_speed=.. max_h=.. grind=..s manual=..s landings=clean/sketchy/bail notes
    BOTISSUE <kind> <line> pos=(x,y,z) tick=N detail
    BOTINFO ...   (recordings, bot route faults)
    BOT score=<0-100> issues=N lines=N failed=N
`/tmp/bot/report.json` holds everything. `--record` writes `/tmp/bot/<line>.json` for each line with issues: `{snapshot (var_to_str at line start and at bot teleports), frames[]}` where frames are the skater `debug` dicts with Vector3 as arrays. `--tune=` applies a preset to `PhysicsTuning.shared()`. `--only=` takes a line name or prefix.

## Score
`score = max(0, 100 - sum(penalty[kind] * min(count, 6)) - 5 * failed_lines)`, counted over issues only (not notes/BOTINFO).
Penalties per issue: nan 20, respawn 15, below_kill_plane 15, stuck 8, overspeed 6, bail 5, snag 4, hard_stop 4, grind_miss 3, wp_timeout 3, gap_miss 3, teleport 3, action_miss 2, jitter_normal 2, jitter_y 2, floor_flicker 2.
100 means every line ran clean. A clean bot run is the loop's exit condition.
