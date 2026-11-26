extends GdUnitTestSuite
## Regression (owner bug 2026-11-26): at Jambavan's question the usual advance key (interact) did nothing, so the
## game looked frozen. Choices must answer interact, accept, number keys and arrows.

func _box() -> DialogueBox:
	var box: DialogueBox = auto_free(DialogueBox.new()) as DialogueBox
	add_child(box)
	box.chars_per_second = 100000.0
	box.choice_guard_seconds = 0.0
	return box


func _action(name: StringName) -> InputEventAction:
	var a: InputEventAction = InputEventAction.new()
	a.action = name
	a.pressed = true
	return a


func _to_choice(box: DialogueBox) -> void:
	assert_int(box.play(&"pro_jambavan") as int).is_equal(OK)
	for i: int in 20:
		if box.get_runner().waiting_for_choice():
			return
		box.step_typewriter(1.0)
		box.handle_input_event(_action(&"interact"))
	assert_bool(box.get_runner().waiting_for_choice()).is_true()


func test_interact_key_answers_a_choice() -> void:
	var box: DialogueBox = _box()
	_to_choice(box)
	box.step_typewriter(1.0)
	assert_bool(box.handle_input_event(_action(&"interact"))).is_true()
	assert_bool(box.get_runner().waiting_for_choice()).is_false()


func test_number_key_answers_a_choice() -> void:
	var box: DialogueBox = _box()
	_to_choice(box)
	box.step_typewriter(1.0)
	var k: InputEventKey = InputEventKey.new()
	k.keycode = KEY_1
	k.pressed = true
	assert_bool(box.handle_input_event(k)).is_true()
	assert_bool(box.get_runner().waiting_for_choice()).is_false()
