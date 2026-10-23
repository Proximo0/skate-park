class_name ReplayDirector
extends Node
## Player-facing replay and photo mode. While the game runs it samples the skater's look every frame into a
## ReplayBuffer (BUFFER_SECONDS): the skater's transform plus the local transforms of the Visual root, body, board,
## the code rig's joints (SkaterPoser.JOINTS) and the sway pivots, which is everything the VRM retarget, the shoes
## and the board read. The flight recorder (PhysicsRecorder) keeps the physics side; it has no pose, so the replay
## keeps its own visual track and the sim (tests/sim/sim_replay.gd) checks the two agree.
##
## R (the "replay" action) or holding R3 for HOLD_R3 s replays the last REPLAY_SECONDS: the tree pauses, the real
## skater's nodes are driven from the buffer like a puppet (its Visual runs while paused so the VRM bones follow),
## and a replay camera takes over with auto cinematic cuts (ReplayShots: chase, low angle, wide) or a picked fixed
## camera or a free orbit. Cross pauses, L1/R1 scrub, Square cycles 1x / 1/2x / 1/4x, Circle cycles the camera,
## Triangle saves a PNG to user://photos/ with a toast, Start / R / Back exits. Exiting puts every node, the camera,
## the HUD layers, the pause state and the time scale back exactly as they were.
##
## The best combos (BEST_KEEP, by points) are clipped from the buffer COMBO_AFTER s after they land, so the results
## screen can offer "Watch Replay" of the run's best combo (best_clip_for / play_clip).
## Cost while not replaying: one 60 Hz copy of about 40 transforms into a packed ring; nothing is allocated.

signal started
signal finished

const ACTION: StringName = &"replay"
const GROUP: StringName = &"replay_director"
const REPLAY_SECONDS: float = 10.0
const BUFFER_SECONDS: float = 20.0
const SAMPLE_HZ: float = 60.0
const HOLD_R3: float = 0.5
const SPEEDS: Array[float] = [1.0, 0.5, 0.25]
const SCRUB_RATE: float = 1.5  ## clip seconds per real second at full stick
const COMBO_BEFORE: float = 1.5
const COMBO_AFTER: float = 1.0
const MAX_CLIP: float = 14.0
const BEST_KEEP: int = 3
const PHOTO_DIR: String = "user://photos"
const MAX_SWAY: int = 32
const BODY_MID: float = 0.9  ## m above the deck the camera looks at when there is no hips joint
const CAM_RATE: float = 6.0
const LOOK_RATE: float = 10.0
const MIN_CAM_DIST: float = 1.2
const WORLD_MASK: int = 1

var photo_dir: String = PHOTO_DIR
var buffer: ReplayBuffer = null
var clock: float = 0.0  ## recording clock: game seconds while unpaused and not replaying
var active: bool = false
var playing: bool = true
var speed_index: int = 0
var cam_mode: int = -1  ## -1 auto cuts, else a ReplayShots.Shot
var play_t: float = 0.0
var clip: ReplayBuffer = null
var allow_in_scripted: bool = false  ## captures and sims turn the hotkeys on; bots and goldens never replay
var last_photo: String = ""

var _skater: Node3D = null
var _recorder: Node = null
var _tracks: Array[Node3D] = []
var _hips: Node3D = null
var _last_sample: float = -INF
var _best: Array = []  ## {"points", "text", "clip"} best first
var _pending: Dictionary = {}
var _combo_start: float = -1.0
var _r3_t: float = 0.0
var _saved: Dictionary = {}
var _cam: Camera3D = null
var _overlay: ReplayOverlay = null
var _cuts: Array = []
var _seg: int = -1  ## cut index (or fixed-camera segment) the camera was placed for
var _shot: int = ReplayShots.Shot.CHASE
var _tripod: Vector3 = Vector3.ZERO
var _cam_pos: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
var _dir: Vector3 = Vector3.FORWARD
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = 0.35
var _orbit_dist: float = 4.0
var _title: String = ""
var _on_done: Callable = Callable()
var _photo_busy: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000  # after the poser and the sway: sample the finished pose


