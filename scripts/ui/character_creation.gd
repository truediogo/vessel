class_name CharacterCreation
extends Control

# Full-screen League of Legends-style Heroic Stylized character creation screen
# featuring the custom Blender-built Novice Adventurer Set (Tunic, Breeches,
# Shoulder Mantle, Forearm Bracers, Buckled Belt, and Cuffed Boots).

signal creation_finished(appearance: Dictionary)

# --- Appearance state ---
var _body_type := "male"  # "male" or "female"
var _skin_color_idx := 2
var _hair_style_idx := 0
var _hair_color_idx := 1

# --- Skin palette (diverse range from porcelain to rich ebony, tuned for cel-shading) ---
const SKIN_COLORS: Array[Color] = [
	Color(0.99, 0.91, 0.83),  # Porcelain
	Color(0.96, 0.84, 0.72),  # Fair
	Color(0.90, 0.75, 0.60),  # Warm Beige
	Color(0.81, 0.64, 0.48),  # Olive-Tan
	Color(0.72, 0.54, 0.39),  # Golden Bronze
	Color(0.62, 0.44, 0.31),  # Warm Brown
	Color(0.51, 0.35, 0.25),  # Deep Brown
	Color(0.41, 0.28, 0.20),  # Rich Ebony
]

# --- Hair palette ---
const HAIR_COLORS: Array[Color] = [
	Color(0.09, 0.07, 0.06),  # Raven Black
	Color(0.28, 0.16, 0.08),  # Dark Brown
	Color(0.52, 0.32, 0.16),  # Chestnut
	Color(0.72, 0.52, 0.28),  # Honey Brown
	Color(0.90, 0.74, 0.40),  # Golden Blonde
	Color(0.96, 0.88, 0.64),  # Platinum
	Color(0.72, 0.22, 0.14),  # Crimson Auburn
	Color(0.86, 0.38, 0.14),  # Copper Ginger
	Color(0.74, 0.78, 0.84),  # Silver Steel
	Color(0.24, 0.58, 0.82),  # Arcane Blue
]

# --- 3D Preview nodes ---
var _preview_viewport: SubViewport
var _preview_container: SubViewportContainer
var _preview_root: Node3D
var _preview_camera: Camera3D
var _preview_light: DirectionalLight3D
var _preview_env: WorldEnvironment
var _preview_model: Node3D
var _preview_anim: AnimationPlayer
var _preview_skeleton: Skeleton3D
var _hair_node: Node3D
var _head_attach: BoneAttachment3D
var _skin_mats: Array[ShaderMaterial] = []
var _hair_mats: Array[ShaderMaterial] = []
var _brow_mats: Array[ShaderMaterial] = []

