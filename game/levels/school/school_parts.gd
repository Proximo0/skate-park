class_name SchoolParts
extends RefCounted
## Skate pieces for the School level, built into a SchoolGeo batch (merged meshes, one collision body per area): stair
## flights with handrails and hubba ledges, banks with lips, ledges, rails, benches and planters. Each takes a
## Transform3D that places its local frame in the world. Local frame of a flight or bank: x across (0 .. width), y up
## from the piece's base, z along the slope; the top edge is at z = 0 and the slope falls toward +z.
## Grind lines are GrindRails (world points) under the geo's parent; gap zones are PieceKit.gap_zone Areas.

const METAL := Color("c9d3dd")
const DARK_METAL := Color("4d5266")
const RAIL_H: float = 0.9  ## handrail height above the nosing line
const RAIL_R: float = 0.035
const HUBBA_W: float = 0.6
const HUBBA_H: float = 0.55  ## hubba ledge top above the nosing line
const LIP_LEDGE: String = "ledge"


## A stair flight: `n` steps of `rise` x `run` across `w`, top edge at local z = 0 (height n * rise above the base),
## foot at z = n * run. Visual treads, a hidden smooth slope to ride (through every nosing, like StairSet), handrails at
## the local x offsets in `rails`, hubba ledges on the left (x < 0 side, hubba & 1) and/or right (hubba & 2) outside the
## stair width, and gap zones <zone>_top / <zone>_bottom. Returns {"top": world top-centre, "bottom": world foot-centre}.
static func stairs(geo: SchoolGeo, xf: Transform3D, w: float, n: int, rise: float, run: float, rails: Array, hubba: int,
		step_key: String, hubba_key: String, zone: String = "") -> Dictionary:
	var h: float = float(n) * rise
	var l: float = float(n) * run
	for i: int in n:
		var top: float = h - float(i + 1) * rise
		if top <= 0.001:
			continue
		geo.obox(xf * Transform3D(Basis.IDENTITY, Vector3(w * 0.5, top * 0.5, (float(i) + 0.5) * run)), Vector3(w, top, run), step_key, false)
	# nosing strips: a lighter edge on each step so the set reads from a distance
	for i: int in n:
		var top: float = h - float(i + 1) * rise
		if top <= 0.001:
			continue
		geo.obox(xf * Transform3D(Basis.IDENTITY, Vector3(w * 0.5, top - 0.015, float(i) * run + 0.05)), Vector3(w - 0.02, 0.04, 0.1), SchoolGeo.toon(Color("d8d2c4")), false)
	# the ride: a convex wedge under the nosing line (top edge at z = 0, ground at z = l)
	geo.prism(xf, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, h), Vector2(l, 0.0)]), 0.0, w, step_key, true, false)
	var slope: float = rise / run
	for rx: Variant in rails:
		var x: float = float(rx)
		var p0: Vector3 = xf * Vector3(x, h + RAIL_H, -0.9)
		var p1: Vector3 = xf * Vector3(x, h + RAIL_H, 0.0)
		var p2: Vector3 = xf * Vector3(x, RAIL_H - 0.35 * slope, l + 0.35)
		handrail(geo, PackedVector3Array([p0, p1, p2]), [h, h, 0.0], xf, x)
	if hubba & 1:
		_hubba(geo, xf, -HUBBA_W, 0.0, h, l, hubba_key)
	if hubba & 2:
		_hubba(geo, xf, w, w + HUBBA_W, h, l, hubba_key)
	if zone != "":
		var z_top: Transform3D = xf * Transform3D(Basis.IDENTITY, Vector3(w * 0.5, h + 1.0, -0.4))
		geo.parent.add_child(_zone(zone + "_top", z_top, Vector3(w + 1.2, 1.8, 1.6)))
		# from a metre up the set to 5 m past its foot, 2.6 m tall: a skater clearing the set is still in the air here
		var z_bot: Transform3D = xf * Transform3D(Basis.IDENTITY, Vector3(w * 0.5, 1.3, l + 2.0))
		geo.parent.add_child(_zone(zone + "_bottom", z_bot, Vector3(w + 1.2, 2.6, 6.0)))
	return {"top": xf * Vector3(w * 0.5, h, 0.0), "bottom": xf * Vector3(w * 0.5, 0.0, l)}


## A gap zone as an oriented box: PieceKit.gap_zone at the origin, then turned and moved by `xf` (centre and rotation).
static func _zone(zone_id: String, xf: Transform3D, size: Vector3) -> Area3D:
	var a: Area3D = PieceKit.gap_zone(zone_id, -size * 0.5, size)
	a.transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
	return a


## An axis-aligned gap zone by min corner and size (world).
static func zone_box(parent: Node, zone_id: String, min_corner: Vector3, size: Vector3) -> void:
	parent.add_child(PieceKit.gap_zone(zone_id, min_corner, size))


