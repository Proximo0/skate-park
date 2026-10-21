class_name Props
extends RefCounted
## Decorative park props built in code: low poly, cartoony, bright. Every builder returns a Node3D whose origin is
## at the base centre (ground level), so props can be scattered by position. Only the trash can and the traffic
## cone carry collision; everything else is visual. Every prop stays under about 600 triangles.

const TRUNK: Color = Color("a0673c")
const LEAF: Color = Color("4cc96a")
const LEAF_LIGHT: Color = Color("7ddc83")
const PALM_TRUNK: Color = Color("c48a52")
const FROND: Color = Color("3fbf6a")
const FROND_DARK: Color = Color("2f9e57")
const COCONUT: Color = Color("8a5a2b")
const BUSH_GREEN: Color = Color("3dbb63")
const BIN: Color = Color("4fa3e0")
const BIN_LID: Color = Color("3a506b")
const CONE_ORANGE: Color = Color("ff7a1a")
const CONE_WHITE: Color = Color("ffffff")
const DARK_GREY: Color = Color("3a3a4a")
const WOOD: Color = Color("d9914f")
const POLE: Color = Color("5b6b7d")
const LAMP_HEAD: Color = Color("fff2b0")
const LAMP_LIGHT: Color = Color("ffd9a0")
const CART_BODY: Color = Color("fff7f0")
const CART_TOP: Color = Color("ff8fb1")
const CART_STRIPE: Color = Color("ff5a5f")
const SCOOP_PINK: Color = Color("ffc0d9")
const SCOOP_MINT: Color = Color("9be7c4")
const CLOUD_WHITE: Color = Color("ffffff")
const MOUNT_GREEN: Color = Color("a8e6b0")
const MOUNT_BLUE: Color = Color("a7d3f2")
const SKIN: Color = Color("f2c6a0")


## Builds the prop named by kind ("tree", "palm_tree", "bush", "trash_can", "traffic_cone", "picnic_table",
## "lamp_post", "ice_cream_cart", "cloud", "mountain", "crowd_kid") with its default arguments. Null if unknown.
static func by_kind(kind: String) -> Node3D:
	match kind:
		"tree":
			return tree()
		"palm_tree":
			return palm_tree()
		"bush":
			return bush()
		"trash_can":
			return trash_can()
		"traffic_cone":
			return traffic_cone()
		"picnic_table":
			return picnic_table()
		"lamp_post":
			return lamp_post()
		"ice_cream_cart":
			return ice_cream_cart()
		"cloud":
			return cloud()
		"mountain":
			return mountain()
		"crowd_kid":
			return crowd_kid()
	return null


