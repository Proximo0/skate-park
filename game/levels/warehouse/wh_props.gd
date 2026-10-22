class_name WhProps
extends RefCounted
## Code-built industrial props for the Creepy Warehouse: trailers, rolling stock, the gantry crane, pipe runs, the boiler
## house and smokestack, tanks, a water tower, a guard booth, jersey barriers, signal masts. Visual geometry goes into
## the caller's WhGeo.Batch, collision boxes onto its StaticBody3D, grind lines and gap zones under the level.

const RUST_PAINT := Color("5a2e1c")
const STEEL_DARK := Color("3f4247")
const TYRE := Color("1d1d21")
const SAFETY := Color("e3b324")

static var _chain: StandardMaterial3D = null


## Chain-link diamonds (alpha scissor), tiled per metre on the batch's metre UVs.
static func chain_material() -> StandardMaterial3D:
	if _chain != null:
		return _chain
	var n: int = 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i: int in n:
		for w: int in 2:
			var a: int = (i + w) % n
			img.set_pixel(i, a, Color(0.72, 0.74, 0.76, 1.0))
			img.set_pixel(i, (n - 1 - i + w) % n, Color(0.72, 0.74, 0.76, 1.0))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(0.55, 0.57, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_scale = Vector3(2.4, 2.4, 1.0)
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_chain = m
	return m


static func _wheels(bt: WhGeo.Batch, x: float, y: float, z0: float, z1: float, r: float, along_z: bool, m: Material) -> void:
	for z: float in [z0, z1]:
		if along_z:
			bt.pipe(Vector3(x - 1.2, y, z), Vector3(x - 0.75, y, z), r, m, 10)
			bt.pipe(Vector3(x + 0.75, y, z), Vector3(x + 1.2, y, z), r, m, 10)
		else:
			bt.pipe(Vector3(z, y, x - 1.2), Vector3(z, y, x - 0.75), r, m, 10)
			bt.pipe(Vector3(z, y, x + 0.75), Vector3(z, y, x + 1.2), r, m, 10)


## A 13 m box trailer: rear at `rear` (x centre, z of the rear), running toward +Z. Solid down to the ground.
static func box_trailer(bt: WhGeo.Batch, sb: StaticBody3D, rear: Vector3, colour: Color) -> void:
	var x: float = rear.x
	var z0: float = rear.z
	var body := WhGeo.mat("metal", colour, 0.6, 0.4, RUST_PAINT, 1.0, 1.25)
	var dark := WhGeo.mat("rust", STEEL_DARK, 0.5, 0.2)
	var tyre := WhGeo.mat("paint", TYRE, 0.0, 0.0)
	bt.box_min(Vector3(x - 1.3, 1.25, z0 + 0.05), Vector3(2.6, 2.85, 13.0), body)
	bt.box_min(Vector3(x - 1.32, 4.08, z0), Vector3(2.64, 0.08, 13.1), dark)
	bt.box_min(Vector3(x - 1.0, 0.95, z0 + 0.3), Vector3(2.0, 0.3, 12.6), dark)
	# rear doors: frame, hinges and lock bars
	bt.box_min(Vector3(x - 1.32, 1.2, z0), Vector3(2.64, 0.12, 0.08), dark)
	for bx: float in [-0.65, -0.25, 0.25, 0.65]:
		bt.box_min(Vector3(x + bx - 0.03, 1.4, z0 - 0.03), Vector3(0.06, 2.6, 0.04), dark)
	bt.box_min(Vector3(x - 1.25, 1.0, z0 - 0.02), Vector3(2.5, 0.2, 0.06), WhGeo.mat("paint", Color("b32a24"), 0.4, 0.0))
	_wheels(bt, x, 0.5, z0 + 1.6, z0 + 2.9, 0.5, true, tyre)
	for lx: float in [-0.8, 0.8]:
		bt.box_min(Vector3(x + lx - 0.06, 0.0, z0 + 10.0), Vector3(0.12, 1.0, 0.12), dark)
	WhGeo.solid_min(sb, Vector3(x - 1.3, 0.0, z0), Vector3(2.6, 4.1, 13.1))


## A 13 m flatbed you can ride: deck top 1.45 m, edges grindable. Rear at `rear` (on the dock face), running toward +Z.
static func flatbed(lvl: Node, bt: WhGeo.Batch, sb: StaticBody3D, rear: Vector3) -> void:
	var x: float = rear.x
	var z0: float = rear.z
	var deck := WhGeo.mat("plywood", Color("7d6a55"), 0.6, 0.3)
	var steel := WhGeo.mat("rust", Color("4b4f56"), 0.7, 0.2)
	var tyre := WhGeo.mat("paint", TYRE, 0.0, 0.0)
	bt.box_min(Vector3(x - 1.25, 1.27, z0), Vector3(2.5, 0.18, 13.0), deck)
	bt.box_min(Vector3(x - 1.27, 1.12, z0), Vector3(0.1, 0.33, 13.0), steel)
	bt.box_min(Vector3(x + 1.17, 1.12, z0), Vector3(0.1, 0.33, 13.0), steel)
	bt.box_min(Vector3(x - 0.9, 0.85, z0 + 0.2), Vector3(1.8, 0.3, 12.6), steel)
	_wheels(bt, x, 0.5, z0 + 1.6, z0 + 2.9, 0.5, true, tyre)
	for lx: float in [-0.8, 0.8]:
		bt.box_min(Vector3(x + lx - 0.06, 0.0, z0 + 10.0), Vector3(0.12, 0.9, 0.12), steel)
	WhGeo.solid_min(sb, Vector3(x - 1.27, 0.0, z0), Vector3(2.54, 1.45, 13.0))
	for ex: float in [x - 1.25, x + 1.25]:
		WhGeo.grind(lvl, PackedVector3Array([Vector3(ex, 1.45, z0 + 0.2), Vector3(ex, 1.45, z0 + 12.9)]), "ledge", "FlatbedEdge")


## A concrete jersey barrier along X centred at `c`.
static func jersey(bt: WhGeo.Batch, c: Vector3, length: float, m: Material) -> void:
	var prof := PackedVector2Array([Vector2(0.0, -0.3), Vector2(0.0, 0.3), Vector2(0.08, 0.3), Vector2(0.33, 0.2), Vector2(0.81, 0.1),
			Vector2(0.81, -0.1), Vector2(0.33, -0.2), Vector2(0.08, -0.3)])
	var mesh: ArrayMesh = PieceKit.extrude_profile(prof, length)
	bt.mesh(mesh, Transform3D(Basis.IDENTITY, Vector3(c.x - length * 0.5, c.y, c.z)), m)


## The night guard's booth: a small hut with a lit window, by the south gate.
static func guard_booth(lvl: Node, bt: WhGeo.Batch, sb: StaticBody3D, p: Vector3) -> void:
	var wall := WhGeo.mat("paint", Color("8c8f86"), 0.6, 0.6, Color("4a3a2a"), 1.0, p.y)
	var roof := WhGeo.mat("rust", Color("3c3f45"), 0.6, 0.0)
	WhGeo.block(bt, sb, p + Vector3(-1.6, 0.0, -1.6), Vector3(3.2, 2.7, 3.2), wall)
	bt.box_min(p + Vector3(-1.9, 2.7, -1.9), Vector3(3.8, 0.18, 3.8), roof)
	var lit := WhGeo.glow(Color(1.0, 0.82, 0.5))
	for side: Vector3 in [Vector3(0, 0, 1.61), Vector3(1.61, 0, 0), Vector3(0, 0, -1.61)]:
		var w: Vector3 = Vector3(1.6, 0.9, 0.02) if absf(side.z) > 0.5 else Vector3(0.02, 0.9, 1.6)
		bt.box(p + side + Vector3(0, 1.55, 0), w, lit)
	bt.box(p + Vector3(-1.61, 1.0, 0.0), Vector3(0.03, 2.0, 0.9), WhGeo.mat("paint", Color("3f4a5a"), 0.5, 0.2))
	var pool: MeshInstance3D = FlickerLight.light_pool(4.0, Color(1.0, 0.75, 0.4), 0.35)
	pool.position = p + Vector3(0.0, 0.02, 2.2)
	lvl.add_child(pool)


## A rail-mounted gantry crane straddling the lane at `c` (between the container rows), with a container hanging.
static func gantry_crane(lvl: Node, bt: WhGeo.Batch, sb: StaticBody3D, c: Vector3) -> void:
	var paint := WhGeo.mat("paint", Color("c98a2a"), 0.8, 0.4, Color("5a2e1c"))
	var dark := WhGeo.mat("rust", STEEL_DARK, 0.6, 0.0)
	var hx: float = 5.25
	var hz: float = 8.0
	var top: float = 15.0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var lp := Vector3(c.x + sx * hx, 0.0, c.z + sz * hz)
			bt.box(lp + Vector3(0, top * 0.5, 0), Vector3(0.7, top, 0.7), paint)
			bt.box(lp + Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 1.6), dark)
			WhGeo.solid(sb, lp + Vector3(0, top * 0.5, 0), Vector3(0.8, top, 0.8))
			WhGeo.solid(sb, lp + Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 1.6))
		# side girder along z on each side, and diagonal braces
		bt.box(Vector3(c.x + sx * hx, top + 0.6, c.z), Vector3(0.9, 1.2, hz * 2.0 + 0.9), paint)
		bt.box(Vector3(c.x + sx * hx, top * 0.55, c.z), Vector3(0.35, 0.35, hz * 2.0), paint)
	for sz: float in [-1.0, 1.0]:
		bt.box(Vector3(c.x, top + 1.5, c.z + sz * hz), Vector3(hx * 2.0 + 1.6, 1.4, 1.0), paint)
	# trolley, cables, spreader and the hanging container
	var tz: float = c.z
	bt.box(Vector3(c.x, top + 2.6, tz), Vector3(3.2, 1.0, 2.6), paint)
	for dx: float in [-1.0, 1.0]:
		for dz: float in [-0.8, 0.8]:
			bt.pipe(Vector3(c.x + dx, top + 2.1, tz + dz), Vector3(c.x + dx * 1.4, 10.0, tz + dz), 0.03, dark, 4)
	bt.box(Vector3(c.x, 9.8, tz), Vector3(6.2, 0.35, 2.5), paint)
	var cont := WhGeo.mat("metal", Color("2f4f74"), 0.8, 0.5, RUST_PAINT)
	bt.box(Vector3(c.x, 8.3, tz), Vector3(6.1, 2.6, 2.45), cont)
	# crane rails on the ground (visual)
	for sx: float in [-1.0, 1.0]:
		bt.box_min(Vector3(c.x + sx * hx - 0.06, 0.0, c.z - 40.0), Vector3(0.12, 0.012, 70.0), dark)
	var sign_l := Label3D.new()
	sign_l.text = "GANTRY 3"
	sign_l.font_size = 120
	sign_l.pixel_size = 0.012
	sign_l.modulate = Color(0.12, 0.1, 0.08)
	sign_l.position = Vector3(c.x, top + 1.5, c.z + hz + 0.52)
	lvl.add_child(sign_l)


