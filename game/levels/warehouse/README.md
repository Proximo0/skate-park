# Creepy Warehouse (`warehouse`)

Owner: the Creepy Warehouse level builder. Everything for this level lives in `game/levels/warehouse/`.

## Theme brief

Abandoned industrial warehouse at night. Sodium lights (orange pools, a few failing and flickering), fog and deep
shadows, catwalks overhead, loading docks with roll-up doors, broken skylights letting moonlight in, rusted
shelving and crates. Creepy but skateable and readable: every line still has to read clearly in the dark, so key
the riding surfaces with light pools and keep the creepy stuff in the set dressing (no gore, Teen rating).

## Starting points

- Interior hall with the catwalk ring (grindable rails), a loading-dock bank run outside, a sunken pit bowl.
- Lights: FlickerLight.sodium_lamp along the aisles, a couple failing; moonlight shafts under the skylights.
- Ambient: SteamVent from floor grates, Birds (pigeons/bats flock) up in the rafters, distant train horn later.
- Mood: warehouse_night (Mood). Night flag is on: lamps glow, headlights on any yard traffic.

## Files

- `warehouse_level.gd`: the level (`extends Level`). Currently a stub: ground, boundary, spawn, one quarter pipe, mood.
- `bot_route.json`: the play-bot's route for this level (`LevelRoute` format). Extend it as the level grows, so
  `LEVEL=warehouse tools/bot_run.sh` keeps covering the main lines.
- Optional: `gaps.json` / `goals.json` (set `gaps_path` / `goals_path` in `_init`).
- Preview card: `game/levels/previews/warehouse.png`, rendered by `tools/level_previews.sh warehouse`.

Read `docs/levels.md` first: the Level API, the world kit (traffic, pedestrians, ocean, ambient life, moods), the
performance budget and the art bar.
