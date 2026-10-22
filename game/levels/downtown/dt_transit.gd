class_name DtTransit
extends RefCounted
## THE LINE: two monorail beams along DtPlan.MONO_Z on T-pylons, over both avenues and the south blocks; their top
## edges are 200 m grind lines and a train runs on each. Central Station: a platform at beam height (one hop off the
## south beam), a canopy, and the 24-stair down to the transit plaza with two handrails and sloped cheek ledges. The
## plaza under the line (ledges, benches, bus stops on the street) and the transit plaza south of the station
## (runout ledges, a red steel arc you can grind, planters, a hot-dog cart).

const BEAM := Color("c9ccd1")
const BEAM_SIDE := Color("aeb3ba")
const PYLON := Color("b9bcc2")
const STATION_STONE := Color("d4cdbf")
const GLASS := Color("7fa7c0")
const CANOPY := Color("2d6f8e")
const PLAZA := Color("97938c")

var lvl: Node3D
var trains: Array[DtTrain] = []
var tree_spots: Array[Vector3] = []
var drop_pad: Vector3 = Vector3(17.0, DtPlan.P, 71.5)
var platform_xf: Transform3D
var _bt := DtBatch.new()
var _line := DtBatch.new()
var _pave := DtBatch.new()
var _sb: StaticBody3D
var _rails: Node3D
var _root: Node3D


func _init(level: Node3D) -> void:
	lvl = level


func build() -> void:
	_root = Node3D.new()
	_root.name = "TheLine"
	lvl.add_child(_root)
	_sb = DtKit.body(_root, "LineCollision")
	_rails = Node3D.new()
	_rails.name = "LineRails"
	_root.add_child(_rails)
	_beams()
	_station()
	_under_line()
	_south_plaza()
	_trains()
	_root.add_child(_line.instance("Beams", true))
	_root.add_child(_bt.instance("TransitStone", true))
	var pv: MeshInstance3D = _pave.instance("TransitPavers", false)
	pv.material_override = WorldSurface.material("pavers", PLAZA, 1.0)
	_root.add_child(pv)


## The two beams on their pylons, rails on the beam edges inside the riding area, the gap zones along them, and the
## portal buildings the line disappears into at both ends of the city.
func _beams() -> void:
	var y1: float = DtPlan.MONO_Y
	var y0: float = y1 - DtPlan.BEAM_H
	var hw: float = DtPlan.BEAM_W * 0.5
	var x0: float = DtPlan.BEAM_X0
	var x1: float = DtPlan.BEAM_X1
	for bz: float in [DtPlan.BEAM_A, DtPlan.BEAM_B]:
		_line.box_min(Vector3(x0, y0, bz - hw), Vector3(x1 - x0, DtPlan.BEAM_H, DtPlan.BEAM_W), BEAM, false)
		for s: float in [-1.0, 1.0]:
			_line.box(Vector3((x0 + x1) * 0.5, y0 + 0.35, bz + s * (hw + 0.01)), Vector3(x1 - x0, 0.22, 0.03), Color("8a929c"))
			_line.box(Vector3((x0 + x1) * 0.5, y1 - 0.02, bz + s * (hw - 0.03)), Vector3(x1 - x0, 0.045, 0.07), Color("e7c64f"))
		DtKit.col_box(_sb, Vector3((x0 + x1) * 0.5, y1 - DtPlan.BEAM_H * 0.5, bz), Vector3(x1 - x0, DtPlan.BEAM_H, DtPlan.BEAM_W))
		var bx0: float = DtPlan.BOUNDS.position.x
		var bx1: float = DtPlan.BOUNDS.end.x
		for s: float in [-1.0, 1.0]:
			DtKit.rail(_rails, PackedVector3Array([Vector3(bx0, y1, bz + s * hw), Vector3(bx1, y1, bz + s * hw)]), "rail", "BeamEdge")
		var id: String = "beam_a" if bz < DtPlan.MONO_Z else "beam_b"
		DtKit.zone(_rails, id, Vector3(bx0, y1, bz - 0.7), Vector3(bx1 - bx0, 1.8, 1.4))
	# grind checkpoints over the east avenue and the station end of the line
	DtKit.zone(_rails, "line_e", Vector3(52.0, y1 - 0.2, DtPlan.BEAM_A - 0.8), Vector3(4.0, 2.0, DtPlan.BEAM_B - DtPlan.BEAM_A + 1.6))
	DtKit.zone(_rails, "line_w", Vector3(24.0, y1 - 0.2, DtPlan.BEAM_A - 0.8), Vector3(4.0, 2.0, DtPlan.BEAM_B - DtPlan.BEAM_A + 1.6))
	# pylons: a column in the median of the line, a crossarm under both beams
	for px: float in DtPlan.PYLONS_X:
		_line.box_min(Vector3(px - 0.6, 0.0, DtPlan.MONO_Z - 0.6), Vector3(1.2, y0 - 1.0, 1.2), PYLON)
		_line.box_min(Vector3(px - 0.9, -0.05, DtPlan.MONO_Z - 0.9), Vector3(1.8, 0.35, 1.8), PYLON.darkened(0.15))
		var arm := PackedVector2Array([Vector2(DtPlan.BEAM_A - 0.7, y0), Vector2(DtPlan.BEAM_B + 0.5, y0), Vector2(DtPlan.BEAM_B + 0.5, y0 - 0.4), Vector2(DtPlan.MONO_Z + 0.6, y0 - 1.2), Vector2(DtPlan.MONO_Z - 0.6, y0 - 1.2), Vector2(DtPlan.BEAM_A - 0.7, y0 - 0.4)])
		_line.prism(arm, px - 0.55, px + 0.55, PYLON, Transform3D.IDENTITY)
		DtKit.col_box(_sb, Vector3(px, (y0 - 1.0) * 0.5, DtPlan.MONO_Z), Vector3(1.2, y0 - 1.0 + 0.4, 1.2))
		DtKit.col_box(_sb, Vector3(px, y0 - 0.6, (DtPlan.BEAM_A + DtPlan.BEAM_B) * 0.5), Vector3(1.1, 1.2, DtPlan.BEAM_B - DtPlan.BEAM_A + 1.2))
	# portal buildings at both ends of the city: the line runs into them
	for s: float in [-1.0, 1.0]:
		_line.box(Vector3(s * 318.0, 20.0, DtPlan.MONO_Z), Vector3(30.0, 40.0, 26.0), Color("9aa3ad"))
		_line.box(Vector3(s * 303.0 - s * 0.02, y1 - 0.6, DtPlan.MONO_Z), Vector3(0.05, 4.0, 8.0), Color("1b2433"))


