shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
// Sunset backdrop for the 3D menu previews: palette gradient, a half sun with slow rays, soft halftone dots.

uniform vec3 c_top : source_color = vec3(0.17, 0.18, 0.42);
uniform vec3 c_mid : source_color = vec3(0.72, 0.27, 0.44);
uniform vec3 c_low : source_color = vec3(1.0, 0.45, 0.36);
uniform vec3 c_hor : source_color = vec3(1.0, 0.72, 0.35);
uniform vec3 c_sun : source_color = vec3(1.0, 0.85, 0.3);

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	float t = uv.y;
	vec3 col = mix(c_top, c_mid, smoothstep(0.0, 0.4, t));
	col = mix(col, c_low, smoothstep(0.3, 0.7, t));
	col = mix(col, c_hor, smoothstep(0.62, 1.0, t));
	vec2 sc = vec2(0.5, 0.64);
	vec2 d = (uv - sc) * vec2(aspect, 1.0);
	float ang = atan(d.y, d.x);
	float rays = smoothstep(0.35, 0.65, 0.5 + 0.5 * sin(ang * 12.0 + TIME * 0.15));
	float fall = smoothstep(1.1, 0.1, length(d));
	col += vec3(1.0, 0.8, 0.5) * rays * fall * 0.12;
	float r = length(d);
	col = mix(col, c_sun, smoothstep(0.2, 0.19, r) * 0.85);
	col += c_sun * smoothstep(0.5, 0.2, r) * 0.1;
	vec2 g = uv * vec2(aspect, 1.0) * 26.0;
	vec2 cell = fract(g) - 0.5;
	float dots = smoothstep(0.34, 0.26, length(cell) * (1.0 + (1.0 - uv.x) * 0.0)) ;
	float zone = smoothstep(0.55, 1.0, uv.y) * smoothstep(0.7, 0.0, uv.x) + smoothstep(0.45, 0.0, uv.y) * smoothstep(0.6, 1.0, uv.x) * 0.6;
	col = mix(col, col * 0.78 + vec3(0.12, 0.05, 0.1), dots * zone * 0.55);
	ALBEDO = col;
}
