class_name StreetRun
extends RefCounted
## Long street pieces for the south run. Same footprint rules as every park piece: origin on the ground at the back-left
## corner, x in [0, width], z in [0, length], riding direction +Z unless said otherwise.
##
##   downhill    a deck that rolls down a long, gentle S-curve to the ground (travel +Z). Zones: downhill_top, downhill_bottom.
##   long_ledge  StreetBits.ledge with a gap zone at each end: <prefix>_a (z = 0) and <prefix>_b (z = length).
##   long_rail   StreetBits.flat_rail with end zones <prefix>_a and <prefix>_b.
##   hubba_set   a launch ramp onto a platform, a stair set going down +Z and a long sloped hubba ledge beside it.
##               Zones: hubba_a (top of the ledge), hubba_b (bottom), plus "hubba_stairs_top/bottom" from the stairs.
##   bank_wall   a long bank (riding face +Z, ridden going -Z) with a tall wall behind its deck.

const DOWNHILL_STEPS: int = 36
const ZONE_H: float = 1.6
const HUBBA_W: float = 1.0
const HUBBA_TOP_EXTRA: float = 0.3
const HUBBA_END_H: float = 0.5
const STRIPE := Color("ffffff")


## Height of the S-curve at fraction t (0 at the top, 1 at the bottom): smoothstep, so it eases in and out.
static func downhill_y(t: float, drop: float) -> float:
	var s: float = clampf(t, 0.0, 1.0)
	return drop * (1.0 - s * s * (3.0 - 2.0 * s))


## Total z length of downhill(): the access ramp, the deck and the slope.
static func downhill_length(slope_len: float = 34.0, deck: float = 5.0, access_len: float = 10.0) -> float:
	return access_len + deck + slope_len


## A straight access ramp up to a deck (z 0 .. access_len), the deck, then a long gentle S-curve down to the ground.
static func downhill(slope_len: float = 34.0, drop: float = 3.5, width: float = 8.0, deck: float = 5.0, access_len: float = 10.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Downhill"
	var deck0: float = access_len
	var deck1: float = access_len + deck
	var end_z: float = deck1 + slope_len
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(drop, deck0), Vector2(drop, deck1)])
	for i: int in range(1, DOWNHILL_STEPS + 1):
		var t: float = float(i) / float(DOWNHILL_STEPS)
		prof.append(Vector2(downhill_y(t, drop), deck1 + t * slope_len))
	root.add_child(PieceKit.body(PieceKit.extrude_profile(prof, width), PieceKit.CONCRETE, "Slope"))
	root.add_child(_visual_box(Vector3(0.0, drop + 0.01, deck1 - 0.5), Vector3(width, 0.02, 0.4), PieceKit.PAINT_YELLOW, "EdgeStripe"))
	var n_chev: int = 6
	for k: int in n_chev:
		var t: float = (float(k) + 0.5) / float(n_chev)
		var mi := _visual_box(Vector3(-0.6, 0.0, -0.25), Vector3(1.2, 0.02, 0.5), STRIPE, "Chevron%d" % k)
		var dy: float = downhill_y(t + 0.01, drop) - downhill_y(t, drop)
		mi.transform = Transform3D(Basis(Vector3.RIGHT, atan2(-dy, 0.01 * slope_len)), Vector3(width * 0.5, downhill_y(t, drop) + 0.03, deck1 + t * slope_len))
		root.add_child(mi)
	root.add_child(PieceKit.gap_zone("downhill_top", Vector3(0.0, drop, deck1 - 1.0), Vector3(width, ZONE_H, 2.0)))
	root.add_child(PieceKit.gap_zone("downhill_bottom", Vector3(0.0, 0.0, end_z - 3.0), Vector3(width, ZONE_H, 3.0)))
	return root


