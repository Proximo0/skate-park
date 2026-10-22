class_name DtLife
extends RefCounted
## The living city on top of the built one: the crowd (walkers on the sidewalks and across the crosswalks, people
## chatting on the plazas, folk waiting at the bus stops), pigeons (huddles on the ground that burst up as you roll
## in, flocks wheeling over the fountain, the Line and the dome), steam from the street grates and the alley vents,
## street lights with swaying banners, flags on City Hall, and the trees in the planters.
##
## The walkers keep to the sidewalks and crosswalks round the play space; the plazas' skate lines stay clear (people
## step aside when the skater comes close anyway).

const FLAG_SHADER: Shader = preload("res://game/levels/downtown/dt_flag.gdshader")
const BANNER_COLOURS: Array[Color] = [Color("1f4f8f"), Color("d8382f"), Color("1f4f8f"), Color("f2b134")]
const LIGHT_STEP: float = 26.0
const LIGHT_OFF: float = 6.75  ## from a road's centre line to the light poles (0.75 m in from the kerb)

var lvl: Node3D
var streets: DtStreets
var civic: DtCivic
var transit: DtTransit
var alley: DtAlley
var crowd: Pedestrians
var pigeons: DtPigeons
var trees: SwayTrees
var light_spots: Array[Transform3D] = []
var _root: Node3D
var _sb: StaticBody3D
var _bt := DtBatch.new()
var _flags: Array = []  ## [Transform3D, Color, pattern]
var _banners: Array = []


func _init(level: Node3D, s: DtStreets, c: DtCivic, t: DtTransit, a: DtAlley) -> void:
	lvl = level
	streets = s
	civic = c
	transit = t
	alley = a


func build() -> void:
	_root = Node3D.new()
	_root.name = "Life"
	lvl.add_child(_root)
	_sb = DtKit.body(_root, "LifeBody")
	_crowd()
	_pigeons()
	_steam()
	_street_lights()
	_civic_flags()
	_trees()
	_commit()


func _night() -> bool:
	return lvl.has_method("is_night") and bool(lvl.call("is_night"))


# --- people -------------------------------------------------------------------------------------------------------

func _crowd() -> void:
	var p: float = DtPlan.P
	var t: float = p + DtPlan.TERRACE_H
	crowd = DtCrowd.new()
	crowd.name = "Crowd"
	crowd.seed_value = 77
	crowd.look_pool = 7
	_root.add_child(crowd)
	# round the civic block on its sidewalk
	crowd.add_walkers(LanePath.block_loop(Rect2(-41.6, -35.6, 83.2, 57.2), p, 3.0, true), 4)
	# the far sidewalk of the south street, behind the bus stops
	crowd.add_walkers(_open([Vector3(-43.0, p, 40.4), Vector3(43.0, p, 40.4)]), 2)
	# down the two avenues (crossing the streets on the zebras: the traffic stops for them)
	crowd.add_walkers(_open([Vector3(-57.2, p, -40.0), Vector3(-57.2, p, 92.0)]), 3, 1.1, 1.45)
	crowd.add_walkers(_open([Vector3(57.2, p, -40.0), Vector3(57.2, p, 46.0)]), 2, 1.1, 1.45)
	# the north street, behind City Hall
	crowd.add_walkers(_open([Vector3(-43.0, p, -50.6), Vector3(43.0, p, -50.6)]), 2)
	# over the mid-block crossing between the promenade and the transit plaza
	crowd.add_walkers(_open([Vector3(-15.0, p, 22.6), Vector3(-1.6, p, 22.6), Vector3(-1.6, p, 40.0), Vector3(-8.0, p, 40.0)]), 1)
	crowd.add_walkers(_open([Vector3(15.0, p, 40.0), Vector3(1.6, p, 40.0), Vector3(1.6, p, 22.6), Vector3(8.0, p, 22.6)]), 1)
	# people chatting: on the terrace by the portico, and on the transit plaza
	crowd.add_group(Vector3(9.0, t, -21.5), 3)
	crowd.add_group(Vector3(31.0, p, 66.0), 2)
	# waiting: at the bus stops, the newsstand, up on the platform
	crowd.add_idler(Vector3(-25.6, p, 38.2), 0.0, "phone")
	crowd.add_idler(Vector3(25.4, p, 21.8), PI, "idle")
	crowd.add_idler(Vector3(-36.0, p, 44.7), 0.2, "idle")
	crowd.add_idler(Vector3(16.5, DtPlan.MONO_Y, 57.3), 0.0, "phone")


