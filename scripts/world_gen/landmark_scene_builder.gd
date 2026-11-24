@tool
class_name LandmarkSceneBuilder
extends Node3D

## Builds clean placeholder 3D landmark dioramas (City, Ruins, Dungeon) with
## hand-painted materials, StaticBody3D colliders, non-overlapping plaza floors,
## and visible 3D Label3D landmark titles.

const SHADER_PAINTERLY_PATH := "res://shaders/arcane_town_painterly.gdshader"
const TEX_STONE_PATH := "res://addons/lorencia_town/Lorencia_Town_T_LoL_Weathered_Stone.png"
const TEX_FLAGSTONE_PATH := "res://addons/lorencia_town/Lorencia_Town_T_LoL_Mossy_Flagstones.png"
const TEX_ARCH_PATH := "res://addons/lorencia_town/Lorencia_Town_T_Lorencia_Architecture.png"
const TEX_ROOF_PATH := "res://addons/lorencia_town/Lorencia_Town_T_Palia_Terracotta_Roof.png"

@export_enum("city", "ruins", "dungeon") var landmark_kind: String = "city":
	set(value):
		landmark_kind = value
		if _ready_done:
			_rebuild()

@export var title_text: String = "Citadel Plaza":
	set(value):
		title_text = value
		var lbl := get_node_or_null("LandmarkTitleLabel") as Label3D
		if lbl != null:
			lbl.text = title_text

var _ready_done: bool = false


