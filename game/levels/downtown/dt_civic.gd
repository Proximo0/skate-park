class_name DtCivic
extends RefCounted
## The CIVIC PLAZA (the centre block): City Hall on its raised terrace, the 10-stair down to the promenade with two
## handrails, a sloped hubba ledge on each side and a granite bank (with an outer hubba) on each wing; the fountain
## plaza to the west (a grindable round rim, a launch bump for the fountain gap, a pair of parallel ledges); the
## granite garden to the east (three stepped ledges, a manual pad, planters, benches); manual pads on the promenade.

const HALL_STONE := Color("eeebe3")
const HALL_SHADE := Color("d6d0c4")
const COPPER := Color("6fb7a2")
const WINDOW := Color("3d4d63")
const PAVERS := Color("97918a")
const TERRACE_TOP := Color("ddd2bd")

var lvl: Node3D
var flag_spots: Array[Vector3] = []  ## flag pole bases (DtLife hangs flags on them)
var banner_spots: Array[Transform3D] = []  ## hanging banners between the columns (position = top centre, -Z faces out)
var tree_spots: Array[Vector3] = []
var fountain_top: Vector3
var _bt := DtBatch.new()  ## granite and skate furniture
var _hall := DtBatch.new()  ## City Hall itself
var _pave := DtBatch.new()  ## paver quads (world-space surface)
var _sb: StaticBody3D
var _rails: Node3D
var _root: Node3D


func _init(level: Node3D) -> void:
	lvl = level


func build() -> void:
	_root = Node3D.new()
	_root.name = "CivicPlaza"
	lvl.add_child(_root)
	_sb = DtKit.body(_root, "CivicCollision")
	_rails = Node3D.new()
	_rails.name = "CivicRails"
	_root.add_child(_rails)
	_floor()
	_hall_building()
	_terrace()
	_stairs()
	_fountain()
	_garden()
	_promenade()
	_root.add_child(_bt.instance("CivicStone", true))
	_root.add_child(_hall.instance("CityHall", true))
	var pv: MeshInstance3D = _pave.instance("CivicPavers", false)
	pv.material_override = WorldSurface.material("pavers", PAVERS, 0.8)
	_root.add_child(pv)


## The plaza floor: warm pavers over the block's sidewalk slab (lifted off it so they never flicker).
func _floor() -> void:
	var p: float = DtPlan.P + PieceKit.FLOOR_PAD_LIFT
	var r := Rect2(-39.0, -33.0, 78.0, 52.0)
	_pave.quad(Vector3(r.position.x, p, r.position.y), Vector3(r.end.x, p, r.position.y), Vector3(r.end.x, p, r.end.y), Vector3(r.position.x, p, r.end.y), Color.WHITE, Vector3.UP)
	# the promenade: big pale granite slabs from the stairs to the street, dark granite borders
	var pr := DtBatch.new()
	var py: float = DtPlan.P + 0.012
	pr.quad(Vector3(-7.8, py, -7.6), Vector3(7.8, py, -7.6), Vector3(7.8, py, 19.0), Vector3(-7.8, py, 19.0), Color.WHITE, Vector3.UP)
	var pm: MeshInstance3D = pr.instance("Promenade", false)
	pm.material_override = WorldSurface.material("concrete", Color("a8a59f"), 1.8)
	_root.add_child(pm)
	for s: float in [-1.0, 1.0]:
		_bt.box(Vector3(s * 8.1, DtPlan.P + 0.016, 5.7), Vector3(0.6, 0.006, 26.6), DtKit.GRANITE_DARK)


