extends Node
## Drives the skater through a script and prints its state every 0.25 s. Run under xvfb:
## godot --path . res://tests/sim/sim_ride.tscn -- --scripted
## Script lines: [seconds, stick_x, stick_y, just_pressed, held]

var park: Node3D
var t: float = 0.0
var step: int = 0
var shot_at: Array = []
var plan: Array = [
	[2.5, 0.0, -1.0, [], []],           # push forward toward the far quarter pipe
	[0.3, 0.0, -1.0, [], ["ollie"]],    # crouch
	[0.05, 0.0, 0.0, ["flip"], []],     # release ollie + flip (buffered)
	[1.2, 0.0, 0.0, [], []],
	[4.0, 0.0, -1.0, [], []],           # keep pushing into the quarter pipe
	[3.0, 0.0, 0.0, [], []],
]


func _ready() -> void:
	park = (load("res://game/park/test_park.tscn") as PackedScene).instantiate()
	add_child(park)
	await get_tree().process_frame
	var sk: Skater = park.skater
	sk.scripted_input = true
	sk.trick_started.connect(func(tr: Dictionary) -> void: print("  TRICK ", tr.get("name")))
	sk.combo_landed.connect(func(p: int, txt: String) -> void: print("  LANDED ", p, " ", txt))
	sk.combo_bailed.connect(func(txt: String) -> void: print("  BAILED ", txt))


var _seg_t: float = 0.0
var _last_print: float = -1.0
var _released: bool = false


func _physics_process(delta: float) -> void:
	var sk: Skater = park.skater
	if step >= plan.size():
		print("SIM done")
		get_tree().quit()
		return
	var s: Array = plan[step]
	var jp: Array = s[3] if _seg_t == 0.0 else []
	# releasing a held ollie happens when held goes from ["ollie"] to []
	sk.set_input(Vector2(s[1], s[2]), jp, s[4])
	_seg_t += delta
	t += delta
	if _seg_t >= float(s[0]):
		step += 1
		_seg_t = 0.0
	for st: float in [1.0, 2.95, 4.6]:
		if t >= st and t - delta < st and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://out/sim"))
			get_viewport().get_texture().get_image().save_png("res://out/sim/t%.2f.png" % st)
	if t - _last_print >= 0.25:
		_last_print = t
		print("t=%.2f %s pos=(%.1f,%.1f,%.1f) v=%.1f n=%s anim=%s" % [t, sk.state.state_name(), sk.global_position.x, sk.global_position.y, sk.global_position.z, sk.velocity.length(), str(sk._floor_normal.snappedf(0.01)), sk.anim])
