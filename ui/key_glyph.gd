class_name KeyGlyph
extends PanelContainer
## A key-cap (keyboard and mouse) or a round gamepad-button badge for one InputMap action (DESIGN §4.1a points 1 and 6).
## The text always comes from the LIVE InputMap, so a remapped key is shown correctly, and it follows the last device the
## player used (keyboard and mouse, or gamepad). Two pseudo actions exist for controls made of several actions:
## `move` (WASD or the left stick), `camera` (the Z / C snap turn, or a stick click), `look` (Mouse or the right
## stick) and `zoom` (Wheel or the D-pad).
##
## `KeyGlyph.text_for(action)` is the static, node-free lookup. The device is tracked in a static variable that
## `KeyGlyph.observe(event)` updates: LevelRuntime feeds it every input event, and each glyph feeds it too.

const ACTION_MOVE: StringName = &"move"
const ACTION_CAMERA: StringName = &"camera"
const ACTION_LOOK: StringName = &"look"
const ACTION_ZOOM: StringName = &"zoom"
const ACTION_SHOW_CONTROLS: StringName = &"show_controls"
const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_left", &"move_down", &"move_right"]
const CAMERA_ACTIONS: Array[StringName] = [&"rotate_camera_left", &"rotate_camera_right"]
const SURGE_ACTION: StringName = &"smarana_surge"
const SURGE_GAMEPAD_TEXT: String = "RT + LT"
const KEY_FONT_SIZE: int = 22
const MIN_CAP_WIDTH: float = 46.0
const CAP_HEIGHT: float = 44.0
const BORDER_WIDTH: int = 2

## True while the gamepad was the last device used.
static var _gamepad: bool = false

