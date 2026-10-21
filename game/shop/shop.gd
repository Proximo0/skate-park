class_name ShopRoom
extends Node3D
## The walk-in skate shop scene (game/shop/shop.tscn). The player walks around on foot (Skater in WALK, chased by
## SkateCamera) between stations; at a station a "Press E / A to ..." prompt shows, and interacting opens the
## SkateShop on a category, the CharacterCreator on a tab, sits on the couch, or leaves for the park.
## While a menu is open the player is frozen; on close the player's skater (and the board in the workbench vice)
## is rebuilt from the saved loadout so changes show at once. Scripted runs (tests, captures) never save: they use
## an in-memory wallet and loadout.
## The shop feeds the skater's input itself (scripted_input), so the interact button (A, shared with jump) doesn't
## also make the skater hop. Tests and sims drive it with `drive` (see drive_input()).

signal menu_opened(kind: String, arg: String)
signal menu_closed
signal leave_requested(scene: String)

const PARK_SCENE: String = "res://game/main.tscn"
const TITLE_SCENE: String = "res://game/ui/title_screen.tscn"
const INTERACT_ACTION: StringName = &"shop_interact"
const CLOSE_COOLDOWN: float = 0.3  ## ignore interact / pause this long after a menu closes (the same press)
const SKATER_BUTTONS: PackedStringArray = ["ollie", "flip", "grab", "grind", "spin_left", "spin_right", "revert",
		"nollie", "dismount"]

var interior: ShopInterior
var skater: Skater
var poser: ShopPoser
var camera: SkateCamera
var sit_cam: Camera3D
var hud: ShopHud
var npcs: Array[ShopNpc] = []
var stations: Array[ShopStation] = []
var focus: ShopStation = null
var overlay: Control = null
var overlay_kind: String = ""
var sitting: bool = false
var wallet: Wallet
var loadout: SkaterLoadout
var scripted: bool = false
var allow_scene_change: bool = true  ## tests turn this off and watch leave_requested instead
## Test / sim driving: when `drive` is true the stick and buttons come from drive_input() instead of the devices.
var drive: bool = false
var _drive_stick: Vector2 = Vector2.ZERO
var _drive_interact: bool = false
var _drive_buttons: Array = []
var _menu_layer: CanvasLayer
var _cooldown: float = 0.0
var _leaving: bool = false
var _sit_seat: int = 0


func _ready() -> void:
	process_physics_priority = -10  # read input before the skater ticks
	scripted = Flags.is_scripted_run()
	_ensure_interact_action()
	wallet = Wallet.new() if scripted else Wallet.load_file()
	loadout = SkaterLoadout.default_female() if scripted else SkaterLoadout.load_file()
	loadout.sanitize(func(id: String) -> bool: return wallet.owns(id))
	interior = ShopInterior.build(self)
	stations = interior.stations
	_spawn_player()
	_spawn_npcs()
	_shadows_for_characters_only()
	camera = SkateCamera.new()
	camera.name = "SkateCamera"
	camera.target = skater
	add_child(camera)
	camera.global_position = skater.global_position + Vector3(0, 1.4, 3.0)
	camera.make_current()
	sit_cam = Camera3D.new()
	sit_cam.name = "SitCamera"
	sit_cam.fov = 60.0
	add_child(sit_cam)
	sit_cam.global_transform = interior.sit_camera
	hud = ShopHud.new()
	hud.name = "ShopHud"
	hud.npcs = npcs
	add_child(hud)
	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "MenuLayer"
	_menu_layer.layer = 30
	add_child(_menu_layer)


## Adds the interact action (E, Enter, pad A) when the project doesn't define one.
static func _ensure_interact_action() -> void:
	if InputMap.has_action(INTERACT_ACTION):
		return
	InputMap.add_action(INTERACT_ACTION)
	for key: Key in [KEY_E, KEY_ENTER]:
		var ev: InputEventKey = InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(INTERACT_ACTION, ev)
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	InputMap.action_add_event(INTERACT_ACTION, pad)


