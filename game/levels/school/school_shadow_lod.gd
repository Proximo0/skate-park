class_name SchoolShadowLod
extends Node
## Shadow LOD for the School level's people: a person (about 50 mesh surfaces) costs as many draw calls again in the
## sun's shadow pass, so only the people near the camera cast shadows. Checked twice a second.

const NEAR: float = 26.0
const PERIOD: float = 0.5

var crowd: Node3D
var _t: float = 0.0
var _on: Dictionary = {}  ## person instance id -> casting now


func _process(delta: float) -> void:
	_t += delta
	if _t < PERIOD or crowd == null:
		return
	_t = 0.0
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye: Vector3 = cam.global_position
	for p: Node in crowd.get_children():
		if not (p is Node3D):
			continue
		var near: bool = (p as Node3D).global_position.distance_to(eye) < NEAR
		var id: int = p.get_instance_id()
		if _on.has(id) and bool(_on[id]) == near:
			continue
		_on[id] = near
		var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if near else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for g: Node in p.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = mode
