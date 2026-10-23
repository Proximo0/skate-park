class_name WhWorld
extends Node3D
## The world round the Creepy Warehouse and the life in it: the moonlit city skyline to the north (one fog-free mesh
## with its own window shader and haze), the elevated highway behind the rail spur with traffic running into tunnel
## portals at both ends, a frontage road south of the truck court, the night watchman on his round with a flashlight,
## a few skaters by the burn barrel, bats in the rafters and crows round the crane and the smokestack, rats scurrying
## along the walls (driven here), steam, dripping roof leaks and puddles.
## North is -Z. The highway deck is at HWY_Y, centred on HWY_Z, well outside the fence (no collision needed there).

const FL: float = WarehouseLevel.FL
const HWY_Z: float = -128.0
const HWY_Y: float = 12.0
const HWY_W: float = 17.0
const HWY_HALF: float = 230.0  ## deck runs x -HWY_HALF..HWY_HALF, into portals
const ROAD_Z: float = 90.0
const SKYLINE: Shader = preload("res://game/levels/warehouse/wh_skyline.gdshader")
const RAT_SPEED: float = 2.6
const RAT_SCARE: float = 5.0

## [from, to] runs the rats scurry along (wall bases, dock faces, the buffer stop).
const RAT_RUNS: Array = [
	[Vector3(30.0, FL, 19.55), Vector3(36.5, FL, 19.55)],
	[Vector3(-4.0, FL, -19.6), Vector3(4.0, FL, -19.6)],
	[Vector3(39.6, FL, -15.0), Vector3(39.6, FL, -9.5)],
	[Vector3(-37.0, FL, 1.0), Vector3(-37.0, FL, 4.5)],
	[Vector3(-17.0, 0.0, 26.35), Vector3(-11.0, 0.0, 26.35)],
	[Vector3(44.0, 0.0, -33.8), Vector3(49.0, 0.0, -33.8)],
	[Vector3(-70.0, 0.0, 12.0), Vector3(-64.0, 0.0, 12.0)],
	[Vector3(52.5, 0.0, 30.0), Vector3(52.5, 0.0, 22.0)],
]

var guard: Pedestrian = null
var traffic: Traffic = null
var crowd: Pedestrians = null
var _rats: MultiMeshInstance3D = null
var _rat_state: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _crowd_baked: bool = false
var _sky_mat: ShaderMaterial = null  ## the skyline's window material (fog-free, own haze)


static func build(lvl: WarehouseLevel) -> WhWorld:
	var w := WhWorld.new()
	w.name = "World"
	lvl.add_child(w)
	w._rng.seed = 404
	w._skyline()
	w._highway()
	w._frontage()
	w._people()
	w._critters()
	w._weather()
	lvl.traffic = w.traffic
	lvl.crowd = w.crowd
	return w


func _process(delta: float) -> void:
	if not _crowd_baked and crowd != null and crowd.is_loaded():
		# the moon is low and the yards are lamp-lit: people skip the shadow pass (about 20 draw calls each)
		_crowd_baked = true
		for n: Node in crowd.find_children("*", "GeometryInstance3D", true, false):
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_step_rats(delta)


# ---------------------------------------------------------------------------------------------------------- skyline