## Central Station: the platform block, its glass ticket hall, the canopy on columns, benches, the 24-stair.
func _station() -> void:
	var r: Rect2 = DtPlan.STATION
	var top: float = DtPlan.MONO_Y
	var p: float = DtPlan.P
	DtKit.col_box(_sb, Vector3(r.get_center().x, (top - 0.5) * 0.5, r.get_center().y), Vector3(r.size.x, top + 0.5, r.size.y))
	_bt.box_min(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, top - 0.12, r.size.y), STATION_STONE)
	_bt.box_min(Vector3(r.position.x - 0.1, top - 0.3, r.position.y - 0.1), Vector3(r.size.x + 0.2, 0.3, r.size.y + 0.2), STATION_STONE.darkened(0.12))
	# platform surface and the yellow edge strip on the beam side
	var tp: float = top + PieceKit.FLOOR_PAD_LIFT
	_pave.quad(Vector3(r.position.x, tp, r.position.y + 0.6), Vector3(r.end.x, tp, r.position.y + 0.6), Vector3(r.end.x, tp, r.end.y), Vector3(r.position.x, tp, r.end.y), Color.WHITE, Vector3.UP)
	_bt.box(Vector3(r.get_center().x, top + 0.003, r.position.y + 0.3), Vector3(r.size.x, 0.006, 0.6), Color("f2c94c"))
	DtKit.rail(_rails, PackedVector3Array([Vector3(r.position.x, top, r.position.y), Vector3(r.end.x, top, r.position.y)]), "ledge", "PlatformEdge")
	# the ticket hall: glass bays along the south face either side of the stairs, a stone band above
	var sz: float = r.end.y
	for side: float in [-1.0, 1.0]:
		var xa: float = side * 6.2
		var xb: float = side * 21.6
		var w: float = absf(xb - xa)
		var cx: float = (xa + xb) * 0.5
		_bt.box(Vector3(cx, p + 2.0, sz + 0.03), Vector3(w, 3.6, 0.06), GLASS)
		for k: int in int(w / 2.6) + 1:
			_bt.box(Vector3(minf(xa, xb) + float(k) * 2.6, p + 2.0, sz + 0.06), Vector3(0.12, 3.6, 0.1), Color("3a4250"))
		_bt.box(Vector3(cx, p + 4.2, sz + 0.06), Vector3(w, 0.5, 0.1), Color("c33b33"))
	# the north face, toward the beams: a mural band and the line's colours
	_bt.box(Vector3(0.0, 3.0, r.position.y - 0.03), Vector3(r.size.x - 2.0, 1.2, 0.06), Color("2d6f8e"))
	_bt.box(Vector3(0.0, 2.2, r.position.y - 0.04), Vector3(r.size.x - 2.0, 0.25, 0.06), Color("e7c64f"))
	# canopy on six columns, a skylight strip, fascia signs
	for i: int in 6:
		var x: float = [-21.0, -14.0, -7.5, 7.5, 14.0, 21.0][i]
		_bt.cyl(Vector3(x, top, r.end.y - 0.6), 0.2, 3.9, Color("394456"), 10)
		DtKit.col_box(_sb, Vector3(x, top + 1.9, r.end.y - 0.6), Vector3(0.4, 3.8, 0.4))
	_bt.box(Vector3(0.0, top + 4.1, r.get_center().y + 0.2), Vector3(r.size.x + 1.0, 0.35, r.size.y + 0.8), CANOPY, Basis.IDENTITY, false)
	_bt.box(Vector3(0.0, top + 4.3, r.get_center().y + 0.2), Vector3(r.size.x - 4.0, 0.12, 1.4), Color("a9d4ea"))
	for s: float in [-1.0, 1.0]:
		var label := Label3D.new()
		label.name = "StationSign"
		label.text = "CENTRAL STATION"
		label.font_size = 128
		label.pixel_size = 0.008
		label.modulate = Color("fff6dc")
		label.outline_size = 0
		label.shaded = false
		label.position = Vector3(0.0, top + 4.1, r.get_center().y + 0.2 + s * (r.size.y * 0.5 + 0.42))
		label.rotation.y = 0.0 if s > 0.0 else PI
		_root.add_child(label)
	for x: float in [-17.0, -11.0, 11.0, 17.0]:
		DtKit.bench(_bt, _sb, _rails, Vector3(x, 0.0, r.get_center().y + 0.6), Vector3(0, 0, -1), 2.4, top)
	# glass balustrades on the platform's open edges (the south edge either side of the stairs, and both ends):
	# solid to 1.1 m, a steel top rail that grinds
	var bal_h: float = 1.1
	var runs: Array = [
		[Vector3(r.position.x, top, sz - 0.1), Vector3(-DtPlan.STATION_STAIR_HALF - 0.6, top, sz - 0.1)],
		[Vector3(DtPlan.STATION_STAIR_HALF + 0.6, top, sz - 0.1), Vector3(r.end.x, top, sz - 0.1)],
		[Vector3(r.position.x + 0.1, top, r.position.y + 0.8), Vector3(r.position.x + 0.1, top, sz - 0.1)],
		[Vector3(r.end.x - 0.1, top, r.position.y + 0.8), Vector3(r.end.x - 0.1, top, sz - 0.1)],
	]
	for run_ab: Array in runs:
		var ba: Vector3 = run_ab[0]
		var bb: Vector3 = run_ab[1]
		var bc: Vector3 = (ba + bb) * 0.5
		var bs := Vector3(maxf(absf(bb.x - ba.x), 0.08), bal_h, maxf(absf(bb.z - ba.z), 0.08))
		_bt.box(bc + Vector3(0, bal_h * 0.5 - 0.05, 0), bs - Vector3(0, 0.1, 0), Color("bfe0ee"))
		_bt.box(bc + Vector3(0, bal_h - 0.03, 0), bs + Vector3(0.04, -bal_h + 0.07, 0.04), DtKit.STEEL)
		DtKit.col_box(_sb, bc + Vector3(0, bal_h * 0.5, 0), bs)
		DtKit.rail(_rails, PackedVector3Array([ba + Vector3(0, bal_h, 0), bb + Vector3(0, bal_h, 0)]), "rail", "Balustrade")
	# the stairs down to the transit plaza, cheek hubbas and two handrails
	var run: float = float(DtPlan.STATION_STEPS) * 0.5
	var half: float = DtPlan.STATION_STAIR_HALF
	DtKit.stairs(_bt, _sb, Vector3(0.0, 0.0, sz), Vector3(0, 0, 1), half * 2.0, DtPlan.STATION_STEPS, 0.5, top, p, DtKit.GRANITE, DtKit.GRANITE_DARK)
	var bot_z: float = sz + run
	for s: float in [-1.0, 1.0]:
		DtKit.hubba(_bt, _sb, _rails, Vector3(s * (half + 0.3), 0.0, sz - 0.6), Vector3(0, 0, 1), 0.6, 0.6, run, top, 0.5, p, 0.5, DtKit.GRANITE_DARK, "StationCheek")
		DtKit.zone(_rails, "station_cheek_top", Vector3(s * (half + 0.3) - 0.5, top + 0.4, sz - 0.6), Vector3(1.0, 1.6, 1.4))
		DtKit.zone(_rails, "station_cheek_bottom", Vector3(s * (half + 0.3) - 0.5, p + 0.3, bot_z - 1.8), Vector3(1.0, 1.8, 1.8))
		var x: float = s * 2.5
		var slope: float = (top - p) / run
		var a0 := Vector3(x, top + 0.9, sz - 1.0)
		var a := Vector3(x, top + 0.9, sz)
		var b := Vector3(x, top + 0.9 - slope * (run + 0.4), bot_z + 0.4)
		var posts: Array = [Vector3(x, top, sz - 0.8)]
		for k: int in 5:
			var z: float = sz + 1.5 + float(k) * 2.4
			posts.append(Vector3(x, top - slope * (z - sz), z))
		DtKit.handrail(_bt, _rails, a0, a, b, posts, "StationRail")
		DtKit.zone(_rails, "station_rail_top", Vector3(x - 0.6, a.y - 0.4, sz - 1.0), Vector3(1.2, 1.6, 1.4))
		DtKit.zone(_rails, "station_rail_bottom", Vector3(x - 0.6, b.y - 0.6, bot_z - 2.0), Vector3(1.2, 1.8, 2.6))
	DtKit.zone(_rails, "station_top", Vector3(-half, top + 0.2, sz - 0.8), Vector3(half * 2.0, 1.8, 1.4))
	DtKit.zone(_rails, "station_bottom", Vector3(-half, p, bot_z - 1.5), Vector3(half * 2.0, 3.0, 10.0))  # clear 21 of the 24 to count
	platform_xf = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-15.0, top, r.get_center().y + 0.4))


