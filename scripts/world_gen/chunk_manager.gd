@tool
class_name WorldGenerator
extends Node3D

## Root @tool coordinator for the procedural world generator (Step 6a: Chunked Navigation & Player).
## Exposes seed, world/chunk sizing, Voronoi region layout parameters, terrain shape
## controls, biome configs, baked Texture2DArray shader settings, merged MultiMesh scattering,
## placeholder landmarks & A* roads, per-chunk NavigationRegion3D baking, test player,
## and live 2D/3D editor & runtime debug visualization.

const TERRAIN_SHADER_PATH := "res://shaders/lol_biome_terrain.gdshader"
const NavTestPlayerScript := preload("res://scripts/world_gen/nav_test_player.gd")

const DEFAULT_BIOME_PATHS: Array[String] = [
	"res://resources/biomes/frozen_tundra.tres",
	"res://resources/biomes/desert.tres",
	"res://resources/biomes/temperate_forest.tres",
	"res://resources/biomes/swamp.tres",
	"res://resources/biomes/volcanic_highlands.tres",
	"res://resources/biomes/coastal_plains.tres",
]

@export_tool_button("Regenerate", "Reload") var regenerate_button: Callable = regenerate_world
@export_tool_button("Bake Biome Texture Arrays", "Texture2DArray") var bake_textures_button: Callable = bake_biome_texture_arrays

@export_group("World Layout")
@export var world_seed: int = 1337:
	set(value):
		world_seed = value
		_schedule_regenerate()

@export var world_size: float = 512.0:
	set(value):
		world_size = maxf(64.0, value)
		_schedule_regenerate()

@export var chunk_size: int = 64:
	set(value):
		chunk_size = maxi(16, value)
		_schedule_regenerate()

@export_range(6, 8, 1) var region_count: int = 7:
	set(value):
		region_count = clampi(value, 2, 32)
		_schedule_regenerate()

@export var prevent_adjacent_identical_biomes: bool = true:
	set(value):
		prevent_adjacent_identical_biomes = value
		_schedule_regenerate()

@export var border_blend_distance: float = 36.0:
	set(value):
		border_blend_distance = maxf(1.0, value)
		_schedule_regenerate()

@export_group("Region Warp Noise")
@export var domain_warp_strength: float = 28.0:
	set(value):
		domain_warp_strength = maxf(0.0, value)
		_schedule_regenerate()

@export var domain_warp_frequency: float = 0.0045:
	set(value):
		domain_warp_frequency = maxf(0.0005, value)
		_schedule_regenerate()

@export_group("Environment & Biomes")
@export var sea_level: float = 0.0:
	set(value):
		sea_level = value
		_schedule_regenerate()

@export var biomes: Array[BiomeConfig] = []:
	set(value):
		biomes = value
		_schedule_regenerate()

@export var compiled_texture_array_dir: String = "res://resources/biomes/compiled"
@export var texture_compression_target: BiomeConfig.CompressionTarget = BiomeConfig.CompressionTarget.DESKTOP_S3TC

@export_group("Terrain & Chunks")
@export_range(16, 128, 8) var chunk_subdivisions: int = 64:
	set(value):
		chunk_subdivisions = clampi(value, 8, 128)
		_schedule_regenerate()

@export_range(0.25, 3.0, 0.05) var height_scale: float = 1.0:
	set(value):
		height_scale = maxf(0.1, value)
		_schedule_regenerate()

@export_range(0.0, 3.0, 0.05) var barrier_height_scale: float = 0.60:
	set(value):
		barrier_height_scale = maxf(0.0, value)
		_schedule_regenerate()

@export var generate_colliders: bool = true:
	set(value):
		generate_colliders = value
		_schedule_regenerate()

@export var generate_water: bool = true:
	set(value):
		generate_water = value
		_schedule_regenerate()

@export_group("Terrain Shader")
@export var use_shader_terrain: bool = true:
	set(value):
		use_shader_terrain = value
		_schedule_regenerate()

@export_range(16, 128, 16) var control_map_resolution: int = 32:
	set(value):
		control_map_resolution = clampi(value, 16, 128)
		_schedule_regenerate()

@export_range(0.02, 0.30, 0.005) var world_uv_scale: float = 0.085:
	set(value):
		world_uv_scale = value
		_sync_shader_global_uniforms()

@export_range(0.02, 0.30, 0.005) var cliff_uv_scale: float = 0.090:
	set(value):
		cliff_uv_scale = value
		_sync_shader_global_uniforms()

@export_range(0.02, 0.30, 0.005) var path_uv_scale: float = 0.140:
	set(value):
		path_uv_scale = value
		_sync_shader_global_uniforms()

@export var enable_camera_occlusion_fade: bool = false:
	set(value):
		enable_camera_occlusion_fade = value
		_sync_shader_global_uniforms()

@export_range(4.0, 24.0, 0.5) var occlusion_fade_radius: float = 11.0:
	set(value):
		occlusion_fade_radius = value
		_sync_shader_global_uniforms()

@export_group("Object Scattering")
@export var enable_scattering: bool = true:
	set(value):
		enable_scattering = value
		_schedule_regenerate()

@export_range(0.0, 2.5, 0.1) var scatter_density_multiplier: float = 1.0:
	set(value):
		scatter_density_multiplier = maxf(0.0, value)
		_schedule_regenerate()

@export_range(1, 8, 1) var scatter_merge_chunk_group: int = 2:
	set(value):
		scatter_merge_chunk_group = clampi(value, 1, 8)
		_schedule_regenerate()

@export_group("Landmarks & Roads")
@export var enable_landmarks_and_roads: bool = true:
	set(value):
		enable_landmarks_and_roads = value
		_schedule_regenerate()

@export_group("Navigation & Player")
@export var enable_navigation: bool = true:
	set(value):
		enable_navigation = value
		_schedule_regenerate()

@export_range(0.25, 1.0, 0.05) var nav_cell_size: float = 0.80:
	set(value):
		nav_cell_size = maxf(0.2, value)
		_schedule_regenerate()

@export_range(0.10, 0.50, 0.05) var nav_cell_height: float = 0.25:
	set(value):
		nav_cell_height = maxf(0.1, value)
		_schedule_regenerate()

