class_name ReplayOverlay
extends CanvasLayer
## The replay's screen dressing (ReplayDirector owns it): cinema letterbox, a blinking REPLAY sticker with the
## clip's title, the camera and speed tags, a scrub timeline with the clip clock, the button hints, the photo flash
## and a toast. Sizes are 1920x1080 px like the rest of the UI. Runs while the tree is paused.

const RO_BAR_H: float = 96.0
const RO_TOAST_SECONDS: float = 3.0
const RO_BLINK: float = 0.55
const RO_HINT: String = "Cross/Space  pause     L1 R1 / Q E  scrub     Square/J  slow-mo     Circle/K  camera     " \
	+ "Triangle/I  photo     Start/Esc  exit"
const RO_FREE_HINT: String = "Stick  orbit     L2 R2 / U L  zoom"

var _root: Control
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _dot: Panel
var _title: Label
var _sub: Label
var _cam_tag: Label
var _speed_tag: Label
var _track: Panel
var _fill: Panel
var _head: Panel
var _clock: Label
var _hint: Label
var _toast: Label
var _flash: ColorRect
var _blink_t: float = 0.0
var _toast_left: float = 0.0
var _flash_a: float = 0.0
var _frac: float = 0.0


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_top_bar = _bar(Control.PRESET_TOP_WIDE)
	_bottom_bar = _bar(Control.PRESET_BOTTOM_WIDE)
	_bottom_bar.offset_top = -RO_BAR_H - 40.0

	# REPLAY sticker, top left (sits across the letterbox edge like a broadcast bug)
	var tag := PanelContainer.new()
	var st: StyleBoxFlat = SkateThemeBuilder.sticker(SkateThemeBuilder.CORAL, 16, 4)
	st.content_margin_left = 18.0
	st.content_margin_right = 22.0
	st.content_margin_top = 4.0
	st.content_margin_bottom = 6.0
	tag.add_theme_stylebox_override("panel", st)
	tag.position = Vector2(48, 38)
	tag.rotation_degrees = -3.0
	_root.add_child(tag)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	tag.add_child(row)
	_dot = Panel.new()
	_dot.add_theme_stylebox_override("panel", SkateThemeBuilder.flat(SkateThemeBuilder.CREAM, 11, 0))
	_dot.custom_minimum_size = Vector2(22, 22)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_dot)
	_title = UiStyle.label("REPLAY", 40, SkateThemeBuilder.CREAM)
	row.add_child(_title)
	_sub = UiStyle.label("", 24, SkateThemeBuilder.SUN)
	_sub.position = Vector2(60, 112)
	_root.add_child(_sub)

	# camera + speed tags, top right
	var tags := HBoxContainer.new()
	tags.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tags.alignment = BoxContainer.ALIGNMENT_END
	tags.offset_left = -900.0
	tags.offset_right = -48.0
	tags.offset_top = 30.0
	tags.add_theme_constant_override("separation", 26)
	_root.add_child(tags)
	_cam_tag = UiStyle.label("AUTO", 28, SkateThemeBuilder.CREAM)
	tags.add_child(_cam_tag)
	_speed_tag = UiStyle.label("1x", 28, SkateThemeBuilder.SUN)
	tags.add_child(_speed_tag)

	# timeline
	_track = Panel.new()
	_track.add_theme_stylebox_override("panel", SkateThemeBuilder.flat(Color(SkateThemeBuilder.CREAM, 0.22), 8, 3))
	_track.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_track.offset_left = 220.0
	_track.offset_right = -220.0
	_track.offset_top = -RO_BAR_H - 6.0
	_track.offset_bottom = -RO_BAR_H + 14.0
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_track)
	_fill = Panel.new()
	_fill.add_theme_stylebox_override("panel", SkateThemeBuilder.flat(SkateThemeBuilder.CORAL, 8, 3))
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_fill)
	_head = Panel.new()
	_head.add_theme_stylebox_override("panel", SkateThemeBuilder.flat(SkateThemeBuilder.SUN, 14, 4))
	_head.size = Vector2(28, 36)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_head)
	_clock = UiStyle.label("0.0 / 0.0", 26, SkateThemeBuilder.CREAM)
	_clock.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_clock.offset_left = -205.0
	_clock.offset_right = -40.0
	_clock.offset_top = -RO_BAR_H - 22.0
	_clock.offset_bottom = -RO_BAR_H + 22.0
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_clock)
	_hint = UiStyle.label(RO_HINT, 24, Color(SkateThemeBuilder.CREAM, 0.88), false)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -RO_BAR_H + 30.0
	_hint.offset_bottom = -12.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(_hint)

	_toast = UiStyle.label("", 28, SkateThemeBuilder.CREAM)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -900.0
	_toast.offset_right = 900.0
	_toast.offset_top = 150.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.visible = false
	_root.add_child(_toast)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	_track.resized.connect(_place_head)


func _bar(preset: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.02, 0.05, 0.92)
	r.set_anchors_preset(preset)
	if preset == Control.PRESET_TOP_WIDE:
		r.offset_bottom = RO_BAR_H
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(r)
	return r


## Shows the overlay for a clip titled `title` (the line under the REPLAY sticker).
func open(title: String) -> void:
	_sub.text = title
	_toast.visible = false
	_toast_left = 0.0
	visible = true


## Per-frame state: clip position (s from its start) and length, camera label, speed, paused, free camera.
func show_state(at: float, length: float, cam_label: String, speed: float, paused: bool, free_cam: bool) -> void:
	_frac = clampf(at / maxf(length, 0.001), 0.0, 1.0)
	_clock.text = "%.1f / %.1f" % [at, length]
	_cam_tag.text = cam_label
	var sp: String = "1x" if speed >= 0.99 else ("1/2x" if speed >= 0.49 else "1/4x")
	_speed_tag.text = ("PAUSED  " if paused else "") + sp
	_hint.text = RO_HINT + ("     " + RO_FREE_HINT if free_cam else "")
	_place_head()


func _place_head() -> void:
	if _track == null:
		return
	var w: float = _track.size.x
	_fill.size = Vector2(maxf(w * _frac, 16.0), _track.size.y)
	_head.position = Vector2(w * _frac - _head.size.x * 0.5, (_track.size.y - _head.size.y) * 0.5)


func toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_left = RO_TOAST_SECONDS


## The camera-shutter flash after a photo.
func flash() -> void:
	_flash_a = 0.85


## Hides everything but keeps the toast timer (used for the frame a photo is taken).
func set_chrome(on: bool) -> void:
	_root.visible = on


func _process(delta: float) -> void:
	if not visible:
		return
	_blink_t += delta
	_dot.modulate.a = 1.0 if fmod(_blink_t, RO_BLINK * 2.0) < RO_BLINK else 0.25
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.visible = false
	if _flash_a > 0.0:
		_flash_a = maxf(_flash_a - delta * 3.0, 0.0)
	_flash.color = Color(1, 1, 1, _flash_a)
