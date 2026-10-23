class_name SchoolLevel
extends Level
## School: Sunset Valley High after hours, at dusk. Five areas joined by lines (north is -Z, the low sun sits in the
## west-north-west):
##   FRONT PLAZA (south, z 31..85): the spawn, the drained fountain (a sunken basin with a rim to grind and a pedestal
##     to hop), the flagpole, the senior steps (tiered seat walls), the marquee sign and the raised front terrace with
##     the big front steps (8 stairs, three handrails, two hubbas) and a bank.
##   MAIN BUILDING (z 0..22): two storeys; a breezeway (floor 2.0) runs through it from the terrace to the courtyard,
##     where the back stairs drop into the courtyard.
##   COURTYARD (z -50..0): the second-floor balcony (y 4.5) with its long guard rail, the ADA ramp up to it (its rail is
##     a 36 m down-rail), the double set off the balcony's east end (the Leap of Faith gaps it all), the lunch shelter
##     (a roof you can ollie onto from the ramp), planters, a long manual pad, benches and lockers.
##   SPORTS FIELD (north, sunk to y -3): banks, bleachers and the field stairs down from the courtyard edge, the north
##     retaining wall to wallride, the running track, goalposts, sprinklers, field lights and the scoreboard.
##   GYM AND LOT (east): the gym (roof 6.0) and its locker-room annex (roof 3.0); the loading-dock ramp climbs to the
##     annex roof and a bank climbs on to the gym roof (the secret: the tape is up there), and the roof's west edge is
##     the Gym Roof Drop into the field. The parking lot holds the school buses, parked cars, islands and bike racks.
## Outside the fence: the perimeter road (the only traffic), sidewalks, the town and the hills beyond.
##
## Geometry is batched per area (SchoolGeo: one mesh per material, one collision body per area); the skate pieces
## come from SchoolParts; the dressing, life and backdrop from SchoolDress and SchoolBackdrop. Gaps, goals and the bot
## route are JSON files next to this script.

const DIR: String = "res://game/levels/school/"
const BOUNDS := Rect2(-100.0, -90.0, 200.0, 175.0)
const FIELD_Y: float = -3.0
## The sunken sports field (floor at FIELD_Y), banks along its south and east edges.
const PIT := Rect2(-100.0, -90.0, 160.0, 40.0)
const FOUNTAIN := Vector3(0.0, 0.0, 55.0)
const FOUNTAIN_HOLE: float = 7.5  ## half size of the square hole the fountain's own deck fills
const TERRACE_Y: float = 2.0
const BALCONY_Y: float = 4.5
const GYM_Y: float = 6.0
const ANNEX_Y: float = 3.0
const SPAWN_POS := Vector3(0.0, 0.1, 76.0)

# palette
const C_PAVER := Color("86807b")
const C_CONC := Color("8f8a84")
const C_CONC_LIGHT := Color("aaa398")
const C_ASPHALT := Color("4b4a52")
const C_GRASS := Color("557a37")
const C_FIELD := Color("4b7d30")
const C_TRACK := Color("b4553e")
const C_STEP := Color("b8b1a6")
const C_LEDGE := Color("8f8a84")
const C_CAP := Color("d9d2c6")
const C_BRICK := Color("9c4a36")
const C_BRICK_WING := Color("a85a3e")
const C_TRIM := Color("efe6d2")
const C_BLUE := Color("2f5f9e")  ## school colours: navy and gold
const C_GOLD := Color("f2b632")
const C_WOOD := Color("b77a45")
const C_METAL := Color("c9d3dd")
const C_DARK := Color("3b3f4c")
const C_SOIL := Color("6b4a32")

var geo_front: SchoolGeo
var geo_main: SchoolGeo
var geo_court: SchoolGeo
var geo_field: SchoolGeo
var geo_gym: SchoolGeo
var geo_out: SchoolGeo
var kit: LevelKit
var dress: SchoolDress


func _init() -> void:
	spawn = Transform3D(Basis.IDENTITY, SPAWN_POS)  # facing -Z: the fountain and the school
	bounds = BOUNDS
	kill_y = Level.DEFAULT_KILL_Y
	gaps_path = DIR + "gaps.json"
	goals_path = DIR + "goals.json"
	preview_view = [Vector3(-34.0, 14.0, 92.0), Vector3(6.0, 2.0, 30.0)]


func _ready() -> void:
	setup_environment()
	_tune_mood()
	kit = LevelKit.open("school")
	geo_front = SchoolGeo.new(self, "Front")
	geo_main = SchoolGeo.new(self, "Main")
	geo_court = SchoolGeo.new(self, "Court")
	geo_field = SchoolGeo.new(self, "Field")
	geo_gym = SchoolGeo.new(self, "Gym")
	geo_out = SchoolGeo.new(self, "Outside")
	dress = SchoolDress.new(self, kit)
	_ground()
	_front_plaza()
	_fountain()
	_terrace()
	_main_building()
	_courtyard()
	_balcony()
	_field()
	_gym()
	_lot()
	_perimeter()
	for g: SchoolGeo in [geo_front, geo_main, geo_court, geo_field, geo_gym, geo_out]:
		g.commit()
	dress.finish()
	add_child(SchoolBackdrop.build())
	add_boundary()
	_drop_ins()
	_collectibles()


## The school_dusk preset, tuned for this campus: a little more ambient so the shaded east faces keep their colour,
## and a warmer, lighter haze so the town and hills fade into the sunset.
func _tune_mood() -> void:
	var env: Environment = world_environment.environment
	env.ambient_light_energy = 0.32
	env.fog_density = 0.0012
	sun.light_energy = 1.0
	# two shadow splits over 90 m: every caster is drawn once per split, and four splits doubled the frame's draws
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0


# --- ground -------------------------------------------------------------------------------------------------

## Collision: 4 m thick slabs at y = 0 everywhere except the field pit and the fountain hole, plus the pit floor. Looks:
## flat surface quads per region (pavers, concrete, asphalt, lawns, road), so nothing is coplanar with anything.
func _ground() -> void:
	var outer := Rect2(-150.0, -150.0, 300.0, 300.0)
	var hole := Rect2(FOUNTAIN.x - FOUNTAIN_HOLE, FOUNTAIN.z - FOUNTAIN_HOLE, FOUNTAIN_HOLE * 2.0, FOUNTAIN_HOLE * 2.0)
	for r: Rect2 in SchoolLevel.subtract(outer, [PIT, hole]):
		geo_out.solid(Vector3(r.position.x, -4.0, r.position.y), Vector3(r.size.x, 4.0, r.size.y))
	geo_field.solid(Vector3(PIT.position.x, FIELD_Y - 1.0, PIT.position.y), Vector3(PIT.size.x, 1.0, PIT.size.y))
	# surfaces at y = 0, each region minus the holes
	var paver: String = SchoolGeo.surf("pavers", C_PAVER, 1.0)
	var conc: String = SchoolGeo.surf("concrete", C_CONC)
	var asph: String = SchoolGeo.surf("asphalt", C_ASPHALT)
	var lawn: String = SchoolGeo.surf("grass", C_GRASS)
	var regions: Array = [
		[Rect2(-16.0, 31.0, 32.0, 54.0), paver, geo_front],  # front plaza: the paver promenade from the gate to the steps
		[Rect2(-100.0, 31.0, 84.0, 54.0), SchoolGeo.surf("concrete", C_CONC_LIGHT, 0.8), geo_front],  # and its concrete wings
		[Rect2(16.0, 31.0, 24.0, 54.0), SchoolGeo.surf("concrete", C_CONC_LIGHT, 0.8), geo_front],
		[Rect2(-100.0, -50.0, 140.0, 81.0), conc, geo_court],  # buildings + courtyard
		[Rect2(40.0, -50.0, 60.0, 135.0), asph, geo_gym],  # parking lot
		[Rect2(60.0, -90.0, 40.0, 40.0), conc, geo_gym],  # gym block
	]
	for reg: Array in regions:
		for r: Rect2 in SchoolLevel.subtract(reg[0] as Rect2, [PIT, hole]):
			(reg[2] as SchoolGeo).flat(r, 0.0, str(reg[1]), 0.0)
	# outside the fence: sidewalk, road, verge and lawns on all four sides (SchoolDress draws the road markings)
	var walk: String = SchoolGeo.surf("concrete", C_CONC_LIGHT, 0.5)
	var bands: Array = [[0.0, 3.5, walk], [3.5, 18.5, asph], [18.5, 22.0, walk], [22.0, 60.0, lawn]]
	var b: Rect2 = BOUNDS
	for band: Array in bands:
		var d0: float = float(band[0])
		var d1: float = float(band[1])
		var k: String = str(band[2])
		# south and north strips run the full width; east and west fill between them
		geo_out.flat(Rect2(b.position.x - d1, b.end.y + d0, b.size.x + d1 * 2.0, d1 - d0), 0.0, k, 0.0)
		geo_out.flat(Rect2(b.position.x - d1, b.position.y - d1, b.size.x + d1 * 2.0, d1 - d0), 0.0, k, 0.0)
		geo_out.flat(Rect2(b.end.x + d0, b.position.y - d0, d1 - d0, b.size.y + d0 * 2.0), 0.0, k, 0.0)
		geo_out.flat(Rect2(b.position.x - d1, b.position.y - d0, d1 - d0, b.size.y + d0 * 2.0), 0.0, k, 0.0)
	# (no add_backdrop plane: it would lie over the sunken field and the fountain basin; SchoolBackdrop's terrain
	# runs out from under these bands instead)
	# the pit: field floor and the north and west retaining walls
	geo_field.flat(PIT, FIELD_Y, SchoolGeo.surf("grass", C_FIELD, 1.4), 0.0)
	var wall: String = SchoolGeo.surf("concrete", Color("a8a29a"), 0.7)
	geo_field.decal(Vector3(PIT.position.x, FIELD_Y, PIT.position.y), Vector3(PIT.end.x, FIELD_Y, PIT.position.y),
			Vector3(PIT.end.x, 0.0, PIT.position.y), Vector3(PIT.position.x, 0.0, PIT.position.y), wall, Vector3.BACK)
	geo_field.decal(Vector3(PIT.position.x, FIELD_Y, PIT.position.y), Vector3(PIT.position.x, FIELD_Y, PIT.end.y),
			Vector3(PIT.position.x, 0.0, PIT.end.y), Vector3(PIT.position.x, 0.0, PIT.position.y), wall, Vector3.RIGHT)


