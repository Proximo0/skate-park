class_name HillsSpots
extends RefCounted
## The Hills' riding spots that sit on the shaped ground: Pool Row's terrace (retaining wall ledge, yard fences, patio
## bits), the garages with their driveway kickers, Valley Park's skate spot and playground, and the secret garden (a
## hedged sunken back yard with its own little pool). Each builder adds its nodes to the level and its gap zones.

const CONCRETE := Color("c9c3b6")
const PARK_CONCRETE := Color("a4a29d")
const UMBRELLA := [Color("e8574a"), Color("f2c14e"), Color("4fa3c7")]
const PLAY_RED := Color("d9534a")
const PLAY_BLUE := Color("3f7cc0")
const PLAY_YELLOW := Color("f2c14e")


## Pool Row: the retaining wall under the strip behind Summit Court (its cap is a long ledge), the privacy fences
## between the three yards (hop them), and patio umbrellas off the riding line.
static func terrace(lvl: HillsLevel) -> void:
	var root := Node3D.new()
	root.name = "PoolRow"
	lvl.add_child(root)
	var t: Rect2 = HillsLevel.TERRACE
	var ty: float = lvl.terrace_y
	var strip_y: float = lvl.summit_y - 0.3
	var wall: StaticBody3D = HillsDress.retaining_wall(t.position.x - 6.0, t.end.x + 5.0, t.position.y - 1.0, 1.0, ty - 2.0, strip_y + 0.5)
	root.add_child(wall)
	for fx: float in HillsLevel.YARD_FENCES:
		root.add_child(HillsDress.fence(Vector3(fx, ty, t.position.y + 0.3), Vector3(fx, ty, t.end.y - 0.4)))
	# low picket runs on the downhill side of each yard (open in the middle: the way in from below)
	for i: int in HillsLevel.POOL_DECKS.size():
		var d: Rect2 = HillsLevel.POOL_DECKS[i]
		var ze: float = t.end.y - 0.3
		root.add_child(HillsDress.picket(Vector3(d.position.x - 2.0, ty, ze), Vector3(d.position.x + 2.5, ty, ze)))
		root.add_child(HillsDress.picket(Vector3(d.end.x - 2.5, ty, ze), Vector3(d.end.x + 2.0, ty, ze)))
		var u := HillsSpots._umbrella(UMBRELLA[i] as Color)
		u.position = Vector3(d.end.x - 0.9, ty, d.end.y - 0.9)
		root.add_child(u)
	# gap zones: each side of both yard fences (in the air over the deck), and the two ends of the wall's cap
	for fx: float in HillsLevel.YARD_FENCES:
		var tag: String = "ab" if fx < 10.0 else "bc"
		lvl.add_child(PieceKit.gap_zone("fence_%s_w" % tag, Vector3(fx - 3.4, ty + 0.5, t.position.y + 0.5), Vector3(2.8, 3.5, t.size.y - 1.0)))
		lvl.add_child(PieceKit.gap_zone("fence_%s_e" % tag, Vector3(fx + 0.6, ty + 0.5, t.position.y + 0.5), Vector3(2.8, 3.5, t.size.y - 1.0)))
	var wz: float = t.position.y - 1.0
	lvl.add_child(PieceKit.gap_zone("wall_w", Vector3(-14.0, strip_y + 0.2, wz - 0.6), Vector3(5.0, 2.0, 2.2)))
	lvl.add_child(PieceKit.gap_zone("wall_e", Vector3(18.0, strip_y + 0.2, wz - 0.6), Vector3(5.0, 2.0, 2.2)))


static func _umbrella(colour: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Umbrella"
	var pole := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.03
	pc.bottom_radius = 0.03
	pc.height = 2.3
	pc.radial_segments = 6
	pole.mesh = pc
	pole.material_override = Toon.material(Color("e8e2d6"), false)
	pole.position = Vector3(0.0, 1.15, 0.0)
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pole)
	var top := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 1.3
	cm.height = 0.45
	cm.radial_segments = 8
	cm.rings = 1
	top.mesh = cm
	top.material_override = Toon.material(colour, false)
	top.position = Vector3(0.0, 2.2, 0.0)
	root.add_child(top)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.15
	sh.height = 2.3
	cs.shape = sh
	cs.position = Vector3(0.0, 1.15, 0.0)
	body.add_child(cs)
	root.add_child(body)
	return root


