class_name SkaterParts
extends RefCounted
## Mesh and node primitives shared by PlaceholderSkater, AnimeHead, AnimeOutfit and AnimeBoard. Every part gets meta
## "palette" (its palette key) and a StandardMaterial3D in material_override so the toon pass can swap materials.


static func materials(palette: Dictionary, defaults: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in defaults.keys():
		var given: Color = palette.get(key, defaults[key])
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = given
		mat.roughness = 0.7
		out[key] = mat
	return out


static func joint(parent: Node3D, joint_name: String, pivot: Vector3) -> Node3D:
	var joint: Node3D = Node3D.new()
	joint.name = joint_name
	joint.position = pivot
	parent.add_child(joint)
	return joint


static func part(parent: Node3D, part_name: String, mesh: Mesh, offset: Vector3, mats: Dictionary, key: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.position = offset
	mi.material_override = mats[key]
	mi.set_meta("palette", key)
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	return m


static func sphere(radius: float) -> SphereMesh:
	var m: SphereMesh = SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 24
	m.rings = 12
	return m


## Upper half of a sphere of this radius (dome), centred on its origin. Godot's hemisphere spans y 0..height,
## so height = radius gives a dome whose top is at the radius.
static func dome(radius: float) -> SphereMesh:
	var m: SphereMesh = sphere(radius)
	m.is_hemisphere = true
	m.height = radius
	return m


static func torus(inner_radius: float, outer_radius: float) -> TorusMesh:
	var m: TorusMesh = TorusMesh.new()
	m.inner_radius = inner_radius
	m.outer_radius = outer_radius
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m: CapsuleMesh = CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 20
	m.rings = 6
	return m


static func cylinder(radius: float, height: float) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 16
	return m


## Tapered tube through the points, radius per point. Built in place (no mesh transform) so its bounds are tight.
static func tube(points: PackedVector3Array, radii: PackedFloat32Array, sides: int = 12) -> ArrayMesh:
	var n: int = points.size()
	var rings: Array = []
	var normals: Array = []
	for i: int in n:
		var tangent: Vector3 = (points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side: Vector3 = tangent.cross(Vector3.RIGHT)
		if side.length() < 0.001:
			side = tangent.cross(Vector3.UP)
		side = side.normalized()
		var up: Vector3 = side.cross(tangent).normalized()
		var ring: PackedVector3Array = PackedVector3Array()
		var ring_normals: Array = []
		for k: int in sides:
			var a: float = TAU * float(k) / float(sides)
			var dir: Vector3 = side * cos(a) + up * sin(a)
			ring.append(points[i] + dir * radii[i])
			ring_normals.append(dir)
		rings.append(ring)
		normals.append(ring_normals)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in n - 1:
		for k: int in sides:
			var k2: int = (k + 1) % sides
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k2]
			var c: Vector3 = rings[i + 1][k]
			var d: Vector3 = rings[i + 1][k2]
			var na: Vector3 = normals[i][k]
			var nb: Vector3 = normals[i][k2]
			var nc: Vector3 = normals[i + 1][k]
			var nd: Vector3 = normals[i + 1][k2]
			st.set_normal(na)
			st.add_vertex(a)
			st.set_normal(nb)
			st.add_vertex(b)
			st.set_normal(nc)
			st.add_vertex(c)
			st.set_normal(nb)
			st.add_vertex(b)
			st.set_normal(nd)
			st.add_vertex(d)
			st.set_normal(nc)
			st.add_vertex(c)
	return st.commit()
