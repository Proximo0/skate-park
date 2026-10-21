class_name AnimeBoard
extends RefCounted
## Surf-style skateboard parts: a popsicle deck with kicked nose and tail, trucks and wheels. Static builders called
## by PlaceholderSkater.build_board. Long along Z, nose at -Z, wheel bottoms at y = 0; the deck top stays at
## DECK_TOP_Y (0.135) over the flat middle.

const DECK_LENGTH: float = 0.8
const DECK_WIDTH: float = 0.22
const DECK_THICK: float = 0.03
const DECK_Y: float = 0.12
## Flat middle ends at this |z|; the nose and tail curve up and round off over the remaining distance.
const FLAT_HALF: float = 0.27
const KICK_RISE: float = 0.05
const CORNER_COLS: int = 4


static func build_deck(root: Node3D, mats: Dictionary) -> void:
	# "Deck" is the board's reference box (full size, top at DECK_TOP_Y). It is not drawn: the visible deck is the
	# shaped surfaces below, which round and kick the ends.
	var proxy: MeshInstance3D = SkaterParts.part(root, "Deck", SkaterParts.box(Vector3(DECK_WIDTH, DECK_THICK, DECK_LENGTH)),
			Vector3(0.0, DECK_Y, 0.0), mats, "grip")
	proxy.visible = false

	var zs: Array = _sample_zs()
	var full: Callable = func(z: float) -> Vector2:
		var hw: float = _half_width(z)
		return Vector2(-hw, hw)
	var inset: Callable = func(z: float) -> Vector2:
		var hw: float = maxf(_half_width(z) - 0.009, 0.0)
		return Vector2(-hw, hw)
	var half_t: float = DECK_THICK * 0.5

	# Top: a coral rim around a sand grip surface.
	SkaterParts.part(root, "DeckRim", _surface(zs, full, half_t - 0.0016, true), Vector3.ZERO, mats, "deck_alt")
	SkaterParts.part(root, "DeckGrip", _surface(zs, inset, half_t, true), Vector3.ZERO, mats, "grip")
	# Edge wall in aqua.
	SkaterParts.part(root, "DeckEdge", _edge(zs), Vector3.ZERO, mats, "deck")
	# Bottom: aqua base with a coral wave ribbon and a sun.
	SkaterParts.part(root, "DeckBottom", _surface(zs, full, -half_t, false), Vector3.ZERO, mats, "deck")
	var wave: Callable = func(z: float) -> Vector2:
		var cx: float = 0.032 * sin(z * 17.0)
		var hw: float = minf(0.04, _half_width(z) - 0.03)
		hw = maxf(hw, 0.0)
		return Vector2(cx - hw, cx + hw)
	var wave_zs: Array = []
	for i: int in 41:
		wave_zs.append(-0.3 + 0.6 * float(i) / 40.0)
	SkaterParts.part(root, "DeckWave", _surface(wave_zs, wave, -half_t - 0.0012, false), Vector3.ZERO, mats, "deck_alt")
	SkaterParts.part(root, "DeckSun", SkaterParts.cylinder(0.034, 0.003),
			Vector3(0.0, DECK_Y - half_t - 0.0016, -0.17), mats, "deck_sun")


static func build_truck(board: Node3D, truck_name: String, z: float, mats: Dictionary) -> void:
	var truck: Node3D = SkaterParts.joint(board, "Truck_" + truck_name, Vector3(0.0, 0.0, z))
	SkaterParts.part(truck, "TruckBaseMesh", SkaterParts.box(Vector3(0.15, 0.02, 0.07)), Vector3(0.0, 0.095, 0.0), mats, "trucks")
	SkaterParts.part(truck, "TruckHangerMesh", SkaterParts.box(Vector3(0.2, 0.034, 0.03)), Vector3(0.0, 0.07, 0.0), mats, "trucks")
	var axle: MeshInstance3D = SkaterParts.part(truck, "TruckAxleMesh", SkaterParts.cylinder(0.009, 0.26), Vector3(0.0, 0.045, 0.0), mats, "trucks")
	axle.rotation.z = PI * 0.5


## Fat wheel (bottom at y = 0) with a light hub on each face.
static func build_wheel(board: Node3D, wheel_name: String, x: float, z: float, mats: Dictionary) -> void:
	var wheel: MeshInstance3D = SkaterParts.part(board, wheel_name, SkaterParts.cylinder(0.045, 0.03), Vector3(x, 0.045, z), mats, "wheels")
	wheel.rotation.z = PI * 0.5
	var hub: MeshInstance3D = SkaterParts.part(board, wheel_name + "_Hub", SkaterParts.cylinder(0.02, 0.036), Vector3(x, 0.045, z), mats, "hubs")
	hub.rotation.z = PI * 0.5


## Deck centre line height at z: flat in the middle, curving up over the nose and tail.
static func center_y(z: float) -> float:
	var d: float = maxf(absf(z) - FLAT_HALF, 0.0) / (DECK_LENGTH * 0.5 - FLAT_HALF)
	return DECK_Y + KICK_RISE * pow(d, 1.7)


