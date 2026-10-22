class_name HillsChannel
extends RefCounted
## The hillside water channel: a straight concrete flood-control ditch running down the hill along z (north to south)
## with 45 degree banks, rounded toes, flat concrete lips and a trickle of water down the middle. It fills a
## grid-aligned strip of the ground exactly: the ground is cut out over x in [cx - HALF, cx + HALF] and its edge
## vertices sit at the lip height, which is what the channel's own mesh has there.
##
## At the top end a flat basin under a headwall with the culvert pipe (the level's spawn: its floor is a box). At the
## bottom end the banks shrink to nothing and the floor runs out onto the park ("the spill").

const HALF: float = 4.0  ## half width: lip edge to lip edge is 8 m (two ground cells each side of the banks)
const DEPTH: float = 1.6
const LIP_IN: float = 2.8  ## where the flat lip ends and the bank starts (from the centre line)
const FLOOR_HALF: float = 0.87  ## flat floor either side of the centre, before the toe fillet
const TOE_R: float = 0.8
const CONCRETE := Color("bdb6a8")
const FLOOR_C := Color("a39d90")
const WATER := Color("6f9fb0")

var cx: float = 60.0
var z_head: float = -70.0  ## the headwall's face
var z_top: float = -62.0  ## end of the flat basin, start of the slope
var z_taper: float = 34.0  ## banks start shrinking here
var z_end: float = 48.0  ## the spill: no banks left
var floor_top: float = 21.0  ## floor height at z_top (and in the basin)
var floor_end: float = 8.5  ## floor height at z_end


## Floor height at z.
func floor_at(z: float) -> float:
	if z <= z_top:
		return floor_top
	return lerpf(floor_top, floor_end, clampf((z - z_top) / (z_end - z_top), 0.0, 1.0))


## Bank depth at z (DEPTH, shrinking to 0 over the spill).
func depth_at(z: float) -> float:
	return DEPTH * (1.0 - smoothstep(z_taper, z_end, z))


func lip_at(z: float) -> float:
	return floor_at(z) + depth_at(z)


## The cross-section as (|x| from the centre, height above the floor at full depth), from the centre out to HALF.
static func section() -> PackedVector2Array:
	var out := PackedVector2Array([Vector2(0.0, 0.0), Vector2(FLOOR_HALF * 0.5, 0.0), Vector2(FLOOR_HALF, 0.0)])
	for k: int in range(1, 5):
		var ph: float = deg_to_rad(45.0) * float(k) / 4.0
		out.append(Vector2(FLOOR_HALF + TOE_R * sin(ph), TOE_R - TOE_R * cos(ph)))
	# straight 45 degree bank up to just under the lip, then a small round onto the lip
	out.append(Vector2(LIP_IN - 0.14, DEPTH - 0.14))
	out.append(Vector2(LIP_IN - 0.04, DEPTH - 0.025))
	out.append(Vector2(LIP_IN + 0.06, DEPTH))
	out.append(Vector2(HALF, DEPTH))
	return out


## Corridor points (lip height) for the ground: x = cx, from the headwall to the spill.
func corridor_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	var z: float = z_head - 1.0
	while z < z_end:
		out.append(Vector3(cx, lip_at(z), z))
		z += 2.0
	out.append(Vector3(cx, lip_at(z_end), z_end))
	return out


## Cuts the strip out of the ground and pins its edge vertices to the lip heights.
func shape_ground(t: HillsTerrain) -> void:
	t.cut_hole(Rect2(cx - HALF, z_head, HALF * 2.0, z_end - z_head))
	var z: float = z_head
	while z <= z_end + 0.001:
		t.set_vertex(cx - HALF, z, lip_at(z))
		t.set_vertex(cx + HALF, z, lip_at(z))
		z += 1.0
	# the spill's last row lies flat at the floor (park) height
	var x: float = cx - HALF
	while x <= cx + HALF + 0.001:
		t.set_vertex(x, z_end, floor_at(z_end))
		x += 1.0


