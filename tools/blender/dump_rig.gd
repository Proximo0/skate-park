extends SceneTree
## Dumps the code-built skater rig to JSON for the Blender pipeline (tools/blender/base_body.py reads it).
## For each body type: every SkaterPoser.JOINTS joint and BodySway_Bust pivot with its parent, its body-space
## rest transform (as PlaceholderSkater.build_body leaves it) and its model-pose transform
## (SkinnedBody.neutral_globals: zero rotations, upper arms out at SkinnedBody.NEUTRAL_ARM), plus the skeleton
## constants. Godot space: Y up, metres, the body faces -Z, Left = -X.
## Run (after an import): timeout 300 xvfb-run -a godot --rendering-driver opengl3 --path . \
##     -s res://tools/blender/dump_rig.gd -- --out=tools/blender/rig_rest.json

var _out_path: String = "res://tools/blender/rig_rest.json"


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out_path = a.substr(6)
	call_deferred("_run")


func _xf(t: Transform3D) -> Array:
	var b: Basis = t.basis
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, t.origin.x, t.origin.y, t.origin.z]


func _body_space(body: Node3D, n: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != body:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


func _run() -> void:
	var ps: GDScript = load("res://game/skater/placeholder_skater.gd") as GDScript
	var poser: GDScript = load("res://game/skater/skater_poser.gd") as GDScript
	var sb: GDScript = load("res://game/skater/skinned_body.gd") as GDScript
	var joints: PackedStringArray = poser.get("JOINTS")
	var extra: Dictionary = sb.get("EXTRA_BONES")
	var out: Dictionary = {
		"neutral_arm": sb.get("NEUTRAL_ARM"),
		"constants": {},
		"bodies": {},
	}
	for k: String in ["HIP_HEIGHT", "UPPER_LEG", "LOWER_LEG", "ANKLE_HEIGHT", "HIP_SPREAD", "UPPER_ARM", "LOWER_ARM",
			"ARM_OUT", "FOREARM_BEND", "SPINE_UP", "CHEST_UP", "NECK_UP", "HEAD_UP", "HAND_SCALE"]:
		out["constants"][k] = ps.get(k)
	var sh: Vector2 = ps.get("SHOULDER")
	out["constants"]["SHOULDER"] = [sh.x, sh.y]
	for body_type: String in ["female", "male"]:
		var body: Node3D = ps.call("build_body", {}, {"body": body_type})
		get_root().add_child(body)
		var neutral: Dictionary = sb.call("neutral_globals", body)
		var nodes: Dictionary = {}
		var names: Array = Array(joints) + extra.values()
		for nm: String in names:
			var n: Node3D = body.find_child(nm, true, false) as Node3D
			if n == null:
				if joints.has(nm):  # the male body has no bust pivots, so no BustL/R bones
					push_error("dump_rig: %s has no joint %s" % [body_type, nm])
				continue
			nodes[nm] = {
				"parent": str(n.get_parent().name) if n.get_parent() != body else "",
				"local_position": [n.position.x, n.position.y, n.position.z],
				"rest": _xf(_body_space(body, n)),
				"neutral": _xf(neutral.get(nm, Transform3D.IDENTITY)),
			}
		out["bodies"][body_type] = {"nodes": nodes, "extra_bones": extra}
		body.queue_free()
	var f: FileAccess = FileAccess.open(_out_path, FileAccess.WRITE)
	if f == null:
		push_error("dump_rig: cannot write " + _out_path)
		quit(1)
		return
	f.store_string(JSON.stringify(out, "\t", true))
	f.close()
	print("dump_rig: wrote ", _out_path)
	quit(0)
