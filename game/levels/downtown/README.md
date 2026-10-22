# Downtown (`downtown`)

City blocks in bright late-morning light, a towering skyline at the end of every street, the busiest traffic in the
game, crowds on the sidewalks, pigeons, steam from the grates, banners and flags in the wind. Everything for the level
lives in this folder.

## Layout (see `dt_plan.gd`)

The play space is about 200 m x 146 m (`DtPlan.BOUNDS`, x -100..100, z -56..90): one civic block, the street round it,
the Line to the south, and three areas off it. The street grid runs on to 330 m each way, with towers out to a kilometre
and a landmark spire at the end of every avenue and street.

| Area | Where | What |
| --- | --- | --- |
| City Hall Plaza | the centre block (spawn on the promenade) | City Hall on a 2.5 m terrace; the 10-stair with two handrails, two hubbas, granite wing banks with outer hubbas; the promenade's manual pads; the fountain plaza (rim ledge, Fountain Clip bump, pair ledges, benches); the granite garden (three stepped ledges, a manual pad) |
| The Line | along z = 50 | twin monorail beams at 6.1 m with grindable edges end to end and two live trains; Central Station (platform, 24-stair with handrails and cheek hubbas, glass balustrades); under the Line: two long ledges, bus stops, a newsstand; the transit plaza (runout ledges, the red arc rail, hot-dog cart, platform lift) |
| The Garage | south-east | ramps up two decks to a roof level with the beams: a quarter pipe, a flat rail, a manual pad, parapet ledges; Roof To Line onto the beam |
| The Alleys | south-west | brick shops with a ramp onto their roofs and the roof-to-roof gap, loading docks across the alley, a fire escape rail, dumpsters; the DIY lot behind a fence (secret spot: quarter pipe, bank, barrier, the tape) |

Safe pockets: the plazas, the garden, the transit plaza, the garage roof and the DIY lot are all off the road; walkers
keep to the sidewalks and step aside; cars and trains stop for the skater ahead of them.

## Lines

- **Promenade**: spawn, manual pads, up a wing bank, the City Hall Ten or the rail or a hubba, out to the fountain.
- **Fountain**: the bump over the fountain's corner (Fountain Clip), the pair hop, the north ledge, back to the garden steps.
- **Station**: drop in on the platform (pause menu or the lift pad), the 24, the station rail or the cheeks, the runout
  ledges, the red arc, under the Line on the long ledges.
- **Garage to Line**: up the ramps (or drop in on the roof), quarter pipe air, along the roof edge onto the beam:
  Roof To Line into the Avenue Grind over the street.
- **Alleys**: up the wooden ramp, roof to roof, the dumpster hop, through the hole in the fence to the DIY quarter.

## Gaps (`gaps.json`, 23)

City Hall Ten, City Hall Rail, Hubba Hubba, Terrace Drop, Fountain Clip, Pair Hop, Garden Steps, Promenade Manual,
Garden Pad Manual, Station 24, Station Rail, Station Cheek, Avenue Grind, Roof To Line, Monorail Transfer, Under The
Line, Red Arc, Garage Air, Alley Roof Gap, Dock To Dock, Dumpster Hop, Fire Escape, Hole In The Fence (secret).

## Goals (`goals.json`, 13)

High score 15k / 40k / 90k, an 8,000 combo, S-K-A-T-E (one letter on each area's signature line), six pizza slices in
the corners, three gap coins in the air (Ten Out, Fountain Clip, Station 24), the secret tape (DIY lot), 12 gaps, a
5-second grind (the beams), a 5-second manual.

## Files

- `downtown_level.gd`: the Level (spawn, bounds, light, drop-ins, pickups); builds the areas below in `_ready`.
- `dt_plan.gd`: the plan (all shared coordinates). `dt_kit.gd`: skate furniture builders (ledges, hubbas, banks,
  stairs, handrails, kickers, planters, benches, kit MultiMeshes). `dt_batch.gd`: merges coloured boxes into one mesh.
- `dt_streets.gd`, `dt_traffic.gd`, `dt_crossing_signal.gd`: roads, sidewalks, markings, 24 cars on a ring and four
  corner loops, five signalled junctions/crossings.
- `dt_city.gd`, `dt_tower.gdshader`: every block filled with buildings (MultiMesh boxes with shader windows),
  storefronts, cornices, rooftops, the far skyline and the landmark towers.
- `dt_civic.gd`, `dt_water.gdshader`: City Hall and its plaza. `dt_transit.gd`, `dt_train.gd`: the Line, the station,
  the trains. `dt_garage.gd`: the garage. `dt_alley.gd`: the alleys and the DIY lot.
- `dt_life.gd`, `dt_crowd.gd`, `dt_pigeons.gd`, `dt_flag.gdshader`: people (24, with a distance LOD), pigeons on the
  ground and in the air, steam, street lights with banners, flags, trees. `dt_tape.gd`: the secret tape pickup.
- `bot_route.json`: 19 play-bot lines covering 20 gaps (`LEVEL=downtown tools/bot_run.sh`).
- Tests: `tests/unit/test_level_downtown.gd`. Preview: `game/levels/previews/downtown.png`.

## Budget

Measured from street level: about 215-385 draw calls and 0.29-0.59 M primitives (llvmpipe, Compatibility), 249 draws
and 0.23 M from the high overview. People past 45 m and cars past 140 m are not drawn; people cast shadows within 20 m. Buildings, skyline, street lights, banners, flags, trees and pigeons are MultiMeshes; each area's
static geometry is one or two merged meshes. No real lights in the day mood.
