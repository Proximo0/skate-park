class_name Ocean
extends Node3D
## A stylised sea for a level: Gerstner waves rolling onto a sloping beach, foam on the breaking crests and the swash
## line, a depth tint over the sand, sun glints, and a far horizon that fades into the sky (game/world/ocean.gdshader).
## Runs in the Compatibility renderer (no depth texture: the water depth comes from the beach profile).
##
## Space: this node's local space. The still-water line runs along local X at z = 0, the sea lies toward local +Z,
## y = 0 is sea level. Position and turn the node to put the shore where you want it (e.g. position.y = -1.2 for a sea
## 1.2 m under a slab at y = 0). The sea floor is min(berm, -beach_slope * z): build the sand with
## Ocean.beach_mesh() (or add_beach()) so the foam line sits exactly where water meets sand.
##
## Colours, sun and sky come from the level's Mood (water_deep / water_shallow, sky bands, sun) when the ocean sits
## under a Level; set them yourself otherwise (apply_mood()). A skater that sinks deeper than respawn_depth under the
## surface respawns (group "skater").
##
## Cost: one draw call, about 60k vertices (dense 1 m grid near the shore, geometric growth to the horizon).

const SHADER: Shader = preload("res://game/world/ocean.gdshader")
## Wave set: [dir.x, dir.z, wavelength m, amplitude m] for the six shader waves (w0..w2 the swell, w3..w5 chop).
const WAVES: Array[Vector4] = [
	Vector4(0.06, -1.0, 21.0, 0.36), Vector4(-0.22, -0.97, 13.0, 0.2), Vector4(0.3, -0.95, 8.5, 0.12),
	Vector4(-0.6, -0.8, 5.2, 0.06), Vector4(0.8, -0.6, 3.3, 0.035), Vector4(-0.9, 0.4, 2.3, 0.022),
]
const STEEP: Array[float] = [0.55, 0.5, 0.45, 0.4, 0.35, 0.3]

const FILM: float = 0.16  ## water kept over the sand in the troughs (m)

@export var beach_slope: float = 0.08
@export var berm: float = 1.2  ## height of the dry beach top above sea level (where the sand profile flattens)
@export var wave_scale: float = 1.0
@export var half_width: float = 1600.0  ## along the shore, each way
@export var reach: float = 3000.0  ## out to sea
@export var inland: float = 40.0  ## how far the water sheet runs under the sand (for the swash)
@export var dense_half_width: float = 110.0  ## the 1 m grid part
@export var dense_reach: float = 140.0
@export var respawn_depth: float = 0.9

var material: ShaderMaterial
var time: float = 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("slope", beach_slope)
	material.set_shader_parameter("berm", berm)
	material.set_shader_parameter("wave_scale", wave_scale)
	var names: Array[String] = ["w0", "w1", "w2", "w3", "w4", "w5"]
	for i: int in WAVES.size():
		material.set_shader_parameter(names[i], WAVES[i])
	material.set_shader_parameter("steep_a", Vector3(STEEP[0], STEEP[1], STEEP[2]))
	material.set_shader_parameter("steep_b", Vector3(STEEP[3], STEEP[4], STEEP[5]))
	_mesh = MeshInstance3D.new()
	_mesh.name = "Water"
	_mesh.mesh = water_mesh(half_width, reach, inland, dense_half_width, dense_reach)
	_mesh.material_override = material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.extra_cull_margin = 4.0
	add_child(_mesh)
	var lvl: Level = Level.of(self)
	apply_mood(lvl.mood if lvl != null and not lvl.mood.is_empty() else Mood.preset("beach_sunny"))


## Colours, sun and sky from a resolved Mood preset (Mood.preset(id)).
func apply_mood(p: Dictionary) -> void:
	var deep: Color = p.get("water_deep", Color("1f6f9a")) as Color
	var shallow: Color = p.get("water_shallow", Color("37c8c0")) as Color
	material.set_shader_parameter("deep_color", deep)
	material.set_shader_parameter("shallow_color", shallow)
	material.set_shader_parameter("crest_color", shallow.lightened(0.35))
	material.set_shader_parameter("sky_color", p.get("upper", Color(0.3, 0.66, 1.0)) as Color)
	var hz: Color = (p.get("aqua", Color(0.6, 0.85, 0.95)) as Color).lerp(p.get("yellow", Color.WHITE) as Color, 0.25)
	material.set_shader_parameter("horizon_color", hz)
	material.set_shader_parameter("sun_dir", Mood.sun_direction(p))
	var sc: Color = p.get("sun_color", Color.WHITE) as Color
	material.set_shader_parameter("sun_color", sc * clampf(float(p.get("sun_energy", 1.0)), 0.2, 1.2))
	var night: bool = bool(p.get("night", false))
	material.set_shader_parameter("light_level", 0.32 if night else 1.0)
	material.set_shader_parameter("foam_color", Color(0.55, 0.6, 0.72) if night else Color(0.97, 0.99, 1.0))


func _process(delta: float) -> void:
	time += delta
	material.set_shader_parameter("t", time)


