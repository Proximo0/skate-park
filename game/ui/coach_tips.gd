class_name CoachTips
extends CanvasLayer
## First-time coach tips: a small card bottom-left that names a move and how to do it, once per move (saved in the
## ProgressStore). A tip appears the first time the player does the move, and, to teach the ones they never found, as
## a "TRY" nudge after every few landed combos. One at a time, never during a bail, gone after a few seconds.

const TIPS: Dictionary = {
	"boneless": ["BONELESS", "Up, Up + Ollie. Plant a foot, then pop. Chain it into a combo."],
	"wallplant": ["WALLPLANT", "Ollie in the air close to a wall to plant a foot on it and kick off."],
	"acid_drop": ["ACID DROP", "Revert in the air over a bank or quarter that falls away to drop in with speed."],
	"powerslide": ["POWERSLIDE", "Revert while rolling to skid sideways and scrub speed."],
	"nollie": ["NOLLIE", "Nose-first stance. Tap Nollie again to switch back."],
	"grind_switch": ["GRIND LINK", "Ollie off a rail, then Grind at the next one to link grinds in one combo."],
	"rail_switch": ["SWITCH GRINDS", "On a rail, push the stick and press Grind to switch to the other grind. Hold Ollie to charge the pop."],
	"manual_switch": ["MANUAL TRICKS", "In a manual, flick the stick to switch, spin to pivot, or Grab + stick for flatland."],
	"manual_revert": ["MANUAL REVERT", "Revert in a manual to roll out of it with the combo still open."],
	"natas": ["NATAS SPIN", "Grind in the air over a post to land on it, then use the spin buttons to spin. Ollie to pop off."],
	"sticker_slap": ["STICKER SLAP", "Ollie beside a wall while riding along it to slap a sticker on it."],
	"bert_slide": ["BERT SLIDE", "Revert on a bank to drag a hand and carve around it."],
	"skitch": ["SKITCH", "Grab behind a moving car to hang on and get towed. Ollie to let go."],
	"focus": ["FOCUS", "With a full special meter, press F or R3 for slow motion. It drains the meter."],
	"lip_trick": ["LIP TRICKS", "On a lip or a wall, Flip, Grab or Revert to pop out with that trick."],
}
## The order "TRY" nudges teach the moves the player has not found yet.
const NUDGE_ORDER: PackedStringArray = ["boneless", "powerslide", "nollie", "grind_switch", "wallplant", "acid_drop", "rail_switch", "manual_switch", "lip_trick", "natas", "sticker_slap", "bert_slide", "skitch", "focus"]
const NUDGE_EVERY: int = 3  ## landed combos between nudges
const MIN_GAP: float = 18.0  ## s between tips
const GRIND_LINK_WINDOW: float = 2.0  ## s between two grinds that counts as a link
const SHOW_TIME: float = 5.5
const TIP_WIDTH: float = 640.0
const TIP_BOTTOM: float = 150.0

var store: ProgressStore
var _skater: Skater = null
var _combos: int = 0
var _quiet: float = 0.0
var _card: PanelContainer
var _head: Label
var _body: Label
var _tween: Tween
var _shown_id: String = ""
var _prev_state: SkateState.State = SkateState.State.ROLLING
var _grind_gap: float = 0.0


## The tip a trick id maps to ("" = none). Grinds map to grind_switch only through the skater's state, not here.
static func tip_for_trick(trick_id: String) -> String:
	return trick_id if trick_id in ["boneless", "wallplant", "acid_drop"] else ""


## The next unseen tip for a nudge, "" when every move is known.
static func next_nudge(seen: Callable) -> String:
	for id: String in NUDGE_ORDER:
		if not bool(seen.call(id)):
			return id
	return ""


