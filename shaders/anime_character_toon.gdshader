shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Genshin Impact / Wind Waker stylized cel-shader for VRoid anime characters.
// Supports double-sided cutout meshes (clothes/hair), skin recoloring that
// preserves cool-toned outfits/tights, and luminance-normalized hair recoloring.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = false;
uniform bool use_alpha_scissor = false;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.66, 0.60, 0.68, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.90, 1.0);
uniform float rim_strength : hint_range(0.0, 1.5) = 0.20;
uniform float rim_width : hint_range(1.0, 8.0) = 3.5;
uniform float shadow_threshold : hint_range(-0.5, 0.5) = 0.02;
uniform float shadow_softness : hint_range(0.005, 0.35) = 0.07;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
// Recoloring: >0 normalizes texture brightness around detail_reference so any tint reads true.
uniform float detail_reference : hint_range(0.0, 1.0) = 0.0;
uniform bool skin_mode = false;
uniform bool keep_texture_hue = false;

void fragment() {
	vec3 col = albedo_color.rgb;
	if (use_texture) {
		vec4 tex = texture(albedo_texture, UV);
		if (use_alpha_scissor && tex.a < 0.5) {
			discard;
		}
		if (detail_reference > 0.0) {
			float luma = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
			vec3 tinted = col * clamp(luma / detail_reference, 0.45, 1.25);
			if (skin_mode) {
				// Preserve painted-on cool-toned tights/underwear/eyes while recoloring warm skin
				float warmth = tex.r - tex.b;
				float mask = smoothstep(0.02, 0.09, warmth);
				col = mix(tex.rgb, tinted, mask);
			} else if (keep_texture_hue) {
				col = tex.rgb * col;
			} else {
				col = tinted;
			}
		} else {
			col *= tex.rgb;
		}
	}
	ALBEDO = mix(col, vec3(1.0, 0.98, 0.92), hit_flash);
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
	EMISSION = vec3(1.0, 0.92, 0.85) * hit_flash * 0.7;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float lit_band = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, ndotl * ATTENUATION);
	float sun_lift = smoothstep(0.48, 0.80, ndotl * ATTENUATION) * 0.10;
	vec3 light_tint = mix(shadow_color.rgb, vec3(1.0 + sun_lift), lit_band);
	DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * light_tint * 0.98;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_width);
	float rim_band = smoothstep(0.40, 0.62, fresnel) * lit_band;
	SPECULAR_LIGHT += rim_color.rgb * rim_band * rim_strength * (LIGHT_COLOR / PI);
}
