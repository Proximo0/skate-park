class_name QuarterPipe
extends RefCounted
## Reference park piece. Footprint x in [0, width], z in [0, deck + radius]; the curved face looks toward +Z.
## The top deck runs from z = 0 to z = deck; coping sits on the lip at (y = height, z = deck).


static func build(width: float = 8.0, radius: float = 3.0, height: float = 3.2, deck: float = 1.5, steps: int = 16) -> Node3D:
	var root := Node3D.new()
	root.name = "QuarterPipe"
	var prof := PackedVector2Array()  # (y, z)
	prof.append(Vector2(0.0, 0.0))
	prof.append(Vector2(0.0, deck + radius))
	for i: int in range(1, steps + 1):
		var th: float = PI * 0.5 * float(i) / float(steps)
		prof.append(Vector2(radius - radius * cos(th), deck + radius - radius * sin(th)))
	if height > radius:
		prof.append(Vector2(height, deck))
	prof.append(Vector2(height, 0.0))
	root.add_child(PieceKit.body(PieceKit.extrude_profile(prof, width), PieceKit.RAMP_WOOD, "Ramp"))
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(0.0, height, deck), Vector3(width, height, deck)]), "coping", "Coping"))
	root.add_child(RampLip.line(PackedVector3Array([Vector3(0.0, height, deck), Vector3(width, height, deck)]), Vector3.BACK))
	var cop := PieceKit.round_rail(Vector3(0.0, height, deck), Vector3(width, height, deck), 0.05, PieceKit.COPING, "CopingPipe")
	# the visual pipe only; the GrindRail above is the coping line
	cop.get_node("Line").queue_free()
	root.add_child(cop)
	return root
