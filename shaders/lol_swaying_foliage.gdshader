shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;

// League of Legends / Summoner's Rift Hand-Painted Alpha-Cutout Foliage & Grass Shader:
// - Uses `ALPHA` + `ALPHA_SCISSOR_THRESHOLD = 0.42` so real chroma-keyed Devoted Studios
//   sakura & emerald leaf-cluster cards and CC0 grass-tuft cards render with crisp,
//   authentic hand-painted jagged leaf silhouettes!
// - Respects Spherical Normal Transfer + upward normal bias so layered alpha leaf cards
//   shade as one plush, volumetric hand-painted canopy cloud without flat card seams.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = true;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float sway_speed : hint_range(0.2, 4.0) = 1.45;
uniform float sway_strength : hint_range(0.0, 0.4) = 0.08;

varying vec3 v_baked_paint;

void vertex() {
	vec3 world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height_mask = clamp((VERTEX.y - 0.12) / 3.8, 0.0, 1.0);
	float wave_x = sin(TIME * sway_speed + world_p.x * 0.65 + world_p.z * 0.55);
	float wave_z = cos(TIME * (sway_speed * 0.85) + world_p.z * 0.65 - world_p.x * 0.45);
	VERTEX.x += wave_x * sway_strength * height_mask;
	VERTEX.z += wave_z * (sway_strength * 0.75) * height_mask;
	// Spherical normal transfer from Blender is already in NORMAL; bias slightly upward for soft Riot canopy volume
	NORMAL = normalize(NORMAL + vec3(0.0, 0.48, 0.0));
	v_baked_paint = COLOR.rgb;
}

void fragment() {
	vec3 col = albedo_color.rgb;
	float alpha = 1.0;
	if (use_texture) {
		vec4 tex = texture(albedo_texture, UV);
		col *= tex.rgb;
		alpha = tex.a;
	}
	col *= mix(vec3(1.0), v_baked_paint, 0.72);
	ALBEDO = col;
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.42;
	ROUGHNESS = 0.94;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = vec3(0.0);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float ndotl = dot(NORMAL, LIGHT) * ATTENUATION;
		float soft_lit = smoothstep(-0.25, 0.45, ndotl);
		vec3 ramp = mix(vec3(0.56, 0.62, 0.68), vec3(1.04, 1.02, 0.92), soft_lit);
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * ramp * 0.95;
	} else {
		float nl = max(0.0, dot(NORMAL, LIGHT));
		float local_glow = smoothstep(0.0, 0.45, nl) * ATTENUATION;
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * local_glow * 0.35;
	}
}
