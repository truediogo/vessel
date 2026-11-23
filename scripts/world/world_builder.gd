class_name WorldBuilder
extends Node3D

# Full Lorencia-Inspired Fortified Starter Town built in Blender 5.3.0 at 1:1 scale
# with our 1.82m League of Legends-style characters:
# - Central Lorencia Octagonal Fountain (0, 0, 10.5) with 4 corner iron torch braziers
# - Lumen's Open-Front Lorencia Bar / Tavern (-12.8, 0, 4.2) with 1.05m counter, kegs & tables
# - Hanzo's Blacksmith Forge & Armory (-13.2, 0, 14.8) with 0.94m Anvil at (-9.2, 0, 13.5)
# - Lorencia Vault Guildhall (+14.2, 0, 14.2) with 2.9m doorway & Potion Arcade (+13.2, 0, 4.2)
# - Fortified Perimeter Walls, 8.6m Twin-Tower Gatehouses, and Wooden Plank Bridge (z = -2.5..-10.5)

const TOON_SHADER := preload("res://shaders/wind_waker_toon.gdshader")
const ARCANE_TOWN_SHADER := preload("res://shaders/arcane_town_painterly.gdshader")
const SWAYING_FOLIAGE_SHADER := preload("res://shaders/lol_swaying_foliage.gdshader")
const ANIMATED_WATER_SHADER := preload("res://shaders/lol_animated_water.gdshader")
const LORENCIA_GLB := "res://addons/lorencia_town/Lorencia_Town.glb"
const MED_NATURE := "res://addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/"

var forge_sparks: GPUParticles3D
var anvil_light: OmniLight3D
var _npc_vessels: Array[VesselRig] = []
var _clouds: Array[Node3D] = []
var _crystal_gem: Node3D
var _brazier_lights: Array[OmniLight3D] = []
var _time := 0.0

func build_world() -> void:
	_build_ground_and_lorencia_town()
	_build_lorencia_colliders()
	_build_lorencia_lights_and_signs()
	_build_nature_backdrop()
	_build_lorencia_npcs()

func _make_toon(albedo: Color, shadow: Color, emit: Color = Color.BLACK, emit_s: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo_color", albedo)
	m.set_shader_parameter("shadow_color", shadow)
	if emit_s > 0.0:
		m.set_shader_parameter("emission_color", emit)
		m.set_shader_parameter("emission_strength", emit_s)
	return m

func _spawn_model(res_path: String, pos: Vector3, rot_y_deg: float = 0.0, scl: float = 1.0, shadow_tint: Color = Color(0.45, 0.47, 0.62)) -> Node3D:
	if not ResourceLoader.exists(res_path):
		push_warning("Missing 3D model: " + res_path)
		return null
	var scene := load(res_path) as PackedScene
	var inst := scene.instantiate() as Node3D
	inst.position = pos
	inst.rotation_degrees.y = rot_y_deg
	inst.scale = Vector3.ONE * scl
	add_child(inst)
	ToonStyler.apply_toon_recursive(inst, shadow_tint, 0.22)
	return inst

func _add_collision_box(size: Vector3, pos: Vector3, rot_y_deg: float = 0.0) -> void:
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation_degrees.y = rot_y_deg
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	add_child(sb)

func _build_ground_and_lorencia_town() -> void:
	# Deep Summoner's Rift forest-moss terrain collider under the town
	_add_collision_box(Vector3(180, 1.0, 200), Vector3(0, -0.54, -20))

	# Spawn our Blender-built 1:1 League / Summoner's Rift-style Lorencia Town
	var town := _spawn_model(LORENCIA_GLB, Vector3.ZERO, 0.0, 1.0, Color(0.42, 0.44, 0.58))
	if town:
		_style_lorencia_special_meshes(town)

	# Floating arcane rune crystal atop the Central Sunspire Fountain (0, 4.35, 11.5)
	var crystal_mat := _make_toon(Color(0.38, 0.88, 1.0), Color(0.16, 0.52, 0.76), Color(0.32, 0.84, 1.0), 0.85)
	var gem := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.80, 1.35, 0.80)
	gem.mesh = pm
	gem.material_override = crystal_mat
	gem.position = Vector3(0.0, 4.45, 11.5)
	add_child(gem)
	_crystal_gem = gem

