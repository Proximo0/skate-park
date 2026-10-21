shader_type spatial;
render_mode cull_front, unshaded;

// Inverted-hull ink outline: draws back faces pushed out along their normals.
// Used as the next_pass of the toon material; see toon.gd.

uniform vec4 outline_color : source_color = vec4(0.106, 0.106, 0.184, 1.0);
// Outline thickness as a fraction of view distance, so it stays roughly constant on screen.
uniform float outline_width : hint_range(0.0, 0.1) = 0.012;

void vertex() {
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	VERTEX += NORMAL * outline_width * dist;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
