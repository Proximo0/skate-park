shader_type spatial;
render_mode specular_disabled;

// Garments of a pedestrian (PedBody bakes them into vertex colours): the toon shading of game/art/toon.gdshader with its
// cloth option on, plus a per-person hue / saturation / value shift, so people built from the same look wear different
// colours. Skin, hair and faces use the plain vertex-colour toon material and are never shifted.

uniform float hue_shift = 0.0;  // turns (0..1)
uniform float sat_mul = 1.0;
uniform float val_mul = 1.0;
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.4, 0.62);
uniform float mid_level : hint_range(0.0, 1.0) = 0.8;
uniform float mid_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float lit_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float band_softness : hint_range(0.0, 0.2) = 0.05;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.22;
uniform float cloth_shade : hint_range(0.0, 1.0) = 1.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 hsv = rgb2hsv(COLOR.rgb);
	hsv.x = fract(hsv.x + hue_shift);
	hsv.y = clamp(hsv.y * sat_mul, 0.0, 1.0);
	hsv.z = clamp(hsv.z * val_mul, 0.0, 1.0);
	ALBEDO = hsv2rgb(hsv);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	float n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float shadow = mix(1.0, smoothstep(0.1, 0.9, ATTENUATION), smoothstep(0.55, 0.8, n_dot_l));
	float lit = n_dot_l * shadow;
	float mid_band = smoothstep(mid_threshold - band_softness, mid_threshold + band_softness, lit);
	float top_band = smoothstep(lit_threshold - band_softness, lit_threshold + band_softness, lit);
	vec3 base = ALBEDO;
	vec3 shadow_col = base * shadow_tint;
	vec3 mid_col = base * mid_level;
	float mx = max(base.r, max(base.g, base.b));
	float mn = min(base.r, min(base.g, base.b));
	float boost = cloth_shade * smoothstep(0.45, 0.9, (mx - mn) / max(mx, 0.001));
	vec3 deep = pow(max(base, vec3(0.0001)), vec3(1.0 + 0.7 * boost)) * shadow_tint * (1.0 - 0.3 * boost);
	shadow_col = mix(shadow_col, deep, boost);
	shadow_col *= 1.0 - 0.3 * boost * (1.0 - smoothstep(0.0, 0.2, lit));
	mid_col *= 1.0 - 0.1 * boost;
	vec3 toon_col = mix(shadow_col, mid_col, mid_band);
	toon_col = mix(toon_col, base, top_band);
	DIFFUSE_LIGHT += toon_col * LIGHT_COLOR * (0.9 / 3.14159265);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength;
	rim *= 1.0 - smoothstep(0.25, 0.6, n_dot_l);
	DIFFUSE_LIGHT += vec3(rim) * clamp(ATTENUATION, 0.4, 1.0);
}