func _hall_building() -> void:
	var r: Rect2 = DtPlan.HALL
	var t: float = DtPlan.P + DtPlan.TERRACE_H
	DtKit.col_box(_sb, Vector3(r.get_center().x, 8.0, r.get_center().y), Vector3(r.size.x, 16.5, r.size.y))
	# body, plinth, cornice, attic
	_hall.box_min(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, 15.0, r.size.y - 0.6), HALL_STONE)
	_hall.box_min(Vector3(r.position.x - 0.2, 0.0, r.position.y - 0.2), Vector3(r.size.x + 0.4, t + 0.6, r.size.y), HALL_SHADE)
	_hall.box_min(Vector3(r.position.x - 0.5, 14.6, r.position.y - 0.5), Vector3(r.size.x + 1.0, 0.8, r.size.y + 0.3), HALL_SHADE)
	_hall.box_min(Vector3(r.position.x + 2.0, 15.4, r.position.y + 1.0), Vector3(r.size.x - 4.0, 1.6, r.size.y - 2.5), HALL_STONE)
	# tall windows on the two wings of the front face (z = r.end.y - 0.6), two storeys
	var fz: float = r.end.y - 0.6
	for side: float in [-1.0, 1.0]:
		for i: int in 4:
			var x: float = side * (13.0 + float(i) * 2.3)
			for row: int in 2:
				var y0: float = t + 1.2 + float(row) * 5.4
				_hall.box(Vector3(x, y0 + 1.7, fz + 0.03), Vector3(1.1, 3.4, 0.08), WINDOW)
				_hall.box(Vector3(x, y0 + 3.55, fz + 0.06), Vector3(1.5, 0.3, 0.14), HALL_SHADE)
				_hall.box(Vector3(x, y0 - 0.1, fz + 0.06), Vector3(1.4, 0.18, 0.18), HALL_SHADE)
	# the portico: eight columns on the terrace, entablature, pediment
	var cz: float = r.end.y + 0.9
	for i: int in 8:
		var x: float = -10.5 + float(i) * 3.0
		_hall.cyl(Vector3(x, t, cz), 0.62, 0.35, HALL_SHADE, 12)
		_hall.cyl(Vector3(x, t + 0.35, cz), 0.48, 8.6, HALL_STONE, 12, 0.42)
		_hall.box(Vector3(x, t + 9.1, cz), Vector3(1.2, 0.35, 1.2), HALL_SHADE)
		DtKit.col_box(_sb, Vector3(x, t + 4.5, cz), Vector3(0.9, 9.0, 0.9))
		if i < 7:
			banner_spots.append(Transform3D(Basis.IDENTITY, Vector3(x + 1.5, t + 8.4, cz + 0.2)))
	_hall.box_min(Vector3(-12.2, t + 9.25, cz - 1.2), Vector3(24.4, 1.2, 2.4), HALL_SHADE)
	_hall.box_min(Vector3(-12.6, t + 10.45, cz - 1.3), Vector3(25.2, 0.35, 2.7), HALL_STONE)
	# the pediment as a prism across z (profile in x, y)
	for k: int in 2:
		var zz: float = cz - 1.3 + float(k) * 2.6
		_hall.tri(Vector3(-12.6, t + 10.8, zz), Vector3(12.6, t + 10.8, zz), Vector3(0.0, t + 14.0, zz), HALL_STONE, Vector3(0, 0, 1) if k == 1 else Vector3(0, 0, -1))
	for s: float in [-1.0, 1.0]:
		var a := Vector3(s * 12.6, t + 10.8, cz - 1.3)
		var b := Vector3(0.0, t + 14.0, cz - 1.3)
		_hall.quad(a, b, b + Vector3(0, 0, 2.6), a + Vector3(0, 0, 2.6), HALL_SHADE, Vector3(s * 3.2, 12.6, 0.0))
	_hall.quad(Vector3(-12.6, t + 10.8, cz - 1.3), Vector3(12.6, t + 10.8, cz - 1.3), Vector3(12.6, t + 10.8, cz + 1.3), Vector3(-12.6, t + 10.8, cz + 1.3), HALL_SHADE, Vector3.DOWN)
	# doors behind the columns
	for i: int in 3:
		_hall.box(Vector3(-5.0 + float(i) * 5.0, t + 2.2, fz + 0.04), Vector3(2.2, 4.4, 0.08), Color("5a3b2a"))
		_hall.box(Vector3(-5.0 + float(i) * 5.0, t + 4.6, fz + 0.06), Vector3(2.6, 0.4, 0.12), HALL_SHADE)
	# the dome: a drum with pilasters, a copper dome, a lantern and a flag mast
	var dc := Vector3(0.0, 16.9, r.get_center().y)
	_hall.cyl(dc, 7.2, 1.0, HALL_SHADE, 24)
	_hall.cyl(dc + Vector3(0, 1.0, 0), 6.6, 4.2, HALL_STONE, 24)
	for i: int in 12:
		var a: float = TAU * float(i) / 12.0
		_hall.box(dc + Vector3(cos(a) * 6.62, 3.0, sin(a) * 6.62), Vector3(0.5, 3.8, 0.5), HALL_SHADE, Basis(Vector3.UP, -a))
		_hall.box(dc + Vector3(cos(a + 0.26) * 6.6, 3.2, sin(a + 0.26) * 6.6), Vector3(0.9, 2.2, 0.1), WINDOW, Basis(Vector3.UP, -(a + 0.26) + PI * 0.5))
	_hall.cyl(dc + Vector3(0, 5.2, 0), 7.0, 0.5, HALL_SHADE, 24)
	_hall.dome(dc + Vector3(0, 5.7, 0), 6.7, COPPER, 1.0, 24, 8, 1.15)
	_hall.cyl(dc + Vector3(0, 13.3, 0), 1.2, 2.6, HALL_STONE, 12)
	_hall.dome(dc + Vector3(0, 15.9, 0), 1.35, COPPER, 1.0, 12, 4, 1.3)
	_hall.tube(dc + Vector3(0, 17.5, 0), dc + Vector3(0, 24.0, 0), 0.07, Color("d8dde4"), 6)
	flag_spots.append(dc + Vector3(0, 24.0, 0))
	# CITY HALL in bronze letters on the entablature
	var label := Label3D.new()
	label.name = "HallName"
	label.text = "CITY  HALL"
	label.font_size = 160
	label.pixel_size = 0.006
	label.modulate = Color("8a6a3a")
	label.outline_size = 0
	label.shaded = true
	label.position = Vector3(0.0, t + 9.85, cz + 1.22)
	_root.add_child(label)


