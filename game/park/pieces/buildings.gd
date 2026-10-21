class_name Buildings
extends RefCounted
## Park-edge buildings with rideable roofs. Origin at ground level at the back-left corner, like every park piece.
## Shop footprint x in [0, width], z in [0, depth]; the front (+Z) face is the shop front. The roof is the solid top
## at y = height, bounded by a parapet whose inner top edges carry "ledge" rails. A quarter pipe sits on the back of
## the roof. The access ramp rises toward -Z (ride it from +Z going -Z), like Kicker, and is meant to be placed
## against a shop's side wall so its top meets the roof.

const PARAPET_H: float = 0.45
const PARAPET_T: float = 0.35
const ROOF_PIPE_RADIUS: float = 1.5
## Must stay above the radius: at height == radius QuarterPipe drops its flat deck.
const ROOF_PIPE_HEIGHT: float = 2.0
const ROOF_PIPE_DECK: float = 0.5
const RAMP_LIP: float = 0.6
const RAMP_WALL_T: float = 0.25
const RAMP_WALL_LIP: float = 0.35
const FACADE_T: float = 0.08
const GAP_ZONE_SIZE: Vector3 = Vector3(6.0, 3.0, 2.0)
const GAP_ZONE_Y: float = 4.0


## A cartoon shop: solid block with a rideable flat roof, parapet lip, ledge rails, door, windows, awning, sign,
## and a quarter pipe on the back of the roof.
static func shop(width: float = 10.0, depth: float = 8.0, height: float = 4.0, color: Color = PieceKit.PAINT_RED, sign_text: String = "SNACKS") -> Node3D:
	var root := Node3D.new()
	root.name = "Shop"
	var t: float = PARAPET_T
	var ph: float = PARAPET_H
	var top_y: float = height + ph
	# Solid walls. Their top face at y = height is the rideable roof (trimesh collision).
	root.add_child(PieceKit.box(Vector3.ZERO, Vector3(width, height, depth), color, "Walls"))
	# Parapet lip around the roof.
	root.add_child(PieceKit.box(Vector3(0.0, height, 0.0), Vector3(width, ph, t), PieceKit.CONCRETE, "ParapetBack"))
	root.add_child(PieceKit.box(Vector3(0.0, height, depth - t), Vector3(width, ph, t), PieceKit.CONCRETE, "ParapetFront"))
	root.add_child(PieceKit.box(Vector3(0.0, height, t), Vector3(t, ph, depth - 2.0 * t), PieceKit.CONCRETE, "ParapetLeft"))
	root.add_child(PieceKit.box(Vector3(width - t, height, t), Vector3(t, ph, depth - 2.0 * t), PieceKit.CONCRETE, "ParapetRight"))
	# Ledges on the inner top edges of the parapet. The back edge is under the quarter pipe, so it gets none.
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(t, top_y, t), Vector3(t, top_y, depth - t)]), "ledge", "LedgeLeft"))
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(t, top_y, depth - t), Vector3(width - t, top_y, depth - t)]), "ledge", "LedgeFront"))
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(width - t, top_y, depth - t), Vector3(width - t, top_y, t)]), "ledge", "LedgeRight"))
	# Quarter pipe on the roof along the back edge, riding toward +Z like the park's own pipes.
	var qp: Node3D = QuarterPipe.build(width - 1.0, ROOF_PIPE_RADIUS, ROOF_PIPE_HEIGHT, ROOF_PIPE_DECK)
	qp.position = Vector3(0.5, height, t)
	root.add_child(qp)
	# Front face: door and windows as coloured insets proud of the +Z face, then the awning. Visual only.
	root.add_child(_facade_box(Vector3(width * 0.12, 0.0, depth), Vector3(1.4, height * 0.55, FACADE_T), PieceKit.RAMP_WOOD, "Door"))
	root.add_child(_facade_box(Vector3(width * 0.42, height * 0.3, depth), Vector3(1.6, height * 0.35, FACADE_T), PieceKit.RAMP_SIDE, "WindowA"))
	root.add_child(_facade_box(Vector3(width * 0.7, height * 0.3, depth), Vector3(1.6, height * 0.35, FACADE_T), PieceKit.RAMP_SIDE, "WindowB"))
	root.add_child(_facade_box(Vector3(0.5, height * 0.7, depth), Vector3(width - 1.0, 0.25, 0.6), PieceKit.PAINT_GREEN, "Awning"))
	# Sign board above the awning, with its text on the board.
	root.add_child(_facade_box(Vector3(width * 0.2, height * 0.8, depth), Vector3(width * 0.6, 0.7, 0.12), PieceKit.METAL, "SignBoard"))
	var label := Label3D.new()
	label.name = "SignLabel"
	label.text = sign_text
	label.font_size = 64
	label.pixel_size = 0.008
	label.outline_size = 10
	label.modulate = Color("3a2a2a")
	label.position = Vector3(width * 0.5, height * 0.8 + 0.35, depth + 0.2)
	root.add_child(label)
	return root


