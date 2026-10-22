shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

// A moonlight shaft through a broken skylight (WhLights.moon_shaft): additive, brightest under the roof and fading toward
// the floor, soft at the prism's edges, with slow drifting dust. UV.x runs across a face (0..1), UV.y down the shaft.

uniform vec4 colour : source_color = vec4(0.55, 0.65, 0.95, 1.0);
uniform float strength = 0.16;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float edge = smoothstep(0.0, 0.35, UV.x) * smoothstep(1.0, 0.65, UV.x);
	float along = mix(1.0, 0.25, UV.y) * smoothstep(0.0, 0.05, UV.y) * smoothstep(1.0, 0.85, UV.y);
	float dust = 0.75 + 0.5 * vnoise(vec2(UV.x * 6.0, UV.y * 9.0 - TIME * 0.08));
	// view-angle fade: faces seen edge-on are thin, keep them from flaring
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = edge * along * dust * strength * mix(0.35, 1.0, facing);
	ALBEDO = colour.rgb * a;
}
