shader_type spatial;
render_mode specular_disabled;

// World-space ground surfaces for the levels (WorldSurface.material(kind, colour), game/world/world_surface.gd). No textures,
// no UVs needed: everything is worked out from the world position, so any slab, ramp top or street can use it.
// kind: 0 concrete (4 m joints, pour patches, stains), 1 asphalt (fine grain, patches, tyre polish), 2 sand (ripples and
// footprint dimples, wet darkening toward wet_line), 3 grass (mowed stripes), 4 pavers (staggered brick tiles),
// 5 boardwalk planks (along +X), 6 painted court / gym floor (polished, subtle boards).
// Lighting: the toon three-band look of toon.gdshader with a soft shadow threshold (as the park ground does).

uniform vec4 albedo : source_color = vec4(0.5, 0.54, 0.59, 1.0);
uniform int kind = 0;
uniform float scale = 1.0;  // pattern size multiplier (joints, tiles, planks)
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.4, 0.62);
uniform float mid_level : hint_range(0.0, 1.0) = 0.8;
uniform vec4 accent : source_color = vec4(0.9, 0.86, 0.8, 1.0);  // joints, mortar, lines
// sand: wet past the plane through wet_origin facing wet_dir (world; dir points out to sea), over wet_width metres
uniform vec3 wet_origin = vec3(0.0, 0.0, 1e6);
uniform vec3 wet_dir = vec3(0.0, 0.0, 1.0);
uniform float wet_width = 6.0;

