class_name LevelKit
extends RefCounted
## A level's Houdini prop kit: assets/props/houdini/<kit>/kit.json plus its glbs. Reads the manifest (file, tris,
## bounds, collision per piece) and places pieces with their collision, every surface converted to the toon look the
## HoudiniProps way (glb base colour kept, materials shared through Toon's cache). Meshes that carry COLOR_0 (palm
## trunks, driveways, weathering) get the vertex-colour toon material automatically.
##
## Use (in a Level's _ready):
##   var kit: LevelKit = LevelKit.open("beach")
##   kit.place(self, "palm_tree_a", Vector3(12, 0, 30), deg_to_rad(40))      # StaticBody3D with its boxes
##   kit.place(self, "rocks", Vector3(-8, 0, 60))                             # "mesh" collision -> trimesh
##   var stand: Node3D = kit.place(self, "food_stand", p, yaw, {"tint": Color("ff6b5e"), "scale": 1.2})
##   var deco: Node3D = kit.visual("umbrella_towel_set")                      # mesh only, no body
## Kit manifest conventions: metres, +Y up, front facing -Z, origin at the base centre; collision boxes are
## axis-aligned in the piece's own space; "collision": "mesh" means use the mesh itself as a trimesh.

const ROOT: String = "res://assets/props/houdini/"
## Material names that take place()'s "tint" option (car paint, bin plastic, and the kits' "paint"/"accent" slots).
const TINT_MATERIALS: Array[String] = ["body", "plastic", "paint", "accent"]

static var _kits: Dictionary = {}

var kit_id: String = ""
var dir: String = ""
var pieces: Dictionary = {}  ## name -> manifest entry (Dictionary)
var _scenes: Dictionary = {}


## The kit in assets/props/houdini/<id>/ (cached; one LevelKit per id). Returns an empty kit when kit.json is missing.
static func open(id: String) -> LevelKit:
	if _kits.has(id):
		return _kits[id] as LevelKit
	var k := LevelKit.new()
	k.kit_id = id
	k.dir = ROOT + id + "/"
	var f: FileAccess = FileAccess.open(k.dir + "kit.json", FileAccess.READ)
	if f != null:
		var data: Variant = JSON.parse_string(f.get_as_text())
		if data is Dictionary:
			for p: Variant in (data as Dictionary).get("pieces", []):
				if p is Dictionary:
					k.pieces[str((p as Dictionary)["name"])] = p
	else:
		push_warning("LevelKit: no kit.json in " + k.dir)
	_kits[id] = k
	return k


## Every kit folder that has a kit.json.
static func kit_ids() -> PackedStringArray:
	var out := PackedStringArray()
	var d: DirAccess = DirAccess.open(ROOT)
	if d == null:
		return out
	for sub: String in d.get_directories():
		if FileAccess.file_exists(ROOT + sub + "/kit.json"):
			out.append(sub)
	return out


func has(piece: String) -> bool:
	return pieces.has(piece)


func names() -> PackedStringArray:
	return PackedStringArray(pieces.keys())


## The manifest entry of a piece ({} when unknown).
func info(piece: String) -> Dictionary:
	return pieces.get(piece, {}) as Dictionary


func tris(piece: String) -> int:
	return int(info(piece).get("tris", 0))


## The piece's bounds from the manifest (its own space, unscaled).
func bounds(piece: String) -> AABB:
	var b: Dictionary = info(piece).get("bounds", {}) as Dictionary
	if b.is_empty():
		return AABB()
	var lo: Vector3 = LevelKit._v3(b["min"])
	return AABB(lo, LevelKit._v3(b["max"]) - lo)


## Collision boxes as AABBs in the piece's space ([] for "mesh" collision or none).
func collision_boxes(piece: String) -> Array[AABB]:
	var out: Array[AABB] = []
	var c: Variant = info(piece).get("collision", [])
	if c is Array:
		for e: Variant in c:
			var d: Dictionary = e as Dictionary
			var size: Vector3 = LevelKit._v3(d["size"])
			out.append(AABB(LevelKit._v3(d["center"]) - size * 0.5, size))
	return out


