@tool
class_name ScatterRule
extends Resource

## Defines procedural scattering rules for a single mesh or PackedScene prop inside a BiomeConfig.

@export var rule_name: String = "Prop"
@export var mesh: Mesh
## Optional PackedScene fallback: if `mesh` is null, Scatterer extracts the first MeshInstance3D mesh.
@export var packed_scene: PackedScene
@export var material_override: Material

@export_group("Placement Constraints")
@export_range(0.0, 40.0, 0.1) var density_per_100m2: float = 2.0
@export_range(0.5, 32.0, 0.5) var min_spacing: float = 3.0
@export var height_range: Vector2 = Vector2(-50.0, 200.0)
@export_range(0.0, 89.0, 1.0) var max_slope_degrees: float = 30.0
@export var min_water_clearance: float = 0.25
@export var scale_range: Vector2 = Vector2(0.85, 1.25)
@export var align_to_normal: bool = false
@export var blocks_navigation: bool = false
@export var cast_shadows: bool = true

@export_group("Collision & Distance Fade")
@export_range(0.15, 4.0, 0.05) var collision_radius: float = 0.65
@export_range(0.5, 12.0, 0.25) var collision_height: float = 3.5
@export_range(0.0, 600.0, 5.0) var visibility_range_end: float = 0.0
@export_range(2.0, 80.0, 2.0) var visibility_range_fade_margin: float = 20.0


func resolve_mesh() -> Mesh:
	if mesh != null:
		return mesh
	if packed_scene != null:
		var inst := packed_scene.instantiate()
		if inst != null:
			var found := _find_first_mesh(inst)
			inst.free()
			if found != null:
				mesh = found
				return found
	return null


static func _find_first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			return mi.mesh
	for child in node.get_children():
		var m := _find_first_mesh(child)
		if m != null:
			return m
	return null
