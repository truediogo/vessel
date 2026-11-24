class_name WorldLayoutData
extends RefCounted

## Immutable-after-generation macro world layout shared safely between the
## main-thread debug view, global landmark/road planner, and chunk builders.

var world_seed: int = 1337
var world_size: float = 512.0
var chunk_size: int = 64
var region_count: int = 7
var border_blend_distance: float = 36.0
var warp_strength: float = 28.0
var warp_frequency: float = 0.0045
var sea_level: float = 0.0

var biomes: Array[BiomeConfig] = []

## Each region Dictionary:
## {"id": int, "center": Vector2, "biome_index": int, "biome": BiomeConfig, "neighbors": PackedInt32Array}
var regions: Array[Dictionary] = []

## Keyed by get_edge_key(id_a, id_b). Each value Dictionary:
## {"has_barrier": bool, "pass_center": Vector2, "pass_radius": float, "ridge_height": float, "is_mst": bool}
var barrier_edges: Dictionary = {}

## Reserved landmark footprints (populated in Step 5 LandmarkPlacer).
## Each Dictionary: {"region_id": int, "biome_id": StringName, "center": Vector2,
##   "target_height": float, "flatten_radius": float, "blend_radius": float,
##   "clearance_radius": float, "kind": StringName, "title": String, "scene": PackedScene}
var landmarks: Array[Dictionary] = []

## Global road polyline samples & smoothed A* segments (populated in Step 5 LandmarkPlacer).
var road_points: PackedVector2Array = PackedVector2Array()
var road_segments: Array[PackedVector2Array] = []
var road_grid_res: int = 0
var road_mask_grid: PackedFloat32Array = PackedFloat32Array()
var road_height_grid: PackedFloat32Array = PackedFloat32Array()


func sample_road_mask(x: float, z: float) -> float:
	return _sample_road_grid(x, z, road_mask_grid, 0.0)


func sample_road_height(x: float, z: float, fallback_h: float) -> float:
	if road_grid_res <= 1 or road_height_grid.size() != road_grid_res * road_grid_res:
		return fallback_h
	return _sample_road_grid(x, z, road_height_grid, fallback_h)


func _sample_road_grid(x: float, z: float, grid: PackedFloat32Array, fallback: float) -> float:
	var n := road_grid_res
	if n <= 1 or grid.size() != n * n:
		return fallback
	var u := clampf((x / maxf(1.0, world_size)) + 0.5, 0.0, 1.0) * float(n - 1)
	var v := clampf((z / maxf(1.0, world_size)) + 0.5, 0.0, 1.0) * float(n - 1)
	var x0 := clampi(int(floor(u)), 0, n - 1)
	var y0 := clampi(int(floor(v)), 0, n - 1)
	var x1 := mini(x0 + 1, n - 1)
	var y1 := mini(y0 + 1, n - 1)
	var tx := u - float(x0)
	var ty := v - float(y0)
	var v00 := grid[y0 * n + x0]
	var v10 := grid[y0 * n + x1]
	var v01 := grid[y1 * n + x0]
	var v11 := grid[y1 * n + x1]
	return lerpf(lerpf(v00, v10, tx), lerpf(v01, v11, tx), ty)


static func get_edge_key(id_a: int, id_b: int) -> String:
	return "%d:%d" % [mini(id_a, id_b), maxi(id_a, id_b)]


func get_grid_chunk_count() -> int:
	return maxi(1, ceili(world_size / float(maxi(1, chunk_size))))


func get_world_half_extent() -> float:
	return world_size * 0.5
