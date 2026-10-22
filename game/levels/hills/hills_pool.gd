class_name HillsPool
extends RefCounted
## A drained backyard kidney pool sunk in its own rectangular concrete deck. Origin at the deck's centre, deck top at
## y = 0; the deck spans x in [-size.x / 2, size.x / 2], z in [-size.y / 2, size.y / 2] (so a level cuts that grid-
## aligned rectangle out of its ground and the deck meets the ground's edge exactly).
##
## The bowl is a star-shaped kidney (an ellipse with a dent on one long side and a bigger lobe at +x). Walls are built
## along rays from the centre: on the long sides a quarter circle (vertical at the coping: carve and air them), at the
## two ends a gentle S-curve bank (roll in at one end, out at the other: the pool is a flow-through on a hopping line).
## The floor is deepest in the middle. Plaster shell with a blue tile band under the coping, a pale coping band on the
## deck, a coping pipe, a closed "coping" GrindRail on the rim and a RampLip ring for the ramp snap.

const PLASTER := Color("e4eef3")
const TILE := Color("5fb2dc")
const TILE_DARK := Color("2f7fb0")
const COPING := Color("efe9dc")
const DECK := Color("cfcabf")
const PIPE := Color("d8d2c4")
const SEGMENTS: int = 72  ## rays round the rim (a multiple of 4)
const WALL_T: Array[float] = [0.0, 0.015, 0.05, 0.1, 0.17, 0.26, 0.37, 0.5, 0.65, 0.82, 1.0]
const FLOOR_RINGS: Array[float] = [0.7, 0.42, 0.18]
const COPING_W: float = 0.4
const TILE_DEPTH: float = 0.32


## a, b: the kidney's half length (x) and half width (z). deep: the depth in the middle; shallow: at the two ends.
## side_r: the long sides' transition radius; end_r: the end banks' run.
static func build(size: Vector2, a: float = 5.2, b: float = 3.0, deep: float = 2.1, shallow: float = 1.1, side_r: float = 1.9, end_r: float = 3.6, dent: float = 0.22, zone_prefix: String = "pool") -> Node3D:
	var root := Node3D.new()
	root.name = "Pool"
	var rim := PackedVector2Array()
	for k: int in SEGMENTS:
		var th: float = -PI * 0.5 + TAU * float(k) / float(SEGMENTS)
		rim.append(HillsPool._rim(th, a, b, dent))
	# --- shell ---------------------------------------------------------------------------------------------------
	var plaster := SurfaceTool.new()
	plaster.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tile := SurfaceTool.new()
	tile.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for m: int in WALL_T.size() + FLOOR_RINGS.size():
		rings.append(PackedVector3Array())
	for k: int in SEGMENTS:
		var p: Vector2 = rim[k]
		var l: float = p.length()
		var dir: Vector2 = p / l
		var we: float = pow(absf(dir.x), 3.0)  # 1 at the ends, 0 on the long sides
		var r: float = minf(lerpf(side_r, end_r, we), l * 0.8)
		var fs: Vector2 = p - dir * r  # where the floor starts on this ray
		var d_f: float = HillsPool.depth_at(fs.x, a, deep, shallow)
		for m: int in WALL_T.size():
			var t: float = WALL_T[m]
			var q: Vector2 = p - dir * r * t
			var y_side: float = -d_f * sqrt(maxf(1.0 - (1.0 - t) * (1.0 - t), 0.0))
			var y_end: float = -d_f * t * t * (3.0 - 2.0 * t)
			rings[m].append(Vector3(q.x, lerpf(y_side, y_end, we), q.y))
		for f: int in FLOOR_RINGS.size():
			var q: Vector2 = fs * FLOOR_RINGS[f]
			rings[WALL_T.size() + f].append(Vector3(q.x, -HillsPool.depth_at(q.x, a, deep, shallow), q.y))
	for m: int in rings.size() - 1:
		for k: int in SEGMENTS:
			var k1: int = (k + 1) % SEGMENTS
			var pa: Vector3 = rings[m][k]
			var pb: Vector3 = rings[m][k1]
			var pc: Vector3 = rings[m + 1][k1]
			var pd: Vector3 = rings[m + 1][k]
			var hint: Vector3 = HillsPool._air((pa + pc) * 0.5)
			var st: SurfaceTool = tile if m == 0 else plaster
			HillsRoad.tri_facing(st, pa, pb, pc, hint)
			HillsRoad.tri_facing(st, pa, pc, pd, hint)
	var last: PackedVector3Array = rings[rings.size() - 1]
	var mid := Vector3(0.0, -HillsPool.depth_at(0.0, a, deep, shallow), 0.0)
	for k: int in SEGMENTS:
		HillsRoad.tri_facing(plaster, last[k], last[(k + 1) % SEGMENTS], mid, Vector3.UP)
	plaster.index()
	plaster.generate_normals()
	tile.index()
	tile.generate_normals()
	var shell_mesh := ArrayMesh.new()
	plaster.commit(shell_mesh)
	tile.commit(shell_mesh)
	var shell := StaticBody3D.new()
	shell.name = "Shell"
	var smi := MeshInstance3D.new()
	smi.name = "Mesh"
	smi.mesh = shell_mesh
	smi.set_surface_override_material(0, Toon.material(PLASTER))
	smi.set_surface_override_material(1, Toon.material(TILE))
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.add_child(smi)
	var scs := CollisionShape3D.new()
	scs.name = "Collision"
	var sshape: ConcavePolygonShape3D = shell_mesh.create_trimesh_shape()
	sshape.backface_collision = true
	scs.shape = sshape
	shell.add_child(scs)
	root.add_child(shell)
	# --- deck and coping band -----------------------------------------------------------------------------------
	var outer := PackedVector2Array()
	for p: Vector2 in rim:
		outer.append(p * ((p.length() + COPING_W) / p.length()))
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx: float = size.x * 0.5
	var hz: float = size.y * 0.5
	var n4: int = SEGMENTS / 2
	var right := PackedVector2Array([Vector2(0.0, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(0.0, hz)])
	for k: int in range(n4, -1, -1):
		right.append(outer[k % SEGMENTS])
	var left := PackedVector2Array([Vector2(0.0, hz), Vector2(-hx, hz), Vector2(-hx, -hz), Vector2(0.0, -hz)])
	for k: int in range(SEGMENTS, n4 - 1, -1):
		left.append(outer[k % SEGMENTS])
	for poly: PackedVector2Array in [right, left]:
		var tri: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		for q: int in range(0, tri.size(), 3):
			HillsRoad.tri_facing(deck, HillsPool._v3(poly[tri[q]]), HillsPool._v3(poly[tri[q + 1]]), HillsPool._v3(poly[tri[q + 2]]), Vector3.UP)
	deck.generate_normals()
	var band := SurfaceTool.new()
	band.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in SEGMENTS:
		var k1: int = (k + 1) % SEGMENTS
		HillsRoad.quad_up(band, HillsPool._v3(rim[k]), HillsPool._v3(rim[k1]), HillsPool._v3(outer[k1]), HillsPool._v3(outer[k]))
	band.generate_normals()
	var deck_mesh := ArrayMesh.new()
	deck.commit(deck_mesh)
	band.commit(deck_mesh)
	var deck_body := StaticBody3D.new()
	deck_body.name = "Deck"
	var dmi := MeshInstance3D.new()
	dmi.name = "Mesh"
	dmi.mesh = deck_mesh
	dmi.set_surface_override_material(0, WorldSurface.material("concrete", DECK, 0.5))
	dmi.set_surface_override_material(1, Toon.material(COPING))
	dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	deck_body.add_child(dmi)
	var dcs := CollisionShape3D.new()
	dcs.name = "Collision"
	dcs.shape = deck_mesh.create_trimesh_shape()
	deck_body.add_child(dcs)
	root.add_child(deck_body)
	# --- coping: pipe, grind line, ramp-snap lip ----------------------------------------------------------------
	var loop := PackedVector3Array()
	for p: Vector2 in rim:
		loop.append(Vector3(p.x, 0.0, p.y))
	loop.append(loop[0])
	root.add_child(PieceKit.rail(loop, "coping", "Coping"))
	root.add_child(RampLip.ring(loop, Vector3.ZERO))
	var pipe := MeshInstance3D.new()
	pipe.name = "CopingPipe"
	pipe.mesh = HillsPool.tube(loop, 0.06, 6)
	pipe.material_override = Toon.material(PIPE)
	pipe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pipe)
	# zones: the air over the pool, and each end bank's lip
	root.add_child(PieceKit.gap_zone(zone_prefix + "_air", Vector3(-a * 0.6, 0.6, -b * 0.6), Vector3(a * 1.2, 4.0, b * 1.2)))
	root.add_child(PieceKit.gap_zone(zone_prefix + "_w", Vector3(-a - 1.2, -0.6, -1.5), Vector3(1.6, 3.0, 3.0)))
	root.add_child(PieceKit.gap_zone(zone_prefix + "_e", Vector3(a - 0.4, -0.6, -1.5), Vector3(1.6, 3.0, 3.0)))
	return root


