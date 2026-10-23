class_name CharacterCreator
extends Control
## Character creator: a turntable preview on the right, tabs and option rows on the left. Rows step with
## left/right, up/down moves, Q/E (or LB/RB) switches tab, Z/X or the right stick turns the skater.
## Only items the player owns are offered; the Skate Shop sells the rest. Save writes user://loadout.json.

signal closed

const TABS: PackedStringArray = ["Body", "Clothes", "Board"]
const ROW_TIPS := {
	"Name": "Who is on the board? Pick a name.", "Body": "Girl or boy frame. Clothes and hair re-fit.",
	"Skin": "Skin tone.", "Hair style": "Cut and style. Buy more in the Skate Shop.",
	"Hair colour": "Dye job.", "Eyes": "Eye colour.", "Top": "Shirt, hoodie or jacket.",
	"Bottom": "Pants, shorts or skirt.", "Socks": "Socks for the shoe-gazers.", "Shoes": "Your kicks.",
	"Accessory": "Hats, glasses and extras. Buy more in the Skate Shop.",
	"Trucks": "Axles: turning and grind feel.", "Wheels": "Wheel colour and style.",
	"Bearings": "How fast the wheels spin.", "Griptape": "The sandpaper on top.",
}
const BODY_LABELS := {"female": "Girl", "male": "Boy"}

var _cat: PartCatalog
var _wallet: Wallet
var _lo: SkaterLoadout
var _preview: SkaterPreview
var _rows_box: VBoxContainer
var _tab_buttons: Array[Button] = []
var _tab: int = 0
var _toast: Label
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _save_enabled: bool = true
var _board_view: String = "top"
var _info: Label
var _info_title: Label


## wallet / loadout default to the saved ones. Tests and screenshots may pass their own.
func setup(wallet: Wallet = null, loadout: SkaterLoadout = null, save_enabled: bool = true) -> CharacterCreator:
	_wallet = wallet if wallet != null else Wallet.load_file()
	_lo = loadout if loadout != null else SkaterLoadout.load_file()
	_save_enabled = save_enabled
	return self


func _ready() -> void:
	_cat = PartCatalog.load_default()
	if _wallet == null:
		setup()
	_rng.randomize()
	_lo.sanitize(_owned_check())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuKit.backdrop())
	_build_layout()
	_rebuild_rows(0)
	_refresh_preview()


func _owned_check() -> Callable:
	return func(id: String) -> bool: return _wallet.owns(id)


func _build_layout() -> void:
	var left: PanelContainer = MenuKit.panel()
	left.offset_left = 50
	left.offset_top = 40
	left.offset_right = -1130
	left.offset_bottom = -40
	left.anchor_right = 1.0
	left.anchor_bottom = 1.0
	add_child(left)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	left.add_child(col)
	var title: Label = UiStyle.label("CREATE YOUR SKATER", UiStyle.SIZE_BIG, UiStyle.BUBBLEGUM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	col.add_child(tabs)
	for i: int in TABS.size():
		var b: Button = Button.new()
		b.text = TABS[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 8)
	_rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_rows_box)
	var card: PanelContainer = MenuKit.panel(SkateThemeBuilder.PNL_NAVY)
	card.custom_minimum_size = Vector2(0, 118)
	col.add_child(card)
	var ccol: VBoxContainer = VBoxContainer.new()
	ccol.add_theme_constant_override("separation", 2)
	card.add_child(ccol)
	_info_title = UiStyle.label("", UiStyle.SIZE_BODY, UiStyle.SUNSHINE, false)
	ccol.add_child(_info_title)
	_info = UiStyle.label("", UiStyle.SIZE_SMALL, UiStyle.WHITE, false)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ccol.add_child(_info)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	col.add_child(foot)
	var rnd: Button = _footer_button("Random", SkateThemeBuilder.BTN_SUN, _on_random)
	var save: Button = _footer_button("Save", SkateThemeBuilder.BTN_MINT, _on_save)
	var back: Button = _footer_button("Cancel", SkateThemeBuilder.BTN_CORAL, _on_cancel)
	foot.add_child(rnd)
	foot.add_child(save)
	foot.add_child(back)
	var hint: Label = MenuKit.text("Q / E or LB / RB: tab    Z / X or right stick: turn", UiStyle.SIZE_SMALL, UiStyle.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	var right: PanelContainer = MenuKit.panel(SkateThemeBuilder.PNL_NAVY)
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = 820
	right.offset_top = 40
	right.offset_right = -50
	right.offset_bottom = -40
	add_child(right)
	_preview = SkaterPreview.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_preview)
	_toast = UiStyle.label("", UiStyle.SIZE_BODY, UiStyle.WHITE)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.offset_left = 820
	_toast.offset_top = 70
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)


