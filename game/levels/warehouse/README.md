# Creepy Warehouse (`warehouse`)

An abandoned industrial complex at night (Nox Docks). Everything for this level lives in `game/levels/warehouse/`.
The skate area is 192 x 152 m (bounds x -96..96, z -78..74; north is -Z). The moonlit downtown skyline sits to the
north behind an elevated highway with live traffic, and a frontage road with a few cars runs to the south. Mood:
`warehouse_night`, retuned in `WarehouseLevel._tune_mood`: a low cold moon with orthogonal shadows (55 m), height fog
that pools along the yards and thins above the roofline, mostly flat grey-violet ambient, and a darkened sky.

## Areas and lines

- **Main hall** (x -40..40, z -20..20, floor at 1.2, roof at 12): two long pallet racks (the top-rail ledges make
  Rack To Rack), the north catwalk (y 4.4) with its rails, stairs and the stair gap, the DIY vert quarter pipe in the
  west, the forklift and its kicker (Forklift Hop), a plywood A-frame with a steel ridge coping (Spine Transfer), the
  pallet gap, the pallet manual pad, the conveyor and a fallen I-beam to grind, and the skaters' corner with a sofa and
  a burn barrel. Moonlight comes through the broken skylights as merged shafts with dust; hanging lamps make pools.
- **Secret room** (the annex, x 40.5..50, z 7.5..20.5): through the half-open roll door behind the east racks. It
  holds a red lamp, a TV, a mannequin, a quarter pipe and the lost tape.
- **Loading docks and truck court** (south): dock ledges and stairs, a drained truck-well quarter pipe (Truck Well
  Air) with a kicker over its west rim (Truck Well Hop), a flatbed with a DIY ramp up its tail that lines up with the
  east dock door (Flatbed To Dock), jersey barriers, dumpsters, the guard booth and the guard's patrol route.
- **Container yard** (east): row A/B is a ramp-up container run with a gap under the gantry crane (Container Gap), the
  row D hop, the two-high wallride wall of row C, and stacks around the edges and in the south-east lot.
- **Rail spur and boiler yard** (north and west): a long spur rail grind, a boxcar, a flatcar and a gondola (Dock To
  Flatcar, Gondola Grind), pipe runs (Pipe Dream, Pipe Hop), the settling pit bowl (Pit Transfer), tanks, a 38 m
  smokestack and the boiler house.

## Gaps (`gaps.json`, 22)

Pallet Gap, Forklift Hop, Spine Transfer, Catwalk Stairs, Catwalk Marathon (1500), DIY Vert Air, Rack To Rack, Truck
Well Air, Truck Well Hop, Dock Stairs, Flatbed To Dock, Container Gap, Container Hop, Container Wallride, Dock To
Flatcar, Gondola Grind, Rail Spur, Pit Transfer, Pipe Dream (1500), Pipe Hop, Secret Room (2000), Pallet Pad Manual.
`bot_route.json` rides 21 lines and verifies every gap except Container Wallride.

## Goals (`goals.json`, 12)

High Score 15,000; Pro Score 40,000; Graveyard Shift 6,000 combo; S-K-A-T-E; the six spray cans; the lost tape; the
C coin (Container Hop) and the F coin (Forklift Hop); Gap Hunter (8 gaps); grind for 5 s; manual for 4 s; one special.

## Life

- Traffic: 14 cars on the elevated highway (they run into tunnel portals at both ends) and 4 on the frontage road.
- People: the night watchman (the guard) with a flashlight, walking the court; two skaters in the corner; an idler on
  the rail dock.
- Critters: bats in the rafters, crows on the gantry and the smokestack, pigeons, and rats (one MultiMesh) that run
  faster when the skater comes near.
- Weather and effects: steam vents (including the boiler roof), drips under the roof leaks, puddles, failing lamps.

## Files

- `warehouse_level.gd`: the level (WarehouseLevel). It sets the mood, the pickups, flattening and shadow trimming.
- `wh_outdoor.gd`: the ground, the slab, the docks, the truck well and court, the yard, the rail spur, the boiler yard
  and the fence.
- `wh_hall.gd`: the hall shell, racks, catwalk, forklift, A-frame, centre pieces, graffiti and the annex.
- `wh_props.gd`: the trailers, the flatbed, the rolling stock, the gantry, the tanks, the stack, the pipes and the booth.
- `wh_lights.gd`: the lamps. About a dozen real lights are in view from anywhere; the rest are fakes with only a pool
  and a beam. It also builds the moon shafts and merges the static lamp meshes.
- `wh_world.gd`: the skyline, the highway, the frontage, the people, the critters and the weather.
- `wh_geo.gd`: geometry helpers. Batch merges every `wh_surface` material into one per-vertex material per tile.
  It also handles flattening and the graffiti tags.
- `wh_pickup.gd`: the can and tape pickups.
- Shaders:
  - `wh_surface.gdshader`: the procedural surfaces, with toon moon bands and smooth lamp falloff;
  - `wh_tag.gdshader`: the graffiti;
  - `wh_skyline.gdshader`: the city windows and haze;
  - `wh_shaft.gdshader`: the moon shafts.

## Budgets (Compatibility, 1280x720)

Draw calls: about 420 at the spawn, 450 in the hall and 565 at the docks (the worst street-level view), and about
530 from the high overview. Primitives stay at or under 0.54M.
