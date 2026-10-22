class_name HillsLevel
extends Level
## The Hills: a hillside suburb at golden hour, built on a real sloped height field (HillsTerrain) with the streets cut
## into it (HillsRoad). North (-Z) is uphill. See README.md here for the layout, lines, gaps and goals.
##
##   Crest Drive      the through street along the top (light traffic), houses uphill of it
##   Summit Court     a cul-de-sac off Crest Drive: driveways, garages with kickers, the curb ring
##   The Ditch        the hillside water channel straight down the middle (spawn in its basin under the culvert)
##   Pool Row         three drained kidney pools in back yards on one terrace, fences between: the hopping line
##   Hillcrest Drive  the long winding downhill on the west side (no through traffic): the speed run
##   Sunset Court     a second cul-de-sac off Hillcrest, above the park
##   Canyon Road      the steep straight bomb down the east side
##   Valley Park      the skate spot at the bottom, where the ditch spills out
##   Valley View      the through street along the bottom: the school crossing and the overlook rail, the valley below

const HALF: float = 110.0
const ROAD_HALF: float = 4.0
const WALK: float = 2.0
const ROAD_CORE: float = ROAD_HALF + WALK + 0.6
const ROAD_MARGIN: float = 5.0
## The pool terrace (back yards of Summit Court's south houses) and its height.
const TERRACE := Rect2(-16.0, -14.0, 64.0, 13.0)
## Pool decks (12 x 8, grid aligned), one per yard; fences between the yards at these x.
const POOL_DECKS: Array[Rect2] = [Rect2(-13.0, -12.0, 12.0, 8.0), Rect2(9.0, -12.0, 12.0, 8.0), Rect2(31.0, -12.0, 12.0, 8.0)]
const YARD_FENCES: Array[float] = [4.0, 26.0]
const PARK := Rect2(-30.0, 47.0, 108.0, 32.0)
## Behind Summit Court's south houses, above the terrace wall.
const BACK_STRIP := Rect2(-16.0, -20.0, 64.0, 5.0)
const SUMMIT_BULB := Vector3(8.0, 0.0, -40.0)
const SUNSET_BULB := Vector3(-8.0, 0.0, 25.0)
const BULB_R: float = 12.0
## The secret garden (a hedged, sunken back yard west of the park) and its little pool's deck.
const SECRET := Rect2(-58.0, 56.0, 18.0, 15.0)
const SECRET_DECK := Rect2(-54.0, 59.0, 10.0, 7.0)

var terrain: HillsTerrain
## The pool terrace's and the park's heights (from the hillside under them, see _init).
var terrace_y: float = 16.5
var park_y: float = 8.5
var roads: Dictionary = {}  ## name -> HillsRoad
var road_list: Array[HillsRoad] = []
var channel: HillsChannel
var lots: Array[Dictionary] = []
var _drives: Array[Dictionary] = []  ## driveway corridors: {a: Vector3, b: Vector3, road, side, s}
var _grind_root: Node3D


func _init() -> void:
	bounds = Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0)
	kill_y = -12.0
	gaps_path = "res://game/levels/hills/gaps.json"
	goals_path = "res://game/levels/hills/goals.json"
	terrace_y = snappedf(HillsTerrain.natural(TERRACE.get_center().x, TERRACE.get_center().y) - 0.3, 0.25)
	park_y = snappedf(HillsTerrain.natural(PARK.get_center().x, PARK.get_center().y) - 0.8, 0.25)
	channel = HillsChannel.new()
	# the ditch: its lip meets the pool terrace beside the yards, its floor runs out onto the park at the spill
	channel.floor_end = park_y
	var f_mid: float = terrace_y - HillsChannel.DEPTH
	var k: float = (f_mid - park_y) / (channel.z_end - TERRACE.get_center().y)
	channel.floor_top = f_mid + k * (TERRACE.get_center().y - channel.z_top)
	# spawn: in the ditch's basin under the culvert, facing down the hill (+Z)
	spawn = Transform3D(Basis(Vector3.UP, PI), Vector3(channel.cx, channel.floor_top + 0.1, channel.z_head + 3.0))
	preview_view = [Vector3(-48.0, 58.0, -118.0), Vector3(22.0, 6.0, 30.0)]


func _ready() -> void:
	setup_environment()
	_tune_mood()
	_layout_roads()
	_layout_lots()
	_shape_ground()
	_build_ground()
	_build_roads()
	add_child(channel.build())
	_build_pools()
	_build_lots()
	HillsSpots.terrace(self)
	HillsSpots.park(self)
	HillsSpots.secret(self)
	HillsTown.build(self)
	_collectibles()
	_zones()
	add_boundary()
	_merge_statics()


