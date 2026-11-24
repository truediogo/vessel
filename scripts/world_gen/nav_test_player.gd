class_name NavTestPlayer
extends CharacterBody3D

## LoL-style right-click-to-move test character (~1.8m capsule) using NavigationAgent3D.

const SHADER_PAINTERLY_PATH := "res://shaders/arcane_town_painterly.gdshader"

@export var move_speed: float = 8.5
@export var rotation_speed: float = 14.0
@export var gravity_accel: float = 28.0

var nav_agent: NavigationAgent3D
var visual_root: Node3D
var target_marker: MeshInstance3D

var _is_moving: bool = false
var _target_world_pos: Vector3 = Vector3.ZERO
var _active_path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _rmb_held: bool = false
var _has_pending_click: bool = false
var _pending_click_screen_pos: Vector2 = Vector2.ZERO
var _last_drag_screen_pos: Vector2 = Vector2.ZERO
var _bob_phase: float = 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.75
	_ensure_components()


func _ensure_components() -> void:
	if get_node_or_null("PlayerCollider") == null:
		var cs := CollisionShape3D.new()
		cs.name = "PlayerCollider"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.40
		cap.height = 1.80
		cs.shape = cap
		cs.position = Vector3(0.0, 0.90, 0.0)
		add_child(cs)

	nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav_agent == null:
		nav_agent = NavigationAgent3D.new()
		nav_agent.name = "NavigationAgent3D"
		nav_agent.path_desired_distance = 0.70
		nav_agent.target_desired_distance = 0.65
		nav_agent.path_max_distance = 6.0
		nav_agent.radius = 0.45
		nav_agent.height = 1.80
		nav_agent.path_search_max_polygons = 65536
		add_child(nav_agent)

	visual_root = get_node_or_null("PlayerVisual") as Node3D
	if visual_root == null:
		visual_root = _build_visual_rig()
		add_child(visual_root)

	target_marker = get_node_or_null("TargetMarker") as MeshInstance3D
	if target_marker == null:
		target_marker = _build_target_marker()
		add_child(target_marker)


func _build_visual_rig() -> Node3D:
	var root := Node3D.new()
	root.name = "PlayerVisual"

	var mat_tunic := _make_matte_mat(Color(0.20, 0.44, 0.82))
	var mat_gold := _make_matte_mat(Color(0.92, 0.76, 0.34))
	var mat_head := _make_matte_mat(Color(0.95, 0.86, 0.78))
	var mat_cloak := _make_matte_mat(Color(0.14, 0.22, 0.38))

	var body := MeshInstance3D.new()
	body.name = "BodyCapsule"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.34
	body_mesh.height = 1.22
	body.mesh = body_mesh
	body.material_override = mat_tunic
	body.position = Vector3(0.0, 0.72, 0.0)
	root.add_child(body)

	var mantle := MeshInstance3D.new()
	mantle.name = "ShoulderMantle"
	var mantle_mesh := CylinderMesh.new()
	mantle_mesh.top_radius = 0.38
	mantle_mesh.bottom_radius = 0.45
	mantle_mesh.height = 0.24
	mantle_mesh.radial_segments = 12
	mantle.mesh = mantle_mesh
	mantle.material_override = mat_cloak
	mantle.position = Vector3(0.0, 1.18, 0.0)
	root.add_child(mantle)

	var head := MeshInstance3D.new()
	head.name = "HeadSphere"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.48
	head.mesh = head_mesh
	head.material_override = mat_head
	head.position = Vector3(0.0, 1.54, 0.0)
	root.add_child(head)

	var crest := MeshInstance3D.new()
	crest.name = "FacingCrest"
	var crest_mesh := BoxMesh.new()
	crest_mesh.size = Vector3(0.16, 0.22, 0.34)
	crest.mesh = crest_mesh
	crest.material_override = mat_gold
	crest.position = Vector3(0.0, 1.04, 0.34)
	root.add_child(crest)

	var ring := MeshInstance3D.new()
	ring.name = "ChampionRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.56
	ring_mesh.outer_radius = 0.68
	ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.24, 0.92, 0.96, 1.0)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	ring.position = Vector3(0.0, 0.08, 0.0)
	ring.scale = Vector3(1.0, 0.35, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)

	return root


func _build_target_marker() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = "TargetMarker"
	marker.top_level = true
	marker.visible = false
	var tor := TorusMesh.new()
	tor.inner_radius = 0.42
	tor.outer_radius = 0.62
	marker.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.98, 0.84, 0.26, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = mat
	marker.scale = Vector3(1.0, 0.35, 1.0)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return marker


func _make_matte_mat(col: Color) -> Material:
	var shader := load(SHADER_PAINTERLY_PATH) as Shader
	if shader != null:
		var smat := ShaderMaterial.new()
		smat.shader = shader
		smat.set_shader_parameter("use_texture", false)
		smat.set_shader_parameter("albedo_color", col)
		smat.set_shader_parameter("emission_strength", 0.0)
		return smat
	var std := StandardMaterial3D.new()
	std.albedo_color = col
	std.roughness = 0.94
	std.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return std


