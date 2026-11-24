extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/world_generator_demo.tscn")
	if scene == null:
		push_error("Failed to load res://scenes/world_generator_demo.tscn")
		quit(1)
		return

	var root_node := scene.instantiate() as Node3D
	get_root().add_child(root_node)

	# Let _ready() and any deferred regenerate_world() execute cleanly.
	await process_frame
	await process_frame

	var gen := root_node.get_node("WorldGenerator") as WorldGenerator
	if gen == null:
		push_error("Missing WorldGenerator node")
		quit(1)
		return

	var container := gen.get_node_or_null("ChunksContainer") as Node3D
	if container == null:
		push_error("Missing ChunksContainer node")
		quit(1)
		return

	var grid_chunks: int = gen.current_layout.get_grid_chunk_count()
	var expected_chunks: int = grid_chunks * grid_chunks
	if expected_chunks != 64 or container.get_child_count() != 64:
		push_error("Expected 64 chunks for 512m/64m, got expected=%d actual=%d" % [expected_chunks, container.get_child_count()])
		quit(1)
		return

	# Verify no adjacent regions share the same biome
	for r in gen.current_layout.regions:
		var b_idx: int = int(r["biome_index"])
		for nb in r["neighbors"]:
			if int(gen.current_layout.regions[int(nb)]["biome_index"]) == b_idx:
				push_error("Adjacent regions %d and %d share identical biome!" % [int(r["id"]), int(nb)])
				quit(1)
				return

	# 1. Inspect every chunk's mesh, collider, and water
	var subs: int = gen.chunk_subdivisions
	var vert_dim: int = subs + 1
	var water_chunks := 0
	var chunk_map := {}

	for cz in range(grid_chunks):
		for cx in range(grid_chunks):
			var c_node := container.get_node_or_null("Chunk_%d_%d" % [cx, cz]) as Node3D
			if c_node == null:
				push_error("Missing Chunk_%d_%d" % [cx, cz])
				quit(1)
				return
			chunk_map[Vector2i(cx, cz)] = c_node

			var t_mi := c_node.get_node_or_null("TerrainMesh") as MeshInstance3D
			if t_mi == null or t_mi.mesh == null or t_mi.mesh.get_surface_count() == 0:
				push_error("Missing TerrainMesh on Chunk_%d_%d" % [cx, cz])
				quit(1)
				return

			var arrays := t_mi.mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if verts.size() != vert_dim * vert_dim or normals.size() != vert_dim * vert_dim:
				push_error("Unexpected vertex count %d on Chunk_%d_%d" % [verts.size(), cx, cz])
				quit(1)
				return
			if indices.size() != subs * subs * 6:
				push_error("Unexpected index count %d on Chunk_%d_%d" % [indices.size(), cx, cz])
				quit(1)
				return

			var col := c_node.get_node_or_null("TerrainBody/CollisionShape3D") as CollisionShape3D
			if col == null or not (col.shape is HeightMapShape3D):
				push_error("Missing HeightMapShape3D collider on Chunk_%d_%d" % [cx, cz])
				quit(1)
				return
			var hm := col.shape as HeightMapShape3D
			if hm.map_width != vert_dim or hm.map_depth != vert_dim:
				push_error("HeightMapShape3D dims mismatch on Chunk_%d_%d" % [cx, cz])
				quit(1)
				return

			if c_node.get_node_or_null("WaterMesh") != null:
				water_chunks += 1

	if water_chunks == 0:
		push_error("Expected at least one chunk with water mesh (coastal/swamp basins)")
		quit(1)
		return

	# 2. Triangle winding consistency vs SurfaceTool generated normals
	var sample_mi := (chunk_map[Vector2i(0, 0)] as Node3D).get_node("TerrainMesh") as MeshInstance3D
	var st := SurfaceTool.new()
	st.create_from(sample_mi.mesh, 0)
	st.generate_normals()
	var st_mesh := st.commit()
	var manual_norms: PackedVector3Array = sample_mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var gen_norms: PackedVector3Array = st_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var min_dot := 1.0
	for i in range(manual_norms.size()):
		min_dot = minf(min_dot, manual_norms[i].dot(gen_norms[i]))
	if min_dot <= 0.35:
		push_error("Winding/normal orientation mismatch! min_dot=%f (expected positive upward normals matching CW front-face)" % min_dot)
		quit(1)
		return

	# 3. Zero Cross-Chunk Seam Assertion (both East-West and North-South boundaries)
	var max_pos_err := 0.0
	var max_norm_err := 0.0
	for cz in range(grid_chunks):
		for cx in range(grid_chunks):
			var c_a := chunk_map[Vector2i(cx, cz)] as Node3D
			var arr_a := (c_a.get_node("TerrainMesh") as MeshInstance3D).mesh.surface_get_arrays(0)
			var va: PackedVector3Array = arr_a[Mesh.ARRAY_VERTEX]
			var na: PackedVector3Array = arr_a[Mesh.ARRAY_NORMAL]

			if cx + 1 < grid_chunks:
				var c_e := chunk_map[Vector2i(cx + 1, cz)] as Node3D
				var arr_e := (c_e.get_node("TerrainMesh") as MeshInstance3D).mesh.surface_get_arrays(0)
				var ve: PackedVector3Array = arr_e[Mesh.ARRAY_VERTEX]
				var ne: PackedVector3Array = arr_e[Mesh.ARRAY_NORMAL]
				for iz in range(vert_dim):
					var idx_a := iz * vert_dim + subs
					var idx_e := iz * vert_dim + 0
					var wa: Vector3 = c_a.position + va[idx_a]
					var we: Vector3 = c_e.position + ve[idx_e]
					max_pos_err = maxf(max_pos_err, wa.distance_to(we))
					max_norm_err = maxf(max_norm_err, na[idx_a].distance_to(ne[idx_e]))

			if cz + 1 < grid_chunks:
				var c_s := chunk_map[Vector2i(cx, cz + 1)] as Node3D
				var arr_s := (c_s.get_node("TerrainMesh") as MeshInstance3D).mesh.surface_get_arrays(0)
				var vs: PackedVector3Array = arr_s[Mesh.ARRAY_VERTEX]
				var ns: PackedVector3Array = arr_s[Mesh.ARRAY_NORMAL]
				for ix in range(vert_dim):
					var idx_a := subs * vert_dim + ix
					var idx_s := 0 * vert_dim + ix
					var wa: Vector3 = c_a.position + va[idx_a]
					var ws: Vector3 = c_s.position + vs[idx_s]
					max_pos_err = maxf(max_pos_err, wa.distance_to(ws))
					max_norm_err = maxf(max_norm_err, na[idx_a].distance_to(ns[idx_s]))

	if max_pos_err >= 1e-4 or max_norm_err >= 1e-4:
		push_error("Cross-chunk seam detected! max_pos_err=%f max_norm_err=%f" % [max_pos_err, max_norm_err])
		quit(1)
		return

	# 4. Physics collider alignment check via raycast
	await physics_frame
	await physics_frame
	var space_state: PhysicsDirectSpaceState3D = root_node.get_world_3d().direct_space_state
	var ray_tests := [Vector2(-120.0, -80.0), Vector2(0.0, 0.0), Vector2(95.0, 110.0)]
	var max_ray_err := 0.0
	for pt in ray_tests:
		var expected_h: float = gen.terrain_generator.sample_height_only(pt.x, pt.y, gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale)
		var q := PhysicsRayQueryParameters3D.create(Vector3(pt.x, 120.0, pt.y), Vector3(pt.x, -120.0, pt.y))
		var hit: Dictionary = space_state.intersect_ray(q)
		if hit.is_empty():
			push_error("Raycast missed HeightMapShape3D collider at (%f, %f)" % [pt.x, pt.y])
			quit(1)
			return
		var hit_pos: Vector3 = hit["position"]
		var ray_err := absf(hit_pos.y - expected_h)
		max_ray_err = maxf(max_ray_err, ray_err)
	if max_ray_err > 0.35:
		push_error("HeightMapShape3D misaligned with terrain mesh! max_ray_err=%f" % max_ray_err)
		quit(1)
		return

	# 5. Biome elevation differentiation & Pass Gate carving
	var volcanic_peak := -INF
	var plains_or_swamp_mean := 0.0
	var ps_count := 0
	for reg in gen.current_layout.regions:
		var b: BiomeConfig = reg["biome"]
		var rc: Vector2 = reg["center"]
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				var sx := rc.x + float(ox) * 14.0
				var sz := rc.y + float(oy) * 14.0
				var h: float = gen.terrain_generator.sample_height_only(sx, sz, gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale)
				if b.biome_id == &"volcanic_highlands":
					volcanic_peak = maxf(volcanic_peak, h)
				elif b.biome_id == &"coastal_plains" or b.biome_id == &"swamp":
					plains_or_swamp_mean += h
					ps_count += 1

	if ps_count > 0:
		plains_or_swamp_mean /= float(ps_count)
	if volcanic_peak <= plains_or_swamp_mean + 8.0:
		push_error("Biome elevation differentiation too weak: volcanic_peak=%f plains_swamp_mean=%f" % [volcanic_peak, plains_or_swamp_mean])
		quit(1)
		return

	var checked_pass := false
	var max_barrier_h := 0.0
	for edge_var in gen.current_layout.barrier_edges.values():
		var edge: Dictionary = edge_var
		if not bool(edge["has_barrier"]):
			continue
		var pc: Vector2 = edge["pass_center"]
		var s_pass := gen.region_generator.sample_at(pc.x, pc.y, gen.current_layout)
		if float(s_pass["barrier_mask"]) >= 0.01 or float(s_pass["barrier_height"]) >= 0.01:
			push_error("Pass gate not open at pass_center %s: mask=%f h=%f" % [str(pc), float(s_pass["barrier_mask"]), float(s_pass["barrier_height"])])
			quit(1)
			return
		checked_pass = true
	for gz in range(-240, 241, 12):
		for gx in range(-240, 241, 12):
			var rs := gen.region_generator.sample_at(float(gx), float(gz), gen.current_layout)
			max_barrier_h = maxf(max_barrier_h, float(rs["barrier_height"]))

	if not checked_pass or max_barrier_h < 10.0:
		push_error("Barrier ridge / pass gate check failed: checked_pass=%s max_barrier_h=%f" % [str(checked_pass), max_barrier_h])
		quit(1)
		return

	# 5b. Walkable pass slope check: max slope from entrance (-pass_radius) to exit (+pass_radius) < 45 deg
	var max_pass_slope_deg := 0.0
	for ekey_var in gen.current_layout.barrier_edges.keys():
		var ekey: String = str(ekey_var)
		var edge: Dictionary = gen.current_layout.barrier_edges[ekey]
		if not bool(edge["has_barrier"]):
			continue
		var parts := ekey.split(":")
		var id_a: int = int(parts[0])
		var id_b: int = int(parts[1])
		var ca: Vector2 = gen.current_layout.regions[id_a]["center"]
		var cb: Vector2 = gen.current_layout.regions[id_b]["center"]
		var pass_dir: Vector2 = (cb - ca).normalized()
		var pass_center: Vector2 = edge["pass_center"]
		var pass_radius: float = float(edge["pass_radius"])
		var steps: int = int(ceil(pass_radius * 2.0))
		var prev_h: float = gen.terrain_generator.sample_height_only(
			pass_center.x - pass_dir.x * pass_radius,
			pass_center.y - pass_dir.y * pass_radius,
			gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale
		)
		for st_i in range(1, steps + 1):
			var t_dist: float = -pass_radius + float(st_i) * 1.0
			var pt: Vector2 = pass_center + pass_dir * t_dist
			var h_cur: float = gen.terrain_generator.sample_height_only(
				pt.x, pt.y, gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale
			)
			var path_slope_deg := rad_to_deg(atan2(absf(h_cur - prev_h), 1.0))
			max_pass_slope_deg = maxf(max_pass_slope_deg, path_slope_deg)
			prev_h = h_cur

	if max_pass_slope_deg >= 28.0:
		push_error("Pass path exceeds gentle LoL-style slope limit (28 deg): max_pass_slope_deg=%.2f" % max_pass_slope_deg)
		quit(1)
		return

	# 6. Dynamic scaling test (1024m -> 16x16 = 256 chunks, terrain-only check; threaded 1024m navmesh comes in Step 6b)
	gen.enable_navigation = false
	gen.chunk_subdivisions = 32
	gen.world_size = 1024.0
	gen.regenerate_world()
	await process_frame
	if container.get_child_count() != 256:
		push_error("Expected 256 chunks for 1024m world, got %d" % container.get_child_count())
		quit(1)
		return
	var corner_chunk := container.get_node_or_null("Chunk_15_15") as Node3D
	if corner_chunk == null or not corner_chunk.position.is_equal_approx(Vector3(448.0, 0.0, 448.0)):
		push_error("1024m corner chunk placement invalid: %s" % [str(corner_chunk.position) if corner_chunk else "null"])
		quit(1)
		return

	print("STEP2_TERRAIN_VERIFY_CLEAN: 64_chunks=ok water_chunks=%d min_dot=%.4f max_pos_err=%.6f max_norm_err=%.6f max_ray_err=%.4f volcanic_peak=%.2f low_mean=%.2f max_barrier_h=%.2f max_pass_slope=%.2fdeg scale_1024=256_chunks" % [
		water_chunks, min_dot, max_pos_err, max_norm_err, max_ray_err, volcanic_peak, plains_or_swamp_mean, max_barrier_h, max_pass_slope_deg
	])
	quit(0)
