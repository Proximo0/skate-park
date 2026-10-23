shader_type spatial;
render_mode specular_disabled;

// Cel-shaded park ramp / ledge surface: toon.gdshader's three light bands plus cheap procedural detail so slope and speed read.
// Used through ParkSurface.material(); everything is worked out per fragment, no textures.
//  - panel sheets: seams every 1.22 m along the riding line, a bevel highlight beside each seam, screw rows, plywood grain,
//    per-sheet tone (concrete kind: saw-cut joints, speckle, stains instead)
//  - wear: skate scuff streaks along the riding line, pale polish within half a metre of the lip, a bright coping-edge line
//  - contact shade: the base of every slope darkens a touch (fake AO at the inside corner) and the colour cools slightly
// Meshes from PieceKit.extrude_profile carry the metric coordinates: UV = (metres across, signed metres along the profile
// from the lip), UV2 = (metres to the lip, 1). Any other mesh (UV2.y = 0) gets the world-space grain only, no seams.

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int kind = 0;  // 0 painted plywood panels, 1 concrete
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.4, 0.62);
uniform float mid_level : hint_range(0.0, 1.0) = 0.8;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.22;
uniform float vertex_color_amount : hint_range(0.0, 1.0) = 0.0;
uniform float detail : hint_range(0.0, 1.0) = 1.0;

varying vec3 wpos;
varying float base_y;
varying vec3 wnorm;

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

// 1 on the line, 0 away from it: distance d (metres) from the nearest multiple of `step_m`, half width w.
float line_at(float s, float step_m, float w, float aa) {
	float d = abs(fract(s / step_m + 0.5) - 0.5) * step_m;
	return 1.0 - smoothstep(w - aa, w + aa, d);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	base_y = VERTEX.y;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = albedo.rgb * mix(vec3(1.0), COLOR.rgb, vertex_color_amount);
	float metric = step(0.5, UV2.y);
	float far_fade = 1.0 - smoothstep(18.0, 60.0, length(VERTEX));
	float near_fade = 1.0 - smoothstep(6.0, 26.0, length(VERTEX));
	vec3 wn = normalize(wnorm);
	if (detail > 0.0) {
		// flat tops of non-metric meshes (box ledges, floor skins) take world x / z so they still get sheets
		bool seams = metric > 0.5 || abs(wn.y) > 0.9;
		vec2 q = metric > 0.5 ? UV : wpos.xz;           // x across, s along the riding line
		float s = metric > 0.5 ? UV.y : wpos.z;
		float aa = max(fwidth(q.x), fwidth(s)) * 0.9 + 0.003;
		float lipd = metric > 0.5 ? UV2.x : 9.0;
		float sheet = floor(s / 1.22);
		float tone = hash21(vec2(sheet, 3.0));
		float shade = 1.0;
		if (kind == 0) {
			// plywood sheets: tone per sheet, grain along the riding line, dark seam with a lit bevel beside it
			shade *= 0.965 + 0.07 * tone;
			float grain = vnoise(vec2(q.x * 7.0 + tone * 40.0, s * 0.7)) * 0.6 + vnoise(vec2(q.x * 26.0, s * 1.6)) * 0.4;
			shade *= 1.0 + (grain - 0.5) * 0.045 * far_fade * (0.35 + 0.65 * metric);
			if (seams) {
				float seam = line_at(s, 1.22, 0.012, aa);
				float bevel = line_at(s - 0.035, 1.22, 0.02, aa * 1.5);
				shade *= 1.0 - 0.34 * seam;
				shade *= 1.0 + 0.07 * bevel * (1.0 - seam);
				float side = line_at(q.x, 2.44, 0.010, aa);  // butt joints between sheets across the width
				shade *= 1.0 - 0.22 * side * (0.6 + 0.4 * step(0.5, fract(sheet * 0.5)));
				// screw rows 0.12 m either side of each seam
				float sr = abs(fract(s / 1.22 + 0.5) - 0.5) * 1.22;
				float srow = 1.0 - smoothstep(0.012, 0.02, abs(sr - 0.12));
				vec2 sp = vec2(fract(q.x / 0.3 + 0.5) - 0.5, 0.0) * 0.3;
				float screw = (1.0 - smoothstep(0.014, 0.026, abs(sp.x))) * srow;
				shade *= 1.0 - 0.28 * screw * near_fade;
			}
		} else {
			// concrete: saw-cut joints, speckle and soft stains
			shade *= 0.97 + 0.06 * tone;
			shade *= 1.0 + (vnoise(q * 11.0 + vec2(0.0, s * 8.0)) - 0.5) * 0.07 * far_fade;
			float stain = smoothstep(0.62, 0.8, vnoise(vec2(q.x * 0.5, s * 0.45) + 17.0));
			shade *= 1.0 - 0.07 * stain;
			if (seams) {
				shade *= 1.0 - 0.3 * line_at(s, 2.44, 0.010, aa);
				shade *= 1.0 - 0.2 * line_at(q.x, 3.05, 0.010, aa);
			}
		}
		// scuffs: long streaks along the riding line, strongest where people ride (mid-slope, centre third)
		float streak = vnoise(vec2(q.x * 3.2, s * 0.35)) * vnoise(vec2(q.x * 11.0 + 5.0, s * 0.9));
		float scuff = smoothstep(0.2, 0.4, streak) * far_fade;
		shade *= 1.0 + 0.04 * scuff * (0.3 + 0.7 * metric);
		// wear toward the lip: pale polished band, a brighter line right at the coping edge
		float polish = (1.0 - smoothstep(0.0, 0.55, lipd)) * metric;
		shade *= 1.0 + 0.10 * polish * (0.5 + 0.5 * vnoise(vec2(q.x * 4.0, s * 3.0)));
		float edge = (1.0 - smoothstep(0.03, 0.09, lipd)) * metric;
		shade *= 1.0 + 0.16 * edge;
		c *= shade;
		// contact shade at the foot of a slope: darker and a touch cooler right at the ground, only where the surface leans
		float lean = 1.0 - smoothstep(0.93, 0.995, abs(wn.y));
		float foot = (1.0 - smoothstep(0.0, 0.9, base_y)) * lean;
		c *= mix(vec3(1.0), vec3(0.72, 0.75, 0.88), foot * 1.0 * detail);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

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
	DIFFUSE_LIGHT += vec3(1.0) * rim * clamp(ATTENUATION, 0.4, 1.0);
}
