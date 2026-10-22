class_name Skater
extends CharacterBody3D
## The player's skater: a kinematic board controller that rides any surface (flat, ramps, vert), plus the
## glue that feeds input into the pure logic modules (SkateState, TrickInput, Combo, SpecialMeter, Balance,
## Gaps, Landing, SpinTracker). Visuals live under $Visual and are posed by SkaterPoser from `anim`.

signal trick_started(trick: Dictionary)
signal combo_changed(text: String, base: int, multiplier: int)
signal combo_landed(points: int, text: String)
signal combo_bailed(text: String)
signal landed(result: String)
signal gap_hit(gap_name: String, points: int)
signal bailed
## Emitted at the end of every physics tick with `debug` (see docs/physics_debug_brief.md).
signal physics_ticked(frame: Dictionary)
## The ramp snap (Q + E / L1 + R1) started: mode is "drop_in", "roll_in", "air_in", "out" or "out_deck".
signal ramp_snapped(mode: String)
## The ramp snap was pressed with no ramp in reach (the HUD shows a hint).
signal ramp_snap_missed

const SPIN_POINTS_PER_180 := 100
## Floor contacts bending more than about 25 degrees from the current floor in one tick are checked against the
## mesh: an edge or vertex touch is a wall graze, not a new floor.
const SNAG_CHECK_DOT: float = 0.906
## Ground ticks on a curved or sloped face (normal y under 0.9) needed before a steep launch counts as vert air.
const VERT_MIN_TRANSITION_TICKS: int = 3
## Landing back on a ramp from vert air, the heading is judged against where gravity takes the skater a moment
## later, not the instantaneous velocity: at the top of a sideways carve the velocity runs along the wall, and a board
## pointed down the fall line (the right re-entry) read as 81 deg across it and bailed. The better reading wins.
## On flat ground gravity is along the normal, so the lookahead changes nothing there.
const VERT_REENTRY_LOOKAHEAD: float = 0.2
## Edge contacts no higher than this above the board (m) are rolled over, not grazed.
## A floor contact more than about 50 degrees from the current floor is never a new floor (ramp toes are gentler).
const FLOOR_JUMP_DOT: float = 0.64
## Share of the speed along the coping kept on a vert launch. Real (and THUG) vert airs carry it: going up a
## quarter at an angle sends you along the ramp, not straight up and to a stop.
const VERT_LATERAL_KEEP: float = 0.85
## Going up a transition, the pump only works below this steepness (normal y, about 66 degrees: the extension through
## the middle of the curve), not on the upper wall, and only while the surface is curving (a bend within
## PUMP_CURVE_TIME): pumping needs a curve, a flat bank gives nothing.
const PUMP_CURVE_TIME: float = 0.15
const PUMP_UP_MIN_NY: float = 0.4
## Grind topple: falling off the side of a rail hops you down to the ground carving, unless the drop is bigger than
## TOPPLE_MAX_DROP (m) or you are slower than TOPPLE_MIN_SPEED (m/s): then it is a real bail.
const TOPPLE_MAX_DROP: float = 1.5
const TOPPLE_MIN_SPEED: float = 2.0
const TOPPLE_KEEP: float = 0.88  ## share of the grind speed carried into the hop (about 85% after the landing)
const TOPPLE_HOP_UP: float = 2.5  ## m/s up
const TOPPLE_HOP_SIDE: float = 2.0  ## m/s toward the fall side
const TOPPLE_LAND_TURN: float = 0.2  ## rad turned toward the fall side on touchdown (the sideways hop already gives about 15 deg)
const TOPPLE_CARVE_TIME: float = 0.5  ## s of carve after the landing
const TOPPLE_CARVE_STEER: float = 0.3  ## stick-equivalent steer of that carve, fading to 0
## Floor contacts in the air flatter than this (normal y) always count as a landing; steeper ones only on a real face.
const LAND_EDGE_MIN_NY: float = 0.7
## Outside vert air, a surface steeper than this (normal y) is never landed on.
const LAND_STEEP_NY: float = 0.35
## Speed (m/s) at which rail_friction is the grind's deceleration.
const RAIL_FRICTION_REF: float = 8.0
const EDGE_STEP_HEIGHT: float = 0.12
## Wall hits squarer than this (cos of incidence) bounce back instead of deflecting along the wall.
const WALL_HEAD_ON: float = 0.9
## Share of the speed into a wall that comes back as a bounce: WALL_BOUNCE_SLOW at a bump, growing to
## WALL_BOUNCE_FAST at the slam speed (THUG-style: a harder hit throws you further back off the wall).
const WALL_BOUNCE_SLOW: float = 0.2
const WALL_BOUNCE_FAST: float = 0.35
## Head-on speed into a wall (m/s) above which the skater bails instead of stumbling, and how square the hit must be
## (cos of incidence, 0.95 is within 18 degrees of head-on). Anything softer or more glancing bounces off.
const WALL_BAIL_SPEED: float = 13.0
const WALL_BAIL_SQUARE: float = 0.95
## Fastest fall in the air, m/s (a terminal speed: a drop from about 25 m at gravity 18).
const AIR_TERMINAL_FALL: float = 30.0
## A revert pressed this many ticks before touchdown still counts (0.15 s), as well as within REVERT_WINDOW after it.
const REVERT_BUFFER_TICKS: int = 9
## Rolling over a coping into its ramp slower than this (m/s, across the coping) follows the wall down (a drop-in);
## faster, the skater flies off the coping and lands on the transition. ROLL_IN_REACH: m from the coping it applies.
const ROLL_IN_MAX_SPEED: float = 4.5
## ...and heading across it within about 75 degrees: a carve along the top of a bowl wall, under its coping, is not a roll-in
## (holding the board to the wall there snagged it).
const ROLL_IN_HEADING_DOT: float = 0.25
const ROLL_IN_REACH: float = 0.8
const ROLL_IN_END_SLACK: float = 0.1  ## m past the end of a coping segment still counted as rolling over it
const ROLL_IN_NORMAL_DOT: float = 0.85  ## the bending floor's horizontal part must point this much along the lip's inward
## Landing speed loss: a clean landing keeps LAND_KEEP_MAX of the along-surface speed; past LAND_KEEP_FREE m/s of
## impact into the surface (a drop of about 0.5 m) a harder landing scrubs LAND_KEEP_PER_MS more per m/s, down to
## LAND_KEEP_MIN. Clean vert re-entries keep everything.
const LAND_KEEP_MAX: float = 0.97
const LAND_KEEP_MIN: float = 0.95
const LAND_KEEP_FREE: float = 4.0
const LAND_KEEP_PER_MS: float = 0.004
## Rolling off an edge (no ollie): the board's nose follows this share of the fall's angle, at most
## ROLL_OFF_PITCH_MAX degrees, and levels out over the last ROLL_OFF_LEVEL_TIME s; ROLL_OFF_TURN is its follow rate, 1/s.
const ROLL_OFF_PITCH_SHARE: float = 0.4
const ROLL_OFF_PITCH_MAX: float = 20.0
const ROLL_OFF_LEVEL_TIME: float = 0.3
const ROLL_OFF_TURN: float = 8.0
## The floor snap may pull the body this far (m) below the old floor's plane in a tick before it counts as rolling off
## a ledge (a curb's worth and less is still rolled down).
const LEDGE_SNAP_MAX: float = 0.1
const BOARD_TURN_MIN_DEG: float = 4.0  ## see the board_up follow in _ground_move
const BOARD_TURN_PER_MS: float = 0.5
const CURV_LEN: float = 0.6  ## m of travel the floor curvature estimate averages over
const GRIP_LIMIT_NY: float = 0.5  ## faces steeper than this (normal y) limit sideways grip to friction on the press
const WALL_GRIP_MU: float = 2.8  ## grip per unit press (generous: the full side_grip at a 0.5 g press)
const PEEL_NY: float = 0.3  ## faces steeper than this can be peeled off with no press holding the board on
const PEEL_CONCAVE: float = 0.02  ## 1/m: a recent path at least this concave never peels off (a stall on vert)
const ROLL_IN_HOLD_TICKS: int = 20
const WALL_ROLL_CURV: float = 0.3  ## 1/m assumed when set onto a ramp wall by a snap (a 3 m transition)
const PEEL_PRESS: float = 0.02  ## press below this share of gravity on such a face: the board comes away
const GROUND_FLOOR_MAX_DEG: float = 80.0  ## floor_max_angle while riding (relative to the current floor's normal)
const BODY_RADIUS: float = 0.3  ## the collision sphere (its centre sits this far above the origin)
## Time (s) the visual takes to catch up after a rail or lip snap (the body snaps at once; see _update_visual).
const POP_SLACK: float = 0.15  ## m a ground tick may move the body past speed * dt (snap round a bend, a curb step)
const DEPEN_REACH: float = 0.8  ## m: how close a face seen from behind must be to count as being inside a solid
const DEPEN_CONFIRM: float = 3.0  ## m: the opposite side of a solid the body seems buried in must lie this close
const DEPEN_MAX_STEP: float = 0.25  ## m a tick the push out of a solid may move the body
const SNAP_YAW_MAX_DEG: float = 5.5  ## the snap's turn never runs faster than this per tick (60 Hz)
const SNAP_YAW_PEAK: float = 1.25  ## the turn profile's peak rate over its average (eased ends)
const SNAP_ARC_STRETCH_MAX: float = 0.75  ## s: longest a snap hop may be stretched for its turn
const SNAP_EASE_TIME: float = 0.1

## Live physics tuning. Every ride number is read from here each tick.
var tune: PhysicsTuning = PhysicsTuning.shared()
## Per-tick debug frame (same dictionary the physics_ticked signal carries).
var debug: Dictionary = {}
## Events raised this tick: "ollie", "air", "land:<result>", "bail", "grind", "grind_end", "manual", "lip",
## "wallride", "leave_edge", "overhang_drop", "speed_restore", "respawn", "dismount", "mount", "ramp_snap:<mode>",
## "ramp_snap_release", "ramp_snap_miss".
var events: Array[String] = []

var db: TrickDB
var state := SkateState.new()
var tricks := TrickInput.new()
var combo := Combo.new()
var special := SpecialMeter.new()
var balance := Balance.new()
var gaps: Gaps
var spin := SpinTracker.new()
var walker := Walker.new()  ## on-foot movement while state is WALK (the poser reads phase and speed from it)
var chord := ChordInput.new()  ## spin_left + spin_right together: the ramp snap

## Read by the poser, camera and HUD.
var anim: String = "idle_ride"
var ragdoll_active: bool = false  ## true while a bail ragdoll drives the body (the poser stands aside)
var anim_trick: Dictionary = {}
var anim_time: float = 0.0
var crouch: float = 0.0  ## 0..1
var switch_stance: bool = false
var balance_kind: String = ""  ## "", "grind", "manual", "lip"
var facing: Vector3 = Vector3.FORWARD  ## horizontal-ish travel direction on the current surface
var board_up: Vector3 = Vector3.UP
var speed: float = 0.0
var vert_air: bool = false
## 0..1: how hard the last landing hit (speed into the surface over 12 m/s). For the poser's knee absorb.
var land_impact: float = 0.0
## Seconds the chase camera holds its place and just watches (a ramp snap's drop-in: the camera stays up over the coping
## while the skater drops down the wall, instead of swinging round into the ramp).
var camera_hold: float = 0.0
var camera_anchor: Vector3 = Vector3.ZERO  ## where the camera waits while camera_hold runs: up behind the coping
var _ragdoll: SkaterRagdoll = null
var _bail_ctx: Dictionary = {}  ## what caused the current bail (BailKind context), read when the ragdoll starts
var _getup_left: float = 0.0

var _t: float = 0.0
var _seed: int = 1
var _floor_normal: Vector3 = Vector3.UP
var _crouch_time: float = 0.0
var _air_trick_until: float = 0.0  ## a flip is still rotating until this time
var _grab_trick: Dictionary = {}
var _rail: GrindRail
var _rail_seg: int = 0
var _rail_t: float = 0.0
var _rail_speed: float = 0.0
var _hold_pps: int = 0
var _wall_normal: Vector3 = Vector3.ZERO
var _launch_normal: Vector3 = Vector3.UP
var _spawn: Transform3D
var _just_pressed: Array = []
var _held: Array = []
var _stick: Vector2 = Vector2.ZERO
var _recent_grind_press: int = 100  ## ticks since grind was pressed (buffered for rails and walls)
var _visual: Node3D
var _pending_air: Array = []
var _snap_offset: Vector3 = Vector3.ZERO  ## visual-only catch-up after a rail or lip snap
var _left_rail: GrindRail
var _left_rail_t: float = -10.0
var _left_edge: bool = false
var _tick_count: int = 0
var _in_tick: bool = false
var _carry_events: Array[String] = []  ## raised between ticks (an outside respawn()), shown on the next frame
var _d_pumping: bool = false
var _d_pushing: bool = false
var _d_braking: bool = false
var _d_pulse: float = 0.0
var _transition_ticks: int = 0  ## consecutive ground ticks on a face with normal y < 0.9 (a real transition)
var _topple_side: float = 0.0  ## +1 / -1 while hopping off a toppled grind (right / left of travel), else 0
var _carve_side: float = 0.0  ## side of the carve after a topple landing
var _carve_left: float = 0.0  ## seconds of topple carve left
var _since_bend: float = 1.0  ## seconds since the floor normal last bent by over a degree (curving transition)
var _touch_wall_n: Vector3 = Vector3.ZERO  ## the upright wall rolled along last tick (steering can't turn into it)
var _recent_revert_press: int = 100  ## ticks since revert was pressed (buffered across the touchdown)
## The ramp snap in progress (see _tick_snap), {} when none. Plain Variants, so it snapshots.
var _snap: Dictionary = {}
var _snap_hold_up: Vector3 = Vector3.ZERO  ## dropping in after a snap: the wall normal the board holds until it lands
var _roll_off: bool = false  ## airborne by rolling off an edge (no ollie): the nose follows the fall a little
var _roll_in_dir: Vector3 = Vector3.ZERO  ## inward (down the ramp) of the coping last rolled in over
var _roll_in_hold: int = 0  ## ground ticks left in which a roll-in's coping bend does not count as convex
var _curv: float = 0.0  ## signed floor curvature along the path, 1/m (see _update_curvature)
var _lone_spin: float = 0.0  ## rad the shoulder buttons spun since both were last up (undone if they make a chord)


