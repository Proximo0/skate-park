class_name HillsTown
extends RefCounted
## The Hills' town life and dressing: the overlook rail along Valley View, the school-zone crossing, through traffic on
## Crest Drive and Valley View, the people (walkers, joggers, dog walkers, a crossing guard, neighbours chatting), the
## trees, sprinklers, parked cars, lamps and yard clutter, and the view: the far suburbs, the valley town with its
## lights coming on, and the radio tower on the ridge.

const WALKER_SPEED := Vector2(1.0, 1.35)
const JOG_SPEED := Vector2(2.3, 2.8)
const CROSS_X: float = -40.0  ## the school crossing on Valley View
const SHOULDER: float = 2.2  ## the overlook walk between Valley View's south edge and the rail


static func build(lvl: HillsLevel) -> void:
	var life := HillsLife.new()
	life.name = "Life"
	lvl.add_child(life)
	HillsTown._overlook(lvl)
	HillsTown._school(lvl, life)
	HillsTown._traffic(lvl, life)
	HillsTown._people(lvl, life)
	HillsTown._trees(lvl)
	HillsTown._yards(lvl, life)
	HillsTown._lamps(lvl)
	HillsTown._vista(lvl, life)
	lvl.add_child(Birds.flock("crow", 7, Vector3(-30.0, 48.0, -20.0), 36.0, 4))
	lvl.add_child(Birds.flock("pigeon", 9, Vector3(30.0, lvl.park_y + 9.0, 64.0), 14.0, 11))


# --- Valley View: the overlook ------------------------------------------------------------------------------------

## The rail along Valley View's south edge, with a paved walk between: the long grind with the valley below it.
static func _overlook(lvl: HillsLevel) -> void:
	var r: HillsRoad = lvl.roads["valley"]
	var s0: float = float(r.closest(Vector3(-HillsLevel.HALF + 1.0, 0.0, 88.0))["s"])
	var s1: float = float(r.closest(Vector3(HillsLevel.HALF - 1.0, 0.0, 88.0))["s"])
	var off: float = HillsLevel.ROAD_HALF + SHOULDER
	var pts := PackedVector3Array()
	var s: float = s0
	while s <= s1:
		pts.append(r.ground_point(lvl.terrain, s, off, 0.0))
		s += 3.0
	var rail: Node3D = HillsDress.long_rail(pts, 0.95)
	rail.name = "OverlookRail"
	lvl.add_child(rail)
	var walk := MeshInstance3D.new()
	walk.name = "OverlookWalk"
	walk.mesh = r.ribbon(lvl.terrain, s0 - 4.0, s1 + 4.0, HillsLevel.ROAD_HALF + 0.05, off + 0.5, 0.03, 1.0)
	walk.material_override = WorldSurface.material("concrete", Color("cbc4b5"), 0.5)
	walk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lvl.add_child(walk)
	# zones on the rail, a stretch apart: grind through both for the gap
	for e: Array in [["overlook_w", -24.0], ["overlook_e", 14.0]]:
		var sc: float = float(r.closest(Vector3(float(e[1]), 0.0, 88.0))["s"])
		var p: Vector3 = r.ground_point(lvl.terrain, sc, off, 0.0)
		lvl.add_child(HillsSpots._zone_at(str(e[0]), p + Vector3(0.0, 1.3, 0.0), Vector3(2.4, 1.8, 2.4)))
	# coin-op binoculars and benches on the walk by the crossing
	var sc2: float = float(r.closest(Vector3(CROSS_X, 0.0, 88.0))["s"])
	for dx: float in [-7.0, -13.0]:
		var p2: Vector3 = r.ground_point(lvl.terrain, sc2 + dx, off - 0.7, 0.0)
		lvl.add_child(HillsTown._viewer(p2, r.right(sc2)))
	var bn: Node3D = StreetBits.bench(2.4)
	var bp: Vector3 = r.ground_point(lvl.terrain, sc2 - 20.0, off - 0.95, 0.0)
	bn.transform = Transform3D(Basis(Vector3.UP, atan2(r.right(sc2).x, r.right(sc2).z) + PI), bp)
	lvl.add_child(bn)


## A coin-operated viewer on a post, looking along `look`.
static func _viewer(p: Vector3, look: Vector3) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "Viewer"
	body.transform = Transform3D(Basis(Vector3.UP, atan2(-look.x, -look.z)), p)
	body.add_child(HillsDress._box_mesh(Vector3(0.12, 1.1, 0.12), Color("4b6b8a"), Vector3(0.0, 0.55, 0.0), "Post", false))
	body.add_child(HillsDress._box_mesh(Vector3(0.5, 0.3, 0.45), Color("3d8f6f"), Vector3(0.0, 1.25, 0.0), "Head"))
	for sx: float in [-0.11, 0.11]:
		var eye := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.07
		cm.height = 0.18
		cm.radial_segments = 8
		eye.mesh = cm
		eye.material_override = Toon.material(Color("2c3b4a"), false)
		eye.rotation.x = PI * 0.5
		eye.position = Vector3(sx, 1.28, -0.3)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(eye)
	body.add_child(HillsDress._box_shape(Vector3(0.5, 1.4, 0.5), Vector3(0.0, 0.7, 0.0)))
	return body


