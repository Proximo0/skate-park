shader_type spatial;
render_mode specular_disabled;

// Shop floor: a checkerboard of `tile` metre squares, cel-lit like toon.gdshader (same three bands), with faint
// scuffs so it reads as a well-skated shop floor. UV is the plane's 0..1, `size` its size in metres.

uniform vec4 color_a : source_color = vec4(0.92, 0.85, 0.74, 1.0);
uniform vec4 color_b : source_color = vec4(0.36, 0.29, 0.47, 1.0);
uniform vec2 size = vec2(14.0, 10.0);
uniform float tile = 0.5;
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.4, 0.62);
uniform float mid_level : hint_range(0.0, 1.0) = 0.8;
uniform float mid_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float lit_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float band_softness : hint_range(0.0, 0.2) = 0.02;

float floor_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 m = UV * size / tile;
	vec2 cell = floor(m);
	float k = mod(cell.x + cell.y, 2.0);
	vec3 c = mix(color_a.rgb, color_b.rgb, k);
	// grout lines
	vec2 f = fract(m);
	float grout = step(f.x, 0.012) + step(f.y, 0.012);
	c *= 1.0 - 0.12 * clamp(grout, 0.0, 1.0);
	// a few soft scuffs per tile
	float n = floor_hash(cell);
	float scuff = smoothstep(0.28, 0.0, length(f - vec2(fract(n * 7.0), fract(n * 13.0)))) * step(0.6, n);
	c = mix(c, c * 0.88, scuff);
	ALBEDO = c;
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
	DIFFUSE_LIGHT += toon_col * LIGHT_COLOR * 0.5;
}
