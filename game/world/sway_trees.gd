class_name SwayTrees
extends Node3D
## Trees that move: palms, round leafy trees, pines and bushes, each kind one MultiMesh (one draw call per kind however
## many trees), swaying in the wind in the vertex shader (sway.gdshader). Seeded size and turn per tree.
## Use: var trees := SwayTrees.new(); trees.add("palm", Vector3(10, 0, 40)); ...; add_child(trees)
## (add before or after add_child: the MultiMeshes are rebuilt at _ready and on rebuild()).

const SHADER: Shader = preload("res://game/world/sway.gdshader")
const KIND_NAMES: Array[String] = ["palm", "round", "pine", "bush"]

@export var seed_value: int = 21
var _spots: Dictionary = {}  ## kind -> Array of [pos, scale, yaw]
var _rng := RandomNumberGenerator.new()
static var _meshes: Dictionary = {}


func _init() -> void:
	_rng.seed = seed_value


## Adds a tree of `kind` at `pos` (size `size` x the kind's default, 0 = a random 0.85..1.2).
func add(kind: String, pos: Vector3, size: float = 0.0) -> void:
	if not _spots.has(kind):
		_spots[kind] = []
	var sc: float = size if size > 0.0 else _rng.randf_range(0.85, 1.2)
	(_spots[kind] as Array).append([pos, sc, _rng.randf() * TAU])


func count() -> int:
	var n: int = 0
	for k: String in _spots:
		n += (_spots[k] as Array).size()
	return n


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for c: Node in get_children():
		c.queue_free()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	for kind: String in _spots:
		var spots: Array = _spots[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = SwayTrees.mesh_for(kind)
		mm.instance_count = spots.size()
		for i: int in spots.size():
			var sp: Array = spots[i]
			var b := Basis(Vector3.UP, float(sp[2])).scaled(Vector3.ONE * float(sp[1]))
			mm.set_instance_transform(i, Transform3D(b, sp[0] as Vector3))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Trees_" + kind
		mmi.multimesh = mm
		mmi.material_override = mat
		add_child(mmi)


## The shared mesh of a kind (built once).
static func mesh_for(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind] as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"palm":
			SwayTrees._palm(st)
		"pine":
			SwayTrees._pine(st)
		"bush":
			SwayTrees._blob(st, Vector3(0, 0.55, 0), 0.8, Color("3f8f4c"), 0.0, 0.15, 0.6)
			SwayTrees._blob(st, Vector3(0.55, 0.45, 0.2), 0.55, Color("4fa65a"), 0.0, 0.15, 0.6)
			SwayTrees._blob(st, Vector3(-0.5, 0.4, -0.15), 0.5, Color("37814a"), 0.0, 0.15, 0.6)
		_:
			SwayTrees._round(st)
	st.generate_normals()
	var m: ArrayMesh = st.commit()
	_meshes[kind] = m
	return m


static func _palm(st: SurfaceTool) -> void:
	var trunk := Color("b88a5a")
	var ring := Color("9a6e45")
	var h: float = 7.0
	var segs: int = 8
	var top := Vector3.ZERO
	for i: int in segs:
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var c0 := Vector3(1.1 * t0 * t0, h * t0, 0.0)
		var c1 := Vector3(1.1 * t1 * t1, h * t1, 0.0)
		var r0: float = lerpf(0.24, 0.15, t0)
		var r1: float = lerpf(0.24, 0.15, t1)
		SwayTrees._tube(st, c0, c1, r0, r1, 6, trunk if i % 2 == 0 else ring, t0, t1, 0.0)
		top = c1
	# crown: eight drooping fronds, each a bent strip with a leafy fringe
	var frond := Color("2f9a58")
	var frond_dark := Color("23804a")
	for k: int in 8:
		var a: float = TAU * float(k) / 8.0 + 0.2 * float(k % 2)
		var d := Vector3(cos(a), 0.0, sin(a))
		var side: Vector3 = d.cross(Vector3.UP).normalized()
		var prev := top
		var n: int = 5
		var length: float = 3.2 if k % 2 == 0 else 2.6
		for j: int in n:
			var u0: float = float(j) / float(n)
			var u1: float = float(j + 1) / float(n)
			var p1: Vector3 = top + d * length * u1 + Vector3.UP * (0.6 * u1 - 2.0 * u1 * u1)
			var w0: float = 0.55 * sin(PI * clampf(u0 * 1.1, 0.0, 1.0)) + 0.08
			var w1: float = 0.55 * sin(PI * clampf(u1 * 1.1, 0.0, 1.0)) + 0.08
			var col: Color = frond if j % 2 == 0 else frond_dark
			SwayTrees._quad(st, prev - side * w0, prev + side * w0, p1 + side * w1, p1 - side * w1, col, [1.0, 1.0, 1.0, 1.0], [u0, u0, u1, u1])
			prev = p1
	# coconuts
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0
		SwayTrees._blob(st, top + Vector3(cos(a) * 0.22, -0.25, sin(a) * 0.22), 0.16, Color("6e4a28"), 1.0, 0.0, 0.0)


static func _round(st: SurfaceTool) -> void:
	SwayTrees._tube(st, Vector3.ZERO, Vector3(0, 2.4, 0), 0.22, 0.16, 6, Color("8a5a36"), 0.0, 0.5, 0.0)
	SwayTrees._tube(st, Vector3(0, 1.8, 0), Vector3(0.7, 2.9, 0.2), 0.1, 0.06, 5, Color("8a5a36"), 0.4, 0.6, 0.0)
	var greens: Array[Color] = [Color("3f9a4a"), Color("4caa52"), Color("358a45"), Color("5fb25c"), Color("3a9048")]
	var spots: Array[Vector3] = [Vector3(0, 3.4, 0), Vector3(0.9, 3.0, 0.3), Vector3(-0.8, 3.1, -0.3), Vector3(0.2, 4.1, -0.5), Vector3(-0.2, 3.0, 0.9)]
	var radii: Array[float] = [1.5, 1.1, 1.15, 1.0, 1.0]
	for i: int in spots.size():
		SwayTrees._blob(st, spots[i], radii[i], greens[i], 0.8, 0.5, 1.0)


static func _pine(st: SurfaceTool) -> void:
	SwayTrees._tube(st, Vector3.ZERO, Vector3(0, 1.4, 0), 0.2, 0.16, 6, Color("6e4a30"), 0.0, 0.2, 0.0)
	var greens: Array[Color] = [Color("2c6e4a"), Color("357d52"), Color("2f7550"), Color("3c8a5a")]
	for i: int in 4:
		var y0: float = 1.0 + float(i) * 1.25
		var r: float = 1.9 - float(i) * 0.38
		SwayTrees._cone(st, Vector3(0, y0, 0), r, 2.0, 9, greens[i], (y0 - 0.5) / 6.0, (y0 + 2.0) / 6.0)


## A low-poly sphere-ish blob (octahedron subdivided once), sway weight w, flutter f.
static func _blob(st: SurfaceTool, c: Vector3, r: float, col: Color, w: float, f: float, _rough: float) -> void:
	var v: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var faces: Array = [[2, 4, 0], [2, 0, 5], [2, 5, 1], [2, 1, 4], [3, 0, 4], [3, 5, 0], [3, 1, 5], [3, 4, 1]]
	for fc: Array in faces:
		var a: Vector3 = v[fc[0]]
		var b: Vector3 = v[fc[1]]
		var d: Vector3 = v[fc[2]]
		var ab: Vector3 = (a + b).normalized()
		var bd: Vector3 = (b + d).normalized()
		var da: Vector3 = (d + a).normalized()
		for tri: Array in [[a, ab, da], [ab, b, bd], [da, bd, d], [ab, bd, da]]:
			var ps: Array[Vector3] = []
			for p: Vector3 in tri:
				ps.append(c + Vector3(p.x * r, p.y * r * 0.85, p.z * r))
			SwayTrees._quad_tri(st, ps[0], ps[1], ps[2], col, w, f)


static func _quad_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, w: float, f: float) -> void:
	var lc: Color = col.srgb_to_linear()
	for p: Vector3 in [a, b, c]:
		st.set_color(lc)
		st.set_uv(Vector2(w, f))
		st.add_vertex(p)


