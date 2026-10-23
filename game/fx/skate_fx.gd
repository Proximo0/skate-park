class_name SkateFx
extends Node3D
## Cartoon particle effects for the skater: grind sparks, landing puffs, bail stars and the special trail.
## Compatibility renderer: CPUParticles3D only, unshaded vertex-coloured billboards.
## bind(skater) makes this node a child of the skater. Board effects are placed each frame in the skater's
## Visual frame (-Z travel, +Y board up); the landing puff is placed once where it starts.

const SPARK_MAX: int = 30
const SPARK_LIFE: float = 0.24
const RING_TIME: float = 0.38
const RING_RADIUS: float = 1.7  ## m the landing ring grows to
const BURST_COUNT: int = 12
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

const DUST_MAX: int = 36
const DUST_LIFE: float = 0.55
const SKID_POOL: int = 56
const SKID_LIFE: float = 7.0  ## s a skid mark lasts
const SKID_FADE: float = 2.5  ## s of that spent fading out
const SKID_STEP: float = 0.3  ## m between marks
const SKID_LEN: float = 0.5
const SKID_WIDTH: float = 0.42  ## the two wheel tracks of a board
const DUST_WHEEL_Z: float = 0.34  ## Visual-local distance of the truck pairs from the board centre
const DUST_COLORS: Dictionary = {
	"concrete": Color(0.95, 0.95, 1.0, 0.5), "wood": Color(0.9, 0.8, 0.65, 0.5),
	"sand": Color(0.95, 0.84, 0.58, 0.95)}
