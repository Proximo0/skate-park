class_name WhOutdoor
extends RefCounted
## The outdoor areas of the Creepy Warehouse: the ground (slabs with holes for the truck well, the pit and the raised
## hall slab), the raised slab itself, the south LOADING DOCKS and truck court, the east CONTAINER YARD, the north RAIL
## SPUR and the west BOILER YARD, plus the perimeter fence. Coordinates are world space (the level sits at the origin).

const FL: float = WarehouseLevel.FL
const ASPHALT := Color("3c3f48")
const RAIL_ASPHALT := Color("34363d")
const YARD := Color("4b4f56")
const BOILER := Color("474a50")
const BALLAST := Color("4b4642")
const DOCK_TOP := Color("65676c")
const DOCK_FACE := Color("75736d")
const STEEL := Color("5c6068")
const SAFETY := Color("e3b324")
const PLY := Color("b48a5a")
const RUBBER := Color("222226")
const CONTAINER_LEN: float = 6.15
const CONTAINER_W: float = 2.494
const CONTAINER_H: float = 2.615
## Spur track (along x, by the north dock) and the main line further north.
const SPUR_Z: float = -31.0
const MAIN_Z: float = -58.0
const GAUGE: float = 1.435
const RAIL_TOP: float = 0.16


static func build(lvl: WarehouseLevel) -> void:
	_ground(lvl)
	_slab(lvl)
	_docks(lvl)
	_truck_well(lvl)
	_truck_court(lvl)
	_yard(lvl)
	_rail(lvl)
	_boiler(lvl)
	_fence(lvl)


# ------------------------------------------------------------------------------------------------------------- ground

## Ground slabs at grade round the raised hall slab, the well, the pit and the annex; asphalt in the truck court and by
## the tracks (ballast strips under the rails), concrete in the yards. Collision boxes are 1 m deep; visuals are top
## quads in 24 m tiles (merged per material), so lights stay local.
static func _ground(lvl: WarehouseLevel) -> void:
	var outer: Rect2 = lvl.bounds.grow(26.0)
	var pit := Rect2(WarehouseLevel.PIT_POS.x, WarehouseLevel.PIT_POS.z, WarehouseLevel.PIT_SIZE.x, WarehouseLevel.PIT_SIZE.y)
	var holes: Array[Rect2] = [WarehouseLevel.SLAB, WarehouseLevel.WELL, pit, WarehouseLevel.ANNEX]
	var cuts_z: Array[float] = [SPUR_Z - 1.7, SPUR_Z + 1.7, MAIN_Z - 1.7, MAIN_Z + 1.7, -26.0, 26.0]
	var cuts_x: Array[float] = [-40.5, 40.5, 50.0, 0.0, -48.0, 48.0]
	for x: float in range(-120, 121, 24):
		cuts_x.append(float(x))
	var rects: Array[Rect2] = WhGeo.cut_rects(outer, holes, cuts_x, cuts_z)
	var sb: StaticBody3D = WhGeo.body(lvl, "Ground")
	var bt := WhGeo.Batch.new(48.0, false)
	var m_asph: ShaderMaterial = WorldSurface.material("asphalt", ASPHALT)
	var m_rail: ShaderMaterial = m_asph  # one asphalt material: fewer merged meshes
	var m_yard: ShaderMaterial = WorldSurface.material("concrete", YARD, 1.5)
	var m_boil: ShaderMaterial = m_yard
	var m_ballast: ShaderMaterial = WorldSurface.material("asphalt", BALLAST, 0.25)
	for r: Rect2 in rects:
		var c: Vector2 = r.get_center()
		var m: Material = m_yard
		if absf(c.y - SPUR_Z) < 1.7 and c.x < 52.0 or absf(c.y - MAIN_Z) < 1.7:
			m = m_ballast
		elif c.y > 26.0:
			m = m_asph
		elif c.y < -26.0:
			m = m_rail
		elif c.x < -40.5:
			m = m_boil
		WhGeo.solid_min(sb, Vector3(r.position.x, -1.0, r.position.y), Vector3(r.size.x, 1.0, r.size.y))
		bt.quad(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.position.x, 0.0, r.end.y), Vector3(r.end.x, 0.0, r.end.y), Vector3(r.position.x + r.size.x, 0.0, r.position.y), m)
	bt.commit(lvl, "GroundMesh")
	lvl.add_backdrop("asphalt", Color("2c2e34"), 3000.0, -0.08)


# ----------------------------------------------------------------------------------------------------------- the slab