## The terrace in front of City Hall: solid to its top, paved, granite cap on its side drops (grind lines), planters,
## and flag poles at its front corners.
func _terrace() -> void:
	var r: Rect2 = DtPlan.TERRACE
	var t: float = DtPlan.P + DtPlan.TERRACE_H
	DtKit.col_box(_sb, Vector3(r.get_center().x, (t - 0.5) * 0.5, r.get_center().y), Vector3(r.size.x, t + 0.5, r.size.y))
	_bt.box_min(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, t - 0.1, r.size.y), DtKit.GRANITE_DARK)
	var tp: float = t + PieceKit.FLOOR_PAD_LIFT
	_pave.quad(Vector3(r.position.x + 0.3, tp, r.position.y), Vector3(r.end.x - 0.3, tp, r.position.y), Vector3(r.end.x - 0.3, tp, r.end.y - 0.3), Vector3(r.position.x + 0.3, tp, r.end.y - 0.3), Color.WHITE, Vector3.UP)
	# the cap round the edge (sides and front)
	for s: float in [-1.0, 1.0]:
		var x: float = s * (r.size.x * 0.5 - 0.15)
		_bt.box(Vector3(x, t - 0.05, r.get_center().y), Vector3(0.34, 0.1, r.size.y), DtKit.GRANITE)
		DtKit.rail(_rails, PackedVector3Array([Vector3(s * r.size.x * 0.5, t, r.position.y + 0.5), Vector3(s * r.size.x * 0.5, t, r.end.y)]), "ledge", "TerraceSide")
		_bt.box(Vector3(s * 26.3, t - 0.05, r.end.y - 0.15), Vector3(1.4, 0.1, 0.34), DtKit.GRANITE)
		# the side drop: a zone off each side edge, and one on the plaza below
		DtKit.zone(_rails, "terrace_edge", Vector3(s * 27.0 - 0.6 if s > 0.0 else -27.6, t - 0.2, r.position.y + 1.0), Vector3(1.2, 2.2, r.size.y - 1.0))
		DtKit.zone(_rails, "terrace_floor", Vector3(s * 33.0 - 3.0, DtPlan.P, r.position.y - 1.0), Vector3(6.0, 1.6, r.size.y + 4.0))
	# planters with trees and flag poles on the terrace
	for s: float in [-1.0, 1.0]:
		tree_spots.append(DtKit.planter(_bt, _sb, _rails, Vector3(s * 20.0, 0.0, -19.5), 3.2, 3.2, 0.6, t))
		flag_spots.append(Vector3(s * 25.5, t, -14.0))
		DtKit.bench(_bt, _sb, _rails, Vector3(s * 14.0, 0.0, -16.0), Vector3(0, 0, 1), 2.6, t)
	for s: float in [-1.0, 1.0]:
		_bt.cyl(Vector3(s * 25.5, t, -14.0), 0.35, 0.3, DtKit.GRANITE)


