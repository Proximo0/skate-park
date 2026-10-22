class_name HillsMerge
extends RefCounted
## Draw-call saver: every MeshInstance3D under a node is baked into one ArrayMesh with one surface per material,
## held by a single MeshInstance3D on that node. Collision bodies and shapes stay where they were; Label3Ds,
## MultiMeshes and anything animated are left alone (only plain MeshInstance3Ds are merged).


## Merges the meshes under `root` (in root's space). Returns how many MeshInstance3Ds it replaced.
static func merge(root: Node3D, cast_shadow: bool = true, node_name: String = "Merged") -> int:
	var by_mat: Dictionary = {}  # Material -> SurfaceTool
	var mats: Array[Material] = []
	var gone: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var xf: Transform3D = HillsMerge._relative(root, mi)
		for s: int in mi.mesh.get_surface_count():
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if not by_mat.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				by_mat[mat] = st
				mats.append(mat)
			(by_mat[mat] as SurfaceTool).append_from(mi.mesh, s, xf)
		gone.append(mi)
	if gone.is_empty():
		return 0
	var out := ArrayMesh.new()
	for mat: Material in mats:
		var st: SurfaceTool = by_mat[mat]
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	for mi: MeshInstance3D in gone:
		mi.get_parent().remove_child(mi)
		mi.free()
	var merged := MeshInstance3D.new()
	merged.name = node_name
	merged.mesh = out
	if not cast_shadow:
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(merged)
	return gone.size()


static func _relative(root: Node3D, n: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
