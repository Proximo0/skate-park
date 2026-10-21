extends TestCase


func test_material_is_shader_material_with_outline_next_pass() -> void:
	var mat: ShaderMaterial = Toon.material(Color.RED)
	assert_true(mat != null, "material returned")
	assert_true(mat.shader != null, "toon shader set")
	assert_true(mat.next_pass != null, "outline next_pass set")
	assert_true(mat.next_pass is ShaderMaterial, "next_pass is a ShaderMaterial")


func test_material_without_outline_has_no_next_pass() -> void:
	var mat: ShaderMaterial = Toon.material(Color.BLUE, false)
	assert_true(mat != null, "material returned")
	assert_true(mat.next_pass == null, "no next_pass when outline is off")


func test_material_caching_returns_same_instance_for_same_color() -> void:
	var a: ShaderMaterial = Toon.material(Color(0.2, 0.4, 0.6))
	var b: ShaderMaterial = Toon.material(Color(0.2, 0.4, 0.6))
	assert_true(is_same(a, b), "same colour gives same instance")
	var c: ShaderMaterial = Toon.material(Color(0.9, 0.1, 0.1))
	assert_false(is_same(a, c), "different colour gives different instance")


func test_apply_to_counts_mesh_instances() -> void:
	var root: Node3D = Node3D.new()
	var box: MeshInstance3D = MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	root.add_child(box)
	var group: Node3D = Node3D.new()
	root.add_child(group)
	var sphere: MeshInstance3D = MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	group.add_child(sphere)
	var plain: Node3D = Node3D.new()
	group.add_child(plain)
	assert_eq(Toon.apply_to(root), 2, "two mesh instances changed")
	assert_true(box.material_override is ShaderMaterial, "box gets toon material")
	assert_true(sphere.material_override is ShaderMaterial, "sphere gets toon material")
	assert_eq(Toon.apply_to(root), 0, "second apply changes nothing")
	root.free()


func test_apply_to_keeps_albedo_colour() -> void:
	var root: MeshInstance3D = MeshInstance3D.new()
	root.mesh = BoxMesh.new()
	var std: StandardMaterial3D = StandardMaterial3D.new()
	std.albedo_color = Color(1.0, 0.3, 0.2)
	root.material_override = std
	assert_eq(Toon.apply_to(root), 1, "root mesh changed")
	var mat: ShaderMaterial = root.material_override as ShaderMaterial
	assert_true(mat != null, "toon material applied")
	if mat != null:
		assert_true(is_same(mat, Toon.material(Color(1.0, 0.3, 0.2))), "albedo carried over")
	root.free()


func test_apply_to_null_root_is_zero() -> void:
	assert_eq(Toon.apply_to(null), 0)


func test_sky_environment_is_bright_sky() -> void:
	var env: Environment = Toon.sky_environment()
	assert_true(env != null, "environment returned")
	assert_eq(env.background_mode, Environment.BG_SKY, "sky background")
	assert_true(env.sky != null, "sky set")
	assert_eq(env.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR, "neutral ambient, not sky-tinted")
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_LINEAR, "linear tonemap keeps colours bright")
