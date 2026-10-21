shader_type spatial;
render_mode unshaded;

// Procedural anime skate and surf posters, picked by `kind`:
// 0 surf sunset (striped sun, layered waves, a curling wave), 1 skate burst (speed lines, halftone dots, a deck),
// 2 anime face (big sparkly eyes, bangs, blush on speed lines), 3 street skate (city skyline, a kickflip arc).
// Text goes on top as Label3D. `tint` darkens it to sit in the room's light.

uniform int kind = 0;
uniform vec3 tint : source_color = vec3(0.92, 0.9, 0.88);
uniform float aspect = 0.68;  // width / height

float ps_circle(vec2 p, vec2 c, float r) {
	return step(length(p - c), r);
}

float ps_ellipse(vec2 p, vec2 c, vec2 r) {
	vec2 d = (p - c) / r;
	return step(dot(d, d), 1.0);
}

float ps_box(vec2 p, vec2 c, vec2 h, float ang) {
	vec2 d = p - c;
	float ca = cos(ang);
	float sa = sin(ang);
	d = vec2(ca * d.x + sa * d.y, -sa * d.x + ca * d.y);
	return step(abs(d.x), h.x) * step(abs(d.y), h.y);
}

vec3 ps_speed_lines(vec2 p, vec2 c, vec3 a, vec3 b, float n) {
	float ang = atan(p.y - c.y, p.x - c.x);
	return mix(a, b, step(0.55, fract(ang / 6.2831 * n)));
}

vec3 ps_surf(vec2 p) {
	vec3 col = mix(vec3(1.0, 0.62, 0.45), vec3(0.98, 0.42, 0.6), smoothstep(0.45, 1.0, p.y));
	col = mix(col, vec3(0.45, 0.3, 0.7), smoothstep(0.8, 1.05, p.y));
	vec2 sc = vec2(0.5, 0.58);
	float sun = ps_circle(p, sc, 0.26);
	float stripes = step(0.3, fract(p.y * 22.0)) + step(0.62, p.y);
	col = mix(col, mix(vec3(1.0, 0.86, 0.35), vec3(1.0, 0.6, 0.3), smoothstep(0.75, 0.4, p.y)), sun * clamp(stripes, 0.0, 1.0));
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float h = 0.44 - fi * 0.09 + 0.025 * sin(p.x * 18.0 + fi * 1.7);
		vec3 wc = mix(vec3(0.15, 0.75, 0.8), vec3(0.05, 0.3, 0.55), fi / 3.0);
		col = mix(col, wc, step(p.y, h));
		col = mix(col, vec3(0.95, 0.98, 1.0), step(p.y, h) * step(h - 0.012, p.y));
	}
	// curling wave on the left
	float curl = ps_circle(p, vec2(0.18, 0.4), 0.17) * (1.0 - ps_circle(p, vec2(0.24, 0.37), 0.1));
	col = mix(col, vec3(0.1, 0.6, 0.75), curl);
	return col;
}

vec3 ps_skate(vec2 p) {
	vec3 col = ps_speed_lines(p, vec2(0.5, 0.55), vec3(1.0, 0.85, 0.3), vec3(1.0, 0.72, 0.25), 28.0);
	vec2 g = fract(p * vec2(18.0, 18.0 / aspect)) - 0.5;
	float dots = step(length(g), 0.22 * smoothstep(0.1, 0.9, p.y));
	col = mix(col, vec3(1.0, 0.45, 0.6), dots * 0.8);
	float ang = 0.6;
	float deck = ps_box(p, vec2(0.5, 0.55), vec2(0.13, 0.36), ang);
	deck = max(deck, ps_circle(p, vec2(0.5, 0.55) + vec2(sin(ang), cos(ang)) * vec2(-0.36, 0.36), 0.13));
	deck = max(deck, ps_circle(p, vec2(0.5, 0.55) - vec2(sin(ang), cos(ang)) * vec2(-0.36, 0.36), 0.13));
	vec3 deck_col = mix(vec3(0.15, 0.7, 0.78), vec3(0.98, 0.95, 0.9), ps_box(p, vec2(0.5, 0.55), vec2(0.04, 0.5), ang));
	col = mix(col, vec3(0.11, 0.11, 0.18), max(deck, ps_box(p, vec2(0.5, 0.55), vec2(0.145, 0.375), ang)) - deck);
	col = mix(col, deck_col, deck);
	float star = ps_circle(p, vec2(0.5, 0.55), 0.07);
	col = mix(col, vec3(1.0, 0.95, 0.4), star);
	return col;
}

