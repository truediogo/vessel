@tool
class_name IsometricCameraRig
extends Node3D

## Fixed-pitch (~55 deg) narrow-FOV (~35 deg) isometric Camera3D rig with pan & zoom.

@export var pitch_degrees: float = 55.0:
	set(value):
		pitch_degrees = clampf(value, 25.0, 85.0)
		_apply_camera_transform()

@export var fov_degrees: float = 35.0:
	set(value):
		fov_degrees = clampf(value, 20.0, 60.0)
		_apply_camera_transform()

@export var zoom_distance: float = 420.0:
	set(value):
		zoom_distance = clampf(value, min_zoom, max_zoom)
		_apply_camera_transform()

@export var min_zoom: float = 14.0
@export var max_zoom: float = 780.0
@export var zoom_step: float = 28.0
@export var pan_bounds_half_extent: float = 512.0
@export var follow_player: bool = true
@export var follow_smooth_speed: float = 10.0
@export var toggle_follow_key: Key = KEY_C

@onready var _camera: Camera3D = $Camera3D
var follow_target: Node3D = null
var _is_panning: bool = false


func _ready() -> void:
	_apply_camera_transform()


func set_follow_target(target: Node3D, snap_now: bool = true) -> void:
	follow_target = target
	if snap_now and follow_target != null:
		global_position = Vector3(follow_target.global_position.x, follow_target.global_position.y, follow_target.global_position.z)


func toggle_follow_mode() -> void:
	follow_player = not follow_player


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if follow_player and follow_target != null and is_instance_valid(follow_target):
		var target_pos := Vector3(follow_target.global_position.x, follow_target.global_position.y, follow_target.global_position.z)
		global_position = global_position.lerp(target_pos, clampf(delta * follow_smooth_speed, 0.0, 1.0))
		return

	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0

	if move.length_squared() > 0.001:
		var speed: float = maxf(24.0, zoom_distance * 0.72)
		var delta_xz := move.normalized() * speed * delta
		_pan_by(delta_xz)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and (ke.keycode == toggle_follow_key or ke.keycode == KEY_TAB or ke.keycode == KEY_SPACE):
			toggle_follow_mode()
			return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_distance -= zoom_step * maxf(0.25, zoom_distance / 280.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_distance += zoom_step * maxf(0.25, zoom_distance / 280.0)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
	elif event is InputEventMouseMotion and _is_panning and not follow_player:
		var mm := event as InputEventMouseMotion
		var drag_scale: float = zoom_distance * 0.0014
		_pan_by(Vector2(-mm.relative.x * drag_scale, -mm.relative.y * drag_scale))


func _pan_by(delta_xz: Vector2) -> void:
	global_position.x = clampf(global_position.x + delta_xz.x, -pan_bounds_half_extent, pan_bounds_half_extent)
	global_position.z = clampf(global_position.z + delta_xz.y, -pan_bounds_half_extent, pan_bounds_half_extent)


func _apply_camera_transform() -> void:
	if _camera == null:
		_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		return
	var rad: float = deg_to_rad(pitch_degrees)
	_camera.position = Vector3(0.0, sin(rad) * zoom_distance, cos(rad) * zoom_distance)
	_camera.rotation_degrees = Vector3(-pitch_degrees, 0.0, 0.0)
	_camera.fov = fov_degrees
	_camera.far = maxf(1200.0, zoom_distance * 2.6)
