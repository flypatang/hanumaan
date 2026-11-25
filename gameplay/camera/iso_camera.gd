class_name IsoCamera
extends Node3D
## Orthographic isometric camera rig (DESIGN §4.1, §9 M35).
## Yaw starts at 45 degrees and turns in 90-degree steps with a 0.3 s eased tween (rotate_camera_left/right).
## Walls and roofs between the camera and the target fade to 75% transparency (25% opacity) and restore when clear.
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

## Node3D path to the node the camera follows (resolved relative to this rig).
@export var target: NodePath
## Orthographic camera size (world units visible vertically).
@export var size: float = 14.0
## Follow smoothing; the rig closes this fraction of the gap per second (exponential, frame-rate independent).
@export var follow_lerp: float = 8.0

## When true, rotation requests are refused (cutscenes and the on-rails leap).
var locked: bool = false

var _camera: Camera3D = null
var _target_node: Node3D = null
var _quarter_turns: int = 0
var _rotation_tween: Tween = null
## Instance ids of the occluders currently faded, so freed nodes are skipped safely.
var _faded_ids: Array[int] = []


func _ready() -> void:
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
	_target_node = get_node_or_null(target) as Node3D
	if _target_node != null:
		global_position = _target_node.global_position


func _process(delta: float) -> void:
	if _camera != null:
		_camera.size = size
	if not locked and InputMap.has_action(&"rotate_camera_right") and Input.is_action_just_pressed(&"rotate_camera_right"):
		rotate_right()
	elif not locked and InputMap.has_action(&"rotate_camera_left") and Input.is_action_just_pressed(&"rotate_camera_left"):
		rotate_left()
	if _target_node != null and is_instance_valid(_target_node):
		var weight: float = 1.0 - exp(-maxf(follow_lerp, 0.0) * delta)
		global_position = global_position.lerp(_target_node.global_position, weight)


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


## Completes any running turn immediately, leaving the yaw at its final step.
func finish_rotation() -> void:
	if _rotation_tween != null:
		_rotation_tween.kill()
	_rotation_tween = null
	rotation.y = _target_yaw()


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
	_quarter_turns += direction
	_rotation_tween = create_tween()
	_rotation_tween.tween_property(self, "rotation:y", _target_yaw(), ROTATE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return true


func _target_yaw() -> float:
	return BASE_YAW + float(_quarter_turns) * STEP_ANGLE


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