@export_range(0.25, 1.25, 0.05) var nav_agent_radius: float = 0.80:
	set(value):
		nav_agent_radius = maxf(0.2, value)
		_schedule_regenerate()

@export_range(1.20, 2.60, 0.05) var nav_agent_height: float = 1.75:
	set(value):
		nav_agent_height = maxf(1.0, value)
		_schedule_regenerate()

@export_range(0.20, 1.40, 0.05) var nav_agent_max_climb: float = 0.75:
	set(value):
		nav_agent_max_climb = maxf(0.1, value)
		_schedule_regenerate()

@export_range(20.0, 60.0, 1.0) var nav_agent_max_slope: float = 45.0:
	set(value):
		nav_agent_max_slope = clampf(value, 15.0, 65.0)
		_schedule_regenerate()

@export_range(1.0, 6.0, 0.2) var nav_border_size: float = 2.40:
	set(value):
		nav_border_size = maxf(0.5, value)
		_schedule_regenerate()

@export var spawn_test_player: bool = true:
	set(value):
		spawn_test_player = value
		if _is_ready and not Engine.is_editor_hint():
			_ensure_test_player()

@export_group("Debug Preview")
@export var show_debug_map: bool = true:
	set(value):
		show_debug_map = value
		_update_debug_visibility()

@export var show_flat_region_plane: bool = false:
	set(value):
		show_flat_region_plane = value
		_update_debug_visibility()

@export_range(128, 512, 64) var debug_map_resolution: int = 256:
	set(value):
		debug_map_resolution = clampi(value, 64, 512)
		_schedule_regenerate()

@export var debug_map_rect_path: NodePath = NodePath("../DebugCanvas/DebugPanel/Margin/VBox/DebugMapRect")
@export var debug_legend_label_path: NodePath = NodePath("../DebugCanvas/DebugPanel/Margin/VBox/LegendLabel")

var region_generator: RegionGenerator = RegionGenerator.new()
var terrain_generator: TerrainGenerator = TerrainGenerator.new()
var scatterer: Scatterer = Scatterer.new()
var landmark_placer: LandmarkPlacer = LandmarkPlacer.new()
var current_layout: WorldLayoutData
var debug_image: Image
var debug_texture: ImageTexture

var _is_ready: bool = false
var _pending_regenerate: bool = false
var _debug_plane: MeshInstance3D
var _chunks_container: Node3D
var _merged_scatter_container: Node3D
var _terrain_material: StandardMaterial3D
var _water_material: StandardMaterial3D
var _terrain_shader: Shader
var _baked_texture_arrays: Dictionary = {}
var _chunk_shader_materials: Array[ShaderMaterial] = []
var _last_min_height: float = 0.0
var _last_max_height: float = 0.0
var _last_water_chunk_count: int = 0
var _last_scattered_instances: int = 0
var _last_nav_region_count: int = 0
var _last_nav_poly_count: int = 0
var _test_player: NavTestPlayerScript = null


func _ready() -> void:
	_is_ready = true
	if biomes.is_empty():
		_load_default_biomes()
	regenerate_world()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not enable_camera_occlusion_fade or _chunk_shader_materials.is_empty():
		return
	var rig := get_node_or_null("../IsometricCameraRig") as IsometricCameraRig
	if rig == null or current_layout == null:
		return
	var focus_xz := Vector2(rig.global_position.x, rig.global_position.z)
	var fy: float = terrain_generator.sample_height_only(
		focus_xz.x, focus_xz.y, current_layout, region_generator, height_scale, barrier_height_scale
	)
	var focus_pos := Vector3(focus_xz.x, fy, focus_xz.y)
	for mat in _chunk_shader_materials:
		if is_instance_valid(mat):
			mat.set_shader_parameter("focus_world_pos", focus_pos)


func _schedule_regenerate() -> void:
	if _is_ready and not _pending_regenerate:
		_pending_regenerate = true
		call_deferred("_run_scheduled_regenerate")


func _run_scheduled_regenerate() -> void:
	if _pending_regenerate:
		_pending_regenerate = false
		regenerate_world()


func regenerate_world() -> void:
	_pending_regenerate = false
	if biomes.is_empty():
		_load_default_biomes()
	StylizedPropLibrary.ensure_biome_scatter_rules(biomes)

	current_layout = region_generator.generate_layout(
		world_seed,
		world_size,
		chunk_size,
		region_count,
		border_blend_distance,
		sea_level,
		biomes,
		domain_warp_strength,
		domain_warp_frequency,
		prevent_adjacent_identical_biomes
	)

	if enable_landmarks_and_roads:
		landmark_placer.plan_landmarks_and_roads(
			current_layout,
			region_generator,
			terrain_generator,
			height_scale,
			barrier_height_scale
		)

	var rig := get_node_or_null("../IsometricCameraRig") as IsometricCameraRig
	if rig != null:
		rig.pan_bounds_half_extent = world_size * 0.6

	_rebuild_all_chunks()
	if not Engine.is_editor_hint():
		_ensure_test_player()
	_refresh_debug_visuals()


## Editor bake action: packs & VRAM-compresses all BiomeConfig textures into 4 `.res` Texture2DArray files
## so runtime never has to decompress or convert source textures to RGBA8.
func bake_biome_texture_arrays() -> Dictionary:
	if biomes.is_empty():
		_load_default_biomes()
	var res := BiomeConfig.bake_and_save_texture_arrays(
		biomes, compiled_texture_array_dir, 512, texture_compression_target
	)
	if res["errors"].is_empty():
		_baked_texture_arrays = res
		print("WorldGenerator: Baked 4 compressed Texture2DArray assets to %s (warnings: %d)" % [
			compiled_texture_array_dir, res["warnings"].size()
		])
		if _is_ready and use_shader_terrain:
			_rebuild_all_chunks()
	return res


