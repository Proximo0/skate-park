class_name SplashScreen
extends Control
## Intro splash, the game's main scene. Studio card (wipe in/out), then the title card: sunset sky, wave, palm,
## speed-line burst, a real 3D board kickflipping in through a SubViewport and the SKATE PARK lettering slamming
## in. About 7 seconds; any key, button or click skips. Then changes to the title screen. All art is procedural.

signal finished  ## emitted once when the splash ends or is skipped, just before the scene change

const TITLE_SCENE: String = "res://game/ui/title_screen.tscn"
const STUDIO_NAME: String = "KICKFLARE"
const STUDIO_TAG: String = "S T U D I O S"
const TITLE: String = "SKATE PARK"
const TAGLINE: String = "Shred. Grind. Have fun!"
const STUDIO_END: float = 2.3  ## s, studio card wipes out
const TITLE_START: float = 2.0
const TITLE_SLAM: float = 3.3  ## s, letters hit
const TOTAL: float = 7.6  ## s; the end holds the title card, then a short fade the title screen answers with a fade-in
const INK: Color = SkateThemeBuilder.NAVY
const LETTER_COLORS: PackedColorArray = [
	SkateThemeBuilder.SUN, SkateThemeBuilder.CORAL, SkateThemeBuilder.CREAM, SkateThemeBuilder.TEAL, SkateThemeBuilder.SUN,
	SkateThemeBuilder.SUN, SkateThemeBuilder.CORAL, SkateThemeBuilder.CREAM, SkateThemeBuilder.TEAL, SkateThemeBuilder.SUN,
]
const SKY_STOPS: PackedFloat32Array = [0.0, 0.45, 0.75, 1.0]
const SKY_COLORS: PackedColorArray = [Color("#3B2A8C"), Color("#E0529C"), Color("#FF9A5A"), Color("#FFD23F")]
const BOARD_VIEW: Vector2i = Vector2i(720, 420)

var change_scene: bool = true  ## tests turn this off
var _size: Vector2 = Vector2(1280.0, 720.0)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _done: bool = false
var _title_layer: Control
var _studio_layer: Control
var _wipe: Control
var _shake_root: Control
var _burst: Node2D
var _board_pivot: Node3D
var _board_box: SubViewportContainer
var _letters: Array[Label] = []
var _flash: ColorRect
var _fade: ColorRect
var _sparkles: Array[Node2D] = []
var _tween: Tween
var _time: float = 0.0


func _ready() -> void:
	_rng.seed = 20260
	_size = get_viewport_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_title_layer()
	_build_studio_layer()
	_build_wipe()
	_fade = _rect(Color(INK, 1.0))
	_fade.name = "Fade"
	add_child(_fade)
	_play_sequence()


func _process(delta: float) -> void:
	_time += delta
	if _burst != null:
		_burst.rotation += delta * 0.12
	if _board_pivot != null and _time > 4.6:
		_board_pivot.rotation.y += delta * 0.9
	for i: int in _sparkles.size():
		var s: Node2D = _sparkles[i]
		s.scale = Vector2.ONE * (0.75 + 0.3 * sin(_time * 4.0 + float(i) * 1.7)) * float(s.get_meta("base"))


func _input(event: InputEvent) -> void:
	var pressed: bool = false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		skip()


## Jumps straight to the title screen.
func skip() -> void:
	if _done:
		return
	_done = true
	if _tween != null:
		_tween.kill()
	finished.emit()
	if change_scene and is_inside_tree():
		get_tree().change_scene_to_file(TITLE_SCENE)


func is_done() -> bool:
	return _done


# ---- sequence ----------------------------------------------------------------------------------------------

func _play_sequence() -> void:
	_tween = create_tween()
	_tween.tween_property(_fade, "color:a", 0.0, 0.25)  # open from black
	# Studio card: wipe in, hold, wipe out.
	var wipe: Control = _wipe
	var logo: Control = _studio_layer.get_node("Logo")
	_tween.tween_property(wipe, "position:x", _size.x * 1.3, 0.6).from(-_size.x * 1.3).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(logo, "modulate:a", 1.0, 0.2).set_delay(0.3)
	_tween.parallel().tween_property(logo, "scale", Vector2.ONE, 0.5).from(Vector2(1.25, 1.25)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3)
	_tween.tween_interval(1.0)
	_tween.tween_callback(_sting.bind("studio"))
	_tween.tween_property(wipe, "position:x", _size.x * 1.3, 0.6).from(-_size.x * 1.3).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_callback(_start_title).set_delay(0.3)
	_tween.tween_interval(TOTAL - 2.55 - 0.2)
	_tween.tween_property(_fade, "color:a", 1.0, 0.2)
	_tween.tween_callback(skip)


