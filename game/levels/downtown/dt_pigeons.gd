class_name DtPigeons
extends MultiMeshInstance3D
## Pigeons on the ground in little huddles: they waddle about and peck, and when the skater rolls close the whole huddle
## bursts up and away, comes back down out of sight, and drifts home a few seconds after the skater has gone. One
## MultiMesh (one draw call) updated from _process; the flyers overhead are Birds flocks (DtLife).

const SCARE: float = 4.5
const SAFE: float = 11.0
const FLY_TIME: float = 2.6
const HOME_DELAY: float = 5.0

var _birds: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0


static func create(seed_value: int = 31) -> DtPigeons:
	var p := DtPigeons.new()
	p.name = "Pigeons"
	p._rng.seed = seed_value
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = DtPigeons._mesh()
	p.multimesh = mm
	p.material_override = Toon.material_vc(Color.WHITE)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## A huddle of `count` pigeons around `centre` (on the floor at centre.y) within `r` metres.
func add_huddle(centre: Vector3, count: int, r: float = 1.6) -> void:
	for i: int in count:
		var a: float = _rng.randf() * TAU
		var d: float = sqrt(_rng.randf()) * r
		var home: Vector3 = centre + Vector3(cos(a) * d, 0.0, sin(a) * d)
		_birds.append({
			"home": home, "pos": home, "yaw": _rng.randf() * TAU, "goal": home, "state": 0, "t": 0.0,
			"vel": Vector3.ZERO, "peck": _rng.randf() * 10.0, "centre": centre, "r": r,
		})


func _ready() -> void:
	multimesh.instance_count = _birds.size()
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for b: Dictionary in _birds:
		lo = lo.min(b["home"] as Vector3)
		hi = hi.max(b["home"] as Vector3)
	if not _birds.is_empty():
		custom_aabb = AABB(lo - Vector3(30, 2, 30), hi - lo + Vector3(60, 30, 60))
	_update(0.0)


func _process(delta: float) -> void:
	_update(delta)


func _update(delta: float) -> void:
	_t += delta
	var sk: Node3D = get_tree().get_first_node_in_group("skater") as Node3D if is_inside_tree() else null
	var sp: Vector3 = sk.global_position if sk != null else Vector3(1e6, 0, 1e6)
	for i: int in _birds.size():
		var b: Dictionary = _birds[i]
		var pos: Vector3 = b["pos"]
		var state: int = int(b["state"])
		b["t"] = float(b["t"]) + delta
		var xf := Transform3D.IDENTITY
		if state == 0:
			# on the ground: waddle toward a goal, peck when there
			var to_sk: Vector3 = Vector3(sp.x - pos.x, 0.0, sp.z - pos.z)
			if to_sk.length() < SCARE and absf(sp.y - pos.y) < 3.0:
				_scatter(b, sp)
				continue
			var goal: Vector3 = b["goal"]
			var to_goal: Vector3 = goal - pos
			if to_goal.length() < 0.05:
				if _rng.randf() < delta * 0.35:
					var c: Vector3 = b["centre"]
					var a: float = _rng.randf() * TAU
					b["goal"] = c + Vector3(cos(a), 0.0, sin(a)) * sqrt(_rng.randf()) * float(b["r"])
			else:
				var step: Vector3 = to_goal.normalized() * minf(0.35 * delta, to_goal.length())
				pos += step
				b["yaw"] = lerp_angle(float(b["yaw"]), atan2(-step.x, -step.z), minf(delta * 8.0, 1.0))
			var pk: float = float(b["peck"]) + _t
			var peck: float = maxf(sin(pk * 5.0), 0.0) * (1.0 if fmod(pk, 4.0) < 2.0 else 0.0)
			var bob: float = absf(sin(_t * 9.0 + float(b["peck"]))) * 0.01 if to_goal.length() > 0.05 else 0.0
			xf = Transform3D(Basis(Vector3.UP, float(b["yaw"])) * Basis(Vector3.RIGHT, -peck * 0.5), pos + Vector3(0, bob, 0))
		elif state == 1:
			# flying off: climb away, then gone
			var v: Vector3 = b["vel"]
			v.y = minf(v.y + 3.0 * delta, 6.0)
			pos += v * delta
			b["vel"] = v
			var flap: float = sin(_t * 30.0 + float(b["peck"])) * 0.3
			xf = Transform3D(Basis(Vector3.UP, float(b["yaw"])) * Basis(Vector3.RIGHT, 0.5) * Basis(Vector3.FORWARD, flap), pos)
			if float(b["t"]) > FLY_TIME:
				b["state"] = 2
				b["t"] = 0.0
		else:
			# away; drift home once the skater has gone
			xf = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), b["home"] as Vector3)
			var home: Vector3 = b["home"]
			if float(b["t"]) > HOME_DELAY and Vector2(sp.x - home.x, sp.z - home.z).length() > SAFE:
				b["state"] = 0
				b["pos"] = home
				b["goal"] = home
				pos = home
				xf = Transform3D(Basis(Vector3.UP, float(b["yaw"])), home)
		b["pos"] = pos
		multimesh.set_instance_transform(i, xf)


func _scatter(b: Dictionary, sp: Vector3) -> void:
	var pos: Vector3 = b["pos"]
	var away: Vector3 = Vector3(pos.x - sp.x, 0.0, pos.z - sp.z)
	if away.length() < 0.01:
		away = Vector3.FORWARD
	away = away.normalized().rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
	b["vel"] = away * _rng.randf_range(4.0, 6.0) + Vector3.UP * _rng.randf_range(2.0, 3.5)
	b["yaw"] = atan2(-away.x, -away.z)
	b["state"] = 1
	b["t"] = 0.0


## A plump grey pigeon, forward -Z, feet at the origin: body, breast, head, beak, tail, folded wings, legs.
static func _mesh() -> ArrayMesh:
	var bt := DtBatch.new()
	var body := Color("8d93a3")
	var dark := Color("5d6372")
	var neck := Color("4f8f7a")
	bt.box(Vector3(0, 0.12, 0.02), Vector3(0.13, 0.11, 0.24), body)
	bt.box(Vector3(0, 0.11, -0.09), Vector3(0.12, 0.1, 0.08), Color("a3a9b8"))
	bt.box(Vector3(0, 0.19, -0.11), Vector3(0.08, 0.08, 0.08), neck)
	bt.box(Vector3(0, 0.235, -0.13), Vector3(0.07, 0.065, 0.075), dark)
	bt.box(Vector3(0, 0.225, -0.18), Vector3(0.02, 0.018, 0.035), Color("e9b26a"))
	bt.box(Vector3(0, 0.13, 0.17), Vector3(0.09, 0.03, 0.1), dark, Basis(Vector3.RIGHT, 0.25))
	for s: float in [-1.0, 1.0]:
		bt.box(Vector3(s * 0.066, 0.135, 0.04), Vector3(0.012, 0.075, 0.2), Color("7a8090"))
		bt.box(Vector3(s * 0.03, 0.035, 0.0), Vector3(0.015, 0.07, 0.015), Color("c96a5a"))
	return bt.mesh()
