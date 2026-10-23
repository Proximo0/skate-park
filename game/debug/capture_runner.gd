extends Node
## Scripted screenshot capture (PipelineKit's capture_showcase, ported). Run through tools/capture.sh.
## User args after "--": --views=<res:// or absolute path> --out=<absolute dir>.
## Per view: instance the scene, pose a Camera3D, settle, time frames, save PNG and JSON sidecar.

const DEFAULT_SETTLE: int = 10
const DEFAULT_MEASURE: int = 60

var _instance: Node = null
var _camera: Camera3D = null


func _ready() -> void:
	_run()


func _run() -> void:
	var views_path: String = Flags.get_arg("views")
	var out_dir: String = Flags.get_arg("out")
	if views_path == "" or out_dir == "":
		printerr("capture: needs --views=<path> and --out=<dir>")
		get_tree().quit(1)
		return
	var views: Array = _load_views(views_path)
	if views.is_empty():
		printerr("capture: no views in %s" % views_path)
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var shots: int = 0
	for item: Variant in views:
		if typeof(item) != TYPE_DICTIONARY:
			printerr("capture: view %d is not an object" % shots)
			get_tree().quit(1)
			return
		var view: Dictionary = item
		var ok: bool = await _capture_view(view, out_dir)
		if not ok:
			get_tree().quit(1)
			return
		shots += 1
	print("CAPTURE done views=%d" % shots)
	get_tree().quit(0)


func _load_views(path: String) -> Array:
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		return []
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var doc: Dictionary = parsed
	if not doc.has("views") or typeof(doc["views"]) != TYPE_ARRAY:
		return []
	return doc["views"]


func _capture_view(view: Dictionary, out_dir: String) -> bool:
	var view_name: String = str(view.get("name", ""))
	var scene_path: String = str(view.get("scene", ""))
	if view_name == "" or scene_path == "":
		printerr("capture: a view needs a name and a scene")
		return false
	var packed: PackedScene = null
	if ResourceLoader.exists(scene_path):
		packed = load(scene_path) as PackedScene
	if packed == null:
		printerr("capture: %s: scene failed to load: %s" % [view_name, scene_path])
		return false

	_free_previous()
	_instance = packed.instantiate()
	add_child(_instance)
	if bool(view.get("hide_hud", false)):
		for n: Node in get_tree().get_nodes_in_group("hud"):
			if n is CanvasItem:
				(n as CanvasItem).visible = false
			elif n is Node3D:
				(n as Node3D).visible = false

	var cam: Dictionary = view.get("camera", {})
	var pos: Vector3 = _vec3(cam.get("pos", [0, 0, 0]))
	var target: Vector3 = _vec3(cam.get("look_at", [0, 0, 0]))
	_camera = Camera3D.new()
	_camera.name = "CaptureCamera"
	add_child(_camera)
	_camera.fov = float(cam.get("fov", 70.0))
	_camera.global_position = pos
	if pos.distance_to(target) > 0.001:
		_camera.look_at(target)
	_camera.make_current()

	var settle: int = int(view.get("settle_frames", DEFAULT_SETTLE))
	var measure: int = int(view.get("measure_frames", DEFAULT_MEASURE))
	for _i: int in range(settle):
		await get_tree().process_frame

	var total_usec: int = 0
	var worst_usec: int = 0
	for _i: int in range(measure):
		var t0: int = Time.get_ticks_usec()
		await get_tree().process_frame
		var dt: int = Time.get_ticks_usec() - t0
		total_usec += dt
		worst_usec = maxi(worst_usec, dt)
	var fps_avg: float = 0.0
	if total_usec > 0:
		fps_avg = float(measure) * 1000000.0 / float(total_usec)
	var worst_ms: float = float(worst_usec) / 1000.0

	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		printerr("capture: %s: no image from viewport" % view_name)
		return false
	if img.save_png(out_dir.path_join(view_name + ".png")) != OK:
		printerr("capture: %s: could not write PNG" % view_name)
		return false

	var side: Dictionary = {
		"view": view_name,
		"frame": Flags.frame,
		"state_hash": Flags.state_hash(),
		"commands": Flags.commands,
		"render_size": [img.get_width(), img.get_height()],
		"fps_avg": snappedf(fps_avg, 0.01),
		"worst_ms": snappedf(worst_ms, 0.01),
		"camera": {
			"pos": [pos.x, pos.y, pos.z],
			"look_at": [target.x, target.y, target.z],
			"fov": _camera.fov,
		},
		"engine": Engine.get_version_info()["string"],
	}
	var f: FileAccess = FileAccess.open(out_dir.path_join(view_name + ".json"), FileAccess.WRITE)
	if f == null:
		printerr("capture: %s: could not write sidecar" % view_name)
		return false
	f.store_string(JSON.stringify(side, "  "))
	f.close()
	print("SHOT %s ok fps=%d" % [view_name, roundi(fps_avg)])
	return true


func _vec3(v: Variant) -> Vector3:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() < 3:
		return Vector3.ZERO
	var a: Array = v
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _free_previous() -> void:
	if _instance != null:
		remove_child(_instance)
		_instance.free()
		_instance = null
	if _camera != null:
		remove_child(_camera)
		_camera.free()
		_camera = null
