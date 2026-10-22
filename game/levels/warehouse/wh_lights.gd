class_name WhLights
extends RefCounted
## Light for the Creepy Warehouse: sodium lamps hanging from the hall trusses over the lines (two of them failing),
## wall packs over the dock doors, sodium masts in the yards, moonlight shafts through the broken skylights, a burn
## barrel in the skaters' corner, the annex's red work lamp and static on its old TVs. About a dozen real lights are in
## view at a time; floor pools and beams are additive fakes (FlickerLight.light_pool / beam_cone).

const FL: float = WarehouseLevel.FL
const SODIUM := Color("ffa848")
const SODIUM_PALE := Color("ffc070")
const MOON := Color(0.5, 0.62, 0.95)
## Old mercury-vapour wall packs over the dock doors: a cold green-white against the sodium masts.
const MERCURY := Color("cfe6da")
const SHAFT_SHADER: Shader = preload("res://game/levels/warehouse/wh_shaft.gdshader")
const TV_SHADER_CODE: String = """
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform float seed = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453); }
void fragment() {
	float t = floor(TIME * 18.0);
	float n = h(floor(UV * vec2(64.0, 48.0)) + t);
	float roll = smoothstep(0.0, 0.1, abs(fract(UV.y + TIME * 0.3) - 0.5));
	float flick = 0.8 + 0.2 * h(vec2(t, 3.0));
	ALBEDO = vec3(0.55, 0.62, 0.75) * (0.35 + 0.65 * n) * flick * (0.6 + 0.4 * roll);
}
"""

static var _tv_shader: Shader = null


static func build(lvl: WarehouseLevel) -> void:
	var root := Node3D.new()
	root.name = "Lights"
	lvl.add_child(root)
	# hanging sodium lamps over the hall's lines: [x, z, failing, real]. About a dozen real lights are in view from
	# anywhere (FlickerLight); the lamps over open floor keep only their pool and beam (fake).
	var hall: Array = [
		[-28.0, -2.0, false, true], [-18.0, -5.0, true, true], [-8.0, -14.0, false, true], [6.0, -6.0, false, true],
		[19.0, -12.0, false, true], [-14.0, 13.0, false, false], [14.0, 12.0, true, true], [0.0, 2.0, false, false],
		[30.0, 4.0, false, false],
	]
	var i: int = 0
	for h: Array in hall:
		var hl: FlickerLight = _steady(hanging_lamp(Vector3(float(h[0]), FL + 6.4, float(h[1])), bool(h[2]), 10 + i))
		root.add_child(hl if bool(h[3]) else _fake(hl))
		i += 1
	# wall packs over the dock doors (outside), south and north
	for x: float in [-24.0, 0.0, 24.0]:
		root.add_child(_steady(wall_pack(Vector3(x, FL + 6.0, 20.5), 1.0, x == 24.0, 30 + int(x))))
	for x: float in [-24.0, 16.0]:
		root.add_child(_fake(_steady(wall_pack(Vector3(x, FL + 6.0, -20.5), -1.0, false, 40 + int(x)))))
	# sodium masts: truck court, yard, rail spur, boiler yard [x, z, yaw, failing, height]
	var masts: Array = [
		[-18.0, 50.0, 180.0, false, 9.0], [20.0, 54.0, 160.0, false, 9.0], [66.0, 8.0, 90.0, false, 10.0], [67.0, -44.0, 110.0, true, 10.0],
		[86.0, 28.0, 60.0, false, 9.0], [-30.0, -44.0, 0.0, false, 8.0], [30.0, -44.0, 20.0, false, 8.0], [-50.5, -28.0, 70.0, false, 8.0],
		[-62.0, 12.0, -60.0, true, 8.0],
	]
	for m: Array in masts:
		var lamp: FlickerLight = FlickerLight.sodium_lamp(float(m[4]), bool(m[3]), SODIUM, 60 + i)
		lamp.position = Vector3(float(m[0]), 0.0, float(m[1]))
		lamp.rotation_degrees.y = float(m[2])
		lamp.energy = 2.6
		root.add_child(_steady(lamp) if absf(float(m[1]) + 44.0) > 1.0 or bool(m[3]) else _fake(_steady(lamp)))  # rail side: fakes
		i += 1
	# moonlight shafts under every skylight (merged into one shaft mesh and one pool mesh; dust in every other one)
	var d: Vector3 = WarehouseLevel.MOON_DIR.normalized()
	var shafts: Array[MeshInstance3D] = []
	var pools: Array[MeshInstance3D] = []
	var k: int = 0
	for x: float in WhHall.SKYLIGHTS_X:
		for z: float in WhHall.SKYLIGHTS_Z:
			var ms: Node3D = moon_shaft(Rect2(x - 2.0, z - 1.5, 4.0, 3.0), WarehouseLevel.ROOF_Y, FL, d)
			root.add_child(ms)
			shafts.append(ms.get_node("Shaft") as MeshInstance3D)
			pools.append(ms.get_node("LightPool") as MeshInstance3D)
			if k % 2 == 1:
				ms.get_node("Dust").queue_free()
			k += 1
	WhGeo.merge_same(shafts, root, "MoonShafts")
	WhGeo.merge_same(pools, root, "MoonPools")
	# the burn barrel in the skaters' corner
	root.add_child(burn_barrel(Vector3(-27.0, FL + 0.9, 17.5)))
	# the annex's red work lamp
	var red := FlickerLight.new()
	red.name = "AnnexLamp"
	red.failing = true
	red.seed_value = 99
	red.energy = 1.6
	var omni := OmniLight3D.new()
	omni.light_color = Color(1.0, 0.25, 0.18)
	omni.omni_range = 9.0
	omni.light_energy = 1.6
	omni.shadow_enabled = false
	red.add_child(omni)
	red.light = omni
	var bulb := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.12
	bm.height = 0.24
	bulb.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(2.2, 0.4, 0.3)
	bulb.material_override = bmat
	red.add_child(bulb)
	red.add_glow(bmat)
	red.position = Vector3(44.0, FL + 3.6, 12.0)
	var pool: MeshInstance3D = FlickerLight.light_pool(4.0, Color(1.0, 0.3, 0.2), 0.4)
	pool.position = Vector3(44.0, FL + 0.02, 12.5)
	root.add_child(pool)
	red.add_glow(pool.material_override as StandardMaterial3D)
	root.add_child(red)  # after its glows: FlickerLight reads their base colours in _ready
	# lamp poles, arms, heads, shades and cables never change: bake them into merged meshes
	var still: Array[MeshInstance3D] = []
	for f: Node in root.get_children():
		var fl: FlickerLight = f as FlickerLight
		if fl == null:
			continue
		for n: Node in fl.get_children():
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi == null or _is_glow(fl, mi) or str(mi.name).begins_with("LightPool") or str(mi.name).begins_with("Beam"):
				continue
			still.append(mi)
	var bt := WhGeo.Batch.new(48.0, false)
	WhGeo.flatten_list(still, bt)
	bt.commit(root, "LampMeshes")
	# the steady lamps' pools and beams: one merged mesh per colour
	var groups: Dictionary = {}
	for f: Node in root.get_children():
		var fl: FlickerLight = f as FlickerLight
		if fl == null:
			continue
		for n: Node in fl.get_children():
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi == null or _is_glow(fl, mi):
				continue
			var key: String = (mi.material_override as StandardMaterial3D).albedo_color.to_html() + str(n.name)
			if not groups.has(key):
				var fresh: Array[MeshInstance3D] = []
				groups[key] = fresh
			var arr: Array[MeshInstance3D] = groups[key]
			arr.append(mi)
	for key: String in groups:
		WhGeo.merge_same(groups[key] as Array[MeshInstance3D], root, "Steady" + str(key).substr(0, 6))


