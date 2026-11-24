class_name RegionGenerator
extends RefCounted

## Generates deterministic, domain-warped Voronoi regions with C1-continuous
## 3-biome blending (triple-junction safe), MST-guaranteed reachability,
## mountain barrier borders with open pass gates, chunk control maps, and
## a top-down 2D debug visualization.

var _warp_x: FastNoiseLite
var _warp_z: FastNoiseLite
var _configured_seed: int = -1
var _configured_warp_freq: float = -1.0


func ensure_warp_noise(world_seed: int, warp_frequency: float) -> void:
	if _warp_x != null and _warp_z != null and _configured_seed == world_seed and is_equal_approx(_configured_warp_freq, warp_frequency):
		return
	_configured_seed = world_seed
	_configured_warp_freq = warp_frequency

	_warp_x = FastNoiseLite.new()
	_warp_x.seed = world_seed + 101
	_warp_x.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp_x.fractal_type = FastNoiseLite.FRACTAL_FBM
	_warp_x.fractal_octaves = 2
	_warp_x.frequency = warp_frequency

	_warp_z = FastNoiseLite.new()
	_warp_z.seed = world_seed + 202
	_warp_z.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp_z.fractal_type = FastNoiseLite.FRACTAL_FBM
	_warp_z.fractal_octaves = 2
	_warp_z.frequency = warp_frequency


