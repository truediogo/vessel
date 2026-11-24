@tool
class_name BiomeConfig
extends Resource

## Configuration Resource describing a single region biome's terrain shape,
## 4-layer painterly textures, scattering rules, and placeholder landmark scenes.

enum CompressionTarget {
	DESKTOP_S3TC = 0,
	MOBILE_ETC2 = 1,
	UNCOMPRESSED_RGBA8 = 2,
}

@export_group("Identity")
@export var biome_id: StringName = &"temperate_forest"
@export var display_name: String = "Temperate Forest"
@export var debug_color: Color = Color(0.28, 0.68, 0.34, 1.0)

@export_group("Terrain Shape")
@export var base_elevation: float = 4.0
@export var height_amplitude: float = 12.0
@export var noise_frequency: float = 0.008
@export_range(1, 6, 1) var octaves: int = 4
@export var lacunarity: float = 2.0
@export var gain: float = 0.5
## Blends standard FBM (0.0) toward ridged peaks (1.0) for mountains/volcanic highlands.
@export_range(0.0, 1.0, 0.05) var ridge_sharpness: float = 0.15
## Offset added to world sea_level to produce local lakes/marshes in depressed basins.
@export var water_table_offset: float = 0.0

@export_group("Shader Textures & Stylized Palette")
## When true, generates biome-specific painted placeholder textures in code so Step 3
## looks cohesive before swapping in custom art. Uncheck and assign tex_* slots to override.
@export var use_procedural_placeholder_textures: bool = true
@export var tex_primary: Texture2D
@export var tex_secondary: Texture2D
@export var tex_cliff: Texture2D
@export var tex_path: Texture2D
@export var primary_tint: Color = Color.WHITE
@export var secondary_tint: Color = Color(0.85, 0.78, 0.68, 1.0)
@export var cliff_tint: Color = Color(0.62, 0.60, 0.58, 1.0)
@export var path_tint: Color = Color(0.76, 0.70, 0.60, 1.0)
@export var slope_rock_threshold: Vector2 = Vector2(0.22, 0.45)
@export var high_altitude_range: Vector2 = Vector2(18.0, 28.0)

@export_group("Scattering & Landmarks")
@export var scatter_rules: Array[ScatterRule] = []
@export var landmark_scenes: Array[PackedScene] = []


