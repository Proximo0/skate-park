extends SceneTree
## Rebuilds game/ui/theme/skate_theme.tres from SkateThemeBuilder. Run after changing the builder:
##   godot --headless --path . -s tools/build_theme.gd


func _init() -> void:
	var theme: Theme = SkateThemeBuilder.build()
	var err: int = ResourceSaver.save(theme, SkateThemeBuilder.THEME_PATH)
	if err != OK:
		printerr("build_theme: save failed (%d)" % err)
		quit(1)
		return
	print("build_theme: wrote ", SkateThemeBuilder.THEME_PATH)
	quit()