func generate_layout(
	world_seed: int,
	world_size: float,
	chunk_size: int,
	region_count: int,
	border_blend_distance: float,
	sea_level: float,
	biomes: Array[BiomeConfig],
	warp_strength: float = 28.0,
	warp_frequency: float = 0.0045,
	prevent_adjacent_identical: bool = true
) -> WorldLayoutData:
	ensure_warp_noise(world_seed, warp_frequency)

	var layout := WorldLayoutData.new()
	layout.world_seed = world_seed
	layout.world_size = maxf(64.0, world_size)
	layout.chunk_size = maxi(16, chunk_size)
	layout.region_count = clampi(region_count, 2, 32)
	layout.border_blend_distance = maxf(1.0, border_blend_distance)
	layout.warp_strength = warp_strength
	layout.warp_frequency = warp_frequency
	layout.sea_level = sea_level
	layout.biomes = biomes.duplicate()

	if biomes.is_empty():
		push_warning("RegionGenerator: no BiomeConfig resources supplied.")
		return layout

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(world_seed)

	# 1. Stratified Jittered Grid Voronoi Sites (scales smoothly with any world_size).
	var cols: int = maxi(2, ceili(sqrt(float(layout.region_count) * 1.25)))
	var rows: int = maxi(2, ceili(float(layout.region_count) / float(cols)))
	var usable_span: float = layout.world_size * 0.86
	var half_usable: float = usable_span * 0.5
	var cell_w: float = usable_span / float(cols)
	var cell_h: float = usable_span / float(rows)

	var cell_coords: Array[Vector2i] = []
	for r in range(rows):
		for c in range(cols):
			cell_coords.append(Vector2i(c, r))
	_shuffle_array_rng(cell_coords, rng)

	var centers: Array[Vector2] = []
	for i in range(layout.region_count):
		var cell: Vector2i = cell_coords[i % cell_coords.size()]
		var cx: float = -half_usable + (float(cell.x) + 0.5) * cell_w + rng.randf_range(-0.32 * cell_w, 0.32 * cell_w)
		var cz: float = -half_usable + (float(cell.y) + 0.5) * cell_h + rng.randf_range(-0.32 * cell_h, 0.32 * cell_h)
		centers.append(Vector2(cx, cz))

	# 2. Discover Voronoi adjacency + exact shared border sample accumulators.
	var half_world: float = layout.world_size * 0.5
	var adj_sets: Array[Dictionary] = []
	for i in range(layout.region_count):
		adj_sets.append({})

	var edge_samples: Dictionary = {} # key -> Array[Vector2]
	var grid_samples: int = 56
	var step: float = layout.world_size / float(grid_samples)

	for gz in range(grid_samples):
		var z: float = -half_world + (float(gz) + 0.5) * step
		for gx in range(grid_samples):
			var x: float = -half_world + (float(gx) + 0.5) * step
			var p_warped := _warp_point(x, z, layout)
			var top2 := _closest_two_sites(p_warped, centers)
			var id0: int = top2[0]
			var id1: int = top2[1]
			var d_diff: float = top2[3] - top2[2]
			if id0 != id1 and id1 >= 0:
				adj_sets[id0][id1] = true
				adj_sets[id1][id0] = true
				if d_diff <= step * 2.2:
					var ekey := WorldLayoutData.get_edge_key(id0, id1)
					if not edge_samples.has(ekey):
						edge_samples[ekey] = []
					edge_samples[ekey].append(Vector2(x, z))

	# 3. Assign biomes ensuring every biome in `biomes` is used at least once when region_count >= biomes.size(),
	#    and strictly preventing adjacent regions from sharing the same biome via degree-ordered backtracking.
	var b_count: int = biomes.size()
	var assigned_biomes := _assign_biomes_graph_coloring(
		adj_sets, b_count, layout.region_count, prevent_adjacent_identical, rng
	)

	for r_i in range(layout.region_count):
		var nbs := PackedInt32Array()
		for nb_id in adj_sets[r_i].keys():
			nbs.append(int(nb_id))
		nbs.sort()
		var b_idx: int = assigned_biomes[r_i]
		layout.regions.append({
			"id": r_i,
			"center": centers[r_i],
			"biome_index": b_idx,
			"biome": biomes[b_idx],
			"neighbors": nbs,
		})

	# 4. Build Minimum Spanning Tree (Prim) so all regions are connected by open corridors or pass gates.
	var in_mst: Dictionary = {0: true}
	var mst_edges: Dictionary = {}
	while in_mst.size() < layout.region_count:
		var best_u := -1
		var best_v := -1
		var best_dist := INF
		for u_var in in_mst.keys():
			var u: int = int(u_var)
			for v_var in adj_sets[u].keys():
				var v: int = int(v_var)
				if in_mst.has(v):
					continue
				var dist_uv: float = centers[u].distance_to(centers[v]) + rng.randf_range(0.0, layout.world_size * 0.08)
				if dist_uv < best_dist:
					best_dist = dist_uv
					best_u = u
					best_v = v
		if best_v == -1:
			# Disconnected graph fallback (rare on tiny layouts): link nearest unvisited node
			for v in range(layout.region_count):
				if in_mst.has(v):
					continue
				for u_var in in_mst.keys():
					var u: int = int(u_var)
					var d_uv: float = centers[u].distance_to(centers[v])
					if d_uv < best_dist:
						best_dist = d_uv
						best_u = u
						best_v = v
		if best_v != -1:
			in_mst[best_v] = true
			mst_edges[WorldLayoutData.get_edge_key(best_u, best_v)] = true
		else:
			break

	# 5. Mark ~60% of shared borders as Mountain/Cliff Barriers; always carve a Pass Gate per barrier!
	var pass_rad: float = maxf(18.0, layout.world_size * 0.045)
	for r_i in range(layout.region_count):
		for nb_var in adj_sets[r_i].keys():
			var nb: int = int(nb_var)
			if r_i >= nb:
				continue
			var ekey := WorldLayoutData.get_edge_key(r_i, nb)
			var is_mst: bool = mst_edges.has(ekey)
			var has_barrier: bool = (rng.randf() < 0.72) if not is_mst else (rng.randf() < 0.35)

			var midpoint: Vector2 = (centers[r_i] + centers[nb]) * 0.5
			if edge_samples.has(ekey):
				var pts: Array = edge_samples[ekey]
				if not pts.is_empty():
					# Pick the border sample with high clearance from 3rd regions (triple junctions)
					# while staying near the chord midpoint so the pass gate stays centered & wide open.
					var best_pt: Vector2 = pts[0]
					var best_score := -INF
					for pt_var in pts:
						var pt: Vector2 = pt_var
						var pw := _warp_point(pt.x, pt.y, layout)
						var d_pair: float = minf(pw.distance_to(centers[r_i]), pw.distance_to(centers[nb]))
						var d_third := INF
						for k in range(layout.region_count):
							if k == r_i or k == nb:
								continue
							d_third = minf(d_third, pw.distance_to(centers[k]))
						var triple_clearance: float = maxf(0.0, d_third - d_pair)
						var score: float = minf(triple_clearance, layout.border_blend_distance * 1.15) - 0.30 * pt.distance_to(midpoint)
						if score > best_score:
							best_score = score
							best_pt = pt
					midpoint = best_pt

			layout.barrier_edges[ekey] = {
				"has_barrier": has_barrier,
				"is_mst": is_mst,
				"pass_center": midpoint,
				"pass_radius": pass_rad,
				"ridge_height": rng.randf_range(16.0, 26.0) if has_barrier else 0.0,
			}

	return layout


