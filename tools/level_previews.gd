extends SceneTree
## Renders the level-select card images: game/levels/previews/<id>.png (1048 x 456, twice the card's image size) for
## every LevelRegistry level, or the ids given after --. Needs a real renderer: run through tools/level_previews.sh.

const OUT_DIR: String = "res://game/levels/previews/"
const SIZE := Vector2i(1048, 456)
const SETTLE_FRAMES: int = 45

var _queue: Array[String] = []
var _level: Node3D = null
var _cam: Camera3D = null
var _id: String = ""
var _wait: int = 0


func _initialize() -> void:
	var reg: GDScript = load("res://game/levels/level_registry.gd")
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			_queue.append(a)
	if _queue.is_empty():
		_queue.assign(reg.call("ids"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE


func _process(_delta: float) -> bool:
	if _level == null:
		if _queue.is_empty():
			return true
		_start(_queue.pop_front())
		return false
	_wait += 1
	if _wait == SETTLE_FRAMES:
		_save.call_deferred()
	return false


func _start(id: String) -> void:
	_id = id
	_wait = 0
	var reg: GDScript = load("res://game/levels/level_registry.gd")
	_level = reg.call("create", id) as Node3D
	root.add_child(_level)
	_cam = Camera3D.new()
	_cam.far = 4000.0
	_cam.fov = 55.0
	root.add_child(_cam)
	_cam.make_current()
	var view: Array = _level.get("preview_view") as Array
	var sp: Transform3D = _level.get("spawn") as Transform3D
	if view.size() >= 2:
		_cam.look_at_from_position(view[0] as Vector3, view[1] as Vector3, Vector3.UP)
	else:
		var fwd: Vector3 = -sp.basis.z
		_cam.look_at_from_position(sp.origin - fwd * 10.0 + Vector3(0.0, 6.0, 0.0), sp.origin + fwd * 25.0, Vector3.UP)


func _save() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	if img.get_size() != SIZE:
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	var path: String = ProjectSettings.globalize_path(OUT_DIR + _id + ".png")
	img.save_png(path)
	print("preview ", _id, " -> ", path)
	_level.queue_free()
	_cam.queue_free()
	_level = null