## The hills_golden mood, tuned for a long view: thinner fog so the valley town and the mountains read, a lower sun.
func _tune_mood() -> void:
	var env: Environment = world_environment.environment
	env.fog_density = 0.00055
	env.fog_sky_affect = 0.6
	# two shadow splits over 90 m: the shadow passes were most of the frame's draw calls
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0


# --- layout --------------------------------------------------------------------------------------------------------

func _add_road(r: HillsRoad) -> HillsRoad:
	roads[r.road_name] = r
	road_list.append(r)
	return r


func _layout_roads() -> void:
	var crest: HillsRoad = _add_road(HillsRoad.through("crest", PackedVector2Array([
		Vector2(-344.0, -70.0), Vector2(-220.0, -86.0), Vector2(-120.0, -80.0), Vector2(-60.0, -83.0), Vector2(0.0, -80.0),
		Vector2(60.0, -82.0), Vector2(120.0, -80.0), Vector2(220.0, -72.0), Vector2(344.0, -88.0)]), ROAD_HALF, WALK))
	crest.profile_from_natural(60.0)
	var valley: HillsRoad = _add_road(HillsRoad.through("valley", PackedVector2Array([
		Vector2(-344.0, 98.0), Vector2(-220.0, 84.0), Vector2(-120.0, 88.0), Vector2(-40.0, 87.0), Vector2(40.0, 88.0),
		Vector2(120.0, 86.0), Vector2(220.0, 92.0), Vector2(344.0, 80.0)]), ROAD_HALF, WALK))
	valley.profile_from_natural(60.0)
	valley.sides = [true, false]  # no sidewalk on the overlook side (the rail runs there)
	var hc_a: Vector3 = valley.sample(float(valley.closest(Vector3(-88.0, 0.0, 87.0))["s"]))
	var hc_b: Vector3 = crest.sample(float(crest.closest(Vector3(-92.0, 0.0, -81.0))["s"]))
	var hill: HillsRoad = _add_road(HillsRoad.through("hillcrest", PackedVector2Array([
		Vector2(hc_a.x, hc_a.z), Vector2(-90.0, 70.0), Vector2(-84.0, 50.0), Vector2(-64.0, 36.0), Vector2(-47.0, 18.0),
		Vector2(-52.0, -3.0), Vector2(-76.0, -16.0), Vector2(-93.0, -36.0), Vector2(-92.0, -60.0), Vector2(hc_b.x, hc_b.z)]), ROAD_HALF, WALK))
	hill.profile_from_natural(40.0, hc_a.y, hc_b.y, 30.0)
	var cy_a: Vector3 = crest.sample(float(crest.closest(Vector3(90.0, 0.0, -82.0))["s"]))
	var cy_b: Vector3 = valley.sample(float(valley.closest(Vector3(88.0, 0.0, 87.0))["s"]))
	var canyon: HillsRoad = _add_road(HillsRoad.through("canyon", PackedVector2Array([
		Vector2(cy_a.x, cy_a.z), Vector2(91.0, -60.0), Vector2(93.0, -30.0), Vector2(88.0, 0.0), Vector2(85.0, 30.0),
		Vector2(89.0, 62.0), Vector2(cy_b.x, cy_b.z)]), ROAD_HALF, WALK))
	canyon.profile_from_natural(40.0, cy_a.y, cy_b.y, 30.0)
	var su_a: Vector3 = crest.sample(float(crest.closest(Vector3(SUMMIT_BULB.x, 0.0, -80.0))["s"]))
	var summit: HillsRoad = _add_road(HillsRoad.through("summit", PackedVector2Array([
		Vector2(su_a.x, su_a.z), Vector2(su_a.x, -66.0), Vector2(SUMMIT_BULB.x, -54.0), Vector2(SUMMIT_BULB.x, SUMMIT_BULB.z)]), ROAD_HALF, WALK))
	summit.profile_from_natural(30.0, su_a.y, NAN, 14.0)
	var sun_a: Vector3 = hill.sample(float(hill.closest(Vector3(-46.0, 0.0, 22.0))["s"]))
	var sunset: HillsRoad = _add_road(HillsRoad.through("sunset", PackedVector2Array([
		Vector2(sun_a.x, sun_a.z), Vector2(-34.0, 21.0), Vector2(-22.0, 23.0), Vector2(SUNSET_BULB.x, SUNSET_BULB.z)]), ROAD_HALF, WALK))
	sunset.profile_from_natural(24.0, sun_a.y, NAN, 12.0)
	# Junctions: a side street leaves a through street level with it (the through street's corridor is level across
	# its core), so each side street holds its junction's height for the core's width before it starts to climb or
	# drop; otherwise the corridors fight and leave a kink (a launch ramp at speed) and buried curbs.
	var hold: float = ROAD_CORE + 0.4
	hill.flatten(-1.0, hold, hc_a.y, 24.0)
	hill.flatten(hill.length - hold, hill.length + 1.0, hc_b.y, 24.0)
	canyon.flatten(-1.0, hold, cy_a.y, 24.0)
	canyon.flatten(canyon.length - hold, canyon.length + 1.0, cy_b.y, 24.0)
	# the cul-de-sacs: Summit Court sits a little above the hillside (a gentler street down from Crest Drive), each
	# bulb level with the end of its street
	summit_y = su_a.y - 2.4
	summit.profile_fn(func(s: float) -> float: return lerpf(su_a.y, summit_y, smoothstep(hold - 1.0, summit.length - BULB_R - 7.0, s)))
	sunset.flatten(-1.0, hold, sun_a.y, 10.0)
	sunset_y = sunset.pts[sunset.pts.size() - 1].y
	sunset.flatten(sunset.length - BULB_R - 6.0, sunset.length + 1.0, sunset_y, 8.0)


