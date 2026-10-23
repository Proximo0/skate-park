shader_type spatial;
render_mode specular_disabled, cull_disabled;

// Fountain water (and the garage's puddles): a turquoise pool with moving ripple rings round the jets, a sky
// reflection by Fresnel and cel-banded sparkles. Unshaded maths, no screen or depth texture (Compatibility-safe).

uniform vec3 deep : source_color = vec3(0.12, 0.45, 0.6);
uniform vec3 shallow : source_color = vec3(0.35, 0.78, 0.82);
uniform vec3 sky : source_color = vec3(0.78, 0.9, 1.0);
uniform float ripple_scale = 3.2;

varying vec3 wpos;
varying vec3 opos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	opos = VERTEX;
}

void fragment() {
	float r = length(opos.xz);
	float rings = sin(r * ripple_scale * 3.0 - TIME * 3.2) * 0.5 + 0.5;
	float rings2 = sin(length(opos.xz - vec2(1.3, -0.8)) * 9.0 - TIME * 2.4) * 0.5 + 0.5;
	float w = rings * 0.6 + rings2 * 0.4;
	vec3 col = mix(deep, shallow, smoothstep(0.2, 0.9, w) * 0.7 + 0.15);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, sky, fres * 0.7);
	float spark = step(0.93, w) * step(0.6, fract(sin(dot(floor(wpos.xz * 6.0), vec2(12.9898, 78.233))) * 43758.5453));
	col += vec3(0.6) * spark;
	ALBEDO = col * 0.25;
	EMISSION = col * 0.75;
	ROUGHNESS = 1.0;
}
