class_name WhHall
extends RefCounted
## The main hall of the Creepy Warehouse and the secret annex behind its east wall: walls with dock-door openings, a
## roof on steel trusses with broken skylights, the catwalk ring (west quarter-pipe deck, north catwalk, stairs, end
## platform and the plywood ramp up to it), pallet racks with plinth ledges, the pallet-box gap, the forklift hop, the
## spine, a conveyor, a fallen beam, the pallet pad and the skaters' corner. The floor (top FL) is WhOutdoor's slab.

const FL: float = WarehouseLevel.FL
const ROOF: float = WarehouseLevel.ROOF_Y
const DADO: float = 2.4  ## brick up to here, corrugated siding above
const CAT_Y: float = FL + 3.2  ## catwalk deck top (= the west quarter pipe's deck)
const BRICK := Color("5e3a31")
const SIDING := Color("56606a")
const SIDING_OUT := Color("4d5964")
const STEEL := Color("454951")
const SAFETY := Color("e0ad22")
const PLY := Color("b0875a")
## Door openings: [from, to, top] along each wall.
const SOUTH_DOORS: Array = [[-27.0, -21.0, FL + 5.0], [-3.0, 3.0, FL + 5.0], [21.0, 27.0, FL + 5.0]]
const NORTH_DOORS: Array = [[-27.0, -21.0, FL + 5.0], [13.0, 19.0, FL + 5.0]]
const WEST_DOORS: Array = [[-17.0, -11.0, FL + 5.0]]
const EAST_DOORS: Array = [[-6.0, 6.0, FL + 5.0], [14.0, 16.5, FL + 2.6]]
const SKYLIGHTS_X: Array[float] = [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0]
const SKYLIGHTS_Z: Array[float] = [-12.0, 3.0]


static func build(lvl: WarehouseLevel) -> void:
	var sb: StaticBody3D = WhGeo.body(lvl, "Hall")
	var bt := WhGeo.Batch.new(20.0)
	_walls(lvl, bt, sb)
	_roof(lvl)
	_catwalks(lvl, bt, sb)
	_racks(lvl, bt, sb)
	_pallet_gap(lvl, bt, sb)
	_forklift(lvl, bt, sb)
	_centre(lvl, bt, sb)
	_floor_paint(bt)
	_dressing(lvl, bt, sb)
	bt.commit(lvl, "HallMesh")
	_annex(lvl)


# ------------------------------------------------------------------------------------------------------------- walls

## A wall along x (faces at z0 and z1) from x0 to x1, with openings [a, b, top]. Brick dado inside and out, siding above.
static func _wall_x(bt: WhGeo.Batch, sb: StaticBody3D, z0: float, z1: float, x0: float, x1: float, doors: Array) -> void:
	var cuts: Array = [[x0, x0, FL]]
	for d: Array in doors:
		cuts.append(d)
	cuts.append([x1, x1, FL])
	for i: int in cuts.size() - 1:
		var a: float = float(cuts[i][1])
		var b: float = float(cuts[i + 1][0])
		if b - a > 0.01:
			_wall_piece(bt, sb, Vector3(a, FL, z0), Vector3(b - a, ROOF - FL, z1 - z0))
	for d: Array in doors:
		_wall_piece(bt, sb, Vector3(float(d[0]), float(d[2]), z0), Vector3(float(d[1]) - float(d[0]), ROOF - float(d[2]), z1 - z0))


static func _wall_z(bt: WhGeo.Batch, sb: StaticBody3D, x0: float, x1: float, z0: float, z1: float, doors: Array) -> void:
	var cuts: Array = [[z0, z0, FL]]
	for d: Array in doors:
		cuts.append(d)
	cuts.append([z1, z1, FL])
	for i: int in cuts.size() - 1:
		var a: float = float(cuts[i][1])
		var b: float = float(cuts[i + 1][0])
		if b - a > 0.01:
			_wall_piece(bt, sb, Vector3(x0, FL, a), Vector3(x1 - x0, ROOF - FL, b - a))
	for d: Array in doors:
		_wall_piece(bt, sb, Vector3(x0, float(d[2]), float(d[0])), Vector3(x1 - x0, ROOF - float(d[2]), float(d[1]) - float(d[0])))


static func _wall_piece(bt: WhGeo.Batch, sb: StaticBody3D, lo: Vector3, size: Vector3) -> void:
	WhGeo.solid_min(sb, lo, size)
	var brick := WhGeo.mat("brick", BRICK, 0.6, 0.8, Color("3e3a37"), 1.0, FL)
	var siding := WhGeo.mat("metal", SIDING, 0.75, 0.3, Color("6b3a22"), 1.0, FL + DADO)
	var top: float = lo.y + size.y
	if lo.y < FL + DADO - 0.01:
		var h: float = minf(FL + DADO, top) - lo.y
		bt.box_min(lo, Vector3(size.x, h, size.z), brick)
	if top > FL + DADO + 0.01:
		var y0: float = maxf(lo.y, FL + DADO)
		bt.box_min(Vector3(lo.x, y0, lo.z), Vector3(size.x, top - y0, size.z), siding)


