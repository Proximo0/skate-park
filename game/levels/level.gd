class_name Level
extends Node3D
## Base class of every playable level (the practice Park and the five themed levels under game/levels/<id>/).
## main.gd, the goals, the HUD, the bot, the collectibles, the drop-ins and the pause menu read only what is declared
## here, so a level is free to build itself however it likes in _ready(). See docs/levels.md for the full guide.
##
## The contract, filled in by the level's _ready() (main.gd adds the level to the tree before it reads any of it):
##   spawn          Transform3D where the skater starts and respawns (on a floor, facing -Z of the basis).
##   bounds         Rect2 in world x/z: the riding area. add_boundary() walls it in (Level.walls_around).
##   kill_y         below this height the skater respawns (main.gd copies it onto the skater's own tuning).
##   collectibles   every Collectible (add_collectible()); goals of type "collect" count their `item`s.
##   drop_ins       spot id -> Transform3D on a start deck (add_drop_in()); drop_in_names: spot id -> pause-menu label.
##   gaps_path      gaps JSON for this level (zones are PieceKit.gap_zone Areas with matching ids).
##   goals_path     goals JSON for this level.
##   placed         every rideable piece added with put(), for layout checks and the ground apron.
##   world_environment / sun   set by setup_environment(mood_id) (Mood presets, game/world/mood.gd).
##   bot_route_path JSON route the play-bot skates on this level (LevelRoute, game/levels/level_route.gd).
## The level node sits at the world origin, so level space is world space.
##
## Ramp snap lips come from pieces that add themselves to the "ramp_lip" group (game/park/ramp_lip.gd); gap zones from
## PieceKit.gap_zone (group "gap_zone"). Both are found through the tree, so a level just has to add the pieces.

signal skater_bound(skater: Node3D)

const DEFAULT_KILL_Y: float = -20.0
const DEFAULT_GAPS: String = "res://data/gaps.json"
const DEFAULT_GOALS: String = "res://data/goals.json"
## Invisible boundary walls: thick and tall enough that no jump clears them.
const WALL_THICK: float = 2.0
const WALL_HEIGHT: float = 40.0
const WALL_BASE_Y: float = -2.0

var level_id: String = ""
var display_name: String = ""
var mood_id: String = ""
var spawn: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.1, 0.0))
var bounds: Rect2 = Rect2(-40.0, -40.0, 80.0, 80.0)
var kill_y: float = DEFAULT_KILL_Y
var collectibles: Array[Collectible] = []
## Every piece added with put() (not the ground, fences, decor, zones or collectibles), for layout checks.
var placed: Array[Node3D] = []
var drop_ins: Dictionary = {}
var drop_in_names: Dictionary = {}
var gaps_path: String = DEFAULT_GAPS
var goals_path: String = DEFAULT_GOALS
var bot_route_path: String = ""
## Camera for the level-select preview (tools/level_previews.sh): [from: Vector3, look_at: Vector3]. Empty = a raised
## view from behind the spawn.
var preview_view: Array = []
var world_environment: WorldEnvironment = null
var sun: DirectionalLight3D = null
## The resolved Mood preset (Mood.preset(mood_id)) once setup_environment() ran; {} before.
var mood: Dictionary = {}
## The skater riding this level, once main.gd (or a harness) calls bind_skater(); null before.
var skater: Node3D = null


## True for a night mood: cars switch their headlights on, lamps glow.
func is_night() -> bool:
	return bool(mood.get("night", false))


## Called by main.gd once the skater exists. World nodes (Traffic, Pedestrians) also find it in the "skater" group.
func bind_skater(s: Node3D) -> void:
	skater = s
	skater_bound.emit(s)


## Adds a rideable piece at `pos` turned `yaw_deg` about Y (PieceKit convention: 0 faces +Z, 180 faces -Z, 90 faces +X)
## and records it in `placed`.
func put(node: Node3D, pos: Vector3, yaw_deg: float = 0.0, node_name: String = "") -> Node3D:
	node.position = pos
	node.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	if node_name != "":
		node.name = node_name
	add_child(node)
	placed.append(node)
	return node