## `r` minus every rect in `holes`, as a list of non-overlapping rects (slabs cut along the holes' x edges).
static func subtract(r: Rect2, holes: Array) -> Array[Rect2]:
	var xs: Array[float] = [r.position.x, r.end.x]
	for h: Rect2 in holes:
		for x: float in [h.position.x, h.end.x]:
			if x > r.position.x and x < r.end.x:
				xs.append(x)
	xs.sort()
	var out: Array[Rect2] = []
	for i: int in xs.size() - 1:
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		if x1 - x0 < 0.001:
			continue
		var cuts: Array[Vector2] = []
		for h: Rect2 in holes:
			if h.position.x <= x0 + 0.001 and h.end.x >= x1 - 0.001:
				cuts.append(Vector2(maxf(h.position.y, r.position.y), minf(h.end.y, r.end.y)))
		cuts.sort_custom(func(a: Vector2, c: Vector2) -> bool: return a.x < c.x)
		var z: float = r.position.y
		for c: Vector2 in cuts:
			if c.y <= c.x:
				continue
			if c.x > z + 0.001:
				out.append(Rect2(x0, z, x1 - x0, c.x - z))
			z = maxf(z, c.y)
		if r.end.y > z + 0.001:
			out.append(Rect2(x0, z, x1 - x0, r.end.y - z))
	return out


# --- front plaza --------------------------------------------------------------------------------------------

func _front_plaza() -> void:
	var g: SchoolGeo = geo_front
	var cap: String = SchoolGeo.toon(C_CAP)
	var body: String = SchoolGeo.toon(C_LEDGE)
	# SENIOR STEPS: three tiers of seat walls stepping up to the west, then a lawn deck (x -72 .. -59)
	var z0: float = 38.0
	var z1: float = 66.0
	var tiers: Array = [[-56.0, -53.0, 0.45], [-59.0, -56.0, 0.9]]
	for t: Array in tiers:
		g.box(Vector3(float(t[0]), 0.0, z0), Vector3(float(t[1]) - float(t[0]), float(t[2]) - 0.06, z1 - z0), body)
		g.box(Vector3(float(t[0]) - 0.02, float(t[2]) - 0.06, z0 - 0.02), Vector3(float(t[1]) - float(t[0]) + 0.04, 0.06, z1 - z0 + 0.04), cap)
		SchoolParts.grind(self, PackedVector3Array([Vector3(float(t[1]) + 0.02, float(t[2]), z0), Vector3(float(t[1]) + 0.02, float(t[2]), z1)]), "ledge")
	g.box(Vector3(-72.0, 0.0, z0), Vector3(13.0, 1.29, z1 - z0), body)
	g.box(Vector3(-59.02, 1.29, z0 - 0.02), Vector3(0.5, 0.06, z1 - z0 + 0.04), cap)
	SchoolParts.grind(self, PackedVector3Array([Vector3(-58.98, 1.35, z0), Vector3(-58.98, 1.35, z1)]), "ledge")
	g.flat(Rect2(-71.5, z0 + 0.5, 12.4, z1 - z0 - 1.0), 1.29, SchoolGeo.surf("grass", C_GRASS), 0.01)
	# the lawn deck's lip (cap band) on its other three sides
	g.vbox(Vector3(-72.0, 1.29, z0 - 0.02), Vector3(13.0, 0.07, 0.5), cap)
	g.vbox(Vector3(-72.0, 1.29, z1 - 0.48), Vector3(13.0, 0.07, 0.5), cap)
	SchoolParts.zone_box(self, "senior_low", Vector3(-56.5, 0.5, z0), Vector3(4.0, 1.8, z1 - z0))
	SchoolParts.zone_box(self, "senior_top", Vector3(-60.0, 1.0, z0), Vector3(3.8, 2.0, z1 - z0))
	dress.tree(Vector3(-66.0, 1.29, 44.0), 1.25)
	dress.tree(Vector3(-66.0, 1.29, 60.0), 1.1)
	# the promenade ledges: two long granite seat walls either side of the paver walk, from the gate toward the fountain
	for x: float in [-11.0, 11.0]:
		SchoolParts.ledge(g, Vector3(x, 0.0, 67.0), Vector3(x, 0.0, 79.0), 0.7, 0.5, SchoolGeo.toon(Color("8d8780")), SchoolGeo.toon(Color("cfc8bd")))
	# benches round the fountain
	var wood: String = SchoolGeo.toon(C_WOOD)
	var dark: String = SchoolGeo.toon(C_DARK)
	for a: float in [0.6, 2.5, 3.8, 5.6]:
		var c: Vector3 = FOUNTAIN + Vector3(cos(a), 0.0, sin(a)) * 11.0
		var t := Vector3(-sin(a), 0.0, cos(a))
		SchoolParts.bench(g, c - t * 1.3, c + t * 1.3, wood, dark)
	# flagpole on a round planter
	var flag := Vector3(-22.0, 0.0, 44.0)
	g.lathe(flag, PackedVector2Array([Vector2(2.4, -0.2), Vector2(2.4, 0.5), Vector2(2.1, 0.5), Vector2(2.1, 0.38), Vector2(0.0, 0.38)]), 24, cap, true)
	g.lathe(flag + Vector3(0.0, 0.001, 0.0), PackedVector2Array([Vector2(2.1, 0.38), Vector2(0.0, 0.38)]), 24, SchoolGeo.toon(C_SOIL), false)
	SchoolParts.ring_wall(g, flag, 2.1, 2.4, 0.5, cap, 24)
	kit.place(self, "flagpole", flag + Vector3(0.0, 0.38, 0.0), deg_to_rad(20.0))
	# two raised lawns flanking the promenade (0.45 kerbs to grind all round), shade trees on them
	var kerb: String = SchoolGeo.toon(Color("b4ab9e"))
	var lawn: String = SchoolGeo.surf("grass", C_GRASS, 0.7)
	for r: Rect2 in [Rect2(-50.0, 52.0, 27.0, 25.0), Rect2(21.0, 52.0, 17.0, 25.0)]:
		SchoolParts.planter_box(g, r, 0.0, 0.45, kerb, lawn)
	for t: Vector3 in [Vector3(-44.0, 0.33, 58.0), Vector3(-31.0, 0.33, 61.0), Vector3(-41.0, 0.33, 71.5), Vector3(-28.5, 0.33, 72.0),
			Vector3(26.0, 0.33, 58.5), Vector3(33.0, 0.33, 66.0), Vector3(26.5, 0.33, 73.0)]:
		dress.tree(t, 1.25 + 0.1 * float(int(t.x) % 3))
	dress.shrubs(Rect2(-49.0, 53.0, 25.0, 3.0), 0.33, 7)
	dress.shrubs(Rect2(22.0, 53.0, 15.0, 3.0), 0.33, 5)
	_court(Rect2(-97.0, 47.0, 17.0, 30.0))
	# the marquee sign by the south fence
	_marquee(Vector3(-24.0, 0.0, 80.5))
	# bike racks by the terrace
	var racks: Array[Transform3D] = []
	for i: int in 5:
		racks.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-30.0 - float(i % 2) * 0.0, 0.0, 36.0 + float(i) * 2.6)))
	dress.kit_row("bike_rack", racks, geo_front)
	# trash cans
	dress.kit_bin(Vector3(-12.0, 0.0, 37.0))
	dress.kit_bin(Vector3(14.0, 0.0, 37.0))


## A basketball court in the plaza's west wing: a painted court floor (key, centre circle, lines), two hoops on posts.
func _court(r: Rect2) -> void:
	var g: SchoolGeo = geo_front
	g.flat(r, 0.0, SchoolGeo.surf("court", Color("3f6f8f"), 1.0), 0.02)
	var inner := r.grow(-1.0)
	g.flat(Rect2(inner.position.x + 3.0, inner.position.y + 5.8, inner.size.x - 6.0, inner.size.y - 11.6), 0.0, SchoolGeo.surf("court", Color("2f5f9e"), 1.0), 0.03)
	var line: String = SchoolGeo.glow(Color("e9e4da"))
	var y: float = 0.045
	var c: Vector3 = Vector3(r.get_center().x, y, r.get_center().y)
	for zz: float in [inner.position.y, inner.end.y]:
		g.strip(Vector3(inner.position.x, y, zz), Vector3(inner.end.x, y, zz), 0.08, line, 0.0)
	for xx: float in [inner.position.x, inner.end.x]:
		g.strip(Vector3(xx, y, inner.position.y), Vector3(xx, y, inner.end.y), 0.08, line, 0.0)
	g.strip(Vector3(inner.position.x, y, c.z), Vector3(inner.end.x, y, c.z), 0.08, line, 0.0)
	g.lathe(c + Vector3(0.0, 0.003, 0.0), PackedVector2Array([Vector2(1.9, 0.0), Vector2(1.8, 0.0)]), 24, line, false)
	var post: String = SchoolGeo.toon(Color("3a3e4a"))
	var board: String = SchoolGeo.toon(Color("f1ece2"))
	var rim: String = SchoolGeo.toon(Color("e5642b"))
	for s: float in [-1.0, 1.0]:
		var base := Vector3(c.x, 0.0, c.z + s * (r.size.y * 0.5 + 0.2))
		g.cyl(base, base + Vector3(0.0, 3.3, 0.0), 0.09, post, 6, true)
		g.obox(Transform3D(Basis.IDENTITY, base + Vector3(0.0, 3.3, -s * 0.85)), Vector3(0.12, 0.12, 1.7), post, false)
		g.obox(Transform3D(Basis.IDENTITY, base + Vector3(0.0, 3.35, -s * 1.7)), Vector3(1.8, 1.1, 0.06), board, false)
		g.lathe(base + Vector3(0.0, 3.05, -s * 2.1), PackedVector2Array([Vector2(0.24, 0.0), Vector2(0.24, 0.03), Vector2(0.2, 0.03), Vector2(0.2, 0.0), Vector2(0.24, 0.0)]), 12, rim, false)
	# a low bench ledge along the court's east side
	SchoolParts.ledge(g, Vector3(r.end.x + 1.5, 0.0, r.position.y + 4.0), Vector3(r.end.x + 1.5, 0.0, r.end.y - 4.0), 0.6, 0.45, SchoolGeo.toon(C_LEDGE), SchoolGeo.toon(C_CAP))