static func long_ledge(length: float = 18.0, height: float = 0.5, depth: float = 0.8, color: Color = PieceKit.PAINT_PURPLE, zone_prefix: String = "long_ledge") -> Node3D:
	var root: Node3D = StreetBits.ledge(length, height, depth, color, "")
	root.name = "LongLedge"
	root.add_child(PieceKit.gap_zone(zone_prefix + "_a", Vector3(0.0, height, 0.0), Vector3(depth, ZONE_H, 0.6)))
	root.add_child(PieceKit.gap_zone(zone_prefix + "_b", Vector3(0.0, height, length - 0.6), Vector3(depth, ZONE_H, 0.6)))
	return root


static func long_rail(length: float = 22.0, height: float = 0.45, zone_prefix: String = "long_rail") -> Node3D:
	var root: Node3D = StreetBits.flat_rail(length, height, zone_prefix + "_a", zone_prefix + "_b")
	root.name = "LongRail"
	return root


## z where hubba_set's stair platform starts (the end of the launch ramp), and the full length.
static func hubba_ramp_len() -> float:
	return 6.0


static func hubba_length(steps: int = 10, step_run: float = 0.9, platform: float = 3.0) -> float:
	return hubba_ramp_len() + platform + float(steps) * step_run


static func hubba_set(steps: int = 10, step_rise: float = 0.2, step_run: float = 0.9, stair_width: float = 5.0) -> Node3D:
	var root := Node3D.new()
	root.name = "HubbaSet"
	var platform: float = 3.0
	var top_h: float = float(steps) * step_rise
	var z0: float = hubba_ramp_len()
	var end_z: float = z0 + platform + float(steps) * step_run
	var sx: float = HUBBA_W + 0.2  # stairs start to the right of the hubba ledge
	# launch ramp onto the platform
	var ramp := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, z0), Vector2(top_h, z0)])
	var ramp_body: StaticBody3D = PieceKit.body(PieceKit.extrude_profile(ramp, stair_width), PieceKit.RAMP_WOOD, "LaunchRamp")
	ramp_body.position = Vector3(sx, 0.0, 0.0)
	root.add_child(ramp_body)
	var stairs: Node3D = StairSet.build(stair_width, platform, steps, step_rise, step_run, "hubba_stairs")
	stairs.position = Vector3(sx, 0.0, z0)
	root.add_child(stairs)
	# the hubba: a sloped ledge, flat over the platform then falling to HUBBA_END_H at the foot of the stairs
	var h0: float = top_h + HUBBA_TOP_EXTRA
	var z1: float = z0 + platform
	var prof := PackedVector2Array([Vector2(0.0, z0), Vector2(h0, z0), Vector2(h0, z1), Vector2(HUBBA_END_H, end_z), Vector2(0.0, end_z)])
	root.add_child(PieceKit.body(PieceKit.extrude_profile(prof, HUBBA_W), PieceKit.PAINT_GREEN, "Hubba"))
	for x: float in [0.0, HUBBA_W]:
		root.add_child(PieceKit.rail(PackedVector3Array([Vector3(x, h0, z0), Vector3(x, h0, z1), Vector3(x, HUBBA_END_H, end_z)]), "ledge", "HubbaRail"))
	# a raised block under the ledge's top so it sits on the platform side (visual; the ledge prism is already solid)
	root.add_child(PieceKit.gap_zone("hubba_a", Vector3(0.0, h0, z0), Vector3(HUBBA_W, ZONE_H, 1.0)))
	root.add_child(PieceKit.gap_zone("hubba_b", Vector3(0.0, HUBBA_END_H, end_z - 1.5), Vector3(HUBBA_W, ZONE_H, 1.5)))
	return root


## A long bank, ridden going -Z, with a tall painted wall behind its deck (wall at z in [-thick, 0]).
static func bank_wall(length: float = 24.0, height: float = 1.6, bank_len: float = 4.0, wall_h: float = 3.0) -> Node3D:
	var root := Node3D.new()
	root.name = "BankWall"
	root.add_child(Walls.bank(length, bank_len, height, ""))
	var wall: Node3D = Walls.wallride_wall(length, wall_h, Walls.WALL_THICKNESS, "")
	wall.position = Vector3(0.0, 0.0, -Walls.WALL_THICKNESS)
	# the wall's riding face is +Z; its back face at z = -thickness
	root.add_child(wall)
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
