shader_type spatial;
render_mode specular_disabled;

// Industrial surfaces of the Creepy Warehouse (WhGeo.mat(kind, colour)). World space, no UVs or textures: the pattern is
// projected on the plane the face looks along (floor/top, wall along X, wall along Z), so merged meshes, ramps and
// boxes of any size share one material. Toon three-band light like game/world/surface.gdshader.
// kind: 0 corrugated metal siding (vertical ribs, sheet seams, rust runs from the fixings, grime at the foot)
//       1 brick (running bond, mortar, sooty patches)
//       2 cast concrete (formwork panels, tie holes, water stains)
//       3 rusted steel plate (mottled rust, pitting, plate seams)
//       4 plywood (DIY ramp sheets: seams, screw rows, wheel scuffs)
//       5 painted steel (flat paint, chips and rust spots on edges)
//       6 floor concrete (power-floated slab: saw cuts, oil stains, tyre marks)

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform int kind = 0;
uniform float scale = 1.0;
uniform vec4 accent : source_color = vec4(0.3, 0.25, 0.22, 1.0);
uniform float rust = 0.5;
uniform float grime = 0.5;
uniform float ground_y = 0.0;
uniform vec3 shadow_tint : source_color = vec3(0.44, 0.43, 0.53);
uniform float mid_level : hint_range(0.0, 1.0) = 0.8;
// Merged meshes (WhGeo.Batch) carry the material per vertex instead: COLOR = albedo, CUSTOM0 = accent rgb + rust,
// CUSTOM1 = grime, pattern scale, ground_y, kind. Then one material draws every kind and colour in a tile.
uniform bool per_vertex = false;

varying vec3 wpos;
varying vec3 wnormal;
varying vec3 v_alb;
varying vec4 v_acc;
varying vec4 v_par;

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

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 7.0) * 0.3 + vnoise(p * 4.3 + 3.0) * 0.15;
}

// 1 on a line every step_m (width w), anti-aliased.
float seam(float x, float step_m, float w, float aa) {
	float d = abs(fract(x / step_m + 0.5) - 0.5) * step_m;
	return 1.0 - smoothstep(w - aa, w + aa, d);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (per_vertex) {
		v_alb = COLOR.rgb;
		v_acc = CUSTOM0;
		v_par = CUSTOM1;
	} else {
		v_alb = albedo.rgb;
		v_acc = vec4(accent.rgb, rust);
		v_par = vec4(grime, scale, ground_y, float(kind));
	}
}

