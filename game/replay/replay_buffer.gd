class_name ReplayBuffer
extends RefCounted
## Ring buffer of visual frames for the player-facing replay (ReplayDirector). One frame holds a time stamp, a fixed
## list of Transform3D tracks (track 0: the skater's global transform; the rest: local transforms of the Visual root,
## the body, the board, the code rig's joints and the sway pivots), the speed and a few state flags (FLAG_*).
## Pure data: no Node, no clock. Times are the caller's recording clock in seconds, strictly increasing.
## Storage is flat packed arrays (12 floats per transform), so a 20 s buffer at 60 Hz with 40 tracks is about 2 MB
## and a push costs one array write per float, with no allocation once the ring is full.

const FLOATS: int = 12  ## basis columns x, y, z then origin
const FLAG_AIR: int = 1
const FLAG_GRIND: int = 2
const FLAG_BAIL: int = 4
const FLAG_MANUAL: int = 8

var track_count: int = 0
var capacity: int = 0

var _t: PackedFloat64Array = PackedFloat64Array()
var _x: PackedFloat32Array = PackedFloat32Array()
var _speed: PackedFloat32Array = PackedFloat32Array()
var _flags: PackedInt32Array = PackedInt32Array()
var _head: int = 0  ## next write slot
var _count: int = 0


func _init(tracks: int = 1, frames: int = 600) -> void:
	track_count = maxi(tracks, 1)
	capacity = maxi(frames, 2)
	_t.resize(capacity)
	_x.resize(capacity * track_count * FLOATS)
	_speed.resize(capacity)
	_flags.resize(capacity)


func size() -> int:
	return _count


func clear() -> void:
	_head = 0
	_count = 0


## Appends a frame. `xforms` must hold track_count transforms (missing ones are written as identity). A time at or
## before the newest frame's replaces that frame (two samples in one engine frame).
func push(t: float, xforms: Array, speed: float = 0.0, flags: int = 0) -> void:
	if _count > 0 and t <= time_at(_count - 1):
		_head = (_head - 1 + capacity) % capacity
		_count -= 1
	var slot: int = _head
	_t[slot] = t
	_speed[slot] = speed
	_flags[slot] = flags
	var base: int = slot * track_count * FLOATS
	for k: int in track_count:
		var xf: Transform3D = xforms[k] if k < xforms.size() else Transform3D.IDENTITY
		var o: int = base + k * FLOATS
		_x[o] = xf.basis.x.x
		_x[o + 1] = xf.basis.x.y
		_x[o + 2] = xf.basis.x.z
		_x[o + 3] = xf.basis.y.x
		_x[o + 4] = xf.basis.y.y
		_x[o + 5] = xf.basis.y.z
		_x[o + 6] = xf.basis.z.x
		_x[o + 7] = xf.basis.z.y
		_x[o + 8] = xf.basis.z.z
		_x[o + 9] = xf.origin.x
		_x[o + 10] = xf.origin.y
		_x[o + 11] = xf.origin.z
	_head = (_head + 1) % capacity
	_count = mini(_count + 1, capacity)


## Ring slot of the i-th kept frame (0 = oldest).
func _slot(i: int) -> int:
	return (_head - _count + i + capacity * 2) % capacity


func time_at(i: int) -> float:
	return _t[_slot(i)]


func speed_at(i: int) -> float:
	return _speed[_slot(i)]


func flags_at(i: int) -> int:
	return _flags[_slot(i)]


func xform(i: int, track: int) -> Transform3D:
	var o: int = (_slot(i) * track_count + track) * FLOATS
	return Transform3D(Basis(Vector3(_x[o], _x[o + 1], _x[o + 2]), Vector3(_x[o + 3], _x[o + 4], _x[o + 5]),
		Vector3(_x[o + 6], _x[o + 7], _x[o + 8])), Vector3(_x[o + 9], _x[o + 10], _x[o + 11]))


func start_time() -> float:
	return time_at(0) if _count > 0 else 0.0


