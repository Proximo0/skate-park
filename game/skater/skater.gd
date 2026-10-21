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

const GRAVITY := 18.0  ## a bit floatier-than-real arcs (9.8 feels heavy for a cartoon game)
const PUSH_ACCEL := 9.0
const PUSH_MAX := 12.0  ## pushing alone tops out here; slopes can go faster
const MAX_SPEED := 22.0
const BRAKE := 6.0
const ROLL_FRICTION := 0.6
const TURN_RATE := 2.6  ## rad/s at low speed
const TURN_RATE_FAST := 1.7  ## rad/s at MAX_SPEED
const OLLIE_MIN := 6.0
const OLLIE_MAX := 8.5
const CROUCH_FULL := 0.4  ## seconds of crouch for the full ollie
const SPIN_RATE := 7.5  ## rad/s in the air
const AIR_STEER := 1.2
const VERT_NORMAL_Y := 0.35  ## leaving a surface steeper than this, going up, is a vert launch
const GRIND_REACH := 1.1
const GRIND_MIN_SPEED := 3.0
const FLIP_TIME := 0.42
const DOUBLE_FLIP_TIME := 0.68
const WALLRIDE_TIME := 1.2
const LIP_MAX_TIME := 2.5
const SPIN_POINTS_PER_180 := 100
const PUMP_ACCEL := 2.5  ## holding forward on the way down a transition pumps speed, as on a real halfpipe
const PUMP_ACCEL_VERT := 22.0  ## the same pump on a steep (vert) transition: a few back-and-forths build big air
const RAIL_GRAVITY := 10.0  ## down rails speed up a little less than free rolling
const RAIL_FRICTION := 0.5
const EDGE_GRIP := 2.5  ## how much more than gravity's hold a convex bend may ask before the board leaves it
const KILL_Y := -6.0
const PUSH_PLANT := 0.18  ## matches SkaterPoser: first push steps off the tail, then each cycle kicks
const PUSH_CYCLE := 0.6
const PUSH_CONTACT := 0.55

var db: TrickDB
var state := SkateState.new()
var tricks := TrickInput.new()
var combo := Combo.new()
var special := SpecialMeter.new()
var balance := Balance.new()
var gaps: Gaps
var spin := SpinTracker.new()

## Read by the poser, camera and HUD.
var anim: String = "idle_ride"
var anim_trick: Dictionary = {}
var anim_time: float = 0.0
var crouch: float = 0.0  ## 0..1
var switch_stance: bool = false
var balance_kind: String = ""  ## "", "grind", "manual", "lip"
var facing: Vector3 = Vector3.FORWARD  ## horizontal-ish travel direction on the current surface
var board_up: Vector3 = Vector3.UP
var speed: float = 0.0
var vert_air: bool = false

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


func _ready() -> void:
	db = TrickDB.load_default()
	gaps = Gaps.load_default()
	_seed = Flags.seed_value()
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(80.0)
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
	for b: String in ["ollie", "flip", "grab", "grind", "spin_left", "spin_right", "revert", "nollie"]:
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
	_t += delta
	if not scripted_input:
		read_input()
	if Input.is_action_just_pressed("restart"):
		respawn()
		return
	if global_position.y < KILL_Y:
		respawn()
		return
	var requests: Array = tricks.feed(_stick, _just_pressed, _held)
	_recent_grind_press = 0 if _just_pressed.has("grind") else _recent_grind_press + 1
	anim_time += delta
	state.tick(delta)
	special.tick(delta, combo.is_active())
	match state.state:
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
	speed = velocity.length()
	_update_visual(delta)
	combo_changed.emit(combo.display_text(), combo.base_sum(), combo.multiplier())


# --- ground -------------------------------------------------------------------------------------------

func _tick_rolling(delta: float, requests: Array) -> void:
	_ground_move(delta, true)
	if not is_on_floor() or _left_edge:
		_go_airborne(false)
		return
	if _just_pressed.has("revert") and state.event("revert"):
		switch_stance = not switch_stance
		_score_trick({"id": "revert", "name": "Revert", "points": 100, "kind": "revert", "anim": "revert"})
		_set_anim("revert")
		return
	var seq: Array = tricks.manual_sequence()
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
	_handle_ollie(delta)


func _handle_ollie(delta: float) -> void:
	if _held.has("ollie"):
		_crouch_time += delta
		crouch = clampf(_crouch_time / CROUCH_FULL, 0.0, 1.0)
	elif _crouch_time > 0.0:
		var power: float = lerpf(OLLIE_MIN, OLLIE_MAX, crouch)
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
		_set_anim("ollie")
		_enter_air(false)