## Evaluates the domain-warped Voronoi cell memberships at world (x, z) and returns:
## - "region_ids": Vector3i(id0, id1, id2) sorted nearest-first
## - "biome_ids": Vector3i(b0, b1, b2) matching biome indices
## - "weights": Vector3(w0, w1, w2) summing to 1.0 (C1 continuous across 2-way & 3-way borders!)
## - "border_distance": float (d1 - d0)
## - "barrier_mask": float in [0, 1] peaking along barrier borders and dropping to 0 at Pass Gates
func sample_at(x: float, z: float, layout: WorldLayoutData) -> Dictionary:
	ensure_warp_noise(layout.world_seed, layout.warp_frequency)
	var regions: Array[Dictionary] = layout.regions
	if regions.is_empty():
		return {
			"region_ids": Vector3i(0, 0, 0),
			"biome_ids": Vector3i(0, 0, 0),
			"weights": Vector3(1.0, 0.0, 0.0),
			"border_distance": 999.0,
			"barrier_mask": 0.0,
			"barrier_height": 0.0,
			"pass_grade_weight": 0.0,
			"pass_target_height": 0.0,
		}

	var p := _warp_point(x, z, layout)

	# Track 3 closest Voronoi sites without allocating arrays per sample.
	var id0 := 0
	var id1 := 0
	var id2 := 0
	var d0 := INF
	var d1 := INF
	var d2 := INF

	for i in range(regions.size()):
		var c: Vector2 = regions[i]["center"]
		var d: float = p.distance_to(c)
		if d < d0:
			d2 = d1
			id2 = id1
			d1 = d0
			id1 = id0
			d0 = d
			id0 = i
		elif d < d1:
			d2 = d1
			id2 = id1
			d1 = d
			id1 = i
		elif d < d2:
			d2 = d
			id2 = i

	if regions.size() < 2:
		id1 = id0
		d1 = d0 + layout.border_blend_distance
	if regions.size() < 3:
		id2 = id1
		d2 = d1 + layout.border_blend_distance

	# Symmetric C1-continuous kernel relative to d0:
	# - On a 2-border seam (d1 == d0): raw0 == raw1 == 1.0 => w0 == w1
	# - On a 3-border triple junction (d2 == d1 == d0): raw0 == raw1 == raw2 == 1.0 => w0 == w1 == w2 == 1/3
	var blend_dist: float = maxf(1.0, layout.border_blend_distance)
	var raw0: float = 1.0
	var raw1: float = _inv_smoothstep01((d1 - d0) / blend_dist)
	var raw2: float = _inv_smoothstep01((d2 - d0) / blend_dist)
	var inv_sum: float = 1.0 / (raw0 + raw1 + raw2)

	var w0: float = raw0 * inv_sum
	var w1: float = raw1 * inv_sum
	var w2: float = raw2 * inv_sum

	var b0: int = regions[id0]["biome_index"]
	var b1: int = regions[id1]["biome_index"]
	var b2: int = regions[id2]["biome_index"]

	var border_distance: float = d1 - d0
	var barrier_res := _evaluate_barrier_triple(
		Vector2(x, z),
		Vector3i(id0, id1, id2),
		Vector3(w0, w1, w2),
		layout
	)

	return {
		"region_ids": Vector3i(id0, id1, id2),
		"biome_ids": Vector3i(b0, b1, b2),
		"weights": Vector3(w0, w1, w2),
		"border_distance": border_distance,
		"barrier_mask": barrier_res["mask"],
		"barrier_height": barrier_res["height"],
		"pass_grade_weight": barrier_res["pass_grade_weight"],
		"pass_target_height": barrier_res["pass_target_height"],
	}


func _evaluate_barrier_triple(world_xz: Vector2, rids: Vector3i, wts: Vector3, layout: WorldLayoutData) -> Dictionary:
	var p01 := Vector4(0.0, 0.0, 1.0, 0.0)
	var p02 := Vector4(0.0, 0.0, 1.0, 0.0)
	var p12 := Vector4(0.0, 0.0, 1.0, 0.0)
	var th01 := 0.0
	var th02 := 0.0
	var th12 := 0.0

	if rids.x != rids.y:
		var res01 := _evaluate_barrier_pair(world_xz, rids.x, rids.y, wts.x, wts.y, layout)
		p01 = res01["vec"]
		th01 = res01["target_h"]
	if rids.x != rids.z:
		var res02 := _evaluate_barrier_pair(world_xz, rids.x, rids.z, wts.x, wts.z, layout)
		p02 = res02["vec"]
		th02 = res02["target_h"]
	if rids.y != rids.z:
		var res12 := _evaluate_barrier_pair(world_xz, rids.y, rids.z, wts.y, wts.z, layout)
		p12 = res12["vec"]
		th12 = res12["target_h"]

	var m01: float = p01.x
	var h01: float = p01.y
	var m02: float = p02.x
	var h02: float = p02.y
	var m12: float = p12.x
	var h12: float = p12.y

	# Symmetric probabilistic union across the 3 neighbor pairs guarantees C1 continuity
	# everywhere (including 3-way Voronoi triple junctions) and keeps mask strictly in [0, 1].
	# Multiplying by all active pass openings prevents an adjacent ridge from partially sealing a Pass Gate.
	var pass_clear: float = p01.z * p02.z * p12.z
	var mask: float = (1.0 - (1.0 - m01) * (1.0 - m02) * (1.0 - m12)) * pass_clear
	var sum_m: float = m01 + m02 + m12
	var height := 0.0
	if sum_m > 0.00001 and mask > 0.00001:
		var avg_ridge_h: float = (m01 * h01 + m02 * h02 + m12 * h12) / sum_m
		height = mask * avg_ridge_h

	var g01: float = p01.w
	var g02: float = p02.w
	var g12: float = p12.w
	var pass_grade_weight: float = 1.0 - (1.0 - g01) * (1.0 - g02) * (1.0 - g12)
	var sum_g: float = g01 + g02 + g12
	var pass_target_height := 0.0
	if sum_g > 0.00001:
		pass_target_height = (g01 * th01 + g02 * th02 + g12 * th12) / sum_g

	return {
		"mask": clampf(mask, 0.0, 1.0),
		"height": height,
		"pass_grade_weight": clampf(pass_grade_weight, 0.0, 1.0),
		"pass_target_height": pass_target_height,
	}