static func _is_glow(fl: FlickerLight, mi: MeshInstance3D) -> bool:
	var sm: StandardMaterial3D = mi.material_override as StandardMaterial3D
	return sm != null and fl.glow_materials.has(sm)


## A lamp that does not fail only flickers by a few per cent: its floor pool and fog beam stop following it, so the
## build can merge them with every other steady lamp's (call before the lamp enters the tree).
## Drops the real light from a lamp and keeps its bulb, pool and beam (a fake lamp costs no light).
static func _fake(f: FlickerLight) -> FlickerLight:
	if f.light != null:
		f.light.free()
		f.light = null
	return f


static func _steady(f: FlickerLight) -> FlickerLight:
	if f.failing:
		return f
	var keep: Array[StandardMaterial3D] = []
	for n: Node in f.get_children():
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or str(mi.name).begins_with("LightPool") or str(mi.name).begins_with("Beam"):
			continue
		var m: StandardMaterial3D = mi.material_override as StandardMaterial3D
		if m != null and m in f.glow_materials:
			keep.append(m)
	f.glow_materials = keep
	return f


## An enamel shade on a cable from the trusses: a downward spot, its floor pool and a faint beam.
static func hanging_lamp(p: Vector3, failing: bool, seed_v: int) -> FlickerLight:
	var f := FlickerLight.new()
	f.name = "HallLamp"
	f.failing = failing
	f.seed_value = seed_v
	f.energy = 5.0
	f.position = p
	var dark := WhGeo.mat("paint", Color("2f4a3a"), 0.6, 0.0)
	var cable := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var len: float = WarehouseLevel.ROOF_Y - 1.4 - p.y
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = len
	cm.radial_segments = 4
	cable.mesh = cm
	cable.position = Vector3(0, len * 0.5, 0)
	cable.material_override = dark
	f.add_child(cable)
	var shade := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.12
	sm.bottom_radius = 0.48
	sm.height = 0.36
	sm.radial_segments = 14
	sm.cap_bottom = false
	shade.mesh = sm
	shade.material_override = dark
	f.add_child(shade)
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_mat.albedo_color = Color(SODIUM.r * 2.6, SODIUM.g * 2.3, SODIUM.b * 1.8)
	var bulb := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.16
	bs.height = 0.24
	bulb.mesh = bs
	bulb.position = Vector3(0, -0.12, 0)
	bulb.material_override = bulb_mat
	f.add_child(bulb)
	f.add_glow(bulb_mat)
	var spot := SpotLight3D.new()
	spot.light_color = SODIUM
	spot.light_energy = 5.0
	spot.spot_range = 14.0
	spot.spot_angle = 62.0
	spot.spot_attenuation = 0.7
	spot.shadow_enabled = false
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.position = Vector3(0, -0.15, 0)
	f.add_child(spot)
	f.light = spot
	var h: float = p.y - FL
	var pool: MeshInstance3D = FlickerLight.light_pool(h * 1.05, SODIUM, 0.42)
	pool.position = Vector3(0, FL - p.y + 0.03, 0)
	f.add_child(pool)
	f.add_glow(pool.material_override as StandardMaterial3D)
	var beam: MeshInstance3D = FlickerLight.beam_cone(h - 0.2, h * 0.55, SODIUM, 0.05)
	beam.position = Vector3(0, -0.2 - (h - 0.2) * 0.5, 0)
	f.add_child(beam)
	f.add_glow(beam.material_override as StandardMaterial3D)
	return f


