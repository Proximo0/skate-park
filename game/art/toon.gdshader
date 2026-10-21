shader_type spatial;
render_mode specular_disabled;

// Cel-shaded surface: flat albedo, three light bands, a soft rim, shadow-receiving.
// Used through Toon.material(); see toon.gd.

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Tint of the shadowed band. Brightness of the shadow band is the tint itself.
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.4, 0.62);
// Brightness of the middle band, as a multiplier on albedo.
uniform float mid_level : hint_range(0.0, 1.0) = 0.8;
// Light amounts (N dot L, shadow-attenuated) where bands switch.
uniform float mid_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float lit_threshold : hint_range(0.0, 1.0) = 0.7;
// Half-width of the soft step between bands.
uniform float band_softness : hint_range(0.0, 0.2) = 0.05;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.22;
// Scale of the toon diffuse light. Godot's LIGHT_COLOR already carries the PI factor, so 1/PI maps a fully lit albedo to about the albedo.
uniform float light_gain : hint_range(0.0, 2.0) = 0.9;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
// 1 multiplies the albedo by the mesh's vertex colour (and a MultiMesh instance colour): weathering, can prints. 0 ignores it.
// Optional albedo texture (default white, so no change without one): multiplied into albedo by the mesh UVs.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float vertex_color_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_tex, UV).rgb * mix(vec3(1.0), COLOR.rgb, vertex_color_amount);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	float n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	// ATTENUATION carries the shadow map result, so cast shadows darken the shadow band.
	// Shadow-map acne (a hatch of speckles) shows on surfaces that face the light only obliquely, so cast shadows count in full
	// only where the surface faces the sun well; elsewhere the plain N.L (already darker) decides the band.
	float shadow = mix(1.0, smoothstep(0.1, 0.9, ATTENUATION), smoothstep(0.55, 0.8, n_dot_l));
	float lit = n_dot_l * shadow;

	float mid_band = smoothstep(mid_threshold - band_softness, mid_threshold + band_softness, lit);
	float top_band = smoothstep(lit_threshold - band_softness, lit_threshold + band_softness, lit);

	// Bands use the linear albedo directly; gamma-encoding it here washed big light surfaces out to white.
	vec3 base = ALBEDO;
	vec3 shadow_col = base * shadow_tint;
	vec3 mid_col = base * mid_level;
	vec3 toon_col = mix(shadow_col, mid_col, mid_band);
	toon_col = mix(toon_col, base, top_band);
	DIFFUSE_LIGHT += toon_col * LIGHT_COLOR * (light_gain / 3.14159265);

	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power) * rim_strength;
	// No rim on surfaces facing the light: the white rim only brightens the shadow side and silhouettes.
	rim *= 1.0 - smoothstep(0.25, 0.6, n_dot_l);
	DIFFUSE_LIGHT += rim_color.rgb * rim * clamp(ATTENUATION, 0.4, 1.0);
}
