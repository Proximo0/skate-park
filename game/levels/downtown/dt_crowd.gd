class_name DtCrowd
extends Pedestrians
## Downtown's crowd: a Pedestrians crowd kept inside the draw budget from any street corner. People fade out past
## VIEW_END metres from the camera (an engine visibility range on every mesh of every body), and only those within
## SHADOW_END cast shadows (a body is ~25 meshes, and every shadow split draws each again). Close up they are the
## world kit's people as they are.

const VIEW_END: float = 45.0
const VIEW_MARGIN: float = 6.0
const SHADOW_END: float = 20.0
const DT_SHADOW_EVERY: int = 6

var _meshes: Dictionary = {}  ## Pedestrian -> Array[GeometryInstance3D]
var _shadowed: Dictionary = {}  ## Pedestrian -> bool
var _tick: int = 0


func _dress_waiting() -> void:
	super._dress_waiting()
	for p: Pedestrian in people:
		if p.has_body() and not _meshes.has(p):
			var list: Array[GeometryInstance3D] = []
			for n: Node in p.find_children("*", "GeometryInstance3D", true, false):
				var g: GeometryInstance3D = n as GeometryInstance3D
				g.visibility_range_end = VIEW_END
				g.visibility_range_end_margin = VIEW_MARGIN
				g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					list.append(g)  # only the meshes that cast shadows to begin with are switched
			_meshes[p] = list
			_shadowed[p] = true


func _process(delta: float) -> void:
	super._process(delta)
	_tick += 1
	if _tick % DT_SHADOW_EVERY != 0:
		return
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var eye: Vector3 = cam.global_position
	for p: Pedestrian in _meshes:
		var want: bool = p.global_position.distance_to(eye) < SHADOW_END
		if bool(_shadowed[p]) == want:
			continue
		_shadowed[p] = want
		var mode: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if want else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for g: GeometryInstance3D in _meshes[p] as Array[GeometryInstance3D]:
			g.cast_shadow = mode