var summit_y: float = 20.0
var sunset_y: float = 14.0


## A house lot facing road `rn` at arc length s on `side` (-1 left of travel, +1 right): the house `setback` metres
## behind the sidewalk. opts: drive_x (local x of the driveway, + = house's left seen from the street... kit +x),
## garage (detached garage at drive_x), kicker, pad_extra (Vector2 more pad: x, back), tint.
func _lot(rn: String, s: float, side: int, kind: String, opts: Dictionary = {}) -> Dictionary:
	var r: HillsRoad = roads[rn]
	var toward: Vector3 = -r.right(s) * float(side)
	var depth: float = HillsLevel._house_depth(kind)
	var setback: float = float(opts.get("setback", 7.0))
	var c: Vector3 = r.sample(s) - toward * (ROAD_HALF + WALK + setback + depth)
	return _lot_at(Vector3(c.x, 0.0, c.z), toward, kind, opts, rn)


## A lot whose house centre is at `c` (x, z), front facing `toward` (horizontal unit), driveway to road `rn`.
func _lot_at(c: Vector3, toward: Vector3, kind: String, opts: Dictionary, rn: String) -> Dictionary:
	var yaw: float = atan2(-toward.x, -toward.z)
	var basis := Basis(Vector3.UP, yaw)
	var r: HillsRoad = roads[rn]
	var drive_x: float = float(opts.get("drive_x", HillsLevel._drive_x(kind)))
	var depth: float = HillsLevel._house_depth(kind)
	var drive_end_local := Vector3(drive_x, 0.0, -depth - 0.5)
	var garage: bool = bool(opts.get("garage", false))
	if garage:
		drive_end_local = Vector3(drive_x, 0.0, -6.0)
	var end_xz: Vector3 = Vector3(c.x, 0.0, c.z) + basis * drive_end_local
	var cl: Dictionary = r.closest(end_xz)
	var rs: float = float(cl["s"])
	var side: int = 1 if float(cl["d"]) > 0.0 else -1
	var start_xz: Vector3 = r.sample(rs) + r.right(rs) * float(side) * (ROAD_HALF + WALK)
	start_xz.y = 0.0
	var road_y: float = r.sample(rs).y
	var bulb_cut: float = NAN
	if rn in ["summit", "sunset"] and rs > r.length - BULB_R - 1.0:
		# a cul-de-sac lot: the driveway leaves the ring sidewalk, straight out from the bulb's middle
		var bc: Vector3 = r.pts[r.pts.size() - 1]
		var out := Vector3(end_xz.x - bc.x, 0.0, end_xz.z - bc.z).normalized()
		start_xz = Vector3(bc.x, 0.0, bc.z) + out * (BULB_R + WALK)
		road_y = bc.y
		bulb_cut = atan2(out.z, out.x)
	var run: float = Vector2(end_xz.x - start_xz.x, end_xz.z - start_xz.z).length()
	var nat: float = HillsTerrain.natural(c.x, c.z)
	var max_grade: float = float(opts.get("grade", 0.16))
	var pad_y: float = clampf(nat, road_y - max_grade * run, road_y + max_grade * run)
	if opts.has("pad_y"):
		pad_y = float(opts["pad_y"])
	var lot: Dictionary = {
		"centre": Vector3(c.x, pad_y, c.z), "yaw": yaw, "basis": basis, "kind": kind, "opts": opts,
		"drive_a": Vector3(start_xz.x, road_y, start_xz.z), "drive_b": Vector3(end_xz.x, pad_y, end_xz.z),
		"road": rn, "s": rs, "side": side, "drive_x": drive_x,
	}
	var hw: float = HillsLevel._house_half_w(kind)
	var lo: float = minf(-hw, drive_x - 2.0 - (3.4 if garage else 0.0))
	var hi: float = maxf(hw, drive_x + 2.0 + (3.4 if garage else 0.0))
	var zf: float = -6.5 if garage else -depth - 1.5
	lot["pad"] = Rect2(lo - 0.8, zf, hi - lo + 1.6, depth + 3.0 - zf + (3.0 if garage else 0.0))
	lots.append(lot)
	if is_nan(bulb_cut):
		r.cuts.append([side, rs - 2.4, rs + 2.4])
	else:
		lot["bulb_cut"] = bulb_cut
	return lot


