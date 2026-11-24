extends SceneTree

const NavTestPlayerScript := preload("res://scripts/world_gen/nav_test_player.gd")

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/world_generator_demo.tscn")
	var root_node := scene.instantiate() as Node3D
	get_root().add_child(root_node)

	await process_frame
	await physics_frame
	await process_frame
	await physics_frame

	var gen := root_node.get_node("WorldGenerator") as WorldGenerator
	var rig := root_node.get_node("IsometricCameraRig") as IsometricCameraRig
	var player := gen.get_node_or_null("TestPlayer") as NavTestPlayerScript
	if gen == null or rig == null or player == null:
		push_error("Missing WorldGenerator, IsometricCameraRig, or TestPlayer")
		quit(1)
		return

	var map_rid := root_node.get_world_3d().navigation_map
	NavigationServer3D.map_set_active(map_rid, true)
	var lm0_c: Vector2 = gen.current_layout.landmarks[0]["center"]
	var lm0_raw := Vector3(lm0_c.x, float(gen.current_layout.landmarks[0]["target_height"]), lm0_c.y + 5.0)
	for _sync_step in range(15):
		await process_frame
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(map_rid) > 0 and NavigationServer3D.map_get_closest_point_owner(map_rid, lm0_raw).is_valid():
			break

	# 1. Gameplay zoom (34m) showing player moving along road out of starting landmark plaza
	var goal_pt := gen.get_landmark_nav_point(1)
	if not gen.current_layout.road_segments.is_empty():
		var seg0: PackedVector2Array = gen.current_layout.road_segments[0]
		var idx0 := mini(seg0.size() - 1, 10)
		var pt0 := seg0[idx0]
		var h0 := gen.terrain_generator.sample_height_only(
			pt0.x, pt0.y, gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale
		)
		goal_pt = Vector3(pt0.x, h0, pt0.y)
	player.move_to_world_position(goal_pt)
	for _s in range(10):
		await physics_frame
		await process_frame

	rig.follow_player = true
	rig.set_follow_target(player, true)
	rig.zoom_distance = 34.0
	for _w in range(4):
		await process_frame
	RenderingServer.force_draw(true, 0.016)

	var out_main := "/Users/diogo.silva/OpenBot/Agents/agent-0f47a086-7b1c-416a-86ce-7cb8de846218/project-vessel/concepts/world-gen-step6a-gameplay.png"
	get_root().get_viewport().get_texture().get_image().save_png(out_main)

	# 2. Close-up gameplay zoom (16m) over cobblestone road verge to verify softened edges & target marker
	if not gen.current_layout.road_segments.is_empty():
		var seg: PackedVector2Array = gen.current_layout.road_segments[0]
		var mid_idx := seg.size() / 2
		var mid_pt := seg[mid_idx]
		var h_mid := gen.terrain_generator.sample_height_only(
			mid_pt.x, mid_pt.y, gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale
		)
		var road_pos := Vector3(mid_pt.x, h_mid, mid_pt.y)
		var road_snap := NavigationServer3D.map_get_closest_point(map_rid, road_pos)
		player.stop_movement()
		player.global_position = road_snap + Vector3(0.0, 0.1, 0.0)
		var next_pt := seg[mini(seg.size() - 1, mid_idx + 6)]
		var h_next := gen.terrain_generator.sample_height_only(
			next_pt.x, next_pt.y, gen.current_layout, gen.region_generator, gen.height_scale, gen.barrier_height_scale
		)
		player.move_to_world_position(Vector3(next_pt.x, h_next, next_pt.y))
		for _k in range(4):
			await physics_frame
			await process_frame

	rig.follow_player = true
	rig.set_follow_target(player, true)
	rig.zoom_distance = 16.0
	for _j in range(4):
		await process_frame
	RenderingServer.force_draw(true, 0.016)

	var out_close := "/Users/diogo.silva/OpenBot/Agents/agent-0f47a086-7b1c-416a-86ce-7cb8de846218/project-vessel/concepts/world-gen-step6a-road-closeup.png"
	get_root().get_viewport().get_texture().get_image().save_png(out_close)

	print("STEP6A_CAPTURE_DONE")
	quit(0)
