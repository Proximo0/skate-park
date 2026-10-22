shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Night headlight beams of a traffic car (CarModel): two soft cones and a pool of light on the road ahead, additive.
// UV.y runs 0 at the lamp to 1 at the far end; UV.x across the beam (0..1). COLOR.a: 1 = pool on the ground, 0 = cone.

uniform vec4 beam_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float strength = 1.0;

void fragment() {
	float across = 1.0 - pow(abs(UV.x * 2.0 - 1.0), 1.6);
	float along = (1.0 - smoothstep(0.15, 1.0, UV.y)) * smoothstep(0.0, 0.08, UV.y);
	float pool = COLOR.a;
	float a = across * along * mix(0.06, 0.32, pool) * strength;
	ALBEDO = beam_color.rgb * a;
}
