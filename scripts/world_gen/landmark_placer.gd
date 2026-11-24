class_name LandmarkPlacer
extends RefCounted

## Places at least one placeholder landmark per region on dry, low-slope ground
## and routes an 8-connected A* road network connecting all regions through
## mountain Pass Gates, rasterizing fast O(1) road masks & height grids.

const SCENE_CITY_PATH := "res://scenes/landmarks/landmark_city.tscn"
const SCENE_RUINS_PATH := "res://scenes/landmarks/landmark_ruins.tscn"
const SCENE_DUNGEON_PATH := "res://scenes/landmarks/landmark_dungeon.tscn"

const BIOME_TITLES: Dictionary = {
	&"temperate_forest": ["Emerald Haven", "Spirit Blossom Shrine", "Sylvan Hollow"],
	&"coastal_plains": ["Sunshore Citadel", "Harborwatch Ruins", "Tidecrest Vault"],
	&"frozen_tundra": ["Frosthold Bastion", "Glacier Monoliths", "Rimefang Crypt"],
	&"desert": ["Sunspire Oasis", "Sunken Sun Temple", "Scorched Vault"],
	&"swamp": ["Fenwatch Outpost", "Drowned Altar", "Mirefang Crypt"],
	&"volcanic_highlands": ["Cinderfort Keep", "Obsidian Sanctum", "Caldera Gate"],
}


