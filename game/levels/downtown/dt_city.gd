class_name DtCity
extends RefCounted
## Downtown's buildings: the street walls round the riding area (solid, with Houdini-kit storefronts and cornices),
## the rest of the city grid out to DtPlan.CITY_HALF (lots split from every block), and a far skyline of towers with
## a landmark closing the view at the end of every street. Every building is a box instance of one MultiMesh drawn with
## dt_tower.gdshader (world-space floors and window bays), so the whole city costs a handful of draw calls.

const SHADER: Shader = preload("res://game/levels/downtown/dt_tower.gdshader")
const MASONRY := [Color("c9b28c"), Color("b8664c"), Color("e3d6bd"), Color("a7a6ad"), Color("d39a6a"), Color("c2c7cc"), Color("9c5b49"), Color("e9e1cf")]
const GLASS := [Color("5f8fae"), Color("4c76a6"), Color("6aa3a8"), Color("8a9db8"), Color("3f5f86"), Color("7fb2c9")]
const STYLE_PUNCHED: float = 0.0
const STYLE_GLASS: float = 0.1
const STYLE_RIBBON: float = 0.2
const STYLE_BLANK: float = 0.3
const LINE_CLEAR: float = 6.5  ## half-width of the Line's corridor through the blocks
const SHADOW_REACH: float = 70.0  ## buildings this close to the riding area cast shadows

var lvl: Node3D
var night: bool = false
var _rng := RandomNumberGenerator.new()
var _near: Array = []  ## [Transform3D, Color, style]
var _far: Array = []
var _sb: StaticBody3D
var _roofs := DtBatch.new()
var _facades: Array[Transform3D] = []
var _root: Node3D


func _init(level: Node3D) -> void:
	lvl = level
	_rng.seed = 90210


func build() -> void:
	_root = Node3D.new()
	_root.name = "City"
	lvl.add_child(_root)
	_sb = DtKit.body(_root, "BuildingCollision")
	for b: Rect2 in DtPlan.grid_blocks():
		for r: Rect2 in _lots_of(b):
			_fill(r, b, r)
	_skyline()
	_landmarks()
	_commit()


## The parts of a grid block given over to ordinary buildings (the special blocks keep their own content).
func _free_rects(b: Rect2) -> Array[Rect2]:
	var w: float = DtPlan.WALK
	var out: Array[Rect2] = []
	var c: Vector2 = b.get_center()
	if DtPlan.CENTER.has_point(c):
		return out
	if DtPlan.SOUTH.grow(40.0).has_point(c) and b.position.x > -50.0 and b.end.x < 50.0:
		out.append(Rect2(b.position.x + w, 90.5, b.size.x - 2.0 * w, b.end.y - w - 90.5))
		return out
	if b.has_point(Vector2(DtPlan.SE.position.x + 1.0, DtPlan.SE.position.y + 1.0)):
		out.append(Rect2(100.5, b.position.y + w, b.end.x - w - 100.5, b.size.y - 2.0 * w))
		out.append(Rect2(b.position.x + w, 90.5, 100.5 - b.position.x - w, b.end.y - w - 90.5))
		return out
	if b.has_point(Vector2(DtPlan.SW.end.x - 1.0, DtPlan.SW.position.y + 1.0)):
		out.append(Rect2(b.position.x + w, b.position.y + w, -100.5 - b.position.x - w, b.size.y - 2.0 * w))
		out.append(Rect2(-100.5, 90.5, b.end.x - w + 100.5, b.end.y - w - 90.5))
		return out
	out.append(b.grow(-w))
	return out


