shader_type spatial;
// Graffiti for the Creepy Warehouse (WhGeo.tag): the shared GraffitiArt textures, alpha-scissored so they go through the
// opaque pass and take light like the walls they are sprayed on (the park's decal shader blends, and in a dark hall that
// reads as neon). Paint is a little faded; lamps light it with smooth falloff, the moon with toon bands.
render_mode specular_disabled, cull_back;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float fade : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * fade;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
}

void light() {
	float n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = n_dot_l * smoothstep(0.3, 0.7, ATTENUATION);
		vec3 col = mix(ALBEDO * vec3(0.42, 0.4, 0.62), ALBEDO * 0.8, smoothstep(0.08, 0.16, lit));
		col = mix(col, ALBEDO, smoothstep(0.45, 0.55, lit));
		DIFFUSE_LIGHT += col * LIGHT_COLOR * 0.5;
	} else {
		DIFFUSE_LIGHT += ALBEDO * mix(0.3, 1.0, smoothstep(0.08, 0.3, n_dot_l)) * ATTENUATION * LIGHT_COLOR * 0.5;
	}
}