## The raised hall slab (top FL): hall floor plus the north rail dock and the south dock apron, notched where the truck
## well's quarter pipe takes over the dock edge. Faces are cast concrete, the dock tops plain concrete, the hall floor
## power-floated concrete.
static func _slab(lvl: WarehouseLevel) -> void:
	var sb: StaticBody3D = WhGeo.body(lvl, "Slab")
	var bt := WhGeo.Batch.new(24.0, false)
	var face := WhGeo.mat("concrete", DOCK_FACE, 0.7, 0.8, Color(0, 0, 0, 0), 1.0, -1.0)
	var dock := WorldSurface.material("concrete", DOCK_TOP, 0.75)
	var floor_m := WhGeo.mat("floor", Color("6a6b70"), 0.8, 0.8)
	var rects: Array = [
		[Rect2(-40.5, -20.5, 81.0, 41.0), floor_m],
		[Rect2(-40.5, -26.0, 81.0, 5.5), dock],
		[Rect2(-40.5, 20.5, 34.5, 5.5), dock],
		[Rect2(-6.0, 20.5, 12.0, 5.2), dock],
		[Rect2(6.0, 20.5, 34.5, 5.5), dock],
	]
	for e: Array in rects:
		var r: Rect2 = e[0]
		WhGeo.solid_min(sb, Vector3(r.position.x, -1.0, r.position.y), Vector3(r.size.x, FL + 1.0, r.size.y))
		# the top stops 0.1 short of an open dock edge, where the steel edge angle sits
		var top: Rect2 = r
		if r.position.y < -25.9:
			top = Rect2(r.position.x, r.position.y + 0.1, r.size.x, r.size.y - 0.1)
		elif r.end.y > 25.9:
			top = Rect2(r.position.x, r.position.y, r.size.x, r.size.y - 0.1)
		bt.quad(Vector3(top.position.x, FL, top.position.y), Vector3(top.position.x, FL, top.end.y), Vector3(top.end.x, FL, top.end.y), Vector3(top.end.x, FL, top.position.y), e[1] as Material)
	# open faces: north dock edge, south dock edges either side of the well, and the slab ends
	_face_z(bt, -40.5, 40.5, -26.0, -1.0, FL, -1.0, face)
	_face_z(bt, -40.5, -6.0, 26.0, -1.0, FL, 1.0, face)
	_face_z(bt, 6.0, 40.5, 26.0, -1.0, FL, 1.0, face)
	_face_x(bt, -26.0, 26.0, -40.5, -1.0, FL, -1.0, face)
	_face_x(bt, -26.0, 26.0, 40.5, -1.0, FL, 1.0, face)
	# steel edge angles along the open dock edges (visual) and their grind lines
	var steel := WhGeo.mat("rust", STEEL, 0.6, 0.2)
	bt.box_min(Vector3(-40.5, FL - 0.14, -26.02), Vector3(81.0, 0.14, 0.12), steel)
	bt.box_min(Vector3(-40.5, FL - 0.14, 25.9), Vector3(34.5, 0.14, 0.12), steel)
	bt.box_min(Vector3(6.0, FL - 0.14, 25.9), Vector3(34.5, 0.14, 0.12), steel)
	bt.box_min(Vector3(-6.0, FL - 0.14, 25.6), Vector3(12.0, 0.14, 0.1), steel)
	bt.commit(lvl, "SlabMesh")
	WhGeo.grind(lvl, PackedVector3Array([Vector3(-40.5, FL, -26.0), Vector3(40.5, FL, -26.0)]), "ledge", "RailDockEdge")
	WhGeo.grind(lvl, PackedVector3Array([Vector3(-40.5, FL, 26.0), Vector3(-6.0, FL, 26.0)]), "ledge", "DockEdgeWest")
	WhGeo.grind(lvl, PackedVector3Array([Vector3(6.0, FL, 26.0), Vector3(40.5, FL, 26.0)]), "ledge", "DockEdgeEast")


## A vertical face at z from x0..x1, y0..y1, facing +Z (dir 1) or -Z (dir -1).
static func _face_z(bt: WhGeo.Batch, x0: float, x1: float, z: float, y0: float, y1: float, dir: float, m: Material) -> void:
	if dir > 0.0:
		bt.quad(Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), m)
	else:
		bt.quad(Vector3(x1, y0, z), Vector3(x0, y0, z), Vector3(x0, y1, z), Vector3(x1, y1, z), m)


static func _face_x(bt: WhGeo.Batch, z0: float, z1: float, x: float, y0: float, y1: float, dir: float, m: Material) -> void:
	if dir > 0.0:
		bt.quad(Vector3(x, y0, z1), Vector3(x, y0, z0), Vector3(x, y1, z0), Vector3(x, y1, z1), m)
	else:
		bt.quad(Vector3(x, y0, z0), Vector3(x, y0, z1), Vector3(x, y1, z1), Vector3(x, y1, z0), m)


## A solid ramp (wedge) over the footprint `r` rising from `low` to `high`: `up` is the rising direction (one of
## +-X, +-Z). Collision is a convex hull that reaches 0.3 m under grade; the visual is its top and two sides.
static func wedge(sb: StaticBody3D, bt: WhGeo.Batch, r: Rect2, low: float, high: float, up: Vector3, top_m: Material, side_m: Material) -> void:
	var x0: float = r.position.x
	var x1: float = r.end.x
	var z0: float = r.position.y
	var z1: float = r.end.y
	var hy := func(x: float, z: float) -> float:
		var t: float = 0.0
		if up.x > 0.5:
			t = (x - x0) / (x1 - x0)
		elif up.x < -0.5:
			t = (x1 - x) / (x1 - x0)
		elif up.z > 0.5:
			t = (z - z0) / (z1 - z0)
		else:
			t = (z1 - z) / (z1 - z0)
		return lerpf(low, high, t)
	var base: float = minf(low, 0.0) - 0.3
	var c: Array[Vector3] = [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]
	var pts := PackedVector3Array()
	for p: Vector3 in c:
		pts.append(Vector3(p.x, base, p.z))
		pts.append(Vector3(p.x, hy.call(p.x, p.z), p.z))
	WhGeo.hull(sb, pts)
	var t0 := Vector3(x0, hy.call(x0, z0), z0)
	var t1 := Vector3(x1, hy.call(x1, z0), z0)
	var t2 := Vector3(x1, hy.call(x1, z1), z1)
	var t3 := Vector3(x0, hy.call(x0, z1), z1)
	bt.quad(t0, t3, t2, t1, top_m)
	# sides (the faces along the rise) down to grade
	var g: float = minf(low, 0.0)
	if absf(up.x) > 0.5:
		bt.quad(Vector3(x0, g, z0), t0, t1, Vector3(x1, g, z0), side_m)
		bt.quad(Vector3(x1, g, z1), t2, t3, Vector3(x0, g, z1), side_m)
		var hx: float = x1 if up.x > 0.0 else x0
		var hs: float = 1.0 if up.x > 0.0 else -1.0
		_face_x(bt, z0, z1, hx, g, high, hs, side_m)
	else:
		bt.quad(Vector3(x0, g, z1), t3, t0, Vector3(x0, g, z0), side_m)
		bt.quad(Vector3(x1, g, z0), t1, t2, Vector3(x1, g, z1), side_m)
		var hz: float = z1 if up.z > 0.0 else z0
		var hs2: float = 1.0 if up.z > 0.0 else -1.0
		_face_z(bt, x0, x1, hz, g, high, hs2, side_m)


# ---------------------------------------------------------------------------------------------------------- the docks

