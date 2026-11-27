extends GdUnitTestSuite
## M04 acceptance tests (DESIGN §9, §4.1): every control in the table is registered in the InputMap
## with a keyboard or mouse event and a joypad event, and registration is idempotent.

const InputSetup = preload("res://core/input_setup.gd")

## Every action from §4.1 (plus the camera rotation actions from the §4.1 camera paragraph).
const EXPECTED_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"attack_light", &"attack_heavy",
	&"leap", &"grow", &"shrink", &"interact", &"smarana_surge", &"pause",
	&"rotate_camera_left", &"rotate_camera_right",
]


func before_test() -> void:
	InputSetup.register_all()


func _has_key(action: StringName, keycode: Key) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = ev as InputEventKey
		if key != null and key.physical_keycode == keycode:
			return true
	return false


func _has_mouse(action: StringName, button: MouseButton) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		var mouse: InputEventMouseButton = ev as InputEventMouseButton
		if mouse != null and mouse.button_index == button:
			return true
	return false


func _has_joy_button(action: StringName, button: JoyButton) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		var joy: InputEventJoypadButton = ev as InputEventJoypadButton
		if joy != null and joy.button_index == button:
			return true
	return false


func _has_joy_axis(action: StringName, axis: JoyAxis, value: float) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		var motion: InputEventJoypadMotion = ev as InputEventJoypadMotion
		if motion != null and motion.axis == axis and signf(motion.axis_value) == signf(value):
			return true
	return false


func _has_any_keyboard_or_mouse(action: StringName) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton:
			return true
	return false


func _has_any_joypad(action: StringName) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			return true
	return false


func test_every_action_is_registered() -> void:
	for action: StringName in EXPECTED_ACTIONS:
		assert_bool(InputMap.has_action(action)).override_failure_message("missing action %s" % action).is_true()


func test_every_action_has_keyboard_or_mouse_and_joypad_event() -> void:
	for action: StringName in EXPECTED_ACTIONS:
		assert_bool(_has_any_keyboard_or_mouse(action)) \
			.override_failure_message("%s has no keyboard or mouse event" % action).is_true()
		assert_bool(_has_any_joypad(action)) \
			.override_failure_message("%s has no joypad event" % action).is_true()


func test_movement_keys_and_left_stick() -> void:
	assert_bool(_has_key(&"move_left", KEY_A)).is_true()
	assert_bool(_has_key(&"move_right", KEY_D)).is_true()
	assert_bool(_has_key(&"move_up", KEY_W)).is_true()
	assert_bool(_has_key(&"move_down", KEY_S)).is_true()
	assert_bool(_has_joy_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)).is_true()
	assert_bool(_has_joy_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)).is_true()
	assert_bool(_has_joy_axis(&"move_up", JOY_AXIS_LEFT_Y, -1.0)).is_true()
	assert_bool(_has_joy_axis(&"move_down", JOY_AXIS_LEFT_Y, 1.0)).is_true()


func test_combat_bindings() -> void:
	assert_bool(_has_mouse(&"attack_light", MOUSE_BUTTON_LEFT)).is_true()
	assert_bool(_has_mouse(&"attack_heavy", MOUSE_BUTTON_RIGHT)).is_true()
	assert_bool(_has_joy_button(&"attack_light", JOY_BUTTON_X)).is_true()
	assert_bool(_has_joy_button(&"attack_heavy", JOY_BUTTON_B)).is_true()


func test_abilities_and_interaction_bindings() -> void:
	assert_bool(_has_key(&"leap", KEY_SPACE)).is_true()
	assert_bool(_has_joy_button(&"leap", JOY_BUTTON_A)).is_true()
	assert_bool(_has_key(&"grow", KEY_E)).is_true()
	assert_bool(_has_joy_button(&"grow", JOY_BUTTON_RIGHT_SHOULDER)).is_true()
	assert_bool(_has_key(&"shrink", KEY_Q)).is_true()
	assert_bool(_has_joy_button(&"shrink", JOY_BUTTON_LEFT_SHOULDER)).is_true()
	assert_bool(_has_key(&"interact", KEY_F)).is_true()
	assert_bool(_has_joy_button(&"interact", JOY_BUTTON_Y)).is_true()
	assert_bool(_has_key(&"smarana_surge", KEY_R)).is_true()
	assert_bool(_has_joy_axis(&"smarana_surge", JOY_AXIS_TRIGGER_RIGHT, 1.0)).is_true()


func test_pause_bindings() -> void:
	assert_bool(_has_key(&"pause", KEY_ESCAPE)).is_true()
	assert_bool(_has_joy_button(&"pause", JOY_BUTTON_START)).is_true()


func test_camera_rotation_bindings() -> void:
	assert_bool(_has_key(&"rotate_camera_left", KEY_Z)).is_true()
	assert_bool(_has_key(&"rotate_camera_right", KEY_C)).is_true()
	assert_bool(_has_joy_button(&"rotate_camera_left", JOY_BUTTON_LEFT_STICK)).is_true()
	assert_bool(_has_joy_button(&"rotate_camera_right", JOY_BUTTON_RIGHT_STICK)).is_true()


func test_free_orbit_and_zoom_bindings() -> void:
	assert_bool(_has_joy_axis(&"camera_orbit_left", JOY_AXIS_RIGHT_X, -1.0)).is_true()
	assert_bool(_has_joy_axis(&"camera_orbit_right", JOY_AXIS_RIGHT_X, 1.0)).is_true()
	assert_bool(_has_mouse(&"camera_zoom_in", MOUSE_BUTTON_WHEEL_UP)).is_true()
	assert_bool(_has_mouse(&"camera_zoom_out", MOUSE_BUTTON_WHEEL_DOWN)).is_true()


func test_register_all_is_idempotent() -> void:
	var before: Dictionary = {}
	for action: StringName in EXPECTED_ACTIONS:
		before[action] = InputMap.action_get_events(action).size()
	InputSetup.register_all()
	InputSetup.register_all()
	for action: StringName in EXPECTED_ACTIONS:
		assert_int(InputMap.action_get_events(action).size()) \
			.override_failure_message("%s event count changed on re-register" % action) \
			.is_equal(before[action] as int)


func test_register_all_does_not_clear_unrelated_actions() -> void:
	InputMap.add_action(&"m04_test_unrelated")
	InputSetup.register_all()
	assert_bool(InputMap.has_action(&"m04_test_unrelated")).is_true()
	InputMap.erase_action(&"m04_test_unrelated")
