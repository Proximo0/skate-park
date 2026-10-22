# The Hills (`hills`)

Owner: the The Hills level builder. Everything for this level lives in `game/levels/hills/`.

## Theme brief

Suburban hills: long downhill streets that wind down toward the valley, driveways, cul-de-sacs, front lawns,
drained backyard pools to skate, fences and hedges, mailboxes, parked cars, a view out over the valley and the town
below at golden hour.

## Starting points

- The level is a hillside: streets as long ramps (bank down and up), cul-de-sac bowls at the ends.
- Drained pools in back yards (Bowl pieces) reached through gaps over fences.
- Traffic: a couple of slow cars on the street loop; Pedestrians walking dogs on the sidewalks.
- Valley view: low-poly town far below with Birds over it; set kill_y well below the lowest street.
- Mood: hills_golden.

## Files

- `hills_level.gd`: the level (`extends Level`). Currently a stub: ground, boundary, spawn, one quarter pipe, mood.
- `bot_route.json`: the play-bot's route for this level (`LevelRoute` format). Extend it as the level grows, so
  `LEVEL=hills tools/bot_run.sh` keeps covering the main lines.
- Optional: `gaps.json` / `goals.json` (set `gaps_path` / `goals_path` in `_init`).
- Preview card: `game/levels/previews/hills.png`, rendered by `tools/level_previews.sh hills`.

Read `docs/levels.md` first: the Level API, the world kit (traffic, pedestrians, ocean, ambient life, moods), the
performance budget and the art bar.
