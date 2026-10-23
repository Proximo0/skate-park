class_name StairSet
extends RefCounted
## Reference-style park piece: a raised platform with a stair set running down toward +Z to the ground.
## Footprint x in [0, width], z in [0, platform_depth + steps * step_run]; the riding face looks toward +Z.
## The step boxes are visual only. A hidden smooth slope (convex wedge through every nosing) carries the skater
## down like a bank. A handrail runs down the +X side (x = width - 0.6) 0.9 m above the nosings, and a low ledge
## runs down the -X side. Gap zones: <zone_prefix>_top above the platform front, <zone_prefix>_bottom past the stairs.

const LEDGE_W: float = 0.3  # the ledge strip along x = 0; the stairs span x in [LEDGE_W, width]
const LEDGE_MAX_H: float = 0.6  # ledge top height at the platform edge
const RAIL_X_OFFSET: float = 0.6  # handrail sits this far in from the right edge
const RAIL_HEIGHT: float = 0.9  # handrail height above the step nosing
const RAIL_FLAT_BACK: float = 0.6  # how far the flat handrail runs back onto the platform
const RAIL_PAST_BOTTOM: float = 0.4  # how far the sloped handrail runs past the last step
const PIPE_RADIUS: float = 0.03
const POST_RADIUS: float = 0.04


