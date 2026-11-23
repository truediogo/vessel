class_name GameHUD
extends CanvasLayer

# Clean, readable PC + Mobile-ready HUD with Public Blacksmith Forge Modal & Mobile Controls Toggle

signal forge_upgrade_requested(slot: String)
signal sandbox_bump_requested(slot: String, delta_lv: int)
signal cycle_vessel_body_requested

var player: PlayerController

var zone_label: Label
var hp_bar: ProgressBar
var hp_text: Label
var gear_label: Label
var banked_label: Label
var run_loot_panel: PanelContainer
var run_loot_label: Label
var interact_hint: Label
var toast_label: Label
var broadcast_label: Label

var skill_q_lbl: Label
var skill_e_lbl: Label
var skill_dash_lbl: Label

var forge_panel: PanelContainer
var forge_sword_info: Label
var forge_armor_info: Label
var forge_result_label: Label

var mobile_controls_root: Control
var mobile_mode := false
var _joy_active := false
var _joy_center := Vector2.ZERO
var _joy_knob: ColorRect

func setup(p: PlayerController) -> void:
	player = p
	_build_ui()
	refresh_stats()

func _build_ui() -> void:
	# --- Top-Center Zone Banner ---
	var top_box := VBoxContainer.new()
	top_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_box.position = Vector2(-240, 14)
	top_box.custom_minimum_size = Vector2(480, 0)
	top_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(top_box)

	var zone_bg := _make_card(Color(0.10, 0.12, 0.17, 0.78), Color(0.86, 0.74, 0.42, 0.85))
	top_box.add_child(zone_bg)
	zone_label = _make_label("LORENCIA STRONGHOLD — SAFE ZONE", 18, Color(0.65, 0.96, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	zone_bg.add_child(zone_label)

	broadcast_label = _make_label("", 17, Color(1.0, 0.88, 0.35), HORIZONTAL_ALIGNMENT_CENTER)
	broadcast_label.visible = false
	top_box.add_child(broadcast_label)

	# --- Top-Left Vessel Status & Inventory ---
	var left_card := _make_card(Color(0.09, 0.11, 0.16, 0.82), Color(0.42, 0.48, 0.62, 0.7))
	left_card.position = Vector2(18, 16)
	left_card.custom_minimum_size = Vector2(290, 0)
	add_child(left_card)

	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 6)
	left_card.add_child(left_col)

	var title := _make_label("CARVED VESSEL", 16, Color(1.0, 0.92, 0.72))
	left_col.add_child(title)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(250, 20)
	hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.28, 0.82, 0.44)
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("fill", fill)
	left_col.add_child(hp_bar)

	hp_text = _make_label("HP 120 / 120", 13, Color(0.92, 0.96, 1.0))
	left_col.add_child(hp_text)

	gear_label = _make_label("Sword +0 · Armor +0", 14, Color(0.84, 0.90, 1.0))
	left_col.add_child(gear_label)

	banked_label = _make_label("Banked: 120g · 10 Ore · 1 Shard", 13, Color(0.94, 0.86, 0.60))
	left_col.add_child(banked_label)

	run_loot_panel = _make_card(Color(0.32, 0.16, 0.08, 0.88), Color(1.0, 0.68, 0.25, 0.9))
	run_loot_panel.visible = false
	left_col.add_child(run_loot_panel)
	run_loot_label = _make_label("Run Loot (At Risk): 0g", 13, Color(1.0, 0.88, 0.55))
	run_loot_panel.add_child(run_loot_label)

	# --- Top-Right Quick Actions & Customization Preview ---
	var right_card := _make_card(Color(0.09, 0.11, 0.16, 0.80), Color(0.42, 0.48, 0.62, 0.65))
	right_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_card.position = Vector2(-248, 16)
	right_card.custom_minimum_size = Vector2(230, 0)
	add_child(right_card)

	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 6)
	right_card.add_child(right_col)

	right_col.add_child(_make_label("QUICK PREVIEW", 13, Color(0.75, 0.82, 0.95)))

	var btn_forge := _make_button("Open Forge Anvil [F]")
	btn_forge.pressed.connect(toggle_forge_panel)
	right_col.add_child(btn_forge)

	var btn_body := _make_button("Swap Vessel: Warrior / Hunter / Mage")
	btn_body.pressed.connect(func(): cycle_vessel_body_requested.emit())
	right_col.add_child(btn_body)

	var btn_mobile := _make_button("Preview Mobile Controls")
	btn_mobile.pressed.connect(func():
		mobile_mode = not mobile_mode
		mobile_controls_root.visible = mobile_mode
	)
	right_col.add_child(btn_mobile)

	# --- Bottom-Center Skill Bar & Hints ---
	var bottom_col := VBoxContainer.new()
	bottom_col.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_col.position = Vector2(-280, -124)
	bottom_col.custom_minimum_size = Vector2(560, 0)
	bottom_col.add_theme_constant_override("separation", 6)
	add_child(bottom_col)

	interact_hint = _make_label("Press [F] to open the Public Blacksmith Forge", 15, Color(1.0, 0.88, 0.42), HORIZONTAL_ALIGNMENT_CENTER)
	interact_hint.visible = false
	bottom_col.add_child(interact_hint)

	toast_label = _make_label("", 15, Color(0.55, 0.96, 0.68), HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.visible = false
	bottom_col.add_child(toast_label)

	var skill_row := HBoxContainer.new()
	skill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_row.add_theme_constant_override("separation", 10)
	bottom_col.add_child(skill_row)

	_add_skill_chip(skill_row, "LMB / Space", "3-Hit Slash")
	skill_q_lbl = _add_skill_chip(skill_row, "Q", "Whirlwind")
	skill_e_lbl = _add_skill_chip(skill_row, "E", "Sword Lunge")
	skill_dash_lbl = _add_skill_chip(skill_row, "Shift", "Evade")
	_add_skill_chip(skill_row, "WASD / Wheel", "Move / Zoom")

	# --- Blacksmith Forge Modal ---
	_build_forge_modal()

	# --- Mobile Virtual Controls Preview ---
	_build_mobile_overlay()

func _build_forge_modal() -> void:
	forge_panel = _make_card(Color(0.08, 0.09, 0.14, 0.94), Color(1.0, 0.78, 0.30, 0.92))
	forge_panel.set_anchors_preset(Control.PRESET_CENTER)
	forge_panel.position = Vector2(-270, -200)
	forge_panel.custom_minimum_size = Vector2(540, 380)
	forge_panel.visible = false
	add_child(forge_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	forge_panel.add_child(col)

	col.add_child(_make_label("★ PUBLIC BLACKSMITH FORGE (MU TIER UPGRADES) ★", 18, Color(1.0, 0.86, 0.36), HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_make_label("Upgrade armor & sword to transform metal colors (+7 Cobalt, +10 Emerald, +13 Crimson-Gold).", 13, Color(0.84, 0.88, 0.95), HORIZONTAL_ALIGNMENT_CENTER))

	# Sword row
	var sw_box := _make_card(Color(0.13, 0.15, 0.22, 0.9), Color(0.45, 0.60, 0.85, 0.7))
	col.add_child(sw_box)
	var sw_row := HBoxContainer.new()
	sw_box.add_child(sw_row)
	forge_sword_info = _make_label("Sword +0", 14, Color.WHITE)
	forge_sword_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sw_row.add_child(forge_sword_info)
	var btn_sw := _make_button("FORGE SWORD")
	btn_sw.pressed.connect(func(): forge_upgrade_requested.emit("sword"))
	sw_row.add_child(btn_sw)

	# Armor row
	var ar_box := _make_card(Color(0.13, 0.15, 0.22, 0.9), Color(0.85, 0.62, 0.35, 0.7))
	col.add_child(ar_box)
	var ar_row := HBoxContainer.new()
	ar_box.add_child(ar_row)
	forge_armor_info = _make_label("Armor +0", 14, Color.WHITE)
	forge_armor_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ar_row.add_child(forge_armor_info)
	var btn_ar := _make_button("FORGE ARMOR")
	btn_ar.pressed.connect(func(): forge_upgrade_requested.emit("armor"))
	ar_row.add_child(btn_ar)

	forge_result_label = _make_label("Farm Ore & Boss Shards in the Wild Meadows north of the archway — or test tiers below.", 13, Color(0.75, 0.90, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(forge_result_label)

	# Sandbox Free Visual Test Row
	var sb_row := HBoxContainer.new()
	sb_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sb_row.add_theme_constant_override("separation", 8)
	col.add_child(sb_row)

	var b_test_all := _make_button("Test +1 Both (Free)")
	b_test_all.pressed.connect(func(): sandbox_bump_requested.emit("both", 1))
	sb_row.add_child(b_test_all)

	var b_jump7 := _make_button("Jump +7 Cobalt")
	b_jump7.pressed.connect(func(): sandbox_bump_requested.emit("set7", 7))
	sb_row.add_child(b_jump7)

	var b_jump13 := _make_button("Jump +13 Gold")
	b_jump13.pressed.connect(func(): sandbox_bump_requested.emit("set13", 13))
	sb_row.add_child(b_jump13)

	var b_reset := _make_button("Reset +0")
	b_reset.pressed.connect(func(): sandbox_bump_requested.emit("reset", 0))
	sb_row.add_child(b_reset)

	var btn_close := _make_button("Close [Esc / F]")
	btn_close.pressed.connect(toggle_forge_panel)
	col.add_child(btn_close)

func _build_mobile_overlay() -> void:
	mobile_controls_root = Control.new()
	mobile_controls_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	mobile_controls_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_controls_root.visible = false
	add_child(mobile_controls_root)

	# Left virtual thumb joystick pad
	var pad := Panel.new()
	pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pad.position = Vector2(44, -196)
	pad.custom_minimum_size = Vector2(148, 148)
	pad.gui_input.connect(_on_joystick_input.bind(pad))
	var pad_style := StyleBoxFlat.new()
	pad_style.bg_color = Color(0.12, 0.15, 0.22, 0.45)
	pad_style.border_color = Color(0.95, 0.90, 0.72, 0.65)
	pad_style.set_border_width_all(2)
	pad_style.set_corner_radius_all(74)
	pad.add_theme_stylebox_override("panel", pad_style)
	mobile_controls_root.add_child(pad)

	_joy_knob = ColorRect.new()
	_joy_knob.color = Color(1.0, 0.92, 0.65, 0.85)
	_joy_knob.size = Vector2(42, 42)
	_joy_knob.position = Vector2(53, 53)
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(_joy_knob)

	# Right thumb MOBA-style skill cluster
	var right_cluster := GridContainer.new()
	right_cluster.columns = 2
	right_cluster.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right_cluster.position = Vector2(-210, -190)
	right_cluster.add_theme_constant_override("h_separation", 10)
	right_cluster.add_theme_constant_override("v_separation", 10)
	mobile_controls_root.add_child(right_cluster)

	var m_atk := _make_button("SLASH")
	m_atk.custom_minimum_size = Vector2(88, 64)
	m_atk.pressed.connect(func(): player.perform_basic_attack())
	right_cluster.add_child(m_atk)

	var m_q := _make_button("SPIN (Q)")
	m_q.custom_minimum_size = Vector2(88, 64)
	m_q.pressed.connect(func(): player.perform_whirlwind())
	right_cluster.add_child(m_q)

	var m_e := _make_button("LUNGE (E)")
	m_e.custom_minimum_size = Vector2(88, 64)
	m_e.pressed.connect(func(): player.perform_sword_skill_lunge())
	right_cluster.add_child(m_e)

	var m_dash := _make_button("EVADE")
	m_dash.custom_minimum_size = Vector2(88, 64)
	m_dash.pressed.connect(func(): player.perform_dash(player.mobile_move_vector))
	right_cluster.add_child(m_dash)

func _on_joystick_input(event: InputEvent, pad: Panel) -> void:
	var center := pad.size * 0.5
	var max_r := 52.0
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_joy_active = mb.pressed
			if not _joy_active:
				player.mobile_move_vector = Vector2.ZERO
				_joy_knob.position = center - _joy_knob.size * 0.5
			else:
				_update_joy(mb.position, center, max_r)
	elif event is InputEventMouseMotion and _joy_active:
		_update_joy((event as InputEventMouseMotion).position, center, max_r)

func _update_joy(pos: Vector2, center: Vector2, max_r: float) -> void:
	var d := pos - center
	if d.length() > max_r:
		d = d.normalized() * max_r
	_joy_knob.position = center + d - _joy_knob.size * 0.5
	player.mobile_move_vector = d / max_r

func _unhandled_input(event: InputEvent) -> void:
	if forge_panel.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle_forge_panel()

func toggle_forge_panel() -> void:
	forge_panel.visible = not forge_panel.visible
	player.ui_blocking_input = forge_panel.visible
	if forge_panel.visible:
		refresh_stats()

func set_zone(zone_text: String, is_safe: bool) -> void:
	zone_label.text = zone_text
	zone_label.add_theme_color_override("font_color", Color(0.65, 0.96, 0.72) if is_safe else Color(1.0, 0.58, 0.42))

func show_toast(text: String, col: Color) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", col)
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): toast_label.visible = false)

func show_plaza_broadcast(text: String, col: Color) -> void:
	broadcast_label.text = text
	broadcast_label.add_theme_color_override("font_color", col)
	broadcast_label.visible = true
	broadcast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.4)
	tw.tween_property(broadcast_label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): broadcast_label.visible = false)

func set_forge_result(text: String, col: Color) -> void:
	forge_result_label.text = text
	forge_result_label.add_theme_color_override("font_color", col)

func refresh_stats() -> void:
	if player == null:
		return
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_text.text = "HP %d / %d  (ATK %d · DEF %d%%)" % [player.hp, player.max_hp, player.get_attack_power(), int(player.get_defense_reduction() * 100)]

	var s_info := GearTiers.get_tier_info(player.sword_level)
	var a_info := GearTiers.get_tier_info(player.armor_level)
	gear_label.text = "Sword +%d (%s)\nArmor +%d (%s)" % [player.sword_level, s_info["name"], player.armor_level, a_info["name"]]
	banked_label.text = "Banked: %dg · %d Ore · %d Shards" % [player.banked_gold, player.banked_ore, player.banked_shards]

	run_loot_panel.visible = player.has_unbanked_loot()
	if run_loot_panel.visible:
		run_loot_label.text = "Run Loot (At Risk!): %dg · %d Ore · %d Shards" % [player.run_gold, player.run_ore, player.run_shards]

	var sw_r := GearTiers.get_upgrade_recipe(player.sword_level)
	if sw_r["can_upgrade"]:
		forge_sword_info.text = "Sword +%d → +%d (%d%% chance)\nCost: %dg, %d Ore%s" % [
			player.sword_level, player.sword_level + 1, int(sw_r["chance"] * 100),
			sw_r["gold"], sw_r["ore"],
			(", %d Shards" % sw_r["shards"]) if int(sw_r["shards"]) > 0 else ""
		]
	else:
		forge_sword_info.text = "Sword +15 (MAX MASTERWORK!)"

	var ar_r := GearTiers.get_upgrade_recipe(player.armor_level)
	if ar_r["can_upgrade"]:
		forge_armor_info.text = "Armor +%d → +%d (%d%% chance)\nCost: %dg, %d Ore%s" % [
			player.armor_level, player.armor_level + 1, int(ar_r["chance"] * 100),
			ar_r["gold"], ar_r["ore"],
			(", %d Shards" % ar_r["shards"]) if int(ar_r["shards"]) > 0 else ""
		]
	else:
		forge_armor_info.text = "Armor +15 (MAX MASTERWORK!)"

func _process(_delta: float) -> void:
	if player == null:
		return
	interact_hint.visible = player.is_near_forge() and not forge_panel.visible
	var cds := player.get_cooldowns()
	skill_q_lbl.text = "Whirlwind" if cds["q"] <= 0.05 else "%.1fs" % cds["q"]
	skill_e_lbl.text = "Sword Lunge" if cds["e"] <= 0.05 else "%.1fs" % cds["e"]
	skill_dash_lbl.text = "Evade" if cds["dash"] <= 0.05 else "%.1fs" % cds["dash"]

func _make_card(bg: Color, border: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)
	return pc

func _make_label(text: String, size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 13)
	return b

func _add_skill_chip(parent: HBoxContainer, key_txt: String, name_txt: String) -> Label:
	var card := _make_card(Color(0.09, 0.11, 0.16, 0.84), Color(0.75, 0.68, 0.48, 0.7))
	parent.add_child(card)
	var v := VBoxContainer.new()
	card.add_child(v)
	v.add_child(_make_label(key_txt, 12, Color(1.0, 0.86, 0.45), HORIZONTAL_ALIGNMENT_CENTER))
	var val := _make_label(name_txt, 13, Color(0.95, 0.97, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(val)
	return val
