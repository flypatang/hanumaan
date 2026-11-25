extends GdUnitTestSuite
## M02 acceptance tests: the EventBus autoload declares every cross-system signal from DESIGN §9 with the right arguments.


func _make_bus() -> Node:
	var bus: Node = (load("res://core/event_bus.gd") as GDScript).new() as Node
	auto_free(bus)
	return bus


func _signal_args(bus: Node, signal_name: StringName) -> Array:
	for sig: Dictionary in bus.get_signal_list():
		if (sig["name"] as String) == String(signal_name):
			return sig["args"] as Array
	return []


func test_m02_player_damaged_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("player_damaged")).is_true()
	var args: Array = _signal_args(bus, &"player_damaged")
	assert_array(args).has_size(2)
	assert_str((args[0] as Dictionary)["name"]).is_equal("amount")
	assert_int((args[0] as Dictionary)["type"]).is_equal(TYPE_INT)
	assert_str((args[1] as Dictionary)["name"]).is_equal("source")
	assert_int((args[1] as Dictionary)["type"]).is_equal(TYPE_OBJECT)


func test_m02_player_exhausted_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("player_exhausted")).is_true()
	assert_array(_signal_args(bus, &"player_exhausted")).has_size(0)


func test_m02_player_recovered_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("player_recovered")).is_true()
	assert_array(_signal_args(bus, &"player_recovered")).has_size(0)


func test_m02_enemy_defeated_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("enemy_defeated")).is_true()
	var args: Array = _signal_args(bus, &"enemy_defeated")
	assert_array(args).has_size(2)
	assert_str((args[0] as Dictionary)["name"]).is_equal("enemy_id")
	assert_int((args[0] as Dictionary)["type"]).is_equal(TYPE_STRING_NAME)
	assert_str((args[1] as Dictionary)["name"]).is_equal("pos")
	assert_int((args[1] as Dictionary)["type"]).is_equal(TYPE_VECTOR3)


func test_m02_size_changed_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("size_changed")).is_true()
	var args: Array = _signal_args(bus, &"size_changed")
	assert_array(args).has_size(1)
	assert_str((args[0] as Dictionary)["name"]).is_equal("new_size")
	assert_int((args[0] as Dictionary)["type"]).is_equal(TYPE_INT)


func test_m02_smarana_changed_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("smarana_changed")).is_true()
	var args: Array = _signal_args(bus, &"smarana_changed")
	assert_array(args).has_size(1)
	assert_str((args[0] as Dictionary)["name"]).is_equal("value")
	assert_int((args[0] as Dictionary)["type"]).is_equal(TYPE_FLOAT)


func test_m02_vitality_changed_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("vitality_changed")).is_true()
	var args: Array = _signal_args(bus, &"vitality_changed")
	assert_array(args).has_size(2)
	assert_str((args[0] as Dictionary)["name"]).is_equal("value")
	assert_int((args[0] as Dictionary)["type"]).is_equal(TYPE_INT)
	assert_str((args[1] as Dictionary)["name"]).is_equal("max")
	assert_int((args[1] as Dictionary)["type"]).is_equal(TYPE_INT)


func test_m02_objective_updated_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("objective_updated")).is_true()
	var args: Array = _signal_args(bus, &"objective_updated")
	assert_array(args).has_size(3)
	assert_str((args[0] as Dictionary)["name"]).is_equal("id")
	assert_int((args[0] as Dictionary)["type"]).is_equal(TYPE_STRING_NAME)
	assert_str((args[1] as Dictionary)["name"]).is_equal("text")
	assert_int((args[1] as Dictionary)["type"]).is_equal(TYPE_STRING)
	assert_str((args[2] as Dictionary)["name"]).is_equal("done")
	assert_int((args[2] as Dictionary)["type"]).is_equal(TYPE_BOOL)


func test_m02_dialogue_started_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("dialogue_started")).is_true()
	var args: Array = _signal_args(bus, &"dialogue_started")
	assert_array(args).has_size(1)
	assert_str((args[0] as Dictionary)["name"]).is_equal("id")
	assert_int((args[0] as Dictionary)["type"]).is_equal(TYPE_STRING_NAME)


func test_m02_dialogue_finished_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("dialogue_finished")).is_true()
	var args: Array = _signal_args(bus, &"dialogue_finished")
	assert_array(args).has_size(2)
	assert_str((args[0] as Dictionary)["name"]).is_equal("id")
	assert_int((args[0] as Dictionary)["type"]).is_equal(TYPE_STRING_NAME)
	assert_str((args[1] as Dictionary)["name"]).is_equal("flags")
	assert_int((args[1] as Dictionary)["type"]).is_equal(TYPE_DICTIONARY)


func test_m02_level_loaded_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("level_loaded")).is_true()
	var args: Array = _signal_args(bus, &"level_loaded")
	assert_array(args).has_size(1)
	assert_str((args[0] as Dictionary)["name"]).is_equal("id")
	assert_int((args[0] as Dictionary)["type"]).is_equal(TYPE_STRING_NAME)


func test_m02_chapter_completed_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("chapter_completed")).is_true()
	var args: Array = _signal_args(bus, &"chapter_completed")
	assert_array(args).has_size(1)
	assert_str((args[0] as Dictionary)["name"]).is_equal("id")
	assert_int((args[0] as Dictionary)["type"]).is_equal(TYPE_STRING_NAME)


func test_m02_fire_ignited_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("fire_ignited")).is_true()
	var args: Array = _signal_args(bus, &"fire_ignited")
	assert_array(args).has_size(1)
	assert_str((args[0] as Dictionary)["name"]).is_equal("target_id")
	assert_int((args[0] as Dictionary)["type"]).is_equal(TYPE_STRING_NAME)


func test_m02_alarm_raised_signal() -> void:
	var bus: Node = _make_bus()
	assert_bool(bus.has_signal("alarm_raised")).is_true()
	var args: Array = _signal_args(bus, &"alarm_raised")
	assert_array(args).has_size(1)
	assert_str((args[0] as Dictionary)["name"]).is_equal("pos")
	assert_int((args[0] as Dictionary)["type"]).is_equal(TYPE_VECTOR3)


func test_m02_emitting_signal_delivers_arguments() -> void:
	var bus: Node = _make_bus()
	var received: Array = []
	bus.connect("vitality_changed", func(value: int, max_value: int) -> void:
		received.append([value, max_value]))
	bus.emit_signal("vitality_changed", 7, 10)
	assert_array(received).has_size(1)
	assert_int((received[0] as Array)[0] as int).is_equal(7)
	assert_int((received[0] as Array)[1] as int).is_equal(10)