# --- the school crossing -------------------------------------------------------------------------------------------

static func _school(lvl: HillsLevel, life: HillsLife) -> void:
	var r: HillsRoad = lvl.roads["valley"]
	var t: HillsTerrain = lvl.terrain
	var sc: float = float(r.closest(Vector3(CROSS_X, 0.0, 88.0))["s"])
	var root := Node3D.new()
	root.name = "SchoolCrossing"
	lvl.add_child(root)
	# zebra stripes across the road, and the yellow centre line and SCHOOL / XING painted in each lane
	var paint := SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	var o: float = -HillsLevel.ROAD_HALF + 0.3
	while o < HillsLevel.ROAD_HALF - 0.4:
		paint.append_from(r.ribbon(t, sc - 1.6, sc + 1.6, o, o + 0.5, HillsRoad.LINE_LIFT, 0.8), 0, Transform3D.IDENTITY)
		o += 0.95
	for e: Array in [[sc - 3.0, sc - 2.6], [sc + 2.6, sc + 3.0]]:
		paint.append_from(r.ribbon(t, float(e[0]), float(e[1]), -HillsLevel.ROAD_HALF + 0.2, HillsLevel.ROAD_HALF - 0.2, HillsRoad.LINE_LIFT, 0.4), 0, Transform3D.IDENTITY)
	var pm := MeshInstance3D.new()
	pm.name = "Crosswalk"
	pm.mesh = paint.commit()
	pm.material_override = Toon.material(Color("f3f0e6"), false)
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pm)
	for e: Array in [[sc - 12.0, 2.0, 1.0], [sc + 12.0, -2.0, -1.0]]:
		var s: float = float(e[0])
		var p: Vector3 = r.ground_point(t, s, float(e[1]), HillsRoad.LINE_LIFT + 0.01)
		var fwd: Vector3 = r.tangent(s) * float(e[2])
		fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
		var l := Label3D.new()
		l.text = "SCHOOL\nXING"
		l.font_size = 160
		l.pixel_size = 0.012
		l.modulate = Color("f3f0e6")
		l.outline_size = 0
		l.double_sided = false
		# lying flat, read by a driver coming along `fwd`: its up is the way they drive
		l.transform = Transform3D(Basis(fwd.cross(Vector3.UP).normalized(), fwd, Vector3.UP), p)
		root.add_child(l)
	# beacons and signs on the north sidewalk, either side of the crossing; a sign on the overlook side
	for ds: float in [-26.0, 26.0]:
		var b: Array = HillsDress.beacon()
		var bn: Node3D = b[0]
		var p: Vector3 = r.ground_point(t, sc + ds, -(HillsLevel.ROAD_HALF + HillsLevel.WALK - 0.4), 0.0)
		p.y = maxf(p.y, r.sample(sc + ds).y + HillsRoad.CURB_H)
		bn.transform = Transform3D(Basis(Vector3.UP, atan2(r.tangent(sc + ds).x, r.tangent(sc + ds).z) + (PI if ds < 0.0 else 0.0)), p)
		root.add_child(bn)
		life.add_beacon_lamps([b[1], b[2]])
	for ds: float in [-6.0, 6.0]:
		var sg: Node3D = HillsDress.sign_post("SCHOOL\nXING")
		var p: Vector3 = r.ground_point(t, sc + ds, -(HillsLevel.ROAD_HALF + HillsLevel.WALK - 0.3), 0.0)
		p.y = maxf(p.y, r.sample(sc + ds).y + HillsRoad.CURB_H)
		sg.transform = Transform3D(Basis(Vector3.UP, atan2(r.tangent(sc).x, r.tangent(sc).z) + (0.0 if ds < 0.0 else PI)), p)
		root.add_child(sg)
		var body := StaticBody3D.new()
		body.add_child(HillsDress._box_shape(Vector3(0.3, 2.4, 0.3), p + Vector3(0.0, 1.2, 0.0)))
		root.add_child(body)
	# a sign on the park lawn: the school is just down the road
	var board := HillsTown._board("VALLEY VIEW ELEMENTARY", "Go Hawks!  Have a great summer")
	var bp: Vector3 = t.at(CROSS_X - 4.0, 79.0)
	board.transform = Transform3D(Basis(Vector3.UP, 0.0), bp)
	root.add_child(board)


## A low school marquee sign: a brick base and a white board with two lines of letters.
static func _board(line1: String, line2: String) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "SchoolSign"
	body.add_child(HillsDress._box_mesh(Vector3(4.2, 0.7, 0.6), Color("a65a45"), Vector3(0.0, 0.35, 0.0), "Base"))
	body.add_child(HillsDress._box_mesh(Vector3(3.8, 1.2, 0.2), Color("f4f1ea"), Vector3(0.0, 1.3, 0.0), "Board"))
	body.add_child(HillsDress._box_mesh(Vector3(4.0, 0.12, 0.3), Color("2f5f8f"), Vector3(0.0, 1.95, 0.0), "Cap"))
	for side: float in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = line1 + "\n" + line2
		l.font_size = 44
		l.pixel_size = 0.006
		l.modulate = Color("1f3550")
		l.outline_size = 0
		l.position = Vector3(0.0, 1.3, side * 0.11)
		l.rotation.y = 0.0 if side > 0.0 else PI
		body.add_child(l)
	body.add_child(HillsDress._box_shape(Vector3(4.2, 2.0, 0.6), Vector3(0.0, 1.0, 0.0)))
	return body