## Bogies (two wheel sets each end) under a rail car along x centred at c.
static func _bogies(bt: WhGeo.Batch, c: Vector3, length: float) -> void:
	var dark := WhGeo.mat("rust", Color("2f3034"), 0.7, 0.0)
	for e: float in [-1.0, 1.0]:
		var bx: float = c.x + e * (length * 0.5 - 2.2)
		bt.box(Vector3(bx, 0.62, c.z), Vector3(2.6, 0.45, 2.3), dark)
		for wx: float in [-0.85, 0.85]:
			for s: float in [-1.0, 1.0]:
				bt.pipe(Vector3(bx + wx, 0.42, c.z + s * 0.6), Vector3(bx + wx, 0.42, c.z + s * 0.82), 0.42, dark, 10)
	for e: float in [-1.0, 1.0]:
		bt.box(Vector3(c.x + e * (length * 0.5 + 0.35), 0.95, c.z), Vector3(0.7, 0.25, 0.3), dark)


## A closed boxcar along x (solid).
static func boxcar(lvl: Node, bt: WhGeo.Batch, sb: StaticBody3D, c: Vector3, length: float, colour: Color, graffiti: String) -> void:
	var body := WhGeo.mat("metal", colour, 0.85, 0.5, RUST_PAINT, 1.0, 1.1)
	var dark := WhGeo.mat("rust", STEEL_DARK, 0.6, 0.0)
	bt.box(Vector3(c.x, 2.7, c.z), Vector3(length, 3.2, 3.0), body)
	bt.box(Vector3(c.x, 4.36, c.z), Vector3(length + 0.1, 0.12, 2.7), dark)
	bt.box(Vector3(c.x, 1.0, c.z), Vector3(length, 0.2, 2.9), dark)
	for s: float in [-1.0, 1.0]:
		bt.box(Vector3(c.x, 2.6, c.z + s * 1.53), Vector3(2.8, 2.9, 0.06), dark)
		bt.box(Vector3(c.x - 1.6, 4.0, c.z + s * 1.56), Vector3(0.12, 0.12, 0.08), dark)
		lvl.add_child(WhGeo.tag(graffiti, 4.4, Vector3(c.x + length * 0.25, 2.6, c.z + s * 1.52), 0.0 if s > 0.0 else 180.0))
		lvl.add_child(WhGeo.tag("tag_spud" if s > 0.0 else "tag_koi", 2.6, Vector3(c.x - length * 0.3, 2.2, c.z + s * 1.52), 0.0 if s > 0.0 else 180.0))
	_bogies(bt, c, length)
	WhGeo.solid(sb, Vector3(c.x, 2.2, c.z), Vector3(length, 4.4, 3.0))


