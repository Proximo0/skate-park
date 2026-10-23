class_name RampSnap
extends RefCounted
## The ramp snap (Q + E / L1 + R1 together): pure geometry for picking where it takes the skater. No Node, no clock.
## Lips come from RampLip.segments(): [{a, b, inward, kind}] in world space, inward = horizontal, down the ramp.
##
## SNAP IN (rolling on flat ground or in the air, not inside a ramp): the nearest lip point within reach, preferring
## lips the skater is in front of. A "drop_in" lip (coping) gets a real drop-in: the skater is carried in a short arc
## onto the coping, hangs the tail on it for a beat, stomps the nose down and drops down the wall. A "roll_in" lip (a
## start deck's edge) sets the skater on the deck rolling over the edge. In the air below the lip, the arc goes
## straight onto the wall (no hang: there is no deck under you to stand on).
## SNAP OUT (riding a transition, in vert air, or down inside a half pipe or bowl): an arc up out of the ramp onto
## the flat in front of it, rolling away; when that flat is itself inside the ramp (a half pipe's flat bottom, a bowl
## floor), off the side past the end of the lip, rolling the same way; failing that, onto the deck behind the
## nearest coping, rolling along it.

const BEHIND_PENALTY: float = 4.0  ## m added to a lip's distance when the skater is behind it (on its deck side)
const ENCLOSE_REACH: float = 9.0  ## m: lips this close (square to the lip) that rise over the skater wall it in
const ENCLOSE_SIDE: float = 0.5  ## m past the end of a lip still counted as in front of it
const ENCLOSE_RISE: float = 0.5  ## m a lip must be above the skater to count as a wall around it
const ENCLOSE_OPPOSED_DOT: float = -0.5  ## two walling lips facing each other at least this squarely: inside a ramp
const ON_TRANSITION_NY: float = 0.97  ## grounded on a floor steeper than this (normal y): on a ramp
const HANG_TIME: float = 0.3  ## tail hooked on the coping
const STOMP_TIME: float = 0.2  ## front foot stomps the nose down (the board pitches about the rear wheels on the coping)
const TIP_TIME: float = 0.32  ## the board rolls over the coping onto the wall: wheels on it the whole way, no hop
const TIP_FALL_START: float = 0.3  ## share of TIP_TIME the nose turns down before the body starts to fall
const DECK_GLIDE_MAX: float = 2.5  ## m: already on the deck this close behind the coping, the skater glides over, no hop
const DECK_GLIDE_RISE: float = 0.35  ## m the deck may sit above or below the skater for a glide
const CAMERA_HOLD: float = 1.0  ## s at most the chase camera stays up over the coping watching the drop (Skater.camera_hold)
const CAMERA_BACK: float = 0.8  ## m behind the coping it waits, on the deck side, looking down the wall
const CAMERA_UP: float = 3.4  ## m above the coping: high enough to see past the coping down the whole wall
const HANG_BACK: float = 0.2  ## m: the rear truck sits this far behind the coping, on the deck
const DROP_OUT: float = 0.34  ## m past the coping the body starts its drop down the wall (its sphere is 0.3)
const ROLL_BACK: float = 1.4  ## m behind a roll-in edge the skater is set down on the deck
const ROLL_SPEED: float = 3.0  ## m/s: rolling over a roll-in edge (more would launch off a 60 degree start)
const OUT_FLAT: float = 4.0  ## m past the start of the flat in front of a ramp that a snap out lands
const SIDE_OUT: float = 2.5  ## m past the end of a lip that a snap out off the side of a ramp lands
const SIDE_IN: float = 1.5  ## m out in front of the lip's line, for the same
const END_MARGIN: float = 0.6  ## m a snap-in point stays in from the ends of a lip segment (side plates, corners)
const OUT_CLEAR: float = 0.8  ## m a snap-out arc's middle clears the lip of the ramp it leaves
const DECK_BACK: float = 1.2  ## m behind a coping that a snap out onto a deck lands
const DECK_SPEED: float = 1.5  ## m/s along the deck after a snap out onto one
const ARC_MIN: float = 0.35  ## s
const ARC_MAX: float = 0.5
const ARC_PER_M: float = 0.012  ## s added per metre of arc
const APEX_MIN: float = 0.8  ## m the arc rises over the straight line between its ends
const APEX_PER_M: float = 0.08


