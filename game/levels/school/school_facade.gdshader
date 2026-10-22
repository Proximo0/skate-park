shader_type spatial;
render_mode specular_disabled;

// School buildings (game/levels/school): brick or painted-block walls with a window grid worked out in world space, so a
// plain box becomes a classroom block with no UVs or textures. Some windows are lit (warm, emissive) for the dusk mood,
// the rest are dark glass with a sky gradient. Flat tops get the roof colour (gravel), undersides a darker soffit.
// Lighting: the toon three-band light shared with the world kit (toon_light.gdshaderinc).

uniform vec4 wall : source_color = vec4(0.66, 0.34, 0.27, 1.0);
uniform vec4 trim : source_color = vec4(0.93, 0.89, 0.8, 1.0);
uniform vec4 glass : source_color = vec4(0.14, 0.19, 0.3, 1.0);
uniform vec4 glass_top : source_color = vec4(0.42, 0.42, 0.62, 1.0);
uniform vec4 lit_col : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform vec4 roof : source_color = vec4(0.44, 0.43, 0.46, 1.0);
uniform float base_y = 0.0;  // ground-floor level the window rows count from
uniform float floor_h = 4.2;  // storey height
uniform float bay = 3.4;  // window spacing along the wall
uniform float win_w = 2.4;
uniform float win_h = 1.9;
uniform float sill = 1.0;  // window bottom above each storey's floor
uniform float top_y = 9.0;  // height (above base_y) of the cornice band; no windows above top_y - 0.7
uniform float floors = 2.0;  // window rows
uniform float lit_ratio = 0.35;
uniform float lit_energy = 1.6;
uniform float brick = 1.0;  // 1 brick courses, 0 smooth painted block
uniform float course = 0.6;  // block course height when brick = 0
uniform float seed = 1.0;
uniform float plinth = 0.6;  // darker base band height

#include "res://game/world/toon_light.gdshaderinc"

varying vec3 wpos;
varying vec3 wnrm;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = wall.rgb;
	vec3 em = vec3(0.0);
	float dist = length(VERTEX);
	if (wnrm.y > 0.6) {
		// gravel roof
		float g = vn(wpos.xz * 3.0) * 0.5 + vn(wpos.xz * 0.4) * 0.5;
		c = roof.rgb * (0.9 + 0.15 * g);
	} else if (wnrm.y < -0.6) {
		c = wall.rgb * 0.55;
	} else {
		vec3 t = normalize(cross(vec3(0.0, 1.0, 0.0), wnrm));
		float u = dot(wpos, t);
		float v = wpos.y - base_y;
		float aa = max(fwidth(u), fwidth(v)) + 0.002;
		// walls: brick courses or painted block
		if (brick > 0.5) {
			float row = floor(v / 0.22);
			float uu = u / 0.5 + 0.5 * mod(row, 2.0);
			float dh = abs(fract(v / 0.22 + 0.5) - 0.5) * 0.22;
			float dv = abs(fract(uu + 0.5) - 0.5) * 0.5;
			float mortar = 1.0 - smoothstep(0.01, 0.01 + aa, min(dh, dv));
			float fade = 1.0 - smoothstep(18.0, 60.0, dist);
			float tone = 0.92 + 0.14 * h21(vec2(floor(uu), row) + seed);
			c *= mix(1.0, tone, fade);
			c = mix(c, c * 0.78, mortar * fade * 0.8);
		} else {
			float fade = 1.0 - smoothstep(18.0, 70.0, dist);
			float line = 1.0 - smoothstep(0.015, 0.015 + aa, abs(fract(v / course + 0.5) - 0.5) * course);
			c = mix(c, c * 0.88, line * fade);
			c *= 0.96 + 0.06 * vn(vec2(u, v) * 0.3);
		}
		// plinth and cornice bands
		if (v < plinth) {
			c = wall.rgb * 0.62;
		}
		if (v > top_y - 0.55) {
			c = trim.rgb * (v > top_y - 0.12 ? 0.82 : 1.0);
		}
		// windows: one row per storey
		float f = floor(v / floor_h);
		float fv = v - f * floor_h;
		float cell = floor(u / bay);
		float fu = (fract(u / bay) - 0.5) * bay;
		if (f < floors && v < top_y - 0.7 && f >= 0.0) {
			float hx = win_w * 0.5;
			float y0 = sill;
			float y1 = sill + win_h;
			float fr = 0.13;
			bool in_frame = abs(fu) < hx + fr && fv > y0 - fr && fv < y1 + fr;
			bool in_glass = abs(fu) < hx && fv > y0 && fv < y1;
			if (in_frame) {
				c = trim.rgb;
			}
			if (fv > y0 - fr - 0.12 && fv < y0 - fr && abs(fu) < hx + fr + 0.1) {
				c = trim.rgb * 0.9;  // sill
			}
			if (in_glass) {
				float hsh = h21(vec2(cell * 1.7 + seed * 13.0, f * 3.1 + seed));
				float k = (fv - y0) / win_h;
				bool mull = abs(fu) < 0.05 || abs(fv - (y0 + win_h * 0.62)) < 0.04;
				if (hsh < lit_ratio) {
					// lit classroom: warm, brighter toward the ceiling, a blind half down on some
					float blind = step(0.5, h21(vec2(cell, f + 7.0) + seed)) * step(0.7, k);
					vec3 l = lit_col.rgb * (0.75 + 0.35 * k) * (blind > 0.5 ? 0.7 : 1.0);
					c = l * 0.35;
					em = l * lit_energy;
				} else {
					c = mix(glass.rgb, glass_top.rgb, smoothstep(0.1, 1.0, k) * 0.7);
					c += vec3(0.05) * step(0.85, fract((fu + fv) * 0.35 + hsh));
				}
				if (mull) {
					c = trim.rgb * 0.75;
					em = vec3(0.0);
				}
			}
		}
	}
	ALBEDO = c;
	EMISSION = em;
}