static func _house_depth(kind: String) -> float:
	match kind:
		"house_ranch":
			return 4.0
		"house_colonial":
			return 4.4
		"house_cottage":
			return 3.4
	return 4.0


static func _drive_x(kind: String) -> float:
	match kind:
		"house_ranch":
			return 7.0
		"house_colonial":
			return 7.6
		"house_cottage":
			return 6.2
	return 7.0


static func _house_half_w(kind: String) -> float:
	match kind:
		"house_ranch":
			return 9.6
		"house_colonial":
			return 5.0
		"house_cottage":
			return 4.0
	return 4.6


func _layout_lots() -> void:
	# Summit Court: round the bulb (fronts facing the middle). The two side lots have detached garages with kickers.
	var b := Vector3(SUMMIT_BULB.x, 0.0, SUMMIT_BULB.z)
	var south_pad: float = summit_y - 0.3
	var bulb_lots: Array = [
		[Vector3(-22.0, 0.0, -42.0), "house_two_storey", {"garage": true, "kicker": true, "drive_x": -8.5, "pad_y": summit_y + 0.9}],
		[Vector3(-6.0, 0.0, -21.0), "house_ranch", {"pad_y": south_pad}],
		[Vector3(22.0, 0.0, -21.0), "house_cottage", {"pad_y": south_pad, "drive_x": -6.2}],
		[Vector3(38.0, 0.0, -42.0), "house_colonial", {"garage": true, "kicker": true, "drive_x": 9.0, "pad_y": summit_y + 0.9}],
	]
	for e: Array in bulb_lots:
		var c: Vector3 = e[0]
		var toward: Vector3 = (b - c).normalized()
		if absf(c.z + 21.0) < 0.1:
			toward = Vector3(0.0, 0.0, -1.0)  # the south houses sit square to the grid (their back wall is the terrace wall)
		_lot_at(c, toward, str(e[1]), e[2] as Dictionary, "summit")
	# Sunset Court
	var b2 := Vector3(SUNSET_BULB.x, 0.0, SUNSET_BULB.z)
	for e: Array in [[Vector3(-26.0, 0.0, 8.0), "house_two_storey"], [Vector3(6.0, 0.0, 6.0), "house_ranch"],
			[Vector3(-26.0, 0.0, 41.0), "house_cottage"], [Vector3(10.0, 0.0, 41.0), "house_colonial"]]:
		var c: Vector3 = e[0]
		_lot_at(c, (b2 - c).normalized(), str(e[1]), {}, "sunset")
	# Crest Drive: the uphill (north) side, and the downhill side west of Summit Court and between it and the ditch
	var crest: HillsRoad = roads["crest"]
	var kinds: Array[String] = ["house_colonial", "house_ranch", "house_two_storey", "house_cottage", "house_ranch", "house_colonial", "house_two_storey"]
	var xs_n: Array[float] = [-74.0, -50.0, -24.0, 12.0, 36.0, 60.0, 82.0]
	for k: int in xs_n.size():
		var s: float = float(crest.closest(Vector3(xs_n[k], 0.0, -80.0))["s"])
		_lot("crest", s, -1, kinds[k], {"setback": 5.0, "grade": 0.2})
	for e: Array in [[-62.0, "house_cottage"], [-34.0, "house_two_storey"], [32.0, "house_cottage"]]:
		var s: float = float(crest.closest(Vector3(float(e[0]), 0.0, -80.0))["s"])
		_lot("crest", s, 1, str(e[1]), {"setback": 6.0})
	# Canyon Road's inner side: back yards run down to the ditch
	var canyon: HillsRoad = roads["canyon"]
	for e: Array in [[-50.0, "house_ranch"], [-24.0, "house_cottage"], [0.0, "house_two_storey"], [24.0, "house_colonial"]]:
		var s: float = float(canyon.closest(Vector3(90.0, 0.0, float(e[0])))["s"])
		_lot("canyon", s, 1, str(e[1]), {"setback": 3.5, "drive_x": -6.5 if str(e[1]) != "house_ranch" else 7.0})
	# Hillcrest Drive: a few on the inside of its bends
	var hill: HillsRoad = roads["hillcrest"]
	for e: Array in [[Vector2(-92.0, -44.0), 1, "house_ranch"], [Vector2(-60.0, -6.0), -1, "house_cottage"], [Vector2(-84.0, 50.0), 1, "house_two_storey"]]:
		var p2: Vector2 = e[0]
		var s: float = float(hill.closest(Vector3(p2.x, 0.0, p2.y))["s"])
		_lot("hillcrest", s, int(e[1]), str(e[2]), {"setback": 4.0})