## A garage at the head of `lot`'s driveway, and a kicker at the street end of the driveway pointing at the street
## (roll out of the garage, down the drive, and launch over the sidewalk into the cul-de-sac).
static func garage_lot(lvl: HillsLevel, kit: LevelKit, lot: Dictionary, index: int) -> void:
	var basis: Basis = lot["basis"]
	var c: Vector3 = lot["centre"]
	var gpos: Vector3 = c + basis * Vector3(float(lot["drive_x"]), 0.0, -1.5)
	gpos.y = c.y
	var g: StaticBody3D = HillsDress.garage(kit, Transform3D(basis, gpos), Color("e9dcc4") if index == 0 else Color("cfe0e6"))
	g.name = "Garage%d" % index
	lvl.add_child(g)
	if not bool((lot["opts"] as Dictionary).get("kicker", false)):
		return
	var a: Vector3 = lot["drive_a"]
	var b: Vector3 = lot["drive_b"]
	var to_street := Vector3(a.x - b.x, 0.0, a.z - b.z).normalized()
	var lip_xz: Vector3 = Vector3(a.x, 0.0, a.z) - to_street * 1.4
	var lip: Vector3 = lvl.terrain.at(lip_xz.x, lip_xz.z)
	var kb := Basis(Vector3.UP, atan2(-to_street.x, -to_street.z))
	var w: float = 2.4
	var k: Node3D = Kicker.build(w, 2.6, 0.85)
	k.name = "GarageKicker%d" % index
	k.transform = Transform3D(kb, lip - kb * Vector3(w * 0.5, 0.0, 0.0) - Vector3(0.0, 0.04, 0.0))
	lvl.add_child(k)
	# zones: in the air off the lip (over the drive's end and the sidewalk), and over the bulb past the curb
	var over_walk: Vector3 = Vector3(a.x, lip.y, a.z) - to_street * 0.2
	lvl.add_child(HillsSpots._zone_at("drive_lip_%d" % index, over_walk + Vector3(0.0, 1.0, 0.0), Vector3(3.0, 2.2, 3.0), kb))
	var land: Vector3 = Vector3(a.x, lip.y, a.z) + to_street * 4.5
	land.y = lvl.summit_y
	lvl.add_child(HillsSpots._zone_at("drive_land_%d" % index, land + Vector3(0.0, 1.6, 0.0), Vector3(5.0, 2.4, 5.0), kb))


## A gap zone centred on `c`, turned by `basis`.
static func _zone_at(zone_id: String, c: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> Area3D:
	var z: Area3D = PieceKit.gap_zone(zone_id, -size * 0.5, size)
	z.transform = Transform3D(basis, c)
	return z


## Valley Park: the concrete skate spot where the ditch spills out (the big quarter pipe catches the ditch bomb), a
## funbox, a pyramid, ledges, a manual pad and a flat rail; the playground, benches and lamps on the west side.
static func park(lvl: HillsLevel) -> void:
	var y: float = lvl.park_y
	var root := Node3D.new()
	root.name = "ValleyPark"
	lvl.add_child(root)
	# the slab (visual over the flat ground; the ground is the collision)
	var slab := MeshInstance3D.new()
	slab.name = "Slab"
	var pm := PlaneMesh.new()
	pm.size = Vector2(76.0, 27.0)
	slab.mesh = pm
	slab.material_override = WorldSurface.material("concrete", PARK_CONCRETE, 0.35)
	slab.position = Vector3(32.0, y + 0.03, 63.5)
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(slab)
	# the big quarter pipe on the south edge, facing up the ditch
	var qp: Node3D = QuarterPipe.build(16.0, 3.5, 3.6, 1.6)
	qp.name = "SpillwayQP"
	qp.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(68.0, y, 77.6))
	root.add_child(qp)
	lvl.add_child(PieceKit.gap_zone("park_qp", Vector3(52.5, y + 4.2, 71.8), Vector3(15.0, 9.0, 4.4)))
	# a mini quarter pipe across the west end, facing the big one
	var mini: Node3D = QuarterPipe.build(12.0, 2.2, 1.8, 1.2)
	mini.name = "MiniQP"
	mini.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-6.0, y, 70.0))
	root.add_child(mini)
	lvl.add_child(PieceKit.gap_zone("park_mini", Vector3(-6.0, y + 2.2, 58.5), Vector3(3.6, 5.0, 11.0)))
	# funbox along z, east of the middle
	var fb: Node3D = FunBox.build(4.0, 5.0, 3.0, 1.0, "park_box")
	fb.position = Vector3(30.0, y, 55.0)
	root.add_child(fb)
	# pyramid in the middle
	var pyr: Node3D = Transfers.pyramid(9.0, 3.0, 1.4, "park_pyr")
	pyr.position = Vector3(10.0, y, 56.0)
	root.add_child(pyr)
	# ledges along the north edge, a manual pad and a flat rail
	var l1: Node3D = StreetBits.ledge(10.0, 0.5, 0.8, Color("8a6fb0"), "park_ledge_a")
	l1.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-2.0, y, 52.6))
	root.add_child(l1)
	var l2: Node3D = StreetBits.ledge(10.0, 0.5, 0.8, Color("5f9e8f"), "park_ledge_b")
	l2.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(12.0, y, 52.6))
	root.add_child(l2)
	var pad: Node3D = StreetBits.manual_pad(7.0, 2.6, 0.3, "park_pad_a", "park_pad_b")
	pad.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(36.0, y, 71.5))
	root.add_child(pad)
	var fr: Node3D = StreetBits.flat_rail(8.0, 0.45, "park_rail_a", "park_rail_b")
	fr.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(4.0, y, 70.0))
	root.add_child(fr)
	# benches and lamps round the spot
	for e: Array in [[Vector3(-9.5, y, 61.0), PI * 0.5], [Vector3(-9.5, y, 67.0), PI * 0.5], [Vector3(46.0, y, 51.2), 0.0], [Vector3(20.0, y, 77.6), PI]]:
		var bn: Node3D = StreetBits.bench(2.4)
		bn.transform = Transform3D(Basis(Vector3.UP, float(e[1])), e[0] as Vector3)
		root.add_child(bn)
	for p: Vector3 in [Vector3(-7.5, y, 52.0), Vector3(-7.5, y, 76.0), Vector3(24.0, y, 50.0), Vector3(48.0, y, 77.5), Vector3(70.5, y, 52.0)]:
		var lm: Node3D = HillsDress.lamp(5.0)
		lm.position = p
		lm.rotation.y = PI * 0.5 if p.x < 0.0 else -PI * 0.5
		root.add_child(lm)
	HillsSpots._playground(root, y)


