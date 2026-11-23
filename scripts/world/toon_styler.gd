class_name ToonStyler
extends RefCounted

# Converts imported 3D GLB/GLTF meshes cleanly into our warm Palia/Wind Waker cel-shader
# while keeping every hand-painted albedo texture intact.

const TOON_SHADER := preload("res://shaders/wind_waker_toon.gdshader")
const GEAR_SHADER := preload("res://shaders/mu_gear_toon.gdshader")

static func apply_toon_recursive(root: Node, shadow_tint: Color = Color(0.45, 0.47, 0.62), rim_strength: float = 0.22) -> Array[ShaderMaterial]:
	var created: Array[ShaderMaterial] = []
	_walk_toon(root, shadow_tint, rim_strength, created)
	return created

static func _walk_toon(node: Node, shadow_tint: Color, rim_strength: float, out: Array[ShaderMaterial]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			var sc := mi.mesh.get_surface_count()
			for i in range(sc):
				var src := mi.get_active_material(i)
				var mat := make_toon_from_material(src, shadow_tint, rim_strength)
				mi.set_surface_override_material(i, mat)
				out.append(mat)
	for child in node.get_children():
		_walk_toon(child, shadow_tint, rim_strength, out)

static func make_toon_from_material(src: Material, shadow_tint: Color = Color(0.45, 0.47, 0.62), rim_strength: float = 0.22) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("shadow_color", shadow_tint)
	mat.set_shader_parameter("rim_strength", rim_strength)
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		mat.set_shader_parameter("albedo_color", b.albedo_color)
		if b.albedo_texture:
			mat.set_shader_parameter("albedo_texture", b.albedo_texture)
			mat.set_shader_parameter("use_texture", true)
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			mat.set_shader_parameter("use_alpha_scissor", true)
			mat.set_shader_parameter("alpha_scissor_threshold", 0.35)
		if b.emission_enabled:
			mat.set_shader_parameter("emission_color", b.emission)
			mat.set_shader_parameter("emission_strength", clampf(b.emission_energy_multiplier, 0.4, 2.5))
	return mat

static func make_gear_from_material(src: Material) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GEAR_SHADER
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		mat.set_shader_parameter("base_color", b.albedo_color)
		if b.albedo_texture:
			mat.set_shader_parameter("albedo_texture", b.albedo_texture)
			mat.set_shader_parameter("use_texture", true)
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			mat.set_shader_parameter("use_alpha_scissor", true)
			mat.set_shader_parameter("alpha_scissor_threshold", 0.35)
	return mat
