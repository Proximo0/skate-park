extends Node3D
## The game scene: the level, the skater and everything that watches the skater (camera, poser, HUD,
## effects, audio, goals, pause menu, debug stamp). The level comes from LevelRegistry (`-- --level=<id>` or the
## level select; the practice Park by default). `-- --testpark` loads the small proving ground instead.

const MAIN_SCENE: String = "res://game/main.tscn"

var park: Node3D  ## the level node (named "Park" whatever the level, for older paths); the test park with --testpark
var level: Level = null  ## the same node as a Level; null with --testpark
var skater: Skater
var hud: Hud
var goals: Goals
var wallet: Wallet
var loadout: SkaterLoadout = null  ## null in scripted runs: they keep the stock placeholder look (goldens, captures)
var _t: float = 0.0
var _prev_state: SkateState.State = SkateState.State.ROLLING
var _hold_time: float = 0.0


func _ready() -> void:
	wallet = Wallet.new() if Flags.is_scripted_run() else Wallet.load_file()
	if not Flags.is_scripted_run():
		loadout = SkaterLoadout.load_file()
		loadout.sanitize(func(id: String) -> bool: return wallet.owns(id))
	if Flags.args.has("testpark"):
		park = (load("res://game/park/test_park.tscn") as PackedScene).instantiate()
		add_child(park)
		skater = park.get("skater")
		(park.get_node("ChaseCam") as Camera3D).queue_free()
	else:
		level = LevelRegistry.create(LevelRegistry.resolve(Flags.args))
		level.name = "Park"
		park = level
		add_child(level)
		skater = _make_skater(level.spawn)
		add_child(skater)
		_apply_level_rules()
	skater.add_to_group("skater")
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
	if level != null:
		pause.drop_in_spots = level.drop_in_names.duplicate()
		pause.current_level = level.level_id
	add_child(pause)
	pause.restart_requested.connect(_restart)
	pause.drop_in_requested.connect(_drop_in)
	pause.level_change_requested.connect(_change_level)
	pause.quit_requested.connect(func() -> void: get_tree().change_scene_to_file("res://game/ui/title_screen.tscn"))
	add_child(FrameStamp.new())
	add_child(RenderToggles.new())
	add_child(TuningPanel.new())
	var overlay := PhysicsOverlay.new()
	add_child(overlay)
	overlay.bind(skater)
	add_child(TimeControl.new())
	_setup_goals()


## The level's own rules: its kill height (on a private copy of the tuning, so the shared one keeps its default),
## its gap list, and the skater handed to the level's world nodes (traffic, pedestrians).
func _apply_level_rules() -> void:
	if not is_equal_approx(level.kill_y, skater.tune.kill_y):
		var t := PhysicsTuning.new()
		t.apply_dict(skater.tune.to_dict())
		t.kill_y = level.kill_y
		skater.tune = t
	if level.gaps_path != Level.DEFAULT_GAPS and FileAccess.file_exists(level.gaps_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(level.gaps_path))
		if parsed is Dictionary:
			skater.gaps.load_from_dict(parsed as Dictionary)
	level.bind_skater(skater)


## Pause menu "Change level": rebuild the game scene with the picked level.
func _change_level(id: String) -> void:
	LevelRegistry.selected = id
	get_tree().change_scene_to_file(MAIN_SCENE)


func _make_skater(at: Transform3D) -> Skater:
	var s := Skater.new()
	s.name = "Skater"
	s.transform = at
	var visual := Node3D.new()
	visual.name = "Visual"
	var board: Node3D = ArtSlots.instance("skater_board", _build_board)
	board.name = "Skateboard"
	visual.add_child(board)
	var body: Node3D = ArtSlots.instance("skater_body", _build_body)
	body.name = "SkaterBody"
	body.position = Vector3(0, PlaceholderSkater.DECK_TOP_Y, 0)
	visual.add_child(body)
	Toon.apply_to(visual)
	s.add_child(visual)
	return s


func _build_board() -> Node3D:
	return PlaceholderSkater.build_board() if loadout == null else SkaterBuilder.build_board(loadout)


func _build_body() -> Node3D:
	return PlaceholderSkater.build_body() if loadout == null else SkaterBuilder.build_body(loadout)


## Coins for a landed combo or a finished goal; saved right away (never in scripted runs).
func _earn(coins: int) -> void:
	if coins <= 0:
		return
	wallet.add(coins)
	if not Flags.is_scripted_run():
		wallet.save()


func _attach_poser() -> void:
	var visual: Node3D = skater.get_node("Visual")
	var poser := SkaterPoser.new()
	poser.name = "Poser"
	poser.skater = skater
	poser.body = visual.get_node_or_null("SkaterBody")
	poser.board = visual.get_node_or_null("Skateboard")
	if poser.body != null and poser.board != null:
		skater.add_child(poser)
	var sway := SecondaryMotion.new()  # visual-only hair and body sway; not in the physics snapshot
	sway.name = "SecondaryMotion"
	skater.add_child(sway)
	sway.bind(visual)


func _setup_goals() -> void:
	if level != null and level.goals_path != Level.DEFAULT_GOALS:
		goals = Goals.new()
		goals.load_from_path(level.goals_path)
	else:
		goals = Goals.load_default()
	goals.start_run(_t)
	goals.goal_completed.connect(_on_goal)
	skater.combo_landed.connect(func(points: int, _text: String) -> void:
		_earn(Wallet.coins_for_combo(points))
		goals.on_combo_landed(points, skater.combo.landed_total, []))
	skater.trick_started.connect(func(tr: Dictionary) -> void:
		goals.on_trick(str(tr.get("id", "")), str(tr.get("kind", ""))))
	skater.gap_hit.connect(func(_n: String, _p: int) -> void:
		goals.on_gap_discovered(skater.gaps.discovered_count()))
	if level != null:
		for c: Collectible in level.collectibles:
			c.collected.connect(func(item: String, _group: String) -> void: goals.on_collect(item))
	var panel := GoalsPanel.new()
	panel.name = "GoalsPanel"
	add_child(panel)
	panel.bind(goals, func() -> float: return _t)


func _on_goal(goal: Dictionary) -> void:
	_earn(Wallet.COINS_PER_GOAL)
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
	skater.combo.landed_total = 0  ## a retry is a fresh run: run-score goals must not carry the old total
	goals.start_run(_t)


## Pause menu "Drop In": put the skater on the level's drop-in spot (practice: "mega" or "loop").
func _drop_in(spot: String) -> void:
	if level == null:
		return
	var spots: Dictionary = level.drop_ins
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
