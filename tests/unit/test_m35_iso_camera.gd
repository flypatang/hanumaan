extends GdUnitTestSuite
## M35 acceptance tests (DESIGN §9, §4.1): the isometric camera rig rotates in 90-degree steps, refuses rotation
## while locked, maps "up" input to the camera's screen-up direction on XZ, and fades occluders between the camera
## and the target.

const ROTATE_WAIT: float = 0.4
const FADED: float = 0.75


## Builds Root > [Hanuman (Node3D at origin), Rig (IsoCamera, target = ../Hanuman)] and returns the rig.
func _build_scene() -> IsoCamera:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var hanuman: Node3D = Node3D.new()
	hanuman.name = "Hanuman"
	root.add_child(hanuman)
	var iso: IsoCamera = IsoCamera.new()
	iso.name = "Rig"
	iso.target = NodePath("../Hanuman")
	root.add_child(iso)
	return iso


## Asserts that a 2D "up" input (0, 1) maps onto the camera's screen-up direction projected on XZ.
func _assert_up_is_screen_up(iso: IsoCamera) -> void:
	var cam: Camera3D = iso.get_camera()
	assert_object(cam).is_not_null()
	var screen_up: Vector3 = cam.global_transform.basis.y
	var expected: Vector3 = Vector3(screen_up.x, 0.0, screen_up.z).normalized()
	var mapped: Vector3 = iso.world_to_input_basis() * Vector3(0.0, 1.0, 0.0)
	var mapped_flat: Vector3 = Vector3(mapped.x, 0.0, mapped.z).normalized()
	assert_float(mapped_flat.dot(expected)).is_equal_approx(1.0, 0.001)


func test_camera_is_orthographic_with_exported_size() -> void:
	var iso: IsoCamera = _build_scene()
	var cam: Camera3D = iso.get_camera()
	assert_object(cam).is_not_null()
	assert_int(cam.projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)
	assert_float(cam.size).is_equal_approx(14.0, 0.001)
	assert_float(iso.size).is_equal_approx(14.0, 0.001)


func test_up_input_maps_to_screen_up_after_each_rotation() -> void:
	var iso: IsoCamera = _build_scene()
	_assert_up_is_screen_up(iso)
	for i: int in range(4):
		assert_bool(iso.rotate_right()).is_true()
		iso.finish_rotation()
		_assert_up_is_screen_up(iso)


func test_rotation_is_an_eased_tween_over_point_three_seconds() -> void:
	var iso: IsoCamera = _build_scene()
	var start_yaw: float = iso.yaw()
	assert_bool(iso.rotate_right()).is_true()
	assert_bool(iso.is_rotating()).is_true()
	await get_tree().create_timer(ROTATE_WAIT).timeout
	assert_bool(iso.is_rotating()).is_false()
	assert_float(iso.yaw() - start_yaw).is_equal_approx(PI / 2.0, 0.001)
	_assert_up_is_screen_up(iso)


func test_each_rotation_turns_exactly_ninety_degrees() -> void:
	var iso: IsoCamera = _build_scene()
	var previous: float = iso.yaw()
	for i: int in range(4):
		iso.rotate_left()
		iso.finish_rotation()
		assert_float(absf(iso.yaw() - previous)).is_equal_approx(PI / 2.0, 0.001)
		previous = iso.yaw()


func test_locked_rig_refuses_rotation() -> void:
	var iso: IsoCamera = _build_scene()
	var start_yaw: float = iso.yaw()
	iso.locked = true
	assert_bool(iso.rotate_right()).is_false()
	assert_bool(iso.rotate_left()).is_false()
	assert_bool(iso.is_rotating()).is_false()
	iso.finish_rotation()
	assert_float(iso.yaw()).is_equal_approx(start_yaw, 0.001)
	iso.locked = false
	assert_bool(iso.rotate_right()).is_true()


func test_occluder_between_camera_and_target_fades_and_restores() -> void:
	var iso: IsoCamera = _build_scene()
	var root: Node = iso.get_parent()
	var blocker: MeshInstance3D = MeshInstance3D.new()
	blocker.mesh = BoxMesh.new()
	blocker.add_to_group(&"occluder")
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(6.0, 6.0, 6.0)
	shape.shape = box
	body.add_child(shape)
	blocker.add_child(body)
	root.add_child(blocker)
	var cam_pos: Vector3 = iso.get_camera().global_position
	blocker.global_position = cam_pos * 0.5
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(blocker.transparency).is_equal_approx(FADED, 0.001)
	blocker.global_position = Vector3(100.0, 0.0, 100.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(blocker.transparency).is_equal_approx(0.0, 0.001)


func test_rig_follows_target() -> void:
	var iso: IsoCamera = _build_scene()
	var hanuman: Node3D = iso.get_parent().get_node("Hanuman") as Node3D
	hanuman.global_position = Vector3(10.0, 0.0, -5.0)
	for i: int in range(120):
		await get_tree().process_frame
	assert_float(iso.global_position.distance_to(hanuman.global_position)).is_less(0.01)
