class_name StylizedPropLibrary
extends RefCounted

## Builds hand-painted League of Legends / Summoner's Rift procedural 3D props
## (distinct tree body archetypes with RGBA alpha-cutout leaf cluster clouds and
## spherical normal transfer, intersecting alpha grass tufts, and rune rock monoliths)
## and populates default ScatterRules on BiomeConfig resources when none are assigned.

const SHADER_PAINTERLY_PATH := "res://shaders/arcane_town_painterly.gdshader"
const SHADER_FOLIAGE_PATH := "res://shaders/lol_swaying_foliage.gdshader"

const TEX_BARK_PATH := "res://addons/lorencia_town/Lorencia_Town_T_LoL_Walnut_Wood.png"
const TEX_STONE_PATH := "res://addons/lorencia_town/Lorencia_Town_T_LoL_Weathered_Stone.png"
const TEX_LEAVES_GREEN_PATH := "res://addons/lorencia_town/Lorencia_Town_T_Real_Palia_Leaves.png"
const TEX_LEAVES_BLOSSOM_PATH := "res://addons/lorencia_town/Lorencia_Town_T_LoL_Blossom_Leaves.png"
const TEX_GRASS_ALPHA_PATH := "res://addons/lorencia_town/Lorencia_Town_T_LoL_Grass_Tuft_Alpha.png"

static var _cached_materials: Dictionary = {}
static var _cached_meshes: Dictionary = {}


static func ensure_biome_scatter_rules(biomes: Array[BiomeConfig]) -> void:
	for b in biomes:
		if b == null:
			continue
		if b.scatter_rules.is_empty():
			b.scatter_rules = build_default_rules_for_biome(b.biome_id)


static func build_default_rules_for_biome(biome_id: StringName) -> Array[ScatterRule]:
	var rules: Array[ScatterRule] = []
	match biome_id:
		&"temperate_forest":
			rules.append(_make_rule("Elder Hollow Sakura", _get_mesh(&"tree_elder_shrine"), 0.26, 11.0, Vector2(0.5, 45.0), 26.0, Vector2(0.95, 1.25), false, true, true, 0.0, 20.0, 0.85, 4.0))
			rules.append(_make_rule("Twin Forked Sakura", _get_mesh(&"tree_twin_sakura"), 0.26, 10.0, Vector2(0.5, 45.0), 26.0, Vector2(0.90, 1.20), false, true, true, 0.0, 20.0, 0.75, 4.0))
			rules.append(_make_rule("Multi-Limb Emerald Oak", _get_mesh(&"tree_emerald_oak"), 0.58, 8.5, Vector2(0.5, 45.0), 28.0, Vector2(0.90, 1.30), false, true, true, 0.0, 20.0, 0.75, 4.0))
			rules.append(_make_rule("Conifer Spire", _get_mesh(&"tree_conifer_0"), 0.36, 8.0, Vector2(4.0, 50.0), 30.0, Vector2(0.85, 1.25), false, true, true, 0.0, 20.0, 0.65, 4.2))
			rules.append(_make_rule("Rift Rune Monolith", _get_mesh(&"monolith_forest"), 0.14, 14.0, Vector2(0.5, 60.0), 34.0, Vector2(0.85, 1.25), true, true, true, 0.0, 20.0, 1.15, 3.6))
			rules.append(_make_rule("Meadow Alpha Grass", _get_mesh(&"grass_emerald"), 25.0, 1.35, Vector2(0.2, 35.0), 28.0, Vector2(0.85, 1.40), true, false, false, 155.0, 22.0))
		&"coastal_plains":
			rules.append(_make_rule("Windswept Canal Bonsai", _get_mesh(&"tree_bonsai_green"), 0.26, 11.0, Vector2(0.4, 30.0), 24.0, Vector2(0.90, 1.25), false, true, true, 0.0, 20.0, 0.75, 3.5))
			rules.append(_make_rule("Coastal Broadleaf Oak", _get_mesh(&"tree_emerald_oak"), 0.30, 12.0, Vector2(0.5, 32.0), 24.0, Vector2(0.85, 1.20), false, true, true, 0.0, 20.0, 0.75, 4.0))
			rules.append(_make_rule("Coastal Rune Stone", _get_mesh(&"monolith_coastal"), 0.16, 14.0, Vector2(0.3, 45.0), 32.0, Vector2(0.85, 1.20), true, true, true, 0.0, 20.0, 1.15, 3.2))
			rules.append(_make_rule("Sunlit Grass Tuft", _get_mesh(&"grass_coastal"), 26.0, 1.35, Vector2(0.2, 28.0), 26.0, Vector2(0.85, 1.40), true, false, false, 155.0, 22.0))
		&"frozen_tundra":
			rules.append(_make_rule("Frost Spire Pine", _get_mesh(&"tree_conifer_tundra_0"), 0.36, 9.5, Vector2(0.5, 55.0), 28.0, Vector2(0.85, 1.25), false, true, true, 0.0, 20.0, 0.65, 4.2))
			rules.append(_make_rule("Old-Growth Cedar", _get_mesh(&"tree_conifer_tundra_1"), 0.32, 10.0, Vector2(0.5, 50.0), 28.0, Vector2(0.85, 1.20), false, true, true, 0.0, 20.0, 0.75, 4.0))
			rules.append(_make_rule("Windswept Ridge Pine", _get_mesh(&"tree_conifer_tundra_3"), 0.26, 10.5, Vector2(2.0, 60.0), 32.0, Vector2(0.80, 1.20), false, true, true, 0.0, 20.0, 0.65, 4.0))
			rules.append(_make_rule("Glacial Rune Monolith", _get_mesh(&"monolith_tundra"), 0.18, 14.0, Vector2(0.5, 65.0), 34.0, Vector2(0.85, 1.30), true, true, true, 0.0, 20.0, 1.15, 3.8))
			rules.append(_make_rule("Frost Tuft Grass", _get_mesh(&"grass_tundra"), 11.5, 1.85, Vector2(0.2, 42.0), 26.0, Vector2(0.80, 1.25), true, false, false, 155.0, 22.0))
		&"desert":
			rules.append(_make_rule("Dryland Desert Bonsai", _get_mesh(&"tree_bonsai_desert"), 0.18, 14.0, Vector2(0.5, 40.0), 22.0, Vector2(0.80, 1.15), false, true, true, 0.0, 20.0, 0.70, 3.2))
			rules.append(_make_rule("Canyon Rune Monolith", _get_mesh(&"monolith_desert"), 0.22, 13.0, Vector2(0.5, 55.0), 34.0, Vector2(0.90, 1.35), true, true, true, 0.0, 20.0, 1.15, 3.6))
			rules.append(_make_rule("Sandstone Outcrop", _get_mesh(&"boulder_desert"), 0.45, 7.5, Vector2(0.3, 60.0), 36.0, Vector2(0.80, 1.40), true, true, true, 250.0, 25.0, 1.25, 2.2))
			rules.append(_make_rule("Arid Scrub Grass", _get_mesh(&"grass_desert"), 10.5, 1.85, Vector2(0.3, 35.0), 24.0, Vector2(0.80, 1.25), true, false, false, 155.0, 22.0))
		&"swamp":
			rules.append(_make_rule("Twisted Swamp Willow", _get_mesh(&"tree_twisted_willow"), 0.56, 8.5, Vector2(0.2, 30.0), 26.0, Vector2(0.90, 1.30), false, true, true, 0.0, 20.0, 0.75, 4.0))
			rules.append(_make_rule("Forked Bog Fir", _get_mesh(&"tree_conifer_2"), 0.36, 9.0, Vector2(0.2, 32.0), 28.0, Vector2(0.85, 1.20), false, true, true, 0.0, 20.0, 0.70, 4.0))
			rules.append(_make_rule("Mossy Swamp Monolith", _get_mesh(&"monolith_swamp"), 0.20, 12.0, Vector2(0.2, 40.0), 34.0, Vector2(0.85, 1.25), true, true, true, 0.0, 20.0, 1.15, 3.4))
			rules.append(_make_rule("Marsh Reed Grass", _get_mesh(&"grass_swamp"), 24.0, 1.35, Vector2(0.15, 25.0), 26.0, Vector2(0.85, 1.40), true, false, false, 155.0, 22.0))
		&"volcanic_highlands":
			rules.append(_make_rule("Scorched Ridge Pine", _get_mesh(&"tree_conifer_volcanic_3"), 0.24, 12.0, Vector2(0.5, 48.0), 26.0, Vector2(0.80, 1.15), false, true, true, 0.0, 20.0, 0.65, 3.8))
			rules.append(_make_rule("Obsidian Rune Monolith", _get_mesh(&"monolith_volcanic"), 0.28, 12.0, Vector2(0.5, 65.0), 36.0, Vector2(0.90, 1.40), true, true, true, 0.0, 20.0, 1.15, 4.0))
			rules.append(_make_rule("Basalt Rock Outcrop", _get_mesh(&"boulder_volcanic"), 0.65, 6.5, Vector2(0.5, 70.0), 38.0, Vector2(0.85, 1.45), true, true, true, 250.0, 25.0, 1.25, 2.2))
			rules.append(_make_rule("Charred Ridge Grass", _get_mesh(&"grass_volcanic"), 9.5, 1.95, Vector2(0.4, 38.0), 26.0, Vector2(0.75, 1.20), true, false, false, 155.0, 22.0))
		_:
			rules.append(_make_rule("Broadleaf Oak", _get_mesh(&"tree_emerald_oak"), 0.45, 9.0, Vector2(0.4, 45.0), 28.0, Vector2(0.90, 1.25), false, true, true, 0.0, 20.0, 0.75, 4.0))
			rules.append(_make_rule("Rune Monolith", _get_mesh(&"monolith_forest"), 0.16, 14.0, Vector2(0.4, 55.0), 32.0, Vector2(0.85, 1.25), true, true, true, 0.0, 20.0, 1.15, 3.6))
			rules.append(_make_rule("Alpha Grass Tuft", _get_mesh(&"grass_emerald"), 20.0, 1.50, Vector2(0.2, 35.0), 28.0, Vector2(0.80, 1.35), true, false, false, 155.0, 22.0))
	return rules