func _ground_move(delta: float, allow_push: bool) -> void:
	var n: Vector3 = _floor_normal
	var v: Vector3 = velocity.slide(n)
	# keep a facing even when stopped
	if v.length() > 0.5:
		facing = v.normalized()
	else:
		facing = facing.slide(n).normalized() if facing.slide(n).length() > 0.01 else _fallback_facing(n)
	# steering: rotate travel direction around the surface normal
	var turn_rate: float = lerpf(TURN_RATE, TURN_RATE_FAST, clampf(v.length() / MAX_SPEED, 0.0, 1.0))
	var steer: float = -_stick.x * turn_rate * delta * clampf(v.length() / 1.5, 0.25, 1.0)
	if absf(steer) > 0.0:
		facing = facing.rotated(n.normalized(), steer).normalized()
		v = facing * v.length() * (1.0 if v.dot(facing) >= 0.0 else -1.0)
	# gravity along the slope
	v += Vector3.DOWN.slide(n) * GRAVITY * delta
	var along: float = v.dot(facing)
	if allow_push and _stick.y < -0.3 and along < PUSH_MAX and n.y > 0.8:
		if anim != "push" and crouch == 0.0:
			_set_anim("push")
		# Speed comes from the kicks: only while the push foot is on the ground (same timing as the pose).
		along = minf(along + PUSH_ACCEL * _push_pulse() * delta, PUSH_MAX)
	elif _stick.y < -0.3 and n.y < 0.95 and n.y > 0.15 and (v.y < 0.0 or n.y < 0.8):
		# Steeper transition, stronger pump: kickers and banks give a little on the way down, a vert wall pumps
		# both ways (compress in, extend out) so a few back-and-forths build big air.
		along += lerpf(PUMP_ACCEL, PUMP_ACCEL_VERT, clampf((0.95 - n.y) / 0.6, 0.0, 1.0)) * delta
	elif _stick.y > 0.5 and n.y > 0.8 and state.state == SkateState.State.ROLLING:
		along = move_toward(along, 0.0, BRAKE * delta)
	along = move_toward(along, 0.0, ROLL_FRICTION * delta)
	var side: Vector3 = v - facing * v.dot(facing)
	side = side.move_toward(Vector3.ZERO, 25.0 * delta)  # wheels resist sliding sideways
	v = facing * along + side
	if v.length() > MAX_SPEED:
		v = v.normalized() * MAX_SPEED
	if anim == "push" and _stick.y >= -0.3:
		_set_anim("idle_ride")
	if crouch > 0.0 and anim != "crouch":
		_set_anim("crouch")
	# Going up a steep wall: no snap and no push into the surface, so the skater leaves the lip
	# into vert air instead of wrapping over onto the deck.
	var climbing_vert: bool = n.y < VERT_NORMAL_Y and v.y > 0.3
	velocity = v if climbing_vert else v - n * 0.5
	up_direction = n
	floor_snap_length = 0.0 if climbing_vert else 0.6
	move_and_slide()
	floor_snap_length = 0.6
	_left_edge = false
	if is_on_floor():
		var fn: Vector3 = get_floor_normal()
		var was: Vector3 = _floor_normal
		if _leaves_surface(was, fn, v, delta):
			# Over a lip (kicker top, ledge edge, funbox crest at speed): the surface falls away faster than
			# gravity can hold the board to it, so carry on along the old surface into the air.
			_left_edge = true
			velocity = v
			_launch_normal = was
			return
		var spd: float = v.length()
		if spd > 0.5 and (fn - was).dot(v) < 0.0 and fn.dot(was) > 0.8 and velocity.length() < spd:
			# Rolling into a transition (a concave facet edge): ride the curve without losing speed to the
			# facet corner, as a real ramp's smooth curve would.
			velocity = velocity.slide(fn).normalized() * spd
		_floor_normal = fn
		if was.y < VERT_NORMAL_Y and velocity.dot(Vector3.UP) > 0.0:
			_launch_normal = was
		elif fn.y >= VERT_NORMAL_Y:
			_launch_normal = Vector3.UP
		board_up = _turn_toward(board_up, fn, clampf(delta * 20.0, 0.0, 1.0))
	else:
		# leaving a surface: was it the top of a vert ramp?
		_launch_normal = _floor_normal


## True when following the floor from normal `was` to `fn` this tick would need more grip than gravity gives:
## a convex bend (the normal tips toward the travel direction) whose curvature at this speed wants a
## centripetal pull over EDGE_GRIP times gravity's, or riding down onto a near-vertical face.
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
	return spd * spd * curvature > EDGE_GRIP * GRAVITY * maxf(was.y, 0.1)