## The 10-stair, its handrails, the hubbas and the wing banks.
func _stairs() -> void:
	var t: float = DtPlan.P + DtPlan.TERRACE_H
	var p: float = DtPlan.P
	var top_z: float = DtPlan.TERRACE.end.y
	var run: float = float(DtPlan.STAIR_STEPS) * DtPlan.STAIR_RUN
	var bot_z: float = top_z + run
	var half: float = DtPlan.STAIR_HALF
	DtKit.stairs(_bt, _sb, Vector3(0.0, 0.0, top_z), Vector3(0, 0, 1), half * 2.0, DtPlan.STAIR_STEPS, DtPlan.STAIR_RUN, t, p, DtKit.GRANITE, DtKit.GRANITE_DARK)
	# two handrails, 3 m either side of the centre line
	var slope: float = DtPlan.TERRACE_H / run
	for s: float in [-1.0, 1.0]:
		var x: float = s * 3.0
		var a0 := Vector3(x, t + 0.9, top_z - 1.0)
		var a := Vector3(x, t + 0.9, top_z)
		var b := Vector3(x, t + 0.9 - slope * (run + 0.4), bot_z + 0.4)
		var posts: Array = [Vector3(x, t, top_z - 0.8)]
		for k: int in 3:
			var z: float = top_z + 1.2 + float(k) * 1.6
			posts.append(Vector3(x, t - slope * (z - top_z), z))
		DtKit.handrail(_bt, _rails, a0, a, b, posts, "HallRail")
		DtKit.zone(_rails, "rail_top", Vector3(x - 0.6, a.y - 0.4, top_z - 1.0), Vector3(1.2, 1.6, 1.4))
		DtKit.zone(_rails, "rail_bottom", Vector3(x - 0.6, b.y - 0.6, bot_z - 1.6), Vector3(1.2, 1.8, 2.2))
	# hubbas flanking the stairs, banks on the wings, outer hubbas closing the banks
	for s: float in [-1.0, 1.0]:
		var hx: float = s * (half + 0.5)
		DtKit.hubba(_bt, _sb, _rails, Vector3(hx, 0.0, top_z - 2.0), Vector3(0, 0, 1), 1.0, 2.0, run, t, 0.45, p, 0.45, DtKit.GRANITE, "Hubba")
		DtKit.zone(_rails, "hubba_top", Vector3(hx - 0.6, t + 0.35, top_z - 2.0), Vector3(1.2, 1.6, 1.6))
		DtKit.zone(_rails, "hubba_bottom", Vector3(hx - 0.6, p + 0.3, bot_z - 1.6), Vector3(1.2, 1.8, 1.6))
		var bx: float = s * (half + 1.0 + 8.0)
		DtKit.bank(_bt, _sb, _rails, Vector3(bx, 0.0, top_z), Vector3(0, 0, 1), 16.0, run, t, p, DtKit.GRANITE_WARM, 0.0, "WingBank")
		DtKit.zone(_rails, "bank_lip", Vector3(bx - 8.0, t, top_z - 0.8), Vector3(16.0, 2.4, 1.8))
		var ox: float = s * (half + 1.0 + 16.0 + 0.3)
		DtKit.hubba(_bt, _sb, _rails, Vector3(ox, 0.0, top_z - 0.6), Vector3(0, 0, 1), 0.6, 0.6, run, t, 0.4, p, 0.4, DtKit.GRANITE_DARK, "OuterHubba")
	# the stair gap zones: above the top nosing and the landing beyond the bottom step
	DtKit.zone(_rails, "hall_top", Vector3(-half, t + 0.2, top_z - 0.8), Vector3(half * 2.0, 1.8, 1.4))
	DtKit.zone(_rails, "hall_bottom", Vector3(-half, p, bot_z + 0.3), Vector3(half * 2.0, 1.6, 6.0))


