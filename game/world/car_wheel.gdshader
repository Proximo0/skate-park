shader_type spatial;
render_mode specular_disabled;

// The four wheels of a traffic car merged into one mesh (CarModel): albedo from the vertex colour, spun in the vertex
// shader about each axle (front axle for z < 0, rear for z > 0; the car's nose faces -Z) by `spin` radians.

uniform float spin = 0.0;
uniform float axle_y = 0.33;
uniform float axle_front_z = -1.3;
uniform float axle_back_z = 1.3;

#include "res://game/world/toon_light.gdshaderinc"

void vertex() {
	float cz = VERTEX.z < 0.0 ? axle_front_z : axle_back_z;
	vec2 q = vec2(VERTEX.y - axle_y, VERTEX.z - cz);
	float c = cos(spin);
	float s = sin(spin);
	q = vec2(c * q.x - s * q.y, s * q.x + c * q.y);
	VERTEX.y = q.x + axle_y;
	VERTEX.z = q.y + cz;
	NORMAL = vec3(NORMAL.x, c * NORMAL.y - s * NORMAL.z, s * NORMAL.y + c * NORMAL.z);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