## City blocks in rows 220 to 600 m north (towers, a few landmarks with antenna beacons) and low industrial blocks
## to the east, west and south, all one fog-free mesh with the window shader.
func _skyline() -> void:
	var m := ShaderMaterial.new()
	m.shader = SKYLINE
	m.set_shader_parameter("moon_dir", WarehouseLevel.MOON_DIR)
	_sky_mat = m
	var far := ShaderMaterial.new()
	far.shader = SKYLINE
	far.set_shader_parameter("moon_dir", WarehouseLevel.MOON_DIR)
	far.set_shader_parameter("wall", Color(0.06, 0.07, 0.12))
	far.set_shader_parameter("lit_share", 0.12)
	var bt := WhGeo.Batch.new(0.0, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313
	var beacons: Array[Vector3] = []
	# downtown: three rows, taller toward the middle (a skyline peak a little east of the hall's axis)
	var rows: Array = [[-230.0, 40.0, 26.0, 55.0], [-330.0, 46.0, 40.0, 95.0], [-470.0, 60.0, 50.0, 140.0]]
	for row: Array in rows:
		var z0: float = float(row[0])
		var x: float = -560.0
		while x < 560.0:
			var w: float = rng.randf_range(16.0, float(row[1]))
			var d: float = rng.randf_range(16.0, 34.0)
			var peak: float = exp(-pow((x - 60.0) / 240.0, 2.0))
			var h: float = rng.randf_range(float(row[2]) * 0.4, float(row[2])) + float(row[3]) * peak * rng.randf_range(0.5, 1.1)
			var z: float = z0 - rng.randf_range(0.0, 40.0)
			if rng.randf() < 0.82:
				var c := Vector3(x + w * 0.5, h * 0.5 - 2.0, z)
				bt.box(c, Vector3(w, h + 4.0, d), m)
				# set-back crowns on the tall ones
				if h > 60.0:
					var h2: float = h * rng.randf_range(0.12, 0.3)
					bt.box(Vector3(c.x, h + h2 * 0.5, z), Vector3(w * 0.66, h2, d * 0.66), m)
					if rng.randf() < 0.6:
						beacons.append(Vector3(c.x, h + h2 + 6.0, z))
						bt.box(Vector3(c.x, h + h2 + 3.0, z), Vector3(0.6, 6.0, 0.6), m)
			x += w + rng.randf_range(2.0, 14.0)
	# one landmark: a slim spire tower
	bt.box(Vector3(110.0, 85.0, -400.0), Vector3(30.0, 170.0, 30.0), far)
	bt.box(Vector3(110.0, 185.0, -400.0), Vector3(18.0, 30.0, 18.0), far)
	bt.box(Vector3(110.0, 215.0, -400.0), Vector3(1.2, 30.0, 1.2), far)
	beacons.append(Vector3(110.0, 231.0, -400.0))
	# low industrial blocks round the other three sides (beyond the fence and the frontage road)
	for side: int in 3:
		var n: int = 16
		for i: int in n:
			var t: float = (float(i) + rng.randf()) / float(n)
			var w: float = rng.randf_range(22.0, 50.0)
			var h: float = rng.randf_range(10.0, 26.0)
			var c := Vector3.ZERO
			var size := Vector3(w, h + 2.0, rng.randf_range(20.0, 40.0))
			if side == 0:
				c = Vector3(lerpf(-420.0, 420.0, t), h * 0.5 - 1.0, rng.randf_range(200.0, 300.0))
			elif side == 1:
				c = Vector3(rng.randf_range(260.0, 340.0), h * 0.5 - 1.0, lerpf(-200.0, 200.0, t))
				size = Vector3(size.z, size.y, size.x)
			else:
				c = Vector3(rng.randf_range(-340.0, -260.0), h * 0.5 - 1.0, lerpf(-200.0, 200.0, t))
				size = Vector3(size.z, size.y, size.x)
			bt.box(c, size, far)
			if rng.randf() < 0.3:
				var sx: float = c.x + rng.randf_range(-w * 0.3, w * 0.3)
				bt.box(Vector3(sx, h + 12.0, c.z), Vector3(2.4, 26.0, 2.4), far)
	var root: Node3D = bt.commit(self, "Skyline")
	for mi: Node in root.get_children():
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as GeometryInstance3D).extra_cull_margin = 0.0
	# red aviation beacons, blinking out of step
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.disable_fog = true
	red.albedo_color = Color(2.6, 0.25, 0.2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var s := SphereMesh.new()
	s.radius = 1.4
	s.height = 2.8
	s.radial_segments = 8
	s.rings = 4
	s.material = red
	mm.mesh = s
	mm.instance_count = beacons.size()
	for i: int in beacons.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, beacons[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Beacons"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	WhLights.blink(mmi, red, 2.2, 0.35)


# ---------------------------------------------------------------------------------------------------------- highway

## The elevated highway: a deck on hammerhead piers, parapets, sodium lamps (glow only), a green sign gantry, and the
## tunnel portals at both ends that hide where the traffic loop turns round.
func _highway() -> void:
	var bt := WhGeo.Batch.new(80.0, false)
	var conc := WhGeo.mat("concrete", Color("5d6068"), 0.3, 0.7)
	var dark := WhGeo.mat("concrete", Color("3b3e46"), 0.3, 0.8)
	var steel := WhGeo.mat("metal", Color("3c4048"), 0.5, 0.5)
	var z0: float = HWY_Z - HWY_W * 0.5
	var z1: float = HWY_Z + HWY_W * 0.5
	# deck slab and girder fascia
	bt.box_min(Vector3(-HWY_HALF, HWY_Y - 1.6, z0), Vector3(HWY_HALF * 2.0, 1.6, HWY_W), dark)
	bt.box_min(Vector3(-HWY_HALF, HWY_Y - 0.02, z0), Vector3(HWY_HALF * 2.0, 0.02, HWY_W), WhGeo.mat("floor", Color("2c2e33"), 0.1, 0.6))
	# parapets
	for z: float in [z0, z1 - 0.4]:
		bt.box_min(Vector3(-HWY_HALF, HWY_Y, z), Vector3(HWY_HALF * 2.0, 1.1, 0.4), conc)
	# median barrier
	bt.box_min(Vector3(-HWY_HALF, HWY_Y, HWY_Z - 0.3), Vector3(HWY_HALF * 2.0, 0.85, 0.6), conc)
	# piers every 32 m
	var x: float = -HWY_HALF + 16.0
	while x < HWY_HALF:
		bt.box_min(Vector3(x - 1.1, -1.0, HWY_Z - 1.6), Vector3(2.2, HWY_Y - 1.6 + 1.0, 3.2), conc)
		bt.box_min(Vector3(x - 1.4, HWY_Y - 2.8, z0 + 0.5), Vector3(2.8, 1.2, HWY_W - 1.0), conc)
		x += 32.0
	# lamps every 24 m on the north parapet, leaning over the road, and on the south one offset by half
	var bulb: StandardMaterial3D = WhGeo.glow(Color(2.2, 1.35, 0.55), false, true)
	x = -HWY_HALF + 6.0
	var k: int = 0
	while x < HWY_HALF:
		var south: bool = k % 2 == 1
		var zp: float = z1 - 0.2 if south else z0 + 0.2
		var arm: float = -2.4 if south else 2.4
		bt.pipe(Vector3(x, HWY_Y + 1.1, zp), Vector3(x, HWY_Y + 9.0, zp), 0.14, steel, 6)
		bt.pipe(Vector3(x, HWY_Y + 9.0, zp), Vector3(x, HWY_Y + 9.2, zp + arm), 0.1, steel, 6)
		bt.box(Vector3(x, HWY_Y + 9.05, zp + arm), Vector3(0.5, 0.18, 0.9), bulb)
		x += 24.0
		k += 1
	# a sign gantry over the eastbound lanes
	var green := WhGeo.mat("paint", Color("1f6b45"), 0.2, 0.3)
	bt.pipe(Vector3(40.0, HWY_Y, z1 - 0.2), Vector3(40.0, HWY_Y + 7.5, z1 - 0.2), 0.25, steel, 6)
	bt.pipe(Vector3(40.0, HWY_Y + 7.5, z1 - 0.2), Vector3(40.0, HWY_Y + 7.5, HWY_Z), 0.2, steel, 6)
	bt.box(Vector3(40.0, HWY_Y + 6.2, HWY_Z + 4.4), Vector3(0.2, 2.2, 6.4), green)  # hangs just under the gantry beam
	var sign := Label3D.new()
	sign.text = "EXIT 14\nNOX DOCKS"
	sign.font_size = 96
	sign.pixel_size = 0.0085  # two lines, 5.5 m wide: inside the 6.4 x 2.2 m board
	sign.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	sign.modulate = Color(0.95, 0.97, 0.95)
	sign.outline_size = 0
	sign.position = Vector3(40.12, HWY_Y + 6.2, HWY_Z + 4.4)
	sign.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	add_child(sign)
	# tunnel portals: chunky blocks the deck runs into at both ends
	for sx: float in [-1.0, 1.0]:
		var px: float = sx * (HWY_HALF - 18.0)
		bt.box(Vector3(px + sx * 14.0, 16.0, HWY_Z), Vector3(32.0, 36.0, 40.0), _sky_mat)
		bt.box(Vector3(px - sx * 2.2, HWY_Y + 3.0, HWY_Z), Vector3(0.6, 6.0, HWY_W + 2.0), WhGeo.glow(Color(0.02, 0.02, 0.03)))
	bt.commit(self, "Highway")
	# traffic: one loop, eastbound on the south side, westbound on the north, turning inside the portals
	traffic = Traffic.new()
	traffic.name = "Traffic"
	traffic.seed_value = 71
	add_child(traffic)
	var portal_x: float = HWY_HALF - 14.0
	var hw: int = traffic.add_lane(LanePath.block_loop(Rect2(-portal_x, HWY_Z - 4.2, portal_x * 2.0, 8.4), HWY_Y, 4.0, true), 21.0)
	traffic.add_cars(hw, 14, ["hatch", "van", "pickup", "hatch", "pickup"] as Array[String], [Color("b8bcc4"), Color("2a3446"), Color("7a1f22"), Color("d9d4c7"), Color("1d1f24"), Color("ffcc33")] as Array[Color])


## The frontage road south of the truck court (two lanes, a few cars) with dashed centre paint and two blocks that
## hide its ends.
func _frontage() -> void:
	var bt := WhGeo.Batch.new(60.0, false)
	var paint := WhGeo.mat("paint", Color("d8c27a"), 0.2, 0.6)
	var x: float = -196.0
	while x < 196.0:
		bt.box_min(Vector3(x, 0.012, ROAD_Z - 0.08), Vector3(3.0, 0.004, 0.16), paint)
		x += 7.0
	for sx: float in [-1.0, 1.0]:
		bt.box(Vector3(sx * 212.0, 5.0, ROAD_Z + 4.0), Vector3(30.0, 10.0, 26.0), _sky_mat)
	bt.commit(self, "Frontage")
	var lane: int = traffic.add_lane(LanePath.block_loop(Rect2(-205.0, ROAD_Z - 2.0, 410.0, 4.0), 0.0, 1.9, false), 12.0)
	traffic.add_cars(lane, 4, ["pickup", "van", "hatch"] as Array[String], [Color("4b5a3a"), Color("c9ccd1"), Color("3a2a2a"), Color("6c7ea0")] as Array[Color])


# ----------------------------------------------------------------------------------------------------------- people

## Sparse and odd: the night watchman walking the truck court with a flashlight, two skaters hanging at the sofa
## corner by the burn barrel, and a lone figure on the rail dock staring at the trains.
func _people() -> void:
	crowd = Pedestrians.new()
	crowd.name = "Crowd"
	crowd.seed_value = 16  # a seed whose looks are about 20 draw calls each (some hair meshes are 60 surfaces)
	crowd.look_pool = 4
	add_child(crowd)
	var patrol := LanePath.from_points(PackedVector3Array([Vector3(-55.0, 0.0, 57.0), Vector3(-34.0, 0.0, 55.0),
		Vector3(-8.0, 0.0, 55.0), Vector3(14.0, 0.0, 54.0), Vector3(36.0, 0.0, 50.0)]), false, 3.0)
	var g: Array[Pedestrian] = crowd.add_walkers(patrol, 1, 0.85, 0.9)
	guard = g[0]
	guard.name = "Watchman"
	# a uniform that reads at night from across the court: navy shirt and trousers, cap, belt, yellow badge and patches
	guard.look_override = PedBody.guard_look()
	guard.uniform = PedBody.UNIFORM_SECURITY
	_flashlight(guard)
	crowd.add_group(Vector3(-29.6, FL, 16.0), 2)
	crowd.add_idler(Vector3(-2.0, FL, -23.6), PI, "idle")  # on the north rail dock, watching the trains
	# the skaters' boards: one under a foot, one leaning on the barrel
	var deck := WhGeo.mat("paint", Color("2d2d33"), 0.2, 0.2)
	var bt := WhGeo.Batch.new(0.0, false)
	bt.box(Vector3(-29.0, FL + 0.08, 15.3), Vector3(0.21, 0.02, 0.8), deck, WhGeo.yaw(35.0))
	bt.box(Vector3(-27.0, FL + 0.42, 18.1), Vector3(0.21, 0.8, 0.02), deck, Basis(Vector3.RIGHT, 0.25))
	bt.commit(self, "Boards")


## A flashlight in the watchman's hand: a narrow spot (one real light) and a faint beam in the fog.
func _flashlight(p: Pedestrian) -> void:
	var pivot := Node3D.new()
	pivot.name = "Flashlight"
	pivot.position = Vector3(0.22, 1.15, -0.25)
	p.add_child(pivot)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.95, 0.82)
	spot.light_energy = 6.0
	spot.spot_range = 16.0
	spot.spot_angle = 16.0
	spot.spot_attenuation = 0.8
	spot.shadow_enabled = false
	spot.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	pivot.add_child(spot)
	var beam: MeshInstance3D = FlickerLight.beam_cone(7.0, 1.4, Color(1.0, 0.95, 0.8), 0.07)
	var bp := Node3D.new()
	bp.rotation_degrees = Vector3(76.0, 0.0, 0.0)  # the cone hangs down -Y: tip it forward (-Z) and a little down
	bp.add_child(beam)
	pivot.add_child(bp)


# --------------------------------------------------------------------------------------------------------- critters

func _critters() -> void:
	add_child(Birds.flock("bat", 9, Vector3(-6.0, 9.5, 0.0), 13.0, 31))
	add_child(Birds.flock("crow", 8, Vector3(62.0, 22.0, -21.0), 16.0, 32))
	add_child(Birds.flock("crow", 6, Vector3(-88.0, 40.0, -24.0), 10.0, 33))
	add_child(Birds.flock("pigeon", 7, Vector3(-10.0, 18.0, -40.0), 22.0, 34))
	_build_rats()


func _build_rats() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := SphereMesh.new()
	body.radius = 0.5
	body.height = 1.0
	body.radial_segments = 8
	body.rings = 4
	st.append_from(body, 0, Transform3D(Basis.from_scale(Vector3(0.11, 0.08, 0.2)), Vector3(0.0, 0.07, 0.0)))
	st.append_from(body, 0, Transform3D(Basis.from_scale(Vector3(0.07, 0.06, 0.1)), Vector3(0.0, 0.08, -0.12)))
	var tail := CylinderMesh.new()
	tail.top_radius = 0.004
	tail.bottom_radius = 0.012
	tail.height = 0.22
	tail.radial_segments = 4
	tail.rings = 1
	st.append_from(tail, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + 0.2), Vector3(0.0, 0.05, 0.2)))
	var mesh: ArrayMesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("3a3330")
	m.roughness = 0.9
	mesh.surface_set_material(0, m)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = RAT_RUNS.size()
	_rats = MultiMeshInstance3D.new()
	_rats.name = "Rats"
	_rats.multimesh = mm
	_rats.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rats.custom_aabb = AABB(Vector3(-100.0, -2.0, -80.0), Vector3(200.0, 6.0, 160.0))
	add_child(_rats)
	for i: int in RAT_RUNS.size():
		_rat_state.append({"t": _rng.randf(), "dir": 1.0 if _rng.randf() < 0.5 else -1.0, "wait": _rng.randf_range(0.0, 2.0),
			"spd": RAT_SPEED * _rng.randf_range(0.8, 1.2)})
	_step_rats(0.0)


