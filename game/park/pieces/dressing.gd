class_name ParkDressing
extends RefCounted
## Lived-in dressing for the park: graffiti decals and graffiti walls, trash bins and dumpsters, scattered litter and parked cars.
## `build(placed)` returns one Node3D ("Dressing") to add to the park; `placed` is Park.placed, used only to keep litter off
## the pieces. Cars, bins, litter and walls are the Houdini glbs in assets/props/houdini/ (see houdini_props.gd), converted to the
## Toon look; the dumpsters and the parking strips are built from boxes.
##
## Collision: bins, dumpsters, walls and cars are StaticBodies on layer 1 (world) with simple box or cylinder shapes (the cars' and
## bins' sized from the mesh AABB). Graffiti decals, litter and the painted parking strips are meshes only. The props sit at the park edges, by the shop backs and along two
## parking strips, away from the bot's lines and the pieces' approach lanes.

const DECAL_LIFT: float = 0.015
const LITTER_SEED: int = 4242
const PARK_HALF: float = 75.0
const TYRE := Color("2a2a35")
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

## Parking strips (x centre, z from, z to), cars as [kind, palette index] in order along the strip. Kinds: "hatch", "pickup", "van" (the surf van).
const STRIP_WEST_X: float = -72.6
const STRIP_EAST_X: float = 72.6
const CARS_WEST: Array = [["hatch", 0], ["van", 4], ["pickup", 1], ["hatch", 2]]
const CARS_EAST: Array = [["van", 3], ["pickup", 9], ["hatch", 7]]
const WEST_START_Z: float = 24.0
const EAST_START_Z: float = 28.0
const WEST_DEPTH: float = 23.0
const EAST_DEPTH: float = 18.0

