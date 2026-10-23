class_name WorldSurface
extends RefCounted
## World-space ground materials for the levels (game/world/surface.gdshader): concrete, asphalt, sand, grass, pavers,
## boardwalk planks and court floor, all toon lit, no textures or UVs. Materials are cached per (kind, colour, scale), so
## every slab of one surface shares a material (one shader, fewer state changes).
##
## Use: mesh_instance.material_override = WorldSurface.material("asphalt"), or Level.add_ground(...) and then
## WorldSurface.apply(ground_body, "sand").

const SHADER: Shader = preload("res://game/world/surface.gdshader")
const KINDS: Dictionary = {"concrete": 0, "asphalt": 1, "sand": 2, "grass": 3, "pavers": 4, "planks": 5, "court": 6}
## Default colour per kind.
const COLORS: Dictionary = {
	"concrete": Color("8a96a6"), "asphalt": Color("4a4e5a"), "sand": Color("d6bd94"), "grass": Color("79a352"),
	"pavers": Color("b07a62"), "planks": Color("b98b5e"), "court": Color("c98d55"),
}

static var _cache: Dictionary = {}


## A shared material for `kind` (a KINDS key). colour alpha 0 = the kind's default colour.
static func material(kind: String, colour: Color = Color(0, 0, 0, 0), pattern_scale: float = 1.0) -> ShaderMaterial:
	var c: Color = colour if colour.a > 0.0 else COLORS.get(kind, COLORS["concrete"]) as Color
	var key: String = "%s|%s|%.3f" % [kind, c.to_html(), pattern_scale]
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("kind", int(KINDS.get(kind, 0)))
	m.set_shader_parameter("scale", pattern_scale)
	_cache[key] = m
	return m


## A fresh (not cached) sand material that darkens toward the water: wet past the plane through `origin` (world)
## facing `toward_sea` (world direction out to sea). Ocean.add_beach() sets this up for you.
static func wet_sand_along(origin: Vector3, toward_sea: Vector3, colour: Color = Color(0, 0, 0, 0)) -> ShaderMaterial:
	var m: ShaderMaterial = material("sand", colour).duplicate() as ShaderMaterial
	m.set_shader_parameter("wet_origin", origin)
	m.set_shader_parameter("wet_dir", toward_sea.normalized())
	return m


## Puts the material on every MeshInstance3D under `root` (root included).
static func apply(root: Node, kind: String, colour: Color = Color(0, 0, 0, 0), pattern_scale: float = 1.0) -> void:
	var m: ShaderMaterial = material(kind, colour, pattern_scale)
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_override = m
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = m
