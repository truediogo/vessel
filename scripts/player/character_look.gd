class_name CharacterLook
extends RefCounted

# Shared League of Legends-style Heroic Stylized character materials, ink silhouette
# outline pass, skin/hair recoloring, and sculpted 3D hair alignment.

const TOON_SHADER := preload("res://shaders/wind_waker_toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/lol_outline.gdshader")
const SKIN_DETAIL_REFERENCE := 0.26
const HAIR_DETAIL_REFERENCE := 0.34

const BODY_MALE_PATH := "res://addons/lol_adventurers/LoL_Male_Adventurer.glb"
const BODY_FEMALE_PATH := "res://addons/lol_adventurers/LoL_Female_Adventurer.glb"

const AUTHORED_HEAD_ORIGIN := {
	"male": Vector3(0.0, 1.5998, -0.0174),
	"female": Vector3(0.0, 1.5496, -0.0109),
}
const FEMALE_AUTHORED_HAIR: Array[String] = ["Hair_Long", "Hair_Buns", "Hair_BuzzedFemale"]

# Chunky sculpted 3D hairstyles (League / Fortnite / Palia style solid 3D volumes)
const HAIR_STYLES: Array[Dictionary] = [
	{"name": "Simple Parted", "path": "res://addons/quaternius_hair/Hair_SimpleParted.gltf"},
	{"name": "Buzzed Short", "path": "res://addons/quaternius_hair/Hair_Buzzed.gltf"},
	{"name": "Long Swept", "path": "res://addons/quaternius_hair/Hair_Long.gltf"},
	{"name": "Twin Buns", "path": "res://addons/quaternius_hair/Hair_Buns.gltf"},
	{"name": "Cropped Cut", "path": "res://addons/quaternius_hair/Hair_BuzzedFemale.gltf"},
	{"name": "Adventurer Beard", "path": "res://addons/quaternius_hair/Hair_Beard.gltf"},
	{"name": "None", "path": ""},
]

static func get_outline_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("outline_color", Color(0.07, 0.06, 0.10, 1.0))
	mat.set_shader_parameter("outline_width", 0.0022)
	return mat

static func is_skin_mesh(mesh_name: String) -> bool:
	return mesh_name.to_lower().contains("superhero")

static func is_brow_mesh(mesh_name: String) -> bool:
	return mesh_name.to_lower().contains("eyebrow")

static func is_tunic_mesh(mesh_name: String) -> bool:
	var low := mesh_name.to_lower()
	return low.contains("tunic") or low.contains("breeches")

static func is_armor_mesh(mesh_name: String) -> bool:
	var low := mesh_name.to_lower()
	return low.contains("mantle") or low.contains("bracers") or low.contains("belt") or low.contains("boots")

static func make_skin_material(src: Material, color: Color) -> ShaderMaterial:
	var mat := _make_material(src, color, SKIN_DETAIL_REFERENCE)
	mat.set_shader_parameter("skin_mode", true)
	mat.set_shader_parameter("shadow_color", Color(0.62, 0.50, 0.56))
	mat.set_shader_parameter("rim_strength", 0.22)
	mat.set_shader_parameter("rim_color", Color(1.0, 0.95, 0.86))
	mat.next_pass = get_outline_material()
	return mat

static func make_hair_material(src: Material, color: Color) -> ShaderMaterial:
	var mat := _make_material(src, color, HAIR_DETAIL_REFERENCE)
	mat.set_shader_parameter("shadow_color", Color(0.46, 0.43, 0.54))
	mat.set_shader_parameter("rim_strength", 0.22)
	mat.set_shader_parameter("rim_color", Color(0.98, 0.93, 0.82))
	mat.next_pass = get_outline_material()
	return mat

static func brow_color_for(hair_color: Color) -> Color:
	return hair_color.darkened(0.32).lerp(Color(0.14, 0.11, 0.09), 0.25)

static func make_brow_material(src: Material, hair_color: Color) -> ShaderMaterial:
	var mat := _make_material(src, brow_color_for(hair_color), HAIR_DETAIL_REFERENCE)
	mat.set_shader_parameter("shadow_color", Color(0.42, 0.38, 0.44))
	mat.set_shader_parameter("rim_strength", 0.05)
	return mat

static func make_cloth_toon_material(src: Material) -> ShaderMaterial:
	var mat := ToonStyler.make_toon_from_material(src, Color(0.44, 0.46, 0.60), 0.24)
	mat.next_pass = get_outline_material()
	return mat

static func hair_transform(skeleton: Skeleton3D, head_idx: int, hair_path: String) -> Transform3D:
	var rest := skeleton.get_bone_global_rest(head_idx)
	var authored_on := "female" if hair_path.get_file().get_basename() in FEMALE_AUTHORED_HAIR else "male"
	return rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin - AUTHORED_HEAD_ORIGIN[authored_on])

static func _make_material(src: Material, color: Color, detail_reference: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("albedo_color", color)
	if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture:
		mat.set_shader_parameter("albedo_texture", (src as BaseMaterial3D).albedo_texture)
		mat.set_shader_parameter("use_texture", true)
		mat.set_shader_parameter("detail_reference", detail_reference)
	return mat
