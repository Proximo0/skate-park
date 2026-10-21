class_name Kicker
extends RefCounted
## A launch ramp. Footprint x in [0, width], z in [0, length]; rises toward -Z (ride it from +Z going -Z).


## Warmer amber than PAINT_YELLOW: the pure yellow clipped to #FFFF00 once lit. The lip is a pale cream edge so the take-off line reads.
const AMBER := Color("e79a2e")
const LIP := Color("fff0cf")
const LIP_WIDTH: float = 0.1


static func build(width: float = 2.0, length: float = 2.4, height: float = 0.9) -> Node3D:
	var root := Node3D.new()
	root.name = "Kicker"
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, length), Vector2(height * 0.15, length * 0.6), Vector2(height, 0.0)])
	root.add_child(PieceKit.body(PieceKit.extrude_profile(prof, width), AMBER, "Ramp"))
	# cream lip along the take-off edge (visual only): the sloped top ends at height `height` at z = 0
	var lip := MeshInstance3D.new()
	lip.name = "Lip"
	var lm := BoxMesh.new()
	lm.size = Vector3(width, 0.04, LIP_WIDTH)
	lip.mesh = lm
	lip.position = Vector3(width * 0.5, height - 0.02, LIP_WIDTH * 0.5)
	lip.material_override = Toon.material(LIP, false)
	root.add_child(lip)
	return root