static func _docks(lvl: WarehouseLevel) -> void:
	var sb: StaticBody3D = WhGeo.body(lvl, "Docks")
	var bt := WhGeo.Batch.new(24.0)
	var ramp_top := WorldSurface.material("concrete", Color("6f7074"), 0.6)
	var ramp_side := WhGeo.mat("concrete", DOCK_FACE, 0.6, 0.8)
	# ramps down from the dock aprons at both ends, north and south, and from the west and east doors
	wedge(sb, bt, Rect2(-48.5, 20.5, 8.0, 5.5), 0.0, FL, Vector3.RIGHT, ramp_top, ramp_side)
	wedge(sb, bt, Rect2(40.5, 20.5, 8.0, 5.5), 0.0, FL, Vector3.LEFT, ramp_top, ramp_side)
	wedge(sb, bt, Rect2(-48.5, -26.0, 8.0, 5.5), 0.0, FL, Vector3.RIGHT, ramp_top, ramp_side)
	wedge(sb, bt, Rect2(40.5, -26.0, 8.0, 5.5), 0.0, FL, Vector3.LEFT, ramp_top, ramp_side)
	wedge(sb, bt, Rect2(-48.5, -17.0, 8.0, 6.0), 0.0, FL, Vector3.RIGHT, ramp_top, ramp_side)
	wedge(sb, bt, Rect2(40.5, -6.0, 8.0, 12.0), 0.0, FL, Vector3.LEFT, ramp_top, ramp_side)
	# yellow kerb paint along the ramp sides
	var paint := WhGeo.mat("paint", SAFETY, 0.6, 0.0, Color("3a3430"))
	for r: Rect2 in [Rect2(-48.5, 20.5, 8.0, 5.5), Rect2(40.5, 20.5, 8.0, 5.5), Rect2(-48.5, -26.0, 8.0, 5.5), Rect2(40.5, -26.0, 8.0, 5.5)]:
		bt.box_min(Vector3(r.position.x, 0.0, r.position.y - 0.02), Vector3(r.size.x, 0.05, 0.04), paint)
	# rubber dock bumpers on the south and north faces (visual) and a yellow stripe under each dock lip
	var rub := WhGeo.mat("paint", RUBBER, 0.1, 0.4, Color("111111"))
	for x: float in [-37.0, -33.0, -27.5, -20.5, -12.5, -9.5, 9.5, 12.5, 20.5, 27.5, 33.0, 37.0]:
		bt.box_min(Vector3(x - 0.25, FL - 0.95, 26.0), Vector3(0.5, 0.75, 0.22), rub)
		bt.box_min(Vector3(x - 0.25, FL - 0.95, -26.22), Vector3(0.5, 0.75, 0.22), rub)
	for seg: Vector2 in [Vector2(-40.5, -6.0), Vector2(6.0, 40.5)]:
		for i: int in int((seg.y - seg.x) / 1.2):
			var x0: float = seg.x + float(i) * 1.2
			if i % 2 == 0:
				bt.box_min(Vector3(x0, FL - 0.32, 26.0), Vector3(0.6, 0.16, 0.015), paint)
	# dock stairs west of the well: five steps down to the court with a handrail
	var stairs: Node3D = StairSet.build(4.0, 0.01, 5, 0.24, 0.45, "dock_stair")
	WhGeo.reskin(stairs, WorldSurface.material("concrete", Color("7d7c78"), 0.5))
	lvl.put(stairs, Vector3(-20.0, 0.0, 26.0), 0.0, "DockStairs")
	lvl.add_child(PieceKit.gap_zone("dock_stair_air", Vector3(-20.0, FL + 0.3, 25.7), Vector3(4.0, 2.5, 1.0)))
	lvl.add_child(PieceKit.gap_zone("dock_stair_land", Vector3(-20.0, 0.0, 28.4), Vector3(4.0, 1.6, 4.0)))
	# a plywood bank up onto the dock east of the well
	var bank: Node3D = Walls.bank(5.0, 4.0, FL, "")
	WhGeo.reskin(bank, WhGeo.mat("plywood", PLY, 0.5, 0.2))
	lvl.put(bank, Vector3(12.0, 0.0, 26.0), 0.0, "DockBank")
	bt.commit(lvl, "DockMesh")


