shader_type spatial;
render_mode unshaded;

// The lounge TV: a looping cartoon skate clip. A sunset sky, a halfpipe, and a little skater riding it back and
// forth, boosting an air with a full spin off each wall. Scanlines, a soft vignette and a "REC"-style dot.

uniform float aspect = 1.33;
uniform float brightness = 1.0;

float tv_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float tv_ramp(float x) {
	return 0.12 + 0.5 * pow(abs(x - 0.5) * 2.0, 2.4);
}

void fragment() {
	vec2 p = vec2(UV.x, 1.0 - UV.y);
	float t = TIME;
	vec3 sky = mix(vec3(1.0, 0.56, 0.42), vec3(0.32, 0.28, 0.72), smoothstep(0.1, 1.0, p.y));
	vec3 col = sky;
	// sun with retro stripes
	vec2 sp = (p - vec2(0.5, 0.6)) * vec2(aspect, 1.0);
	float sun = step(length(sp), 0.2) * step(0.35, fract(p.y * 18.0 + 0.2) + step(0.7, p.y));
	col = mix(col, vec3(1.0, 0.86, 0.38), sun);
	// halfpipe
	float rh = tv_ramp(p.x);
	if (p.y < rh) {
		col = mix(vec3(0.98, 0.72, 0.4), vec3(0.85, 0.52, 0.3), step(0.5, fract(p.x * 12.0)) * 0.35);
		if (p.y > rh - 0.015) col = vec3(0.92, 0.94, 0.98);
	}
	// rider: runs along the ramp, airs out above each wall
	float ph = t * 1.4;
	float s = sin(ph);
	float x = 0.5 + 0.43 * s;
	float base_y = tv_ramp(x);
	float air = max(abs(s) - 0.82, 0.0) / 0.18;
	float y = base_y + 0.36 * air * air;
	float spin = air * 6.2831 * sign(s);
	vec2 rp = (p - vec2(x, y)) * vec2(aspect, 1.0);
	float ca = cos(spin);
	float sa = sin(spin);
	vec2 q = vec2(ca * rp.x + sa * rp.y, -sa * rp.x + ca * rp.y);
	float board = tv_seg(q, vec2(-0.05, 0.0), vec2(0.05, 0.0));
	float legs = tv_seg(q, vec2(-0.02, 0.01), vec2(0.0, 0.06)) - 0.003;
	float legs2 = tv_seg(q, vec2(0.025, 0.01), vec2(0.0, 0.06)) - 0.003;
	float torso = tv_seg(q, vec2(0.0, 0.06), vec2(0.0, 0.11)) - 0.006;
	float head = length(q - vec2(0.0, 0.135)) - 0.022;
	float arms = tv_seg(q, vec2(-0.045, 0.1), vec2(0.045, 0.1)) - 0.002;
	if (board < 0.008) col = vec3(0.15, 0.75, 0.8);
	if (min(min(legs, legs2), min(torso, arms)) < 0.006) col = vec3(1.0, 0.42, 0.55);
	if (head < 0.0) col = vec3(1.0, 0.85, 0.42);
	// scanlines, vignette, flicker
	col *= 0.86 + 0.14 * step(0.5, fract(UV.y * 90.0));
	vec2 v = UV - 0.5;
	col *= 1.0 - 0.9 * dot(v, v);
	col *= 0.96 + 0.04 * sin(t * 37.0);
	float rec = step(length((UV - vec2(0.9, 0.1)) * vec2(aspect, 1.0)), 0.03) * step(0.5, fract(t * 0.8));
	col = mix(col, vec3(1.0, 0.2, 0.25), rec);
	ALBEDO = col * brightness;
}