func _ready() -> void:
	add_to_group(GROUP)
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		var k := InputEventKey.new()
		k.keycode = KEY_R
		InputMap.action_add_event(ACTION, k)
	_overlay = ReplayOverlay.new()
	_overlay.name = "ReplayOverlay"
	add_child(_overlay)


## The game scene's director (or null).
static func find(tree: SceneTree) -> ReplayDirector:
	return tree.get_first_node_in_group(GROUP) as ReplayDirector if tree != null else null


func bind(skater: Node3D, recorder: Node = null) -> void:
	if _skater != null and is_instance_valid(_skater):
		for pair: Array in _signals():
			if _skater.is_connected(pair[0], pair[1]):
				_skater.disconnect(pair[0], pair[1])
	_skater = skater
	_recorder = recorder
	_collect_tracks()
	for pair: Array in _signals():
		if _skater.has_signal(pair[0]):
			_skater.connect(pair[0], pair[1])


func _signals() -> Array:
	return [["trick_started", _on_trick], ["combo_landed", _on_combo_landed], ["combo_bailed", _on_combo_bailed]]


## Tracks: 0 the skater (global), then local transforms of Visual, the body, the board, the joints, the sway pivots.
func _collect_tracks() -> void:
	_tracks = [_skater]
	_hips = null
	var visual: Node3D = _skater.get_node_or_null("Visual") as Node3D
	if visual != null:
		_tracks.append(visual)
		var body: Node3D = visual.get_node_or_null("SkaterBody") as Node3D
		var board: Node3D = visual.get_node_or_null("Skateboard") as Node3D
		if body != null:
			_tracks.append(body)
		if board != null:
			_tracks.append(board)
		if body != null:
			for j: String in SkaterPoser.JOINTS:
				var n: Node3D = body.find_child(j, true, false) as Node3D
				if n != null and not _tracks.has(n):
					_tracks.append(n)
					if j == "Hips":
						_hips = n
		var sway: int = 0
		for pat: String in [SecondaryMotion.HAIR_PREFIX + "*", SecondaryMotion.BODY_PREFIX + "*"]:
			for n: Node in visual.find_children(pat, "Node3D", true, false):
				if sway < MAX_SWAY and not _tracks.has(n):
					_tracks.append(n as Node3D)
					sway += 1
	buffer = ReplayBuffer.new(_tracks.size(), int(BUFFER_SECONDS * SAMPLE_HZ) + 8)
	_last_sample = -INF
	_best.clear()
	_pending.clear()


func _tracks_valid() -> bool:
	for n: Node3D in _tracks:
		if not is_instance_valid(n):
			return false
	return true


## The tracks' current transforms (track 0 global, the rest local).
func capture_now() -> Array:
	var out: Array = []
	for i: int in _tracks.size():
		out.append(_tracks[i].global_transform if i == 0 else _tracks[i].transform)
	return out


func _flags_now() -> int:
	var f: int = 0
	var st: Object = _skater.get("state") as Object
	if st != null:
		match int(st.get("state")):
			SkateState.State.AIR:
				f |= ReplayBuffer.FLAG_AIR
			SkateState.State.GRIND:
				f |= ReplayBuffer.FLAG_GRIND
			SkateState.State.MANUAL:
				f |= ReplayBuffer.FLAG_MANUAL
			SkateState.State.BAIL:
				f |= ReplayBuffer.FLAG_BAIL
	return f


## Records one frame now (normally called from _process at SAMPLE_HZ; sims call it straight).
func sample_now() -> void:
	if _skater == null or not _skater.is_inside_tree():
		return
	if not _tracks_valid():
		_collect_tracks()
	buffer.push(clock, capture_now(), float(_skater.get("speed")), _flags_now())
	_last_sample = clock


