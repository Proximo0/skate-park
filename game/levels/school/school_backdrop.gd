class_name SchoolBackdrop
extends RefCounted
## Everything past the School's perimeter road, all visual (no collision, no shadows): the town (houses and a few
## blocks as two MultiMeshes with lit windows, school_town.gdshader), street trees, street-lamp glows, rolling hills
## that rise behind the sports field to the north and ring the valley, a far mountain ridge for the sunset to sit on,
## and the landmarks: the water tower, a church steeple and a radio mast with a blinking light. Seeded: the same view
## every run.

const SEED: int = 4417
const TOWN_SHADER: Shader = preload("res://game/levels/school/school_town.gdshader")
## Keep-out rect: the campus, its road and sidewalks (houses start past it).
const CAMPUS := Rect2(-134.0, -128.0, 268.0, 252.0)
const WALLS: Array[Color] = [Color("e8dcc4"), Color("d9c3a0"), Color("c9d6d8"), Color("e6c9b8"), Color("b8c9a8"),
		Color("f0e6d2"), Color("cbb79c"), Color("a9b8c9"), Color("e2d0a8"), Color("d6b8a8")]
const BLOCK_WALLS: Array[Color] = [Color("c9b99a"), Color("b97a62"), Color("8fa8b4"), Color("d9cbb0"), Color("a58d78")]


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Town"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	root.add_child(_terrain())
	root.add_child(_ridge(rng))
	var trees := SwayTrees.new()
	trees.name = "TownTrees"
	trees.seed_value = 77
	var glows: Array[Vector3] = []
	_town(root, rng, trees, glows)
	_landmarks(root, trees)
	root.add_child(trees)
	root.add_child(_glows(glows))
	return root


# --- terrain ----------------------------------------------------------------------------------------------

## Ground height outside the campus: flat (just under the lawns) in the valley, rising into the hills to the north and
## round the rim.
static func terrain_h(x: float, z: float) -> float:
	var n: float = _vnoise(x * 0.008 + 3.1, z * 0.008 - 1.7)
	var n2: float = _vnoise(x * 0.021 - 5.0, z * 0.021 + 2.0)
	var d: float = Vector2(x, z).length()
	var rim: float = smoothstep(300.0, 560.0, d) * (55.0 + 75.0 * n)
	var north: float = smoothstep(130.0, 360.0, -z) * (26.0 + 40.0 * n + 8.0 * n2) * (1.0 - 0.5 * smoothstep(200.0, 420.0, absf(x)))
	return maxf(rim, north) + 2.0 * n2 * smoothstep(150.0, 260.0, d) - 0.14


