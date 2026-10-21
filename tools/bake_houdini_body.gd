extends SceneTree
## Bakes HoudiniBody.prepared() for both body types into assets/characters/houdini/base_body_<type>_prepared.res
## (run through tools/bake_houdini_body.sh after changing game/skater/houdini_body.gd or a base body .glb).


func _init() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var failed: bool = false
	for kind: String in ["female", "male"]:
		var t0: int = Time.get_ticks_msec()
		var err: Error = HoudiniBody.bake(kind)
		print("%s: %s (%d ms)" % [kind, error_string(err), Time.get_ticks_msec() - t0])
		failed = failed or err != OK
	quit(1 if failed else 0)
