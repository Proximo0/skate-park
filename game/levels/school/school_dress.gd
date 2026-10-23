class_name SchoolDress
extends RefCounted
## The School level's dressing and life: swaying trees and shrubs (one MultiMesh per kind, trunks collide), kit props
## repeated as MultiMeshes (collision boxes from the kit manifest), lamps that flicker on at dusk (a real light on only
## some of them, pools under all), signs, steam, the chain-link fence and road markings, the perimeter traffic, the
## people (students, joggers, the janitor and his cart) and the birds, the sprinklers and the field lights.

const STREET_LAMP_STEP: float = 32.0
## Campus lamps built as FlickerLights (a real light each, flickering on at dusk); the rest are merged static
## geometry with a lit bulb and a floor pool, to keep the draw calls and the lights in budget.
const MAX_LAMP_LIGHTS: int = 3
## Which of the campus lamp spots in finish() get a real light: the two east of the fountain (seen from the spawn)
## and one in the courtyard. In the Compatibility renderer every real light redraws everything it touches, so the
## people are kept out of their reach.
const REAL_LAMPS: Array[int] = [1, 3, 7]

var level: Node3D
var kit: LevelKit
var trees: SwayTrees
var body: StaticBody3D
var geo: SchoolGeo
var lamps: Array[FlickerLight] = []
var lamp_colour: Color = Color("ffd08a")
var _lamp_spots: Array = []  ## [pos, yaw, seed, height, real]
var _bins: Array[Transform3D] = []
var _n: int = 0


func _init(lvl: Node3D, k: LevelKit) -> void:
	level = lvl
	kit = k
	trees = SwayTrees.new()
	trees.name = "Trees"
	body = StaticBody3D.new()
	body.name = "DressSolid"
	body.collision_layer = 1
	body.collision_mask = 0
	lvl.add_child(body)
	geo = SchoolGeo.new(lvl, "Dress")
	var m: Variant = lvl.get("mood")
	if m is Dictionary and (m as Dictionary).has("lamp_color"):
		lamp_colour = (m as Dictionary)["lamp_color"] as Color


# --- trees and props ------------------------------------------------------------------------------------

## A swaying tree at pos (size x the kind's default); its trunk is solid when it stands inside the riding area.
func tree(pos: Vector3, size: float = 1.0, kind: String = "round") -> void:
	trees.add(kind, pos, size)
	if SchoolLevel.BOUNDS.grow(1.0).has_point(Vector2(pos.x, pos.z)):
		_cyl_solid(pos, 0.24 * size, 2.6 * size)


## Low bushes scattered over a rect at height y.
func shrubs(r: Rect2, y: float, n: int) -> void:
	for i: int in n:
		var t: float = (float(i) + 0.5) / float(n)
		trees.add("bush", Vector3(r.position.x + r.size.x * t, y, r.get_center().y + sin(float(i) * 2.3) * r.size.y * 0.3), 0.75 + 0.2 * sin(float(i) * 1.7))


