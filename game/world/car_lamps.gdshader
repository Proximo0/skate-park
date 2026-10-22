shader_type spatial;
render_mode unshaded, specular_disabled, cull_disabled;

// A traffic car's head and tail lamps (CarModel): the lamp surfaces of the glb in their own mesh, vertex colour = lamp
// colour, and COLOR.a = 1 for a headlight, 0 for a tail light. By day they show their plain colour (a little shaded);
// `on` makes them glow (night), `brake` brightens the tail lights.

uniform float on = 0.0;
uniform float brake = 0.0;
uniform float day_shade = 0.82;

void fragment() {
	float head = COLOR.a;
	vec3 base = COLOR.rgb * day_shade;
	vec3 head_glow = vec3(1.0, 0.95, 0.8) * 2.2;
	vec3 tail_glow = vec3(1.0, 0.12, 0.1) * (1.1 + 1.4 * brake);
	vec3 glow = mix(tail_glow, head_glow, head);
	float k = head > 0.5 ? on : clamp(on * 0.7 + brake, 0.0, 1.0);
	ALBEDO = mix(base, glow, k);
}
