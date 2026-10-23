class_name DtAlley
extends RefCounted
## THE ALLEYS (south-west block): two low shops (A west, B east) either side of a north-south alley, a tall brick
## building (D) south-east, the east-west alley between them, and the hidden DIY spot in the vacant lot (south-west)
## behind a chain-link fence with a torn hole. Lines: up the wooden roof ramp (under the line) onto shop A, over the
## alley to shop B (Alley Roof Gap); dock to dock across the alley; over the dumpster in the east-west alley; the fire
## escape rail down D's north wall; through the hole into the DIY spot (a concrete quarter, a bank, a jersey barrier,
## a pallet kicker, and the secret tape over the quarter).

const BRICK := Color("a9543f")
const BRICK_B := Color("8a5a48")
const BRICK_D := Color("b56a4a")
const TRIM := Color("d9cfbd")
const DOCK := Color("8e9196")
const ROOF := Color("b3aea4")
const WOOD := Color("b98a58")

const SHOP_A := Rect2(-100.0, 58.0, 20.0, 12.0)
const SHOP_B := Rect2(-74.0, 58.0, 13.0, 12.0)
const TOWER_D := Rect2(-74.0, 76.0, 13.0, 14.0)
const LOT := Rect2(-100.0, 76.0, 20.0, 14.0)
const SHOP_H: float = 3.5
const D_H: float = 11.0
const DOCK_H: float = 1.2
const HOLE_Z := Vector2(82.6, 84.6)

var lvl: Node3D
var tape_pos: Vector3
var steam_spots: Array[Vector3] = []
var _bt := DtBatch.new()
var _sb: StaticBody3D
var _rails: Node3D
var _root: Node3D


func _init(level: Node3D) -> void:
	lvl = level


func build() -> void:
	_root = Node3D.new()
	_root.name = "Alleys"
	lvl.add_child(_root)
	_sb = DtKit.body(_root, "AlleyCollision")
	_rails = Node3D.new()
	_rails.name = "AlleyRails"
	_root.add_child(_rails)
	_ground()
	_shops()
	_docks()
	_tower_d()
	_roof_ramp()
	_dumpsters()
	_diy()
	_graffiti()
	_root.add_child(_bt.instance("AlleyBrick", true))


## Worn asphalt over the block interior (the alleys and the lot), cracked concrete in the lot.
func _ground() -> void:
	var lift: float = DtPlan.P + PieceKit.FLOOR_PAD_LIFT
	var d := DtBatch.new()
	var r := Rect2(-100.0, 41.0, 39.0, 49.0)
	d.quad(Vector3(r.position.x, lift, r.position.y), Vector3(r.end.x, lift, r.position.y), Vector3(r.end.x, lift, r.end.y), Vector3(r.position.x, lift, r.end.y), Color.WHITE, Vector3.UP)
	var mi: MeshInstance3D = d.instance("AlleyFloor", false)
	mi.material_override = WorldSurface.material("asphalt", Color("5a5c63"), 0.8)
	_root.add_child(mi)
	var c := DtBatch.new()
	var lot_y: float = lift + 0.004
	c.quad(Vector3(LOT.position.x, lot_y, LOT.position.y), Vector3(LOT.end.x, lot_y, LOT.position.y), Vector3(LOT.end.x, lot_y, LOT.end.y), Vector3(LOT.position.x, lot_y, LOT.end.y), Color.WHITE, Vector3.UP)
	var ci: MeshInstance3D = c.instance("LotFloor", false)
	ci.material_override = WorldSurface.material("concrete", Color("9c9a92"), 1.4)
	_root.add_child(ci)


