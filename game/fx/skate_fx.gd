class_name SkateFx
extends Node3D
## Cartoon particle effects for the skater: grind sparks, landing puffs, bail stars and the special trail.
## Compatibility renderer: CPUParticles3D only, unshaded vertex-coloured billboards.
## bind(skater) makes this node a child of the skater. Board effects are placed each frame in the skater's
## Visual frame (-Z travel, +Y board up); the landing puff is placed once where it starts.

const SPARK_MAX: int = 24
const SPARK_STEP_SPEED: float = 3.0  ## sparks come in steps of 6 as speed rises past each multiple of this
const TRAIL_AMOUNT: int = 26
const PUFF_RING_COUNT: int = 8
const PUFF_RING_RADIUS: float = 0.22
const STAR_COUNT: int = 4
const STAR_ORBIT_RADIUS: float = 0.45
const STAR_ORBIT_SPEED: float = 3.5  ## radians per second
const STAR_HEIGHT: float = 1.75  ## Visual-local height of the orbit: above the helmet, clear of the face
const STAR_POP_TIME: float = 0.2
const STAR_SIZE: float = 0.24

const SPARK_OFFSET: Vector3 = Vector3(0.0, 0.0, 0.0)  ## under the board, between the trucks
const TRAIL_OFFSET: Vector3 = Vector3(0.0, 0.12, 0.42)  ## board tail
const STAR_OFFSET: Vector3 = Vector3(0.0, 0.0, 0.0)

const STAR_COLOR: Color = Color(1.0, 0.86, 0.15, 1.0)
## Concrete is near white, so the dust is a cool light grey and the sketchy one a warmer tan to stay readable.
const PUFF_CLEAN_COLOR: Color = Color(0.84, 0.87, 0.92, 1.0)
const PUFF_SKETCHY_COLOR: Color = Color(0.8, 0.75, 0.68, 1.0)

var _skater: Skater
var _visual: Node3D
var _built: bool = false
var _sparks: CPUParticles3D
var _trail: CPUParticles3D
var _puff_root: Node3D
var _puffs: Array[CPUParticles3D] = []
var _stars_root: Node3D
var _stars: Array[MeshInstance3D] = []
var _sparks_amount: int = 0
var _orbit_t: float = 0.0
var _star_pop: float = 0.0


## Attaches the effects to the skater and connects to its landed and bailed signals. Safe to call once per skater.
func bind(skater: Skater) -> void:
	_skater = skater
	_visual = skater.get_node_or_null("Visual") as Node3D
	if get_parent() != skater:
		if get_parent() != null:
			get_parent().remove_child(self)
		skater.add_child(self)
	if not _built:
		_build()
	if not skater.landed.is_connected(_on_landed):
		skater.landed.connect(_on_landed)
	if not skater.bailed.is_connected(_on_bailed):
		skater.bailed.connect(_on_bailed)


