class_name BailFx
extends Node
## Bail injury effects ("Hall of Meat" flavour, cartoon only: no blood, no gore). Follows the skater's bail ragdoll:
## - on the slam (SkaterRagdoll.injured): a bone-crunch sound, a comic impact burst at each hurt joint, a short slow
##   motion (real time, never in scripted runs), a camera punch-in and shake, and the readout (bail title, injury
##   list, "+2,450 MEAT");
## - on the repair (SkaterRagdoll.repairing): a pop sound and a white ring and sparkle at each joint as it snaps back.
## track(skater, ragdoll) makes one BailFx under the skater on first use and points it at the new ragdoll. With the
## Bail injuries setting off the plan carries no injuries, so none of this plays.

const SLOWMO_SCALE: float = 0.35
const SLOWMO_TIME: float = 0.42  ## s of real time
const SHAKE_TIME: float = 0.38
const SHAKE_AMP: float = 0.09  ## m of camera offset at full severity
const PUNCH_TIME: float = 0.55
const PUNCH_FOV: float = 13.0  ## degrees narrower at full severity: the camera punches in on the slam
const READOUT_TIME: float = 2.6
const BURST_TIME: float = 0.22
const POP_TIME: float = 0.28
const BURST_COLOR: Color = Color(1.0, 0.92, 0.35)
const POP_COLOR: Color = Color(0.85, 0.97, 1.0)
const RATE: int = 22050

static var _crunch_stream: AudioStreamWAV
static var _pop_stream: AudioStreamWAV
static var meat_total: int = 0  ## this session's Hall of Meat

var plan: Dictionary = {}
var _skater: Node3D
var _ragdoll: Node
var _player: AudioStreamPlayer
var _layer: CanvasLayer
var _box: VBoxContainer
var _readout_t: float = 99.0
var _shake_t: float = 99.0
var _punch_t: float = 99.0
var _sev: float = 0.0
var _cam: Camera3D
var _cam_fov_seen: float = -1.0
var _cam_fov_written: float = -1.0
var _slowmo: bool = false
var _star_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D


## The skater's BailFx (made on first use), now following `ragdoll`.
static func track(skater: Node3D, ragdoll: Node) -> BailFx:
	var fx: BailFx = skater.get_node_or_null("BailFx") as BailFx
	if fx == null:
		fx = BailFx.new()
		fx.name = "BailFx"
		skater.add_child(fx)
	fx._skater = skater
	fx.follow(ragdoll)
	return fx


func follow(ragdoll: Node) -> void:
	_ragdoll = ragdoll
	plan = ragdoll.get("plan") if ragdoll != null and ragdoll.get("plan") is Dictionary else {}
	if ragdoll == null:
		return
	if not ragdoll.is_connected("injured", _on_injured):
		ragdoll.connect("injured", _on_injured)
	if not ragdoll.is_connected("repairing", _on_repairing):
		ragdoll.connect("repairing", _on_repairing)


func _exit_tree() -> void:
	_end_slowmo()
	_restore_camera()


func _on_injured(points: Array) -> void:
	_sev = float(plan.get("severity", 0.5))
	_play(crunch_stream(), 0.9 + 0.25 * (1.0 - _sev))
	var at: Array = _anchors(points)
	for a: Variant in at:
		_burst(a, BURST_COLOR, BURST_TIME, 0.22 + 0.1 * _sev, true)
	_shake_t = 0.0
	_punch_t = 0.0
	meat_total += int(plan.get("meat", 0))
	_show_readout()
	if not Flags.is_scripted_run():
		_start_slowmo()


func _on_repairing(points: Array) -> void:
	_play(pop_stream(), 1.0)
	for a: Variant in _anchors(points):
		_burst(a, POP_COLOR, POP_TIME, 0.3, false)


func _process(delta: float) -> void:
	var real: float = delta / maxf(Engine.time_scale, 0.01)
	_tick_camera(real)
	if _layer != null and _readout_t < READOUT_TIME:
		_readout_t += real
		var fade: float = clampf((READOUT_TIME - _readout_t) / 0.35, 0.0, 1.0)
		_box.modulate.a = fade
		if _readout_t >= READOUT_TIME:
			_layer.visible = false


# --- camera -------------------------------------------------------------------------------------------------------

## Shake offset (m) at time t into the shake: a quick decaying wobble on two incommensurate sines. Pure.
static func shake_offset(t: float, sev: float) -> Vector2:
	if t >= SHAKE_TIME or t < 0.0:
		return Vector2.ZERO
	var k: float = 1.0 - t / SHAKE_TIME
	var a: float = SHAKE_AMP * (0.4 + 0.6 * sev) * k * k
	return Vector2(sin(t * 83.0) * a, cos(t * 61.0 + 0.7) * a * 0.8)