static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, col: Color, w0: float, w1: float, f: float) -> void:
	var axis: Vector3 = (b - a).normalized()
	var u: Vector3 = axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var v: Vector3 = axis.cross(u).normalized()
	var lc: Color = col.srgb_to_linear()
	for i: int in sides:
		var t0: float = TAU * float(i) / float(sides)
		var t1: float = TAU * float(i + 1) / float(sides)
		var d0: Vector3 = u * cos(t0) + v * sin(t0)
		var d1: Vector3 = u * cos(t1) + v * sin(t1)
		var p := [a + d0 * r0, a + d1 * r0, b + d1 * r1, b + d0 * r1]
		var ws := [w0, w0, w1, w1]
		for k: int in [0, 2, 1, 0, 3, 2]:
			st.set_color(lc)
			st.set_uv(Vector2(float(ws[k]), f))
			st.add_vertex(p[k] as Vector3)


static func _cone(st: SurfaceTool, base: Vector3, r: float, h: float, sides: int, col: Color, w0: float, w1: float) -> void:
	var lc: Color = col.srgb_to_linear()
	var tip: Vector3 = base + Vector3(0, h, 0)
	for i: int in sides:
		var t0: float = TAU * float(i) / float(sides)
		var t1: float = TAU * float(i + 1) / float(sides)
		var a: Vector3 = base + Vector3(cos(t0) * r, -0.25, sin(t0) * r)
		var b: Vector3 = base + Vector3(cos(t1) * r, -0.25, sin(t1) * r)
		for pw: Array in [[a, w0], [tip, w1], [b, w0], [a, w0], [b, w0], [base, w0]]:
			st.set_color(lc)
			st.set_uv(Vector2(float(pw[1]), 0.1))
			st.add_vertex(pw[0] as Vector3)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, ws: Array, fs: Array) -> void:
	var lc: Color = col.srgb_to_linear()
	var ps: Array[Vector3] = [a, b, c, d]
	for k: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(lc)
		st.set_uv(Vector2(float(ws[k]), float(fs[k])))
		st.add_vertex(ps[k])