static func _terrain() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii: Array[float] = [118.0, 140.0, 165.0, 195.0, 230.0, 270.0, 315.0, 365.0, 420.0, 480.0, 545.0, 615.0, 690.0, 770.0, 860.0]
	var na: int = 160
	var pts: Array = []
	for r: float in radii:
		var ring: Array[Vector3] = []
		for i: int in na:
			var a: float = TAU * float(i) / float(na)
			var x: float = cos(a) * r
			var z: float = sin(a) * r
			ring.append(Vector3(x, terrain_h(x, z), z))
		pts.append(ring)
	for j: int in radii.size() - 1:
		var r0: Array = pts[j]
		var r1: Array = pts[j + 1]
		for i: int in na:
			var k: int = (i + 1) % na
			var a: Vector3 = r0[i]
			var b: Vector3 = r0[k]
			var c: Vector3 = r1[k]
			var d: Vector3 = r1[i]
			for v: Vector3 in [a, c, b, a, d, c]:
				st.set_color(_terrain_colour(v).srgb_to_linear())
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Hills"
	mi.mesh = st.commit()
	mi.material_override = Toon.material_vc(Color.WHITE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _terrain_colour(v: Vector3) -> Color:
	var low := Color("52733a")
	var mid := Color("44683a")
	var high := Color("707a48")
	var d: float = Vector2(v.x, v.z).length()
	var t: float = clampf(v.y / 60.0, 0.0, 1.0)
	var c: Color = low.lerp(mid, smoothstep(0.0, 0.4, t)).lerp(high, smoothstep(0.5, 1.0, t))
	# dry golden patches on the far slopes
	var g: float = _vnoise(v.x * 0.02, v.z * 0.02)
	c = c.lerp(Color("a99a55"), smoothstep(0.62, 0.8, g) * smoothstep(200.0, 400.0, d) * 0.6)
	return c


## The far ridge: a jagged band of mountains at about 950 m, darker at the foot.
static func _ridge(rng: RandomNumberGenerator) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 120
	var tops: Array[Vector3] = []
	var feet: Array[Vector3] = []
	var hs: Array[float] = []
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var peak: float = 90.0 + 150.0 * pow(_vnoise(float(i) * 0.22, 7.3), 1.6) + rng.randf_range(-12.0, 12.0)
		# taller behind the field (north and north-west, where the sun sets)
		var dir := Vector2(cos(a), sin(a))
		peak *= 1.0 + 0.5 * maxf(0.0, dir.dot(Vector2(-0.6, -0.8)))
		hs.append(peak)
		var r: float = 960.0 + rng.randf_range(-40.0, 40.0)
		tops.append(Vector3(dir.x * r, peak, dir.y * r))
		feet.append(Vector3(dir.x * (r - 90.0), -10.0, dir.y * (r - 90.0)))
	var foot_c := Color("3d4a5c")
	var top_c := Color("7e86a0")
	for i: int in n:
		var k: int = (i + 1) % n
		var cf := foot_c
		var ct := top_c
		for tri: Array in [[feet[i], tops[k], tops[i]], [feet[i], feet[k], tops[k]]]:
			for v: Vector3 in tri:
				st.set_color((cf if v.y < 0.0 else ct.lerp(Color("c9c2cf"), clampf((v.y - 150.0) / 120.0, 0.0, 1.0))).srgb_to_linear())
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Ridge"
	mi.mesh = st.commit()
	mi.material_override = Toon.material_vc(Color.WHITE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# --- the town ---------------------------------------------------------------------------------------------

static func _town(root: Node3D, rng: RandomNumberGenerator, trees: SwayTrees, glows: Array[Vector3]) -> void:
	var houses: Array = []  # [Transform3D, Color custom]
	var blocks: Array = []
	var lot := Vector2(17.0, 21.0)
	for gx: int in range(-19, 20):
		for gz: int in range(-16, 17):
			var col: int = posmod(gx, 3)
			var row: int = posmod(gz, 4)
			var cx: float = float(gx) * lot.x
			var cz: float = float(gz) * lot.y
			if col == 0 or row == 0:
				# a street: lamps along it now and then, trees on the verges
				if col == 0 and row == 2 and not CAMPUS.has_point(Vector2(cx, cz)):
					glows.append(Vector3(cx + 3.5, terrain_h(cx + 3.5, cz) + 6.5, cz))
				if row == 0 and col == 2 and not CAMPUS.has_point(Vector2(cx, cz)) and rng.randf() < 0.5:
					trees.add("round", Vector3(cx, terrain_h(cx, cz), cz + 6.0), rng.randf_range(1.0, 1.5))
				continue
			var p := Vector2(cx + rng.randf_range(-2.0, 2.0), cz + rng.randf_range(-2.0, 2.0))
			if CAMPUS.grow(4.0).has_point(p):
				continue
			var d: float = p.length()
			if d > 420.0:
				continue
			var y: float = terrain_h(p.x, p.y)
			if y > 34.0:
				continue
			var hill: bool = p.y < -130.0
			if hill and rng.randf() < 0.45:
				trees.add("pine", Vector3(p.x, y, p.y), rng.randf_range(1.2, 1.7))
				continue
			if rng.randf() < 0.14:
				# a garden: trees instead of a house
				trees.add("round" if rng.randf() < 0.7 else "pine", Vector3(p.x, y, p.y), rng.randf_range(1.1, 1.6))
				continue
			var face: float = 0.0 if col == 1 else PI  # face the street on the left or the right
			var downtown: bool = p.x > 150.0 and p.y > 140.0 and d < 380.0
			if downtown:
				var bh: float = rng.randf_range(9.0, 26.0)
				var xf := Transform3D(Basis(Vector3.UP, face + PI * 0.5).scaled(Vector3(rng.randf_range(12.0, 16.0), bh, rng.randf_range(13.0, 18.0))), Vector3(p.x, y - 0.3, p.y))
				var bc: Color = BLOCK_WALLS[rng.randi() % BLOCK_WALLS.size()]
				blocks.append([xf, Color(bc.r, bc.g, bc.b, rng.randf())])
				continue
			var w: float = rng.randf_range(8.0, 11.5)
			var dd: float = rng.randf_range(7.5, 10.0)
			var h: float = rng.randf_range(3.2, 3.6) * (2.0 if rng.randf() < 0.45 else 1.0)
			var xf2 := Transform3D(Basis(Vector3.UP, face + PI * 0.5 + rng.randf_range(-0.05, 0.05)).scaled(Vector3(w, h, dd)), Vector3(p.x, y - 0.3, p.y))
			var wc: Color = WALLS[rng.randi() % WALLS.size()]
			houses.append([xf2, Color(wc.r, wc.g, wc.b, rng.randf())])
			# a tree in most front yards
			if rng.randf() < 0.6:
				var off := Vector3(rng.randf_range(-4.0, 4.0), 0.0, 0.0)
				var tp := Vector3(p.x, 0.0, p.y) + Basis(Vector3.UP, face + PI * 0.5) * (off + Vector3(0.0, 0.0, -dd * 0.5 - 3.0))
				trees.add("round", Vector3(tp.x, terrain_h(tp.x, tp.z), tp.z), rng.randf_range(0.9, 1.4))
	root.add_child(_multi("Houses", _house_mesh(true), houses, {"floors": 2.0, "floor_h": 3.4, "bay": 3.4, "win_w": 1.3, "lit_ratio": 0.5}))
	root.add_child(_multi("Blocks", _house_mesh(false), blocks, {"floors": 8.0, "floor_h": 3.2, "bay": 3.0, "win_w": 1.8, "win_h": 1.5, "lit_ratio": 0.4}))


static func _multi(node_name: String, mesh: ArrayMesh, items: Array, params: Dictionary) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i: int in items.size():
		mm.set_instance_transform(i, items[i][0] as Transform3D)
		mm.set_instance_custom_data(i, items[i][1] as Color)
	var mat := ShaderMaterial.new()
	mat.shader = TOWN_SHADER
	for k: String in params:
		mat.set_shader_parameter(k, params[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## A unit house: a 1 x 1 x 1 body (base at y 0) and, if `gable`, a gable roof up to y 1.55 (vertex alpha 0 = roof).
## Without a gable: a flat-roofed block with a parapet band.
static func _house_mesh(gable: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall := Color(1, 1, 1, 1)
	var roof := Color(1, 1, 1, 0)
	var c: Array[Vector3] = []
	for i: int in 8:
		c.append(Vector3(-0.5 if i & 1 == 0 else 0.5, 0.0 if i & 2 == 0 else 1.0, -0.5 if i & 4 == 0 else 0.5))
	var o := Vector3(0.0, 0.5, 0.0)
	_q(st, c[0], c[1], c[3], c[2], o, wall)
	_q(st, c[4], c[5], c[7], c[6], o, wall)
	_q(st, c[0], c[2], c[6], c[4], o, wall)
	_q(st, c[1], c[3], c[7], c[5], o, wall)
	if gable:
		var r0 := Vector3(-0.55, 1.55, 0.0)
		var r1 := Vector3(0.55, 1.55, 0.0)
		var e := [Vector3(-0.55, 0.97, -0.58), Vector3(0.55, 0.97, -0.58), Vector3(0.55, 0.97, 0.58), Vector3(-0.55, 0.97, 0.58)]
		var oc := Vector3(0.0, 1.0, 0.0)
		_q(st, e[0], e[1], r1, r0, oc, roof)
		_q(st, e[3], e[2], r1, r0, oc, roof)
		# gable ends (wall colour)
		_t(st, Vector3(-0.5, 1.0, -0.5), Vector3(-0.5, 1.0, 0.5), Vector3(-0.5, 1.5, 0.0), Vector3(-1, 0, 0), wall)
		_t(st, Vector3(0.5, 1.0, -0.5), Vector3(0.5, 1.0, 0.5), Vector3(0.5, 1.5, 0.0), Vector3(1, 0, 0), wall)
		# roof undersides
		_q(st, e[0], e[1], r1, r0, Vector3(0.0, 2.0, 0.0), roof)
		_q(st, e[3], e[2], r1, r0, Vector3(0.0, 2.0, 0.0), roof)
	else:
		_q(st, c[2], c[3], c[7], c[6], o, roof)
	return st.commit()


static func _q(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, col: Color) -> void:
	var want: Vector3 = (a + b + c + d) * 0.25 - inside
	_t(st, a, b, c, want, col)
	_t(st, a, c, d, want, col)


static func _t(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, want: Vector3, col: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.dot(want) < 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
		n = -n
	n = n.normalized()
	for v: Vector3 in [a, c, b]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)


# --- landmarks and lights -----------------------------------------------------------------------------------

static func _landmarks(root: Node3D, trees: SwayTrees) -> void:
	var g := SchoolGeo.new(root, "Landmarks")
	# the water tower on the hill to the north-east
	var wt := Vector3(190.0, 0.0, -205.0)
	wt.y = terrain_h(wt.x, wt.z)
	var leg: String = SchoolGeo.toon(Color("8a9099"))
	for k: int in 4:
		var a: float = PI * 0.25 + PI * 0.5 * float(k)
		var foot: Vector3 = wt + Vector3(cos(a) * 6.0, -1.0, sin(a) * 6.0)
		g.cyl(foot, wt + Vector3(cos(a) * 3.6, 24.0, sin(a) * 3.6), 0.35, leg, 6)
	g.lathe(wt + Vector3(0.0, 23.5, 0.0), PackedVector2Array([Vector2(0.0, 0.0), Vector2(6.5, 1.5), Vector2(6.8, 2.2), Vector2(6.8, 8.0),
			Vector2(5.8, 9.6), Vector2(1.2, 11.0), Vector2(0.0, 11.4)]), 24, SchoolGeo.toon(Color("cfd6dc")), false)
	var lab := Label3D.new()
	lab.text = "SUNSET VALLEY"
	lab.font_size = 160
	lab.pixel_size = 0.03
	lab.modulate = Color("2f5f9e")
	lab.outline_size = 0
	lab.shaded = true
	lab.position = wt + Vector3(-5.0, 28.6, 4.3)
	lab.rotation.y = deg_to_rad(-40.0)
	root.add_child(lab)
	# a church steeple in the south-west
	var ch := Vector3(-205.0, 0.0, 190.0)
	ch.y = terrain_h(ch.x, ch.z)
	g.box(ch + Vector3(-8.0, -0.3, -12.0), Vector3(16.0, 9.0, 24.0), SchoolGeo.toon(Color("eae2d2")), false)
	g.prism(Transform3D(Basis.IDENTITY, ch), PackedVector2Array([Vector2(-12.4, 8.6), Vector2(12.4, 8.6), Vector2(0.0, 15.0)]), -8.4, 8.4, SchoolGeo.toon(Color("6b4a44")), false)
	g.box(ch + Vector3(-3.0, -0.3, 12.0), Vector3(6.0, 20.0, 6.0), SchoolGeo.toon(Color("eae2d2")), false)
	g.lathe(ch + Vector3(0.0, 19.7, 15.0), PackedVector2Array([Vector2(0.0, -0.01), Vector2(4.4, 0.0), Vector2(0.0, 14.0)]), 4, SchoolGeo.toon(Color("4c5a6e")), false, PI * 0.25, PI * 2.25)
	# the radio mast on the north-west hill, with a blinking light
	var rm := Vector3(-230.0, 0.0, -300.0)
	rm.y = terrain_h(rm.x, rm.z)
	g.cyl(rm, rm + Vector3(0.0, 60.0, 0.0), 0.5, SchoolGeo.toon(Color("c8402e")), 4)
	for k: int in 6:
		g.cyl(rm + Vector3(0.0, 10.0 * float(k) + 2.0, 0.0), rm + Vector3(0.0, 10.0 * float(k) + 6.0, 0.0), 0.9, SchoolGeo.toon(Color("e8e4dc")), 4)
	var blink := SchoolBlinker.create(Color(2.2, 0.25, 0.15))
	blink.position = rm + Vector3(0.0, 61.0, 0.0)
	root.add_child(blink)
	# trees round the landmarks
	for k: int in 6:
		var a: float = float(k) * 1.1
		trees.add("pine", wt + Vector3(cos(a) * 14.0, 0.0, sin(a) * 14.0), 1.5)
	g.commit()


## The town's street lamps: small glowing heads (one MultiMesh, unshaded).
static func _glows(pts: Array[Vector3]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.7
	sm.radial_segments = 6
	sm.rings = 3
	mm.mesh = sm
	mm.instance_count = pts.size()
	for i: int in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i]))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(2.2, 1.7, 1.1)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "TownLamps"
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## Smooth value noise in 0..1 (deterministic, no RandomNumberGenerator).
static func _vnoise(x: float, z: float) -> float:
	var ix: float = floorf(x)
	var iz: float = floorf(z)
	var fx: float = x - ix
	var fz: float = z - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a: float = _hash(ix, iz)
	var b: float = _hash(ix + 1.0, iz)
	var c: float = _hash(ix, iz + 1.0)
	var d: float = _hash(ix + 1.0, iz + 1.0)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


static func _hash(x: float, z: float) -> float:
	var h: float = sin(x * 127.1 + z * 311.7) * 43758.5453
	return h - floorf(h)