## Swings, a slide and a sandbox on the park's west lawn.
static func _playground(root: Node3D, y: float) -> void:
	var pg := StaticBody3D.new()
	pg.name = "Playground"
	root.add_child(pg)
	var x0: float = -24.0
	var z0: float = 56.0
	# swing frame: two A-frames and a top bar, three swings
	for sx: float in [0.0, 6.0]:
		for dz: float in [-0.9, 0.9]:
			var leg := HillsDress._box_mesh(Vector3(0.1, 2.6, 0.1), PLAY_RED, Vector3(x0 + sx, y + 1.25, z0 + dz * 0.5), "Leg")
			leg.rotation.x = dz * 0.3
			pg.add_child(leg)
		pg.add_child(HillsDress._box_shape(Vector3(0.35, 2.6, 1.6), Vector3(x0 + sx, y + 1.3, z0)))
	pg.add_child(HillsDress._box_mesh(Vector3(6.2, 0.1, 0.1), PLAY_RED, Vector3(x0 + 3.0, y + 2.5, z0), "Bar"))
	for k: int in 3:
		var sx: float = x0 + 1.2 + float(k) * 1.8
		for dx: float in [-0.25, 0.25]:
			pg.add_child(HillsDress._box_mesh(Vector3(0.02, 1.9, 0.02), Color("50565e"), Vector3(sx + dx, y + 1.5, z0), "Chain", false))
		pg.add_child(HillsDress._box_mesh(Vector3(0.6, 0.05, 0.22), PLAY_BLUE, Vector3(sx, y + 0.55, z0), "Seat", false))
	# slide: a platform tower, a ladder and the chute
	var sx0: float = -16.0
	var sz0: float = 64.0
	pg.add_child(HillsDress._box_mesh(Vector3(1.4, 0.1, 1.4), PLAY_YELLOW, Vector3(sx0, y + 1.6, sz0), "Deck"))
	for cx: float in [-0.65, 0.65]:
		for cz: float in [-0.65, 0.65]:
			pg.add_child(HillsDress._box_mesh(Vector3(0.1, 2.6, 0.1), PLAY_BLUE, Vector3(sx0 + cx, y + 1.3, sz0 + cz), "Post", false))
	var roof := MeshInstance3D.new()
	var rm := PrismMesh.new()
	rm.size = Vector3(1.6, 0.7, 1.6)
	roof.mesh = rm
	roof.material_override = Toon.material(PLAY_RED, false)
	roof.position = Vector3(sx0, y + 2.95, sz0)
	pg.add_child(roof)
	var chute := HillsDress._box_mesh(Vector3(0.7, 0.06, 3.3), PLAY_YELLOW, Vector3(sx0, y + 0.85, sz0 + 2.1), "Chute")
	chute.rotation.x = 0.52
	pg.add_child(chute)
	pg.add_child(HillsDress._box_shape(Vector3(1.6, 3.2, 1.6), Vector3(sx0, y + 1.6, sz0)))
	# sandbox (a low border you roll round, not into: 0.35 m)
	var sb_c := Vector3(-24.0, y, 66.0)
	pg.add_child(HillsDress._box_mesh(Vector3(4.0, 0.08, 4.0), Color("e5cf98"), sb_c + Vector3(0.0, 0.2, 0.0), "Sand", false))
	for e: Array in [[Vector3(0.0, 0.0, -2.0), Vector3(4.3, 0.35, 0.3)], [Vector3(0.0, 0.0, 2.0), Vector3(4.3, 0.35, 0.3)], [Vector3(-2.0, 0.0, 0.0), Vector3(0.3, 0.35, 4.3)], [Vector3(2.0, 0.0, 0.0), Vector3(0.3, 0.35, 4.3)]]:
		var off: Vector3 = e[0]
		var sz: Vector3 = e[1]
		pg.add_child(HillsDress._box_mesh(sz, Color("b5875a"), sb_c + off + Vector3(0.0, sz.y * 0.5, 0.0), "Edge"))
		pg.add_child(HillsDress._box_shape(sz + Vector3(0.0, 0.3, 0.0), sb_c + off + Vector3(0.0, sz.y * 0.5 - 0.15, 0.0)))


