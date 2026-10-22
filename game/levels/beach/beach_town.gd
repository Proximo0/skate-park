class_name BeachTown
extends RefCounted
## The Beachfront's world beyond the riding area and its life: the beach town along the coast road (one MultiMesh of
## painted buildings, BeachFacade shader), signs, golden hills behind, the bay's headlands, island and sailboats, the
## traffic on the coast road, the crowd (walkers, joggers, surfers carrying boards, beach groups, fishers) and gulls.
## Everything here is visual or ambient; the rideable level lives in beach_level.gd.

const FACADE_SHADER: Shader = preload("res://game/levels/beach/beach_facade.gdshader")
const PAINTS: Array[Color] = [
	Color("f6e7c8"), Color("f2b8a0"), Color("9fd8d0"), Color("f7d58b"), Color("e9a2b6"), Color("b9d7f0"),
	Color("ffffff"), Color("c8e6b0"), Color("f0c890"), Color("d6c4ec"),
]
const SIGNS: Array = [
	["SURF", Color("ff6b5e")], ["MOTEL", Color("1aa6b7")], ["TACOS", Color("f2a33a")], ["HOTEL", Color("3a5ba0")],
	["ICE CREAM", Color("e75a9a")], ["BURGERS", Color("e2483d")], ["RENTALS", Color("27a37a")], ["CAFE", Color("8a5a3c")],
]
const HILL_COLOURS: Array[Color] = [Color("8f9c55"), Color("7d9250"), Color("a29a5c"), Color("6f8a4e"), Color("94a05e")]