func _ready() -> void:
	db = TrickDB.load_default()
	gaps = Gaps.load_default()
	_seed = Flags.seed_value()
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(GROUND_FLOOR_MAX_DEG)
	floor_snap_length = 0.6
	floor_constant_speed = false
	floor_stop_on_slope = false
	floor_block_on_wall = false
	max_slides = 4
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	cs.shape = sphere
	cs.position = Vector3(0, 0.3, 0)
	add_child(cs)
	_visual = get_node_or_null("Visual")
	if _visual == null:
		_visual = Node3D.new()
		_visual.name = "Visual"
		add_child(_visual)
	_spawn = global_transform
	facing = -global_transform.basis.z
	state.combo_landed.connect(_on_combo_landed)
	state.combo_bailed.connect(_on_combo_bailed)
	state.state_changed.connect(_on_state_changed)
	gaps.gap_completed.connect(_on_gap)
	Flags.register_hash(_state_hash)
	for z: Node in get_tree().get_nodes_in_group("gap_zone"):
		_connect_zone(z as Area3D)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Area3D and n.is_in_group("gap_zone"):
		_connect_zone(n as Area3D)


func _connect_zone(a: Area3D) -> void:
	if a == null or a.body_entered.is_connected(_on_zone_entered):
		return
	a.body_entered.connect(_on_zone_entered.bind(a))


## Overridable input source, so scripted runs and tests can drive the skater.
func read_input() -> void:
	_stick = Controls.move_vector()
	_just_pressed.clear()
	_held.clear()
	for b: String in ["ollie", "flip", "grab", "grind", "spin_left", "spin_right", "revert", "nollie", "dismount"]:
		if Input.is_action_just_pressed(b):
			_just_pressed.append(b)
			Flags.commands += 1
		if Input.is_action_pressed(b):
			_held.append(b)


## Scripted input for one tick (captures and tests).
func set_input(stick: Vector2, just_pressed: Array, held: Array) -> void:
	_stick = stick
	_just_pressed = just_pressed.duplicate()
	_held = held.duplicate()


var scripted_input: bool = false


func _physics_process(delta: float) -> void:
	_tick_count += 1
	events = _carry_events
	_carry_events = []
	_d_pumping = false
	_d_pushing = false
	_d_braking = false
	_d_pulse = 0.0
	_in_tick = true
	_step(delta)
	_in_tick = false
	_publish()


func _step(delta: float) -> void:
	_t += delta
	if not scripted_input:
		read_input()
	if Input.is_action_just_pressed("restart"):
		respawn()
		return
	if global_position.y < tune.kill_y:
		respawn()
		return
	if _snap.is_empty() and not is_on_floor() and state.state in [SkateState.State.AIR, SkateState.State.ROLLING, SkateState.State.MANUAL]:
		_depenetrate()
	var snap_fired: bool = chord.feed(_just_pressed, _held)
	if chord.suppressing():
		# the buttons of a fired chord do not also spin
		_held = _held.filter(func(b: Variant) -> bool: return b != "spin_left" and b != "spin_right")
		_just_pressed = _just_pressed.filter(func(b: Variant) -> bool: return b != "spin_left" and b != "spin_right")
	var requests: Array = tricks.feed(_stick, _just_pressed, _held)
	_recent_grind_press = 0 if _just_pressed.has("grind") else _recent_grind_press + 1
	_recent_revert_press = 0 if _just_pressed.has("revert") else mini(_recent_revert_press + 1, 100)
	anim_time += delta
	camera_hold = maxf(camera_hold - delta, 0.0)
	if state.state == SkateState.State.ROLLING and _floor_normal.y > 0.95 and _snap.is_empty():
		camera_hold = 0.0  # down on the flat: the chase camera takes over again
	state.tick(delta)
	if state.state != SkateState.State.WALK:
		special.tick(delta, combo.is_active())  # the meter holds while on foot
	if not _snap.is_empty():
		_tick_snap(delta)
		_finish_step(delta)
		return
	if snap_fired:
		_undo_lone_spin()
		if _try_ramp_snap():
			_finish_step(delta)
			return
	if _just_pressed.has("dismount") and state.state == SkateState.State.ROLLING:
		_try_dismount()
	match state.state:
		SkateState.State.WALK:
			_tick_walk(delta)
		SkateState.State.ROLLING:
			_tick_rolling(delta, requests)
		SkateState.State.MANUAL:
			_tick_manual(delta)
		SkateState.State.AIR:
			_tick_air(delta, requests)
		SkateState.State.GRIND:
			_tick_grind(delta)
		SkateState.State.LIP:
			_tick_lip(delta, requests)
		SkateState.State.WALLRIDE:
			_tick_wallride(delta)
		SkateState.State.BAIL:
			_tick_bail(delta)
	_finish_step(delta)


func _finish_step(delta: float) -> void:
	speed = velocity.length()
	_update_visual(delta)
	combo_changed.emit(combo.display_text(), combo.base_sum(), combo.multiplier())


# --- ground -------------------------------------------------------------------------------------------

func _tick_rolling(delta: float, requests: Array) -> void:
	_ground_move(delta, true)
	if not is_on_floor() or _left_edge:
		_go_airborne(false)
		return
	if anim == "drop_in" and _floor_normal.y > 0.97:
		# down the wall and onto the flat: the knees take the bottom of the transition
		land_impact = clampf(speed / 14.0, 0.2, 0.8)
		_set_anim("land")
	# Revert: pressed just after touchdown, or a moment before it (buffered, as THUG players hit it on the way down).
	if _recent_revert_press <= REVERT_BUFFER_TICKS and state.event("revert"):
		_recent_revert_press = 100
		switch_stance = not switch_stance
		_score_trick({"id": "revert", "name": "Revert", "points": 100, "kind": "revert", "anim": "revert"})
		_set_anim("revert")
		return
	var seq: Array = tricks.manual_tap_sequence()
	if seq.size() == 2 and speed > 1.0:
		var m: Dictionary = db.find_sequence(seq, "")
		if not m.is_empty() and state.event("manual_start"):
			tricks.clear()
			_start_balance_trick(m, "manual")
			return
	if _recent_grind_press < 8 and _try_grind():
		return
	# flips and grabs need air: keep presses from the last few ticks so ollie + flip together works
	for r: Dictionary in requests:
		if r["button"] != "grind":
			_pending_air.append({"req": r, "t": _t})
	_pending_air = _pending_air.filter(func(p: Dictionary) -> bool: return _t - float(p["t"]) < 0.2)
	# Ollie tapped just before touchdown and already released: pop now (a THUG-style jump buffer).
	if _crouch_time == 0.0 and not _held.has("ollie") and state.time_in_state < 0.05 \
			and tricks.pressed_within("ollie", TrickInput.OLLIE_LAND_BUFFER_TICKS):
		tricks.consume("ollie")
		_ollie(tune.ollie_min)
		return
	_handle_ollie(delta)


func _handle_ollie(delta: float) -> void:
	if _held.has("ollie"):
		_crouch_time += delta
		crouch = clampf(_crouch_time / tune.crouch_full, 0.0, 1.0)
	elif _crouch_time > 0.0:
		var power: float = lerpf(tune.ollie_min, tune.ollie_max, crouch)
		_crouch_time = 0.0
		crouch = 0.0
		_ollie(power)


func _ollie(power: float) -> void:
	# Pop straight up off anything you can stand on: popping along a kicker's normal would brake you.
	var up: Vector3 = Vector3.UP
	if state.state != SkateState.State.GRIND and _floor_normal.y < 0.8:
		up = (_floor_normal + Vector3.UP).normalized()  # on a steep transition, pop out of the ramp too
	velocity += up * power
	if state.state != SkateState.State.GRIND:
		position += up * 0.05
	if state.event("ollie"):
		_ev("ollie")
		_set_anim("ollie")
		_enter_air(false)


## Buried in solid geometry (spawned or put back inside a closed mesh, whose faces only collide from outside, so the
## body would fall through it at terminal speed): find the shortest way out, a nearby face seen from behind along one of
## the six axes, and push out along it by at most DEPEN_MAX_STEP a tick, stopping the motion into the solid. Ordinary
## physics takes over once out.
func _depenetrate() -> void:
	if not is_inside_tree():
		return
	var c: Vector3 = global_position + Vector3.UP * BODY_RADIUS
	var best_d: float = INF
	var best_dir: Vector3 = Vector3.ZERO
	for axis: Vector3 in [Vector3.UP, Vector3.RIGHT, Vector3.BACK]:
		# Inside a solid along this axis only with its faces on both sides seen from behind (one side alone is just a
		# face nearby, or a mesh with a stray or flipped face).
		var a: float = _behind_face(c, axis, DEPEN_REACH)
		var b: float = _behind_face(c, -axis, DEPEN_REACH)
		if a < 0.0 and b < 0.0:
			continue
		if a < 0.0:
			a = _behind_face(c, axis, DEPEN_CONFIRM)
		elif b < 0.0:
			b = _behind_face(c, -axis, DEPEN_CONFIRM)
		if a < 0.0 or b < 0.0:
			continue
		if a < best_d:
			best_d = a
			best_dir = axis
		if b < best_d:
			best_d = b
			best_dir = -axis
	if best_dir == Vector3.ZERO:
		return
	global_position += best_dir * minf(best_d + BODY_RADIUS + 0.01, DEPEN_MAX_STEP)
	velocity -= best_dir * minf(velocity.dot(best_dir), 0.0)
	_ev("depenetrate")


## Distance from `c` along `dir` to a face that `c` lies behind (the face's outside looks along `dir`, away from `c`, with
## no other face between), within `reach`; -1 when there is none. Found by casting back toward `c` from `reach` out:
## faces only collide from their outside, so a ray from inside a mesh sees nothing.
func _behind_face(c: Vector3, dir: Vector3, reach: float) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(c + dir * reach, c, collision_mask, [get_rid()])
	q.hit_back_faces = false
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).dot(dir) < 0.5:
		return -1.0
	var d: float = c.distance_to(hit["position"] as Vector3)
	var out := PhysicsRayQueryParameters3D.create(c, c + dir * d, collision_mask, [get_rid()])
	out.hit_back_faces = false
	if not space.intersect_ray(out).is_empty():
		return -1.0  # a near face first: `c` is outside a thin wall and that face is its far side
	return d


func _ev(name: String) -> void:
	if _in_tick:
		events.append(name)
	else:
		_carry_events.append(name)


func _publish() -> void:
	var rail_name: String = ""
	if _rail != null and is_instance_valid(_rail):
		rail_name = String(_rail.name)
	var pressed: Array[String] = []
	for b: Variant in _just_pressed:
		pressed.append(str(b))
	var held: Array[String] = []
	for b: Variant in _held:
		held.append(str(b))
	debug = {
		"tick": _tick_count, "t": _t, "state": state.state_name(),
		"pos": global_position if is_inside_tree() else position, "vel": velocity, "speed": velocity.length(),
		"on_floor": is_on_floor(), "floor_normal": _floor_normal, "facing": facing, "board_up": board_up,
		"stick": _stick, "held": held, "pressed": pressed, "crouch": crouch, "anim": anim,
		"vert_air": vert_air, "launch_normal": _launch_normal, "wall_normal": _wall_normal,
		"pumping": _d_pumping, "pushing": _d_pushing, "push_pulse": _d_pulse, "braking": _d_braking,
		"left_edge": _left_edge, "on_wall": is_on_wall(), "rail": rail_name, "events": events,
	}
	physics_ticked.emit(debug)