## A mercury wall pack over a door (outside face at z = p.z, facing `out` along z): a lit lens and a spot down onto the apron.
static func wall_pack(p: Vector3, out: float, failing: bool, seed_v: int) -> FlickerLight:
	var f := FlickerLight.new()
	f.name = "WallPack"
	f.failing = failing
	f.seed_value = seed_v
	f.energy = 2.0
	f.position = p + Vector3(0, 0, out * 0.25)
	var housing := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.6, 0.45, 0.5)
	housing.mesh = hb
	housing.material_override = WhGeo.mat("paint", Color("3a3d42"), 0.5, 0.0)
	f.add_child(housing)
	var lens_mat := StandardMaterial3D.new()
	lens_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lens_mat.albedo_color = Color(MERCURY.r * 1.8, MERCURY.g * 2.0, MERCURY.b * 1.9)
	var lens := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.46, 0.06, 0.38)
	lens.mesh = lb
	lens.position = Vector3(0, -0.24, 0)
	lens.material_override = lens_mat
	f.add_child(lens)
	f.add_glow(lens_mat)
	var spot := SpotLight3D.new()
	spot.light_color = MERCURY
	spot.light_energy = 2.6
	spot.spot_range = 13.0
	spot.spot_angle = 64.0
	spot.shadow_enabled = false
	spot.rotation_degrees = Vector3(-70.0, 0.0 if out < 0.0 else 180.0, 0.0)
	f.add_child(spot)
	f.light = spot
	var pool: MeshInstance3D = FlickerLight.light_pool(5.5, MERCURY, 0.2)
	pool.position = Vector3(0, FL - p.y + 0.03, out * 3.2)
	f.add_child(pool)
	f.add_glow(pool.material_override as StandardMaterial3D)
	return f