func _style_lorencia_special_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var low := mi.name.to_lower()
		if low.contains("water"):
			var wm := ShaderMaterial.new()
			wm.shader = ANIMATED_WATER_SHADER
			mi.material_override = wm
		elif low.contains("ember"):
			mi.material_override = _make_toon(Color(1.0, 0.78, 0.32), Color(0.86, 0.46, 0.14), Color(1.0, 0.68, 0.20), 1.45)
		elif low.contains("foliage") or low.contains("flowers"):
			# Point 5: Gently swaying painterly foliage with baked top-crown highlights & dark crevices
			for i in range(mi.mesh.get_surface_count()):
				var cur := mi.get_surface_override_material(i) as ShaderMaterial
				if cur:
					var fm := ShaderMaterial.new()
					fm.shader = SWAYING_FOLIAGE_SHADER
					fm.set_shader_parameter("albedo_color", cur.get_shader_parameter("albedo_color"))
					fm.set_shader_parameter("use_texture", cur.get_shader_parameter("use_texture"))
					fm.set_shader_parameter("albedo_texture", cur.get_shader_parameter("albedo_texture"))
					mi.set_surface_override_material(i, fm)
		elif mi.mesh:
			# Point 2: Matte 80%-unshaded painterly shader with baked vertex top-edge highlights & crevice AO
			for i in range(mi.mesh.get_surface_count()):
				var cur := mi.get_surface_override_material(i) as ShaderMaterial
				if cur:
					var am := ShaderMaterial.new()
					am.shader = ARCANE_TOWN_SHADER
					am.set_shader_parameter("albedo_color", cur.get_shader_parameter("albedo_color"))
					am.set_shader_parameter("use_texture", cur.get_shader_parameter("use_texture"))
					am.set_shader_parameter("albedo_texture", cur.get_shader_parameter("albedo_texture"))
					am.set_shader_parameter("shadow_color", Color(0.76, 0.74, 0.84))
					mi.set_surface_override_material(i, am)
	for c in node.get_children():
		_style_lorencia_special_meshes(c)

func _build_lorencia_colliders() -> void:
	# 1. Central Sunspire Fountain at (0, 0, 11.5)
	var sb_f := StaticBody3D.new()
	sb_f.position = Vector3(0, 1.0, 11.5)
	var cs_f := CollisionShape3D.new()
	var cyl_f := CylinderShape3D.new()
	cyl_f.radius = 3.95
	cyl_f.height = 2.0
	cs_f.shape = cyl_f
	sb_f.add_child(cs_f)
	add_child(sb_f)

	# 2. Grand Town Hall & Clocktower at (0, 0, -7.2) (twin bypass lanes on West x=-10.5 and East x=+10.5!)
	_add_collision_box(Vector3(17.8, 6.0, 7.8), Vector3(0.0, 3.0, -7.2))

	# 3. Lumen's Half-Timbered Tavern Bar Counter (-21.5, 0, 3.8)
	_add_collision_box(Vector3(5.5, 1.4, 1.1), Vector3(-21.7, 0.7, 2.7))
	_add_collision_box(Vector3(1.1, 1.4, 3.4), Vector3(-23.9, 0.7, 4.5))

	# 4. Hanzo's Blacksmith Foundry & Anvil (-17.8, 0, 16.5)
	_add_collision_box(Vector3(3.0, 5.0, 4.4), Vector3(-24.7, 2.5, 16.8))
	_add_collision_box(Vector3(1.5, 1.4, 1.7), Vector3(-17.8, 0.7, 16.5))

	# 5. East 6-Sail Windmill Tower (+23.2, 0, 16.8) & Apothecary Counter (+18.2, 0, 5.2)
	_add_collision_box(Vector3(5.4, 6.0, 5.4), Vector3(23.2, 3.0, 16.8))
	_add_collision_box(Vector3(1.3, 1.4, 5.8), Vector3(18.2, 0.7, 5.2))

	# 6. North Village Bridge Side Railings (x = ±3.45, z = -12.5 to -20.5)
	_add_collision_box(Vector3(0.7, 2.0, 8.4), Vector3(-3.45, 1.0, -16.5))
	_add_collision_box(Vector3(0.7, 2.0, 8.4), Vector3(3.45, 1.0, -16.5))

	# Outer West, East & South City Boundaries
	_add_collision_box(Vector3(2.5, 6.0, 38.0), Vector3(-29.0, 3.0, 13.0))
	_add_collision_box(Vector3(2.5, 6.0, 38.0), Vector3(28.5, 3.0, 13.0))
	_add_collision_box(Vector3(60.0, 5.0, 2.0), Vector3(0.0, 2.5, 31.2))