func _footer_button(text_: String, variation: StringName, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text_
	b.custom_minimum_size = Vector2(0, 70)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuKit.style_button(b, variation)
	b.pressed.connect(cb)
	return b


func _set_tab(i: int) -> void:
	_tab = posmod(i, TABS.size())
	_rebuild_rows(0)
	_refresh_preview()


func _style_tabs() -> void:
	for i: int in _tab_buttons.size():
		var on: bool = i == _tab
		MenuKit.style_button(_tab_buttons[i], SkateThemeBuilder.BTN_TEAL if on else SkateThemeBuilder.BTN_CREAM)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("spin_left"):
		_set_tab(_tab - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("spin_right"):
		_set_tab(_tab + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()


# Rows

func _rebuild_rows(focus_index: int) -> void:
	_style_tabs()
	for c: Node in _rows_box.get_children():
		_rows_box.remove_child(c)
		c.queue_free()
	match _tab:
		0: _build_body_rows()
		1: _build_clothes_rows()
		2: _build_board_rows()
	_info_title.get_parent().get_parent().visible = _rows_box.get_child_count() <= 7  # no room on the long tabs
	if _rows_box.get_child_count() > 0:
		var row: Control = _rows_box.get_child(clampi(focus_index, 0, _rows_box.get_child_count() - 1)) as Control
		_grab_focus.call_deferred(row)


func _grab_focus(c: Control) -> void:
	if is_instance_valid(c) and c.is_inside_tree():
		c.grab_focus()


func _add_row(title_: String, value: String, swatch: Color, on_step: Callable, board_view: String = "", info: String = "") -> void:
	var row: StepRow = StepRow.new().setup(title_, value, swatch)
	row.focus_entered.connect(func() -> void:
		_info_title.text = title_
		_info.text = info if info != "" else str(ROW_TIPS.get(title_, "Left / Right to change.")))
	if board_view != "":
		row.focus_entered.connect(func() -> void: _board_view = board_view; _refresh_preview())
	row.stepped.connect(func(dir: int) -> void:
		on_step.call(dir)
		_after_change(row.get_index()))
	_rows_box.add_child(row)


func _build_body_rows() -> void:
	var skin_i: int = PartCatalog.palette_index(_cat.skin_tones, _lo.skin_tone)
	var hair_i: int = PartCatalog.palette_index(_cat.hair_colors, _lo.hair_color)
	var eye_i: int = PartCatalog.palette_index(_cat.eye_colors, _lo.eye_color)
	_add_row("Name", _lo.skater_name, Color(0, 0, 0, 0), _step_name)
	_add_row("Body", BODY_LABELS.get(_lo.body_type, "?"), Color(0, 0, 0, 0), _step_body)
	_add_row("Skin", str(_cat.skin_tones[skin_i]["name"]), _lo.skin_tone, func(d: int) -> void:
		_lo.skin_tone = _step_palette(_cat.skin_tones, skin_i, d))
	_add_row("Hair style", _item_name(_lo.hair_style), Color(0, 0, 0, 0), func(d: int) -> void: _step_item("hair", d))
	_add_row("Hair colour", str(_cat.hair_colors[hair_i]["name"]), _lo.hair_color, func(d: int) -> void:
		_lo.hair_color = _step_palette(_cat.hair_colors, hair_i, d))
	_add_row("Eyes", str(_cat.eye_colors[eye_i]["name"]), _lo.eye_color, func(d: int) -> void:
		_lo.eye_color = _step_palette(_cat.eye_colors, eye_i, d))


func _build_clothes_rows() -> void:
	for slot: String in ["top", "bottom", "socks", "shoes"]:
		_add_item_rows(slot, slot.capitalize(), slot.capitalize() + " colour")
	var acc: String = _lo.item_id("accessory")
	_add_row("Accessory", _item_name(acc) if acc != "" else "None", Color(0, 0, 0, 0), _step_accessory)
	if acc != "":
		_add_color_row("accessory", "Accessory colour")


func _build_board_rows() -> void:
	_add_item_rows("deck", "Deck", "Graphic", "display")
	_add_item_rows("truck", "Trucks", "Truck colour", "top")
	_add_item_rows("wheel", "Wheels", "Wheel colour", "top")
	_add_row("Bearings", _item_name(_lo.bearing_id), Color(0, 0, 0, 0), func(d: int) -> void: _step_item("bearing", d), "top")
	_add_item_rows("griptape", "Griptape", "Grip colour", "grip")


func _add_item_rows(slot: String, title_: String, color_title: String, view: String = "") -> void:
	var desc: String = str(_cat.item(_lo.item_id(slot)).get("desc", ""))
	_add_row(title_, _item_name(_lo.item_id(slot)), Color(0, 0, 0, 0), func(d: int) -> void: _step_item(slot, d), view, desc)
	_add_color_row(slot, color_title, view)


func _add_color_row(slot: String, title_: String, view: String = "") -> void:
	var id: String = _lo.item_id(slot)
	var idx: int = _lo.item_color(slot)
	if _cat.color_count(id) == 0:
		return
	_add_row(title_, _cat.color_name(id, idx), _cat.color_of(id, idx), func(d: int) -> void:
		var n: int = _cat.color_count(id)
		_lo.set_color(slot, posmod(idx + d, n)), view)


func _item_name(id: String) -> String:
	return str(_cat.item(id).get("name", "None"))


func _owned_items(slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in _cat.items_for(slot, _lo.body_type):
		if _wallet.owns(str(it["id"])):
			out.append(it)
	return out


func _step_item(slot: String, dir: int) -> void:
	var items: Array[Dictionary] = _owned_items(slot)
	if items.is_empty():
		return
	var cur: int = 0
	for i: int in items.size():
		if items[i]["id"] == _lo.item_id(slot):
			cur = i
	var pick: Dictionary = items[posmod(cur + dir, items.size())]
	_lo.set_item(slot, str(pick["id"]), mini(_lo.item_color(slot), maxi((pick["colors"] as Array).size() - 1, 0)))


## None, then each owned accessory.
func _step_accessory(dir: int) -> void:
	var items: Array[Dictionary] = _owned_items("accessory")
	var cur: int = 0
	for i: int in items.size():
		if items[i]["id"] == _lo.item_id("accessory"):
			cur = i + 1
	var n: int = cur + dir
	n = posmod(n, items.size() + 1)
	if n == 0:
		_lo.set_item("accessory", "")
	else:
		_lo.set_item("accessory", str(items[n - 1]["id"]), 0)


func _step_palette(palette: Array[Dictionary], idx: int, dir: int) -> Color:
	return palette[posmod(idx + dir, palette.size())]["color"]


func _step_name(dir: int) -> void:
	var names: PackedStringArray = _cat.names
	if names.is_empty():
		return
	var cur: int = names.find(_lo.skater_name)
	_lo.skater_name = names[posmod(cur + dir, names.size())]


func _step_body(_dir: int) -> void:
	_lo.body_type = "male" if _lo.body_type == "female" else "female"
	_lo.sanitize(_owned_check())


func _after_change(focus_index: int) -> void:
	_rebuild_rows(focus_index)
	_refresh_preview()


func _refresh_preview() -> void:
	if _tab == 2:
		_preview.show_board(_lo, _board_view)
	else:
		_preview.show_skater(_lo, "face" if _tab == 0 else "body")


# Footer

func _on_random() -> void:
	_lo.randomise(_rng, _owned_check())
	_rebuild_rows(0)
	_refresh_preview()
	_say("Random look!")


func _on_save() -> void:
	if _save_enabled:
		_lo.save()
	_say("Saved!")
	closed.emit()


func _on_cancel() -> void:
	closed.emit()


func _say(msg: String) -> void:
	_toast.text = msg
	var tw: Tween = create_tween()
	_toast.modulate.a = 1.0
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


## For screenshots and tests.
func current_loadout() -> SkaterLoadout:
	return _lo


func set_tab(i: int) -> void:
	_set_tab(i)