## The school's monument sign: a stone base (a grindable ledge) and a lit message board on two posts.
func _marquee(p: Vector3) -> void:
	var g: SchoolGeo = geo_front
	var stone: String = SchoolGeo.toon(Color("8e8378"))
	var cap: String = SchoolGeo.toon(C_CAP)
	g.box(p + Vector3(-4.5, 0.0, -0.6), Vector3(9.0, 0.56, 1.2), stone)
	g.box(p + Vector3(-4.55, 0.56, -0.65), Vector3(9.1, 0.08, 1.3), cap)
	for s: float in [-1.0, 1.0]:
		SchoolParts.grind(self, PackedVector3Array([p + Vector3(-4.5, 0.64, s * 0.66), p + Vector3(4.5, 0.64, s * 0.66)]), "ledge")
	for x: float in [-3.6, 3.6]:
		g.box(p + Vector3(x - 0.25, 0.64, -0.25), Vector3(0.5, 2.2, 0.5), stone)
	g.box(p + Vector3(-3.9, 1.6, -0.3), Vector3(7.8, 1.9, 0.6), SchoolGeo.toon(C_BLUE))
	g.vbox(p + Vector3(-3.7, 1.75, 0.3), Vector3(7.4, 1.6, 0.02), SchoolGeo.glow(Color("101a33")))
	dress.label(p + Vector3(0.0, 3.05, 0.33), "SUNSET VALLEY HIGH", 64, C_GOLD)
	dress.label(p + Vector3(0.0, 2.45, 0.34), "HOMECOMING FRI 7PM", 48, Color("ffb347"), Vector3.BACK, true)
	dress.label(p + Vector3(0.0, 2.0, 0.34), "GO COUGARS!", 48, Color("ff9a3c"), Vector3.BACK, true)
	dress.label(p + Vector3(0.0, 3.05, -0.33), "SUNSET VALLEY HIGH", 64, C_GOLD, Vector3.FORWARD)


## The drained fountain: a square paver deck round a raised rim (grind it), a basin falling to a flat floor 1 m down
## (ride it like a mini bowl, RampLip on the rim), and a tiered pedestal in the middle (hop it).
func _fountain() -> void:
	var g: SchoolGeo = geo_front
	var c: Vector3 = FOUNTAIN
	var h: float = FOUNTAIN_HOLE
	var rim_r: float = 7.0
	var rim_in: float = 6.3
	var rim_h: float = 0.45
	var floor_y: float = -1.0
	var segs: int = 48
	# deck: from the hole's square edge in to the rim circle, at y = 0 (trimesh)
	var deck: String = SchoolGeo.surf("pavers", C_PAVER, 1.0)
	for i: int in segs:
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0: Vector3 = c + Vector3(cos(a0), 0.0, sin(a0)) * rim_r
		var p1: Vector3 = c + Vector3(cos(a1), 0.0, sin(a1)) * rim_r
		var q0: Vector3 = c + SchoolLevel._square_point(a0, h)
		var q1: Vector3 = c + SchoolLevel._square_point(a1, h)
		g.tri(p0, p1, q1, Vector3.UP, true, deck)
		g.tri(p0, q1, q0, Vector3.UP, true, deck)
		# the square's corners
		for k: int in 4:
			var ca: float = PI * 0.25 + PI * 0.5 * float(k)
			if ca > a0 and ca <= a1:
				var corner: Vector3 = c + Vector3(cos(ca), 0.0, sin(ca)) * h * sqrt(2.0)
				g.tri(p1, q1, corner, Vector3.UP, true, deck)
	# rim (outer wall, top) and basin wall + floor, one profile
	var stone: String = SchoolGeo.toon(Color("cfc6b6"))
	g.lathe(c, PackedVector2Array([Vector2(rim_r, -0.3), Vector2(rim_r, rim_h), Vector2(rim_in, rim_h)]), segs, stone, true)
	var basin := PackedVector2Array()
	# ellipse wall: from the rim's inner top edge (73 degrees steep) to the floor at r = 4.6
	var a_ax: float = 1.83
	var b_ax: float = 2.27
	var cy: float = floor_y + b_ax
	var steps: int = 8
	for i: int in steps + 1:
		var t: float = 1.2 * (1.0 - float(i) / float(steps))
		basin.append(Vector2(4.6 + a_ax * sin(t), cy - b_ax * cos(t)))
	basin.append(Vector2(1.0, floor_y))
	g.lathe(c, basin, segs, SchoolGeo.toon(Color("6a9db0")), true)
	g.lathe(c, PackedVector2Array([Vector2(1.0, floor_y), Vector2(0.0, floor_y)]), segs, SchoolGeo.toon(Color("7aa7b2")), true)
	# a darker water-stain band just under the rim and a tile line
	g.lathe(c + Vector3(0.0, 0.0, 0.0), PackedVector2Array([Vector2(rim_in - 0.004, rim_h - 0.02), Vector2(rim_in - 0.03, rim_h - 0.3)]), segs, SchoolGeo.toon(Color("e7e0d2")), false)
	# pedestal: a column, a wide dish, a spire
	var ped: String = SchoolGeo.toon(Color("d6cdbd"))
	# low enough to fly over from the deck: the dish tops out at -0.55, its finial at -0.37
	g.lathe(c, PackedVector2Array([Vector2(0.6, floor_y - 0.1), Vector2(0.6, -0.78), Vector2(1.4, -0.66), Vector2(1.4, -0.55),
			Vector2(1.2, -0.55), Vector2(0.3, -0.6), Vector2(0.18, -0.45), Vector2(0.24, -0.41), Vector2(0.0, -0.37)]), 24, ped, true)
	SchoolParts.grind(self, SchoolLevel._circle(c + Vector3(0.0, -0.55, 0.0), 1.4, 24), "ledge")
	# grind lines: the rim's outer and inner top edges; the inner one is the lip for the ramp snap
	SchoolParts.grind(self, SchoolLevel._circle(c + Vector3(0.0, rim_h, 0.0), rim_r, segs), "ledge")
	var lip_pts: PackedVector3Array = SchoolLevel._circle(c + Vector3(0.0, rim_h, 0.0), rim_in, segs)
	SchoolParts.grind(self, lip_pts, "coping")
	add_child(RampLip.ring(lip_pts, c))
	# gap zones: four boxes over the rim (W, E, N, S), from just over the rim up
	var zs: float = 3.0
	SchoolParts.zone_box(self, "fount_w", c + Vector3(-rim_r - 0.6, 0.0, -zs * 0.5 - 1.0), Vector3(1.8, 2.6, zs + 2.0))
	SchoolParts.zone_box(self, "fount_e", c + Vector3(rim_r - 1.2, 0.0, -zs * 0.5 - 1.0), Vector3(1.8, 2.6, zs + 2.0))
	SchoolParts.zone_box(self, "fount_n", c + Vector3(-zs * 0.5 - 1.0, 0.0, -rim_r - 0.6), Vector3(zs + 2.0, 2.6, 1.8))
	SchoolParts.zone_box(self, "fount_s", c + Vector3(-zs * 0.5 - 1.0, 0.0, rim_r - 1.2), Vector3(zs + 2.0, 2.6, 1.8))
	SchoolParts.zone_box(self, "fount_mid", c + Vector3(-2.0, -0.05, -2.0), Vector3(4.0, 3.0, 4.0))
	dress.fountain_life(c, floor_y)


## Where the ray at angle `a` from the centre leaves the square of half size `h` (y = 0).
static func _square_point(a: float, h: float) -> Vector3:
	var d := Vector2(cos(a), sin(a))
	var k: float = h / maxf(absf(d.x), absf(d.y))
	return Vector3(d.x * k, 0.0, d.y * k)


static func _circle(c: Vector3, r: float, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i: int in n + 1:
		var a: float = TAU * float(i) / float(n)
		out.append(c + Vector3(cos(a) * r, 0.0, sin(a) * r))
	return out


# --- terrace and front steps --------------------------------------------------------------------------------

## The raised front terrace (y 2.0, x -26 .. 30, z 22 .. 31): the big front steps in the middle (8 stairs, rails at
## x -6, 0 and 6, hubbas both sides), a bank on the west, and a ledge drop on the east.
func _terrace() -> void:
	var g: SchoolGeo = geo_front
	var top: String = SchoolGeo.surf("concrete", C_CONC_LIGHT, 0.6)
	var side: String = SchoolGeo.toon(Color("b0a89c"))
	g.box(Vector3(-26.0, -0.5, 22.0), Vector3(56.0, TERRACE_Y + 0.5, 9.0), side, true, false)
	g.flat(Rect2(-26.0, 22.0, 56.0, 9.0), TERRACE_Y, top, 0.0)
	# the front steps
	var step: String = SchoolGeo.toon(C_STEP)
	var hub: String = SchoolGeo.toon(Color("a89f92"))
	SchoolParts.stairs(g, Transform3D(Basis.IDENTITY, Vector3(-12.0, 0.0, 31.0)), 24.0, 8, 0.25, 0.45, [6.0, 12.0, 18.0], 3, step, hub, "front")
	# the west bank down to the plaza
	SchoolParts.bank(g, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 31.0)), -26.0, -12.6, 5.0, TERRACE_Y, SchoolGeo.toon(Color("b7afa3")))
	# the east wall: a ledge on its lip, planter boxes on the terrace behind it
	var cap: String = SchoolGeo.toon(C_CAP)
	g.box(Vector3(12.6, TERRACE_Y, 30.7), Vector3(17.4, 0.06, 0.32), cap, false)
	SchoolParts.grind(self, PackedVector3Array([Vector3(12.6, TERRACE_Y, 31.0), Vector3(30.0, TERRACE_Y, 31.0)]), "ledge")
	SchoolParts.zone_box(self, "terrace_e", Vector3(12.6, TERRACE_Y + 0.1, 28.0), Vector3(17.4, 2.0, 3.0))
	SchoolParts.zone_box(self, "terrace_drop", Vector3(12.0, -0.2, 32.0), Vector3(18.0, 1.6, 6.0))
	SchoolParts.planter_box(g, Rect2(18.0, 23.0, 8.0, 2.4), TERRACE_Y, 0.55, SchoolGeo.toon(Color("a39a8e")), SchoolGeo.toon(C_SOIL))
	dress.shrubs(Rect2(18.4, 23.4, 7.2, 1.6), TERRACE_Y + 0.43, 5)
	SchoolParts.planter_box(g, Rect2(-24.0, 23.0, 8.0, 2.4), TERRACE_Y, 0.55, SchoolGeo.toon(Color("a39a8e")), SchoolGeo.toon(C_SOIL))
	dress.shrubs(Rect2(-23.6, 23.4, 7.2, 1.6), TERRACE_Y + 0.43, 5)
	# benches on the terrace
	SchoolParts.bench(g, Vector3(-9.0, TERRACE_Y, 26.0), Vector3(-5.0, TERRACE_Y, 26.0), SchoolGeo.toon(C_WOOD), SchoolGeo.toon(C_DARK))
	SchoolParts.bench(g, Vector3(5.0, TERRACE_Y, 26.0), Vector3(9.0, TERRACE_Y, 26.0), SchoolGeo.toon(C_WOOD), SchoolGeo.toon(C_DARK))


