class_name SkaterParts
extends RefCounted
## Mesh and node primitives shared by PlaceholderSkater, AnimeHead, AnimeOutfit and AnimeBoard. Every part gets meta
## "palette" (its palette key) and a StandardMaterial3D in material_override so the toon pass can swap materials.


static func materials(palette: Dictionary, defaults: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in defaults.keys():
		var given: Color = palette.get(key, defaults[key])
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = given
		mat.roughness = 0.7
		out[key] = mat
	return out


static func joint(parent: Node3D, joint_name: String, pivot: Vector3) -> Node3D:
	var joint: Node3D = Node3D.new()
	joint.name = joint_name
	joint.position = pivot
	parent.add_child(joint)
	return joint


static func part(parent: Node3D, part_name: String, mesh: Mesh, offset: Vector3, mats: Dictionary, key: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.position = offset
	mi.material_override = mats[key]
	mi.set_meta("palette", key)
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	return m


static func sphere(radius: float) -> SphereMesh:
	var m: SphereMesh = SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 20
	m.rings = 10
	return m


## Upper half of a sphere of this radius (dome), centred on its origin. Godot's hemisphere spans y 0..height,
## so height = radius gives a dome whose top is at the radius.
static func dome(radius: float) -> SphereMesh:
	var m: SphereMesh = sphere(radius)
	m.is_hemisphere = true
	m.height = radius
	return m


static func torus(inner_radius: float, outer_radius: float) -> TorusMesh:
	var m: TorusMesh = TorusMesh.new()
	m.inner_radius = inner_radius
	m.outer_radius = outer_radius
	m.rings = 24
	m.ring_segments = 8
	return m


## Low-poly capsule for tiny parts (laces, fingers).
static func capsule_small(radius: float, height: float) -> CapsuleMesh:
	var m: CapsuleMesh = capsule(radius, height)
	m.radial_segments = 8
	m.rings = 2
	return m


## Low-poly sphere for tiny parts.
static func sphere_small(radius: float) -> SphereMesh:
	var m: SphereMesh = sphere(radius)
	m.radial_segments = 10
	m.rings = 5
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m: CapsuleMesh = CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 16
	m.rings = 4
	return m


static func cylinder(radius: float, height: float) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 16
	return m


## Tapered tube through the points, radius per point. Built in place (no mesh transform) so its bounds are tight.
static func tube(points: PackedVector3Array, radii: PackedFloat32Array, sides: int = 12) -> ArrayMesh:
	var n: int = points.size()
	var rings: Array = []
	var normals: Array = []
	for i: int in n:
		var tangent: Vector3 = (points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side: Vector3 = tangent.cross(Vector3.RIGHT)
		if side.length() < 0.001:
			side = tangent.cross(Vector3.UP)
		side = side.normalized()
		var up: Vector3 = side.cross(tangent).normalized()
		var ring: PackedVector3Array = PackedVector3Array()
		var ring_normals: Array = []
		for k: int in sides:
			var a: float = TAU * float(k) / float(sides)
			var dir: Vector3 = side * cos(a) + up * sin(a)
			ring.append(points[i] + dir * radii[i])
			ring_normals.append(dir)
		rings.append(ring)
		normals.append(ring_normals)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in n - 1:
		for k: int in sides:
			var k2: int = (k + 1) % sides
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k2]
			var c: Vector3 = rings[i + 1][k]
			var d: Vector3 = rings[i + 1][k2]
			var na: Vector3 = normals[i][k]
			var nb: Vector3 = normals[i][k2]
			var nc: Vector3 = normals[i + 1][k]
			var nd: Vector3 = normals[i + 1][k2]
			st.set_normal(na)
			st.add_vertex(a)
			st.set_normal(nb)
			st.add_vertex(b)
			st.set_normal(nc)
			st.add_vertex(c)
			st.set_normal(nb)
			st.add_vertex(b)
			st.set_normal(nd)
			st.add_vertex(d)
			st.set_normal(nc)
			st.add_vertex(c)
	return st.commit()


## Tube with rounded (hemispherical) ends: the first and last point are the centres of the end caps.
static func tube_capped(points: PackedVector3Array, radii: PackedFloat32Array, sides: int = 12) -> ArrayMesh:
	var n: int = points.size()
	var t0: Vector3 = (points[1] - points[0]).normalized()
	var t1: Vector3 = (points[n - 1] - points[n - 2]).normalized()
	var pts: PackedVector3Array = PackedVector3Array()
	var rs: PackedFloat32Array = PackedFloat32Array()
	var caps: Array = [[1.0, 0.0], [0.866, 0.5], [0.5, 0.866]]
	for c: Array in caps:
		pts.append(points[0] - t0 * radii[0] * float(c[0]))
		rs.append(radii[0] * float(c[1]) + 0.0001)
	for i: int in n:
		pts.append(points[i])
		rs.append(radii[i])
	for c: Array in caps:
		var k: Array = caps[2 - caps.find(c)]
		pts.append(points[n - 1] + t1 * radii[n - 1] * float(k[0]))
		rs.append(radii[n - 1] * float(k[1]) + 0.0001)
	return tube(pts, rs, sides)


## Catmull-Rom resample of a 2D profile: `sub` points per segment.
static func smooth2d(pts: PackedVector2Array, sub: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = pts.size()
	for i: int in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		for k: int in sub:
			var t: float = float(k) / float(sub)
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(pts[n - 1])
	return out


## Radius of a lathe profile (x = radius, y = height, y increasing) at height y.
static func profile_r(profile: PackedVector2Array, y: float) -> float:
	if y <= profile[0].y:
		return profile[0].x
	for i: int in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		if y <= b.y:
			return lerpf(a.x, b.x, (y - a.y) / maxf(b.y - a.y, 0.00001))
	return profile[profile.size() - 1].x


## Sub-profile between two heights, pushed outward by `offset`.
static func profile_band(profile: PackedVector2Array, y0: float, y1: float, offset: float, steps: int = 10) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in steps + 1:
		var y: float = lerpf(y0, y1, float(i) / float(steps))
		out.append(Vector2(profile_r(profile, y) + offset, y))
	return out


## Smooth triangle surface from rows of points (each row a ring or a strip). Shared vertices get smooth normals.
## Winding: rows going "up" with columns running clockwise seen from above face outward.
static func grid(rows: Array, closed: bool, flip: bool = false) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in rows.size() - 1:
		var r0: PackedVector3Array = rows[i]
		var r1: PackedVector3Array = rows[i + 1]
		var cols: int = r0.size() if closed else r0.size() - 1
		for k: int in cols:
			var k2: int = (k + 1) % r0.size()
			var a: Vector3 = r0[k]
			var b: Vector3 = r0[k2]
			var c: Vector3 = r1[k]
			var d: Vector3 = r1[k2]
			if flip:
				st.add_vertex(a)
				st.add_vertex(c)
				st.add_vertex(b)
				st.add_vertex(b)
				st.add_vertex(c)
				st.add_vertex(d)
			else:
				st.add_vertex(a)
				st.add_vertex(b)
				st.add_vertex(c)
				st.add_vertex(b)
				st.add_vertex(d)
				st.add_vertex(c)
	st.index()
	st.generate_normals()
	return st.commit()


## Surface of revolution. profile: (radius, y) points bottom to top. x = r sin(a), z = -r depth cos(a), so a = 0
## faces -Z. A full turn (a0 = 0, a1 = TAU) is closed; any other arc is open.
static func lathe(profile: PackedVector2Array, depth: float = 1.0, a0: float = 0.0, a1: float = TAU, segs: int = 32) -> ArrayMesh:
	var full: bool = absf((a1 - a0) - TAU) < 0.0001
	var cols: int = segs if full else segs + 1
	var rows: Array = []
	for p: Vector2 in profile:
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols:
			var a: float = a0 + (a1 - a0) * float(k) / float(segs)
			ring.append(Vector3(p.x * sin(a), p.y, -p.x * depth * cos(a)))
		rows.append(ring)
	return grid(rows, full)


## Flat-bottomed slab with softly bevelled edges over an outline of (x, z) points. y0 = bottom, y1 = top.
static func slab(outline: PackedVector2Array, y0: float, y1: float, bevel: float = 0.006) -> ArrayMesh:
	var c: Vector2 = Vector2.ZERO
	for p: Vector2 in outline:
		c += p
	c /= float(outline.size())
	var spec: Array = [[0.0, y0], [0.9, y0], [1.0, y0 + bevel], [1.0, y1 - bevel], [0.93, y1], [0.0, y1]]
	var rows: Array = []
	for sp: Array in spec:
		var ring: PackedVector3Array = PackedVector3Array()
		for p: Vector2 in outline:
			var q: Vector2 = c + (p - c) * float(sp[0])
			ring.append(Vector3(q.x, float(sp[1]), q.y))
		rows.append(ring)
	return grid(rows, true)


## Combines meshes, each with its own transform, into one ArrayMesh (one draw call).
static func merge(items: Array) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	for it: Array in items:
		st.append_from(it[0] as Mesh, 0, it[1] as Transform3D)
	return st.commit()


## Grid whose faces look toward `outward` (judged on the first triangle).
static func facing_grid(rows: Array, outward: Vector3) -> ArrayMesh:
	var m: ArrayMesh = grid(rows, false)
	var verts: PackedVector3Array = (m.surface_get_arrays(0) as Array)[Mesh.ARRAY_VERTEX]
	var tri_n: Vector3 = (verts[1] - verts[0]).cross(verts[2] - verts[0])
	if tri_n.dot(outward) > 0.0:
		return grid(rows, false, true)
	return m


## Flat ribbon along a path (width along `across`), for stripes lying on a surface. Faces toward `outward`.
static func ribbon(points: PackedVector3Array, across: Vector3, half_width: float, outward: Vector3) -> ArrayMesh:
	var left: PackedVector3Array = PackedVector3Array()
	var right: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in points:
		left.append(p - across * half_width)
		right.append(p + across * half_width)
	return facing_grid([left, right], outward)


## Catmull-Rom resample of 3D points (sub points per segment).
static func smooth3d(pts: PackedVector3Array, sub: int) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var n: int = pts.size()
	for i: int in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		for k: int in sub:
			var t: float = float(k) / float(sub)
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(pts[n - 1])
	return out


# --- elliptical lofts (body and limbs) ------------------------------------------------------------------------
# A loft section is [y, half width, front depth, back depth, power, z centre, x centre]; the last three are optional
# (power 1 = ellipse, below 1 squarer; z centre and x centre default to 0). Front is -Z. Sections run along +Y or -Y.

## Catmull-Rom resample of loft sections (all fields), `sub` sections per span. Missing optional fields get defaults.
static func smooth_sections(sections: Array, sub: int) -> Array:
	var full: Array = []
	for s: Array in sections:
		full.append([float(s[0]), float(s[1]), float(s[2]), float(s[3]),
				float(s[4]) if s.size() > 4 else 1.0, float(s[5]) if s.size() > 5 else 0.0,
				float(s[6]) if s.size() > 6 else 0.0])
	var out: Array = []
	var n: int = full.size()
	for i: int in n - 1:
		var p0: Array = full[maxi(i - 1, 0)]
		var p1: Array = full[i]
		var p2: Array = full[i + 1]
		var p3: Array = full[mini(i + 2, n - 1)]
		for k: int in sub:
			var t: float = float(k) / float(sub)
			var row: Array = []
			for f: int in 7:
				var a: float = p0[f]
				var b: float = p1[f]
				var c: float = p2[f]
				var d: float = p3[f]
				row.append(0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t
						+ (-a + 3.0 * b - 3.0 * c + d) * t * t * t))
			out.append(row)
	out.append(full[n - 1])
	return out


## The section at height y (linear between smoothed sections; y may run up or down the list).
static func section_at(sections: Array, y: float) -> Array:
	var n: int = sections.size()
	for i: int in n - 1:
		var a: Array = sections[i]
		var b: Array = sections[i + 1]
		var y0: float = a[0]
		var y1: float = b[0]
		if (y - y0) * (y - y1) <= 0.0:
			var t: float = clampf((y - y0) / (y1 - y0), 0.0, 1.0) if absf(y1 - y0) > 0.000001 else 0.0
			var row: Array = []
			for f: int in 7:
				row.append(lerpf(float(a[f]), float(b[f]), t))
			return row
	var nearest: Array = sections[0] if absf(y - float(sections[0][0])) < absf(y - float(sections[n - 1][0])) else sections[n - 1]
	return nearest.duplicate()


## Point on a section's outline at angle a (0 = front, -Z; +PI/2 = +X), pushed out by grow.
static func section_point(sec: Array, a: float, grow: float = 0.0) -> Vector3:
	var p: float = sec[4]
	var sn: float = sin(a)
	var c: float = cos(a)
	var x: float = (float(sec[1]) + grow) * signf(sn) * pow(absf(sn), p)
	var d: float = float(sec[2]) if c > 0.0 else float(sec[3])
	var z: float = -(d + grow) * signf(c) * pow(absf(c), p)
	return Vector3(float(sec[6]) + x, float(sec[0]), float(sec[5]) + z)


## Angle on a section whose outline point has the given x (front half if front, else back half).
static func section_angle_for_x(sec: Array, x: float, front: bool, grow: float = 0.0) -> float:
	var hw: float = float(sec[1]) + grow
	var u: float = clampf((x - float(sec[6])) / maxf(hw, 0.0001), -0.999, 0.999)
	var a: float = signf(u) * asin(pow(absf(u), 1.0 / float(sec[4])))
	return a if front else PI - a


## Smooth closed loft through smoothed sections (from smooth_sections), `sides` points round each ring. Sections must
## be listed bottom to top (increasing y) for outward faces; pass descending=true for limbs listed top to bottom.
static func loft(sections: Array, sides: int = 16, grow: float = 0.0, descending: bool = false) -> ArrayMesh:
	var rows: Array = []
	for sec: Array in sections:
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in sides:
			ring.append(section_point(sec, TAU * float(k) / float(sides), grow))
		rows.append(ring)
	if descending:
		rows.reverse()
	return grid(rows, true)


## Closed tube following one section outline at height y (a trim line or a stripe round a loft).
static func loft_ring(sections: Array, y: float, grow: float, tube_r: float, n: int = 28) -> ArrayMesh:
	var sec: Array = section_at(sections, y)
	var pts: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	for i: int in n + 1:
		pts.append(section_point(sec, TAU * float(i) / float(n), grow))
		radii.append(tube_r)
	return tube(pts, radii, 6)