static func _walls(lvl: WarehouseLevel, bt: WhGeo.Batch, sb: StaticBody3D) -> void:
	var t: float = WarehouseLevel.WALL_T
	_wall_x(bt, sb, 20.0, 20.0 + t, -40.5, 40.5, SOUTH_DOORS)
	_wall_x(bt, sb, -20.0 - t, -20.0, -40.5, 40.5, NORTH_DOORS)
	_wall_z(bt, sb, -40.0 - t, -40.0, -20.0, 20.0, WEST_DOORS)
	_wall_z(bt, sb, 40.0, 40.0 + t, -20.0, 20.0, EAST_DOORS)
	# door frames (steel) and half-raised roll-up shutters in the open bays
	var steel := WhGeo.mat("rust", STEEL, 0.6, 0.2)
	var shutter := WhGeo.mat("metal", Color("6c7076"), 0.85, 0.3, Color("6b3a22"), 1.0, FL)
	for d: Array in SOUTH_DOORS:
		_door_frame_x(bt, float(d[0]), float(d[1]), float(d[2]), 20.0 + t, steel, shutter, 1.0)
	for d: Array in NORTH_DOORS:
		_door_frame_x(bt, float(d[0]), float(d[1]), float(d[2]), -20.0 - t, steel, shutter, -1.0)
	# closed kit dock doors in the blind bays (visual; the wall behind is solid)
	var k: LevelKit = lvl.kit()
	var doors: Array[Transform3D] = []
	for x: float in [-33.0, -12.0, 12.0, 33.0]:
		doors.append(Transform3D(WhGeo.yaw(180.0), Vector3(x, -0.01, 20.0 + t + 0.06)))
	for x: float in [-33.0, -6.0, 30.0]:
		doors.append(Transform3D(Basis.IDENTITY, Vector3(x, -0.01, -20.0 - t - 0.06)))
	WhGeo.kit_multi(lvl, k, "loading_dock_door", doors, "DockDoors")
	# pilasters on the inside faces (steel columns under each truss)
	var col := WhGeo.mat("paint", Color("3d4a5c"), 0.7, 0.5, Color("6b3a22"), 1.0, FL)
	for x: float in range(-32, 33, 8):
		for zf: Array in [[19.65, 20.0, SOUTH_DOORS], [-20.0, -19.65, NORTH_DOORS]]:
			var blocked: bool = false
			for d: Array in zf[2]:
				if float(x) > float(d[0]) - 0.6 and float(x) < float(d[1]) + 0.6:
					blocked = true
			if not blocked:
				WhGeo.block(bt, sb, Vector3(float(x) - 0.2, FL, float(zf[0])), Vector3(0.4, ROOF - FL - 1.4, float(zf[1]) - float(zf[0])), col)
	# graffiti on the walls, inside and out
	var g: Array = [
		["throw_bonz", 7.0, Vector3(-12.0, FL + 2.0, 19.98), 180.0], ["tag_drip", 3.0, Vector3(8.0, FL + 1.7, 19.98), 180.0],
		["motif_skull", 3.2, Vector3(12.0, FL + 6.4, 19.98), 180.0], ["tag_flux", 3.5, Vector3(-33.0, FL + 6.2, 19.98), 180.0],
		["throw_waxy", 7.0, Vector3(-30.0, FL + 7.0, -19.98), 0.0], ["tag_zest", 3.4, Vector3(4.0, FL + 1.5, -19.98), 0.0],
		["throw_mochi", 7.0, Vector3(-39.98, FL + 7.0, 5.0), 90.0], ["motif_koi", 4.0, Vector3(39.98, FL + 2.4, -12.0), -90.0],
		["throw_tide", 6.0, Vector3(39.98, FL + 7.5, 10.0), -90.0], ["sticker_sk8", 0.8, Vector3(-2.0, FL + 1.2, -19.98), 0.0],
		["throw_yuzu", 8.0, Vector3(-12.0, FL + 6.5, 20.54), 0.0], ["tag_koi", 3.6, Vector3(9.0, FL + 1.5, 20.54), 0.0],
		["throw_bonz", 7.5, Vector3(40.54, FL + 6.0, -14.0), 90.0], ["tag_spud", 3.0, Vector3(-40.54, FL + 1.6, 4.0), -90.0],
		["throw_tide", 7.0, Vector3(14.0, FL + 6.5, -20.54), 180.0], ["tag_drip", 3.0, Vector3(-8.0, FL + 1.6, -20.54), 180.0],
	]
	for e: Array in g:
		lvl.add_child(WhGeo.tag(str(e[0]), float(e[1]), e[2] as Vector3, float(e[3])))


## Steel frame round an opening in a wall along x (outer face at zf), a shutter rolled most of the way up, and a hazard
## stripe on the sill.
static func _door_frame_x(bt: WhGeo.Batch, a: float, b: float, top: float, zf: float, steel: Material, shutter: Material, out: float) -> void:
	var t: float = WarehouseLevel.WALL_T
	var zc: float = zf - out * t * 0.5
	bt.box(Vector3(a - 0.12, (FL + top) * 0.5, zc), Vector3(0.24, top - FL, t + 0.16), steel)
	bt.box(Vector3(b + 0.12, (FL + top) * 0.5, zc), Vector3(0.24, top - FL, t + 0.16), steel)
	bt.box(Vector3((a + b) * 0.5, top + 0.12, zc), Vector3(b - a + 0.48, 0.24, t + 0.16), steel)
	bt.box(Vector3((a + b) * 0.5, top - 0.45, zc), Vector3(b - a, 0.9, 0.12), shutter)
	bt.box(Vector3((a + b) * 0.5, top + 0.45, zc), Vector3(b - a + 0.3, 0.6, 0.7), steel)


# -------------------------------------------------------------------------------------------------------------- roof

