class_name DtGarage
extends RefCounted
## THE GARAGE (south-east block): a two-deck parking structure. Ramp 1 climbs from the street entrance (north side)
## along the west wall to deck 1; ramp 2 climbs from the south end of deck 1 along the east wall to the roof. The roof
## is flush with the monorail beams: its open north edge is one hop from the south beam (Roof To Line). On the roof:
## a quarter pipe, a flat rail, a manual pad, grindable parapets. Guard walls along the ramps hide their side faces
## and are sloped ledges themselves.

const CONCRETE := Color("bfc0bf")
const CONCRETE_DARK := Color("9fa1a3")
const DECK := Color("8e9196")
const PAINT := Color("f4f1e6")
const STRIPE := Color("f2c94c")
const SIGN := Color("2d6f8e")

var lvl: Node3D
var roof_xf: Transform3D
var _bt := DtBatch.new()
var _sb: StaticBody3D
var _rails: Node3D
var _root: Node3D


func _init(level: Node3D) -> void:
	lvl = level


func build() -> void:
	_root = Node3D.new()
	_root.name = "Garage"
	lvl.add_child(_root)
	_sb = DtKit.body(_root, "GarageCollision")
	_rails = Node3D.new()
	_rails.name = "GarageRails"
	_root.add_child(_rails)
	_decks()
	_ramps()
	_walls()
	_roof_pieces()
	_root.add_child(_bt.instance("GarageConcrete", true))
	var decks := MeshInstance3D.new()
	decks.name = "DeckSurface"
	decks.mesh = _deck_mesh()
	decks.material_override = WorldSurface.material("concrete", DECK, 0.6)
	decks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(decks)


## Deck 1 and the roof as slabs (with the ramp openings cut out), the columns through both.
func _decks() -> void:
	var g: Rect2 = DtPlan.GARAGE
	var r1: Rect2 = DtPlan.RAMP1
	var r2: Rect2 = DtPlan.RAMP2
	var l1: Array[Rect2] = [
		Rect2(r1.end.x, g.position.y, g.end.x - r1.end.x, g.size.y),
		Rect2(g.position.x, g.position.y, r1.size.x, r1.position.y - g.position.y),
		Rect2(g.position.x, r1.end.y, r1.size.x, g.end.y - r1.end.y),
	]
	var roof: Array[Rect2] = [
		Rect2(g.position.x, g.position.y, r2.position.x - g.position.x, g.size.y),
		Rect2(r2.position.x, g.position.y, r2.size.x, r2.position.y - g.position.y),
		Rect2(r2.position.x, r2.end.y, r2.size.x, g.end.y - r2.end.y),
	]
	for r: Rect2 in l1:
		_slab(r, DtPlan.L1)
	for r: Rect2 in roof:
		_slab(r, DtPlan.ROOF)
	for x: float in [75.0, 83.0]:
		for z: float in [62.0, 72.0, 82.0]:
			_bt.box_min(Vector3(x - 0.3, 0.0, z - 0.3), Vector3(0.6, DtPlan.ROOF - 0.3, 0.6), CONCRETE)
			DtKit.col_box(_sb, Vector3(x, (DtPlan.ROOF - 0.3) * 0.5, z), Vector3(0.6, DtPlan.ROOF - 0.3, 0.6))
	# parking stall lines and two parked cars on deck 1, three on the ground floor
	for k: int in 8:
		var z: float = 60.0 + float(k) * 3.0
		_bt.box(Vector3(78.5, DtPlan.L1 + 0.008, z), Vector3(5.0, 0.004, 0.12), PAINT)
		_bt.box(Vector3(78.5, DtPlan.P + 0.008, z), Vector3(5.0, 0.004, 0.12), PAINT)
	var cars: Array = [["hatch", Color("e8463a"), Vector3(78.5, DtPlan.L1, 64.5)], ["van", Color("3aa66a"), Vector3(78.5, DtPlan.L1, 76.5)],
		["pickup", Color("2f6fd6"), Vector3(78.5, DtPlan.P, 67.5)], ["hatch", Color("f2c23a"), Vector3(78.5, DtPlan.P, 79.5)]]
	for c: Array in cars:
		var car: StaticBody3D = ParkDressing.car(str(c[0]), c[1] as Color)
		car.position = c[2] as Vector3
		car.rotation.y = PI * 0.5
		_root.add_child(car)
		# under the decks they sit in shade: no shadows of their own, and gone from far off (a car is ~30 meshes)
		for n: Node in car.find_children("*", "GeometryInstance3D", true, false):
			var gi: GeometryInstance3D = n as GeometryInstance3D
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			gi.visibility_range_end = 70.0


