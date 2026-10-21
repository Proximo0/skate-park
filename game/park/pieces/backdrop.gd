class_name ParkBackdrop
extends RefCounted
## The mid and far distance round the park, all visual (no collision, no shadows): rolling hills, a dense tree line, a low-rise
## skyline and big banded-colour mountains. `build()` returns one Node3D "Backdrop". Layers, near to far: tree line (r about 100 to
## 128), hills (130 to 330), low buildings (235 to 300), mountains (420 to 560). Colours step to cooler and paler with distance so
## the fog haze finishes the job. Seeded, so the view is the same every run.

const SEED: int = 7731

const HILL_COLOURS: Array[Color] = [Color("6c8a42"), Color("5f8040"), Color("78924c"), Color("527c48")]
const FAR_HILL_COLOURS: Array[Color] = [Color("56806a"), Color("4c7a78"), Color("608a70")]
const BUILDING_COLOURS: Array[Color] = [Color("c9b99a"), Color("d86a58"), Color("5fa4b0"), Color("a08a5c"), Color("8e88b4"), Color("b8a283")]
const MOUNTAIN_BANDS: Array[Color] = [Color("2f5878"), Color("48789a"), Color("6f9fbc"), Color("d9d2c6")]


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Backdrop"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	root.add_child(_hills(rng))
	root.add_child(_tree_line(rng))
	root.add_child(_buildings(rng))
	root.add_child(_mountains(rng))
	return root


