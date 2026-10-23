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
const LS_CARD_SIZE := Vector2(560, 392)
const LS_IMAGE_SIZE := Vector2(524, 148)
const LS_NAME_FONT: int = 40
const LS_BLURB_FONT: int = 23
const LS_TAG_FONT: int = 22
const LS_STAT_FONT: int = 24

## Grabs focus on this level's card when the screen opens ("" = the current selection).
var focus_id: String = ""
var _cards: Dictionary = {}  ## id -> Button
var _back: Button
var _detail: Label
var _unlock_btn: Button
var _session_btns: Dictionary = {}  ## session id -> Button (the 2:00 / 5:00 / free skate picker)
## Career numbers (stars, goals, bests, locks). The shared store by default; tests hand in their own before add_child.
var store: ProgressStore = null
var _locks: Dictionary = {}  ## id -> Control (the LOCKED cover over the preview)
var _lock_texts: Dictionary = {}  ## id -> Label
var _stat_texts: Dictionary = {}  ## id -> Label
var _medals: Dictionary = {}  ## id -> MedalDisc (the Pro Challenge medal beside the stars)
var _pro_texts: Dictionary = {}  ## id -> Label ("PRO Pool Row: Gold medal")


func _ready() -> void:
	if store == null:
		store = ProgressStore.shared()
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
	elif event.is_action_pressed("spin_left") or event.is_action_pressed("spin_right"):
		get_viewport().set_input_as_handled()
		_set_session(SessionMode.cycle(store.session, -1 if event.is_action_pressed("spin_left") else 1))
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
	_refresh_locks()

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 28)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	_back = Button.new()
	_back.text = "Back"
	_back.theme_type_variation = SkateThemeBuilder.BTN_CORAL
	_back.custom_minimum_size = Vector2(200, 66)
	_back.add_theme_font_size_override("font_size", 32)
	_back.pressed.connect(func() -> void: closed.emit())
	_back.mouse_entered.connect(_back.grab_focus)
	bar.add_child(_back)
	var seg := HBoxContainer.new()  # the session picker: how long the run is
	seg.name = "SessionPicker"
	seg.add_theme_constant_override("separation", 10)
	seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(seg)
	var prev: Button = _back
	for m: Dictionary in SessionMode.MODES:
		var sb := Button.new()
		sb.name = "Session_" + str(m["id"])
		sb.text = str(m["label"])
		sb.custom_minimum_size = Vector2(185, 66)
		sb.add_theme_font_size_override("font_size", 26)
		sb.pressed.connect(_set_session.bind(str(m["id"])))
		sb.mouse_entered.connect(sb.grab_focus)
		sb.focus_entered.connect(_show_session_blurb.bind(str(m["id"])))
		sb.focus_exited.connect(_show_session_blurb.bind(store.session))
		seg.add_child(sb)
		_session_btns[str(m["id"])] = sb
		prev.focus_neighbor_right = sb.get_path()
		sb.focus_neighbor_left = prev.get_path()
		prev = sb
	_unlock_btn = Button.new()
	_unlock_btn.name = "UnlockAll"
	_unlock_btn.theme_type_variation = SkateThemeBuilder.BTN_TEAL
	_unlock_btn.custom_minimum_size = Vector2(250, 66)
	_unlock_btn.add_theme_font_size_override("font_size", 26)
	_unlock_btn.pressed.connect(_on_unlock_all)
	_unlock_btn.mouse_entered.connect(_unlock_btn.grab_focus)
	bar.add_child(_unlock_btn)
	prev.focus_neighbor_right = _unlock_btn.get_path()
	_unlock_btn.focus_neighbor_left = prev.get_path()
	_detail = Label.new()
	_detail.text = ""
	_detail.add_theme_font_override("font", SkateThemeBuilder.heading_font())
	_detail.add_theme_font_size_override("font_size", 24)
	_detail.custom_minimum_size = Vector2(420, 0)
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
	_refresh_locks()


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
	b.pressed.connect(func() -> void: _on_card_pressed(id, b))

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

	var lock := _lock_cover()
	frame.add_child(lock)
	_locks[id] = lock
	_lock_texts[id] = lock.find_child("LockText", true, false)

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
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(spacer)
	var stars := StarRow.new()
	stars.name = "Stars"
	stars.count = store.stars(id)
	title_row.add_child(stars)

	var blurb := MenuKit.text(str(e["blurb"]), LS_BLURB_FONT, SkateThemeBuilder.MUTED)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(LS_IMAGE_SIZE.x, 0)
	v.add_child(blurb)
	var stat := MenuKit.text(stat_line(id), LS_STAT_FONT, accent.darkened(0.45))
	stat.name = "Stat"
	stat.add_theme_font_override("font", SkateThemeBuilder.heading_font())
	var stat_row := HBoxContainer.new()
	stat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(stat_row)
	stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_row.add_child(stat)
	_stat_texts[id] = stat
	var disc := MedalDisc.new()
	disc.name = "Medal"
	disc.medal = store.medal(id)
	stat_row.add_child(disc)
	_medals[id] = disc
	var pro := MenuKit.text(pro_line(id), LS_BLURB_FONT - 3, accent.darkened(0.45))
	pro.name = "ProLine"
	v.add_child(pro)
	_pro_texts[id] = pro
	return b


