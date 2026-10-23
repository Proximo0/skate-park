extends "res://tests/sim/sim_base.gd"
## Skater.snapshot()/restore(): a snapshot taken mid-ride (through var_to_str/str_to_var), restored and run with the
## same inputs reproduces the positions within 1e-3 m over 120 ticks, through an ollie and its landing. Also
## checks that PhysicsTuning.gravity changes the ollie height.

const TICKS: int = 120
const EPS: float = 1.0e-3


## Input for tick i of the test run: ride forward, crouch for 12 ticks, release (ollie), coast.
func _input(i: int) -> Array:
	if i < 12:
		return [FWD, [], ["ollie"]]
	return [FWD, [], []]


## Runs TICKS ticks from the current state. Returns {pos: Array[Vector3], land: int, air: int, peak: float}.
func _run_script() -> Dictionary:
	var out: Dictionary = {"pos": [], "land": 0, "air": 0, "peak": -1000.0}
	var ev: Callable = func(frame: Dictionary) -> void:
		for e: String in frame["events"]:
			if e.begins_with("land:"):
				out["land"] = int(out["land"]) + 1
			elif e == "air":
				out["air"] = int(out["air"]) + 1
	sk.physics_ticked.connect(ev)
	for i: int in TICKS:
		var inp: Array = _input(i)
		await tick(inp[0], inp[1], inp[2])
		(out["pos"] as Array).append(sk.global_position)
		out["peak"] = maxf(float(out["peak"]), sk.global_position.y)
	sk.physics_ticked.disconnect(ev)
	return out


func run() -> Array:
	var rows: Array = []
	await sandbox([])
	sk.tune = PhysicsTuning.new()
	place(Vector3(0, 0.0, 0), Vector3(0, 0, -1), 6.0)
	for i: int in 45:
		await tick(FWD)
	var snap_text: String = var_to_str(sk.snapshot())
	var first: Dictionary = await _run_script()
	sk.restore(str_to_var(snap_text) as Dictionary)
	var second: Dictionary = await _run_script()
	var worst: float = 0.0
	for i: int in TICKS:
		worst = maxf(worst, ((first["pos"] as Array)[i] as Vector3).distance_to((second["pos"] as Array)[i] as Vector3))
	var good: bool = worst <= EPS and int(first["land"]) >= 1 and int(first["air"]) >= 1 and int(second["land"]) == int(first["land"])
	rows.append(ok_line("snapshot_replay", good, "worst position error %.6f m over %d ticks (need <= %.3f), ollie peak y %.2f, airs %d, landings %d/%d" % [worst, TICKS, EPS, float(first["peak"]), int(first["air"]), int(first["land"]), int(second["land"])]))

	# Gravity changes the ollie height: same snapshot, half the gravity.
	sk.restore(str_to_var(snap_text) as Dictionary)
	sk.tune.gravity = 9.0
	var light: Dictionary = await _run_script()
	sk.tune.gravity = 18.0
	var higher: bool = float(light["peak"]) > float(first["peak"]) + 0.3
	rows.append(ok_line("tune_gravity_ollie", higher, "ollie peak y %.2f at gravity 18, %.2f at gravity 9 (need higher by 0.3)" % [float(first["peak"]), float(light["peak"])]))
	await clear()
	return rows
