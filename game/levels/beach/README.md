# Beachfront (`beach`)

Owner: the Beachfront level builder. Everything for this level lives in `game/levels/beach/`.

## Theme brief

Sunny beachfront: a concrete skatepark right on the sand by a boardwalk, palms, a pier running out over the
water, lifeguard towers, beach huts and food stands. The ocean (game/world/ocean.gd) rolls real waves onto the shore
with foam on the swash line and a far horizon that melts into the sky. The view out to sea is the money shot.

## Starting points

- Concrete park (bowl, snake run, ledges) on the slab; a boardwalk (WorldSurface "planks") with benches and rails.
- Pier: a long plank deck on pilings out over the surf, rideable, with a drop back to the sand.
- Ocean: Ocean node with shore_z on the sand line, Ocean.beach_mesh for the sand so the foam line matches the swash.
- Ambient: Birds.gulls over the water, SwayTrees palms, Pedestrians on the boardwalk, a few surf vans parked.
- Mood: beach_sunny.

## Files

- `beach_level.gd`: the level (`extends Level`). Currently a stub: ground, boundary, spawn, one quarter pipe, mood.
- `bot_route.json`: the play-bot's route for this level (`LevelRoute` format). Extend it as the level grows, so
  `LEVEL=beach tools/bot_run.sh` keeps covering the main lines.
- Optional: `gaps.json` / `goals.json` (set `gaps_path` / `goals_path` in `_init`).
- Preview card: `game/levels/previews/beach.png`, rendered by `tools/level_previews.sh beach`.

Read `docs/levels.md` first: the Level API, the world kit (traffic, pedestrians, ocean, ambient life, moods), the
performance budget and the art bar.