## A long, gentle straight bank from the ground (z = length) up to roof height (z = 0), with a flat lip at the top
## so the skater can roll onto the roof. Side walls follow the bank and carry a "ledge" rail on each top edge.
static func roof_access_ramp(width: float = 4.0, length: float = 10.0, height: float = 4.0) -> Node3D:
	var root := Node3D.new()
	root.name = "RoofAccessRamp"
	var lip: float = RAMP_LIP
	var bank := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, length), Vector2(height, lip), Vector2(height, 0.0)])
	root.add_child(PieceKit.body(PieceKit.extrude_profile(bank, width), PieceKit.RAMP_WOOD, "Ramp"))
	# Side walls: the same bank shape, a little taller, and thin.
	var wt: float = RAMP_WALL_T
	var wall_top: float = height + RAMP_WALL_LIP
	var wall := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, length), Vector2(wall_top, lip), Vector2(wall_top, 0.0)])
	root.add_child(PieceKit.body(PieceKit.extrude_profile(wall, wt), PieceKit.RAMP_SIDE, "WallLeft"))
	var right_wall: StaticBody3D = PieceKit.body(PieceKit.extrude_profile(wall, wt), PieceKit.RAMP_SIDE, "WallRight")
	right_wall.position.x = width - wt
	root.add_child(right_wall)
	# Ledges on the top edge of each wall (the wall's sloped top line, at the middle of its thickness).
	var lx: float = wt * 0.5
	var rx: float = width - wt * 0.5
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(lx, 0.0, length), Vector3(lx, wall_top, lip), Vector3(lx, wall_top, 0.0)]), "ledge", "LedgeLeft"))
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(rx, 0.0, length), Vector3(rx, wall_top, lip), Vector3(rx, wall_top, 0.0)]), "ledge", "LedgeRight"))
	return root


## Two gap-detection zones for a roof gap: zone_a at x = 0 and zone_b at x = gap + 2, both at roof height (y = 4),
## each 6 m wide, 2 m deep and 3 m tall. The park layout places this node over a gap between two shops.
static func gap_pair(zone_a: String = "roof_west", zone_b: String = "roof_east", gap: float = 4.0) -> Node3D:
	var root := Node3D.new()
	root.name = "GapPair"
	root.add_child(PieceKit.gap_zone(zone_a, Vector3(0.0, GAP_ZONE_Y, 0.0), GAP_ZONE_SIZE))
	root.add_child(PieceKit.gap_zone(zone_b, Vector3(gap + 2.0, GAP_ZONE_Y, 0.0), GAP_ZONE_SIZE))
	return root


## A visual-only box (toon material, no collision) positioned by its minimum corner and size.
static func _facade_box(min_corner: Vector3, size: Vector3, color: Color, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = Toon.material(color)
	mi.position = min_corner + size * 0.5
	return mi
