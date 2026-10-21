shader_type spatial;
render_mode cull_front, unshaded;

// Inverted-hull ink outline: draws back faces pushed out along their normals.
// Used as the next_pass of the toon material; see toon.gd.

uniform vec4 outline_color : source_color = vec4(0.106, 0.106, 0.184, 1.0);
// Ink width as a fraction of the viewport height. The offset is computed in clip space, so the ink is the
// same number of pixels wide at any distance and never balloons up close.
uniform float outline_width : hint_range(0.0, 0.02) = 0.0045;
// Pushes the shell away from the camera by this fraction of its view distance, so it loses depth ties to
// nearby surfaces (coplanar or just in front) instead of drawing over them. Scales with distance because
// NDC depth precision falls off with distance.
uniform float depth_push : hint_range(0.0, 0.05) = 0.002;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.z -= depth_push * length(view.xyz);
	vec4 clip = PROJECTION_MATRIX * view;
	// Screen-space direction of the normal, measured in pixels so the offset is not stretched by aspect ratio.
	vec2 dir_px = (PROJECTION_MATRIX * vec4(mat3(MODELVIEW_MATRIX) * NORMAL, 0.0)).xy * VIEWPORT_SIZE * 0.5;
	float dir_len = length(dir_px);
	if (dir_len > 1e-5) {
		float width_px = outline_width * VIEWPORT_SIZE.y;
		// Pixels to NDC is 2 / viewport; scaling by w keeps the offset constant after the perspective divide.
		vec2 offset_ndc = (dir_px / dir_len) * (width_px * 2.0 / VIEWPORT_SIZE);
		clip.xy += offset_ndc * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