## Closest point to `p` on segment a-b and its parameter: [point, t].
static func closest_on_segment(p: Vector3, a: Vector3, b: Vector3) -> Array:
	var ab: Vector3 = b - a
	var len2: float = ab.length_squared()
	if len2 < 0.000001:
		return [a, 0.0]
	var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return [a + ab * t, t]


## Snap-in candidates within `reach` (horizontal metres) of `pos`, best first: [{point, inward, kind, dist, score,
## behind, tangent}]. One per segment. Lips behind the skater (it is on their deck side) cost BEHIND_PENALTY.
static func candidates(pos: Vector3, segs: Array, reach: float) -> Array:
	var out: Array = []
	for s: Dictionary in segs:
		var a: Vector3 = s["a"]
		var b: Vector3 = s["b"]
		var c: Array = closest_on_segment(pos, a, b)
		var p: Vector3 = c[0]
		var seg_len: float = a.distance_to(b)
		if seg_len > 0.01:
			var m: float = minf(END_MARGIN, seg_len * 0.5) / seg_len
			p = a.lerp(b, clampf(float(c[1]), m, 1.0 - m))
		var flat: float = Vector2(p.x - pos.x, p.z - pos.z).length()
		if flat > reach:
			continue
		var inward: Vector3 = s["inward"]
		var behind: bool = (pos - p).dot(inward) < 0.0
		var dist: float = p.distance_to(pos)
		var tan: Vector3 = (b - a)
		tan.y = 0.0
		out.append({"point": p, "inward": inward, "kind": str(s.get("kind", "drop_in")), "dist": dist,
			"score": dist + (BEHIND_PENALTY if behind else 0.0), "behind": behind,
			"tangent": tan.normalized() if tan.length() > 0.001 else inward.cross(Vector3.UP)})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["score"]) < float(y["score"]))
	return out


## The lips walling `pos` in: segments it is in front of (inward side), within ENCLOSE_REACH square to the lip and
## alongside it, rising ENCLOSE_RISE or more above it. Returned as candidate-shaped dicts, nearest first.
static func walls_around(pos: Vector3, segs: Array) -> Array:
	var out: Array = []
	for s: Dictionary in segs:
		var a: Vector3 = s["a"]
		var b: Vector3 = s["b"]
		var c: Array = closest_on_segment(pos, a, b)
		var p: Vector3 = c[0]
		var inward: Vector3 = s["inward"]
		var d: Vector3 = pos - p
		d.y = 0.0
		var ahead: float = d.dot(inward)
		if ahead <= 0.0 or ahead > ENCLOSE_REACH or p.y - pos.y < ENCLOSE_RISE:
			continue
		if (d - inward * ahead).length() > ENCLOSE_SIDE:
			continue  # off the end of the segment: beside the ramp, not in front of it
		var tan: Vector3 = b - a
		tan.y = 0.0
		out.append({"point": p, "inward": inward, "kind": str(s.get("kind", "drop_in")), "dist": d.length(),
			"tangent": tan.normalized() if tan.length() > 0.001 else inward.cross(Vector3.UP)})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["dist"]) < float(y["dist"]))
	return out


## True when two walling lips face each other across `pos`: down inside a half pipe or a bowl.
static func enclosed(pos: Vector3, segs: Array) -> bool:
	var w: Array = walls_around(pos, segs)
	for i: int in w.size():
		for j: int in range(i + 1, w.size()):
			if (w[i]["inward"] as Vector3).dot(w[j]["inward"] as Vector3) < ENCLOSE_OPPOSED_DOT:
				return true
	return false


## In a ramp, so the snap goes OUT: on a transition (grounded on a steep floor), in vert air, on a lip trick, or down
## inside a half pipe or bowl.
static func in_ramp(grounded: bool, floor_ny: float, vert_air: bool, on_lip: bool, is_enclosed: bool) -> bool:
	if on_lip or vert_air or is_enclosed:
		return true
	return grounded and floor_ny < ON_TRANSITION_NY