func _ground_move(delta: float, allow_push: bool) -> void:
	var n: Vector3 = _floor_normal
	var v: Vector3 = velocity.slide(n)
	var in_spd: float = velocity.length()
	if in_spd > 0.5 and v.length() > 0.01 and absf(velocity.dot(n)) < 0.35 * in_spd:
		# Following a curve onto the next facet: turn the velocity onto it rather than cutting it.
		v = v.normalized() * in_spd
	# keep a facing even when stopped
	if v.length() > 0.5:
		facing = v.normalized()
	else:
		facing = facing.slide(n).normalized() if facing.slide(n).length() > 0.01 else _fallback_facing(n)
	# steering: rotate travel direction around the surface normal
	var turn_rate: float = lerpf(tune.turn_rate, tune.turn_rate_fast, clampf(v.length() / tune.max_speed, 0.0, 1.0))
	# Carving is limited by grip: the sideways pull v * turn_rate can't pass carve_grip, so at speed the radius
	# grows like v^2 / carve_grip (a wide carve), while low-speed turns stay tight.
	turn_rate = minf(turn_rate, tune.carve_grip / maxf(v.length(), 0.1))
	var stick_x: float = _stick.x
	if _carve_left > 0.0:
		# Carving out of a toppled grind: a steer toward the fall side that fades out.
		stick_x = clampf(stick_x + _carve_side * TOPPLE_CARVE_STEER * (_carve_left / TOPPLE_CARVE_TIME), -1.0, 1.0)
		_carve_left = maxf(_carve_left - delta, 0.0)
	var steer: float = -stick_x * turn_rate * delta * clampf(v.length() / 1.5, 0.25, 1.0)
	if absf(steer) > 0.0:
		var pre_facing: Vector3 = facing
		var pre_v: Vector3 = v
		facing = facing.rotated(n.normalized(), steer).normalized()
		v = facing * v.length() * (1.0 if v.dot(facing) >= 0.0 else -1.0)
		if _touch_wall_n != Vector3.ZERO and pre_v.length() > 1.5 and v.dot(_touch_wall_n) < minf(pre_v.dot(_touch_wall_n), 0.0):
			# Rolling along a wall: the stick can't steer you further into it, only along it (or away). The
			# steer is refused; the wall contact itself (the slide and _wall_response) handles the rest. Slower
			# than a jog the skater can kick-turn off the wall instead.
			facing = pre_facing
			v = pre_v
	_touch_wall_n = Vector3.ZERO
	# gravity along the slope
	v += Vector3.DOWN.slide(n) * tune.gravity * delta
	var along: float = v.dot(facing)
	if allow_push and _stick.y < -0.3 and along < tune.push_max and n.y > 0.8:
		_d_pushing = true
		if anim != "push" and crouch == 0.0:
			_set_anim("push")
		# Speed comes from the kicks: only while the push foot is on the ground (same timing as the pose).
		_d_pulse = _push_pulse()
		along = minf(along + tune.push_accel * _d_pulse * delta, tune.push_max)
	elif _stick.y < -0.3 and n.y < 0.95 and n.y > 0.15 and (v.y < 0.0 or (n.y > PUMP_UP_MIN_NY and _since_bend < PUMP_CURVE_TIME)):
		# Pumping: compress into the transition on the way down and through the lower curve, extend on the way out.
		# Steeper transitions pump harder. The gain grows with speed (as the square root: real pumping adds a share of
		# the energy you carry, so passes build, but the first pass is already a real air and the later ones level
		# off: about 2, 4.5, 6.5, 8, 9 m over a 4 m halfpipe's coping) and fades toward the speed cap.
		# Nothing is added while climbing the steep upper wall, so holding forward never parks you on a wall.
		_d_pumping = true
		var spd_now: float = v.length()
		var rate: float = clampf(sqrt(spd_now / tune.pump_speed_ref), 0.25, 2.0)
		var taper: float = clampf(1.0 - pow(spd_now / tune.max_speed, 6.0), 0.0, 1.0)
		along += lerpf(tune.pump_accel, tune.pump_accel_vert, clampf((0.95 - n.y) / 0.6, 0.0, 1.0)) * rate * taper * delta
	elif _stick.y > 0.5 and n.y > 0.8 and state.state == SkateState.State.ROLLING:
		_d_braking = true
		along = move_toward(along, 0.0, tune.brake * delta)
	along = move_toward(along, 0.0, tune.roll_friction * delta)
	var side: Vector3 = v - facing * v.dot(facing)
	# Wheels resist sliding sideways, but only as hard as they are pressed on: on a steep wall the press is the
	# centripetal pull of the curve (v^2 * curvature) plus gravity's share into the face, so a slow carve high on a bowl
	# wall slides down it instead of hanging there, while a fast one holds its line.
	side = side.move_toward(Vector3.ZERO, _side_grip(n, v.length()) * delta)
	v = facing * along + side
	if v.length() > tune.max_speed:
		v = v.normalized() * tune.max_speed
	if anim == "push" and _stick.y >= -0.3:
		_set_anim("idle_ride")
	if crouch > 0.0 and anim != "crouch":
		_set_anim("crouch")
	# Going up a steep wall: no snap and no push into the surface, so the skater leaves the lip
	# into vert air instead of wrapping over onto the deck.
	# Upside down (a loop's upper half): only centripetal force holds the board on. Too slow, and it drops off.
	if n.y < -0.2 and v.length_squared() < tune.gravity * -n.y * tune.overhang_radius:
		_left_edge = true
		_ev("overhang_drop")
		velocity = v
		_launch_normal = n
		return
	# (Not on an overhang: inside a loop the surface keeps curving over the top, so stay glued to it.)
	var climbing_vert: bool = n.y < tune.vert_normal_y and n.y > -0.2 and v.y > 0.3
	velocity = v if climbing_vert else v - n * 0.5
	up_direction = n
	floor_snap_length = 0.0 if climbing_vert else 0.6
	var pre_pos: Vector3 = global_position
	move_and_slide()
	floor_snap_length = 0.6
	_left_edge = false
	_limit_step(pre_pos, maxf(in_spd, v.length()) * delta)
	if is_on_floor():
		var fn: Vector3 = get_floor_normal()
		var was: Vector3 = _floor_normal
		if fn.dot(was) < SNAG_CHECK_DOT:
			# A big jump in the floor: is it a real face (a ramp toe, a bank) or the sphere touching an edge or vertex
			# (the end of a side wall, a ramp's side rim)? Edge contacts give blended normals no face has.
			var real: Vector3 = _real_floor_normal(was, v, fn)
			if real == Vector3.ZERO:
				_graze_edge(v, was)
				return
			fn = real
		# How far the floor snap pulled the body below the old floor's plane this tick: off a ledge or a box at speed
		# it would drag the skater straight down a 0.5 m drop in one frame and keep rolling, never airborne.
		var sank: float = (pre_pos + v * delta - global_position).dot(was)
		# Only from a surface the body was standing on: a body set down hovering (a respawn, a bot reset) just settles.
		var off_ledge: bool = sank > LEDGE_SNAP_MAX and v.length() > 0.5 and fn.dot(was) > 0.9 \
			and test_move(Transform3D(global_transform.basis, pre_pos), -was * LEDGE_SNAP_MAX)
		if (off_ledge or _leaves_surface(was, fn, v, delta)) and not (_roll_in_holds(fn) and not off_ledge) \
				and not _rolls_in(was, fn, v):
			# Over a lip (kicker top, ledge edge, funbox crest at speed): the surface falls away faster than
			# gravity can hold the board to it, so carry on along the old surface into the air, from where the old
			# surface would have put the body (not wrapped down round the edge by the snap: no pop at the lip).
			_left_edge = true
			_ev("leave_edge")
			velocity = v
			_launch_normal = was
			var carry: Transform3D = Transform3D(global_transform.basis, pre_pos)
			if sank > 0.005 and not test_move(carry, v * delta):
				global_position = pre_pos + v * delta
			return
		var block: Array = _blocking_contact(v, fn) if fn.y > 0.7 else []
		if not block.is_empty() and absf((block[0] as Vector3).y) < 0.3:
			_touch_wall_n = (block[0] as Vector3).slide(fn).normalized()
		if not block.is_empty() and _wall_response(v, block[0], fn, false, block[1]):
			return
		var spd: float = v.length()
		var grazing: bool = not is_on_wall() or absf(get_wall_normal().dot(v / maxf(spd, 0.001))) < 0.3
		if spd > 0.5 and fn.dot(was) > 0.8 and grazing and velocity.length() < spd:
			# Riding a curved (faceted) ramp, transition or loop, or brushing along a curb: keep the speed the
			# slope physics gave, so facet corners and glancing side contacts don't eat it.
			_ev("speed_restore")
			var keep_dir: Vector3 = velocity.slide(fn)
			if keep_dir.length() < 0.1 * spd:
				# Pinched to a stop in a crease (a slope's side edge meeting a ledge and a wall): carry on along the
				# floor and any upright wall touched instead of losing the whole speed in one tick.
				keep_dir = _crease_dir(v, fn)
			if keep_dir.length() >= 0.1 * spd:
				velocity = keep_dir.normalized() * spd
			# else: wedged into an inside corner with no way along either wall: the speed is lost to it.
		_update_curvature(was, fn, v, global_position.distance_to(pre_pos))
		if _ground_below(fn):
			return
		if _peels_off(fn):
			# Riding a steep face nothing presses the wheels onto (a raised ramp's flat side, a wall reached over a
			# convex edge, too slow for the curve to hold it): the board comes away and the rider falls beside it.
			_left_edge = true
			_ev("wall_peel")
			_launch_normal = fn
			return
		_since_bend = 0.0 if fn.dot(was) < 0.99985 else _since_bend + delta
		_floor_normal = fn
		_transition_ticks = _transition_ticks + 1 if fn.y < 0.9 else 0
		if was.y < tune.vert_normal_y and velocity.dot(Vector3.UP) > 0.0:
			_launch_normal = was
		elif fn.y >= tune.vert_normal_y:
			_launch_normal = Vector3.UP
		# The board follows the floor quickly, but at a slow roll over a sharp bend (a coping, a roll-in's edge) no
		# faster than BOARD_TURN_MIN_DEG + BOARD_TURN_PER_MS * speed degrees a tick: the nose drops onto the wall over a
		# few frames instead of snapping. Fast riding round a tight curve is never limited below what it needs.
		var w: float = clampf(delta * 20.0, 0.0, 1.0)
		var ang: float = board_up.angle_to(fn)
		var cap: float = deg_to_rad(BOARD_TURN_MIN_DEG + BOARD_TURN_PER_MS * velocity.length()) * delta * 60.0
		if ang * w > cap and ang > 0.0001:
			w = cap / ang
		board_up = _turn_toward(board_up, fn, w)
	else:
		# leaving a surface: was it the top of a vert ramp?
		_launch_normal = _floor_normal


## Still committed to a roll-in on the floor `fn`: within ROLL_IN_HOLD_TICKS of rolling over a coping, with the floor
## still tipping toward the ramp (a normal swinging round sideways is the ramp's side edge, not its wall).
func _roll_in_holds(fn: Vector3) -> bool:
	if _roll_in_hold <= 0:
		return false
	var fn_h: Vector2 = Vector2(fn.x, fn.z)
	return fn_h.length() < 0.05 or fn_h.normalized().dot(Vector2(_roll_in_dir.x, _roll_in_dir.z).normalized()) >= ROLL_IN_NORMAL_DOT


## No position pops: the slide's floor snap and overlap recovery may not carry the body further in one tick than its
## speed allows plus POP_SLACK (a curb step, the snap round a bend). A bigger jump (the snap dragging the body down a
## wall face it scraped, or out through a corner) is cut back along the way it went, where the body fits.
func _limit_step(pre_pos: Vector3, allowed: float) -> void:
	var moved: Vector3 = global_position - pre_pos
	var lim: float = allowed + POP_SLACK
	if moved.length() <= lim:
		return
	var to: Vector3 = pre_pos + moved.normalized() * lim
	if test_move(Transform3D(global_transform.basis, pre_pos), to - pre_pos):
		return  # the shorter step would end inside something: keep the slide's own result
	global_position = to
	_ev("pop_limited")


## Normal press per unit mass on the floor `n` at speed `spd` (m/s^2): the centripetal pull the path's recent
## curvature needs (_curv: concave positive) plus gravity's part into the face. g on the flat.
func _wall_press(n: Vector3, spd: float) -> float:
	return spd * spd * _curv + tune.gravity * n.y


## Sideways grip on floor `n`: the full side_grip on anything flatter than GRIP_LIMIT_NY; on a steeper face no more
## than WALL_GRIP_MU times the press (friction), so a slow carve on a near-vertical bowl wall slides down it.
func _side_grip(n: Vector3, spd: float) -> float:
	if n.y >= GRIP_LIMIT_NY:
		return tune.side_grip
	return clampf(WALL_GRIP_MU * _wall_press(n, spd), 0.0, tune.side_grip)


## Exponential average over the last CURV_LEN metres of how fast the floor normal turns per metre of travel,
## signed: positive when concave (into a transition, round a bowl wall), negative when convex (over a coping or edge).
func _update_curvature(was: Vector3, fn: Vector3, v: Vector3, moved: float) -> void:
	var spd: float = v.length()
	if spd < 0.05:
		return
	var bend: float = -(fn - was).dot(v / spd)
	if _roll_in_holds(fn):
		_roll_in_hold -= 1
		bend = maxf(bend, 0.0)
	else:
		_roll_in_hold = 0  # rolling in over a coping: its convex curve is the way onto the wall, not off it
	var a: float = clampf(moved / CURV_LEN, 0.0, 1.0)
	_curv = _curv * (1.0 - a) + bend / CURV_LEN


## On a steep face with a real floor under the wheels this tick (the ground at the foot of a vertical face that was
## being slid down): stand on that floor instead. True when it took over.
func _ground_below(fn: Vector3) -> bool:
	if fn.y >= PEEL_NY:
		return false
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		var cn: Vector3 = c.get_normal()
		if cn.y >= LAND_EDGE_MIN_NY and _is_face_contact(c.get_position(), cn):
			_floor_normal = cn
			up_direction = cn
			velocity = velocity - cn * minf(velocity.dot(cn), 0.0)
			_curv = 0.0
			_ev("ground_below")
			return true
	return false


## True when the face `fn` is too steep to ride with no press holding the wheels on (see _wall_press): only a face
## steeper than PEEL_NY, not climbing it (a climb is judged by the vert launch), with the recent path not concave
## enough to hold the board on (a flat vertical side, or one reached over a convex edge).
func _peels_off(fn: Vector3) -> bool:
	if fn.y >= PEEL_NY or fn.y < -0.2 or velocity.y > 0.3 or _curv > PEEL_CONCAVE:
		return false  # a concave curve behind (a transition's vert top, a bowl wall) keeps the board on it
	return _wall_press(fn, velocity.length()) < PEEL_PRESS * tune.gravity


## The floor normal from this tick's contacts that lie on a real face, averaged, or ZERO when every floor contact
## that bends more than SNAG_CHECK_DOT away from `was` is an edge or vertex touch. A sphere touching an edge gets
## a normal pointing from the edge to its centre, a blend no face of the mesh has: a ray along that normal hits a
## face whose own normal differs. Contacts close to `was` are kept unchecked (facets of a curve).
func _real_floor_normal(was: Vector3, v: Vector3, snap_n: Vector3) -> Vector3:
	var cands: Array = []
	var cos_max: float = cos(floor_max_angle) - 0.01
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		for j: int in c.get_collision_count():
			if c.get_normal(j).dot(up_direction) >= cos_max:
				cands.append([c.get_normal(j), c.get_position(j)])
	if cands.is_empty():
		# Held down by the floor snap alone (no slide contact): judge the snapped normal at the sphere's base.
		cands.append([snap_n, global_position + up_direction * 0.3 - snap_n * 0.3])
	var sum: Vector3 = Vector3.ZERO
	for cand: Array in cands:
		var n: Vector3 = cand[0]
		if (n - was).dot(v) > 0.0:
			sum += n  # convex (over a crest or a lip): _leaves_surface judges it, the floor bends away from us
			continue
		if n.dot(was) < FLOOR_JUMP_DOT and n.y < 0.5:
			continue  # too far round in one tick to be the next stretch of floor: a wall met from a slope
		if n.dot(was) < SNAG_CHECK_DOT and not _is_face_contact(cand[1], n):
			continue
		sum += n
	return sum.normalized() if sum.length() > 0.001 else Vector3.ZERO


