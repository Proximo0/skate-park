class_name DtStreets
extends RefCounted
## Downtown's streets: the asphalt (one collision slab at y = 0), every city block of the grid raised to the plaza
## level behind a rolled granite curb (a wedge on the road side, so a curb never snags a wheel; its top edge is a grind
## line where it faces the play space), lane markings, zebra crossings, stop lines and manholes, and the traffic: a
## two-way ring round the civic block plus an L-shaped loop through the outer arms of each corner intersection, all
## under signals, and a signalled mid-block crossing between the plaza and the transit plaza.

const ASPHALT := Color("4b4f5c")
const SIDEWALK := Color("a8a49c")
const CURB := Color("d6d0c4")
const LINE_YELLOW := Color("e9c75a")
const LINE_WHITE := Color("f1efe8")
const MANHOLE := Color("3b3d45")
const ARM: float = 100.0  ## corner loops run this far out along each arm before turning round
const RING_CARS: int = 6
const ARM_CARS: int = 3
const CAR_VIEW_END: float = 140.0

var lvl: Node3D
var traffic: Traffic
## Manhole / grate positions (DtLife puts steam on some of them).
var grates: Array[Vector3] = []
var _sb: StaticBody3D
var _rails: Node3D


func _init(level: Node3D) -> void:
	lvl = level


func build() -> void:
	var root := Node3D.new()
	root.name = "Streets"
	lvl.add_child(root)
	_sb = DtKit.body(root, "StreetCollision")
	_rails = Node3D.new()
	_rails.name = "CurbRails"
	root.add_child(_rails)
	_road(root)
	_blocks(root)
	_markings(root)
	_traffic(root)


## The asphalt: one collision slab for the whole city floor, one world-space asphalt mesh.
func _road(root: Node3D) -> void:
	var h: float = DtPlan.CITY_HALF
	DtKit.col_box(_sb, Vector3(0.0, -0.5, 0.0), Vector3(h * 2.0, 1.0, h * 2.0))
	var mi := MeshInstance3D.new()
	mi.name = "Asphalt"
	var pm := PlaneMesh.new()
	pm.size = Vector2(h * 2.0, h * 2.0)
	mi.mesh = pm
	mi.material_override = WorldSurface.material("asphalt", ASPHALT)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Every grid block: a raised slab (sidewalk concrete), its curb all round; collision and curb wedges for the
## blocks the rider can reach.
func _blocks(root: Node3D) -> void:
	var slab := DtBatch.new()
	var curb := DtBatch.new()
	var reach: Rect2 = DtPlan.BOUNDS.grow(3.0)
	var p: float = DtPlan.P
	var cr: float = DtPlan.CURB_RUN
	for b: Rect2 in DtPlan.grid_blocks():
		slab.quad(Vector3(b.position.x, p, b.position.y), Vector3(b.end.x, p, b.position.y), Vector3(b.end.x, p, b.end.y), Vector3(b.position.x, p, b.end.y), Color.WHITE, Vector3.UP)
		# the rolled curb: a sloped face from the road up to the slab edge, all four sides
		var c0 := Vector2(b.position.x, b.position.y)
		var c1 := Vector2(b.end.x, b.position.y)
		var c2 := Vector2(b.end.x, b.end.y)
		var c3 := Vector2(b.position.x, b.end.y)
		var sides: Array = [[c0, c1, Vector3(0, 0, -1)], [c1, c2, Vector3(1, 0, 0)], [c2, c3, Vector3(0, 0, 1)], [c3, c0, Vector3(-1, 0, 0)]]
		for s: Array in sides:
			var a2: Vector2 = s[0]
			var b2: Vector2 = s[1]
			var o: Vector3 = s[2]
			var a3 := Vector3(a2.x, p, a2.y)
			var b3 := Vector3(b2.x, p, b2.y)
			curb.quad(a3, b3, b3 + o * cr + Vector3(0.0, -p, 0.0), a3 + o * cr + Vector3(0.0, -p, 0.0), CURB, o + Vector3.UP)
			curb.quad(a3 - o * 0.25 + Vector3(0.0, 0.004, 0.0), b3 - o * 0.25 + Vector3(0.0, 0.004, 0.0), b3 + Vector3(0.0, 0.004, 0.0), a3 + Vector3(0.0, 0.004, 0.0), CURB, Vector3.UP)
		if not reach.intersects(b):
			continue
		var cb: Rect2 = b.intersection(reach.grow(6.0))
		DtKit.col_box(_sb, Vector3(cb.get_center().x, p - 0.4, cb.get_center().y), Vector3(cb.size.x, 0.8, cb.size.y))
		for s: Array in sides:
			var a2: Vector2 = s[0]
			var b2: Vector2 = s[1]
			var o: Vector3 = s[2]
			var mid := Vector2((a2.x + b2.x) * 0.5, (a2.y + b2.y) * 0.5)
			if not reach.has_point(mid + Vector2(o.x, o.z) * 1.0) and not reach.has_point(a2) and not reach.has_point(b2):
				continue
			_curb_wedge(a2, b2, o)
	var smi: MeshInstance3D = slab.instance("Sidewalks", false)
	smi.material_override = WorldSurface.material("concrete", SIDEWALK, 0.5)
	root.add_child(smi)
	root.add_child(curb.instance("Curbs", false))