func _slab(r: Rect2, top: float) -> void:
	_bt.box_min(Vector3(r.position.x, top - 0.3, r.position.y), Vector3(r.size.x, 0.3, r.size.y), CONCRETE_DARK, false)
	DtKit.col_box(_sb, Vector3(r.get_center().x, top - 0.15, r.get_center().y), Vector3(r.size.x, 0.3, r.size.y))


## The deck tops as one world-space concrete mesh (deck 1, roof, ramps).
func _deck_mesh() -> ArrayMesh:
	var d := DtBatch.new()
	var g: Rect2 = DtPlan.GARAGE
	var r1: Rect2 = DtPlan.RAMP1
	var r2: Rect2 = DtPlan.RAMP2
	var lift: float = PieceKit.FLOOR_PAD_LIFT
	var quads: Array = [
		[Rect2(r1.end.x, g.position.y, g.end.x - r1.end.x, g.size.y), DtPlan.L1],
		[Rect2(g.position.x, g.position.y, r1.size.x, r1.position.y - g.position.y), DtPlan.L1],
		[Rect2(g.position.x, r1.end.y, r1.size.x, g.end.y - r1.end.y), DtPlan.L1],
		[Rect2(g.position.x, g.position.y, r2.position.x - g.position.x, g.size.y), DtPlan.ROOF],
		[Rect2(r2.position.x, g.position.y, r2.size.x, r2.position.y - g.position.y), DtPlan.ROOF],
		[Rect2(r2.position.x, r2.end.y, r2.size.x, g.end.y - r2.end.y), DtPlan.ROOF],
		[g, DtPlan.P],
	]
	for q: Array in quads:
		var r: Rect2 = q[0]
		var y: float = float(q[1]) + lift
		d.quad(Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y, r.position.y), Vector3(r.end.x, y, r.end.y), Vector3(r.position.x, y, r.end.y), Color.WHITE, Vector3.UP)
	# the ramps' surfaces
	d.quad(Vector3(r1.position.x, DtPlan.P + lift, r1.position.y), Vector3(r1.end.x, DtPlan.P + lift, r1.position.y), Vector3(r1.end.x, DtPlan.L1 + lift, r1.end.y), Vector3(r1.position.x, DtPlan.L1 + lift, r1.end.y), Color.WHITE, Vector3.UP)
	d.quad(Vector3(r2.position.x, DtPlan.ROOF + lift, r2.position.y), Vector3(r2.end.x, DtPlan.ROOF + lift, r2.position.y), Vector3(r2.end.x, DtPlan.L1 + lift, r2.end.y), Vector3(r2.position.x, DtPlan.L1 + lift, r2.end.y), Color.WHITE, Vector3.UP)
	return d.mesh()


## The two ramps (convex wedges sunk into what they stand on) and their guard walls (sloped ledges).
func _ramps() -> void:
	var r1: Rect2 = DtPlan.RAMP1
	var r2: Rect2 = DtPlan.RAMP2
	_wedge(r1, DtPlan.P, DtPlan.L1, true)
	_wedge(r2, DtPlan.L1, DtPlan.ROOF, false)
	# guard walls: ramp 1 on its east side (toward the open ground floor), ramp 2 on its west side (toward deck 1)
	_guard(r1.end.x, r1.position.y, r1.end.y, DtPlan.P, DtPlan.L1, 1.0)
	_guard(r2.position.x - 0.3, r2.end.y, r2.position.y, DtPlan.L1, DtPlan.ROOF, 1.0)
	# chevrons painted up the ramps
	for k: int in 5:
		var t: float = (float(k) + 0.5) / 5.0
		var z1: float = lerpf(r1.position.y, r1.end.y, t)
		var y1: float = lerpf(DtPlan.P, DtPlan.L1, t) + 0.012
		_bt.box(Vector3(r1.get_center().x, y1, z1), Vector3(2.2, 0.004, 0.35), STRIPE, Basis(Vector3.RIGHT, -atan2(DtPlan.L1 - DtPlan.P, r1.size.y)))
		var z2: float = lerpf(r2.end.y, r2.position.y, t)
		var y2: float = lerpf(DtPlan.L1, DtPlan.ROOF, t) + 0.012
		_bt.box(Vector3(r2.get_center().x, y2, z2), Vector3(2.2, 0.004, 0.35), STRIPE, Basis(Vector3.RIGHT, atan2(DtPlan.ROOF - DtPlan.L1, r2.size.y)))


