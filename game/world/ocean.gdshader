shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, specular_disabled;

// Stylised ocean for the levels (Ocean node, game/world/ocean.gd). Works in the Compatibility renderer: no depth or screen
// texture, the water depth comes from the known beach profile instead.
//
// Space: the Ocean node's local space. The still-water line is local z = 0, the sea lies toward +Z, y = 0 is sea level.
// The sea floor is the beach profile sand_y(z) = min(berm, -slope * z) (Ocean.beach_mesh builds the matching sand).
//
// Waves: six Gerstner waves. The swell rolls toward the shore (-Z), steepens and grows as the water shoals, and runs up
// the sand as swash; small chop from other directions breaks it up. Per-pixel normals are evaluated analytically (plus two
// scrolling noise octaves), so the far, coarse part of the mesh still glints.
// Look: depth tint (turquoise shallows over the sand, deep blue further out), crest translucency toward the sun, sky
// reflection with Fresnel, cel-banded sun glints, foam on breaking crests and a lacy swash line on the sand, and the far
// water fading into the sky's horizon colour so the sea meets the sky without a seam.

uniform float t = 0.0;  // seconds, fed by Ocean so the CPU height_at() matches
uniform float slope = 0.08;
uniform float berm = 1.2;
uniform float wave_scale = 1.0;
// waves: (dir.x, dir.y, wavelength m, amplitude m); steep: Gerstner steepness 0..1 per wave
uniform vec4 w0 = vec4(0.06, -1.0, 21.0, 0.36);
uniform vec4 w1 = vec4(-0.22, -0.97, 13.0, 0.2);
uniform vec4 w2 = vec4(0.3, -0.95, 8.5, 0.12);
uniform vec4 w3 = vec4(-0.6, -0.8, 5.2, 0.06);
uniform vec4 w4 = vec4(0.8, -0.6, 3.3, 0.035);
uniform vec4 w5 = vec4(-0.9, 0.4, 2.3, 0.022);
uniform vec3 steep_a = vec3(0.55, 0.5, 0.45);
uniform vec3 steep_b = vec3(0.4, 0.35, 0.3);

uniform vec3 deep_color : source_color = vec3(0.04, 0.36, 0.56);
uniform vec3 shallow_color : source_color = vec3(0.18, 0.8, 0.77);
uniform vec3 crest_color : source_color = vec3(0.45, 0.95, 0.88);
uniform vec3 foam_color : source_color = vec3(0.97, 0.99, 1.0);
uniform vec3 sky_color : source_color = vec3(0.3, 0.62, 0.98);
uniform vec3 horizon_color : source_color = vec3(0.86, 0.93, 0.95);
uniform vec3 sun_dir = vec3(0.3, 0.7, 0.6);  // world space, toward the sun
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.88);
uniform float light_level = 1.0;  // overall brightness (night moods dim it)
uniform float far_start = 220.0;
uniform float far_end = 1900.0;

varying vec3 lpos;  // local, undisplaced (x, z) + displaced y
varying vec3 wpos;
varying float v_crest;

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

float sand_y(float z) {
	return min(berm, -slope * z);
}

// How much of each wave survives at still-water depth d: the swell shoals up and then dies on the sand; chop fades sooner.
float shoal(float d, float is_swell) {
	float up = 1.0 + 0.3 * (1.0 - smoothstep(0.8, 5.0, d)) * is_swell;
	float die = smoothstep(-0.6 * is_swell, 1.4 - 0.6 * is_swell, d);
	return up * mix(die, max(die, 0.55), is_swell);
}

// One Gerstner wave at p: adds displacement to disp, and the d(height)/dx, d(height)/dz partials to grad.
void gerstner(vec4 w, float q, vec2 p, float k_amp, inout vec3 disp, inout vec2 grad) {
	vec2 d = normalize(w.xy);
	float k = 6.2831853 / w.z;
	float c = sqrt(9.8 / k);
	float a = w.w * wave_scale * k_amp;
	float ph = k * (dot(d, p) - c * t);
	float cs = cos(ph);
	float sn = sin(ph);
	disp.x += q * a * d.x * cs;
	disp.z += q * a * d.y * cs;
	disp.y += a * sn;
	grad += d * (a * k * cs);
}