static func _roof(lvl: WarehouseLevel) -> void:
	var bt := WhGeo.Batch.new(28.0)
	var holes: Array[Rect2] = []
	for x: float in SKYLIGHTS_X:
		for z: float in SKYLIGHTS_Z:
			holes.append(Rect2(x - 2.0, z - 1.5, 4.0, 3.0))
	var inner := WhGeo.mat("metal", Color("2c3036"), 0.6, 0.0, Color("4a2a1a"))
	var outer := WhGeo.mat("metal", Color("4a4f56"), 0.8, 0.0, Color("5a2e1c"))
	for r: Rect2 in WhGeo.cut_rects(Rect2(-40.6, -20.6, 81.2, 41.2), holes):
		bt.quad(Vector3(r.position.x, ROOF, r.position.y), Vector3(r.end.x, ROOF, r.position.y), Vector3(r.end.x, ROOF, r.end.y), Vector3(r.position.x, ROOF, r.end.y), inner)
		bt.quad(Vector3(r.position.x, ROOF + 0.35, r.position.y), Vector3(r.position.x, ROOF + 0.35, r.end.y), Vector3(r.end.x, ROOF + 0.35, r.end.y), Vector3(r.end.x, ROOF + 0.35, r.position.y), outer)
	# parapet round the roof edge (from outside it closes the roof slab's edge)
	for e: Array in [[Vector3(-40.6, ROOF, -20.6), Vector3(81.2, 0.9, 0.3)], [Vector3(-40.6, ROOF, 20.3), Vector3(81.2, 0.9, 0.3)],
			[Vector3(-40.6, ROOF, -20.6), Vector3(0.3, 0.9, 41.2)], [Vector3(40.3, ROOF, -20.6), Vector3(0.3, 0.9, 41.2)]]:
		bt.box_min(e[0] as Vector3, e[1] as Vector3, outer)
	# skylight curbs (raised monitors) round each hole
	var curb := WhGeo.mat("rust", Color("3a3d43"), 0.7, 0.0)
	for h: Rect2 in holes:
		for e: Array in [[Vector3(h.position.x - 0.15, ROOF, h.position.y - 0.15), Vector3(h.size.x + 0.3, 0.6, 0.15)],
				[Vector3(h.position.x - 0.15, ROOF, h.end.y), Vector3(h.size.x + 0.3, 0.6, 0.15)],
				[Vector3(h.position.x - 0.15, ROOF, h.position.y), Vector3(0.15, 0.6, h.size.y)],
				[Vector3(h.end.x, ROOF, h.position.y), Vector3(0.15, 0.6, h.size.y)]]:
			bt.box_min(e[0] as Vector3, e[1] as Vector3, curb)
	# trusses every 8 m across the hall, purlins along it
	var steel := WhGeo.mat("rust", Color("3b3f46"), 0.7, 0.0, Color("5a2e1c"))
	for x: float in range(-32, 33, 8):
		var xf: float = float(x)
		bt.box(Vector3(xf, ROOF - 1.45, 0.0), Vector3(0.22, 0.22, 40.0), steel)
		bt.box(Vector3(xf, ROOF - 0.12, 0.0), Vector3(0.22, 0.22, 40.0), steel)
		var z: float = -20.0
		var k: int = 0
		while z < 20.0 - 0.01:
			bt.box(Vector3(xf, ROOF - 0.8, z), Vector3(0.12, 1.3, 0.12), steel)
			var za: float = z
			var zb: float = z + 4.0
			if k % 2 == 0:
				bt.pipe(Vector3(xf, ROOF - 1.45, za), Vector3(xf, ROOF - 0.12, zb), 0.05, steel, 4)
			else:
				bt.pipe(Vector3(xf, ROOF - 0.12, za), Vector3(xf, ROOF - 1.45, zb), 0.05, steel, 4)
			z += 4.0
			k += 1
	for z: float in range(-18, 19, 4):
		bt.box(Vector3(0.0, ROOF - 0.08, float(z)), Vector3(80.0, 0.14, 0.14), steel)
	var roof_node: Node3D = bt.commit(lvl, "Roof")
	roof_node.name = "Roof"
	# the skylight frames (broken glass), no shadow so moonlight falls through
	var frames: Array[Transform3D] = []
	for x: float in SKYLIGHTS_X:
		for z: float in SKYLIGHTS_Z:
			frames.append(Transform3D(Basis.IDENTITY, Vector3(x, ROOF + 0.45, z)))
	WhGeo.kit_multi(lvl, lvl.kit(), "skylight_frame_broken", frames, "Skylights", {}, false)


# ----------------------------------------------------------------------------------------------------------- catwalks