## The drained truck well: a ramp dips from grade to WELL_FLOOR, then a concrete quarter pipe climbs to the dock edge
## (the coping is the dock lip). Retaining walls each side carry yellow guard rails (grindable).
static func _truck_well(lvl: WarehouseLevel) -> void:
	var w: Rect2 = WarehouseLevel.WELL
	var sb: StaticBody3D = WhGeo.body(lvl, "TruckWell")
	var bt := WhGeo.Batch.new()
	var conc := WhGeo.mat("concrete", Color("878580"), 0.8, 0.6, Color(0, 0, 0, 0), 1.0, WarehouseLevel.WELL_FLOOR)
	var floor_m := WorldSurface.material("concrete", Color("5f6064"), 0.7)
	var h: float = FL - WarehouseLevel.WELL_FLOOR
	var qp: Node3D = QuarterPipe.build(w.size.x, h, h, 0.3)
	WhGeo.reskin(qp, WorldSurface.material("concrete", Color("7b7c80"), 0.5))
	lvl.put(qp, Vector3(w.position.x, WarehouseLevel.WELL_FLOOR, 25.7), 0.0, "WellQuarter")
	var qp_end: float = 25.7 + 0.3 + h  # foot of the transition
	# floor and the slope back up to grade (solid down to 1.6 under grade)
	var flat_end: float = qp_end + 2.3
	var x0: float = w.position.x + 0.4
	var x1: float = w.end.x - 0.4
	var prof := PackedVector3Array([
		Vector3(x0, WarehouseLevel.WELL_FLOOR, qp_end), Vector3(x1, WarehouseLevel.WELL_FLOOR, qp_end),
		Vector3(x0, WarehouseLevel.WELL_FLOOR, flat_end), Vector3(x1, WarehouseLevel.WELL_FLOOR, flat_end),
		Vector3(x0, 0.0, w.end.y), Vector3(x1, 0.0, w.end.y),
		Vector3(x0, -1.8, qp_end), Vector3(x1, -1.8, qp_end), Vector3(x0, -1.8, w.end.y), Vector3(x1, -1.8, w.end.y),
	])
	WhGeo.hull(sb, prof)
	bt.quad(Vector3(x0, WarehouseLevel.WELL_FLOOR, qp_end), Vector3(x0, WarehouseLevel.WELL_FLOOR, flat_end), Vector3(x1, WarehouseLevel.WELL_FLOOR, flat_end), Vector3(x1, WarehouseLevel.WELL_FLOOR, qp_end), floor_m)
	bt.quad(Vector3(x0, WarehouseLevel.WELL_FLOOR, flat_end), Vector3(x0, 0.0, w.end.y), Vector3(x1, 0.0, w.end.y), Vector3(x1, WarehouseLevel.WELL_FLOOR, flat_end), floor_m)
	# retaining walls (their tops are flush with grade) and the quarter pipe's side cheeks
	for wx: float in [w.position.x, x1]:
		WhGeo.block(bt, sb, Vector3(wx, -1.8, qp_end - 2.5), Vector3(0.4, 1.8, w.end.y - qp_end + 2.5), conc)
	# yellow guard rails on the walls (grind lines on top)
	var paint := WhGeo.mat("paint", SAFETY, 0.5, 0.0, Color("4a3a2a"))
	for rx: float in [w.position.x + 0.2, w.end.x - 0.2]:
		var a := Vector3(rx, 1.0, 26.6)
		var b := Vector3(rx, 1.0, 34.0)
		bt.pipe(a, b, 0.045, paint)
		for z: float in [26.8, 30.4, 33.8]:
			bt.pipe(Vector3(rx, 0.0, z), Vector3(rx, 1.0, z), 0.04, paint)
		WhGeo.grind(lvl, PackedVector3Array([a, b]), "rail", "WellRail")
	# drain grate and a dark puddle at the bottom
	bt.box_min(Vector3(-1.5, WarehouseLevel.WELL_FLOOR + 0.004, qp_end + 0.6), Vector3(3.0, 0.01, 0.5), WhGeo.mat("rust", Color("2e2f33"), 0.5, 0.0))
	bt.commit(lvl, "TruckWellMesh")
	# gap zones: the lip (any state) and high above it (Truck Well Air); the kicker over the west rim into the far half (Truck Well Hop)
	lvl.add_child(PieceKit.gap_zone("well_lip", Vector3(w.position.x, FL - 0.3, 25.9), Vector3(w.size.x, 1.3, 1.1)))
	lvl.add_child(PieceKit.gap_zone("well_high", Vector3(w.position.x, FL + 1.6, 25.4), Vector3(w.size.x, 5.0, 2.2)))
	lvl.add_child(PieceKit.gap_zone("well_w", Vector3(-8.2, 0.3, 29.0), Vector3(2.0, 3.0, 7.0)))
	lvl.add_child(PieceKit.gap_zone("well_e", Vector3(1.0, -1.2, 26.0), Vector3(5.4, 6.5, 12.5)))  # the far half of the well
	# a kicker at the west rim to clear the well
	var kick: Node3D = Kicker.build(3.0, 3.2, 1.4)
	WhGeo.reskin(kick, WhGeo.mat("plywood", PLY, 0.5, 0.2))
	lvl.put(kick, Vector3(-8.0, 0.0, 34.0), -90.0, "WellKicker")


# ----------------------------------------------------------------------------------------------------- the truck court

static func _truck_court(lvl: WarehouseLevel) -> void:
	var sb: StaticBody3D = WhGeo.body(lvl, "Court")
	var bt := WhGeo.Batch.new(32.0)
	var k: LevelKit = lvl.kit()
	# a box trailer backed up to the west bays (solid), and a flatbed at the east bays you can ride
	WhProps.box_trailer(bt, sb, Vector3(-30.7, 0.0, 26.0), Color("8e9aa3"))
	lvl.add_child(WhGeo.tag("throw_bonz", 5.0, Vector3(-32.03, 2.7, 33.0), -90.0))
	lvl.add_child(WhGeo.tag("tag_drip", 3.0, Vector3(-29.37, 2.4, 35.5), 90.0))
	WhProps.flatbed(lvl, bt, sb, Vector3(24.0, 0.0, 26.0))  # centred on the east dock door: flatbed -> dock -> hall
	# the DIY ramp up onto the flatbed's tail
	var ply := WhGeo.mat("plywood", PLY, 0.5, 0.2)
	wedge(sb, bt, Rect2(22.75, 39.0, 2.5, 6.0), 0.0, 1.45, Vector3.FORWARD, ply, ply)
	lvl.add_child(PieceKit.gap_zone("flatbed_tail", Vector3(22.75, 1.5, 26.0), Vector3(2.5, 2.5, 1.0)))
	lvl.add_child(PieceKit.gap_zone("flatbed_dock", Vector3(22.25, FL + 0.05, 21.8), Vector3(3.5, 2.5, 3.6)))
	# jersey barriers in a row: one long grind
	var jb := WhGeo.mat("concrete", Color("a9a59c"), 0.6, 0.5)
	for i: int in 4:
		var x0: float = -27.0 + float(i) * 3.6
		WhProps.jersey(bt, Vector3(x0 + 1.75, 0.0, 46.0), 3.5, jb)
	WhGeo.solid_min(sb, Vector3(-27.0, -0.5, 45.7), Vector3(14.3, 1.31, 0.6))
	WhGeo.grind(lvl, PackedVector3Array([Vector3(-27.0, 0.81, 46.0), Vector3(-12.7, 0.81, 46.0)]), "ledge", "JerseyLedge")
	# dumpsters by the east bays, a guard booth by the gate, oil drums and pallets
	for d: Array in [[Vector3(36.5, 0.0, 30.0), 90.0, "tag_flux"], [Vector3(36.5, 0.0, 33.5), 90.0, ""]]:
		var dump: StaticBody3D = ParkDressing.dumpster(Color("2f5d4a"), str(d[2]))
		dump.position = d[0] as Vector3
		dump.rotation_degrees.y = float(d[1])
		lvl.add_child(dump)
	WhProps.guard_booth(lvl, bt, sb, Vector3(-58.0, 0.0, 62.0))
	var drums: Array[Transform3D] = []
	for p: Vector3 in [Vector3(-36.0, 0, 41.0), Vector3(-35.3, 0, 41.6), Vector3(-36.2, 0, 42.3), Vector3(38.5, 0, 40.0), Vector3(39.1, 0, 40.6)]:
		drums.append(Transform3D(Basis(Vector3.UP, p.x * 0.7), p))
	WhGeo.kit_multi(lvl, k, "oil_drum", drums, "CourtDrums", {}, false)
	for t: Transform3D in drums:
		WhGeo.kit_solids(sb, k, "oil_drum", t)
	var pallets: Array[Transform3D] = [Transform3D(WhGeo.yaw(8.0), Vector3(-44.0, 0.0, 30.0)), Transform3D(WhGeo.yaw(-4.0), Vector3(-44.2, 0.0, 31.4)),
		Transform3D(WhGeo.yaw(85.0), Vector3(44.0, 0.0, 44.0))]
	WhGeo.kit_multi(lvl, k, "pallet_stack", pallets, "CourtPallets", {}, false)
	for t: Transform3D in pallets:
		WhGeo.kit_solids(sb, k, "pallet_stack", t)
	# the guard's old car, parked by the booth
	var car: CarModel = CarModel.create("hatch", Color("5b6f80"))
	car.position = Vector3(-50.0, 0.0, 64.5)
	car.rotation_degrees.y = 95.0
	lvl.add_child(car)
	WhGeo.solid(sb, Vector3(-50.0, 0.75, 64.5), Vector3(4.2, 1.5, 1.9), WhGeo.yaw(95.0))
	# parking bay lines on the asphalt (visual)
	var line := WhGeo.mat("paint", Color(0.7, 0.68, 0.58), 0.7, 0.0)
	for i: int in 9:
		var x: float = -38.0 + float(i) * 9.5
		if absf(x) < 8.0:
			continue
		bt.box_min(Vector3(x, 0.0, 40.0), Vector3(0.14, 0.012, 9.0), line)
	bt.commit(lvl, "CourtMesh")