# --- traffic --------------------------------------------------------------------------------------------------------

## Crest Drive and Valley View carry the through traffic: each street is one loop, out along the right-hand lane and
## back along the other, turning far outside the riding area. Cars stop at the school crossing on red.
static func _traffic(lvl: HillsLevel, life: HillsLife) -> void:
	var tr := Traffic.new()
	tr.name = "Traffic"
	lvl.add_child(tr)
	life.traffic = tr
	var counts: Dictionary = {"valley": 6, "crest": 5}
	for rn: String in ["valley", "crest"]:
		var r: HillsRoad = lvl.roads[rn]
		var out: PackedVector3Array = r.lane_points(lvl.terrain, 2.0, 2.0, r.length - 2.0, 4.0)
		var back: PackedVector3Array = r.lane_points(lvl.terrain, -2.0, 2.0, r.length - 2.0, 4.0)
		back.reverse()
		var loop := PackedVector3Array()
		loop.append_array(out)
		loop.append_array(back)
		var lane: int = tr.add_lane(LanePath.from_points(loop, true, 1.5), 10.0)
		tr.add_cars(lane, int(counts[rn]))
	var vr: HillsRoad = lvl.roads["valley"]
	var cross: Vector3 = vr.sample(float(vr.closest(Vector3(CROSS_X, 0.0, 88.0))["s"]))
	tr.add_intersection(cross, 6.0, 0.0)


# --- people ---------------------------------------------------------------------------------------------------------

static func _walk_path(lvl: HillsLevel, rn: String, side: int, x0: float, x1: float, along_z: bool = false) -> LanePath:
	var r: HillsRoad = lvl.roads[rn]
	var a: Vector3 = Vector3(0.0, 0.0, x0) if along_z else Vector3(x0, 0.0, 0.0)
	var b: Vector3 = Vector3(0.0, 0.0, x1) if along_z else Vector3(x1, 0.0, 0.0)
	if along_z:
		a.x = r.sample(0.0).x
		b.x = a.x
	else:
		a.z = r.sample(r.length * 0.5).z
		b.z = a.z
	var sa: float = float(r.closest(a)["s"])
	var sb: float = float(r.closest(b)["s"])
	return LanePath.from_points(r.walk_points(lvl.terrain, side, minf(sa, sb), maxf(sa, sb), 3.0), false, 2.0)


static func _people(lvl: HillsLevel, life: HillsLife) -> void:
	var crowd := Pedestrians.new()
	crowd.name = "Pedestrians"
	lvl.add_child(crowd)
	life.crowd = crowd
	var dogs: Array = [[Color("c8a46a"), 1.0], [Color("2b2522"), 0.8], [Color("efe8dc"), 1.15], [Color("8a5a3a"), 0.9]]
	# Crest Drive's north sidewalk: walkers and a dog walker
	var crest_n: LanePath = HillsTown._walk_path(lvl, "crest", -1, -96.0, 96.0)
	var cw: Array[Pedestrian] = crowd.add_walkers(crest_n, 2, WALKER_SPEED.x, WALKER_SPEED.y)
	life.add_dog(cw[0], dogs[0][0] as Color, float(dogs[0][1]), 1.0)
	# Valley View's sidewalk (the north side): walkers, two joggers, a dog walker
	var valley_n: LanePath = HillsTown._walk_path(lvl, "valley", -1, -100.0, 100.0)
	var vw: Array[Pedestrian] = crowd.add_walkers(valley_n, 2, WALKER_SPEED.x, WALKER_SPEED.y)
	life.add_dog(vw[1], dogs[1][0] as Color, float(dogs[1][1]), -1.0)
	crowd.add_walkers(valley_n, 2, JOG_SPEED.x, JOG_SPEED.y)
	# joggers working up and down the hills, a dog walker on Hillcrest
	var cy: HillsRoad = lvl.roads["canyon"]
	crowd.add_walkers(LanePath.from_points(cy.walk_points(lvl.terrain, -1, 14.0, cy.length - 14.0, 3.0), false, 2.0), 1, JOG_SPEED.x, JOG_SPEED.y)
	var hc: HillsRoad = lvl.roads["hillcrest"]
	var hcw: Array[Pedestrian] = crowd.add_walkers(LanePath.from_points(hc.walk_points(lvl.terrain, 1, 14.0, hc.length - 14.0, 3.0), false, 2.0), 2, WALKER_SPEED.x, JOG_SPEED.y)
	life.add_dog(hcw[0], dogs[2][0] as Color, float(dogs[2][1]), 1.0)
	# the park: a dog walker round the lawn, people watching the quarter pipe, a group by the benches
	var y: float = lvl.park_y
	var loop := PackedVector3Array([Vector3(-27.0, y, 50.0), Vector3(-27.0, y, 77.0), Vector3(-9.0, y, 78.0), Vector3(-9.0, y, 50.0)])
	var pw: Array[Pedestrian] = crowd.add_walkers(LanePath.from_points(loop, true, 3.0), 1, WALKER_SPEED.x, WALKER_SPEED.x + 0.1)
	life.add_dog(pw[0], dogs[3][0] as Color, float(dogs[3][1]), -1.0)
	crowd.add_idler(Vector3(49.5, y, 66.0), PI * 0.25 + PI, "idle")
	crowd.add_idler(Vector3(71.0, y, 66.0), -PI * 0.3 + PI, "phone")
	crowd.add_group(Vector3(-3.0, y, 74.0), 2)
	# the crossing guard on the corner, with her stop paddle
	var vr: HillsRoad = lvl.roads["valley"]
	var sc: float = float(vr.closest(Vector3(CROSS_X, 0.0, 88.0))["s"])
	var gp: Vector3 = vr.ground_point(lvl.terrain, sc - 2.6, -(HillsLevel.ROAD_HALF + 0.7), 0.0)
	gp.y = vr.sample(sc).y + HillsRoad.CURB_H
	var guard: Pedestrian = crowd.add_idler(gp, atan2(-vr.right(sc).x, -vr.right(sc).z) + PI, "wave")
	guard.add_child(HillsTown._paddle())
	# neighbours: chatting at the end of a Summit Court drive, and in Sunset Court
	crowd.add_group(Vector3(HillsLevel.SUMMIT_BULB.x + 3.0, lvl.summit_y + 0.1, HillsLevel.SUMMIT_BULB.z + 15.6), 2)
	crowd.add_group(Vector3(HillsLevel.SUNSET_BULB.x - 2.0, lvl.sunset_y + 0.1, HillsLevel.SUNSET_BULB.z - 15.2), 2)