static func _catwalks(lvl: WarehouseLevel, bt: WhGeo.Batch, sb: StaticBody3D) -> void:
	# the DIY quarter pipe along the west wall: its deck is the west catwalk
	var qp: Node3D = QuarterPipe.build(22.0, 3.0, CAT_Y - FL, 1.5)
	WhGeo.reskin(qp, WhGeo.mat("plywood", PLY, 0.4, 0.2))
	lvl.put(qp, Vector3(-40.0, FL, 16.0), 90.0, "DIYQuarter")
	lvl.add_child(PieceKit.gap_zone("qp_lip", Vector3(-38.9, CAT_Y - 0.6, -6.0), Vector3(1.4, 1.4, 22.0)))
	lvl.add_child(PieceKit.gap_zone("qp_high", Vector3(-39.6, CAT_Y + 1.0, -6.0), Vector3(2.8, 5.0, 22.0)))
	var grate := WhGeo.mat("rust", Color("50545b"), 0.6, 0.0, Color("6a3a20"))
	var yellow := WhGeo.mat("paint", SAFETY, 0.55, 0.0, Color("4a3624"))
	var dk: float = 0.25
	# north catwalk (split where the stairs come up) and the west leg joining the quarter pipe's deck
	for seg: Vector2 in [Vector2(-40.0, -10.0), Vector2(-7.0, 28.0)]:
		WhGeo.block(bt, sb, Vector3(seg.x, CAT_Y - dk, -20.0), Vector3(seg.y - seg.x, dk, 2.0), grate)
	WhGeo.block(bt, sb, Vector3(-40.0, CAT_Y - dk, -18.0), Vector3(1.5, dk, 12.0), grate)
	# posts under the catwalks
	for x: float in range(-34, 27, 6):
		if float(x) > -11.0 and float(x) < -6.0:
			continue
		WhGeo.block(bt, sb, Vector3(float(x) - 0.08, FL, -18.3), Vector3(0.16, CAT_Y - dk - FL, 0.16), grate)
	for z: float in [-14.0, -9.0]:
		WhGeo.block(bt, sb, Vector3(-38.7, FL, z - 0.08), Vector3(0.16, CAT_Y - dk - FL, 0.16), grate)
	# the end platform and the plywood ramp up to it
	WhGeo.block(bt, sb, Vector3(28.0, FL, -20.0), Vector3(6.0, CAT_Y - FL, 5.0), WhGeo.mat("rust", Color("4a4e55"), 0.7, 0.5, Color("6a3a20"), 1.0, FL))
	bt.box_min(Vector3(28.0, CAT_Y - 0.002, -20.0), Vector3(6.0, 0.004, 5.0), grate)
	var ply := WhGeo.mat("plywood", PLY, 0.5, 0.2)
	WhOutdoor.wedge(sb, bt, Rect2(28.0, -15.0, 6.0, 12.0), FL, CAT_Y, Vector3.FORWARD, ply, WhGeo.mat("plywood", Color("8a6a48"), 0.6, 0.3))
	# guard rails: the north catwalk's front rail, the west leg's rail, the platform's east rail and the ramp's handrail
	var rails: Array = [
		[Vector3(-38.5, CAT_Y + 1.0, -18.05), Vector3(-10.15, CAT_Y + 1.0, -18.05)],
		[Vector3(-6.85, CAT_Y + 1.0, -18.05), Vector3(27.9, CAT_Y + 1.0, -18.05)],
		[Vector3(-38.55, CAT_Y + 1.0, -17.9), Vector3(-38.55, CAT_Y + 1.0, -6.6)],
		[Vector3(33.95, CAT_Y + 1.0, -19.9), Vector3(33.95, CAT_Y + 1.0, -15.1)],
		[Vector3(28.08, FL + 0.95, -3.4), Vector3(28.08, CAT_Y + 0.95, -14.9)],
	]
	var names: Array[String] = ["CatwalkRailW", "CatwalkRailE", "CatwalkRailWest", "PlatformRail", "RampRail"]
	for i: int in rails.size():
		var a: Vector3 = rails[i][0]
		var b: Vector3 = rails[i][1]
		bt.pipe(a, b, 0.045, yellow, 8)
		bt.pipe(a - Vector3(0, 0.5, 0), b - Vector3(0, 0.5, 0), 0.03, yellow, 6)
		var n: int = maxi(int(a.distance_to(b) / 2.0), 1)
		for k: int in n + 1:
			var p: Vector3 = a.lerp(b, float(k) / float(n))
			bt.pipe(p - Vector3(0, 1.0, 0), p, 0.03, yellow, 6)
		WhGeo.grind(lvl, PackedVector3Array([a, b]), "rail", names[i])
	# toe boards along the catwalk front (visual)
	bt.box_min(Vector3(-40.0, CAT_Y, -18.08), Vector3(30.0, 0.12, 0.04), yellow)
	bt.box_min(Vector3(-7.0, CAT_Y, -18.08), Vector3(35.0, 0.12, 0.04), yellow)
	# the stairs down from the catwalk
	var st: Node3D = StairSet.build(3.0, 2.0, 13, (CAT_Y - FL) / 13.0, 0.42, "cw_stair")
	WhGeo.reskin(st, WhGeo.mat("rust", Color("50545b"), 0.6, 0.2, Color("6a3a20"), 1.0, FL))
	lvl.put(st, Vector3(-10.0, FL, -20.0), 0.0, "CatwalkStairs")
	lvl.add_child(PieceKit.gap_zone("cw_rail_a", Vector3(12.0, CAT_Y + 0.75, -18.35), Vector3(4.0, 1.2, 0.6)))
	lvl.add_child(PieceKit.gap_zone("cw_rail_b", Vector3(-5.0, CAT_Y + 0.75, -18.35), Vector3(4.0, 1.2, 0.6)))
	# the stair gap's own zones: off the head of the flight (in the air) and the floor past its foot
	lvl.add_child(PieceKit.gap_zone("cw_stair_air", Vector3(-10.0, CAT_Y + 0.3, -17.9), Vector3(3.0, 2.5, 1.0)))
	lvl.add_child(PieceKit.gap_zone("cw_stair_land", Vector3(-10.0, FL, -13.2), Vector3(3.0, 1.8, 5.0)))


# -------------------------------------------------------------------------------------------------------------- racks

static func _racks(lvl: WarehouseLevel, bt: WhGeo.Batch, sb: StaticBody3D) -> void:
	var plinth := WhGeo.mat("concrete", Color("8a8780"), 0.6, 0.5, Color(0, 0, 0, 0), 1.0, FL)
	var edge := WhGeo.mat("paint", SAFETY, 0.6, 0.1, Color("4a3624"))
	var upright := WhGeo.mat("paint", Color("2f5f9a"), 0.6, 0.2, Color("5a2e1c"))
	var beam := WhGeo.mat("paint", Color("d9632a"), 0.6, 0.1, Color("5a2e1c"))
	var pallets: Array[Transform3D] = []
	var ph: float = 0.45
	for r: Vector2 in [Vector2(-26.0, -3.0), Vector2(3.0, 26.0)]:
		var x0: float = r.x
		var x1: float = r.y
		WhGeo.block(bt, sb, Vector3(x0, FL, 7.0), Vector3(x1 - x0, ph, 1.4), plinth)
		bt.box_min(Vector3(x0, FL + ph - 0.06, 6.98), Vector3(x1 - x0, 0.062, 0.06), edge)
		bt.box_min(Vector3(x0, FL + ph - 0.06, 8.36), Vector3(x1 - x0, 0.062, 0.06), edge)
		for z: float in [7.0, 8.4]:
			WhGeo.grind(lvl, PackedVector3Array([Vector3(x0, FL + ph, z), Vector3(x1, FL + ph, z)]), "ledge", "RackLedge")
		WhGeo.solid_min(sb, Vector3(x0 + 0.1, FL + ph, 7.35), Vector3(x1 - x0 - 0.2, 4.8, 0.7))
		var bays: int = int((x1 - x0 - 0.4) / 2.7)
		var step: float = (x1 - x0 - 0.4) / float(bays)
		for i: int in bays + 1:
			var x: float = x0 + 0.2 + float(i) * step
			for z: float in [7.4, 8.0]:
				bt.box(Vector3(x, FL + ph + 2.4, z), Vector3(0.09, 4.8, 0.09), upright)
		for lv: float in [1.6, 3.2, 4.7]:
			for z: float in [7.4, 8.0]:
				bt.box(Vector3((x0 + x1) * 0.5, FL + ph + lv - 0.07, z), Vector3(x1 - x0 - 0.3, 0.14, 0.06), beam)
			if lv > 4.0:
				continue
			for i: int in bays:
				var xc: float = x0 + 0.2 + (float(i) + 0.5) * step
				for k: int in 2:
					if (i * 3 + int(lv) + k) % 5 == 4:
						continue
					pallets.append(Transform3D(Basis.IDENTITY, Vector3(xc + (float(k) - 0.5) * 1.24, FL + ph + lv, 7.7)))
	# pallets standing on each beam level (and on the plinth's first level)
	WhGeo.kit_multi(lvl, lvl.kit(), "pallet_stack", pallets, "RackPallets")
	lvl.add_child(PieceKit.gap_zone("rack_a_end", Vector3(-5.0, FL + 0.2, 6.6), Vector3(1.8, 1.5, 2.2)))
	lvl.add_child(PieceKit.gap_zone("rack_b_start", Vector3(3.2, FL + 0.2, 6.6), Vector3(1.8, 1.5, 2.2)))