func _ensure_shader_resources() -> bool:
	if _terrain_shader == null and ResourceLoader.exists(TERRAIN_SHADER_PATH):
		_terrain_shader = ResourceLoader.load(TERRAIN_SHADER_PATH) as Shader
	if _terrain_shader == null:
		return false

	if _baked_texture_arrays.is_empty() or _baked_texture_arrays.get("layer0") == null:
		var loaded := BiomeConfig.load_baked_texture_arrays(compiled_texture_array_dir)
		if loaded["errors"].is_empty() and loaded.get("layer0") != null:
			_baked_texture_arrays = loaded
		elif DisplayServer.get_name() != "headless":
			var baked := BiomeConfig.bake_and_save_texture_arrays(
				biomes, compiled_texture_array_dir, 512, texture_compression_target
			)
			if baked["errors"].is_empty():
				_baked_texture_arrays = baked

	return _baked_texture_arrays.get("layer0") != null and _baked_texture_arrays.get("layer1") != null and _baked_texture_arrays.get("layer2_cliff") != null and _baked_texture_arrays.get("layer3_path") != null


func _create_chunk_shader_material(ctrl_id_tex: Texture2D, ctrl_wt_tex: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _terrain_shader
	mat.set_shader_parameter("layer0_array", _baked_texture_arrays["layer0"])
	mat.set_shader_parameter("layer1_array", _baked_texture_arrays["layer1"])
	mat.set_shader_parameter("layer2_cliff_array", _baked_texture_arrays["layer2_cliff"])
	mat.set_shader_parameter("layer3_path_array", _baked_texture_arrays["layer3_path"])
	mat.set_shader_parameter("ctrl_id_tex", ctrl_id_tex)
	mat.set_shader_parameter("ctrl_weight_tex", ctrl_wt_tex)
	mat.set_shader_parameter("ctrl_tex_res", control_map_resolution)
	mat.set_shader_parameter("biome_count", mini(8, biomes.size()))
	mat.set_shader_parameter("sea_level", sea_level)
	mat.set_shader_parameter("world_uv_scale", world_uv_scale)
	mat.set_shader_parameter("cliff_uv_scale", cliff_uv_scale)
	mat.set_shader_parameter("path_uv_scale", path_uv_scale)
	mat.set_shader_parameter("enable_occlusion_fade", enable_camera_occlusion_fade)
	mat.set_shader_parameter("occlusion_fade_radius", occlusion_fade_radius)

	var p_tints: Array[Color] = []
	var s_tints: Array[Color] = []
	var c_tints: Array[Color] = []
	var r_tints: Array[Color] = []
	var slope_th: Array[Vector2] = []
	var high_alt: Array[Vector2] = []
	var water_off: Array[float] = []
	var is_volc: Array[float] = []

	for i in range(8):
		if i < biomes.size() and biomes[i] != null:
			var b: BiomeConfig = biomes[i]
			var tint_mix: float = 0.16 if b.use_procedural_placeholder_textures else 1.0
			p_tints.append(Color.WHITE.lerp(b.primary_tint, tint_mix))
			s_tints.append(Color.WHITE.lerp(b.secondary_tint, tint_mix))
			c_tints.append(Color.WHITE.lerp(b.cliff_tint, tint_mix))
			r_tints.append(Color.WHITE.lerp(b.path_tint, tint_mix))
			slope_th.append(b.slope_rock_threshold)
			high_alt.append(b.high_altitude_range)
			water_off.append(b.water_table_offset)
			is_volc.append(1.0 if b.biome_id == &"volcanic_highlands" else 0.0)
		else:
			p_tints.append(Color.WHITE)
			s_tints.append(Color.WHITE)
			c_tints.append(Color.WHITE)
			r_tints.append(Color.WHITE)
			slope_th.append(Vector2(0.22, 0.45))
			high_alt.append(Vector2(18.0, 28.0))
			water_off.append(0.0)
			is_volc.append(0.0)

	mat.set_shader_parameter("biome_primary_tints", p_tints)
	mat.set_shader_parameter("biome_secondary_tints", s_tints)
	mat.set_shader_parameter("biome_cliff_tints", c_tints)
	mat.set_shader_parameter("biome_path_tints", r_tints)
	mat.set_shader_parameter("biome_slope_thresholds", slope_th)
	mat.set_shader_parameter("biome_high_alt_ranges", high_alt)
	mat.set_shader_parameter("biome_water_offsets", water_off)
	mat.set_shader_parameter("biome_is_volcanic", is_volc)
	return mat


func _sync_shader_global_uniforms() -> void:
	for mat in _chunk_shader_materials:
		if not is_instance_valid(mat):
			continue
		mat.set_shader_parameter("world_uv_scale", world_uv_scale)
		mat.set_shader_parameter("cliff_uv_scale", cliff_uv_scale)
		mat.set_shader_parameter("path_uv_scale", path_uv_scale)
		mat.set_shader_parameter("enable_occlusion_fade", enable_camera_occlusion_fade)
		mat.set_shader_parameter("occlusion_fade_radius", occlusion_fade_radius)


func _ensure_shared_materials() -> void:
	if _terrain_material == null:
		_terrain_material = StandardMaterial3D.new()
		_terrain_material.vertex_color_use_as_albedo = true
		_terrain_material.roughness = 0.94
		_terrain_material.metallic = 0.0
		_terrain_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	if _water_material == null:
		_water_material = StandardMaterial3D.new()
		_water_material.vertex_color_use_as_albedo = true
		_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_water_material.albedo_color = Color(1.0, 1.0, 1.0, 0.80)
		_water_material.roughness = 0.25
		_water_material.metallic = 0.05
		_water_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _ensure_chunks_container() -> Node3D:
	if _chunks_container == null or not is_instance_valid(_chunks_container):
		_chunks_container = get_node_or_null("ChunksContainer") as Node3D
	if _chunks_container == null:
		_chunks_container = Node3D.new()
		_chunks_container.name = "ChunksContainer"
		add_child(_chunks_container)
	return _chunks_container


func _ensure_merged_scatter_container() -> Node3D:
	if _merged_scatter_container == null or not is_instance_valid(_merged_scatter_container):
		_merged_scatter_container = get_node_or_null("MergedScatterContainer") as Node3D
	if _merged_scatter_container == null:
		_merged_scatter_container = Node3D.new()
		_merged_scatter_container.name = "MergedScatterContainer"
		add_child(_merged_scatter_container)
	return _merged_scatter_container


func _rebuild_all_chunks() -> void:
	if current_layout == null:
		return

	_ensure_shared_materials()
	var shader_ready: bool = use_shader_terrain and _ensure_shader_resources()
	_chunk_shader_materials.clear()

	var container := _ensure_chunks_container()
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

	var merged_container := _ensure_merged_scatter_container()
	for child in merged_container.get_children():
		merged_container.remove_child(child)
		child.queue_free()

	_last_min_height = INF
	_last_max_height = -INF
	_last_water_chunk_count = 0
	_last_scattered_instances = 0
	_last_nav_region_count = 0
	_last_nav_poly_count = 0

	var grid_chunks: int = current_layout.get_grid_chunk_count()
	var half_world: float = current_layout.world_size * 0.5
	var merge_g: int = maxi(1, scatter_merge_chunk_group)

	# Super-cell accumulator: key = "%d_%d_%d_%s" -> Dictionary of transforms, colors, mesh, rule settings
	var merged_batches: Dictionary = {}
	var chunk_nodes: Dictionary = {}
	var chunk_nav_grids: Dictionary = {}
	var chunk_obstacles: Dictionary = {}

	for cz in range(grid_chunks):
		for cx in range(grid_chunks):
			var chunk_coord := Vector2i(cx, cz)
			var chunk_data := terrain_generator.build_chunk_data(
				chunk_coord,
				chunk_subdivisions,
				current_layout,
				region_generator,
				height_scale,
				barrier_height_scale,
				generate_water
			)

			_last_min_height = minf(_last_min_height, float(chunk_data["min_height"]))
			_last_max_height = maxf(_last_max_height, float(chunk_data["max_height"]))

			var chunk_node := Node3D.new()
			chunk_node.name = "Chunk_%d_%d" % [cx, cz]
			var chunk_origin: Vector3 = chunk_data["origin"]
			chunk_node.position = chunk_origin
			chunk_nodes[chunk_coord] = chunk_node
			if enable_navigation:
				chunk_nav_grids[chunk_coord] = {
					"subdivisions": int(chunk_data["subdivisions"]),
					"step": float(chunk_data["step"]),
					"heightmap": chunk_data["heightmap_data"],
				}
				chunk_obstacles[chunk_coord] = []

			var terrain_mi := MeshInstance3D.new()
			terrain_mi.name = "TerrainMesh"
			terrain_mi.mesh = chunk_data["terrain_mesh"]
			if shader_ready:
				var c_maps := region_generator.build_chunk_control_maps(
					chunk_coord, control_map_resolution, current_layout
				)
				var id_tex := ImageTexture.create_from_image(c_maps["id_image"])
				var wt_tex := ImageTexture.create_from_image(c_maps["weight_image"])
				var s_mat := _create_chunk_shader_material(id_tex, wt_tex)
				terrain_mi.material_override = s_mat
				_chunk_shader_materials.append(s_mat)
			else:
				terrain_mi.material_override = _terrain_material
			chunk_node.add_child(terrain_mi)

			var water_mesh: ArrayMesh = chunk_data["water_mesh"] as ArrayMesh
			if generate_water and water_mesh != null:
				_last_water_chunk_count += 1
				var water_mi := MeshInstance3D.new()
				water_mi.name = "WaterMesh"
				water_mi.mesh = water_mesh
				water_mi.material_override = _water_material
				water_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				chunk_node.add_child(water_mi)

			var body: StaticBody3D = null
			if generate_colliders:
				body = StaticBody3D.new()
				body.name = "TerrainBody"
				var col_shape := CollisionShape3D.new()
				col_shape.name = "CollisionShape3D"
				var hm := HeightMapShape3D.new()
				var vert_dim: int = int(chunk_data["subdivisions"]) + 1
				hm.map_width = vert_dim
				hm.map_depth = vert_dim
				hm.map_data = chunk_data["heightmap_data"]
				col_shape.shape = hm
				var step: float = float(chunk_data["step"])
				col_shape.scale = Vector3(step, 1.0, step)
				col_shape.position = Vector3(float(chunk_size) * 0.5, 0.0, float(chunk_size) * 0.5)
				body.add_child(col_shape)
				chunk_node.add_child(body)

			if enable_scattering and scatter_density_multiplier > 0.0:
				@warning_ignore("integer_division")
				var sx: int = cx / merge_g
				@warning_ignore("integer_division")
				var sz: int = cz / merge_g
				var super_origin := Vector3(
					-half_world + float(sx * merge_g * chunk_size),
					0.0,
					-half_world + float(sz * merge_g * chunk_size)
				)
				var offset_delta: Vector3 = chunk_origin - super_origin

				var scatter_batches := scatterer.scatter_chunk(
					chunk_coord,
					current_layout,
					region_generator,
					terrain_generator,
					height_scale,
					barrier_height_scale,
					scatter_density_multiplier
				)
				for batch in scatter_batches:
					var mm: MultiMesh = batch["multimesh"] as MultiMesh
					var rule: ScatterRule = batch["rule"] as ScatterRule
					var mesh_res: Mesh = mm.mesh
					_last_scattered_instances += mm.instance_count

					# Merge MultiMesh transforms & colors into 2x2 super-cell batch
					var batch_key := "%d_%d_%d_%d_%.0f" % [
						sx, sz, mesh_res.get_instance_id(), 1 if rule.cast_shadows else 0, rule.visibility_range_end
					]
					if not merged_batches.has(batch_key):
						merged_batches[batch_key] = {
							"super_coord": Vector2i(sx, sz),
							"super_origin": super_origin,
							"mesh": mesh_res,
							"rule": rule,
							"transforms": [],
							"colors": [],
						}
					var entry: Dictionary = merged_batches[batch_key]
					var t_list: Array = entry["transforms"]
					var c_list: Array = entry["colors"]
					for inst_i in range(mm.instance_count):
						var xf: Transform3D = mm.get_instance_transform(inst_i)
						xf.origin += offset_delta
						t_list.append(xf)
						c_list.append(mm.get_instance_color(inst_i))

					# Add physics colliders on chunk TerrainBody for navigation-blocking props
					if body != null and rule.blocks_navigation:
						var obs_list: Array = chunk_obstacles.get(chunk_coord, [])
						var recs: Array = batch["records"]
						for rec_var in recs:
							var rec: Dictionary = rec_var
							var lpos: Vector3 = rec["local_pos"]
							var sc: float = float(rec["scale"])
							var cyl := CylinderShape3D.new()
							cyl.radius = rule.collision_radius * sc
							cyl.height = rule.collision_height * sc
							var prop_cs := CollisionShape3D.new()
							prop_cs.shape = cyl
							prop_cs.position = lpos + Vector3(0.0, cyl.height * 0.5, 0.0)
							body.add_child(prop_cs)
							if enable_navigation:
								obs_list.append({
									"kind": &"cyl",
									"pos": lpos,
									"radius": cyl.radius,
								})

			container.add_child(chunk_node)

	# Build merged 2x2 super-cell MultiMeshInstance3D nodes
	var super_nodes: Dictionary = {}
	for b_var in merged_batches.values():
		var b_dict: Dictionary = b_var
		var sc_coord: Vector2i = b_dict["super_coord"]
		if not super_nodes.has(sc_coord):
			var sn := Node3D.new()
			sn.name = "SuperCell_%d_%d" % [sc_coord.x, sc_coord.y]
			sn.position = b_dict["super_origin"]
			merged_container.add_child(sn)
			super_nodes[sc_coord] = sn
		var parent_sn := super_nodes[sc_coord] as Node3D

		var t_arr: Array = b_dict["transforms"]
		var c_arr: Array = b_dict["colors"]
		var merged_mm := MultiMesh.new()
		merged_mm.transform_format = MultiMesh.TRANSFORM_3D
		merged_mm.use_colors = true
		merged_mm.mesh = b_dict["mesh"]
		merged_mm.instance_count = t_arr.size()
		for i in range(t_arr.size()):
			merged_mm.set_instance_transform(i, t_arr[i])
			merged_mm.set_instance_color(i, c_arr[i])

		var rule: ScatterRule = b_dict["rule"] as ScatterRule
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_%s" % rule.rule_name.replace(" ", "_")
		mmi.multimesh = merged_mm
		if rule.material_override != null:
			mmi.material_override = rule.material_override
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if rule.cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if rule.visibility_range_end > 0.0:
			mmi.visibility_range_end = rule.visibility_range_end
			mmi.visibility_range_end_margin = rule.visibility_range_fade_margin
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent_sn.add_child(mmi)

	# Instantiate Step 5 Landmark scenes inside their owning chunks
	if enable_landmarks_and_roads and not current_layout.landmarks.is_empty():
		for lm_var in current_layout.landmarks:
			var lm: Dictionary = lm_var
			var lm_scene: PackedScene = lm.get("scene") as PackedScene
			if lm_scene == null:
				continue
			var lm_center: Vector2 = lm["center"]
			var cx: int = clampi(floori((lm_center.x + half_world) / float(chunk_size)), 0, grid_chunks - 1)
			var cz: int = clampi(floori((lm_center.y + half_world) / float(chunk_size)), 0, grid_chunks - 1)
			var owner_chunk := chunk_nodes.get(Vector2i(cx, cz)) as Node3D
			if owner_chunk == null:
				continue
			var lm_container := owner_chunk.get_node_or_null("LandmarksContainer") as Node3D
			if lm_container == null:
				lm_container = Node3D.new()
				lm_container.name = "LandmarksContainer"
				owner_chunk.add_child(lm_container)

			var inst := lm_scene.instantiate() as Node3D
			if inst != null:
				inst.position = Vector3(
					lm_center.x - owner_chunk.position.x,
					float(lm["target_height"]),
					lm_center.y - owner_chunk.position.z
				)
				if inst is LandmarkSceneBuilder:
					(inst as LandmarkSceneBuilder).title_text = str(lm.get("title", "Landmark"))
				lm_container.add_child(inst)
				if enable_navigation:
					_collect_landmark_obstacles(inst, chunk_obstacles.get(Vector2i(cx, cz), []))

	if _last_min_height == INF:
		_last_min_height = 0.0
		_last_max_height = 0.0

	if enable_navigation and not chunk_nodes.is_empty():
		_bake_all_chunk_navmeshes(chunk_nodes, chunk_nav_grids, chunk_obstacles)


func _load_default_biomes() -> void:
	var loaded: Array[BiomeConfig] = []
	for path in DEFAULT_BIOME_PATHS:
		if ResourceLoader.exists(path):
			var res := load(path) as BiomeConfig
			if res != null:
				loaded.append(res)
	biomes = loaded


func _refresh_debug_visuals() -> void:
	if current_layout == null:
		return

	debug_image = region_generator.render_debug_map(
		current_layout,
		debug_map_resolution,
		terrain_generator,
		height_scale,
		barrier_height_scale
	)
	debug_texture = ImageTexture.create_from_image(debug_image)

	_ensure_debug_plane()
	if _debug_plane != null:
		var pm := _debug_plane.mesh as PlaneMesh
		if pm == null:
			pm = PlaneMesh.new()
			_debug_plane.mesh = pm
		pm.size = Vector2(world_size, world_size)
		_debug_plane.position.y = -0.25
		var mat := _debug_plane.material_override as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			_debug_plane.material_override = mat
		mat.albedo_texture = debug_texture

	var rect := get_node_or_null(debug_map_rect_path) as TextureRect
	if rect != null:
		rect.texture = debug_texture

	var legend := get_node_or_null(debug_legend_label_path) as RichTextLabel
	if legend != null:
		legend.text = _build_legend_bbcode()

	_update_debug_visibility()


func _ensure_debug_plane() -> void:
	if _debug_plane == null or not is_instance_valid(_debug_plane):
		_debug_plane = get_node_or_null("DebugRegionPlane") as MeshInstance3D
	if _debug_plane == null:
		_debug_plane = MeshInstance3D.new()
		_debug_plane.name = "DebugRegionPlane"
		add_child(_debug_plane)


func _update_debug_visibility() -> void:
	if _debug_plane != null and is_instance_valid(_debug_plane):
		_debug_plane.visible = show_flat_region_plane
	var rect := get_node_or_null(debug_map_rect_path)
	if rect != null:
		var panel := rect.get_node_or_null("../../..") as Control
		if panel != null:
			panel.visible = show_debug_map
		else:
			rect.visible = show_debug_map


func _build_legend_bbcode() -> String:
	var lines := PackedStringArray()
	var grid_chunks := current_layout.get_grid_chunk_count()
	lines.append("[b]Seed:[/b] %d   [b]World:[/b] %.0fm (%dx%d @ %dm)" % [
		world_seed, world_size, grid_chunks, grid_chunks, chunk_size
	])
	var barrier_cnt := 0
	for e in current_layout.barrier_edges.values():
		if bool(e["has_barrier"]):
			barrier_cnt += 1
	lines.append("[b]Regions:[/b] %d   [b]Barriers:[/b] %d   [b]Elev:[/b] %.1f..%.1fm" % [
		current_layout.regions.size(), barrier_cnt, _last_min_height, _last_max_height
	])
	lines.append("[b]Landmarks:[/b] %d   [b]Roads:[/b] %d   [b]Props:[/b] %d" % [
		current_layout.landmarks.size(), current_layout.road_segments.size(), _last_scattered_instances
	])
	if enable_navigation:
		lines.append("[b]NavRegions:[/b] %d   [b]NavPolys:[/b] %d" % [_last_nav_region_count, _last_nav_poly_count])
	lines.append("[b]Controls:[/b] R-Click: Move | C/Tab: Follow/Free | Scroll: Zoom")

	var seen := {}
	for r in current_layout.regions:
		var b: BiomeConfig = r["biome"]
		if not seen.has(b.biome_id):
			seen[b.biome_id] = b.debug_color
			lines.append("[color=#%s]■[/color] %s" % [b.debug_color.to_html(false), b.display_name])
	lines.append("[color=#eb5c29]■[/color] Mountain Barrier   [color=#2eebef]◯[/color] Open Pass Gate")
	return "\n".join(lines)


func get_landmark_nav_point(landmark_index: int) -> Vector3:
	if current_layout == null or landmark_index < 0 or landmark_index >= current_layout.landmarks.size():
		return Vector3.ZERO
	var lm: Dictionary = current_layout.landmarks[landmark_index]
	var c: Vector2 = lm["center"]
	var h: float = float(lm["target_height"])
	var pt := Vector3(c.x, h, c.y + 5.0)
	if is_inside_tree():
		var map_rid := get_world_3d().navigation_map
		if map_rid.is_valid() and NavigationServer3D.map_get_iteration_id(map_rid) > 0:
			if NavigationServer3D.map_get_closest_point_owner(map_rid, pt).is_valid():
				pt = NavigationServer3D.map_get_closest_point(map_rid, pt)
	return pt


func find_navigation_path(start_pt: Vector3, end_pt: Vector3, optimize: bool = true) -> PackedVector3Array:
	if not is_inside_tree():
		return PackedVector3Array()
	var map_rid := get_world_3d().navigation_map
	if not map_rid.is_valid():
		return PackedVector3Array()
	var qp := NavigationPathQueryParameters3D.new()
	qp.map = map_rid
	qp.start_position = start_pt
	qp.target_position = end_pt
	qp.path_postprocessing = (
		NavigationPathQueryParameters3D.PATH_POSTPROCESSING_CORRIDORFUNNEL
		if optimize
		else NavigationPathQueryParameters3D.PATH_POSTPROCESSING_NONE
	)
	qp.path_search_max_polygons = 65536
	var qr := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(qp, qr)
	return qr.path


func _ensure_test_player() -> void:
	if not spawn_test_player:
		if _test_player != null and is_instance_valid(_test_player):
			_test_player.queue_free()
			_test_player = null
		return

	if _test_player == null or not is_instance_valid(_test_player):
		_test_player = get_node_or_null("TestPlayer") as NavTestPlayerScript
	if _test_player == null:
		_test_player = NavTestPlayerScript.new()
		_test_player.name = "TestPlayer"
		add_child(_test_player)

	var spawn_pt := Vector3(0.0, 2.0, 0.0)
	if current_layout != null and not current_layout.landmarks.is_empty():
		var lm: Dictionary = current_layout.landmarks[0]
		var lc: Vector2 = lm["center"]
		spawn_pt = Vector3(lc.x, float(lm["target_height"]) + 0.1, lc.y + 5.0)
	elif current_layout != null:
		var h0 := terrain_generator.sample_height_only(
			0.0, 0.0, current_layout, region_generator, height_scale, barrier_height_scale
		)
		spawn_pt = Vector3(0.0, h0 + 0.1, 0.0)

	_test_player.stop_movement()
	_test_player.global_position = spawn_pt

	var rig := get_node_or_null("../IsometricCameraRig") as IsometricCameraRig
	if rig != null:
		rig.set_follow_target(_test_player, true)


func _append_clipped_chunk_nav_faces(
	faces: PackedVector3Array,
	grid_info: Dictionary,
	delta_pos: Vector3,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float
) -> void:
	var subs: int = int(grid_info["subdivisions"])
	var step: float = float(grid_info["step"])
	var hdata: PackedFloat32Array = grid_info["heightmap"]
	var vert_dim := subs + 1

	var ix0 := clampi(floori((min_x - delta_pos.x) / step), 0, subs - 1)
	var ix1 := clampi(ceili((max_x - delta_pos.x) / step) - 1, 0, subs - 1)
	var iz0 := clampi(floori((min_z - delta_pos.z) / step), 0, subs - 1)
	var iz1 := clampi(ceili((max_z - delta_pos.z) / step) - 1, 0, subs - 1)
	if ix1 < ix0 or iz1 < iz0:
		return

	var old_sz := faces.size()
	var quad_cnt := (ix1 - ix0 + 1) * (iz1 - iz0 + 1)
	faces.resize(old_sz + quad_cnt * 6)
	var ptr := old_sz
	for iz in range(iz0, iz1 + 1):
		var lz0 := float(iz) * step + delta_pos.z
		var lz1 := float(iz + 1) * step + delta_pos.z
		for ix in range(ix0, ix1 + 1):
			var lx0 := float(ix) * step + delta_pos.x
			var lx1 := float(ix + 1) * step + delta_pos.x
			var i00 := iz * vert_dim + ix
			var i10 := i00 + 1
			var i01 := (iz + 1) * vert_dim + ix
			var i11 := i01 + 1
			var v00 := Vector3(lx0, hdata[i00], lz0)
			var v10 := Vector3(lx1, hdata[i10], lz0)
			var v01 := Vector3(lx0, hdata[i01], lz1)
			var v11 := Vector3(lx1, hdata[i11], lz1)
			faces[ptr + 0] = v00
			faces[ptr + 1] = v10
			faces[ptr + 2] = v11
			faces[ptr + 3] = v00
			faces[ptr + 4] = v11
			faces[ptr + 5] = v01
			ptr += 6


func _collect_landmark_obstacles(inst: Node3D, out_list: Array) -> void:
	var lm_body := inst.get_node_or_null("LandmarkBody") as StaticBody3D
	if lm_body == null:
		return
	for child in lm_body.get_children():
		var cs := child as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		if cs.shape is CylinderShape3D:
			var cshape := cs.shape as CylinderShape3D
			var bottom_y := cs.position.y - cshape.height * 0.5
			if bottom_y > 1.65:
				continue
			out_list.append({
				"kind": &"cyl",
				"pos": Vector3(inst.position.x + cs.position.x, inst.position.y, inst.position.z + cs.position.z),
				"radius": cshape.radius,
			})
		elif cs.shape is BoxShape3D:
			var bshape := cs.shape as BoxShape3D
			var bottom_y := cs.position.y - bshape.size.y * 0.5
			if bottom_y > 1.65:
				continue
			out_list.append({
				"kind": &"box",
				"pos": Vector3(inst.position.x + cs.position.x, inst.position.y, inst.position.z + cs.position.z),
				"half_ext": Vector2(bshape.size.x * 0.5 + 0.06, bshape.size.z * 0.5 + 0.06),
				"rot_y": cs.rotation.y,
			})


func _bake_all_chunk_navmeshes(
	chunk_nodes: Dictionary,
	chunk_nav_grids: Dictionary,
	chunk_obstacles: Dictionary
) -> void:
	if is_inside_tree():
		var map_rid := get_world_3d().navigation_map
		if map_rid.is_valid():
			NavigationServer3D.map_set_active(map_rid, true)
			NavigationServer3D.map_set_use_async_iterations(map_rid, false)
			NavigationServer3D.map_set_cell_size(map_rid, nav_cell_size)
			NavigationServer3D.map_set_cell_height(map_rid, nav_cell_height)
			NavigationServer3D.map_set_edge_connection_margin(map_rid, maxf(1.20, nav_cell_size * 1.5))

	var grid_chunks: int = current_layout.get_grid_chunk_count()
	var c_len := float(chunk_size)
	var min_y := _last_min_height - 8.0
	var box_h := maxf(28.0, (_last_max_height - _last_min_height) + 28.0)
	var expanded_aabb := AABB(
		Vector3(-nav_border_size, min_y, -nav_border_size),
		Vector3(c_len + 2.0 * nav_border_size, box_h, c_len + 2.0 * nav_border_size)
	)
	var exact_aabb := AABB(
		Vector3(0.0, min_y, 0.0),
		Vector3(c_len, box_h, c_len)
	)
	var active_aabb := expanded_aabb
	var verified_bounds := false
	var margin := nav_border_size + 3.0

	for cz in range(grid_chunks):
		for cx in range(grid_chunks):
			var coord := Vector2i(cx, cz)
			var chunk_node := chunk_nodes.get(coord) as Node3D
			if chunk_node == null:
				continue

			var source_geom := NavigationMeshSourceGeometryData3D.new()
			var terrain_faces := PackedVector3Array()
			var obs_faces := PackedVector3Array()
			for nz in range(maxi(0, cz - 1), mini(grid_chunks, cz + 2)):
				for nx in range(maxi(0, cx - 1), mini(grid_chunks, cx + 2)):
					var nb_coord := Vector2i(nx, nz)
					var nb_node := chunk_nodes.get(nb_coord) as Node3D
					if nb_node == null:
						continue
					var delta_pos := nb_node.position - chunk_node.position
					var nb_grid: Dictionary = chunk_nav_grids.get(nb_coord, {})
					if not nb_grid.is_empty():
						_append_clipped_chunk_nav_faces(
							terrain_faces, nb_grid, delta_pos,
							-margin, c_len + margin, -margin, c_len + margin
						)

					var nb_obs: Array = chunk_obstacles.get(nb_coord, [])
					if not nb_obs.is_empty():
						for obs_var in nb_obs:
							var obs: Dictionary = obs_var
							var rel_pos: Vector3 = (obs["pos"] as Vector3) + delta_pos
							if rel_pos.x < -margin or rel_pos.x > c_len + margin or rel_pos.z < -margin or rel_pos.z > c_len + margin:
								continue
							if obs["kind"] == &"cyl":
								_append_corrugated_cylinder_faces(obs_faces, rel_pos.x, rel_pos.z, rel_pos.y, float(obs["radius"]))
							else:
								var he: Vector2 = obs["half_ext"]
								_append_corrugated_box_faces(obs_faces, rel_pos.x, rel_pos.z, rel_pos.y, he.x, he.y, float(obs["rot_y"]))

			if not terrain_faces.is_empty():
				source_geom.add_faces(terrain_faces, Transform3D.IDENTITY)
			if not obs_faces.is_empty():
				source_geom.add_faces(obs_faces, Transform3D.IDENTITY)

			var nav_mesh := _create_chunk_navmesh(active_aabb)
			NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source_geom)

			if not verified_bounds and nav_mesh.get_polygon_count() > 0:
				verified_bounds = true
				var verts := nav_mesh.get_vertices()
				var out_of_bounds := false
				for v in verts:
					if v.x < -0.1 or v.x > c_len + 0.1 or v.z < -0.1 or v.z > c_len + 0.1:
						out_of_bounds = true
						break
				if out_of_bounds:
					active_aabb = exact_aabb
					nav_mesh = _create_chunk_navmesh(active_aabb)
					NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source_geom)

			var nav_region := NavigationRegion3D.new()
			nav_region.name = "ChunkNavRegion"
			nav_region.navigation_mesh = nav_mesh
			chunk_node.add_child(nav_region)

			_last_nav_region_count += 1
			_last_nav_poly_count += nav_mesh.get_polygon_count()


