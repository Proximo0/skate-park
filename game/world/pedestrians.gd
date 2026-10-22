class_name Pedestrians
extends Node3D
## A crowd for a level: walkers on sidewalk paths, chatting groups and idlers, each a Pedestrian with its own seeded
## random look (body type, skin, hair, outfit, colours). Drives every walker from one _process with built-in distance
## LOD, measured from the camera (from the skater when there is no camera, as in bots and sims):
##   - hidden beyond hide_range (50 m, they keep walking but are neither drawn nor posed);
##   - posed every frame within NEAR, every 2nd frame to MID, every 4th to the hide range, and not at all while off
##     camera (a person 6 m or closer is always posed);
##   - casting a sun shadow only within shadow_range (18 m): a person costs as many draws in the shadow pass again.
## Levels that roll their own (DtCrowd, the beach merge, the school's SchoolShadowLod, the hills' range limits) keep
## working: they set their own visibility ranges and shadows on the same meshes, and the kit only acts on changes.
## Set shadow_lod = false to leave shadows alone.
##
## Use (in a Level's _ready):
##   var crowd := Pedestrians.new()
##   add_child(crowd)
##   crowd.add_walkers(LanePath.from_points(PackedVector3Array([...]), false, 2.0), 4)
##   crowd.add_group(Vector3(4, 0, 9), 3)        # people chatting in a circle
##   crowd.add_idler(Vector3(-3, 0, 2), 0.0, "phone")
##   # a person with a look and uniform of their own (before the first frame):
##   var guard := crowd.add_idler(Vector3(0, 0, 0), 0.0)
##   guard.look_override = PedBody.guard_look(); guard.uniform = PedBody.UNIFORM_SECURITY
## Budget: 15 to 25 people (about 15 draw calls each, ~0.1 ms of posing each when close). The look templates are freed
## when the crowd leaves the tree.

const NEAR: float = 20.0
const MID: float = 32.0
const HIDE: float = 50.0  ## default hide_range
const SHADOW: float = 18.0  ## default shadow_range
const ALWAYS_POSED: float = 6.0
const KIT_SHADOW_EVERY: int = 6  ## frames between shadow checks
const SCREEN_MARGIN: float = 0.4  ## of the viewport size: how far off screen a person is still posed

@export var seed_value: int = 5
## Distinct looks built for this crowd; people share them with their own garment colours (PedBody.recolour), scale and
## gait. Each look costs about 0.35 s to build, so they are built on a worker thread after the level has loaded
## (synchronously in scripted runs and tests, so captures are deterministic). People appear as their look is ready.
@export var look_pool: int = 6
@export var hide_range: float = HIDE
@export var shadow_range: float = SHADOW
@export var shadow_lod: bool = true
## Build looks on a worker thread (off in scripted runs).
var threaded: bool = true
var people: Array[Pedestrian] = []
var _rng := RandomNumberGenerator.new()
var _frame: int = 0
var _seeded: bool = false
var _looks: Array[SkaterLoadout] = []
var _pool_n: int = 0  ## looks from the shared pool (the rest belong to people with a look_override)
var _override_of: Dictionary = {}  ## Pedestrian -> index into _looks
var _uniform_of: Dictionary = {}  ## index into _looks -> uniform kind
var _templates: Array[Node3D] = []
var _ready_templates: Array[Node3D] = []  ## filled by the worker, under _mutex
var _mutex := Mutex.new()
var _task: int = -1
var _started: bool = false


func _seed() -> void:
	if not _seeded:
		_rng.seed = seed_value
		_seeded = true


func _ready() -> void:
	threaded = threaded and not Flags.is_scripted_run()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_free_templates()


## The look templates live outside the tree: free them (and any the worker finished late) or every run leaks about
## 40 nodes and their instances per look.
func _free_templates() -> void:
	_mutex.lock()
	var late: Array[Node3D] = _ready_templates.duplicate()
	_ready_templates.clear()
	_mutex.unlock()
	for t: Node3D in _templates + late:
		if is_instance_valid(t) and t.get_parent() == null:
			t.free()
	_templates.clear()


## True once every person has a body.
func is_loaded() -> bool:
	for p: Pedestrian in people:
		if not p.has_body():
			return false
	return true


## Builds every look now, on this thread (tests, captures, or a level that wants its crowd at frame one).
func build_now() -> void:
	_plan_looks()
	while _templates.size() < _looks.size():
		_templates.append(_make_template(_templates.size()))
	_dress_waiting()


func _plan_looks() -> void:
	_seed()
	if _looks.is_empty():
		for i: int in maxi(look_pool, 1):
			_looks.append(PedBody.random_look(_rng))
		_pool_n = _looks.size()
		for p: Pedestrian in people:
			if p.look_override != null:
				_override_of[p] = _looks.size()
				if p.uniform != "":
					_uniform_of[_looks.size()] = p.uniform
				_looks.append(p.look_override)


func _make_template(i: int) -> Node3D:
	var b: Node3D = PedBody.build(_looks[i])
	if _uniform_of.has(i):
		PedBody.uniform(b, str(_uniform_of[i]))
	return b


func _build_all() -> void:
	for i: int in _looks.size():
		var b: Node3D = _make_template(i)
		_mutex.lock()
		_ready_templates.append(b)
		_mutex.unlock()


