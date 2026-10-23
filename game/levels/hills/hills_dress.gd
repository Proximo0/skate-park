class_name HillsDress
extends RefCounted
## The Hills' code-built street furniture and yard pieces: privacy fences (grindable tops), retaining walls (a ledge on
## the cap), detached garages with a rideable gable roof, overlook guard rail, school-zone signs and flashing beacons,
## lamp posts, hedges and garden clutter. Every solid-looking part has collision; small clutter casts no shadow.

const FENCE_WOOD := Color("c79a6a")
const FENCE_CAP := Color("a77b50")
const WALL_STONE := Color("9a8f80")
const WALL_CAP := Color("d9d2c3")
const RAIL_METAL := Color("9aa3ad")
const SIGN_YELLOW := Color("f2c52e")
const POST_GREY := Color("6b7280")


static func _box_mesh(size: Vector3, colour: Color, pos: Vector3, node_name: String = "Box", shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Toon.material(colour, false)
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _box_shape(size: Vector3, pos: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	return cs


## A wooden privacy fence from a to b (both on the ground, y = the ground there), `h` tall: board panel, cap rail,
## posts. Collision is 0.3 m thick; the cap is a grind line. Returns a StaticBody3D in level space.
static func fence(a: Vector3, b: Vector3, h: float = 1.15, colour: Color = FENCE_WOOD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Fence"
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length: float = d.length()
	var yaw: float = atan2(d.x, d.z)
	var base_y: float = minf(a.y, b.y)
	var top_y: float = maxf(a.y, b.y) + h
	var mid := Vector3((a.x + b.x) * 0.5, 0.0, (a.z + b.z) * 0.5)
	body.transform = Transform3D(Basis(Vector3.UP, yaw), mid)
	var hh: float = top_y - base_y
	body.add_child(HillsDress._box_mesh(Vector3(0.08, hh - 0.06, length), colour, Vector3(0.0, base_y + (hh - 0.06) * 0.5, 0.0), "Boards"))
	body.add_child(HillsDress._box_mesh(Vector3(0.16, 0.07, length + 0.1), FENCE_CAP, Vector3(0.0, top_y - 0.035, 0.0), "Cap"))
	var posts: int = maxi(int(length / 2.4), 1)
	for k: int in posts + 1:
		var z: float = -length * 0.5 + length * float(k) / float(posts)
		body.add_child(HillsDress._box_mesh(Vector3(0.12, hh, 0.12), FENCE_CAP, Vector3(0.0, base_y + hh * 0.5, z), "Post", false))
	body.add_child(HillsDress._box_shape(Vector3(0.3, hh + 0.4, length), Vector3(0.0, base_y - 0.2 + (hh + 0.4) * 0.5, 0.0)))
	body.add_child(PieceKit.rail(PackedVector3Array([Vector3(0.0, top_y, -length * 0.5 + 0.1), Vector3(0.0, top_y, length * 0.5 - 0.1)]), "rail", "FenceTop"))
	return body


## A white picket fence from a to b (visual pickets, a low box collider, grindable top rail).
static func picket(a: Vector3, b: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Picket"
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length: float = d.length()
	var mid := Vector3((a.x + b.x) * 0.5, minf(a.y, b.y), (a.z + b.z) * 0.5)
	body.transform = Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), mid)
	var h: float = 0.95 + absf(a.y - b.y)
	var white := Color("f4f1ea")
	body.add_child(HillsDress._box_mesh(Vector3(0.05, 0.08, length), white, Vector3(0.0, h - 0.25, 0.0), "RailHi", false))
	body.add_child(HillsDress._box_mesh(Vector3(0.05, 0.08, length), white, Vector3(0.0, 0.3, 0.0), "RailLo", false))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := BoxMesh.new()
	pm.size = Vector3(0.03, h, 0.09)
	mm.mesh = pm
	var n: int = maxi(int(length / 0.16), 2)
	mm.instance_count = n
	for k: int in n:
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5 - 0.05, -length * 0.5 + (float(k) + 0.5) * length / float(n))))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Toon.material(white, false)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mmi)
	body.add_child(HillsDress._box_shape(Vector3(0.3, h + 0.3, length), Vector3(0.0, h * 0.5 - 0.15, 0.0)))
	body.add_child(PieceKit.rail(PackedVector3Array([Vector3(0.0, h - 0.05, -length * 0.5 + 0.1), Vector3(0.0, h - 0.05, length * 0.5 - 0.1)]), "rail", "PicketTop"))
	return body