func bind(skater: Skater, s: ProgressStore = null) -> void:
	store = s if s != null else ProgressStore.shared()
	_skater = skater
	skater.trick_started.connect(_on_trick)
	skater.combo_landed.connect(_on_combo_landed)
	skater.powerslide_changed.connect(func(on: bool) -> void: if on: _offer("powerslide", false))
	skater.nollie_changed.connect(func(on: bool) -> void: if on: _offer("nollie", false))
	skater.physics_ticked.connect(_on_tick)


func _ready() -> void:
	layer = 6
	_card = PanelContainer.new()
	_card.theme_type_variation = SkateThemeBuilder.PNL_NAVY
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_left = 48.0
	_card.offset_bottom = -TIP_BOTTOM
	_card.custom_minimum_size = Vector2(TIP_WIDTH, 0)
	_card.modulate.a = 0.0
	_card.visible = false
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_card.add_child(col)
	_head = UiStyle.label("", UiStyle.SIZE_SMALL, UiStyle.SUNSHINE)
	col.add_child(_head)
	_body = UiStyle.label("", UiStyle.SIZE_SMALL - 2, UiStyle.WHITE, false)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(TIP_WIDTH - 56.0, 0)
	col.add_child(_body)


func _process(delta: float) -> void:
	_quiet = maxf(_quiet - delta, 0.0)
	_grind_gap = maxf(_grind_gap - delta, 0.0)
	if _skater == null:
		return
	# GRIND, AIR, GRIND within a couple of seconds is a rail-to-rail link: the move the tip teaches.
	var st: SkateState.State = _skater.state.state
	if st != _prev_state:
		if _prev_state == SkateState.State.GRIND:
			_grind_gap = GRIND_LINK_WINDOW
		elif st == SkateState.State.GRIND and _grind_gap > 0.0:
			_offer("grind_switch", false)
		_prev_state = st


## The tip a skater event teaches ("" = none): the first time the player does the new move, it is named.
static func tip_for_event(event: String) -> String:
	match event:
		"grind_switch":
			return "rail_switch"
		"manual_switch", "manual_pivot", "flatland":
			return "manual_switch"
		"manual_revert":
			return "manual_revert"
		"lip_pop", "lip_revert", "wall_revert":
			return "lip_trick"
		"natas":
			return "natas"
		"sticker_slap":
			return "sticker_slap"
		"bert_slide":
			return "bert_slide"
		"skitch":
			return "skitch"
		"focus_on":
			return "focus"
	return ""


func _on_tick(frame: Dictionary) -> void:
	for e: Variant in frame.get("events", []):
		var id: String = tip_for_event(str(e))
		if id != "":
			_offer(id, false)


func _on_trick(trick: Dictionary) -> void:
	var id: String = tip_for_trick(str(trick.get("id", "")))
	if id != "":
		_offer(id, false)


func _on_combo_landed(_points: int, _text: String) -> void:
	_combos += 1
	if _combos % NUDGE_EVERY != 0:
		return
	var id: String = next_nudge(store.tip_seen)
	if id != "":
		_offer(id, true)


## Shows a tip if it is new and nothing else is up. nudge: header reads "TRY" instead of the plain name.
func _offer(id: String, nudge: bool) -> bool:
	if store == null or store.tip_seen(id) or not TIPS.has(id) or _quiet > 0.0:
		return false
	if _skater != null and _skater.state.state == SkateState.State.BAIL:
		return false
	store.mark_tip(id)
	store.save()
	_show(id, nudge)
	return true


func shown_id() -> String:
	return _shown_id


func _show(id: String, nudge: bool) -> void:
	var t: Array = TIPS[id]
	_shown_id = id
	_quiet = MIN_GAP
	_head.text = ("TRY: " if nudge else "TIP: ") + str(t[0])
	_body.text = str(t[1])
	_card.visible = true
	if _tween != null:
		_tween.kill()
	_card.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_card, "modulate:a", 1.0, 0.25)
	_tween.tween_interval(SHOW_TIME)
	_tween.tween_property(_card, "modulate:a", 0.0, 0.6)
	_tween.tween_callback(func() -> void: _card.visible = false)
