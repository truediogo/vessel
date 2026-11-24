class_name Scatterer
extends RefCounted

## Deterministic per-chunk object scatterer building MultiMesh buffers from BiomeConfig ScatterRules.
## Enforces slope, height, water clearance, pass/landmark/road clearance, and 2D spatial-hash spacing.


func scatter_chunk(
	chunk_coord: Vector2i,
	layout: WorldLayoutData,
	region_gen: RegionGenerator,
	terrain_gen: TerrainGenerator,
	height_scale: float = 1.0,
	barrier_scale: float = 0.60,
	density_multiplier: float = 1.0
) -> Array[Dictionary]:
	var batches: Array[Dictionary] = []
	if layout == null or layout.biomes.is_empty() or density_multiplier <= 0.0:
		return batches

	terrain_gen.sync_noise(layout)

	var half_world: float = layout.world_size * 0.5
	var origin_x: float = -half_world + float(chunk_coord.x * layout.chunk_size)
	var origin_z: float = -half_world + float(chunk_coord.y * layout.chunk_size)
	var chunk_f: float = float(layout.chunk_size)

	# 1. Discover active biomes intersecting this chunk via a quick 3x3 probe
	var active_biomes := {}
	for pz in range(3):
		var wz := origin_z + float(pz) * 0.5 * chunk_f
		for px in range(3):
			var wx := origin_x + float(px) * 0.5 * chunk_f
			var rs := region_gen.sample_at(wx, wz, layout)
			var bids: Vector3i = rs["biome_ids"]
			var wts: Vector3 = rs["weights"]
			if wts.x > 0.05:
				active_biomes[bids.x] = true
			if wts.y > 0.05:
				active_biomes[bids.y] = true
			if wts.z > 0.05:
				active_biomes[bids.z] = true

	# Shared spatial hash for navigation-blocking props (trees/monoliths/boulders) so they never overlap each other.
	var nav_spatial := {}

	var sorted_biomes := active_biomes.keys()
	sorted_biomes.sort()

	for b_var in sorted_biomes:
		var b_idx: int = int(b_var)
		if b_idx < 0 or b_idx >= layout.biomes.size():
			continue
		var biome: BiomeConfig = layout.biomes[b_idx]
		if biome == null or biome.scatter_rules.is_empty():
			continue

		for r_idx in range(biome.scatter_rules.size()):
			var rule: ScatterRule = biome.scatter_rules[r_idx]
			if rule == null or rule.density_per_100m2 <= 0.0:
				continue
			var prop_mesh: Mesh = rule.resolve_mesh()
			if prop_mesh == null:
				continue

			var eff_density: float = rule.density_per_100m2 * density_multiplier
			var cell_area: float = 100.0 / maxf(0.01, eff_density)
			var cell_size: float = maxf(rule.min_spacing * 0.85, sqrt(cell_area))
			var accept_prob: float = clampf((eff_density / 100.0) * cell_size * cell_size, 0.0, 1.0)

			var gx_min: int = floori(origin_x / cell_size)
			var gx_max: int = floori((origin_x + chunk_f) / cell_size)
			var gz_min: int = floori(origin_z / cell_size)
			var gz_max: int = floori((origin_z + chunk_f) / cell_size)

			var rule_spatial := {}
			var spacing_cell: float = maxf(1.0, rule.min_spacing)

			var transforms: Array[Transform3D] = []
			var inst_colors: Array[Color] = []
			var debug_records: Array[Dictionary] = []

			for gz in range(gz_min, gz_max + 1):
				for gx in range(gx_min, gx_max + 1):
					var rng := RandomNumberGenerator.new()
					rng.seed = _cell_seed(layout.world_seed, b_idx, r_idx, gx, gz)

					var wx: float = (float(gx) + rng.randf_range(0.14, 0.86)) * cell_size
					var wz: float = (float(gz) + rng.randf_range(0.14, 0.86)) * cell_size
					if wx < origin_x or wx >= origin_x + chunk_f or wz < origin_z or wz >= origin_z + chunk_f:
						continue
					if accept_prob < 0.999 and rng.randf() > accept_prob:
						continue

					var rs := region_gen.sample_at(wx, wz, layout)
					var b_weight := _get_biome_weight(rs, b_idx)
					if b_weight < 0.16 or rng.randf() > smoothstep(0.16, 0.72, b_weight):
						continue

					var ts := terrain_gen.sample_from_region(wx, wz, layout, rs, height_scale, barrier_scale)
					var h: float = float(ts["height"])
					var water_y: float = float(ts["water_y"])
					if h < water_y + rule.min_water_clearance:
						continue
					if h < rule.height_range.x or h > rule.height_range.y:
						continue

					var normal := _sample_terrain_normal(wx, wz, layout, region_gen, terrain_gen, height_scale, barrier_scale)
					var slope_deg: float = rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
					if slope_deg > rule.max_slope_degrees:
						continue

					if not _has_world_clearance(wx, wz, rule, layout):
						continue

					var pt2 := Vector2(wx, wz)
					if rule.blocks_navigation:
						if _violates_spacing(pt2, rule.min_spacing, nav_spatial, spacing_cell):
							continue
					if _violates_spacing(pt2, rule.min_spacing, rule_spatial, spacing_cell):
						continue

					_insert_spatial(pt2, rule.min_spacing, rule_spatial, spacing_cell)
					if rule.blocks_navigation:
						_insert_spatial(pt2, rule.min_spacing, nav_spatial, spacing_cell)

					var yaw: float = rng.randf_range(0.0, TAU)
					var s_lo: float = minf(rule.scale_range.x, rule.scale_range.y)
					var s_hi: float = maxf(rule.scale_range.x, rule.scale_range.y)
					var sc: float = rng.randf_range(s_lo, s_hi)

					var b_basis: Basis
					if rule.align_to_normal:
						var up_n := normal.lerp(Vector3.UP, 0.35).normalized()
						b_basis = _basis_from_up_and_yaw(up_n, yaw)
					else:
						b_basis = Basis(Vector3.UP, yaw)
					b_basis = b_basis.scaled(Vector3(sc, sc, sc))

					var local_pos := Vector3(wx - origin_x, h - 0.08, wz - origin_z)
					transforms.append(Transform3D(b_basis, local_pos))

					inst_colors.append(Color(
						rng.randf_range(0.93, 1.07),
						rng.randf_range(0.94, 1.06),
						rng.randf_range(0.92, 1.06),
						1.0
					))
					debug_records.append({
						"world_pos": Vector3(wx, h, wz),
						"local_pos": local_pos,
						"scale": sc,
						"water_y": water_y,
						"slope_deg": slope_deg,
						"min_spacing": rule.min_spacing,
					})

			if transforms.is_empty():
				continue

			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = prop_mesh
			mm.instance_count = transforms.size()
			for idx in range(transforms.size()):
				mm.set_instance_transform(idx, transforms[idx])
				mm.set_instance_color(idx, inst_colors[idx])

			batches.append({
				"rule": rule,
				"biome_index": b_idx,
				"rule_index": r_idx,
				"multimesh": mm,
				"records": debug_records,
			})

	return batches


