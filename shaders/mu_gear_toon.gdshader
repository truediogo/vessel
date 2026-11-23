shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Textured MU Online-inspired metallic color & sheen shader applied over real sculpted 3D gear!
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = false;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 tier_color : source_color = vec4(0.32, 0.34, 0.37, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.28, 0.30, 0.42, 1.0);
uniform vec4 specular_color : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.85, 0.90, 1.0, 1.0);

uniform float tier_blend : hint_range(0.0, 1.0) = 0.0;
uniform float sheen_strength : hint_range(0.0, 3.0) = 0.25;
uniform float sheen_sharpness : hint_range(4.0, 96.0) = 24.0;
uniform float rim_strength : hint_range(0.0, 3.0) = 0.25;
uniform float pulse_speed : hint_range(0.0, 6.0) = 0.0;
uniform float pulse_strength : hint_range(0.0, 1.5) = 0.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 tex_col = base_color.rgb;
	if (use_texture) {
		vec4 tex = texture(albedo_texture, UV);
		if (tex.a < 0.5) {
			discard;
		}
		tex_col *= tex.rgb;
	}
	// Preserve texture value/contrast while richly tinting into the MU upgrade metal color
	float luma = dot(tex_col, vec3(0.299, 0.587, 0.114));
	vec3 tinted_metal = tier_color.rgb * (0.48 + luma * 0.92);
	vec3 col = mix(tex_col, tinted_metal, tier_blend * 0.85);

	float wave = sin((local_pos.y * 6.5 + local_pos.x * 4.5) - TIME * pulse_speed);
	float glint_band = smoothstep(0.74, 0.92, wave) * pulse_strength;

	ALBEDO = mix(col, vec3(1.0, 0.98, 0.92), hit_flash);
	ROUGHNESS = 0.42;
	METALLIC = 0.18;
	EMISSION = (specular_color.rgb * glint_band * 0.42)
		+ (tier_color.rgb * pulse_strength * 0.15)
		+ (vec3(1.0, 0.94, 0.85) * hit_flash * 0.72);
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float main_band = smoothstep(-0.02, 0.07, ndotl * ATTENUATION);
	float mid_band = smoothstep(0.45, 0.58, ndotl * ATTENUATION);

	vec3 shaded = mix(shadow_color.rgb, vec3(1.0), main_band);
	shaded = mix(shaded, vec3(1.16), mid_band * 0.35);
	DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * shaded * 0.96;

	vec3 half_vec = normalize(LIGHT + VIEW);
	float ndoth = max(dot(NORMAL, half_vec), 0.0);
	float spec = pow(ndoth, sheen_sharpness);
	float spec_band = smoothstep(0.26, 0.38, spec) * main_band;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float rim_band = smoothstep(0.32, 0.52, fresnel);

	SPECULAR_LIGHT += (specular_color.rgb * spec_band * sheen_strength * 0.75
		+ rim_color.rgb * rim_band * rim_strength * 0.58 * (0.45 + 0.55 * main_band)) * (LIGHT_COLOR / PI);
}
