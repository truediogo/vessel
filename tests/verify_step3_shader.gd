extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var biomes: Array[BiomeConfig] = []
	for path in WorldGenerator.DEFAULT_BIOME_PATHS:
		var b := load(path) as BiomeConfig
		if b == null:
			push_error("Failed loading biome: %s" % path)
			quit(1)
			return
		biomes.append(b)

	# 1. Verify all 24 procedural painted placeholder textures (6 biomes x 4 layers) generate with real paint detail
	for b in biomes:
		for slot_idx in range(4):
			var img := BiomeConfig.generate_painterly_placeholder_image(b.biome_id, slot_idx, 128)
			if img == null or img.get_width() != 128 or img.get_height() != 128:
				push_error("Failed generating placeholder image for %s slot %d" % [b.biome_id, slot_idx])
				quit(1)
				return
			var c_min := 1.0
			var c_max := 0.0
			for py in range(0, 128, 8):
				for px in range(0, 128, 8):
					var lum := img.get_pixel(px, py).get_luminance()
					c_min = minf(c_min, lum)
					c_max = maxf(c_max, lum)
			if c_max - c_min < 0.04:
				push_error("Placeholder image for %s slot %d looks flat (lum range %.4f..%.4f)" % [b.biome_id, slot_idx, c_min, c_max])
				quit(1)
				return

	# 2. Verify mobile ETC2 path builds cleanly in memory without touching saved desktop .res files
	var etc_res := BiomeConfig.build_validated_texture_arrays(
		biomes, 128, true, BiomeConfig.CompressionTarget.MOBILE_ETC2
	)
	if not etc_res["errors"].is_empty() or etc_res.get("layer0") == null:
		push_error("MOBILE_ETC2 validation failed: %s" % str(etc_res["errors"]))
		quit(1)
		return

	# 3. Verify custom texture override path (use_procedural_placeholder_textures = false)
	var custom_biome := biomes[0].duplicate() as BiomeConfig
	custom_biome.use_procedural_placeholder_textures = false
	var custom_arr: Array[BiomeConfig] = [custom_biome]
	var custom_res := BiomeConfig.build_validated_texture_arrays(
		custom_arr, 128, true, BiomeConfig.CompressionTarget.DESKTOP_S3TC
	)
	if not custom_res["errors"].is_empty() or custom_res.get("layer0") == null:
		push_error("Custom texture override build failed: %s" % str(custom_res["errors"]))
		quit(1)
		return

	# 4. Bake desktop compressed Texture2DArrays when running on a live GPU renderer (Metal),
	#    then instantiate the full demo scene and check every chunk's ShaderMaterial bindings.
	if DisplayServer.get_name() != "headless":
		var bake_res := BiomeConfig.bake_and_save_texture_arrays(
			biomes, "res://resources/biomes/compiled", 512, BiomeConfig.CompressionTarget.DESKTOP_S3TC
		)
		if not bake_res["errors"].is_empty():
			push_error("Failed baking Texture2DArrays: %s" % str(bake_res["errors"]))
			quit(1)
			return

	var scene: PackedScene = load("res://scenes/world_generator_demo.tscn")
	var root_node := scene.instantiate() as Node3D
	get_root().add_child(root_node)
	await process_frame
	await process_frame

	var gen := root_node.get_node("WorldGenerator") as WorldGenerator
	var container := gen.get_node_or_null("ChunksContainer") as Node3D
	if container == null or container.get_child_count() != 64:
		push_error("Expected 64 chunks in demo scene, got %d" % [container.get_child_count() if container else -1])
		quit(1)
		return

	var expected_shader: Shader = load("res://shaders/lol_biome_terrain.gdshader") as Shader
	for child in container.get_children():
		var t_mi := child.get_node_or_null("TerrainMesh") as MeshInstance3D
		if t_mi == null or not (t_mi.material_override is ShaderMaterial):
			push_error("%s TerrainMesh missing ShaderMaterial!" % child.name)
			quit(1)
			return
		var smat := t_mi.material_override as ShaderMaterial
		if smat.shader != expected_shader:
			push_error("%s ShaderMaterial has wrong shader!" % child.name)
			quit(1)
			return
		for param in ["layer0_array", "layer1_array", "layer2_cliff_array", "layer3_path_array", "ctrl_id_tex", "ctrl_weight_tex"]:
			if smat.get_shader_parameter(param) == null:
				push_error("%s missing shader parameter '%s'" % [child.name, param])
				quit(1)
				return

	# 5. Measure GPU & CPU frame time on live renderer at max zoom-out (780m) and close-up (140m)
	var perf_str := "headless_skipped"
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var vp_rid: RID = get_root().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp_rid, true)
		var rig := root_node.get_node_or_null("IsometricCameraRig") as IsometricCameraRig
		if rig != null:
			# Max zoom-out benchmark
			rig.global_position = Vector3.ZERO
			rig.zoom_distance = 780.0
			for _w in range(6):
				await process_frame
			var gpu_far := 0.0
			var cpu_far := 0.0
			var t0_far := Time.get_ticks_usec()
			for _f in range(20):
				await process_frame
				gpu_far += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
				cpu_far += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
			var wall_far := float(Time.get_ticks_usec() - t0_far) / 20000.0
			gpu_far /= 20.0
			cpu_far /= 20.0

			# Close-up benchmark over a pass & triple junction
			var focus_xz := Vector2.ZERO
			for edge_var in gen.current_layout.barrier_edges.values():
				var edge: Dictionary = edge_var
				if bool(edge["has_barrier"]):
					focus_xz = edge["pass_center"]
					break
			rig.global_position = Vector3(focus_xz.x, 0.0, focus_xz.y)
			rig.zoom_distance = 140.0
			for _w in range(6):
				await process_frame
			var gpu_near := 0.0
			var cpu_near := 0.0
			var t0_near := Time.get_ticks_usec()
			for _f in range(20):
				await process_frame
				gpu_near += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
				cpu_near += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
			var wall_near := float(Time.get_ticks_usec() - t0_near) / 20000.0
			gpu_near /= 20.0
			cpu_near /= 20.0
			var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			perf_str = "far_frame=%.2fms(gpu_ts=%.2fms,cpu=%.2fms)_near_frame=%.2fms(gpu_ts=%.2fms,cpu=%.2fms)_draws=%d" % [
				wall_far, gpu_far, cpu_far, wall_near, gpu_near, cpu_near, draws
			]

	print("STEP3_SHADER_VERIFY_CLEAN: placeholders_24=ok mobile_etc2=ok custom_override=ok shader_chunks=64 shader_bindings=ok perf=%s" % perf_str)
	quit(0)