func _evaluate_barrier_pair(world_xz: Vector2, id_a: int, id_b: int, w_a: float, w_b: float, layout: WorldLayoutData) -> Dictionary:
	var ekey := WorldLayoutData.get_edge_key(id_a, id_b)
	if not layout.barrier_edges.has(ekey):
		return {"vec": Vector4(0.0, 0.0, 1.0, 0.0), "target_h": 0.0}
	var edge_info: Dictionary = layout.barrier_edges[ekey]
	var has_barrier: bool = bool(edge_info["has_barrier"])
	var is_mst: bool = bool(edge_info.get("is_mst", false))
	if not has_barrier and not is_mst:
		return {"vec": Vector4(0.0, 0.0, 1.0, 0.0), "target_h": 0.0}

	var pass_center: Vector2 = edge_info["pass_center"]
	var pass_radius: float = float(edge_info["pass_radius"])
	var dist_to_pass: float = world_xz.distance_to(pass_center)
	var pass_open: float = 1.0 - _inv_smoothstep01(maxf(0.0, dist_to_pass - pass_radius * 0.85) / maxf(1.0, pass_radius * 1.15))
	# Gentle LoL-style corridor floor out to 0.85 * pass_radius, ramping smoothly to 2.35 * pass_radius (<= 28 deg).
	var pass_grade: float = _inv_smoothstep01(maxf(0.0, dist_to_pass - pass_radius * 0.85) / maxf(1.0, pass_radius * 1.50))

	var ba: BiomeConfig = layout.regions[id_a]["biome"]
	var bb: BiomeConfig = layout.regions[id_b]["biome"]
	var target_h: float = 0.5 * ((ba.base_elevation if ba != null else 0.0) + (bb.base_elevation if bb != null else 0.0))

	if not has_barrier:
		return {"vec": Vector4(0.0, 0.0, pass_open, pass_grade), "target_h": target_h}

	var pair_weight: float = pow(smoothstep(0.14, 1.0, 4.0 * w_a * w_b), 1.65)
	if pair_weight <= 0.0001:
		return {"vec": Vector4(0.0, 0.0, pass_open, pass_grade), "target_h": target_h}

	var mask: float = pair_weight * pass_open
	var ridge_h: float = float(edge_info.get("ridge_height", 20.0))
	return {"vec": Vector4(mask, ridge_h, pass_open, pass_grade), "target_h": target_h}


