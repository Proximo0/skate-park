class_name StepRow
extends Button
## A menu row: title on the left, "< value >" on the right with an optional colour swatch. Left/right (keys, d-pad,
## stick) or a click on an arrow emits `stepped(-1 / +1)`. Accept or a click elsewhere is the normal button press.

signal stepped(dir: int)

const ROW_HEIGHT: float = 58.0

var _title: Label
var _value: Label
var _swatch: ColorRect
var _left: Control
var _right: Control


## Small triangle arrow drawn in code (the default font has no arrow glyphs).
class Arrow extends Control:
	var dir: int = 1

	func _init(d: int) -> void:
		dir = d
		custom_minimum_size = Vector2(26, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var h: float = 11.0
		var pts: PackedVector2Array = [
			c + Vector2(-dir * h * 0.6, -h), c + Vector2(-dir * h * 0.6, h), c + Vector2(dir * h * 0.8, 0.0)]
		draw_colored_polygon(pts, UiStyle.INK)


func _init() -> void:
	custom_minimum_size = Vector2(0, ROW_HEIGHT)
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	var box: HBoxContainer = HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_right = -14
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = MenuKit.text("", UiStyle.SIZE_BODY)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_left = Arrow.new(-1)
	box.add_child(_left)
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(30, 30)
	_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_swatch)
	_value = MenuKit.text("", UiStyle.SIZE_BODY)
	_value.custom_minimum_size = Vector2(250, 0)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_value)
	_right = Arrow.new(1)
	box.add_child(_right)
	MenuKit.style_button(self, SkateThemeBuilder.BTN_ROW)


func setup(title_text: String, value_text: String, swatch: Color = Color(0, 0, 0, 0)) -> StepRow:
	_title.text = title_text
	set_value(value_text, swatch)
	return self


func set_value(value_text: String, swatch: Color = Color(0, 0, 0, 0), value_color: Color = UiStyle.INK) -> void:
	_value.text = value_text
	_value.add_theme_color_override("font_color", value_color)
	_swatch.modulate.a = 1.0 if swatch.a > 0.0 else 0.0  # keeps the arrows aligned across rows
	_swatch.color = Color(swatch, 1.0)


## Hides the arrows (rows that only act on accept).
func set_arrows_visible(on: bool) -> void:
	_left.visible = on
	_right.visible = on


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left", true):
		stepped.emit(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		stepped.emit(1)
		accept_event()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and _left.visible:
			var dir: int = 0
			if _left.get_global_rect().grow(8).has_point(mb.global_position):
				dir = -1
			elif _right.get_global_rect().grow(8).has_point(mb.global_position):
				dir = 1
			if dir != 0:
				if mb.pressed:
					stepped.emit(dir)
				accept_event()
