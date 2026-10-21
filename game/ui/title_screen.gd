extends Control
## Title screen. Behind the UI, a SubViewport shows a slowly orbiting camera around the placeholder skater on
## its board, with a quarter pipe behind on a ground plane. In front: a bobbing multicolour "SKATE PARK" title,
## a subtitle and three buttons. Play loads the park, Controls opens ControlsScreen (if it exists), Quit quits.

const GAME_SCENE: String = "res://game/main.tscn"
const CONTROLS_SCRIPT: String = "res://game/ui/controls_screen.gd"
const CREATOR_SCRIPT: String = "res://game/ui/character_creator.gd"
const SHOP_SCRIPT: String = "res://game/ui/skate_shop.gd"
const SHOP_SCENE: String = "res://game/shop/shop.tscn"  ## the walk-in shop
const TITLE: String = "SKATE PARK"
const SUBTITLE: String = "Shred. Grind. Have fun!"
const TITLE_COLORS: PackedColorArray = [
	SkateThemeBuilder.CORAL, SkateThemeBuilder.SUN, SkateThemeBuilder.CREAM, SkateThemeBuilder.TEAL,
	SkateThemeBuilder.SUN, SkateThemeBuilder.CORAL, SkateThemeBuilder.CREAM,
]
const TITLE_FONT_SIZE: int = 150
const BOB_AMPLITUDE: float = 14.0
const BOB_SPEED: float = 3.0
const BOB_PHASE: float = 0.55
const ORBIT_RADIUS: float = 4.2
const ORBIT_HEIGHT: float = 1.5
const ORBIT_SPEED: float = 0.3  # phase rad/s; the camera sways, see ORBIT_SWAY
const ORBIT_SWAY: float = 0.4  # max camera angle either side of the front, rad (keeps the quarter pipe in frame)
const SKATER_YAW: float = -2.2  ## turned three-quarter toward the camera so her face shows
const LOOK_AT: Vector3 = Vector3(0.0, 1.25, 0.0)
const GROUND_COLOR: Color = Color("#B4627F")  ## dusky sunset rose, hazed into the horizon by the fog
const LETTER_TIGHTEN: float = 0.66  ## letter advance as a share of its box, the boxes carry outline padding

@onready var _viewport: SubViewport = $World/Viewport
@onready var _title_row: Control = $Ui/TitleRow
@onready var _subtitle: Label = $Ui/Subtitle
@onready var _menu: VBoxContainer = $Ui/Menu
@onready var _play: Button = $Ui/Menu/Play
@onready var _create: Button = $Ui/Menu/Create
@onready var _shop: Button = $Ui/Menu/Shop
@onready var _visit: Button = $Ui/Menu/Visit
@onready var _controls: Button = $Ui/Menu/Controls
@onready var _quit: Button = $Ui/Menu/Quit

var _camera: Camera3D
var _orbit: float = 0.0
var _time: float = 0.0
var _letters: Array[AnimeText] = []
var _letter_base_y: float = 0.0
var _overlay: Control = null
var _overlay_button: Button = null
var _skater_node: Node3D = null
var _leaving: bool = false


