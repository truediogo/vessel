class_name WildEnemy
extends CharacterBody3D

# Real rigged & animated 3D fantasy enemies (KayKit Skeletons + Weapons) in cel-shading:
# BOAR -> Meadow Stalker (Skeleton_Rogue), KOBOLD -> Ruin Vanguard (Skeleton_Warrior),
# BOSS -> Towering Crimson Labyrinth Lord (2.15x Skeleton_Warrior with glowing crimson armor!)

signal defeated(enemy: WildEnemy, pos: Vector3, reward: Dictionary)

enum Kind { BOAR, KOBOLD, BOSS }

const MODEL_PATHS := {
	Kind.BOAR: "res://addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Rogue.glb",
	Kind.KOBOLD: "res://addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Warrior.glb",
	Kind.BOSS: "res://addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Warrior.glb",
}
const AXE_PATH := "res://addons/kaykit_character_pack_skeletons/Assets/gltf/Skeleton_Axe.gltf"
const BLADE_PATH := "res://addons/kaykit_character_pack_skeletons/Assets/gltf/Skeleton_Blade.gltf"
const SHIELD_PATH := "res://addons/kaykit_character_pack_skeletons/Assets/gltf/Skeleton_Shield_Large_A.gltf"
const BOSS_SWORD_PATH := "res://addons/kaykit_character_pack_adventures/Assets/gltf/sword_2handed.gltf"

@export var kind: Kind = Kind.BOAR
@export var home_position: Vector3 = Vector3.ZERO

var max_hp := 70
var hp := 70
var attack_damage := 12
var move_speed := 4.2
var aggro_range := 10.5
var leash_range := 18.0
var attack_range := 2.6
var windup_duration := 0.72
var attack_cooldown := 1.45
var enemy_name := "Meadow Stalker"

var _state := "idle"
var _state_timer := 0.0
var _respawn_timer := 0.0
var _hit_flash := 0.0
var _knockback := Vector3.ZERO
var _strike_dir := Vector3.FORWARD
var _boss_slam_next := false
var _current_anim := ""

var _model_root: Node3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var telegraph_mesh: MeshInstance3D
var telegraph_mat: StandardMaterial3D
var hp_label: Label3D
var _mats: Array[ShaderMaterial] = []
var player_ref: Node3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	_configure_stats()
	_build_collider()
	_build_visuals()
	_build_telegraph()
	_build_hp_label()
	global_position = home_position

func _configure_stats() -> void:
	match kind:
		Kind.BOAR:
			enemy_name = "Meadow Stalker"
			max_hp = 68
			attack_damage = 11
			move_speed = 4.7
			aggro_range = 10.5
			attack_range = 3.0
			windup_duration = 0.65
			attack_cooldown = 1.35
		Kind.KOBOLD:
			enemy_name = "Ruin Vanguard"
			max_hp = 120
			attack_damage = 16
			move_speed = 4.0
			aggro_range = 11.5
			attack_range = 2.7
			windup_duration = 0.72
			attack_cooldown = 1.35
		Kind.BOSS:
			enemy_name = "Labyrinth Crimson Lord"
			max_hp = 480
			attack_damage = 26
			move_speed = 3.6
			aggro_range = 15.0
			leash_range = 22.0
			attack_range = 4.4
			windup_duration = 0.90
			attack_cooldown = 1.55
	hp = max_hp

func _build_collider() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	if kind == Kind.BOSS:
		cap.radius = 1.15
		cap.height = 3.8
		cs.position = Vector3(0, 1.9, 0)
	elif kind == Kind.KOBOLD:
		cap.radius = 0.55
		cap.height = 1.9
		cs.position = Vector3(0, 0.95, 0)
	else:
		cap.radius = 0.50
		cap.height = 1.75
		cs.position = Vector3(0, 0.88, 0)
	cs.shape = cap
	add_child(cs)

