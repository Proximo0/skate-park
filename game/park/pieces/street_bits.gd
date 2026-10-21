class_name StreetBits
extends RefCounted
## Street pieces: ledge, manual pad, flat rail, bench and planter. Footprints follow PieceKit: origin at ground
## level at the back-left corner, the riding face looks toward +Z. Grind lines sit exactly on the top edges.
## Gap zones (when a zone id is given) cover the air space above the piece's top surface.

const LEDGE_CAP := 0.06
const LEDGE_EDGE := 0.03
const PAD_BEVEL := 0.12
const FLAT_RAIL_WIDTH := 1.0
const FLAT_RAIL_FOOT := 0.06
const FLAT_RAIL_END := 0.5
const GAP_ZONE_HEIGHT := 1.5
const BENCH_SLAT_W := 0.16
const BENCH_SLAT_T := 0.05
const BENCH_SLAT_GAP := 0.02
const BENCH_DEPTH := 0.8
const BENCH_SEAT_TOP := 0.46
const BENCH_BACK_TOP := 0.85
const BENCH_POST := 0.08
const PLANTER_WALL := 0.15
const PLANTER_FLOOR := 0.15
const PLANTER_SOIL_DROP := 0.1
const SOIL := Color("7a4b2a")
const TRUNK := Color("b86b3c")


## Concrete-capped ledge along Z. Body in `color`, concrete cap with metal edge strips slightly wider than the body.
## Grind rails on both top long edges (x = 0 and x = depth). Optional gap zone over the top.
static func ledge(length: float = 8.0, height: float = 0.5, depth: float = 0.8, color: Color = PieceKit.PAINT_PURPLE, zone_id: String = "") -> Node3D:
	var root := Node3D.new()
	root.name = "Ledge"
	var cap_h: float = minf(LEDGE_CAP, height * 0.5)
	var cap_y: float = height - cap_h
	root.add_child(PieceKit.box(Vector3(0.0, 0.0, 0.0), Vector3(depth, cap_y, length), color, "LedgeBody"))
	root.add_child(PieceKit.box(Vector3(0.0, cap_y, 0.0), Vector3(depth, cap_h, length), PieceKit.CONCRETE, "LedgeCap"))
	root.add_child(PieceKit.box(Vector3(-LEDGE_EDGE, cap_y, 0.0), Vector3(LEDGE_EDGE, cap_h, length), PieceKit.METAL, "EdgeLeft"))
	root.add_child(PieceKit.box(Vector3(depth, cap_y, 0.0), Vector3(LEDGE_EDGE, cap_h, length), PieceKit.METAL, "EdgeRight"))
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(0.0, height, 0.0), Vector3(0.0, height, length)]), "ledge", "LedgeLeft"))
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(depth, height, 0.0), Vector3(depth, height, length)]), "ledge", "LedgeRight"))
	if zone_id != "":
		root.add_child(PieceKit.gap_zone(zone_id, Vector3(0.0, height, 0.0), Vector3(depth, GAP_ZONE_HEIGHT, length)))
	return root


## Low wide manual pad along Z. Chamfered top edges (45-degree bevel strips), ledge rails on both long sides.
## Gap zones, if given, sit on each end of the top surface.
static func manual_pad(length: float = 6.0, width: float = 2.5, height: float = 0.3, zone_a: String = "", zone_b: String = "") -> Node3D:
	var root := Node3D.new()
	root.name = "ManualPad"
	root.add_child(PieceKit.box(Vector3.ZERO, Vector3(width, height, length), PieceKit.PAINT_GREEN, "PadBody"))
	var bev: float = minf(PAD_BEVEL, height)
	root.add_child(_sb_bar(Vector3(0.0, height, length * 0.5), Vector3(bev, bev, length), Vector3.BACK, "BevelLeft"))
	root.add_child(_sb_bar(Vector3(width, height, length * 0.5), Vector3(bev, bev, length), Vector3.BACK, "BevelRight"))
	root.add_child(_sb_bar(Vector3(width * 0.5, height, 0.0), Vector3(width, bev, bev), Vector3.RIGHT, "BevelFront"))
	root.add_child(_sb_bar(Vector3(width * 0.5, height, length), Vector3(width, bev, bev), Vector3.RIGHT, "BevelBack"))
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(0.0, height, 0.0), Vector3(0.0, height, length)]), "ledge", "LedgeLeft"))
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(width, height, 0.0), Vector3(width, height, length)]), "ledge", "LedgeRight"))
	if zone_a != "":
		root.add_child(PieceKit.gap_zone(zone_a, Vector3(0.0, height, 0.0), Vector3(width, GAP_ZONE_HEIGHT, FLAT_RAIL_END)))
	if zone_b != "":
		root.add_child(PieceKit.gap_zone(zone_b, Vector3(0.0, height, length - FLAT_RAIL_END), Vector3(width, GAP_ZONE_HEIGHT, FLAT_RAIL_END)))
	return root