vec3 ps_face(vec2 p) {
	vec3 col = ps_speed_lines(p, vec2(0.5, 0.5), vec3(0.62, 0.86, 1.0), vec3(0.78, 0.93, 1.0), 36.0);
	vec2 q = vec2((p.x - 0.5) * aspect + 0.5, p.y);
	vec3 skin = vec3(1.0, 0.86, 0.74);
	vec3 hair = vec3(0.96, 0.45, 0.62);
	// hair back
	col = mix(col, hair * 0.85, ps_ellipse(q, vec2(0.5, 0.5), vec2(0.36, 0.42)));
	// face
	float face = ps_ellipse(q, vec2(0.5, 0.46), vec2(0.27, 0.3));
	face = max(face, ps_ellipse(q, vec2(0.5, 0.33), vec2(0.17, 0.18)));
	col = mix(col, skin, face);
	// bangs: a saw edge
	float edge = 0.6 + 0.07 * abs(fract(q.x * 7.0) - 0.5) * 2.0;
	col = mix(col, hair, step(edge, q.y) * ps_ellipse(q, vec2(0.5, 0.6), vec2(0.34, 0.3)));
	// eyes
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		vec2 c = vec2(0.5 + sx * 0.12, 0.46);
		col = mix(col, vec3(1.0), ps_ellipse(q, c, vec2(0.075, 0.095)));
		col = mix(col, vec3(0.2, 0.45, 0.9), ps_ellipse(q, c + vec2(0.0, -0.01), vec2(0.06, 0.085)));
		col = mix(col, vec3(0.45, 0.85, 1.0), ps_ellipse(q, c + vec2(0.0, -0.04), vec2(0.045, 0.04)));
		col = mix(col, vec3(0.08, 0.1, 0.25), ps_ellipse(q, c + vec2(0.0, 0.0), vec2(0.03, 0.045)));
		col = mix(col, vec3(1.0), ps_circle(q, c + vec2(sx * 0.02, 0.03), 0.02));
		col = mix(col, vec3(0.11, 0.11, 0.18), ps_box(q, c + vec2(0.0, 0.09), vec2(0.085, 0.012), sx * 0.15));
		col = mix(col, vec3(1.0, 0.6, 0.62), ps_ellipse(q, c + vec2(sx * 0.03, -0.12), vec2(0.05, 0.022)));
	}
	col = mix(col, vec3(0.85, 0.3, 0.4), ps_ellipse(q, vec2(0.5, 0.28), vec2(0.035, 0.018)));
	// hair clip star
	col = mix(col, vec3(1.0, 0.86, 0.3), ps_circle(q, vec2(0.74, 0.68), 0.035));
	return col;
}

vec3 ps_street(vec2 p) {
	vec3 col = mix(vec3(0.4, 0.82, 0.98), vec3(0.82, 0.95, 1.0), smoothstep(1.0, 0.3, p.y));
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float x0 = fi / 7.0;
		float h = 0.3 + 0.18 * fract(sin(fi * 12.9) * 43.7);
		float b = step(x0, p.x) * step(p.x, x0 + 0.13) * step(p.y, h);
		col = mix(col, mix(vec3(0.5, 0.45, 0.75), vec3(0.62, 0.55, 0.85), fract(fi * 0.37)), b);
		vec2 w = fract(vec2((p.x - x0) * 40.0, p.y * 40.0));
		col = mix(col, vec3(1.0, 0.9, 0.55), b * step(0.5, w.x) * step(0.5, w.y) * step(0.7, fract(sin(floor(p.y * 40.0) * 3.1 + fi) * 91.3)));
	}
	col = mix(col, vec3(0.75, 0.72, 0.7), step(p.y, 0.16));
	// kickflip arc of motion dashes
	float arc = abs(length((p - vec2(0.5, 0.15)) * vec2(1.0, 1.4)) - 0.42);
	col = mix(col, vec3(1.0), step(arc, 0.01) * step(0.5, fract(atan(p.y - 0.15, p.x - 0.5) * 8.0)) * step(0.2, p.y));
	float deck = ps_box(p, vec2(0.64, 0.6), vec2(0.15, 0.035), -0.5);
	col = mix(col, vec3(1.0, 0.4, 0.45), deck);
	col = mix(col, vec3(1.0, 0.85, 0.35), ps_circle(p, vec2(0.52, 0.65), 0.025) + ps_circle(p, vec2(0.75, 0.53), 0.025));
	return col;
}

void fragment() {
	vec2 p = vec2(UV.x, 1.0 - UV.y);
	vec3 col;
	if (kind == 0) col = ps_surf(p);
	else if (kind == 1) col = ps_skate(p);
	else if (kind == 2) col = ps_face(p);
	else col = ps_street(p);
	// paper border
	float border = step(p.x, 0.035) + step(0.965, p.x) + step(p.y, 0.025) + step(0.975, p.y);
	col = mix(col, vec3(0.98, 0.96, 0.9), clamp(border, 0.0, 1.0));
	ALBEDO = col * tint;
}
