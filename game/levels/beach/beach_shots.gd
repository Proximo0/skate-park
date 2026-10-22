extends SceneTree
## Beachfront art-check renders: one PNG per named view (spawn, vistas, lines, overview) plus draw-call and primitive
## counts. Run: xvfb-run -a godot --rendering-driver opengl3 --path . -s res://game/levels/beach/beach_shots.gd -- --scripted <out_dir> [view ...]

const SIZE := Vector2i(1280, 720)
const VIEWS: Dictionary = {
	"spawn": [Vector3(0.0, 2.6, -33.0), Vector3(0.0, 0.8, -15.0)],
	"vista_sea": [Vector3(-6.0, 3.2, -11.5), Vector3(30.0, -1.0, 80.0)],
	"vista_pier": [Vector3(30.0, 4.0, -4.0), Vector3(58.0, 0.0, 70.0)],
	"vista_park": [Vector3(-34.0, 10.0, -12.0), Vector3(-80.0, -1.0, -28.0)],
	"vista_town": [Vector3(54.0, 3.0, 92.0), Vector3(20.0, 4.0, -60.0)],
	"vista_bay": [Vector3(-100.0, 6.0, 18.0), Vector3(40.0, 0.0, 60.0)],
	"overview": [Vector3(-60.0, 90.0, 150.0), Vector3(0.0, 0.0, -10.0)],
	"overview_n": [Vector3(0.0, 70.0, -120.0), Vector3(0.0, 0.0, 20.0)],
	"line_snake": [Vector3(-110.0, 3.2, -35.0), Vector3(-84.0, -1.2, -22.0)],
	"snake_close": [Vector3(-88.0, 1.6, -22.0), Vector3(-76.0, -1.2, -18.0)],
	"line_seawall": [Vector3(-60.0, 1.8, -10.5), Vector3(-10.0, 0.4, -8.6)],
	"line_pier": [Vector3(54.0, 2.2, 0.0), Vector3(54.0, 0.5, 60.0)],
	"line_launch": [Vector3(22.0, 2.0, -20.0), Vector3(36.0, 0.0, 4.0)],
	"life_road": [Vector3(-14.0, 2.0, -40.0), Vector3(10.0, 1.0, -56.0)],
	"life_beach": [Vector3(-20.0, 1.6, -2.0), Vector3(-40.0, -0.5, 14.0)],
	"life_boardwalk": [Vector3(-10.0, 1.8, -24.0), Vector3(20.0, 1.0, -31.0)],
	"ped_close": [Vector3(-36.0, 0.4, 3.5), Vector3(-36.0, -0.4, 8.0)],
}

var _level: Node3D = null
var _cam: Camera3D = null
var _queue: Array[String] = []
var _out: String = ""
var _frame: int = 0
var _cur: String = ""


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for a: String in args:
		if a.begins_with("--"):
			continue
		if _out == "":
			_out = a
		else:
			_queue.append(a)
	if _queue.is_empty():
		_queue.assign(VIEWS.keys())
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE
	var reg: GDScript = load("res://game/levels/level_registry.gd")
	_level = reg.call("create", "beach") as Node3D
	root.add_child(_level)
	_cam = Camera3D.new()
	_cam.far = 4000.0
	_cam.fov = 60.0
	root.add_child(_cam)
	_cam.make_current()


func _process(_delta: float) -> bool:
	_frame += 1
	if OS.get_cmdline_user_args().has("--trace"):
		printerr("frame ", _frame, " ms=", Time.get_ticks_msec())
	if _cur == "" and _frame < 30:
		if _frame == 29:
			for a: String in OS.get_cmdline_user_args():
				if a.begins_with("--hide="):
					for nm: String in a.trim_prefix("--hide=").split(","):
						var n: Node3D = _level.get_node_or_null(nm) as Node3D
						if n != null:
							n.visible = false
		return false
	if _cur == "":
		if _queue.is_empty():
			return true
		_cur = _queue.pop_front()
		var v: Array = VIEWS[_cur]
		_cam.look_at_from_position(v[0] as Vector3, v[1] as Vector3, Vector3.UP)
		_frame = 20
		return false
	if _frame == 26:
		_save.call_deferred(_cur)
		_cur = ""
	return false


func _save(view_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_out + "/" + view_name + ".png")
	var draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	printerr("shot %s draws=%d prims=%.2fM" % [view_name, draws, float(prims) / 1e6])
