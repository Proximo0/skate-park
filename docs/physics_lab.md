# Physics lab

A headless battery of scripted manoeuvres that measures the ride in real units (metres, seconds, m/s) and compares each number
with a target taken from real skateboarding, scaled for this game's cartoon feel (gravity is 18, not 9.8, on purpose).
It is a report, not a gate: WARN lines are tuning hints.

## Run it

```
tools/physics_report.sh                       # all manoeuvres, about 7 s
tools/physics_report.sh --only=turn_radius    # only metrics starting with this prefix
tools/physics_report.sh --tune=preset.json    # apply a PhysicsTuning preset first
```

Output, one line per metric, then a summary:

```
LAB ollie_height_tap 1.035 m target=0.8 ok=[0.6,1.1] PASS
LAB summary pass=18 warn=2
```

`LABINFO x_...` lines are unscored diagnostics (peaks per pass, ideal energy values, bails). Files: `/tmp/lab/report.json` and
`/tmp/lab/report.md`. Exit code is 0 even with WARNs; 1 only if a manoeuvre crashed or the scene died before its summary.
Everything is measured in sim time (physics ticks); the script passes `--fixed-fps 60` so it runs faster than real time.

## Files

- `data/physics_targets.json`: per metric `target`, `min_ok`, `max_ok`, `unit`, `why`. Edit the numbers here, not in code.
- `tests/lab/physics_lab.gd` / `.tscn`: runner (args, targets, output, report files).
- `tests/lab/lab_moves.gd`: the manoeuvres (extends the sim harness `tests/sim/sim_base.gd`). `table()` lists each manoeuvre and
  the metrics it produces.
- `tools/compare_reports.py`: side-by-side deltas of two `report.json` files.

## Metrics: what and how

All starts are on a flat 200 m ground (`SimBase.sandbox`) with scripted input and no input unless stated.

| metric | measured how |
|---|---|
| `ollie_height_tap`, `ollie_airtime_tap` | Rolling at 4 m/s, hold ollie for 1 tick, release. Height = peak origin y minus start y; airtime = ticks in AIR. |
| `ollie_height_full`, `ollie_airtime_full` | Same, ollie held 40 ticks (past `crouch_full`). |
| `push_top_speed` | Stick forward from standstill for 20 s; mean speed over the last 2 s (whole push cycles). |
| `push_time_to_top` | Time until speed first reaches 95% of that top speed. |
| `coast_distance_8ms` | Start at 8 m/s, no input; distance until speed <= 0.05 m/s (the skater is wrapped across the ground, the odometer is not). |
| `brake_distance_8ms` | Same with stick back. |
| `turn_radius_4ms` / `8ms` / `12ms` | Full stick right. Radius = mean speed / mean yaw rate of the velocity between 0.2 s and 1.2 s. Speed bleeds a little by friction over the window, so the radius shrinks slightly. |
| `quarter_air_8ms` / `12ms` | 1.5 m mini quarter pipe (height = radius = 1.5 m), 1.8 m of run-in at the given speed. Peak board height minus coping height (negative: never reached the lip). Energy alone gives v^2/(2g) minus 1.5. |
| `kicker_distance_8ms` / `12ms` | Park kicker (2.0 x 2.4 x 0.9). Horizontal distance from the lip (z = 0) to first touchdown. Climbing the 0.9 m costs speed (energy), so launch speed is below the entry speed. |
| `landing_speed_retention` | Tap ollie at 8 m/s on flat; horizontal speed on the touchdown tick over the tick before. The result must be "clean" (see `x_landing_result`). |
| `halfpipe_pump_gain_per_cycle` | 10 m wide, 4 m high halfpipe, enter the flat at 9 m/s, stick held forward. Each turnaround peak (vertical speed crossing from up to down) is taken above the coping; gain = (last of the first 5 peaks - first) / (n - 1). `x_halfpipe_peaks_above_coping_m` lists them. |
| `loop_min_entry_speed` | Park loop (r 4 m). Bisection (7 steps, from 6 to 22 m/s) for the lowest speed at the loop's base that gets round and out the run-out without a bail or fall. 99 means even the 22 m/s cap fails. `x_loop_ideal_sqrt5gr_ms` is the textbook minimum for comparison. |
| `grind_speed_loss_per_m` | 50-50 on a 30 m flat rail entered at 8 m/s, no stick. (speed at grind start - speed at grind end) / metres ground. Ends at the rail end or a bail (`x_grind_bails`, `x_grind_length_m`); needs >= 2 m of grind. |
| `roll_down_speed_bank3m` | 3 m high bank, 5 m run (about 31 degrees) with a deck on top; roll off the deck at 1 m/s, no input. Total speed when the board reaches the toe. `x_bank_ideal_sqrt2gh_ms` is the frictionless value. |

## Comparing two feels

The skater reads every physics number from `PhysicsTuning.shared()`, and the lab applies `--tune=` to that before it runs. A preset is
a JSON object of `{field: value}` (the output of `PhysicsTuning.save_json`, or a hand-written subset; unknown keys are ignored).

```
tools/physics_report.sh;                          cp /tmp/lab/report.json /tmp/lab/a.json
tools/physics_report.sh --tune=presets/heavy.json; cp /tmp/lab/report.json /tmp/lab/b.json
tools/compare_reports.py /tmp/lab/a.json /tmp/lab/b.json
```

The table shows A, B, delta, delta percent, PASS to WARN changes, the target band, and the tuning fields that differ from the
defaults. The report records `tuning_diff` (fields that differ from the defaults), so you can see what each run used.
If the class `PhysicsTuning` does not exist the preset is ignored and the report says so.

## Adding a metric

1. Add the entry in `data/physics_targets.json` (target, band, unit, why).
2. Add a `m_<name>()` function to `tests/lab/lab_moves.gd` returning `{metric: value}` (keys starting with `x_` are diagnostics) and
   list it in `table()`.
3. Run `tools/physics_report.sh --only=<metric>`.
