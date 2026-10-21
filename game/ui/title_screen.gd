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
const ORBIT_SWAY: float = 0.6  # max camera angle either side of the front, rad (keeps the quarter pipe in frame)
const LOOK_AT: Vector3 = Vector3(0.0, 1.05, 0.0)
const GROUND_COLOR: Color = Color("#7BC96F")
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


func _process(delta: float) -> void:
	_time += delta
	_orbit += ORBIT_SPEED * delta
	_update_camera()
	for i: int in _letters.size():
		var bob: float = sin(_time * BOB_SPEED + float(i) * BOB_PHASE) * BOB_AMPLITUDE
		_letters[i].position.y = _letter_base_y + bob


## The 3D backdrop: toon sky, sun, ground, a quarter pipe behind and the placeholder skater on a board.
func _build_world(vp: SubViewport) -> void:
	var world_env := WorldEnvironment.new()
	world_env.environment = Toon.sky_environment()
	vp.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = true
	vp.add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	ground.mesh = plane
	ground.material_override = Toon.material(GROUND_COLOR, false)
	vp.add_child(ground)

	var ramp: Node3D = QuarterPipe.build()
	ramp.position = Vector3(-4.0, 0.0, -14.0)
	vp.add_child(ramp)

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
	vp.add_child(skater)
	_skater_node = skater


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