func _create_chunk_navmesh(baking_aabb: AABB) -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.cell_size = nav_cell_size
	nm.cell_height = nav_cell_height
	nm.agent_height = nav_agent_height
	nm.agent_radius = nav_agent_radius
	nm.agent_max_climb = nav_agent_max_climb
	nm.agent_max_slope = nav_agent_max_slope
	nm.region_min_size = 2.0
	nm.edge_max_error = 1.5
	nm.detail_sample_distance = 12.0
	nm.detail_sample_max_error = 2.4
	nm.border_size = nav_border_size
	nm.filter_baking_aabb = baking_aabb
	return nm


static func _append_corrugated_cylinder_faces(
	faces: PackedVector3Array,
	cx: float,
	cz: float,
	base_y: float,
	radius: float
) -> void:
	var y_bot := base_y - 1.2
	var y_lo := base_y + 1.00
	var y_hi := base_y + 1.45
	var sides := 8
	var num_rings := maxi(2, ceili(radius / 0.22))

	var prev_r := 0.0
	var prev_y := y_lo if (num_rings % 2 == 0) else y_hi
	for ri in range(1, num_rings + 1):
		var r_cur := radius * float(ri) / float(num_rings)
		var y_cur := y_lo if ((num_rings - ri) % 2 == 0) else y_hi
		for s in range(sides):
			var a0 := float(s) * TAU / float(sides)
			var a1 := float(s + 1) * TAU / float(sides)
			var c0 := cos(a0)
			var s0 := sin(a0)
			var c1 := cos(a1)
			var s1 := sin(a1)
			if ri == 1:
				var vc := Vector3(cx, prev_y, cz)
				var p0 := Vector3(cx + c0 * r_cur, y_cur, cz + s0 * r_cur)
				var p1 := Vector3(cx + c1 * r_cur, y_cur, cz + s1 * r_cur)
				faces.append(vc)
				faces.append(p0)
				faces.append(p1)
			else:
				var i0 := Vector3(cx + c0 * prev_r, prev_y, cz + s0 * prev_r)
				var i1 := Vector3(cx + c1 * prev_r, prev_y, cz + s1 * prev_r)
				var o0 := Vector3(cx + c0 * r_cur, y_cur, cz + s0 * r_cur)
				var o1 := Vector3(cx + c1 * r_cur, y_cur, cz + s1 * r_cur)
				faces.append(i0)
				faces.append(o0)
				faces.append(o1)
				faces.append(i0)
				faces.append(o1)
				faces.append(i1)
		prev_r = r_cur
		prev_y = y_cur

	# Vertical perimeter wall from y_bot up to outer rim y_lo
	for s in range(sides):
		var a0 := float(s) * TAU / float(sides)
		var a1 := float(s + 1) * TAU / float(sides)
		var b0 := Vector3(cx + cos(a0) * radius, y_bot, cz + sin(a0) * radius)
		var b1 := Vector3(cx + cos(a1) * radius, y_bot, cz + sin(a1) * radius)
		var t0 := Vector3(b0.x, y_lo, b0.z)
		var t1 := Vector3(b1.x, y_lo, b1.z)
		faces.append(b0)
		faces.append(t0)
		faces.append(t1)
		faces.append(b0)
		faces.append(t1)
		faces.append(b1)