func _shape_ground() -> void:
	terrain = HillsTerrain.new()
	var t: HillsTerrain = terrain
	# house pads
	for lot: Dictionary in lots:
		var pr: Rect2 = lot["pad"]
		var c: Vector3 = (lot["centre"] as Vector3) + (lot["basis"] as Basis) * Vector3(pr.get_center().x, 0.0, pr.get_center().y)
		c.y = (lot["centre"] as Vector3).y
		t.flat_box(c, pr.size * 0.5, float(lot["yaw"]), 4.0)
	# the strip behind Summit Court's south houses: one level, so the terrace wall below it is even
	t.flat_rect(BACK_STRIP, summit_y - 0.3, Vector4(4.0, 4.0, 4.0, 0.0))
	# the park and the pool terrace (hard north and south edges: retaining walls)
	t.flat_rect(PARK, park_y, Vector4(6.0, 4.0, 3.0, 3.0))
	t.flat_rect(TERRACE, terrace_y, Vector4(5.0, 4.0, 0.0, 4.0))
	# the secret garden, sunk to the park's level, and the lawn between it and the park
	t.flat_rect(SECRET, park_y, Vector4(4.0, 0.0, 4.0, 4.0))
	t.flat_rect(Rect2(SECRET.end.x, SECRET.position.y - 2.0, PARK.position.x - SECRET.end.x + 1.0, SECRET.size.y + 4.0), park_y, Vector4(0.0, 0.0, 3.0, 3.0))
	# the cul-de-sacs and their streets
	for rn: String in ["summit", "sunset"]:
		var r: HillsRoad = roads[rn]
		t.corridor(r.corridor_points(), ROAD_CORE, ROAD_MARGIN)
	t.flat_disc(Vector3(SUMMIT_BULB.x, summit_y, SUMMIT_BULB.z), BULB_R + WALK + 0.6, ROAD_MARGIN)
	t.flat_disc(Vector3(SUNSET_BULB.x, sunset_y, SUNSET_BULB.z), BULB_R + WALK + 0.6, ROAD_MARGIN)
	# the ditch
	t.corridor(channel.corridor_points(), HillsChannel.HALF + 1.0, 6.0)
	# the main streets: the through streets last so they win at the junctions
	for rn: String in ["hillcrest", "canyon", "crest", "valley"]:
		var r: HillsRoad = roads[rn]
		t.corridor(r.corridor_points(), ROAD_CORE, ROAD_MARGIN)
	# driveways
	for lot: Dictionary in lots:
		t.corridor(PackedVector3Array([lot["drive_a"], lot["drive_b"]]), 2.0, 1.5)
	# pieces with their own floors
	for r: Rect2 in POOL_DECKS:
		t.set_rect(r, terrace_y)
		t.cut_hole(r)
	t.set_rect(SECRET_DECK, park_y)
	t.cut_hole(SECRET_DECK)
	channel.shape_ground(t)


# --- building ------------------------------------------------------------------------------------------------------

func _build_ground() -> void:
	var near := MeshInstance3D.new()
	near.name = "Ground"
	near.mesh = terrain.near_mesh()
	near.material_override = WorldSurface.material("grass", Color("7fa04e"))
	near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(near)
	var far := MeshInstance3D.new()
	far.name = "FarLand"
	far.mesh = terrain.far_mesh(_far_colour)
	far.material_override = Toon.material_vc(Color.WHITE)
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far)
	add_child(terrain.collision_body(bounds.grow(3.0)))


## Colour of the far land: lawns near the suburb, golden dry grass on the hills, an olive valley floor, hazy mountains.
func _far_colour(x: float, y: float, z: float) -> Color:
	var r: float = Vector2(x, z).length()
	var lawn := Color("6f8f45")
	var dry := Color("b8904c")
	var olive := Color("6c7a44")
	var rock := Color("7a6a86")
	var c: Color = lawn.lerp(dry, smoothstep(130.0, 300.0, r))
	if z > 160.0 and y < -25.0:
		c = c.lerp(olive, smoothstep(-25.0, -45.0, y))
	c = c.lerp(rock, smoothstep(80.0, 260.0, y))
	# the valley town's streets and lots under its buildings
	if z > 600.0 and x > -1260.0 and x < 1060.0:
		c = c.lerp(Color("7c766c"), 0.55 * smoothstep(600.0, 700.0, z) * (1.0 - smoothstep(1550.0, 1700.0, z)))
	return c


