extends Control
## Title screen. Behind the UI, a SubViewport shows a slowly orbiting camera around the placeholder skater on
## its board, with a quarter pipe behind on a ground plane. In front: a bobbing multicolour "SKATE PARK" title,
## a subtitle and three buttons. Play loads the park, Controls opens ControlsScreen (if it exists), Quit quits.

const GAME_SCENE: String = "res://game/main.tscn"
const CONTROLS_SCRIPT: String = "res://game/ui/controls_screen.gd"
const TITLE: String = "SKATE PARK"
const SUBTITLE: String = "Shred. Grind. Have fun!"
const TITLE_COLORS: PackedColorArray = [
	Color("#FF5A5F"), Color("#FF9F1C"), Color("#FFD84D"), Color("#A6E22E"), Color("#4FC3F7"),
	Color("#7C83FD"), Color("#FF7EB6"),
]
const TITLE_FONT_SIZE: int = 144
const BOB_AMPLITUDE: float = 14.0
const BOB_SPEED: float = 3.0
const BOB_PHASE: float = 0.55
const ORBIT_RADIUS: float = 4.2
const ORBIT_HEIGHT: float = 1.5
const ORBIT_SPEED: float = 0.3  # phase rad/s; the camera sways, see ORBIT_SWAY
const ORBIT_SWAY: float = 0.6  # max camera angle either side of the front, rad (keeps the quarter pipe in frame)
const LOOK_AT: Vector3 = Vector3(0.0, 1.05, 0.0)
const GROUND_COLOR: Color = Color("#7BC96F")
const BUTTON_RADIUS: int = 18
const BUTTON_FONT_SIZE: int = 48

@onready var _viewport: SubViewport = $World/Viewport
@onready var _title_row: Control = $Ui/TitleRow
@onready var _subtitle: Label = $Ui/Subtitle
@onready var _menu: VBoxContainer = $Ui/Menu
@onready var _play: Button = $Ui/Menu/Play
@onready var _controls: Button = $Ui/Menu/Controls
@onready var _quit: Button = $Ui/Menu/Quit

var _camera: Camera3D
var _orbit: float = 0.0
var _time: float = 0.0
var _letters: Array[Label] = []
var _letter_base_y: float = 0.0
var _overlay: Control = null
var _leaving: bool = false


func _ready() -> void:
	_build_world(_viewport)
	_build_title()
	var subtitle_label: Label = UiStyle.label(SUBTITLE, UiStyle.SIZE_BODY, UiStyle.WHITE)
	_subtitle.label_settings = subtitle_label.label_settings
	subtitle_label.free()
	_style_button(_play, UiStyle.LIME)
	_style_button(_controls, UiStyle.SUNSHINE)
	_style_button(_quit, UiStyle.BUBBLEGUM)
	_play.pressed.connect(_on_play)
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

	var skater := Node3D.new()
	skater.name = "Skater"
	skater.add_child(PlaceholderSkater.build_board())
	var body: Node3D = PlaceholderSkater.build_body()
	body.position.y = PlaceholderSkater.DECK_TOP_Y
	body.rotation.y = PI * 0.5
	skater.add_child(body)
	Toon.apply_to(skater)
	vp.add_child(skater)

	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.05
	vp.add_child(_camera)
	_update_camera()


func _update_camera() -> void:
	var angle: float = sin(_orbit) * ORBIT_SWAY
	_camera.position = Vector3(sin(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, cos(angle) * ORBIT_RADIUS)
	_camera.look_at(LOOK_AT, Vector3.UP)


## One label per character (spaces included, for the gap) so each letter takes its own colour and bobs on its own.
func _build_title() -> void:
	for i: int in TITLE.length():
		var letter: Label = UiStyle.label(TITLE.substr(i, 1), TITLE_FONT_SIZE, TITLE_COLORS[i % TITLE_COLORS.size()])
		letter.label_settings.outline_size = 16
		_title_row.add_child(letter)
		_letters.append(letter)
	_title_row.resized.connect(_layout_title)
	_layout_title()


## Centres the letters across the title row and records their resting height.
func _layout_title() -> void:
	var total: float = 0.0
	var sizes: Array[Vector2] = []
	for letter: Label in _letters:
		var s: Vector2 = letter.get_minimum_size()
		sizes.append(s)
		total += s.x
	var x: float = (_title_row.size.x - total) * 0.5
	var max_h: float = 0.0
	for i: int in _letters.size():
		_letters[i].size = sizes[i]
		_letters[i].position.x = x
		x += sizes[i].x
		max_h = maxf(max_h, sizes[i].y)
	_letter_base_y = (_title_row.size.y - max_h) * 0.5


func _style_button(button: Button, color: Color) -> void:
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", UiStyle.INK)
	button.add_theme_color_override("font_hover_color", UiStyle.INK)
	button.add_theme_color_override("font_pressed_color", UiStyle.INK)
	button.add_theme_color_override("font_focus_color", UiStyle.INK)
	button.add_theme_stylebox_override("normal", _button_box(color))
	button.add_theme_stylebox_override("hover", _button_box(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _button_box(color.darkened(0.12)))
	var focus: StyleBoxFlat = _button_box(color.lightened(0.2))
	focus.border_color = UiStyle.WHITE
	focus.set_border_width_all(6)
	button.add_theme_stylebox_override("focus", focus)


func _button_box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = UiStyle.panel_style(color)
	box.set_corner_radius_all(BUTTON_RADIUS)
	box.set_content_margin_all(10)
	return box


func _on_play() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(GAME_SCENE)


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


func _on_quit() -> void:
	get_tree().quit()
