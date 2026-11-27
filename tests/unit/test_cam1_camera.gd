extends GdUnitTestSuite
## CAM1 acceptance tests: free orbit with the mouse and the right stick, wheel zoom, camera-relative movement after any
## yaw, mouse capture that is released while a menu or dialogue holds input, and the tutorial camera step.

class FakeRuntime:
	extends Node3D
	var held: bool = false

	func input_locked() -> bool:
		return held


## Root (FakeRuntime) > [Hanuman, Rig (IsoCamera)].
func _build() -> IsoCamera:
	(load("res://core/input_setup.gd") as GDScript).call("register_all")
	var root: FakeRuntime = auto_free(FakeRuntime.new()) as FakeRuntime
	add_child(root)
	var hanuman: Node3D = Node3D.new()
	hanuman.name = "Hanuman"
	root.add_child(hanuman)
	var iso: IsoCamera = IsoCamera.new()
	iso.name = "Rig"
	iso.target = NodePath("../Hanuman")
	root.add_child(iso)
	return iso


func _motion(pixels: float) -> InputEventMouseMotion:
	var ev: InputEventMouseMotion = InputEventMouseMotion.new()
	ev.relative = Vector2(pixels, 0.0)
	return ev


func _wheel(button: MouseButton) -> InputEventMouseButton:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


func test_mouse_motion_rotates_yaw_proportionally() -> void:
	var iso: IsoCamera = _build()
	var start: float = iso.yaw_goal()
	iso._input(_motion(100.0))
	assert_float(iso.yaw_goal() - start).is_equal_approx(100.0 * IsoCamera.MOUSE_SENSITIVITY, 0.0001)
	iso._input(_motion(-300.0))
	assert_float(iso.yaw_goal() - start).is_equal_approx(-200.0 * IsoCamera.MOUSE_SENSITIVITY, 0.0001)
	iso.finish_rotation()
	assert_float(iso.rotation.y).is_equal_approx(iso.yaw_goal(), 0.0001)


func test_view_follows_the_orbit_smoothly() -> void:
	var iso: IsoCamera = _build()
	iso._input(_motion(200.0))
	var before: float = iso.rotation.y
	iso._process(0.016)
	assert_float(iso.rotation.y).is_greater(before)
	assert_float(iso.rotation.y).is_less(iso.yaw_goal())
	for i: int in range(60):
		iso._process(0.016)
	assert_float(iso.rotation.y).is_equal_approx(iso.yaw_goal(), 0.001)


func test_movement_maps_correctly_after_arbitrary_yaw() -> void:
	var iso: IsoCamera = _build()
	for pixels: float in [37.0, 211.0, -523.0, 1000.0]:
		iso._input(_motion(pixels))
		iso.finish_rotation()
		var cam: Camera3D = iso.get_camera()
		var up: Vector3 = cam.global_transform.basis.y
		var expected_up: Vector3 = Vector3(up.x, 0.0, up.z).normalized()
		var mapped_up: Vector3 = iso.world_to_input_basis() * Vector3(0.0, 1.0, 0.0)
		assert_float(Vector3(mapped_up.x, 0.0, mapped_up.z).normalized().dot(expected_up)).is_equal_approx(1.0, 0.001)
		var right: Vector3 = cam.global_transform.basis.x
		var expected_right: Vector3 = Vector3(right.x, 0.0, right.z).normalized()
		var mapped_right: Vector3 = iso.world_to_input_basis() * Vector3(1.0, 0.0, 0.0)
		assert_float(Vector3(mapped_right.x, 0.0, mapped_right.z).normalized().dot(expected_right)).is_equal_approx(1.0, 0.001)


func test_snap_turn_from_a_free_yaw_lands_on_the_grid() -> void:
	var iso: IsoCamera = _build()
	iso._input(_motion(100.0))  # 0.5 rad off the grid
	assert_bool(iso.rotate_right()).is_true()
	iso.finish_rotation()
	var steps: float = (iso.rotation.y - IsoCamera.BASE_YAW) / IsoCamera.STEP_ANGLE
	assert_float(steps).is_equal_approx(1.0, 0.0001)
	iso._input(_motion(100.0))
	assert_bool(iso.rotate_left()).is_true()
	iso.finish_rotation()
	assert_float((iso.rotation.y - IsoCamera.BASE_YAW) / IsoCamera.STEP_ANGLE).is_equal_approx(1.0, 0.0001)