func _build_roads() -> void:
	var asphalt: ShaderMaterial = WorldSurface.material("asphalt", Color("4d4f58"))
	var walk_mat: ShaderMaterial = WorldSurface.material("concrete", Color("c4bfb4"), 0.5)
	var body := StaticBody3D.new()
	body.name = "Sidewalks"
	add_child(body)
	_grind_root = Node3D.new()
	_grind_root.name = "Curbs"
	add_child(_grind_root)
	var bulbs: Array = [[SUMMIT_BULB, summit_y, "summit"], [SUNSET_BULB, sunset_y, "sunset"]]
	for r: HillsRoad in road_list:
		var s0: float = 0.0
		var s1: float = r.length
		if r.road_name in ["summit", "sunset"]:
			s1 = r.length - BULB_R + 1.0
		if r.road_name in ["hillcrest", "canyon", "summit", "sunset"]:
			s0 = 0.0
		var mi := MeshInstance3D.new()
		mi.name = "Road_" + r.road_name
		mi.mesh = r.ribbon(terrain, s0, s1, -ROAD_HALF, ROAD_HALF, HillsRoad.ROAD_LIFT, 1.0 if absf(r.box.size.x) < 300.0 else 2.0)
		mi.material_override = asphalt
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		for side: int in [-1, 1]:
			for run: Vector2 in r.walk_runs(side, road_list, _bulb_cuts(r)):
				if not _near_play(r, run):
					continue
				var m: ArrayMesh = r.sidewalk_mesh(terrain, side, run)
				var w := MeshInstance3D.new()
				w.mesh = m
				w.material_override = walk_mat
				w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				body.add_child(w)
				var cs := CollisionShape3D.new()
				cs.shape = m.create_trimesh_shape()
				body.add_child(cs)
				_grind_root.add_child(PieceKit.rail(r.curb_points(terrain, side, run), "ledge", "Curb_%s_%d" % [r.road_name, _grind_root.get_child_count()]))
	for bb: Array in bulbs:
		_bulb(bb[0] as Vector3, float(bb[1]), str(bb[2]), asphalt, walk_mat, body)


## Sidewalk cuts where a street runs into its bulb (the ring sidewalk takes over).
func _bulb_cuts(r: HillsRoad) -> Array:
	if r.road_name in ["summit", "sunset"]:
		return [[-1, r.length - BULB_R - WALK, r.length + 1.0], [1, r.length - BULB_R - WALK, r.length + 1.0]]
	return []


## Only build sidewalks inside (or just outside) the riding area.
func _near_play(r: HillsRoad, run: Vector2) -> bool:
	var a: Vector3 = r.sample(run.x)
	var b: Vector3 = r.sample(run.y)
	var area: Rect2 = bounds.grow(40.0)
	return area.has_point(Vector2(a.x, a.z)) or area.has_point(Vector2(b.x, b.z))


## A cul-de-sac bulb: the round of asphalt, the ring sidewalk with its curb (one grind line round the ring, open at
## the street's mouth).
func _bulb(c: Vector3, y: float, rn: String, asphalt: Material, walk_mat: Material, body: StaticBody3D) -> void:
	var r: HillsRoad = roads[rn]
	var n: int = 64
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre: Vector3 = terrain.at(c.x, c.z, HillsRoad.ROAD_LIFT)
	for k: int in n:
		var a0: float = TAU * float(k) / float(n)
		var a1: float = TAU * float(k + 1) / float(n)
		var p0: Vector3 = terrain.at(c.x + cos(a0) * BULB_R, c.z + sin(a0) * BULB_R, HillsRoad.ROAD_LIFT)
		var p1: Vector3 = terrain.at(c.x + cos(a1) * BULB_R, c.z + sin(a1) * BULB_R, HillsRoad.ROAD_LIFT)
		HillsRoad.tri_facing(st, centre, p0, p1, Vector3.UP)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Bulb_" + rn
	mi.mesh = st.commit()
	mi.material_override = asphalt
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# the ring sidewalk, open where the street comes in
	var mouth: Vector3 = r.sample(r.length - BULB_R - 1.0)
	var mouth_a: float = atan2(mouth.z - c.z, mouth.x - c.x)
	var open: float = asin(clampf((ROAD_HALF + 0.3) / BULB_R, 0.0, 1.0)) + 0.02
	var cut_w: float = 2.3 / (BULB_R + WALK * 0.5)
	var cut_angles: Array[float] = []
	for lot: Dictionary in lots:
		if str(lot["road"]) == rn and lot.has("bulb_cut"):
			cut_angles.append(fposmod(float(lot["bulb_cut"]) - mouth_a, TAU))
	cut_angles.sort()
	var spans: Array[Vector2] = []
	var a0: float = open
	for ca: float in cut_angles:
		if ca - cut_w > a0 + 0.05:
			spans.append(Vector2(a0, ca - cut_w))
		a0 = ca + cut_w
	if TAU - open > a0 + 0.05:
		spans.append(Vector2(a0, TAU - open))
	for sp: Vector2 in spans:
		_ring_walk(c, y, mouth_a + sp.x, mouth_a + sp.y, walk_mat, body, rn)