# ---------------------------------------------------------------------------------------------------- the pallet gap

## Two pallet boxes 1 m tall with a 4 m gap: a plywood bank up onto box A from the west, a bank down off box B to
## the east. Long edges are ledges.
static func _pallet_gap(lvl: WarehouseLevel, bt: WhGeo.Batch, sb: StaticBody3D) -> void:
	var h: float = 1.0
	var top := WhGeo.mat("plywood", Color("a07c55"), 0.5, 0.2)
	var side := WhGeo.mat("plywood", Color("7a5c3e"), 0.7, 0.4, Color(0, 0, 0, 0), 0.6, FL)
	var ply := WhGeo.mat("plywood", PLY, 0.5, 0.2)
	var z0: float = -7.0
	var z1: float = -3.0
	for bx: Vector2 in [Vector2(-26.0, -20.0), Vector2(-16.0, -10.0)]:
		WhGeo.solid_min(sb, Vector3(bx.x, FL, z0), Vector3(bx.y - bx.x, h, z1 - z0))
		bt.box_min(Vector3(bx.x, FL, z0), Vector3(bx.y - bx.x, h - 0.06, z1 - z0), side)
		bt.box_min(Vector3(bx.x, FL + h - 0.06, z0), Vector3(bx.y - bx.x, 0.06, z1 - z0), top)
		# pallet slats on the long faces
		var x: float = bx.x + 0.15
		while x < bx.y - 0.1:
			for zz: float in [z0 - 0.02, z1 + 0.02]:
				bt.box(Vector3(x + 0.6, FL + 0.5, zz), Vector3(1.1, 0.12, 0.03), WhGeo.mat("plywood", Color("c09a68"), 0.4, 0.2))
			x += 1.2
		for z: float in [z0, z1]:
			WhGeo.grind(lvl, PackedVector3Array([Vector3(bx.x, FL + h, z), Vector3(bx.y, FL + h, z)]), "ledge", "PalletLedge")
	WhOutdoor.wedge(sb, bt, Rect2(-30.0, z0, 4.0, z1 - z0), FL, FL + h, Vector3.RIGHT, ply, side)
	WhOutdoor.wedge(sb, bt, Rect2(-10.0, z0, 4.0, z1 - z0), FL, FL + h, Vector3.LEFT, ply, side)
	lvl.add_child(PieceKit.gap_zone("pal_a", Vector3(-20.0, FL + 0.9, z0), Vector3(1.4, 3.2, z1 - z0)))
	lvl.add_child(PieceKit.gap_zone("pal_b", Vector3(-17.0, FL + 1.1, z0), Vector3(1.0, 3.0, z1 - z0)))


# ------------------------------------------------------------------------------------------------- the forklift hop

static func _forklift(lvl: WarehouseLevel, bt: WhGeo.Batch, sb: StaticBody3D) -> void:
	# the forklift parked across the east aisle (forks north), a pallet up on the forks, and a plywood kicker 4 m west
	# of it: the line runs west to east, over the forklift and on out of the east door into the yard
	var k: LevelKit = lvl.kit()
	var xf := Transform3D(Basis.IDENTITY, Vector3(14.0, FL, -1.5))
	var fl: Node3D = k.visual("forklift")
	fl.transform = xf
	fl.name = "Forklift"
	lvl.add_child(fl)
	WhGeo.kit_solids(sb, k, "forklift", xf)
	var pal: Node3D = k.visual("pallet_stack")
	pal.transform = Transform3D(Basis.IDENTITY, Vector3(14.0, FL + 0.9, -3.0))
	pal.name = "ForkPallet"
	lvl.add_child(pal)
	WhGeo.solid(sb, Vector3(14.0, FL + 1.55, -3.0), Vector3(1.2, 1.6, 1.0))
	var kick: Node3D = Kicker.build(3.0, 2.4, 0.9)
	WhGeo.reskin(kick, WhGeo.mat("plywood", PLY, 0.5, 0.2))
	lvl.put(kick, Vector3(10.0, FL, -3.4), -90.0, "ForkKicker")
	lvl.add_child(PieceKit.gap_zone("fork_a", Vector3(10.3, FL + 1.0, -3.7), Vector3(2.0, 4.5, 3.6)))
	lvl.add_child(PieceKit.gap_zone("fork_b", Vector3(15.3, FL + 0.6, -3.7), Vector3(1.6, 4.5, 3.6)))
	var hatch := WhGeo.mat("paint", SAFETY, 0.7, 0.4, Color("4a3624"))
	for i: int in 8:
		bt.box(Vector3(11.0 + float(i) * 0.9, FL + 0.004, 0.9), Vector3(0.3, 0.008, 0.9), hatch, WhGeo.yaw(30.0))


# --------------------------------------------------------------------------------------------- centre and odds/ends

