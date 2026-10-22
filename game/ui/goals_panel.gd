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

## Progress: the career store, the level it belongs to, and the run being played. Results show when the run ends.
var store: ProgressStore
var level_id: String = LevelRegistry.DEFAULT_ID
var results_enabled: bool = not Flags.is_scripted_run()  ## a paused results card would stall a bot or a golden
var _skater: Skater = null
var _run_goal_ids: PackedStringArray = []
var _run_goal_titles: Array[String] = []
var _run_base_score: int = 0
var _run_best_combo: int = 0
var _free_skate: bool = false
var _results: ResultsScreen = null
var _level_select: LevelSelect = null
var _select_layer: CanvasLayer = null
var _dist_kind: String = ""  ## "manual" / "grind" while the skater holds one, for the distance goals
var _dist_m: float = 0.0
var _has_distance_goals: bool = false
var _run_unlocks: Array[String] = []  ## shop items and specials this run opened, for the results card
var _pickups: Array[Collectible] = []
var _session: String = SessionMode.DEFAULT_ID


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


## What the list shows: goals already in progress first (the closest to done on top), then the rest in data order.
static func pick_goals(all: Array[Dictionary], done: PackedStringArray, progress_of: Callable, limit: int) -> Array[Dictionary]:
	var open: Array[Dictionary] = next_goals(all, done, all.size())
	var started: Array[Dictionary] = []
	var fresh: Array[Dictionary] = []
	for g: Dictionary in open:
		if float(progress_of.call(str(g.get("id", "")))) > 0.0:
			started.append(g)
		else:
			fresh.append(g)
	started.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(progress_of.call(str(a.get("id", "")))) > float(progress_of.call(str(b.get("id", "")))))
	var out: Array[Dictionary] = []
	for g: Dictionary in started + fresh:
		if out.size() < limit:
			out.append(g)
	return out


static func row_text(title: String, progress: float) -> String:
	if progress > 0.0 and progress < 1.0:
		return "%s  %d%%" % [title, int(progress * 100.0)]
	return title


func bind(g: Goals, now: Callable) -> void:
	goals = g
	clock = now
	store = ProgressStore.shared()
	level_id = LevelRegistry.selected
	goals.mark_done(store.goals_done(level_id))
	goals.goal_completed.connect(_on_goal_completed)
	_session = store.session
	goals.set_session(SessionMode.seconds(_session))
	goals.start_run(float(clock.call()))  # the session's length counts from now
	for goal: Dictionary in goals.all_goals():
		if str(goal["type"]) in ["manual_distance", "grind_distance"]:
			_has_distance_goals = true
	_skater = get_tree().get_first_node_in_group("skater") as Skater if is_inside_tree() else null
	if _skater != null:
		_skater.combo_landed.connect(_on_combo_landed)
		_skater.combo_bailed.connect(func(_text: String) -> void: goals.on_combo_bailed())
		_skater.gaps.gap_completed.connect(_on_gap_completed)
		if not Flags.is_scripted_run():
			Unlocks.apply_specials(_skater.db, store.equipped_specials())
	_sync_rewards()
	_spawn_pickups()
	_begin_run()


## The skater finished a real gap (not a link bonus): feed the gap goals.
func _on_gap_completed(gap: Dictionary, _first_time: bool) -> void:
	goals.on_gap_event(str(gap.get("id", "")), str(gap.get("name", "")), float(clock.call()))


## Hidden pickups the goal file names: a cassette over each landmark zone, counted by the collect goals.
func _spawn_pickups() -> void:
	var level: Node = get_parent().get("level") as Node if get_parent() != null else null
	if level == null or not is_inside_tree():
		return
	_pickups = GoalPickup.spawn(get_tree(), level, goals.pickups)
	for c: Collectible in _pickups:
		c.collected.connect(_on_pickup)