func plan_landmarks_and_roads(
	layout: WorldLayoutData,
	region_gen: RegionGenerator,
	terrain_gen: TerrainGenerator,
	height_scale: float = 1.0,
	barrier_scale: float = 0.60
) -> void:
	if layout == null or layout.regions.is_empty():
		return

	terrain_gen.sync_noise(layout)
	layout.landmarks.clear()
	layout.road_points = PackedVector2Array()
	layout.road_segments.clear()

	_ensure_default_biome_landmarks(layout.biomes)

	var half_world: float = layout.world_size * 0.5
	var safe_bound: float = half_world - 26.0

	# 1. Place 1 dry, low-slope landmark inside every Voronoi region
	var region_landmark_idx: Dictionary = {}
	for r_i in range(layout.regions.size()):
		var reg: Dictionary = layout.regions[r_i]
		var center: Vector2 = reg["center"]
		var biome: BiomeConfig = reg["biome"]

		var best_pos: Vector2 = center.clamp(Vector2(-safe_bound, -safe_bound), Vector2(safe_bound, safe_bound))
		var best_h: float = 0.0
		var best_water: float = layout.sea_level
		var best_score: float = -INF

		var ring_radii: Array[float] = [0.0, 12.0, 24.0, 38.0]
		for rad in ring_radii:
			var ang_steps := 1 if rad < 1.0 else 8
			for a_i in range(ang_steps):
				var ang := float(a_i) * TAU / float(ang_steps)
				var cand := center + Vector2(cos(ang), sin(ang)) * rad
				if absf(cand.x) > safe_bound or absf(cand.y) > safe_bound:
					continue
				var rs := region_gen.sample_at(cand.x, cand.y, layout)
				var bdist: float = float(rs["border_distance"])
				if float(rs["barrier_mask"]) > 0.15:
					continue
				var ts := terrain_gen.sample_from_region(cand.x, cand.y, layout, rs, height_scale, barrier_scale)
				var h: float = float(ts["height"])
				var wy: float = float(ts["water_y"])
				var slope_est: float = _estimate_slope(cand.x, cand.y, layout, region_gen, terrain_gen, height_scale, barrier_scale)

				var dry_bonus: float = 22.0 if h >= wy + 0.5 else -18.0 * clampf(wy - h, 0.0, 4.0)
				var border_bonus: float = minf(bdist, 34.0) * 0.45
				var score: float = dry_bonus + border_bonus - slope_est * 1.4 - rad * 0.12
				if score > best_score:
					best_score = score
					best_pos = cand
					best_h = h
					best_water = wy

		var target_h: float = maxf(best_h, best_water + 1.35)
		var lm_scene: PackedScene = null
		var kind_idx: int = r_i % 3
		if biome != null and not biome.landmark_scenes.is_empty():
			var scene_idx: int = (r_i + int(biome.biome_id.hash())) % biome.landmark_scenes.size()
			lm_scene = biome.landmark_scenes[scene_idx]
			kind_idx = scene_idx

		var kind_name := &"city"
		if lm_scene != null:
			var spath := lm_scene.resource_path
			if spath.contains("ruins"):
				kind_name = &"ruins"
			elif spath.contains("dungeon"):
				kind_name = &"dungeon"

		var title_str := "Outpost %d" % (r_i + 1)
		if biome != null and BIOME_TITLES.has(biome.biome_id):
			var tlist: Array = BIOME_TITLES[biome.biome_id]
			var t_slot: int = 0 if kind_name == &"city" else (1 if kind_name == &"ruins" else 2)
			title_str = str(tlist[t_slot % tlist.size()])

		var flat_r: float = 13.5 if kind_name == &"city" else 11.5
		layout.landmarks.append({
			"region_id": r_i,
			"biome_id": biome.biome_id if biome != null else &"unknown",
			"center": best_pos,
			"target_height": target_h,
			"flatten_radius": flat_r,
			"blend_radius": flat_r + 14.0,
			"clearance_radius": flat_r + 4.5,
			"kind": kind_name,
			"title": title_str,
			"scene": lm_scene,
		})
		region_landmark_idx[r_i] = layout.landmarks.size() - 1

	# 2. Build coarse 8-connected AStar2D navigation graph across the whole world
	var astar_dim: int = 129
	var astar_step: float = layout.world_size / float(astar_dim - 1)
	var astar := AStar2D.new()
	var grid_h := PackedFloat32Array()
	var grid_w := PackedFloat32Array()
	var grid_b := PackedFloat32Array()
	grid_h.resize(astar_dim * astar_dim)
	grid_w.resize(astar_dim * astar_dim)
	grid_b.resize(astar_dim * astar_dim)

	for gz in range(astar_dim):
		var wz := -half_world + float(gz) * astar_step
		for gx in range(astar_dim):
			var wx := -half_world + float(gx) * astar_step
			var idx := gz * astar_dim + gx
			var rs := region_gen.sample_at(wx, wz, layout)
			var ts := terrain_gen.sample_from_region(wx, wz, layout, rs, height_scale, barrier_scale)
			grid_h[idx] = float(ts["height"])
			grid_w[idx] = float(ts["water_y"])
			grid_b[idx] = float(rs["barrier_mask"])

	var two_step := 2.0 * astar_step
	for gz in range(astar_dim):
		var gz_u := maxi(0, gz - 1)
		var gz_d := mini(astar_dim - 1, gz + 1)
		var wz := -half_world + float(gz) * astar_step
		for gx in range(astar_dim):
			var gx_l := maxi(0, gx - 1)
			var gx_r := mini(astar_dim - 1, gx + 1)
			var idx := gz * astar_dim + gx
			var wx := -half_world + float(gx) * astar_step

			var h_c := grid_h[idx]
			var wy := grid_w[idx]
			var bm := grid_b[idx]
			var slope_x := absf(grid_h[gz * astar_dim + gx_r] - grid_h[gz * astar_dim + gx_l]) / two_step
			var slope_z := absf(grid_h[gz_d * astar_dim + gx] - grid_h[gz_u * astar_dim + gx]) / two_step
			var slope_sq := slope_x * slope_x + slope_z * slope_z

			var weight := 1.0 + slope_sq * 20.0 + bm * 110.0
			if h_c < wy + 0.15:
				weight += 42.0 + clampf(wy - h_c, 0.0, 5.0) * 10.0
			astar.add_point(idx, Vector2(wx, wz), weight)

	for gz in range(astar_dim):
		for gx in range(astar_dim):
			var id0 := gz * astar_dim + gx
			if gx + 1 < astar_dim:
				astar.connect_points(id0, gz * astar_dim + (gx + 1), true)
			if gz + 1 < astar_dim:
				astar.connect_points(id0, (gz + 1) * astar_dim + gx, true)
			if gx + 1 < astar_dim and gz + 1 < astar_dim:
				astar.connect_points(id0, (gz + 1) * astar_dim + (gx + 1), true)
			if gx - 1 >= 0 and gz + 1 < astar_dim:
				astar.connect_points(id0, (gz + 1) * astar_dim + (gx - 1), true)

	# 3. Route A* roads along every MST edge and every barrier Pass Gate
	var raw_segments: Array[PackedVector2Array] = []
	for ekey_var in layout.barrier_edges.keys():
		var ekey: String = str(ekey_var)
		var edge: Dictionary = layout.barrier_edges[ekey]
		var is_mst: bool = bool(edge["is_mst"])
		var has_barrier: bool = bool(edge["has_barrier"])
		if not is_mst and not has_barrier:
			continue

		var parts := ekey.split(":")
		var u: int = int(parts[0])
		var v: int = int(parts[1])
		var lm_u: Vector2 = layout.landmarks[region_landmark_idx[u]]["center"]
		var lm_v: Vector2 = layout.landmarks[region_landmark_idx[v]]["center"]

		if has_barrier or is_mst:
			var pass_pt: Vector2 = edge["pass_center"]
			var leg_a := _find_smooth_path(astar, lm_u, pass_pt, layout.world_size, astar_dim)
			var leg_b := _find_smooth_path(astar, pass_pt, lm_v, layout.world_size, astar_dim)
			if has_barrier:
				if not leg_a.is_empty():
					raw_segments.append(leg_a)
				if not leg_b.is_empty():
					raw_segments.append(leg_b)
			else:
				var joined := PackedVector2Array()
				joined.append_array(leg_a)
				for idx_b in range(1, leg_b.size()):
					joined.append(leg_b[idx_b])
				if not joined.is_empty():
					raw_segments.append(joined)
		else:
			var direct := _find_smooth_path(astar, lm_u, lm_v, layout.world_size, astar_dim)
			if not direct.is_empty():
				raw_segments.append(direct)

	layout.road_segments = raw_segments
	var all_pts := PackedVector2Array()
	for seg in raw_segments:
		for pt in seg:
			all_pts.append(pt)
	layout.road_points = all_pts

	# 4. Rasterize O(1) road mask & graded road elevation grids (512x512 = 1m precision)
	_rasterize_road_grids(layout, region_gen, terrain_gen, height_scale, barrier_scale, 512)