const SKID_COLORS: Dictionary = {
	"concrete": Color(0.1, 0.1, 0.12, 0.5), "wood": Color(0.15, 0.1, 0.07, 0.38),
	"sand": Color(0.45, 0.36, 0.22, 0.5)}
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
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _ring_t: float = 99.0
var _ring_scale: float = 1.0
var _burst: CPUParticles3D
var _streaks: SpeedStreaks
var _orbit_t: float = 0.0
var _star_pop: float = 0.0
var _lshake_t: float = 99.0  ## big-landing camera shake clock (s since the landing)
var _lshake_amp: float = 0.0
var _shake_cam: Camera3D
var _dust: CPUParticles3D  ## wheel grit while powersliding
var _dust_surface: String = "concrete"
var _dust_probe: float = 0.0
var _skid_marks: Array[MeshInstance3D] = []
var _skid_next: int = 0
var _skid_last: Vector3 = Vector3(INF, 0.0, 0.0)
var _skid_mat: StandardMaterial3D
var _skid_age: PackedFloat32Array = PackedFloat32Array()
var _skid_alpha: PackedFloat32Array = PackedFloat32Array()


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

	var streak_mat: StandardMaterial3D = _material(_streak_texture(), BaseMaterial3D.BILLBOARD_DISABLED, Color.WHITE, true)
	streak_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var streak_mesh: ArrayMesh = _streak_mesh(0.05, 0.34)
	_sparks = _emitter("GrindSparks", streak_mesh, streak_mat, SPARK_MAX, SPARK_LIFE)
	_sparks.particle_flag_align_y = true  ## the streak lies along its velocity
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sparks.emission_box_extents = Vector3(0.04, 0.01, 0.26)  ## spread along the board: both truck contact points
	_sparks.direction = Vector3(0.0, 0.5, 1.0)  ## visual +Z is behind the skater
	_sparks.spread = 28.0
	_sparks.gravity = Vector3(0.0, -12.0, 0.0)
	_sparks.color_ramp = _gradient(
		PackedColorArray([Color(1.0, 1.0, 0.85, 1.0), Color(1.0, 0.75, 0.25, 0.9), Color(1.0, 0.45, 0.1, 0.0)]),
		PackedFloat32Array([0.0, 0.45, 1.0]))

	_burst = _emitter("LandBurst", streak_mesh, streak_mat, BURST_COUNT, 0.3)
	remove_child(_burst)
	_burst.one_shot = true
	_burst.explosiveness = 1.0
	_burst.particle_flag_align_y = true
	_burst.direction = Vector3.UP
	_burst.spread = 75.0
	_burst.initial_velocity_min = 2.5
	_burst.initial_velocity_max = 4.5
	_burst.gravity = Vector3(0.0, -9.0, 0.0)
	_burst.color_ramp = _gradient(
		PackedColorArray([Color(1.0, 1.0, 0.9, 1.0), Color(1.0, 0.9, 0.4, 0.8), Color(1.0, 0.8, 0.3, 0.0)]),
		PackedFloat32Array([0.0, 0.5, 1.0]))

	_dust = _emitter("SlideDust", _quad(Vector2(0.9, 0.9)), particle_mat, DUST_MAX, DUST_LIFE)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(0.25, 0.02, DUST_WHEEL_Z)
	_dust.direction = Vector3(0.0, 0.6, 0.0)
	_dust.spread = 55.0
	_dust.initial_velocity_min = 0.6
	_dust.initial_velocity_max = 1.3
	_dust.damping_min = 1.5
	_dust.damping_max = 2.5
	_dust.gravity = Vector3(0.0, 0.25, 0.0)
	_dust.color_ramp = _fade_gradient(Color.WHITE)
	_dust.scale_amount_curve = _grow_curve()
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.1
	_build_skid_marks()

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

	_puff_root.add_child(_burst)
	_ring_mat = _material(_ring_texture(), BaseMaterial3D.BILLBOARD_DISABLED, Color.WHITE, false)
	_ring = MeshInstance3D.new()
	_ring.name = "LandRing"
	_ring.mesh = _quad(Vector2(2.0, 2.0))
	(_ring.mesh as QuadMesh).material = _ring_mat
	_ring.rotation.x = -PI * 0.5
	_ring.position = Vector3(0.0, 0.03, 0.0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	_puff_root.add_child(_ring)
	_streaks = SpeedStreaks.new()
	_streaks.name = "SpeedStreaks"
	_streaks.skater = _skater
	add_child(_streaks)

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


const LAND_SHAKE_MIN: float = 0.45  ## land_impact (0..1) below this: no shake
const LAND_SHAKE_TIME: float = 0.28
const LAND_SHAKE_AMP: float = 0.07  ## m of camera offset at full impact


## Camera shake offset (m) t seconds after a landing of this 0..1 impact: a short decaying wobble, none below
## LAND_SHAKE_MIN. Pure.
static func land_shake(t: float, impact: float) -> Vector2:
	if impact < LAND_SHAKE_MIN or t < 0.0 or t >= LAND_SHAKE_TIME:
		return Vector2.ZERO
	var k: float = 1.0 - t / LAND_SHAKE_TIME
	var a: float = LAND_SHAKE_AMP * clampf((impact - LAND_SHAKE_MIN) / (1.0 - LAND_SHAKE_MIN) * 0.8 + 0.2, 0.0, 1.0) * k * k
	return Vector2(sin(t * 71.0) * a * 0.5, cos(t * 53.0) * a)


func _tick_land_shake(delta: float) -> void:
	if _lshake_t >= LAND_SHAKE_TIME:
		return
	if _shake_cam == null or not is_instance_valid(_shake_cam):
		_shake_cam = get_viewport().get_camera_3d()
	if _shake_cam == null:
		return
	_lshake_t += delta
	var o: Vector2 = land_shake(_lshake_t, _lshake_amp)
	_shake_cam.h_offset = o.x
	_shake_cam.v_offset = o.y


func _process(delta: float) -> void:
	if not _built or _skater == null or not is_instance_valid(_skater):
		return
	_tick_land_shake(delta)
	if _visual == null:
		_visual = _skater.get_node_or_null("Visual") as Node3D
	var frame: Transform3D = _visual.global_transform if _visual != null else _skater.global_transform
	var st: SkateState.State = _skater.state.state
	_update_sparks(frame, st)
	_update_slide(frame, delta)
	_update_trail(frame, st)
	_update_stars(frame, st, delta)
	_update_ring(delta)


func _update_ring(delta: float) -> void:
	if _ring_t > RING_TIME:
		_ring.visible = false
		return
	_ring_t += delta
	var k: float = clampf(_ring_t / RING_TIME, 0.0, 1.0)
	var grow: float = 1.0 - pow(1.0 - k, 3.0)
	_ring.visible = true
	_ring.scale = Vector3.ONE * lerpf(0.25, RING_RADIUS * _ring_scale, grow)
	var a: float = 1.0 - k
	_ring_mat.albedo_color = Color(_ring_mat.albedo_color.r, _ring_mat.albedo_color.g, _ring_mat.albedo_color.b, a * a)


func _update_sparks(frame: Transform3D, st: SkateState.State) -> void:
	var spd: float = _skater.speed
	_sparks.global_transform = Transform3D(frame.basis, frame.origin + frame.basis * SPARK_OFFSET)
	var want: int = clampi(int(ceil(spd / SPARK_STEP_SPEED)) * 6, 6, SPARK_MAX)
	if want != _sparks_amount:
		_sparks_amount = want
		_sparks.amount = want
	_sparks.initial_velocity_min = 2.0 + 0.3 * spd
	_sparks.initial_velocity_max = 3.5 + 0.5 * spd
	_sparks.emitting = st == SkateState.State.GRIND and spd > 0.5


## Powerslide grit from the wheels (a light grey puff on concrete, a bigger tan one on sand) and a short skid mark
## laid every SKID_STEP m along the slide.
func _update_slide(frame: Transform3D, delta: float) -> void:
	_age_skid_marks(delta)
	var bert: bool = _skater.berting and _skater.state.state == SkateState.State.ROLLING
	var sliding: bool = (_skater.powersliding or bert) and _skater.state.state == SkateState.State.ROLLING
	if sliding:
		_dust_probe -= delta
		if _dust_probe <= 0.0:
			_dust_probe = 0.25
			_dust_surface = _probe_surface_name()
	else:
		_dust_probe = 0.0
		_skid_last = Vector3(INF, 0.0, 0.0)
	var spd: float = _skater.speed
	var sandy: bool = _dust_surface == "sand"
	_dust.global_transform = Transform3D(frame.basis, frame.origin + frame.basis * Vector3(0.0, 0.05, 0.0))
	var col: Color = DUST_COLORS.get(_dust_surface, DUST_COLORS["concrete"])
	_dust.color = col
	_dust.initial_velocity_max = (1.3 if not sandy else 2.2) + 0.12 * spd
	_dust.scale_amount_max = 1.6 if sandy else (1.2 if bert else 0.8)  ## a bert slide drags more grit than a skid
	_dust.emitting = sliding and spd > 1.0
	if sliding and not bert and spd > 1.5:
		var pos: Vector3 = _skater.global_position
		if _skid_last.x == INF:
			_drop_skid_mark(pos)
		else:
			var gap: float = pos.distance_to(_skid_last)
			var from: Vector3 = _skid_last
			var n: int = mini(int(gap / SKID_STEP), 8)  ## a slow frame still lays an unbroken line
			for i in range(1, n + 1):
				_drop_skid_mark(from.lerp(pos, float(i) / float(n)))


## The material of the ground under the skater: "concrete", "wood" or "sand" (from the collider's names).
func _probe_surface_name() -> String:
	if not _skater.is_inside_tree():
		return "concrete"
	var from: Vector3 = _skater.global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.2)
	if _skater is CollisionObject3D:
		q.exclude = [(_skater as CollisionObject3D).get_rid()]
	var hit: Dictionary = _skater.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "concrete"
	var names := PackedStringArray()
	var n: Node = hit["collider"] as Node
	var depth: int = 0
	while n != null and depth < 4:
		names.append(str(n.name))
		n = n.get_parent()
		depth += 1
	var s: String = SkateAudio.classify_surface(names)
	return s if s == "wood" or s == "sand" else "concrete"