## A flatcar along x: deck top 1.3 m, both deck edges grindable.
static func flatcar(lvl: Node, bt: WhGeo.Batch, sb: StaticBody3D, c: Vector3, length: float) -> void:
	var deck := WhGeo.mat("plywood", Color("6b5a48"), 0.7, 0.2)
	var steel := WhGeo.mat("rust", Color("4d4a47"), 0.85, 0.1)
	bt.box(Vector3(c.x, 1.18, c.z), Vector3(length, 0.24, 2.9), deck)
	for s: float in [-1.0, 1.0]:
		bt.box(Vector3(c.x, 1.1, c.z + s * 1.47), Vector3(length, 0.4, 0.08), steel)
		for i: int in 7:
			bt.box(Vector3(c.x - length * 0.5 + 1.0 + float(i) * (length - 2.0) / 6.0, 0.95, c.z + s * 1.52), Vector3(0.14, 0.2, 0.06), steel)
	bt.box(Vector3(c.x, 0.85, c.z), Vector3(length, 0.3, 1.0), steel)
	_bogies(bt, c, length)
	WhGeo.solid(sb, Vector3(c.x, 0.65, c.z), Vector3(length, 1.3, 3.0))
	for s: float in [-1.0, 1.0]:
		WhGeo.grind(lvl, PackedVector3Array([Vector3(c.x - length * 0.5 + 0.1, 1.3, c.z + s * 1.5), Vector3(c.x + length * 0.5 - 0.1, 1.3, c.z + s * 1.5)]), "ledge", "FlatcarEdge")