## 0..1 push strength this tick, from the push anim's time: 0 while stepping off and swinging the foot forward,
## a burst while the foot sweeps the ground. Averages to 1 over a cycle.
func _push_pulse() -> float:
	if anim != "push" or anim_time < PUSH_PLANT:
		return 0.3
	var u: float = fposmod(anim_time - PUSH_PLANT, PUSH_CYCLE) / PUSH_CYCLE
	return 1.0 / PUSH_CONTACT if u < PUSH_CONTACT else 0.0


func _fallback_facing(n: Vector3) -> Vector3:
	var f: Vector3 = (-global_transform.basis.z).slide(n)
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func _tick_manual(delta: float) -> void:
	_ground_move(delta, false)
	combo.add_hold_points(_hold_pps, delta)
	if not balance.update(delta, -_stick.y):
		_bail()
		return
	if not is_on_floor() or _left_edge:
		state.event("fall_off")
		_enter_air(false)
		return
	if _just_pressed.has("ollie"):
		balance_kind = ""
		_ollie(OLLIE_MIN)
		return
	if speed < 0.6:
		balance_kind = ""
		state.event("manual_end")
		_set_anim("idle_ride")


# --- air ----------------------------------------------------------------------------------------------

func _go_airborne(_from_grind: bool) -> void:
	if state.event("fall_off") or state.state == SkateState.State.AIR:
		_enter_air(false)


func _enter_air(_from_rail: bool) -> void:
	balance_kind = ""
	_rail = null
	vert_air = _launch_normal.y < VERT_NORMAL_Y and velocity.y > 0.5
	if vert_air:
		# THUG-style vert: stay in the ramp's plane so the skater comes back down onto the ramp.
		var out: Vector3 = Vector3(_launch_normal.x, 0.0, _launch_normal.z).normalized()
		var lateral: Vector3 = velocity - out * velocity.dot(out)
		lateral.y = 0.0
		velocity = Vector3(0.0, maxf(velocity.y, 0.0) + absf(velocity.dot(out)) * 0.6, 0.0) + lateral * 0.15 + out * 0.7
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
	velocity += Vector3.DOWN * GRAVITY * delta
	# spin: shoulders or stick left/right
	var spin_in: float = 0.0
	if _held.has("spin_left"):
		spin_in += 1.0
	if _held.has("spin_right"):
		spin_in -= 1.0
	if spin_in == 0.0 and absf(_stick.x) > 0.35:
		# THUG-style stick spin, analog: past the steering range it spins, full stick at SPIN_RATE.
		spin_in = -signf(_stick.x) * clampf((absf(_stick.x) - 0.35) / 0.5, 0.3, 1.0)
	if spin_in != 0.0:
		facing = facing.rotated(Vector3.UP, spin_in * SPIN_RATE * delta).normalized()
	elif not vert_air:
		# gentle drift of travel direction toward the stick (air control)
		var hv: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		if hv.length() > 0.5:
			velocity = velocity.rotated(Vector3.UP, -_stick.x * AIR_STEER * delta)
	spin.update(_yaw())
	# auto-align the board toward the predicted landing surface (generous, like THUG)
	var target_up: Vector3 = _predict_landing_normal()
	if vert_air and velocity.y > 0.0:
		target_up = _launch_normal
	board_up = _turn_toward(board_up, target_up, clampf(delta * (12.0 if vert_air else 4.0), 0.0, 1.0))
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
	velocity.y = maxf(velocity.y, -40.0)
	up_direction = Vector3.UP
	floor_snap_length = 0.0
	var impact: Vector3 = velocity
	move_and_slide()
	floor_snap_length = 0.6
	if is_on_wall() and not is_on_floor():
		var wn: Vector3 = get_wall_normal()
		if absf(wn.y) < 0.3 and _recent_grind_press < 10 and speed > 3.0 and state.event("wallride_start"):
			_wall_normal = wn
			_score_trick({"id": "wallride", "name": "Wallride", "points": 250, "kind": "wallride", "anim": "wallride", "points_per_sec": 100})
			return
	if is_on_floor():
		_land(get_floor_normal(), impact)


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
		var dur: float = DOUBLE_FLIP_TIME if bool(t.get("double_tap", false)) else FLIP_TIME
		if t["kind"] == "special":
			dur = 0.9
			special.use_special()
		_air_trick_until = _t + dur
	_score_trick(t)