## Trash bins: [kind, x, z, yaw]; kinds "metal", "wheelie" (both the Houdini bin, in different plastic) and "over_metal", "over_wheelie" (lid open, heaped).
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
## Graffiti walls (the Houdini wall, 6.1 x 3.1 x 0.42 m) with their backs flush to the north boundary, facing into the park: [x, z, yaw (0 faces -Z, 180 +Z,
## 90 -X), decals as [texture id, x offset on the wall, y, width]]. They stand clear of every piece and skate line.
const WALL_LEN: float = 6.12
const WALL_FRONT_Z: float = -0.15  ## the wall's painted face, in its own frame
const WALLS: Array = [
	[1.0, -75.29, 180.0, [["chibi_cap", -1.6, 1.5, 2.2], ["tag_koi", 1.1, 1.0, 3.0]]],
	[-38.0, -75.29, 180.0, [["throw_mochi", -0.9, 1.55, 4.2], ["sticker_star", 2.2, 0.7, 0.8]]],
	[-8.0, -75.29, 180.0, [["motif_wave", -1.4, 1.5, 2.8], ["tag_drip", 1.4, 1.3, 2.4]]],
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
	var wall_node: Node3D = walls()
	root.add_child(wall_node)
	counts["walls"] = wall_node.get_child_count()
	var furn: Node3D = furniture()
	root.add_child(furn)
	counts["furniture"] = furn.get_child_count()
	var dz: Node3D = dead_zones()
	root.add_child(dz)
	counts["dead_zones"] = dz.get_child_count()
	var avoid: Array[Rect2] = footprints(placed)
	for r: Rect2 in DEAD_ZONE_AVOID:
		avoid.append(r)
	for c: Node in cans.get_children():
		var n3: Node3D = c as Node3D
		avoid.append(Rect2(n3.position.x - 0.7, n3.position.z - 0.7, 1.4, 1.4))
	for w: Node in wall_node.get_children():
		var wp: Vector3 = (w as Node3D).position
		avoid.append(Rect2(wp.x - 3.4, wp.z - 3.4, 6.8, 6.8))
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


# ------------------------------------------------------------------------------------------------------------- street furniture

const NAVY := Color("2c3050")
const CORAL := Color("e8665a")
const TEAL := Color("1f9db8")
const SUNNY := Color("e0a030")
const CREAM := Color("d9cfbd")
const FOLIAGE := Color("4a8a3a")
const TRUNK_BROWN := Color("7a5636")
## Clusters along the sidewalk outside each fence: at these offsets along the side (m from its middle).
const SIDEWALK_U: Array = [-60.0, -34.0, -8.0, 18.0, 44.0, 66.0]
## The inside west-edge cluster, tight against the fence and clear of every piece and skate line. Visual only: a solid one became a snag-sweep target.
const WEST_CLUSTER_X: float = -73.4


## Benches, planters with trees, bike racks and light poles in clusters: a run along the sidewalk outside each fence (visual only, outside the
## invisible boundary walls) and one small visual-only cluster inside, at the west edge. Each group is a Node3D child "Cluster*".
static func furniture() -> Node3D:
	var root := Node3D.new()
	root.name = "Furniture"
	for side: int in 4:
		var n: Vector3 = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)][side]
		var t: Vector3 = Vector3(-n.z, 0.0, n.x)
		var yaw: float = atan2(-n.x, -n.z)
		for k: int in SIDEWALK_U.size():
			var cl := Node3D.new()
			cl.name = "Cluster%d_%d" % [side, k]
			cl.position = n * (PARK_HALF + 2.6) + t * float(SIDEWALK_U[k])
			cl.rotation.y = yaw
			root.add_child(cl)
			match (side + k) % 4:
				0:
					_bench(cl, Vector3(-1.6, 0.0, 0.0), false)
					_planter_tree(cl, Vector3(1.4, 0.0, 0.2), 0.9, false)
					_lamp(cl, Vector3(3.6, 0.0, 0.8))
				1:
					_bike_rack(cl, Vector3(-1.0, 0.0, 0.0), 5, false)
					_lamp(cl, Vector3(-4.0, 0.0, 0.8))
				2:
					_planter_tree(cl, Vector3(-2.2, 0.0, 0.2), 1.0, false)
					_bench(cl, Vector3(0.4, 0.0, 0.0), false)
					_bench(cl, Vector3(3.0, 0.0, 0.0), false)
				_:
					_lamp(cl, Vector3(-3.0, 0.0, 0.8))
					_bike_rack(cl, Vector3(0.0, 0.0, 0.0), 4, false)
					_planter_tree(cl, Vector3(3.4, 0.0, 0.2), 0.8, false)
	# inside, west edge, facing +X (the park)
	var west := Node3D.new()
	west.name = "ClusterWestInside"
	west.position = Vector3(WEST_CLUSTER_X, 0.0, -10.0)
	west.rotation.y = PI * 0.5
	root.add_child(west)
	_bench(west, Vector3(-4.0, 0.0, 0.0), false)
	_planter_tree(west, Vector3(-1.0, 0.0, 0.3), 1.0, false)
	_bike_rack(west, Vector3(1.8, 0.0, 0.0), 4, false)
	_lamp(west, Vector3(5.2, 0.0, 0.8))
	return root


static func _vbox(parent: Node3D, centre: Vector3, size: Vector3, colour: Color, solid: bool, node_name: String) -> void:
	if solid:
		parent.add_child(PieceKit.box(centre - size * 0.5, size, colour, node_name))
		return
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = m
	mi.position = centre
	mi.material_override = Toon.material(colour, false)
	parent.add_child(mi)


## A park bench, 1.8 m long, seat facing local +Z.
static func _bench(parent: Node3D, at: Vector3, solid: bool) -> void:
	var b := Node3D.new()
	b.name = "Bench"
	b.position = at
	parent.add_child(b)
	_vbox(b, Vector3(0.0, 0.45, 0.0), Vector3(1.8, 0.07, 0.5), CORAL, solid, "Seat")
	_vbox(b, Vector3(0.0, 0.8, -0.22), Vector3(1.8, 0.4, 0.06), CORAL, solid, "Back")
	for x: float in [-0.8, 0.8]:
		_vbox(b, Vector3(x, 0.22, 0.0), Vector3(0.08, 0.44, 0.45), NAVY, solid, "Leg")