func _process(delta: float) -> void:
	if active:
		_tick_replay(delta)
		return
	if _skater == null or not is_instance_valid(_skater) or get_tree().paused:
		_r3_t = 0.0
		return
	clock += delta
	if clock - _last_sample >= 1.0 / SAMPLE_HZ - 0.0005:
		sample_now()
	if not _pending.is_empty() and clock >= float(_pending["due"]):
		_finalize_pending()
	if Flags.is_scripted_run() and not allow_in_scripted:
		return
	if InputMap.has_action(ACTION) and Input.is_action_just_pressed(ACTION):
		play_last()
		return
	if Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_STICK):
		_r3_t += delta / maxf(Engine.time_scale, 0.01)
		if _r3_t >= HOLD_R3:
			_r3_t = -INF  # one replay per hold
			play_last()
	else:
		_r3_t = 0.0


# --- best combos -------------------------------------------------------------------------------------------

func _on_trick(_tr: Dictionary) -> void:
	if _combo_start < 0.0:
		_combo_start = clock


func _on_combo_landed(points: int, text: String) -> void:
	var from_t: float = (_combo_start if _combo_start >= 0.0 else clock - 3.0) - COMBO_BEFORE
	_combo_start = -1.0
	if points <= 0:
		return
	if not _pending.is_empty():
		_finalize_pending()
	_pending = {"points": points, "text": text, "from": from_t, "due": clock + COMBO_AFTER}


func _on_combo_bailed(_text: String) -> void:
	_combo_start = -1.0


func _finalize_pending() -> void:
	if _pending.is_empty():
		return
	var p: Dictionary = _pending
	_pending = {}
	var pts: int = int(p["points"])
	if _best.size() >= BEST_KEEP and pts <= int((_best[_best.size() - 1] as Dictionary)["points"]):
		return
	var to_t: float = minf(clock, float(p["due"]))
	var from_t: float = maxf(float(p["from"]), to_t - MAX_CLIP)
	var c: ReplayBuffer = buffer.clip(from_t, to_t)
	if c.size() < 2:
		return
	_best.append({"points": pts, "text": str(p["text"]), "clip": c})
	_best.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["points"]) > int(b["points"]))
	while _best.size() > BEST_KEEP:
		_best.pop_back()


## The kept clip of a combo worth exactly `points` ({"points", "text", "clip"}), or {} when there is none.
## A combo that landed less than COMBO_AFTER s ago is clipped now.
func best_clip_for(points: int) -> Dictionary:
	if not _pending.is_empty():
		_finalize_pending()
	for e: Dictionary in _best:
		if int(e["points"]) == points:
			return e
	return {}


func best_entries() -> Array:
	return _best


# --- playback ----------------------------------------------------------------------------------------------

## Replays the newest REPLAY_SECONDS. Returns false when there is not enough recorded yet.
func play_last(seconds: float = REPLAY_SECONDS) -> bool:
	if active or buffer == null or buffer.size() < 10:
		return false
	return play_clip(buffer.last_seconds(seconds), "LAST %d SECONDS" % int(round(minf(seconds, buffer.duration()))))


## Plays `c` titled `title`; on_done runs after the replay closes and everything is restored.
func play_clip(c: ReplayBuffer, title: String, on_done: Callable = Callable()) -> bool:
	if active or c == null or c.size() < 2 or _skater == null or c.track_count != _tracks.size() or not _tracks_valid():
		return false
	clip = c
	_title = title
	_on_done = on_done
	_save_state()
	get_tree().paused = true
	Engine.time_scale = 1.0
	var visual: Node = _tracks[1] if _tracks.size() > 1 else null
	if visual != null:
		(visual as Node).process_mode = Node.PROCESS_MODE_ALWAYS  # the VRM retarget and spring bones keep running
	_hide_layers()
	_cam = Camera3D.new()
	_cam.name = "ReplayCamera"
	var prev: Camera3D = _saved.get("camera") as Camera3D
	if prev != null:
		_cam.environment = prev.environment
		_cam.attributes = prev.attributes
		_cam.cull_mask = prev.cull_mask
		_cam.far = prev.far
	_cam.near = 0.05
	add_child(_cam)
	_cam.make_current()
	_cuts = ReplayShots.plan(clip.start_time(), clip.end_time(), clip.edges(ReplayBuffer.FLAG_AIR))
	play_t = clip.start_time()
	playing = true
	speed_index = 0
	cam_mode = -1
	_seg = -1
	active = true
	_overlay.open(title)
	_apply(play_t)
	_update_camera(0.0)
	_show_state()
	started.emit()
	return true