func _start_title() -> void:
	_title_layer.visible = true
	_studio_layer.visible = false
	var t: Tween = create_tween()
	# Kickflip arc: the board flies in from the lower left, flips, and settles under the title.
	_board_box.modulate.a = 1.0
	t.tween_method(_board_arc, 0.0, 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_board_pivot, "rotation:z", TAU * 2.0, 1.1).from(0.0)
	t.parallel().tween_callback(_slam).set_delay(0.5)
	var burst_t: Tween = create_tween()
	burst_t.tween_property(_burst, "scale", Vector2.ONE, 0.5).from(Vector2(0.2, 0.2)) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var sky_t: Tween = create_tween()
	sky_t.tween_property(_title_layer, "modulate:a", 1.0, 0.2).from(0.0)


func _board_arc(p: float) -> void:
	var start: Vector2 = Vector2(-_size.x * 0.25, _size.y * 0.75)
	var end: Vector2 = Vector2(_size.x * 0.5 - BOARD_VIEW.x * 0.5, _size.y - BOARD_VIEW.y * 0.95)
	var pos: Vector2 = start.lerp(end, p)
	pos.y -= sin(p * PI) * _size.y * 0.55
	_board_box.position = pos


func _slam() -> void:
	_sting("title")
	_flash.color.a = 0.9
	var ft: Tween = create_tween()
	ft.tween_property(_flash, "color:a", 0.0, 0.35)
	for i: int in _letters.size():
		var l: Label = _letters[i]
		l.modulate.a = 1.0
		var lt: Tween = create_tween()
		lt.tween_property(l, "scale", Vector2.ONE, 0.32).from(Vector2(2.6, 2.6)).set_delay(0.035 * float(i)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		lt.parallel().tween_property(l, "rotation", 0.0, 0.32).from(deg_to_rad(_rng.randf_range(-25.0, 25.0))) \
			.set_delay(0.035 * float(i))
	# Camera shake.
	var st: Tween = create_tween()
	for k: int in 7:
		var amp: float = 16.0 * (1.0 - float(k) / 7.0)
		st.tween_property(_shake_root, "position", Vector2(_rng.randf_range(-amp, amp), _rng.randf_range(-amp, amp)), 0.04)
	st.tween_property(_shake_root, "position", Vector2.ZERO, 0.04)
	var sub: Label = _title_layer.get_node("Tagline")
	var tt: Tween = create_tween()
	tt.tween_property(sub, "modulate:a", 1.0, 0.4).set_delay(0.5)
	for s: Node2D in _sparkles:
		s.visible = true


## Sound hook: no dedicated sting exists in game/audio yet, so reuse the synthesized UI sounds.
## TODO(audio): replace with a proper splash sting (SfxSynth) when one is made.
func _sting(which: String) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var player := AudioStreamPlayer.new()
	player.stream = SfxSynth.combo_land() if which == "title" else SfxSynth.ui_accept()
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


# ---- building ----------------------------------------------------------------------------------------------

func _rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = _size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build_title_layer() -> void:
	_title_layer = Control.new()
	_title_layer.name = "TitleLayer"
	_title_layer.size = _size
	_title_layer.visible = false
	_title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_layer)
	_shake_root = Control.new()
	_shake_root.name = "Shake"
	_shake_root.size = _size
	_shake_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(_shake_root)
	_shake_root.add_child(_sky())
	_shake_root.add_child(_sun())
	_burst = _speed_burst()
	_shake_root.add_child(_burst)
	_shake_root.add_child(_wave())
	_shake_root.add_child(_palm(Vector2(_size.x * 0.89, _size.y * 0.93), 1.0))
	_shake_root.add_child(_palm(Vector2(_size.x * 0.06, _size.y * 0.97), 0.7))
	_shake_root.add_child(_manga_lines())
	_build_board()
	_build_lettering()
	_build_sparkles()
	_flash = _rect(Color(1, 1, 1, 0))
	_flash.name = "Flash"
	_title_layer.add_child(_flash)


