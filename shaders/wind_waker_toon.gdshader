shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Warm Palia / Wind Waker 3D cel-shader supporting both painted 3D model textures, solid tints, and alpha-cutout foliage leaves
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform bool use_alpha_scissor = false;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.35;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.46, 0.48, 0.64, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.84, 1.0);
uniform float rim_strength : hint_range(0.0, 1.5) = 0.24;
uniform float rim_width : hint_range(1.0, 8.0) = 3.8;
uniform float shadow_threshold : hint_range(-0.5, 0.5) = 0.04;
uniform float shadow_softness : hint_range(0.005, 0.35) = 0.09;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 4.0) = 0.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
// Character recoloring: average texture brightness (0 = off), and underwear-preserving skin mode
uniform float detail_reference : hint_range(0.0, 1.0) = 0.0;
uniform bool skin_mode = false;

// Optional procedural world-space variation for terrain ground planes
uniform float tile_scale : hint_range(0.0, 2.0) = 0.0;
uniform float tile_contrast : hint_range(0.0, 0.4) = 0.08;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = albedo_color.rgb;
	if (use_texture) {
		vec4 tex_rgba = texture(albedo_texture, UV);
		vec3 tex = tex_rgba.rgb;
		if (use_alpha_scissor) {
			ALPHA = tex_rgba.a;
			ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
		}
		if (detail_reference > 0.0) {
			// Recolor: keep only the texture's light/dark detail, so any tint reads true.
			float luma = dot(tex, vec3(0.2126, 0.7152, 0.0722));
			vec3 tinted = col * clamp(luma / detail_reference, 0.55, 1.3);
			// Skin textures have gray underwear baked in; low-warmth pixels stay as painted.
			col = skin_mode ? mix(tex, tinted, smoothstep(0.03, 0.10, tex.r - tex.b)) : tinted;
		} else {
			col *= tex;
		}
	}
	if (tile_scale > 0.01) {
		vec2 uv = world_pos.xz * tile_scale;
		float patch_v = sin(uv.x * 1.3) * cos(uv.y * 1.1) * 0.5 + 0.5;
		col *= mix(1.0 - tile_contrast, 1.0 + tile_contrast, patch_v);
	}
	ALBEDO = mix(col, vec3(1.0, 0.98, 0.92), hit_flash);
	ROUGHNESS = 0.88;
	METALLIC = 0.0;
	EMISSION = emission_color.rgb * emission_strength + vec3(1.0, 0.92, 0.85) * hit_flash * 0.7;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float ndotl = max(0.0, dot(NORMAL, LIGHT)) * ATTENUATION;
		float lit_band = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, ndotl);
		float sun_lift = smoothstep(0.45, 0.78, ndotl) * 0.10;
		vec3 light_tint = mix(shadow_color.rgb, vec3(1.0 + sun_lift), lit_band);
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * light_tint * 0.92;

		float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_width);
		float rim_band = smoothstep(0.42, 0.62, fresnel) * lit_band;
		SPECULAR_LIGHT += rim_color.rgb * rim_band * rim_strength * (LIGHT_COLOR / PI);
	} else {
		float nl = max(0.0, dot(NORMAL, LIGHT));
		float local_lit = smoothstep(0.0, 0.35, nl) * ATTENUATION;
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * local_lit * 0.55;
	}
}