static func _make_rule(
	rname: String,
	p_mesh: Mesh,
	density: float,
	spacing: float,
	h_range: Vector2,
	max_slope: float,
	s_range: Vector2,
	align_norm: bool,
	blocks_nav: bool,
	shadows: bool,
	vis_end: float = 0.0,
	vis_margin: float = 20.0,
	col_rad: float = 0.65,
	col_h: float = 3.5
) -> ScatterRule:
	var r := ScatterRule.new()
	r.rule_name = rname
	r.mesh = p_mesh
	r.density_per_100m2 = density
	r.min_spacing = spacing
	r.height_range = h_range
	r.max_slope_degrees = max_slope
	r.scale_range = s_range
	r.align_to_normal = align_norm
	r.blocks_navigation = blocks_nav
	r.cast_shadows = shadows
	r.visibility_range_end = vis_end
	r.visibility_range_fade_margin = vis_margin
	r.collision_radius = col_rad
	r.collision_height = col_h
	return r


static func _get_mesh(key: StringName) -> ArrayMesh:
	if _cached_meshes.has(key):
		return _cached_meshes[key] as ArrayMesh

	var m: ArrayMesh
	match key:
		&"tree_elder_shrine":
			m = _build_tree_elder_hollow_shrine()
		&"tree_twin_sakura":
			m = _build_tree_twin_forked_sakura()
		&"tree_emerald_oak":
			m = _build_tree_multi_limb_emerald_oak()
		&"tree_bonsai_green":
			m = _build_tree_windswept_bonsai(_get_foliage_mat(&"green"), Color(0.76, 0.90, 0.72), Color(1.04, 1.06, 0.88))
		&"tree_bonsai_desert":
			m = _build_tree_windswept_bonsai(_get_foliage_mat(&"green"), Color(0.68, 0.64, 0.42), Color(0.96, 0.86, 0.56))
		&"tree_twisted_willow":
			m = _build_tree_twisted_willow()
		&"tree_conifer_0":
			m = _build_tree_conifer_pine(0, _get_foliage_mat(&"green"), Color(0.62, 0.78, 0.64), Color(0.95, 1.02, 0.86))
		&"tree_conifer_2":
			m = _build_tree_conifer_pine(2, _get_foliage_mat(&"green"), Color(0.48, 0.64, 0.54), Color(0.78, 0.88, 0.70))
		&"tree_conifer_tundra_0":
			m = _build_tree_conifer_pine(0, _get_foliage_mat(&"green"), Color(0.66, 0.82, 0.88), Color(0.96, 1.02, 1.06))
		&"tree_conifer_tundra_1":
			m = _build_tree_conifer_pine(1, _get_foliage_mat(&"green"), Color(0.64, 0.80, 0.86), Color(0.94, 1.00, 1.04))
		&"tree_conifer_tundra_3":
			m = _build_tree_conifer_pine(3, _get_foliage_mat(&"green"), Color(0.66, 0.82, 0.88), Color(0.96, 1.02, 1.06))
		&"tree_conifer_volcanic_3":
			m = _build_tree_conifer_pine(3, _get_foliage_mat(&"green"), Color(0.36, 0.30, 0.28), Color(0.64, 0.48, 0.38))
		&"monolith_forest":
			m = _build_rift_rune_monolith(Color(0.74, 0.80, 0.78), Color(0.18, 0.88, 0.94), 3.4, 101)
		&"monolith_coastal":
			m = _build_rift_rune_monolith(Color(0.88, 0.90, 0.84), Color(0.20, 0.90, 0.92), 3.0, 202)
		&"monolith_tundra":
			m = _build_rift_rune_monolith(Color(0.68, 0.78, 0.92), Color(0.34, 0.94, 1.00), 3.8, 303)
		&"monolith_desert":
			m = _build_rift_rune_monolith(Color(0.96, 0.76, 0.56), Color(0.24, 0.90, 0.86), 3.6, 404)
		&"monolith_swamp":
			m = _build_rift_rune_monolith(Color(0.60, 0.72, 0.62), Color(0.28, 0.92, 0.78), 3.2, 505)
		&"monolith_volcanic":
			m = _build_rift_rune_monolith(Color(0.46, 0.42, 0.46), Color(1.00, 0.54, 0.20), 4.0, 606)
		&"boulder_desert":
			m = _build_stylized_boulder_cluster(Color(0.92, 0.72, 0.52), 707)
		&"boulder_volcanic":
			m = _build_stylized_boulder_cluster(Color(0.42, 0.38, 0.42), 808)
		&"grass_emerald":
			m = _build_alpha_grass_tuft_cluster(Color(0.76, 0.92, 0.68), Color(1.02, 1.08, 0.82))
		&"grass_coastal":
			m = _build_alpha_grass_tuft_cluster(Color(0.84, 0.96, 0.66), Color(1.08, 1.12, 0.82))
		&"grass_tundra":
			m = _build_alpha_grass_tuft_cluster(Color(0.76, 0.88, 0.96), Color(0.98, 1.04, 1.08))
		&"grass_desert":
			m = _build_alpha_grass_tuft_cluster(Color(0.88, 0.74, 0.46), Color(1.06, 0.94, 0.62))
		&"grass_swamp":
			m = _build_alpha_grass_tuft_cluster(Color(0.56, 0.76, 0.62), Color(0.82, 0.96, 0.72))
		&"grass_volcanic":
			m = _build_alpha_grass_tuft_cluster(Color(0.52, 0.44, 0.38), Color(0.78, 0.58, 0.44))
		_:
			m = _build_alpha_grass_tuft_cluster(Color(0.80, 0.94, 0.70), Color(1.04, 1.08, 0.86))

	_cached_meshes[key] = m
	return m


