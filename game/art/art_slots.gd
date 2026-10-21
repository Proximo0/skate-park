class_name ArtSlots
extends RefCounted
## Art slots. Each slot is a glTF binary at res://art/<slot>.glb (see docs/art_spec.md). When a file is
## missing, callers get their placeholder, built in code, so the game runs with no art at all. Dropping a
## correctly named .glb in art/ replaces the placeholder with no code change.

const SLOTS: PackedStringArray = [
	"skater_body",
	"skater_board",
	"park_quarterpipe",
	"park_halfpipe",
	"park_bowl",
	"park_funbox",
	"park_rail_flat",
	"park_rail_down",
	"park_ledge",
	"park_stairs",
	"park_kicker",
	"park_wall",
	"park_bench",
	"park_props",
]

const ART_DIR: String = "res://art/"


static func path_for(slot: String) -> String:
	return ART_DIR + slot + ".glb"


static func has_art(slot: String) -> bool:
	return ResourceLoader.exists(path_for(slot))


## Returns an instance of the slot's .glb when it exists and loads, otherwise placeholder.call().
static func instance(slot: String, placeholder: Callable) -> Node3D:
	if has_art(slot):
		var scene: PackedScene = load(path_for(slot)) as PackedScene
		if scene != null:
			var root: Node = scene.instantiate()
			if root is Node3D:
				return root as Node3D
			if root != null:
				root.free()
	return placeholder.call() as Node3D
