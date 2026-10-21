class_name PhysicsOverlay
extends CanvasLayer
## Physics debug overlay (F1). A text panel at top-left, right of the score chip (the special meter owns the left edge), rolling graphs at bottom-left
## (speed, height, vertical speed over 10 s, each with a state colour strip), and 3D gizmos that show through
## geometry: velocity (cyan), floor normal (yellow), facing (white), board up (magenta), a predicted ballistic
## arc while airborne or holding ollie, and a 3 s trail coloured by state. It starts hidden. Frames are always
## recorded (cheap), but text, graphs and gizmos are only rebuilt while it is visible.
## Use: add_child(PhysicsOverlay.new()), then bind(skater). Tests feed frames straight into feed_frame().

const LAYER: int = 118
const WINDOW_TICKS: int = 600  ## 10 s at 60 Hz
const TRAIL_TICKS: int = 180  ## 3 s
const EVENT_LOG: int = 6
const EVENT_MARKS: int = 128
const FONT_SIZE: int = 15
const PLATE_COLOR := Color(0.04, 0.05, 0.08, 0.72)
const TEXT_COLOR := Color("#E8ECF5")
const DIM_COLOR := Color("#9AA3B8")
const PANEL_X: float = 24.0
const TEXT_X: float = 176.0  ## right of the score chip (x 48..140) and clear of the special meter on the left edge
const TEXT_Y: float = 24.0
const GRAPH_W: float = 460.0
const GRAPH_H: float = 62.0
const STRIP_H: float = 6.0
const GRAPH_GAP: float = 12.0
const GRAPH_MARGIN: float = 24.0
const ARROW_LEN: float = 1.2
const ARC_STEP: float = 1.0 / 30.0
const ARC_MAX_STEPS: int = 150
const ARC_DROP: float = 10.0
const GRAPH_SPEED: int = 0
const GRAPH_HEIGHT: int = 1
const GRAPH_VERT: int = 2

const STATE_COLORS: Dictionary = {
	"ROLLING": Color(0.66, 0.68, 0.74),
	"AIR": Color("#4FC3F7"),
	"GRIND": Color("#FF9F1C"),
	"MANUAL": Color("#A56BF2"),
	"LIP": Color("#FF7EB6"),
	"WALLRIDE": Color("#1FB5A8"),
	"BAIL": Color("#F2403F"),
}
const STATE_NAMES: PackedStringArray = ["ROLLING", "AIR", "GRIND", "MANUAL", "LIP", "WALLRIDE", "BAIL"]
const COL_VEL := Color(0.0, 0.9, 1.0)
const COL_NORMAL := Color(1.0, 0.9, 0.1)
const COL_FACING := Color(1.0, 1.0, 1.0)
const COL_UP := Color(1.0, 0.1, 1.0)
const COL_ARC := Color(1.0, 0.65, 0.2)

## Stats from the frames.
var last_air_time: float = -1.0  ## seconds, -1 until a first air has ended
var last_air_peak: float = 0.0  ## metres above the take-off point
var last_ollie_pop: float = -1.0  ## peak height above the ollie point of the last ollie
var last_retention: float = -1.0  ## speed after landing / speed before, -1 until a first landing
var spawn_y: float = 0.0
var state_name: String = "ROLLING"
var state_since: float = 0.0

var _skater: Skater
var _frame: Dictionary = {}
var _have_frame: bool = false
var _count: int = 0  ## samples stored (up to WINDOW_TICKS)
var _head: int = 0  ## next write index
var _speed_buf := PackedFloat32Array()
var _height_buf := PackedFloat32Array()
var _vert_buf := PackedFloat32Array()
var _state_buf := PackedByteArray()
var _tick_buf := PackedInt32Array()
var _marks: Array[Vector2i] = []  ## ring of [tick, event index] for the graph ticks
var _mark_names: Array[String] = []
var _event_log: Array[String] = []
var _trail_pos := PackedVector3Array()
var _trail_state := PackedByteArray()
var _trail_head: int = 0
var _trail_count: int = 0
var _in_air: bool = false
var _air_start_t: float = 0.0
var _air_start_y: float = 0.0
var _air_peak_y: float = 0.0
var _last_air_speed: float = 0.0
var _ollie_y0: float = 0.0
var _ollie_active: bool = false
var _prev_state: String = "ROLLING"

var _label: Label
var _plate: PanelContainer
var _graphs: PhysicsGraphView
var _gizmo: Node3D
var _mesh_inst: MeshInstance3D
var _mesh := ImmediateMesh.new()
var _arc_points := PackedVector3Array()
var _font: Font