func uses_mesh_collision(piece: String) -> bool:
	return str(info(piece).get("collision", "")) == "mesh"


func scene(piece: String) -> PackedScene:
	if not _scenes.has(piece):
		var file: String = str(info(piece).get("file", piece + ".glb"))
		_scenes[piece] = load(dir + file)
	return _scenes[piece] as PackedScene


## The piece's meshes only (toon materials, no collision), named after the piece. `tint` (alpha 0 = none) recolours
## the TINT_MATERIALS surfaces.
func visual(piece: String, tint: Color = Color(0, 0, 0, 0)) -> Node3D:
	var ps: PackedScene = scene(piece)
	if ps == null:
		push_warning("LevelKit: missing piece %s/%s" % [kit_id, piece])
		var empty := Node3D.new()
		empty.name = piece
		return empty
	var root: Node3D = ps.instantiate() as Node3D
	root.name = piece
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			var vc: bool = (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR) != 0
			mi.set_surface_override_material(s, LevelKit.toon_surface(mi.mesh.surface_get_material(s), vc, tint))
	return root


## Places a piece under `parent` at `pos` turned `yaw` radians about Y: a StaticBody3D (world layer 1) holding the
## visual and its collision (boxes from the manifest, or a trimesh of the meshes for "mesh"). Options:
##   "tint": Color   recolour tintable surfaces          "scale": float   uniform scale (collision follows)
##   "collide": bool false = visual only (a Node3D)      "shadow": bool   false = don't cast shadows (small clutter)
##   "name": String  node name (default the piece name)
## Returns the placed node.
func place(parent: Node, piece: String, pos: Vector3, yaw: float = 0.0, opts: Dictionary = {}) -> Node3D:
	var tint: Color = opts.get("tint", Color(0, 0, 0, 0)) as Color
	var sc: float = float(opts.get("scale", 1.0))
	var vis: Node3D = visual(piece, tint)
	if not bool(opts.get("shadow", true)):
		for n: Node in vis.find_children("*", "MeshInstance3D", true, false):
			(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var node: Node3D
	if bool(opts.get("collide", true)):
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		vis.name = "Mesh"
		sb.add_child(vis)
		add_collision(sb, piece, vis)
		node = sb
	else:
		node = vis
	node.name = str(opts.get("name", piece))
	node.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), pos)
	parent.add_child(node)
	return node


## Adds the piece's collision shapes to `body` (which holds `vis`, the piece's visual, for "mesh" collision).
func add_collision(body: CollisionObject3D, piece: String, vis: Node3D) -> void:
	if uses_mesh_collision(piece):
		for n: Node in vis.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			var cs := CollisionShape3D.new()
			cs.name = "Trimesh_" + mi.name
			cs.shape = mi.mesh.create_trimesh_shape()
			cs.transform = vis.transform * LevelKit._relative(vis, mi)
			body.add_child(cs)
		return
	var i: int = 0
	for bb: AABB in collision_boxes(piece):
		var cs := CollisionShape3D.new()
		cs.name = "Box%d" % i
		var shape := BoxShape3D.new()
		shape.size = bb.size
		cs.shape = shape
		cs.position = bb.get_center()
		body.add_child(cs)
		i += 1


## The toon material for one imported surface (base colour kept; vertex colour multiplied in when the mesh has it).
static func toon_surface(src: Material, vertex_colour: bool, tint: Color = Color(0, 0, 0, 0)) -> Material:
	var col: Color = Color.WHITE
	var mat_name: String = ""
	if src is StandardMaterial3D:
		col = (src as StandardMaterial3D).albedo_color
		mat_name = src.resource_name
	if tint.a > 0.0 and TINT_MATERIALS.has(mat_name):
		col = tint
	return Toon.material_vc(col) if vertex_colour else Toon.material(col, false)


static func _relative(root: Node3D, n: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


static func _v3(a: Variant) -> Vector3:
	var arr: Array = a as Array
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