## One seamless closed ring (top annulus, outer and inner wall) as a front-face trimesh: no box corners or shared top edges.
func _ring_collision(c: Vector3, r_in: float, r_out: float, y_top: float, y_bot: float, n: int) -> void:
	var pts := PackedVector3Array()
	for i: int in n:
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var ot0: Vector3 = c + d0 * r_out + Vector3.UP * y_top
		var ot1: Vector3 = c + d1 * r_out + Vector3.UP * y_top
		var it0: Vector3 = c + d0 * r_in + Vector3.UP * y_top
		var it1: Vector3 = c + d1 * r_in + Vector3.UP * y_top
		var ob0 := Vector3(ot0.x, y_bot, ot0.z)
		var ob1 := Vector3(ot1.x, y_bot, ot1.z)
		var ib0 := Vector3(it0.x, y_bot, it0.z)
		var ib1 := Vector3(it1.x, y_bot, it1.z)
		var dm: Vector3 = (d0 + d1).normalized()
		_tri(pts, it0, ot0, ot1, Vector3.UP)
		_tri(pts, it0, ot1, it1, Vector3.UP)
		_tri(pts, ot0, ob0, ob1, dm)
		_tri(pts, ot0, ob1, ot1, dm)
		_tri(pts, it0, ib0, ib1, -dm)
		_tri(pts, it0, ib1, it1, -dm)
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(pts)
	shape.backface_collision = false
	cs.shape = shape
	_sb.add_child(cs)


## Append a triangle wound so its front (clockwise in Godot) faces `out`.
func _tri(pts: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) > 0.0:
		pts.append_array(PackedVector3Array([a, c, b]))
	else:
		pts.append_array(PackedVector3Array([a, b, c]))