func move_to_world_position(target_pos: Vector3) -> void:
	_ensure_components()
	var resolved := target_pos
	var queried_path := PackedVector3Array()
	var world := get_world_3d()
	if world != null:
		var map_rid: RID = world.navigation_map
		if map_rid.is_valid() and NavigationServer3D.map_get_iteration_id(map_rid) > 0 and not NavigationServer3D.map_get_regions(map_rid).is_empty():
			if NavigationServer3D.map_get_closest_point_owner(map_rid, target_pos).is_valid():
				resolved = NavigationServer3D.map_get_closest_point(map_rid, target_pos)
			var qp := NavigationPathQueryParameters3D.new()
			qp.map = map_rid
			qp.start_position = global_position
			qp.target_position = resolved
			qp.path_postprocessing = NavigationPathQueryParameters3D.PATH_POSTPROCESSING_CORRIDORFUNNEL
			qp.path_search_max_polygons = 65536
			var qr := NavigationPathQueryResult3D.new()
			NavigationServer3D.query_path(qp, qr)
			queried_path = qr.path
	_target_world_pos = resolved
	nav_agent.target_position = resolved
	_active_path = queried_path
	_path_index = 0
	while _path_index < _active_path.size():
		var wp := _active_path[_path_index]
		if Vector2(wp.x - global_position.x, wp.z - global_position.z).length() <= 0.45:
			_path_index += 1
		else:
			break
	_is_moving = true
	if target_marker != null:
		target_marker.global_position = resolved + Vector3(0.0, 0.08, 0.0)
		target_marker.visible = true


func stop_movement() -> void:
	_is_moving = false
	_active_path = PackedVector3Array()
	_path_index = 0
	velocity.x = 0.0
	velocity.z = 0.0
	if target_marker != null:
		target_marker.visible = false


func is_moving() -> bool:
	return _is_moving


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var vp := get_viewport()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_held = mb.pressed
			if mb.pressed:
				_pending_click_screen_pos = mb.position
				_last_drag_screen_pos = mb.position
				_has_pending_click = true
				if vp != null:
					vp.set_input_as_handled()
	elif event is InputEventMouseMotion and _rmb_held:
		var mm := event as InputEventMouseMotion
		if mm.position.distance_to(_last_drag_screen_pos) > 6.0:
			_pending_click_screen_pos = mm.position
			_last_drag_screen_pos = mm.position
			_has_pending_click = true


func _raycast_and_move(screen_pos: Vector2) -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	var world := get_world_3d()
	if cam == null or world == null:
		return
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 2000.0, 1)
	q.exclude = [get_rid()]
	var hit := world.direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		move_to_world_position(hit["position"])
		return
	var plane := Plane(Vector3.UP, global_position.y)
	var hit_pt: Variant = plane.intersects_ray(origin, dir)
	if hit_pt is Vector3:
		move_to_world_position(hit_pt as Vector3)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if nav_agent == null:
		return

	if _has_pending_click:
		_has_pending_click = false
		_raycast_and_move(_pending_click_screen_pos)

	if not is_on_floor():
		velocity.y -= gravity_accel * delta
	else:
		velocity.y = minf(0.0, velocity.y)

	if _is_moving:
		while _path_index < _active_path.size():
			var wp := _active_path[_path_index]
			if Vector2(wp.x - global_position.x, wp.z - global_position.z).length() <= 0.55:
				_path_index += 1
			else:
				break

		var flat_dist_to_goal := Vector2(global_position.x - _target_world_pos.x, global_position.z - _target_world_pos.z).length()
		if flat_dist_to_goal <= nav_agent.target_desired_distance or (_active_path.size() > 0 and _path_index >= _active_path.size() and flat_dist_to_goal <= 0.85):
			stop_movement()
		else:
			var next_pt := _target_world_pos
			if _path_index < _active_path.size():
				next_pt = _active_path[_path_index]
			elif not nav_agent.is_navigation_finished():
				next_pt = nav_agent.get_next_path_position()
			var to_next := Vector3(next_pt.x - global_position.x, 0.0, next_pt.z - global_position.z)
			if to_next.length() > 0.04:
				var move_dir := to_next.normalized()
				velocity.x = move_dir.x * move_speed
				velocity.z = move_dir.z * move_speed
				if visual_root != null:
					var target_yaw := atan2(move_dir.x, move_dir.z)
					visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, clampf(delta * rotation_speed, 0.0, 1.0))
					_bob_phase += delta * 11.0
					visual_root.position.y = absf(sin(_bob_phase)) * 0.06
			else:
				velocity.x = 0.0
				velocity.z = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 42.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 42.0)
		if visual_root != null:
			visual_root.position.y = move_toward(visual_root.position.y, 0.0, delta * 2.0)

	move_and_slide()