## Draws the three graphs. Reads the overlay's ring buffers.
class PhysicsGraphView:
	extends Control
	var ov: PhysicsOverlay

	func _draw() -> void:
		if ov == null or ov._count < 2:
			return
		var font: Font = ov._font
		var titles: PackedStringArray = ["speed m/s", "height m (vs spawn)", "vertical m/s"]
		for g: int in 3:
			var top: float = float(g) * (PhysicsOverlay.GRAPH_H + PhysicsOverlay.STRIP_H + PhysicsOverlay.GRAPH_GAP)
			ov._draw_graph(self, g, top, font, titles[g])


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_alloc()
	_font = SystemFont.new()
	(_font as SystemFont).font_names = PackedStringArray(["DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_build_ui()
	_build_gizmo()
	visibility_changed.connect(_on_visibility_changed)
	visible = false
	_on_visibility_changed()


func _alloc() -> void:
	if _speed_buf.size() == WINDOW_TICKS:
		return
	_speed_buf.resize(WINDOW_TICKS)
	_height_buf.resize(WINDOW_TICKS)
	_vert_buf.resize(WINDOW_TICKS)
	_state_buf.resize(WINDOW_TICKS)
	_tick_buf.resize(WINDOW_TICKS)
	_trail_pos.resize(TRAIL_TICKS)
	_trail_state.resize(TRAIL_TICKS)


func _build_ui() -> void:
	_plate = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PLATE_COLOR
	style.set_content_margin_all(8.0)
	style.set_corner_radius_all(6)
	_plate.add_theme_stylebox_override("panel", style)
	_plate.position = Vector2(TEXT_X, TEXT_Y)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	_label = Label.new()
	_label.add_theme_font_override("font", _font)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_constant_override("line_spacing", 1)
	_plate.add_child(_label)
	_graphs = PhysicsGraphView.new()
	_graphs.ov = self
	_graphs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graphs.anchor_top = 1.0
	_graphs.anchor_bottom = 1.0
	var total_h: float = 3.0 * (GRAPH_H + STRIP_H) + 2.0 * GRAPH_GAP
	_graphs.offset_left = PANEL_X
	_graphs.offset_right = PANEL_X + GRAPH_W
	_graphs.offset_top = -(total_h + GRAPH_MARGIN)
	_graphs.offset_bottom = -GRAPH_MARGIN
	add_child(_graphs)


func _build_gizmo() -> void:
	_gizmo = Node3D.new()
	_gizmo.name = "PhysicsGizmo"
	_gizmo.top_level = true
	_mesh_inst = MeshInstance3D.new()
	_mesh_inst.mesh = _mesh
	_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_inst.extra_cull_margin = 16384.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.vertex_color_use_as_albedo = true
	mat.render_priority = 127
	_mesh_inst.material_override = mat
	_gizmo.add_child(_mesh_inst)
	add_child(_gizmo)


## Follows a skater. Safe to call again with another one.
func bind(skater: Skater) -> void:
	if _skater != null and _skater.physics_ticked.is_connected(feed_frame):
		_skater.physics_ticked.disconnect(feed_frame)
	_skater = skater
	if skater == null:
		return
	spawn_y = skater.global_position.y if skater.is_inside_tree() else skater.position.y
	skater.physics_ticked.connect(feed_frame)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_F1:
		return
	get_viewport().set_input_as_handled()
	set_shown(not visible)


func set_shown(on: bool) -> void:
	visible = on


func _on_visibility_changed() -> void:
	if _gizmo != null:
		_gizmo.visible = visible
	if visible and _have_frame:
		_refresh()


# --- data ---------------------------------------------------------------------------------------------

## Takes one physics frame (the skater's debug dictionary). Always records; draws only when visible.
func feed_frame(frame: Dictionary) -> void:
	_alloc()
	_frame = frame
	var pos: Vector3 = frame.get("pos", Vector3.ZERO)
	var vel: Vector3 = frame.get("vel", Vector3.ZERO)
	var st: String = String(frame.get("state", "ROLLING"))
	var t: float = float(frame.get("t", 0.0))
	var tick: int = int(frame.get("tick", 0))
	var speed: float = float(frame.get("speed", vel.length()))
	if not _have_frame:
		_have_frame = true
		if spawn_y == 0.0:
			spawn_y = pos.y
		state_since = t
	if st != state_name:
		state_since = t
	_prev_state = state_name
	state_name = st
	var evs: Array = frame.get("events", [])
	for e: Variant in evs:
		_log_event(tick, String(e))
		if String(e) == "respawn":
			_in_air = false
			_ollie_active = false
		if String(e) == "ollie":
			_ollie_y0 = pos.y
			_ollie_active = true
	_air_stats(st, pos, speed, t)
	_push_sample(speed, pos.y - spawn_y, vel.y, st, tick)
	_push_trail(pos, st)
	if visible:
		_refresh()


func _air_stats(st: String, pos: Vector3, speed: float, t: float) -> void:
	if st == "AIR":
		if not _in_air:
			_in_air = true
			_air_start_t = t
			_air_start_y = pos.y
			_air_peak_y = pos.y
		_air_peak_y = maxf(_air_peak_y, pos.y)
		_last_air_speed = speed
		return
	if _in_air:
		_in_air = false
		last_air_time = t - _air_start_t
		last_air_peak = _air_peak_y - _air_start_y
		if _last_air_speed > 0.01:
			last_retention = speed / _last_air_speed
		if _ollie_active:
			last_ollie_pop = _air_peak_y - _ollie_y0
			_ollie_active = false


func _log_event(tick: int, name: String) -> void:
	_event_log.append("%d %s" % [tick, name])
	if _event_log.size() > EVENT_LOG:
		_event_log.remove_at(0)
	_marks.append(Vector2i(tick, _mark_names.size()))
	_mark_names.append(name)
	if _marks.size() > EVENT_MARKS:
		_marks.remove_at(0)
		_mark_names.remove_at(0)
		for i: int in _marks.size():
			_marks[i].y = i


func _push_sample(speed: float, h: float, vy: float, st: String, tick: int) -> void:
	_speed_buf[_head] = speed
	_height_buf[_head] = h
	_vert_buf[_head] = vy
	_state_buf[_head] = _state_index(st)
	_tick_buf[_head] = tick
	_head = (_head + 1) % WINDOW_TICKS
	_count = mini(_count + 1, WINDOW_TICKS)


func _push_trail(pos: Vector3, st: String) -> void:
	_trail_pos[_trail_head] = pos
	_trail_state[_trail_head] = _state_index(st)
	_trail_head = (_trail_head + 1) % TRAIL_TICKS
	_trail_count = mini(_trail_count + 1, TRAIL_TICKS)


func _state_index(st: String) -> int:
	var i: int = STATE_NAMES.find(st)
	return maxi(i, 0)


## Number of graph samples held (capped at WINDOW_TICKS).
func sample_count() -> int:
	return _count


## Graph sample i counted from the oldest (0) to the newest (sample_count() - 1). kind is GRAPH_SPEED, GRAPH_HEIGHT or GRAPH_VERT.
func sample_at(kind: int, i: int) -> float:
	var idx: int = (_head - _count + i + WINDOW_TICKS * 2) % WINDOW_TICKS
	match kind:
		GRAPH_SPEED:
			return _speed_buf[idx]
		GRAPH_HEIGHT:
			return _height_buf[idx]
	return _vert_buf[idx]


func event_log() -> Array[String]:
	return _event_log


# --- text ---------------------------------------------------------------------------------------------

func _refresh() -> void:
	if _label == null or not _have_frame:
		return
	_label.text = build_text()
	_graphs.queue_redraw()
	_rebuild_gizmo()


## The text panel content.
func build_text() -> String:
	var f: Dictionary = _frame
	var vel: Vector3 = f.get("vel", Vector3.ZERO)
	var pos: Vector3 = f.get("pos", Vector3.ZERO)
	var n: Vector3 = f.get("floor_normal", Vector3.UP)
	var speed: float = float(f.get("speed", 0.0))
	var slope: float = rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))
	var held: PackedStringArray = PackedStringArray(f.get("held", []))
	var rail: String = String(f.get("rail", ""))
	var lines: PackedStringArray = []
	lines.append("PHYSICS  tick %d  t %.2f" % [int(f.get("tick", 0)), float(f.get("t", 0.0))])
	lines.append("state    %s  %.2fs" % [state_name, float(f.get("t", 0.0)) - state_since])
	lines.append("speed    %.2f m/s  %.1f km/h" % [speed, speed * 3.6])
	lines.append("vel      %+.2f %+.2f %+.2f" % [vel.x, vel.y, vel.z])
	lines.append("vert     %+.2f m/s" % vel.y)
	lines.append("height   %+.2f m vs spawn" % (pos.y - spawn_y))
	lines.append("normal   %+.2f %+.2f %+.2f  slope %.1f deg" % [n.x, n.y, n.z, slope])
	lines.append("floor %s  wall %s" % [_yn(f.get("on_floor", false)), _yn(f.get("on_wall", false))])
	lines.append("pump %s  push %s  brake %s" % [_yn(f.get("pumping", false)), _yn(f.get("pushing", false)), _yn(f.get("braking", false))])
	lines.append("crouch   %.2f  anim %s" % [float(f.get("crouch", 0.0)), String(f.get("anim", ""))])
	lines.append("rail     %s" % (rail if rail != "" else "-"))
	lines.append("held     %s" % (" ".join(held) if not held.is_empty() else "-"))
	lines.append("")
	lines.append("last air  %s" % _fmt_air())
	lines.append("ollie pop %s" % ("-" if last_ollie_pop < 0.0 else "%.2f m" % last_ollie_pop))
	lines.append("landing   %s" % ("-" if last_retention < 0.0 else "speed kept %.0f%%" % (last_retention * 100.0)))
	lines.append("")
	lines.append("events (last %d, newest first)" % EVENT_LOG)
	for i: int in EVENT_LOG:
		var k: int = _event_log.size() - 1 - i
		lines.append("  " + (_event_log[k] if k >= 0 else "."))
	lines.append("F1 hide  F2 slow  F3 freeze  . step")
	return "\n".join(lines)


