class_name TerrainGenerator
extends RefCounted

## Generates deterministic, biome-blended 3D terrain chunks and water meshes.
## Evaluates a padded height grid beyond each chunk's boundaries so vertex
## positions and finite-difference normals match identically across chunk seams.

var _biome_noises: Array[FastNoiseLite] = []
var _biome_ridge_noises: Array[FastNoiseLite] = []
var _barrier_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _configured_seed: int = -999999


func ensure_noise(layout: WorldLayoutData) -> void:
	if _configured_seed == layout.world_seed and _biome_noises.size() == layout.biomes.size() and _barrier_noise != null:
		return
	sync_noise(layout)


func sync_noise(layout: WorldLayoutData) -> void:
	var need_rebuild := (
		_configured_seed != layout.world_seed
		or _biome_noises.size() != layout.biomes.size()
		or _barrier_noise == null
		or _detail_noise == null
	)
	_configured_seed = layout.world_seed

	if need_rebuild:
		_biome_noises.clear()
		_biome_ridge_noises.clear()
		for b_idx in range(layout.biomes.size()):
			var n_fbm := FastNoiseLite.new()
			n_fbm.seed = layout.world_seed + b_idx * 997 + 17
			n_fbm.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n_fbm.fractal_type = FastNoiseLite.FRACTAL_FBM
			_biome_noises.append(n_fbm)

			var n_ridge := FastNoiseLite.new()
			n_ridge.seed = layout.world_seed + b_idx * 1301 + 53
			n_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
			_biome_ridge_noises.append(n_ridge)

		_barrier_noise = FastNoiseLite.new()
		_barrier_noise.seed = layout.world_seed + 40404
		_barrier_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_barrier_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		_barrier_noise.fractal_octaves = 3
		_barrier_noise.frequency = 0.018

		_detail_noise = FastNoiseLite.new()
		_detail_noise.seed = layout.world_seed + 70707
		_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		_detail_noise.fractal_octaves = 2
		_detail_noise.frequency = 0.024

	for b_idx in range(layout.biomes.size()):
		var biome: BiomeConfig = layout.biomes[b_idx]
		if biome == null:
			continue
		var n_fbm: FastNoiseLite = _biome_noises[b_idx]
		n_fbm.frequency = biome.noise_frequency
		n_fbm.fractal_octaves = clampi(biome.octaves, 1, 6)
		n_fbm.fractal_lacunarity = biome.lacunarity
		n_fbm.fractal_gain = biome.gain

		var n_ridge: FastNoiseLite = _biome_ridge_noises[b_idx]
		n_ridge.frequency = biome.noise_frequency * 1.1
		n_ridge.fractal_octaves = clampi(biome.octaves, 1, 6)
		n_ridge.fractal_lacunarity = biome.lacunarity
		n_ridge.fractal_gain = biome.gain


func evaluate_biome_height(biome_index: int, x: float, z: float, layout: WorldLayoutData) -> float:
	if biome_index < 0 or biome_index >= layout.biomes.size():
		return 0.0
	var biome: BiomeConfig = layout.biomes[biome_index]
	if biome == null:
		return 0.0
	var n_fbm: float = _biome_noises[biome_index].get_noise_2d(x, z)
	var n_ridge: float = _biome_ridge_noises[biome_index].get_noise_2d(x, z)
	var n_blend: float = lerpf(n_fbm, n_ridge, clampf(biome.ridge_sharpness, 0.0, 1.0))
	return biome.base_elevation + n_blend * biome.height_amplitude


func sample_terrain_at(
	x: float,
	z: float,
	layout: WorldLayoutData,
	region_gen: RegionGenerator,
	height_scale: float = 1.0,
	barrier_scale: float = 1.0
) -> Dictionary:
	ensure_noise(layout)
	var r := region_gen.sample_at(x, z, layout)
	return sample_from_region(x, z, layout, r, height_scale, barrier_scale)


func sample_height_only(
	x: float,
	z: float,
	layout: WorldLayoutData,
	region_gen: RegionGenerator,
	height_scale: float = 1.0,
	barrier_scale: float = 1.0
) -> float:
	ensure_noise(layout)
	var r := region_gen.sample_at(x, z, layout)
	return _evaluate_height_from_region(x, z, layout, r, height_scale, barrier_scale)


