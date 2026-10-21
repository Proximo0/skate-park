shader_type spatial;
render_mode specular_disabled;

// Toon-lit world-space ground for the park, in two looks chosen by `grass`:
//  slab (0): concrete with expansion joints every 4 m, soft large-scale tint drift, a few darker/lighter patches, oil stains,
//            painted lines (crosswalk, dashes, a ring), a lighter apron round every piece (apron_mask) and a lighter, finer-jointed
//            sidewalk strip outside `walk_from`.
//  grass (1): warm, desaturated lawn with mowed stripes and big tint drift.
// Lighting copies toon.gdshader's three bands but reads ATTENUATION through a soft threshold so a flat slab never flips band on
// tiny shadow-map differences (the old ground split into a light and a dark polygon for exactly that reason).

uniform vec4 albedo : source_color = vec4(0.5, 0.54, 0.59, 1.0);
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.4, 0.62);
uniform float mid_level : hint_range(0.0, 1.0) = 0.8;
uniform float grass = 0.0;
uniform sampler2D apron_mask : filter_linear, repeat_disable;
// world rect (x0, z0, width, depth) the apron mask covers
uniform vec4 apron_rect = vec4(-90.0, -90.0, 180.0, 180.0);
uniform float walk_from = 75.8;
uniform float walk_to = 80.4;
uniform vec4 grass_color : source_color = vec4(0.55, 0.66, 0.34, 1.0);
uniform vec4 walk_color : source_color = vec4(0.55, 0.6, 0.66, 1.0);

varying vec3 wpos;
varying vec3 wnormal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float a = hash21(p);
	return vec2(a, hash21(p + a * 17.0));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 1 inside an axis-aligned rect (centre c, half size h), anti-aliased over about one pixel.
float rect(vec2 p, vec2 c, vec2 h, float aa) {
	vec2 d = abs(p - c) - h;
	return 1.0 - smoothstep(-aa, aa, max(d.x, d.y));
}

