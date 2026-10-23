class_name HillsLife
extends Node3D
## The Hills' small moving things that the world kit does not have: lawn sprinklers (ticking impulse sprinklers
## throwing a sweeping arc of spray), dogs on leads trotting beside their walkers, the school zone's flashing beacons,
## and cars pitched to the slope of the street they drive (Traffic keeps cars level; this runs after it each tick and
## tips each car's body to its lane's grade).

const SPRAY := Color(0.86, 0.95, 1.0, 0.55)

var traffic: Traffic = null
var crowd: Pedestrians = null
## People further than this from the camera are hidden (the hillside sees a long way: this keeps the crowd inside the
## primitive budget; the crowd's own LOD hides them only past 150 m).
var people_range: float = 50.0
## People cast shadows only this close to the camera (each shadow split draws every part of a person again).
var shadow_range: float = 16.0
var _shadow_on: Dictionary = {}  ## Pedestrian -> [shadow on: bool, part count when last set]
var _sprinklers: Array[Dictionary] = []  ## {node: CPUParticles3D, base: float, sweep: float, rate: float, t: float}
var _dogs: Array[Dictionary] = []  ## {dog: Node3D, legs: Array, tail: Node3D, leash: MeshInstance3D, owner: Pedestrian, side: float, phase: float, prev: Vector3}
var _beacons: Array = []  ## [mat_a, mat_b]
var _blinkers: Array[StandardMaterial3D] = []  ## slow red aircraft-warning lamps
var _t: float = 0.0
static var _drop_tex: GradientTexture2D = null


func _ready() -> void:
	process_physics_priority = 100
	process_priority = 100  # after the crowd's own LOD pass


func _physics_process(_delta: float) -> void:
	if traffic == null:
		return
	for car: TrafficCar in traffic.cars:
		var path: LanePath = traffic.lanes[car.lane]
		var t: Vector3 = path.tangent(car.s, 3.0)
		car.model.rotation.x += asin(clampf(t.y, -0.5, 0.5))


func _process(delta: float) -> void:
	_t += delta
	if crowd != null:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null:
			var eye: Vector3 = cam.global_position
			for p: Pedestrian in crowd.people:
				var d: float = p.global_position.distance_to(eye)
				if p.visible and d > people_range:
					p.visible = false
				if p.visible:
					_person_shadow(p, d < shadow_range)
	for s: Dictionary in _sprinklers:
		var p: CPUParticles3D = s["node"]
		s["t"] = float(s["t"]) + delta
		# an impulse sprinkler: ticks across its arc, then sweeps back fast
		var cycle: float = 6.0
		var u: float = fposmod(float(s["t"]), cycle) / cycle
		var f: float = u / 0.85 if u < 0.85 else 1.0 - (u - 0.85) / 0.15
		var ang: float = float(s["base"]) + (f - 0.5) * float(s["sweep"])
		p.direction = Vector3(sin(ang), 0.9, cos(ang))
	var flash: bool = fposmod(_t, 1.0) < 0.5
	for b: Array in _beacons:
		(b[0] as StandardMaterial3D).emission_energy_multiplier = 3.0 if flash else 0.15
		(b[1] as StandardMaterial3D).emission_energy_multiplier = 0.15 if flash else 3.0
	var blink: bool = fposmod(_t, 2.4) < 0.5
	for m: StandardMaterial3D in _blinkers:
		m.emission_energy_multiplier = 4.0 if blink else 0.2
	for d: Dictionary in _dogs:
		_step_dog(d, delta)


func _person_shadow(p: Pedestrian, on: bool) -> void:
	var n: int = p.get_child_count()
	var st: Array = _shadow_on.get(p, [true, -1])
	if bool(st[0]) == on and int(st[1]) == n:
		return
	var mode: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for g: Node in p.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = mode
	_shadow_on[p] = [on, n]


# --- sprinklers ----------------------------------------------------------------------------------------------------

## A lawn sprinkler at `pos` sweeping `sweep` radians round `base` (yaw of the middle of the arc).
func add_sprinkler(pos: Vector3, base: float, sweep: float = 2.2, seed_t: float = 0.0) -> void:
	var head := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.07
	cm.height = 0.18
	cm.radial_segments = 6
	head.mesh = cm
	head.material_override = Toon.material(Color("3a3f48"), false)
	head.position = pos + Vector3(0.0, 0.09, 0.0)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(head)
	var p := CPUParticles3D.new()
	p.name = "Sprinkler"
	p.amount = 90
	p.lifetime = 1.3
	p.preprocess = 1.3
	p.position = pos + Vector3(0.0, 0.2, 0.0)
	p.direction = Vector3(0.0, 0.9, 1.0)
	p.spread = 4.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 7.5
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, SPRAY)
	ramp.set_color(1, Color(SPRAY.r, SPRAY.g, SPRAY.b, 0.0))
	p.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = HillsLife._drop()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	_sprinklers.append({"node": p, "base": base, "sweep": sweep, "t": seed_t})


static func _drop() -> GradientTexture2D:
	if _drop_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_drop_tex = GradientTexture2D.new()
		_drop_tex.gradient = g
		_drop_tex.fill = GradientTexture2D.FILL_RADIAL
		_drop_tex.fill_from = Vector2(0.5, 0.5)
		_drop_tex.fill_to = Vector2(1.0, 0.5)
		_drop_tex.width = 32
		_drop_tex.height = 32
	return _drop_tex