static func _get_painterly_mat(key: StringName, tex_path: String, albedo_tint: Color) -> Material:
	var cache_id := "%s_%s" % [String(key), albedo_tint.to_html(false)]
	if _cached_materials.has(cache_id):
		return _cached_materials[cache_id] as Material

	var shader := load(SHADER_PAINTERLY_PATH) as Shader
	var tex := load(tex_path) as Texture2D
	if shader != null:
		var smat := ShaderMaterial.new()
		smat.shader = shader
		smat.set_shader_parameter("use_texture", tex != null)
		if tex != null:
			smat.set_shader_parameter("albedo_texture", tex)
		smat.set_shader_parameter("albedo_color", albedo_tint)
		smat.set_shader_parameter("emission_strength", 0.0)
		_cached_materials[cache_id] = smat
		return smat

	var std := StandardMaterial3D.new()
	std.albedo_texture = tex
	std.albedo_color = albedo_tint
	std.vertex_color_use_as_albedo = true
	std.roughness = 0.94
	std.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_cached_materials[cache_id] = std
	return std


static func _get_foliage_mat(kind: StringName) -> Material:
	var cache_id := "foliage_%s" % String(kind)
	if _cached_materials.has(cache_id):
		return _cached_materials[cache_id] as Material

	var tex_path: String
	var sway_str: float
	if kind == &"blossom":
		tex_path = TEX_LEAVES_BLOSSOM_PATH
		sway_str = 0.032
	elif kind == &"grass":
		tex_path = TEX_GRASS_ALPHA_PATH
		sway_str = 0.014
	else:
		tex_path = TEX_LEAVES_GREEN_PATH
		sway_str = 0.032

	var shader := load(SHADER_FOLIAGE_PATH) as Shader
	var tex := load(tex_path) as Texture2D
	if shader != null:
		var smat := ShaderMaterial.new()
		smat.shader = shader
		smat.set_shader_parameter("use_texture", tex != null)
		if tex != null:
			smat.set_shader_parameter("albedo_texture", tex)
		smat.set_shader_parameter("albedo_color", Color.WHITE)
		smat.set_shader_parameter("sway_speed", 1.35)
		smat.set_shader_parameter("sway_strength", sway_str)
		_cached_materials[cache_id] = smat
		return smat

	var std := StandardMaterial3D.new()
	std.albedo_texture = tex
	std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	std.alpha_scissor_threshold = 0.42
	std.cull_mode = BaseMaterial3D.CULL_DISABLED
	std.vertex_color_use_as_albedo = true
	std.roughness = 0.94
	std.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_cached_materials[cache_id] = std
	return std


static func _get_rune_mat(rune_color: Color) -> Material:
	var cache_id := "rune_%s" % rune_color.to_html(false)
	if _cached_materials.has(cache_id):
		return _cached_materials[cache_id] as Material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = rune_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	_cached_materials[cache_id] = mat
	return mat


# --- 6 Distinct Tree Body Archetypes (Bark Surface 0 + Alpha Leaf Card Surface 1) ---