## A brick box with a flat roof, a trim band, windows and doors on the faces listed in `fronts` (outward normals).
func _building(r: Rect2, h: float, col: Color, fronts: Array[Vector3], roof_rails: bool) -> void:
	var p: float = DtPlan.P
	_bt.box_min(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, p + h, r.size.y), col)
	_bt.box_min(Vector3(r.position.x - 0.05, p + h - 0.25, r.position.y - 0.05), Vector3(r.size.x + 0.1, 0.25, r.size.y + 0.1), TRIM)
	_bt.box_min(Vector3(r.position.x + 0.15, p + h, r.position.y + 0.15), Vector3(r.size.x - 0.3, 0.004, r.size.y - 0.3), ROOF)
	DtKit.col_box(_sb, Vector3(r.get_center().x, (p + h - 0.5) * 0.5, r.get_center().y), Vector3(r.size.x, p + h + 0.5, r.size.y))
	if roof_rails:
		var y: float = p + h
		var pts := PackedVector3Array([Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y, r.position.y), Vector3(r.end.x, y, r.end.y), Vector3(r.position.x, y, r.end.y), Vector3(r.position.x, y, r.position.y)])
		DtKit.rail(_rails, pts, "ledge", "RoofEdge")
	for o: Vector3 in fronts:
		var along: Vector3 = Vector3(-o.z, 0.0, o.x)
		var c3 := Vector3(r.get_center().x + o.x * r.size.x * 0.5, 0.0, r.get_center().y + o.z * r.size.y * 0.5)
		var span: float = absf(along.x) * r.size.x + absf(along.z) * r.size.y
		var n: int = int(span / 3.2)
		var floors: int = int((h - 1.0) / 3.4)
		for f: int in floors:
			for i: int in n:
				var u: float = -span * 0.5 + (float(i) + 0.5) * span / float(n)
				var y0: float = p + 1.0 + float(f) * 3.4
				if f == 0 and i % 3 == 1:
					_bt.box(c3 + along * u + Vector3(0, p + 1.15, 0) + o * 0.03, Vector3(1.2, 2.3, 0.06).rotated(Vector3.UP, 0.0) if absf(o.z) > 0.5 else Vector3(0.06, 2.3, 1.2), Color("4a3a30"))
				else:
					var sz := Vector3(1.1, 1.5, 0.06) if absf(o.z) > 0.5 else Vector3(0.06, 1.5, 1.1)
					_bt.box(c3 + along * u + Vector3(0, y0 + 1.0, 0) + o * 0.03, sz, Color("34465c"))
					var sill := Vector3(1.3, 0.12, 0.14) if absf(o.z) > 0.5 else Vector3(0.14, 0.12, 1.3)
					_bt.box(c3 + along * u + Vector3(0, y0 + 0.2, 0) + o * 0.06, sill, TRIM)


func _shops() -> void:
	_building(SHOP_A, SHOP_H, BRICK, [Vector3(0, 0, -1), Vector3(0, 0, 1)] as Array[Vector3], true)
	_building(SHOP_B, SHOP_H, BRICK_B, [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1)] as Array[Vector3], true)
	# the roof gap over the north-south alley: zones over the two facing roof edges
	var y: float = DtPlan.P + SHOP_H
	DtKit.zone(_rails, "alley_roof_a", Vector3(SHOP_A.end.x - 2.0, y, SHOP_A.position.y), Vector3(2.0, 2.4, SHOP_A.size.y))
	DtKit.zone(_rails, "alley_roof_b", Vector3(SHOP_B.position.x, y, SHOP_B.position.y), Vector3(2.4, 2.4, SHOP_B.size.y))
	# AC units on the roofs (solid, ledges to grind)
	for c: Vector3 in [Vector3(-94.0, y, 64.0), Vector3(-66.0, y, 66.0)]:
		_bt.box(c + Vector3(0, 0.55, 0), Vector3(2.2, 1.1, 1.4), Color("b9bec6"))
		_bt.box(c + Vector3(0, 1.12, 0), Vector3(1.6, 0.06, 1.0), Color("7d838c"))
		DtKit.col_box(_sb, c + Vector3(0, 0.45, 0), Vector3(2.2, 1.3, 1.4))


## Loading docks facing each other across the north-south alley: 1.2 m decks with steel edges (grind lines),
## rubber bumpers, roll-up doors behind.
func _docks() -> void:
	var p: float = DtPlan.P
	var z0: float = 60.0
	var z1: float = 68.0
	for side: Array in [[DtPlan.ALLEY_X0, 1.0, "dock_w"], [DtPlan.ALLEY_X1, -1.0, "dock_e"]]:
		var wx: float = float(side[0])
		var s: float = float(side[1])
		var x0: float = wx if s > 0.0 else wx - 1.4
		_bt.box_min(Vector3(x0, 0.0, z0), Vector3(1.4, p + DOCK_H, z1 - z0), DOCK)
		DtKit.col_box(_sb, Vector3(x0 + 0.7, (p + DOCK_H - 0.5) * 0.5, (z0 + z1) * 0.5), Vector3(1.4, p + DOCK_H + 0.5, z1 - z0))
		var ex: float = wx + s * 1.4
		_bt.box(Vector3(ex - s * 0.03, p + DOCK_H - 0.04, (z0 + z1) * 0.5), Vector3(0.08, 0.08, z1 - z0), DtKit.STEEL)
		for k: int in 3:
			_bt.box(Vector3(ex + s * 0.08, p + 0.75, z0 + 1.2 + float(k) * 2.8), Vector3(0.16, 0.4, 0.5), Color("232428"))
		DtKit.rail(_rails, PackedVector3Array([Vector3(ex, p + DOCK_H, z0), Vector3(ex, p + DOCK_H, z1)]), "ledge", "DockEdge")
		# roll-up doors above the dock
		for k: int in 2:
			_bt.box(Vector3(wx + s * 0.03, p + DOCK_H + 1.4, z0 + 2.0 + float(k) * 4.0), Vector3(0.06, 2.6, 2.8), Color("aeb3ba"))
		DtKit.zone(_rails, str(side[2]), Vector3(ex - 0.7, p + DOCK_H + 0.1, z0), Vector3(1.4, 2.0, z1 - z0))