func _build_lorencia_lights_and_signs() -> void:
	# Warm Blacksmith Forge light & sparks over the West Canal Artisan Anvil at (-17.8, 0, 16.5)
	anvil_light = OmniLight3D.new()
	anvil_light.position = Vector3(-18.2, 2.4, 16.5)
	anvil_light.light_color = Color(1.0, 0.62, 0.24)
	anvil_light.light_energy = 1.15
	anvil_light.omni_range = 10.0
	add_child(anvil_light)

	for lp in [
		Vector3(-21.5, 2.6, 3.8),  # Lumen's Canal-Side Tavern
		Vector3(0.0, 3.4, 11.5),   # Central Sunspire Fountain
		Vector3(-4.2, 2.6, -3.2),  # North Triumphal Gate West
		Vector3(4.2, 2.6, -3.2),   # North Triumphal Gate East
		Vector3(18.2, 2.6, 4.2),   # East Apothecary Arcade
	]:
		var ol := OmniLight3D.new()
		ol.position = lp
		ol.light_color = Color(1.0, 0.74, 0.36)
		ol.light_energy = 0.85
		ol.omni_range = 9.0
		add_child(ol)
		_brazier_lights.append(ol)

	_add_landmark_sign(
		"★ HANZO'S ARTISAN FORGE & FOUNDRY ★\nPress [F] at the Anvil to Upgrade Gear (+0 → +15)",
		Vector3(-18.5, 4.4, 16.5),
		Color(1.0, 0.86, 0.38)
	)
	_add_landmark_sign(
		"★ LUMEN'S CANAL-SIDE LORENCIA BAR ★\n(West Canal Terrace)",
		Vector3(-21.5, 4.85, 1.2),
		Color(0.98, 0.82, 0.52)
	)
	_add_landmark_sign(
		"★ HIGH-ARCANE APOTHECARY & VAULT ROTUNDA ★\n(East Merchant Quarter)",
		Vector3(21.5, 4.85, 9.5),
		Color(0.72, 0.92, 1.0)
	)
	_add_landmark_sign(
		"▲ NORTH TRIUMPHAL VIADUCT — RIFT OUTSKIRTS & BOSS COLOSSEUM ▲\n(Combat & Run Loot Risk Beyond Bridge)",
		Vector3(0.0, 6.4, -3.2),
		Color(1.0, 0.82, 0.46)
	)

	forge_sparks = GPUParticles3D.new()
	forge_sparks.position = Vector3(-17.8, 1.15, 16.5)
	forge_sparks.one_shot = true
	forge_sparks.explosiveness = 0.92
	forge_sparks.emitting = false
	forge_sparks.amount = 46
	forge_sparks.lifetime = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 65.0
	pm.initial_velocity_min = 3.5
	pm.initial_velocity_max = 7.5
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.08
	pm.scale_max = 0.16
	forge_sparks.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.88, 0.35)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.80, 0.25)
	smat.emission_energy_multiplier = 2.8
	sm.material = smat
	forge_sparks.draw_pass_1 = sm
	add_child(forge_sparks)

	# Point 5: Atmospheric drifting leaves & golden pollen motes across the village square
	var leaf_motes := GPUParticles3D.new()
	leaf_motes.position = Vector3(0.0, 6.5, 10.0)
	leaf_motes.amount = 64
	leaf_motes.lifetime = 6.5
	var lpm := ParticleProcessMaterial.new()
	lpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	lpm.emission_box_extents = Vector3(24.0, 3.5, 22.0)
	lpm.direction = Vector3(0.6, -0.4, 0.3)
	lpm.spread = 35.0
	lpm.initial_velocity_min = 0.8
	lpm.initial_velocity_max = 1.8
	lpm.gravity = Vector3(0.15, -0.35, 0.1)
	lpm.scale_min = 0.08
	lpm.scale_max = 0.16
	leaf_motes.process_material = lpm
	var l_quad := PrismMesh.new()
	l_quad.size = Vector3(0.45, 0.12, 0.35)
	var l_mat := StandardMaterial3D.new()
	l_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	l_mat.albedo_color = Color(0.76, 0.92, 0.42)
	l_quad.material = l_mat
	leaf_motes.draw_pass_1 = l_quad
	add_child(leaf_motes)