func _ensure_default_biome_landmarks(biomes: Array[BiomeConfig]) -> void:
	var city_scn := load(SCENE_CITY_PATH) as PackedScene
	var ruins_scn := load(SCENE_RUINS_PATH) as PackedScene
	var dungeon_scn := load(SCENE_DUNGEON_PATH) as PackedScene

	for b in biomes:
		if b == null or not b.landmark_scenes.is_empty():
			continue
		var list: Array[PackedScene] = []
		match b.biome_id:
			&"temperate_forest", &"coastal_plains":
				if city_scn != null: list.append(city_scn)
				if ruins_scn != null: list.append(ruins_scn)
			&"swamp", &"volcanic_highlands":
				if dungeon_scn != null: list.append(dungeon_scn)
				if ruins_scn != null: list.append(ruins_scn)
			_:
				if ruins_scn != null: list.append(ruins_scn)
				if city_scn != null: list.append(city_scn)
		b.landmark_scenes = list


func _find_smooth_path(astar: AStar2D, from_xz: Vector2, to_xz: Vector2, world_size: float, astar_dim: int) -> PackedVector2Array:
	var id_a := _world_to_astar_id(from_xz, world_size, astar_dim)
	var id_b := _world_to_astar_id(to_xz, world_size, astar_dim)
	var pts := astar.get_point_path(id_a, id_b)
	if pts.size() < 2:
		return PackedVector2Array([from_xz, to_xz])

	pts[0] = from_xz
	pts[pts.size() - 1] = to_xz

	# 2 passes of Chaikin smoothing preserving exact endpoints
	var cur := pts
	for _pass in range(2):
		if cur.size() < 3:
			break
		var next := PackedVector2Array()
		next.append(cur[0])
		for i in range(cur.size() - 1):
			var a := cur[i]
			var b := cur[i + 1]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		next.append(cur[cur.size() - 1])
		cur = next

	return cur