## True when the contact at `p` with normal `n` lies on a face with that normal (not an edge or vertex blend).
func _is_face_contact(p: Vector3, n: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters3D.create(p + n * 0.12, p - n * 0.12, collision_mask, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	return (hit["normal"] as Vector3).dot(n) > 0.985


## The only floor contacts this tick were edges or walls (a wall end, a ramp's side rim, a vertical face that
## counts as floor only because we are on a slope): ride on along the old floor. An edge no higher than a wheel
## (a ramp toe's side rim) is rolled over at full speed; a taller one is hit like a wall.
func _graze_edge(v: Vector3, was: Vector3) -> void:
	_ev("edge_graze")
	var hit_n: Vector3 = Vector3.ZERO
	var hit_h: float = 0.0
	var hit_p: Vector3 = global_position
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		if c.get_normal().dot(was) < SNAG_CHECK_DOT:
			hit_n = c.get_normal()
			hit_h = (c.get_position() - global_position).dot(was)
			hit_p = c.get_position()
	_floor_normal = was
	up_direction = was
	velocity = v
	if hit_h > EDGE_STEP_HEIGHT:
		_wall_response(v, hit_n, was, true, hit_p)


## Share of speed kept when glancing off a wall at `square` (0 = parallel, 1 = head-on): a THUG-style deflection
## that turns you along the wall, not a stop.
## Arcade-forgiving: a brush under about 25 degrees costs nothing, 40 degrees about 3-4%, 60 degrees about 6%. Only
## nearly square-on hits tend to the real share, the part of the velocity along the wall.
static func _deflect_keep(square: float) -> float:
	var arcade: float = 1.0 - 0.07 * smoothstep(0.42, 0.9, square)
	var real: float = sqrt(maxf(1.0 - square * square, 0.0))
	return lerpf(arcade, real, smoothstep(0.85, 0.98, square))


## The travel `v` turned onto the floor `fn` and slid along every upright wall it presses into this tick.
func _crease_dir(v: Vector3, fn: Vector3) -> Vector3:
	var d: Vector3 = v.slide(fn)
	for i: int in get_slide_collision_count():
		var cn: Vector3 = get_slide_collision(i).get_normal()
		if absf(cn.y) < 0.3 and d.dot(cn) < 0.0:
			d = d.slide(cn.slide(fn).normalized())
	return d


## The wall (or overhang) contact most against the travel this tick, as [normal, point], or [] when none.
func _blocking_contact(v: Vector3, n: Vector3) -> Array:
	var best: Array = []
	var best_d: float = 0.0
	var cos_max: float = cos(floor_max_angle) - 0.01
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		var cn: Vector3 = c.get_normal()
		if cn.dot(up_direction) >= cos_max:
			continue  # floor
		var d: float = -v.dot(cn.slide(n))
		if d > best_d:
			best_d = d
			best = [cn, c.get_position()]
	if best.is_empty() and is_on_wall() and -v.dot(get_wall_normal().slide(n)) > 0.0:
		# The wall contact can fall out of the slide list when the floor contacts use up max_slides.
		var wn: Vector3 = get_wall_normal()
		best = [wn, global_position + up_direction * 0.3 - wn * 0.3]
	return best


## Rolling into a wall with normal `wn` (any contact normal; only its part along the floor `n` counts).
## Glancing: turn along the wall keeping most of the speed. Square-on: bounce back a quarter of the speed into it
## and stumble; bail when the head-on speed is too high to ride out. `force` sets the deflected velocity even when
## the slide kept more. Returns true after a bail.
func _wall_response(v: Vector3, wn: Vector3, n: Vector3, force: bool, p: Vector3) -> bool:
	var spd: float = v.length()
	var w: Vector3 = wn.slide(n)
	if spd < 0.5 or w.length() < 0.2:
		return false
	w = w.normalized()
	var dir: Vector3 = v / spd
	var square: float = -dir.dot(w)
	if square <= 0.05:
		return false
	var into: float = spd * square
	# Clipping a corner (an edge or vertex contact, not a face) glances off around it however square the
	# sphere's contact normal looks: only a flat face met square-on stops you.
	var face: bool = square >= WALL_HEAD_ON and _is_face_contact(p, wn)
	if not face:
		var keep: float = spd * _deflect_keep(square)
		# The slide can leave the velocity aimed into the wall (it keeps the motion on the floor plane and may not
		# trim it when the contact sits beside the body), so a velocity still pressing in counts as not deflected.
		if force or velocity.length() < keep or velocity.dot(w) < -0.05 * spd:
			var along: Vector3 = (dir - w * dir.dot(w)).slide(n)
			if along.length() < 0.05:
				along = n.cross(w)  # dead centre on a corner: pick a side
			var free: Vector3 = _crease_dir(along, n)
			if free.length() < 0.25 * along.length():
				# Into an inside corner: the way along this wall runs into another one, so nothing is kept.
				velocity = Vector3.ZERO
			else:
				velocity = free.normalized() * keep
		return false
	if wn.normalized().y > 0.3 or n.y < 0.7:
		return false  # only an upright wall or an overhang met from flat-ish ground stops you; a slope just slides
	_wall_normal = w
	var bounce: float = lerpf(WALL_BOUNCE_SLOW, WALL_BOUNCE_FAST, clampf(into / WALL_BAIL_SPEED, 0.0, 1.0))
	if into > WALL_BAIL_SPEED and square >= WALL_BAIL_SQUARE:
		velocity = w * into * bounce
		_ev("wall_slam")
		_bail({"cause": "wall", "impact": into})  # the ragdoll takes the bounce; the body itself drops at the wall
		velocity = Vector3.ZERO
		return true
	velocity = ((v - w * v.dot(w)) * 0.7 + w * into * bounce).slide(n)
	_ev("stumble")
	_set_anim("land")
	return false


## True when following the floor from normal `was` to `fn` this tick would need more grip than gravity gives:
## a convex bend (the normal tips toward the travel direction) whose curvature at this speed wants a
## centripetal pull over the edge_grip tuning times gravity's, or riding down onto a near-vertical face.
func _leaves_surface(was: Vector3, fn: Vector3, v: Vector3, delta: float) -> bool:
	var spd: float = v.length()
	if spd < 0.5:
		return false
	var dir: Vector3 = v / spd
	if (fn - was).dot(dir) <= 0.0:
		return false  # concave (into a ramp) or flat: stay on it
	if fn.y < 0.1 and v.y <= 0.0:
		return true  # rolling off onto a vertical face is a fall, not a ride
	var bend: float = acos(clampf(fn.dot(was), -1.0, 1.0))
	if bend < 0.01:
		return false
	var curvature: float = bend / maxf(spd * delta, 0.001)
	return spd * spd * curvature > tune.edge_grip * tune.gravity * maxf(was.y, 0.1)


## Rolling slowly over a coping into its ramp (a natural drop-in off the deck): the front wheels drop onto the wall
## and the board follows the transition down, instead of flying off the coping's vertical top and falling onto the
## curve below (or off a start deck's edge onto its roll-in slope). Only next to a RampLip, crossing it inward, slower
## than ROLL_IN_MAX_SPEED: faster than that
## the skater really does fly out over the transition (an air drop-in), and a ledge or deck edge with no ramp under
## it is always a real drop-off. Heading across the coping (ROLL_IN_HEADING_DOT), not carving along it.
func _rolls_in(was: Vector3, fn: Vector3, v: Vector3) -> bool:
	if fn.y < -0.05 or v.y > 0.5 or not is_inside_tree():
		return false
	var hv: Vector3 = Vector3(v.x, 0.0, v.z)
	for seg: Dictionary in _lip_segments():
		var c: Array = RampSnap.closest_on_segment(global_position, seg["a"], seg["b"])
		var lip: Vector3 = c[0]
		var off: Vector3 = global_position - lip
		var inward: Vector3 = seg["inward"]
		if absf(off.y) > 0.6 or Vector2(off.x, off.z).length() > ROLL_IN_REACH:
			continue
		# Alongside the coping, not past its end: off the end of a lip the edge being rolled over is the ramp's side
		# (a bank's or a quarter's raised side face), which is a drop-off, never a roll-in.
		var along_seg: Vector3 = (seg["b"] as Vector3) - (seg["a"] as Vector3)
		along_seg.y = 0.0
		if along_seg.length() > 0.01 and absf(off.dot(along_seg.normalized())) > ROLL_IN_END_SLACK:
			continue
		# The floor tips toward the ramp (down the wall below the coping), not sideways off a side edge.
		var fn_h: Vector2 = Vector2(fn.x, fn.z)
		if fn_h.length() > 0.05 and fn_h.normalized().dot(Vector2(inward.x, inward.z).normalized()) < ROLL_IN_NORMAL_DOT:
			continue
		var into: float = hv.dot(inward)
		if into > 0.0 and into < ROLL_IN_MAX_SPEED and into >= hv.length() * ROLL_IN_HEADING_DOT:
			_ev("roll_in")
			# Committed to the drop-in: the wheels stay on the wall below the coping (its transition is ahead), the
			# coping's own convex curve does not count against the grip.
			_curv = maxf(_curv, WALL_ROLL_CURV)
			_roll_in_hold = ROLL_IN_HOLD_TICKS
			_roll_in_dir = inward
			if camera_hold <= 0.0:
				camera_anchor = RampSnap.camera_perch(lip, inward)
				camera_hold = RampSnap.CAMERA_HOLD
			return true
	return false


## 0..1 push strength this tick, from the push anim's time: 0 while stepping off and swinging the foot forward,
## a burst while the foot sweeps the ground. Averages to 1 over a cycle.
func _push_pulse() -> float:
	if anim != "push" or anim_time < tune.push_plant:
		return 0.3
	var u: float = fposmod(anim_time - tune.push_plant, tune.push_cycle) / tune.push_cycle
	return 1.0 / tune.push_contact if u < tune.push_contact else 0.0


func _fallback_facing(n: Vector3) -> Vector3:
	var f: Vector3 = (-global_transform.basis.z).slide(n)
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func _tick_manual(delta: float) -> void:
	_ground_move(delta, false)
	combo.add_hold_points(_hold_pps, delta)
	if not balance.update(delta, -_stick.y):
		_bail({"cause": "manual", "lean": balance.angle})
		return
	if not is_on_floor() or _left_edge:
		state.event("fall_off")
		_enter_air(false)
		return
	if _just_pressed.has("ollie"):
		balance_kind = ""
		_ollie(tune.ollie_min)
		return
	if speed < 0.6:
		balance_kind = ""
		state.event("manual_end")
		_set_anim("idle_ride")


# --- air ----------------------------------------------------------------------------------------------

func _go_airborne(_from_grind: bool) -> void:
	if state.event("fall_off") or state.state == SkateState.State.AIR:
		_enter_air(false)
		_roll_off = not vert_air and state.state == SkateState.State.AIR


func _enter_air(_from_rail: bool) -> void:
	_ev("air")
	_roll_off = false
	balance_kind = ""
	_rail = null
	# Vert air needs a real transition behind it: a steep normal adopted in one tick off flat ground is an edge
	# touch (a wall end, a ramp rim), and the vert branch would throw away the sideways speed.
	vert_air = _launch_normal.y < tune.vert_normal_y and _launch_normal.y > -0.2 and velocity.y > 0.5 \
		and _transition_ticks >= VERT_MIN_TRANSITION_TICKS
	_transition_ticks = 0
	_touch_wall_n = Vector3.ZERO
	if vert_air:
		# THUG-style vert: stay in the ramp's plane so the skater comes back down onto the ramp.
		var out: Vector3 = Vector3(_launch_normal.x, 0.0, _launch_normal.z).normalized()
		var lateral: Vector3 = velocity - out * velocity.dot(out)
		lateral.y = 0.0
		velocity = Vector3(0.0, maxf(velocity.y, 0.0) + absf(velocity.dot(out)) * 0.6, 0.0) + lateral * VERT_LATERAL_KEEP + out * 0.7
	_floor_normal = Vector3.UP
	up_direction = Vector3.UP
	spin.start(_yaw())
	_grab_trick = {}
	_air_trick_until = 0.0
	var pending: Array = _pending_air
	_pending_air = []
	for p: Dictionary in pending:
		_air_trick(p["req"])


func _tick_air(delta: float, requests: Array) -> void:
	velocity += Vector3.DOWN * tune.gravity * delta
	# spin: shoulders or stick left/right
	var spin_in: float = 0.0
	if _held.has("spin_left"):
		spin_in += 1.0
	if _held.has("spin_right"):
		spin_in -= 1.0
	_lone_spin = _lone_spin + spin_in * tune.spin_rate * delta if spin_in != 0.0 else 0.0
	if spin_in == 0.0 and absf(_stick.x) > 0.35:
		# THUG-style stick spin, analog: past the steering range it spins, full stick at the spin rate.
		spin_in = -signf(_stick.x) * clampf((absf(_stick.x) - 0.35) / 0.5, 0.3, 1.0)
	if spin_in != 0.0:
		facing = facing.rotated(Vector3.UP, spin_in * tune.spin_rate * delta).normalized()
	elif not vert_air:
		# gentle drift of travel direction toward the stick (air control)
		var hv: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		if hv.length() > 0.5:
			velocity = velocity.rotated(Vector3.UP, -_stick.x * tune.air_steer * delta)
	spin.update(_yaw())
	# auto-align the board toward the predicted landing surface (generous, like THUG)
	var target_up: Vector3 = _predict_landing_normal()
	if vert_air and velocity.y > 0.0:
		target_up = _launch_normal
	if _snap_hold_up != Vector3.ZERO:
		target_up = _snap_hold_up  # dropping in off a ramp snap: the board stays square to the wall it drops down
	var air_turn: float = 12.0 if vert_air else 4.0
	if _roll_off:
		# Rolled off an edge without popping: the front wheels go first, so the nose dips with the fall a little, then
		# the rider levels it to put all four wheels down together.
		target_up = _roll_off_up(target_up)
		air_turn = ROLL_OFF_TURN
	board_up = _turn_toward(board_up, target_up, clampf(delta * air_turn, 0.0, 1.0))
	# tricks
	for r: Dictionary in requests:
		_air_trick(r)
	if not _grab_trick.is_empty():
		if _held.has("grab"):
			combo.add_hold_points(_hold_pps, delta)
		else:
			_grab_trick = {}
			_set_anim("air")
	if _recent_grind_press < 8 and _try_grind():
		return
	if vert_air and _recent_grind_press < 8 and _try_lip():
		return
	if _air_trick_until > 0.0 and _t >= _air_trick_until:
		_air_trick_until = 0.0
		_set_anim("air")
	# No air drag: only the horizontal speed is capped (at the ground's speed cap); the fall speed comes from gravity,
	# up to a terminal speed, so big drops and huge vert airs keep accelerating like they should.
	velocity.y = maxf(velocity.y, -AIR_TERMINAL_FALL)
	var hv_air: Vector2 = Vector2(velocity.x, velocity.z)
	if hv_air.length() > tune.max_speed:
		hv_air = hv_air.normalized() * tune.max_speed
		velocity = Vector3(hv_air.x, velocity.y, hv_air.y)
	up_direction = Vector3.UP
	floor_snap_length = 0.0
	var impact: Vector3 = velocity
	# A face steeper than any landing surface is a wall in the air, never a floor: a floor contact makes the slide
	# drop the whole vertical speed (falling past a bowl's vertical top or a box's side read as standing on it, the
	# fall zeroed in one tick). Back into a vert ramp every face up to the ground move's limit can be landed on.
	if not vert_air:
		floor_max_angle = acos(LAND_STEEP_NY)
	move_and_slide()
	floor_max_angle = deg_to_rad(GROUND_FLOOR_MAX_DEG)
	floor_snap_length = 0.6
	if is_on_wall() and not is_on_floor():
		var wn: Vector3 = get_wall_normal()
		if absf(wn.y) < 0.3 and _recent_grind_press < 10 and speed > 3.0 and state.event("wallride_start"):
			_wall_normal = wn
			_score_trick({"id": "wallride", "name": "Wallride", "points": 250, "kind": "wallride", "anim": "wallride", "points_per_sec": 100})
			return
	if is_on_floor():
		var land_n: Vector3 = _landing_normal(get_floor_normal())
		if land_n == Vector3.ZERO:
			_ev("edge_graze")  # clipped a wall's top edge or corner: not a landing, keep flying
			return
		_land(land_n, impact)


## Rolling off an edge: `land_up` (the predicted landing surface's up) tipped forward toward the fall line by
## ROLL_OFF_PITCH_SHARE of the flight path's angle below horizontal, at most ROLL_OFF_PITCH_MAX, fading out over the
## last ROLL_OFF_LEVEL_TIME s before touchdown so the board lands flat on its four wheels.
func _roll_off_up(land_up: Vector3) -> Vector3:
	var hv: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if hv.length() < 0.5 or velocity.y >= 0.0:
		return land_up
	var fall: float = atan2(-velocity.y, hv.length())
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 8.0, collision_mask, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	var t_land: float = 1.0
	if not hit.is_empty():
		var h: float = maxf(global_position.y - (hit["position"] as Vector3).y, 0.0)
		var vy: float = -velocity.y
		t_land = (-vy + sqrt(vy * vy + 2.0 * tune.gravity * h)) / tune.gravity
	var k: float = smoothstep(ROLL_OFF_LEVEL_TIME * 0.4, ROLL_OFF_LEVEL_TIME, t_land)
	var pitch: float = minf(fall * ROLL_OFF_PITCH_SHARE, deg_to_rad(ROLL_OFF_PITCH_MAX)) * k
	var axis: Vector3 = Vector3.UP.cross(hv.normalized())
	return land_up.rotated(axis.normalized(), pitch).normalized() if axis.length() > 0.001 else land_up


## The surface to land on from this tick's floor contacts: real faces only, plus edge or vertex blends that are
## nearly flat (the lip of a box top). A steep blend from clipping a wall's corner or a parapet's edge is not a
## landing surface (it would judge the board as tilted and bail): ZERO then, and the skater keeps flying.
func _landing_normal(fn: Vector3) -> Vector3:
	if fn.y >= LAND_EDGE_MIN_NY:
		return fn
	var sum: Vector3 = Vector3.ZERO
	var cos_max: float = cos(floor_max_angle) - 0.01
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		var n: Vector3 = c.get_normal()
		if n.y < LAND_STEEP_NY and not vert_air:
			continue  # a near-vertical face is a wall to bounce along, unless dropping back into a vert ramp
		if n.dot(up_direction) >= cos_max and (n.y >= LAND_EDGE_MIN_NY or _is_face_contact(c.get_position(), n)):
			sum += n
	if sum.length() < 0.001:
		return fn if get_slide_collision_count() == 0 else Vector3.ZERO
	return sum.normalized()


func _air_trick(r: Dictionary) -> void:
	var button: String = r["button"]
	var t: Dictionary = {}
	if special.is_special() and not (r["sequence"] as Array).is_empty():
		t = db.find_sequence(r["sequence"], button)
	if t.is_empty() and button != "grind":
		t = db.find(button, r["dir"], r["double_tap"])
	if t.is_empty() or t["kind"] == "grind":
		return
	if _air_trick_until > _t:
		return  # still finishing the last flip
	if t["kind"] == "grab":
		_grab_trick = t
		_hold_pps = int(t.get("points_per_sec", 0))
	else:
		var dur: float = tune.double_flip_time if bool(t.get("double_tap", false)) else tune.flip_time
		if t["kind"] == "special":
			dur = 0.9
			special.use_special()
		_air_trick_until = _t + dur
	_score_trick(t)


## impact: the velocity just before touching down (move_and_slide has already removed the part into the floor).
func _land(n: Vector3, impact: Vector3 = Vector3.ZERO) -> void:
	_floor_normal = n
	_curv = 0.0
	_roll_in_hold = 0
	_roll_off = false
	_snap_hold_up = Vector3.ZERO
	_lone_spin = 0.0
	var hit_v: Vector3 = impact if impact != Vector3.ZERO else velocity
	var judge: Dictionary = Landing.judge_reentry(_board_forward(), board_up, hit_v, n, tune.gravity,
			VERT_REENTRY_LOOKAHEAD) if vert_air \
		else Landing.judge(_board_forward(), board_up, hit_v, n)
	var result: String = judge["result"]
	var flip_left: float = _air_trick_until - _t
	if flip_left > 0.2:
		result = "bail"  # landed with the board still mid-flip
	elif flip_left > 0.0 and result == "clean":
		result = "sketchy"  # caught it late
	var spins: int = spin.spins180()
	_ev("land:" + result)
	if result == "bail":
		_bail({"cause": "flip" if flip_left > 0.2 else "land", "velocity": hit_v, "normal": n,
				"spin_deg": spin.degrees()})
		landed.emit(result)
		return
	if spins > 0:
		_score_trick({"id": "spin_%d" % spins, "name": spin.label() + " Spin", "points": SPIN_POINTS_PER_180 * spins, "kind": "spin", "anim": ""})
	if bool(judge["switch"]):
		switch_stance = not switch_stance
	# keep speed, now along the surface
	var v: Vector3 = hit_v.slide(n)
	var into: float = maxf(-hit_v.dot(n), 0.0)
	land_impact = clampf(into / 12.0, 0.0, 1.0)
	# Wheels first, knees take it: a clean landing scrubs a little speed, more the harder it hits (no bounce: the part
	# of the velocity into the surface is absorbed, never reflected).
	var keep: float = clampf(LAND_KEEP_MAX - LAND_KEEP_PER_MS * maxf(into - LAND_KEEP_FREE, 0.0), LAND_KEEP_MIN, LAND_KEEP_MAX) if result == "clean" else 0.8
	if vert_air and result == "clean" and v.length() > 0.5:
		# Clean vert re-entry: the fall turns into roll along the transition with no loss (as in THUG), so
		# pumping on each pass builds height instead of bleeding it away.
		v = v.normalized() * hit_v.length()
		keep = 1.0
	velocity = (v * keep).limit_length(tune.max_speed)
	if v.length() > 0.5:
		facing = v.normalized()
	if _topple_side != 0.0 and result != "bail":
		# Off a toppled grind: land carving toward the side we fell, already turned into it.
		var turn: float = -_topple_side * TOPPLE_LAND_TURN
		velocity = velocity.rotated(n, turn)
		facing = facing.rotated(n, turn).normalized()
		_carve_side = _topple_side
		_carve_left = TOPPLE_CARVE_TIME
	_topple_side = 0.0
	vert_air = false
	_grab_trick = {}
	var seq: Array = tricks.manual_tap_sequence()
	var m: Dictionary = db.find_sequence(seq, "") if seq.size() == 2 else {}
	if not m.is_empty() and state.event("land_manual"):
		tricks.clear()
		_start_balance_trick(m, "manual")
	else:
		state.event("land")
		_set_anim("land")
	up_direction = n
	landed.emit(result)


func _predict_landing_normal() -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3.UP * 0.3
	var to: Vector3 = from + velocity * 0.35 + Vector3.DOWN * 4.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return Vector3.UP
	var n: Vector3 = hit["normal"]
	return n if n.y > 0.2 else Vector3.UP


# --- rails, lips, walls -------------------------------------------------------------------------------

func _try_grind() -> bool:
	if speed < tune.grind_min_speed * 0.5 and state.state == SkateState.State.ROLLING:
		return false
	var best: GrindRail = null
	var best_hit: Dictionary = {}
	var best_d: float = tune.grind_reach
	for node: Node in get_tree().get_nodes_in_group("grind_rail"):
		var r: GrindRail = node as GrindRail
		if r == null or r.points.size() < 2:
			continue
		if r == _left_rail and _t - _left_rail_t < 0.25:
			continue  # just popped off its end: let a quick press transfer to the next rail
		var hit: Dictionary = r.closest(global_position)
		if hit.is_empty():
			continue
		var p: Vector3 = hit["point"]
		var dy: float = p.y - global_position.y
		if dy < -0.9 or dy > 1.3:
			continue
		var flat: float = Vector2(p.x - global_position.x, p.z - global_position.z).length()
		if flat < best_d:
			best_d = flat
			best = r
			best_hit = hit
	if best == null:
		return false
	if best.kind == "coping" and vert_air:
		return false  # vert + coping = lip trick, handled by _try_lip
	if not state.event("grind_start"):
		return false
	_rail = best
	_rail_seg = best_hit["segment"]
	_rail_t = best_hit["t"]
	var tan: Vector3 = best_hit["tangent"]
	var along: float = velocity.dot(tan)
	# A steep catch keeps at least half the incoming speed, turned onto the rail.
	if absf(along) < velocity.length() * 0.5:
		var sgn: float = signf(along) if absf(along) > 0.01 else (1.0 if facing.dot(tan) >= 0.0 else -1.0)
		along = velocity.length() * 0.5 * sgn
	var floor_speed: float = tune.grind_min_speed * 0.5
	if absf(along) < floor_speed:
		along = floor_speed * (1.0 if along >= 0.0 else -1.0)
		if absf(velocity.dot(tan)) < 0.01:
			along = floor_speed * (1.0 if facing.dot(tan) >= 0.0 else -1.0)
	_rail_speed = along
	_snap_offset += global_position - (best_hit["point"] as Vector3)
	global_position = best_hit["point"] as Vector3
	vert_air = false
	_recent_grind_press = 100
	var t: Dictionary = db.find("grind", TrickInput.quantize(_stick), false)
	if t.is_empty():
		t = {"id": "fifty_fifty", "name": "50-50", "points": 100, "kind": "grind", "anim": "grind_fifty_fifty", "points_per_sec": 60}
	_start_balance_trick(t, "grind")
	return true


func _tick_grind(delta: float) -> void:
	if _rail == null or not is_instance_valid(_rail):
		state.event("fall_off")
		_enter_air(true)
		return
	combo.add_hold_points(_hold_pps, delta)
	var cur: Dictionary = _rail.advance(_rail_seg, _rail_t, 0.0)
	var tan: Vector3 = cur["tangent"]
	_rail_speed += -tune.rail_gravity * tan.y * delta  # downhill rails speed up, uphill ones slow and slide back
	# Grind friction scales with speed around 8 m/s (rail_friction is the deceleration there), so a rail costs about
	# the same speed per metre at any pace: long rails stay finishable from a moderate run-in instead of grinding
	# to a halt, and fast grinds still bleed visibly.
	_rail_speed = move_toward(_rail_speed, 0.0, tune.rail_friction * clampf(absf(_rail_speed) / RAIL_FRICTION_REF, 0.35, 1.5) * delta)
	_rail_speed = clampf(_rail_speed, -tune.max_speed, tune.max_speed)
	if absf(_rail_speed) < 0.3 and absf(tan.y) < 0.05:
		state.event("fall_off")  # ground to a halt on a flat rail
		_enter_air(true)
		return
	var next: Dictionary = _rail.advance(_rail_seg, _rail_t, _rail_speed * delta)
	_rail_seg = next["segment"]
	_rail_t = next["t"]
	var p: Vector3 = next["point"]
	var move_dir: Vector3 = (next["tangent"] as Vector3) * signf(_rail_speed)
	velocity = move_dir * absf(_rail_speed)
	global_position = p
	facing = Vector3(move_dir.x, 0.0, move_dir.z).normalized() if Vector2(move_dir.x, move_dir.z).length() > 0.01 else facing
	board_up = _turn_toward(board_up, Vector3.UP, clampf(delta * 10.0, 0.0, 1.0))
	if not balance.update(delta, _stick.x):
		_grind_topple()
		return
	if _just_pressed.has("ollie"):
		_left_rail = _rail
		_left_rail_t = _t
		_ollie(7.5)
		return
	if bool(next["ended"]):
		_left_rail = _rail
		_left_rail_t = _t
		state.event("fall_off")
		velocity += Vector3.UP * 3.0
		_enter_air(true)


## The grind balance tipped over. Low and moving: step off the rail on the side you leaned, a small sideways hop to
## the ground that lands rolling and carves away (the combo lands as usual). High up or nearly stopped: a real bail,
## because there is no ground in reach to step down onto, or no speed to ride away with.
func _grind_topple() -> void:
	var side: float = 1.0 if balance.angle >= 0.0 else -1.0
	var along: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var right: Vector3 = (along.normalized() if along.length() > 0.1 else facing).cross(Vector3.UP).normalized()
	var drop: float = 99.0
	if is_inside_tree():
		var from: Vector3 = global_position + right * side * 0.7 + Vector3.UP * 0.3
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (TOPPLE_MAX_DROP + 2.0), collision_mask, [get_rid()])
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			drop = global_position.y - (hit["position"] as Vector3).y
	if drop > TOPPLE_MAX_DROP or absf(_rail_speed) < TOPPLE_MIN_SPEED:
		_bail({"cause": "grind", "drop": drop, "rail_speed": _rail_speed, "lean": side})
		return
	_left_rail = _rail
	_left_rail_t = _t
	_ev("topple_carve")
	state.event("fall_off")
	velocity = along * TOPPLE_KEEP + right * side * TOPPLE_HOP_SIDE + Vector3.UP * TOPPLE_HOP_UP
	global_position += Vector3.UP * 0.05
	_launch_normal = Vector3.UP
	_enter_air(true)
	_topple_side = side
	_set_anim("air")


func _try_lip() -> bool:
	if velocity.y < -3.0:
		return false
	for node: Node in get_tree().get_nodes_in_group("grind_rail"):
		var r: GrindRail = node as GrindRail
		if r == null or r.kind != "coping":
			continue
		var hit: Dictionary = r.closest(global_position)
		if hit.is_empty() or (hit["distance"] as float) > 1.4:
			continue
		if not state.event("lip_start"):
			return false
		var t: Dictionary = db.find_lip(TrickInput.quantize(_stick))
		if t.is_empty():
			t = db.find_lip("N")
		var lip_at: Vector3 = (hit["point"] as Vector3) + Vector3.UP * 0.1
		_snap_offset += global_position - lip_at
		global_position = lip_at
		velocity = Vector3.ZERO
		_start_balance_trick(t, "lip")
		return true
	return false


func _tick_lip(delta: float, _requests: Array) -> void:
	combo.add_hold_points(_hold_pps, delta)
	if not balance.update(delta, _stick.x):
		_bail({"cause": "lip", "lean": balance.angle})
		return
	if _just_pressed.has("ollie") or _just_pressed.has("grind") or balance.time_held() > tune.lip_max_time:
		# drop back in: down the ramp, which faces along the launch normal
		balance_kind = ""
		state.event("lip_end")
		var out: Vector3 = Vector3(_launch_normal.x, 0.0, _launch_normal.z).normalized()
		global_position += out * 0.4
		_snap_offset -= out * 0.4
		velocity = out * 1.0 + Vector3.DOWN * 1.0
		facing = out
		_launch_normal = Vector3.UP
		vert_air = false
		spin.start(_yaw())
		_set_anim("air")


func _tick_wallride(delta: float) -> void:
	combo.add_hold_points(_hold_pps, delta)
	velocity = velocity.slide(_wall_normal)
	velocity += Vector3.DOWN * tune.gravity * 0.3 * delta
	velocity += -_wall_normal * 0.5  # stay against the wall
	up_direction = Vector3.UP
	move_and_slide()
	if _just_pressed.has("ollie"):
		velocity += _wall_normal * 3.5 + Vector3.UP * 6.0
		state.event("ollie")
		_ev("ollie")
		_score_trick({"id": "wallie", "name": "Wallie", "points": 200, "kind": "wallride", "anim": "ollie"})
		_enter_air(false)
		return
	if state.time_in_state > tune.wallride_time or not is_on_wall() or is_on_floor():
		state.event("fall_off")
		velocity += _wall_normal * 1.0
		_enter_air(false)
		if is_on_floor():
			_land(get_floor_normal())


# --- ramp snap ----------------------------------------------------------------------------------------

## Q + E / L1 + R1 together. Inside a ramp (on a transition, in vert air, on a lip, down in a half pipe or bowl) it
## takes the skater out of it; otherwise into the nearest ramp in reach (see RampSnap). Never on foot or bailing.
## Returns true when a snap started.
func _try_ramp_snap() -> bool:
	var st: SkateState.State = state.state
	if not st in [SkateState.State.ROLLING, SkateState.State.MANUAL, SkateState.State.AIR, SkateState.State.LIP]:
		return false
	if ragdoll_active or not is_inside_tree():
		return false
	var segs: Array = _lip_segments()
	var grounded: bool = st == SkateState.State.ROLLING or st == SkateState.State.MANUAL
	var inside: bool = RampSnap.in_ramp(grounded, _floor_normal.y, vert_air, st == SkateState.State.LIP,
			RampSnap.enclosed(global_position, segs))
	var plan: Dictionary = _plan_snap_out(segs) if inside else {}
	if plan.is_empty():
		plan = _plan_snap_in(segs, st == SkateState.State.AIR)
	if plan.is_empty():
		_ev("ramp_snap_miss")
		ramp_snap_missed.emit()
		return false
	_begin_snap(plan)
	return true


## The snap's turn from the take-off facing to the arrival facing, by yaw: face the way the arc travels through its
## first half, then turn to the arrival facing. A half turn (rolling straight at a ramp, arriving facing down it) spins
## the same way round through the way the arc travels, so it reads as a frontside 180, not a flip or a whip at the end.
## The turn runs on an eased constant-rate profile never faster than SNAP_YAW_MAX_DEG a tick: a long turn stretches a
## drop-in's turn into its hang on the coping (the tail pivots on it), or the hop itself for the other snaps.
func _plan_snap_yaw() -> void:
	var f0: Vector3 = _snap["face0"]
	var f1: Vector3 = _snap["face1"]
	var fm: Vector3 = (_snap["p1"] as Vector3) - (_snap["p0"] as Vector3)
	fm.y = 0.0
	fm = fm.normalized() if fm.length() > 0.5 else f1
	var y0: float = atan2(-f0.x, -f0.z)
	var ym: float = atan2(-fm.x, -fm.z)
	var y1: float = atan2(-f1.x, -f1.z)
	var turn: float = angle_difference(y0, y1)
	if absf(angle_difference(y0, ym)) < absf(angle_difference(ym, y1)) and absf(turn) > PI * 0.5:
		turn = angle_difference(y0, ym) + angle_difference(ym, y1)
	var dur: float = _snap["dur"]
	var need: float = absf(turn) * SNAP_YAW_PEAK / (deg_to_rad(SNAP_YAW_MAX_DEG) * 60.0)
	var yaw_dur: float = maxf(dur, need)
	if str(_snap["mode"]) == "drop_in" and not bool(_snap.get("glide", false)):
		yaw_dur = minf(yaw_dur, dur + RampSnap.HANG_TIME + RampSnap.STOMP_TIME * 0.5)
	elif yaw_dur > dur:
		_snap["dur"] = minf(yaw_dur, SNAP_ARC_STRETCH_MAX)  # a slower hop, so the board turns round smoothly
		yaw_dur = _snap["dur"]
	_snap["yaw0"] = y0
	_snap["yaw_turn"] = turn
	_snap["yaw_dur"] = yaw_dur
	_snap["yt"] = 0.0


func _turn_snap_yaw(delta: float) -> void:
	if not _snap.has("yaw_dur"):
		return
	var yt: float = float(_snap["yt"]) + delta
	_snap["yt"] = yt
	var x: float = clampf(yt / maxf(float(_snap["yaw_dur"]), 0.001), 0.0, 1.0)
	var yaw: float = float(_snap["yaw0"]) + float(_snap["yaw_turn"]) * _ramp_profile(x)
	facing = Vector3(-sin(yaw), 0.0, -cos(yaw))


## 0..1 progress with an eased start and end and a constant rate between: peak rate SNAP_YAW_PEAK times the average.
static func _ramp_profile(x: float) -> float:
	var a: float = 1.0 - 1.0 / SNAP_YAW_PEAK
	var vmax: float = SNAP_YAW_PEAK
	if x < a:
		return vmax * x * x / (2.0 * a)
	if x > 1.0 - a:
		return 1.0 - vmax * (1.0 - x) * (1.0 - x) / (2.0 * a)
	return vmax * (x - a * 0.5)


static func _smooth01(x: float) -> float:
	var p: float = clampf(x, 0.0, 1.0)
	return p * p * (3.0 - 2.0 * p)


## True during a ramp snap and its drop down the wall: the camera turns round faster to stay behind the skater.
func snapping() -> bool:
	return not _snap.is_empty() or _snap_hold_up != Vector3.ZERO


## The chord's first button already spun the skater for a few ticks before the second came down: take it back.
func _undo_lone_spin() -> void:
	if state.state == SkateState.State.AIR and _lone_spin != 0.0:
		facing = facing.rotated(Vector3.UP, -_lone_spin).normalized()
		spin.update(_yaw())
	_lone_spin = 0.0


func _lip_segments() -> Array:
	var segs: Array = []
	for n: Node in get_tree().get_nodes_in_group("ramp_lip"):
		var lip: RampLip = n as RampLip
		if lip != null:
			segs.append_array(lip.segments())
	return segs


## Snap in: the nearest lip in reach with a clear spot to arrive at. {} when none.
func _plan_snap_in(segs: Array, air: bool) -> Dictionary:
	var pos: Vector3 = global_position
	var reach: float = tune.snap_reach_air if air else tune.snap_reach_roll
	var cands: Array = RampSnap.candidates(pos, segs, reach)
	for i: int in mini(cands.size(), 8):
		var c: Dictionary = cands[i]
		var lip: Vector3 = c["point"]
		var inward: Vector3 = c["inward"]
		if str(c["kind"]) == "roll_in":
			var deck: Dictionary = _flat_under(lip - inward * RampSnap.ROLL_BACK, 1.0, 1.5)
			if deck.is_empty() or not _clear_at(deck["pos"]):
				continue
			return {"mode": "roll_in", "p1": deck["pos"], "face1": inward, "lip": lip, "inward": inward}
		var rel: Dictionary = _drop_release(lip, inward)
		if rel.is_empty():
			continue
		if air and pos.y < lip.y - 0.5 and not bool(c["behind"]):
			# already below the lip in the air: straight onto the wall, no deck to hang the tail on
			return {"mode": "air_in", "p1": rel["rest"], "face1": inward, "rel": rel["pos"], "rest": rel["rest"], "n": rel["n"], "lip": lip, "inward": inward}
		var hang: Vector3 = RampSnap.hang_spot(lip, inward, AnimeBoard.TRUCK_Z)
		if not _clear_at(hang):
			continue
		return {"mode": "drop_in", "p1": hang, "face1": inward, "rel": rel["pos"], "rest": rel["rest"], "n": rel["n"], "lip": lip, "inward": inward}
	return {}


## Snap out: onto the flat in front of the ramp the skater is in, rolling away from it; when that flat is inside the
## ramp too (a half pipe's flat bottom, a bowl floor), onto the deck behind the nearest coping. {} when neither fits.
func _plan_snap_out(segs: Array) -> Dictionary:
	var pos: Vector3 = global_position
	var walls: Array = RampSnap.walls_around(pos, segs)
	if walls.is_empty():
		# high in vert air over the coping: the lip below, on the side the skater came up
		for c: Dictionary in RampSnap.candidates(pos, segs, 4.0):
			if not bool(c["behind"]):
				walls.append(c)
				break
	if walls.is_empty():
		return {}
	var w: Dictionary = walls[0]
	var lip: Vector3 = w["point"]
	var inward: Vector3 = w["inward"]
	# march out along the ramp to where the flat starts, then a few metres on
	var k: float = 0.5
	while k <= 16.0:
		var probe: Dictionary = _flat_under(lip + inward * k, 1.0, 20.0)
		if not probe.is_empty() and (probe["pos"] as Vector3).y < lip.y - 0.3:
			var land: Dictionary = _flat_under(lip + inward * (k + RampSnap.OUT_FLAT), 1.0, 20.0)
			if not land.is_empty() and absf((land["pos"] as Vector3).y - (probe["pos"] as Vector3).y) < 0.3 \
					and _clear_at(land["pos"]) and not RampSnap.enclosed(land["pos"], segs):
				return {"mode": "out", "p1": land["pos"], "face1": inward, "speed": tune.snap_out_speed, "over_y": lip.y + RampSnap.OUT_CLEAR}
			break
		k += 0.5
	# off the side: past the nearer end of the lip, beside the ramp (a half pipe's flat bottom is inside it)
	var tan: Vector3 = w["tangent"]
	var ends: Array = _lip_ends(segs, lip, tan)
	for e: Variant in ends:
		var end_pt: Vector3 = (e as Array)[0]
		var away: Vector3 = (e as Array)[1]
		var side: Dictionary = _flat_under(end_pt + away * RampSnap.SIDE_OUT + inward * RampSnap.SIDE_IN, 1.0, 20.0)
		if not side.is_empty() and (side["pos"] as Vector3).y < lip.y - 0.3 and _clear_at(side["pos"]) \
				and not RampSnap.enclosed(side["pos"], segs):
			return {"mode": "out", "p1": side["pos"], "face1": inward, "speed": tune.snap_out_speed, "over_y": lip.y + RampSnap.OUT_CLEAR}
	var deck: Dictionary = _flat_under(lip - inward * RampSnap.DECK_BACK, 1.0, 1.5)
	if deck.is_empty() or not _clear_at(deck["pos"]):
		return {}
	var hv: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if hv.dot(tan) < 0.0 or (hv.length() < 0.5 and facing.dot(tan) < 0.0):
		tan = -tan
	return {"mode": "out_deck", "p1": deck["pos"], "face1": tan, "speed": RampSnap.DECK_SPEED, "over_y": lip.y + RampSnap.OUT_CLEAR}


## The two ends of the straight run of lip through `lip` along `tan` (following segments that continue in line),
## nearer first: [[end point, outward direction along the lip], ...].
func _lip_ends(segs: Array, lip: Vector3, tan: Vector3) -> Array:
	var lo: Vector3 = lip
	var hi: Vector3 = lip
	for s: Dictionary in segs:
		var a: Vector3 = s["a"]
		var b: Vector3 = s["b"]
		var d: Vector3 = b - a
		d.y = 0.0
		if d.length() < 0.01 or absf(d.normalized().dot(tan)) < 0.999:
			continue
		var off: Vector3 = a - lip
		off.y = 0.0
		if (off - tan * off.dot(tan)).length() > 0.05 or absf(a.y - lip.y) > 0.05:
			continue  # parallel but not on this lip's line
		for q: Vector3 in [a, b]:
			var t: float = (q - lip).dot(tan)
			if t < (lo - lip).dot(tan):
				lo = q
			if t > (hi - lip).dot(tan):
				hi = q
	var out: Array = [[hi, tan], [lo, -tan]]
	if lip.distance_to(lo) < lip.distance_to(hi):
		out.reverse()
	return out


## Flat ground straight under `p`: a ray from `up` metres above it to `down` metres below. {pos, n} or {}.
func _flat_under(p: Vector3, up: float, down: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * up, p + Vector3.DOWN * down, collision_mask, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < RampSnap.ON_TRANSITION_NY:
		return {}
	return {"pos": hit["position"], "n": hit["normal"]}


## Where a drop-in leaves the coping: just past it, over a wall that faces down the ramp. The body's sphere is swept
## down from there to where it will meet the wall; the board is set square to that spot's normal for the drop (so
## the catch is clean). {pos, n} or {}.
func _drop_release(lip: Vector3, inward: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for out: float in [RampSnap.DROP_OUT, 0.5, 0.8]:
		var at: Vector3 = lip + inward * out + Vector3.UP * 0.05
		if not _clear_at(at):
			continue
		var sphere := SphereShape3D.new()
		sphere.radius = 0.3
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sphere
		q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.3)
		q.motion = Vector3.DOWN * 6.0
		q.collision_mask = collision_mask
		q.exclude = [get_rid()]
		var frac: PackedFloat32Array = space.cast_motion(q)
		if frac.size() < 2 or frac[1] >= 1.0:
			continue
		q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.3 + q.motion * frac[1])
		q.motion = Vector3.ZERO
		var rest: Dictionary = space.get_rest_info(q)
		if rest.is_empty():
			continue
		var n: Vector3 = rest["normal"]
		if n.y < 0.05 or n.y > RampSnap.ON_TRANSITION_NY or Vector3(n.x, 0.0, n.z).normalized().dot(inward) < 0.5:
			continue  # no wall facing down the ramp under this spot
		# where the body comes to rest against the wall: the sphere a hair short of touching it
		var centre: Vector3 = at + Vector3.UP * 0.3 + Vector3.DOWN * 6.0 * frac[0] + n * 0.01
		return {"pos": at, "n": n, "rest": centre - Vector3.UP * 0.3}
	return {}


## True when the skater's sphere fits at origin `p` without touching the park.
func _clear_at(p: Vector3) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.27
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.32)
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _begin_snap(plan: Dictionary) -> void:
	if state.state != SkateState.State.AIR:
		state.event("ollie")
	balance_kind = ""
	_rail = null
	_grab_trick = {}
	_air_trick_until = 0.0
	_pending_air.clear()
	tricks.clear()
	crouch = 0.0
	_crouch_time = 0.0
	vert_air = false
	_topple_side = 0.0
	_carve_left = 0.0
	_left_edge = false
	_snap_hold_up = Vector3.ZERO
	var p0: Vector3 = global_position
	var dist: float = p0.distance_to(plan["p1"] as Vector3)
	_snap = plan.duplicate()
	_snap["phase"] = "arc"
	_snap["t"] = 0.0
	_snap["p0"] = p0
	_snap["dur"] = RampSnap.arc_time(dist)
	_snap["apex"] = RampSnap.arc_apex(dist, p0, plan["p1"], float(plan.get("over_y", -INF)))
	if str(plan["mode"]) == "drop_in" and RampSnap.deck_glide(p0, plan["p1"], plan["lip"], plan["inward"]):
		# already on the deck behind the coping: walk the board up to it, no hop through the air
		_snap["apex"] = 0.0
		_snap["dur"] = clampf(0.25 + dist * 0.12, 0.25, 0.5)
		_snap["glide"] = true
	_snap["face0"] = facing
	_snap["speed0"] = velocity.length()
	_plan_snap_yaw()
	spin.start(_yaw())
	_ev("ramp_snap:" + str(plan["mode"]))
	_set_anim("idle_ride" if bool(_snap.get("glide", false)) else "ollie")
	ramp_snapped.emit(str(plan["mode"]))


