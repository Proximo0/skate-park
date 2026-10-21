class_name Toon
extends RefCounted
## Cartoon look: toon-shaded materials with an ink outline (inverted hull), applied to meshes, and a bright
## sky environment. Pure helpers, called at setup time, never per frame. Shaders: toon.gdshader and
## toon_outline.gdshader next to this file.

const TOON_SHADER: Shader = preload("res://game/art/toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://game/art/toon_outline.gdshader")
## Ink from the art palette (#1B1B2F), used for outlines.
const INK: Color = Color(0.106, 0.106, 0.184, 1.0)

static var _outline_material: ShaderMaterial = null
static var _cache: Dictionary = {}
## Ink outlines are off by default (the playtest found they made the scene look busier, not better).
## set_outlines() switches every toon material that asked for one; F5 does this in game.
static var outlines_enabled: bool = false


## Toon material for a flat colour. With outline (and outlines_enabled), the ink outline pass is its next_pass.
## Cached per colour: the same colour and outline flag return the same instance.
static func material(color: Color, outline: bool = true) -> ShaderMaterial:
	var key: String = "%s|%s" % [color.to_html(true), str(outline)]
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("albedo", color)
	if outline and outlines_enabled:
		mat.next_pass = _shared_outline()
	_cache[key] = mat
	return mat


## Toon material whose albedo is multiplied by the mesh's vertex colour (and a MultiMesh instance colour): weathered walls,
## printed cans. Cached per colour, no outline.
static func material_vc(color: Color) -> ShaderMaterial:
	var key: String = "%s|vc" % color.to_html(true)
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("vertex_color_amount", 1.0)
	_cache[key] = mat
	return mat


## Turns the ink outline on or off for every toon material made with outline = true, now and from here on.
static func set_outlines(on: bool) -> void:
	outlines_enabled = on
	for key: String in _cache:
		if key.ends_with("|true"):
			(_cache[key] as ShaderMaterial).next_pass = _shared_outline() if on else null


## Replaces the material of every MeshInstance3D under root (root included) with a toon material that keeps
## the mesh's albedo colour (white when it has no StandardMaterial3D). Meshes that already carry a ShaderMaterial
## override are left alone, so a second call returns 0. Returns the number of meshes changed.
static func apply_to(root: Node, outline: bool = true) -> int:
	if root == null:
		return 0
	var changed: int = 0
	if root is MeshInstance3D and _apply_one(root as MeshInstance3D, outline):
		changed += 1
	for child: Node in root.get_children():
		changed += apply_to(child, outline)
	return changed


## Bright cartoon sky: saturated blue overhead, pale horizon, neutral ambient light, linear tonemap so
## colours stay bright.
static func sky_environment() -> Environment:
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.56, 1.0, 1.0)
	sky_mat.sky_horizon_color = Color(0.82, 0.93, 1.0, 1.0)
	sky_mat.sky_curve = 0.2
	sky_mat.ground_horizon_color = Color(0.82, 0.93, 1.0, 1.0)
	sky_mat.ground_bottom_color = Color(0.45, 0.66, 0.42, 1.0)
	sky_mat.ground_curve = 0.1
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Neutral ambient, not sky-sourced: sky ambient tinted every colour blue-cyan.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.92, 0.96, 1.0)
	env.ambient_light_energy = 0.2
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	return env


static func _shared_outline() -> ShaderMaterial:
	if _outline_material == null:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = OUTLINE_SHADER
		_outline_material.set_shader_parameter("outline_color", INK)
	return _outline_material


static func _apply_one(mi: MeshInstance3D, outline: bool) -> bool:
	if mi.material_override is ShaderMaterial:
		return false
	var src: Material = mi.material_override
	if src == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
		src = mi.get_active_material(0)
	var color: Color = Color.WHITE
	if src is StandardMaterial3D:
		color = (src as StandardMaterial3D).albedo_color
	mi.material_override = material(color, outline)
	return true
