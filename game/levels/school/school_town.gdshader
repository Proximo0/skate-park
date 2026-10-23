shader_type spatial;
render_mode specular_disabled;

// The town round the School level (game/levels/school/school_backdrop.gd): MultiMesh houses and blocks. Per instance
// (INSTANCE_CUSTOM): rgb = wall colour (sRGB), a = seed. Per vertex: COLOR.a = 1 for walls, 0 for the roof, which takes one
// of four roof colours by seed. Windows are a world-space grid on the walls; at dusk about half are lit (emissive).

uniform float floor_h = 3.0;
uniform float bay = 3.2;
uniform float win_w = 1.3;
uniform float win_h = 1.2;
uniform float sill = 1.0;
uniform float floors = 2.0;
uniform float lit_ratio = 0.45;
uniform float lit_energy = 1.7;
uniform vec4 lit_col : source_color = vec4(1.0, 0.76, 0.45, 1.0);
uniform vec4 glass : source_color = vec4(0.16, 0.18, 0.28, 1.0);
uniform vec4 roof_a : source_color = vec4(0.42, 0.26, 0.24, 1.0);
uniform vec4 roof_b : source_color = vec4(0.3, 0.3, 0.34, 1.0);
uniform vec4 roof_c : source_color = vec4(0.5, 0.36, 0.28, 1.0);
uniform vec4 roof_d : source_color = vec4(0.26, 0.32, 0.38, 1.0);

#include "res://game/world/toon_light.gdshaderinc"

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 inst;
varying float wall_mask;
varying float base_y;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	inst = INSTANCE_CUSTOM;
	wall_mask = COLOR.a;
	base_y = MODEL_MATRIX[3].y;
}

void fragment() {
	vec3 c = pow(inst.rgb, vec3(2.2));  // the custom data is an sRGB colour
	vec3 em = vec3(0.0);
	float s = inst.a * 97.0;
	if (wall_mask < 0.5) {
		float k = fract(s * 0.37);
		c = k < 0.25 ? roof_a.rgb : (k < 0.5 ? roof_b.rgb : (k < 0.75 ? roof_c.rgb : roof_d.rgb));
		c *= 0.9 + 0.1 * h21(floor(wpos.xz * 2.0));
	} else if (abs(wnrm.y) < 0.5) {
		vec3 t = normalize(cross(vec3(0.0, 1.0, 0.0), wnrm));
		float u = dot(wpos, t);
		float v = wpos.y - base_y;
		float f = floor(v / floor_h);
		float fv = v - f * floor_h;
		float cell = floor(u / bay);
		float fu = (fract(u / bay) - 0.5) * bay;
		if (f >= 0.0 && f < floors && abs(fu) < win_w * 0.5 && fv > sill && fv < sill + win_h) {
			float hsh = h21(vec2(cell + s, f * 3.7 + s * 0.3));
			if (hsh < lit_ratio) {
				vec3 l = lit_col.rgb * (0.8 + 0.4 * h21(vec2(cell, s)));
				c = l * 0.3;
				em = l * lit_energy;
			} else {
				c = glass.rgb;
			}
		}
		if (v < 0.4) {
			c *= 0.7;
		}
	}
	ALBEDO = c;
	EMISSION = em;
}
