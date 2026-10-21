extends Node3D
## The game scene: the park, the skater and everything that watches the skater (camera, poser, HUD,
## effects, audio, goals, pause menu, debug stamp). `-- --testpark` loads the small proving ground instead.

var park: Node3D
var skater: Skater
var hud: Hud
var goals: Goals
var _t: float = 0.0
var _prev_state: SkateState.State = SkateState.State.ROLLING
var _hold_time: float = 0.0


func _ready() -> void:
	if Flags.args.has("testpark"):
		park = (load("res://game/park/test_park.tscn") as PackedScene).instantiate()
		add_child(park)
		skater = park.get("skater")
		(park.get_node("ChaseCam") as Camera3D).queue_free()
	else:
		park = Park.new()
		park.name = "Park"
		add_child(park)
		skater = _make_skater((park as Park).spawn)
		add_child(skater)
	_skater_only_shadows()
	_attach_poser()
	var cam := SkateCamera.new()
	cam.name = "SkateCamera"
	cam.target = skater
	add_child(cam)
	cam.global_position = skater.global_position + Vector3(0, 2, 4.5)
	cam.make_current()
	hud = Hud.new()
	add_child(hud)
	hud.bind(skater)
	var fx := SkateFx.new()
	add_child(fx)
	fx.bind(skater)
	var recorder := PhysicsRecorder.new()
	add_child(recorder)
	recorder.bind(skater)
	var audio := SkateAudio.new()
	add_child(audio)
	audio.bind(skater)
	var pause := PauseMenu.new()
	add_child(pause)
	pause.restart_requested.connect(_restart)
	pause.drop_in_requested.connect(_drop_in)
	pause.quit_requested.connect(func() -> void: get_tree().change_scene_to_file("res://game/ui/title_screen.tscn"))
	add_child(FrameStamp.new())
	add_child(RenderToggles.new())
	add_child(TuningPanel.new())
	_setup_goals()


func _make_skater(at: Transform3D) -> Skater:
	var s := Skater.new()
	s.name = "Skater"
	s.transform = at
	var visual := Node3D.new()
	visual.name = "Visual"
	var board: Node3D = ArtSlots.instance("skater_board", PlaceholderSkater.build_board)
	board.name = "Skateboard"
	visual.add_child(board)
	var body: Node3D = ArtSlots.instance("skater_body", PlaceholderSkater.build_body)
	body.name = "SkaterBody"
	body.position = Vector3(0, PlaceholderSkater.DECK_TOP_Y, 0)
	visual.add_child(body)
	Toon.apply_to(visual)
	s.add_child(visual)
	return s


func _attach_poser() -> void:
	var visual: Node3D = skater.get_node("Visual")
	var poser := SkaterPoser.new()
	poser.name = "Poser"
	poser.skater = skater
	poser.body = visual.get_node_or_null("SkaterBody")
	poser.board = visual.get_node_or_null("Skateboard")
	if poser.body != null and poser.board != null:
		skater.add_child(poser)


func _setup_goals() -> void:
	goals = Goals.load_default()
	goals.start_run(_t)
	goals.goal_completed.connect(_on_goal)
	skater.combo_landed.connect(func(points: int, _text: String) -> void:
		goals.on_combo_landed(points, skater.combo.landed_total, []))
	skater.trick_started.connect(func(tr: Dictionary) -> void:
		goals.on_trick(str(tr.get("id", "")), str(tr.get("kind", ""))))
	skater.gap_hit.connect(func(_n: String, _p: int) -> void:
		goals.on_gap_discovered(skater.gaps.discovered_count()))
	if park is Park:
		for c: Collectible in (park as Park).collectibles:
			c.collected.connect(func(item: String, _group: String) -> void: goals.on_collect(item))
	var panel := GoalsPanel.new()
	panel.name = "GoalsPanel"
	add_child(panel)
	panel.bind(goals, func() -> float: return _t)


func _on_goal(goal: Dictionary) -> void:
	if hud.has_method("_show_banner"):
		hud.call("_show_banner", "GOAL! " + str(goal.get("title", "")))


func _process(delta: float) -> void:
	_t += delta
	goals.tick(_t)
	# hold-time goals: report each finished manual or grind
	var st: SkateState.State = skater.state.state
	if st == _prev_state and (st == SkateState.State.MANUAL or st == SkateState.State.GRIND):
		_hold_time += delta
	elif st != _prev_state:
		if _prev_state == SkateState.State.MANUAL:
			goals.on_hold("manual", _hold_time)
		elif _prev_state == SkateState.State.GRIND:
			goals.on_hold("grind", _hold_time)
		_hold_time = 0.0
		_prev_state = st


func _restart() -> void:
	skater.respawn()
	goals.start_run(_t)


## Pause menu "Drop In": put the skater on top of the mega ramp ("mega") or the drop ramp before the loop ("loop").
func _drop_in(spot: String) -> void:
	if not (park is Park):
		return
	var spots: Dictionary = (park as Park).drop_ins
	if spots.has(spot):
		DropIn.teleport(skater, spots[spot] as Transform3D)


## Only the skater casts a shadow: it shows where you'll land, while park shadows only cluttered the scene
## (playtest feedback). The ground still receives it. A shorter shadow range keeps it crisp.
func _skater_only_shadows() -> void:
	for n: Node in park.find_children("*", "GeometryInstance3D", true, false):
		if not skater.is_ancestor_of(n):
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for n: Node in park.find_children("*", "DirectionalLight3D", true, false):
		(n as DirectionalLight3D).directional_shadow_max_distance = 40.0
