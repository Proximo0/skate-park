# School (`school`)

Owner: the School level builder. Everything for this level lives in `game/levels/school/`.

## Theme brief

High-school campus after hours, golden light. Classic street spots: stair sets with handrails, benches,
planters, ledges in the courtyard, the gym with a bank up to its roof, the parking lot (some cars, painted bays), the
sports field with bleachers and a running track. Lockers, bike racks, a flagpole, banners for the big game.

## Starting points

- Front steps (big stair set + hubba ledges), courtyard (planters, benches, manual pads), gym roof line.
- Parking lot with Traffic on the access road (a slow loop) and a few Pedestrians (students heading home).
- Sports field: bleachers to grind, a long bank along the track.
- Mood: school_dusk (golden hour, long shadows).

## Files

- `school_level.gd`: the level (`extends Level`). Currently a stub: ground, boundary, spawn, one quarter pipe, mood.
- `bot_route.json`: the play-bot's route for this level (`LevelRoute` format). Extend it as the level grows, so
  `LEVEL=school tools/bot_run.sh` keeps covering the main lines.
- Optional: `gaps.json` / `goals.json` (set `gaps_path` / `goals_path` in `_init`).
- Preview card: `game/levels/previews/school.png`, rendered by `tools/level_previews.sh school`.

Read `docs/levels.md` first: the Level API, the world kit (traffic, pedestrians, ocean, ambient life, moods), the
performance budget and the art bar.