func _ring_walk(c: Vector3, y: float, a_start: float, a_end: float, walk_mat: Material, body: StaticBody3D, rn: String) -> void:
	var steps: int = maxi(int((a_end - a_start) / TAU * 64.0), 2)
	var ws := SurfaceTool.new()
	ws.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curb := PackedVector3Array()
	var prev: Array = []
	for k: int in steps + 1:
		var a: float = lerpf(a_start, a_end, float(k) / float(steps))
		var d := Vector3(cos(a), 0.0, sin(a))
		var gi: Vector3 = terrain.at(c.x + d.x * BULB_R, c.z + d.z * BULB_R)
		var go: Vector3 = terrain.at(c.x + d.x * (BULB_R + WALK), c.z + d.z * (BULB_R + WALK))
		var top: float = y + HillsRoad.CURB_H
		var it := Vector3(gi.x, maxf(top, gi.y + 0.02), gi.z)
		var ot := Vector3(go.x, maxf(top, go.y + 0.02), go.z)
		var ib := Vector3(gi.x, gi.y - HillsRoad.SKIRT, gi.z)
		var ob := Vector3(go.x, go.y - HillsRoad.SKIRT, go.z)
		curb.append(Vector3(c.x + d.x * (BULB_R + 0.05), top, c.z + d.z * (BULB_R + 0.05)))
		if k == 0 or k == steps:
			var along := Vector3(-sin(a), 0.0, cos(a)) * (-1.0 if k == 0 else 1.0)
			HillsRoad.tri_facing(ws, it, ot, ob, along)
			HillsRoad.tri_facing(ws, it, ob, ib, along)
		if k > 0:
			HillsRoad.quad_up(ws, prev[0], prev[1], ot, it)
			HillsRoad.tri_facing(ws, prev[0], it, ib, -d)
			HillsRoad.tri_facing(ws, prev[0], ib, prev[2], -d)
			HillsRoad.tri_facing(ws, prev[1], ot, ob, d)
			HillsRoad.tri_facing(ws, prev[1], ob, prev[3], d)
		prev = [it, ot, ib, ob]
	ws.generate_normals()
	var m: ArrayMesh = ws.commit()
	var w := MeshInstance3D.new()
	w.mesh = m
	w.material_override = walk_mat
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(w)
	var cs := CollisionShape3D.new()
	cs.shape = m.create_trimesh_shape()
	body.add_child(cs)
	_grind_root.add_child(PieceKit.rail(curb, "ledge", "BulbCurb_%s_%d" % [rn, _grind_root.get_child_count()]))


func _build_pools() -> void:
	for i: int in POOL_DECKS.size():
		var r: Rect2 = POOL_DECKS[i]
		var pool: Node3D = HillsPool.build(r.size, 5.0, 2.9, 2.1, 1.0, 1.9, 3.4, 0.2, "pool_" + "abc"[i])
		pool.name = "Pool" + "ABC"[i]
		pool.position = Vector3(r.get_center().x, terrace_y, r.get_center().y)
		put(pool, pool.position, 0.0)


func _build_lots() -> void:
	var kit: LevelKit = LevelKit.open("hills")
	var drive_mat: ShaderMaterial = WorldSurface.material("concrete", Color("d2cdc2"), 0.5)
	var houses := Node3D.new()
	houses.name = "Houses"
	add_child(houses)
	var clutter := Node3D.new()
	clutter.name = "Mailboxes"
	add_child(clutter)
	var drives := SurfaceTool.new()
	drives.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tints: Array[Color] = [Color(0, 0, 0, 0), Color("f3e3c3"), Color("dfe9e1"), Color(0, 0, 0, 0), Color("f1d9cf"), Color("e3e3ef")]
	var garages: int = 0
	for i: int in lots.size():
		var lot: Dictionary = lots[i]
		var c: Vector3 = lot["centre"]
		var yaw: float = float(lot["yaw"])
		kit.place(houses, str(lot["kind"]), c, yaw, {"tint": tints[i % tints.size()]})
		if bool((lot["opts"] as Dictionary).get("garage", false)):
			HillsSpots.garage_lot(self, kit, lot, garages)
			garages += 1
		# the driveway: a concrete strip on the ground from the sidewalk edge to the pad
		var a: Vector3 = lot["drive_a"]
		var b: Vector3 = lot["drive_b"]
		var dir := Vector3(b.x - a.x, 0.0, b.z - a.z)
		var run: float = dir.length()
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0.0, dir.x) * 1.6
		var n: int = maxi(int(run), 1)
		var pa: Vector3
		var pb: Vector3
		for k: int in n + 1:
			var p: Vector3 = a.lerp(b, float(k) / float(n))
			var l: Vector3 = terrain.at(p.x - side.x, p.z - side.z, 0.03)
			var rr: Vector3 = terrain.at(p.x + side.x, p.z + side.z, 0.03)
			if k > 0:
				HillsRoad.quad_up(drives, pa, pb, rr, l)
			pa = l
			pb = rr
		var mb: Vector3 = a + side * 1.4 + dir * 0.6
		kit.place(clutter, "mailbox", terrain.at(mb.x + side.x * 0.6, mb.z + side.z * 0.6), yaw, {"shadow": false})
	drives.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Driveways"
	mi.mesh = drives.commit()
	mi.material_override = drive_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	HillsMerge.merge(houses, true)
	HillsMerge.merge(clutter, false)


