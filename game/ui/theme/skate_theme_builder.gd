class_name SkateThemeBuilder
extends RefCounted
## Builds the one shared Theme (game/ui/theme/skate_theme.tres, set as gui/theme/custom in project.godot):
## skate sticker panels (thick navy outline, offset hard drop shadow), sunset palette, a bold condensed font,
## chunky buttons with a gamepad-readable focus ring. tools/build_theme.gd saves the result; tests may call build().
## Sizes are 1920x1080 px like the rest of the UI. Button tilt on hover/focus lives in UiFx.

const THEME_PATH: String = "res://game/ui/theme/skate_theme.tres"
const FONT_PATH: String = "res://game/ui/theme/fonts/Inter-ExtraBold.otf"

const CORAL := Color("#FF6B5B")
const TEAL := Color("#00A6C8")
const SUN := Color("#FFD23F")
const NAVY := Color("#1B1F3B")
const CREAM := Color("#FFF6E9")
const MINT := Color("#3DDC97")  ## the one extra: "go" / success green
const MUTED := Color("#4A5170")  ## secondary text on cream

const BORDER: int = 5
const RADIUS: int = 22
const SHADOW_OFFSET := Vector2(0, 8)
const FOCUS_RING: int = 6

## Theme type variations (set Control.theme_type_variation to one of these).
const BTN_CORAL: StringName = &"CoralButton"
const BTN_TEAL: StringName = &"TealButton"
const BTN_SUN: StringName = &"SunButton"
const BTN_NAVY: StringName = &"NavyButton"
const BTN_CREAM: StringName = &"CreamButton"
const BTN_MINT: StringName = &"MintButton"
const BTN_ROW: StringName = &"RowButton"
const LBL_HEADING: StringName = &"HeadingLabel"
const LBL_RIBBON: StringName = &"RibbonLabel"
const PNL_CREAM: StringName = &"CreamPanel"
const PNL_TEAL: StringName = &"TealPanel"
const PNL_CORAL: StringName = &"CoralPanel"
const PNL_SUN: StringName = &"SunPanel"
const PNL_NAVY: StringName = &"NavyPanel"
const PNL_GLASS: StringName = &"GlassPanel"

static var _body: Font = null
static var _heading: Font = null


## The bold body font: Inter ExtraBold (bundled, OFL), a touch condensed. Falls back to a system sans.
static func body_font() -> Font:
	if _body == null:
		_body = _variation(0.92, 0.0)
	return _body


## The heading font: same family pushed condensed and heavier, for titles, buttons and action text.
static func heading_font() -> Font:
	if _heading == null:
		_heading = _variation(0.84, 0.3)
	return _heading