## Classic flatbar along Z, centred in x, on two square legs with wide feet. The round rail is centred on the
## grind line at `height`, so the legs top out at that height. Gap zones, if given, sit above each end of the rail.
static func flat_rail(length: float = 6.0, height: float = 0.45, zone_a: String = "", zone_b: String = "") -> Node3D:
	var root := Node3D.new()
	root.name = "FlatRail"
	var cx: float = FLAT_RAIL_WIDTH * 0.5
	var leg: float = 0.14
	var foot_w: float = 0.44
	var foot_d: float = 0.4
	for zc: float in [0.6, length - 0.6]:
		root.add_child(PieceKit.box(Vector3(cx - foot_w * 0.5, 0.0, zc - foot_d * 0.5), Vector3(foot_w, FLAT_RAIL_FOOT, foot_d), PieceKit.METAL, "Foot"))
		root.add_child(PieceKit.box(Vector3(cx - leg * 0.5, FLAT_RAIL_FOOT, zc - leg * 0.5), Vector3(leg, height - FLAT_RAIL_FOOT, leg), PieceKit.METAL, "Leg"))
	root.add_child(PieceKit.round_rail(Vector3(cx, height, 0.0), Vector3(cx, height, length), 0.04, PieceKit.METAL, "FlatBar"))
	if zone_a != "":
		root.add_child(PieceKit.gap_zone(zone_a, Vector3(0.0, height, 0.0), Vector3(FLAT_RAIL_WIDTH, GAP_ZONE_HEIGHT, FLAT_RAIL_END)))
	if zone_b != "":
		root.add_child(PieceKit.gap_zone(zone_b, Vector3(0.0, height, length - FLAT_RAIL_END), Vector3(FLAT_RAIL_WIDTH, GAP_ZONE_HEIGHT, FLAT_RAIL_END)))
	return root


## Park bench: seat sits along X with its front edge at z = BENCH_DEPTH (the riding face). Slats, legs, backrest.
## One "ledge" rail along the front edge of the seat.
static func bench(length: float = 2.4) -> Node3D:
	var root := Node3D.new()
	root.name = "Bench"
	var seat_bottom: float = BENCH_SEAT_TOP - BENCH_SLAT_T
	var slat_start: float = BENCH_DEPTH - 4.0 * BENCH_SLAT_W - 3.0 * BENCH_SLAT_GAP
	for i: int in 4:
		var z0: float = slat_start + float(i) * (BENCH_SLAT_W + BENCH_SLAT_GAP)
		root.add_child(PieceKit.box(Vector3(0.0, seat_bottom, z0), Vector3(length, BENCH_SLAT_T, BENCH_SLAT_W), PieceKit.RAMP_WOOD, "Slat%d" % i))
	for x0: float in [0.1, length - 0.1 - BENCH_POST]:
		root.add_child(PieceKit.box(Vector3(x0, 0.0, 0.0), Vector3(BENCH_POST, BENCH_BACK_TOP, BENCH_POST), PieceKit.METAL, "BackPost"))
		root.add_child(PieceKit.box(Vector3(x0, 0.0, BENCH_DEPTH - BENCH_POST), Vector3(BENCH_POST, seat_bottom, BENCH_POST), PieceKit.METAL, "FrontLeg"))
	for y0: float in [0.55, 0.7]:
		root.add_child(PieceKit.box(Vector3(0.0, y0, 0.0), Vector3(length, 0.09, 0.06), PieceKit.RAMP_WOOD, "BackSlat"))
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(0.0, BENCH_SEAT_TOP, BENCH_DEPTH), Vector3(length, BENCH_SEAT_TOP, BENCH_DEPTH)]), "ledge", "SeatEdge"))
	return root