func _ready() -> void:
	_ready_done = true
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var body := StaticBody3D.new()
	body.name = "LandmarkBody"
	add_child(body)

	match landmark_kind:
		"ruins":
			_build_ruins(body)
		"dungeon":
			_build_dungeon(body)
		_:
			_build_city(body)

	var label := Label3D.new()
	label.name = "LandmarkTitleLabel"
	label.text = title_text
	label.position = Vector3(0.0, 5.8, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.016
	label.outline_size = 10
	label.modulate = Color(1.0, 0.94, 0.72, 1.0)
	label.outline_modulate = Color(0.07, 0.08, 0.12, 0.95)
	add_child(label)


func _build_city(body: StaticBody3D) -> void:
	var mat_floor := _make_painterly_mat(TEX_FLAGSTONE_PATH, Color(0.92, 0.90, 0.84))
	var mat_wall := _make_painterly_mat(TEX_ARCH_PATH, Color(0.95, 0.92, 0.86))
	var mat_roof := _make_painterly_mat(TEX_ROOF_PATH, Color(0.92, 0.56, 0.44))
	var mat_cyan := _make_rune_mat(Color(0.22, 0.92, 0.96))

	# Elevated stone plaza slab (top y = 0.08 above terrain y = 0.00 to avoid Z-fighting)
	_add_cyl_part("PlazaFloor", Vector3(0.0, -0.17, 0.0), 10.5, 0.50, 12, mat_floor, null)

	# 4 corner watch-pillars with terracotta caps
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var px: float = sx * 6.4
			var pz: float = sz * 6.4
			_add_box_part("Pillar", Vector3(px, 2.2, pz), Vector3(1.5, 4.4, 1.5), mat_wall, body)
			_add_cyl_part("RoofCap", Vector3(px, 4.9, pz), 1.35, 1.2, 4, mat_roof, null)

	# North archway gatehouse
	_add_box_part("ArchLeft", Vector3(-2.4, 2.4, -7.2), Vector3(1.6, 4.8, 1.6), mat_wall, body)
	_add_box_part("ArchRight", Vector3(2.4, 2.4, -7.2), Vector3(1.6, 4.8, 1.6), mat_wall, body)
	_add_box_part("ArchLintel", Vector3(0.0, 5.1, -7.2), Vector3(6.8, 1.1, 1.9), mat_roof, body)

	# Central cyan obelisk fountain
	_add_cyl_part("FountainBasin", Vector3(0.0, 0.38, 0.0), 2.5, 0.65, 10, mat_wall, body)
	_add_cyl_part("ObeliskCore", Vector3(0.0, 2.5, 0.0), 0.72, 4.0, 6, mat_wall, body)
	_add_cyl_part("RuneRing", Vector3(0.0, 2.8, 0.0), 0.78, 0.25, 8, mat_cyan, null)


func _build_ruins(body: StaticBody3D) -> void:
	var mat_stone := _make_painterly_mat(TEX_STONE_PATH, Color(0.84, 0.86, 0.82))
	var mat_floor := _make_painterly_mat(TEX_FLAGSTONE_PATH, Color(0.76, 0.80, 0.72))
	var mat_cyan := _make_rune_mat(Color(0.24, 0.90, 0.88))

	_add_cyl_part("RuinsDias", Vector3(0.0, -0.17, 0.0), 9.0, 0.50, 10, mat_floor, null)

	# Ring of 6 weathered runic monoliths (some tilted/broken)
	for i in range(6):
		var a := float(i) * TAU / 6.0
		var pos := Vector3(cos(a) * 6.5, 2.0, sin(a) * 6.5)
		var h: float = 4.6 if (i % 2 == 0) else 3.1
		var rot := Vector3(0.08 if i == 1 else 0.0, -a, -0.12 if i == 4 else 0.0)
		_add_box_part("RuinPillar_%d" % i, Vector3(pos.x, h * 0.5, pos.z), Vector3(1.25, h, 1.15), mat_stone, body, rot)
		_add_box_part("RuneStrip_%d" % i, Vector3(pos.x * 0.92, h * 0.55, pos.z * 0.92), Vector3(0.32, h * 0.45, 0.32), mat_cyan, null)

	# Broken lintel spanning pillars 0 and 1
	_add_box_part("BrokenLintel", Vector3(5.6, 4.4, 3.2), Vector3(1.4, 0.9, 6.2), mat_stone, null, Vector3(0.05, 0.52, -0.10))

	# Central altar
	_add_box_part("AltarBase", Vector3(0.0, 0.65, 0.0), Vector3(2.4, 1.3, 1.8), mat_stone, body)
	_add_box_part("AltarCrystal", Vector3(0.0, 1.85, 0.0), Vector3(0.55, 1.1, 0.55), mat_cyan, null, Vector3(0.15, 0.6, 0.2))


func _build_dungeon(body: StaticBody3D) -> void:
	var mat_basalt := _make_painterly_mat(TEX_STONE_PATH, Color(0.50, 0.46, 0.52))
	var mat_floor := _make_painterly_mat(TEX_FLAGSTONE_PATH, Color(0.46, 0.44, 0.48))
	var mat_ember := _make_rune_mat(Color(1.00, 0.46, 0.16))

	_add_cyl_part("DungeonForecourt", Vector3(0.0, -0.17, 0.0), 9.2, 0.50, 8, mat_floor, null)

	# Massive dark portal frame
	_add_box_part("GatePillarL", Vector3(-2.6, 2.8, -2.5), Vector3(1.9, 5.6, 2.4), mat_basalt, body)
	_add_box_part("GatePillarR", Vector3(2.6, 2.8, -2.5), Vector3(1.9, 5.6, 2.4), mat_basalt, body)
	_add_box_part("GateCrown", Vector3(0.0, 6.1, -2.5), Vector3(8.0, 1.6, 2.8), mat_basalt, body)
	_add_box_part("PortalVoid", Vector3(0.0, 2.6, -2.7), Vector3(3.3, 4.6, 0.35), _make_rune_mat(Color(0.07, 0.05, 0.10)), body)
	_add_box_part("PortalRuneGlow", Vector3(0.0, 5.6, -1.0), Vector3(4.2, 0.35, 0.25), mat_ember, null)

	# Flanking spikes
	for sx in [-1.0, 1.0]:
		_add_cyl_part("BrazierPillar", Vector3(sx * 5.2, 1.6, 3.2), 0.75, 3.2, 6, mat_basalt, body)
		_add_cyl_part("BrazierEmber", Vector3(sx * 5.2, 3.4, 3.2), 0.48, 0.42, 6, mat_ember, null)


func _add_box_part(
	part_name: String,
	pos: Vector3,
	size_vec: Vector3,
	mat: Material,
	body: StaticBody3D,
	rot_euler: Vector3 = Vector3.ZERO
) -> void:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var bm := BoxMesh.new()
	bm.size = size_vec
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot_euler
	add_child(mi)

	if body != null:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size_vec
		cs.shape = shape
		cs.position = pos
		cs.rotation = rot_euler
		body.add_child(cs)


func _add_cyl_part(
	part_name: String,
	pos: Vector3,
	rad: float,
	h: float,
	sides: int,
	mat: Material,
	body: StaticBody3D
) -> void:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var cm := CylinderMesh.new()
	cm.top_radius = rad * 0.92
	cm.bottom_radius = rad
	cm.height = h
	cm.radial_segments = sides
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)

	if body != null:
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = rad
		shape.height = h
		cs.shape = shape
		cs.position = pos
		body.add_child(cs)


static func _make_painterly_mat(tex_path: String, tint: Color) -> Material:
	var shader := load(SHADER_PAINTERLY_PATH) as Shader
	var tex := load(tex_path) as Texture2D
	if shader != null:
		var smat := ShaderMaterial.new()
		smat.shader = shader
		smat.set_shader_parameter("use_texture", tex != null)
		if tex != null:
			smat.set_shader_parameter("albedo_texture", tex)
		smat.set_shader_parameter("albedo_color", tint)
		smat.set_shader_parameter("emission_strength", 0.0)
		return smat
	var std := StandardMaterial3D.new()
	std.albedo_texture = tex
	std.albedo_color = tint
	std.roughness = 0.92
	return std


static func _make_rune_mat(col: Color) -> Material:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