static func _build_tree_elder_hollow_shrine() -> ArrayMesh:
	var bark_st := SurfaceTool.new()
	bark_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_root := Color(0.46, 0.36, 0.34)
	var c_tip := Color(0.84, 0.72, 0.66)
	# 3 arched wishbone hollow-root legs converging at y=1.3m
	for r_i in range(3):
		var ang := float(r_i) * TAU / 3.0 + 0.3
		var dx := cos(ang)
		var dz := sin(ang)
		_add_tapered_branch(bark_st, [
			Vector3(dx * 0.92, -0.05, dz * 0.92),
			Vector3(dx * 0.62, 0.65, dz * 0.62),
			Vector3(dx * 0.18, 1.35, dz * 0.18),
		], [0.22, 0.18, 0.24], 6, c_root, c_tip * 0.88)

	# S-curved main trunk rising from hollow convergence
	_add_tapered_branch(bark_st, [
		Vector3(0.0, 1.2, 0.0),
		Vector3(0.28, 2.3, -0.15),
		Vector3(-0.22, 3.5, 0.20),
		Vector3(0.12, 4.7, 0.05),
	], [0.32, 0.26, 0.20, 0.12], 7, c_root * 1.1, c_tip)

	# 3 spreading shrine limbs with tiered Spirit Blossom clouds
	var limb_targets := [
		[Vector3(-0.18, 3.3, 0.18), Vector3(-1.35, 4.1, 0.95), Vector3(-2.1, 4.4, 1.3)],
		[Vector3(0.10, 3.8, -0.05), Vector3(1.45, 4.5, -0.75), Vector3(2.0, 4.9, -1.0)],
		[Vector3(0.12, 4.5, 0.05), Vector3(-0.25, 5.4, -0.65), Vector3(-0.4, 5.9, -0.9)],
	]
	for limb in limb_targets:
		_add_tapered_branch(bark_st, limb, [0.16, 0.11, 0.06], 5, c_tip * 0.9, c_tip)

	var c_cool := Color(0.68, 0.56, 0.72)
	var c_warm := Color(1.06, 0.96, 1.02)
	_add_alpha_leaf_cloud(leaf_st, Vector3(0.05, 5.75, -0.25), 2.15, 1.35, 16, 11, c_cool, c_warm)
	_add_alpha_leaf_cloud(leaf_st, Vector3(-1.85, 4.45, 1.15), 1.65, 1.05, 11, 22, c_cool, c_warm)
	_add_alpha_leaf_cloud(leaf_st, Vector3(1.80, 4.85, -0.90), 1.55, 1.00, 11, 33, c_cool, c_warm)

	return _commit_two_surface_mesh(
		bark_st, _get_painterly_mat(&"bark", TEX_BARK_PATH, Color(0.76, 0.66, 0.62)),
		leaf_st, _get_foliage_mat(&"blossom")
	)


static func _build_tree_windswept_bonsai(leaf_mat: Material, c_cool: Color, c_warm: Color) -> ArrayMesh:
	var bark_st := SurfaceTool.new()
	bark_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_root := Color(0.45, 0.38, 0.32)
	var c_tip := Color(0.84, 0.76, 0.66)
	# Sweeping low S-bend trunk leaning strongly horizontally
	_add_tapered_branch(bark_st, [
		Vector3(-0.45, -0.05, 0.0),
		Vector3(-0.10, 0.95, 0.18),
		Vector3(0.85, 1.85, -0.22),
		Vector3(1.85, 2.55, 0.10),
		Vector3(2.45, 3.10, 0.25),
	], [0.34, 0.26, 0.20, 0.14, 0.08], 7, c_root, c_tip)

	_add_tapered_branch(bark_st, [
		Vector3(0.65, 1.75, -0.15),
		Vector3(0.25, 2.65, -0.85),
	], [0.14, 0.07], 5, c_tip * 0.9, c_tip)

	# Flat tiered horizontal floating foliage shelves
	_add_alpha_leaf_cloud(leaf_st, Vector3(2.25, 3.35, 0.22), 1.85, 0.72, 13, 44, c_cool, c_warm)
	_add_alpha_leaf_cloud(leaf_st, Vector3(0.25, 2.85, -0.85), 1.45, 0.62, 10, 55, c_cool, c_warm)
	_add_alpha_leaf_cloud(leaf_st, Vector3(1.10, 2.30, 0.65), 1.25, 0.55, 9, 66, c_cool, c_warm)

	return _commit_two_surface_mesh(
		bark_st, _get_painterly_mat(&"bark", TEX_BARK_PATH, Color(0.78, 0.68, 0.56)),
		leaf_st, leaf_mat
	)


static func _build_tree_twin_forked_sakura() -> ArrayMesh:
	var bark_st := SurfaceTool.new()
	bark_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_root := Color(0.46, 0.36, 0.35)
	var c_tip := Color(0.86, 0.74, 0.68)
	# Short base trunk splitting into opposing -34 deg and +28 deg V-trunks
	_add_tapered_branch(bark_st, [
		Vector3(0.0, -0.05, 0.0),
		Vector3(0.04, 0.75, 0.0),
	], [0.34, 0.28], 7, c_root, c_tip * 0.85)

	_add_tapered_branch(bark_st, [
		Vector3(0.04, 0.65, 0.0),
		Vector3(-0.95, 2.15, 0.30),
		Vector3(-1.75, 3.55, 0.45),
	], [0.22, 0.16, 0.09], 6, c_root * 1.1, c_tip)

	_add_tapered_branch(bark_st, [
		Vector3(0.04, 0.65, 0.0),
		Vector3(0.85, 2.35, -0.25),
		Vector3(1.45, 4.25, -0.45),
	], [0.24, 0.17, 0.09], 6, c_root * 1.1, c_tip)

	var c_cool := Color(0.68, 0.56, 0.72)
	var c_warm := Color(1.06, 0.98, 1.02)
	_add_alpha_leaf_cloud(leaf_st, Vector3(-1.70, 3.75, 0.45), 1.85, 1.15, 13, 77, c_cool, c_warm)
	_add_alpha_leaf_cloud(leaf_st, Vector3(1.45, 4.55, -0.45), 2.05, 1.30, 15, 88, c_cool, c_warm)

	return _commit_two_surface_mesh(
		bark_st, _get_painterly_mat(&"bark", TEX_BARK_PATH, Color(0.76, 0.66, 0.62)),
		leaf_st, _get_foliage_mat(&"blossom")
	)