## Half width at z: full in the middle, a rounded end over the kicked part.
static func _half_width(z: float) -> float:
	var end: float = DECK_LENGTH * 0.5 - FLAT_HALF
	var d: float = maxf(absf(z) - FLAT_HALF, 0.0) / end
	return DECK_WIDTH * 0.5 * sqrt(maxf(1.0 - d * d, 0.0))


## z samples from nose to tail: even in the flat part, arc-spaced over the rounded ends so the tip stays round.
static func _sample_zs() -> Array:
	var out: Array = []
	var end: float = DECK_LENGTH * 0.5 - FLAT_HALF
	var arc: int = 14
	for i: int in arc + 1:
		var phi: float = (PI * 0.5) * (1.0 - float(i) / float(arc))
		out.append(-(FLAT_HALF + end * sin(phi)))
	for i: int in range(1, 7):
		out.append(-FLAT_HALF + 2.0 * FLAT_HALF * float(i) / 7.0)
	for i: int in arc + 1:
		var phi: float = (PI * 0.5) * float(i) / float(arc)
		out.append(FLAT_HALF + end * sin(phi))
	return out


static func _slope(z: float) -> float:
	return (center_y(z + 0.002) - center_y(z - 0.002)) / 0.004


## A ribbon over the deck at height y_off from the centre line: x range per z from range_fn, CORNER_COLS columns each
## side. Normals follow the kick. Faces up when facing_up, else down.
static func _surface(zs: Array, range_fn: Callable, y_off: float, facing_up: bool) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols: int = CORNER_COLS * 2
	var sign_n: float = 1.0 if facing_up else -1.0
	for i: int in zs.size() - 1:
		var z0: float = zs[i]
		var z1: float = zs[i + 1]
		var r0: Vector2 = range_fn.call(z0)
		var r1: Vector2 = range_fn.call(z1)
		var n0: Vector3 = Vector3(0.0, 1.0, -_slope(z0)).normalized() * sign_n
		var n1: Vector3 = Vector3(0.0, 1.0, -_slope(z1)).normalized() * sign_n
		for j: int in cols:
			var u0: float = float(j) / float(cols)
			var u1: float = float(j + 1) / float(cols)
			var a: Vector3 = Vector3(lerpf(r0.x, r0.y, u0), center_y(z0) + y_off, z0)
			var b: Vector3 = Vector3(lerpf(r0.x, r0.y, u1), center_y(z0) + y_off, z0)
			var c: Vector3 = Vector3(lerpf(r1.x, r1.y, u0), center_y(z1) + y_off, z1)
			var d: Vector3 = Vector3(lerpf(r1.x, r1.y, u1), center_y(z1) + y_off, z1)
			_tri(st, a, b, c, n0, n0, n1)
			_tri(st, b, d, c, n0, n1, n1)
	return st.commit()


## The side wall: the outline of the deck, top to bottom.
static func _edge(zs: Array) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var loop: Array = []
	for z: float in zs:
		loop.append(Vector2(_half_width(z), z))
	for i: int in range(zs.size() - 1, -1, -1):
		loop.append(Vector2(-_half_width(zs[i]), zs[i]))
	var half_t: float = DECK_THICK * 0.5
	for i: int in loop.size():
		var p0: Vector2 = loop[i]
		var p1: Vector2 = loop[(i + 1) % loop.size()]
		if p0.distance_to(p1) < 0.0001:
			continue
		var out0: Vector3 = _outward(loop, i)
		var out1: Vector3 = _outward(loop, (i + 1) % loop.size())
		var a: Vector3 = Vector3(p0.x, center_y(p0.y) + half_t, p0.y)
		var b: Vector3 = Vector3(p1.x, center_y(p1.y) + half_t, p1.y)
		var c: Vector3 = Vector3(p0.x, center_y(p0.y) - half_t, p0.y)
		var d: Vector3 = Vector3(p1.x, center_y(p1.y) - half_t, p1.y)
		_tri(st, a, b, c, out0, out1, out0)
		_tri(st, b, d, c, out1, out1, out0)
	return st.commit()


static func _outward(loop: Array, i: int) -> Vector3:
	var n: int = loop.size()
	var prev: Vector2 = loop[(i - 1 + n) % n]
	var next: Vector2 = loop[(i + 1) % n]
	var t: Vector2 = next - prev
	var normal: Vector2 = Vector2(t.y, -t.x).normalized()
	var p: Vector2 = loop[i]
	if normal.dot(Vector2(p.x, p.y)) < 0.0:
		normal = -normal
	return Vector3(normal.x, 0.0, normal.y)


## Adds a triangle wound clockwise as seen from the side its normals point to (Godot's front face).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var face: Vector3 = (b - a).cross(c - a)
	var avg: Vector3 = na + nb + nc
	if face.length() < 0.0000001:
		return
	if face.dot(avg) > 0.0:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nc)
		st.add_vertex(c)
		st.set_normal(nb)
		st.add_vertex(b)
	else:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nb)
		st.add_vertex(b)
		st.set_normal(nc)
		st.add_vertex(c)
