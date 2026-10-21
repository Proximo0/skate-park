class_name SkaterPreview
extends SubViewportContainer
## A 3D turntable for menus. show_skater() stands the whole skater on it, show_board() shows just the board.
## Turn it with the right stick, Z / X, or by dragging with the mouse; it drifts slowly when left alone.

const STICK_SPIN: float = 3.2
const IDLE_BEFORE_AUTO: float = 1.5
const PLATFORM_BASE := Color("#3A3470")
const PLATFORM_TILE_A := Color("#6E64A8")
const PLATFORM_TILE_B := Color("#3F8C9C")
const PLATFORM_RIM := Color("#35E0D0")
const BACKDROP_SHADER: Shader = preload("res://game/ui/theme/preview_backdrop.gdshader")

## Camera / motion presets. "face" is a head-and-shoulders bust with a gentle sway, "body" the whole skater on a slow
## turntable, "top" the board seen from above on a slow swing, "grip" a close top-down look at the griptape and
## "display" the board stood up with the deck graphic, trucks and wheels facing the camera.
const VIEWS := {
	"face": {"fov": 30.0, "cam": Vector3(0.0, 1.5, 2.05), "at": Vector3(0.0, 1.36, 0.0), "base": PI + 0.5, "sway": 0.3, "spin": 0.0},
	"body": {"fov": 34.0, "cam": Vector3(0.0, 1.2, 3.5), "at": Vector3(0.0, 0.72, 0.0), "base": PI, "sway": 0.0, "spin": 0.5},
	"top": {"fov": 30.0, "cam": Vector3(0.0, 0.62, 1.25), "at": Vector3(0.0, 0.08, 0.0), "base": 0.9, "sway": 0.55, "spin": 0.0},
	"grip": {"fov": 32.0, "cam": Vector3(0.0, 0.75, 1.0), "at": Vector3(0.0, 0.1, 0.0), "base": 0.6, "sway": 0.25, "spin": 0.0},
	"trucks": {"fov": 34.0, "cam": Vector3(0.0, 0.1, 0.8), "at": Vector3(0.0, 0.38, 0.0), "base": 0.45, "sway": 0.25, "spin": 0.0},
	"wheels": {"fov": 30.0, "cam": Vector3(0.0, 0.12, 0.62), "at": Vector3(-0.05, 0.36, 0.0), "base": 0.45, "sway": 0.25, "spin": 0.0},
	"feet": {"fov": 30.0, "cam": Vector3(0.0, 0.5, 1.35), "at": Vector3(0.0, 0.2, 0.0), "base": PI, "sway": 0.25, "spin": 0.0},
	"display": {"fov": 34.0, "cam": Vector3(0.0, 0.5, 2.0), "at": Vector3(0.0, 0.42, 0.0), "base": 0.0, "sway": 0.5, "spin": 0.0},
}

var _vp: SubViewport
var _pivot: Node3D
var _holder: Node3D
var _platform: Node3D
var _cam: Camera3D
var _loadout: SkaterLoadout = null
var _board_only: bool = false
var _view: String = "body"
var _dirty: bool = false
var _idle: float = 0.0
var _dragging: bool = false
var _user_yaw: float = 0.0
var _spin_yaw: float = 0.0
var _time: float = 0.0


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = _environment()
	_vp.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.shadow_enabled = true
	_vp.add_child(sun)
	var rim: DirectionalLight3D = DirectionalLight3D.new()  # warm-cool rim from behind
	rim.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
	rim.light_color = Color(0.55, 0.9, 1.0)
	rim.light_energy = 0.7
	_vp.add_child(rim)
	_pivot = Node3D.new()
	_pivot.name = "Turntable"
	_pivot.rotation.y = PI
	_vp.add_child(_pivot)
	_build_platform()
	_holder = Node3D.new()
	_pivot.add_child(_holder)
	_cam = Camera3D.new()
	_cam.near = 0.05
	_vp.add_child(_cam)
	var back: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(60.0, 40.0)
	back.mesh = quad
	back.position = Vector3(0.0, 0.0, -12.0)
	back.custom_aabb = AABB(Vector3(-100, -100, -100), Vector3(200, 200, 200))
	var bm: ShaderMaterial = ShaderMaterial.new()
	bm.shader = BACKDROP_SHADER
	back.material_override = bm
	_cam.add_child(back)
	_frame_camera()


func _environment() -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#B8456F")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.93, 0.9)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	return env