## Under the line: concrete floor, two long granite ledges, benches, the newsstand and bus stops on the street.
func _under_line() -> void:
	var p: float = DtPlan.P
	for s: float in [-1.0, 1.0]:
		DtKit.ledge(_bt, _sb, _rails, Vector3(s * 9.0, 0.0, 44.5), Vector3(s * 29.0, 0.0, 44.5), 0.8, 0.5, p, DtKit.GRANITE_DARK, DtKit.GRANITE, "LineLedge")
		DtKit.bench(_bt, _sb, _rails, Vector3(s * 34.0, 0.0, 49.0), Vector3(-s, 0, 0), 2.4, p)
	# Under The Line: either ledge ridden end to end, from its outer end in toward the station
	for s: float in [-1.0, 1.0]:
		DtKit.zone(_rails, "line_ledge_in", Vector3(s * 28.0 - 1.0, p + 0.3, 44.0), Vector3(2.0, 1.6, 1.0))
		DtKit.zone(_rails, "line_ledge_out", Vector3(s * 10.0 - 1.0, p + 0.3, 44.0), Vector3(2.0, 1.6, 1.0))
	var kit: LevelKit = LevelKit.open("downtown")
	var stops: Array[Transform3D] = [DtKit.at(Vector3(-26.0, p, 38.8), 0.0), DtKit.at(Vector3(26.0, p, 38.8), 0.0), DtKit.at(Vector3(-25.0, p, 21.2), PI), DtKit.at(Vector3(25.0, p, 21.2), PI)]
	DtKit.kit_multi(_root, kit, "bus_stop", stops, _sb, true)
	DtKit.kit_multi(_root, kit, "newsstand", [DtKit.at(Vector3(-36.0, p, 46.0), PI * 0.5), DtKit.at(Vector3(37.5, p, 20.5), PI)] as Array[Transform3D], _sb, true)


