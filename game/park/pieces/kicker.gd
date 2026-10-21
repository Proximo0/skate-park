class_name Kicker
extends RefCounted
## A launch ramp. Footprint x in [0, width], z in [0, length]; rises toward -Z (ride it from +Z going -Z).


static func build(width: float = 2.0, length: float = 2.4, height: float = 0.9) -> Node3D:
	var root := Node3D.new()
	root.name = "Kicker"
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, length), Vector2(height * 0.15, length * 0.6), Vector2(height, 0.0)])
	root.add_child(PieceKit.body(PieceKit.extrude_profile(prof, width), PieceKit.PAINT_YELLOW, "Ramp"))
	return root