# ------------------------------------------------------------------------------------------------- the container yard

## Container runs under a gantry crane: row A climbs from a steel ramp, gaps to row B and drops back to grade; row D in
## the south-east is a kicker-launched hop; row C is a two-high wallride wall; stacks wall the yard in.
static func _yard(lvl: WarehouseLevel) -> void:
	var sb: StaticBody3D = WhGeo.body(lvl, "Yard")
	var bt := WhGeo.Batch.new(32.0)
	var cs: Dictionary = {}  ## colour name -> Array[Transform3D]
	# row A and row B along z at x = 62
	var ax: float = 62.0
	for zc: float in [-3.075, -9.225, -15.375]:
		_container(cs, sb, Vector3(ax, 0.0, zc), true, ["red", "teal", "blue"][int(absf(zc)) % 3])
	for zc: float in [-26.525, -32.675, -38.825]:
		_container(cs, sb, Vector3(ax, 0.0, zc), true, ["orange", "red", "grey"][int(absf(zc)) % 3])
	var hw: float = CONTAINER_W * 0.5
	var plate := WhGeo.mat("rust", Color("5e5a55"), 0.8, 0.3)
	wedge(sb, bt, Rect2(ax - hw, 0.0, CONTAINER_W, 10.0), 0.0, CONTAINER_H, Vector3.FORWARD, plate, plate)
	wedge(sb, bt, Rect2(ax - hw, -49.9, CONTAINER_W, 8.0), 0.0, CONTAINER_H, Vector3.BACK, plate, plate)
	for x: float in [ax - hw, ax + hw]:
		WhGeo.grind(lvl, PackedVector3Array([Vector3(x, CONTAINER_H, 0.0), Vector3(x, CONTAINER_H, -18.45)]), "ledge", "RowAEdge")
		WhGeo.grind(lvl, PackedVector3Array([Vector3(x, CONTAINER_H, -23.45), Vector3(x, CONTAINER_H, -41.9)]), "ledge", "RowBEdge")
	lvl.add_child(PieceKit.gap_zone("cont_a", Vector3(ax - 1.6, 1.4, -21.0), Vector3(3.2, 5.0, 2.4)))
	lvl.add_child(PieceKit.gap_zone("cont_b", Vector3(ax - 1.6, 2.0, -24.6), Vector3(3.2, 4.5, 1.25)))
	# row D: the container hop (ridden north from the south-east)
	var dx: float = 80.0
	_container(cs, sb, Vector3(dx, 0.0, 44.925), true, "blue")
	_container(cs, sb, Vector3(dx, 0.0, 34.925), true, "red")
	wedge(sb, bt, Rect2(dx - hw, 48.0, CONTAINER_W, 10.0), 0.0, CONTAINER_H, Vector3.FORWARD, plate, plate)
	for x: float in [dx - hw, dx + hw]:
		WhGeo.grind(lvl, PackedVector3Array([Vector3(x, CONTAINER_H, 48.0), Vector3(x, CONTAINER_H, 41.85)]), "ledge", "HopEdgeA")
		WhGeo.grind(lvl, PackedVector3Array([Vector3(x, CONTAINER_H, 38.0), Vector3(x, CONTAINER_H, 31.85)]), "ledge", "HopEdgeB")
	lvl.add_child(PieceKit.gap_zone("hop_a", Vector3(dx - 1.6, 1.4, 39.6), Vector3(3.2, 5.0, 2.0)))
	lvl.add_child(PieceKit.gap_zone("hop_b", Vector3(dx - 1.6, 2.0, 37.5), Vector3(3.2, 4.5, 1.1)))
	# row C: a two-high wall facing the lane (wallride face at x = 70.75)
	var colours: Array[String] = ["grey", "red", "teal", "orange", "blue", "red", "white", "teal"]
	for i: int in 8:
		var zc: float = 9.2 - CONTAINER_LEN * 0.5 - float(i) * CONTAINER_LEN
		_container(cs, sb, Vector3(72.0, 0.0, zc), true, colours[i])
		_container(cs, sb, Vector3(72.0, CONTAINER_H, zc), true, colours[(i + 3) % 8])
	lvl.add_child(PieceKit.gap_zone("cwall_a", Vector3(69.6, 0.8, -6.0), Vector3(1.15, 3.2, 3.0)))
	lvl.add_child(PieceKit.gap_zone("cwall_b", Vector3(69.6, 0.8, -15.0), Vector3(1.15, 3.2, 3.0)))
	# stacks round the edge of the yard (two and three high), crosswise in the north-east
	var z: float = -70.0
	var n: int = 0
	while z < 66.0:
		var high: int = 3 if n % 3 == 0 else 2
		if true:
			for lvl_i: int in high:
				_container(cs, sb, Vector3(92.5, float(lvl_i) * CONTAINER_H, z + CONTAINER_LEN * 0.5), true, colours[(n + lvl_i * 3) % 8])
		z += CONTAINER_LEN + (0.3 if n % 4 != 3 else 3.0)
		n += 1
	for i: int in 4:
		var xc: float = 55.0 + float(i) * 6.6
		for lvl_i: int in 2:
			_container(cs, sb, Vector3(xc, float(lvl_i) * CONTAINER_H, -73.0), false, colours[(i * 2 + lvl_i) % 8])
	# a couple of loose ones at angles by the dock ramp
	_container(cs, sb, Vector3(56.0, 0.0, 30.0), false, "white", 12.0)
	_container(cs, sb, Vector3(58.5, 0.0, 66.0), false, "teal", -6.0)
	# the south-east lot: a stack waiting by the gate, one box knocked askew
	_container(cs, sb, Vector3(46.0, 0.0, 63.5), false, "red")
	_container(cs, sb, Vector3(46.0, CONTAINER_H, 63.5), false, "grey")
	_container(cs, sb, Vector3(46.0, 0.0, 66.1), false, "blue")
	_container(cs, sb, Vector3(52.4, 0.0, 66.1), false, "orange")
	_container(cs, sb, Vector3(46.4, CONTAINER_H, 66.2), false, "teal", 7.0)
	_container(cs, sb, Vector3(40.0, 0.0, 70.5), false, "white", 4.0)
	# the south-west lot behind the guard booth: a two-high pair, a dead trailer and a stack by the tanks
	_container(cs, sb, Vector3(-90.0, 0.0, 47.0), true, "grey")
	_container(cs, sb, Vector3(-90.0, CONTAINER_H, 47.0), true, "red")
	_container(cs, sb, Vector3(-87.2, 0.0, 47.6), true, "teal", -5.0)
	_container(cs, sb, Vector3(-72.0, 0.0, 69.0), false, "orange")
	_container(cs, sb, Vector3(-72.0, CONTAINER_H, 69.0), false, "white")
	_container(cs, sb, Vector3(-65.6, 0.0, 69.4), false, "blue", -3.0)
	WhProps.box_trailer(bt, sb, Vector3(-80.0, 0.0, 56.0), Color("6d7a6f"))
	lvl.add_child(WhGeo.tag("throw_bonz", 4.0, Vector3(-81.33, 2.6, 62.0), -90.0))
	_container_meshes(lvl, cs)
	WhProps.gantry_crane(lvl, bt, sb, Vector3(62.25, 0.0, -21.0))
	# drums and pallets
	var k: LevelKit = lvl.kit()
	var drums: Array[Transform3D] = []
	for p: Vector3 in [Vector3(67.5, 0, 12.0), Vector3(68.1, 0, 12.5), Vector3(67.4, 0, 13.2), Vector3(54.0, 0, -45.0), Vector3(54.7, 0, -44.6)]:
		drums.append(Transform3D(Basis(Vector3.UP, p.z), p))
	WhGeo.kit_multi(lvl, k, "oil_drum", drums, "YardDrums", {}, false)
	for t: Transform3D in drums:
		WhGeo.kit_solids(sb, k, "oil_drum", t)
	bt.commit(lvl, "YardMesh")