void fragment() {
	int kind_v = int(v_par.w + 0.5);
	float rust_v = v_acc.a;
	float grime_v = v_par.x;
	vec3 accent_v = v_acc.rgb;
	vec3 n = abs(wnormal);
	bool top = n.y > max(n.x, n.z);
	// u runs along the face, v up the wall (or along z on a top)
	vec2 p = top ? wpos.xz : (n.x > n.z ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y));
	p /= max(v_par.y, 0.01);
	float dist = length(VERTEX);
	float near = 1.0 - smoothstep(10.0, 40.0, dist);
	float aa = max(fwidth(p.x), fwidth(p.y)) * 0.9 + 0.002;
	float h = wpos.y - v_par.z;
	vec3 c = v_alb;
	float drift = fbm(p * 0.11);
	c *= 0.9 + 0.2 * drift;
	if (kind_v == 0) {
		float rib = sin(p.x * 6.2831853 / 0.17);
		c *= 1.0 + 0.09 * rib * (1.0 - smoothstep(25.0, 70.0, dist));
		float sheet = seam(p.x, 0.92, 0.012, aa) + seam(p.y, 3.05, 0.02, aa);
		c = mix(c, c * 0.7, clamp(sheet, 0.0, 1.0));
		// rust_v running down from the sheet laps and fixings
		float col = floor(p.x / 0.92);
		float run = vnoise(vec2(p.x * 7.0, p.y * 0.35 + hash21(vec2(col, 2.0)) * 9.0));
		float lap = 1.0 - smoothstep(0.0, 1.6 + 2.0 * hash21(vec2(col, 5.0)), fract(-p.y / 3.05) * 3.05);
		float r = smoothstep(0.55, 0.85, run) * (0.35 + 0.65 * lap) * rust_v;
		r = max(r, smoothstep(0.62, 0.8, fbm(p * vec2(0.6, 0.25) + 11.0)) * rust_v * 0.8);
		c = mix(c, accent_v * (0.7 + 0.5 * vnoise(p * 3.0)), clamp(r, 0.0, 0.85));
	} else if (kind_v == 1) {
		vec2 b = vec2(p.x / 0.44, p.y / 0.15);
		b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
		vec2 cell = floor(b);
		vec2 f = fract(b);
		float mortar = 1.0 - smoothstep(0.03, 0.07, f.x) * smoothstep(0.03, 0.07, 1.0 - f.x) * smoothstep(0.07, 0.15, f.y) * smoothstep(0.07, 0.15, 1.0 - f.y);
		c *= 0.82 + 0.3 * hash21(cell);
		c = mix(c, accent_v, mortar * (0.25 + 0.6 * near));
		float soot = smoothstep(0.5, 0.8, fbm(p * vec2(0.35, 0.15) + 4.0));
		c = mix(c, c * 0.55, soot * rust_v);
	} else if (kind_v == 2) {
		float panel = max(seam(p.x, 2.4, 0.012, aa), seam(p.y, 1.2, 0.012, aa));
		c = mix(c, c * 0.8, panel);
		vec2 tc = fract(p / vec2(0.6, 0.6)) - 0.5;
		float tie = (1.0 - smoothstep(0.02, 0.035, length(tc))) * near;
		c = mix(c, c * 0.55, tie * 0.7);
		float stain = smoothstep(0.45, 0.85, vnoise(vec2(p.x * 1.6, p.y * 0.12) + 3.0));
		c = mix(c, c * vec3(0.72, 0.74, 0.7), stain * rust_v);
	} else if (kind_v == 3) {
		float r = smoothstep(0.35, 0.75, fbm(p * 0.8 + 2.0));
		c = mix(c, accent_v * (0.75 + 0.5 * vnoise(p * 6.0)), r * rust_v);
		float plates = max(seam(p.x, 1.5, 0.01, aa), seam(p.y, 1.5, 0.01, aa));
		c = mix(c, c * 0.6, plates);
		c *= 1.0 - 0.18 * step(0.82, vnoise(p * 14.0)) * near;
	} else if (kind_v == 4) {
		float sheet = max(seam(p.x, 2.44, 0.008, aa), seam(p.y, 1.22, 0.008, aa));
		c *= 0.94 + 0.12 * sin(p.y * 40.0 + vnoise(p * vec2(0.6, 5.0)) * 6.0) * near;
		c = mix(c, c * 0.55, sheet);
		vec2 sc = vec2(fract(p.x / 2.44) * 2.44, fract(p.y / 0.3) * 0.3);
		float screw = (1.0 - smoothstep(0.012, 0.02, length(vec2(min(sc.x, 2.44 - sc.x) - 0.04, sc.y - 0.15)))) * near;
		c = mix(c, vec3(0.15), screw);
		float scuff = smoothstep(0.55, 0.85, vnoise(vec2(p.x * 0.4, p.y * 5.0)));
		c = mix(c, c * 0.7, scuff * 0.6);
		c = mix(c, c * vec3(0.8, 0.78, 0.74), smoothstep(0.6, 0.9, fbm(p * 0.5 + 9.0)) * rust_v);
	} else if (kind_v == 5) {
		float chip = smoothstep(0.7, 0.78, fbm(p * 1.6 + 5.0));
		c = mix(c, accent_v * (0.7 + 0.4 * vnoise(p * 9.0)), chip * rust_v);
	} else {
		float cut = max(seam(p.x, 6.0, 0.012, aa), seam(p.y, 6.0, 0.012, aa));
		c = mix(c, c * 0.72, cut);
		float oil = smoothstep(0.66, 0.8, fbm(p * 0.22 + 21.0));
		c = mix(c, c * vec3(0.55, 0.55, 0.6), oil * rust_v);
		float tyre = smoothstep(0.5, 0.55, abs(sin(p.x * 0.9 + fbm(p * 0.1) * 6.0))) * step(0.6, vnoise(p * 0.07 + 2.0));
		c = mix(c, c * 0.85, (1.0 - tyre) * 0.25 * grime_v);
		c *= 1.0 + (vnoise(p * 11.0) - 0.5) * 0.08 * near;
	}
	// grime_v: dark at the foot of walls, a little everywhere
	if (!top) {
		c = mix(c, c * 0.5, (1.0 - smoothstep(0.0, 1.4, h)) * grime_v);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	float n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	vec3 b = ALBEDO;
	if (LIGHT_IS_DIRECTIONAL) {
		// the moon: three hard toon bands, flat tops always in the lit band unless shadowed
		n_dot_l = mix(n_dot_l, max(n_dot_l, 0.62), step(0.7, wnormal.y) * step(0.05, n_dot_l));
		float shadow = smoothstep(0.3, 0.7, ATTENUATION);
		float lit = n_dot_l * shadow;
		float mid_band = smoothstep(0.08, 0.16, lit);
		float top_band = smoothstep(0.45, 0.55, lit);
		vec3 toon_col = mix(b * shadow_tint, b * mid_level, mid_band);
		toon_col = mix(toon_col, b, top_band);
		DIFFUSE_LIGHT += toon_col * LIGHT_COLOR * 0.5;
	} else {
		// lamps: banded on the facing, but the distance and cone falloff stay smooth so they make pools, not floods
		float band = mix(0.3, 1.0, smoothstep(0.08, 0.3, n_dot_l));
		DIFFUSE_LIGHT += b * band * ATTENUATION * LIGHT_COLOR * 0.5;
	}
}
