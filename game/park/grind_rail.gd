class_name GrindRail
extends Node3D
## A grindable polyline (rail, ledge edge or coping) in this node's local space.
## The skater finds rails through the "grind_rail" group and snaps to the closest segment.

@export var points: PackedVector3Array = PackedVector3Array()
@export_enum("rail", "ledge", "coping") var kind: String = "rail"


func _ready() -> void:
	add_to_group("grind_rail")


func global_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Vector3 in points:
		out.append(global_transform * p)
	return out


## Closest point on the rail to a world position.
## Returns {point: Vector3, tangent: Vector3 (unit, along increasing index), segment: int, t: float, distance: float}.
func closest(world_pos: Vector3) -> Dictionary:
	var gp: PackedVector3Array = global_points()
	var best: Dictionary = {}
	var best_d: float = INF
	for i: int in range(gp.size() - 1):
		var a: Vector3 = gp[i]
		var b: Vector3 = gp[i + 1]
		var ab: Vector3 = b - a
		var len2: float = ab.length_squared()
		if len2 < 0.000001:
			continue
		var t: float = clampf((world_pos - a).dot(ab) / len2, 0.0, 1.0)
		var p: Vector3 = a + ab * t
		var d: float = p.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = {"point": p, "tangent": ab.normalized(), "segment": i, "t": t, "distance": d}
	return best


## Advance along the rail by a signed distance from (segment, t). Returns the same shape as closest(),
## plus "ended": true when it ran off either end (point is then the end point).
func advance(segment: int, t: float, distance: float) -> Dictionary:
	var gp: PackedVector3Array = global_points()
	var seg: int = segment
	var tt: float = t
	var left: float = distance
	while true:
		var a: Vector3 = gp[seg]
		var b: Vector3 = gp[seg + 1]
		var seg_len: float = maxf(a.distance_to(b), 0.0001)
		var nt: float = tt + left / seg_len
		if nt > 1.0 and seg < gp.size() - 2:
			left -= (1.0 - tt) * seg_len
			seg += 1
			tt = 0.0
		elif nt < 0.0 and seg > 0:
			left += tt * seg_len
			seg -= 1
			tt = 1.0
		else:
			var ended: bool = nt > 1.0 or nt < 0.0
			nt = clampf(nt, 0.0, 1.0)
			return {"point": a.lerp(b, nt), "tangent": (b - a).normalized(), "segment": seg, "t": nt, "ended": ended}
	return {}