## D: the tall brick building south-east, its fire escape (a grindable rail down to the alley).
func _tower_d() -> void:
	_building(TOWER_D, D_H, BRICK_D, [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(1, 0, 0)] as Array[Vector3], false)
	var p: float = DtPlan.P
	var z: float = TOWER_D.position.y - 1.1
	# landings and stairs (visual), the lower run's outer rail is a grind line
	for k: int in 2:
		var y: float = p + 3.4 + float(k) * 3.4
		_bt.box(Vector3(-64.5, y, z + 0.1), Vector3(5.0, 0.1, 1.2), Color("3b3f48"))
		_bt.box(Vector3(-64.5, y + 0.95, z - 0.45), Vector3(5.0, 0.05, 0.05), Color("3b3f48"))
	var a := Vector3(-62.4, p + 3.4 + 0.9, z - 0.5)
	var b := Vector3(-71.6, p + 1.0, z - 0.5)
	_bt.tube(a, b, 0.045, Color("3b3f48"), 8)
	_bt.bar(Vector3(-62.4, p + 3.35, z + 0.1), Vector3(-71.6, p + 0.45, z + 0.1), 1.0, 0.1, Color("3b3f48"))
	# the stair run and the landings are solid (a steel slab under the rail; it lands on the alley floor)
	# The slab runs on to the building wall (z + 1.1 = TOWER_D.position.y): it used to stop 0.5 m short and left a pinch the
	# skater wedged into (snag sweep, Alleys/AlleyCollision at (-71, 75.5)). Its low end now sits on the floor, and the
	# taper where it is under 0.8 m clear of the floor is filled in, so there is no gap too low to ride into.
	var sp := PackedVector3Array()
	for dz: float in [-0.4, 1.1]:
		sp.append(Vector3(-62.4, p + 3.4, z + dz))
		sp.append(Vector3(-62.4, p + 3.2, z + dz))
		sp.append(Vector3(-71.6, p + 0.5, z + dz))
		sp.append(Vector3(-71.6, p - DtKit.SINK, z + dz))
	DtKit.col_convex(_sb, sp)
	var tp := PackedVector3Array()
	for dz: float in [-0.4, 1.1]:
		tp.append(Vector3(-71.6, p - DtKit.SINK, z + dz))
		tp.append(Vector3(-71.6, p + 0.5, z + dz))
		tp.append(Vector3(-68.0, p - DtKit.SINK, z + dz))
		tp.append(Vector3(-68.0, p + 1.2, z + dz))
	DtKit.col_convex(_sb, tp)
	for k: int in 2:
		DtKit.col_box(_sb, Vector3(-64.5, p + 3.4 + float(k) * 3.4, z + 0.1), Vector3(5.0, 0.1, 1.2))
	for i: int in 4:
		var t: float = float(i) / 3.0
		var pt: Vector3 = a.lerp(b, t)
		_bt.tube(Vector3(pt.x, p, pt.z), pt, 0.04, Color("3b3f48"), 6)
		DtKit.col_box(_sb, Vector3(pt.x, (pt.y + p - 0.2) * 0.5, pt.z), Vector3(0.1, pt.y - p + 0.2, 0.1))
	DtKit.rail(_rails, PackedVector3Array([a, b]), "rail", "FireEscape")
	var mid: Vector3 = a.lerp(b, 0.4)  # catch it from the alley: ollie up onto its middle and ride it down
	DtKit.zone(_rails, "escape_top", Vector3(mid.x - 0.8, mid.y - 0.5, a.z - 0.6), Vector3(1.6, 1.8, 1.2))
	DtKit.zone(_rails, "escape_bottom", Vector3(b.x - 0.4, b.y - 0.6, b.z - 0.6), Vector3(1.6, 1.8, 1.2))
	steam_spots.append(Vector3(-68.0, p, 75.0))


