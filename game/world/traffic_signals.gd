class_name TrafficSignals
extends Node3D
## Signal heads for one Traffic intersection (visual only): a pole at each corner with a three-lamp head facing the
## traffic coming at it. Lamps glow with the live signal state (Traffic.signal_state). Six shared materials per
## intersection; about a dozen meshes in all.

const POLE := Color("2c3050")
const OFF := Color("2a2a34")

var traffic: Traffic
var index: int = 0
var _lamps: Dictionary = {}  ## "axis|colour" -> ShaderMaterial


static func build(t: Traffic, i: int) -> TrafficSignals:
	var sig := TrafficSignals.new()
	sig.name = "Signals%d" % i
	sig.traffic = t
	sig.index = i
	var it: Dictionary = t.intersections[i]
	var c: Vector3 = it["centre"]
	var r: float = float(it["radius"]) * 0.82
	for axis: int in 2:
		for col: String in ["red", "amber", "green"]:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = OFF
			sig._lamps["%d|%s" % [axis, col]] = m
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.09
	pole_mesh.bottom_radius = 0.11
	pole_mesh.height = 4.2
	pole_mesh.radial_segments = 8
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.42, 1.15, 0.32)
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.12
	lamp_mesh.height = 0.24
	lamp_mesh.radial_segments = 10
	lamp_mesh.rings = 5
	# corners: each faces traffic arriving along one axis
	var corners: Array = [[Vector3(r, 0, r), 0, Vector3(1, 0, 0)], [Vector3(-r, 0, -r), 0, Vector3(-1, 0, 0)],
		[Vector3(-r, 0, r), 1, Vector3(0, 0, 1)], [Vector3(r, 0, -r), 1, Vector3(0, 0, -1)]]
	for k: int in corners.size():
		var spec: Array = corners[k]
		var root := Node3D.new()
		root.name = "Pole%d" % k
		root.position = c + (spec[0] as Vector3)
		var face: Vector3 = spec[2]
		root.rotation.y = atan2(face.x, face.z)
		sig.add_child(root)
		var pole := MeshInstance3D.new()
		pole.mesh = pole_mesh
		pole.position = Vector3(0, 2.1, 0)
		pole.material_override = Toon.material(POLE, false)
		root.add_child(pole)
		var head := MeshInstance3D.new()
		head.mesh = head_mesh
		head.position = Vector3(0, 3.7, 0)
		head.material_override = Toon.material(Color("1d2033"), false)
		root.add_child(head)
		var cols: Array[String] = ["red", "amber", "green"]
		for j: int in 3:
			var lamp := MeshInstance3D.new()
			lamp.mesh = lamp_mesh
			lamp.position = Vector3(0, 4.07 - 0.36 * float(j), 0.15)
			lamp.material_override = sig._lamps["%d|%s" % [int(spec[1]), cols[j]]]
			root.add_child(lamp)
	return sig


func _process(_delta: float) -> void:
	if traffic == null:
		return
	var glow: Dictionary = {"red": Color(1.6, 0.15, 0.1), "amber": Color(1.6, 0.9, 0.1), "green": Color(0.2, 1.5, 0.5)}
	for axis: int in 2:
		var st: String = traffic.signal_state(index, axis)
		for col: String in ["red", "amber", "green"]:
			(_lamps["%d|%s" % [axis, col]] as StandardMaterial3D).albedo_color = glow[col] if col == st else OFF