func sample_from_region(
	x: float,
	z: float,
	layout: WorldLayoutData,
	region_sample: Dictionary,
	height_scale: float = 1.0,
	barrier_scale: float = 1.0
) -> Dictionary:
	ensure_noise(layout)
	if layout.biomes.is_empty():
		return {
			"height": 0.0,
			"water_y": layout.sea_level,
			"region_sample": region_sample,
		}

	var h: float = _evaluate_height_from_region(x, z, layout, region_sample, height_scale, barrier_scale)
	var bids: Vector3i = region_sample["biome_ids"]
	var wts: Vector3 = region_sample["weights"]

	var b0: BiomeConfig = layout.biomes[bids.x]
	var b1: BiomeConfig = layout.biomes[bids.y]
	var b2: BiomeConfig = layout.biomes[bids.z]
	var water_off: float = 0.0
	if b0 != null:
		water_off += b0.water_table_offset * wts.x
	if b1 != null:
		water_off += b1.water_table_offset * wts.y
	if b2 != null:
		water_off += b2.water_table_offset * wts.z
	var water_y: float = layout.sea_level + maxf(0.0, water_off)

	return {
		"height": h,
		"water_y": water_y,
		"region_sample": region_sample,
	}


func _evaluate_height_from_region(
	x: float,
	z: float,
	layout: WorldLayoutData,
	region_sample: Dictionary,
	height_scale: float,
	barrier_scale: float
) -> float:
	if layout.biomes.is_empty():
		return 0.0

	var bids: Vector3i = region_sample["biome_ids"]
	var wts: Vector3 = region_sample["weights"]

	var h := 0.0
	if wts.x > 0.0001:
		h += evaluate_biome_height(bids.x, x, z, layout) * wts.x
	if wts.y > 0.0001:
		h += evaluate_biome_height(bids.y, x, z, layout) * wts.y
	if wts.z > 0.0001:
		h += evaluate_biome_height(bids.z, x, z, layout) * wts.z

	var barrier_h: float = float(region_sample.get("barrier_height", 0.0))
	if barrier_h > 0.0001 and _barrier_noise != null:
		var ridge_detail: float = 0.38 + 0.62 * ((_barrier_noise.get_noise_2d(x, z) + 1.0) * 0.5)
		h += barrier_h * ridge_detail * barrier_scale

	h *= height_scale

	var pass_grade_w: float = float(region_sample.get("pass_grade_weight", 0.0))
	if pass_grade_w > 0.0001:
		var pass_target_h: float = float(region_sample.get("pass_target_height", 0.0)) * height_scale
		h = lerpf(h, pass_target_h, pass_grade_w * 0.96)

	var road_m: float = layout.sample_road_mask(x, z)
	if road_m > 0.01:
		var road_h: float = layout.sample_road_height(x, z, h)
		var grade_t: float = smoothstep(0.01, 0.55, road_m)
		h = lerpf(h, road_h, grade_t)

	if not layout.landmarks.is_empty():
		h = _apply_landmark_flattening(x, z, h, layout)

	return h


func _apply_landmark_flattening(x: float, z: float, h: float, layout: WorldLayoutData) -> float:
	var pos2 := Vector2(x, z)
	for lm_var in layout.landmarks:
		var lm: Dictionary = lm_var
		var center: Vector2 = lm.get("center", Vector2.ZERO)
		var flat_r: float = float(lm.get("flatten_radius", 0.0))
		var blend_r: float = maxf(flat_r + 0.05, float(lm.get("blend_radius", flat_r + 12.0)))
		var target_h: float = float(lm.get("target_height", h))
		var d: float = pos2.distance_to(center)
		if d < blend_r:
			var t: float = 1.0 - smoothstep(flat_r, blend_r, d)
			h = lerpf(h, target_h, t)
	return h