func _physics_process(_delta: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var sk: Node3D = tree.get_first_node_in_group("skater") as Node3D
	if sk == null or not sk.has_method("respawn"):
		return
	var lp: Vector3 = global_transform.affine_inverse() * sk.global_position
	if lp.z > 0.0 and absf(lp.x) < half_width and lp.y < -respawn_depth and lp.y > -60.0:
		sk.call("respawn")


## Still-water depth at local z (positive over the sea).
func depth_at(local_z: float) -> float:
	return -sand_height(local_z, beach_slope, berm)


## Sea floor height at local z for a beach profile.
static func sand_height(local_z: float, slope: float, berm_h: float) -> float:
	return minf(berm_h, -slope * local_z)


## Surface height (local y) of the swell at local (x, z) at time `at`, ignoring the horizontal Gerstner shift: good for
## floating props and tests. Matches the shader's wave set and shoaling.
func height_at(local_x: float, local_z: float, at: float) -> float:
	var d: float = depth_at(local_z)
	var y: float = 0.0
	for i: int in WAVES.size():
		var w: Vector4 = WAVES[i]
		var dir := Vector2(w.x, w.y).normalized()
		var k: float = TAU / w.z
		var c: float = sqrt(9.8 / k)
		var swell: float = 1.0 if i < 3 else 0.0
		var amp: float = w.w * wave_scale * Ocean.shoal(d, swell)
		y += amp * sin(k * (dir.dot(Vector2(local_x, local_z)) - c * at))
	return maxf(y, Ocean.trough_floor(d))


## Lowest the water may sit at still depth d: troughs keep a thin film over the sand except right at the shoreline, so
## the backwash does not bare sandbars all over the shallows (matches the shader).
static func trough_floor(d: float) -> float:
	return -d + FILM * smoothstep(0.2, 0.9, d) - 100.0 * (1.0 - smoothstep(0.0, 0.2, d))


## The shader's shoaling factor (see ocean.gdshader shoal()).
static func shoal(d: float, is_swell: float) -> float:
	var up: float = 1.0 + 0.3 * (1.0 - smoothstep(0.8, 5.0, d)) * is_swell
	var die: float = smoothstep(-0.6 * is_swell, 1.4 - 0.6 * is_swell, d)
	return up * lerpf(die, maxf(die, 0.55), is_swell)


## Coordinates along one axis: 1 m steps over [-dense, dense] (or [lo_dense, dense]), then steps growing by 12 % out to
## the far end.
static func _axis(lo: float, hi: float, dense_lo: float, dense_hi: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var x: float = dense_lo
	var stepv: float = 1.0
	var below := PackedFloat32Array()
	while x > lo:
		stepv *= 1.12
		x -= stepv
		below.append(maxf(x, lo))
	below.reverse()
	out.append_array(below)
	x = dense_lo
	while x < dense_hi:
		out.append(x)
		x += 1.0
	stepv = 1.0
	x = dense_hi
	while x < hi:
		out.append(x)
		stepv *= 1.12
		x += stepv
	out.append(hi)
	return out


## The water sheet: a grid in local space, x in [-half_w, half_w], z in [-inland_m, reach_m], dense near the shore.
static func water_mesh(half_w: float, reach_m: float, inland_m: float, dense_w: float, dense_z: float) -> ArrayMesh:
	var xs: PackedFloat32Array = _axis(-half_w, half_w, -dense_w, dense_w)
	var zs: PackedFloat32Array = _axis(-inland_m, reach_m, -inland_m, dense_z)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(xs.size() * zs.size())
	norms.resize(verts.size())
	var i: int = 0
	for z: float in zs:
		for x: float in xs:
			verts[i] = Vector3(x, 0.0, z)
			norms[i] = Vector3.UP
			i += 1
	var idx := PackedInt32Array()
	var nx: int = xs.size()
	for r: int in zs.size() - 1:
		for c: int in nx - 1:
			var a: int = r * nx + c
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# the vertex shader lifts the sheet by up to a couple of metres
	m.custom_aabb = AABB(Vector3(-half_w, -3.0, -inland_m), Vector3(half_w * 2.0, 6.0, reach_m + inland_m))
	return m


## The sand under and behind the water, matching the shader's sea floor: a strip `width` wide (centred on local x = 0)
## from `inland_m` behind the waterline (where it sits at the berm height) out to `seaward` metres. In Ocean local space,
## so add it as a child of the Ocean, or give it the Ocean's transform.
static func beach_mesh(width: float, inland_m: float, seaward: float, slope: float = 0.08, berm_h: float = 1.2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zs := PackedFloat32Array()
	var z: float = -inland_m
	# the dry beach is flat (at the berm): one strip up to where the slope starts, then 2 m rows down the slope
	var flat_end: float = -berm_h / maxf(slope, 0.001) - 2.0
	if z < flat_end:
		zs.append(z)
		z = flat_end
	while z < seaward:
		zs.append(z)
		z += 2.0
	zs.append(seaward)
	var hw: float = width * 0.5
	for i: int in zs.size() - 1:
		var z0: float = zs[i]
		var z1: float = zs[i + 1]
		var y0: float = sand_height(z0, slope, berm_h)
		var y1: float = sand_height(z1, slope, berm_h)
		var a := Vector3(-hw, y0, z0)
		var b := Vector3(hw, y0, z0)
		var c := Vector3(hw, y1, z1)
		var d := Vector3(-hw, y1, z1)
		var n: Vector3 = (d - a).cross(b - a).normalized()
		st.set_normal(n)
		for p: Vector3 in [a, b, c, a, c, d]:
			st.add_vertex(p)
	return st.commit()


## Adds the matching sand (with trimesh collision, so it can be ridden) as a child: a "Beach" StaticBody3D.
## The sand darkens where it is wet (WorldSurface.wet_sand, set up along this node's shore line).
func add_beach(width: float, inland_m: float, seaward: float = 60.0, colour: Color = Color(0, 0, 0, 0)) -> StaticBody3D:
	var mesh: ArrayMesh = Ocean.beach_mesh(width, inland_m, seaward, beach_slope, berm)
	var body := StaticBody3D.new()
	body.name = "Beach"
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)
	var wet: ShaderMaterial = WorldSurface.wet_sand_along(global_transform * Vector3(0.0, 0.0, -2.5),
			global_transform.basis * Vector3(0.0, 0.0, 1.0), colour)
	mi.material_override = wet
	return body