# --- main building ------------------------------------------------------------------------------------------

## Two storeys (roof 9.6) along z 0 .. 22, x -66 .. 40, with the breezeway (floor 2.0, ceiling 5.0) through x 18 .. 30.
## The west wing runs north along x -96 .. -66 to a 5 m deck above the field's west bank.
func _main_building() -> void:
	var g: SchoolGeo = geo_main
	var brick: String = SchoolGeo.facade("main", {"wall": C_BRICK, "trim": C_TRIM, "top_y": 9.6, "floor_h": 4.5, "bay": 3.6, "lit_ratio": 0.4, "seed": 2.0})
	var wing: String = SchoolGeo.facade("wing", {"wall": C_BRICK_WING, "trim": C_TRIM, "top_y": 9.6, "floor_h": 4.5, "bay": 3.2, "lit_ratio": 0.3, "seed": 5.0})
	g.box(Vector3(-66.0, 0.0, 0.0), Vector3(84.0, 9.6, 22.0), brick)
	g.box(Vector3(30.0, 0.0, 0.0), Vector3(10.0, 9.6, 22.0), brick)
	g.box(Vector3(18.0, 5.0, 0.0), Vector3(12.0, 4.6, 22.0), brick)
	# breezeway floor (its top is the terrace height), walls tiled, a lit ceiling
	g.box(Vector3(18.0, -0.5, 0.0), Vector3(12.0, TERRACE_Y + 0.5, 22.0), SchoolGeo.toon(Color("b0a89c")), true, false)
	g.flat(Rect2(18.0, 0.0, 12.0, 22.0), TERRACE_Y, SchoolGeo.surf("court", Color("c9c2b4"), 0.8), 0.0)
	for i: int in 4:
		g.vbox(Vector3(22.5, 4.96, 2.5 + float(i) * 5.0), Vector3(3.0, 0.04, 1.2), SchoolGeo.glow(Color("fff1cc")))
	for x: float in [18.0, 30.0]:
		g.vbox(Vector3(x - 0.03, TERRACE_Y, 0.4), Vector3(0.06, 1.3, 21.2), SchoolGeo.toon(Color("3c6aa8")))
	dress.light_pool(Vector3(24.0, TERRACE_Y + 0.02, 11.0), 7.0, 0.35)
	# west wing
	g.box(Vector3(-96.0, 0.0, -45.0), Vector3(30.0, 9.6, 67.0), wing)
	# roof parapets and rooftop units (visual, out of reach)
	var cap: String = SchoolGeo.toon(Color("e9e0cc"))
	for r: Rect2 in [Rect2(-66.0, 0.0, 106.0, 22.0), Rect2(-96.0, -45.0, 30.0, 67.0)]:
		g.vbox(Vector3(r.position.x - 0.1, 9.6, r.position.y - 0.1), Vector3(r.size.x + 0.2, 0.6, 0.4), cap)
		g.vbox(Vector3(r.position.x - 0.1, 9.6, r.end.y - 0.3), Vector3(r.size.x + 0.2, 0.6, 0.4), cap)
		g.vbox(Vector3(r.position.x - 0.1, 9.6, r.position.y), Vector3(0.4, 0.6, r.size.y), cap)
		g.vbox(Vector3(r.end.x - 0.3, 9.6, r.position.y), Vector3(0.4, 0.6, r.size.y), cap)
	var unit: String = SchoolGeo.toon(Color("9aa1aa"))
	for p: Vector3 in [Vector3(-40.0, 9.6, 6.0), Vector3(-10.0, 9.6, 12.0), Vector3(-82.0, 9.6, -20.0), Vector3(-86.0, 9.6, 6.0)]:
		g.vbox(p, Vector3(4.0, 1.6, 3.0), unit)
	dress.steam(Vector3(-84.0, 11.2, 7.5), 0.6)
	# the front entrance: doors, a canopy and the name
	var door: String = SchoolGeo.toon(C_BLUE)
	var frame: String = SchoolGeo.toon(C_TRIM)
	g.vbox(Vector3(-5.0, TERRACE_Y, 21.9), Vector3(10.0, 3.4, 0.2), frame)
	for i: int in 4:
		g.vbox(Vector3(-4.6 + float(i) * 2.35, TERRACE_Y, 22.0), Vector3(2.1, 3.0, 0.12), door)
		g.vbox(Vector3(-4.2 + float(i) * 2.35, TERRACE_Y + 1.4, 22.1), Vector3(1.3, 1.3, 0.04), SchoolGeo.glow(Color("ffe1a8")))
	g.box(Vector3(-7.0, 5.4, 22.0), Vector3(14.0, 0.35, 3.2), frame)
	g.vbox(Vector3(-7.0, 5.75, 24.9), Vector3(14.0, 0.5, 0.3), SchoolGeo.toon(C_BLUE))
	dress.light_pool(Vector3(0.0, TERRACE_Y + 0.02, 24.0), 5.0, 0.45)
	dress.label(Vector3(0.0, 8.1, 22.12), "SUNSET VALLEY HIGH SCHOOL", 120, C_TRIM, Vector3.BACK, false, 0.012)
	dress.label(Vector3(0.0, 6.2, 25.22), "EST. 1962", 64, C_GOLD, Vector3.BACK, false, 0.01)
	# classroom doors along the courtyard face (ground floor) and the balcony (upper floor)
	for x: float in [-58.0, -28.0, -20.0]:
		g.vbox(Vector3(x, 0.0, -0.12), Vector3(1.4, 2.6, 0.14), door)
	for x: float in [-58.0, -50.0, -26.0, -20.0]:
		g.vbox(Vector3(x, BALCONY_Y, -0.12), Vector3(1.4, 2.6, 0.14), door)
	# west wing: cafeteria doors toward the plaza, a sign
	g.vbox(Vector3(-86.0, 0.0, 21.9), Vector3(8.0, 3.2, 0.2), frame)
	for i: int in 3:
		g.vbox(Vector3(-85.6 + float(i) * 2.5, 0.0, 22.0), Vector3(2.2, 2.9, 0.12), SchoolGeo.glow(Color("ffd89a")))
	dress.label(Vector3(-82.0, 4.2, 22.12), "CAFETERIA", 96, C_TRIM, Vector3.BACK, false, 0.012)
	dress.light_pool(Vector3(-82.0, 0.02, 25.0), 5.0, 0.4)


# --- courtyard ----------------------------------------------------------------------------------------------

