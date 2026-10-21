class_name ShopHud
extends CanvasLayer
## The shop's on-screen layer: the shop name tag (top left), a "Press E / A to ..." prompt (bottom centre) while
## the player is at a station, and speech bubbles over talking NPCs (projected from 3D every frame).
## Sizes are 1920 x 1080 px like the rest of the UI.

const PROMPT_Y: float = 0.82
const BUBBLE_WIDTH: float = 460.0

var npcs: Array[ShopNpc] = []
var _root: Control
var _prompt: PanelContainer
var _prompt_key: Label
var _prompt_text: Label
var _bubbles: Dictionary = {}  ## ShopNpc -> PanelContainer
var _hint: Label


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var tag: PanelContainer = PanelContainer.new()
	tag.theme_type_variation = SkateThemeBuilder.PNL_NAVY
	tag.position = Vector2(40, 32)
	_root.add_child(tag)
	var col: VBoxContainer = VBoxContainer.new()
	tag.add_child(col)
	col.add_child(UiStyle.label("SUNSET SKATE CO.", UiStyle.SIZE_BODY, UiStyle.SUNSHINE))
	_hint = UiStyle.label("Walk up to anything to shop  -  Esc / Start: title", UiStyle.SIZE_SMALL, UiStyle.WHITE, false)
	col.add_child(_hint)

	_prompt = PanelContainer.new()
	_prompt.theme_type_variation = SkateThemeBuilder.PNL_NAVY
	_root.add_child(_prompt)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_prompt.add_child(row)
	row.add_child(UiStyle.label("Press", UiStyle.SIZE_BODY, UiStyle.WHITE))
	var key_panel: PanelContainer = PanelContainer.new()
	key_panel.theme_type_variation = SkateThemeBuilder.PNL_SUN
	row.add_child(key_panel)
	_prompt_key = UiStyle.label(ShopStation.PROMPT_KEYS, UiStyle.SIZE_BODY, UiStyle.INK, false)
	key_panel.add_child(_prompt_key)
	_prompt_text = UiStyle.label("", UiStyle.SIZE_BODY, UiStyle.WHITE)
	row.add_child(_prompt_text)
	_prompt.visible = false


## Shows "Press E / A to <prompt>" for a station, or hides the prompt for null.
func show_prompt(st: ShopStation) -> void:
	_prompt.visible = st != null
	if st == null:
		return
	_prompt_text.text = "to " + st.prompt
	_prompt.reset_size()
	var vp: Vector2 = _root.size
	_prompt.position = Vector2((vp.x - _prompt.size.x) * 0.5, vp.y * PROMPT_Y)


## The prompt as one line, for tests: "Press E / A to <prompt>" or "".
func prompt_line() -> String:
	return "Press %s %s" % [_prompt_key.text, _prompt_text.text] if _prompt.visible else ""


func set_hint(text: String) -> void:
	_hint.text = text


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	for npc: ShopNpc in npcs:
		if not is_instance_valid(npc):
			continue
		var b: PanelContainer = _bubbles.get(npc, null) as PanelContainer
		var talking: bool = npc.is_talking() and cam != null and visible
		if talking and b == null:
			b = _make_bubble(npc)
			_bubbles[npc] = b
		if b == null:
			continue
		b.visible = talking and not cam.is_position_behind(npc.bubble_anchor())
		if not b.visible:
			continue
		(b.get_meta("label") as Label).text = npc.display_name + ":  " + npc.current_line()
		b.reset_size()
		var p: Vector2 = cam.unproject_position(npc.bubble_anchor())
		# The canvas is stretched from the window: map viewport pixels to canvas units.
		var scale_k: Vector2 = _root.size / Vector2(get_viewport().get_visible_rect().size)
		p *= scale_k
		b.position = Vector2(clampf(p.x - b.size.x * 0.5, 16.0, _root.size.x - b.size.x - 16.0),
				clampf(p.y - b.size.y - 44.0, 16.0, _root.size.y - b.size.y - 16.0))
		b.modulate.a = clampf(npc.bubble_left / 0.4, 0.0, 1.0)


## Cream sticker bubble with a small navy-outlined tail pointing down at the speaker.
class Bubble extends PanelContainer:
	func _draw() -> void:
		var cx: float = size.x * 0.5
		var y: float = size.y - 2.0
		var outline: PackedVector2Array = [Vector2(cx - 24.0, y), Vector2(cx + 24.0, y), Vector2(cx, y + 38.0)]
		draw_colored_polygon(outline, SkateThemeBuilder.NAVY)
		var fill: PackedVector2Array = [Vector2(cx - 14.0, y + 6.0), Vector2(cx + 14.0, y + 6.0), Vector2(cx, y + 24.0)]
		draw_colored_polygon(fill, SkateThemeBuilder.CREAM)


func _make_bubble(npc: ShopNpc) -> PanelContainer:
	var b: PanelContainer = Bubble.new()
	b.theme_type_variation = SkateThemeBuilder.PNL_CREAM
	var l: Label = MenuKit.text("", UiStyle.SIZE_SMALL + 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(BUBBLE_WIDTH, 0)
	b.add_child(l)
	b.set_meta("label", l)
	b.name = "Bubble_" + npc.role
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(b)
	return b