func _sky() -> TextureRect:
	var g := Gradient.new()
	g.offsets = SKY_STOPS
	g.colors = SKY_COLORS
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 8
	tex.height = 256
	var tr := TextureRect.new()
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = _size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _circle(center: Vector2, radius: float, color: Color, n: int = 48) -> Polygon2D:
	var pts := PackedVector2Array()
	for i: int in n:
		pts.append(center + Vector2.from_angle(TAU * float(i) / float(n)) * radius)
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	return p


func _sun() -> Node2D:
	var root := Node2D.new()
	var c: Vector2 = Vector2(_size.x * 0.5, _size.y * 0.55)
	root.add_child(_circle(c, 250.0, Color("#FFD23F", 0.18)))
	root.add_child(_circle(c, 190.0, Color("#FFE98A", 0.35)))
	var sun: Polygon2D = _circle(c, 135.0, Color("#FFF0A0"))
	root.add_child(sun)
	# Retro sun stripes cut out with sky-coloured bars.
	for k: int in 5:
		var y: float = c.y + 20.0 + float(k) * 22.0
		var h: float = 3.0 + float(k) * 3.0
		var bar := Polygon2D.new()
		bar.polygon = PackedVector2Array([Vector2(c.x - 150, y), Vector2(c.x + 150, y), Vector2(c.x + 150, y + h), Vector2(c.x - 150, y + h)])
		bar.color = Color("#FF9A5A")
		root.add_child(bar)
	return root


func _speed_burst() -> Node2D:
	var root := Node2D.new()
	root.position = Vector2(_size.x * 0.5, _size.y * 0.42)
	var n: int = 28
	for i: int in n:
		var a0: float = TAU * float(i) / float(n)
		var a1: float = a0 + TAU / float(n) * 0.5
		var tri := Polygon2D.new()
		tri.polygon = PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a0) * 1500.0, Vector2.from_angle(a1) * 1500.0])
		tri.color = Color(1, 1, 1, 0.16) if i % 3 != 0 else Color("#FFD23F", 0.22)
		root.add_child(tri)
	root.scale = Vector2(0.2, 0.2)
	return root


func _wave() -> Node2D:
	var root := Node2D.new()
	var base: float = _size.y * 0.8
	for layer: int in 3:
		var col: Color = [Color("#7C83FD"), Color("#00A6C8"), Color("#2A9FD6")][layer]
		var amp: float = 46.0 - float(layer) * 10.0
		var top := PackedVector2Array()
		var steps: int = 64
		for i: int in steps + 1:
			var x: float = _size.x * float(i) / float(steps)
			var u: float = x / _size.x
			# A cresting wave: tall on the left, curling to the right.
			var y: float = base + float(layer) * 36.0 - amp * sin(u * TAU * 1.0 + 0.6 + float(layer)) \
				- 90.0 * exp(-pow((u - 0.2 - 0.05 * float(layer)) * 5.0, 2.0))
			top.append(Vector2(x, y))
		var poly := PackedVector2Array(top)
		poly.append(Vector2(_size.x, _size.y))
		poly.append(Vector2(0, _size.y))
		var p := Polygon2D.new()
		p.polygon = poly
		p.color = col
		root.add_child(p)
		var foam := Line2D.new()
		foam.points = top
		foam.width = 8.0
		foam.default_color = Color.WHITE
		foam.joint_mode = Line2D.LINE_JOINT_ROUND
		foam.begin_cap_mode = Line2D.LINE_CAP_ROUND
		foam.end_cap_mode = Line2D.LINE_CAP_ROUND
		root.add_child(foam)
		var ink := Line2D.new()
		ink.points = top
		ink.width = 14.0
		ink.default_color = INK
		ink.z_index = -1
		root.add_child(ink)
	return root


func _palm(foot: Vector2, s: float) -> Node2D:
	var root := Node2D.new()
	root.position = foot
	root.scale = Vector2(s, s)
	var trunk := Line2D.new()
	var pts := PackedVector2Array()
	for i: int in 13:
		var u: float = float(i) / 12.0
		pts.append(Vector2(-60.0 * sin(u * 1.6) , -u * 330.0))
	trunk.points = pts
	trunk.width = 18.0
	trunk.default_color = INK
	trunk.begin_cap_mode = Line2D.LINE_CAP_ROUND
	root.add_child(trunk)
	var top: Vector2 = pts[pts.size() - 1]
	for i: int in 7:
		var a: float = deg_to_rad(-170.0 + float(i) * 160.0 / 6.0)
		var frond := Polygon2D.new()
		var dir: Vector2 = Vector2.from_angle(a)
		var side: Vector2 = dir.orthogonal()
		var tip: Vector2 = dir * 150.0 + Vector2(0, 55.0 * absf(cos(a)))
		var mid: Vector2 = dir * 70.0 + Vector2(0, -18.0)
		frond.polygon = PackedVector2Array([Vector2.ZERO, mid + side * 20.0, tip, mid - side * 20.0])
		frond.position = top
		frond.color = INK
		root.add_child(frond)
	root.add_child(_circle(top + Vector2(-6, 8), 9.0, INK, 12))
	return root


