class_name SkyBackdrop
extends Control
## Full-screen sunset backdrop for menus, all drawn in code: gradient sky, a half sun, speed lines, halftone dots,
## a wave line at the bottom and twinkling sparkles. With overlay = true it skips the sky and sun and only adds
## the decorations (the title screen draws them over its 3D scene).

var overlay: bool = false
var sparkles: bool = true  ## off for text-dense screens (controls)
var _time: float = 0.0
var _sparkles: PackedVector2Array = PackedVector2Array()


func _init(overlay_only: bool = false) -> void:
	overlay = overlay_only
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2026
	for i: int in 14:
		_sparkles.append(Vector2(rng.randf(), rng.randf() * 0.7))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, _extent())
	if r.size.x < 2.0:
		return
	if not overlay:
		_draw_sky(r)
	SkateDeco.speed_lines(self, Vector2(r.size.x * 0.78, r.size.y * 0.42), r, 28,
			Color(SkateThemeBuilder.CREAM, 0.07 if not overlay else 0.1), _time * 0.03)
	SkateDeco.halftone(self, Rect2(0.0, r.size.y * 0.45, r.size.x * 0.5, r.size.y * 0.55), 26.0, 9.0,
			Color(SkateThemeBuilder.CREAM, 0.22), Vector2(0.0, r.size.y))
	SkateDeco.halftone(self, Rect2(r.size.x * 0.6, 0.0, r.size.x * 0.4, r.size.y * 0.4), 26.0, 8.0,
			Color(SkateThemeBuilder.NAVY, 0.2), Vector2(r.size.x, 0.0))
	var base: float = r.size.y * 0.95
	SkateDeco.wave(self, 0.0, r.size.x, base, r.size.y, 12.0, 340.0, _time * 1.2,
			Color(SkateThemeBuilder.TEAL, 0.9), SkateThemeBuilder.CREAM, 6.0)
	SkateDeco.wave(self, 0.0, r.size.x, base + 26.0, r.size.y, 9.0, 260.0, -_time * 0.9 + 1.0,
			SkateThemeBuilder.NAVY, SkateThemeBuilder.TEAL.lightened(0.25), 4.0)
	for i: int in (_sparkles.size() if sparkles else 0):
		var s: Vector2 = _sparkles[i]
		var tw: float = 0.5 + 0.5 * sin(_time * 2.4 + float(i) * 1.9)
		var col: Color = SkateThemeBuilder.SUN if i % 3 != 0 else SkateThemeBuilder.CREAM
		SkateDeco.sparkle(self, Vector2(s.x * r.size.x, s.y * r.size.y), 8.0 + 12.0 * tw, col)


## Our size, or the viewport's when the parent has none (a Control directly under a CanvasLayer stays 0x0).
func _extent() -> Vector2:
	return size if size.x >= 2.0 and size.y >= 2.0 else get_viewport_rect().size


func _draw_sky(r: Rect2) -> void:
	var stops: PackedColorArray = [Color("#2B2F6B"), Color("#B8456F"), SkateThemeBuilder.CORAL, Color("#FF9A55"), SkateThemeBuilder.SUN]
	var n: int = stops.size() - 1
	for i: int in n:
		var y0: float = r.size.y * float(i) / float(n)
		var y1: float = r.size.y * float(i + 1) / float(n)
		var pts: PackedVector2Array = [Vector2(0, y0), Vector2(r.size.x, y0), Vector2(r.size.x, y1), Vector2(0, y1)]
		var cols: PackedColorArray = [stops[i], stops[i], stops[i + 1], stops[i + 1]]
		draw_polygon(pts, cols)
	var sun_c: Vector2 = Vector2(r.size.x * 0.78, r.size.y * 0.42)
	draw_circle(sun_c, r.size.y * 0.2, Color(SkateThemeBuilder.SUN, 0.35))
	draw_circle(sun_c, r.size.y * 0.15, SkateThemeBuilder.SUN)