static func _open(pts: Array[Vector3]) -> LanePath:
	return LanePath.from_points(PackedVector3Array(pts), false, 1.5)


# --- pigeons ------------------------------------------------------------------------------------------------------

func _pigeons() -> void:
	var p: float = DtPlan.P + 0.004
	pigeons = DtPigeons.create(41)
	var f: Vector3 = DtPlan.FOUNTAIN
	pigeons.add_huddle(Vector3(f.x - 9.0, p, f.z - 3.0), 7, 1.8)
	pigeons.add_huddle(Vector3(-4.0, p, 43.0), 6, 1.6)
	pigeons.add_huddle(Vector3(14.0, DtPlan.P + DtPlan.TERRACE_H + 0.004, -17.2), 5, 1.4)
	pigeons.add_huddle(Vector3(-34.0, p, 62.0), 5, 1.5)
	_root.add_child(pigeons)
	_root.add_child(Birds.flock("pigeon", 14, Vector3(f.x, 9.0, f.z), 12.0, 7))
	_root.add_child(Birds.flock("pigeon", 10, Vector3(30.0, 12.0, 62.0), 16.0, 13))
	_root.add_child(Birds.flock("pigeon", 9, Vector3(0.0, 27.0, -30.0), 14.0, 19))
	_root.add_child(Birds.flock("gull", 6, Vector3(-20.0, 70.0, -60.0), 60.0, 3))


# --- steam --------------------------------------------------------------------------------------------------------

func _steam() -> void:
	var col := Color(0.93, 0.95, 1.0, 0.32) if not _night() else Color(1.0, 0.86, 0.7, 0.3)
	var i: int = 0
	for g: Vector3 in streets.grates:
		var v: SteamVent = SteamVent.create(col, 0.8 + 0.15 * float(i % 3), 4.0 + float(i % 2))
		v.name = "Steam%d" % i
		v.position = g + Vector3(0, 0.05, 0)
		_root.add_child(v)
		i += 1
	for s: Vector3 in alley.steam_spots:
		var v: SteamVent = SteamVent.create(col, 1.1, 3.0)
		v.name = "Steam%d" % i
		v.position = s
		_root.add_child(v)
		i += 1


# --- street lights and banners ------------------------------------------------------------------------------------