## An open gondola along x: floor 1.0 m, walls to 2.6 m whose rims are grindable.
static func gondola(lvl: Node, bt: WhGeo.Batch, sb: StaticBody3D, c: Vector3, length: float) -> void:
	var body := WhGeo.mat("rust", Color("4e3a30"), 0.9, 0.3, Color("7a3a1e"))
	var dark := WhGeo.mat("rust", STEEL_DARK, 0.6, 0.0)
	var t: float = 0.15
	bt.box(Vector3(c.x, 0.9, c.z), Vector3(length, 0.2, 3.0), dark)
	WhGeo.solid(sb, Vector3(c.x, 0.5, c.z), Vector3(length, 1.0, 3.0))
	for s: float in [-1.0, 1.0]:
		var wz: float = c.z + s * (1.5 - t * 0.5)
		WhGeo.block(bt, sb, Vector3(c.x - length * 0.5, 1.0, wz - t * 0.5), Vector3(length, 1.6, t), body)
		for i: int in 9:
			bt.box(Vector3(c.x - length * 0.5 + 0.6 + float(i) * (length - 1.2) / 8.0, 1.8, c.z + s * 1.53), Vector3(0.12, 1.6, 0.06), dark)
		WhGeo.grind(lvl, PackedVector3Array([Vector3(c.x - length * 0.5 + 0.1, 2.6, wz), Vector3(c.x + length * 0.5 - 0.1, 2.6, wz)]), "ledge", "GondolaRim")
	for e: float in [-1.0, 1.0]:
		WhGeo.block(bt, sb, Vector3(c.x + e * (length * 0.5 - t * 0.5) - t * 0.5, 1.0, c.z - 1.5 + t), Vector3(t, 1.6, 3.0 - t * 2.0), body)
	# scrap inside
	bt.box(Vector3(c.x - 2.0, 1.3, c.z), Vector3(3.0, 0.6, 2.0), dark)
	bt.box(Vector3(c.x + 3.0, 1.2, c.z + 0.3), Vector3(2.0, 0.4, 1.6), WhGeo.mat("rust", Color("5a4a3a"), 0.9, 0.0))
	lvl.add_child(WhGeo.tag("throw_yuzu", 4.0, Vector3(c.x, 1.9, c.z + 1.535), 0.0))
	_bogies(bt, c, length)


