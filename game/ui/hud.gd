class_name Hud
extends CanvasLayer
## In-game HUD, THUG2-inspired and kid-friendly. Laid out for 1920x1080 with anchors, so it scales with the window.
## bind(skater) connects the skater's signals; the numbers are read from the skater every frame.
## Pure formatting helpers are static and unit tested (tests/unit/test_hud_format.gd).

const MARGIN: int = 48
const COUNT_RATE: float = 3.0  ## exponential approach speed of the score count-up, per second
const FLOAT_RISE: float = 110.0
const FLOAT_TIME: float = 1.3
const TRICK_HOLD: float = 0.9  ## s the big trick text stays after landing (it holds while still airborne)
const COMBO_TRICK_SIZE: int = 45  ## combo row, 25 percent bigger than SIZE_BODY / SIZE_BIG
const COMBO_PTS_SIZE: int = 68
const LAND_TAG_CLEAN: Color = Color(0.35, 0.95, 1.0)
const LAND_TAG_SKETCHY: Color = Color(1.0, 0.55, 0.2)
const BANNER_HOLD: float = 2.2
const SPECIAL_W: int = 44
const SPECIAL_H: int = 380
const BAL_W: int = 520
const BAL_H: int = 40
const BAL_TALL_W: int = 40
const BAL_TALL_H: int = 320
const BAL_HORIZ_Y: float = 0.15  ## screen height fraction for the horizontal balance meter
const BAL_MANUAL_X: float = 300.0  ## pixels right of centre for the manual (vertical) meter
const TRICK_Y: float = 0.255
const FLOAT_Y: float = 0.78
const BANNER_TOP: float = 215.0  ## px (1080 layout) under the score chip, away from the centre readouts
const TRACK_COLOUR := SkateThemeBuilder.CREAM
const SPECIAL_GLOW_WIDTH: int = 6

var _skater: Skater
var _shown_score: float = 0.0
var _time: float = 0.0
var _vertical_balance: bool = false

var _root: Control
var _fx: Control
var _score_value: Label
var _gaps_label: Label
var _combo_box: VBoxContainer
var _combo_trick: Label
var _combo_pts: AnimeText
var _special_fill: Panel
var _fill_style: StyleBoxFlat
var _special_glow: Panel
var _special_title: Label
var _bal_box: PanelContainer
var _bal_col: VBoxContainer
var _bal_title: Label
var _bal_view: HudBalanceView
var _trick_pop: AnimeText
var _trick_tween: Tween
var _banner: PanelContainer
var _banner_label: Label
var _banner_tween: Tween
var _banner_queue: PackedStringArray = PackedStringArray()
var _banner_busy: bool = false
var _trick_hold_left: float = 0.0
var _trick_shown: bool = false
var _land_result: String = "clean"
var _land_points: int = -1


## Balance meter drawn in code: a track, a sweet-spot band, a centre tick and a needle.
class HudBalanceView:
	extends Control
	var angle: float = 0.0
	var vertical: bool = false

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var centre: Vector2 = size * 0.5
		draw_style_box(UiStyle.flat_style(Hud.TRACK_COLOUR), Rect2(Vector2.ZERO, size))
		var inset: float = 14.0
		var a: float = clampf(angle, -1.0, 1.0)
		var needle_colour: Color = UiStyle.BUBBLEGUM if absf(a) > 0.7 else UiStyle.SUNSHINE
		var band: Color = Color(UiStyle.LIME, 0.6)
		if vertical:
			var half_v: float = h * 0.5 - inset
			draw_rect(Rect2(inset, centre.y - half_v * 0.3, w - inset * 2.0, half_v * 0.6), band)
			draw_line(Vector2(6.0, centre.y), Vector2(w - 6.0, centre.y), UiStyle.INK, 3.0)
			var y: float = centre.y - a * half_v
			draw_style_box(UiStyle.flat_style(needle_colour), Rect2(inset * 0.5, y - 7.0, w - inset, 14.0))
		else:
			var half_h: float = w * 0.5 - inset
			draw_rect(Rect2(centre.x - half_h * 0.3, inset, half_h * 0.6, h - inset * 2.0), band)
			draw_line(Vector2(centre.x, 6.0), Vector2(centre.x, h - 6.0), UiStyle.INK, 3.0)
			var x: float = centre.x + a * half_h
			draw_style_box(UiStyle.flat_style(needle_colour), Rect2(x - 7.0, inset * 0.5, 14.0, h - inset))


