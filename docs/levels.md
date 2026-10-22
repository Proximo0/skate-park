# Levels

How the game's levels are put together: the Level API and registry, how a level is chosen and loaded, the world kit
(traffic, pedestrians, ocean, ambient life, ground surfaces, moods, Houdini prop kits), the performance budgets, the art
bar and how to capture and check your work.

Six levels are registered: `practice` (the original park, `game/park/park.gd`) and five new ones, `warehouse`,
`beach`, `school`, `downtown` and `hills`. The five new ones start as **stubs** in `game/levels/<id>/`. Each has
ground, boundary walls, a spawn, one quarter pipe, its mood, a `README.md` theme brief and a `bot_route.json`. A level
builder replaces the stub's body and keeps the contract.

## 1. The Level API (`game/levels/level.gd`, `class_name Level extends Node3D`)

A level is a `Node3D` script that extends `Level`. Set the contract fields in `_init()`, which runs before main.gd reads
them. Build the world in `_ready()`.

| Field | Meaning |
|---|---|
| `spawn: Transform3D` | Where the skater starts and respawns. Basis -Z is the facing. Put it 0.1 m above a floor. |
| `bounds: Rect2` | The riding area in world x/z. `add_boundary()` walls it in, and the bot and tests check against it. |
| `kill_y: float` | Below this the skater respawns. The default is -20; main.gd copies the tuning only when a level changes it. |
| `mood_id: String` | Set by LevelRegistry from the entry. `setup_environment()` builds sky, sun, fog and tonemap from it. |
| `drop_ins`, `drop_in_names` | Drop-in spots for the pause menu. Fill them with `add_drop_in(id, label, xform)`. |
| `collectibles: Array[Collectible]` | Fill with `add_collectible(item, group, pos)`. main.gd wires them to the HUD. |
| `gaps_path`, `goals_path` | JSON for this level's gaps and goals. The defaults are the practice park's files. |
| `bot_route_path` | The play-bot route (set from the registry). |
| `preview_view: Array` | `[from, look_at]` for the level-select card render. Leave it empty for a raised view from behind the spawn. |
| `world_environment`, `sun`, `mood` | Filled by `setup_environment()`. |
| `skater` | Set by `bind_skater()` (main.gd calls it). The `skater_bound` signal fires then. |

Helpers:

- `setup_environment(preset_id = "")`: WorldEnvironment plus sun from `Mood` (§4). Call it first in `_ready()`.
- `add_ground(rect, top_y = 0, colour, name)`: a skateable slab (collision on layer 1, receives shadows only). Then
  give it a look with `WorldSurface.apply(ground, "concrete")`.
- `add_backdrop(kind, colour, size = 3000, y = -0.06)`: a huge visual-only plane under everything, so the world never
  ends in the sky's lower half past your edges.
- `add_boundary(rect = bounds)`: four invisible 40 m walls (`BoundaryN/S/W/E`) that overlap at the corners.
- `put(node, pos, yaw_deg, name)`: adds a piece and records it in `placed`.
- `add_drop_in(id, label, xform)` and `add_collectible(...)`.
- `load_bot_route()` returns the parsed `bot_route.json` (`LevelRoute`).
- `is_night()` reports the mood's night flag (Traffic headlights follow it).
- Static helpers: `Level.walls_around(rect, ...)` and `Level.of(node)`, which finds the Level above any node.

The practice park (`Park`) is a `Level` too and keeps its own constants. Nothing about it changed for players.

## 2. Registry and loading (`game/levels/level_registry.gd`)

`LevelRegistry.ENTRIES` is the single list of levels. Each entry has `id`, `name`, `blurb`, `script`, `mood`,
`bot_route` (a JSON path; practice uses the built-in BotLines), `preview` (`game/levels/previews/<id>.png`), `accent`
(the card colour) and `tag` (the card sticker). To add a level, append an entry. Nothing else needs to know about it.

- `ids()`, `has(id)`, `entry(id)`, `entries()`, `display_name(id)`, `preview(id)`
- `create(id) -> Level`: a new, not yet added level with `level_id`, `display_name`, `mood_id` and `bot_route_path` filled in.
- `resolve(Flags.args) -> id`: `--level=<id>` wins the first time, then the last selection (`LevelRegistry.selected`).
  Unknown ids fall back to practice.

How a level gets loaded:

- **Title, Play**: the level select (`game/ui/level_select.gd`, cards with previews). Picking a card sets `selected`
  and changes to `main.tscn`.
