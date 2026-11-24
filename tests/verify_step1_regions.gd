extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var biomes: Array[BiomeConfig] = []
	for path in WorldGenerator.DEFAULT_BIOME_PATHS:
		var b := load(path) as BiomeConfig
		if b == null:
			push_error("Failed loading biome resource: %s" % path)
			quit(1)
			return
		biomes.append(b)

	var rg := RegionGenerator.new()

	# 1. Strict non-adjacent biome assignment + all biomes represented + reachability across 25 seeds
	var test_seeds: Array[int] = [1337]
	for s in range(100, 124):
		test_seeds.append(s)

	for seed_val in test_seeds:
		var layout := rg.generate_layout(seed_val, 512.0, 64, 7, 36.0, 0.0, biomes, 28.0, 0.0045, true)
		if layout.regions.size() != 7:
			push_error("Seed %d: expected 7 regions, got %d" % [seed_val, layout.regions.size()])
			quit(1)
			return

		var used_biomes := {}
		for r in layout.regions:
			var b_idx: int = int(r["biome_index"])
			used_biomes[b_idx] = true
			for nb in r["neighbors"]:
				var nb_b: int = int(layout.regions[int(nb)]["biome_index"])
				if nb_b == b_idx:
					push_error("Seed %d: adjacent regions %d and %d share identical biome %d!" % [seed_val, int(r["id"]), int(nb), b_idx])
					quit(1)
					return

		if used_biomes.size() != biomes.size():
			push_error("Seed %d: expected all %d biomes used, got %d" % [seed_val, biomes.size(), used_biomes.size()])
			quit(1)
			return

		# BFS reachability
		var visited := {0: true}
		var queue: Array[int] = [0]
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			for nb in layout.regions[cur]["neighbors"]:
				var nb_id := int(nb)
				if not visited.has(nb_id):
					visited[nb_id] = true
					queue.append(nb_id)
		if visited.size() != layout.regions.size():
			push_error("Seed %d: unreachable regions (%d/%d)" % [seed_val, visited.size(), layout.regions.size()])
			quit(1)
			return

	# 2. Determinism & 1024m dynamic scaling
	var l1 := rg.generate_layout(1337, 512.0, 64, 7, 36.0, 0.0, biomes)
	var l2 := rg.generate_layout(1337, 512.0, 64, 7, 36.0, 0.0, biomes)
	for i in range(l1.regions.size()):
		if not l1.regions[i]["center"].is_equal_approx(l2.regions[i]["center"]) or int(l1.regions[i]["biome_index"]) != int(l2.regions[i]["biome_index"]):
			push_error("Determinism mismatch on region %d" % i)
			quit(1)
			return

	var l_1024 := rg.generate_layout(1337, 1024.0, 64, 7, 36.0, 0.0, biomes)
	if l_1024.get_grid_chunk_count() != 16:
		push_error("1024m grid chunk count expected 16, got %d" % l_1024.get_grid_chunk_count())
		quit(1)
		return

	# 3. Triple-junction & grid weight conservation
	var max_w_err := 0.0
	for gz in range(-240, 241, 16):
		for gx in range(-240, 241, 16):
			var s := rg.sample_at(float(gx), float(gz), l1)
			var w: Vector3 = s["weights"]
			max_w_err = maxf(max_w_err, absf((w.x + w.y + w.z) - 1.0))
			if w.x < 0.0 or w.y < 0.0 or w.z < 0.0:
				push_error("Negative weight encountered: %s" % str(w))
				quit(1)
				return
	if max_w_err > 1e-5:
		push_error("Weight conservation error too high: %f" % max_w_err)
		quit(1)
		return

	# 4. Control map quantization (r8+g8+b8 == 255) & 4-tap texelFetch bilinear slot-swap test
	var tex_res := 32
	var found_slot_swap := false
	var swap_chunk := Vector2i.ZERO
	var swap_uv := Vector2(0.5, 0.5)
	var swap_b_left := 0
	var swap_b_right := 0
	var tested_maps := {}

	for cz in range(8):
		for cx in range(8):
			var maps := rg.build_chunk_control_maps(Vector2i(cx, cz), tex_res, l1)
			var id_img: Image = maps["id_image"]
			var wt_img: Image = maps["weight_image"]
			tested_maps[Vector2i(cx, cz)] = maps
			for py in range(tex_res):
				for px in range(tex_res):
					var wc: Color = wt_img.get_pixel(px, py)
					var w_sum: int = wc.r8 + wc.g8 + wc.b8
					if w_sum != 255:
						push_error("Quantized weight sum != 255 (%d) at chunk (%d,%d) texel (%d,%d)" % [w_sum, cx, cz, px, py])
						quit(1)
						return
					if not found_slot_swap and px + 1 < tex_res:
						var c_a: Color = id_img.get_pixel(px, py)
						var c_b: Color = id_img.get_pixel(px + 1, py)
						if c_a.r8 != c_b.r8 and c_a.r8 == c_b.g8 and c_a.g8 == c_b.r8:
							found_slot_swap = true
							swap_chunk = Vector2i(cx, cz)
							swap_uv = Vector2((float(px) + 0.5) / float(tex_res - 1), float(py) / float(tex_res - 1))
							swap_b_left = c_a.r8
							swap_b_right = c_b.r8

	if not found_slot_swap:
		push_error("Expected at least one Voronoi border slot swap across texels in 512m world")
		quit(1)
		return

	var swap_maps: Dictionary = tested_maps[swap_chunk]
	var interp: Dictionary = RegionGenerator.sample_control_maps_bilinear(
		swap_maps["id_image"], swap_maps["weight_image"], swap_uv, biomes.size()
	)
	var bw: PackedFloat32Array = interp["biome_weights"]
	var bw_sum := 0.0
	for v in bw:
		bw_sum += v
	if absf(bw_sum - 1.0) > 0.015:
		push_error("4-tap bilinear biome weights do not sum to 1.0: %f" % bw_sum)
		quit(1)
		return
	if bw[swap_b_left] <= 0.15 or bw[swap_b_right] <= 0.15:
		push_error("4-tap bilinear failed across slot swap: left=%.3f right=%.3f" % [bw[swap_b_left], bw[swap_b_right]])
		quit(1)
		return

	# 5. Editor-baked compressed Texture2DArray save (on GPU renderer) & runtime load
	var bake_dir := "res://resources/biomes/compiled"
	if DisplayServer.get_name() != "headless":
		var bake_res := BiomeConfig.bake_and_save_texture_arrays(biomes, bake_dir, 512)
		if not bake_res["errors"].is_empty():
			push_error("Texture2DArray bake errors: %s" % str(bake_res["errors"]))
			quit(1)
			return

	var load_res := BiomeConfig.load_baked_texture_arrays(bake_dir)
	if not load_res["errors"].is_empty():
		push_error("Texture2DArray load errors: %s" % str(load_res["errors"]))
		quit(1)
		return

	var layer0 := load_res["layer0"] as Texture2DArray
	if layer0 == null or layer0.get_layers() != biomes.size() or layer0.get_width() != 512:
		push_error("Baked layer0 Texture2DArray dimensions invalid")
		quit(1)
		return

	var fmt_info := "headless_loaded"
	if DisplayServer.get_name() != "headless":
		var slice0: Image = layer0.get_layer_data(0)
		if slice0 == null or not slice0.is_compressed():
			push_error("Baked Texture2DArray slice0 is not VRAM-compressed (fmt=%d)" % [slice0.get_format() if slice0 else -1])
			quit(1)
			return
		fmt_info = "fmt=%d_compressed" % slice0.get_format()

	print("STEP1_REGIONS_VERIFY_CLEAN: seeds_25_non_adjacent=ok determinism=ok scale_1024=16x16 max_w_err=%.6f 4tap_slot_swap_ok=(%.3f,%.3f) baked_texarray=(%dx%dx%d,%s)" % [
		max_w_err, bw[swap_b_left], bw[swap_b_right], layer0.get_width(), layer0.get_height(), layer0.get_layers(), fmt_info
	])
	quit(0)