## One tick of a ramp snap: the guided arc, then the drop-in hang, stomp and tip over the coping. The body is placed
## directly (no slide): every arrival spot was checked clear before the snap began.
func _tick_snap(delta: float) -> void:
	_snap["t"] = float(_snap["t"]) + delta
	var t: float = _snap["t"]
	match str(_snap["phase"]):
		"hang":
			velocity = Vector3.ZERO
			_turn_snap_yaw(delta)
			board_up = _turn_toward(board_up, Vector3.UP, clampf(delta * 12.0, 0.0, 1.0))
			if t >= RampSnap.HANG_TIME and camera_hold <= 0.0:
				# The stomp: the camera (which swung round behind during the hop and the hang) starts rising to a perch
				# over the coping, to watch the drop from there (see SkateCamera); it blends in, so it starts early.
				camera_anchor = RampSnap.camera_perch(_snap["lip"], _snap["inward"])
				camera_hold = RampSnap.CAMERA_HOLD + RampSnap.STOMP_TIME + RampSnap.TIP_TIME
			if t >= RampSnap.HANG_TIME + RampSnap.STOMP_TIME:
				_snap["phase"] = "tip"
				_snap["t"] = 0.0
				_snap["c0"] = global_position + Vector3.UP * 0.3
			return
		"tip":
			_tick_tip(delta)
			return
	var u: float = clampf(t / float(_snap["dur"]), 0.0, 1.0)
	var p: Vector3 = RampSnap.arc_point(_snap["p0"], _snap["p1"], _snap["apex"], u)
	if bool(_snap.get("glide", false)):
		p = (_snap["p0"] as Vector3).lerp(_snap["p1"], _smooth01(u))  # rolled up to the coping, easing to a stop on it
	# The arc is a guided hop, not a launch: report a travel speed no faster than the skater came in with (the HUD,
	# camera FOV and speed lines read it), never the 20+ m/s the path itself covers in a few ticks.
	velocity = ((p - global_position) / maxf(delta, 0.0001)).limit_length(maxf(float(_snap["speed0"]), 4.0))
	global_position = p
	_turn_snap_yaw(delta)
	var up_goal: Vector3 = Vector3.UP
	if str(_snap["mode"]) == "air_in":
		# straight onto the wall: the board turns square to it through the second half, so the wheels meet it flat
		up_goal = Vector3.UP.slerp(_snap["n"] as Vector3, _smooth01((u - 0.4) / 0.6))
	board_up = _turn_toward(board_up, up_goal, clampf(delta * 10.0, 0.0, 1.0)) if up_goal == Vector3.UP else up_goal
	if u > 0.3 and anim == "ollie":
		_set_anim("air")
	if u >= 1.0:
		_arrive_snap()


