class_name LootPouch
extends Node3D

# Glowing world drop (enemy loot burst OR player's dropped Run Loot pouch on death)

signal collected(pouch: LootPouch, contents: Dictionary)

var contents := {"gold": 0, "ore": 0, "shards": 0}
var is_death_pouch := false
var _time := 0.0
var _mesh: MeshInstance3D
var _label: Label3D

func setup(pos: Vector3, loot: Dictionary, death_pouch: bool = false) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)
	contents = loot.duplicate()
	is_death_pouch = death_pouch

func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.34 if is_death_pouch else 0.24
	sphere.height = 0.68 if is_death_pouch else 0.48
	_mesh.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var col := Color(1.0, 0.35, 0.28) if is_death_pouch else (Color(1.0, 0.82, 0.28) if int(contents.get("shards", 0)) > 0 else Color(0.45, 0.88, 1.0))
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	_mesh.material_override = mat
	_mesh.position = Vector3(0, 0.45, 0)
	add_child(_mesh)

	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.45
	tor.outer_radius = 0.56
	ring.mesh = tor
	ring.material_override = mat
	ring.position = Vector3(0, 0.08, 0)
	add_child(ring)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 26
	_label.outline_size = 6
	_label.modulate = col
	_label.position = Vector3(0, 1.15, 0)
	var parts: Array[String] = []
	if is_death_pouch:
		parts.append("DROPPED RUN LOOT")
	if int(contents.get("gold", 0)) > 0:
		parts.append("+%dg" % int(contents["gold"]))
	if int(contents.get("ore", 0)) > 0:
		parts.append("+%d Ore" % int(contents["ore"]))
	if int(contents.get("shards", 0)) > 0:
		parts.append("+%d Boss Shard" % int(contents["shards"]))
	_label.text = " · ".join(parts)
	add_child(_label)

func _process(delta: float) -> void:
	_time += delta
	_mesh.position.y = 0.45 + sin(_time * 4.0) * 0.12
	_mesh.rotation.y += delta * 2.2

func try_pickup(player_pos: Vector3) -> bool:
	var d := player_pos - global_position
	d.y = 0.0
	if d.length() <= 1.65:
		collected.emit(self, contents)
		queue_free()
		return true
	return false
