class_name HalfPipe
extends RefCounted
## Park piece: a vert half pipe, two quarter-pipe walls facing each other across a flat bottom (like THUG's).
## Footprint x in [0, width], z in [0, 2 * (deck + radius) + flat]. Wall A sits at z = 0 and faces +Z, wall B is
## the same wall turned 180 degrees about Y at the far end. Each wall has a deck at the back, coping on its lip
## (a "coping" GrindRail at y = height), side plates and a safety rail fence along the back of the deck.


const SIDE_T: float = 0.2  # thickness of the side plates at each end
const ARC_STEPS: int = 16
const FENCE_POSTS: int = 5  # spacing = width / FENCE_POSTS
const FENCE_H: float = 0.9
const FENCE_BAR: float = 0.07


static func build(width: float = 10.0, flat: float = 6.0, radius: float = 3.5, height: float = 4.0, deck: float = 2.0) -> Node3D:
	var root := Node3D.new()
	root.name = "HalfPipe"
	var length: float = 2.0 * (deck + radius) + flat
	var wall_a: Node3D = _wall(width, deck, radius, height)
	root.add_child(wall_a)
	var wall_b: Node3D = _wall(width, deck, radius, height)
	wall_b.name = "WallB"
	wall_b.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	wall_b.position = Vector3(width, 0.0, length)
	root.add_child(wall_b)
	# The flat bottom rides on the park ground; this is a thin painted skin just above it (no collision), so
	# the two surfaces never share a plane and z-fight.
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(width, 0.01, flat)
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Floor"
	floor_mi.mesh = floor_mesh
	floor_mi.material_override = Toon.material(PieceKit.RAMP_WOOD)
	floor_mi.position = Vector3(width * 0.5, 0.005, deck + radius + flat * 0.5)
	root.add_child(floor_mi)
	# two painted stripes across the flat bottom (decorative, no collision)
	for i: int in 2:
		var z: float = deck + radius + flat * float(i + 1) / 3.0
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(width - 2.0 * SIDE_T, 0.02, 0.35)
		var stripe := MeshInstance3D.new()
		stripe.name = "Stripe%d" % i
		stripe.mesh = stripe_mesh
		stripe.material_override = Toon.material(PieceKit.PAINT_RED)
		stripe.position = Vector3(width * 0.5, 0.01, z)
		root.add_child(stripe)
	return root


## One quarter-pipe wall in its own space: deck at z in [0, deck], curve up to the lip at z = deck, footprint
## z in [0, deck + radius], riding face toward +Z.
static func _wall(width: float, deck: float, radius: float, height: float) -> Node3D:
	var prof: PackedVector2Array = _wall_profile(deck, radius, height)
	var wall := Node3D.new()
	wall.name = "WallA"
	var ramp: StaticBody3D = PieceKit.body(PieceKit.extrude_profile(prof, width - 2.0 * SIDE_T), PieceKit.RAMP_WOOD, "Ramp")
	ramp.position.x = SIDE_T
	wall.add_child(ramp)
	wall.add_child(PieceKit.body(PieceKit.extrude_profile(prof, SIDE_T), PieceKit.RAMP_SIDE, "SideLeft"))
	var side_right: StaticBody3D = PieceKit.body(PieceKit.extrude_profile(prof, SIDE_T), PieceKit.RAMP_SIDE, "SideRight")
	side_right.position.x = width - SIDE_T
	wall.add_child(side_right)
	wall.add_child(PieceKit.rail(PackedVector3Array([Vector3(0.0, height, deck), Vector3(width, height, deck)]), "coping", "Coping"))
	var pipe: Node3D = PieceKit.round_rail(Vector3(0.0, height, deck), Vector3(width, height, deck), 0.05, PieceKit.COPING, "CopingPipe")
	# the visual pipe only; the GrindRail above is the coping line
	pipe.get_node("Line").free()
	wall.add_child(pipe)
	wall.add_child(_fence(width, height))
	return wall


## Profile (y, z) of one wall, the same shape as QuarterPipe, closed along the bottom and back.
static func _wall_profile(deck: float, radius: float, height: float) -> PackedVector2Array:
	var prof := PackedVector2Array()
	prof.append(Vector2(0.0, 0.0))
	prof.append(Vector2(0.0, deck + radius))
	for i: int in range(1, ARC_STEPS + 1):
		var th: float = PI * 0.5 * float(i) / float(ARC_STEPS)
		prof.append(Vector2(radius - radius * cos(th), deck + radius - radius * sin(th)))
	if height > radius:
		prof.append(Vector2(height, deck))
	prof.append(Vector2(height, 0.0))
	return prof


## Safety rail along the back edge (z = 0) of a deck: posts plus two bars, all solid boxes.
static func _fence(width: float, height: float) -> Node3D:
	var fence := Node3D.new()
	fence.name = "Fence"
	var post: float = 0.08
	for i: int in FENCE_POSTS + 1:
		var x: float = clampf(width * float(i) / float(FENCE_POSTS) - post * 0.5, 0.0, width - post)
		fence.add_child(PieceKit.box(Vector3(x, height, 0.0), Vector3(post, FENCE_H, post), PieceKit.METAL, "Post%d" % i))
	fence.add_child(PieceKit.box(Vector3(0.0, height + FENCE_H * 0.5 - FENCE_BAR * 0.5, 0.0), Vector3(width, FENCE_BAR, FENCE_BAR), PieceKit.METAL, "RailMid"))
	fence.add_child(PieceKit.box(Vector3(0.0, height + FENCE_H - FENCE_BAR, 0.0), Vector3(width, FENCE_BAR, FENCE_BAR), PieceKit.METAL, "RailTop"))
	return fence
