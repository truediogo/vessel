shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// Point 5 of the League of Legends Godot Pipeline:
// Animated hand-painted water shader with scrolling caustic bands and soft shore highlights.

uniform vec4 deep_color : source_color = vec4(0.14, 0.54, 0.68, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.28, 0.78, 0.86, 1.0);
uniform vec4 foam_color : source_color = vec4(0.78, 0.96, 0.98, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 2.1 + world_pos.x * 1.4 + world_pos.z * 1.2) * 0.018;
}

void fragment() {
	vec2 uv = world_pos.xz * 0.55;
	float r1 = sin(uv.x * 2.4 + TIME * 1.3 + cos(uv.y * 2.1 - TIME * 0.9));
	float r2 = cos(uv.y * 2.8 - TIME * 1.1 + sin(uv.x * 2.2 + TIME * 0.8));
	float wave = (r1 + r2) * 0.25 + 0.5;

	vec3 col = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.25, 0.75, wave));
	float highlight_rib = smoothstep(0.78, 0.86, wave);
	col = mix(col, foam_color.rgb, highlight_rib * 0.45);

	ALBEDO = col;
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = col * 0.78;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * 0.25;
	}
}