static func _build_tree_twisted_willow() -> ArrayMesh:
	var bark_st := SurfaceTool.new()
	bark_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_root := Color(0.38, 0.36, 0.30)
	var c_tip := Color(0.72, 0.70, 0.58)
	# Corkscrew upright trunk branching into weeping dome
	_add_tapered_branch(bark_st, [
		Vector3(0.0, -0.05, 0.0),
		Vector3(0.28, 1.25, 0.22),
		Vector3(-0.24, 2.55, 0.18),
		Vector3(0.16, 3.85, -0.18),
		Vector3(0.0, 4.95, 0.0),
	], [0.36, 0.28, 0.22, 0.16, 0.10], 7, c_root, c_tip)

	for i in range(4):
		var a := float(i) * TAU / 4.0 + 0.4
		var dx := cos(a)
		var dz := sin(a)
		_add_tapered_branch(bark_st, [
			Vector3(dx * 0.1, 3.9, dz * 0.1),
			Vector3(dx * 1.3, 4.6, dz * 1.3),
			Vector3(dx * 1.9, 4.2, dz * 1.9),
		], [0.13, 0.09, 0.05], 5, c_tip * 0.9, c_tip)

	var c_cool := Color(0.46, 0.66, 0.54)
	var c_warm := Color(0.78, 0.94, 0.68)
	_add_alpha_leaf_cloud(leaf_st, Vector3(0.0, 5.25, 0.0), 2.30, 1.45, 16, 99, c_cool, c_warm)
	_add_alpha_leaf_cloud(leaf_st, Vector3(-1.4, 3.85, 1.1), 1.55, 1.55, 11, 110, c_cool, c_warm)
	_add_alpha_leaf_cloud(leaf_st, Vector3(1.5, 3.95, -0.9), 1.55, 1.55, 11, 121, c_cool, c_warm)

	return _commit_two_surface_mesh(
		bark_st, _get_painterly_mat(&"bark", TEX_BARK_PATH, Color(0.64, 0.62, 0.50)),
		leaf_st, _get_foliage_mat(&"green")
	)


static func _build_tree_multi_limb_emerald_oak() -> ArrayMesh:
	var bark_st := SurfaceTool.new()
	bark_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_root := Color(0.42, 0.34, 0.28)
	var c_tip := Color(0.78, 0.68, 0.56)
	_add_tapered_branch(bark_st, [
		Vector3(0.0, -0.05, 0.0),
		Vector3(-0.18, 1.15, 0.14),
		Vector3(0.10, 2.45, -0.10),
	], [0.42, 0.30, 0.24], 7, c_root, c_tip)

	var limb_dirs := [
		Vector3(-1.65, 3.75, 0.85),
		Vector3(1.55, 3.95, 0.95),
		Vector3(0.95, 4.25, -1.45),
		Vector3(-0.85, 4.75, -0.95),
	]
	var c_cool := Color(0.58, 0.78, 0.56)
	var c_warm := Color(0.96, 1.06, 0.78)
	for idx in range(limb_dirs.size()):
		var end_pt: Vector3 = limb_dirs[idx]
		var mid_pt: Vector3 = Vector3(0.1, 2.4, -0.1).lerp(end_pt, 0.5) + Vector3(0.0, 0.35, 0.0)
		_add_tapered_branch(bark_st, [Vector3(0.1, 2.35, -0.1), mid_pt, end_pt], [0.16, 0.11, 0.06], 5, c_tip * 0.9, c_tip)
		_add_alpha_leaf_cloud(leaf_st, end_pt + Vector3(0.0, 0.45, 0.0), 1.85, 1.20, 12, 200 + idx * 17, c_cool, c_warm)

	_add_alpha_leaf_cloud(leaf_st, Vector3(0.0, 4.95, 0.0), 2.15, 1.35, 14, 290, c_cool, c_warm)

	return _commit_two_surface_mesh(
		bark_st, _get_painterly_mat(&"bark", TEX_BARK_PATH, Color(0.74, 0.64, 0.54)),
		leaf_st, _get_foliage_mat(&"green")
	)


static func _build_tree_conifer_pine(variant: int, leaf_mat: Material, c_cool: Color, c_warm: Color) -> ArrayMesh:
	var bark_st := SurfaceTool.new()
	bark_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_root := Color(0.40, 0.32, 0.28)
	var c_tip := Color(0.74, 0.64, 0.54)

	if variant == 0:
		# Crooked mountain spire (5 staggered tiers of alpha leaf cards)
		_add_tapered_branch(bark_st, [
			Vector3(0.0, -0.05, 0.0),
			Vector3(0.18, 2.0, -0.12),
			Vector3(-0.12, 4.2, 0.14),
			Vector3(0.08, 6.2, 0.0),
		], [0.30, 0.22, 0.14, 0.06], 6, c_root, c_tip)
		for t in range(5):
			var frac := float(t) / 4.0
			var cy := 2.0 + frac * 4.0
			var rad := lerpf(1.95, 0.72, frac)
			_add_alpha_leaf_cloud(leaf_st, Vector3(sin(float(t) * 1.4) * 0.16, cy, 0.0), rad, 0.82, 10 - t, 310 + t * 9, c_cool, c_warm)
	elif variant == 1:
		# Squat old-growth cedar
		_add_tapered_branch(bark_st, [
			Vector3(0.0, -0.05, 0.0),
			Vector3(-0.14, 1.7, 0.10),
			Vector3(0.08, 3.6, -0.08),
			Vector3(0.0, 4.8, 0.0),
		], [0.38, 0.28, 0.18, 0.08], 7, c_root, c_tip)
		for t in range(4):
			var frac := float(t) / 3.0
			var cy := 1.7 + frac * 2.9
			var rad := lerpf(2.25, 1.05, frac)
			_add_alpha_leaf_cloud(leaf_st, Vector3(0.0, cy, 0.0), rad, 0.90, 12 - t, 410 + t * 11, c_cool, c_warm)
	elif variant == 2:
		# Twin-stemmed forked fir
		_add_tapered_branch(bark_st, [Vector3(0.0, -0.05, 0.0), Vector3(0.0, 0.9, 0.0)], [0.32, 0.26], 6, c_root, c_tip)
		_add_tapered_branch(bark_st, [Vector3(0.0, 0.85, 0.0), Vector3(-0.65, 2.9, 0.25), Vector3(-0.85, 4.9, 0.30)], [0.19, 0.12, 0.06], 5, c_root * 1.1, c_tip)
		_add_tapered_branch(bark_st, [Vector3(0.0, 0.85, 0.0), Vector3(0.60, 3.2, -0.20), Vector3(0.80, 5.6, -0.25)], [0.21, 0.14, 0.06], 5, c_root * 1.1, c_tip)
		for t in range(3):
			_add_alpha_leaf_cloud(leaf_st, Vector3(-0.78, 2.3 + float(t) * 1.15, 0.28), 1.45 - float(t) * 0.30, 0.78, 9, 510 + t * 7, c_cool, c_warm)
			_add_alpha_leaf_cloud(leaf_st, Vector3(0.72, 2.5 + float(t) * 1.30, -0.22), 1.55 - float(t) * 0.32, 0.82, 9, 550 + t * 7, c_cool, c_warm)
	else:
		# Windswept ridge pine
		_add_tapered_branch(bark_st, [
			Vector3(-0.20, -0.05, 0.0),
			Vector3(0.25, 1.8, 0.15),
			Vector3(0.95, 3.5, 0.22),
			Vector3(1.35, 5.1, 0.10),
		], [0.30, 0.22, 0.15, 0.07], 6, c_root, c_tip)
		for t in range(4):
			var frac := float(t) / 3.0
			var cx := lerpf(0.25, 1.35, frac)
			var cy := lerpf(2.0, 5.0, frac)
			_add_alpha_leaf_cloud(leaf_st, Vector3(cx, cy, 0.15), lerpf(1.70, 0.78, frac), 0.78, 10 - t, 610 + t * 13, c_cool, c_warm)

	return _commit_two_surface_mesh(
		bark_st, _get_painterly_mat(&"bark", TEX_BARK_PATH, Color(0.68, 0.58, 0.50)),
		leaf_st, leaf_mat
	)


