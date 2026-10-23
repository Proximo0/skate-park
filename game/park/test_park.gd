extends Node3D
## Small proving ground for the skater controller: flat ground, two facing quarter pipes, a kicker,
## a flat rail and a ledge. Used by controller sims and captures until the real park exists.

var skater: Skater


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Toon.sky_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	add_child(PieceKit.box(Vector3(-20, -1, -30), Vector3(40, 1, 60), PieceKit.CONCRETE, "Ground"))
	var qp_far: Node3D = QuarterPipe.build(10.0)
	qp_far.position = Vector3(-5, 0, -30)
	add_child(qp_far)
	var qp_near: Node3D = QuarterPipe.build(10.0)
	qp_near.rotation_degrees = Vector3(0, 180, 0)
	qp_near.position = Vector3(5, 0, 30)
	add_child(qp_near)
	var kick: Node3D = Kicker.build()
	kick.position = Vector3(6, 0, 2)
	add_child(kick)
	add_child(PieceKit.round_rail(Vector3(-6, 0.6, 8), Vector3(-6, 0.6, -8)))
	var ledge := PieceKit.box(Vector3(-11, 0, -6), Vector3(1.0, 0.5, 12), PieceKit.PAINT_PURPLE, "Ledge")
	add_child(ledge)
	add_child(PieceKit.rail(PackedVector3Array([Vector3(-10.0, 0.5, 6), Vector3(-10.0, 0.5, -6)]), "ledge", "LedgeEdge"))
	skater = Skater.new()
	skater.name = "Skater"
	skater.position = Vector3(0, 0.05, 10)
	var visual := Node3D.new()
	visual.name = "Visual"
	var body: Node3D = PlaceholderSkater.build_body()
	var board: Node3D = PlaceholderSkater.build_board()
	visual.add_child(board)
	body.position = Vector3(0, 0.1, 0)
	visual.add_child(body)
	Toon.apply_to(visual)
	skater.add_child(visual)
	add_child(skater)
	var cam := Camera3D.new()
	cam.name = "ChaseCam"
	add_child(cam)
	cam.current = true


func _physics_process(delta: float) -> void:
	var cam: Camera3D = $ChaseCam
	var back: Vector3 = -skater.facing
	back.y = 0.0
	if back.length() < 0.1:
		back = Vector3.BACK
	var target: Vector3 = skater.global_position - back.normalized() * -4.5 + Vector3.UP * 2.2
	cam.global_position = cam.global_position.lerp(target, clampf(delta * 5.0, 0.0, 1.0))
	cam.look_at(skater.global_position + Vector3.UP * 0.8)