## The rim at angle th (0 = +x): an ellipse a x b, a bigger lobe toward +x, and the kidney's dent on the +z side.
static func _rim(th: float, a: float, b: float, dent: float) -> Vector2:
	var c: float = cos(th)
	var s: float = sin(th)
	var r: float = 1.0 / sqrt((c / a) * (c / a) + (s / b) * (s / b))
	var dd: float = angle_difference(th, PI * 0.55)
	r *= 1.0 - dent * exp(-(dd / 0.5) * (dd / 0.5))
	r *= 1.0 + 0.1 * c
	return Vector2(c, s) * r


## Depth of the floor at x: deep in the middle, shallow toward both ends.
static func depth_at(x: float, a: float, deep: float, shallow: float) -> float:
	return lerpf(deep, shallow, smoothstep(0.15 * a, 0.75 * a, absf(x)))


static func _air(p: Vector3) -> Vector3:
	var inward := Vector3(-p.x, 0.0, -p.z)
	if inward.length_squared() > 1e-6:
		inward = inward.normalized()
	return inward + Vector3.UP * 0.35


static func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


## A round tube along a polyline (visual only), `sides` facets.
static func tube(path: PackedVector3Array, radius: float, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = path.size()
	var rings: Array[PackedVector3Array] = []
	for i: int in n:
		var t: Vector3 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side: Vector3 = t.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.5:
			side = Vector3.RIGHT
		var up: Vector3 = side.cross(t).normalized()
		var ring := PackedVector3Array()
		for k: int in sides:
			var ang: float = TAU * float(k) / float(sides)
			ring.append(path[i] + (side * cos(ang) + up * sin(ang)) * radius)
		rings.append(ring)
	for i: int in n - 1:
		for k: int in sides:
			var k1: int = (k + 1) % sides
			var c: Vector3 = (path[i] + path[i + 1]) * 0.5
			var a0: Vector3 = rings[i][k]
			var a1: Vector3 = rings[i][k1]
			var b0: Vector3 = rings[i + 1][k]
			var b1: Vector3 = rings[i + 1][k1]
			var out: Vector3 = ((a0 + a1 + b0 + b1) * 0.25 - c)
			HillsRoad.tri_facing(st, a0, a1, b1, out)
			HillsRoad.tri_facing(st, a0, b1, b0, out)
	st.generate_normals()
	return st.commit()
