extends "res://tests/sim/sim_base.gd"
## Weight on the board (round 10, audit gaps 5 and 6), through the physics lab's own manoeuvres:
##  snap_drop_energy  a Q+E ramp snap drop-in off a 6 m and a 3.2 m quarter pipe reaches the bottom at about the
##                    speed gravity gives over that height (0.85..1.0 of sqrt(2 g h)), and the tip over the coping
##                    never pushes harder than about gravity (round 9: 1.5x the energy, a 7.8 g catapult)
##  carve_weight      full stick at 4 / 8 / 12 m/s carves about 2.5 / 4.5 / 8 m, and at 8 m/s the turn leans in over
##                    0.1..0.35 s instead of answering in one tick (round 9: 3.4 m and 0.017 s, a ball on a pin)


func _lab() -> Variant:
	var m: Variant = (load("res://tests/lab/lab_moves.gd") as GDScript).new()
	m.host = host
	m.SkaterScript = SkaterScript
	return m


func _g() -> float:
	return float(PhysicsTuning.shared().gravity)


func run() -> Array:
	var rows: Array = []
	var lab: Variant = _lab()
	var g: float = _g()
	var tall: Dictionary = await lab.snap_drop_data(6.0)
	var low: Dictionary = await lab.snap_drop_data(3.2)
	var k_tall: float = float(tall["spd"]) / sqrt(2.0 * g * 6.0)
	var k_low: float = float(low["spd"]) / sqrt(2.0 * g * 3.2)
	var peak: float = maxf(float(tall["peak"]), float(low["peak"])) / g
	var ok: bool = bool(tall["snapped"]) and bool(low["snapped"]) and k_tall >= 0.85 and k_tall <= 1.0 \
		and k_low >= 0.85 and k_low <= 1.0 and peak <= 1.2 and int(tall["bails"]) == 0 and int(low["bails"]) == 0
	rows.append(ok_line("snap_drop_energy", ok, "6 m: %.1f m/s = %.2f of sqrt(2gh), 3.2 m: %.1f m/s = %.2f (want 0.85..1.0); hardest tip push %.2f g (want <= 1.2); bails %d/%d"
		% [tall["spd"], k_tall, low["spd"], k_low, peak, tall["bails"], low["bails"]]))
	var r4: float = await lab._turn(4.0)
	var r8: float = await lab._turn(8.0)
	var lean: float = lab.last_turn_lean_in
	var r12: float = await lab._turn(12.0)
	var ok2: bool = r4 >= 1.5 and r4 <= 3.2 and r8 >= 3.8 and r8 <= 6.0 and r12 >= 6.0 and r12 <= 10.0 \
		and r12 > r8 * 1.4 and lean >= 0.1 and lean <= 0.35
	rows.append(ok_line("carve_weight", ok2, "turn radius %.2f / %.2f / %.2f m at 4 / 8 / 12 m/s (want ~2.5 / 4.5 / 8), lean-in at 8 m/s %.3f s (want 0.1..0.35)"
		% [r4, r8, r12, lean]))
	return rows
