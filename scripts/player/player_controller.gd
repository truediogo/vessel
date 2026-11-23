class_name PlayerController
extends CharacterBody3D

# Isometric action-RPG controller with PC mouse+keyboard & optional mobile touch joystick input,
# 3-hit sword combo, Q Whirlwind, E SAO-style Dash-Thrust, Shift Evade, and Zoned Loot-Drop risk.

signal stats_changed
signal zone_changed(zone_name: String, is_safe: bool)
signal interact_forge_requested
signal toast_message(text: String, color: Color)
signal dropped_loot_created(pos: Vector3, dropped: Dictionary)

var rig: VesselRig
var camera_rig: Node3D
var camera: Camera3D

# Appearance from character creation (set by main.gd before _ready)
var appearance: Dictionary = {}

# Persistent-ready Player State (clean dictionary boundary for future authoritative server sync)
var max_hp := 120
var hp := 120
var sword_level := 0
var armor_level := 0
var banked_gold := 120
var banked_ore := 10
var banked_shards := 1
var run_gold := 0
var run_ore := 0
var run_shards := 0

# Movement & Combat Tuning
var base_move_speed := 7.2
var _combo_step := 0
var _combo_reset_timer := 0.0
var _attack_cd := 0.0
var _q_cd := 0.0
var _e_cd := 0.0
var _dash_cd := 0.0
var _dash_timer := 0.0
var _dash_dir := Vector3.ZERO
var _invuln_timer := 0.0
var _camera_zoom := 15.5
var _shake_strength := 0.0

var forge_position := Vector3(-17.8, 0.0, 16.5)
var spawn_position := Vector3(0.0, 0.0, 17.8)
var in_safe_plaza := true
var current_zone_name := "LORENCIA STRONGHOLD — SAFE ZONE"
var ui_blocking_input := false
var mobile_move_vector := Vector2.ZERO

var enemies_container: Node3D
var vfx_container: Node3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_setup_inputs()
	_build_collider()
	_build_rig_and_camera()
	global_position = spawn_position
	_recalc_stats()

func _setup_inputs() -> void:
	_ensure_key_action("move_up", [KEY_W, KEY_UP])
	_ensure_key_action("move_down", [KEY_S, KEY_DOWN])
	_ensure_key_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_key_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_key_action("attack", [KEY_SPACE])
	_ensure_key_action("skill_q", [KEY_Q])
	_ensure_key_action("skill_e", [KEY_E])
	_ensure_key_action("dash", [KEY_SHIFT])
	_ensure_key_action("interact", [KEY_F])

func _ensure_key_action(action_name: String, keys: Array[Key]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action_name, ev)

func _build_collider() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.85
	cs.shape = cap
	cs.position = Vector3(0, 0.92, 0)
	add_child(cs)

func _build_rig_and_camera() -> void:
	rig = VesselRig.new()
	if appearance.size() > 0:
		rig.set_appearance_data(appearance)
	add_child(rig)
	rig.set_gear_levels(armor_level, sword_level)

	# Isometric angled camera rig (detached in _physics_process for buttery smoothing)
	camera_rig = Node3D.new()
	camera_rig.top_level = true
	add_child(camera_rig)

	camera = Camera3D.new()
	camera.fov = 40.0
	camera.near = 0.5
	camera.far = 180.0
	camera_rig.add_child(camera)
	_update_camera_offset()