## A sloped hubba ledge beside a flight (x0 .. x1 in the flight's frame): top follows the nosing line HUBBA_H above it.
static func _hubba(geo: SchoolGeo, xf: Transform3D, x0: float, x1: float, h: float, l: float, key: String) -> void:
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(l, 0.0), Vector2(l, HUBBA_H), Vector2(0.0, h + HUBBA_H)])
	geo.prism(xf, prof, x0, x1, key)
	# a metal angle on each top edge, and the grind lines
	for x: float in [x0, x1]:
		var a: Vector3 = xf * Vector3(x, h + HUBBA_H, 0.0)
		var b: Vector3 = xf * Vector3(x, HUBBA_H, l)
		geo.cyl(a, b, 0.025, SchoolGeo.toon(METAL), 4)
		grind(geo.parent, PackedVector3Array([a, b]), "ledge")


## A round handrail along `pts` (world) with posts down to the floor heights `floors` (one per point; the post base is
## found by interpolating along the rail in the piece frame), plus its GrindRail.
static func handrail(geo: SchoolGeo, pts: PackedVector3Array, floors: Array, xf: Transform3D, _x: float) -> void:
	var key: String = SchoolGeo.toon(METAL)
	for i: int in pts.size() - 1:
		geo.cyl(pts[i], pts[i + 1], RAIL_R, key, 8)
	# posts: at each end and about every 1.8 m along the rail
	var inv: Transform3D = xf.affine_inverse()
	for i: int in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var segs: int = maxi(1, int(ceil(a.distance_to(b) / 1.8)))
		for k: int in segs + (1 if i == pts.size() - 2 else 0):
			var t: float = float(k) / float(segs)
			var p: Vector3 = a.lerp(b, t)
			var lp: Vector3 = inv * p
			var fy: float = lerpf(float(floors[i]), float(floors[i + 1]), t)
			var base: Vector3 = xf * Vector3(lp.x, fy, lp.z)
			if p.y - base.y > 0.2:
				geo.cyl(base, p, 0.03, key, 6)
	grind(geo.parent, pts, "rail")


## A free-standing round rail (flat bar) from a to b at their heights, on posts to the ground at `ground_y`.
static func flatbar(geo: SchoolGeo, a: Vector3, b: Vector3, ground_y: float = 0.0, key: String = "") -> void:
	var k: String = key if key != "" else SchoolGeo.toon(METAL)
	geo.cyl(a, b, 0.04, k, 8)
	var n: int = maxi(2, int(ceil(a.distance_to(b) / 2.5)) + 1)
	for i: int in n:
		var p: Vector3 = a.lerp(b, (0.08 + 0.84 * float(i) / float(n - 1)))
		geo.cyl(Vector3(p.x, ground_y, p.z), p, 0.035, k, 6)
		geo.box(Vector3(p.x - 0.12, ground_y, p.z - 0.12), Vector3(0.24, 0.04, 0.24), k, false)
	grind(geo.parent, PackedVector3Array([a, b]), "rail")


## A grind line (world points) under `parent`.
static func grind(parent: Node, pts: PackedVector3Array, kind: String = "ledge") -> GrindRail:
	var r: GrindRail = PieceKit.rail(pts, kind, "Grind%s" % kind.capitalize())
	parent.add_child(r)
	return r


## A bank in the frame `xf`: across x0 .. x1, lip at local z = 0 and height h, foot at z = len (height 0), vertical back
## at z = 0. The lip gets a "ledge" grind line, a metal coping strip and a RampLip (inward +z, down the bank).
static func bank(geo: SchoolGeo, xf: Transform3D, x0: float, x1: float, len: float, h: float, key: String, lip: bool = true) -> void:
	geo.prism(xf, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, h), Vector2(len, 0.0)]), x0, x1, key)
	if lip:
		var a: Vector3 = xf * Vector3(x0, h, 0.0)
		var b: Vector3 = xf * Vector3(x1, h, 0.0)
		geo.cyl(a + (xf.basis * Vector3(0, -0.03, 0.03)), b + (xf.basis * Vector3(0, -0.03, 0.03)), 0.045, SchoolGeo.toon(DARK_METAL), 6)
		grind(geo.parent, PackedVector3Array([a, b]), "coping")
		var inward: Vector3 = xf.basis * Vector3(0.0, 0.0, 1.0)
		var rl: RampLip = RampLip.line(PackedVector3Array([a, b]), Vector3(inward.x, 0.0, inward.z).normalized())
		geo.parent.add_child(rl)