## Kit street lights along both sides of the near avenues and streets, every LIGHT_STEP, clear of the junctions, the
## Line, the bus stops and the crossings. Every pole carries a banner on a bracket.
func _street_lights() -> void:
	var p: float = DtPlan.P
	var avoid: Array[Vector3] = [
		Vector3(-26.0, 0, 38.8), Vector3(26.0, 0, 38.8), Vector3(-25.0, 0, 21.2), Vector3(25.0, 0, 21.2),
		Vector3(-36.0, 0, 46.0), Vector3(37.5, 0, 20.5), Vector3(-5.5, 0, 30.0), Vector3(5.5, 0, 30.0),
	]
	for g: Vector3 in streets.grates:
		avoid.append(g)
	var cross_x: Array[float] = []
	var cross_z: Array[float] = []
	for v: float in DtPlan.OUTER_X:
		cross_x.append(v)
	for v: float in DtPlan.OUTER_Z:
		cross_z.append(v)
	cross_x.append(DtPlan.MID_X)
	# avenues (run along Z)
	for ax: float in [DtPlan.X_W, DtPlan.X_E, -150.0, 150.0]:
		var reach: float = 200.0 if absf(ax) < 100.0 else 140.0
		for side: float in [-1.0, 1.0]:
			var z: float = -reach
			while z <= reach:
				var pos := Vector3(ax + side * LIGHT_OFF, p, z + side * 6.0)
				if _clear(pos, cross_x, cross_z, avoid, true):
					_add_light(pos, Vector3(-side, 0, 0))
				z += LIGHT_STEP
	# streets (run along X)
	for sz: float in [DtPlan.Z_N, DtPlan.Z_S, -144.0, 130.0]:
		var reach: float = 200.0 if absf(sz) < 100.0 else 140.0
		for side: float in [-1.0, 1.0]:
			var x: float = -reach
			while x <= reach:
				var pos := Vector3(x + side * 6.0, p, sz + side * LIGHT_OFF)
				if _clear(pos, cross_x, cross_z, avoid, false):
					_add_light(pos, Vector3(0, 0, -side))
				x += LIGHT_STEP
	var kit: LevelKit = LevelKit.open("downtown")
	var near: Array[Transform3D] = []
	var far: Array[Transform3D] = []
	for xf: Transform3D in light_spots:
		if DtPlan.BOUNDS.grow(10.0).has_point(Vector2(xf.origin.x, xf.origin.z)):
			near.append(xf)
		else:
			far.append(xf)
	DtKit.kit_multi(_root, kit, "streetlight", near, _sb, true)
	DtKit.kit_multi(_root, kit, "streetlight", far, null, false)
	# a fire hydrant beside some of them
	var hyd: Array[Transform3D] = []
	for i: int in light_spots.size():
		if i % 3 == 1:
			var xf: Transform3D = light_spots[i]
			var side: Vector3 = xf.basis.x
			hyd.append(DtKit.at(xf.origin + side * 2.2 + xf.basis.z * 0.3, xf.basis.get_euler().y))
	DtKit.kit_multi(_root, kit, "hydrant", hyd, _sb, true)


func _clear(pos: Vector3, cross_x: Array[float], cross_z: Array[float], avoid: Array[Vector3], avenue: bool) -> bool:
	if avenue:
		for cz: float in cross_z:
			if absf(pos.z - cz) < 13.0:
				return false
		if absf(pos.z - DtPlan.MONO_Z) < 7.0:
			return false
	else:
		for cx: float in cross_x:
			if absf(pos.x - cx) < (13.0 if cx != DtPlan.MID_X or absf(pos.z - DtPlan.Z_S) > 10.0 else 8.0):
				return false
	for a: Vector3 in avoid:
		if Vector2(pos.x - a.x, pos.z - a.z).length() < 3.5:
			return false
	# not inside the special lots (station, garage, alleys)
	for r: Rect2 in [DtPlan.STATION.grow(2.0), DtPlan.GARAGE.grow(1.0), Rect2(-101.0, 44.0, 41.0, 47.0)]:
		if r.has_point(Vector2(pos.x, pos.z)):
			return false
	return true


## A pole at `pos` whose arm reaches out over the road along `out`; its banner hangs on a bracket on the same side.
func _add_light(pos: Vector3, out: Vector3) -> void:
	var yaw: float = atan2(-out.x, -out.z)
	var xf: Transform3D = DtKit.at(pos, yaw)
	light_spots.append(xf)
	var k: int = light_spots.size()
	var col: Color = BANNER_COLOURS[k % BANNER_COLOURS.size()]
	# the bracket: two short arms off the pole toward the road, the banner between them
	var top: Vector3 = pos + Vector3(0, 5.15, 0)
	var bot: Vector3 = pos + Vector3(0, 3.35, 0)
	for y: Vector3 in [top, bot]:
		_bt.box(y + out * 0.44, Vector3(0.04, 0.04, 0.8), Color("3a414c"), Basis(Vector3.UP, yaw))
	# banner local: x 0..1 along `out` (0.12 .. 0.82 m from the pole), y 0..-1 down (1.75 m); face normal sideways
	var b := Basis(out.normalized(), Vector3.UP, out.normalized().cross(Vector3.UP))
	b = b.scaled_local(Vector3(0.7, 1.75, 1.0))
	_banners.append([Transform3D(b, top + out * 0.1 + Vector3(0, -0.03, 0)), col, 0.5])


