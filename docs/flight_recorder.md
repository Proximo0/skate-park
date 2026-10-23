# Flight recorder

The game keeps the last 30 s of skater physics in memory (every tick: position, velocity, state, inputs, events,
plus a full `snapshot()` once a second). Dump it after something felt wrong and the log can be replayed
deterministically, plotted, and re-run with different tuning.

## Recording (Curtis)

- Press **F12** right after the thing happens. A toast shows the saved path for 3 seconds. The log holds the last 30 s.
- Every **bail** is also saved automatically as `bail_<date>_<time>.json` (the 10 s before it and 1 s after). The last 3 are kept.
- Files land in `user://physics_logs/`. On Windows that is
  `%APPDATA%\Godot\app_userdata\Skate Park\physics_logs\` (project name `Skate Park`, from `project.godot`).
  Paste that into Explorer's address bar. On Linux it is `~/.local/share/godot/app_userdata/Skate Park/physics_logs/`.
- To send one: attach the `run_*.json` (or `bail_*.json`) file to the message. Each is about 1 MB. Say what was wrong
  ("the ollie off the kicker felt too low") and roughly how many seconds before the end of the log it happened.
  If you were using the tuning panel, the log already contains your tuning values.

## Replaying (Claude / developers)

```
tools/replay.sh <log.json> [--tune=preset.json] [--from=tick] [--ticks=N] [--csv=out.csv]
```

- Builds the same park (`park` in the log: `main` or `testpark`), restores the snapshot at or before `--from`
  (default: the first one), feeds the recorded stick/held/pressed each tick and compares to the recorded positions.
- Prints `REPLAY divergence max=<m> at tick <t> mean=<m>` and the events that differ between recorded and replayed.
  With unchanged tuning the divergence should be under 1e-3 m (the script exits 1 if not). `--ticks=N` replays N ticks
  after the snapshot tick.
- `--tune=preset.json` makes it a what-if: the log's tuning with the preset on top (same format as the tuning panel's
  save). It then prints `REPLAY whatif` lines: peak height of each airtime, speed at each ollie/land/grind/bail event,
  bail counts and max speed, recorded vs replayed. Inputs are replayed as recorded, so a change that alters timing
  (an earlier landing) can change what the same buttons do; read it as "what would these exact inputs have done".
- Always writes a CSV (default `<log>.replay.csv`): tick, t, recorded and replayed state/pos/vel/speed, and the events.
- A bail's ragdoll is not replayed. Pressing Restart (R) during a recording is not replayed either (the skater is
  respawned only by falling below `kill_y`).

## Plotting

```
python3 -I tools/plot_run.py <log.json|replay.csv> [-o out.png]
```

Speed, height, vertical velocity and a state strip against time, with ollie / land / bail / grind labelled.
Given a replay CSV, recorded (solid) and replayed (dashed) are overlaid. Needs `pip install matplotlib`.

## Checking the recorder itself

`tools/replay_selftest.sh` records a scripted 5 s ride on the test park and replays it (expects divergence under 1e-3 m).
`tools/run_tests.sh test_physics_recorder` covers the ring buffer and the file layout.

## Wiring (game/main.gd)

```gdscript
var recorder := PhysicsRecorder.new()
add_child(recorder)
recorder.bind(skater)
```

Log format: see `docs/physics_debug_brief.md`. Snapshot values are `var_to_str` strings (they can lose about 1e-8 on
some floats, so compare with a tolerance, never `==`).