## Editor-time pipeline: validates, decompresses, converts to RGBA8, resizes to `target_size x target_size`,
## generates mipmaps, and optionally VRAM-compresses slices before packing into 4 Texture2DArray assets.
static func build_validated_texture_arrays(
	biomes: Array[BiomeConfig],
	target_size: int = 512,
	compress_vram: bool = true,
	compression_target: CompressionTarget = CompressionTarget.DESKTOP_S3TC
) -> Dictionary:
	var result: Dictionary = {
		"layer0": null,
		"layer1": null,
		"layer2_cliff": null,
		"layer3_path": null,
		"warnings": PackedStringArray(),
		"errors": PackedStringArray(),
	}

	if biomes.is_empty():
		result["errors"].append("BiomeConfig.build_validated_texture_arrays: biomes array is empty.")
		push_error(result["errors"][0])
		return result

	if target_size < 16:
		result["errors"].append("BiomeConfig.build_validated_texture_arrays: target_size must be >= 16, got %d." % target_size)
		push_error(result["errors"][0])
		return result

	var slot_keys: Array[String] = ["layer0", "layer1", "layer2_cliff", "layer3_path"]
	var slot_props: Array[String] = ["tex_primary", "tex_secondary", "tex_cliff", "tex_path"]
	var tint_props: Array[String] = ["primary_tint", "secondary_tint", "cliff_tint", "path_tint"]

	for s_idx in range(4):
		var layer_images: Array[Image] = []
		var slot_key: String = slot_keys[s_idx]
		var slot_prop: String = slot_props[s_idx]
		var tint_prop: String = tint_props[s_idx]

		for b_idx in range(biomes.size()):
			var biome: BiomeConfig = biomes[b_idx]
			if biome == null:
				var err_msg := "BiomeConfig at index %d is null." % b_idx
				result["errors"].append(err_msg)
				push_error(err_msg)
				var blank := Image.create(target_size, target_size, false, Image.FORMAT_RGBA8)
				blank.fill(Color.MAGENTA)
				blank.generate_mipmaps()
				if compress_vram and compression_target != CompressionTarget.UNCOMPRESSED_RGBA8:
					_compress_image_for_target(blank, compression_target, "null", slot_prop, result)
				layer_images.append(blank)
				continue

			var work: Image = null
			if biome.use_procedural_placeholder_textures:
				var gen_size: int = mini(target_size, 256)
				work = generate_painterly_placeholder_image(biome.biome_id, s_idx, gen_size)
				if work.get_width() != target_size or work.get_height() != target_size:
					work.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
			else:
				var tex: Texture2D = biome.get(slot_prop) as Texture2D
				var fallback_tint: Color = biome.get(tint_prop) as Color
				var img: Image = null

				if tex == null:
					var warn_null := "[%s] missing %s; generating painted placeholder (%dx%d)." % [biome.display_name, slot_prop, target_size, target_size]
					result["warnings"].append(warn_null)
					push_warning(warn_null)
				else:
					img = tex.get_image()
					if img == null:
						var warn_img := "[%s] %s could not extract Image data; generating painted placeholder (%dx%d)." % [biome.display_name, slot_prop, target_size, target_size]
						result["warnings"].append(warn_img)
						push_warning(warn_img)

				if img == null:
					var gen_sz: int = mini(target_size, 256)
					work = generate_painterly_placeholder_image(biome.biome_id, s_idx, gen_sz)
					if work.get_width() != target_size or work.get_height() != target_size:
						work.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
				else:
					# Copy so we never mutate shared source Texture2D memory in place.
					work = img.duplicate() as Image
					if work.is_compressed():
						var decomp_err := work.decompress()
						if decomp_err != OK:
							var err_decomp := "[%s] %s compressed format failed to decompress (err=%d); using fallback." % [biome.display_name, slot_prop, decomp_err]
							result["errors"].append(err_decomp)
							push_error(err_decomp)
							work = Image.create(target_size, target_size, false, Image.FORMAT_RGBA8)
							work.fill(biome.debug_color.lerp(fallback_tint, 0.5))

					var orig_w: int = work.get_width()
					var orig_h: int = work.get_height()
					var orig_fmt: Image.Format = work.get_format()
					var changed := false

					if orig_fmt != Image.FORMAT_RGBA8:
						work.convert(Image.FORMAT_RGBA8)
						changed = true

					if orig_w != target_size or orig_h != target_size:
						work.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
						changed = true

					if changed:
						var warn_resize := "[%s] normalized %s (%dx%d fmt=%d -> %dx%d RGBA8) for Texture2DArray compatibility." % [
							biome.display_name, slot_prop, orig_w, orig_h, orig_fmt, target_size, target_size
						]
						result["warnings"].append(warn_resize)
						push_warning(warn_resize)

			# Texture2DArray.create_from_images requires matching mipmap counts and formats across all slices.
			work.clear_mipmaps()
			work.generate_mipmaps()
			if compress_vram and compression_target != CompressionTarget.UNCOMPRESSED_RGBA8:
				_compress_image_for_target(work, compression_target, biome.display_name, slot_prop, result)
			layer_images.append(work)

		var tex_array := Texture2DArray.new()
		var arr_err := tex_array.create_from_images(layer_images)
		if arr_err != OK:
			var msg := "Failed creating Texture2DArray for %s (error %d)." % [slot_key, arr_err]
			result["errors"].append(msg)
			push_error(msg)
		else:
			result[slot_key] = tex_array

	return result


static func _compress_image_for_target(
	img: Image,
	target: CompressionTarget,
	biome_name: String,
	slot_prop: String,
	result: Dictionary
) -> void:
	if target == CompressionTarget.MOBILE_ETC2:
		var err_etc := img.compress(Image.COMPRESS_ETC2)
		if err_etc == OK:
			return
		var warn_etc := "[%s] %s ETC2 compression unavailable (err=%d); falling back to S3TC." % [biome_name, slot_prop, err_etc]
		result["warnings"].append(warn_etc)
		push_warning(warn_etc)

	var err_s3tc := img.compress(Image.COMPRESS_S3TC)
	if err_s3tc != OK:
		var err_msg := "[%s] %s VRAM compression failed with err=%d." % [biome_name, slot_prop, err_s3tc]
		result["errors"].append(err_msg)
		push_error(err_msg)