## The crossing guard's stop paddle, carried at the hip.
static func _paddle() -> Node3D:
	var root := Node3D.new()
	root.name = "Paddle"
	root.position = Vector3(0.32, 0.75, -0.05)
	root.add_child(HillsDress._box_mesh(Vector3(0.03, 0.9, 0.03), Color("d8d8d0"), Vector3(0.0, 0.3, 0.0), "Stick", false))
	var head := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.22
	cm.height = 0.02
	cm.radial_segments = 8
	head.mesh = cm
	head.material_override = Toon.material(Color("d03a2f"), false)
	head.rotation = Vector3(PI * 0.5, 0.0, PI / 8.0)
	head.position = Vector3(0.0, 0.85, 0.0)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(head)
	for side: float in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = "STOP"
		l.font_size = 40
		l.pixel_size = 0.004
		l.modulate = Color.WHITE
		l.outline_size = 0
		l.position = Vector3(0.0, 0.85, side * 0.015)
		l.rotation.y = 0.0 if side < 0.0 else PI
		root.add_child(l)
	return root


# --- trees ----------------------------------------------------------------------------------------------------------

## True when `p` (x, z) is clear of the streets, sidewalks, driveways, houses, the ditch, the pools and the park's slab.
static func _clear(lvl: HillsLevel, p: Vector3, pad: float) -> bool:
	for r: HillsRoad in lvl.road_list:
		var reach: float = HillsLevel.ROAD_HALF + HillsLevel.WALK + pad
		if not r.box.grow(reach + 2.0).has_point(Vector2(p.x, p.z)):
			continue
		if absf(float(r.closest(p)["d"])) < reach:
			return false
	for c: Vector3 in [HillsLevel.SUMMIT_BULB, HillsLevel.SUNSET_BULB]:
		if Vector2(p.x - c.x, p.z - c.z).length() < HillsLevel.BULB_R + HillsLevel.WALK + pad:
			return false
	for lot: Dictionary in lvl.lots:
		var local: Vector3 = (lot["basis"] as Basis).inverse() * (Vector3(p.x, 0.0, p.z) - Vector3((lot["centre"] as Vector3).x, 0.0, (lot["centre"] as Vector3).z))
		var pr: Rect2 = lot["pad"]
		if pr.grow(pad - 1.0).has_point(Vector2(local.x, local.z)):
			return false
		var a: Vector3 = lot["drive_a"]
		var b: Vector3 = lot["drive_b"]
		var q: Vector3 = Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0.0, p.z), Vector3(a.x, 0.0, a.z), Vector3(b.x, 0.0, b.z))
		if q.distance_to(Vector3(p.x, 0.0, p.z)) < 2.0 + pad:
			return false
	if absf(p.x - lvl.channel.cx) < HillsChannel.HALF + 2.0 + pad and p.z > lvl.channel.z_head - 6.0 and p.z < lvl.channel.z_end + 4.0:
		return false
	for r: Rect2 in [HillsLevel.TERRACE.grow(1.0), Rect2(-8.0, 49.0, 80.0, 31.0), HillsLevel.SECRET.grow(-1.0), Rect2(-30.0, 50.0, 20.0, 18.0)]:
		if r.grow(pad).has_point(Vector2(p.x, p.z)):
			return false
	return true


