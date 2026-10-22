# Feel targets: THUG-generous, Skate-3-believable

This is the numeric spec for the ride. Each number lives in `data/physics_targets.json` (target, ok band, reason), and the physics
lab measures it: `tools/physics_report.sh` prints `LAB <metric> <value> ... PASS|WARN` for every row below (see `docs/physics_lab.md`).
The tuning values live in `game/skater/physics_tuning.gd`. Input windows live in `game/input/trick_input.gd` and in `skater.gd`
constants.

## How the targets were picked

- **Real skateboarding sets the shape.** We start from measurements: ollie heights, rolling friction, push speeds, vert airs, flip rates.
  Then we scale them for a game with gravity 18 m/s² (snappier, less floaty than 9.8) and a park tens of metres wide.
- **THUG sets the generosity.** Combo inputs (revert, manual, grind, flip) get forgiving buffers of 0.1 to 0.35 s. Landings forgive a
  45-degree heading error. Grinds snap from about a body width away. Walls rarely bail you.
- **Skate 3 sets the believability.** Speed follows energy. Ramps give back what you carry in, minus small losses. Hills accelerate you
  at nearly g·sinθ. Bowl carves keep their speed. Flips and spins have limits on flat ground, and nothing adds speed for free except
  the pump, which is a design choice.
- **Curtis's halfpipe pump stays strong.** `pump_accel_vert` is never lowered (`docs/lessons_learned.md`: "check a WARN against the player's
  stated wishes before tuning it away").

## Sources

| # | Source | What we took |
|---|---|---|
| 1 | Guinness World Records, highest ollie (Aldrin Garcia, 2011): 114.3 cm, https://www.guinnessworldrecords.com/world-records/skateboarding-highest-ollie | The ceiling for a real ollie. Ours are exaggerated well past it on purpose. |
| 2 | "3D Kinematic Analysis of the Ollie" (Apunts, Vicon at 100 Hz, n = 6), https://revista-apunts.com/en/3d-kinematic-analysis-of-the-ollie-maneuver-on-the-skateboard/ | An ordinary ollie raises the skater's centre of mass only about 0.18 m and the board's about 0.24 m: real everyday ollies are small. |
| 3 | radratvideo, "How many flips are possible on flat" (frame counts), https://radratvideo.com/many-flips-possible-flat-5-6-7-skate-physics/ | A kickflip board spins about 2900 deg/s (about 8 rev/s); the record ollie hangs about 0.7 s; a shove-it is about 0.15 s per 180. |
| 4 | Kogelbauer et al., "Mechanical Optimization of Skateboard Pumping", arXiv 2312.17671, https://arxiv.org/pdf/2312.17671 | Measured rolling friction mu about 0.02 (0.2 m/s lost over 1 s at 3 m/s); a mini ramp with a 1.9 m radius. |
| 5 | Physics World on the same pumping study, https://physicsworld.com/a/pumping-on-a-half-pipe-physicists-model-a-skateboarding-skill/ | Pumping is a pendulum with a changing length: lower on the flat, rise on the walls. |
| 6 | Longboard speed study (Eur J Appl Physiol 2014), https://link.springer.com/10.1007/s00421-014-2959-x | Self-chosen pushing speeds 3.7 / 4.5 / 5.1 m/s (slow, typical, fast). |
| 7 | Surfertoday, "How fast can a skateboard go", https://www.surfertoday.com/skateboarding/how-fast-can-a-skateboard-go | Cruising at 8 to 19 km/h (2 to 5 m/s), pushing at about 12 km/h. |
| 8 | Guinness World Records, highest air on a quarterpipe (Danny Way, 7.77 m), https://www.guinnessworldrecords.com/world-records/63735-highest-air-on-a-skateboard-quarterpipe | The ceiling for vert air. Pro airs on a normal vert ramp are a fraction of it. |
| 9 | Wikipedia, Half-pipe, https://en.wikipedia.org/wiki/Half-pipe | Ramp height is 50 to 75% of the transition radius on less-than-vert ramps; quarter-circle transitions. |
| 10 | Game Developer, "EA's Blackwood: text-based prototype perfected Skate's control scheme", https://www.gamedeveloper.com/game-platforms/ea-s-blackwood-text-based-prototype-perfected-i-skate-i-s-control-scheme | Skate read the stick at 120 Hz because 60 Hz missed gesture speed. The physics was tuned to the controls, not the other way round. |
| 11 | gamedev.net, "Your players hate missed jump inputs", https://gamedev.net/news/4298-your-players-hate-missed-jump-inputs-heres-why/ | Jump buffer of about 120 ms: "long enough to catch human timing errors without making controls feel mushy". |
| 12 | Maddy Thorson, "Celeste & Forgiveness", https://maddymakesgames.com/articles/celeste_and_forgiveness/ | Jump buffering and coyote time as invisible forgiveness, the THUG-style feel we want for combo inputs. |
| 13 | Engineering ToolBox, friction coefficients, https://www.engineeringtoolbox.com/friction-coefficients-d_778.html | Aluminium on steel has kinetic mu 0.47 dry; waxed far lower. Rubber on concrete has mu 0.6 to 0.85 (the powerslide ballpark). |
| 14 | Tony Hawk's Games wiki, Double Revert, https://tonyhawkgames.fandom.com/wiki/Double_Revert | Reverts are timed presses around a landing; THUG-era games lean on them to link combos. |

