class_name DtPlan
extends RefCounted
## Downtown's layout in numbers, shared by every builder. North is -Z. Level space is world space.
##
##   Streets: two avenues (x = X_W, X_E) and two streets (z = Z_N, Z_S), each 12 m wide with a lane each way, four
##   signal-controlled intersections and a signalled mid-block crosswalk on Z_S at x = 0. The grid carries on outside
##   the riding area (OUTER_X / OUTER_Z) as the rest of the city, under a skyline of towers.
##   Blocks are raised to the plaza level P behind a rolled granite curb (a wedge, so it never snags).
##
##   Areas: CIVIC PLAZA (centre block: City Hall terrace, the 10-stair with hubbas and handrails, the fountain plaza
##   west, the granite garden east), THE LINE (an elevated monorail along MONO_Z with a station and its 24-stair down
##   to the transit plaza), THE GARAGE (south-east: two ramps up to a rooftop flush with the monorail beams), THE ALLEYS
##   (south-west: docks, dumpsters, a roof gap, and a hidden DIY spot behind a torn fence).

const P: float = 0.12  ## plaza / sidewalk level (the roads are at 0)
const ROAD_HALF: float = 6.0
const LANE: float = 3.0  ## lane centre offset from the road centre line
const WALK: float = 5.0  ## sidewalk width
const CURB_RUN: float = 0.3  ## the rolled curb's wedge, road side of each block edge

const X_W: float = -50.0
const X_E: float = 50.0
const Z_N: float = -44.0
const Z_S: float = 30.0
const MID_X: float = 0.0  ## the mid-block crosswalk on Z_S
## The city grid outside the riding area (road centre lines).
const OUTER_X: Array[float] = [-250.0, -150.0, -50.0, 50.0, 150.0, 250.0]
const OUTER_Z: Array[float] = [-244.0, -144.0, -44.0, 30.0, 130.0, 230.0]
const CITY_HALF: float = 330.0  ## the grid's slab and streets run this far from the centre

const BOUNDS := Rect2(-100.0, -56.0, 200.0, 146.0)

## Inner blocks (between road edges), x/z rects.
const CENTER := Rect2(-44.0, -38.0, 88.0, 62.0)
const SOUTH := Rect2(-44.0, 36.0, 88.0, 54.0)
const SE := Rect2(56.0, 36.0, 44.0, 54.0)
const SW := Rect2(-100.0, 36.0, 44.0, 54.0)
const EAST := Rect2(56.0, -38.0, 44.0, 62.0)
const WEST := Rect2(-100.0, -38.0, 44.0, 62.0)

## Civic plaza.
const HALL := Rect2(-22.0, -33.5, 44.0, 9.5)  ## City Hall's footprint
const TERRACE := Rect2(-27.0, -24.0, 54.0, 11.0)  ## the raised terrace in front of it
const TERRACE_H: float = 2.5
const STAIR_STEPS: int = 10
const STAIR_RUN: float = 0.5
const STAIR_HALF: float = 8.0  ## the stairs span x in [-8, 8]
const FOUNTAIN := Vector3(-24.0, 0.0, 6.0)
const FOUNTAIN_R: float = 5.5

## The Line (monorail).
const MONO_Y: float = 6.12  ## beam top (= the station platform and the garage roof)
const MONO_Z: float = 50.0
const BEAM_A: float = 48.4
const BEAM_B: float = 51.6
const BEAM_W: float = 1.0
const BEAM_H: float = 1.2
const BEAM_X0: float = -300.0
const BEAM_X1: float = 300.0
const PYLONS_X: Array[float] = [-118.0, -101.0, -84.0, -66.0, -50.0, -34.0, -17.0, 0.0, 17.0, 34.0, 50.0, 72.0, 89.0, 106.0, 123.0]
const STATION := Rect2(-22.0, 53.1, 44.0, 4.9)  ## the platform (top at MONO_Y); its edge clears the trains
const STATION_STEPS: int = 24
const STATION_STAIR_HALF: float = 5.0

## The garage.
const GARAGE := Rect2(62.0, 53.1, 34.0, 34.9)
const L1: float = 3.12
const ROOF: float = 6.12
const RAMP1 := Rect2(62.0, 57.0, 6.0, 22.0)  ## ground -> L1, rising south
const RAMP2 := Rect2(90.0, 57.0, 6.0, 22.0)  ## L1 -> roof, rising north

## The alleys.
const ALLEY_X0: float = -80.0  ## the north-south alley: x in [-80, -74]
const ALLEY_X1: float = -74.0
const ALLEY_Z0: float = 70.0  ## the east-west alley: z in [70, 76]
const ALLEY_Z1: float = 76.0
const DIY := Rect2(-100.0, 70.0, 16.0, 20.0)  ## the hidden spot behind the torn fence
const DIY_FENCE_X: float = -84.0

const SPAWN := Vector3(0.0, P + 0.1, 15.0)


## True when a point (x, z) is on a road surface (between road edges), inside the city.
static func on_road(x: float, z: float) -> bool:
	for rx: float in OUTER_X:
		if absf(x - rx) < ROAD_HALF:
			return true
	for rz: float in OUTER_Z:
		if absf(z - rz) < ROAD_HALF:
			return true
	return false


## Every city block (between road edges) of the outer grid, as x/z rects.
static func grid_blocks() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var xs: Array[float] = [-CITY_HALF]
	xs.append_array(OUTER_X)
	xs.append(CITY_HALF)
	var zs: Array[float] = [-CITY_HALF]
	zs.append_array(OUTER_Z)
	zs.append(CITY_HALF)
	for i: int in xs.size() - 1:
		for j: int in zs.size() - 1:
			var x0: float = xs[i] + (ROAD_HALF if i > 0 else 0.0)
			var x1: float = xs[i + 1] - (ROAD_HALF if i + 1 < xs.size() - 1 else 0.0)
			var z0: float = zs[j] + (ROAD_HALF if j > 0 else 0.0)
			var z1: float = zs[j + 1] - (ROAD_HALF if j + 1 < zs.size() - 1 else 0.0)
			out.append(Rect2(x0, z0, x1 - x0, z1 - z0))
	return out