func _add_landmark_sign(txt: String, pos: Vector3, col: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = txt
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 26
	lbl.outline_size = 8
	lbl.modulate = col
	lbl.position = pos
	add_child(lbl)

func trigger_forge_burst(col: Color) -> void:
	if forge_sparks == null:
		return
	var sm := forge_sparks.draw_pass_1 as SphereMesh
	if sm and sm.material is StandardMaterial3D:
		var m := sm.material as StandardMaterial3D
		m.albedo_color = col
		m.emission = col
	forge_sparks.restart()
	forge_sparks.emitting = true

func _build_nature_backdrop() -> void:
	# Distant mountain peaks on the far northern horizon & drifting sky clouds (no low-poly cone-tree hills!)
	_spawn_model(MED_NATURE + "mountain_A_grass_trees.gltf", Vector3(-44.0, -0.45, -108.0), 12.0, 17.5, Color(0.42, 0.48, 0.62))
	_spawn_model(MED_NATURE + "mountain_B_grass_trees.gltf", Vector3(6.0, -0.45, -112.0), -18.0, 19.5, Color(0.42, 0.48, 0.62))
	_spawn_model(MED_NATURE + "mountain_C_grass_trees.gltf", Vector3(48.0, -0.45, -104.0), 40.0, 16.5, Color(0.42, 0.48, 0.62))

	for cp in [Vector3(-18.0, 26.0, -34.0), Vector3(16.0, 28.0, -46.0), Vector3(0.0, 25.0, -16.0)]:
		var cl := _spawn_model(MED_NATURE + "cloud_big.gltf", cp, randf_range(0, 360), 6.8, Color(0.88, 0.84, 0.86))
		if cl:
			_clouds.append(cl)

func _build_lorencia_npcs() -> void:
	# Iconic Lorencia NPCs & Adventurers across the 5-District City Layout!
	_spawn_npc("warrior", Vector3(-15.8, 0.0, 16.8), -75.0, 13, 14, "Hanzo's Masterwork Clearer (+13)")
	_spawn_npc("hunter", Vector3(-21.6, 0.16, 1.65), 15.0, 4, 4, "Lumen the Barmaid")
	_spawn_npc("mage", Vector3(4.2, 0.0, -0.4), -20.0, 8, 8, "Lorencia Viaduct Guard (+8)")
	_spawn_npc("twin_tails", Vector3(5.2, 0.0, 10.8), -110.0, 5, 5, "Bonded Adventurer (+5)")
	_spawn_npc("warrior", Vector3(6.4, 0.0, 12.0), -145.0, 7, 7, "Bonded Adventurer (+7)")
	_spawn_npc("merchant", Vector3(19.6, 0.16, 4.2), -90.0, 2, 2, "High-Arcane Apothecary")
	_spawn_npc("mage", Vector3(19.2, 0.16, 16.5), -90.0, 10, 10, "Grand Vault Keeper (+10)")

func _spawn_npc(arch: String, pos: Vector3, yaw_deg: float, armor_lv: int, sword_lv: int, title: String) -> void:
	var npc := VesselRig.new()
	npc.archetype = arch
	npc.position = pos
	npc.rotation_degrees.y = yaw_deg
	add_child(npc)
	npc.set_gear_levels(armor_lv, sword_lv)
	_npc_vessels.append(npc)

	var lbl := Label3D.new()
	lbl.text = title
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 24
	lbl.outline_size = 6
	lbl.modulate = Color(1.0, 0.90, 0.52) if armor_lv >= 13 else Color(0.94, 0.96, 1.0)
	lbl.position = Vector3(0, 2.25, 0)
	npc.add_child(lbl)

func _process(delta: float) -> void:
	_time += delta
	for npc in _npc_vessels:
		npc.update_animation(delta, 0.0)
	if _crystal_gem:
		_crystal_gem.rotation.y += delta * 0.65
		_crystal_gem.position.y = 4.15 + sin(_time * 2.2) * 0.12
	for cl in _clouds:
		cl.position.x += delta * 0.45
		if cl.position.x > 42.0:
			cl.position.x = -42.0
	if anvil_light:
		anvil_light.light_energy = 1.35 + sin(_time * 9.0) * 0.22