static func _centre(lvl: WarehouseLevel, bt: WhGeo.Batch, sb: StaticBody3D) -> void:
	# the spine (plywood), north-east of the forklift
	_spine(lvl, bt, sb)  # x 16..26, z -11.8..-7.4, ridge at z -9.6
	lvl.add_child(PieceKit.gap_zone("spine_n", Vector3(16.0, FL + 1.6, -10.8), Vector3(10.0, 4.4, 1.1)))
	lvl.add_child(PieceKit.gap_zone("spine_s", Vector3(16.0, FL + 1.6, -9.5), Vector3(10.0, 4.4, 1.1)))
	# the conveyor (side rails grindable)
	var steel := WhGeo.mat("rust", Color("50545b"), 0.6, 0.2, Color("6a3a20"))
	var roller := WhGeo.mat("paint", Color("8c9096"), 0.5, 0.0)
	var cz: float = 13.0
	var cx0: float = -33.0
	var cx1: float = -20.0
	var ch: float = 0.85
	WhGeo.solid_min(sb, Vector3(cx0, FL, cz - 0.5), Vector3(cx1 - cx0, ch, 1.0))
	bt.box_min(Vector3(cx0, FL + ch - 0.18, cz - 0.5), Vector3(cx1 - cx0, 0.18, 0.08), steel)
	bt.box_min(Vector3(cx0, FL + ch - 0.18, cz + 0.42), Vector3(cx1 - cx0, 0.18, 0.08), steel)
	var x: float = cx0 + 0.15
	while x < cx1:
		bt.pipe(Vector3(x, FL + ch - 0.07, cz - 0.42), Vector3(x, FL + ch - 0.07, cz + 0.42), 0.05, roller, 6)
		x += 0.3
	x = cx0 + 0.4
	while x < cx1:
		for zz: float in [cz - 0.42, cz + 0.42]:
			bt.box(Vector3(x, FL + (ch - 0.18) * 0.5, zz), Vector3(0.08, ch - 0.18, 0.08), steel)
		x += 2.0
	for zz: float in [cz - 0.5, cz + 0.5]:
		WhGeo.grind(lvl, PackedVector3Array([Vector3(cx0, FL + ch, zz), Vector3(cx1, FL + ch, zz)]), "ledge", "ConveyorRail")
	# a fallen I-beam on two blocks (grindable)
	var bz: float = 11.5
	WhGeo.solid_min(sb, Vector3(22.0, FL, bz - 0.2), Vector3(12.0, 0.5, 0.4))
	bt.box_min(Vector3(22.0, FL + 0.38, bz - 0.2), Vector3(12.0, 0.12, 0.4), WhGeo.mat("rust", Color("5a4d44"), 0.95, 0.0))
	bt.box_min(Vector3(22.0, FL + 0.18, bz - 0.06), Vector3(12.0, 0.2, 0.12), WhGeo.mat("rust", Color("5a4d44"), 0.95, 0.0))
	for bx: float in [23.5, 32.5]:
		bt.box_min(Vector3(bx - 0.4, FL, bz - 0.35), Vector3(0.8, 0.18, 0.7), WhGeo.mat("concrete", Color("8a8780"), 0.5, 0.3))
	WhGeo.grind(lvl, PackedVector3Array([Vector3(22.0, FL + 0.5, bz), Vector3(34.0, FL + 0.5, bz)]), "rail", "BeamRail")
	# the pallet pad (manual pad), its long edges grindable
	var pad := Rect2(-14.0, 12.0, 6.0, 4.0)
	var ph: float = 0.3
	WhGeo.solid_min(sb, Vector3(pad.position.x, FL, pad.position.y), Vector3(pad.size.x, ph, pad.size.y))
	bt.box_min(Vector3(pad.position.x, FL, pad.position.y), Vector3(pad.size.x, ph - 0.03, pad.size.y), WhGeo.mat("plywood", Color("8a6a48"), 0.6, 0.3))
	bt.box_min(Vector3(pad.position.x, FL + ph - 0.03, pad.position.y), Vector3(pad.size.x, 0.03, pad.size.y), WhGeo.mat("plywood", Color("b48a5a"), 0.5, 0.2))
	for z: float in [pad.position.y, pad.end.y]:
		WhGeo.grind(lvl, PackedVector3Array([Vector3(pad.position.x, FL + ph, z), Vector3(pad.end.x, FL + ph, z)]), "ledge", "PadEdge")
	lvl.add_child(PieceKit.gap_zone("pad_a", Vector3(pad.position.x, FL + ph, pad.position.y), Vector3(3.0, 1.5, pad.size.y)))
	lvl.add_child(PieceKit.gap_zone("pad_b", Vector3(pad.end.x - 0.6, FL + ph, pad.position.y), Vector3(0.6, 1.5, pad.size.y)))


## The plywood A-frame (bank to bank over a steel ridge coping), north-east of the forklift: x 16..26, ridge at z -9.6.
## Two 28 degree banks rather than a vert spine, so a fast line pops off one side and lands on the other.
static func _spine(lvl: WarehouseLevel, bt: WhGeo.Batch, sb: StaticBody3D) -> void:
	var ply := WhGeo.mat("plywood", PLY, 0.45, 0.2)
	var h: float = 1.2
	WhOutdoor.wedge(sb, bt, Rect2(16.0, -9.6, 10.0, 2.2), FL, FL + h, Vector3.FORWARD, ply, ply)
	WhOutdoor.wedge(sb, bt, Rect2(16.0, -11.8, 10.0, 2.2), FL, FL + h, Vector3.BACK, ply, ply)
	var steel := WhGeo.mat("rust", Color("8a8e94"), 0.35, 0.6, Color("5a3a24"))
	var a := Vector3(16.0, FL + h, -9.6)
	var b := Vector3(26.0, FL + h, -9.6)
	bt.pipe(a, b, 0.05, steel)
	WhGeo.grind(lvl, PackedVector3Array([a, b]), "rail", "SpineCoping")


## Yellow aisle lines and hazard paint on the floor (visual).
static func _floor_paint(bt: WhGeo.Batch) -> void:
	var paint := WhGeo.mat("paint", Color("c99a2a"), 0.85, 0.0, Color("3a3430"))
	var y: float = FL + 0.004
	for z: float in [4.0, 5.2]:
		bt.box(Vector3(0.0, y, z), Vector3(66.0, 0.008, 0.12), paint)
	for x: float in [-34.0, 36.0]:
		bt.box(Vector3(x, y, 0.0), Vector3(0.12, 0.008, 24.0), paint)
	for x: float in [-3.6, 3.6]:
		bt.box(Vector3(x, y, 14.0), Vector3(0.12, 0.008, 11.0), paint)