func test_wheel_zoom_changes_and_clamps() -> void:
	var iso: IsoCamera = _build()
	iso._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	assert_float(iso.zoom_target()).is_equal_approx(IsoCamera.ZOOM_STEP, 0.0001)
	for i: int in range(60):
		iso._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	assert_float(iso.zoom_target()).is_equal_approx(IsoCamera.ZOOM_MIN, 0.0001)
	for i: int in range(120):
		iso._input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	assert_float(iso.zoom_target()).is_equal_approx(IsoCamera.ZOOM_MAX, 0.0001)
	iso.finish_zoom()
	assert_float(iso.get_camera().size).is_equal_approx(iso.size * IsoCamera.ZOOM_MAX, 0.001)
	iso.size = 10.0  # the runtime's own size-based zoom still applies, multiplied
	iso._process(0.016)
	assert_float(iso.get_camera().size).is_equal_approx(10.0 * IsoCamera.ZOOM_MAX, 0.001)


func test_real_wheel_event_zooms_through_the_input_map() -> void:
	var iso: IsoCamera = _build()
	Input.parse_input_event(_wheel(MOUSE_BUTTON_WHEEL_UP))
	Input.flush_buffered_events()
	assert_float(iso.zoom_target()).is_less(1.0)


func test_mouse_is_captured_then_released_for_menus_and_dialogue() -> void:
	var iso: IsoCamera = _build()
	var runtime: FakeRuntime = iso.get_parent() as FakeRuntime
	iso._process(0.016)
	assert_int(iso.applied_mouse_mode()).is_equal(Input.MOUSE_MODE_CAPTURED)
	runtime.held = true  # a dialogue, card or menu holds input
	iso._process(0.016)
	assert_int(iso.applied_mouse_mode()).is_equal(Input.MOUSE_MODE_VISIBLE)
	var yaw: float = iso.yaw_goal()
	iso._input(_motion(500.0))
	assert_float(iso.yaw_goal()).is_equal_approx(yaw, 0.00001)  # no orbit while released
	runtime.held = false
	iso._process(0.016)
	assert_int(iso.applied_mouse_mode()).is_equal(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = true  # the pause screen
	iso._process(0.016)
	assert_int(iso.applied_mouse_mode()).is_equal(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	iso._process(0.016)
	assert_int(iso.applied_mouse_mode()).is_equal(Input.MOUSE_MODE_CAPTURED)


func test_locked_camera_refuses_orbit_and_zoom() -> void:
	var iso: IsoCamera = _build()
	iso.locked = true
	var yaw: float = iso.yaw_goal()
	iso._input(_motion(300.0))
	iso._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	assert_float(iso.yaw_goal()).is_equal_approx(yaw, 0.00001)
	assert_float(iso.zoom_target()).is_equal_approx(1.0, 0.00001)


func test_right_stick_orbits() -> void:
	var iso: IsoCamera = _build()
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_RIGHT_X
	ev.axis_value = 1.0
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	var start: float = iso.yaw_goal()
	iso._process(0.1)
	ev.axis_value = 0.0
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	assert_float(iso.yaw_goal() - start).is_equal_approx(IsoCamera.STICK_SPEED * 0.1, 0.001)


func test_controls_screen_lists_look_zoom_and_snap() -> void:
	var actions: Array[StringName] = []
	for entry: Dictionary in ControlsScreen.CONTROLS:
		actions.append(entry["action"] as StringName)
	assert_bool(actions.has(&"look")).is_true()
	assert_bool(actions.has(&"zoom")).is_true()
	assert_bool(actions.has(&"camera")).is_true()
	KeyGlyph.set_gamepad_active(true)
	assert_str(KeyGlyph.text_for(&"look")).is_equal("R Stick")
	KeyGlyph.set_gamepad_active(false)
	assert_str(KeyGlyph.text_for(&"look")).is_equal("Mouse")


func test_camera_strings_exist_in_english_and_hindi() -> void:
	for key: String in ["TUT_CAMERA", "HINT_PRO_CAMERA", "CTRL_LOOK", "CTRL_ZOOM", "CTRL_CAMERA"]:
		TranslationServer.set_locale("en")
		var en: String = TranslationServer.translate(key)
		TranslationServer.set_locale("hi")
		var hi: String = TranslationServer.translate(key)
		assert_bool(en != key and hi != key and en != hi).is_true()
	TranslationServer.set_locale("en")