# --- UI Widgets ---
var _body_btn: Button
var _skin_swatches: Array[ColorRect] = []
var _hair_name_label: Label
var _hair_prev_btn: Button
var _hair_next_btn: Button
var _hair_color_swatches: Array[ColorRect] = []
var _start_btn: Button
var _rotate_angle := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_build_3d_preview()
	_refresh_preview()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.10, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var left_panel := PanelContainer.new()
	left_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left_panel.offset_right = 380
	var lp_style := StyleBoxFlat.new()
	lp_style.bg_color = Color(0.08, 0.09, 0.14, 0.94)
	lp_style.border_color = Color(0.86, 0.74, 0.42, 0.65)
	lp_style.border_width_right = 2
	lp_style.set_content_margin_all(24)
	left_panel.add_theme_stylebox_override("panel", lp_style)
	add_child(left_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 16)
	scroll.add_child(col)

	col.add_child(_make_label("CREATE YOUR VESSEL", 22, Color(1.0, 0.92, 0.72)))

	col.add_child(_make_label("BODY TYPE", 14, Color(0.75, 0.82, 0.95)))
	_body_btn = Button.new()
	_body_btn.text = _body_type.capitalize()
	_body_btn.add_theme_font_size_override("font_size", 15)
	_body_btn.pressed.connect(_toggle_body)
	col.add_child(_body_btn)

	col.add_child(_make_label("SKIN COLOR", 14, Color(0.75, 0.82, 0.95)))
	var skin_row := _build_swatch_row(SKIN_COLORS, _on_skin_swatch_clicked, 8, Vector2(32, 32))
	_skin_swatches = skin_row["swatches"]
	col.add_child(skin_row["container"])
	_update_skin_selection()

	col.add_child(_make_label("HAIR STYLE", 14, Color(0.75, 0.82, 0.95)))
	var hair_nav := HBoxContainer.new()
	hair_nav.add_theme_constant_override("separation", 8)
	col.add_child(hair_nav)

	_hair_prev_btn = Button.new()
	_hair_prev_btn.text = "◀"
	_hair_prev_btn.add_theme_font_size_override("font_size", 18)
	_hair_prev_btn.pressed.connect(func(): _cycle_hair(-1))
	hair_nav.add_child(_hair_prev_btn)

	_hair_name_label = _make_label(CharacterLook.HAIR_STYLES[_hair_style_idx]["name"], 15, Color(0.95, 0.97, 1.0))
	_hair_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hair_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hair_nav.add_child(_hair_name_label)

	_hair_next_btn = Button.new()
	_hair_next_btn.text = "▶"
	_hair_next_btn.add_theme_font_size_override("font_size", 18)
	_hair_next_btn.pressed.connect(func(): _cycle_hair(1))
	hair_nav.add_child(_hair_next_btn)

	col.add_child(_make_label("HAIR COLOR", 14, Color(0.75, 0.82, 0.95)))
	var hair_color_row := _build_swatch_row(HAIR_COLORS, _on_hair_color_swatch_clicked, 5, Vector2(54, 32))
	_hair_color_swatches = hair_color_row["swatches"]
	col.add_child(hair_color_row["container"])
	_update_hair_color_selection()

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	col.add_child(spacer)

	_start_btn = Button.new()
	_start_btn.text = "ENTER THE WORLD"
	_start_btn.add_theme_font_size_override("font_size", 18)
	_start_btn.custom_minimum_size = Vector2(300, 56)
	var start_style := StyleBoxFlat.new()
	start_style.bg_color = Color(0.22, 0.52, 0.86)
	start_style.set_corner_radius_all(8)
	start_style.set_content_margin_all(12)
	_start_btn.add_theme_stylebox_override("normal", start_style)
	var start_hover := StyleBoxFlat.new()
	start_hover.bg_color = Color(0.30, 0.62, 0.96)
	start_hover.set_corner_radius_all(8)
	start_hover.set_content_margin_all(12)
	_start_btn.add_theme_stylebox_override("hover", start_hover)
	_start_btn.pressed.connect(_on_start_pressed)
	col.add_child(_start_btn)

	col.add_child(_make_label("Drag on the preview to rotate your character", 12, Color(0.55, 0.60, 0.70)))

	_preview_container = SubViewportContainer.new()
	_preview_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_container.offset_left = 380
	_preview_container.stretch = true
	_preview_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_preview_container)

func _build_swatch_row(colors: Array[Color], click_callback: Callable, columns: int = 8, swatch_size: Vector2 = Vector2(32, 32)) -> Dictionary:
	var container := GridContainer.new()
	container.columns = columns
	container.add_theme_constant_override("h_separation", 6)
	container.add_theme_constant_override("v_separation", 6)
	var swatches: Array[ColorRect] = []

	for i in range(colors.size()):
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = swatch_size
		swatch.color = colors[i]
		swatch.mouse_filter = Control.MOUSE_FILTER_STOP
		swatch.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					click_callback.call(i)
		)
		var marker := ReferenceRect.new()
		marker.name = "Marker"
		marker.editor_only = false
		marker.border_color = Color(1.0, 0.92, 0.72)
		marker.border_width = 3.0
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.visible = false
		swatch.add_child(marker)
		marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		container.add_child(swatch)
		swatches.append(swatch)

	return {"container": container, "swatches": swatches}

func _build_3d_preview() -> void:
	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(900, 720)
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_viewport.transparent_bg = true
	_preview_viewport.msaa_3d = Viewport.MSAA_2X
	_preview_container.add_child(_preview_viewport)

	_preview_root = Node3D.new()
	_preview_viewport.add_child(_preview_root)

	_preview_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.62, 0.78)
	env.ambient_light_energy = 0.54
	env.ssao_enabled = false
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_preview_env.environment = env
	_preview_root.add_child(_preview_env)

	_preview_light = DirectionalLight3D.new()
	_preview_light.rotation_degrees = Vector3(-30.0, 26.0, 0.0)
	_preview_light.light_color = Color(1.0, 0.97, 0.93)
	_preview_light.light_energy = 1.25
	_preview_light.shadow_enabled = false
	_preview_root.add_child(_preview_light)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, -148.0, 0.0)
	fill.light_color = Color(0.76, 0.82, 0.96)
	fill.light_energy = 0.56
	_preview_root.add_child(fill)

	_preview_camera = Camera3D.new()
	_preview_camera.fov = 32.0
	_preview_camera.position = Vector3(0.0, 1.05, 4.0)
	_preview_root.add_child(_preview_camera)
	_preview_camera.call_deferred("look_at", Vector3(0.0, 0.92, 0.0), Vector3.UP)

	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.45
	disc.bottom_radius = 1.55
	disc.height = 0.06
	ground.mesh = disc
	ground.position = Vector3(0, -0.03, 0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.13, 0.15, 0.21)
	gmat.roughness = 0.9
	ground.material_override = gmat
	_preview_root.add_child(ground)