## A rail signal mast with a red aspect.
static func signal_mast(lvl: Node, bt: WhGeo.Batch, p: Vector3) -> void:
	var dark := WhGeo.mat("rust", STEEL_DARK, 0.5, 0.0)
	bt.pipe(p, p + Vector3(0, 5.6, 0), 0.09, dark, 6)
	bt.box(p + Vector3(0, 5.3, 0.15), Vector3(0.5, 1.1, 0.3), dark)
	for k: int in 2:
		var lamp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.22
		sm.radial_segments = 8
		sm.rings = 4
		lamp.mesh = sm
		lamp.material_override = WhGeo.glow(Color(2.4, 0.25, 0.15) if k == 0 else Color(0.08, 0.16, 0.1))
		lamp.position = p + Vector3(0, 5.55 - float(k) * 0.42, 0.32)
		lvl.add_child(lamp)


## A water tower on four legs (legs solid).
static func water_tower(lvl: Node, bt: WhGeo.Batch, sb: StaticBody3D, p: Vector3) -> void:
	var steel := WhGeo.mat("rust", Color("5f6266"), 0.9, 0.0)
	var tank := WhGeo.mat("metal", Color("7c7a76"), 0.9, 0.0, RUST_PAINT)
	var leg_top: float = 15.0
	for a: float in [0.785, 2.356, 3.927, 5.498]:
		var base: Vector3 = p + Vector3(cos(a), 0, sin(a)) * 4.2
		var top: Vector3 = p + Vector3(cos(a), 0, sin(a)) * 3.0 + Vector3(0, leg_top, 0)
		bt.pipe(base, top, 0.22, steel, 6)
		WhGeo.solid(sb, base + Vector3(0, 1.5, 0), Vector3(0.6, 3.0, 0.6))
	for y: float in [5.0, 10.0]:
		for i: int in 4:
			var a0: float = 0.785 + float(i) * PI * 0.5
			var a1: float = a0 + PI * 0.5
			var r: float = lerpf(4.2, 3.0, y / leg_top)
			bt.pipe(p + Vector3(cos(a0) * r, y, sin(a0) * r), p + Vector3(cos(a1) * r, y, sin(a1) * r), 0.07, steel, 4)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.4
	cyl.bottom_radius = 4.4
	cyl.height = 6.0
	cyl.radial_segments = 20
	bt.mesh(cyl, Transform3D(Basis.IDENTITY, p + Vector3(0, leg_top + 3.0, 0)), tank)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.3
	cone.bottom_radius = 4.7
	cone.height = 2.2
	cone.radial_segments = 20
	bt.mesh(cone, Transform3D(Basis.IDENTITY, p + Vector3(0, leg_top + 7.1, 0)), steel)
	var l := Label3D.new()
	l.text = "NOX CHEMICAL"
	l.font_size = 160
	l.pixel_size = 0.014
	l.modulate = Color(0.16, 0.15, 0.15)
	l.position = p + Vector3(0, leg_top + 3.4, 4.45)
	lvl.add_child(l)