## Editor-only bake step: packs, VRAM-compresses, and saves the 4 Texture2DArray assets
## as `.res` files so runtime startup loads compressed GPU textures with zero RGBA8 conversion.
static func bake_and_save_texture_arrays(
	biomes: Array[BiomeConfig],
	save_dir: String = "res://resources/biomes/compiled",
	target_size: int = 512,
	compression_target: CompressionTarget = CompressionTarget.DESKTOP_S3TC
) -> Dictionary:
	var result := {
		"layer0": null,
		"layer1": null,
		"layer2_cliff": null,
		"layer3_path": null,
		"warnings": PackedStringArray(),
		"errors": PackedStringArray(),
		"saved_paths": {},
	}
	if DisplayServer.get_name() == "headless":
		var msg := "BiomeConfig.bake_and_save_texture_arrays requires a live renderer (not --headless); Dummy driver cannot read back Texture2DArray layers for saving."
		result["errors"].append(msg)
		push_error(msg)
		return result

	var use_vram: bool = (compression_target != CompressionTarget.UNCOMPRESSED_RGBA8)
	result = build_validated_texture_arrays(biomes, target_size, use_vram, compression_target)
	result["saved_paths"] = {}
	if not result["errors"].is_empty():
		return result

	var abs_dir := ProjectSettings.globalize_path(save_dir)
	var mk_err := DirAccess.make_dir_recursive_absolute(abs_dir)
	if mk_err != OK:
		var msg := "Failed creating compiled texture directory '%s' (err=%d)." % [abs_dir, mk_err]
		result["errors"].append(msg)
		push_error(msg)
		return result

	var slot_keys: Array[String] = ["layer0", "layer1", "layer2_cliff", "layer3_path"]
	for slot_key in slot_keys:
		var tex_arr := result[slot_key] as Texture2DArray
		if tex_arr == null:
			continue
		var res_path := save_dir.path_join(slot_key + "_array.res")
		var save_err := ResourceSaver.save(tex_arr, res_path, ResourceSaver.FLAG_COMPRESS)
		if save_err != OK:
			var msg := "Failed saving baked Texture2DArray to '%s' (err=%d)." % [res_path, save_err]
			result["errors"].append(msg)
			push_error(msg)
		else:
			result["saved_paths"][slot_key] = res_path

	return result


