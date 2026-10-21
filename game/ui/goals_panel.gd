class_name GoalsPanel
extends CanvasLayer
## Run timer (top centre) and a short goal list (right side, under the gaps counter). Shows the next few
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
	_timer = UiStyle.label("2:00", UiStyle.SIZE_BIG, UiStyle.WHITE)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer.offset_left = -200
	_timer.offset_right = 200
	_timer.offset_top = MARGIN - 16
	add_child(_timer)

	_box = PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.panel_style(Color(UiStyle.INK, 0.55))
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_box.add_theme_stylebox_override("panel", style)
	_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_box.offset_right = -MARGIN
	_box.offset_top = LIST_TOP
	add_child(_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_box.add_child(col)
	_count = UiStyle.label("Goals", UiStyle.SIZE_BODY, UiStyle.SUNSHINE)
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
	for c: Node in _rows.get_children():
		c.queue_free()
	if shown.is_empty():
		_rows.add_child(UiStyle.label("All done! You rock!", UiStyle.SIZE_SMALL, UiStyle.LIME))
	for g: Dictionary in shown:
		var text: String = row_text(str(g.get("title", "")), goals.progress(str(g.get("id", ""))))
		_rows.add_child(UiStyle.label("• " + text, UiStyle.SIZE_SMALL, UiStyle.WHITE))
