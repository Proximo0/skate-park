class_name ResultsScreen
extends CanvasLayer
## THUG2-style end-of-run card, shown when the run timer hits zero: score, best combo, goals done this run, new
## records flagged, and three ways on: Retry, Free Skate (keep skating, no clock) or Level Select. When the game's
## ReplayDirector kept a clip of the run's best combo, a fourth button, Watch Replay, plays it (the card hides and
## comes back when the replay closes).
## The owner (GoalsPanel) pauses the tree while it is open; this layer keeps running (PROCESS_MODE_ALWAYS).
## Cross / Enter presses the focused button, like the level select.

signal retry_pressed
signal free_skate_pressed
signal level_select_pressed
signal replay_pressed

const RS_PANEL_MIN := Vector2(1060, 0)
const RS_GOAL_ROWS: int = 5
const RS_COUNT_TIME: float = 1.1

var data: Dictionary = {}
var _score_label: Label
var _combo_label: Label
var _retry: Button
var _free: Button
var _levels: Button
var _replay: Button = null
var _tween: Tween


## data: level_name, score, best_combo, goals (Array of titles done this run), goals_done, goals_total, stars,
## record_score, record_combo (bool), best_score, best_combo_ever (int, the record to beat), coins (int earned).
func setup(d: Dictionary) -> ResultsScreen:
	data = d
	return self


## "+3 goals" style summary line for the goals row.
static func goals_line(this_run: int, done: int, total: int) -> String:
	return "%d this run   -   %d / %d done" % [this_run, done, total]


static func stars_text(n: int) -> String:
	return "*".repeat(clampi(n, 0, 3)) + "-".repeat(3 - clampi(n, 0, 3))


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func focus_default() -> void:
	if _retry != null:
		_retry.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()  # the pause menu must not open over the card
	elif event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		retry_pressed.emit()
	elif event.is_action_pressed("ollie"):
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus is Button and _root_has(focus):
			get_viewport().set_input_as_handled()
			(focus as Button).pressed.emit()


func _root_has(n: Node) -> bool:
	return is_ancestor_of(n)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.09, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Card"
	panel.theme_type_variation = SkateThemeBuilder.PNL_NAVY
	panel.custom_minimum_size = RS_PANEL_MIN
	panel.add_child(StickerDots.new())
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	pad.add_child(col)

	var title := AnimeText.new("TIME'S UP!", UiStyle.SIZE_TITLE, UiStyle.SUNSHINE)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(title)
	var sub_text: String = str(data.get("level_name", ""))
	if str(data.get("session", "")) != "":
		sub_text += "  -  " + str(data["session"])
	var sub := UiStyle.label(sub_text, UiStyle.SIZE_SMALL, UiStyle.WHITE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	var score: int = int(data.get("score", 0))
	var combo: int = int(data.get("best_combo", 0))
	_score_label = _stat_row(col, "SCORE", UiStyle.SIZE_BIG + 14, bool(data.get("record_score", false)),
		"Best %s" % Hud.format_points(int(data.get("best_score", 0))), UiStyle.SUNSHINE)
	_combo_label = _stat_row(col, "BEST COMBO", UiStyle.SIZE_BIG, bool(data.get("record_combo", false)),
		"Best %s" % Hud.format_points(int(data.get("best_combo_ever", 0))), UiStyle.LIME)

	col.add_child(_goals_block())

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 22)
	col.add_child(bar)
	_retry = _button("Retry", SkateThemeBuilder.BTN_MINT, retry_pressed)
	_free = _button("Free Skate", SkateThemeBuilder.BTN_TEAL, free_skate_pressed)
	_levels = _button("Level Select", SkateThemeBuilder.BTN_SUN, level_select_pressed)
	var buttons: Array[Button] = [_retry, _free, _levels]
	if not best_replay().is_empty():
		_replay = _button("Watch Replay", SkateThemeBuilder.BTN_CORAL, replay_pressed)
		_replay.name = "WatchReplay"
		replay_pressed.connect(watch_replay)
		buttons.append(_replay)
		for b: Button in buttons:
			b.custom_minimum_size.x = 252
	for b: Button in buttons:
		bar.add_child(b)
	for i: int in buttons.size():
		if i > 0:
			buttons[i].focus_neighbor_left = buttons[i - 1].get_path()
		if i + 1 < buttons.size():
			buttons[i].focus_neighbor_right = buttons[i + 1].get_path()
	_retry.grab_focus.call_deferred()

	# Count-up and slam-in.
	_score_label.text = "0"
	_combo_label.text = "0"
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	_tween.tween_method(func(v: float) -> void: _score_label.text = Hud.format_points(int(v)), 0.0, float(score), RS_COUNT_TIME).set_delay(0.2)
	_tween.tween_method(func(v: float) -> void: _combo_label.text = Hud.format_points(int(v)), 0.0, float(combo), RS_COUNT_TIME).set_delay(0.2)