static func _dressing(lvl: WarehouseLevel, bt: WhGeo.Batch, sb: StaticBody3D) -> void:
	var k: LevelKit = lvl.kit()
	# the skaters' corner: an old sofa, a burn barrel, boards against the wall
	var sofa := WhGeo.mat("paint", Color("5a2f3c"), 0.6, 0.6, Color("2e1a20"), 1.0, FL)
	WhGeo.block(bt, sb, Vector3(-33.5, FL, 18.6), Vector3(3.0, 0.45, 1.0), sofa)
	bt.box_min(Vector3(-33.5, FL + 0.45, 19.3), Vector3(3.0, 0.5, 0.3), sofa)
	bt.box_min(Vector3(-33.6, FL + 0.45, 18.6), Vector3(0.25, 0.3, 1.0), sofa)
	bt.box_min(Vector3(-30.75, FL + 0.45, 18.6), Vector3(0.25, 0.3, 1.0), sofa)
	for i: int in 4:
		var bx: float = -29.2 + float(i) * 0.35
		bt.box(Vector3(bx, FL + 0.42, 19.85), Vector3(0.22, 0.8, 0.02), WhGeo.mat("paint", [Color("ff5a5f"), Color("3fd0d4"), Color("ffd23f"), Color("9b6bff")][i], 0.5, 0.0), Basis(Vector3.RIGHT, -0.18))
	var drums: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(-27.0, FL, 17.5)), Transform3D(WhGeo.yaw(40.0), Vector3(37.5, FL, -9.0)),
		Transform3D(WhGeo.yaw(10.0), Vector3(38.2, FL, -8.3)), Transform3D(WhGeo.yaw(70.0), Vector3(-37.8, FL, -18.8)),
		Transform3D(WhGeo.yaw(20.0), Vector3(-37.1, FL, -18.6)), Transform3D(WhGeo.yaw(5.0), Vector3(6.0, FL, -18.8))]
	WhGeo.kit_multi(lvl, k, "oil_drum", drums, "HallDrums", {}, false)
	for t: Transform3D in drums:
		WhGeo.kit_solids(sb, k, "oil_drum", t)
	# pallets stacked round the walls, two hiding the hole into the annex
	var pal: Array[Transform3D] = [Transform3D(WhGeo.yaw(3.0), Vector3(38.9, FL, 12.6)), Transform3D(WhGeo.yaw(-8.0), Vector3(38.8, FL + 1.38, 12.7)),
		Transform3D(WhGeo.yaw(90.0), Vector3(38.9, FL, 18.6)), Transform3D(WhGeo.yaw(0.0), Vector3(-26.0, FL, -18.9)),
		Transform3D(WhGeo.yaw(4.0), Vector3(-24.6, FL, -18.9)), Transform3D(WhGeo.yaw(85.0), Vector3(24.0, FL, 18.9)),
		Transform3D(WhGeo.yaw(-3.0), Vector3(25.4, FL, 18.9)), Transform3D(WhGeo.yaw(12.0), Vector3(25.0, FL + 1.38, 18.9))]
	WhGeo.kit_multi(lvl, k, "pallet_stack", pal, "HallPallets")
	for t: Transform3D in pal:
		WhGeo.kit_solids(sb, k, "pallet_stack", t)
	# broken glass under the skylights (visual)
	var glass := WhGeo.mat("paint", Color("9fb3b0"), 0.0, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for x: float in WhHall.SKYLIGHTS_X:
		for z: float in WhHall.SKYLIGHTS_Z:
			for i: int in 6:
				var p := Vector3(x + rng.randf_range(-2.0, 2.0) + 3.5, FL + 0.006, z + rng.randf_range(-2.0, 2.0) + 4.0)
				bt.box(p, Vector3(rng.randf_range(0.1, 0.3), 0.01, rng.randf_range(0.06, 0.2)), glass, WhGeo.yaw(rng.randf() * 180.0))


# ---------------------------------------------------------------------------------------------------------- the annex

## The secret room behind the east wall: a small raised room with a mini quarter pipe, a low ledge, old TVs, a red work
## lamp and a mannequin in the corner. The secret tape sits in the line from the hole in the wall.
static func _annex(lvl: WarehouseLevel) -> void:
	var a: Rect2 = WarehouseLevel.ANNEX
	var sb: StaticBody3D = WhGeo.body(lvl, "Annex")
	var bt := WhGeo.Batch.new()
	var face := WhGeo.mat("concrete", Color("7a7770"), 0.7, 0.8, Color(0, 0, 0, 0), 1.0, -1.0)
	WhGeo.solid_min(sb, Vector3(a.position.x, -1.0, a.position.y), Vector3(a.size.x, FL + 1.0, a.size.y))
	bt.quad(Vector3(a.position.x, FL, a.position.y), Vector3(a.position.x, FL, a.end.y), Vector3(a.end.x, FL, a.end.y), Vector3(a.end.x, FL, a.position.y), WhGeo.mat("floor", Color("4f4c4c"), 0.9, 0.9))
	WhOutdoor._face_x(bt, a.position.y, a.end.y, a.end.x, -1.0, FL, 1.0, face)
	WhOutdoor._face_z(bt, a.position.x, a.end.x, a.position.y, -1.0, FL, -1.0, face)
	WhOutdoor._face_z(bt, a.position.x, a.end.x, a.end.y, -1.0, FL, 1.0, face)
	var top: float = FL + 4.6
	var brick := WhGeo.mat("brick", Color("4e3530"), 0.9, 0.9, Color("2e2a28"), 1.0, FL)
	WhGeo.block(bt, sb, Vector3(a.end.x - 0.5, FL, a.position.y), Vector3(0.5, top - FL, a.size.y), brick)
	WhGeo.block(bt, sb, Vector3(a.position.x, FL, a.position.y), Vector3(a.size.x - 0.5, top - FL, 0.5), brick)
	WhGeo.block(bt, sb, Vector3(a.position.x, FL, a.end.y - 0.5), Vector3(a.size.x - 0.5, top - FL, 0.5), brick)
	var roof := WhGeo.mat("metal", Color("2a2c30"), 0.8, 0.0)
	for r: Rect2 in WhGeo.cut_rects(Rect2(a.position.x - 0.1, a.position.y - 0.1, a.size.x + 0.2, a.size.y + 0.2), [Rect2(44.0, 11.0, 2.0, 1.5)] as Array[Rect2]):
		bt.box_min(Vector3(r.position.x, top, r.position.y), Vector3(r.size.x, 0.25, r.size.y), roof)
	# the mini quarter pipe on the east wall, a low ledge, a kicker
	var qp: Node3D = QuarterPipe.build(8.0, 2.0, 1.8, 0.6)
	WhGeo.reskin(qp, WhGeo.mat("plywood", Color("8f6f50"), 0.7, 0.4))
	lvl.put(qp, Vector3(a.end.x - 0.5, FL, 9.0), -90.0, "AnnexQuarter")
	var ledge := WhGeo.mat("concrete", Color("8a8780"), 0.7, 0.5)
	WhGeo.block(bt, sb, Vector3(42.0, FL, 9.0), Vector3(3.0, 0.4, 0.6), ledge)
	WhGeo.grind(lvl, PackedVector3Array([Vector3(42.0, FL + 0.4, 9.6), Vector3(45.0, FL + 0.4, 9.6)]), "ledge", "AnnexLedge")
	# old TVs stacked against the south wall, glowing with static, and a skate shrine of broken boards
	var tv := WhGeo.mat("paint", Color("2a2622"), 0.4, 0.2)
	var screens: Array[MeshInstance3D] = []
	for i: int in 5:
		var p := Vector3(42.4 + float(i % 3) * 1.0, FL + 0.35 + float(i / 3) * 0.7, 19.15)
		WhGeo.block(bt, sb, p - Vector3(0.42, 0.35, 0.3), Vector3(0.84, 0.7, 0.6), tv)
		var scr := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.62, 0.48)
		scr.mesh = q
		scr.position = p + Vector3(0, 0.02, -0.305)
		scr.rotation_degrees.y = 180.0
		lvl.add_child(scr)
		screens.append(scr)
	WhLights.tv_static(lvl, screens)
	for i: int in 5:
		bt.box(Vector3(46.4 + float(i) * 0.42, FL + 1.9 + 0.1 * float(i % 2), 19.48), Vector3(0.21, 0.75, 0.02),
				WhGeo.mat("paint", [Color("ff5a8a"), Color("3fd0d4"), Color("ffd23f"), Color("6cd46c"), Color("b58cff")][i], 0.6, 0.0), Basis(Vector3.BACK, 0.3 * float(i - 2)))
	lvl.add_child(WhGeo.tag("motif_skull", 2.2, Vector3(45.0, FL + 2.6, 7.99 + 0.02), 0.0))
	lvl.add_child(WhGeo.tag("tag_spud", 2.2, Vector3(42.0, FL + 2.8, 7.99 + 0.02), 0.0))
	lvl.add_child(WhGeo.tag("throw_mochi", 3.6, Vector3(49.48, FL + 3.3, 13.0), -90.0))
	lvl.add_child(WhGeo.tag("tag_drip", 2.4, Vector3(44.0, FL + 3.2, 19.98), 180.0))
	_mannequin(lvl, Vector3(48.7, FL, 19.0), 215.0)
	bt.commit(lvl, "AnnexMesh")
	lvl.add_child(PieceKit.gap_zone("secret_door", Vector3(39.6, FL, 14.0), Vector3(1.2, 2.4, 2.5)))
	lvl.add_child(PieceKit.gap_zone("secret_room", Vector3(42.5, FL, 12.0), Vector3(3.0, 2.5, 6.5)))


