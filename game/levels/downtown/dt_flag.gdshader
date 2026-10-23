shader_type spatial;
render_mode specular_disabled, cull_disabled;

// Flags and banners that move in the wind (DtLife), drawn as one MultiMesh each. The mesh is a unit cloth in local XY
// (x 0..1 out from the pole, y 0..-1 down from the top), UV = (x, -y). A flag (hang = 0) ripples along its length,
// more toward the fly end; a banner (hang = 1) hangs from its top bar and swings, more toward its foot. Colour per
// instance: INSTANCE_CUSTOM.rgb (linear) is the field; INSTANCE_CUSTOM.a picks the pattern (0 plain stripe,
// 0.5 emblem disc, 1 two-band).

uniform float hang = 0.0;
uniform float amount = 0.22;
uniform float speed = 2.4;
uniform vec3 accent : source_color = vec3(0.96, 0.92, 0.8);

#include "res://game/world/toon_light.gdshaderinc"

varying vec4 v_custom;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = dot(o.xz, vec2(0.13, 0.21));
	float gust = 0.65 + 0.35 * sin(TIME * 0.29 + ph * 0.7);
	float along = mix(UV.x, UV.y, hang);
	float w = along * mix(1.0, along, hang);
	float wave = sin(TIME * speed + ph - UV.x * 7.0 * (1.0 - hang) - UV.y * 2.2 * hang);
	wave += 0.35 * sin(TIME * speed * 2.1 + ph * 1.3 - UV.x * 13.0 * (1.0 - hang));
	VERTEX.z += wave * amount * w * gust;
	VERTEX.y -= (1.0 - hang) * UV.x * UV.x * 0.06 * (1.2 - gust);
	VERTEX.x -= hang * abs(wave) * 0.03 * w;
	v_custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec3 field = v_custom.rgb;
	vec3 acc = accent;
	float p = v_custom.a;
	float m = 0.0;
	if (p < 0.25) {
		// a band across the middle
		m = step(abs(UV.y - 0.5), 0.12);
	} else if (p < 0.75) {
		// an emblem disc (banners are about 2.4 times taller than wide)
		vec2 d = (UV - vec2(0.5, 0.42)) * vec2(1.0, 2.4);
		m = 1.0 - smoothstep(0.3, 0.33, length(d));
		m = max(m, step(0.86, UV.y) * step(UV.y, 0.92));
	} else {
		m = step(0.5, UV.y);
	}
	ALBEDO = mix(field, acc, m);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