## Round leafy tree: a brown trunk with three clustered green spheres for the crown.
static func tree(height: float = 4.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Tree"
	var trunk_h: float = height * 0.4
	root.add_child(_part(_cylinder(height * 0.04, height * 0.05, trunk_h, 8), TRUNK, Vector3(0.0, trunk_h * 0.5, 0.0), "Trunk"))
	var r: float = height * 0.24
	root.add_child(_part(_sphere(r), LEAF_LIGHT, Vector3(0.0, height - r, 0.0), "Crown"))
	root.add_child(_part(_sphere(r * 0.8), LEAF, Vector3(r * 0.6, height - 1.75 * r, r * 0.15), "CrownR"))
	root.add_child(_part(_sphere(r * 0.8), LEAF, Vector3(-r * 0.55, height - 1.8 * r, -r * 0.2), "CrownL"))
	return root


## Palm: a leaning ringed trunk, seven drooping fronds and a few coconuts.
static func palm_tree() -> Node3D:
	var root := Node3D.new()
	root.name = "PalmTree"
	var h: float = 3.2
	var lean: float = 0.18
	# The tilted bottom rim dips below y = 0 by radius * sin(lean); lift the whole tree to sit on the ground.
	var lift: float = 0.15 * sin(lean)
	var mid := Vector3(sin(lean) * h * 0.5, cos(lean) * h * 0.5 + lift, 0.0)
	root.add_child(_part(_cylinder(0.09, 0.15, h, 8), PALM_TRUNK, mid, "Trunk", Vector3(0.0, 0.0, -lean)))
	var crown := Node3D.new()
	crown.name = "Fronds"
	crown.position = Vector3(sin(lean) * h, cos(lean) * h + lift, 0.0)
	root.add_child(crown)
	for k: int in 7:
		var yaw: float = TAU * float(k) / 7.0
		var pivot := Node3D.new()
		pivot.name = "Frond%d" % k
		pivot.rotation = Vector3(-0.4, yaw, 0.0)
		# Wide, fat fronds without ink: thin inked slats read as floating green crosses from far away.
		var leaf_color: Color = FROND if k % 2 == 0 else FROND_DARK
		pivot.add_child(_part(_box(Vector3(0.7, 0.1, 1.5)), leaf_color, Vector3(0.0, 0.0, -0.75), "Leaf", Vector3.ZERO, false))
		crown.add_child(pivot)
	crown.add_child(_part(_sphere(0.32, 8, 4), FROND_DARK, Vector3(0.0, 0.0, 0.0), "Heart"))
	crown.add_child(_part(_sphere(0.09, 6, 3), COCONUT, Vector3(0.08, -0.12, 0.06), "CoconutA"))
	crown.add_child(_part(_sphere(0.09, 6, 3), COCONUT, Vector3(-0.07, -0.13, -0.05), "CoconutB"))
	return root


## Leafy bush: three low green spheres sitting on the ground.
static func bush() -> Node3D:
	var root := Node3D.new()
	root.name = "Bush"
	root.add_child(_part(_sphere(0.32), BUSH_GREEN, Vector3(0.0, 0.32, 0.0), "Main"))
	root.add_child(_part(_sphere(0.24), LEAF_LIGHT, Vector3(0.28, 0.24, 0.1), "SideR"))
	root.add_child(_part(_sphere(0.26), BUSH_GREEN, Vector3(-0.25, 0.26, -0.12), "SideL"))
	return root


## Blue bin with a dark lid. Has collision (layer 1, world).
static func trash_can() -> StaticBody3D:
	var root := StaticBody3D.new()
	root.name = "TrashCan"
	root.add_child(_part(_cylinder(0.22, 0.2, 0.7, 10), BIN, Vector3(0.0, 0.35, 0.0), "Bin"))
	root.add_child(_part(_cylinder(0.25, 0.25, 0.06, 10), BIN_LID, Vector3(0.0, 0.73, 0.0), "Lid"))
	var shape := CylinderShape3D.new()
	shape.radius = 0.22
	shape.height = 0.7
	root.add_child(_collider(shape, Vector3(0.0, 0.35, 0.0)))
	return root


## Orange cone with a white band and a dark base plate. Has collision (layer 1, world).
static func traffic_cone() -> StaticBody3D:
	var root := StaticBody3D.new()
	root.name = "TrafficCone"
	root.add_child(_part(_box(Vector3(0.44, 0.03, 0.44)), DARK_GREY, Vector3(0.0, 0.015, 0.0), "Base"))
	root.add_child(_part(_cylinder(0.04, 0.2, 0.6, 10), CONE_ORANGE, Vector3(0.0, 0.3, 0.0), "Cone"))
	root.add_child(_part(_cylinder(0.15, 0.15, 0.08, 10), CONE_WHITE, Vector3(0.0, 0.22, 0.0), "Band"))
	var shape := CylinderShape3D.new()
	shape.radius = 0.2
	shape.height = 0.6
	root.add_child(_collider(shape, Vector3(0.0, 0.3, 0.0)))
	return root


## Wooden picnic table with two benches, one on each side. Visual only.
static func picnic_table() -> Node3D:
	var root := Node3D.new()
	root.name = "PicnicTable"
	root.add_child(_part(_box(Vector3(1.6, 0.06, 0.7)), WOOD, Vector3(0.0, 0.75, 0.0), "Top"))
	for sx: float in [-0.7, 0.7]:
		for sz: float in [-0.3, 0.3]:
			root.add_child(_part(_box(Vector3(0.08, 0.72, 0.08)), WOOD, Vector3(sx, 0.36, sz), "TableLeg"))
	for side: float in [-0.7, 0.7]:
		root.add_child(_part(_box(Vector3(1.6, 0.05, 0.3)), WOOD, Vector3(0.0, 0.44, side), "Bench"))
		for sx: float in [-0.7, 0.7]:
			root.add_child(_part(_box(Vector3(0.08, 0.42, 0.08)), WOOD, Vector3(sx, 0.21, side), "BenchLeg"))
	return root


## Tall pole with a round lamp head and a warm, low-energy OmniLight3D (no shadows).
static func lamp_post() -> Node3D:
	var root := Node3D.new()
	root.name = "LampPost"
	root.add_child(_part(_cylinder(0.2, 0.2, 0.08, 8), POLE, Vector3(0.0, 0.04, 0.0), "Foot"))
	root.add_child(_part(_cylinder(0.06, 0.08, 3.2, 8), POLE, Vector3(0.0, 1.6, 0.0), "Pole"))
	root.add_child(_part(_sphere(0.22), LAMP_HEAD, Vector3(0.0, 3.3, 0.0), "Lamp"))
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.position = Vector3(0.0, 3.2, 0.0)
	light.light_color = LAMP_LIGHT
	light.light_energy = 0.6
	light.omni_range = 6.0
	light.shadow_enabled = false
	root.add_child(light)
	return root


## Cute white ice cream cart: pink counter with two scoops, four wheels, a striped front and a red umbrella.
static func ice_cream_cart() -> Node3D:
	var root := Node3D.new()
	root.name = "IceCreamCart"
	root.add_child(_part(_box(Vector3(1.1, 0.8, 0.7)), CART_BODY, Vector3(0.0, 0.7, 0.0), "Body"))
	root.add_child(_part(_box(Vector3(1.2, 0.08, 0.8)), CART_TOP, Vector3(0.0, 1.14, 0.0), "Counter"))
	root.add_child(_part(_box(Vector3(1.0, 0.22, 0.02)), CART_STRIPE, Vector3(0.0, 0.62, 0.36), "Stripe"))
	for sx: float in [-0.58, 0.58]:
		for sz: float in [-0.25, 0.25]:
			root.add_child(_part(_cylinder(0.2, 0.2, 0.1, 8), DARK_GREY, Vector3(sx, 0.2, sz), "Wheel", Vector3(0.0, 0.0, PI * 0.5)))
	root.add_child(_part(_sphere(0.18, 8, 4), SCOOP_PINK, Vector3(-0.25, 1.36, 0.1), "ScoopA"))
	root.add_child(_part(_sphere(0.18, 8, 4), SCOOP_MINT, Vector3(0.25, 1.36, 0.1), "ScoopB"))
	root.add_child(_part(_cylinder(0.03, 0.03, 1.0, 6), POLE, Vector3(0.0, 1.7, -0.3), "UmbrellaPole"))
	root.add_child(_part(_cylinder(0.05, 0.9, 0.35, 12), CART_STRIPE, Vector3(0.0, 2.35, -0.3), "Umbrella"))
	return root


## Fluffy white cloud from four spheres, no ink outline. Visual only, for the sky ring.
static func cloud(scale: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Cloud"
	root.scale = Vector3.ONE * scale
	root.add_child(_part(_sphere(1.0), CLOUD_WHITE, Vector3(0.0, 0.0, 0.0), "Puff", Vector3.ZERO, false))
	root.add_child(_part(_sphere(0.7), CLOUD_WHITE, Vector3(-0.9, -0.2, 0.1), "PuffL", Vector3.ZERO, false))
	root.add_child(_part(_sphere(0.8), CLOUD_WHITE, Vector3(0.95, -0.15, -0.1), "PuffR", Vector3.ZERO, false))
	root.add_child(_part(_sphere(0.6), CLOUD_WHITE, Vector3(0.3, 0.5, 0.0), "PuffTop", Vector3.ZERO, false))
	return root


## Big soft low-poly mountain for the far horizon: a pastel green peak with a pastel blue ridge behind it.
## Visual only, no ink outline (reads as soft scenery). Height in metres.
static func mountain(height: float = 40.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Mountain"
	var base_r: float = height * 0.7
	root.add_child(_part(_cylinder(0.0, base_r, height, 8), MOUNT_GREEN, Vector3(0.0, height * 0.5, 0.0), "Peak", Vector3.ZERO, false))
	root.add_child(_part(_cylinder(0.0, base_r * 0.8, height * 0.7, 8), MOUNT_BLUE, Vector3(base_r * 0.9, height * 0.35, -base_r * 0.5), "Ridge", Vector3.ZERO, false))
	return root


## Tiny simplified spectator: a capsule body, a sphere head and a right arm on a pivot named "ArmR" (rotate
## it about Z to wave). Visual only.
static func crowd_kid(color: Color = Color(1.0, 0.35, 0.37)) -> Node3D:
	var root := Node3D.new()
	root.name = "CrowdKid"
	root.add_child(_part(_capsule(0.14, 0.55), color, Vector3(0.0, 0.275, 0.0), "Body"))
	root.add_child(_part(_sphere(0.13, 8, 4), SKIN, Vector3(0.0, 0.695, 0.0), "Head"))
	var arm := Node3D.new()
	arm.name = "ArmR"
	arm.position = Vector3(0.17, 0.475, 0.0)
	root.add_child(arm)
	arm.add_child(_part(_capsule(0.04, 0.3), color, Vector3(0.0, -0.15, 0.0), "Arm"))
	return root


## Places one prop of kind at each position under parent (parent-local space). Each gets a seeded random yaw and a
## uniform scale in [0.85, 1.2]. Returns the nodes added, in position order; empty if kind is unknown.
static func scatter(parent: Node3D, kind: String, positions: PackedVector3Array, seed: int) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i: int in positions.size():
		var node: Node3D = by_kind(kind)
		if node == null:
			push_error("Props.scatter: unknown kind '%s'" % kind)
			return out
		node.name = "%s_%d" % [kind, i]
		node.position = positions[i]
		node.rotation.y = rng.randf_range(0.0, TAU)
		var s: float = rng.randf_range(0.85, 1.2)
		node.scale = node.scale * s
		parent.add_child(node)
		out.append(node)
	return out


static func _part(mesh: Mesh, color: Color, pos: Vector3, node_name: String, rot: Vector3 = Vector3.ZERO, ink: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = Toon.material(color, ink)
	mi.position = pos
	mi.rotation = rot
	return mi


static func _collider(shape: Shape3D, pos: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	cs.position = pos
	return cs


static func _sphere(radius: float, segments: int = 10, rings: int = 5) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = rings
	return m


static func _cylinder(top_radius: float, bottom_radius: float, height: float, segments: int = 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top_radius
	m.bottom_radius = bottom_radius
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 8
	m.rings = 4
	return m
