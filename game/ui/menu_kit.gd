class_name MenuKit
extends RefCounted
## Shared pieces for the full-screen menus (character creator, skate shop): sunset backdrop, sticker panels and
## buttons. Looks come from the shared theme (game/ui/theme); these helpers just pick theme type variations.
## Pure helpers, sizes in 1920x1080 px.

const BAD := Color("#D6293F")


## The animated sunset backdrop; fills its parent.
static func backdrop() -> SkyBackdrop:
	return SkyBackdrop.new()


## A sticker panel. `variation` is one of SkateThemeBuilder.PNL_*; the default cream one gets corner halftone dots.
static func panel(variation: StringName = SkateThemeBuilder.PNL_CREAM) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.theme_type_variation = variation
	if variation == SkateThemeBuilder.PNL_CREAM:
		p.add_child(StickerDots.new())
	return p


## Gives a button one of the themed looks (SkateThemeBuilder.BTN_*); the theme owns colours, outline and focus ring.
static func style_button(button: Button, variation: StringName) -> void:
	button.theme_type_variation = variation


## Plain navy label for use on cream panels.
static func text(txt: String, size: int, color: Color = UiStyle.INK) -> Label:
	var l: Label = Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