// Sum of the waves at local p (x, z). Returns displacement; grad gets the height gradient; crest gets the swell's
// normalised height (1 at a crest).
vec3 waves(vec2 p, out vec2 grad, out float crest, float far_fade) {
	vec3 disp = vec3(0.0);
	grad = vec2(0.0);
	float d = -sand_y(p.y);
	float s = shoal(d, 1.0) * far_fade;
	float c = shoal(d, 0.0) * mix(0.6, 1.0, far_fade);
	float near = 1.0 - smoothstep(0.5, 4.5, d);
	gerstner(w0, min(steep_a.x + 0.3 * near, 0.95), p, s, disp, grad);
	crest = disp.y / max(w0.w * wave_scale * s, 0.001);
	gerstner(w1, steep_a.y, p, s, disp, grad);
	gerstner(w2, steep_a.z, p, s * 0.9 + 0.1, disp, grad);
	gerstner(w3, steep_b.x, p, c, disp, grad);
	gerstner(w4, steep_b.y, p, c, disp, grad);
	gerstner(w5, steep_b.z, p, c, disp, grad);
	return disp;
}

void vertex() {
	vec2 p = VERTEX.xz;
	float far_fade = 1.0 - 0.6 * smoothstep(250.0, 900.0, p.y);
	vec2 g;
	float crest;
	vec3 disp = waves(p, g, crest, far_fade);
	// troughs keep a thin film over the sand except at the shoreline (Ocean.trough_floor)
	float d0 = -sand_y(p.y);
	disp.y = max(disp.y, -d0 + 0.16 * smoothstep(0.2, 0.9, d0) - 100.0 * (1.0 - smoothstep(0.0, 0.2, d0)));
	VERTEX += disp;
	lpos = vec3(p.x, VERTEX.y, p.y);
	v_crest = crest;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = lpos.xz;
	float cam_d = length(VERTEX);
	float far_fade = 1.0 - 0.6 * smoothstep(250.0, 900.0, p.y);
	vec2 g;
	float crest;
	vec3 disp = waves(p, g, crest, far_fade);
	float h = lpos.y;
	// detail normals: two scrolling noise octaves, faded with distance so the far sea does not shimmer
	float detail = 1.0 - smoothstep(40.0, 260.0, cam_d);
	vec2 q = p + vec2(0.0, t * 0.9);
	float e = 0.35;
	float n0 = vnoise(q * 0.9);
	float nx = vnoise((q + vec2(e, 0.0)) * 0.9);
	float nz = vnoise((q + vec2(0.0, e)) * 0.9);
	vec2 q2 = p * 2.3 + vec2(t * 0.7, -t * 1.1);
	float m0 = vnoise(q2);
	float mx = vnoise(q2 + vec2(e * 2.3, 0.0));
	float mz = vnoise(q2 + vec2(0.0, e * 2.3));
	g += (vec2(nx - n0, nz - n0) * 0.35 + vec2(mx - m0, mz - m0) * 0.22) * detail;
	vec3 n_local = normalize(vec3(-g.x, 1.0, -g.y));
	vec3 n = normalize((MODEL_MATRIX * vec4(n_local, 0.0)).xyz);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 l = normalize(sun_dir);

	// depth of water over the sand here, and how far out we are
	float depth = h - sand_y(p.y + disp.z);
	float still_depth = -sand_y(p.y);
	float shallow_k = 1.0 - smoothstep(0.0, 7.0, max(depth, 0.0));
	vec3 water = mix(deep_color, shallow_color, shallow_k * shallow_k);
	// crests light up toward the sun (light through the thin top of the wave)
	float back = clamp(dot(-v, l) * 0.5 + 0.5, 0.0, 1.0);
	float thin = smoothstep(0.2, 1.0, v_crest) * (0.4 + 0.6 * back);
	water = mix(water, crest_color, thin * 0.45 * (1.0 - smoothstep(10.0, 60.0, still_depth)) + thin * 0.15);
	// simple toon diffuse so wave backs read
	float ndl = clamp(dot(n, l), 0.0, 1.0);
	water *= mix(0.78, 1.0, smoothstep(0.25, 0.45, ndl));

	// sky reflection with Fresnel
	vec3 r = reflect(-v, n);
	float fres = 0.02 + 0.98 * pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 5.0);
	vec3 refl = mix(horizon_color, sky_color, smoothstep(0.0, 0.5, max(r.y, 0.0)));
	vec3 col = mix(water, refl, clamp(fres * 0.85, 0.0, 0.85));

	// sun: a soft sheen down the sun path and cel-banded glints
	float rl = max(dot(r, l), 0.0);
	float sheen = pow(rl, 70.0) * 0.35;
	float glint = smoothstep(0.9965, 0.998, rl) * (0.6 + 0.4 * detail);
	float spark = step(0.86, vnoise(p * 6.0 + t * 2.0)) * smoothstep(0.985, 0.995, rl) * detail;
	col += sun_color * (sheen + glint * 1.4 + spark * 1.2);

	// foam: breaking crests near the shore, and the swash line on the sand
	float surf_zone = 1.0 - smoothstep(1.0, 4.0, still_depth);
	float lace = vnoise(p * vec2(1.3, 2.4) + vec2(0.0, t * 0.4)) * 0.6 + vnoise(p * 4.1 - t * 0.3) * 0.4;
	// breaking crest: a lacy band riding the top of the swell (not the whole wave), broken up by the lace noise
	float c_hi = v_crest + (lace - 0.5) * 0.5;
	float crest_band = smoothstep(0.62, 0.74, c_hi) * (1.0 - smoothstep(1.05, 1.25, c_hi));
	float crest_foam = crest_band * smoothstep(0.35, 0.55, lace) * surf_zone;
	// a trail of thinning foam behind the break
	crest_foam = max(crest_foam, smoothstep(0.62, 0.8, lace) * smoothstep(0.2, 0.6, v_crest) * surf_zone * 0.6);
	crest_foam += smoothstep(0.86, 0.94, v_crest + lace * 0.2) * 0.25 * (1.0 - surf_zone) * (1.0 - smoothstep(30.0, 140.0, still_depth));
	// the swash edge: a thin bright line where the water meets the sand, with lace patches just behind it
	float shore_only = 1.0 - smoothstep(0.25, 0.7, still_depth);  // no foam rings round the film over the troughs
	float edge = (1.0 - smoothstep(0.02, 0.07 + lace * 0.06, depth)) * shore_only;
	float wash = (1.0 - smoothstep(0.05, 0.22, depth)) * smoothstep(0.55, 0.68, lace) * shore_only;
	float foam = clamp(max(max(crest_foam, edge), wash * 0.85), 0.0, 1.0);
	// cel: hard-edged foam, two tones (thin foam lets the water show through)
	float foam_cel = smoothstep(0.42, 0.5, foam);
	float foam_thick = smoothstep(0.72, 0.8, foam);
	col = mix(col, foam_color, foam_cel * mix(0.6, 0.95, foam_thick));

	// light level (night moods) and the far fade into the horizon
	col *= light_level;
	float far = smoothstep(far_start, far_end, cam_d);
	col = mix(col, horizon_color * mix(1.0, light_level, 0.6), far);

	ALBEDO = col;
	// see-through over the sand in the shallows, solid foam
	float a = mix(0.4, 0.97, smoothstep(0.0, 1.6, depth)) + 0.25 * smoothstep(0.3, 1.0, still_depth) * (1.0 - smoothstep(0.0, 1.6, depth));
	ALPHA = clamp(max(a, foam_cel * mix(0.7, 1.0, foam_thick)), 0.0, 1.0) * (1.0 - smoothstep(-0.02, 0.0, -depth));
}