static func _planter_tree(parent: Node3D, at: Vector3, size: float, solid: bool) -> void:
	var p := Node3D.new()
	p.name = "PlanterTree"
	p.position = at
	parent.add_child(p)
	_vbox(p, Vector3(0.0, 0.3, 0.0), Vector3(size, 0.6, size), CREAM, solid, "Box")
	_vbox(p, Vector3(0.0, 0.62, 0.0), Vector3(size + 0.1, 0.06, size + 0.1), TEAL, false, "Cap")
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.1
	trunk.bottom_radius = 0.14
	trunk.height = 1.8
	trunk.radial_segments = 6
	trunk.rings = 1
	var tm := MeshInstance3D.new()
	tm.name = "Trunk"
	tm.mesh = trunk
	tm.position = Vector3(0.0, 1.5, 0.0)
	tm.material_override = Toon.material(TRUNK_BROWN, false)
	p.add_child(tm)
	for k: int in 2:
		var crown := SphereMesh.new()
		crown.radius = 0.95 - 0.25 * float(k)
		crown.height = crown.radius * 2.0
		crown.radial_segments = 8
		crown.rings = 4
		var cm := MeshInstance3D.new()
		cm.name = "Crown%d" % k
		cm.mesh = crown
		cm.position = Vector3(0.0, 2.7 + 0.8 * float(k), 0.0)
		cm.material_override = Toon.material(FOLIAGE, false)
		p.add_child(cm)


## A row of inverted-U bike hoops along local X.
static func _bike_rack(parent: Node3D, at: Vector3, hoops: int, solid: bool) -> void:
	var r := Node3D.new()
	r.name = "BikeRack"
	r.position = at
	parent.add_child(r)
	for i: int in hoops:
		var x: float = float(i) * 0.7
		_vbox(r, Vector3(x, 0.4, -0.15), Vector3(0.05, 0.8, 0.05), TEAL, solid, "HoopL")
		_vbox(r, Vector3(x, 0.4, 0.15), Vector3(0.05, 0.8, 0.05), TEAL, solid, "HoopR")
		_vbox(r, Vector3(x, 0.8, 0.0), Vector3(0.05, 0.05, 0.35), TEAL, false, "HoopTop")
	_vbox(r, Vector3(float(hoops - 1) * 0.35, 0.02, 0.0), Vector3(float(hoops) * 0.7, 0.03, 0.5), NAVY, false, "Pad")


## A tall light pole with a bracket arm and a warm lamp head.
static func _lamp(parent: Node3D, at: Vector3) -> void:
	var l := Node3D.new()
	l.name = "LightPole"
	l.position = at
	parent.add_child(l)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.1
	pole.height = 4.6
	pole.radial_segments = 6
	pole.rings = 1
	var pm := MeshInstance3D.new()
	pm.name = "Pole"
	pm.mesh = pole
	pm.position = Vector3(0.0, 2.3, 0.0)
	pm.material_override = Toon.material(NAVY, false)
	l.add_child(pm)
	_vbox(l, Vector3(0.0, 4.55, 0.35), Vector3(0.1, 0.08, 0.8), NAVY, false, "Arm")
	_vbox(l, Vector3(0.0, 4.45, 0.75), Vector3(0.4, 0.14, 0.3), Color("ffe6a6"), false, "Head")


# ------------------------------------------------------------------------------------------------------------- dead-zone decor

const TRUCK_BODY := Color("f2c94c")
const TRUCK_TRIM := Color("e8665a")
const BOX_GREY := Color("7f8f8a")
## Keep litter off the dead-zone decor: Rect2(x, z, w, d).
const DEAD_ZONE_AVOID: Array[Rect2] = [Rect2(70.0, -59.0, 5.0, 7.0), Rect2(19.0, -74.5, 7.0, 4.0), Rect2(13.0, -74.0, 2.0, 2.0), Rect2(29.0, -74.0, 2.0, 2.0)]


