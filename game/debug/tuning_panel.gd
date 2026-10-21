class_name TuningPanel
extends CanvasLayer
## Live tuning panel for PhysicsTuning. Backquote toggles it. It docks on the right and edits
## PhysicsTuning.shared() as you drag or type, so the game keeps running behind it. Fields show in FIELDS order
## under group headers. A row whose value differs from its default gets an amber name. Save writes
## user://physics_tuning.json and copies the changes as JSON. Load resets to defaults and reads that file back.
## Nothing loads at startup.

const LAYER: int = 120
const PANEL_WIDTH: float = 420.0
const PANEL_BG := Color(0.06, 0.07, 0.11, 0.98)
const PANEL_EDGE := Color("#2B2F7A")
const BUTTON_FILL := Color("#2B2F7A")
const BUTTON_HOVER := Color("#3A3F95")
const BUTTON_PRESSED := Color("#1E2260")
const HEADER_COLOR := Color("#4FC3F7")
const NAME_COLOR := Color("#E8E8F0")
const CHANGED_COLOR := Color("#FFB000")
const STATUS_COLOR := Color("#C9CEDD")
const TOGGLE_KEY: int = KEY_QUOTELEFT
const SAVE_PATH: String = "user://physics_tuning.json"

var is_open: bool = false

var _rows: Dictionary = {}  ## field name -> {"name": Label, "slider": HSlider, "spin": SpinBox, "reset": Button}
var _rows_box: VBoxContainer
var _status: Label
var _syncing: bool = false  ## true while the panel writes values into its own controls, so their signals are ignored
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	PhysicsTuning.shared().changed.connect(_on_tuning_changed)
	visible = false
	refresh_all()


func _exit_tree() -> void:
	var tuning: PhysicsTuning = PhysicsTuning.shared()
	if tuning.changed.is_connected(_on_tuning_changed):
		tuning.changed.disconnect(_on_tuning_changed)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != TOGGLE_KEY:
		return
	get_viewport().set_input_as_handled()
	toggle()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## Shows the panel and the mouse. The previous mouse mode comes back on close().
func open() -> void:
	if is_open:
		return
	_saved_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	visible = true
	refresh_all()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if is_inside_tree():
		get_viewport().gui_release_focus()
	Input.mouse_mode = _saved_mouse_mode


## One row per tuning field.
func row_count() -> int:
	return _rows.size()


func row_slider(field: String) -> HSlider:
	var row: Dictionary = _rows.get(field, {})
	return row.get("slider") as HSlider


func row_spin(field: String) -> SpinBox:
	var row: Dictionary = _rows.get(field, {})
	return row.get("spin") as SpinBox


## Sets every field back to its default. PhysicsTuning.reset() emits no signal, so the rows are refreshed here.
func reset_all() -> void:
	PhysicsTuning.shared().reset()
	refresh_all()
	_set_status("Reset all to defaults.")


func reset_field(field: String) -> void:
	var info: Dictionary = PhysicsTuning.field_info(field)
	if info.is_empty():
		return
	PhysicsTuning.shared().set_value(field, float(info["default"]))


## Saves the full tuning to user://physics_tuning.json and copies the changes from defaults to the clipboard.
func save_preset() -> void:
	var err: Error = PhysicsTuning.shared().save_json(SAVE_PATH)
	if err != OK:
		_set_status("Save failed: %s" % error_string(err))
		return
	var count: int = _copy_changes()
	_set_status("Saved %s\nCopied %d changed fields to the clipboard." % [_abs_path(), count])


## Loads the saved file over the defaults, so a diff-only file gives the intended preset.
func load_preset() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_set_status("No saved tuning at %s" % _abs_path())
		return
	PhysicsTuning.shared().reset()
	if PhysicsTuning.shared().load_json(SAVE_PATH):
		refresh_all()
		_set_status("Loaded %s" % _abs_path())
	else:
		refresh_all()
		_set_status("Could not read %s" % _abs_path())


## Copies the changes from defaults to the clipboard only.
func copy_changes() -> void:
	var count: int = _copy_changes()
	_set_status("Copied %d changed fields to the clipboard." % count)


