class_name LevelSelect
extends Control
## Level select: one sticker card per LevelRegistry entry (preview image, mood tag, name, one-line blurb) on the
## sunset backdrop, three across. Arrows / stick move between cards, Cross or Enter rides the focused one, Circle,
## Esc or Back closes. Emits chosen(id) or closed; the owner (title screen, pause menu) decides what happens next.
## Previews come from LevelRegistry.preview(id) (rendered by tools/level_previews.gd); a level without one gets a
## painted placeholder in its accent colour.

signal chosen(level_id: String)
signal closed

const LS_COLUMNS: int = 3
const LS_CARD_SIZE := Vector2(560, 412)
const LS_IMAGE_SIZE := Vector2(524, 228)
const LS_NAME_FONT: int = 40
const LS_BLURB_FONT: int = 23
const LS_TAG_FONT: int = 22

## Grabs focus on this level's card when the screen opens ("" = the current selection).
var focus_id: String = ""
var _cards: Dictionary = {}  ## id -> Button
var _back: Button
var _detail: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	var want: String = focus_id if focus_id != "" else LevelRegistry.selected
	var card: Button = _cards.get(want, _cards.get(LevelRegistry.DEFAULT_ID)) as Button
	if card != null:
		card.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or _ls_is_circle(event):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.is_action_pressed("ollie"):
		# Godot's ui_accept has no gamepad button here, so Cross presses the focused button.
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus is Button and is_ancestor_of(focus):
			get_viewport().set_input_as_handled()
			(focus as Button).pressed.emit()


func _ls_is_circle(event: InputEvent) -> bool:
	var jb := event as InputEventJoypadButton
	return jb != null and jb.pressed and jb.button_index == JOY_BUTTON_B


func card_ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in _cards:
		out.append(k)
	return out


func _build() -> void:
	add_child(SkyBackdrop.new())
	var shade := ColorRect.new()  # calms the sunset a little behind the cards
	shade.color = Color(SkateThemeBuilder.NAVY, 0.28)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var title := AnimeText.new("PICK A SPOT", 72, SkateThemeBuilder.SUN)
	title.impact_lines = false
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(title)

	var grid := GridContainer.new()
	grid.columns = LS_COLUMNS
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 24)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grid)
	for e: Dictionary in LevelRegistry.entries():
		var card: Button = _card(e)
		grid.add_child(card)
		_cards[str(e["id"])] = card

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 28)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	_back = Button.new()
	_back.text = "Back"
	_back.theme_type_variation = SkateThemeBuilder.BTN_CORAL
	_back.custom_minimum_size = Vector2(240, 66)
	_back.add_theme_font_size_override("font_size", 32)
	_back.pressed.connect(func() -> void: closed.emit())
	_back.mouse_entered.connect(_back.grab_focus)
	bar.add_child(_back)
	_detail = Label.new()
	_detail.text = "Arrows: pick    Cross / Enter: ride    Circle / Esc: back"
	_detail.add_theme_font_override("font", SkateThemeBuilder.heading_font())
	_detail.add_theme_font_size_override("font_size", 28)
	_detail.add_theme_color_override("font_color", SkateThemeBuilder.CREAM)
	_detail.add_theme_color_override("font_outline_color", SkateThemeBuilder.NAVY)
	_detail.add_theme_constant_override("outline_size", 8)
	_detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_detail)

	# Down from the bottom row lands on Back; up from Back returns to the middle card of the last row.
	var ids: Array[String] = card_ids()
	var last_row: int = (ids.size() - 1) / LS_COLUMNS
	for i: int in ids.size():
		if i / LS_COLUMNS == last_row:
			(_cards[ids[i]] as Button).focus_neighbor_bottom = _back.get_path()
	var mid: int = mini(last_row * LS_COLUMNS + 1, ids.size() - 1)
	_back.focus_neighbor_top = (_cards[ids[mid]] as Button).get_path()