# --- player -----------------------------------------------------------------------------------------------------

func _spawn_player() -> void:
	skater = Skater.new()
	skater.name = "Skater"
	skater.transform = interior.spawn
	skater.scripted_input = true
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	skater.add_child(visual)
	add_child(skater)
	skater.add_to_group("shop_player")
	_build_player_look()
	# Start on foot, carrying the board, already past the step-off.
	skater.state.event("dismount")
	skater.walker.begin(skater.facing, 0.0)
	skater.walker.step_time = Walker.STEP_OFF_TIME
	skater.set_input(Vector2.ZERO, [], [])


## (Re)builds the player's body and board from `loadout`, and the board in the workbench vice.
func _build_player_look() -> void:
	var visual: Node3D = skater.get_node("Visual") as Node3D
	for c: Node in visual.get_children():
		visual.remove_child(c)
		c.queue_free()
	if poser != null:
		poser.get_parent().remove_child(poser)
		poser.queue_free()
	var board: Node3D = SkaterBuilder.build_board(loadout)
	board.name = "Skateboard"
	visual.add_child(board)
	var body: Node3D = SkaterBuilder.build_body(loadout)
	body.name = "SkaterBody"
	body.position.y = PlaceholderSkater.DECK_TOP_Y
	visual.add_child(body)
	Toon.apply_to(visual)
	for mi: Node in visual.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	poser = ShopPoser.new()
	poser.name = "Poser"
	poser.skater = skater
	poser.body = body
	poser.board = board
	poser.mode = "sit" if sitting else ""
	skater.add_child(poser)
	if interior.vice != null:
		for c: Node in interior.vice.get_children():
			interior.vice.remove_child(c)
			c.queue_free()
		var vice_board: Node3D = SkaterBuilder.build_board(loadout)
		Toon.apply_to(vice_board)
		interior.vice.add_child(vice_board)


func _spawn_npcs() -> void:
	npcs = ShopNpc.cast(interior.npc_spots)
	for n: ShopNpc in npcs:
		add_child(n)


## Like main.gd: only the characters cast shadows; the room only receives them.
func _shadows_for_characters_only() -> void:
	for n: Node in interior.root.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- input and update ---------------------------------------------------------------------------------------------

## Scripted driving for tests and sims: the stick, a one-shot interact press, and one-shot skater buttons.
func drive_input(stick: Vector2, interact: bool = false, buttons: Array = []) -> void:
	drive = true
	_drive_stick = stick
	_drive_interact = interact
	_drive_buttons = buttons.duplicate()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var stick: Vector2 = _drive_stick if drive else Controls.move_vector()
	var interact: bool = _drive_interact if drive else Input.is_action_just_pressed(INTERACT_ACTION)
	var pressed: Array = []
	var held: Array = []
	if drive:
		pressed = _drive_buttons.duplicate()
		_drive_interact = false
		_drive_buttons.clear()
	else:
		for b: String in SKATER_BUTTONS:
			if Input.is_action_just_pressed(b):
				pressed.append(b)
			if Input.is_action_pressed(b):
				held.append(b)
	for npc: ShopNpc in npcs:
		npc.update_talk(skater.global_position, delta)
	if overlay != null or _leaving:
		skater.set_input(Vector2.ZERO, [], [])
		return
	if sitting:
		if _cooldown <= 0.0 and (interact or stick.length() > 0.5):
			stand_up()
		return
	if not drive and _cooldown <= 0.0 and Input.is_action_just_pressed("pause"):
		_go(TITLE_SCENE)
		return
	_update_focus()
	if focus != null:
		# A (interact) shares the jump button: at a station it interacts instead.
		pressed.erase("ollie")
		held.erase("ollie")
		if interact and _cooldown <= 0.0:
			use_station(focus)
			skater.set_input(Vector2.ZERO, [], [])
			return
	skater.set_input(stick, pressed, held)