## Decor for the plazas that were empty: the strip west of the dome bowl along the north fence, the apron south of it, and the east
## strip beside the loop's run-out. Everything stays at the fence lines or the plaza margins, clear of the rail line to the dome
## (z about -58.5), the dome and drop-in approaches and the loop lane (x 57 to 66). Everything is visual only: the first version's
## solid truck and boxes against the fences showed up as snag-sweep hotspots, so none has collision.
static func dead_zones() -> Node3D:
	var root := Node3D.new()
	root.name = "DeadZones"
	# west of the dome, against the north fence: a food truck serving the plaza, tables and a sign
	_food_truck(root, Vector3(23.0, 0.0, -73.4), 0.0)
	_picnic(root, Vector3(19.5, 0.0, -68.2))
	_picnic(root, Vector3(26.5, 0.0, -68.0))
	_elec_box(root, Vector3(14.0, 0.0, -74.3), 0.0, "tag_zest", "sticker_star", true)
	_elec_box(root, Vector3(31.5, 0.0, -74.3), 0.0, "sticker_sk8", "tag_koi", true)
	_planter_tree(root, Vector3(16.5, 0.0, -66.0), 1.1, false)
	_planter_tree(root, Vector3(29.5, 0.0, -66.0), 1.1, false)
	_sign_post(root, Vector3(33.4, 0.0, -66.5), 0.0, "DOME >")
	_lamp(root, Vector3(21.0, 0.0, -65.0))
	# south of the dome: a bench pair and planters on the margin, a sign
	_bench(root, Vector3(40.5, 0.0, -42.5), false)
	_bench(root, Vector3(44.3, 0.0, -42.5), false)
	_planter_tree(root, Vector3(49.0, 0.0, -42.5), 1.0, false)
	_planter_tree(root, Vector3(53.5, 0.0, -42.5), 1.0, false)
	_sign_post(root, Vector3(38.5, 0.0, -51.5), -90.0, "SKATE ZONE")
	# the east strip, beside the loop's run-out: electrical boxes, a food truck, benches facing the loop
	_food_truck(root, Vector3(73.8, 0.0, -57.2), -90.0)
	_elec_box(root, Vector3(74.3, 0.0, -43.0), -90.0, "sticker_smile", "tag_drip", true)
	_elec_box(root, Vector3(74.3, 0.0, -66.0), -90.0, "sticker_heart", "tag_spud", true)
	var b1 := Node3D.new()
	b1.name = "EastBenches"
	b1.position = Vector3(73.0, 0.0, -48.5)
	b1.rotation.y = -PI * 0.5
	root.add_child(b1)
	_bench(b1, Vector3.ZERO, false)
	_planter_tree(root, Vector3(73.0, 0.0, -38.0), 1.0, false)
	_planter_tree(root, Vector3(73.0, 0.0, -70.5), 1.0, false)
	_sign_post(root, Vector3(70.0, 0.0, -34.0), -90.0, "SK8 ONLY")
	return root


## A food truck, length along local X, serving window and awning on its +Z side. Visual only.
static func _food_truck(parent: Node3D, at: Vector3, yaw_deg: float) -> void:
	var t := Node3D.new()
	t.name = "FoodTruck"
	t.position = at
	t.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent.add_child(t)
	var cream := Color("f4ecd8")
	_vbox(t, Vector3(0.0, 1.35, 0.0), Vector3(5.2, 1.9, 2.1), cream, false, "Box")
	_vbox(t, Vector3(0.0, 0.62, 0.0), Vector3(5.24, 0.5, 2.14), TRUCK_TRIM, false, "Skirt")
	_vbox(t, Vector3(-0.2, 2.34, 0.0), Vector3(4.9, 0.1, 2.2), TRUCK_BODY, false, "Roof")
	_vbox(t, Vector3(3.15, 0.95, 0.0), Vector3(1.2, 1.3, 2.0), TRUCK_BODY, false, "Cab")
	_vbox(t, Vector3(3.5, 1.5, 0.0), Vector3(0.5, 0.55, 1.7), Color("8fd0e0"), false, "Windscreen")
	_vbox(t, Vector3(-0.3, 1.5, 1.07), Vector3(2.6, 0.8, 0.06), Color("2c3050"), false, "Window")
	_vbox(t, Vector3(-0.3, 1.1, 1.14), Vector3(2.8, 0.08, 0.3), Color("d9cfbd"), false, "Counter")
	for k: int in 7:
		var c: Color = TRUCK_TRIM if k % 2 == 0 else Color("fff4dc")
		var m := BoxMesh.new()
		m.size = Vector3(0.4, 0.06, 0.7)
		var mi := MeshInstance3D.new()
		mi.name = "Awn%d" % k
		mi.mesh = m
		mi.position = Vector3(-1.5 + float(k) * 0.4, 2.05, 1.42)
		mi.rotation.x = 0.45
		mi.material_override = Toon.material(c, false)
		t.add_child(mi)
	for wx: float in [-1.7, 2.9]:
		var wm := CylinderMesh.new()
		wm.top_radius = 0.38
		wm.bottom_radius = 0.38
		wm.height = 0.3
		wm.radial_segments = 10
		wm.rings = 1
		for wz: float in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			w.name = "Wheel"
			w.mesh = wm
			w.position = Vector3(wx, 0.38, wz)
			w.rotation.x = PI * 0.5
			w.material_override = Toon.material(TYRE, false)
			t.add_child(w)
	var label := Label3D.new()
	label.name = "TruckLabel"
	label.text = "SURF TACOS"
	label.font_size = 48
	label.pixel_size = 0.008
	label.outline_size = 8
	label.modulate = Color("e8665a")
	label.position = Vector3(-0.3, 2.0, 1.1)
	t.add_child(label)
	t.add_child(decal("sticker_smile", 0.5, Vector3(-2.2, 1.2, 1.065), 0.0, "TruckSticker"))


