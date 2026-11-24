shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

// Hand-painted League of Legends / Summoner's Rift multi-biome terrain shader:
// - Manual 4-tap texelFetch bilinear interpolation on chunk control maps (prevents slot-swap seams)
// - Dual-scale rotated world XZ UV sampling on ground/soil layers (prevents tiling stripes)
// - World-space 3-axis triplanar projection for steep cliff slopes & barrier mountains
// - Matte painterly wrap diffuse lighting matching arcane_town_painterly.gdshader

uniform sampler2DArray layer0_array : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray layer1_array : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray layer2_cliff_array : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray layer3_path_array : source_color, filter_linear_mipmap, repeat_enable;

uniform sampler2D ctrl_id_tex : filter_nearest, repeat_disable;
uniform sampler2D ctrl_weight_tex : filter_nearest, repeat_disable;
uniform int ctrl_tex_res = 32;
uniform int biome_count = 6;

uniform float world_uv_scale = 0.085;
uniform float cliff_uv_scale = 0.090;
uniform float path_uv_scale = 0.140;

uniform vec4 biome_primary_tints[8];
uniform vec4 biome_secondary_tints[8];
uniform vec4 biome_cliff_tints[8];
uniform vec4 biome_path_tints[8];
uniform vec2 biome_slope_thresholds[8];
uniform vec2 biome_high_alt_ranges[8];
uniform float biome_water_offsets[8];
uniform float biome_is_volcanic[8];

uniform float sea_level = 0.0;
uniform vec4 shadow_color : source_color = vec4(0.54, 0.50, 0.62, 1.0);
uniform vec4 sun_warmth_color : source_color = vec4(1.02, 0.97, 0.88, 1.0);

uniform bool enable_occlusion_fade = false;
uniform vec3 focus_world_pos = vec3(0.0, 0.0, 0.0);
uniform float occlusion_fade_radius = 11.0;
uniform float occlusion_fade_min_alpha : hint_range(0.0, 1.0) = 0.25;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float bayer4x4(ivec2 px) {
	int idx = (px.y & 3) * 4 + (px.x & 3);
	const float m[16] = float[16](
		0.0625, 0.5625, 0.1875, 0.6875,
		0.8125, 0.3125, 0.9375, 0.4375,
		0.2500, 0.7500, 0.1250, 0.6250,
		1.0000, 0.5000, 0.8750, 0.3750
	);
	return m[idx];
}

