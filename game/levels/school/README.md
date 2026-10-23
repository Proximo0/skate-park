# School (`school`)

Sunset Valley High after hours, at dusk. Everything for this level lives in `game/levels/school/`. The campus is
200 x 175 m inside the fence (bounds x -100..100, z -90..85; north is -Z), with the perimeter road, the town and the
hills outside it. Mood: `school_dusk`, retuned in `SchoolLevel._tune_mood` (low west-north-west sun, two shadow
splits, light fog).

## Areas and lines

- **Front plaza** (south, the spawn): paver promenade to the drained fountain (basin to drop into, a rim to grind, a
  pedestal to hop), two raised lawns with ledges, promenade ledges, a basketball court, the flagpole, the senior
  steps (tiered seat walls) and the cafeteria patio tables. The raised front terrace (y 2) has the big front steps
  (8 stairs, three handrails, two hubbas) and a bank.
- **Main building** (z 0..22): a breezeway (floor 2.0) runs through it from the terrace to the courtyard; the back
  stairs drop out of it.
- **Courtyard** (z -50..0): the second-floor balcony (y 4.5) with its long guard rail, the ADA ramp (a 36 m
  down-rail), the double set off the balcony's east end (the Leap of Faith clears it all), the lunch shelter roof,
  planters, the manual pad, benches, lockers.
- **Sports field** (north, sunk to y -3): banks, bleachers, the 12-stair field set with rails, the north retaining
  wall to wallride, the track, goalposts, sprinklers, field lights, crows.
- **Gym and lot** (east): the loading-dock ramp to the annex roof (3.0), a bank up to the gym roof (6.0, the secret
  tape), the Gym Roof Drop into the field; the parking lot with the school buses, cars, islands and bike racks.

## Gaps (`gaps.json`, 25)

Front Steps, Front Rail, Back Door Eight, Back Door Rail, Leap of Faith (2500), Double Kink, ADA Rail, Hall Pass
Rail, Lunch Roof, Planter Hop, Planter Hop Again, Detention Manual, Fountain Hop, Rim Ride, Bleacher Bomb, Bank Drop,
Back Forty Drop, Twelve to the Field, Field Rail, Wall of Fame (wallride), Up on the Roof, Gym Roof Drop (2000),
Loading Dock Rail, Senior Steps Ollie Up, Terrace Drop.

## Goals (`goals.json`, 12, 120 s runs)

Scores 15k / 40k / 90k, an 8k combo, S-K-A-T-E (front steps, fountain, ADA rail, lunch roof, field rail), five lost
textbooks, the Leap of Faith letter, the secret tape on the gym roof, 10 gaps, a 4 s grind, a 5 s manual, kickflip
the front steps.

## Files

- `school_level.gd`: the level: layout, areas, zones, pickups, mood.
- `school_geo.gd`: per-area batched geometry (vertex-coloured batches, one collision body per area).
- `school_parts.gd`: skate pieces (stairs with rails and hubbas, banks with lips, ledges, benches, planters).
- `school_dress.gd`, `school_lamps.gd`, `school_blinker.gd`, `school_sprinkler.gd`, `school_pickup.gd`: dressing
  and life (lamps that flicker on, people, the janitor, sprinklers, birds, blinkers, pickups).
- `school_shadow_lod.gd`: turns pedestrian shadows on only near the camera (draw budget).
- `school_backdrop.gd`, `school_town.gdshader`, `school_facade.gdshader`: the town, hills and building facades.
- `bot_route.json`: the play-bot's 22 lines; `LEVEL=school tools/bot_run.sh` must score 100.
- `school_snag_sweep.gd` / `.tscn`: the snag sweep over the whole campus (same options as `tests/lab/snag_sweep.gd`).
- Tests: `tests/unit/test_level_school.gd`. Preview card: `game/levels/previews/school.png`
  (`tools/level_previews.sh school`).
