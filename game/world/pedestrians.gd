class_name Pedestrians
extends Node3D
## A crowd for a level: walkers on sidewalk paths, chatting groups and idlers, each a Pedestrian with its own seeded
## random look (body type, skin, hair, outfit, colours). Drives every walker from one _process with a distance LOD:
## posed every frame within NEAR, every 2nd frame to MID, every 4th to FAR, hidden beyond HIDE (they keep walking).
##
## Use (in a Level's _ready):
##   var crowd := Pedestrians.new()
##   add_child(crowd)
##   crowd.add_walkers(LanePath.from_points(PackedVector3Array([...]), false, 2.0), 4)
##   crowd.add_group(Vector3(4, 0, 9), 3)        # people chatting in a circle
##   crowd.add_idler(Vector3(-3, 0, 2), 0.0, "phone")
## Budget: 15 to 25 people (about 20 draw calls each, ~0.1 ms of posing each when close).

const NEAR: float = 28.0
const MID: float = 60.0
const FAR: float = 110.0
const HIDE: float = 150.0

@export var seed_value: int = 5
## Distinct looks built for this crowd; people share them with their own garment colours (PedBody.recolour), scale and
## gait. Each look costs about 0.35 s to build, so they are built on a worker thread after the level has loaded
## (synchronously in scripted runs and tests, so captures are deterministic). People appear as their look is ready.
@export var look_pool: int = 6
## Build looks on a worker thread (off in scripted runs).
var threaded: bool = true
var people: Array[Pedestrian] = []
var _rng := RandomNumberGenerator.new()
var _frame: int = 0
var _seeded: bool = false
var _looks: Array[SkaterLoadout] = []
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
		_templates.append(PedBody.build(_looks[_templates.size()]))
	_dress_waiting()


func _plan_looks() -> void:
	_seed()
	if _looks.is_empty():
		for i: int in maxi(look_pool, 1):
			_looks.append(PedBody.random_look(_rng))


func _build_all() -> void:
	for look: SkaterLoadout in _looks:
		var b: Node3D = PedBody.build(look)
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
		var k: int = i % _looks.size()
		if k >= _templates.size():
			continue
		var b: Node3D = PedBody.clone(_templates[k])
		var shift: int = i / _looks.size()
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
	var eye: Vector3 = cam.global_position if cam != null else Vector3.ZERO
	for i: int in people.size():
		var p: Pedestrian = people[i]
		var d: float = p.global_position.distance_to(eye) if cam != null else 0.0
		var hide: bool = d > HIDE
		if p.visible == hide:
			p.visible = not hide
		var every: int = 1 if d < NEAR else (2 if d < MID else (4 if d < FAR else 0))
		var pose_now: bool = every > 0 and (_frame + i) % every == 0
		p.step(delta, sk, pose_now)