func _build_platform() -> void:
	_platform = Node3D.new()
	_pivot.add_child(_platform)
	var disc: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.88
	cyl.bottom_radius = 0.92
	cyl.height = 0.08
	disc.mesh = cyl
	disc.position.y = -0.04
	disc.material_override = Toon.material(PLATFORM_BASE, false)
	_platform.add_child(disc)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var rm: TorusMesh = TorusMesh.new()
	rm.inner_radius = 0.86
	rm.outer_radius = 0.93
	rm.rings = 48
	rm.ring_segments = 6
	ring.mesh = rm
	ring.scale = Vector3(1.0, 0.4, 1.0)
	ring.position.y = -0.01
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = PLATFORM_RIM
	glow.emission_enabled = true
	glow.emission = PLATFORM_RIM
	glow.emission_energy_multiplier = 1.4
	ring.material_override = glow
	_platform.add_child(ring)
	# Raised tiles with a gap between them so the floor reads as a stage, not one flat disc.
	var tile: BoxMesh = BoxMesh.new()
	tile.size = Vector3(0.2, 0.012, 0.2)
	var n: int = 4
	for ix: int in range(-n, n + 1):
		for iz: int in range(-n, n + 1):
			var pos: Vector3 = Vector3(float(ix) * 0.225, 0.0, float(iz) * 0.225)
			if Vector2(pos.x, pos.z).length() > 0.76:
				continue
			var t: MeshInstance3D = MeshInstance3D.new()
			t.mesh = tile
			t.position = pos + Vector3(0.0, 0.004, 0.0)
			t.material_override = Toon.material(PLATFORM_TILE_A if (ix + iz) % 2 == 0 else PLATFORM_TILE_B, false)
			_platform.add_child(t)


## view: "face" (bust, gentle sway) or "body" (whole skater, slow turntable).
func show_skater(l: SkaterLoadout, view: String = "body") -> void:
	_loadout = l
	_board_only = false
	_set_view(view)
	_dirty = true


## view: "top" (deck top, slow swing), "grip" (close griptape camera) or "display" (stood up, graphic and trucks
## facing the camera). The older "under" means "display".
func show_board(l: SkaterLoadout, view: String = "top") -> void:
	_loadout = l
	_board_only = true
	_set_view("display" if view == "under" else view)
	_dirty = true


func _set_view(v: String) -> void:
	if v != _view:
		_user_yaw = 0.0
		_spin_yaw = 0.0
	_view = v if VIEWS.has(v) else "body"
	_frame_camera()


func _frame_camera() -> void:
	var v: Dictionary = VIEWS[_view]
	_cam.fov = float(v["fov"])
	_cam.transform = Transform3D(Basis.IDENTITY, v["cam"]).looking_at(v["at"], Vector3.UP)


func _rebuild() -> void:
	_dirty = false
	_platform.scale = Vector3(0.42, 1.0, 0.42) if _board_only else Vector3.ONE
	_platform.visible = _view != "face" and not _floating_view()
	for c: Node in _holder.get_children():
		_holder.remove_child(c)
		c.queue_free()
	if _loadout == null:
		return
	var root: Node3D = Node3D.new()
	var board: Node3D = SkaterBuilder.build_board(_loadout)
	root.add_child(board)
	if not _board_only:
		var body: Node3D = SkaterBuilder.build_body(_loadout)
		body.position.y = PlaceholderSkater.DECK_TOP_Y
		root.add_child(body)
		Toon.apply_to(root)
		var poser: SkaterPoser = SkaterPoser.new()
		poser.body = body
		poser.board = board
		poser.preview_anim = "crouch"
		root.add_child(poser)
		var sway: SecondaryMotion = SecondaryMotion.new()
		root.add_child(sway)
		sway.bind(root)
	else:
		Toon.apply_to(root)
		if _floating_view():
			root.position.y = 0.3
		elif _view == "display":
			root.rotation.x = deg_to_rad(-78.0)
			root.position.y = 0.46
	_holder.add_child(root)


## Trucks and wheels are looked at from below, so the board floats and the stage is hidden.
func _floating_view() -> bool:
	return _board_only and (_view == "trucks" or _view == "wheels")


func _process(delta: float) -> void:
	if _dirty:
		_rebuild()
	_time += delta
	var v: Dictionary = VIEWS[_view]
	var spin: float = 0.0
	var stick: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(stick) > 0.2:
		spin += stick * STICK_SPIN
	if Input.is_physical_key_pressed(KEY_X):
		spin += STICK_SPIN * 0.7
	if Input.is_physical_key_pressed(KEY_Z):
		spin -= STICK_SPIN * 0.7
	var auto: float = float(v["spin"])
	if spin != 0.0 or _dragging:
		_idle = 0.0
	else:
		_idle += delta
	_user_yaw += spin * delta
	if _idle > IDLE_BEFORE_AUTO:
		_spin_yaw += auto * delta
		if auto == 0.0:
			_user_yaw = move_toward(_user_yaw, 0.0, delta * 0.8)
	var sway: float = sin(_time * 0.7) * float(v["sway"])
	_pivot.rotation.y = float(v["base"]) + _user_yaw + _spin_yaw + sway


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		_user_yaw += (event as InputEventMouseMotion).relative.x * 0.012
