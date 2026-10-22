class_name SchoolLamps
extends Node
## Dusk on the School level: the campus lamps (FlickerLights) come on one by one in the first seconds, each stuttering
## like a warming tube before it holds steady; one of them never quite settles. Deterministic (fixed schedule per lamp).

## Seconds before the first lamp starts, and between lamps.
const FIRST: float = 0.6
const STAGGER: float = 0.55
## How long a lamp stutters before it holds.
const WARM: float = 2.2
## Lamps (by index) that keep failing: the plaza's south-east lamp (seen from the spawn).
const FAULTY: Array[int] = [1]

var lamps: Array[FlickerLight] = []
var _t: float = 0.0


func _ready() -> void:
	for i: int in lamps.size():
		lamps[i].failing = true


func _process(delta: float) -> void:
	_t += delta
	var settled: bool = true
	for i: int in lamps.size():
		if FAULTY.has(i):
			continue
		var on_at: float = FIRST + STAGGER * float(i) + WARM
		if _t >= on_at:
			lamps[i].failing = false
		else:
			settled = false
	if settled:
		set_process(false)