func _courtyard() -> void:
	var g: SchoolGeo = geo_court
	var cap: String = SchoolGeo.toon(C_CAP)
	var body: String = SchoolGeo.toon(C_LEDGE)
	var wood: String = SchoolGeo.toon(C_WOOD)
	var dark: String = SchoolGeo.toon(C_DARK)
	# the breezeway's back stairs, down to the courtyard (descending -Z)
	var back := Transform3D(Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1)), Vector3(30.0, 0.0, 0.0))
	SchoolParts.stairs(g, back, 12.0, 8, 0.25, 0.45, [4.0, 8.0], 3, SchoolGeo.toon(C_STEP), SchoolGeo.toon(Color("a89f92")), "back")
	# LUNCH SHELTER: a flat roof on four posts over the cafeteria tables, its roof reachable from the ADA ramp
	var sh := Rect2(-58.0, -28.0, 14.0, 14.0)
	var roof_y: float = 3.2
	g.box(Vector3(sh.position.x, roof_y - 0.25, sh.position.y), Vector3(sh.size.x, 0.25, sh.size.y), SchoolGeo.toon(Color("e8e2d4")))
	g.vbox(Vector3(sh.position.x - 0.05, roof_y - 0.32, sh.position.y - 0.05), Vector3(sh.size.x + 0.1, 0.1, sh.size.y + 0.1), SchoolGeo.toon(C_BLUE))
	for px: float in [sh.position.x + 0.6, sh.end.x - 0.6]:
		for pz: float in [sh.position.y + 0.6, sh.end.y - 0.6]:
			g.box(Vector3(px - 0.15, 0.0, pz - 0.15), Vector3(0.3, roof_y - 0.25, 0.3), SchoolGeo.toon(C_BLUE))
	var rp := PackedVector3Array([Vector3(sh.position.x, roof_y, sh.position.y), Vector3(sh.end.x, roof_y, sh.position.y),
			Vector3(sh.end.x, roof_y, sh.end.y), Vector3(sh.position.x, roof_y, sh.end.y), Vector3(sh.position.x, roof_y, sh.position.y)])
	SchoolParts.grind(self, rp, "ledge")
	SchoolParts.zone_box(self, "lunch_roof", Vector3(sh.position.x + 0.3, roof_y + 0.05, sh.position.y), Vector3(sh.size.x - 0.6, 2.0, sh.size.y))
	# the launch: a short steep kicker north of the shelter, ridden south, its lip 4 m short of the roof
	var kick_x0: float = sh.get_center().x - 2.5
	g.wedge(Transform3D.IDENTITY, kick_x0, kick_x0 + 5.0, -35.0, -32.0, 0.0, 1.2, SchoolGeo.toon(Color("e79a2e")))
	g.vbox(Vector3(kick_x0, 1.17, -32.12), Vector3(5.0, 0.04, 0.12), SchoolGeo.toon(Color("fff0cf")))
	SchoolParts.zone_box(self, "lunch_kick", Vector3(kick_x0 - 0.5, 0.9, -33.5), Vector3(6.0, 2.5, 2.0))
	var tables: Array[Transform3D] = []
	for tx: float in [-54.0, -48.0]:
		for tz: float in [-24.5, -17.5]:
			tables.append(Transform3D(Basis.IDENTITY, Vector3(tx, 0.0, tz)))
	dress.kit_row("cafeteria_table", tables, g)
	for t: Transform3D in tables:
		for s: float in [-1.0, 1.0]:
			SchoolParts.grind(self, PackedVector3Array([t * Vector3(-1.2, 0.76, s * 0.37), t * Vector3(1.2, 0.76, s * 0.37)]), "ledge")
	dress.light_pool(Vector3(-51.0, 0.03, -21.0), 6.0, 0.35)
	# PLANTERS: three kit planter ledges in a row along z -30 (Planter Hop), a round tree planter in the middle
	var planters: Array[Transform3D] = []
	for px: float in [-34.0, -24.0, -14.0]:
		planters.append(Transform3D(Basis.IDENTITY, Vector3(px, 0.0, -30.0)))
	dress.kit_row("planter_ledge", planters, g)
	var ids: Array[String] = ["planter_a", "planter_b", "planter_c"]
	for i: int in planters.size():
		var t: Transform3D = planters[i]
		for s: float in [-1.0, 1.0]:
			SchoolParts.grind(self, PackedVector3Array([t * Vector3(-2.0, 0.5, s * 0.6), t * Vector3(2.0, 0.5, s * 0.6)]), "ledge")
		SchoolParts.zone_box(self, ids[i], t.origin + Vector3(-2.0, 0.5, -1.0), Vector3(4.0, 2.0, 2.0))
	var tc := Vector3(2.0, 0.0, -26.0)
	g.lathe(tc, PackedVector2Array([Vector2(3.6, -0.2), Vector2(3.6, 0.55), Vector2(3.25, 0.55), Vector2(3.25, 0.42), Vector2(0.0, 0.42)]), 32, cap, true)
	g.lathe(tc + Vector3(0.0, 0.002, 0.0), PackedVector2Array([Vector2(3.25, 0.42), Vector2(0.0, 0.42)]), 32, SchoolGeo.toon(C_SOIL), false)
	SchoolParts.grind(self, SchoolLevel._circle(tc + Vector3(0.0, 0.55, 0.0), 3.6, 32), "ledge")
	dress.tree(tc + Vector3(0.0, 0.42, 0.0), 1.8)
	# the long manual pad (Manual Madness) and two ledges east of it
	var pad := Rect2(12.0, -24.0, 16.0, 3.0)
	g.box(Vector3(pad.position.x, 0.0, pad.position.y), Vector3(pad.size.x, 0.35, pad.size.y), SchoolGeo.toon(Color("9c958c")))
	g.vbox(Vector3(pad.position.x - 0.02, 0.33, pad.position.y - 0.02), Vector3(pad.size.x + 0.04, 0.04, pad.size.y + 0.04), cap)
	for zz: float in [pad.position.y, pad.end.y]:
		SchoolParts.grind(self, PackedVector3Array([Vector3(pad.position.x, 0.35, zz), Vector3(pad.end.x, 0.35, zz)]), "ledge")
	SchoolParts.zone_box(self, "pad_a", Vector3(pad.position.x - 0.5, 0.0, pad.position.y), Vector3(5.0, 2.2, pad.size.y))
	SchoolParts.zone_box(self, "pad_b", Vector3(pad.end.x - 2.0, 0.35, pad.position.y), Vector3(2.0, 1.8, pad.size.y))
	SchoolParts.ledge(g, Vector3(34.0, 0.0, -44.0), Vector3(34.0, 0.0, -30.0), 0.7, 0.5, body, cap)
	SchoolParts.ledge(g, Vector3(37.5, 0.0, -44.0), Vector3(37.5, 0.0, -30.0), 0.7, 0.75, SchoolGeo.toon(C_BLUE), cap)
	# benches along the north edge of the courtyard and by the planters
	for x: float in [-44.0, -8.0, 20.0]:
		SchoolParts.bench(g, Vector3(x - 1.3, 0.0, -44.0), Vector3(x + 1.3, 0.0, -44.0), wood, dark)
	SchoolParts.bench(g, Vector3(-30.0, 0.0, -36.0), Vector3(-27.4, 0.0, -36.0), wood, dark)
	SchoolParts.bench(g, Vector3(-20.0, 0.0, -36.0), Vector3(-17.4, 0.0, -36.0), wood, dark)
	# trees in grates
	for p: Vector3 in [Vector3(-40.0, 0.0, -40.0), Vector3(-6.0, 0.0, -40.0), Vector3(16.0, 0.0, -40.0), Vector3(30.0, 0.0, -12.0), Vector3(-2.0, 0.0, -12.0)]:
		g.vflat_ring(p, 1.2, SchoolGeo.toon(Color("4b4f5a")))
		dress.tree(p, 1.3)
	dress.kit_bin(Vector3(-40.0, 0.0, -8.0))
	dress.kit_bin(Vector3(8.0, 0.0, -42.0))
	# the plaza east of the courtyard, by the gym entrance: bike racks
	var racks: Array[Transform3D] = []
	for i: int in 6:
		racks.append(Transform3D(Basis.IDENTITY, Vector3(44.0 + float(i) * 2.6, 0.0, -40.0)))
	dress.kit_row("bike_rack", racks, g)
	for t: Transform3D in racks:
		SchoolParts.grind(self, PackedVector3Array([t * Vector3(-1.0, 0.86, 0.0), t * Vector3(1.0, 0.86, 0.0)]), "rail")


# --- balcony, ADA ramp, double set ----------------------------------------------------------------------------

## The second-floor balcony along the courtyard face (y 4.5, x -62 .. -16, z -3.5 .. 0) with its guard rail; the ADA
## ramp up to it along the west wing (x -66 .. -62, z -40 .. -3.5, 7 degrees); and the double set down from its east
## end (9 + 9 stairs with a landing, one long kinked handrail).
func _balcony() -> void:
	var g: SchoolGeo = geo_court
	var slab: String = SchoolGeo.toon(Color("cbc3b5"))
	var conc_top: String = SchoolGeo.surf("concrete", C_CONC_LIGHT, 0.5)
	var blue: String = SchoolGeo.toon(C_BLUE)
	var metal: String = SchoolGeo.toon(C_METAL)
	# balcony slab and the landing block at the top of the ramp
	g.box(Vector3(-62.0, BALCONY_Y - 0.3, -3.5), Vector3(46.0, 0.3, 3.5), slab, true, false)
	g.box(Vector3(-66.0, 0.0, -3.5), Vector3(4.0, BALCONY_Y, 3.5), slab, true, false)
	g.flat(Rect2(-66.0, -3.5, 50.0, 3.5), BALCONY_Y, conc_top, 0.0)
	g.vbox(Vector3(-62.0, BALCONY_Y - 0.36, -3.56), Vector3(46.0, 0.12, 0.08), blue)
	# columns under the balcony
	for i: int in 6:
		var x: float = -58.0 + float(i) * 7.6
		g.box(Vector3(x - 0.18, 0.0, -3.4), Vector3(0.36, BALCONY_Y - 0.3, 0.36), SchoolGeo.toon(C_TRIM))
	# guard rail: a thin solid panel under a round top rail (grind it), posts every 2 m
	var rail_y: float = BALCONY_Y + 0.95
	var rz: float = -3.42
	# (it stops short of the double set, whose kinked handrail takes over as the guard)
	g.box(Vector3(-62.0, BALCONY_Y, rz - 0.03), Vector3(43.2, 0.92, 0.06), SchoolGeo.toon(Color("7e8a99")))
	g.cyl(Vector3(-62.0, rail_y, rz), Vector3(-18.8, rail_y, rz), 0.045, metal, 8)
	SchoolParts.grind(self, PackedVector3Array([Vector3(-62.0, rail_y, rz), Vector3(-18.8, rail_y, rz)]), "rail")
	SchoolParts.zone_box(self, "balc_w", Vector3(-62.0, rail_y - 1.0, -4.5), Vector3(3.0, 2.4, 2.0))
	SchoolParts.zone_box(self, "balc_e", Vector3(-37.0, rail_y - 1.0, -4.5), Vector3(3.0, 2.4, 2.0))
	# lockers along the balcony wall and under it
	var lk: Array[Transform3D] = []
	for i: int in 8:
		lk.append(Transform3D(Basis.IDENTITY, Vector3(-44.0 + float(i) * 1.82, BALCONY_Y, -0.26)))
		lk.append(Transform3D(Basis.IDENTITY, Vector3(-50.0 + float(i) * 1.82, 0.0, -0.26)))
	dress.kit_row("lockers", lk, g)
	# ADA ramp: z -40 (y 0) up to z -3.5 (y 4.5), with a guard rail (and its grind line) on the open east side
	var z_lo: float = -40.0
	var z_hi: float = -3.5
	g.prism(Transform3D.IDENTITY, PackedVector2Array([Vector2(z_lo, 0.0), Vector2(z_hi, 0.0), Vector2(z_hi, BALCONY_Y)]), -66.0, -62.0, slab)
	g.decal(Vector3(-66.0, 0.006, z_lo), Vector3(-62.0, 0.006, z_lo), Vector3(-62.0, BALCONY_Y + 0.006, z_hi), Vector3(-66.0, BALCONY_Y + 0.006, z_hi), conc_top)
	var ry: float = 0.92
	var a := Vector3(-62.12, ry + 0.25, z_lo + 2.0)
	var b := Vector3(-62.12, BALCONY_Y + ry, z_hi)
	a.y = BALCONY_Y * (a.z - z_lo) / (z_hi - z_lo) + ry
	SchoolParts.handrail(g, PackedVector3Array([a, b]), [a.y - ry, BALCONY_Y], Transform3D.IDENTITY, 0.0)
	# a thin solid guard under the rail, so the ramp's open side is a wall up to the rail
	var gprof := PackedVector2Array([Vector2(z_lo + 2.0, a.y - 0.1), Vector2(z_hi, BALCONY_Y + ry - 0.1), Vector2(z_hi, BALCONY_Y), Vector2(z_lo + 2.0, a.y - ry)])
	g.prism(Transform3D.IDENTITY, gprof, -62.15, -62.09, SchoolGeo.toon(Color("7e8a99")))
	SchoolParts.zone_box(self, "ada_top", Vector3(-63.5, BALCONY_Y - 0.5, -9.0), Vector3(3.0, 2.5, 5.0))
	SchoolParts.zone_box(self, "ada_bottom", Vector3(-63.5, -0.2, z_lo + 1.0), Vector3(3.0, 2.5, 6.0))
	SchoolParts.zone_box(self, "ada_side", Vector3(-66.0, 1.6, -28.0), Vector3(4.6, 3.4, 14.0))
	# DOUBLE SET: flight 1 (balcony -> landing at 2.25), landing, flight 2 (-> ground), descending +X along the wall
	var basis := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0))
	var mid_y: float = BALCONY_Y * 0.5
	var step: String = SchoolGeo.toon(C_STEP)
	var hub: String = SchoolGeo.toon(Color("a89f92"))
	SchoolParts.stairs(g, Transform3D(basis, Vector3(-16.0, mid_y, 0.0)), 3.5, 9, 0.25, 0.45, [], 0, step, hub, "dbl1")
	g.box(Vector3(-16.0, -0.2, -3.5), Vector3(4.05, mid_y + 0.2, 3.5), slab)
	g.box(Vector3(-11.95, -0.2, -3.5), Vector3(3.0, mid_y + 0.2, 3.5), slab, true, false)
	g.flat(Rect2(-11.95, -3.5, 3.0, 3.5), mid_y, conc_top, 0.0)
	SchoolParts.stairs(g, Transform3D(basis, Vector3(-8.95, 0.0, 0.0)), 3.5, 9, 0.25, 0.45, [], 0, step, hub, "dbl2")
	# the kinked handrail down both flights, on the open north side
	var zr: float = -3.15
	var rh: float = SchoolParts.RAIL_H
	var s: float = 0.25 / 0.45
	var pts := PackedVector3Array([
		Vector3(-18.4, BALCONY_Y + rh, zr), Vector3(-16.0, BALCONY_Y + rh, zr), Vector3(-11.95, mid_y + rh, zr),
		Vector3(-8.95, mid_y + rh, zr), Vector3(-4.6, rh - 0.35 * s, zr)])
	SchoolParts.handrail(g, pts, [BALCONY_Y, BALCONY_Y, mid_y, mid_y, 0.0], Transform3D.IDENTITY, 0.0)
	SchoolParts.zone_box(self, "dbl_rail_top", Vector3(-18.6, BALCONY_Y + 0.2, -4.6), Vector3(3.0, 2.2, 2.4))
	SchoolParts.zone_box(self, "dbl_rail_end", Vector3(-6.4, -0.2, -4.6), Vector3(3.6, 2.4, 2.4))
	# Leap of Faith: off the balcony's east end, over both flights
	SchoolParts.zone_box(self, "leap_top", Vector3(-19.5, BALCONY_Y + 0.1, -3.5), Vector3(3.5, 2.6, 3.5))
	SchoolParts.zone_box(self, "leap_land", Vector3(-6.5, -0.3, -9.0), Vector3(16.0, 2.0, 9.0))