## The fountain plaza (west): the round rim, water, the kit fountain in the middle with jets, a launch bump on the
## east side for the fountain gap, two parallel ledges to the south, benches round the west edge.
func _fountain() -> void:
	var c: Vector3 = DtPlan.FOUNTAIN
	var p: float = DtPlan.P
	var r: float = DtPlan.FOUNTAIN_R
	# the kit's ring_ledge collides as 28 overlapping angled boxes (their top edges and corners are snag seams); the visuals and
	# the grind rail are kept, its boxes go to a scratch body and one seamless trimesh ring takes over the collision
	var scratch := StaticBody3D.new()
	DtKit.ring_ledge(_bt, scratch, _rails, c, r - 0.6, r, 0.55, p, 28, DtKit.GRANITE, DtKit.GRANITE_WARM, "FountainRim")
	scratch.free()
	_ring_collision(c, r - 0.6, r, p + 0.55, p - DtKit.SINK, 28)
	# basin floor (blue tiles) and the water
	_bt.cyl(Vector3(c.x, p + 0.004, c.z), r - 0.55, 0.01, Color("3f7fa6"), 28)
	var water := MeshInstance3D.new()
	water.name = "FountainWater"
	var cm := CylinderMesh.new()
	cm.top_radius = r - 0.58
	cm.bottom_radius = r - 0.58
	cm.height = 0.02
	cm.radial_segments = 32
	cm.rings = 1
	water.mesh = cm
	water.position = Vector3(c.x, p + 0.32, c.z)
	var wm := ShaderMaterial.new()
	wm.shader = load("res://game/levels/downtown/dt_water.gdshader") as Shader
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(water)
	# the centrepiece (kit fountain, mesh collision) on a granite drum
	_bt.cyl(Vector3(c.x, p, c.z), 2.5, 0.3, DtKit.GRANITE_DARK, 20)
	var kit: LevelKit = LevelKit.open("downtown")
	kit.place(_root, "fountain", Vector3(c.x, p + 0.3, c.z), 0.0, {"scale": 1.0})
	fountain_top = Vector3(c.x, p + 3.0, c.z)
	_root.add_child(_jets(c, p, r))
	# the launch bump east of the rim, facing west along a chord 4.2 m south of the centre (clear of the
	# centrepiece), and the gap zones: the lip, and the air over the far rim
	var ch: float = c.z + 4.2
	DtKit.kicker(_bt, _sb, _rails, Vector3(c.x + 6.55, 0.0, ch), Vector3(-1, 0, 0), 2.4, 2.0, 0.7, p, DtKit.GRANITE_WARM)
	DtKit.zone(_rails, "fountain_e", Vector3(c.x + 3.2, p + 0.3, ch - 1.3), Vector3(3.0, 4.0, 2.6))
	DtKit.zone(_rails, "fountain_w", Vector3(c.x - 4.6, p + 0.75, ch - 1.6), Vector3(1.6, 4.0, 3.2))
	# two parallel ledges south of the fountain (ledge to ledge), benches on the west edge
	DtKit.ledge(_bt, _sb, _rails, Vector3(-34.0, 0.0, 13.0), Vector3(-21.0, 0.0, 13.0), 0.7, 0.5, p, DtKit.GRANITE_DARK, DtKit.GRANITE, "PairLedgeA")
	DtKit.ledge(_bt, _sb, _rails, Vector3(-34.0, 0.0, 16.6), Vector3(-21.0, 0.0, 16.6), 0.7, 0.6, p, DtKit.GRANITE_DARK, DtKit.GRANITE, "PairLedgeB")
	DtKit.zone(_rails, "pair_a", Vector3(-34.0, p + 0.4, 12.6), Vector3(13.0, 1.6, 0.8))
	DtKit.zone(_rails, "pair_b", Vector3(-34.0, p + 0.5, 16.2), Vector3(13.0, 1.6, 0.8))
	for z: float in [-4.0, 2.0]:
		DtKit.bench(_bt, _sb, _rails, Vector3(-38.0, 0.0, z), Vector3(1, 0, 0), 2.6, p)
	# a long ledge on the north side of the fountain plaza, under the terrace's west drop
	DtKit.ledge(_bt, _sb, _rails, Vector3(-37.0, 0.0, -6.5), Vector3(-29.0, 0.0, -6.5), 0.8, 0.5, p, DtKit.GRANITE_DARK, DtKit.GRANITE, "NorthLedge")
	for pos: Vector3 in [Vector3(-36.0, 0.0, -28.0), Vector3(-36.0, 0.0, -18.0)]:
		tree_spots.append(DtKit.planter(_bt, _sb, _rails, pos, 3.0, 3.0, 0.55, p))