# --- Summoner's Rift Rock Monoliths (Cyan Spiral Runes) & Alpha Grass Tufts ---

static func _build_rift_rune_monolith(stone_tint: Color, rune_color: Color, height_m: float, seed_val: int) -> ArrayMesh:
	var stone_st := SurfaceTool.new()
	stone_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rune_st := SurfaceTool.new()
	rune_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Chiseled 7-sided tapered monolith + flanking base ledge rock
	var rings := [
		{"y": -0.15, "rx": 1.15, "rz": 0.92, "off": Vector2.ZERO, "col": Color(0.55, 0.56, 0.60)},
		{"y": height_m * 0.22, "rx": 0.98, "rz": 0.78, "off": Vector2(0.05, -0.03), "col": Color(0.72, 0.74, 0.76)},
		{"y": height_m * 0.65, "rx": 0.74, "rz": 0.60, "off": Vector2(0.12, -0.08), "col": Color(0.88, 0.90, 0.92)},
		{"y": height_m, "rx": 0.36, "rz": 0.28, "off": Vector2(0.18, -0.10), "col": Color(0.98, 1.00, 1.00)},
	]
	_add_chiseled_rock_prism(stone_st, rings, 7, rng)

	# Flanking stepped rock shoulder
	var ledge_rings := [
		{"y": -0.15, "rx": 0.72, "rz": 0.65, "off": Vector2(-0.82, 0.28), "col": Color(0.54, 0.55, 0.58)},
		{"y": height_m * 0.32, "rx": 0.55, "rz": 0.48, "off": Vector2(-0.78, 0.25), "col": Color(0.82, 0.84, 0.86)},
		{"y": height_m * 0.42, "rx": 0.26, "rz": 0.22, "off": Vector2(-0.74, 0.22), "col": Color(0.94, 0.96, 0.98)},
	]
	_add_chiseled_rock_prism(stone_st, ledge_rings, 6, rng)

	# Carved glowing cyan-turquoise spiral rune ribbon across front (+Z) face
	var spiral_pts := PackedVector3Array()
	var turns := 2.2
	var segs := 28
	var center_y := height_m * 0.52
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var ang := t * TAU * turns
		var rad := lerpf(0.04, 0.34, t)
		var px := 0.12 + cos(ang) * rad
		var py := center_y + sin(ang) * rad * 1.15
		var pz := lerpf(0.74, 0.56, clampf((py - height_m * 0.2) / maxf(0.1, height_m * 0.7), 0.0, 1.0)) + 0.045
		spiral_pts.append(Vector3(px, py, pz))

	_add_ribbon_strip(rune_st, spiral_pts, 0.042, Vector3(0.0, 0.0, 1.0), rune_color)

	return _commit_two_surface_mesh(
		stone_st, _get_painterly_mat(&"stone", TEX_STONE_PATH, stone_tint),
		rune_st, _get_rune_mat(rune_color)
	)


static func _build_stylized_boulder_cluster(stone_tint: Color, seed_val: int) -> ArrayMesh:
	var stone_st := SurfaceTool.new()
	stone_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	_add_chiseled_rock_prism(stone_st, [
		{"y": -0.15, "rx": 1.35, "rz": 1.10, "off": Vector2.ZERO, "col": Color(0.56, 0.56, 0.58)},
		{"y": 0.65, "rx": 1.05, "rz": 0.85, "off": Vector2(0.08, -0.05), "col": Color(0.84, 0.84, 0.86)},
		{"y": 1.15, "rx": 0.45, "rz": 0.38, "off": Vector2(0.15, -0.10), "col": Color(0.98, 0.98, 1.00)},
	], 7, rng)
	_add_chiseled_rock_prism(stone_st, [
		{"y": -0.15, "rx": 0.82, "rz": 0.74, "off": Vector2(-0.88, 0.42), "col": Color(0.54, 0.54, 0.56)},
		{"y": 0.48, "rx": 0.58, "rz": 0.52, "off": Vector2(-0.84, 0.38), "col": Color(0.82, 0.84, 0.86)},
		{"y": 0.76, "rx": 0.22, "rz": 0.20, "off": Vector2(-0.80, 0.34), "col": Color(0.95, 0.96, 0.98)},
	], 6, rng)

	stone_st.generate_normals()
	var mesh := stone_st.commit()
	mesh.surface_set_material(0, _get_painterly_mat(&"stone", TEX_STONE_PATH, stone_tint))
	return mesh


