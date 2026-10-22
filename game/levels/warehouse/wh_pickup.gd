class_name WhPickup
extends Collectible
## Warehouse pickups: the usual letter coins (S-K-A-T-E, gap coins), plus a spray can ("can") and the secret VHS tape
## ("tape") built in code. Same pickup behaviour as Collectible (spin, bob, near-camera fade, pop).

const CAN_BODY := Color("ff4f8b")
const CAN_CAP := Color("f2f2f2")
const TAPE_BODY := Color("1d1b24")
const TAPE_LABEL := Color("ffcf3a")


static func make(item_id: String, group: String, pos: Vector3) -> WhPickup:
	var c := WhPickup.new()
	c.item = item_id
	c.group_id = group
	c.position = pos
	return c


func _build_letter() -> void:
	if item == "can":
		_build_can()
	elif item == "tape":
		_build_tape()
	else:
		super._build_letter()


func _build_can() -> void:
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.13
	cyl.bottom_radius = 0.13
	cyl.height = 0.5
	cyl.radial_segments = 12
	body.mesh = cyl
	body.material_override = Toon.material(CAN_BODY, false)
	_visual.add_child(body)
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.135
	bm.bottom_radius = 0.135
	bm.height = 0.12
	bm.radial_segments = 12
	band.mesh = bm
	band.material_override = Toon.material(Color("ffe14d"), false)
	_visual.add_child(band)
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.11
	cm.height = 0.14
	cm.radial_segments = 10
	cap.mesh = cm
	cap.position.y = 0.32
	cap.material_override = Toon.material(CAN_CAP, false)
	_visual.add_child(cap)
	_visual.scale = Vector3.ONE * 1.3


func _build_tape() -> void:
	var shell := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.75, 0.42, 0.11)
	shell.mesh = b
	shell.material_override = Toon.material(TAPE_BODY, false)
	_visual.add_child(shell)
	var label := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.6, 0.16, 0.115)
	label.mesh = lb
	label.position.y = 0.08
	label.material_override = Toon.material(TAPE_LABEL, false)
	_visual.add_child(label)
	for sx: float in [-0.17, 0.17]:
		var reel := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.07
		rm.bottom_radius = 0.07
		rm.height = 0.12
		rm.radial_segments = 10
		reel.mesh = rm
		reel.rotation_degrees.x = 90.0
		reel.position = Vector3(sx, -0.07, 0.0)
		reel.material_override = Toon.material(Color("f4f0e6"), false)
		_visual.add_child(reel)