## Gives a body to every person whose look is built.
func _dress_waiting() -> void:
	if _templates.is_empty():
		return
	for i: int in people.size():
		var p: Pedestrian = people[i]
		if p.has_body():
			continue
		var own: bool = _override_of.has(p)
		var k: int = int(_override_of[p]) if own else i % _pool_n
		if k >= _templates.size():
			continue
		var b: Node3D = PedBody.clone(_templates[k])
		var shift: int = 0 if own else i / _pool_n
		if shift > 0:
			PedBody.recolour(b, fposmod(0.17 * float(shift) + 0.31 * float(k), 1.0), 0.85 + 0.1 * float(shift % 3), 0.92 + 0.06 * float(shift % 2))
		p.attach_body(b)


## `count` walkers spread along `path` (open paths are walked back and forth). Returns them.
func add_walkers(path: LanePath, count: int, speed_min: float = 1.05, speed_max: float = 1.4) -> Array[Pedestrian]:
	_seed()
	var out: Array[Pedestrian] = []
	for i: int in count:
		var p: Pedestrian = _new_person()
		p.path = path
		p.s = path.wrap_s(path.length * (float(i) + _rng.randf() * 0.6) / float(maxi(count, 1)))
		p.dir = 1.0 if _rng.randf() < 0.5 or path.loop else -1.0
		p.walk_speed = _rng.randf_range(speed_min, speed_max)
		p.phase = _rng.randf()
		_add(p)
		out.append(p)
	return out


## `count` people standing in a loose circle round `centre`, facing in, chatting.
func add_group(centre: Vector3, count: int) -> Array[Pedestrian]:
	_seed()
	var out: Array[Pedestrian] = []
	var r: float = 0.55 + 0.12 * float(count)
	var a0: float = _rng.randf() * TAU
	for i: int in count:
		var a: float = a0 + TAU * float(i) / float(count) + _rng.randf_range(-0.2, 0.2)
		var pos: Vector3 = centre + Vector3(cos(a), 0.0, sin(a)) * r
		var to: Vector3 = centre - pos
		var p: Pedestrian = _new_person()
		p.base_mode = "chat" if i % 2 == 0 or count == 2 else ("idle" if _rng.randf() < 0.6 else "phone")
		p.position = pos
		p.rotation.y = atan2(-to.x, -to.z)
		_add(p)
		out.append(p)
	return out


## One person standing at `pos` facing `yaw` (radians, 0 = -Z) in `mode` ("idle", "phone", "chat", "wave").
func add_idler(pos: Vector3, yaw: float, mode: String = "idle") -> Pedestrian:
	_seed()
	var p: Pedestrian = _new_person()
	p.base_mode = mode
	p.position = pos
	p.rotation.y = yaw
	_add(p)
	return p


func _new_person() -> Pedestrian:
	var p: Pedestrian = Pedestrian.create(_rng.randi())
	p.name = "Person%d" % people.size()
	p.scale = Vector3.ONE * _rng.randf_range(0.95, 1.05)
	return p


func _add(p: Pedestrian) -> void:
	add_child(p)
	people.append(p)


func _process(delta: float) -> void:
	_frame += 1
	if not _started:
		# start building after the level and the skater are set up (the builders share caches with the main thread)
		_started = true
		_plan_looks()
		if threaded:
			_task = WorkerThreadPool.add_task(_build_all, false, "Pedestrian looks")
		else:
			build_now()
	if _templates.size() < _looks.size() and _task >= 0:
		_mutex.lock()
		_templates.append_array(_ready_templates)
		_ready_templates.clear()
		_mutex.unlock()
		_dress_waiting()
		if _templates.size() >= _looks.size():
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
	var tree: SceneTree = get_tree()
	var sk: Node3D = tree.get_first_node_in_group("skater") as Node3D
	var cam: Camera3D = get_viewport().get_camera_3d()
	var has_eye: bool = cam != null or sk != null
	var eye: Vector3 = cam.global_position if cam != null else (sk.global_position if sk != null else Vector3.ZERO)
	var view: Rect2 = get_viewport().get_visible_rect()
	view = view.grow(maxf(view.size.x, view.size.y) * SCREEN_MARGIN)
	var shadow_check: bool = shadow_lod and has_eye and (_frame % KIT_SHADOW_EVERY) == 0
	for i: int in people.size():
		var p: Pedestrian = people[i]
		var d: float = p.global_position.distance_to(eye) if has_eye else 0.0
		var hide: bool = d > hide_range
		if p.visible == hide:
			p.visible = not hide
		var every: int = 1 if d < NEAR else (2 if d < MID else (4 if d < hide_range else 0))
		if every > 0 and d > ALWAYS_POSED and cam != null and not _on_screen(cam, p, view):
			every = 0
		var pose_now: bool = every > 0 and (_frame + i) % every == 0
		if not p.posed and p.has_body() and not hide:
			pose_now = true  # never show the rest pose
		p.step(delta, sk, pose_now)
		if shadow_check and p.has_body():
			p.set_shadows(d < shadow_range)


func _on_screen(cam: Camera3D, p: Pedestrian, view: Rect2) -> bool:
	var at: Vector3 = p.global_position + Vector3.UP * 0.9
	return not cam.is_position_behind(at) and view.has_point(cam.unproject_position(at))
