class_name ParkSurface
extends RefCounted
## Toon materials for park ramps, banks and ledges with procedural detail (game/park/ramp_surface.gdshader): panel seams,
## screws, grain, scuffs, lip wear and foot-of-slope contact shade. Same three-band light as Toon.material, same colours.
## PieceKit.body uses it for every body except metal. Cached per colour. Ink outlines are not part of it (off by default).

const SHADER: Shader = preload("res://game/park/ramp_surface.gdshader")
## Colours below this saturation are concrete, the rest painted plywood.
const CONCRETE_SAT: float = 0.2

static var _cache: Dictionary = {}


static func material(color: Color, vertex_colors: bool = false) -> ShaderMaterial:
	if OS.get_environment("SKATE_NOSURF") != "":
		return Toon.material_vc(color) if vertex_colors else Toon.material(color)
	var key: String = "%s|%s" % [color.to_html(true), str(vertex_colors)]
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("kind", 1 if color.s < CONCRETE_SAT else 0)
	if vertex_colors:
		mat.set_shader_parameter("vertex_color_amount", 1.0)
	_cache[key] = mat
	return mat