func _arrive_snap() -> void:
	var mode: String = _snap["mode"]
	global_position = _snap["p1"]
	if mode != "drop_in" or float(_snap.get("yt", 0.0)) >= float(_snap.get("yaw_dur", 0.0)):
		facing = _snap["face1"]  # (a drop-in finishes its turn on the coping, during the hang)
	match mode:
		"drop_in":
			_snap["phase"] = "hang"
			_snap["t"] = 0.0
			velocity = Vector3.ZERO
			_set_anim("drop_in")
		"air_in":
			camera_anchor = RampSnap.camera_perch(_snap["lip"], _snap["inward"])
			camera_hold = RampSnap.CAMERA_HOLD
			_start_wall_roll(_snap["n"], maxf(float(_snap["speed0"]) * 0.5, tune.snap_drop_speed))
		_:
			# roll_in, out, out_deck: set down on flat ground, rolling
			var spd: float = RampSnap.ROLL_SPEED if mode == "roll_in" else float(_snap.get("speed", tune.snap_out_speed))
			velocity = facing * spd
			_floor_normal = Vector3.UP
			up_direction = Vector3.UP
			board_up = Vector3.UP
			_launch_normal = Vector3.UP
			_transition_ticks = 0
			_snap = {}
			state.event("land")
			if mode == "roll_in":
				_score_trick({"id": "roll_in", "name": "Roll In", "points": 50, "kind": "snap", "anim": ""})
			_ev("land:clean")
			_set_anim("land")
			landed.emit("clean")


