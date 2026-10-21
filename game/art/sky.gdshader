shader_type sky;

// Stylised sunset-palette sky for the park: banded horizon (coral, sunny yellow, aqua) rising to the bright blue overhead,
// a sun disc with two cel glow rings in the key light's direction, and big cel-shaded cumulus (value-noise blobs with a
// hard edge, white lit sides and a lavender shaded side facing away from the sun). No textures. See Toon.park_sky_environment().

uniform vec3 sun_dir = vec3(0.45, 0.79, 0.4);
uniform vec3 zenith_color : source_color = vec3(0.2, 0.5, 0.96);
uniform vec3 upper_color : source_color = vec3(0.3, 0.66, 1.0);
uniform vec3 aqua_color : source_color = vec3(0.58, 0.88, 0.95);
uniform vec3 yellow_color : source_color = vec3(1.0, 0.86, 0.42);
uniform vec3 coral_color : source_color = vec3(1.0, 0.5, 0.4);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_speed = 0.004;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

// Cloud field density at a point of the cloud plane: big cumulus blobs with a flat-ish base.
float cloud_density(vec2 p) {
	float big = fbm(p * 0.5);
	float detail = vnoise(p * 2.2) * 0.12;
	return big + detail;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	float t = max(h, 0.0);

	// Horizon bands: coral line, sunny yellow, aqua, then blue. Smooth blends between the stops.
	vec3 col = mix(coral_color, yellow_color, smoothstep(0.0, 0.05, t));
	col = mix(col, aqua_color, smoothstep(0.05, 0.2, t));
	col = mix(col, upper_color, smoothstep(0.18, 0.5, t));
	col = mix(col, zenith_color, smoothstep(0.5, 1.0, t));
	// Below the horizon: the coral band darkened, so a gap in the scenery never shows a white fog band.
	col = mix(col, coral_color * 0.8, smoothstep(0.0, -0.08, h));

	// Sun: a disc with two cel rings, in the key light's direction.
	vec3 s = normalize(sun_dir);
	float sd = dot(d, s);
	float ring2 = smoothstep(0.93, 0.935, sd);
	float ring1 = smoothstep(0.985, 0.988, sd);
	float disc = smoothstep(0.9975, 0.9980, sd);
	col = mix(col, col + vec3(0.18, 0.1, 0.0), ring2 * 0.5);
	col = mix(col, vec3(1.0, 0.86, 0.45), ring1 * 0.6);
	col = mix(col, vec3(1.0, 0.97, 0.78), disc);

	// Cumulus on a plane overhead.
	if (!AT_CUBEMAP_PASS && h > 0.015) {
		vec2 uv = d.xz / (h + 0.3) * 4.2 + vec2(TIME * cloud_speed, 0.0);
		float thr = mix(0.8, 0.56, cloud_cover);
		float n = cloud_density(uv);
		float body = smoothstep(thr, thr + 0.015, n);
		// Look toward the sun in cloud space: where the density there is lower, we are on the lit rim.
		vec2 toward = normalize(s.xz + vec2(0.0001)) * 0.16;
		float n_sun = cloud_density(uv + toward);
		float shade = smoothstep(-0.01, 0.05, n_sun - n);
		float deep = smoothstep(thr + 0.12, thr + 0.2, n);
		vec3 lit = vec3(1.0, 0.985, 0.95);
		vec3 shaded = vec3(0.74, 0.8, 0.94);
		vec3 low = vec3(0.62, 0.68, 0.88);
		vec3 ccol = mix(lit, shaded, shade);
		ccol = mix(ccol, low, shade * deep * 0.7);
		// warm the clouds toward the horizon and near the sun
		float warm = smoothstep(0.45, 0.0, t) * 0.5 + smoothstep(0.9, 0.99, sd) * 0.35;
		ccol = mix(ccol, vec3(1.0, 0.82, 0.66), warm);
		float fade = smoothstep(0.015, 0.2, h);
		col = mix(col, ccol, body * fade);
	}
	COLOR = col;
}
