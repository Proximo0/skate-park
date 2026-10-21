class_name SkateDeco
extends RefCounted
## Small decorations drawn in code, no art files: halftone dots, speed lines, a wave line, star sparkles.
## Static helpers draw onto any CanvasItem from its _draw(); SkyBackdrop and StickerDots wrap them as Controls.


## Rows of dots that shrink away from `corner` (a point on the rect, e.g. rect.end). Reads as a comic halftone.
static func halftone(ci: CanvasItem, rect: Rect2, spacing: float, max_radius: float, color: Color, corner: Vector2) -> void:
	var reach: float = maxf(rect.size.x, rect.size.y) * 0.9
	var row: int = 0
	var y: float = rect.position.y
	while y <= rect.end.y:
		var x: float = rect.position.x + (spacing * 0.5 if row % 2 == 1 else 0.0)
		while x <= rect.end.x:
			var d: float = Vector2(x, y).distance_to(corner)
			var r: float = max_radius * clampf(1.0 - d / reach, 0.0, 1.0)
			if r > 0.8:
				ci.draw_circle(Vector2(x, y), r, color)
			x += spacing
		y += spacing * 0.866
		row += 1


## Thin wedges fanning out from `center` to beyond `bounds`; `phase` rotates them. Anime impact lines.
static func speed_lines(ci: CanvasItem, center: Vector2, bounds: Rect2, count: int, color: Color, phase: float = 0.0, inner: float = 0.18) -> void:
	var far: float = (bounds.size.length()) * 1.1
	for i: int in count:
		var a: float = phase + TAU * float(i) / float(count)
		var half: float = TAU / float(count) * (0.16 + 0.12 * fposmod(float(i) * 0.618, 1.0))
		var near: float = far * inner * (0.6 + 0.8 * fposmod(float(i) * 0.37, 1.0))
		var pts: PackedVector2Array = [
			center + Vector2.from_angle(a) * near,
			center + Vector2.from_angle(a - half) * far,
			center + Vector2.from_angle(a + half) * far,
		]
		ci.draw_colored_polygon(pts, color)


## A wavy band: filled with `fill` below the crest, with a thick `line` colour crest on top.
static func wave(ci: CanvasItem, x0: float, x1: float, y: float, bottom: float, amp: float, wavelength: float, phase: float, fill: Color, line: Color, thickness: float) -> void:
	var crest: PackedVector2Array = PackedVector2Array()
	var step: float = 12.0
	var x: float = x0
	while x <= x1 + step:
		crest.append(Vector2(x, y + sin(x / wavelength * TAU + phase) * amp))
		x += step
	var poly: PackedVector2Array = crest.duplicate()
	poly.append(Vector2(x - step, bottom))
	poly.append(Vector2(x0, bottom))
	ci.draw_colored_polygon(poly, fill)
	ci.draw_polyline(crest, line, thickness, true)


## A four-point star with a navy rim.
static func sparkle(ci: CanvasItem, pos: Vector2, radius: float, color: Color, rim: Color = SkateThemeBuilder.NAVY) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0 - PI * 0.5
		var r: float = radius if i % 2 == 0 else radius * 0.28
		pts.append(pos + Vector2.from_angle(a) * r)
	pts.append(pts[0])
	ci.draw_polyline(pts, rim, maxf(radius * 0.22, 2.0), true)
	ci.draw_colored_polygon(pts, color)