## The game's kept clip of this run's best combo ({"points", "text", "clip"}), or {} (no director, no combo).
func best_replay() -> Dictionary:
	var combo: int = int(data.get("best_combo", 0))
	var dir: ReplayDirector = ReplayDirector.find(get_tree()) if is_inside_tree() else null
	if combo <= 0 or dir == null:
		return {}
	return dir.best_clip_for(combo)


## Watch Replay: hide the card, play the best combo, come back focused on the button.
func watch_replay() -> void:
	var dir: ReplayDirector = ReplayDirector.find(get_tree())
	var e: Dictionary = best_replay()
	if dir == null or e.is_empty():
		return
	var text: String = str(e.get("text", ""))
	if text.length() > 64:
		text = text.substr(0, 61) + "..."
	var title: String = "BEST COMBO  %s   %s" % [Hud.format_points(int(e["points"])), text]
	visible = false
	if not dir.play_clip(e["clip"] as ReplayBuffer, title, _back_from_replay):
		visible = true


func _back_from_replay() -> void:
	visible = true
	if _replay != null:
		_replay.grab_focus()


## Skip the count-up (tests and captures).
func finish_now() -> void:
	if _tween != null:
		_tween.kill()
	var panel: Control = find_child("Card", true, false) as Control
	if panel != null:
		panel.scale = Vector2.ONE
		panel.modulate.a = 1.0
	_score_label.text = Hud.format_points(int(data.get("score", 0)))
	_combo_label.text = Hud.format_points(int(data.get("best_combo", 0)))


## One stat row: caption left, big number, then a NEW RECORD sticker or the best to beat.
func _stat_row(col: VBoxContainer, caption: String, size: int, record: bool, best_text: String, tint: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)
	var cap := UiStyle.label(caption, UiStyle.SIZE_SMALL, UiStyle.WHITE)
	cap.custom_minimum_size = Vector2(270, 0)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	var num := UiStyle.label("0", size, tint)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.custom_minimum_size = Vector2(330, 0)
	row.add_child(num)
	var tag: Control
	if record:
		var l := Label.new()
		l.text = "NEW RECORD!"
		l.add_theme_font_override("font", SkateThemeBuilder.heading_font())
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", SkateThemeBuilder.NAVY)
		var st: StyleBoxFlat = SkateThemeBuilder.sticker(SkateThemeBuilder.SUN, 12, 4)
		st.content_margin_left = 14.0
		st.content_margin_right = 14.0
		st.content_margin_top = 2.0
		st.content_margin_bottom = 4.0
		l.add_theme_stylebox_override("normal", st)
		l.rotation_degrees = -4.0
		l.pivot_offset = Vector2(80, 20)
		l.name = "NewRecord"
		tag = l
	else:
		tag = UiStyle.label(best_text, UiStyle.SIZE_SMALL - 6, UiStyle.WHITE, false)
		tag.modulate = Color(1, 1, 1, 0.7)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)
	return num


func _goals_block() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var titles: Array = data.get("goals", []) as Array
	var head := UiStyle.label("GOALS  " + goals_line(titles.size(), int(data.get("goals_done", 0)), int(data.get("goals_total", 0))),
		UiStyle.SIZE_SMALL, UiStyle.SUNSHINE)
	head.name = "GoalsHead"
	box.add_child(head)
	var shown: int = mini(titles.size(), RS_GOAL_ROWS)
	for i: int in shown:
		box.add_child(UiStyle.label("+ " + str(titles[i]), UiStyle.SIZE_SMALL - 4, UiStyle.LIME, false))
	if titles.size() > shown:
		box.add_child(UiStyle.label("and %d more" % (titles.size() - shown), UiStyle.SIZE_SMALL - 4, UiStyle.WHITE, false))
	if titles.is_empty():
		box.add_child(UiStyle.label("No new goals. Check the goal list (Tab) for the next one.", UiStyle.SIZE_SMALL - 4, UiStyle.WHITE, false))
	var unlocks: Array = data.get("unlocks", []) as Array
	if not unlocks.is_empty():
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 8)
		box.add_child(gap)
		var u := UiStyle.label("UNLOCKED: " + ", ".join(PackedStringArray(unlocks.map(func(x: Variant) -> String: return str(x)))),
			UiStyle.SIZE_SMALL - 2, UiStyle.BUBBLEGUM, false)
		u.name = "Unlocked"
		u.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		u.custom_minimum_size = Vector2(900, 0)
		box.add_child(u)
	return box


func _button(text: String, variation: StringName, sig: Signal) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(300, 78)
	b.add_theme_font_size_override("font_size", 34)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(func() -> void: sig.emit())
	return b