const CONTAINER_COLOURS: Dictionary = {
	"red": Color("8f3b2f"), "blue": Color("2f4f74"), "teal": Color("2f6a66"), "orange": Color("a85d26"),
	"grey": Color("5d6166"), "white": Color("807d75"),
}


## Records a container (footprint centre `c` at base height c.y; along z when `along_z`) and its collision box.
static func _container(cs: Dictionary, sb: StaticBody3D, c: Vector3, along_z: bool, colour: String, extra_yaw: float = 0.0) -> void:
	var yaw_deg: float = (90.0 if along_z else 0.0) + extra_yaw
	var b: Basis = WhGeo.yaw(yaw_deg)
	var origin: Vector3 = c - b * Vector3(0.035, 0.0, 0.0)
	if not cs.has(colour):
		var fresh: Array[Transform3D] = []
		cs[colour] = fresh
	var list: Array[Transform3D] = cs[colour]
	list.append(Transform3D(b, origin))
	WhGeo.solid(sb, c + Vector3(0.0, CONTAINER_H * 0.5, 0.0), Vector3(CONTAINER_LEN, CONTAINER_H, CONTAINER_W), b)


static func _container_meshes(lvl: WarehouseLevel, cs: Dictionary) -> void:
	var k: LevelKit = lvl.kit()
	for colour: String in cs:
		var body_m: Material = WhGeo.mat("metal", CONTAINER_COLOURS[colour] as Color, 0.75, 0.5, Color("5a2e1c"), 1.0, 0.0)
		var steel_m: Material = WhGeo.mat("rust", Color("4a4c50"), 0.7, 0.2)
		WhGeo.kit_multi(lvl, k, "container_red", cs[colour] as Array[Transform3D], "Containers_" + colour,
				{"container_red": body_m, "steel_dark": steel_m, "steel": steel_m})


# ---------------------------------------------------------------------------------------------------- the rail spur