## A ramp over rect `r` rising from y0 to y1 toward +Z (`south`) or -Z.
func _wedge(r: Rect2, y0: float, y1: float, south: bool) -> void:
	var z_lo: float = r.position.y if south else r.end.y
	var z_hi: float = r.end.y if south else r.position.y
	var base: float = y0 - DtKit.SINK
	var pts := PackedVector3Array()
	for x: float in [r.position.x, r.end.x]:
		pts.append(Vector3(x, y0, z_lo))
		pts.append(Vector3(x, base, z_lo))
		pts.append(Vector3(x, y1, z_hi))
		pts.append(Vector3(x, base, z_hi))
	DtKit.col_convex(_sb, pts)
	var prof := PackedVector2Array([Vector2(z_lo, base + 0.2), Vector2(z_lo, y0), Vector2(z_hi, y1), Vector2(z_hi, base + 0.2)])
	_bt.prism(prof, r.position.x, r.end.x, CONCRETE_DARK, Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))


## A 0.3 m guard wall at x in [x0, x0 + 0.3] along a ramp from z_a (floor y_a) to z_b (floor y_b), `h` above the
## ramp, full height down to the ground: its top is a sloped ledge.
func _guard(x0: float, z_a: float, z_b: float, y_a: float, y_b: float, h: float) -> void:
	var base: float = DtPlan.P - DtKit.SINK
	var prof := PackedVector2Array([Vector2(z_a, base), Vector2(z_a, y_a + h), Vector2(z_b, y_b + h), Vector2(z_b, base)])
	_bt.prism(prof, x0, x0 + 0.3, CONCRETE, Transform3D.IDENTITY)
	var pts := PackedVector3Array()
	for x: float in [x0, x0 + 0.3]:
		for zy: Vector2 in prof:
			pts.append(Vector3(x, zy.y, zy.x))
	DtKit.col_convex(_sb, pts)
	for x: float in [x0, x0 + 0.3]:
		DtKit.rail(_rails, PackedVector3Array([Vector3(x, y_a + h, z_a), Vector3(x, y_b + h, z_b)]), "ledge", "RampGuard")


