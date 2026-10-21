class_name SecondaryMotion
extends Node
## Visual-only secondary motion: hair and bust sway on damped springs. Never part of the physics snapshot.
## bind() finds every Node3D named "HairSway_*" or "BodySway_*" under the visual root. Each tick the world
## acceleration of the pivot's attach point (plus gravity, seen in the parent's frame so body rotation counts)
## drives a spring. Hair swings like a pendulum on two axes, chains (HairSway_X, then a child HairSway_X2, ...)
## lag down the chain. Bust pivots get a few mm of offset and at most about 3 degrees. Everything is clamped.
## Fixed 1/60 s steps (4 sub-steps each) keep it deterministic; a jump in position resets it (teleport, respawn).

const HAIR_PREFIX: String = "HairSway_"
const BODY_PREFIX: String = "BodySway_"
const DT: float = 1.0 / 60.0
const SUBSTEPS: int = 4
const GRAVITY: float = 9.8
const MAX_ACCEL: float = 60.0  ## m/s^2, input clamp (landings, pose snaps)
const ACCEL_SMOOTH: float = 0.5  ## one-pole blend per tick; poses change per rendered frame
const TELEPORT_DIST: float = 2.0  ## attach point moving farther than this in one tick resets the state

const HAIR_GAIN: float = 0.6
const HAIR_FREQ: float = 2.2  ## Hz at chain depth 0; each link down is a bit slower
const HAIR_DAMP: float = 0.3
const SIDE_BACK: float = 35.0
const SIDE_FWD: float = 25.0
const SIDE_OUT: float = 30.0
const SIDE_IN: float = 6.0  ## inward swing toward the head, kept tiny so locks never cut into it
## Ponytail chain, per link: degrees back / forward / sideways. Totals 60 back and 35 forward.
const CHAIN_BACK: Array[float] = [30.0, 18.0, 12.0]
const CHAIN_FWD: Array[float] = [18.0, 10.0, 7.0]
const CHAIN_SIDE: Array[float] = [20.0, 12.0, 8.0]

const BUST_FREQ: float = 7.0
const BUST_DAMP: float = 0.75
const BUST_GAIN: float = 0.0004  ## metres of offset per m/s^2
const BUST_MAX_OFFSET: float = 0.012  ## 1.2 cm
const BUST_MAX_TILT: float = 3.0  ## degrees

var hair_enabled: bool = true
var body_enabled: bool = true
var follow_settings: bool = true  ## read the toggles from GameSettings every tick

var _pivots: Array[Pivot] = []


class Pivot extends RefCounted:
	var node: Node3D
	var is_bust: bool = false
	var rest: Transform3D = Transform3D.IDENTITY
	var depth: int = 0
	var side: float = 0.0  ## -1 or 1 for a side lock (sign of its rest x), 0 for centre hair
	var pos: Vector3 = Vector3.ZERO  ## hair: x/z angle (rad) in .x/.z; bust: offset metres
	var vel: Vector3 = Vector3.ZERO
	var prev_p: Vector3 = Vector3.ZERO
	var prev_v: Vector3 = Vector3.ZERO
	var accel: Vector3 = Vector3.ZERO
	var samples: int = 0
	var applied: bool = false  ## true while the node is off its rest pose


func _ready() -> void:
	process_priority = 100  # after the skater and the poser have moved this tick


## Finds the pivots under the visual root (by name prefix, any depth). Safe to call again after a rebuild.
func bind(visual_root: Node3D) -> void:
	_pivots.clear()
	if visual_root == null:
		return
	_collect(visual_root)


func pivot_count() -> int:
	return _pivots.size()


func pivot_nodes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for p: Pivot in _pivots:
		out.append(p.node)
	return out


func _collect(n: Node) -> void:
	for c: Node in n.get_children():
		var nd := c as Node3D
		if nd != null and (nd.name.begins_with(HAIR_PREFIX) or nd.name.begins_with(BODY_PREFIX)):
			var p := Pivot.new()
			p.node = nd
			p.is_bust = nd.name.begins_with(BODY_PREFIX)
			p.rest = nd.transform
			if not p.is_bust:
				var d: int = 0
				var a: Node = nd.get_parent()
				while a != null and a is Node3D and a.name.begins_with(HAIR_PREFIX):
					d += 1
					a = a.get_parent()
				p.depth = d
				if d == 0 and absf(nd.position.x) > 0.02:
					p.side = signf(nd.position.x)
			_pivots.append(p)
		_collect(c)


## Back to the rest pose with no motion. Call after a teleport, respawn or replay restore.
func reset() -> void:
	for p: Pivot in _pivots:
		_clear(p)
		if is_instance_valid(p.node):
			p.node.transform = p.rest
		p.applied = false


func _clear(p: Pivot) -> void:
	p.pos = Vector3.ZERO
	p.vel = Vector3.ZERO
	p.prev_v = Vector3.ZERO
	p.accel = Vector3.ZERO
	p.samples = 0


func _physics_process(_delta: float) -> void:
	if follow_settings:
		hair_enabled = GameSettings.hair_on()
		body_enabled = GameSettings.body_on()
	tick()


## One fixed 1/60 s step. Public so tests can drive it without a scene tree.
func tick() -> void:
	for p: Pivot in _pivots:
		if not is_instance_valid(p.node):
			continue
		var on: bool = body_enabled if p.is_bust else hair_enabled
		if not on:
			if p.applied:
				_clear(p)
				p.node.transform = p.rest
				p.applied = false
			continue
		_step_pivot(p)


