class_name Birds
extends MultiMeshInstance3D
## A flock circling over a spot: gulls over the sea, pigeons over a plaza, crows over the hills, bats in a warehouse.
## One MultiMesh (one draw call) of low-poly birds whose wings flap in the vertex shader (bird.gdshader); each bird
## wheels on its own circle (radius, height, speed and phase from a seeded rng), banking into the turn, and gulls
## glide most of the time. Cheap enough for a few flocks of 10 to 30.
## Use: var gulls := Birds.flock("gull", 14, Vector3(0, 18, 120), 40.0); add_child(gulls)

const SHADER: Shader = preload("res://game/world/bird.gdshader")
## kind -> [span m, body colour, wing colour, tip colour, flap Hz, glide share, speed m/s]
const KINDS: Dictionary = {
	"gull": [1.15, Color("f4f4f2"), Color("c9ced6"), Color("2b2d33"), 2.4, 0.7, 7.5],
	"pigeon": [0.62, Color("8d93a3"), Color("a7adbb"), Color("454a58"), 5.5, 0.15, 6.5],
	"crow": [0.85, Color("26262c"), Color("2f3038"), Color("1a1a1f"), 3.2, 0.4, 7.0],
	"bat": [0.5, Color("2a2230"), Color("3a2e40"), Color("231b28"), 8.0, 0.0, 6.0],
}

var kind: String = "gull"
var centre: Vector3 = Vector3.ZERO
var radius: float = 30.0
var spread_height: float = 6.0
var _birds: Array[Dictionary] = []
var _t: float = 0.0


## A flock of `count` birds of `kind` wheeling round `at` (the flock's centre, at its mean height) within `r` metres.
static func flock(bird_kind: String, count: int, at: Vector3, r: float = 30.0, seed_value: int = 9) -> Birds:
	var b := Birds.new()
	b.name = "Birds_" + bird_kind
	b.kind = bird_kind if KINDS.has(bird_kind) else "gull"
	b.centre = at
	b.radius = r
	var spec: Array = KINDS[b.kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = Birds.bird_mesh(float(spec[0]), spec[1] as Color, spec[2] as Color, spec[3] as Color)
	mm.instance_count = count
	for i: int in count:
		var d: Dictionary = {
			"r": r * rng.randf_range(0.35, 1.0), "h": rng.randf_range(-b.spread_height, b.spread_height) * 0.5,
			"w": float(spec[6]) / maxf(r * 0.7, 1.0) * rng.randf_range(0.8, 1.2) * (1.0 if rng.randf() < 0.85 else -1.0),
			"a": rng.randf() * TAU, "bob": rng.randf() * TAU, "glide": float(spec[5]), "flip": rng.randf() * 100.0,
		}
		b._birds.append(d)
		mm.set_instance_custom_data(i, Color(rng.randf(), float(spec[4]) * rng.randf_range(0.85, 1.15), 0.0, 0.0))
	b.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = SHADER
	b.material_override = m
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.custom_aabb = AABB(at - Vector3(r + 5.0, 12.0, r + 5.0), Vector3((r + 5.0) * 2.0, 24.0, (r + 5.0) * 2.0))
	b.position = Vector3.ZERO
	b._update(0.0)
	return b


func _process(delta: float) -> void:
	_t += delta
	_update(delta)


func _update(_delta: float) -> void:
	var mm: MultiMesh = multimesh
	var origin: Vector3 = global_position if is_inside_tree() else position
	for i: int in _birds.size():
		var d: Dictionary = _birds[i]
		var a: float = float(d["a"]) + float(d["w"]) * _t
		var r: float = float(d["r"]) * (1.0 + 0.15 * sin(_t * 0.13 + float(d["bob"])))
		var p: Vector3 = centre + Vector3(cos(a) * r, float(d["h"]) + 0.8 * sin(_t * 0.7 + float(d["bob"])), sin(a) * r)
		var w: float = float(d["w"])
		var vel := Vector3(-sin(a), 0.0, cos(a)) * signf(w)
		var bank: float = clampf(w * 4.0, -0.6, 0.6)
		var basis := Basis.looking_at(vel, Vector3.UP) * Basis(Vector3(0, 0, 1), bank)
		mm.set_instance_transform(i, Transform3D(basis, p - origin))
		# gliding comes and goes in stretches
		var g: float = 1.0 if sin(_t * 0.4 + float(d["flip"])) < float(d["glide"]) * 2.0 - 1.0 else 0.0
		var cd: Color = mm.get_instance_custom_data(i)
		if cd.b != g:
			cd.b = g
			mm.set_instance_custom_data(i, cd)


## A low-poly bird, nose toward -Z, `span` metres wingtip to wingtip. UV.x = distance out along the wing (0..1).
static func bird_mesh(span: float, body_c: Color, wing_c: Color, tip_c: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var L: float = span * 0.36
	var hw: float = span * 0.06
	var b: Color = body_c.srgb_to_linear()
	# body: a stretched double pyramid
	var nose := Vector3(0, 0, -L * 0.55)
	var tail := Vector3(0, 0, L * 0.5)
	var ring: Array[Vector3] = [Vector3(hw, 0, 0), Vector3(0, hw, -L * 0.05), Vector3(-hw, 0, 0), Vector3(0, -hw * 0.8, 0)]
	for k: int in 4:
		var a: Vector3 = ring[k]
		var c: Vector3 = ring[(k + 1) % 4]
		Birds._tri(st, nose, a, c, b, 0.0)
		Birds._tri(st, tail, c, a, b, 0.0)
	# tail fan
	Birds._tri(st, Vector3(-hw * 1.6, 0, L * 0.75), Vector3(hw * 1.6, 0, L * 0.75), Vector3(0, 0, L * 0.3), b, 0.0)
	# wings: two segments each side, swept back, darker toward the tip
	for side: float in [-1.0, 1.0]:
		var root_f := Vector3(side * hw, 0.02, -L * 0.18)
		var root_b := Vector3(side * hw, 0.02, L * 0.12)
		var mid_f := Vector3(side * span * 0.26, 0.04, -L * 0.12)
		var mid_b := Vector3(side * span * 0.26, 0.04, L * 0.2)
		var tip := Vector3(side * span * 0.5, 0.0, L * 0.25)
		var wc: Color = wing_c.srgb_to_linear()
		var tc: Color = tip_c.srgb_to_linear()
		Birds._quad(st, root_f, mid_f, mid_b, root_b, [wc, wc, wc, wc], [0.0, 0.5, 0.5, 0.0])
		Birds._tri3(st, mid_f, tip, mid_b, [wc, tc, wc], [0.5, 1.0, 0.5])
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, w: float) -> void:
	for p: Vector3 in [a, b, c]:
		st.set_color(col)
		st.set_uv(Vector2(w, 0.0))
		st.add_vertex(p)


static func _tri3(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, cols: Array, ws: Array) -> void:
	var ps: Array[Vector3] = [a, b, c]
	for i: int in 3:
		st.set_color(cols[i] as Color)
		st.set_uv(Vector2(float(ws[i]), 0.0))
		st.add_vertex(ps[i])


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, cols: Array, ws: Array) -> void:
	Birds._tri3(st, a, b, c, [cols[0], cols[1], cols[2]], [ws[0], ws[1], ws[2]])
	Birds._tri3(st, a, c, d, [cols[0], cols[2], cols[3]], [ws[0], ws[2], ws[3]])
