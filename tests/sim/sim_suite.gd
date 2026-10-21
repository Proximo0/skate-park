extends Node
## Runs the ride-feel regression sims listed in SIM_FILES (each tests/sim/sim_<name>.gd extends sim_base.gd and
## returns [[name, ok, detail], ...] from run()). Prints "SIM <name> PASS|FAIL <detail>" and "SIMS passed=N failed=M".
## Part of tools/run_sims.sh. Run alone: godot --headless --path . res://tests/sim/sim_suite.tscn [-- name ...]

const SIM_FILES: Array = [
	"sim_kicker", "sim_ledge_drop", "sim_halfpipe_pump", "sim_vert_reentry", "sim_bank45", "sim_wall_head_on", "sim_drop_in", "sim_snapshot", "sim_walk", "sim_grind_topple", "sim_pump_no_stall",
]


func _ready() -> void:
	var only: PackedStringArray = OS.get_cmdline_user_args()
	var passed: int = 0
	var failed: int = 0
	for f: String in SIM_FILES:
		if not only.is_empty() and not only.has(f):
			continue
		var scr: GDScript = load("res://tests/sim/%s.gd" % f) as GDScript
		var sim: Variant = scr.new()
		sim.host = self
		var rows: Array = await sim.run()
		for r: Array in rows:
			var verdict: String = "PASS" if r[1] else "FAIL"
			if r[1] == null:
				verdict = "INFO"
			elif r[1]:
				passed += 1
			else:
				failed += 1
			print("SIM %s %s %s" % [r[0], verdict, r[2]])
	print("SIMS passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