## Builds the channel: concrete shell (collision), basin floor box (the spawn's floor), headwall with the culvert, the
## water trickle, grind lines along both lips and the gap zones. Level space (the node sits at the origin).
func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Channel"
	var sec: PackedVector2Array = HillsChannel.section()
	# the cross-section mirrored, from -HALF to +HALF
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	for k: int in range(sec.size() - 1, 0, -1):
		xs.append(-sec[k].x)
		ys.append(sec[k].y)
	for k: int in sec.size():
		xs.append(sec[k].x)
		ys.append(sec[k].y)
	var main := SurfaceTool.new()
	main.begin(Mesh.PRIMITIVE_TRIANGLES)
	var head := SurfaceTool.new()
	head.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z: float = z_head
	while z < z_end - 0.001:
		var z1: float = minf(z + 1.0, z_end)
		var in_head: bool = z1 <= z_top + 0.001
		var st: SurfaceTool = head if in_head else main
		for k: int in xs.size() - 1:
			if in_head and absf(xs[k]) <= FLOOR_HALF + 0.001 and absf(xs[k + 1]) <= FLOOR_HALF + 0.001:
				continue  # the basin's floor strip is the box below
			var a := Vector3(cx + xs[k], floor_at(z) + ys[k] * depth_at(z) / DEPTH, z)
			var b := Vector3(cx + xs[k + 1], floor_at(z) + ys[k + 1] * depth_at(z) / DEPTH, z)
			var c := Vector3(cx + xs[k + 1], floor_at(z1) + ys[k + 1] * depth_at(z1) / DEPTH, z1)
			var d := Vector3(cx + xs[k], floor_at(z1) + ys[k] * depth_at(z1) / DEPTH, z1)
			HillsRoad.quad_up(st, a, b, c, d)
		z = z1
	main.generate_normals()
	head.generate_normals()
	var shell := StaticBody3D.new()
	shell.name = "Shell"
	for pair: Array in [[main.commit(), "Main"], [head.commit(), "Head"]]:
		var m: ArrayMesh = pair[0]
		var mi := MeshInstance3D.new()
		mi.name = "Mesh" + str(pair[1])
		mi.mesh = m
		mi.material_override = WorldSurface.material("concrete", CONCRETE, 0.6)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.name = "Collision" + str(pair[1])
		cs.shape = m.create_trimesh_shape()
		shell.add_child(cs)
	root.add_child(shell)
	# the basin floor: a flat box (the spawn stands on it)
	var basin: StaticBody3D = PieceKit.box(Vector3(cx - FLOOR_HALF, floor_top - 0.6, z_head), Vector3(FLOOR_HALF * 2.0, 0.6, z_top - z_head), FLOOR_C, "BasinFloor")
	var bmi: MeshInstance3D = basin.get_node("Mesh") as MeshInstance3D
	bmi.material_override = WorldSurface.material("concrete", FLOOR_C, 0.6)
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(basin)
	# headwall: a thick wall across the top end, a little higher than the lips (a guard), with the culvert mouth
	var wall_top: float = lip_at(z_head) + 0.9
	var wall: StaticBody3D = PieceKit.box(Vector3(cx - HALF - 0.6, floor_top - 2.0, z_head - 1.2), Vector3(HALF * 2.0 + 1.2, wall_top - floor_top + 2.0, 1.2), CONCRETE, "Headwall")
	(wall.get_node("Mesh") as MeshInstance3D).material_override = WorldSurface.material("concrete", Color("b2ab9c"), 0.6)
	root.add_child(wall)
	var pipe := MeshInstance3D.new()
	pipe.name = "CulvertMouth"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.75
	cyl.bottom_radius = 0.75
	cyl.height = 0.08
	cyl.radial_segments = 20
	pipe.mesh = cyl
	pipe.material_override = Toon.material(Color("1d2026"), false)
	pipe.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(cx, floor_top + 0.8, z_head + 0.03))
	root.add_child(pipe)
	var ring := MeshInstance3D.new()
	ring.name = "CulvertRim"
	var tor := TorusMesh.new()
	tor.inner_radius = 0.72
	tor.outer_radius = 0.92
	tor.rings = 20
	tor.ring_segments = 6
	ring.mesh = tor
	ring.material_override = Toon.material(Color("8f897c"), false)
	ring.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(cx, floor_top + 0.8, z_head + 0.02))
	root.add_child(ring)
	for i: int in 5:  # grate bars over the mouth
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 1.5, 0.05)
		bar.mesh = bm
		bar.material_override = Toon.material(Color("4d5266"), false)
		bar.position = Vector3(cx - 0.5 + 0.25 * float(i), floor_top + 0.8, z_head + 0.08)
		root.add_child(bar)
	# the trickle of water down the middle (visual, just above the floor)
	var water := MeshInstance3D.new()
	water.name = "Trickle"
	var wst := SurfaceTool.new()
	wst.begin(Mesh.PRIMITIVE_TRIANGLES)
	z = z_head + 0.2
	var wide: float = 0.32
	while z < z_end - 4.0:
		var z1: float = minf(z + 2.0, z_end - 4.0)
		var w0: float = wide * (0.8 + 0.3 * sin(z * 0.7))
		var w1: float = wide * (0.8 + 0.3 * sin(z1 * 0.7))
		var m0: float = 0.12 * sin(z * 0.23)
		var m1: float = 0.12 * sin(z1 * 0.23)
		HillsRoad.quad_up(wst, Vector3(cx + m0 - w0, floor_at(z) + 0.012, z), Vector3(cx + m0 + w0, floor_at(z) + 0.012, z),
			Vector3(cx + m1 + w1, floor_at(z1) + 0.012, z1), Vector3(cx + m1 - w1, floor_at(z1) + 0.012, z1))
		z = z1
	wst.generate_normals()
	water.mesh = wst.commit()
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(WATER.r, WATER.g, WATER.b, 0.75)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.metallic_specular = 0.9
	wm.roughness = 0.08
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(water)
	# grind lines on both lips' inner edges (ledge), from just below the headwall to the start of the spill
	for sgn: float in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		z = z_head + 0.5
		while z <= z_taper:
			pts.append(Vector3(cx + sgn * (LIP_IN + 0.06), lip_at(z), z))
			z += 4.0
		root.add_child(PieceKit.rail(pts, "ledge", "LipRail" + ("W" if sgn < 0.0 else "E")))
	# gap zones: the basin (start of the ditch bomb), the spill (its end), and both lips mid-run (the transfer)
	root.add_child(PieceKit.gap_zone("ditch_head", Vector3(cx - HALF, floor_top - 0.5, z_top - 2.0), Vector3(HALF * 2.0, 3.0, 3.0)))
	root.add_child(PieceKit.gap_zone("ditch_spill", Vector3(cx - HALF, floor_end - 0.5, z_end - 6.0), Vector3(HALF * 2.0, 3.0, 4.0)))
	for k: int in 3:
		var zc: float = -40.0 + 30.0 * float(k)
		root.add_child(PieceKit.gap_zone("ditch_lip_w", Vector3(cx - HALF - 0.5, lip_at(zc + 5.0) - 0.2, zc - 6.0), Vector3(1.9, 2.6, 12.0)))
		root.add_child(PieceKit.gap_zone("ditch_lip_e", Vector3(cx + HALF - 1.4, lip_at(zc + 5.0) - 0.2, zc - 6.0), Vector3(1.9, 2.6, 12.0)))
	return root
