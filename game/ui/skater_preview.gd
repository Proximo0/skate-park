class_name SkaterPreview
extends SubViewportContainer
## A 3D turntable for menus. show_skater() stands the whole skater on it, show_board() shows just the board.
## Turn it with the right stick, Z / X, or by dragging with the mouse; it drifts slowly when left alone.

const AUTO_SPIN: float = 0.5  ## rad/s while idle
const STICK_SPIN: float = 3.2
const IDLE_BEFORE_AUTO: float = 1.5
const PLATFORM_COLOR := Color("#B79CFF")
const PLATFORM_STRIPE := Color("#FFD84D")

var _vp: SubViewport
var _pivot: Node3D
var _holder: Node3D
var _platform: Node3D
var _cam: Camera3D
var _loadout: SkaterLoadout = null
var _board_only: bool = false
var _board_view: String = "under"
var _dirty: bool = false
var _idle: float = 0.0
var _dragging: bool = false


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Toon.sky_environment()
	_vp.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	sun.shadow_enabled = true
	_vp.add_child(sun)
	_pivot = Node3D.new()
	_pivot.name = "Turntable"
	_pivot.rotation.y = PI  # the skater faces the camera
	_vp.add_child(_pivot)
	_build_platform()
	_holder = Node3D.new()
	_pivot.add_child(_holder)
	_cam = Camera3D.new()
	_cam.near = 0.05
	_vp.add_child(_cam)
	_frame_camera()


func _build_platform() -> void:
	_platform = Node3D.new()
	_pivot.add_child(_platform)
	var disc: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.85
	cyl.bottom_radius = 0.9
	cyl.height = 0.08
	disc.mesh = cyl
	disc.position.y = -0.04
	disc.material_override = Toon.material(PLATFORM_COLOR, true)
	_platform.add_child(disc)
	for i: int in 6:
		var stripe: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.12, 0.02, 0.22)
		stripe.mesh = box
		var a: float = float(i) * TAU / 6.0
		stripe.position = Vector3(sin(a) * 0.72, 0.001, cos(a) * 0.72)
		stripe.rotation.y = a
		stripe.material_override = Toon.material(PLATFORM_STRIPE, false)
		_platform.add_child(stripe)


func show_skater(l: SkaterLoadout) -> void:
	_loadout = l
	_board_only = false
	_dirty = true
	_frame_camera()


## view: "top" shows the griptape side, "under" flips the board to show the deck graphic, trucks and wheels.
func show_board(l: SkaterLoadout, view: String = "under") -> void:
	_loadout = l
	_board_only = true
	_board_view = view
	_dirty = true
	_frame_camera()


func _frame_camera() -> void:
	if _board_only:
		_cam.fov = 34.0
		_cam.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.85, 1.9)).looking_at(Vector3(0.0, 0.12, 0.0), Vector3.UP)
	else:
		_cam.fov = 34.0
		_cam.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.55, 4.3)).looking_at(Vector3(0.0, 0.78, 0.0), Vector3.UP)


func _rebuild() -> void:
	_dirty = false
	_platform.scale = Vector3(0.5, 1.0, 0.5) if _board_only else Vector3.ONE
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
	else:
		Toon.apply_to(root)
		root.rotation.x = deg_to_rad(-22.0)
		if _board_view == "under":
			root.rotation.z = PI
			root.position.y = 0.2
	_holder.add_child(root)


func _process(delta: float) -> void:
	if _dirty:
		_rebuild()
	var spin: float = 0.0
	var stick: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(stick) > 0.2:
		spin += stick * STICK_SPIN
	if Input.is_physical_key_pressed(KEY_X):
		spin += STICK_SPIN * 0.7
	if Input.is_physical_key_pressed(KEY_Z):
		spin -= STICK_SPIN * 0.7
	if spin != 0.0 or _dragging:
		_idle = 0.0
	else:
		_idle += delta
		if _idle > IDLE_BEFORE_AUTO:
			spin = AUTO_SPIN
	_pivot.rotation.y += spin * delta


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		_pivot.rotation.y += (event as InputEventMouseMotion).relative.x * 0.012