static func _build_alpha_grass_tuft_cluster(c_root: Color, c_tip: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var w := 1.32
	var h := 0.98
	# 5 intersecting gently arched alpha-cutout grass cards (36 deg spacing) for lush full bouquets
	for k in range(5):
		var yaw := float(k) * PI / 5.0
		var basis := Basis(Vector3.UP, yaw)
		var r_off := Vector3(cos(yaw + 1.1) * 0.12, 0.0, sin(yaw + 1.1) * 0.12)
		var bend := 0.18
		var p_bl := r_off + basis * Vector3(-w * 0.5, -0.02, 0.0)
		var p_br := r_off + basis * Vector3(w * 0.5, -0.02, 0.0)
		var p_ml := r_off + basis * Vector3(-w * 0.53, h * 0.52, bend * 0.45)
		var p_mr := r_off + basis * Vector3(w * 0.53, h * 0.52, bend * 0.45)
		var p_tl := r_off + basis * Vector3(-w * 0.56, h, bend)
		var p_tr := r_off + basis * Vector3(w * 0.56, h, bend)

		var n_up := Vector3(0.0, 0.92, 0.39).normalized()
		n_up = (basis * n_up).normalized()
		var c_mid := c_root.lerp(c_tip, 0.58)

		_emit_quad_grid(st, p_bl, p_br, p_ml, p_mr, Vector2(0.04, 0.98), Vector2(0.96, 0.50), n_up, c_root, c_mid)
		_emit_quad_grid(st, p_ml, p_mr, p_tl, p_tr, Vector2(0.04, 0.50), Vector2(0.96, 0.04), n_up, c_mid, c_tip)

	var mesh := st.commit()
	mesh.surface_set_material(0, _get_foliage_mat(&"grass"))
	return mesh


# --- Shared Procedural Geometry Helpers ---

static func _add_tapered_branch(
	st: SurfaceTool,
	pts: Array,
	radii: Array,
	sides: int,
	c_bottom: Color,
	c_top: Color
) -> void:
	var rings: Array[Array] = []
	var ring_cols: Array[Color] = []
	var ring_vs: Array[float] = []
	var n_pts := pts.size()
	for i in range(n_pts):
		var p: Vector3 = pts[i]
		var r: float = float(radii[i])
		var tangent: Vector3
		if i == 0:
			tangent = ((pts[1] as Vector3) - p).normalized()
		elif i == n_pts - 1:
			tangent = (p - (pts[i - 1] as Vector3)).normalized()
		else:
			tangent = ((pts[i + 1] as Vector3) - (pts[i - 1] as Vector3)).normalized()
		if tangent.length_squared() < 0.0001:
			tangent = Vector3.UP
		var ref := Vector3.RIGHT if absf(tangent.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var u_ax := tangent.cross(ref).normalized()
		var v_ax := tangent.cross(u_ax).normalized()

		var ring: Array[Vector3] = []
		for s in range(sides):
			var a := float(s) * TAU / float(sides)
			ring.append(p + (u_ax * cos(a) + v_ax * sin(a)) * r)
		rings.append(ring)
		var t_frac := float(i) / float(maxi(1, n_pts - 1))
		ring_cols.append(c_bottom.lerp(c_top, t_frac))
		ring_vs.append(t_frac * 2.0)

	for i in range(n_pts - 1):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var c0: Color = ring_cols[i]
		var c1: Color = ring_cols[i + 1]
		var v0: float = ring_vs[i]
		var v1: float = ring_vs[i + 1]
		for s in range(sides):
			var sn := (s + 1) % sides
			var u0 := float(s) / float(sides)
			var u1 := float(s + 1) / float(sides)
			_emit_tri(st, r0[s], r1[sn], r0[sn], Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0), c0, c1, c0)
			_emit_tri(st, r0[s], r1[s], r1[sn], Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), c0, c1, c1)


static func _add_alpha_leaf_cloud(
	st: SurfaceTool,
	center: Vector3,
	radius_xz: float,
	radius_y: float,
	card_count: int,
	seed_val: int,
	c_cool: Color,
	c_warm: Color
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var total_cards := card_count + 4
	for i in range(total_cards):
		# Distribute cards densely across the cloud volume using golden angle
		var frac := (float(i) + 0.5) / float(maxi(1, total_cards))
		var theta := float(i) * 2.3999632 + rng.randf_range(-0.22, 0.22)
		var phi := acos(clampf(1.0 - 1.50 * frac, -0.75, 0.98))
		var shell_r := rng.randf_range(0.18, 0.72)

		var offset := Vector3(
			sin(phi) * cos(theta) * radius_xz * shell_r,
			cos(phi) * radius_y * shell_r,
			sin(phi) * sin(theta) * radius_xz * shell_r
		)
		var card_center := center + offset
		var card_w := rng.randf_range(1.65, 2.35) * clampf(radius_xz / 1.75, 0.68, 1.32)
		var card_h := card_w * rng.randf_range(0.75, 0.95)

		# Bias card plane normals skyward (+Y) + gentle camera-facing tilt so 2x2 dome leaf bouquets
		# form plush volumetric canopy clouds from isometric pitch instead of thin edge-on slices.
		var outward := (offset * 0.42 + Vector3(rng.randf_range(-0.18, 0.18), 0.88, 0.48 + rng.randf_range(-0.15, 0.15))).normalized()
		if outward.length_squared() < 0.001:
			outward = Vector3.UP
		var roll_ang := rng.randf_range(-0.45, 0.45)
		var right := Vector3(cos(roll_ang), 0.0, sin(roll_ang)).cross(outward)
		if right.length_squared() < 0.01:
			right = Vector3.RIGHT
		right = right.normalized()
		var up := outward.cross(right).normalized()

		# Pick one of the 4 hand-painted leaf clusters in the 2x2 RGBA atlas
		var quad_idx := rng.randi_range(0, 3)
		var qx := quad_idx % 2
		@warning_ignore("integer_division")
		var qy := quad_idx / 2
		var uv_min := Vector2(float(qx) * 0.5 + 0.025, float(qy) * 0.5 + 0.025)
		var uv_max := Vector2(float(qx) * 0.5 + 0.475, float(qy) * 0.5 + 0.475)

		# Gentle dome arch on card so intersecting cards shade smoothly with spherical normals
		var bulge := outward * (card_w * 0.12)
		var hw := right * (card_w * 0.5)
		var hh := up * (card_h * 0.5)

		var p_bl := card_center - hw - hh
		var p_bc := card_center - hh + bulge * 0.75
		var p_br := card_center + hw - hh
		var p_tl := card_center - hw + hh
		var p_tc := card_center + hh + bulge * 0.75
		var p_tr := card_center + hw + hh

		var uv_mid_x := (uv_min.x + uv_max.x) * 0.5
		_emit_leaf_tri(st, p_bl, p_bc, p_tc, Vector2(uv_min.x, uv_max.y), Vector2(uv_mid_x, uv_max.y), Vector2(uv_mid_x, uv_min.y), center, radius_y, c_cool, c_warm)
		_emit_leaf_tri(st, p_bl, p_tc, p_tl, Vector2(uv_min.x, uv_max.y), Vector2(uv_mid_x, uv_min.y), Vector2(uv_min.x, uv_min.y), center, radius_y, c_cool, c_warm)
		_emit_leaf_tri(st, p_bc, p_br, p_tr, Vector2(uv_mid_x, uv_max.y), Vector2(uv_max.x, uv_max.y), Vector2(uv_max.x, uv_min.y), center, radius_y, c_cool, c_warm)
		_emit_leaf_tri(st, p_bc, p_tr, p_tc, Vector2(uv_mid_x, uv_max.y), Vector2(uv_max.x, uv_min.y), Vector2(uv_mid_x, uv_min.y), center, radius_y, c_cool, c_warm)


static func _emit_leaf_tri(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	uva: Vector2,
	uvb: Vector2,
	uvc: Vector2,
	cloud_center: Vector3,
	radius_y: float,
	c_cool: Color,
	c_warm: Color
) -> void:
	var verts := [a, b, c]
	var uvs := [uva, uvb, uvc]
	for idx in range(3):
		var v: Vector3 = verts[idx]
		# Spherical Normal Transfer (per AGENTS.md)
		var sn := (v - cloud_center + Vector3(0.0, 0.55, 0.0)).normalized()
		var t_up := clampf((v.y - (cloud_center.y - radius_y)) / maxf(0.2, 2.0 * radius_y), 0.0, 1.0)
		st.set_normal(sn)
		st.set_color(c_cool.lerp(c_warm, t_up))
		st.set_uv(uvs[idx])
		st.add_vertex(v)


static func _add_chiseled_rock_prism(
	st: SurfaceTool,
	ring_specs: Array,
	sides: int,
	rng: RandomNumberGenerator
) -> void:
	var rings: Array[Array] = []
	var ring_cols: Array[Color] = []
	var angle_jitters: Array[float] = []
	for s in range(sides):
		angle_jitters.append(rng.randf_range(0.84, 1.16))

	for r_spec in ring_specs:
		var y: float = float(r_spec["y"])
		var rx: float = float(r_spec["rx"])
		var rz: float = float(r_spec["rz"])
		var off: Vector2 = r_spec["off"]
		var ring: Array[Vector3] = []
		for s in range(sides):
			var a := float(s) * TAU / float(sides)
			var jr: float = angle_jitters[s]
			ring.append(Vector3(off.x + cos(a) * rx * jr, y, off.y + sin(a) * rz * jr))
		rings.append(ring)
		ring_cols.append(r_spec["col"])

	for i in range(rings.size() - 1):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var c0: Color = ring_cols[i]
		var c1: Color = ring_cols[i + 1]
		var v0 := float(i) / float(rings.size() - 1)
		var v1 := float(i + 1) / float(rings.size() - 1)
		for s in range(sides):
			var sn := (s + 1) % sides
			var u0 := float(s) / float(sides)
			var u1 := float(s + 1) / float(sides)
			_emit_tri(st, r0[s], r1[sn], r0[sn], Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0), c0, c1, c0)
			_emit_tri(st, r0[s], r1[s], r1[sn], Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), c0, c1, c1)

	# Cap top face
	var top_r: Array = rings[rings.size() - 1]
	var top_c: Color = ring_cols[rings.size() - 1]
	var center_top := Vector3.ZERO
	for v in top_r:
		center_top += (v as Vector3)
	center_top /= float(sides)
	center_top.y += 0.08
	for s in range(sides):
		var sn := (s + 1) % sides
		_emit_tri(st, top_r[s], center_top, top_r[sn], Vector2(0.0, 0.0), Vector2(0.5, 0.5), Vector2(1.0, 0.0), top_c, top_c, top_c)