## Square planter box with a cartoon tree (trunk and three green spheres). One closed "ledge" rail around the
## four top edges.
static func planter(size: float = 2.0, height: float = 0.55) -> Node3D:
	var root := Node3D.new()
	root.name = "Planter"
	var t: float = PLANTER_WALL
	var wall_color: Color = PieceKit.PAINT_RED
	root.add_child(PieceKit.box(Vector3.ZERO, Vector3(size, PLANTER_FLOOR, size), PieceKit.CONCRETE, "Floor"))
	root.add_child(PieceKit.box(Vector3(0.0, 0.0, 0.0), Vector3(size, height, t), wall_color, "WallFront"))
	root.add_child(PieceKit.box(Vector3(0.0, 0.0, size - t), Vector3(size, height, t), wall_color, "WallBack"))
	root.add_child(PieceKit.box(Vector3(0.0, 0.0, t), Vector3(t, height, size - 2.0 * t), wall_color, "WallLeft"))
	root.add_child(PieceKit.box(Vector3(size - t, 0.0, t), Vector3(t, height, size - 2.0 * t), wall_color, "WallRight"))
	var soil_top: float = height - PLANTER_SOIL_DROP
	root.add_child(PieceKit.box(Vector3(t, PLANTER_FLOOR, t), Vector3(size - 2.0 * t, soil_top - PLANTER_FLOOR, size - 2.0 * t), SOIL, "Soil"))
	var k: float = size * 0.5
	var trunk_h: float = 0.9 * k
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.09 * k
	trunk.bottom_radius = 0.11 * k
	trunk.height = trunk_h
	trunk.radial_segments = 10
	root.add_child(_sb_mesh(trunk, TRUNK, Vector3(k, soil_top + trunk_h * 0.5, k), "Trunk"))
	var crown: Array = [
		[Vector3(0.0, 1.0, 0.0), 0.5],
		[Vector3(-0.32, 0.8, 0.12), 0.36],
		[Vector3(0.3, 0.92, -0.1), 0.38],
	]
	for i: int in crown.size():
		var c: Array = crown[i]
		var sph := SphereMesh.new()
		sph.radius = float(c[1]) * k
		sph.height = float(c[1]) * k * 2.0
		var off: Vector3 = c[0]
		root.add_child(_sb_mesh(sph, PieceKit.PAINT_GREEN, Vector3(k, soil_top + trunk_h, k) + off * k, "Leaves%d" % i))
	var corners: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, height, 0.0), Vector3(size, height, 0.0), Vector3(size, height, size),
		Vector3(0.0, height, size), Vector3(0.0, height, 0.0),
	])
	root.add_child(PieceKit.rail(corners, "ledge", "TopEdges"))
	return root


## A bevel bar: a 45-degree square bar centred on a top edge, rotated about its long axis `axis`.
## Cosmetic only (no collision).
static func _sb_bar(center: Vector3, size: Vector3, axis: Vector3, node_name: String) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi: MeshInstance3D = _sb_mesh(bm, PieceKit.PAINT_YELLOW, center, node_name)
	mi.transform = Transform3D(Basis(axis, PI * 0.25), center)
	return mi


## A cosmetic mesh instance (no collision) at a position with the toon material.
static func _sb_mesh(mesh: Mesh, color: Color, pos: Vector3, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = Toon.material(color)
	mi.position = pos
	return mi