- **Pause, Change Level**: the same level select over the pause menu. main.gd re-enters `main.tscn` with the new selection.
- **Command line**: `godot --path . -- --level=beach`. `--testpark` still loads the tiny test park.
- **main.gd** calls `LevelRegistry.create(resolve(...))`, names the level `Park` for older code, puts the skater at
  `level.spawn`, applies `kill_y`, gaps and goals, and calls `bind_skater`.

## 3. World kit (`game/world/`)

Read `game/world/demo/world_demo.gd` (`WorldDemo`) top to bottom. It is a worked example of a city crossroads that
uses nearly every piece below. It is not a registered level.

### Traffic: `Traffic`, `TrafficCar`, `CarModel`, `LanePath`, `TrafficSignals`

```gdscript
var traffic := Traffic.new()
add_child(traffic)
var loop := LanePath.block_loop(Rect2(-60, -40, 60, 80), 0.0, 9.0, true).offset(2.0)  # +offset = right of travel
traffic.add_cars(traffic.add_lane(loop, 10.0), 6)           # kinds/colours optional
traffic.add_signal_poles(traffic.add_intersection(Vector3(0, 0, -40), 9.0))
```

- Lanes are `LanePath`s. Build them with `from_points(corners, closed, corner_radius)`, `from_path3d(path, closed)`
  or `block_loop(rect, y, radius, ccw)`. `offset(d)` gives the parallel lane and `reversed()` the other direction.
- Cars come from the Houdini car glbs (hatch, pickup, van) in paint variants. The baked body is 3 draw calls by day and
  4 at night. Cars accelerate and brake smoothly, slow for corners, keep their headway, stop at red and amber signals,
  and stop for the skater or any `traffic_obstacle` (walkers) in their lane.
- A car is an `AnimatableBody3D` on layer 1, so the skater collides with it. A moving car that touches the skater
  calls the skater's own `_bail()` and emits `skater_hit`.
- Headlight beams, lamps and brake lights switch on at night (`Level.is_night()`). Force them with `lights_mode`.
- Sims: `traffic_stops_for_skater` and `traffic_hit_bails_skater` (`tests/sim/sim_levels.gd`).

### Pedestrians: `Pedestrians`, `Pedestrian`, `PedBody`, `PedPoser`

```gdscript
var crowd := Pedestrians.new()
add_child(crowd)
crowd.add_walkers(LanePath.from_points(sidewalk_pts, true, 2.0), 6)
crowd.add_group(Vector3(-5.7, 0.15, 12), 3)            # a chatting group
crowd.add_idler(Vector3(5.9, 0.15, -8), PI * 0.5, "phone")
```

- Bodies are the player's own body builder (`SkaterBuilder.build_body`, random adult looks). Each is **baked** by
  `PedBody.bake`, which merges the rigid meshes per joint, from about 157 meshes to about 20 draw calls. The crowd
  builds a pool of 6 looks on a worker thread, then clones and re-colours the garments by hue for each person. Until a
  body arrives, a pedestrian walks unseen. In scripted or headless runs, the build happens synchronously.
- Behaviours: walk a path (back and forth or round a loop), stop now and then to idle or check a phone (a phone prop
  appears in the hand), and chat in groups. Pedestrians react to the skater: they step aside when you ride at them,
  startle when you fly past close, and sometimes wave.
- `PedPoser` is a `SkaterPoser`. **The poser gotcha:** call `add_child(poser)` and then `poser.set_process(false)`, or
  `SkaterPoser._process` overwrites the pose. Pedestrian does this, and drives the pose at an LOD rate (every frame
  under 28 m, less often to 110 m, hidden past 150 m).
- Joint angle signs for new poses are documented at the top of `ped_poser.gd`. For example, an upper arm's +X swings
  it forward, and Head +X tilts the face up.
- **Threading caveat:** while the crowd is loading, don't create Toon materials from other threads. Build everything
  else in `_ready()` as normal; the worker only touches its own new nodes.

### Ocean: `Ocean` (`ocean.gd` and `ocean.gdshader`)

```gdscript
var ocean := Ocean.new()
ocean.position = Vector3(0, -1.2, 78)   # local z = 0 is the still waterline, the sea lies toward +Z
ocean.berm = 1.15                       # dry-sand height above sea level
add_child(ocean)
ocean.add_beach(900.0, 478.0, 80.0)     # sand mesh + trimesh collision + wet-sand darkening (call in the tree)
```