func _refresh_preview() -> void:
	if _preview_model and is_instance_valid(_preview_model):
		_preview_model.queue_free()
		_preview_model = null
	_skin_mats.clear()
	_hair_mats.clear()
	_brow_mats.clear()
	_hair_node = null
	_head_attach = null
	_preview_anim = null
	_preview_skeleton = null

	var char_path := CharacterLook.BODY_MALE_PATH if _body_type == "male" else CharacterLook.BODY_FEMALE_PATH
	var scene := load(char_path) as PackedScene
	if scene == null:
		return
	_preview_model = scene.instantiate()
	_preview_model.scale = Vector3.ONE
	_preview_model.rotation.y = _rotate_angle
	_preview_root.add_child(_preview_model)

	_discover_skeleton(_preview_model)
	_load_preview_animations()
	_apply_body_materials(_preview_model)
	_attach_hair()
	_apply_hair_color()

	if _preview_anim:
		var idle_name := _resolve_preview_anim("Idle_Loop", "Idle")
		if not idle_name.is_empty():
			var a := _preview_anim.get_animation(idle_name)
			if a:
				a.loop_mode = Animation.LOOP_LINEAR
			_preview_anim.play(idle_name, 0.0, 1.0)

func _discover_skeleton(n: Node) -> void:
	if n is AnimationPlayer:
		_preview_anim = n as AnimationPlayer
	elif n is Skeleton3D:
		_preview_skeleton = n as Skeleton3D
	for c in n.get_children():
		_discover_skeleton(c)
	if n == _preview_model and _preview_anim == null and _preview_skeleton != null:
		_preview_anim = AnimationPlayer.new()
		_preview_anim.name = "AnimationPlayer"
		_preview_model.add_child(_preview_anim)
		_preview_anim.root_node = NodePath("..")

func _load_preview_animations() -> void:
	if _preview_anim == null or _preview_skeleton == null:
		return
	var anim_scene := load("res://addons/quaternius_anims/UAL1_Standard.glb") as PackedScene
	if anim_scene == null:
		return
	var anim_instance := anim_scene.instantiate()
	var anim_player := _find_anim_player(anim_instance)
	if anim_player == null:
		anim_instance.queue_free()
		return

	var anim_root_node: Node = _preview_anim.get_node(_preview_anim.root_node) if _preview_anim.root_node else _preview_anim.get_parent()
	var char_skel_path := str(anim_root_node.get_path_to(_preview_skeleton))

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
	_preview_anim.add_animation_library("ual", lib)
	anim_instance.queue_free()

func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r:
			return r
	return null

func _resolve_preview_anim(primary: String, fallback: String = "") -> String:
	if _preview_anim == null:
		return ""
	for cand in [primary, "ual/" + primary, fallback, "ual/" + fallback]:
		if not cand.is_empty() and _preview_anim.has_animation(cand):
			return cand
	return ""

