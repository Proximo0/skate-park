class_name GoalsPanel
extends CanvasLayer
## Run timer (top centre) and a goal list (right side, under the gaps counter): one line (count and the next goal)
## during play, the full list while paused or while Tab is held. Shows the next few
## unfinished goals with progress, ticks finished ones off, and says "Time's up!" when the run ends.
## Pure formatting lives in static functions for unit tests.

const MARGIN: int = 48
const LIST_TOP: int = 140
const SHOWN: int = 4  ## unfinished goals listed at once
const LOW_TIME: float = 10.0

var goals: Goals
var clock: Callable  ## returns the caller's current time in seconds, the same clock passed to Goals

var _timer: Label
var _count: Label
var _rows: VBoxContainer
var _expanded: bool = false
var _box: PanelContainer
var _was_active: bool = false
var _list_key: String = ""


static func format_time(seconds: float) -> String:
	var s: int = int(ceil(maxf(seconds, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]


static func count_line(done: int, total: int) -> String:
	return "Goals %d/%d" % [done, total]


## Unfinished goals in data order, at most `limit`.
static func next_goals(all: Array[Dictionary], done: PackedStringArray, limit: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Dictionary in all:
		if done.has(str(g.get("id", ""))):
			continue
		out.append(g)
		if out.size() >= limit:
			break
	return out


static func row_text(title: String, progress: float) -> String:
	if progress > 0.0 and progress < 1.0:
		return "%s  %d%%" % [title, int(progress * 100.0)]
	return title


func bind(g: Goals, now: Callable) -> void:
	goals = g
	clock = now
	goals.goal_completed.connect(func(_goal: Dictionary) -> void: _list_key = "")


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS  # so the list can open while the game is paused
	_timer = UiStyle.label("2:00", UiStyle.SIZE_BIG, UiStyle.WHITE)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer.offset_left = -200
	_timer.offset_right = 200
	_timer.offset_top = MARGIN - 16
	add_child(_timer)

	_box = PanelContainer.new()
	_box.theme_type_variation = SkateThemeBuilder.PNL_NAVY
	_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_box.offset_right = -MARGIN
	_box.offset_top = LIST_TOP
	add_child(_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_box.add_child(col)
	_count = UiStyle.label("Goals", UiStyle.SIZE_SMALL + 2, UiStyle.SUNSHINE)
	col.add_child(_count)
	_rows = VBoxContainer.new()
	col.add_child(_rows)


func _process(_delta: float) -> void:
	if goals == null or not clock.is_valid():
		return
	var now: float = float(clock.call())
	var active: bool = goals.run_active()
	if active:
		var left: float = goals.run_time_left(now)
		_timer.text = format_time(left)
		_timer.label_settings.font_color = UiStyle.BUBBLEGUM if left <= LOW_TIME else UiStyle.WHITE
	elif _was_active or _timer.text != "Time's up!":
		_timer.text = "Time's up!"
		_timer.label_settings.font_color = UiStyle.SUNSHINE
	_was_active = active
	var want: bool = get_tree().paused or Input.is_physical_key_pressed(KEY_TAB)
	if want != _expanded:
		_expanded = want
		_list_key = ""
	_refresh_list()


func _refresh_list() -> void:
	var done: PackedStringArray = goals.completed_ids()
	var all: Array[Dictionary] = goals.all_goals()
	var shown: Array[Dictionary] = next_goals(all, done, SHOWN)
	var key: String = str(done.size())
	for g: Dictionary in shown:
		key += "|" + row_text(str(g.get("title", "")), goals.progress(str(g.get("id", ""))))
	if key == _list_key:
		return
	_list_key = key
	_count.text = count_line(done.size(), all.size())
	_rows.visible = _expanded
	if not _expanded:
		_count.text += "  -  " + (row_text(str(shown[0].get("title", "")), goals.progress(str(shown[0].get("id", "")))) if not shown.is_empty() else "All done!")
	for c: Node in _rows.get_children():
		c.queue_free()
	if shown.is_empty():
		_rows.add_child(UiStyle.label("All done! You rock!", UiStyle.SIZE_SMALL, UiStyle.LIME))
	for g: Dictionary in shown:
		var text: String = row_text(str(g.get("title", "")), goals.progress(str(g.get("id", ""))))
		_rows.add_child(UiStyle.label("• " + text, UiStyle.SIZE_SMALL, UiStyle.WHITE))