## A pipe along z at x (radius r, centre height cy) for each [z0, z1] segment, on concrete saddles; solid underneath.
## `grind` adds a grind line along the top.
static func pipe_run(lvl: Node, bt: WhGeo.Batch, sb: StaticBody3D, x: float, r: float, cy: float, segs: Array, grind: bool) -> void:
	var pm := WhGeo.mat("rust", Color("6f655c"), 0.9, 0.0, Color("7b3e1e"))
	var conc := WhGeo.mat("concrete", Color("8b8882"), 0.6, 0.5)
	var flange := WhGeo.mat("rust", Color("4a4440"), 0.6, 0.0)
	for s: Vector2 in segs:
		bt.pipe(Vector3(x, cy, s.x), Vector3(x, cy, s.y), r, pm, 12)
		var z: float = s.x + 1.0
		while z < s.y - 0.5:
			bt.box(Vector3(x, (cy - r * 0.4) * 0.5, z), Vector3(r * 2.0 + 0.3, cy - r * 0.4, 0.5), conc)
			bt.pipe(Vector3(x, cy, z + 2.4), Vector3(x, cy, z + 2.55), r + 0.05, flange, 12)
			z += 5.0
		WhGeo.solid(sb, Vector3(x, (cy + r) * 0.5, (s.x + s.y) * 0.5), Vector3(r * 2.0, cy + r, s.y - s.x))
		if grind:
			WhGeo.grind(lvl, PackedVector3Array([Vector3(x, cy + r, s.x + 0.2), Vector3(x, cy + r, s.y - 0.2)]), "rail", "PipeTop")


## Where the pipes leave the ground runs and climb over the lane between z0 and z1 at top_y (risers solid).
static func pipe_bridge(lvl: Node, bt: WhGeo.Batch, sb: StaticBody3D, xs: Array, rs: Array, cys: Array, z0: float, z1: float, top_y: float) -> void:
	var pm := WhGeo.mat("rust", Color("6f655c"), 0.9, 0.0, Color("7b3e1e"))
	var frame := WhGeo.mat("paint", Color("4e5560"), 0.7, 0.2)
	for i: int in xs.size():
		var x: float = float(xs[i])
		var r: float = float(rs[i])
		var cy: float = float(cys[i])
		var ty: float = top_y + float(i) * 0.9
		for z: float in [z0, z1]:
			bt.pipe(Vector3(x, cy, z), Vector3(x, ty, z), r, pm, 12)
			bt.box(Vector3(x, cy, z), Vector3(r * 2.2, r * 2.2, r * 2.2), pm)
			bt.box(Vector3(x, ty, z), Vector3(r * 2.2, r * 2.2, r * 2.2), pm)
			WhGeo.solid(sb, Vector3(x, ty * 0.5, z), Vector3(r * 2.0, ty, r * 2.0))
		bt.pipe(Vector3(x, ty, z0), Vector3(x, ty, z1), r, pm, 12)
	# a steel portal frame carrying the span
	for z: float in [z0 + 6.0, z1 - 6.0]:
		var xa: float = float(xs[xs.size() - 1]) - 1.2
		var xb: float = float(xs[0]) + 1.2
		bt.box(Vector3(xa, top_y * 0.5, z), Vector3(0.3, top_y, 0.3), frame)
		bt.box(Vector3(xb, top_y * 0.5, z), Vector3(0.3, top_y, 0.3), frame)
		bt.box(Vector3((xa + xb) * 0.5, top_y - 0.6, z), Vector3(xb - xa + 0.3, 0.3, 0.3), frame)
		WhGeo.solid(sb, Vector3(xa, top_y * 0.5, z), Vector3(0.4, top_y, 0.4))
		WhGeo.solid(sb, Vector3(xb, top_y * 0.5, z), Vector3(0.4, top_y, 0.4))
	lvl.add_child(WhGeo.tag("tag_drip", 2.0, Vector3(float(xs[0]) + 1.36, 2.4, z0 + 6.0), 90.0))