- Six Gerstner waves: a swell that shoals, steepens and runs up the sand, plus cross chop. Troughs keep a thin film
  over the sand (`Ocean.FILM`), so the backwash doesn't uncover sandbars across the shallows.
- The shading is unshaded and Compatibility-safe. It uses no depth or screen textures, because depth comes from the
  known beach profile. It has a depth tint (turquoise over the sand, deep blue further out), crest translucency toward
  the sun, a Fresnel sky reflection, cel-banded sun glints and sparkles, lacy breaking-crest foam, a thin swash line on
  the sand, and a far fade into the horizon colour.
- `apply_mood(preset)` is called for you and takes `water_deep`, `water_shallow`, sky and night dimming from the mood.
- CPU mirror: `height_at(x, z, t)`, `depth_at(z)` and `Ocean.sand_height(...)` match the shader. Use them for floating
  props. The ocean respawns a skater who falls in (`respawn_depth`).
- **Decision: the procedural `Ocean`, not the kit's `ocean_plane.glb` and `shoreline_foam.glb`.** The kit plane is
  flat vertex colour with no waves. Rendered side by side in Compatibility, the procedural sea reads far better (moving
  swell, real swash, glints), and it costs 2 draw calls and about 140k vertices for the whole bay. The kit's dressing
  pieces (`headland_left/right`, `distant_island`, `sailboat`) frame the bay well; the beach stub places them through
  LevelKit. `wave_crest.glb` is left for the builder if a stylised breaking curl is wanted.

### Ambient life

- `Birds.flock(kind, count, centre, radius, seed)`: gull, pigeon, crow or bat. One MultiMesh with wings flapping in
  the shader, about 1 draw call per flock.
- `SwayTrees`: `add("palm" | "round" | "pine" | "bush", pos, size)` and then `rebuild()`. One MultiMesh per kind; the
  wind sways them in the vertex shader.
