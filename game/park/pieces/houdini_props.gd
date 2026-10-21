class_name HoudiniProps
extends RefCounted
## Loader for the Houdini-made prop glbs in assets/props/houdini/ (cars, trash bin, litter kit, graffiti wall). Every surface is
## converted to the game's toon look (Toon.material, keeping the glb material's base colour); the car body and the bin's plastic
## take a per-instance tint. Materials come out of Toon's colour cache, so instances with the same colour share one material.
##
## Conventions of the glbs: Y up, metres, origin at the ground centre, front facing -Z. Wheels are separate meshes.

const DIR: String = "res://assets/props/houdini/"
## Glbs whose COLOR_0 carries weathering or prints: the toon material multiplies it into the albedo.
const VERTEX_COLOUR_GLBS: Array[String] = ["litter_kit", "graffiti_wall"]
## Material names that take the per-instance tint (the paint of a car, the plastic of a bin).
const TINT_MATERIALS: Array[String] = ["body", "plastic"]
## Skate and surf paint colours for car bodies and bin plastic.
const PALETTE: Array[String] = [
	"ff6b5e", "ffd23f", "4fd1c5", "ff8ec7", "7ec8e3", "a8e6cf", "ffb199", "b58cff", "ff8a3d", "3a7bd5", "f4f0e6", "5fcf80",
]

static var _scenes: Dictionary = {}


static func scene(glb: String) -> PackedScene:
	if not _scenes.has(glb):
		_scenes[glb] = load(DIR + glb + ".glb")
	return _scenes[glb] as PackedScene


static func palette_colour(index: int) -> Color:
	return Color(PALETTE[posmod(index, PALETTE.size())])


## A fresh instance of `glb` (no extension) with every surface converted to toon. `tint` (alpha 0 means none) replaces the
## base colour of the tint materials.
static func instance(glb: String, tint: Color = Color(0, 0, 0, 0)) -> Node3D:
	var root: Node3D = scene(glb).instantiate() as Node3D
	var vc: bool = VERTEX_COLOUR_GLBS.has(glb)
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, toon_surface(mi.mesh.surface_get_material(s), vc, tint))
	return root


## The toon material for one imported surface material.
static func toon_surface(src: Material, vertex_colour: bool, tint: Color = Color(0, 0, 0, 0)) -> Material:
	var col: Color = Color.WHITE
	var mat_name: String = ""
	if src is StandardMaterial3D:
		col = (src as StandardMaterial3D).albedo_color
		mat_name = src.resource_name
	if tint.a > 0.0 and TINT_MATERIALS.has(mat_name):
		col = tint
	return Toon.material_vc(col) if vertex_colour else Toon.material(col, false)


## Local AABB of every mesh under `root`, merged, in root space (children's transforms applied).
static func aabb_of(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var bb: AABB = _local_aabb(root, mi)
		out = bb if first else out.merge(bb)
		first = false
	return out


static func _local_aabb(root: Node3D, mi: MeshInstance3D) -> AABB:
	var xf: Transform3D = Transform3D.IDENTITY
	var n: Node = mi
	while n != null and n != root:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf * mi.mesh.get_aabb()


## The mesh of one named MeshInstance3D in a glb (for MultiMeshes).
static func named_mesh(glb: String, node_name: String) -> Mesh:
	var root: Node3D = scene(glb).instantiate() as Node3D
	var mi: MeshInstance3D = root.get_node(node_name) as MeshInstance3D
	var m: Mesh = mi.mesh
	root.free()
	return m
