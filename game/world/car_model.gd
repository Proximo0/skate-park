class_name CarModel
extends Node3D
## A cheap drawable car from the Houdini glbs (HoudiniProps: car_hatchback, car_pickup, car_surfvan), baked for crowds:
##   Body   every body surface merged into one vertex-coloured toon mesh (paint `tint` baked in): 1 draw call
##   Wheels the four wheels merged, spun about their axles in the vertex shader (car_wheel.gdshader): 1 draw call
##   Lamps  the head and tail lamp surfaces, glowing at night or under braking (car_lamps.gdshader): 1 draw call
##   Beams  night only: headlight cones and a light pool on the road (car_beams.gdshader, additive): 1 draw call
## Baked meshes are cached per kind (and per kind + paint for the body), so twenty cars share a handful of meshes.
## Conventions of the glbs: origin at the ground centre, nose toward -Z.

const KINDS: Dictionary = {"hatch": "car_hatchback", "pickup": "car_pickup", "van": "car_surfvan"}
## Paint colours for traffic: everyday car colours first, then the game's skate/surf palette.
const PAINTS: Array[String] = [
	"eeeeea", "2a2d34", "9aa3ad", "b3262d", "264f8f", "f2c94c", "3d7a5a", "6b3f8f",
	"ff6b5e", "4fd1c5", "ff8ec7", "7ec8e3", "ffb199", "ff8a3d", "f4f0e6", "5fcf80",
]
const WHEEL_SHADER: Shader = preload("res://game/world/car_wheel.gdshader")
const LAMP_SHADER: Shader = preload("res://game/world/car_lamps.gdshader")
const BEAM_SHADER: Shader = preload("res://game/world/car_beams.gdshader")
const LAMP_SURFACES: Array[String] = ["light", "taillight"]
const TINTED: Array[String] = ["body"]

static var _body_cache: Dictionary = {}
static var _kind_cache: Dictionary = {}  ## kind -> {wheels: ArrayMesh, lamps: ArrayMesh, aabb: AABB, axle_y, front_z, back_z, radius}
static var _beam_mesh: ArrayMesh = null

var kind: String = "hatch"
var aabb: AABB = AABB()
var wheel_radius: float = 0.33
var _wheel_mat: ShaderMaterial
var _lamp_mat: ShaderMaterial
var _beams: MeshInstance3D = null
var _spin: float = 0.0


## A car of `kind` ("hatch", "pickup", "van") painted `tint`.
static func create(car_kind: String, tint: Color) -> CarModel:
	var cm := CarModel.new()
	cm.name = "CarModel"
	cm.kind = car_kind if KINDS.has(car_kind) else "hatch"
	var info: Dictionary = CarModel.kind_info(cm.kind)
	cm.aabb = info["aabb"] as AABB
	cm.wheel_radius = float(info["radius"])
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = CarModel.body_mesh(cm.kind, tint)
	body.material_override = Toon.material_vc(Color.WHITE)
	cm.add_child(body)
	var wheels := MeshInstance3D.new()
	wheels.name = "Wheels"
	wheels.mesh = info["wheels"] as ArrayMesh
	cm._wheel_mat = ShaderMaterial.new()
	cm._wheel_mat.shader = WHEEL_SHADER
	cm._wheel_mat.set_shader_parameter("axle_y", float(info["axle_y"]))
	cm._wheel_mat.set_shader_parameter("axle_front_z", float(info["front_z"]))
	cm._wheel_mat.set_shader_parameter("axle_back_z", float(info["back_z"]))
	wheels.material_override = cm._wheel_mat
	cm.add_child(wheels)
	var lamps := MeshInstance3D.new()
	lamps.name = "Lamps"
	lamps.mesh = info["lamps"] as ArrayMesh
	cm._lamp_mat = ShaderMaterial.new()
	cm._lamp_mat.shader = LAMP_SHADER
	lamps.material_override = cm._lamp_mat
	cm.add_child(lamps)
	return cm


## Rolls the wheels on by `dist` metres.
func roll(dist: float) -> void:
	_spin = fposmod(_spin - dist / maxf(wheel_radius, 0.05), TAU)
	_wheel_mat.set_shader_parameter("spin", _spin)


## Headlights on (with beams) or off.
func set_lights(on: bool) -> void:
	_lamp_mat.set_shader_parameter("on", 1.0 if on else 0.0)
	if on and _beams == null:
		_beams = MeshInstance3D.new()
		_beams.name = "Beams"
		_beams.mesh = CarModel.beam_mesh()
		var m := ShaderMaterial.new()
		m.shader = BEAM_SHADER
		_beams.material_override = m
		_beams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beams.position = Vector3(0.0, 0.0, aabb.position.z + 0.1)
		_beams.scale = Vector3(aabb.size.x / 1.86, 1.0, 1.0)
		add_child(_beams)
	if _beams != null:
		_beams.visible = on


func set_brake(amount: float) -> void:
	_lamp_mat.set_shader_parameter("brake", clampf(amount, 0.0, 1.0))