## Builds the two chunk-local RGBA8 control textures required for triple-junction-free
## 3-biome terrain shader blending:
## - "id_image" (must sample with filter_nearest / texelFetch): R=b0/255, G=b1/255, B=b2/255, A=barrier_mask
## - "weight_image" (must sample with filter_nearest / texelFetch, NOT linear):
##     R=w0, G=w1, B=w2 quantized so r8 + g8 + b8 == 255, A=road_mask (0.0 until Step 5).
## Step 3 shader contract: slot ordering (b0, b1, b2) can swap between adjacent texels as
## nearest Voronoi sites cross boundaries, so the shader performs a manual 4-tap bilinear
## `texelFetch` on both textures and accumulates weights per biome ID before blending textures.
func build_chunk_control_maps(chunk_coord: Vector2i, tex_res: int, layout: WorldLayoutData) -> Dictionary:
	var id_img := Image.create(tex_res, tex_res, false, Image.FORMAT_RGBA8)
	var wt_img := Image.create(tex_res, tex_res, false, Image.FORMAT_RGBA8)

	var half_world: float = layout.world_size * 0.5
	var origin_x: float = -half_world + float(chunk_coord.x * layout.chunk_size)
	var origin_z: float = -half_world + float(chunk_coord.y * layout.chunk_size)
	var inv_denom: float = 1.0 / float(maxi(1, tex_res - 1))

	for py in range(tex_res):
		var wz: float = origin_z + float(py) * inv_denom * float(layout.chunk_size)
		for px in range(tex_res):
			var wx: float = origin_x + float(px) * inv_denom * float(layout.chunk_size)
			var s := sample_at(wx, wz, layout)
			var bids: Vector3i = s["biome_ids"]
			var wts: Vector3 = s["weights"]
			var bmask: float = float(s["barrier_mask"])

			var f0: float = clampf(wts.x, 0.0, 1.0) * 255.0
			var f1: float = clampf(wts.y, 0.0, 1.0) * 255.0
			var f2: float = clampf(wts.z, 0.0, 1.0) * 255.0
			var q0: int = int(floor(f0))
			var q1: int = int(floor(f1))
			var q2: int = int(floor(f2))
			var rem: int = 255 - (q0 + q1 + q2)
			var r0: float = f0 - float(q0)
			var r1: float = f1 - float(q1)
			var r2: float = f2 - float(q2)
			for _k in range(maxi(0, rem)):
				if r0 >= r1 and r0 >= r2:
					q0 += 1
					r0 = -1.0
				elif r1 >= r0 and r1 >= r2:
					q1 += 1
					r1 = -1.0
				else:
					q2 += 1
					r2 = -1.0

			id_img.set_pixel(px, py, Color(
				float(bids.x) / 255.0,
				float(bids.y) / 255.0,
				float(bids.z) / 255.0,
				clampf(bmask, 0.0, 1.0)
			))
			var road_mask: float = clampf(layout.sample_road_mask(wx, wz), 0.0, 1.0)
			wt_img.set_pixel(px, py, Color(
				float(q0) / 255.0,
				float(q1) / 255.0,
				float(q2) / 255.0,
				road_mask
			))

	return {
		"id_image": id_img,
		"weight_image": wt_img,
	}


## CPU reference implementation of the Step 3 shader's manual 4-tap `texelFetch` bilinear filter:
## fetches the 4 nearest control-map texels and accumulates weights per integer biome ID so
## slot swaps (b0/b1/b2 reordering across borders) never blend weights of different biomes.
static func sample_control_maps_bilinear(
	id_img: Image,
	wt_img: Image,
	uv: Vector2,
	biome_count: int
) -> Dictionary:
	var w: int = id_img.get_width()
	var h: int = id_img.get_height()
	var biome_weights := PackedFloat32Array()
	biome_weights.resize(maxi(1, biome_count))

	var fx: float = clampf(uv.x, 0.0, 1.0) * float(maxi(1, w - 1))
	var fy: float = clampf(uv.y, 0.0, 1.0) * float(maxi(1, h - 1))
	var x0: int = clampi(int(floor(fx)), 0, w - 1)
	var y0: int = clampi(int(floor(fy)), 0, h - 1)
	var x1: int = mini(x0 + 1, w - 1)
	var y1: int = mini(y0 + 1, h - 1)
	var tx: float = fx - float(x0)
	var ty: float = fy - float(y0)

	var tap_coords: Array[Vector2i] = [
		Vector2i(x0, y0),
		Vector2i(x1, y0),
		Vector2i(x0, y1),
		Vector2i(x1, y1),
	]
	var tap_weights: Array[float] = [
		(1.0 - tx) * (1.0 - ty),
		tx * (1.0 - ty),
		(1.0 - tx) * ty,
		tx * ty,
	]

	var barrier_mask := 0.0
	var road_mask := 0.0
	for i in range(4):
		var tc: Vector2i = tap_coords[i]
		var tw: float = tap_weights[i]
		var id_c: Color = id_img.get_pixel(tc.x, tc.y)
		var wt_c: Color = wt_img.get_pixel(tc.x, tc.y)

		var b0: int = clampi(id_c.r8, 0, biome_count - 1)
		var b1: int = clampi(id_c.g8, 0, biome_count - 1)
		var b2: int = clampi(id_c.b8, 0, biome_count - 1)

		biome_weights[b0] += (float(wt_c.r8) / 255.0) * tw
		biome_weights[b1] += (float(wt_c.g8) / 255.0) * tw
		biome_weights[b2] += (float(wt_c.b8) / 255.0) * tw
		barrier_mask += (float(id_c.a8) / 255.0) * tw
		road_mask += (float(wt_c.a8) / 255.0) * tw

	return {
		"biome_weights": biome_weights,
		"barrier_mask": barrier_mask,
		"road_mask": road_mask,
	}


