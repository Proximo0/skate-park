class_name PieceKit
extends RefCounted
## Shared helpers for park pieces built in code. Every piece builder returns a Node3D whose origin is at
## ground level at the piece's back-left corner; the footprint spans x in [0, width] and z in [0, depth],
## and the riding face looks toward +Z. Units are metres on a 1 m grid. See docs/art_spec.md.

## Palette for placeholder park pieces (bright, kid-friendly).
const CONCRETE := Color("b9b3aa")
const RAMP_WOOD := Color("f2b45a")
const RAMP_SIDE := Color("4fa3e0")
const METAL := Color("c9d3dd")
const PAINT_RED := Color("ff5a5f")
const PAINT_GREEN := Color("6cd46c")
const PAINT_PURPLE := Color("9b6bff")
const PAINT_YELLOW := Color("ffd23f")


## A static body with a mesh and matching trimesh collision. Collision layer 1 = world.
const FLOOR_PAD_LIFT: float = 0.006


static func body(mesh: Mesh, color: Color, node_name: String = "Body") -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = node_name
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.material_override = Toon.material(color)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	sb.add_child(cs)
	return sb


## A box body positioned by its minimum corner and size (handy for platforms, ledges, decks).
static func box(min_corner: Vector3, size: Vector3, color: Color, node_name: String = "Box") -> StaticBody3D:
	var m := BoxMesh.new()
	m.size = size
	var sb: StaticBody3D = body(m, color, node_name)
	sb.position = min_corner + size * 0.5
	return sb


## A box whose top sits flush with the park ground (y = 0). The collider stays flush so nothing snags, but the
## mesh is lifted FLOOR_PAD_LIFT so its top doesn't z-fight (flicker) with the ground slab it overlaps.
static func floor_pad(min_corner: Vector3, size: Vector3, color: Color, node_name: String = "FloorPad") -> StaticBody3D:
	var sb: StaticBody3D = box(min_corner, size, color, node_name)
	(sb.get_node("Mesh") as Node3D).position.y = FLOOR_PAD_LIFT
	return sb


## A grindable polyline in the parent's local space.
static func rail(points: PackedVector3Array, kind: String = "rail", node_name: String = "Rail") -> GrindRail:
	var r := GrindRail.new()
	r.name = node_name
	r.points = points
	r.kind = kind
	return r


## A visible round metal rail (mesh only, no collision: the skater grinds the GrindRail line) plus its GrindRail.
static func round_rail(a: Vector3, b: Vector3, radius: float = 0.04, color: Color = METAL, node_name: String = "Rail") -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 10
	mi.mesh = cyl
	mi.material_override = Toon.material(color)
	var mid: Vector3 = (a + b) * 0.5
	var dir: Vector3 = (b - a).normalized()
	var up_hint: Vector3 = Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var basis_y: Basis = Basis.looking_at(dir, up_hint) * Basis(Vector3.RIGHT, -PI / 2)
	mi.transform = Transform3D(basis_y, mid)
	root.add_child(mi)
	root.add_child(rail(PackedVector3Array([a, b]), "rail", "Line"))
	return root


## A trigger zone for gap detection (group "gap_zone", meta "zone_id"). Detects the skater on layer 2.
static func gap_zone(zone_id: String, min_corner: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = "Zone_" + zone_id
	area.set_meta("zone_id", zone_id)
	area.add_to_group("gap_zone")
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = min_corner + size * 0.5
	area.add_child(cs)
	return area


## Build an ArrayMesh from a list of triangles (counter-clockwise when seen from the outside), with flat normals.
static func mesh_from_triangles(tris: PackedVector3Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(0, tris.size(), 3):
		var n: Vector3 = (tris[i + 1] - tris[i]).cross(tris[i + 2] - tris[i]).normalized()
		# Godot treats clockwise as front-facing, so emit the outside-CCW triangle reversed.
		for k: int in [0, 2, 1]:
			st.set_normal(n)
			st.add_vertex(tris[i + k])
	return st.commit()


## Extrude a 2D profile (in the Y-Z plane, points ordered so the solid is on the left when walking them,
## closed implicitly) along X from 0 to width. Smooth-ish normals come from SurfaceTool.generate_normals.
static func extrude_profile(profile: PackedVector2Array, width: float) -> ArrayMesh:
	# Normalise the winding: counter-clockwise in (z right, y up) gives outward-facing triangles below.
	var area: float = 0.0
	for i: int in profile.size():
		var a2: Vector2 = profile[i]
		var b2: Vector2 = profile[(i + 1) % profile.size()]
		area += a2.y * b2.x - b2.y * a2.x
	if area < 0.0:
		profile = profile.duplicate()
		profile.reverse()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = profile.size()
	for i: int in n:
		var p: Vector2 = profile[i]
		var q: Vector2 = profile[(i + 1) % n]
		var a := Vector3(0, p.x, p.y)
		var b := Vector3(0, q.x, q.y)
		var c := Vector3(width, q.x, q.y)
		var d := Vector3(width, p.x, p.y)
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)
	# end caps (fan; profiles are kept convex or fan-safe from vertex 0)
	for i: int in range(1, n - 1):
		st.add_vertex(Vector3(0, profile[0].x, profile[0].y))
		st.add_vertex(Vector3(0, profile[i + 1].x, profile[i + 1].y))
		st.add_vertex(Vector3(0, profile[i].x, profile[i].y))
		st.add_vertex(Vector3(width, profile[0].x, profile[0].y))
		st.add_vertex(Vector3(width, profile[i].x, profile[i].y))
		st.add_vertex(Vector3(width, profile[i + 1].x, profile[i + 1].y))
	st.generate_normals()
	return st.commit()
