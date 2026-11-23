class_name VesselRig
extends Node3D

# League of Legends-style Heroic Stylized character rig built in Blender 5.3.0
# with the 3D Novice Adventurer Set (Tunic, Breeches, Shoulder Mantle, Forearm Bracers,
# Buckled Belt, and Cuffed Boots), sculpted 3D hair, ink silhouette outline, and MU gear tiers.

const ANIM_LIB_PATH := "res://addons/quaternius_anims/UAL1_Standard.glb"
const SWORD_1H_PATH := "res://addons/kaykit_character_pack_adventures/Assets/gltf/sword_1handed.gltf"
const SWORD_2H_PATH := "res://addons/kaykit_character_pack_adventures/Assets/gltf/sword_2handed.gltf"

const ARCHETYPE_MODELS := {
	"warrior": CharacterLook.BODY_MALE_PATH,
	"hunter": CharacterLook.BODY_FEMALE_PATH,
	"mage": CharacterLook.BODY_MALE_PATH,
	"twin_tails": CharacterLook.BODY_FEMALE_PATH,
	"merchant": CharacterLook.BODY_FEMALE_PATH,
}

const NPC_PRESETS := {
	"warrior": {"hair_idx": 0, "hair_color": Color(0.18, 0.12, 0.08), "skin_color": Color(0.90, 0.75, 0.60)},
	"hunter": {"hair_idx": 2, "hair_color": Color(0.72, 0.22, 0.14), "skin_color": Color(0.96, 0.84, 0.72)},
	"mage": {"hair_idx": 1, "hair_color": Color(0.74, 0.78, 0.84), "skin_color": Color(0.81, 0.64, 0.48)},
	"twin_tails": {"hair_idx": 3, "hair_color": Color(0.90, 0.74, 0.40), "skin_color": Color(0.90, 0.75, 0.60)},
	"merchant": {"hair_idx": 4, "hair_color": Color(0.28, 0.16, 0.08), "skin_color": Color(0.62, 0.44, 0.31)},
}

var archetype := "warrior"
var _has_custom_appearance := false
var skin_color := Color(0.90, 0.75, 0.60)
var hair_style_path := "res://addons/quaternius_hair/Hair_SimpleParted.gltf"
var hair_color := Color(0.28, 0.16, 0.08)

var _model_root: Node3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _hand_r_attach: BoneAttachment3D
var _head_attach: BoneAttachment3D
var _hair_node: Node3D
var _equipped_sword_node: Node3D
var _slash_arc_mesh: MeshInstance3D
var _slash_mat: StandardMaterial3D
var _armor_embers: GPUParticles3D
var _sword_embers: GPUParticles3D

var _armor_mats: Array[ShaderMaterial] = []
var _skin_mats: Array[ShaderMaterial] = []
var _hair_mats: Array[ShaderMaterial] = []
var _sword_mats: Array[ShaderMaterial] = []
var _all_mats: Array[ShaderMaterial] = []

var _armor_lv := 0
var _sword_lv := 0
var _action_timer := 0.0
var _is_spinning := false
var _hit_flash := 0.0
var _time := 0.0
var _current_loco := ""
var _use_ual := false

const ANIM_IDLE := "Idle_Loop"
const ANIM_RUN := "Jog_Fwd_Loop"
const ANIM_SWORD_ATTACK := "Sword_Attack"
const ANIM_PUNCH_JAB := "Punch_Jab"
const ANIM_PUNCH_CROSS := "Punch_Cross"
const ANIM_ROLL := "Roll"
const ANIM_DANCE := "Dance_Loop"

func _ready() -> void:
	_build_slash_and_embers()
	load_archetype(archetype)

func set_appearance_data(appearance: Dictionary) -> void:
	_has_custom_appearance = true
	if appearance.has("skin_color"):
		skin_color = appearance["skin_color"]
	if appearance.has("hair_style_path"):
		hair_style_path = appearance["hair_style_path"]
	if appearance.has("hair_color"):
		hair_color = appearance["hair_color"]
	if appearance.has("body_type"):
		var bt: String = appearance["body_type"]
		archetype = "hunter" if bt == "female" else "warrior"

func apply_appearance(appearance: Dictionary) -> void:
	set_appearance_data(appearance)
	load_archetype(archetype)

