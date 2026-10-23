class_name DtKit
extends RefCounted
## Downtown's building blocks: collision helpers, grind lines, gap zones and ramp lips, plus the skateable street
## furniture every area uses (granite ledges, manual pads, sloped hubba ledges, banks, stair sets with a smooth hidden
## slope, kickers, round ledges). Visuals go into a DtBatch (one draw call per area), collision into one StaticBody3D
## per area, rails and zones under a parent node. Everything is in world space (the level sits at the origin).
##
## Collision rules (docs/lessons_learned.md): no collision edge under 0.3 m that a rider can hit, side walls of
## slopes run below the floor, no coplanar floors (every slope and wedge is sunk under the floor it meets), ramp lips
## sit exactly on the top edge of the transition.

const GRANITE := Color("cfc8bb")
const GRANITE_DARK := Color("a59d90")
const GRANITE_WARM := Color("cbc5ba")
const STEEL := Color("8e98a6")
const STEEL_DARK := Color("596273")
const BRASS := Color("c9a25a")
const SINK: float = 0.4  ## how far the hidden parts of slopes and wedges run below the floor they stand on


## A frame at `origin` whose +Z runs along `dir` (flattened), +Y up and +X across (to the right of a rider going +Z).
static func frame(origin: Vector3, dir: Vector3) -> Transform3D:
	var z: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, Vector3.UP, z), origin)


## A static body on the world layer that holds many shapes.
static func body(parent: Node, node_name: String) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = node_name
	sb.collision_layer = 1
	sb.collision_mask = 0
	parent.add_child(sb)
	return sb