## The transit plaza south of the station: pavers, two runout ledges, the red arc sculpture (a rail), planters, a
## hot-dog cart, the elevator pad to the platform.
func _south_plaza() -> void:
	var p: float = DtPlan.P
	var pp: float = p + PieceKit.FLOOR_PAD_LIFT
	var r := Rect2(-39.0, 41.0, 78.0, 49.0)
	_pave.quad(Vector3(r.position.x, pp, r.position.y), Vector3(r.end.x, pp, r.position.y), Vector3(r.end.x, pp, r.end.y), Vector3(r.position.x, pp, r.end.y), Color.WHITE, Vector3.UP)
	for s: float in [-1.0, 1.0]:
		DtKit.ledge(_bt, _sb, _rails, Vector3(s * 9.5, 0.0, 74.0), Vector3(s * 9.5, 0.0, 87.0), 0.7, 0.55, p, DtKit.GRANITE_DARK, DtKit.GRANITE, "RunoutLedge")
	for pos: Vector3 in [Vector3(-30.0, 0.0, 76.0), Vector3(-30.0, 0.0, 86.0), Vector3(30.0, 0.0, 76.0), Vector3(30.0, 0.0, 86.0)]:
		tree_spots.append(DtKit.planter(_bt, _sb, _rails, pos, 3.0, 3.0, 0.55, p))
	# the arc: a red steel band rising to 1.25 m, its top a grind line
	var arc := PackedVector3Array()
	var ac := Vector3(-20.0, p, 81.0)
	for i: int in 13:
		var t: float = float(i) / 12.0
		var x: float = lerpf(-6.0, 6.0, t)
		var y: float = 0.45 + 0.8 * sin(t * PI)
		arc.append(ac + Vector3(x, y, 0.0))
	for i: int in arc.size() - 1:
		_bt.bar(arc[i] - Vector3(0, 0.06, 0), arc[i + 1] - Vector3(0, 0.06, 0), 0.25, 0.12, Color("d8382f"))
	for i: int in [0, 3, 6, 9, 12]:
		_bt.box(Vector3(arc[i].x, (p + arc[i].y) * 0.5, ac.z), Vector3(0.12, arc[i].y - p, 0.12), Color("a8281f"))
		DtKit.col_box(_sb, Vector3(arc[i].x, (arc[i].y + p - 0.3) * 0.5, ac.z), Vector3(0.14, arc[i].y - p + 0.3, 0.14))
	DtKit.rail(_rails, arc, "rail", "ArcRail")
	DtKit.zone(_rails, "arc_a", Vector3(ac.x - 6.2, p + 0.3, ac.z - 0.6), Vector3(1.2, 1.6, 1.2))
	DtKit.zone(_rails, "arc_b", Vector3(ac.x + 5.0, p + 0.3, ac.z - 0.6), Vector3(1.2, 1.6, 1.2))
	# a hot-dog cart with its umbrella
	var hc := Vector3(22.0, p, 80.0)
	_bt.box(hc + Vector3(0, 0.6, 0), Vector3(2.2, 0.9, 1.1), Color("e9e2d2"))
	_bt.box(hc + Vector3(0, 1.08, 0), Vector3(2.3, 0.06, 1.2), Color("9aa3ad"))
	_bt.box(hc + Vector3(0, 0.75, 0.56), Vector3(2.0, 0.3, 0.02), Color("d8382f"))
	_bt.cyl(hc + Vector3(-0.7, 0.0, 0.0), 0.3, 0.3, Color("2a2c33"), 10)
	_bt.cyl(hc + Vector3(0.7, 0.0, 0.0), 0.3, 0.3, Color("2a2c33"), 10)
	_bt.tube(hc + Vector3(0.0, 1.1, 0.0), hc + Vector3(0.0, 2.6, 0.0), 0.04, Color("596273"), 6)
	_bt.cyl(hc + Vector3(0.0, 2.3, 0.0), 1.5, 0.45, Color("f2c94c"), 12, 0.05)
	DtKit.col_box(_sb, hc + Vector3(0, 0.55, 0), Vector3(2.3, 1.1, 1.2))
	# the elevator pad: a DROP IN marker to the platform
	_bt.box(drop_pad + Vector3(4.0, 1.4, 0.0), Vector3(0.6, 2.8, 0.6), Color("394456"))
	DtKit.col_box(_sb, drop_pad + Vector3(4.0, 1.4, 0.0), Vector3(0.6, 2.8, 0.6))


func _trains() -> void:
	var a: DtTrain = DtTrain.create(DtPlan.BEAM_A, 1.0, -140.0, Color("f2f0ea"), Color("d8382f"))
	var b: DtTrain = DtTrain.create(DtPlan.BEAM_B, -1.0, 210.0, Color("f2f0ea"), Color("2d8fb8"))
	a.name = "TrainEast"
	b.name = "TrainWest"
	_root.add_child(a)
	_root.add_child(b)
	trains = [a, b]