var _action: StringName = &""
var _text: String = ""
var _label: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(MIN_CAP_WIDTH, CAP_HEIGHT)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", KEY_FONT_SIZE)
	_label.add_theme_color_override("font_color", Palette.GOLD)
	_label.add_theme_color_override("font_outline_color", Palette.UI_DARK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_apply_style()


func _ready() -> void:
	var locale: Node = get_node_or_null(^"/root/Locale")
	if locale != null:
		var font: Font = locale.call("font_for", &"ui") as Font
		if font != null:
			_label.add_theme_font_override("font", font)
	refresh()


func _input(event: InputEvent) -> void:
	if KeyGlyph.observe(event):
		refresh()


func _process(_delta: float) -> void:
	# Remapping in the InputMap does not announce itself, so compare the text each frame (a handful of glyphs).
	if _action != &"" and KeyGlyph.text_for(_action) != _text:
		refresh()


# ---------------------------------------------------------------- the node

func set_action(action: StringName) -> void:
	_action = action
	refresh()


func action() -> StringName:
	return _action


## A smaller cap for the HUD ability bar.
func set_compact(on: bool) -> void:
	_label.add_theme_font_size_override("font_size", KEY_FONT_SIZE - 4 if on else KEY_FONT_SIZE)
	custom_minimum_size = Vector2(MIN_CAP_WIDTH - 8.0, CAP_HEIGHT - 8.0) if on else Vector2(MIN_CAP_WIDTH, CAP_HEIGHT)


## The text drawn on the cap right now.
func shown_text() -> String:
	return _text


func refresh() -> void:
	_text = KeyGlyph.text_for(_action) if _action != &"" else ""
	_label.text = _text
	_apply_style()


func _apply_style() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(Palette.UI_DARK, 0.88)
	box.border_color = Palette.GOLD
	box.set_border_width_all(BORDER_WIDTH)
	box.border_width_bottom = BORDER_WIDTH + 3  # the lip of a key-cap
	var round_badge: bool = KeyGlyph.gamepad_active()
	box.set_corner_radius_all(int(CAP_HEIGHT * 0.5) if round_badge else 9)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	box.shadow_size = 4
	add_theme_stylebox_override("panel", box)


# ---------------------------------------------------------------- the device

## Records which device `event` came from. Returns true when the device changed. Small stick drift is ignored.
static func observe(event: InputEvent) -> bool:
	var was: bool = _gamepad
	if event is InputEventKey or event is InputEventMouseButton:
		_gamepad = false
	elif event is InputEventJoypadButton:
		_gamepad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.5:
			_gamepad = true
	return was != _gamepad


static func gamepad_active() -> bool:
	return _gamepad


static func set_gamepad_active(on: bool) -> void:
	_gamepad = on


## Registers the "show_controls" action (hold Tab) when the InputMap lacks it. Safe to call any number of times.
static func ensure_actions() -> void:
	if InputMap.has_action(ACTION_SHOW_CONTROLS):
		return
	InputMap.add_action(ACTION_SHOW_CONTROLS, 0.5)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_TAB
	InputMap.action_add_event(ACTION_SHOW_CONTROLS, key)
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_BACK
	InputMap.action_add_event(ACTION_SHOW_CONTROLS, pad)


# ---------------------------------------------------------------- the text

## The text of the glyph for `action` on the device last used, read from the live InputMap.
## An action with no event for that device falls back to the other device; an unknown action gives "?".
static func text_for(action: StringName) -> String:
	if action == ACTION_MOVE:
		return _joined(MOVE_ACTIONS, "", "L Stick")
	if action == ACTION_CAMERA:
		return _joined(CAMERA_ACTIONS, " / ", "L3 / R3")
	if action == ACTION_LOOK:
		return "R Stick" if _gamepad else "Mouse"
	if action == ACTION_ZOOM:
		return "D-pad" if _gamepad else "Wheel"
	if not InputMap.has_action(action):
		return "?"
	if _gamepad and action == SURGE_ACTION:
		return SURGE_GAMEPAD_TEXT
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	var preferred: String = _first_text(events, _gamepad)
	if preferred != "":
		return preferred
	var other: String = _first_text(events, not _gamepad)
	return other if other != "" else "?"


static func _joined(actions: Array[StringName], separator: String, stick_text: String) -> String:
	if _gamepad:
		return stick_text
	var parts: PackedStringArray = []
	for member: StringName in actions:
		if InputMap.has_action(member):
			var part: String = _first_text(InputMap.action_get_events(member), false)
			if part != "":
				parts.append(part)
	return separator.join(parts) if not parts.is_empty() else "?"


static func _first_text(events: Array[InputEvent], gamepad: bool) -> String:
	for event: InputEvent in events:
		var text: String = _event_text(event, gamepad)
		if text != "":
			return text
	return ""


static func _event_text(event: InputEvent, gamepad: bool) -> String:
	if not gamepad:
		var key: InputEventKey = event as InputEventKey
		if key != null:
			return _key_text(key)
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse != null:
			return _mouse_text(mouse.button_index)
		return ""
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button != null:
		return _joy_button_text(button.button_index)
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion != null:
		return _joy_axis_text(motion.axis)
	return ""


static func _key_text(key: InputEventKey) -> String:
	var text: String = ""
	if key.physical_keycode != 0:
		text = key.as_text_physical_keycode()
	elif key.keycode != 0:
		text = key.as_text_keycode()
	match text:
		"Escape":
			return "Esc"
		"Space":
			return "Space"
	return text


static func _mouse_text(button: MouseButton) -> String:
	match button:
		MOUSE_BUTTON_LEFT:
			return "LMB"
		MOUSE_BUTTON_RIGHT:
			return "RMB"
		MOUSE_BUTTON_MIDDLE:
			return "MMB"
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			return "Wheel"
	return "Mouse %d" % int(button)


static func _joy_button_text(button: JoyButton) -> String:
	match button:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN:
			return "D-pad"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_BACK:
			return "Back"
	return "Btn %d" % int(button)


static func _joy_axis_text(axis: JoyAxis) -> String:
	match axis:
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
			return "L Stick"
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
			return "R Stick"
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
	return "Axis %d" % int(axis)