static func _get_biome_weight(rs: Dictionary, target_b: int) -> float:
	var bids: Vector3i = rs["biome_ids"]
	var wts: Vector3 = rs["weights"]
	var w := 0.0
	if bids.x == target_b:
		w += wts.x
	if bids.y == target_b:
		w += wts.y
	if bids.z == target_b:
		w += wts.z
	return w


static func _sample_terrain_normal(
	wx: float,
	wz: float,
	layout: WorldLayoutData,
	region_gen: RegionGenerator,
	terrain_gen: TerrainGenerator,
	height_scale: float,
	barrier_scale: float
) -> Vector3:
	var eps := 0.65
	var hl := terrain_gen.sample_height_only(wx - eps, wz, layout, region_gen, height_scale, barrier_scale)
	var hr := terrain_gen.sample_height_only(wx + eps, wz, layout, region_gen, height_scale, barrier_scale)
	var hu := terrain_gen.sample_height_only(wx, wz - eps, layout, region_gen, height_scale, barrier_scale)
	var hd := terrain_gen.sample_height_only(wx, wz + eps, layout, region_gen, height_scale, barrier_scale)
	return Vector3(hl - hr, 2.0 * eps, hu - hd).normalized()


static func _has_world_clearance(wx: float, wz: float, rule: ScatterRule, layout: WorldLayoutData) -> bool:
	var pos := Vector2(wx, wz)

	# Keep walkable pass centers open for navigation-blocking props (trees/rocks)
	if rule.blocks_navigation:
		for edge_var in layout.barrier_edges.values():
			var edge: Dictionary = edge_var
			if not bool(edge["has_barrier"]) and not bool(edge.get("is_mst", false)):
				continue
			var pc: Vector2 = edge["pass_center"]
			var pr: float = float(edge["pass_radius"])
			if pos.distance_to(pc) < pr * 0.52:
				return false

	# Landmark & Road clearance (O(1) road mask grid lookup + landmark clearance radius)
	if not layout.landmarks.is_empty():
		for lm_var in layout.landmarks:
			var lm: Dictionary = lm_var
			var c: Vector2 = lm.get("center", Vector2.ZERO)
			var clear_r: float = float(lm.get("clearance_radius", lm.get("flatten_radius", 0.0) + 4.0))
			if pos.distance_to(c) < clear_r:
				return false

	var road_m: float = layout.sample_road_mask(wx, wz)
	if road_m > (0.05 if rule.blocks_navigation else 0.28):
		return false

	return true


static func _violates_spacing(pt: Vector2, min_dist: float, grid: Dictionary, cell_sz: float) -> bool:
	var cx: int = floori(pt.x / cell_sz)
	var cz: int = floori(pt.y / cell_sz)
	var min_sq := min_dist * min_dist
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if not grid.has(key):
				continue
			var bucket: Array = grid[key]
			for entry_var in bucket:
				var entry: Dictionary = entry_var
				var other_pt: Vector2 = entry["pt"]
				var req_d: float = maxf(min_dist, float(entry["r"]))
				if pt.distance_squared_to(other_pt) < maxf(min_sq, req_d * req_d):
					return true
	return false


static func _insert_spatial(pt: Vector2, rad: float, grid: Dictionary, cell_sz: float) -> void:
	var key := Vector2i(floori(pt.x / cell_sz), floori(pt.y / cell_sz))
	if not grid.has(key):
		grid[key] = []
	grid[key].append({"pt": pt, "r": rad})


static func _basis_from_up_and_yaw(up_vec: Vector3, yaw: float) -> Basis:
	var ref := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := up_vec.cross(ref)
	if right.length_squared() < 0.0001:
		right = up_vec.cross(Vector3.RIGHT)
	right = right.normalized()
	var fwd := right.cross(up_vec).normalized()
	return Basis(right, up_vec, fwd)


static func _cell_seed(world_seed: int, b_idx: int, r_idx: int, gx: int, gz: int) -> int:
	return hash([world_seed, b_idx, r_idx, gx, gz])
