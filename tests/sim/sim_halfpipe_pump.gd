extends "res://tests/sim/sim_base.gd"
## Main-park halfpipe (coping y 4.0, centre x -33): from 9 m/s holding the stick forward for 25 s, each air's peak above
## the coping grows and the last is at least 4 m above it, with no bails. With no input it does not gain height.

const ParkScript := preload("res://game/park/park.gd")
const COPING_Y: float = 4.0
const START: Vector3 = Vector3(-33.0, 0.05, -31.5)
const SECONDS: float = 25.0
const MIN_LAST_PEAK: float = 4.0
const MIN_GAIN: float = 1.0  ## last peak minus first peak
const SLACK: float = 0.75  ## a peak may sit this far under the one before (heights saturate near the top)


## Returns {peaks: [m above coping per air], bails, end_speed}.
func _run_hp(stick: Vector2) -> Dictionary:
	root3 = Node3D.new()
	host.add_child(root3)
	var park: Node = ParkScript.new()
	park.name = "Park"
	root3.add_child(park)
	sk = SkaterScript.new()
	sk.name = "Skater"
	sk.position = START
	var vis := Node3D.new()
	vis.name = "Visual"
	sk.add_child(vis)
	root3.add_child(sk)
	sk.scripted_input = true
	bails = 0
	sk.bailed.connect(func() -> void: bails += 1)
	for i: int in 20:
		await tick()
	sk.global_position = START
	sk.velocity = Vector3(0, 0, -9.0)
	sk.facing = Vector3(0, 0, -1)
	sk.board_up = UPV
	await tick()
	var peaks: Array = []
	var cur: float = -99.0
	var in_air: bool = false
	for i: int in int(SECONDS / DT):
		await tick(stick)
		if sname() == "AIR":
			in_air = true
			cur = maxf(cur, sk.global_position.y)
		elif in_air:
			peaks.append(cur - COPING_Y)
			cur = -99.0
			in_air = false
	var res: Dictionary = {"peaks": peaks, "bails": bails, "speed": sk.speed}
	await clear()
	return res


func _fmt(a: Array) -> String:
	var p: PackedStringArray = []
	for v: Variant in a:
		p.append("%.1f" % float(v))
	return ",".join(p)


func run() -> Array:
	var rows: Array = []
	var r: Dictionary = await _run_hp(FWD)
	var pk: Array = r["peaks"]
	var ok: bool = pk.size() >= 3 and r["bails"] == 0
	var grows: bool = true
	var last: float = 0.0
	var first: float = 0.0
	if pk.size() >= 3:
		first = pk[0]
		last = pk[pk.size() - 1]
		for i: int in range(1, pk.size()):
			if float(pk[i]) < float(pk[i - 1]) - SLACK:  ## heights keep building: no air drops well below the one before
				grows = false
		ok = ok and grows and last >= MIN_LAST_PEAK and last - first >= MIN_GAIN
	rows.append(ok_line("halfpipe_pump_forward", ok,
		"%d airs, peaks above coping [%s] m (need no drop >%.2f from the previous air, last >=%.1f, gain >=%.1f), bails %d (need 0)"
		% [pk.size(), _fmt(pk), SLACK, MIN_LAST_PEAK, MIN_GAIN, r["bails"]]))
	var n: Dictionary = await _run_hp(NONE)
	var npk: Array = n["peaks"]
	var nmax: float = -99.0
	for v: Variant in npk:
		nmax = maxf(nmax, float(v))
	var nok: bool = npk.is_empty() or (nmax <= float(npk[0]) + 0.3 and nmax < MIN_LAST_PEAK)
	rows.append(ok_line("halfpipe_no_input_no_gain", nok,
		"%d airs, peaks [%s] m (need no peak >0.3 above the first, and none >=%.1f)" % [npk.size(), _fmt(npk), MIN_LAST_PEAK]))
	return rows