## Rows of beach-town buildings from x0 to x1 behind the line z = front (they extend toward -Z), plus far rows.
## Cross streets at `streets` (x) are left open (the traffic loops turn up them).
static func town(x0: float, x1: float, front: float, seed_value: int, streets: Array[float] = []) -> Node3D:
	var root := Node3D.new()
	root.name = "Town"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var xforms: Array[Transform3D] = []
	var paints: Array[Color] = []
	var styles: Array[Color] = []
	var sign_spots: Array = []
	# front row: low two- and three-storey shops right on the road
	var x: float = x0
	while x < x1:
		var w: float = rng.randf_range(9.0, 17.0)
		var floors: int = rng.randi_range(2, 3)
		var h: float = float(floors) * 3.2 + 0.6
		var d: float = rng.randf_range(10.0, 14.0)
		var setback: float = rng.randf_range(0.0, 1.2)
		if BeachTown._on_street(x, x + w, streets):
			x += w
			continue
		xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(w - 0.4, h, d)), Vector3(x + w * 0.5, h * 0.5, front - setback - d * 0.5)))
		paints.append(PAINTS[rng.randi_range(0, PAINTS.size() - 1)])
		styles.append(Color(rng.randf_range(0.0, 0.66), rng.randf(), 1.0, 0.0))
		if rng.randf() < 0.45:
			sign_spots.append([Vector3(x + w * 0.5, h - 1.1, front - setback + 0.08), rng.randi_range(0, SIGNS.size() - 1)])
		x += w
	# second row: resort hotels and apartments, taller, set back
	x = x0 - 10.0
	while x < x1 + 10.0:
		var w: float = rng.randf_range(16.0, 30.0)
		var floors: int = rng.randi_range(4, 8)
		var h: float = float(floors) * 3.2 + 0.6
		var d: float = rng.randf_range(14.0, 20.0)
		var z: float = front - 24.0 - rng.randf_range(0.0, 10.0)
		if rng.randf() < 0.8 and not BeachTown._on_street(x, x + w, streets):
			xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(w - 2.0, h, d)), Vector3(x + w * 0.5, h * 0.5, z - d * 0.5)))
			paints.append(PAINTS[rng.randi_range(0, PAINTS.size() - 1)])
			styles.append(Color(rng.randf_range(0.67, 1.0) if rng.randf() < 0.6 else 0.4, rng.randf(), 0.0, 0.0))
		x += w + rng.randf_range(2.0, 8.0)
	# far rows: houses climbing toward the hills
	for row: int in 3:
		x = x0 - 60.0
		while x < x1 + 60.0:
			var w: float = rng.randf_range(8.0, 14.0)
			var h: float = rng.randf_range(5.0, 9.0) + float(row) * 1.5
			var z: float = front - 62.0 - float(row) * 26.0 - rng.randf_range(0.0, 8.0)
			var y0: float = float(row) * 2.5
			xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(w - 2.5, h, rng.randf_range(8.0, 12.0))), Vector3(x + w * 0.5, y0 + h * 0.5, z)))
			paints.append(PAINTS[rng.randi_range(0, PAINTS.size() - 1)])
			styles.append(Color(rng.randf_range(0.0, 0.66), rng.randf(), 0.0, 0.0))
			x += w + rng.randf_range(3.0, 10.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, paints[i])
		mm.set_instance_custom_data(i, styles[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Buildings"
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = FACADE_SHADER
	mmi.material_override = mat
	root.add_child(mmi)
	for sp: Array in sign_spots:
		var s: Array = SIGNS[int(sp[1])]
		root.add_child(sign_label(str(s[0]), s[1] as Color, sp[0] as Vector3, 0.0))
	return root


static func _on_street(a: float, b: float, streets: Array[float]) -> bool:
	for sx: float in streets:
		if b > sx - 9.0 and a < sx + 9.0:
			return true
	return false


## A shop sign: bold letters with a white outline on the facade (a Label3D, fixed facing +Z turned by `yaw`).
static func sign_label(text: String, colour: Color, pos: Vector3, yaw: float, size: int = 96) -> Label3D:
	var l := Label3D.new()
	l.name = "Sign_" + text.replace(" ", "")
	l.text = text
	l.font_size = size
	l.pixel_size = 0.012
	l.outline_size = 22
	l.modulate = colour
	l.outline_modulate = Color("fff8ee")
	l.position = pos
	l.rotation.y = yaw
	l.double_sided = false
	return l


## Rolling golden hills behind the town (low domes, no collision): a near and a far ring of them.
static func hills(cx: float, back_z: float, seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Hills"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for row: int in 2:
		var n: int = 9 if row == 0 else 7
		for i: int in n:
			var sph := SphereMesh.new()
			sph.radial_segments = 20
			sph.rings = 8
			sph.is_hemisphere = true
			var r: float = rng.randf_range(90.0, 150.0) * (1.0 + float(row) * 0.6)
			sph.radius = 1.0
			sph.height = 1.0
			var mi := MeshInstance3D.new()
			mi.name = "Hill%d_%d" % [row, i]
			mi.mesh = sph
			var hgt: float = rng.randf_range(30.0, 55.0) * (1.0 + float(row) * 0.9)
			mi.scale = Vector3(r, hgt, r * rng.randf_range(0.5, 0.8))
			var span: float = 900.0 + float(row) * 500.0
			mi.position = Vector3(cx - span * 0.5 + span * (float(i) + rng.randf_range(0.2, 0.8)) / float(n), -2.0, back_z - float(row) * 180.0 - rng.randf_range(0.0, 60.0))
			var c: Color = HILL_COLOURS[rng.randi_range(0, HILL_COLOURS.size() - 1)]
			mi.material_override = Toon.material(c.lerp(Color("7f9fb8"), 0.25 * float(row)), false)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
	return root


## Two-lane coast road traffic: an eastbound lane at z = east_z and a westbound one at z = west_z, each a long loop that
## returns far behind the town (out of sight).
static func traffic(east_z: float, west_z: float, back_z: float, half_len: float) -> Traffic:
	var t := Traffic.new()
	t.name = "Traffic"
	t.seed_value = 31
	var east := PackedVector3Array([Vector3(-half_len, 0.0, east_z), Vector3(half_len, 0.0, east_z), Vector3(half_len, 0.0, back_z), Vector3(-half_len, 0.0, back_z)])
	var west := PackedVector3Array([Vector3(half_len + 8.0, 0.0, west_z), Vector3(-half_len - 8.0, 0.0, west_z), Vector3(-half_len - 8.0, 0.0, back_z - 10.0), Vector3(half_len + 8.0, 0.0, back_z - 10.0)])
	var kinds: Array[String] = ["hatch", "van", "pickup", "hatch", "van", "hatch", "pickup"]
	t.add_cars(t.add_lane(LanePath.from_points(east, true, 9.0), 12.0), 7, kinds)
	t.add_cars(t.add_lane(LanePath.from_points(west, true, 9.0), 11.0), 7, kinds)
	return t


## A parked car or van (CarModel) with a box collider so it is solid; `yaw` in radians, the model faces -Z.
static func parked(kind: String, tint: Color, pos: Vector3, yaw: float) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = "Parked_" + kind
	sb.collision_layer = 1
	var car: CarModel = CarModel.create(kind, tint)
	sb.add_child(car)
	var bb: AABB = car.aabb
	if bb.size == Vector3.ZERO:
		bb = AABB(Vector3(-0.9, 0.0, -2.2), Vector3(1.8, 1.9, 4.4))
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bb.size
	cs.shape = shape
	cs.position = bb.get_center()
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = yaw
	return sb


## A surfboard (visual): a flat rounded slab `length` long along local -Z... +Z, nose at +Z.
static func surfboard(length: float, colour: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 12
	var top := PackedVector3Array()
	var bot := PackedVector3Array()
	for i: int in n + 1:
		var t: float = float(i) / float(n)
		var z: float = (t - 0.5) * length
		var w: float = 0.27 * sin(PI * pow(t, 0.8)) + 0.012
		top.append(Vector3(-w, 0.03, z))
		top.append(Vector3(w, 0.03, z))
		bot.append(Vector3(-w, -0.03, z))
		bot.append(Vector3(w, -0.03, z))
	for i: int in n:
		var a: int = i * 2
		for q: Array in [[top, Vector3.UP], [bot, Vector3.DOWN]]:
			var v: PackedVector3Array = q[0]
			var nn: Vector3 = q[1]
			var tri: Array[int] = [a, a + 2, a + 1, a + 1, a + 2, a + 3]
			if nn.y < 0.0:
				tri = [a, a + 1, a + 2, a + 1, a + 3, a + 2]
			for k: int in tri:
				st.set_normal(nn)
				st.add_vertex(v[k])
		for sd: int in 2:
			var e0: Vector3 = top[a + sd]
			var e1: Vector3 = top[a + 2 + sd]
			var f0: Vector3 = bot[a + sd]
			var f1: Vector3 = bot[a + 2 + sd]
			var out := Vector3(-1.0 if sd == 0 else 1.0, 0.0, 0.0)
			var tri2: Array[Vector3] = [e0, e1, f0, e1, f1, f0]
			if sd == 1:
				tri2 = [e0, f0, e1, e1, f0, f1]
			for p: Vector3 in tri2:
				st.set_normal(out)
				st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.name = "Surfboard"
	mi.mesh = st.commit()
	mi.material_override = Toon.material(colour, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Gives a pedestrian a surfboard under the right arm once its body has arrived (bodies build after the level).
class SurfCarry:
	extends Node
	var who: Array[Pedestrian] = []
	var colours: Array[Color] = [Color("ff8a3d"), Color("2fb7c9"), Color("f4f1e8"), Color("ff5a8a"), Color("ffd23f")]
	var _done: Dictionary = {}

	func _process(_delta: float) -> void:
		var left: int = 0
		for i: int in who.size():
			var p: Pedestrian = who[i]
			if _done.has(i) or not is_instance_valid(p):
				continue
			if not p.has_body():
				left += 1
				continue
			var chest: Node3D = p.body.find_child("Chest", true, false) as Node3D
			var host: Node3D = chest if chest != null else p.body
			var board: MeshInstance3D = BeachTown.surfboard(2.1, colours[i % colours.size()])
			# under the right arm: on edge, nose forward and a little up, beside the hip
			board.transform = Transform3D(Basis(Vector3.FORWARD, deg_to_rad(84.0)) * Basis(Vector3.RIGHT, deg_to_rad(-12.0)), Vector3(0.3, -0.28, 0.05))
			host.add_child(board)
			_done[i] = true
		if left == 0 and _done.size() == who.size():
			set_process(false)


## Sailboats that drift slowly along the bay and rock on the swell.
class Boats:
	extends Node3D
	var boats: Array[Node3D] = []
	var base: Array[Vector3] = []
	var speed: Array[float] = []
	var t: float = 0.0

	func _process(delta: float) -> void:
		t += delta
		for i: int in boats.size():
			var b: Node3D = boats[i]
			var p: Vector3 = base[i]
			b.position = Vector3(p.x + sin(t * speed[i] * 0.05 + float(i)) * 25.0, p.y + sin(t * 0.9 + float(i) * 1.7) * 0.25, p.z)
			b.rotation.z = sin(t * 0.8 + float(i)) * 0.06
			b.rotation.x = sin(t * 0.63 + float(i) * 2.1) * 0.04
