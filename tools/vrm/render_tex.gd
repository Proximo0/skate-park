extends SceneTree
# Verification renders of avatarsample_g with repainted textures applied by surface override.
# xvfb-run -a godot --rendering-driver opengl3 --path /tmp/lead/vroid/proj -s render_tex.gd -- <texdir> <outdir> [bikini_png] [views]
const TEX := "/home/claude/skate/assets/characters/vrm/textures"
var texdir := TEX
var outdir := "/tmp/lead/vrm_tex/shots"
var bikini := "body_skin_bikini_coral.png"

func img_tex(path: String) -> Texture2D:
	return ImageTexture.create_from_image(Image.load_from_file(path))

func swap(mi: MeshInstance3D, s: int, params: Dictionary) -> void:
	var m := mi.get_active_material(s).duplicate() as ShaderMaterial
	for k in params:
		m.set_shader_parameter(k, params[k])
	mi.set_surface_override_material(s, m)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: texdir = a[0]
	if a.size() > 1: outdir = a[1]
	if a.size() > 2: bikini = a[2]
	var only: PackedStringArray = a[3].split(",") if a.size() > 3 else PackedStringArray()
	DirAccess.make_dir_recursive_absolute(outdir)
	DisplayServer.window_set_size(Vector2i(600, 900))
	get_root().size = Vector2i(600, 900)
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.65, 0.75)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.65, 0.65, 0.65)
	var we := WorldEnvironment.new(); we.environment = e; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 25, 0); root.add_child(sun)
	var cam := Camera3D.new(); cam.fov = 30; root.add_child(cam)
	var inst: Node3D = (load("res://models/avatarsample_g.vrm") as PackedScene).instantiate()
	root.add_child(inst)
	var body := inst.find_child("Body", true, false) as MeshInstance3D
	var hair := inst.find_child("Hair001", true, false) as MeshInstance3D
	var bt := img_tex(texdir + "/" + bikini)
	for s in 4:
		swap(body, s, {"_MainTex": bt, "_ShadeTexture": bt})
	var clear := StandardMaterial3D.new(); clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; clear.albedo_color = Color(0, 0, 0, 0)
	if not (a.size() > 4 and a[4] == "showdress"):
		body.set_surface_override_material(4, clear)
	# hair / eyes
	var hm := {"F00_000_Hair_00_HAIR_01": "hair_main", "F00_000_Hair_00_HAIR_02": "hair_main2", "F00_000_Hair_00_HAIR_03": "ribbon"}
	var gp := texdir + "/hair_gold_params.json"
	var hp := {}
	if FileAccess.file_exists(gp):
		hp = JSON.parse_string(FileAccess.get_file_as_string(gp))
	var cache := {}
	for mi in [hair, body]:
		for s in mi.mesh.get_surface_count():
			var n: String = mi.get_active_material(s).resource_name
			var key := ""
			if hm.has(n): key = hm[n]
			elif n == "F00_000_HairBack_00_HAIR": key = "hair_back"
			if key == "": continue
			var p := texdir + "/" + key + ".png"
			if not FileAccess.file_exists(p): continue
			if not cache.has(key):
				var d := {"_MainTex": img_tex(p), "_ShadeTexture": img_tex(texdir + "/" + key + "_shade.png" if FileAccess.file_exists(texdir + "/" + key + "_shade.png") else p)}
				var ep := texdir + "/" + key + "_emission.png"
				if FileAccess.file_exists(ep): d["_EmissionMap"] = img_tex(ep)
				if hp.has(key):
					for k in hp[key]:
						var v = hp[key][k]
						d[k] = Color(v[0], v[1], v[2], v[3]) if v is Array else v
				cache[key] = d
			swap(mi, s, cache[key])
	var ip := texdir + "/eye_iris.png"
	if FileAccess.file_exists(ip):
		var face := inst.find_child("Face", true, false) as MeshInstance3D
		var t := img_tex(ip)
		swap(face, 5, {"_MainTex": t, "_ShadeTexture": t})
	await process_frame
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var views := [
		["front", 0.0, 0.0, 0.9, 3.3], ["back", 180.0, 0.0, 0.9, 3.3], ["side", 90.0, 0.0, 0.9, 3.3],
		["q34", 35.0, 0.0, 0.9, 3.3], ["below", 25.0, -0.9, 0.7, 2.2],
		["chest", 20.0, 0.0, 1.25, 1.1], ["hips", 20.0, 0.0, 0.95, 1.1], ["hipsback", 200.0, 0.0, 0.95, 1.1],
		["face", 15.0, 0.0, 1.62, 0.85], ["hairback", 160.0, 0.0, 1.5, 1.3],
	]
	for v in views:
		if only.size() > 0 and not only.has(v[0]): continue
		var yaw: float = deg_to_rad(v[1])
		var tgt := Vector3(0, v[3], 0)
		cam.position = tgt + Vector3(sin(yaw), v[2] * 0.5, cos(yaw)) * v[4]
		cam.look_at(tgt)
		for i in 4: await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [outdir, v[0]])
	# crouch / arms up pose
	if only.size() == 0 or only.has("crouch"):
		var pose := {"LeftUpperArm": Vector3(0, 0, 80), "RightUpperArm": Vector3(0, 0, -80), "LeftUpperLeg": Vector3(-60, 0, 0), "RightUpperLeg": Vector3(-60, 0, 0),
			"LeftLowerLeg": Vector3(80, 0, 0), "RightLowerLeg": Vector3(80, 0, 0), "Spine": Vector3(25, 0, 0), "Hips": Vector3(0, 0, 0)}
		for b in pose:
			var bi := sk.find_bone(b)
			if bi < 0: continue
			sk.set_bone_pose_rotation(bi, sk.get_bone_rest(bi).basis.get_rotation_quaternion() * Quaternion.from_euler(Vector3(deg_to_rad(pose[b].x), deg_to_rad(pose[b].y), deg_to_rad(pose[b].z))))
		for vv in [["crouch_front", 20.0], ["crouch_back", 200.0]]:
			var yaw2: float = deg_to_rad(vv[1])
			cam.position = Vector3(0, 0.9, 0) + Vector3(sin(yaw2), 0, cos(yaw2)) * 3.3
			cam.look_at(Vector3(0, 0.8, 0))
			for i in 4: await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [outdir, vv[0]])
	# legs spread view (inner thigh / gusset check): reset arms, spread and bend legs, camera below
	if only.size() == 0 or only.has("spread"):
		for bi in sk.get_bone_count():
			sk.set_bone_pose_rotation(bi, sk.get_bone_rest(bi).basis.get_rotation_quaternion())
		var sp := {"LeftUpperLeg": Vector3(-40, 0, -35), "RightUpperLeg": Vector3(-25, 0, 35), "LeftLowerLeg": Vector3(50, 0, 0), "RightLowerLeg": Vector3(40, 0, 0)}
		for b in sp:
			var bi2 := sk.find_bone(b)
			if bi2 >= 0:
				sk.set_bone_pose_rotation(bi2, sk.get_bone_rest(bi2).basis.get_rotation_quaternion() * Quaternion.from_euler(Vector3(deg_to_rad(sp[b].x), deg_to_rad(sp[b].y), deg_to_rad(sp[b].z))))
		for vv in [["spread_below_front", 15.0, -0.6], ["spread_below_back", 195.0, -0.6], ["spread_below_side", 80.0, -0.5], ["spread_below_side2", 280.0, -0.5]]:
			var yaw3: float = deg_to_rad(vv[1])
			var tg := Vector3(0, 0.85, 0)
			cam.position = tg + Vector3(sin(yaw3), vv[2], cos(yaw3)) * 1.1
			cam.look_at(tg)
			for i in 4: await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [outdir, vv[0]])
	quit()