## The lots of a block, less a corridor for the Line (the beams and trains run between the buildings, end to end).
func _lots_of(b: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var z0: float = DtPlan.MONO_Z - LINE_CLEAR
	var z1: float = DtPlan.MONO_Z + LINE_CLEAR
	for r: Rect2 in _free_rects(b):
		if r.end.y <= z0 or r.position.y >= z1:
			out.append(r)
			continue
		if z0 - r.position.y >= 4.0:
			out.append(Rect2(r.position.x, r.position.y, r.size.x, z0 - r.position.y))
		if r.end.y - z1 >= 4.0:
			out.append(Rect2(r.position.x, z1, r.size.x, r.end.y - z1))
	return out


## Splits a rect into lots (recursively, along its longer side) and puts a building on each.
func _fill(r: Rect2, block: Rect2, area: Rect2) -> void:
	if r.size.x < 4.0 or r.size.y < 4.0:
		return
	var long_x: bool = r.size.x >= r.size.y
	var span: float = r.size.x if long_x else r.size.y
	var max_lot: float = 26.0 if _dist_to_play(r) < 60.0 else 40.0
	if span > max_lot:
		var f: float = _rng.randf_range(0.35, 0.65)
		var cut: float = roundf(span * f)
		if long_x:
			_fill(Rect2(r.position.x, r.position.y, cut, r.size.y), block, area)
			_fill(Rect2(r.position.x + cut, r.position.y, r.size.x - cut, r.size.y), block, area)
		else:
			_fill(Rect2(r.position.x, r.position.y, r.size.x, cut), block, area)
			_fill(Rect2(r.position.x, r.position.y + cut, r.size.x, r.size.y - cut), block, area)
		return
	_lot(r, block, area)


func _dist_to_play(r: Rect2) -> float:
	var b: Rect2 = DtPlan.BOUNDS
	var dx: float = maxf(0.0, maxf(b.position.x - r.end.x, r.position.x - b.end.x))
	var dz: float = maxf(0.0, maxf(b.position.y - r.end.y, r.position.y - b.end.y))
	return sqrt(dx * dx + dz * dz)


## One building on a lot: height and style from its distance to the riding area (low masonry close in, glass towers
## further out and toward the north-west core), storefronts on the faces that look onto a street near the play space.
func _lot(r: Rect2, block: Rect2, area: Rect2) -> void:
	var d: float = _dist_to_play(r)
	var core: float = clampf((-r.get_center().y - r.get_center().x * 0.3) / 260.0, 0.0, 1.0)
	var h: float
	var style: float
	var col: Color
	if d < 2.0:
		h = _rng.randf_range(16.0, 42.0)
		style = STYLE_PUNCHED if _rng.randf() < 0.65 else STYLE_RIBBON
	elif d < 90.0:
		h = _rng.randf_range(22.0, 70.0) + core * 50.0
		style = [STYLE_PUNCHED, STYLE_RIBBON, STYLE_GLASS][_rng.randi() % 3]
	else:
		h = _rng.randf_range(30.0, 110.0) + core * 110.0
		style = STYLE_GLASS if _rng.randf() < 0.55 else [STYLE_PUNCHED, STYLE_RIBBON][_rng.randi() % 2]
	col = (GLASS[_rng.randi() % GLASS.size()] if style == STYLE_GLASS else MASONRY[_rng.randi() % MASONRY.size()]) as Color
	h = roundf(h / 3.6) * 3.6 + 1.2
	var near: bool = d < SHADOW_REACH
	_box(r, 0.0, h, col, style, near)
	if h > 55.0 and _rng.randf() < 0.7:
		# a setback tier on top
		var inset: float = minf(r.size.x, r.size.y) * _rng.randf_range(0.12, 0.22)
		var h2: float = roundf(h * _rng.randf_range(0.18, 0.4) / 3.6) * 3.6
		_box(r.grow(-inset), h, h2, col.lightened(0.05), style, near)
		_crown(r.grow(-inset), h + h2, col)
	elif d < 60.0:
		_rooftop(r, h)
	if d < 4.0 and r.intersects(DtPlan.BOUNDS.grow(4.0)):
		DtKit.col_box(_sb, Vector3(r.get_center().x, (h - 0.5) * 0.5, r.get_center().y), Vector3(r.size.x, h + 0.5, r.size.y))
	if d < 40.0:
		_storefronts(r, block, area, h, style)
	if style != STYLE_GLASS and d < 90.0 and h < 60.0:
		_cornice(r, h, col)


## A continuous cornice round the top of a masonry building: a projecting cap in a paler tone of its walls, a shadow
## line under it, and a parapet coping.
func _cornice(r: Rect2, h: float, col: Color) -> void:
	var cap: Color = col.lightened(0.18)
	var g: Rect2 = r.grow(0.35)
	_roofs.box_min(Vector3(g.position.x, h - 0.75, g.position.y), Vector3(g.size.x, 0.75, g.size.y), cap, false)
	_roofs.box_min(Vector3(r.position.x + 0.02, h - 1.0, r.position.y + 0.02), Vector3(r.size.x - 0.04, 0.25, r.size.y - 0.04), col.darkened(0.35), false)
	_roofs.box_min(Vector3(g.position.x + 0.1, h, g.position.y + 0.1), Vector3(g.size.x - 0.2, 0.35, g.size.y - 0.2), col.darkened(0.1))


## Kit storefronts (facade_base) along every face of the lot on the edge of its area that looks onto a street or
## onto the play space.
func _storefronts(r: Rect2, block: Rect2, area: Rect2, h: float, style: float) -> void:
	var faces: Array = [
		[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector3(0, 0, -1), r.position.y - block.position.y, absf(r.position.y - area.position.y)],
		[Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y), Vector3(0, 0, 1), block.end.y - r.end.y, absf(r.end.y - area.end.y)],
		[Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.position.y), Vector3(-1, 0, 0), r.position.x - block.position.x, absf(r.position.x - area.position.x)],
		[Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector3(1, 0, 0), block.end.x - r.end.x, absf(r.end.x - area.end.x)],
	]
	for f: Array in faces:
		if float(f[4]) > 0.01:
			continue  # an inner face between two lots
		var mid: Vector2 = ((f[0] as Vector2) + (f[1] as Vector2)) * 0.5
		var o3: Vector3 = f[2]
		var faces_play: bool = DtPlan.BOUNDS.has_point(mid + Vector2(o3.x, o3.z) * 3.0)
		if float(f[3]) > DtPlan.WALK + 0.6 and not faces_play:
			continue  # not on a street or the play space
		var a: Vector2 = f[0]
		var b: Vector2 = f[1]
		var o: Vector3 = f[2]
		var l: float = a.distance_to(b)
		var n: int = int(floor(l / 10.4))
		if n < 1:
			continue
		var yaw: float = atan2(-o.x, -o.z)
		var dir: Vector2 = (b - a) / l
		var start: float = (l - float(n) * 10.4) * 0.5 + 5.2
		for i: int in n:
			var p: Vector2 = a + dir * (start + float(i) * 10.4)
			var pos := Vector3(p.x, DtPlan.P, p.y) + o * 0.02
			_facades.append(DtKit.at(pos, yaw))