func _on_pickup(item: String, _group: String) -> void:
	goals.on_collect(item)
	for goal: Dictionary in goals.all_goals():
		if str(goal["type"]) in ["collect", "pickup"] and (goal["items"] as Array).has(item) and not goals.is_completed(str(goal["id"])):
			var have: int = roundi(goals.progress(str(goal["id"])) * float((goal["items"] as Array).size()))
			_banner("%s %d/%d" % [item_label(item), have, (goal["items"] as Array).size()])
			break


## Display name of a pickup item: the VHS tapes are "Mixtape".
static func item_label(item: String) -> String:
	return "Mixtape" if item == "VHS" else item.capitalize()


func _banner(text: String) -> void:
	var hud: Node = get_parent().get("hud") as Node if get_parent() != null else null
	if hud != null and hud.has_method("_show_banner"):
		hud.call("_show_banner", text)


## Hands out the reward items the goal total has earned (free shop items) and saves the wallet when it changed.
func _sync_rewards() -> void:
	var wallet: Wallet = get_parent().get("wallet") as Wallet if get_parent() != null else null
	if wallet == null:
		return
	var fresh: PackedStringArray = Unlocks.sync_wallet(wallet, store.total_goals_done())
	if not fresh.is_empty() and not Flags.is_scripted_run():
		wallet.save()


func _begin_run() -> void:
	_run_goal_ids = []
	_run_goal_titles = []
	_run_unlocks = []
	_run_best_combo = 0
	_run_base_score = _skater.combo.landed_total if _skater != null else 0
	_free_skate = false


func _on_goal_completed(goal: Dictionary) -> void:
	_list_key = ""
	_run_goal_ids.append(str(goal.get("id", "")))
	_run_goal_titles.append(str(goal.get("title", "")))
	var before: int = store.total_goals_done()
	if store.add_goal(level_id, str(goal.get("id", ""))):
		store.save()
		_announce_unlocks(before, before + 1)


## Banners for what the new goal total opened: shop items, special tricks and special slots.
func _announce_unlocks(before: int, after: int) -> void:
	for id: String in Unlocks.opened_between(before, after):
		var line: String = "%s%s" % ["NEW GEAR: " if Unlocks.is_reward(id) else "SHOP UNLOCK: ", Unlocks.item_name(id)]
		_run_unlocks.append(Unlocks.item_name(id))
		_banner(line)
	for e: Dictionary in Unlocks.special_entries():
		var need: int = int(e.get("goals", 0))
		if need > before and need <= after:
			var nm: String = str((TrickDB.load_default().get_trick(str(e["id"]))).get("name", e["id"]))
			_run_unlocks.append(nm)
			_banner("NEW SPECIAL: " + nm)
	if Unlocks.special_slots(after) > Unlocks.special_slots(before):
		_banner("SPECIAL SLOT %d OPEN" % Unlocks.special_slots(after))
	var wallet: Wallet = get_parent().get("wallet") as Wallet if get_parent() != null else null
	if wallet != null and not Unlocks.sync_wallet(wallet, after).is_empty() and not Flags.is_scripted_run():
		wallet.save()


func _on_combo_landed(points: int, _text: String) -> void:
	_run_best_combo = maxi(_run_best_combo, points)
	var score: int = run_score()
	var before: int = store.best_score(level_id)
	store.note_bests(level_id, score, _run_best_combo)
	if score > before or _run_best_combo > store.best_combo(level_id):
		store.save()


## Points landed since this run started.
func run_score() -> int:
	return (_skater.combo.landed_total - _run_base_score) if _skater != null else 0


## What the results card shows. Call once per run end: it records the run in the store.
func build_results() -> Dictionary:
	var prev_score: int = store.best_score(level_id)
	var prev_combo: int = store.best_combo(level_id)
	var score: int = run_score()
	var rec: Dictionary = store.record_run(level_id, score, _run_best_combo, _run_goal_ids)
	store.save()
	var name: String = level_id
	for e: Dictionary in LevelRegistry.entries():
		if str(e["id"]) == level_id:
			name = str(e["name"])
	var done: int = store.goals_done_count(level_id)
	var total: int = goals.all_goals().size()
	return {
		"level_name": name, "score": score, "best_combo": _run_best_combo,
		"goals": _run_goal_titles.duplicate(), "goals_done": done, "goals_total": total,
		"stars": ProgressStore.stars_for(done, total),
		"record_score": bool(rec["score"]), "record_combo": bool(rec["combo"]),
		"best_score": store.best_score(level_id), "best_combo_ever": store.best_combo(level_id),
		"prev_best_score": prev_score, "prev_best_combo": prev_combo,
		"session": SessionMode.label(_session), "unlocks": _run_unlocks.duplicate(),
	}


