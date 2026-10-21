class_name ShopNpc
extends Node3D
## An idle skater in the shop: a PlaceholderSkater body and board in its own colours, posed by ShopPoser ("stand",
## "counter" or "sit"). An NPC with `lines` speaks: walking within TALK_RADIUS shows the next line in a speech
## bubble (ShopHud draws it) for LINE_TIME; it won't repeat until the player has walked away and come back.
## Standing talkers turn to face the player while they talk.

const CHAR_SHADER: Shader = preload("res://game/shop/shop_char.gdshader")
const TALK_RADIUS: float = 2.6
const LEAVE_RADIUS: float = 3.4  ## the player must get this far away before the next line can start
const LINE_TIME: float = 4.5
const TURN_RATE: float = 4.0
const HEAD_HEIGHT: float = 1.85  ## where the bubble anchors, above the head (scaled with the NPC)

var role: String = ""
var display_name: String = ""
var lines: PackedStringArray = []
var pose_mode: String = "stand"
var poser: ShopPoser
var body: Node3D
var board: Node3D
var line_index: int = -1  ## index of the line being shown (or last shown), -1 before the first
var bubble_left: float = 0.0  ## seconds the current bubble stays up
var _armed: bool = true
var _rest_yaw: float = 0.0


## Builds an NPC from a loadout plus extra palette keys (hair ties, trims) for variety.
static func create(role_: String, name_: String, look: SkaterLoadout, extra: Dictionary, mode: String,
		lines_: PackedStringArray, sway: float) -> ShopNpc:
	var n: ShopNpc = ShopNpc.new()
	n.name = "Npc_" + role_
	n.role = role_
	n.display_name = name_
	n.lines = lines_
	n.pose_mode = mode
	var palette: Dictionary = SkaterBuilder.body_palette(look)
	palette.merge(extra, true)
	n.board = SkaterBuilder.build_board(look)
	n.board.name = "Skateboard"
	n.add_child(n.board)
	n.body = PlaceholderSkater.build_body(palette, SkaterBuilder.body_options(look))
	n.body.name = "SkaterBody"
	n.body.position.y = PlaceholderSkater.DECK_TOP_Y
	n.add_child(n.body)
	Toon.apply_to(n)
	_soften_lighting(n)
	n.poser = ShopPoser.new()
	n.poser.name = "Poser"
	n.poser.body = n.body
	n.poser.board = n.board
	n.poser.mode = mode
	n.poser.sway_phase = sway
	n.add_child(n.poser)
	if mode == "counter":
		n.board.visible = false
	return n


## Swaps the shared toon materials under `root` for the shop character shader (same albedo, lower light), so skin and
## clothes keep their colour under the lamps and the sun.
static func _soften_lighting(root: Node) -> void:
	var cache: Dictionary = {}
	_soften_node(root, cache)