## Water jets: eight arcs from the rim toward the centre and a plume off the top, one particle system.
func _jets(c: Vector3, p: float, r: float) -> CPUParticles3D:
	var j := CPUParticles3D.new()
	j.name = "Jets"
	j.amount = 160
	j.lifetime = 1.1
	j.preprocess = 1.1
	j.emission_shape = CPUParticles3D.EMISSION_SHAPE_DIRECTED_POINTS
	var pts := PackedVector3Array()
	var nrm := PackedVector3Array()
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0
		pts.append(Vector3(cos(a) * (r - 0.7), p + 0.45, sin(a) * (r - 0.7)))
		nrm.append(Vector3(-cos(a) * 0.45, 1.0, -sin(a) * 0.45).normalized())
	for i: int in 4:
		pts.append(Vector3(0.0, p + 2.75, 0.0))
		var a: float = TAU * float(i) / 4.0
		nrm.append(Vector3(cos(a) * 0.15, 1.0, sin(a) * 0.15).normalized())
	j.emission_points = pts
	j.emission_normals = nrm
	j.direction = Vector3(0, 1, 0)
	j.spread = 4.0
	j.initial_velocity_min = 4.6
	j.initial_velocity_max = 5.2
	j.gravity = Vector3(0, -9.8, 0)
	j.scale_amount_min = 0.5
	j.scale_amount_max = 0.9
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	ramp.set_color(1, Color(0.85, 0.95, 1.0, 0.0))
	j.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = SteamVent.puff_texture()
	q.material = m
	j.mesh = q
	j.position = Vector3(c.x, 0.0, c.z)
	j.local_coords = true
	j.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return j


## The granite garden (east): three stepped ledges, a manual pad, planters with trees, benches.
func _garden() -> void:
	var p: float = DtPlan.P
	var hs: Array[float] = [0.45, 0.55, 0.65]
	for i: int in 3:
		var z: float = -1.0 + float(i) * 4.4
		DtKit.ledge(_bt, _sb, _rails, Vector3(14.0, 0.0, z), Vector3(30.0, 0.0, z), 0.8, hs[i], p, DtKit.GRANITE_DARK, DtKit.GRANITE, "StepLedge%d" % i)
	DtKit.zone(_rails, "step_ledge_a", Vector3(14.0, p + 0.3, -1.5), Vector3(16.0, 1.6, 1.0))
	DtKit.zone(_rails, "step_ledge_c", Vector3(14.0, p + 0.5, 7.3), Vector3(16.0, 1.6, 1.0))
	DtKit.zone(_rails, "step_ledge_b", Vector3(14.0, p + 0.4, 2.9), Vector3(16.0, 1.6, 1.0))
	DtKit.manual_pad(_bt, _sb, _rails, Vector3(14.0, 0.0, 14.0), Vector3(22.0, 0.0, 14.0), 2.6, 0.3, p, DtKit.GRANITE_WARM, "GardenPad")
	DtKit.zone(_rails, "garden_pad_a", Vector3(14.0, p + 0.3, 12.7), Vector3(4.0, 1.5, 2.6))
	DtKit.zone(_rails, "garden_pad_b", Vector3(21.5, p + 0.3, 12.7), Vector3(0.6, 1.5, 2.6))
	for pos: Vector3 in [Vector3(35.0, 0.0, -3.0), Vector3(35.0, 0.0, 9.0), Vector3(35.0, 0.0, -18.0), Vector3(35.0, 0.0, -28.0)]:
		tree_spots.append(DtKit.planter(_bt, _sb, _rails, pos, 3.0, 3.0, 0.55, p))
	for x: float in [26.0, 31.0]:
		DtKit.bench(_bt, _sb, _rails, Vector3(x, 0.0, 15.5), Vector3(0, 0, -1), 2.6, p)


## The promenade: two manual pads either side of the stair line, benches facing it.
func _promenade() -> void:
	var p: float = DtPlan.P
	for s: float in [-1.0, 1.0]:
		var x: float = s * 5.25
		DtKit.manual_pad(_bt, _sb, _rails, Vector3(x, 0.0, 3.0), Vector3(x, 0.0, 9.0), 2.5, 0.3, p, DtKit.GRANITE_WARM, "PromPad")
	DtKit.zone(_rails, "prom_pad_a", Vector3(-6.5, p + 0.3, 3.0), Vector3(2.5, 1.5, 3.0))
	DtKit.zone(_rails, "prom_pad_b", Vector3(-6.5, p + 0.3, 8.5), Vector3(2.5, 1.5, 0.5))