## Outer walls and parapets: a solid ground-floor wall on the west, south and east, a parapet on each deck, the open
## north side (the entrance under deck 1, the line hop on the roof).
func _walls() -> void:
	var g: Rect2 = DtPlan.GARAGE
	var t: float = 0.3
	var sides: Array = [
		[Vector3(g.position.x, 0.0, g.position.y), Vector3(t, 0.0, g.size.y), "W"],
		[Vector3(g.end.x - t, 0.0, g.position.y), Vector3(t, 0.0, g.size.y), "E"],
		[Vector3(g.position.x, 0.0, g.end.y - t), Vector3(g.size.x, 0.0, t), "S"],
	]
	for s: Array in sides:
		var p0: Vector3 = s[0]
		var sz: Vector3 = s[1]
		# ground floor wall up to deck 1, the deck-1 parapet, the roof parapet
		for band: Vector2 in [Vector2(0.0, DtPlan.L1 + 1.0), Vector2(DtPlan.ROOF - 0.3, DtPlan.ROOF + 1.0)]:
			var size := Vector3(sz.x, band.y - band.x, sz.z)
			_bt.box_min(Vector3(p0.x, band.x, p0.z), size, CONCRETE)
			DtKit.col_box(_sb, Vector3(p0.x + sz.x * 0.5, band.x + size.y * 0.5, p0.z + sz.z * 0.5), size)
		_bt.box_min(Vector3(p0.x, DtPlan.L1 + 1.0, p0.z), Vector3(sz.x, 0.08, sz.z) + Vector3(0.04 if sz.x < 1 else 0.0, 0.0, 0.04 if sz.z < 1 else 0.0), STRIPE)
	# the roof parapets are grind lines (inner top edges)
	var y: float = DtPlan.ROOF + 1.0
	DtKit.rail(_rails, PackedVector3Array([Vector3(g.position.x + t, y, g.position.y + 0.3), Vector3(g.position.x + t, y, g.end.y - t)]), "ledge", "ParapetW")
	DtKit.rail(_rails, PackedVector3Array([Vector3(g.end.x - t, y, g.position.y + 0.3), Vector3(g.end.x - t, y, g.end.y - t)]), "ledge", "ParapetE")
	DtKit.rail(_rails, PackedVector3Array([Vector3(g.position.x + t, y, g.end.y - t), Vector3(g.end.x - t, y, g.end.y - t)]), "ledge", "ParapetS")
	# deck 1's north edge parapet, over the open entrance
	_bt.box_min(Vector3(g.position.x, DtPlan.L1 - 0.3, g.position.y), Vector3(g.size.x, 1.3, t), CONCRETE)
	DtKit.col_box(_sb, Vector3(g.get_center().x, DtPlan.L1 + 0.35, g.position.y + t * 0.5), Vector3(g.size.x, 1.3, t))
	# the roof's north edge: open over the line, a yellow edge band; a short parapet over ramp 2's top only
	_bt.box(Vector3((g.position.x + DtPlan.RAMP2.position.x) * 0.5, DtPlan.ROOF + 0.003, g.position.y + 0.25), Vector3(DtPlan.RAMP2.position.x - g.position.x, 0.006, 0.5), STRIPE)
	_bt.box_min(Vector3(DtPlan.RAMP2.position.x, DtPlan.ROOF - 0.3, g.position.y), Vector3(g.end.x - DtPlan.RAMP2.position.x, 1.3, t), CONCRETE)
	DtKit.col_box(_sb, Vector3((DtPlan.RAMP2.position.x + g.end.x) * 0.5, DtPlan.ROOF + 0.35, g.position.y + t * 0.5), Vector3(g.end.x - DtPlan.RAMP2.position.x, 1.3, t))
	# (no grind line on this edge: the beam's rail runs a metre away, and a grind press here should find the beam)
	DtKit.zone(_rails, "roof_edge", Vector3(g.position.x, DtPlan.ROOF - 0.2, g.position.y), Vector3(DtPlan.RAMP2.position.x - g.position.x, 2.0, 2.4))
	# the sign on the west face, over the avenue
	var label := Label3D.new()
	label.name = "GarageSign"
	label.text = "PARK"
	label.font_size = 200
	label.pixel_size = 0.012
	label.modulate = Color("f2f4f7")
	label.outline_modulate = SIGN
	label.outline_size = 40
	label.position = Vector3(g.position.x - 0.05, 4.8, g.position.y + 8.0)
	label.rotation.y = -PI * 0.5
	_root.add_child(label)
	_bt.box(Vector3(g.position.x - 0.1, 4.8, g.position.y + 8.0), Vector3(0.1, 2.4, 6.0), SIGN)


## The roof: a quarter pipe facing north at the south end, a flat rail, a manual pad, and the drop-in spot.
func _roof_pieces() -> void:
	var g: Rect2 = DtPlan.GARAGE
	var y: float = DtPlan.ROOF
	var qp: Node3D = QuarterPipe.build(16.0, 3.0, 3.2, 1.5)
	(lvl as Level).put(qp, Vector3(84.0, y, g.end.y - 0.4), 180.0, "RoofQuarter")
	DtKit.zone(_rails, "garage_lip", Vector3(68.0, y + 2.6, g.end.y - 2.6), Vector3(16.0, 1.6, 2.4))
	DtKit.zone(_rails, "garage_sky", Vector3(68.0, y + 3.8, g.end.y - 3.4), Vector3(16.0, 3.0, 2.6))
	var rail: Node3D = StreetBits.flat_rail(12.0, 0.45, "", "")
	(lvl as Level).put(rail, Vector3(70.0, y, 69.5), 90.0, "RoofRail")
	DtKit.manual_pad(_bt, _sb, _rails, Vector3(70.0, 0.0, 61.5), Vector3(80.0, 0.0, 61.5), 2.4, 0.3, y, DtKit.GRANITE_WARM, "RoofPad")
	roof_xf = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(88.0, y, 56.2))