func _box(r: Rect2, y0: float, h: float, col: Color, style: float, near: bool) -> void:
	var xf := Transform3D(Basis.IDENTITY.scaled(Vector3(r.size.x, h, r.size.y)), Vector3(r.get_center().x, y0 + h * 0.5, r.get_center().y))
	(_near if near else _far).append([xf, col, style])


## Rooftop clutter: AC units, a water tank on legs, a stair bulkhead.
func _rooftop(r: Rect2, h: float) -> void:
	var c := Vector3(r.get_center().x, h, r.get_center().y)
	var n: int = 1 + _rng.randi() % 3
	for i: int in n:
		var p: Vector3 = c + Vector3(_rng.randf_range(-0.3, 0.3) * r.size.x, 0.0, _rng.randf_range(-0.3, 0.3) * r.size.y)
		_roofs.box_min(p + Vector3(-1.2, 0.0, -0.8), Vector3(2.4, 1.3, 1.6), Color("b9bec6"))
		_roofs.box_min(p + Vector3(-0.9, 1.3, -0.5), Vector3(1.8, 0.12, 1.0), Color("7d838c"))
	if _rng.randf() < 0.35:
		var t: Vector3 = c + Vector3(r.size.x * 0.22, 0.0, -r.size.y * 0.18)
		for k: int in 4:
			var a: float = PI * 0.25 + PI * 0.5 * float(k)
			_roofs.tube(t + Vector3(cos(a) * 1.3, 0.0, sin(a) * 1.3), t + Vector3(cos(a) * 1.1, 2.6, sin(a) * 1.1), 0.09, Color("5a4436"), 5)
		_roofs.cyl(t + Vector3(0.0, 2.6, 0.0), 1.6, 3.2, Color("8a6a4e"), 12)
		_roofs.cyl(t + Vector3(0.0, 5.8, 0.0), 1.7, 1.0, Color("6b5a4a"), 12, 0.15)
	_roofs.box_min(Vector3(r.position.x + 1.5, h, r.end.y - 4.5), Vector3(3.0, 2.8, 3.0), Color("cfc8bb"))


## A crown on a tall tower: a narrower cap and a mast.
func _crown(r: Rect2, h: float, col: Color) -> void:
	var c := Vector3(r.get_center().x, h, r.get_center().y)
	var s: float = minf(r.size.x, r.size.y)
	_roofs.box(c + Vector3(0.0, 2.5, 0.0), Vector3(r.size.x * 0.6, 5.0, r.size.y * 0.6), col.darkened(0.2))
	if _rng.randf() < 0.6:
		_roofs.tube(c + Vector3(0.0, 5.0, 0.0), c + Vector3(0.0, 5.0 + s * 0.8, 0.0), 0.35, Color("d8dde4"), 6)


