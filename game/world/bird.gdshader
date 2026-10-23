shader_type spatial;
render_mode cull_disabled, specular_disabled;

// Birds of a Birds flock (game/world/birds.gd): one MultiMesh, the wings flap in the vertex shader. Vertex colour = the
// plumage; UV.x = how far out along the wing (0 at the body, 1 at the tip), so the tips move most. INSTANCE_CUSTOM.x is
// each bird's flap phase, .y its flap rate (Hz), .z = 1 while it glides (wings held up a little, no flap).

uniform float flap_amount = 0.9;

#include "res://game/world/toon_light.gdshaderinc"

void vertex() {
	float w = UV.x;
	float ph = INSTANCE_CUSTOM.x * 6.2831853 + TIME * INSTANCE_CUSTOM.y * 6.2831853;
	float glide = INSTANCE_CUSTOM.z;
	float flap = mix(sin(ph), 0.18, glide);
	VERTEX.y += flap * flap_amount * w * w * 0.5;
	VERTEX.x *= 1.0 - 0.12 * abs(flap) * w;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