## Closes the replay and puts everything back.
func stop() -> void:
	if not active:
		return
	active = false
	_restore_state()
	if _cam != null:
		_cam.queue_free()
		_cam = null
	_overlay.visible = false
	clip = null
	finished.emit()
	if _on_done.is_valid():
		var cb: Callable = _on_done
		_on_done = Callable()
		cb.call()


func _save_state() -> void:
	var vis: Node = _tracks[1] if _tracks.size() > 1 else null
	_saved = {
		"paused": get_tree().paused, "time_scale": Engine.time_scale, "camera": get_viewport().get_camera_3d(),
		"xforms": capture_now(), "visual_mode": vis.process_mode if vis != null else Node.PROCESS_MODE_INHERIT,
		"layers": [],
	}


func _restore_state() -> void:
	var xs: Array = _saved.get("xforms", [])
	if xs.size() == _tracks.size() and _tracks_valid():
		_set_tracks(xs)
	if _tracks.size() > 1 and is_instance_valid(_tracks[1]):
		_tracks[1].process_mode = int(_saved.get("visual_mode", Node.PROCESS_MODE_INHERIT)) as Node.ProcessMode
	for l: Variant in _saved.get("layers", []):
		if is_instance_valid(l):
			(l as CanvasLayer).visible = true
	var prev: Variant = _saved.get("camera")
	if prev != null and is_instance_valid(prev):
		(prev as Camera3D).make_current()
	Engine.time_scale = float(_saved.get("time_scale", 1.0))
	get_tree().paused = bool(_saved.get("paused", false))
	_saved = {}


## Hides every visible CanvasLayer in the scene but the overlay (HUD, goals, effects) and remembers them.
func _hide_layers() -> void:
	var hidden: Array = []
	for n: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var l := n as CanvasLayer
		if l == _overlay or not l.visible:
			continue
		l.visible = false
		hidden.append(l)
	_saved["layers"] = hidden


func _set_tracks(xs: Array) -> void:
	_skater.global_transform = xs[0]
	for i: int in range(1, _tracks.size()):
		_tracks[i].transform = xs[i]


func _apply(t: float) -> void:
	_set_tracks(clip.sample(t))


func _tick_replay(delta: float) -> void:
	if clip == null:
		return
	var scrub: float = Input.get_axis(&"spin_left", &"spin_right") if InputMap.has_action(&"spin_left") else 0.0
	if absf(scrub) > 0.15:
		play_t += scrub * SCRUB_RATE * delta
	elif playing:
		play_t += delta * SPEEDS[speed_index]
	if play_t > clip.end_time():
		if playing and absf(scrub) <= 0.15:
			play_t = clip.start_time()  # loop
			_seg = -1
		else:
			play_t = clip.end_time()
	play_t = maxf(play_t, clip.start_time())
	if cam_mode == ReplayShots.Shot.FREE:
		_orbit_input(delta)
	_apply(play_t)
	_update_camera(delta)
	_show_state()


func _orbit_input(delta: float) -> void:
	if not InputMap.has_action(&"move_left"):
		return
	var st := Vector2(Input.get_axis(&"move_left", &"move_right"), Input.get_axis(&"move_up", &"move_down"))
	_orbit_yaw -= st.x * 2.2 * delta
	_orbit_pitch = clampf(_orbit_pitch + st.y * 1.6 * delta, -0.15, 1.35)
	var zoom: float = 0.0
	if InputMap.has_action(&"nollie") and Input.is_action_pressed(&"nollie"):
		zoom -= 1.0
	if InputMap.has_action(&"revert") and Input.is_action_pressed(&"revert"):
		zoom += 1.0
	_orbit_dist = clampf(_orbit_dist + zoom * 3.0 * delta, 1.6, 12.0)


