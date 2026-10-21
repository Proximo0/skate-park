extends RefCounted
## Shared harness for the ride-feel regression sims (sim_*.gd, run by tests/sim/sim_suite.gd).
## A sim extends this, sets `host` (a Node in the tree) and implements `func run() -> Array` returning
## [[name, ok, detail], ...]. Everything is in sim seconds (physics ticks), never wall clock.

const PieceKit := preload("res://game/park/piece_kit.gd")
## SIM_SKATER_SCRIPT swaps in another skater script (a copy with a deliberate break), to prove a sim can fail.
var SkaterScript: GDScript = load(OS.get_environment("SIM_SKATER_SCRIPT") if OS.get_environment("SIM_SKATER_SCRIPT") != "" else "res://game/skater/skater.gd")
const DT: float = 1.0 / 60.0
const UPV: Vector3 = Vector3.UP
const NONE: Vector2 = Vector2.ZERO
const FWD: Vector2 = Vector2(0.0, -1.0)  ## stick up = push / lean forward

var host: Node
var sk  ## a Skater (untyped so a mutated copy of the script can stand in)
var root3: Node3D
var bails: int = 0
var landings: Array = []


## Flat concrete ground plus `pieces`, and a scripted-input skater.
func sandbox(pieces: Array, with_ground: bool = true) -> void:
	root3 = Node3D.new()
	host.add_child(root3)
	root3.add_child(WorldEnvironment.new())
	if with_ground:
		root3.add_child(PieceKit.box(Vector3(-100, -1, -100), Vector3(200, 1, 200), PieceKit.CONCRETE, "Ground"))
	for p: Node3D in pieces:
		root3.add_child(p)
	attach_skater()


func attach_skater() -> void:
	sk = SkaterScript.new()
	sk.name = "Skater"
	root3.add_child(sk)
	sk.scripted_input = true
	bails = 0
	landings = []
	sk.bailed.connect(func() -> void: bails += 1)
	sk.landed.connect(func(r: String) -> void: landings.append(r))
	await host.get_tree().physics_frame
	sk.set_input(NONE, [], [])


func clear() -> void:
	if root3 != null:
		host.remove_child(root3)
		root3.free()
		root3 = null
	sk = null
	await host.get_tree().physics_frame


func place(pos: Vector3, dir: Vector3, speed: float) -> void:
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	sk.global_transform = Transform3D(Basis.looking_at(d, UPV), pos)
	sk.velocity = d * speed
	sk.facing = d
	sk.board_up = UPV
	sk._floor_normal = UPV
	sk.up_direction = UPV
	sk.speed = speed


func tick(stick: Vector2 = NONE, jp: Array = [], held: Array = []) -> void:
	sk.set_input(stick, jp, held)
	await host.get_tree().physics_frame


func sname() -> String:
	return sk.state.state_name()


func ok_line(sim_name: String, ok: Variant, detail: String) -> Array:
	return [sim_name, ok, detail]