func _manga_lines() -> Node2D:
	## Tapered speed lines streaking in from the edges toward the middle.
	var root := Node2D.new()
	var centre: Vector2 = Vector2(_size.x * 0.5, _size.y * 0.42)
	for i: int in 46:
		var a: float = _rng.randf() * TAU
		var d0: float = _rng.randf_range(0.62, 0.9) * _size.x
		var len: float = _rng.randf_range(0.08, 0.2) * _size.x
		var w: float = _rng.randf_range(2.0, 6.0)
		var dir: Vector2 = Vector2.from_angle(a)
		var a0: Vector2 = centre + dir * d0
		var a1: Vector2 = centre + dir * (d0 - len)
		var tri := Polygon2D.new()
		tri.polygon = PackedVector2Array([a0 + dir.orthogonal() * w, a1, a0 - dir.orthogonal() * w])
		tri.color = Color(1, 1, 1, 0.8) if i % 4 != 0 else Color(INK, 0.55)
		root.add_child(tri)
	return root


func _build_board() -> void:
	_board_box = SubViewportContainer.new()
	_board_box.name = "BoardBox"
	_board_box.stretch = true
	_board_box.size = Vector2(BOARD_VIEW)
	_board_box.position = Vector2(-2000, 0)
	_board_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(_board_box)
	var vp := SubViewport.new()
	vp.size = BOARD_VIEW
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	_board_box.add_child(vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.6, 2.4)
	cam.fov = 40.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.5, 2.5), Vector3.ZERO)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#FFE0F0")
	e.ambient_light_energy = 0.9
	env.environment = e
	vp.add_child(env)
	_board_pivot = Node3D.new()
	vp.add_child(_board_pivot)
	var board: Node3D = PlaceholderSkater.build_board()
	board.scale = Vector3.ONE * 3.2
	_board_pivot.add_child(board)


func _build_lettering() -> void:
	var row := Control.new()
	row.name = "Lettering"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_root.add_child(row)
	var font_size: int = 230
	var x: float = 0.0
	var widths: Array[float] = []
	var font: Font = SkateThemeBuilder.heading_font()
	for ch: String in TITLE:
		widths.append(font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x - 4.0 + (70.0 if ch == " " else 0.0))
		x += widths[-1]
	var cursor: float = (_size.x - x) * 0.5
	var idx: int = 0
	for ch: String in TITLE:
		var w: float = widths[idx]
		if ch != " ":
			var l: Label = UiStyle.label(ch, font_size, LETTER_COLORS[idx % LETTER_COLORS.size()], true)
			l.label_settings.outline_size = 36
			l.label_settings.shadow_size = 0
			l.size = Vector2(w, 280)
			l.pivot_offset = Vector2(w * 0.5, 140.0)
			l.position = Vector2(cursor, _size.y * 0.05 + (6.0 if idx % 2 == 0 else -6.0))
			l.rotation = deg_to_rad(-4.0)
			l.scale = Vector2(2.6, 2.6)
			l.modulate.a = 0.0
			row.add_child(l)
			_letters.append(l)
		cursor += w
		idx += 1
	var tag: Label = UiStyle.label(TAGLINE, UiStyle.SIZE_BIG, UiStyle.WHITE)
	tag.name = "Tagline"
	tag.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tag.size = Vector2(_size.x, 60)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.position = Vector2(0, _size.y * 0.05 + 300.0)
	tag.modulate.a = 0.0
	_title_layer.add_child(tag)