func _build() -> void:
	_built = true
	var dot: Texture2D = _dot_texture()
	var particle_mat: StandardMaterial3D = _material(dot, BaseMaterial3D.BILLBOARD_PARTICLES, Color.WHITE, true)

	_sparks = _emitter("GrindSparks", _quad(Vector2(0.07, 0.07)),
		_material(null, BaseMaterial3D.BILLBOARD_PARTICLES, Color.WHITE, true), SPARK_MAX, 0.45)
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sparks.emission_box_extents = Vector3(0.08, 0.01, 0.3)
	_sparks.direction = Vector3(0.0, 0.6, 1.0)  ## visual +Z is behind the skater
	_sparks.spread = 22.0
	_sparks.gravity = Vector3(0.0, -9.0, 0.0)
	_sparks.color_ramp = _gradient(
		PackedColorArray([Color(1.0, 1.0, 0.6, 1.0), Color(1.0, 0.6, 0.1, 1.0), Color(1.0, 0.4, 0.05, 0.0)]),
		PackedFloat32Array([0.0, 0.5, 1.0]))

	_trail = _emitter("SpecialTrail", _quad(Vector2(0.14, 0.14)), particle_mat, TRAIL_AMOUNT, 0.55)
	_trail.direction = Vector3.UP
	_trail.spread = 180.0
	_trail.initial_velocity_min = 0.2
	_trail.initial_velocity_max = 0.6
	_trail.gravity = Vector3.ZERO
	_trail.color_initial_ramp = _gradient(_rainbow_colors(), _even_offsets(7))
	_trail.color_ramp = _fade_gradient(Color.WHITE)

	_puff_root = Node3D.new()
	_puff_root.name = "LandingPuffs"
	_puff_root.top_level = true
	add_child(_puff_root)
	for i in range(PUFF_RING_COUNT):
		var a: float = TAU * float(i) / float(PUFF_RING_COUNT)
		var p: CPUParticles3D = _emitter("Puff%d" % i, _quad(Vector2(0.6, 0.6)), particle_mat, 3, 0.6)
		p.one_shot = true
		p.explosiveness = 1.0
		p.emitting = false
		p.direction = Vector3(0.0, 0.3, 1.0)  ## rotated below so it points outward from the ring
		p.spread = 25.0
		p.initial_velocity_min = 1.2
		p.initial_velocity_max = 1.8
		p.damping_min = 2.5
		p.damping_max = 2.5
		p.gravity = Vector3.ZERO
		p.color_ramp = _fade_gradient(Color.WHITE)
		p.scale_amount_curve = _grow_curve()
		p.rotation.y = a
		p.position = Vector3(sin(a), 0.0, cos(a)) * PUFF_RING_RADIUS
		remove_child(p)
		_puff_root.add_child(p)
		_puffs.append(p)

	_stars_root = Node3D.new()
	_stars_root.name = "BailStars"
	_stars_root.top_level = true
	_stars_root.visible = false
	add_child(_stars_root)
	var star_mesh: ArrayMesh = _star_mesh()
	var star_mat: StandardMaterial3D = _material(null, BaseMaterial3D.BILLBOARD_ENABLED, STAR_COLOR, false)
	for i in range(STAR_COUNT):
		var m := MeshInstance3D.new()
		m.name = "Star%d" % i
		m.mesh = star_mesh
		m.material_override = star_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.scale = Vector3.ZERO
		_stars_root.add_child(m)
		_stars.append(m)


func _process(delta: float) -> void:
	if not _built or _skater == null or not is_instance_valid(_skater):
		return
	if _visual == null:
		_visual = _skater.get_node_or_null("Visual") as Node3D
	var frame: Transform3D = _visual.global_transform if _visual != null else _skater.global_transform
	var st: SkateState.State = _skater.state.state
	_update_sparks(frame, st)
	_update_trail(frame, st)
	_update_stars(frame, st, delta)


func _update_sparks(frame: Transform3D, st: SkateState.State) -> void:
	var spd: float = _skater.speed
	_sparks.global_transform = Transform3D(frame.basis, frame.origin + frame.basis * SPARK_OFFSET)
	var want: int = clampi(int(ceil(spd / SPARK_STEP_SPEED)) * 6, 6, SPARK_MAX)
	if want != _sparks_amount:
		_sparks_amount = want
		_sparks.amount = want
	_sparks.initial_velocity_min = 1.5 + 0.3 * spd
	_sparks.initial_velocity_max = 2.5 + 0.5 * spd
	_sparks.emitting = st == SkateState.State.GRIND and spd > 0.5


func _update_trail(frame: Transform3D, st: SkateState.State) -> void:
	_trail.global_transform = Transform3D(frame.basis, frame.origin + frame.basis * TRAIL_OFFSET)
	_trail.emitting = st == SkateState.State.AIR and _skater.special.is_special()