- `SteamVent.create(colour, rate, height)`: CPUParticles steam for vents and manholes.
- `FlickerLight.sodium_lamp(height, failing, colour, seed)`: pole, head, spot light, additive floor pool and fog beam.
  `failing` flickers like a dying tube. `light_pool()` and `beam_cone()` fake lights cheaply (fog is disabled on them,
  so the quads don't show).

### Ground surfaces: `WorldSurface` (`surface.gdshader`)

`WorldSurface.apply(node, kind, colour = default, pattern_scale = 1)` covers every mesh under a node. The kinds are
`concrete` (4 m joints, pour patches, stains), `asphalt`, `sand` (ripples, footprints, wet darkening),
`grass` (mown stripes that fade with distance), `pavers`, `planks` and `court`. Everything is worked out in world
space, so you need no UVs or textures. Flat tops in sun stay in the lit band whatever the sun height, so a low golden
sun doesn't blotch them. Materials are cached by kind, colour and scale.

### Moods: `Mood` (`mood.gd` and `mood_sky.gdshader`)

The presets are `day`, `beach_sunny`, `warehouse_night`, `school_dusk`, `city_afternoon`, `city_night` and
`hills_golden`. Each one covers the sky gradient bands, clouds, sun disc and rings, moon and stars, city glow, sun
angle, colour and energy, shadow distance, fog, ambient light, tonemap, exposure and glow, water colours and lamp
colour. `Mood.build(id)` returns `{preset, environment (WorldEnvironment), sun}`. To add a mood, add a dict of
overrides to `PRESETS`; unspecified keys come from `BASE`.

### Houdini prop kits: `LevelKit` (`game/levels/level_kit.gd`)

Each level has a kit in `assets/props/houdini/<id>/`: glbs plus a `kit.json` manifest that gives the file, tris,
bounds and collision for each piece. The conventions are metres, +Y up, front facing -Z and the origin at the base
centre. Collision boxes are axis-aligned in the piece's own space; `"mesh"` means use a trimesh.

```gdscript
var kit := LevelKit.open("beach")                                  # cached
kit.place(self, "palm_tree_a", Vector3(12, 0, 30), deg_to_rad(40))   # StaticBody3D + manifest boxes
kit.place(self, "rocks", Vector3(-8, 0, 60))                         # "mesh" collision -> trimesh
kit.place(self, "food_stand", p, yaw, {"tint": Color("ff6b5e"), "scale": 1.2})
kit.place(self, "sailboat", p, yaw, {"collide": false, "shadow": false})  # visual only
var deco: Node3D = kit.visual("umbrella_towel_set")                  # meshes only, not added
```

- Every surface is converted to the toon look the HoudiniProps way (base colour kept, materials shared through Toon's
  cache). Meshes that carry vertex colour (palm trunks, driveways) get the vertex-colour toon material automatically.
- Options: `tint` recolours surfaces named body, plastic, paint or accent. `scale` is uniform and collision follows.
  `collide: false` gives a plain Node3D. `shadow: false` stops shadow casting (use it for small clutter). `name` sets
  the node name.
- Queries: `names()`, `info(piece)`, `bounds(piece)`, `tris(piece)`, `collision_boxes(piece)`, `LevelKit.kit_ids()`.
- Grind edges are not in the manifests. Add `GrindRail`s yourself (`PieceKit.rail` or `PieceKit.round_rail`) along
  ledges, benches and rails.
- New glbs need an import under the lock:
  `flock /tmp/skate_import.lock timeout 300 godot --headless --path . --import`.

## 4. Performance budgets (target: 60 fps on a mid Windows PC, Compatibility renderer)

| Thing | Budget |
|---|---|
| Draw calls in view | 600 or fewer at street level, 900 or fewer from the highest camera |
| Primitives in view | 1.5M or fewer |
| Real lights (Omni or Spot) in view | about 12. Fake the rest with `FlickerLight.light_pool` and `beam_cone`. |
| Cars | about 20 per level (3 to 4 draw calls each) |
| Pedestrians | 15 to 25 (about 20 draw calls each close up; LOD hides them past 150 m) |
| Trees, birds and clutter | MultiMesh (`SwayTrees`, `Birds`) for anything with more than about 10 copies |
| Kit pieces | Share materials (LevelKit does). Use `shadow: false` on small clutter. |
| Shadow casters | Only things taller than about 0.5 m. Ground and backdrop never cast. |

Measured on the reference captures: the demo crossroads with 12 cars, 14 pedestrians, 14 trees and pigeons draws
about 140 calls and 0.26M prims at street level, and about 400 calls and 1.3M prims from above (the crowd is most of
it). The beach ocean draws 2 to 3 calls and 0.14M prims. Check your level from both heights with the capture script
(§6) and read the `draws=` and `prims=` numbers it prints.

## 5. Art bar

- **Read as one game.** Use the toon shading, the colour-cache materials (`Toon.material` or LevelKit), the bold skate
  palette and the moods. Outlines stay off by default.
- **No placeholder look.** No untextured grey boxes at street level. Give every walkable surface a WorldSurface kind
  and every edge a reason (curb, coping, ledge, planter).
- **Life in every view.** Each level needs at least two of: traffic, pedestrians, birds, swaying trees, steam, flicker,
  surf.
- **People are clearly adults**, dressed by the part catalog. They react to the skater.
- **The horizon is never empty.** Use a backdrop plane, skyline, hills, headlands or sea.
- **Keep the strong existing things:** the title and splash art, UI kit, shop interior, shoes, hair, speed lines and
  trick text. Don't nerf the halfpipe pump.

## 6. Capture, check and test

- **Level-select previews:** run `tools/level_previews.sh [id ...]` to write `game/levels/previews/<id>.png` from
  `preview_view`. Re-run it when your level changes.
- **Renders** need a real renderer: `xvfb-run -a godot --rendering-driver opengl3 --path . -s <script.gd> -- --scripted`.
  Load classes with `load("res://...")` in `-s` scripts; bare `class_name`s and autoloads aren't resolved there.
  Capture from the spawn and from high, look critically, and iterate.
- **Unit tests:** `tools/run_tests.sh test_levels` checks the registry, that every level builds headless with an
  environment, that the spawn sits over a floor, that the walls enclose the bounds, that the bot route parses inside
  the bounds, and that the kits load. `tools/run_tests.sh test_world_kit` covers moods, LanePath, the ocean model,
  signals and ped poses.
- **Sims:** `tools/run_sims.sh` includes `sim_levels`: a 3 s spawn ride on each level, a car stopping for the skater
  and a car knocking the skater down.
- **Play-bot on a level:** `LEVEL=beach tools/bot_run.sh` rides the lines of `bot_route.json`. The format is
  `{"lines": [{"name", "limit", "soft", "expect", "wps": [...]}]}`, with the same waypoint dicts as BotDriver
  (`p`, `spd`, `r`, `act`, `tp: {pos, dir, speed}`, `drop`). `LEVEL=practice` (the default) keeps the built-in lines.
- **Finish** with lint 0 (`tools/lint.sh`), all tests and sims green, and the practice bot still at 100.
