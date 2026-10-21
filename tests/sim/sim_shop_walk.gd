extends Node
## Walk-through of the shop with the real physics: the player walks (scripted stick, camera-relative like a pad)
## from the door to every station in turn, presses interact, and the right thing must happen: the SkateShop on the
## right category, the CharacterCreator on the right tab, sitting on the couch, or leaving for the park. Menus are
## closed again and the player must be rebuilt and back on foot. Also checks that pressing interact (A, the jump
## button) at a station doesn't make the player hop.
## Run: godot --headless --path . res://tests/sim/sim_shop_walk.tscn
## Prints "SIM shop_<station> PASS|FAIL <detail>" per station and "SIMS passed=N failed=M"; exit 1 on a failure.

const MAX_LEG_TIME: float = 12.0
const ARRIVE: float = 0.3

## station id, waypoints (x, z) leading to its stand point, expected [kind, arg]
const ROUTE: Array = [
	["boards", [Vector2(-1.5, 0.8), Vector2(-1.6, -1.5), Vector2(-3.5, -2.2)], ["shop", "decks"]],
	["shoes", [Vector2(-5.4, -1.2)], ["shop", "shoes"]],
	["clothes", [Vector2(-5.1, 0.0), Vector2(-4.95, 0.85)], ["shop", "clothing"]],
	["dressing", [Vector2(-1.8, 0.8)], ["creator", "1"]],
	["style", [Vector2(-1.0, -2.0), Vector2(4.0, -1.6)], ["creator", "0"]],
	["couch", [Vector2(4.2, -0.4)], ["sit", ""]],
	["door", [Vector2(2.0, 1.5), Vector2(0.0, 3.4)], ["exit", ""]],
]

var shop: ShopRoom
var passed: int = 0
var failed: int = 0
var _opened: Array = []
var _left: Array = []


func _ready() -> void:
	process_physics_priority = -20
	shop = (load("res://game/shop/shop.tscn") as PackedScene).instantiate() as ShopRoom
	shop.allow_scene_change = false
	add_child(shop)
	shop.menu_opened.connect(func(kind: String, arg: String) -> void: _opened.append([kind, arg]))
	shop.leave_requested.connect(func(scene: String) -> void: _left.append(scene))
	shop.drive_input(Vector2.ZERO)
	await _ticks(10)
	for leg: Array in ROUTE:
		await _leg(leg)
	print("SIMS passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _ticks(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _report(name: String, ok: bool, detail: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("SIM shop_%s %s %s" % [name, "PASS" if ok else "FAIL", detail])


## Stick that walks toward a world point, seen from the current camera (as a player would push it).
func _stick_toward(target: Vector3, tilt: float) -> Vector2:
	var p: Vector3 = shop.skater.global_position
	var d: Vector3 = Vector3(target.x - p.x, 0.0, target.z - p.z)
	if d.length() < 0.001:
		return Vector2.ZERO
	d = d.normalized()
	var cam: Camera3D = get_viewport().get_camera_3d()
	var yaw: float = Walker.yaw_from_forward(-cam.global_basis.z, 0.0) if cam != null else 0.0
	var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	return Vector2(d.dot(right), -d.dot(fwd)) * tilt


func _walk_to(target: Vector3) -> float:
	var t: float = 0.0
	while t < MAX_LEG_TIME:
		var p: Vector3 = shop.skater.global_position
		var dist: float = Vector2(target.x - p.x, target.z - p.z).length()
		if dist < ARRIVE:
			break
		shop.drive_input(_stick_toward(target, 0.85 if dist > 1.0 else 0.5))
		await get_tree().physics_frame
		t += 1.0 / 60.0
	shop.drive_input(Vector2.ZERO)
	return t


func _leg(leg: Array) -> void:
	var id: String = str(leg[0])
	var st: ShopStation = ShopStation.by_id(shop.stations, id)
	var want: Array = leg[2]
	var took: float = 0.0
	for w: Vector2 in leg[1]:
		took += await _walk_to(Vector3(w.x, 0.0, w.y))
	took += await _walk_to(st.stand)
	await _ticks(20)
	var at: Vector3 = shop.skater.global_position
	var focus_ok: bool = shop.focus == st
	if not focus_ok:
		_report(id, false, "never reached: at (%.2f, %.2f) after %.1f s, focus %s" % [at.x, at.z, took, shop.focus.id if shop.focus else "none"])
		return
	var y0: float = at.y
	_opened.clear()
	_left.clear()
	shop.drive_input(Vector2.ZERO, true, ["ollie"])  # the A press also arrives as the skater's jump button
	await _ticks(2)
	var hopped: bool = shop.skater.global_position.y > y0 + 0.05
	var ok: bool = not hopped
	var detail: String = "walked %.1f s" % took
	match str(want[0]):
		"shop", "creator":
			ok = ok and _opened.size() == 1 and str(_opened[0][0]) == str(want[0]) and str(_opened[0][1]) == str(want[1])
			if shop.overlay is SkateShop:
				var cat: PartCatalog = PartCatalog.load_default()
				ok = ok and int(shop.overlay.get("_category")) == ShopStation.category_index(cat, str(want[1]))
			elif shop.overlay is CharacterCreator:
				ok = ok and int(shop.overlay.get("_tab")) == int(want[1])
			else:
				ok = false
			# frozen while the menu is up, even with the stick held
			var before: Vector3 = shop.skater.global_position
			shop.drive_input(Vector2(0.0, -1.0))
			await _ticks(30)
			var drift: float = shop.skater.global_position.distance_to(before)
			ok = ok and drift < 0.05
			var old_body: Node = shop.skater.get_node("Visual/SkaterBody")
			shop.close_menu()
			shop.drive_input(Vector2.ZERO)
			await _ticks(25)
			ok = ok and shop.overlay == null and shop.skater.get_node_or_null("Visual/SkaterBody") != old_body
			ok = ok and shop.skater.state.state == SkateState.State.WALK
			detail += ", opened %s, frozen drift %.3f m, closed and rebuilt" % [str(_opened), drift]
		"sit":
			ok = ok and shop.sitting and shop.poser.mode == "sit"
			await _ticks(40)
			shop.drive_input(Vector2(0.0, -1.0))
			await _ticks(2)
			shop.drive_input(Vector2.ZERO)
			ok = ok and not shop.sitting
			await _ticks(20)
			detail += ", sat and stood up at (%.2f, %.2f)" % [shop.skater.global_position.x, shop.skater.global_position.z]
		"exit":
			ok = ok and _left == [ShopRoom.PARK_SCENE]
			detail += ", left for %s" % str(_left)
	if hopped:
		detail += ", HOPPED on interact"
	_report(id, ok, detail)
