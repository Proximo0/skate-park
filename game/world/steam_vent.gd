class_name SteamVent
extends CPUParticles3D
## Steam rising from a grate or a pipe: soft billboard puffs that swell, drift with a little wind and fade. CPU
## particles (works in the Compatibility renderer), 18 puffs, one draw call. Tint it warm under sodium light.
## Use: var v := SteamVent.create(); v.position = ...; add_child(v)

static var _puff: GradientTexture2D = null


static func create(colour: Color = Color(0.92, 0.94, 1.0, 0.35), rate: float = 1.0, height: float = 3.5) -> SteamVent:
	var v := SteamVent.new()
	v.name = "SteamVent"
	v.amount = 18
	v.lifetime = 3.6 / maxf(rate, 0.2)
	v.preprocess = v.lifetime
	v.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	v.emission_sphere_radius = 0.25
	v.direction = Vector3(0.0, 1.0, 0.0)
	v.spread = 12.0
	v.gravity = Vector3(0.25, 0.25, 0.0)
	v.initial_velocity_min = height / v.lifetime * 0.7
	v.initial_velocity_max = height / v.lifetime * 1.1
	v.damping_min = 0.2
	v.damping_max = 0.4
	v.scale_amount_min = 0.7
	v.scale_amount_max = 1.1
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(1.0, 1.6))
	v.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.set_color(0, Color(colour.r, colour.g, colour.b, 0.0))
	ramp.set_color(1, Color(colour.r, colour.g, colour.b, 0.0))
	ramp.add_point(0.15, colour)
	ramp.add_point(0.6, Color(colour.r, colour.g, colour.b, colour.a * 0.5))
	v.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = SteamVent.puff_texture()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = m
	v.mesh = q
	v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return v


static func puff_texture() -> GradientTexture2D:
	if _puff == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.5, Color(1, 1, 1, 0.55))
		_puff = GradientTexture2D.new()
		_puff.gradient = g
		_puff.fill = GradientTexture2D.FILL_RADIAL
		_puff.fill_from = Vector2(0.5, 0.5)
		_puff.fill_to = Vector2(1.0, 0.5)
		_puff.width = 64
		_puff.height = 64
	return _puff
