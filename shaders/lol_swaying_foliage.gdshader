shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;

// League of Legends / Summoner's Rift Hand-Painted Foliage & Grass Shader:
// - Upward-biased normal smoothing so tiered pine skirts, umbrella leaf clusters, and 3D grass tufts
//   grade smoothly from warm sunlit crown tips to cool viridian-teal shadow undersides without harsh facet seams.
// - Hue-shifted vertex-color paint (`COLOR.rgb`) + soft wrap-around matte directional lighting (no self-emission washout).

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = true;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float sway_speed : hint_range(0.2, 4.0) = 1.45;
uniform float sway_strength : hint_range(0.0, 0.4) = 0.09;

varying vec3 v_baked_paint;

void vertex() {
	vec3 world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height_mask = clamp((world_p.y - 0.15) / 4.2, 0.0, 1.0);
	float wave_x = sin(TIME * sway_speed + world_p.x * 0.65 + world_p.z * 0.55);
	float wave_z = cos(TIME * (sway_speed * 0.85) + world_p.z * 0.65 - world_p.x * 0.45);
	VERTEX.x += wave_x * sway_strength * height_mask;
	VERTEX.z += wave_z * (sway_strength * 0.75) * height_mask;
	// Riot / League of Legends foliage normal trick: bias normals slightly toward sky up so layered leaf skirts shade as cohesive hand-painted volumes
	NORMAL = normalize(NORMAL + vec3(0.0, 0.38, 0.0));
	v_baked_paint = COLOR.rgb;
}

void fragment() {
	vec3 col = albedo_color.rgb;
	if (use_texture) {
		col *= texture(albedo_texture, UV).rgb;
	}
	col *= mix(vec3(1.0), v_baked_paint, 0.78);
	ALBEDO = col;
	ROUGHNESS = 0.94;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = vec3(0.0);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float ndotl = dot(NORMAL, LIGHT) * ATTENUATION;
		float soft_lit = smoothstep(-0.18, 0.42, ndotl);
		// Cool viridian-teal shadow underside -> warm sunlit golden-chartreuse crown highlight
		vec3 ramp = mix(vec3(0.46, 0.58, 0.62), vec3(1.05, 1.03, 0.90), soft_lit);
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * ramp * 0.96;
	} else {
		float nl = max(0.0, dot(NORMAL, LIGHT));
		float local_glow = smoothstep(0.0, 0.45, nl) * ATTENUATION;
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * local_glow * 0.35;
	}
}