## Renders a top-down 2D debug Image displaying blended biome colors, dark Voronoi borders,
## mountain barrier ridges (orange-red), open Pass Gates (cyan), and Voronoi sites (white rings).
## When `terrain_gen` is provided, also overlays subtle hillshade relief and water/shorelines.
func render_debug_map(
	layout: WorldLayoutData,
	res: int = 256,
	terrain_gen: Variant = null,
	height_scale: float = 1.0,
	barrier_scale: float = 1.0
) -> Image:
	var img := Image.create(res, res, false, Image.FORMAT_RGBA8)
	if layout.regions.is_empty() or layout.biomes.is_empty():
		img.fill(Color(0.14, 0.16, 0.20, 1.0))
		return img

	var half_world: float = layout.world_size * 0.5
	var pixel_world: float = layout.world_size / float(maxi(1, res))
	var border_line_w: float = maxf(2.0, pixel_world * 1.45)

	var use_terrain: bool = terrain_gen != null and terrain_gen.has_method("sample_from_region")
	if use_terrain and terrain_gen.has_method("sync_noise"):
		terrain_gen.sync_noise(layout)

	var heights := PackedFloat32Array()
	var water_ys := PackedFloat32Array()
	var bmasks := PackedFloat32Array()
	var bdists := PackedFloat32Array()
	var base_colors := PackedColorArray()
	if use_terrain:
		var total_px := res * res
		heights.resize(total_px)
		water_ys.resize(total_px)
		bmasks.resize(total_px)
		bdists.resize(total_px)
		base_colors.resize(total_px)

	for py in range(res):
		var z: float = -half_world + (float(py) + 0.5) * pixel_world
		for px in range(res):
			var x: float = -half_world + (float(px) + 0.5) * pixel_world
			var s := sample_at(x, z, layout)
			var bids: Vector3i = s["biome_ids"]
			var wts: Vector3 = s["weights"]

			var c0: Color = layout.biomes[bids.x].debug_color
			var c1: Color = layout.biomes[bids.y].debug_color
			var c2: Color = layout.biomes[bids.z].debug_color
			var col := Color(
				c0.r * wts.x + c1.r * wts.y + c2.r * wts.z,
				c0.g * wts.x + c1.g * wts.y + c2.g * wts.z,
				c0.b * wts.x + c1.b * wts.y + c2.b * wts.z,
				1.0
			)
			var bmask: float = float(s["barrier_mask"])
			var bdist: float = float(s["border_distance"])

			if use_terrain:
				var idx := py * res + px
				var ts: Dictionary = terrain_gen.sample_from_region(x, z, layout, s, height_scale, barrier_scale)
				heights[idx] = float(ts["height"])
				water_ys[idx] = float(ts["water_y"])
				bmasks[idx] = bmask
				bdists[idx] = bdist
				base_colors[idx] = col
			else:
				if bmask > 0.28:
					col = col.lerp(Color(0.92, 0.36, 0.16, 1.0), clampf(bmask * 0.85, 0.0, 0.85))
				if bdist < border_line_w:
					col = col.lerp(Color(0.08, 0.09, 0.12, 1.0), 0.72)
				img.set_pixel(px, py, col)

	if use_terrain:
		var sun_dir := Vector3(-0.55, 0.72, -0.42).normalized()
		var two_step := 2.0 * pixel_world
		for py in range(res):
			var py_u := maxi(0, py - 1)
			var py_d := mini(res - 1, py + 1)
			for px in range(res):
				var px_l := maxi(0, px - 1)
				var px_r := mini(res - 1, px + 1)
				var idx := py * res + px
				var h: float = heights[idx]
				var wy: float = water_ys[idx]
				var col: Color = base_colors[idx]

				var h_l: float = heights[py * res + px_l]
				var h_r: float = heights[py * res + px_r]
				var h_u: float = heights[py_u * res + px]
				var h_d: float = heights[py_d * res + px]
				var n := Vector3(h_l - h_r, two_step, h_u - h_d).normalized()
				var shade: float = lerpf(0.74, 1.22, clampf(n.dot(sun_dir) * 0.85 + 0.35, 0.0, 1.0))

				if h <= wy:
					var depth := clampf((wy - h) / 4.0, 0.0, 1.0)
					var water_col := Color(0.14, 0.44, 0.58, 1.0).lerp(Color(0.08, 0.24, 0.38, 1.0), depth)
					col = col.lerp(water_col, 0.78)
					if wy - h < 0.35:
						col = col.lerp(Color(0.72, 0.88, 0.94, 1.0), 0.45)
				else:
					col = Color(
						clampf(col.r * shade, 0.0, 1.0),
						clampf(col.g * shade, 0.0, 1.0),
						clampf(col.b * shade, 0.0, 1.0),
						1.0
					)

				var bmask: float = bmasks[idx]
				if bmask > 0.28:
					col = col.lerp(Color(0.92, 0.36, 0.16, 1.0), clampf(bmask * 0.65, 0.0, 0.65))
				var bdist: float = bdists[idx]
				if bdist < border_line_w:
					col = col.lerp(Color(0.08, 0.09, 0.12, 1.0), 0.62)

				img.set_pixel(px, py, col)

	# Overlay A* road segments (warm sunlit gold)
	for seg in layout.road_segments:
		for s_i in range(seg.size() - 1):
			_draw_line_2d(img, seg[s_i], seg[s_i + 1], layout.world_size, Color(0.96, 0.80, 0.34, 1.0))

	# Overlay Pass Gates (cyan rings) along barrier borders
	for edge_var in layout.barrier_edges.values():
		var edge: Dictionary = edge_var
		if not bool(edge["has_barrier"]):
			continue
		var pc: Vector2 = edge["pass_center"]
		var pr: float = float(edge["pass_radius"]) * 0.5
		_draw_circle_outline(img, pc, pr, layout.world_size, Color(0.18, 0.92, 0.96, 1.0), 1.6)

	# Overlay Region Center sites (dark outline + white center dot)
	for reg in layout.regions:
		var rc: Vector2 = reg["center"]
		_draw_filled_dot(img, rc, 3, layout.world_size, Color(0.08, 0.08, 0.12, 1.0))
		_draw_filled_dot(img, rc, 2, layout.world_size, Color(0.90, 0.92, 0.96, 1.0))

	# Overlay Landmarks (distinct gold/magenta diamonds)
	for lm_var in layout.landmarks:
		var lm: Dictionary = lm_var
		var lc: Vector2 = lm["center"]
		var pin_col := Color(1.0, 0.86, 0.24, 1.0) if lm.get("kind", &"") == &"city" else (Color(0.94, 0.38, 0.72, 1.0) if lm.get("kind", &"") == &"dungeon" else Color(0.32, 0.94, 0.86, 1.0))
		_draw_filled_dot(img, lc, 5, layout.world_size, Color(0.08, 0.06, 0.10, 1.0))
		_draw_filled_dot(img, lc, 3, layout.world_size, pin_col)

	return img