## Builds all mesh, water, and physics collider buffers for chunk (cx, cz).
## Samples a 1-ring padded height grid outside the chunk boundaries so edge
## positions and normals match neighboring chunks down to floating-point precision.
func build_chunk_data(
	chunk_coord: Vector2i,
	subdivisions: int,
	layout: WorldLayoutData,
	region_gen: RegionGenerator,
	height_scale: float = 1.0,
	barrier_scale: float = 1.0,
	include_water: bool = true
) -> Dictionary:
	sync_noise(layout)

	var subs: int = maxi(4, subdivisions)
	var vert_dim: int = subs + 1
	var vert_count: int = vert_dim * vert_dim
	var padded_dim: int = subs + 3
	var step: float = float(layout.chunk_size) / float(subs)

	var half_world: float = layout.world_size * 0.5
	var origin_x: float = -half_world + float(chunk_coord.x * layout.chunk_size)
	var origin_z: float = -half_world + float(chunk_coord.y * layout.chunk_size)

	var padded_heights := PackedFloat32Array()
	padded_heights.resize(padded_dim * padded_dim)

	var water_ys := PackedFloat32Array()
	water_ys.resize(vert_count)

	var region_samples: Array[Dictionary] = []
	region_samples.resize(vert_count)

	# 1. Sample padded grid [-1 .. subs + 1]
	for gz in range(-1, subs + 2):
		var pz: int = gz + 1
		var wz: float = origin_z + float(gz) * step
		var in_z: bool = (gz >= 0 and gz <= subs)
		for gx in range(-1, subs + 2):
			var px: int = gx + 1
			var wx: float = origin_x + float(gx) * step
			var r := region_gen.sample_at(wx, wz, layout)
			var h: float = _evaluate_height_from_region(wx, wz, layout, r, height_scale, barrier_scale)
			padded_heights[pz * padded_dim + px] = h

			if in_z and gx >= 0 and gx <= subs:
				var v_idx: int = gz * vert_dim + gx
				region_samples[v_idx] = r
				var bids: Vector3i = r["biome_ids"]
				var wts: Vector3 = r["weights"]
				var water_off := 0.0
				if not layout.biomes.is_empty():
					water_off += layout.biomes[bids.x].water_table_offset * wts.x
					water_off += layout.biomes[bids.y].water_table_offset * wts.y
					water_off += layout.biomes[bids.z].water_table_offset * wts.z
				water_ys[v_idx] = layout.sea_level + maxf(0.0, water_off)

	# 2. Construct terrain vertices, cross-chunk continuous normals, tangents, colors, UVs, heightmap
	var verts := PackedVector3Array()
	verts.resize(vert_count)
	var normals := PackedVector3Array()
	normals.resize(vert_count)
	var tangents := PackedFloat32Array()
	tangents.resize(vert_count * 4)
	var colors := PackedColorArray()
	colors.resize(vert_count)
	var uvs := PackedVector2Array()
	uvs.resize(vert_count)
	var heightmap_data := PackedFloat32Array()
	heightmap_data.resize(vert_count)

	var min_height := INF
	var max_height := -INF
	var inv_subs := 1.0 / float(subs)
	var two_step := 2.0 * step

	for iz in range(vert_dim):
		var pz := iz + 1
		var lz := float(iz) * step
		var wz := origin_z + lz
		for ix in range(vert_dim):
			var px := ix + 1
			var lx := float(ix) * step
			var wx := origin_x + lx
			var v_idx := iz * vert_dim + ix

			var h := padded_heights[pz * padded_dim + px]
			var h_l := padded_heights[pz * padded_dim + (px - 1)]
			var h_r := padded_heights[pz * padded_dim + (px + 1)]
			var h_u := padded_heights[(pz - 1) * padded_dim + px]
			var h_d := padded_heights[(pz + 1) * padded_dim + px]

			var normal := Vector3(h_l - h_r, two_step, h_u - h_d).normalized()
			var t_vec := Vector3(two_step, h_r - h_l, 0.0)
			t_vec = (t_vec - normal * t_vec.dot(normal)).normalized()

			verts[v_idx] = Vector3(lx, h, lz)
			normals[v_idx] = normal
			tangents[v_idx * 4 + 0] = t_vec.x
			tangents[v_idx * 4 + 1] = t_vec.y
			tangents[v_idx * 4 + 2] = t_vec.z
			tangents[v_idx * 4 + 3] = 1.0
			uvs[v_idx] = Vector2(float(ix) * inv_subs, float(iz) * inv_subs)
			colors[v_idx] = _compute_vertex_color(wx, wz, h, water_ys[v_idx], normal, region_samples[v_idx], layout)
			heightmap_data[v_idx] = h

			min_height = minf(min_height, h)
			max_height = maxf(max_height, h)

	var indices := PackedInt32Array()
	indices.resize(subs * subs * 6)
	var idx_ptr := 0
	for iz in range(subs):
		for ix in range(subs):
			var i00 := iz * vert_dim + ix
			var i10 := i00 + 1
			var i01 := (iz + 1) * vert_dim + ix
			var i11 := i01 + 1

			indices[idx_ptr + 0] = i00
			indices[idx_ptr + 1] = i10
			indices[idx_ptr + 2] = i11
			indices[idx_ptr + 3] = i00
			indices[idx_ptr + 4] = i11
			indices[idx_ptr + 5] = i01
			idx_ptr += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# 3. Build water mesh only for cells intersecting or submerged under local water_y
	var water_mesh: ArrayMesh = null
	if include_water:
		water_mesh = _build_water_mesh(subs, vert_dim, step, heightmap_data, water_ys, region_samples, layout)

	return {
		"chunk_coord": chunk_coord,
		"origin": Vector3(origin_x, 0.0, origin_z),
		"step": step,
		"subdivisions": subs,
		"terrain_mesh": terrain_mesh,
		"water_mesh": water_mesh,
		"heightmap_data": heightmap_data,
		"min_height": min_height,
		"max_height": max_height,
	}