static func _trees(lvl: HillsLevel) -> void:
	var trees := SwayTrees.new()
	trees.name = "Trees"
	var trunks := StaticBody3D.new()
	trunks.name = "TreeTrunks"
	var t: HillsTerrain = lvl.terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var placed: Array[Vector3] = []
	# street trees on the verges, behind the sidewalks
	for r: HillsRoad in lvl.road_list:
		var s: float = 6.0
		while s < r.length:
			for side: int in [-1, 1]:
				var p: Vector3 = r.ground_point(t, s + rng.randf_range(-3.0, 3.0), float(side) * (HillsLevel.ROAD_HALF + HillsLevel.WALK + 2.4 + rng.randf() * 2.0), 0.0)
				if absf(p.x) > 300.0:
					continue
				var inside: bool = lvl.bounds.grow(-2.0).has_point(Vector2(p.x, p.z))
				if inside and rng.randf() < 0.35:
					continue
				if not HillsTown._clear(lvl, p, 1.0):
					continue
				placed.append(p)
			s += 15.0 if absf(r.sample(s).x) < 120.0 else 26.0
	# yard trees behind the houses and a scatter on the open slopes
	for lot: Dictionary in lvl.lots:
		var c: Vector3 = lot["centre"]
		var bs: Basis = lot["basis"]
		for off: Vector3 in [Vector3(-6.0, 0.0, 9.5), Vector3(5.5, 0.0, 11.0)]:
			var p: Vector3 = c + bs * (off + Vector3(rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(-1.0, 1.0)))
			if HillsTown._clear(lvl, p, 0.5):
				placed.append(t.at(p.x, p.z))
	for i: int in 70:
		var p := Vector3(rng.randf_range(-105.0, 105.0), 0.0, rng.randf_range(-105.0, 105.0))
		if HillsTown._clear(lvl, p, 2.5):
			placed.append(t.at(p.x, p.z))
	# the park's west lawn and its edges
	for p2: Vector2 in [Vector2(-28.0, 49.0), Vector2(-12.0, 49.0), Vector2(-28.0, 72.0), Vector2(-11.0, 78.0), Vector2(74.0, 50.0), Vector2(75.0, 70.0), Vector2(-36.0, 52.0)]:
		placed.append(t.at(p2.x, p2.y))
	var kinds: Array[String] = ["round", "round", "round", "pine"]
	for p: Vector3 in placed:
		var kind: String = kinds[rng.randi() % kinds.size()]
		if p.z < -90.0 and rng.randf() < 0.5:
			kind = "pine"
		trees.add(kind, p)
		if lvl.bounds.grow(4.0).has_point(Vector2(p.x, p.z)):
			var cs := CollisionShape3D.new()
			var sh := CylinderShape3D.new()
			sh.radius = 0.35
			sh.height = 4.0
			cs.shape = sh
			cs.position = p + Vector3(0.0, 1.5, 0.0)
			trunks.add_child(cs)
	# hillside pines and oaks beyond the crest, and on the far slopes either side
	for i: int in 140:
		var p := Vector3(rng.randf_range(-320.0, 320.0), 0.0, rng.randf_range(-260.0, -112.0))
		if absf(p.x) < 112.0 and p.z > -112.0:
			continue
		if not HillsTown._clear(lvl, p, 1.5):
			continue
		trees.add("pine" if rng.randf() < 0.6 else "round", t.at(p.x, p.z), rng.randf_range(1.0, 1.5))
	for i: int in 90:
		var p := Vector3(rng.randf_range(112.0, 320.0) * (1.0 if rng.randf() < 0.5 else -1.0), 0.0, rng.randf_range(-110.0, 120.0))
		if not HillsTown._clear(lvl, p, 1.5):
			continue
		trees.add("round" if rng.randf() < 0.7 else "pine", t.at(p.x, p.z), rng.randf_range(1.0, 1.4))
	lvl.add_child(trees)
	lvl.add_child(trunks)


# --- yards ----------------------------------------------------------------------------------------------------------