func _warp_point(x: float, z: float, layout: WorldLayoutData) -> Vector2:
	var ox: float = _warp_x.get_noise_2d(x, z) * layout.warp_strength
	var oz: float = _warp_z.get_noise_2d(x, z) * layout.warp_strength
	return Vector2(x + ox, z + oz)


func _closest_two_sites(p: Vector2, centers: Array[Vector2]) -> Array:
	var id0 := 0
	var id1 := -1
	var d0 := INF
	var d1 := INF
	for i in range(centers.size()):
		var d: float = p.distance_to(centers[i])
		if d < d0:
			d1 = d0
			id1 = id0
			d0 = d
			id0 = i
		elif d < d1:
			d1 = d
			id1 = i
	return [id0, id1, d0, d1]


func _assign_biomes_graph_coloring(
	adj_sets: Array[Dictionary],
	b_count: int,
	region_count: int,
	prevent_adjacent: bool,
	rng: RandomNumberGenerator
) -> Array[int]:
	var assigned: Array[int] = []
	assigned.resize(region_count)
	assigned.fill(-1)
	if b_count <= 0 or region_count <= 0:
		return assigned

	# Order vertices by descending neighbor degree (most constrained regions colored first).
	var order: Array[int] = []
	for i in range(region_count):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var da: int = adj_sets[a].size()
		var db: int = adj_sets[b].size()
		if da == db:
			return a < b
		return da > db
	)

	var usage_counts: Array[int] = []
	usage_counts.resize(b_count)
	usage_counts.fill(0)
	var max_uses: int = maxi(1, ceili(float(region_count) / float(b_count)))

	# Pre-shuffle candidate biome order per depth deterministically so repeated runs stay seeded.
	var cand_orders: Array[Array] = []
	for _d in range(region_count):
		var cands: Array[int] = []
		for b_i in range(b_count):
			cands.append(b_i)
		_shuffle_array_rng(cands, rng)
		cand_orders.append(cands)

	if prevent_adjacent:
		var solved := _solve_biome_coloring(
			0, order, adj_sets, assigned, usage_counts,
			b_count, region_count, max_uses, b_count, cand_orders
		)
		if solved:
			return assigned
		push_warning("RegionGenerator: strict non-adjacent biome coloring impossible with %d biomes for %d regions; relaxing adjacency constraint." % [b_count, region_count])

	# Fallback when prevent_adjacent is false or graph has fewer colors than chromatic number.
	assigned.fill(-1)
	usage_counts.fill(0)
	var require_all: bool = region_count >= b_count
	var unused_cnt: int = b_count
	for depth in range(region_count):
		var u: int = order[depth]
		var rem_after: int = region_count - 1 - depth
		var best_b: int = 0
		var best_score: int = 999999
		for cand_b: int in cand_orders[depth]:
			if usage_counts[cand_b] >= max_uses:
				continue
			var new_unused: int = unused_cnt - (1 if usage_counts[cand_b] == 0 else 0)
			if require_all and new_unused > rem_after:
				continue
			var clashes := 0
			for nb_var in adj_sets[u].keys():
				if assigned[int(nb_var)] == cand_b:
					clashes += 1
			var score: int = clashes * 100 + usage_counts[cand_b] * 10
			if score < best_score:
				best_score = score
				best_b = cand_b
		assigned[u] = best_b
		if usage_counts[best_b] == 0:
			unused_cnt -= 1
		usage_counts[best_b] += 1

	return assigned


