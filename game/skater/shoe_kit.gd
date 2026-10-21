class_name ShoeKit
extends RefCounted
## Mesh-building helpers shared by SkateShoe and ShoeStyles. Every triangle is wound to face away from a reference
## point inside its part, so a part never needs its winding checked by eye.


## Shoe materials: colourway keys win, then materials already in `mats` (e.g. from the body palette), then the Lagoon
## defaults (added to `mats` so both shoes share them). Only the "shoe_*" keys of SkateShoe.PRESETS are used.
static func materials(mats: Dictionary, colourway: Dictionary) -> Dictionary:
	var defaults: Dictionary = SkateShoe.PRESETS[SkateShoe.LAGOON]
	var out: Dictionary = mats.duplicate()
	var missing: Dictionary = {}
	for key: String in defaults.keys():
		if not mats.has(key):
			missing[key] = defaults[key]
	var made: Dictionary = SkaterParts.materials({}, missing)
	for key: String in made.keys():
		mats[key] = made[key]
		out[key] = made[key]
	var given: Dictionary = {}
	for key: String in colourway.keys():
		if defaults.has(key):
			given[key] = colourway[key]
	var custom: Dictionary = SkaterParts.materials({}, given)
	for key: String in custom.keys():
		out[key] = custom[key]
	return out


static func begin() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func done(st: SurfaceTool) -> ArrayMesh:
	st.index()
	st.generate_normals()
	return st.commit()


static func grid_into(st: SurfaceTool, rows: Array, closed: bool, refs: PackedVector3Array) -> void:
	for i: int in rows.size() - 1:
		var r0: PackedVector3Array = rows[i]
		var r1: PackedVector3Array = rows[i + 1]
		var ref: Vector3 = (refs[i] + refs[i + 1]) * 0.5
		var cols: int = r0.size() if closed else r0.size() - 1
		for k: int in cols:
			var k2: int = (k + 1) % r0.size()
			quad_into(st, r0[k], r0[k2], r1[k], r1[k2], ref)


static func quad_into(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ref: Vector3) -> void:
	tri_into(st, a, b, c, ref)
	tri_into(st, b, d, c, ref)


## Adds triangle abc wound so its front (Godot: clockwise) faces away from ref. Skips degenerate triangles.
static func tri_into(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ref: Vector3) -> void:
	var n: Vector3 = (c - a).cross(b - a)
	if n.length_squared() < 1e-14:
		return
	st.add_vertex(a)
	if n.dot((a + b + c) / 3.0 - ref) >= 0.0:
		st.add_vertex(b)
		st.add_vertex(c)
	else:
		st.add_vertex(c)
		st.add_vertex(b)


## Point at arc length s along a closed ring (wraps).
static func along(ring: PackedVector3Array, lengths: PackedFloat32Array, s: float) -> Vector3:
	var total: float = lengths[lengths.size() - 1]
	var ss: float = fposmod(s, total)
	for i: int in ring.size():
		if ss <= lengths[i + 1]:
			var t: float = (ss - lengths[i]) / maxf(lengths[i + 1] - lengths[i], 0.000001)
			return ring[i].lerp(ring[(i + 1) % ring.size()], t)
	return ring[0]


## Cumulative arc lengths of a closed ring (size + 1 entries, starting at 0).
static func ring_lengths(ring: PackedVector3Array) -> PackedFloat32Array:
	var lengths: PackedFloat32Array = PackedFloat32Array([0.0])
	for i: int in ring.size():
		lengths.append(lengths[i] + ring[i].distance_to(ring[(i + 1) % ring.size()]))
	return lengths


## Merges [mesh, Transform3D] items into one smooth-shaded mesh. SkaterParts.merge drops meshes that lack the first one's
## attributes (the tube meshes of a bow after an indexed one), so this goes through the faces instead.
static func merge(items: Array) -> ArrayMesh:
	var st: SurfaceTool = begin()
	for it: Array in items:
		var xf: Transform3D = it[1]
		var faces: PackedVector3Array = (it[0] as Mesh).get_faces()
		for v: Vector3 in faces:
			st.add_vertex(xf * v)
	return done(st)