func end_time() -> float:
	return time_at(_count - 1) if _count > 0 else 0.0


func duration() -> float:
	return end_time() - start_time()


## Index of the newest frame at or before t (0 before the first frame, size()-1 after the last). Binary search.
func index_at(t: float) -> int:
	if _count == 0:
		return -1
	var lo: int = 0
	var hi: int = _count - 1
	if t <= time_at(0):
		return 0
	if t >= time_at(hi):
		return hi
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if time_at(mid) <= t:
			lo = mid
		else:
			hi = mid
	return lo


## Every track at time t, interpolated between the two frames around it (origin lerp, rotation slerp with scale).
## Clamped to the first / last frame. Empty when the buffer is.
func sample(t: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	if _count == 0:
		return out
	var i: int = index_at(t)
	var j: int = mini(i + 1, _count - 1)
	var w: float = 0.0
	if j > i:
		var t0: float = time_at(i)
		var t1: float = time_at(j)
		w = clampf((t - t0) / maxf(t1 - t0, 1e-9), 0.0, 1.0)
	for k: int in track_count:
		var a: Transform3D = xform(i, k)
		out.append(a if w <= 0.0 else a.interpolate_with(xform(j, k), w))
	return out


## One track at time t (interpolated like sample()).
func sample_track(t: float, track: int) -> Transform3D:
	if _count == 0:
		return Transform3D.IDENTITY
	var i: int = index_at(t)
	var j: int = mini(i + 1, _count - 1)
	if j == i:
		return xform(i, track)
	var w: float = clampf((t - time_at(i)) / maxf(time_at(j) - time_at(i), 1e-9), 0.0, 1.0)
	return xform(i, track).interpolate_with(xform(j, track), w)


## Speed at time t (linear).
func speed_sample(t: float) -> float:
	if _count == 0:
		return 0.0
	var i: int = index_at(t)
	var j: int = mini(i + 1, _count - 1)
	if j == i:
		return speed_at(i)
	var w: float = clampf((t - time_at(i)) / maxf(time_at(j) - time_at(i), 1e-9), 0.0, 1.0)
	return lerpf(speed_at(i), speed_at(j), w)


## A new buffer holding a copy of the frames with from_t <= t <= to_t (sized to fit them exactly).
func clip(from_t: float, to_t: float) -> ReplayBuffer:
	var first: int = -1
	var last: int = -1
	for i: int in _count:
		var t: float = time_at(i)
		if t < from_t:
			continue
		if t > to_t:
			break
		if first < 0:
			first = i
		last = i
	var n: int = 0 if first < 0 else last - first + 1
	var out := ReplayBuffer.new(track_count, maxi(n, 2))
	for i: int in n:
		out._copy_frame_from(self, first + i)
	return out


## The newest `seconds` of the buffer as a clip.
func last_seconds(seconds: float) -> ReplayBuffer:
	return clip(end_time() - seconds, end_time())


func _copy_frame_from(src: ReplayBuffer, i: int) -> void:
	var s: int = src._slot(i)
	var slot: int = _head
	_t[slot] = src._t[s]
	_speed[slot] = src._speed[s]
	_flags[slot] = src._flags[s]
	var n: int = track_count * FLOATS
	var so: int = s * n
	var dof: int = slot * n
	for k: int in n:
		_x[dof + k] = src._x[so + k]
	_head = (_head + 1) % capacity
	_count = mini(_count + 1, capacity)


## Rising edges of `flag` (e.g. takeoffs for FLAG_AIR) between from_t and to_t, as times.
func edges(flag: int, from_t: float = -INF, to_t: float = INF) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var prev: bool = false
	for i: int in _count:
		var on: bool = (flags_at(i) & flag) != 0
		var t: float = time_at(i)
		if on and not prev and i > 0 and t >= from_t and t <= to_t:
			out.append(t)
		prev = on
	return out


## About how many bytes the frames take (for the cost check).
func bytes() -> int:
	return capacity * (8 + 4 + 4 + track_count * FLOATS * 4)