func _build_sparkles() -> void:
	var spots: Array[Vector2] = [Vector2(0.14, 0.2), Vector2(0.86, 0.16), Vector2(0.3, 0.55), Vector2(0.72, 0.5),
		Vector2(0.06, 0.6), Vector2(0.94, 0.62), Vector2(0.5, 0.06), Vector2(0.62, 0.34), Vector2(0.38, 0.38)]
	for i: int in spots.size():
		var s := Node2D.new()
		var r: float = 26.0 if i % 2 == 0 else 16.0
		var star := Polygon2D.new()
		var pts := PackedVector2Array()
		for k: int in 8:
			pts.append(Vector2.from_angle(TAU * float(k) / 8.0) * (r if k % 2 == 0 else r * 0.22))
		star.polygon = pts
		star.color = Color.WHITE if i % 3 != 0 else Color("#FFD23F")
		s.add_child(star)
		var rim := Line2D.new()
		rim.points = pts
		rim.closed = true
		rim.width = 3.0
		rim.default_color = INK
		s.add_child(rim)
		s.position = spots[i] * _size
		s.set_meta("base", 1.0)
		s.visible = false
		_shake_root.add_child(s)
		_sparkles.append(s)


func _build_studio_layer() -> void:
	_studio_layer = Control.new()
	_studio_layer.name = "StudioLayer"
	_studio_layer.size = _size
	_studio_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_studio_layer)
	_studio_layer.add_child(_rect(INK))
	var logo := Control.new()
	logo.name = "Logo"
	logo.size = _size
	logo.pivot_offset = _size * 0.5
	logo.modulate.a = 0.0
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_studio_layer.add_child(logo)
	_build_logo(logo)


func _build_wipe() -> void:
	var wipe := Control.new()
	wipe.name = "Wipe"
	wipe.size = _size
	wipe.position = Vector2(-_size.x * 1.3, 0)
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wipe)
	_wipe = wipe
	# Slanted anime-style colour bands wiping across.
	var colors: Array[Color] = [Color("#FF6B5B"), Color("#FFD23F"), Color("#00A6C8"), Color("#FFF6E0")]
	var bands := Node2D.new()
	wipe.add_child(bands)
	for i: int in colors.size():
		var p := Polygon2D.new()
		var x0: float = float(i) * 0.0
		var top: float = float(i) * 0.0
		var skew: float = 180.0
		var inset: float = float(3 - i) * 70.0
		p.polygon = PackedVector2Array([Vector2(-_size.x * 0.3 - x0, -10), Vector2(_size.x + skew - inset, -10),
			Vector2(_size.x - inset, _size.y + 10), Vector2(-_size.x * 0.3 - top, _size.y + 10)])
		p.color = colors[i]
		bands.add_child(p)


func _build_logo(logo: Control) -> void:
	var c: Vector2 = Vector2(_size.x * 0.5, _size.y * 0.5)
	var emblem := Node2D.new()
	emblem.position = c + Vector2(-330.0, -20.0)
	logo.add_child(emblem)
	emblem.add_child(_circle(Vector2.ZERO, 92.0, INK, 40))
	emblem.add_child(_circle(Vector2.ZERO, 80.0, Color("#FF6B5B"), 40))
	# Lightning-bolt flare cut into the emblem.
	var bolt := Polygon2D.new()
	bolt.polygon = PackedVector2Array([Vector2(14, -78), Vector2(-40, 8), Vector2(-4, 8), Vector2(-20, 78), Vector2(46, -12), Vector2(6, -12)])
	bolt.color = Color("#FFD23F")
	emblem.add_child(bolt)
	var bolt_rim := Line2D.new()
	bolt_rim.points = bolt.polygon
	bolt_rim.closed = true
	bolt_rim.width = 5.0
	bolt_rim.default_color = INK
	emblem.add_child(bolt_rim)
	var name_lbl: Label = UiStyle.label(STUDIO_NAME, 128, Color.WHITE)
	name_lbl.label_settings.outline_size = 22
	name_lbl.label_settings.shadow_size = 0
	name_lbl.position = c + Vector2(-210.0, -118.0)
	name_lbl.rotation = deg_to_rad(-3.0)
	logo.add_child(name_lbl)
	var tag: Label = UiStyle.label(STUDIO_TAG, UiStyle.SIZE_BIG, Color("#FFD23F"))
	tag.position = c + Vector2(-190.0, 58.0)
	logo.add_child(tag)
	var underline := Line2D.new()
	underline.points = PackedVector2Array([c + Vector2(-210, 128), c + Vector2(360, 108)])
	underline.width = 8.0
	underline.default_color = Color("#00A6C8")
	underline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	underline.end_cap_mode = Line2D.LINE_CAP_ROUND
	logo.add_child(underline)