# --- sports field -------------------------------------------------------------------------------------------

## The sunken field (y -3): south edge, west to east: a bank (x -100 .. -60), the bleachers (-60 .. -30), the field
## stairs (-30 .. -18) and a long bank (-18 .. 60); the east bank (x 54 .. 60) rises to the gym; the north wall is a
## 3 m retaining wall to wallride.
func _field() -> void:
	var g: SchoolGeo = geo_field
	var bank_key: String = SchoolGeo.surf("concrete", Color("aaa298"), 0.6)
	var down := Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1))  # local z -> world -z (toward the field)
	var depth: float = 6.0
	var h: float = -FIELD_Y
	SchoolParts.bank(g, Transform3D(down, Vector3(0.0, FIELD_Y, -50.0)), 60.0, 100.0, depth, h, bank_key)
	SchoolParts.bank(g, Transform3D(down, Vector3(0.0, FIELD_Y, -50.0)), -60.0, 18.0, depth, h, bank_key)
	# east bank: lip at x 60, slope falls toward -x
	var west := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
	SchoolParts.bank(g, Transform3D(west, Vector3(60.0, FIELD_Y, 0.0)), -90.0, -50.0, depth, h, bank_key)
	_bleachers(Rect2(-60.0, -56.0, 30.0, 6.0))
	# field stairs: 12 x (0.25, 0.5), x -29.4 .. -18.6, hubbas to -30 and -18
	SchoolParts.stairs(g, Transform3D(down, Vector3(-18.6, FIELD_Y, -50.0)), 10.8, 12, 0.25, 0.5, [3.6, 7.2], 3,
			SchoolGeo.toon(C_STEP), SchoolGeo.toon(Color("a89f92")), "fstairs")
	# the campus-edge zones: over every lip, and the landing strip on the field below
	SchoolParts.zone_box(self, "edge_bleach", Vector3(-60.0, 0.1, -51.5), Vector3(30.0, 2.4, 2.5))
	SchoolParts.zone_box(self, "edge_bank", Vector3(-18.0, 0.1, -51.5), Vector3(72.0, 2.4, 2.5))
	SchoolParts.zone_box(self, "edge_bank_w", Vector3(-100.0, 0.1, -51.5), Vector3(40.0, 2.4, 2.5))
	SchoolParts.zone_box(self, "field_land", Vector3(-100.0, FIELD_Y - 0.3, -66.0), Vector3(154.0, 1.9, 10.0))
	# north wall: the wallride zones, a mural band and the painted name
	SchoolParts.zone_box(self, "wall_a", Vector3(-80.0, FIELD_Y + 0.4, -90.0), Vector3(14.0, 2.6, 1.6))
	SchoolParts.zone_box(self, "wall_b", Vector3(-64.0, FIELD_Y + 0.4, -90.0), Vector3(14.0, 2.6, 1.6))
	g.vbox(Vector3(-100.0, -0.25, -90.02), Vector3(160.0, 0.25, 0.04), SchoolGeo.toon(C_BLUE))
	g.vbox(Vector3(-100.0, -0.42, -90.02), Vector3(160.0, 0.12, 0.04), SchoolGeo.toon(C_GOLD))
	dress.label(Vector3(-24.0, -1.6, -89.95), "C O U G A R S", 220, C_GOLD, Vector3.BACK, false, 0.02)
	dress.label(Vector3(-72.0, -1.6, -89.95), "HOME OF THE", 120, C_TRIM, Vector3.BACK, false, 0.016)
	g.box(Vector3(-100.0, 0.0, -90.5), Vector3(160.0, 0.35, 0.5), SchoolGeo.toon(C_CAP), false)
	# the track (decals), the field's yard lines, the goalposts
	_track()
	for x: float in [-72.0, 26.0]:
		_goalpost(Vector3(x, FIELD_Y, -73.0))
	# field lights, scoreboard (outside the wall), sprinklers and the crows
	dress.field_life()


## Bleachers built into the bank: six rows of 0.5 x 1.0 (a hidden smooth slope to ride, like a stair flight), seat
## planks on each row, two aisle handrails and a press box on the deck behind.
func _bleachers(r: Rect2) -> void:
	var g: SchoolGeo = geo_field
	var down := Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1))
	var xf := Transform3D(down, Vector3(r.end.x, FIELD_Y, -50.0))
	var w: float = r.size.x
	var rows: int = 6
	var rise: float = 0.5
	var run: float = 1.0
	var hh: float = float(rows) * rise
	var conc: String = SchoolGeo.toon(Color("b3ab9f"))
	var plank: String = SchoolGeo.toon(Color("c9d1da"))
	for i: int in rows:
		var top: float = hh - float(i + 1) * rise
		if top > 0.001:
			g.obox(xf * Transform3D(Basis.IDENTITY, Vector3(w * 0.5, top * 0.5, (float(i) + 0.5) * run)), Vector3(w, top, run), conc, false)
		# seat plank near the back of each row (low enough to stay under the ride line)
		var seat_y: float = top + 0.06
		if i < rows - 1:
			g.obox(xf * Transform3D(Basis.IDENTITY, Vector3(w * 0.5, seat_y + 0.0, (float(i) + 0.72) * run)), Vector3(w - 0.2, 0.05, 0.3), plank, false)
	g.prism(xf, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, hh), Vector2(float(rows) * run, 0.0)]), 0.0, w, conc, true, false)
	for ax: float in [10.0, 20.0]:
		var p0: Vector3 = xf * Vector3(ax, hh + SchoolParts.RAIL_H, -0.8)
		var p1: Vector3 = xf * Vector3(ax, hh + SchoolParts.RAIL_H, 0.0)
		var p2: Vector3 = xf * Vector3(ax, SchoolParts.RAIL_H - 0.3, float(rows) * run + 0.3)
		SchoolParts.handrail(g, PackedVector3Array([p0, p1, p2]), [0.0, 0.0, FIELD_Y], Transform3D.IDENTITY, 0.0)
	# press box behind the top row (a small building: its roof is out of reach, its walls are solid)
	var pb := Rect2(r.position.x + 9.0, -47.5, 12.0, 4.0)
	var wall: String = SchoolGeo.facade("press", {"wall": Color("e3dccd"), "trim": C_BLUE, "brick": 0.0, "top_y": 3.4, "floor_h": 4.0, "bay": 2.4, "win_w": 1.8, "win_h": 1.0, "sill": 1.4, "floors": 1.0, "lit_ratio": 0.6, "seed": 9.0})
	g.box(Vector3(pb.position.x, 0.0, pb.position.y), Vector3(pb.size.x, 3.4, pb.size.y), wall)
	g.vbox(Vector3(pb.position.x - 0.3, 3.4, pb.position.y - 0.3), Vector3(pb.size.x + 0.6, 0.3, pb.size.y + 0.6), SchoolGeo.toon(C_BLUE))
	dress.label(Vector3(pb.get_center().x, 2.9, pb.position.y - 0.02), "COUGARS", 90, C_BLUE, Vector3.FORWARD, false, 0.012)