## A utility box, 0.9 x 1.4 x 0.5, front toward local +Z, two stickers and a tag on the front. Visual only.
static func _elec_box(parent: Node3D, at: Vector3, yaw_deg: float, tag_id: String, sticker_id: String, _solid: bool = false) -> void:
	var b := Node3D.new()
	b.name = "ElecBox"
	b.position = at
	b.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent.add_child(b)
	_vbox(b, Vector3(0.0, 0.7, 0.0), Vector3(0.9, 1.4, 0.5), BOX_GREY, false, "Body")
	_vbox(b, Vector3(0.0, 1.43, 0.0), Vector3(1.0, 0.08, 0.6), BOX_GREY.darkened(0.25), false, "Cap")
	_vbox(b, Vector3(0.0, 0.05, 0.0), Vector3(1.0, 0.1, 0.6), Color("5a5a6a"), false, "Foot")
	b.add_child(decal(tag_id, 0.8, Vector3(0.0, 0.85, 0.265), 0.0, "Tag"))
	b.add_child(decal(sticker_id, 0.28, Vector3(-0.28, 0.3, 0.265), 0.0, "StickerA"))
	b.add_child(decal("sticker_heart" if sticker_id != "sticker_heart" else "sticker_star", 0.24, Vector3(0.25, 1.2, 0.265), 0.0, "StickerB"))


static func _picnic(parent: Node3D, at: Vector3) -> void:
	var p := Node3D.new()
	p.name = "PicnicTable"
	p.position = at
	parent.add_child(p)
	_vbox(p, Vector3(0.0, 0.75, 0.0), Vector3(1.8, 0.07, 0.8), CORAL, false, "Top")
	_vbox(p, Vector3(0.0, 0.45, 0.65), Vector3(1.8, 0.06, 0.3), CORAL, false, "SeatA")
	_vbox(p, Vector3(0.0, 0.45, -0.65), Vector3(1.8, 0.06, 0.3), CORAL, false, "SeatB")
	for x: float in [-0.7, 0.7]:
		_vbox(p, Vector3(x, 0.38, 0.0), Vector3(0.07, 0.76, 1.2), NAVY, false, "Leg")
	_vbox(p, Vector3(0.0, 1.9, 0.0), Vector3(0.05, 2.3, 0.05), NAVY, false, "UmbrellaPole")
	var um := CylinderMesh.new()
	um.top_radius = 0.06
	um.bottom_radius = 1.2
	um.height = 0.35
	um.radial_segments = 8
	um.rings = 1
	var umi := MeshInstance3D.new()
	umi.name = "Umbrella"
	umi.mesh = um
	umi.position = Vector3(0.0, 3.0, 0.0)
	umi.material_override = Toon.material(TEAL, false)
	p.add_child(umi)


