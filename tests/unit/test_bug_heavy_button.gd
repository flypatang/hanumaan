extends GdUnitTestSuite
## Regression (2026-11-27): light and heavy shared LMB / X, so the light attack always won and the heavy attack was
## unreachable. Heavy now has its own button (RMB / gamepad B). These tests press the REAL buttons.

func before_test() -> void:
	(load("res://core/input_setup.gd") as GDScript).call("register_all")


func _player() -> Player:
	var p: Player = auto_free(Player.new()) as Player
	add_child(p)
	p.read_input = true
	return p


func test_right_click_starts_a_heavy_attack() -> void:
	var p: Player = _player()
	await get_tree().physics_frame
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(p.get_state()).is_equal(Player.State.HEAVY_WINDUP)
	ev.pressed = false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func test_left_click_is_still_the_light_attack() -> void:
	var p: Player = _player()
	await get_tree().physics_frame
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(p.get_state()).is_equal(Player.State.LIGHT)
	ev.pressed = false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
