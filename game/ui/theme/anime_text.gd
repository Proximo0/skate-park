class_name AnimeText
extends Control
## Anime action text: heavy condensed letters, skewed forward, a cream rim inside a thick navy outline, a hard drop
## shadow and optional impact lines behind. pop(text) sets the text and plays the pop-in (slam from big, overshoot,
## settle at a small tilt). Used for trick names, +points and Bail! on the HUD, and title lettering.

var text: String = "":
	set(v):
		if v == text:
			return
		text = v
		_refit()
var font_size: int = UiStyle.SIZE_BIG:
	set(v):
		font_size = v
		_refit()
var fill: Color = SkateThemeBuilder.SUN
var rim: Color = SkateThemeBuilder.CREAM
var skew: float = 0.22
var tilt_degrees: float = -4.0
var impact_lines: bool = true
var _outline: int = 12
var _burst: float = 0.0
var _tween: Tween


func _init(txt: String = "", size_px: int = UiStyle.SIZE_BIG, fill_color: Color = SkateThemeBuilder.SUN) -> void:
	fill = fill_color
	font_size = size_px
	text = txt
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotation_degrees = tilt_degrees


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5


func _pad() -> float:
	return float(_outline) * 1.3 + 4.0


func _refit() -> void:
	_outline = maxi(int(float(font_size) * 0.13), 6)
	var font: Font = SkateThemeBuilder.heading_font()
	var s: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	custom_minimum_size = Vector2(s.x + _pad() * 2.0 + float(font_size) * skew, s.y + _pad() * 2.0 + 8.0)
	pivot_offset = size * 0.5
	queue_redraw()


func _draw() -> void:
	if text == "":
		return
	var font: Font = SkateThemeBuilder.heading_font()
	var s: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var centre: Vector2 = size * 0.5
	if impact_lines and _burst > 0.01:
		SkateDeco.speed_lines(self, centre, Rect2(Vector2.ZERO, size * 1.6), 22,
				Color(rim, 0.55 * _burst), 0.0, 0.1 + 0.3 * (1.0 - _burst))
	var base_y: float = centre.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var origin: Vector2 = Vector2(centre.x - s.x * 0.5, base_y)
	# Shear around the baseline so the tops lean forward.
	draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(-skew, 1.0), Vector2(skew * base_y, 0.0)))
	var navy: Color = SkateThemeBuilder.NAVY
	draw_string_outline(font, origin + Vector2(0.0, 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _outline * 2, navy)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _outline * 2, navy)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _outline, rim)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fill)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Sets the text and plays the pop-in: slam in big and crooked, overshoot, settle. Impact lines flash behind.
func pop(new_text: String) -> void:
	text = new_text
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	scale = Vector2(1.7, 1.7)
	rotation_degrees = tilt_degrees - 7.0
	_burst = 1.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation_degrees", tilt_degrees, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_burst, 1.0, 0.0, 0.45)


func _set_burst(v: float) -> void:
	_burst = v
	queue_redraw()