## Pushes the tuning's current values into every row.
func refresh_all() -> void:
	for f: Array in PhysicsTuning.FIELDS:
		var field: String = f[0]
		_sync_row(field, float(PhysicsTuning.shared().get(field)))


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_WIDTH
	panel.offset_right = 0.0
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_width_left = 3
	box.border_color = PANEL_EDGE
	box.set_content_margin_all(14.0)
	panel.add_theme_stylebox_override("panel", box)
	root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var title := Label.new()
	title.text = "Physics tuning"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", HEADER_COLOR)
	col.add_child(title)

	var hint := Label.new()
	hint.text = "` closes this panel. Changes apply live. Amber names differ from the default."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", STATUS_COLOR)
	col.add_child(hint)

	var buttons := GridContainer.new()
	buttons.columns = 2
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 6)
	col.add_child(buttons)
	buttons.add_child(_button("Reset all", reset_all))
	buttons.add_child(_button("Save", save_preset))
	buttons.add_child(_button("Load", load_preset))
	buttons.add_child(_button("Copy changes", copy_changes))

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", STATUS_COLOR)
	_status.text = " "
	col.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows_box)

	var group: String = ""
	for f: Array in PhysicsTuning.FIELDS:
		if f[5] != group:
			group = f[5]
			_add_group_header(group, _rows_box.get_child_count() > 0)
		_add_row(f)


func _add_group_header(group: String, separated: bool) -> void:
	if separated:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0.0, 8.0)
		_rows_box.add_child(gap)
	var header := Label.new()
	header.text = group.to_upper()
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", HEADER_COLOR)
	_rows_box.add_child(header)


func _add_row(f: Array) -> void:
	var field: String = f[0]
	var doc: String = f[6]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var name_label := Label.new()
	name_label.text = field.replace("_", " ")
	name_label.custom_minimum_size = Vector2(122.0, 0.0)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	name_label.tooltip_text = doc
	name_label.add_theme_font_size_override("font_size", 14)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = float(f[2])
	slider.max_value = float(f[3])
	slider.step = float(f[4])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(80.0, 0.0)
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = doc
	slider.value_changed.connect(_on_field_edited.bind(field))
	row.add_child(slider)

	var spin := SpinBox.new()
	spin.min_value = float(f[2])
	spin.max_value = float(f[3])
	spin.step = float(f[4])
	spin.custom_minimum_size = Vector2(96.0, 0.0)
	spin.select_all_on_focus = true
	spin.tooltip_text = doc
	spin.value_changed.connect(_on_field_edited.bind(field))
	row.add_child(spin)

	var reset := _button("Reset", reset_field.bind(field), 13)
	reset.custom_minimum_size = Vector2(50.0, 0.0)
	reset.size_flags_horizontal = Control.SIZE_FILL  ## only the slider takes the spare width
	reset.tooltip_text = "Back to the default: %s" % str(f[1])
	row.add_child(reset)

	_rows_box.add_child(row)
	_rows[field] = {"name": name_label, "slider": slider, "spin": spin, "reset": reset}


func _button(text: String, on_press: Callable, font_size: int = 15) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  ## keeps Space and the arrows for the game
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", NAME_COLOR)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("#5C6280"))
	b.add_theme_stylebox_override("normal", _button_box(BUTTON_FILL))
	b.add_theme_stylebox_override("hover", _button_box(BUTTON_HOVER))
	b.add_theme_stylebox_override("pressed", _button_box(BUTTON_PRESSED))
	b.add_theme_stylebox_override("disabled", _button_box(Color("#1A1C2E")))
	b.pressed.connect(on_press)
	return b


func _button_box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(6)
	box.set_content_margin_all(5.0)
	return box


## A slider or spin box moved. Writes through to the shared tuning; the changed signal then updates the other control.
func _on_field_edited(value: float, field: String) -> void:
	if _syncing:
		return
	PhysicsTuning.shared().set_value(field, value)


func _on_tuning_changed(field: String, value: float) -> void:
	_sync_row(field, value)


func _sync_row(field: String, value: float) -> void:
	if not _rows.has(field):
		return
	var row: Dictionary = _rows[field]
	var slider: HSlider = row["slider"]
	var spin: SpinBox = row["spin"]
	_syncing = true
	slider.value = value
	spin.value = value
	_syncing = false
	var name_label: Label = row["name"]
	var reset: Button = row["reset"]
	var default_value: float = float(PhysicsTuning.field_info(field).get("default", value))
	var differs: bool = not is_equal_approx(value, default_value)
	name_label.add_theme_color_override("font_color", CHANGED_COLOR if differs else NAME_COLOR)
	reset.disabled = not differs


func _copy_changes() -> int:
	var diff: Dictionary = PhysicsTuning.shared().diff_from_defaults()
	DisplayServer.clipboard_set(JSON.stringify(diff, "\t", true, true))
	return diff.size()


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func _abs_path() -> String:
	return ProjectSettings.globalize_path(SAVE_PATH)