## The drop-in tip: the front foot has stomped the nose down; the board rolls over the coping on its rear wheels and
## onto the wall (the sphere swung about the coping, the board's up turned from the deck's to the wall's), picking up
## the speed of that swing, then rides the wall as ordinary ground. No air, no hop, no snap of orientation.
func _tick_tip(delta: float) -> void:
	var s: float = clampf(float(_snap["t"]) / RampSnap.TIP_TIME, 0.0, 1.0)
	var n: Vector3 = _snap["n"]
	var c1: Vector3 = (_snap["rest"] as Vector3) + Vector3.UP * 0.3
	# the nose turns down eased in and out; the body starts down the wall from rest, eased in (it falls into it), so
	# the speed only ever grows and hands over to the ride down the wall without a step
	var fall: float = clampf((s - 0.3) / 0.7, 0.0, 1.0)
	var pose: Array = RampSnap.tip_pose(_snap["c0"], c1, _snap["lip"], n, lerpf(s, _smooth01(s), 0.5), fall * fall)
	var origin: Vector3 = (pose[0] as Vector3) - Vector3.UP * 0.3
	var was_speed: float = velocity.length()
	velocity = (origin - global_position) / maxf(delta, 0.0001)
	if s >= 1.0:
		velocity = velocity.normalized() * maxf(velocity.length(), was_speed)  # the last step is a partial tick
	global_position = origin
	board_up = pose[1]
	var down: Vector3 = Vector3.DOWN.slide(board_up)
	if down.length() > 0.2:
		facing = down.normalized()
	if s >= 1.0:
		_start_wall_roll(n, maxf(velocity.length(), tune.snap_drop_speed))


## Wheels on the wall below the coping: ride it down as ordinary ground (ROLLING on the transition), starting at
## `v0` m/s straight down the fall line. The landing signals fire here (the stomp's clack), with no air time.
func _start_wall_roll(n: Vector3, v0: float) -> void:
	var rest: Vector3 = _snap.get("rest", global_position)
	global_position = rest
	var down: Vector3 = Vector3.DOWN.slide(n).normalized()
	velocity = down * maxf(v0, velocity.dot(down))
	facing = down
	board_up = n
	_floor_normal = n
	up_direction = n
	_launch_normal = n
	_transition_ticks = VERT_MIN_TRANSITION_TICKS
	_since_bend = 1.0
	_curv = WALL_ROLL_CURV  # set on a ramp's wall: a transition's concave curve lies ahead
	vert_air = false
	_snap_hold_up = Vector3.ZERO
	_snap = {}
	spin.start(_yaw())
	state.event("land")
	_ev("ramp_snap_release")
	_ev("land:clean")
	_score_trick({"id": "drop_in", "name": "Drop In", "points": 50, "kind": "snap", "anim": ""})
	if anim != "drop_in":
		_set_anim("drop_in")
		anim_time = RampSnap.HANG_TIME + RampSnap.STOMP_TIME  # straight into the ride-down part of the pose
	landed.emit("clean")


# --- walking ------------------------------------------------------------------------------------------

## ROLLING -> WALK: hop off the board (at speed, jog a few steps to a stop) and carry it.
func _try_dismount() -> void:
	if not is_on_floor() or _floor_normal.y < 0.7:
		return
	var h: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if not state.event("dismount"):
		return
	walker.begin(h.normalized() if h.length() > 0.5 else facing, h.length())
	velocity = Vector3(h.x, minf(velocity.y, 0.0), h.z)
	facing = walker.facing
	tricks.clear()
	_pending_air.clear()
	crouch = 0.0
	_crouch_time = 0.0
	balance_kind = ""
	_left_edge = false
	_set_anim("dismount")


## WALK -> ROLLING: drop the board in front of the feet and hop on, rolling at the walking speed.
func _try_mount() -> bool:
	if walker.step_time < Walker.MIN_WALK_TIME or not is_on_floor() or not state.event("mount"):
		return false
	_floor_normal = get_floor_normal()
	velocity = Vector3(velocity.x, 0.0, velocity.z).slide(_floor_normal)
	facing = walker.facing
	up_direction = _floor_normal
	_left_edge = false
	_set_anim("mount")
	return true


func _tick_walk(delta: float) -> void:
	if _just_pressed.has("dismount") and _try_mount():
		return
	var cam_fwd: Vector3 = Vector3.ZERO
	if is_inside_tree() and get_viewport() != null:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null:
			cam_fwd = -cam.global_basis.z
	walker.step(self, delta, _stick, _just_pressed.has("ollie"), tune, cam_fwd)
	facing = walker.facing
	if is_on_floor():
		_floor_normal = get_floor_normal()
	else:
		_floor_normal = Vector3.UP
	board_up = _turn_toward(board_up, _floor_normal, clampf(delta * 12.0, 0.0, 1.0))
	if walker.step_time < Walker.STEP_OFF_TIME:
		_set_anim("dismount")
	elif not walker.grounded:
		_set_anim("walk_jump")
	else:
		_set_anim("walk")


## Floor rules for a walker: it can't climb steep ramps (they act as walls it slides down) and stands still on slopes.
func _set_walk_physics(walking: bool) -> void:
	floor_max_angle = deg_to_rad(Walker.FLOOR_MAX_ANGLE if walking else GROUND_FLOOR_MAX_DEG)
	floor_stop_on_slope = walking


# --- bail ---------------------------------------------------------------------------------------------

## ctx: what caused it (BailKind context keys; the ragdoll's plan is classified from it).
func _bail(ctx: Dictionary = {}) -> void:
	_bail_ctx = ctx
	balance_kind = ""
	_snap = {}
	_snap_hold_up = Vector3.ZERO
	_topple_side = 0.0
	_carve_left = 0.0
	_rail = null
	_grab_trick = {}
	_air_trick_until = 0.0
	vert_air = false
	state.event("bail")
	_set_anim("bail_fall")
	_start_ragdoll()
	bailed.emit()


## Hands the body and board to a physics ragdoll for the slam, when the visual rig is there (not in bare sims).
func _start_ragdoll() -> void:
	_end_ragdoll()
	if _visual == null or not is_inside_tree() or get_parent() == null:
		return
	var body: Node3D = _visual.get_node_or_null("SkaterBody") as Node3D
	var board: Node3D = _visual.get_node_or_null("Skateboard") as Node3D
	if body == null or board == null:
		return
	var spin: Vector3 = facing.cross(Vector3.UP).normalized() * -3.0 if facing.length() > 0.1 else Vector3(-3.0, 0.0, 0.0)
	var plan: Dictionary = BailKind.classify(SkaterRagdoll.bail_context(self, _bail_ctx), GameSettings.injuries_on())
	_ragdoll = SkaterRagdoll.spawn(body, board, velocity, spin, get_parent(), plan)
	BailFx.track(self, _ragdoll)
	ragdoll_active = true
	_getup_left = 0.0


func _end_ragdoll() -> void:
	if _ragdoll != null and is_instance_valid(_ragdoll):
		_ragdoll.finish()
	_ragdoll = null
	ragdoll_active = false


func _tick_bail(delta: float) -> void:
	if _ragdoll != null and is_instance_valid(_ragdoll):
		# The ragdoll owns the slam: the skater just follows the pelvis (for the camera) until it settles,
		# then stands up where the body came to rest.
		global_position = _ragdoll.pelvis_transform().origin  # the ground under the pelvis
		velocity = Vector3.ZERO
		if _ragdoll.settled():
			var t: Transform3D = _ragdoll.pelvis_transform()
			_end_ragdoll()
			global_position = t.origin
			facing = -t.basis.z
			board_up = Vector3.UP
			_floor_normal = Vector3.UP
			_getup_left = tune.getup_time
			_set_anim("bail_getup")
		return
	if _getup_left > 0.0:
		_getup_left -= delta
		if _getup_left > 0.0:
			return
		if state.time_in_state >= SkateState.BAIL_TIME and state.event("recover"):
			_set_anim("idle_ride")
		return
	velocity += Vector3.DOWN * tune.gravity * delta
	var h: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 8.0 * delta)
	velocity = Vector3(h.x, velocity.y, h.z)
	up_direction = Vector3.UP
	move_and_slide()
	if is_on_floor():
		_floor_normal = get_floor_normal()
	board_up = _turn_toward(board_up, Vector3.UP, clampf(delta * 3.0, 0.0, 1.0))
	if state.time_in_state > SkateState.BAIL_TIME * 0.6 and anim == "bail_fall":
		_set_anim("bail_getup")
	if state.event("recover"):
		_set_anim("idle_ride")
		if _floor_normal.y < 0.6:
			_floor_normal = Vector3.UP


func respawn() -> void:
	_ev("respawn")
	_end_ragdoll()
	_getup_left = 0.0
	_snap = {}
	_snap_hold_up = Vector3.ZERO
	camera_hold = 0.0
	_roll_off = false
	global_transform = _spawn
	velocity = Vector3.ZERO
	_snap_offset = Vector3.ZERO
	facing = -_spawn.basis.z
	board_up = Vector3.UP
	_floor_normal = Vector3.UP
	_curv = 0.0
	if state.state != SkateState.State.ROLLING:
		state = SkateState.new()
		state.combo_landed.connect(_on_combo_landed)
		state.combo_bailed.connect(_on_combo_bailed)
		state.state_changed.connect(_on_state_changed)
	_set_walk_physics(false)
	combo.bail()
	gaps.reset_combo()
	_set_anim("idle_ride")