## The brick boiler house (solid) with lit and broken windows.
static func boiler_house(lvl: Node, bt: WhGeo.Batch, sb: StaticBody3D, r: Rect2, h: float) -> void:
	var brick := WhGeo.mat("brick", Color("6e4034"), 0.7, 0.8, Color("4d4945"))
	var trim := WhGeo.mat("concrete", Color("85827c"), 0.6, 0.3)
	WhGeo.block(bt, sb, Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, h, r.size.y), brick)
	bt.box_min(Vector3(r.position.x - 0.2, h, r.position.y - 0.2), Vector3(r.size.x + 0.4, 0.5, r.size.y + 0.4), trim)
	var lit := WhGeo.glow(Color(1.3, 0.8, 0.4))
	var dark := WhGeo.glow(Color(0.04, 0.045, 0.06))
	var fx: float = r.end.x + 0.02
	var i: int = 0
	for z: float in range(int(r.position.y) + 2, int(r.end.y) - 1, 3):
		for y: float in [3.0, 7.0]:
			var m: Material = lit if (i * 7 + int(y)) % 5 == 0 else dark
			bt.box(Vector3(fx, y, float(z) + 0.5), Vector3(0.04, 1.8, 1.4), m)
			bt.box(Vector3(fx + 0.02, y - 1.0, float(z) + 0.5), Vector3(0.12, 0.12, 1.6), trim)
			i += 1
	bt.box(Vector3(fx, 1.8, r.get_center().y), Vector3(0.06, 3.6, 3.2), WhGeo.mat("metal", Color("5d4a3c"), 0.9, 0.5))
	lvl.add_child(WhGeo.tag("throw_bonz", 6.0, Vector3(fx + 0.05, 2.2, r.position.y + 5.0), 90.0))


## A tapered brick smokestack with a blinking red light on top (solid base).
static func smokestack(lvl: Node, bt: WhGeo.Batch, sb: StaticBody3D, p: Vector3, r: float, h: float) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = r * 0.7
	cyl.bottom_radius = r
	cyl.height = h
	cyl.radial_segments = 16
	bt.mesh(cyl, Transform3D(Basis.IDENTITY, p + Vector3(0, h * 0.5, 0)), WhGeo.mat("brick", Color("6a3a30"), 0.9, 0.6, Color("3d3935")))
	for y: float in [h * 0.35, h * 0.7, h - 0.6]:
		var band := CylinderMesh.new()
		var rr: float = lerpf(r, r * 0.7, y / h) + 0.06
		band.top_radius = rr
		band.bottom_radius = rr
		band.height = 0.4
		band.radial_segments = 16
		bt.mesh(band, Transform3D(Basis.IDENTITY, p + Vector3(0, y, 0)), WhGeo.mat("rust", Color("3a3a3c"), 0.6, 0.0))
	WhGeo.solid(sb, p + Vector3(0, 3.0, 0), Vector3(r * 1.8, 6.0, r * 1.8))
	var beacon := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	beacon.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(3.0, 0.2, 0.1)
	bm.disable_fog = true
	beacon.material_override = bm
	beacon.position = p + Vector3(0, h + 0.4, 0)
	lvl.add_child(beacon)
	WhLights.blink(beacon, bm, 1.6, 0.25)


## A vertical storage tank (solid cylinder) with a cone roof and a ladder.
static func tank(lvl: Node, bt: WhGeo.Batch, sb: StaticBody3D, p: Vector3, r: float, h: float) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = h
	cyl.radial_segments = 20
	bt.mesh(cyl, Transform3D(Basis.IDENTITY, p + Vector3(0, h * 0.5, 0)), WhGeo.mat("metal", Color("6c6b66"), 0.85, 0.7, RUST_PAINT, 1.0, p.y))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = r + 0.1
	cone.height = 1.2
	cone.radial_segments = 20
	bt.mesh(cone, Transform3D(Basis.IDENTITY, p + Vector3(0, h + 0.6, 0)), WhGeo.mat("rust", Color("5d5a56"), 0.8, 0.0))
	var dark := WhGeo.mat("rust", STEEL_DARK, 0.5, 0.0)
	for s: float in [-0.25, 0.25]:
		bt.pipe(p + Vector3(r + 0.25, 0.0, s), p + Vector3(r + 0.25, h, s), 0.03, dark, 4)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	cs.position = p + Vector3(0, h * 0.5, 0)
	sb.add_child(cs)
	# a bolted-on warning plate (flat, standing off the curve on two brackets) somebody sprayed a skull over
	var plate_c: Vector3 = p + Vector3(0, 2.6, r + 0.12)
	bt.box(plate_c, Vector3(1.7, 1.7, 0.04), WhGeo.mat("paint", Color("c9b23a"), 0.6, 0.6, RUST_PAINT))
	for bx: float in [-0.6, 0.6]:
		bt.box(plate_c + Vector3(bx, 0, -0.08), Vector3(0.08, 1.2, 0.16), dark)
	lvl.add_child(WhGeo.tag("motif_skull", 1.5, plate_c + Vector3(0, 0, 0.025), 0.0))
