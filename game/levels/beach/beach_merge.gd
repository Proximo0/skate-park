class_name BeachMerge
extends RefCounted
## Draw-call saver for code-built props (benches, tables, carts, stairs, shops): every MeshInstance3D under a node is
## baked into one ArrayMesh with a surface per material, placed on the node itself. Collision bodies stay where they
## were; only their visual children are replaced. Label3Ds, MultiMeshes and anything animated are left alone.


## Merges the meshes under `root` (in root's space). Returns the number of MeshInstance3Ds removed.
static func merge(root: Node3D, cast_shadow: bool = true) -> int:
	var by_mat: Dictionary = {}  # Material -> SurfaceTool
	var mats: Array[Material] = []
	var gone: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var xf: Transform3D = BeachMerge._relative(root, mi)
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
	var mesh := ArrayMesh.new()
	for mat: Material in mats:
		var st: SurfaceTool = by_mat[mat]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	for mi: MeshInstance3D in gone:
		mi.get_parent().remove_child(mi)
		mi.free()
	var out := MeshInstance3D.new()
	out.name = "Merged"
	out.mesh = mesh
	out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(out)
	return gone.size()


static func _relative(root: Node3D, n: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## The material a surface draws with, ignoring material_override (the VRM body clears overrides every frame).
static func surface_material(mi: MeshInstance3D, s: int) -> Material:
	var m: Material = mi.get_surface_override_material(s)
	return m if m != null else mi.mesh.surface_get_material(s)


## One surface per material for a (skinned or plain) mesh: the arrays of every surface sharing a material are
## concatenated (bones, weights and blend shapes included), so a hair mesh cut into 60 surfaces over 3 materials costs
## 3 draw calls instead of 60. Returns the source mesh unchanged when nothing would be saved or the surfaces' formats
## differ. `cache` (source mesh -> result) lets every instance of a mesh share one copy.
static func compact(mi: MeshInstance3D, cache: Dictionary) -> ArrayMesh:
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() < 2:
		return mesh
	if cache.has(mesh):
		return cache[mesh] as ArrayMesh
	cache[mesh] = mesh
	var fmt: int = mesh.surface_get_format(0)
	var groups: Dictionary = {}  # Material -> Array[int] of surfaces
	var order: Array[Material] = []
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_format(s) != fmt or mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return mesh
		var mat: Material = BeachMerge.surface_material(mi, s)
		if not groups.has(mat):
			groups[mat] = []
			order.append(mat)
		(groups[mat] as Array).append(s)
	if order.size() == mesh.get_surface_count():
		return mesh
	var nb: int = mesh.get_blend_shape_count()
	var merged := ArrayMesh.new()
	merged.blend_shape_mode = mesh.blend_shape_mode
	for b: int in nb:
		merged.add_blend_shape(mesh.get_blend_shape_name(b))
	for mat: Material in order:
		var out: Array = []
		out.resize(Mesh.ARRAY_MAX)
		var blends: Array = []
		for b: int in nb:
			var ba: Array = []
			ba.resize(Mesh.ARRAY_MAX)
			blends.append(ba)
		var base: int = 0
		for s: int in groups[mat]:
			var arr: Array = mesh.surface_get_arrays(s)
			for k: int in Mesh.ARRAY_MAX:
				var v: Variant = arr[k]
				if v == null:
					continue
				if k == Mesh.ARRAY_INDEX and base > 0:
					var idx: PackedInt32Array = v
					for j: int in idx.size():
						idx[j] += base
					v = idx
				out[k] = BeachMerge._cat(out[k], v)
			if nb > 0:
				var sb: Array = mesh.surface_get_blend_shape_arrays(s)
				if sb.size() != nb:
					return mesh
				for b: int in nb:
					var src: Array = sb[b]
					var dst: Array = blends[b]
					for k: int in mini(src.size(), Mesh.ARRAY_MAX):
						if src[k] != null:
							dst[k] = BeachMerge._cat(dst[k], src[k])
			base += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, blends, {}, fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		merged.surface_set_material(merged.get_surface_count() - 1, mat)
	cache[mesh] = merged
	return merged


static func _cat(acc: Variant, v: Variant) -> Variant:
	if acc == null:
		return v
	var a: Variant = acc
	a.append_array(v)
	return a


## Compacts every multi-surface mesh under `root` (see compact) and drops its now index-mismatched surface overrides.
## Returns the surfaces saved.
static func compact_under(root: Node, cache: Dictionary) -> int:
	var saved: int = 0
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var am: ArrayMesh = mi.mesh as ArrayMesh
		if am == null or am.get_surface_count() < 2:
			continue
		var c: ArrayMesh = BeachMerge.compact(mi, cache)
		if c != am:
			saved += am.get_surface_count() - c.get_surface_count()
			mi.mesh = c
	return saved


## Compacts each pedestrian's body meshes once the crowd has dressed them (bodies arrive over a few frames).
class PedTrim:
	extends Node
	const VIEW_END: float = 60.0
	var crowd: Pedestrians = null
	var _done: Dictionary = {}
	var _cache: Dictionary = {}

	func _process(_delta: float) -> void:
		if crowd == null:
			set_process(false)
			return
		var left: int = 0
		for p: Pedestrian in crowd.people:
			if _done.has(p) or not is_instance_valid(p):
				continue
			if not p.has_body():
				left += 1
				continue
			BeachMerge.compact_under(p.body, _cache)
			# faces and hair add a dozen shadow-pass draws per person for shadows nobody sees: the body casts the shadow
			# and past VIEW_END a person is a few pixels tall: drawn beyond it, the long promenade alone costs ~150 draws
			for n: Node in p.body.find_children("*", "MeshInstance3D", true, false):
				var mi: MeshInstance3D = n as MeshInstance3D
				mi.visibility_range_end = VIEW_END
				if mi.name.begins_with("Face") or mi.name.begins_with("Hair"):
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_done[p] = true
		if left == 0 and _done.size() >= crowd.people.size():
			set_process(false)

	# The crowd keeps its look templates (whole VRM bodies) outside the tree and never frees them: free them with the
	# level, or every run ends with thousands of leaked nodes and render instances.
	func _notification(what: int) -> void:
		if what != NOTIFICATION_PREDELETE or crowd == null or not is_instance_valid(crowd):
			return
		for t: Variant in crowd.get("_templates"):
			var n: Node = t as Node
			if is_instance_valid(n) and not n.is_inside_tree() and n.get_parent() == null:
				n.free()

