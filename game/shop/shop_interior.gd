class_name ShopInterior
extends RefCounted
## Builds the walk-in skate shop "SUNSET SKATE CO." in code: a cosy 14 x 10 m room (x -7..7, z -5..5, floor y = 0,
## the front door and windows on +Z). Areas, west to east:
##   Boards  (north-west): a wall of decks, a glass case of trucks and wheels, a workbench with a board in a vice.
##   Clothes (west): tee and hoodie racks, a shoe wall, a surf corner (surfboards and wetsuits) by the window.
##   Dressing (back wall): a changing booth with a half-drawn curtain and a mirror.
##   Counter (back wall): register, sticker spinner, stocked shelves, the neon shop sign; the shopkeeper's spot.
##   Ramp (north-east): a mini quarter pipe.  Style (east): a stylist chair facing a bulb-lit mirror.
##   Lounge (south-east): a worn couch, beanbag, coffee table with mags, a TV looping a skate clip, a mini fridge.
## build() fills `stations`, `npc_spots`, `seats`, `spawn`, `sit_camera` and `vice` for ShopRoom.

const W: float = 7.0  ## half width (x)
const D: float = 5.0  ## half depth (z)
const H: float = 3.4  ## ceiling height
const WALL_T: float = 0.2
const DOOR_HALF: float = 0.8
const DOOR_H: float = 2.4
const WINDOWS: Array[Vector2] = [Vector2(-4.4, -2.0), Vector2(1.3, 3.7)]  ## x ranges in the front wall
const WINDOW_Y: Vector2 = Vector2(0.9, 2.45)
const COUNTER_TOP: float = 1.0
const SEAT_X: float = 6.36  ## where a seated hip sits on the couch (x): knees just past the cushion's front edge
const SEAT_ZS: Array[float] = [1.15, 2.3]

const WALL_PAINT := Color("#4C9BA3")  ## muted teal: deep enough that lamps never wash it to peach
const WALL_ACCENT := Color("#7A4A9C")
const WALL_PINK := Color("#F59AA6")
const WOOD := Color("#C9874F")
const WOOD_DARK := Color("#8A5634")
const WOOD_LIGHT := Color("#B87A50")
const CEILING := Color("#6A4E7C")
const CEILING_PLANK := Color("#5A4070")
const INK := Color("#1B1B2F")
const CREAM := Color("#FFF6E6")
const METAL := Color("#A3AEC2")
const NEON_PINK := Color("#FF5FA2")
const NEON_ORANGE := Color("#FFB04D")
const NEON_TEAL := Color("#52F0E6")
const LEAF := Color("#3FAE6A")
const LEAF_LIGHT := Color("#69C98A")
const POT := Color("#E07A5F")
const DECK_COLORS: Array[Color] = [
	Color("#FF5A5F"), Color("#FFD84D"), Color("#4FC3F7"), Color("#7C83FD"), Color("#FF9F1C"), Color("#FF7EB6"),
	Color("#2EC4B6"), Color("#F4F1DE"), Color("#B79CFF"), Color("#E0455A"), Color("#1B1B2F"), Color("#A6E22E"),
]

var root: Node3D
var stations: Array[ShopStation] = []
var npc_spots: Dictionary = {}  ## role -> Transform3D (floor point, -Z of the basis = facing)
var seats: Array[Transform3D] = []  ## couch seats: floor point under the hips, facing out of the couch
var spawn: Transform3D = Transform3D.IDENTITY
var sit_camera: Transform3D = Transform3D.IDENTITY
var vice: Node3D  ## holder for the board clamped in the workbench vice (ShopRoom puts the player's board here)
var tv_screen: MeshInstance3D
var _shoe_cache: Dictionary = {}
var _garment_cache: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func build(parent: Node3D) -> ShopInterior:
	var si: ShopInterior = ShopInterior.new()
	si._rng.seed = 2207
	si.root = Node3D.new()
	si.root.name = "Interior"
	parent.add_child(si.root)
	si._build_environment()
	si._build_shell()
	si._build_outside()
	si._build_boards()
	si._build_clothes()
	si._build_surf_corner()
	si._build_dressing()
	si._build_counter()
	si._build_ramp()
	si._build_style()
	si._build_lounge()
	si._build_decor()
	si._build_lights()
	si._define_stations()
	for b: Variant in si._board_cache.values():
		(b as Node).free()  # the duplicates share the meshes; the master copies were never in the tree
	si._board_cache.clear()
	return si


# --- small mesh helpers --------------------------------------------------------------------------------------

func _group(group_name: String) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = group_name
	root.add_child(n)
	return n