func _build_visuals() -> void:
	var scene := load(MODEL_PATHS[kind]) as PackedScene
	_model_root = scene.instantiate()
	var scl := 2.45 if kind == Kind.BOSS else (1.48 if kind == Kind.KOBOLD else 1.32)
	_model_root.scale = Vector3.ONE * scl
	add_child(_model_root)

	_find_rig(_model_root)
	_mats = ToonStyler.apply_toon_recursive(_model_root, Color(0.28, 0.24, 0.42), 0.30)

	# Give the Boss ominous obsidian-crimson enchanted plating & fiery glowing eyes!
	if kind == Kind.BOSS:
		_style_boss_meshes(_model_root)

	# Attach real sculpted 3D weapons to handslot.r and handslot.l!
	if _skeleton:
		var hr := BoneAttachment3D.new()
		hr.bone_name = "handslot.r"
		_skeleton.add_child(hr)
		var w_path := BOSS_SWORD_PATH if kind == Kind.BOSS else (AXE_PATH if kind == Kind.KOBOLD else BLADE_PATH)
		var w := (load(w_path) as PackedScene).instantiate()
		w.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		w.scale = Vector3.ONE * (1.25 if kind == Kind.BOSS else 1.0)
		hr.add_child(w)
		var w_mats := ToonStyler.apply_toon_recursive(w, Color(0.30, 0.14, 0.22), 0.45)
		if kind == Kind.BOSS:
			for m in w_mats:
				m.set_shader_parameter("albedo_color", Color(0.95, 0.26, 0.22))
				m.set_shader_parameter("emission_color", Color(1.0, 0.24, 0.14))
				m.set_shader_parameter("emission_strength", 1.1)
		_mats.append_array(w_mats)

		if kind == Kind.KOBOLD:
			var hl := BoneAttachment3D.new()
			hl.bone_name = "handslot.l"
			_skeleton.add_child(hl)
			var sh := (load(SHIELD_PATH) as PackedScene).instantiate()
			sh.rotation_degrees = Vector3(90.0, 90.0, 0.0)
			hl.add_child(sh)
			_mats.append_array(ToonStyler.apply_toon_recursive(sh))

	_play_anim("Idle", 0.0, true)

func _find_rig(n: Node) -> void:
	if n is AnimationPlayer:
		_anim = n as AnimationPlayer
	elif n is Skeleton3D:
		_skeleton = n as Skeleton3D
	for c in n.get_children():
		_find_rig(c)

func _style_boss_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var nlow := mi.name.to_lower()
		for i in range(mi.mesh.get_surface_count()):
			var sm := mi.get_surface_override_material(i) as ShaderMaterial
			if sm == null:
				continue
			if nlow.contains("eye"):
				sm.set_shader_parameter("albedo_color", Color(1.0, 0.20, 0.14))
				sm.set_shader_parameter("emission_color", Color(1.0, 0.22, 0.12))
				sm.set_shader_parameter("emission_strength", 3.2)
			elif nlow.contains("cloak"):
				sm.set_shader_parameter("albedo_color", Color(0.55, 0.12, 0.18))
			else:
				sm.set_shader_parameter("albedo_color", Color(0.52, 0.36, 0.44))
				sm.set_shader_parameter("rim_color", Color(1.0, 0.35, 0.26))
				sm.set_shader_parameter("rim_strength", 0.72)
	for c in node.get_children():
		_style_boss_meshes(c)

func _play_anim(clip_name: String, blend: float = 0.12, loop_it: bool = false, speed: float = 1.0) -> void:
	if _anim == null:
		return
	var target := clip_name
	if not _anim.has_animation(target):
		target = "Idle"
	if not _anim.has_animation(target):
		return
	if target == _current_anim and loop_it:
		return
	_current_anim = target
	var a := _anim.get_animation(target)
	if a:
		a.loop_mode = Animation.LOOP_LINEAR if loop_it else Animation.LOOP_NONE
	_anim.play(target, blend, speed)