## Wheels, lamps, axle positions and the model AABB for a kind (baked once, cached).
static func kind_info(car_kind: String) -> Dictionary:
	if _kind_cache.has(car_kind):
		return _kind_cache[car_kind] as Dictionary
	var root: Node3D = HoudiniProps.scene(str(KINDS[car_kind])).instantiate() as Node3D
	var wheels := _Merger.new()
	var lamps := _Merger.new()
	var front_z: float = 0.0
	var back_z: float = 0.0
	var radius: float = 0.33
	var nf: int = 0
	var nb: int = 0
	for n: Node in root.get_children():
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null:
			continue
		if str(mi.name).begins_with("wheel"):
			var bb: AABB = mi.transform * mi.mesh.get_aabb()
			radius = bb.size.y * 0.5
			if bb.get_center().z < 0.0:
				front_z += bb.get_center().z
				nf += 1
			else:
				back_z += bb.get_center().z
				nb += 1
			for s: int in mi.mesh.get_surface_count():
				wheels.add(mi.mesh, s, mi.transform, _albedo(mi.mesh.surface_get_material(s)), 1.0)
		else:
			for s: int in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(s)
				if LAMP_SURFACES.has(_mat_name(m)):
					lamps.add(mi.mesh, s, mi.transform, _albedo(m), 1.0 if _mat_name(m) == "light" else 0.0)
	var info: Dictionary = {
		"wheels": wheels.commit(), "lamps": lamps.commit(), "aabb": HoudiniProps.aabb_of(root), "radius": radius,
		"axle_y": radius, "front_z": front_z / maxf(float(nf), 1.0), "back_z": back_z / maxf(float(nb), 1.0),
	}
	root.free()
	_kind_cache[car_kind] = info
	return info


## The body of a kind painted `tint`, every non-wheel, non-lamp surface merged into one vertex-coloured surface.
static func body_mesh(car_kind: String, tint: Color) -> ArrayMesh:
	var key: String = "%s|%s" % [car_kind, tint.to_html(false)]
	if _body_cache.has(key):
		return _body_cache[key] as ArrayMesh
	var root: Node3D = HoudiniProps.scene(str(KINDS[car_kind])).instantiate() as Node3D
	var body := _Merger.new()
	for n: Node in root.get_children():
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or str(mi.name).begins_with("wheel"):
			continue
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			var nm: String = _mat_name(m)
			if LAMP_SURFACES.has(nm):
				continue
			var c: Color = tint if TINTED.has(nm) else _albedo(m)
			if nm == "glass":
				c = Color("3d4f66")  # darker glass reads better than the glb's pale blue on a toon car
			body.add(mi.mesh, s, mi.transform, c, 1.0)
	var mesh: ArrayMesh = body.commit()
	root.free()
	_body_cache[key] = mesh
	return mesh


## Two beam cones (from the lamps forward along -Z, 9 m long) and a ground pool, as one mesh. Unit width car (1.86 m).
static func beam_mesh() -> ArrayMesh:
	if _beam_mesh != null:
		return _beam_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length: float = 11.0
	for side: float in [-0.62, 0.62]:
		# a flat-ish cone: a fan of quads from the lamp outward, angled a little down
		var lamp := Vector3(side, 0.72, 0.0)
		var far := Vector3(side * 2.2, 0.15, -length)
		for k: int in 2:
			var up: float = 0.55 if k == 0 else -0.25
			var w: float = 1.6
			var a := lamp + Vector3(-0.12, 0.0, 0.0)
			var b := lamp + Vector3(0.12, 0.0, 0.0)
			var c := far + Vector3(w, up, 0.0)
			var d := far + Vector3(-w, up, 0.0)
			_beam_quad(st, a, b, c, d, 0.0)
	# the pool on the ground ahead
	var p0 := Vector3(-1.1, 0.04, -0.6)
	var p1 := Vector3(1.1, 0.04, -0.6)
	var p2 := Vector3(3.2, 0.04, -length)
	var p3 := Vector3(-3.2, 0.04, -length)
	_beam_quad(st, p0, p1, p2, p3, 1.0)
	_beam_mesh = st.commit()
	return _beam_mesh


static func _beam_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, pool: float) -> void:
	var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var ps: Array[Vector3] = [a, b, c, d]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(Color(1, 1, 1, pool))
		st.set_uv(uvs[i])
		st.add_vertex(ps[i])


static func _mat_name(m: Material) -> String:
	return m.resource_name if m != null else ""


static func _albedo(m: Material) -> Color:
	if m is StandardMaterial3D:
		return (m as StandardMaterial3D).albedo_color
	return Color.WHITE


## Merges mesh surfaces into one surface, baking a colour per source surface into the vertex colours.
class _Merger:
	extends RefCounted
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	func add(mesh: Mesh, surface: int, xf: Transform3D, colour: Color, alpha: float) -> void:
		var arr: Array = mesh.surface_get_arrays(surface)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var base: int = verts.size()
		var lin: Color = colour.srgb_to_linear()  # shaders read COLOR as linear; source_color uniforms are converted the same way
		var c := Color(lin.r, lin.g, lin.b, alpha)
		for i: int in v.size():
			verts.append(xf * v[i])
			norms.append((xf.basis * n[i]).normalized() if i < n.size() else Vector3.UP)
			cols.append(c)
		if ix.is_empty():
			for i: int in v.size():
				idx.append(base + i)
		else:
			for i: int in ix:
				idx.append(base + i)

	func commit() -> ArrayMesh:
		var m := ArrayMesh.new()
		if verts.is_empty():
			return m
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_INDEX] = idx
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m