func _ready() -> void:
	layer = 10
	add_to_group("hud")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_score()
	_build_gaps()
	_build_combo()
	_build_special()
	_build_balance()
	_build_trick_pop()
	_build_banner()
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	if _skater != null:
		_connect_skater(_skater)
	_hide_debug_strip.call_deferred()


## The F5/F6 render-toggle strip is a dev aid: hidden unless run with --dev or SKATE_DEV=1 (F4 still toggles it).
func _hide_debug_strip() -> void:
	if OS.get_cmdline_user_args().has("--dev") or OS.get_cmdline_args().has("--dev") or OS.get_environment("SKATE_DEV") != "":
		return
	var host: Node = get_parent()
	if host == null:
		return
	for n: Node in host.get_children():
		if n is RenderToggles:
			(n as RenderToggles).visible = false


## Binds the HUD to a skater. Safe to call before or after the HUD enters the tree.
func bind(skater: Skater) -> void:
	if _skater != null and _skater != skater:
		_disconnect_skater(_skater)
	_skater = skater
	if skater == null:
		return
	_shown_score = float(skater.combo.landed_total)
	if is_node_ready():
		_connect_skater(skater)


func _connect_skater(s: Skater) -> void:
	if not s.trick_started.is_connected(_on_trick_started):
		s.trick_started.connect(_on_trick_started)
	if not s.combo_landed.is_connected(_on_combo_landed):
		s.combo_landed.connect(_on_combo_landed)
	if not s.landed.is_connected(_on_landed):
		s.landed.connect(_on_landed)
	if not s.combo_bailed.is_connected(_on_combo_bailed):
		s.combo_bailed.connect(_on_combo_bailed)
	if not s.gap_hit.is_connected(_on_gap_hit):
		s.gap_hit.connect(_on_gap_hit)


func _disconnect_skater(s: Skater) -> void:
	if s.trick_started.is_connected(_on_trick_started):
		s.trick_started.disconnect(_on_trick_started)
	if s.combo_landed.is_connected(_on_combo_landed):
		s.combo_landed.disconnect(_on_combo_landed)
	if s.landed.is_connected(_on_landed):
		s.landed.disconnect(_on_landed)
	if s.combo_bailed.is_connected(_on_combo_bailed):
		s.combo_bailed.disconnect(_on_combo_bailed)
	if s.gap_hit.is_connected(_on_gap_hit):
		s.gap_hit.disconnect(_on_gap_hit)


# --- pure helpers (unit tested) -----------------------------------------------------------------------