func _build_skid_marks() -> void:
	var img: Image = Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		var along: float = float(y) / 63.0
		var end_fade: float = clampf(minf(along, 1.0 - along) * 6.0, 0.0, 1.0)
		for x in range(32):
			var u: float = (float(x) + 0.5) / 32.0
			var track: float = maxf(clampf(1.0 - absf(u - 0.22) / 0.14, 0.0, 1.0), clampf(1.0 - absf(u - 0.78) / 0.14, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, track * end_fade))
	_skid_mat = _material(ImageTexture.create_from_image(img), BaseMaterial3D.BILLBOARD_DISABLED, Color.WHITE, false)
	_skid_mat.render_priority = -1
	var holder := Node3D.new()
	holder.name = "SkidMarks"
	holder.top_level = true
	add_child(holder)
	var quad := QuadMesh.new()
	quad.size = Vector2(SKID_WIDTH, SKID_LEN)
	quad.orientation = PlaneMesh.FACE_Y
	for i in range(SKID_POOL):
		var m := MeshInstance3D.new()
		m.name = "Skid%d" % i
		m.mesh = quad
		m.material_override = _skid_mat.duplicate()
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		holder.add_child(m)
		_skid_marks.append(m)
		_skid_age.append(SKID_LIFE)
		_skid_alpha.append(0.5)