func _solve_biome_coloring(
	depth: int,
	order: Array[int],
	adj_sets: Array[Dictionary],
	assigned: Array[int],
	usage_counts: Array[int],
	b_count: int,
	region_count: int,
	max_uses: int,
	unused_count: int,
	cand_orders: Array[Array]
) -> bool:
	if depth >= region_count:
		return true

	var u: int = order[depth]
	var rem_after: int = region_count - 1 - depth
	var require_all: bool = region_count >= b_count

	# Try unused biomes first so every biome is represented cleanly before any repeat.
	var pass_list: Array[int] = []
	for cand_b: int in cand_orders[depth]:
		if usage_counts[cand_b] == 0:
			pass_list.append(cand_b)
	for cand_b: int in cand_orders[depth]:
		if usage_counts[cand_b] > 0:
			pass_list.append(cand_b)

	for cand_b: int in pass_list:
		if usage_counts[cand_b] >= max_uses:
			continue
		var is_unused: bool = (usage_counts[cand_b] == 0)
		var new_unused: int = unused_count - (1 if is_unused else 0)
		if require_all and new_unused > rem_after:
			continue

		var clashes := false
		for nb_var in adj_sets[u].keys():
			if assigned[int(nb_var)] == cand_b:
				clashes = true
				break
		if clashes:
			continue

		assigned[u] = cand_b
		usage_counts[cand_b] += 1
		if _solve_biome_coloring(
			depth + 1, order, adj_sets, assigned, usage_counts,
			b_count, region_count, max_uses, new_unused, cand_orders
		):
			return true
		usage_counts[cand_b] -= 1
		assigned[u] = -1

	return false


static func _inv_smoothstep01(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return 1.0 - (c * c * (3.0 - 2.0 * c))


static func _shuffle_array_rng(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func _world_to_pixel(pos: Vector2, world_size: float, res: int) -> Vector2i:
	var u := clampf((pos.x / world_size) + 0.5, 0.0, 0.9999)
	var v := clampf((pos.y / world_size) + 0.5, 0.0, 0.9999)
	return Vector2i(int(u * res), int(v * res))


static func _draw_line_2d(img: Image, a: Vector2, b: Vector2, world_size: float, col: Color) -> void:
	var res := img.get_width()
	var pa := _world_to_pixel(a, world_size, res)
	var pb := _world_to_pixel(b, world_size, res)
	var steps := maxi(1, maxi(absi(pb.x - pa.x), absi(pb.y - pa.y)))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var px := clampi(int(round(lerpf(float(pa.x), float(pb.x), t))), 0, res - 1)
		var py := clampi(int(round(lerpf(float(pa.y), float(pb.y), t))), 0, res - 1)
		img.set_pixel(px, py, col)


static func _draw_filled_dot(img: Image, world_pos: Vector2, rad_px: int, world_size: float, col: Color) -> void:
	var res := img.get_width()
	var c := _world_to_pixel(world_pos, world_size, res)
	for dy in range(-rad_px, rad_px + 1):
		for dx in range(-rad_px, rad_px + 1):
			if dx * dx + dy * dy <= rad_px * rad_px:
				var px := c.x + dx
				var py := c.y + dy
				if px >= 0 and px < res and py >= 0 and py < res:
					img.set_pixel(px, py, col)


static func _draw_circle_outline(img: Image, world_pos: Vector2, world_rad: float, world_size: float, col: Color, thickness_px: float) -> void:
	var res := img.get_width()
	var c := _world_to_pixel(world_pos, world_size, res)
	var rad_px: int = maxi(4, int((world_rad / world_size) * float(res)))
	var r_min := float(rad_px) - thickness_px * 0.5
	var r_max := float(rad_px) + thickness_px * 0.5
	for dy in range(-rad_px - 2, rad_px + 3):
		for dx in range(-rad_px - 2, rad_px + 3):
			var d := sqrt(float(dx * dx + dy * dy))
			if d >= r_min and d <= r_max:
				var px := c.x + dx
				var py := c.y + dy
				if px >= 0 and px < res and py >= 0 and py < res:
					img.set_pixel(px, py, col)
