extends Node3D
## Entry scene. Loads the park once it exists (step 3); for now a ground plane and a sun.


func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	add_child(ground)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 4, 10)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