func _ready() -> void:
	_build_world(_viewport)
	_build_title()
	var deco: SkyBackdrop = SkyBackdrop.new(true)
	$Ui.add_child(deco)
	$Ui.move_child(deco, 0)
	_subtitle.theme_type_variation = SkateThemeBuilder.LBL_RIBBON
	_subtitle.anchor_left = 0.5
	_subtitle.anchor_right = 0.5
	_subtitle.offset_left = -330.0
	_subtitle.offset_right = 330.0
	_subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_play.theme_type_variation = SkateThemeBuilder.BTN_MINT
	_create.theme_type_variation = SkateThemeBuilder.BTN_TEAL
	_shop.theme_type_variation = SkateThemeBuilder.BTN_SUN
	_visit.theme_type_variation = SkateThemeBuilder.BTN_NAVY
	_controls.theme_type_variation = SkateThemeBuilder.BTN_CREAM
	_quit.theme_type_variation = SkateThemeBuilder.BTN_CORAL
	_play.pressed.connect(_on_play)
	_create.pressed.connect(_open_overlay.bind(CREATOR_SCRIPT, _create))
	_shop.pressed.connect(_open_overlay.bind(SHOP_SCRIPT, _shop))
	_visit.pressed.connect(_on_visit_shop)
	_controls.pressed.connect(_on_controls)
	_quit.pressed.connect(_on_quit)
	_play.grab_focus()
	# Cross-fade in from the splash's closing fade (same navy), so there is no hard cut.
	var veil := ColorRect.new()
	veil.color = Color(SkateThemeBuilder.NAVY, 1.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	create_tween().tween_property(veil, "color:a", 0.0, 0.45)
	get_tree().create_timer(0.5).timeout.connect(veil.queue_free)


func _process(delta: float) -> void:
	_time += delta
	_orbit += ORBIT_SPEED * delta
	_update_camera()
	for i: int in _letters.size():
		var bob: float = sin(_time * BOB_SPEED + float(i) * BOB_PHASE) * BOB_AMPLITUDE
		_letters[i].position.y = _letter_base_y + bob


## The 3D backdrop: toon sky, sun, ground, a quarter pipe behind and the placeholder skater on a board.
func _build_world(vp: SubViewport) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24.0, 150.0, 0.0)  # low warm key from the sunset side
	sun.light_color = Color(1.0, 0.86, 0.72)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var world_env := WorldEnvironment.new()
	world_env.environment = Toon.park_sky_environment(sun.global_transform.basis.z)
	world_env.environment.fog_enabled = true
	world_env.environment.fog_density = 0.012
	world_env.environment.fog_light_color = Color("#FFB58A")
	vp.add_child(world_env)
	var rim := DirectionalLight3D.new()  # cool rim from behind the skater so her outline pops off the warm ground
	rim.rotation_degrees = Vector3(-18.0, -35.0, 0.0)
	rim.light_color = Color(0.55, 0.9, 1.0)
	rim.light_energy = 0.8
	vp.add_child(rim)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	ground.mesh = plane
	ground.material_override = Toon.material(GROUND_COLOR, false)
	ground.material_overlay = _overlay_material(GROUND_SHADER)
	vp.add_child(ground)

	var ramp: Node3D = QuarterPipe.build()
	ramp.position = Vector3(-4.0, 0.0, -14.0)
	vp.add_child(ramp)
	_ground_ramp(ramp)

	_build_skater(vp)

	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.05
	vp.add_child(_camera)
	_update_camera()


## The player's saved skater (the default look in scripted runs), posed on its board.
func _build_skater(vp: SubViewport) -> void:
	if _skater_node != null:
		_skater_node.queue_free()
	var skater := Node3D.new()
	skater.name = "Skater"
	var board: Node3D
	var body: Node3D
	if Flags.is_scripted_run():
		board = PlaceholderSkater.build_board()
		body = PlaceholderSkater.build_body()
	else:
		var loadout: SkaterLoadout = SkaterLoadout.load_file()
		board = SkaterBuilder.build_board(loadout)
		body = SkaterBuilder.build_body(loadout)
	skater.add_child(board)
	body.position.y = PlaceholderSkater.DECK_TOP_Y
	skater.add_child(body)
	Toon.apply_to(skater)
	var poser := SkaterPoser.new()
	poser.body = body
	poser.board = board
	poser.preview_anim = "crouch"
	skater.add_child(poser)
	var sway := SecondaryMotion.new()
	skater.add_child(sway)
	sway.bind(skater)
	skater.rotation.y = SKATER_YAW
	skater.add_child(_blob_shadow())
	vp.add_child(skater)
	_skater_node = skater