func _rasterize_road_grids(
	layout: WorldLayoutData,
	region_gen: RegionGenerator,
	terrain_gen: TerrainGenerator,
	height_scale: float,
	barrier_scale: float,
	res: int
) -> void:
	layout.road_grid_res = res
	var total := res * res
	var mask_grid := PackedFloat32Array()
	var height_grid := PackedFloat32Array()
	var weight_sum := PackedFloat32Array()
	mask_grid.resize(total)
	height_grid.resize(total)
	weight_sum.resize(total)
	mask_grid.fill(0.0)
	height_grid.fill(0.0)
	weight_sum.fill(0.0)

	var half_world := layout.world_size * 0.5
	var px_step := layout.world_size / float(res - 1)
	var road_inner := 2.6
	var road_outer := 7.8
	var pad_px := ceili(road_outer / px_step) + 1

	for seg in layout.road_segments:
		if seg.size() < 2:
			continue
		var seg_h := PackedFloat32Array()
		seg_h.resize(seg.size())
		for i in range(seg.size()):
			var pt := seg[i]
			seg_h[i] = terrain_gen.sample_height_only(pt.x, pt.y, layout, region_gen, height_scale, barrier_scale)

		# Pin segment ends near landmarks to their exact plaza target_height
		for end_idx in [0, seg.size() - 1]:
			var end_pt := seg[end_idx]
			for lm_var in layout.landmarks:
				var lm: Dictionary = lm_var
				if end_pt.distance_to(lm["center"]) < 6.0:
					seg_h[end_idx] = float(lm["target_height"])
					break

		# Bidirectional longitudinal slope clamp (<= ~22.8 deg) + smoothing passes
		for _pass in range(6):
			for i in range(1, seg.size()):
				var max_dh := seg[i - 1].distance_to(seg[i]) * 0.42
				seg_h[i] = clampf(seg_h[i], seg_h[i - 1] - max_dh, seg_h[i - 1] + max_dh)
			for i in range(seg.size() - 2, -1, -1):
				var max_dh := seg[i].distance_to(seg[i + 1]) * 0.42
				seg_h[i] = clampf(seg_h[i], seg_h[i + 1] - max_dh, seg_h[i + 1] + max_dh)
			var smoothed := seg_h.duplicate()
			for i in range(1, seg.size() - 1):
				smoothed[i] = 0.25 * seg_h[i - 1] + 0.50 * seg_h[i] + 0.25 * seg_h[i + 1]
			seg_h = smoothed

		for i in range(seg.size() - 1):
			var a := seg[i]
			var b := seg[i + 1]
			var ha := seg_h[i]
			var hb := seg_h[i + 1]
			var ab := b - a
			var len_sq := ab.length_squared()

			var min_x := clampi(floori(((minf(a.x, b.x) + half_world) / px_step)) - pad_px, 0, res - 1)
			var max_x := clampi(ceili(((maxf(a.x, b.x) + half_world) / px_step)) + pad_px, 0, res - 1)
			var min_y := clampi(floori(((minf(a.y, b.y) + half_world) / px_step)) - pad_px, 0, res - 1)
			var max_y := clampi(ceili(((maxf(a.y, b.y) + half_world) / px_step)) + pad_px, 0, res - 1)

			for py in range(min_y, max_y + 1):
				var wz := -half_world + float(py) * px_step
				for px in range(min_x, max_x + 1):
					var wx := -half_world + float(px) * px_step
					var t := 0.0
					if len_sq > 0.0001:
						t = clampf((Vector2(wx, wz) - a).dot(ab) / len_sq, 0.0, 1.0)
					var closest := a + ab * t
					var d := Vector2(wx, wz).distance_to(closest)
					if d >= road_outer:
						continue
					var m := 1.0 - smoothstep(road_inner, road_outer, d)
					var idx := py * res + px
					if m > mask_grid[idx]:
						mask_grid[idx] = m
					var w := 1.0 - (d / road_outer)
					w = w * w
					height_grid[idx] += lerpf(ha, hb, t) * w
					weight_sum[idx] += w

	# Blend cobble plaza apron right around each landmark perimeter
	for lm_var in layout.landmarks:
		var lm: Dictionary = lm_var
		var c: Vector2 = lm["center"]
		var th: float = float(lm["target_height"])
		var r_in: float = float(lm["flatten_radius"]) - 1.5
		var r_out: float = float(lm["flatten_radius"]) + 3.2
		var p_pad := ceili(r_out / px_step) + 1
		var cx_px := int(round((c.x + half_world) / px_step))
		var cy_px := int(round((c.y + half_world) / px_step))
		for py in range(maxi(0, cy_px - p_pad), mini(res - 1, cy_px + p_pad) + 1):
			var wz := -half_world + float(py) * px_step
			for px in range(maxi(0, cx_px - p_pad), mini(res - 1, cx_px + p_pad) + 1):
				var wx := -half_world + float(px) * px_step
				var d := Vector2(wx, wz).distance_to(c)
				if d < r_out:
					var m := 1.0 - smoothstep(r_in, r_out, d)
					var idx := py * res + px
					if m > mask_grid[idx]:
						mask_grid[idx] = m
					var w := (1.0 - d / r_out) * 3.0
					w = w * w
					height_grid[idx] += th * w
					weight_sum[idx] += w

	for idx in range(total):
		if weight_sum[idx] > 0.00001:
			height_grid[idx] /= weight_sum[idx]

	layout.road_mask_grid = mask_grid
	layout.road_height_grid = height_grid