## A kit piece repeated at each transform: one MultiMeshInstance3D per mesh of the piece, and the manifest's collision
## boxes added to `g`'s body (unless `collide` is false).
func kit_row(piece: String, xfs: Array[Transform3D], g: SchoolGeo, collide: bool = true, shadow: bool = true) -> void:
	if xfs.is_empty():
		return
	var vis: Node3D = kit.visual(piece)
	for n: Node in vis.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate() as Mesh
		if mesh is ArrayMesh:
			for s: int in mesh.get_surface_count():
				(mesh as ArrayMesh).surface_set_material(s, mi.get_surface_override_material(s))
		var local: Transform3D = LevelKit._relative(vis, mi)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i: int in xfs.size():
			mm.set_instance_transform(i, xfs[i] * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%s" % [piece, mi.name]
		mmi.multimesh = mm
		if not shadow:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(mmi)
	vis.free()
	if collide:
		for xf: Transform3D in xfs:
			for bb: AABB in kit.collision_boxes(piece):
				g.osolid(xf * Transform3D(Basis.IDENTITY, bb.get_center()), bb.size)


## A trash bin (the shared Houdini bin, school blue), solid.
func kit_bin(pos: Vector3) -> void:
	_bins.append(Transform3D(Basis(Vector3.UP, fposmod(pos.x * 0.37 + pos.z * 0.71, TAU)), pos))


## All the bins as one MultiMesh per bin part, each with a solid cylinder.
func _build_bins() -> void:
	if _bins.is_empty():
		return
	var bin: Node3D = HoudiniProps.instance("trash_bin", Color("2f5f9e"))
	level.add_child(bin)
	var bb: AABB = HoudiniProps.aabb_of(bin)
	for n: Node in bin.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var local: Transform3D = bin.global_transform.affine_inverse() * mi.global_transform
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = _bins.size()
		for i: int in _bins.size():
			mm.set_instance_transform(i, _bins[i] * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Bins_%s" % mi.name
		mmi.multimesh = mm
		mmi.material_override = mi.material_override
		level.add_child(mmi)
	bin.queue_free()
	for xf: Transform3D in _bins:
		_cyl_solid(xf.origin, maxf(bb.size.x, bb.size.z) * 0.5, bb.size.y)


## Parked cars: [[position, yaw], ...]. A CarModel each (lights off) with a solid box.
func parked_cars(spots: Array) -> void:
	var kinds: Array[String] = ["hatch", "pickup", "van", "hatch", "hatch", "van"]
	var paints: Array[String] = ["b3262d", "eeeeea", "264f8f", "9aa3ad", "3d7a5a", "f2c94c", "2a2d34", "ff8a3d", "7ec8e3"]
	var i: int = 0
	for s: Array in spots:
		var car: CarModel = CarModel.create(kinds[i % kinds.size()], Color(paints[i % paints.size()]))
		car.position = s[0] as Vector3
		car.rotation.y = float(s[1]) * PI  # -0.5: nose +X, 0.5: nose -X (cars face -Z)
		level.add_child(car)
		var bb: AABB = car.aabb
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(bb.size.x, bb.size.y * 0.9, bb.size.z)
		cs.shape = shape
		cs.transform = car.transform * Transform3D(Basis.IDENTITY, bb.get_center() - Vector3(0.0, bb.size.y * 0.05, 0.0))
		body.add_child(cs)
		i += 1


# --- signs, light, steam ----------------------------------------------------------------------------------

## A painted or lit Label3D facing `facing` (BACK = readable from +Z). Lit labels ignore the light.
func label(pos: Vector3, text: String, size: int, colour: Color, facing: Vector3 = Vector3.BACK, glow: bool = false, pixel: float = 0.01) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = colour
	l.outline_size = 0 if glow else 6
	l.outline_modulate = Color(0.1, 0.08, 0.12, 0.5)
	l.shaded = not glow
	l.double_sided = false
	l.position = pos
	l.rotation.y = atan2(facing.x, facing.z)
	l.name = "Sign%d" % _n
	_n += 1
	level.add_child(l)
	return l


## An additive pool of lamp light on a floor (no real light).
func light_pool(pos: Vector3, radius: float, strength: float = 0.4) -> void:
	var p: MeshInstance3D = FlickerLight.light_pool(radius, lamp_colour, strength)
	p.position = pos
	level.add_child(p)


func steam(pos: Vector3, scale: float = 1.0) -> void:
	var v: SteamVent = SteamVent.create(Color(1.0, 0.92, 0.86, 0.3), 0.8, 3.5 * scale)
	v.position = pos
	level.add_child(v)


## A campus lamp post (sodium-style head, the mood's lamp colour) whose pole is solid. It flickers on at dusk
## (SchoolLamps); only some of them keep a real light.
## A campus lamp (built in finish(): a FlickerLight if `real`, else merged geometry). Solid pole either way.
func lamp(pos: Vector3, yaw: float, seed_v: int, height: float = 6.5, real: bool = false) -> void:
	_lamp_spots.append([pos, yaw, seed_v, height, real])
	_cyl_solid(pos, 0.13, height)


## A lamp without a light: pole, arm and head (toon), the lit lens and a floor pool, all merged into the dress geo.
func _static_lamp(pos: Vector3, yaw: float, height: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var dark: String = SchoolGeo.toon(Color("3a3e4a"))
	geo.cyl(pos, pos + Vector3(0.0, height, 0.0), 0.085, dark, 6)
	geo.obox(Transform3D(b, pos + b * Vector3(0.0, height - 0.05, -0.55)), Vector3(0.08, 0.08, 1.2), dark, false)
	geo.obox(Transform3D(b, pos + b * Vector3(0.0, height - 0.08, -1.1)), Vector3(0.36, 0.14, 0.62), dark, false)
	geo.obox(Transform3D(b, pos + b * Vector3(0.0, height - 0.16, -1.1)), Vector3(0.28, 0.03, 0.5),
			SchoolGeo.glow(Color(minf(lamp_colour.r * 1.4, 1.0), minf(lamp_colour.g * 1.3, 1.0), lamp_colour.b * 1.1)), false)
	geo.pool(pos + b * Vector3(0.0, 0.03, -1.1), height * 0.9, lamp_colour, 0.42)


# --- fountain and field ---------------------------------------------------------------------------------

## A puddle left in the drained basin, and pigeons over the plaza.
func fountain_life(c: Vector3, floor_y: float) -> void:
	geo.lathe(c + Vector3(1.6, floor_y + 0.012, 1.4), PackedVector2Array([Vector2(1.5, 0.0), Vector2(0.0, 0.0)]), 16, SchoolGeo.toon(Color("4d7e98")), false)
	geo.lathe(c + Vector3(-2.2, floor_y + 0.012, -0.8), PackedVector2Array([Vector2(0.8, 0.0), Vector2(0.0, 0.0)]), 12, SchoolGeo.toon(Color("4d7e98")), false)
	level.add_child(Birds.flock("pigeon", 9, c + Vector3(0.0, 7.0, -4.0), 13.0, 31))


## Field lights (four masts, two real lights), the scoreboard over the north wall, three sprinklers and the crows.
func field_life() -> void:
	var y0: float = SchoolLevel.FIELD_Y
	var pole: String = SchoolGeo.toon(Color("5d6470"))
	var head: String = SchoolGeo.toon(Color("3b3f4c"))
	var bulb: String = SchoolGeo.glow(Color(1.6, 1.45, 1.15))
	var masts: Array = [[Vector3(-86.0, 0.0, -95.0), true], [Vector3(40.0, 0.0, -95.0), true], [Vector3(-63.0, 0.0, -46.0), false], [Vector3(22.0, 0.0, -46.0), false]]
	var aim := Vector3(-23.0, y0, -73.0)
	for m: Array in masts:
		var p: Vector3 = m[0]
		var h: float = 18.0
		geo.cyl(p, p + Vector3(0.0, h, 0.0), 0.3, pole, 8)
		if SchoolLevel.BOUNDS.has_point(Vector2(p.x, p.z)):
			_cyl_solid(p, 0.32, h)
		var to: Vector3 = (aim - p)
		to.y = 0.0
		to = to.normalized()
		var side: Vector3 = Vector3(-to.z, 0.0, to.x)
		var top: Vector3 = p + Vector3(0.0, h, 0.0)
		geo.obox(Transform3D(Basis(side, Vector3.UP, -to), top + Vector3(0.0, 1.2, 0.0)), Vector3(5.0, 3.0, 0.4), head, false)
		for row: int in 3:
			for col: int in 5:
				var c: Vector3 = top + Vector3(0.0, 0.3 + float(row) * 0.95, 0.0) + side * (float(col) - 2.0) * 0.95 + to * 0.22
				geo.obox(Transform3D(Basis(side, Vector3.UP, -to), c), Vector3(0.7, 0.62, 0.06), bulb, false)
	# the field lights' wash: faked with two wide pools (a real spot this big would relight the whole campus)
	for px: float in [-52.0, 4.0]:
		geo.pool(Vector3(px, y0 + 0.03, -73.0), 24.0, Color(1.0, 0.93, 0.8), 0.16)
	# scoreboard
	var sb := Vector3(-23.0, 0.0, -98.0)
	for x: float in [-5.0, 5.0]:
		geo.cyl(sb + Vector3(x, 0.0, 0.0), sb + Vector3(x, 6.0, 0.0), 0.25, pole, 8)
	geo.box(sb + Vector3(-8.0, 6.0, -0.5), Vector3(16.0, 6.5, 0.6), SchoolGeo.toon(Color("1d3d6b")), false)
	geo.vbox(sb + Vector3(-7.4, 6.5, 0.1), Vector3(14.8, 4.1, 0.04), SchoolGeo.glow(Color("0d1220")))
	geo.vbox(sb + Vector3(-8.0, 12.5, -0.4), Vector3(16.0, 0.6, 0.4), SchoolGeo.toon(Color("f2b632")))
	label(sb + Vector3(0.0, 11.3, 0.12), "COUGARS", 150, Color("f2b632"), Vector3.BACK, false, 0.012)
	label(sb + Vector3(-4.0, 9.6, 0.15), "HOME", 90, Color("ffe8b0"), Vector3.BACK, true, 0.01)
	label(sb + Vector3(4.0, 9.6, 0.15), "GUEST", 90, Color("ffe8b0"), Vector3.BACK, true, 0.01)
	label(sb + Vector3(-4.0, 7.9, 0.15), "21", 200, Color("ff5a3c"), Vector3.BACK, true, 0.01)
	label(sb + Vector3(4.0, 7.9, 0.15), "14", 200, Color("ff5a3c"), Vector3.BACK, true, 0.01)
	label(sb + Vector3(0.0, 7.0, 0.15), "4TH  0:00", 60, Color("ffe8b0"), Vector3.BACK, true, 0.01)
	# sprinklers on the field
	for x: float in [-55.0, -23.0, 9.0]:
		var s := SchoolSprinkler.new()
		s.position = Vector3(x, y0, -73.0)
		s.seed_value = int(x)
		level.add_child(s)
	level.add_child(Birds.flock("crow", 11, Vector3(-30.0, 16.0, -80.0), 34.0, 17))
	level.add_child(Birds.flock("crow", 6, Vector3(78.0, 13.0, -66.0), 16.0, 23))


# --- perimeter ------------------------------------------------------------------------------------------

## A chain-link fence round `b` (posts, rails and see-through panels, all merged), 0.3 m outside it; on the north side
## it stands on the field's retaining wall. Hedges just outside.
func fence_line(b: Rect2) -> void:
	var h: float = 2.2
	var post: String = SchoolGeo.toon(Color("8f99a6"))
	var chain: String = _chain_key()
	var o: float = 0.3
	var corners: Array[Vector3] = [Vector3(b.position.x - o, 0.0, b.position.y - o), Vector3(b.end.x + o, 0.0, b.position.y - o),
			Vector3(b.end.x + o, 0.0, b.end.y + o), Vector3(b.position.x - o, 0.0, b.end.y + o)]
	for i: int in 4:
		var a: Vector3 = corners[i]
		var c: Vector3 = corners[(i + 1) % 4]
		var n: int = int(ceil(a.distance_to(c) / 3.0))
		for k: int in n + 1:
			var p: Vector3 = a.lerp(c, float(k) / float(n))
			geo.box(p + Vector3(-0.04, 0.0, -0.04), Vector3(0.08, h + 0.05, 0.08), post, false)
		geo.cyl(a + Vector3(0.0, h, 0.0), c + Vector3(0.0, h, 0.0), 0.035, post, 6)
		geo.cyl(a + Vector3(0.0, 0.08, 0.0), c + Vector3(0.0, 0.08, 0.0), 0.03, post, 6)
		var d: Vector3 = (c - a).normalized()
		geo.decal(a + Vector3(0.0, 0.05, 0.0), c + Vector3(0.0, 0.05, 0.0), c + Vector3(0.0, h, 0.0), a + Vector3(0.0, h, 0.0), chain, Vector3(-d.z, 0.0, d.x))
		# hedge row outside
		var out_n := Vector3(d.z, 0.0, -d.x)
		var m: int = int(a.distance_to(c) / 4.0)
		for k: int in m:
			var p: Vector3 = a.lerp(c, (float(k) + 0.5) / float(m)) + out_n * 1.4
			trees.add("bush", p, 1.05 + 0.25 * sin(float(k) * 1.9))


## The see-through chain-link material (world-space triplanar tile, both sides).
func _chain_key() -> String:
	var k: String = "chainlink"
	if not SchoolGeo._mats.has(k):
		var px: int = 32
		var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for i: int in px:
			var j: int = mini(i + 1, px - 1)
			for q: Vector2i in [Vector2i(i, i), Vector2i(j, i), Vector2i(i, px - 1 - i), Vector2i(j, px - 1 - i)]:
				img.set_pixelv(q, Color(1, 1, 1, 1))
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.albedo_color = Color(0.78, 0.84, 0.9, 1.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(2.0, 2.0, 2.0)
		m.roughness = 0.6
		SchoolGeo._mats[k] = m
		SchoolGeo._no_shadow[k] = true
	return k


## Dashed centre lines on the road round the campus, a crosswalk at the front gate, kerbs and street lamps (merged
## poles and heads, glowing bulbs, light pools; no real lights).
func road_markings(b: Rect2) -> void:
	var yellow: String = SchoolGeo.glow(Color("d9b13a"))
	var white: String = SchoolGeo.glow(Color("d8d6d0"))
	var c: float = 11.0  # road centre, outside the bounds
	var lines: Array = [
		[Vector3(b.position.x - c, 0.0, b.end.y + c), Vector3(b.end.x + c, 0.0, b.end.y + c)],
		[Vector3(b.position.x - c, 0.0, b.position.y - c), Vector3(b.end.x + c, 0.0, b.position.y - c)],
		[Vector3(b.position.x - c, 0.0, b.position.y - c), Vector3(b.position.x - c, 0.0, b.end.y + c)],
		[Vector3(b.end.x + c, 0.0, b.position.y - c), Vector3(b.end.x + c, 0.0, b.end.y + c)],
	]
	for l: Array in lines:
		var a: Vector3 = l[0]
		var e: Vector3 = l[1]
		var len: float = a.distance_to(e)
		var n: int = int(len / 6.0)
		for k: int in n:
			var t0: float = (float(k) * 6.0 + 1.5) / len
			var t1: float = (float(k) * 6.0 + 4.5) / len
			if t1 > 0.97 or t0 < 0.03:
				continue
			geo.strip(a.lerp(e, t0), a.lerp(e, t1), 0.16, yellow, 0.02)
	# crosswalk at the front gate
	for k: int in 8:
		var x: float = -7.0 + float(k) * 1.9
		geo.strip(Vector3(x, 0.0, b.end.y + 4.0), Vector3(x, 0.0, b.end.y + 18.0), 0.9, white, 0.02)
	# kerbs between the sidewalks and the road (visual: outside the riding area)
	var kerb: String = SchoolGeo.toon(Color("cfc8bb"))
	for d: float in [3.5, 18.5]:
		var r: Rect2 = b.grow(d)
		geo.vbox(Vector3(r.position.x, 0.0, r.position.y - 0.15), Vector3(r.size.x, 0.12, 0.3), kerb)
		geo.vbox(Vector3(r.position.x, 0.0, r.end.y - 0.15), Vector3(r.size.x, 0.12, 0.3), kerb)
		geo.vbox(Vector3(r.position.x - 0.15, 0.0, r.position.y), Vector3(0.3, 0.12, r.size.y), kerb)
		geo.vbox(Vector3(r.end.x - 0.15, 0.0, r.position.y), Vector3(0.3, 0.12, r.size.y), kerb)
	# street lamps on the far sidewalk, every STREET_LAMP_STEP metres
	var pole: String = SchoolGeo.toon(Color("4a4f5c"))
	var bulb: String = SchoolGeo.glow(Color(lamp_colour.r * 2.0, lamp_colour.g * 1.85, lamp_colour.b * 1.5))
	var r2: Rect2 = b.grow(20.2)
	var sides: Array = [[Vector3(r2.position.x, 0, r2.end.y), Vector3(r2.end.x, 0, r2.end.y), Vector3(0, 0, -1)],
			[Vector3(r2.position.x, 0, r2.position.y), Vector3(r2.end.x, 0, r2.position.y), Vector3(0, 0, 1)],
			[Vector3(r2.position.x, 0, r2.position.y), Vector3(r2.position.x, 0, r2.end.y), Vector3(1, 0, 0)],
			[Vector3(r2.end.x, 0, r2.position.y), Vector3(r2.end.x, 0, r2.end.y), Vector3(-1, 0, 0)]]
	for sd: Array in sides:
		var a: Vector3 = sd[0]
		var e: Vector3 = sd[1]
		var arm: Vector3 = sd[2]
		var n: int = int(a.distance_to(e) / STREET_LAMP_STEP)
		for k: int in n:
			var p: Vector3 = a.lerp(e, (float(k) + 0.5) / float(n))
			geo.cyl(p, p + Vector3(0.0, 7.0, 0.0), 0.09, pole, 6)
			geo.cyl(p + Vector3(0.0, 6.9, 0.0), p + Vector3(0.0, 6.9, 0.0) + arm * 1.6, 0.05, pole, 4)
			var hp: Vector3 = p + arm * 1.8 + Vector3(0.0, 6.85, 0.0)
			geo.obox(Transform3D(Basis.IDENTITY, hp), Vector3(0.5, 0.16, 0.5), pole, false)
			geo.obox(Transform3D(Basis.IDENTITY, hp - Vector3(0.0, 0.1, 0.0)), Vector3(0.4, 0.04, 0.4), bulb, false)
			geo.pool(hp * Vector3(1, 0, 1) + Vector3(0.0, 0.03, 0.0), 6.5, lamp_colour, 0.42)


## The perimeter traffic: a loop each way round the campus on the outside road (outside the riding area, so the cars
## never reach the skate lines), headlights on for dusk.
func traffic(b: Rect2) -> void:
	var t := Traffic.new()
	t.name = "Traffic"
	t.lights_mode = 1
	t.seed_value = 41
	level.add_child(t)
	var loop_r: Rect2 = b.grow(11.0)
	var cw: LanePath = LanePath.block_loop(loop_r, 0.0, 12.0, true).offset(2.0)
	var ccw: LanePath = LanePath.block_loop(loop_r, 0.0, 12.0, false).offset(2.0)
	t.add_cars(t.add_lane(cw, 11.0), 6)
	t.add_cars(t.add_lane(ccw, 10.0), 5)


# --- people -------------------------------------------------------------------------------------------------

## Students crossing the plaza and the courtyard, a group by the flagpole, joggers on the track, the janitor pushing
## his cart along the balcony, a few people on the sidewalks outside.
func people() -> void:
	var crowd := Pedestrians.new()
	crowd.name = "Pedestrians"
	crowd.seed_value = 12
	level.add_child(crowd)
	# eight people in all (each costs about 50 draw calls, twice that with its shadow): the front plaza has one walking in from the gate, two by the
	# flagpole and one on the terrace
	crowd.add_walkers(LanePath.from_points(PackedVector3Array([Vector3(-19.0, 0.0, 82.0), Vector3(-19.0, 0.0, 50.0), Vector3(-26.0, 0.0, 40.0)]), false, 2.0), 1)
	crowd.add_group(Vector3(-27.0, 0.0, 49.0), 2)
	crowd.add_idler(Vector3(10.0, SchoolLevel.TERRACE_Y, 25.5), PI, "phone")
	var court := PackedVector3Array([Vector3(-40.0, 0.0, -38.0), Vector3(-9.0, 0.0, -38.0), Vector3(-9.0, 0.0, -20.0), Vector3(-40.0, 0.0, -20.0)])
	crowd.add_walkers(LanePath.from_points(court, true, 2.5), 1)
	# the janitor and his cart, slowly along under the balcony
	var jan: Array[Pedestrian] = crowd.add_walkers(LanePath.from_points(PackedVector3Array([Vector3(-58.0, 0.0, -8.0), Vector3(-22.0, 0.0, -8.0)]), false, 1.0), 1, 0.7, 0.8)
	for j: Pedestrian in jan:
		j.add_child(_janitor_cart())
	# a jogger on the track
	var cz: float = -73.0
	var y: float = SchoolLevel.FIELD_Y
	var track := PackedVector3Array([Vector3(-70.0, y, cz - 12.2), Vector3(24.0, y, cz - 12.2), Vector3(24.0, y, cz + 12.2), Vector3(-70.0, y, cz + 12.2)])
	crowd.add_walkers(LanePath.from_points(track, true, 11.5), 1, 2.4, 2.9)
	# outside the fence, on the north sidewalk behind the field
	var b: Rect2 = SchoolLevel.BOUNDS
	crowd.add_walkers(LanePath.from_points(PackedVector3Array([Vector3(-80.0, 0.0, b.position.y - 1.8), Vector3(80.0, 0.0, b.position.y - 1.8)]), false, 2.0), 1)
	var lod := SchoolShadowLod.new()
	lod.name = "CrowdShadowLod"
	lod.crowd = crowd
	level.add_child(lod)


## A janitor's cart: a grey bin on wheels with a yellow mop bucket, pushed in front (Pedestrians face -Z).
static func _janitor_cart() -> Node3D:
	var root := Node3D.new()
	root.name = "JanitorCart"
	var parts: Array = [
		[Vector3(0.0, 0.55, -0.95), Vector3(0.55, 0.7, 0.8), Color("6c7480")],
		[Vector3(0.0, 0.92, -0.95), Vector3(0.6, 0.06, 0.85), Color("3b3f4c")],
		[Vector3(0.0, 0.32, -1.6), Vector3(0.5, 0.36, 0.45), Color("f2c230")],
		[Vector3(0.0, 0.08, -1.2), Vector3(0.6, 0.1, 1.4), Color("2a2d34")],
	]
	for p: Array in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[1] as Vector3
		mi.mesh = bm
		mi.position = p[0] as Vector3
		mi.material_override = Toon.material(p[2] as Color, false)
		root.add_child(mi)
	var mop := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	cm.height = 1.4
	mop.mesh = cm
	mop.position = Vector3(0.12, 0.9, -1.6)
	mop.rotation_degrees = Vector3(12.0, 0.0, 8.0)
	mop.material_override = Toon.material(Color("b77a45"), false)
	root.add_child(mop)
	return root


# --- finish ---------------------------------------------------------------------------------------------

## Campus lamps along the main paths, then the trees, people, the lamp controller and the merged dressing geometry.
func finish() -> void:
	var lamp_spots: Array = [
		[Vector3(-14.0, 0.0, 47.0), 0.0], [Vector3(14.0, 0.0, 47.0), 0.0], [Vector3(-14.0, 0.0, 66.0), PI], [Vector3(14.0, 0.0, 66.0), PI],
		[Vector3(-21.0, 0.0, 64.0), -PI * 0.5], [Vector3(-46.0, 0.0, -46.0), PI], [Vector3(-12.0, 0.0, -46.0), PI],
		[Vector3(10.0, 0.0, -8.0), 0.0], [Vector3(30.0, 0.0, -46.0), PI], [Vector3(46.0, 0.0, -30.0), PI * 0.5],
		[Vector3(58.0, 0.0, -10.0), PI * 0.5], [Vector3(39.0, 0.0, 44.0), -PI * 0.5], [Vector3(-80.0, 0.0, 30.0), PI],
		[Vector3(-30.0, 0.0, -14.0), 0.0],
	]
	var k: int = 0
	for s: Array in lamp_spots:
		lamp(s[0] as Vector3, float(s[1]), 100 + k * 7, 6.5, k in REAL_LAMPS)
		k += 1
	for s: Array in _lamp_spots:
		if bool(s[4]) and lamps.size() < MAX_LAMP_LIGHTS:
			var f: FlickerLight = FlickerLight.sodium_lamp(float(s[3]), false, lamp_colour, int(s[2]))
			f.position = s[0] as Vector3
			f.rotation.y = float(s[1])
			level.add_child(f)
			lamps.append(f)
		else:
			_static_lamp(s[0] as Vector3, float(s[1]), float(s[3]))
	_build_bins()
	var ctl := SchoolLamps.new()
	ctl.name = "LampsOn"
	ctl.lamps = lamps
	level.add_child(ctl)
	level.add_child(trees)
	people()
	geo.commit()


func _cyl_solid(pos: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	cs.position = pos + Vector3(0.0, h * 0.5, 0.0)
	body.add_child(cs)