## A curb wedge along block edge a-b (x/z), road side `o`: from the road (y = 0) up to the slab top over CURB_RUN.
## Clipped to the riding area plus a margin; its top edge (the block edge) is a ledge grind line.
func _curb_wedge(a2: Vector2, b2: Vector2, o: Vector3) -> void:
	var lim: Rect2 = DtPlan.BOUNDS.grow(4.0)
	var a := Vector2(clampf(a2.x, lim.position.x, lim.end.x), clampf(a2.y, lim.position.y, lim.end.y))
	var b := Vector2(clampf(b2.x, lim.position.x, lim.end.x), clampf(b2.y, lim.position.y, lim.end.y))
	if a.distance_to(b) < 0.5:
		return
	var p: float = DtPlan.P
	var cr: float = DtPlan.CURB_RUN
	var pts := PackedVector3Array()
	for v: Vector2 in [a, b]:
		var top := Vector3(v.x, p, v.y)
		pts.append(top)
		pts.append(top + Vector3(0.0, -0.5, 0.0))
		pts.append(top + o * cr + Vector3(0.0, -p, 0.0))
		pts.append(top + o * cr + Vector3(0.0, -0.5, 0.0))
	DtKit.col_convex(_sb, pts)


## Lane markings, stop lines, zebra crossings and manholes (one batch, lifted off the asphalt).
func _markings(root: Node3D) -> void:
	var bt := DtBatch.new()
	var y: float = 0.012
	var h: float = DtPlan.CITY_HALF
	var rh: float = DtPlan.ROAD_HALF
	# centre lines: a double yellow along every road, broken at the junctions
	for rx: float in DtPlan.OUTER_X:
		var zs: Array[float] = [-h]
		zs.append_array(DtPlan.OUTER_Z)
		zs.append(h)
		for i: int in zs.size() - 1:
			var z0: float = zs[i] + (rh + 4.0 if i > 0 else 0.0)
			var z1: float = zs[i + 1] - (rh + 4.0 if i + 1 < zs.size() - 1 else 0.0)
			if z1 - z0 < 1.0:
				continue
			for dx: float in [-0.12, 0.12]:
				bt.box(Vector3(rx + dx, y, (z0 + z1) * 0.5), Vector3(0.1, 0.004, z1 - z0), LINE_YELLOW)
			# stop lines on the inbound lanes
			if i > 0:
				bt.box(Vector3(rx + DtPlan.LANE * 0.5 + 0.1, y, z0 + 0.4), Vector3(DtPlan.LANE + 0.6, 0.004, 0.4), LINE_WHITE)
			if i + 1 < zs.size() - 1:
				bt.box(Vector3(rx - DtPlan.LANE * 0.5 - 0.1, y, z1 - 0.4), Vector3(DtPlan.LANE + 0.6, 0.004, 0.4), LINE_WHITE)
	for rz: float in DtPlan.OUTER_Z:
		var xs: Array[float] = [-h]
		xs.append_array(DtPlan.OUTER_X)
		xs.append(h)
		for i: int in xs.size() - 1:
			var x0: float = xs[i] + (rh + 4.0 if i > 0 else 0.0)
			var x1: float = xs[i + 1] - (rh + 4.0 if i + 1 < xs.size() - 1 else 0.0)
			if x1 - x0 < 1.0:
				continue
			for dz: float in [-0.12, 0.12]:
				bt.box(Vector3((x0 + x1) * 0.5, y, rz + dz), Vector3(x1 - x0, 0.004, 0.1), LINE_YELLOW)
			if i > 0:
				bt.box(Vector3(x0 + 0.4, y, rz - DtPlan.LANE * 0.5 - 0.1), Vector3(0.4, 0.004, DtPlan.LANE + 0.6), LINE_WHITE)
			if i + 1 < xs.size() - 1:
				bt.box(Vector3(x1 - 0.4, y, rz + DtPlan.LANE * 0.5 + 0.1), Vector3(0.4, 0.004, DtPlan.LANE + 0.6), LINE_WHITE)
	# zebra crossings on all four arms of every junction near the play space
	for rx: float in DtPlan.OUTER_X:
		for rz: float in DtPlan.OUTER_Z:
			if absf(rx) > 160.0 or absf(rz) > 150.0:
				continue
			_zebra(bt, Vector3(rx, y, rz), y)
	# the mid-block crossing on the south street (between the promenade and the transit plaza)
	for i: int in 9:
		bt.box(Vector3(DtPlan.MID_X - 4.0 + float(i), y, DtPlan.Z_S), Vector3(0.55, 0.004, 2.0 * rh - 0.6), LINE_WHITE)
	for s: float in [-1.0, 1.0]:
		bt.box(Vector3(DtPlan.MID_X + s * 6.0, y, DtPlan.Z_S - s * DtPlan.LANE * 0.5), Vector3(0.4, 0.004, DtPlan.LANE + 0.6), LINE_WHITE)
	# manholes and storm grates
	var spots: Array[Vector3] = [
		Vector3(-50.0, 0.0, -10.0), Vector3(50.0, 0.0, 4.0), Vector3(-20.0, 0.0, -44.0), Vector3(24.0, 0.0, 30.0),
		Vector3(-50.0, 0.0, 62.0), Vector3(50.0, 0.0, -20.0), Vector3(-78.0, 0.0, 30.0), Vector3(14.0, 0.0, -44.0),
		Vector3(78.0, 0.0, 30.0), Vector3(-30.0, 0.0, 30.0),
	]
	for s: Vector3 in spots:
		var p := Vector3(s.x + (1.5 if absf(s.x - roundf(s.x / 50.0) * 50.0) < 1.0 else 0.0), y, s.z + (1.5 if absf(s.z - DtPlan.Z_S) < 1.0 or absf(s.z - DtPlan.Z_N) < 1.0 else 0.0))
		bt.cyl(p - Vector3(0.0, 0.006, 0.0), 0.62, 0.008, MANHOLE, 14)
		for k: int in 3:
			bt.box(p + Vector3(0.0, 0.004, -0.3 + 0.3 * float(k)), Vector3(0.9, 0.004, 0.06), Color("2a2c33"))
		grates.append(Vector3(p.x, 0.02, p.z))
	var mi: MeshInstance3D = bt.instance("Markings", false)
	root.add_child(mi)