## A slanted prism of moonlight from a roof opening (rect at y = top) down along -dir to the floor at y = bottom.
static func moon_shaft(r: Rect2, top: float, bottom: float, dir: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "MoonShaft"
	var t: float = (top - bottom) / dir.y
	var off: Vector3 = -dir * t
	var c: Array[Vector3] = [Vector3(r.position.x, top, r.position.y), Vector3(r.end.x, top, r.position.y), Vector3(r.end.x, top, r.end.y), Vector3(r.position.x, top, r.end.y)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in 4:
		var a: Vector3 = c[k]
		var b: Vector3 = c[(k + 1) % 4]
		var a2: Vector3 = a + off
		var b2: Vector3 = b + off
		var n: Vector3 = (b - a).cross(off).normalized()
		for v: Array in [[a, Vector2(0, 0)], [b, Vector2(1, 0)], [b2, Vector2(1, 1)], [a, Vector2(0, 0)], [b2, Vector2(1, 1)], [a2, Vector2(0, 1)]]:
			st.set_normal(n)
			st.set_uv(v[1] as Vector2)
			st.add_vertex(v[0] as Vector3)
	# a diagonal sheet through the middle so the shaft has body when seen end-on
	var m0: Vector3 = (c[0] + c[1]) * 0.5
	var m1: Vector3 = (c[3] + c[2]) * 0.5
	var nn: Vector3 = (m1 - m0).cross(off).normalized()
	for v: Array in [[m0, Vector2(0, 0)], [m1, Vector2(1, 0)], [m1 + off, Vector2(1, 1)], [m0, Vector2(0, 0)], [m1 + off, Vector2(1, 1)], [m0 + off, Vector2(0, 1)]]:
		st.set_normal(nn)
		st.set_uv(v[1] as Vector2)
		st.add_vertex(v[0] as Vector3)
	var mi := MeshInstance3D.new()
	mi.name = "Shaft"
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = SHAFT_SHADER
	m.set_shader_parameter("colour", MOON)
	m.set_shader_parameter("strength", 0.14)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	# where it lands: a cool pool on the floor, and dust motes drifting in the light
	var land: Vector3 = Vector3(r.get_center().x, bottom + 0.035, r.get_center().y) + off
	var pool: MeshInstance3D = FlickerLight.light_pool(2.8, MOON, 0.3)
	pool.position = land
	pool.scale = Vector3(1.4, 1.0, 1.15)
	node.add_child(pool)
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 24
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.6, (top - bottom) * 0.4, 1.2)
	dust.position = (c[0] + c[2]) * 0.5 + off * 0.5
	dust.direction = Vector3(0.2, -1.0, 0.1)
	dust.spread = 40.0
	dust.gravity = Vector3(0.0, -0.02, 0.0)
	dust.initial_velocity_min = 0.03
	dust.initial_velocity_max = 0.12
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.albedo_color = Color(0.6, 0.68, 0.9, 0.8)
	dm.disable_fog = true
	dm.albedo_texture = FlickerLight.radial_texture()
	q.material = dm
	dust.mesh = q
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(dust)
	return node


## A drum with a fire in it: flickering orange omni light, flames and sparks.
static func burn_barrel(p: Vector3) -> Node3D:
	var f := FlickerLight.new()
	f.name = "BurnBarrel"
	f.seed_value = 7
	f.energy = 1.8
	f.position = p
	var omni := OmniLight3D.new()
	omni.light_color = Color(1.0, 0.55, 0.22)
	omni.omni_range = 8.0
	omni.light_energy = 1.8
	omni.position = Vector3(0, 0.6, 0)
	omni.shadow_enabled = false
	f.add_child(omni)
	f.light = omni
	var fire := CPUParticles3D.new()
	fire.amount = 20
	fire.lifetime = 0.9
	fire.preprocess = 1.0
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.18
	fire.direction = Vector3.UP
	fire.spread = 15.0
	fire.gravity = Vector3(0, 1.2, 0)
	fire.initial_velocity_min = 0.4
	fire.initial_velocity_max = 0.9
	fire.scale_amount_min = 0.6
	fire.scale_amount_max = 1.1
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	ramp.set_color(1, Color(0.6, 0.1, 0.02, 0.0))
	fire.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.vertex_color_use_as_albedo = true
	fm.albedo_texture = SteamVent.puff_texture()
	fm.disable_fog = true
	q.material = fm
	fire.mesh = q
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(fire)
	var pool: MeshInstance3D = FlickerLight.light_pool(3.6, Color(1.0, 0.5, 0.2), 0.45)
	pool.position = Vector3(0, FL - p.y + 0.03, 0)
	f.add_child(pool)
	f.add_glow(pool.material_override as StandardMaterial3D)
	return f


## Blinks an unshaded material: on for on_frac of every period (seconds).
static func blink(node: Node, m: StandardMaterial3D, period: float, on_frac: float) -> void:
	var on: Color = m.albedo_color
	var off := Color(on.r * 0.08, on.g * 0.08, on.b * 0.08)
	var tw: Tween = node.create_tween().set_loops()
	tw.tween_callback(func() -> void: m.albedo_color = on)
	tw.tween_interval(period * on_frac)
	tw.tween_callback(func() -> void: m.albedo_color = off)
	tw.tween_interval(period * (1.0 - on_frac))


## Gives each screen quad a flickering static material (its own seed) and a faint blue glow on the floor.
static func tv_static(lvl: Node, screens: Array[MeshInstance3D]) -> void:
	if _tv_shader == null:
		_tv_shader = Shader.new()
		_tv_shader.code = TV_SHADER_CODE
	for i: int in screens.size():
		var m := ShaderMaterial.new()
		m.shader = _tv_shader
		m.set_shader_parameter("seed", float(i) * 1.7)
		screens[i].material_override = m
		screens[i].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not screens.is_empty():
		var pool: MeshInstance3D = FlickerLight.light_pool(2.6, Color(0.5, 0.6, 0.9), 0.3)
		pool.position = Vector3(screens[0].position.x + 1.0, FL + 0.03, screens[0].position.z - 1.0)
		lvl.add_child(pool)