## FOV reduction (degrees) at time t into the punch: in fast, out slowly. Pure.
static func punch_fov(t: float, sev: float) -> float:
	if t >= PUNCH_TIME or t < 0.0:
		return 0.0
	var u: float = t / PUNCH_TIME
	var env: float = minf(u / 0.12, 1.0) * (1.0 - smoothstep(0.35, 1.0, u))
	return PUNCH_FOV * (0.5 + 0.5 * sev) * env


func _tick_camera(real: float) -> void:
	if _shake_t >= SHAKE_TIME and _punch_t >= PUNCH_TIME:
		return
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_3d() if is_inside_tree() else null
		_cam_fov_seen = -1.0
	if _cam == null:
		return
	_shake_t += real
	_punch_t += real
	var o: Vector2 = shake_offset(_shake_t, _sev)
	_cam.h_offset = o.x
	_cam.v_offset = o.y
	# The chase camera writes its own fov each physics tick: punch relative to the last value it wrote.
	if _cam_fov_written < 0.0 or not is_equal_approx(_cam.fov, _cam_fov_written):
		_cam_fov_seen = _cam.fov
	_cam_fov_written = clampf(_cam_fov_seen - punch_fov(_punch_t, _sev), 20.0, 120.0)
	_cam.fov = _cam_fov_written
	if _shake_t >= SHAKE_TIME and _punch_t >= PUNCH_TIME:
		_restore_camera()


func _restore_camera() -> void:
	if _cam != null and is_instance_valid(_cam):
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
		if _cam_fov_seen > 0.0 and is_equal_approx(_cam.fov, _cam_fov_written):
			_cam.fov = _cam_fov_seen
	_cam_fov_written = -1.0


# --- slow motion ----------------------------------------------------------------------------------------------------

func _start_slowmo() -> void:
	if not is_inside_tree():
		return
	_slowmo = true
	Engine.time_scale = SLOWMO_SCALE
	var t: SceneTreeTimer = get_tree().create_timer(SLOWMO_TIME, true, false, true)
	t.timeout.connect(_end_slowmo)


func _end_slowmo() -> void:
	if _slowmo:
		_slowmo = false
		Engine.time_scale = 1.0


# --- readout --------------------------------------------------------------------------------------------------------

## Readout text: [title, injury lines..., "+2,450 MEAT"]. Empty when the plan has no injuries. Pure.
static func readout_lines(p: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var inj: Array = p.get("injuries", [])
	if inj.is_empty():
		return out
	out.append(str(p.get("title", "BAIL")))
	for i: Dictionary in inj:
		out.append(str(i["label"]))
	out.append("+%s MEAT" % Hud.format_points(int(p.get("meat", 0))))
	return out


func _show_readout() -> void:
	var lines: PackedStringArray = readout_lines(plan)
	if lines.is_empty() or not is_inside_tree():
		return
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 12
		add_child(_layer)
		var root: Control = Control.new()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(root)
		_box = VBoxContainer.new()
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_box.add_theme_constant_override("separation", -6)
		_box.anchor_left = 0.8  # lower right: the chase camera keeps the skater in the middle of the screen
		_box.anchor_right = 0.8
		_box.anchor_top = 0.66
		_box.anchor_bottom = 0.66
		_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_box.grow_vertical = Control.GROW_DIRECTION_BOTH
		root.add_child(_box)
	for c: Node in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_layer.visible = true
	_readout_t = 0.0
	_box.modulate.a = 1.0
	var head: Label = UiStyle.label("HALL OF MEAT  -  " + lines[0], UiStyle.SIZE_SMALL, UiStyle.WHITE)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(head)
	for i: int in range(1, lines.size() - 1):
		var t: AnimeText = AnimeText.new("", UiStyle.SIZE_BIG, UiStyle.BUBBLEGUM)
		t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		t.impact_lines = false  # the HUD's Bail! already bursts; keep the skater in view
		_box.add_child(t)
		t.pop(lines[i])
	var m: AnimeText = AnimeText.new("", UiStyle.SIZE_BODY + 6, UiStyle.SUNSHINE)
	m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.impact_lines = false
	_box.add_child(m)
	m.pop(lines[lines.size() - 1])


# --- 3D bursts ------------------------------------------------------------------------------------------------------

## Where the bursts go: the injured joints themselves when the ragdoll gives them (so a burst rides with its limb),
## else the world points.
func _anchors(points: Array) -> Array:
	if _ragdoll != null and is_instance_valid(_ragdoll) and _ragdoll.has_method("injury_nodes"):
		var nodes: Array = _ragdoll.call("injury_nodes")
		if not nodes.is_empty():
			return nodes
	return points


## A comic impact burst (spiky star) or a repair pop (ring), billboarded at `at` (a joint Node3D it rides on, or a
## world point), growing and fading over `life`.
func _burst(at: Variant, color: Color, life: float, size: float, spiky: bool) -> void:
	var world: Node = at as Node3D if at is Node3D else (_skater.get_parent() if _skater != null else null)
	if world == null or not is_inside_tree() or not world.is_inside_tree():
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE * size
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: StandardMaterial3D = (_star_material() if spiky else _ring_material()).duplicate() as StandardMaterial3D
	mat.albedo_color = color
	mi.material_override = mat
	world.add_child(mi)
	if not at is Node3D:
		mi.global_position = at as Vector3
	mi.scale = Vector3.ONE * 0.3
	var tw: Tween = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * (1.0 if spiky else 1.6), life).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, life).set_delay(life * 0.35)
	tw.chain().tween_callback(mi.queue_free)