func _zebra(bt: DtBatch, c: Vector3, y: float) -> void:
	var rh: float = DtPlan.ROAD_HALF
	var near: float = rh + 0.6
	var far: float = rh + 3.6
	var mid: float = (near + far) * 0.5
	for k: int in 11:
		var u: float = -rh + 0.6 + float(k) * 1.08
		bt.box(Vector3(c.x + u, y, c.z - mid), Vector3(0.55, 0.004, far - near), LINE_WHITE)
		bt.box(Vector3(c.x + u, y, c.z + mid), Vector3(0.55, 0.004, far - near), LINE_WHITE)
		bt.box(Vector3(c.x - mid, y, c.z + u), Vector3(far - near, 0.004, 0.55), LINE_WHITE)
		bt.box(Vector3(c.x + mid, y, c.z + u), Vector3(far - near, 0.004, 0.55), LINE_WHITE)


## The traffic: the ring (both ways round the civic block), an L-loop through the outer arms of each corner junction,
## signals at the four junctions and the mid-block crossing.
func _traffic(root: Node3D) -> void:
	traffic = DtTraffic.new()
	traffic.name = "Traffic"
	traffic.seed_value = 23
	root.add_child(traffic)
	var ring := Rect2(DtPlan.X_W, DtPlan.Z_N, DtPlan.X_E - DtPlan.X_W, DtPlan.Z_S - DtPlan.Z_N)
	var paints: Array[Color] = [Color("e8463a"), Color("f2c23a"), Color("2f6fd6"), Color("f4f1ea"), Color("1f2a3a"), Color("3aa66a"), Color("ff8a3d"), Color("8a95a8"), Color("f2c23a")]
	var taxi: Array[Color] = [Color("f6c431")]
	var kinds_city: Array[String] = ["hatch", "hatch", "van", "pickup", "hatch"]
	var l_ccw: int = traffic.add_lane(LanePath.block_loop(ring, 0.0, 9.0, true).offset(DtPlan.LANE), 11.0)
	var l_cw: int = traffic.add_lane(LanePath.block_loop(ring, 0.0, 9.0, false).offset(DtPlan.LANE), 11.0)
	traffic.add_cars(l_ccw, RING_CARS, kinds_city, paints)
	traffic.add_cars(l_cw, RING_CARS - 1, kinds_city, paints)
	traffic.add_cars(l_cw, 1, ["hatch"] as Array[String], taxi)
	var k: int = 0
	for cx: float in [DtPlan.X_W, DtPlan.X_E]:
		for cz: float in [DtPlan.Z_N, DtPlan.Z_S]:
			var lane: int = traffic.add_lane(_corner_loop(cx, cz), 12.0)
			traffic.add_cars(lane, ARM_CARS, kinds_city if k % 2 == 0 else (["hatch", "van", "hatch"] as Array[String]), paints if k != 1 else taxi + paints)
			var it: int = traffic.add_intersection(Vector3(cx, 0.0, cz), 11.0, float(k) * 5.3)
			traffic.add_signal_poles(it)
			k += 1
	var mid: int = traffic.add_intersection(Vector3(DtPlan.MID_X, 0.0, DtPlan.Z_S), 7.0, 3.0)
	var heads := DtCrossingSignal.build(traffic, mid, Vector3(DtPlan.MID_X, 0.0, DtPlan.Z_S))
	root.add_child(heads)
	# a car is ~25 meshes: past CAR_VIEW_END (well into the haze down the avenues) they are not drawn
	for car: TrafficCar in traffic.cars:
		for n: Node in car.find_children("*", "GeometryInstance3D", true, false):
			(n as GeometryInstance3D).visibility_range_end = CAR_VIEW_END


## The L-shaped loop through the two outer arms of the junction (cx, cz): in along the avenue arm, right onto the street
## arm, out to its end and round, back in, left onto the avenue arm, out to its end and round. Right-hand traffic.
static func _corner_loop(cx: float, cz: float) -> LanePath:
	var sx: float = signf(cx)
	var sz: float = signf(cz)
	var ln: float = DtPlan.LANE
	var xi: float = cx + ln * sz
	var zo: float = cz + ln * sx
	var zi: float = cz - ln * sx
	var xo: float = cx - ln * sz
	var pts := PackedVector3Array([
		Vector3(xi, 0.0, cz + sz * ARM), Vector3(xi, 0.0, zo), Vector3(cx + sx * ARM, 0.0, zo),
		Vector3(cx + sx * ARM, 0.0, zi), Vector3(xo, 0.0, zi), Vector3(xo, 0.0, cz + sz * ARM),
	])
	return LanePath.from_points(pts, true, 4.0)