## The secret garden: a sunken back yard west of the park, walled in by tall hedges, with a little drained pool and
## the hidden tape. Ways in: ollie the low hedge from the park's kicker, or find the gap in the north hedge behind
## the shed.
static func secret(lvl: HillsLevel) -> void:
	var y: float = lvl.park_y
	var r: Rect2 = HillsLevel.SECRET
	var root := Node3D.new()
	root.name = "SecretGarden"
	lvl.add_child(root)
	var deck: Rect2 = HillsLevel.SECRET_DECK
	var pool: Node3D = HillsPool.build(deck.size, 3.9, 2.2, 1.9, 1.1, 1.6, 2.6, 0.18, "secret_pool")
	pool.name = "SecretPool"
	pool.position = Vector3(deck.get_center().x, y, deck.get_center().y)
	root.add_child(pool)
	# tall hedges on the west, south and north sides (a gap in the north one), a low one on the park side (east)
	var hs: Array = [
		[Vector3(r.position.x, y, r.get_center().y), Vector3(r.size.y, 2.4, 1.2), PI * 0.5],
		[Vector3(r.get_center().x, y, r.end.y), Vector3(r.size.x, 2.4, 1.2), 0.0],
		[Vector3(r.position.x + 4.5, y, r.position.y), Vector3(9.0, 2.4, 1.2), 0.0],
		[Vector3(r.end.x - 4.0, y, r.position.y), Vector3(6.0, 2.4, 1.2), 0.0],
		[Vector3(r.end.x, y, r.get_center().y), Vector3(r.size.y, 1.05, 1.0), PI * 0.5],
	]
	for h: Array in hs:
		root.add_child(HillsDress.hedge(h[0] as Vector3, h[1] as Vector3, float(h[2])))
	# the shed that hides the north gap
	var shed := StaticBody3D.new()
	shed.name = "Shed"
	var shed_c := Vector3(r.position.x + 11.0, y, r.position.y - 3.2)
	shed.add_child(HillsDress._box_mesh(Vector3(3.0, 2.3, 2.2), Color("8f6b4e"), shed_c + Vector3(0.0, 1.15, 0.0), "Walls"))
	var sr := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(3.3, 0.8, 2.5)
	sr.mesh = prism
	sr.material_override = Toon.material(Color("5b4a42"), false)
	sr.position = shed_c + Vector3(0.0, 2.7, 0.0)
	shed.add_child(sr)
	shed.add_child(HillsDress._box_shape(Vector3(3.0, 2.8, 2.2), shed_c + Vector3(0.0, 1.3, 0.0)))
	root.add_child(shed)
	# a kicker on the park lawn aimed west over the low hedge
	var k: Node3D = Kicker.build(2.4, 2.8, 0.9)
	k.name = "SecretKicker"
	var kb := Basis(Vector3.UP, PI * 0.5)  # rises toward -X
	k.transform = Transform3D(kb, Vector3(r.end.x + 2.5, y - 0.03, r.position.y + 4.0 + 1.2))
	root.add_child(k)
	lvl.add_child(PieceKit.gap_zone("secret_hop", Vector3(r.end.x - 1.0, y + 1.3, r.position.y + 1.0), Vector3(2.0, 3.0, r.size.y - 2.0)))
	lvl.add_child(PieceKit.gap_zone("secret_in", Vector3(r.position.x + 1.0, y - 2.5, r.position.y + 1.0), Vector3(r.size.x - 3.0, 4.0, r.size.y - 2.0)))