## A concrete ledge (seat wall) from a to b (world, at the ledge's base height), `w` wide and `h` tall, with a cap and
## grind lines on both top edges.
static func ledge(geo: SchoolGeo, a: Vector3, b: Vector3, w: float, h: float, body_key: String, cap_key: String, edges: bool = true) -> void:
	var d: Vector3 = b - a
	d.y = 0.0
	var len: float = d.length()
	var x: Vector3 = d / len
	var z: Vector3 = Vector3(-x.z, 0.0, x.x)
	var basis := Basis(x, Vector3.UP, z)
	var mid: Vector3 = (a + b) * 0.5
	geo.obox(Transform3D(basis, mid + Vector3(0.0, (h - 0.06) * 0.5, 0.0)), Vector3(len, h - 0.06, w), body_key)
	geo.obox(Transform3D(basis, mid + Vector3(0.0, h - 0.03, 0.0)), Vector3(len + 0.04, 0.06, w + 0.06), cap_key)
	if edges:
		for s: float in [-1.0, 1.0]:
			var off: Vector3 = z * (w * 0.5 + 0.03) * s + Vector3(0.0, h, 0.0)
			grind(geo.parent, PackedVector3Array([a + off, b + off]), "ledge")


## A park bench of slats on concrete feet, seat along a -> b (world, ground level), the seat front edge grindable.
static func bench(geo: SchoolGeo, a: Vector3, b: Vector3, wood: String, metal: String) -> void:
	var d: Vector3 = b - a
	d.y = 0.0
	var len: float = d.length()
	var x: Vector3 = d / len
	var z: Vector3 = Vector3(-x.z, 0.0, x.x)
	var basis := Basis(x, Vector3.UP, z)
	var mid: Vector3 = (a + b) * 0.5
	# feet and seat are looks only; one solid block from the ground to the seat top collides, so nothing can catch
	# the board or the skater under the seat
	for t: float in [0.12, 0.88]:
		var p: Vector3 = a.lerp(b, t)
		geo.obox(Transform3D(basis, p + Vector3(0.0, 0.2, 0.0)), Vector3(0.12, 0.4, 0.5), metal, false)
	geo.obox(Transform3D(basis, mid + Vector3(0.0, 0.43, 0.0)), Vector3(len, 0.06, 0.55), wood, false)
	geo.osolid(Transform3D(basis, mid + Vector3(0.0, 0.23, 0.0)), Vector3(len, 0.46, 0.55))
	for s: float in [-1.0, 1.0]:
		geo.obox(Transform3D(basis, mid + Vector3(0.0, 0.47, 0.0) + z * 0.14 * s), Vector3(len, 0.02, 0.2), wood, false)
	grind(geo.parent, PackedVector3Array([a + z * 0.29 + Vector3(0, 0.46, 0), b + z * 0.29 + Vector3(0, 0.46, 0)]), "ledge")
	grind(geo.parent, PackedVector3Array([a - z * 0.29 + Vector3(0, 0.46, 0), b - z * 0.29 + Vector3(0, 0.46, 0)]), "ledge")


## A square raised planter (walls `h` tall, `t` thick) around rect (world x/z) at base y, soil inside, a closed ledge
## grind line round the outer top edge.
static func planter_box(geo: SchoolGeo, r: Rect2, y: float, h: float, wall_key: String, soil_key: String) -> void:
	var t: float = 0.3
	geo.box(Vector3(r.position.x, y, r.position.y), Vector3(r.size.x, h, t), wall_key)
	geo.box(Vector3(r.position.x, y, r.end.y - t), Vector3(r.size.x, h, t), wall_key)
	geo.box(Vector3(r.position.x, y, r.position.y + t), Vector3(t, h, r.size.y - 2.0 * t), wall_key)
	geo.box(Vector3(r.end.x - t, y, r.position.y + t), Vector3(t, h, r.size.y - 2.0 * t), wall_key)
	# soil: solid, a little under the wall top
	geo.box(Vector3(r.position.x + t, y, r.position.y + t), Vector3(r.size.x - 2.0 * t, h - 0.12, r.size.y - 2.0 * t), soil_key)
	var top: float = y + h
	var pts := PackedVector3Array([
		Vector3(r.position.x, top, r.position.y), Vector3(r.end.x, top, r.position.y), Vector3(r.end.x, top, r.end.y),
		Vector3(r.position.x, top, r.end.y), Vector3(r.position.x, top, r.position.y)])
	grind(geo.parent, pts, "ledge")


## A circular raised planter or rim: a ring wall from r_in to r_out, `h` tall at base y, with a closed ledge grind line
## round the outer top edge (and the inner one if `inner`).
static func ring_wall(geo: SchoolGeo, c: Vector3, r_in: float, r_out: float, h: float, key: String, segs: int = 24, inner: bool = false) -> void:
	geo.lathe(c, PackedVector2Array([Vector2(r_out, -0.2), Vector2(r_out, h), Vector2(r_in, h), Vector2(r_in, -0.2)]), segs, key, true)
	var pts := PackedVector3Array()
	for i: int in segs + 1:
		var a: float = TAU * float(i) / float(segs)
		pts.append(c + Vector3(cos(a) * r_out, h, sin(a) * r_out))
	grind(geo.parent, pts, "ledge")
	if inner:
		var pin := PackedVector3Array()
		for i: int in segs + 1:
			var a: float = TAU * float(i) / float(segs)
			pin.append(c + Vector3(cos(a) * r_in, h, sin(a) * r_in))
		grind(geo.parent, pin, "coping")
