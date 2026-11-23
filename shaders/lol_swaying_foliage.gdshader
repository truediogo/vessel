shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;

// Point 5 of the League of Legends Godot Pipeline:
// Gently swaying painterly foliage with baked top-crown highlights, dark inner-bough crevices,
// and soft unshaded-dominant matte shading.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = true;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float sway_speed : hint_range(0.2, 4.0) = 1.45;
uniform float sway_strength : hint_range(0.0, 0.4) = 0.11;

varying vec3 v_baked_paint;

void vertex() {
	vec3 world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Gentle organic wind sway on upper foliage boughs
	float height_mask = clamp((world_p.y - 0.6) / 4.5, 0.0, 1.0);
	float wave_x = sin(TIME * sway_speed + world_p.x * 0.55 + world_p.z * 0.45);
	float wave_z = cos(TIME * (sway_speed * 0.85) + world_p.z * 0.60 - world_p.x * 0.35);
	VERTEX.x += wave_x * sway_strength * height_mask;
	VERTEX.z += wave_z * (sway_strength * 0.75) * height_mask;
	v_baked_paint = COLOR.rgb;
}

void fragment() {
	vec3 col = albedo_color.rgb;
	if (use_texture) {
		col *= texture(albedo_texture, UV).rgb;
	}
	col *= v_baked_paint;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = col * 0.74;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float ndotl = max(0.0, dot(NORMAL, LIGHT)) * ATTENUATION;
		float soft_lit = smoothstep(0.05, 0.50, ndotl);
		vec3 ramp = mix(vec3(0.72, 0.76, 0.82), vec3(1.05, 1.02, 0.94), soft_lit);
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * ramp * 0.32;
	}
}
