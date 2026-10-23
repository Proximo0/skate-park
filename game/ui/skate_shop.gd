class_name SkateShop
extends Control
## The skate shop: pick a category, browse items (up/down), change colourway (left/right), buy or equip (accept).
## The preview shows the whole skater or the board with the highlighted item on it. Coins come from landed combos
## and finished goals. Q / E (LB / RB) switch category, Z / X or the right stick turn the preview.

signal closed

var _cat: PartCatalog
var _wallet: Wallet
var _lo: SkaterLoadout
var _save_enabled: bool = true
var _category: int = 0
var _items: Array[Dictionary] = []
var _color_pick: Dictionary = {}  ## item id -> colourway index being looked at
var _selected: int = 0
var _tab_buttons: Array[Button] = []
var _rows: VBoxContainer
var _row_nodes: Array[StepRow] = []
var _scroll: ScrollContainer
var _preview: SkaterPreview
var _coins_label: Label
var _name_label: Label
var _desc_label: Label
var _price_label: Label
var _message: Label
var _stock_title: Label
var _stock_bar: ProgressBar
var _stock_note: Label
var _action: Button
var _progress: ProgressStore = null  ## the career: goals done open items and specials (the shared one unless a test hands one in)
var _tab_specials: Button
var _specials_mode: bool = false
var _special_ids: PackedStringArray = []


func setup(wallet: Wallet = null, loadout: SkaterLoadout = null, save_enabled: bool = true, progress: ProgressStore = null) -> SkateShop:
	_wallet = wallet if wallet != null else Wallet.load_file()
	_lo = loadout if loadout != null else SkaterLoadout.load_file()
	_save_enabled = save_enabled
	_progress = progress
	return self


func _goals_done() -> int:
	return _progress.total_goals_done()


func _ready() -> void:
	_cat = PartCatalog.load_default()
	if _wallet == null:
		setup()
	if _progress == null:
		_progress = ProgressStore.shared()
	if not Unlocks.sync_wallet(_wallet, _goals_done()).is_empty() and _save_enabled:
		_wallet.save()  # reward gear earned since the last visit is already yours
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuKit.backdrop())
	_build_layout()
	_set_category(0)


