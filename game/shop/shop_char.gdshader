shader_type spatial;
render_mode specular_disabled;

// Toon shader for the shop's NPCs: toon.gdshader's three bands, but the light is scaled down (`light_scale`) so
// several pendant lamps plus the sun never blow skin out to pale yellow, and the rim is gentler.

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 shadow_tint : source_color = vec3(0.5, 0.46, 0.66);
uniform float mid_level : hint_range(0.0, 1.0) = 0.82;
uniform float mid_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float lit_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float band_softness : hint_range(0.0, 0.2) = 0.03;
uniform float light_scale : hint_range(0.1, 1.0) = 0.5;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.08;
uniform float vertex_color_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = albedo.rgb * mix(vec3(1.0), COLOR.rgb, vertex_color_amount);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float mid_band = smoothstep(mid_threshold - band_softness, mid_threshold + band_softness, lit);
	float top_band = smoothstep(lit_threshold - band_softness, lit_threshold + band_softness, lit);
	vec3 base = ALBEDO;
	vec3 toon_col = mix(base * shadow_tint, base * mid_level, mid_band);
	toon_col = mix(toon_col, base, top_band);
	DIFFUSE_LIGHT += toon_col * LIGHT_COLOR * light_scale * (LIGHT_IS_DIRECTIONAL ? 1.0 : 0.6);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength;
	DIFFUSE_LIGHT += base * rim * clamp(ATTENUATION, 0.4, 1.0);
}