## Generates a tileable hand-painted style RGBA8 placeholder texture for a biome and layer slot
## (0 = primary ground, 1 = secondary soil/sub-surface, 2 = stratified cliff rock, 3 = cobblestone road).
static func generate_painterly_placeholder_image(
	biome_id: StringName,
	slot_index: int,
	target_size: int = 256
) -> Image:
	var sz: int = maxi(16, target_size)
	var palette := _get_placeholder_palette(biome_id, slot_index)
	var c_dark: Color = palette[0]
	var c_mid: Color = palette[1]
	var c_hi: Color = palette[2]

	var n_macro := FastNoiseLite.new()
	n_macro.seed = int(biome_id.hash()) + slot_index * 313 + 77
	n_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_macro.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_macro.fractal_octaves = 3
	n_macro.frequency = 0.032 if slot_index != 2 else 0.022

	var n_stroke := FastNoiseLite.new()
	n_stroke.seed = int(biome_id.hash()) + slot_index * 719 + 411
	n_stroke.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_stroke.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_stroke.fractal_octaves = 2
	n_stroke.frequency = 0.085

	var img_macro: Image = n_macro.get_seamless_image(sz, sz, false, false, true)
	var img_stroke: Image = n_stroke.get_seamless_image(sz, sz, false, false, true)
	var out := Image.create(sz, sz, false, Image.FORMAT_RGBA8)

	# Precompute periodic cobble sites on [0, 1]^2 for Layer 3 road pavers.
	var cobble_pts: Array[Vector2] = []
	if slot_index == 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(biome_id.hash()) + 909
		var grid := 5
		for gy in range(grid):
			for gx in range(grid):
				cobble_pts.append(Vector2(
					(float(gx) + 0.5 + rng.randf_range(-0.28, 0.28)) / float(grid),
					(float(gy) + 0.5 + rng.randf_range(-0.28, 0.28)) / float(grid)
				))

	var inv_sz := 1.0 / float(sz)
	for py in range(sz):
		var v: float = float(py) * inv_sz
		for px in range(sz):
			var u: float = float(px) * inv_sz
			var m_val: float = img_macro.get_pixel(px, py).r
			var s_val: float = img_stroke.get_pixel(px, py).r
			var col: Color

			if slot_index == 0 or slot_index == 1:
				# Painterly soft brushstroke tufts: quantized 4-step paint value blended softly
				var paint_t: float = clampf(m_val * 0.62 + s_val * 0.38, 0.0, 1.0)
				var stepped: float = floor(paint_t * 5.0) / 5.0
				var t: float = lerpf(paint_t, stepped, 0.34)
				col = c_dark.lerp(c_mid, smoothstep(0.12, 0.58, t))
				col = col.lerp(c_hi, smoothstep(0.54, 0.92, t))
				if biome_id == &"volcanic_highlands" and slot_index == 0 and m_val < 0.24:
					col = col.lerp(Color(0.86, 0.34, 0.14, 1.0), smoothstep(0.24, 0.10, m_val) * 0.65)
			elif slot_index == 2:
				# Stratified cliff rock bands with crisp painted facets
				var strata: float = 0.5 + 0.5 * sin((v * 5.0 + m_val * 1.35) * TAU)
				var rock_t: float = clampf(strata * 0.52 + s_val * 0.32 + m_val * 0.16, 0.0, 1.0)
				var stepped_r: float = floor(rock_t * 4.0) / 4.0
				var rt: float = lerpf(rock_t, stepped_r, 0.38)
				col = c_dark.lerp(c_mid, smoothstep(0.15, 0.55, rt))
				col = col.lerp(c_hi, smoothstep(0.55, 0.92, rt))
			else:
				# Torus-wrapped cobblestone / flagstone pavers for Layer 3 roads
				var d0 := 999.0
				var d1 := 999.0
				var uv_warp := Vector2(u + (m_val - 0.5) * 0.04, v + (s_val - 0.5) * 0.04)
				for cp in cobble_pts:
					var dx := absf(uv_warp.x - cp.x)
					dx = minf(dx, 1.0 - dx)
					var dy := absf(uv_warp.y - cp.y)
					dy = minf(dy, 1.0 - dy)
					var d := sqrt(dx * dx + dy * dy)
					if d < d0:
						d1 = d0
						d0 = d
					elif d < d1:
						d1 = d
				var edge_gap: float = clampf((d1 - d0) / 0.032, 0.0, 1.0)
				var stone_t: float = clampf(m_val * 0.6 + s_val * 0.4, 0.0, 1.0)
				var stone_col: Color = c_mid.lerp(c_hi, smoothstep(0.25, 0.88, stone_t))
				col = c_dark.lerp(stone_col, smoothstep(0.08, 0.45, edge_gap))

			col.a = 1.0
			out.set_pixel(px, py, col)

	return out


