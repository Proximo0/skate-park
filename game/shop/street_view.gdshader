shader_type spatial;
render_mode unshaded;

// What you see through the shop's front window and door: a sunset beach street. Sky gradient, a low sun, the sea,
// palm silhouettes, the far kerb and a few parked-car blobs. UV covers the whole backdrop quad.

uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

float sv_palm(vec2 p, float x0, float h) {
	float trunk = step(abs(p.x - x0 - 0.01 * sin(p.y * 6.0)), 0.006) * step(p.y, h) * step(0.25, p.y);
	float crown = 0.0;
	for (int i = 0; i < 6; i++) {
		float a = float(i) * 1.05 + 0.3;
		vec2 d = vec2(cos(a), sin(a) * 0.5 - 0.15);
		vec2 q = p - vec2(x0, h);
		float t = clamp(dot(q, d) / dot(d, d), 0.0, 0.09);
		crown = max(crown, step(length(q - d * t), 0.012 * (1.0 - t / 0.09) + 0.002));
	}
	return max(trunk, crown);
}

void fragment() {
	vec2 p = vec2(UV.x, 1.0 - UV.y);
	vec3 col = mix(vec3(1.0, 0.7, 0.45), vec3(0.98, 0.5, 0.6), smoothstep(0.38, 0.7, p.y));
	col = mix(col, vec3(0.45, 0.4, 0.8), smoothstep(0.7, 1.0, p.y));
	float sun = step(length((p - vec2(0.62, 0.42)) * vec2(2.4, 1.0)), 0.09);
	col = mix(col, vec3(1.0, 0.9, 0.5), sun);
	// sea
	float sea = step(p.y, 0.38);
	col = mix(col, mix(vec3(0.2, 0.55, 0.75), vec3(0.35, 0.75, 0.85), smoothstep(0.25, 0.38, p.y)), sea);
	col = mix(col, vec3(1.0, 0.85, 0.6), sea * step(0.3, p.y) * step(abs(p.x - 0.62), 0.04 * (p.y - 0.25) / 0.13) * step(0.5, fract(p.y * 60.0)));
	// palms
	float palms = 0.0;
	palms = max(palms, sv_palm(p, 0.12, 0.62));
	palms = max(palms, sv_palm(p, 0.3, 0.55));
	palms = max(palms, sv_palm(p, 0.86, 0.66));
	col = mix(col, vec3(0.2, 0.16, 0.3), palms);
	// promenade wall and sidewalk
	col = mix(col, vec3(0.88, 0.72, 0.62), step(p.y, 0.25));
	col = mix(col, vec3(0.72, 0.6, 0.58), step(p.y, 0.25) * step(0.23, p.y));
	col = mix(col, vec3(0.55, 0.52, 0.6), step(p.y, 0.14));
	// a couple of parked cars
	for (int i = 0; i < 2; i++) {
		float cx = i == 0 ? 0.22 : 0.74;
		vec3 cc = i == 0 ? vec3(0.4, 0.8, 0.85) : vec3(1.0, 0.85, 0.4);
		float car = step(abs(p.x - cx), 0.09) * step(p.y, 0.2) * step(0.12, p.y);
		car = max(car, step(abs(p.x - cx), 0.05) * step(p.y, 0.25) * step(0.19, p.y));
		col = mix(col, cc, car);
		col = mix(col, vec3(0.15, 0.15, 0.2), step(length((p - vec2(cx - 0.055, 0.12)) * vec2(1.0, 1.5)), 0.022) + step(length((p - vec2(cx + 0.055, 0.12)) * vec2(1.0, 1.5)), 0.022));
	}
	ALBEDO = col * tint;
}