func _update_camera_offset() -> void:
	# Rich 3/4 isometric angle (~37°)
	camera.position = Vector3(0.0, _camera_zoom * 0.64, _camera_zoom * 0.86)
	if camera.is_inside_tree():
		camera.look_at(Vector3(0.0, 0.65, 0.0), Vector3.UP)
	else:
		camera.call_deferred("look_at", Vector3(0.0, 0.65, 0.0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_zoom = clampf(_camera_zoom - 1.2, 9.5, 28.0)
			_update_camera_offset()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_zoom = clampf(_camera_zoom + 1.2, 9.5, 28.0)
			_update_camera_offset()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not ui_blocking_input:
			perform_basic_attack()

func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_q_cd = maxf(0.0, _q_cd - delta)
	_e_cd = maxf(0.0, _e_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_invuln_timer = maxf(0.0, _invuln_timer - delta)
	_combo_reset_timer = maxf(0.0, _combo_reset_timer - delta)
	if _combo_reset_timer <= 0.0:
		_combo_step = 0

	# Gentle HP regen while safe in the Plaza
	if in_safe_plaza and hp < max_hp:
		hp = mini(max_hp, hp + int(ceil(delta * 18.0)))
		stats_changed.emit()

	# Input Handling
	var input_vec := Vector2.ZERO
	if not ui_blocking_input:
		input_vec = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		)
		if mobile_move_vector.length() > 0.1:
			input_vec = mobile_move_vector
		if Input.is_action_just_pressed("attack"):
			perform_basic_attack()
		if Input.is_action_just_pressed("skill_q"):
			perform_whirlwind()
		if Input.is_action_just_pressed("skill_e"):
			perform_sword_skill_lunge()
		if Input.is_action_just_pressed("dash"):
			perform_dash(input_vec)
		if Input.is_action_just_pressed("interact") and is_near_forge():
			interact_forge_requested.emit()

	if _dash_timer > 0.0:
		_dash_timer = maxf(0.0, _dash_timer - delta)
		velocity = _dash_dir * 18.5
	elif rig._action_timer > 0.0:
		# Plant feet during attack animations — no sliding
		velocity = velocity.move_toward(Vector3.ZERO, delta * 60.0)
	elif input_vec.length() > 0.05:
		var dir := Vector3(input_vec.x, 0.0, input_vec.y).normalized()
		velocity = dir * base_move_speed
		var target_yaw := atan2(dir.x, dir.z)
		rig.rotation.y = lerp_angle(rig.rotation.y, target_yaw, delta * 14.0)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, delta * 36.0)

	move_and_slide()

	# Keep player inside expanded 5-district playable world bounds
	global_position.x = clampf(global_position.x, -28.0, 27.5)
	global_position.z = clampf(global_position.z, -53.0, 30.0)
	global_position.y = 0.0

	var speed_ratio := clampf(Vector2(velocity.x, velocity.z).length() / base_move_speed, 0.0, 1.0)
	rig.update_animation(delta, speed_ratio)

	_update_zone_state()
	_update_camera_follow(delta)

func _update_camera_follow(delta: float) -> void:
	var target_pos := global_position + Vector3(0, 0.8, 0)
	camera_rig.global_position = camera_rig.global_position.lerp(target_pos, clampf(delta * 9.5, 0.0, 1.0))
	if _shake_strength > 0.01:
		_shake_strength = maxf(0.0, _shake_strength - delta * 3.8)
		camera.h_offset = randf_range(-_shake_strength, _shake_strength)
		camera.v_offset = randf_range(-_shake_strength, _shake_strength)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func _update_zone_state() -> void:
	var new_safe := global_position.z >= -2.2
	var new_name := "LORENCIA STRONGHOLD — SAFE ZONE"
	if global_position.z < -28.0:
		new_name = "ANCIENT LABYRINTH — BOSS TERRITORY"
	elif not new_safe:
		new_name = "LORENCIA OUTSKIRTS — RUN LOOT AT RISK"

	if new_safe and not in_safe_plaza and has_unbanked_loot():
		_bank_run_loot()

	if new_name != current_zone_name or new_safe != in_safe_plaza:
		in_safe_plaza = new_safe
		current_zone_name = new_name
		zone_changed.emit(current_zone_name, in_safe_plaza)

func is_near_forge() -> bool:
	return global_position.distance_to(forge_position) <= 5.4

func has_unbanked_loot() -> bool:
	return run_gold > 0 or run_ore > 0 or run_shards > 0

func _bank_run_loot() -> void:
	var msg := "Banked safe in Plaza: +%dg" % run_gold
	if run_ore > 0:
		msg += ", +%d Ore" % run_ore
	if run_shards > 0:
		msg += ", +%d Boss Shards" % run_shards
	banked_gold += run_gold
	banked_ore += run_ore
	banked_shards += run_shards
	run_gold = 0
	run_ore = 0
	run_shards = 0
	stats_changed.emit()
	toast_message.emit(msg, Color(0.48, 0.96, 0.65))

func add_loot(contents: Dictionary) -> void:
	var g := int(contents.get("gold", 0))
	var o := int(contents.get("ore", 0))
	var s := int(contents.get("shards", 0))
	if in_safe_plaza:
		banked_gold += g
		banked_ore += o
		banked_shards += s
	else:
		run_gold += g
		run_ore += o
		run_shards += s
	stats_changed.emit()

func get_attack_power() -> int:
	return 18 + sword_level * 6

func get_defense_reduction() -> float:
	return clampf(armor_level * 0.038, 0.0, 0.58)

func _recalc_stats() -> void:
	var prev_max := max_hp
	max_hp = 120 + armor_level * 14
	hp = mini(max_hp, hp + maxi(0, max_hp - prev_max))
	if rig:
		rig.set_gear_levels(armor_level, sword_level)
	stats_changed.emit()

func set_gear_levels(new_armor: int, new_sword: int) -> void:
	armor_level = clampi(new_armor, 0, GearTiers.MAX_LEVEL)
	sword_level = clampi(new_sword, 0, GearTiers.MAX_LEVEL)
	_recalc_stats()

func _aim_toward_cursor() -> Vector3:
	if mobile_move_vector.length() > 0.1:
		return Vector3(mobile_move_vector.x, 0.0, mobile_move_vector.y).normalized()
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	if absf(ray_dir.y) > 0.001:
		var t := -ray_origin.y / ray_dir.y
		if t > 0.0:
			var hit := ray_origin + ray_dir * t
			var dir := hit - global_position
			dir.y = 0.0
			if dir.length() > 0.1:
				rig.rotation.y = atan2(dir.x, dir.z)
				return dir.normalized()
	return rig.global_transform.basis.z.normalized()

func perform_basic_attack() -> void:
	if _attack_cd > 0.0:
		return
	var aim := _aim_toward_cursor()
	_attack_cd = 0.30
	_combo_reset_timer = 1.15
	rig.trigger_attack(_combo_step, sword_level)
	var dmg := int(get_attack_power() * (1.35 if _combo_step == 2 else 1.0))
	var hit_count := _hit_enemies_in_cone(aim, 3.2, 0.15, dmg, 6.5 if _combo_step == 2 else 4.2)
	if hit_count > 0:
		add_camera_shake(0.16 if _combo_step == 2 else 0.09)
	_combo_step = (_combo_step + 1) % 3

func perform_whirlwind() -> void:
	if _q_cd > 0.0:
		return
	_q_cd = 3.8
	rig.trigger_whirlwind(sword_level)
	var dmg := int(get_attack_power() * 1.65)
	var hit_count := _hit_enemies_in_radius(global_position, 3.7, dmg, 8.0)
	add_camera_shake(0.24 if hit_count > 0 else 0.10)
	_spawn_ring_vfx(global_position + Vector3(0, 0.4, 0), 3.6, GearTiers.get_tier_info(sword_level)["rim_color"])

func perform_sword_skill_lunge() -> void:
	if _e_cd > 0.0:
		return
	_e_cd = 5.5
	var aim := _aim_toward_cursor()
	_dash_dir = aim
	_dash_timer = 0.22
	_invuln_timer = 0.28
	rig.trigger_attack(2, sword_level)
	var dmg := int(get_attack_power() * 2.2)
	var hit_count := _hit_enemies_in_cone(aim, 5.4, 0.55, dmg, 10.5)
	add_camera_shake(0.30 if hit_count > 0 else 0.14)
	_spawn_ring_vfx(global_position + aim * 2.4 + Vector3(0, 0.5, 0), 2.2, Color(0.45, 0.90, 1.0))

func perform_dash(input_vec: Vector2) -> void:
	if _dash_cd > 0.0:
		return
	_dash_cd = 1.35
	_dash_timer = 0.18
	_invuln_timer = 0.30
	if input_vec.length() > 0.05:
		_dash_dir = Vector3(input_vec.x, 0.0, input_vec.y).normalized()
	else:
		_dash_dir = rig.global_transform.basis.z.normalized()
	rig.rotation.y = atan2(_dash_dir.x, _dash_dir.z)
	rig.trigger_dash()
	_spawn_ring_vfx(global_position + Vector3(0, 0.15, 0), 1.0, Color(0.95, 0.92, 0.80))

func _hit_enemies_in_cone(aim: Vector3, reach: float, min_dot: float, dmg: int, knock: float) -> int:
	if enemies_container == null:
		return 0
	var hits := 0
	for child in enemies_container.get_children():
		if child is WildEnemy and child.is_alive():
			var to_e: Vector3 = child.global_position - global_position
			to_e.y = 0.0
			var dist := to_e.length()
			if dist <= reach + (0.8 if child.kind == WildEnemy.Kind.BOSS else 0.0):
				var dot_val := 1.0 if dist < 0.8 else aim.dot(to_e.normalized())
				if dot_val >= min_dot:
					child.take_damage(dmg, global_position, knock)
					_spawn_damage_popup(child.global_position + Vector3(0, 1.8, 0), dmg, Color(1.0, 0.92, 0.42))
					hits += 1
	return hits

func _hit_enemies_in_radius(center: Vector3, radius: float, dmg: int, knock: float) -> int:
	if enemies_container == null:
		return 0
	var hits := 0
	for child in enemies_container.get_children():
		if child is WildEnemy and child.is_alive():
			var to_e: Vector3 = child.global_position - center
			to_e.y = 0.0
			if to_e.length() <= radius + (0.9 if child.kind == WildEnemy.Kind.BOSS else 0.0):
				child.take_damage(dmg, center, knock)
				_spawn_damage_popup(child.global_position + Vector3(0, 1.8, 0), dmg, Color(0.55, 0.92, 1.0))
				hits += 1
	return hits

func receive_damage(raw_damage: int, from_pos: Vector3) -> void:
	if _invuln_timer > 0.0 or in_safe_plaza:
		return
	var reduced := maxi(2, int(round(float(raw_damage) * (1.0 - get_defense_reduction()))))
	hp = maxi(0, hp - reduced)
	_invuln_timer = 0.35
	rig.trigger_hit_flash()
	add_camera_shake(0.24)
	_spawn_damage_popup(global_position + Vector3(0, 1.8, 0), reduced, Color(1.0, 0.32, 0.28))
	stats_changed.emit()

	var push := global_position - from_pos
	push.y = 0.0
	if push.length() > 0.01:
		global_position += push.normalized() * 0.45

	if hp <= 0:
		_handle_defeat()

func _handle_defeat() -> void:
	# Zoned risk rule: Drop 50% of unbanked Run Loot on death; equipped gear & cosmetics stay safe!
	var dropped := {
		"gold": int(ceil(run_gold * 0.5)),
		"ore": int(ceil(run_ore * 0.5)),
		"shards": int(ceil(run_shards * 0.5)),
	}
	run_gold -= int(dropped["gold"])
	run_ore -= int(dropped["ore"])
	run_shards -= int(dropped["shards"])
	if int(dropped["gold"]) > 0 or int(dropped["ore"]) > 0 or int(dropped["shards"]) > 0:
		dropped_loot_created.emit(global_position, dropped)
		toast_message.emit("Defeated! Dropped half your unbanked Run Loot — run back to recover it!", Color(1.0, 0.45, 0.35))
	else:
		toast_message.emit("Defeated! Returned safely to the Sunlit Plaza Fountain.", Color(1.0, 0.72, 0.45))

	hp = max_hp
	global_position = spawn_position
	stats_changed.emit()

func add_camera_shake(amount: float) -> void:
	_shake_strength = maxf(_shake_strength, amount)

func get_cooldowns() -> Dictionary:
	return {"q": _q_cd, "e": _e_cd, "dash": _dash_cd}

func _spawn_damage_popup(world_pos: Vector3, amount: int, col: Color) -> void:
	if vfx_container == null:
		return
	var lbl := Label3D.new()
	lbl.text = str(amount)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 42
	lbl.outline_size = 8
	lbl.modulate = col
	lbl.position = world_pos + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	vfx_container.add_child(lbl)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 1.4, 0.65).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.65).set_delay(0.18)
	tw.chain().tween_callback(lbl.queue_free)

func _spawn_ring_vfx(world_pos: Vector3, radius: float, col: Color) -> void:
	if vfx_container == null:
		return
	var mi := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = radius * 0.78
	tor.outer_radius = radius
	mi.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col.r, col.g, col.b, 0.85)
	mi.material_override = mat
	mi.position = world_pos
	mi.scale = Vector3(0.25, 0.4, 0.25)
	vfx_container.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.15, 0.2, 1.15), 0.28).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(mi.queue_free)
