class_name GoalPickup
extends Collectible
## A hidden goal pickup: a skate-video cassette that spins and bobs where the letters would. It is a Collectible like
## any other (the goals count its `item`); only the look differs: a black shell, a yellow label with a red stripe, two
## white reels, and a small floating tag so a rider who spots it knows what it is.

const SHELL_COLOR: Color = Color(0.11, 0.12, 0.16)
const LABEL_COLOR: Color = Color(1.0, 0.82, 0.22)
const STRIPE_COLOR: Color = Color(0.9, 0.22, 0.2)
const REEL_COLOR: Color = Color(0.95, 0.94, 0.9)
const TAG_TEXT: String = "MIXTAPE"
const SCALE: float = 1.25


func _build_letter() -> void:
	var tape := Node3D.new()
	tape.name = "Cassette"
	tape.scale = Vector3.ONE * SCALE
	_visual.add_child(tape)
	tape.add_child(_box(Vector3(0.62, 0.4, 0.1), Vector3.ZERO, SHELL_COLOR))
	tape.add_child(_box(Vector3(0.5, 0.17, 0.012), Vector3(0, 0.06, 0.054), LABEL_COLOR))
	tape.add_child(_box(Vector3(0.5, 0.04, 0.014), Vector3(0, 0.06, 0.056), STRIPE_COLOR))
	tape.add_child(_box(Vector3(0.38, 0.11, 0.012), Vector3(0, -0.1, 0.054), Color(0.24, 0.27, 0.34)))
	for sx: float in [-1.0, 1.0]:
		tape.add_child(_reel(Vector3(sx * 0.11, -0.1, 0.06)))
	# The back carries the same label and reels, so the cassette reads from any side as it turns.
	tape.add_child(_box(Vector3(0.5, 0.17, 0.012), Vector3(0, 0.06, -0.054), LABEL_COLOR))
	tape.add_child(_box(Vector3(0.5, 0.04, 0.014), Vector3(0, 0.06, -0.056), STRIPE_COLOR))
	tape.add_child(_box(Vector3(0.38, 0.11, 0.012), Vector3(0, -0.1, -0.054), Color(0.24, 0.27, 0.34)))
	for sx: float in [-1.0, 1.0]:
		tape.add_child(_reel(Vector3(sx * 0.11, -0.1, -0.06)))
	var tag := Label3D.new()  # not Collectible's _label: that one is re-seated every frame, this rides on the bobbing visual
	tag.text = TAG_TEXT
	tag.font_size = 64
	tag.pixel_size = 0.004
	tag.outline_size = 12
	tag.outline_modulate = OUTLINE_COLOR
	tag.modulate = LETTER_COLOR
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = 0.55
	_visual.add_child(tag)


static func _box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	mi.material_override = Toon.material(color)
	return mi


static func _reel(at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = 0.012
	mi.mesh = cm
	mi.rotation_degrees.x = 90.0
	mi.position = at
	mi.material_override = Toon.material(REEL_COLOR)
	return mi


## Puts a cassette over each entry's gap zone ({"item", "zone" (a zone id), "dy" (metres above the zone's floor)}) in
## `level` and returns them. Entries whose zone is missing are skipped.
static func spawn(tree: SceneTree, level: Node, entries: Array[Dictionary]) -> Array[Collectible]:
	var out: Array[Collectible] = []
	var zones: Dictionary = {}
	for z: Node in tree.get_nodes_in_group("gap_zone"):
		var area := z as Area3D
		if area != null and area.get_child_count() > 0 and area.get_child(0) is CollisionShape3D:
			zones[str(area.get_meta("zone_id", ""))] = area.get_child(0)
	var n: int = 0
	for e: Dictionary in entries:
		var zone: String = str(e.get("zone", ""))
		if not zones.has(zone):
			continue
		var cs: CollisionShape3D = zones[zone]
		var box := cs.shape as BoxShape3D
		var floor_y: float = cs.global_position.y - (box.size.y * 0.5 if box != null else 0.0)
		var c := GoalPickup.new()
		c.item = str(e.get("item", "VHS"))
		c.group_id = "mixtape"
		c.name = "Mixtape_%d" % n
		var world := Vector3(cs.global_position.x, floor_y + float(e.get("dy", 1.2)), cs.global_position.z)
		c.position = (level as Node3D).to_local(world) if level is Node3D else world
		level.add_child(c)
		out.append(c)
		n += 1
	return out
