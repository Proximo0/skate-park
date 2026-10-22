shader_type sky;

// The levels' sky: game/art/sky.gdshader (the practice park's banded sunset-palette sky with cel clouds and a ringed sun
// disc) extended with everything a Mood preset (game/world/mood.gd) needs: per-mood cloud colours, a moon instead of the
// sun (night), stars, a warm city glow on the horizon and a sea-horizon colour below it. Same contract as the park sky:
// sun_dir is the direction TO the sun (the key light's +Z axis). No textures, works in the Compatibility renderer.

uniform vec3 sun_dir = vec3(0.45, 0.79, 0.4);
uniform vec3 zenith_color : source_color = vec3(0.2, 0.5, 0.96);
uniform vec3 upper_color : source_color = vec3(0.3, 0.66, 1.0);
uniform vec3 aqua_color : source_color = vec3(0.58, 0.88, 0.95);
uniform vec3 yellow_color : source_color = vec3(1.0, 0.86, 0.42);
uniform vec3 coral_color : source_color = vec3(1.0, 0.5, 0.4);
uniform vec3 below_color : source_color = vec3(0.8, 0.4, 0.32);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_speed = 0.004;
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.985, 0.95);
uniform vec3 cloud_shaded : source_color = vec3(0.74, 0.8, 0.94);
uniform vec3 cloud_low : source_color = vec3(0.62, 0.68, 0.88);
uniform vec3 cloud_warm : source_color = vec3(1.0, 0.82, 0.66);
uniform float cloud_warmth : hint_range(0.0, 1.0) = 0.5;
uniform vec3 disc_color : source_color = vec3(1.0, 0.97, 0.78);
uniform vec3 ring_color : source_color = vec3(1.0, 0.86, 0.45);
uniform float sun_size : hint_range(0.5, 4.0) = 1.0;
uniform float sun_rings : hint_range(0.0, 1.0) = 1.0;
uniform float moon : hint_range(0.0, 1.0) = 0.0;
uniform float stars : hint_range(0.0, 1.0) = 0.0;
uniform vec3 glow_color : source_color = vec3(1.0, 0.6, 0.3);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.0;
// 0..1 of the band height: how low the coral band sits (1 = the park sky, 0.4 = a thin line on a clear day).
uniform float band_scale : hint_range(0.2, 2.0) = 1.0;

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

float cloud_density(vec2 p) {
	return fbm(p * 0.5) + vnoise(p * 2.2) * 0.12;
}

// A star field: one candidate star per cell of a grid on the sky, twinkling slowly.
float star_field(vec3 d) {
	vec2 uv = vec2(atan(d.x, d.z) * 60.0, asin(clamp(d.y, -1.0, 1.0)) * 60.0);
	vec2 cell = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float h = hash21(cell);
	if (h < 0.86) {
		return 0.0;
	}
	vec2 off = vec2(hash21(cell + 7.1), hash21(cell + 3.7)) - 0.5;
	float r = length(f - off * 0.6);
	float size = mix(0.05, 0.13, hash21(cell + 1.3));
	float tw = 0.75 + 0.25 * sin(TIME * (1.0 + 3.0 * h) + h * 40.0);
	return smoothstep(size, 0.0, r) * tw * (h - 0.86) / 0.14;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	float t = max(h, 0.0) / band_scale;

	vec3 col = mix(coral_color, yellow_color, smoothstep(0.0, 0.05, t));
	col = mix(col, aqua_color, smoothstep(0.05, 0.2, t));
	col = mix(col, upper_color, smoothstep(0.18, 0.5, t));
	col = mix(col, zenith_color, smoothstep(0.5, 1.0, max(h, 0.0)));
	// below the horizon: the far sea or the far ground, never a white fog band through a gap in the scenery
	col = mix(col, below_color, smoothstep(0.0, -0.06, h));

	// warm light-pollution / city glow hugging the horizon
	col += glow_color * glow_strength * (1.0 - smoothstep(0.0, 0.22, abs(h))) * 0.6;

	// stars, fading out toward the horizon glow
	if (stars > 0.0 && h > 0.0) {
		col += vec3(0.9, 0.93, 1.0) * star_field(d) * stars * smoothstep(0.02, 0.25, h);
	}

	// sun (or moon) disc with cel rings
	vec3 s = normalize(sun_dir);
	float sd = dot(d, s);
	float k = sun_size;
	float ring2 = smoothstep(1.0 - 0.07 * k, 1.0 - 0.065 * k, sd);
	float ring1 = smoothstep(1.0 - 0.015 * k, 1.0 - 0.012 * k, sd);
	float disc = smoothstep(1.0 - 0.0025 * k, 1.0 - 0.0020 * k, sd);
	col = mix(col, col + ring_color * 0.18, ring2 * 0.5 * sun_rings);
	col = mix(col, ring_color, ring1 * 0.6 * sun_rings);
	vec3 dc = disc_color;
	if (moon > 0.0) {
		// a soft halo and a disc with a few darker maria
		col += ring_color * moon * 0.25 * pow(max(sd, 0.0), 220.0);
		vec3 side = normalize(cross(s, vec3(0.0, 1.0, 0.0)));
		vec3 up = cross(side, s);
		vec2 m = vec2(dot(d - s, side), dot(d - s, up)) / (0.045 * k);
		float maria = smoothstep(0.55, 0.75, vnoise(m * 6.0 + 3.0));
		dc = mix(disc_color, disc_color * 0.78, maria * moon);
	}
	col = mix(col, dc, disc);

	// cumulus on a plane overhead
	if (!AT_CUBEMAP_PASS && h > 0.015 && cloud_cover > 0.0) {
		vec2 uv = d.xz / (h + 0.3) * 4.2 + vec2(TIME * cloud_speed, 0.0);
		float thr = mix(0.8, 0.56, cloud_cover);
		float n = cloud_density(uv);
		float body = smoothstep(thr, thr + 0.015, n);
		vec2 toward = normalize(s.xz + vec2(0.0001)) * 0.16;
		float n_sun = cloud_density(uv + toward);
		float shade = smoothstep(-0.01, 0.05, n_sun - n);
		float deep = smoothstep(thr + 0.12, thr + 0.2, n);
		vec3 ccol = mix(cloud_lit, cloud_shaded, shade);
		ccol = mix(ccol, cloud_low, shade * deep * 0.7);
		float warm = (smoothstep(0.45, 0.0, t) * 0.5 + smoothstep(0.9, 0.99, sd) * 0.35) * cloud_warmth * 2.0;
		ccol = mix(ccol, cloud_warm, clamp(warm, 0.0, 1.0));
		float fade = smoothstep(0.015, 0.2, h);
		col = mix(col, ccol, body * fade);
	}
	COLOR = col;
}