## Far towers beyond the grid: a ring out to ~1 km, taller and denser to the north (the downtown core).
func _skyline() -> void:
	var step: float = 46.0
	var lim: float = 1000.0
	var x: float = -lim
	while x <= lim:
		var z: float = -lim
		while z <= lim:
			var px: float = x + _rng.randf_range(-12.0, 12.0)
			var pz: float = z + _rng.randf_range(-12.0, 12.0)
			z += step
			if absf(px) < DtPlan.CITY_HALF + 25.0 and absf(pz) < DtPlan.CITY_HALF + 25.0:
				continue
			var dist: float = Vector2(px, pz).length()
			if dist > lim + 60.0:
				continue
			var north: float = clampf(-pz / 700.0, -0.4, 1.0)
			if _rng.randf() > 0.62 + north * 0.25:
				continue
			var w: float = _rng.randf_range(18.0, 38.0)
			var d: float = _rng.randf_range(18.0, 38.0)
			var h: float = _rng.randf_range(45.0, 130.0) + maxf(north, 0.0) * _rng.randf_range(40.0, 160.0)
			var glass: bool = _rng.randf() < 0.6
			var col: Color = (GLASS[_rng.randi() % GLASS.size()] if glass else MASONRY[_rng.randi() % MASONRY.size()]) as Color
			var r := Rect2(px - w * 0.5, pz - d * 0.5, w, d)
			_box(r, 0.0, h, col, STYLE_GLASS if glass else STYLE_RIBBON, false)
			if h > 120.0 and _rng.randf() < 0.6:
				var r2: Rect2 = r.grow(-minf(w, d) * 0.18)
				var h2: float = h * _rng.randf_range(0.15, 0.3)
				_box(r2, h, h2, col.lightened(0.06), STYLE_GLASS if glass else STYLE_RIBBON, false)
				if _rng.randf() < 0.5:
					_roofs.tube(Vector3(px, h + h2, pz), Vector3(px, h + h2 + h * 0.25, pz), 0.6, Color("dfe4ea"), 6)
		x += step


## A landmark tower at the end of each street: tiers with setbacks and a spire, so every street view ends in a skyline.
func _landmarks() -> void:
	var spots: Array = [
		[Vector2(DtPlan.X_W, -420.0), 230.0, Color("7fb2c9")], [Vector2(DtPlan.X_E, -470.0), 260.0, Color("c9b28c")],
		[Vector2(DtPlan.X_W, 430.0), 170.0, Color("e3d6bd")], [Vector2(DtPlan.X_E, 400.0), 190.0, Color("4c76a6")],
		[Vector2(-430.0, DtPlan.Z_N), 210.0, Color("a7a6ad")], [Vector2(420.0, DtPlan.Z_N), 240.0, Color("6aa3a8")],
		[Vector2(-410.0, DtPlan.Z_S), 160.0, Color("d39a6a")], [Vector2(440.0, DtPlan.Z_S), 200.0, Color("8a9db8")],
	]
	for s: Array in spots:
		var c: Vector2 = s[0]
		var h: float = float(s[1])
		var col: Color = s[2]
		var w: float = 42.0
		var y: float = 0.0
		var tiers: Array[float] = [0.55, 0.25, 0.12]
		for i: int in tiers.size():
			var th: float = h * tiers[i]
			var r := Rect2(c.x - w * 0.5, c.y - w * 0.5, w, w)
			_box(r, y, th, col.lightened(0.04 * float(i)), STYLE_GLASS if i != 1 or col.r > 0.6 else STYLE_RIBBON, false)
			y += th
			w *= 0.72
		_roofs.box(Vector3(c.x, y + 3.0, c.y), Vector3(w, 6.0, w), col.darkened(0.25))
		_roofs.cyl(Vector3(c.x, y + 6.0, c.y), w * 0.35, h * 0.14, Color("e6eaef"), 8, 0.4)
		_roofs.tube(Vector3(c.x, y + 6.0 + h * 0.14, c.y), Vector3(c.x, y + 6.0 + h * 0.3, c.y), 0.5, Color("f2f4f7"), 6)


func _commit() -> void:
	_root.add_child(_multi("Buildings", _near, true))
	_root.add_child(_multi("Skyline", _far, false))
	if not _roofs.is_empty():
		var mi: MeshInstance3D = _roofs.instance("Rooftops", true)
		_root.add_child(mi)
	var kit: LevelKit = LevelKit.open("downtown")
	DtKit.kit_multi(_root, kit, "facade_base", _facades, null, true)


func _multi(node_name: String, list: Array, shadow: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	mm.instance_count = list.size()
	for i: int in list.size():
		var e: Array = list[i]
		mm.set_instance_transform(i, e[0] as Transform3D)
		var c: Color = e[1]
		mm.set_instance_custom_data(i, Color(c.r, c.g, c.b, float(e[2])))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("night", 1.0 if night else 0.0)
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