# --- snapshot / restore ---------------------------------------------------------------------------------

## Everything that affects future physics, as plain Variants (Vector3, Transform3D, Dictionary, Array, String,
## int, float, bool) so it survives var_to_str / str_to_var. Inputs are not included: feed them with set_input.
func snapshot() -> Dictionary:
	var rail_path: String = ""
	if _rail != null and is_instance_valid(_rail) and _rail.is_inside_tree():
		rail_path = str(_rail.get_path())
	var left_rail_path: String = ""
	if _left_rail != null and is_instance_valid(_left_rail) and _left_rail.is_inside_tree():
		left_rail_path = str(_left_rail.get_path())
	return {
		"transform": global_transform if is_inside_tree() else transform,
		"velocity": velocity,
		"up_direction": up_direction,
		"speed": speed,
		"facing": facing,
		"board_up": board_up,
		"floor_normal": _floor_normal,
		"launch_normal": _launch_normal,
		"wall_normal": _wall_normal,
		"vert_air": vert_air,
		"crouch": crouch,
		"crouch_time": _crouch_time,
		"switch_stance": switch_stance,
		"anim": anim,
		"anim_time": anim_time,
		"anim_trick": anim_trick.duplicate(true),
		"balance_kind": balance_kind,
		"t": _t,
		"seed": _seed,
		"tick": _tick_count,
		"air_trick_until": _air_trick_until,
		"grab_trick": _grab_trick.duplicate(true),
		"hold_pps": _hold_pps,
		"rail": rail_path,
		"rail_seg": _rail_seg,
		"rail_t": _rail_t,
		"rail_speed": _rail_speed,
		"left_rail": left_rail_path,
		"left_rail_t": _left_rail_t,
		"left_edge": _left_edge,
		"transition_ticks": _transition_ticks,
		"touch_wall_n": _touch_wall_n,
		"since_bend": _since_bend,
		"curv": _curv,
		"roll_in_hold": _roll_in_hold,
		"roll_in_dir": _roll_in_dir,
		"topple_side": _topple_side,
		"roll_off": _roll_off,
		"carve_side": _carve_side,
		"carve_left": _carve_left,
		"recent_grind_press": _recent_grind_press,
		"recent_revert_press": _recent_revert_press,
		"pending_air": _pending_air.duplicate(true),
		"snap_offset": _snap_offset,
		"spawn": _spawn,
		"ragdoll": ragdoll_active,
		"getup_left": _getup_left,
		"walker": walker.to_dict(),
		"snap": _snap.duplicate(true),
		"snap_hold_up": _snap_hold_up,
		"lone_spin": _lone_spin,
		"camera_hold": camera_hold,
		"camera_anchor": camera_anchor,
		"chord": chord.to_dict(),
		"state": {
			"state": int(state.state),
			"time_in_state": state.time_in_state,
			"combo_open": state.combo_open,
			"revert_armed": state._revert_armed,
		},
		"tricks": {
			"tick": tricks._tick,
			"last_dir": tricks._last_dir,
			"last_dir_tick": tricks._last_dir_tick,
			"history": Array(tricks._history).duplicate(true),
			"last_press": tricks._last_press.duplicate(true),
		},
		"combo": {
			"tricks": Array(combo._tricks).duplicate(true),
			"hold_accum": combo._hold_accum,
			"landed_total": combo.landed_total,
			"best_combo": combo.best_combo,
		},
		"special": {"value": special.value, "special": special._special},
		"balance": {
			"angle": balance.angle,
			"velocity": balance.velocity,
			"time": balance._time,
			"difficulty": balance._difficulty,
			"failed": balance._failed,
			"next_nudge_at": balance._next_nudge_at,
			"rng_seed": balance._rng.seed,
			"rng_state": balance._rng.state,
		},
		"spin": {"last_yaw": spin._last_yaw, "total_rad": spin._total_rad},
		"gaps": {"discovered": gaps.discovered.duplicate(true), "pending": gaps._pending.duplicate(true)},
	}


## Puts a snapshot() back. Inputs are untouched. The bail ragdoll is a physics-engine object and cannot be
## stored: a snapshot taken during one starts a fresh ragdoll from the restored velocity.
func restore(d: Dictionary) -> void:
	_end_ragdoll()
	if is_inside_tree():
		global_transform = d["transform"]
	else:
		transform = d["transform"]
	velocity = d["velocity"]
	up_direction = d["up_direction"]
	speed = d["speed"]
	facing = d["facing"]
	board_up = d["board_up"]
	_floor_normal = d["floor_normal"]
	_launch_normal = d["launch_normal"]
	_wall_normal = d["wall_normal"]
	vert_air = d["vert_air"]
	crouch = d["crouch"]
	_crouch_time = d["crouch_time"]
	switch_stance = d["switch_stance"]
	anim = d["anim"]
	anim_time = d["anim_time"]
	anim_trick = (d["anim_trick"] as Dictionary).duplicate(true)
	balance_kind = d["balance_kind"]
	_t = d["t"]
	_seed = d["seed"]
	_tick_count = d["tick"]
	_air_trick_until = d["air_trick_until"]
	_grab_trick = (d["grab_trick"] as Dictionary).duplicate(true)
	_hold_pps = d["hold_pps"]
	_rail = _rail_at(str(d["rail"]))
	_rail_seg = d["rail_seg"]
	_rail_t = d["rail_t"]
	_rail_speed = d["rail_speed"]
	_left_rail = _rail_at(str(d["left_rail"]))
	_left_rail_t = d["left_rail_t"]
	_left_edge = d["left_edge"]
	_transition_ticks = int(d.get("transition_ticks", VERT_MIN_TRANSITION_TICKS))
	_touch_wall_n = d.get("touch_wall_n", Vector3.ZERO)
	_since_bend = float(d.get("since_bend", 1.0))
	_curv = float(d.get("curv", 0.0))
	_roll_in_hold = int(d.get("roll_in_hold", 0))
	_roll_in_dir = d.get("roll_in_dir", Vector3.ZERO)
	_topple_side = float(d.get("topple_side", 0.0))
	_roll_off = bool(d.get("roll_off", false))
	_carve_side = float(d.get("carve_side", 0.0))
	_carve_left = float(d.get("carve_left", 0.0))
	_recent_grind_press = d["recent_grind_press"]
	_recent_revert_press = int(d.get("recent_revert_press", 100))
	_pending_air = (d["pending_air"] as Array).duplicate(true)
	_snap_offset = d["snap_offset"]
	_spawn = d["spawn"]
	_getup_left = d["getup_left"]
	_snap = (d.get("snap", {}) as Dictionary).duplicate(true)
	_snap_hold_up = d.get("snap_hold_up", Vector3.ZERO)
	_lone_spin = float(d.get("lone_spin", 0.0))
	camera_hold = float(d.get("camera_hold", 0.0))
	camera_anchor = d.get("camera_anchor", Vector3.ZERO)
	chord.from_dict(d.get("chord", {}))
	var st: Dictionary = d["state"]
	state.state = int(st["state"]) as SkateState.State
	if d.has("walker"):
		walker.from_dict(d["walker"])
	_set_walk_physics(state.state == SkateState.State.WALK)
	state.time_in_state = st["time_in_state"]
	state.combo_open = st["combo_open"]
	state._revert_armed = st["revert_armed"]
	var ti: Dictionary = d["tricks"]
	tricks._tick = ti["tick"]
	tricks._last_dir = ti["last_dir"]
	tricks._last_dir_tick = ti["last_dir_tick"]
	tricks._history.clear()
	for h: Dictionary in (ti["history"] as Array):
		tricks._history.append(h.duplicate(true))
	tricks._last_press = (ti["last_press"] as Dictionary).duplicate(true)
	var cb: Dictionary = d["combo"]
	combo._tricks.clear()
	for e: Dictionary in (cb["tricks"] as Array):
		combo._tricks.append(e.duplicate(true))
	combo._hold_accum = cb["hold_accum"]
	combo.landed_total = cb["landed_total"]
	combo.best_combo = cb["best_combo"]
	var sp: Dictionary = d["special"]
	special.value = sp["value"]
	special._special = sp["special"]
	var bl: Dictionary = d["balance"]
	balance.angle = bl["angle"]
	balance.velocity = bl["velocity"]
	balance._time = bl["time"]
	balance._difficulty = bl["difficulty"]
	balance._failed = bl["failed"]
	balance._next_nudge_at = bl["next_nudge_at"]
	balance._rng.seed = bl["rng_seed"]
	balance._rng.state = bl["rng_state"]
	var sn: Dictionary = d["spin"]
	spin._last_yaw = sn["last_yaw"]
	spin._total_rad = sn["total_rad"]
	var gp: Dictionary = d["gaps"]
	gaps.discovered = (gp["discovered"] as Dictionary).duplicate(true)
	gaps._pending = (gp["pending"] as Dictionary).duplicate(true)
	if bool(d["ragdoll"]):
		_start_ragdoll()
		_getup_left = d["getup_left"]


func _rail_at(path: String) -> GrindRail:
	if path == "" or not is_inside_tree():
		return null
	return get_node_or_null(NodePath(path)) as GrindRail


# --- scoring ------------------------------------------------------------------------------------------

func _start_balance_trick(t: Dictionary, kind: String) -> void:
	balance_kind = kind
	_seed += 1
	balance.start(_seed, 1.0 + combo.trick_count() * 0.02)
	_hold_pps = int(t.get("points_per_sec", 0))
	_score_trick(t)


func _score_trick(t: Dictionary) -> void:
	var points: int = int(t.get("points", 0))
	var nm: String = str(t.get("name", "Trick"))
	if switch_stance and t.get("kind", "") in ["flip", "grab", "grind", "manual"]:
		nm = "Switch " + nm
	combo.add_trick(str(t.get("id", nm)), nm, points)
	special.add_points(points)
	state.mark_trick()
	if t.get("kind", "") in ["grab", "wallride"] or t.get("hold", false):
		_hold_pps = int(t.get("points_per_sec", _hold_pps))
	anim_trick = t
	var a: String = str(t.get("anim", ""))
	if a != "":
		_set_anim(a)
	trick_started.emit(t)


func _on_combo_landed() -> void:
	var text: String = combo.display_text()
	var pts: int = combo.land()
	gaps.reset_combo()
	combo_landed.emit(pts, text)


func _on_combo_bailed() -> void:
	var text: String = combo.display_text()
	combo.bail()
	special.bail()
	gaps.reset_combo()
	combo_bailed.emit(text)


func _on_state_changed(from: SkateState.State, to: SkateState.State) -> void:
	_restart_gaps_in_zones()
	if from == SkateState.State.GRIND:
		_ev("grind_end")
	if to == SkateState.State.WALK or from == SkateState.State.WALK:
		_set_walk_physics(to == SkateState.State.WALK)
		_ev("dismount" if to == SkateState.State.WALK else "mount")
	match to:
		SkateState.State.GRIND:
			_ev("grind")
		SkateState.State.MANUAL:
			_ev("manual")
		SkateState.State.LIP:
			_ev("lip")
		SkateState.State.WALLRIDE:
			_ev("wallride")
		SkateState.State.BAIL:
			_ev("bail")
		_:
			pass


## A state change inside a gap zone (an ollie landing into a manual on a pad) can start a gap that needs that state.
func _restart_gaps_in_zones() -> void:
	if not is_inside_tree():
		return
	for z: Node in get_tree().get_nodes_in_group("gap_zone"):
		var a := z as Area3D
		if a != null and a.monitoring and a.overlaps_body(self):
			gaps.start_in_zone(str(a.get_meta("zone_id", "")), state.state_name(), _t)


func _on_zone_entered(body: Node3D, area: Area3D) -> void:
	if body != self:
		return
	gaps.enter_zone(str(area.get_meta("zone_id", "")), state.state_name(), _t)


func _on_gap(gap: Dictionary, _first_time: bool) -> void:
	var nm: String = str(gap.get("name", "Gap"))
	var pts: int = int(gap.get("points", 0))
	combo.add_gap(nm, pts)
	special.add_points(pts)
	state.mark_trick()
	gap_hit.emit(nm, pts)


# --- visuals ------------------------------------------------------------------------------------------

func _set_anim(a: String) -> void:
	if a == anim:
		return
	anim = a
	anim_time = 0.0


## Rotate unit vector a toward b by fraction w (safe for unnormalized and opposite inputs).
static func _turn_toward(a: Vector3, b: Vector3, w: float) -> Vector3:
	var an: Vector3 = a.normalized()
	var bn: Vector3 = b.normalized()
	var axis: Vector3 = an.cross(bn)
	if axis.length() < 0.00001:
		return an if an.dot(bn) < 0.0 and w < 0.5 else (bn if an.dot(bn) < 0.0 else an)
	return an.rotated(axis.normalized(), acos(clampf(an.dot(bn), -1.0, 1.0)) * w).normalized()


func _yaw() -> float:
	return atan2(-facing.x, -facing.z)


func _board_forward() -> Vector3:
	return facing


func _update_visual(delta: float) -> void:
	if _visual == null:
		return
	var up: Vector3 = board_up.normalized()
	var fwd: Vector3 = facing.slide(up)
	if fwd.length() < 0.01:
		fwd = _fallback_facing(up)
	fwd = fwd.normalized()
	var target := Basis.looking_at(fwd, up)
	var cur: Basis = _visual.global_transform.basis.orthonormalized()
	var b: Basis = cur.slerp(target, clampf(delta * 18.0, 0.0, 1.0))
	# A rail or lip snap moves the body at once; the visual slides over after it, finishing a 1.3 m snap in about
	# 0.11 s (12 m/s, 0.2 m a frame) and a short one at 8 m/s, so a magnet catch reads as a quick hop, not a teleport.
	_snap_offset = _snap_offset.move_toward(Vector3.ZERO, delta * clampf(_snap_offset.length() / SNAP_EASE_TIME, 8.0, 12.0))
	# The body is a sphere of radius BODY_RADIUS above the origin that never turns; the board sits under its centre
	# along the board's own up, so on a steep wall the wheels touch the wall instead of floating a sphere's width off it.
	var lift: Vector3 = (Vector3.UP - b.y.normalized()) * BODY_RADIUS
	_visual.global_transform = Transform3D(b, global_position + lift + _snap_offset)


func _state_hash() -> int:
	return hash([state.state, snappedf(global_position.x, 0.01), snappedf(global_position.y, 0.01), snappedf(global_position.z, 0.01), combo.landed_total])