func _show_results() -> void:
	if _results != null:
		return
	_results = ResultsScreen.new().setup(build_results())
	_results.retry_pressed.connect(_on_retry)
	_results.free_skate_pressed.connect(_on_free_skate)
	_results.level_select_pressed.connect(_on_results_level_select)
	add_child(_results)
	_box.visible = false
	get_tree().paused = true


func _close_results() -> void:
	_box.visible = true
	if _results != null:
		_results.queue_free()
		_results = null
	get_tree().paused = false


func _on_retry() -> void:
	_close_results()
	var main: Node = get_parent()
	if main != null and main.has_method("_restart"):
		main.call("_restart")
	else:
		goals.start_run(float(clock.call()))


func _on_free_skate() -> void:
	_close_results()
	_free_skate = true


func _on_results_level_select() -> void:
	if _level_select != null or _results == null:
		return
	_results.visible = false
	_select_layer = CanvasLayer.new()
	_select_layer.layer = 61
	_select_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_level_select = LevelSelect.new()
	_level_select.focus_id = level_id
	_level_select.chosen.connect(_on_level_picked)
	_level_select.closed.connect(_on_select_closed)
	_select_layer.add_child(_level_select)
	add_child(_select_layer)


func _on_select_closed() -> void:
	if _select_layer != null:
		_select_layer.queue_free()
	_select_layer = null
	_level_select = null
	if _results != null:
		_results.visible = true
		_results.focus_default()


func _on_level_picked(id: String) -> void:
	get_tree().paused = false
	var main: Node = get_parent()
	if main != null and main.has_method("_change_level"):
		main.call("_change_level", id)


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


## Distance goals: the metres of the manual or grind being held, counted as it goes (a bail keeps what it earned).
func _physics_process(delta: float) -> void:
	if not _has_distance_goals or _skater == null or goals == null or get_tree().paused:
		return
	var st: SkateState.State = _skater.state.state
	var kind: String = "manual" if st == SkateState.State.MANUAL else ("grind" if st == SkateState.State.GRIND else "")
	if kind != _dist_kind:
		_dist_kind = kind
		_dist_m = 0.0
	if kind != "":
		_dist_m += _skater.velocity.length() * delta
		goals.on_distance(kind, _dist_m)


func _process(_delta: float) -> void:
	if goals == null or not clock.is_valid():
		return
	var now: float = float(clock.call())
	var active: bool = goals.run_active()
	if active and not _was_active:
		_begin_run()
	elif _was_active and not active and results_enabled:
		_show_results()
	if active and goals.untimed:
		_timer.text = "Free skate"
		_timer.label_settings.font_color = UiStyle.SUNSHINE
	elif active:
		var left: float = goals.run_time_left(now)
		_timer.text = format_time(left)
		_timer.label_settings.font_color = UiStyle.BUBBLEGUM if left <= LOW_TIME else UiStyle.WHITE
	elif _was_active or _timer.text not in ["Time's up!", "Free skate"]:
		_timer.text = "Time's up!"
		_timer.label_settings.font_color = UiStyle.SUNSHINE
	elif _free_skate and _timer.text != "Free skate":
		_timer.text = "Free skate"
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
	var live: Array[Dictionary] = []
	for g: Dictionary in all:  # goals the session parks (score goals in free skate) stay out of the list
		if goals.is_active(str(g.get("id", ""))):
			live.append(g)
	var shown: Array[Dictionary] = pick_goals(live, done, goals.progress, SHOWN)
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
