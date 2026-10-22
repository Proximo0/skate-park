shader_type spatial;
render_mode specular_disabled, cull_disabled;

// Trees and plants that sway in the wind (SwayTrees, game/world/sway_trees.gd), drawn as MultiMeshes. Vertex colour is
// the albedo; UV.x is the sway weight (0 at the root, 1 at the top: the bend grows with its square) and UV.y the flutter
// weight (fronds and leaf clumps shiver faster on top of the sway). Each instance gets its own phase from its position.

uniform float sway_amount = 0.35;  // metres at the top of a unit-weight vertex
uniform float sway_speed = 0.9;
uniform float flutter_amount = 0.06;
uniform vec2 wind_dir = vec2(0.8, 0.3);

#include "res://game/world/toon_light.gdshaderinc"

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float ph = dot(origin.xz, vec2(0.11, 0.17));
	float w = UV.x * UV.x;
	float gust = 0.6 + 0.4 * sin(TIME * 0.23 + ph * 0.3);
	float s = sin(TIME * sway_speed + ph) * 0.7 + sin(TIME * sway_speed * 2.3 + ph * 1.7) * 0.3;
	vec2 wd = normalize(wind_dir);
	// wind is in world space; take it into the instance's local space (rotation only)
	vec3 local_w = normalize((inverse(MODEL_MATRIX) * vec4(wd.x, 0.0, wd.y, 0.0)).xyz);
	VERTEX += local_w * (s * sway_amount * gust * w);
	float f = sin(TIME * 5.3 + ph * 3.0 + VERTEX.x * 2.0 + VERTEX.z * 1.7);
	VERTEX.y += f * flutter_amount * UV.y;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