func _apply_body_materials(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mi := node as MeshInstance3D
		for i in range(mi.mesh.get_surface_count()):
			var src := mi.get_active_material(i)
			if CharacterLook.is_skin_mesh(mi.name):
				var skin := CharacterLook.make_skin_material(src, SKIN_COLORS[_skin_color_idx])
				mi.set_surface_override_material(i, skin)
				_skin_mats.append(skin)
			elif CharacterLook.is_brow_mesh(mi.name):
				var brow := CharacterLook.make_brow_material(src, HAIR_COLORS[_hair_color_idx])
				mi.set_surface_override_material(i, brow)
				_brow_mats.append(brow)
			elif CharacterLook.is_tunic_mesh(mi.name) or CharacterLook.is_armor_mesh(mi.name):
				var cloth := CharacterLook.make_cloth_toon_material(src)
				mi.set_surface_override_material(i, cloth)
	for c in node.get_children():
		_apply_body_materials(c)

func _attach_hair() -> void:
	if _preview_skeleton == null:
		return
	var head_idx := _preview_skeleton.find_bone("Head")
	if head_idx < 0:
		head_idx = _preview_skeleton.find_bone("head")
	if head_idx < 0:
		return

	_head_attach = BoneAttachment3D.new()
	_head_attach.bone_name = "Head" if _preview_skeleton.find_bone("Head") >= 0 else "head"
	_preview_skeleton.add_child(_head_attach)
	_load_hair_model()

func _load_hair_model() -> void:
	if _head_attach == null:
		return
	if _hair_node and is_instance_valid(_hair_node):
		_hair_node.queue_free()
		_hair_node = null
	_hair_mats.clear()

	var style := CharacterLook.HAIR_STYLES[_hair_style_idx]
	var hair_path: String = style["path"]
	if hair_path.is_empty():
		return
	var hair_scene := load(hair_path) as PackedScene
	if hair_scene == null:
		return
	_hair_node = hair_scene.instantiate()
	_hair_node.transform = CharacterLook.hair_transform(_preview_skeleton, _preview_skeleton.find_bone(_head_attach.bone_name), hair_path)
	_head_attach.add_child(_hair_node)
	_apply_hair_shader(_hair_node)

func _apply_hair_shader(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mi := node as MeshInstance3D
		for i in range(mi.mesh.get_surface_count()):
			var mat := CharacterLook.make_hair_material(mi.get_active_material(i), HAIR_COLORS[_hair_color_idx])
			mi.set_surface_override_material(i, mat)
			_hair_mats.append(mat)
	for c in node.get_children():
		_apply_hair_shader(c)

func _apply_hair_color() -> void:
	var col := HAIR_COLORS[_hair_color_idx]
	for m in _hair_mats:
		if is_instance_valid(m):
			m.set_shader_parameter("albedo_color", col)
	var brow_col := CharacterLook.brow_color_for(col)
	for m in _brow_mats:
		if is_instance_valid(m):
			m.set_shader_parameter("albedo_color", brow_col)

func _apply_skin_color_live() -> void:
	var col := SKIN_COLORS[_skin_color_idx]
	for m in _skin_mats:
		if is_instance_valid(m):
			m.set_shader_parameter("albedo_color", col)

func _toggle_body() -> void:
	_body_type = "female" if _body_type == "male" else "male"
	_body_btn.text = _body_type.capitalize()
	_hair_style_idx = 2 if _body_type == "female" else 0
	_hair_name_label.text = CharacterLook.HAIR_STYLES[_hair_style_idx]["name"]
	_refresh_preview()

func _on_skin_swatch_clicked(idx: int) -> void:
	_skin_color_idx = idx
	_update_skin_selection()
	_apply_skin_color_live()

func _on_hair_color_swatch_clicked(idx: int) -> void:
	_hair_color_idx = idx
	_update_hair_color_selection()
	_apply_hair_color()

func _cycle_hair(direction: int) -> void:
	var count := CharacterLook.HAIR_STYLES.size()
	_hair_style_idx = (_hair_style_idx + direction + count) % count
	_hair_name_label.text = CharacterLook.HAIR_STYLES[_hair_style_idx]["name"]
	_load_hair_model()

func _update_skin_selection() -> void:
	_mark_swatch(_skin_swatches, _skin_color_idx)

func _update_hair_color_selection() -> void:
	_mark_swatch(_hair_color_swatches, _hair_color_idx)

func _mark_swatch(swatches: Array[ColorRect], selected: int) -> void:
	for i in range(swatches.size()):
		swatches[i].get_node("Marker").visible = i == selected

func _on_start_pressed() -> void:
	var style := CharacterLook.HAIR_STYLES[_hair_style_idx]
	var appearance := {
		"body_type": _body_type,
		"skin_color": SKIN_COLORS[_skin_color_idx],
		"skin_color_idx": _skin_color_idx,
		"hair_style_idx": _hair_style_idx,
		"hair_style_name": style["name"],
		"hair_style_path": style["path"],
		"hair_color": HAIR_COLORS[_hair_color_idx],
		"hair_color_idx": _hair_color_idx,
	}
	creation_finished.emit(appearance)

var _dragging := false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.position.x > 380:
				_dragging = mb.pressed
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_rotate_angle += mm.relative.x * 0.012
		if _preview_model and is_instance_valid(_preview_model):
			_preview_model.rotation.y = _rotate_angle

func _make_label(text: String, size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
