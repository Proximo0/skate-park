class_name ParkDressing
extends RefCounted
## Lived-in dressing for the park: graffiti decals, trash cans and dumpsters, scattered litter and parked cars.
## `build(placed)` returns one Node3D ("Dressing") to add to the park; `placed` is Park.placed, used only to keep litter off
## the pieces. Everything here is built from boxes, cylinders and lofted profiles, with the Toon look.
##
## Collision: cans, dumpsters and cars are StaticBodies on layer 1 (world) with simple box or cylinder shapes. Graffiti decals,
## litter and the painted parking strips are meshes only. The props sit at the park edges, by the shop backs and along two
## parking strips, away from the bot's lines and the pieces' approach lanes.

const DECAL_LIFT: float = 0.015
const LITTER_SEED: int = 4242
const PARK_HALF: float = 75.0
const GLASS := Color("33465e")
const TYRE := Color("2a2a35")
const CHROME := Color("d5dde6")
const DARK := Color("3a3a4a")

const DECAL_SHADER_CODE: String = """
shader_type spatial;
render_mode specular_disabled, depth_draw_never, cull_back;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ROUGHNESS = 1.0;
}
void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float mid = smoothstep(0.28, 0.32, lit);
	float top = smoothstep(0.68, 0.72, lit);
	vec3 col = mix(ALBEDO * vec3(0.42, 0.4, 0.62), ALBEDO * 0.8, mid);
	col = mix(col, ALBEDO, top);
	DIFFUSE_LIGHT += col * LIGHT_COLOR * 0.5;
}
"""

static var _decal_shader: Shader = null
static var _decal_mats: Dictionary = {}

## Graffiti sites: [texture id, centre (world), yaw degrees (0 faces +Z, 90 faces +X, 180 faces -Z, -90 faces -X), width m].
## The quad is put 1.5 cm off the surface it faces. The height follows the texture's aspect.
const GRAFFITI: Array = [
	# wallride alley, the plain backs of the two walls
	["throw_waxy", Vector3(25.585, 2.4, 6.0), -90.0, 4.4],
	["tag_spud", Vector3(25.585, 0.75, 2.6), -90.0, 2.6],
	["chibi_blue", Vector3(33.615, 1.9, 3.2), 90.0, 2.4],
	["throw_tide", Vector3(33.615, 1.9, 8.4), 90.0, 4.0],
	# shop side walls (the roof gap) and backs
	["motif_wave", Vector3(-14.015, 1.9, 36.6), 90.0, 3.2],
	["tag_koi", Vector3(-9.985, 1.5, 36.6), -90.0, 3.2],
	["throw_bonz", Vector3(-21.9, 2.3, 40.015), 0.0, 3.8],
	["chibi_cat", Vector3(-16.0, 2.1, 40.015), 0.0, 2.3],
	["tag_flux", Vector3(-8.2, 1.7, 40.015), 0.0, 3.2],
	["motif_skull", Vector3(-1.6, 2.2, 40.015), 0.0, 2.2],
	# the quarter pipes' backs
	["throw_ramen", Vector3(-19.6, 1.7, -40.015), 180.0, 5.2],
	["chibi_cap", Vector3(-13.0, 1.8, -40.015), 180.0, 2.4],
	["throw_mochi", Vector3(-2.4, 1.7, -40.015), 180.0, 4.8],
	["motif_sun", Vector3(4.4, 1.8, -40.015), 180.0, 2.4],
	["tag_zest", Vector3(-40.015, 1.3, -12.4), -90.0, 3.6],
	["motif_koi", Vector3(40.015, 1.7, -9.0), 90.0, 3.4],
	["tag_spud", Vector3(58.5, 1.6, 24.015), 0.0, 3.6],
	# the mega ramp: the back of its quarter pipe and the tower's side
	["throw_waxy", Vector3(-68.0, 3.4, 18.415), 0.0, 6.6],
	["throw_mochi", Vector3(-63.785, 4.6, -67.5), 90.0, 8.0],
	["chibi_blue", Vector3(-63.785, 3.6, -59.0), 90.0, 4.4],
	# the drop ramp's west face
	["motif_palm", Vector3(59.985, 4.0, -64.0), -90.0, 5.0],
	# beside the quarter pipes at the south and west
	["throw_yuzu", Vector3(-33.0, 2.4, -40.015), 180.0, 4.2],
]

## Parking strips (x centre, z from, z to, yaw degrees the cars face), cars as [kind, colour] in nose-to-tail order.
const STRIP_WEST_X: float = -72.6
const STRIP_EAST_X: float = 72.6
const CARS_WEST: Array = [["kei", "a8e6cf"], ["hatch", "ffb199"], ["van", "7ec8e3"], ["pickup", "ffe066"]]
const CARS_EAST: Array = [["hatch", "4fd1c5"], ["pickup", "ff6b5e"], ["kei", "fff1d6"]]
const WEST_START_Z: float = 24.0
const EAST_START_Z: float = 28.0
const WEST_DEPTH: float = 22.0
const EAST_DEPTH: float = 16.0

## Trash cans: [kind, x, z, yaw]; kinds "metal", "wheelie", "over_metal", "over_wheelie".
const CANS: Array = [
	["metal", -17.0, -42.8, 15.0], ["metal", 11.0, -42.8, -20.0],
	["metal", 72.6, 6.0, 0.0], ["metal", 0.5, 54.5, 30.0], ["metal", -70.0, 38.8, 0.0],
	["wheelie", -26.2, 41.4, 180.0], ["wheelie", 1.9, 41.1, 170.0], ["wheelie", -40.5, 55.5, 0.0], ["wheelie", 52.5, 55.5, 10.0],
	["wheelie", 72.6, -30.0, 90.0], ["wheelie", -43.5, -30.0, 0.0],
	["over_metal", -12.0, 41.2, 0.0], ["over_wheelie", 29.0, 55.0, 0.0],
]
## Dumpsters: [x, z, yaw, graffiti id].
const DUMPSTERS: Array = [
	[73.3, -12.0, -90.0, "tag_drip"], [-73.3, 47.5, 90.0, "sticker_smile"], [73.2, 25.0, -90.0, "throw_yuzu"],
]


