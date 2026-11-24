extends SceneTree

const NavTestPlayerScript := preload("res://scripts/world_gen/nav_test_player.gd")

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
	await physics_frame
	await process_frame
	await physics_frame

	var gen := root_node.get_node("WorldGenerator") as WorldGenerator
	if gen == null or gen.current_layout == null:
		push_error("Missing WorldGenerator or layout")
		quit(1)
		return

	var container := gen.get_node_or_null("ChunksContainer") as Node3D
	if container == null or container.get_child_count() != 64:
		push_error("Expected 64 chunks")
		quit(1)
		return

	var map_rid: RID = root_node.get_world_3d().navigation_map
	NavigationServer3D.map_set_active(map_rid, true)
	var lm0_c: Vector2 = gen.current_layout.landmarks[0]["center"]
	var lm0_raw := Vector3(lm0_c.x, float(gen.current_layout.landmarks[0]["target_height"]), lm0_c.y + 5.0)
	for _sync_step in range(15):
		await process_frame
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(map_rid) > 0 and NavigationServer3D.map_get_closest_point_owner(map_rid, lm0_raw).is_valid():
			break
	if not NavigationServer3D.map_get_closest_point_owner(map_rid, lm0_raw).is_valid():
		push_error("NavigationServer3D map failed to synchronize within 15 frames (iter=%d)" % NavigationServer3D.map_get_iteration_id(map_rid))
		quit(1)
		return

	# 1. Verify every chunk has a ChunkNavRegion with border_size + filter_baking_aabb & clean local crop bounds
	var nav_regions := 0
	var total_polys := 0
	var chunk_len := float(gen.chunk_size)
	for c_node in container.get_children():
		var nr := c_node.get_node_or_null("ChunkNavRegion") as NavigationRegion3D
		if nr == null or nr.navigation_mesh == null:
			push_error("%s missing ChunkNavRegion or NavigationMesh" % c_node.name)
			quit(1)
			return
		var nm := nr.navigation_mesh
		if nm.border_size <= 0.0 or not nm.filter_baking_aabb.has_volume():
			push_error("%s NavigationMesh missing border_size or filter_baking_aabb" % c_node.name)
			quit(1)
			return
		if nm.get_polygon_count() <= 0:
			push_error("%s NavigationMesh baked 0 polygons" % c_node.name)
			quit(1)
			return
		for v in nm.get_vertices():
			if v.x < -0.05 or v.x > chunk_len + 0.05 or v.z < -0.05 or v.z > chunk_len + 0.05:
				push_error("%s NavigationMesh vertex %s outside chunk bounds [0, %.1f]" % [c_node.name, str(v), chunk_len])
				quit(1)
				return
		nav_regions += 1
		total_polys += nm.get_polygon_count()

	# 2. Verify a continuous path exists between EVERY pair of landmarks across regions
	var lm_count := gen.current_layout.landmarks.size()
	var total_pairs := 0
	var max_chunks_crossed := 0
	for i in range(lm_count):
		var pt_i := gen.get_landmark_nav_point(i)
		for j in range(i + 1, lm_count):
			var pt_j := gen.get_landmark_nav_point(j)
			var path := gen.find_navigation_path(pt_i, pt_j, true)
			if path.size() < 2:
				push_error("No navmesh path between landmark %d (%s) and %d (%s)" % [i, str(pt_i), j, str(pt_j)])
				quit(1)
				return
			var err_start := path[0].distance_to(pt_i)
			var err_end := path[path.size() - 1].distance_to(pt_j)
			if err_start > 1.5 or err_end > 1.5:
				push_error("Disconnected landmark path %d->%d: start_err=%.2f end_err=%.2f" % [i, j, err_start, err_end])
				quit(1)
				return

			var chunks_seen := {}
			var half_w := gen.world_size * 0.5
			for p in path:
				var cx := clampi(floori((p.x + half_w) / chunk_len), 0, 7)
				var cz := clampi(floori((p.z + half_w) / chunk_len), 0, 7)
				chunks_seen[Vector2i(cx, cz)] = true
			max_chunks_crossed = maxi(max_chunks_crossed, chunks_seen.size())
			total_pairs += 1

	if max_chunks_crossed < 3:
		push_error("Expected long landmark paths to cross >= 3 chunks, max=%d" % max_chunks_crossed)
		quit(1)
		return

	# 3. Verify explicit cross-border paths across shared chunk seams without gaps (X seam & Z seam)
	var border_tests_passed := 0
	var seam_coords := [-128.0, -64.0, 0.0, 64.0, 128.0]
	for seam_x in seam_coords:
		if border_tests_passed >= 2:
			break
		for sample_z in range(-180, 181, 24):
			var p_left := Vector3(seam_x - 12.0, 0.0, float(sample_z))
			var p_right := Vector3(seam_x + 12.0, 0.0, float(sample_z))
			p_left.y = gen.terrain_generator.sample_height_only(p_left.x, p_left.z, gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale)
			p_right.y = gen.terrain_generator.sample_height_only(p_right.x, p_right.z, gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale)
			var c_left := NavigationServer3D.map_get_closest_point(map_rid, p_left)
			var c_right := NavigationServer3D.map_get_closest_point(map_rid, p_right)
			if c_left.distance_to(p_left) < 1.2 and c_right.distance_to(p_right) < 1.2:
				var seam_path := NavigationServer3D.map_get_path(map_rid, c_left, c_right, true)
				if seam_path.size() >= 2 and seam_path[seam_path.size() - 1].distance_to(c_right) < 0.6:
					var plen := _polyline_length_xz(seam_path)
					if plen < 42.0:
						border_tests_passed += 1
						break

	for seam_z in seam_coords:
		if border_tests_passed >= 4:
			break
		for sample_x in range(-180, 181, 24):
			var p_up := Vector3(float(sample_x), 0.0, seam_z - 12.0)
			var p_dn := Vector3(float(sample_x), 0.0, seam_z + 12.0)
			p_up.y = gen.terrain_generator.sample_height_only(p_up.x, p_up.z, gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale)
			p_dn.y = gen.terrain_generator.sample_height_only(p_dn.x, p_dn.z, gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale)
			var c_up := NavigationServer3D.map_get_closest_point(map_rid, p_up)
			var c_dn := NavigationServer3D.map_get_closest_point(map_rid, p_dn)
			if c_up.distance_to(p_up) < 1.2 and c_dn.distance_to(p_dn) < 1.2:
				var seam_path := NavigationServer3D.map_get_path(map_rid, c_up, c_dn, true)
				if seam_path.size() >= 2 and seam_path[seam_path.size() - 1].distance_to(c_dn) < 0.6:
					var plen := _polyline_length_xz(seam_path)
					if plen < 42.0:
						border_tests_passed += 1
						break

	if border_tests_passed < 4:
		push_error("Cross-chunk border path verification insufficient: %d/4" % border_tests_passed)
		quit(1)
		return

	# 4. Verify paths go around trees/rocks (navmesh carves obstacles + path deflects laterally)
	var obs_verified := false
	var obs_clearance := 0.0
	var obs_deflect := 0.0
	for c_node in container.get_children():
		if obs_verified:
			break
		var body := c_node.get_node_or_null("TerrainBody") as StaticBody3D
		if body == null:
			continue
		for cs_var in body.get_children():
			var cs := cs_var as CollisionShape3D
			if cs == null or not (cs.shape is CylinderShape3D):
				continue
			var cyl := cs.shape as CylinderShape3D
			if cyl.radius < 0.65:
				continue
			var obs_world := (c_node as Node3D).position + Vector3(cs.position.x, 0.0, cs.position.z)
			obs_world.y = gen.terrain_generator.sample_height_only(
				obs_world.x, obs_world.z, gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale
			)
			# Ensure obstacle carved a hole at its center
			var center_snap := NavigationServer3D.map_get_closest_point(map_rid, obs_world)
			var center_push := Vector2(center_snap.x - obs_world.x, center_snap.z - obs_world.z).length()
			if center_push < cyl.radius * 0.65:
				continue

			var side_a := Vector3(obs_world.x - 4.5, 0.0, obs_world.z)
			var side_b := Vector3(obs_world.x + 4.5, 0.0, obs_world.z)
			side_a.y = gen.terrain_generator.sample_height_only(side_a.x, side_a.z, gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale)
			side_b.y = gen.terrain_generator.sample_height_only(side_b.x, side_b.z, gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale)
			var snap_a := NavigationServer3D.map_get_closest_point(map_rid, side_a)
			var snap_b := NavigationServer3D.map_get_closest_point(map_rid, side_b)
			if snap_a.distance_to(side_a) > 1.2 or snap_b.distance_to(side_b) > 1.2:
				continue

			var obs_path := NavigationServer3D.map_get_path(map_rid, snap_a, snap_b, true)
			if obs_path.size() < 3 or obs_path[obs_path.size() - 1].distance_to(snap_b) > 1.2:
				continue

			var min_seg_d := _min_distance_polyline_to_point_xz(obs_path, Vector2(obs_world.x, obs_world.z))
			var max_lat_z := 0.0
			for pt in obs_path:
				max_lat_z = maxf(max_lat_z, absf(pt.z - obs_world.z))
			if min_seg_d >= cyl.radius * 0.65 and max_lat_z >= cyl.radius * 0.55:
				obs_verified = true
				obs_clearance = min_seg_d
				obs_deflect = max_lat_z
				break

	if not obs_verified:
		push_error("Failed verifying navmesh detour around scattered tree/rock cylinder collider")
		quit(1)
		return

	# 5. Verify NavTestPlayer (~1.8m capsule) + NavigationAgent3D movement + Camera Rig follow/free toggle
	var player := gen.get_node_or_null("TestPlayer") as NavTestPlayerScript
	var rig := root_node.get_node_or_null("IsometricCameraRig") as IsometricCameraRig
	if player == null or rig == null:
		push_error("Missing TestPlayer or IsometricCameraRig")
		quit(1)
		return

	var p_col := player.get_node_or_null("PlayerCollider") as CollisionShape3D
	var p_nav := player.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if p_col == null or not (p_col.shape is CapsuleShape3D) or p_nav == null:
		push_error("TestPlayer missing 1.8m CapsuleShape3D or NavigationAgent3D")
		quit(1)
		return
	var cap_h := (p_col.shape as CapsuleShape3D).height
	if absf(cap_h - 1.80) > 0.25:
		push_error("Expected ~1.8m capsule player, got height=%.2f" % cap_h)
		quit(1)
		return

	var start_p := player.global_position
	var goal_pt := gen.get_landmark_nav_point(1)
	if goal_pt.distance_to(start_p) < 12.0 and lm_count > 2:
		goal_pt = gen.get_landmark_nav_point(2)
	player.move_to_world_position(goal_pt)
	for _s in range(30):
		await physics_frame
		await process_frame

	var moved_dist := Vector2(player.global_position.x - start_p.x, player.global_position.z - start_p.z).length()
	if moved_dist < 2.2:
		push_error("TestPlayer did not advance along NavigationAgent3D path: moved=%.2fm" % moved_dist)
		quit(1)
		return

	var cam_follow_dist := Vector2(rig.global_position.x - player.global_position.x, rig.global_position.z - player.global_position.z).length()
	if not rig.follow_player or cam_follow_dist > 3.5:
		push_error("Camera rig failed to follow TestPlayer: follow=%s dist=%.2fm" % [str(rig.follow_player), cam_follow_dist])
		quit(1)
		return

	rig.toggle_follow_mode()
	if rig.follow_player:
		push_error("toggle_follow_mode() did not switch camera to free mode")
		quit(1)
		return
	rig.toggle_follow_mode()

	player.stop_movement()
	rig.follow_player = true
	rig.set_follow_target(player, true)
	rig.zoom_distance = 32.0
	await process_frame
	var click_start := player.global_position
	var click_ev := InputEventMouseButton.new()
	click_ev.button_index = MOUSE_BUTTON_RIGHT
	click_ev.pressed = true
	click_ev.position = Vector2(760.0, 420.0)
	get_root().push_input(click_ev)
	await process_frame
	await physics_frame
	if not player.is_moving():
		push_error("Right-click input event did not start TestPlayer movement")
		quit(1)
		return
	var click_rel := InputEventMouseButton.new()
	click_rel.button_index = MOUSE_BUTTON_RIGHT
	click_rel.pressed = false
	click_rel.position = Vector2(760.0, 420.0)
	get_root().push_input(click_rel)
	for _c in range(14):
		await physics_frame
		await process_frame
	var click_moved := Vector2(player.global_position.x - click_start.x, player.global_position.z - click_start.z).length()
	if click_moved < 1.0:
		push_error("TestPlayer did not move after right-click input: moved=%.2fm" % click_moved)
		quit(1)
		return

	# 6. Gameplay zoom range benchmark (14m, 35m, 65m) + overview (780m) on Metal
	var bench_str := "headless_skipped"
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		rig.follow_player = true
		var zoom_levels := [14.0, 35.0, 65.0, 780.0]
		var zoom_results := PackedStringArray()
		for z_val in zoom_levels:
			if z_val > 100.0:
				rig.follow_player = false
				rig.global_position = Vector3.ZERO
			else:
				rig.follow_player = true
			rig.zoom_distance = z_val
			for _w in range(6):
				await process_frame
			var t0 := Time.get_ticks_usec()
			for _f in range(20):
				await process_frame
			var ms_avg := float(Time.get_ticks_usec() - t0) / 20000.0
			var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			zoom_results.append("%.0fm=%.2fms(%dd)" % [z_val, ms_avg, draws])
		bench_str = ",".join(zoom_results)

	print("STEP6A_NAVIGATION_VERIFY_CLEAN: nav_regions=%d polys=%d landmark_pairs=%d/%d max_chunks_crossed=%d border_crossings=%d obs_clear=%.2fm obs_deflect=%.2fm player_moved=%.2fm zoom_bench=[%s]" % [
		nav_regions, total_polys, total_pairs, lm_count * (lm_count - 1) / 2, max_chunks_crossed, border_tests_passed, obs_clearance, obs_deflect, moved_dist, bench_str
	])
	quit(0)


static func _polyline_length_xz(pts: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(pts.size() - 1):
		total += Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).length()
	return total


static func _min_distance_polyline_to_point_xz(pts: PackedVector3Array, p: Vector2) -> float:
	var best := INF
	for i in range(pts.size() - 1):
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[i + 1].x, pts[i + 1].z)
		var ab := b - a
		var lsq := ab.length_squared()
		var t := 0.0 if lsq < 0.0001 else clampf((p - a).dot(ab) / lsq, 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best
