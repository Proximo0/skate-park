class_name ReplayShots
extends RefCounted
## Camera shots for the replay (ReplayDirector), as pure math: the auto-cut plan over a clip and where each shot
## puts the camera. Skate-video grammar: a chase cam that rides behind, a low fisheye tripod beside the line for
## the airs (cut in just before each takeoff), and a wide tripod that shows the whole line. FREE is the player's
## orbit camera (never in an auto plan).

enum Shot { CHASE, LOW, WIDE, FREE }

const NAMES: PackedStringArray = ["CHASE CAM", "LOW ANGLE", "WIDE", "FREE CAM"]
const MIN_GAP: float = 1.6  ## s: shortest shot an auto cut leaves
const MIN_FIRST: float = 0.6  ## s: the opening shot may be this short when an air comes early
const MAX_LEN: float = 3.4  ## s: longest shot before a filler cut
const LEAD_IN: float = 0.2  ## s before a takeoff the cut lands
const FOV: Array[float] = [62.0, 72.0, 40.0, 60.0]
## Chase: metres behind and above the rider.
const CHASE_BACK: float = 3.4
const CHASE_UP: float = 1.3
## Low tripod: beside the line, a little ahead, near the ground.
const LOW_SIDE: float = 3.0
const LOW_AHEAD: float = 1.0
const LOW_UP: float = 0.3
## A tripod shot re-stands (a quick re-cut) when the rider gets this far from it (m), by shot.
const RESTAND: Array[float] = [0.0, 7.0, 20.0, 0.0]
## A re-stood tripod stands this far (m) up the rider's line, so they ride toward it.
const RESTAND_AHEAD: float = 3.5
## A low-angle cut stands for the moment this long after the cut (the air near its peak), not the shot's middle.
const LOW_AIM: float = 0.55
## Wide tripod: well off to the side and behind, raised.
const WIDE_SIDE: float = 8.5
const WIDE_BACK: float = 4.0
const WIDE_UP: float = 3.2


## Cuts over [from_t, to_t]: an Array of {"t": float, "shot": Shot}, first one at from_t, times increasing.
## takeoffs: rising edges of the air flag (ReplayBuffer.edges). Each takeoff with room gets a LOW (or WIDE if the
## shot before was LOW) cut LEAD_IN before it; long stretches get filler cuts that cycle CHASE -> WIDE -> LOW.
static func plan(from_t: float, to_t: float, takeoffs: PackedFloat64Array) -> Array:
	var cuts: Array = [{"t": from_t, "shot": Shot.CHASE}]
	var last_t: float = from_t
	var last_shot: int = Shot.CHASE
	var marks: Array = []
	for tk: float in takeoffs:
		marks.append(tk - LEAD_IN)
	marks.append(INF)
	for m: float in marks:
		var stop: float = minf(m, to_t)
		while stop - last_t > MAX_LEN and to_t - (last_t + MAX_LEN) >= MIN_GAP:
			last_t += MAX_LEN
			last_shot = _filler_after(last_shot)
			cuts.append({"t": last_t, "shot": last_shot})
		if m == INF or m >= to_t - MIN_GAP * 0.5:
			continue
		if m - last_t < (MIN_FIRST if cuts.size() == 1 else MIN_GAP):
			continue
		last_shot = Shot.WIDE if last_shot == Shot.LOW else Shot.LOW
		last_t = m
		cuts.append({"t": m, "shot": last_shot})
	return cuts


static func _filler_after(shot: int) -> int:
	match shot:
		Shot.CHASE:
			return Shot.WIDE
		Shot.WIDE:
			return Shot.LOW
	return Shot.CHASE


## Index of the cut in effect at time t.
static func cut_index(cuts: Array, t: float) -> int:
	var idx: int = 0
	for i: int in cuts.size():
		if float((cuts[i] as Dictionary)["t"]) <= t:
			idx = i
	return idx


## Where a tripod shot stands, from the rider's position at the middle of the shot and its flat travel direction.
## side_sign picks the side of the line (+1 right of travel, -1 left).
static func tripod(shot: int, mid: Vector3, dir: Vector3, side_sign: float = 1.0) -> Vector3:
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z)
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var side: Vector3 = d.cross(Vector3.UP).normalized() * side_sign
	match shot:
		Shot.LOW:
			return mid + side * LOW_SIDE + d * LOW_AHEAD + Vector3.UP * LOW_UP
		Shot.WIDE:
			return mid + side * WIDE_SIDE - d * WIDE_BACK + Vector3.UP * WIDE_UP
	return mid - d * CHASE_BACK + Vector3.UP * CHASE_UP


## Chase camera goal for a rider at `focus` travelling along `dir`.
static func chase(focus: Vector3, dir: Vector3) -> Vector3:
	return tripod(Shot.CHASE, focus, dir)


## Free orbit camera position: yaw / pitch (radians) around focus at dist.
static func orbit(focus: Vector3, yaw: float, pitch: float, dist: float) -> Vector3:
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	return focus + off * dist