## One Node3D with everything. `placed` (Park.placed) keeps the litter off the pieces; pass [] for none.
static func build(placed: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "Dressing"
	var counts: Dictionary = {}
	var g: Node3D = graffiti()
	root.add_child(g)
	counts["graffiti"] = g.get_child_count()
	var cans: Node3D = trash_cans()
	root.add_child(cans)
	counts["cans"] = cans.get_child_count()
	var cars_node: Node3D = cars()
	root.add_child(cars_node)
	counts["cars"] = cars_node.get_child_count()
	var avoid: Array[Rect2] = footprints(placed)
	for c: Node in cans.get_children():
		var n3: Node3D = c as Node3D
		avoid.append(Rect2(n3.position.x - 0.7, n3.position.z - 0.7, 1.4, 1.4))
	avoid.append(Rect2(STRIP_WEST_X - 2.4, WEST_START_Z - 1.0, 4.8, WEST_DEPTH + 1.0))
	avoid.append(Rect2(STRIP_EAST_X - 2.4, EAST_START_Z - 1.0, 4.8, EAST_DEPTH + 1.0))
	var lit: Node3D = litter(avoid, LITTER_SEED)
	root.add_child(lit)
	var n_lit: int = 0
	for m: Node in lit.get_children():
		if m is MultiMeshInstance3D:
			n_lit += (m as MultiMeshInstance3D).multimesh.instance_count
	counts["litter"] = n_lit
	root.set_meta("counts", counts)
	for strip: Node3D in parking_strips():
		root.add_child(strip)
	return root


# ----------------------------------------------------------------------------------------------------------------- helpers

static func _mesh(mesh: Mesh, color: Color, pos: Vector3, node_name: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = Toon.material(color, false)
	mi.position = pos
	mi.rotation = rot
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _cyl(top: float, bottom: float, height: float, seg: int = 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = seg
	m.rings = 1
	return m


static func _sphere(radius: float, seg: int = 10, rings: int = 5) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = seg
	m.rings = rings
	return m


static func _body(node_name: String) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = node_name
	sb.collision_layer = 1
	return sb


static func _shape_box(size: Vector3, pos: Vector3, node_name: String = "Collision") -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = node_name
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position = pos
	return cs


## World-space xz footprints of the placed pieces, from their meshes.
static func footprints(placed: Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for p: Variant in placed:
		var node: Node3D = p as Node3D
		if node == null:
			continue
		var boxes: Array[AABB] = []
		_collect_aabbs(node, node.transform, boxes)
		var merged: AABB = AABB()
		for i: int in boxes.size():
			merged = boxes[i] if i == 0 else merged.merge(boxes[i])
		if boxes.size() > 0:
			out.append(Rect2(merged.position.x, merged.position.z, merged.size.x, merged.size.z))
	return out


static func _collect_aabbs(node: Node, xf: Transform3D, out: Array[AABB]) -> void:
	for c: Node in node.get_children():
		if c is Node3D:
			var n3: Node3D = c as Node3D
			var t: Transform3D = xf * n3.transform
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				out.append(t * (c as MeshInstance3D).mesh.get_aabb())
			_collect_aabbs(c, t, out)


# --------------------------------------------------------------------------------------------------------------- graffiti

static func decal_material(id: String) -> ShaderMaterial:
	if _decal_mats.has(id):
		return _decal_mats[id] as ShaderMaterial
	if _decal_shader == null:
		_decal_shader = Shader.new()
		_decal_shader.code = DECAL_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _decal_shader
	mat.set_shader_parameter("tex", GraffitiArt.texture(id))
	_decal_mats[id] = mat
	return mat


## A graffiti quad: width `w` metres, height from the texture's aspect, facing yaw_deg (0 = +Z). No collision, no shadow.
static func decal(id: String, w: float, pos: Vector3, yaw_deg: float, node_name: String = "") -> MeshInstance3D:
	var px: Vector2i = GraffitiArt.size_of(id)
	var q := QuadMesh.new()
	q.size = Vector2(w, w * float(px.y) / float(px.x))
	var mi := MeshInstance3D.new()
	mi.name = node_name if node_name != "" else "Graffiti_" + id
	mi.mesh = q
	mi.material_override = decal_material(id)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	return mi


static func graffiti() -> Node3D:
	var root := Node3D.new()
	root.name = "Graffiti"
	var n: int = 0
	for site: Array in GRAFFITI:
		root.add_child(decal(str(site[0]), float(site[3]), site[1] as Vector3, float(site[2]), "G%02d_%s" % [n, str(site[0])]))
		n += 1
	return root


# -------------------------------------------------------------------------------------------------------------- trash cans

## A city litter bin: steel drum with bands, a lid and a knob. Collision: a cylinder. Origin at the ground, centred.
static func metal_can(color: Color = Color("7f95a8")) -> StaticBody3D:
	var sb: StaticBody3D = _body("MetalCan")
	sb.add_child(_mesh(_cyl(0.27, 0.25, 0.82, 14), color, Vector3(0, 0.45, 0), "Drum"))
	for i: int in 3:
		sb.add_child(_mesh(_cyl(0.272, 0.272, 0.035, 14), color.darkened(0.3), Vector3(0, 0.18 + 0.22 * float(i), 0), "Band%d" % i))
	sb.add_child(_mesh(_cyl(0.3, 0.3, 0.05, 14), DARK, Vector3(0, 0.88, 0), "LidRim"))
	sb.add_child(_mesh(_cyl(0.12, 0.27, 0.1, 14), color.darkened(0.45), Vector3(0, 0.95, 0), "LidDome"))
	sb.add_child(_mesh(_sphere(0.045, 8, 4), DARK, Vector3(0, 1.02, 0), "Knob"))
	sb.add_child(_mesh(_cyl(0.28, 0.28, 0.04, 14), DARK, Vector3(0, 0.03, 0), "Foot"))
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 1.0
	cs.shape = shape
	cs.position = Vector3(0, 0.5, 0)
	sb.add_child(cs)
	return sb


## A plastic wheelie bin: tapered tub, hinged lid, two wheels and a back handle. Front faces +Z. Collision: a box.
static func wheelie_bin(color: Color = Color("2f6f9f"), lid_open: bool = false) -> StaticBody3D:
	var sb: StaticBody3D = _body("WheelieBin")
	sb.add_child(_mesh(_box(Vector3(0.58, 0.9, 0.66)), color, Vector3(0, 0.5, 0), "Tub"))
	sb.add_child(_mesh(_box(Vector3(0.64, 0.06, 0.72)), color.darkened(0.15), Vector3(0, 0.15, 0.0), "Skirt"))
	var lid: MeshInstance3D = _mesh(_box(Vector3(0.66, 0.06, 0.74)), color.darkened(0.25), Vector3(0, 0.97, 0.0), "Lid")
	if lid_open:
		lid.position = Vector3(0, 1.12, -0.42)
		lid.rotation_degrees = Vector3(-70.0, 0.0, 0.0)
	else:
		lid.rotation_degrees = Vector3(-3.0, 0.0, 0.0)
	sb.add_child(lid)
	sb.add_child(_mesh(_box(Vector3(0.5, 0.05, 0.06)), color.darkened(0.3), Vector3(0, 0.8, 0.38), "Handle"))
	for sgn: float in [-1.0, 1.0]:
		sb.add_child(_mesh(_cyl(0.1, 0.1, 0.06, 10), TYRE, Vector3(sgn * 0.31, 0.1, -0.22), "Wheel", Vector3(0, 0, PI * 0.5)))
	sb.add_child(_mesh(_box(Vector3(0.22, 0.14, 0.02)), Color("fff4df"), Vector3(0, 0.62, 0.335), "Label"))
	sb.add_child(_shape_box(Vector3(0.66, 1.0, 0.72), Vector3(0, 0.5, 0)))
	return sb


## A can or bin heaped with bags and crushed cans, lid ajar.
static func overflowing_can(wheelie: bool, seed_value: int = 1) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sb: StaticBody3D
	var top: float
	if wheelie:
		sb = wheelie_bin(Color("3f8f6f"), true)
		sb.name = "OverflowWheelie"
		top = 0.98
	else:
		sb = metal_can(Color("6f8aa0"))
		sb.name = "OverflowCan"
		top = 0.9
		var lid_rim: Node = sb.get_node("LidRim")
		var dome: Node = sb.get_node("LidDome")
		var knob: Node = sb.get_node("Knob")
		(lid_rim as Node3D).position = Vector3(0.14, top + 0.1, -0.12)
		(lid_rim as Node3D).rotation_degrees = Vector3(-35.0, 0.0, 12.0)
		dome.queue_free()
		knob.queue_free()
	var bag_cols: Array[Color] = [Color("f4f0e6"), Color("ff9ec0"), Color("3a3a4a"), Color("a8d8ff")]
	for i: int in 5:
		var m: MeshInstance3D = _mesh(_sphere(0.23, 8, 4), bag_cols[i % bag_cols.size()], Vector3(rng.randf_range(-0.14, 0.14), top + 0.08 + rng.randf_range(0.0, 0.14), rng.randf_range(-0.12, 0.12)), "Bag%d" % i)
		m.scale = Vector3(1.0, 0.8, 1.0)
		sb.add_child(m)
	for i: int in 3:
		sb.add_child(_mesh(_cyl(0.035, 0.035, 0.12, 8), [Color("ff5a5f"), Color("c9d3dd"), Color("5ad1e6")][i], Vector3(rng.randf_range(-0.15, 0.15), top + 0.25 + rng.randf_range(0.0, 0.08), rng.randf_range(-0.12, 0.12)), "Can%d" % i, Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))))
	# a few things that fell out, on the ground (no collision)
	for i: int in 4:
		var a: float = rng.randf_range(0.0, TAU)
		var d: float = rng.randf_range(0.4, 0.75)
		sb.add_child(_mesh(_box(Vector3(0.14, 0.02, 0.1)), bag_cols[(i + 1) % bag_cols.size()], Vector3(cos(a) * d, 0.012, sin(a) * d), "Spill%d" % i, Vector3(0.0, a, 0.0)))
	return sb


## A big hinge-lidded dumpster along X (2 m long, 1.1 m deep, 1.2 m tall), with ribs, fork pockets and four castors.
## `graffiti_id` ("" for none) puts a decal on its +Z side. Collision: one box.
static func dumpster(color: Color = Color("3a7a9a"), graffiti_id: String = "") -> StaticBody3D:
	var sb: StaticBody3D = _body("Dumpster")
	sb.add_child(_mesh(_box(Vector3(2.0, 0.95, 1.05)), color, Vector3(0, 0.72, 0), "Box"))
	sb.add_child(_mesh(_box(Vector3(2.08, 0.07, 1.13)), color.darkened(0.25), Vector3(0, 1.22, 0), "Rim"))
	var lid_col: Color = DARK
	var l1: MeshInstance3D = _mesh(_box(Vector3(1.0, 0.06, 1.1)), lid_col, Vector3(-0.5, 1.29, 0.0), "LidL")
	l1.rotation_degrees = Vector3(0, 0, 4.0)
	sb.add_child(l1)
	var l2: MeshInstance3D = _mesh(_box(Vector3(1.0, 0.06, 1.1)), lid_col, Vector3(0.5, 1.29, 0.0), "LidR")
	l2.rotation_degrees = Vector3(0, 0, -4.0)
	sb.add_child(l2)
	for i: int in 4:
		sb.add_child(_mesh(_box(Vector3(0.06, 0.8, 0.04)), color.darkened(0.22), Vector3(-0.75 + 0.5 * float(i), 0.72, 0.54), "Rib%d" % i))
	sb.add_child(_mesh(_box(Vector3(2.04, 0.05, 0.05)), color.darkened(0.3), Vector3(0, 0.28, 0.55), "Skid"))
	for sx: float in [-0.8, 0.8]:
		for sz: float in [-0.4, 0.4]:
			sb.add_child(_mesh(_cyl(0.07, 0.07, 0.05, 8), TYRE, Vector3(sx, 0.1, sz), "Castor", Vector3(0, 0, PI * 0.5)))
	sb.add_child(_shape_box(Vector3(2.08, 1.3, 1.13), Vector3(0, 0.65, 0)))
	if graffiti_id != "":
		var s: float = 1.6 if not graffiti_id.begins_with("sticker") else 0.7
		sb.add_child(decal(graffiti_id, s, Vector3(0, 0.72, 0.565), 0.0))
	return sb


static func trash_cans() -> Node3D:
	var root := Node3D.new()
	root.name = "TrashCans"
	var n: int = 0
	for c: Array in CANS:
		var kind: String = str(c[0])
		var can: StaticBody3D
		match kind:
			"metal":
				can = metal_can([Color("7f95a8"), Color("5f7f6f"), Color("8a7fa8")][n % 3])
			"wheelie":
				can = wheelie_bin([Color("2f6f9f"), Color("3f8f6f"), Color("7a7f8a")][n % 3])
			"over_metal":
				can = overflowing_can(false, n + 1)
			_:
				can = overflowing_can(true, n + 1)
		can.position = Vector3(float(c[1]), 0.0, float(c[2]))
		can.rotation_degrees = Vector3(0, float(c[3]), 0)
		can.name = "%s_%d" % [kind, n]
		root.add_child(can)
		n += 1
	var cols: Array[Color] = [Color("3a7a9a"), Color("4a8a6a"), Color("b86b3c")]
	var d: int = 0
	for dd: Array in DUMPSTERS:
		var dump: StaticBody3D = dumpster(cols[d % 3], str(dd[3]))
		dump.position = Vector3(float(dd[0]), 0.0, float(dd[1]))
		dump.rotation_degrees = Vector3(0, float(dd[2]), 0)
		dump.name = "Dumpster_%d" % d
		root.add_child(dump)
		d += 1
	return root


# ------------------------------------------------------------------------------------------------------------------- cars

## A flat quad, wound so it faces `outward`. Corners in order around the polygon.
static func _quad_mesh(a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> ArrayMesh:
	var n: Vector3 = (b - a).cross(c - a)
	var pts := PackedVector3Array([a, b, c, a, c, d])
	if n.dot(outward) < 0.0:
		pts = PackedVector3Array([a, c, b, a, d, c])
	return PieceKit.mesh_from_triangles(pts)


## Lofted car side profile: extruded across the car's width and centred on x.
static func _profile_mesh(prof: PackedVector2Array, width: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = PieceKit.extrude_profile(prof, width)
	mi.position = Vector3(-width * 0.5, 0.0, 0.0)
	return mi


## One side window (a trapezoid on each side of the car) from y/z corners: [belt y, front z at belt, roof y, front z at roof,
## rear z at roof, rear z at belt]. A body-coloured pillar splits it at `pillar_z` (skip with INF).
static func _side_glass(root: Node3D, w: float, g: Array, body_col: Color, pillar_z: float) -> void:
	for sgn: float in [-1.0, 1.0]:
		var x: float = sgn * (w * 0.5 + 0.012)
		var out := Vector3(sgn, 0, 0)
		var q: ArrayMesh = _quad_mesh(Vector3(x, g[0], g[1]), Vector3(x, g[2], g[3]), Vector3(x, g[2], g[4]), Vector3(x, g[0], g[5]), out)
		var mi := MeshInstance3D.new()
		mi.name = "SideGlass"
		mi.mesh = q
		mi.material_override = Toon.material(GLASS, false)
		root.add_child(mi)
		if pillar_z != INF:
			root.add_child(_mesh(_box(Vector3(0.02, g[2] - g[0], 0.09)), body_col, Vector3(x + sgn * 0.004, (g[0] + g[2]) * 0.5, pillar_z), "Pillar"))
		# a pale streak so the glass reads as glass
		var mid_z: float = (g[3] + g[4]) * 0.5
		root.add_child(_mesh(_box(Vector3(0.02, 0.05, absf(g[3] - g[4]) * 0.35)), Color("7f9fbf"), Vector3(x + sgn * 0.006, g[2] - 0.1, mid_z), "Glint"))


## Slanted windscreen or rear glass between two (y, z) points, `half_w` either side of centre, pushed out along `out_yz`.
static func _slope_glass(root: Node3D, p0: Vector2, p1: Vector2, half_w: float, out_yz: Vector2, split: bool = false) -> void:
	var lift: Vector2 = out_yz.normalized() * 0.012
	var a := Vector3(-half_w, p0.x + lift.x, p0.y + lift.y)
	var b := Vector3(-half_w, p1.x + lift.x, p1.y + lift.y)
	var c := Vector3(half_w, p1.x + lift.x, p1.y + lift.y)
	var d := Vector3(half_w, p0.x + lift.x, p0.y + lift.y)
	var mi := MeshInstance3D.new()
	mi.name = "Glass"
	mi.mesh = _quad_mesh(a, b, c, d, Vector3(0, out_yz.x, out_yz.y))
	mi.material_override = Toon.material(GLASS, false)
	root.add_child(mi)
	if split:
		var m: Vector2 = (p0 + p1) * 0.5 + lift + out_yz.normalized() * 0.004
		root.add_child(_mesh(_box(Vector3(0.06, 0.03, 0.03)), DARK, Vector3(0, m.x, m.y), "Split"))


static func _wheel(root: Node3D, x: float, y: float, z: float, r: float, w: float, hub: Color) -> void:
	var rot := Vector3(0, 0, PI * 0.5)
	root.add_child(_mesh(_cyl(r, r, w, 14), TYRE, Vector3(x, y, z), "Wheel", rot))
	var sgn: float = signf(x)
	root.add_child(_mesh(_cyl(r * 0.46, r * 0.46, w + 0.03, 12), hub, Vector3(x + sgn * 0.005, y, z), "Hub", rot))
	root.add_child(_mesh(_cyl(r * 0.2, r * 0.2, w + 0.05, 8), DARK, Vector3(x + sgn * 0.01, y, z), "Cap", rot))


## A stylised parked car. kind: "kei" (tiny boxy), "hatch", "van" (surf van with a board on its roof rack) or "pickup".
## Faces +Z, origin at the ground, centred. Collision: a low body box plus a cabin box (StaticBody3D, layer 1).
static func car(kind: String, color: Color) -> StaticBody3D:
	var sb: StaticBody3D = _body("Car_" + kind)
	var pts: PackedVector2Array
	var w: float
	var len: float
	var wheel_r: float
	var wheel_z: float
	var cab_y: float
	var cab_z0: float  # rear end of the cabin (z)
	var cab_z1: float  # front end of the cabin (z)
	var roof_y: float
	match kind:
		"kei":
			w = 1.42
			len = 3.1
			wheel_r = 0.26
			wheel_z = 1.0
			pts = PackedVector2Array([Vector2(0.2, -1.5), Vector2(0.2, 1.5), Vector2(0.3, 1.56), Vector2(0.66, 1.56), Vector2(0.8, 1.3), Vector2(0.88, 0.85), Vector2(1.6, 0.55), Vector2(1.67, 0.4), Vector2(1.67, -1.1), Vector2(1.56, -1.42), Vector2(0.9, -1.54), Vector2(0.4, -1.56), Vector2(0.28, -1.5)])
			cab_y = 0.88
			cab_z0 = -1.4
			cab_z1 = 0.7
			roof_y = 1.67
		"van":
			w = 1.82
			len = 4.3
			wheel_r = 0.33
			wheel_z = 1.35
			pts = PackedVector2Array([Vector2(0.25, -2.1), Vector2(0.25, 2.0), Vector2(0.38, 2.12), Vector2(0.85, 2.15), Vector2(1.05, 2.1), Vector2(1.2, 2.0), Vector2(1.86, 1.76), Vector2(1.98, 1.5), Vector2(2.03, 1.0), Vector2(2.03, -1.6), Vector2(1.95, -1.95), Vector2(1.4, -2.13), Vector2(0.5, -2.14), Vector2(0.33, -2.06)])
			cab_y = 1.2
			cab_z0 = -2.0
			cab_z1 = 1.8
			roof_y = 2.03
		"pickup":
			w = 1.84
			len = 4.9
			wheel_r = 0.36
			wheel_z = 1.55
			pts = PackedVector2Array([Vector2(0.28, -2.45), Vector2(0.28, 2.4), Vector2(0.42, 2.47), Vector2(0.78, 2.47), Vector2(0.96, 2.0), Vector2(1.04, 1.5), Vector2(1.04, -2.4), Vector2(0.6, -2.47), Vector2(0.4, -2.45)])
			cab_y = 1.04
			cab_z0 = -0.4
			cab_z1 = 1.0
			roof_y = 1.78
		_:
			w = 1.68
			len = 3.95
			wheel_r = 0.29
			wheel_z = 1.2
			pts = PackedVector2Array([Vector2(0.2, -1.9), Vector2(0.2, 1.9), Vector2(0.34, 1.97), Vector2(0.62, 1.97), Vector2(0.8, 1.55), Vector2(0.9, 0.95), Vector2(1.44, 0.3), Vector2(1.49, 0.0), Vector2(1.46, -0.9), Vector2(1.0, -1.88), Vector2(0.4, -1.97), Vector2(0.28, -1.93)])
			cab_y = 0.95
			cab_z0 = -1.9
			cab_z1 = 0.95
			roof_y = 1.49
	# main body (a pickup's cab is separate; its lower body is this profile)
	var body_mi: MeshInstance3D = _profile_mesh(pts, w)
	body_mi.name = "Body"
	body_mi.material_override = Toon.material(color, false)
	sb.add_child(body_mi)
	var front_z: float = len * 0.5
	match kind:
		"kei":
			_side_glass(sb, w, [0.98, 0.78, 1.57, 0.53, -1.1, -1.28], color, -0.3)
			_slope_glass(sb, Vector2(0.92, 0.84), Vector2(1.6, 0.56), w * 0.5 - 0.12, Vector2(0.5, 0.85), false)
			_slope_glass(sb, Vector2(1.56, -1.4), Vector2(0.98, -1.52), w * 0.5 - 0.15, Vector2(0.2, -1.0), false)
		"hatch":
			_side_glass(sb, w, [1.0, 0.82, 1.4, 0.33, -0.8, -1.55], color, -0.35)
			_slope_glass(sb, Vector2(0.95, 0.93), Vector2(1.43, 0.31), w * 0.5 - 0.12, Vector2(0.6, 0.65), false)
			_slope_glass(sb, Vector2(1.44, -0.93), Vector2(1.02, -1.86), w * 0.5 - 0.15, Vector2(0.45, -0.45), false)
		"van":
			# two-tone: cream roof band above the belt line, wrapped over the cabin
			var cream := Color("fff4df")
			var roof_pts: PackedVector2Array = _clip_above(pts, 1.28)
			var roof_mi: MeshInstance3D = _profile_mesh(roof_pts, w + 0.03)
			roof_mi.name = "RoofBand"
			roof_mi.material_override = Toon.material(cream, false)
			sb.add_child(roof_mi)
			_side_glass(sb, w + 0.03, [1.34, 1.72, 1.86, 1.46, -1.7, -1.85], cream, 0.55)
			_slope_glass(sb, Vector2(1.26, 2.02), Vector2(1.84, 1.78), w * 0.5 - 0.1, Vector2(0.4, 0.9), true)
			# roof rack and the board
			for z: float in [-0.9, 0.0, 0.9]:
				sb.add_child(_mesh(_box(Vector3(w - 0.2, 0.04, 0.05)), CHROME, Vector3(0, 2.1, z), "RackBar"))
			for sgn: float in [-1.0, 1.0]:
				sb.add_child(_mesh(_box(Vector3(0.04, 0.04, 2.2)), CHROME, Vector3(sgn * (w * 0.5 - 0.12), 2.1, 0.0), "RackRail"))
			var board: MeshInstance3D = _mesh(_sphere(0.5, 12, 6), Color("ff6b8a"), Vector3(0.12, 2.24, -0.1), "Surfboard")
			board.scale = Vector3(0.52, 0.1, 2.3)
			sb.add_child(board)
			var stripe: MeshInstance3D = _mesh(_sphere(0.5, 12, 6), Color("fff4df"), Vector3(0.12, 2.27, -0.1), "BoardStripe")
			stripe.scale = Vector3(0.12, 0.1, 2.0)
			sb.add_child(stripe)
			# round headlamps and a V on the nose
			for sgn: float in [-1.0, 1.0]:
				sb.add_child(_mesh(_cyl(0.13, 0.13, 0.06, 12), Color("fff6c8"), Vector3(sgn * 0.6, 0.78, front_z + 0.0), "Lamp", Vector3(PI * 0.5, 0, 0)))
			sb.add_child(_mesh(_box(Vector3(0.05, 0.4, 0.05)), CHROME, Vector3(-0.1, 0.82, front_z + 0.03), "VL", Vector3(0, 0, -0.4)))
			sb.add_child(_mesh(_box(Vector3(0.05, 0.4, 0.05)), CHROME, Vector3(0.1, 0.82, front_z + 0.03), "VR", Vector3(0, 0, 0.4)))
		"pickup":
			# the cab, then the open bed with a liner and tail gate
			var cab: PackedVector2Array = PackedVector2Array([Vector2(1.04, 1.0), Vector2(1.76, 0.5), Vector2(1.79, 0.3), Vector2(1.79, -0.3), Vector2(1.04, -0.4)])
			var cab_mi: MeshInstance3D = _profile_mesh(cab, w - 0.04)
			cab_mi.name = "Cab"
			cab_mi.material_override = Toon.material(color, false)
			sb.add_child(cab_mi)
			_side_glass(sb, w - 0.04, [1.12, 0.78, 1.7, 0.47, -0.22, -0.3], color, 0.18)
			_slope_glass(sb, Vector2(1.08, 0.96), Vector2(1.72, 0.49), w * 0.5 - 0.14, Vector2(0.65, 0.75), false)
			sb.add_child(_mesh(_box(Vector3(w - 0.4, 0.4, 0.02)), GLASS, Vector3(0, 1.4, -0.412), "RearGlass"))
			sb.add_child(_mesh(_box(Vector3(w - 0.3, 0.03, 1.9)), Color("2c2c3a"), Vector3(0, 1.055, -1.45), "Liner"))
			for sgn: float in [-1.0, 1.0]:
				sb.add_child(_mesh(_box(Vector3(0.07, 0.4, 1.95)), color, Vector3(sgn * (w * 0.5 - 0.035), 1.22, -1.42), "BedWall"))
			sb.add_child(_mesh(_box(Vector3(w, 0.4, 0.07)), color, Vector3(0, 1.22, -2.43), "TailGate"))
			sb.add_child(_mesh(_box(Vector3(w - 0.3, 0.4, 0.07)), color, Vector3(0, 1.22, -0.5), "BedFront"))
			# a crate in the back
			sb.add_child(_mesh(_box(Vector3(0.6, 0.4, 0.5)), Color("c98f5a"), Vector3(-0.3, 1.27, -1.8), "Crate"))
	# bumpers, lights, grille, plates, mirrors, door seams
	sb.add_child(_mesh(_box(Vector3(w + 0.04, 0.14, 0.1)), CHROME if kind == "van" else DARK, Vector3(0, 0.36, front_z + 0.02), "BumperF"))
	sb.add_child(_mesh(_box(Vector3(w + 0.04, 0.14, 0.1)), CHROME if kind == "van" else DARK, Vector3(0, 0.36, -front_z - 0.02), "BumperR"))
	for sgn: float in [-1.0, 1.0]:
		if kind != "van":
			sb.add_child(_mesh(_box(Vector3(0.3, 0.13, 0.04)), Color("fff6c8"), Vector3(sgn * (w * 0.5 - 0.3), 0.66 if kind != "pickup" else 0.7, front_z + 0.005), "Headlight"))
		sb.add_child(_mesh(_box(Vector3(0.24, 0.13, 0.04)), Color("ff4a55"), Vector3(sgn * (w * 0.5 - 0.22), 0.7 if kind != "pickup" else 0.95, -front_z - 0.005), "Taillight"))
		sb.add_child(_mesh(_box(Vector3(0.1, 0.07, 0.12)), color.darkened(0.25), Vector3(sgn * (w * 0.5 + 0.08), cab_y + 0.06, cab_z1 - 0.15), "Mirror"))
		sb.add_child(_mesh(_box(Vector3(0.012, 0.42, 0.02)), color.darkened(0.35), Vector3(sgn * (w * 0.5 + 0.004), 0.62, (cab_z0 + cab_z1) * 0.5 + 0.1), "DoorSeam"))
	if kind != "van":
		sb.add_child(_mesh(_box(Vector3(0.52, 0.12, 0.03)), DARK, Vector3(0, 0.55 if kind != "pickup" else 0.6, front_z + 0.005), "Grille"))
	sb.add_child(_mesh(_box(Vector3(0.34, 0.12, 0.02)), Color("fff4df"), Vector3(0, 0.45, front_z + 0.06), "PlateF"))
	sb.add_child(_mesh(_box(Vector3(0.34, 0.12, 0.02)), Color("fff4df"), Vector3(0, 0.5, -front_z - 0.06), "PlateR"))
	# wheels
	for sgn: float in [-1.0, 1.0]:
		for z: float in [wheel_z, -wheel_z]:
			_wheel(sb, sgn * (w * 0.5 - 0.06), wheel_r, z, wheel_r, 0.2, Color("aab6c4"))
	# collision: a low body box and a cabin box
	var low_h: float = cab_y
	sb.add_child(_shape_box(Vector3(w, low_h, len), Vector3(0, low_h * 0.5, 0), "CollisionBody"))
	var cab_len: float = (cab_z1 - cab_z0) if kind != "van" else (cab_z1 - cab_z0)
	sb.add_child(_shape_box(Vector3(w - 0.1, roof_y - cab_y, cab_len), Vector3(0, (roof_y + cab_y) * 0.5, (cab_z0 + cab_z1) * 0.5), "CollisionCabin"))
	return sb


## Clip a (y, z) polygon to y >= ymin (Sutherland-Hodgman against one half-plane).
static func _clip_above(pts: PackedVector2Array, ymin: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var a_in: bool = a.x >= ymin
		var b_in: bool = b.x >= ymin
		if a_in:
			out.append(a)
		if a_in != b_in:
			var t: float = (ymin - a.x) / (b.x - a.x)
			out.append(a.lerp(b, t))
	return out


## Length of a car kind along z, for lining them up.
static func car_length(kind: String) -> float:
	match kind:
		"kei":
			return 3.1
		"van":
			return 4.3
		"pickup":
			return 4.9
	return 3.95


static func cars() -> Node3D:
	var root := Node3D.new()
	root.name = "Cars"
	var n: int = 0
	var z: float = WEST_START_Z
	for spec: Array in CARS_WEST:
		var kind: String = str(spec[0])
		var c: StaticBody3D = car(kind, Color(str(spec[1])))
		c.position = Vector3(STRIP_WEST_X, 0.0, z + car_length(kind) * 0.5)
		c.rotation_degrees = Vector3(0, 0, 0)
		c.name = "Car%d_%s" % [n, kind]
		root.add_child(c)
		z += car_length(kind) + 1.0 + float(n % 3) * 0.25
		n += 1
	z = EAST_START_Z
	for spec: Array in CARS_EAST:
		var kind: String = str(spec[0])
		var c: StaticBody3D = car(kind, Color(str(spec[1])))
		c.position = Vector3(STRIP_EAST_X, 0.0, z + car_length(kind) * 0.5)
		c.rotation_degrees = Vector3(0, 180, 0)
		c.name = "Car%d_%s" % [n, kind]
		root.add_child(c)
		z += car_length(kind) + 1.0 + float(n % 3) * 0.25
		n += 1
	return root


## The two parking strips: a dark asphalt slab laid 2 cm above the ground (visual only) with a painted edge line.
static func parking_strips() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for west: bool in [true, false]:
		var x: float = STRIP_WEST_X if west else STRIP_EAST_X
		var z0: float = WEST_START_Z - 1.0 if west else EAST_START_Z - 1.0
		var depth: float = WEST_DEPTH if west else EAST_DEPTH
		var strip := Node3D.new()
		strip.name = "ParkingStrip" + ("West" if west else "East")
		strip.add_child(_mesh(_box(Vector3(4.4, 0.02, depth)), Color("4d5262"), Vector3(x, 0.01, z0 + depth * 0.5), "Asphalt"))
		var inner: float = x + (2.1 if west else -2.1)
		strip.add_child(_mesh(_box(Vector3(0.14, 0.024, depth)), Color("ffd23f"), Vector3(inner, 0.012, z0 + depth * 0.5), "EdgeLine"))
		var zz: float = z0
		while zz <= z0 + depth + 0.01:
			strip.add_child(_mesh(_box(Vector3(1.3, 0.024, 0.1)), Color("f4f0e6"), Vector3(x + (0.7 if west else -0.7), 0.012, zz), "BayLine"))
			zz += 5.0
		out.append(strip)
	return out


# ------------------------------------------------------------------------------------------------------------------ litter

## Litter kinds: [name, colour, count, mesh builder id].
const LITTER_KINDS: Array = [
	["can_red", "ff5a5f", 12, "can"], ["can_silver", "c9d3dd", 14, "can"], ["can_blue", "4a8fe0", 10, "can"],
	["cup_white", "f6f1e8", 12, "cup"], ["cup_red", "e8484f", 10, "cup"],
	["chips_yellow", "ffd23f", 12, "bag"], ["chips_red", "ff5a5f", 10, "bag"], ["chips_blue", "4aa8e0", 10, "bag"],
	["news_a", "e9e3d2", 10, "paper"], ["news_b", "d9d2bf", 8, "paper"],
	["pizza_box", "e3c79c", 6, "pizza"], ["ball_paper", "f4f0e6", 16, "ball"], ["bottle_cap", "ff7a45", 12, "cap"],
	["wrapper_pink", "ff9ec0", 10, "wrapper"], ["wrapper_teal", "52d1c4", 10, "wrapper"],
]
const LITTER_STICKERS: Array = [["sticker_smile", 6], ["sticker_star", 6], ["sticker_sk8", 6], ["sticker_heart", 6]]


static func _litter_mesh(kind: String) -> Mesh:
	match kind:
		"can":
			return _cyl(0.033, 0.033, 0.115, 8)
		"cup":
			return _cyl(0.042, 0.03, 0.11, 8)
		"bag":
			return _box(Vector3(0.17, 0.02, 0.12))
		"paper":
			return _box(Vector3(0.3, 0.008, 0.22))
		"pizza":
			return _box(Vector3(0.36, 0.035, 0.36))
		"ball":
			return _sphere(0.04, 6, 3)
		"cap":
			return _cyl(0.016, 0.016, 0.01, 6)
	return _box(Vector3(0.1, 0.008, 0.07))


## Scatter points: mostly along the fence line and the corners, some around the feet of pieces; none inside `avoid`.
static func litter_points(avoid: Array[Rect2], count: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var tries: int = 0
	var limit: float = PARK_HALF - 0.7
	var piece_rects: Array[Rect2] = []
	for r: Rect2 in avoid:
		if r.size.x > 1.5 and r.size.y > 1.5:
			piece_rects.append(r)
	while out.size() < count and tries < count * 60:
		tries += 1
		var p: Vector2
		var roll: float = rng.randf()
		if roll < 0.5:
			# along the fence, a metre or two in; heavier toward corners
			var side: int = rng.randi() % 4
			var along: float = rng.randf_range(-limit, limit)
			if rng.randf() < 0.4:
				along = signf(along) * rng.randf_range(limit - 9.0, limit)
			var depth: float = rng.randf_range(0.2, 2.2)
			match side:
				0:
					p = Vector2(along, -limit + depth)
				1:
					p = Vector2(along, limit - depth)
				2:
					p = Vector2(-limit + depth, along)
				_:
					p = Vector2(limit - depth, along)
		elif roll < 0.9 and not piece_rects.is_empty():
			# the feet of a piece: just outside one of its sides
			var r: Rect2 = piece_rects[rng.randi() % piece_rects.size()]
			var off: float = rng.randf_range(0.3, 1.6)
			var side2: int = rng.randi() % 4
			match side2:
				0:
					p = Vector2(rng.randf_range(r.position.x - off, r.end.x + off), r.position.y - off)
				1:
					p = Vector2(rng.randf_range(r.position.x - off, r.end.x + off), r.end.y + off)
				2:
					p = Vector2(r.position.x - off, rng.randf_range(r.position.y - off, r.end.y + off))
				_:
					p = Vector2(r.end.x + off, rng.randf_range(r.position.y - off, r.end.y + off))
		else:
			# by a can or a corner of the plaza: anywhere along a rim, loosely
			p = Vector2(rng.randf_range(-limit, limit), rng.randf_range(-limit, limit))
			if rng.randf() < 0.8:
				continue
		if absf(p.x) > limit or absf(p.y) > limit:
			continue
		var blocked: bool = false
		for r2: Rect2 in avoid:
			if r2.grow(0.2).has_point(p):
				blocked = true
				break
		if blocked:
			continue
		out.append(p)
	return out


## All the litter: one MultiMeshInstance3D per kind (cheap) with fixed-seed positions. No collision.
static func litter(avoid: Array[Rect2], seed_value: int = LITTER_SEED) -> Node3D:
	var root := Node3D.new()
	root.name = "Litter"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var total: int = 0
	for k: Array in LITTER_KINDS:
		total += int(k[2])
	for s: Array in LITTER_STICKERS:
		total += int(s[1])
	var pts: Array[Vector2] = litter_points(avoid, total, rng)
	var cursor: int = 0
	for k: Array in LITTER_KINDS:
		var kind: String = str(k[3])
		var want: int = int(k[2])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _litter_mesh(kind)
		var lit_scale: float = 1.6
		var n: int = mini(want, maxi(0, pts.size() - cursor))
		mm.instance_count = n
		for i: int in n:
			var p: Vector2 = pts[cursor + i]
			var yaw: float = rng.randf_range(0.0, TAU)
			var b: Basis = Basis(Vector3.UP, yaw)
			var y: float = 0.01
			match kind:
				"can":
					# crushed and lying on its side
					b = b * Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(1.0, 0.8, rng.randf_range(0.5, 0.9)))
					y = 0.03
				"cup":
					b = b * Basis(Vector3.BACK, PI * 0.5 + rng.randf_range(-0.15, 0.15))
					y = 0.04
				"bag":
					b = b * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08))
					y = 0.018
				"paper":
					y = 0.006
				"pizza":
					y = 0.022
				"ball":
					y = 0.035
				"cap":
					y = 0.01
			mm.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * lit_scale), Vector3(p.x, y * lit_scale, p.y)))
		cursor += n
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Litter_" + str(k[0])
		mmi.multimesh = mm
		mmi.material_override = Toon.material(Color(str(k[1])), false)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	for s: Array in LITTER_STICKERS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var q := QuadMesh.new()
		q.size = Vector2(0.22, 0.22)
		mm.mesh = q
		var n2: int = mini(int(s[1]), maxi(0, pts.size() - cursor))
		mm.instance_count = n2
		for i: int in n2:
			var p: Vector2 = pts[cursor + i]
			var b: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, -PI * 0.5)
			mm.set_instance_transform(i, Transform3D(b, Vector3(p.x, 0.011, p.y)))
		cursor += n2
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Litter_" + str(s[0])
		mmi.multimesh = mm
		mmi.material_override = decal_material(str(s[0]))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	return root
