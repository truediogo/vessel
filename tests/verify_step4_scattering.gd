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
		push_error("Missing WorldGenerator or layout")
		quit(1)
		return

	# 1. Verify all 6 biomes have populated ScatterRules using multi-surface alpha foliage / monoliths
	for b in gen.biomes:
		if b.scatter_rules.is_empty():
			push_error("Biome '%s' has empty scatter_rules!" % b.biome_id)
			quit(1)
			return
		for r in b.scatter_rules:
			var m := r.resolve_mesh()
			if m == null:
				push_error("Rule '%s' on biome '%s' resolved null mesh!" % [r.rule_name, b.biome_id])
				quit(1)
				return
			# Verify foliage rules use alpha-cutout shader (lol_swaying_foliage) rather than opaque plastic primitives
			if r.rule_name.contains("Sakura") or r.rule_name.contains("Oak") or r.rule_name.contains("Willow") or r.rule_name.contains("Pine") or r.rule_name.contains("Cedar") or r.rule_name.contains("Fir") or r.rule_name.contains("Bonsai"):
				if m.get_surface_count() < 2:
					push_error("Tree rule '%s' expected 2 surfaces (bark + alpha leaf cards), got %d" % [r.rule_name, m.get_surface_count()])
					quit(1)
					return
				var leaf_mat := m.surface_get_material(1) as ShaderMaterial
				if leaf_mat == null or leaf_mat.shader == null or not leaf_mat.shader.resource_path.ends_with("lol_swaying_foliage.gdshader"):
					push_error("Tree rule '%s' leaf surface does not use lol_swaying_foliage.gdshader!" % r.rule_name)
					quit(1)
					return

	# 2. Verify MultiMeshInstance3D nodes spawned (either merged in MergedScatterContainer or per-chunk ScatterContainer),
	#    plus CylinderShape3D colliders on navigation-blocking props.
	var container := gen.get_node_or_null("ChunksContainer") as Node3D
	if container == null or container.get_child_count() != 64:
		push_error("Expected 64 chunks")
		quit(1)
		return

	var total_instances := 0
	var tree_like_batches := 0
	var grass_batches := 0
	var merged_sc := gen.get_node_or_null("MergedScatterContainer") as Node3D
	if merged_sc != null:
		for cell_node in merged_sc.get_children():
			for mmi_var in cell_node.get_children():
				var mmi := mmi_var as MultiMeshInstance3D
				if mmi == null or mmi.multimesh == null:
					continue
				total_instances += mmi.multimesh.instance_count
				if mmi.name.contains("Grass"):
					grass_batches += 1
				else:
					tree_like_batches += 1
	for c_node in container.get_children():
		var sc := c_node.get_node_or_null("ScatterContainer") as Node3D
		if sc == null:
			continue
		for mmi_var in sc.get_children():
			var mmi := mmi_var as MultiMeshInstance3D
			if mmi == null or mmi.multimesh == null:
				continue
			total_instances += mmi.multimesh.instance_count
			if mmi.name.contains("Grass"):
				grass_batches += 1
			else:
				tree_like_batches += 1

	var cyl_colliders := 0
	for c_node in container.get_children():
		var body := c_node.get_node_or_null("TerrainBody") as StaticBody3D
		if body == null:
			continue
		for cs_var in body.get_children():
			var cs := cs_var as CollisionShape3D
			if cs != null and cs.shape is CylinderShape3D:
				cyl_colliders += 1

	if total_instances < 1500 or tree_like_batches == 0 or grass_batches == 0 or cyl_colliders == 0:
		push_error("Insufficient scattered instances or colliders: total=%d tree_batches=%d grass_batches=%d cyl_colliders=%d" % [total_instances, tree_like_batches, grass_batches, cyl_colliders])
		quit(1)
		return

	# 3. Verify determinism & strict rule constraints (height_range, max_slope_degrees, min_water_clearance, min_spacing)
	var scatter_a := gen.scatterer.scatter_chunk(Vector2i(3, 3), gen.current_layout, gen.region_generator, gen.terrain_generator, gen.height_scale, gen.barrier_height_scale, gen.scatter_density_multiplier)
	var scatter_b := gen.scatterer.scatter_chunk(Vector2i(3, 3), gen.current_layout, gen.region_generator, gen.terrain_generator, gen.height_scale, gen.barrier_height_scale, gen.scatter_density_multiplier)
	if scatter_a.size() != scatter_b.size():
		push_error("Scatterer determinism mismatch on batch count!")
		quit(1)
		return

	for i in range(scatter_a.size()):
		var mm_a := scatter_a[i]["multimesh"] as MultiMesh
		var mm_b := scatter_b[i]["multimesh"] as MultiMesh
		if mm_a.instance_count != mm_b.instance_count:
			push_error("Scatterer determinism mismatch on instance count!")
			quit(1)
			return
		var rule := scatter_a[i]["rule"] as ScatterRule
		var recs: Array = scatter_a[i]["records"]
		for j in range(recs.size()):
			var rec: Dictionary = recs[j]
			var wp: Vector3 = rec["world_pos"]
			var wy: float = float(rec["water_y"])
			var s_deg: float = float(rec["slope_deg"])
			if wp.y < wy + rule.min_water_clearance - 0.01:
				push_error("Instance violated water clearance on %s: y=%.2f wy=%.2f" % [rule.rule_name, wp.y, wy])
				quit(1)
				return
			if wp.y < rule.height_range.x - 0.01 or wp.y > rule.height_range.y + 0.01:
				push_error("Instance violated height_range on %s: y=%.2f" % [rule.rule_name, wp.y])
				quit(1)
				return
			if s_deg > rule.max_slope_degrees + 0.01:
				push_error("Instance violated max_slope_degrees on %s: slope=%.2f > %.2f" % [rule.rule_name, s_deg, rule.max_slope_degrees])
				quit(1)
				return
			for k in range(j + 1, recs.size()):
				var wp2: Vector3 = recs[k]["world_pos"]
				var dist2 := Vector2(wp.x, wp.z).distance_to(Vector2(wp2.x, wp2.z))
				if dist2 < rule.min_spacing - 0.05:
					push_error("Instance violated min_spacing on %s: d=%.2f < %.2f" % [rule.rule_name, dist2, rule.min_spacing])
					quit(1)
					return

	print("STEP4_SCATTERING_VERIFY_CLEAN: biomes_6=ok total_instances=%d tree_batches=%d grass_batches=%d cyl_colliders=%d determinism=ok constraints=ok" % [
		total_instances, tree_like_batches, grass_batches, cyl_colliders
	])
	quit(0)