## Sprinklers on the front lawns, parked cars in some drives, hedges and picket fences, bikes on the lawn, a lemonade
## stand, a basketball hoop over a garage door.
static func _yards(lvl: HillsLevel, life: HillsLife) -> void:
	var t: HillsTerrain = lvl.terrain
	var root := Node3D.new()
	root.name = "Yards"
	lvl.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var paints: Array[Color] = [Color("c0392b"), Color("2e86c1"), Color("f4d03f"), Color("ecf0f1"), Color("27ae60"), Color("8e44ad"), Color("e67e22")]
	var kinds: Array[String] = ["hatch", "pickup", "van"]
	var sprinklers: int = 0
	for i: int in lvl.lots.size():
		var lot: Dictionary = lvl.lots[i]
		var c: Vector3 = lot["centre"]
		var bs: Basis = lot["basis"]
		var hw: float = HillsLevel._house_half_w(str(lot["kind"]))
		var depth: float = HillsLevel._house_depth(str(lot["kind"]))
		var dx: float = float(lot["drive_x"])
		var garage: bool = bool((lot["opts"] as Dictionary).get("garage", false))
		# a sprinkler on every other front lawn (on the side away from the drive)
		if i % 2 == 0 and sprinklers < 9:
			var lp: Vector3 = c + bs * Vector3(-signf(dx) * hw * 0.5, 0.0, -depth - 3.5)
			if HillsTown._lawn_ok(lvl, lp):
				life.add_sprinkler(t.at(lp.x, lp.z), atan2(-(bs.z.x), -(bs.z.z)) + PI, 2.4, float(i) * 0.7)
				sprinklers += 1
		# a parked car in a third of the drives (never on the kicker drives)
		if i % 3 == 1 and not garage:
			var a: Vector3 = lot["drive_a"]
			var b: Vector3 = lot["drive_b"]
			var d := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
			var cp: Vector3 = Vector3(b.x, 0.0, b.z) - d * 3.2
			var car := CarModel.create(kinds[i % kinds.size()], paints[i % paints.size()])
			var body := StaticBody3D.new()
			body.name = "ParkedCar"
			var gy: Vector3 = t.at(cp.x, cp.z)
			body.transform = Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), gy)
			body.add_child(car)
			var bb: AABB = car.aabb
			body.add_child(HillsDress._box_shape(bb.size * Vector3(1.0, 0.9, 1.0), bb.get_center()))
			root.add_child(body)
		# hedges along some front walks, white picket fences on others
		var front_z: float = -depth - 6.0
		if i % 4 == 2:
			var hp: Vector3 = c + bs * Vector3(-signf(dx) * (hw * 0.5 + 1.0), 0.0, front_z)
			if HillsTown._lawn_ok(lvl, hp):
				root.add_child(HillsDress.hedge(t.at(hp.x, hp.z) - Vector3(0.0, 0.2, 0.0), Vector3(hw, 1.0, 0.9), float(lot["yaw"])))
		elif i % 4 == 0:
			var pa: Vector3 = c + bs * Vector3(-signf(dx) * (hw + 1.0), 0.0, front_z)
			var pb: Vector3 = c + bs * Vector3(dx - signf(dx) * 2.4, 0.0, front_z)
			if HillsTown._lawn_ok(lvl, pa) and HillsTown._lawn_ok(lvl, pb) and HillsTown._lawn_ok(lvl, (pa + pb) * 0.5):
				root.add_child(HillsDress.picket(t.at(pa.x, pa.z), t.at(pb.x, pb.z)))
		# bikes on the lawn (the kids are at school)
		if i % 5 == 3:
			var kp: Vector3 = c + bs * Vector3(-signf(dx) * 2.0, 0.0, -depth - 2.0)
			var bike: Node3D = HillsTown._bike(paints[(i + 2) % paints.size()])
			bike.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, 1.35), t.at(kp.x, kp.z, 0.12))
			root.add_child(bike)
	# a lemonade stand at the end of a Sunset Court drive, a hoop over the first garage door
	var stand: Node3D = HillsTown._lemonade()
	var sp: Vector3 = Vector3(HillsLevel.SUNSET_BULB.x + 9.0, 0.0, HillsLevel.SUNSET_BULB.z + 11.0)
	stand.transform = Transform3D(Basis(Vector3.UP, atan2(-(HillsLevel.SUNSET_BULB.x - sp.x), -(HillsLevel.SUNSET_BULB.z - sp.z))), t.at(sp.x, sp.z))
	if HillsTown._lawn_ok(lvl, sp):
		root.add_child(stand)
	HillsMerge.merge(root, true)


static func _lawn_ok(lvl: HillsLevel, p: Vector3) -> bool:
	for r: HillsRoad in lvl.road_list:
		var reach: float = HillsLevel.ROAD_HALF + HillsLevel.WALK + 0.5
		if r.box.grow(reach + 2.0).has_point(Vector2(p.x, p.z)) and absf(float(r.closest(p)["d"])) < reach:
			return false
	for c: Vector3 in [HillsLevel.SUMMIT_BULB, HillsLevel.SUNSET_BULB]:
		if Vector2(p.x - c.x, p.z - c.z).length() < HillsLevel.BULB_R + HillsLevel.WALK + 0.5:
			return false
	for lot: Dictionary in lvl.lots:
		var a: Vector3 = lot["drive_a"]
		var b: Vector3 = lot["drive_b"]
		var q: Vector3 = Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0.0, p.z), Vector3(a.x, 0.0, a.z), Vector3(b.x, 0.0, b.z))
		if q.distance_to(Vector3(p.x, 0.0, p.z)) < 2.2:
			return false
	return true


