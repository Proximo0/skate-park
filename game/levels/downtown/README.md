# Downtown (`downtown`)

Owner: the Downtown level builder. Everything for this level lives in `game/levels/downtown/`.

## Theme brief

Downtown city blocks: plazas with ledges and fountains, granite banks, crosswalks, traffic lights, moving
traffic on the streets and people on the sidewalks, skyscrapers all round (a skyline you can see from anywhere), a
subway entrance, newsstands, planters, bus stops.

## Starting points

- Two blocks with a central plaza (fountain, ledges, gaps over planters) and a cross street with live Traffic.
- Pedestrians on every sidewalk with idle stops (phone, chat) and crosswalk crossings.
- Skyscrapers: MultiMesh window boxes or merged meshes, lit windows (night variant city_night).
- Mood: city_afternoon (switch to city_night for a night version).

## Files

- `downtown_level.gd`: the level (`extends Level`). Currently a stub: ground, boundary, spawn, one quarter pipe, mood.
- `bot_route.json`: the play-bot's route for this level (`LevelRoute` format). Extend it as the level grows, so
  `LEVEL=downtown tools/bot_run.sh` keeps covering the main lines.
- Optional: `gaps.json` / `goals.json` (set `gaps_path` / `goals_path` in `_init`).
- Preview card: `game/levels/previews/downtown.png`, rendered by `tools/level_previews.sh downtown`.

Read `docs/levels.md` first: the Level API, the world kit (traffic, pedestrians, ocean, ambient life, moods), the
performance budget and the art bar.