static func _soften_node(node: Node, cache: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		var src: ShaderMaterial = mi.material_override as ShaderMaterial
		if src != null and src.shader == Toon.TOON_SHADER:
			var a: Color = src.get_shader_parameter("albedo") as Color if src.get_shader_parameter("albedo") != null else Color.WHITE
			var vc: float = float(src.get_shader_parameter("vertex_color_amount") if src.get_shader_parameter("vertex_color_amount") != null else 0.0)
			var key: String = "%s|%s" % [a.to_html(true), vc]
			if not cache.has(key):
				var m: ShaderMaterial = ShaderMaterial.new()
				m.shader = CHAR_SHADER
				m.set_shader_parameter("albedo", a)
				m.set_shader_parameter("vertex_color_amount", vc)
				cache[key] = m
			mi.material_override = cache[key] as ShaderMaterial
	for c: Node in node.get_children():
		_soften_node(c, cache)


func _ready() -> void:
	_rest_yaw = rotation.y


## Advances the talk state for a player at `player_pos`. Returns true on the frame a new line starts.
func update_talk(player_pos: Vector3, delta: float) -> bool:
	bubble_left = maxf(bubble_left - delta, 0.0)
	if lines.is_empty():
		return false
	var d: float = Vector2(player_pos.x - global_position.x, player_pos.z - global_position.z).length()
	var started: bool = false
	if d <= TALK_RADIUS and _armed:
		line_index = (line_index + 1) % lines.size()
		bubble_left = LINE_TIME
		_armed = false
		started = true
	elif d >= LEAVE_RADIUS:
		_armed = true
	return started


func is_talking() -> bool:
	return bubble_left > 0.0 and line_index >= 0 and line_index < lines.size()


func current_line() -> String:
	return lines[line_index] if is_talking() else ""


## Bubble anchor in world space.
func bubble_anchor() -> Vector3:
	var up: float = HEAD_HEIGHT * scale.y
	if pose_mode == "sit":
		up -= 0.4 * scale.y
	return global_position + Vector3.UP * up


func _process(delta: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	# Standing talkers turn toward the player while the bubble is up, then back to their rest yaw.
	if pose_mode == "stand":
		var want: float = _rest_yaw
		var player: Node3D = tree.get_first_node_in_group("shop_player") as Node3D
		if player != null and is_talking():
			var to: Vector3 = player.global_position - global_position
			if Vector2(to.x, to.z).length() > 0.2:
				want = atan2(-to.x, -to.z)
		rotation.y = rotation.y + angle_difference(rotation.y, want) * (1.0 - exp(-TURN_RATE * delta))


# --- the cast ------------------------------------------------------------------------------------------------------

## Look, pose and lines for each shop role. `spots` comes from ShopInterior.npc_spots.
static func cast(spots: Dictionary) -> Array[ShopNpc]:
	var out: Array[ShopNpc] = []
	var keeper_lines: PackedStringArray = [
		"Yo! Welcome to Sunset Skate Co. Decks on the wall, threads on the racks!",
		"Fresh griptape just dropped. Check the workbench to set up your board.",
		"Land your combos clean and the coins roll in. Then come spend 'em here!",
		"Swell's flat today, so the whole crew's out at the park.",
		"Need a new look? The style bar's by the mini ramp. Fitting room's right there too.",
	]
	var racks_lines: PackedStringArray = [
		"Manual between tricks to keep your combo alive. Big points!",
		"Hold grind as you come down on a rail and you'll lock right on.",
		"The mega ramp at the park? Total send. Tuck those knees!",
		"Revert out of a vert air to keep the combo rolling.",
		"Ever try surfing a bowl? It's basically a frozen wave, dude.",
	]
	var specs: Array[Dictionary] = [
		{"role": "keeper", "name": "Mika", "mode": "counter", "lines": keeper_lines, "sway": 0.0, "scale": 1.03, "body": "female",
			"skin": "#C98E64", "hair": "#1F1F33", "eyes": "#4A2C1A", "hair_style": "hair_bob",
			"top": ["top_flannel", 1], "bottom": ["bottom_skate_jeans", 0], "socks": ["socks_ankle", 0], "shoes": ["shoes_low_vulc", 2],
			"acc": ["acc_wristbands", 1], "extra": {"hair_tie": "#FFD84D", "band": "#E0455A", "top_trim": "#FFD84D"}},
		{"role": "racks", "name": "Rin", "mode": "stand", "lines": racks_lines, "sway": 1.7, "scale": 0.97, "body": "female",
			"skin": "#F1C9AC", "hair": "#FF7EB6", "eyes": "#8A6BE0", "hair_style": "hair_ponytail",
			"top": ["top_hoodie", 2], "bottom": ["bottom_cargo_shorts", 1], "socks": ["socks_tube", 0], "shoes": ["shoes_high_top", 3],
			"acc": ["acc_headband", 0], "extra": {"hair_tie": "#4FC3F7", "band": "#4FC3F7", "top_trim": "#FFFFFF"}},
		{"role": "deckwall", "name": "Jun", "mode": "stand", "lines": PackedStringArray(), "sway": 3.1, "scale": 1.0, "body": "male",
			"skin": "#9A6445", "hair": "#4FC3F7", "eyes": "#2F86E0", "hair_style": "hair_short_spiky",
			"top": ["top_surf_tee", 3], "bottom": ["bottom_joggers", 0], "socks": ["socks_crew", 0], "shoes": ["shoes_cupsole", 1],
			"acc": ["acc_cap", 1], "extra": {"hair_tie": "#FF5A5F", "band": "#FFD84D"}},
		{"role": "couch", "name": "Nami", "mode": "sit", "lines": PackedStringArray(), "sway": 0.6, "scale": 0.98, "body": "female",
			"skin": "#E0A97E", "hair": "#D9722B", "eyes": "#2F86E0", "hair_style": "hair_bun",
			"top": ["top_crop_tank", 2], "bottom": ["bottom_joggers", 2], "socks": ["socks_striped", 0], "shoes": ["shoes_puffy", 0],
			"acc": ["acc_sunnies", 0], "extra": {"hair_tie": "#A6E22E", "band": "#FF9F1C"}},
		{"role": "ramp", "name": "Sora", "mode": "stand", "lines": PackedStringArray(), "sway": 4.4, "scale": 1.0, "body": "male",
			"skin": "#6B4430", "hair": "#8A6BE0", "eyes": "#4A2C1A", "hair_style": "hair_undercut",
			"top": ["top_hoodie", 0], "bottom": ["bottom_board_shorts", 1], "socks": ["socks_crew", 1], "shoes": ["shoes_low_vulc", 2],
			"acc": ["", 0], "extra": {"hair_tie": "#FFD84D", "band": "#FF7EB6"}},
	]
	for s: Dictionary in specs:
		var role_: String = str(s["role"])
		if not spots.has(role_):
			continue
		var look: SkaterLoadout = SkaterLoadout.new()
		look.skater_name = str(s["name"])
		look.skin_tone = Color(str(s["skin"]))
		look.hair_color = Color(str(s["hair"]))
		look.eye_color = Color(str(s["eyes"]))
		look.body_type = str(s["body"])
		look.hair_style = str(s["hair_style"])
		for slot: String in ["top", "bottom", "socks", "shoes"]:
			look.set_item(slot, str((s[slot] as Array)[0]), int((s[slot] as Array)[1]))
		look.set_item("accessory", str((s["acc"] as Array)[0]), int((s["acc"] as Array)[1]))
		look.deck_graphic = out.size() % 3
		look.wheel_color = (out.size() + 1) % 3
		var extra: Dictionary = {}
		for k: String in (s["extra"] as Dictionary):
			extra[k] = Color(str((s["extra"] as Dictionary)[k]))
		var npc: ShopNpc = create(role_, str(s["name"]), look, extra, str(s["mode"]), s["lines"] as PackedStringArray, float(s["sway"]))
		npc.transform = spots[role_] as Transform3D
		npc.scale = Vector3.ONE * float(s["scale"])
		if role_ == "couch":
			npc.poser.look_yaw = 28.0  # watching the TV
		out.append(npc)
	return out