func _fmt_air() -> String:
	if last_air_time < 0.0:
		return "-"
	return "%.2fs  peak %.2f m" % [last_air_time, last_air_peak]


func _yn(v: Variant) -> String:
	return "Y" if bool(v) else "n"


# --- graphs -------------------------------------------------------------------------------------------

func _graph_value(kind: int, i: int) -> float:
	return sample_at(kind, i)


func _draw_graph(c: Control, kind: int, top: float, font: Font, title: String) -> void:
	var lo: float = 0.0
	var hi: float = 1.0
	if kind == GRAPH_SPEED:
		hi = 10.0
	elif kind == GRAPH_HEIGHT:
		lo = 0.0
		hi = 1.0
	else:
		hi = 4.0
	var seen_lo: float = INF
	var seen_hi: float = -INF
	for i: int in _count:
		var v: float = _graph_value(kind, i)
		seen_lo = minf(seen_lo, v)
		seen_hi = maxf(seen_hi, v)
	if kind == GRAPH_SPEED:
		hi = maxf(10.0, ceilf(seen_hi / 5.0) * 5.0)
		lo = 0.0
	elif kind == GRAPH_HEIGHT:
		lo = minf(0.0, floorf(seen_lo))
		hi = maxf(2.0, ceilf(seen_hi))
	else:
		var m: float = maxf(4.0, ceilf(maxf(absf(seen_lo), absf(seen_hi)) / 2.0) * 2.0)
		lo = -m
		hi = m
	var rect := Rect2(0.0, top, GRAPH_W, GRAPH_H)
	c.draw_rect(rect, PLATE_COLOR)
	if lo < 0.0 and hi > 0.0:
		var zy: float = rect.position.y + rect.size.y * (hi / (hi - lo))
		c.draw_line(Vector2(0.0, zy), Vector2(GRAPH_W, zy), Color(1, 1, 1, 0.25), 1.0)
	var span: float = hi - lo
	var last: Vector2 = Vector2.ZERO
	var w: float = GRAPH_W / float(WINDOW_TICKS)
	var x0: float = GRAPH_W - float(_count) * w
	for i: int in _count:
		var v: float = _graph_value(kind, i)
		var p := Vector2(x0 + float(i) * w, rect.end.y - rect.size.y * clampf((v - lo) / span, 0.0, 1.0))
		if i > 0:
			c.draw_line(last, p, TEXT_COLOR, 1.5)
		last = p
	# state strip under the graph
	var strip_y: float = top + GRAPH_H
	for i: int in _count:
		var idx: int = (_head - _count + i + WINDOW_TICKS * 2) % WINDOW_TICKS
		c.draw_rect(Rect2(x0 + float(i) * w, strip_y, maxf(w, 1.0), STRIP_H), STATE_COLORS[STATE_NAMES[_state_buf[idx]]])
	# event ticks
	var newest: int = _tick_buf[(_head - 1 + WINDOW_TICKS) % WINDOW_TICKS]
	for m: Vector2i in _marks:
		var age: int = newest - m.x
		if age < 0 or age >= _count:
			continue
		var ex: float = GRAPH_W - float(age) * w
		c.draw_line(Vector2(ex, top), Vector2(ex, top + 8.0), Color(1, 1, 1, 0.9), 1.0)
	var cur: float = _graph_value(kind, _count - 1)
	var label: String = "%s  [%.0f..%.0f]  now %.2f" % [title, lo, hi, cur]
	c.draw_string(font, Vector2(4.0, top + 13.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, DIM_COLOR)


# --- 3D gizmos ----------------------------------------------------------------------------------------

func _rebuild_gizmo() -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var pos: Vector3 = _frame.get("pos", Vector3.ZERO)
	var vel: Vector3 = _frame.get("vel", Vector3.ZERO)
	var base: Vector3 = pos + Vector3(0.0, 0.3, 0.0)
	var vlen: float = clampf(vel.length() * 0.2, 0.0, 3.0)
	if vel.length() > 0.05:
		_arrow(base, vel.normalized() * vlen, COL_VEL)
	_arrow(base, Vector3(_frame.get("floor_normal", Vector3.UP)) * ARROW_LEN, COL_NORMAL)
	_arrow(base, Vector3(_frame.get("facing", Vector3.FORWARD)) * ARROW_LEN, COL_FACING)
	_arrow(base, Vector3(_frame.get("board_up", Vector3.UP)) * ARROW_LEN * 0.8, COL_UP)
	_add_trail()
	var held: Array = _frame.get("held", [])
	if state_name == "AIR" or held.has("ollie"):
		_add_arc(pos, vel)
	_mesh.surface_end()


func _arrow(from: Vector3, dir: Vector3, col: Color) -> void:
	var len: float = dir.length()
	if len < 0.01:
		return
	var to: Vector3 = from + dir
	_line(from, to, col)
	var d: Vector3 = dir / len
	var side: Vector3 = d.cross(Vector3.UP)
	if side.length() < 0.1:
		side = d.cross(Vector3.RIGHT)
	side = side.normalized()
	var head: float = minf(0.25, len * 0.3)
	_line(to, to - d * head + side * head * 0.5, col)
	_line(to, to - d * head - side * head * 0.5, col)


func _line(a: Vector3, b: Vector3, col: Color) -> void:
	_mesh.surface_set_color(col)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(col)
	_mesh.surface_add_vertex(b)


func _add_trail() -> void:
	if _trail_count < 2:
		return
	var prev: Vector3 = Vector3.ZERO
	for i: int in _trail_count:
		var idx: int = (_trail_head - _trail_count + i + TRAIL_TICKS * 2) % TRAIL_TICKS
		var p: Vector3 = _trail_pos[idx]
		if i > 0:
			var col: Color = STATE_COLORS[STATE_NAMES[_trail_state[idx]]]
			col.a = 0.35 + 0.65 * float(i) / float(_trail_count)
			_line(prev, p, col)
		prev = p


## Predicted ballistic path with the live gravity: dots until it falls 10 m below the start or hits something.
func _add_arc(pos: Vector3, vel: Vector3) -> void:
	var g: float = PhysicsTuning.shared().gravity
	if _skater != null:
		g = _skater.tune.gravity
	var space: PhysicsDirectSpaceState3D = null
	if _gizmo != null and _gizmo.is_inside_tree():
		space = _gizmo.get_world_3d().direct_space_state
	var p: Vector3 = pos
	var v: Vector3 = vel
	var min_y: float = pos.y - ARC_DROP
	var dot: float = 0.07
	for i: int in ARC_MAX_STEPS:
		var nv: Vector3 = v + Vector3(0.0, -g * ARC_STEP, 0.0)
		var np: Vector3 = p + (v + nv) * 0.5 * ARC_STEP
		var hit: bool = false
		if space != null:
			var q := PhysicsRayQueryParameters3D.create(p, np)
			if _skater != null:
				q.exclude = [_skater.get_rid()]
			var r: Dictionary = space.intersect_ray(q)
			if not r.is_empty():
				np = r["position"]
				hit = true
		_cross(np, dot, COL_ARC)
		if hit or np.y < min_y:
			if hit:
				_cross(np, dot * 2.0, COL_NORMAL)
			break
		p = np
		v = nv


func _cross(p: Vector3, s: float, col: Color) -> void:
	_line(p - Vector3(s, 0, 0), p + Vector3(s, 0, 0), col)
	_line(p - Vector3(0, s, 0), p + Vector3(0, s, 0), col)
	_line(p - Vector3(0, 0, s), p + Vector3(0, 0, s), col)