func _place(parent: Node3D, mesh: Mesh, center: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO,
		scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = center
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, center: Vector3, size: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	return _place(parent, m, center, _toon(color), rot_deg)


func _box_mesh(size: Vector3) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	return m


func _cyl(parent: Node3D, center: Vector3, r_top: float, r_bottom: float, h: float, color: Color,
		rot_deg: Vector3 = Vector3.ZERO, segments: int = 18) -> MeshInstance3D:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = segments
	m.rings = 1
	return _place(parent, m, center, _toon(color), rot_deg)


func _ball(parent: Node3D, center: Vector3, r: float, color: Color, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m: SphereMesh = SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	return _place(parent, m, center, _toon(color), Vector3.ZERO, scl)


func _capsule(parent: Node3D, center: Vector3, r: float, h: float, color: Color, rot_deg: Vector3 = Vector3.ZERO,
		scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m: CapsuleMesh = CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 16
	m.rings = 6
	return _place(parent, m, center, _toon(color), rot_deg, scl)


## An invisible static box collider on the world layer (1), so the walker and the camera bump into furniture.
func _solid(center: Vector3, size: Vector3, rot_y_deg: float = 0.0) -> StaticBody3D:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.name = "Solid"
	sb.position = center
	sb.rotation_degrees.y = rot_y_deg
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)
	root.add_child(sb)
	return sb


## Unshaded bright material for neon tubes, bulbs and screens; `energy` above 1 feeds the glow.
## Shop-lit toon material (shop_char.gdshader: scaled, capped light) so lamps and sun never blow colours to flat peach.
## Cached per colour; the room reads a little richer than the characters, so its light_scale is a touch higher.
static var _toon_cache: Dictionary = {}


static func _toon(color: Color) -> ShaderMaterial:
	var key: String = color.to_html(true)
	if _toon_cache.has(key):
		return _toon_cache[key] as ShaderMaterial
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://game/shop/shop_char.gdshader") as Shader
	m.set_shader_parameter("albedo", _clamp_bright(color))
	m.set_shader_parameter("light_scale", 0.4)
	m.set_shader_parameter("rim_strength", 0.05)
	_toon_cache[key] = m
	return m


## Near-white and pale-yellow props (shelf backboards, rack bars, cream boards) would still clip to flat white under
## the lamps: pull them to a soft lavender-grey ceiling so their form survives.
static func _clamp_bright(c: Color) -> Color:
	var lum: float = c.get_luminance()
	if lum <= 0.62:
		return c
	var t: float = clampf((lum - 0.62) / 0.38, 0.0, 1.0)
	var out: Color = c.lerp(Color(0.74, 0.70, 0.82), 0.3 + 0.3 * t)
	return Color(minf(out.r, 0.74), minf(out.g, 0.72), minf(out.b, 0.8), c.a)


static func glow_material(c: Color, energy: float = 1.6) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r * energy, c.g * energy, c.b * energy, 1.0)
	return m


func _glass_material(c: Color, alpha: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _label(parent: Node3D, text: String, pos: Vector3, font_size: int, color: Color, outline: Color,
		rot_y_deg: float = 0.0, pixel: float = 0.004) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = font_size
	l.outline_size = maxi(font_size / 6, 4)
	l.pixel_size = pixel
	l.modulate = color
	l.outline_modulate = outline
	l.position = pos
	l.rotation_degrees.y = rot_y_deg
	l.double_sided = false
	parent.add_child(l)
	return l


## A wooden plaque with a label, hung flat on a wall. `rot_y_deg` turns its face (+Z) into the room.
func _plaque(parent: Node3D, text: String, pos: Vector3, rot_y_deg: float, width: float, color: Color) -> void:
	var p: Node3D = Node3D.new()
	p.position = pos
	p.rotation_degrees.y = rot_y_deg
	parent.add_child(p)
	_box(p, Vector3.ZERO, Vector3(width, 0.32, 0.04), WOOD_DARK)
	_box(p, Vector3(0, 0, 0.012), Vector3(width - 0.08, 0.24, 0.03), color)
	_label(p, text, Vector3(0, 0, 0.035), 64, CREAM, INK, 0.0, 0.0035)


func _poster(parent: Node3D, kind: int, pos: Vector3, rot_y_deg: float, size: Vector2, title: String,
		title_color: Color) -> void:
	var p: Node3D = Node3D.new()
	p.name = "Poster%d" % kind
	p.position = pos
	p.rotation_degrees.y = rot_y_deg
	parent.add_child(p)
	var q: QuadMesh = QuadMesh.new()
	q.size = size
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://game/shop/poster.gdshader") as Shader
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("aspect", size.x / size.y)
	mat.set_shader_parameter("banner", 1.0 if title != "" else 0.0)
	_place(p, q, Vector3(0, 0, 0.01), mat)
	_box(p, Vector3(0, 0, -0.005), Vector3(size.x + 0.04, size.y + 0.04, 0.01), INK)
	if title != "":
		# The title sits on the banner baked into the poster art (shader strip along the bottom).
		var tl: Label3D = _label(p, title, Vector3(0, -size.y * (0.5 - 0.0825), 0.014), 40, title_color, INK, 0.0,
				minf(size.x * 0.86 / (float(title.length()) * 24.0), size.y * 0.11 / 40.0))
		tl.outline_size = 0
		tl.autowrap_mode = TextServer.AUTOWRAP_OFF
		tl.modulate = Color("#FFF6E6")
	for corner: Vector2 in [Vector2(-1, 1), Vector2(1, 1)]:
		_ball(p, Vector3(corner.x * (size.x * 0.5 - 0.04), corner.y * (size.y * 0.5 - 0.04), 0.02), 0.015, Color("#FF5A5F"))


func _plant(parent: Node3D, pos: Vector3, h: float) -> void:
	var p: Node3D = Node3D.new()
	p.position = pos
	parent.add_child(p)
	_cyl(p, Vector3(0, 0.2, 0), 0.22, 0.17, 0.4, POT)
	_cyl(p, Vector3(0, 0.39, 0), 0.24, 0.24, 0.04, POT.darkened(0.15))
	_cyl(p, Vector3(0, 0.4, 0), 0.2, 0.2, 0.02, Color("#6B4430"))
	for i: int in 7:
		var a: float = float(i) * TAU / 7.0 + 0.3
		var r: float = 0.18 + 0.05 * float(i % 2)
		var y: float = 0.45 + h * (0.35 + 0.1 * float(i % 3))
		_ball(p, Vector3(cos(a) * r, y, sin(a) * r), 0.17, LEAF if i % 2 == 0 else LEAF_LIGHT, Vector3(1.4, 0.45, 0.8))
		_cyl(p, Vector3(cos(a) * r * 0.5, (0.42 + y) * 0.5, sin(a) * r * 0.5), 0.012, 0.012, y - 0.42, Color("#2F8A55"),
				Vector3(sin(a) * 18.0, 0.0, -cos(a) * 18.0), 6)
	_solid(pos + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.5))


# --- environment and shell ---------------------------------------------------------------------------------

func _build_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2B2140")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.88, 0.76)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "ShopEnvironment"
	we.environment = env
	root.add_child(we)


func _build_shell() -> void:
	var g: Node3D = _group("Shell")
	# Floor: checker over the whole room, collision slab below it.
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = Vector2(W * 2.0, D * 2.0)
	var fm: ShaderMaterial = ShaderMaterial.new()
	fm.shader = load("res://game/shop/shop_floor.gdshader") as Shader
	fm.set_shader_parameter("size", Vector2(W * 2.0, D * 2.0))
	_place(g, floor_mesh, Vector3.ZERO, fm).name = "Floor"
	_solid(Vector3(0, -0.5, 0), Vector3(W * 2.0 + 10.0, 1.0, D * 2.0 + 10.0))
	# Ceiling and beams.
	_box(g, Vector3(0, H + 0.05, 0), Vector3(W * 2.0 + 0.4, 0.1, D * 2.0 + 0.4), CEILING).name = "Ceiling"
	for i: int in 6:
		var x: float = -W + 1.2 + float(i) * 2.32
		_box(g, Vector3(x, H - 0.1, 0), Vector3(0.16, 0.2, D * 2.0), WOOD_DARK)
	# Plank ceiling: alternating darker boards between the beams, so it reads as wood, not a flat lid.
	for i: int in 24:
		if i % 2 == 0:
			_box(g, Vector3(-W + 0.3 + float(i) * (W * 2.0 - 0.6) / 23.0, H - 0.004, 0), Vector3(0.28, 0.008, D * 2.0), CEILING_PLANK)
	# Neon cove strip running round the top of the walls (glow only, not lit).
	var strip_y: float = H - 0.22
	for sd: Array in [[Vector3(0, strip_y, -D + 0.05), Vector3(W * 2.0, 0.05, 0.05), NEON_PINK],
			[Vector3(-W + 0.05, strip_y, 0), Vector3(0.05, 0.05, D * 2.0), NEON_TEAL],
			[Vector3(W - 0.05, strip_y, 0), Vector3(0.05, 0.05, D * 2.0), NEON_ORANGE]]:
		_place(g, _box_mesh(sd[1] as Vector3), sd[0] as Vector3, glow_material(sd[2] as Color, 1.15))
	# Back wall (z = -D), side walls.
	_wall(g, Vector3(0, H * 0.5, -D - WALL_T * 0.5), Vector3(W * 2.0 + WALL_T * 2.0, H, WALL_T), WALL_PAINT)
	_wall(g, Vector3(-W - WALL_T * 0.5, H * 0.5, 0), Vector3(WALL_T, H, D * 2.0), WALL_PAINT)
	_wall(g, Vector3(W + WALL_T * 0.5, H * 0.5, 0), Vector3(WALL_T, H, D * 2.0), WALL_PAINT)
	# Accent panels: teal behind the board wall, pink behind the lounge.
	_box(g, Vector3(-5.0, 1.9, -D + 0.01), Vector3(3.9, 2.4, 0.02), WALL_ACCENT)
	_box(g, Vector3(W - 0.01, 2.0, 1.7), Vector3(0.02, 2.2, 3.0), WALL_PINK)
	# Wainscot: wood panelling up to a metre, with a trim rail.
	for side: Array in [[Vector3(0, 0.5, -D + 0.03), Vector3(W * 2.0, 1.0, 0.04)],
			[Vector3(-W + 0.03, 0.5, 0), Vector3(0.04, 1.0, D * 2.0)], [Vector3(W - 0.03, 0.5, 0), Vector3(0.04, 1.0, D * 2.0)]]:
		_box(g, side[0] as Vector3, side[1] as Vector3, WOOD_LIGHT)
		var trim_size: Vector3 = (side[1] as Vector3) + Vector3(0.03, -0.94, 0.03)
		_box(g, (side[0] as Vector3) + Vector3(0, 0.5, 0), trim_size, WOOD_DARK)
	# Front wall (z = +D) with the door and two windows.
	_build_front_wall(g)


func _wall(g: Node3D, center: Vector3, size: Vector3, color: Color) -> void:
	_box(g, center, size, color)
	_solid(center, size)


func _build_front_wall(g: Node3D) -> void:
	var z: float = D + WALL_T * 0.5
	var cuts: Array[Vector2] = [WINDOWS[0], Vector2(-DOOR_HALF, DOOR_HALF), WINDOWS[1]]
	var x: float = -W - WALL_T
	for c: Vector2 in cuts:
		_wall(g, Vector3((x + c.x) * 0.5, H * 0.5, z), Vector3(c.x - x, H, WALL_T), WALL_PAINT)
		x = c.y
	_wall(g, Vector3((x + W + WALL_T) * 0.5, H * 0.5, z), Vector3(W + WALL_T - x, H, WALL_T), WALL_PAINT)
	# Above the door and windows, below the windows.
	_wall(g, Vector3(0, (DOOR_H + H) * 0.5, z), Vector3(DOOR_HALF * 2.0, H - DOOR_H, WALL_T), WALL_PAINT)
	for wnd: Vector2 in WINDOWS:
		var cx: float = (wnd.x + wnd.y) * 0.5
		var w: float = wnd.y - wnd.x
		_wall(g, Vector3(cx, (WINDOW_Y.y + H) * 0.5, z), Vector3(w, H - WINDOW_Y.y, WALL_T), WALL_PAINT)
		_wall(g, Vector3(cx, WINDOW_Y.x * 0.5, z), Vector3(w, WINDOW_Y.x, WALL_T), WOOD_LIGHT)
		# frame, mullion, sill, glass
		_box(g, Vector3(cx, WINDOW_Y.x + 0.02, D - 0.06), Vector3(w + 0.1, 0.05, 0.24), WOOD_DARK)
		_box(g, Vector3(cx, WINDOW_Y.y - 0.03, D), Vector3(w, 0.06, 0.08), CREAM)
		_box(g, Vector3(cx, (WINDOW_Y.x + WINDOW_Y.y) * 0.5, D), Vector3(0.06, WINDOW_Y.y - WINDOW_Y.x, 0.08), CREAM)
		for ex: float in [wnd.x + 0.03, wnd.y - 0.03]:
			_box(g, Vector3(ex, (WINDOW_Y.x + WINDOW_Y.y) * 0.5, D), Vector3(0.06, WINDOW_Y.y - WINDOW_Y.x, 0.08), CREAM)
		var pane: QuadMesh = QuadMesh.new()
		pane.size = Vector2(w, WINDOW_Y.y - WINDOW_Y.x)
		_place(g, pane, Vector3(cx, (WINDOW_Y.x + WINDOW_Y.y) * 0.5, D + 0.02), _glass_material(Color("#BFEFFF"), 0.12))
	# The glass door: frame, panel, push bar, and a little "OPEN" sign. It is closed, so it is solid.
	var door: Node3D = Node3D.new()
	door.name = "FrontDoor"
	g.add_child(door)
	for ex: float in [-DOOR_HALF + 0.04, DOOR_HALF - 0.04]:
		_box(door, Vector3(ex, DOOR_H * 0.5, D), Vector3(0.08, DOOR_H, 0.14), WOOD_DARK)
	_box(door, Vector3(0, DOOR_H - 0.04, D), Vector3(DOOR_HALF * 2.0, 0.08, 0.14), WOOD_DARK)
	_box(door, Vector3(0, 0.08, D), Vector3(DOOR_HALF * 2.0, 0.16, 0.1), WOOD_DARK)
	_box(door, Vector3(0, DOOR_H * 0.5, D + 0.02), Vector3(0.05, DOOR_H, 0.05), WOOD_DARK)
	var glass: QuadMesh = QuadMesh.new()
	glass.size = Vector2(DOOR_HALF * 2.0 - 0.16, DOOR_H - 0.24)
	_place(door, glass, Vector3(0, DOOR_H * 0.5 + 0.04, D + 0.01), _glass_material(Color("#CFF4FF"), 0.14))
	_cyl(door, Vector3(0, 1.05, D - 0.08), 0.025, 0.025, 1.2, METAL, Vector3(0, 0, 90), 10)
	var sign_holder: Node3D = Node3D.new()
	sign_holder.position = Vector3(-0.38, 1.6, D - 0.03)
	sign_holder.rotation_degrees.y = 180.0
	door.add_child(sign_holder)
	_box(sign_holder, Vector3.ZERO, Vector3(0.44, 0.2, 0.02), CREAM)
	_label(sign_holder, "COME IN!", Vector3(0, 0, -0.015), 48, Color("#E0455A"), CREAM, 180.0, 0.003)
	_solid(Vector3(0, DOOR_H * 0.5, D + 0.05), Vector3(DOOR_HALF * 2.0, DOOR_H, 0.2))
	# Doormat inside.
	_box(g, Vector3(0, 0.008, D - 0.75), Vector3(1.9, 0.016, 1.0), Color("#C2553F"))
	_box(g, Vector3(0, 0.0165, D - 0.75), Vector3(1.78, 0.004, 0.88), Color("#A63F2E"))
	var mat_text: Label3D = _label(g, "SHRED ON", Vector3(0, 0.04, D - 0.75), 96, CREAM, INK, 0.0, 0.0048)
	mat_text.rotation_degrees = Vector3(-90, 180, 0)
	mat_text.double_sided = true
	mat_text.outline_size = 10


func _build_outside() -> void:
	var g: Node3D = _group("Outside")
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(30.0, 11.0)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://game/shop/street_view.gdshader") as Shader
	var back: MeshInstance3D = _place(g, q, Vector3(0, 3.2, D + 7.0), mat, Vector3(0, 180, 0))
	back.name = "StreetView"
	_box(g, Vector3(0, -0.02, D + 3.5), Vector3(30.0, 0.04, 7.0), Color("#D9C8C0")).name = "Sidewalk"
	_box(g, Vector3(0, 0.06, D + 2.6), Vector3(30.0, 0.12, 0.25), Color("#B8A8A8"))
	# Striped awning over the storefront.
	for i: int in 16:
		var x: float = -W + 0.45 + float(i) * 0.875
		_box(g, Vector3(x, H - 0.25, D + 0.55), Vector3(0.875, 0.06, 1.1), NEON_PINK.lerp(CREAM, 0.15) if i % 2 == 0 else CREAM, Vector3(-18, 0, 0))


# --- boards: deck wall, glass case, workbench -------------------------------------------------------------------

const _DECK_SHAPE_KEYS: Array[String] = ["popsicle", "popsicle", "cruiser", "oldschool", "popsicle"]
const _DECK_GRAPHICS: Array[String] = ["sunset", "wave", "face", "checker", "flames", "palm"]
var _board_cache: Dictionary = {}
const DECK_Y_OFFSET: float = 0.125  ## deck sits 0.12 above the board origin; standing, that is depth behind the holder


## A real AnimeBoard deck (graphic, shaped nose/tail, optionally trucks and wheels) standing on its tail with the
## graphic facing +Z (rotated by `face_yaw` about Y), tilted `tilt` degrees on its peg. Built once per variant and
## copied, so a wall of twenty decks stays cheap. Origin at the board's centre.
func _deck(parent: Node3D, center: Vector3, base: Color, accent: Color, style: int, tilt: float = 0.0,
		with_trucks: bool = false, face_yaw: float = 0.0) -> void:
	var shape: String = _DECK_SHAPE_KEYS[style % _DECK_SHAPE_KEYS.size()]
	var graphic: String = _DECK_GRAPHICS[style % _DECK_GRAPHICS.size()]
	var key: String = "%s|%s|%s|%s|%s" % [shape, graphic, base.to_html(false), accent.to_html(false), with_trucks]
	if not _board_cache.has(key):
		var pal: Dictionary = {"deck": base, "deck_dark": base.darkened(0.35), "deck_alt": accent,
				"deck_accent": accent, "deck_foam": CREAM, "deck_sun": accent.lightened(0.25)}
		var board: Node3D = PlaceholderSkater.build_board(pal, {"deck": shape, "graphic": graphic})
		if not with_trucks:
			for n: String in ["Truck_Front", "Truck_Back", "Wheel_FL", "Wheel_FL_Hub", "Wheel_FR", "Wheel_FR_Hub",
					"Wheel_BL", "Wheel_BL_Hub", "Wheel_BR", "Wheel_BR_Hub"]:
				var node: Node = board.get_node_or_null(n)
				if node != null:
					board.remove_child(node)
					node.free()
		Toon.apply_to(board)
		_board_cache[key] = board
	var src: Node3D = _board_cache[key] as Node3D
	var holder: Node3D = Node3D.new()
	holder.position = center
	holder.rotation_degrees = Vector3(0, face_yaw, tilt)
	parent.add_child(holder)
	var d: Node3D = src.duplicate() as Node3D
	# Board length (Z) up, underside graphic toward +Z; the deck's own centre sits near its origin.
	d.rotation_degrees = Vector3(-90, 0, 0)
	d.position = Vector3(0, 0, DECK_Y_OFFSET)
	holder.add_child(d)


## A shaped surfboard (pointed nose, round tail, stripe, fins) built from the same lofted-tube helper as the garments.
func _surfboard(parent: Node3D, length: float, width: float, base: Color, stripe: Color) -> void:
	var rows: Array = []
	var stripe_rows: Array = []
	var n: int = 16
	for i: int in n + 1:
		var t: float = float(i) / float(n)  # 0 = nose, 1 = tail
		var hw: float = width * 0.5 * pow(sin(PI * clampf(0.02 + 0.98 * t, 0.0, 1.0)) , 0.55) * (1.0 - 0.18 * t)
		if t < 0.3:
			hw = width * 0.5 * pow(sin(PI * 0.5 * (t / 0.3)), 0.7)
		hw = maxf(hw, 0.012)
		var hd: float = 0.035 * (1.0 - pow(absf(t - 0.45) * 1.7, 2.0)) + 0.012
		var y: float = length * 0.5 - t * length
		rows.append(Vector3(y, hw, hd))
		stripe_rows.append(Vector3(y, hw * 0.22, hd + 0.006))
	var mesh: ArrayMesh = _loft(rows, 20, 0.0, 0.0)
	_place(parent, mesh, Vector3.ZERO, _toon(base))
	_place(parent, _loft(stripe_rows, 10, 0.0, 0.0), Vector3(0, 0, 0.0), _toon(stripe))
	# two side fins and a centre fin on the wall-facing side, at the tail
	for fx: float in [-width * 0.3, width * 0.3]:
		_box(parent, Vector3(fx, -length * 0.5 + 0.38, -0.07), Vector3(0.02, 0.14, 0.1), INK, Vector3(0, 0, fx * 20.0))
	_box(parent, Vector3(0, -length * 0.5 + 0.28, -0.08), Vector3(0.02, 0.18, 0.12), INK)


func _wheel(parent: Node3D, center: Vector3, color: Color, rot_deg: Vector3 = Vector3(0, 0, 90)) -> void:
	_cyl(parent, center, 0.028, 0.028, 0.035, color, rot_deg, 14)
	_cyl(parent, center, 0.012, 0.012, 0.037, CREAM, rot_deg, 10)


func _truck(parent: Node3D, center: Vector3, color: Color) -> void:
	_box(parent, center + Vector3(0, 0.015, 0), Vector3(0.06, 0.012, 0.08), color.darkened(0.15))
	_cyl(parent, center + Vector3(0, 0.035, 0), 0.012, 0.012, 0.2, color, Vector3(0, 0, 90), 10)
	_box(parent, center + Vector3(0, 0.03, 0), Vector3(0.05, 0.035, 0.03), color)
	_cyl(parent, center + Vector3(0, 0.025, 0.02), 0.012, 0.012, 0.02, Color("#FF8C38"), Vector3(90, 0, 0), 8)


func _build_boards() -> void:
	var g: Node3D = _group("Boards")
	# Deck wall on the back wall: two rows of decks on pegs over the teal accent.
	var n: int = 0
	for row: int in 2:
		for i: int in 10:
			var x: float = -6.55 + float(i) * 0.34
			var y: float = 1.55 + float(row) * 0.95
			var base: Color = DECK_COLORS[(i * 5 + row * 3) % DECK_COLORS.size()]
			var accent: Color = DECK_COLORS[(i * 7 + row * 5 + 4) % DECK_COLORS.size()]
			if accent == base:
				accent = CREAM
			_deck(g, Vector3(x, y, -D + 0.07), base, accent, n, float((n * 7) % 5 - 2) * 1.6)
			_cyl(g, Vector3(x, y + 0.43, -D + 0.04), 0.012, 0.012, 0.1, METAL, Vector3(90, 0, 0), 8)
			n += 1
	_plaque(g, "DECKS", Vector3(-5.0, 3.1, -D + 0.04), 0.0, 1.2, Color("#E0455A"))
	# A few completes (decks with trucks and wheels) leaning on the west wall, graphics out.
	for i: int in 3:
		_deck(g, Vector3(-W + 0.2, 0.46, -1.6 - float(i) * 0.32), DECK_COLORS[i + 5], CREAM, i + 2, 8.0, true, 90.0)
	# Workbench with a vice; ShopRoom clamps the player's board into `vice`.
	var bench: Node3D = Node3D.new()
	bench.name = "Workbench"
	g.add_child(bench)
	var bx: Vector2 = Vector2(-6.5, -4.2)
	var bz: Vector2 = Vector2(-4.95, -4.25)
	var top_y: float = 0.9
	var cx: float = (bx.x + bx.y) * 0.5
	var cz: float = (bz.x + bz.y) * 0.5
	_box(bench, Vector3(cx, top_y - 0.03, cz), Vector3(bx.y - bx.x, 0.06, bz.y - bz.x), WOOD)
	for lx: float in [bx.x + 0.06, bx.y - 0.06]:
		for lz: float in [bz.x + 0.06, bz.y - 0.06]:
			_box(bench, Vector3(lx, (top_y - 0.06) * 0.5, lz), Vector3(0.07, top_y - 0.06, 0.07), WOOD_DARK)
	_box(bench, Vector3(cx, 0.25, cz), Vector3(bx.y - bx.x - 0.1, 0.04, bz.y - bz.x - 0.1), WOOD_DARK)
	# tools: wheels, a skate tool, a wax bar, a grip roll
	_wheel(bench, Vector3(-6.2, top_y + 0.03, -4.5), Color("#FFD84D"), Vector3(90, 0, 0))
	_wheel(bench, Vector3(-6.12, top_y + 0.03, -4.4), Color("#FFD84D"), Vector3(90, 0, 0))
	_truck(bench, Vector3(-5.95, top_y, -4.6), METAL)
	_box(bench, Vector3(-4.6, top_y + 0.015, -4.4), Vector3(0.14, 0.03, 0.04), Color("#FF5A5F"), Vector3(0, 30, 0))
	_box(bench, Vector3(-4.45, top_y + 0.025, -4.7), Vector3(0.1, 0.05, 0.07), Color("#B79CFF"))
	_cyl(bench, Vector3(-6.35, top_y + 0.06, -4.75), 0.06, 0.06, 0.24, INK, Vector3(0, 0, 90))
	# vice: a cast jaw block on the bench with a screw handle
	var vice_x: float = -5.2
	_box(bench, Vector3(vice_x, top_y + 0.06, -4.6), Vector3(0.12, 0.12, 0.2), Color("#4F7CAC"))
	_box(bench, Vector3(vice_x + 0.1, top_y + 0.08, -4.6), Vector3(0.06, 0.16, 0.18), Color("#4F7CAC"))
	_cyl(bench, Vector3(vice_x - 0.12, top_y + 0.06, -4.6), 0.012, 0.012, 0.2, METAL, Vector3(0, 0, 90), 8)
	vice = Node3D.new()
	vice.name = "Vice"
	# Board on its side in the jaws, grip toward the wall, wheels toward the room: a set-up in progress.
	vice.position = Vector3(vice_x + 0.04, top_y + 0.36, -4.6)
	vice.rotation_degrees = Vector3(0, 90, -90)
	bench.add_child(vice)
	_solid(Vector3(cx, top_y * 0.5, cz), Vector3(bx.y - bx.x, top_y, bz.y - bz.x))
	# Glass case of trucks and wheels along the west wall.
	var case: Node3D = Node3D.new()
	case.name = "GlassCase"
	g.add_child(case)
	var case_x: float = -W + 0.38
	var cz0: float = -3.75
	var cz1: float = -2.05
	var case_cz: float = (cz0 + cz1) * 0.5
	_box(case, Vector3(case_x, 0.3, case_cz), Vector3(0.62, 0.6, cz1 - cz0), WOOD_DARK)
	_box(case, Vector3(case_x, 0.62, case_cz), Vector3(0.62, 0.04, cz1 - cz0), CREAM)
	_box(case, Vector3(case_x, 0.82, case_cz), Vector3(0.56, 0.02, cz1 - cz0 - 0.06), CREAM.darkened(0.05))
	var glass_box: BoxMesh = BoxMesh.new()
	glass_box.size = Vector3(0.62, 0.45, cz1 - cz0)
	_place(case, glass_box, Vector3(case_x, 0.865, case_cz), _glass_material(Color("#BFEFFF"), 0.18))
	for ex: float in [cz0, cz1]:
		_box(case, Vector3(case_x, 0.865, ex), Vector3(0.64, 0.46, 0.02), METAL)
	_box(case, Vector3(case_x, 1.1, case_cz), Vector3(0.64, 0.02, cz1 - cz0 + 0.02), METAL)
	var wheel_colors: Array[Color] = [Color("#FFD84D"), Color("#FF7EB6"), Color("#4FC3F7"), CREAM, Color("#A6E22E"), Color("#FF9F1C")]
	var truck_colors: Array[Color] = [Color("#C9D3DD"), Color("#FFD84D"), Color("#3A506B"), Color("#FF5A5F"), Color("#4FC3F7"), Color("#C9D3DD")]
	var kinds: Array[String] = ["standard", "low", "hollow"]
	var wkinds: Array[String] = ["street", "park", "cruiser"]
	for i: int in 6:
		var z: float = cz0 + 0.18 + float(i) * 0.27
		# Real AnimeBoard trucks and wheels (pulled off a freshly built board), shown a little larger than life.
		var board: Node3D = PlaceholderSkater.build_board({"wheels": wheel_colors[i], "trucks": truck_colors[i]},
				{"truck": kinds[i % 3], "wheel": wkinds[(i + 1) % 3]})
		var truck: Node3D = board.get_node("Truck_Front") as Node3D
		board.remove_child(truck)
		truck.position = Vector3(case_x - 0.05, 0.83, z + 0.04)
		truck.rotation_degrees.y = 90.0
		truck.scale = Vector3.ONE * 1.25
		case.add_child(truck)
		Toon.apply_to(truck)
		for wn: Array in [["Wheel_FL", 0.0], ["Wheel_FL_Hub", 0.0], ["Wheel_FR", 0.085], ["Wheel_FR_Hub", 0.085]]:
			var w: Node3D = board.get_node(str(wn[0])) as Node3D
			board.remove_child(w)
			case.add_child(w)
			w.position = Vector3(case_x + 0.12, 0.65 + 0.032 * 1.25, z + float(wn[1]))
			w.scale = Vector3.ONE * 1.25
			Toon.apply_to(w)
		board.free()
	_solid(Vector3(case_x, 0.55, case_cz), Vector3(0.64, 1.1, cz1 - cz0))
	_plaque(g, "TRUCKS + WHEELS", Vector3(-W + 0.04, 1.75, case_cz), 90.0, 1.5, Color("#4F7CAC"))


# --- clothes: racks, shoe wall ---------------------------------------------------------------------------------

## A lofted garment tube along -Y: `rows` are Vector3(y, half width, half depth) elliptical sections, `fold` adds
## vertical fold ripples around the section. Closed at both ends, smooth normals.
func _loft(rows: Array, segs: int, fold: float, phase: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r: Vector3 in rows:
		for j: int in segs:
			var a: float = TAU * float(j) / float(segs)
			var rip: float = 1.0 + fold * sin(a * 3.0 + phase)
			st.add_vertex(Vector3(r.y * cos(a) * (1.0 + 0.3 * fold * sin(a * 5.0 + phase * 2.0)), r.x, r.z * sin(a) * rip))
	for i: int in rows.size() - 1:
		for j: int in segs:
			var j2: int = (j + 1) % segs
			var a0: int = i * segs + j
			var a1: int = i * segs + j2
			var b0: int = (i + 1) * segs + j
			var b1: int = (i + 1) * segs + j2
			for idx: int in [a0, b0, a1, a1, b0, b1]:
				st.add_index(idx)
	for cap: Array in [[0, false], [rows.size() - 1, true]]:
		var ci: int = int(cap[0])
		var centre: int = rows.size() * segs + (1 if cap[1] else 0)
		st.add_vertex(Vector3(0.0, (rows[ci] as Vector3).x, 0.0))
		for j: int in segs:
			var j2: int = (j + 1) % segs
			if cap[1]:
				st.add_index(centre)
				st.add_index(ci * segs + j2)
				st.add_index(ci * segs + j)
			else:
				st.add_index(centre)
				st.add_index(ci * segs + j)
				st.add_index(ci * segs + j2)
	st.generate_normals()
	return st.commit()


func _garment_meshes(hoodie: bool) -> Dictionary:
	var key: String = "hood" if hoodie else "tee"
	if _garment_cache.has(key):
		return _garment_cache[key] as Dictionary
	var d: Dictionary = {}
	if hoodie:
		d["body"] = _loft([Vector3(-0.09, 0.08, 0.04), Vector3(-0.11, 0.15, 0.05), Vector3(-0.17, 0.215, 0.058),
				Vector3(-0.33, 0.235, 0.062), Vector3(-0.52, 0.245, 0.058), Vector3(-0.66, 0.25, 0.052), Vector3(-0.68, 0.24, 0.05)], 18, 0.1, 0.4)
		d["sleeve"] = _loft([Vector3(0.0, 0.085, 0.06), Vector3(-0.12, 0.078, 0.056), Vector3(-0.3, 0.068, 0.05),
				Vector3(-0.44, 0.062, 0.05), Vector3(-0.46, 0.056, 0.048)], 12, 0.12, 1.3)
	else:
		d["body"] = _loft([Vector3(-0.09, 0.07, 0.035), Vector3(-0.105, 0.14, 0.045), Vector3(-0.16, 0.2, 0.05),
				Vector3(-0.32, 0.212, 0.052), Vector3(-0.47, 0.218, 0.05), Vector3(-0.58, 0.222, 0.046), Vector3(-0.6, 0.214, 0.044)], 18, 0.08, 1.1)
		d["sleeve"] = _loft([Vector3(0.0, 0.085, 0.05), Vector3(-0.07, 0.08, 0.048), Vector3(-0.15, 0.076, 0.046),
				Vector3(-0.17, 0.07, 0.044)], 12, 0.1, 0.2)
	_garment_cache[key] = d
	return d


## A tee (or hoodie) hanging on a rail from a wire hanger, its body in the plane across the rail (YZ when the rail
## runs along X): a lofted body with fold ripples, tapered sleeves, a ribbed collar, hood and pocket on hoodies.
func _tee(parent: Node3D, center: Vector3, color: Color, hoodie: bool, face_out: bool = false) -> void:
	var t: Node3D = Node3D.new()
	t.position = center
	t.rotation_degrees.y = 48.0 if face_out else 90.0  # the face-out sample is turned toward the aisle
	parent.add_child(t)
	var meshes: Dictionary = _garment_meshes(hoodie)
	var cloth: Material = _toon(color)
	var cloth2: Material = _toon(color.darkened(0.1))
	var trim: Material = _toon(color.darkened(0.25))
	_place(t, meshes["body"] as Mesh, Vector3.ZERO, cloth)
	var sleeve_y: float = -0.115 if not hoodie else -0.13
	var ang: float = 62.0 if not hoodie else 30.0
	var sx: float = 0.185 if not hoodie else 0.205
	_place(t, meshes["sleeve"] as Mesh, Vector3(sx, sleeve_y, 0.0), cloth2, Vector3(0, 0, ang))
	_place(t, meshes["sleeve"] as Mesh, Vector3(-sx, sleeve_y, 0.0), cloth2, Vector3(0, 0, -ang))
	var collar: TorusMesh = TorusMesh.new()
	collar.inner_radius = 0.045
	collar.outer_radius = 0.07
	_place(t, collar, Vector3(0, -0.095, 0.012), trim, Vector3(0, 0, 0), Vector3(1.0, 0.45, 0.8))
	if hoodie:
		_ball(t, Vector3(0, -0.12, -0.085), 0.12, color.darkened(0.12), Vector3(1.35, 0.9, 0.75))
		_ball(t, Vector3(0, -0.15, 0.055), 0.08, color.darkened(0.2), Vector3(1.5, 0.55, 0.35))  # hood front folded at the neck
		_box(t, Vector3(0, -0.46, 0.062), Vector3(0.3, 0.12, 0.02), color.darkened(0.12))
		_box(t, Vector3(0, -0.665, 0.0), Vector3(0.45, 0.04, 0.1), color.darkened(0.2))
		for cx: float in [-0.04, 0.04]:
			_cyl(t, Vector3(cx, -0.22, 0.066), 0.007, 0.007, 0.16, CREAM, Vector3.ZERO, 5)
	else:
		_ball(t, Vector3(0, -0.28, 0.05), 0.075, CREAM if color.get_luminance() < 0.6 else INK, Vector3(1.0, 1.0, 0.08))
	# wire hanger: hook, two arms to the shoulders
	_cyl(t, Vector3(0, 0.02, 0), 0.006, 0.006, 0.1, METAL, Vector3.ZERO, 6)
	for sgn: float in [-1.0, 1.0]:
		_cyl(t, Vector3(sgn * 0.065, -0.04, 0.0), 0.005, 0.005, 0.18, METAL, Vector3(0, 0, sgn * 47.0), 5)


func _rack(parent: Node3D, x0: float, x1: float, z: float, colors: Array[Color], hoodies: bool) -> void:
	var bar_y: float = 1.45
	for x: float in [x0, x1]:
		_cyl(parent, Vector3(x, bar_y * 0.5, z), 0.02, 0.02, bar_y, METAL, Vector3.ZERO, 8)
		_box(parent, Vector3(x, 0.02, z), Vector3(0.08, 0.04, 0.6), METAL.darkened(0.2))
		for dz: float in [-0.27, 0.27]:
			_ball(parent, Vector3(x, 0.03, z + dz), 0.03, INK)
	_cyl(parent, Vector3((x0 + x1) * 0.5, bar_y, z), 0.018, 0.018, x1 - x0, METAL, Vector3(0, 0, 90), 8)
	var count: int = colors.size()
	for i: int in count:
		var x: float = lerpf(x0 + 0.15, x1 - 0.15, (float(i) + 0.5) / float(count))
		_tee(parent, Vector3(x, bar_y - 0.02, z), colors[i], hoodies)
	# face-out sample on an arm at the aisle end
	_cyl(parent, Vector3(x1 + 0.2, bar_y - 0.05, z), 0.012, 0.012, 0.4, METAL, Vector3(0, 0, 90), 6)
	_tee(parent, Vector3(x1 + 0.38, bar_y - 0.07, z), colors[0], hoodies, true)
	_solid(Vector3((x0 + x1) * 0.5 + 0.2, 0.8, z), Vector3(x1 - x0 + 0.5, 1.6, 0.6))


## A real skate shoe (SkateShoe / ShoeStyles meshes, toon-shaded) standing on the floor of `parent`'s origin, toe along -Z.
## Built once per (style, colour, side) and then copied, so a full shelf stays cheap.
func _shoe(parent: Node3D, center: Vector3, color: Color, style: int, side: String, yaw_deg: float) -> void:
	var key: String = "%d|%s|%s" % [style, color.to_html(false), side]
	if not _shoe_cache.has(key):
		var foot: Node3D = Node3D.new()
		var mats: Dictionary = {}
		var cw: Dictionary = SkateShoe.colourway_from(color)
		var ankle: float = PlaceholderSkater.ANKLE_HEIGHT
		match style % 3:
			0: SkateShoe.build(foot, side, ankle, mats, cw)
			1: ShoeStyles.build_cupsole(foot, side, ankle, mats, cw)
			_: ShoeStyles.build_puffy(foot, side, ankle, mats, cw)
		Toon.apply_to(foot)
		_shoe_cache[key] = foot
	var copy: Node3D = (_shoe_cache[key] as Node3D).duplicate() as Node3D
	copy.position = center + Vector3(0, PlaceholderSkater.ANKLE_HEIGHT, 0)
	copy.rotation_degrees.y = yaw_deg
	parent.add_child(copy)


func _build_clothes() -> void:
	var g: Node3D = _group("Clothes")
	var tees: Array[Color] = [Color("#FF5A5F"), Color("#FFD84D"), CREAM, Color("#4FC3F7"), Color("#1B1B2F"),
			Color("#2EC4B6"), Color("#FF9F1C"), Color("#B79CFF")]
	var hoods: Array[Color] = [Color("#7C83FD"), Color("#E0455A"), Color("#3A506B"), Color("#FF7EB6"),
			Color("#F4F1DE"), Color("#2EC4B6"), Color("#FFB04D")]
	_rack(g, -4.6, -2.7, -0.35, tees, false)
	_rack(g, -4.6, -2.7, 1.95, hoods, true)
	_plaque(g, "THREADS", Vector3(-3.4, 2.75, 0.8), 90.0, 1.3, Color("#2EC4B6"))
	var hang: Node3D = g.get_child(g.get_child_count() - 1) as Node3D
	_cyl(g, hang.position + Vector3(0, 0.45, 0.4), 0.006, 0.006, 0.6, INK, Vector3.ZERO, 4)
	_cyl(g, hang.position + Vector3(0, 0.45, -0.4), 0.006, 0.006, 0.6, INK, Vector3.ZERO, 4)
	# Shoe wall on the west wall: five shelves of pairs.
	var shoes: Node3D = Node3D.new()
	shoes.name = "ShoeWall"
	g.add_child(shoes)
	var z0: float = -0.95
	var z1: float = 2.65
	_box(shoes, Vector3(-W + 0.02, 1.55, (z0 + z1) * 0.5), Vector3(0.03, 2.3, z1 - z0 + 0.1), Color("#A59DC0"))
	var shoe_colors: Array[Color] = [Color("#FF5A5F"), CREAM, Color("#1B1B2F"), Color("#4FC3F7"), Color("#FFD84D"),
			Color("#7C83FD"), Color("#FF9F1C"), Color("#2EC4B6"), Color("#E0455A"), Color("#FF7EB6")]
	for sh: int in 5:
		var y: float = 0.55 + float(sh) * 0.47
		_box(shoes, Vector3(-W + 0.17, y, (z0 + z1) * 0.5), Vector3(0.3, 0.03, z1 - z0), WOOD)
		for i: int in 5:
			var z: float = z0 + 0.36 + float(i) * 0.72
			var c: Color = shoe_colors[(sh * 3 + i) % shoe_colors.size()]
			var style: int = (i + sh) % 3
			# a pair, toes out into the room (-90 degrees turns toe -Z to +X)
			_shoe(shoes, Vector3(-W + 0.12, y + 0.015, z - 0.07), c, style, "Left", -90.0 - 6.0)
			_shoe(shoes, Vector3(-W + 0.12, y + 0.015, z + 0.07), c, style, "Right", -90.0 + 6.0)
	_solid(Vector3(-W + 0.17, 1.2, (z0 + z1) * 0.5), Vector3(0.34, 2.4, z1 - z0))
	_plaque(g, "KICKS", Vector3(-W + 0.04, 3.0, 0.85), 90.0, 1.0, Color("#FF9F1C"))
	# A bench to try shoes on.
	_box(g, Vector3(-5.6, 0.22, 0.85), Vector3(0.45, 0.06, 1.2), WOOD)
	_box(g, Vector3(-5.6, 0.1, 0.85), Vector3(0.35, 0.2, 1.0), WOOD_DARK)
	_solid(Vector3(-5.6, 0.12, 0.85), Vector3(0.45, 0.25, 1.2))


func _build_surf_corner() -> void:
	var g: Node3D = _group("SurfCorner")
	# Two longboards leaning on the west wall, each with a stripe and a fin.
	var boards: Array[Array] = [[3.25, Color("#F4F1DE"), Color("#2EC4B6")], [3.95, Color("#FFB04D"), Color("#E0455A")],
			[4.55, Color("#4FC3F7"), CREAM]]
	for b: Array in boards:
		var holder: Node3D = Node3D.new()
		holder.position = Vector3(-W + 0.3, 1.05, float(b[0]))
		holder.rotation_degrees = Vector3(0, 90, -12)
		g.add_child(holder)
		_surfboard(holder, 2.0, 0.5, b[1] as Color, b[2] as Color)
	_solid(Vector3(-W + 0.35, 1.0, 3.9), Vector3(0.6, 2.0, 1.7))
	# Wetsuits hanging face-out on the front wall.
	for i: int in 2:
		var w: Node3D = Node3D.new()
		w.position = Vector3(-6.2 + float(i) * 0.75, 2.2, D - 0.12)
		w.rotation_degrees.y = 180.0
		g.add_child(w)
		var body_c: Color = INK
		var panel: Color = Color("#2EC4B6") if i == 0 else Color("#FF7EB6")
		_box(w, Vector3(0, -0.32, 0), Vector3(0.38, 0.6, 0.06), body_c)
		_box(w, Vector3(0, -0.2, 0.032), Vector3(0.38, 0.12, 0.01), panel)
		_box(w, Vector3(-0.1, -0.95, 0), Vector3(0.15, 0.7, 0.05), body_c, Vector3(0, 0, 3))
		_box(w, Vector3(0.1, -0.95, 0), Vector3(0.15, 0.7, 0.05), body_c, Vector3(0, 0, -3))
		_box(w, Vector3(-0.26, -0.35, 0), Vector3(0.1, 0.6, 0.05), panel, Vector3(0, 0, -10))
		_box(w, Vector3(0.26, -0.35, 0), Vector3(0.1, 0.6, 0.05), panel, Vector3(0, 0, 10))
		_box(w, Vector3(0, -0.02, 0), Vector3(0.36, 0.04, 0.03), WOOD_DARK)
		_cyl(w, Vector3(0, 0.08, 0), 0.008, 0.008, 0.16, METAL, Vector3.ZERO, 6)
	_plaque(g, "SURF", Vector3(-5.85, 2.85, D - 0.04), 180.0, 0.9, Color("#4FC3F7"))
	_plant(g, Vector3(-4.75, 0, 4.55), 0.9)


# --- dressing booth ----------------------------------------------------------------------------------------------

func _build_dressing() -> void:
	var g: Node3D = _group("Dressing")
	var x0: float = -2.75
	var x1: float = -0.85
	var zf: float = -3.55
	var hb: float = 2.35
	for x: float in [x0, x1]:
		_box(g, Vector3(x, hb * 0.5, (zf - D) * 0.5), Vector3(0.08, hb, D + zf), WOOD)
		_solid(Vector3(x, hb * 0.5, (zf - D) * 0.5), Vector3(0.1, hb, D + zf))
	_box(g, Vector3((x0 + x1) * 0.5, hb + 0.06, zf + 0.02), Vector3(x1 - x0 + 0.1, 0.16, 0.12), WOOD_DARK)
	_box(g, Vector3((x0 + x1) * 0.5, hb + 0.13, (zf - D) * 0.5), Vector3(x1 - x0 + 0.1, 0.02, D + zf), WOOD_DARK)
	_label(g, "FITTING ROOM", Vector3((x0 + x1) * 0.5, hb + 0.06, zf + 0.085), 48, CREAM, INK, 0.0, 0.003)
	# Inside: a tall mirror with anime shine streaks, a stool and a hook with a hoodie.
	var mx: float = (x0 + x1) * 0.5
	_box(g, Vector3(mx, 1.25, -D + 0.04), Vector3(0.82, 1.82, 0.04), WOOD_DARK)
	_box(g, Vector3(mx, 1.25, -D + 0.065), Vector3(0.7, 1.7, 0.02), Color("#BFE6F5"))
	for k: int in 2:
		_box(g, Vector3(mx - 0.1 + float(k) * 0.16, 1.45 - float(k) * 0.12, -D + 0.08), Vector3(0.06 - float(k) * 0.03, 0.9, 0.005), CREAM, Vector3(0, 0, -28))
	_cyl(g, Vector3(x0 + 0.35, 0.22, -4.4), 0.18, 0.18, 0.06, Color("#FF7EB6"))
	_cyl(g, Vector3(x0 + 0.35, 0.1, -4.4), 0.03, 0.05, 0.2, METAL)
	_tee(g, Vector3(x1 - 0.14, 1.9, -4.5), Color("#7C83FD"), true, false)
	# Curtain rail and a curtain drawn two thirds across, in soft folds.
	_cyl(g, Vector3(mx, hb - 0.08, zf + 0.05), 0.015, 0.015, x1 - x0, METAL, Vector3(0, 0, 90), 8)
	var folds: int = 9
	for i: int in folds:
		var x: float = x0 + 0.1 + float(i) * 0.135
		var c: Color = Color("#E0455A") if i % 2 == 0 else Color("#C93A4E")
		_box(g, Vector3(x, (hb - 0.1) * 0.5 + 0.08, zf + 0.05 + (0.03 if i % 2 == 0 else -0.02)), Vector3(0.15, hb - 0.26, 0.03), c, Vector3(0, (14.0 if i % 2 == 0 else -14.0), 0))
	_cyl(g, Vector3(x0 + 0.1 + float(folds) * 0.135 - 0.05, 1.2, zf + 0.1), 0.012, 0.012, 0.18, Color("#FFD84D"), Vector3(0, 0, 90), 6)
	# Full-length mirror outside on the booth's east side, angled to the room.
	var m: Node3D = Node3D.new()
	m.position = Vector3(x1 + 0.35, 0.0, -3.45)
	m.rotation_degrees.y = -20.0
	g.add_child(m)
	_box(m, Vector3(0, 1.0, 0), Vector3(0.6, 1.7, 0.06), Color("#FFD84D"))
	_box(m, Vector3(0, 1.0, 0.035), Vector3(0.5, 1.58, 0.02), Color("#BFE6F5"))
	_box(m, Vector3(-0.08, 1.15, 0.05), Vector3(0.05, 0.8, 0.005), CREAM, Vector3(0, 0, -25))
	_box(m, Vector3(0.06, 1.05, 0.05), Vector3(0.025, 0.6, 0.005), CREAM, Vector3(0, 0, -25))
	_box(m, Vector3(0, 0.1, -0.15), Vector3(0.5, 0.04, 0.4), Color("#FFD84D"))
	_solid(Vector3(x1 + 0.35, 0.9, -3.45), Vector3(0.6, 1.8, 0.4), -20.0)


# --- counter, register, shelves, neon sign -----------------------------------------------------------------------

func _build_counter() -> void:
	var g: Node3D = _group("Counter")
	var x0: float = 0.25
	var x1: float = 3.85
	var z0: float = -3.95
	var z1: float = -3.3
	var cx: float = (x0 + x1) * 0.5
	var cz: float = (z0 + z1) * 0.5
	_box(g, Vector3(cx, (COUNTER_TOP - 0.05) * 0.5, cz), Vector3(x1 - x0, COUNTER_TOP - 0.05, z1 - z0), WOOD)
	_box(g, Vector3(cx, COUNTER_TOP - 0.025, cz + 0.04), Vector3(x1 - x0 + 0.1, 0.05, z1 - z0 + 0.12), WOOD_DARK)
	_box(g, Vector3(cx, 0.06, z1 + 0.005), Vector3(x1 - x0, 0.12, 0.02), INK)
	# Sticker-bombed front.
	for i: int in 34:
		var sx: float = _rng.randf_range(x0 + 0.12, x1 - 0.12)
		var sy: float = _rng.randf_range(0.2, COUNTER_TOP - 0.15)
		var sc: Color = DECK_COLORS[_rng.randi_range(0, DECK_COLORS.size() - 1)]
		var sz: Vector2 = Vector2(_rng.randf_range(0.1, 0.22), _rng.randf_range(0.07, 0.16))
		if i % 3 == 0:
			_ball(g, Vector3(sx, sy, z1 + 0.012), sz.x * 0.5, sc, Vector3(1.0, 1.0, 0.05))
		else:
			_box(g, Vector3(sx, sy, z1 + 0.01 + float(i) * 0.0003), Vector3(sz.x, sz.y, 0.006), sc, Vector3(0, 0, _rng.randf_range(-25.0, 25.0)))
	_solid(Vector3(cx, COUNTER_TOP * 0.5, cz), Vector3(x1 - x0, COUNTER_TOP, z1 - z0 + 0.1))
	# Register.
	var reg: Node3D = Node3D.new()
	reg.name = "Register"
	reg.position = Vector3(3.05, COUNTER_TOP, -3.65)
	g.add_child(reg)
	_box(reg, Vector3(0, 0.06, 0), Vector3(0.42, 0.12, 0.36), Color("#4FC3F7"))
	_box(reg, Vector3(0, 0.15, -0.06), Vector3(0.38, 0.08, 0.2), Color("#3A8FC0"), Vector3(-20, 0, 0))
	_box(reg, Vector3(0, 0.3, -0.13), Vector3(0.3, 0.2, 0.03), INK, Vector3(-12, 0, 0))
	var screen: QuadMesh = QuadMesh.new()
	screen.size = Vector2(0.24, 0.14)
	_place(reg, screen, Vector3(0, 0.3, -0.112), glow_material(Color("#A6F0C8"), 1.0), Vector3(-12, 0, 0))
	for i: int in 9:
		_box(reg, Vector3(-0.1 + float(i % 3) * 0.06, 0.2 - float(i / 3) * 0.012, 0.0 + float(i / 3) * 0.045), Vector3(0.045, 0.02, 0.035), CREAM, Vector3(-20, 0, 0))
	_box(reg, Vector3(0, 0.03, 0.19), Vector3(0.36, 0.05, 0.02), Color("#FFD84D"))
	# Sticker spinner.
	var spin: Node3D = Node3D.new()
	spin.name = "StickerDisplay"
	spin.position = Vector3(0.75, COUNTER_TOP, -3.62)
	spin.rotation_degrees.y = 20.0
	g.add_child(spin)
	_cyl(spin, Vector3(0, 0.02, 0), 0.12, 0.14, 0.04, INK)
	_cyl(spin, Vector3(0, 0.35, 0), 0.012, 0.012, 0.66, METAL, Vector3.ZERO, 8)
	for tier: int in 3:
		for side: int in 4:
			var holder: Node3D = Node3D.new()
			holder.position = Vector3(0, 0.18 + float(tier) * 0.2, 0)
			holder.rotation_degrees.y = float(side) * 90.0
			spin.add_child(holder)
			_box(holder, Vector3(0, 0, 0.06), Vector3(0.18, 0.18, 0.01), CREAM)
			for k: int in 4:
				var c: Color = DECK_COLORS[(tier * 5 + side * 3 + k) % DECK_COLORS.size()]
				var p: Vector3 = Vector3(-0.04 + float(k % 2) * 0.08, -0.04 + float(k / 2) * 0.08, 0.067)
				if k % 2 == tier % 2:
					_ball(holder, p, 0.032, c, Vector3(1.0, 1.0, 0.1))
				else:
					_box(holder, p, Vector3(0.065, 0.05, 0.004), c, Vector3(0, 0, 12.0 * float(k - 1)))
	# A tip jar and a stack of stickers.
	_cyl(g, Vector3(1.45, COUNTER_TOP + 0.08, -3.5), 0.06, 0.06, 0.16, Color("#BFE6F5"))
	_label(g, "TIPS = RAD", Vector3(1.45, COUNTER_TOP + 0.1, -3.43), 32, INK, CREAM, 0.0, 0.0022)
	# Shelves behind the counter: shoe boxes and caps.
	for s: int in 2:
		var y: float = 1.35 + float(s) * 0.5
		_box(g, Vector3(cx, y, -D + 0.16), Vector3(x1 - x0 - 0.2, 0.03, 0.3), WOOD)
		for i: int in 7:
			var x: float = x0 + 0.35 + float(i) * 0.48
			if s == 0:
				var bc: Color = [Color("#FF5A5F"), Color("#4FC3F7"), INK, Color("#FFD84D")][i % 4] as Color
				_box(g, Vector3(x, y + 0.08, -D + 0.17), Vector3(0.34, 0.13, 0.22), bc)
				_box(g, Vector3(x, y + 0.155, -D + 0.17), Vector3(0.35, 0.03, 0.23), bc.lightened(0.25))
				_box(g, Vector3(x, y + 0.2, -D + 0.17), Vector3(0.34, 0.08, 0.22), bc.darkened(0.1))
			else:
				var capc: Color = DECK_COLORS[(i * 5 + 2) % DECK_COLORS.size()]
				_ball(g, Vector3(x, y + 0.02, -D + 0.17), 0.1, capc, Vector3(1.0, 0.7, 1.0))
				_box(g, Vector3(x, y + 0.025, -D + 0.3), Vector3(0.16, 0.012, 0.1), capc.darkened(0.2))
	# Neon shop sign on the back wall above the shelves.
	var sign_node: Node3D = Node3D.new()
	sign_node.name = "NeonSign"
	sign_node.position = Vector3(2.05, 2.78, -D + 0.04)
	g.add_child(sign_node)
	_box(sign_node, Vector3.ZERO, Vector3(3.9, 0.78, 0.04), Color("#241B38"))
	var title: Label3D = _label(sign_node, "SUNSET SKATE CO.", Vector3(0.3, 0.02, 0.04), 100, Color(2.3, 0.95, 1.6), Color(1.0, 0.22, 0.55), 0.0, 0.0031)
	title.outline_size = 22
	# neon sun on the left: a ring, half under a wave line
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.17
	ring.outer_radius = 0.2
	ring.rings = 24
	ring.ring_segments = 8
	_place(sign_node, ring, Vector3(-1.55, 0.04, 0.05), glow_material(NEON_ORANGE, 2.0), Vector3(90, 0, 0))
	for k: int in 3:
		var wave: BoxMesh = BoxMesh.new()
		wave.size = Vector3(0.42 - float(k) * 0.08, 0.02, 0.02)
		_place(sign_node, wave, Vector3(-1.55, -0.04 - float(k) * 0.07, 0.06), glow_material(NEON_TEAL, 1.8))
	for edge: Array in [[Vector3(0, 0.36, 0.05), Vector3(3.8, 0.025, 0.025)], [Vector3(0, -0.36, 0.05), Vector3(3.8, 0.025, 0.025)],
			[Vector3(-1.9, 0, 0.05), Vector3(0.025, 0.72, 0.025)], [Vector3(1.9, 0, 0.05), Vector3(0.025, 0.72, 0.025)]]:
		var tube: BoxMesh = BoxMesh.new()
		tube.size = edge[1] as Vector3
		_place(sign_node, tube, edge[0] as Vector3, glow_material(NEON_TEAL, 1.4))


# --- mini ramp ----------------------------------------------------------------------------------------------------

func _build_ramp() -> void:
	var g: Node3D = _group("MiniRamp")
	var qp: Node3D = QuarterPipe.build(2.6, 1.2, 1.2, 0.8, 12)
	qp.position = Vector3(W, 0, -D)
	qp.rotation_degrees.y = -90.0
	g.add_child(qp)
	# paint a stripe and some stickers on the deck front
	_box(g, Vector3(W - 1.0, 1.21, -D + 1.3), Vector3(0.02, 0.01, 2.6), Color("#FF5A5F"))


# --- style station -------------------------------------------------------------------------------------------------

func _build_style() -> void:
	var g: Node3D = _group("Style")
	var cz: float = -1.15
	var chair: Node3D = Node3D.new()
	chair.name = "StylistChair"
	chair.position = Vector3(5.95, 0, cz)
	chair.rotation_degrees.y = -90.0  ## the sitter faces +X, the mirror
	g.add_child(chair)
	_cyl(chair, Vector3(0, 0.03, 0), 0.28, 0.3, 0.06, METAL.darkened(0.2))
	_cyl(chair, Vector3(0, 0.25, 0), 0.05, 0.06, 0.4, METAL)
	_box(chair, Vector3(0, 0.5, 0), Vector3(0.55, 0.12, 0.52), Color("#E0455A"))
	_box(chair, Vector3(0, 0.88, 0.25), Vector3(0.52, 0.66, 0.1), Color("#E0455A"), Vector3(-8, 0, 0))
	_box(chair, Vector3(0, 1.26, 0.28), Vector3(0.3, 0.14, 0.08), Color("#C93A4E"))
	for sx: float in [-0.3, 0.3]:
		_box(chair, Vector3(sx, 0.68, -0.02), Vector3(0.07, 0.06, 0.48), METAL)
		_box(chair, Vector3(sx, 0.6, 0.18), Vector3(0.04, 0.16, 0.04), METAL)
	_box(chair, Vector3(0, 0.18, -0.42), Vector3(0.38, 0.03, 0.14), METAL)
	_solid(Vector3(5.95, 0.5, cz), Vector3(0.6, 1.0, 0.6))
	# Bulb-framed mirror on the east wall.
	var mirror: Node3D = Node3D.new()
	mirror.name = "StyleMirror"
	mirror.position = Vector3(W - 0.04, 1.55, cz)
	mirror.rotation_degrees.y = -90.0
	g.add_child(mirror)
	_box(mirror, Vector3.ZERO, Vector3(1.05, 1.2, 0.05), Color("#FF7EB6"))
	_box(mirror, Vector3(0, 0, 0.03), Vector3(0.88, 1.03, 0.02), Color("#8CC8E6"))
	_box(mirror, Vector3(-0.15, 0.1, 0.045), Vector3(0.06, 0.7, 0.005), CREAM, Vector3(0, 0, -30))
	_box(mirror, Vector3(0.0, 0.0, 0.045), Vector3(0.03, 0.5, 0.005), CREAM, Vector3(0, 0, -30))
	var bulb: SphereMesh = SphereMesh.new()
	bulb.radius = 0.035
	bulb.height = 0.07
	var bulb_mat: StandardMaterial3D = glow_material(Color("#FFF1C4"), 1.5)
	for i: int in 5:
		var t: float = (float(i) + 0.5) / 5.0
		_place(mirror, bulb, Vector3(lerpf(-0.45, 0.45, t), 0.6, 0.05), bulb_mat)
		_place(mirror, bulb, Vector3(-0.53, lerpf(-0.5, 0.5, t), 0.05), bulb_mat)
		_place(mirror, bulb, Vector3(0.53, lerpf(-0.5, 0.5, t), 0.05), bulb_mat)
	# Shelf of hair stuff below the mirror.
	_box(g, Vector3(W - 0.15, 0.92, cz), Vector3(0.26, 0.04, 1.0), CREAM)
	var bottles: Array[Color] = [Color("#FF7EB6"), Color("#4FC3F7"), Color("#FFD84D"), Color("#B79CFF"), Color("#2EC4B6")]
	for i: int in bottles.size():
		var h: float = 0.12 + 0.04 * float(i % 3)
		_cyl(g, Vector3(W - 0.15, 0.94 + h * 0.5, cz - 0.38 + float(i) * 0.18), 0.035, 0.035, h, bottles[i], Vector3.ZERO, 10)
		_cyl(g, Vector3(W - 0.15, 0.94 + h + 0.02, cz - 0.38 + float(i) * 0.18), 0.015, 0.015, 0.04, CREAM, Vector3.ZERO, 8)
	_box(g, Vector3(W - 0.12, 0.96, cz + 0.42), Vector3(0.04, 0.03, 0.2), INK, Vector3(0, 20, 0))
	_plaque(g, "STYLE BAR", Vector3(W - 0.04, 2.6, cz), -90.0, 1.3, Color("#FF7EB6"))
	# Small rug under the chair.
	_cyl(g, Vector3(5.85, 0.006, cz), 0.85, 0.85, 0.012, Color("#7C83FD"), Vector3.ZERO, 24)
	_cyl(g, Vector3(5.85, 0.01, cz), 0.6, 0.6, 0.012, Color("#B79CFF"), Vector3.ZERO, 24)


# --- lounge ----------------------------------------------------------------------------------------------------------

func _build_lounge() -> void:
	var g: Node3D = _group("Lounge")
	# Round rug.
	_cyl(g, Vector3(5.0, 0.006, 2.0), 1.6, 1.6, 0.012, Color("#E07A5F"), Vector3.ZERO, 32)
	_cyl(g, Vector3(5.0, 0.01, 2.0), 1.3, 1.3, 0.012, Color("#F2CC8F"), Vector3.ZERO, 32)
	_cyl(g, Vector3(5.0, 0.014, 2.0), 1.0, 1.0, 0.012, Color("#E07A5F"), Vector3.ZERO, 32)
	# Worn mustard couch against the east wall, facing -X.
	var couch: Node3D = Node3D.new()
	couch.name = "Couch"
	g.add_child(couch)
	var cz0: float = 0.5
	var cz1: float = 2.95
	var czc: float = (cz0 + cz1) * 0.5
	var fabric: Color = Color("#D9A441")
	# Low lounge seat (cushion top about 0.38, 0.55 deep) so a seated rider's knees clear the front edge with the
	# feet on the floor, and a thick backrest so a reclined back rests against it (ShopPoser._shop_sit).
	_box(couch, Vector3(6.525, 0.2, czc), Vector3(0.95, 0.2, cz1 - cz0), fabric.darkened(0.1))
	for k: int in 2:
		var zc: float = lerpf(cz0 + 0.2, cz1 - 0.2, (float(k) + 0.5) / 2.0)
		_box(couch, Vector3(6.425, 0.33, zc), Vector3(0.75, 0.1, (cz1 - cz0 - 0.4) * 0.5 - 0.02), fabric, Vector3(0, 0, -2))
		_box(couch, Vector3(6.8, 0.7, zc), Vector3(0.36, 0.62, (cz1 - cz0 - 0.4) * 0.5 - 0.02), fabric, Vector3(0, 0, 10))
	for z: float in [cz0 + 0.1, cz1 - 0.1]:
		_box(couch, Vector3(6.525, 0.46, z), Vector3(0.95, 0.32, 0.2), fabric.darkened(0.05))
		_ball(couch, Vector3(6.05, 0.62, z), 0.1, fabric.darkened(0.05), Vector3(1.0, 1.0, 1.0))
		_cyl(couch, Vector3(6.525, 0.62, z), 0.1, 0.1, 0.95, fabric.darkened(0.05), Vector3(0, 0, 90), 14)
	for x: float in [6.13, 6.92]:
		for z: float in [cz0 + 0.08, cz1 - 0.08]:
			_cyl(couch, Vector3(x, 0.05, z), 0.035, 0.025, 0.1, WOOD_DARK, Vector3.ZERO, 8)
	_box(couch, Vector3(6.35, 0.385, 1.95), Vector3(0.28, 0.01, 0.22), Color("#7FB3D5"), Vector3(0, 12, 0))  # patched cushion
	_box(couch, Vector3(6.35, 0.388, 1.95), Vector3(0.3, 0.005, 0.01), CREAM, Vector3(0, 12, 0))
	_ball(couch, Vector3(6.55, 0.6, cz1 - 0.38), 0.17, Color("#FF7EB6"), Vector3(0.5, 1.0, 1.0))
	_box(couch, Vector3(6.7, 0.55, cz0 + 0.5), Vector3(0.5, 0.05, 0.6), Color("#4FC3F7"), Vector3(0, 0, 40))  # throw blanket
	_solid(Vector3(6.525, 0.45, czc), Vector3(0.95, 0.9, cz1 - cz0))
	seats.clear()
	for z: float in SEAT_ZS:
		seats.append(Transform3D(Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP), Vector3(SEAT_X, 0.0, z)))
	# Coffee table with skate mags and a soda.
	var table: Node3D = Node3D.new()
	table.name = "CoffeeTable"
	g.add_child(table)
	var tc: Vector3 = Vector3(4.75, 0, 1.9)
	_box(table, tc + Vector3(0, 0.4, 0), Vector3(0.75, 0.05, 1.05), WOOD)
	for lx: float in [-0.3, 0.3]:
		for lz: float in [-0.45, 0.45]:
			_box(table, tc + Vector3(lx, 0.19, lz), Vector3(0.05, 0.38, 0.05), WOOD_DARK)
	var mags: Array[Color] = [Color("#FF5A5F"), Color("#FFD84D"), Color("#4FC3F7"), Color("#B79CFF")]
	for i: int in mags.size():
		_box(table, tc + Vector3(-0.08 + float(i % 2) * 0.12, 0.43 + float(i) * 0.008, -0.2 + float(i / 2) * 0.12), Vector3(0.22, 0.008, 0.3), mags[i], Vector3(0, -20.0 + float(i) * 17.0, 0))
	_label(table, "THRASH\nKIDS", tc + Vector3(0.04, 0.47, -0.08), 40, CREAM, INK, 0.0, 0.0018).rotation_degrees = Vector3(-90, 18, 0)
	_cyl(table, tc + Vector3(0.2, 0.48, 0.3), 0.033, 0.033, 0.12, Color("#E0455A"), Vector3.ZERO, 12)
	_cyl(table, tc + Vector3(0.2, 0.48, 0.3), 0.034, 0.034, 0.03, CREAM, Vector3.ZERO, 12)
	_cyl(table, tc + Vector3(-0.22, 0.45, 0.32), 0.05, 0.04, 0.05, CREAM, Vector3.ZERO, 12)
	_solid(tc + Vector3(0, 0.22, 0), Vector3(0.75, 0.44, 1.05))
	# Beanbag.
	_ball(g, Vector3(3.55, 0.27, 3.2), 0.55, Color("#FF7EB6"), Vector3(1.0, 0.55, 1.0))
	_ball(g, Vector3(3.62, 0.48, 3.42), 0.33, Color("#F06BA8"), Vector3(1.0, 0.75, 0.6))
	_solid(Vector3(3.55, 0.3, 3.2), Vector3(0.95, 0.6, 0.95))
	# TV on a cabinet in the corner, angled toward the couch and beanbag, playing a skate clip.
	var tv: Node3D = Node3D.new()
	tv.name = "TV"
	tv.position = Vector3(6.2, 0, 4.35)
	tv.rotation_degrees.y = 30.0
	g.add_child(tv)
	_box(tv, Vector3(0, 0.25, 0), Vector3(1.2, 0.5, 0.48), WOOD_DARK)
	_box(tv, Vector3(0, 0.25, -0.245), Vector3(1.1, 0.4, 0.01), WOOD)
	_box(tv, Vector3(0.3, 0.12, -0.25), Vector3(0.3, 0.06, 0.02), INK)
	_box(tv, Vector3(-0.32, 0.56, 0.0), Vector3(0.36, 0.08, 0.26), CREAM)  # console
	_box(tv, Vector3(0, 0.84, 0.02), Vector3(0.86, 0.66, 0.5), Color("#3A3F58"))
	_box(tv, Vector3(0, 0.84, -0.235), Vector3(0.8, 0.6, 0.03), INK)
	var scr: QuadMesh = QuadMesh.new()
	scr.size = Vector2(0.68, 0.5)
	var tvm: ShaderMaterial = ShaderMaterial.new()
	tvm.shader = load("res://game/shop/tv_screen.gdshader") as Shader
	tvm.set_shader_parameter("aspect", 0.68 / 0.5)
	tv_screen = _place(tv, scr, Vector3(0, 0.85, -0.255), tvm, Vector3(0, 180, 0))
	tv_screen.name = "Screen"
	for s: float in [-1.0, 1.0]:
		_cyl(tv, Vector3(s * 0.12, 1.32, 0.08), 0.006, 0.006, 0.4, METAL, Vector3(0, 0, -s * 25.0), 6)
	_solid(Vector3(6.2, 0.6, 4.35), Vector3(1.2, 1.2, 0.6), 30.0)
	var tv_light: OmniLight3D = OmniLight3D.new()
	tv_light.light_color = Color("#9FC7FF")
	tv_light.light_energy = 0.6
	tv_light.omni_range = 2.6
	tv_light.position = tv.position + Vector3(-0.4, 0.9, -0.6)
	g.add_child(tv_light)
	# Mini fridge by the couch.
	var fridge: Node3D = Node3D.new()
	fridge.name = "MiniFridge"
	fridge.position = Vector3(6.62, 0, 0.0)
	fridge.rotation_degrees.y = 90.0
	g.add_child(fridge)
	_box(fridge, Vector3(0, 0.43, 0), Vector3(0.55, 0.86, 0.55), Color("#DDF3EE"))
	_box(fridge, Vector3(0, 0.43, -0.28), Vector3(0.52, 0.82, 0.01), Color("#C9E8E1"))
	_box(fridge, Vector3(0.2, 0.55, -0.3), Vector3(0.03, 0.25, 0.03), METAL)
	for i: int in 4:
		_box(fridge, Vector3(-0.15 + float(i % 2) * 0.16, 0.3 + float(i / 2) * 0.2, -0.29), Vector3(0.1, 0.07, 0.005), DECK_COLORS[i * 2], Vector3(0, 0, -15.0 + float(i) * 11.0))
	_cyl(fridge, Vector3(0.1, 0.92, 0), 0.033, 0.033, 0.12, Color("#4FC3F7"), Vector3.ZERO, 12)
	_solid(Vector3(6.62, 0.43, 0.0), Vector3(0.55, 0.86, 0.55))
	_plaque(g, "CHILL ZONE", Vector3(W - 0.04, 3.0, 1.7), -90.0, 1.4, Color("#FF9F1C"))


# --- decor -------------------------------------------------------------------------------------------------------------

func _build_decor() -> void:
	var g: Node3D = _group("Decor")
	_poster(g, 0, Vector3(W - 0.03, 2.05, 1.05), -90.0, Vector2(0.75, 1.05), "SUNSET SESH", CREAM)
	_poster(g, 2, Vector3(W - 0.03, 2.05, 2.35), -90.0, Vector2(0.75, 1.05), "SKATE + SMILE", Color("#FFD84D"))
	_poster(g, 1, Vector3(5.95, 2.1, -D + 0.03), 0.0, Vector2(0.8, 1.1), "KICKFLIP FEST", CREAM)
	_poster(g, 3, Vector3(-1.8, 2.75, -3.48), 0.0, Vector2(1.2, 0.6), "", CREAM)
	_poster(g, 0, Vector3(-W + 0.03, 2.75, 3.95), 90.0, Vector2(0.62, 0.86), "RIDE IT", CREAM)
	_poster(g, 2, Vector3(4.4, 2.1, -D + 0.03), 0.0, Vector2(0.7, 0.95), "", CREAM)
	_poster(g, 1, Vector3(-1.2, 1.7, D - 0.03), 180.0, Vector2(0.55, 0.8), "", CREAM)
	_plant(g, Vector3(-1.3, 0, 4.5), 0.85)
	_plant(g, Vector3(1.0 - 0.05, 0, 4.35) + Vector3(-0.0, 0, 0.15), 0.7)
	_plant(g, Vector3(4.55, 0, -4.55), 1.0)
	_plant(g, Vector3(-0.3, 0, -4.55), 0.8)
	# Hanging planter by the window.
	_cyl(g, Vector3(-3.2, 2.75, 4.4), 0.004, 0.004, 0.7, INK, Vector3.ZERO, 4)
	_cyl(g, Vector3(-3.2, 2.35, 4.4), 0.16, 0.12, 0.18, CREAM)
	for i: int in 5:
		var a: float = float(i) * TAU / 5.0
		_ball(g, Vector3(-3.2 + cos(a) * 0.15, 2.3 - 0.1 * float(i % 2), 4.4 + sin(a) * 0.15), 0.09, LEAF_LIGHT, Vector3(1.0, 1.6, 1.0))
	# "OPEN" neon in the east window, readable from inside, and a small "SKATE / SURF" neon over the door.
	var open_sign: Label3D = _label(g, "OPEN", Vector3(3.15, 2.05, D - 0.08), 110, Color(1.8, 0.55, 1.1), Color(1.0, 0.25, 0.55), 180.0, 0.0035)
	open_sign.outline_size = 18
	var surf_sign: Label3D = _label(g, "SKATE  •  SURF  •  CHILL", Vector3(0, 2.85, D - 0.06), 72, Color(0.6, 1.9, 1.8), Color(0.15, 0.85, 0.9), 180.0, 0.0035)
	surf_sign.outline_size = 14
	surf_sign.no_depth_test = false
	# Glow: a soft teal halo quad behind the lettering plus a tube light, so it reads as neon, not flat text.
	var halo: QuadMesh = QuadMesh.new()
	halo.size = Vector2(3.4, 0.5)
	var halo_mat: StandardMaterial3D = StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color = Color(0.2, 0.95, 0.95, 0.5)
	halo_mat.albedo_texture = _halo_texture()
	halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_place(g, halo, Vector3(0, 2.85, D - 0.045), halo_mat, Vector3(0, 180, 0))
	var sign_light: OmniLight3D = OmniLight3D.new()
	sign_light.position = Vector3(0, 2.8, D - 0.5)
	sign_light.light_color = Color("#52F0E6")
	sign_light.light_energy = 0.35
	sign_light.omni_range = 2.2
	g.add_child(sign_light)
	# String lights over the lounge.
	var bulb: SphereMesh = SphereMesh.new()
	bulb.radius = 0.04
	bulb.height = 0.08
	var colors: Array[Color] = [Color("#FFD84D"), Color("#FF7EB6"), Color("#52F0E6"), Color("#FFB04D")]
	for i: int in 22:
		var t: float = float(i) / 21.0
		var p: Vector3 = Vector3(W - 0.15, 3.05 - 0.35 * sin(t * PI * 2.0) * sin(t * PI * 2.0), lerpf(-0.2, 4.6, t))
		_place(g, bulb, p, glow_material(colors[i % colors.size()], 1.6))


static func _halo_texture() -> Texture2D:
	var gt: GradientTexture2D = GradientTexture2D.new()
	var gr: Gradient = Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 32
	return gt


func _build_lights() -> void:
	var g: Node3D = _group("Lights")
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.rotation_degrees = Vector3(-62.0, 25.0, 0.0)
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 25.0
	g.add_child(sun)
	var pendants: Array[Vector3] = [Vector3(-4.6, 0, -2.6), Vector3(-3.5, 0, 0.8), Vector3(-0.2, 0, 1.4),
			Vector3(2.0, 0, -2.4), Vector3(4.9, 0, 1.9), Vector3(5.4, 0, -1.3), Vector3(-1.8, 0, -2.2)]
	var shade_mat: Color = Color("#2EC4B6")
	for i: int in pendants.size():
		var p: Vector3 = pendants[i]
		var cord: float = 0.7 + 0.15 * float(i % 2)
		var y: float = H - cord
		_cyl(g, Vector3(p.x, H - cord * 0.5, p.z), 0.006, 0.006, cord, INK, Vector3.ZERO, 4)
		_cyl(g, Vector3(p.x, y - 0.1, p.z), 0.06, 0.24, 0.22, shade_mat if i % 2 == 0 else Color("#FFB04D"))
		var bulb: SphereMesh = SphereMesh.new()
		bulb.radius = 0.06
		bulb.height = 0.12
		_place(g, bulb, Vector3(p.x, y - 0.22, p.z), glow_material(Color("#FFE7B0"), 1.8))
		var l: OmniLight3D = OmniLight3D.new()
		l.position = Vector3(p.x, y - 0.4, p.z)
		l.light_color = Color("#FFC98A")
		l.light_energy = 0.28
		l.omni_range = 3.6
		l.omni_attenuation = 1.2
		g.add_child(l)
	var neon: OmniLight3D = OmniLight3D.new()
	neon.position = Vector3(2.05, 2.6, -D + 0.6)
	neon.light_color = NEON_PINK
	neon.light_energy = 0.8
	neon.omni_range = 3.0
	g.add_child(neon)


func _define_stations() -> void:
	stations = [
		ShopStation.make("boards", "trick out your board", "shop", "decks", Vector3(-5.2, 0, -3.45), 1.4),
		ShopStation.make("shoes", "shop for kicks", "shop", "shoes", Vector3(-6.1, 0, 0.0), 1.0),
		ShopStation.make("clothes", "browse the threads", "shop", "clothing", Vector3(-3.4, 0, 0.8), 1.15),
		ShopStation.make("dressing", "try on outfits", "creator", "1", Vector3(-1.8, 0, -2.85), 1.05),
		ShopStation.make("style", "change your look", "creator", "0", Vector3(5.0, 0, -1.15), 1.1),
		ShopStation.make("couch", "chill on the couch", "sit", "", Vector3(5.45, 0, 0.6), 1.0),
		ShopStation.make("door", "hit the park", "exit", "", Vector3(0, 0, 4.15), 0.75),
	]
	npc_spots = {
		"keeper": Transform3D(Basis.looking_at(Vector3(0, 0, 1), Vector3.UP), Vector3(2.05, 0, -4.32)),
		"deckwall": Transform3D(Basis.looking_at(Vector3(-0.3, 0, -1), Vector3.UP), Vector3(-3.7, 0, -3.5)),
		"racks": Transform3D(Basis.looking_at(Vector3(1, 0, 0.4), Vector3.UP), Vector3(-2.0, 0, 3.0)),
		"couch": seats[1],
		"ramp": Transform3D(Basis.looking_at(Vector3(-1, 0, 0.35), Vector3.UP), Vector3(6.5, 1.2, -3.2)),
	}
	spawn = Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), Vector3(0, 0.05, 3.2))
	sit_camera = Transform3D(Basis.IDENTITY, Vector3(3.3, 1.55, -0.2)).looking_at(Vector3(6.1, 0.75, 1.6), Vector3.UP)