func _update_stars(frame: Transform3D, st: SkateState.State, delta: float) -> void:
	var bailing: bool = st == SkateState.State.BAIL
	_stars_root.visible = bailing
	if not bailing:
		_star_pop = 0.0
		return
	_orbit_t += delta
	_star_pop = minf(1.0, _star_pop + delta / STAR_POP_TIME)
	_stars_root.global_transform = Transform3D(Basis.IDENTITY, frame * (STAR_OFFSET + Vector3(0.0, STAR_HEIGHT, 0.0)))
	for i in range(_stars.size()):
		var angle: float = _orbit_t * STAR_ORBIT_SPEED + TAU * float(i) / float(STAR_COUNT)
		var bob: float = 0.05 * sin(_orbit_t * 6.0 + float(i))
		_stars[i].position = Vector3(cos(angle) * STAR_ORBIT_RADIUS, bob, sin(angle) * STAR_ORBIT_RADIUS)
		_stars[i].scale = Vector3.ONE * (STAR_SIZE * _star_pop)


func _on_bailed() -> void:
	_star_pop = 0.0
	_orbit_t = 0.0


## Soft white dust ring at the feet. Clean landings give a bright puff, sketchy ones a greyer, denser one.
func _on_landed(result: String) -> void:
	if not _built or _skater == null or result == "bail":
		return
	var clean: bool = result == "clean"
	var count: int = 3 if clean else 5
	var col: Color = PUFF_CLEAN_COLOR if clean else PUFF_SKETCHY_COLOR
	var feet: Vector3 = _skater.global_position + Vector3(0.0, 0.02, 0.0)
	_puff_root.global_transform = Transform3D(Basis.IDENTITY, feet)
	for p: CPUParticles3D in _puffs:
		p.amount = count
		p.color = col
		p.emitting = false
		p.emitting = true


func _emitter(node_name: String, mesh: PrimitiveMesh, mat: StandardMaterial3D, amount: int,
		lifetime: float) -> CPUParticles3D:
	mesh.material = mat
	var p := CPUParticles3D.new()
	p.name = node_name
	p.mesh = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.2
	add_child(p)
	return p


func _quad(size: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	return q


func _material(tex: Texture2D, billboard: BaseMaterial3D.BillboardMode, tint: Color,
		vertex_tint: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = billboard
	m.billboard_keep_scale = true
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = vertex_tint
	m.albedo_color = tint
	return m


## Soft round dot: white centre fading to transparent at the edge.
func _dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## Five-point star, flat in XY, centred on the origin.
func _star_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: int = 10
	for i in range(ring):
		var a0: float = TAU * float(i) / float(ring) + PI * 0.5
		var a1: float = TAU * float(i + 1) / float(ring) + PI * 0.5
		var r0: float = 0.5 if i % 2 == 0 else 0.22
		var r1: float = 0.22 if i % 2 == 0 else 0.5
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a0) * r0, sin(a0) * r0, 0.0))
		st.add_vertex(Vector3(cos(a1) * r1, sin(a1) * r1, 0.0))
	return st.commit()


func _gradient(colors: PackedColorArray, offsets: PackedFloat32Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	return g


func _fade_gradient(c: Color) -> Gradient:
	return _gradient(PackedColorArray([c, Color(c.r, c.g, c.b, 0.0)]), PackedFloat32Array([0.0, 1.0]))


func _grow_curve() -> Curve:
	var c := Curve.new()
	c.clear_points()
	c.add_point(Vector2(0.0, 0.35))
	c.add_point(Vector2(1.0, 1.0))
	return c


func _rainbow_colors() -> PackedColorArray:
	return PackedColorArray([
		Color(1.0, 0.25, 0.25), Color(1.0, 0.6, 0.15), Color(1.0, 1.0, 0.3), Color(0.4, 1.0, 0.4),
		Color(0.3, 0.9, 1.0), Color(0.5, 0.5, 1.0), Color(1.0, 0.45, 0.9)])


func _even_offsets(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(n):
		out.append(float(i) / float(n - 1))
	return out