No developer has published THUG's or Skate 3's internal numbers. The game references, such as a THUG kickflip taking about 0.4 s or
a flat 360 being possible with a full crouch, come from playing and watching the games, and the table says so.

## Targets

"Before" is the lab at the start of this pass. "After" is the lab with the shipped defaults and the proposed `skater.gd` ollie
buffer (see the end of this file). Gravity 18, speed cap 22.

### Rolling

| metric | real | THUG / Skate 3 | target (ok band) | before | after | reasoning |
|---|---|---|---|---|---|---|
| push_accel_0_5 (m/s²) | 1.5 to 2.5 [6] | THUG: rolling in about 1 s; Skate 3: 2 to 3 visible kicks | 4.5 (3 to 6.5) | 5.09 | 5.09 | Snappy, but each kick still reads. |
| push_top_speed (m/s) | 4 to 6 [6,7] | | 10.5 (9 to 12.5) | 11.95 | 11.95 | About 2x real, so a flat push gives meaningful ramp air in parks tens of metres wide. |
| push_time_to_top (s) | about 4 | | 2.5 (1.6 to 3.5) | 2.23 | 2.23 | |
| coast_distance_8ms (m) | about 160 at mu 0.02 [4] | | 55 (35 to 90) | 53.1 | 53.1 | Shorter than real on purpose: if you stop pushing you visibly slow down. |
| brake_distance_8ms (m) | 6 to 8 foot brake | | 5.5 (3.5 to 8) | 4.77 | 4.77 | Stick back stands in for a foot brake or powerslide (no separate powerslide yet, see the end). Decel about 6.7 m/s², a rubber-on-concrete powerslide [13]. |
| turn_radius_4 / 8 / 12 ms (m) | 2 to 4 / 8 to 12 / 15+ | THUG sharp, Skate 3 wider | 2 / 4.5 / 7 | 1.45 / 3.30 / 7.43 | same | The radius grows like v²/carve_grip at speed. 8 m/s sits at the tight (THUG) end of its band. Kept: the bots' street lines thread with it. |
| slope_accel_15deg (m/s²) | g·sin15 minus friction | Skate 3 hills | 4.1 (3.6 to 4.7) | 4.06 | 4.06 | Ideal 4.66 minus roll_friction 0.6. |
| roll_down_speed_bank3m (m/s) | | | 9.5 (8.5 to 10.5) | 9.96 | 9.96 | |
| wall_carve_speed_retention | about 0.97 [4] | both keep bowl speed | 0.95 (0.92 to 1.0) | 0.926 | 0.926 | At the low edge. The cost is the 0.6 m/s² roll friction over a 1.1 s carve. Lowering roll_friction would also stretch the coast, so it is left alone (see "Watch"). |

### Ollie, flips, spins