static func _sign_post(parent: Node3D, at: Vector3, yaw_deg: float, text: String) -> void:
	var s := Node3D.new()
	s.name = "SignPost"
	s.position = at
	s.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent.add_child(s)
	_vbox(s, Vector3(0.0, 1.1, 0.0), Vector3(0.08, 2.2, 0.08), NAVY, false, "Post")
	_vbox(s, Vector3(0.0, 2.15, 0.0), Vector3(1.9, 0.6, 0.07), SUNNY, false, "Board")
	_vbox(s, Vector3(0.0, 2.15, -0.01), Vector3(1.98, 0.68, 0.04), NAVY, false, "Rim")
	var l := Label3D.new()
	l.name = "Text"
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.008
	l.outline_size = 0
	l.modulate = NAVY
	l.position = Vector3(0.0, 2.15, 0.045)
	s.add_child(l)


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

## The Houdini trash bin (0.6 x 1 x 0.7 m), plastic tinted `color`, front facing -Z. `lid_open` swings the lid up about its hinge at
## the back. Collision: one cylinder sized from the mesh.
static func bin(color: Color, lid_open: bool = false) -> StaticBody3D:
	var sb: StaticBody3D = _body("TrashBin")
	var model: Node3D = HoudiniProps.instance("trash_bin", color)
	model.name = "Model"
	sb.add_child(model)
	var lid: Node3D = model.get_node("lid") as Node3D
	if lid_open:
		lid.rotation_degrees = Vector3(72.0, 0.0, 0.0)
	var bb: AABB = HoudiniProps.aabb_of(model)
	if lid_open:
		bb = bb.merge(AABB(Vector3(-0.3, 0.0, -0.36), Vector3(0.6, 0.95, 0.72)))
	# a cylinder (like the old can), so a skater clipping a corner glances off; it covers the bin's 0.6 x 0.7 m footprint
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = 0.36
	shape.height = minf(bb.size.y, 1.0)
	cs.shape = shape
	cs.position = Vector3(bb.get_center().x, shape.height * 0.5, bb.get_center().z)
	sb.add_child(cs)
	return sb


## A bin heaped with bags and crushed cans, lid ajar.
static func overflowing_bin(seed_value: int = 1) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sb: StaticBody3D = bin(HoudiniProps.palette_colour(seed_value * 5 + 2), true)
	sb.name = "OverflowBin"
	var top: float = 0.9
	var bag_cols: Array[Color] = [Color("f4f0e6"), Color("ff9ec0"), Color("3a3a4a"), Color("a8d8ff")]
	for i: int in 5:
		var m: MeshInstance3D = _mesh(_sphere(0.2, 8, 4), bag_cols[i % bag_cols.size()], Vector3(rng.randf_range(-0.12, 0.12), top + 0.08 + rng.randf_range(0.0, 0.14), rng.randf_range(-0.1, 0.12)), "Bag%d" % i)
		m.scale = Vector3(1.0, 0.8, 1.0)
		sb.add_child(m)
	for i: int in 3:
		sb.add_child(_mesh(_cyl(0.035, 0.035, 0.12, 8), [Color("ff5a5f"), Color("c9d3dd"), Color("5ad1e6")][i], Vector3(rng.randf_range(-0.15, 0.15), top + 0.2 + rng.randf_range(0.0, 0.08), rng.randf_range(-0.12, 0.12)), "Can%d" % i, Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))))
	# a few things that fell out, on the ground (no collision)
	for i: int in 4:
		var a: float = rng.randf_range(0.0, TAU)
		var d: float = rng.randf_range(0.5, 0.8)
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


## The bins and dumpsters.
static func trash_cans() -> Node3D:
	var root := Node3D.new()
	root.name = "TrashCans"
	var n: int = 0
	for c: Array in CANS:
		var kind: String = str(c[0])
		var can: StaticBody3D
		match kind:
			"metal":
				can = bin([Color("7f95a8"), Color("5f9f7f"), Color("8a7fa8")][n % 3])
			"wheelie":
				can = bin([Color("2f8fcf"), Color("3fbf7f"), Color("e0a030")][n % 3])
			_:
				can = overflowing_bin(n + 1)
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