## S-K-A-T-E along the lines, the pizza, the pool coins and the secret tape.
func _collectibles() -> void:
	var hc: HillsRoad = roads["hillcrest"]
	var cy: HillsRoad = roads["canyon"]
	add_collectible("S", "skate", hc.ground_point(terrain, hc.length - 40.0, 2.0, 1.0))
	add_collectible("K", "skate", Vector3(YARD_FENCES[0], terrace_y + 2.1, TERRACE.get_center().y))
	add_collectible("A", "skate", Vector3(channel.cx, channel.floor_at(0.0) + 1.0, 0.0))
	add_collectible("T", "skate", Vector3(60.0, park_y + 6.0, 74.5))
	add_collectible("E", "skate", cy.ground_point(terrain, cy.length - 26.0, 2.0, 1.0))
	add_collectible("pizza", "pizza", Vector3(SUMMIT_BULB.x, summit_y + 1.0, SUMMIT_BULB.z))
	var drive: Dictionary = {}
	for lot: Dictionary in lots:
		if bool((lot["opts"] as Dictionary).get("kicker", false)):
			drive = lot
			break
	if not drive.is_empty():
		var a: Vector3 = drive["drive_a"]
		var b: Vector3 = drive["drive_b"]
		var to_street := Vector3(a.x - b.x, 0.0, a.z - b.z).normalized()
		add_collectible("pizza", "pizza", Vector3(a.x, summit_y + 2.0, a.z) + to_street * 2.5)
	add_collectible("pizza", "pizza", Vector3(2.0, summit_y - 0.3 + 0.5 + 0.7, TERRACE.position.y - 0.5))
	add_collectible("pizza", "pizza", Vector3(32.0, park_y + 2.2, 60.5))
	var vr: HillsRoad = roads["valley"]
	add_collectible("pizza", "pizza", vr.ground_point(terrain, float(vr.closest(Vector3(-4.0, 0.0, 88.0))["s"]), ROAD_HALF + HillsTown.SHOULDER, 0.95 + 0.6))
	for i: int in POOL_DECKS.size():
		var r: Rect2 = POOL_DECKS[i]
		# down in the pool, where the line rolls through
		var floor_y: float = terrace_y - HillsPool.depth_at(0.0, 5.0, 2.1, 1.0)
		add_collectible(str(i + 1), "pools", Vector3(r.get_center().x, floor_y + 1.0, r.get_center().y))
	add_collectible("tape", "tape", Vector3(SECRET_DECK.get_center().x + 1.0, park_y - 0.9, SECRET_DECK.get_center().y))


## Bakes the static dressing into a mesh per material per area (draw calls).
func _merge_statics() -> void:
	for n: String in ["Sidewalks", "PoolRow", "ValleyPark", "SecretGarden", "SchoolCrossing", "Channel", "PoolA", "PoolB", "PoolC"]:
		var node: Node3D = get_node_or_null(n) as Node3D
		if node != null:
			HillsMerge.merge(node, n != "Sidewalks")
	for c: Node in get_children():
		if c.name.begins_with("Garage"):
			HillsMerge.merge(c as Node3D, true)


## A gap zone `size` big centred on `c` (its floor `below` metres under c).
func _zone(zone_id: String, c: Vector3, size: Vector3, below: float = 1.0) -> Area3D:
	var z: Area3D = PieceKit.gap_zone(zone_id, Vector3(c.x - size.x * 0.5, c.y - below, c.z - size.z * 0.5), size)
	add_child(z)
	return z


## A zone across a street at arc length s (the whole width, sidewalks too).
func _street_zone(zone_id: String, rn: String, s: float) -> void:
	var r: HillsRoad = roads[rn]
	var w: float = (ROAD_HALF + WALK) * 2.0 + 2.0
	_zone(zone_id, r.sample(s), Vector3(w, 4.0, w))


func _zones() -> void:
	var hc: HillsRoad = roads["hillcrest"]
	_street_zone("hillcrest_top", "hillcrest", hc.length - 22.0)
	_street_zone("hillcrest_bottom", "hillcrest", 14.0)
	var cy: HillsRoad = roads["canyon"]
	_street_zone("canyon_top", "canyon", 20.0)
	_street_zone("canyon_bottom", "canyon", cy.length - 14.0)