| metric | real | THUG / Skate 3 | target (ok band) | before | after | reasoning |
|---|---|---|---|---|---|---|
| ollie_height_tap (m) | 0.2 to 0.5 [2] | THUG: a tap clears a bench | 1.0 (0.75 to 1.15) | 1.035 | 1.035 | Exaggerated about 2x. The levels' gaps are built on it (see "What was tuned"). |
| ollie_height_full (m) | 0.9 to 1.14 [1] | THUG: a chest-high ledge with room to flip | 1.9 (1.6 to 2.1) | 1.987 | 1.987 | Same: the biggest ollie gaps in the six levels need it. |
| ollie_airtime_tap / full (s) | 0.4 to 0.7 [3] | | 0.68 / 0.93 | 0.683 / 0.950 | same | |
| ollie_pop_latency_ms | | THUG pops on release | 17 (0 to 34) | 16.7 | 16.7 | One tick. |
| ollie_land_buffer_ms | | jump buffer about 100 to 120 ms [11,12] | 100 (67 to 150) | 0 | 117 with the proposed change | An ollie tapped just before touchdown was dropped. |
| flip_rotations_per_s | about 8 [3] | THUG about 2.5, Skate 3 about 3 | 2.4 (1.8 to 3.2) | 2.31 | 2.31 | Real speed reads as a blur. |
| flip_catch_margin_tap_s | | THUG: tap kickflips land | 0.2 (0.1 to 0.4) | 0.267 | 0.267 | A tap kickflip on flat still lands clean. |
| flip_prepop_buffer_ms | | | 150 (100 to 250) | 183 | 183 | The `_pending_air` 0.2 s buffer. |
| spin_deg_full_ollie | | THUG: flat 360 with a full crouch | 400 (340 to 540) | 401 | 401 | A flat 360 is still possible, 540 needs a ramp. |
| spin_under_rotation_grace_deg | | | 30 (20 to 45) | 30 | 30 | SpinTracker.GRACE_DEG. |
| land_clean_heading_max_deg | | Skate 3 20 to 30, THUG 45 to 60 | 45 (35 to 55) | 50 | 50 | |
| land_sketchy_heading_max_deg | | | 75 (65 to 85) | 79.7 | 79.7 | |
| land_clean_tilt_max_deg | | | 30 (20 to 40) | 31 | 31 | |
| landing_speed_retention | about 1 | | 0.97 (0.93 to 1.0) | 0.961 | 0.961 | |

### Combo windows (THUG responsiveness)

| metric | target (ok band) | before | after | where it lives |
|---|---|---|---|---|
| revert_pre_land_buffer_ms | 150 (100 to 200) | 133 | 133 | `skater.gd` REVERT_BUFFER_TICKS = 9 (the lab reads it to within 1 tick) |
| revert_post_land_window_ms | 350 (250 to 500) | 333 | 333 | `skate_state.gd` REVERT_WINDOW = 0.35 s, equal to the combo LAND_WINDOW |
| manual_entry_window_ms | 300 (200 to 400) | 300 | 300 | `trick_input.gd` SEQUENCE_TICKS = 20 |
| grind_press_buffer_ms | 133 (100 to 200) | 117 | 117 | `skater.gd` `_recent_grind_press < 8` |
| flip_prepop_buffer_ms | 150 (100 to 250) | 183 | 183 | `skater.gd` `_pending_air` 0.2 s |
| ollie_land_buffer_ms | 100 (67 to 150) | 0 | 117 (proposed) | `trick_input.gd` OLLIE_LAND_BUFFER_TICKS = 7, used by the proposed `skater.gd` lines |

### Balance

Balance is measured with a player model. It reacts 0.2 s late (a typical visual reaction time) to the lean and to how fast the lean is
tipping (stick = lean + 0.3 × lean rate), and the speed is held, so only the balance can end the trick.