func _update_focus() -> void:
	var st: SkateState.State = skater.state.state
	var can_use: bool = st == SkateState.State.WALK or st == SkateState.State.ROLLING
	var f: ShopStation = ShopStation.nearest(stations, skater.global_position) if can_use else null
	if f != focus:
		focus = f
		hud.show_prompt(focus)


## Refreshes the focused station now (tests teleport the player and call this).
func refresh_focus() -> ShopStation:
	_update_focus()
	return focus


func use_station(st: ShopStation) -> void:
	match st.action:
		"shop", "creator":
			open_menu(st.action, st.arg)
		"sit":
			sit_down()
		"exit":
			_go(PARK_SCENE)


# --- menus ----------------------------------------------------------------------------------------------------------

## Opens SkateShop ("shop", arg = category id) or CharacterCreator ("creator", arg = tab index) over the shop.
func open_menu(kind: String, arg: String) -> void:
	if overlay != null:
		return
	var screen: Control = null
	if kind == "shop":
		var s: SkateShop = SkateShop.new()
		s.setup(wallet if scripted else null, loadout if scripted else null, not scripted)
		screen = s
	else:
		var c: CharacterCreator = CharacterCreator.new()
		c.setup(wallet if scripted else null, loadout if scripted else null, not scripted)
		screen = c
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(screen)
	if screen is SkateShop:
		(screen as SkateShop).set_category(ShopStation.category_index(PartCatalog.load_default(), arg))
	elif screen is CharacterCreator:
		(screen as CharacterCreator).set_tab(int(arg))
	screen.connect(&"closed", _on_menu_closed)
	overlay = screen
	overlay_kind = kind
	hud.visible = false
	hud.show_prompt(null)
	focus = null
	menu_opened.emit(kind, arg)


func _on_menu_closed() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null
	overlay_kind = ""
	_cooldown = CLOSE_COOLDOWN
	if not scripted:
		wallet = Wallet.load_file()
		loadout = SkaterLoadout.load_file()
	loadout.sanitize(func(id: String) -> bool: return wallet.owns(id))
	_build_player_look()
	hud.visible = true
	menu_closed.emit()


func close_menu() -> void:
	if overlay != null:
		overlay.emit_signal(&"closed")


# --- sitting --------------------------------------------------------------------------------------------------------

## Sits the player on the free couch seat: physics stops, ShopPoser takes the sit pose, a fixed camera frames it.
func sit_down() -> void:
	if sitting:
		return
	sitting = true
	_cooldown = CLOSE_COOLDOWN
	_sit_seat = 0
	var seat: Transform3D = interior.seats[_sit_seat]
	skater.set_input(Vector2.ZERO, [], [])
	skater.velocity = Vector3.ZERO
	skater.set_physics_process(false)
	skater.global_position = seat.origin
	skater.facing = -seat.basis.z
	(skater.get_node("Visual") as Node3D).global_transform = seat
	poser.mode = "sit"
	poser.look_yaw = -24.0  # toward the TV, on the left of the seat
	sit_cam.make_current()
	hud.show_prompt(null)
	focus = null
	hud.set_hint("Chillin'...  E / A or move to get up")


func stand_up() -> void:
	if not sitting:
		return
	sitting = false
	_cooldown = CLOSE_COOLDOWN
	var seat: Transform3D = interior.seats[_sit_seat]
	var out: Vector3 = -seat.basis.z
	skater.global_position = seat.origin + out * 0.85 + Vector3(0, 0.05, -0.55)
	skater.velocity = Vector3.ZERO
	skater.walker.begin(out, 0.0)
	skater.walker.step_time = Walker.STEP_OFF_TIME
	skater.facing = out
	skater.set_physics_process(true)
	poser.mode = ""
	poser.look_yaw = 0.0
	camera.make_current()
	hud.set_hint("Walk up to anything to shop  -  Esc / Start: title")


# --- leaving ----------------------------------------------------------------------------------------------------------

func _go(scene: String) -> void:
	if _leaving:
		return
	_leaving = true
	leave_requested.emit(scene)
	if allow_scene_change and is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(scene)