void fragment() {
	if (enable_occlusion_fade) {
		vec3 seg = focus_world_pos - CAMERA_POSITION_WORLD;
		float seg_len = length(seg);
		vec3 seg_dir = seg / max(seg_len, 0.001);
		float proj = dot(world_pos - CAMERA_POSITION_WORLD, seg_dir);
		if (proj > 1.0 && proj < seg_len - 1.5) {
			vec3 closest_pt = CAMERA_POSITION_WORLD + seg_dir * proj;
			float radial = length(world_pos - closest_pt);
			float fade = smoothstep(occlusion_fade_radius * 0.35, occlusion_fade_radius, radial);
			float alpha_vis = mix(occlusion_fade_min_alpha, 1.0, fade);
			if (alpha_vis < bayer4x4(ivec2(FRAGCOORD.xy))) {
				discard;
			}
		}
	}

	// 1. Manual 4-tap texelFetch bilinear interpolation accumulating weights per biome ID.
	vec2 f_coord = clamp(UV, vec2(0.0), vec2(1.0)) * float(max(1, ctrl_tex_res - 1));
	ivec2 i0 = clamp(ivec2(floor(f_coord)), ivec2(0), ivec2(ctrl_tex_res - 1));
	ivec2 i1 = min(i0 + ivec2(1), ivec2(ctrl_tex_res - 1));
	vec2 frac_uv = f_coord - vec2(i0);

	float tap_w[4];
	tap_w[0] = (1.0 - frac_uv.x) * (1.0 - frac_uv.y);
	tap_w[1] = frac_uv.x * (1.0 - frac_uv.y);
	tap_w[2] = (1.0 - frac_uv.x) * frac_uv.y;
	tap_w[3] = frac_uv.x * frac_uv.y;

	ivec2 tap_p[4];
	tap_p[0] = i0;
	tap_p[1] = ivec2(i1.x, i0.y);
	tap_p[2] = ivec2(i0.x, i1.y);
	tap_p[3] = i1;

	float bw[8];
	for (int b = 0; b < 8; b++) {
		bw[b] = 0.0;
	}
	float barrier_mask = 0.0;
	float road_mask = 0.0;

	int max_b = max(0, min(7, biome_count - 1));
	for (int t = 0; t < 4; t++) {
		vec4 id_s = texelFetch(ctrl_id_tex, tap_p[t], 0);
		vec4 wt_s = texelFetch(ctrl_weight_tex, tap_p[t], 0);
		float tw = tap_w[t];

		int b0 = clamp(int(round(id_s.r * 255.0)), 0, max_b);
		int b1 = clamp(int(round(id_s.g * 255.0)), 0, max_b);
		int b2 = clamp(int(round(id_s.b * 255.0)), 0, max_b);

		bw[b0] += wt_s.r * tw;
		bw[b1] += wt_s.g * tw;
		bw[b2] += wt_s.b * tw;
		barrier_mask += id_s.a * tw;
		road_mask += wt_s.a * tw;
	}

	// 2. Shared world-space UVs (dual-scale rotated ground + 3-axis triplanar cliff).
	vec2 uv_ground = world_pos.xz * world_uv_scale;
	vec2 uv_macro = vec2(
		uv_ground.x * 0.37 - uv_ground.y * 0.24,
		uv_ground.x * 0.24 + uv_ground.y * 0.37
	) + vec2(0.37, 0.61);

	vec3 n_w = normalize(world_normal);
	float slope = 1.0 - clamp(n_w.y, 0.0, 1.0);
	vec3 tri_w = pow(abs(n_w), vec3(4.0));
	tri_w /= max(tri_w.x + tri_w.y + tri_w.z, 0.0001);
	vec2 uv_tri_x = world_pos.zy * cliff_uv_scale;
	vec2 uv_tri_y = world_pos.xz * cliff_uv_scale;
	vec2 uv_tri_z = world_pos.xy * cliff_uv_scale;
	vec2 uv_path = world_pos.xz * path_uv_scale;

	// Macro soil-variation wave in world space to blend primary <-> secondary layers naturally.
	float sec_wave = 0.5 + 0.5 * sin(world_pos.x * 0.073 + cos(world_pos.z * 0.061) * 1.9);

	// Soften road mask in world space so 1m/2m control texels feather organically at 14-65m zoom.
	float road_edge_wave = 0.5
		+ 0.28 * sin(world_pos.x * 1.45 + cos(world_pos.z * 1.25) * 2.1)
		+ 0.22 * cos(world_pos.z * 2.65 - sin(world_pos.x * 2.15) * 1.7);
	float road_edge_t = clamp(road_mask + (road_edge_wave - 0.5) * 0.26 * (1.0 - road_mask * 0.55), 0.0, 1.0);
	float soft_road_mask = smoothstep(0.32, 0.88, road_edge_t);

	// Keep only the 3 highest-weight biomes (renormalized) so texture fetches per pixel stay bounded:
	// worst case = 8 control texelFetch + 3 * (2 primary + 2 secondary + 3 triplanar cliff + 1 path) = 32 fetches.
	int top_b[3] = int[3](0, 0, 0);
	float top_w[3] = float[3](0.0, 0.0, 0.0);
	for (int b = 0; b < 8; b++) {
		if (b >= biome_count) {
			break;
		}
		float w_cand = bw[b];
		if (w_cand > top_w[0]) {
			top_w[2] = top_w[1]; top_b[2] = top_b[1];
			top_w[1] = top_w[0]; top_b[1] = top_b[0];
			top_w[0] = w_cand; top_b[0] = b;
		} else if (w_cand > top_w[1]) {
			top_w[2] = top_w[1]; top_b[2] = top_b[1];
			top_w[1] = w_cand; top_b[1] = b;
		} else if (w_cand > top_w[2]) {
			top_w[2] = w_cand; top_b[2] = b;
		}
	}
	float top_sum = max(top_w[0] + top_w[1] + top_w[2], 0.0001);
	top_w[0] /= top_sum;
	top_w[1] /= top_sum;
	top_w[2] /= top_sum;

	vec3 final_albedo = vec3(0.0);
	float weight_sum = 0.0;

	for (int k = 0; k < 3; k++) {
		int b = top_b[k];
		float w = top_w[k];
		if (w <= 0.001) {
			continue;
		}
		float fb = float(b);

		vec3 p_a = texture(layer0_array, vec3(uv_ground, fb)).rgb;
		vec3 p_b = texture(layer0_array, vec3(uv_macro, fb)).rgb;
		vec3 col_primary = mix(p_a, p_b, 0.42) * biome_primary_tints[b].rgb;

		vec3 s_a = texture(layer1_array, vec3(uv_ground * 1.15, fb)).rgb;
		vec3 s_b = texture(layer1_array, vec3(uv_macro * 1.10, fb)).rgb;
		vec3 col_secondary = mix(s_a, s_b, 0.40) * biome_secondary_tints[b].rgb;

		float local_water_y = sea_level + max(0.0, biome_water_offsets[b]);
		float shore_blend = 1.0 - clamp((world_pos.y - local_water_y + 0.4) / 1.8, 0.0, 1.0);
		float sec_blend = clamp(sec_wave * 0.45 + shore_blend * 0.72, 0.0, 1.0);
		vec3 col_biome = mix(col_primary, col_secondary, sec_blend);

		vec2 sr = biome_slope_thresholds[b];
		float cliff_t = smoothstep(sr.x, max(sr.x + 0.02, sr.y), slope + barrier_mask * 0.14);
		if (cliff_t > 0.002) {
			vec3 cx = texture(layer2_cliff_array, vec3(uv_tri_x, fb)).rgb;
			vec3 cy = texture(layer2_cliff_array, vec3(uv_tri_y, fb)).rgb;
			vec3 cz = texture(layer2_cliff_array, vec3(uv_tri_z, fb)).rgb;
			vec3 col_cliff = (cx * tri_w.x + cy * tri_w.y + cz * tri_w.z) * biome_cliff_tints[b].rgb;
			col_biome = mix(col_biome, col_cliff, clamp(cliff_t, 0.0, 1.0));
		}

		vec2 ar = biome_high_alt_ranges[b];
		float alt_t = smoothstep(ar.x, max(ar.x + 0.5, ar.y), world_pos.y);
		if (alt_t > 0.002) {
			float flat_cap = 1.0 - smoothstep(0.18, 0.45, slope);
			if (biome_is_volcanic[b] > 0.5) {
				col_biome = mix(col_biome, vec3(0.20, 0.17, 0.19), alt_t * 0.55);
			} else {
				col_biome = mix(col_biome, vec3(0.88, 0.93, 0.98), alt_t * flat_cap * 0.80);
			}
		}

		if (soft_road_mask > 0.002) {
			vec3 col_path = texture(layer3_path_array, vec3(uv_path, fb)).rgb * biome_path_tints[b].rgb;
			float cobble_lum = dot(col_path, vec3(0.3333));
			float cobble_blend = smoothstep(0.08, 0.88, soft_road_mask + (cobble_lum - 0.5) * 0.18 * (1.0 - soft_road_mask));
			float verge_t = smoothstep(0.02, 0.45, soft_road_mask) * (1.0 - cobble_blend);
			col_biome = mix(col_biome, col_secondary * 0.92, verge_t * 0.65);
			col_biome = mix(col_biome, col_path, clamp(cobble_blend, 0.0, 1.0));
		}

		final_albedo += col_biome * w;
		weight_sum += w;
	}

	if (weight_sum > 0.0001) {
		final_albedo /= weight_sum;
	}

	// Damp shoreline darkening right at water level.
	float water_tint_mask = 1.0 - clamp((world_pos.y - sea_level + 0.6) / 1.4, 0.0, 1.0);
	final_albedo *= mix(1.0, 0.72, water_tint_mask * 0.55);

	ALBEDO = final_albedo;
	ROUGHNESS = 0.94;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = vec3(0.0);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float ndotl = dot(NORMAL, LIGHT) * ATTENUATION;
		float lit_band = smoothstep(-0.08, 0.34, ndotl);
		vec3 ramp = mix(shadow_color.rgb, sun_warmth_color.rgb, lit_band);
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * ramp * 0.96;
	} else {
		float nl = max(0.0, dot(NORMAL, LIGHT));
		float local_glow = smoothstep(0.0, 0.45, nl) * ATTENUATION;
		DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * local_glow * 0.45;
	}
}