func load_archetype(new_arch: String) -> void:
	archetype = new_arch if ARCHETYPE_MODELS.has(new_arch) else "warrior"
	if _model_root and is_instance_valid(_model_root):
		_model_root.queue_free()
	_armor_mats.clear()
	_skin_mats.clear()
	_hair_mats.clear()
	_sword_mats.clear()
	_all_mats.clear()
	_anim = null
	_skeleton = null
	_hand_r_attach = null
	_head_attach = null
	_hair_node = null
	_equipped_sword_node = null
	_current_loco = ""

	var char_path: String = ARCHETYPE_MODELS[archetype]
	if not _has_custom_appearance and NPC_PRESETS.has(archetype):
		var p: Dictionary = NPC_PRESETS[archetype]
		skin_color = p["skin_color"]
		hair_color = p["hair_color"]
		hair_style_path = CharacterLook.HAIR_STYLES[int(p["hair_idx"])]["path"]

	var scene := load(char_path) as PackedScene
	if scene == null:
		push_warning("VesselRig: Could not load character model: " + char_path)
		return
	_model_root = scene.instantiate()
	_model_root.scale = Vector3.ONE
	add_child(_model_root)

	_discover_rig(_model_root)
	_load_animation_library()
	_configure_meshes_and_materials(_model_root)
	_attach_hair()
	_attach_vessel_sword()
	set_gear_levels(_armor_lv, _sword_lv)
	_play_anim(ANIM_IDLE, 0.0, true)

func _discover_rig(n: Node) -> void:
	if n is AnimationPlayer:
		_anim = n as AnimationPlayer
	elif n is Skeleton3D:
		_skeleton = n as Skeleton3D
	for c in n.get_children():
		_discover_rig(c)
	if n == _model_root and _anim == null and _skeleton != null:
		_anim = AnimationPlayer.new()
		_anim.name = "AnimationPlayer"
		_model_root.add_child(_anim)
		_anim.root_node = NodePath("..")

func _load_animation_library() -> void:
	if _anim == null or _skeleton == null:
		return
	var anim_scene := load(ANIM_LIB_PATH) as PackedScene
	if anim_scene == null:
		push_warning("VesselRig: Could not load animation library: " + ANIM_LIB_PATH)
		return
	var anim_instance := anim_scene.instantiate()
	var anim_player: AnimationPlayer = _find_anim_player_direct(anim_instance)
	if anim_player == null:
		anim_instance.queue_free()
		return

	var anim_root_node: Node = _anim.get_node(_anim.root_node) if _anim.root_node else _anim.get_parent()
	var char_skel_path := str(anim_root_node.get_path_to(_skeleton))

	var lib := AnimationLibrary.new()
	for anim_name in anim_player.get_animation_list():
		var a := anim_player.get_animation(anim_name)
		if a == null:
			continue
		var cloned := a.duplicate(true) as Animation
		for t_idx in range(cloned.get_track_count()):
			var tp_str := str(cloned.track_get_path(t_idx))
			var colon := tp_str.find(":")
			if colon != -1:
				cloned.track_set_path(t_idx, NodePath(char_skel_path + tp_str.substr(colon)))
		lib.add_animation(anim_name, cloned)
	_anim.add_animation_library("ual", lib)
	anim_instance.queue_free()
	_use_ual = true