## Houdini glb per car kind, and the collision shape of each as fractions of its mesh AABB: [belt height m (top of the low body box),
## cabin z range from the tail to the nose as fractions of the length, 0 = tail, 1 = nose].
const CAR_GLB: Dictionary = {"hatch": "car_hatchback", "pickup": "car_pickup", "van": "car_surfvan"}
const CAR_CABIN: Dictionary = {"hatch": [0.95, 0.02, 0.74], "pickup": [1.04, 0.42, 0.70], "van": [1.2, 0.04, 0.92]}


## A parked car: the Houdini model with its body painted `color`, wheels and all. kind: "hatch", "pickup" or "van" (surf van with a
## board on the roof). The model's nose (-Z) points along the body's -Z, like the glb. Origin at the ground, centred.
## Collision: a low body box plus a cabin box, sized from the mesh AABB (StaticBody3D, layer 1).
static func car(kind: String, color: Color) -> StaticBody3D:
	var sb: StaticBody3D = _body("Car_" + kind)
	var model: Node3D = HoudiniProps.instance(str(CAR_GLB.get(kind, "car_hatchback")), color)
	model.name = "Model"
	sb.add_child(model)
	var bb: AABB = HoudiniProps.aabb_of(model)
	var cab: Array = CAR_CABIN.get(kind, CAR_CABIN["hatch"])
	var belt: float = float(cab[0])
	var roof: float = bb.end.y
	var z_tail: float = bb.end.z  # the tail is +Z (the nose faces -Z)
	var len: float = bb.size.z
	sb.add_child(_shape_box(Vector3(bb.size.x, belt, len), Vector3(bb.get_center().x, belt * 0.5, bb.get_center().z), "CollisionBody"))
	var c0: float = z_tail - float(cab[2]) * len
	var c1: float = z_tail - float(cab[1]) * len
	sb.add_child(_shape_box(Vector3(bb.size.x - 0.1, roof - belt, c1 - c0), Vector3(bb.get_center().x, (roof + belt) * 0.5, (c0 + c1) * 0.5), "CollisionCabin"))
	return sb


## Length of a car kind along z, for lining them up (the glb's AABB).
static func car_length(kind: String) -> float:
	match kind:
		"van":
			return 4.72
		"pickup":
			return 5.42
	return 4.16


static func cars() -> Node3D:
	var root := Node3D.new()
	root.name = "Cars"
	var n: int = 0
	var z: float = WEST_START_Z
	for spec: Array in CARS_WEST:
		var kind: String = str(spec[0])
		var c: StaticBody3D = car(kind, HoudiniProps.palette_colour(int(spec[1])))
		c.position = Vector3(STRIP_WEST_X, 0.0, z + car_length(kind) * 0.5)
		c.rotation_degrees = Vector3(0, 180, 0)  # nose toward +Z, as the old cars faced
		c.name = "Car%d_%s" % [n, kind]
		root.add_child(c)
		z += car_length(kind) + 0.8 + float(n % 3) * 0.2
		n += 1
	z = EAST_START_Z
	for spec: Array in CARS_EAST:
		var kind: String = str(spec[0])
		var c: StaticBody3D = car(kind, HoudiniProps.palette_colour(int(spec[1])))
		c.position = Vector3(STRIP_EAST_X, 0.0, z + car_length(kind) * 0.5)
		c.rotation_degrees = Vector3(0, 0, 0)  # nose toward -Z
		c.name = "Car%d_%s" % [n, kind]
		root.add_child(c)
		z += car_length(kind) + 0.8 + float(n % 3) * 0.2
		n += 1
	return root


# ------------------------------------------------------------------------------------------------------------------- walls