static func _off(mi: GeometryInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _hills(rng: RandomNumberGenerator) -> Node3D:
	var node := Node3D.new()
	node.name = "Hills"
	var n: int = 32
	for i: int in n:
		var a: float = (float(i) + rng.randf_range(-0.3, 0.3)) / float(n) * TAU
		var far: bool = i % 3 == 0
		# horizontal radius `size` (stretched at most 1.4x), centred far enough out that the hill never reaches the tree line
		var size: float = rng.randf_range(55.0, 95.0) if far else rng.randf_range(28.0, 55.0)
		var r: float = (215.0 if far else 132.0) + size * 1.4 + rng.randf_range(0.0, 30.0)
		var m := SphereMesh.new()
		m.radius = size
		m.height = size * 2.0
		m.radial_segments = 20
		m.rings = 8
		var mi := MeshInstance3D.new()
		mi.name = "Hill%d" % i
		mi.mesh = m
		var pal: Array[Color] = FAR_HILL_COLOURS if far else HILL_COLOURS
		mi.material_override = Toon.material(pal[rng.randi() % pal.size()], false)
		var top: float = rng.randf_range(22.0, 44.0) if far else rng.randf_range(9.0, 24.0)
		mi.position = Vector3(cos(a) * r, -0.5, sin(a) * r)
		mi.scale = Vector3(rng.randf_range(1.0, 1.4), top / size, rng.randf_range(1.0, 1.4))
		mi.rotation.y = rng.randf() * TAU
		_off(mi)
		node.add_child(mi)
	return node


static func _tree_line(rng: RandomNumberGenerator) -> Node3D:
	var node := Node3D.new()
	node.name = "TreeLine"
	var count: int = 150
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.25
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = 2.6
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 2.2
	crown_mesh.height = 4.6
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 4
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.use_colors = true
	trunks.mesh = trunk_mesh
	trunks.instance_count = count
	var crowns := MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	crowns.use_colors = true
	crowns.mesh = crown_mesh
	crowns.instance_count = count
	var greens: Array[Color] = [Color("447a36"), Color("4f8a3c"), Color("3a7040"), Color("5f8c36"), Color("3f6f2c"), Color("3f8058")]
	for i: int in count:
		var a: float = float(i) / float(count) * TAU + rng.randf_range(-0.02, 0.02)
		var r: float = rng.randf_range(100.0, 128.0)
		var s: float = rng.randf_range(1.0, 1.7)
		var pos := Vector3(cos(a) * r, -0.05, sin(a) * r)
		var yaw := Basis(Vector3.UP, rng.randf() * TAU)
		trunks.set_instance_transform(i, Transform3D(yaw.scaled(Vector3.ONE * s), pos + Vector3(0.0, 1.3 * s, 0.0)))
		trunks.set_instance_color(i, Color("8a5a36"))
		var cs := Vector3(s, s * rng.randf_range(1.0, 1.35), s)
		crowns.set_instance_transform(i, Transform3D(yaw.scaled(cs), pos + Vector3(0.0, 2.6 * s + 1.4 * s, 0.0)))
		crowns.set_instance_color(i, greens[rng.randi() % greens.size()])
	var mat: ShaderMaterial = Toon.material_vc(Color.WHITE)
	for pair: Array in [["Trunks", trunks], ["Crowns", crowns]]:
		var mmi := MultiMeshInstance3D.new()
		mmi.name = str(pair[0])
		mmi.multimesh = pair[1] as MultiMesh
		mmi.material_override = mat
		_off(mmi)
		node.add_child(mmi)
	return node


static func _buildings(rng: RandomNumberGenerator) -> Node3D:
	var node := Node3D.new()
	node.name = "Skyline"
	var count: int = 46
	var bodies := MultiMesh.new()
	bodies.transform_format = MultiMesh.TRANSFORM_3D
	bodies.use_colors = true
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	bodies.mesh = unit
	bodies.instance_count = count * 2
	for i: int in count:
		var a: float = (float(i) + rng.randf_range(-0.3, 0.3)) / float(count) * TAU
		var r: float = rng.randf_range(235.0, 300.0)
		var w: float = rng.randf_range(14.0, 32.0)
		var d: float = rng.randf_range(12.0, 24.0)
		var h: float = rng.randf_range(10.0, 24.0)
		if i % 9 == 0:
			h = rng.randf_range(26.0, 36.0)
		var yaw := Basis(Vector3.UP, -a + rng.randf_range(-0.2, 0.2))
		var pos := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var col: Color = BUILDING_COLOURS[rng.randi() % BUILDING_COLOURS.size()]
		bodies.set_instance_transform(i * 2, Transform3D(yaw.scaled(Vector3(w, h, d)), pos + Vector3(0.0, h * 0.5 - 1.0, 0.0)))
		bodies.set_instance_color(i * 2, col)
		# a darker roof slab
		bodies.set_instance_transform(i * 2 + 1, Transform3D(yaw.scaled(Vector3(w + 1.0, 1.0, d + 1.0)), pos + Vector3(0.0, h - 0.5, 0.0)))
		bodies.set_instance_color(i * 2 + 1, col.darkened(0.3))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Buildings"
	mmi.multimesh = bodies
	mmi.material_override = Toon.material_vc(Color.WHITE)
	_off(mmi)
	node.add_child(mmi)
	return node


## Banded mountain: stacked cones sharing one silhouette, dark teal at the foot rising to a warm-white cap.
static func mountain(height: float, base_r: float, sides: int = 7) -> Node3D:
	var root := Node3D.new()
	root.name = "Mountain"
	var bands: int = MOUNTAIN_BANDS.size()
	var cuts: Array[float] = [0.0, 0.34, 0.62, 0.82, 1.0]
	for k: int in bands:
		var y0: float = cuts[k] * height
		var y1: float = cuts[k + 1] * height
		var m := CylinderMesh.new()
		m.top_radius = base_r * (1.0 - cuts[k + 1])
		m.bottom_radius = base_r * (1.0 - cuts[k])
		m.height = y1 - y0
		m.radial_segments = sides
		m.rings = 1
		var mi := MeshInstance3D.new()
		mi.name = "Band%d" % k
		mi.mesh = m
		mi.material_override = Toon.material(MOUNTAIN_BANDS[k], false)
		mi.position = Vector3(0.0, (y0 + y1) * 0.5, 0.0)
		_off(mi)
		root.add_child(mi)
	return root


static func _mountains(rng: RandomNumberGenerator) -> Node3D:
	var node := Node3D.new()
	node.name = "Mountains"
	var n: int = 14
	for i: int in n:
		var a: float = (float(i) + rng.randf_range(-0.25, 0.25)) / float(n) * TAU
		var r: float = rng.randf_range(430.0, 560.0)
		var h: float = rng.randf_range(110.0, 200.0)
		var m: Node3D = mountain(h, h * rng.randf_range(0.9, 1.3), 6 + rng.randi() % 3)
		m.name = "Mountain%d" % i
		m.position = Vector3(cos(a) * r, -2.0, sin(a) * r)
		m.rotation.y = rng.randf() * TAU
		node.add_child(m)
		# a smaller shoulder peak beside it
		var s: Node3D = mountain(h * 0.6, h * 0.7, 6)
		s.name = "Shoulder%d" % i
		var off := Vector3(cos(a + 1.5708), 0.0, sin(a + 1.5708)) * h * rng.randf_range(0.7, 1.0)
		s.position = m.position + off + Vector3(0.0, 0.0, 0.0)
		node.add_child(s)
	return node
