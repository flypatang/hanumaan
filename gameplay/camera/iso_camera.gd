class_name IsoCamera
extends Node3D
## Orthographic isometric camera rig (DESIGN §4.1, §9 M35).
## Yaw starts at 45 degrees and turns in 90-degree steps with a 0.3 s eased tween (rotate_camera_left/right).
## Walls and roofs between the camera and the target fade to 75% transparency (25% opacity) and restore when clear.
## CAM1: the mouse (and the right stick) orbit the view freely (yaw only, the isometric pitch is fixed), the wheel zooms
## (a multiplier on `size`, clamped), Z / C still snap by 90 degrees. The mouse is captured while playing and released
## while the tree is paused or the runtime holds input (dialogue, menu, card), then captured again.
## Frame-rate independent: follow smoothing and the turn duration use delta, and occlusion runs in physics.

const ROTATE_TIME: float = 0.3
const STEP_ANGLE: float = PI / 2.0
const BASE_YAW: float = PI / 4.0
## True isometric pitch: atan(1 / sqrt(2)) below the horizon, in degrees.
const ISO_ELEVATION_DEG: float = 35.264
const CAMERA_DISTANCE: float = 40.0
const OCCLUDED_TRANSPARENCY: float = 0.75
const MAX_OCCLUDERS_PER_RAY: int = 8
const OCCLUDER_GROUP: StringName = &"occluder"
## Radians of yaw per pixel of mouse motion (90 degrees is about 315 px).
const MOUSE_SENSITIVITY: float = 0.005
## Radians per second at full right-stick deflection.
const STICK_SPEED: float = 2.4
## How fast the view catches up with the orbit goal (exponential, per second).
const ORBIT_SMOOTHING: float = 20.0
const ZOOM_MIN: float = 0.6
const ZOOM_MAX: float = 1.6
## Each wheel notch multiplies the zoom by this (in) or its inverse (out).
const ZOOM_STEP: float = 0.9
const ZOOM_SMOOTHING: float = 12.0

## Node3D path to the node the camera follows (resolved relative to this rig).
@export var target: NodePath
## Orthographic camera size (world units visible vertically).
@export var size: float = 14.0
## Follow smoothing; the rig closes this fraction of the gap per second (exponential, frame-rate independent).
@export var follow_lerp: float = 8.0

## When true, rotation requests are refused (cutscenes and the on-rails leap).
var locked: bool = false
## When false the mouse is never captured and mouse motion does not orbit (Settings or a test can switch it off).
var mouse_look_enabled: bool = true
## Radians of yaw added by free orbit since the rig was built (mouse, stick); the tutorial reads it.
var orbit_total: float = 0.0

var _camera: Camera3D = null
var _target_node: Node3D = null
var _yaw_goal: float = BASE_YAW
var _zoom: float = 1.0
var _zoom_goal: float = 1.0
var _mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _rotation_tween: Tween = null
## Instance ids of the occluders currently faded, so freed nodes are skipped safely.
var _faded_ids: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # so the mouse is released while the tree is paused
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = size
	var elevation: float = deg_to_rad(ISO_ELEVATION_DEG)
	_camera.position = Vector3(0.0, CAMERA_DISTANCE * sin(elevation), CAMERA_DISTANCE * cos(elevation))
	_camera.rotation.x = -elevation
	add_child(_camera)
	_camera.current = true
	rotation.y = BASE_YAW
	_yaw_goal = BASE_YAW
	_target_node = get_node_or_null(target) as Node3D
	if _target_node != null:
		global_position = _target_node.global_position


func _process(delta: float) -> void:
	_zoom = lerpf(_zoom, _zoom_goal, 1.0 - exp(-ZOOM_SMOOTHING * delta))
	if absf(_zoom - _zoom_goal) < 0.0005:
		_zoom = _zoom_goal
	if _camera != null:
		_camera.size = size * _zoom
	_update_mouse_mode()
	var blocked: bool = is_input_blocked()
	if not blocked:
		if InputMap.has_action(&"rotate_camera_right") and Input.is_action_just_pressed(&"rotate_camera_right"):
			rotate_right()
		elif InputMap.has_action(&"rotate_camera_left") and Input.is_action_just_pressed(&"rotate_camera_left"):
			rotate_left()
		elif InputMap.has_action(&"camera_orbit_left") and InputMap.has_action(&"camera_orbit_right"):
			var stick: float = Input.get_axis(&"camera_orbit_left", &"camera_orbit_right")
			if absf(stick) > 0.0:
				orbit(stick * STICK_SPEED * delta)
	if not is_rotating():
		rotation.y = lerpf(rotation.y, _yaw_goal, 1.0 - exp(-ORBIT_SMOOTHING * delta)) if absf(rotation.y - _yaw_goal) > 0.0001 else _yaw_goal
	if _target_node != null and is_instance_valid(_target_node):
		var weight: float = 1.0 - exp(-maxf(follow_lerp, 0.0) * delta)
		global_position = global_position.lerp(_target_node.global_position, weight)


func _input(event: InputEvent) -> void:
	if is_input_blocked():
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if mouse_look_enabled:
			orbit(motion.relative.x * MOUSE_SENSITIVITY)
		return
	if event.is_action_pressed(&"camera_zoom_in"):
		zoom_by(ZOOM_STEP)
	elif event.is_action_pressed(&"camera_zoom_out"):
		zoom_by(1.0 / ZOOM_STEP)


func _exit_tree() -> void:
	_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(_delta: float) -> void:
	_update_occlusion()


## The camera node owned by this rig.
func get_camera() -> Camera3D:
	return _camera