## A kid's bike lying on its side (visual only).
static func _bike(colour: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Bike"
	for z: float in [-0.45, 0.45]:
		var w := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.26
		tm.outer_radius = 0.3
		tm.rings = 12
		tm.ring_segments = 4
		w.mesh = tm
		w.material_override = Toon.material(Color("24262b"), false)
		w.rotation.z = PI * 0.5
		w.position = Vector3(0.0, 0.0, z)
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(w)
	var frame := HillsDress._box_mesh(Vector3(0.04, 0.04, 0.85), colour, Vector3(0.0, 0.18, 0.0), "Frame", false)
	root.add_child(frame)
	var down := HillsDress._box_mesh(Vector3(0.04, 0.32, 0.04), colour, Vector3(0.0, 0.05, -0.05), "Down", false)
	down.rotation.x = 0.5
	root.add_child(down)
	root.add_child(HillsDress._box_mesh(Vector3(0.5, 0.03, 0.03), Color("cfd3d8"), Vector3(0.0, 0.42, -0.42), "Bars", false))
	return root


static func _lemonade() -> Node3D:
	var body := StaticBody3D.new()
	body.name = "LemonadeStand"
	body.add_child(HillsDress._box_mesh(Vector3(1.6, 0.9, 0.7), Color("f2e3b3"), Vector3(0.0, 0.45, 0.0), "Counter"))
	for sx: float in [-0.75, 0.75]:
		body.add_child(HillsDress._box_mesh(Vector3(0.06, 1.7, 0.06), Color("d9c48f"), Vector3(sx, 0.85, 0.3), "Post", false))
	body.add_child(HillsDress._box_mesh(Vector3(1.7, 0.42, 0.04), Color("f7d54a"), Vector3(0.0, 1.55, 0.3), "Sign", false))
	var l := Label3D.new()
	l.text = "LEMONADE 25c"
	l.font_size = 48
	l.pixel_size = 0.005
	l.modulate = Color("c0392b")
	l.outline_size = 0
	l.position = Vector3(0.0, 1.55, 0.27)
	l.rotation.y = PI
	body.add_child(l)
	body.add_child(HillsDress._box_mesh(Vector3(0.18, 0.28, 0.18), Color("f9e79f"), Vector3(-0.3, 1.04, 0.0), "Jug", false))
	body.add_child(HillsDress._box_shape(Vector3(1.6, 1.0, 0.7), Vector3(0.0, 0.5, 0.0)))
	return body


## Street lamps along the sidewalks inside the riding area (one merged mesh).
static func _lamps(lvl: HillsLevel) -> void:
	var root := Node3D.new()
	root.name = "StreetLamps"
	lvl.add_child(root)
	var t: HillsTerrain = lvl.terrain
	for rn: String in ["crest", "valley", "hillcrest", "canyon"]:
		var r: HillsRoad = lvl.roads[rn]
		var s: float = 10.0
		var side: int = -1
		while s < r.length - 6.0:
			var p: Vector3 = r.ground_point(t, s, float(side) * (HillsLevel.ROAD_HALF + HillsLevel.WALK + 0.45), 0.0)
			if lvl.bounds.grow(-3.0).has_point(Vector2(p.x, p.z)) and HillsTown._lamp_ok(lvl, r, s, side):
				var lm: Node3D = HillsDress.lamp(5.6)
				var toward: Vector3 = -r.right(s) * float(side)
				lm.transform = Transform3D(Basis(Vector3.UP, atan2(toward.x, toward.z)), p)
				root.add_child(lm)
			s += 34.0
			if rn in ["hillcrest", "canyon"]:
				side = -side
	HillsMerge.merge(root, true)


## No lamp on a driveway or in a junction mouth.
static func _lamp_ok(lvl: HillsLevel, r: HillsRoad, s: float, side: int) -> bool:
	for cut: Array in r.cuts:
		if int(cut[0]) == side and s > float(cut[1]) - 2.0 and s < float(cut[2]) + 2.0:
			return false
	var p: Vector3 = r.ground_point(lvl.terrain, s, float(side) * (HillsLevel.ROAD_HALF + HillsLevel.WALK + 0.45), 0.0)
	for o: HillsRoad in lvl.road_list:
		if o == r:
			continue
		if o.box.grow(14.0).has_point(Vector2(p.x, p.z)) and absf(float(o.closest(p)["d"])) < HillsLevel.ROAD_HALF + HillsLevel.WALK + 3.0:
			return false
	return true


# --- the view -------------------------------------------------------------------------------------------------------

## The far suburbs on the slopes either side, the valley town below (its windows starting to light), and the radio
## tower on the eastern ridge.
static func _vista(lvl: HillsLevel, life: HillsLife) -> void:
	var t: HillsTerrain = lvl.terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	# far houses: walls and roofs, two MultiMeshes with per-house colours
	var walls: Array[Transform3D] = []
	var wall_c: Array[Color] = []
	var roofs: Array[Transform3D] = []
	var roof_c: Array[Color] = []
	var house_cols: Array[Color] = [Color("f3ead8"), Color("f5e6b8"), Color("dfe8e4"), Color("e9d6c8"), Color("f4f1ea"), Color("d8dde8")]
	var roof_cols: Array[Color] = [Color("8d7d78"), Color("b0624e"), Color("6f6a70"), Color("a5756a")]
	var tries: int = 0
	while walls.size() < 620 and tries < 6000:
		tries += 1
		var p := Vector3(rng.randf_range(-330.0, 330.0), 0.0, rng.randf_range(-230.0, 200.0))
		if walls.size() >= 260:
			# the valley floor below the hill, thinning out toward the town
			p = Vector3(rng.randf_range(-700.0, 600.0), 0.0, rng.randf_range(190.0, 640.0))
			if rng.randf() < smoothstep(250.0, 600.0, p.z) * 0.3:
				continue
		if absf(p.x) < 116.0 and absf(p.z) < 116.0:
			continue
		if not HillsTown._clear(lvl, p, 2.0):
			continue
		var g: float = t.height_at(p.x, p.z)
		var yaw: float = rng.randf() * TAU
		var w: float = rng.randf_range(8.0, 12.0)
		var d: float = rng.randf_range(7.0, 9.0)
		var h: float = rng.randf_range(3.0, 5.6)
		var b := Basis(Vector3.UP, yaw)
		walls.append(Transform3D(b.scaled(Vector3(w, h + 2.0, d)), Vector3(p.x, g + h * 0.5 - 1.0, p.z)))
		wall_c.append(house_cols[rng.randi() % house_cols.size()])
		roofs.append(Transform3D(b.scaled(Vector3(w + 0.8, 2.2, d + 0.8)), Vector3(p.x, g + h + 1.1, p.z)))
		roof_c.append(roof_cols[rng.randi() % roof_cols.size()])
	lvl.add_child(HillsTown._mm("FarHouses", BoxMesh.new(), walls, wall_c, false))
	var prism := PrismMesh.new()
	lvl.add_child(HillsTown._mm("FarRoofs", prism, roofs, roof_c, false))
	HillsTown._valley_town(lvl, rng)
	# the radio tower on the eastern ridge, its red light blinking
	var tp := Vector3(330.0, 0.0, -300.0)
	tp.y = HillsTerrain.natural(tp.x, tp.z)
	var tower: Node3D = HillsTown._tower(life)
	tower.position = tp
	lvl.add_child(tower)


## A MultiMesh of `mesh` with per-instance colours (lit, no shadows).
static func _mm(node_name: String, mesh: Mesh, xfs: Array[Transform3D], cols: Array[Color], unshaded: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i: int in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cols[i])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## The town on the valley floor: blocks of low buildings, a cluster of towers downtown, and the first lights.
static func _valley_town(lvl: HillsLevel, rng: RandomNumberGenerator) -> void:
	var xfs: Array[Transform3D] = []
	var cols: Array[Color] = []
	var lights: Array[Transform3D] = []
	var light_c: Array[Color] = []
	var town_cols: Array[Color] = [Color("8a7d70"), Color("7f746e"), Color("94877a"), Color("74717a"), Color("897a67"), Color("6d6c7d")]
	var centre := Vector2(-160.0, 1050.0)
	for i: int in 1000:
		var p := Vector2(rng.randf_range(-1200.0, 1000.0), rng.randf_range(640.0, 1600.0))
		var dc: float = p.distance_to(centre)
		var tall: bool = dc < 190.0 and rng.randf() < 0.6
		var w: float = rng.randf_range(14.0, 34.0)
		var d: float = rng.randf_range(14.0, 34.0)
		var h: float = rng.randf_range(40.0, 120.0) if tall else rng.randf_range(6.0, 18.0)
		if tall:
			w *= 0.8
			d *= 0.8
		var g: float = HillsTerrain.natural(p.x, p.y)
		var b := Basis(Vector3.UP, rng.randf_range(-0.08, 0.08))
		xfs.append(Transform3D(b.scaled(Vector3(w, h + 4.0, d)), Vector3(p.x, g + h * 0.5 - 2.0, p.y)))
		cols.append(town_cols[rng.randi() % town_cols.size()].lerp(Color("7d8aa6"), 0.35 if tall else 0.0))
		var nl: int = 2 + int(h / 12.0)
		for k: int in nl:
			if rng.randf() < 0.45:
				continue
			var ly: float = g + rng.randf_range(2.0, h)
			var side: float = 1.0 if rng.randf() < 0.5 else -1.0
			var lp := Vector3(p.x + rng.randf_range(-w * 0.45, w * 0.45), ly, p.y - d * 0.5 - 0.3)
			if side < 0.0:
				lp = Vector3(p.x - w * 0.5 - 0.3, ly, p.y + rng.randf_range(-d * 0.45, d * 0.45))
			var sz: float = rng.randf_range(2.2, 3.4)
			lights.append(Transform3D(Basis.IDENTITY.scaled(Vector3(sz, sz, sz)), lp))
			light_c.append(Color("ffd27a").lerp(Color("fff3d6"), rng.randf()) * rng.randf_range(0.8, 1.3))
	lvl.add_child(HillsTown._mm("ValleyTown", BoxMesh.new(), xfs, cols, false))
	# street lights along a few long boulevards
	for k: int in 5:
		var z: float = 690.0 + float(k) * 190.0
		var x: float = -1180.0
		while x < 980.0:
			lights.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 2.2), Vector3(x, HillsTerrain.natural(x, z) + 6.0, z)))
			light_c.append(Color("ffb860"))
			x += 26.0
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var lm: MultiMeshInstance3D = HillsTown._mm("TownLights", q, lights, light_c, true)
	var mat: StandardMaterial3D = lm.material_override as StandardMaterial3D
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.disable_fog = true
	lvl.add_child(lm)


static func _tower(life: HillsLife) -> Node3D:
	var root := Node3D.new()
	root.name = "RadioTower"
	var h: float = 70.0
	var mat: Material = Toon.material(Color("c94f3d"), false)
	var white: Material = Toon.material(Color("efeae0"), false)
	for k: int in 7:
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.9 - float(k) * 0.1
		cm.bottom_radius = 1.0 - float(k) * 0.1
		cm.height = h / 7.0
		cm.radial_segments = 4
		cm.rings = 1
		seg.mesh = cm
		seg.material_override = mat if k % 2 == 0 else white
		seg.position = Vector3(0.0, h / 7.0 * (float(k) + 0.5), 0.0)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(seg)
	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 4
	lamp.mesh = sm
	var em := StandardMaterial3D.new()
	em.albedo_color = Color("ff3b2f")
	em.emission_enabled = true
	em.emission = Color("ff2a1a")
	em.emission_energy_multiplier = 3.0
	em.disable_fog = true
	lamp.material_override = em
	lamp.position = Vector3(0.0, h + 0.8, 0.0)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lamp)
	life.add_blinker(em)
	return root