## Builds the sky, sun, fog, ambient light and tonemap of a Mood preset (game/world/mood.gd) and keeps the nodes in
## world_environment and sun. Call it first in _ready().
func setup_environment(preset_id: String = "") -> void:
	if preset_id != "":
		mood_id = preset_id
	var built: Dictionary = Mood.build(mood_id if mood_id != "" else Mood.DEFAULT_ID)
	mood = built["preset"]
	world_environment = built["environment"]
	sun = built["sun"]
	add_child(world_environment)
	add_child(sun)


## A flat skateable slab whose top is at `top_y`, covering `rect` (world x/z). Collision on the world layer, no shadow
## casting (the ground only receives).
func add_ground(rect: Rect2, top_y: float = 0.0, color: Color = Color("7a8ca0"), node_name: String = "Ground") -> StaticBody3D:
	var sb: StaticBody3D = PieceKit.box(Vector3(rect.position.x, top_y - 1.0, rect.position.y), Vector3(rect.size.x, 1.0, rect.size.y), color, node_name)
	var mi: MeshInstance3D = sb.get_node_or_null("Mesh") as MeshInstance3D
	if mi != null:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sb)
	return sb


## A huge visual-only ground plane (no collision) just under the slabs, so the world does not end in the sky's lower
## half past the level's edges. `kind` is a WorldSurface kind. Returns the MeshInstance3D "Backdrop".
func add_backdrop(kind: String = "concrete", color: Color = Color(0, 0, 0, 0), size: float = 3000.0, y: float = -0.06) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Backdrop"
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	mi.position = Vector3(bounds.get_center().x, y, bounds.get_center().y)
	mi.material_override = WorldSurface.material(kind, color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Walls `rect` (default: bounds) in with four invisible collision walls. Returns the "Boundary" node.
func add_boundary(rect: Rect2 = Rect2()) -> Node3D:
	var r: Rect2 = rect if rect.has_area() else bounds
	var walls: Node3D = Level.walls_around(r)
	add_child(walls)
	return walls


## A collectible (a goal pickup) at `pos`. `group_id` groups items for the HUD ("skate" letters, "pizza", ...).
func add_collectible(item: String, group_id: String, pos: Vector3) -> Collectible:
	var c := Collectible.new()
	c.item = item
	c.group_id = group_id
	c.position = pos
	c.name = "%s_%s_%d" % [group_id, item, collectibles.size()]
	add_child(c)
	collectibles.append(c)
	return c


## Registers a pause-menu drop-in: `xf` is where the skater is put (on a start deck, facing the roll-in).
func add_drop_in(spot_id: String, label: String, xf: Transform3D) -> void:
	drop_ins[spot_id] = xf
	drop_in_names[spot_id] = label


## The bot route of this level: {"lines": [...]} parsed by LevelRoute, or {} when the level has none.
func load_bot_route() -> Dictionary:
	return LevelRoute.load_file(bot_route_path)


## Four invisible, collision-only walls whose inner faces sit on the edges of `rect` (world x/z). North and south span
## the full width plus the thickness, east and west the full depth plus the thickness, so the corners overlap and leave
## no gap. Static bodies on the world layer (1).
static func walls_around(rect: Rect2, height: float = WALL_HEIGHT, base_y: float = WALL_BASE_Y, thick: float = WALL_THICK) -> Node3D:
	var root := Node3D.new()
	root.name = "Boundary"
	var y: float = base_y + height * 0.5
	var cx: float = rect.get_center().x
	var cz: float = rect.get_center().y
	var span := Vector3(rect.size.x + thick * 2.0, height, thick)
	var side := Vector3(thick, height, rect.size.y + thick * 2.0)
	root.add_child(_level_wall("BoundaryN", Vector3(cx, y, rect.position.y - thick * 0.5), span))
	root.add_child(_level_wall("BoundaryS", Vector3(cx, y, rect.end.y + thick * 0.5), span))
	root.add_child(_level_wall("BoundaryW", Vector3(rect.position.x - thick * 0.5, y, cz), side))
	root.add_child(_level_wall("BoundaryE", Vector3(rect.end.x + thick * 0.5, y, cz), side))
	return root


static func _level_wall(node_name: String, centre: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.position = centre
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	return body


## The Level that `node` belongs to (itself or the nearest Level ancestor), or null.
static func of(node: Node) -> Level:
	var n: Node = node
	while n != null:
		if n is Level:
			return n as Level
		n = n.get_parent()
	return null
