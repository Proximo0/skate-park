shader_type spatial;
// Distant city blocks for the Creepy Warehouse: flat night-blue walls with a grid of windows (a seeded share lit warm
// or cool, some flickering TVs), darker roofs, a moonlit rim on the faces turned to the moon and a manual distance haze
// toward the horizon colour (scene fog is off here: at 300 m and more it would swallow the skyline whole).
// UV is (x + z, y) in metres (WhGeo.Batch), so the window grid is world-sized on every face.
render_mode unshaded, fog_disabled, shadows_disabled;

uniform vec3 wall : source_color = vec3(0.07, 0.08, 0.13);
uniform vec3 roof : source_color = vec3(0.04, 0.045, 0.08);
uniform vec3 haze : source_color = vec3(0.13, 0.12, 0.18);
uniform vec3 rim : source_color = vec3(0.28, 0.33, 0.5);
uniform vec3 moon_dir = vec3(0.25, 0.8, -1.0);
uniform float lit_share : hint_range(0.0, 1.0) = 0.22;
uniform float haze_near = 180.0;
uniform float haze_far = 700.0;
uniform vec2 cell = vec2(3.2, 3.6);

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = wall;
	vec3 n = normalize(wnrm);
	if (n.y > 0.5) {
		col = roof;
	} else {
		// slight darkening toward the street, a cool moonlit rim on the faces that turn toward the moon
		col *= mix(0.7, 1.05, clamp(wpos.y / 60.0, 0.0, 1.0));
		float facing = max(dot(n, normalize(vec3(moon_dir.x, 0.0, moon_dir.z))), 0.0);
		col += rim * facing * 0.35;
		// window grid
		vec2 g = UV / cell;
		vec2 id = floor(g);
		vec2 f = fract(g);
		float pane = step(0.18, f.x) * step(f.x, 0.82) * step(0.25, f.y) * step(f.y, 0.78);
		float h = hash(id + floor(wpos.xz / 37.0) * 7.13);
		float ground = step(1.0, id.y);
		if (h < lit_share && pane > 0.5 && ground > 0.5) {
			float k = hash(id * 1.7 + 3.1);
			vec3 warm = vec3(1.0, 0.72, 0.38);
			vec3 cool = vec3(0.55, 0.75, 1.0);
			vec3 wc = mix(warm, cool, step(0.7, k)) * mix(0.55, 1.25, hash(id + 9.0));
			// a few TVs flicker
			if (k > 0.94) {
				wc = cool * (0.6 + 0.4 * sin(TIME * (6.0 + k * 9.0) + h * 40.0));
			}
			col = wc;
		} else if (pane > 0.5) {
			col *= 0.72;
		}
	}
	float d = length(wpos - CAMERA_POSITION_WORLD);
	float hz = smoothstep(haze_near, haze_far, d) * 0.85;
	ALBEDO = mix(col, haze, hz);
}