func _build_telegraph() -> void:
	telegraph_mat = StandardMaterial3D.new()
	telegraph_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	telegraph_mat.albedo_color = Color(1.0, 0.24, 0.14, 0.42)

	telegraph_mesh = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = attack_range * 0.95
	disc.bottom_radius = attack_range * 0.95
	disc.height = 0.04
	telegraph_mesh.mesh = disc
	telegraph_mesh.material_override = telegraph_mat
	telegraph_mesh.position = Vector3(0, 0.08, 0)
	telegraph_mesh.visible = false
	add_child(telegraph_mesh)

func _build_hp_label() -> void:
	hp_label = Label3D.new()
	hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_label.no_depth_test = true
	hp_label.font_size = 38 if kind == Kind.BOSS else 26
	hp_label.outline_size = 8
	hp_label.modulate = Color(1.0, 0.42, 0.36) if kind == Kind.BOSS else Color(1.0, 0.94, 0.80)
	hp_label.position = Vector3(0, 5.1 if kind == Kind.BOSS else 2.55, 0)
	add_child(hp_label)
	_refresh_hp_label()

func _refresh_hp_label() -> void:
	if hp_label == null:
		return
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var bars := int(round(ratio * 10.0))
	hp_label.text = "%s\n[%s%s] %d/%d" % [enemy_name, "■".repeat(bars), "·".repeat(10 - bars), hp, max_hp]

func is_alive() -> bool:
	return _state != "dead"

func take_damage(amount: int, from_pos: Vector3, knock_force: float = 5.5) -> void:
	if _state == "dead":
		return
	hp = maxi(0, hp - amount)
	_hit_flash = 1.0
	var push := (global_position - from_pos)
	push.y = 0.0
	if push.length() > 0.01:
		var resist := 0.22 if kind == Kind.BOSS else 1.0
		_knockback = push.normalized() * knock_force * resist
	_refresh_hp_label()
	if hp <= 0:
		_die()
	elif _state != "windup" and _state != "strike":
		_play_anim("Hit_A", 0.05, false, 1.3)

func _die() -> void:
	_state = "dead"
	telegraph_mesh.visible = false
	_play_anim("Death_A", 0.08, false, 1.1)
	set_physics_process(false)
	_respawn_timer = 18.0 if kind == Kind.BOSS else 9.0

	var reward := {"gold": 14, "ore": 1, "shards": 0}
	if kind == Kind.KOBOLD:
		reward = {"gold": 28, "ore": 2, "shards": 0}
	elif kind == Kind.BOSS:
		reward = {"gold": 120, "ore": 6, "shards": 2}
	defeated.emit(self, global_position, reward)

func _process(delta: float) -> void:
	if _state == "dead":
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			hp = max_hp
			global_position = home_position
			_state = "idle"
			visible = true
			set_physics_process(true)
			_current_anim = ""
			_play_anim("Idle", 0.1, true)
			_refresh_hp_label()
		elif _respawn_timer < (16.5 if kind == Kind.BOSS else 7.5):
			visible = false
		return

	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta * 6.5)
		for m in _mats:
			if is_instance_valid(m):
				m.set_shader_parameter("hit_flash", _hit_flash)