## impact: the velocity just before touching down (move_and_slide has already removed the part into the floor).
func _land(n: Vector3, impact: Vector3 = Vector3.ZERO) -> void:
	_floor_normal = n
	var hit_v: Vector3 = impact if impact != Vector3.ZERO else velocity
	var judge: Dictionary = Landing.judge(_board_forward(), board_up, hit_v, n)
	var result: String = judge["result"]
	var flip_left: float = _air_trick_until - _t
	if flip_left > 0.2:
		result = "bail"  # landed with the board still mid-flip
	elif flip_left > 0.0 and result == "clean":
		result = "sketchy"  # caught it late
	var spins: int = spin.spins180()
	if result == "bail":
		_bail()
		landed.emit(result)
		return
	if spins > 0:
		_score_trick({"id": "spin_%d" % spins, "name": spin.label() + " Spin", "points": SPIN_POINTS_PER_180 * spins, "kind": "spin", "anim": ""})
	if bool(judge["switch"]):
		switch_stance = not switch_stance
	# keep speed, now along the surface
	var v: Vector3 = hit_v.slide(n)
	var keep: float = 0.97 if result == "clean" else 0.8
	if vert_air and result == "clean" and v.length() > 0.5:
		# Clean vert re-entry: the fall turns into roll along the transition with no loss (as in THUG), so
		# pumping on each pass builds height instead of bleeding it away.
		v = v.normalized() * hit_v.length()
		keep = 1.0
	velocity = (v * keep).limit_length(MAX_SPEED)
	if v.length() > 0.5:
		facing = v.normalized()
	vert_air = false
	_grab_trick = {}
	var seq: Array = tricks.manual_sequence()
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
	if speed < GRIND_MIN_SPEED * 0.5 and state.state == SkateState.State.ROLLING:
		return false
	var best: GrindRail = null
	var best_hit: Dictionary = {}
	var best_d: float = GRIND_REACH
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
	var floor_speed: float = GRIND_MIN_SPEED * 0.5
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
	_rail_speed += -RAIL_GRAVITY * tan.y * delta  # downhill rails speed up, uphill ones slow and slide back
	_rail_speed = move_toward(_rail_speed, 0.0, RAIL_FRICTION * delta)
	_rail_speed = clampf(_rail_speed, -MAX_SPEED, MAX_SPEED)
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
		_bail()
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
		_bail()
		return
	if _just_pressed.has("ollie") or _just_pressed.has("grind") or balance.time_held() > LIP_MAX_TIME:
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
	velocity += Vector3.DOWN * GRAVITY * 0.3 * delta
	velocity += -_wall_normal * 0.5  # stay against the wall
	up_direction = Vector3.UP
	move_and_slide()
	if _just_pressed.has("ollie"):
		velocity += _wall_normal * 3.5 + Vector3.UP * 6.0
		state.event("ollie")
		_score_trick({"id": "wallie", "name": "Wallie", "points": 200, "kind": "wallride", "anim": "ollie"})
		_enter_air(false)
		return
	if state.time_in_state > WALLRIDE_TIME or not is_on_wall() or is_on_floor():
		state.event("fall_off")
		velocity += _wall_normal * 1.0
		_enter_air(false)
		if is_on_floor():
			_land(get_floor_normal())


# --- bail ---------------------------------------------------------------------------------------------

func _bail() -> void:
	balance_kind = ""
	_rail = null
	_grab_trick = {}
	_air_trick_until = 0.0
	vert_air = false
	state.event("bail")
	_set_anim("bail_fall")
	bailed.emit()


func _tick_bail(delta: float) -> void:
	velocity += Vector3.DOWN * GRAVITY * delta
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
	global_transform = _spawn
	velocity = Vector3.ZERO
	_snap_offset = Vector3.ZERO
	facing = -_spawn.basis.z
	board_up = Vector3.UP
	_floor_normal = Vector3.UP
	if state.state != SkateState.State.ROLLING:
		state = SkateState.new()
		state.combo_landed.connect(_on_combo_landed)
		state.combo_bailed.connect(_on_combo_bailed)
		state.state_changed.connect(_on_state_changed)
	combo.bail()
	gaps.reset_combo()
	_set_anim("idle_ride")


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


func _on_state_changed(_from: SkateState.State, _to: SkateState.State) -> void:
	pass


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
	_snap_offset = _snap_offset.move_toward(Vector3.ZERO, delta * 8.0)
	_visual.global_transform = Transform3D(b, global_position + _snap_offset)


func _state_hash() -> int:
	return hash([state.state, snappedf(global_position.x, 0.01), snappedf(global_position.y, 0.01), snappedf(global_position.z, 0.01), combo.landed_total])