func _show_state() -> void:
	var label: String = ReplayShots.NAMES[_shot]
	if cam_mode < 0:
		label = "AUTO  " + label
	_overlay.show_state(play_t - clip.start_time(), clip.duration(), label, SPEEDS[speed_index], not playing,
		cam_mode == ReplayShots.Shot.FREE)


func _input(event: InputEvent) -> void:
	if not active:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	get_viewport().set_input_as_handled()  # nothing else (pause menu, results card, debug keys) sees it
	if event.is_echo():
		return
	if _pressed(event, &"pause") or _pressed(event, &"restart") or _pressed(event, ACTION):
		stop.call_deferred()
	elif _pressed(event, &"ollie"):
		playing = not playing
	elif _pressed(event, &"flip"):
		speed_index = (speed_index + 1) % SPEEDS.size()
	elif _pressed(event, &"grab"):
		cycle_camera()
	elif _pressed(event, &"grind"):
		save_photo()


func _pressed(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action)


## Auto -> chase -> low -> wide -> free -> auto.
func cycle_camera() -> void:
	cam_mode = cam_mode + 1
	if cam_mode > ReplayShots.Shot.FREE:
		cam_mode = -1
	_seg = -1
	if cam_mode == ReplayShots.Shot.FREE and _cam != null:
		var off: Vector3 = _cam.global_position - _focus()
		_orbit_dist = clampf(off.length(), 2.0, 10.0)
		_orbit_yaw = atan2(off.x, off.z)
		_orbit_pitch = clampf(asin(clampf(off.y / maxf(off.length(), 0.01), -1.0, 1.0)), -0.15, 1.35)


# --- camera ------------------------------------------------------------------------------------------------

## The point the camera frames: the hips, or the body middle along the board's up.
func _focus() -> Vector3:
	if _hips != null and is_instance_valid(_hips) and _hips.is_inside_tree():
		return _hips.global_position
	var g: Transform3D = _skater.global_transform
	if _tracks.size() > 1:
		g = g * _tracks[1].transform
	return g.origin + g.basis.y.normalized() * BODY_MID


func _travel_dir(t: float) -> Vector3:
	var a: Vector3 = clip.sample_track(t - 0.12, 0).origin
	var b: Vector3 = clip.sample_track(t + 0.12, 0).origin
	var d: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	if d.length() > 0.05:
		return d.normalized()
	var fwd: Vector3 = -clip.sample_track(t, 0).basis.z
	fwd.y = 0.0
	return fwd.normalized() if fwd.length() > 0.01 else _dir


func _update_camera(delta: float) -> void:
	if _cam == null:
		return
	var focus: Vector3 = _focus()
	_dir = _travel_dir(play_t)
	var seg: int = ReplayShots.cut_index(_cuts, play_t)
	var snap: bool = seg != _seg
	if snap:
		_seg = seg
		_place_shot(seg)
	elif ReplayShots.RESTAND[_shot] > 0.0 and focus.distance_to(_tripod) > ReplayShots.RESTAND[_shot]:
		_stand(_ahead_t())  # the rider left the tripod behind: re-cut ahead of them
		snap = true
	var goal: Vector3
	match _shot:
		ReplayShots.Shot.LOW, ReplayShots.Shot.WIDE:
			goal = _tripod
		ReplayShots.Shot.FREE:
			goal = _clear(focus, ReplayShots.orbit(focus, _orbit_yaw, _orbit_pitch, _orbit_dist))
		_:
			goal = _clear(focus, ReplayShots.chase(focus, _dir))
	if snap or _shot != ReplayShots.Shot.CHASE:
		_cam_pos = goal
	else:
		_cam_pos = _cam_pos.lerp(goal, 1.0 - exp(-CAM_RATE * delta))
	_look = focus if snap else _look.lerp(focus, 1.0 - exp(-LOOK_RATE * delta))
	_cam.fov = ReplayShots.FOV[_shot]
	_cam.global_position = _cam_pos
	var to: Vector3 = _look - _cam_pos
	if to.length() > 0.01:
		var up: Vector3 = Vector3.UP if absf(to.normalized().y) < 0.98 else Vector3.FORWARD
		_cam.look_at(_look, up)