static func col_box(sb: StaticBody3D, centre: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = Transform3D(basis, centre)
	sb.add_child(cs)
	return cs


static func col_box_min(sb: StaticBody3D, min_corner: Vector3, size: Vector3) -> CollisionShape3D:
	return col_box(sb, min_corner + size * 0.5, size)


static func col_convex(sb: StaticBody3D, points: PackedVector3Array) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	cs.shape = shape
	sb.add_child(cs)
	return cs


## A grind line (world points).
static func rail(parent: Node, pts: PackedVector3Array, kind: String = "ledge", node_name: String = "Rail") -> GrindRail:
	var r: GrindRail = PieceKit.rail(pts, kind, node_name)
	parent.add_child(r)
	return r


static func zone(parent: Node, zone_id: String, min_corner: Vector3, size: Vector3) -> Area3D:
	var z: Area3D = PieceKit.gap_zone(zone_id, min_corner, size)
	parent.add_child(z)
	return z


## A zone centred on `c` (a box `size`).
static func zone_c(parent: Node, zone_id: String, c: Vector3, size: Vector3) -> Area3D:
	return zone(parent, zone_id, c - size * 0.5, size)


static func lip(parent: Node, a: Vector3, b: Vector3, inward: Vector3, node_name: String = "Lip") -> RampLip:
	var l: RampLip = RampLip.line(PackedVector3Array([a, b]), inward)
	l.name = node_name
	parent.add_child(l)
	return l


## A granite ledge standing on floor height `fy`: centre line from `a` to `b` (x/z), `w` deep, `h` tall. A darker
## body, a pale cap that overhangs a little and steel angle on both top edges, which are grind lines.
static func ledge(bt: DtBatch, sb: StaticBody3D, rails: Node, a: Vector3, b: Vector3, w: float, h: float, fy: float,
		body_col: Color = GRANITE_DARK, cap_col: Color = GRANITE, node_name: String = "Ledge") -> void:
	var d: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	var l: float = d.length()
	var xf: Transform3D = frame(Vector3(a.x, fy, a.z), d)
	var cap: float = 0.08
	bt.box(xf * Vector3(0.0, (h - cap) * 0.5, l * 0.5), Vector3(w - 0.04, h - cap, l), body_col, xf.basis)
	bt.box(xf * Vector3(0.0, h - cap * 0.5, l * 0.5), Vector3(w + 0.04, cap, l + 0.04), cap_col, xf.basis)
	for s: float in [-1.0, 1.0]:
		bt.box(xf * Vector3(s * (w * 0.5 + 0.02), h - 0.035, l * 0.5), Vector3(0.035, 0.07, l + 0.02), STEEL, xf.basis)
	col_box(sb, xf * Vector3(0.0, (h - SINK) * 0.5, l * 0.5), Vector3(w, h + SINK, l), xf.basis)
	for s: float in [-1.0, 1.0]:
		rail(rails, PackedVector3Array([xf * Vector3(s * w * 0.5, h, 0.0), xf * Vector3(s * w * 0.5, h, l)]), "ledge", node_name + ("L" if s < 0.0 else "R"))


## A low manual pad (`h` at least 0.3): granite top with bevelled steel edges; grind lines on the two long edges.
static func manual_pad(bt: DtBatch, sb: StaticBody3D, rails: Node, a: Vector3, b: Vector3, w: float, h: float, fy: float,
		col: Color = GRANITE_WARM, node_name: String = "Pad") -> void:
	ledge(bt, sb, rails, a, b, w, h, fy, col.darkened(0.12), col, node_name)


## A sloped "hubba" ledge: a flat top (`flat` m at `fy_top + h_top`) then a straight slope down to `fy_bot + h_bot`
## over `run` m, from `top` (centre of its upper end) along `dir`. Convex collision, sunk under both floors.
static func hubba(bt: DtBatch, sb: StaticBody3D, rails: Node, top: Vector3, dir: Vector3, w: float, flat: float, run: float,
		fy_top: float, h_top: float, fy_bot: float, h_bot: float, col: Color = GRANITE, node_name: String = "Hubba") -> void:
	var xf: Transform3D = frame(Vector3(top.x, 0.0, top.z), dir)
	var y0: float = fy_top + h_top
	var y1: float = fy_bot + h_bot
	var base: float = minf(fy_top, fy_bot) - SINK
	var prof := PackedVector2Array([Vector2(0.0, base), Vector2(0.0, y0), Vector2(flat, y0), Vector2(flat + run, y1), Vector2(flat + run, base)])
	bt.prism(prof, -w * 0.5, w * 0.5, col.darkened(0.1), xf)
	# a pale cap strip on top and steel edges
	var cap := PackedVector2Array([Vector2(-0.02, y0 - 0.07), Vector2(-0.02, y0 + 0.01), Vector2(flat, y0 + 0.01), Vector2(flat + run + 0.02, y1 + 0.01), Vector2(flat + run + 0.02, y1 - 0.07), Vector2(flat, y0 - 0.07)])
	bt.prism(cap, -w * 0.5 - 0.02, w * 0.5 + 0.02, col, xf)
	var pts := PackedVector3Array()
	for x: float in [-w * 0.5, w * 0.5]:
		for zy: Vector2 in [Vector2(0.0, base), Vector2(0.0, y0), Vector2(flat, y0), Vector2(flat + run, y1), Vector2(flat + run, base)]:
			pts.append(xf * Vector3(x, zy.y, zy.x))
	col_convex(sb, pts)
	for s: float in [-1.0, 1.0]:
		var x: float = s * w * 0.5
		rail(rails, PackedVector3Array([xf * Vector3(x, y0, 0.0), xf * Vector3(x, y0, flat), xf * Vector3(x, y1, flat + run)]), "ledge", node_name + ("L" if s < 0.0 else "R"))


## A bank: its top edge (lip) runs across `w` at `top` (centre) at height `fy_top`, the slope falls along `dir` to the
## floor `fy_bot` over `run` m. The top edge is a coping grind line and a RampLip (Q+E snap). Optional deck behind.
static func bank(bt: DtBatch, sb: StaticBody3D, rails: Node, top: Vector3, dir: Vector3, w: float, run: float, fy_top: float,
		fy_bot: float, col: Color = GRANITE, deck: float = 0.0, node_name: String = "Bank") -> void:
	var xf: Transform3D = frame(Vector3(top.x, 0.0, top.z), dir)
	var base: float = fy_bot - SINK
	var prof := PackedVector2Array([Vector2(-deck, base), Vector2(-deck, fy_top), Vector2(0.0, fy_top), Vector2(run, fy_bot), Vector2(run, base)])
	bt.prism(prof, -w * 0.5, w * 0.5, col, xf)
	# a steel lip strip across the top edge
	bt.box(xf * Vector3(0.0, fy_top + 0.005, -0.06), Vector3(w, 0.03, 0.14), STEEL, xf.basis)
	var pts := PackedVector3Array()
	for x: float in [-w * 0.5, w * 0.5]:
		for zy: Vector2 in [Vector2(-deck, base), Vector2(-deck, fy_top), Vector2(0.0, fy_top), Vector2(run, fy_bot), Vector2(run, base)]:
			pts.append(xf * Vector3(x, zy.y, zy.x))
	col_convex(sb, pts)
	var a: Vector3 = xf * Vector3(-w * 0.5, fy_top, 0.0)
	var b: Vector3 = xf * Vector3(w * 0.5, fy_top, 0.0)
	rail(rails, PackedVector3Array([a, b]), "coping", node_name + "Lip")
	lip(rails, a, b, xf.basis.z, node_name + "Snap")


## A stair set: the top nosing runs across `w` at `top` (centre) at height `fy_top`, `steps` steps fall along `dir`
## to `fy_bot` (rise = (fy_top - fy_bot) / steps, tread `run`). Steps are visual; a hidden convex slope through every
## nosing carries the rider like a bank (StairSet's rule). Returns the bottom centre.
static func stairs(bt: DtBatch, sb: StaticBody3D, top: Vector3, dir: Vector3, w: float, steps: int, run: float, fy_top: float,
		fy_bot: float, col: Color = GRANITE, nose_col: Color = GRANITE_DARK) -> Vector3:
	var xf: Transform3D = frame(Vector3(top.x, 0.0, top.z), dir)
	var rise: float = (fy_top - fy_bot) / float(steps)
	var len_: float = float(steps) * run
	for i: int in steps:
		var tread: float = fy_top - float(i + 1) * rise
		if tread <= fy_bot + 0.001:
			continue
		var z0: float = float(i) * run
		var hgt: float = tread - (fy_bot - 0.05)
		bt.box(xf * Vector3(0.0, fy_bot - 0.05 + hgt * 0.5, z0 + run * 0.5), Vector3(w, hgt, run), col if i % 2 == 0 else col.darkened(0.04), xf.basis)
		bt.box(xf * Vector3(0.0, tread - 0.015, z0 + 0.05), Vector3(w + 0.002, 0.035, 0.1), nose_col, xf.basis)
	var pts := PackedVector3Array()
	for x: float in [-w * 0.5, w * 0.5]:
		pts.append(xf * Vector3(x, fy_top, 0.0))
		pts.append(xf * Vector3(x, fy_bot - SINK, 0.0))
		pts.append(xf * Vector3(x, fy_bot, len_))
		pts.append(xf * Vector3(x, fy_bot - SINK, len_))
	col_convex(sb, pts)
	return xf * Vector3(0.0, fy_bot, len_)


## A handrail down a stair line: posts and a round pipe from `a` (top, flat part starts at `a0`) to `b`; one grind
## line `a0 -> a -> b`. Posts stand on the floor heights given by `floor_at` (a Callable z -> y along the run).
static func handrail(bt: DtBatch, rails: Node, a0: Vector3, a: Vector3, b: Vector3, post_floor: Array, node_name: String = "Handrail") -> void:
	bt.tube(a0, a, 0.045, STEEL, 8)
	bt.tube(a, b, 0.045, STEEL, 8)
	for p: Variant in post_floor:
		var pf: Vector3 = p as Vector3
		var top_y: float = _rail_y_at(a0, a, b, pf)
		bt.tube(pf, Vector3(pf.x, top_y, pf.z), 0.04, STEEL_DARK, 6)
	rail(rails, PackedVector3Array([a0, a, b]), "rail", node_name)


## Height of a 3-point rail polyline above the floor point `p` (by the horizontal distance along it).
static func _rail_y_at(a0: Vector3, a: Vector3, b: Vector3, p: Vector3) -> float:
	var d0: float = Vector2(a.x - a0.x, a.z - a0.z).length()
	var d1: float = Vector2(b.x - a.x, b.z - a.z).length()
	var t: float = Vector2(p.x - a0.x, p.z - a0.z).length()
	if t <= d0 or d1 < 0.001:
		return a0.y
	return lerpf(a.y, b.y, clampf((t - d0) / d1, 0.0, 1.0))


## A launch wedge (kicker): `w` wide, rises from the floor to `h` over `run` along `dir`, its foot at `foot`.
static func kicker(bt: DtBatch, sb: StaticBody3D, rails: Node, foot: Vector3, dir: Vector3, w: float, run: float, h: float, fy: float,
		col: Color = Color("e0a640")) -> void:
	var xf: Transform3D = frame(Vector3(foot.x, 0.0, foot.z), dir)
	var base: float = fy - SINK
	var prof := PackedVector2Array([Vector2(0.0, base), Vector2(0.0, fy), Vector2(run, fy + h), Vector2(run, base)])
	bt.prism(prof, -w * 0.5, w * 0.5, col, xf)
	bt.box(xf * Vector3(0.0, fy + h - 0.01, run - 0.06), Vector3(w, 0.03, 0.14), STEEL, xf.basis)
	var pts := PackedVector3Array()
	for x: float in [-w * 0.5, w * 0.5]:
		for zy: Vector2 in prof:
			pts.append(xf * Vector3(x, zy.y, zy.x))
	col_convex(sb, pts)


## A round ledge (a fountain rim, a planter ring): `n` straight segments between radii r_in..r_out at `h` above
## floor `fy`. The outer top edge is one closed grind line.
static func ring_ledge(bt: DtBatch, sb: StaticBody3D, rails: Node, c: Vector3, r_in: float, r_out: float, h: float, fy: float, n: int,
		col: Color = GRANITE, top_col: Color = GRANITE_WARM, node_name: String = "Rim") -> void:
	var ring := PackedVector3Array()
	var rm: float = (r_in + r_out) * 0.5
	var t: float = r_out - r_in
	for i: int in n + 1:
		var a: float = TAU * float(i) / float(n)
		ring.append(Vector3(c.x + cos(a) * r_out, fy + h, c.z + sin(a) * r_out))
	for i: int in n:
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var am: float = (a0 + a1) * 0.5
		var chord: float = 2.0 * r_out * sin(PI / float(n)) + 0.02
		var basis := Basis(Vector3.UP, -am + PI * 0.5)
		var cm := Vector3(c.x + cos(am) * rm, fy, c.z + sin(am) * rm)
		bt.box(cm + Vector3(0.0, (h - 0.08) * 0.5, 0.0), Vector3(chord, h - 0.08, t), col, basis)
		bt.box(cm + Vector3(0.0, h - 0.04, 0.0), Vector3(chord + 0.03, 0.08, t + 0.06), top_col, basis)
		col_box(sb, cm + Vector3(0.0, (h - SINK) * 0.5, 0.0), Vector3(chord, h + SINK, t), basis)
	rail(rails, ring, "ledge", node_name)


## A planter box with a tree spot: granite walls `h` tall (top edges are a grind loop), soil inside. Returns the centre.
static func planter(bt: DtBatch, sb: StaticBody3D, rails: Node, c: Vector3, sx: float, sz: float, h: float, fy: float,
		col: Color = GRANITE, node_name: String = "Planter") -> Vector3:
	var t: float = 0.25
	bt.box(c + Vector3(0.0, fy + (h - 0.06) * 0.5, -sz * 0.5 + t * 0.5), Vector3(sx, h - 0.06, t), col.darkened(0.08))
	bt.box(c + Vector3(0.0, fy + (h - 0.06) * 0.5, sz * 0.5 - t * 0.5), Vector3(sx, h - 0.06, t), col.darkened(0.08))
	bt.box(c + Vector3(-sx * 0.5 + t * 0.5, fy + (h - 0.06) * 0.5, 0.0), Vector3(t, h - 0.06, sz - 2.0 * t), col.darkened(0.08))
	bt.box(c + Vector3(sx * 0.5 - t * 0.5, fy + (h - 0.06) * 0.5, 0.0), Vector3(t, h - 0.06, sz - 2.0 * t), col.darkened(0.08))
	# cap ring
	bt.box(c + Vector3(0.0, fy + h - 0.03, -sz * 0.5 + t * 0.5), Vector3(sx + 0.04, 0.06, t + 0.04), col)
	bt.box(c + Vector3(0.0, fy + h - 0.03, sz * 0.5 - t * 0.5), Vector3(sx + 0.04, 0.06, t + 0.04), col)
	bt.box(c + Vector3(-sx * 0.5 + t * 0.5, fy + h - 0.03, 0.0), Vector3(t + 0.04, 0.06, sz - 2.0 * t), col)
	bt.box(c + Vector3(sx * 0.5 - t * 0.5, fy + h - 0.03, 0.0), Vector3(t + 0.04, 0.06, sz - 2.0 * t), col)
	bt.box(c + Vector3(0.0, fy + h - 0.12, 0.0), Vector3(sx - 2.0 * t, 0.06, sz - 2.0 * t), Color("6a4a32"))
	col_box(sb, c + Vector3(0.0, fy + (h - SINK) * 0.5, 0.0), Vector3(sx, h + SINK, sz))
	var y: float = fy + h
	var hx: float = sx * 0.5
	var hz: float = sz * 0.5
	rail(rails, PackedVector3Array([c + Vector3(-hx, y, -hz), c + Vector3(hx, y, -hz), c + Vector3(hx, y, hz), c + Vector3(-hx, y, hz), c + Vector3(-hx, y, -hz)]), "ledge", node_name)
	return c + Vector3(0.0, y - 0.1, 0.0)


## A street bench: slatted wooden seat on cast legs; the front seat edge is a grind line. `face` points out of the
## seat (where you sit facing). Solid (one box).
static func bench(bt: DtBatch, sb: StaticBody3D, rails: Node, c: Vector3, face: Vector3, length: float, fy: float) -> void:
	var xf: Transform3D = frame(Vector3(c.x, fy, c.z), face)
	var wood := Color("b77a45")
	for i: int in 4:
		bt.box(xf * Vector3(0.0, 0.44, -0.24 + float(i) * 0.15), Vector3(length, 0.05, 0.12), wood, xf.basis)
	for s: float in [-1.0, 1.0]:
		bt.box(xf * Vector3(s * (length * 0.5 - 0.2), 0.21, 0.0), Vector3(0.08, 0.42, 0.56), STEEL_DARK, xf.basis)
		bt.box(xf * Vector3(s * (length * 0.5 - 0.2), 0.62, -0.33), Vector3(0.06, 0.4, 0.06), STEEL_DARK, xf.basis)
	bt.box(xf * Vector3(0.0, 0.72, -0.35), Vector3(length, 0.14, 0.05), wood, xf.basis)
	col_box(sb, xf * Vector3(0.0, 0.47 * 0.5 - 0.1, 0.0), Vector3(length, 0.47 + 0.2, 0.62), xf.basis)
	rail(rails, PackedVector3Array([xf * Vector3(-length * 0.5, 0.47, 0.31), xf * Vector3(length * 0.5, 0.47, 0.31)]), "ledge", "BenchEdge")


## LevelKit pieces as MultiMeshes: one MultiMeshInstance3D per mesh in the glb, every instance sharing the toon
## materials. `xforms` are world transforms of the piece origin. Collision boxes from the manifest go into `sb`
## (null = none). Returns the holder node.
static func kit_multi(parent: Node, kit: LevelKit, piece: String, xforms: Array[Transform3D], sb: StaticBody3D = null,
		shadow: bool = true, tint: Color = Color(0, 0, 0, 0), scale: float = 1.0) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Multi_" + piece
	parent.add_child(holder)
	if xforms.is_empty():
		return holder
	var vis: Node3D = kit.visual(piece, tint)
	for n: Node in vis.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var m: Mesh = mi.mesh.duplicate() as Mesh
		if m is ArrayMesh:
			for s: int in m.get_surface_count():
				var mat: Material = mi.get_surface_override_material(s)
				if mat != null:
					(m as ArrayMesh).surface_set_material(s, mat)
		var rel: Transform3D = _rel(vis, mi)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m
		mm.instance_count = xforms.size()
		for i: int in xforms.size():
			mm.set_instance_transform(i, xforms[i] * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3.ZERO) * rel)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = str(mi.name)
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mmi)
	vis.free()
	if sb != null:
		for xf: Transform3D in xforms:
			for bb: AABB in kit.collision_boxes(piece):
				var sxf: Transform3D = xf * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3.ZERO)
				col_box(sb, sxf * bb.get_center(), bb.size * scale, sxf.basis.orthonormalized())
	return holder


static func _rel(root: Node3D, n: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## A transform at `pos` turned `yaw` radians (kit pieces face -Z at yaw 0).
static func at(pos: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos)