## 1234567 -> "1,234,567". Negative values keep their sign.
static func format_points(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = digits.substr(i, 1) + out
		count += 1
	return ("-" if n < 0 else "") + out


## The combo's points line: base x multiplier, e.g. (1250, 4) -> "1,250 x 4".
static func combo_line(base: int, mult: int) -> String:
	return "%s x %d" % [format_points(base), mult]


## Gap counter text, e.g. (3, 12) -> "Gaps 3/12".
static func gaps_line(found: int, total: int) -> String:
	return "Gaps %d/%d" % [found, total]


## Moves the shown score toward target. Exponential approach, snaps when within half a point.
static func count_up(shown: float, target: int, delta: float) -> float:
	var goal: float = float(target)
	if absf(goal - shown) < 0.5:
		return goal
	var k: float = 1.0 - exp(-COUNT_RATE * maxf(delta, 0.0))
	return shown + (goal - shown) * k


## Manual balance is shown as a vertical meter; grinds and lips are horizontal.
static func balance_is_vertical(kind: String) -> bool:
	return kind == "manual"


# --- layout -------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if _skater == null or not is_instance_valid(_skater):
		return
	var combo: Combo = _skater.combo
	_shown_score = count_up(_shown_score, combo.landed_total, delta)
	_score_value.text = format_points(roundi(_shown_score))
	_gaps_label.text = gaps_line(_skater.gaps.discovered_count(), _skater.gaps.total_count())
	_update_combo(combo)
	_update_special()
	_update_balance()
	_update_trick_hold(delta)


## The big trick text holds while the skater is still in the air, then fades TRICK_HOLD after touchdown.
func _update_trick_hold(delta: float) -> void:
	if not _trick_shown:
		return
	var airborne: bool = _skater.state.state == SkateState.State.AIR
	if airborne:
		_trick_hold_left = TRICK_HOLD
		return
	_trick_hold_left -= delta
	if _trick_hold_left <= 0.0:
		_trick_shown = false
		if _trick_tween != null and _trick_tween.is_valid():
			_trick_tween.kill()
		_trick_tween = create_tween()
		_trick_tween.tween_property(_trick_pop, "modulate:a", 0.0, 0.35)


func _update_combo(combo: Combo) -> void:
	var active: bool = combo.is_active()
	_combo_box.visible = active
	if active:
		_combo_trick.text = combo.display_text()
		_combo_pts.text = combo_line(combo.base_sum(), combo.multiplier())


func _update_special() -> void:
	var meter: SpecialMeter = _skater.special
	_special_fill.anchor_top = 1.0 - clampf(meter.value, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_time * 8.0)
	if meter.is_special():
		_fill_style.bg_color = UiStyle.SUNSHINE.lerp(UiStyle.WHITE, pulse * 0.25)
		_special_glow.visible = true
		_special_glow.modulate.a = 0.35 + 0.65 * pulse
		_special_title.text = "SPECIAL!"
	else:
		_fill_style.bg_color = UiStyle.SKY_BLUE
		_special_glow.visible = false
		_special_title.text = "SPECIAL"


func _update_balance() -> void:
	var kind: String = _skater.balance_kind
	_bal_box.visible = kind != ""
	if kind == "":
		return
	var vertical: bool = balance_is_vertical(kind)
	if vertical != _vertical_balance:
		_apply_balance_layout(vertical)
	_bal_title.text = "MANUAL" if vertical else "BALANCE"
	_bal_view.angle = _skater.balance.angle
	_bal_view.queue_redraw()


func _apply_balance_layout(vertical: bool) -> void:
	_vertical_balance = vertical
	_bal_view.vertical = vertical
	if vertical:
		_bal_view.custom_minimum_size = Vector2(BAL_TALL_W, BAL_TALL_H)
		_anchor_point(_bal_box, 0.5, 0.5)
		_bal_box.offset_left = BAL_MANUAL_X
		_bal_box.offset_right = BAL_MANUAL_X
	else:
		_bal_view.custom_minimum_size = Vector2(BAL_W, BAL_H)
		_anchor_point(_bal_box, 0.5, BAL_HORIZ_Y)
	_bal_view.queue_redraw()


## Anchors a control at a screen fraction and grows it symmetrically around that point.
func _anchor_point(c: Control, ax: float, ay: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = 0.0
	c.offset_bottom = 0.0
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH


func _anchor_top_left(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 0.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = MARGIN
	c.offset_right = MARGIN
	c.offset_top = MARGIN
	c.offset_bottom = MARGIN


func _anchor_top_right(c: Control) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = -MARGIN
	c.offset_right = -MARGIN
	c.offset_top = MARGIN
	c.offset_bottom = MARGIN
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _anchor_bottom_centre(c: Control) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = -MARGIN
	c.offset_bottom = -MARGIN
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _build_score() -> void:
	var chip := PanelContainer.new()
	chip.theme_type_variation = SkateThemeBuilder.PNL_TEAL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_top_left(chip)
	_root.add_child(chip)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	chip.add_child(col)
	col.add_child(UiStyle.label("SCORE", UiStyle.SIZE_SMALL, UiStyle.WHITE))
	_score_value = UiStyle.label("0", UiStyle.SIZE_BIG, UiStyle.WHITE)
	col.add_child(_score_value)


func _build_gaps() -> void:
	var chip := PanelContainer.new()
	chip.theme_type_variation = SkateThemeBuilder.PNL_CORAL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_top_right(chip)
	_root.add_child(chip)
	_gaps_label = UiStyle.label("Gaps 0/0", UiStyle.SIZE_BODY, UiStyle.WHITE)
	chip.add_child(_gaps_label)


func _build_combo() -> void:
	_combo_box = VBoxContainer.new()
	_combo_box.add_theme_constant_override("separation", 0)
	_combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_bottom_centre(_combo_box)
	_combo_box.visible = false
	_root.add_child(_combo_box)
	_combo_trick = UiStyle.label("", COMBO_TRICK_SIZE, UiStyle.WHITE)
	_combo_trick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_box.add_child(_combo_trick)
	_combo_pts = AnimeText.new("", COMBO_PTS_SIZE, UiStyle.SUNSHINE)
	_combo_pts.impact_lines = false
	_combo_pts.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_combo_box.add_child(_combo_pts)


func _build_special() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.offset_left = MARGIN
	col.offset_right = MARGIN
	_root.add_child(col)
	_special_title = UiStyle.label("SPECIAL", UiStyle.SIZE_SMALL, UiStyle.WHITE)
	col.add_child(_special_title)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(SPECIAL_W, SPECIAL_H)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	var track := Panel.new()
	track.add_theme_stylebox_override("panel", UiStyle.panel_style(TRACK_COLOUR))
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(track)
	_fill_style = UiStyle.flat_style(UiStyle.SKY_BLUE)
	_fill_style.border_width_left = 0
	_fill_style.border_width_right = 0
	_fill_style.border_width_top = 0
	_fill_style.border_width_bottom = 0
	_special_fill = Panel.new()
	_special_fill.add_theme_stylebox_override("panel", _fill_style)
	_special_fill.anchor_left = 0.0
	_special_fill.anchor_right = 1.0
	_special_fill.anchor_top = 1.0
	_special_fill.anchor_bottom = 1.0
	_special_fill.offset_left = 6.0
	_special_fill.offset_right = -6.0
	_special_fill.offset_top = 0.0
	_special_fill.offset_bottom = -6.0
	_special_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_special_fill)
	_special_glow = Panel.new()
	var glow := StyleBoxFlat.new()
	glow.draw_center = false
	glow.set_corner_radius_all(UiStyle.PANEL_RADIUS + 6)
	glow.set_border_width_all(SPECIAL_GLOW_WIDTH)
	glow.border_color = UiStyle.SUNSHINE
	_special_glow.add_theme_stylebox_override("panel", glow)
	_special_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_special_glow.offset_left = -10.0
	_special_glow.offset_top = -10.0
	_special_glow.offset_right = 10.0
	_special_glow.offset_bottom = 10.0
	_special_glow.visible = false
	_special_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_special_glow)


func _build_balance() -> void:
	_bal_box = PanelContainer.new()  ## dark backplate so scenery text never shows through the meter
	_bal_box.theme_type_variation = SkateThemeBuilder.PNL_NAVY
	_bal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bal_box.visible = false
	_root.add_child(_bal_box)
	_bal_col = VBoxContainer.new()
	_bal_col.add_theme_constant_override("separation", 6)
	_bal_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bal_box.add_child(_bal_col)
	_bal_title = UiStyle.label("BALANCE", UiStyle.SIZE_SMALL, UiStyle.WHITE)
	_bal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bal_col.add_child(_bal_title)
	_bal_view = HudBalanceView.new()
	_bal_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bal_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bal_col.add_child(_bal_view)
	_apply_balance_layout(false)


func _build_trick_pop() -> void:
	_trick_pop = AnimeText.new("", UiStyle.SIZE_TITLE, UiStyle.SUNSHINE)
	_trick_pop.modulate.a = 0.0
	_anchor_point(_trick_pop, 0.5, TRICK_Y)
	_root.add_child(_trick_pop)


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.theme_type_variation = SkateThemeBuilder.PNL_NAVY
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.pivot_offset_ratio = Vector2(0.5, 0.5)
	_banner.modulate.a = 0.0
	_anchor_top_left(_banner)
	_banner.offset_top = BANNER_TOP
	_banner.offset_bottom = BANNER_TOP
	_banner.grow_horizontal = Control.GROW_DIRECTION_END
	_root.add_child(_banner)
	_banner_label = UiStyle.label("", UiStyle.SIZE_BODY + 6, UiStyle.SUNSHINE)
	_banner.add_child(_banner_label)


# --- signal handlers and feedback -----------------------------------------------------------------

func _on_trick_started(trick: Dictionary) -> void:
	_pop_trick(str(trick.get("name", "")))


## combo_landed and the skater's landed signal fire in the same frame in either order, so both are folded
## together once the frame's emits are done.
func _on_combo_landed(points: int, _text: String) -> void:
	_land_points = points
	_flush_landing.call_deferred()


func _on_landed(result: String) -> void:
	_land_result = result


func _flush_landing() -> void:
	if _land_points < 0:
		return
	var pts: int = _land_points
	_land_points = -1
	var sketchy: bool = _land_result == "sketchy"
	_land_result = "clean"
	var size: int = land_size(pts)
	_spawn_float("+%s!" % format_points(pts), LAND_TAG_SKETCHY if sketchy else UiStyle.LIME, false, size)
	_spawn_tag("SKETCHY" if sketchy else "CLEAN!", LAND_TAG_SKETCHY if sketchy else LAND_TAG_CLEAN, sketchy)


## Font size of the +N! pop: grows with the combo, from SIZE_BIG up to 1.5 x SIZE_TITLE.
static func land_size(points: int) -> int:
	var t: float = clampf(float(points) / 3000.0, 0.0, 1.0)
	return int(lerpf(float(UiStyle.SIZE_BIG) * 1.1, float(UiStyle.SIZE_TITLE) * 1.4, t))


## A small CLEAN! / SKETCHY tag that pops above the points and fades.
func _spawn_tag(text: String, color: Color, wobble: bool) -> void:
	var lbl: AnimeText = AnimeText.new(text, UiStyle.SIZE_BODY, color)
	lbl.tilt_degrees = 6.0 if wobble else -6.0
	lbl.impact_lines = false
	_anchor_point(lbl, 0.5, FLOAT_Y - 0.09)
	_fx.add_child(lbl)
	lbl.pop(text)
	var move := lbl.create_tween().set_parallel(true)
	move.tween_property(lbl, "offset_top", -FLOAT_RISE * 0.6, FLOAT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move.tween_property(lbl, "offset_bottom", -FLOAT_RISE * 0.6, FLOAT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move.tween_property(lbl, "modulate:a", 0.0, FLOAT_TIME * 0.5).set_delay(FLOAT_TIME * 0.5)
	move.finished.connect(lbl.queue_free)


func _on_combo_bailed(_text: String) -> void:
	_spawn_float("Bail!", UiStyle.BUBBLEGUM, true, UiStyle.SIZE_TITLE)


func _on_gap_hit(gap_name: String, points: int) -> void:
	_show_banner("%s! +%s" % [gap_name, format_points(points)])


## Shows the trick name in the centre as anime action text: slams in big and crooked, settles, then fades.
func _pop_trick(text: String) -> void:
	if _trick_tween != null and _trick_tween.is_valid():
		_trick_tween.kill()
	_trick_pop.pop(text.to_upper())
	_trick_shown = true
	_trick_hold_left = TRICK_HOLD


## A word that floats up from the combo area and fades. Wobbly text rocks side to side.
func _spawn_float(text: String, color: Color, wobble: bool, size: int) -> void:
	var lbl: AnimeText = AnimeText.new(text, size, color)
	lbl.tilt_degrees = 5.0 if wobble else -5.0
	lbl.impact_lines = size <= UiStyle.SIZE_TITLE  ## big points would throw a screen-filling burst
	_anchor_point(lbl, 0.5, FLOAT_Y)
	_fx.add_child(lbl)
	lbl.pop(text)
	var move := lbl.create_tween().set_parallel(true)
	move.tween_property(lbl, "offset_top", -FLOAT_RISE, FLOAT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move.tween_property(lbl, "offset_bottom", -FLOAT_RISE, FLOAT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move.tween_property(lbl, "modulate:a", 0.0, FLOAT_TIME * 0.5).set_delay(FLOAT_TIME * 0.5)
	move.finished.connect(lbl.queue_free)
	if wobble:
		var wob := lbl.create_tween()
		wob.tween_interval(0.25)
		for i: int in range(6):
			var amp: float = 0.2 * (1.0 - float(i) / 6.0)
			var target: float = amp if i % 2 == 0 else -amp
			wob.tween_property(lbl, "rotation", target, 0.1).set_trans(Tween.TRANS_SINE)
		wob.tween_property(lbl, "rotation", 0.0, 0.1)


## The gap / goal banner drops in with a bounce, holds, then fades. Banners that arrive together queue up.
func _show_banner(text: String) -> void:
	_banner_queue.append(text)
	if not _banner_busy:
		_next_banner()


func _next_banner() -> void:
	if _banner_queue.is_empty():
		_banner_busy = false
		return
	_banner_busy = true
	_banner_label.text = _banner_queue[0]
	_banner_queue.remove_at(0)
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(0.6, 0.6)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(BANNER_HOLD if _banner_queue.is_empty() else BANNER_HOLD * 0.5)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.3)
	_banner_tween.tween_callback(_next_banner)
