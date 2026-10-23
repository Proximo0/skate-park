class_name RampLip
extends Node3D
## A ramp's lip for the ramp snap (Q + E / L1 + R1, see RampSnap): a polyline along the coping or the roll-in edge,
## in this node's local space, with one horizontal "inward" direction per segment: the way down the ramp (from the
## lip over the transition toward the flat in front of it). Found through the "ramp_lip" group.
## kind "drop_in": coping on a transition (quarter pipe, half pipe, bowl, spine, hip, bank); the skater hangs the
## tail on it and stomps in. kind "roll_in": the edge of a flat start deck that rolls into a slope (mega ramp,
## drop ramp); the skater is set on the deck rolling over the edge.

@export var points: PackedVector3Array = PackedVector3Array()
## One per segment (points.size() - 1), local space, horizontal and unit length.
@export var inward: PackedVector3Array = PackedVector3Array()
@export_enum("drop_in", "roll_in") var kind: String = "drop_in"


func _ready() -> void:
	add_to_group("ramp_lip")


## A straight or bent lip whose every segment faces `inward_dir` (local).
static func line(pts: PackedVector3Array, inward_dir: Vector3, lip_kind: String = "drop_in", node_name: String = "Lip") -> RampLip:
	var dirs := PackedVector3Array()
	for i: int in range(pts.size() - 1):
		dirs.append(inward_dir)
	return make(pts, dirs, lip_kind, node_name)


## A closed rim (a bowl): each segment faces the horizontal `centre`, square to the segment.
static func ring(pts: PackedVector3Array, centre: Vector3, node_name: String = "Lip") -> RampLip:
	var dirs := PackedVector3Array()
	for i: int in range(pts.size() - 1):
		var t: Vector3 = Vector3(pts[i + 1].x - pts[i].x, 0.0, pts[i + 1].z - pts[i].z).normalized()
		var side: Vector3 = t.cross(Vector3.UP)
		var mid: Vector3 = (pts[i] + pts[i + 1]) * 0.5
		if side.dot(Vector3(centre.x - mid.x, 0.0, centre.z - mid.z)) < 0.0:
			side = -side
		dirs.append(side)
	return make(pts, dirs, "drop_in", node_name)


static func make(pts: PackedVector3Array, dirs: PackedVector3Array, lip_kind: String, node_name: String) -> RampLip:
	var lip := RampLip.new()
	lip.name = node_name
	lip.points = pts
	var flat := PackedVector3Array()
	for d: Vector3 in dirs:
		flat.append(Vector3(d.x, 0.0, d.z).normalized())
	lip.inward = flat
	lip.kind = lip_kind
	return lip


## World-space segments: [{a, b, inward, kind}], the shape RampSnap's pure functions take.
func segments() -> Array:
	var out: Array = []
	var xf: Transform3D = global_transform if is_inside_tree() else transform
	for i: int in range(points.size() - 1):
		var d: Vector3 = xf.basis * (inward[i] if i < inward.size() else Vector3.BACK)
		d.y = 0.0
		out.append({"a": xf * points[i], "b": xf * points[i + 1], "inward": d.normalized(), "kind": kind})
	return out
