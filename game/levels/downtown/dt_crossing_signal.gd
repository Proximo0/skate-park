class_name DtCrossingSignal
extends Node3D
## A signalled mid-block crossing (visual): two poles on the sidewalks, each with a car signal (red/amber/green for the
## street's axis 0) facing the traffic and a walk/stop box facing the crosswalk. Reads Traffic.signal_state live.

const POLE := Color("2c3050")
const OFF := Color("2a2a34")

var traffic: Traffic
var index: int = 0
var _mats: Dictionary = {}


static func build(t: Traffic, i: int, centre: Vector3) -> DtCrossingSignal:
	var sig := DtCrossingSignal.new()
	sig.name = "CrossingSignal"
	sig.traffic = t
	sig.index = i
	for k: String in ["red", "amber", "green", "walk", "stop"]:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = OFF
		sig._mats[k] = m
	var bt := DtBatch.new()
	var off: float = DtPlan.ROAD_HALF + 1.2
	for s: float in [-1.0, 1.0]:
		var base := Vector3(centre.x + s * 5.5, DtPlan.P, centre.z + s * off)
		bt.cyl(base, 0.1, 4.0, POLE, 8)
		# head facing the traffic arriving on this side's lane (cars on the far side of the pole's lane come at it)
		var face := Vector3(-s, 0.0, 0.0)
		var head_c: Vector3 = base + Vector3(0.0, 3.55, 0.0) + face * 0.22
		bt.box(head_c, Vector3(0.32, 1.1, 0.42), Color("1d2033"), Basis(Vector3.UP, PI * 0.5))
		for j: int in 3:
			var lamp := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.12
			sm.height = 0.24
			sm.radial_segments = 10
			sm.rings = 5
			lamp.mesh = sm
			lamp.position = head_c + face * 0.17 + Vector3(0.0, 0.36 - 0.36 * float(j), 0.0)
			lamp.material_override = sig._mats[["red", "amber", "green"][j]]
			sig.add_child(lamp)
		# walk box facing across the street
		var wface := Vector3(0.0, 0.0, -s)
		var wc: Vector3 = base + Vector3(0.0, 2.6, 0.0) + wface * 0.18
		bt.box(wc, Vector3(0.36, 0.5, 0.2), Color("1d2033"))
		for j: int in 2:
			var q := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.24, 0.16, 0.02)
			q.mesh = bm
			q.position = wc + wface * 0.105 + Vector3(0.0, 0.1 - 0.2 * float(j), 0.0)
			q.material_override = sig._mats["stop" if j == 0 else "walk"]
			sig.add_child(q)
	sig.add_child(bt.instance("Poles", true))
	return sig


func _process(_delta: float) -> void:
	if traffic == null:
		return
	var st: String = traffic.signal_state(index, 0)
	(_mats["red"] as StandardMaterial3D).albedo_color = Color(1.6, 0.15, 0.1) if st == "red" else OFF
	(_mats["amber"] as StandardMaterial3D).albedo_color = Color(1.6, 0.9, 0.1) if st == "amber" else OFF
	(_mats["green"] as StandardMaterial3D).albedo_color = Color(0.2, 1.5, 0.5) if st == "green" else OFF
	(_mats["walk"] as StandardMaterial3D).albedo_color = Color(1.4, 1.5, 1.6) if st == "red" else OFF
	(_mats["stop"] as StandardMaterial3D).albedo_color = Color(1.7, 0.5, 0.1) if st != "red" else OFF
