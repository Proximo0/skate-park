class_name UiStyle
extends RefCounted
## Shared look for every UI screen: colour tokens, 1080p font sizes, outlined labels and rounded panels.
## Pure helpers. Sizes are in px at 1920x1080; the viewport stretch scales them with the window.

const SKY_BLUE := Color("#4FC3F7")
const SUNSHINE := Color("#FFD84D")
const BUBBLEGUM := Color("#FF7EB6")
const LIME := Color("#A6E22E")
const WHITE := Color("#FFFFFF")
const INK := Color("#1B1B2F")

const SIZE_TITLE: int = 72
const SIZE_BIG: int = 48
const SIZE_BODY: int = 30
const SIZE_SMALL: int = 22

const OUTLINE_SIZE: int = 8
const SHADOW_OFFSET := Vector2(0, 5)
const SHADOW_SIZE: int = 6
const SHADOW_ALPHA: float = 0.45

const PANEL_RADIUS: int = 18
const PANEL_BORDER: int = 4


## A bright text label with a thick ink outline and a soft drop shadow. Outline makes it read as bold.
static func label(text: String, size: int, color: Color, outline: bool = true) -> Label:
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = color
	if outline:
		settings.outline_size = OUTLINE_SIZE
		settings.outline_color = INK
	var shadow_color := INK
	shadow_color.a = SHADOW_ALPHA
	settings.shadow_size = SHADOW_SIZE
	settings.shadow_color = shadow_color
	settings.shadow_offset = SHADOW_OFFSET
	var lbl := Label.new()
	lbl.text = text
	lbl.label_settings = settings
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


## A rounded panel in the given fill colour with an ink border.
static func panel_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(PANEL_RADIUS)
	sb.set_border_width_all(PANEL_BORDER)
	sb.border_color = INK
	sb.set_content_margin_all(12)
	return sb