## One level card: a cream sticker button holding the preview, a mood tag, the name and the blurb.
func _card(e: Dictionary) -> Button:
	var id: String = str(e["id"])
	var accent: Color = e.get("accent", SkateThemeBuilder.TEAL) as Color
	var b := Button.new()
	b.name = "Card_" + id
	b.theme_type_variation = SkateThemeBuilder.BTN_CREAM
	b.custom_minimum_size = LS_CARD_SIZE
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(func() -> void: chosen.emit(id))

	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	pad.add_theme_constant_override("margin_bottom", 22)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(v)

	var frame := PanelContainer.new()  # navy rounded frame round the preview
	var fs: StyleBoxFlat = SkateThemeBuilder.flat(SkateThemeBuilder.NAVY, 14, 4)
	fs.border_color = SkateThemeBuilder.NAVY
	frame.add_theme_stylebox_override("panel", fs)
	frame.custom_minimum_size = LS_IMAGE_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(frame)
	var tex: Texture2D = LevelRegistry.preview(id)
	if tex != null:
		var img := TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.custom_minimum_size = LS_IMAGE_SIZE - Vector2(8, 8)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(img)
	else:
		var ph := LevelCardArt.new()
		ph.accent = accent
		ph.label = str(e["name"])
		ph.custom_minimum_size = LS_IMAGE_SIZE - Vector2(8, 8)
		frame.add_child(ph)

	var tag := Label.new()  # the mood tag, a sticker on the preview's top-left corner
	tag.text = str(e.get("tag", ""))
	tag.add_theme_font_override("font", SkateThemeBuilder.heading_font())
	tag.add_theme_font_size_override("font_size", LS_TAG_FONT)
	tag.add_theme_color_override("font_color", SkateThemeBuilder.NAVY)
	var ts: StyleBoxFlat = SkateThemeBuilder.sticker(accent, 12, 4)
	ts.content_margin_left = 14.0
	ts.content_margin_right = 14.0
	ts.content_margin_top = 2.0
	ts.content_margin_bottom = 4.0
	ts.shadow_offset = Vector2(0, 4)
	tag.add_theme_stylebox_override("normal", ts)
	tag.position = Vector2(14, 12)
	tag.rotation_degrees = -4.0
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# PanelContainer would stretch the tag over the image; a plain Control holder keeps it at its own size.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tag)
	frame.add_child(holder)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title_row)
	var dot := ColorRect.new()  # accent swatch beside the name
	dot.color = accent
	dot.custom_minimum_size = Vector2(14, 34)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(dot)
	var name_l := MenuKit.text(str(e["name"]), LS_NAME_FONT, SkateThemeBuilder.NAVY)
	name_l.add_theme_font_override("font", SkateThemeBuilder.heading_font())
	title_row.add_child(name_l)

	var blurb := MenuKit.text(str(e["blurb"]), LS_BLURB_FONT, SkateThemeBuilder.MUTED)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(LS_IMAGE_SIZE.x, 0)
	v.add_child(blurb)
	return b


## The painted stand-in for a level without a rendered preview: a sky gradient in the level's accent, a sun and a
## skyline silhouette, so the card never shows an empty box.
class LevelCardArt:
	extends Control
	var accent: Color = SkateThemeBuilder.TEAL
	var label: String = ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var top: Color = accent.darkened(0.55)
		var bottom: Color = accent.lightened(0.25)
		var n: int = 24
		for i: int in n:
			var y0: float = r.size.y * float(i) / float(n)
			draw_rect(Rect2(0.0, y0, r.size.x, r.size.y / float(n) + 1.0), top.lerp(bottom, float(i) / float(n - 1)))
		draw_circle(Vector2(r.size.x * 0.72, r.size.y * 0.62), r.size.y * 0.26, Color(SkateThemeBuilder.SUN, 0.9))
		var x: float = 0.0
		var k: int = 0
		while x < r.size.x:
			var w: float = 26.0 + float((k * 37) % 41)
			var h: float = r.size.y * (0.18 + float((k * 53) % 29) / 80.0)
			draw_rect(Rect2(x, r.size.y - h, w, h), SkateThemeBuilder.NAVY)
			x += w + 4.0
			k += 1