## The wooden ramp up onto shop A's roof, from under the line (its slope keeps clear of the beam above).
func _roof_ramp() -> void:
	var p: float = DtPlan.P
	var top: float = p + SHOP_H
	var x0: float = -97.0
	var x1: float = -91.0
	var z_lo: float = SHOP_A.position.y - 12.0
	var z_hi: float = SHOP_A.position.y
	var pts := PackedVector3Array()
	for x: float in [x0, x1]:
		pts.append(Vector3(x, p, z_lo))
		pts.append(Vector3(x, p - DtKit.SINK, z_lo))
		pts.append(Vector3(x, top, z_hi))
		pts.append(Vector3(x, p - DtKit.SINK, z_hi))
	DtKit.col_convex(_sb, pts)
	var prof := PackedVector2Array([Vector2(z_lo, p - 0.05), Vector2(z_hi, top), Vector2(z_hi, p - 0.05)])
	_bt.prism(prof, x0, x1, WOOD, Transform3D.IDENTITY)
	for k: int in 12:
		var t: float = (float(k) + 0.5) / 12.0
		var zz: float = lerpf(z_lo, z_hi, t)
		_bt.box(Vector3((x0 + x1) * 0.5, lerpf(p, top, t) + 0.01, zz), Vector3(x1 - x0, 0.03, 0.08), WOOD.darkened(0.25), Basis(Vector3.RIGHT, -atan2(top - p, z_hi - z_lo)))
	# side rails of the ramp, grind lines
	for x: float in [x0, x1]:
		var z_r: float = lerpf(z_lo, z_hi, 0.35 / (top - p))  # the rail starts where the side is 0.35 m tall
		DtKit.rail(_rails, PackedVector3Array([Vector3(x, p + 0.35, z_r), Vector3(x, top, z_hi)]), "ledge", "RampSide")


## Dumpsters: one in the middle of the east-west alley (Dumpster Hop), two against D's west wall.
func _dumpsters() -> void:
	var p: float = DtPlan.P
	var cz: float = (DtPlan.ALLEY_Z0 + DtPlan.ALLEY_Z1) * 0.5
	_dumpster(Vector3(-70.0, p, cz), 0.0, Color("2f7a5a"))
	_dumpster(Vector3(-75.0, p, 81.0), PI * 0.5, Color("3a6a9a"))
	_dumpster(Vector3(-75.0, p, 86.0), PI * 0.5, Color("2f7a5a"))
	DtKit.zone(_rails, "dumpster_w", Vector3(-72.4, p + 1.35, cz - 1.5), Vector3(0.9, 2.5, 3.0))
	DtKit.zone(_rails, "dumpster_e", Vector3(-68.5, p + 1.35, cz - 1.5), Vector3(0.9, 2.5, 3.0))
	steam_spots.append(Vector3(-86.0, p, 73.0))
	steam_spots.append(Vector3(-77.0, p, 63.5))


