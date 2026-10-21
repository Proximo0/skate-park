class_name DropRamp
extends RefCounted
## A tall start deck with a smooth concave roll-in, built to feed the loop with speed. Footprint x in [0, width],
## z in [0, length()], ground at y = 0. THE SKATER TRAVELS ALONG +Z, like MegaRamp.
##
##   start deck  y = start_height, z in [0, DECK_LEN]       drop-in spot; the tower under it is filled to the ground
##   roll-in     60 deg arc from the deck edge down to the ground (body "RollIn"), visual side rails along it
##   run         `flat_len` metres of floor after the arc ends, level with the ground
##
## The arc is the same as MegaRamp's roll-in: radius 2 * start_height, so it starts steep and eases to flat. Rails,
## ladder and the striped deck edge are visual only.

const DECK_LEN: float = 4.0  ## start deck depth (z 0 to 4)
const DROP_Z: float = 2.5  ## drop-in spot on the deck: this far from the back edge (1.5 m from the lip)
const ROLL_STEPS: int = 40
const SIDE_RAIL_H: float = 0.9
const SIDE_RAIL_INSET: float = 0.15
const LADDER_X0: float = 0.4
const LADDER_X1: float = 1.2
const LADDER_RUNG: float = 0.5
const STRIPE := Color("ff7a00")


static func _roll_len(start_height: float) -> float:
	return 2.0 * start_height * sin(deg_to_rad(60.0))


## Total footprint length along Z: the deck, the roll-in and the flat run.
static func length(_width: float = 4.0, start_height: float = 12.0, flat_len: float = 2.0) -> float:
	return DECK_LEN + _roll_len(start_height) + flat_len


## z where the roll-in reaches the ground.
static func roll_end(start_height: float = 12.0) -> float:
	return DECK_LEN + _roll_len(start_height)


## Where the skater spawns on the start deck: DROP_Z from the back edge, middle of the width, facing +Z.
static func drop_in_transform(width: float = 4.0, start_height: float = 12.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), Vector3(width * 0.5, start_height, DROP_Z))


## The (y, z) profile of the roll-in arc from the deck edge (y = start_height, z = DECK_LEN) to the ground.
static func roll_curve(start_height: float) -> PackedVector2Array:
	var r: float = 2.0 * start_height
	var a0: float = deg_to_rad(60.0)
	var pts := PackedVector2Array()
	for i: int in ROLL_STEPS + 1:
		var phi: float = a0 * (1.0 - float(i) / float(ROLL_STEPS))
		pts.append(Vector2(start_height - r * (cos(phi) - cos(a0)), DECK_LEN + r * (sin(a0) - sin(phi))))
	return pts


static func build(width: float = 4.0, start_height: float = 12.0, flat_len: float = 2.0) -> Node3D:
	var root := Node3D.new()
	root.name = "DropRamp"
	var curve: PackedVector2Array = roll_curve(start_height)
	# Solid profile (y, z): back bottom, back top (the deck), the arc, then the ground back to the start.
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(start_height, 0.0)])
	for p: Vector2 in curve:
		prof.append(p)
	root.add_child(PieceKit.body(PieceKit.extrude_profile(prof, width), PieceKit.RAMP_SIDE, "RollIn"))
	var end_z: float = roll_end(start_height)
	if flat_len > 0.0:
		root.add_child(PieceKit.box(Vector3(0.0, -0.5, end_z), Vector3(width, 0.5, flat_len), PieceKit.CONCRETE, "RunFloor"))
	for x: float in [SIDE_RAIL_INSET, width - SIDE_RAIL_INSET]:
		var i: int = 0
		while i < ROLL_STEPS:
			var j: int = mini(i + 4, ROLL_STEPS)
			var a := Vector3(x, curve[i].x + SIDE_RAIL_H, curve[i].y)
			var b := Vector3(x, curve[j].x + SIDE_RAIL_H, curve[j].y)
			var rail: Node3D = PieceKit.round_rail(a, b, 0.04, PieceKit.METAL, "SideRail%d" % i)
			rail.get_node("Line").free()
			root.add_child(rail)
			i = j
	# an orange stripe on the deck edge, so the drop-in spot reads from far away
	root.add_child(_visual_box(Vector3(0.0, start_height + 0.01, DECK_LEN - 0.5), Vector3(width, 0.02, 0.4), STRIPE, "EdgeStripe"))
	# ladder up the back of the tower
	for lx: float in [LADDER_X0, LADDER_X1]:
		root.add_child(_visual_box(Vector3(lx - 0.06, 0.0, -0.14), Vector3(0.12, start_height, 0.1), PieceKit.METAL, "LadderRail"))
	var rung_y: float = LADDER_RUNG
	while rung_y < start_height - 0.5:
		root.add_child(_visual_box(Vector3(LADDER_X0, rung_y, -0.12), Vector3(LADDER_X1 - LADDER_X0, 0.05, 0.08), PieceKit.METAL, "Rung"))
		rung_y += LADDER_RUNG
	return root


static func _visual_box(min_corner: Vector3, size: Vector3, color: Color, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Toon.material(color)
	mi.position = min_corner + size * 0.5
	return mi