varying vec3 wpos;
varying vec3 wnormal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float joint(float x, float step_m, float w, float aa) {
	float d = abs(fract(x / step_m + 0.5) - 0.5) * step_m;
	return 1.0 - smoothstep(w - aa, w + aa, d);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz / scale;
	float aa = max(fwidth(p.x), fwidth(p.y)) * 0.8 + 0.002;
	float near = 1.0 - smoothstep(12.0, 48.0, length(VERTEX));
	vec3 c = albedo.rgb;
	float drift = vnoise(p * 0.03) * 0.6 + vnoise(p * 0.09) * 0.4;
	if (kind == 0) {
		c *= 0.95 + 0.1 * drift;
		vec2 pc = floor(p / 12.0);
		float ph = hash21(pc + 3.0);
		vec2 q = abs(p - (pc + 0.5) * 12.0) - vec2(2.0 + 3.0 * hash21(pc + 5.0), 1.5 + 3.0 * hash21(pc + 6.0));
		float patch = (1.0 - smoothstep(-aa, aa, max(q.x, q.y))) * step(0.74, ph);
		c = mix(c, c * (ph > 0.88 ? 0.96 : 1.04), patch);
		float j = max(joint(p.x, 4.0, 0.025, aa), joint(p.y, 4.0, 0.025, aa));
		c = mix(c, c * 0.88, j);
		c *= 1.0 + (vnoise(p * 9.0) - 0.5) * 0.05 * near;
		float stain = smoothstep(0.78, 0.86, vnoise(p * 0.35 + 13.0));
		c = mix(c, c * 0.93, stain * 0.6);
	} else if (kind == 1) {
		c *= 0.96 + 0.06 * drift;
		c *= 1.0 + (hash21(floor(p * 40.0)) - 0.5) * 0.09 * near;
		c *= 1.0 + (vnoise(p * 6.0) - 0.5) * 0.06;
		// resurfaced patches: faint, soft-edged, and only near the camera's scale (no big dark blobs from afar)
		float patch = smoothstep(0.7, 0.76, vnoise(p * 0.12 + 3.0));
		c = mix(c, c * 0.95, patch * near);
		float crack = 1.0 - smoothstep(0.0, 0.025, abs(vnoise(p * 0.5 + 9.0) - 0.5));
		c = mix(c, c * 0.8, crack * 0.3 * step(0.55, vnoise(p * 0.08)) * (1.0 - smoothstep(30.0, 90.0, length(VERTEX))));
	} else if (kind == 2) {
		float rip = sin((p.x * 0.7 + p.y * 1.6) * 2.4 + vnoise(p * 0.4) * 5.0);
		c *= 0.96 + 0.05 * drift + 0.035 * rip * (0.5 + 0.5 * near);
		c *= 1.0 + (hash21(floor(p * 55.0)) - 0.5) * 0.12 * near;
		vec2 fc = floor(p / 1.3);
		vec2 fo = (fc + 0.5) * 1.3 + (vec2(hash21(fc), hash21(fc + 7.0)) - 0.5) * 0.8;
		float foot = (1.0 - smoothstep(0.08, 0.16, length((p - fo) * vec2(1.0, 0.55)))) * step(0.72, hash21(fc + 2.0));
		c = mix(c, c * 0.86, foot * 0.6);
		float wet = smoothstep(-wet_width, 0.0, dot(wpos - wet_origin, normalize(wet_dir)));
		c = mix(c, c * vec3(0.74, 0.74, 0.76), wet);
	} else if (kind == 3) {
		float sp = (p.x + p.y) / 9.0 + vnoise(p * 0.025) * 2.2;
		float stripe = smoothstep(0.46, 0.54, fract(sp));
		c = mix(c * vec3(0.96, 0.98, 0.93), c * vec3(1.04, 1.02, 0.95), drift);
		c *= 1.0 - 0.035 * stripe * (1.0 - smoothstep(40.0, 160.0, length(VERTEX)));  // stripes alias far away
		c *= 0.96 + 0.08 * vnoise(p * 0.7) * near;
	} else if (kind == 4) {
		vec2 b = vec2(p.x / 0.6, p.y / 0.3);
		b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
		vec2 cell = floor(b);
		vec2 f = fract(b);
		float m = 1.0 - (smoothstep(0.03, 0.08, f.x) * smoothstep(0.03, 0.08, 1.0 - f.x) * smoothstep(0.06, 0.14, f.y) * smoothstep(0.06, 0.14, 1.0 - f.y));
		c *= 0.9 + 0.2 * hash21(cell);
		c = mix(c, accent.rgb * c * 1.2, m * (0.5 + 0.5 * near));
	} else if (kind == 5) {
		float plank = p.y / 0.24;
		vec2 cell = vec2(floor((p.x + hash21(vec2(floor(plank), 1.0)) * 6.0) / 3.0), floor(plank));
		c *= 0.86 + 0.24 * hash21(cell);
		c *= 0.96 + 0.08 * sin(p.x * 3.0 + hash21(cell) * 20.0 + vnoise(p * vec2(0.5, 8.0)) * 3.0);
		float gap = 1.0 - smoothstep(0.04, 0.09, abs(fract(plank) - 0.5) * 2.0 - 0.88);
		c *= 1.0 - 0.45 * (1.0 - gap);
	} else {
		float board = floor(p.y / 0.12);
		c *= 0.97 + 0.06 * hash21(vec2(board, floor(p.x / 2.4 + hash21(vec2(board)) * 3.0)));
		c *= 1.0 + 0.04 * drift;
	}
	float top = step(0.7, wnormal.y);
	ALBEDO = mix(albedo.rgb, c, top);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	float n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	// Flat tops in sun are fully lit whatever the sun height: a low sun puts n.l right on a band threshold, where the
	// shadow map's sampling noise would split the ground into blotches. Only the shadow decides the band there.
	n_dot_l = mix(n_dot_l, max(n_dot_l, 0.62), step(0.7, wnormal.y) * step(0.05, n_dot_l));
	float shadow = smoothstep(0.35, 0.65, ATTENUATION);
	float lit = n_dot_l * shadow;
	float mid_band = smoothstep(0.1, 0.14, lit);
	float top_band = smoothstep(0.5, 0.54, lit);
	vec3 b = ALBEDO;
	vec3 toon_col = mix(b * shadow_tint, b * mid_level, mid_band);
	toon_col = mix(toon_col, b, top_band);
	DIFFUSE_LIGHT += toon_col * LIGHT_COLOR * 0.5;
}
