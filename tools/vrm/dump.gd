extends SceneTree
# Dumps per-surface material info, textures (PNG) and mesh arrays (rest pose) of avatarsample_g.
# Usage: godot --headless --path /tmp/lead/vroid/proj -s <this> -- <outdir>
func _init() -> void:
	var out := "/tmp/lead/vrm_tex/dump"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var inst: Node = (load("res://models/avatarsample_g.vrm") as PackedScene).instantiate()
	root.add_child(inst)
	var info := []
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var rec := {"mesh": mi.name, "surf": s, "mat": mat.resource_name, "class": mat.get_class()}
			if mat is ShaderMaterial:
				var sm := mat as ShaderMaterial
				rec["shader"] = sm.shader.resource_path
				var tex := {}
				for p in sm.shader.get_shader_uniform_list():
					var v = sm.get_shader_parameter(p.name)
					if v is Texture2D:
						var t := v as Texture2D
						var fn := "%s_%d_%s.png" % [mi.name, s, p.name]
						var img := t.get_image()
						if img.is_compressed(): img.decompress()
						img.save_png(out + "/" + fn)
						tex[p.name] = [fn, t.get_width(), t.get_height()]
				rec["tex"] = tex
			var arr := mi.mesh.surface_get_arrays(s)
			var f := FileAccess.open("%s/%s_%d.json" % [out, mi.name, s], FileAccess.WRITE)
			var P: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var U: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var pf := PackedFloat32Array(); for v in P: pf.append_array([v.x, v.y, v.z])
			var uf := PackedFloat32Array(); for v in U: uf.append_array([v.x, v.y])
			f.store_string(JSON.stringify({"pos": Array(pf), "uv": Array(uf), "idx": Array(I)}))
			f.close()
			info.append(rec)
	var f := FileAccess.open(out + "/info.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(info, "  "))
	f.close()
	print(JSON.stringify(info, " "))
	quit()