func _build_water_mesh(
	subs: int,
	vert_dim: int,
	step: float,
	heights: PackedFloat32Array,
	water_ys: PackedFloat32Array,
	region_samples: Array[Dictionary],
	layout: WorldLayoutData
) -> ArrayMesh:
	var vert_map := PackedInt32Array()
	vert_map.resize(vert_dim * vert_dim)
	vert_map.fill(-1)

	var w_verts := PackedVector3Array()
	var w_normals := PackedVector3Array()
	var w_colors := PackedColorArray()
	var w_uvs := PackedVector2Array()
	var w_indices := PackedInt32Array()
	var inv_subs := 1.0 / float(subs)

	for iz in range(subs):
		for ix in range(subs):
			var i00 := iz * vert_dim + ix
			var i10 := i00 + 1
			var i01 := (iz + 1) * vert_dim + ix
			var i11 := i01 + 1

			var wet := (
				heights[i00] <= water_ys[i00] + 0.35
				or heights[i10] <= water_ys[i10] + 0.35
				or heights[i01] <= water_ys[i01] + 0.35
				or heights[i11] <= water_ys[i11] + 0.35
			)
			if not wet:
				continue

			var corners: Array[int] = [i00, i10, i11, i00, i11, i01]
			for ci: int in corners:
				if vert_map[ci] == -1:
					var c_ix: int = ci % vert_dim
					@warning_ignore("integer_division")
					var c_iz: int = ci / vert_dim
					var wy := water_ys[ci]
					var depth := maxf(0.0, wy - heights[ci])
					var col := _compute_water_color(depth, region_samples[ci], layout)

					vert_map[ci] = w_verts.size()
					w_verts.append(Vector3(float(c_ix) * step, wy, float(c_iz) * step))
					w_normals.append(Vector3.UP)
					w_colors.append(col)
					w_uvs.append(Vector2(float(c_ix) * inv_subs, float(c_iz) * inv_subs))
				w_indices.append(vert_map[ci])

	if w_indices.is_empty():
		return null

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = w_verts
	arrays[Mesh.ARRAY_NORMAL] = w_normals
	arrays[Mesh.ARRAY_COLOR] = w_colors
	arrays[Mesh.ARRAY_TEX_UV] = w_uvs
	arrays[Mesh.ARRAY_INDEX] = w_indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _compute_vertex_color(
	wx: float,
	wz: float,
	height: float,
	water_y: float,
	normal: Vector3,
	region_sample: Dictionary,
	layout: WorldLayoutData
) -> Color:
	if layout.biomes.is_empty():
		return Color(0.5, 0.7, 0.5, 1.0)

	var bids: Vector3i = region_sample["biome_ids"]
	var wts: Vector3 = region_sample["weights"]
	var slope: float = 1.0 - clampf(normal.y, 0.0, 1.0)
	var n_det: float = 0.5
	if _detail_noise != null:
		n_det = clampf((_detail_noise.get_noise_2d(wx, wz) + 0.5) * 0.85, 0.0, 1.0)

	var r := 0.0
	var g := 0.0
	var b := 0.0

	var b_arr := [bids.x, bids.y, bids.z]
	var w_arr := [wts.x, wts.y, wts.z]
	for k in range(3):
		var wk: float = w_arr[k]
		if wk <= 0.0001:
			continue
		var biome: BiomeConfig = layout.biomes[b_arr[k]]
		if biome == null:
			continue
		var c_prim: Color = biome.debug_color.lerp(biome.debug_color * biome.primary_tint, 0.45)
		var c_sec: Color = biome.secondary_tint.lerp(biome.debug_color * 0.68, 0.45)
		var c_ground: Color = c_prim.lerp(c_sec, n_det * 0.55)

		var s_lo: float = biome.slope_rock_threshold.x
		var s_hi: float = maxf(s_lo + 0.02, biome.slope_rock_threshold.y)
		var cliff_t: float = smoothstep(s_lo, s_hi, slope)
		var c_biome: Color = c_ground.lerp(biome.cliff_tint, cliff_t * 0.90)

		var a_lo: float = biome.high_altitude_range.x
		var a_hi: float = maxf(a_lo + 0.5, biome.high_altitude_range.y)
		var alt_t: float = smoothstep(a_lo, a_hi, height)
		if alt_t > 0.001:
			if biome.biome_id == &"volcanic_highlands":
				c_biome = c_biome.lerp(Color(0.24, 0.19, 0.21, 1.0), alt_t * 0.65)
			else:
				# Snow caps stick mostly to flatter high peaks rather than sheer cliffs.
				var flat_mask: float = 1.0 - smoothstep(0.18, 0.42, slope)
				c_biome = c_biome.lerp(Color(0.88, 0.93, 0.98, 1.0), alt_t * flat_mask * 0.78)

		r += c_biome.r * wk
		g += c_biome.g * wk
		b += c_biome.b * wk

	var col := Color(r, g, b, 1.0)

	var bmask: float = float(region_sample.get("barrier_mask", 0.0))
	if bmask > 0.01:
		var ridge_rock_t := bmask * smoothstep(0.08, 0.32, slope) * 0.65
		col = col.lerp(Color(0.38, 0.40, 0.45, 1.0), ridge_rock_t)

	var above_water: float = height - water_y
	if above_water < 1.1:
		var shore_t := 1.0 - clampf((above_water + 0.5) / 1.6, 0.0, 1.0)
		col = col.lerp(Color(0.56, 0.50, 0.36, 1.0), shore_t * 0.62)

	return col


func _compute_water_color(depth: float, region_sample: Dictionary, layout: WorldLayoutData) -> Color:
	var bids: Vector3i = region_sample["biome_ids"]
	var wts: Vector3 = region_sample["weights"]
	var swamp_w := 0.0
	if not layout.biomes.is_empty():
		if layout.biomes[bids.x].biome_id == &"swamp":
			swamp_w += wts.x
		if layout.biomes[bids.y].biome_id == &"swamp":
			swamp_w += wts.y
		if layout.biomes[bids.z].biome_id == &"swamp":
			swamp_w += wts.z

	var depth_t := clampf(depth / 3.2, 0.0, 1.0)
	var sea_col := Color(0.26, 0.74, 0.80, 0.64).lerp(Color(0.10, 0.36, 0.56, 0.88), depth_t)
	var marsh_col := Color(0.22, 0.48, 0.38, 0.70).lerp(Color(0.12, 0.28, 0.24, 0.86), depth_t)
	return sea_col.lerp(marsh_col, clampf(swamp_w, 0.0, 1.0))