## Each rat dashes along its run, stops, sniffs, turns back; it bolts at double speed when the skater comes close.
func _step_rats(delta: float) -> void:
	if _rats == null:
		return
	var sk: Node3D = null
	if is_inside_tree():
		sk = get_tree().get_first_node_in_group("skater") as Node3D
	for i: int in _rat_state.size():
		var st: Dictionary = _rat_state[i]
		var a: Vector3 = RAT_RUNS[i][0]
		var b: Vector3 = RAT_RUNS[i][1]
		var span: float = maxf(a.distance_to(b), 0.1)
		var t: float = float(st["t"])
		var p: Vector3 = a.lerp(b, t)
		var scared: bool = sk != null and sk.global_position.distance_to(p) < RAT_SCARE
		var wait: float = float(st["wait"])
		if wait > 0.0 and not scared:
			st["wait"] = wait - delta
		else:
			var spd: float = float(st["spd"]) * (2.0 if scared else 1.0)
			t += float(st["dir"]) * spd * delta / span
			if t >= 1.0 or t <= 0.0:
				t = clampf(t, 0.0, 1.0)
				st["dir"] = -float(st["dir"])
				st["wait"] = _rng.randf_range(0.6, 3.5)
			elif _rng.randf() < delta * 0.4:
				st["wait"] = _rng.randf_range(0.3, 1.2)
			st["t"] = t
		p = a.lerp(b, t)
		var fwd: Vector3 = (b - a).normalized() * float(st["dir"])
		var basis := Basis.looking_at(fwd, Vector3.UP)
		_rats.multimesh.set_instance_transform(i, Transform3D(basis, p + Vector3(0.0, 0.004, 0.0)))


