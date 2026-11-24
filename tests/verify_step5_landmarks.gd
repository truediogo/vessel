extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/world_generator_demo.tscn")
	if scene == null:
		push_error("Failed loading demo scene")
		quit(1)
		return

	var root_node := scene.instantiate() as Node3D
	get_root().add_child(root_node)
	await process_frame
	await process_frame

	var gen := root_node.get_node("WorldGenerator") as WorldGenerator
	if gen == null or gen.current_layout == null:
		push_error("Missing WorldGenerator or current_layout")
		quit(1)
		return

	var layout := gen.current_layout
	var reg_count := layout.regions.size()

	# 1. Every region has at least one landmark, instantiated with a visible Label3D & flat pad
	if layout.landmarks.size() < reg_count:
		push_error("Expected >= %d landmarks (one per region), got %d" % [reg_count, layout.landmarks.size()])
		quit(1)
		return

	var covered_regions := {}
	var container := gen.get_node_or_null("ChunksContainer") as Node3D
	var instantiated_landmarks := 0
	var visible_labels := 0
	for c_node in container.get_children():
		var lc := c_node.get_node_or_null("LandmarksContainer") as Node3D
		if lc != null:
			for lm_inst in lc.get_children():
				instantiated_landmarks += 1
				var lbl := lm_inst.get_node_or_null("LandmarkTitleLabel") as Label3D
				if lbl != null and lbl.visible and not lbl.text.is_empty():
					visible_labels += 1

	if instantiated_landmarks != layout.landmarks.size() or visible_labels != layout.landmarks.size():
		push_error("Landmark instantiation/Label3D mismatch: inst=%d labels=%d expected=%d" % [
			instantiated_landmarks, visible_labels, layout.landmarks.size()
		])
		quit(1)
		return

	var max_pad_diff := 0.0
	for lm_var in layout.landmarks:
		var lm: Dictionary = lm_var
		covered_regions[int(lm["region_id"])] = true
		var lc_pos: Vector2 = lm["center"]
		var target_h: float = float(lm["target_height"])
		var sample_r: float = float(lm["flatten_radius"]) * 0.65
		for ang_i in range(6):
			var a := float(ang_i) * TAU / 6.0
			var pt := lc_pos + Vector2(cos(a), sin(a)) * sample_r
			var h := gen.terrain_generator.sample_height_only(pt.x, pt.y, layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale)
			max_pad_diff = maxf(max_pad_diff, absf(h - target_h))

	if covered_regions.size() != reg_count:
		push_error("Not all regions have a landmark: %d/%d" % [covered_regions.size(), reg_count])
		quit(1)
		return
	if max_pad_diff >= 0.30:
		push_error("Landmark pad not flat enough: max_pad_diff=%.3fm" % max_pad_diff)
		quit(1)
		return

	# 2. A* roads connect all regions and pass near every barrier Pass Gate
	if layout.road_segments.is_empty():
		push_error("No A* road segments generated!")
		quit(1)
		return

	# Check pass gate proximity
	for edge_var in layout.barrier_edges.values():
		var edge: Dictionary = edge_var
		if not bool(edge["has_barrier"]):
			continue
		var pc: Vector2 = edge["pass_center"]
		var min_d := INF
		for rp in layout.road_points:
			min_d = minf(min_d, rp.distance_to(pc))
		if min_d > 8.5:
			push_error("No road routed through barrier Pass Gate %s (min_d=%.2fm)" % [str(pc), min_d])
			quit(1)
			return

	# Verify road graph reaches all landmarks via BFS over endpoint adjacency
	var lm_adj := {}
	for i in range(layout.landmarks.size()):
		lm_adj[i] = []
	for seg in layout.road_segments:
		if seg.size() < 2:
			continue
		var u := _nearest_landmark(seg[0], layout.landmarks)
		var v := _nearest_landmark(seg[seg.size() - 1], layout.landmarks)
		if u != -1 and v != -1 and u != v:
			lm_adj[u].append(v)
			lm_adj[v].append(u)
	# Notice barrier segments split at pass_center -> match two legs meeting at pass_center
	for edge_var in layout.barrier_edges.values():
		var edge: Dictionary = edge_var
		if not bool(edge["has_barrier"]):
			continue
		var pc: Vector2 = edge["pass_center"]
		var connected_lms: Array[int] = []
		for seg in layout.road_segments:
			if seg.size() < 2:
				continue
			if seg[seg.size() - 1].distance_to(pc) < 6.0:
				var lm_i := _nearest_landmark(seg[0], layout.landmarks)
				if lm_i != -1 and not connected_lms.has(lm_i):
					connected_lms.append(lm_i)
			elif seg[0].distance_to(pc) < 6.0:
				var lm_j := _nearest_landmark(seg[seg.size() - 1], layout.landmarks)
				if lm_j != -1 and not connected_lms.has(lm_j):
					connected_lms.append(lm_j)
		for a_i in connected_lms:
			for b_i in connected_lms:
				if a_i != b_i:
					lm_adj[a_i].append(b_i)

	var visited := {0: true}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nb in lm_adj[cur]:
			if not visited.has(nb):
				visited[nb] = true
				queue.append(nb)
	if visited.size() != layout.landmarks.size():
		push_error("Road network failed to connect all region landmarks (%d/%d)" % [visited.size(), layout.landmarks.size()])
		quit(1)
		return

	# 3. Control map weight_image alpha channel paints road_mask > 0.5 along road points
	var max_road_alpha := 0.0
	var test_pt := layout.road_points[layout.road_points.size() / 2]
	var half_w := layout.world_size * 0.5
	var cx := clampi(floori((test_pt.x + half_w) / float(layout.chunk_size)), 0, layout.get_grid_chunk_count() - 1)
	var cz := clampi(floori((test_pt.y + half_w) / float(layout.chunk_size)), 0, layout.get_grid_chunk_count() - 1)
	var c_maps := gen.region_generator.build_chunk_control_maps(Vector2i(cx, cz), gen.control_map_resolution, layout)
	var wt_img: Image = c_maps["weight_image"]
	for py in range(wt_img.get_height()):
		for px in range(wt_img.get_width()):
			max_road_alpha = maxf(max_road_alpha, float(wt_img.get_pixel(px, py).a8) / 255.0)
	if max_road_alpha < 0.5:
		push_error("Chunk control map road_mask alpha missing along road chunk (%d,%d): max=%.2f" % [cx, cz, max_road_alpha])
		quit(1)
		return

	# 4. Zero scattered props overlap landmark footprints or road centerlines
	var merged_sc := gen.get_node_or_null("MergedScatterContainer") as Node3D
	if merged_sc == null:
		push_error("Missing MergedScatterContainer")
		quit(1)
		return
	for cell_node in merged_sc.get_children():
		var cell_pos := (cell_node as Node3D).position
		for mmi_var in cell_node.get_children():
			var mmi := mmi_var as MultiMeshInstance3D
			if mmi == null or mmi.multimesh == null:
				continue
			for idx in range(mmi.multimesh.instance_count):
				var wp := cell_pos + mmi.multimesh.get_instance_transform(idx).origin
				var wp2 := Vector2(wp.x, wp.z)
				for lm_var in layout.landmarks:
					var lm: Dictionary = lm_var
					if wp2.distance_to(lm["center"]) < float(lm["flatten_radius"]) - 0.1:
						push_error("Scattered prop inside landmark footprint at %s" % str(wp2))
						quit(1)
						return
				if layout.sample_road_mask(wp.x, wp.z) > 0.35:
					push_error("Scattered prop inside road centerline at %s (mask=%.2f)" % [str(wp2), layout.sample_road_mask(wp.x, wp.z)])
					quit(1)
					return

	# 5. Navigation-blocking CylinderShape3D colliders exist on chunk TerrainBody nodes
	var cyl_colliders := 0
	for c_node in container.get_children():
		var body := c_node.get_node_or_null("TerrainBody") as StaticBody3D
		if body == null:
			continue
		for cs in body.get_children():
			if cs is CollisionShape3D and (cs as CollisionShape3D).shape is CylinderShape3D:
				cyl_colliders += 1
	if cyl_colliders < 100:
		push_error("Expected >= 100 navigation-blocking CylinderShape3D colliders, got %d" % cyl_colliders)
		quit(1)
		return

	# 6. Live Metal draw call & frame-time check
	var perf_info := "headless"
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var rig := root_node.get_node_or_null("IsometricCameraRig") as IsometricCameraRig
		if rig != null:
			rig.global_position = Vector3.ZERO
			rig.zoom_distance = 140.0
			for _w in range(5):
				await process_frame
			var t0 := Time.get_ticks_usec()
			for _f in range(15):
				await process_frame
			var near_ms := float(Time.get_ticks_usec() - t0) / 15000.0
			var draws_near := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)

			rig.zoom_distance = 780.0
			for _w2 in range(5):
				await process_frame
			var draws_far := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)

			if draws_near >= 780:
				push_error("Merged 2x2 MultiMesh did not reduce close-up draw calls below 780: got %d" % draws_near)
				quit(1)
				return
			perf_info = "draws_near=%d draws_far=%d near_ms=%.2f" % [draws_near, draws_far, near_ms]

	print("STEP5_LANDMARKS_VERIFY_CLEAN: landmarks=%d labels=%d max_pad_diff=%.3f roads=%d road_alpha=%.2f cyl_colliders=%d %s" % [
		layout.landmarks.size(), visible_labels, max_pad_diff, layout.road_segments.size(), max_road_alpha, cyl_colliders, perf_info
	])
	quit(0)


static func _nearest_landmark(pt: Vector2, landmarks: Array[Dictionary]) -> int:
	var best_i := -1
	var best_d := 22.0
	for i in range(landmarks.size()):
		var d := pt.distance_to(landmarks[i]["center"])
		if d < best_d:
			best_d = d
			best_i = i
	return best_i