| metric | target (ok band) | before | after | reasoning |
|---|---|---|---|---|
| manual_fall_nostick_s | 1.8 (1.2 to 3.0) | 2.0 | 2.0 | THUG: hands off, it tips over in 1 to 2 s. |
| manual_hold_human_s | 15 (8 to 30) | 15.4 | 15.4 | A steady player holds 10 to 20 s early in a combo; the difficulty grows with time held (Balance.TIME_GROWTH_SECONDS 12). |
| grind_fall_nostick_s | 2.5 (1.5 to 4) | 2.8 | 2.8 | A little kinder than the manual: short rails need no balancing. |
| grind_hold_human_s | 15 (8 to 30) | 15.4 | 15.4 | |

### Grinds, walls, vert

| metric | real | target (ok band) | before | after | reasoning |
|---|---|---|---|---|---|
| grind_snap_reach_m | trucks over the rail | 1.0 (0.7 to 1.4) | 1.09 | 1.09 | THUG magnet, about a body width. |
| grind_speed_loss_per_m (m/s per m) | 0.3 to 0.5 (mu about 0.2 to 0.47 [13]) | 0.15 (0.05 to 0.35) | 0.150 | 0.150 | Long rails stay rewarding. |
| wallride_duration_s | a fraction of a second | 1.0 (0.7 to 1.5) | 1.2 | 1.2 | `wallride_time` cap. |
| wall_slam_speed_ms | | 13 (10 to 16) | 13.4 | 13.4 | Just above push top speed: a pushed run bounces, a ramp- or hill-fed run slams. |
| vert_air_14ms / 18ms (m over a 4 m coping) | pro airs 1.5 to 3.5 [8] | 1.2 / 4.6 | 1.20 / 4.78 | same | Follows energy (1.44 / 5.0 ideal). |
| quarter_air_8 / 12ms (m over a 1.5 m coping) | | 0.3 / 2.5 | 0.20 / 2.52 | same | |
| kicker_distance_8 / 12ms (m) | 2 to 3 | 3 / 5 | 2.16 / 6.12 | same | |
| halfpipe_pump_gain_per_cycle (m) | 0.2 to 0.4 | 1.7 (1.2 to 2.4) | 1.88 | 1.88 | Curtis's strong pump; untouched. |
| loop_min_entry_speed (m/s) | sqrt(5gr) = 19 | 16 (13 to 19) | 18.7 | 18.7 | |

## What was tuned

No default in `physics_tuning.gd` changed. Every measured number already sat inside its band, except the ollie jump buffer, which
needs code (below). One tuning was tried and rejected. `ollie_min` 6.0 → 5.7 and `ollie_max` 8.5 → 7.9 gave a 0.93 m tap and a
1.72 m full ollie, closer to real. Then the bots dropped: practice 28 (Over The Funbox missed, dome wall slam), beach 77, school 73
(Senior Steps, Lunch Roof), warehouse 94 and hills 97. The six levels' gaps are built on the current pop, so the ollie targets now
follow the level design (THUG-sized, about 2x real), not the real-world numbers. To make ollies smaller later, the level gaps have to
be re-measured with the bot as well.

## Proposed `skater.gd` change: ollie jump buffer

`TrickInput` now stamps every button press (`pressed_within(button, ticks)`, `consume(button)`), so the skater can buffer any press with
no new snapshot state (`_last_press` is already in the snapshot). In `_tick_rolling`, just before `_handle_ollie(delta)`:

```gdscript
	# Ollie tapped just before touchdown and already released: pop now (a THUG-style jump buffer).
	if _crouch_time == 0.0 and not _held.has("ollie") and state.time_in_state < 0.05 \
			and tricks.pressed_within("ollie", TrickInput.OLLIE_LAND_BUFFER_TICKS):
		tricks.consume("ollie")
		_ollie(tune.ollie_min)
		return
```

## Watch / not done

- **No powerslide.** Stick back is a straight brake. A Skate-3 powerslide would mean a sideways slide state with a decel of about
  mu·g, roughly 5 to 7 m/s² here. It would be a new `skater.gd` feature, so it is out of scope for tuning.
- `wall_carve_speed_retention` (0.926) sits near its low edge; `roll_friction` 0.45 would fix it but needs the bot lines re-routed (see Round 3).
- `turn_radius_8ms` (3.3 m) is tighter than its 4.5 m target but inside the band. It is THUG-sharp. To widen it, lower `carve_grip`
  toward 15, but that also widens the 12 m/s turn to about 9.6 m.