func _track() -> void:
	var g: SchoolGeo = geo_field
	var track: String = SchoolGeo.surf("court", C_TRACK, 1.0)
	var line: String = SchoolGeo.glow(Color("e9e4da"))
	var cz: float = -73.0
	var x0: float = -70.0
	var x1: float = 24.0
	var r_in: float = 10.0
	var r_out: float = 14.5
	var y: float = FIELD_Y + 0.015
	var segs: int = 20
	# straights
	g.flat(Rect2(x0, cz - r_out, x1 - x0, r_out - r_in), FIELD_Y, track, 0.015)
	g.flat(Rect2(x0, cz + r_in, x1 - x0, r_out - r_in), FIELD_Y, track, 0.015)
	# bends
	for side: float in [-1.0, 1.0]:
		var c := Vector3(x1 if side > 0.0 else x0, y, cz)
		for i: int in segs:
			var a0: float = -PI * 0.5 + PI * float(i) / float(segs)
			var a1: float = -PI * 0.5 + PI * float(i + 1) / float(segs)
			var d0 := Vector3(cos(a0) * side, 0.0, sin(a0))
			var d1 := Vector3(cos(a1) * side, 0.0, sin(a1))
			g.decal(c + d0 * r_in, c + d1 * r_in, c + d1 * r_out, c + d0 * r_out, track)
	# lane lines on the straights
	for k: int in 4:
		var rr: float = r_in + 1.1 * float(k + 1) - 0.05
		for s: float in [-1.0, 1.0]:
			g.strip(Vector3(x0, y + 0.002, cz + rr * s), Vector3(x1, y + 0.002, cz + rr * s), 0.06, line, 0.0)
	# the football field's yard lines and sidelines
	var fl := Rect2(x0 + 2.0, cz - r_in + 1.0, x1 - x0 - 4.0, r_in * 2.0 - 2.0)
	for k: int in 11:
		var x: float = fl.position.x + fl.size.x * float(k) / 10.0
		g.strip(Vector3(x, FIELD_Y, fl.position.y), Vector3(x, FIELD_Y, fl.end.y), 0.12, line, 0.02)
	g.strip(Vector3(fl.position.x, FIELD_Y, fl.position.y), Vector3(fl.end.x, FIELD_Y, fl.position.y), 0.12, line, 0.02)
	g.strip(Vector3(fl.position.x, FIELD_Y, fl.end.y), Vector3(fl.end.x, FIELD_Y, fl.end.y), 0.12, line, 0.02)
	# the midfield logo: a gold disc
	g.lathe(Vector3((x0 + x1) * 0.5, FIELD_Y + 0.02, cz), PackedVector2Array([Vector2(3.2, 0.0), Vector2(0.0, 0.0)]), 24, SchoolGeo.toon(C_GOLD), false)
	g.lathe(Vector3((x0 + x1) * 0.5, FIELD_Y + 0.025, cz), PackedVector2Array([Vector2(2.4, 0.0), Vector2(0.0, 0.0)]), 24, SchoolGeo.toon(C_BLUE), false)


## A football goalpost: a padded post, a crossbar 3 m up and two uprights (the post collides).
func _goalpost(p: Vector3) -> void:
	var g: SchoolGeo = geo_field
	var y: String = SchoolGeo.toon(Color("f2c230"))
	g.cyl(p, p + Vector3(0.0, 3.0, 0.0), 0.12, y, 8, true)
	g.cyl(p + Vector3(0.0, 0.0, 0.0), p + Vector3(0.0, 1.8, 0.0), 0.2, SchoolGeo.toon(C_BLUE), 8)
	g.cyl(p + Vector3(0.0, 3.0, -2.8), p + Vector3(0.0, 3.0, 2.8), 0.08, y, 8)
	for s: float in [-2.8, 2.8]:
		g.cyl(p + Vector3(0.0, 3.0, s), p + Vector3(0.0, 9.0, s), 0.06, y, 6)


# --- gym ----------------------------------------------------------------------------------------------------

## The gym (x 62 .. 96, z -84 .. -50, roof 6.0) and its annex (z -50 .. -30, roof 3.0). The loading-dock ramp (x 90 ..
## 96, z -30 .. -6) climbs to the annex roof, a bank there (z -44 .. -50) climbs on to the gym roof. The gym roof's
## west parapet is open between z -74 and -60: the Gym Roof Drop.
func _gym() -> void:
	var g: SchoolGeo = geo_gym
	var wall: String = SchoolGeo.facade("gym", {"wall": Color("c9a57a"), "trim": C_BLUE, "brick": 0.0, "course": 0.6, "top_y": 6.0,
			"floor_h": 6.0, "floors": 1.0, "sill": 4.0, "win_h": 1.2, "win_w": 3.0, "bay": 4.0, "lit_ratio": 0.55, "seed": 4.0})
	var annex: String = SchoolGeo.facade("annex", {"wall": C_BRICK, "trim": C_TRIM, "top_y": 3.0, "floor_h": 3.0, "floors": 1.0,
			"sill": 1.4, "win_h": 0.8, "win_w": 1.6, "bay": 3.0, "lit_ratio": 0.3, "seed": 7.0})
	g.box(Vector3(62.0, 0.0, -84.0), Vector3(34.0, GYM_Y, 34.0), wall, true, false)
	g.box(Vector3(62.0, 0.0, -50.0), Vector3(34.0, ANNEX_Y, 20.0), annex, true, false)
	var roof: String = SchoolGeo.surf("concrete", Color("9a958e"), 0.8)
	g.flat(Rect2(62.0, -84.0, 34.0, 34.0), GYM_Y, roof, 0.0)
	g.flat(Rect2(62.0, -50.0, 34.0, 20.0), ANNEX_Y, roof, 0.0)
	# parapets (0.45, grind their inner top edges) with the openings
	var par: String = SchoolGeo.toon(Color("e6dcc7"))
	var ph: float = 0.45
	var t: float = 0.35
	# gym roof: west side open z -74 .. -60, south side open x 88 .. 96 (the bank), north side behind the quarter pipe
	_parapet(g, Vector3(62.0, GYM_Y, -84.0), Vector3(62.0, GYM_Y, -74.0), t, ph, par, 1)
	_parapet(g, Vector3(62.0, GYM_Y, -60.0), Vector3(62.0, GYM_Y, -50.0), t, ph, par, 1)
	_parapet(g, Vector3(96.0, GYM_Y, -84.0), Vector3(96.0, GYM_Y, -50.0), t, ph, par, -1)
	_parapet(g, Vector3(62.0, GYM_Y, -50.0), Vector3(88.0, GYM_Y, -50.0), t, ph, par, -1, true)
	_parapet(g, Vector3(62.0, GYM_Y, -84.0), Vector3(72.0, GYM_Y, -84.0), t, ph, par, 1, true)
	_parapet(g, Vector3(82.0, GYM_Y, -84.0), Vector3(96.0, GYM_Y, -84.0), t, ph, par, 1, true)
	# annex roof: south side open x 90 .. 96 (the ramp)
	_parapet(g, Vector3(62.0, ANNEX_Y, -50.0), Vector3(62.0, ANNEX_Y, -30.0), t, ph, par, 1)
	_parapet(g, Vector3(96.0, ANNEX_Y, -50.0), Vector3(96.0, ANNEX_Y, -30.0), t, ph, par, -1)
	_parapet(g, Vector3(62.0, ANNEX_Y, -30.0), Vector3(89.2, ANNEX_Y, -30.0), t, ph, par, -1, true)
	# the annex-to-gym bank and the loading-dock ramp
	SchoolParts.bank(g, Transform3D(Basis.IDENTITY, Vector3(0.0, ANNEX_Y, -50.0)), 88.0, 96.0, 6.0, GYM_Y - ANNEX_Y, SchoolGeo.toon(Color("b9b0a2")))
	var ramp_z0: float = -30.0
	var ramp_z1: float = -6.0
	g.prism(Transform3D.IDENTITY, PackedVector2Array([Vector2(ramp_z1, 0.0), Vector2(ramp_z0, 0.0), Vector2(ramp_z0, ANNEX_Y)]), 90.0, 96.0, SchoolGeo.toon(Color("a7a097")))
	g.decal(Vector3(90.0, 0.006, ramp_z1), Vector3(96.0, 0.006, ramp_z1), Vector3(96.0, ANNEX_Y + 0.006, ramp_z0), Vector3(90.0, ANNEX_Y + 0.006, ramp_z0), SchoolGeo.surf("concrete", Color("b3ab9f"), 0.5))
	var ry: float = 0.9
	var ra := Vector3(90.12, ry + ANNEX_Y * 2.0 / 24.0, ramp_z1 - 2.0)
	var rb := Vector3(90.12, ANNEX_Y + ry, ramp_z0)
	var r0 := Vector3(90.12, ANNEX_Y + ry, ramp_z0 - 2.5)  # a flat run on the roof first, so it can be caught from the roof
	SchoolParts.handrail(g, PackedVector3Array([r0, rb, ra]), [ANNEX_Y, ANNEX_Y, ANNEX_Y * 2.0 / 24.0], Transform3D.IDENTITY, 0.0)
	SchoolParts.zone_box(self, "dock_rail_top", Vector3(88.5, ANNEX_Y - 0.4, -32.0), Vector3(3.2, 2.6, 4.0))
	SchoolParts.zone_box(self, "dock_rail_end", Vector3(88.5, -0.2, ramp_z1 - 4.0), Vector3(3.2, 2.4, 4.0))
	SchoolParts.zone_box(self, "annex_up", Vector3(88.0, ANNEX_Y + 0.05, -44.0), Vector3(8.0, 1.8, 12.0))
	SchoolParts.zone_box(self, "gym_roof", Vector3(62.0, GYM_Y + 0.05, -58.0), Vector3(34.0, 2.0, 8.0))
	SchoolParts.zone_box(self, "gym_edge", Vector3(61.0, GYM_Y + 0.05, -74.0), Vector3(3.0, 3.0, 14.0))
	SchoolParts.zone_box(self, "gym_land", Vector3(20.0, FIELD_Y - 0.3, -86.0), Vector3(40.5, 2.2, 30.0))
	# the loading dock along the annex's south face (a 1.2 m ledge with a steel edge)
	g.box(Vector3(62.0, 0.0, -30.0), Vector3(26.0, 1.2, 3.0), SchoolGeo.toon(Color("a49c90")), true, false)
	g.flat(Rect2(62.0, -30.0, 26.0, 3.0), 1.2, SchoolGeo.surf("concrete", Color("b7afa3"), 0.5), 0.0)
	g.cyl(Vector3(62.0, 1.18, -26.98), Vector3(88.0, 1.18, -26.98), 0.04, SchoolGeo.toon(C_DARK), 6)
	SchoolParts.grind(self, PackedVector3Array([Vector3(62.0, 1.2, -27.0), Vector3(88.0, 1.2, -27.0)]), "ledge")
	for x: float in [68.0, 76.0, 84.0]:
		g.vbox(Vector3(x - 1.6, 1.2, -30.1), Vector3(3.2, 1.6, 0.12), SchoolGeo.toon(Color("6c7480")))
	# the gym's quarter pipe on the roof's north edge, AC units, skylights, the vent
	put(QuarterPipe.build(10.0, 2.2, 2.4, 1.0), Vector3(72.0, GYM_Y, -84.0), 0.0, "RoofQuarter")
	var ac: String = SchoolGeo.toon(Color("a9b0b8"))
	for p: Vector3 in [Vector3(87.5, GYM_Y, -83.0), Vector3(91.8, GYM_Y, -83.0), Vector3(87.5, GYM_Y, -76.5)]:
		g.box(p, Vector3(3.6, 1.7, 2.6), ac)
		g.vbox(p + Vector3(0.4, 1.7, 0.4), Vector3(2.8, 0.08, 1.8), SchoolGeo.toon(C_DARK))
	for i: int in 3:
		var sx: float = 67.0 + float(i) * 6.5
		g.box(Vector3(sx, GYM_Y, -61.0), Vector3(3.4, 0.45, 8.0), SchoolGeo.toon(Color("dcd6cc")))
		g.vbox(Vector3(sx + 0.25, GYM_Y + 0.45, -60.75), Vector3(2.9, 0.03, 7.5), SchoolGeo.glow(Color("ffd28c")))
		for s: float in [0.0, 3.4]:
			SchoolParts.grind(self, PackedVector3Array([Vector3(sx + s, GYM_Y + 0.45, -61.0), Vector3(sx + s, GYM_Y + 0.45, -53.0)]), "ledge")
	dress.steam(Vector3(80.0, GYM_Y + 1.0, -56.0), 0.7)
	g.cyl(Vector3(80.0, GYM_Y, -56.0), Vector3(80.0, GYM_Y + 1.0, -56.0), 0.35, ac, 10, true)
	# facades on the gym's west face (the kit pieces, visual), the name, the entrance doors on the annex
	var wins: Array[Transform3D] = []
	for z: float in [-80.0, -72.0, -56.0]:
		wins.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(61.9, 0.0, z)))
	dress.kit_row("gym_facade_window", wins, g, false)
	kit.place(self, "gym_facade_door", Vector3(61.9, 0.0, -64.0), PI * 0.5, {"collide": false})
	dress.label(Vector3(61.5, 6.6, -67.0), "COUGAR GYM", 140, C_GOLD, Vector3.LEFT, false, 0.014)
	var door: String = SchoolGeo.toon(C_BLUE)
	for i: int in 2:
		g.vbox(Vector3(61.88, 0.0, -45.0 + float(i) * 2.3), Vector3(0.12, 2.6, 2.1), door)
	dress.light_pool(Vector3(60.0, 0.02, -43.8), 5.0, 0.4)