## A retaining wall along x from x0 to x1 at z in [z0, z0 + thick], from `low` (under the lower ground) up to `top`,
## with a pale cap. The cap's two top edges are grind lines (ledges).
static func retaining_wall(x0: float, x1: float, z0: float, thick: float, low: float, top: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "RetainingWall"
	var size := Vector3(x1 - x0, top - low, thick)
	var c := Vector3((x0 + x1) * 0.5, (low + top) * 0.5, z0 + thick * 0.5)
	var mi: MeshInstance3D = HillsDress._box_mesh(size - Vector3(0.0, 0.08, 0.0), WALL_STONE, c - Vector3(0.0, 0.04, 0.0), "Wall")
	mi.material_override = WorldSurface.material("pavers", WALL_STONE, 0.3)
	body.add_child(mi)
	body.add_child(HillsDress._box_mesh(Vector3(size.x + 0.04, 0.1, thick + 0.08), WALL_CAP, Vector3(c.x, top - 0.05, c.z), "Cap"))
	body.add_child(HillsDress._box_shape(size, c))
	# the face toward +Z: block courses (thin dark joints) and a pilaster every few metres, so it reads as built stone
	var face_z: float = z0 + thick
	var joint: Color = WALL_STONE.darkened(0.3)
	var y: float = low + 2.6
	while y < top - 0.35:
		body.add_child(HillsDress._box_mesh(Vector3(size.x - 0.1, 0.05, 0.03), joint, Vector3(c.x, y, face_z + 0.005), "Joint", false))
		y += 0.75
	var px: float = x0 + 3.0
	while px < x1 - 1.0:
		body.add_child(HillsDress._box_mesh(Vector3(0.7, top - low - 0.1, 0.14), WALL_STONE.lightened(0.12), Vector3(px, (low + top) * 0.5 - 0.05, face_z + 0.06), "Pilaster", false))
		px += 6.5
	for z: float in [z0 + 0.02, z0 + thick - 0.02]:
		body.add_child(PieceKit.rail(PackedVector3Array([Vector3(x0 + 0.2, top, z), Vector3(x1 - 0.2, top, z)]), "ledge", "WallCap"))
	return body


## A detached garage from the kit (visual) with a solid body: walls to the eaves and the gable roof as two rideable
## slopes. `xf` places it (kit space: door facing -Z). Returns the node.
static func garage(kit: LevelKit, xf: Transform3D, tint: Color = Color(0, 0, 0, 0)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Garage"
	body.transform = xf
	body.add_child(kit.visual("garage", tint))
	var eave: float = 3.09
	var ridge: float = 4.93
	var hx: float = 3.3
	var hz: float = 3.53
	body.add_child(HillsDress._box_shape(Vector3(6.0, eave, 6.5), Vector3(0.0, eave * 0.5, 0.0)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var f0 := Vector3(-hx, eave, -hz)
	var f1 := Vector3(hx, eave, -hz)
	var r0 := Vector3(-hx, ridge, 0.0)
	var r1 := Vector3(hx, ridge, 0.0)
	var b0 := Vector3(-hx, eave, hz)
	var b1 := Vector3(hx, eave, hz)
	HillsRoad.tri_facing(st, f0, f1, r1, Vector3(0, 1, -0.5))
	HillsRoad.tri_facing(st, f0, r1, r0, Vector3(0, 1, -0.5))
	HillsRoad.tri_facing(st, b0, r1, b1, Vector3(0, 1, 0.5))
	HillsRoad.tri_facing(st, b0, r0, r1, Vector3(0, 1, 0.5))
	HillsRoad.tri_facing(st, f0, r0, b0, Vector3.LEFT)
	HillsRoad.tri_facing(st, f1, b1, r1, Vector3.RIGHT)
	var cs := CollisionShape3D.new()
	cs.name = "Roof"
	cs.shape = st.commit().create_trimesh_shape()
	body.add_child(cs)
	body.add_child(PieceKit.rail(PackedVector3Array([r0 + Vector3(0.2, 0.0, 0.0), r1 - Vector3(0.2, 0.0, 0.0)]), "ledge", "Ridge"))
	return body


## A guard rail of posts and a round top rail through `pts` (ground points), `h` high: grindable along its top.
static func guard_rail(pts: PackedVector3Array, h: float = 0.9) -> Node3D:
	var root := Node3D.new()
	root.name = "GuardRail"
	var line := PackedVector3Array()
	for p: Vector3 in pts:
		line.append(p + Vector3(0.0, h, 0.0))
	root.add_child(PieceKit.rail(line, "rail", "RailLine"))
	var body := StaticBody3D.new()
	body.name = "Posts"
	root.add_child(body)
	var mat: Material = Toon.material(RAIL_METAL, false)
	for i: int in line.size() - 1:
		var a: Vector3 = line[i]
		var b: Vector3 = line[i + 1]
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.045
		cyl.height = a.distance_to(b)
		cyl.radial_segments = 8
		mi.mesh = cyl
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dir: Vector3 = (b - a).normalized()
		var bx: Basis = Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
		mi.transform = Transform3D(bx, (a + b) * 0.5)
		root.add_child(mi)
		# a lower rail (visual) and the panel collision between posts
		var lo: MeshInstance3D = mi.duplicate() as MeshInstance3D
		lo.position -= Vector3(0.0, h * 0.5, 0.0)
		root.add_child(lo)
		var seg := Vector3(b.x - a.x, 0.0, b.z - a.z)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.3, h + 0.5, seg.length())
		cs.shape = bs
		cs.transform = Transform3D(Basis(Vector3.UP, atan2(seg.x, seg.z)), (pts[i] + pts[i + 1]) * 0.5 + Vector3(0.0, (h + 0.5) * 0.5 - 0.5, 0.0))
		body.add_child(cs)
	for p: Vector3 in pts:
		var post := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.05
		pc.bottom_radius = 0.06
		pc.height = h + 0.3
		pc.radial_segments = 6
		post.mesh = pc
		post.material_override = mat
		post.position = p + Vector3(0.0, (h + 0.3) * 0.5 - 0.3, 0.0)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(post)
	return root


## Text on a sign face: one-sided (a double-sided label on each face of a thin plate shows its mirror image through
## the plate, which made "SCHOOL" read "SCHOOB"), drawn from a big font (96 px) at a small pixel size so it stays crisp
## close up, depth-correct (alpha cut) and with anisotropic mipmaps for the glancing angles of a road.
static func sign_label(text: String, pixel: float, colour: Color, font_px: int = 96) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_px
	l.pixel_size = pixel
	l.modulate = colour
	l.outline_size = 0
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	l.shaded = false
	return l


## A sign on a post: `text` on a yellow diamond or a rectangle. Visual only.
static func sign_post(text: String, colour: Color = SIGN_YELLOW, diamond: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "Sign"
	# the post ends under the plate (a post running up the face would hide the lettering)
	root.add_child(HillsDress._box_mesh(Vector3(0.08, 1.8, 0.08), POST_GREY, Vector3(0.0, 0.9, 0.0), "Post", false))
	var plate := HillsDress._box_mesh(Vector3(0.75, 0.75, 0.04), colour, Vector3(0.0, 2.25, 0.0), "Plate", false)
	if diamond:
		plate.rotation = Vector3(0.0, 0.0, PI * 0.25)
	root.add_child(plate)
	var l := HillsDress.sign_label(text, 0.0019, Color("1d1d1f"))
	l.position = Vector3(0.0, 2.25, -0.03)
	l.rotation = Vector3(0.0, PI, 0.0)
	root.add_child(l)
	var l2: Label3D = l.duplicate() as Label3D
	l2.position = Vector3(0.0, 2.25, 0.03)
	l2.rotation = Vector3.ZERO
	root.add_child(l2)
	return root


## A street lamp: pole, arm and a warm head (emissive, no real light).
static func lamp(height: float = 5.5) -> Node3D:
	var root := Node3D.new()
	root.name = "Lamp"
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.1
	cyl.height = height
	cyl.radial_segments = 8
	pole.mesh = cyl
	pole.material_override = Toon.material(Color("54606e"), false)
	pole.position = Vector3(0.0, height * 0.5, 0.0)
	root.add_child(pole)
	root.add_child(HillsDress._box_mesh(Vector3(0.08, 0.08, 1.2), Color("54606e"), Vector3(0.0, height - 0.1, 0.55), "Arm", false))
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.36, 0.14, 0.55)
	head.mesh = hm
	var em := StandardMaterial3D.new()
	em.albedo_color = Color("ffe2a8")
	em.emission_enabled = true
	em.emission = Color("ffcf7a")
	em.emission_energy_multiplier = 1.4
	head.material_override = em
	head.position = Vector3(0.0, height - 0.2, 1.05)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(head)
	var body := StaticBody3D.new()
	body.add_child(HillsDress._box_shape(Vector3(0.3, height, 0.3), Vector3(0.0, height * 0.5, 0.0)))
	root.add_child(body)
	return root


## A hedge block (visual + collision), w x h x d centred on `c` (y = its base).
static func hedge(c: Vector3, size: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Hedge"
	body.transform = Transform3D(Basis(Vector3.UP, yaw), c)
	var mi: MeshInstance3D = HillsDress._box_mesh(size, Color("4f7d3a"), Vector3(0.0, size.y * 0.5, 0.0), "Leaves")
	var sm := SphereMesh.new()
	mi.mesh = BoxMesh.new()
	(mi.mesh as BoxMesh).size = size
	body.add_child(mi)
	for k: int in maxi(int(size.x / 1.2), 1):
		var blob := MeshInstance3D.new()
		sm.radius = size.y * 0.32
		sm.height = size.y * 0.5
		sm.radial_segments = 8
		sm.rings = 4
		blob.mesh = sm
		blob.material_override = Toon.material(Color("5d8f43"), false)
		blob.position = Vector3(-size.x * 0.5 + (float(k) + 0.5) * size.x / float(maxi(int(size.x / 1.2), 1)), size.y, 0.0)
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(blob)
	body.add_child(HillsDress._box_shape(size, Vector3(0.0, size.y * 0.5, 0.0)))
	return body


## A flashing amber school-zone beacon: a post with two lamps that alternate (a tiny node script-free flasher: the
## caller animates `lamps` with HillsLife). Returns [node, lamp_a_material, lamp_b_material].
static func beacon() -> Array:
	var root := Node3D.new()
	root.name = "Beacon"
	root.add_child(HillsDress._box_mesh(Vector3(0.1, 1.55, 0.1), POST_GREY, Vector3(0.0, 0.775, 0.0), "Post", false))
	var plate := HillsDress._box_mesh(Vector3(0.9, 1.1, 0.05), SIGN_YELLOW, Vector3(0.0, 2.1, 0.0), "Plate", false)
	root.add_child(plate)
	for side: float in [-1.0, 1.0]:
		var l := HillsDress.sign_label("SCHOOL\nZONE\n25", 0.0022, Color("1d1d1f"))
		l.position = Vector3(0.0, 2.1, side * 0.035)
		l.rotation = Vector3(0.0, 0.0 if side > 0.0 else PI, 0.0)
		root.add_child(l)
	var mats: Array[StandardMaterial3D] = []
	for k: int in 2:
		var lamp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		sm.radial_segments = 10
		sm.rings = 5
		lamp.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("ffb21e")
		m.emission_enabled = true
		m.emission = Color("ffae00")
		m.emission_energy_multiplier = 2.0
		lamp.material_override = m
		lamp.position = Vector3(-0.25 + 0.5 * float(k), 2.85, 0.0)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lamp)
		mats.append(m)
	var body := StaticBody3D.new()
	body.add_child(HillsDress._box_shape(Vector3(0.3, 3.2, 0.3), Vector3(0.0, 1.6, 0.0)))
	root.add_child(body)
	return [root, mats[0], mats[1]]


## A long guard rail through `pts` (ground points) built cheaply: the top and middle rails are two tube meshes, the
## posts one MultiMesh, the panels box shapes in one body. The top rail is a grind line.
static func long_rail(pts: PackedVector3Array, h: float = 0.95) -> Node3D:
	var root := Node3D.new()
	root.name = "LongRail"
	var top := PackedVector3Array()
	var mid := PackedVector3Array()
	for p: Vector3 in pts:
		top.append(p + Vector3(0.0, h, 0.0))
		mid.append(p + Vector3(0.0, h * 0.5, 0.0))
	var mat: Material = Toon.material(RAIL_METAL, false)
	for line: PackedVector3Array in [top, mid]:
		var mi := MeshInstance3D.new()
		mi.mesh = HillsPool.tube(line, 0.05, 8)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pc := CylinderMesh.new()
	pc.top_radius = 0.05
	pc.bottom_radius = 0.06
	pc.height = h + 0.4
	pc.radial_segments = 6
	mm.mesh = pc
	mm.instance_count = pts.size()
	for i: int in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i] + Vector3(0.0, (h + 0.4) * 0.5 - 0.4, 0.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	var body := StaticBody3D.new()
	body.name = "Panels"
	root.add_child(body)
	for i: int in pts.size() - 1:
		var seg := Vector3(pts[i + 1].x - pts[i].x, 0.0, pts[i + 1].z - pts[i].z)
		var lo: float = minf(pts[i].y, pts[i + 1].y) - 0.5
		var hi: float = maxf(pts[i].y, pts[i + 1].y) + h
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.3, hi - lo, seg.length())
		cs.shape = bs
		var c: Vector3 = (pts[i] + pts[i + 1]) * 0.5
		cs.transform = Transform3D(Basis(Vector3.UP, atan2(seg.x, seg.z)), Vector3(c.x, (lo + hi) * 0.5, c.z))
		body.add_child(cs)
	root.add_child(PieceKit.rail(top, "rail", "RailLine"))
	return root