## Round 3: carve retention and lab coverage

**Tuning (not shipped).** `roll_friction` 0.6 stays the default. Lowering it to 0.45 (mu about 0.025 at gravity 18; real wheels are 0.02)
fixes the drag in the lab: wall carve retention 0.926 to 0.956 (reference about 0.96 per carve), a full hands-off lap round the practice
DomeBowl (new `dome_lap_speed_retention`, r 8 m dome, 6.3 m ring, 4.4 s) 0.81 to 0.89, coast from 8 m/s 53 to 71 m (band 35 to 90),
halfpipe pump gain 1.88 to 1.90 (the pump is untouched). The lap loss scales linearly with `roll_friction` (0.35 gives 0.92, 0.25 gives
0.97). But the scripted bot lines are tuned to the 0.6 speeds and every change broke some of them, without a pattern: at 0.45 practice
96 (dome line: wall slam, one snag on the ollies line), beach 92 (bowl line wp_timeout), school 97 (Lunch Roof); at 0.5 practice 96, beach 77
(pier_rail wp_timeout), school 97; at 0.55 practice 42 (dome bail), beach 100, school 87 (Fountain Hop). Warehouse, downtown and hills stay
100 at 0.45. So the lap metric deliberately WARNs (0.81 against a 0.85 floor) until the bot lines are re-routed for the faster bowls;
then set the default to 0.45 and the WARN clears. The beach bowl is a rounded rectangle, so its carve is covered by the wall carve metric
(same transition profile) rather than a lap.

**New lab moves** (all in `tests/lab/lab_moves.gd`, targets above in `data/physics_targets.json`):

| metric | now | reference rationale |
|---|---:|---|
| `dome_lap_speed_retention` | 0.81 (0.89 at friction 0.45) | Real rolling loss 0.2 m/s per second; Skate 3 lets a bowl lap run many seconds before a pump is needed |
| `grind_entry_speed_retention` | 1.00 | THUG grinds lock on with no loss; Skate 3 loses a few percent |
| `manual_drift_1s` | 3.5x | THUG manual lean doubles about every half second (unstable pendulum) |
| `manual_recover_half_s` | 0.60 s | A PD stick catches a half-tipped manual in about half a second: catchable, not a twitch |
| `revert_speed_keep` | 1.00 | A revert is a stance switch only, in both reference games; it must never brake the combo |
| `fakie_landing_retention` | 0.94 | A 180 spin landed backward costs the same as a forward landing plus a little roll |
| `big_air_landing_keep` | 0.94 | 8 m drop (mega ramp scale, 19 m/s impact): scrub is clamped at about 5 percent |
| `big_air_clean_drop_m` | 20 (cap) | See below |
| `nollie_height_ratio` | PENDING | Real nollie about 0.9 of an ollie; THUG matches it |
| `powerslide_decel_ms2` | PENDING | Skate 3 slide sheds about half of 8 m/s in 0.7 s (about 6 m/s^2) |

**Pending moves.** A target whose `why` begins with `PENDING` and whose move returns NaN prints `PENDING` and counts as neither pass nor warn.
`m_nollie` presses the `nollie` button after a tap-height check and goes live as soon as it pops (height at least 0.2 m). `m_powerslide`
holds `powerslide` with a full stick at 10 m/s and goes live as soon as any state name contains `SLIDE` (the skater currently has none; the
poser already has a `powerslide` pose). If the trigger gets another name, change the string in `m_powerslide`.

**Gap found: no impact bail.** `Landing.judge` and `_land` decide a bail from board pose and heading only. An upright board lands clean
from 20 m (impact 26.6 m/s), keeping about 94 percent of its speed. That suits a THUG-leaning game and means a mega ramp can never slam
a clean board, but there is no height slam as in Skate 3. If one is wanted, add it in `_land` (for example a bail when `into` passes
about 24 m/s on flat) and tighten `big_air_clean_drop_m` max_ok to match; the lab move already searches up to 20 m.
