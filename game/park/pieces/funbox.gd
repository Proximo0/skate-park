class_name FunBox
extends RefCounted
## The classic centre-of-park box. Footprint x in [0, width], z in [0, top_length + 2 * bank_length].
## Bank up along z in [0, bank_length], flat top, bank down. Grindable ledges sit on both long top edges;
## a flat round rail runs down the middle on two posts. Gap zones "<prefix>_a" and "<prefix>_b" sit over
## the bottom ends of the two banks, so flying from one to the other is "Over The Funbox".

const SIDE_THICK: float = 0.06  ## purple side panels
const SLAB_THICK: float = 0.1  ## concrete top skin
const TRIM_WIDTH: float = 0.08  ## metal angle-iron trim on each top edge
const TRIM_HEIGHT: float = 0.02
const RAIL_HEIGHT: float = 0.45  ## mid rail sits this far above the top
const RAIL_RADIUS: float = 0.04
const POST_SIZE: float = 0.08
const ZONE_DEPTH: float = 1.5
const ZONE_HEIGHT: float = 2.5


static func build(width: float = 4.0, top_length: float = 5.0, bank_length: float = 3.0, height: float = 1.0, zone_prefix: String = "funbox") -> Node3D:
	var root := Node3D.new()
	root.name = "FunBox"
	var bank_end: float = bank_length
	var top_end: float = bank_length + top_length
	var total_z: float = top_length + 2.0 * bank_length
	var inner_w: float = width - 2.0 * SIDE_THICK
	var slab: float = minf(SLAB_THICK, height * 0.5)

	# Banks: solid wedges, inset between the side panels.
	var up_prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(height, bank_end), Vector2(0.0, bank_end)])  # (y, z)
	var bank_up: StaticBody3D = PieceKit.body(PieceKit.extrude_profile(up_prof, inner_w), PieceKit.RAMP_WOOD, "BankUp")
	bank_up.position.x = SIDE_THICK
	root.add_child(bank_up)
	var down_prof := PackedVector2Array([Vector2(height, top_end), Vector2(0.0, total_z), Vector2(0.0, top_end)])
	var bank_down: StaticBody3D = PieceKit.body(PieceKit.extrude_profile(down_prof, inner_w), PieceKit.RAMP_WOOD, "BankDown")
	bank_down.position.x = SIDE_THICK
	root.add_child(bank_down)

	# Purple side panels following the whole outline, on both long sides.
	var outline := PackedVector2Array([Vector2(0.0, 0.0), Vector2(height, bank_end), Vector2(height, top_end), Vector2(0.0, total_z)])
	var side_left: StaticBody3D = PieceKit.body(PieceKit.extrude_profile(outline, SIDE_THICK), PieceKit.PAINT_PURPLE, "SideLeft")
	root.add_child(side_left)
	var side_right: StaticBody3D = PieceKit.body(PieceKit.extrude_profile(outline, SIDE_THICK), PieceKit.PAINT_PURPLE, "SideRight")
	side_right.position.x = width - SIDE_THICK
	root.add_child(side_right)

	# Flat top: purple core below, concrete skin on top.
	root.add_child(PieceKit.box(Vector3(SIDE_THICK, 0.0, bank_end), Vector3(inner_w, height - slab, top_length), PieceKit.PAINT_PURPLE, "DeckCore"))
	root.add_child(PieceKit.box(Vector3(SIDE_THICK, height - slab, bank_end), Vector3(inner_w, slab, top_length), PieceKit.CONCRETE, "DeckTop"))

	# Metal angle-iron trim on the top corners (visual and collision), with the ledge rails on the top corner line.
	root.add_child(PieceKit.box(Vector3(0.0, height, bank_end), Vector3(TRIM_WIDTH, TRIM_HEIGHT, top_length), PieceKit.METAL, "TrimLeft"))
	root.add_child(PieceKit.box(Vector3(width - TRIM_WIDTH, height, bank_end), Vector3(TRIM_WIDTH, TRIM_HEIGHT, top_length), PieceKit.METAL, "TrimRight"))
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(0.0, height, bank_end), Vector3(0.0, height, top_end)]), "ledge", "LedgeLeft"))
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(width, height, bank_end), Vector3(width, height, top_end)]), "ledge", "LedgeRight"))

	# Mid rail on two posts, running along the top.
	var mid_x: float = width * 0.5
	var rail_y: float = height + RAIL_HEIGHT
	var post_inset: float = minf(0.4, top_length * 0.25)
	var post_z0: float = bank_end + post_inset
	var post_z1: float = top_end - post_inset
	root.add_child(PieceKit.box(Vector3(mid_x - POST_SIZE * 0.5, height, post_z0 - POST_SIZE * 0.5), Vector3(POST_SIZE, RAIL_HEIGHT, POST_SIZE), PieceKit.METAL, "PostA"))
	root.add_child(PieceKit.box(Vector3(mid_x - POST_SIZE * 0.5, height, post_z1 - POST_SIZE * 0.5), Vector3(POST_SIZE, RAIL_HEIGHT, POST_SIZE), PieceKit.METAL, "PostB"))
	root.add_child(PieceKit.round_rail(Vector3(mid_x, rail_y, post_z0), Vector3(mid_x, rail_y, post_z1), RAIL_RADIUS, PieceKit.METAL, "MidRail"))

	# Gap zones over the bottom end of each bank.
	root.add_child(PieceKit.gap_zone(zone_prefix + "_a", Vector3(0.0, 0.0, 0.0), Vector3(width, ZONE_HEIGHT, ZONE_DEPTH)))
	root.add_child(PieceKit.gap_zone(zone_prefix + "_b", Vector3(0.0, 0.0, total_z - ZONE_DEPTH), Vector3(width, ZONE_HEIGHT, ZONE_DEPTH)))
	return root