func add_beacon_lamps(mats: Array) -> void:
	_beacons.append(mats)


func add_blinker(mat: StandardMaterial3D) -> void:
	_blinkers.append(mat)


# --- dogs ----------------------------------------------------------------------------------------------------------

## A dog on a lead trotting beside walker `who` (on its `side`: -1 left, +1 right). `size` 0.7 small .. 1.2 big.
func add_dog(who: Pedestrian, coat: Color, size: float = 1.0, side: float = 1.0) -> void:
	var dog := Node3D.new()
	dog.name = "Dog"
	dog.scale = Vector3.ONE * size
	var coat_m: Material = Toon.material(coat, false)
	var dark_m: Material = Toon.material(coat.darkened(0.35), false)
	var body := HillsLife._part(Vector3(0.22, 0.22, 0.55), coat_m, Vector3(0.0, 0.42, 0.0))
	dog.add_child(body)
	dog.add_child(HillsLife._part(Vector3(0.18, 0.18, 0.22), coat_m, Vector3(0.0, 0.6, -0.36)))  # head
	dog.add_child(HillsLife._part(Vector3(0.11, 0.09, 0.14), dark_m, Vector3(0.0, 0.55, -0.52)))  # snout
	for sx: float in [-1.0, 1.0]:
		var ear := HillsLife._part(Vector3(0.05, 0.12, 0.06), dark_m, Vector3(sx * 0.08, 0.72, -0.33))
		ear.rotation.z = sx * 0.3
		dog.add_child(ear)
	var legs: Array = []
	for lz: float in [-0.2, 0.2]:
		for sx: float in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(sx * 0.08, 0.36, lz)
			hip.add_child(HillsLife._part(Vector3(0.06, 0.34, 0.06), dark_m if lz > 0.0 else coat_m, Vector3(0.0, -0.17, 0.0)))
			dog.add_child(hip)
			legs.append(hip)
	var tail := Node3D.new()
	tail.position = Vector3(0.0, 0.5, 0.28)
	var tp: MeshInstance3D = HillsLife._part(Vector3(0.04, 0.04, 0.22), coat_m, Vector3(0.0, 0.06, 0.1))
	tp.rotation.x = 0.6
	tail.add_child(tp)
	dog.add_child(tail)
	add_child(dog)
	var leash := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.015, 0.015, 1.0)
	leash.mesh = lm
	leash.material_override = Toon.material(Color("c0392b"), false)
	leash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(leash)
	_dogs.append({"dog": dog, "legs": legs, "tail": tail, "leash": leash, "owner": who, "side": side, "phase": 0.0, "prev": who.global_position, "size": size})


static func _part(size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _step_dog(d: Dictionary, delta: float) -> void:
	var who: Pedestrian = d["owner"]
	if not is_instance_valid(who):
		return
	var dog: Node3D = d["dog"]
	dog.visible = who.visible
	var fwd: Vector3 = -who.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right: Vector3 = fwd.cross(Vector3.UP)
	var moved: float = (who.global_position - (d["prev"] as Vector3)).length()
	d["prev"] = who.global_position
	var speed: float = moved / maxf(delta, 0.0001)
	# a little ahead and to the side, sniffing about
	var wander: float = sin(_t * 0.7 + float(d["side"]) * 2.0) * 0.25
	var want: Vector3 = who.global_position + fwd * 0.9 + right * float(d["side"]) * (0.75 + wander)
	dog.global_position = dog.global_position.lerp(want, clampf(delta * 4.0, 0.0, 1.0)) if dog.global_position != Vector3.ZERO else want
	dog.global_position.y = who.global_position.y
	var yaw: float = atan2(-fwd.x, -fwd.z)
	dog.rotation.y = lerp_angle(dog.rotation.y, yaw, clampf(delta * 6.0, 0.0, 1.0))
	d["phase"] = float(d["phase"]) + delta * clampf(speed, 0.0, 3.0) * 4.5 / float(d["size"])
	var ph: float = float(d["phase"])
	var legs: Array = d["legs"]
	var swing: float = 0.55 * clampf(speed / 1.2, 0.0, 1.0)
	for i: int in legs.size():
		(legs[i] as Node3D).rotation.x = sin(ph + (PI if i == 1 or i == 2 else 0.0)) * swing
	(d["tail"] as Node3D).rotation.y = sin(_t * 9.0) * 0.6
	# the lead: from the walker's hand to the collar
	var hand: Vector3 = who.global_position + right * float(d["side"]) * 0.3 + Vector3(0.0, 0.85, 0.0) + fwd * 0.15
	var collar: Vector3 = dog.global_position + Vector3(0.0, 0.6 * float(d["size"]), 0.0) - fwd * 0.0 + fwd * 0.3 * float(d["size"])
	var leash: MeshInstance3D = d["leash"]
	var span: Vector3 = collar - hand
	var l: float = maxf(span.length(), 0.05)
	leash.visible = dog.visible
	leash.global_transform = Transform3D(Basis.looking_at(span / l, Vector3.UP) * Basis.from_scale(Vector3(1.0, 1.0, l)), (hand + collar) * 0.5)