// 1 on a line every `step` metres along one axis, `w` wide.
float joint(float x, float step, float w, float aa) {
	float d = abs(fract(x / step + 0.5) - 0.5) * step;
	return 1.0 - smoothstep(w - aa, w + aa, d);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz;
	float aa = max(fwidth(p.x), fwidth(p.y)) * 0.8 + 0.002;
	vec3 base = albedo.rgb;
	float top = step(0.7, wnormal.y);

	if (grass > 0.5) {
		vec3 g = grass_color.rgb;
		float drift = vnoise(p * 0.02) * 0.6 + vnoise(p * 0.07) * 0.4;
		g = mix(g * vec3(0.9, 0.95, 0.85), g * vec3(1.1, 1.05, 0.9), drift);
		float stripe = step(0.5, fract((p.x + p.y) / 14.0));
		g *= 1.0 - 0.045 * stripe;
		// darker lawn right at the slab edge (where it meets the curb)
		ALBEDO = mix(base, g, top);
	} else {
		vec3 c = base;
		// large-scale tint drift, warm toward one end and cool toward the other
		float drift = vnoise(p * 0.03) * 0.6 + vnoise(p * 0.09) * 0.4;
		c *= 0.95 + 0.1 * drift;
		c = mix(c, c * vec3(1.05, 1.0, 0.93), smoothstep(0.35, 0.75, vnoise(p * 0.05 + 7.0)));

		// pour patches: 12 m cells, a quarter hold a slightly different-toned rectangle
		vec2 pc = floor(p / 12.0);
		float ph = hash21(pc + 3.0);
		vec2 poff = hash22(pc + 11.0);
		vec2 pctr = (pc + 0.2 + poff * 0.6) * 12.0;
		vec2 phalf = 1.5 + hash22(pc + 5.0) * 3.0;
		float patch = rect(p, pctr, phalf, aa) * step(0.74, ph);
		float patch_edge = patch - rect(p, pctr, phalf - 0.05, aa);
		c = mix(c, c * (ph > 0.88 ? 0.94 : 1.07), patch);
		c = mix(c, c * 0.94, clamp(patch_edge, 0.0, 1.0));

		// oil stains: cell 9 m, a third hold one; two cel rings
		vec2 sc = floor(p / 9.0 + 0.37);
		float sh = hash21(sc + 23.0);
		vec2 sctr = (sc + 0.15 + hash22(sc + 41.0) * 0.7 - 0.37) * 9.0;
		vec2 sq = (p - sctr) * vec2(1.0, 1.0 + hash21(sc + 2.0));
		float sr = 0.35 + hash21(sc + 9.0) * 0.8;
		float sdist = length(sq) / sr + (vnoise(p * 3.0) - 0.5) * 0.35;
		float stain = step(0.62, sh);
		c = mix(c, c * 0.95, stain * (1.0 - smoothstep(0.95, 1.0, sdist)));
		c = mix(c, c * 0.88, stain * (1.0 - smoothstep(0.5, 0.55, sdist)));

		// expansion joints every 4 m (cut lines), finer 2 m joints on the sidewalk
		float walk_d = max(abs(p.x), abs(p.y));
		float on_walk = smoothstep(walk_from - 0.05, walk_from + 0.05, walk_d);
		float jw = 0.025;
		float j = max(joint(p.x, 4.0, jw, aa), joint(p.y, 4.0, jw, aa));
		float jw2 = max(joint(p.x, 2.0, 0.03, aa), joint(p.y, 2.0, 0.03, aa));
		c = mix(c, c * 0.9, mix(j, jw2, on_walk));

		// lighter apron round every piece (mask baked from the piece footprints)
		vec2 muv = (p - apron_rect.xy) / apron_rect.zw;
		float ap = texture(apron_mask, muv).r;
		float apron = smoothstep(0.35, 0.5, ap) * (1.0 - on_walk);
		c = mix(c, c * vec3(1.07, 1.07, 1.06), apron * 0.5);

		// painted lines (visual only)
		// crosswalk: zebra bars across a path, in the open plaza south-west
		vec2 cw = p - vec2(-47.0, 33.0);
		float zebra = rect(cw, vec2(0.0), vec2(3.4, 2.6), aa) * step(fract(cw.x / 1.0), 0.55);
		// dashed lane line along the south run
		float dash = rect(p, vec2(0.0, 52.0), vec2(70.0, 0.07), aa) * step(fract(p.x / 3.0), 0.55);
		// yellow no-skate-here curb dashes round the spawn pad
		float ring_r = abs(length(p - vec2(0.0, 20.0)) - 5.0);
		float ring = (1.0 - smoothstep(0.07 - aa, 0.07 + aa, ring_r)) * step(fract(atan(p.y - 20.0, p.x) * 2.5), 0.6);
		vec3 paint_w = vec3(0.86, 0.86, 0.84);
		vec3 paint_y = vec3(0.95, 0.72, 0.22);
		c = mix(c, paint_w, zebra * 0.85);
		c = mix(c, paint_w, dash * 0.8);
		c = mix(c, paint_y, ring * 0.9);
		// bay lines on the north side, a box and a centre line
		float box_l = max(rect(p, vec2(-24.0, -64.0), vec2(0.07, 4.0), aa), rect(p, vec2(-14.0, -64.0), vec2(0.07, 4.0), aa));
		c = mix(c, paint_w, box_l * 0.8);
		c = mix(c, paint_y, rect(p, vec2(-19.0, -64.0), vec2(0.07, 4.0), aa) * 0.9);

		// sidewalk strip: warm light concrete, edge line at the curb
		c = mix(c, walk_color.rgb * (0.97 + 0.06 * drift), on_walk);
		float curb_line = rect(vec2(walk_d, 0.0), vec2(walk_to + 0.2, 0.0), vec2(0.2, 1.0), aa);
		c = mix(c, c * 0.9, curb_line * on_walk);
		ALBEDO = mix(base, c, top);
	}
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	float n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float shadow = smoothstep(0.35, 0.65, ATTENUATION);
	float lit = n_dot_l * shadow;
	float mid_band = smoothstep(0.1, 0.14, lit);
	float top_band = smoothstep(0.5, 0.54, lit);
	vec3 b = ALBEDO;
	vec3 toon_col = mix(b * shadow_tint, b * mid_level, mid_band);
	toon_col = mix(toon_col, b, top_band);
	DIFFUSE_LIGHT += toon_col * LIGHT_COLOR * 0.5;
}