static func _add_ribbon_strip(
	st: SurfaceTool,
	pts: PackedVector3Array,
	half_w: float,
	face_normal: Vector3,
	col: Color
) -> void:
	for i in range(pts.size() - 1):
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var dir := (p1 - p0).normalized()
		var side := face_normal.cross(dir).normalized() * half_w
		var a := p0 - side
		var b := p0 + side
		var c := p1 + side
		var d := p1 - side
		_emit_tri_n(st, a, b, c, face_normal, col)
		_emit_tri_n(st, a, c, d, face_normal, col)


static func _emit_quad_grid(
	st: SurfaceTool,
	bl: Vector3,
	br: Vector3,
	tl: Vector3,
	tr: Vector3,
	uv_min: Vector2,
	uv_max: Vector2,
	n: Vector3,
	c_bot: Color,
	c_top: Color
) -> void:
	st.set_normal(n); st.set_color(c_bot); st.set_uv(Vector2(uv_min.x, uv_min.y)); st.add_vertex(bl)
	st.set_normal(n); st.set_color(c_bot); st.set_uv(Vector2(uv_max.x, uv_min.y)); st.add_vertex(br)
	st.set_normal(n); st.set_color(c_top); st.set_uv(Vector2(uv_max.x, uv_max.y)); st.add_vertex(tr)

	st.set_normal(n); st.set_color(c_bot); st.set_uv(Vector2(uv_min.x, uv_min.y)); st.add_vertex(bl)
	st.set_normal(n); st.set_color(c_top); st.set_uv(Vector2(uv_max.x, uv_max.y)); st.add_vertex(tr)
	st.set_normal(n); st.set_color(c_top); st.set_uv(Vector2(uv_min.x, uv_max.y)); st.add_vertex(tl)


static func _emit_tri(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	uva: Vector2,
	uvb: Vector2,
	uvc: Vector2,
	ca: Color,
	cb: Color,
	cc: Color
) -> void:
	st.set_color(ca); st.set_uv(uva); st.add_vertex(a)
	st.set_color(cb); st.set_uv(uvb); st.add_vertex(b)
	st.set_color(cc); st.set_uv(uvc); st.add_vertex(c)


static func _emit_tri_n(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	n: Vector3,
	col: Color
) -> void:
	st.set_normal(n); st.set_color(col); st.set_uv(Vector2.ZERO); st.add_vertex(a)
	st.set_normal(n); st.set_color(col); st.set_uv(Vector2.RIGHT); st.add_vertex(b)
	st.set_normal(n); st.set_color(col); st.set_uv(Vector2.ONE); st.add_vertex(c)


static func _commit_two_surface_mesh(
	st0: SurfaceTool,
	mat0: Material,
	st1: SurfaceTool,
	mat1: Material
) -> ArrayMesh:
	st0.generate_normals()
	var mesh := st0.commit()
	st1.commit(mesh)
	mesh.surface_set_material(0, mat0)
	if mesh.get_surface_count() > 1:
		mesh.surface_set_material(1, mat1)
	return mesh
