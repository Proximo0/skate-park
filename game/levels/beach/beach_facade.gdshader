shader_type spatial;
render_mode specular_disabled;

// Beach-town buildings for the Beachfront backdrop (BeachTown), drawn as one MultiMesh of unit boxes (centre origin).
// The instance colour (MultiMesh colours) is the wall paint; INSTANCE_CUSTOM.r picks the window style, .g the trim hue
// shift and .b the awning flag. Windows, floor bands, a shop-front band with an awning stripe and a parapet line are
// worked out from the box's own metres (scale from the model matrix), so no UVs or textures are needed. Toon lit.

uniform vec3 glass_top : source_color = vec3(0.55, 0.78, 0.92);
uniform vec3 glass_bottom : source_color = vec3(0.16, 0.3, 0.42);
uniform vec3 frame_color : source_color = vec3(0.97, 0.95, 0.9);
uniform vec3 roof_color : source_color = vec3(0.62, 0.58, 0.55);
uniform float floor_h = 3.2;
uniform float bay_w = 2.8;

varying vec3 m_pos;  // position in metres from the box centre
varying vec3 m_size;
varying vec3 m_nrm;
varying vec4 paint;
varying vec4 style;

#include "res://game/world/toon_light.gdshaderinc"

void vertex() {
	m_size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	m_pos = VERTEX * m_size;
	m_nrm = NORMAL;
	paint = COLOR;
	style = INSTANCE_CUSTOM;
}

float box_mask(vec2 p, vec2 half_size, float soft) {
	vec2 d = abs(p) - half_size;
	return 1.0 - smoothstep(-soft, soft, max(d.x, d.y));
}

void fragment() {
	vec3 col = paint.rgb;
	if (abs(m_nrm.y) > 0.5) {
		col = m_nrm.y > 0.0 ? roof_color * mix(0.9, 1.05, paint.r) : col * 0.6;
	} else {
		float u = abs(m_nrm.x) > 0.5 ? m_pos.z : m_pos.x;
		float w = abs(m_nrm.x) > 0.5 ? m_size.z : m_size.x;
		float h = m_pos.y + m_size.y * 0.5;  // height above the base
		float top = m_size.y;
		// parapet band and a darker plinth
		col = mix(col, col * 1.12 + vec3(0.04), smoothstep(top - 0.55, top - 0.5, h));
		col = mix(col * 0.78, col, smoothstep(0.3, 0.34, h));
		float bays = max(floor(w / bay_w), 1.0);
		float bw = w / bays;
		float cu = mod(u + w * 0.5, bw) - bw * 0.5;
		float fl = floor(h / floor_h);
		float fy = mod(h, floor_h) - floor_h * 0.55;
		float style_k = style.r;
		if (h < floor_h && style.b > 0.5) {
			// shop front: tall glass with a stripe awning over it
			float glass = box_mask(vec2(cu, h - 1.35), vec2(bw * 0.44, 1.05), 0.03);
			vec3 g = mix(glass_bottom, glass_top, clamp((h - 0.3) / 2.2, 0.0, 1.0)) * 0.85;
			col = mix(col, frame_color * 0.92, box_mask(vec2(cu, h - 1.35), vec2(bw * 0.47, 1.12), 0.02));
			col = mix(col, g, glass);
			float aw = smoothstep(2.55, 2.6, h) * (1.0 - smoothstep(3.0, 3.05, h));
			float stripe = step(0.5, fract((u + w * 0.5) / 0.7));
			vec3 awning = mix(vec3(0.97, 0.95, 0.9), mix(vec3(0.95, 0.35, 0.3), vec3(0.1, 0.62, 0.72), style.g), stripe);
			col = mix(col, awning, aw);
		} else if (h > 0.9 && h < top - 0.7) {
			vec2 half_w = style_k < 0.33 ? vec2(bw * 0.28, 0.7) : (style_k < 0.66 ? vec2(bw * 0.38, 0.55) : vec2(bw * 0.2, 0.85));
			float frame = box_mask(vec2(cu, fy), half_w + vec2(0.09), 0.02);
			float glass = box_mask(vec2(cu, fy), half_w, 0.02);
			// a few lit or curtained panes so rows don't repeat
			float r = fract(sin(dot(vec2(floor((u + w * 0.5) / bw), fl), vec2(12.9898, 78.233))) * 43758.5453);
			vec3 g = mix(glass_bottom, glass_top, clamp(fy / (half_w.y * 2.0) + 0.5, 0.0, 1.0));
			g = mix(g, vec3(0.95, 0.88, 0.72), step(0.86, r) * 0.6);
			col = mix(col, frame_color, frame);
			col = mix(col, g, glass);
			// balcony rail under every other window on the "resort" style
			if (style_k > 0.66) {
				float rail = box_mask(vec2(cu, fy + half_w.y + 0.35), vec2(bw * 0.36, 0.05), 0.01);
				col = mix(col, frame_color, rail);
			}
		}
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