## A pale, faceless shop mannequin standing in the corner (visual).
static func _mannequin(lvl: Node, p: Vector3, yaw_deg: float) -> void:
	var root := Node3D.new()
	root.name = "Mannequin"
	root.position = p
	root.rotation_degrees.y = yaw_deg
	var m: ShaderMaterial = Toon.material(Color("d8d0c8"), false)
	var parts: Array = [
		[Vector3(0, 1.55, 0), Vector3(0.22, 0.27, 0.24), "s"], [Vector3(0, 1.17, 0), Vector3(0.42, 0.55, 0.24), "b"],
		[Vector3(0, 0.82, 0), Vector3(0.36, 0.2, 0.22), "b"], [Vector3(-0.1, 0.4, 0), Vector3(0.13, 0.78, 0.13), "b"],
		[Vector3(0.1, 0.4, 0), Vector3(0.13, 0.78, 0.13), "b"], [Vector3(-0.27, 1.15, 0.05), Vector3(0.09, 0.62, 0.09), "b"],
		[Vector3(0.27, 1.15, 0.0), Vector3(0.09, 0.62, 0.09), "b"], [Vector3(0, 0.02, 0), Vector3(0.5, 0.04, 0.5), "b"],
	]
	for e: Array in parts:
		var mi := MeshInstance3D.new()
		if str(e[2]) == "s":
			var sm := SphereMesh.new()
			sm.radius = 0.12
			sm.height = 0.27
			mi.mesh = sm
		else:
			var cm := CapsuleMesh.new()
			var s: Vector3 = e[1]
			cm.radius = minf(s.x, s.z) * 0.5
			cm.height = maxf(s.y, cm.radius * 2.0)
			mi.mesh = cm
		mi.position = e[0] as Vector3
		mi.material_override = m
		root.add_child(mi)
	(root.get_child(5) as Node3D).rotation_degrees.z = -14.0
	(root.get_child(6) as Node3D).rotation_degrees = Vector3(-35.0, 0.0, 10.0)
	lvl.add_child(root)