func _drop_skid_mark(pos: Vector3) -> void:
	var from: Vector3 = pos + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.0)
	if _skater is CollisionObject3D:
		q.exclude = [(_skater as CollisionObject3D).get_rid()]
	var hit: Dictionary = _skater.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var up: Vector3 = hit["normal"]
	var travel: Vector3 = _skater.velocity
	travel = (travel - up * travel.dot(up))
	if travel.length() < 0.1:
		return
	var fwd: Vector3 = travel.normalized()
	var m: MeshInstance3D = _skid_marks[_skid_next]
	var side: Vector3 = fwd.cross(up).normalized()
	m.global_transform = Transform3D(Basis(side, up, -fwd).orthonormalized(), (hit["position"] as Vector3) + up * 0.015)
	var mat: StandardMaterial3D = m.material_override as StandardMaterial3D
	mat.albedo_color = SKID_COLORS.get(_dust_surface, SKID_COLORS["concrete"])
	_skid_alpha[_skid_next] = mat.albedo_color.a
	m.visible = true
	_skid_age[_skid_next] = 0.0
	_skid_next = (_skid_next + 1) % SKID_POOL
	_skid_last = pos


func _age_skid_marks(delta: float) -> void:
	for i in range(_skid_marks.size()):
		if _skid_age[i] >= SKID_LIFE:
			continue
		_skid_age[i] += delta
		var m: MeshInstance3D = _skid_marks[i]
		if _skid_age[i] >= SKID_LIFE:
			m.visible = false
			continue
		var fade: float = clampf((SKID_LIFE - _skid_age[i]) / SKID_FADE, 0.0, 1.0)
		var mat: StandardMaterial3D = m.material_override as StandardMaterial3D
		mat.albedo_color.a = _skid_alpha[i] * fade


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


## Soft white dust ring at the feet plus an expanding ground ring and a star burst of streaks. Clean landings give a bright puff, sketchy ones a greyer, denser one.
func _on_landed(result: String) -> void:
	if not _built or _skater == null or result == "bail":
		return
	if _skater.land_impact >= LAND_SHAKE_MIN:
		_lshake_t = 0.0
		_lshake_amp = _skater.land_impact
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
	_ring_t = 0.0
	_ring_scale = 1.0 if clean else 0.7
	var ring_col: Color = Color(1.0, 1.0, 1.0) if clean else Color(1.0, 0.8, 0.45)
	_ring_mat.albedo_color = ring_col
	_burst.amount = BURST_COUNT if clean else 7
	_burst.emitting = false
	_burst.emitting = true


func _emitter(node_name: String, mesh: Mesh, mat: StandardMaterial3D, amount: int,
		lifetime: float) -> CPUParticles3D:
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = mat
	else:
		mesh.surface_set_material(0, mat)
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


## Streak texture: a bright head at the top (the velocity end) tapering to nothing, soft at the sides.
func _streak_texture() -> ImageTexture:
	var w: int = 16
	var h: int = 64
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var along: float = float(y) / float(h - 1)  ## 0 head, 1 tail
		var taper: float = pow(1.0 - along, 1.6)
		for x in range(w):
			var across: float = 1.0 - absf((float(x) + 0.5) / float(w) * 2.0 - 1.0)
			var a: float = clampf(taper * pow(across, 0.8) * 1.4, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## Soft ring on a transparent square: bright thin band at ~80 percent of the radius.
func _ring_texture() -> ImageTexture:
	var n: int = 128
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var r: float = Vector2(float(x) + 0.5 - n * 0.5, float(y) + 0.5 - n * 0.5).length() / (n * 0.5)
			var a: float = clampf(1.0 - absf(r - 0.78) / 0.16, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


## Two crossed quads along Y so a velocity-aligned streak reads from any side. UV v=0 is the head (+Y).
func _streak_mesh(width: float, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plane in range(2):
		var side: Vector3 = Vector3.RIGHT if plane == 0 else Vector3.BACK
		var hw: float = width * 0.5
		var hl: float = length * 0.5
		var corners: Array[Vector3] = [-side * hw + Vector3.UP * hl, side * hw + Vector3.UP * hl,
			side * hw - Vector3.UP * hl, -side * hw - Vector3.UP * hl]
		var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[i])
			st.add_vertex(corners[i])
	return st.commit()


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
