class_name MenuKit
extends RefCounted
## Shared pieces for the full-screen menus (character creator, skate shop): sky backdrop, white panels,
## chunky buttons in the title screen style. Pure helpers, sizes in 1920x1080 px.

const BUTTON_RADIUS: int = 18
const PANEL_FILL := Color("#FFFFFF")
const SOFT_FILL := Color("#EAF7FF")
const BAD := Color("#E0455A")


## A vertical sky gradient that fills its parent.
static func backdrop() -> TextureRect:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color("#4FC3F7"))
	g.set_color(1, Color("#D8F3FF"))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var r: TextureRect = TextureRect.new()
	r.texture = tex
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func panel(fill: Color = PANEL_FILL) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = UiStyle.panel_style(fill)
	sb.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func button_box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = UiStyle.panel_style(color)
	box.set_corner_radius_all(BUTTON_RADIUS)
	box.set_content_margin_all(8)
	return box


static func style_button(button: Button, color: Color, font_size: int = UiStyle.SIZE_BODY) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(key, UiStyle.INK)
	button.add_theme_stylebox_override("normal", button_box(color))
	button.add_theme_stylebox_override("hover", button_box(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", button_box(color.darkened(0.12)))
	button.add_theme_stylebox_override("disabled", button_box(color.darkened(0.05)))
	var focus: StyleBoxFlat = button_box(UiStyle.SUNSHINE)
	focus.border_color = UiStyle.WHITE
	focus.set_border_width_all(6)
	button.add_theme_stylebox_override("focus", focus)


## Plain ink-coloured label for use on white panels.
static func text(txt: String, size: int, color: Color = UiStyle.INK) -> Label:
	var l: Label = Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
