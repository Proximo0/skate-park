// The toon three-band light of game/art/toon.gdshader, shared by the world kit's own spatial shaders (car wheels,
// swaying trees, birds) so they light exactly like Toon.material surfaces. Include it after the shader's uniforms;
// it declares its own band uniforms and the light() function.

uniform vec3 shadow_tint : source_color = vec3(0.42, 0.4, 0.62);
uniform float mid_level : hint_range(0.0, 1.0) = 0.8;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.22;

void light() {
	float n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float shadow = mix(1.0, smoothstep(0.1, 0.9, ATTENUATION), smoothstep(0.55, 0.8, n_dot_l));
	float lit = n_dot_l * shadow;
	float mid_band = smoothstep(0.25, 0.35, lit);
	float top_band = smoothstep(0.65, 0.75, lit);
	vec3 base = ALBEDO;
	vec3 toon_col = mix(base * shadow_tint, base * mid_level, mid_band);
	toon_col = mix(toon_col, base, top_band);
	DIFFUSE_LIGHT += toon_col * LIGHT_COLOR * (0.9 / 3.14159265);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength;
	rim *= 1.0 - smoothstep(0.25, 0.6, n_dot_l);
	DIFFUSE_LIGHT += vec3(rim) * clamp(ATTENUATION, 0.4, 1.0);
}