## "Goals 5/12   Best 12,400" (or "No runs yet").
func stat_line(id: String) -> String:
	var total: int = ProgressStore.goal_total(id)
	var line: String = "Goals %d/%d" % [store.goals_done_count(id), total]
	if store.best_score(id) > 0:
		line += "    Best %s" % Hud.format_points(store.best_score(id))
	return line


## "PRO Pool Row: Gold medal" (or "PRO Pool Row: no medal yet"); "" for a level without a Pro Challenge.
func pro_line(id: String) -> String:
	var info: Dictionary = ProgressStore.pro_info(id)
	if info.is_empty():
		return ""
	var m: int = ProgressStore.medal_of(info, store.goals_done(id))
	return "PRO %s: %s" % [info["name"], ProgressStore.medal_name(m) if m > 0 else "no medal yet"]


func _lock_cover() -> Control:
	var c := ColorRect.new()
	c.color = Color(SkateThemeBuilder.NAVY, 0.82)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(box)
	var head := AnimeText.new("LOCKED", 56, SkateThemeBuilder.CORAL)
	head.impact_lines = false
	head.custom_minimum_size = Vector2(0, 80)
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(head)
	var t := MenuKit.text("", 26, SkateThemeBuilder.CREAM)
	t.name = "LockText"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	return c


## Locked cards show the cover and say how many goals open them.
func _refresh_locks() -> void:
	for id: String in _locks:
		var need: int = store.goals_to_unlock(id)
		(_locks[id] as Control).visible = need > 0
		(_lock_texts[id] as Label).text = "Finish %d more goal%s" % [need, "" if need == 1 else "s"]
		(_stat_texts[id] as Label).text = stat_line(id)
		if _medals.has(id):
			(_medals[id] as MedalDisc).medal = store.medal(id)
			(_medals[id] as MedalDisc).queue_redraw()
		if _pro_texts.has(id):
			(_pro_texts[id] as Label).text = pro_line(id)
	if _unlock_btn != null:
		_unlock_btn.text = "Unlock all: %s" % ("On" if store.unlock_all else "Off")
	_refresh_session()


## Marks the picked session (sun yellow, the rest cream) and shows its one-liner.
func _refresh_session() -> void:
	for id: String in _session_btns:
		(_session_btns[id] as Button).theme_type_variation = SkateThemeBuilder.BTN_SUN if id == store.session else SkateThemeBuilder.BTN_CREAM
	_show_session_blurb(store.session)


func _show_session_blurb(id: String) -> void:
	if _detail != null:
		_detail.text = str(SessionMode.mode(id)["blurb"]) + "   [Q / E]"


func _set_session(id: String) -> void:
	store.session = id
	store.save()
	_refresh_session()


func _on_unlock_all() -> void:
	store.unlock_all = not store.unlock_all
	store.save()
	_refresh_locks()


func _on_card_pressed(id: String, card: Button) -> void:
	if not store.is_unlocked(id):
		var tw := card.create_tween()  # a small refusal shake
		for dx: float in [-10.0, 10.0, -6.0, 0.0]:
			tw.tween_property(card, "rotation_degrees", dx * 0.2, 0.05)
		return
	chosen.emit(id)


## Three stars drawn as polygons (the heading font has no star glyph): filled gold up to `count`, outlined after.
class StarRow:
	extends Control
	var count: int = 0

	func _init() -> void:
		custom_minimum_size = Vector2(108, 36)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i: int in 3:
			var c := Vector2(17.0 + 36.0 * i, 19.0)
			var pts := PackedVector2Array()
			for k: int in 10:
				var r: float = 16.0 if k % 2 == 0 else 7.0
				var a: float = -PI / 2.0 + TAU * float(k) / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			var on: bool = i < count
			draw_colored_polygon(pts, SkateThemeBuilder.SUN if on else Color(SkateThemeBuilder.MUTED, 0.25))
			pts.append(pts[0])
			draw_polyline(pts, SkateThemeBuilder.NAVY, 3.0, true)


## The Pro Challenge medal: a round disc (bronze, silver or gold) with a ribbon notch, a faint ring while unearned.
class MedalDisc:
	extends Control
	const COLORS: Array[Color] = [Color("c9803f"), Color("c3ccd6"), Color("ffc93c")]
	var medal: int = 0

	func _init() -> void:
		custom_minimum_size = Vector2(40, 36)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(20.0, 19.0)
		if medal <= 0:
			draw_arc(c, 13.0, 0.0, TAU, 24, Color(SkateThemeBuilder.MUTED, 0.4), 3.0, true)
			return
		var col: Color = COLORS[clampi(medal, 1, 3) - 1]
		draw_circle(c, 15.0, SkateThemeBuilder.NAVY)
		draw_circle(c, 12.0, col)
		draw_arc(c, 8.0, 0.3, TAU - 0.3, 20, col.darkened(0.3), 2.0, true)
		draw_circle(c + Vector2(-4.0, -4.0), 2.5, col.lightened(0.5))


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