## A parapet wall from a to b (axis-aligned), thickness t inward (`inward` +1/-1 along the perpendicular axis) and
## height h, with a ledge grind line on its inner top edge.
func _parapet(g: SchoolGeo, a: Vector3, b: Vector3, t: float, h: float, key: String, inward: int, along_x: bool = false) -> void:
	var lo := Vector3(minf(a.x, b.x), a.y, minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), a.y, maxf(a.z, b.z))
	if along_x:
		var z0: float = lo.z if inward > 0 else lo.z - t
		g.box(Vector3(lo.x, a.y, z0 - (0.0 if inward > 0 else 0.0)), Vector3(hi.x - lo.x, h, t), key)
		var zi: float = z0 + t if inward > 0 else z0
		SchoolParts.grind(self, PackedVector3Array([Vector3(lo.x, a.y + h, zi), Vector3(hi.x, a.y + h, zi)]), "ledge")
	else:
		var x0: float = lo.x if inward > 0 else lo.x - t
		g.box(Vector3(x0, a.y, lo.z), Vector3(t, h, hi.z - lo.z), key)
		var xi: float = x0 + t if inward > 0 else x0
		SchoolParts.grind(self, PackedVector3Array([Vector3(xi, a.y + h, lo.z), Vector3(xi, a.y + h, hi.z)]), "ledge")


# --- parking lot ------------------------------------------------------------------------------------------

## The lot east of the main building (x 40 .. 100, z -27 .. 85): painted bays, two planted islands (curbs to grind),
## the school buses lined up, parked cars and the lamps.
func _lot() -> void:
	var g: SchoolGeo = geo_gym
	var paint: String = SchoolGeo.glow(Color("d9d4c8"))
	var yellow: String = SchoolGeo.glow(Color("e8c040"))
	# bays: two double rows, cars nose to nose across a centre line
	for row: Array in [[47.0, 52.0], [63.0, 68.0]]:
		for k: int in 13:
			var z: float = 38.0 + float(k) * 3.0
			for x: float in row:
				g.strip(Vector3(x - 2.6, 0.0, z), Vector3(x + 2.6, 0.0, z), 0.12, paint)
	# islands: raised curbs with grass and trees; their long edges are grind lines
	for ix: float in [57.0, 73.0]:
		var r := Rect2(ix - 1.5, 38.0, 3.0, 36.0)
		g.box(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, 0.35, r.size.y), SchoolGeo.toon(C_CAP))
		g.flat(r.grow(-0.25), 0.35, SchoolGeo.surf("grass", C_GRASS), 0.01)
		for xx: float in [r.position.x, r.end.x]:
			SchoolParts.grind(self, PackedVector3Array([Vector3(xx, 0.35, r.position.y), Vector3(xx, 0.35, r.end.y)]), "ledge")
		for k: int in 3:
			dress.tree(Vector3(ix, 0.35, r.position.y + 6.0 + float(k) * 12.0), 1.0)
		dress.lamp(Vector3(ix, 0.35, r.position.y + 12.0), 0.0, 9 + int(ix))
		dress.lamp(Vector3(ix, 0.35, r.end.y - 0.5), PI, 19 + int(ix))
	# bus loop: the yellow kerb line and the buses
	g.strip(Vector3(80.0, 0.0, -2.0), Vector3(80.0, 0.0, 30.0), 0.2, yellow)
	var buses: Array[Transform3D] = []
	for i: int in 4:
		buses.append(Transform3D(Basis(Vector3.UP, PI), Vector3(84.0 + float(i) * 3.6, 0.0, 14.0 + float(i % 2) * 1.2)))
	dress.kit_row("school_bus", buses, g)
	# parked cars
	dress.parked_cars([[Vector3(47.0, 0.0, 39.5), -0.5], [Vector3(52.0, 0.0, 45.5), 0.5], [Vector3(47.0, 0.0, 54.5), -0.5],
			[Vector3(52.0, 0.0, 63.5), 0.5], [Vector3(63.0, 0.0, 42.5), -0.5], [Vector3(68.0, 0.0, 48.5), 0.5],
			[Vector3(63.0, 0.0, 66.5), -0.5], [Vector3(68.0, 0.0, 72.5), 0.5], [Vector3(47.0, 0.0, 69.5), -0.5]])
	# the main building's east side: bike racks by the side door
	dress.light_pool(Vector3(42.0, 0.02, 11.0), 5.0, 0.35)
	g.vbox(Vector3(39.88, 0.0, 9.8), Vector3(0.14, 2.6, 2.4), SchoolGeo.toon(C_BLUE))


# --- perimeter --------------------------------------------------------------------------------------------

## The fence round the campus (chain link on posts, visual: the boundary walls stop the skater), the road outside with
## its markings, street lamps, the traffic and the people on the sidewalks.
func _perimeter() -> void:
	dress.fence_line(BOUNDS)
	dress.road_markings(BOUNDS)
	dress.traffic(BOUNDS)


# --- drop-ins and collectibles ------------------------------------------------------------------------------

func _drop_ins() -> void:
	add_drop_in("balcony", "Second Floor", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-58.0, BALCONY_Y + 0.1, -1.75)))
	add_drop_in("gym_roof", "Gym Roof", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(92.0, GYM_Y + 0.1, -67.0)))
	add_drop_in("terrace", "Front Steps", Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, TERRACE_Y + 0.1, 24.0)))
	add_drop_in("field", "Sports Field", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-40.0, FIELD_Y + 0.1, -73.0)))


func _collectibles() -> void:
	# S-K-A-T-E, each on a different line
	_pickup("S", "skate", Vector3(-3.0, 3.6, 32.8))  # over the front steps, in the ollie's arc
	_pickup("K", "skate", FOUNTAIN + Vector3(0.0, 0.8, 0.0))  # over the fountain's pedestal
	_pickup("A", "skate", Vector3(-62.1, 3.9, -20.0))  # along the ADA rail
	_pickup("T", "skate", Vector3(-51.0, 3.9, -21.0))  # on the lunch shelter roof
	_pickup("E", "skate", Vector3(-25.8, -0.1, -53.0))  # down the field stairs' rail
	# the Leap of Faith coin, in the air over the double set
	_pickup("L", "leap", Vector3(-10.5, 5.0, -1.75))
	# the secret tape, behind the AC units on the gym roof
	_pickup("tape", "tape", Vector3(93.5, GYM_Y + 0.8, -78.5))
	# five lost textbooks
	for p: Vector3 in [Vector3(24.0, 3.0, 10.0), Vector3(-45.0, -0.9, -53.0), Vector3(-70.0, -1.6, -88.8), Vector3(-24.0, 1.6, -30.0), Vector3(73.0, 1.6, 56.0)]:
		_pickup("book", "books", p)


func _pickup(item: String, group: String, pos: Vector3) -> void:
	var c := SchoolPickup.new()
	c.item = item
	c.group_id = group
	c.position = pos
	c.name = "%s_%s_%d" % [group, item, collectibles.size()]
	add_child(c)
	collectibles.append(c)