func _dumpster(c: Vector3, yaw: float, col: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	_bt.box(c + Vector3(0, 0.72, 0), Vector3(2.0, 0.95, 1.05), col, b)
	_bt.box(c + Vector3(0, 1.22, 0), Vector3(2.08, 0.07, 1.13), col.darkened(0.25), b)
	_bt.box(c + Vector3(0, 1.29, 0), Vector3(2.0, 0.06, 1.1), Color("3a3a4a"), b * Basis(Vector3.FORWARD, 0.04))
	_bt.box(c + Vector3(0, 0.15, 0), Vector3(1.8, 0.3, 0.9), Color("2a2a35"), b)
	DtKit.col_box(_sb, c + Vector3(0, 0.6, 0), Vector3(2.08, 1.3, 1.13), b)


## The DIY spot: the vacant lot behind the fence (a torn hole on its alley side), a concrete quarter pipe against the
## west wall, a bank in the south-east corner, a jersey barrier, a pallet kicker, a mattress; the tape over the quarter.
func _diy() -> void:
	var p: float = DtPlan.P
	# the fence: along the lot's north side (z = 76) and east side (x = -80) with the hole
	var fence := DtBatch.new()
	var panels: Array = [
		[Vector3(LOT.position.x, 0.0, LOT.position.y), Vector3(LOT.end.x, 0.0, LOT.position.y)],
		[Vector3(LOT.end.x, 0.0, LOT.position.y), Vector3(LOT.end.x, 0.0, HOLE_Z.x)],
		[Vector3(LOT.end.x, 0.0, HOLE_Z.y), Vector3(LOT.end.x, 0.0, LOT.end.y)],
	]
	var fh: float = 2.4
	for pr: Array in panels:
		var a: Vector3 = pr[0]
		var b: Vector3 = pr[1]
		var l: float = a.distance_to(b)
		var dir: Vector3 = (b - a) / l
		var n: int = int(ceil(l / 2.5))
		for i: int in n + 1:
			var q: Vector3 = a + dir * minf(float(i) * l / float(n), l)
			fence.cyl(Vector3(q.x, p, q.z), 0.05, fh, PieceKit.METAL, 6)
		fence.bar(a + Vector3(0, p + fh, 0), b + Vector3(0, p + fh, 0), 0.05, 0.05, PieceKit.METAL)
		fence.bar(a + Vector3(0, p + 0.1, 0), b + Vector3(0, p + 0.1, 0), 0.05, 0.05, PieceKit.METAL)
		var c: Vector3 = (a + b) * 0.5
		DtKit.col_box(_sb, Vector3(c.x, p + fh * 0.5, c.z), Vector3(absf(b.x - a.x) + 0.1, fh + 0.4, absf(b.z - a.z) + 0.1))
		var panel := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(l, fh)
		panel.mesh = quad
		panel.material_override = Walls._chain_material(l, fh)
		panel.position = Vector3(c.x, p + fh * 0.5, c.z)
		panel.rotation.y = atan2(dir.x, dir.z) - PI * 0.5
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(panel)
	# the torn flap, peeled back
	fence.box(Vector3(LOT.end.x - 0.5, p + 1.0, HOLE_Z.x + 0.2), Vector3(0.9, 1.6, 0.03), PieceKit.METAL.darkened(0.2), Basis(Vector3.UP, 0.9))
	_root.add_child(fence.instance("Fence", true))
	DtKit.zone(_rails, "diy_hole", Vector3(LOT.end.x - 1.0, p, HOLE_Z.x), Vector3(2.0, 2.4, HOLE_Z.y - HOLE_Z.x))
	DtKit.zone(_rails, "diy_spot", Vector3(LOT.position.x, p, LOT.position.y + 0.5), Vector3(LOT.size.x - 1.2, 6.0, LOT.size.y - 0.5))
	# concrete quarter pipe against the west wall, facing east
	var qp: Node3D = QuarterPipe.build(9.0, 2.6, 2.6, 1.2)
	(lvl as Level).put(qp, Vector3(LOT.position.x + 0.2, p, LOT.end.y - 0.4), 90.0, "DiyQuarter")
	tape_pos = Vector3(LOT.position.x + 2.2, p + 4.2, LOT.end.y - 4.9)
	# a bank in the south-east corner rising to the south wall, a jersey barrier, a pallet kicker
	DtKit.bank(_bt, _sb, _rails, Vector3(-86.0, 0.0, LOT.end.y - 1.2), Vector3(0, 0, -1), 6.0, 3.2, p + 1.4, p, Color("a8a69e"), 1.0, "DiyBank")
	DtKit.ledge(_bt, _sb, _rails, Vector3(-94.0, 0.0, 79.0), Vector3(-86.0, 0.0, 79.0), 0.6, 0.8, p, Color("c9c6be"), Color("d9d6ce"), "Barrier")
	DtKit.kicker(_bt, _sb, _rails, Vector3(-84.0, 0.0, 81.0), Vector3(-1, 0, 0), 1.6, 1.6, 0.6, p, WOOD)
	# a mattress and a few tyres (clutter, flat)
	_bt.box(Vector3(-83.0, p + 0.11, 88.0), Vector3(1.9, 0.22, 1.4), Color("cdbd9c"), Basis(Vector3.UP, 0.3))
	_bt.box(Vector3(-83.0, p + 0.3, 88.0), Vector3(1.85, 0.16, 1.35), Color("d9c9a8"), Basis(Vector3.UP, 0.34))
	DtKit.col_box(_sb, Vector3(-83.0, p + 0.0, 88.0), Vector3(1.9, 0.76, 1.4), Basis(Vector3.UP, 0.3))


func _graffiti() -> void:
	var p: float = DtPlan.P
	var tags: Array = [
		["throw_waxy", Vector3(SHOP_A.end.x + 0.02, p + 2.4, 63.0), 90.0, 3.8],
		["chibi_blue", Vector3(SHOP_B.position.x - 0.02, p + 2.6, 68.8), -90.0, 1.6],
		["throw_mochi", Vector3(-67.5, p + 2.2, TOWER_D.position.y - 0.02), 180.0, 5.0],
		["motif_skull", Vector3(LOT.position.x + 0.02, p + 4.6, 84.0), 90.0, 3.0],
		["tag_flux", Vector3(-90.0, p + 1.8, SHOP_A.end.y + 0.02), 0.0, 3.2],
	]
	for t: Array in tags:
		_root.add_child(ParkDressing.decal(str(t[0]), float(t[3]), t[1] as Vector3, float(t[2])))