func _physics_process(delta: float) -> void:
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 18.0)

	if player_ref == null or not is_instance_valid(player_ref):
		return

	var to_player := player_ref.global_position - global_position
	to_player.y = 0.0
	var dist_player := to_player.length()
	var dist_home := (global_position - home_position).length()
	var player_in_wilds := player_ref.global_position.z < -2.8

	match _state:
		"idle":
			velocity = _knockback
			if player_in_wilds and dist_player < aggro_range:
				_state = "chase"
			elif dist_home > 1.2:
				var back := (home_position - global_position)
				back.y = 0.0
				velocity = back.normalized() * move_speed * 0.75 + _knockback
				_face_dir(back)
				_play_anim("Walking_A", 0.15, true)
			else:
				_play_anim("Idle", 0.18, true)

		"chase":
			if not player_in_wilds or dist_home > leash_range or dist_player > aggro_range * 1.45:
				_state = "idle"
				return
			if dist_player <= attack_range * 0.92:
				_start_windup(to_player)
				return
			var dir := to_player.normalized()
			velocity = dir * move_speed + _knockback
			_face_dir(dir)
			_play_anim("Running_A", 0.12, true, 1.05)

		"windup":
			velocity = _knockback * 0.3
			_state_timer -= delta
			var p := clampf(1.0 - (_state_timer / windup_duration), 0.0, 1.0)
			telegraph_mesh.scale = Vector3.ONE * lerpf(0.35, 1.0, p)
			telegraph_mat.albedo_color = Color(1.0, lerpf(0.45, 0.10, p), 0.10, 0.35 + p * 0.35)
			if _state_timer <= 0.0:
				_execute_strike()

		"strike":
			_state_timer -= delta
			if kind == Kind.BOAR:
				velocity = _strike_dir * 10.0 + _knockback
			else:
				velocity = _knockback
			if _state_timer <= 0.0:
				_state = "cooldown"
				_state_timer = attack_cooldown

		"cooldown":
			velocity = _knockback
			_state_timer -= delta
			_play_anim("Idle_Combat", 0.15, true)
			if _state_timer <= 0.0:
				_state = "chase" if (player_in_wilds and dist_player < aggro_range * 1.2) else "idle"

	move_and_slide()

func _face_dir(dir: Vector3) -> void:
	if dir.length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)

func _start_windup(to_player: Vector3) -> void:
	_state = "windup"
	_state_timer = windup_duration
	_strike_dir = to_player.normalized()
	_face_dir(_strike_dir)
	telegraph_mesh.visible = true
	_play_anim("Idle_Combat", 0.08, true)
	if kind == Kind.BOSS and _boss_slam_next:
		telegraph_mesh.position = Vector3(0, 0.08, 0)
		(telegraph_mesh.mesh as CylinderMesh).top_radius = 5.6
		(telegraph_mesh.mesh as CylinderMesh).bottom_radius = 5.6
	else:
		var fwd := 1.6 if kind == Kind.BOSS else (1.3 if kind == Kind.BOAR else 1.1)
		var rad := 3.4 if kind == Kind.BOSS else (1.9 if kind == Kind.KOBOLD else 1.65)
		telegraph_mesh.position = Vector3(0, 0.08, fwd)
		(telegraph_mesh.mesh as CylinderMesh).top_radius = rad
		(telegraph_mesh.mesh as CylinderMesh).bottom_radius = rad

func _execute_strike() -> void:
	telegraph_mesh.visible = false
	_state = "strike"
	_state_timer = 0.34
	if kind == Kind.BOSS:
		_play_anim("2H_Melee_Attack_Spin" if _boss_slam_next else "1H_Melee_Attack_Jump_Chop", 0.06, false, 1.3)
	elif kind == Kind.KOBOLD:
		_play_anim("1H_Melee_Attack_Chop", 0.06, false, 1.35)
	else:
		_play_anim("1H_Melee_Attack_Stab", 0.06, false, 1.45)

	if player_ref and player_ref.has_method("receive_damage"):
		var hit_center := global_position + (global_transform.basis.z * telegraph_mesh.position.z)
		var hit_radius := (telegraph_mesh.mesh as CylinderMesh).top_radius + 0.55
		var d := player_ref.global_position - hit_center
		d.y = 0.0
		if d.length() <= hit_radius:
			var dmg := int(attack_damage * (1.3 if (kind == Kind.BOSS and _boss_slam_next) else 1.0))
			player_ref.receive_damage(dmg, global_position)
	if kind == Kind.BOSS:
		_boss_slam_next = not _boss_slam_next