static func _get_placeholder_palette(biome_id: StringName, slot_index: int) -> Array[Color]:
	match biome_id:
		&"temperate_forest":
			match slot_index:
				0: return [Color(0.18, 0.34, 0.22), Color(0.30, 0.52, 0.29), Color(0.49, 0.68, 0.34)]
				1: return [Color(0.23, 0.21, 0.16), Color(0.38, 0.32, 0.23), Color(0.49, 0.42, 0.29)]
				2: return [Color(0.21, 0.25, 0.27), Color(0.32, 0.36, 0.37), Color(0.43, 0.48, 0.39)]
				_: return [Color(0.29, 0.31, 0.26), Color(0.49, 0.47, 0.41), Color(0.62, 0.59, 0.50)]
		&"coastal_plains":
			match slot_index:
				0: return [Color(0.24, 0.44, 0.24), Color(0.42, 0.65, 0.31), Color(0.62, 0.79, 0.40)]
				1: return [Color(0.55, 0.47, 0.30), Color(0.74, 0.64, 0.44), Color(0.85, 0.77, 0.56)]
				2: return [Color(0.33, 0.36, 0.35), Color(0.49, 0.52, 0.49), Color(0.65, 0.67, 0.62)]
				_: return [Color(0.42, 0.40, 0.34), Color(0.62, 0.58, 0.49), Color(0.76, 0.71, 0.60)]
		&"frozen_tundra":
			match slot_index:
				0: return [Color(0.46, 0.58, 0.70), Color(0.71, 0.82, 0.90), Color(0.92, 0.96, 0.99)]
				1: return [Color(0.29, 0.35, 0.43), Color(0.44, 0.51, 0.60), Color(0.61, 0.69, 0.78)]
				2: return [Color(0.16, 0.21, 0.28), Color(0.28, 0.35, 0.44), Color(0.44, 0.53, 0.62)]
				_: return [Color(0.28, 0.34, 0.41), Color(0.48, 0.55, 0.63), Color(0.66, 0.73, 0.80)]
		&"desert":
			match slot_index:
				0: return [Color(0.62, 0.42, 0.20), Color(0.82, 0.61, 0.32), Color(0.94, 0.77, 0.47)]
				1: return [Color(0.48, 0.30, 0.16), Color(0.67, 0.43, 0.24), Color(0.81, 0.56, 0.34)]
				2: return [Color(0.41, 0.22, 0.16), Color(0.60, 0.33, 0.22), Color(0.75, 0.46, 0.31)]
				_: return [Color(0.49, 0.38, 0.25), Color(0.72, 0.59, 0.41), Color(0.85, 0.73, 0.54)]
		&"swamp":
			match slot_index:
				0: return [Color(0.13, 0.24, 0.20), Color(0.23, 0.39, 0.30), Color(0.35, 0.51, 0.35)]
				1: return [Color(0.16, 0.16, 0.12), Color(0.26, 0.25, 0.18), Color(0.36, 0.34, 0.24)]
				2: return [Color(0.16, 0.21, 0.21), Color(0.24, 0.30, 0.29), Color(0.32, 0.40, 0.35)]
				_: return [Color(0.20, 0.25, 0.20), Color(0.33, 0.38, 0.30), Color(0.44, 0.49, 0.38)]
		&"volcanic_highlands":
			match slot_index:
				0: return [Color(0.15, 0.12, 0.14), Color(0.27, 0.22, 0.23), Color(0.40, 0.29, 0.27)]
				1: return [Color(0.25, 0.14, 0.12), Color(0.42, 0.21, 0.16), Color(0.57, 0.29, 0.20)]
				2: return [Color(0.11, 0.11, 0.13), Color(0.20, 0.19, 0.23), Color(0.31, 0.29, 0.33)]
				_: return [Color(0.18, 0.17, 0.20), Color(0.30, 0.28, 0.32), Color(0.42, 0.38, 0.42)]
		_:
			var hue := fmod(float(absi(biome_id.hash())) * 0.137, 1.0)
			var base := Color.from_hsv(hue, 0.45, 0.55)
			return [base.darkened(0.35), base, base.lightened(0.25)]


## Runtime loader: loads the pre-baked compressed Texture2DArray resources without decompression or resizing.
static func load_baked_texture_arrays(save_dir: String = "res://resources/biomes/compiled") -> Dictionary:
	var result: Dictionary = {
		"layer0": null,
		"layer1": null,
		"layer2_cliff": null,
		"layer3_path": null,
		"errors": PackedStringArray(),
	}
	var slot_keys: Array[String] = ["layer0", "layer1", "layer2_cliff", "layer3_path"]
	for slot_key in slot_keys:
		var res_path := save_dir.path_join(slot_key + "_array.res")
		if not ResourceLoader.exists(res_path):
			var msg := "Missing baked Texture2DArray '%s'. Run 'Bake Biome Texture Arrays' in the editor." % res_path
			result["errors"].append(msg)
			push_error(msg)
			continue
		var res := ResourceLoader.load(res_path) as Texture2DArray
		if res == null:
			var msg := "Failed loading Texture2DArray from '%s'." % res_path
			result["errors"].append(msg)
			push_error(msg)
			continue
		result[slot_key] = res
	return result