## Turns the view 90 degrees to the left (counter-clockwise seen from above). Returns false if refused.
func rotate_left() -> bool:
	return _rotate(-1)


## Turns the view 90 degrees to the right (clockwise seen from above). Returns false if refused.
func rotate_right() -> bool:
	return _rotate(1)


## True while a 90-degree turn is animating.
func is_rotating() -> bool:
	return _rotation_tween != null and _rotation_tween.is_running()


## Completes any running turn immediately, leaving the yaw at its goal.
func finish_rotation() -> void:
	if _rotation_tween != null:
		_rotation_tween.kill()
	_rotation_tween = null
	rotation.y = _yaw_goal


## Free orbit: adds `radians` to the yaw goal (positive turns like rotate_right). The view follows smoothly.
## Refused while locked or while a menu or dialogue holds input. Returns true when applied.
func orbit(radians: float) -> bool:
	if is_input_blocked():
		return false
	if is_rotating():
		finish_rotation()
	_yaw_goal += radians
	orbit_total += absf(radians)
	return true


## The yaw the view is heading for (rotation.y once smoothing and turns are done).
func yaw_goal() -> float:
	return _yaw_goal


## Multiplies the zoom goal (below 1.0 zooms in), clamped to ZOOM_MIN..ZOOM_MAX of the level size.
func zoom_by(factor: float) -> void:
	if is_input_blocked():
		return
	_zoom_goal = clampf(_zoom_goal * factor, ZOOM_MIN, ZOOM_MAX)


## The zoom the wheel is heading for.
func zoom_target() -> float:
	return _zoom_goal


## The zoom multiplier applied on top of `size` right now.
func zoom_multiplier() -> float:
	return _zoom


## Jumps the zoom to its goal.
func finish_zoom() -> void:
	_zoom = _zoom_goal
	if _camera != null:
		_camera.size = size * _zoom


## True while orbit and zoom input must be ignored: a cutscene lock, a paused tree, or a dialogue / menu / card that
## holds the runtime's input.
func is_input_blocked() -> bool:
	if locked:
		return true
	if is_inside_tree() and get_tree().paused:
		return true
	var parent: Node = get_parent()
	if parent != null and parent.has_method(&"input_locked") and parent.call(&"input_locked") as bool:
		return true
	return false


## The mouse mode the camera wants right now: captured while playing, visible while anything holds input.
func wanted_mouse_mode() -> Input.MouseMode:
	if mouse_look_enabled and not is_input_blocked():
		return Input.MOUSE_MODE_CAPTURED
	return Input.MOUSE_MODE_VISIBLE


## The mouse mode this rig last applied.
func applied_mouse_mode() -> Input.MouseMode:
	return _mouse_mode


func _update_mouse_mode() -> void:
	_set_mouse_mode(wanted_mouse_mode())


func _set_mouse_mode(mode: Input.MouseMode) -> void:
	if mode == _mouse_mode:
		return
	_mouse_mode = mode
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = mode


## Maps 2D input (x right, y up on screen) to world XZ for the current yaw, as a Basis.
## Use as: world_direction = world_to_input_basis() * Vector3(input.x, input.y, 0.0).
func world_to_input_basis() -> Basis:
	var yaw_basis: Basis = Basis(Vector3.UP, rotation.y)
	var screen_right: Vector3 = yaw_basis * Vector3.RIGHT
	var screen_up: Vector3 = yaw_basis * Vector3.FORWARD
	return Basis(screen_right, screen_up, Vector3.UP)


func _rotate(direction: int) -> bool:
	if locked:
		return false
	finish_rotation()
	var grid: float = (_yaw_goal - BASE_YAW) / STEP_ANGLE
	var next: float = floorf(grid + 0.001) + 1.0 if direction > 0 else ceilf(grid - 0.001) - 1.0
	_yaw_goal = BASE_YAW + next * STEP_ANGLE
	_rotation_tween = create_tween()
	_rotation_tween.tween_property(self, "rotation:y", _yaw_goal, ROTATE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return true


## Raycasts from the camera to the target each physics frame and fades the occluders that block the view.
func _update_occlusion() -> void:
	if _camera == null or _target_node == null or not is_inside_tree():
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var blockers: Array[GeometryInstance3D] = _find_occluders(space, _camera.global_position, _target_node.global_position)
	var blocker_ids: Array[int] = []
	for blocker: GeometryInstance3D in blockers:
		blocker_ids.append(blocker.get_instance_id())
	for old_id: int in _faded_ids:
		if not blocker_ids.has(old_id):
			var old_node: GeometryInstance3D = instance_from_id(old_id) as GeometryInstance3D
			if old_node != null:
				old_node.transparency = 0.0
	for blocker: GeometryInstance3D in blockers:
		blocker.transparency = OCCLUDED_TRANSPARENCY
	_faded_ids = blocker_ids


func _find_occluders(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	var exclude: Array[RID] = []
	var target_body: CollisionObject3D = _target_node as CollisionObject3D
	if target_body != null:
		exclude.append(target_body.get_rid())
	for i: int in range(MAX_OCCLUDERS_PER_RAY):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = exclude
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			break
		var rid: RID = hit["rid"] as RID
		exclude.append(rid)
		var occluder: GeometryInstance3D = _occluder_for(hit["collider"] as Object)
		if occluder != null and not found.has(occluder):
			found.append(occluder)
	return found


## The nearest occluder-group GeometryInstance3D at or above the collider, or null.
func _occluder_for(collider: Object) -> GeometryInstance3D:
	var node: Node = collider as Node
	while node != null and node != self:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		if geometry != null and geometry.is_in_group(OCCLUDER_GROUP):
			return geometry
		node = node.get_parent()
	return null
