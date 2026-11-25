extends GdUnitTestSuite
## M17 acceptance tests: the Objectives tracker adds, completes and reports objectives,
## ignores duplicates, and emits EventBus.objective_updated on every real change.

var _emitted: Array[Array] = []


func _make_objectives() -> Node:
	var objectives: Node = (load("res://narrative/objectives.gd") as GDScript).new() as Node
	auto_free(objectives)
	return objectives


func _bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("EventBus") as Node


func _on_objective_updated(id: StringName, text: String, done: bool) -> void:
	_emitted.append([id, text, done])


func _connect_bus() -> Node:
	_emitted.clear()
	var bus: Node = _bus()
	assert_object(bus).is_not_null()
	bus.connect("objective_updated", Callable(self, "_on_objective_updated"))
	return bus


func _disconnect_bus(bus: Node) -> void:
	if bus.is_connected("objective_updated", Callable(self, "_on_objective_updated")):
		bus.disconnect("objective_updated", Callable(self, "_on_objective_updated"))


func test_unknown_objective_is_not_done() -> void:
	var objectives: Node = _make_objectives()
	assert_bool(objectives.call("is_done", &"find_sita") as bool).is_false()


func test_added_objective_starts_not_done() -> void:
	var objectives: Node = _make_objectives()
	objectives.call("add", &"leap_to_lanka", "Leap across the sea to Lanka")
	assert_bool(objectives.call("is_done", &"leap_to_lanka") as bool).is_false()


func test_complete_marks_objective_done() -> void:
	var objectives: Node = _make_objectives()
	objectives.call("add", &"find_sita", "Find Sita in the Ashoka grove")
	objectives.call("complete", &"find_sita")
	assert_bool(objectives.call("is_done", &"find_sita") as bool).is_true()


func test_complete_only_affects_its_own_id() -> void:
	var objectives: Node = _make_objectives()
	objectives.call("add", &"a", "First")
	objectives.call("add", &"b", "Second")
	objectives.call("complete", &"a")
	assert_bool(objectives.call("is_done", &"a") as bool).is_true()
	assert_bool(objectives.call("is_done", &"b") as bool).is_false()


func test_completing_unknown_objective_does_nothing() -> void:
	var objectives: Node = _make_objectives()
	var bus: Node = _connect_bus()
	objectives.call("complete", &"never_added")
	assert_bool(objectives.call("is_done", &"never_added") as bool).is_false()
	assert_int(_emitted.size()).is_equal(0)
	_disconnect_bus(bus)


func test_adding_same_objective_twice_does_nothing() -> void:
	var objectives: Node = _make_objectives()
	var bus: Node = _connect_bus()
	objectives.call("add", &"find_sita", "Find Sita")
	objectives.call("add", &"find_sita", "Something else")
	assert_int(_emitted.size()).is_equal(1)
	assert_str(_emitted[0][1] as String).is_equal("Find Sita")
	_disconnect_bus(bus)


func test_adding_same_objective_twice_keeps_completed_state() -> void:
	var objectives: Node = _make_objectives()
	objectives.call("add", &"find_sita", "Find Sita")
	objectives.call("complete", &"find_sita")
	objectives.call("add", &"find_sita", "Find Sita")
	assert_bool(objectives.call("is_done", &"find_sita") as bool).is_true()


func test_add_emits_objective_updated_not_done() -> void:
	var objectives: Node = _make_objectives()
	var bus: Node = _connect_bus()
	objectives.call("add", &"leap_to_lanka", "Leap to Lanka")
	assert_int(_emitted.size()).is_equal(1)
	assert_str(_emitted[0][0] as String).is_equal("leap_to_lanka")
	assert_str(_emitted[0][1] as String).is_equal("Leap to Lanka")
	assert_bool(_emitted[0][2] as bool).is_false()
	_disconnect_bus(bus)


func test_complete_emits_objective_updated_done() -> void:
	var objectives: Node = _make_objectives()
	objectives.call("add", &"find_sita", "Find Sita")
	var bus: Node = _connect_bus()
	objectives.call("complete", &"find_sita")
	assert_int(_emitted.size()).is_equal(1)
	assert_str(_emitted[0][0] as String).is_equal("find_sita")
	assert_str(_emitted[0][1] as String).is_equal("Find Sita")
	assert_bool(_emitted[0][2] as bool).is_true()
	_disconnect_bus(bus)


func test_completing_twice_emits_only_once() -> void:
	var objectives: Node = _make_objectives()
	objectives.call("add", &"find_sita", "Find Sita")
	var bus: Node = _connect_bus()
	objectives.call("complete", &"find_sita")
	objectives.call("complete", &"find_sita")
	assert_int(_emitted.size()).is_equal(1)
	_disconnect_bus(bus)