func _find_anim_player_direct(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_anim_player_direct(c)
		if r:
			return r
	return null

func _configure_meshes_and_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var src := mi.get_active_material(i)
				var mat: ShaderMaterial
				if CharacterLook.is_skin_mesh(mi.name):
					mat = CharacterLook.make_skin_material(src, skin_color)
					_skin_mats.append(mat)
				elif CharacterLook.is_brow_mesh(mi.name):
					mat = CharacterLook.make_brow_material(src, hair_color)
				elif CharacterLook.is_armor_mesh(mi.name):
					# 3D Mantle, Bracers, Buckled Belt & Cuffed Boots transform with MU Armor Tiers!
					mat = ToonStyler.make_gear_from_material(src)
					mat.next_pass = CharacterLook.get_outline_material()
					_armor_mats.append(mat)
				elif CharacterLook.is_tunic_mesh(mi.name):
					mat = CharacterLook.make_cloth_toon_material(src)
				else:
					mat = ToonStyler.make_toon_from_material(src)
				mi.set_surface_override_material(i, mat)
				_all_mats.append(mat)
	for c in node.get_children():
		_configure_meshes_and_materials(c)

func _attach_hair() -> void:
	if _skeleton == null:
		return
	var head_idx := _skeleton.find_bone("Head")
	if head_idx < 0:
		head_idx = _skeleton.find_bone("head")
	if head_idx < 0:
		return

	_head_attach = BoneAttachment3D.new()
	_head_attach.bone_name = "Head" if _skeleton.find_bone("Head") >= 0 else "head"
	_skeleton.add_child(_head_attach)

	if not hair_style_path.is_empty():
		_load_hair()

func _load_hair() -> void:
	if _head_attach == null:
		return
	if _hair_node and is_instance_valid(_hair_node):
		_hair_node.queue_free()
		_hair_node = null
	_hair_mats.clear()

	var hair_scene := load(hair_style_path) as PackedScene
	if hair_scene == null:
		return
	_hair_node = hair_scene.instantiate()
	_hair_node.transform = CharacterLook.hair_transform(_skeleton, _skeleton.find_bone(_head_attach.bone_name), hair_style_path)
	_head_attach.add_child(_hair_node)
	_apply_hair_shader(_hair_node)

func _apply_hair_shader(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mi := node as MeshInstance3D
		for i in range(mi.mesh.get_surface_count()):
			var mat := CharacterLook.make_hair_material(mi.get_active_material(i), hair_color)
			mi.set_surface_override_material(i, mat)
			_hair_mats.append(mat)
			_all_mats.append(mat)
	for c in node.get_children():
		_apply_hair_shader(c)

func _attach_vessel_sword() -> void:
	if _skeleton == null:
		return
	var hand_idx := _skeleton.find_bone("hand_r")
	if hand_idx < 0:
		hand_idx = _skeleton.find_bone("RightHand")
	if hand_idx < 0:
		push_warning("VesselRig: Could not find hand_r bone")
		return

	_hand_r_attach = BoneAttachment3D.new()
	_hand_r_attach.bone_name = "hand_r" if _skeleton.find_bone("hand_r") >= 0 else "RightHand"
	_skeleton.add_child(_hand_r_attach)
	_rebuild_sword_mesh()

func _rebuild_sword_mesh() -> void:
	if _hand_r_attach == null:
		return
	if _equipped_sword_node and is_instance_valid(_equipped_sword_node):
		_equipped_sword_node.queue_free()
	_sword_mats.clear()

	var path := SWORD_2H_PATH if _sword_lv >= 10 else SWORD_1H_PATH
	var s := load(path) as PackedScene
	_equipped_sword_node = s.instantiate()
	_equipped_sword_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_equipped_sword_node.scale = Vector3.ONE * (1.15 if _sword_lv >= 10 else 1.25)
	_hand_r_attach.add_child(_equipped_sword_node)
	_apply_gear_shader_recursive(_equipped_sword_node, _sword_mats)

	if _sword_embers:
		if _sword_embers.get_parent():
			_sword_embers.get_parent().remove_child(_sword_embers)
		_sword_embers.position = Vector3(0, 0.85, 0)
		_equipped_sword_node.add_child(_sword_embers)

func _apply_gear_shader_recursive(node: Node, target_list: Array[ShaderMaterial]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var gm := ToonStyler.make_gear_from_material(mi.get_active_material(i))
				gm.next_pass = CharacterLook.get_outline_material()
				mi.set_surface_override_material(i, gm)
				target_list.append(gm)
				_all_mats.append(gm)
	for c in node.get_children():
		_apply_gear_shader_recursive(c, target_list)

func _build_slash_and_embers() -> void:
	_slash_mat = StandardMaterial3D.new()
	_slash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_slash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slash_mat.albedo_color = Color(0.95, 0.98, 1.0, 0.0)
	_slash_arc_mesh = MeshInstance3D.new()
	var arc := TorusMesh.new()
	arc.inner_radius = 1.25
	arc.outer_radius = 2.1
	_slash_arc_mesh.mesh = arc
	_slash_arc_mesh.material_override = _slash_mat
	_slash_arc_mesh.position = Vector3(0, 1.1, 0.4)
	_slash_arc_mesh.scale = Vector3(1.0, 0.16, 1.0)
	_slash_arc_mesh.visible = false
	add_child(_slash_arc_mesh)

	_armor_embers = _make_ember_particles(Vector3(0, 1.1, 0), 0.65)
	add_child(_armor_embers)
	_sword_embers = _make_ember_particles(Vector3(0, 0.85, 0), 0.22)

func _make_ember_particles(pos: Vector3, spread_radius: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = pos
	p.emitting = false
	p.amount = 16
	p.lifetime = 1.2
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = spread_radius
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.95
	pm.gravity = Vector3(0, 0.35, 0)
	pm.scale_min = 0.045
	pm.scale_max = 0.095
	p.process_material = pm

	var sp := SphereMesh.new()
	sp.radius = 0.5
	sp.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.88, 0.38)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.82, 0.32)
	mat.emission_energy_multiplier = 2.2
	sp.material = mat
	p.draw_pass_1 = sp
	return p

func set_gear_levels(armor_lv: int, sword_lv: int) -> void:
	var sword_tier_crossed := (_sword_lv < 10 and sword_lv >= 10) or (_sword_lv >= 10 and sword_lv < 10)
	_armor_lv = armor_lv
	_sword_lv = sword_lv
	if sword_tier_crossed and _hand_r_attach != null:
		_rebuild_sword_mesh()

	for m in _armor_mats:
		GearTiers.apply_to_gear_material(m, armor_lv, false)
	for m in _sword_mats:
		GearTiers.apply_to_gear_material(m, sword_lv, true)

	var a_info := GearTiers.get_tier_info(armor_lv)
	var s_info := GearTiers.get_tier_info(sword_lv)
	_update_embers(_armor_embers, a_info["ember_amount"], a_info["ember_color"])
	_update_embers(_sword_embers, int(s_info["ember_amount"] * 0.75), s_info["ember_color"])

func _update_embers(p: GPUParticles3D, count: int, col: Color) -> void:
	if p == null:
		return
	if count <= 0:
		p.emitting = false
		return
	p.amount = clampi(count, 4, 48)
	var mesh := p.draw_pass_1 as SphereMesh
	if mesh and mesh.material is StandardMaterial3D:
		var m := mesh.material as StandardMaterial3D
		m.albedo_color = col
		m.emission = col
	p.emitting = true

func play_cheer() -> void:
	_action_timer = 1.2
	_play_anim(ANIM_DANCE, 0.12, false)

func trigger_attack(combo_step: int, sword_lv: int) -> void:
	_action_timer = 0.34
	_is_spinning = false
	var clips := [ANIM_SWORD_ATTACK, ANIM_PUNCH_JAB, ANIM_PUNCH_CROSS]
	_play_anim(clips[combo_step % 3], 0.06, false, 1.45)

	var info := GearTiers.get_tier_info(sword_lv)
	var arc_col: Color = info["rim_color"] if sword_lv >= 7 else Color(0.95, 0.97, 1.0)
	_slash_mat.albedo_color = Color(arc_col.r, arc_col.g, arc_col.b, 0.78)
	_slash_arc_mesh.scale = Vector3(1.0, 0.16, 1.0)
	_slash_arc_mesh.rotation_degrees = Vector3(0, 0, -14.0 if combo_step % 2 == 0 else 14.0)
	_slash_arc_mesh.visible = true

func trigger_whirlwind(sword_lv: int) -> void:
	_action_timer = 0.52
	_is_spinning = true
	_play_anim(ANIM_SWORD_ATTACK, 0.06, false, 2.0)
	var info := GearTiers.get_tier_info(sword_lv)
	var arc_col: Color = info["rim_color"] if sword_lv >= 7 else Color(0.65, 0.90, 1.0)
	_slash_mat.albedo_color = Color(arc_col.r, arc_col.g, arc_col.b, 0.85)
	_slash_arc_mesh.scale = Vector3(1.65, 0.22, 1.65)
	_slash_arc_mesh.visible = true

func trigger_dash() -> void:
	_action_timer = 0.26
	_is_spinning = false
	_play_anim(ANIM_ROLL, 0.05, false, 1.6)

func trigger_hit_flash() -> void:
	_hit_flash = 1.0

func _resolve_anim_name(clip: String) -> String:
	if _anim == null:
		return ""
	var alt := clip.replace("_Loop", "")
	for cand in [clip, "ual/" + clip, alt, "ual/" + alt]:
		if not cand.is_empty() and _anim.has_animation(cand):
			return cand
	return ""

func _play_anim(clip_name: String, blend: float = 0.12, loop_it: bool = false, speed: float = 1.0) -> void:
	if _anim == null:
		return
	var resolved := _resolve_anim_name(clip_name)
	if resolved.is_empty():
		return
	var a := _anim.get_animation(resolved)
	if a:
		a.loop_mode = Animation.LOOP_LINEAR if loop_it else Animation.LOOP_NONE
	_anim.play(resolved, blend, speed)

func update_animation(delta: float, move_speed_ratio: float) -> void:
	_time += delta
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta * 6.0)
		for m in _all_mats:
			if is_instance_valid(m):
				m.set_shader_parameter("hit_flash", _hit_flash)

	if _action_timer > 0.0:
		_action_timer = maxf(0.0, _action_timer - delta)
		if _slash_arc_mesh.visible:
			_slash_arc_mesh.rotation.y += delta * (18.0 if _is_spinning else 10.0)
			_slash_mat.albedo_color.a = clampf(_action_timer * 2.2, 0.0, 0.85)
		if _action_timer <= 0.0:
			_slash_arc_mesh.visible = false
			_is_spinning = false
			_current_loco = ""
		return

	var target_loco := ANIM_RUN if move_speed_ratio > 0.15 else ANIM_IDLE
	if target_loco != _current_loco:
		_current_loco = target_loco
		_play_anim(target_loco, 0.15, true, 1.1 if move_speed_ratio > 0.15 else 1.0)