# ---------------------------------------------------------------------------------------------------------- weather

## Steam from the boiler yard, a burst pipe in the hall and a grate in the truck court; drips from the broken roof
## with puddles under them.
func _weather() -> void:
	var warm := Color(1.0, 0.86, 0.7, 0.3)
	var cool := Color(0.85, 0.9, 1.0, 0.3)
	var vents: Array = [
		[Vector3(-86.0, 11.0, -46.0), cool, 0.8, 6.0],  # boiler house roof
		[Vector3(-60.0, 1.8, 18.0), warm, 1.2, 3.0],  # pipe run joint
		[Vector3(-88.5, 9.0, 30.0), cool, 0.6, 5.0],  # tank vent
		[Vector3(-36.0, FL + 0.2, -12.0), warm, 1.0, 3.5],  # burst pipe behind the quarter pipe
		[Vector3(18.0, 0.05, 60.0), warm, 0.9, 3.0],  # truck court grate
		[Vector3(-30.0, 0.3, -42.0), cool, 0.7, 4.0],  # under the boxcar
	]
	for v: Array in vents:
		var s: SteamVent = SteamVent.create(v[1] as Color, float(v[2]), float(v[3]))
		s.position = v[0] as Vector3
		add_child(s)
	var leaks: Array[Vector3] = [Vector3(-14.0, FL, 4.5), Vector3(9.0, FL, -6.0), Vector3(31.0, FL, 13.0), Vector3(-34.0, FL, -2.0)]
	var puddle := StandardMaterial3D.new()
	puddle.albedo_color = Color(0.05, 0.06, 0.08, 0.7)
	puddle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puddle.metallic = 0.6
	puddle.roughness = 0.08
	puddle.albedo_texture = FlickerLight.radial_texture()
	for i: int in leaks.size():
		var p: Vector3 = leaks[i]
		var q := MeshInstance3D.new()
		q.name = "Puddle%d" % i
		var pm := QuadMesh.new()
		pm.orientation = PlaneMesh.FACE_Y
		pm.size = Vector2(2.6 + float(i % 2), 1.8 + float(i % 3) * 0.4)
		q.mesh = pm
		q.material_override = puddle
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = p + Vector3(0.0, 0.01, 0.0)
		q.rotation.y = float(i) * 0.9
		add_child(q)
		add_child(_drip(Vector3(p.x, WarehouseLevel.ROOF_Y - 0.3, p.z), p.y))


## Water dripping from the roof at `from` down to `floor_y`: a few thin streaks, one draw call.
func _drip(from: Vector3, floor_y: float) -> CPUParticles3D:
	var d := CPUParticles3D.new()
	d.name = "Drip"
	d.position = from
	d.amount = 5
	d.lifetime = sqrt(2.0 * (from.y - floor_y) / 18.0)
	d.preprocess = d.lifetime
	d.randomness = 0.6
	d.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	d.emission_box_extents = Vector3(0.4, 0.0, 0.4)
	d.direction = Vector3.DOWN
	d.spread = 0.0
	d.initial_velocity_min = 0.0
	d.initial_velocity_max = 0.2
	d.gravity = Vector3(0.0, -18.0, 0.0)
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.35)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_color = Color(0.75, 0.85, 1.0, 0.5)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	d.mesh = q
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.visibility_aabb = AABB(Vector3(-1.0, floor_y - from.y - 1.0, -1.0), Vector3(2.0, from.y - floor_y + 2.0, 2.0))
	return d