static func build(width: float = 5.0, platform_depth: float = 4.0, steps: int = 6, step_rise: float = 0.25, step_run: float = 0.45, zone_prefix: String = "stair") -> Node3D:
	var root := Node3D.new()
	root.name = "StairSet"
	var n_steps: int = maxi(steps, 1)
	var top_h: float = float(n_steps) * step_rise
	var pd: float = platform_depth
	var end_z: float = pd + float(n_steps) * step_run
	var run_w: float = width - LEDGE_W

	# Platform: solid box, top at top_h.
	root.add_child(PieceKit.box(Vector3(0.0, 0.0, 0.0), Vector3(width, top_h, pd), PieceKit.CONCRETE, "Platform"))

	# Step visuals. Tread i sits at top_h - (i + 1) * step_rise; the last tread is the ground, so it needs no box.
	# No collision here: the skater rides SlopeCollision instead.
	var steps_node := Node3D.new()
	steps_node.name = "Steps"
	root.add_child(steps_node)
	for i: int in n_steps:
		var tread_top: float = top_h - float(i + 1) * step_rise
		if tread_top <= 0.001:
			continue
		var z0: float = pd + float(i) * step_run
		var z1: float = pd + float(i + 1) * step_run
		var bm := BoxMesh.new()
		bm.size = Vector3(run_w, tread_top, step_run)
		var mi := MeshInstance3D.new()
		mi.name = "Step%d" % (i + 1)
		mi.mesh = bm
		mi.material_override = Toon.material(PieceKit.CONCRETE)
		mi.position = Vector3(LEDGE_W + run_w * 0.5, tread_top * 0.5, (z0 + z1) * 0.5)
		steps_node.add_child(mi)

	# Hidden smooth slope: a convex wedge under the line from the platform front top edge to the ground at end_z.
	# That line passes through every nosing, so the skater rolls over the stairs as one bank.
	var slope_body := StaticBody3D.new()
	slope_body.name = "SlopeCollision"
	var slope_cs := CollisionShape3D.new()
	slope_cs.name = "Collision"
	var wedge := ConvexPolygonShape3D.new()
	var wedge_pts := PackedVector3Array()
	for x: float in [LEDGE_W, width]:
		wedge_pts.append(Vector3(x, 0.0, pd))
		wedge_pts.append(Vector3(x, top_h, pd))
		wedge_pts.append(Vector3(x, 0.0, end_z))
	wedge.points = wedge_pts
	slope_cs.shape = wedge
	slope_body.add_child(slope_cs)
	root.add_child(slope_body)

	# Low ledge along the -X side: a wedge whose top outer edge (x = 0) follows the slope down to the ground.
	var ledge_h: float = minf(LEDGE_MAX_H, top_h)
	var ledge_prof := PackedVector2Array([Vector2(0.0, pd), Vector2(ledge_h, pd), Vector2(0.0, end_z)])  # (y, z)
	root.add_child(PieceKit.body(PieceKit.extrude_profile(ledge_prof, LEDGE_W), PieceKit.RAMP_SIDE, "Ledge"))
	var ledge_mid_z: float = (pd + end_z) * 0.5
	root.add_child(PieceKit.rail(PackedVector3Array([
		Vector3(0.0, ledge_h, pd),
		Vector3(0.0, ledge_h * 0.5, ledge_mid_z),
		Vector3(0.0, 0.0, end_z),
	]), "ledge", "LedgeRail"))

	# Handrail on the +X side: flat top segment, then the slope, as ONE 3-point GrindRail. The middle point sits at
	# the top step (platform front edge).
	var rail_x: float = width - RAIL_X_OFFSET
	var flat_start_z: float = maxf(0.0, pd - RAIL_FLAT_BACK)
	var rail_top_y: float = top_h + RAIL_HEIGHT
	var p0 := Vector3(rail_x, rail_top_y, flat_start_z)
	var p1 := Vector3(rail_x, rail_top_y, pd)
	var bottom_z: float = end_z + RAIL_PAST_BOTTOM
	var p2 := Vector3(rail_x, _stair_slope_y(bottom_z, top_h, pd, step_rise, step_run) + RAIL_HEIGHT, bottom_z)
	# Visible pipes for both segments. round_rail brings its own GrindRail; keep only the pipe mesh.
	root.add_child(_stair_pipe(p0, p1, "HandrailFlat"))
	root.add_child(_stair_pipe(p1, p2, "HandrailSlope"))
	root.add_child(PieceKit.rail(PackedVector3Array([p0, p1, p2]), "rail", "HandRail"))

	# Posts: one on the platform, then one under each nosing (base on the slope line, clamped to the stair).
	root.add_child(_stair_post(rail_x, pd - 0.3, top_h, top_h + RAIL_HEIGHT, "PostPlatform"))
	for i: int in n_steps:
		var z: float = pd + float(i + 1) * step_run
		var base: float = clampf(_stair_slope_y(z, top_h, pd, step_rise, step_run), 0.0, top_h)
		root.add_child(_stair_post(rail_x, z, base, base + RAIL_HEIGHT, "Post%d" % (i + 1)))

	# Gap zones. Top: box above the platform front edge, full width. Bottom: ground box past the last step, 2 m deep.
	root.add_child(PieceKit.gap_zone(zone_prefix + "_top", Vector3(0.0, top_h + 0.2, pd - 0.6), Vector3(width, 1.6, 1.2)))
	root.add_child(PieceKit.gap_zone(zone_prefix + "_bottom", Vector3(0.0, 0.0, end_z), Vector3(width, 1.5, 2.0)))
	return root


## Height of the slope line (through the platform front top edge and the ground at the stairs' end) at z.
static func _stair_slope_y(z: float, top_h: float, pd: float, step_rise: float, step_run: float) -> float:
	return top_h - (z - pd) * step_rise / step_run


## A visible pipe between two points, without its GrindRail (the piece's single HandRail carries the grind line).
static func _stair_pipe(a: Vector3, b: Vector3, node_name: String) -> Node3D:
	var pipe: Node3D = PieceKit.round_rail(a, b, PIPE_RADIUS, PieceKit.METAL, node_name)
	var line: Node = pipe.get_node("Line")
	pipe.remove_child(line)
	line.free()
	return pipe


## A vertical post from base_y up to top_y at (x, z).
static func _stair_post(x: float, z: float, base_y: float, top_y: float, node_name: String) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = POST_RADIUS
	cyl.bottom_radius = POST_RADIUS
	cyl.height = maxf(top_y - base_y, 0.01)
	cyl.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = cyl
	mi.material_override = Toon.material(PieceKit.METAL)
	mi.position = Vector3(x, (base_y + top_y) * 0.5, z)
	return mi