static func _world(n: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var a: Node3D = n
	while a != null:
		t = a.transform * t
		a = a.get_parent() as Node3D
	return t


func _step_pivot(p: Pivot) -> void:
	var parent_w: Transform3D = _world(p.node.get_parent() as Node3D) if p.node.get_parent() is Node3D else Transform3D.IDENTITY
	var attach: Vector3 = parent_w * p.rest.origin
	var basis_p: Basis = parent_w.basis.orthonormalized()
	if p.samples >= 1 and attach.distance_to(p.prev_p) > TELEPORT_DIST:
		_clear(p)
		p.node.transform = p.rest
	var raw: Vector3 = Vector3.ZERO
	if p.samples >= 1:
		var v: Vector3 = (attach - p.prev_p) / DT
		if p.samples >= 2:
			raw = (v - p.prev_v) / DT
		p.prev_v = v
	p.prev_p = attach
	p.samples += 1
	raw = raw.limit_length(MAX_ACCEL)
	p.accel = p.accel.lerp(raw, ACCEL_SMOOTH)
	# Apparent gravity in the parent's frame: what a hanging mass feels.
	var eff_local: Vector3 = basis_p.inverse() * (Vector3(0.0, -GRAVITY, 0.0) - p.accel)
	if p.is_bust:
		_step_bust(p, eff_local)
	else:
		_step_hair(p, eff_local)
	p.applied = true


func _step_hair(p: Pivot, eff_local: Vector3) -> void:
	var dir: Vector3 = eff_local.normalized() if eff_local.length() > 0.001 else Vector3.DOWN
	var axis: Vector3 = Vector3.DOWN.cross(dir)
	var ang: float = acos(clampf(Vector3.DOWN.dot(dir), -1.0, 1.0))
	var target := Vector3.ZERO
	if axis.length() > 0.00001:
		var rv: Vector3 = axis.normalized() * ang * HAIR_GAIN
		target = Vector3(rv.x, 0.0, rv.z)
	var freq: float = HAIR_FREQ / (1.0 + 0.35 * float(p.depth))
	var w: float = TAU * freq
	var h: float = DT / float(SUBSTEPS)
	for i: int in SUBSTEPS:
		var acc: Vector3 = (target - p.pos) * (w * w) - p.vel * (2.0 * HAIR_DAMP * w)
		p.vel += acc * h
		p.pos += p.vel * h
	# Clamp per axis (rx: negative is back, since the skater faces -Z; rz: positive swings toward +x).
	var d: int = mini(p.depth, CHAIN_BACK.size() - 1)
	var back: float = SIDE_BACK if p.side != 0.0 else CHAIN_BACK[d]
	var fwd: float = SIDE_FWD if p.side != 0.0 else CHAIN_FWD[d]
	if p.node.has_meta("sway_fwd_limit_deg"):  # a hair part that would swing into the body (long hair on the back)
		fwd = minf(fwd, float(p.node.get_meta("sway_fwd_limit_deg")))
	p.pos.x = clampf(p.pos.x, -deg_to_rad(back), deg_to_rad(fwd))
	var rz_min: float = -deg_to_rad(CHAIN_SIDE[d])
	var rz_max: float = deg_to_rad(CHAIN_SIDE[d])
	if p.side != 0.0:
		# Positive rz swings the tip toward +x: inward for the left lock (x < 0), outward for the right.
		var inward: float = deg_to_rad(SIDE_IN)
		var outward: float = deg_to_rad(SIDE_OUT)
		rz_max = inward if p.side < 0.0 else outward
		rz_min = -outward if p.side < 0.0 else -inward
	p.pos.z = clampf(p.pos.z, rz_min, rz_max)
	if p.pos.x == -deg_to_rad(back) or p.pos.x == deg_to_rad(fwd):
		p.vel.x = 0.0
	if p.pos.z == rz_min or p.pos.z == rz_max:
		p.vel.z = 0.0
	var b: Basis = Basis.from_euler(Vector3(p.pos.x, 0.0, p.pos.z))
	p.node.transform = Transform3D(p.rest.basis * b, p.rest.origin)


func _step_bust(p: Pivot, eff_local: Vector3) -> void:
	# Only the dynamic part: how far the apparent gravity departs from plain 1 g down.
	var dev: Vector3 = eff_local - Vector3(0.0, -GRAVITY, 0.0)
	var target: Vector3 = Vector3(dev.x, dev.y, dev.z * 0.5) * BUST_GAIN * 0.5
	var w: float = TAU * BUST_FREQ
	var h: float = DT / float(SUBSTEPS)
	for i: int in SUBSTEPS:
		var acc: Vector3 = (target - p.pos) * (w * w) - p.vel * (2.0 * BUST_DAMP * w)
		p.vel += acc * h
		p.pos += p.vel * h
	p.pos = p.pos.limit_length(BUST_MAX_OFFSET)
	var tilt: float = deg_to_rad(BUST_MAX_TILT) / BUST_MAX_OFFSET
	var rot := Vector3(p.pos.y * tilt * 0.5, 0.0, -p.pos.x * tilt)
	p.node.transform = Transform3D(p.rest.basis * Basis.from_euler(rot), p.rest.origin + p.pos)
