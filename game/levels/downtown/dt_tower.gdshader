shader_type spatial;
render_mode specular_disabled;

// Downtown buildings and skyline towers, drawn as MultiMeshes of a unit box (DtCity). Everything is worked out in
// world space, so one box of any size gets correctly sized floors and window bays. INSTANCE_CUSTOM carries the wall
// colour (rgb, sRGB) and the style in alpha: 0.0 punched windows (masonry), 0.1 glass curtain wall, 0.2 ribbon
// windows, 0.3 blank (no windows). Glass shows a sky reflection that brightens with height; windows fade to their
// average colour with distance so the far skyline never shimmers. Lit like Toon materials (toon_light include).

uniform float floor_h = 3.6;
uniform vec3 glass_low : source_color = vec3(0.32, 0.44, 0.58);
uniform vec3 glass_high : source_color = vec3(0.7, 0.84, 0.96);
uniform vec3 roof_tint : source_color = vec3(0.62, 0.62, 0.66);
uniform float ground_band = 5.0;  // storefront height left plain (kit facades sit there on near buildings)
uniform float night = 0.0;
uniform vec3 lamp : source_color = vec3(1.0, 0.82, 0.55);

#include "res://game/world/toon_light.gdshaderinc"

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 cust;
varying vec3 opos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	cust = INSTANCE_CUSTOM;
	opos = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec3 base = pow(clamp(cust.rgb, 0.0, 1.0), vec3(2.2));
	int style = int(cust.a * 10.0 + 0.5);
	vec3 n = normalize(wnrm);
	vec3 col = base;
	vec3 emit = vec3(0.0);
	if (abs(n.y) > 0.5) {
		// roof: tar and gravel, a shade darker, with a faint grid of roof joints
		vec2 rg = fract(wpos.xz / 4.0);
		float joint = step(0.96, max(rg.x, rg.y));
		col = base * roof_tint * (0.9 - 0.08 * joint);
	} else {
		vec2 t = normalize(vec2(-n.z, n.x));
		float u = dot(wpos.xz, t);
		float v = wpos.y;
		float bay = style == 1 ? 1.5 : (style == 2 ? 2.0 : 3.0);
		vec2 g = vec2(u / bay, v / floor_h);
		vec2 f = fract(g);
		vec2 id = floor(g);
		float win = 0.0;
		float avg = 0.0;
		if (style == 0) {
			win = step(0.24, f.x) * step(f.x, 0.76) * step(0.3, f.y) * step(f.y, 0.84);
			avg = 0.28;
		} else if (style == 1) {
			win = step(0.06, f.x) * step(f.x, 0.94) * step(0.1, f.y) * step(f.y, 0.96);
			avg = 0.76;
		} else if (style == 2) {
			win = step(0.36, f.y) * step(f.y, 0.86) * step(0.04, f.x);
			avg = 0.48;
		}
		vec2 fw = fwidth(g);
		float aa = clamp(1.0 - max(fw.x, fw.y) * 1.8, 0.0, 1.0);
		win = mix(avg, win, aa);
		if (v < ground_band) {
			win *= 0.0;
			col = base * 0.82;
		}
		float k = hash12(id + opos.xz * 0.37);
		float hgt = clamp((v - 4.0) / 140.0, 0.0, 1.0);
		vec3 glass = mix(glass_low, glass_high, hgt * 0.8 + 0.2 * k);
		// a blind or a dark room now and then
		glass *= mix(1.0, 0.55, step(0.8, k));
		col = mix(col, glass, win);
		emit = glass * win * 0.22;
		if (night > 0.5) {
			float on = step(0.55, hash12(id * 1.7 + opos.xz));
			emit += lamp * win * on * 0.9;
		}
		// a darker sill line under every floor on masonry
		if (style == 0) {
			col *= 1.0 - 0.18 * step(f.y, 0.06) * aa;
		}
	}
	ALBEDO = col;
	EMISSION = emit;
	ROUGHNESS = 1.0;
}