## The graffiti walls: the Houdini wall (weathering in its vertex colour) with a box collision, and the procedural graffiti art
## laid over its painted face as decal quads. Facing: yaw 0 faces -Z (the glb's front).
static func walls() -> Node3D:
	var root := Node3D.new()
	root.name = "Walls"
	var n: int = 0
	for w: Array in WALLS:
		var sb: StaticBody3D = _body("GraffitiWall_%d" % n)
		sb.position = Vector3(float(w[0]), 0.0, float(w[1]))
		sb.rotation_degrees = Vector3(0.0, float(w[2]), 0.0)
		var model: Node3D = HoudiniProps.instance("graffiti_wall")
		model.name = "Model"
		sb.add_child(model)
		# a box with round ends, so a skater clipping an end glances off instead of snagging on a corner
		sb.add_child(_shape_box(Vector3(WALL_LEN - 0.42, 3.1, 0.42), Vector3(0.0, 1.55, 0.0)))
		for sgn: float in [-1.0, 1.0]:
			var cs := CollisionShape3D.new()
			cs.name = "EndCap"
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.21
			cyl.height = 3.1
			cs.shape = cyl
			cs.position = Vector3(sgn * (WALL_LEN * 0.5 - 0.21), 1.55, 0.0)
			sb.add_child(cs)
		for d: Array in w[3]:
			var q: MeshInstance3D = decal(str(d[0]), float(d[3]), Vector3(float(d[1]), float(d[2]), WALL_FRONT_Z - DECAL_LIFT), 180.0)
			sb.add_child(q)
		root.add_child(sb)
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

## Litter kinds, one MultiMeshInstance3D each: [litter_kit mesh, count, scale min, scale max, tint palette (empty for none)].
## The kit's can and cup print is vertex colour on a white material; the tints recolour it per instance.
const LITTER_KINDS: Array = [
	["can_crushed_a", 18, 1.4, 1.9, ["ff5a5f", "c9d3dd", "4a8fe0"]], ["can_crushed_b", 18, 1.4, 1.9, ["ff5a5f", "c9d3dd", "4a8fe0"]],
	["cup", 22, 1.3, 1.7, ["f6f1e8", "e8484f"]],
	["paper_crumpled_a", 14, 1.3, 1.8, []], ["paper_crumpled_b", 14, 1.3, 1.8, []],
	["chip_bag_a", 20, 1.1, 1.5, []], ["chip_bag_b", 20, 1.1, 1.5, []],
	["newspaper", 18, 0.9, 1.2, []], ["pizza_box", 6, 0.9, 1.1, []], ["napkin", 12, 1.3, 1.8, []],
]
const LITTER_STICKERS: Array = [["sticker_smile", 6], ["sticker_star", 6], ["sticker_sk8", 6], ["sticker_heart", 6]]


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


## All the litter: one MultiMeshInstance3D per litter_kit item (cheap) with fixed-seed positions, random yaw and scale, and one
## shared toon material (vertex colour on). No collision.
static func litter(avoid: Array[Rect2], seed_value: int = LITTER_SEED) -> Node3D:
	var root := Node3D.new()
	root.name = "Litter"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var total: int = 0
	for k: Array in LITTER_KINDS:
		total += int(k[1])
	for s: Array in LITTER_STICKERS:
		total += int(s[1])
	var pts: Array[Vector2] = litter_points(avoid, total, rng)
	var cursor: int = 0
	var mat: Material = Toon.material_vc(Color.WHITE)
	for k: Array in LITTER_KINDS:
		var mesh: Mesh = HoudiniProps.named_mesh("litter_kit", str(k[0]))
		var centre: AABB = mesh.get_aabb()
		var shift: Vector3 = Vector3(centre.get_center().x, 0.0, centre.get_center().z)
		var tints: Array = k[4]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = not tints.is_empty()
		mm.mesh = mesh
		var n: int = mini(int(k[1]), maxi(0, pts.size() - cursor))
		mm.instance_count = n
		for i: int in n:
			var p: Vector2 = pts[cursor + i]
			var b: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(float(k[2]), float(k[3])))
			mm.set_instance_transform(i, Transform3D(b, Vector3(p.x, 0.0, p.y) - b * shift))
			if not tints.is_empty():
				mm.set_instance_color(i, Color(str(tints[rng.randi() % tints.size()])))
		cursor += n
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Litter_" + str(k[0])
		mmi.multimesh = mm
		mmi.material_override = mat
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
