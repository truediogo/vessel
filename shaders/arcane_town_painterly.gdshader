shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// Point 2 & Point 4 of the League of Legends Godot Pipeline:
// - Hand-painted diffuse texture + Blender-baked vertex edge highlights & crevice AO (COLOR.rgb)
//   do 82% of the work!
// - Completely matte (specular_disabled, ROUGHNESS = 1.0) with ultra-soft lighting (82% unshaded
//   base + 18% soft sun/shadow modulation) so Godot's real-time lighting NEVER fights the painting.
// - Region color identity: gameplay areas stay warm, saturated, and ~20% brighter than outer borders.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.76, 0.74, 0.84, 1.0);
uniform vec4 sun_warmth_color : source_color = vec4(1.04, 1.01, 0.96, 1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 4.0) = 0.0;

varying vec3 world_pos;
varying vec3 v_baked_paint;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// COLOR.rgb carries the Blender-baked top-edge bevel highlights (>1.0) and dark crevice AO (<1.0)
	v_baked_paint = COLOR.rgb;
}

void fragment() {
	vec3 col = albedo_color.rgb;
	if (use_texture) {
		col *= texture(albedo_texture, UV).rgb;
	}
	// Apply Blender-baked top-edge highlights and dark crevice tones straight into the diffuse color
	col *= v_baked_paint;

	// Point 4: Gameplay areas (near the plaza & northern lane center) are slightly brighter than outer surroundings
	float dist_from_lane = min(
		length(world_pos.xz - vec2(0.0, 11.5)) / 30.0,
		abs(world_pos.x) / 22.0
	);
	float region_focus = mix(1.06, 0.82, smoothstep(0.55, 1.25, dist_from_lane));
	col *= region_focus;

	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	// 78% self-lit painted diffuse base so engine lighting never washes out or fights the hand-painted texture!
	EMISSION = col * 0.72 + emission_color.rgb * emission_strength;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		// Ultra-soft 28% directional light contribution so cast shadows are gentle and painterly
		float ndotl = max(0.0, dot(NORMAL, LIGHT)) * ATTENUATION;
		float soft_lit = smoothstep(0.05, 0.45, ndotl);
		vec3 ramp = mix(shadow_color.rgb, sun_warmth_color.rgb, soft_lit);
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * ramp * 0.34;
	} else {
		float nl = max(0.0, dot(NORMAL, LIGHT));
		float local_glow = smoothstep(0.0, 0.5, nl) * ATTENUATION;
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * local_glow * 0.24;
	}
}