static func _world_to_astar_id(pos: Vector2, world_size: float, dim: int) -> int:
	var half := world_size * 0.5
	var gx := clampi(int(round(((pos.x + half) / maxf(1.0, world_size)) * float(dim - 1))), 0, dim - 1)
	var gz := clampi(int(round(((pos.y + half) / maxf(1.0, world_size)) * float(dim - 1))), 0, dim - 1)
	return gz * dim + gx


static func _estimate_slope(
	wx: float,
	wz: float,
	layout: WorldLayoutData,
	region_gen: RegionGenerator,
	terrain_gen: TerrainGenerator,
	height_scale: float,
	barrier_scale: float
) -> float:
	var eps := 3.0
	var hl := terrain_gen.sample_height_only(wx - eps, wz, layout, region_gen, height_scale, barrier_scale)
	var hr := terrain_gen.sample_height_only(wx + eps, wz, layout, region_gen, height_scale, barrier_scale)
	var hu := terrain_gen.sample_height_only(wx, wz - eps, layout, region_gen, height_scale, barrier_scale)
	var hd := terrain_gen.sample_height_only(wx, wz + eps, layout, region_gen, height_scale, barrier_scale)
	var dx := (hr - hl) / (2.0 * eps)
	var dz := (hd - hu) / (2.0 * eps)
	return rad_to_deg(atan(sqrt(dx * dx + dz * dz)))