static func _variation(x_scale: float, embolden: float) -> Font:
	var fv: FontVariation = FontVariation.new()
	if ResourceLoader.exists(FONT_PATH):
		fv.base_font = load(FONT_PATH) as Font
	else:
		var sys: SystemFont = SystemFont.new()
		sys.font_names = PackedStringArray(["Impact", "Arial Narrow", "Liberation Sans Narrow", "Inter", "Arial", "sans-serif"])
		sys.font_weight = 800
		fv.base_font = sys
	fv.variation_transform = Transform2D(Vector2(x_scale, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
	fv.variation_embolden = embolden
	return fv


## A sticker box: thick navy outline, rounded, hard offset drop shadow.
static func sticker(fill: Color, radius: int = RADIUS, border: int = BORDER, shadow: bool = true) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = NAVY
	sb.set_content_margin_all(14)
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = Color(NAVY, 0.9)
		sb.shadow_size = 2
		sb.shadow_offset = SHADOW_OFFSET
	return sb


## A rounded box with no shadow, for bars and tracks inside panels.
static func flat(fill: Color, radius: int = RADIUS, border: int = BORDER) -> StyleBoxFlat:
	return sticker(fill, radius, border, false)


static func build() -> Theme:
	var t: Theme = Theme.new()
	t.default_font = body_font()
	t.default_font_size = 30
	_labels(t)
	_panels(t)
	_buttons(t)
	_bars(t)
	return t


static func _labels(t: Theme) -> void:
	t.set_color("font_color", "Label", CREAM)
	t.set_type_variation("HeadingLabel", "Label")
	t.set_font("font", "HeadingLabel", heading_font())
	t.set_font_size("font_size", "HeadingLabel", 56)
	t.set_color("font_color", "HeadingLabel", SUN)
	t.set_color("font_outline_color", "HeadingLabel", NAVY)
	t.set_constant("outline_size", "HeadingLabel", 12)
	t.set_color("font_shadow_color", "HeadingLabel", Color(NAVY, 0.9))
	t.set_constant("shadow_offset_x", "HeadingLabel", 0)
	t.set_constant("shadow_offset_y", "HeadingLabel", 6)
	t.set_font("font", "Button", heading_font())
	# A coral ribbon with condensed cream lettering (title subtitle, banners).
	t.set_type_variation("RibbonLabel", "Label")
	t.set_font("font", "RibbonLabel", heading_font())
	t.set_font_size("font_size", "RibbonLabel", 48)
	t.set_color("font_color", "RibbonLabel", CREAM)
	t.set_color("font_outline_color", "RibbonLabel", NAVY)
	t.set_constant("outline_size", "RibbonLabel", 8)
	var ribbon: StyleBoxFlat = sticker(CORAL, 18, 5)
	ribbon.content_margin_left = 28.0
	ribbon.content_margin_right = 28.0
	ribbon.content_margin_top = 4.0
	ribbon.content_margin_bottom = 8.0
	t.set_stylebox("normal", "RibbonLabel", ribbon)


static func _panels(t: Theme) -> void:
	var fills: Dictionary = {
		PNL_CREAM: CREAM, PNL_TEAL: TEAL, PNL_CORAL: CORAL, PNL_SUN: SUN, PNL_NAVY: NAVY,
		PNL_GLASS: Color(CREAM, 0.4),
	}
	t.set_stylebox("panel", "Panel", sticker(CREAM))
	t.set_stylebox("panel", "PanelContainer", sticker(CREAM))
	for v: StringName in fills:
		t.set_type_variation(v, "PanelContainer")
		var sb: StyleBoxFlat = sticker(fills[v])
		sb.set_content_margin_all(18)
		if v == PNL_GLASS:
			sb.shadow_color = Color(NAVY, 0.5)
		t.set_stylebox("panel", String(v), sb)
	t.set_stylebox("panel", "TooltipPanel", sticker(NAVY, 14, 3))
	t.set_color("font_color", "TooltipLabel", CREAM)


static func _buttons(t: Theme) -> void:
	# Plain Button: compact sticker (dev panels, anything unstyled).
	_button(t, "Button", SUN, NAVY, 10, 3, 6)
	var chunky: Dictionary = {
		BTN_CORAL: [CORAL, NAVY], BTN_TEAL: [TEAL, NAVY], BTN_SUN: [SUN, NAVY],
		BTN_NAVY: [NAVY, CREAM], BTN_CREAM: [CREAM, NAVY], BTN_MINT: [MINT, NAVY],
	}
	for v: StringName in chunky:
		t.set_type_variation(v, "Button")
		_button(t, String(v), chunky[v][0], chunky[v][1], 20, BORDER, 8)
	# Menu rows: cream, flat-ish, the focused row fills sunny yellow.
	t.set_type_variation(BTN_ROW, "Button")
	_button(t, String(BTN_ROW), Color("#FFFFFF"), NAVY, 16, 4, 5)
	var row_focus: StyleBoxFlat = sticker(SUN, 16, 6, true)
	row_focus.shadow_offset = Vector2(0, 5)
	t.set_stylebox("focus", String(BTN_ROW), row_focus)


## Normal / hover / pressed / disabled / focus boxes plus font colours for one button type.
static func _button(t: Theme, type: String, fill: Color, ink: Color, radius: int, border: int, lift: float) -> void:
	var n: StyleBoxFlat = sticker(fill, radius, border)
	n.shadow_offset = Vector2(0, lift)
	n.set_content_margin_all(10)
	var h: StyleBoxFlat = sticker(fill.lightened(0.18), radius, border)
	h.shadow_offset = Vector2(0, lift + 2.0)
	h.set_content_margin_all(10)
	var p: StyleBoxFlat = sticker(fill.darkened(0.12), radius, border)
	p.shadow_offset = Vector2(0, maxf(lift - 6.0, 1.0))
	p.content_margin_top = 14.0
	p.content_margin_bottom = 6.0
	var d: StyleBoxFlat = sticker(fill.lerp(Color("#B8B4AA"), 0.4), radius, border)
	d.shadow_offset = Vector2(0, maxf(lift - 4.0, 1.0))
	d.set_content_margin_all(10)
	var ring: StyleBoxFlat = StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_corner_radius_all(radius + 6)
	ring.set_border_width_all(FOCUS_RING)
	ring.border_color = CREAM if fill == SUN else SUN
	ring.set_expand_margin_all(float(FOCUS_RING) - 1.0)
	ring.shadow_color = NAVY
	ring.shadow_size = 3
	ring.shadow_offset = Vector2.ZERO
	ring.anti_aliasing = true
	t.set_stylebox("normal", type, n)
	t.set_stylebox("hover", type, h)
	t.set_stylebox("pressed", type, p)
	t.set_stylebox("hover_pressed", type, p)
	t.set_stylebox("disabled", type, d)
	t.set_stylebox("focus", type, ring)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(key, type, ink)
	t.set_color("font_disabled_color", type, Color(ink, 0.7))
	t.set_color("font_outline_color", type, Color(ink, 0.0))
	t.set_font_size("font_size", type, 36)


static func _bars(t: Theme) -> void:
	t.set_stylebox("background", "ProgressBar", flat(CREAM, 12, 4))
	t.set_stylebox("fill", "ProgressBar", flat(TEAL, 8, 0))
	t.set_color("font_color", "ProgressBar", NAVY)
	for bar: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, flat(Color(NAVY, 0.25), 8, 0))
		t.set_stylebox("grabber", bar, flat(CORAL, 8, 3))
		t.set_stylebox("grabber_highlight", bar, flat(SUN, 8, 3))
		t.set_stylebox("grabber_pressed", bar, flat(SUN.darkened(0.1), 8, 3))
	t.set_stylebox("normal", "LineEdit", flat(CREAM, 12, 3))
	t.set_stylebox("focus", "LineEdit", flat(Color("#FFFFFF"), 12, 5))
	t.set_color("font_color", "LineEdit", NAVY)
	t.set_color("caret_color", "LineEdit", CORAL)
