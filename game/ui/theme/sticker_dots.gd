class_name StickerDots
extends Control
## Halftone dots in the top-right and bottom-left corners of a sticker panel. Add as a child of the panel;
## it ignores the mouse and draws under the panel's other children when added first.


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = false
	clip_contents = true


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var w: float = minf(size.x * 0.5, 260.0)
	var h: float = minf(size.y * 0.5, 200.0)
	var col: Color = Color(SkateThemeBuilder.CORAL, 0.16)
	SkateDeco.halftone(self, Rect2(r.size.x - w, 0.0, w, h), 20.0, 7.0, col, Vector2(r.size.x, 0.0))
	SkateDeco.halftone(self, Rect2(0.0, r.size.y - h, w, h), 20.0, 7.0, Color(SkateThemeBuilder.TEAL, 0.16), Vector2(0.0, r.size.y))