# --- City Hall's flags and banners --------------------------------------------------------------------------------

func _civic_flags() -> void:
	var mast := Color("d8dde4")
	for i: int in civic.flag_spots.size():
		var base: Vector3 = civic.flag_spots[i]
		var on_dome: bool = i == 0 and base.y > 20.0
		var top: Vector3 = base
		if not on_dome:
			top = base + Vector3(0, 9.0, 0)
			_bt.tube(base, top, 0.07, mast, 6)
			DtKit.col_box(_sb, base + Vector3(0, 4.5, 0), Vector3(0.18, 9.0, 0.18))
		_bt.dome(top, 0.14, Color("e8c45a"), 1.0, 8, 3)
		var size := Vector2(3.4, 2.1) if on_dome else Vector2(2.6, 1.6)
		var b := Basis(Vector3(1, 0, 0) * size.x, Vector3(0, 1, 0) * size.y, Vector3(0, 0, 1))
		var cols: Array[Color] = [Color("1f4f8f"), Color("d8382f"), Color("2f7a4f")]
		_flags.append([Transform3D(b, top + Vector3(0.08, -0.1, 0)), cols[i % cols.size()], 0.0 if i == 0 else 1.0])
	for i: int in civic.banner_spots.size():
		var xf: Transform3D = civic.banner_spots[i]
		var b := Basis(Vector3(1.5, 0, 0), Vector3(0, 5.2, 0), Vector3(0, 0, 1))
		var col: Color = Color("8f1f2f") if i % 2 == 0 else Color("1f4f8f")
		_banners.append([Transform3D(b, xf.origin + Vector3(-0.75, 0.0, 0.0)), col, 0.5])


# --- trees --------------------------------------------------------------------------------------------------------

func _trees() -> void:
	trees = SwayTrees.new()
	trees.name = "Trees"
	trees.seed_value = 57
	for s: Vector3 in civic.tree_spots:
		trees.add("round", s, 0.0)
	for s: Vector3 in transit.tree_spots:
		trees.add("round", s, 0.0)
	_root.add_child(trees)


# --- commit -------------------------------------------------------------------------------------------------------

func _commit() -> void:
	if not _bt.is_empty():
		_root.add_child(_bt.instance("LifeBits", true))
	_root.add_child(_cloth("Flags", _flags, 0.0, 0.28, 2.6))
	_root.add_child(_cloth("Banners", _banners, 1.0, 0.12, 1.6))


func _cloth(node_name: String, list: Array, hang: float, amount: float, speed: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = DtLife.cloth_mesh(10, 6)
	mm.instance_count = list.size()
	for i: int in list.size():
		var e: Array = list[i]
		mm.set_instance_transform(i, e[0] as Transform3D)
		var c: Color = (e[1] as Color).srgb_to_linear()
		mm.set_instance_custom_data(i, Color(c.r, c.g, c.b, float(e[2])))
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = FLAG_SHADER
	m.set_shader_parameter("hang", hang)
	m.set_shader_parameter("amount", amount)
	m.set_shader_parameter("speed", speed)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


## The unit cloth: x 0..1, y 0..-1, facing +Z, `nx` x `ny` cells, UV = (x, -y).
static func cloth_mesh(nx: int, ny: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in ny + 1:
		for i: int in nx + 1:
			var u: float = float(i) / float(nx)
			var v: float = float(j) / float(ny)
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(Vector2(u, v))
			st.add_vertex(Vector3(u, -v, 0.0))
	for j: int in ny:
		for i: int in nx:
			var a: int = j * (nx + 1) + i
			var b: int = a + 1
			var c: int = a + nx + 1
			var d: int = c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	return st.commit()