func _build_layout() -> void:
	var left: PanelContainer = MenuKit.panel()
	left.anchor_right = 1.0
	left.anchor_bottom = 1.0
	left.offset_left = 50
	left.offset_top = 40
	left.offset_right = -1030
	left.offset_bottom = -40
	add_child(left)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	left.add_child(col)
	var title: Label = UiStyle.label("SKATE SHOP", UiStyle.SIZE_BIG, UiStyle.SUNSHINE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var tabs: GridContainer = GridContainer.new()
	tabs.columns = 3
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	col.add_child(tabs)
	for i: int in _cat.categories.size():
		var b: Button = Button.new()
		b.text = str(_cat.categories[i]["name"])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_category.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	_tab_specials = Button.new()
	_tab_specials.text = "Special Tricks"
	_tab_specials.focus_mode = Control.FOCUS_NONE
	_tab_specials.custom_minimum_size = Vector2(0, 56)
	_tab_specials.pressed.connect(_set_category.bind(_cat.categories.size()))
	col.add_child(_tab_specials)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	_scroll.add_child(_rows)
	var card: PanelContainer = MenuKit.panel(SkateThemeBuilder.PNL_NAVY)
	card.custom_minimum_size = Vector2(0, 150)
	col.add_child(card)
	var ccol: VBoxContainer = VBoxContainer.new()
	ccol.add_theme_constant_override("separation", 6)
	card.add_child(ccol)
	_stock_title = UiStyle.label("", UiStyle.SIZE_BODY, UiStyle.SUNSHINE, false)
	ccol.add_child(_stock_title)
	_stock_bar = ProgressBar.new()
	_stock_bar.show_percentage = false
	_stock_bar.custom_minimum_size = Vector2(0, 26)
	ccol.add_child(_stock_bar)
	_stock_note = UiStyle.label("", UiStyle.SIZE_SMALL, UiStyle.WHITE, false)
	_stock_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ccol.add_child(_stock_note)
	var hint: Label = MenuKit.text("Q / E or LB / RB: category    Left / Right: colour", UiStyle.SIZE_SMALL, UiStyle.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	var right: PanelContainer = MenuKit.panel(SkateThemeBuilder.PNL_NAVY)
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = 920
	right.offset_top = 40
	right.offset_right = -50
	right.offset_bottom = -40
	add_child(right)
	var rcol: VBoxContainer = VBoxContainer.new()
	rcol.add_theme_constant_override("separation", 8)
	right.add_child(rcol)
	_preview = SkaterPreview.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rcol.add_child(_preview)
	var info: PanelContainer = MenuKit.panel()
	rcol.add_child(info)
	var icol: VBoxContainer = VBoxContainer.new()
	icol.add_theme_constant_override("separation", 4)
	info.add_child(icol)
	_name_label = MenuKit.text("", UiStyle.SIZE_BODY + 4)
	icol.add_child(_name_label)
	_desc_label = MenuKit.text("", UiStyle.SIZE_SMALL, UiStyle.MUTED)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(0, 54)
	icol.add_child(_desc_label)
	var buy_row: HBoxContainer = HBoxContainer.new()
	buy_row.add_theme_constant_override("separation", 12)
	icol.add_child(buy_row)
	_price_label = MenuKit.text("", UiStyle.SIZE_BODY)
	_price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_row.add_child(_price_label)
	_action = Button.new()
	_action.custom_minimum_size = Vector2(240, 62)
	_action.focus_mode = Control.FOCUS_NONE
	MenuKit.style_button(_action, SkateThemeBuilder.BTN_MINT)
	_action.pressed.connect(_activate)
	buy_row.add_child(_action)
	var back: Button = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(150, 62)
	back.focus_mode = Control.FOCUS_NONE
	MenuKit.style_button(back, SkateThemeBuilder.BTN_CORAL)
	back.pressed.connect(func() -> void: closed.emit())
	buy_row.add_child(back)

	var coins_panel: PanelContainer = MenuKit.panel(SkateThemeBuilder.PNL_NAVY)
	coins_panel.anchor_left = 1.0
	coins_panel.anchor_right = 1.0
	coins_panel.offset_left = -330
	coins_panel.offset_right = -70
	coins_panel.offset_top = 56
	coins_panel.offset_bottom = 120
	add_child(coins_panel)
	_coins_label = UiStyle.label("", UiStyle.SIZE_BODY, UiStyle.SUNSHINE, false)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_panel.add_child(_coins_label)
	_message = UiStyle.label("", UiStyle.SIZE_BODY, UiStyle.WHITE)
	_message.anchor_right = 1.0
	_message.offset_left = 920
	_message.offset_top = 140
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("spin_left"):
		_set_category(posmod(_category - 1, _cat.categories.size() + 1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("spin_right"):
		_set_category(posmod(_category + 1, _cat.categories.size() + 1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _set_category(i: int) -> void:
	_category = clampi(i, 0, _cat.categories.size())  # one past the catalog's categories is the Special Tricks tab
	_specials_mode = _category >= _cat.categories.size()
	for t: int in _tab_buttons.size():
		MenuKit.style_button(_tab_buttons[t], SkateThemeBuilder.BTN_TEAL if t == _category else SkateThemeBuilder.BTN_CREAM)
	MenuKit.style_button(_tab_specials, SkateThemeBuilder.BTN_TEAL if _specials_mode else SkateThemeBuilder.BTN_CREAM)
	if _specials_mode:
		_items = []
		_special_ids = []
		for e: Dictionary in Unlocks.special_entries():
			_special_ids.append(str(e["id"]))
		_rebuild_special_rows(0)
		return
	_items = _cat.category_items(str(_cat.categories[_category]["id"]), _lo.body_type)
	_rebuild_rows(0)


func _rebuild_rows(focus_index: int) -> void:
	for c: Node in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	_row_nodes.clear()
	for i: int in _items.size():
		var row: StepRow = StepRow.new()
		row.stepped.connect(_on_step.bind(i))
		row.pressed.connect(_on_row_pressed.bind(i))
		row.focus_entered.connect(_select.bind(i))
		if i > 0 and str(_items[i]["slot"]) != str(_items[i - 1]["slot"]):
			_rows.add_child(_divider(str(_items[i]["slot"])))
		_rows.add_child(row)
		_row_nodes.append(row)
		_refresh_row(i)
	_refresh_coins()
	if _items.is_empty():
		_name_label.text = "Nothing here yet"
		return
	_selected = clampi(focus_index, 0, _items.size() - 1)
	_grab_focus.call_deferred(_row_nodes[_selected] as Control)
	_select(_selected)


## A thin labelled rule between two slots that share a category (griptape and bearings).
func _divider(slot: String) -> Control:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = MenuKit.text(slot.capitalize() + "s", UiStyle.SIZE_SMALL, UiStyle.MUTED)
	box.add_child(label)
	var line: ColorRect = ColorRect.new()
	line.color = UiStyle.MUTED
	line.custom_minimum_size = Vector2(0, 3)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	return box


func _grab_focus(c: Control) -> void:
	if is_instance_valid(c) and c.is_inside_tree():
		c.grab_focus()


func _color_of_pick(id: String) -> int:
	return clampi(int(_color_pick.get(id, 0)), 0, maxi(_cat.color_count(id) - 1, 0))


func _is_equipped(it: Dictionary) -> bool:
	var slot: String = str(it["slot"])
	var id: String = str(it["id"])
	if slot == "accessory":
		return _lo.accessories.has(id) and _lo.item_color(slot) == _color_of_pick(id)
	return _lo.item_id(slot) == id and (slot == "bearing" or _lo.item_color(slot) == _color_of_pick(id))


func _refresh_row(i: int) -> void:
	var it: Dictionary = _items[i]
	var id: String = str(it["id"])
	var row: StepRow = _row_nodes[i]
	var sw: Color = _cat.color_of(id, _color_of_pick(id)) if _cat.color_count(id) > 0 else Color(0, 0, 0, 0)
	row.setup(str(it["name"]), "", sw)
	row.set_arrows_visible(_cat.color_count(id) > 1)
	if _is_equipped(it):
		row.set_value("EQUIPPED", sw, Color("#0B6B33"))
	elif _wallet.owns(id):
		row.set_value("OWNED", sw, Color("#0E4F8B"))
	elif Unlocks.item_locked(id, _goals_done()):
		row.set_value("%d goals" % Unlocks.item_goals(id), sw, MenuKit.BAD)
	else:
		var price: int = int(it["price"])
		row.set_value("%d coins" % price, sw, UiStyle.INK if _wallet.can_afford(price) else MenuKit.BAD)


func _refresh_coins() -> void:
	_coins_label.text = "COINS  %d" % _wallet.coins
	var owned: int = 0
	var cheapest: int = -1
	var next_lock: int = -1
	for it: Dictionary in _items:
		if _wallet.owns(str(it["id"])):
			owned += 1
		elif Unlocks.item_locked(str(it["id"]), _goals_done()):
			var need: int = Unlocks.goals_missing(str(it["id"]), _goals_done())
			next_lock = need if next_lock < 0 else mini(next_lock, need)
		else:
			var pr: int = int(it["price"])
			cheapest = pr if cheapest < 0 else mini(cheapest, pr)
	_stock_title.text = "OWNED  %d / %d" % [owned, _items.size()]
	_stock_bar.max_value = maxf(float(_items.size()), 1.0)
	_stock_bar.value = float(owned)
	if cheapest < 0 and next_lock > 0:
		_stock_note.text = "Locked gear opens as you finish goals: %d more for the next piece." % next_lock
	elif cheapest < 0:
		_stock_note.text = "You own everything here. Nice."
	elif _wallet.coins >= cheapest:
		_stock_note.text = "You can afford something new. Up / Down to browse."
	else:
		_stock_note.text = "Next unlock costs %d coins. Land combos and finish goals to earn more." % cheapest


func _select(i: int) -> void:
	_selected = i
	_update_info()
	_update_preview()


func _update_info() -> void:
	if _specials_mode:
		_update_special_info()
		return
	if _items.is_empty():
		return
	var it: Dictionary = _items[_selected]
	var id: String = str(it["id"])
	var cname: String = _cat.color_name(id, _color_of_pick(id))
	_name_label.text = str(it["name"]) + ("  -  " + cname if cname != "" else "")
	_desc_label.text = str(it["desc"])
	var price: int = int(it["price"])
	if _wallet.owns(id):
		_price_label.text = "Owned"
		_action.text = "Equip" if not _is_equipped(it) else "Equipped"
		_action.disabled = _is_equipped(it)
	elif Unlocks.item_locked(id, _goals_done()):
		var missing: int = Unlocks.goals_missing(id, _goals_done())
		_price_label.text = "Reward: %d goals" % Unlocks.item_goals(id) if Unlocks.is_reward(id) else "Locked: %d goals" % Unlocks.item_goals(id)
		_price_label.add_theme_color_override("font_color", MenuKit.BAD)
		_action.text = "%d more goal%s" % [missing, "" if missing == 1 else "s"]
		_action.disabled = true
	else:
		_price_label.text = "%d coins" % price
		_price_label.add_theme_color_override("font_color", UiStyle.INK if _wallet.can_afford(price) else MenuKit.BAD)
		_action.text = "Buy" if _wallet.can_afford(price) else "Need %d more" % (price - _wallet.coins)
		_action.disabled = false


func _update_preview() -> void:
	if _specials_mode:
		_preview.show_skater(_lo)
		return
	if _items.is_empty():
		return
	var it: Dictionary = _items[_selected]
	var id: String = str(it["id"])
	var slot: String = str(it["slot"])
	var look: SkaterLoadout = _lo.duplicate_loadout()
	look.set_item(slot, id, _color_of_pick(id))
	if slot in SkaterLoadout.BOARD_SLOTS:
		_preview.show_board(look, _board_view_for(slot))
	elif slot == "shoes":
		_preview.show_skater(look, "feet")
	else:
		_preview.show_skater(look)


func _board_view_for(slot: String) -> String:
	match slot:
		"griptape": return "grip"
		"deck": return "display"
		"truck": return "trucks"
		"wheel": return "wheels"
		"bearing": return "wheels"
	return "top"


func _on_step(dir: int, i: int) -> void:
	if _specials_mode:
		return
	var id: String = str(_items[i]["id"])
	var n: int = _cat.color_count(id)
	if n < 2:
		return
	_color_pick[id] = posmod(_color_of_pick(id) + dir, n)
	_refresh_row(i)
	_select(i)


func _on_row_pressed(i: int) -> void:
	_selected = i
	_activate()


func _activate() -> void:
	if _specials_mode:
		_toggle_special()
		return
	if _items.is_empty():
		return
	var it: Dictionary = _items[_selected]
	var id: String = str(it["id"])
	var bought: bool = false
	if not _wallet.owns(id) and Unlocks.item_locked(id, _goals_done()):
		_say("Finish %d more goals to unlock this." % Unlocks.goals_missing(id, _goals_done()))
		return
	if not _wallet.owns(id):
		if not _wallet.buy(id):
			_say("Not enough coins! Land combos to earn more.")
			return
		bought = true
		if _save_enabled:
			_wallet.save()
	_lo.set_item(str(it["slot"]), id, _color_of_pick(id))
	if _save_enabled:
		_lo.save()
	_say("Bought and equipped!" if bought else "Equipped!")
	for i: int in _items.size():
		_refresh_row(i)
	_refresh_coins()
	_update_info()


# --- special tricks -------------------------------------------------------------------------------------------

const SPECIAL_BUTTONS: Dictionary = {"flip": "Flip", "grab": "Grab", "grind": "Grind"}
const SPECIAL_DIRS: Dictionary = {"N": "Up", "S": "Down", "E": "Right", "W": "Left", "NE": "Up-Right", "NW": "Up-Left",
	"SE": "Down-Right", "SW": "Down-Left"}


## "Down, Up + Flip" for a special's stick sequence and button.
static func special_input(trick: Dictionary) -> String:
	var parts: PackedStringArray = []
	for d: Variant in trick.get("sequence", []) as Array:
		parts.append(str(SPECIAL_DIRS.get(str(d), str(d))))
	return "%s + %s" % [", ".join(parts), str(SPECIAL_BUTTONS.get(str(trick.get("button", "")), "Trick"))]


func _special_trick(id: String) -> Dictionary:
	return TrickDB.load_default().get_trick(id)


func _rebuild_special_rows(focus_index: int) -> void:
	for c: Node in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	_row_nodes.clear()
	for i: int in _special_ids.size():
		var row: StepRow = StepRow.new()
		row.pressed.connect(_on_row_pressed.bind(i))
		row.focus_entered.connect(_select.bind(i))
		_rows.add_child(row)
		_row_nodes.append(row)
		_refresh_special_row(i)
	_refresh_special_stock()
	if _special_ids.is_empty():
		_name_label.text = "No specials yet"
		return
	_selected = clampi(focus_index, 0, _special_ids.size() - 1)
	_grab_focus.call_deferred(_row_nodes[_selected] as Control)
	_select(_selected)


func _refresh_special_row(i: int) -> void:
	var id: String = _special_ids[i]
	var row: StepRow = _row_nodes[i]
	row.setup(str(_special_trick(id).get("name", id)), "")
	row.set_arrows_visible(false)
	if _progress.equipped_specials().has(id):
		row.set_value("EQUIPPED", Color(0, 0, 0, 0), Color("#0B6B33"))
	elif Unlocks.special_unlocked(id, _goals_done()):
		row.set_value("READY", Color(0, 0, 0, 0), Color("#0E4F8B"))
	else:
		row.set_value("%d goals" % Unlocks.special_goals(id), Color(0, 0, 0, 0), MenuKit.BAD)


func _refresh_special_stock() -> void:
	var done: int = _goals_done()
	var slots: int = Unlocks.special_slots(done)
	var used: int = _progress.equipped_specials().size()
	_coins_label.text = "GOALS DONE  %d" % done
	_stock_title.text = "SPECIAL SLOTS  %d / %d" % [used, slots]
	_stock_bar.max_value = float(maxi(slots, 1))
	_stock_bar.value = float(used)
	var next_slot: int = -1
	for e: Variant in Unlocks.data().get("special_slots", []) as Array:
		var need: int = int((e as Dictionary).get("goals", 0))
		if need > done and (next_slot < 0 or need < next_slot):
			next_slot = need
	_stock_note.text = "Carry the specials you like. Fill the meter, then pull the stick moves in the air." \
			+ ("  Next slot at %d goals." % next_slot if next_slot > 0 else "")


func _update_special_info() -> void:
	if _special_ids.is_empty():
		return
	var id: String = _special_ids[_selected]
	var t: Dictionary = _special_trick(id)
	_name_label.text = str(t.get("name", id))
	_desc_label.text = "%s with a full special meter.  %s points." % [special_input(t), Hud.format_points(int(t.get("points", 0)))]
	var done: int = _goals_done()
	var equipped: bool = _progress.equipped_specials().has(id)
	if not Unlocks.special_unlocked(id, done):
		_price_label.text = "Locked: %d goals" % Unlocks.special_goals(id)
		_price_label.add_theme_color_override("font_color", MenuKit.BAD)
		_action.text = "%d more goals" % (Unlocks.special_goals(id) - done)
		_action.disabled = true
	else:
		_price_label.text = "Equipped" if equipped else "Ready"
		_price_label.add_theme_color_override("font_color", UiStyle.INK)
		_action.text = "Unequip" if equipped else ("Equip" if _progress.equipped_specials().size() < Unlocks.special_slots(done) else "Slots full")
		_action.disabled = not equipped and _progress.equipped_specials().size() >= Unlocks.special_slots(done)


func _toggle_special() -> void:
	if _special_ids.is_empty():
		return
	var id: String = _special_ids[_selected]
	if _progress.toggle_special(id):
		if _save_enabled:
			_progress.save()
		_say("Special equipped!" if _progress.equipped_specials().has(id) else "Special put away.")
	elif not Unlocks.special_unlocked(id, _goals_done()):
		_say("Finish %d more goals to unlock this." % (Unlocks.special_goals(id) - _goals_done()))
	else:
		_say("Slots full. Put another special away first.")
	for i: int in _special_ids.size():
		_refresh_special_row(i)
	_refresh_special_stock()
	_update_special_info()


func _say(msg: String) -> void:
	_message.text = msg
	_message.modulate.a = 1.0
	var tw: Tween = create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_message, "modulate:a", 0.0, 0.4)


## For screenshots and tests.
func set_category(i: int) -> void:
	_set_category(i)