## Seconds a snap arc of `dist` metres takes.
static func arc_time(dist: float) -> float:
	return clampf(ARC_MIN + dist * ARC_PER_M, ARC_MIN, ARC_MAX)


## Height (m) the arc rises over the straight line between its ends: more for longer arcs, and enough for its middle
## to clear `over_y` (a snap out goes up over the ramp's lip, not through its side).
static func arc_apex(dist: float, p0: Vector3 = Vector3.ZERO, p1: Vector3 = Vector3.ZERO, over_y: float = -INF) -> float:
	var h: float = APEX_MIN + dist * APEX_PER_M
	return maxf(h, over_y - (p0.y + p1.y) * 0.5)


## A point on the snap arc at u in [0, 1]: the straight line from p0 to p1 lifted by a parabola peaking at `apex`.
## The horizontal motion eases in and out a little so the take-off and the catch do not jerk.
static func arc_point(p0: Vector3, p1: Vector3, apex: float, u: float) -> Vector3:
	var k: float = clampf(u, 0.0, 1.0)
	var e: float = lerpf(k, k * k * (3.0 - 2.0 * k), 0.5)
	var p: Vector3 = p0.lerp(p1, e)
	return p + Vector3.UP * (4.0 * apex * k * (1.0 - k))


## True when a snap in from `p0` to the hang spot `p1` behind coping `lip` (inward down the ramp) is a short glide
## along the deck the skater is already standing on, not an arc through the air.
static func deck_glide(p0: Vector3, p1: Vector3, lip: Vector3, inward: Vector3) -> bool:
	var flat: float = Vector2(p1.x - p0.x, p1.z - p0.z).length()
	return (p0 - lip).dot(inward) < 0.0 and absf(p0.y - lip.y) < DECK_GLIDE_RISE and flat < DECK_GLIDE_MAX


## The drop-in tip over the coping: the sphere centre swung about the coping point `lip` by the angle between UP and
## the wall normal `n` (progress `turn`, 0..1, eased), plus the slide from the end of that swing down onto `c1` (the
## centre resting on the wall; progress `fall`, 0..1, eased in like a fall from rest). Returns [centre, board_up].
## The swing keeps the rear wheels on the coping while the nose goes down onto the wall.
static func tip_pose(c0: Vector3, c1: Vector3, lip: Vector3, n: Vector3, turn: float, fall: float) -> Array:
	var k: float = clampf(turn, 0.0, 1.0)
	var f: float = clampf(fall, 0.0, 1.0)
	var axis: Vector3 = Vector3.UP.cross(n)
	var ang: float = Vector3.UP.angle_to(n)
	if axis.length() < 0.0001:
		return [c0.lerp(c1, f), Vector3.UP]
	axis = axis.normalized()
	var swung: Vector3 = lip + (c0 - lip).rotated(axis, ang * k)
	var swung_end: Vector3 = lip + (c0 - lip).rotated(axis, ang)
	return [swung + (c1 - swung_end) * f, Vector3.UP.rotated(axis, ang * k).normalized()]


## Length of the path tip_pose carries the sphere centre along from c0 to c1 (its swing about the coping and the
## slide onto the wall together), sampled.
static func tip_path_length(c0: Vector3, c1: Vector3, lip: Vector3, n: Vector3) -> float:
	var total: float = 0.0
	var prev: Vector3 = c0
	for i: int in range(1, 17):
		var x: float = float(i) / 16.0
		var p: Vector3 = tip_pose(c0, c1, lip, n, x, x)[0]
		total += prev.distance_to(p)
		prev = p
	return maxf(total, c0.distance_to(c1))


## The camera's perch for a drop-in at coping `lip` facing down the ramp along `inward`: up over the coping, a little
## back on the deck side, looking down the wall.
static func camera_perch(lip: Vector3, inward: Vector3) -> Vector3:
	return lip - inward * CAMERA_BACK + Vector3.UP * CAMERA_UP


## Where the drop-in hang puts the skater's origin for a coping point and inward: the board's rear truck just behind
## the coping on the deck, the board pointing down the ramp.
static func hang_spot(lip: Vector3, inward: Vector3, truck_z: float) -> Vector3:
	return lip + inward * (truck_z - HANG_BACK)
