class_name UiStyle
extends RefCounted
## Shared look for every UI screen: colour tokens, 1080p font sizes, outlined labels and rounded panels.
## Pure helpers. Sizes are in px at 1920x1080; the viewport stretch scales them with the window.

## Sunset palette (SkateThemeBuilder holds the master copy). The old token names stay: SKY_BLUE is the teal,
## BUBBLEGUM the coral, SUNSHINE the sunny yellow, LIME the one "go" green, WHITE the off-white, INK the deep navy.
const SKY_BLUE := SkateThemeBuilder.TEAL
const SUNSHINE := SkateThemeBuilder.SUN
const BUBBLEGUM := SkateThemeBuilder.CORAL
const LIME := SkateThemeBuilder.MINT
const WHITE := SkateThemeBuilder.CREAM
const INK := SkateThemeBuilder.NAVY
const MUTED := SkateThemeBuilder.MUTED

const SIZE_TITLE: int = 80
const SIZE_BIG: int = 54
const SIZE_BODY: int = 36
const SIZE_SMALL: int = 28

const OUTLINE_SIZE: int = 10
const SHADOW_OFFSET := Vector2(0, 6)
const SHADOW_SIZE: int = 1
const SHADOW_ALPHA: float = 0.9

const PANEL_RADIUS: int = SkateThemeBuilder.RADIUS
const PANEL_BORDER: int = SkateThemeBuilder.BORDER


## A bright text label with a thick ink outline and a soft drop shadow. Outline makes it read as bold.
static func label(text: String, size: int, color: Color, outline: bool = true) -> Label:
	var settings := LabelSettings.new()
	settings.font = SkateThemeBuilder.heading_font()
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


## A sticker panel in the given fill: thick navy outline, rounded, hard offset drop shadow.
static func panel_style(color: Color) -> StyleBoxFlat:
	return SkateThemeBuilder.sticker(color)


## The same rounded outline without the drop shadow, for bars and tracks drawn inside panels.
static func flat_style(color: Color) -> StyleBoxFlat:
	return SkateThemeBuilder.flat(color)
