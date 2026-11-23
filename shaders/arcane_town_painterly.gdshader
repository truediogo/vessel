shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// Point 2 & Point 4 of the League of Legends Godot Pipeline:
// - Hand-painted diffuse texture + Blender-baked vertex edge highlights & crevice AO (COLOR.rgb)
//   do the primary lighting work.
// - Completely matte (specular_disabled, ROUGHNESS = 0.92, SPECULAR = 0.0) with soft directional
//   lighting and zero fake self-emission washout so cast shadows and SSAO remain crisp.
// - Region color identity: gameplay areas stay warm, saturated, and slightly brighter than outer borders.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.54, 0.50, 0.62, 1.0);
uniform vec4 sun_warmth_color : source_color = vec4(1.02, 0.97, 0.88, 1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 4.0) = 0.0;

varying vec3 world_pos;
varying vec3 v_baked_paint;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_baked_paint = COLOR.rgb;
}

void fragment() {
	vec3 col = albedo_color.rgb;
	if (use_texture) {
		col *= texture(albedo_texture, UV).rgb;
	}
	// Apply Blender-baked top-edge highlights and dark crevice AO without blowing out the texture
	col *= mix(vec3(1.0), v_baked_paint, 0.65);

	// Point 4: Gameplay areas (plaza & northern lane center) stay slightly brighter than outer borders
	float dist_from_lane = min(
		length(world_pos.xz - vec2(0.0, 11.5)) / 30.0,
		abs(world_pos.x) / 22.0
	);
	float region_focus = mix(1.06, 0.82, smoothstep(0.55, 1.25, dist_from_lane));
	col *= region_focus;

	ALBEDO = col;
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = emission_color.rgb * emission_strength;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float ndotl = max(0.0, dot(NORMAL, LIGHT)) * ATTENUATION;
		float lit_band = smoothstep(0.08, 0.32, ndotl);
		vec3 ramp = mix(shadow_color.rgb, sun_warmth_color.rgb, lit_band);
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * ramp * 0.95;
	} else {
		float nl = max(0.0, dot(NORMAL, LIGHT));
		float local_glow = smoothstep(0.0, 0.45, nl) * ATTENUATION;
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * local_glow * 0.45;
	}
}