## Picks segment seg's shot (the auto plan's, or the fixed camera) and stands a tripod for it.
func _place_shot(seg: int) -> void:
	_shot = cam_mode if cam_mode >= 0 else int((_cuts[seg] as Dictionary)["shot"])
	if _shot != ReplayShots.Shot.LOW and _shot != ReplayShots.Shot.WIDE:
		return
	var t0: float = float((_cuts[seg] as Dictionary)["t"])
	var t1: float = float((_cuts[seg + 1] as Dictionary)["t"]) if seg + 1 < _cuts.size() else clip.end_time()
	t0 = maxf(t0, play_t)
	var mid_t: float = lerpf(t0, t1, 0.5) if t1 > t0 else play_t
	if _shot == ReplayShots.Shot.LOW:
		mid_t = minf(t0 + ReplayShots.LOW_AIM, maxf(t1, t0))
	if cam_mode >= 0:
		mid_t = _ahead_t()  # a picked camera stands for where the rider is about to be, not the segment's middle
	_stand(mid_t)


## The clip time when the rider will be RESTAND_AHEAD m further along (at the current speed, at most 0.6 s on).
func _ahead_t() -> float:
	return play_t + minf(ReplayShots.RESTAND_AHEAD / maxf(clip.speed_sample(play_t), 0.1), 0.6)


## Stands the current tripod shot for the rider's spot at time at_t (the other side of the line if a wall is in
## the way; a chase if both sides are blocked).
func _stand(at_t: float) -> void:
	var mid_t: float = clampf(at_t, clip.start_time(), clip.end_time())
	var mid: Vector3 = clip.sample_track(mid_t, 0).origin + Vector3.UP * 0.5
	var dir: Vector3 = _travel_dir(mid_t)
	for side: float in [1.0, -1.0]:
		var p: Vector3 = ReplayShots.tripod(_shot, mid, dir, side)
		if _blocked(mid, p) < 0.0:
			_tripod = p
			return
	var p2: Vector3 = ReplayShots.tripod(_shot, mid, dir, 1.0)
	_tripod = _clear(mid, p2)
	if _tripod.distance_to(mid) < 2.0:
		_shot = ReplayShots.Shot.CHASE


## Distance along focus -> pos where the world blocks it, or -1 when clear.
func _blocked(focus: Vector3, pos: Vector3) -> float:
	var world: World3D = _skater.get_world_3d() if _skater != null else null
	if world == null:
		return -1.0
	var q := PhysicsRayQueryParameters3D.create(focus, pos, WORLD_MASK)
	if _skater is CollisionObject3D:
		q.exclude = [(_skater as CollisionObject3D).get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return -1.0
	return focus.distance_to(hit["position"] as Vector3)


## pos pulled in toward focus so a wall never sits between them.
func _clear(focus: Vector3, pos: Vector3) -> Vector3:
	var d: float = _blocked(focus, pos)
	if d < 0.0:
		return pos
	var dir: Vector3 = (pos - focus).normalized()
	return focus + dir * maxf(d - 0.3, MIN_CAM_DIST)


# --- photos ------------------------------------------------------------------------------------------------

## Saves the current view (without the overlay) as user://photos/photo_<datetime>.png and toasts the path.
## Returns the path, or "" when the renderer gives no image (headless).
func save_photo() -> String:
	if _photo_busy:
		return ""
	_photo_busy = true
	_overlay.set_chrome(false)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_overlay.set_chrome(true)
	_photo_busy = false
	if img == null or img.is_empty():
		_overlay.toast("Photo failed: no image from the renderer")
		return ""
	DirAccess.make_dir_recursive_absolute(photo_dir)
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path: String = "%s/photo_%s_%03d.png" % [photo_dir, stamp, Time.get_ticks_msec() % 1000]
	var err: Error = img.save_png(path)
	if err != OK:
		_overlay.toast("Photo failed (%d)" % err)
		return ""
	last_photo = path
	_overlay.flash()
	_overlay.toast("Photo saved: " + ProjectSettings.globalize_path(path))
	return path