func _star_material() -> StandardMaterial3D:
	if _star_mat == null:
		_star_mat = _billboard_material(burst_texture(true))
	return _star_mat


func _ring_material() -> StandardMaterial3D:
	if _ring_mat == null:
		_ring_mat = _billboard_material(burst_texture(false))
	return _ring_mat


func _billboard_material(tex: Texture2D) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.albedo_texture = tex
	return m


## 64 px burst texture: a jagged comic "pow" star with a navy rim, or a thin ring with four sparkle rays.
static func burst_texture(spiky: bool) -> ImageTexture:
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c: float = (n - 1) * 0.5
	for y: int in n:
		for x: int in n:
			var dx: float = (x - c) / c
			var dy: float = (y - c) / c
			var r: float = sqrt(dx * dx + dy * dy)
			var a: float = atan2(dy, dx)
			var col: Color = Color(1, 1, 1, 0)
			if spiky:
				var edge: float = 0.62 + 0.36 * absf(sin(a * 4.5)) * (0.75 + 0.25 * sin(a * 3.0 + 1.0))
				if r < edge - 0.12:
					col = Color(1, 1, 1, 1)
				elif r < edge:
					col = Color(0.12, 0.13, 0.3, 1)  # navy rim; tinted to a dark ochre by the yellow
			else:
				var ring: float = 1.0 - clampf(absf(r - 0.72) / 0.09, 0.0, 1.0)
				var ray: float = 0.0
				for k: int in 4:
					var da: float = absf(wrapf(a - PI * 0.5 * k - PI * 0.25, -PI, PI))
					ray = maxf(ray, (1.0 - clampf(da / 0.07, 0.0, 1.0)) * (1.0 - clampf(absf(r - 0.5) / 0.4, 0.0, 1.0)))
				col = Color(1, 1, 1, clampf(maxf(ring, ray), 0.0, 1.0))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


# --- sound ----------------------------------------------------------------------------------------------------------

func _play(stream: AudioStream, pitch: float) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.volume_db = -4.0
		add_child(_player)
	_player.stream = stream
	_player.pitch_scale = pitch
	_player.play()


## A dull thud with a quick crackle of dry clicks on top (a cartoon bone crunch), about 0.35 s, peak -6 dBFS.
static func crunch_stream() -> AudioStreamWAV:
	if _crunch_stream == null:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 909
		var out: PackedFloat32Array = PackedFloat32Array()
		out.resize(int(0.35 * RATE))
		var lp: float = 0.0
		for i: int in out.size():
			var t: float = float(i) / RATE
			var thud: float = sin(TAU * (95.0 - 120.0 * t) * t) * exp(-t * 18.0)
			lp += 0.35 * (rng.randf_range(-1.0, 1.0) - lp)
			out[i] = thud * 0.8 + lp * 0.35 * exp(-t * 9.0)
		for k: int in 7:  # the crackle: short bright clicks bunched at the start
			var at: int = int((0.004 + 0.018 * k + rng.randf_range(0.0, 0.008)) * RATE)
			var amp: float = 0.9 * pow(0.8, k)
			for j: int in int(0.006 * RATE):
				if at + j < out.size():
					out[at + j] += amp * rng.randf_range(-1.0, 1.0) * exp(-float(j) / (0.0012 * RATE))
		_crunch_stream = wav_from(out)
	return _crunch_stream


## A short rising "bloop" (the joint clicking back in), 0.14 s.
static func pop_stream() -> AudioStreamWAV:
	if _pop_stream == null:
		var out: PackedFloat32Array = PackedFloat32Array()
		out.resize(int(0.14 * RATE))
		var ph: float = 0.0
		for i: int in out.size():
			var t: float = float(i) / RATE
			ph += TAU * (420.0 + 5200.0 * t) / RATE
			out[i] = sin(ph) * minf(t / 0.004, 1.0) * exp(-t * 26.0)
		_pop_stream = wav_from(out)
	return _pop_stream


## 16-bit mono WAV normalised to -6 dBFS.
static func wav_from(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak: float = 0.0001
	for s: float in samples:
		peak = maxf(peak, absf(s))
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / peak * 0.5, -1.0, 1.0) * 32767.0))
	var st: AudioStreamWAV = AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	return st