static func _append_corrugated_box_faces(
	faces: PackedVector3Array,
	cx: float,
	cz: float,
	base_y: float,
	hx: float,
	hz: float,
	rot_y: float
) -> void:
	var y_bot := base_y - 1.2
	var y_lo := base_y + 1.00
	var y_hi := base_y + 1.45
	var nx := maxi(2, ceili((2.0 * hx) / 0.22))
	if nx % 2 != 0:
		nx += 1
	var b_rot := Basis(Vector3.UP, rot_y)
	var center := Vector3(cx, 0.0, cz)

	# Corrugated roof strips along X (every triangle spans y_lo <-> y_hi with >= 61 deg slope)
	for ix in range(nx):
		var x0 := lerpf(-hx, hx, float(ix) / float(nx))
		var x1 := lerpf(-hx, hx, float(ix + 1) / float(nx))
		var y0 := y_lo if (ix % 2 == 0) else y_hi
		var y1 := y_lo if ((ix + 1) % 2 == 0) else y_hi

		var p00 := center + b_rot * Vector3(x0, y0, -hz)
		var p10 := center + b_rot * Vector3(x1, y1, -hz)
		var p01 := center + b_rot * Vector3(x0, y0, hz)
		var p11 := center + b_rot * Vector3(x1, y1, hz)
		faces.append(p00)
		faces.append(p10)
		faces.append(p11)
		faces.append(p00)
		faces.append(p11)
		faces.append(p01)

		# North (-hz) and South (+hz) vertical wall segments matching roof sawtooth profile
		var nb0 := center + b_rot * Vector3(x0, y_bot, -hz)
		var nb1 := center + b_rot * Vector3(x1, y_bot, -hz)
		faces.append(nb1)
		faces.append(p10)
		faces.append(p00)
		faces.append(nb1)
		faces.append(p00)
		faces.append(nb0)

		var sb0 := center + b_rot * Vector3(x0, y_bot, hz)
		var sb1 := center + b_rot * Vector3(x1, y_bot, hz)
		faces.append(sb0)
		faces.append(p01)
		faces.append(p11)
		faces.append(sb0)
		faces.append(p11)
		faces.append(sb1)

	# West (-hx) and East (+hx) vertical walls (both at y_lo since nx is even)
	var w_b0 := center + b_rot * Vector3(-hx, y_bot, hz)
	var w_b1 := center + b_rot * Vector3(-hx, y_bot, -hz)
	var w_t0 := center + b_rot * Vector3(-hx, y_lo, hz)
	var w_t1 := center + b_rot * Vector3(-hx, y_lo, -hz)
	faces.append(w_b0)
	faces.append(w_t0)
	faces.append(w_t1)
	faces.append(w_b0)
	faces.append(w_t1)
	faces.append(w_b1)

	var e_b0 := center + b_rot * Vector3(hx, y_bot, -hz)
	var e_b1 := center + b_rot * Vector3(hx, y_bot, hz)
	var e_t0 := center + b_rot * Vector3(hx, y_lo, -hz)
	var e_t1 := center + b_rot * Vector3(hx, y_lo, hz)
	faces.append(e_b0)
	faces.append(e_t0)
	faces.append(e_t1)
	faces.append(e_b0)
	faces.append(e_t1)
	faces.append(e_b1)