static func _rail(lvl: WarehouseLevel) -> void:
	var sb: StaticBody3D = WhGeo.body(lvl, "Rail")
	var bt := WhGeo.Batch.new(32.0)
	var steel := WhGeo.mat("rust", Color("6d6a66"), 0.9, 0.0)
	var sleepers: Array[Transform3D] = []
	for track: Vector3 in [Vector3(-94.0, 50.0, SPUR_Z), Vector3(-120.0, 120.0, MAIN_Z)]:
		var x0: float = track.x
		var x1: float = track.y
		var tz: float = track.z
		for s: float in [-1.0, 1.0]:
			var rz: float = tz + s * GAUGE * 0.5
			bt.box_min(Vector3(x0, 0.04, rz - 0.04), Vector3(x1 - x0, RAIL_TOP - 0.04, 0.08), steel)
			var gx0: float = maxf(x0, -95.5)
			var gx1: float = minf(x1, 95.5)
			WhGeo.grind(lvl, PackedVector3Array([Vector3(gx0, RAIL_TOP, rz), Vector3(gx1, RAIL_TOP, rz)]), "rail", "TrackRail")
		var x: float = x0 + 0.3
		while x < x1:
			sleepers.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.02, tz)))
			x += 0.7
	var sl := BoxMesh.new()
	sl.size = Vector3(0.24, 0.06, 2.5)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sl
	mm.instance_count = sleepers.size()
	for i: int in sleepers.size():
		mm.set_instance_transform(i, sleepers[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Sleepers"
	mmi.multimesh = mm
	mmi.material_override = WhGeo.mat("plywood", Color("3d322b"), 0.3, 0.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lvl.add_child(mmi)
	# buffer stop at the spur's east end
	WhGeo.block(bt, sb, Vector3(50.0, 0.0, SPUR_Z - 1.4), Vector3(0.8, 1.3, 2.8), WhGeo.mat("paint", Color("a33a2b"), 0.7, 0.3))
	bt.box_min(Vector3(49.6, 0.75, SPUR_Z - 1.1), Vector3(0.4, 0.3, 0.3), WhGeo.mat("paint", SAFETY, 0.5, 0.0))
	bt.box_min(Vector3(49.6, 0.75, SPUR_Z + 0.8), Vector3(0.4, 0.3, 0.3), WhGeo.mat("paint", SAFETY, 0.5, 0.0))
	# the parked train on the spur: boxcar, flatcar, gondola, boxcar
	WhProps.boxcar(lvl, bt, sb, Vector3(-30.0, 0.0, SPUR_Z), 16.0, Color("6e3326"), "throw_ramen")
	WhProps.flatcar(lvl, bt, sb, Vector3(-12.0, 0.0, SPUR_Z), 14.0)
	WhProps.gondola(lvl, bt, sb, Vector3(5.0, 0.0, SPUR_Z), 14.0)
	WhProps.boxcar(lvl, bt, sb, Vector3(23.0, 0.0, SPUR_Z), 16.0, Color("3b4a5a"), "throw_waxy")
	lvl.add_child(PieceKit.gap_zone("rd_edge", Vector3(-19.0, FL + 0.2, -27.6), Vector3(14.0, 3.0, 1.5)))
	lvl.add_child(PieceKit.gap_zone("flatcar_top", Vector3(-19.0, 1.4, -29.85), Vector3(14.0, 2.5, 0.6)))
	lvl.add_child(PieceKit.gap_zone("gon_a", Vector3(-2.0, 2.3, SPUR_Z - 2.0), Vector3(2.0, 1.6, 4.0)))
	lvl.add_child(PieceKit.gap_zone("gon_b", Vector3(10.0, 2.3, SPUR_Z - 2.0), Vector3(2.0, 1.6, 4.0)))
	lvl.add_child(PieceKit.gap_zone("spur_a", Vector3(-84.0, -0.2, SPUR_Z - 1.6), Vector3(3.0, 1.6, 3.2)))
	lvl.add_child(PieceKit.gap_zone("spur_b", Vector3(-48.0, -0.2, SPUR_Z - 1.6), Vector3(3.0, 1.6, 3.2)))
	# the north bank wall: a long bank against a tall concrete retaining wall
	var wall_m := WhGeo.mat("concrete", Color("7d7b77"), 0.9, 0.9)
	WhGeo.block(bt, sb, Vector3(-72.0, -1.0, -77.4), Vector3(120.0, 5.6, 1.4), wall_m)
	bt.box_min(Vector3(-72.2, 4.6, -77.6), Vector3(120.4, 0.25, 1.8), WhGeo.mat("concrete", Color("8f8c86"), 0.4, 0.2))
	var bank: Node3D = Walls.bank(120.0, 4.0, 1.6, "")
	WhGeo.reskin(bank, WorldSurface.material("concrete", Color("6c6d70"), 0.8))
	lvl.put(bank, Vector3(-72.0, 0.0, -76.0), 0.0, "NorthBank")
	for g: Array in [["throw_mochi", -50.0, 5.5], ["tag_koi", -30.0, 3.2], ["throw_tide", -8.0, 5.0], ["chibi_cap", 12.0, 2.4],
			["throw_yuzu", 30.0, 5.0], ["tag_zest", 42.0, 3.2]]:
		lvl.add_child(WhGeo.tag(str(g[0]), float(g[2]), Vector3(float(g[1]), 3.15, -75.98), 0.0))
	# a signal mast and relay cabinets by the main line
	WhProps.signal_mast(lvl, bt, Vector3(-62.0, 0.0, MAIN_Z + 3.0))
	WhProps.signal_mast(lvl, bt, Vector3(40.0, 0.0, MAIN_Z - 3.2))
	WhGeo.block(bt, sb, Vector3(-60.0, 0.0, MAIN_Z + 4.0), Vector3(1.2, 1.4, 0.8), WhGeo.mat("paint", Color("6d7a6a"), 0.7, 0.4))
	WhProps.water_tower(lvl, bt, sb, Vector3(82.0, 0.0, -60.0))
	bt.commit(lvl, "RailMesh")


# ---------------------------------------------------------------------------------------------------- the boiler yard

static func _boiler(lvl: WarehouseLevel) -> void:
	var sb: StaticBody3D = WhGeo.body(lvl, "Boiler")
	var bt := WhGeo.Batch.new(32.0)
	# the drained settling pit
	var pit: Node3D = Bowl.build(WarehouseLevel.PIT_SIZE.x, WarehouseLevel.PIT_SIZE.y, 2.6, 4.0, 2.4, 10, "pit")
	for n: Node in pit.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.name == "Mesh" and mi.get_parent().name == "Shell":
			mi.material_override = WhGeo.mat("concrete", Color("8c8a84"), 0.9, 0.7, Color(0, 0, 0, 0), 1.0, -2.6)
		elif mi.name == "Mesh":
			mi.material_override = WorldSurface.material("concrete", Color("6a6b6e"), 0.8)
	lvl.put(pit, WarehouseLevel.PIT_POS, 0.0, "Pit")
	# the pipe runs: a low pipe (grind) and a high one on saddles, bridging up over the west door lane
	WhProps.pipe_run(lvl, bt, sb, -57.0, 0.3, 0.65, [Vector2(-52.0, -34.0), Vector2(-27.5, -22.0), Vector2(-2.0, 24.0)], true)
	WhProps.pipe_run(lvl, bt, sb, -60.0, 0.4, 1.3, [Vector2(-52.0, -34.0), Vector2(-27.5, -22.0), Vector2(-2.0, 24.0)], false)
	WhProps.pipe_bridge(lvl, bt, sb, [-57.0, -60.0], [0.3, 0.4], [0.65, 1.3], -22.0, -2.0, 5.6)
	lvl.add_child(PieceKit.gap_zone("pipe_s", Vector3(-57.6, 0.6, 19.0), Vector3(1.2, 1.8, 2.5)))
	lvl.add_child(PieceKit.gap_zone("pipe_n", Vector3(-57.6, 0.6, 0.0), Vector3(1.2, 1.8, 2.5)))
	# kicker over both pipes (Pipe Hop)
	var kick: Node3D = Kicker.build(2.6, 2.4, 0.9)
	WhGeo.reskin(kick, WhGeo.mat("plywood", PLY, 0.5, 0.2))
	lvl.put(kick, Vector3(-53.5, 0.0, -35.7), 90.0, "PipeKicker")
	lvl.add_child(PieceKit.gap_zone("pipehop_a", Vector3(-55.6, 1.0, -39.0), Vector3(1.9, 3.5, 3.6)))
	lvl.add_child(PieceKit.gap_zone("pipehop_b", Vector3(-62.8, 1.0, -39.0), Vector3(1.6, 4.0, 3.6)))
	# the boiler house and its smokestack, two tanks
	WhProps.boiler_house(lvl, bt, sb, Rect2(-96.0, -55.0, 14.0, 19.0), 11.0)  # north of the spur
	WhProps.smokestack(lvl, bt, sb, Vector3(-88.0, 0.0, -24.0), 1.7, 38.0)
	WhProps.tank(lvl, bt, sb, Vector3(-78.0, 0.0, 22.0), 3.0, 9.0)
	WhProps.tank(lvl, bt, sb, Vector3(-88.5, 0.0, 30.0), 3.6, 11.0)
	# a rusted-out car and drums
	var car: CarModel = CarModel.create("pickup", Color("7a4a32"))
	car.position = Vector3(-70.0, 0.0, -18.0)
	car.rotation_degrees = Vector3(0.0, 28.0, 2.0)
	lvl.add_child(car)
	WhGeo.solid(sb, Vector3(-70.0, 0.85, -18.0), Vector3(5.0, 1.7, 2.1), WhGeo.yaw(28.0 + 90.0))
	var k: LevelKit = lvl.kit()
	var drums: Array[Transform3D] = []
	for p: Vector3 in [Vector3(-64.0, 0, -46.0), Vector3(-63.3, 0, -45.5), Vector3(-64.4, 0, -45.2), Vector3(-50.0, 0, 18.0), Vector3(-50.6, 0, 18.5)]:
		drums.append(Transform3D(Basis(Vector3.UP, p.x), p))
	WhGeo.kit_multi(lvl, k, "oil_drum", drums, "BoilerDrums", {}, false)
	for t: Transform3D in drums:
		WhGeo.kit_solids(sb, k, "oil_drum", t)
	bt.commit(lvl, "BoilerMesh")


# ------------------------------------------------------------------------------------------------------------ fence

## Chain-link fence with barbed wire round the bounds (visual: the invisible boundary walls keep the skater in).
static func _fence(lvl: WarehouseLevel) -> void:
	var b: Rect2 = lvl.bounds.grow(0.8)
	var bt := WhGeo.Batch.new(48.0, false)
	var post := WhGeo.mat("rust", Color("6a6d72"), 0.6, 0.0)
	var chain: Material = WhProps.chain_material()
	var h: float = 3.0
	var sides: Array = [
		[Vector3(b.position.x, 0, b.position.y), Vector3(b.end.x, 0, b.position.y)],
		[Vector3(b.end.x, 0, b.position.y), Vector3(b.end.x, 0, b.end.y)],
		[Vector3(b.end.x, 0, b.end.y), Vector3(b.position.x, 0, b.end.y)],
		[Vector3(b.position.x, 0, b.end.y), Vector3(b.position.x, 0, b.position.y)],
	]
	for s: Array in sides:
		var a: Vector3 = s[0]
		var e: Vector3 = s[1]
		var n: int = int(a.distance_to(e) / 3.0)
		for i: int in n + 1:
			var p: Vector3 = a.lerp(e, float(i) / float(n))
			bt.box(p + Vector3(0, h * 0.5 + 0.2, 0), Vector3(0.07, h + 0.4, 0.07), post)
		bt.pipe(a + Vector3(0, h, 0), e + Vector3(0, h, 0), 0.03, post)
		for k: int in 3:
			bt.pipe(a + Vector3(0, h + 0.15 + 0.12 * float(k), 0), e + Vector3(0, h + 0.15 + 0.12 * float(k), 0), 0.008, post, 4)
		bt.quad(a, e, e + Vector3(0, h, 0), a + Vector3(0, h, 0), chain)
	bt.commit(lvl, "Fence")
