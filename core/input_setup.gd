extends Node
## Registers every control from DESIGN §4.1 in the InputMap (keyboard, mouse and joypad).
## Intended as an autoload; `register_all()` is idempotent and can also be called directly.

const _STICK_DEADZONE: float = 0.2
const _DEFAULT_DEADZONE: float = 0.5


func _ready() -> void:
	register_all()


## Registers or re-registers every action. Safe to call any number of times: each action is rebuilt from scratch,
## so events never accumulate. Unrelated actions are left untouched.
static func register_all() -> void:
	_bind_action(&"move_left", _STICK_DEADZONE, _events_key_and_axis(KEY_A, JOY_AXIS_LEFT_X, -1.0))
	_bind_action(&"move_right", _STICK_DEADZONE, _events_key_and_axis(KEY_D, JOY_AXIS_LEFT_X, 1.0))
	_bind_action(&"move_up", _STICK_DEADZONE, _events_key_and_axis(KEY_W, JOY_AXIS_LEFT_Y, -1.0))
	_bind_action(&"move_down", _STICK_DEADZONE, _events_key_and_axis(KEY_S, JOY_AXIS_LEFT_Y, 1.0))

	_bind_action(&"attack_light", _DEFAULT_DEADZONE, _events_mouse_and_joy_button(MOUSE_BUTTON_LEFT, JOY_BUTTON_X))
	_bind_action(&"attack_heavy", _DEFAULT_DEADZONE, _events_mouse_and_joy_button(MOUSE_BUTTON_RIGHT, JOY_BUTTON_B))  # own button: LMB+X made heavy unreachable (2026-11-27)

	_bind_action(&"leap", _DEFAULT_DEADZONE, _events_key_and_joy_button(KEY_SPACE, JOY_BUTTON_A))
	_bind_action(&"grow", _DEFAULT_DEADZONE, _events_key_and_joy_button(KEY_E, JOY_BUTTON_RIGHT_SHOULDER))
	_bind_action(&"shrink", _DEFAULT_DEADZONE, _events_key_and_joy_button(KEY_Q, JOY_BUTTON_LEFT_SHOULDER))
	_bind_action(&"interact", _DEFAULT_DEADZONE, _events_key_and_joy_button(KEY_F, JOY_BUTTON_Y))
	_bind_action(&"smarana_surge", _DEFAULT_DEADZONE, _events_key_and_axis(KEY_R, JOY_AXIS_TRIGGER_RIGHT, 1.0))
	_bind_action(&"pause", _DEFAULT_DEADZONE, _events_key_and_joy_button(KEY_ESCAPE, JOY_BUTTON_START))

	# 90-degree snap turns (Z / C, or a click of the left / right stick). The right stick itself orbits freely.
	_bind_action(&"rotate_camera_left", _DEFAULT_DEADZONE, _events_key_and_joy_button(KEY_Z, JOY_BUTTON_LEFT_STICK))
	_bind_action(&"rotate_camera_right", _DEFAULT_DEADZONE, _events_key_and_joy_button(KEY_C, JOY_BUTTON_RIGHT_STICK))
	# Free orbit: the mouse moves (read as motion events by IsoCamera) and the right stick X axis.
	_bind_action(&"camera_orbit_left", _STICK_DEADZONE, [_axis(JOY_AXIS_RIGHT_X, -1.0)] as Array[InputEvent])
	_bind_action(&"camera_orbit_right", _STICK_DEADZONE, [_axis(JOY_AXIS_RIGHT_X, 1.0)] as Array[InputEvent])
	# Zoom: the mouse wheel, or the D-pad up / down.
	_bind_action(&"camera_zoom_in", _DEFAULT_DEADZONE, _events_mouse_and_joy_button(MOUSE_BUTTON_WHEEL_UP, JOY_BUTTON_DPAD_UP))
	_bind_action(&"camera_zoom_out", _DEFAULT_DEADZONE, _events_mouse_and_joy_button(MOUSE_BUTTON_WHEEL_DOWN, JOY_BUTTON_DPAD_DOWN))


static func _bind_action(action: StringName, deadzone: float, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, deadzone)
	for ev: InputEvent in events:
		InputMap.action_add_event(action, ev)


static func _events_key_and_axis(keycode: Key, axis: JoyAxis, axis_value: float) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	events.append(_key(keycode))
	events.append(_axis(axis, axis_value))
	return events


static func _events_key_and_joy_button(keycode: Key, button: JoyButton) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	events.append(_key(keycode))
	events.append(_joy_button(button))
	return events


static func _events_mouse_and_joy_button(button: MouseButton, joy_button: JoyButton) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	events.append(_mouse(button))
	events.append(_joy_button(joy_button))
	return events


static func _key(keycode: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = keycode
	return ev


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button
	return ev


static func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button
	return ev


static func _axis(axis: JoyAxis, axis_value: float) -> InputEventJoypadMotion:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_value
	return ev