const GROUND_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, fog_disabled;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// A faint ground gradient: a deeper plum band in the mid-ground that eases back out toward the horizon haze.
	float d = length(wp.xz - vec2(0.0, -4.0));
	float band = smoothstep(4.0, 13.0, d) * (1.0 - smoothstep(20.0, 52.0, d));
	ALBEDO = vec3(0.50, 0.17, 0.42);
	ALPHA = 0.34 * band;
}
"""
const RAMP_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, fog_disabled;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// Darker where the ramp meets the ground, fading out over the first ~1.8 m of height.
	float k = 1.0 - smoothstep(0.0, 1.8, wp.y);
	ALBEDO = vec3(0.30, 0.10, 0.20);
	ALPHA = 0.55 * k * k + 0.10 * k;
}
"""
const BLOB_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	ALBEDO = vec3(0.30, 0.08, 0.22);
	ALPHA = 0.62 * (1.0 - smoothstep(0.25, 1.0, r));
}
"""


func _overlay_material(code: String) -> ShaderMaterial:
	var sh: Shader = Shader.new()
	sh.code = code
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	return m


## A soft contact shadow lying on the ground under the skater (ellipse along the board).
func _blob_shadow() -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.05, 1.9)
	quad.orientation = PlaneMesh.FACE_Y
	var blob: MeshInstance3D = MeshInstance3D.new()
	blob.name = "BlobShadow"
	blob.mesh = quad
	blob.position = Vector3(0.0, 0.012, 0.0)
	blob.material_override = _overlay_material(BLOB_SHADER)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return blob


## Grounds the quarter pipe: a darker contact band up its lower face, plus a soft shadow strip on the ground along
## its foot.
func _ground_ramp(ramp: Node3D) -> void:
	var body: Node = ramp.get_node_or_null("Ramp/Mesh")
	if body is MeshInstance3D:
		(body as MeshInstance3D).material_overlay = _overlay_material(RAMP_SHADER)
	var strip: QuadMesh = QuadMesh.new()
	strip.size = Vector2(8.6, 2.4)
	strip.orientation = PlaneMesh.FACE_Y
	var m: MeshInstance3D = MeshInstance3D.new()
	m.name = "RampContactShadow"
	m.mesh = strip
	m.position = Vector3(4.0, 0.015, 4.5 + 0.9)  # in front of the foot of the transition (z = deck + radius)
	var sh: Shader = Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;
void fragment() {
	// UV.y runs 0 (far, at the ramp) to 1 (near): dark at the foot, fading out; soft at the two ends.
	float along = 1.0 - smoothstep(0.0, 0.85, UV.y);
	float ends = smoothstep(0.0, 0.05, UV.x) * (1.0 - smoothstep(0.95, 1.0, UV.x));
	ALBEDO = vec3(0.30, 0.08, 0.22);
	ALPHA = 0.5 * along * along * ends;
}
"""
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ramp.add_child(m)


func _update_camera() -> void:
	var angle: float = sin(_orbit) * ORBIT_SWAY
	_camera.position = Vector3(sin(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, cos(angle) * ORBIT_RADIUS)
	_camera.look_at(LOOK_AT, Vector3.UP)


## One label per character (spaces included, for the gap) so each letter takes its own colour and bobs on its own.
func _build_title() -> void:
	for i: int in TITLE.length():
		var letter: AnimeText = AnimeText.new(TITLE.substr(i, 1), TITLE_FONT_SIZE, TITLE_COLORS[i % TITLE_COLORS.size()])
		letter.impact_lines = false
		letter.tilt_degrees = -3.0 if i % 2 == 0 else 2.0
		letter.rotation_degrees = letter.tilt_degrees
		_title_row.add_child(letter)
		_letters.append(letter)
	_title_row.resized.connect(_layout_title)
	_layout_title()


## Centres the letters across the title row and records their resting height.
func _layout_title() -> void:
	var total: float = 0.0
	var sizes: Array[Vector2] = []
	for letter: AnimeText in _letters:
		var s: Vector2 = letter.get_combined_minimum_size()
		sizes.append(s)
		total += s.x * LETTER_TIGHTEN
	var x: float = (_title_row.size.x - total) * 0.5
	var max_h: float = 0.0
	for i: int in _letters.size():
		_letters[i].size = sizes[i]
		_letters[i].position.x = x
		x += sizes[i].x * LETTER_TIGHTEN
		max_h = maxf(max_h, sizes[i].y)
	_letter_base_y = (_title_row.size.y - max_h) * 0.5


func _on_play() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(GAME_SCENE)


## Walks into the 3D skate shop (game/shop/shop.tscn).
func _on_visit_shop() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(SHOP_SCENE)


func _on_controls() -> void:
	if _overlay != null or not ResourceLoader.exists(CONTROLS_SCRIPT):
		return
	var controls_script: Script = load(CONTROLS_SCRIPT) as Script
	if controls_script == null:
		return
	var screen: Control = controls_script.new() as Control
	if screen == null:
		return
	if screen.has_signal(&"closed"):
		screen.connect(&"closed", _on_controls_closed)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	_overlay = screen
	_menu.visible = false


func _on_controls_closed() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_menu.visible = true
	_controls.grab_focus()


## Opens the character creator or the skate shop over the menu; both emit `closed` when done.
func _open_overlay(script_path: String, from: Button) -> void:
	if _overlay != null or not ResourceLoader.exists(script_path):
		return
	var script: Script = load(script_path) as Script
	var screen: Control = script.new() as Control if script != null else null
	if screen == null:
		return
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.connect(&"closed", _on_screen_closed)
	add_child(screen)
	_overlay = screen
	_overlay_button = from
	_menu.visible = false


func _on_screen_closed() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_menu.visible = true
	_build_skater(_viewport)
	if _overlay_button != null:
		_overlay_button.grab_focus()


func _on_quit() -> void:
	get_tree().quit()
